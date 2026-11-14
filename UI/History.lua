local _, GF = ...
local History, W = {rows = {}}, GF.UI.Widgets
GF.UI.History = History
function History.Create(parent)
    local f = CreateFrame("Frame", nil, parent)
    History.frame = f
    local back = W.CreateButton(f, GF.L["Return to current scan"], 210, 26)
    back:SetPoint("TOPLEFT", 5, -5)
    back:SetScript("OnClick", function() GF.App:ClearSnapshotView(); GF.UI.SelectPage("trade") end)
    History.label = W.CreateFontString(f, GF.L["Historical scans are read-only. Select a snapshot to inspect it."], "GameFontHighlightSmall")
    History.label:SetPoint("TOPLEFT", 5, -40)
    History.scroll, History.content = W.CreateScrollFrame(f)
    History.scroll:SetPoint("TOPLEFT", 5, -70)
    History.scroll:SetPoint("BOTTOMRIGHT", -25, 5)
    History.content:SetWidth(900)
    History.scroll:SetScript("OnVerticalScroll", function(self, offset) self:SetVerticalScroll(offset); History.RefreshSnapshots() end)
    return f
end
function History.RefreshSnapshots()
    if not History.frame then return end
    local data = {}
    for _, market in ipairs(GF.App.index:AllMarkets()) do
        for _, snapshot in ipairs(GF.App:GetHistory(market.key)) do
            data[#data + 1] = {market = market.key, snapshot = snapshot}
        end
    end
    data = GF.Util.SortStable(data, function(a, b) return (a.snapshot.observedAt or 0) > (b.snapshot.observedAt or 0) end)
    local offset = math.floor((History.scroll:GetVerticalScroll() or 0) / 28)
    local count = math.max(1, math.ceil(History.scroll:GetHeight() / 28) + 1)
    for i = 1, count do
        local row = History.rows[i]
        if not row then
            row = W.CreateButton(History.content, "", 890, 26)
            row:SetScript("OnClick", function(self)
                GF.App:ViewSnapshot(self.entry.market, self.entry.snapshot.id)
                GF.UI.SelectPage("trade")
            end)
            History.rows[i] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(offset + i - 1) * 28)
        local entry = data[offset + i]
        row:SetShown(entry ~= nil)
        if entry then
            row.entry = entry
            local s = entry.snapshot
            row:SetText(string.format("%s | %s | Vendor %d / DE %d%s", date("%m-%d %H:%M", s.observedAt or 0), entry.market,
                #(s.opportunities or {}), #(s.disenchant or {}), s.partial and " [Partial]" or ""))
        end
    end
    for i = count + 1, #History.rows do History.rows[i]:Hide() end
    History.content:SetHeight(math.max(#data * 28, History.scroll:GetHeight()))
end
function History.RefreshMarkets() History.RefreshSnapshots() end
function History.GetFrame() return History.frame end
