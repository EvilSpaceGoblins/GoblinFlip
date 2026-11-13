-- Live auction-house search adapter. Only one item search can be active at a
-- time, so all callers share one FIFO queue. Search results are the authority
-- for purchasing; replicated scan rows are never used as auction IDs.

local _, GF = ...

GF.LiveMarket = {
    initialized = false,
    queue = {},
    active = nil,
    attempts = 0,
}

local function ah()
    return _G.C_AuctionHouse
end

local function safeRegister(frame, event)
    if not event then
        return false
    end
    return pcall(frame.RegisterEvent, frame, event)
end

local function searchSorts()
    local enum = _G.Enum
    local order = enum and enum.AuctionHouseSortOrder and enum.AuctionHouseSortOrder.Price
    if not order then
        return nil
    end
    return {{sortOrder = order, reverseSort = false}}
end

function GF.LiveMarket.Initialize()
    if GF.LiveMarket.initialized then
        return
    end
    GF.LiveMarket.initialized = true

    local frame = CreateFrame("Frame")
    GF.LiveMarket.frame = frame
    safeRegister(frame, "ITEM_SEARCH_RESULTS_UPDATED")
    safeRegister(frame, "COMMODITY_SEARCH_RESULTS_UPDATED")
    safeRegister(frame, "AUCTION_HOUSE_NEW_BID_RECEIVED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_NEW_BID_RECEIVED" then
            if type(GF.LiveMarket.bidListener) == "function" then
                pcall(GF.LiveMarket.bidListener)
            end
        end
        GF.LiveMarket:TryResolve()
    end)

    local poller = CreateFrame("Frame")
    GF.LiveMarket.poller = poller
    poller:Hide()
    poller.elapsed = 0
    poller:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.2 then
            return
        end
        self.elapsed = 0
        if not GF.LiveMarket:TryResolve() and GF.LiveMarket.active then
            GF.LiveMarket.attempts = GF.LiveMarket.attempts + 1
            if GF.LiveMarket.attempts >= 15 then
                GF.LiveMarket:FinishActive({}, {reason = "timeout", isCommodity = GF.LiveMarket.activeIsCommodity})
            end
        end
    end)
end

function GF.LiveMarket.IsAvailable()
    local api = ah()
    return type(api) == "table"
        and type(api.SendSearchQuery) == "function"
        and type(api.GetNumItemSearchResults) == "function"
        and type(api.GetItemSearchResultInfo) == "function"
end

function GF.LiveMarket.GetItemKey(listing)
    return GF.ItemInfo.GetItemKey(listing)
end

function GF.LiveMarket.IsCommodity(itemKey)
    return GF.ItemInfo.IsCommodity(itemKey)
end

local function makeVariantKey(itemKey)
    return GF.Domain.ScanNormalizer.MakeVariantKey(
        itemKey.itemID or 0,
        itemKey.itemLevel or 0,
        itemKey.itemSuffix or 0,
        itemKey.battlePetSpeciesID or 0)
end

function GF.LiveMarket:CollectOffers(itemKey)
    local api = ah()
    local offers = {}
    if not api or not itemKey then
        return offers, false
    end
    local commodity = self:IsCommodity(itemKey)

    if commodity == true then
        if type(api.GetNumCommoditySearchResults) ~= "function"
            or type(api.GetCommoditySearchResultInfo) ~= "function" then
            return offers, true
        end
        local ok, count = pcall(api.GetNumCommoditySearchResults, itemKey.itemID)
        if not ok or type(count) ~= "number" then
            return offers, true
        end
        for index = 1, count do
            local infoOk, result = pcall(api.GetCommoditySearchResultInfo, itemKey.itemID, index)
            if infoOk and type(result) == "table" and result.unitPrice and result.unitPrice > 0 then
                local quantity = result.quantity or 1
                offers[#offers + 1] = {
                    itemId = itemKey.itemID,
                    variantKey = makeVariantKey(itemKey),
                    quantity = quantity,
                    buyoutTotal = result.unitPrice * quantity,
                    unitPrice = result.unitPrice,
                    isCommodity = true,
                    own = false,
                }
            end
        end
    else
        local ok, count = pcall(api.GetNumItemSearchResults, itemKey)
        if not ok or type(count) ~= "number" then
            return offers, false
        end
        for index = 1, count do
            local infoOk, result = pcall(api.GetItemSearchResultInfo, itemKey, index)
            if infoOk and type(result) == "table" then
                local buyout = result.buyoutAmount
                local own = result.containsOwnerItem == true or result.containsAccountItem == true
                if buyout and buyout > 0 and not own then
                    local quantity = result.quantity or 1
                    offers[#offers + 1] = {
                        auctionId = result.auctionID,
                        itemId = itemKey.itemID,
                        variantKey = makeVariantKey(itemKey),
                        quantity = quantity,
                        buyoutTotal = buyout,
                        unitPrice = buyout / quantity,
                        isCommodity = false,
                        own = false,
                    }
                end
            end
        end
    end

    table.sort(offers, function(left, right)
        if left.buyoutTotal == right.buyoutTotal then
            return (left.quantity or 0) > (right.quantity or 0)
        end
        return left.buyoutTotal < right.buyoutTotal
    end)
    return offers, commodity == true
end

local function isSearchReady(itemKey, commodity)
    local api = ah()
    if not api or not itemKey then
        return false
    end
    if commodity then
        local hasFull = false
        if type(api.HasFullCommoditySearchResults) == "function" then
            local ok, result = pcall(api.HasFullCommoditySearchResults, itemKey.itemID)
            hasFull = ok and result == true
        end
        local quantity = 0
        if type(api.GetCommoditySearchResultsQuantity) == "function" then
            local ok, result = pcall(api.GetCommoditySearchResultsQuantity, itemKey.itemID)
            if ok and type(result) == "number" then
                quantity = result
            end
        end
        return hasFull or quantity > 0
    end
    if type(api.HasSearchResults) == "function" then
        local ok, has = pcall(api.HasSearchResults, itemKey)
        if not ok or not has then
            return false
        end
    end
    local hasFull = false
    if type(api.HasFullItemSearchResults) == "function" then
        local ok, result = pcall(api.HasFullItemSearchResults, itemKey)
        hasFull = ok and result == true
    end
    local quantity = 0
    if type(api.GetItemSearchResultsQuantity) == "function" then
        local ok, result = pcall(api.GetItemSearchResultsQuantity, itemKey)
        if ok and type(result) == "number" then
            quantity = result
        end
    end
    return hasFull or quantity > 0
end

function GF.LiveMarket:FinishActive(offers, info)
    local active = self.active
    self.active = nil
    self.attempts = 0
    self.activeIsCommodity = nil
    if self.poller then
        self.poller:Hide()
    end
    if active and type(active.callback) == "function" then
        pcall(active.callback, active.generation, offers, info or {})
    end
    self:StartNext()
end

function GF.LiveMarket:TryResolve()
    local active = self.active
    if not active or not isSearchReady(active.itemKey, active.isCommodity) then
        return false
    end
    local offers, commodity = self:CollectOffers(active.itemKey)
    self:FinishActive(offers, {isCommodity = commodity, count = #offers})
    return true
end

function GF.LiveMarket:StartNext()
    if self.active or #self.queue == 0 then
        return
    end
    self.active = table.remove(self.queue, 1)
    self.activeIsCommodity = self:IsCommodity(self.active.itemKey)
    self.active.isCommodity = self.activeIsCommodity
    self.attempts = 0

    local api = ah()
    local sorts = searchSorts()
    local ok = pcall(api.SendSearchQuery, self.active.itemKey, sorts, true)
    if not ok then
        -- Retry once without an explicit sort table on clients that changed the signature.
        ok = pcall(api.SendSearchQuery, self.active.itemKey, nil, true)
    end
    if not ok then
        self:FinishActive({}, {reason = "query_failed", isCommodity = self.activeIsCommodity})
        return
    end
    if self.poller then
        self.poller.elapsed = 0
        self.poller:Show()
    end
end

--- callback(generation, offers, info)
function GF.LiveMarket:RequestOffers(listing, generation, callback)
    self:Initialize()
    if not self:IsAvailable() then
        if callback then
            pcall(callback, generation, {}, {reason = "unsupported"})
        end
        return false, "unsupported"
    end
    local itemKey = self.GetItemKey(listing)
    if not itemKey then
        if callback then
            pcall(callback, generation, {}, {reason = "no_item_key"})
        end
        return false, "no_item_key"
    end
    self.queue[#self.queue + 1] = {
        listing = listing,
        itemKey = itemKey,
        generation = generation,
        callback = callback,
    }
    self:StartNext()
    return true
end

function GF.LiveMarket:CancelAll()
    self.queue = {}
    local active = self.active
    self.active = nil
    self.attempts = 0
    if self.poller then
        self.poller:Hide()
    end
    if active then
        return true
    end
    return false
end

function GF.LiveMarket:Cancel(generation)
    local keep = {}
    for index = 1, #self.queue do
        if self.queue[index].generation ~= generation then
            keep[#keep + 1] = self.queue[index]
        end
    end
    self.queue = keep
    if self.active and self.active.generation == generation then
        self:CancelAll()
    end
end

function GF.LiveMarket:PlaceBid(auctionId, amount)
    local api = ah()
    if type(api) ~= "table" or type(api.PlaceBid) ~= "function" then
        return false, "unsupported"
    end
    if type(auctionId) ~= "number" then
        return false, "missing_auction_id"
    end
    if not GF.Util.IsCopper(amount) or amount <= 0 then
        return false, "invalid_amount"
    end
    local ok, errorMessage = pcall(api.PlaceBid, auctionId, amount)
    if not ok then
        return false, errorMessage
    end
    return true
end

function GF.LiveMarket:SetBidListener(listener)
    self.bidListener = listener
end

function GF.LiveMarket:GetQueueLength()
    return #self.queue + (self.active and 1 or 0)
end
