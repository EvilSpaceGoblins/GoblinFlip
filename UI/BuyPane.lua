-- UI Buy Pane: purchase confirmation and execution panel.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.BuyPane = {}

local BuyPane = GF.UI.BuyPane
local Widgets = GF.UI.Widgets

BuyPane.frame = nil
BuyPane.currentOpportunity = nil

--- Create the buy pane.
---@param parent Frame
---@return Frame
function BuyPane.Create(parent)
    if BuyPane.frame then return BuyPane.frame end

    local frame = CreateFrame("Frame", "GoblinFlipBuyPane", parent)
    frame:SetSize(400, 250)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    BuyPane.frame = frame

    local y = -10

    -- Title
    BuyPane.title = Widgets.CreateFontString(frame, GF.L["Confirm Purchase"], "GameFontNormalLarge")
    BuyPane.title:SetPoint("TOP", 0, y)
    y = y - 30

    -- Item info
    BuyPane.itemIcon = frame:CreateTexture(nil, "ARTWORK")
    BuyPane.itemIcon:SetSize(36, 36)
    BuyPane.itemIcon:SetPoint("TOPLEFT", 15, y)

    BuyPane.itemName = Widgets.CreateFontString(frame, "", "GameFontNormalLarge")
    BuyPane.itemName:SetPoint("TOPLEFT", 60, y)
    BuyPane.itemName:SetWidth(320)
    BuyPane.itemName:SetJustifyH("LEFT")
    y = y - 40

    -- Details
    BuyPane.details = Widgets.CreateFontString(frame, "", "GameFontHighlightSmall")
    BuyPane.details:SetPoint("TOPLEFT", 15, y)
    BuyPane.details:SetWidth(370)
    BuyPane.details:SetJustifyH("LEFT")
    y = y - 50

    -- Profit/ROI display
    BuyPane.profitLabel = Widgets.CreateFontString(frame, "", "GameFontNormal")
    BuyPane.profitLabel:SetPoint("TOPLEFT", 15, y)
    y = y - 25

    -- Separator
    Widgets.CreateSeparator(frame).SetPoint("TOPLEFT", 15, y).SetPoint("TOPRIGHT", -15, y)
    y = y - 15

    -- Quote freshness
    BuyPane.quoteLabel = Widgets.CreateFontString(frame, "", "GameFontHighlightSmall")
    BuyPane.quoteLabel:SetPoint("TOPLEFT", 15, y)
    y = y - 25

    -- Buttons
    BuyPane.buyBtn = Widgets.CreateButton(frame, GF.L["Buy"], 120, 28)
    BuyPane.buyBtn:SetPoint("BOTTOMRIGHT", -15, 15)
    BuyPane.buyBtn:SetScript("OnClick", function()
        if GF.App and GF.App.SubmitPurchase then
            GF.App:SubmitPurchase()
        end
    end)

    BuyPane.cancelBtn = Widgets.CreateButton(frame, GF.L["Cancel"], 120, 28)
    BuyPane.cancelBtn:SetPoint("BOTTOMLEFT", 15, 15)
    BuyPane.cancelBtn:SetScript("OnClick", function()
        if GF.App and GF.App.CancelPurchase then
            GF.App:CancelPurchase()
        end
        BuyPane.Hide()
    end)

    return frame
end

--- Update the buy pane with an opportunity.
---@param opportunity table|nil
function BuyPane.SetOpportunity(opportunity)
    BuyPane.currentOpportunity = opportunity

    if not opportunity then
        BuyPane.Hide()
        return
    end

    -- Item icon
    if opportunity.itemIcon then
        BuyPane.itemIcon:SetTexture(opportunity.itemIcon)
    else
        BuyPane.itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Item name with quality color
    local name = opportunity.itemName or ("Item #" .. tostring(opportunity.itemId))
    if opportunity.itemQuality then
        name = Widgets.ColorQuality(name, opportunity.itemQuality)
    end
    BuyPane.itemName:SetText(name)

    -- Details
    local qty = opportunity.quantity or 1
    local buyout = opportunity.buyoutTotal or 0
    local unitPrice = qty > 0 and math.floor(buyout / qty) or 0
    local details = string.format(
        "%s × %d | Unit: %s | Total: %s",
        GF.L["Quantity"], qty,
        Widgets.FormatMoney(unitPrice),
        Widgets.FormatMoney(buyout)
    )
    BuyPane.details:SetText(details)

    -- Profit
    local profit = opportunity.profit or 0
    local roi = opportunity.roi or 0
    local profitColor = profit >= 0 and "|cff00ff00" or "|cffff0000"
    local profitText = string.format(
        "%s: %s | %s: %s",
        GF.L["Profit"], profitColor .. Widgets.FormatMoney(profit) .. "|r",
        GF.L["ROI"], Widgets.FormatROI(roi)
    )
    BuyPane.profitLabel:SetText(profitText)

    -- Quote freshness
    local quote = GF.App and GF.App.purchase and GF.App.purchase:GetQuote()
    if quote and quote.quotedAt then
        local age = math.floor((time() - quote.quotedAt) * 100) / 100
        BuyPane.quoteLabel:SetText(string.format(
            "%s: %.1fs | %s",
            GF.L["Quote age"], age,
            age > 5 and "|cffff0000" .. GF.L["Quote may be stale"] .. "|r" or "|cff00ff00" .. GF.L["Quote fresh"] .. "|r"
        ))
    else
        BuyPane.quoteLabel:SetText("|cffff0000" .. GF.L["No live quote"] .. "|r")
    end

    BuyPane.buyBtn:Enable()
    BuyPane.Show()
end

--- Show the buy pane.
function BuyPane.Show()
    if BuyPane.frame then BuyPane.frame:Show() end
end

--- Hide the buy pane.
function BuyPane.Hide()
    if BuyPane.frame then BuyPane.frame:Hide() end
    BuyPane.currentOpportunity = nil
end

--- Get frame.
---@return Frame|nil
function BuyPane.GetFrame()
    return BuyPane.frame
end

return BuyPane