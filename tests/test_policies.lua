-- test_policies.lua -- Colony policies system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Colony: Policies')

T.test('getAll returns policies in order', function()
    H.resetAll()
    -- Force-reload to reset module-level active states
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')
    local all = Policies.getAll()
    T.eq(#all, 6, 'six policies defined')
    T.eq(all[1].id, 'extended_shifts')
    T.eq(all[2].id, 'rationing')
    T.eq(all[3].id, 'martial_law')
    T.eq(all[4].id, 'emergency_protocol')
    T.eq(all[5].id, 'quota_compliance')
    T.eq(all[6].id, 'blackout_protocol')
end)

T.test('toggle activates and deactivates a policy', function()
    H.resetAll()
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')
    T.eq(Policies.isActive('rationing'), false, 'inactive by default')

    Policies.toggle('rationing')
    T.ok(Policies.isActive('rationing'), 'active after first toggle')

    Policies.toggle('rationing')
    T.eq(Policies.isActive('rationing'), false, 'inactive after second toggle')
end)

T.test('toggle returns false for unknown policy', function()
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')
    local ok = Policies.toggle('nonexistent_policy')
    T.eq(ok, false, 'unknown policy returns false')
end)

T.test('getWorkSpeedMult reflects extended_shifts', function()
    H.resetAll()
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')
    T.eq(Policies.getWorkSpeedMult(), 1.0, 'default is 1.0')

    Policies.activate('extended_shifts')
    T.near(Policies.getWorkSpeedMult(), 1.25, 0.001, 'extended shifts gives 1.25')

    Policies.deactivate('extended_shifts')
    T.eq(Policies.getWorkSpeedMult(), 1.0, 'back to 1.0 after deactivate')
end)

T.test('getFoodDrainMult reflects rationing', function()
    H.resetAll()
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')
    T.eq(Policies.getFoodDrainMult(), 1.0, 'default is 1.0')

    Policies.activate('rationing')
    T.near(Policies.getFoodDrainMult(), 0.70, 0.001, 'rationing gives 0.70')
end)

T.test('martial_law enables noFreeTime and blockMentalBreak', function()
    H.resetAll()
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')
    T.eq(Policies.isNoFreeTime(), false, 'free time allowed by default')
    T.eq(Policies.isMentalBreakBlocked(), false, 'mental breaks allowed by default')

    Policies.activate('martial_law')
    T.ok(Policies.isNoFreeTime(), 'no free time under martial law')
    T.ok(Policies.isMentalBreakBlocked(), 'mental breaks blocked under martial law')
    T.eq(Policies.getDiscontentAdd(), 20, 'martial law adds 20 discontent')
end)

T.test('getMoraleDrainAdd stacks from multiple policies', function()
    H.resetAll()
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')
    T.eq(Policies.getMoraleDrainAdd(), 0, 'no drain by default')

    Policies.activate('extended_shifts')
    T.near(Policies.getMoraleDrainAdd(), 0.10, 0.001, 'extended shifts adds 0.10')

    Policies.activate('rationing')
    T.near(Policies.getMoraleDrainAdd(), 0.25, 0.001, 'both policies stack to 0.25')
end)

T.test('emergency_protocol enables allPriority1', function()
    H.resetAll()
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')
    T.eq(Policies.isAllPriority1(), false, 'not active by default')

    Policies.activate('emergency_protocol')
    T.ok(Policies.isAllPriority1(), 'allPriority1 when emergency active')

    -- Verify startDay was recorded
    local def = Policies.get('emergency_protocol')
    T.notnil(def.startDay, 'startDay set on activation')
end)

T.test('quota_compliance boosts supply drops and outbound quota size', function()
    H.resetAll()
    package.loaded['src.colony.policies'] = nil
    local Policies = require('src.colony.policies')

    Policies.activate('quota_compliance')
    T.near(Policies.getSupplyDropMult(), 1.35, 0.001, 'quota compliance boosts supply drops')
    T.near(Policies.getQuotaShipmentMult(), 1.5, 0.001, 'quota compliance boosts outbound quota size')
end)
