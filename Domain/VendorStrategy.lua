-- Deterministic vendor flip evaluation.

local _, GF = ...

GF.Domain = GF.Domain or {}
local Vendor = {}
GF.Domain.VendorStrategy = Vendor

---@param listing table normalized listing (buyoutTotal is the whole-lot price)
---@param context table|nil optional {vendorUnit = number}
---@return table|nil opportunity
---@return string|nil reason
function Vendor.Evaluate(listing, context)
    if type(listing) ~= "table" then
        return nil, "invalid_listing"
    end

    local quantity = listing.quantity
    local buyoutTotal = listing.buyoutTotal
    local vendorUnit = listing.vendorUnit
    if vendorUnit == nil and context and context.vendorUnit ~= nil then
        vendorUnit = context.vendorUnit
    end

    if not GF.Util.IsInteger(quantity) or quantity <= 0 then
        return nil, "invalid_quantity"
    end
    if not GF.Util.IsCopper(buyoutTotal) or buyoutTotal <= 0 then
        return nil, "invalid_buyout"
    end
    if vendorUnit == nil then
        return nil, "vendor_unknown"
    end
    if not GF.Util.IsCopper(vendorUnit) then
        return nil, "invalid_vendor_price"
    end
    if vendorUnit == 0 then
        return nil, "not_vendorable"
    end
    if listing.ownAuction == true then
        return nil, "own_auction"
    end

    local proceeds = quantity * vendorUnit
    if not GF.Util.IsCopper(proceeds) then return nil, "invalid_proceeds" end
    local profit = proceeds - buyoutTotal
    if profit <= 0 then
        return nil, "not_profitable"
    end

    return {
        strategy = GF.STRATEGY_VENDOR,
        proceeds = proceeds,
        expectedProceeds = proceeds,
        profit = profit,
        roi = 100 * profit / buyoutTotal,
        vendorUnit = vendorUnit,
        confidence = "verified",
        estimated = false,
    }, nil
end
