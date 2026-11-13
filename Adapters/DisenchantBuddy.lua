-- DisenchantBuddy adapter. DisenchantBuddy is optional; every entry point is
-- defensive and reports a reason instead of erroring. Values are treated as an
-- estimate of net material value, never as a guaranteed sale.

local _, GF = ...

GF.DisenchantBuddy = {
    initialized = false,
    cache = {},
    cacheTtl = 3600,
    skill = {
        verified = nil,
        reason = nil,
        rank = nil,
        evidence = nil,
        checkedAt = 0,
    },
}

local ENCHANTING_SKILL_LINE_ID = 333
local SKILL_CACHE_SECONDS = 300

local function api()
    return _G.DisenchantBuddy
end

local function valueApi()
    local addon = api()
    if type(addon) ~= "table" or type(addon.API) ~= "table" then
        return nil
    end
    local v1 = addon.API.v1
    if type(v1) ~= "table" then
        return nil
    end
    if type(v1.GetAverageDisenchantValueByItemID) == "function" then
        return v1.GetAverageDisenchantValueByItemID
    end
    return nil
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if not ok then
        return false
    end
    return true, a, b, c, d, e, f, g
end

local function positiveRank(value)
    if type(value) ~= "number" or value ~= value or value < 0 then
        return nil
    end
    return math.floor(value)
end

local function looksLikeEnchanting(name)
    if type(name) ~= "string" then
        return false
    end
    local lower = name:lower()
    return lower:find("enchant", 1, true) ~= nil
        or lower:find("verzauber", 1, true) ~= nil
end

local function readModernProfession()
    local trade = _G.C_TradeSkillUI
    if type(trade) ~= "table" then
        return nil
    end
    if type(trade.GetProfessionInfoBySkillLineID) == "function" then
        local ok, info = safeCall(trade.GetProfessionInfoBySkillLineID, ENCHANTING_SKILL_LINE_ID)
        if ok and type(info) == "table" then
            local rank = positiveRank(info.skillLevel or info.rank)
            if rank and rank > 0 then
                return rank, "C_TradeSkillUI.GetProfessionInfoBySkillLineID"
            end
        end
    end
    if type(trade.GetTradeSkillLineForSkillLineID) == "function" then
        local ok, a, b, c, d, e, f = safeCall(
            trade.GetTradeSkillLineForSkillLineID, ENCHANTING_SKILL_LINE_ID)
        if ok then
            -- Different builds order the return values differently. Accept the
            -- first plausible rank only when a name-like result confirms the line.
            local candidates = {a, b, c, d, e, f}
            local named
            for index = 1, #candidates do
                if looksLikeEnchanting(candidates[index]) then
                    named = true
                end
            end
            local rank = positiveRank(d) or positiveRank(e) or positiveRank(f)
            if named and rank and rank > 0 then
                return rank, "C_TradeSkillUI.GetTradeSkillLineForSkillLineID"
            end
        end
    end
    return nil
end

local function readLegacySkillLines()
    if type(_G.GetNumSkillLines) ~= "function" or type(_G.GetSkillLineInfo) ~= "function" then
        return nil
    end
    local ok, count = safeCall(_G.GetNumSkillLines)
    if not ok or type(count) ~= "number" then
        return nil
    end
    for index = 1, count do
        local lineOk, name, isHeader, rank, maxRank = safeCall(_G.GetSkillLineInfo, index)
        if lineOk and not isHeader and looksLikeEnchanting(name) then
            local value = positiveRank(rank)
            if value and value > 0 then
                return value, "GetSkillLineInfo"
            end
        end
    end
    return nil
end

local function readOpenProfession()
    if type(_G.GetTradeSkillLine) ~= "function" then
        return nil
    end
    local ok, name, rank = safeCall(_G.GetTradeSkillLine)
    if ok and looksLikeEnchanting(name) then
        local value = positiveRank(rank)
        if value and value > 0 then
            return value, "GetTradeSkillLine"
        end
    end
    return nil
end

--- Detect Enchanting. Returns verified, reason, rank.
function GF.DisenchantBuddy.DetectSkill(force)
    local skill = GF.DisenchantBuddy.skill
    local now = type(time) == "function" and time() or 0
    if not force and skill.checkedAt > 0 and now - skill.checkedAt < SKILL_CACHE_SECONDS then
        return skill.verified == true, skill.reason, skill.rank
    end

    skill.checkedAt = now
    local settings = GF.Settings and GF.Settings.GetAll and GF.Settings.GetAll() or {}
    if settings.assumeDisenchantSkill == true then
        skill.verified = true
        skill.rank = skill.rank or 1
        skill.reason = nil
        skill.evidence = "manual-override"
        return true, nil, skill.rank
    end

    local rank, evidence = readModernProfession()
    if not rank then
        rank, evidence = readOpenProfession()
    end
    if not rank then
        rank, evidence = readLegacySkillLines()
    end

    if rank then
        skill.verified = true
        skill.rank = rank
        skill.reason = nil
        skill.evidence = evidence
        return true, nil, rank
    end

    skill.verified = false
    skill.rank = nil
    skill.evidence = nil
    skill.reason = "enchanting_not_detected"
    return false, skill.reason, nil
end

function GF.DisenchantBuddy.GetSkillStatus(force)
    local verified, reason, rank = GF.DisenchantBuddy.DetectSkill(force)
    return {
        verified = verified,
        reason = reason,
        rank = rank,
        evidence = GF.DisenchantBuddy.skill.evidence,
    }
end

local function extractValue(first, second)
    local value
    if type(first) == "number" then
        value = first
    elseif type(first) == "table" then
        local fields = {
            "expectedNetPerItem", "netValue", "averageValue",
            "averageDisenchantValue", "value", "copper", "price",
        }
        for index = 1, #fields do
            local candidate = first[fields[index]]
            if type(candidate) == "number" then
                value = candidate
                break
            end
        end
        if value == nil and type(first.average) == "number" then
            value = first.average
        end
    elseif type(second) == "number" then
        value = second
    end
    if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 then
        return nil
    end
    return math.floor(value + 0.5)
end

function GF.DisenchantBuddy.IsAvailable()
    return valueApi() ~= nil
end

--- Estimate data for one item ID. Returns nil, reason when unavailable.
--- The returned table matches the Domain.DisenchantStrategy contract.
function GF.DisenchantBuddy.GetEstimate(itemId, options)
    options = options or {}
    local getter = valueApi()
    if not getter then
        return nil, "disenchantbuddy_unavailable"
    end
    if type(itemId) ~= "number" or itemId <= 0 then
        return nil, "invalid_item"
    end

    local now = type(time) == "function" and time() or 0
    local cached = GF.DisenchantBuddy.cache[itemId]
    if not options.force and cached and now - cached.at < GF.DisenchantBuddy.cacheTtl then
        return cached.data, nil
    end

    local ok, first, second = safeCall(getter, itemId)
    if not ok then
        return nil, "disenchantbuddy_error"
    end
    local value = extractValue(first, second)
    if value == nil then
        return nil, "value_unavailable"
    end

    local skillVerified, skillReason = GF.DisenchantBuddy.DetectSkill()
    local data = {
        available = true,
        provider = "DisenchantBuddy",
        expectedNetPerItem = value,
        saleFeeRate = 0,
        asOf = now,
        stale = false,
        skillVerified = skillVerified,
        skillReason = skillReason,
        assumptions = {
            "DisenchantBuddy average value is treated as net material value.",
            "Actual disenchant results and material prices can differ.",
        },
    }
    GF.DisenchantBuddy.cache[itemId] = {at = now, data = data}
    return data, nil
end

function GF.DisenchantBuddy.ClearCache()
    GF.DisenchantBuddy.cache = {}
end

function GF.DisenchantBuddy.Initialize()
    if GF.DisenchantBuddy.initialized then
        return
    end
    GF.DisenchantBuddy.initialized = true
    GF.DisenchantBuddy.DetectSkill(true)
end
