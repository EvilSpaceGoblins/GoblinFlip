-- UI Main Tab: Auction House tab integration via LibAHTab.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.MainTab = {}

local MainTab = GF.UI.MainTab

MainTab.tabId = "GoblinFlipMainTab"
MainTab.frame = nil
MainTab.attached = false

--- Create the main AH tab.
---@return Frame|nil
function MainTab.Create()
    if MainTab.frame then return MainTab.frame end

    local libAHTab = _G.LibStub and _G.LibStub:GetLibrary("LibAHTab-1.0", true)
    if not libAHTab then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("LibAHTab not available") end
        return nil
    end

    -- Check if AuctionHouseFrame exists and has tabs
    if not AuctionHouseFrame then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("AuctionHouseFrame not available") end
        return nil
    end

    if not AuctionHouseFrame.Tabs or #AuctionHouseFrame.Tabs == 0 then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("AuctionHouseFrame.Tabs not available or empty") end
        -- Try to wait for tabs to be created
    end

    -- Create main frame (LibAHTab will handle showing/hiding based on tab selection)
    local frame = CreateFrame("Frame", "GoblinFlipMainTabFrame", AuctionHouseFrame)
    frame:SetSize(800, 500)
    frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 0, -60)
    frame:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", 0, 40)
    frame:Hide()
    MainTab.frame = frame

    -- Frame will be shown/hidden by LibAHTab when tab is selected/deselected
    -- No OnShow/OnHide scripts needed - LibAHTab handles this

    -- Create the tab via LibAHTab
    local success, err = pcall(function()
        libAHTab:CreateTab(MainTab.tabId, frame, GF.L["GoblinFlip"], GF.L["GoblinFlip"])
    end)

    if not success then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("Failed to create AH tab: " .. tostring(err)) end
        return nil
    end

    if GF.Debug and GF.Debug.Log then GF.Debug:Log("AH tab created successfully: " .. MainTab.tabId) end

    MainTab.attached = true
    return frame
end

--- Called when tab is shown.
function MainTab.OnShow()
    if not MainTab.initialized then
        MainTab.BuildUI()
        MainTab.initialized = true
    end
    if GF.UI.Dashboard and GF.UI.Dashboard.Refresh then
        GF.UI.Dashboard.Refresh()
    end
    if GF.UI.ResultsTable and GF.UI.ResultsTable.Refresh then
        GF.UI.ResultsTable.Refresh()
    end
end

--- Called when tab is hidden.
function MainTab.OnHide()
    -- Cleanup if needed
end

--- Build the tab UI layout.
function MainTab.BuildUI()
    local frame = MainTab.frame
    if not frame then return end

    -- Sub-tab bar
    local subTabBar = CreateFrame("Frame", nil, frame)
    subTabBar:SetPoint("TOPLEFT", 0, 0)
    subTabBar:SetPoint("TOPRIGHT", 0, 0)
    subTabBar:SetHeight(24)
    MainTab.subTabBar = subTabBar

    -- Sub-tabs: Dashboard, Ledger, History, Options
    MainTab.subTabs = {
        { id = "dashboard", text = GF.L["Dashboard"], frame = nil },
        { id = "ledger", text = GF.L["Ledger"], frame = nil },
        { id = "history", text = GF.L["History"], frame = nil },
        { id = "options", text = GF.L["Settings"], frame = nil },
    }

    local tabButtons = {}
    for i, tab in ipairs(MainTab.subTabs) do
        local btn = CreateFrame("Button", nil, subTabBar, "PanelTabButtonTemplate")
        btn:SetID(i)
        btn:SetText(tab.text)
        btn:SetPoint("TOPLEFT", subTabBar, "TOPLEFT", (i - 1) * 80 + 4, -2)
        PanelTemplates_TabResize(btn, 0)
        btn:SetScript("OnClick", function(self)
            MainTab.SelectSubTab(self:GetID())
        end)
        tabButtons[i] = btn
    end
    MainTab.subTabButtons = tabButtons

    -- Content container (below sub-tabs)
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", subTabBar, "BOTTOMLEFT", 0, -2)
    contentFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    MainTab.contentFrame = contentFrame

    -- Create sub-tab content frames
    for _, tab in ipairs(MainTab.subTabs) do
        local content = CreateFrame("Frame", nil, contentFrame)
        content:SetAllPoints()
        content:Hide()
        tab.frame = content
    end

    -- Build each sub-tab content
    MainTab.BuildDashboardTab()
    MainTab.BuildLedgerTab()
    MainTab.BuildHistoryTab()
    MainTab.BuildOptionsTab()

    -- Select first tab by default
    MainTab.SelectSubTab(1)

    -- Initial refresh
    if GF.UI.ResultsTable.Refresh then
        GF.UI.ResultsTable.Refresh()
    end
    if GF.UI.Dashboard.Refresh then
        GF.UI.Dashboard.Refresh()
    end
    if GF.UI.LedgerView.Refresh then
        GF.UI.LedgerView.Refresh()
    end
    if GF.UI.History.Refresh then
        GF.UI.History.Refresh()
    end
    if GF.UI.Options.Refresh then
        GF.UI.Options.Refresh()
    end
end



--- Select a sub-tab by index.
---@param index number
function MainTab.SelectSubTab(index)
    if not MainTab.subTabs or index < 1 or index > #MainTab.subTabs then return end
    
    -- Update button states
    for i, btn in ipairs(MainTab.subTabButtons or {}) do
        if i == index then
            PanelTemplates_SelectTab(btn)
        else
            PanelTemplates_DeselectTab(btn)
        end
    end
    
    -- Show/hide content frames
    for i, tab in ipairs(MainTab.subTabs) do
        if tab.frame then
            if i == index then
                tab.frame:Show()
            else
                tab.frame:Hide()
            end
        end
    end
    
    MainTab.currentSubTab = index
end

--- Build Dashboard sub-tab content.
function MainTab.BuildDashboardTab()
    local tab = MainTab.subTabs[1]
    if not tab or not tab.frame then return end
    
    if GF.UI.Dashboard and GF.UI.Dashboard.Create then
        local frame = GF.UI.Dashboard.Create(tab.frame)
        if frame then
            frame:SetParent(tab.frame)
            frame:SetAllPoints()
            frame:Show()
        end
    end
end

--- Build Ledger sub-tab content.
function MainTab.BuildLedgerTab()
    local tab = MainTab.subTabs[2]
    if not tab or not tab.frame then return end
    
    if GF.UI.LedgerView and GF.UI.LedgerView.Create then
        local frame = GF.UI.LedgerView.Create(tab.frame)
        if frame then
            frame:SetParent(tab.frame)
            frame:SetAllPoints()
            frame:Show()
        end
    end
end

--- Build History sub-tab content.
function MainTab.BuildHistoryTab()
    local tab = MainTab.subTabs[3]
    if not tab or not tab.frame then return end
    
    if GF.UI.History and GF.UI.History.Create then
        local frame = GF.UI.History.Create(tab.frame)
        if frame then
            frame:SetParent(tab.frame)
            frame:SetAllPoints()
            frame:Show()
        end
    end
end

--- Build Options sub-tab content.
function MainTab.BuildOptionsTab()
    local tab = MainTab.subTabs[4]
    if not tab or not tab.frame then return end
    
    if GF.UI.Options and GF.UI.Options.Create then
        local frame = GF.UI.Options.Create(tab.frame)
        if frame then
            frame:SetParent(tab.frame)
            frame:SetAllPoints()
            frame:Show()
        end
    end
end

--- Show the tab.
function MainTab.Show()
    local libAHTab = _G.LibStub and _G.LibStub:GetLibrary("LibAHTab-1.0", true)
    if libAHTab and libAHTab.GetButton then
        local btn = libAHTab:GetButton(MainTab.tabId)
        if btn then btn:Click() end
    end
end

--- Check if tab exists.
---@return boolean
function MainTab.IsCreated()
    return MainTab.attached == true
end

--- Get frame.
---@return Frame|nil
function MainTab.GetFrame()
    return MainTab.frame
end

-- Expose for Events.lua
GF.UI.AttachToAuctionHouse = MainTab.Create

return MainTab