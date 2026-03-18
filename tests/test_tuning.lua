require('tests.mock_love')

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Simulation: Tuning')

local function reloadModule(name)
    package.loaded[name] = nil
    return require(name)
end

T.test('returns defaults and applies overrides cleanly', function()
    H.resetAll()
    local Tuning = reloadModule('src.sim.tuning')

    T.eq(Tuning.get('quotas.cycle_length'), 4, 'default quota cycle exposed')
    T.eq(Tuning.get('raids.warning_base'), 15, 'default raid warning exposed')

    Tuning.setOverride('quotas.cycle_length', 2)
    T.eq(Tuning.get('quotas.cycle_length'), 2, 'override takes precedence')

    Tuning.clearOverrides()
    T.eq(Tuning.get('quotas.cycle_length'), 4, 'clearing overrides restores defaults')
end)

T.test('quota timing obeys tuning overrides', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Tuning = reloadModule('src.sim.tuning')
    local Quotas = reloadModule('src.sim.quotas')

    Tuning.setOverride('quotas.cycle_length', 2)
    Tuning.setOverride('quotas.delivery_delay', 0)

    GS.day = 1
    GS.resources.food = 40
    GS.resources.fuel = 20
    GS.resources.metal = 8

    Quotas.init()
    Quotas.step(0.05)

    local quota = Quotas.getCurrentQuota()
    T.eq(quota.dueDay, 2, 'cycle length override shortens quota')

    GS.day = quota.dueDay
    Quotas.step(0.05)

    local pending = Quotas.getPendingSupply()
    T.eq(pending.arrivalDay, quota.dueDay, 'delivery delay override affects arrival day')
end)

T.test('raid warning timing obeys tuning overrides', function()
    H.resetAll()
    local Tilemap = require('src.world.tilemap')
    local Tuning = reloadModule('src.sim.tuning')
    local Raids = reloadModule('src.sim.raids')

    Tilemap.init(32, 32)
    Tuning.setOverride('raids.warning_swarm', 33)

    local ok, err = Raids.startRaid('swarm_wave')
    T.ok(ok ~= nil, 'swarm raid starts for warning test')

    local info = Raids.getActiveRaid()
    T.notnil(info, 'active raid info exists')
    T.eq(info.warningTime, 33, 'warning override applied to swarm raid')

    Raids.endRaid()
end)
