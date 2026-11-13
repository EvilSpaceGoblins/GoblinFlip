-- Converts scan-provider payloads into the normalized per-listing contract.
-- This module never talks to the WoW API; callers inject item-key creation.

local _, GF = ...

GF.Domain = GF.Domain or {}
local Normalizer = {}
GF.Domain.ScanNormalizer = Normalizer

-- Field indices in the array returned by C_AuctionHouse.GetReplicateItemInfo().
-- These are the values used by the verified Forever Auctionator replicate payload.
Normalizer.REPLICATE_FIELDS = {
    QUANTITY = 3,
    BUYOUT = 10,
    ITEM_ID = 17,
}

local MAX_REJECT_SAMPLES = 5

local function splitLinkFields(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end
    local fields = {}
    local startIndex = 1
    while true do
        local separator = itemLink:find(":", startIndex, true)
        if not separator then
            fields[#fields + 1] = itemLink:sub(startIndex)
            break
        end
        fields[#fields + 1] = itemLink:sub(startIndex, separator - 1)
        startIndex = separator + 1
    end
    return fields
end

--- Suffix ID is the 6th field after the item ID (8th colon-delimited field
--- including the "|c...|Hitem" prefix).
function Normalizer.GetSuffixFromLink(itemLink)
    local fields = splitLinkFields(itemLink)
    if not fields then
        return 0
    end
    local suffix = tonumber(fields[8])
    if suffix and suffix >= 0 then
        return math.floor(suffix)
    end
    return 0
end

function Normalizer.GetItemIdFromLink(itemLink)
    local fields = splitLinkFields(itemLink)
    if not fields then
        return nil
    end
    local itemId = tonumber(fields[2])
    if itemId and itemId > 0 then
        return math.floor(itemId)
    end
    return nil
end

function Normalizer.MakeVariantKey(itemId, itemLevel, itemSuffix, battlePetSpeciesID)
    return string.format("%d:%d:%d:%d",
        tonumber(itemId) or 0,
        tonumber(itemLevel) or 0,
        tonumber(itemSuffix) or 0,
        tonumber(battlePetSpeciesID) or 0)
end

local function addReject(state, reason, sample)
    state.rejectCounts[reason] = (state.rejectCounts[reason] or 0) + 1
    if #state.rejectSamples < MAX_REJECT_SAMPLES then
        state.rejectSamples[#state.rejectSamples + 1] = {
            reason = reason,
            sample = sample,
        }
    end
end

local function isValidPositiveInteger(value, maximum)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return false
    end
    if value % 1 ~= 0 or value <= 0 then
        return false
    end
    return value <= (maximum or GF.MAX_COPPER)
end

local function buildListing(entry, context, state, fields)
    local replicateInfo = entry.replicateInfo
    local itemId, quantity, totalBuyout, itemLink

    if type(replicateInfo) == "table" then
        itemId = replicateInfo[fields.ITEM_ID]
        quantity = replicateInfo[fields.QUANTITY]
        totalBuyout = replicateInfo[fields.BUYOUT]
        itemLink = entry.itemLink
    else
        -- Already-normalized input, primarily useful for tests and fixtures.
        itemId = entry.itemId
        quantity = entry.quantity or entry.totalQuantity
        totalBuyout = entry.buyoutTotal or entry.buyout
        itemLink = entry.itemLink
    end

    if not itemId then
        itemId = Normalizer.GetItemIdFromLink(itemLink)
    end
    if not isValidPositiveInteger(itemId, 2147483647) then
        addReject(state, "missing_item", itemId)
        return nil
    end
    itemId = math.floor(itemId)

    if not isValidPositiveInteger(quantity, 100000000) then
        addReject(state, "invalid_quantity", quantity)
        return nil
    end
    quantity = math.floor(quantity)

    if totalBuyout == nil or totalBuyout == 0 then
        addReject(state, "bid_only", totalBuyout)
        return nil
    end
    if not isValidPositiveInteger(totalBuyout, GF.MAX_COPPER) then
        addReject(state, "invalid_buyout", totalBuyout)
        return nil
    end
    totalBuyout = math.floor(totalBuyout)

    local itemLevel = tonumber(entry.itemLevel) or 0
    local battlePetSpeciesID = tonumber(entry.battlePetSpeciesID) or 0
    local itemSuffix = tonumber(entry.itemSuffix)
    if not itemSuffix then
        itemSuffix = Normalizer.GetSuffixFromLink(itemLink)
    end
    itemLevel = math.floor(itemLevel)
    itemSuffix = math.floor(itemSuffix)
    battlePetSpeciesID = math.floor(battlePetSpeciesID)

    local listing = {
        scanId = context.scanId,
        marketKey = context.marketKey,
        observedAt = context.observedAt,
        itemId = itemId,
        itemLink = itemLink,
        itemKey = nil,
        variantKey = Normalizer.MakeVariantKey(itemId, itemLevel, itemSuffix, battlePetSpeciesID),
        itemLevel = itemLevel,
        itemSuffix = itemSuffix,
        battlePetSpeciesID = battlePetSpeciesID,
        auctionId = entry.auctionID or entry.auctionId,
        quantity = quantity,
        buyoutTotal = totalBuyout,
        buyoutUnit = totalBuyout / quantity,
        priceMode = "stack",
        ownAuction = entry.containsOwnerItem == true and true or (entry.ownAuction == true and true or nil),
        source = context.source,
        rowIndex = state.cursor,
    }

    if type(context.makeItemKey) == "function" then
        local ok, itemKey = pcall(context.makeItemKey, listing)
        if ok then
            listing.itemKey = itemKey
        end
    end

    return listing
end

function Normalizer.NewBatch(payload, context)
    local state = {
        payload = payload,
        context = context,
        cursor = 0,
        listings = {},
        rejectCounts = {},
        rejectSamples = {},
        done = false,
    }

    local fields = (context and context.fields) or Normalizer.REPLICATE_FIELDS
    local total = type(payload) == "table" and #payload or 0

    local batch = state

    function batch:Step(maxRows)
        if self.done then
            return true
        end
        maxRows = maxRows or 250
        local stop = math.min(self.cursor + maxRows, total)
        for index = self.cursor + 1, stop do
            self.cursor = index
            local entry = self.payload[index]
            if type(entry) == "table" then
                local listing = buildListing(entry, self.context, self, fields)
                if listing then
                    self.listings[#self.listings + 1] = listing
                end
            else
                addReject(self, "invalid_entry", entry)
            end
        end
        if self.cursor >= total then
            self.done = true
        end
        return self.done
    end

    function batch:IsDone()
        return self.done
    end

    function batch:GetListings()
        return self.listings
    end

    function batch:GetProgress()
        if total == 0 then
            return 1
        end
        return self.cursor / total
    end

    function batch:GetResult()
        return {
            scanId = self.context.scanId,
            marketKey = self.context.marketKey,
            observedAt = self.context.observedAt,
            source = self.context.source,
            listings = self.listings,
            accepted = #self.listings,
            total = total,
            rejected = self.rejectCounts,
            rejectSamples = self.rejectSamples,
            complete = self.done and self.cursor >= total,
        }
    end

    return batch
end

function Normalizer.Normalize(payload, context)
    local batch = Normalizer.NewBatch(payload, context)
    while not batch:Step(1000) do
        -- Keep the helper synchronous; production callers use the chunked batch.
    end
    return batch:GetResult()
end
