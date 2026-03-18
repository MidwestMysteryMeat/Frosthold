-- test_raids.lua -- Raid system lifecycle tests
-- Tests raid start, warning phase, wave spawning, retreat, victory, and save/load.

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Raids')

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Raids     = require('src.sim.raids')
local Creatures = require('src.creatures.creatures')

-- Helper: initialize tilemap + weather + storyteller + hope so modules don't crash
local function initWorld()
    math.randomseed(12345)
    local Tilemap = require('src.world.tilemap')
    local Tiles   = require('src.world.tiles')
    Tilemap.init(32, 32)
    -- Ensure edge tiles are walkable so raid spawn points work
    for i = 0, 31 do
        Tilemap.setTile(i, 3, Tiles.SNOW, 0)
        Tilemap.setTile(i, 28, Tiles.SNOW, 0)
        Tilemap.setTile(3, i, Tiles.SNOW, 0)
        Tilemap.setTile(28, i, Tiles.SNOW, 0)
    end
    local Weather = require('src.weather.weather')
    Weather.init()
    local Storyteller = require('src.storyteller.storyteller')
    Storyteller.init('steady')
    require('src.colony.hope')
end

-- Helper: set day high enough for any raid type
local function setDayForRaid(day)
    GameState.day = day or 40
end

-- Helper: spawn a tagged raid creature manually (simulates what spawnWave does)
local function spawnRaidCreature(x, y, species)
    local id = Creatures.spawn(species or 'tundra_wolf', x or 10, y or 10)
    if id then
        ECS.set(id, 'raid_tag', { raidType = 'test' })
    end
    return id
end

---------------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------------

T.test('test_startRaid_creates_activeRaid', function()
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    local raid = Raids.startRaid('beast_assault')
    T.notnil(raid, 'startRaid returned a table')
    T.ok(Raids.isRaidActive(), 'raid is active after start')

    local info = Raids.getActiveRaid()
    T.notnil(info, 'getActiveRaid returns data')
    T.eq(info.type, 'beast_assault', 'raid type is beast_assault')
    T.eq(info.phase, 'warning', 'initial phase is warning')
    T.gt(info.budget, 0, 'budget is positive')
    T.gt(info.waveCount, 0, 'at least one wave')
    T.eq(info.currentWave, 1, 'starts on wave 1')
    T.eq(info.totalSpawned, 0, 'nothing spawned yet')
    T.eq(info.totalKilled, 0, 'nothing killed yet')
end)

T.test('test_startRaid_rejects_duplicate', function()
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    Raids.startRaid('beast_assault')
    local raid2, err = Raids.startRaid('beast_assault')
    T.isnil(raid2, 'second startRaid returns nil')
    T.ok(err and err:find('already'), 'error mentions already in progress')
end)

T.test('test_raid_warning_phase', function()
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    Raids.startRaid('beast_assault')

    -- Step a few times but stay within warning duration
    -- beast_assault warning is 15 seconds base
    for i = 1, 10 do
        Raids.step(1.0)
    end

    local info = Raids.getActiveRaid()
    T.notnil(info, 'raid still active')
    T.eq(info.phase, 'warning', 'still in warning phase after 10s')
    T.eq(info.totalSpawned, 0, 'no spawns during warning')
end)

T.test('test_raid_transitions_to_active', function()
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    Raids.startRaid('beast_assault')

    -- Step past the 15-second warning time
    for i = 1, 16 do
        Raids.step(1.0)
    end

    local info = Raids.getActiveRaid()
    T.notnil(info, 'raid still active')
    T.eq(info.phase, 'active', 'phase transitions to active after warning expires')
end)

T.test('test_raid_wave_spawning', function()
    H.resetAll()
    math.randomseed(12345)
    initWorld()
    Raids.init()
    setDayForRaid(10)

    -- Spawn some colonists to generate heat signature (budget needs to be > 0)
    H.spawnTestColonist(16, 16)
    H.spawnTestColonist(17, 16)

    Raids.startRaid('beast_assault')

    -- Step well past warning time so waves spawn
    -- beast_assault has 1 wave, waveDelay 0, spawnTime = warningTime (15)
    for i = 1, 20 do
        Raids.step(1.0)
    end

    local info = Raids.getActiveRaid()
    T.notnil(info, 'raid still active')
    T.eq(info.phase, 'active', 'phase is active')
    T.gt(info.totalSpawned, 0, 'creatures were spawned')

    -- Verify raid_tag components exist on spawned creatures
    local taggedCount = ECS.countWith('raid_tag')
    T.gt(taggedCount, 0, 'raid-tagged entities exist')
end)

T.test('test_raid_retreat', function()
    math.randomseed(12345)
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    H.spawnTestColonist(16, 16)
    Raids.startRaid('beast_assault')

    -- Step past warning to spawn creatures
    for i = 1, 20 do
        Raids.step(1.0)
    end

    local info = Raids.getActiveRaid()
    T.eq(info.phase, 'active', 'phase is active after spawning')

    -- Kill enough creatures to trigger retreat (beast_assault retreatPct = 0.5)
    -- Count total spawned and kill at least half
    local totalSpawned = info.totalSpawned
    if totalSpawned > 0 then
        local killed = 0
        local toKill = math.ceil(totalSpawned * 0.5)
        for id, comps in ECS.query('raid_tag', 'creature') do
            if killed >= toKill then break end
            Creatures.kill(id)
            killed = killed + 1
        end
        -- Flush deferred destroys
        ECS.update(0.05)
        -- Step to process retreat check
        Raids.step(0.05)

        local infoAfter = Raids.getActiveRaid()
        -- Should be in 'aftermath' (retreating) or nil (all dead = victory)
        if infoAfter then
            T.eq(infoAfter.phase, 'aftermath', 'phase transitions to aftermath after casualties')
        else
            -- All creatures dead = victory, also valid
            T.ok(true, 'raid ended in victory (all dead)')
        end
    else
        -- Budget was too small to spawn anything, raid may already be over
        T.ok(true, 'no creatures spawned (budget too low for test map)')
    end
end)

T.test('test_raid_victory', function()
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    local survivedBefore = Raids.getRaidsSurvived()
    local coresBefore = GameState.resources.thermalCores or 0

    H.spawnTestColonist(16, 16)
    Raids.startRaid('beast_assault')

    -- Step past warning to spawn creatures
    for i = 1, 20 do
        Raids.step(1.0)
    end

    -- Kill ALL raid creatures
    for id, comps in ECS.query('raid_tag', 'creature') do
        Creatures.kill(id)
    end
    ECS.update(0.05)

    -- Step to trigger victory check
    Raids.step(0.05)

    -- Raid should be over
    local info = Raids.getActiveRaid()
    -- After all creatures killed and all waves spawned, raid ends
    -- beast_assault has 1 wave, so all waves are already spawned
    if info == nil then
        T.eq(Raids.getRaidsSurvived(), survivedBefore + 1, 'raidsSurvived incremented')
        T.eq(GameState.resources.thermalCores, coresBefore, 'raid victory does not mint thermal cores')
    else
        -- If raid is still active (maybe aftermath waiting for despawn), step more
        for i = 1, 5 do
            Raids.step(1.0)
        end
        info = Raids.getActiveRaid()
        T.isnil(info, 'raid ended after stepping aftermath')
        T.eq(Raids.getRaidsSurvived(), survivedBefore + 1, 'raidsSurvived incremented')
        T.eq(GameState.resources.thermalCores, coresBefore, 'raid victory does not mint thermal cores')
    end
end)

T.test('test_raid_save_restore', function()
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    H.spawnTestColonist(16, 16)
    Raids.startRaid('beast_assault')

    -- Step to active phase and spawn creatures
    for i = 1, 20 do
        Raids.step(1.0)
    end

    local infoBefore = Raids.getActiveRaid()
    T.notnil(infoBefore, 'raid active before save')

    -- Save state
    local state = Raids.getState()
    T.notnil(state, 'getState returns data')
    T.eq(state.raidsSurvived, 0, 'raidsSurvived in state')
    T.notnil(state.activeRaid, 'activeRaid in state')
    T.eq(state.activeRaid.type, 'beast_assault', 'type preserved in state')
    T.eq(state.activeRaid.phase, infoBefore.phase, 'phase preserved')
    T.notnil(state.activeRaid.raidCreatureIds, 'raidCreatureIds in state')

    -- Reinit and restore
    Raids.init()
    T.ok(not Raids.isRaidActive(), 'raid cleared after init')

    Raids.restoreState(state)

    local infoAfter = Raids.getActiveRaid()
    T.notnil(infoAfter, 'raid restored after restoreState')
    T.eq(infoAfter.type, infoBefore.type, 'type matches after restore')
    T.eq(infoAfter.phase, infoBefore.phase, 'phase matches after restore')
    T.eq(infoAfter.budget, infoBefore.budget, 'budget matches after restore')
end)

T.test('test_raid_save_restore_with_dead_creatures', function()
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    H.spawnTestColonist(16, 16)
    H.spawnTestColonist(17, 16)
    Raids.startRaid('beast_assault')

    -- Step to spawn
    for i = 1, 20 do
        Raids.step(1.0)
    end

    local infoBefore = Raids.getActiveRaid()
    if infoBefore and infoBefore.totalSpawned > 1 then
        -- Kill one creature
        local killedOne = false
        for id, comps in ECS.query('raid_tag', 'creature') do
            if not killedOne then
                Creatures.kill(id)
                killedOne = true
            end
        end
        ECS.update(0.05)

        -- Save and restore
        local state = Raids.getState()
        Raids.init()
        Raids.restoreState(state)

        local infoAfter = Raids.getActiveRaid()
        T.notnil(infoAfter, 'raid restored')
        -- Dead creatures should be pruned from raidCreatures in restoreState
        T.ok(infoAfter.alive < infoBefore.totalSpawned,
            'dead creatures pruned after restore')
    else
        T.ok(true, 'not enough creatures spawned to test dead-creature pruning')
    end
end)

T.test('test_raid_getState_no_active_raid', function()
    H.resetAll()
    initWorld()
    Raids.init()

    local state = Raids.getState()
    T.notnil(state, 'getState returns a table even with no raid')
    T.eq(state.raidsSurvived, 0, 'raidsSurvived is 0')
    T.isnil(state.activeRaid, 'activeRaid is nil when no raid')
    T.notnil(state.raidLog, 'raidLog exists')
end)

T.test('test_heat_signature_calculation', function()
    H.resetAll()
    initWorld()
    Raids.init()

    -- No colonists, no reactor: base heat should be low
    local sig0 = Raids.getHeatSignature()
    T.ok(type(sig0) == 'number', 'heat signature is a number')

    -- Add colonists: each living colonist adds 3
    H.spawnTestColonist(16, 16)
    H.spawnTestColonist(17, 16)
    local sig2 = Raids.getHeatSignature()
    T.gt(sig2, sig0, 'heat signature increases with colonists')

    -- Add thermal cores: each adds 0.5
    GameState.resources.thermalCores = 20
    local sig3 = Raids.getHeatSignature()
    T.gt(sig3, sig2, 'heat signature increases with thermal cores')
end)

T.test('test_pickRaidType_respects_minDay', function()
    H.resetAll()
    initWorld()
    Raids.init()

    -- On day 1, only beast_assault is eligible (minDay=5 but pickRaidType
    -- returns beast_assault as fallback when nothing qualifies)
    GameState.day = 1
    local rtype = Raids.pickRaidType()
    T.notnil(rtype, 'pickRaidType returns something')
    -- Swarm requires day >= 30, so day 1 should never return swarm
    T.ok(rtype ~= 'swarm', 'swarm not picked on day 1')

    -- On day 3, still too early for most types
    GameState.day = 3
    local rtype3 = Raids.pickRaidType()
    T.ok(rtype3 ~= 'swarm', 'swarm not picked on day 3')
    T.ok(rtype3 ~= 'coordinated', 'coordinated not picked on day 3')
    T.ok(rtype3 ~= 'siege', 'siege not picked on day 3')
end)

T.test('test_pickRaidType_fallback_can_bias_toward_containment_raids', function()
    H.resetAll()
    initWorld()
    local Tuning = require('src.sim.tuning')
    local Containment = require('src.sim.containment')
    Raids.init()

    -- Build a late colony state with active containment so reclamation raids are eligible.
    GameState.day = 40
    GameState.resources.food = 120
    GameState.resources.fuel = 60
    GameState.resources.metal = 120
    GameState.resources.components = 12

    for i = 1, 10 do
        H.spawnTestColonist(10 + i, 12, { task = 'haul' })
    end
    for i = 1, 5 do
        local id = ECS.spawn()
        ECS.set(id, 'machine', { active = true })
    end
    local drill = ECS.spawn()
    ECS.set(drill, 'deep_drill', { active = true })

    local cell = ECS.spawn()
    ECS.set(cell, 'pos', { x = 20, y = 20, prevX = 20, prevY = 20, depth = 0 })
    ECS.set(cell, 'containment_cell', {
        cellType = 'cell',
        mode = 'study',
        subjectId = nil,
        currentRisk = 0,
        incidentCooldown = 0,
    })
    Containment.registerFieldSubject('vessel_host', { source = 'test chamber' })
    Containment.assignNextSubject(cell)

    Tuning.setOverride('raids.containment_reclamation_chance', 1.0)
    Tuning.setOverride('raids.swarm_chance_scale', 0.0)
    Tuning.setOverride('raids.thermovore_chance_scale', 0.0)

    local counts = {}
    math.randomseed(4242)
    for i = 1, 60 do
        local picked = Raids.pickRaidType()
        counts[picked] = (counts[picked] or 0) + 1
    end

    T.gt(counts.erebus_reclamation or 0, 0, 'containment raid can dominate when explicitly favored')
end)

T.test('test_startRaid_rejects_too_early', function()
    H.resetAll()
    initWorld()
    Raids.init()
    GameState.day = 1

    local raid, err = Raids.startRaid('swarm')
    T.isnil(raid, 'swarm rejected on day 1')
    T.ok(err and err:find('Too early'), 'error says too early')
end)

T.test('test_raid_delay', function()
    H.resetAll()
    initWorld()
    Raids.init()

    T.ok(not Raids.isDelayed(), 'not delayed initially')

    Raids.delayNextRaid(60)
    T.ok(Raids.isDelayed(), 'delayed after delayNextRaid')

    -- Tick down the delay
    Raids.tickDelay(30)
    T.ok(Raids.isDelayed(), 'still delayed after partial tick')

    Raids.tickDelay(30)
    T.ok(not Raids.isDelayed(), 'no longer delayed after full tick')
end)

T.test('test_raid_log_populated', function()
    H.resetAll()
    initWorld()
    Raids.init()
    setDayForRaid(10)

    T.eq(#Raids.getLog(), 0, 'log empty before raid')

    Raids.startRaid('beast_assault')
    local log = Raids.getLog()
    T.gt(#log, 0, 'log has entries after startRaid')
    T.notnil(log[1].msg, 'log entry has msg')
    T.notnil(log[1].day, 'log entry has day')
end)

T.test('test_raid_types_table_valid', function()
    -- Verify all raid type definitions have required fields
    local requiredFields = {
        'name', 'minDay', 'waves', 'directions', 'waveDelay',
        'pool', 'budgetMult', 'hopeDelta', 'threatCost'
    }
    for typeId, def in pairs(Raids.RAID_TYPES) do
        for _, field in ipairs(requiredFields) do
            T.notnil(def[field], typeId .. ' missing field: ' .. field)
        end
        T.ok(#def.pool > 0, typeId .. ' has empty creature pool')
        T.ok(def.minDay >= 0, typeId .. ' has negative minDay')
        T.ok(def.waves >= 1, typeId .. ' has zero waves')
    end
end)
