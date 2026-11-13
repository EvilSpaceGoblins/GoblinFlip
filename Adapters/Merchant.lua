-- Merchant observer. It records merchant stock, buyback slots and the money
-- delta while the window is open. It never buys or sells anything automatically;
-- the delta is only a hint for manual ledger reconciliation.

local _, GF = ...

GF.Merchant = {
    initialized = false,
    open = false,
    observations = {},
    maxObservations = 40,
    lastSnapshot = nil,
    lastFingerprint = nil,
    moneyBefore = 0,
}

local MAX_ITEMS = 120
local MAX_BUYBACK = 12

local function nowOf()
    return type(time) == "function" and time() or 0
end

local function money()
    local ok, value = pcall(_G.GetMoney)
    if ok and type(value) == "number" and value >= 0 then
        return math.floor(value)
    end
    return 0
end

local function merchantName()
    if type(_G.UnitName) == "function" then
        local ok, name = pcall(_G.UnitName, "npc")
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

local function readItem(index)
    if type(_G.GetMerchantItemInfo) ~= "function" then
        return nil
    end
    local ok, name, texture, price, quantity, numAvailable, isUsable, extendedCost =
        pcall(_G.GetMerchantItemInfo, index)
    if not ok or type(name) ~= "string" then
        return nil
    end
    local link
    if type(_G.GetMerchantItemLink) == "function" then
        local linkOk, value = pcall(_G.GetMerchantItemLink, index)
        if linkOk and type(value) == "string" then
            link = value
        end
    end
    local itemId = link and GF.Domain.ScanNormalizer.GetItemIdFromLink(link) or nil
    return {
        index = index,
        itemId = itemId,
        link = link,
        name = name,
        texture = type(texture) == "string" and texture or nil,
        price = type(price) == "number" and math.max(0, math.floor(price)) or nil,
        quantity = type(quantity) == "number" and quantity or nil,
        numAvailable = type(numAvailable) == "number" and numAvailable or nil,
        isUsable = isUsable == true,
        limited = extendedCost ~= nil,
    }
end

local function readBuyback(index)
    if type(_G.GetBuybackItemInfo) ~= "function" then
        return nil
    end
    local ok, name, texture, price, quantity = pcall(_G.GetBuybackItemInfo, index)
    if not ok or type(name) ~= "string" or name == "" then
        return nil
    end
    local link
    if type(_G.GetBuybackItemLink) == "function" then
        local linkOk, value = pcall(_G.GetBuybackItemLink, index)
        if linkOk and type(value) == "string" then
            link = value
        end
    end
    return {
        index = index,
        itemId = link and GF.Domain.ScanNormalizer.GetItemIdFromLink(link) or nil,
        link = link,
        name = name,
        texture = type(texture) == "string" and texture or nil,
        price = type(price) == "number" and math.max(0, math.floor(price)) or nil,
        quantity = type(quantity) == "number" and quantity or nil,
    }
end

local function fingerprintOf(items, buyback)
    local parts = {}
    for index = 1, #items do
        local item = items[index]
        parts[#parts + 1] = tostring(item.itemId or item.name)
            .. ":" .. tostring(item.price) .. "x" .. tostring(item.numAvailable)
    end
    for index = 1, #buyback do
        local item = buyback[index]
        parts[#parts + 1] = "b" .. tostring(item.itemId or item.name)
            .. ":" .. tostring(item.price) .. "x" .. tostring(item.quantity)
    end
    return table.concat(parts, "|")
end

local function pushObservation(observation)
    local addon = GF.Merchant
    local list = addon.observations
    list[#list + 1] = observation
    while #list > addon.maxObservations do
        table.remove(list, 1)
    end
    addon.lastSnapshot = observation
end

--- Read merchant stock and buyback slots without interacting with them.
function GF.Merchant.Snapshot(reason)
    local addon = GF.Merchant
    local items = {}
    local itemCount = 0
    if type(_G.GetMerchantNumItems) == "function" then
        local ok, count = pcall(_G.GetMerchantNumItems)
        if ok and type(count) == "number" and count > 0 then
            itemCount = math.min(math.floor(count), MAX_ITEMS)
        end
    end
    for index = 1, itemCount do
        local item = readItem(index)
        if item then
            items[#items + 1] = item
        end
    end

    local buyback = {}
    if type(_G.GetNumBuybackItems) == "function" then
        local ok, count = pcall(_G.GetNumBuybackItems)
        if ok and type(count) == "number" and count > 0 then
            for index = 1, math.min(math.floor(count), MAX_BUYBACK) do
                local item = readBuyback(index)
                if item then
                    buyback[#buyback + 1] = item
                end
            end
        end
    end

    local fingerprint = fingerprintOf(items, buyback)
    local currentMoney = money()
    local snapshot = {
        at = nowOf(),
        reason = reason or "update",
        merchant = merchantName(),
        items = items,
        itemCount = #items,
        buyback = buyback,
        money = currentMoney,
        moneyBefore = addon.moneyBefore,
        moneyDelta = addon.moneyBefore > 0 and (currentMoney - addon.moneyBefore) or 0,
        fingerprint = fingerprint,
        automatic = false,
    }

    if fingerprint ~= addon.lastFingerprint or reason == "open" or reason == "closed" then
        addon.lastFingerprint = fingerprint
        pushObservation(snapshot)
    else
        addon.lastSnapshot = snapshot
    end
    return snapshot
end

function GF.Merchant.GetLastSnapshot()
    return GF.Merchant.lastSnapshot
end

function GF.Merchant.GetObservations()
    return GF.Merchant.observations
end

function GF.Merchant.IsOpen()
    return GF.Merchant.open
end

--- Record a vendor sale event.
---@param itemId number
---@param quantity number
---@param price number
function GF.Merchant.RecordVendorSale(itemId, quantity, price)
    if not itemId or not quantity or not price then return end

    local observation = {
        at = nowOf(),
        type = "vendor_sale",
        itemId = itemId,
        quantity = quantity,
        price = price,
        total = price * quantity,
    }

    -- Add to observations
    local list = GF.Merchant.observations
    list[#list + 1] = observation
    while #list > GF.Merchant.maxObservations do
        table.remove(list, 1)
    end
    GF.Merchant.lastSnapshot = observation

    -- TODO: Link to ledger if this was a GoblinFlip purchase
    -- GF.Domain.Ledger:RecordVendorSale(itemId, quantity, price)

    if GF.Debug and GF.Debug.Log then
        GF.Debug:Log("Vendor sale recorded:", itemId, quantity, price)
    end
end

function GF.Merchant.IsOpen()
    return GF.Merchant.open
end

function GF.Merchant.Clear()
    GF.Merchant.observations = {}
    GF.Merchant.lastSnapshot = nil
    GF.Merchant.lastFingerprint = nil
end

function GF.Merchant.Initialize()
    if GF.Merchant.initialized then
        return
    end
    GF.Merchant.initialized = true

    local frame = CreateFrame("Frame")
    GF.Merchant.frame = frame
    local events = {"MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "MERCHANT_CONFIRM_TRADE"}
    for index = 1, #events do
        pcall(frame.RegisterEvent, frame, events[index])
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "MERCHANT_SHOW" then
            GF.Merchant.open = true
            GF.Merchant.moneyBefore = money()
            GF.Merchant.Snapshot("open")
        elseif event == "MERCHANT_UPDATE" then
            if GF.Merchant.open then
                GF.Merchant.Snapshot("update")
            end
        elseif event == "MERCHANT_CONFIRM_TRADE" then
            -- Item sold to vendor
            GF.Merchant.RecordVendorSale(...)
        else
            if GF.Merchant.open then
                GF.Merchant.Snapshot("closed")
            end
            GF.Merchant.open = false
        end
    end)
end
