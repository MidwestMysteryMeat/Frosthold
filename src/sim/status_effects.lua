-- status_effects.lua — Status effect system with per-tick application and recovery
-- Effects: frostbite (body-part cold damage), heatstroke, burning, infection, exhaustion
-- Each effect has a severity (0-1), per-tick damage, and recovery chance.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local StatusEffects = {}

---------------------------------------------------------------------------
-- Effect definitions
---------------------------------------------------------------------------

local EFFECTS = {
    frostbite = {
        id = 'frostbite',
        name = 'Frostbite',
        -- Severity tiers: mild (0-0.3), moderate (0.3-0.6), severe (0.6-1.0)
        tickDamage   = 0.3,      -- HP per second at severity 1.0
        workDebuff   = 0.25,     -- work speed penalty at severity 1.0
        moveDebuff   = 0.15,     -- move speed penalty at severity 1.0
        recoveryBase = 0.02,     -- base recovery per second when warm
        warmthThreshold = 25,    -- warmth below this triggers frostbite risk
    },
    infection = {
        id = 'infection',
        name = 'Wound Infection',
        tickDamage   = 0.5,
        workDebuff   = 0.2,
        moveDebuff   = 0.1,
        recoveryBase = 0.005,    -- slow natural recovery
    },
    exhaustion = {
        id = 'exhaustion',
        name = 'Exhaustion',
        tickDamage   = 0.1,
        workDebuff   = 0.4,
        moveDebuff   = 0.3,
        recoveryBase = 0.03,     -- recovers when resting
    },
    burning = {
        id = 'burning',
        name = 'Burning',
        tickDamage   = 2.0,
        workDebuff   = 0.5,
        moveDebuff   = 0.2,
        recoveryBase = 0.08,     -- recovers quickly when off fire tiles
    },
    radiation_sickness = {
        id = 'radiation_sickness',
        name = 'Radiation Sickness',
        tickDamage   = 0.2,      -- mild ongoing damage
        workDebuff   = 0.35,     -- significant work penalty
        moveDebuff   = 0.2,
        recoveryBase = 0.015,    -- slow recovery when away from source
    },
    toxic_exposure = {
        id = 'toxic_exposure',
        name = 'Toxic Exposure',
        tickDamage   = 0.4,
        workDebuff   = 0.3,
        moveDebuff   = 0.15,
        recoveryBase = 0.025,
    },
    heatstroke = {
        id = 'heatstroke',
        name = 'Heatstroke',
        -- Severity tiers: mild (0-0.3), moderate (0.3-0.6), severe (0.6-1.0)
        tickDamage   = 0.2,      -- HP per second at severity 1.0
        workDebuff   = 0.3,      -- work speed penalty at severity 1.0
        moveDebuff   = 0.2,      -- move speed penalty at severity 1.0
        recoveryBase = 0.02,     -- base recovery per second when cooled
        warmthThreshold = 80,    -- warmth above this triggers heatstroke risk
        recoverThreshold = 50,   -- warmth below this allows recovery
    },
}

StatusEffects.EFFECTS = EFFECTS

---------------------------------------------------------------------------
-- Ensure entity has status_effects component
---------------------------------------------------------------------------

local function ensureComponent(entityId)
    if not ECS.has(entityId, 'status_effects') then
        ECS.set(entityId, 'status_effects', { active = {} })
    end
    return ECS.get(entityId, 'status_effects')
end

---------------------------------------------------------------------------
-- Apply or worsen an effect
---------------------------------------------------------------------------

function StatusEffects.apply(entityId, effectId, severity)
    local def = EFFECTS[effectId]
    if not def then return end

    local se = ensureComponent(entityId)
    local existing = se.active[effectId]

    if existing then
        -- Stack: increase severity (capped at 1.0)
        existing.severity = math.min(1.0, existing.severity + (severity or 0.1))
    else
        se.active[effectId] = {
            id       = effectId,
            severity = math.min(1.0, severity or 0.1),
            duration = 0,  -- time active
        }
    end
end

---------------------------------------------------------------------------
-- Remove an effect
---------------------------------------------------------------------------

function StatusEffects.remove(entityId, effectId)
    local se = ECS.get(entityId, 'status_effects')
    if se then
        se.active[effectId] = nil
    end
end

---------------------------------------------------------------------------
-- Query: get effect severity (0 if not present)
---------------------------------------------------------------------------

function StatusEffects.getSeverity(entityId, effectId)
    local se = ECS.get(entityId, 'status_effects')
    if not se or not se.active[effectId] then return 0 end
    return se.active[effectId].severity
end

---------------------------------------------------------------------------
-- Query: total work speed multiplier from all active effects
---------------------------------------------------------------------------

function StatusEffects.getWorkSpeedMult(entityId)
    local se = ECS.get(entityId, 'status_effects')
    if not se then return 1.0 end

    local mult = 1.0
    for effectId, state in pairs(se.active) do
        local def = EFFECTS[effectId]
        if def then
            mult = mult * (1 - def.workDebuff * state.severity)
        end
    end
    return math.max(0.1, mult)
end

---------------------------------------------------------------------------
-- Query: total move speed multiplier from all active effects
---------------------------------------------------------------------------

function StatusEffects.getMoveSpeedMult(entityId)
    local se = ECS.get(entityId, 'status_effects')
    if not se then return 1.0 end

    local mult = 1.0
    for effectId, state in pairs(se.active) do
        local def = EFFECTS[effectId]
        if def then
            mult = mult * (1 - def.moveDebuff * state.severity)
        end
    end
    return math.max(0.1, mult)
end

---------------------------------------------------------------------------
-- Query: list all active effects for UI display
---------------------------------------------------------------------------

function StatusEffects.getActive(entityId)
    local se = ECS.get(entityId, 'status_effects')
    if not se then return {} end

    local list = {}
    for effectId, state in pairs(se.active) do
        local def = EFFECTS[effectId]
        list[#list + 1] = {
            id       = effectId,
            name     = def and def.name or effectId,
            severity = state.severity,
            duration = state.duration,
        }
    end
    return list
end

---------------------------------------------------------------------------
-- Area effect: apply a status effect to all colonists within radius
-- Called by pipes.lua for toxic spills, radiation.lua for proximity
---------------------------------------------------------------------------

function StatusEffects.applyArea(x, y, radius, effectId, dt)
    local severity = 0.05 * (dt or 0.05)
    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        local pos = comps.pos
        if col.state ~= 'dead' then
            local dx = math.abs(pos.x - x)
            local dy = math.abs(pos.y - y)
            if dx <= radius and dy <= radius then
                local dist = math.max(dx, dy)
                local falloff = 1.0 - dist / (radius + 1)
                StatusEffects.apply(id, effectId, severity * falloff)
            end
        end
    end
end

---------------------------------------------------------------------------
-- ECS system: tick all status effects (damage, recovery, frostbite trigger)
---------------------------------------------------------------------------

local function statusEffectSystem(dt, id, comps)
    local col   = comps.colonist
    local needs = comps.needs
    if col.state == 'dead' then return end

    local se = ECS.get(id, 'status_effects')
    if not se then return end

    -- Tick each active effect
    local toRemove = {}
    for effectId, state in pairs(se.active) do
        local def = EFFECTS[effectId]
        if not def then
            toRemove[#toRemove + 1] = effectId
        else
            state.duration = state.duration + dt

            -- Apply tick damage (scaled by severity)
            local dmg = def.tickDamage * state.severity * dt
            if dmg > 0 then
                col.health = col.health - dmg
            end

            -- Recovery: chance to reduce severity each tick
            local recoveryRate = def.recoveryBase
            local recovering = false

            if effectId == 'frostbite' then
                -- Frostbite recovers when warm, worsens when cold
                if needs.warmth >= 60 then
                    recovering = true
                    recoveryRate = def.recoveryBase * (needs.warmth / 60)
                elseif needs.warmth < def.warmthThreshold then
                    -- Worsening: add severity
                    local worsenRate = (def.warmthThreshold - needs.warmth) / 100 * 0.01
                    state.severity = math.min(1.0, state.severity + worsenRate * dt)
                end
            elseif effectId == 'heatstroke' then
                -- Heatstroke recovers when cool, worsens when overheated
                if needs.warmth <= def.recoverThreshold then
                    recovering = true
                    recoveryRate = def.recoveryBase * ((def.recoverThreshold + 10) / math.max(1, needs.warmth + 10))
                elseif needs.warmth > def.warmthThreshold then
                    -- Worsening: add severity based on how far above threshold
                    local worsenRate = (needs.warmth - def.warmthThreshold) / 100 * 0.01
                    state.severity = math.min(1.0, state.severity + worsenRate * dt)
                end
            elseif effectId == 'exhaustion' then
                -- Exhaustion recovers when resting
                if col.state == 'sleeping' then
                    recovering = true
                    recoveryRate = def.recoveryBase * 3
                elseif needs.rest > 70 then
                    recovering = true
                end
            elseif effectId == 'infection' then
                -- Infection recovers with medical treatment (check for medicated wounds)
                local wok, Wounds = pcall(require, 'src.combat.wounds')
                if wok and not Wounds.hasUntreatedWounds(id) then
                    recovering = true
                    recoveryRate = def.recoveryBase * 2
                end
            elseif effectId == 'burning' then
                -- Burning recovers when not on a fire tile
                local pos = ECS.get(id, 'pos')
                local onFire = false
                if pos then
                    local fok, FireMod = pcall(require, 'src.sim.fire')
                    if fok and FireMod.isOnFire then
                        onFire = FireMod.isOnFire(pos.x, pos.y, pos.depth or 0)
                    end
                end
                if not onFire then
                    recovering = true
                    recoveryRate = def.recoveryBase * 2
                end
            elseif effectId == 'radiation_sickness' then
                -- Recovers when away from radiation sources
                local radOk, RadMod = pcall(require, 'src.sim.radiation')
                local pos = ECS.get(id, 'pos')
                local exposed = false
                if radOk and pos then
                    exposed = RadMod.getDoseRate(pos.x, pos.y, pos.depth or 0) > 0
                end
                if not exposed then
                    recovering = true
                end
            elseif effectId == 'toxic_exposure' then
                -- Recovers when away from toxic spills
                recovering = true
            end

            if recovering then
                state.severity = state.severity - recoveryRate * dt
                if state.severity <= 0 then
                    toRemove[#toRemove + 1] = effectId
                end
            end
        end
    end

    for _, effectId in ipairs(toRemove) do
        se.active[effectId] = nil
    end

    -- Frostbite trigger: low warmth + no existing frostbite = risk
    if needs.warmth < (EFFECTS.frostbite.warmthThreshold) then
        if not se.active.frostbite then
            -- Chance per tick based on how cold
            local risk = (EFFECTS.frostbite.warmthThreshold - needs.warmth) / 100 * 0.005
            if math.random() < risk then
                StatusEffects.apply(id, 'frostbite', 0.1)
            end
        end
    end

    -- Heatstroke trigger: high warmth + no existing heatstroke = risk
    if needs.warmth > (EFFECTS.heatstroke.warmthThreshold) then
        if not se.active.heatstroke then
            -- Chance per tick based on how hot
            local risk = (needs.warmth - EFFECTS.heatstroke.warmthThreshold) / 100 * 0.005
            if math.random() < risk then
                StatusEffects.apply(id, 'heatstroke', 0.1)
            end
        end
    end

    -- Exhaustion trigger: critically low rest
    if needs.rest < 10 and not se.active.exhaustion then
        if math.random() < 0.01 then
            StatusEffects.apply(id, 'exhaustion', 0.2)
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function StatusEffects.registerSystems()
    ECS.addSystem('status_effects', { 'colonist', 'needs' }, statusEffectSystem, 11)
end

StatusEffects.registerSystems()

return StatusEffects
