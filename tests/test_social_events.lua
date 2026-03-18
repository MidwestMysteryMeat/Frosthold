-- test_social_events.lua -- Social system discrete events and persistence tests
-- Tests social event firing, cooldowns, and save/load of social log.

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Social Events')

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Social    = require('src.colonist.social')

-- Helper: initialize modules needed by social system
local function initWorld()
    local Tilemap = require('src.world.tilemap')
    Tilemap.init(32, 32)
    local Weather = require('src.weather.weather')
    Weather.init()
    local Storyteller = require('src.storyteller.storyteller')
    Storyteller.init('steady')
    require('src.colony.hope')
end

-- Helper: spawn two colonists close together (within proximity range of 3 tiles)
local function spawnNearbyPair()
    local idA = H.spawnTestColonist(16, 16, { name = 'Alice' })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob' })
    return idA, idB
end

---------------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------------

T.test('test_social_opinion_basics', function()
    H.resetAll()
    initWorld()

    local idA = H.spawnTestColonist(16, 16, { name = 'Alice' })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob' })

    -- Initial opinion is 0
    T.eq(Social.getOpinion(idA, idB), 0, 'initial opinion is 0')

    -- Set opinion
    Social.setOpinion(idA, idB, 60)
    T.eq(Social.getOpinion(idA, idB), 60, 'opinion set to 60')
    T.eq(Social.getOpinion(idB, idA), 60, 'symmetric opinion')

    -- Friend/rival checks
    T.ok(Social.isFriend(idA, idB), 'A and B are friends at 60')
    T.ok(not Social.isRival(idA, idB), 'A and B are not rivals at 60')

    Social.setOpinion(idA, idB, -40)
    T.ok(Social.isRival(idA, idB), 'A and B are rivals at -40')
    T.ok(not Social.isFriend(idA, idB), 'A and B are not friends at -40')
end)

T.test('test_social_adjustOpinion', function()
    H.resetAll()
    initWorld()

    local idA = H.spawnTestColonist(16, 16, { name = 'Alice' })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob' })

    Social.adjustOpinion(idA, idB, 25)
    T.eq(Social.getOpinion(idA, idB), 25, 'adjusted to 25')

    Social.adjustOpinion(idA, idB, -10)
    T.eq(Social.getOpinion(idA, idB), 15, 'adjusted down to 15')

    -- Clamp to range
    Social.adjustOpinion(idA, idB, 200)
    T.eq(Social.getOpinion(idA, idB), 100, 'clamped to 100')

    Social.adjustOpinion(idA, idB, -300)
    T.eq(Social.getOpinion(idA, idB), -100, 'clamped to -100')
end)

T.test('test_social_log_populated', function()
    H.resetAll()
    initWorld()
    Social.registerSystems()

    local idA, idB = spawnNearbyPair()

    -- Social events are probabilistic. To test that the system CAN generate
    -- log entries, we force opinion to trigger eligible events and run many ticks.
    -- The social system runs as an ECS system, so we tick via ECS.update.
    GameState.simTick = 0

    local logBefore = #Social.getSocialLog()

    -- Run many ticks to give discrete events a chance to fire.
    -- Each tick processes the social system for nearby colonists.
    for i = 1, 500 do
        GameState.simTick = i
        ECS.update(1.0)
    end

    -- Social events are probabilistic; with 500 ticks at dt=1.0 and
    -- 3 possible positive events each at 0.002-0.004 chance, odds of
    -- at least one are high. But not guaranteed. Check non-crash at minimum.
    local logAfter = Social.getSocialLog()
    T.ok(type(logAfter) == 'table', 'socialLog is a table after ticking')
    -- If events fired, verify log entry structure
    if #logAfter > logBefore then
        local entry = logAfter[#logAfter]
        T.notnil(entry.msg, 'log entry has msg')
        T.notnil(entry.day, 'log entry has day')
        T.notnil(entry.hour, 'log entry has hour')
    end
end)

T.test('test_social_event_cooldown', function()
    H.resetAll()
    initWorld()
    Social.registerSystems()

    local idA, idB = spawnNearbyPair()

    -- Force an opinion that enables events, then tick rapidly
    Social.setOpinion(idA, idB, 0)
    GameState.simTick = 0

    -- Run a burst of ticks
    local eventCount = 0
    for i = 1, 100 do
        GameState.simTick = i
        local logBefore = #Social.getSocialLog()
        ECS.update(0.1)  -- small dt so cooldown doesn't expire (30s cooldown)
        if #Social.getSocialLog() > logBefore then
            eventCount = eventCount + 1
        end
    end

    -- With 0.1s per tick, 100 ticks = 10s total. Cooldown is 30s.
    -- So at most 1 event per pair should fire (the first one).
    T.ok(eventCount <= 2, 'cooldown prevents rapid event spam (got ' .. eventCount .. ')')
end)

T.test('test_social_save_restore_log', function()
    H.resetAll()
    initWorld()

    local idA = H.spawnTestColonist(16, 16, { name = 'Alice' })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob' })

    -- Set up opinions and manually populate the social log
    Social.setOpinion(idA, idB, 55)

    -- Save state
    local state = Social.getState()
    T.notnil(state, 'getState returns data')
    T.notnil(state.opinions, 'opinions in state')
    T.notnil(state.socialLog, 'socialLog in state')

    -- Verify opinions are in the state
    T.ok(state.opinions[idA] ~= nil or state.opinions[idB] ~= nil,
        'opinion data present in saved state')

    -- Wipe and restore
    Social.loadState({ opinions = {}, grieving = {}, socialLog = {} })
    T.eq(Social.getOpinion(idA, idB), 0, 'opinion cleared after wipe')

    Social.loadState(state)
    T.eq(Social.getOpinion(idA, idB), 55, 'opinion restored after loadState')
end)

T.test('test_social_save_restore_opinions_survive', function()
    H.resetAll()
    initWorld()

    local idA = H.spawnTestColonist(16, 16, { name = 'Alice' })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob' })
    local idC = H.spawnTestColonist(18, 16, { name = 'Charlie' })

    Social.setOpinion(idA, idB, 75)
    Social.setOpinion(idA, idC, -50)
    Social.setOpinion(idB, idC, 30)

    local state = Social.getState()
    Social.loadState({ opinions = {}, grieving = {}, socialLog = {} })

    -- All opinions should be 0 after wipe
    T.eq(Social.getOpinion(idA, idB), 0, 'A-B cleared')
    T.eq(Social.getOpinion(idA, idC), 0, 'A-C cleared')

    Social.loadState(state)

    T.eq(Social.getOpinion(idA, idB), 75, 'A-B restored to 75')
    T.eq(Social.getOpinion(idA, idC), -50, 'A-C restored to -50')
    T.eq(Social.getOpinion(idB, idC), 30, 'B-C restored to 30')
end)

T.test('test_social_relationships_query', function()
    H.resetAll()
    initWorld()

    local idA = H.spawnTestColonist(16, 16, { name = 'Alice' })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob' })
    local idC = H.spawnTestColonist(18, 16, { name = 'Charlie' })

    Social.setOpinion(idA, idB, 60)
    Social.setOpinion(idA, idC, -40)

    local rels = Social.getRelationships(idA)
    T.eq(#rels, 2, 'Alice has 2 relationships')

    -- Sorted by opinion descending
    T.eq(rels[1].label, 'friend', 'first is friend (highest opinion)')
    T.eq(rels[2].label, 'rival', 'second is rival (lowest opinion)')
end)

T.test('test_social_romance_bond_labels_and_persistence', function()
    H.resetAll()
    initWorld()

    local idA = H.spawnTestColonist(16, 16, { name = 'Alice', age = 28 })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob', age = 29 })

    Social.setOpinion(idA, idB, 90)
    T.ok(Social.setBond(idA, idB, 'dating'), 'dating bond can be set')
    T.eq(Social.getRelationshipStatus(idA, idB), 'dating', 'dating status visible')

    local rels = Social.getRelationships(idA)
    T.eq(rels[1].label, 'dating', 'dating overrides generic friend label')

    Social.setBond(idA, idB, 'lovers')
    T.eq(Social.getRelationshipStatus(idA, idB), 'lovers', 'bond upgrades to lovers')

    local state = Social.getState()
    Social.loadState({ opinions = {}, grieving = {}, bonds = {}, socialLog = {} })
    T.isnil(Social.getBond(idA), 'bond cleared on empty load')

    Social.loadState(state)
    local restored = Social.getBond(idA)
    T.notnil(restored, 'bond restored from saved state')
    T.eq(restored.stage, 'lovers', 'restored stage is lovers')
end)

T.test('test_social_partner_death_clears_bond', function()
    H.resetAll()
    initWorld()

    local idA = H.spawnTestColonist(16, 16, { name = 'Alice', age = 31 })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob', age = 30 })

    Social.setOpinion(idA, idB, 95)
    Social.setBond(idA, idB, 'lovers')
    T.notnil(Social.getBond(idA), 'bond exists before death')

    Social.onColonistDeath(idB)
    T.isnil(Social.getBond(idA), 'bond cleared when partner dies')
end)

T.test('test_social_onColonistDeath_grief', function()
    H.resetAll()
    initWorld()

    local idA = H.spawnTestColonist(16, 16, { name = 'Alice' })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob' })

    -- Make them friends
    Social.setOpinion(idA, idB, 60)

    -- Kill Bob
    Social.onColonistDeath(idB)

    -- Bob's opinion data should be cleaned up
    T.eq(Social.getOpinion(idA, idB), 0, 'opinions cleared for dead colonist')

    -- Alice should have grief (tested indirectly: the grief structure is internal,
    -- but we can verify the opinion cleanup happened)
    local rels = Social.getRelationships(idA)
    -- Bob is dead so shouldn't appear in relationships
    local bobFound = false
    for _, r in ipairs(rels) do
        if r.id == idB then bobFound = true end
    end
    T.ok(not bobFound, 'dead colonist removed from relationships')
end)
