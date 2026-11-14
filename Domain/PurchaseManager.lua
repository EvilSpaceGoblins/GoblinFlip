-- Purchase state machine. It owns quote freshness, budget reservations and the
-- one-submission-at-a-time guarantee. Actual API calls are injected.

local _, GF = ...

GF.Domain = GF.Domain or {}
local PurchaseManager = {}
GF.Domain.PurchaseManager = PurchaseManager
PurchaseManager.__index = PurchaseManager

PurchaseManager.STATE = {
    IDLE = "IDLE",
    QUERYING = "QUERYING",
    QUOTED = "QUOTED",
    CONFIRM_REQUIRED = "CONFIRM_REQUIRED",
    SUBMITTED = "SUBMITTED",
    CONFIRMED = "CONFIRMED",
    FAILED = "FAILED",
    UNKNOWN = "UNKNOWN",
    CANCELLED = "CANCELLED",
}

local STATE = PurchaseManager.STATE

function PurchaseManager.New(environment, options)
    options = options or {}
    local self = setmetatable({
        env = environment or {},
        state = STATE.IDLE,
        quote = nil,
        lastQuote = nil,
        activeListing = nil,
        activeContext = nil,
        generation = 0,
        reserved = 0,
        pending = nil,
        lastReason = nil,
        options = {
            quoteFreshness = options.quoteFreshness or 10,
            allowCommodity = options.allowCommodity == true,
            maxPerPurchase = options.maxPerPurchase or 0,
        },
    }, PurchaseManager)
    return self
end

function PurchaseManager:GetState()
    return self.state
end

function PurchaseManager:GetQuote()
    return self.quote
end

function PurchaseManager:GetLastQuote()
    return self.lastQuote
end

function PurchaseManager:GetPending()
    return self.pending
end

function PurchaseManager:GetLastReason()
    return self.lastReason
end

function PurchaseManager:GetReserved()
    return self.reserved
end

function PurchaseManager:IsBusy()
    return self.state == STATE.QUERYING or self.state == STATE.SUBMITTED
        or self.state == STATE.CONFIRM_REQUIRED or self.state == STATE.UNKNOWN
end

local function nowOf(self)
    if type(self.env.now) == "function" then
        local ok, value = pcall(self.env.now)
        if ok and type(value) == "number" then
            return value
        end
    end
    return type(time) == "function" and time() or 0
end

local function notify(self, state, quote, info)
    if type(self.env.onState) == "function" then
        pcall(self.env.onState, state, quote, info)
    end
end

local function setState(self, state, reason, info)
    self.state = state
    if reason then
        self.lastReason = reason
    end
    notify(self, state, self.quote, info)
end

function PurchaseManager:GetRemainingBudget(now)
    local budget = 0
    local spent = 0
    if type(self.env.getSessionBudget) == "function" then
        local ok, value = pcall(self.env.getSessionBudget)
        if ok and type(value) == "number" then
            budget = value
        end
    end
    if type(self.env.getSessionSpent) == "function" then
        local ok, value = pcall(self.env.getSessionSpent)
        if ok and type(value) == "number" then
            spent = value
        end
    end
    if budget == 0 then return math.huge end
    return math.max(0, budget - spent - self.reserved)
end

function PurchaseManager:GetMoney()
    if type(self.env.getMoney) == "function" then
        local ok, value = pcall(self.env.getMoney)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

function PurchaseManager:GetMarketKey()
    if type(self.env.getMarketKey) == "function" then
        local ok, value = pcall(self.env.getMarketKey)
        if ok then
            return value
        end
    end
    return nil
end

function PurchaseManager:RequestQuote(listing, context)
    context = context or {}
    if self.state == STATE.SUBMITTED or self.state == STATE.UNKNOWN then
        return false, "busy_outcome_pending"
    end
    if self.state == STATE.QUERYING then
        return false, "busy_query"
    end
    if type(listing) ~= "table" or listing.isGroup == true then
        return false, "not_executable"
    end
    if not GF.Util.IsCopper(listing.buyoutTotal) or listing.buyoutTotal <= 0 then
        return false, "invalid_buyout"
    end
    if not GF.Util.IsInteger(listing.quantity) or listing.quantity <= 0 then
        return false, "invalid_quantity"
    end

    local currentMarket = self:GetMarketKey()
    local marketKey = context.marketKey or listing.marketKey or currentMarket
    if listing.marketKey and currentMarket and listing.marketKey ~= currentMarket then
        return false, "wrong_market"
    end
    if context.marketKey and currentMarket and context.marketKey ~= currentMarket then
        return false, "wrong_market"
    end

    self.generation = self.generation + 1
    self.activeListing = listing
    self.activeContext = {
        strategy = context.strategy or listing.strategy or GF.STRATEGY_VENDOR,
        marketKey = marketKey,
        filters = context.filters or {},
        disenchant = context.disenchant,
        requireSkill = context.requireSkill,
        quoteFreshness = context.quoteFreshness or self.options.quoteFreshness,
        evaluationContext = context.evaluationContext,
    }
    self.quote = nil
    self.pending = nil
    setState(self, STATE.QUERYING, nil, {generation = self.generation})

    if type(self.env.query) ~= "function" then
        setState(self, STATE.FAILED, "query_unavailable")
        return false, "query_unavailable"
    end
    local ok, result, reason = pcall(self.env.query, listing, self.generation)
    if not ok then
        setState(self, STATE.FAILED, "query_error")
        return false, "query_error"
    end
    if result == false then
        setState(self, STATE.FAILED, reason or "query_failed")
        return false, reason or "query_failed"
    end
    return true
end

function PurchaseManager:Cancel(reason)
    if self.state == STATE.SUBMITTED or self.state == STATE.UNKNOWN then
        return false, "outcome_pending"
    end
    local cancelledGeneration = self.generation
    self.generation = self.generation + 1
    if type(self.env.cancelQuery) == "function" then
        pcall(self.env.cancelQuery, cancelledGeneration)
    end
    self.quote = nil
    self.activeListing = nil
    self.activeContext = nil
    setState(self, STATE.CANCELLED, reason or "cancelled")
    return true
end

function PurchaseManager:OnAhClosed()
    if self.state == STATE.SUBMITTED or self.state == STATE.UNKNOWN then
        if self.quote then
            self.quote.ahClosed = true
        end
        return
    end
    return self:Cancel("ah_closed")
end

function PurchaseManager:OnMarketChanged(newKey)
    if self.quote and self.quote.marketKey and newKey and self.quote.marketKey ~= newKey then
        if self.state == STATE.SUBMITTED or self.state == STATE.UNKNOWN then
            self.quote.marketChanged = true
            return false, "outcome_pending"
        end
        return self:Cancel("market_changed")
    end
    return true
end

local function offerMatches(listing, offer)
    if type(offer) ~= "table" then
        return false
    end
    if offer.own == true then
        return false
    end
    if not GF.Util.IsCopper(offer.buyoutTotal) or offer.buyoutTotal <= 0 then
        return false
    end
    if not GF.Util.IsInteger(offer.quantity) or offer.quantity <= 0 then
        return false
    end
    if offer.itemId and listing.itemId and offer.itemId ~= listing.itemId then
        return false
    end
    if offer.variantKey and listing.variantKey and offer.variantKey ~= listing.variantKey then
        return false
    end
    return true
end

local function chooseOffer(listing, offers, isCommodity)
    local best
    for index = 1, #offers do
        local offer = offers[index]
        if offerMatches(listing, offer) then
            local quantityMatches = offer.quantity == listing.quantity
            if quantityMatches or isCommodity then
                if not best or offer.buyoutTotal < best.buyoutTotal then
                    best = offer
                end
            end
        end
    end
    return best
end

function PurchaseManager:OnQueryResults(generation, offers, info)
    if generation ~= self.generation or self.state ~= STATE.QUERYING then
        return false, "stale_generation"
    end
    if type(offers) ~= "table" then
        offers = {}
    end
    local listing = self.activeListing
    local context = self.activeContext
    if not listing or not context then
        setState(self, STATE.FAILED, "no_active_listing")
        return false, "no_active_listing"
    end

    local isCommodity = info and info.isCommodity == true
    local offer = chooseOffer(listing, offers, isCommodity)
    if not offer then
        setState(self, STATE.FAILED, "unavailable")
        return false, "unavailable"
    end

    local evaluationContext = context.evaluationContext or {}
    evaluationContext.disenchant = context.disenchant or evaluationContext.disenchant
    evaluationContext.requireSkill = context.requireSkill
    local opportunity, reason = GF.Domain.ProfitEngine.EvaluateLive(
        listing, context.strategy, evaluationContext, offer.buyoutTotal, offer.quantity)
    if not opportunity then
        setState(self, STATE.FAILED, reason or "not_profitable")
        return false, reason or "not_profitable"
    end

    local quotedAt = nowOf(self)
    local freshness = context.quoteFreshness or self.options.quoteFreshness
    local quote = {
        generation = generation,
        strategy = context.strategy,
        marketKey = context.marketKey,
        auctionId = offer.auctionId,
        itemId = listing.itemId,
        itemKey = offer.itemKey or listing.itemKey,
        variantKey = listing.variantKey,
        itemName = listing.itemName or opportunity.itemName,
        itemLink = listing.itemLink,
        quantity = offer.quantity,
        buyoutTotal = offer.buyoutTotal,
        unitPrice = offer.unitPrice or (offer.buyoutTotal / offer.quantity),
        expectedProceeds = opportunity.expectedProceeds,
        profit = opportunity.profit,
        roi = opportunity.roi,
        isCommodity = isCommodity,
        quotedAt = quotedAt,
        expiresAt = quotedAt + freshness,
        freshness = freshness,
        scannedBuyout = listing.buyoutTotal,
        scannedQuantity = listing.quantity,
        changed = offer.buyoutTotal ~= listing.buyoutTotal or offer.quantity ~= listing.quantity,
        confidence = opportunity.confidence,
        estimated = opportunity.estimated,
    }

    local maxPerPurchase = (context.filters and context.filters.maxBuyout) or self.options.maxPerPurchase or 0
    if not GF.Domain.ProfitEngine.Qualifies(opportunity, context.filters) then
        quote.blockedReason = "profit_filters"
    end
    if maxPerPurchase > 0 and quote.buyoutTotal > maxPerPurchase then
        quote.blockedReason = "per_purchase_limit"
    end
    if quote.isCommodity and not self.options.allowCommodity then
        quote.blockedReason = quote.blockedReason or "commodity_disabled"
    end
    if quote.buyoutTotal > self:GetMoney() then
        quote.blockedReason = quote.blockedReason or "insufficient_funds"
    end
    if quote.buyoutTotal > self:GetRemainingBudget(quotedAt) then
        quote.blockedReason = quote.blockedReason or "budget"
    end

    self.quote = quote
    self.lastQuote = quote
    self.lastReason = nil
    setState(self, STATE.QUOTED, nil, {changed = quote.changed})
    return true, nil, quote
end

function PurchaseManager:ValidateQuote(now)
    local quote = self.quote
    if not quote then
        return false, "no_quote"
    end
    if self.state ~= STATE.QUOTED and self.state ~= STATE.CONFIRM_REQUIRED then
        return false, "wrong_state"
    end
    now = now or nowOf(self)
    if now > quote.expiresAt then
        return false, "expired"
    end
    local currentMarket = self:GetMarketKey()
    if quote.marketKey and currentMarket and quote.marketKey ~= currentMarket then
        return false, "market_changed"
    end
    if quote.blockedReason then
        return false, quote.blockedReason
    end
    if self.options.maxPerPurchase > 0 and quote.buyoutTotal > self.options.maxPerPurchase then
        return false, "per_purchase_limit"
    end
    if not quote.profit or quote.profit <= 0 then
        return false, "not_profitable"
    end
    if quote.buyoutTotal > self:GetMoney() then
        return false, "insufficient_funds"
    end
    if quote.buyoutTotal > self:GetRemainingBudget(now) then
        return false, "budget"
    end
    if quote.isCommodity and not self.options.allowCommodity then
        return false, "commodity_disabled"
    end
    if not quote.auctionId and not quote.isCommodity then
        return false, "missing_auction_id"
    end
    if self.env.validateQuote then return self.env.validateQuote(quote) end
    return true, nil
end

function PurchaseManager:BeginConfirm()
    if self.state ~= STATE.QUOTED then
        return false, "wrong_state"
    end
    local ok, reason = self:ValidateQuote()
    if not ok then
        return false, reason
    end
    setState(self, STATE.CONFIRM_REQUIRED, nil)
    return true, nil, self.quote
end

function PurchaseManager:Submit(now)
    if self.state == STATE.SUBMITTED then
        return false, "already_submitted"
    end
    if self.state ~= STATE.CONFIRM_REQUIRED then
        return false, "confirmation_required"
    end
    local ok, reason = self:ValidateQuote(now)
    if not ok then
        -- A price change or an expired quote must produce a new confirmation.
        self.quote = nil
        setState(self, STATE.CANCELLED, reason)
        return false, reason
    end
    if type(self.env.submit) ~= "function" then
        return false, "submit_unavailable"
    end

    local quote = self.quote
    quote.submittedAt = nowOf(self)
    if type(self.env.newTransactionId) == "function" then
        local ok, id = pcall(self.env.newTransactionId)
        if ok and type(id) == "string" then
            quote.localTransactionId = id
        end
    end
    quote.localTransactionId = quote.localTransactionId or GF.Util.NewId("tx")
    self.pending = quote
    self.reserved = self.reserved + quote.buyoutTotal
    setState(self, STATE.SUBMITTED, nil)
    if type(self.env.onSubmitted) == "function" then
        pcall(self.env.onSubmitted, quote)
    end

    local callOk, result, submitReason = pcall(self.env.submit, quote)
    if not callOk then
        setState(self, STATE.UNKNOWN, "submit_error")
        return nil, "submit_error"
    end
    if result == false then
        self.reserved = math.max(0, self.reserved - quote.buyoutTotal)
        self.pending = nil
        self.quote = nil
        setState(self, STATE.FAILED, submitReason or "submit_failed")
        if type(self.env.onFailed) == "function" then
            pcall(self.env.onFailed, submitReason or "submit_failed", quote)
        end
        return false, submitReason or "submit_failed"
    end
    return true, nil
end

function PurchaseManager:OnSubmitEvent(kind, data)
    if not self.pending then
        return false, "no_pending_purchase"
    end
    local pending = self.pending
    if kind == "confirmed" then
        self.reserved = math.max(0, self.reserved - pending.buyoutTotal)
        local transaction = {
            id = pending.localTransactionId,
            strategy = pending.strategy,
            marketKey = pending.marketKey,
            auctionId = pending.auctionId,
            itemId = pending.itemId,
            itemKey = pending.itemKey,
            variantKey = pending.variantKey,
            itemName = pending.itemName,
            itemLink = pending.itemLink,
            purchasedQuantity = pending.quantity,
            purchasedCost = pending.buyoutTotal,
            expectedProceeds = pending.expectedProceeds,
            confirmedAt = nowOf(self),
            source = "auction-house",
        }
        if data then
            for key, value in pairs(data) do
                if transaction[key] == nil then
                    transaction[key] = value
                end
            end
        end
        self.pending = nil
        self.quote = nil
        setState(self, STATE.CONFIRMED, nil, {transaction = transaction})
        if type(self.env.onConfirmed) == "function" then
            pcall(self.env.onConfirmed, transaction)
        end
        return true
    elseif kind == "failed" then
        self.reserved = math.max(0, self.reserved - pending.buyoutTotal)
        self.pending = nil
        self.quote = nil
        setState(self, STATE.FAILED, (data and data.reason) or "purchase_failed")
        if type(self.env.onFailed) == "function" then
            pcall(self.env.onFailed, (data and data.reason) or "purchase_failed", pending)
        end
        return true
    elseif kind == "unknown" then
        -- Keep the reservation: the gold may already be spent. No automatic retry.
        self.quote = nil
        setState(self, STATE.UNKNOWN, (data and data.reason) or "outcome_unknown")
        return true
    end
    return false, "unknown_event"
end

function PurchaseManager:ResolveUncertain(confirmed, data)
    if self.state ~= STATE.UNKNOWN or not self.pending then
        return false, "not_uncertain"
    end
    return self:OnSubmitEvent(confirmed and "confirmed" or "failed", data)
end

function PurchaseManager:Tick(now)
    now = now or nowOf(self)
    if (self.state == STATE.QUOTED or self.state == STATE.CONFIRM_REQUIRED) and self.quote then
        if now > self.quote.expiresAt then
            self.quote.expired = true
            setState(self, STATE.CANCELLED, "expired")
            return true
        end
    end
    return false
end

function PurchaseManager:GetQuoteRemaining(now)
    if not self.quote then
        return 0
    end
    now = now or nowOf(self)
    return math.max(0, self.quote.expiresAt - now)
end

function PurchaseManager:Reset()
    self.state = STATE.IDLE
    self.quote = nil
    self.activeListing = nil
    self.activeContext = nil
    self.pending = nil
    self.reserved = 0
    self.generation = self.generation + 1
end
