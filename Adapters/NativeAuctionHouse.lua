-- Optional native replicate scan adapter. This path is experimental and
-- disabled by default; it is only used when explicitly selected in Settings.

local _, GF = ...

GF.NativeScan = {
    initialized = false,
    eventRegistered = false,
    collecting = false,
    index = 0,
    payload = {},
    startedAt = 0,
    lastCompletedAt = 0,
}

local function ah()
    return _G.C_AuctionHouse
end

function GF.NativeScan.GetStatus()
    local api = ah()
    return {
        available = GF.NativeScan.IsAvailable(),
        eventRegistered = GF.NativeScan.eventRegistered,
        collecting = GF.NativeScan.collecting,
        lastCompletedAt = GF.NativeScan.lastCompletedAt,
    }
end

function GF.NativeScan.IsAvailable()
    local api = ah()
    return type(api) == "table"
        and type(api.ReplicateItems) == "function"
        and type(api.GetNumReplicateItems) == "function"
        and type(api.GetReplicateItemInfo) == "function"
        and type(api.GetReplicateItemLink) == "function"
end

function GF.NativeScan:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    local frame = CreateFrame("Frame")
    self.frame = frame
    local ok = pcall(frame.RegisterEvent, frame, "REPLICATE_ITEM_LIST_UPDATE")
    self.eventRegistered = ok
    frame:SetScript("OnEvent", function()
        GF.NativeScan:BeginCollection()
    end)

    local driver = CreateFrame("Frame")
    self.driver = driver
    driver:Hide()
    driver:SetScript("OnUpdate", function()
        GF.NativeScan:Step()
    end)
end

function GF.NativeScan:RequestScan()
    self:Initialize()
    local api = ah()
    if not self:IsAvailable() then
        return false, "native_scan_unavailable"
    end
    if not self.eventRegistered then
        return false, "replicate_event_unavailable"
    end
    if self.collecting then
        return false, "already_collecting"
    end
    local ok, reason = pcall(api.ReplicateItems)
    if not ok then
        return false, tostring(reason)
    end
    self.requestedAt = type(time) == "function" and time() or 0
    return true, nil
end

function GF.NativeScan:BeginCollection()
    local api = ah()
    if type(api) ~= "table" or type(api.GetNumReplicateItems) ~= "function" then
        return
    end
    local ok, count = pcall(api.GetNumReplicateItems)
    if not ok or type(count) ~= "number" or count <= 0 then
        if GF.App then
            GF.App:OnScanError("native_empty_payload")
        end
        return
    end
    self.collecting = true
    self.index = 0
    self.payload = {}
    self.count = count
    self.startedAt = type(time) == "function" and time() or 0
    if self.driver then
        self.driver:Show()
    end
end

function GF.NativeScan:Step()
    if not self.collecting then
        return
    end
    local api = ah()
    local started = type(debugprofilestop) == "function" and debugprofilestop() or 0
    local processed = 0
    while self.index < self.count do
        self.index = self.index + 1
        local infoOk, replicateInfo = pcall(api.GetReplicateItemInfo, self.index)
        if infoOk and type(replicateInfo) == "table" then
            local linkOk, itemLink = pcall(api.GetReplicateItemLink, self.index)
            local timeLeft = nil
            if type(api.GetReplicateItemTimeLeft) == "function" then
                local leftOk, value = pcall(api.GetReplicateItemTimeLeft, self.index)
                if leftOk then
                    timeLeft = value
                end
            end
            self.payload[#self.payload + 1] = {
                replicateInfo = replicateInfo,
                itemLink = linkOk and itemLink or nil,
                timeLeft = timeLeft,
            }
        end
        processed = processed + 1
        if processed >= 200 then
            local now = type(debugprofilestop) == "function" and debugprofilestop() or 0
            if now - started >= 4 then
                return
            end
            processed = 0
        end
    end

    self.collecting = false
    if self.driver then
        self.driver:Hide()
    end
    self.lastCompletedAt = type(time) == "function" and time() or 0
    if GF.App and type(GF.App.OnScanPayload) == "function" then
        GF.App:OnScanPayload(self.payload, "native", self.lastCompletedAt)
    end
    self.payload = {}
end

function GF.NativeScan:Cancel()
    self.collecting = false
    self.index = 0
    self.payload = {}
    if self.driver then
        self.driver:Hide()
    end
end
