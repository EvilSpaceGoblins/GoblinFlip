-- Item metadata cache. Distinguishes an unknown vendor price (nil) from a known
-- zero vendor price (item cannot be vendored).

local _, GF = ...

GF.Domain = GF.Domain or {}
local ItemCache = {}
GF.Domain.ItemCache = ItemCache
ItemCache.__index = ItemCache

function ItemCache.New(options)
    options = options or {}
    local self = setmetatable({
        entries = {},
        pending = {},
        pendingByKey = {},
        maxAttempts = options.maxAttempts or 4,
        now = options.now or function()
            return type(time) == "function" and time() or 0
        end,
    }, ItemCache)
    return self
end

function ItemCache.KeyFor(itemId, variantKey)
    return tostring(itemId) .. "@" .. tostring(variantKey or "0:0:0:0")
end

function ItemCache:Get(itemId, variantKey)
    return self.entries[ItemCache.KeyFor(itemId, variantKey)]
end

function ItemCache:Set(itemId, variantKey, info, now)
    if not itemId or not variantKey then
        return nil
    end
    local key = ItemCache.KeyFor(itemId, variantKey)
    local existing = self.entries[key] or {}
    local entry = {
        itemId = itemId,
        variantKey = variantKey,
        sellPrice = info.sellPrice,
        name = info.name or existing.name,
        quality = info.quality or existing.quality,
        itemLevel = info.itemLevel or existing.itemLevel,
        classId = info.classId or existing.classId,
        subClassId = info.subClassId or existing.subClassId,
        icon = info.icon or existing.icon,
        itemLink = info.itemLink or existing.itemLink,
        resolvedAt = now or self.now(),
        source = info.source or existing.source or "item-info",
        attempts = info.attempts or existing.attempts or 0,
        failed = info.failed or false,
    }
    self.entries[key] = entry
    return entry
end

function ItemCache:MarkPending(itemId, variantKey, now)
    if not itemId or not variantKey then
        return false
    end
    local key = ItemCache.KeyFor(itemId, variantKey)
    if self.pendingByKey[key] then
        return false
    end
    local entry = {
        key = key,
        itemId = itemId,
        variantKey = variantKey,
        requestedAt = now or self.now(),
        attempts = 0,
    }
    self.pendingByKey[key] = entry
    self.pending[#self.pending + 1] = entry
    return true
end

function ItemCache:IsPending(itemId, variantKey)
    return self.pendingByKey[ItemCache.KeyFor(itemId, variantKey)] ~= nil
end

function ItemCache:TakePendingBatch(maxItems)
    local batch = {}
    maxItems = maxItems or 25
    while #batch < maxItems and #self.pending > 0 do
        local entry = table.remove(self.pending, 1)
        if self.pendingByKey[entry.key] then
            self.pendingByKey[entry.key] = nil
            entry.attempts = entry.attempts + 1
            batch[#batch + 1] = entry
        end
    end
    return batch
end

function ItemCache:Requeue(entry)
    if not entry or not entry.key then
        return false
    end
    if entry.attempts >= self.maxAttempts then
        return false
    end
    if self.pendingByKey[entry.key] then
        return false
    end
    self.pendingByKey[entry.key] = entry
    self.pending[#self.pending + 1] = entry
    return true
end

function ItemCache:MarkFailed(itemId, variantKey, reason)
    local key = ItemCache.KeyFor(itemId, variantKey)
    local entry = self.entries[key]
    if entry then
        entry.failed = true
        entry.failureReason = reason
    end
    self.pendingByKey[key] = nil
end

--- Attach resolved metadata to a listing. Returns true only when the exact
--- variant's vendor price is known (including a known zero).
function ItemCache:Apply(listing)
    if not listing or not listing.itemId or not listing.variantKey then
        return false
    end
    local entry = self:Get(listing.itemId, listing.variantKey)
    if not entry then
        return false
    end
    listing.itemName = entry.name
    listing.itemQuality = entry.quality
    listing.itemLevel = entry.itemLevel or listing.itemLevel
    listing.classId = entry.classId
    listing.subClassId = entry.subClassId
    listing.itemIcon = entry.icon
    if not listing.itemLink and entry.itemLink then
        listing.itemLink = entry.itemLink
    end
    if entry.sellPrice == nil then
        return false
    end
    listing.vendorUnit = entry.sellPrice
    listing.vendorSource = entry.source
    return true
end

function ItemCache:Stats()
    local resolved = 0
    local vendorable = 0
    local nonVendorable = 0
    local unknown = 0
    for _, entry in pairs(self.entries) do
        if entry.sellPrice == nil then
            unknown = unknown + 1
        else
            resolved = resolved + 1
            if entry.sellPrice > 0 then
                vendorable = vendorable + 1
            else
                nonVendorable = nonVendorable + 1
            end
        end
    end
    return {
        entries = GF.Util.TableCount(self.entries),
        resolved = resolved,
        vendorable = vendorable,
        nonVendorable = nonVendorable,
        unknown = unknown,
        pending = #self.pending,
    }
end

function ItemCache:Reset()
    self.entries = {}
    self.pending = {}
    self.pendingByKey = {}
end
