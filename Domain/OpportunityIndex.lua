-- In-memory snapshot history, market-scoped and bounded. Only opportunity
-- summaries are retained; raw scan payloads are never persisted.

local _, GF = ...

GF.Domain = GF.Domain or {}
local OpportunityIndex = {}
GF.Domain.OpportunityIndex = OpportunityIndex
OpportunityIndex.__index = OpportunityIndex

local DEFAULT_MAX_SNAPSHOTS = 10
local DEFAULT_RETENTION_SECONDS = 7 * 86400

function OpportunityIndex.New(options)
    options = options or {}
    local self = setmetatable({
        snapshots = {},
        latest = {},
        cooldowns = {},
        maxSnapshotsPerMarket = options.maxSnapshotsPerMarket or DEFAULT_MAX_SNAPSHOTS,
        retentionSeconds = options.retentionSeconds or DEFAULT_RETENTION_SECONDS,
        now = options.now or function()
            return type(time) == "function" and time() or 0
        end,
    }, OpportunityIndex)
    return self
end

local function signatureFor(opportunity)
    local idPart = opportunity.auctionId and tostring(opportunity.auctionId) or "no-auction-id"
    return table.concat({
        tostring(opportunity.strategy or "?"),
        tostring(opportunity.itemId or "?"),
        tostring(opportunity.variantKey or "?"),
        tostring(opportunity.quantity or "?"),
        tostring(opportunity.buyoutTotal or "?"),
        idPart,
    }, "|")
end

local function buildSignatureSet(opportunities)
    local set = {}
    local count = 0
    for index = 1, #opportunities do
        local signature = signatureFor(opportunities[index])
        if not set[signature] then
            set[signature] = true
            count = count + 1
        end
    end
    return set, count
end

function OpportunityIndex:Publish(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.marketKey) ~= "string" or snapshot.marketKey == "" then
        return nil, "invalid_snapshot"
    end
    if type(snapshot.observedAt) ~= "number" or snapshot.observedAt <= 0 then
        return nil, "invalid_timestamp"
    end

    snapshot.id = snapshot.id or GF.Util.NewId("scan")
    snapshot.opportunities = snapshot.opportunities or {}
    snapshot.disenchant = snapshot.disenchant or {}
    snapshot.metrics = snapshot.metrics or {}
    snapshot.vendorSignatures, snapshot.vendorSignatureCount = buildSignatureSet(snapshot.opportunities)
    snapshot.disenchantSignatures, snapshot.disenchantSignatureCount = buildSignatureSet(snapshot.disenchant)
    snapshot.partial = snapshot.partial == true

    local marketSnapshots = self.snapshots[snapshot.marketKey]
    if not marketSnapshots then
        marketSnapshots = {}
        self.snapshots[snapshot.marketKey] = marketSnapshots
    end
    marketSnapshots[#marketSnapshots + 1] = snapshot
    self.latest[snapshot.marketKey] = snapshot
    self:Prune(snapshot.observedAt)
    return snapshot
end

function OpportunityIndex:Prune(now)
    now = now or self.now()
    for marketKey, snapshots in pairs(self.snapshots) do
        local kept = {}
        for index = 1, #snapshots do
            local snapshot = snapshots[index]
            local age = now - (snapshot.observedAt or 0)
            if age <= self.retentionSeconds then
                kept[#kept + 1] = snapshot
            end
        end
        while #kept > self.maxSnapshotsPerMarket do
            table.remove(kept, 1)
        end
        if #kept == 0 then
            -- Never evict the latest good snapshot just because the clock moved.
            local latest = self.latest[marketKey]
            if latest then
                kept[1] = latest
            end
        end
        self.snapshots[marketKey] = kept
        if #kept > 0 then
            self.latest[marketKey] = kept[#kept]
        end
    end
end

function OpportunityIndex:Latest(marketKey)
    return self.latest[marketKey]
end

function OpportunityIndex:Previous(marketKey)
    local snapshots = self.snapshots[marketKey]
    if not snapshots or #snapshots < 2 then
        return nil
    end
    return snapshots[#snapshots - 1]
end

function OpportunityIndex:History(marketKey)
    local result = {}
    local snapshots = self.snapshots[marketKey] or {}
    for index = #snapshots, 1, -1 do
        result[#result + 1] = snapshots[index]
    end
    return result
end

function OpportunityIndex:GetSnapshot(marketKey, snapshotId)
    local snapshots = self.snapshots[marketKey] or {}
    for index = 1, #snapshots do
        if snapshots[index].id == snapshotId then
            return snapshots[index]
        end
    end
    return nil
end

function OpportunityIndex:AllMarkets()
    local result = {}
    for marketKey, snapshot in pairs(self.latest) do
        result[#result + 1] = {
            key = marketKey,
            snapshot = snapshot,
            observedAt = snapshot.observedAt,
        }
    end
    table.sort(result, function(left, right)
        return (left.observedAt or 0) > (right.observedAt or 0)
    end)
    return result
end

--- New opportunities compared with the previous snapshot in this market.
--- The signature is deliberately conservative when no auction ID is available.
function OpportunityIndex:DiffSignatures(marketKey, opportunities, strategy)
    local previous = self:Previous(marketKey)
    if not previous then
        return {}
    end
    local previousSet = previous.vendorSignatures or {}
    if strategy == GF.STRATEGY_DISENCHANT then
        previousSet = previous.disenchantSignatures or {}
    end
    local fresh = {}
    for index = 1, #opportunities do
        local signature = signatureFor(opportunities[index])
        if not previousSet[signature] then
            fresh[#fresh + 1] = opportunities[index]
        end
    end
    return fresh
end

function OpportunityIndex:SetCooldown(marketKey, readyAt)
    if marketKey then
        self.cooldowns[marketKey] = readyAt
    end
end

function OpportunityIndex:GetCooldown(marketKey, now)
    local readyAt = self.cooldowns[marketKey]
    if not readyAt then
        return 0
    end
    now = now or self.now()
    return math.max(0, readyAt - now)
end

--- Serialize compact snapshots for SavedVariables. Raw listings and sets are
--- intentionally omitted.
function OpportunityIndex:Serialize(maxPerMarket)
    local maximum = maxPerMarket or self.maxSnapshotsPerMarket
    local output = {}
    for marketKey, snapshots in pairs(self.snapshots) do
        local list = {}
        local startIndex = math.max(1, #snapshots - maximum + 1)
        for index = startIndex, #snapshots do
            local snapshot = snapshots[index]
            local vendor = {}
            for opportunityIndex = 1, #snapshot.opportunities do
                vendor[#vendor + 1] = GF.Domain.ProfitEngine.Compact(snapshot.opportunities[opportunityIndex])
            end
            local disenchant = {}
            for opportunityIndex = 1, #snapshot.disenchant do
                disenchant[#disenchant + 1] = GF.Domain.ProfitEngine.Compact(snapshot.disenchant[opportunityIndex])
            end
            list[#list + 1] = {
                id = snapshot.id,
                marketKey = snapshot.marketKey,
                market = snapshot.market,
                observedAt = snapshot.observedAt,
                source = snapshot.source,
                partial = snapshot.partial,
                counts = snapshot.counts,
                metrics = snapshot.metrics,
                opportunities = vendor,
                disenchant = disenchant,
                scanState = snapshot.scanState,
                duration = snapshot.duration,
            }
        end
        output[marketKey] = list
    end
    return output
end

function OpportunityIndex:LoadSerialized(data)
    if type(data) ~= "table" then
        return 0
    end
    local loaded = 0
    for marketKey, snapshots in pairs(data) do
        if type(snapshots) == "table" then
            local list = {}
            for index = 1, #snapshots do
                local snapshot = snapshots[index]
                if type(snapshot) == "table" and snapshot.observedAt then
                    snapshot.marketKey = snapshot.marketKey or marketKey
                    snapshot.opportunities = snapshot.opportunities or {}
                    snapshot.disenchant = snapshot.disenchant or {}
                    snapshot.metrics = snapshot.metrics or {}
                    snapshot.vendorSignatures, snapshot.vendorSignatureCount =
                        buildSignatureSet(snapshot.opportunities)
                    snapshot.disenchantSignatures, snapshot.disenchantSignatureCount =
                        buildSignatureSet(snapshot.disenchant)
                    list[#list + 1] = snapshot
                    loaded = loaded + 1
                end
            end
            table.sort(list, function(left, right)
                return (left.observedAt or 0) < (right.observedAt or 0)
            end)
            self.snapshots[marketKey] = list
            if #list > 0 then
                self.latest[marketKey] = list[#list]
            end
        end
    end
    self:Prune(self.now())
    return loaded
end

function OpportunityIndex:Reset()
    self.snapshots = {}
    self.latest = {}
    self.cooldowns = {}
end