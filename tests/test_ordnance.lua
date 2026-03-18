local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Combat: Ordnance')

local function reloadModule(name)
    package.loaded[name] = nil
    return require(name)
end

T.test('nuclear detonation seeds fallout that contributes to radiation dose', function()
    H.resetAll()

    local World = require('src.world.tilemap')
    World.init(24, 24)

    local Ordnance = reloadModule('src.combat.ordnance')
    local Radiation = reloadModule('src.sim.radiation')

    Ordnance.init()
    Ordnance.detonate(12, 12, 'briefcase_nuke', 0)

    T.ok(next(Ordnance.getFalloutZones()) ~= nil, 'fallout zones seeded')
    T.gt(Ordnance.getFalloutDoseRate(12, 12, 0), 0, 'impact tile has fallout dose')
    T.gt(Radiation.getDoseRate(12, 12, 0), 0, 'radiation system includes fallout dose')
end)

T.test('napalm fields keep burning occupants after detonation', function()
    H.resetAll()

    local World = require('src.world.tilemap')
    local ECS = require('src.ecs.ecs')
    World.init(20, 20)

    local Ordnance = reloadModule('src.combat.ordnance')
    Ordnance.init()

    local colonistId = H.spawnTestColonist(10, 10)
    Ordnance.spawnNapalmField(10, 10, 0, 0, 12, 1.2)
    Ordnance.step(0.5)

    local se = ECS.get(colonistId, 'status_effects')
    T.notnil(se, 'status effects component created')
    T.notnil(se.active.burning, 'burning applied from napalm field')
end)

T.test('bio clouds can infect colonists over time', function()
    H.resetAll()

    local World = require('src.world.tilemap')
    local ECS = require('src.ecs.ecs')
    World.init(20, 20)

    local Ordnance = reloadModule('src.combat.ordnance')
    Ordnance.init()

    local colonistId = H.spawnTestColonist(9, 9)
    Ordnance.spawnBioCloud(9, 9, 0, 0, 10, 'ice_plague', 5.0)
    Ordnance.step(1.0)

    T.ok(ECS.has(colonistId, 'disease'), 'colonist infected by bio cloud')
end)

T.test('gas traps create persistent toxic clouds when triggered', function()
    H.resetAll()

    local World = require('src.world.tilemap')
    local ECS = require('src.ecs.ecs')
    World.init(20, 20)

    local Ordnance = reloadModule('src.combat.ordnance')
    local Traps = reloadModule('src.combat.traps')
    Ordnance.init()

    local trapId = ECS.spawn()
    ECS.set(trapId, 'pos', { x = 8, y = 8, prevX = 8, prevY = 8, depth = 0 })
    ECS.set(trapId, 'trap', { type = 'gas_trap', armed = true, uses = 1 })
    H.spawnTestCreature(8, 8, { hostile = true })

    ECS.update(0.1)

    T.ok(next(Ordnance.getCloudZones()) ~= nil, 'gas trap produced toxic cloud')
end)

T.test('napalm sprayer turrets spawn persistent napalm hazards on hit', function()
    H.resetAll()

    local World = require('src.world.tilemap')
    local ECS = require('src.ecs.ecs')
    World.init(20, 20)

    local Ordnance = reloadModule('src.combat.ordnance')
    local Defenses = reloadModule('src.combat.defenses')
    Ordnance.init()

    local turretId = ECS.spawn()
    ECS.set(turretId, 'pos', { x = 5, y = 5, prevX = 5, prevY = 5, depth = 0 })
    ECS.set(turretId, 'turret', { type = 'napalm_sprayer', powered = true, ammo = 10, cooldown = 0 })
    local towerId = ECS.spawn()
    ECS.set(towerId, 'pos', { x = 5, y = 5, prevX = 5, prevY = 5, depth = 0 })
    ECS.set(towerId, 'watchtower', { sightRange = 8, accuracyBonus = 0.25 })
    H.spawnTestCreature(6, 5, { hostile = true })

    ECS.update(0.5)

    T.ok(next(Ordnance.getNapalmZones()) ~= nil, 'napalm sprayer created hazard zone')
end)

T.test('storms shorten surface hazard lifetimes while underground hazards persist normally', function()
    H.resetAll()

    local World = require('src.world.tilemap')
    local Weather = reloadModule('src.weather.weather')
    local Ordnance = reloadModule('src.combat.ordnance')
    World.init(20, 20)

    local function lifetimeFor(depth, weatherType)
        Ordnance.init()
        Weather.init()
        Weather.force(weatherType, 999)
        if depth == 0 then
            Weather.setWind(0, 1)
        end
        Ordnance.spawnNapalmField(10, 10, depth, 0, 20, 1.0)
        local steps = 0
        while next(Ordnance.getNapalmZones()) ~= nil and steps < 200 do
            steps = steps + 1
            Weather.step(0.5)
            Ordnance.step(0.5)
        end
        return steps * 0.5
    end

    local clearSurface = lifetimeFor(0, 'clear')
    local whiteoutSurface = lifetimeFor(0, 'whiteout')
    local clearUnderground = lifetimeFor(1, 'clear')
    local whiteoutUnderground = lifetimeFor(1, 'whiteout')

    T.lt(whiteoutSurface, clearSurface, 'whiteout burns off surface napalm faster')
    T.near(clearUnderground, whiteoutUnderground, 0.01, 'weather does not change underground napalm lifetime')
end)
