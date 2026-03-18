-- traps.lua — Trap definitions and trigger system
-- Traps are ECS entities with 'trap' + 'pos' components.
-- When hostile creatures step on a trap tile, effects are applied.
-- Ordnance-integrated traps delegate to Ordnance.detonate() for heavy effects.

local ECS = require('src.ecs.ecs')

local Traps = {}

local function dist(x1, y1, x2, y2)
    return math.sqrt((x2-x1)^2 + (y2-y1)^2)
end

---------------------------------------------------------------------------
-- Trap definitions
---------------------------------------------------------------------------

local TRAP_DEFS = {
    -- Tier 1: primitive
    spike = {
        name   = 'Spike Trap',
        damage = 30,
        slow   = 0.5,
        uses   = 1,
    },
    deadfall = {
        name   = 'Deadfall Trap',
        damage = 50,
        slow   = 0.0,
        uses   = 1,
        stun   = 2.0,
    },
    pit = {
        name   = 'Pit Trap',
        damage = 10,
        slow   = 0.0,
        uses   = 3,
        stun   = 4.0,
    },
    snare = {
        name   = 'Snare Trap',
        damage = 5,
        slow   = 1.0,
        uses   = 1,
        stun   = 3.0,
    },

    -- Tier 2: mechanical
    razor_wire = {
        name   = 'Razor Wire',
        damage = 8,
        slow   = 0.6,
        uses   = 10,
        bleed  = 3.0,
    },
    bear_trap = {
        name   = 'Bear Trap',
        damage = 40,
        slow   = 0.0,
        uses   = 1,
        stun   = 5.0,
    },
    spring_blade = {
        name   = 'Spring Blade',
        damage = 60,
        slow   = 0.0,
        uses   = 1,
    },

    -- Tier 3: advanced
    incendiary = {
        name   = 'Incendiary Trap',
        damage = 15,
        slow   = 0.0,
        uses   = 1,
        fire   = true,
    },
    emp_trap = {
        name   = 'EMP Mine',
        damage = 10,
        slow   = 0.0,
        uses   = 1,
        stun   = 6.0,
        aoe    = 3,
    },
    acid_trap = {
        name   = 'Acid Trap',
        damage = 20,
        slow   = 0.3,
        uses   = 1,
        dot    = { damage = 5, duration = 8 },
    },
    cryo_mine = {
        name   = 'Cryo Mine',
        damage = 10,
        slow   = 0.9,
        uses   = 1,
        aoe    = 2,
    },
    frag_mine = {
        name   = 'Frag Mine',
        damage = 45,
        slow   = 0.0,
        uses   = 1,
        aoe    = 3,
    },
    gas_trap = {
        name   = 'Poison Gas Trap',
        damage = 5,
        slow   = 0.3,
        uses   = 1,
        dot    = { damage = 8, duration = 10 },
        aoe    = 4,
        cloudPayload = { radius = 4, duration = 18, severity = 0.18, creatureDamage = 3, slow = 0.3 },
    },

    -- Tier 1b: area denial
    caltrops = {
        name   = 'Caltrops',
        damage = 5,
        slow   = 0.7,
        uses   = 15,
        bleed  = 2.0,
    },
    tripwire_alarm = {
        name   = 'Tripwire Alarm',
        damage = 0,
        slow   = 0.0,
        uses   = 5,
        alarm  = true,
    },

    -- Tier 2b: military
    punji_pit = {
        name   = 'Punji Pit',
        damage = 35,
        slow   = 0.0,
        uses   = 2,
        stun   = 3.0,
        bleed  = 4.0,
    },
    tripwire_ied = {
        name   = 'Tripwire IED',
        damage = 55,
        slow   = 0.0,
        uses   = 1,
        aoe    = 3,
    },
    claymore = {
        name   = 'Claymore Mine',
        damage = 70,
        slow   = 0.0,
        uses   = 1,
        aoe    = 2,
    },

    -- Tier 2b: fire
    fire_pit = {
        name   = 'Fire Pit',
        damage = 10,
        slow   = 0.0,
        uses   = 3,
        fire   = true,
        aoe    = 1,
    },
    napalm_mine = {
        name   = 'Napalm Mine',
        damage = 20,
        slow   = 0.3,
        uses   = 1,
        fire   = true,
        aoe    = 3,
        dot    = { damage = 6, duration = 8 },
        napalmPayload = { radius = 3, duration = 22, potency = 1.1 },
    },

    -- Tier 3: ordnance-integrated traps (use Ordnance.detonate for effects)
    foam_trap = {
        name   = 'Foam Trap',
        damage = 0,
        slow   = 0.2,
        uses   = 1,
        aoe    = 3,
        ordnanceType = 'foam_grenade',
    },
    napalm_tripwire = {
        name   = 'Napalm Tripwire',
        damage = 15,
        slow   = 0.0,
        uses   = 1,
        aoe    = 3,
        ordnanceType = 'napalm_grenade',
    },
    emp_floor_mine = {
        name   = 'EMP Floor Mine',
        damage = 5,
        slow   = 0.0,
        uses   = 1,
        aoe    = 4,
        stun   = 5.0,
        ordnanceType = 'emp_grenade',
    },

    -- Tier 4: ordnance-integrated heavy traps
    bio_mine = {
        name   = 'Bio Mine',
        damage = 5,
        slow   = 0.0,
        uses   = 1,
        aoe    = 4,
        ordnanceType = 'bio_grenade',
    },
    concussion_mine = {
        name   = 'Concussion Mine',
        damage = 70,
        slow   = 0.0,
        uses   = 1,
        aoe    = 4,
        stun   = 4.0,
        terrainDamage = true,
    },
    thermobaric_trap = {
        name   = 'Thermobaric Trap',
        damage = 60,
        slow   = 0.0,
        uses   = 1,
        aoe    = 5,
        stun   = 3.0,
        oxygenDrain = true,
    },

    -- Tier 5: endgame traps
    sinkhole_charge = {
        name   = 'Sinkhole Charge',
        damage = 40,
        slow   = 0.0,
        uses   = 1,
        aoe    = 2,
        floorCollapse = true,
        terrainDamage = true,
    },
    nuclear_mine = {
        name   = 'Nuclear Mine',
        damage = 100,
        slow   = 0.0,
        uses   = 1,
        aoe    = 6,
        ordnanceType = 'briefcase_nuke',
    },

    -- Mechanical / area control
    barbed_fence = {
        name   = 'Barbed Fence',
        damage = 6,
        slow   = 0.5,
        uses   = 12,
        bleed  = 3.0,
    },
    pressure_plate = {
        name   = 'Pressure Plate',
        damage = 0,
        slow   = 0.0,
        uses   = 3,
        alarm  = true,
        chainTrigger = true,
        chainRadius  = 2,
    },
    bait_lure = {
        name   = 'Bait Lure',
        damage = 0,
        slow   = 0.0,
        uses   = 1,
        lure   = true,
        lureRadius = 10,
    },
    directional_mine = {
        name   = 'Directional Mine',
        damage = 90,
        slow   = 0.0,
        uses   = 1,
        aoe    = 3,
        directional = true,
    },
    chain_mine = {
        name   = 'Chain Mine',
        damage = 40,
        slow   = 0.0,
        uses   = 1,
        aoe    = 2,
        chainDetonation = true,
        chainRange = 4,
    },
}

Traps.TRAP_DEFS = TRAP_DEFS

---------------------------------------------------------------------------
-- Planet-based trap damage modifiers
---------------------------------------------------------------------------
local function getTrapPlanetMult(trapType)
    local pok, Planet = pcall(require, 'src.world.planet')
    local planetId = pok and Planet.getId() or 'erebus'

    if trapType == 'incendiary' or trapType == 'fire_pit'
       or trapType == 'napalm_mine' or trapType == 'napalm_tripwire' then
        if planetId == 'nerthus_9' then return 0.5 end      -- wet environment douses flames
        if planetId == 'rhea_2' then return 1.5 end          -- dry air feeds fire
    elseif trapType == 'emp_trap' or trapType == 'emp_floor_mine' then
        if planetId == 'nerthus_9' then return 1.5 end       -- water conducts electricity
        if planetId == 'rhea_2' then return 0.7 end          -- dry air resists conduction
    elseif trapType == 'acid_trap' then
        if planetId == 'morvos' then return 0.5 end          -- creatures are acid-resistant
    elseif trapType == 'gas_trap' then
        if planetId == 'nemaea' then return 0 end            -- no atmosphere to carry gas
        if planetId == 'morvos' then return 0.5 end          -- toxic atmosphere dilutes gas
    elseif trapType == 'cryo_mine' then
        if planetId == 'nemaea' then return 0.1 end          -- already frozen, nearly useless
        if planetId == 'rhea_2' then return 1.5 end          -- cold very effective in desert
    elseif trapType == 'thermobaric_trap' then
        if planetId == 'nemaea' then return 0.3 end          -- needs atmosphere for blast wave
    end
    return 1.0
end

---------------------------------------------------------------------------
-- Trap trigger system
---------------------------------------------------------------------------

local function trapSystem(dt, id, comps)
    local trap = comps.trap
    local pos  = comps.pos

    if not trap.armed then return end

    local def = TRAP_DEFS[trap.type]
    if not def then return end

    -- Lure traps: attract creatures rather than damaging them
    if def.lure then
        local lureR = def.lureRadius or 10
        for _, ccomps in ECS.query('creature', 'pos') do
            local cr = ccomps.creature
            local cpos = ccomps.pos
            if cr.hostile and cr.state ~= 'dead' then
                local d = dist(pos.x, pos.y, cpos.x, cpos.y)
                if d > 1 and d <= lureR then
                    cr.lureX = pos.x
                    cr.lureY = pos.y
                end
                if cpos.x == pos.x and cpos.y == pos.y then
                    trap.uses = trap.uses - 1
                    if trap.uses <= 0 then
                        trap.armed = false
                        ECS.destroy(id)
                    end
                    return
                end
            end
        end
        return
    end

    -- Check for hostile creatures on this tile
    local triggerRange = (def.aoe or 0)
    for cid, ccomps in ECS.query('creature', 'pos') do
        local cr = ccomps.creature
        local cpos = ccomps.pos
        if cr.hostile and cr.state ~= 'dead' then
            local onTile = (cpos.x == pos.x and cpos.y == pos.y)
            if not onTile then goto next_creature end

            -- Trigger! Apply to this creature and AOE targets
            local targets = { { id = cid, cr = cr, dist = 0 } }

            -- Gather AOE targets
            if triggerRange > 0 then
                -- Directional mines: compute trigger direction from triggering creature
                local dirX, dirY = 0, 0
                if def.directional then
                    dirX = cpos.x - pos.x
                    dirY = cpos.y - pos.y
                    local len = math.sqrt(dirX*dirX + dirY*dirY)
                    if len > 0 then dirX, dirY = dirX/len, dirY/len
                    else dirX, dirY = 0, 1 end
                end

                for oid, ocomps in ECS.query('creature', 'pos') do
                    if oid ~= cid and ocomps.creature.hostile and ocomps.creature.state ~= 'dead' then
                        local od = dist(pos.x, pos.y, ocomps.pos.x, ocomps.pos.y)
                        if od <= triggerRange then
                            -- Directional filter: 120-degree cone in trigger direction
                            if def.directional and od > 0 then
                                local tdx = (ocomps.pos.x - pos.x) / od
                                local tdy = (ocomps.pos.y - pos.y) / od
                                local dotVal = tdx * dirX + tdy * dirY
                                if dotVal < 0.5 then goto skip_aoe end
                            end
                            targets[#targets + 1] = { id = oid, cr = ocomps.creature, dist = od }
                        end
                    end
                    ::skip_aoe::
                end
            end

            -- Apply effects to all targets
            local planetMult = getTrapPlanetMult(trap.type)
            for _, t in ipairs(targets) do
                local dmgMult = t.dist > 0 and (1 - t.dist / math.max(1, triggerRange)) * 0.6 or 1.0
                t.cr.health = t.cr.health - def.damage * dmgMult * planetMult

                if def.stun then
                    t.cr.stunTimer = (t.cr.stunTimer or 0) + def.stun * dmgMult
                end

                if def.slow and def.slow > 0 then
                    t.cr.slowMult = math.min(t.cr.slowMult or 1.0, 1 - def.slow)
                    t.cr.slowTimer = 3.0
                end

                if def.bleed then
                    t.cr.bleedTimer = (t.cr.bleedTimer or 0) + def.bleed
                end

                if def.dot and planetMult > 0 then
                    t.cr.dotDamage   = def.dot.damage * planetMult
                    t.cr.dotDuration = def.dot.duration
                end
            end

            -- Ordnance detonation: delegate to ordnance system
            if def.ordnanceType then
                local ook, OrdMod = pcall(require, 'src.combat.ordnance')
                if ook and OrdMod.detonate then
                    OrdMod.detonate(pos.x, pos.y, def.ordnanceType, pos.depth or 0)
                end
            end

            if def.napalmPayload or def.cloudPayload then
                local ook, OrdMod = pcall(require, 'src.combat.ordnance')
                if ook and OrdMod then
                    if def.napalmPayload and OrdMod.spawnNapalmField and planetMult > 0 then
                        OrdMod.spawnNapalmField(
                            pos.x,
                            pos.y,
                            pos.depth or 0,
                            def.napalmPayload.radius,
                            def.napalmPayload.duration,
                            def.napalmPayload.potency * planetMult
                        )
                    end
                    if def.cloudPayload and OrdMod.spawnToxicCloud and planetMult > 0 then
                        OrdMod.spawnToxicCloud(
                            pos.x,
                            pos.y,
                            pos.depth or 0,
                            def.cloudPayload.radius,
                            def.cloudPayload.duration,
                            def.cloudPayload.severity * planetMult,
                            def.cloudPayload.creatureDamage * planetMult,
                            def.cloudPayload.slow
                        )
                    end
                end
            end

            -- Alarm: alert colonists to hostile presence
            if def.alarm then
                for _, acomps in ECS.query('colonist') do
                    local col = acomps.colonist
                    if col.state ~= 'dead' then
                        col.alertTimer = (col.alertTimer or 0) + 30.0
                    end
                end
            end

            -- Fire effect
            if def.fire then
                local fok, Fire = pcall(require, 'src.sim.fire')
                if fok then Fire.ignite(pos.x, pos.y, 'trap', pos.depth) end
            end

            -- Terrain damage (concussion mine, sinkhole)
            if def.terrainDamage then
                local wok, World = pcall(require, 'src.world.tilemap')
                local tok, Tiles = pcall(require, 'src.world.tiles')
                if wok and tok then
                    local innerR = math.max(1, math.floor((def.aoe or 1) / 2))
                    for tdy = -innerR, innerR do
                        for tdx = -innerR, innerR do
                            if tdx*tdx + tdy*tdy <= innerR*innerR then
                                local tx, ty = pos.x + tdx, pos.y + tdy
                                if World.inBounds(tx, ty) then
                                    World.setTile(tx, ty, Tiles.DEBRIS, pos.depth or 0)
                                end
                            end
                        end
                    end
                end
            end

            -- Floor collapse (sinkhole charge): drop creatures to depth below
            if def.floorCollapse then
                local wok, World = pcall(require, 'src.world.tilemap')
                local tok, Tiles = pcall(require, 'src.world.tiles')
                if wok and tok then
                    local belowDepth = (pos.depth or 0) + 1
                    local layer = World.getLayer and World.getLayer(belowDepth)
                    if layer then
                        local collapseR = def.aoe or 2
                        for tdy = -collapseR, collapseR do
                            for tdx = -collapseR, collapseR do
                                if tdx*tdx + tdy*tdy <= collapseR*collapseR then
                                    local tx, ty = pos.x + tdx, pos.y + tdy
                                    if World.inBounds(tx, ty) then
                                        World.setTile(tx, ty, Tiles.UNDERGROUND_FLOOR, pos.depth or 0)
                                    end
                                end
                            end
                        end
                        for fid, fcomps in ECS.query('creature', 'pos') do
                            local fp = fcomps.pos
                            if (fp.depth or 0) == (pos.depth or 0) then
                                local fdx = fp.x - pos.x
                                local fdy = fp.y - pos.y
                                if fdx*fdx + fdy*fdy <= collapseR*collapseR then
                                    fp.depth = belowDepth
                                    local crok, CreMod = pcall(require, 'src.creatures.creatures')
                                    if crok and CreMod.damageCreature then
                                        CreMod.damageCreature(fid, 30)
                                    else
                                        fcomps.creature.health = fcomps.creature.health - 30
                                    end
                                    fcomps.creature.stunTimer = (fcomps.creature.stunTimer or 0) + 4.0
                                end
                            end
                        end
                    end
                end
            end

            -- Oxygen drain (thermobaric): flood area with CO2, displacing O2
            if def.oxygenDrain then
                local aok, Atmo = pcall(require, 'src.sim.atmosphere')
                if aok and Atmo.injectCO2 then
                    local drainR = def.aoe or 3
                    for tdy = -drainR, drainR do
                        for tdx = -drainR, drainR do
                            if tdx*tdx + tdy*tdy <= drainR*drainR then
                                Atmo.injectCO2(pos.x + tdx, pos.y + tdy, 40)
                            end
                        end
                    end
                end
            end

            -- Chain trigger: detonate all placed ordnance within radius
            if def.chainTrigger and def.chainRadius then
                local ook, OrdMod = pcall(require, 'src.combat.ordnance')
                if ook then
                    local chainR2 = def.chainRadius * def.chainRadius
                    for oid, ocomps in ECS.query('ordnance', 'pos') do
                        local op = ocomps.pos
                        local odx = op.x - pos.x
                        local ody = op.y - pos.y
                        if odx*odx + ody*ody <= chainR2 then
                            OrdMod.trigger(oid)
                        end
                    end
                end
            end

            -- Chain detonation: trigger other chain_mine traps in range
            if def.chainDetonation and def.chainRange then
                local chainR2 = def.chainRange * def.chainRange
                for oid, ocomps in ECS.query('trap', 'pos') do
                    if oid ~= id then
                        local otrap = ocomps.trap
                        local opos  = ocomps.pos
                        local oDef  = TRAP_DEFS[otrap.type]
                        if oDef and oDef.chainDetonation and otrap.armed then
                            local odx = opos.x - pos.x
                            local ody = opos.y - pos.y
                            if odx*odx + ody*ody <= chainR2 then
                                otrap.armed = false
                                for _, fcomps in ECS.query('creature', 'pos') do
                                    local fp = fcomps.pos
                                    local fcr = fcomps.creature
                                    if fcr.hostile and fcr.state ~= 'dead' then
                                        local fd = dist(opos.x, opos.y, fp.x, fp.y)
                                        if fd <= (oDef.aoe or 2) then
                                            local falloff = 1 - fd / math.max(1, oDef.aoe or 2)
                                            fcr.health = fcr.health - oDef.damage * falloff
                                        end
                                    end
                                end
                                otrap.uses = 0
                                ECS.destroy(oid)
                            end
                        end
                    end
                end
            end

            -- Consume uses
            trap.uses = trap.uses - 1
            if trap.uses <= 0 then
                trap.armed = false
                ECS.destroy(id)
            end
            return
        end
        ::next_creature::
    end
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

function Traps.registerSystems()
    ECS.addSystem('trap_trigger', { 'trap', 'pos' }, trapSystem, 21)
end

Traps.registerSystems()

return Traps
