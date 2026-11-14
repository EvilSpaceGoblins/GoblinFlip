-- Expected disenchant value. This is an estimate, never a guaranteed margin,
-- and is kept strictly separate from vendor flips.

local _, GF = ...

GF.Domain = GF.Domain or {}
local Disenchant = {}
GF.Domain.DisenchantStrategy = Disenchant

--- Expected value per item from the provider data.
--- Providers that already return a net value must set expectedNetPerItem; a
--- saleFeeRate is only applied when only a gross value is supplied.
local function expectedNetPerItem(data)
    local value = data.expectedNetPerItem
    if value == nil then
        local gross = data.expectedGrossPerItem
        if not GF.Util.IsFiniteNumber(gross) or gross < 0 then
            return nil
        end
        local feeRate = data.saleFeeRate == nil and 0 or tonumber(data.saleFeeRate)
        if not GF.Util.IsFiniteNumber(feeRate) or feeRate < 0 or feeRate > 1 then return nil end
        value = gross * (1 - feeRate)
    end
    if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 then
        return nil
    end
    return value
end

---@param listing table normalized listing
---@param context table {disenchant = data, requireSkill = boolean}
---@return table|nil opportunity
---@return string|nil reason
function Disenchant.Evaluate(listing, context)
    if type(listing) ~= "table" then
        return nil, "invalid_listing"
    end

    local data = context and context.disenchant
    if type(data) ~= "table" or data.available ~= true then
        return nil, (data and data.reason) or "unavailable"
    end

    local quantity = listing.quantity
    local buyoutTotal = listing.buyoutTotal
    if not GF.Util.IsInteger(quantity) or quantity <= 0 then
        return nil, "invalid_quantity"
    end
    if not GF.Util.IsCopper(buyoutTotal) or buyoutTotal <= 0 then
        return nil, "invalid_buyout"
    end
    if listing.ownAuction == true then
        return nil, "own_auction"
    end
    if listing.classId and listing.classId ~= 2 and listing.classId ~= 4 then return nil, "not_disenchantable" end
    if listing.itemQuality and (listing.itemQuality < 2 or listing.itemQuality > 4) then return nil, "not_disenchantable" end

    if context.requireSkill ~= false then
        if data.skillVerified == false then
            return nil, data.skillReason or "skill_unverified"
        end
        if data.skillVerified == nil and context.requireSkill == true then
            return nil, data.skillReason or "skill_unverified"
        end
    end

    local netPerItem = expectedNetPerItem(data)
    if netPerItem == nil then
        return nil, "value_unavailable"
    end

    local otherCostPerItem = data.otherCostPerItem == nil and 0 or tonumber(data.otherCostPerItem)
    if not GF.Util.IsFiniteNumber(otherCostPerItem) or otherCostPerItem < 0 then return nil, "invalid_cost" end

    local expectedGross = netPerItem * quantity
    local otherCosts = otherCostPerItem * quantity
    local expectedNet = expectedGross - otherCosts
    if not GF.Util.IsFiniteNumber(expectedNet) or math.abs(expectedNet) > GF.MAX_COPPER then return nil, "invalid_proceeds" end
    local expectedProfit = expectedNet - buyoutTotal
    if expectedProfit <= 0 then
        return nil, "not_profitable"
    end

    local confidence = "medium"
    if data.stale then
        confidence = "low"
    end

    return {
        strategy = GF.STRATEGY_DISENCHANT,
        proceeds = expectedGross,
        expectedProceeds = expectedNet,
        expectedProfit = expectedProfit,
        profit = expectedProfit,
        roi = 100 * expectedProfit / buyoutTotal,
        confidence = confidence,
        estimated = true,
        provider = data.provider or "unknown",
        asOf = data.asOf,
        stale = data.stale == true,
        skillVerified = data.skillVerified,
        saleFeeRate = data.saleFeeRate,
        assumptions = data.assumptions,
    }, nil
end
