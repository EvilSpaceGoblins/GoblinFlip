-- Client and dependency capability probing.
-- Everything here is defensive: a missing API produces a diagnostic, never an error.

local _, GF = ...

GF.Compat = {
    probedAt = nil,
    report = nil,
}

local function getGlobal(name)
    return _G[name]
end

local function tableHasFunctions(tbl, names)
    local present = {}
    local missing = {}
    if type(tbl) ~= "table" then
        for index = 1, #names do
            missing[#missing + 1] = names[index]
        end
        return present, missing
    end
    for index = 1, #names do
        local name = names[index]
        if type(tbl[name]) == "function" then
            present[#present + 1] = name
        else
            missing[#missing + 1] = name
        end
    end
    return present, missing
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d
end

local function readAddonMetadata(name)
    local addons = getGlobal("C_AddOns")
    if addons and type(addons.GetAddOnMetadata) == "function" then
        local ok, value = pcall(addons.GetAddOnMetadata, name, "Version")
        if ok and value then
            return value
        end
    end
    local getter = getGlobal("GetAddOnMetadata")
    if type(getter) == "function" then
        local ok, value = pcall(getter, name, "Version")
        if ok and value then
            return value
        end
    end
    return nil
end

function GF.Compat.GetBuildInfo()
    local version, build, date, toc = safeCall(getGlobal("GetBuildInfo"))
    return {
        version = version,
        build = build,
        date = date,
        toc = toc,
    }
end

function GF.Compat.IsForever()
    local projectID = getGlobal("WOW_PROJECT_ID")
    local mainline = getGlobal("WOW_PROJECT_MAINLINE")
    local build = tonumber((GF.Compat.GetBuildInfo()).build) or 0
    -- Forever reports the mainline project with a build in the 16000-19999 range.
    -- Project ID alone is not enough to distinguish it from Retail.
    return projectID ~= nil and projectID == mainline and build >= 16000 and build < 20000
end

function GF.Compat.GetCharacterKey()
    local realm = safeCall(getGlobal("GetRealmName")) or "unknown-realm"
    local name = safeCall(getGlobal("UnitName"), "player") or "unknown-character"
    realm = tostring(realm):gsub("%s+", "")
    name = tostring(name):gsub("%s+", "")
    return realm .. "/" .. name
end

function GF.Compat.GetMoney()
    local money = safeCall(getGlobal("GetMoney"))
    if type(money) == "number" and money >= 0 then
        return money
    end
    return 0
end

function GF.Compat.GetAuctionatorVersion()
    return readAddonMetadata("Auctionator")
end

function GF.Compat.GetDisenchantBuddyVersion()
    return readAddonMetadata("DisenchantBuddy")
end

local AUCTION_HOUSE_APIS = {
    "SendSearchQuery",
    "GetNumItemSearchResults",
    "GetItemSearchResultInfo",
    "HasSearchResults",
    "HasFullItemSearchResults",
    "GetItemSearchResultsQuantity",
    "GetNumCommoditySearchResults",
    "GetCommoditySearchResultInfo",
    "HasFullCommoditySearchResults",
    "GetCommoditySearchResultsQuantity",
    "PlaceBid",
    "MakeItemKey",
    "GetItemKeyInfo",
}

local REPLICATE_APIS = {
    "ReplicateItems",
    "GetNumReplicateItems",
    "GetReplicateItemInfo",
    "GetReplicateItemLink",
    "GetReplicateItemTimeLeft",
}

function GF.Compat.Probe()
    local build = GF.Compat.GetBuildInfo()
    local ah = getGlobal("C_AuctionHouse")
    local item = getGlobal("C_Item")

    local ahPresent, ahMissing = tableHasFunctions(ah, AUCTION_HOUSE_APIS)
    local replicatePresent, replicateMissing = tableHasFunctions(ah, REPLICATE_APIS)

    local auctionator = getGlobal("Auctionator")
    local auctionatorInfo = {
        installed = type(auctionator) == "table",
        version = GF.Compat.GetAuctionatorVersion(),
        eventBus = type(auctionator) == "table" and type(auctionator.EventBus) == "table",
        fullScan = type(auctionator) == "table" and type(auctionator.FullScan) == "table",
        scanEvent = nil,
    }
    if auctionatorInfo.fullScan and type(auctionator.FullScan.Events) == "table" then
        auctionatorInfo.scanEvent = auctionator.FullScan.Events.ScanComplete
    end
    auctionatorInfo.contractAvailable = auctionatorInfo.eventBus
        and auctionatorInfo.scanEvent ~= nil
        and type(auctionator.FullScan.Events) == "table"

    local disenchantBuddy = getGlobal("DisenchantBuddy")
    local disenchantInfo = {
        installed = type(disenchantBuddy) == "table",
        version = GF.Compat.GetDisenchantBuddyVersion(),
        api = type(disenchantBuddy) == "table"
            and type(disenchantBuddy.API) == "table"
            and type(disenchantBuddy.API.v1) == "table"
            or false,
        valueFunction = type(disenchantBuddy) == "table"
            and type(disenchantBuddy.API) == "table"
            and type(disenchantBuddy.API.v1) == "table"
            and type(disenchantBuddy.API.v1.GetAverageDisenchantValueByItemID) == "function"
            or false,
    }

    local libStub = getGlobal("LibStub")
    local libAHTab = nil
    if type(libStub) == "table" and type(libStub.GetLibrary) == "function" then
        local ok, library = pcall(libStub.GetLibrary, libStub, "LibAHTab-1-0", true)
        if ok then
            libAHTab = library
        end
    end

    local report = {
        probedAt = type(time) == "function" and time() or nil,
        addonVersion = GF.version,
        locale = GF.locale,
        build = build,
        interface = build.toc,
        projectID = getGlobal("WOW_PROJECT_ID"),
        isMainline = getGlobal("WOW_PROJECT_ID") == getGlobal("WOW_PROJECT_MAINLINE"),
        isForever = GF.Compat.IsForever(),
        auctionHouseFrame = type(getGlobal("AuctionHouseFrame")) == "table",
        auctionHouseApis = {
            present = ahPresent,
            missing = ahMissing,
            supported = #ahMissing == 0,
        },
        replicateApis = {
            present = replicatePresent,
            missing = replicateMissing,
            supported = #replicateMissing == 0,
        },
        auctionator = auctionatorInfo,
        disenchantBuddy = disenchantInfo,
        libStub = type(libStub) == "table",
        libAHTab = type(libAHTab) == "table",
        itemApis = {
            getItemInfo = type(item) == "table" and type(item.GetItemInfo) == "function",
            getItemInfoInstant = type(item) == "table" and type(item.GetItemInfoInstant) == "function",
            getItemIconByID = type(item) == "table" and type(item.GetItemIconByID) == "function",
            getItemQualityColor = type(item) == "table" and type(item.GetItemQualityColor) == "function",
        },
        canQueryLive = type(ah) == "table"
            and type(ah.SendSearchQuery) == "function"
            and type(ah.GetNumItemSearchResults) == "function"
            and type(ah.GetItemSearchResultInfo) == "function",
        canBuyNonCommodity = type(ah) == "table" and type(ah.PlaceBid) == "function",
        canScanAuctionator = auctionatorInfo.contractAvailable and GF.AuctionatorAdapter and GF.AuctionatorAdapter.registered == true or false,
        canScanNative = #replicateMissing == 0 and (not GF.NativeScan or not GF.NativeScan.initialized or GF.NativeScan.eventRegistered),
        savedVariables = type(GoblinFlipDB) == "table",
    }

    if report.canScanAuctionator then
        report.scanProvider = "auctionator"
    elseif report.canScanNative then
        report.scanProvider = "native-unverified"
    else
        report.scanProvider = nil
    end

    GF.Compat.report = report
    GF.Compat.probedAt = report.probedAt
    return report
end

function GF.Compat.GetReport()
    return GF.Compat.report or GF.Compat.Probe()
end

function GF.Compat.GetHealth(report)
    report = report or GF.Compat.Probe()
    local function addonState(name, ready)
        if ready then return "ready" end
        local api = _G.C_AddOns or _G
        local info = api.GetAddOnInfo or _G.GetAddOnInfo
        local ok, found = pcall(function() return info and info(name) end)
        if not ok or not found then return "missing" end
        local enabled = api.GetAddOnEnableState or _G.GetAddOnEnableState
        if enabled then
            local value
            if api == _G then value = safeCall(enabled, nil, name) else value = safeCall(enabled, name) end
            if value == 0 then return "disabled" end
        end
        local loaded = api.IsAddOnLoaded or _G.IsAddOnLoaded
        if loaded and not safeCall(loaded, name) then return "not loaded" end
        return "incompatible API"
    end
    return {
        {name = "Auctionator scan", state = addonState("Auctionator", report.canScanAuctionator),
            action = "Install/enable Auctionator with FullScan events, then /reload. Scan using its Get All button."},
        {name = "Native scan", state = report.canScanNative and "ready" or "unavailable",
            action = "Requires replicate APIs and event support. Select Native in Settings when available."},
        {name = "Live query / item buying", state = report.canQueryLive and report.canBuyNonCommodity and "ready" or "unavailable",
            action = "Open the auction house on a supported client. Commodity purchases are disabled."},
        {name = "Auction house tab", state = report.libAHTab and "ready" or "unavailable",
            action = "Open the AH to attach the tab; /gf always opens the separate window."},
        {name = "DisenchantBuddy (optional)", state = addonState("DisenchantBuddy", report.disenchantBuddy.valueFunction),
            action = "Install/enable its supported API for executable estimates. Internal prices are illustrative only."},
    }
end

function GF.Compat.IsAhSupported()
    local report = GF.Compat.GetReport()
    return report.auctionHouseFrame and report.canQueryLive
end

function GF.Compat.CanScan()
    local report = GF.Compat.GetReport()
    return report.canScanAuctionator or report.canScanNative
end

function GF.Compat.CanBuy()
    local report = GF.Compat.GetReport()
    return report.canBuyNonCommodity
end

function GF.Compat.CanDisenchant()
    local report = GF.Compat.GetReport()
    return report.disenchantBuddy.valueFunction
end

function GF.Compat.GetReportLines()
    local report = GF.Compat.GetReport()
    local build = report.build or {}
    local lines = {
        string.format("GoblinFlip %s (%s)", tostring(report.addonVersion), tostring(report.locale)),
        string.format("Client %s build %s, interface %s, Forever=%s",
            tostring(build.version), tostring(build.build), tostring(build.toc), tostring(report.isForever)),
        string.format("Auction house frame: %s, live query: %s, buy: %s",
            tostring(report.auctionHouseFrame), tostring(report.canQueryLive), tostring(report.canBuyNonCommodity)),
        string.format("Auctionator: installed=%s contract=%s version=%s",
            tostring(report.auctionator.installed), tostring(report.auctionator.contractAvailable),
            tostring(report.auctionator.version)),
        string.format("Auctionator full-scan event: %s", tostring(report.auctionator.scanEvent)),
        string.format("Native replicate APIs: %s", tostring(report.replicateApis.supported)),
        string.format("DisenchantBuddy: installed=%s valueApi=%s version=%s",
            tostring(report.disenchantBuddy.installed), tostring(report.disenchantBuddy.valueFunction),
            tostring(report.disenchantBuddy.version)),
        string.format("LibAHTab: %s, LibStub: %s", tostring(report.libAHTab), tostring(report.libStub)),
    }
    if #report.auctionHouseApis.missing > 0 then
        lines[#lines + 1] = "Missing AH APIs: " .. table.concat(report.auctionHouseApis.missing, ", ")
    end
    if #report.replicateApis.missing > 0 then
        lines[#lines + 1] = "Missing replicate APIs: " .. table.concat(report.replicateApis.missing, ", ")
    end
    return lines
end

function GF.Compat.PrintDiagnostics()
    local lines = GF.Compat.GetReportLines()
    for index = 1, #lines do
        GF.Util.Print(lines[index])
    end
end
