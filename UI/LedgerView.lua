local _, GF = ...
local Ledger, W = {rows = {}}, GF.UI.Widgets
GF.UI.LedgerView = Ledger
local function selected()
    local tx = Ledger.selectedId and GF.App.ledger:Get(Ledger.selectedId)
    if not tx then GF.Util.Print(GF.L["Select a transaction first."]) end
    return tx
end
local function prompt(title, initial, callback)
    if GF.Settings.readOnly then GF.Util.Print("Saved data is read-only."); return end
    StaticPopupDialogs.GOBLINFLIP_LEDGER_INPUT = {
        text = title, button1 = GF.L["Save"], button2 = GF.L["Cancel"], hasEditBox = true,
        timeout = 0, whileDead = true, hideOnEscape = true,
        OnShow = function(self) self.editBox:SetText(initial or ""); self.editBox:SetFocus() end,
        OnAccept = function(self) callback(self.editBox:GetText()) end,
    }
    StaticPopup_Show("GOBLINFLIP_LEDGER_INPUT")
end
local function confirm(title, callback)
    if GF.Settings.readOnly then GF.Util.Print("Saved data is read-only."); return end
    StaticPopupDialogs.GOBLINFLIP_LEDGER_CONFIRM = {
        text = title, button1 = GF.L["Confirm"], button2 = GF.L["Cancel"], timeout = 0,
        whileDead = true, hideOnEscape = true, OnAccept = callback,
    }
    StaticPopup_Show("GOBLINFLIP_LEDGER_CONFIRM")
end
function Ledger.Create(parent)
    local f = CreateFrame("Frame", nil, parent)
    Ledger.frame = f
    Ledger.summary = W.CreateFontString(f, "", "GameFontHighlightSmall")
    Ledger.summary:SetPoint("TOPLEFT", 5, -5)
    Ledger.summary:SetPoint("TOPRIGHT", -5, -5)
    Ledger.summary:SetJustifyH("LEFT")
    local actions = {
        {"Received", function()
            local tx = selected(); if not tx then return end
            prompt("Quantity actually received for " .. (tx.itemName or tostring(tx.itemId)), tostring(tx.purchasedQuantity - tx.receivedQuantity), function(text)
                local quantity = tonumber(text)
                if not GF.Util.IsInteger(quantity) or quantity <= 0 then GF.Util.Print("Enter a positive whole quantity."); return end
                GF.UI.Action(GF.App.MarkReceived, GF.App, tx.id, quantity); Ledger.Refresh()
            end)
        end},
        {"Add proceeds", function()
            local tx = selected(); if not tx then return end
            prompt("Actual total proceeds | quantity (example: 1g 20s|2)", "", function(text)
                local amount, qty = text:match("^(.-)|(%d+)$")
                local copper, reason = GF.Util.ParseMoney(amount)
                if not copper then GF.Util.Print(reason); return end
                GF.UI.Action(GF.App.AddProceeds, GF.App, tx.id, copper, tonumber(qty)); Ledger.Refresh()
            end)
        end},
        {"Verify bought", function()
            local tx = selected(); if not tx then return end
            confirm("I verified this purchase in-game: " .. (tx.itemName or tostring(tx.itemId)) .. ". Charge " .. W.FormatMoney(tx.purchasedCost) .. " to budget?", function()
                GF.UI.Action(GF.App.ResolveTransaction, GF.App, tx.id, true); Ledger.Refresh()
            end)
        end},
        {"Verify failed", function()
            local tx = selected(); if not tx then return end
            confirm("I verified this purchase failed and no gold was spent. Release its pending status?", function()
                GF.UI.Action(GF.App.ResolveTransaction, GF.App, tx.id, false); Ledger.Refresh()
            end)
        end},
        {"Reverse disposal", function()
            local tx = selected(); if not tx then return end
            confirm("Reverse the last recorded disposal after verifying a full buyback/refund?", function()
                local result, reason = GF.App.ledger:ReverseLastDisposal(tx.id)
                if not result then GF.Util.Print(reason) end
                GF.App:Save(); Ledger.Refresh()
            end)
        end},
        {"Manual entry", function() Ledger.ShowManualEntryDialog() end},
    }
    for i, action in ipairs(actions) do
        local b = W.CreateButton(f, GF.L[action[1]], 145, 26)
        b:SetPoint("TOPLEFT", ((i - 1) % 3) * 150 + 5, -65 - math.floor((i - 1) / 3) * 30)
        b:SetScript("OnClick", action[2])
    end
    Ledger.scroll, Ledger.content = W.CreateScrollFrame(f)
    Ledger.scroll:SetPoint("TOPLEFT", 5, -135)
    Ledger.scroll:SetPoint("BOTTOMRIGHT", -25, 5)
    Ledger.content:SetWidth(950)
    Ledger.scroll:SetScript("OnVerticalScroll", function(self, offset) self:SetVerticalScroll(offset); Ledger.Refresh() end)
    return f
end
function Ledger.Refresh()
    if not Ledger.frame then return end
    local m = GF.App:GetLedgerMetrics()
    Ledger.summary:SetText(string.format("%d transactions | Confirmed cost %s | Proceeds %s | Realized profit %s\nUncertain %s | Selected: %s | Mail/merchant observations: %d / %d",
        m.transactions, W.FormatMoney(m.confirmedSpend), W.FormatMoney(m.realizedProceeds), W.FormatMoney(m.realizedProfit),
        W.FormatMoney(m.uncertainSpend), Ledger.selectedId or "none", #GF.Mailbox.observations, #GF.Merchant.observations))
    local data = GF.App:GetLedgerTransactions({})
    data = GF.Util.SortStable(data, function(a, b) return (a.createdAt or 0) > (b.createdAt or 0) end)
    local offset = math.floor((Ledger.scroll:GetVerticalScroll() or 0) / 28)
    local count = math.max(1, math.ceil(Ledger.scroll:GetHeight() / 28) + 1)
    for i = 1, count do
        local row = Ledger.rows[i]
        if not row then
            row = W.CreateButton(Ledger.content, "", 940, 26)
            row:SetScript("OnClick", function(self) Ledger.selectedId = self.tx.id; Ledger.Refresh() end)
            Ledger.rows[i] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(offset + i - 1) * 28)
        local tx = data[offset + i]
        row:SetShown(tx ~= nil)
        if tx then
            row.tx = tx
            row:SetText(string.format("%s%s | %s | %s | %d/%d received | %s cost | %s profit",
                tx.id == Ledger.selectedId and "> " or "", date("%m-%d %H:%M", tx.createdAt or 0), tx.status,
                tx.itemName or tostring(tx.itemId), tx.receivedQuantity, tx.purchasedQuantity,
                W.FormatMoney(tx.purchasedCost), W.FormatMoney(tx.realizedProceeds - tx.allocatedCost)))
        end
    end
    for i = count + 1, #Ledger.rows do Ledger.rows[i]:Hide() end
    Ledger.content:SetHeight(math.max(#data * 28, Ledger.scroll:GetHeight()))
end
function Ledger.ShowManualEntryDialog()
    prompt("strategy|itemID|quantity|cost (example: vendor|123|2|1g)", "", function(text)
        local strategy, item, qty, amount = text:match("^(%a+)|(%d+)|(%d+)|(.+)$")
        local copper, reason = GF.Util.ParseMoney(amount)
        if not copper then GF.Util.Print(reason); return end
        local tx, err = GF.App.ledger:Create({strategy = strategy, itemId = tonumber(item), purchasedQuantity = tonumber(qty),
            purchasedCost = copper, marketKey = GF.App:GetMarketKey(), characterKey = GF.Settings.GetCharacterKey(),
            status = GF.TX_STATUS.RECEIVED, receivedQuantity = tonumber(qty), manual = true, source = "manual"})
        if not tx then GF.Util.Print(err); return end
        GF.App:Save(); Ledger.Refresh()
    end)
end
function Ledger.GetFrame() return Ledger.frame end
