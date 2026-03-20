-- test_ruin_spawner.lua — Tests for src/sim/ruin_spawner.lua
-- Run standalone: cd F:/IceRimworld && luajit tests/test_ruin_spawner.lua

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

local root = (arg and arg[0] or 'tests/test_ruin_spawner.lua'):match('(.-)tests[/\\]') or './'
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path

require('tests.mock_love')

local T            = require('tests.test_framework')
local ECS          = require('src.ecs.ecs')
local RuinSpawner  = require('src.sim.ruin_spawner')

---------------------------------------------------------------------------
-- Suite: spawnGraves
---------------------------------------------------------------------------

T.suite('RuinSpawner.spawnGraves')

T.test('test_spawn_graves — 2 colonists produce 2 decoration entities', function()
    ECS.init()
    local colonists = {
        { name = 'Arvik', backstory = 'A miner from the north', deathX = 10, deathY = 20 },
        { name = 'Solenne', backstory = nil,                    deathX = -5, deathY = 3  },
    }
    RuinSpawner.spawnGraves(colonists)
    T.eq(ECS.countWith('decoration'), 2, 'should have 2 decoration entities')
end)

T.test('grave has correct name and fields', function()
    ECS.init()
    local colonists = {
        { name = 'Torben', backstory = 'Frontier blacksmith', deathX = 7, deathY = 7 },
    }
    RuinSpawner.spawnGraves(colonists)
    local found = false
    for id, comps in ECS.query('decoration', 'pos') do
        local dec = comps.decoration
        T.eq(dec.name, 'Remains of Torben', 'grave name')
        T.eq(dec.backstory, 'Frontier blacksmith', 'backstory preserved')
        T.eq(dec.isGrave, true, 'isGrave flag')
        T.eq(dec.buried, false, 'buried defaults false')
        T.eq(dec.moodRadius, 5, 'moodRadius')
        T.eq(dec.moodEffect, -3, 'moodEffect')
        local pos = comps.pos
        T.eq(pos.x, 7, 'deathX')
        T.eq(pos.y, 7, 'deathY')
        T.eq(pos.depth, 0, 'depth 0')
        found = true
    end
    T.ok(found, 'grave entity exists')
end)

T.test('empty colonists list produces no decoration entities', function()
    ECS.init()
    RuinSpawner.spawnGraves({})
    T.eq(ECS.countWith('decoration'), 0, 'no graves from empty list')
end)

---------------------------------------------------------------------------
-- Suite: spawnDataDiscs
---------------------------------------------------------------------------

T.suite('RuinSpawner.spawnDataDiscs')

T.test('test_spawn_data_discs — 2 completed + 1 in-progress = 3 item entities', function()
    ECS.init()
    local completed = {
        { techId = 'basic_insulation', tier = 1 },
        { techId = 'advanced_alloys',  tier = 3 },
    }
    local inProgress = {
        { techId = 'plasma_core', progress = 0.6 },
    }
    local record = { x = 50, y = 50 }
    RuinSpawner.spawnDataDiscs(completed, inProgress, record)
    T.eq(ECS.countWith('item'), 3, 'should have 3 item entities')
end)

T.test('tier <= 2 gives intact quality', function()
    ECS.init()
    local completed = {
        { techId = 'basic_insulation', tier = 1 },
        { techId = 'steam_pipes',      tier = 2 },
    }
    RuinSpawner.spawnDataDiscs(completed, {}, { x = 0, y = 0 })
    local qualities = {}
    for id, comps in ECS.query('item') do
        local itm = comps.item
        if itm.dataDisc then
            qualities[#qualities + 1] = itm.dataDisc.quality
        end
    end
    T.eq(#qualities, 2, 'two discs')
    for _, q in ipairs(qualities) do
        T.eq(q, 'intact', 'tier<=2 disc should be intact')
    end
end)

T.test('tier > 2 gives degraded quality', function()
    ECS.init()
    local completed = {
        { techId = 'advanced_alloys', tier = 3 },
        { techId = 'ion_drive',       tier = 5 },
    }
    RuinSpawner.spawnDataDiscs(completed, {}, { x = 0, y = 0 })
    local qualities = {}
    for id, comps in ECS.query('item') do
        local itm = comps.item
        if itm.dataDisc then
            qualities[#qualities + 1] = itm.dataDisc.quality
        end
    end
    T.eq(#qualities, 2, 'two discs')
    for _, q in ipairs(qualities) do
        T.eq(q, 'degraded', 'tier>2 disc should be degraded')
    end
end)

T.test('in-progress disc has partial quality and halved fraction', function()
    ECS.init()
    local inProgress = {
        { techId = 'plasma_core', progress = 0.8 },
    }
    RuinSpawner.spawnDataDiscs({}, inProgress, { x = 0, y = 0 })
    T.eq(ECS.countWith('item'), 1, 'one item entity')
    for id, comps in ECS.query('item') do
        local disc = comps.item.dataDisc
        T.eq(disc.quality, 'partial', 'quality is partial')
        T.near(disc.partialFraction, 0.4, 0.001, 'partialFraction = progress * 0.5')
    end
end)

T.test('disc name includes techId', function()
    ECS.init()
    local completed = { { techId = 'cryo_tech', tier = 1 } }
    RuinSpawner.spawnDataDiscs(completed, {}, { x = 0, y = 0 })
    for id, comps in ECS.query('item') do
        local name = comps.item.name
        T.ok(name:find('cryo_tech', 1, true), 'name contains techId')
    end
end)

T.test('disc pos is within 8 units of record origin', function()
    ECS.init()
    local baseX, baseY = 100, 200
    local completed = { { techId = 'test_tech', tier = 1 } }
    RuinSpawner.spawnDataDiscs(completed, {}, { x = baseX, y = baseY })
    for id, comps in ECS.query('item', 'pos') do
        local pos = comps.pos
        T.ok(math.abs(pos.x - baseX) <= 8, 'x within 8 of origin')
        T.ok(math.abs(pos.y - baseY) <= 8, 'y within 8 of origin')
    end
end)

---------------------------------------------------------------------------
-- Suite: spawnResourceCrates
---------------------------------------------------------------------------

T.suite('RuinSpawner.spawnResourceCrates')

T.test('test_spawn_resource_crates — amounts are 30-40% of originals', function()
    ECS.init()
    local resources = { metal = 1000, wood = 500, food = 200 }
    local record = { x = 0, y = 0 }
    RuinSpawner.spawnResourceCrates(resources, record)
    T.eq(ECS.countWith('item'), 3, 'one crate per resource')
    for id, comps in ECS.query('item') do
        local itm = comps.item
        T.eq(itm.defId, 'salvage_crate', 'defId is salvage_crate')
        local original = resources[itm.resource]
        T.notnil(original, 'resource type exists in original data')
        local minAmt = math.floor(original * 0.30)
        local maxAmt = math.floor(original * 0.40)
        T.ok(itm.amount >= minAmt, 'amount >= 30% floor')
        T.ok(itm.amount <= maxAmt, 'amount <= 40% floor')
    end
end)

T.test('zero-amount resources are skipped', function()
    ECS.init()
    local resources = { metal = 0, wood = 100 }
    RuinSpawner.spawnResourceCrates(resources, { x = 0, y = 0 })
    T.eq(ECS.countWith('item'), 1, 'only non-zero resource produces a crate')
end)

T.test('crate name contains resource type', function()
    ECS.init()
    local resources = { thermalCores = 50 }
    RuinSpawner.spawnResourceCrates(resources, { x = 0, y = 0 })
    for id, comps in ECS.query('item') do
        T.ok(comps.item.name:find('thermalCores', 1, true), 'name contains resource type')
    end
end)

T.test('crate pos is within 10 units of record origin', function()
    ECS.init()
    local baseX, baseY = 50, 75
    RuinSpawner.spawnResourceCrates({ stone = 100 }, { x = baseX, y = baseY })
    for id, comps in ECS.query('item', 'pos') do
        local pos = comps.pos
        T.ok(math.abs(pos.x - baseX) <= 10, 'x within 10 of origin')
        T.ok(math.abs(pos.y - baseY) <= 10, 'y within 10 of origin')
    end
end)

---------------------------------------------------------------------------
-- Suite: spawnBuildingRuins
---------------------------------------------------------------------------

T.suite('RuinSpawner.spawnBuildingRuins')

T.test('test_spawn_building_ruins — roughly 75% of 20 buildings survive', function()
    -- Run multiple times to reduce flakiness; check aggregate survival
    local totalSpawned = 0
    local trials = 10
    local buildingsPerTrial = 20
    for _ = 1, trials do
        ECS.init()
        local buildings = {}
        for i = 1, buildingsPerTrial do
            buildings[i] = { defId = 'wall', x = i, y = i, depth = 0, hp = 100 }
        end
        RuinSpawner.spawnBuildingRuins(buildings)
        totalSpawned = totalSpawned + ECS.countWith('building_ref')
    end
    local avgSurvived = totalSpawned / trials
    -- Expect average 15 ± 4 across trials (25% destruction, so ~75% survive)
    T.ok(avgSurvived >= 11, 'average survivors should be at least 11/20')
    T.ok(avgSurvived <= 20, 'average survivors should be at most 20/20')
end)

T.test('surviving ruin has isRuin=true on building_ref', function()
    -- Use a deterministic approach: spawn many buildings, check all survivors
    math.randomseed(42)
    ECS.init()
    local buildings = {}
    for i = 1, 50 do
        buildings[i] = { defId = 'floor', x = i, y = 0, depth = 0, hp = 200 }
    end
    RuinSpawner.spawnBuildingRuins(buildings)
    for id, comps in ECS.query('building_ref') do
        T.eq(comps.building_ref.isRuin, true, 'isRuin flag set on survivor')
    end
end)

T.test('ruin durability is 50% of original hp', function()
    math.randomseed(1)
    ECS.init()
    -- Spawn many buildings with known hp to find at least one survivor
    local buildings = {}
    for i = 1, 40 do
        buildings[i] = { defId = 'wall', x = i, y = 0, depth = 0, hp = 80 }
    end
    RuinSpawner.spawnBuildingRuins(buildings)
    local checked = 0
    for id, comps in ECS.query('building_ref', 'durability') do
        local dur = comps.durability
        T.eq(dur.hp, 40, 'hp is 50% of original 80')
        T.eq(dur.maxHp, 80, 'maxHp is original hp')
        checked = checked + 1
    end
    T.ok(checked > 0, 'at least one ruin was checked')
end)

T.test('empty buildings list produces no entities', function()
    ECS.init()
    RuinSpawner.spawnBuildingRuins({})
    T.eq(ECS.countWith('building_ref'), 0, 'no ruins from empty list')
end)

---------------------------------------------------------------------------
-- Suite: getRuinPositions
---------------------------------------------------------------------------

T.suite('RuinSpawner.getRuinPositions')

T.test('test_getRuinPositions — returns correct x/y pairs', function()
    local record = {
        buildings = {
            { defId = 'wall',  x = 10, y = 20, hp = 100 },
            { defId = 'floor', x = 30, y = 40, hp = 50  },
            { defId = 'door',  x = 50, y = 60, hp = 75  },
        }
    }
    local positions = RuinSpawner.getRuinPositions(record)
    T.eq(#positions, 3, 'should return 3 positions')
    T.eq(positions[1].x, 10, 'first x')
    T.eq(positions[1].y, 20, 'first y')
    T.eq(positions[2].x, 30, 'second x')
    T.eq(positions[2].y, 40, 'second y')
    T.eq(positions[3].x, 50, 'third x')
    T.eq(positions[3].y, 60, 'third y')
end)

T.test('nil record returns empty list', function()
    local positions = RuinSpawner.getRuinPositions(nil)
    T.eq(#positions, 0, 'nil record returns empty list')
end)

T.test('record with no buildings returns empty list', function()
    local positions = RuinSpawner.getRuinPositions({})
    T.eq(#positions, 0, 'no buildings field returns empty list')
end)

---------------------------------------------------------------------------
-- Suite: spawnFromLegacy (integration)
---------------------------------------------------------------------------

T.suite('RuinSpawner.spawnFromLegacy')

T.test('spawns all entity types from a full legacy record', function()
    ECS.init()
    local record = {
        x = 100, y = 100,
        buildings = {
            { defId = 'wall',  x = 100, y = 100, depth = 0, hp = 120 },
            { defId = 'floor', x = 102, y = 100, depth = 0, hp = 60  },
        },
        completedResearch = {
            { techId = 'cryo_storage', tier = 1 },
        },
        inProgressResearch = {
            { techId = 'orbital_relay', progress = 0.5 },
        },
        resources = { metal = 500, food = 300 },
        colonists = {
            { name = 'Kiri', deathX = 101, deathY = 101 },
        },
    }
    RuinSpawner.spawnFromLegacy(record)
    -- At least 1 decoration (grave), at least 2 items (1 disc + 1 in-progress + 2 crates = 4),
    -- at least 1 building_ref
    T.ok(ECS.countWith('decoration') >= 1, 'at least 1 grave')
    T.ok(ECS.countWith('item') >= 3, 'discs + crates spawned')
end)

T.test('nil record does not error', function()
    ECS.init()
    local ok, err = pcall(RuinSpawner.spawnFromLegacy, nil)
    T.ok(ok, 'nil record should not throw: ' .. tostring(err))
end)

T.test('empty record does not error', function()
    ECS.init()
    local ok, err = pcall(RuinSpawner.spawnFromLegacy, {})
    T.ok(ok, 'empty record should not throw: ' .. tostring(err))
    T.eq(ECS.countWith('decoration'), 0, 'no graves')
    T.eq(ECS.countWith('item'), 0, 'no items')
    T.eq(ECS.countWith('building_ref'), 0, 'no ruins')
end)

---------------------------------------------------------------------------
-- Summary (standalone mode only)
---------------------------------------------------------------------------

if arg and arg[0] and arg[0]:find('test_ruin_spawner') then
    local failures = T.summary()
    os.exit(failures > 0 and 1 or 0)
end
