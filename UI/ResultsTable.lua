-- UI Results Table: displays opportunities in a sortable, filterable table.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.ResultsTable = {}

local ResultsTable = GF.UI.ResultsTable
local Widgets = GF.UI.Widgets

ResultsTable.frame = nil
ResultsTable.scrollFrame = nil
ResultsTable.content = nil
ResultsTable.rows = {}
ResultsTable.data = {}
ResultsTable.sortColumn = "profit"
ResultsTable.sortDescending = true
ResultsTable.selectedRow = nil
ResultsTable.onSelect = nil
ResultsTable.onBuy = nil

local COLUMNS = {
    { key = "itemName",    header = "Item",           width = 180, align = "LEFT" },
    { key = "quantity",    header = "Qty",            width = 40,  align = "RIGHT" },
    { key = "buyoutTotal", header = "Buyout",         width = 100, align = "RIGHT", format = "money" },
    { key = "profit",      header = "Profit",         width = 100, align = "RIGHT", format = "money" },
    { key = "roi",         header = "ROI",            width = 60,  align = "RIGHT", format = "roi" },
    { key = "strategy",    header = "Type",           width = 70,  align = "CENTER" },
}

--- Create the results table.
---@param parent Frame
---@return Frame
function ResultsTable.Create(parent)
    if ResultsTable.frame then return ResultsTable.frame end

    local frame = CreateFrame("Frame", "GoblinFlipResultsTable", parent)
    frame:SetSize(600, 400)
    ResultsTable.frame = frame

    -- Header row
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetPoint("TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", 0, 0)
    headerFrame:SetHeight(22)
    headerFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    headerFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

    local x = 0
    for i, col in ipairs(COLUMNS) do
        local btn = CreateFrame("Button", nil, headerFrame)
        btn:SetPoint("LEFT", headerFrame, "LEFT", x, 0)
        btn:SetSize(col.width, 22)
        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:SetText(col.header)
        btn:GetFontString():SetJustifyH(col.align)
        btn:SetScript("OnClick", function() ResultsTable.SortBy(col.key) end)
        x = x + col.width
    end

    -- Scroll frame for rows
    local scroll, content = Widgets.CreateScrollFrame(frame, 600, 378)
    scroll:SetPoint("TOPLEFT", 0, -22)
    ResultsTable.scrollFrame = scroll
    ResultsTable.content = content

    -- Row templates will be created on demand
    ResultsTable.Refresh()

    return frame
end

--- Sort by column.
---@param key string
function ResultsTable.SortBy(key)
    if ResultsTable.sortColumn == key then
        ResultsTable.sortDescending = not ResultsTable.sortDescending
    else
        ResultsTable.sortColumn = key
        ResultsTable.sortDescending = true
    end
    ResultsTable.Refresh()
end

--- Format cell value.
---@param value any
---@param format string|nil
---@return string
local function FormatCell(value, format)
    if value == nil then return "" end
    if format == "money" then return Widgets.FormatMoney(value) end
    if format == "roi" then return Widgets.FormatROI(value) end
    if type(value) == "boolean" then return value and GF.L["Yes"] or GF.L["No"] end
    return tostring(value)
end

--- Get strategy display text.
---@param strategy string
---@return string
local function GetStrategyText(strategy)
    if strategy == GF.STRATEGY_VENDOR then return GF.L["Vendor"] end
    if strategy == GF.STRATEGY_DISENCHANT then return GF.L["Disenchant"] end
    return strategy
end

--- Create or reuse a row frame.
---@param index number
---@return Frame
local function GetOrCreateRow(index)
    if ResultsTable.rows[index] then return ResultsTable.rows[index] end

    local row = CreateFrame("Button", nil, ResultsTable.content)
    row:SetHeight(20)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 20)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * 20)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Highlight
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Selection
    row.selectedTex = row:CreateTexture(nil, "BACKGROUND")
    row.selectedTex:SetAllPoints()
    row.selectedTex:SetColorTexture(0.2, 0.5, 0.8, 0.4)
    row.selectedTex:Hide()

    -- Alternating background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if index % 2 == 0 then
        row.bg:SetColorTexture(1, 1, 1, 0.02)
    else
        row.bg:SetColorTexture(0, 0, 0, 0.02)
    end

    row.cells = {}
    local x = 0
    for i, col in ipairs(COLUMNS) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", row, "LEFT", x + 4, 0)
        fs:SetSize(col.width - 8, 18)
        fs:SetJustifyH(col.align)
        row.cells[i] = fs
        x = x + col.width
    end

    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ResultsTable.SelectRow(self.dataIndex)
        elseif button == "RightButton" and GF.App.ShowFlipContextMenu then
            GF.App:ShowFlipContextMenu()
        end
    end)

    row:SetScript("OnEnter", function(self)
        if self.dataIndex and GF.UI.Widgets then
            -- Could show tooltip here
        end
    end)

    ResultsTable.rows[index] = row
    return row
end

--- Refresh the table with current data.
function ResultsTable.Refresh()
    local view = GF.App and GF.App.GetView and GF.App:GetView() or {}
    local rows = view.rows or {}
    ResultsTable.data = rows

    -- Sort
    table.sort(ResultsTable.data, function(a, b)
        local av = a[ResultsTable.sortColumn]
        local bv = b[ResultsTable.sortColumn]
        if av == nil and bv == nil then return false end
        if av == nil then return ResultsTable.sortDescending end
        if bv == nil then return not ResultsTable.sortDescending end
        if ResultsTable.sortDescending then
            return av > bv
        else
            return av < bv
        end
    end)

    -- Update visible rows
    local maxRows = math.floor(ResultsTable.scrollFrame:GetHeight() / 20) + 2
    for i = 1, maxRows do
        local row = GetOrCreateRow(i)
        local data = ResultsTable.data[i]
        if data then
            row.dataIndex = i
            row:Show()
            local x = 0
            for j, col in ipairs(COLUMNS) do
                local val = data[col.key]
                local text = FormatCell(val, col.format)
                if col.key == "strategy" then text = GetStrategyText(val) end
                row.cells[j]:SetText(text)
                x = x + col.width
            end

            -- Selection highlight
            if ResultsTable.selectedRow == i then
                row.selectedTex:Show()
            else
                row.selectedTex:Hide()
            end
        else
            row:Hide()
        end
    end

    -- Update content height
    ResultsTable.content:SetHeight(math.max(#ResultsTable.data * 20, ResultsTable.scrollFrame:GetHeight()))
end

--- Select a row by index.
---@param index number|nil
function ResultsTable.SelectRow(index)
    if index and index > #ResultsTable.data then return end
    ResultsTable.selectedRow = index
    local data = index and ResultsTable.data[index] or nil
    if ResultsTable.onSelect then
        ResultsTable.onSelect(data)
    end
    ResultsTable.Refresh()
end

--- Get selected row data.
---@return table|nil
function ResultsTable.GetSelected()
    if ResultsTable.selectedRow and ResultsTable.data[ResultsTable.selectedRow] then
        return ResultsTable.data[ResultsTable.selectedRow]
    end
    return nil
end

--- Set selection callback.
---@param callback function(data)
function ResultsTable.SetOnSelect(callback)
    ResultsTable.onSelect = callback
end

--- Set buy callback.
---@param callback function(data)
function ResultsTable.SetOnBuy(callback)
    ResultsTable.onBuy = callback
end

--- Get frame.
---@return Frame|nil
function ResultsTable.GetFrame()
    return ResultsTable.frame
end

return ResultsTable
