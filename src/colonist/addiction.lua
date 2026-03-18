-- addiction.lua -- Drug addiction + contraband theft system
-- Tracks per-colonist per-drug usage. Addiction triggers withdrawal.
-- Contraband: addicted colonists with thief/addict traits steal from stockpiles.
-- Uses 'addictions' ECS component on colonist entities.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Zones     = require('src.world.zones')
local Schedule  = require('src.colonist.schedule')

local Addiction = {}

---------------------------------------------------------------------------
-- Drug type definitions
---------------------------------------------------------------------------

local DRUG_DEFS = {
    -- Uppers
    spike = {
        id   = 'spike',
        name = 'Spike',         -- outer rim stimulant
        category = 'drug',
        effects = {
            workSpeedBuff = 0.40,
            restDrain     = 0.15,
        },
        effectDuration = 90,
        addictionThreshold = 2,
        addictionWindow    = 5,
        withdrawalInterval = 1.5,
        withdrawalDuration = 4,
    },
    stardust = {
        id   = 'stardust',
        name = 'Stardust',      -- euphoric powder, common on stations
        category = 'drug',
        effects = {
            workSpeedBuff = 0.25,
            moraleBuff    = 25,
            restDrain     = 0.08,
        },
        effectDuration = 45,
        addictionThreshold = 3,
        addictionWindow    = 5,
        withdrawalInterval = 2,
        withdrawalDuration = 3,
    },

    -- Painkillers / downers
    drift = {
        id   = 'drift',
        name = 'Drift',         -- synthetic opiate
        category = 'drug',
        effects = {
            moraleBuff = 20,
            painReduce = 0.5,
            workSpeedBuff = -0.10,
        },
        effectDuration = 120,
        addictionThreshold = 3,
        addictionWindow    = 5,
        withdrawalInterval = 2,
        withdrawalDuration = 4,
    },
    smog = {
        id   = 'smog',
        name = 'Smog',          -- smoked sedative
        category = 'drug',
        effects = {
            moraleBuff    = 15,
            workSpeedBuff = -0.20,
        },
        effectDuration = 180,
        addictionThreshold = 5,
        addictionWindow    = 7,
        withdrawalInterval = 3,
        withdrawalDuration = 2,
    },

    -- Alcohol
    rotgut = {
        id   = 'rotgut',
        name = 'Rotgut',        -- cheap moonshine / hooch
        category = 'drug',
        effects = {
            moraleBuff    = 12,
            workSpeedBuff = -0.15,
        },
        effectDuration = 150,
        addictionThreshold = 4,
        addictionWindow    = 5,
        withdrawalInterval = 2,
        withdrawalDuration = 3,
    },

    -- Psychedelics
    shards = {
        id   = 'shards',
        name = 'Shards',        -- crystalline psychedelic
        category = 'drug',
        effects = {
            moraleBuff    = 35,
            workSpeedBuff = -0.40,
            sanityDrain   = 5,
        },
        effectDuration = 240,
        addictionThreshold = 4,
        addictionWindow    = 10,
        withdrawalInterval = 4,
        withdrawalDuration = 2,
    },
    glimpse = {
        id   = 'glimpse',
        name = 'Glimpse',       -- deep psychedelic, distilled from spores
        category = 'drug',
        effects = {
            moraleBuff    = 50,
            workSpeedBuff = -0.60,
            sanityDrain   = 15,
        },
        effectDuration = 60,
        addictionThreshold = 3,
        addictionWindow    = 10,
        withdrawalInterval = 5,
        withdrawalDuration = 5,
    },

    -- Combat drugs
    surge = {
        id   = 'surge',
        name = 'Surge',         -- combat stimulant
        category = 'drug',
        effects = {
            workSpeedBuff = 0.20,
            damageBuff    = 0.50,
            moraleBuff    = -10,
            restDrain     = 0.20,
        },
        effectDuration = 60,
        addictionThreshold = 2,
        addictionWindow    = 5,
        withdrawalInterval = 1,
        withdrawalDuration = 3,
    },

    -- Medical
    thaw = {
        id   = 'thaw',
        name = 'Thaw',          -- warmth restoration
        category = 'medical',
        effects = {
            warmthBuff    = 40,
            coldResistBuff = 0.3,
        },
        effectDuration = 300,
        addictionThreshold = 10,  -- very hard to get addicted
        addictionWindow    = 20,
        withdrawalInterval = 5,
        withdrawalDuration = 1,
    },

    -- Advanced combat
    berserker = {
        id   = 'berserker',
        name = 'Berserker',       -- combat rage chem
        category = 'drug',
        effects = {
            damageBuff    = 1.0,
            armorBuff     = 0.30,
            moraleBuff    = -20,
            painReduce    = 0.8,
            restDrain     = 0.30,
            workSpeedBuff = -0.50,
        },
        effectDuration = 45,
        addictionThreshold = 1,
        addictionWindow    = 3,
        withdrawalInterval = 1,
        withdrawalDuration = 5,
    },
    stim = {
        id   = 'stim',
        name = 'Stim',            -- combat focus chem
        category = 'drug',
        effects = {
            workSpeedBuff = 0.15,
            damageBuff    = 0.25,
            moraleBuff    = 5,
            painReduce    = 0.3,
            restDrain     = 0.12,
        },
        effectDuration = 90,
        addictionThreshold = 2,
        addictionWindow    = 5,
        withdrawalInterval = 2,
        withdrawalDuration = 3,
    },

    -- Erebus native
    voidbloom = {
        id   = 'voidbloom',
        name = 'Voidbloom',        -- bioluminescent fungus from Erebus
        category = 'drug',
        effects = {
            moraleBuff    = 30,
            painReduce    = 0.3,
            warmthBuff    = 15,
            sanityDrain   = 10,
            workSpeedBuff = -0.30,
        },
        effectDuration = 200,
        addictionThreshold = 2,
        addictionWindow    = 5,
        withdrawalInterval = 1,
        withdrawalDuration = 5,
    },
}

Addiction.DRUG_DEFS = DRUG_DEFS

---------------------------------------------------------------------------
-- Component helpers
---------------------------------------------------------------------------

-- Ensure entity has an addictions component
local function ensureComponent(id)
    if not ECS.has(id, 'addictions') then
        ECS.set(id, 'addictions', {})  -- { [drugId] = { uses, timestamps, addicted, withdrawalTimer, lastUse, activeEffect } }
    end
    return ECS.get(id, 'addictions')
end

local function getDrugEntry(addictions, drugId)
    if not addictions[drugId] then
        addictions[drugId] = {
            uses            = 0,
            timestamps      = {},   -- game-day of each use (for window calc)
            addicted        = false,
            withdrawalTimer = 0,    -- game-days remaining of withdrawal
            lastUse         = 0,    -- game-day of last use
            activeEffect    = 0,    -- seconds remaining of drug effect
        }
    end
    return addictions[drugId]
end

---------------------------------------------------------------------------
-- Public: administer a drug to a colonist
---------------------------------------------------------------------------

function Addiction.administer(colonistId, drugId)
    local def = DRUG_DEFS[drugId]
    if not def then return false end

    -- Teetotaler trait: refuses all drugs
    local col = ECS.get(colonistId, 'colonist')
    if col and col.traits then
        for _, t in ipairs(col.traits) do
            if t.id == 'teetotaler' then return false end
        end
    end

    local addictions = ensureComponent(colonistId)
    local entry = getDrugEntry(addictions, drugId)
    local currentDay = GameState.day + GameState.hour / 24

    -- Record use
    entry.uses = entry.uses + 1
    entry.timestamps[#entry.timestamps + 1] = currentDay
    entry.lastUse = currentDay
    -- Pharmacist mastery: drug effects last 50% longer
    local durationMult = 1.0
    local skOk, Skills = pcall(require, 'src.colonist.skills')
    if skOk and Skills.hasMastery(colonistId, 'pharmacist') then
        local eff = Skills.getMasteryEffect(colonistId, 'pharmacist')
        if eff and eff.drugDuration then durationMult = eff.drugDuration end
    end
    entry.activeEffect = def.effectDuration * durationMult

    -- Reset withdrawal if addicted
    if entry.addicted then
        entry.withdrawalTimer = 0
    end

    -- Check addiction threshold: count uses within the window
    local recentUses = 0
    for i = #entry.timestamps, 1, -1 do
        if currentDay - entry.timestamps[i] <= def.addictionWindow then
            recentUses = recentUses + 1
        else
            break
        end
    end
    if recentUses >= def.addictionThreshold then
        entry.addicted = true
    end

    -- Apply immediate effects
    local needs = ECS.get(colonistId, 'needs')
    if needs and def.effects.moraleBuff then
        needs.morale = math.min(100, needs.morale + def.effects.moraleBuff)
    end

    return true
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Addiction.isAddicted(colonistId, drugId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return false end
    local entry = addictions[drugId]
    return entry and entry.addicted or false
end

function Addiction.isInWithdrawal(colonistId, drugId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return false end
    local entry = addictions[drugId]
    return entry and entry.withdrawalTimer > 0 or false
end

function Addiction.isAnyWithdrawal(colonistId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return false end
    for _, entry in pairs(addictions) do
        if entry.withdrawalTimer > 0 then return true end
    end
    return false
end

function Addiction.getWorkSpeedMult(colonistId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return 1.0 end
    local mult = 1.0
    for drugId, entry in pairs(addictions) do
        local def = DRUG_DEFS[drugId]
        if def then
            -- Active drug effect
            if entry.activeEffect > 0 and def.effects.workSpeedBuff then
                mult = mult * (1 + def.effects.workSpeedBuff)
            end
            -- Withdrawal penalty
            if entry.withdrawalTimer > 0 then
                mult = mult * 0.60  -- -40% work speed
            end
        end
    end
    return mult
end

function Addiction.getDamageMult(colonistId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return 1.0 end
    local mult = 1.0
    for drugId, entry in pairs(addictions) do
        local def = DRUG_DEFS[drugId]
        if def and entry.activeEffect > 0 and def.effects.damageBuff then
            mult = mult * (1 + def.effects.damageBuff)
        end
    end
    return mult
end

function Addiction.getArmorMult(colonistId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return 1.0 end
    local mult = 1.0
    for drugId, entry in pairs(addictions) do
        local def = DRUG_DEFS[drugId]
        if def and entry.activeEffect > 0 and def.effects.armorBuff then
            mult = mult * (1 + def.effects.armorBuff)
        end
    end
    return mult
end

function Addiction.getPainReduceMult(colonistId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return 1.0 end
    local mult = 1.0
    for drugId, entry in pairs(addictions) do
        local def = DRUG_DEFS[drugId]
        if def and entry.activeEffect > 0 and def.effects.painReduce then
            mult = mult * (1 - def.effects.painReduce)
        end
    end
    return math.max(0, mult)
end

function Addiction.getColdResist(colonistId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return 0 end
    local best = 0
    for drugId, entry in pairs(addictions) do
        local def = DRUG_DEFS[drugId]
        if def and entry.activeEffect > 0 and def.effects.coldResistBuff then
            best = math.max(best, def.effects.coldResistBuff)
        end
    end
    return best
end

function Addiction.getStatus(colonistId)
    local addictions = ECS.get(colonistId, 'addictions')
    if not addictions then return {} end
    local result = {}
    for drugId, entry in pairs(addictions) do
        local def = DRUG_DEFS[drugId]
        result[#result + 1] = {
            drugId      = drugId,
            name        = def and def.name or drugId,
            uses        = entry.uses,
            addicted    = entry.addicted,
            withdrawal  = entry.withdrawalTimer > 0,
            withdrawalDaysLeft = entry.withdrawalTimer,
            effectActive = entry.activeEffect > 0,
        }
    end
    return result
end

---------------------------------------------------------------------------
-- Contraband: addicted colonists steal drugs during free time
---------------------------------------------------------------------------

local function hasTrait(col, traitId)
    if not col.traits then return false end
    for _, t in ipairs(col.traits) do
        if t.id == traitId then return true end
    end
    return false
end

local function tryContraband(id, col, addictions)
    -- Only during free time
    local sched = ECS.get(id, 'schedule')
    if not sched then return end
    local block = Schedule.getCurrentBlock(sched)
    if block ~= 'free' then return end

    -- Must have thief-like or addict-like traits
    local canSteal = hasTrait(col, 'volatile')
        or hasTrait(col, 'glutton')
        or hasTrait(col, 'pyromaniac')
        or hasTrait(col, 'loner')
    -- Any addicted colonist can also attempt theft
    local anyAddicted = false
    for _, entry in pairs(addictions) do
        if entry.addicted then anyAddicted = true; break end
    end
    if not canSteal and not anyAddicted then return end

    -- 2% chance per tick
    if math.random() > 0.02 then return end

    -- Find a stockpile with drugs
    local stockpiles = Zones.getByType('stockpile')
    for _, zone in ipairs(stockpiles) do
        for _, t in ipairs(zone.tileList) do
            local k = t.y * 10000 + t.x
            local item = zone.items[k]
            if item and DRUG_DEFS[item.itemId] then
                -- Steal one unit
                if item.amount > 1 then
                    item.amount = item.amount - 1
                else
                    zone.items[k] = nil
                end
                -- Consume it
                Addiction.administer(id, item.itemId)
                return
            end
        end
    end
end

---------------------------------------------------------------------------
-- ECS system
---------------------------------------------------------------------------

local function addictionSystem(dt, id, comps)
    local col   = comps.colonist
    local needs = comps.needs

    if col.state == 'dead' then return end

    local addictions = ECS.get(id, 'addictions')
    if not addictions then return end

    local hoursPerTick = dt / 60
    local daysPerTick  = hoursPerTick / 24

    for drugId, entry in pairs(addictions) do
        local def = DRUG_DEFS[drugId]
        if not def then goto continue end

        -- Tick active drug effect
        if entry.activeEffect > 0 then
            entry.activeEffect = entry.activeEffect - dt
            -- Apply ongoing effects
            if def.effects.restDrain then
                needs.rest = math.max(0, needs.rest - def.effects.restDrain * dt)
            end
            if def.effects.warmthBuff then
                needs.warmth = math.min(100, needs.warmth + def.effects.warmthBuff * dt)
            end
            if def.effects.sanityDrain then
                col.sanity = math.max(0, col.sanity - def.effects.sanityDrain * dt)
            end
        end

        -- Withdrawal tracking for addicted colonists
        if entry.addicted then
            local currentDay = GameState.day + GameState.hour / 24
            local daysSinceUse = currentDay - entry.lastUse

            if entry.withdrawalTimer > 0 then
                -- In withdrawal: tick down
                entry.withdrawalTimer = entry.withdrawalTimer - daysPerTick
                -- Morale penalty during withdrawal (-30 spread over duration)
                needs.morale = math.max(0, needs.morale - 30 * daysPerTick / def.withdrawalDuration)

                if entry.withdrawalTimer <= 0 then
                    -- Withdrawal complete: cured
                    entry.withdrawalTimer = 0
                    entry.addicted = false
                    entry.uses = 0
                    entry.timestamps = {}
                end
            elseif daysSinceUse >= def.withdrawalInterval and entry.activeEffect <= 0 then
                -- Start withdrawal
                entry.withdrawalTimer = def.withdrawalDuration
            end
        end

        -- Trim old timestamps (outside addiction window)
        local currentDay = GameState.day + GameState.hour / 24
        while #entry.timestamps > 0 and (currentDay - entry.timestamps[1]) > (def.addictionWindow + 1) do
            table.remove(entry.timestamps, 1)
        end

        ::continue::
    end

    -- Contraband theft attempt
    tryContraband(id, col, addictions)
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Addiction.registerSystems()
    ECS.addSystem('addiction', { 'colonist', 'needs', 'addictions' }, addictionSystem, 15)
end

Addiction.registerSystems()

return Addiction
