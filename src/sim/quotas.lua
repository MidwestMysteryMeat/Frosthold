-- quotas.lua -- Mammona quota and supply-drop cycle
-- Runs a repeating corporate shipment schedule. The colony ships a quota
-- on the due day and receives a supply drop the following day based on how
-- complete the shipment was, then policy and HERMES modifiers adjust it.

local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')
local Tuning    = require('src.sim.tuning')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local Quotas = {}

local function getCycleLength()
    return math.max(1, math.floor(Tuning.get('quotas.cycle_length', 4)))
end

local function getDeliveryDelay()
    return math.max(0, math.floor(Tuning.get('quotas.delivery_delay', 1)))
end

local RESOURCE_VALUE = {
    food       = 2,
    fuel       = 2,
    metal      = 3,
    components = 5,
}

local TARGET_ORDER = { 'metal', 'fuel', 'food', 'components' }
local PACKAGE_ORDER = { 'food', 'fuel', 'wood', 'metal', 'components' }
local LABELS = {
    metal = 'met',
    fuel = 'fuel',
    food = 'food',
    components = 'comp',
}

local state = {
    currentQuota = nil,
    pendingSupply = nil,
    lastQuota = nil,
    queuedSpecimenValue = 0,
    queuedSpecimenTransfers = 0,
}

local function copyTable(src)
    local out = {}
    if not src then return out end
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

local function countLivingColonists()
    local count = 0
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' then
            count = count + 1
        end
    end
    return math.max(1, count)
end

local function sendAlert(title, body, priority)
    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send(title, body, priority or 'info')
    end
end

local function logEvent(title, body)
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.logEvent then
        Storyteller.logEvent(title, body, 0)
    end
end

local function adjustStanding(ratio)
    local fok, Factions = pcall(require, 'src.colony.factions')
    if fok and Factions.modifyRep then
        if ratio >= 1 then
            Factions.modifyRep('mammona_logistics', 2)
        elseif ratio >= 0.75 then
            Factions.modifyRep('mammona_logistics', 1)
        elseif ratio >= 0.4 then
            Factions.modifyRep('mammona_logistics', -2)
        else
            Factions.modifyRep('mammona_logistics', -4)
        end
    end

    local hok, Hope = pcall(require, 'src.colony.hope')
    if hok and Hope.applyDelta then
        if ratio >= 1 then
            Hope.applyDelta(1, -1)
        elseif ratio < 0.4 then
            Hope.applyDelta(-3, 2)
        elseif ratio < 0.75 then
            Hope.applyDelta(-2, 1)
        end
    end
end

local function buildBaseTarget(startDay)
    local colonists = countLivingColonists()
    local day = math.max(1, startDay or (GameState.day or 1))
    local target = {
        metal = 2 + math.floor((day - 1) / 6) + math.floor((colonists - 1) / 4),
        fuel  = 1 + math.floor((day - 1) / 8),
        food  = 2 + math.floor((colonists - 1) / 3),
    }

    if day >= 10 then
        target.components = 1 + math.floor((day - 10) / 20)
    end

    return target
end

local function getQuotaShipmentMult()
    local pok, Policies = pcall(require, 'src.colony.policies')
    if pok and Policies.getQuotaShipmentMult then
        return Policies.getQuotaShipmentMult()
    end
    return 1.0
end

local function getSupplyResponseMult()
    local pok, Policies = pcall(require, 'src.colony.policies')
    if pok and Policies.getSupplyDropMult then
        return Policies.getSupplyDropMult()
    end
    return 1.0
end

local function buildTarget(baseTarget)
    local mult = getQuotaShipmentMult()
    local target = {}
    for _, res in ipairs(TARGET_ORDER) do
        local amount = baseTarget[res]
        if amount and amount > 0 then
            target[res] = math.max(1, math.floor(amount * mult + 0.5))
        end
    end
    return target
end

local function responseForRatio(ratio)
    if ratio >= 1 then return 1.0, 'met' end
    if ratio >= 0.75 then return 0.8, 'short' end
    if ratio >= 0.4 then return 0.55, 'missed' end
    if ratio > 0 then return 0.35, 'failed' end
    return 0.2, 'failed'
end

local function buildSupplyPackage(processedDay, responseMult)
    local colonists = countLivingColonists()
    local base = {
        food       = 6 + colonists * 2,
        fuel       = 4 + math.floor((processedDay - 1) / 5),
        wood       = 8 + math.floor((processedDay - 1) / 4),
        metal      = 3 + math.floor((processedDay - 1) / 6),
        components = processedDay >= 7 and (1 + math.floor((processedDay - 7) / 18)) or 0,
    }

    local package = {}
    for res, amount in pairs(base) do
        if amount > 0 then
            local scaled = math.floor(amount * responseMult + 0.5)
            if res == 'components' then
                if scaled > 0 then package[res] = scaled end
            else
                package[res] = math.max(1, scaled)
            end
        end
    end
    return package
end

local function mergePackage(dst, src)
    for res, amount in pairs(src or {}) do
        if amount and amount > 0 then
            dst[res] = (dst[res] or 0) + amount
        end
    end
end

local function buildSpecimenBonusPackage(value)
    local credits = math.max(1, math.floor(value or 1))
    local package = {
        food = 1 + math.floor(credits / 2),
        fuel = 1 + math.floor(credits / 2),
        metal = 1 + credits,
    }
    if credits >= 2 then
        package.components = math.max(1, math.floor(credits / 2))
    end
    return package
end

local function scoreSubject(subject)
    if not subject then return 1 end
    local value = math.max(1, math.floor((subject.researchValue or 35) / 35))
    if subject.kind == 'human' then
        value = value + 1
    end
    if subject.subtype == 'vessel' then
        value = value + 1
    elseif subject.subtype == 'herald' then
        value = value + 2
    elseif subject.kind == 'artifact' then
        value = value + 1
    end
    if (subject.instability or 0) <= 35 then
        value = value + 1
    end
    return math.max(1, value)
end

local function formatResources(values, order)
    local parts = {}
    for _, res in ipairs(order or TARGET_ORDER) do
        local amount = values and values[res]
        if amount and amount > 0 then
            parts[#parts + 1] = string.format('%s %d', LABELS[res] or res, amount)
        end
    end
    return table.concat(parts, '  ')
end

local function targetValue(target)
    local total = 0
    for res, amount in pairs(target or {}) do
        total = total + (RESOURCE_VALUE[res] or 1) * amount
    end
    return total
end

local function shippedRatio(target)
    local shipped = 0
    local needed = 0
    for res, amount in pairs(target or {}) do
        local value = RESOURCE_VALUE[res] or 1
        local stock = GameState.resources[res] or 0
        shipped = shipped + math.min(stock, amount) * value
        needed = needed + amount * value
    end
    if needed <= 0 then return 1 end
    return math.min(1, shipped / needed)
end

local function beginCycle(startDay)
    local day = math.max(1, startDay or (GameState.day or 1))
    local baseTarget = buildBaseTarget(day)
    state.currentQuota = {
        startDay = day,
        dueDay = day + getCycleLength() - 1,
        baseTarget = baseTarget,
        target = buildTarget(baseTarget),
        announced = false,
        warned = false,
    }
end

local function processQuota()
    local quota = state.currentQuota
    if not quota then return end

    local shipped = {}
    local shippedValue = 0
    local neededValue = targetValue(quota.target)
    for _, res in ipairs(TARGET_ORDER) do
        local required = quota.target[res]
        if required and required > 0 then
            local stock = GameState.resources[res] or 0
            local sent = math.min(stock, required)
            if GameState.resources[res] ~= nil then
                GameState.resources[res] = stock - sent
            end
            shipped[res] = sent
            shippedValue = shippedValue + sent * (RESOURCE_VALUE[res] or 1)
        end
    end

    local ratio = neededValue > 0 and (shippedValue / neededValue) or 1
    local baseResponse, status = responseForRatio(ratio)
    local responseMult = baseResponse * getSupplyResponseMult()
    local arrivalDay = quota.dueDay + getDeliveryDelay()
    local package = buildSupplyPackage(quota.dueDay, responseMult)
    local specimenValue = state.queuedSpecimenValue or 0
    local specimenTransfers = state.queuedSpecimenTransfers or 0
    if specimenValue > 0 then
        mergePackage(package, buildSpecimenBonusPackage(specimenValue))
        state.queuedSpecimenValue = 0
        state.queuedSpecimenTransfers = 0
    end

    state.lastQuota = {
        processedDay = quota.dueDay,
        dueDay = quota.dueDay,
        baseTarget = copyTable(quota.baseTarget),
        target = copyTable(quota.target),
        shipped = shipped,
        ratio = ratio,
        status = status,
        responseMult = responseMult,
    }
    state.pendingSupply = {
        arrivalDay = arrivalDay,
        package = package,
        responseMult = responseMult,
        status = status,
        delivered = false,
        specimenTransfers = specimenTransfers,
    }

    adjustStanding(ratio)

    -- (Paxtera quota enforcement removed — Paxtera is a straightforward temperate map)

    local body
    local priority
    if ratio >= 1 then
        body = string.format('Return pod away with a full shipment (%s). Mammona confirms a supply drop on day %d.',
            formatResources(quota.target, TARGET_ORDER), arrivalDay)
        priority = 'info'
    elseif ratio >= 0.75 then
        body = string.format('Return pod launched short (%s). Mammona trims the next drop.',
            formatResources(quota.target, TARGET_ORDER))
        priority = 'minor'
    elseif ratio >= 0.4 then
        body = string.format('Quota missed. Mammona marks the colony behind schedule. Next drop is reduced.')
        priority = 'major'
    else
        body = 'Quota failed. Mammona classifies the colony as noncompliant and cuts the next drop hard.'
        priority = 'critical'
    end
    sendAlert('Quota Review', body, priority)
    logEvent('Quota Review', body)

    beginCycle(quota.dueDay + 1)
end

local function deliverSupply()
    local pending = state.pendingSupply
    if not pending or pending.delivered then return end

    local Items = getItems()
    for res, amount in pairs(pending.package or {}) do
        if amount > 0 then
            if Items then Items.spawn(GameState.startX, GameState.startY, res, amount, nil, 0)
            else GameState.addResource(res, amount) end
        end
    end
    pending.delivered = true

    local title
    if pending.status == 'met' then
        title = 'Supply Drop Received'
    elseif pending.status == 'short' then
        title = 'Reduced Supply Drop'
    else
        title = 'Emergency Supply Drop'
    end

    local body = string.format('Drop received: %s.', formatResources(pending.package, PACKAGE_ORDER))
    sendAlert(title, body, pending.status == 'met' and 'info' or 'minor')
    logEvent(title, body)
end

function Quotas.init()
    state.currentQuota = nil
    state.pendingSupply = nil
    state.lastQuota = nil
    state.queuedSpecimenValue = 0
    state.queuedSpecimenTransfers = 0
end

function Quotas.step(dt)
    if not state.currentQuota then
        beginCycle(GameState.day or 1)
    end

    local today = GameState.day or 1
    local quota = state.currentQuota
    if quota then
        if not quota.announced and today >= quota.startDay then
            quota.announced = true
            local body = string.format('Mammona posts a shipment due on day %d: %s.',
                quota.dueDay, formatResources(quota.target, TARGET_ORDER))
            sendAlert('New Quota', body, 'info')
            logEvent('New Quota', body)
        end

        if not quota.warned and today >= (quota.dueDay - 1) and today < quota.dueDay then
            quota.warned = true
            local ratio = math.floor(shippedRatio(quota.target) * 100 + 0.5)
            local body = string.format('Quota due tomorrow. Current stock covers %d%% of the shipment.', ratio)
            sendAlert('Quota Due Soon', body, ratio >= 100 and 'info' or 'minor')
        end

        if today >= quota.dueDay and (not state.lastQuota or state.lastQuota.processedDay < quota.dueDay) then
            processQuota()
        end
    end

    if state.pendingSupply and not state.pendingSupply.delivered and today >= state.pendingSupply.arrivalDay then
        deliverSupply()
    end
end

function Quotas.getCurrentQuota()
    return state.currentQuota
end

function Quotas.getPendingSupply()
    return state.pendingSupply
end

function Quotas.getLastQuota()
    return state.lastQuota
end

function Quotas.getProjectedFillRatio()
    if not state.currentQuota then return 0 end
    return shippedRatio(state.currentQuota.target)
end

function Quotas.getStatusSummary()
    if not state.currentQuota then
        return 'Quota cycle offline'
    end

    local quota = state.currentQuota
    local readyPct = math.floor(Quotas.getProjectedFillRatio() * 100 + 0.5)
    local summary = string.format('Quota D%d  %d%% ready  |  %s',
        quota.dueDay, readyPct, formatResources(quota.target, TARGET_ORDER))

    local pending = state.pendingSupply
    if pending and not pending.delivered then
        summary = summary .. string.format('  |  Drop D%d  %.0f%%',
            pending.arrivalDay, pending.responseMult * 100)
        if (pending.specimenTransfers or 0) > 0 then
            summary = summary .. string.format('  |  Specimens %d', pending.specimenTransfers)
        end
    elseif (state.queuedSpecimenTransfers or 0) > 0 then
        summary = summary .. string.format('  |  Specimens queued %d', state.queuedSpecimenTransfers)
    end

    return summary
end

function Quotas.registerSpecimenTransfer(subject)
    local value = scoreSubject(subject)
    local bonus = buildSpecimenBonusPackage(value)
    if state.pendingSupply and not state.pendingSupply.delivered then
        mergePackage(state.pendingSupply.package, bonus)
        state.pendingSupply.specimenTransfers = (state.pendingSupply.specimenTransfers or 0) + 1
        return {
            value = value,
            package = bonus,
            immediate = true,
            arrivalDay = state.pendingSupply.arrivalDay,
        }
    end

    state.queuedSpecimenValue = (state.queuedSpecimenValue or 0) + value
    state.queuedSpecimenTransfers = (state.queuedSpecimenTransfers or 0) + 1
    return {
        value = value,
        package = bonus,
        immediate = false,
        arrivalDay = state.currentQuota and (state.currentQuota.dueDay + getDeliveryDelay()) or ((GameState.day or 1) + getDeliveryDelay()),
    }
end

function Quotas.getState()
    return {
        currentQuota = state.currentQuota and {
            startDay = state.currentQuota.startDay,
            dueDay = state.currentQuota.dueDay,
            baseTarget = copyTable(state.currentQuota.baseTarget),
            target = copyTable(state.currentQuota.target),
            announced = state.currentQuota.announced,
            warned = state.currentQuota.warned,
        } or nil,
        pendingSupply = state.pendingSupply and {
            arrivalDay = state.pendingSupply.arrivalDay,
            package = copyTable(state.pendingSupply.package),
            responseMult = state.pendingSupply.responseMult,
            status = state.pendingSupply.status,
            delivered = state.pendingSupply.delivered,
            specimenTransfers = state.pendingSupply.specimenTransfers or 0,
        } or nil,
        lastQuota = state.lastQuota and {
            processedDay = state.lastQuota.processedDay,
            dueDay = state.lastQuota.dueDay,
            baseTarget = copyTable(state.lastQuota.baseTarget),
            target = copyTable(state.lastQuota.target),
            shipped = copyTable(state.lastQuota.shipped),
            ratio = state.lastQuota.ratio,
            status = state.lastQuota.status,
            responseMult = state.lastQuota.responseMult,
        } or nil,
        queuedSpecimenValue = state.queuedSpecimenValue or 0,
        queuedSpecimenTransfers = state.queuedSpecimenTransfers or 0,
    }
end

function Quotas.restoreState(saved)
    if not saved then
        Quotas.init()
        return
    end

    state.currentQuota = saved.currentQuota and {
        startDay = saved.currentQuota.startDay or (GameState.day or 1),
        dueDay = saved.currentQuota.dueDay or (GameState.day or 1),
        baseTarget = copyTable(saved.currentQuota.baseTarget),
        target = copyTable(saved.currentQuota.target),
        announced = saved.currentQuota.announced == true,
        warned = saved.currentQuota.warned == true,
    } or nil

    state.pendingSupply = saved.pendingSupply and {
        arrivalDay = saved.pendingSupply.arrivalDay or ((GameState.day or 1) + getDeliveryDelay()),
        package = copyTable(saved.pendingSupply.package),
        responseMult = saved.pendingSupply.responseMult or 1,
        status = saved.pendingSupply.status or 'met',
        delivered = saved.pendingSupply.delivered == true,
        specimenTransfers = saved.pendingSupply.specimenTransfers or 0,
    } or nil

    state.lastQuota = saved.lastQuota and {
        processedDay = saved.lastQuota.processedDay or 0,
        dueDay = saved.lastQuota.dueDay or saved.lastQuota.processedDay or 0,
        baseTarget = copyTable(saved.lastQuota.baseTarget),
        target = copyTable(saved.lastQuota.target),
        shipped = copyTable(saved.lastQuota.shipped),
        ratio = saved.lastQuota.ratio or 0,
        status = saved.lastQuota.status or 'met',
        responseMult = saved.lastQuota.responseMult or 1,
    } or nil

    state.queuedSpecimenValue = saved.queuedSpecimenValue or 0
    state.queuedSpecimenTransfers = saved.queuedSpecimenTransfers or 0
end

return Quotas
