-- GoblinFlip - shared namespace, constants and small pure helpers.
-- All money values inside the addon are integer copper.

local ADDON, GF = ...
if type(GF) ~= "table" then
    GF = _G.GoblinFlip or {}
    _G.GoblinFlip = GF
end

GF.name = ADDON or "GoblinFlip"
GF.version = "1.2.0"

GF.COPPER_PER_SILVER = 100
GF.COPPER_PER_GOLD = 10000
GF.MAX_COPPER = 9007199254740991 -- largest exactly representable integer

GF.STRATEGY_VENDOR = "vendor"
GF.STRATEGY_DISENCHANT = "disenchant"

GF.SCAN_STATE = {
    IDLE = "IDLE",
    REQUESTED = "REQUESTED",
    RECEIVING = "RECEIVING",
    NORMALIZING = "NORMALIZING",
    RESOLVING_ITEMS = "RESOLVING_ITEMS",
    READY = "READY",
    COOLDOWN = "COOLDOWN",
    ERROR = "ERROR",
    CANCELLED = "CANCELLED",
    PARTIAL = "PARTIAL",
}

GF.TX_STATUS = {
    SUBMITTED = "submitted",
    CONFIRMED = "confirmed",
    AWAITING_MAIL = "awaiting_mail",
    PARTIALLY_RECEIVED = "partially_received",
    RECEIVED = "received",
    PARTIALLY_DISPOSED = "partially_disposed",
    DISPOSED = "disposed",
    UNCERTAIN = "uncertain",
    FAILED = "failed",
    CANCELLED = "cancelled",
}

GF.Util = {}

function GF.Util.IsFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

--- Integer copper (or any non-negative integer amount) that is exactly representable.
function GF.Util.IsInteger(value, allowNegative)
    if not GF.Util.IsFiniteNumber(value) or value % 1 ~= 0 then
        return false
    end
    if not allowNegative and value < 0 then
        return false
    end
    return math.abs(value) <= GF.MAX_COPPER
end

function GF.Util.IsCopper(value)
    return GF.Util.IsInteger(value, false)
end

function GF.Util.Clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

function GF.Util.Trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function GF.Util.Copy(source)
    local target = {}
    for key, value in pairs(source or {}) do
        target[key] = value
    end
    return target
end

function GF.Util.DeepCopy(source, seen)
    if type(source) ~= "table" then
        return source
    end
    seen = seen or {}
    if seen[source] then
        return seen[source]
    end
    local target = {}
    seen[source] = target
    for key, value in pairs(source) do
        target[GF.Util.DeepCopy(key, seen)] = GF.Util.DeepCopy(value, seen)
    end
    return target
end

--- Format integer copper as "1g 2s 3c". Zero is "0c".
function GF.Util.FormatMoney(copper)
    if not GF.Util.IsFiniteNumber(copper) then
        return "?"
    end
    local rounded = copper >= 0 and math.floor(copper + 0.5) or math.ceil(copper - 0.5)
    local sign = rounded < 0 and "-" or ""
    local remaining = math.abs(rounded)
    local gold = math.floor(remaining / GF.COPPER_PER_GOLD)
    remaining = remaining - gold * GF.COPPER_PER_GOLD
    local silver = math.floor(remaining / GF.COPPER_PER_SILVER)
    local copperPart = remaining - silver * GF.COPPER_PER_SILVER

    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = gold .. "g"
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. "s"
    end
    if copperPart > 0 or #parts == 0 then
        parts[#parts + 1] = copperPart .. "c"
    end
    return sign .. table.concat(parts, " ")
end

--- Parse user money input. Plain numbers are copper; "1g 20s 5c" also works.
--- Returns nil, reason for invalid input. Never rounds fractional copper.
function GF.Util.ParseMoney(text)
    if type(text) == "number" then
        if GF.Util.IsCopper(text) then
            return text
        end
        return nil, "Money must be a non-negative whole number of copper."
    end
    if type(text) ~= "string" then
        return nil, "Money input must be text."
    end

    local value = GF.Util.Trim(text)
    if value == "" then
        return nil, "Money input is empty."
    end

    if value:match("^%d+$") then
        local copper = tonumber(value)
        if not copper or not GF.Util.IsCopper(copper) then
            return nil, "Money is too large."
        end
        return copper
    end

    local total = 0
    local consumed = 1
    local found = false
    while consumed <= #value do
        local startIndex, endIndex, amountText, unit = value:find("^(%d+)%s*([gsc])", consumed)
        if not startIndex then
            break
        end
        found = true
        local amount = tonumber(amountText)
        if not amount or not GF.Util.IsInteger(amount, false) then
            return nil, "Money components must be whole numbers."
        end
        if unit == "g" then
            total = total + amount * GF.COPPER_PER_GOLD
        elseif unit == "s" then
            total = total + amount * GF.COPPER_PER_SILVER
        else
            total = total + amount
        end
        if total > GF.MAX_COPPER then
            return nil, "Money is too large."
        end
        consumed = endIndex + 1
        while consumed <= #value and value:sub(consumed, consumed):match("%s") do
            consumed = consumed + 1
        end
    end

    if not found or consumed <= #value then
        return nil, "Use copper, or gold/silver/copper such as 1g 20s 5c."
    end
    return total
end

function GF.Util.FormatPercent(value)
    if not GF.Util.IsFiniteNumber(value) then
        return "?"
    end
    if math.abs(value) >= 1000 then
        return string.format("%.0f%%", value)
    end
    if math.abs(value) >= 100 then
        return string.format("%.1f%%", value)
    end
    return string.format("%.2f%%", value)
end

function GF.Util.FormatAge(seconds, now)
    if not GF.Util.IsFiniteNumber(seconds) then
        seconds = 0
    end
    if seconds < 0 then
        seconds = 0
    end
    if seconds < 60 then
        return "just now"
    end
    if seconds < 3600 then
        return string.format("%dm ago", math.floor(seconds / 60))
    end
    if seconds < 86400 then
        return string.format("%dh ago", math.floor(seconds / 3600))
    end
    return string.format("%dd ago", math.floor(seconds / 86400))
end

--- Stable merge sort. comparator(a, b) returns true when a belongs before b.
function GF.Util.SortStable(items, comparator)
    if #items < 2 then
        local copy = {}
        for index = 1, #items do
            copy[index] = items[index]
        end
        return copy
    end

    local middle = math.floor(#items / 2)
    local left = {}
    local right = {}
    for index = 1, middle do
        left[index] = items[index]
    end
    for index = middle + 1, #items do
        right[index - middle] = items[index]
    end
    left = GF.Util.SortStable(left, comparator)
    right = GF.Util.SortStable(right, comparator)

    local merged = {}
    local leftIndex = 1
    local rightIndex = 1
    while leftIndex <= #left and rightIndex <= #right do
        -- Take the right item only when it is strictly before the left item,
        -- which keeps equal items in their original order.
        if comparator(right[rightIndex], left[leftIndex]) then
            merged[#merged + 1] = right[rightIndex]
            rightIndex = rightIndex + 1
        else
            merged[#merged + 1] = left[leftIndex]
            leftIndex = leftIndex + 1
        end
    end
    while leftIndex <= #left do
        merged[#merged + 1] = left[leftIndex]
        leftIndex = leftIndex + 1
    end
    while rightIndex <= #right do
        merged[#merged + 1] = right[rightIndex]
        rightIndex = rightIndex + 1
    end
    return merged
end

function GF.Util.RoundTo(value, places)
    local factor = 10 ^ (places or 0)
    return math.floor(value * factor + 0.5) / factor
end

function GF.Util.TableCount(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
        count = count + 1
    end
    return count
end

function GF.Util.SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return true, result
    end
    return false, result
end

local idCounter = 0
function GF.Util.NewId(prefix)
    idCounter = idCounter + 1
    local stamp = 0
    if type(time) == "function" then
        local ok, value = pcall(time)
        if ok and type(value) == "number" then
            stamp = value
        end
    end
    return string.format("%s-%d-%d", prefix or "gf", stamp, idCounter)
end

function GF.Util.Print(message)
    local text = tostring(message)
    if type(DEFAULT_CHAT_FRAME) == "table" and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200GoblinFlip:|r " .. text)
    elseif type(print) == "function" then
        print("GoblinFlip: " .. text)
    end
end

--- Bounded debug log. Never intended to capture character data.
GF.Debug = {
    enabled = false,
    maxEntries = 250,
    entries = {},
}

function GF.Debug:Log(...)
    if not self.enabled then
        return
    end
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = table.concat(parts, " ")
    self.entries[#self.entries + 1] = message
    if #self.entries > self.maxEntries then
        table.remove(self.entries, 1)
    end
    if type(DEFAULT_CHAT_FRAME) == "table" and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888GoblinFlip debug:|r " .. message)
    end
end

function GF.Debug:Dump()
    if #self.entries == 0 then
        GF.Util.Print("No debug entries recorded.")
        return
    end
    for index = 1, #self.entries do
        GF.Util.Print(self.entries[index])
    end
end

function GF.Debug:Clear()
    self.entries = {}
end
