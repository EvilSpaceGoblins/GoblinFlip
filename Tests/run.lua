local mock = dofile("Tests/WowMock.lua")
mock.Install()
local GF, count = {}, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then for _, message in ipairs(mock.messages) do print(message) end; error(name .. ": " .. tostring(err), 0) end
    count = count + 1
    print("PASS " .. name)
end
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
test("manifest loads without optional addons", function()
    for line in io.lines("GoblinFlip.toc") do
        if line:match("%.lua$") then
            local path = line:gsub("\\", "/")
            assert(loadfile(path))("GoblinFlip", GF)
        end
    end
    assert(GF.App.eventFrame.events.ADDON_LOADED)
    eq(GF.App.initialized, false)
end)
test("addon event initializes once", function()
    mock.Event("ADDON_LOADED", "GoblinFlip")
    eq(GF.App.initialized, true)
    assert(SlashCmdList.GOBLINFLIP)
    local purchase = GF.App.purchase
    mock.Event("ADDON_LOADED", "GoblinFlip")
    eq(purchase, GF.App.purchase)
end)
test("first login opens resumable setup", function()
    mock.Event("PLAYER_LOGIN")
    assert(GF.UI.Onboarding.frame:IsShown())
    eq(GF.Settings.db.onboarding.step, 1)
    GF.UI.Onboarding.next:Click()
    eq(GF.Settings.db.onboarding.step, 2)
    GF.UI.Onboarding.frame.CloseButton:Click()
    assert(GF.Settings.db.onboarding.skipped)
    GF.UI.Onboarding.Show()
    eq(GF.Settings.db.onboarding.step, 2)
end)
test("standalone builds the full workspace", function()
    SlashCmdList.GOBLINFLIP("")
    assert(GF.UI.root)
    assert(GF.UI.ResultsTable.scrollFrame)
    assert(GF.UI.BuyPane.frame)
    for _, page in ipairs({"ledger", "history", "options", "health", "trade"}) do GF.UI.SelectPage(page) end
    assert(GF.UI.root:IsVisible())
end)
test("settings before AH and structured search", function()
    SlashCmdList.GOBLINFLIP("settings")
    eq(GF.UI.page, "options")
    SlashCmdList.GOBLINFLIP("settings minProfit 200")
    eq(GF.Settings.Get("minProfit"), 200)
    assert(GF.App:SetSearch("test"))
    eq(GF.Settings.Get("search"), "test")
    assert(GF.Settings.Set("qualityFilter", {[2] = true}))
    assert(not GF.Settings.Set("qualityFilter", 2))
    GF.Settings.ResetFilters()
end)
test("signed and fractional money rendering", function()
    eq(GF.UI.Widgets.FormatMoney(-100), "-1s")
    eq(GF.UI.Widgets.FormatMoney(100.5), "1s 1c")
    eq(GF.Util.ParseMoney("1g 20s 5c"), 12005)
end)
test("vendor stack math and overflow", function()
    local r = GF.Domain.VendorStrategy.Evaluate({quantity = 20, buyoutTotal = 5000, vendorUnit = 375})
    eq(r.profit, 2500); eq(r.roi, 50)
    assert(not GF.Domain.VendorStrategy.Evaluate({quantity = 100, buyoutTotal = 1, vendorUnit = GF.MAX_COPPER}))
end)
test("DE gross fees applied once; illustrative data stale", function()
    local r = GF.Domain.DisenchantStrategy.Evaluate({quantity = 2, buyoutTotal = 100},
        {disenchant = {available = true, expectedGrossPerItem = 100, saleFeeRate = 0.05}, requireSkill = false})
    eq(r.expectedProceeds, 190); eq(r.profit, 90)
    local d = GF.Domain.DisenchantData.GetEstimate(123, 20, 2, GF.Domain.DisenchantData.defaultPrices)
    assert(d.stale and d.illustrative and d.expectedGrossPerItem)
    assert(not d.expectedNetPerItem)
end)
test("DE rejects malformed costs", function()
    local r = GF.Domain.DisenchantStrategy.Evaluate({quantity = 1, buyoutTotal = 1},
        {disenchant = {available = true, expectedNetPerItem = 100, otherCostPerItem = 0/0}, requireSkill = false})
    assert(not r)
end)
test("commodity detection and disabled setting", function()
    assert(GF.LiveMarket:IsCommodity({itemID = 99}))
    assert(not GF.LiveMarket:IsCommodity({itemID = 123}))
    assert(not GF.Settings.Set("allowCommodityPurchase", true))
end)
test("AH tab attaches and shares existing workspace", function()
    AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
    AuctionHouseFrame.Tabs = {CreateFrame("Button", nil, AuctionHouseFrame)}
    function AuctionHouseFrame:SetDisplayMode() end
    function AuctionHouseFrame:SetTitle() end
    mock.Event("AUCTION_HOUSE_SHOW")
    assert(GF.App.ahOpen)
    assert(GF.UI.MainTab.IsCreated())
    GF.UI.MainTab.Show()
    eq(GF.UI.root:GetParent(), GF.UI.MainTab.frame)
    GF.UI.Standalone.Show()
    eq(GF.UI.root:GetParent(), GF.UI.Standalone.content)
end)
test("late Auctionator registers and health refreshes", function()
    Auctionator = {FullScan = {Events = {ScanComplete = "ScanComplete"}}, EventBus = {Register = function() end}}
    mock.Event("ADDON_LOADED", "Auctionator")
    assert(GF.AuctionatorAdapter.registered)
    eq(GF.App.health[1].state, "ready")
end)
test("minimap invokes launcher and tooltip", function()
    local icon = GF.UI.MinimapIcon.icon
    assert(icon)
    local before = GF.UI.Standalone.IsVisible()
    icon:Click()
    eq(GF.UI.Standalone.IsVisible(), not before)
    icon.scripts.OnEnter(icon)
    assert(GameTooltip.lines and #GameTooltip.lines > 0)
end)
local function manager(cost)
    local submitted = 0
    local p = GF.Domain.PurchaseManager.New({now = function() return mock.now end, getMoney = function() return 10000 end,
        getSessionBudget = function() return 1000 end, getSessionSpent = function() return 0 end,
        getMarketKey = function() return "m" end, query = function() return true end,
        submit = function() submitted = submitted + 1; return true end}, {maxPerPurchase = 500})
    local listing = {strategy = "vendor", itemId = 123, variantKey = "v", auctionId = 1, marketKey = "m", quantity = 1, buyoutTotal = cost or 100, vendorUnit = 500}
    assert(p:RequestQuote(listing, {strategy = "vendor", marketKey = "m", filters = {minProfit = 1}}))
    assert(p:OnQueryResults(p.generation, {{auctionId = 1, variantKey = "v", buyoutTotal = cost or 100, quantity = 1}}, {}))
    return p, function() return submitted end
end
test("purchase requires confirmation and submits once", function()
    local p, submitted = manager()
    eq(select(2, p:Submit()), "confirmation_required")
    assert(p:BeginConfirm()); assert(p:Submit())
    assert(not p:Submit()); eq(submitted(), 1)
end)
test("expired quotes cannot submit", function()
    local p = manager(); assert(p:BeginConfirm())
    mock.now = mock.now + 11
    eq(select(2, p:Submit()), "expired")
end)
test("current purchase limit revalidated", function()
    local p = manager(); assert(p:BeginConfirm()); p.options.maxPerPurchase = 50
    eq(select(2, p:Submit()), "per_purchase_limit")
end)
test("cancel uses the cancelled query generation", function()
    local generation
    local p = GF.Domain.PurchaseManager.New({query = function() return true end, cancelQuery = function(g) generation = g end})
    assert(p:RequestQuote({buyoutTotal = 100, quantity = 1}, {}))
    local before = p.generation
    p:Cancel(); eq(generation, before)
end)
test("ledger partial quantities, losses and reversal", function()
    local ledger = GF.Domain.Ledger.New()
    local tx = assert(ledger:Create({strategy = "vendor", itemId = 123, marketKey = "m", purchasedQuantity = 3, purchasedCost = 100, status = "awaiting_mail"}))
    eq(ledger:MarkReceived(tx.id, 2, "mail1"), 2)
    eq(ledger:MarkReceived(tx.id, 2, "mail1"), 0)
    assert(ledger:AddProceeds(tx.id, 20, 1, "sale1"))
    eq(tx.allocatedCost, 33); eq(ledger:Metrics().realizedProfit, -13)
    assert(not ledger:AddProceeds(tx.id, 20, 1, "sale1"))
    assert(not ledger:ReverseLastDisposal(tx.id, -1)); eq(tx.disposedQuantity, 1)
    assert(ledger:ReverseLastDisposal(tx.id)); eq(tx.disposedQuantity, 0); eq(tx.realizedProceeds, 0)
end)
test("recovery blocks buying until unresolved purchase verified", function()
    local tx = assert(GF.App.ledger:Create({id = "recover", strategy = "vendor", itemId = 123, marketKey = GF.App:GetMarketKey(), purchasedQuantity = 1, purchasedCost = 100}))
    GF.App:RecoverPendingPurchases(); eq(tx.status, "uncertain"); assert(GF.App.recoveryBlocked)
    assert(not GF.App:ResetSessionBudget())
    local spent = GF.Settings.GetSessionSpent()
    assert(GF.App:ResolveTransaction(tx.id, true)); eq(GF.Settings.GetSessionSpent(), spent + 100)
    assert(not GF.App:ResolveTransaction(tx.id, true)); eq(GF.Settings.GetSessionSpent(), spent + 100)
    eq(GF.App.recoveryBlocked, false)
end)
test("scan resolves metadata and publishes results", function()
    GF.Settings.ResetFilters()
    GF.UI.SelectPage("trade")
    assert(GF.App:OnScanPayload({{itemId = 123, quantity = 20, buyoutTotal = 5000, itemLink = "item:123"}}, "fixture", mock.now))
    mock.Advance(0.1)
    eq(GF.App.scanState, "READY")
    eq(#GF.App:GetRows(), 1)
    eq(GF.App:GetRows()[1].itemLevel, 20)
    eq(GF.App:GetRows()[1].profit, 2500)
    assert(#GF.App:GetHistory() > 0)
end)
test("empty scan publishes an empty snapshot", function()
    assert(GF.App:OnScanPayload({}, "fixture", mock.now))
    mock.Advance(0.1)
    eq(GF.App.scanState, "READY"); eq(#GF.App:GetRows(), 0)
end)
test("native scan ignores unsolicited events and times out", function()
    GF.NativeScan:Cancel()
    mock.Event("REPLICATE_ITEM_LIST_UPDATE")
    assert(not GF.NativeScan.collecting)
    assert(GF.App:SetSetting("scanProvider", "native"))
    assert(GF.App:RequestScan())
    assert(not GF.App:RequestScan())
    mock.Advance(31)
    eq(GF.App.scanState, "ERROR")
    eq(GF.NativeScan.requestedAt, nil)
end)
test("native tuple and table payload contracts", function()
    local oldCount, oldInfo = C_AuctionHouse.GetNumReplicateItems, C_AuctionHouse.GetReplicateItemInfo
    C_AuctionHouse.GetNumReplicateItems = function() return 1 end
    C_AuctionHouse.GetReplicateItemLink = function(index) eq(index, 0); return "item:123" end
    for _, mode in ipairs({"tuple", "table"}) do
        C_AuctionHouse.GetReplicateItemInfo = function(index)
            eq(index, 0)
            local data = {[1] = "Test item", [3] = 20, [10] = 5000, [17] = 123}
            if mode == "table" then return data end
            return unpack(data, 1, 17)
        end
        assert(GF.App:RequestScan())
        mock.Event("REPLICATE_ITEM_LIST_UPDATE")
        GF.NativeScan:Step(); mock.Advance(0.1)
        eq(#GF.App:GetRows(), 1)
    end
    C_AuctionHouse.GetNumReplicateItems, C_AuctionHouse.GetReplicateItemInfo = oldCount, oldInfo
end)
test("quote review UI submits once and preserves uncertainty", function()
    GF.UI.Open("trade")
    local p = GF.App.purchase
    local beforeQuery, beforeSubmit = p.env.query, p.env.submit
    local submissions = 0
    p.env.query = function(listing, generation)
        p:OnQueryResults(generation, {{itemId = 123, auctionId = 42, quantity = 20, buyoutTotal = 4000}}, {})
        return true
    end
    p.env.submit = function() submissions = submissions + 1; return true end
    GF.UI.SelectPage("trade")
    GF.UI.ResultsTable.SelectRow(1)
    eq(p:GetState(), "QUOTED")
    GF.UI.BuyPane.review:Click(); eq(p:GetState(), "CONFIRM_REQUIRED")
    GF.UI.BuyPane.buy:Click(); eq(submissions, 1)
    GF.UI.BuyPane.buy:Click(); eq(submissions, 1)
    mock.money = mock.money - 4000
    GF.App:CheckPendingConfirmation()
    eq(p:GetState(), "SUBMITTED") -- unrelated money movement is not proof
    mock.Advance(9)
    eq(p:GetState(), "UNKNOWN")
    assert(GF.App.recoveryBlocked)
    local id = p:GetPending().localTransactionId
    assert(GF.App:ResolveTransaction(id, false))
    eq(GF.App.ledger:Get(id).status, "failed")
    assert(not GF.App.recoveryBlocked)
    p.env.query, p.env.submit = beforeQuery, beforeSubmit
end)
test("history cannot execute purchases", function()
    local snapshot = GF.App:GetHistory()[1]
    assert(GF.App:ViewSnapshot(GF.App:GetMarketKey(), snapshot.id))
    eq(select(2, GF.App:RequestPurchase({})), "snapshot_read_only")
    GF.App:ClearSnapshotView()
end)
test("virtualized results show rows after the first viewport", function()
    local original = GF.App.visible
    GF.App.visible = {}
    for i = 1, 100 do GF.App.visible[i] = {itemId = i, itemName = "Row " .. i, quantity = 1, buyoutTotal = 100, profit = i, roi = i} end
    GF.UI.ResultsTable.scrollFrame:SetVerticalScroll(1000)
    GF.UI.ResultsTable.Refresh()
    eq(GF.UI.ResultsTable.rows[1].dataIndex, 51)
    eq(GF.App.visible[1].profit, 1) -- display sorting must not mutate app rows
    GF.App.visible = original
    GF.UI.ResultsTable.scrollFrame:SetVerticalScroll(0)
end)
test("corrupt ledger records cannot crash metrics", function()
    local ledger = GF.Domain.Ledger.New()
    eq(ledger:Load({{id = "bad", status = "received", purchasedCost = "x"},
        {id = "bad2", strategy = "vendor", status = "received", purchasedCost = 10, purchasedQuantity = 1, marketKey = "m", disposals = {"invalid"}}}), 0)
    eq(ledger:Metrics().transactions, 0)
end)
test("unlimited budget and live profit filters", function()
    local p = GF.Domain.PurchaseManager.New({getSessionBudget = function() return 0 end})
    eq(p:GetRemainingBudget(), math.huge)
    local p2 = manager()
    p2.quote.profit = 0
    eq(select(2, p2:BeginConfirm()), "not_profitable")
end)
test("future schema untouched and saving disabled", function()
    local original = GoblinFlipDB
    local saved = {schemaVersion = 99, settings = {custom = "keep"}}
    GoblinFlipDB = saved
    local db, supported = GF.Settings.Initialize(saved)
    assert(not supported and GF.Settings.readOnly); assert(db ~= saved)
    GF.App:Save(); eq(saved.history, nil); eq(saved.settings.custom, "keep")
    assert(not GF.Settings.Set("minProfit", 1))
    GoblinFlipDB = original; GF.Settings.Initialize(original)
end)
test("migration keeps a backup and saved pending spend recovers", function()
    local original = GF.Settings.db
    local old = {schemaVersion = 1, settings = {minProfit = 321}, session = {spent = 123}}
    local upgraded = GF.Settings.Initialize(old)
    eq(upgraded.schemaVersion, 2); eq(upgraded.settings.minProfit, 321)
    eq(upgraded.migrationBackup.schemaVersion, 1); eq(upgraded.migrationBackup.session.spent, 123)
    local ledger = GF.Domain.Ledger.New()
    local tx = assert(ledger:Create({strategy = "vendor", marketKey = "m", itemId = 123, purchasedQuantity = 1, purchasedCost = 100}))
    tx.budgetCounted = true
    local restored = GF.Domain.Ledger.New()
    eq(restored:Load(ledger:Export()), 1)
    assert(restored:Get(tx.id).budgetCounted)
    local active = GF.App.ledger
    GF.App.ledger = restored; GF.App:RecoverPendingPurchases()
    assert(GF.App.recoveryBlocked); eq(restored:Get(tx.id).status, "uncertain")
    GF.App.ledger = active; GF.App:RecoverPendingPurchases()
    GF.Settings.Initialize(original)
end)
test("corrupt snapshots and alert signatures are skipped", function()
    local index = GF.Domain.OpportunityIndex.New()
    eq(index:LoadSerialized({m = {{id = "bad", observedAt = "yesterday"},
        {id = "valid", observedAt = time(), opportunities = {"broken"}, disenchant = false}}}), 1)
    eq(#index:History("m")[1].opportunities, 0)
    GF.App.notifications:Load({signatures = {m = {"good", false, 0/0}}})
end)
test("copper allocation stays exact at the integer limit", function()
    eq(GF.Util.AllocateCopper(GF.MAX_COPPER, 2, 3), 6004799503160660)
    for amount = 0, 100 do
        for part = 0, 13 do eq(GF.Util.AllocateCopper(amount, part, 13), math.floor(amount * part / 13)) end
    end
end)
test("all setup pages render and finish without buying", function()
    GF.UI.Onboarding.Show()
    for i = 1, 7 do GF.UI.Onboarding.SaveStep(i); GF.UI.Onboarding.Render() end
    GF.UI.Onboarding.next:Click()
    assert(GF.Settings.db.onboarding.completed)
end)
test("no swallowed startup or UI errors", function()
    for _, message in ipairs(mock.messages) do
        assert(not message:find("Error during", 1, true) and not message:find("UI:", 1, true)
            and not message:find("Scheduled action:", 1, true) and not message:find("Item resolution:", 1, true), message)
    end
end)
print(string.format("%d tests passed (%s)", count, GetLocale()))
