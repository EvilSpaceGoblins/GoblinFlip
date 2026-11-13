-- UI Tooltip: enhanced item tooltip integration with vendor/DE breakdown.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.Tooltip = {}

local Tooltip = GF.UI.Tooltip
local Widgets = GF.UI.Widgets

Tooltip.enabled = false
Tooltip.hooked = false
Tooltip.lastItem = nil

--- Initialize tooltip integration.
function Tooltip.Initialize()
    if Tooltip.hooked then return end
    Tooltip.hooked = true

    -- Hook GameTooltip
    Tooltip.HookTooltip(GameTooltip)
    Tooltip.HookTooltip(ItemRefTooltip)
    Tooltip.HookTooltip(ShoppingTooltip1)
    Tooltip.HookTooltip(ShoppingTooltip2)

    print("|cff00ff00GoblinFlip:|r Tooltip integration enabled")
end

--- Hook a tooltip frame.
---@param tip Frame
function Tooltip.HookTooltip(tip)
    if not tip or tip.GoblinFlipHooked then return end
    tip.GoblinFlipHooked = true

    tip:HookScript("OnTooltipSetItem", function(self)
        Tooltip.OnTooltipSetItem(self)
    end)

    tip:HookScript("OnHide", function(self)
        Tooltip.lastItem = nil
    end)
end

--- Called when tooltip shows an item.
---@param tip Frame
function Tooltip.OnTooltipSetItem(tip)
    if not Tooltip.enabled then return end

    local name, link = tip:GetItem()
    if not link then return end

    local itemId = Tooltip.GetItemIdFromLink(link)
    if not itemId then return end

    -- Avoid duplicate processing
    if Tooltip.lastItem == itemId and Tooltip.lastTip == tip then return end
    Tooltip.lastItem = itemId
    Tooltip.lastTip = tip

    -- Get vendor price
    local vendorPrice = Tooltip.GetVendorPrice(itemId, link)

    -- Get DE estimate
    local deData = Tooltip.GetDisenchantEstimate(itemId, link)

    -- Add lines
    Tooltip.AddLines(tip, vendorPrice, deData, link)
end

--- Extract item ID from link.
---@param link string
---@return number|nil
function Tooltip.GetItemIdFromLink(link)
    if type(link) ~= "string" then return nil end
    local itemId = link:match("item:(%d+)")
    return tonumber(itemId)
end

--- Get vendor sell price.
---@param itemId number
---@param link string
---@return number|nil
function Tooltip.GetVendorPrice(itemId, link)
    -- Try ItemInfo cache first
    if GF.ItemInfo and GF.ItemInfo.cache then
        local entry = GF.ItemInfo.cache:Get(itemId, "0:0:0:0")
        if entry and entry.sellPrice and entry.sellPrice > 0 then
            return entry.sellPrice
        end
    end

    -- Fallback to C_Item.GetItemInfo
    if C_Item and C_Item.GetItemInfo then
        local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(link)
        if sellPrice and sellPrice > 0 then
            return sellPrice
        end
    end

    return nil
end

--- Get disenchant estimate.
---@param itemId number
---@param link string
---@return table|nil
function Tooltip.GetDisenchantEstimate(itemId, link)
    -- Try DisenchantBuddy first
    if GF.DisenchantBuddy and GF.DisenchantBuddy.IsAvailable() then
        local data = GF.DisenchantBuddy.GetEstimate(itemId)
        if data then
            data.source = "DisenchantBuddy"
            return data
        end
    end

    -- Fallback to internal data
    if GF.Domain and GF.Domain.DisenchantData then
        -- Need item level and quality from link
        local _, _, quality, itemLevel = C_Item.GetItemInfo(link)
        if quality and quality >= 2 and quality <= 4 and itemLevel then
            local data = GF.Domain.DisenchantData.GetEstimate(itemId, itemLevel, quality)
            if data then
                data.source = "Internal"
                return data
            end
        end
    end

    return nil
end

--- Add GoblinFlip lines to tooltip.
---@param tip Frame
---@param vendorPrice number|nil
---@param deData table|nil
---@param link string
function Tooltip.AddLines(tip, vendorPrice, deData, link)
    local added = false

    -- Vendor flip info
    if vendorPrice and vendorPrice > 0 then
        tip:AddLine(" ")
        tip:AddLine("|cffFFD700GoblinFlip:|r " .. GF.L["Tooltip: Vendor flip"])
        tip:AddDoubleLine("  " .. GF.L["Vendor price"], Widgets.FormatMoney(vendorPrice), 1, 1, 1, 1, 1, 1)
        added = true
    end

    -- Disenchant estimate
    if deData and deData.available and deData.expectedNetPerItem then
        if not added then tip:AddLine(" ") end
        local label = deData.source == "DisenchantBuddy" and "DB" or "Int"
        tip:AddLine("|cffFFD700GoblinFlip:|r " .. string.format(GF.L["Tooltip: Disenchant estimate"], label))
        tip:AddDoubleLine("  " .. GF.L["Avg value"], Widgets.FormatMoney(deData.expectedNetPerItem), 1, 1, 1, 1, 1, 1)
        if deData.expectedGrossPerItem then
            tip:AddDoubleLine("  " .. GF.L["Gross (pre-fee)"], Widgets.FormatMoney(deData.expectedGrossPerItem), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        end
        added = true
    end

    -- Show expected materials if available
    if deData and deData.materials then
        tip:AddLine("  " .. GF.L["Expected materials"])
        for _, mat in ipairs(deData.materials) do
            if mat.price and mat.price > 0 then
                tip:AddDoubleLine("    " .. mat.name .. " ×" .. string.format("%.1f", mat.avgQty or 0),
                    Widgets.FormatMoney(mat.expectedValue or 0), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
            end
        end
    end
end

--- Enable/disable tooltip integration.
---@param enabled boolean
function Tooltip.SetEnabled(enabled)
    Tooltip.enabled = enabled
    if enabled and not Tooltip.hooked then
        Tooltip.Initialize()
    end
end

--- Check if enabled.
---@return boolean
function Tooltip.IsEnabled()
    return Tooltip.enabled
end

--- Update tooltip settings (called from App:ToggleFlipTooltip).
---@param enabled boolean
function Tooltip.UpdateTooltipSettings(enabled)
    Tooltip.SetEnabled(enabled)
end

return Tooltip