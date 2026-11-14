-- Pure profit evaluation, filtering, sorting, grouping and metrics.

local _, GF = ...

GF.Domain = GF.Domain or {}
local ProfitEngine = {}
GF.Domain.ProfitEngine = ProfitEngine

local EPSILON = 1e-9

local STRATEGIES = {
    [GF.STRATEGY_VENDOR] = function()
        return GF.Domain.VendorStrategy
    end,
    [GF.STRATEGY_DISENCHANT] = function()
        return GF.Domain.DisenchantStrategy
    end,
}

local function copyCoreFields(opportunity, listing, result, index)
    opportunity.key = table.concat({tostring(listing.scanId or "live"), tostring(listing.variantKey or listing.itemId), tostring(listing.auctionId or listing.rowIndex or index)}, "|")
    opportunity.strategy = result.strategy
    opportunity.itemId = listing.itemId
    opportunity.itemKey = listing.itemKey
    opportunity.variantKey = listing.variantKey
    opportunity.itemLink = listing.itemLink
    opportunity.itemName = listing.itemName or ("Item #" .. tostring(listing.itemId))
    opportunity.itemQuality = listing.itemQuality
    opportunity.itemLevel = listing.itemLevel
    opportunity.classId = listing.classId
    opportunity.subClassId = listing.subClassId
    opportunity.itemIcon = listing.itemIcon
    opportunity.auctionId = listing.auctionId
    opportunity.quantity = listing.quantity
    opportunity.buyoutTotal = listing.buyoutTotal
    opportunity.buyoutUnit = listing.buyoutTotal / listing.quantity
    opportunity.expectedProceeds = result.expectedProceeds or result.proceeds
    opportunity.proceeds = result.proceeds or result.expectedProceeds
    opportunity.profit = result.profit or result.expectedProfit
    opportunity.roi = result.roi
    opportunity.vendorUnit = result.vendorUnit or listing.vendorUnit
    opportunity.confidence = result.confidence
    opportunity.estimated = result.estimated == true
    opportunity.stale = result.stale == true
    opportunity.provider = result.provider
    opportunity.asOf = result.asOf
    opportunity.skillVerified = result.skillVerified
    opportunity.scanId = listing.scanId
    opportunity.marketKey = listing.marketKey
    opportunity.observedAt = listing.observedAt
    opportunity.source = listing.source
    opportunity.priceMode = listing.priceMode
    opportunity.ownAuction = listing.ownAuction
    opportunity._index = index
    return opportunity
end

---@param listing table
---@param strategy string vendor|disenchant
---@param context table
---@return table|nil opportunity
---@return string|nil reason
function ProfitEngine.Evaluate(listing, strategy, context)
    local resolver = STRATEGIES[strategy]
    if not resolver then
        return nil, "unknown_strategy"
    end
    local evaluator = resolver()
    if not evaluator then
        return nil, "strategy_unavailable"
    end
    local result, reason = evaluator.Evaluate(listing, context)
    if not result then
        return nil, reason
    end
    local opportunity = copyCoreFields({}, listing, result, context and context.index or 0)
    return opportunity, nil
end

---@return table[] opportunities, table counts
function ProfitEngine.BuildAll(listings, strategy, context)
    local opportunities = {}
    local counts = {
        evaluated = 0,
        profitable = 0,
        notProfitable = 0,
        vendorUnknown = 0,
        notVendorable = 0,
        ownAuction = 0,
        invalid = 0,
        other = 0,
    }
    for index = 1, #listings do
        local listing = listings[index]
        if not listing.vendorUnit and strategy == GF.STRATEGY_VENDOR then
            counts.vendorUnknown = counts.vendorUnknown + 1
        else
            local scopedContext = context or {}
            scopedContext.index = index
            local opportunity, reason = ProfitEngine.Evaluate(listing, strategy, scopedContext)
            counts.evaluated = counts.evaluated + 1
            if opportunity then
                opportunities[#opportunities + 1] = opportunity
                counts.profitable = counts.profitable + 1
            elseif reason == "not_profitable" then
                counts.notProfitable = counts.notProfitable + 1
            elseif reason == "not_vendorable" then
                counts.notVendorable = counts.notVendorable + 1
            elseif reason == "own_auction" then
                counts.ownAuction = counts.ownAuction + 1
            elseif reason == "vendor_unknown" or reason == "value_unavailable" then
                counts.vendorUnknown = counts.vendorUnknown + 1
            elseif reason == "invalid_quantity" or reason == "invalid_buyout"
                or reason == "invalid_vendor_price" or reason == "invalid_listing" then
                counts.invalid = counts.invalid + 1
            else
                counts.other = counts.other + 1
            end
        end
    end
    return opportunities, counts
end

local function searchMatches(opportunity, search)
    if not search or search == "" then
        return true
    end
    local needle = search:lower()
    if opportunity.itemName and opportunity.itemName:lower():find(needle, 1, true) then
        return true
    end
    if opportunity.itemLink and opportunity.itemLink:lower():find(needle, 1, true) then
        return true
    end
    return tostring(opportunity.itemId) == search
end

local function qualityMatches(opportunity, qualityFilter)
    if not qualityFilter or next(qualityFilter) == nil then
        return true
    end
    local quality = opportunity.itemQuality
    if quality == nil then
        return true
    end
    return qualityFilter[quality] == true
end

function ProfitEngine.Qualifies(opportunity, filters)
    filters = filters or {}
    if not opportunity or not GF.Util.IsCopper(opportunity.buyoutTotal) then
        return false
    end
    if opportunity.profit == nil or opportunity.profit <= 0 then
        return false
    end
    if opportunity.ownAuction == true and filters.showOwned ~= true then
        return false
    end

    local minProfit = filters.minProfit or 0
    if opportunity.profit + EPSILON < minProfit then
        return false
    end

    local minRoi = filters.minRoi or 0
    if (opportunity.roi or 0) + EPSILON < minRoi then
        return false
    end

    local maxBuyout = filters.maxBuyout or 0
    if maxBuyout > 0 and opportunity.buyoutTotal > maxBuyout then
        return false
    end

    if filters.minQuantity and opportunity.quantity < filters.minQuantity then
        return false
    end
    if filters.maxQuantity and filters.maxQuantity > 0 and opportunity.quantity > filters.maxQuantity then
        return false
    end

    if filters.blacklist then
        if filters.blacklist[opportunity.itemId] or filters.blacklist[opportunity.variantKey] then
            return false
        end
    end

    if filters.strategy and opportunity.strategy ~= filters.strategy then
        return false
    end

    if not searchMatches(opportunity, filters.search) then
        return false
    end
    if not qualityMatches(opportunity, filters.quality) then
        return false
    end

    return true
end

function ProfitEngine.Filter(opportunities, filters)
    local result = {}
    for index = 1, #opportunities do
        if ProfitEngine.Qualifies(opportunities[index], filters) then
            result[#result + 1] = opportunities[index]
        end
    end
    return result
end

local SORT_GETTERS = {
    profit = function(opportunity)
        return opportunity.profit or 0
    end,
    roi = function(opportunity)
        return opportunity.roi or 0
    end,
    buyout = function(opportunity)
        return opportunity.buyoutTotal or 0
    end,
    unit = function(opportunity)
        return opportunity.buyoutUnit or 0
    end,
    quantity = function(opportunity)
        return opportunity.quantity or 0
    end,
    vendor = function(opportunity)
        return opportunity.expectedProceeds or 0
    end,
    age = function(opportunity)
        return opportunity.observedAt or 0
    end,
    name = function(opportunity)
        return (opportunity.itemName or ""):lower()
    end,
}

function ProfitEngine.Sort(opportunities, field, direction)
    local getter = SORT_GETTERS[field] or SORT_GETTERS.profit
    local descending = direction ~= "asc"

    local comparator = function(left, right)
        local leftValue = getter(left)
        local rightValue = getter(right)
        if leftValue == rightValue then
            local leftIndex = left._index or 0
            local rightIndex = right._index or 0
            return leftIndex < rightIndex
        end
        if descending then
            return leftValue > rightValue
        end
        return leftValue < rightValue
    end

    return GF.Util.SortStable(opportunities, comparator)
end

function ProfitEngine.Group(opportunities)
    local groupsByKey = {}
    local groups = {}
    for index = 1, #opportunities do
        local opportunity = opportunities[index]
        local key = opportunity.variantKey or tostring(opportunity.itemId)
        local group = groupsByKey[key]
        if not group then
            group = {
                key = "group|" .. tostring(opportunity.scanId) .. "|" .. key,
                isGroup = true,
                variantKey = key,
                itemId = opportunity.itemId,
                itemKey = opportunity.itemKey,
                itemLink = opportunity.itemLink,
                itemName = opportunity.itemName,
                itemQuality = opportunity.itemQuality,
                itemIcon = opportunity.itemIcon,
                strategy = opportunity.strategy,
                marketKey = opportunity.marketKey,
                scanId = opportunity.scanId,
                observedAt = opportunity.observedAt,
                lots = 0,
                quantity = 0,
                buyoutTotal = 0,
                expectedProceeds = 0,
                profit = 0,
                bestRoi = 0,
                bestProfit = 0,
                estimated = opportunity.estimated,
                confidence = opportunity.confidence,
                stale = opportunity.stale,
                _index = index,
            }
            groupsByKey[key] = group
            groups[#groups + 1] = group
        end
        group.lots = group.lots + 1
        group.stale = group.stale or opportunity.stale
        if opportunity.confidence == "low" then group.confidence = "low" end
        group.quantity = group.quantity + opportunity.quantity
        group.buyoutTotal = group.buyoutTotal + opportunity.buyoutTotal
        group.expectedProceeds = group.expectedProceeds + (opportunity.expectedProceeds or 0)
        group.profit = group.profit + opportunity.profit
        group.buyoutUnit = group.buyoutTotal / group.quantity
        if (opportunity.roi or 0) > group.bestRoi then
            group.bestRoi = opportunity.roi
        end
        if opportunity.profit > group.bestProfit then
            group.bestProfit = opportunity.profit
        end
        if opportunity.observedAt and opportunity.observedAt > (group.observedAt or 0) then
            group.observedAt = opportunity.observedAt
        end
    end
    for index = 1, #groups do
        local group = groups[index]
        group.roi = group.buyoutTotal > 0 and (100 * group.profit / group.buyoutTotal) or 0
    end
    return groups
end

function ProfitEngine.Metrics(opportunities, context)
    local metrics = {
        count = 0,
        investment = 0,
        proceeds = 0,
        profit = 0,
        bestProfit = 0,
        affordable = 0,
        affordableCount = 0,
    }
    local money = context and context.money
    for index = 1, #opportunities do
        local opportunity = opportunities[index]
        metrics.count = metrics.count + 1
        metrics.investment = metrics.investment + (opportunity.buyoutTotal or 0)
        metrics.proceeds = metrics.proceeds + (opportunity.expectedProceeds or 0)
        metrics.profit = metrics.profit + (opportunity.profit or 0)
        if (opportunity.profit or 0) > metrics.bestProfit then
            metrics.bestProfit = opportunity.profit
        end
        if money == nil or (opportunity.buyoutTotal or 0) <= money then
            metrics.affordableCount = metrics.affordableCount + 1
            metrics.affordable = metrics.affordable + (opportunity.buyoutTotal or 0)
        end
    end
    metrics.roi = metrics.investment > 0 and (100 * metrics.profit / metrics.investment) or 0
    return metrics
end

--- Re-evaluate a live offer using the same item's metadata. Used by the purchase
--- manager after a live search; the caller must supply the live cost/quantity.
function ProfitEngine.EvaluateLive(listing, strategy, context, liveBuyoutTotal, liveQuantity)
    if not GF.Util.IsCopper(liveBuyoutTotal) or liveBuyoutTotal <= 0 then
        return nil, "invalid_buyout"
    end
    if not GF.Util.IsInteger(liveQuantity) or liveQuantity <= 0 then
        return nil, "invalid_quantity"
    end
    local copy = {}
    for key, value in pairs(listing) do
        copy[key] = value
    end
    copy.buyoutTotal = liveBuyoutTotal
    copy.quantity = liveQuantity
    copy.buyoutUnit = liveBuyoutTotal / liveQuantity
    copy.ownAuction = nil
    return ProfitEngine.Evaluate(copy, strategy, context)
end

function ProfitEngine.Compact(opportunity)
    return {
        key = opportunity.key,
        strategy = opportunity.strategy,
        itemId = opportunity.itemId,
        variantKey = opportunity.variantKey,
        itemLink = opportunity.itemLink,
        itemName = opportunity.itemName,
        itemQuality = opportunity.itemQuality,
        itemLevel = opportunity.itemLevel,
        classId = opportunity.classId,
        subClassId = opportunity.subClassId,
        itemIcon = opportunity.itemIcon,
        quantity = opportunity.quantity,
        buyoutTotal = opportunity.buyoutTotal,
        buyoutUnit = opportunity.buyoutUnit,
        expectedProceeds = opportunity.expectedProceeds,
        profit = opportunity.profit,
        roi = opportunity.roi,
        vendorUnit = opportunity.vendorUnit,
        confidence = opportunity.confidence,
        estimated = opportunity.estimated,
        stale = opportunity.stale,
        provider = opportunity.provider,
        scanId = opportunity.scanId,
        marketKey = opportunity.marketKey,
        observedAt = opportunity.observedAt,
        source = opportunity.source,
        priceMode = opportunity.priceMode,
        auctionId = opportunity.auctionId,
        _index = opportunity._index,
    }
end
