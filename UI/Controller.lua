local _, GF = ...
local UI, W = GF.UI, GF.UI.Widgets
function UI.Action(fn, ...)
    local ok, reason = fn(...)
    if ok == false then GF.Util.Print(GF.App:ReasonText(reason) or tostring(reason)) end
    return ok, reason
end
function UI.SetSetting(key, value)
    local ok, reason = GF.App:SetSetting(key, value)
    if not ok then GF.Util.Print(reason) end
    return ok, reason
end
function UI.SelectPage(name)
    if not UI.pages then return end
    UI.page = name
    for id, page in pairs(UI.pages) do page:SetShown(id == name) end
    UI.Notify("navigation")
end
function UI.Open(name)
    GF.App:Initialize()
    UI.Standalone.Show()
    UI.SelectPage(name or "trade")
end
function UI.Build(parent)
    local root = CreateFrame("Frame", nil, parent)
    UI.root, UI.pages = root, {}
    root:SetAllPoints()
    local tabs = {{"trade", "Opportunities"}, {"ledger", "Ledger"}, {"history", "History"}, {"options", "Settings"}, {"health", "Health / setup"}}
    for i, tab in ipairs(tabs) do
        local id = tab[1]
        local b = W.CreateButton(root, GF.L[tab[2]], 132, 24)
        b:SetPoint("TOPLEFT", (i - 1) * 136, 0)
        b:SetScript("OnClick", function() UI.SelectPage(id) end)
        local page = CreateFrame("Frame", nil, root)
        page:SetPoint("TOPLEFT", 0, -62)
        page:SetPoint("BOTTOMRIGHT")
        page:Hide()
        UI.pages[id] = page
    end
    UI.status = W.CreateFontString(root, "", "GameFontHighlightSmall")
    UI.status:SetPoint("TOPLEFT", 5, -30)
    UI.status:SetPoint("TOPRIGHT", -5, -30)
    UI.status:SetJustifyH("LEFT")
    local scan = W.CreateButton(root, GF.L["Scan"], 110, 24)
    scan:SetPoint("TOPLEFT", 685, 0)
    scan:SetScript("OnClick", function() UI.Action(GF.App.RequestScan, GF.App) end)
    local current = W.CreateButton(root, GF.L["Current scan"], 125, 24)
    current:SetPoint("TOPLEFT", 800, 0)
    current:SetScript("OnClick", function() GF.App:ClearSnapshotView(); UI.SelectPage("trade") end)
    local cancelScan = W.CreateButton(root, GF.L["Cancel scan"], 115, 24)
    cancelScan:SetPoint("TOPLEFT", 930, 0)
    cancelScan:SetScript("OnClick", function() GF.App:CancelScan() end)
    local trade = UI.pages.trade
    local scroll, filters = W.CreateScrollFrame(trade, 300)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMLEFT")
    filters:SetHeight(800)
    local f = UI.Filters.Create(filters)
    f:SetPoint("TOPLEFT")
    f:SetHeight(800)
    local results = UI.ResultsTable.Create(trade)
    results:SetPoint("TOPLEFT", 325, 0)
    results:SetPoint("BOTTOMRIGHT", -20, 170)
    local buy = UI.BuyPane.Create(trade)
    buy:SetPoint("TOPLEFT", results, "BOTTOMLEFT", 0, -5)
    buy:SetPoint("BOTTOMRIGHT")
    UI.ResultsTable.SetOnSelect(function(row)
        GF.App:Select(row)
        UI.Action(GF.App.RequestPurchase, GF.App, row)
        UI.BuyPane.Refresh()
    end)
    for _, pair in ipairs({{"ledger", UI.LedgerView}, {"history", UI.History}}) do
        local frame = pair[2].Create(UI.pages[pair[1]])
        frame:SetAllPoints()
    end
    local optionsScroll, optionsContent = W.CreateScrollFrame(UI.pages.options)
    optionsScroll:SetPoint("TOPLEFT")
    optionsScroll:SetPoint("BOTTOMRIGHT", -25, 0)
    optionsContent:SetWidth(720)
    optionsContent:SetHeight(900)
    UI.Options.Create(optionsContent):SetAllPoints()
    UI.healthText = W.CreateFontString(UI.pages.health, "", "GameFontHighlight")
    UI.healthText:SetPoint("TOPLEFT", 15, -15)
    UI.healthText:SetPoint("TOPRIGHT", -15, -15)
    UI.healthText:SetJustifyH("LEFT")
    local recheck = W.CreateButton(UI.pages.health, GF.L["Recheck"], 140, 28)
    recheck:SetPoint("BOTTOMLEFT", 15, 15)
    recheck:SetScript("OnClick", function() GF.App:CheckDependencies() end)
    local setup = W.CreateButton(UI.pages.health, GF.L["Run setup"], 140, 28)
    setup:SetPoint("LEFT", recheck, "RIGHT", 12, 0)
    setup:SetScript("OnClick", function() UI.Onboarding.Show() end)
    root:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.25 then self.elapsed = 0; UI.BuyPane.Refresh() end
    end)
    UI.SelectPage("trade")
end
function UI.Mount(parent)
    if not UI.root then UI.Build(parent) end
    UI.root:SetParent(parent)
    UI.root:ClearAllPoints()
    local scale = math.min(1, parent:GetWidth() / 1060)
    UI.root:SetScale(scale)
    UI.root:SetSize(parent:GetWidth() / scale, parent:GetHeight() / scale)
    UI.root:SetPoint("TOPLEFT")
    UI.root:Show()
    UI.Notify("mount")
end
function UI.Notify(event)
    if UI.refreshing or not UI.root or not UI.root:IsVisible() then return end
    UI.refreshing = true
    local ok, err = pcall(function()
        local view = GF.App:GetView()
        UI.status:SetText(string.format("%s | %s | %d results | ROI %s | Budget %s / %s",
            view.identity and view.identity.houseLabel or "?", (view.viewSnapshot and "READ-ONLY HISTORY | " or "") .. view.scanState .. (view.scanMessage and (": " .. view.scanMessage) or ""),
            #view.rows, GF.Util.FormatPercent(view.metrics.roi), W.FormatMoney(view.sessionSpent),
            view.budget == 0 and "unlimited" or W.FormatMoney(view.budget)))
        if UI.page == "trade" then UI.ResultsTable.Refresh(); UI.BuyPane.Refresh() end
        if UI.page == "ledger" then UI.LedgerView.Refresh() end
        if UI.page == "history" then UI.History.RefreshSnapshots() end
        if UI.page == "health" then
            local lines = {"GoblinFlip " .. GF.version .. " — feature health", ""}
            for _, item in ipairs(GF.App.health or GF.Compat.GetHealth()) do
                lines[#lines + 1] = item.name .. ": " .. item.state .. "\n" .. item.action .. "\n"
            end
            UI.healthText:SetText(table.concat(lines, "\n"))
        end
        if event == "reset" then UI.Filters.Refresh(); UI.Options.Refresh() end
    end)
    UI.refreshing = false
    if not ok then GF.Util.Print("UI: " .. tostring(err)) end
end
function UI.Initialize() GF.App:CheckDependencies() end
