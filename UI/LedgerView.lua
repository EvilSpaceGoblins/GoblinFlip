-- UI Ledger View: transaction history and P&L tracking.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.LedgerView = {}

local LedgerView = GF.UI.LedgerView
local Widgets = GF.UI.Widgets

LedgerView.frame = nil
LedgerView.selectedTransaction = nil
LedgerView.filter = {}

--- Create the ledger view panel.
---@param parent Frame
---@return Frame
function LedgerView.Create(parent)
    if LedgerView.frame then return LedgerView.frame end

    local frame = CreateFrame("Frame", "GoblinFlipLedgerView", parent)
    frame:SetSize(800, 500)
    LedgerView.frame = frame

    local y = -10

    -- Title
    LedgerView.title = Widgets.CreateFontString(frame, GF.L["Ledger"], "GameFontNormalLarge")
    LedgerView.title:SetPoint("TOP", 0, y)
    y = y - 30

    -- Summary metrics
    LedgerView.summary = Widgets.CreateFontString(frame, "", "GameFontHighlightSmall")
    LedgerView.summary:SetPoint("TOPLEFT", 20, y)
    LedgerView.summary:SetWidth(760)
    LedgerView.summary:SetJustifyH("LEFT")
    y = y - 50

    -- Separator
    Widgets.CreateSeparator(frame):SetPoint("TOPLEFT", 15, y):SetPoint("TOPRIGHT", -15, y)
    y = y - 10

    -- Filter row
    LedgerView.filterLabel = Widgets.CreateFontString(frame, GF.L["Filters"], "GameFontNormal")
    LedgerView.filterLabel:SetPoint("TOPLEFT", 20, y)
    y = y - 18

    -- Status filter
    local statusItems = {
        { value = "", text = GF.L["All"] },
        { value = "submitted", text = GF.L["Submitted"] },
        { value = "confirmed", text = GF.L["Confirmed"] },
        { value = "awaiting_mail", text = GF.L["Awaiting Mail"] },
        { value = "received", text = GF.L["Received"] },
        { value = "disposed", text = GF.L["Disposed"] },
        { value = "failed", text = GF.L["Failed"] },
    }
    LedgerView.statusDropdown = Widgets.CreateDropdown(frame, 150, statusItems, function(value)
        LedgerView.filter.status = value ~= "" and value or nil
        LedgerView.Refresh()
    end)
    LedgerView.statusDropdown:SetPoint("TOPLEFT", 0, y)

    -- Strategy filter
    local strategyItems = {
        { value = "", text = GF.L["All"] },
        { value = "vendor", text = GF.L["Vendor"] },
        { value = "disenchant", text = GF.L["Disenchant"] },
    }
    LedgerView.strategyDropdown = Widgets.CreateDropdown(frame, 150, strategyItems, function(value)
        LedgerView.filter.strategy = value ~= "" and value or nil
        LedgerView.Refresh()
    end)
    LedgerView.strategyDropdown:SetPoint("LEFT", LedgerView.statusDropdown, "RIGHT", 10, 0)

    -- Market filter
    LedgerView.marketDropdown = Widgets.CreateDropdown(frame, 200, {}, function(value)
        LedgerView.filter.marketKey = value ~= "" and value or nil
        LedgerView.Refresh()
    end)
    LedgerView.marketDropdown:SetPoint("LEFT", LedgerView.strategyDropdown, "RIGHT", 10, 0)

    -- Reset filter
    LedgerView.resetFilterBtn = Widgets.CreateButton(frame, GF.L["Reset"], 80, 22)
    LedgerView.resetFilterBtn:SetPoint("LEFT", LedgerView.marketDropdown, "RIGHT", 10, 0)
    LedgerView.resetFilterBtn:SetScript("OnClick", function()
        LedgerView.filter = {}
        LedgerView.Refresh()
    end)

    y = y - 35

    -- Separator
    Widgets.CreateSeparator(frame):SetPoint("TOPLEFT", 15, y):SetPoint("TOPRIGHT", -15, y)
    y = y - 10

    -- Transaction table
    local scroll, content = Widgets.CreateScrollFrame(frame, 770, 350)
    scroll:SetPoint("TOPLEFT", 15, y)
    LedgerView.scrollFrame = scroll
    LedgerView.content = content

    y = y - 360

    -- Separator
    Widgets.CreateSeparator(frame):SetPoint("TOPLEFT", 15, y):SetPoint("TOPRIGHT", -15, y)
    y = y - 10

    -- Action buttons
    LedgerView.receiveBtn = Widgets.CreateButton(frame, GF.L["Mark Received"], 150, 24)
    LedgerView.receiveBtn:SetPoint("BOTTOMLEFT", 15, 15)
    LedgerView.receiveBtn:SetScript("OnClick", function()
        LedgerView.MarkReceived()
    end)

    LedgerView.disposeBtn = Widgets.CreateButton(frame, GF.L["Add Proceeds"], 150, 24)
    LedgerView.disposeBtn:SetPoint("LEFT", LedgerView.receiveBtn, "RIGHT", 10, 0)
    LedgerView.disposeBtn:SetScript("OnClick", function()
        LedgerView.AddProceeds()
    end)

    LedgerView.uncertainBtn = Widgets.CreateButton(frame, GF.L["Mark Uncertain"], 150, 24)
    LedgerView.uncertainBtn:SetPoint("LEFT", LedgerView.disposeBtn, "RIGHT", 10, 0)
    LedgerView.uncertainBtn:SetScript("OnClick", function()
        LedgerView.MarkUncertain()
    end)

    LedgerView.manualBtn = Widgets.CreateButton(frame, GF.L["Add Manual Entry"], 150, 24)
    LedgerView.manualBtn:SetPoint("LEFT", LedgerView.uncertainBtn, "RIGHT", 10, 0)
    LedgerView.manualBtn:SetScript("OnClick", function()
        LedgerView.ShowManualEntryDialog()
    end)

    return frame
end

--- Refresh market filter dropdown.
function LedgerView.RefreshMarkets()
    if not LedgerView.frame then return end
    local transactions = GF.App and GF.App.GetLedgerTransactions and GF.App:GetLedgerTransactions({})
    if not transactions then return end

    local markets = {}
    for _, tx in ipairs(transactions) do
        if tx.marketKey and not markets[tx.marketKey] then
            markets[tx.marketKey] = true
        end
    end

    local items = { { value = "", text = GF.L["All Markets"] } }
    for mk in pairs(markets) do
        table.insert(items, { value = mk, text = mk })
    end
    table.sort(items, function(a, b) return a.text < b.text end)

    LedgerView.marketDropdown = Widgets.CreateDropdown(LedgerView.frame, 200, items, function(value)
        LedgerView.filter.marketKey = value ~= "" and value or nil
        LedgerView.Refresh()
    end)
    LedgerView.marketDropdown:SetPoint("LEFT", LedgerView.strategyDropdown, "RIGHT", 10, 0)
    UIDropDownMenu_SetSelectedValue(LedgerView.marketDropdown, LedgerView.filter.marketKey or "")
end

--- Refresh the transaction table.
function LedgerView.Refresh()
    if not LedgerView.frame then return end
    LedgerView.RefreshMarkets()

    local transactions = GF.App and GF.App.GetLedgerTransactions and GF.App:GetLedgerTransactions(LedgerView.filter)
    local metrics = GF.App and GF.App.GetLedgerMetrics and GF.App:GetLedgerMetrics()

    -- Update summary
    if metrics then
        local summary = string.format(
            "%s: %d | %s: %s | %s: %s | %s: %s | %s: %s",
            GF.L["Transactions"], metrics.totalTransactions or 0,
            GF.L["Invested"], Widgets.FormatMoney(metrics.totalInvested or 0),
            GF.L["Proceeds"], Widgets.FormatMoney(metrics.totalProceeds or 0),
            GF.L["Realized Profit"], Widgets.FormatMoney(metrics.realizedProfit or 0),
            GF.L["Pending"], metrics.pendingCount or 0
        )
        LedgerView.summary:SetText(summary)
    end

    -- Sort transactions by time descending
    table.sort(transactions, function(a, b) return (a.submittedAt or 0) > (b.submittedAt or 0) end)

    -- Create/update rows
    local maxRows = math.floor(LedgerView.scrollFrame:GetHeight() / 22)
    for i = 1, maxRows do
        local tx = transactions[i]
        local row = LedgerView.GetOrCreateRow(i)
        if tx then
            row.transaction = tx
            local dateStr = date("%m-%d %H:%M", tx.submittedAt or 0)
            local statusColor = {
                submitted = "|cffffff00",
                confirmed = "|cff00ff00",
                awaiting_mail = "|cff00ffff",
                received = "|cff80ff80",
                partially_disposed = "|cffff8000",
                disposed = "|cff00ff00",
                failed = "|cffff0000",
                uncertain = "|cffff8000",
            }
            local status = tx.status or "?"
            local statusText = (statusColor[status] or "|cffffffff") .. status .. "|r"
            local strategyText = tx.strategy == "vendor" and GF.L["Vendor"] or GF.L["DE"]
            local text = string.format(
                "%s | %s | %s | %s | %s | %s",
                dateStr,
                statusText,
                strategyText,
                tx.itemName or ("#" .. tostring(tx.itemId)),
                Widgets.FormatMoney(tx.purchasedCost or 0),
                Widgets.FormatMoney(tx.realizedProfit or 0)
            )
            row.text:SetText(text)
            row:Show()
        else
            row:Hide()
        end
    end
end

--- Get or create transaction row.
---@param index number
---@return Frame
function LedgerView.GetOrCreateRow(index)
    if LedgerView.rows and LedgerView.rows[index] then return LedgerView.rows[index] end

    if not LedgerView.rows then LedgerView.rows = {} end

    local row = CreateFrame("Button", nil, LedgerView.content)
    row:SetHeight(20)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 22)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * 22)
    row:RegisterForClicks("LeftButtonUp")

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    row.selectedTex = row:CreateTexture(nil, "BACKGROUND")
    row.selectedTex:SetAllPoints()
    row.selectedTex:SetColorTexture(0.2, 0.5, 0.8, 0.4)
    row.selectedTex:Hide()

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 10, 0)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnClick", function(self)
        LedgerView.selectedTransaction = self.transaction
        for _, r in pairs(LedgerView.rows) do
            if r == self then r.selectedTex:Show() else r.selectedTex:Hide() end
        end
    end)

    LedgerView.rows[index] = row
    return row
end

--- Mark selected transaction as received.
function LedgerView.MarkReceived()
    if not LedgerView.selectedTransaction then
        print(GF.L["No transaction selected"])
        return
    end
    if GF.App and GF.App.MarkReceived then
        local ok = GF.App:MarkReceived(LedgerView.selectedTransaction.id)
        if ok then LedgerView.Refresh() end
    end
end

--- Add proceeds to selected transaction.
function LedgerView.AddProceeds()
    if not LedgerView.selectedTransaction then
        print(GF.L["No transaction selected"])
        return
    end
    print(GF.L["Not yet implemented"])
end

--- Mark selected transaction as uncertain.
function LedgerView.MarkUncertain()
    if not LedgerView.selectedTransaction then
        print(GF.L["No transaction selected"])
        return
    end
    if GF.App and GF.App.MarkUncertain then
        local ok = GF.App:MarkUncertain(LedgerView.selectedTransaction.id, "manual")
        if ok then LedgerView.Refresh() end
    end
end

--- Show dialog for manual ledger entry.
function LedgerView.ShowManualEntryDialog()
    if not StaticPopupDialogs["GOBLINFLIP_MANUAL_ENTRY"] then
        StaticPopupDialogs["GOBLINFLIP_MANUAL_ENTRY"] = {
            text = GF.L["Add manual ledger entry"],
            button1 = GF.L["Save"],
            button2 = GF.L["Cancel"],
            hasEditBox = true,
            maxLetters = 200,
            OnAccept = function(self)
                local text = self.editBox:GetText()
                -- Parse format: strategy|itemId|quantity|cost|marketKey|notes
                -- For now just log
                if GF.Debug and GF.Debug.Log then GF.Debug:Log("Manual entry:", text) end
                print("Manual entry saved: " .. text)
            end,
            EditBoxOnEnterPressed = function(self)
                self:GetParent().button1:Click()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent().button2:Click()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show("GOBLINFLIP_MANUAL_ENTRY")
end

--- Get frame.
---@return Frame|nil
function LedgerView.GetFrame()
    return LedgerView.frame
end

return LedgerView
