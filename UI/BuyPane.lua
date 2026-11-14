local _, GF = ...
local Pane, W = {}, GF.UI.Widgets
GF.UI.BuyPane = Pane
function Pane.Create(parent)
    local f = CreateFrame("Frame", "GoblinFlipBuyPane", parent)
    Pane.frame = f
    Pane.text = W.CreateFontString(f, "", "GameFontHighlightSmall")
    Pane.text:SetPoint("TOPLEFT", 5, -10)
    Pane.text:SetPoint("TOPRIGHT", -5, -10)
    Pane.text:SetJustifyH("LEFT")
    local function button(text, x, fn)
        local b = W.CreateButton(f, GF.L[text], 140, 26)
        b:SetPoint("BOTTOMLEFT", x, 8)
        b:SetScript("OnClick", fn)
        return b
    end
    Pane.refresh = button("Live quote", 5, function() GF.UI.Action(GF.App.RequestPurchase, GF.App); Pane.Refresh() end)
    Pane.review = button("Review purchase", 150, function() GF.UI.Action(GF.App.BeginConfirm, GF.App); Pane.Refresh() end)
    Pane.buy = button("Confirm purchase", 295, function() GF.UI.Action(GF.App.SubmitPurchase, GF.App); Pane.Refresh() end)
    Pane.cancel = button("Cancel", 440, function() GF.UI.Action(GF.App.CancelPurchase, GF.App); Pane.Refresh() end)
    return f
end
function Pane.Refresh()
    if not Pane.frame then return end
    local p = GF.App.purchase
    if not p then return end
    local state, quote = p:GetState(), p:GetQuote()
    local row = GF.App:GetSelected()
    local lines = {quote and quote.itemName or (row and row.itemName) or GF.L["Select an opportunity to request a live quote."]}
    if quote then
        lines[#lines + 1] = string.format("LIVE: %d items | Cost %s | %s %s | ROI %s | expires in %ds",
            quote.quantity, W.FormatMoney(quote.buyoutTotal), quote.estimated and "Estimated profit" or "Profit",
            W.FormatMoney(quote.profit), GF.Util.FormatPercent(quote.roi), math.max(0, p:GetQuoteRemaining()))
        if quote.changed then lines[#lines + 1] = "Offer changed since scan. Review the live quantity and total before confirming." end
    end
    lines[#lines + 1] = state .. (p:GetLastReason() and (": " .. GF.App:ReasonText(p:GetLastReason())) or "")
    if state == "CONFIRM_REQUIRED" then lines[#lines + 1] = "Confirm purchase spends the live total shown above." end
    if state == "UNKNOWN" then lines[#lines + 1] = "Outcome uncertain. Verify in-game, then resolve this transaction in Ledger." end
    Pane.text:SetText(table.concat(lines, "\n"))
    local valid = p:ValidateQuote()
    Pane.refresh:SetEnabled(row ~= nil and not p:IsBusy() and GF.App.ahOpen == true and not GF.App.viewSnapshot)
    Pane.review:SetEnabled(state == "QUOTED" and valid == true)
    Pane.buy:SetEnabled(state == "CONFIRM_REQUIRED" and valid == true)
    Pane.cancel:SetEnabled(state ~= "SUBMITTED" and state ~= "UNKNOWN")
end
function Pane.SetOpportunity() Pane.Refresh() end
function Pane.Show() if Pane.frame then Pane.frame:Show() end end
function Pane.Hide() end
function Pane.GetFrame() return Pane.frame end
