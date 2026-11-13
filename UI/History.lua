-- UI History: view historical scan snapshots.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.History = {}

local History = GF.UI.History
local Widgets = GF.UI.Widgets

History.frame = nil
History.selectedSnapshot = nil
History.onSnapshotSelect = nil

--- Create the history panel.
---@param parent Frame
---@return Frame
function History.Create(parent)
    if History.frame then return History.frame end

    local frame = CreateFrame("Frame", "GoblinFlipHistory", parent)
    frame:SetSize(600, 450)
    History.frame = frame

    local y = -10

    -- Title
    History.title = Widgets.CreateFontString(frame, GF.L["History"], "GameFontNormalLarge")
    History.title:SetPoint("TOP", 0, y)
    y = y - 30

    -- Market filter dropdown
    History.marketLabel = Widgets.CreateFontString(frame, GF.L["Market"], "GameFontNormal")
    History.marketLabel:SetPoint("TOPLEFT", 15, y)
    y = y - 18

    History.marketDropdown = Widgets.CreateDropdown(frame, 300, {}, function(value)
        History.selectedMarket = value
        History.RefreshSnapshots()
    end)
    History.marketDropdown:SetPoint("TOPLEFT", 0, y)
    y = y - 40

    -- Separator
    Widgets.CreateSeparator(frame).SetPoint("TOPLEFT", 15, y).SetPoint("TOPRIGHT", -15, y)
    y = y - 10

    -- Snapshot list
    History.listLabel = Widgets.CreateFontString(frame, GF.L["Snapshots"], "GameFontNormal")
    History.listLabel:SetPoint("TOPLEFT", 15, y)
    y = y - 18

    local scroll, content = Widgets.CreateScrollFrame(frame, 570, 300)
    scroll:SetPoint("TOPLEFT", 15, y)
    History.scrollFrame = scroll
    History.content = content

    y = y - 310

    -- Separator
    Widgets.CreateSeparator(frame).SetPoint("TOPLEFT", 15, y).SetPoint("TOPRIGHT", -15, y)
    y = y - 10

    -- Action buttons
    History.viewBtn = Widgets.CreateButton(frame, GF.L["View Snapshot"], 150, 24)
    History.viewBtn:SetPoint("BOTTOMLEFT", 15, 15)
    History.viewBtn:SetScript("OnClick", function()
        if History.selectedSnapshot and History.onSnapshotSelect then
            History.onSnapshotSelect(History.selectedMarket, History.selectedSnapshot.id)
        end
    end)

    History.clearBtn = Widgets.CreateButton(frame, GF.L["Clear View"], 150, 24)
    History.clearBtn:SetPoint("LEFT", History.viewBtn, "RIGHT", 10, 0)
    History.clearBtn:SetScript("OnClick", function()
        if GF.App and GF.App.ClearSnapshotView then
            GF.App:ClearSnapshotView()
        end
        History.selectedSnapshot = nil
        History.RefreshSnapshots()
    end)

    return frame
end

--- Refresh market dropdown.
function History.RefreshMarkets()
    if not History.frame then return end
    local index = GF.App and GF.App.GetHistory and GF.App:GetHistory()
    if not index then return end

    local items = {}
    for marketKey in pairs(index) do
        local data = index[marketKey]
        local label = data.market and data.market.label or marketKey
        table.insert(items, { value = marketKey, text = label })
    end
    table.sort(items, function(a, b) return a.text < b.text end)

    local current = History.selectedMarket or (items[1] and items[1].value)
    History.marketDropdown = Widgets.CreateDropdown(History.frame, 300, items, function(value)
        History.selectedMarket = value
        History.RefreshSnapshots()
    end)
    History.marketDropdown:SetPoint("TOPLEFT", 0, -58)
    if current then
        UIDropDownMenu_SetSelectedValue(History.marketDropdown, current)
    end
end

--- Refresh snapshots for selected market.
function History.RefreshSnapshots()
    if not History.frame then return end
    History.RefreshMarkets()

    local index = GF.App and GF.App.GetHistory and GF.App:GetHistory()
    if not index or not History.selectedMarket then
        History.ClearSnapshotRows()
        return
    end

    local marketData = index[History.selectedMarket]
    if not marketData or not marketData.snapshots then
        History.ClearSnapshotRows()
        return
    end

    -- Sort by observedAt descending
    local snapshots = marketData.snapshots
    table.sort(snapshots, function(a, b) return (a.observedAt or 0) > (b.observedAt or 0) end)

    -- Create rows
    local maxRows = math.floor(History.scrollFrame:GetHeight() / 22)
    for i = 1, maxRows do
        local snap = snapshots[i]
        local row = History.GetOrCreateRow(i)
        if snap then
            row.snapshot = snap
            local dateStr = date("%Y-%m-%d %H:%M", snap.observedAt or 0)
            local vendorCount = #(snap.opportunities or {})
            local deCount = #(snap.disenchant or {})
            local text = string.format("%s | Vendor: %d | DE: %d | %s",
                dateStr, vendorCount, deCount, snap.partial and "|cffff8000[Partial]|r" or "")
            row.text:SetText(text)
            row:Show()
        else
            row:Hide()
        end
    end
end

--- Get or create snapshot row.
---@param index number
---@return Frame
function History.GetOrCreateRow(index)
    if History.rows and History.rows[index] then return History.rows[index] end

    if not History.rows then History.rows = {} end

    local row = CreateFrame("Button", nil, History.content)
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
        History.selectedSnapshot = self.snapshot
        for _, r in pairs(History.rows) do
            if r == self then r.selectedTex:Show() else r.selectedTex:Hide() end
        end
    end)

    History.rows[index] = row
    return row
end

--- Clear snapshot rows.
function History.ClearSnapshotRows()
    if History.rows then
        for _, row in pairs(History.rows) do row:Hide() end
    end
    History.selectedSnapshot = nil
end

--- Set snapshot select callback.
---@param callback function(marketKey, snapshotId)
function History.SetOnSnapshotSelect(callback)
    History.onSnapshotSelect = callback
end

--- Get frame.
---@return Frame|nil
function History.GetFrame()
    return History.frame
end

return History