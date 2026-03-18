-- test_expeditions.lua -- Expedition system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Expeditions')

local Expeditions = require('src.exploration.expeditions')
local Overworld   = require('src.exploration.overworld')
local ECS         = require('src.ecs.ecs')

-- Initialize storyteller so expedition launch/resolve log calls work.
local function initStoryteller()
    local Storyteller = require('src.storyteller.storyteller')
    Storyteller.init('steady')
end

T.test('init resets state to empty', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    T.eq(Expeditions.getActiveCount(), 0, 'no active expeditions')
    T.ok(Expeditions.canLaunch(), 'can launch when empty')
end)

T.test('validateLaunch rejects empty party', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    local ok, err = Expeditions.validateLaunch('frozen_wastes', {})
    T.eq(ok, false, 'empty party rejected')
    T.ok(err:find('No colonists'), 'error mentions no colonists')
end)

T.test('validateLaunch rejects unknown destination', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    local colId = H.spawnTestColonist(64, 64)
    local ok, err = Expeditions.validateLaunch('nonexistent_place', { colId })
    T.eq(ok, false, 'unknown destination rejected')
    T.ok(err:find('Unknown'), 'error mentions unknown')
end)

T.test('validateLaunch rejects party exceeding max size', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    local ids = {}
    for i = 1, 4 do
        ids[i] = H.spawnTestColonist(64, 64, { name = 'Col' .. i })
    end

    local ok, err = Expeditions.validateLaunch('frozen_wastes', ids)
    T.eq(ok, false, 'party of 4 rejected')
    T.ok(err:find('Maximum party'), 'error mentions max party')
end)

T.test('launch creates expedition and marks colonists away', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    local colId = H.spawnTestColonist(64, 64, { name = 'Scout' })
    local expId, err = Expeditions.launch('frozen_wastes', { colId })

    T.notnil(expId, 'expedition ID returned')
    T.eq(Expeditions.getActiveCount(), 1, 'one active expedition')

    -- Colonist state should be flagged away
    local col = ECS.get(colId, 'colonist')
    T.eq(col.state, 'away_expedition', 'colonist marked away')
    T.ok(ECS.has(colId, 'away'), 'away component set')
    T.ok(Expeditions.isOnExpedition(colId), 'isOnExpedition returns true')
end)

T.test('cannot exceed max concurrent expeditions', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    -- Launch two expeditions (the max)
    local c1 = H.spawnTestColonist(64, 64, { name = 'A' })
    local c2 = H.spawnTestColonist(64, 64, { name = 'B' })
    local c3 = H.spawnTestColonist(64, 64, { name = 'C' })

    Expeditions.launch('frozen_wastes', { c1 })
    Expeditions.launch('frozen_wastes', { c2 })

    T.eq(Expeditions.getActiveCount(), 2, 'two active')
    T.eq(Expeditions.canLaunch(), false, 'cannot launch a third')

    local expId, err = Expeditions.launch('frozen_wastes', { c3 })
    T.isnil(expId, 'third launch rejected')
end)

T.test('getById and getProgress track expedition', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    local colId = H.spawnTestColonist(64, 64, { name = 'Tracker' })
    local expId = Expeditions.launch('frozen_wastes', { colId })

    local exp = Expeditions.getById(expId)
    T.notnil(exp, 'found by ID')
    T.eq(exp.state, 'travelling', 'initial state is travelling')
    T.eq(exp.destId, 'frozen_wastes', 'destination stored')
    T.near(Expeditions.getProgress(expId), 0, 0.01, 'progress starts at 0')

    local remaining = Expeditions.getRemaining(expId)
    T.gt(remaining, 0, 'time remaining is positive')
end)

T.test('step resolves expedition after duration elapses', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    local GameState = require('src.game_state')
    GameState.speed = 1

    local colId = H.spawnTestColonist(64, 64, { name = 'Returner' })
    local expId = Expeditions.launch('frozen_wastes', { colId })

    -- frozen_wastes duration is 30 game-seconds
    -- Step past the full duration
    Expeditions.step(35)

    -- Expedition should be resolved and removed
    T.eq(Expeditions.getActiveCount(), 0, 'expedition resolved and removed')

    -- Colonist should be restored
    local col = ECS.get(colId, 'colonist')
    T.neq(col.state, 'away_expedition', 'colonist no longer away')
    T.eq(ECS.has(colId, 'away'), false, 'away component removed')
end)

T.test('successful expeditions can recover containment finds from dangerous sites', function()
    H.resetAll()
    initStoryteller()
    Expeditions.init()

    local Containment = require('src.sim.containment')
    Containment.init()

    local original = Overworld.DESTINATIONS.frozen_wastes.findings
    Overworld.DESTINATIONS.frozen_wastes.findings = {
        success = {
            min = 1, max = 1,
            entries = {
                { template = 'signal_idol', weight = 1, overrides = { source = 'test expedition cache' } },
            },
        },
    }

    local colId = H.spawnTestColonist(64, 64, { name = 'Finder' })
    local expId = Expeditions.launch('frozen_wastes', { colId })
    local exp = Expeditions.getById(expId)
    exp.map.completed = true
    exp.map.outcome = 'success'
    exp.map.lootCollected = {}
    exp.map.encountersLost = 0

    Expeditions.step(0.1)

    T.eq(Expeditions.getActiveCount(), 0, 'expedition resolved')
    T.eq(Containment.getStats().recovered, 1, 'containment subject recovered from expedition')
    T.ok(Containment.hasPendingSubjects(), 'recovered subject waits for containment')

    Overworld.DESTINATIONS.frozen_wastes.findings = original
end)
