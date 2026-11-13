-- UI Standalone: standalone window for GoblinFlip (when not using AH tab).

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.Standalone = {}

local Standalone = GF.UI.Standalone

Standalone.frame = nil
Standalone.visible = false

--- Create the standalone window.
---@return Frame
function Standalone.Create()
    if Standalone.frame then return Standalone.frame end

    local frame = CreateFrame("Frame", "GoblinFlipStandalone", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(900, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetTitle(GF.L["GoblinFlip"])
    frame:Hide()
    Standalone.frame = frame

    frame.CloseButton:SetScript("OnClick", function()
        Standalone.Hide()
    end)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 10, -30)
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    Standalone.content = content

    local leftPanel = CreateFrame("Frame", nil, content)
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

    local rightPanel = CreateFrame("Frame", nil, content)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", 0, 0)

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

    local bottomPanel = CreateFrame("Frame", nil, rightPanel)
    bottomPanel:SetPoint("TOPLEFT", resultsFrame, "BOTTOMLEFT", 0, -5)
    bottomPanel:SetPoint("BOTTOMRIGHT", 0, 0)

    local dashFrame = CreateFrame("Frame", nil, bottomPanel)
    dashFrame:SetPoint("TOPLEFT", 0, 0)
    dashFrame:SetPoint("BOTTOMLEFT", 0, 0)
    dashFrame:SetWidth(400)

    GF.UI.Dashboard.Create(dashFrame)
    local dash = GF.UI.Dashboard.GetFrame()
    if dash then
        dash:SetParent(dashFrame)
        dash:SetAllPoints()
        dash:Show()
    end

    local buyFrame = CreateFrame("Frame", nil, bottomPanel)
    buyFrame:SetPoint("TOPLEFT", dashFrame, "TOPRIGHT", 5, 0)
    buyFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    GF.UI.BuyPane.Create(buyFrame)
    local buyPane = GF.UI.BuyPane.GetFrame()
    if buyPane then
        buyPane:SetParent(buyFrame)
        buyPane:SetAllPoints()
        buyPane:Hide()
    end

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

    return frame
end

function Standalone.Show()
    if not Standalone.frame then Standalone.Create() end
    Standalone.frame:Show()
    Standalone.visible = true
    if GF.UI.ResultsTable.Refresh then GF.UI.ResultsTable.Refresh() end
    if GF.UI.Dashboard.Refresh then GF.UI.Dashboard.Refresh() end
end

function Standalone.Hide()
    if Standalone.frame then Standalone.frame:Hide() end
    Standalone.visible = false
end

function Standalone.Toggle()
    if Standalone.visible then Standalone.Hide() else Standalone.Show() end
end

function Standalone.IsVisible()
    return Standalone.visible
end

function Standalone.GetFrame()
    return Standalone.frame
end

return Standalone
