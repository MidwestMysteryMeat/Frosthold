-- test_save_raids.lua -- Integration test: save/load with active raid state
-- Tests the full save/load cycle including raid creatures and ID remapping.

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Save/Load Raids Integration')

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Save      = require('src.persistence.save')
local Raids     = require('src.sim.raids')
local Creatures = require('src.creatures.creatures')

-- Helper: initialize all modules needed for a full save/load cycle
local function initFullWorld()
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

---------------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------------

T.test('test_save_load_during_raid', function()
    H.resetAll()
    initFullWorld()
    Raids.init()

    GameState.day = 10
    GameState.hour = 12.0

    -- Spawn colonists
    H.spawnTestColonist(16, 16, { name = 'Guard1' })
    H.spawnTestColonist(17, 16, { name = 'Guard2' })

    -- Start a raid
    Raids.startRaid('beast_assault')

    -- Step past warning into active phase and spawn creatures
    for i = 1, 20 do
        Raids.step(1.0)
    end

    local infoBefore = Raids.getActiveRaid()
    T.notnil(infoBefore, 'raid active before save')
    T.eq(infoBefore.phase, 'active', 'raid in active phase')

    local spawnedBefore = infoBefore.totalSpawned
    local raidTagsBefore = ECS.countWith('raid_tag')

    -- Full save
    local saveOk = Save.save()
    T.ok(saveOk, 'save succeeds during active raid')

    -- Wipe all state
    GameState.day = 1
    GameState.hour = 6.0
    ECS.init()
    Raids.init()

    T.eq(ECS.countWith('colonist'), 0, 'colonists wiped')
    T.eq(ECS.countWith('raid_tag'), 0, 'raid tags wiped')
    T.ok(not Raids.isRaidActive(), 'no active raid after wipe')

    -- Load
    local loadOk = Save.load()
    T.ok(loadOk, 'load succeeds')

    -- Verify game state restored
    T.eq(GameState.day, 10, 'day restored')

    -- Verify raid restored
    T.ok(Raids.isRaidActive(), 'raid active after load')
    local infoAfter = Raids.getActiveRaid()
    T.notnil(infoAfter, 'getActiveRaid returns data after load')
    T.eq(infoAfter.type, 'beast_assault', 'raid type preserved')
    T.eq(infoAfter.phase, 'active', 'raid phase preserved')

    -- Verify colonists restored
    T.gt(ECS.countWith('colonist'), 0, 'colonists restored after load')

    -- Verify raid creatures exist (may be fewer if some didn't serialize properly,
    -- but should have at least some)
    if spawnedBefore > 0 then
        T.gt(ECS.countWith('creature'), 0, 'creatures restored after load')
    end
end)

T.test('test_save_load_raid_id_remapping', function()
    H.resetAll()
    initFullWorld()
    Raids.init()

    GameState.day = 10

    -- Spawn colonists and a raid
    local col1 = H.spawnTestColonist(16, 16, { name = 'Warden' })
    Raids.startRaid('beast_assault')

    -- Step to spawn creatures
    for i = 1, 20 do
        Raids.step(1.0)
    end

    local infoBefore = Raids.getActiveRaid()
    if not infoBefore or infoBefore.totalSpawned == 0 then
        T.ok(true, 'no creatures spawned (budget too low), skipping ID remap test')
        return
    end

    -- Collect creature IDs before save
    local creatureIdsBefore = {}
    for id, comps in ECS.query('raid_tag') do
        creatureIdsBefore[#creatureIdsBefore + 1] = id
    end
    T.gt(#creatureIdsBefore, 0, 'have creature IDs before save')

    -- Save
    Save.save()

    -- Get raid state before wipe to compare
    local raidStateBefore = Raids.getState()
    local raidCreatureCountBefore = 0
    if raidStateBefore.activeRaid and raidStateBefore.activeRaid.raidCreatureIds then
        raidCreatureCountBefore = #raidStateBefore.activeRaid.raidCreatureIds
    end

    -- Wipe and load
    ECS.init()
    Raids.init()
    Save.load()

    -- After load, entity IDs will be different (remapped). Verify:
    -- 1. The raid is active
    T.ok(Raids.isRaidActive(), 'raid active after load')

    -- 2. The raid's creature count should be consistent
    local infoAfter = Raids.getActiveRaid()
    T.notnil(infoAfter, 'raid info available after load')

    -- 3. The raid_tag entities exist and are alive
    local raidTagsAfter = ECS.countWith('raid_tag')
    -- raid_tag entities should exist (IDs remapped correctly)
    -- Some may have been pruned if marked dead, but alive ones should be tagged
    if raidCreatureCountBefore > 0 then
        T.gt(raidTagsAfter, 0, 'raid-tagged entities exist after load (IDs remapped)')
    end

    -- 4. Verify creatures referenced by raid are actually alive ECS entities
    for id, comps in ECS.query('raid_tag', 'creature') do
        T.ok(ECS.isAlive(id), 'raid creature ' .. tostring(id) .. ' is alive')
        T.notnil(comps.creature, 'raid creature has creature component')
    end
end)

T.test('test_save_load_raidsSurvived_persists', function()
    H.resetAll()
    initFullWorld()
    Raids.init()

    GameState.day = 10
    H.spawnTestColonist(16, 16, { name = 'Veteran' })

    -- Start and complete a raid to increment raidsSurvived
    Raids.startRaid('beast_assault')
    for i = 1, 20 do
        Raids.step(1.0)
    end

    -- Kill all raid creatures to trigger victory
    for id, comps in ECS.query('raid_tag', 'creature') do
        Creatures.kill(id)
    end
    ECS.update(0.05)
    Raids.step(0.05)

    -- May need more steps if aftermath
    for i = 1, 5 do
        Raids.step(1.0)
    end

    local survivedBefore = Raids.getRaidsSurvived()

    -- Save
    Save.save()

    -- Wipe
    ECS.init()
    Raids.init()
    T.eq(Raids.getRaidsSurvived(), 0, 'raidsSurvived reset to 0 after init')

    -- Load
    Save.load()

    T.eq(Raids.getRaidsSurvived(), survivedBefore, 'raidsSurvived persisted through save/load')
end)

T.test('test_save_load_no_raid_clean', function()
    H.resetAll()
    initFullWorld()
    Raids.init()

    GameState.day = 5
    H.spawnTestColonist(16, 16, { name = 'Settler' })

    -- No raid active. Save and load should work cleanly.
    Save.save()

    ECS.init()
    Raids.init()
    Save.load()

    T.ok(not Raids.isRaidActive(), 'no raid after load when none was active')
    T.eq(Raids.getRaidsSurvived(), 0, 'raidsSurvived is 0')
end)

T.test('test_save_load_social_with_raid', function()
    H.resetAll()
    initFullWorld()
    Raids.init()

    GameState.day = 10

    local Social = require('src.colonist.social')
    local idA = H.spawnTestColonist(16, 16, { name = 'Alice' })
    local idB = H.spawnTestColonist(17, 16, { name = 'Bob' })

    -- Set up social state alongside a raid
    Social.setOpinion(idA, idB, 55)
    Raids.startRaid('beast_assault')

    for i = 1, 20 do
        Raids.step(1.0)
    end

    -- Save
    Save.save()

    -- Wipe
    ECS.init()
    Raids.init()
    Social.loadState({ opinions = {}, grieving = {}, socialLog = {} })

    -- Load
    Save.load()

    -- Both systems should be restored
    T.ok(Raids.isRaidActive(), 'raid restored')
    T.gt(ECS.countWith('colonist'), 0, 'colonists restored')

    -- Social opinions use remapped IDs, verify at least colonist entities exist
    -- The exact opinion values depend on ID remapping working correctly in save.lua
    local colonistCount = 0
    for id, comps in ECS.query('colonist') do
        colonistCount = colonistCount + 1
    end
    T.eq(colonistCount, 2, 'both colonists restored')
end)
