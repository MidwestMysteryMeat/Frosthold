-- test_creatures.lua — Creature system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Creatures')

local Creatures = require('src.creatures.creatures')
local ECS       = require('src.ecs.ecs')

T.test('SPECIES table has expected species', function()
    local expected = {
        'frost_hare', 'ice_fox', 'snow_grouse',
        'tundra_wolf', 'glacier_bear', 'ice_stalker',
        'frost_titan', 'thermal_wurm', 'glacial_leviathan',
    }
    for _, key in ipairs(expected) do
        T.notnil(Creatures.SPECIES[key], 'missing species: ' .. key)
    end
end)

T.test('each species has required fields', function()
    local requiredFields = { 'name', 'tier', 'health', 'damage', 'thermalCore', 'meat', 'hostile', 'color', 'size' }
    for key, sp in pairs(Creatures.SPECIES) do
        for _, field in ipairs(requiredFields) do
            T.notnil(sp[field], key .. ' missing field: ' .. field)
        end
    end
end)

T.test('species tiers are valid', function()
    local validTiers = { small = true, medium = true, megafauna = true, eldritch_livestock = true, eldritch = true, swarm = true }
    for key, sp in pairs(Creatures.SPECIES) do
        T.ok(validTiers[sp.tier], key .. ' has invalid tier: ' .. tostring(sp.tier))
    end
end)

T.test('spawn creates entity with correct components', function()
    H.resetAll()
    local id = Creatures.spawn('frost_hare', 10, 20)
    T.notnil(id, 'spawn returned an id')
    T.ok(ECS.has(id, 'pos'), 'entity has pos')
    T.ok(ECS.has(id, 'creature'), 'entity has creature')
    T.ok(ECS.has(id, 'path'), 'entity has path')

    local pos = ECS.get(id, 'pos')
    T.eq(pos.x, 10, 'pos.x')
    T.eq(pos.y, 20, 'pos.y')

    local cr = ECS.get(id, 'creature')
    T.eq(cr.species, 'frost_hare', 'species set')
    T.eq(cr.name, 'Frost Hare', 'name from species def')
    T.eq(cr.health, 15, 'health from species def')
    T.eq(cr.state, 'idle', 'initial state is idle')
end)

T.test('spawn returns nil for unknown species', function()
    H.resetAll()
    local id = Creatures.spawn('nonexistent_species', 5, 5)
    T.isnil(id, 'nil for unknown species')
end)

T.test('damageCreature reduces health', function()
    H.resetAll()
    local id = Creatures.spawn('glacier_bear', 10, 10)
    local cr = ECS.get(id, 'creature')
    local startHealth = cr.health

    local killed = Creatures.damageCreature(id, 10)
    T.eq(killed, false, 'not killed yet')
    T.eq(cr.health, startHealth - 10, 'health reduced by damage amount')
end)

T.test('damageCreature kills creature at 0 HP', function()
    H.resetAll()
    local id = Creatures.spawn('frost_hare', 10, 10)
    local cr = ECS.get(id, 'creature')

    local killed = Creatures.damageCreature(id, cr.health)
    T.eq(killed, true, 'creature killed')
end)

T.test('kill drops corpse resources without minting thermal cores', function()
    H.resetAll()
    local GS = require('src.game_state')
    local startCores   = GS.resources.thermalCores or 0
    local startCorpses = GS.resources.corpse_creature or 0

    local id = Creatures.spawn('tundra_wolf', 10, 10)

    Creatures.kill(id)

    T.eq(GS.resources.thermalCores, startCores, 'thermalCores unchanged')
    T.ok(GS.resources.corpse_creature > startCorpses, 'corpse_creature increased')
end)

T.test('explicit special drops still grant thermal cores', function()
    H.resetAll()
    local GS = require('src.game_state')
    local startCores = GS.resources.thermalCores or 0
    local startCorpses = GS.resources.corpse_creature or 0

    local id = Creatures.spawn('glacier_bear', 10, 10)
    local cr = ECS.get(id, 'creature')
    cr.drops = { thermalCore = 7, meat = 20 }

    Creatures.kill(id)

    T.eq(GS.resources.thermalCores, startCores + 7, 'explicit thermal core drops applied')
    T.ok(GS.resources.corpse_creature > startCorpses, 'corpse still produced')
end)

T.test('hostile species have aggroRange and leashRange', function()
    for key, sp in pairs(Creatures.SPECIES) do
        if sp.hostile then
            T.ok(sp.aggroRange and sp.aggroRange > 0, key .. ' hostile but missing aggroRange')
            T.ok(sp.leashRange and sp.leashRange > 0, key .. ' hostile but missing leashRange')
        end
    end
end)
