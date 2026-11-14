local _, GF = ...
local Setup, W = {VERSION = 1}, GF.UI.Widgets
GF.UI.Onboarding = Setup
local pages = {
    {"Welcome to GoblinFlip", "Find vendor flips, then validate a live offer before spending gold. Setup never purchases anything.\n\nYour saved settings and progress survive reloads."},
    {"Check your providers", "Auctionator supplies full scans through its Get All action. Native scanning needs replicate APIs. DisenchantBuddy is optional: vendor flips work without it."},
    {"Choose a scan provider", "Choose a working source below. The separate window and the auction-house tab share the same data; window mode does not change your provider."},
    {"Set your safeguards", "Money fields accept copper or units such as 1g 20s. A zero budget or purchase limit means unlimited. Minimum profit and ROI also apply to live quotes."},
    {"Disenchant estimates", "Disenchanting is random. Internal tables use illustrative prices and cannot be used to buy. Executable estimates require a supported provider, fresh values and skill evidence. Keep vendor-only mode if unsure."},
    {"Run your first scan", "Visit an auction house and check the market in the main window. If unknown, choose the correct house in Settings.\n\nAuctionator: click its Get All button. Native: click Scan below. No scan runs automatically. An empty result can mean no profitable offers, missing item data, or restrictive filters."},
    {"Review before buying", "Select a result to request a live quote. Review the live quantity, total, profit and expiry, then click Review purchase → Confirm purchase.\n\nIf the outcome is uncertain, verify your in-game purchase and resolve it in Ledger. Record mail receipt and actual disposal proceeds there to calculate realized profit.\n\nSetup is complete without making a purchase. Reopen it with /gf setup."},
}
function Setup.State() return GF.Settings.db.onboarding end
function Setup.SaveStep(step)
    Setup.State().step = GF.Util.Clamp(step, 1, #pages)
    GF.App:Save()
end
function Setup.Render()
    local step = Setup.State().step
    Setup.title:SetText(GF.L[pages[step][1]] .. " (" .. step .. "/" .. #pages .. ")")
    local body = GF.L[pages[step][2]]
    if step == 1 then
        local b = GF.Compat.GetBuildInfo()
        body = body .. "\n\nClient: " .. tostring(b.version) .. " / " .. tostring(b.build) .. "\nGoblinFlip: " .. GF.version
    elseif step == 2 then
        GF.App:CheckDependencies()
        for _, h in ipairs(GF.App.health) do body = body .. "\n\n" .. h.name .. ": " .. h.state end
    elseif step == 5 then
        local skill = GF.DisenchantBuddy.GetSkillStatus(true)
        body = body .. "\n\nSkill verified: " .. tostring(skill.verified) .. " (" .. tostring(skill.evidence or skill.reason) .. ")"
    end
    Setup.body:SetText(body)
    Setup.back:SetEnabled(step > 1)
    Setup.next:SetText(GF.L[step == #pages and "Finish" or "Next"])
    for id, group in pairs(Setup.groups) do for _, w in ipairs(group) do w:SetShown(id == step) end end
    if step == 3 then
        local report = GF.Compat.GetReport()
        Setup.auctionator:SetEnabled(report.canScanAuctionator)
        Setup.native:SetEnabled(report.canScanNative)
    elseif step == 4 then
        for key, box in pairs(Setup.money) do box:SetText(GF.Util.FormatMoney(GF.Settings.Get(key))) end
        Setup.roi:SetText(tostring(GF.Settings.Get("minRoi")))
    end
end
function Setup.Create()
    if Setup.frame then return end
    local f = CreateFrame("Frame", "GoblinFlipSetup", UIParent, "BasicFrameTemplateWithInset")
    Setup.frame = f
    f:SetSize(660, 590)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetScale(math.min(1, (UIParent:GetHeight() - 30) / 590))
    if f.TitleText then f.TitleText:SetText(GF.L["GoblinFlip setup"]) end
    Setup.title = W.CreateFontString(f, "", "GameFontNormalLarge")
    Setup.title:SetPoint("TOPLEFT", 25, -45)
    Setup.body = W.CreateFontString(f, "", "GameFontHighlight")
    Setup.body:SetPoint("TOPLEFT", 25, -80)
    Setup.body:SetWidth(610)
    Setup.body:SetJustifyH("LEFT")
    Setup.groups, Setup.money = {}, {}
    local function button(step, text, x, y, fn)
        local b = W.CreateButton(f, GF.L[text], 190, 28)
        b:SetPoint("BOTTOMLEFT", x, y)
        b:SetScript("OnClick", fn)
        Setup.groups[step] = Setup.groups[step] or {}
        table.insert(Setup.groups[step], b)
        return b
    end
    button(2, "Recheck", 25, 80, function() Setup.Render() end)
    Setup.auctionator = button(3, "Use Auctionator", 25, 100, function() GF.UI.SetSetting("scanProvider", "auctionator"); Setup.SaveStep(4); Setup.Render() end)
    Setup.native = button(3, "Use Native", 230, 100, function() GF.UI.SetSetting("scanProvider", "native"); Setup.SaveStep(4); Setup.Render() end)
    Setup.groups[4] = {}
    for i, key in ipairs({"sessionBudget", "maxBuyout", "minProfit"}) do
        local labels = {sessionBudget = "Session budget", maxBuyout = "Per purchase limit", minProfit = "Minimum profit"}
        local label = W.CreateFontString(f, GF.L[labels[key]], "GameFontNormal")
        label:SetPoint("BOTTOMLEFT", 25, 255 - i * 45)
        local box = W.CreateEditBox(f, 220, 26, 40)
        box:SetPoint("LEFT", label, "LEFT", 220, 0)
        Setup.money[key] = box
        table.insert(Setup.groups[4], label); table.insert(Setup.groups[4], box)
    end
    local label = W.CreateFontString(f, GF.L["Minimum ROI %"], "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", 25, 75)
    Setup.roi = W.CreateEditBox(f, 220, 26, 12)
    Setup.roi:SetPoint("LEFT", label, "LEFT", 220, 0)
    table.insert(Setup.groups[4], label); table.insert(Setup.groups[4], Setup.roi)
    button(5, "Vendor only", 25, 100, function() GF.UI.SetSetting("disenchantEnabled", false); Setup.SaveStep(6); Setup.Render() end)
    button(5, "Enable DE estimates", 230, 100, function() GF.UI.SetSetting("disenchantEnabled", true); Setup.SaveStep(6); Setup.Render() end)
    button(6, "Open opportunities", 25, 100, function() GF.UI.Open("trade") end)
    button(6, "Scan", 230, 100, function() GF.UI.Action(GF.App.RequestScan, GF.App) end)
    Setup.back = W.CreateButton(f, GF.L["Back"], 100, 28)
    Setup.back:SetPoint("BOTTOMLEFT", 25, 20)
    Setup.back:SetScript("OnClick", function() Setup.SaveStep(Setup.State().step - 1); Setup.Render() end)
    Setup.next = W.CreateButton(f, GF.L["Next"], 100, 28)
    Setup.next:SetPoint("BOTTOMRIGHT", -25, 20)
    Setup.next:SetScript("OnClick", function()
        local step = Setup.State().step
        if step == 4 then
            local values = {}
            for key, box in pairs(Setup.money) do
                local value, reason = GF.Util.ParseMoney(box:GetText())
                if not value then GF.Util.Print(reason); return end
                values[key] = value
            end
            local roi = tonumber(Setup.roi:GetText())
            if not GF.Util.IsFiniteNumber(roi) or roi < 0 or roi > 1000000 then GF.Util.Print("Invalid ROI."); return end
            for key, value in pairs(values) do GF.UI.SetSetting(key, value) end
            GF.UI.SetSetting("minRoi", roi)
        end
        if step == #pages then
            Setup.State().version = Setup.VERSION
            Setup.State().completed = true
            Setup.State().skipped = false
            GF.App:Save(); f:Hide(); GF.UI.Open("trade")
        else Setup.SaveStep(step + 1); Setup.Render() end
    end)
    local skip = W.CreateButton(f, GF.L["Skip for now"], 130, 28)
    skip:SetPoint("BOTTOM", 0, 20)
    skip:SetScript("OnClick", function() Setup.State().skipped = true; GF.App:Save(); f:Hide() end)
    f.CloseButton:SetScript("OnClick", function() Setup.State().skipped = true; GF.App:Save(); f:Hide() end)
    f:Hide()
end
function Setup.Show()
    if GF.Settings.readOnly then GF.Util.Print("Setup disabled for newer saved data."); return end
    Setup.Create(); Setup.Render(); Setup.frame:Show()
end
function Setup.MaybeShow()
    local state = Setup.State()
    if not state.skipped and (not state.completed or state.version ~= Setup.VERSION) then Setup.Show() end
end
