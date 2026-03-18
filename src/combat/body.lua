-- body.lua -- Body part system for colonists
-- Each colonist gets a 'body' component with six parts: head, torso, arms, legs.
-- Parts have HP and status. Destruction has gameplay consequences:
-- head/torso destroyed = death, arm destroyed = no 2-handed, leg destroyed = half move speed.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Body = {}

-- Lazy-loaded colonist module (avoid pcall in hot-path body consequence system)
local _ColMod
local function lazyLoadBody()
    if _ColMod ~= nil then return end
    local ok
    ok, _ColMod = pcall(require, 'src.colonist.colonist')
    if not ok then _ColMod = false end
end

---------------------------------------------------------------------------
-- Part definitions
---------------------------------------------------------------------------

local PART_DEFS = {
    head      = { maxHp = 30, vital = true },
    torso     = { maxHp = 60, vital = true },
    left_arm  = { maxHp = 40, vital = false },
    right_arm = { maxHp = 40, vital = false },
    left_leg  = { maxHp = 50, vital = false },
    right_leg = { maxHp = 50, vital = false },
}

-- Ordered list for iteration and random targeting
local PART_NAMES = { 'head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg' }

Body.PART_DEFS  = PART_DEFS
Body.PART_NAMES = PART_NAMES

---------------------------------------------------------------------------
-- Create a fresh body component
---------------------------------------------------------------------------

function Body.create()
    local parts = {}
    for _, name in ipairs(PART_NAMES) do
        local def = PART_DEFS[name]
        parts[name] = {
            hp     = def.maxHp,
            maxHp  = def.maxHp,
            status = 'healthy', -- healthy / injured / destroyed
        }
    end
    return { parts = parts }
end

---------------------------------------------------------------------------
-- Attach body component to an entity
---------------------------------------------------------------------------

function Body.attach(entityId)
    if not ECS.has(entityId, 'body') then
        ECS.set(entityId, 'body', Body.create())
    end
end

---------------------------------------------------------------------------
-- Damage a specific body part. Returns true if the hit killed the entity.
---------------------------------------------------------------------------

function Body.damagePart(entityId, partName, amount)
    -- Debug: god mode makes colonists invulnerable
    if ECS.get(entityId, 'colonist') then
        local dpOk, DP = pcall(require, 'src.ui.debug_panel')
        if dpOk and DP.godMode then return false end
    end

    local body = ECS.get(entityId, 'body')
    if not body then return false end

    local part = body.parts[partName]
    if not part or part.status == 'destroyed' then return false end

    part.hp = math.max(0, part.hp - amount)

    if part.hp <= 0 then
        part.status = 'destroyed'
        part.hp = 0
        -- Scar trait: limb destroyed
        local scarOk, ScarTraits = pcall(require, 'src.colonist.scar_traits')
        if scarOk then ScarTraits.onLimbDestroyed(entityId) end
    elseif part.hp < part.maxHp * 0.5 then
        part.status = 'injured'
    end

    -- Vital part destroyed = entity death
    local def = PART_DEFS[partName]
    if def.vital and part.status == 'destroyed' then
        return true
    end

    return false
end

---------------------------------------------------------------------------
-- Heal a body part by amount. Cannot heal destroyed parts.
---------------------------------------------------------------------------

function Body.healPart(entityId, partName, amount, healerId)
    local body = ECS.get(entityId, 'body')
    if not body then return end

    local part = body.parts[partName]
    if not part then return end

    -- Destroyed parts can only be restored by a surgeon mastery holder
    if part.status == 'destroyed' then
        if not healerId then return end
        local skOk, Skills = pcall(require, 'src.colonist.skills')
        if not skOk or not Skills.hasMastery(healerId, 'surgeon') then return end
        -- Vital parts (head/torso) cannot be restored even by surgeons
        local def = PART_DEFS[partName]
        if def and def.vital then return end
        -- Restore: set to 1 HP injured state, then apply the heal amount
        part.hp = 1
        part.status = 'injured'
    end

    part.hp = math.min(part.maxHp, part.hp + amount)
    if part.hp >= part.maxHp * 0.5 then
        part.status = 'healthy'
    end
end

---------------------------------------------------------------------------
-- Pick a random body part weighted by surface area (torso most likely)
---------------------------------------------------------------------------

-- Hit weights: torso=40%, legs=20% each (combined 40%), arms=8% each (16%), head=4%
local HIT_WEIGHTS = {
    { name = 'torso',     weight = 40 },
    { name = 'left_leg',  weight = 20 },
    { name = 'right_leg', weight = 20 },
    { name = 'left_arm',  weight = 8 },
    { name = 'right_arm', weight = 8 },
    { name = 'head',      weight = 4 },
}
local TOTAL_HIT_WEIGHT = 100

function Body.randomPart()
    local roll = math.random(TOTAL_HIT_WEIGHT)
    local acc = 0
    for _, entry in ipairs(HIT_WEIGHTS) do
        acc = acc + entry.weight
        if roll <= acc then
            return entry.name
        end
    end
    return 'torso'
end

---------------------------------------------------------------------------
-- Query helpers
---------------------------------------------------------------------------

function Body.isPartDestroyed(entityId, partName)
    local body = ECS.get(entityId, 'body')
    if not body then return false end
    local part = body.parts[partName]
    return part and part.status == 'destroyed'
end

function Body.hasUsableArms(entityId)
    local body = ECS.get(entityId, 'body')
    if not body then return true end
    local la = body.parts.left_arm
    local ra = body.parts.right_arm
    local usable = 0
    if la and la.status ~= 'destroyed' then usable = usable + 1 end
    if ra and ra.status ~= 'destroyed' then usable = usable + 1 end
    return usable
end

function Body.canUseTwoHanded(entityId)
    return Body.hasUsableArms(entityId) >= 2
end

function Body.getMoveSpeedMultiplier(entityId)
    local body = ECS.get(entityId, 'body')
    if not body then return 1.0 end
    local ll = body.parts.left_leg
    local rl = body.parts.right_leg

    -- Prosthetic legs modify speed via efficiency
    local pok, Prosth = pcall(require, 'src.combat.prosthetics')
    if pok then
        return Prosth.getMoveEfficiency(entityId)
    end

    local destroyed = 0
    if ll and ll.status == 'destroyed' then destroyed = destroyed + 1 end
    if rl and rl.status == 'destroyed' then destroyed = destroyed + 1 end
    if destroyed >= 2 then return 0.0 end -- both legs gone: immobile
    if destroyed >= 1 then return 0.5 end
    return 1.0
end

---------------------------------------------------------------------------
-- ECS system: apply body-part consequences to colonist stats each tick
---------------------------------------------------------------------------

local function bodyConsequenceSystem(dt, id, comps)
    local col  = comps.colonist
    local body = comps.body

    if col.state == 'dead' then return end

    -- Check vital parts — kill colonist via shared death handler
    for _, partName in ipairs(PART_NAMES) do
        local part = body.parts[partName]
        local def = PART_DEFS[partName]
        if def.vital and part.status == 'destroyed' and col.state ~= 'dead' then
            lazyLoadBody()
            if _ColMod then _ColMod.kill(id) end
            return
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Body.registerSystems()
    ECS.addSystem('body_consequences', { 'colonist', 'body' }, bodyConsequenceSystem, 9)
end

Body.registerSystems()

return Body
