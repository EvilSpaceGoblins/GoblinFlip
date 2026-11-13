-- Mailbox observer. It records what the inbox shows and never takes, returns or
-- deletes mail. Reconciliation with the ledger is always a manual user action.

local _, GF = ...

GF.Mailbox = {
    initialized = false,
    open = false,
    observations = {},
    maxObservations = 40,
    lastFingerprint = nil,
    lastSnapshot = nil,
    listener = nil,
}

local MAX_ATTACHMENTS = 16
local MAX_ITEM_CACHE = 4

local function nowOf()
    return type(time) == "function" and time() or 0
end

local function inboxCount()
    if type(_G.GetInboxNumItems) ~= "function" then
        return 0
    end
    local ok, count = pcall(_G.GetInboxNumItems)
    if ok and type(count) == "number" and count > 0 then
        return math.floor(count)
    end
    return 0
end

local function readHeader(index)
    if type(_G.GetInboxHeaderInfo) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(_G.GetInboxHeaderInfo, index)
    if not ok then
        return nil
    end
    -- packageIcon, stationeryIcon, sender, subject, money, cod, daysLeft,
    -- hasItem, canReply, isGM, itemQuantity
    return {
        sender = type(c) == "string" and c or nil,
        subject = type(d) == "string" and d or nil,
        money = type(e) == "number" and math.max(0, math.floor(e)) or 0,
        cod = type(f) == "number" and math.max(0, math.floor(f)) or 0,
        daysLeft = type(g) == "number" and g or nil,
        hasItem = h == true,
        itemQuantity = type(k) == "number" and k or nil,
    }
end

local function readAttachment(index, attachmentIndex)
    local link
    if type(_G.GetInboxItemLink) == "function" then
        local ok, value = pcall(_G.GetInboxItemLink, index, attachmentIndex)
        if ok and type(value) == "string" then
            link = value
        end
    end

    local name, quantity
    if type(_G.GetInboxItem) == "function" then
        local ok, a, b, c = pcall(_G.GetInboxItem, index, attachmentIndex)
        if ok then
            if type(a) == "string" then
                name = a
            end
            if type(c) == "number" then
                quantity = c
            elseif type(b) == "number" then
                quantity = b
            end
        end
    end

    if not link and not name then
        return nil
    end
    local itemId = link and GF.Domain.ScanNormalizer.GetItemIdFromLink(link) or nil
    return {
        index = attachmentIndex,
        link = link,
        name = name,
        itemId = itemId,
        quantity = quantity,
    }
end

local function fingerprintOf(items)
    local parts = {}
    for index = 1, #items do
        local item = items[index]
        parts[#parts + 1] = tostring(item.itemId or item.name or "?")
            .. "x" .. tostring(item.quantity or 1)
    end
    return table.concat(parts, "|")
end

local function pushObservation(observation)
    local addon = GF.Mailbox
    local list = addon.observations
    list[#list + 1] = observation
    while #list > addon.maxObservations do
        table.remove(list, 1)
    end
    addon.lastSnapshot = observation
    if type(addon.listener) == "function" then
        pcall(addon.listener, observation)
    end
end

--- Read the current inbox without touching any mail.
function GF.Mailbox.Scan()
    local addon = GF.Mailbox
    local count = inboxCount()
    local items = {}
    local totalMoney = 0
    local totalCod = 0
    local totalQuantity = 0
    local unnamedAttachments = 0

    for index = 1, count do
        local header = readHeader(index)
        if header then
            totalMoney = totalMoney + header.money
            totalCod = totalCod + header.cod
            if header.hasItem then
                local attachments = 0
                for attachmentIndex = 1, MAX_ATTACHMENTS do
                    local item = readAttachment(index, attachmentIndex)
                    if item then
                        items[#items + 1] = item
                        totalQuantity = totalQuantity + (item.quantity or 1)
                        attachments = attachments + 1
                        if attachments >= MAX_ITEM_CACHE then
                            break
                        end
                    end
                end
                if attachments == 0 then
                    unnamedAttachments = unnamedAttachments + 1
                end
            end
        end
    end

    local observation = {
        at = nowOf(),
        count = count,
        items = items,
        itemCount = #items,
        totalQuantity = totalQuantity,
        money = totalMoney,
        cod = totalCod,
        unnamedAttachments = unnamedAttachments,
        fingerprint = fingerprintOf(items) .. "#" .. tostring(count) .. "#" .. tostring(totalMoney),
        automatic = false,
    }

    if observation.fingerprint ~= addon.lastFingerprint then
        addon.lastFingerprint = observation.fingerprint
        pushObservation(observation)
    else
        addon.lastSnapshot = observation
    end
    return observation
end

function GF.Mailbox.GetLastSnapshot()
    return GF.Mailbox.lastSnapshot
end

function GF.Mailbox.GetObservations()
    return GF.Mailbox.observations
end

function GF.Mailbox.GetLastObservation()
    local list = GF.Mailbox.observations
    return list[#list]
end

function GF.Mailbox.IsOpen()
    return GF.Mailbox.open
end

function GF.Mailbox.SetListener(listener)
    GF.Mailbox.listener = type(listener) == "function" and listener or nil
end

function GF.Mailbox.Clear()
    GF.Mailbox.observations = {}
    GF.Mailbox.lastFingerprint = nil
    GF.Mailbox.lastSnapshot = nil
end

function GF.Mailbox.Initialize()
    if GF.Mailbox.initialized then
        return
    end
    GF.Mailbox.initialized = true

    local frame = CreateFrame("Frame")
    GF.Mailbox.frame = frame
    local events = {"MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED"}
    for index = 1, #events do
        pcall(frame.RegisterEvent, frame, events[index])
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "MAIL_CLOSED" then
            GF.Mailbox.open = false
            return
        end
        GF.Mailbox.open = true
        GF.Mailbox.Scan()
    end)
end
