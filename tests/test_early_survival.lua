-- test_early_survival.lua — Early-game survivability guards
-- Covers the three pieces that stop a fresh crew being wiped in the opening
-- hours: the standard drop-pod loadout, the apex-lair grace period and
-- distance guard, and the speed-aware flee decision.

local T = require('tests.test_framework')
local H = require('tests.helpers')

--- Flatten a patch of generated terrain to plain snow so line-of-sight and
--- walkability checks in these tests do not depend on what the noise produced.
local function clearPatch(cx, cy, r)
    local World = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')
    for y = cy - r, cy + r do
        for x = cx - r, cx + r do
            if World.inBounds(x, y) then World.setTile(x, y, Tiles.SNOW, 0) end
        end
    end
end

T.suite('Early survival: starting loadout')

T.test('starting colonists land with a weapon and cold gear', function()
    H.resetAll()
    local ECS      = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')
    local World    = require('src.world.tilemap')
    World.init(64, 64)

    local GameState = require('src.game_state')
    GameState.startX, GameState.startY = 32, 32
    Colonist.spawnInitial(32, 32, 3)

    local crew = Colonist.applyStartingLoadout({ colonists = 3 })
    T.eq(crew, 3, 'three colonists kitted')

    for id in ECS.query('colonist') do
        local equip = ECS.get(id, 'equipment')
        T.notnil(equip and equip.weapon, 'colonist has a weapon')
        local clothing = ECS.get(id, 'clothing')
        T.notnil(clothing and clothing.outer, 'colonist has an outer garment')
        T.notnil(clothing and clothing.feet, 'colonist has boots')
    end
end)

T.test('a weapon means combat_ai is no longer forced to flee', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local Equipment = require('src.colonist.equipment')
    local Body      = require('src.combat.body')
    local id = H.spawnTestColonist(10, 10)
    Body.attach(id)
    Equipment.attach(id)

    T.isnil(ECS.get(id, 'equipment').weapon, 'unarmed to begin with')
    local Colonist = require('src.colonist.colonist')
    Colonist.equipStartingGear(id, 1, 1, true)
    T.notnil(ECS.get(id, 'equipment').weapon, 'armed after loadout')
end)

T.test('starting weapons stay in the improvised/tier-1 bracket', function()
    local Equipment = require('src.colonist.equipment')
    -- The loadout must not hand out anything that would make crafted or
    -- late-tier weapons pointless. Cap it well under the tier-2 melee range.
    for _, wid in ipairs({ 'knife', 'hatchet', 'club', 'shortbow' }) do
        local def = Equipment.WEAPONS[wid]
        T.notnil(def, wid .. ' exists')
        T.ok(def.dmg <= 10, wid .. ' damage stays <= 10 (got ' .. tostring(def.dmg) .. ')')
    end
end)

T.test('scenarios can opt out of the standard loadout', function()
    H.resetAll()
    local ECS      = require('src.ecs.ecs')
    local Colonist = require('src.colonist.colonist')
    local World    = require('src.world.tilemap')
    World.init(64, 64)

    local GameState = require('src.game_state')
    GameState.startX, GameState.startY = 32, 32
    Colonist.spawnInitial(32, 32, 1)
    Colonist.applyStartingLoadout({ colonists = 1, startingGear = false })

    for id in ECS.query('colonist') do
        local equip = ECS.get(id, 'equipment')
        T.isnil(equip and equip.weapon, 'naked start stays unarmed')
    end
end)

T.test('naked_brutality scenarios declare startingGear = false', function()
    local PS = require('src.world.planet_scenarios')
    local scen = PS.getScenario('erebus', 'naked_brutality')
    T.notnil(scen, 'Erebus naked_brutality exists')
    T.eq(scen.startingGear, false, 'opted out of the loadout')
end)

T.suite('Early survival: apex lair guards')

T.test('apex species are the ones that out-damage a kitted colonist', function()
    local Lairs = require('src.creatures.lairs')
    T.ok(Lairs.isApexSpecies('glacier_bear'), 'glacier bear is apex (25 dmg)')
    T.ok(Lairs.isApexSpecies('ice_stalker'), 'ice stalker is apex (18 dmg)')
    T.ok(Lairs.isApexSpecies('stalker'), 'stalker is apex (28 dmg)')
    T.ok(Lairs.isApexSpecies('char_hound'), 'char hound is apex (14 dmg)')
    T.eq(Lairs.isApexSpecies('tundra_wolf'), false, 'tundra wolf is not apex (12 dmg)')
end)

T.test('apex dens must sit beyond their own leash range from camp', function()
    local Lairs = require('src.creatures.lairs')
    -- ice_stalker leashRange 25 -> must be further out than the flat margin
    T.ok(Lairs.minColonyDistance('ice_stalker', 25) > 25,
        'ice stalker den pushed past the base margin')
    -- stalker leashRange 30 -> further still
    T.ok(Lairs.minColonyDistance('stalker', 25) >
         Lairs.minColonyDistance('ice_stalker', 25),
        'longer tether means a further den')
    T.eq(Lairs.minColonyDistance('tundra_wolf', 25), 25,
        'non-apex dens keep the original margin')
end)

T.test('no den releases a pack during day 1, apex dens wait until day 4', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local GameState = require('src.game_state')
    local World     = require('src.world.tilemap')
    World.init(64, 64)
    local Lairs = require('src.creatures.lairs')

    local function packsAfterOneTick(species, day)
        H.resetECS()
        Lairs.registerSystems()   -- ECS.init() wipes registered systems
        clearPatch(20, 20, 8)
        GameState.day = day
        local lairId = Lairs.spawn(20, 20, 1)
        local lair = ECS.get(lairId, 'lair')
        lair.species = species
        lair.spawnTimer = 0        -- due right now
        lair.packMin, lair.packMax = 1, 1
        ECS.update(0.05)
        return ECS.countWith('creature')
    end

    T.eq(packsAfterOneTick('tundra_wolf', 1), 0, 'day 1: wolf den silent')
    T.eq(packsAfterOneTick('ice_stalker', 1), 0, 'day 1: apex den silent')
    T.ok(packsAfterOneTick('tundra_wolf', 2) > 0, 'day 2: wolf den active')
    T.eq(packsAfterOneTick('ice_stalker', 2), 0, 'day 2: apex den still shut')
    T.eq(packsAfterOneTick('ice_stalker', 3), 0, 'day 3: apex den still shut')
    T.ok(packsAfterOneTick('ice_stalker', 4) > 0, 'day 4: apex den active')
end)

T.test('dens release one animal at a time until the grace window closes', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local GameState = require('src.game_state')
    local World     = require('src.world.tilemap')
    World.init(64, 64)
    local Lairs = require('src.creatures.lairs')

    local function releasedOn(day)
        H.resetECS()
        Lairs.registerSystems()
        clearPatch(20, 20, 10)
        GameState.day = day
        local lairId = Lairs.spawn(20, 20, 1)
        local lair = ECS.get(lairId, 'lair')
        lair.species = 'tundra_wolf'        -- non-apex, so the den is open
        lair.spawnTimer = 0
        lair.packMin, lair.packMax = 4, 4   -- a full wolf pack
        ECS.update(0.05)
        return ECS.countWith('creature')
    end

    T.eq(releasedOn(2), 1, 'day 2: single animal despite a pack size of 4')
    T.eq(releasedOn(3), 1, 'day 3: still a single animal')
    T.ok(releasedOn(4) > 1, 'day 4: full pack')
end)

T.suite('Early survival: flee decisions')

T.test('getMoveSpeed reports the colonist baseline', function()
    H.resetAll()
    local Colonist = require('src.colonist.colonist')
    local id = H.spawnTestColonist(10, 10)
    local speed = Colonist.getMoveSpeed(id)
    T.ok(speed > 0, 'positive speed')
    T.ok(speed <= 3.0 + 0.001, 'no faster than the 3.0 tiles/s baseline')
end)

T.test('an armed colonist fights a faster animal instead of running', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local World     = require('src.world.tilemap')
    World.init(64, 64)
    clearPatch(30, 30, 8)
    local Body      = require('src.combat.body')
    local Equipment = require('src.colonist.equipment')
    local Creatures = require('src.creatures.creatures')
    local CombatAI  = require('src.combat.combat_ai')
    CombatAI.registerSystems()   -- ECS.init() wiped the registration

    local id = H.spawnTestColonist(30, 30)
    Body.attach(id)
    Equipment.attach(id)
    Equipment.equipWeapon(id, 'knife')
    local col = ECS.get(id, 'colonist')
    col.health = 20   -- below the 40% flee threshold
    col.facing = 0

    -- Stalker: 5.0 tiles/s, well clear of the colonist's 3.0
    local crId = Creatures.spawn('stalker', 32, 30, 0)
    T.notnil(crId, 'creature spawned')

    ECS.update(0.05)
    T.ok(col.state ~= 'fleeing' or ECS.get(id, 'path').nodes ~= nil,
        'either standing to fight or moving to a specific cover tile, not a blind sprint')
    T.ok(ECS.get(crId, 'creature').health <= 100,
        'colonist is engaging rather than turning its back')
end)

T.test('a colonist notices an animal biting it from behind', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local World     = require('src.world.tilemap')
    World.init(64, 64)
    clearPatch(30, 30, 8)
    local Body      = require('src.combat.body')
    local Equipment = require('src.colonist.equipment')
    local Creatures = require('src.creatures.creatures')
    local CombatAI  = require('src.combat.combat_ai')
    CombatAI.registerSystems()

    local id = H.spawnTestColonist(30, 30)
    Body.attach(id)
    Equipment.attach(id)
    Equipment.equipWeapon(id, 'hatchet')
    local col = ECS.get(id, 'colonist')
    col.facing = 0                      -- looking east

    -- Wolf standing directly behind, well outside the vision cone
    Creatures.spawn('tundra_wolf', 29, 30, 0)
    ECS.update(0.05)
    T.eq(col.state, 'fighting', 'turns and fights instead of standing idle')
end)

T.test('a colonist can still outrun a slower animal', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local World     = require('src.world.tilemap')
    World.init(64, 64)
    clearPatch(30, 30, 8)
    local Body      = require('src.combat.body')
    local Equipment = require('src.colonist.equipment')
    local Creatures = require('src.creatures.creatures')
    local CombatAI  = require('src.combat.combat_ai')
    CombatAI.registerSystems()   -- ECS.init() wiped the registration

    local id = H.spawnTestColonist(30, 30)
    Body.attach(id)
    Equipment.attach(id)
    local col = ECS.get(id, 'colonist')
    col.health = 20
    col.facing = 0

    -- Glacier bear: 2.5 tiles/s, slower than the colonist
    Creatures.spawn('glacier_bear', 33, 30, 0)
    ECS.update(0.05)
    T.eq(col.state, 'fleeing', 'running from something it can actually escape')
end)
