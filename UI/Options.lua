-- UI Options: settings configuration panel.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.Options = {}

local Options = GF.UI.Options
local Widgets = GF.UI.Widgets

Options.frame = nil
Options.tabs = {}
Options.currentTab = "general"

--- Create the options panel.
---@param parent Frame
---@return Frame
function Options.Create(parent)
    if Options.frame then return Options.frame end

    local frame = CreateFrame("Frame", "GoblinFlipOptions", parent)
    frame:SetSize(600, 500)
    Options.frame = frame

    local y = -10

    -- Title
    Options.title = Widgets.CreateFontString(frame, GF.L["Settings"], "GameFontNormalLarge")
    Options.title:SetPoint("TOP", 0, y)
    y = y - 30

    -- Tab buttons
    Options.tabButtons = {}
    local tabData = {
        { id = "general", text = GF.L["General"] },
        { id = "scanning", text = GF.L["Scanning"] },
        { id = "alerts", text = GF.L["Alerts"] },
        { id = "advanced", text = GF.L["Advanced"] },
    }

    local x = 10
    for _, tab in ipairs(tabData) do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(80, 24)
        btn:SetPoint("TOPLEFT", x, y)
        btn:SetText(tab.text)
        btn:SetScript("OnClick", function() Options.SelectTab(tab.id) end)
        Options.tabButtons[tab.id] = btn
        x = x + 85
    end

    y = y - 30

    -- Tab content container
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", 10, y)
    contentFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    Options.contentFrame = contentFrame

    -- Create tab contents
    Options.CreateGeneralTab()
    Options.CreateScanningTab()
    Options.CreateAlertsTab()
    Options.CreateAdvancedTab()

    Options.SelectTab("general")
    return frame
end

--- Create General tab content.
function Options.CreateGeneralTab()
    local frame = CreateFrame("Frame", nil, Options.contentFrame)
    frame:SetAllPoints()
    frame:Hide()
    Options.tabs.general = frame

    local y = -10

    -- Session Budget
    local label = Widgets.CreateFontString(frame, GF.L["Session Budget"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    Options.budgetBox = Widgets.CreateEditBox(frame, 150, 24, 10, true)
    Options.budgetBox:SetPoint("TOPLEFT", 0, y)
    Options.budgetBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("sessionBudget", val * 10000) end
        self:SetText(Widgets.FormatMoney(GF.Settings.Get("sessionBudget") or 0))
    end)
    y = y - 34

    -- Max Buyout per Purchase
    label = Widgets.CreateFontString(frame, GF.L["Max Buyout per Purchase"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    Options.maxBuyoutBox = Widgets.CreateEditBox(frame, 150, 24, 10, true)
    Options.maxBuyoutBox:SetPoint("TOPLEFT", 0, y)
    Options.maxBuyoutBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("maxBuyout", val * 10000) end
        self:SetText(Widgets.FormatMoney(GF.Settings.Get("maxBuyout") or 0))
    end)
    y = y - 34

    -- Quote Freshness
    label = Widgets.CreateFontString(frame, GF.L["Quote Freshness (seconds)"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    Options.quoteFreshnessBox = Widgets.CreateEditBox(frame, 60, 24, 3, true)
    Options.quoteFreshnessBox:SetPoint("TOPLEFT", 0, y)
    Options.quoteFreshnessBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 60 then GF.Settings.Set("quoteFreshness", val) end
        self:SetText(tostring(GF.Settings.Get("quoteFreshness") or 10))
    end)
    y = y - 34

    -- Allow Commodity Purchase
    Options.commodityCheck = Widgets.CreateCheckButton(frame, GF.L["Allow Commodity Direct Purchase"], GF.L["Enable direct commodity buyout (experimental)"])
    Options.commodityCheck:SetPoint("TOPLEFT", 0, y)
    Options.commodityCheck:SetChecked(GF.Settings.Get("allowCommodityPurchase") == true)
    Options.commodityCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("allowCommodityPurchase", self:GetChecked())
    end)
    y = y - 30

    -- Standalone Mode
    Options.standaloneCheck = Widgets.CreateCheckButton(frame, GF.L["Standalone Mode (Zero Dependencies)"], GF.L["Use native scan and internal DE data. No Auctionator or DisenchantBuddy required."])
    Options.standaloneCheck:SetPoint("TOPLEFT", 0, y)
    Options.standaloneCheck:SetChecked(GF.Settings.Get("standaloneMode") == true)
    Options.standaloneCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("standaloneMode", self:GetChecked())
        if GF.App and GF.App.CheckDependencies then GF.App:CheckDependencies() end
    end)
    y = y - 30

    -- Tooltip Integration
    Options.tooltipCheck = Widgets.CreateCheckButton(frame, GF.L["Show Flip Tooltip"], GF.L["Show GoblinFlip info on item tooltips (vendor price, DE estimate)"])
    Options.tooltipCheck:SetPoint("TOPLEFT", 0, y)
    Options.tooltipCheck:SetChecked(GF.Settings.Get("showFlipTooltip") == true)
    Options.tooltipCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("showFlipTooltip", self:GetChecked())
        if GF.UI and GF.UI.Tooltip then GF.UI.Tooltip.SetEnabled(self:GetChecked()) end
    end)
    y = y - 30

    -- Context Menu
    Options.contextMenuCheck = Widgets.CreateCheckButton(frame, GF.L["Show Flip Context Menu"], GF.L["Right-click opportunities for context menu"])
    Options.contextMenuCheck:SetPoint("TOPLEFT", 0, y)
    Options.contextMenuCheck:SetChecked(GF.Settings.Get("showFlipContextMenu") == true)
    Options.contextMenuCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("showFlipContextMenu", self:GetChecked())
    end)
    y = y - 30

    -- Debug Logging
    Options.debugCheck = Widgets.CreateCheckButton(frame, GF.L["Debug Logging"], GF.L["Enable debug output to chat"])
    Options.debugCheck:SetPoint("TOPLEFT", 0, y)
    Options.debugCheck:SetChecked(GF.Settings.Get("debug") == true)
    Options.debugCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("debug", self:GetChecked())
    end)
    y = y - 30

    -- Reset Budget Button
    Options.resetBudgetBtn = Widgets.CreateButton(frame, GF.L["Reset Session Budget"], 200, 24)
    Options.resetBudgetBtn:SetPoint("TOPLEFT", 0, y)
    Options.resetBudgetBtn:SetScript("OnClick", function()
        if GF.App and GF.App.ResetSessionBudget then GF.App:ResetSessionBudget() end
    end)
    y = y - 34

    -- Reset All Data Button
    Options.resetAllBtn = Widgets.CreateButton(frame, GF.L["Reset All Data"], 200, 24)
    Options.resetAllBtn:SetPoint("TOPLEFT", 0, y)
    Options.resetAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("GOBLINFLIP_RESET_ALL")
    end)
    y = y - 34
end

--- Create Scanning tab content.
function Options.CreateScanningTab()
    local frame = CreateFrame("Frame", nil, Options.contentFrame)
    frame:SetAllPoints()
    frame:Hide()
    Options.tabs.scanning = frame

    local y = -10

    -- Scan Provider
    local label = Widgets.CreateFontString(frame, GF.L["Scan Provider"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    local providerItems = {
        { value = "auctionator", text = GF.L["Auctionator (Fast)"] },
        { value = "native", text = GF.L["Native Replicate (Standalone)"] },
    }
    Options.providerDropdown = Widgets.CreateDropdown(frame, 250, providerItems, function(value)
        GF.Settings.Set("scanProvider", value)
    end)
    Options.providerDropdown:SetPoint("TOPLEFT", -5, y)
    y = y - 40

    -- Experimental Native Scan
    Options.nativeScanCheck = Widgets.CreateCheckButton(frame, GF.L["Enable Native Scan (Experimental)"], GF.L["Allow native replicate scan without Auctionator"])
    Options.nativeScanCheck:SetPoint("TOPLEFT", 0, y)
    Options.nativeScanCheck:SetChecked(GF.Settings.Get("experimentalNativeScan") == true)
    Options.nativeScanCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("experimentalNativeScan", self:GetChecked())
    end)
    y = y - 30

    -- Market House Override
    label = Widgets.CreateFontString(frame, GF.L["Market House Override"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    local marketItems = {
        { value = "auto", text = GF.L["Automatic"] },
        { value = "horde", text = GF.L["Horde"] },
        { value = "alliance", text = GF.L["Alliance"] },
        { value = "neutral", text = GF.L["Neutral (Blackwater)"] },
    }
    Options.marketDropdown = Widgets.CreateDropdown(frame, 250, marketItems, function(value)
        GF.Settings.Set("marketHouseOverride", value)
        if GF.App and GF.App.DetectMarket then GF.App:DetectMarket(true) end
    end)
    Options.marketDropdown:SetPoint("TOPLEFT", -5, y)
    y = y - 40

    -- Disenchant Settings
    Widgets.CreateSeparator(frame):SetPoint("TOPLEFT", 0, y):SetPoint("TOPRIGHT", 0, y)
    y = y - 10

    label = Widgets.CreateFontString(frame, GF.L["Disenchant Settings"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    Options.deEnabledCheck = Widgets.CreateCheckButton(frame, GF.L["Enable Disenchant Estimates"], GF.L["Show disenchant flip opportunities"])
    Options.deEnabledCheck:SetPoint("TOPLEFT", 0, y)
    Options.deEnabledCheck:SetChecked(GF.Settings.Get("disenchantEnabled") ~= false)
    Options.deEnabledCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("disenchantEnabled", self:GetChecked())
    end)
    y = y - 30

    Options.deRequireSkillCheck = Widgets.CreateCheckButton(frame, GF.L["Require Enchanting Skill"], GF.L["Only show DE flips if you have Enchanting profession"])
    Options.deRequireSkillCheck:SetPoint("TOPLEFT", 0, y)
    Options.deRequireSkillCheck:SetChecked(GF.Settings.Get("requireDisenchantSkill") == true)
    Options.deRequireSkillCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("requireDisenchantSkill", self:GetChecked())
    end)
    y = y - 30

    Options.assumeSkillCheck = Widgets.CreateCheckButton(frame, GF.L["Assume I Can Disenchant"], GF.L["Override skill check - show all DE flips"])
    Options.assumeSkillCheck:SetPoint("TOPLEFT", 0, y)
    Options.assumeSkillCheck:SetChecked(GF.Settings.Get("assumeDisenchantSkill") == true)
    Options.assumeSkillCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("assumeDisenchantSkill", self:GetChecked())
        if GF.DisenchantBuddy and GF.DisenchantBuddy.DetectSkill then GF.DisenchantBuddy.DetectSkill(true) end
    end)
    y = y - 30

    -- History Settings
    Widgets.CreateSeparator(frame):SetPoint("TOPLEFT", 0, y):SetPoint("TOPRIGHT", 0, y)
    y = y - 10

    label = Widgets.CreateFontString(frame, GF.L["History Retention"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    Options.historyDaysBox = Widgets.CreateEditBox(frame, 60, 24, 3, true)
    Options.historyDaysBox:SetPoint("TOPLEFT", 0, y)
    Options.historyDaysBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 90 then GF.Settings.Set("historyDays", val) end
        self:SetText(tostring(GF.Settings.Get("historyDays") or 7))
    end)
    Widgets.CreateFontString(frame, GF.L["Days"], "GameFontNormalSmall"):SetPoint("LEFT", Options.historyDaysBox, "RIGHT", 5, 0)

    Options.historySnapshotsBox = Widgets.CreateEditBox(frame, 60, 24, 3, true)
    Options.historySnapshotsBox:SetPoint("LEFT", Options.historyDaysBox, "RIGHT", 80, 0)
    Options.historySnapshotsBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 100 then GF.Settings.Set("historySnapshots", val) end
        self:SetText(tostring(GF.Settings.Get("historySnapshots") or 10))
    end)
    Widgets.CreateFontString(frame, GF.L["Snapshots/Market"], "GameFontNormalSmall"):SetPoint("LEFT", Options.historySnapshotsBox, "RIGHT", 5, 0)
end

--- Create Alerts tab content.
function Options.CreateAlertsTab()
    local frame = CreateFrame("Frame", nil, Options.contentFrame)
    frame:SetAllPoints()
    frame:Hide()
    Options.tabs.alerts = frame

    local y = -10

    -- Sound Alerts
    local label = Widgets.CreateFontString(frame, GF.L["Sound Alerts"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    Options.soundCheck = Widgets.CreateCheckButton(frame, GF.L["Enable Sound Alerts"], GF.L["Play sound when new opportunities found"])
    Options.soundCheck:SetPoint("TOPLEFT", 0, y)
    Options.soundCheck:SetChecked(GF.Settings.Get("soundAlerts") == true)
    Options.soundCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("soundAlerts", self:GetChecked())
    end)
    y = y - 30

    -- Sound File
    label = Widgets.CreateFontString(frame, GF.L["Sound File"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    Options.soundFileBox = Widgets.CreateEditBox(frame, 300, 24, 100)
    Options.soundFileBox:SetPoint("TOPLEFT", 0, y)
    Options.soundFileBox:SetText(GF.Settings.Get("soundFile") or "Sound\\Interface\\AuctionWindowOpen.wav")
    Options.soundFileBox:SetScript("OnEnterPressed", function(self)
        GF.Settings.Set("soundFile", self:GetText())
    end)
    y = y - 34

    -- Test Sound Button
    Options.testSoundBtn = Widgets.CreateButton(frame, GF.L["Test Sound"], 120, 24)
    Options.testSoundBtn:SetPoint("TOPLEFT", 0, y)
    Options.testSoundBtn:SetScript("OnClick", function()
        local sound = GF.Settings.Get("soundFile") or "Sound\\Interface\\AuctionWindowOpen.wav"
        if PlaySoundFile then PlaySoundFile(sound, "Master") elseif PlaySound then PlaySound("AuctionWindowOpen") end
    end)
    y = y - 34

    -- Alert Thresholds
    Widgets.CreateSeparator(frame):SetPoint("TOPLEFT", 0, y):SetPoint("TOPRIGHT", 0, y)
    y = y - 10

    label = Widgets.CreateFontString(frame, GF.L["Alert Thresholds"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    Options.minProfitAlertBox = Widgets.CreateEditBox(frame, 150, 24, 10, true)
    Options.minProfitAlertBox:SetPoint("TOPLEFT", 0, y)
    Options.minProfitAlertBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("alertMinProfit", val * 10000) end
        self:SetText(Widgets.FormatMoney(GF.Settings.Get("alertMinProfit") or 0))
    end)
    Widgets.CreateFontString(frame, GF.L["Min Profit"], "GameFontNormalSmall"):SetPoint("LEFT", Options.minProfitAlertBox, "RIGHT", 10, 0)

    Options.minROIAlertBox = Widgets.CreateEditBox(frame, 60, 24, 5, true)
    Options.minROIAlertBox:SetPoint("LEFT", Options.minProfitAlertBox, "RIGHT", 80, 0)
    Options.minROIAlertBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("alertMinRoi", val) end
        self:SetText(tostring(GF.Settings.Get("alertMinRoi") or 0))
    end)
    Widgets.CreateFontString(frame, GF.L["Min ROI %"], "GameFontNormalSmall"):SetPoint("LEFT", Options.minROIAlertBox, "RIGHT", 5, 0)
end

--- Create Advanced tab content.
function Options.CreateAdvancedTab()
    local frame = CreateFrame("Frame", nil, Options.contentFrame)
    frame:SetAllPoints()
    frame:Hide()
    Options.tabs.advanced = frame

    local y = -10

    -- Grouped View
    Options.groupedCheck = Widgets.CreateCheckButton(frame, GF.L["Grouped View"], GF.L["Group similar items together"])
    Options.groupedCheck:SetPoint("TOPLEFT", 0, y)
    Options.groupedCheck:SetChecked(GF.Settings.Get("groupedView") == true)
    Options.groupedCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("groupedView", self:GetChecked())
    end)
    y = y - 30

    -- Default Sort
    local label = Widgets.CreateFontString(frame, GF.L["Default Sort"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    local sortItems = {
        { value = "profit", text = GF.L["Profit"] },
        { value = "roi", text = GF.L["ROI"] },
        { value = "buyout", text = GF.L["Buyout"] },
        { value = "quantity", text = GF.L["Quantity"] },
    }
    Options.sortDropdown = Widgets.CreateDropdown(frame, 150, sortItems, function(value)
        GF.Settings.Set("defaultSort", value)
    end)
    Options.sortDropdown:SetPoint("TOPLEFT", -5, y)
    y = y - 40

    -- Sort Direction
    label = Widgets.CreateFontString(frame, GF.L["Sort Direction"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    local dirItems = {
        { value = "desc", text = GF.L["Descending"] },
        { value = "asc", text = GF.L["Ascending"] },
    }
    Options.dirDropdown = Widgets.CreateDropdown(frame, 150, dirItems, function(value)
        GF.Settings.Set("defaultSortDirection", value)
    end)
    Options.dirDropdown:SetPoint("TOPLEFT", -5, y)
    y = y - 40

    -- Show Owned
    Options.ownedCheck = Widgets.CreateCheckButton(frame, GF.L["Show Owned Listings"], GF.L["Include items you have listed on AH"])
    Options.ownedCheck:SetPoint("TOPLEFT", 0, y)
    Options.ownedCheck:SetChecked(GF.Settings.Get("showOwned") == true)
    Options.ownedCheck:SetScript("OnClick", function(self)
        GF.Settings.Set("showOwned", self:GetChecked())
    end)
    y = y - 30

    -- Quality Filter
    label = Widgets.CreateFontString(frame, GF.L["Quality Filter"], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y)
    y = y - 18

    local qualityItems = {
        { value = 0, text = Widgets.ColorQuality(GF.L["Poor"], 0) .. " + " },
        { value = 1, text = Widgets.ColorQuality(GF.L["Common"], 1) .. " + " },
        { value = 2, text = Widgets.ColorQuality(GF.L["Uncommon"], 2) .. " + " },
        { value = 3, text = Widgets.ColorQuality(GF.L["Rare"], 3) .. " + " },
        { value = 4, text = Widgets.ColorQuality(GF.L["Epic"], 4) },
    }
    Options.qualityDropdown = Widgets.CreateDropdown(frame, 250, qualityItems, function(value)
        GF.Settings.Set("qualityFilter", value)
    end)
    Options.qualityDropdown:SetPoint("TOPLEFT", -5, y)
    y = y - 40

    -- Min/Max Quantity
    Options.minQtyBox = Widgets.CreateEditBox(frame, 80, 24, 6, true)
    Options.minQtyBox:SetPoint("TOPLEFT", 0, y)
    Options.minQtyBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("minQuantity", val) end
        self:SetText(tostring(GF.Settings.Get("minQuantity") or 0))
    end)
    Widgets.CreateFontString(frame, GF.L["Min Qty"], "GameFontNormalSmall"):SetPoint("LEFT", Options.minQtyBox, "RIGHT", 10, 0)

    Options.maxQtyBox = Widgets.CreateEditBox(frame, 80, 24, 6, true)
    Options.maxQtyBox:SetPoint("LEFT", Options.minQtyBox, "RIGHT", 80, 0)
    Options.maxQtyBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then GF.Settings.Set("maxQuantity", val) end
        self:SetText(tostring(GF.Settings.Get("maxQuantity") or 0))
    end)
    Widgets.CreateFontString(frame, GF.L["Max Qty"], "GameFontNormalSmall"):SetPoint("LEFT", Options.maxQtyBox, "RIGHT", 10, 0)

    y = y - 40

    -- Diagnostics Button
    Widgets.CreateSeparator(frame):SetPoint("TOPLEFT", 0, y):SetPoint("TOPRIGHT", 0, y)
    y = y - 10

    Options.diagBtn = Widgets.CreateButton(frame, GF.L["Print Diagnostics"], 200, 24)
    Options.diagBtn:SetPoint("TOPLEFT", 0, y)
    Options.diagBtn:SetScript("OnClick", function()
        if GF.App and GF.App.PrintDiagnostics then GF.App:PrintDiagnostics() end
    end)
end

--- Select a tab.
---@param tabId string
function Options.SelectTab(tabId)
    if not Options.tabs[tabId] then return end

    for id, btn in pairs(Options.tabButtons) do
        if id == tabId then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end

    for id, frame in pairs(Options.tabs) do
        if id == tabId then
            frame:Show()
        else
            frame:Hide()
        end
    end

    Options.currentTab = tabId
    Options.Refresh()
end

--- Refresh all widget values from settings.
function Options.Refresh()
    if not Options.frame then return end

    local w = Options
    if w.budgetBox then w.budgetBox:SetText(Widgets.FormatMoney(GF.Settings.Get("sessionBudget") or 0)) end
    if w.maxBuyoutBox then w.maxBuyoutBox:SetText(Widgets.FormatMoney(GF.Settings.Get("maxBuyout") or 0)) end
    if w.quoteFreshnessBox then w.quoteFreshnessBox:SetText(tostring(GF.Settings.Get("quoteFreshness") or 10)) end
    if w.commodityCheck then w.commodityCheck:SetChecked(GF.Settings.Get("allowCommodityPurchase") == true) end
    if w.standaloneCheck then w.standaloneCheck:SetChecked(GF.Settings.Get("standaloneMode") == true) end
    if w.tooltipCheck then w.tooltipCheck:SetChecked(GF.Settings.Get("showFlipTooltip") == true) end
    if w.contextMenuCheck then w.contextMenuCheck:SetChecked(GF.Settings.Get("showFlipContextMenu") == true) end
    if w.debugCheck then w.debugCheck:SetChecked(GF.Settings.Get("debug") == true) end

    if w.providerDropdown then UIDropDownMenu_SetSelectedValue(w.providerDropdown, GF.Settings.Get("scanProvider") or "auctionator") end
    if w.nativeScanCheck then w.nativeScanCheck:SetChecked(GF.Settings.Get("experimentalNativeScan") == true) end
    if w.marketDropdown then UIDropDownMenu_SetSelectedValue(w.marketDropdown, GF.Settings.Get("marketHouseOverride") or "auto") end
    if w.deEnabledCheck then w.deEnabledCheck:SetChecked(GF.Settings.Get("disenchantEnabled") ~= false) end
    if w.deRequireSkillCheck then w.deRequireSkillCheck:SetChecked(GF.Settings.Get("requireDisenchantSkill") == true) end
    if w.assumeSkillCheck then w.assumeSkillCheck:SetChecked(GF.Settings.Get("assumeDisenchantSkill") == true) end
    if w.historyDaysBox then w.historyDaysBox:SetText(tostring(GF.Settings.Get("historyDays") or 7)) end
    if w.historySnapshotsBox then w.historySnapshotsBox:SetText(tostring(GF.Settings.Get("historySnapshots") or 10)) end

    if w.soundCheck then w.soundCheck:SetChecked(GF.Settings.Get("soundAlerts") == true) end
    if w.soundFileBox then w.soundFileBox:SetText(GF.Settings.Get("soundFile") or "Sound\\Interface\\AuctionWindowOpen.wav") end
    if w.minProfitAlertBox then w.minProfitAlertBox:SetText(Widgets.FormatMoney(GF.Settings.Get("alertMinProfit") or 0)) end
    if w.minROIAlertBox then w.minROIAlertBox:SetText(tostring(GF.Settings.Get("alertMinRoi") or 0)) end

    if w.groupedCheck then w.groupedCheck:SetChecked(GF.Settings.Get("groupedView") == true) end
    if w.sortDropdown then UIDropDownMenu_SetSelectedValue(w.sortDropdown, GF.Settings.Get("defaultSort") or "profit") end
    if w.dirDropdown then UIDropDownMenu_SetSelectedValue(w.dirDropdown, GF.Settings.Get("defaultSortDirection") or "desc") end
    if w.ownedCheck then w.ownedCheck:SetChecked(GF.Settings.Get("showOwned") == true) end
    if w.qualityDropdown then UIDropDownMenu_SetSelectedValue(w.qualityDropdown, GF.Settings.Get("qualityFilter") or 0) end
    if w.minQtyBox then w.minQtyBox:SetText(tostring(GF.Settings.Get("minQuantity") or 0)) end
    if w.maxQtyBox then w.maxQtyBox:SetText(tostring(GF.Settings.Get("maxQuantity") or 0)) end
end

--- Get frame.
---@return Frame|nil
function Options.GetFrame()
    return Options.frame
end

return Options