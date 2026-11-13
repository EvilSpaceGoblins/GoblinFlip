-- Market identity and auction-house detection.
-- Forever separates faction houses and a neutral (Blackwater) house. The client does
-- not expose a reliable "which house am I standing at" API, so we use zone evidence
-- and an explicit manual override. Unknown is never merged with a known market.

local _, GF = ...

GF.Domain = GF.Domain or {}
local Market = {}
GF.Domain.Market = Market

Market.HOUSE_HORDE = "horde"
Market.HOUSE_ALLIANCE = "alliance"
Market.HOUSE_NEUTRAL = "neutral"
Market.HOUSE_UNKNOWN = "unknown"

Market.OVERRIDE_AUTO = "auto"

local NEUTRAL_ZONES = {
    ["booty bay"] = true,
    ["beutebucht"] = true,
    ["gadgetzan"] = true,
    ["everlook"] = true,
    ["immerfrost"] = true,
    ["area 52"] = true,
    ["area 52 "] = true,
}

local ALLIANCE_ZONES = {
    ["stormwind city"] = true,
    ["sturmwind"] = true,
    ["ironforge"] = true,
    ["eisenschmiede"] = true,
    ["darnassus"] = true,
    ["the exodar"] = true,
    ["exodar"] = true,
    ["valsharah"] = true,
}

local HORDE_ZONES = {
    ["orgrimmar"] = true,
    ["thunder bluff"] = true,
    ["donnerfels"] = true,
    ["undercity"] = true,
    ["unterstadt"] = true,
    ["silvermoon city"] = true,
    ["silbermond"] = true,
    ["shattrath city"] = true,
}

local REGION_NAMES = {
    [1] = "US",
    [2] = "KR",
    [3] = "EU",
    [4] = "TW",
    [5] = "CN",
}

local function trimLower(value)
    if type(value) ~= "string" then
        return ""
    end
    local text = value:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    return text:gsub("%s+", " ")
end

function Market.NormalizeFaction(value)
    if type(value) ~= "string" then
        return nil
    end
    local faction = value:lower()
    if faction == "alliance" or faction == "allianz" then
        return "alliance"
    end
    if faction == "horde" then
        return "horde"
    end
    return nil
end

function Market.HouseFromFaction(faction)
    local normalized = Market.NormalizeFaction(faction)
    if normalized == "alliance" then
        return Market.HOUSE_ALLIANCE
    end
    if normalized == "horde" then
        return Market.HOUSE_HORDE
    end
    return Market.HOUSE_UNKNOWN
end

function Market.NormalizeOverride(value)
    if value == Market.HOUSE_HORDE or value == Market.HOUSE_ALLIANCE or value == Market.HOUSE_NEUTRAL then
        return value
    end
    return Market.OVERRIDE_AUTO
end

--- Returns house, evidence, verified, requiresOverride.
function Market.HouseForLocation(zone, subZone, override, faction)
    local selected = Market.NormalizeOverride(override)
    if selected ~= Market.OVERRIDE_AUTO then
        return selected, "manual", true, false
    end

    local candidates = {trimLower(subZone), trimLower(zone)}
    for index = 1, #candidates do
        local candidate = candidates[index]
        if candidate ~= "" then
            if NEUTRAL_ZONES[candidate] then
                return Market.HOUSE_NEUTRAL, "zone", true, false
            end
            if ALLIANCE_ZONES[candidate] then
                local house = Market.HouseFromFaction(faction)
                if house == Market.HOUSE_ALLIANCE then
                    return Market.HOUSE_ALLIANCE, "zone", true, false
                end
                -- The zone is an Alliance city but the character's faction is
                -- unknown, so do not pretend the market is verified.
                return Market.HOUSE_UNKNOWN, "zone-faction-mismatch", false, true
            end
            if HORDE_ZONES[candidate] then
                local house = Market.HouseFromFaction(faction)
                if house == Market.HOUSE_HORDE then
                    return Market.HOUSE_HORDE, "zone", true, false
                end
                return Market.HOUSE_UNKNOWN, "zone-faction-mismatch", false, true
            end
        end
    end

    return Market.HOUSE_UNKNOWN, "unknown", false, true
end

function Market.HouseLabel(house)
    if house == Market.HOUSE_HORDE then
        return GF.L["Horde"]
    end
    if house == Market.HOUSE_ALLIANCE then
        return GF.L["Alliance"]
    end
    if house == Market.HOUSE_NEUTRAL then
        return GF.L["Neutral / Blackwater"]
    end
    return GF.L["Unknown market"]
end

local function sanitizePart(value)
    local text = tostring(value or "unknown")
    text = text:gsub("%s+", "-")
    text = text:gsub("[:|/\\]", "-")
    return text
end

function Market.BuildKey(identity)
    local flavor = sanitizePart(identity.flavor or "wowf")
    local interface = sanitizePart(identity.interface or "unknown")
    local region = sanitizePart(identity.region or "unknown"):upper()
    local realm = sanitizePart(identity.realm or "unknown")
    local house = sanitizePart(identity.house or Market.HOUSE_UNKNOWN)
    return string.format("%s-%s:%s:%s:%s", flavor, interface, region, realm, house)
end

function Market.ParseKey(key)
    if type(key) ~= "string" then
        return nil
    end
    local flavorInterface, region, realm, house = key:match("^(.-):(.-):(.-):(.-)$")
    if not flavorInterface then
        return nil
    end
    local flavor, interface = flavorInterface:match("^(.-)%-(.+)$")
    return {
        flavor = flavor,
        interface = interface,
        region = region,
        realm = realm,
        house = house,
        key = key,
    }
end

function Market.IsAccessible(identity, faction)
    if not identity then
        return false
    end
    if identity.house == Market.HOUSE_NEUTRAL then
        return true
    end
    local playerHouse = Market.HouseFromFaction(faction)
    return identity.house ~= Market.HOUSE_UNKNOWN and identity.house == playerHouse
end

local function readEnv(env, name, ...)
    local fn = env and env[name]
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn, ...)
    if not ok then
        return nil
    end
    return value
end

local function readBuildInfo(env)
    local fn = env and env.getBuildInfo
    if type(fn) ~= "function" then
        return {version = "unknown", build = 0, toc = 0}
    end
    local ok, a, b, c, d = pcall(fn)
    if not ok then
        return {version = "unknown", build = 0, toc = 0}
    end
    if type(a) == "table" then
        return a
    end
    return {
        version = a,
        build = b,
        date = c,
        toc = d,
    }
end

local function defaultEnv()
    return {
        getBuildInfo = _G.GetBuildInfo,
        getRealmName = _G.GetRealmName,
        getRegion = _G.GetCurrentRegion,
        getRegionName = _G.GetCurrentRegionName,
        getFaction = function()
            return _G.UnitFactionGroup and _G.UnitFactionGroup("player")
        end,
        getZoneText = _G.GetZoneText,
        getSubZoneText = _G.GetSubZoneText,
        isInInstance = _G.IsInInstance,
    }
end

--- Build the identity for the character's current location.
--- env is injectable for tests; defaults to the WoW globals.
function Market.GetCurrent(env, options)
    env = env or defaultEnv()
    options = options or {}

    local build = readBuildInfo(env)

    local region = readEnv(env, "getRegionName")
    if type(region) ~= "string" or region == "" then
        local regionID = tonumber(readEnv(env, "getRegion"))
        region = REGION_NAMES[regionID] or "UNKNOWN"
    else
        region = region:upper()
        if region == "EUROPE" then
            region = "EU"
        elseif region == "NORTH AMERICA" or region == "AMERICAS" then
            region = "US"
        end
    end

    local faction = Market.NormalizeFaction(readEnv(env, "getFaction"))
    local zone = readEnv(env, "getZoneText")
    local subZone = readEnv(env, "getSubZoneText")
    local inInstance = readEnv(env, "isInInstance")

    local house, evidence, verified, requiresOverride = Market.HouseForLocation(
        zone, subZone, options.override, faction)

    local realm = readEnv(env, "getRealmName") or "unknown"
    local isForever = options.isForever
    if isForever == nil then
        isForever = GF.Compat and GF.Compat.IsForever and GF.Compat.IsForever()
    end

    local identity = {
        flavor = isForever and "wowf" or "unknown",
        interface = tostring(build.toc or options.interface or "unknown"),
        clientVersion = build.version,
        clientBuild = build.build,
        region = region,
        realm = tostring(realm),
        house = house,
        houseLabel = Market.HouseLabel(house),
        faction = faction,
        zone = zone,
        subZone = subZone,
        inInstance = inInstance == true,
        evidence = evidence,
        verified = verified,
        requiresOverride = requiresOverride,
        detectedAt = type(time) == "function" and time() or 0,
    }
    identity.key = Market.BuildKey(identity)
    identity.accessible = Market.IsAccessible(identity, faction)
    identity.readOnly = not identity.accessible
    return identity
end

function Market.SameKey(left, right)
    if type(left) == "table" then
        left = left.key
    end
    if type(right) == "table" then
        right = right.key
    end
    return left ~= nil and left == right
end

function Market.Describe(identity)
    if not identity then
        return GF.L["Unknown market"]
    end
    local parts = {}
    parts[#parts + 1] = identity.houseLabel or Market.HouseLabel(identity.house)
    if identity.region and identity.realm then
        parts[#parts + 1] = identity.region .. " / " .. identity.realm
    end
    return table.concat(parts, " - ")
end
