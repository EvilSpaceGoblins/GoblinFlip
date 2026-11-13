-- Transaction ledger: confirmed cost, received inventory, disposal proceeds and
-- realized profit are tracked independently. Integer cost allocation is exact.

local _, GF = ...

GF.Domain = GF.Domain or {}
local Ledger = {}
GF.Domain.Ledger = Ledger
Ledger.__index = Ledger

local STATUS = GF.TX_STATUS

local ALLOWED_TRANSITIONS = {
    [STATUS.SUBMITTED] = {
        [STATUS.CONFIRMED] = true,
        [STATUS.FAILED] = true,
        [STATUS.CANCELLED] = true,
        [STATUS.UNCERTAIN] = true,
    },
    [STATUS.CONFIRMED] = {
        [STATUS.AWAITING_MAIL] = true,
        [STATUS.PARTIALLY_RECEIVED] = true,
        [STATUS.RECEIVED] = true,
        [STATUS.FAILED] = true,
        [STATUS.UNCERTAIN] = true,
    },
    [STATUS.AWAITING_MAIL] = {
        [STATUS.PARTIALLY_RECEIVED] = true,
        [STATUS.RECEIVED] = true,
        [STATUS.FAILED] = true,
        [STATUS.UNCERTAIN] = true,
    },
    [STATUS.PARTIALLY_RECEIVED] = {
        [STATUS.RECEIVED] = true,
        [STATUS.UNCERTAIN] = true,
    },
    [STATUS.RECEIVED] = {
        [STATUS.PARTIALLY_DISPOSED] = true,
        [STATUS.DISPOSED] = true,
        [STATUS.UNCERTAIN] = true,
    },
    [STATUS.PARTIALLY_DISPOSED] = {
        [STATUS.DISPOSED] = true,
        [STATUS.UNCERTAIN] = true,
    },
    [STATUS.UNCERTAIN] = {
        [STATUS.CONFIRMED] = true,
        [STATUS.PARTIALLY_RECEIVED] = true,
        [STATUS.RECEIVED] = true,
        [STATUS.PARTIALLY_DISPOSED] = true,
        [STATUS.DISPOSED] = true,
        [STATUS.FAILED] = true,
    },
    [STATUS.FAILED] = {
        [STATUS.UNCERTAIN] = true,
        [STATUS.CONFIRMED] = true,
    },
    [STATUS.CANCELLED] = {},
    [STATUS.DISPOSED] = {
        [STATUS.UNCERTAIN] = true,
    },
}

local VALID_STRATEGIES = {
    [GF.STRATEGY_VENDOR] = true,
    [GF.STRATEGY_DISENCHANT] = true,
}

local function isTerminal(status)
    return status == STATUS.DISPOSED or status == STATUS.FAILED or status == STATUS.CANCELLED
end

function Ledger.New(options)
    options = options or {}
    local self = setmetatable({
        transactions = {},
        byId = {},
        maxTransactions = options.maxTransactions or 5000,
        now = options.now or function()
            return type(time) == "function" and time() or 0
        end,
        idFactory = options.idFactory or function(prefix)
            return GF.Util.NewId(prefix)
        end,
    }, Ledger)
    return self
end

function Ledger:Get(id)
    return self.byId[id]
end

function Ledger:List(filter)
    filter = filter or {}
    local result = {}
    for index = 1, #self.transactions do
        local transaction = self.transactions[index]
        local include = true
        if filter.marketKey and transaction.marketKey ~= filter.marketKey then
            include = false
        end
        if filter.characterKey and transaction.characterKey ~= filter.characterKey then
            include = false
        end
        if filter.strategy and transaction.strategy ~= filter.strategy then
            include = false
        end
        if filter.since and (transaction.createdAt or 0) < filter.since then
            include = false
        end
        if filter.statuses and not filter.statuses[transaction.status] then
            include = false
        end
        if include then
            result[#result + 1] = transaction
        end
    end
    table.sort(result, function(left, right)
        if left.createdAt == right.createdAt then
            return left.id > right.id
        end
        return (left.createdAt or 0) > (right.createdAt or 0)
    end)
    return result
end

function Ledger:Create(data, now)
    data = data or {}
    if not VALID_STRATEGIES[data.strategy] then
        return nil, "invalid_strategy"
    end
    if not GF.Util.IsInteger(data.purchasedQuantity) or data.purchasedQuantity <= 0 then
        return nil, "invalid_quantity"
    end
    if not GF.Util.IsCopper(data.purchasedCost) then
        return nil, "invalid_cost"
    end
    if data.expectedProceeds ~= nil and (type(data.expectedProceeds) ~= "number" or data.expectedProceeds < 0) then
        return nil, "invalid_expected_proceeds"
    end
    if type(data.marketKey) ~= "string" or data.marketKey == "" then
        return nil, "invalid_market"
    end

    now = now or self.now()
    local transaction = {
        id = data.id or self.idFactory("tx"),
        strategy = data.strategy,
        marketKey = data.marketKey,
        characterKey = data.characterKey or "unknown",
        auctionId = data.auctionId,
        itemId = data.itemId,
        itemKey = type(data.itemKey) == "string" and data.itemKey or nil,
        variantKey = data.variantKey,
        itemName = data.itemName,
        itemLink = data.itemLink,
        purchasedQuantity = data.purchasedQuantity,
        purchasedCost = data.purchasedCost,
        expectedProceeds = data.expectedProceeds or 0,
        confirmedAt = data.confirmedAt,
        createdAt = data.createdAt or now,
        updatedAt = now,
        status = data.status or STATUS.SUBMITTED,
        receivedQuantity = data.receivedQuantity or 0,
        disposedQuantity = data.disposedQuantity or 0,
        realizedProceeds = data.realizedProceeds or 0,
        allocatedCost = data.allocatedCost or 0,
        disposals = data.disposals or {},
        processedEvents = data.processedEvents or {},
        mailEventIds = data.mailEventIds or {},
        notes = data.notes,
        reason = data.reason,
        source = data.source,
        manual = data.manual == true,
    }
    if not ALLOWED_TRANSITIONS[transaction.status] then
        return nil, "invalid_status"
    end
    if transaction.id == nil or self.byId[transaction.id] then
        return nil, "duplicate_id"
    end

    self.transactions[#self.transactions + 1] = transaction
    self.byId[transaction.id] = transaction
    self:Prune()
    return transaction
end

function Ledger:Transition(id, status, patch, now)
    local transaction = self.byId[id]
    if not transaction then
        return nil, "not_found"
    end
    if not ALLOWED_TRANSITIONS[status] then
        return nil, "invalid_status"
    end
    if transaction.status == status then
        if patch then
            for key, value in pairs(patch) do
                transaction[key] = value
            end
        end
        return transaction
    end
    if not ALLOWED_TRANSITIONS[transaction.status] or not ALLOWED_TRANSITIONS[transaction.status][status] then
        return nil, "invalid_transition"
    end

    transaction.status = status
    transaction.updatedAt = now or self.now()
    if status == STATUS.CONFIRMED and not transaction.confirmedAt then
        transaction.confirmedAt = transaction.updatedAt
    end
    if patch then
        for key, value in pairs(patch) do
            transaction[key] = value
        end
    end
    return transaction
end

function Ledger:Confirm(id, now)
    return self:Transition(id, STATUS.CONFIRMED, nil, now)
end

function Ledger:MarkAwaitingMail(id, now)
    return self:Transition(id, STATUS.AWAITING_MAIL, nil, now)
end

function Ledger:MarkUncertain(id, reason, now)
    return self:Transition(id, STATUS.UNCERTAIN, {reason = reason}, now)
end

function Ledger:Fail(id, reason, now)
    return self:Transition(id, STATUS.FAILED, {reason = reason}, now)
end

local function resolveStatusForReceipt(received, purchased)
    if received >= purchased then
        return STATUS.RECEIVED
    elseif received > 0 then
        return STATUS.PARTIALLY_RECEIVED
    end
    return STATUS.CONFIRMED
end

function Ledger:MarkReceived(id, quantity, eventId, now)
    local transaction = self.byId[id]
    if not transaction then
        return 0, "not_found"
    end
    if not GF.Util.IsInteger(quantity) or quantity <= 0 then
        return 0, "invalid_quantity"
    end
    if eventId then
        if transaction.processedEvents[eventId] then
            return 0, "duplicate"
        end
        transaction.processedEvents[eventId] = true
    end
    if transaction.status == STATUS.SUBMITTED or transaction.status == STATUS.FAILED
        or transaction.status == STATUS.CANCELLED then
        return 0, "invalid_state"
    end

    local remaining = transaction.purchasedQuantity - transaction.receivedQuantity
    local delta = math.min(quantity, math.max(0, remaining))
    if delta <= 0 then
        return 0, "nothing_to_receive"
    end
    transaction.receivedQuantity = transaction.receivedQuantity + delta
    local newStatus = resolveStatusForReceipt(transaction.receivedQuantity, transaction.purchasedQuantity)
    if newStatus ~= transaction.status then
        local ok, reason = self:Transition(id, newStatus, nil, now)
        if not ok then
            -- Keep the quantity change and flag the transaction rather than losing data.
            transaction.manual = true
            transaction.reason = transaction.reason or reason
        end
    end
    transaction.updatedAt = now or self.now()
    return delta, nil
end

function Ledger:AllocateCost(transaction, quantity)
    if not transaction or not GF.Util.IsInteger(quantity) or quantity <= 0 then
        return 0
    end
    local remainingUnits = transaction.purchasedQuantity - transaction.disposedQuantity
    if quantity >= remainingUnits then
        return math.max(0, transaction.purchasedCost - transaction.allocatedCost)
    end
    local allocation = math.floor(transaction.purchasedCost * quantity / transaction.purchasedQuantity)
    local maxAllocation = transaction.purchasedCost - transaction.allocatedCost
    if allocation > maxAllocation then
        allocation = maxAllocation
    end
    return allocation
end

function Ledger:AddProceeds(id, amount, quantity, eventId, now)
    local transaction = self.byId[id]
    if not transaction then
        return nil, "not_found"
    end
    if not GF.Util.IsCopper(amount) then
        return nil, "invalid_amount"
    end
    if not GF.Util.IsInteger(quantity) or quantity <= 0 then
        return nil, "invalid_quantity"
    end
    if eventId then
        if transaction.processedEvents[eventId] then
            return nil, "duplicate"
        end
        transaction.processedEvents[eventId] = true
    end
    if transaction.receivedQuantity <= 0 then
        return nil, "not_received"
    end
    local remaining = transaction.receivedQuantity - transaction.disposedQuantity
    if quantity > remaining then
        return nil, "exceeds_received"
    end

    local allocation = self:AllocateCost(transaction, quantity)
    local record = {
        quantity = quantity,
        allocatedCost = allocation,
        proceeds = amount,
        at = now or self.now(),
    }
    transaction.disposals[#transaction.disposals + 1] = record
    transaction.disposedQuantity = transaction.disposedQuantity + quantity
    transaction.allocatedCost = transaction.allocatedCost + allocation
    transaction.realizedProceeds = transaction.realizedProceeds + amount
    transaction.updatedAt = now or self.now()

    local newStatus = STATUS.PARTIALLY_DISPOSED
    if transaction.disposedQuantity >= transaction.purchasedQuantity then
        newStatus = STATUS.DISPOSED
    end
    if newStatus ~= transaction.status then
        local ok, reason = self:Transition(id, newStatus, nil, now)
        if not ok then
            transaction.manual = true
            transaction.reason = transaction.reason or reason
        end
    end
    return record, nil
end

--- Reverse the most recent disposal, used for vendor buyback. A full reversal is
--- exact; partial buybacks should be reconciled with the exact refunded amount.
function Ledger:ReverseLastDisposal(id, refundAmount, now)
    local transaction = self.byId[id]
    if not transaction then
        return nil, "not_found"
    end
    local record = table.remove(transaction.disposals)
    if not record then
        return nil, "no_disposal"
    end
    transaction.disposedQuantity = math.max(0, transaction.disposedQuantity - record.quantity)
    transaction.allocatedCost = math.max(0, transaction.allocatedCost - record.allocatedCost)
    local refund = refundAmount or record.proceeds
    if not GF.Util.IsCopper(refund) then
        return nil, "invalid_amount"
    end
    transaction.realizedProceeds = math.max(0, transaction.realizedProceeds - refund)
    transaction.updatedAt = now or self.now()
    transaction.reversal = true
    if transaction.status == STATUS.DISPOSED then
        transaction.status = STATUS.PARTIALLY_DISPOSED
    end
    return record, nil
end

function Ledger:RecordMailEvent(id, eventId)
    local transaction = self.byId[id]
    if not transaction or not eventId then
        return false
    end
    if transaction.mailEventIds[eventId] then
        return false
    end
    transaction.mailEventIds[eventId] = true
    return true
end

--- Attempt to auto-match a mail item to pending transactions.
--- Returns the transaction ID if matched, nil otherwise.
function Ledger:AutoMatchMail(itemLink, quantity)
    if not itemLink or not quantity then return nil end
    local itemId = GF.Domain.ScanNormalizer.GetItemIdFromLink(itemLink)
    if not itemId then return nil end

    local transactions = self:List({ status = { "awaiting_mail", "confirmed" } })
    for _, tx in ipairs(transactions) do
        if tx.itemId == itemId and tx.receivedQuantity < tx.purchasedQuantity then
            local remaining = tx.purchasedQuantity - tx.receivedQuantity
            if remaining >= quantity then
                return tx.id
            end
        end
    end
    return nil
end

function Ledger:Metrics(filter)
    local transactions = self:List(filter)
    local metrics = {
        transactions = #transactions,
        pendingSpend = 0,
        uncertainSpend = 0,
        confirmedSpend = 0,
        realizedProceeds = 0,
        realizedCost = 0,
        realizedProfit = 0,
        realizedRoi = 0,
        inventoryCost = 0,
        estimatedResale = 0,
        pendingMail = 0,
        awaitingReceipt = 0,
        disposedTransactions = 0,
        unmatched = 0,
        sessionSpent = 0,
    }

    for index = 1, #transactions do
        local transaction = transactions[index]
        local status = transaction.status
        if status == STATUS.SUBMITTED then
            metrics.pendingSpend = metrics.pendingSpend + transaction.purchasedCost
        elseif status == STATUS.UNCERTAIN then
            metrics.uncertainSpend = metrics.uncertainSpend + transaction.purchasedCost
        end

        if status == STATUS.CONFIRMED or status == STATUS.AWAITING_MAIL
            or status == STATUS.PARTIALLY_RECEIVED or status == STATUS.RECEIVED
            or status == STATUS.PARTIALLY_DISPOSED or status == STATUS.DISPOSED then
            metrics.confirmedSpend = metrics.confirmedSpend + transaction.purchasedCost
        end

        if status == STATUS.CONFIRMED or status == STATUS.AWAITING_MAIL then
            metrics.pendingMail = metrics.pendingMail + 1
        end
        if transaction.receivedQuantity == 0 and status ~= STATUS.SUBMITTED
            and status ~= STATUS.FAILED and status ~= STATUS.CANCELLED then
            metrics.awaitingReceipt = metrics.awaitingReceipt + 1
            metrics.unmatched = metrics.unmatched + 1
        end
        if status == STATUS.DISPOSED or status == STATUS.PARTIALLY_DISPOSED then
            metrics.disposedTransactions = metrics.disposedTransactions + 1
        end

        metrics.realizedProceeds = metrics.realizedProceeds + transaction.realizedProceeds
        metrics.realizedCost = metrics.realizedCost + transaction.allocatedCost
        if status ~= STATUS.SUBMITTED and status ~= STATUS.FAILED and status ~= STATUS.CANCELLED then
            metrics.inventoryCost = metrics.inventoryCost
                + math.max(0, transaction.purchasedCost - transaction.allocatedCost)
        end

        local remainingQuantity = math.max(0, transaction.purchasedQuantity - transaction.disposedQuantity)
        if transaction.purchasedQuantity > 0 and status ~= STATUS.FAILED and status ~= STATUS.CANCELLED then
            metrics.estimatedResale = metrics.estimatedResale
                + (transaction.expectedProceeds or 0) * remainingQuantity / transaction.purchasedQuantity
        end
    end

    metrics.realizedProfit = metrics.realizedProceeds - metrics.realizedCost
    metrics.realizedRoi = metrics.realizedCost > 0
        and (100 * metrics.realizedProfit / metrics.realizedCost) or 0
    metrics.sessionSpent = metrics.pendingSpend + metrics.uncertainSpend + metrics.confirmedSpend
    return metrics
end

function Ledger:Prune()
    if #self.transactions <= self.maxTransactions then
        return
    end
    local kept = {}
    local overflow = #self.transactions - self.maxTransactions
    for index = 1, #self.transactions do
        local transaction = self.transactions[index]
        if overflow > 0 and isTerminal(transaction.status) then
            self.byId[transaction.id] = nil
            overflow = overflow - 1
        else
            kept[#kept + 1] = transaction
        end
    end
    self.transactions = kept
end

function Ledger:Reset()
    self.transactions = {}
    self.byId = {}
end

function Ledger:Export()
    return GF.Util.DeepCopy(self.transactions)
end

function Ledger:Load(data)
    if type(data) ~= "table" then
        return 0
    end
    local loaded = 0
    for index = 1, #data do
        local transaction = data[index]
        if type(transaction) == "table" and transaction.id and not self.byId[transaction.id] then
            transaction.disposals = transaction.disposals or {}
            transaction.processedEvents = transaction.processedEvents or {}
            transaction.mailEventIds = transaction.mailEventIds or {}
            transaction.receivedQuantity = transaction.receivedQuantity or 0
            transaction.disposedQuantity = transaction.disposedQuantity or 0
            transaction.realizedProceeds = transaction.realizedProceeds or 0
            transaction.allocatedCost = transaction.allocatedCost or 0
            self.transactions[#self.transactions + 1] = transaction
            self.byId[transaction.id] = transaction
            loaded = loaded + 1
        end
    end
    table.sort(self.transactions, function(left, right)
        return (left.createdAt or 0) < (right.createdAt or 0)
    end)
    return loaded
end
