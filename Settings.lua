-- Settings, schema migration and session budget persistence.

local _, GF = ...

GF.Settings = {
    SCHEMA_VERSION = 1,
    db = nil,
}

local DEFAULTS = {
    minProfit = 100,
    minRoi = 0,
    maxBuyout = 20000,
    sessionBudget = 200000,
    defaultSort = "profit",
    defaultSortDirection = "desc",
    scanProvider = "auctionator",
    soundAlerts = false,
    alertMinProfit = 100,
    alertMinRoi = 0,
    quoteFreshness = 10,
    historyDays = 7,
    historySnapshots = 10,
    disenchantEnabled = true,
    requireDisenchantSkill = true,
    assumeDisenchantSkill = false,
    marketHouseOverride = "auto",
    groupedView = false,
    showOwned = false,
    minQuantity = 0,
    maxQuantity = 0,
    debug = false,
    experimentalNativeScan = false,
    allowCommodityPurchase = false,
    showFlipTooltip = false,
    showFlipContextMenu = true,
    standaloneMode = false,
    cooldownHint = 900,
    soundFile = "Sound\\Interface\\AuctionWindowOpen.wav",
    minimapIcon = {
        hide = false,
        minimapPos = 225,
        radius = 80,
        lock = false,
    },
}

GF.Settings.DEFAULTS = DEFAULTS

local ENUMS = {
    defaultSort = {
        profit = true,
        roi = true,
        buyout = true,
        unit = true,
        quantity = true,
        vendor = true,
        age = true,
        name = true,
    },
    defaultSortDirection = {
        asc = true,
        desc = true,
    },
    scanProvider = {
        auctionator = true,
        native = true,
    },
    marketHouseOverride = {
        auto = true,
        horde = true,
        alliance = true,
        neutral = true,
    },
}

local MONEY_KEYS = {
    minProfit = true,
    maxBuyout = true,
    sessionBudget = true,
    alertMinProfit = true,
}

local BOOLEAN_KEYS = {
    soundAlerts = true,
    disenchantEnabled = true,
    requireDisenchantSkill = true,
    assumeDisenchantSkill = true,
    groupedView = true,
    showOwned = true,
    debug = true,
    experimentalNativeScan = true,
    allowCommodityPurchase = true,
    showFlipTooltip = true,
    showFlipContextMenu = true,
    standaloneMode = true,
}

local PERCENT_KEYS = {
    minRoi = {min = 0, max = 1000000},
    alertMinRoi = {min = 0, max = 1000000},
}

local RANGE_KEYS = {
    quoteFreshness = {min = 1, max = 60},
    historyDays = {min = 1, max = 90},
    historySnapshots = {min = 1, max = 100},
    minQuantity = {min = 0, max = 100000000},
    maxQuantity = {min = 0, max = 100000000},
    cooldownHint = {min = 60, max = 86400},
}

local function validateValue(key, value)
    if MONEY_KEYS[key] then
        if not GF.Util.IsCopper(value) then
            return nil, "Expected a non-negative whole number of copper."
        end
        return value
    end
    if BOOLEAN_KEYS[key] then
        if type(value) ~= "boolean" then
            return nil, "Expected true or false."
        end
        return value
    end
    if PERCENT_KEYS[key] then
        local rule = PERCENT_KEYS[key]
        if type(value) ~= "number" or value ~= value or value < rule.min or value > rule.max then
            return nil, "Expected a non-negative percentage."
        end
        return value
    end
    if RANGE_KEYS[key] then
        local rule = RANGE_KEYS[key]
        if not GF.Util.IsInteger(value) or value < rule.min or value > rule.max then
            return nil, string.format("Expected a whole number between %d and %d.", rule.min, rule.max)
        end
        return value
    end
    if ENUMS[key] then
        if not ENUMS[key][value] then
            return nil, "Expected one of the listed values."
        end
        return value
    end
    if key == "soundFile" then
        if type(value) ~= "string" or value == "" or #value > 260 then
            return nil, "Expected a sound file path."
        end
        return value
    end
    return nil, "Unknown setting."
end

local function normalizeQualityFilter(value)
    local normalized = {}
    if type(value) ~= "table" then
        return normalized
    end
    for key, enabled in pairs(value) do
        local quality = tonumber(key)
        if quality and quality >= 0 and quality <= 7 and enabled == true then
            normalized[quality] = true
        end
    end
    return normalized
end

local function normalizeBlacklist(value)
    local normalized = {}
    if type(value) ~= "table" then
        return normalized
    end
    for key, enabled in pairs(value) do
        if enabled == true then
            if type(key) == "number" and GF.Util.IsInteger(key) then
                normalized[key] = true
            elseif type(key) == "string" and #key <= 80 then
                normalized[key] = true
            end
        end
    end
    return normalized
end

local function ensureDatabaseShape(db)
    db.settings = type(db.settings) == "table" and db.settings or {}
    db.history = type(db.history) == "table" and db.history or {}
    db.history.snapshots = type(db.history.snapshots) == "table" and db.history.snapshots or {}
    db.ledger = type(db.ledger) == "table" and db.ledger or {}
    db.ledger.transactions = type(db.ledger.transactions) == "table" and db.ledger.transactions or {}
    db.alerts = type(db.alerts) == "table" and db.alerts or {}
    db.session = type(db.session) == "table" and db.session or {}
    db.session.spent = GF.Util.IsCopper(db.session.spent) and db.session.spent or 0
    db.session.startedAt = tonumber(db.session.startedAt) or 0
    db.diagnostics = type(db.diagnostics) == "table" and db.diagnostics or {}
end

local function applyDefaults(db)
    local diagnostics = {}
    for key, defaultValue in pairs(DEFAULTS) do
        local current = db.settings[key]
        if current == nil then
            db.settings[key] = GF.Util.DeepCopy(defaultValue)
        else
            local value, reason = validateValue(key, current)
            if value == nil then
                diagnostics[#diagnostics + 1] = string.format("%s: %s; using default", key, reason)
                db.settings[key] = GF.Util.DeepCopy(defaultValue)
            else
                db.settings[key] = value
            end
        end
    end

    db.settings.qualityFilter = normalizeQualityFilter(db.settings.qualityFilter)
    db.settings.blacklist = normalizeBlacklist(db.settings.blacklist)
    db.settings.search = type(db.settings.search) == "string" and db.settings.search or ""
    db.settings.minQuantity = math.min(db.settings.minQuantity, db.settings.maxQuantity > 0
        and db.settings.maxQuantity or db.settings.minQuantity)
    db.diagnostics.settings = diagnostics
end

function GF.Settings.Initialize(saved)
    if type(saved) ~= "table" then
        saved = {}
    end
    GF.Settings.db = saved
    ensureDatabaseShape(saved)

    if saved.schemaVersion == nil then
        saved.schemaVersion = 1
    end
    if saved.schemaVersion > GF.Settings.SCHEMA_VERSION then
        saved.diagnostics = saved.diagnostics or {}
        saved.diagnostics.schema = {
            found = saved.schemaVersion,
            supported = GF.Settings.SCHEMA_VERSION,
            message = "Saved data was written by a newer GoblinFlip version; it was not modified.",
        }
        -- Do not overwrite settings from a newer schema. Use defaults in memory.
        saved.settings = saved.settings or {}
        for key, defaultValue in pairs(DEFAULTS) do
            if saved.settings[key] == nil then
                saved.settings[key] = GF.Util.DeepCopy(defaultValue)
            end
        end
        saved.settings.qualityFilter = normalizeQualityFilter(saved.settings.qualityFilter)
        saved.settings.blacklist = normalizeBlacklist(saved.settings.blacklist)
        saved.settings.search = type(saved.settings.search) == "string" and saved.settings.search or ""
        return saved, false
    end

    applyDefaults(saved)
    return saved, true
end

function GF.Settings.Get(key)
    return GF.Settings.db.settings[key]
end

function GF.Settings.Set(key, value)
    local normalized, reason = validateValue(key, value)
    if normalized == nil then
        return false, reason
    end
    GF.Settings.db.settings[key] = normalized
    return true
end

function GF.Settings.GetAll()
    return GF.Settings.db and GF.Settings.db.settings or {}
end

function GF.Settings.GetFilters()
    local settings = GF.Settings.GetAll()
    return {
        minProfit = settings.minProfit,
        minRoi = settings.minRoi,
        maxBuyout = settings.maxBuyout,
        minQuantity = settings.minQuantity,
        maxQuantity = settings.maxQuantity,
        showOwned = settings.showOwned,
        blacklist = settings.blacklist,
        quality = settings.qualityFilter,
    }
end

function GF.Settings.ResetFilters()
    local settings = GF.Settings.db.settings
    settings.minProfit = DEFAULTS.minProfit
    settings.minRoi = DEFAULTS.minRoi
    settings.maxBuyout = DEFAULTS.maxBuyout
    settings.minQuantity = DEFAULTS.minQuantity
    settings.maxQuantity = DEFAULTS.maxQuantity
    settings.showOwned = DEFAULTS.showOwned
    settings.qualityFilter = {}
    settings.groupedView = DEFAULTS.groupedView
    settings.defaultSort = DEFAULTS.defaultSort
    settings.defaultSortDirection = DEFAULTS.defaultSortDirection
    settings.search = ""
end

function GF.Settings.IsBlacklisted(itemIdOrVariant)
    return GF.Settings.db.settings.blacklist[itemIdOrVariant] == true
end

function GF.Settings.AddBlacklist(itemIdOrVariant)
    if type(itemIdOrVariant) == "number" and not GF.Util.IsInteger(itemIdOrVariant) then
        return false
    end
    if type(itemIdOrVariant) ~= "number" and type(itemIdOrVariant) ~= "string" then
        return false
    end
    GF.Settings.db.settings.blacklist[itemIdOrVariant] = true
    return true
end

function GF.Settings.RemoveBlacklist(itemIdOrVariant)
    GF.Settings.db.settings.blacklist[itemIdOrVariant] = nil
end

function GF.Settings.GetBlacklist()
    return GF.Settings.db.settings.blacklist
end

function GF.Settings.GetSessionSpent()
    return GF.Settings.db.session.spent or 0
end

function GF.Settings.AddSessionSpent(amount)
    if not GF.Util.IsCopper(amount) then
        return false
    end
    GF.Settings.db.session.spent = (GF.Settings.db.session.spent or 0) + amount
    return true
end

function GF.Settings.ResetSessionBudget()
    GF.Settings.db.session.spent = 0
    GF.Settings.db.session.startedAt = type(_G.time) == "function" and _G.time() or 0
    return true
end

function GF.Settings.GetSessionStart()
    return GF.Settings.db.session.startedAt
end

function GF.Settings.GetCharacterKey()
    if GF.Compat and GF.Compat.GetCharacterKey then
        return GF.Compat.GetCharacterKey()
    end
    return "unknown"
end

function GF.Settings.ResetAll()
    local db = GF.Settings.db
    for key in pairs(db) do
        db[key] = nil
    end
    db.schemaVersion = GF.Settings.SCHEMA_VERSION
    ensureDatabaseShape(db)
    applyDefaults(db)
    db.session.spent = 0
    db.session.startedAt = type(_G.time) == "function" and _G.time() or 0
    return db
end

function GF.Settings.Export()
    return {
        schemaVersion = GF.Settings.SCHEMA_VERSION,
        settings = GF.Util.DeepCopy(GF.Settings.db.settings),
        session = GF.Util.DeepCopy(GF.Settings.db.session),
        ledger = GF.Util.DeepCopy(GF.Settings.db.ledger),
        history = GF.Util.DeepCopy(GF.Settings.db.history),
    }
end
