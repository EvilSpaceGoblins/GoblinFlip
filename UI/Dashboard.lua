-- UI Dashboard: main overview with metrics and quick actions.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.Dashboard = {}

local Dashboard = GF.UI.Dashboard
local Widgets = GF.UI.Widgets

Dashboard.frame = nil

--- Create the dashboard panel.
---@param parent Frame
---@return Frame
function Dashboard.Create(parent)
    if Dashboard.frame then return Dashboard.frame end

    local frame = CreateFrame("Frame", "GoblinFlipDashboard", parent)
    frame:SetSize(600, 450)
    Dashboard.frame = frame

    local y = -10

    -- Title
    Dashboard.title = Widgets.CreateFontString(frame, GF.L["GoblinFlip Dashboard"], "GameFontNormalLarge")
    Dashboard.title:SetPoint("TOP", 0, y)
    y = y - 30

    -- Metrics row 1: Scan status
    Dashboard.scanStatus = Widgets.CreateFontString(frame, "", "GameFontNormal")
    Dashboard.scanStatus:SetPoint("TOPLEFT", 20, y)
    y = y - 25

    -- Metrics row 2: Opportunity counts
    Dashboard.counts = Widgets.CreateFontString(frame, "", "GameFontHighlight")
    Dashboard.counts:SetPoint("TOPLEFT", 20, y)
    y = y - 25

    -- Metrics row 3: Budget
    Dashboard.budget = Widgets.CreateFontString(frame, "", "GameFontHighlight")
    Dashboard.budget:SetPoint("TOPLEFT", 20, y)
    y = y - 30

    -- Separator
    Widgets.CreateSeparator(frame).SetPoint("TOPLEFT", 15, y).SetPoint("TOPRIGHT", -15, y)
    y = y - 15

    -- Quick Actions
    Dashboard.actionsLabel = Widgets.CreateFontString(frame, GF.L["Quick Actions"], "GameFontNormal")
    Dashboard.actionsLabel:SetPoint("TOPLEFT", 20, y)
    y = y - 30

    -- Scan button
    Dashboard.scanBtn = Widgets.CreateButton(frame, GF.L["Scan"], 150, 30)
    Dashboard.scanBtn:SetPoint("TOPLEFT", 20, y)
    Dashboard.scanBtn:SetScript("OnClick", function()
        if GF.App and GF.App.RequestScan then
            GF.App:RequestScan()
        end
    end)

    -- Refresh button
    Dashboard.refreshBtn = Widgets.CreateButton(frame, GF.L["Refresh Selected"], 150, 30)
    Dashboard.refreshBtn:SetPoint("LEFT", Dashboard.scanBtn, "RIGHT", 10, 0)
    Dashboard.refreshBtn:SetScript("OnClick", function()
        if GF.App and GF.App.RequestPurchase then
            GF.App:RequestPurchase()
        end
    end)

    -- Buy Next button
    Dashboard.buyNextBtn = Widgets.CreateButton(frame, GF.L["Buy Next"], 150, 30)
    Dashboard.buyNextBtn:SetPoint("LEFT", Dashboard.refreshBtn, "RIGHT", 10, 0)
    Dashboard.buyNextBtn:SetScript("OnClick", function()
        if GF.App and GF.App.RequestPurchase then
            local view = GF.App:GetView()
            if view and view.rows and #view.rows > 0 then
                GF.App:RequestPurchase(view.rows[1])
            end
        end
    end)

    y = y - 45

    -- Separator
    Widgets.CreateSeparator(frame).SetPoint("TOPLEFT", 15, y).SetPoint("TOPRIGHT", -15, y)
    y = y - 15

    -- Ledger summary
    Dashboard.ledgerLabel = Widgets.CreateFontString(frame, GF.L["Ledger Summary"], "GameFontNormal")
    Dashboard.ledgerLabel:SetPoint("TOPLEFT", 20, y)
    y = y - 25

    Dashboard.ledgerSummary = Widgets.CreateFontString(frame, "", "GameFontHighlightSmall")
    Dashboard.ledgerSummary:SetPoint("TOPLEFT", 20, y)
    Dashboard.ledgerSummary:SetWidth(560)
    Dashboard.ledgerSummary:SetJustifyH("LEFT")
    y = y - 80

    -- Market info
    Dashboard.marketLabel = Widgets.CreateFontString(frame, GF.L["Market"], "GameFontNormal")
    Dashboard.marketLabel:SetPoint("TOPLEFT", 20, y)
    y = y - 25

    Dashboard.marketInfo = Widgets.CreateFontString(frame, "", "GameFontHighlightSmall")
    Dashboard.marketInfo:SetPoint("TOPLEFT", 20, y)

    Dashboard.Refresh()
    return frame
end

--- Refresh dashboard with current data.
function Dashboard.Refresh()
    if not Dashboard.frame or not Dashboard.frame:IsVisible() then return end

    local view = GF.App and GF.App.GetView and GF.App:GetView() or {}
    local metrics = view.metrics or {}
    local identity = view.identity
    local strategy = view.strategy

    -- Scan status
    local scanState = view.scanState or "IDLE"
    local scanProgress = view.scanProgress or 0
    local scanMsg = view.scanMessage or ""
    local statusText = string.format("%s: %s%s", GF.L["Scan"], scanState, scanMsg ~= "" and (" - " .. scanMsg) or "")
    if scanState == "NORMALIZING" or scanState == "RESOLVING_ITEMS" then
        statusText = statusText .. string.format(" (%.0f%%)", scanProgress * 100)
    end
    Dashboard.scanStatus:SetText(statusText)

    -- Counts
    local vendorCount = 0
    local deCount = 0
    if view.rows then
        for _, row in ipairs(view.rows) do
            if row.strategy == GF.STRATEGY_VENDOR then
                vendorCount = vendorCount + 1
            elseif row.strategy == GF.STRATEGY_DISENCHANT then
                deCount = deCount + 1
            end
        end
    end
    local countsText = string.format(
        "%s: %d | %s: %d | %s: %.1f%%",
        GF.L["Vendor Flips"], vendorCount,
        GF.L["Disenchant"], deCount,
        GF.L["Total ROI"], metrics.avgRoi or 0
    )
    Dashboard.counts:SetText(countsText)

    -- Budget
    local budget = view.budget or 0
    local spent = view.sessionSpent or 0
    local remaining = budget - spent
    local budgetText = string.format(
        "%s: %s / %s | %s: %s",
        GF.L["Budget"], Widgets.FormatMoney(spent), Widgets.FormatMoney(budget),
        GF.L["Remaining"], Widgets.FormatMoney(math.max(0, remaining))
    )
    Dashboard.budget:SetText(budgetText)

    -- Ledger summary
    local ledgerMetrics = GF.App and GF.App.GetLedgerMetrics and GF.App:GetLedgerMetrics() or {}
    local ledgerText = string.format(
        "%s: %d | %s: %s | %s: %s | %s: %s",
        GF.L["Total Transactions"], ledgerMetrics.totalTransactions or 0,
        GF.L["Total Invested"], Widgets.FormatMoney(ledgerMetrics.totalInvested or 0),
        GF.L["Total Proceeds"], Widgets.FormatMoney(ledgerMetrics.totalProceeds or 0),
        GF.L["Realized Profit"], Widgets.FormatMoney(ledgerMetrics.realizedProfit or 0)
    )
    Dashboard.ledgerSummary:SetText(ledgerText)

    -- Market info
    local marketText = ""
    if identity then
        marketText = string.format(
            "%s: %s | %s: %s | %s: %s | %s: %s",
            GF.L["House"], identity.houseLabel or "?",
            GF.L["Region"], identity.region or "?",
            GF.L["Realm"], identity.realm or "?",
            GF.L["Strategy"], (strategy == GF.STRATEGY_VENDOR and GF.L["Vendor Flips"] or GF.L["Disenchant"])
        )
    else
        marketText = GF.L["Market unknown - select override in Settings"]
    end
    Dashboard.marketInfo:SetText(marketText)
end

--- Get frame.
---@return Frame|nil
function Dashboard.GetFrame()
    return Dashboard.frame
end

return Dashboard