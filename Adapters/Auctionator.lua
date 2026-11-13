-- Auctionator full-scan adapter. Auctionator's event bus is an internal,
-- undocumented contract; it is probed defensively and never mutated.

local _, GF = ...

GF.AuctionatorAdapter = {
    initialized = false,
    registered = false,
    lastPayloadAt = 0,
    lastRequestAt = 0,
    lastPayloadCount = 0,
    lastError = nil,
}

local function auctionator()
    return _G.Auctionator
end

function GF.AuctionatorAdapter.GetStatus()
    local addon = auctionator()
    local eventName
    if type(addon) == "table" and type(addon.FullScan) == "table"
        and type(addon.FullScan.Events) == "table" then
        eventName = addon.FullScan.Events.ScanComplete
    end
    return {
        installed = type(addon) == "table",
        version = GF.Compat.GetAuctionatorVersion(),
        eventBus = type(addon) == "table" and type(addon.EventBus) == "table",
        event = eventName,
        registered = GF.AuctionatorAdapter.registered,
        lastPayloadAt = GF.AuctionatorAdapter.lastPayloadAt,
        lastPayloadCount = GF.AuctionatorAdapter.lastPayloadCount,
        lastError = GF.AuctionatorAdapter.lastError,
    }
end

function GF.AuctionatorAdapter.IsAvailable()
    local addon = auctionator()
    return type(addon) == "table"
        and type(addon.EventBus) == "table"
        and type(addon.EventBus.Register) == "function"
        and type(addon.FullScan) == "table"
        and type(addon.FullScan.Events) == "table"
        and type(addon.FullScan.Events.ScanComplete) == "string"
end

local function payloadSignature(payload)
    local count = type(payload) == "table" and #payload or 0
    local first = payload and payload[1]
    local last = payload and payload[count]
    local firstId = first and (first.itemLink or (first.replicateInfo and first.replicateInfo[17]))
    local lastId = last and (last.itemLink or (last.replicateInfo and last.replicateInfo[17]))
    return tostring(count) .. "|" .. tostring(firstId) .. "|" .. tostring(lastId)
end

function GF.AuctionatorAdapter:HandlePayload(payload)
    if GF.AuctionatorAdapter.adapterRefreshing then
        return
    end
    if type(payload) ~= "table" or #payload == 0 then
        self.lastError = "empty_payload"
        return
    end
    local first = payload[1]
    if type(first) ~= "table" or type(first.replicateInfo) ~= "table" then
        -- Auctionator's incremental/summary scan has no per-listing data. It is not
        -- a substitute for a full scan and must not be shown as buyable lots.
        self.lastError = "not_a_replicate_payload"
        GF.Debug:Log("Auctionator scan ignored: incremental/summary payload")
        return
    end

    local now = type(time) == "function" and time() or 0
    local signature = payloadSignature(payload)
    if signature == self.lastSignature and now - self.lastPayloadAt <= 5 then
        GF.Debug:Log("Duplicate Auctionator scan completion ignored")
        return
    end
    self.lastSignature = signature
    self.lastPayloadAt = now
    self.lastPayloadCount = #payload
    self.lastError = nil

    if GF.App and type(GF.App.OnScanPayload) == "function" then
        GF.App:OnScanPayload(payload, "auctionator", now)
    end
end

function GF.AuctionatorAdapter:Register()
    if self.registered then
        return true
    end
    if not self:IsAvailable() then
        self.lastError = "auctionator_contract_missing"
        return false
    end

    local addon = auctionator()
    local eventName = addon.FullScan.Events.ScanComplete
    local listener = {}
    function listener.ReceiveEvent(_, event, payload)
        if event == eventName then
            GF.AuctionatorAdapter:HandlePayload(payload)
        end
    end

    local ok, reason = pcall(addon.EventBus.Register, addon.EventBus, listener, {eventName})
    if not ok then
        self.lastError = tostring(reason)
        return false
    end
    self.listener = listener
    self.eventName = eventName
    self.registered = true
    return true
end

function GF.AuctionatorAdapter:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    self:Register()
end

--- Auctionator does not expose a documented full-scan trigger. The Scan button
--- guides the player to Auctionator's own Get All action instead of guessing.
function GF.AuctionatorAdapter:RequestScan()
    self.lastRequestAt = type(time) == "function" and time() or 0
    if not self:IsAvailable() then
        return false, "auctionator_unavailable"
    end
    if not self.registered then
        self:Register()
    end
    return false, "manual_scan_required"
end

function GF.AuctionatorAdapter:GetCooldownHint(seconds)
    local reference = self.lastPayloadAt
    if self.lastRequestAt > reference then
        reference = self.lastRequestAt
    end
    if reference <= 0 then
        return 0
    end
    local now = type(time) == "function" and time() or 0
    return math.max(0, reference + (seconds or 900) - now)
end

function GF.AuctionatorAdapter:Reset()
    self.lastSignature = nil
    self.lastPayloadAt = 0
    self.lastRequestAt = 0
    self.lastPayloadCount = 0
    self.lastError = nil
end
