-- scar_traits.lua — Hardship-earned permanent traits (Kenshi-style)
-- Colonists who survive specific events gain permanent character modifications.
-- Scars make veterans irreplaceable — their loss is devastating.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ScarTraits = {}

---------------------------------------------------------------------------
-- Scar definitions — event type → trait granted
---------------------------------------------------------------------------

local SCARS = {
    frostblood = {
        id = 'frostblood',
        name = 'Frostblood',
        desc = 'Survived severe hypothermia. Blood runs cold now.',
        trigger = 'hypothermia_severe',  -- survived stage 4+ hypothermia
        coldResist = 0.15,
        moraleMod = -0.02,  -- haunted by the cold
    },
    battle_hardened = {
        id = 'battle_hardened',
        name = 'Battle-Hardened',
        desc = 'Survived a raid with less than 20 HP. Knows combat now.',
        trigger = 'raid_survivor_low_hp',
        combatMod = 0.15,
        workSpeed = -0.05,  -- restless, not suited for desk work
    },
    iron_stomach_scar = {
        id = 'iron_stomach_scar',
        name = 'Iron Gut',
        desc = 'Nearly starved. Body learned to extract every calorie.',
        trigger = 'starvation_survivor',
        foodMod = -0.15,  -- negative means LESS food drain
    },
    plague_immune = {
        id = 'plague_immune',
        name = 'Disease Hardened',
        desc = 'Beat a disease that should have killed them. Body remembers.',
        trigger = 'disease_survivor',
        -- no stat mods — immunity tracked via disease system
    },
    mental_resilience = {
        id = 'mental_resilience',
        name = 'Mental Resilience',
        desc = 'Recovered from a mental break. Mind is tempered.',
        trigger = 'mental_break_recovery',
        moraleMod = 0.05,
    },
    efficient_metabolism = {
        id = 'efficient_metabolism',
        name = 'Efficient Metabolism',
        desc = 'Body adapted to scarcity. Needs less food and rest.',
        trigger = 'prolonged_hunger',  -- food < 10 for extended period
        foodMod = -0.10,
        restMod = -0.05,
    },
    deep_scars = {
        id = 'deep_scars',
        name = 'Deep Scars',
        desc = 'Survived destruction of a limb. Pushes through pain now.',
        trigger = 'limb_destroyed',
        combatMod = 0.10,
        speedMod = -0.05,
    },
    pyromaniac_reformed = {
        id = 'pyromaniac_reformed',
        name = 'Reformed Pyromaniac',
        desc = 'Learned to channel destructive impulses constructively.',
        trigger = 'pyro_break_survived',
        workSpeed = 0.10,
        craftMod = 0.05,
    },
    blizzard_walker = {
        id = 'blizzard_walker',
        name = 'Blizzard Walker',
        desc = 'Survived a whiteout outside. Can see in the driving snow.',
        trigger = 'whiteout_survivor',
        coldResist = 0.10,
        speedMod = 0.05,
    },
    megafauna_slayer = {
        id = 'megafauna_slayer',
        name = 'Megafauna Slayer',
        desc = 'Killed a titan-class creature. Confident in a fight.',
        trigger = 'megafauna_kill',
        combatMod = 0.20,
        moraleMod = 0.03,
    },
}

ScarTraits.SCARS = SCARS

---------------------------------------------------------------------------
-- Per-colonist scar tracking
-- Stored on the colonist component as col._scars = { [scarId] = true }
-- and col._scarTrackers = { [trackerId] = value }
---------------------------------------------------------------------------

local function hasScar(col, scarId)
    return col._scars and col._scars[scarId]
end

local function grantScar(col, scarId)
    if not col._scars then col._scars = {} end
    if col._scars[scarId] then return false end

    col._scars[scarId] = true

    local scar = SCARS[scarId]
    if not scar then return false end

    -- Add scar as a trait to the colonist's trait list
    if not col.traits then col.traits = {} end
    col.traits[#col.traits + 1] = {
        id        = scar.id,
        name      = scar.name,
        desc      = scar.desc,
        isScar    = true,
        coldResist = scar.coldResist,
        combatMod  = scar.combatMod,
        workSpeed  = scar.workSpeed,
        foodMod    = scar.foodMod,
        restMod    = scar.restMod,
        moraleMod  = scar.moraleMod,
        speedMod   = scar.speedMod,
        craftMod   = scar.craftMod,
    }
    return true
end

---------------------------------------------------------------------------
-- Tracker system — monitors colonist state for scar triggers
-- Runs each sim tick at low priority
---------------------------------------------------------------------------

local CHECK_INTERVAL = 5.0  -- seconds between scar checks (not every tick)
local checkTimer = 0

local function scarTrackingSystem(dt, id, comps)
    local col   = comps.colonist
    local needs = comps.needs
    if col.state == 'dead' then return end

    if not col._scarTrackers then col._scarTrackers = {} end
    local t = col._scarTrackers

    -- Hypothermia survival: track time in severe hypothermia
    if col._hypothermia == 'severe' then
        t.severeHypoTime = (t.severeHypoTime or 0) + dt
    else
        -- Survived if they were in severe and came back
        if (t.severeHypoTime or 0) >= 10 and col._hypothermia ~= 'severe' then
            grantScar(col, 'frostblood')
        end
        t.severeHypoTime = 0
    end

    -- Starvation survival: track time with very low food
    if needs.food < 10 then
        t.starvationTime = (t.starvationTime or 0) + dt
    else
        if (t.starvationTime or 0) >= 30 then
            grantScar(col, 'iron_stomach_scar')
        end
        t.starvationTime = 0
    end

    -- Prolonged hunger → efficient metabolism
    if needs.food < 20 then
        t.hungerTime = (t.hungerTime or 0) + dt
        if t.hungerTime >= 60 then
            grantScar(col, 'efficient_metabolism')
            t.hungerTime = 0
        end
    else
        t.hungerTime = 0
    end

    -- Low HP after raid → battle hardened
    -- Tracked via onRaidSurvived callback below
end

---------------------------------------------------------------------------
-- Event callbacks (called by other systems)
---------------------------------------------------------------------------

function ScarTraits.onRaidSurvived(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    if col.health and col.health < 20 then
        grantScar(col, 'battle_hardened')
    end
end

function ScarTraits.onMentalBreakRecovery(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    grantScar(col, 'mental_resilience')
end

function ScarTraits.onDiseaseRecovery(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    grantScar(col, 'plague_immune')
end

function ScarTraits.onLimbDestroyed(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    grantScar(col, 'deep_scars')
end

function ScarTraits.onWhiteoutSurvived(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    grantScar(col, 'blizzard_walker')
end

function ScarTraits.onMegafaunaKill(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    grantScar(col, 'megafauna_slayer')
end

function ScarTraits.onPyroBreakSurvived(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return end
    grantScar(col, 'pyromaniac_reformed')
end

-- Query: get all scars for a colonist
function ScarTraits.getScars(entityId)
    local col = ECS.get(entityId, 'colonist')
    if not col or not col._scars then return {} end
    local result = {}
    for scarId in pairs(col._scars) do
        result[#result + 1] = SCARS[scarId]
    end
    return result
end

function ScarTraits.hasScar(entityId, scarId)
    local col = ECS.get(entityId, 'colonist')
    if not col then return false end
    return hasScar(col, scarId)
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function ScarTraits.registerSystems()
    ECS.addSystem('scar_tracking', { 'colonist', 'needs' }, scarTrackingSystem, 55)
end

ScarTraits.registerSystems()

return ScarTraits
