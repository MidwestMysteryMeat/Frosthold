require('tests.mock_love')

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Simulation: Quotas')

local function reloadModule(name)
    package.loaded[name] = nil
    return require(name)
end

T.test('step creates the first quota cycle', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Quotas = reloadModule('src.sim.quotas')

    GS.day = 1
    Quotas.init()
    Quotas.step(0.05)

    local quota = Quotas.getCurrentQuota()
    T.notnil(quota, 'quota exists after first step')
    T.eq(quota.startDay, 1, 'quota starts on current day')
    T.eq(quota.dueDay, 4, 'quota uses a four-day cycle')
    T.eq(quota.target.metal, 2, 'early quota asks for metal')
    T.eq(quota.target.fuel, 1, 'early quota asks for fuel')
    T.eq(quota.target.food, 2, 'early quota asks for food')
end)

T.test('full shipment deducts stock and delivers a supply drop next day', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Quotas = reloadModule('src.sim.quotas')

    GS.resources.food = 40
    GS.resources.fuel = 20
    GS.resources.metal = 12
    GS.resources.wood = 50
    GS.resources.components = 3

    Quotas.init()
    Quotas.step(0.05)
    local quota = Quotas.getCurrentQuota()

    GS.day = quota.dueDay
    local foodBefore = GS.resources.food
    local fuelBefore = GS.resources.fuel
    local metalBefore = GS.resources.metal
    Quotas.step(0.05)

    local last = Quotas.getLastQuota()
    local pending = Quotas.getPendingSupply()

    T.eq(last.status, 'met', 'quota marked as met')
    T.eq(GS.resources.food, foodBefore - quota.target.food, 'food shipped')
    T.eq(GS.resources.fuel, fuelBefore - quota.target.fuel, 'fuel shipped')
    T.eq(GS.resources.metal, metalBefore - quota.target.metal, 'metal shipped')
    T.eq(pending.arrivalDay, quota.dueDay + 1, 'delivery arrives the following day')
    T.ok((pending.package.food or 0) > 0, 'delivery package contains food')

    local foodAfterShipment = GS.resources.food
    GS.day = pending.arrivalDay
    Quotas.step(0.05)

    T.ok(GS.resources.food > foodAfterShipment, 'food added on delivery day')
    T.ok(Quotas.getPendingSupply().delivered, 'pending supply marked delivered')
end)

T.test('quota compliance increases shipment size and supply response', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Policies = reloadModule('src.colony.policies')
    local Quotas = reloadModule('src.sim.quotas')

    Policies.activate('quota_compliance')
    GS.resources.food = 50
    GS.resources.fuel = 30
    GS.resources.metal = 20
    GS.resources.wood = 50

    Quotas.init()
    Quotas.step(0.05)
    local quota = Quotas.getCurrentQuota()

    T.eq(quota.target.metal, 3, 'policy increases metal shipment target')
    T.eq(quota.target.fuel, 2, 'policy increases fuel shipment target')
    T.eq(quota.target.food, 3, 'policy increases food shipment target')

    GS.day = quota.dueDay
    Quotas.step(0.05)

    local pending = Quotas.getPendingSupply()
    T.near(pending.responseMult, 1.35, 0.001, 'policy boosts full-response supply drop')
end)

T.test('state restore preserves pending delivery and active quota', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Quotas = reloadModule('src.sim.quotas')

    GS.resources.food = 40
    GS.resources.fuel = 20
    GS.resources.metal = 12
    GS.resources.wood = 50

    Quotas.init()
    Quotas.step(0.05)
    local quota = Quotas.getCurrentQuota()
    GS.day = quota.dueDay
    Quotas.step(0.05)

    local saved = Quotas.getState()
    Quotas = reloadModule('src.sim.quotas')
    Quotas.restoreState(saved)

    local restoredPending = Quotas.getPendingSupply()
    local restoredQuota = Quotas.getCurrentQuota()
    T.notnil(restoredPending, 'pending delivery restored')
    T.notnil(restoredQuota, 'next quota restored')
    T.eq(restoredPending.arrivalDay, saved.pendingSupply.arrivalDay, 'delivery day preserved')
    T.eq(restoredQuota.dueDay, saved.currentQuota.dueDay, 'next quota due day preserved')
end)

T.test('specimen transfers enrich the next supply drop immediately when one is pending', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Quotas = reloadModule('src.sim.quotas')

    GS.resources.food = 40
    GS.resources.fuel = 20
    GS.resources.metal = 12
    GS.resources.wood = 50
    GS.resources.components = 3

    Quotas.init()
    Quotas.step(0.05)
    local quota = Quotas.getCurrentQuota()
    GS.day = quota.dueDay
    Quotas.step(0.05)

    local pending = Quotas.getPendingSupply()
    local beforeMetal = pending.package.metal or 0
    local beforeComponents = pending.package.components or 0

    local shipment = Quotas.registerSpecimenTransfer({
        kind = 'artifact',
        subtype = 'signal_idol',
        label = 'Signal Idol',
        researchValue = 85,
        instability = 42,
    })

    pending = Quotas.getPendingSupply()
    T.ok(shipment.immediate, 'transfer enriches the already scheduled supply drop')
    T.eq(pending.specimenTransfers, 1, 'pending drop tracks specimen transfers')
    T.gt(pending.package.metal or 0, beforeMetal, 'specimen transfer adds metal to the package')
    T.gt(pending.package.components or 0, beforeComponents, 'specimen transfer adds components to the package')
end)
