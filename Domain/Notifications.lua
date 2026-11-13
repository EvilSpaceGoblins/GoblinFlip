-- Sound alerts are opt-in, rate limited and deduplicated per completed scan.

local _, GF = ...

GF.Domain = GF.Domain or {}
local Notifications = {}
GF.Domain.Notifications = Notifications
Notifications.__index = Notifications

local DEFAULT_RATE_LIMIT = 30
local DEFAULT_MAX_SIGNATURES = 500

local function signatureFor(opportunity)
    local auctionPart = opportunity.auctionId and tostring(opportunity.auctionId) or "no-auction-id"
    return table.concat({
        tostring(opportunity.strategy or "?"),
        tostring(opportunity.itemId or "?"),
        tostring(opportunity.variantKey or "?"),
        tostring(opportunity.quantity or "?"),
        tostring(opportunity.buyoutTotal or "?"),
        auctionPart,
    }, "|")
end

function Notifications.New(environment, options)
    options = options or {}
    local self = setmetatable({
        env = environment or {},
        lastScanId = {},
        signatures = {},
        hasBaseline = {},
        lastAlertAt = options.lastAlertAt or 0,
        rateLimit = options.rateLimit or DEFAULT_RATE_LIMIT,
        maxSignatures = options.maxSignatures or DEFAULT_MAX_SIGNATURES,
    }, Notifications)
    return self
end

function Notifications:GetNow()
    if type(self.env.now) == "function" then
        local ok, value = pcall(self.env.now)
        if ok and type(value) == "number" then
            return value
        end
    end
    return type(time) == "function" and time() or 0
end

local function thresholdsMatch(opportunity, settings)
    local minProfit = settings.alertMinProfit or 0
    local minRoi = settings.alertMinRoi or 0
    return (opportunity.profit or 0) >= minProfit
        and (opportunity.roi or 0) + 1e-9 >= minRoi
end

function Notifications:TrimSignatures(marketKey)
    local set = self.signatures[marketKey]
    if not set then
        return
    end
    local count = 0
    for _ in pairs(set) do
        count = count + 1
    end
    if count <= self.maxSignatures then
        return
    end
    -- Bounded state: keep the most recent scan only rather than growing forever.
    self.signatures[marketKey] = {}
end

function Notifications:OnScanCompleted(marketKey, opportunities, settings, scanId)
    settings = settings or {}
    scanId = scanId or "unknown"
    local now = self:GetNow()

    if self.lastScanId[marketKey] == scanId then
        return nil, "duplicate_scan"
    end
    self.lastScanId[marketKey] = scanId

    local previous = self.signatures[marketKey] or {}
    local current = {}
    local fresh = {}
    for index = 1, #(opportunities or {}) do
        local opportunity = opportunities[index]
        local signature = signatureFor(opportunity)
        current[signature] = true
        if not previous[signature] and thresholdsMatch(opportunity, settings) then
            fresh[#fresh + 1] = opportunity
        end
    end
    self.signatures[marketKey] = current
    self:TrimSignatures(marketKey)

    if not self.hasBaseline[marketKey] then
        self.hasBaseline[marketKey] = true
        return nil, "baseline"
    end

    if #fresh == 0 then
        return nil, "no_new_opportunities"
    end

    local best = fresh[1]
    for index = 2, #fresh do
        if (fresh[index].profit or 0) > (best.profit or 0) then
            best = fresh[index]
        end
    end

    if settings.soundAlerts ~= true then
        return {
            newCount = #fresh,
            best = best,
            soundPlayed = false,
            reason = "disabled",
        }
    end

    if now - self.lastAlertAt < self.rateLimit then
        return {
            newCount = #fresh,
            best = best,
            soundPlayed = false,
            reason = "rate_limited",
        }
    end

    self.lastAlertAt = now
    if type(self.env.playSound) == "function" then
        pcall(self.env.playSound, #fresh, best)
    end
    return {
        newCount = #fresh,
        best = best,
        soundPlayed = true,
        reason = "played",
    }
end

function Notifications:Serialize()
    local signatures = {}
    for marketKey, set in pairs(self.signatures) do
        local list = {}
        local count = 0
        for signature in pairs(set) do
            if count < self.maxSignatures then
                list[#list + 1] = signature
                count = count + 1
            end
        end
        signatures[marketKey] = list
    end
    return {
        lastAlertAt = self.lastAlertAt,
        signatures = signatures,
        lastScanId = self.lastScanId,
        hasBaseline = self.hasBaseline,
    }
end

function Notifications:Load(data)
    if type(data) ~= "table" then
        return
    end
    self.lastAlertAt = tonumber(data.lastAlertAt) or 0
    self.lastScanId = type(data.lastScanId) == "table" and data.lastScanId or {}
    self.hasBaseline = type(data.hasBaseline) == "table" and data.hasBaseline or {}
    self.signatures = {}
    if type(data.signatures) == "table" then
        for marketKey, list in pairs(data.signatures) do
            local set = {}
            if type(list) == "table" then
                for index = 1, #list do
                    set[list[index]] = true
                end
            end
            self.signatures[marketKey] = set
        end
    end
end
