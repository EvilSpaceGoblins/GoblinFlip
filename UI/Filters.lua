-- UI Filters panel: min profit, ROI, quality, quantity, owned, search.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.Filters = {}

local Filters = GF.UI.Filters
local Widgets = GF.UI.Widgets

Filters.frame = nil
Filters.widgets = {}
Filters.onChange = nil

--- Create the filters panel.
---@param parent Frame
---@return Frame
function Filters.Create(parent)
    if Filters.frame then return Filters.frame end

    local frame = CreateFrame("Frame", "GoblinFlipFiltersFrame", parent)
    frame:SetSize(300, 400)
    Filters.frame = frame

    local y = -10

    -- Section: Search
    Filters.widgets.searchLabel = Widgets.CreateFontString(frame, GF.L["Search"], "GameFontNormal")
    Filters.widgets.searchLabel:SetPoint("TOPLEFT", 10, y)
    y = y - 18

    Filters.widgets.searchBox = Widgets.CreateEditBox(frame, 280, 24, 50)
    Filters.widgets.searchBox:SetPoint("TOPLEFT", 10, y)
    Filters.widgets.searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        GF.Settings.Set("search", text)
        if Filters.onChange then Filters.onChange() end
    end)
    y = y - 34

    -- Separator
    Widgets.CreateSeparator(frame).SetPoint("TOPLEFT", 10, y).SetPoint("TOPRIGHT", -10, y)
    y = y - 10

    -- Section: Strategy
    Filters.widgets.strategyLabel = Widgets.CreateFontString(frame, GF.L["Strategy"], "GameFontNormal")
    Filters.widgets.strategyLabel:SetPoint("TOPLEFT", 10, y)
    y = y - 18

    Filters.widgets.strategyDropdown = Widgets.CreateDropdown(frame, 280, {
        { value = GF.STRATEGY_VENDOR, text = GF.L["Vendor Flips"] },
        { value = GF.STRATEGY_DISENCHANT, text = GF.L["Disenchant"] },
    }, function(value)
        GF.App:SetStrategy(value)
        if Filters.onChange then Filters.onChange() end
    end)
    Filters.widgets.strategyDropdown:SetPoint("TOPLEFT", -5, y)
    UIDropDownMenu_SetSelectedValue(Filters.widgets.strategyDropdown, GF.App:GetStrategy() or GF.STRATEGY_VENDOR)
    y = y - 40

    -- Separator
    Widgets.CreateSeparator(frame).SetPoint("TOPLEFT", 10, y).SetPoint("TOPRIGHT", -10, y)
    y = y - 10

    -- Section: Min Profit
    Filters.widgets.minProfitLabel = Widgets.CreateFontString(frame, GF.L["Min Profit"], "GameFontNormal")
    Filters.widgets.minProfitLabel:SetPoint("TOPLEFT", 10, y)
    y = y - 18

    Filters.widgets.minProfitBox = Widgets.CreateEditBox(frame, 130, 24, 10, true)
    Filters.widgets.minProfitBox:SetPoint("TOPLEFT", 10, y)
    Filters.widgets.minProfitBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("minProfit", val * 10000) end
        self:SetText(Widgets.FormatMoney(GF.Settings.Get("minProfit") or 0))
        if Filters.onChange then Filters.onChange() end
    end)
    Filters.widgets.minProfitBox:SetScript("OnEscapePressed", function(self)
        self:SetText(Widgets.FormatMoney(GF.Settings.Get("minProfit") or 0))
        self:ClearFocus()
    end)
    y = y - 34

    -- Section: Min ROI
    Filters.widgets.minROILabel = Widgets.CreateFontString(frame, GF.L["Min ROI %"], "GameFontNormal")
    Filters.widgets.minROILabel:SetPoint("TOPLEFT", 10, y)
    y = y - 18

    Filters.widgets.minROIBox = Widgets.CreateEditBox(frame, 130, 24, 5, true)
    Filters.widgets.minROIBox:SetPoint("TOPLEFT", 10, y)
    Filters.widgets.minROIBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("minRoi", val) end
        self:SetText(tostring(GF.Settings.Get("minRoi") or 0))
        if Filters.onChange then Filters.onChange() end
    end)
    y = y - 34

    -- Section: Max Buyout
    Filters.widgets.maxBuyoutLabel = Widgets.CreateFontString(frame, GF.L["Max Buyout"], "GameFontNormal")
    Filters.widgets.maxBuyoutLabel:SetPoint("TOPLEFT", 10, y)
    y = y - 18

    Filters.widgets.maxBuyoutBox = Widgets.CreateEditBox(frame, 130, 24, 10, true)
    Filters.widgets.maxBuyoutBox:SetPoint("TOPLEFT", 10, y)
    Filters.widgets.maxBuyoutBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("maxBuyout", val * 10000) end
        self:SetText(Widgets.FormatMoney(GF.Settings.Get("maxBuyout") or 0))
        if Filters.onChange then Filters.onChange() end
    end)
    y = y - 34

    -- Separator
    Widgets.CreateSeparator(frame).SetPoint("TOPLEFT", 10, y).SetPoint("TOPRIGHT", -10, y)
    y = y - 10

    -- Section: Quality Filter
    Filters.widgets.qualityLabel = Widgets.CreateFontString(frame, GF.L["Quality"], "GameFontNormal")
    Filters.widgets.qualityLabel:SetPoint("TOPLEFT", 10, y)
    y = y - 18

    local qualityItems = {
        { value = 0, text = Widgets.ColorQuality(GF.L["Poor"], 0) },
        { value = 1, text = Widgets.ColorQuality(GF.L["Common"], 1) },
        { value = 2, text = Widgets.ColorQuality(GF.L["Uncommon"], 2) },
        { value = 3, text = Widgets.ColorQuality(GF.L["Rare"], 3) },
        { value = 4, text = Widgets.ColorQuality(GF.L["Epic"], 4) },
    }
    Filters.widgets.qualityDropdown = Widgets.CreateDropdown(frame, 280, qualityItems, function(value)
        GF.Settings.Set("qualityFilter", value)
        if Filters.onChange then Filters.onChange() end
    end)
    Filters.widgets.qualityDropdown:SetPoint("TOPLEFT", -5, y)
    UIDropDownMenu_SetSelectedValue(Filters.widgets.qualityDropdown, GF.Settings.Get("qualityFilter") or 0)
    y = y - 40

    -- Section: Quantity Range
    Filters.widgets.minQtyLabel = Widgets.CreateFontString(frame, GF.L["Min Quantity"], "GameFontNormal")
    Filters.widgets.minQtyLabel:SetPoint("TOPLEFT", 10, y)
    y = y - 18

    Filters.widgets.minQtyBox = Widgets.CreateEditBox(frame, 130, 24, 6, true)
    Filters.widgets.minQtyBox:SetPoint("TOPLEFT", 10, y)
    Filters.widgets.minQtyBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("minQuantity", val) end
        self:SetText(tostring(GF.Settings.Get("minQuantity") or 0))
        if Filters.onChange then Filters.onChange() end
    end)
    y = y - 34

    Filters.widgets.maxQtyLabel = Widgets.CreateFontString(frame, GF.L["Max Quantity"], "GameFontNormal")
    Filters.widgets.maxQtyLabel:SetPoint("TOPLEFT", 10, y)
    y = y - 18

    Filters.widgets.maxQtyBox = Widgets.CreateEditBox(frame, 130, 24, 6, true)
    Filters.widgets.maxQtyBox:SetPoint("TOPLEFT", 10, y)
    Filters.widgets.maxQtyBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("maxQuantity", val) end
        self:SetText(tostring(GF.Settings.Get("maxQuantity") or 0))
        if Filters.onChange then Filters.onChange() end
    end)
    y = y - 34

    -- Section: Show Owned
    Filters.widgets.showOwnedCheck = Widgets.CreateCheckButton(frame, GF.L["Show Owned"], GF.L["Include items you already have listed"])
    Filters.widgets.showOwnedCheck:SetPoint("TOPLEFT", 10, y)
    Filters.widgets.showOwnedCheck:SetChecked(GF.Settings.Get("showOwned") == true)
    Filters.widgets.showOwnedCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("showOwned", self:GetChecked())
        if Filters.onChange then Filters.onChange() end
    end)
    y = y - 30

    -- Reset button
    Filters.widgets.resetBtn = Widgets.CreateButton(frame, GF.L["Reset filters"], 280, 24)
    Filters.widgets.resetBtn:SetPoint("TOPLEFT", 10, y)
    Filters.widgets.resetBtn:SetScript("OnClick", function()
        GF.App:ResetFilters()
        Filters.Refresh()
    end)

    Filters.Refresh()
    return frame
end

--- Refresh widget values from settings.
function Filters.Refresh()
    local w = Filters.widgets
    if not w then return end

    if w.searchBox then w.searchBox:SetText(GF.Settings.Get("search") or "") end
    if w.minProfitBox then w.minProfitBox:SetText(Widgets.FormatMoney(GF.Settings.Get("minProfit") or 0)) end
    if w.minROIBox then w.minROIBox:SetText(tostring(GF.Settings.Get("minRoi") or 0)) end
    if w.maxBuyoutBox then w.maxBuyoutBox:SetText(Widgets.FormatMoney(GF.Settings.Get("maxBuyout") or 0)) end
    if w.minQtyBox then w.minQtyBox:SetText(tostring(GF.Settings.Get("minQuantity") or 0)) end
    if w.maxQtyBox then w.maxQtyBox:SetText(tostring(GF.Settings.Get("maxQuantity") or 0)) end
    if w.showOwnedCheck then w.showOwnedCheck:SetChecked(GF.Settings.Get("showOwned") == true) end
    if w.strategyDropdown then
        UIDropDownMenu_SetSelectedValue(w.strategyDropdown, GF.App:GetStrategy() or GF.STRATEGY_VENDOR)
    end
    if w.qualityDropdown then
        UIDropDownMenu_SetSelectedValue(w.qualityDropdown, GF.Settings.Get("qualityFilter") or 0)
    end
end

--- Set change callback.
---@param callback function
function Filters.SetOnChange(callback)
    Filters.onChange = callback
end

--- Get frame.
---@return Frame|nil
function Filters.GetFrame()
    return Filters.frame
end

return Filters