-- defenses.lua — Turret targeting, trap triggers, cover system
-- Turrets auto-target hostile creatures. Traps trigger on walk-over.
-- Cover reduces incoming projectile hit chance.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Defenses = {}

-- Lazy-loaded modules (avoid pcall in ECS tick functions)
local _Ordnance, _CreaturesMod, _Fire, _Power, _VFX
local function lazyLoadDefenses()
    if _Power ~= nil then return end
    local ok
    ok, _Ordnance = pcall(require, 'src.combat.ordnance')
    if not ok then _Ordnance = false end
    ok, _CreaturesMod = pcall(require, 'src.creatures.creatures')
    if not ok then _CreaturesMod = false end
    ok, _Fire = pcall(require, 'src.sim.fire')
    if not ok then _Fire = false end
    ok, _Power = pcall(require, 'src.sim.power')
    if not ok then _Power = false end
    ok, _VFX = pcall(require, 'src.render.vfx')
    if not ok then _VFX = false end
end

local function resolvePayloadType(def, turret)
    if not _Ordnance or not _Ordnance.TYPES then return nil end
    if turret and turret.loadedPayload and _Ordnance.TYPES[turret.loadedPayload] then
        return turret.loadedPayload
    end
    if def.payloadType and _Ordnance.TYPES[def.payloadType] then
        return def.payloadType
    end
    if def.ammoType and _Ordnance.TYPES[def.ammoType] then
        return def.ammoType
    end
    return nil
end

local function igniteBurst(x, y, depth, radius, source)
    lazyLoadDefenses()
    if not _Fire then return end
    radius = radius or 0
    for dy = -radius, radius do
        for dx = -radius, radius do
            if dx * dx + dy * dy <= radius * radius then
                _Fire.ignite(x + dx, y + dy, source or 'turret', depth or 0)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Planet-based damage modifiers
---------------------------------------------------------------------------
local function getPlanetDamageMult(turretType)
    local pok, Planet = pcall(require, 'src.world.planet')
    local planetId = pok and Planet.getId() or 'erebus'

    if turretType == 'flamethrower' or turretType == 'napalm_sprayer' then
        if planetId == 'rhea_2' then return 0.5 end        -- overheats in desert
        if planetId == 'nemaea' then return 1.5 end         -- fire very effective in vacuum cold
    elseif turretType == 'cryo_turret' or turretType == 'heat_drain' then
        if planetId == 'nemaea' then return 0.1 end         -- already frozen, nearly useless
        if planetId == 'rhea_2' then return 1.5 end         -- cold very effective in desert
    elseif turretType == 'tesla' or turretType == 'emp_cannon' then
        if planetId == 'nerthus_9' then return 1.8 end      -- water conducts electricity
    elseif turretType == 'gas_turret' or turretType == 'poison_turret' then
        if planetId == 'nemaea' then return 0 end            -- no atmosphere to carry gas
        if planetId == 'morvos' then return 0.5 end          -- toxic atmosphere dilutes gas
    elseif turretType == 'acid_sprayer' then
        if planetId == 'morvos' then return 0.5 end          -- creatures are acid-resistant
    end
    return 1.0
end

local function getTurretFxColor(turretType)
    if turretType == 'laser' or turretType == 'railgun' then
        return { 0.55, 0.88, 1.0, 0.85 }
    elseif turretType == 'tesla' or turretType == 'emp_cannon' then
        return { 0.62, 0.8, 1.0, 0.85 }
    elseif turretType == 'flamethrower' or turretType == 'napalm_sprayer' then
        return { 1.0, 0.45, 0.12, 0.85 }
    elseif turretType == 'gas_turret' then
        return { 0.72, 0.88, 0.2, 0.8 }
    elseif turretType == 'cryo_turret' or turretType == 'heat_drain' then
        return { 0.52, 0.85, 1.0, 0.82 }
    end
    return { 1.0, 0.86, 0.35, 0.8 }
end

---------------------------------------------------------------------------
-- Turret definitions
---------------------------------------------------------------------------

local TURRET_DEFS = {
    -- Tier 1: primitive
    ballista = {
        name     = 'Ballista',
        damage   = 25,
        range    = 10,
        cooldown = 4.0,
        accuracy = 0.65,
        powered  = false,
        ammoUse  = 1,
        aoe      = 0,
    },
    crossbow_turret = {
        name     = 'Auto-Crossbow',
        damage   = 12,
        range    = 8,
        cooldown = 2.0,
        accuracy = 0.70,
        powered  = false,
        ammoUse  = 1,
        aoe      = 0,
    },

    -- Tier 2: powered mechanical
    gun = {
        name     = 'Gun Turret',
        damage   = 15,
        range    = 12,
        cooldown = 1.5,
        accuracy = 0.75,
        powered  = true,
        ammoUse  = 1,
        aoe      = 0,
    },
    minigun = {
        name     = 'Minigun Turret',
        damage   = 8,
        range    = 10,
        cooldown = 0.3,    -- extremely fast
        accuracy = 0.45,   -- spray and pray
        powered  = true,
        ammoUse  = 3,
        aoe      = 0,
        suppression = true,  -- forces creatures to take cover
    },
    shotgun_turret = {
        name     = 'Shotgun Turret',
        damage   = 30,
        range    = 6,       -- short range
        cooldown = 2.5,
        accuracy = 0.85,   -- devastating close up
        powered  = true,
        ammoUse  = 2,
        aoe      = 1,      -- small spread
    },
    mortar = {
        name     = 'Mortar',
        damage   = 40,
        range    = 20,
        cooldown = 8.0,
        accuracy = 0.50,
        powered  = false,
        ammoUse  = 2,
        aoe      = 3,
    },

    -- Tier 3: energy weapons
    laser = {
        name     = 'Laser Turret',
        damage   = 20,
        range    = 15,
        cooldown = 0.8,
        accuracy = 0.90,
        powered  = true,
        ammoUse  = 0,
        aoe      = 0,
        powerDraw = 30,
    },
    tesla = {
        name     = 'Tesla Coil',
        damage   = 15,
        range    = 8,
        cooldown = 1.2,
        accuracy = 1.0,    -- auto-hit, chain lightning
        powered  = true,
        ammoUse  = 0,
        aoe      = 0,
        chainTargets = 3,  -- jumps to 3 nearby enemies
        chainRange   = 4,
        powerDraw    = 40,
    },
    flamethrower = {
        name     = 'Flamethrower Turret',
        damage   = 10,
        range    = 5,       -- very short
        cooldown = 0.2,     -- continuous stream
        accuracy = 1.0,     -- cone, always hits
        powered  = true,
        ammoUse  = 0,
        aoe      = 2,       -- cone area
        igniteRadius = 1,
        setsFireOnMiss = true,
        powerDraw = 20,
    },
    cryo_turret = {
        name     = 'Cryo Turret',
        damage   = 5,
        range    = 10,
        cooldown = 1.0,
        accuracy = 0.80,
        powered  = true,
        ammoUse  = 0,
        aoe      = 2,
        slowEffect = 0.7,  -- 70% slow for 4 seconds
        slowDuration = 4.0,
        powerDraw = 25,
    },
    heat_drain = {
        name     = 'Heat-Drain Turret',
        damage   = 12,
        range    = 8,
        cooldown = 1.5,
        accuracy = 0.85,
        powered  = true,
        ammoUse  = 0,
        aoe      = 3,
        damageType = 'cold',
        slowEffect = 0.5,  -- 50% slow for 5 seconds
        slowDuration = 5.0,
        powerDraw = 30,
    },

    -- Tier 4: heavy/special
    railgun = {
        name     = 'Railgun Emplacement',
        damage   = 120,
        range    = 25,
        cooldown = 12.0,    -- massive cooldown
        accuracy = 0.95,
        powered  = true,
        ammoUse  = 0,
        aoe      = 0,
        penetration = true,  -- hits all enemies in a line
        powerDraw   = 60,
    },
    emp_cannon = {
        name     = 'EMP Cannon',
        damage   = 5,
        range    = 12,
        cooldown = 6.0,
        accuracy = 0.80,
        powered  = true,
        ammoUse  = 0,
        aoe      = 4,
        stunDuration = 3.0,  -- area stun
        powerDraw    = 35,
    },
    rocket_turret = {
        name     = 'Rocket Turret',
        damage   = 60,
        range    = 18,
        cooldown = 6.0,
        accuracy = 0.60,
        powered  = false,
        ammoUse  = 3,
        aoe      = 4,
    },

    -- Tier 2b: emplaced ballistic
    sniper_nest = {
        name     = 'Sniper Nest',
        damage   = 50,
        range    = 22,
        cooldown = 8.0,
        accuracy = 0.92,
        powered  = false,
        ammoUse  = 1,
        aoe      = 0,
    },
    autocannon = {
        name     = 'Autocannon',
        damage   = 12,
        range    = 11,
        cooldown = 0.6,
        accuracy = 0.65,
        powered  = true,
        ammoUse  = 2,
        aoe      = 0,
        powerDraw = 25,
    },
    grenade_launcher = {
        name     = 'Grenade Launcher Turret',
        damage   = 35,
        range    = 14,
        cooldown = 5.0,
        accuracy = 0.55,
        powered  = false,
        ammoUse  = 2,
        aoe      = 3,
    },
    heavy_mg = {
        name     = 'Heavy MG Nest',
        damage   = 10,
        range    = 13,
        cooldown = 0.4,
        accuracy = 0.55,
        powered  = false,
        ammoUse  = 3,
        aoe      = 0,
        suppression = true,
    },

    -- Tier 3b: special ordnance turrets
    napalm_sprayer = {
        name     = 'Napalm Sprayer',
        damage   = 8,
        range    = 6,
        cooldown = 0.3,
        accuracy = 1.0,
        powered  = true,
        ammoUse  = 1,
        aoe      = 3,
        setsFireOnMiss = true,
        payloadType = 'napalm_grenade',
        ammoType = 'napalm_fuel',
        powerDraw = 25,
    },
    foam_nozzle = {
        name     = 'Foam Nozzle',
        damage   = 0,
        range    = 8,
        cooldown = 2.0,
        accuracy = 1.0,
        powered  = true,
        ammoUse  = 1,
        aoe      = 4,
        foamEffect = true,    -- triggers foam instead of damage
        ammoType = 'foam_canister',
        powerDraw = 15,
    },
    missile_launcher = {
        name     = 'Missile Launcher',
        damage   = 100,
        range    = 40,
        cooldown = 15.0,
        accuracy = 0.85,
        powered  = true,
        ammoUse  = 1,
        aoe      = 4,
        ammoType = 'missile_he',
        missileDetonation = true,
        powerDraw = 50,
    },
    -- Ground-to-air defense (targets flying creatures / aerial raids)
    sam_launcher = {
        name     = 'SAM Launcher',
        damage   = 80,
        range    = 30,
        cooldown = 10.0,
        accuracy = 0.90,
        powered  = true,
        ammoUse  = 1,
        aoe      = 2,
        ammoType = 'ammo_rocket',
        antiAir  = true,
        powerDraw = 40,
    },

    -- Tier 3c: gas/chemical turrets
    gas_turret = {
        name     = 'Gas Turret',
        damage   = 3,
        range    = 8,
        cooldown = 1.5,
        accuracy = 1.0,     -- cloud, always hits
        powered  = true,
        ammoUse  = 1,
        aoe      = 3,
        ammoType = 'gas_canister',
        dotEffect   = { damage = 6, duration = 10 },
        slowEffect  = 0.4,
        slowDuration = 5.0,
        cloudPayload = { radius = 3, duration = 16, severity = 0.16, creatureDamage = 3, slow = 0.35 },
        powerDraw    = 20,
    },
    acid_sprayer = {
        name     = 'Acid Sprayer',
        damage   = 6,
        range    = 6,
        cooldown = 0.4,
        accuracy = 1.0,     -- spray cone, auto-hit
        powered  = true,
        ammoUse  = 1,
        aoe      = 2,
        ammoType = 'acid_canister',
        dotEffect   = { damage = 8, duration = 8 },
        powerDraw    = 25,
    },
    poison_turret = {
        name     = 'Poison Dart Turret',
        damage   = 8,
        range    = 12,
        cooldown = 2.0,
        accuracy = 0.80,
        powered  = true,
        ammoUse  = 1,
        aoe      = 0,
        ammoType = 'poison_darts',
        dotEffect   = { damage = 10, duration = 12 },
        slowEffect  = 0.3,
        slowDuration = 6.0,
        powerDraw    = 15,
    },
}

Defenses.TURRET_DEFS = TURRET_DEFS

---------------------------------------------------------------------------
-- Trap definitions (split to src/combat/traps.lua)
---------------------------------------------------------------------------
local tok, TrapsMod = pcall(require, 'src.combat.traps')
local TRAP_DEFS = tok and TrapsMod.TRAP_DEFS or {}

-- NOTE: TRAP_DEFS defined in src/combat/traps.lua; only reference kept here for backward compat
-- The following old inline TRAP_DEFS block has been removed.
-- See src/combat/traps.lua for all trap definitions.

Defenses.TRAP_DEFS = TRAP_DEFS

---------------------------------------------------------------------------
-- Turret AI system — finds hostile targets, fires projectiles
---------------------------------------------------------------------------

local function dist(x1, y1, x2, y2)
    return math.sqrt((x2-x1)^2 + (y2-y1)^2)
end

local function findClosestHostile(tx, ty, tDepth, range)
    local bestId, bestDist = nil, range + 1
    for id, comps in ECS.query('creature', 'pos') do
        local cr = comps.creature
        local pos = comps.pos
        if cr.hostile and cr.state ~= 'dead' and cr.health > 0 and (pos.depth or 0) == tDepth then
            local d = dist(tx, ty, pos.x, pos.y)
            if d <= range and d < bestDist then
                bestDist = d
                bestId = id
            end
        end
    end
    return bestId, bestDist
end

local function turretSystem(dt, id, comps)
    local turret = comps.turret
    local pos    = comps.pos

    local def = TURRET_DEFS[turret.type]
    if not def then return end

    -- Powered turrets need power
    if def.powered and not turret.powered then return end

    -- Cooldown
    if turret.cooldown > 0 then
        turret.cooldown = turret.cooldown - dt
        return
    end

    -- Ammo check
    if def.ammoUse > 0 and (turret.ammo or 0) <= 0 then return end

    -- Find target
    local targetId, targetDist = findClosestHostile(pos.x, pos.y, pos.depth or 0, def.range)
    if not targetId then
        turret.target = nil
        return
    end

    turret.target = targetId

    -- Fire!
    local hitRoll = math.random()

    -- Watchtower accuracy bonus
    local accuracyBonus = 0
    for _, wcomps in ECS.query('watchtower', 'pos') do
        local wpos = wcomps.pos
        local wd = dist(pos.x, pos.y, wpos.x, wpos.y)
        if wd <= wcomps.watchtower.sightRange then
            accuracyBonus = math.max(accuracyBonus, wcomps.watchtower.accuracyBonus)
        end
    end

    local finalAccuracy = def.accuracy + accuracyBonus
    -- Range penalty: accuracy drops at long range
    local rangePenalty = (targetDist / def.range) * 0.15
    finalAccuracy = finalAccuracy - rangePenalty

    if hitRoll < finalAccuracy then
        local targetPos = ECS.get(targetId, 'pos')
        lazyLoadDefenses()
        local fxColor = getTurretFxColor(turret.type)
        if _VFX then
            _VFX.spawn('burst', pos.x, pos.y, pos.depth or 0, {
                color = fxColor,
                radius = 0.12,
                endRadius = 0.45,
                duration = 0.12,
            })
        end

        -- Foam nozzle: extinguish fires around target instead of dealing damage
        if def.foamEffect then
            if targetPos then
                if _Ordnance then
                    _Ordnance.detonate(targetPos.x, targetPos.y, 'foam_grenade', targetPos.depth or 0)
                end
            end
            if def.ammoUse > 0 then turret.ammo = (turret.ammo or 0) - def.ammoUse end
            turret.cooldown = def.cooldown
            return
        end

        local payloadType
        if def.missileDetonation or def.payloadType then
            payloadType = resolvePayloadType(def, turret)
            if targetPos then
                if _Ordnance and payloadType then
                    _Ordnance.detonate(targetPos.x, targetPos.y, payloadType, targetPos.depth or 0)
                end
            end
            if def.ammoUse > 0 then turret.ammo = (turret.ammo or 0) - def.ammoUse end
            turret.cooldown = def.cooldown
            return
        end

        local targetCreature = ECS.get(targetId, 'creature')
        if targetCreature then
            lazyLoadDefenses()
            local planetMult = getPlanetDamageMult(turret.type)
            local finalDamage = def.damage * planetMult
            if _CreaturesMod and _CreaturesMod.damageCreature then
                _CreaturesMod.damageCreature(targetId, finalDamage)
            else
                targetCreature.health = targetCreature.health - finalDamage
            end

            if targetPos and _VFX then
                _VFX.spawn('burst', targetPos.x, targetPos.y, targetPos.depth or 0, {
                    color = fxColor,
                    radius = 0.18,
                    endRadius = def.aoe and def.aoe > 0 and (0.4 + def.aoe * 0.2) or 0.55,
                    duration = 0.16,
                })
                if turret.type == 'laser' or turret.type == 'railgun' or turret.type == 'tesla' then
                    _VFX.spawn('line', pos.x, pos.y, pos.depth or 0, {
                        x2 = targetPos.x,
                        y2 = targetPos.y,
                        color = fxColor,
                        width = turret.type == 'railgun' and 3 or 2,
                        duration = turret.type == 'tesla' and 0.12 or 0.08,
                    })
                end
            end

            -- Slow effect (cryo turret)
            if def.slowEffect then
                targetCreature.slowMult = def.slowEffect
                targetCreature.slowTimer = def.slowDuration or 3.0
            end

            -- Stun effect (EMP cannon)
            if def.stunDuration then
                targetCreature.stunTimer = (targetCreature.stunTimer or 0) + def.stunDuration
            end

            -- DOT effect (gas, acid, poison turrets)
            if def.dotEffect and planetMult > 0 then
                targetCreature.dotDamage   = def.dotEffect.damage * planetMult
                targetCreature.dotDuration = def.dotEffect.duration
            end

            if targetPos and def.igniteRadius then
                igniteBurst(targetPos.x, targetPos.y, targetPos.depth or 0, def.igniteRadius, 'flamethrower')
            end

            if targetPos and def.cloudPayload and planetMult > 0 then
                lazyLoadDefenses()
                if _Ordnance and _Ordnance.spawnToxicCloud then
                    _Ordnance.spawnToxicCloud(
                        targetPos.x,
                        targetPos.y,
                        targetPos.depth or 0,
                        def.cloudPayload.radius,
                        def.cloudPayload.duration,
                        def.cloudPayload.severity * planetMult,
                        def.cloudPayload.creatureDamage * planetMult,
                        def.cloudPayload.slow
                    )
                end
            end

            -- AOE: damage creatures near target
            if def.aoe > 0 then
                if targetPos then
                    for oid, ocomps in ECS.query('creature', 'pos') do
                        if oid ~= targetId then
                            local od = dist(targetPos.x, targetPos.y, ocomps.pos.x, ocomps.pos.y)
                            if od <= def.aoe then
                                local splash = def.damage * planetMult * (1 - od / def.aoe) * 0.6
                                if _CreaturesMod and _CreaturesMod.damageCreature then
                                    _CreaturesMod.damageCreature(oid, splash)
                                else
                                    ocomps.creature.health = ocomps.creature.health - splash
                                end
                                -- AOE slow/stun propagates at reduced effect
                                if def.slowEffect then
                                    ocomps.creature.slowMult = def.slowEffect * 0.7
                                    ocomps.creature.slowTimer = (def.slowDuration or 3.0) * 0.5
                                end
                                if def.stunDuration then
                                    ocomps.creature.stunTimer = (ocomps.creature.stunTimer or 0) + def.stunDuration * 0.5
                                end
                                if def.dotEffect and planetMult > 0 then
                                    ocomps.creature.dotDamage   = def.dotEffect.damage * planetMult * 0.6
                                    ocomps.creature.dotDuration = def.dotEffect.duration * 0.5
                                end
                            end
                        end
                    end
                end
            end

            -- Chain lightning (tesla coil): jump to nearby enemies
            if def.chainTargets and def.chainRange then
                if targetPos then
                    local chainDmg = def.damage * planetMult * 0.6
                    local jumped = 0
                    local hitSet = { [targetId] = true }
                    local lastX, lastY = targetPos.x, targetPos.y
                    for _ = 1, def.chainTargets do
                        local bestChain, bestChainDist = nil, def.chainRange + 1
                        for oid, ocomps in ECS.query('creature', 'pos') do
                            if not hitSet[oid] and ocomps.creature.hostile and ocomps.creature.state ~= 'dead' then
                                local od = dist(lastX, lastY, ocomps.pos.x, ocomps.pos.y)
                                if od <= def.chainRange and od < bestChainDist then
                                    bestChainDist = od
                                    bestChain = oid
                                end
                            end
                        end
                        if bestChain then
                            hitSet[bestChain] = true
                            if _CreaturesMod and _CreaturesMod.damageCreature then
                                _CreaturesMod.damageCreature(bestChain, chainDmg)
                            else
                                local chainCr = ECS.get(bestChain, 'creature')
                                if chainCr then chainCr.health = chainCr.health - chainDmg end
                            end
                            local chainPos = ECS.get(bestChain, 'pos')
                            if chainPos then
                                if _VFX then
                                    _VFX.spawn('line', lastX, lastY, chainPos.depth or (pos.depth or 0), {
                                        x2 = chainPos.x,
                                        y2 = chainPos.y,
                                        color = { 0.7, 0.86, 1.0, 0.82 },
                                        width = 2,
                                        duration = 0.1,
                                    })
                                end
                                lastX, lastY = chainPos.x, chainPos.y
                            end
                            chainDmg = chainDmg * 0.7  -- decay per jump
                            jumped = jumped + 1
                        else
                            break
                        end
                    end
                end
            end

            -- Railgun penetration: damage all enemies in a line from turret to target
            if def.penetration then
                if targetPos then
                    -- Line from turret to target, extended to max range
                    local dx = targetPos.x - pos.x
                    local dy = targetPos.y - pos.y
                    local len = math.sqrt(dx*dx + dy*dy)
                    if len > 0 then
                        dx, dy = dx/len, dy/len
                        for oid, ocomps in ECS.query('creature', 'pos') do
                            if oid ~= targetId and ocomps.creature.hostile and ocomps.creature.state ~= 'dead' then
                                -- Distance from creature to the line
                                local cx = ocomps.pos.x - pos.x
                                local cy = ocomps.pos.y - pos.y
                                local proj = cx * dx + cy * dy  -- projection along line
                                local perpX = cx - proj * dx
                                local perpY = cy - proj * dy
                                local perpDist = math.sqrt(perpX*perpX + perpY*perpY)
                                if perpDist < 1.5 and proj > 0 and proj <= def.range then
                                    if _CreaturesMod and _CreaturesMod.damageCreature then
                                        _CreaturesMod.damageCreature(oid, def.damage * planetMult * 0.5)
                                    else
                                        ocomps.creature.health = ocomps.creature.health - def.damage * planetMult * 0.5
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        -- Miss: flamethrower turrets set tiles on fire even on miss
        if def.setsFireOnMiss then
            local targetPos = ECS.get(targetId, 'pos')
            if targetPos then
                igniteBurst(targetPos.x, targetPos.y, targetPos.depth or 0, def.igniteRadius or 0, 'flamethrower')
            end
        end
    end

    -- Consume ammo
    if def.ammoUse > 0 then
        turret.ammo = (turret.ammo or 0) - def.ammoUse
    end

    -- Reset cooldown
    turret.cooldown = def.cooldown
end

---------------------------------------------------------------------------
-- Laser fence system — energy barriers that damage creatures on contact
---------------------------------------------------------------------------
-- laser_fence component: { type, active, hp, maxHp, damagePerSec, powerDraw }
-- Types: laser_gate (1-tile door, toggled), laser_fence (1-tile wall, always on),
--        laser_grid (3-tile corridor, RE hallway style)
--        electrified_wall (unpowered = wall, powered = damages on contact)

local LASER_DEFS = {
    laser_gate = {
        name         = 'Laser Gate',
        damagePerSec = 15,
        hp           = 100,
        powerDraw    = 20,
        blockMove    = true,    -- blocks creature pathing when active
        toggleable   = true,    -- can be opened/closed
    },
    laser_fence = {
        name         = 'Laser Fence',
        damagePerSec = 25,
        hp           = 80,
        powerDraw    = 15,
        blockMove    = false,   -- creatures can push through but take damage
        toggleable   = false,
    },
    laser_grid = {
        name         = 'Laser Grid',
        damagePerSec = 40,
        hp           = 60,
        powerDraw    = 30,
        blockMove    = false,   -- passable but lethal
        toggleable   = true,
    },
    electrified_wall = {
        name         = 'Electrified Wall',
        damagePerSec = 10,
        hp           = 200,
        powerDraw    = 10,
        blockMove    = true,
        toggleable   = false,
        stunOnContact = 1.5,    -- stuns on touch
    },
    shield_curtain = {
        name         = 'Shield Curtain',
        damagePerSec = 5,
        hp           = 150,
        powerDraw    = 25,
        blockMove    = true,    -- blocks creatures + projectiles
        toggleable   = true,
        absorbsProjectiles = true,
    },
}

Defenses.LASER_DEFS = LASER_DEFS

function Defenses.isBlockingBarrierAt(x, y, depth)
    lazyLoadDefenses()
    local pd = depth or 0

    for _, comps in ECS.query('laser_fence', 'pos') do
        local pos = comps.pos
        if pos.x == x and pos.y == y and (pos.depth or 0) == pd then
            local fence = comps.laser_fence
            local def = LASER_DEFS[fence.type]
            if def and def.blockMove and (fence.hp or 0) > 0 then
                local powered = true
                if _Power and _Power.isGridPowered then
                    powered = _Power.isGridPowered(pos.x, pos.y)
                end
                local active = powered and (not def.toggleable or fence.toggled ~= false)
                if active then
                    return true
                end
            end
        end
    end

    return false
end

local function laserFenceSystem(dt, id, comps)
    local fence = comps.laser_fence
    local pos   = comps.pos

    local def = LASER_DEFS[fence.type]
    if not def then return end

    -- Power check
    lazyLoadDefenses()
    if _Power then
        local powered = _Power.isGridPowered(pos.x, pos.y)
        if not powered then
            fence.active = false
            return
        end
    end

    -- Toggled off
    if def.toggleable and fence.toggled == false then
        fence.active = false
        return
    end

    fence.active = true
    if fence.hp <= 0 then fence.active = false return end

    -- Damage hostile creatures on this tile
    for cid, ccomps in ECS.query('creature', 'pos') do
        local cr = ccomps.creature
        local cpos = ccomps.pos
        if cr.hostile and cr.state ~= 'dead' and cpos.x == pos.x and cpos.y == pos.y and (cpos.depth or 0) == (pos.depth or 0) then
            cr.health = cr.health - def.damagePerSec * dt
            -- Stun on contact (electrified wall)
            if def.stunOnContact then
                cr.stunTimer = math.max(cr.stunTimer or 0, def.stunOnContact)
            end
            -- Fence takes wear from creature contact
            fence.hp = fence.hp - dt * 2
        end
    end
end

-- Perimeter sensor system — detects hostiles in radius, triggers colony alert
-- sensor component: { radius, cooldown, alertDuration }
local function sensorSystem(dt, id, comps)
    local sensor = comps.sensor
    local pos    = comps.pos

    -- Power check
    lazyLoadDefenses()
    if _Power and not _Power.isGridPowered(pos.x, pos.y) then return end

    sensor.scanTimer = (sensor.scanTimer or 0) + dt
    if sensor.scanTimer < (sensor.scanInterval or 2.0) then return end
    sensor.scanTimer = 0

    local r2 = (sensor.radius or 15) * (sensor.radius or 15)
    local detected = false

    for _, ccomps in ECS.query('creature', 'pos') do
        local cr = ccomps.creature
        local cpos = ccomps.pos
        if cr.hostile and cr.state ~= 'dead' then
            local dx = cpos.x - pos.x
            local dy = cpos.y - pos.y
            if dx*dx + dy*dy <= r2 then
                detected = true
                break
            end
        end
    end

    if detected then
        -- Alert all colonists
        for _, acomps in ECS.query('colonist') do
            local col = acomps.colonist
            if col.state ~= 'dead' then
                col.alertTimer = math.max(col.alertTimer or 0, sensor.alertDuration or 60)
            end
        end
        -- Activate auto-lock on nearby laser gates
        for gid, gcomps in ECS.query('laser_fence', 'pos') do
            local gf = gcomps.laser_fence
            local gpos = gcomps.pos
            local gdef = LASER_DEFS[gf.type]
            if gdef and gdef.toggleable then
                local gdx = gpos.x - pos.x
                local gdy = gpos.y - pos.y
                if gdx*gdx + gdy*gdy <= r2 then
                    gf.toggled = true  -- auto-close gates
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Shield generator system — absorbs damage, regens HP
---------------------------------------------------------------------------

local function shieldSystem(dt, id, comps)
    local shield = comps.shield
    local pos    = comps.pos

    -- Powered check
    lazyLoadDefenses()
    if _Power then
        local powered = _Power.isGridPowered(pos.x, pos.y)
        if not powered then
            shield.active = false
            return
        end
    end
    shield.active = true

    -- Regen cooldown ticks down after taking damage
    if shield.regenCooldown > 0 then
        shield.regenCooldown = shield.regenCooldown - dt
    end

    -- Regen HP when cooldown expired
    if shield.regenCooldown <= 0 and shield.hp < shield.maxHp then
        shield.hp = math.min(shield.maxHp, shield.hp + shield.regenRate * dt)
    end

    -- Absorb damage from hostile creatures inside shield radius
    if shield.hp <= 0 then return end

    for cid, ccomps in ECS.query('creature', 'pos') do
        local cr = ccomps.creature
        if cr.hostile and cr.state ~= 'dead' and (ccomps.pos.depth or 0) == (pos.depth or 0) then
            local d = dist(pos.x, pos.y, ccomps.pos.x, ccomps.pos.y)
            -- Creatures at the shield boundary take push-back damage
            if d <= shield.radius and d >= shield.radius - 1 then
                local pushDmg = 2 * dt
                cr.health = cr.health - pushDmg
                shield.hp = shield.hp - pushDmg * 0.5
                shield.regenCooldown = shield.regenDelay
            end
        end
    end
end

---------------------------------------------------------------------------
-- Register systems
---------------------------------------------------------------------------

function Defenses.registerSystems()
    ECS.addSystem('turret_ai', { 'turret', 'pos' }, turretSystem, 20)
    -- Trap system now in src/combat/traps.lua (registers itself)
    ECS.addSystem('shield_gen', { 'shield', 'pos' }, shieldSystem, 22)
    ECS.addSystem('laser_fence', { 'laser_fence', 'pos' }, laserFenceSystem, 23)
    ECS.addSystem('sensor_scan', { 'sensor', 'pos' }, sensorSystem, 24)
end

Defenses.registerSystems()

return Defenses
