-- combat_ai.lua -- Colonist combat AI
-- Fight-or-flee decisions based on health, traits, weapon equipped.
-- Auto-targets nearest hostile creature in range. Cowards flee at 70% HP,
-- brave colonists fight to 20% HP. Flee: path away from threat.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Pathfind  = require('src.util.pathfind')
local Equipment = require('src.colonist.equipment')
local Ranged    = require('src.combat.ranged')
local Creatures = require('src.creatures.creatures')
local Body      = require('src.combat.body')
local Wounds    = require('src.combat.wounds')

local CombatAI = {}

---------------------------------------------------------------------------
-- Trait helpers
---------------------------------------------------------------------------

local function hasTrait(col, traitId)
    if not col.traits then return false end
    for _, t in ipairs(col.traits) do
        if t.id == traitId then return true end
    end
    return false
end

local function getFleeThreshold(col)
    if hasTrait(col, 'pacifist') then return 1.0 end  -- always flee, never fight
    if hasTrait(col, 'coward') then return 0.70 end
    if hasTrait(col, 'brave')  then return 0.20 end
    return 0.40 -- default: flee at 40% HP
end

---------------------------------------------------------------------------
-- Melee stances: affect damage, accuracy, and damage reduction
---------------------------------------------------------------------------

local STANCES = {
    balanced = {
        id = 'balanced', name = 'Balanced',
        damageMult = 1.0, accuracyMod = 0.0, damageReduction = 0.0,
        desc = 'No bonuses or penalties.',
    },
    aggressive = {
        id = 'aggressive', name = 'Aggressive',
        damageMult = 1.25, accuracyMod = -0.05, damageReduction = -0.10,
        desc = 'More damage, less defense.',
    },
    defensive = {
        id = 'defensive', name = 'Defensive',
        damageMult = 0.75, accuracyMod = 0.05, damageReduction = 0.20,
        desc = 'Less damage, better defense.',
    },
}

CombatAI.STANCES = STANCES

function CombatAI.getStance(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return STANCES.balanced end
    return STANCES[col._stance or 'balanced'] or STANCES.balanced
end

function CombatAI.setStance(entityId, stanceId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    if STANCES[stanceId] then
        col._stance = stanceId
    end
end

---------------------------------------------------------------------------
-- Distance helpers
---------------------------------------------------------------------------

local function distSq(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return dx * dx + dy * dy
end

local function dist(x1, y1, x2, y2)
    return math.sqrt(distSq(x1, y1, x2, y2))
end

---------------------------------------------------------------------------
-- Find nearest hostile creature to a colonist
---------------------------------------------------------------------------

local function findNearestHostile(posX, posY, posDepth, detectionRange, facing)
    local bestId, bestDist = nil, math.huge
    local losOk, LOS = pcall(require, 'src.sim.line_of_sight')
    local halfFov = losOk and LOS.COLONIST_FOV / 2 or math.pi

    for id, comps in ECS.query('creature', 'pos') do
        local cr   = comps.creature
        local cpos = comps.pos
        if cr.hostile and cr.state ~= 'dead' and (cpos.depth or 0) == (posDepth or 0) then
            local d = distSq(posX, posY, cpos.x, cpos.y)
            if d < bestDist and d <= detectionRange * detectionRange then
                -- Check vision cone + LOS
                if losOk and facing then
                    if LOS.canSee(posX, posY, cpos.x, cpos.y, facing, halfFov, detectionRange) then
                        bestDist = d
                        bestId = id
                    end
                else
                    bestDist = d
                    bestId = id
                end
            end
        end
    end

    return bestId, bestDist > 0 and math.sqrt(bestDist) or 0
end

---------------------------------------------------------------------------
-- Melee attack a creature
---------------------------------------------------------------------------

local function meleeAttack(colonistId, targetId, col)
    local damage = Equipment.getWeaponDamage(colonistId)

    -- Skills module for mastery checks and XP
    local sok, Skills = pcall(require, 'src.colonist.skills')

    -- Enhanced combat formula (ported from MMOLite):
    -- base = floor((2*level/5+2) * weaponDmg * (skill/10) / 50) + 2
    local skillLevel = col.skills and col.skills.hunting or 1
    local level = skillLevel  -- colonist "level" is their hunting skill
    local base = math.floor((2 * level / 5 + 2) * damage * (skillLevel / 10) / 50) + 2
    -- Use the higher of weapon damage or formula result
    damage = math.max(damage, base)

    -- Crit chance: 5% base + 1% per skill level
    local critChance = 0.05 + skillLevel * 0.01
    if math.random() < critChance then
        damage = math.floor(damage * 1.5)
    end

    -- Berserker mastery: +25% melee damage
    if sok and Skills.hasMastery(colonistId, 'berserker_mastery') then
        local effect = Skills.getMasteryEffect(colonistId, 'berserker_mastery')
        if effect then damage = math.floor(damage * (effect.meleeMult or 1)) end
    end

    -- Combat trait modifiers (brave +10%, coward -15%, night_fighter +8%)
    if col.traits then
        local combatMod = 0
        for _, t in ipairs(col.traits) do
            if t.combatMod then combatMod = combatMod + t.combatMod end
        end
        if combatMod ~= 0 then
            damage = math.max(1, math.floor(damage * (1 + combatMod)))
        end
    end
    if hasTrait(col, 'ex_soldier') then
        damage = math.floor(damage * 1.15)
    end

    -- Stance modifier
    local stance = CombatAI.getStance(colonistId)
    damage = math.max(1, math.floor(damage * stance.damageMult))

    -- Prosthetic arm efficiency affects melee damage
    local pok, Prosth = pcall(require, 'src.combat.prosthetics')
    if pok then
        local armEff = Prosth.getManipEfficiency(colonistId)
        damage = math.max(1, math.floor(damage * armEff))
    end

    -- Drug damage buff
    local addOk, AddictionMod = pcall(require, 'src.colonist.addiction')
    if addOk and AddictionMod.getDamageMult then
        damage = math.floor(damage * AddictionMod.getDamageMult(colonistId))
    end

    -- Award combat XP
    if sok then Skills.onCombatHit(colonistId, damage) end

    local killed = Creatures.damageCreature(targetId, damage, colonistId)
    return killed
end

---------------------------------------------------------------------------
-- Try to flee from a threat
---------------------------------------------------------------------------

local function fleePath(colonistId, pos, threatPos, path)
    local World = require('src.world.tilemap')

    -- Direction away from threat
    local dx = pos.x - threatPos.x
    local dy = pos.y - threatPos.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then
        dx, dy = 1, 0
    else
        dx, dy = dx / len, dy / len
    end

    -- Try to flee 10 tiles away
    local fleeX = math.floor(pos.x + dx * 10)
    local fleeY = math.floor(pos.y + dy * 10)
    fleeX = math.max(1, math.min(World.width() - 2, fleeX))
    fleeY = math.max(1, math.min(World.height() - 2, fleeY))

    local pd = pos.depth or 0
    if World.isWalkable(fleeX, fleeY, pd) then
        local route = Pathfind.find(pos.x, pos.y, fleeX, fleeY, World, colonistId, pd, pd)
        if route and #route > 0 then
            path.nodes = route
            path.index = 1
            path.moveTimer = 0
            return true
        end
    end

    -- Fallback: try random direction
    for _ = 1, 4 do
        local rx = pos.x + math.random(-8, 8)
        local ry = pos.y + math.random(-8, 8)
        rx = math.max(1, math.min(World.width() - 2, rx))
        ry = math.max(1, math.min(World.height() - 2, ry))
        if World.isWalkable(rx, ry, pd) then
            local route = Pathfind.find(pos.x, pos.y, rx, ry, World, colonistId, pd, pd)
            if route and #route > 0 then
                path.nodes = route
                path.index = 1
                path.moveTimer = 0
                return true
            end
        end
    end

    return false
end

---------------------------------------------------------------------------
-- ECS system: colonist combat AI
-- Runs after work_ai (priority 28) but only takes over when hostiles are near.
---------------------------------------------------------------------------

local attackCooldowns = {} -- { [entityId] = timer }

local function combatAISystem(dt, id, comps)
    local col  = comps.colonist
    local pos  = comps.pos
    local path = comps.path

    if col.state == 'dead' or col.state == 'mental_break' then
        attackCooldowns[id] = nil
        return
    end

    -- Detection range: base 12, reduced if sleeping/eating
    local detectionRange = 12
    if col.state == 'sleeping' or col.state == 'eating' then
        detectionRange = 5
    end

    -- Find nearest hostile (vision cone + LOS aware)
    local threatId, threatDist = findNearestHostile(pos.x, pos.y, pos.depth or 0, detectionRange, col.facing)
    if not threatId then
        -- Brain 2 (Director): check shared threat reports from other colonists
        -- If a nearby threat was reported, face toward it (heightened awareness)
        local dok, Director = pcall(require, 'src.ai.director')
        if dok then
            local tx, ty, tStr = Director.getNearbyThreat(pos.x, pos.y)
            if tx then
                -- Face toward reported threat area (heightened vigilance)
                col.facing = math.atan2(ty - pos.y, tx - pos.x)
            end
        end

        -- No direct threat spotted: clear combat state if we were fighting/fleeing
        if col.state == 'fighting' or col.state == 'fleeing' then
            col.state = 'idle'
            col.task = nil
        end
        attackCooldowns[id] = nil
        return
    end

    local threatPos = ECS.get(threatId, 'pos')
    if not threatPos then return end

    -- Brain 2 (Director): report threat sighting to colony awareness
    local dok, Director = pcall(require, 'src.ai.director')
    if dok then Director.reportThreat(threatPos.x, threatPos.y, threatDist < 5 and 2 or 1) end

    -- Fight-or-flee decision
    local hpRatio = col.maxHealth > 0 and (col.health / col.maxHealth) or 0
    local fleeThreshold = getFleeThreshold(col)

    -- No weapon = always flee unless brave
    local hasWeapon = ECS.has(id, 'equipment') and ECS.get(id, 'equipment').weapon ~= nil
    local forceF = (not hasWeapon and not hasTrait(col, 'brave'))

    if hpRatio <= fleeThreshold or forceF then
        -- Exposure outranks a creature once it is the more certain death.
        -- work_ai returns early for state 'fleeing', so its cold-emergency
        -- block never runs while a colonist is running away: a colonist chased
        -- by a lingering predator froze solid at warmth 0 without ever trying
        -- to reach a fire. Breaking off hands control back to work_ai, which
        -- then paths to warmth.
        --   * warmth < 25: break off from a DISTANT threat (> 6 tiles)
        --   * warmth < 12: break off regardless of distance — at this point
        --     hypothermia is draining 1 HP/s and will finish the job first
        local fleeNeeds = ECS.get(id, 'needs')
        if fleeNeeds and (fleeNeeds.warmth < 12
            or (fleeNeeds.warmth < 25 and threatDist > 6)) then
            if col.state == 'fleeing' then
                col.state = 'idle'
                path.nodes = nil
            end
            return
        end

        -- FLEE
        if col.state ~= 'fleeing' then
            col.state = 'fleeing'
            col.task = nil
            path.nodes = nil
        end

        -- Only repath if not already moving
        if not path.nodes then
            fleePath(id, pos, threatPos, path)
        end
        return
    end

    -- FIGHT
    if col.state ~= 'fighting' then
        col.state = 'fighting'
        col.task = nil
    end

    -- Face toward the threat
    col.facing = math.atan2(threatPos.y - pos.y, threatPos.x - pos.x)

    local weaponRange = Equipment.getWeaponRange(id)
    local isRanged = Equipment.isRanged(id)

    -- Tick attack cooldown
    attackCooldowns[id] = (attackCooldowns[id] or 0) - dt

    -- In range? Attack.
    if threatDist <= weaponRange + 0.5 then
        if attackCooldowns[id] <= 0 then
            if isRanged then
                Ranged.fire(id, threatId)
                attackCooldowns[id] = 1.5 -- ranged attack cooldown
            else
                local killed = meleeAttack(id, threatId, col)
                attackCooldowns[id] = 0.8 -- melee attack cooldown

                -- Melee: creature can counterattack (handled by creature AI)
            end
        end
        -- Stand ground (don't re-path while attacking)
        path.nodes = nil
        return
    end

    -- Out of range: close distance (melee) or hold position (ranged, find better spot)
    if not path.nodes then
        if isRanged then
            -- Ranged: try to get within weapon range but not too close
            local idealDist = weaponRange - 1
            local dx = pos.x - threatPos.x
            local dy = pos.y - threatPos.y
            local len = math.sqrt(dx * dx + dy * dy)
            if len < 0.01 then dx, dy = 1, 0 else dx, dy = dx / len, dy / len end

            local tx = math.floor(threatPos.x + dx * idealDist)
            local ty = math.floor(threatPos.y + dy * idealDist)
            local World = require('src.world.tilemap')
            tx = math.max(1, math.min(World.width() - 2, tx))
            ty = math.max(1, math.min(World.height() - 2, ty))

            local pd = pos.depth or 0
            if World.isWalkable(tx, ty, pd) then
                local route = Pathfind.find(pos.x, pos.y, tx, ty, World, id, pd, pd)
                if route then
                    local trimmed = {}
                    for i = 1, math.min(4, #route) do trimmed[i] = route[i] end
                    path.nodes = trimmed
                    path.index = 1
                    path.moveTimer = 0
                end
            end
        else
            -- Melee: path directly to target
            local World = require('src.world.tilemap')
            local pd = pos.depth or 0
            local route = Pathfind.find(pos.x, pos.y, threatPos.x, threatPos.y, World, id, pd, threatPos.depth or 0)
            if route and #route > 0 then
                -- Only take a few steps (re-evaluate frequently)
                local trimmed = {}
                for i = 1, math.min(5, #route) do trimmed[i] = route[i] end
                path.nodes = trimmed
                path.index = 1
                path.moveTimer = 0
            end
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function CombatAI.registerSystems()
    ECS.addSystem('combat_ai', { 'colonist', 'pos', 'path' }, combatAISystem, 29)
end

CombatAI.registerSystems()

return CombatAI
