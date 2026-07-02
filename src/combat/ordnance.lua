-- ordnance.lua — Explosive ordnance system
-- Handles placed explosives (timed, tripwire, manual), detonation effects,
-- multi-floor penetration, persistent hazard zones, and missile silo launching.
-- Integrates with fire, disease, radiation, and atmosphere systems.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tuning    = require('src.sim.tuning')

local Ordnance = {}

local function otune(key, fallback)
    return Tuning.get('ordnance.' .. key, fallback)
end

local _VFX
local _FireMod, _StatusFx, _TileGas, _Disease
local function lazyLoadOrdnanceDeps()
    if _VFX == nil then
        local ok, mod = pcall(require, 'src.render.vfx')
        _VFX = ok and mod or false
    end
    if _FireMod == nil then
        local ok, mod = pcall(require, 'src.sim.fire')
        _FireMod = ok and mod or false
    end
    if _StatusFx == nil then
        local ok, mod = pcall(require, 'src.sim.status_effects')
        _StatusFx = ok and mod or false
    end
    if _TileGas == nil then
        local ok, mod = pcall(require, 'src.sim.tile_gas')
        _TileGas = ok and mod or false
    end
    if _Disease == nil then
        local ok, mod = pcall(require, 'src.sim.disease')
        _Disease = ok and mod or false
    end
end
local function getVFX()
    lazyLoadOrdnanceDeps()
    return _VFX or nil
end

---------------------------------------------------------------------------
-- Ordnance type definitions
---------------------------------------------------------------------------

-- Effect types applied on detonation
-- blast: raw damage + terrain destruction
-- napalm: fire spread
-- biological: disease infection
-- foam: fire suppression
-- emp: stun + power disable
-- nuclear: massive blast + fire + multi-floor

Ordnance.TYPES = {
    -- Placed explosives (colonist places at tile)
    placed_charge = {
        name = 'Placed Charge', desc = 'Manually detonated explosive charge. Breaches walls.',
        fuse = 'manual', damage = 80, radius = 3, penetration = 0,
        terrainDamage = true, effect = 'blast',
        cost = { metal_ingot = 3, charcoal = 4 },
    },
    timed_bomb = {
        name = 'Timed Bomb', desc = 'Detonates after a set delay. Good for traps and mining.',
        fuse = 'timed', fuseDelay = 10, damage = 60, radius = 3, penetration = 0,
        terrainDamage = true, effect = 'blast',
        cost = { metal_ingot = 2, charcoal = 3, components = 1 },
    },
    tripwire_bomb = {
        name = 'Tripwire Bomb', desc = 'Detonates when a hostile enters its trigger radius.',
        fuse = 'proximity', triggerRadius = 2, damage = 50, radius = 3, penetration = 0,
        terrainDamage = false, effect = 'blast',
        cost = { metal_ingot = 2, charcoal = 2, cloth = 1 },
    },

    -- C4 (remote detonation, high wall-breach capability)
    c4_charge = {
        name = 'C4 Charge', desc = 'Remote detonated plastic explosive. Excellent for breaching walls and structures.',
        fuse = 'manual', damage = 100, radius = 2, penetration = 1,
        terrainDamage = true, effect = 'blast',
        cost = { metal_ingot = 2, charcoal = 5, components = 2 },
    },

    -- EMP ordnance
    emp_charge = {
        name = 'EMP Charge', desc = 'Electromagnetic pulse device. Stuns creatures and disables power.',
        fuse = 'timed', fuseDelay = 5, damage = 5, radius = 5, penetration = 0,
        terrainDamage = false, effect = 'emp', stun = 6.0,
        cost = { metal_ingot = 3, components = 4, circuit = 2 },
    },
    emp_grenade = {
        name = 'EMP Grenade', desc = 'Throwable electromagnetic pulse. Stuns and disables in a small area.',
        fuse = 'instant', damage = 3, radius = 3, penetration = 0,
        terrainDamage = false, effect = 'emp', stun = 4.0,
        cost = { metal_ingot = 1, components = 2, circuit = 1 },
    },

    -- Briefcase nuke (compact, shorter range, smaller yield than mini nuke)
    briefcase_nuke = {
        name = 'Briefcase Nuke', desc = 'Compact nuclear device. Devastating in a small area. Penetrates one floor.',
        fuse = 'timed', fuseDelay = 15, damage = 150, radius = 6, penetration = 1,
        terrainDamage = true, effect = 'nuclear', fireDuration = 40,
        cost = { metal_ingot = 5, components = 6, nuclear_core = 1 },
    },

    -- Napalm ordnance
    napalm_grenade = {
        name = 'Napalm Grenade', desc = 'Sets a wide area on fire. Short range throw.',
        fuse = 'instant', damage = 15, radius = 3, penetration = 0,
        terrainDamage = false, effect = 'napalm', fireDuration = 20,
        cost = { metal_ingot = 1, charcoal = 4 },
    },
    napalm_bomb = {
        name = 'Napalm Bomb', desc = 'Placed incendiary. Large fire area on detonation.',
        fuse = 'timed', fuseDelay = 8, damage = 20, radius = 5, penetration = 0,
        terrainDamage = false, effect = 'napalm', fireDuration = 30,
        cost = { metal_ingot = 2, charcoal = 7 },
    },

    -- Biological ordnance
    bio_grenade = {
        name = 'Bio Grenade', desc = 'Disperses a pathogen cloud. Infects creatures and colonists.',
        fuse = 'instant', damage = 5, radius = 4, penetration = 0,
        terrainDamage = false, effect = 'biological',
        disease = 'ice_plague', infectionChance = 0.4,
        cost = { glass = 2, medicinal_herb = 3 },
    },
    bio_bomb = {
        name = 'Bio Bomb', desc = 'Large area biological dispersal. Devastating pathogen load.',
        fuse = 'timed', fuseDelay = 12, damage = 10, radius = 6, penetration = 0,
        terrainDamage = false, effect = 'biological',
        disease = 'ice_plague', infectionChance = 0.7,
        cost = { glass = 3, medicinal_herb = 5, components = 2 },
    },

    -- Foam ordnance (defensive)
    foam_grenade = {
        name = 'Foam Grenade', desc = 'Extinguishes fires and coats area in flame-retardant foam.',
        fuse = 'instant', damage = 0, radius = 3, penetration = 0,
        terrainDamage = false, effect = 'foam', foamDuration = 45,
        cost = { glass = 1, raw_ice = 3 },
    },
    foam_bomb = {
        name = 'Foam Bomb', desc = 'Large area fire suppression. Placed and timed.',
        fuse = 'timed', fuseDelay = 5, damage = 0, radius = 5, penetration = 0,
        terrainDamage = false, effect = 'foam', foamDuration = 60,
        cost = { metal_ingot = 2, raw_ice = 5, components = 1 },
    },

    -- Missiles (silo-launched, endgame)
    missile_he = {
        name = 'HE Missile', desc = 'High-explosive warhead. Strong blast, moderate area.',
        fuse = 'instant', damage = 100, radius = 4, penetration = 0,
        terrainDamage = true, effect = 'blast',
        cost = { metal_ingot = 5, charcoal = 4, components = 3 },
        siloOnly = true,
    },
    missile_napalm = {
        name = 'Napalm Missile', desc = 'Incendiary warhead. Wide fire spread on impact.',
        fuse = 'instant', damage = 30, radius = 5, penetration = 0,
        terrainDamage = false, effect = 'napalm', fireDuration = 40,
        cost = { metal_ingot = 4, charcoal = 6, components = 2 },
        siloOnly = true,
    },
    missile_bio = {
        name = 'Bio Missile', desc = 'Biological warhead. Massive infection radius.',
        fuse = 'instant', damage = 10, radius = 7, penetration = 0,
        terrainDamage = false, effect = 'biological',
        disease = 'ice_plague', infectionChance = 0.8,
        cost = { metal_ingot = 3, medicinal_herb = 8, components = 3 },
        siloOnly = true,
    },
    missile_foam = {
        name = 'Foam Missile', desc = 'Suppression warhead. Blankets area in fire-retardant foam.',
        fuse = 'instant', damage = 0, radius = 6, penetration = 0,
        terrainDamage = false, effect = 'foam', foamDuration = 90,
        cost = { metal_ingot = 3, raw_ice = 8, components = 2 },
        siloOnly = true,
    },
    missile_bunker = {
        name = 'Bunker Buster', desc = 'Penetrating warhead. Punches through multiple floors.',
        fuse = 'instant', damage = 120, radius = 2, penetration = 3,
        terrainDamage = true, effect = 'blast',
        cost = { metal_ingot = 8, charcoal = 6, components = 5 },
        siloOnly = true,
    },
    missile_nuke = {
        name = 'Mini Nuke', desc = 'Thermonuclear warhead. Obliterates everything in a wide area across all floors.',
        fuse = 'instant', damage = 250, radius = 10, penetration = 99,
        terrainDamage = true, effect = 'nuclear', fireDuration = 60,
        cost = { metal_ingot = 10, charcoal = 8, components = 8, nuclear_core = 1 },
        siloOnly = true,
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local foamZones = {}    -- { [tileKey] = { x, y, depth, remaining } }
local napalmZones = {}  -- persistent incendiary puddles / hotspots
local cloudZones = {}   -- toxic / biological aerosol tiles
local falloutZones = {} -- radioactive fallout tiles
local stepTimer = 0

local function tileKey(x, y, depth)
    return (depth or 0) * 100000000 + y * 10000 + x
end

local function upsertZone(store, x, y, depth, remaining, fields)
    local k = tileKey(x, y, depth)
    local zone = store[k]
    if not zone then
        zone = {
            x = x,
            y = y,
            depth = depth or 0,
            remaining = remaining or 0,
        }
        store[k] = zone
    else
        zone.remaining = math.max(zone.remaining or 0, remaining or 0)
    end

    if fields then
        for key, value in pairs(fields) do
            if type(value) == 'number' and type(zone[key]) == 'number' then
                zone[key] = math.max(zone[key], value)
            else
                zone[key] = value
            end
        end
    end

    return zone
end

local function forEachTileInRadius(cx, cy, radius, fn)
    for dy = -radius, radius do
        for dx = -radius, radius do
            if dx * dx + dy * dy <= radius * radius then
                fn(cx + dx, cy + dy, dx, dy)
            end
        end
    end
end

function Ordnance.init()
    foamZones = {}
    napalmZones = {}
    cloudZones = {}
    falloutZones = {}
    stepTimer = 0
end

---------------------------------------------------------------------------
-- Foam zone API
---------------------------------------------------------------------------

local function applyFoam(cx, cy, depth, radius, duration)
    local fok, FireMod = pcall(require, 'src.sim.fire')
    forEachTileInRadius(cx, cy, radius, function(tx, ty)
        upsertZone(foamZones, tx, ty, depth, duration)
        if fok then FireMod.extinguish(tx, ty, depth) end
    end)
    local VFX = getVFX()
    if VFX then
        VFX.spawn('burst', cx, cy, depth, {
            color = { 0.72, 0.92, 1.0, 0.65 },
            radius = 0.25,
            endRadius = radius + 0.65,
            duration = 0.35,
        })
    end
end

function Ordnance.spawnNapalmField(cx, cy, depth, radius, duration, potency)
    potency = potency or 1.0
    local fok, FireMod = pcall(require, 'src.sim.fire')
    forEachTileInRadius(cx, cy, radius, function(tx, ty, dx, dy)
        local dist = math.sqrt(dx * dx + dy * dy)
        local distMult = 1.0 - (dist / math.max(radius, 1))
        local intensity = math.max(0.35, potency * (0.45 + distMult * 0.55))
        upsertZone(napalmZones, tx, ty, depth, duration, {
            intensity = intensity,
            source = 'napalm',
        })
        if fok and math.random() < (0.45 + intensity * 0.35) then
            FireMod.ignite(tx, ty, 'napalm', depth)
        end
    end)
    local VFX = getVFX()
    if VFX then
        VFX.spawn('burst', cx, cy, depth, {
            color = { 1.0, 0.45, 0.1, 0.55 },
            radius = 0.35,
            endRadius = radius + 0.85,
            duration = 0.4,
        })
    end
end

local function spawnCloud(cx, cy, depth, radius, duration, fields)
    forEachTileInRadius(cx, cy, radius, function(tx, ty, dx, dy)
        local dist = math.sqrt(dx * dx + dy * dy)
        local distMult = 1.0 - (dist / math.max(radius, 1))
        upsertZone(cloudZones, tx, ty, depth, duration, {
            kind = fields.kind,
            gasType = fields.gasType,
            disease = fields.disease,
            infectionChance = (fields.infectionChance or 0) * math.max(0.25, distMult),
            severity = (fields.severity or 0.1) * math.max(0.35, distMult),
            creatureDamage = (fields.creatureDamage or 0) * math.max(0.35, distMult),
            slow = fields.slow or 0,
            source = fields.source or fields.kind,
        })
    end)
end

function Ordnance.spawnBioCloud(cx, cy, depth, radius, duration, diseaseId, infectionChance)
    local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')
    spawnCloud(cx, cy, depth, radius, duration, {
        kind = 'bio',
        gasType = tgOk and TileGas.TYPE_SPORE or nil,
        disease = diseaseId or 'ice_plague',
        infectionChance = infectionChance or 0.3,
        severity = 0.16,
        creatureDamage = 1.5,
        source = 'bio_ordnance',
    })
    local VFX = getVFX()
    if VFX then
        VFX.spawn('burst', cx, cy, depth, {
            color = { 0.55, 0.92, 0.3, 0.52 },
            radius = 0.3,
            endRadius = radius + 0.8,
            duration = 0.45,
        })
    end
end

function Ordnance.spawnToxicCloud(cx, cy, depth, radius, duration, severity, creatureDamage, slow)
    local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')
    spawnCloud(cx, cy, depth, radius, duration, {
        kind = 'toxic',
        gasType = tgOk and TileGas.TYPE_TOXIC or nil,
        severity = severity or 0.18,
        creatureDamage = creatureDamage or 2,
        slow = slow or 0.25,
        source = 'chemical',
    })
    local VFX = getVFX()
    if VFX then
        VFX.spawn('burst', cx, cy, depth, {
            color = { 0.72, 0.88, 0.18, 0.5 },
            radius = 0.3,
            endRadius = radius + 0.9,
            duration = 0.42,
        })
    end
end

function Ordnance.spawnFalloutField(cx, cy, depth, radius, duration, baseDoseRate)
    local doseBase = baseDoseRate or 0.08
    forEachTileInRadius(cx, cy, radius, function(tx, ty, dx, dy)
        local dist = math.sqrt(dx * dx + dy * dy)
        local distMult = 1.0 - (dist / math.max(radius, 1))
        if distMult <= 0 then return end
        upsertZone(falloutZones, tx, ty, depth, duration, {
            doseRate = doseBase * math.max(0.2, distMult),
            source = 'fallout',
        })
    end)
    local VFX = getVFX()
    if VFX then
        VFX.spawn('ring', cx, cy, depth, {
            color = { 0.82, 1.0, 0.28, 0.45 },
            radius = math.max(0.4, radius * 0.35),
            endRadius = radius + 1.2,
            duration = 0.7,
            width = 2,
        })
    end
end

function Ordnance.getFoamZones()
    return foamZones
end

function Ordnance.getNapalmZones()
    return napalmZones
end

function Ordnance.getCloudZones()
    return cloudZones
end

function Ordnance.getFalloutZones()
    return falloutZones
end

function Ordnance.getFalloutDoseRate(x, y, depth)
    local zone = falloutZones[tileKey(x, y, depth)]
    return zone and zone.doseRate or 0
end

local applyDetonationLayer  -- forward declaration

---------------------------------------------------------------------------
-- Core detonation — applies all effects for an explosion
---------------------------------------------------------------------------

function Ordnance.detonate(x, y, ordType, depth)
    local def = Ordnance.TYPES[ordType]
    if not def then return end

    depth = depth or 0
    local World = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')
    local radius = def.radius or 3
    local damage = def.damage or 0
    local VFX = getVFX()

    if VFX then
        local color = { 1.0, 0.86, 0.38, 0.65 }
        if def.effect == 'napalm' then
            color = { 1.0, 0.42, 0.08, 0.65 }
        elseif def.effect == 'biological' then
            color = { 0.55, 0.9, 0.28, 0.62 }
        elseif def.effect == 'foam' then
            color = { 0.72, 0.92, 1.0, 0.62 }
        elseif def.effect == 'nuclear' then
            color = { 1.0, 0.96, 0.62, 0.78 }
        elseif def.effect == 'emp' then
            color = { 0.45, 0.8, 1.0, 0.62 }
        end
        VFX.spawn('burst', x, y, depth, {
            color = color,
            radius = 0.45,
            endRadius = radius + 1.2,
            duration = def.effect == 'nuclear' and 0.9 or 0.35,
        })
        VFX.spawn('ring', x, y, depth, {
            color = color,
            radius = 0.55,
            endRadius = radius + 1.5,
            duration = def.effect == 'nuclear' and 1.0 or 0.45,
            width = def.effect == 'nuclear' and 3 or 2,
        })
    end

    -- Notify AI director of explosion noise
    local dok, Director = pcall(require, 'src.ai.director')
    if dok and Director.onNoise then Director.onNoise(x, y, radius * 2) end

    -- Apply effects at this depth
    applyDetonationLayer(x, y, depth, def, damage, radius)

    -- Multi-floor penetration
    if def.penetration and def.penetration > 0 then
        for floor = 1, def.penetration do
            local belowDepth = depth + floor
            local layer = World.getLayer and World.getLayer(belowDepth)
            if layer then
                -- Reduced damage per floor
                local floorDmg = damage * math.max(0.2, 1 - floor * 0.25)
                local floorRadius = math.max(1, radius - floor)
                applyDetonationLayer(x, y, belowDepth, def, floorDmg, floorRadius)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Apply detonation effects to a single depth layer
---------------------------------------------------------------------------

applyDetonationLayer = function(cx, cy, depth, def, damage, radius)
    local World = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')

    -- Terrain destruction (inner half of radius)
    if def.terrainDamage then
        local innerR = math.max(1, math.floor(radius / 2))
        for dy = -innerR, innerR do
            for dx = -innerR, innerR do
                if dx * dx + dy * dy <= innerR * innerR then
                    local tx, ty = cx + dx, cy + dy
                    if World.inBounds(tx, ty) then
                        local tile = World.getTile(tx, ty, depth)
                        local props = Tiles.get(tile)
                        if props and not props.name:find('void') then
                            -- Walls and floors get destroyed to debris/underground floor
                            if depth > 0 then
                                World.setTile(tx, ty, Tiles.UNDERGROUND_FLOOR, depth)
                            else
                                World.setTile(tx, ty, Tiles.DEBRIS, depth)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Damage entities in radius
    if damage > 0 then
        -- Damage creatures
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok then
            for crId, comps in ECS.query('creature', 'pos') do
                local cr = comps.creature
                -- Skip dead creatures
                if cr.state == 'dead' then goto continue_creature end
                local cp = comps.pos
                if (cp.depth or 0) == depth then
                    local dx = cp.x - cx
                    local dy = cp.y - cy
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist <= radius then
                        local falloff = 1 - (dist / radius)
                        local dmg = damage * falloff
                        if dmg > 0 then
                            Creatures.damageCreature(crId, dmg, nil)
                        end
                    end
                end
                ::continue_creature::
            end
        end

        -- Damage colonists
        local bok, Body = pcall(require, 'src.combat.body')
        local wok, Wounds = pcall(require, 'src.combat.wounds')
        for colId, comps in ECS.query('colonist', 'pos') do
            local cp = comps.pos
            if (cp.depth or 0) == depth and comps.colonist.state ~= 'dead' then
                local dx = cp.x - cx
                local dy = cp.y - cy
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= radius then
                    local falloff = 1 - (dist / radius)
                    local dmg = damage * falloff
                    comps.colonist.health = math.max(0, comps.colonist.health - dmg)
                    -- Apply wound (shrapnel cut)
                    if wok and bok and dmg > 10 then
                        local part = Body.randomPart()
                        Wounds.apply(colId, part, 'cut', math.min(1.0, dmg / 60))
                    end
                    -- Death check — route through Colonist.kill for full callbacks
                    if comps.colonist.health <= 0 and comps.colonist.state ~= 'dead' then
                        local cok2, ColMod = pcall(require, 'src.colonist.colonist')
                        if cok2 and ColMod.kill then
                            ColMod.kill(colId)
                        end
                    end
                end
            end
        end
    end

    -- Effect: napalm (fire spread)
    if def.effect == 'napalm' or def.effect == 'nuclear' then
        local fireDuration = def.fireDuration
            or (def.effect == 'nuclear' and otune('default_nuclear_fire_duration', 45) or otune('default_fire_duration', 20))
        local potency = def.effect == 'nuclear' and 1.35 or 1.0
        Ordnance.spawnNapalmField(cx, cy, depth, radius, fireDuration, potency)
        if def.effect == 'nuclear' then
            local falloutDuration = math.max(
                otune('fallout_min_duration', 90),
                fireDuration * otune('fallout_duration_mult', 3)
            )
            local falloutDose = otune('fallout_base_dose', 0.04) + radius * otune('fallout_dose_per_radius', 0.01)
            Ordnance.spawnFalloutField(cx, cy, depth, radius, falloutDuration, falloutDose)
        end
    end

    -- Effect: biological (disease infection)
    if def.effect == 'biological' then
        local diseaseOk, Disease = pcall(require, 'src.sim.disease')
        if diseaseOk then
            local diseaseId = def.disease or 'ice_plague'
            local chance = def.infectionChance or 0.5
            for colId, comps in ECS.query('colonist', 'pos') do
                local cp = comps.pos
                if (cp.depth or 0) == depth and comps.colonist.state ~= 'dead' then
                    local dx = cp.x - cx
                    local dy = cp.y - cy
                    if dx * dx + dy * dy <= radius * radius then
                        if math.random() < chance then
                            Disease.infect(colId, diseaseId)
                        end
                    end
                end
            end
            -- Also infect creatures
            for crId, comps in ECS.query('creature', 'pos') do
                local cp = comps.pos
                if (cp.depth or 0) == depth then
                    local dx = cp.x - cx
                    local dy = cp.y - cy
                    if dx * dx + dy * dy <= radius * radius then
                        if math.random() < chance then
                            local cr = comps.creature
                            if cr then cr.health = cr.health - 20 end  -- creatures take bio damage
                        end
                    end
                end
            end
        end
        local cloudDuration = math.max(18, radius * 5)
        Ordnance.spawnBioCloud(cx, cy, depth, radius, cloudDuration, def.disease, (def.infectionChance or 0.5) * 0.8)
    end

    -- Effect: foam (fire suppression)
    if def.effect == 'foam' then
        applyFoam(cx, cy, depth, radius, def.foamDuration or 60)
    end

    -- Effect: EMP (stun creatures)
    if def.effect == 'emp' then
        for crId, comps in ECS.query('creature', 'pos') do
            local cp = comps.pos
            if (cp.depth or 0) == depth then
                local dx = cp.x - cx
                local dy = cp.y - cy
                if dx * dx + dy * dy <= radius * radius then
                    local cr = comps.creature
                    if cr then
                        cr.stunTimer = (cr.stunTimer or 0) + (def.stun or 3.0)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Placed ordnance ECS system
---------------------------------------------------------------------------

-- ordnance component: { type, fuse, fuseTimer, armed, triggerRadius, depth }

local function ordnanceTickSystem(dt, id, comps)
    local ord = comps.ordnance
    local pos = comps.pos
    if not ord or not pos then return end

    local def = Ordnance.TYPES[ord.type]
    if not def then return end

    -- Arming delay (1 second after placement)
    if not ord.armed then
        ord.armTimer = (ord.armTimer or 0) + dt
        if ord.armTimer >= 1.0 then
            ord.armed = true
        end
        return
    end

    -- Timed fuse: count down and detonate
    if ord.fuse == 'timed' then
        ord.fuseTimer = ord.fuseTimer - dt
        if ord.fuseTimer <= 0 then
            Ordnance.detonate(pos.x, pos.y, ord.type, pos.depth or 0)
            ECS.destroy(id)
        end
    end

    -- Proximity fuse: check for hostiles in range
    if ord.fuse == 'proximity' then
        local triggerR = ord.triggerRadius or def.triggerRadius or 2
        local r2 = triggerR * triggerR
        local triggered = false

        for crId, crComps in ECS.query('creature', 'pos') do
            local cp = crComps.pos
            if (cp.depth or 0) == (pos.depth or 0) then
                local dx = cp.x - pos.x
                local dy = cp.y - pos.y
                if dx * dx + dy * dy <= r2 then
                    triggered = true
                    break
                end
            end
        end

        if triggered then
            Ordnance.detonate(pos.x, pos.y, ord.type, pos.depth or 0)
            ECS.destroy(id)
        end
    end

    -- Instant fuse: detonate immediately after arming
    if ord.fuse == 'instant' then
        Ordnance.detonate(pos.x, pos.y, ord.type, pos.depth or 0)
        ECS.destroy(id)
    end

    -- Manual fuse: waits for Ordnance.trigger(entityId)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- Place an explosive at a tile
function Ordnance.place(x, y, ordType, depth)
    local def = Ordnance.TYPES[ordType]
    if not def then return nil end

    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth or 0 })
    ECS.set(id, 'ordnance', {
        type         = ordType,
        fuse         = def.fuse,
        fuseTimer    = def.fuseDelay or 0,
        armed        = false,
        armTimer     = 0,
        triggerRadius = def.triggerRadius,
    })
    return id
end

-- Manually trigger a placed charge
function Ordnance.trigger(entityId)
    local ord = ECS.get(entityId, 'ordnance')
    local pos = ECS.get(entityId, 'pos')
    if not ord or not pos then return false end
    if not ord.armed then return false end
    Ordnance.detonate(pos.x, pos.y, ord.type, pos.depth or 0)
    ECS.destroy(entityId)
    return true
end

-- Fire a missile from a silo toward target coordinates
function Ordnance.launchMissile(siloX, siloY, targetX, targetY, missileType, depth)
    local def = Ordnance.TYPES[missileType]
    if not def then return nil end

    -- Spawn projectile entity that flies to target
    local id = ECS.spawn()
    local dx = targetX - siloX
    local dy = targetY - siloY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then dist = 1 end

    ECS.set(id, 'pos', { x = siloX, y = siloY, prevX = siloX, prevY = siloY, depth = 0 })
    ECS.set(id, 'projectile', {
        shooterId  = nil,
        targetId   = nil,
        damage     = 0,           -- damage handled by detonation
        accuracy   = 1.0,         -- missiles always hit target tile
        dirX       = dx / dist,
        dirY       = dy / dist,
        speed      = 15,
        traveled   = 0,
        maxDist    = dist,
        fx         = siloX + 0.5,
        fy         = siloY + 0.5,
        -- Missile-specific fields
        isMissile    = true,
        missileType  = missileType,
        targetX      = targetX,
        targetY      = targetY,
        targetDepth  = depth or 0,
    })
    return id
end

-- Check if a tile has active foam
function Ordnance.isFoamed(x, y, depth)
    local k = tileKey(x, y, depth)
    local zone = foamZones[k]
    local remaining = type(zone) == 'table' and zone.remaining or zone
    if not remaining or remaining <= 0 then
        foamZones[k] = nil
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- ECS system for missile arrival (extends projectile system)
---------------------------------------------------------------------------

local function missileArrivalSystem(dt, id, comps)
    local proj = comps.projectile
    if not proj or not proj.isMissile then return end

    -- Check if missile has arrived (traveled >= maxDist)
    if proj.traveled >= proj.maxDist then
        Ordnance.detonate(proj.targetX, proj.targetY, proj.missileType, proj.targetDepth or 0)
        ECS.destroy(id)
    end
end

---------------------------------------------------------------------------
-- Step — clean up expired foam zones
---------------------------------------------------------------------------

function Ordnance.step(dt)
    stepTimer = stepTimer + dt
    if stepTimer < otune('hazard_step_interval', 0.5) then return end
    local elapsed = stepTimer
    stepTimer = 0

    local wOk, Weather = pcall(require, 'src.weather.weather')
    local function getDecay(kind, depth)
        if not wOk or not Weather.getHazardDecayMult then return 1.0 end
        return Weather.getHazardDecayMult(kind, depth)
    end

    for k, zone in pairs(foamZones) do
        local left = zone.remaining - elapsed
        if left <= 0 then
            foamZones[k] = nil
        else
            zone.remaining = left
        end
    end

    -- Cache entity lists once before zone processing (avoids N+1 ECS.query per zone)
    lazyLoadOrdnanceDeps()
    local colonists = {}
    for id, comps in ECS.query('colonist', 'pos') do
        colonists[#colonists + 1] = { id = id, pos = comps.pos, colonist = comps.colonist }
    end
    local creatures = {}
    for id, comps in ECS.query('creature', 'pos') do
        creatures[#creatures + 1] = { id = id, pos = comps.pos, creature = comps.creature }
    end

    do
        for k, zone in pairs(napalmZones) do
            zone.remaining = zone.remaining - elapsed * getDecay('napalm', zone.depth)
            if zone.remaining <= 0 then
                napalmZones[k] = nil
            else
                if _FireMod and math.random() < math.min(0.9, 0.22 + zone.intensity * 0.45) then
                    _FireMod.ignite(zone.x, zone.y, 'napalm', zone.depth)
                end

                for _, e in ipairs(colonists) do
                    local pos = e.pos
                    if pos.x == zone.x and pos.y == zone.y and (pos.depth or 0) == (zone.depth or 0) then
                        local col = e.colonist
                        if col and col.state ~= 'dead' then
                            col.health = math.max(0, col.health - zone.intensity * 1.5 * elapsed)
                            if _StatusFx then _StatusFx.apply(e.id, 'burning', 0.12 * zone.intensity) end
                        end
                    end
                end
                for _, e in ipairs(creatures) do
                    local pos = e.pos
                    if pos.x == zone.x and pos.y == zone.y and (pos.depth or 0) == (zone.depth or 0) then
                        local creature = e.creature
                        if creature and (creature.health or 0) > 0 then
                            creature.health = creature.health - zone.intensity * 2.0 * elapsed
                            creature.dotDamage = math.max(creature.dotDamage or 0, 3 * zone.intensity)
                            creature.dotDuration = math.max(creature.dotDuration or 0, 2.0)
                        end
                    end
                end
            end
        end
    end

    do
        for k, zone in pairs(cloudZones) do
            zone.remaining = zone.remaining - elapsed * getDecay('cloud', zone.depth)
            if zone.remaining <= 0 then
                cloudZones[k] = nil
            else
                if _TileGas and zone.gasType then
                    _TileGas.addGas(zone.x, zone.y, 1, zone.gasType, zone.depth or 0)
                end

                for _, e in ipairs(colonists) do
                    local pos = e.pos
                    if pos.x == zone.x and pos.y == zone.y and (pos.depth or 0) == (zone.depth or 0) then
                        local col = e.colonist
                        if col and col.state ~= 'dead' then
                            if _StatusFx and zone.kind == 'toxic' then
                                _StatusFx.apply(e.id, 'toxic_exposure', zone.severity or 0.1)
                            end
                            if zone.kind == 'bio' and _Disease and math.random() < (zone.infectionChance or 0) * elapsed then
                                _Disease.infect(e.id, zone.disease or 'ice_plague')
                            end
                        end
                    end
                end
                for _, e in ipairs(creatures) do
                    local pos = e.pos
                    if pos.x == zone.x and pos.y == zone.y and (pos.depth or 0) == (zone.depth or 0) then
                        local creature = e.creature
                        if creature and (creature.health or 0) > 0 then
                            if zone.creatureDamage and zone.creatureDamage > 0 then
                                creature.health = creature.health - zone.creatureDamage * elapsed
                            end
                            if zone.slow and zone.slow > 0 then
                                creature.slowMult = math.min(creature.slowMult or 1.0, 1 - zone.slow)
                                creature.slowTimer = math.max(creature.slowTimer or 0, 1.5)
                            end
                        end
                    end
                end
            end
        end
    end

    do
        for k, zone in pairs(falloutZones) do
            zone.remaining = zone.remaining - elapsed * getDecay('fallout', zone.depth)
            if zone.remaining <= 0 then
                falloutZones[k] = nil
            else
                for _, e in ipairs(creatures) do
                    local pos = e.pos
                    if pos.x == zone.x and pos.y == zone.y and (pos.depth or 0) == (zone.depth or 0) then
                        local creature = e.creature
                        if creature and (creature.health or 0) > 0 then
                            creature.health = creature.health - zone.doseRate * 8 * elapsed
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- ECS registration
---------------------------------------------------------------------------

function Ordnance.registerSystems()
    ECS.addSystem('ordnance_tick', { 'ordnance', 'pos' }, ordnanceTickSystem, 20)
    ECS.addSystem('missile_arrival', { 'projectile' }, missileArrivalSystem, 23)
end

Ordnance.registerSystems()

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Ordnance.getState()
    return {
        foamZones = foamZones,
        napalmZones = napalmZones,
        cloudZones = cloudZones,
        falloutZones = falloutZones,
    }
end

local function normalizeZoneStore(store)
    local normalized = {}
    for k, zone in pairs(store or {}) do
        if type(zone) == 'number' then
            local depth = math.floor(k / 100000000)
            local rem = k - depth * 100000000
            local y = math.floor(rem / 10000)
            local x = rem - y * 10000
            normalized[k] = { x = x, y = y, depth = depth, remaining = zone }
        else
            normalized[k] = zone
        end
    end
    return normalized
end

function Ordnance.loadState(saved)
    foamZones = {}
    napalmZones = {}
    cloudZones = {}
    falloutZones = {}
    stepTimer = 0
    if not saved then return end
    foamZones = normalizeZoneStore(saved.foamZones)
    napalmZones = normalizeZoneStore(saved.napalmZones)
    cloudZones = normalizeZoneStore(saved.cloudZones)
    falloutZones = normalizeZoneStore(saved.falloutZones)
end

return Ordnance
