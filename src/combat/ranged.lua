-- ranged.lua -- Ranged combat system
-- Projectile entities: spawn at shooter position, move toward target, hit check on arrival.
-- Accuracy modified by weapon base accuracy + hunting skill (+5% per level).

local ECS       = require('src.ecs.ecs')
local Equipment = require('src.colonist.equipment')
local Body      = require('src.combat.body')
local Wounds    = require('src.combat.wounds')
local Creatures = require('src.creatures.creatures')
local GameState = require('src.game_state')

local Ranged = {}

---------------------------------------------------------------------------
-- Projectile speed (tiles per second)
---------------------------------------------------------------------------

local PROJECTILE_SPEED = 12

---------------------------------------------------------------------------
-- Fire a projectile from shooter toward target
---------------------------------------------------------------------------

function Ranged.fire(shooterId, targetId)
    local shooterPos = ECS.get(shooterId, 'pos')
    local targetPos  = ECS.get(targetId, 'pos')
    if not shooterPos or not targetPos then return nil end

    -- Calculate accuracy
    local baseAccuracy = Equipment.getWeaponAccuracy(shooterId)
    local col = ECS.get(shooterId, 'colonist')
    local huntingSkill = 0
    if col and col.skills then
        huntingSkill = col.skills.hunting or 0
    end

    -- +5% per hunting skill level
    local accuracy = baseAccuracy + huntingSkill * 0.05

    -- Trait huntMod: eagle_eye +15% accuracy
    if col and col.traits then
        for _, t in ipairs(col.traits) do
            if t.huntMod then accuracy = accuracy + t.huntMod end
        end
    end

    -- Sharpshooter mastery: +20% ranged accuracy
    local sok, Skills = pcall(require, 'src.colonist.skills')
    if sok and Skills.hasMastery(shooterId, 'sharpshooter') then
        local effect = Skills.getMasteryEffect(shooterId, 'sharpshooter')
        if effect then accuracy = accuracy + (effect.accuracyBonus or 0) end
    end

    -- Combat trait modifier (brave +10%, night_fighter +8%)
    if col and col.traits then
        local combatMod = 0
        for _, t in ipairs(col.traits) do
            if t.combatMod then combatMod = combatMod + t.combatMod end
        end
        accuracy = accuracy + combatMod
    end

    -- Scope accessory bonus
    accuracy = accuracy + Equipment.getAccessoryEffect(shooterId, 'accuracy')

    -- Clamp to 0.05 - 0.99 (always a tiny miss chance, always a tiny hit chance)
    accuracy = math.max(0.05, math.min(0.99, accuracy))

    local damage = Equipment.getWeaponDamage(shooterId)

    -- Drug damage buff
    local addOk, AddictionMod = pcall(require, 'src.colonist.addiction')
    if addOk and AddictionMod.getDamageMult then
        damage = math.floor(damage * AddictionMod.getDamageMult(shooterId))
    end

    -- Spawn projectile entity
    local projId = ECS.spawn()

    -- Floating point position for smooth movement
    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.01 then dist = 1 end

    ECS.set(projId, 'pos', {
        x = shooterPos.x,
        y = shooterPos.y,
        prevX = shooterPos.x,
        prevY = shooterPos.y,
        depth = shooterPos.depth or 0,
    })

    -- Get damage type from weapon
    local damageType = Equipment.getWeaponDamageType(shooterId)

    ECS.set(projId, 'projectile', {
        shooterId  = shooterId,
        targetId   = targetId,
        damage     = damage,
        damageType = damageType,
        accuracy   = accuracy,
        -- Normalized direction
        dirX       = dx / dist,
        dirY       = dy / dist,
        speed      = PROJECTILE_SPEED,
        traveled   = 0,
        maxDist    = dist,
        -- Float position for sub-tile movement
        fx         = shooterPos.x,
        fy         = shooterPos.y,
    })

    -- Gunfire generates noise for AI Director
    local dok, Dir = pcall(require, 'src.ai.director')
    if dok then Dir.onNoise(shooterPos.x, shooterPos.y, 2.0) end

    return projId
end

---------------------------------------------------------------------------
-- Distance-squared helper
---------------------------------------------------------------------------

local function distSq(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return dx * dx + dy * dy
end

---------------------------------------------------------------------------
-- Check if shooter is in range of target
---------------------------------------------------------------------------

function Ranged.inRange(shooterId, targetId)
    local sPos = ECS.get(shooterId, 'pos')
    local tPos = ECS.get(targetId, 'pos')
    if not sPos or not tPos then return false end

    local range = Equipment.getWeaponRange(shooterId)
    return distSq(sPos.x, sPos.y, tPos.x, tPos.y) <= range * range
end

---------------------------------------------------------------------------
-- Apply hit to target (creature or colonist)
---------------------------------------------------------------------------

local function applyHit(targetId, damage, shooterId, damageType)
    damageType = damageType or 'sharp'
    local dtOk, DmgTypes = pcall(require, 'src.combat.damage_types')

    -- Target is a creature
    local cr = ECS.get(targetId, 'creature')
    if cr then
        -- Award ranged combat XP
        local sok, Skills = pcall(require, 'src.colonist.skills')
        if sok then Skills.onCombatHit(shooterId, damage) end
        -- Apply armor-like reduction from creature tier
        local killed = Creatures.damageCreature(targetId, damage, shooterId)
        return killed
    end

    -- Target is a colonist (friendly fire or PvE counterattack scenario)
    local col = ECS.get(targetId, 'colonist')
    if col then
        -- Apply typed armor resistance
        local armorResist = Equipment.getArmorResist(targetId)
        local finalDmg
        if dtOk and armorResist then
            finalDmg = DmgTypes.applyArmor(damage, damageType, armorResist)
        else
            -- Fallback to flat reduction
            local reduction = Equipment.getArmorReduction(targetId)
            local addOk2, AddictionMod2 = pcall(require, 'src.colonist.addiction')
            if addOk2 and AddictionMod2.getArmorMult then
                reduction = math.floor(reduction * AddictionMod2.getArmorMult(targetId))
            end
            finalDmg = math.max(1, damage - reduction)
        end

        -- Scar tissue trait: 10% damage reduction from hardened skin
        if col.traits then
            for _, t in ipairs(col.traits) do
                if t.id == 'scar_tissue' then
                    finalDmg = math.max(1, math.floor(finalDmg * 0.9))
                    break
                end
            end
        end

        -- Defensive stance damage reduction
        local caOk, CombatAIMod = pcall(require, 'src.combat.combat_ai')
        if caOk then
            local stance = CombatAIMod.getStance(targetId)
            if stance.damageReduction > 0 then
                finalDmg = math.max(1, math.floor(finalDmg * (1 - stance.damageReduction)))
            end
        end

        -- Hit a random body part
        local partName = Body.randomPart()
        local killed = Body.damagePart(targetId, partName, finalDmg)

        -- Apply wound based on damage type
        local severity, woundType
        if dtOk then
            severity, woundType = DmgTypes.calcWoundSeverity(finalDmg, damageType)
        else
            severity = math.min(1.0, finalDmg / 20)
            woundType = 'cut'
        end
        Wounds.apply(targetId, partName, woundType, severity)

        -- Check for special effects (stun, extra infection)
        if dtOk then
            local fx = DmgTypes.getSpecialEffects(damageType)
            if fx.stunChance and math.random() < fx.stunChance then
                local sfxOk, StatusFx = pcall(require, 'src.sim.status_effects')
                if sfxOk and StatusFx.apply then StatusFx.apply(targetId, 'stunned') end
            end
        end

        -- Also reduce overall health
        col.health = math.max(0, col.health - finalDmg)
        if col.health <= 0 or killed then
            local cOk, ColMod = pcall(require, 'src.colonist.colonist')
            if cOk then ColMod.kill(targetId) end
            return true
        end
    end

    return false
end

---------------------------------------------------------------------------
-- ECS system: projectile movement and hit resolution
---------------------------------------------------------------------------

local function projectileSystem(dt, id, comps)
    local proj = comps.projectile
    local pos  = comps.pos

    pos.prevX = pos.x
    pos.prevY = pos.y

    -- Move projectile along direction
    local moveDist = proj.speed * dt
    proj.fx = proj.fx + proj.dirX * moveDist
    proj.fy = proj.fy + proj.dirY * moveDist
    proj.traveled = proj.traveled + moveDist

    -- Update tile position
    pos.x = math.floor(proj.fx + 0.5)
    pos.y = math.floor(proj.fy + 0.5)

    -- Arrived at target distance?
    if proj.traveled >= proj.maxDist then
        -- Skip missiles — handled by missileArrivalSystem
        if proj.isMissile then return end

        -- Hit check
        local hit = math.random() < proj.accuracy

        if hit and ECS.isAlive(proj.targetId) then
            -- Verify target is still on same depth layer
            local targetPos = ECS.get(proj.targetId, 'pos')
            if targetPos and (targetPos.depth or 0) == (pos.depth or 0) then
                applyHit(proj.targetId, proj.damage, proj.shooterId, proj.damageType)
            end
        end

        -- Projectile consumed
        ECS.destroy(id)
    end
end

---------------------------------------------------------------------------
-- Creature ranged fire — no Equipment dependency, uses species stats
---------------------------------------------------------------------------

function Ranged.creatureFire(shooterId, targetId, damage, accuracy)
    local shooterPos = ECS.get(shooterId, 'pos')
    local targetPos  = ECS.get(targetId, 'pos')
    if not shooterPos or not targetPos then return nil end

    -- Clamp accuracy
    accuracy = math.max(0.05, math.min(0.99, accuracy))

    -- Spawn projectile entity
    local projId = ECS.spawn()

    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.01 then dist = 1 end

    ECS.set(projId, 'pos', {
        x = shooterPos.x,
        y = shooterPos.y,
        prevX = shooterPos.x,
        prevY = shooterPos.y,
        depth = shooterPos.depth or 0,
    })

    ECS.set(projId, 'projectile', {
        shooterId = shooterId,
        targetId  = targetId,
        damage    = damage,
        accuracy  = accuracy,
        dirX      = dx / dist,
        dirY      = dy / dist,
        speed     = PROJECTILE_SPEED,
        traveled  = 0,
        maxDist   = dist,
        fx        = shooterPos.x,
        fy        = shooterPos.y,
    })

    -- Gunfire generates noise for AI Director
    local dok, Dir = pcall(require, 'src.ai.director')
    if dok then Dir.onNoise(shooterPos.x, shooterPos.y, 2.0) end

    return projId
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Ranged.registerSystems()
    ECS.addSystem('projectile_move', { 'projectile', 'pos' }, projectileSystem, 22)
end

Ranged.registerSystems()

return Ranged
