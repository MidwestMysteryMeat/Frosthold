-- prosthetics.lua -- Prosthetic limb system
-- 4 tiers: crude (50%), standard (80%), bionic (120%), precursor (150%)
-- Installation requires medical skill check. Failure = damage.
-- Prosthetics replace destroyed limbs and modify body part stats.

local ECS  = require('src.ecs.ecs')
local Body = require('src.combat.body')

local Prosthetics = {}

---------------------------------------------------------------------------
-- Prosthetic definitions
---------------------------------------------------------------------------

local TIERS = {
    crude = {
        name       = 'Crude',
        efficiency = 0.50,  -- 50% of natural limb function
        maxHpMult  = 0.40,  -- reduced max HP
        skillReq   = 3,     -- minimum medical skill
        failChance = 0.30,  -- 30% surgery failure at min skill
        craftable  = true,
        materials  = { metal = 5 },
        desc       = 'A rough prosthetic. Better than nothing.',
    },
    standard = {
        name       = 'Standard',
        efficiency = 0.80,
        maxHpMult  = 0.70,
        skillReq   = 6,
        failChance = 0.20,
        craftable  = true,
        materials  = { metal = 10, components = 2 },
        desc       = 'A functional replacement limb.',
    },
    bionic = {
        name       = 'Bionic',
        efficiency = 1.20,  -- better than natural
        maxHpMult  = 1.00,
        skillReq   = 10,
        failChance = 0.15,
        craftable  = true,
        materials  = { plasteel = 5, components = 5 },
        desc       = 'A high-performance artificial limb.',
    },
    precursor = {
        name       = 'Precursor',
        efficiency = 1.50,
        maxHpMult  = 1.30,
        skillReq   = 12,
        failChance = 0.10,
        craftable  = false,  -- found in ruins only
        materials  = {},
        desc       = 'Alien-designed limb. Unsettlingly organic.',
        sideEffect = 'anomaly_exposure',  -- chance of anomaly_sensitive trait
    },
}

-- Which body parts can receive prosthetics (not head/torso)
local INSTALLABLE_PARTS = {
    left_arm  = true,
    right_arm = true,
    left_leg  = true,
    right_leg = true,
}

Prosthetics.TIERS = TIERS
Prosthetics.INSTALLABLE_PARTS = INSTALLABLE_PARTS

---------------------------------------------------------------------------
-- Get prosthetic on a body part (nil if natural limb)
---------------------------------------------------------------------------

function Prosthetics.get(entityId, partName)
    local body = ECS.get(entityId, 'body')
    if not body or not body.parts[partName] then return nil end
    return body.parts[partName].prosthetic
end

---------------------------------------------------------------------------
-- Check if installation is possible
---------------------------------------------------------------------------

function Prosthetics.canInstall(entityId, partName, tierId)
    if not INSTALLABLE_PARTS[partName] then return false, 'Cannot install prosthetic on this part' end
    local tier = TIERS[tierId]
    if not tier then return false, 'Unknown prosthetic tier' end

    local body = ECS.get(entityId, 'body')
    if not body or not body.parts[partName] then return false, 'No body data' end

    -- Part must be destroyed (or have existing prosthetic to upgrade)
    local part = body.parts[partName]
    if part.status ~= 'destroyed' and not part.prosthetic then
        return false, 'Limb is still functional'
    end

    return true, nil
end

---------------------------------------------------------------------------
-- Install a prosthetic. Returns success, message.
-- doctorId is the colonist performing surgery.
---------------------------------------------------------------------------

function Prosthetics.install(entityId, partName, tierId, doctorId)
    local ok, err = Prosthetics.canInstall(entityId, partName, tierId)
    if not ok then return false, err end

    local tier = TIERS[tierId]
    local body = ECS.get(entityId, 'body')
    local part = body.parts[partName]
    local partDef = Body.PART_DEFS[partName]

    -- Surgery skill check
    local doctorSkill = 1
    if doctorId then
        local sok, Skills = pcall(require, 'src.colonist.skills')
        if sok then
            doctorSkill = Skills.getEffectiveLevel(doctorId, 'medical')
        else
            local dCol = ECS.get(doctorId, 'colonist')
            if dCol and dCol.skills then doctorSkill = dCol.skills.medical or 1 end
        end
    end

    -- Failure chance decreases with skill above requirement
    local skillOver = math.max(0, doctorSkill - tier.skillReq)
    local failChance = math.max(0.02, tier.failChance - skillOver * 0.03)

    if math.random() < failChance then
        -- Surgery failed: damage patient
        local col = ECS.get(entityId, 'colonist')
        if col then
            local dmg = math.random(5, 15)
            col.health = math.max(1, col.health - dmg)
        end
        -- Award XP even on failure
        local sok2, Skills2 = pcall(require, 'src.colonist.skills')
        if sok2 and doctorId then Skills2.addXp(doctorId, 'medical', 10) end
        return false, 'Surgery failed'
    end

    -- Success: install prosthetic
    local newMaxHp = math.floor(partDef.maxHp * tier.maxHpMult)
    part.hp = newMaxHp
    part.maxHp = newMaxHp
    part.status = 'healthy'
    part.prosthetic = {
        tier       = tierId,
        name       = tier.name,
        efficiency = tier.efficiency,
    }

    -- Precursor side effect: small chance to gain anomaly_sensitive trait
    if tier.sideEffect == 'anomaly_exposure' and math.random() < 0.15 then
        local col = ECS.get(entityId, 'colonist')
        if col and col.traits then
            local hasIt = false
            for _, t in ipairs(col.traits) do
                if t.id == 'anomaly_sensitive' then hasIt = true; break end
            end
            if not hasIt then
                local aok, Adlib = pcall(require, 'src.util.adlib')
                if aok and Adlib.TRAITS then
                    for _, t in ipairs(Adlib.TRAITS.neutral) do
                        if t.id == 'anomaly_sensitive' then
                            col.traits[#col.traits + 1] = t
                            break
                        end
                    end
                end
            end
        end
    end

    -- Award XP
    local sok3, Skills3 = pcall(require, 'src.colonist.skills')
    if sok3 and doctorId then Skills3.addXp(doctorId, 'medical', 30) end

    -- body_purist trait: morale penalty from having prosthetics
    local col2 = ECS.get(entityId, 'colonist')
    if col2 and col2.traits then
        for _, t in ipairs(col2.traits) do
            if t.id == 'body_purist' then
                local needs = ECS.get(entityId, 'needs')
                if needs then needs.morale = math.max(0, needs.morale - 15) end
                break
            end
        end
        -- transhumanist trait: morale boost from prosthetics
        for _, t in ipairs(col2.traits) do
            if t.id == 'transhumanist' then
                local needs = ECS.get(entityId, 'needs')
                if needs then needs.morale = math.min(100, needs.morale + 10) end
                break
            end
        end
    end

    return true, 'Surgery successful'
end

---------------------------------------------------------------------------
-- Remove a prosthetic (revert to destroyed natural limb)
---------------------------------------------------------------------------

function Prosthetics.remove(entityId, partName)
    local body = ECS.get(entityId, 'body')
    if not body or not body.parts[partName] then return false end

    local part = body.parts[partName]
    if not part.prosthetic then return false end

    local partDef = Body.PART_DEFS[partName]
    part.prosthetic = nil
    part.hp = 0
    part.maxHp = partDef.maxHp
    part.status = 'destroyed'
    return true
end

---------------------------------------------------------------------------
-- Get efficiency multiplier for a limb (1.0 = natural, >1.0 = bionic+)
---------------------------------------------------------------------------

function Prosthetics.getEfficiency(entityId, partName)
    local body = ECS.get(entityId, 'body')
    if not body or not body.parts[partName] then return 1.0 end

    local part = body.parts[partName]
    if part.status == 'destroyed' then return 0.0 end
    if part.prosthetic then return part.prosthetic.efficiency end
    return 1.0
end

---------------------------------------------------------------------------
-- Aggregate limb efficiency for movement (average of both legs)
---------------------------------------------------------------------------

function Prosthetics.getMoveEfficiency(entityId)
    local left  = Prosthetics.getEfficiency(entityId, 'left_leg')
    local right = Prosthetics.getEfficiency(entityId, 'right_leg')
    return (left + right) / 2
end

---------------------------------------------------------------------------
-- Aggregate limb efficiency for manipulation (average of both arms)
---------------------------------------------------------------------------

function Prosthetics.getManipEfficiency(entityId)
    local left  = Prosthetics.getEfficiency(entityId, 'left_arm')
    local right = Prosthetics.getEfficiency(entityId, 'right_arm')
    return (left + right) / 2
end

---------------------------------------------------------------------------
-- Count prosthetics on an entity
---------------------------------------------------------------------------

function Prosthetics.count(entityId)
    local body = ECS.get(entityId, 'body')
    if not body then return 0 end
    local n = 0
    for _, name in ipairs(Body.PART_NAMES) do
        if body.parts[name] and body.parts[name].prosthetic then
            n = n + 1
        end
    end
    return n
end

---------------------------------------------------------------------------
-- List all prosthetics on an entity (for UI)
---------------------------------------------------------------------------

function Prosthetics.list(entityId)
    local body = ECS.get(entityId, 'body')
    if not body then return {} end
    local result = {}
    for _, name in ipairs(Body.PART_NAMES) do
        local part = body.parts[name]
        if part and part.prosthetic then
            result[#result + 1] = {
                part       = name,
                tier       = part.prosthetic.tier,
                name       = part.prosthetic.name,
                efficiency = part.prosthetic.efficiency,
            }
        end
    end
    return result
end

return Prosthetics
