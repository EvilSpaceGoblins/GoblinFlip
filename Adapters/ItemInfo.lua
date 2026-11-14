-- Item metadata adapter. Keeps WoW API access at the boundary and resolves
-- vendor sell prices asynchronously with bounded retries.

local _, GF = ...

GF.ItemInfo = {
    initialized = false,
    cache = nil,
    resolver = nil,
}

local function getItemApi()
    return _G.C_Item
end

local function safeRegister(frame, event)
    if not event then
        return false
    end
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end

local function readItemInfo(identifier)
    local item = getItemApi()
    if not item or type(item.GetItemInfo) ~= "function" then
        return nil
    end
    local function capture(...) return {n = select("#", ...), ...} end
    local ok, values = pcall(function() return capture(item.GetItemInfo(identifier)) end)
    if not ok then
        return nil
    end
    return (unpack or table.unpack)(values, 1, values.n)
end

function GF.ItemInfo.Initialize()
    if GF.ItemInfo.initialized then
        return
    end
    GF.ItemInfo.initialized = true
    GF.ItemInfo.cache = GF.Domain.ItemCache.New()
    GF.ItemInfo.pendingLinks = {}

    local frame = CreateFrame("Frame")
    GF.ItemInfo.frame = frame
    safeRegister(frame, "GET_ITEM_INFO_RECEIVED")
    safeRegister(frame, "ITEM_DATA_LOAD_RESULT")
    frame:SetScript("OnEvent", function()
        GF.ItemInfo:TryPending()
    end)

    local ticker = CreateFrame("Frame")
    GF.ItemInfo.ticker = ticker
    ticker:Hide()
    ticker.elapsed = 0
    ticker:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.25 then
            return
        end
        self.elapsed = 0
        GF.ItemInfo:TryPending()
        if GF.ItemInfo.resolver then
            GF.ItemInfo.resolver.attempts = GF.ItemInfo.resolver.attempts + 1
            if GF.ItemInfo.resolver.attempts >= 16 then
                GF.ItemInfo:FinishResolve(true)
            end
        end
    end)
end

function GF.ItemInfo.GetItemKey(listing)
    if not listing then
        return nil
    end
    if listing.itemKey then
        return listing.itemKey
    end
    local ah = _G.C_AuctionHouse
    if not ah or type(ah.MakeItemKey) ~= "function" then
        return nil
    end
    local ok, key = pcall(ah.MakeItemKey,
        listing.itemId,
        listing.itemLevel or 0,
        listing.itemSuffix or 0,
        listing.battlePetSpeciesID or 0)
    if ok then
        listing.itemKey = key
        return key
    end
    return nil
end

function GF.ItemInfo.IsCommodity(itemKey)
    if not itemKey then
        return nil
    end
    local ah = _G.C_AuctionHouse
    if not ah or type(ah.GetItemKeyInfo) ~= "function" then
        return nil
    end
    local ok, info = pcall(ah.GetItemKeyInfo, itemKey)
    if not ok or type(info) ~= "table" then
        return nil
    end
    return info.isCommodity == true
end

--- Returns true when item info (including a known sell price) is available.
function GF.ItemInfo:ResolveOne(itemId, variantKey, itemLink)
    if not itemId or not variantKey then
        return false
    end
    local identifier = itemLink or itemId
    local values = {readItemInfo(identifier)}
    if not values[1] then
        return false
    end

    local name = values[1]
    local resolvedLink = values[2]
    local quality = values[3]
    local icon = values[10]
    local sellPrice = values[11]

    if not name then
        return false
    end

    self.cache:Set(itemId, variantKey, {
        sellPrice = sellPrice,
        name = name,
        quality = quality,
        itemLevel = values[4],
        classId = values[12],
        subClassId = values[13],
        icon = icon,
        itemLink = resolvedLink,
        source = "C_Item.GetItemInfo",
    })
    return true
end

function GF.ItemInfo:Prime(listings)
    local seen = {}
    for index = 1, #listings do
        local listing = listings[index]
        local variantKey = listing.variantKey
        if variantKey then
            local cacheKey = GF.Domain.ItemCache.KeyFor(listing.itemId, variantKey)
            if not seen[cacheKey] then
                seen[cacheKey] = true
                local entry = self.cache:Get(listing.itemId, variantKey)
                if not entry or entry.sellPrice == nil then
                    local resolved = self:ResolveOne(listing.itemId, variantKey, listing.itemLink)
                    if not resolved then
                        self.cache:MarkPending(listing.itemId, variantKey)
                        self.pendingLinks[cacheKey] = listing.itemLink
                    end
                end
                if not listing.itemKey then
                    GF.ItemInfo.GetItemKey(listing)
                end
            end
        end
    end
    return #self.cache.pending
end

function GF.ItemInfo:TryPending()
    if not self.cache then
        return
    end
    local batch = self.cache:TakePendingBatch(20)
    for index = 1, #batch do
        local entry = batch[index]
        local cacheKey = GF.Domain.ItemCache.KeyFor(entry.itemId, entry.variantKey)
        local link = self.pendingLinks[cacheKey]
        if not self:ResolveOne(entry.itemId, entry.variantKey, link) then
            if not self.cache:Requeue(entry) then
                self.cache:MarkFailed(entry.itemId, entry.variantKey, "item info unavailable")
            end
        else
            self.pendingLinks[cacheKey] = nil
        end
    end
    if #self.cache.pending == 0 then
        self:FinishResolve(false)
    end
end

function GF.ItemInfo:FinishResolve(timedOut)
    local resolver = self.resolver
    self.resolver = nil
    if self.ticker then
        self.ticker:Hide()
    end
    if resolver and type(resolver.callback) == "function" then
        local stats = self:GetStats()
        stats.timedOut = timedOut == true
        local ok, err = pcall(resolver.callback, resolver.token, stats)
        if not ok then
            GF.Util.Print("Item resolution: " .. tostring(err))
            if GF.App then GF.App:OnScanError("item_resolution_failed") end
        end
    end
end

--- Resolve all listings, then call callback(token, stats). Callbacks may fire
--- immediately or after item-info events. A newer call cancels the older callback.
function GF.ItemInfo:ResolveScan(listings, callback)
    self:Initialize()
    local token = GF.Util.NewId("resolve")
    self.resolver = {token = token, callback = callback, attempts = 0}
    self.pendingLinks = self.pendingLinks or {}
    local pending = self:Prime(listings)
    if pending == 0 then
        self:FinishResolve(false)
        return token
    end
    if self.ticker then
        self.ticker.elapsed = 0
        self.ticker:Show()
    end
    return token
end

function GF.ItemInfo:GetStats()
    if not self.cache then
        return {entries = 0, resolved = 0, pending = 0}
    end
    return self.cache:Stats()
end

function GF.ItemInfo:ApplyToListings(listings)
    local resolved = 0
    local unknown = 0
    for index = 1, #listings do
        if self.cache and self.cache:Apply(listings[index]) then
            resolved = resolved + 1
        else
            unknown = unknown + 1
        end
    end
    return resolved, unknown
end

function GF.ItemInfo:GetName(itemId)
    if not itemId then
        return nil
    end
    local info = readItemInfo(itemId)
    return info
end
