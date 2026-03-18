local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Simulation: Containment')

local function reloadModule(name)
    package.loaded[name] = nil
    return require(name)
end

local function spawnCell(x, y, cellType)
    local ECS = require('src.ecs.ecs')
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, prevX = x, prevY = y })
    ECS.set(id, 'containment_cell', {
        cellType = cellType or 'locker',
        mode = 'study',
        subjectId = nil,
        currentRisk = 0,
        incidentCooldown = 0,
    })
    return id
end

T.test('intact transfer queues a specimen shipment and clears the cell', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Quotas = reloadModule('src.sim.quotas')
    local Containment = reloadModule('src.sim.containment')

    Quotas.init()
    Quotas.step(0.05)
    Containment.init()

    local cellId = spawnCell(8, 8, 'locker')
    local subject = Containment.registerFieldSubject('signal_idol', { source = 'test shaft' })
    T.notnil(subject, 'subject registered')
    T.ok(Containment.assignNextSubject(cellId), 'subject assigned to locker')

    local ok = Containment.transferSubject(cellId)
    T.ok(ok, 'transfer succeeds')
    T.eq(ECS.get(cellId, 'containment_cell').subjectId, nil, 'cell cleared after transfer')
    T.eq(Containment.getStats().transferred, 1, 'transfer stat recorded')

    local quotaState = Quotas.getState()
    T.eq(quotaState.queuedSpecimenTransfers, 1, 'specimen transfer queued for next shipment')
    T.gt(quotaState.queuedSpecimenValue, 0, 'specimen value recorded for bonus package')
end)

T.test('unstable human subjects cannot be transferred intact', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local Containment = reloadModule('src.sim.containment')

    Containment.init()
    local cellId = spawnCell(12, 12, 'cell')
    local subject = Containment.registerFieldSubject('vessel_host', { source = 'sealed room' })
    T.notnil(subject, 'human subject registered')
    T.ok(Containment.assignNextSubject(cellId), 'subject assigned to live cell')

    local ok, detail = Containment.transferSubject(cellId)
    T.eq(ok, false, 'transfer blocked for unstable human')
    T.ok(detail and detail:find('too unstable'), 'failure explains instability gate')
    T.notnil(ECS.get(cellId, 'containment_cell').subjectId, 'subject remains in cell')
    T.eq(Containment.getStats().transferred or 0, 0, 'no transfer recorded')
end)
