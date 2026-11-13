-- Application orchestration: scan pipeline, market identity, purchase flow,
-- persistence and UI notifications. All WoW API use is wrapped defensively so a
-- missing API degrades to a diagnostic instead of a Lua error.

local _, GF = ...

GF.App = {
    initialized = false,
    uiInitialized = false,
    scanning = false,
    scanState = "IDLE",
    scanProgress = 0,
    scanMessage = nil,
    scanId = nil,
    scanMarketKey = nil,
    strategy = GF.STRATEGY_VENDOR,
    allVendor = {},
    allDisenchant = {},
    disenchantCounts = nil,
    visible = {},
    viewSnapshot = nil,
    selected = nil,
    selectedKey = nil,
    identity = nil,
    pendingPayload = nil,
    lastResult = nil,
    lastError = nil,
    lastScanAt = 0,
    tasks = {},
    timers = {},
    pendingConfirmation = nil,
    confirmationTimeout = 8,
}

local App = GF.App
local STATE = GF.SCAN_STATE
local TX = GF.TX_STATUS

local function nowOf()
    return type(time) == "function" and time() or 0
end

local function settings()
    if GF.Settings and GF.Settings.GetAll then
        return GF.Settings.GetAll()
    end
    return {}
end

local function settingValue(key, fallback)
    local value = settings()[key]
    if value == nil then
        return fallback
    end
    return value
end

local function notify(event, ...)
    if GF.UI and type(GF.UI.Notify) == "function" then
        pcall(GF.UI.Notify, event, ...)
    end
end

local function printMessage(text)
    GF.Util.Print(text)
end

--- Run a function later without relying on C_Timer (which may be absent).
function App:After(delay, fn)
    if type(fn) ~= "function" then
        return
    end
    local at = nowOf() + math.max(0, tonumber(delay) or 0)
    self.timers[#self.timers + 1] = {at = at, fn = fn}
end

function App:RunTimers(now)
    if #self.timers == 0 then
        return
    end
    local due = {}
    local keep = {}
    for index = 1, #self.timers do
        local entry = self.timers[index]
        if entry.at <= now then
            due[#due + 1] = entry.fn
        else
            keep[#keep + 1] = entry
        end
    end
    self.timers = keep
    for index = 1, #due do
        pcall(due[index])
    end
end

function App:SetScanState(state, progress, message)
    self.scanState = state
    if progress ~= nil then
        self.scanProgress = progress
    end
    if message ~= nil then
        self.scanMessage = message
    end
    notify("scan_state", state, self.scanProgress, self.scanMessage)
end

function App:EnsureDatabase()
    local saved = _G.GoblinFlipDB
    if type(saved) ~= "table" then
        saved = {}
        _G.GoblinFlipDB = saved
    end
    return saved
end

function App:DetectMarket(force)
    local identity = GF.Domain.Market.GetCurrent(nil, {
        override = settingValue("marketHouseOverride", "auto"),
        isForever = GF.Compat.IsForever and GF.Compat.IsForever(),
    })
    local previous = self.identity
    self.identity = identity
    if previous and previous.key ~= identity.key and self.purchase then
        local ok = self.purchase:OnMarketChanged(identity.key)
        if ok == false then
            notify("purchase", self.purchase:GetState())
        end
    end
    if force or not previous or previous.key ~= identity.key then
        notify("market", identity)
    end
    return identity
end

function App:GetMarketKey()
    return self.identity and self.identity.key or nil
end

function App:BuildPurchaseManager()
    local environment = {
        now = nowOf,
        getMoney = function()
            return GF.Compat.GetMoney()
        end,
        getSessionBudget = function()
            return tonumber(settingValue("sessionBudget", 0)) or 0
        end,
        getSessionSpent = function()
            return GF.Settings.GetSessionSpent()
        end,
        getMarketKey = function()
            return App:GetMarketKey()
        end,
        query = function(listing, generation)
            return GF.LiveMarket:RequestOffers(listing, generation, function(queryGeneration, offers, info)
                App.purchase:OnQueryResults(queryGeneration, offers, info)
            end)
        end,
        cancelQuery = function(generation)
            GF.LiveMarket:Cancel(generation)
        end,
        submit = function(quote)
            return App:SubmitQuote(quote)
        end,
        newTransactionId = function()
            return GF.Util.NewId("tx")
        end,
        onSubmitted = function(quote)
            App:OnSubmitted(quote)
        end,
        onConfirmed = function(transaction)
            App:OnConfirmed(transaction)
        end,
        onFailed = function(reason)
            App:OnPurchaseFailed(reason)
        end,
        onState = function(state, quote, info)
            notify("purchase", state, quote, info)
        end,
    }
    self.purchase = GF.Domain.PurchaseManager.New(environment, {
        quoteFreshness = tonumber(settingValue("quoteFreshness", 10)) or 10,
        allowCommodity = settingValue("allowCommodityPurchase", false) == true,
        maxPerPurchase = tonumber(settingValue("maxBuyout", 0)) or 0,
    })
end

function App:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    local saved = self:EnsureDatabase()
    GF.Settings.Initialize(saved)
    GF.Compat.Probe()
    GF.Debug.enabled = settingValue("debug", false) == true

    self.index = GF.Domain.OpportunityIndex.New({
        maxSnapshotsPerMarket = tonumber(settingValue("historySnapshots", 10)) or 10,
        retentionSeconds = (tonumber(settingValue("historyDays", 7)) or 7) * 86400,
    })
    self.index:LoadSerialized(saved.history and saved.history.snapshots)

    self.ledger = GF.Domain.Ledger.New({maxTransactions = 5000})
    self.ledger:Load(saved.ledger and saved.ledger.transactions)

    self.notifications = GF.Domain.Notifications.New({
        now = nowOf,
        playSound = function(count, best)
            App:PlayAlert(count, best)
        end,
    }, {rateLimit = 30, maxSignatures = 500})
    self.notifications:Load(saved.alerts)

    self:DetectMarket(true)

    GF.ItemInfo.Initialize()
    GF.LiveMarket.Initialize()
    GF.LiveMarket:SetBidListener(function()
        App:CheckPendingConfirmation()
    end)
    GF.AuctionatorAdapter:Initialize()
    GF.NativeScan:Initialize()
    GF.DisenchantBuddy.Initialize()
    GF.Mailbox.Initialize()
    GF.Merchant.Initialize()

    -- Dependency check
    App:CheckDependencies()

    -- Tooltip and context menu integration (optional, settings-controlled)
    if settingValue("showFlipTooltip", false) == true then
        self:HookTooltips()
    end
    self:RegisterTooltipEvents()

    -- Minimap icon
    if GF.UI and GF.UI.MinimapIcon then
        GF.UI.MinimapIcon.Initialize()
    end

    -- Slash commands
    if GF.SlashCommands then
        GF.SlashCommands.Initialize()
    end

    self:BuildPurchaseManager()
    self:RegisterEvents()
    self:RegisterTicker()

    saved.lastMarket = self.identity and self.identity.key or nil
    notify("initialized")
end

function App:RegisterTicker()
    if self.ticker then
        return
    end
    local ticker = CreateFrame("Frame")
    self.ticker = ticker
    ticker.elapsed = 0
    ticker.confirmElapsed = 0
    ticker:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = frame.elapsed + elapsed
        frame.confirmElapsed = frame.confirmElapsed + elapsed
        local now = nowOf()
        App:RunTimers(now)
        if frame.confirmElapsed >= 0.5 then
            frame.confirmElapsed = 0
            App:CheckPendingConfirmation()
            if App.purchase then
                local state = App.purchase:GetState()
                local ticked = App.purchase:Tick(now)
                if ticked and state ~= App.purchase:GetState() then
                    notify("purchase", App.purchase:GetState(), App.purchase:GetQuote())
                end
            end
        end
    end)
end

function App:RegisterEvents()
    if self.eventFrame then
        return
    end
    local frame = CreateFrame("Frame")
    self.eventFrame = frame
    local events = {
        "ADDON_LOADED",
        "PLAYER_LOGIN",
        "PLAYER_LOGOUT",
        "PLAYER_ENTERING_WORLD",
        "ZONE_CHANGED",
        "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED_INDOORS",
        "AUCTION_HOUSE_SHOW",
        "AUCTION_HOUSE_CLOSED",
        "AUCTION_HOUSE_NEW_BID_RECEIVED",
        "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
        "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    }
    for index = 1, #events do
        pcall(frame.RegisterEvent, frame, events[index])
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        App:HandleEvent(event, ...)
    end)
end

function App:HandleEvent(event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == GF.name then
            self:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        self:Initialize()
        if not self.uiInitialized then
            self.uiInitialized = true
            if GF.UI and GF.UI.Initialize then
                pcall(GF.UI.Initialize)
            end
        end
        self:ReportReadiness()
    elseif event == "PLAYER_LOGOUT" then
        self:Save()
    elseif event == "AUCTION_HOUSE_SHOW" then
        self:DetectMarket(true)
        -- Legacy event fallback
        if GF.UI and GF.UI.AttachToAuctionHouse then
            pcall(GF.UI.AttachToAuctionHouse)
        end
        -- Re-check dependencies after AH opens (Auctionator may have loaded late)
        App:After(1, function() App:CheckDependencies() end)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        -- Modern interaction system (Forever/Retail)
        local interactionType = ...
        if interactionType == Enum.PlayerInteractionType.Auctioneer then
            self:DetectMarket(true)
            if GF.UI and GF.UI.AttachToAuctionHouse then
                pcall(GF.UI.AttachToAuctionHouse)
            end
            App:After(1, function() App:CheckDependencies() end)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if self.purchase then
            self.purchase:OnAhClosed()
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if interactionType == Enum.PlayerInteractionType.Auctioneer then
            if self.purchase then
                self.purchase:OnAhClosed()
            end
        end
    elseif event == "AUCTION_HOUSE_NEW_BID_RECEIVED" then
        self:CheckPendingConfirmation()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:DetectMarket()
    else
        self:DetectMarket()
    end
end

function App:ReportReadiness()
    local report = GF.Compat.GetReport()
    if not report.canQueryLive then
        printMessage(GF.L["This client does not expose the modern auction house APIs."])
        return
    end
    if not report.auctionator.contractAvailable then
        printMessage(GF.L["Auctionator is missing. GoblinFlip needs Auctionator for full scans."])
    end
    local identity = self.identity
    if identity and not identity.verified then
        printMessage(GF.L["Market unknown - select a house override in Settings."])
    end
    printMessage(GF.L["GoblinFlip is ready."])
end

function App:Save()
    local saved = self:EnsureDatabase()
    if self.index then
        saved.history = saved.history or {}
        saved.history.snapshots = self.index:Serialize(tonumber(settingValue("historySnapshots", 10)) or 10)
    end
    if self.ledger then
        saved.ledger = saved.ledger or {}
        saved.ledger.transactions = self.ledger:Export()
    end
    if self.notifications then
        saved.alerts = self.notifications:Serialize()
    end
    saved.lastMarket = self.identity and self.identity.key or nil
end

--- Scan trigger used by the UI and slash commands.
function App:RequestScan()
    self:Initialize()
    local currentSettings = settings()
    local provider = settingValue("scanProvider", "auctionator")
    
    -- In standalone mode, always use native scan
    if currentSettings.standaloneMode == true then
        provider = "native"
    end
    
    if provider == "native" then
        -- Allow native scan in standalone mode without experimental flag
        local allowNative = settingValue("experimentalNativeScan", false) == true
            or currentSettings.standaloneMode == true
        if not allowNative then
            return false, "native_scan_disabled"
        end
        local ok, reason = GF.NativeScan:RequestScan()
        if not ok then
            self.lastError = reason
            return false, reason
        end
        self:SetScanState(STATE.REQUESTED, 0, nil)
        return true
    end

    local ok = GF.Compat.CanScan()
    if not ok then
        self:SetScanState(STATE.ERROR, 0, "scan_unavailable")
        return false, "scan_unavailable"
    end
    local requested, reason = GF.AuctionatorAdapter:RequestScan()
    if not requested then
        if reason == "manual_scan_required" then
            self:SetScanState(STATE.REQUESTED, 0, "manual_scan_required")
            printMessage(GF.L["Open Auctionator's Buy tab and click Get All."])
        else
            self:SetScanState(STATE.ERROR, 0, reason)
            printMessage(GF.L["Scanning is not available yet."])
        end
        return false, reason
    end
    self:SetScanState(STATE.REQUESTED, 0, nil)
    return true
end

function App:OnScanError(reason)
    self.scanning = false
    self.lastError = reason
    self:SetScanState(STATE.ERROR, 0, reason)
    notify("scan", nil)
end

function App:CanPublishScans()
    local identity = self.identity
    if not identity then
        return false, "market_unknown"
    end
    if not identity.verified then
        return false, "market_unknown"
    end
    if identity.readOnly then
        return false, "market_read_only"
    end
    return true
end

--- Entry point for scan providers (Auctionator adapter and native adapter).
function App:OnScanPayload(payload, source, observedAt)
    self:Initialize()
    if type(payload) ~= "table" or #payload == 0 then
        self:OnScanError("empty_payload")
        return false
    end
    if self.scanning then
        self.pendingPayload = {payload = payload, source = source, observedAt = observedAt}
        GF.Debug:Log("Scan queued while another scan is in progress")
        return false, "busy"
    end

    local canPublish, reason = self:CanPublishScans()
    if not canPublish then
        self.lastError = reason
        self:SetScanState(STATE.ERROR, 0, reason)
        printMessage(GF.L["Market unknown - select a house override in Settings."])
        return false, reason
    end

    self:DetectMarket()
    canPublish, reason = self:CanPublishScans()
    if not canPublish then
        self.lastError = reason
        self:SetScanState(STATE.ERROR, 0, reason)
        return false, reason
    end

    local observed = tonumber(observedAt) or nowOf()
    local scanId = GF.Util.NewId("scan")
    self.scanning = true
    self.scanId = scanId
    self.scanGeneration = (self.scanGeneration or 0) + 1
    self.scanMarketKey = self.identity.key
    self.scanStartedAt = observed
    self.lastError = nil
    self.lastResult = nil
    self:SetScanState(STATE.NORMALIZING, 0, nil)
    notify("scan", nil)

    local batch = GF.Domain.ScanNormalizer.NewBatch(payload, {
        scanId = scanId,
        marketKey = self.identity.key,
        market = self.identity,
        observedAt = observed,
        source = source or "unknown",
        makeItemKey = function(listing)
            return GF.ItemInfo.GetItemKey(listing)
        end,
    })
    self.batch = batch

    local function step()
        if not App.scanning or App.scanId ~= scanId then
            return
        end
        local done = batch:Step(400)
        App:SetScanState(STATE.NORMALIZING, batch:GetProgress(), nil)
        if done then
            App:FinishNormalize(batch)
        else
            App:After(0, step)
        end
    end
    self:After(0, step)
    return true
end

function App:CancelScan(reason)
    if not self.scanning then
        return false
    end
    self.scanning = false
    self.scanGeneration = (self.scanGeneration or 0) + 1
    self.batch = nil
    self.pendingPayload = nil
    self:SetScanState(STATE.CANCELLED, self.scanProgress, reason or "cancelled")
    notify("scan", nil)
    return true
end

function App:FinishNormalize(batch)
    local scanId = self.scanId
    local listings = batch:GetListings()
    if #listings == 0 then
        self:CompleteScan(batch:GetResult(), {}, {evaluated = 0, profitable = 0}, 0)
        return
    end
    self:SetScanState(STATE.RESOLVING_ITEMS, 1, nil)
    local generation = self.scanGeneration
    GF.ItemInfo:ResolveScan(listings, function()
        if not App.scanning or App.scanId ~= scanId or App.scanGeneration ~= generation then
            return
        end
        App:EvaluateScan(batch, listings)
    end)
end

function App:BuildDisenchantData(itemId, itemLevel, quality, force)
    local currentSettings = settings()
    
    -- Use standalone internal data if enabled or if DisenchantBuddy unavailable
    local useStandalone = currentSettings.standaloneMode == true
        or not GF.DisenchantBuddy.IsAvailable()
    
    if useStandalone and GF.Domain.DisenchantData then
        -- Get material prices from live AH if available, otherwise use defaults
        local materialPrices = GF.Domain.DisenchantData.defaultPrices
        return GF.Domain.DisenchantData.GetEstimate(itemId, itemLevel or 0, quality or 0, materialPrices)
    end
    
    -- Fall back to DisenchantBuddy
    if not GF.DisenchantBuddy.IsAvailable() then
        return nil, "disenchantbuddy_unavailable"
    end
    return GF.DisenchantBuddy.GetEstimate(itemId, {force = force == true})
end

function App:EvaluateScan(batch, listings)
    local scanId = self.scanId
    local startedAt = self.scanStartedAt
    local currentSettings = settings()

    local resolved, unknown = GF.ItemInfo:ApplyToListings(listings)

    local vendor, vendorCounts = GF.Domain.ProfitEngine.BuildAll(
        listings, GF.STRATEGY_VENDOR, {})

    local disenchant = {}
    local disenchantCounts = {
        evaluated = 0,
        profitable = 0,
        notProfitable = 0,
        unavailable = 0,
        skillUnverified = 0,
    }
    local useStandalone = currentSettings.standaloneMode == true
        or not GF.DisenchantBuddy.IsAvailable()
    if currentSettings.disenchantEnabled ~= false and (GF.DisenchantBuddy.IsAvailable() or useStandalone) then
        for index = 1, #listings do
            local listing = listings[index]
            local data = nil
            if listing.itemId then
                data = self:BuildDisenchantData(listing.itemId, listing.itemLevel, listing.itemQuality)
            end
            if not data then
                disenchantCounts.unavailable = disenchantCounts.unavailable + 1
            else
                disenchantCounts.evaluated = disenchantCounts.evaluated + 1
                local opportunity, reason = GF.Domain.ProfitEngine.Evaluate(
                    listing, GF.STRATEGY_DISENCHANT, {
                        disenchant = data,
                        requireSkill = currentSettings.requireDisenchantSkill == true,
                        index = index,
                    })
                if opportunity then
                    disenchant[#disenchant + 1] = opportunity
                    disenchantCounts.profitable = disenchantCounts.profitable + 1
                elseif reason == "not_profitable" then
                    disenchantCounts.notProfitable = disenchantCounts.notProfitable + 1
                elseif reason == "skill_unverified" then
                    disenchantCounts.skillUnverified = disenchantCounts.skillUnverified + 1
                else
                    disenchantCounts.unavailable = disenchantCounts.unavailable + 1
                end
            end
        end
    end

    vendor = GF.Domain.ProfitEngine.Sort(vendor, "profit", "desc")
    disenchant = GF.Domain.ProfitEngine.Sort(disenchant, "profit", "desc")

    self.lastResult = {
        scanId = scanId,
        resolved = resolved,
        unknown = unknown,
        listings = #listings,
        vendorCounts = vendorCounts,
        disenchantCounts = disenchantCounts,
        duration = math.max(0, nowOf() - (startedAt or nowOf())),
    }
    self:CompleteScan(batch:GetResult(), vendor, disenchant)
end

local function trimList(list, maximum)
    if #list <= maximum then
        return list
    end
    local trimmed = {}
    for index = 1, maximum do
        trimmed[index] = list[index]
    end
    return trimmed
end

function App:CompleteScan(normalized, vendor, disenchant)
    local scanId = self.scanId
    if not self.scanning or not scanId then
        return
    end
    if self.scanMarketKey and self.identity and self.scanMarketKey ~= self.identity.key then
        self:OnScanError("market_changed")
        return
    end

    self.scanning = false
    self.allVendor = vendor or {}
    self.allDisenchant = disenchant or {}
    self.disenchantCounts = self.lastResult and self.lastResult.disenchantCounts or nil
    self.lastScanAt = nowOf()
    self.lastResult.scanId = scanId
    self.lastResult.listings = normalized and normalized.total or 0
    self.lastResult.rejected = normalized and normalized.rejected or {}
    self.lastResult.resolved = self.lastResult.resolved or 0
    self.lastResult.unknown = self.lastResult.unknown or 0

    local snapshot = {
        id = scanId,
        marketKey = self.identity.key,
        market = {
            house = self.identity.house,
            label = self.identity.houseLabel,
            region = self.identity.region,
            realm = self.identity.realm,
        },
        observedAt = normalized and normalized.observedAt or nowOf(),
        source = normalized and normalized.source or "unknown",
        partial = normalized and normalized.complete == false or false,
        counts = {
            total = normalized and normalized.total or 0,
            accepted = normalized and normalized.accepted or 0,
            rejected = normalized and normalized.rejected or {},
            resolved = self.lastResult.resolved,
            unknown = self.lastResult.unknown,
        },
        opportunities = trimList(self.allVendor, 500),
        disenchant = trimList(self.allDisenchant, 500),
        disenchantCounts = self.disenchantCounts,
        scanState = STATE.READY,
        duration = self.lastResult.duration,
    }
    local published, reason = self.index:Publish(snapshot)
    if not published then
        self.lastError = reason
        self:SetScanState(STATE.ERROR, 1, reason)
        return
    end

    self:RebuildVisible()
    self:TryAlerts(snapshot)
    self:SetScanState(STATE.READY, 1, nil)
    notify("scan", self.lastResult)
    self:Save()

    local vendorCount = #self.allVendor
    local disenchantCount = #self.allDisenchant
    if vendorCount == 0 and disenchantCount == 0 then
        printMessage(GF.L["No opportunities detected in this scan."])
    else
        printMessage(string.format("Scan complete: %d vendor flips, %d disenchant estimates.",
            vendorCount, disenchantCount))
    end

    if self.pendingPayload then
        local pending = self.pendingPayload
        self.pendingPayload = nil
        self:After(0.5, function()
            App:OnScanPayload(pending.payload, pending.source, pending.observedAt)
        end)
    end
end

function App:TryAlerts(snapshot)
    if not self.notifications then
        return
    end
    local currentSettings = settings()
    local result, reason = self.notifications:OnScanCompleted(
        snapshot.marketKey, snapshot.opportunities, currentSettings, snapshot.id)
    if reason == "baseline" then
        return
    end
    if result and result.soundPlayed and result.best then
        printMessage(string.format("%s: %s (%s)",
            GF.L["New opportunity"],
            tostring(result.best.itemName or "?"),
            GF.Util.FormatMoney(result.best.profit or 0)))
    end
end

function App:PlayAlert(count, best)
    local sound = settingValue("soundFile", "Sound\\Interface\\AuctionWindowOpen.wav")
    if type(_G.PlaySoundFile) == "function" then
        pcall(_G.PlaySoundFile, sound, "Master")
    elseif type(_G.PlaySound) == "function" then
        pcall(_G.PlaySound, "AuctionWindowOpen")
    end
    if best then
        printMessage(string.format("%d %s: %s", count, GF.L["new opportunities"],
            tostring(best.itemName or "?")))
    end
end

function App:GetFilters()
    local filters = GF.Settings.GetFilters()
    filters.search = settingValue("search", "")
    filters.strategy = self.strategy
    return filters
end

function App:RebuildVisible()
    local filters = self:GetFilters()
    local source = self.strategy == GF.STRATEGY_DISENCHANT
        and self.allDisenchant or self.allVendor
    local filtered = GF.Domain.ProfitEngine.Filter(source, filters)
    local rows = filtered
    if settingValue("groupedView", false) == true then
        rows = GF.Domain.ProfitEngine.Group(filtered)
    end
    local sortField = settingValue("defaultSort", "profit")
    local sortDirection = settingValue("defaultSortDirection", "desc")
    self.visible = GF.Domain.ProfitEngine.Sort(rows, sortField, sortDirection)
    self:ValidateSelection()
end

function App:ValidateSelection()
    if not self.selected then
        return
    end
    local key = self.selected.key
    if not key or self.viewSnapshot then
        return
    end
    for index = 1, #self.visible do
        if self.visible[index].key == key then
            return
        end
    end
    self.selected = nil
    self.selectedKey = nil
end

function App:SetStrategy(strategy)
    if strategy ~= GF.STRATEGY_VENDOR and strategy ~= GF.STRATEGY_DISENCHANT then
        return false
    end
    self.strategy = strategy
    self.selected = nil
    self.selectedKey = nil
    self:RebuildVisible()
    notify("filters")
    return true
end

function App:SetSearch(text)
    local value = type(text) == "string" and text or ""
    GF.Settings.Set("search", value)
    self:RebuildVisible()
    notify("filters")
    return true
end

function App:SetSort(field, direction)
    local ok = GF.Settings.Set("defaultSort", field)
    if not ok then
        return false, "invalid_sort"
    end
    if direction then
        GF.Settings.Set("defaultSortDirection", direction)
    end
    self:RebuildVisible()
    notify("filters")
    return true
end

function App:SetSetting(key, value)
    local ok, reason = GF.Settings.Set(key, value)
    if not ok then
        return false, reason
    end
    if key == "debug" then
        GF.Debug.enabled = value == true
    elseif key == "groupedView" or key == "defaultSort" or key == "defaultSortDirection"
        or key == "minProfit" or key == "minRoi" or key == "maxBuyout"
        or key == "minQuantity" or key == "maxQuantity" or key == "showOwned"
        or key == "qualityFilter" or key == "search" then
        self:RebuildVisible()
    elseif key == "historySnapshots" then
        self.index.maxSnapshotsPerMarket = value
    elseif key == "historyDays" then
        self.index.retentionSeconds = value * 86400
        self.index:Prune(nowOf())
    elseif key == "marketHouseOverride" then
        self:DetectMarket(true)
    elseif key == "assumeDisenchantSkill" then
        GF.DisenchantBuddy.DetectSkill(true)
        GF.DisenchantBuddy.ClearCache()
    elseif key == "quoteFreshness" and self.purchase then
        self.purchase.options.quoteFreshness = value
    end
    notify("settings", key)
    self:Save()
    return true
end

function App:GetView()
    local rows = self:GetRows()
    local metrics = GF.Domain.ProfitEngine.Metrics(rows, {
        money = GF.Compat.GetMoney(),
    })
    return {
        identity = self.identity,
        strategy = self.strategy,
        rows = rows,
        metrics = metrics,
        filters = self:GetFilters(),
        scanning = self.scanning,
        scanState = self.scanState,
        scanProgress = self.scanProgress,
        scanMessage = self.scanMessage,
        selected = self.selected,
        selectedKey = self.selectedKey,
        lastResult = self.lastResult,
        lastScanAt = self.lastScanAt,
        viewSnapshot = self.viewSnapshot,
        sessionSpent = GF.Settings.GetSessionSpent(),
        budget = tonumber(settingValue("sessionBudget", 0)) or 0,
        money = GF.Compat.GetMoney(),
        purchase = self.purchase,
    }
end

function App:GetRows()
    if self.viewSnapshot then
        local rows
        if self.strategy == GF.STRATEGY_DISENCHANT then
            rows = self.viewSnapshot.disenchant or {}
        else
            rows = self.viewSnapshot.opportunities or {}
        end
        local filters = self:GetFilters()
        local filtered = GF.Domain.ProfitEngine.Filter(rows, filters)
        return GF.Domain.ProfitEngine.Sort(filtered, "profit", "desc")
    end
    return self.visible
end

function App:Select(row)
    if type(row) ~= "table" then
        self.selected = nil
        self.selectedKey = nil
        notify("selection")
        return
    end
    self.selected = row
    self.selectedKey = row.key
    notify("selection", row)
end

function App:GetSelected()
    return self.selected
end

function App:GetDisenchantStatus()
    local currentSettings = settings()
    local useStandalone = currentSettings.standaloneMode == true
        or not GF.DisenchantBuddy.IsAvailable()
    local data = {
        available = GF.DisenchantBuddy.IsAvailable() or useStandalone,
        provider = useStandalone and "Internal (Standalone)" or "DisenchantBuddy",
        standaloneMode = useStandalone,
        skill = useStandalone and { verified = true, reason = nil, rank = 1, evidence = "internal" }
            or GF.DisenchantBuddy.GetSkillStatus(false),
        counts = self.disenchantCounts,
    }
    return data
end

--- Live quote request for an opportunity. No purchase happens here.
function App:RequestPurchase(row)
    self:Initialize()
    row = row or self.selected
    if type(row) ~= "table" then
        return false, "no_selection"
    end
    if self.viewSnapshot then
        return false, "snapshot_read_only"
    end
    if not GF.Compat.IsAhSupported() then
        return false, "ah_unsupported"
    end
    local identity = self.identity
    if not identity or not identity.verified then
        return false, "market_unknown"
    end
    if identity.readOnly then
        return false, "market_read_only"
    end
    if row.marketKey and row.marketKey ~= identity.key then
        return false, "wrong_market"
    end
    if row.isGroup == true then
        return false, "not_executable"
    end

    local data, reason
    if row.strategy == GF.STRATEGY_DISENCHANT then
        data, reason = self:BuildDisenchantData(row.itemId, row.itemLevel, row.itemQuality, true)
        if not data then
            return false, reason or "disenchant_unavailable"
        end
    end

    self.selected = row
    self.selectedKey = row.key
    self.purchase.options.allowCommodity = settingValue("allowCommodityPurchase", false) == true
    self.purchase.options.maxPerPurchase = tonumber(settingValue("maxBuyout", 0)) or 0
    self.purchase.options.quoteFreshness = tonumber(settingValue("quoteFreshness", 10)) or 10

    return self.purchase:RequestQuote(row, {
        strategy = row.strategy,
        marketKey = identity.key,
        filters = {
            maxBuyout = tonumber(settingValue("maxBuyout", 0)) or 0,
        },
        disenchant = data,
        requireSkill = settingValue("requireDisenchantSkill", true) == true,
        quoteFreshness = tonumber(settingValue("quoteFreshness", 10)) or 10,
        evaluationContext = {
            disenchant = data,
            requireSkill = settingValue("requireDisenchantSkill", true) == true,
        },
    })
end

function App:BeginConfirm()
    if not self.purchase then
        return false, "not_ready"
    end
    return self.purchase:BeginConfirm()
end

function App:SubmitPurchase()
    if not self.purchase then
        return false, "not_ready"
    end
    local ok, reason = self.purchase:Submit()
    notify("purchase", self.purchase:GetState(), self.purchase:GetQuote())
    return ok, reason
end

function App:CancelPurchase()
    if not self.purchase then
        return false
    end
    local ok, reason = self.purchase:Cancel("user_cancelled")
    notify("purchase", self.purchase:GetState())
    return ok, reason
end

function App:SubmitQuote(quote)
    if not quote then
        return false, "missing_quote"
    end
    if quote.isCommodity then
        if settingValue("allowCommodityPurchase", false) ~= true then
            return false, "commodity_disabled"
        end
        local api = _G.C_AuctionHouse
        if type(api) == "table" and type(api.StartCommoditiesPurchase) == "function" then
            local ok, reason = pcall(api.StartCommoditiesPurchase, quote.itemId, quote.quantity)
            if not ok then
                return false, tostring(reason)
            end
            return true
        end
        return false, "commodity_unsupported"
    end
    return GF.LiveMarket:PlaceBid(quote.auctionId, quote.buyoutTotal)
end

function App:OnSubmitted(quote)
    if not quote or not quote.localTransactionId then
        return
    end
    local transaction, reason = self.ledger:Create({
        id = quote.localTransactionId,
        strategy = quote.strategy,
        marketKey = quote.marketKey,
        characterKey = GF.Settings.GetCharacterKey(),
        auctionId = quote.auctionId,
        itemId = quote.itemId,
        itemKey = quote.variantKey,
        variantKey = quote.variantKey,
        itemName = quote.itemName,
        itemLink = quote.itemLink,
        purchasedQuantity = quote.quantity,
        purchasedCost = quote.buyoutTotal,
        expectedProceeds = quote.expectedProceeds,
        status = TX.SUBMITTED,
        source = "auction-house",
    }, quote.submittedAt)
    if not transaction then
        GF.Debug:Log("Ledger create failed", tostring(reason))
    end

    self.pendingConfirmation = {
        transactionId = quote.localTransactionId,
        cost = quote.buyoutTotal,
        moneyBefore = GF.Compat.GetMoney(),
        deadline = nowOf() + (self.confirmationTimeout or 8),
        quote = quote,
    }
    printMessage(GF.L["Purchase submitted."])
    notify("purchase", self.purchase and self.purchase:GetState(), quote)
    self:Save()
end

function App:ChargeBudget(transactionId, amount)
    local transaction = transactionId and self.ledger:Get(transactionId)
    if transaction and transaction.budgetCounted then
        return false
    end
    GF.Settings.AddSessionSpent(amount)
    if transaction then
        transaction.budgetCounted = true
    end
    return true
end

function App:OnConfirmed(transaction)
    if not transaction or not transaction.id then
        return
    end
    local record = self.ledger:Get(transaction.id)
    if record then
        if record.status == TX.SUBMITTED then
            self.ledger:Confirm(record.id)
        elseif record.status == TX.UNCERTAIN then
            self.ledger:Transition(record.id, TX.CONFIRMED)
        end
        if record.status == TX.CONFIRMED then
            self.ledger:MarkAwaitingMail(record.id)
        end
        self:ChargeBudget(record.id, record.purchasedCost)
    end
    self.pendingConfirmation = nil
    printMessage(GF.L["Purchase confirmed."])
    notify("ledger")
    notify("purchase", self.purchase and self.purchase:GetState(), transaction)
    self:Save()
end

function App:OnPurchaseFailed(reason)
    local pending = self.pendingConfirmation
    if pending and pending.transactionId then
        local record = self.ledger:Get(pending.transactionId)
        if record and record.status == TX.SUBMITTED then
            self.ledger:Fail(record.id, reason or "purchase_failed")
        end
    end
    self.pendingConfirmation = nil
    printMessage(GF.L["Purchase failed."] .. " " .. self:ReasonText(reason))
    notify("ledger")
    notify("purchase", self.purchase and self.purchase:GetState())
    self:Save()
end

function App:MarkTransactionUncertain(transactionId, reason)
    local record = transactionId and self.ledger:Get(transactionId)
    if not record then
        return false, "not_found"
    end
    if record.status == TX.SUBMITTED then
        self.ledger:MarkUncertain(record.id, reason)
        return true
    end
    return false, "invalid_state"
end

function App:CheckPendingConfirmation()
    local pending = self.pendingConfirmation
    if not pending then
        return
    end
    if not self.purchase or self.purchase:GetState() ~= GF.Domain.PurchaseManager.STATE.SUBMITTED then
        self.pendingConfirmation = nil
        return
    end
    local money = GF.Compat.GetMoney()
    if pending.moneyBefore > 0 and money <= pending.moneyBefore - pending.cost then
        self.purchase:OnSubmitEvent("confirmed", {confirmedAt = nowOf()})
        return
    end
    if nowOf() >= pending.deadline then
        self.pendingConfirmation = nil
        self.purchase:OnSubmitEvent("unknown", {reason = "confirmation_timeout"})
        self:MarkTransactionUncertain(pending.transactionId, "confirmation_timeout")
        self:ChargeBudget(pending.transactionId, pending.cost)
        printMessage(GF.L["Purchase outcome is uncertain."])
        notify("ledger")
        self:Save()
    end
end

function App:ReasonText(reason)
    local map = {
        expired = GF.L["Quote expired."],
        insufficient_funds = GF.L["Not enough gold."],
        budget = GF.L["Session budget exceeded."],
        per_purchase_limit = GF.L["Per-purchase limit exceeded."],
        commodity_disabled = GF.L["Commodity direct purchase is disabled in this build."],
        own_auction = GF.L["Own listing."],
        not_profitable = GF.L["Not profitable at the live price."],
        market_changed = GF.L["Other market history is read-only."],
        unavailable = GF.L["No live offers matched this item."],
        confirmation_timeout = GF.L["Purchase outcome is uncertain."],
    }
    return map[reason] or tostring(reason or "?")
end

function App:GetHistory(marketKey)
    return self.index:History(marketKey or self:GetMarketKey())
end

function App:ViewSnapshot(marketKey, snapshotId)
    local snapshot = self.index:GetSnapshot(marketKey, snapshotId)
    if not snapshot then
        return false, "not_found"
    end
    self.viewSnapshot = snapshot
    self.selected = nil
    notify("history")
    return true
end

function App:ClearSnapshotView()
    self.viewSnapshot = nil
    notify("history")
    return true
end

function App:GetLedgerTransactions(filter)
    return self.ledger:List(filter)
end

function App:GetLedgerMetrics()
    return self.ledger:Metrics()
end

function App:MarkReceived(transactionId, quantity)
    local record = self.ledger:Get(transactionId)
    if not record then
        return false, "not_found"
    end
    local amount = quantity or (record.purchasedQuantity - record.receivedQuantity)
    local delta, reason = self.ledger:MarkReceived(transactionId, amount)
    if not delta then
        return false, reason
    end
    notify("ledger")
    self:Save()
    return true, nil, delta
end

function App:AddProceeds(transactionId, amount, quantity)
    local record = self.ledger:Get(transactionId)
    if not record then
        return false, "not_found"
    end
    local count = quantity or (record.receivedQuantity - record.disposedQuantity)
    local disposal, reason = self.ledger:AddProceeds(transactionId, amount, count)
    if not disposal then
        return false, reason
    end
    notify("ledger")
    self:Save()
    return true
end

function App:MarkUncertain(transactionId, reason)
    local ok = self:MarkTransactionUncertain(transactionId, reason or "manual")
    if ok then
        notify("ledger")
        self:Save()
    end
    return ok
end

function App:MarkFailed(transactionId, reason)
    local record = self.ledger:Get(transactionId)
    if not record then
        return false, "not_found"
    end
    local result, failure = self.ledger:Fail(transactionId, reason or "manual")
    if not result then
        return false, failure
    end
    notify("ledger")
    self:Save()
    return true
end

function App:ResetSessionBudget()
    GF.Settings.ResetSessionBudget()
    notify("budget")
    notify("settings", "sessionBudget")
    self:Save()
end

function App:ResetFilters()
    GF.Settings.ResetFilters()
    self:RebuildVisible()
    notify("filters")
    self:Save()
end

function App:ResetAllData()
    GF.Settings.ResetAll()
    if self.index then
        self.index:Reset()
    end
    if self.ledger then
        self.ledger:Reset()
    end
    if self.notifications then
        self.notifications:Load(nil)
    end
    self.allVendor = {}
    self.allDisenchant = {}
    self.visible = {}
    self.selected = nil
    self.viewSnapshot = nil
    self:DetectMarket(true)
    self:RebuildVisible()
    notify("reset")
    notify("filters")
    notify("ledger")
    self:Save()
end

function App:GetDiagnostics()
    local report = GF.Compat.GetReport()
    local lines = GF.Compat.GetReportLines()
    lines[#lines + 1] = string.format("Scan state: %s, registered=%s, last error=%s",
        tostring(self.scanState), tostring(report.auctionator.registered), tostring(self.lastError))
    lines[#lines + 1] = string.format("Native scan: %s / collecting=%s",
        tostring(report.canScanNative), tostring(GF.NativeScan.collecting))
    lines[#lines + 1] = string.format("Disenchant skill: %s (%s)",
        tostring(GF.DisenchantBuddy.skill.verified), tostring(GF.DisenchantBuddy.skill.evidence))
    lines[#lines + 1] = string.format("Mailbox observations: %d, merchant observations: %d",
        #GF.Mailbox.observations, #GF.Merchant.observations)
    lines[#lines + 1] = string.format("Ledger transactions: %d, history markets: %d",
        #self.ledger.transactions, GF.Util.TableCount(self.index.latest))
    return lines
end

function App:PrintDiagnostics()
    local lines = self:GetDiagnostics()
    for index = 1, #lines do
        printMessage(lines[index])
    end
end

function App:GetStatusLine()
    local identity = self.identity
    local parts = {}
    parts[#parts + 1] = identity and (identity.houseLabel or "?") or "?"
    parts[#parts + 1] = self.scanState
    parts[#parts + 1] = string.format("%d/%d", #self.allVendor, #self.allDisenchant)
    return table.concat(parts, " | ")
end

--- Dependency check
function App:CheckDependencies()
    local currentSettings = settings()
    local missing = {}
    local warnings = {}

    -- Auctionator (Required unless standalone mode with native scan)
    local needAuctionator = currentSettings.standaloneMode ~= true
        and currentSettings.scanProvider ~= "native"
    if needAuctionator and not GF.AuctionatorAdapter.IsAvailable() then
        table.insert(missing, "|cffff0000Auctionator|r (required for full scans)")
    elseif GF.AuctionatorAdapter.IsAvailable() and not GF.AuctionatorAdapter.registered then
        table.insert(warnings, "|cffffff00Auctionator|r loaded but scan events not registered")
    end

    -- DisenchantBuddy (Optional - only needed if not standalone)
    local needDB = currentSettings.standaloneMode ~= true
    if needDB and not GF.DisenchantBuddy.IsAvailable() then
        table.insert(warnings, "|cff00ff00DisenchantBuddy|r (optional - disenchant estimates disabled)")
    end

    -- LibAHTab (Embedded - always available)
    local libAHTab = _G.LibStub and _G.LibStub:GetLibrary("LibAHTab-1-0", true)
    if not libAHTab then
        table.insert(missing, "|cffff0000LibAHTab|r (embedded - should never be missing)")
    end

    -- Display results
    if currentSettings.standaloneMode == true then
        printMessage("|cff00ff00GoblinFlip: Standalone Mode Active (no external dependencies required)|r")
    end

    if #missing > 0 then
        printMessage("|cffff0000GoblinFlip: Missing dependencies:|r")
        for _, m in ipairs(missing) do printMessage("  - " .. m) end
        return false
    end

    if #warnings > 0 then
        printMessage("|cffffff00GoblinFlip: Optional dependencies:|r")
        for _, w in ipairs(warnings) do printMessage("  - " .. w) end
    end

    return true
end



--- Tooltip and context menu integration
-- Toggles whether GoblinFlip shows info lines on item tooltips.
function App:ToggleFlipTooltip()
    local current = settingValue("showFlipTooltip", false)
    local newValue = not current
    GF.Settings.Set("showFlipTooltip", newValue)
    if GF.UI and GF.UI.UpdateTooltipSettings then
        pcall(GF.UI.UpdateTooltipSettings, newValue)
    end
    notify("tooltip_toggle", newValue)
    return newValue
end

--- Show a context menu for the currently hovered item or selected opportunity.
function App:ShowFlipContextMenu()
    if not self.selected then
        printMessage(GF.L["No opportunity selected."])
        return
    end
    if not settingValue("showFlipContextMenu", true) then
        printMessage(GF.L["Context menu disabled in settings."])
        return
    end

    local menu = {
        {
            text = GF.L["Open Auction House scan for this item"],
            notCheckable = true,
            func = function()
                App:RequestPurchase(self.selected)
            end,
        },
        {
            text = GF.L["Toggle tooltip"],
            notCheckable = true,
            func = function()
                App:ToggleFlipTooltip()
            end,
        },
        {
            text = GF.L["Copy item link"],
            notCheckable = true,
            func = function()
                if self.selected.itemLink then
                    local link = self.selected.itemLink
                    -- Use copying function if available
                    local copyFunc = (CopyChatEdit and CopyChatEdit.GetEditedItem) or nil
                    if copyFunc then
                        copyFunc(CopyChatEdit, link)
                    else
                        printMessage(" |cffffd200" .. link .. "|r")
                    end
                else
                    printMessage(GF.L["No item link available."])
                end
            end,
        },
        {
            text = CLOSE,
            notCheckable = true,
            func = function() end,
        },
    }

    -- Try to use UIDropDownMenu, fallback to simple print
    if UIDropDownMenu_Show then
        -- Attempt to show dropdown at cursor position
        local dropdown = CreateFrame("Frame", "GoblinFlipContextMenu", UIParent, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(dropdown, function(self2)
            for index = 1, #menu do
                local info = UIDropDownMenu_CreateInfo()
                info.text = menu[index].text
                info.notCheckable = menu[index].notCheckable
                info.func = menu[index].func
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_Show(dropdown, "cursor")
    else
        printMessage(" |cffFFD700GoblinFlip context menu:|r")
        for index = 1, #menu do
            printMenu = menu[index].text
        end
        -- Simpler approach: just print the options
        printMessage(string.format("1: %s", menu[1].text))
        printMessage(string.format("2: %s", menu[2].text))
        printMessage(string.format("3: %s", menu[3].text))
    end
end

--- Add GoblinFlip info line to an item tooltip.
-- Called from GameTooltip hooks when an item is being shown.
function App:AddTooltipInfo(tooltip)
    if not settingValue("showFlipTooltip", false) then
        return
    end

    if not self.selected then
        -- Show general scan info instead of selected opportunity
        local identity = self.identity
        if identity and identity.house ~= GF.Domain.Market.HOUSE_UNKNOWN then
            local scanInfo = string.format("%s %s |r", GF.L["Market"], identity.houseLabel or "")
            -- Try to add a line with scan status
            if type(tooltip) == "table" and tooltip.AddDoubleLine then
                tooltip:AddDoubleLine(GF.L["GoblinFlip"], scanInfo, 1.0, 1.0, 1.0, 0.82, 0.82, 0.82)
            end
        end
        return
    end

    -- Show selected opportunity info
    local opportunity = self.selected
    local profitText = GF.Util.FormatMoney(opportunity.profit or 0)
    local roiText = opportunity.roi and string.format("%.1f%%", opportunity.roi / 10) or ""

    local line = string.format("|cffFFD700GF: %s %s|r %s %s", GF.L["Flip"], opportunity.itemName or "", profitText, roiText)

    if type(tooltip) == "table" and tooltip.AddDoubleLine then
        tooltip:AddDoubleLine(GF.L["GoblinFlip"], line, 1.0, 1.0, 1.0, 0.82, 0.82, 0.82)
    elseif type(tooltip) == "table" and tooltip.AddLine then
        tooltip:AddLine(line, 1.0, 1.0, 1.0, true)
    end
end

--- Hook GameTooltip to show GoblinFlip info when toggle is on.
-- This runs after ADDON_LOADED and PLAYER_LOGIN.
function App:HookTooltips()
    if self.tooltipHooked then
        return
    end
    self.tooltipHooked = true

    -- Hook GameTooltip_SetDefaultAnchor if available
    if type(GameTooltip_SetDefaultAnchor) == "function" then
        -- We hook OnShow to add our info
    end

    -- Register for tooltip events via the frame script
    local oldOnShow = GameTooltip:GetScript("OnShow")
    GameTooltip:SetScript("OnShow", function(self2)
        if oldOnShow then
            oldOnShow(self2)
        end
        App:AddTooltipInfo(self2)
    end)

    -- Also hook ItemRefTooltip for item links
    local oldItemRefOnShow = ItemRefTooltip:GetScript("OnShow")
    ItemRefTooltip:SetScript("OnShow", function(self2)
        if oldItemRefOnShow then
            oldItemRefOnShow(self2)
        end
        App:AddTooltipInfo(self2)
    end)

    printMessage(GF.L["Tooltip integration enabled."])
end

--- Enable/disable the tooltip context menu toggle via settings.
function App:ToggleContextMenu()
    local current = settingValue("showFlipContextMenu", true)
    GF.Settings.Set("showFlipContextMenu", not current)
    notify("context_menu_toggle", not current)
    return not current
end

--- Register tooltip-related events and hooks.
function App:RegisterTooltipEvents()
    if self.tooltipEventsRegistered then
        return
    end
    self.tooltipEventsRegistered = true

    -- We hook tooltips in the Initialize function after UI is ready
    -- But register the slash command and setting changelisteners
    if type(_G.SLASH_GOBLINFLIP1) ~= "nil" then
        -- Slash command already registered, just ensure our handlers work
    end

    -- Listen for setting changes
    self:After(1, function()
        if GF.Settings then
            -- Settings change handler would call notify events
        end
    end)
end
