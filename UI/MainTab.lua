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

    -- Create main frame
    local frame = CreateFrame("Frame", "GoblinFlipMainTabFrame", AuctionHouseFrame)
    frame:SetSize(800, 500)
    frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 0, -60)
    frame:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", 0, 40)
    frame:Hide()
    MainTab.frame = frame

    -- Tab content will be populated when shown
    frame:SetScript("OnShow", function()
        MainTab.OnShow()
    end)

    frame:SetScript("OnHide", function()
        MainTab.OnHide()
    end)

    -- Create the tab via LibAHTab
    local success = pcall(function()
        libAHTab:CreateTab(MainTab.tabId, frame, GF.L["GoblinFlip"], GF.L["GoblinFlip"])
    end)

    if not success then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("Failed to create AH tab") end
        return nil
    end

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

    -- Left panel: Filters (300px)
    local leftPanel = CreateFrame("Frame", nil, frame)
    leftPanel:SetPoint("TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMLEFT", 0, 0)
    leftPanel:SetWidth(300)

    GF.UI.Filters.Create(leftPanel)
    local filtersFrame = GF.UI.Filters.GetFrame()
    if filtersFrame then
        filtersFrame:SetParent(leftPanel)
        filtersFrame:SetAllPoints()
        filtersFrame:Show()
    end

    -- Right panel: Results + Buy Pane
    local rightPanel = CreateFrame("Frame", nil, frame)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Results table (top)
    local resultsFrame = CreateFrame("Frame", nil, rightPanel)
    resultsFrame:SetPoint("TOPLEFT", 0, 0)
    resultsFrame:SetPoint("TOPRIGHT", 0, 0)
    resultsFrame:SetHeight(350)

    GF.UI.ResultsTable.Create(resultsFrame)
    local tableFrame = GF.UI.ResultsTable.GetFrame()
    if tableFrame then
        tableFrame:SetParent(resultsFrame)
        tableFrame:SetAllPoints()
        tableFrame:Show()
    end

    -- Buy pane (bottom)
    local buyFrame = CreateFrame("Frame", nil, rightPanel)
    buyFrame:SetPoint("TOPLEFT", resultsFrame, "BOTTOMLEFT", 0, -5)
    buyFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    GF.UI.BuyPane.Create(buyFrame)
    local buyPaneFrame = GF.UI.BuyPane.GetFrame()
    if buyPaneFrame then
        buyPaneFrame:SetParent(buyFrame)
        buyPaneFrame:SetAllPoints()
        buyPaneFrame:Hide() -- Hidden until selection
    end

    -- Connect callbacks
    GF.UI.ResultsTable.SetOnSelect(function(data)
        if data then
            GF.App:Select(data)
            if GF.UI.BuyPane.SetOpportunity then
                GF.UI.BuyPane.SetOpportunity(data)
            end
        else
            GF.UI.BuyPane.Hide()
        end
    end)

    -- Initial refresh
    if GF.UI.ResultsTable.Refresh then GF.UI.ResultsTable.Refresh() end
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

return MainTab