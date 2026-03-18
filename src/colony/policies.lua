-- policies.lua -- Colony-wide policy/law toggles
-- Permanent modifiers the player enables or disables.
-- Effects are read by needs decay (colonist.lua) and work AI (work_ai.lua).
-- Step function called from main.lua for duration-based policies.

local GameState = require('src.game_state')

local Policies = {}
local ok_Hermes, Hermes = pcall(require, 'src.sim.hermes')

---------------------------------------------------------------------------
-- Policy definitions
---------------------------------------------------------------------------

local POLICY_DEFS = {
    extended_shifts = {
        id          = 'extended_shifts',
        name        = 'Extended Shifts',
        description = 'Colonists work 25% faster but morale drains 10% faster.',
        effects     = {
            workSpeedMult  = 1.25,
            moraleDrainAdd = 0.10,
        },
        active = false,
    },
    rationing = {
        id          = 'rationing',
        name        = 'Rationing',
        description = 'Food drain reduced 30% but morale drains 15% faster.',
        effects     = {
            foodDrainMult  = 0.70,
            moraleDrainAdd = 0.15,
        },
        active = false,
    },
    martial_law = {
        id          = 'martial_law',
        name        = 'Martial Law',
        description = 'No free time. Discontent +20 while active, but colonists cannot have mental breaks.',
        effects     = {
            noFreeTime      = true,
            discontentAdd   = 20,
            blockMentalBreak = true,
        },
        active = false,
    },
    emergency_protocol = {
        id          = 'emergency_protocol',
        name        = 'Emergency Protocol',
        description = 'All work priorities set to 1 for 1 game-day. Auto-deactivates.',
        effects     = {
            allPriority1 = true,
        },
        active   = false,
        duration = 1,       -- game-days
        startDay = nil,     -- set on activation
        startHour = nil,
    },
    quota_compliance = {
        id          = 'quota_compliance',
        name        = 'Quota Compliance',
        description = 'Load extra cargo into the return pod. Mammona sends better drops back, but the colony gives up more stock. Morale -15.',
        effects     = {
            moraleDrainAdd = 0.15,
            supplyBonus    = true,
            supplyDropMult = 1.35,
            quotaShipmentMult = 1.5,
        },
        active = false,
    },
    blackout_protocol = {
        id          = 'blackout_protocol',
        name        = 'Blackout Protocol',
        description = 'Reduce heat signature by 50% to avoid raids. Warmth output drops 30%.',
        effects     = {
            heatSignatureMult = 0.5,
            warmthMult        = 0.7,
        },
        active = false,
    },
}

-- Ordered list for UI iteration
local POLICY_ORDER = { 'extended_shifts', 'rationing', 'martial_law', 'emergency_protocol', 'quota_compliance', 'blackout_protocol' }

---------------------------------------------------------------------------
-- Activation
---------------------------------------------------------------------------

function Policies.toggle(policyId)
    local def = POLICY_DEFS[policyId]
    if not def then return false end

    if def.active then
        Policies.deactivate(policyId)
    else
        Policies.activate(policyId)
    end
    return true
end

function Policies.activate(policyId)
    local def = POLICY_DEFS[policyId]
    if not def or def.active then return false end

    def.active = true
    def.lastDay = GameState.day
    if def.duration then
        def.startDay  = GameState.day
        def.startHour = GameState.hour
    end
    return true
end

function Policies.deactivate(policyId)
    local def = POLICY_DEFS[policyId]
    if not def or not def.active then return false end

    def.active    = false
    def.startDay  = nil
    def.startHour = nil
    def.lastDay   = nil
    return true
end

function Policies.isActive(policyId)
    local def = POLICY_DEFS[policyId]
    return def and def.active or false
end

---------------------------------------------------------------------------
-- Computed modifier accessors (called by other systems)
---------------------------------------------------------------------------

function Policies.getWorkSpeedMult()
    local mult = 1.0
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.workSpeedMult then
            mult = mult * def.effects.workSpeedMult
        end
    end
    if ok_Hermes and Hermes.getWorkSpeedMult then
        mult = mult * Hermes.getWorkSpeedMult()
    end
    return mult
end

function Policies.getFoodDrainMult()
    local mult = 1.0
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.foodDrainMult then
            mult = mult * def.effects.foodDrainMult
        end
    end
    return mult
end

function Policies.getMoraleDrainAdd()
    local total = 0
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.moraleDrainAdd then
            total = total + def.effects.moraleDrainAdd
        end
    end
    if ok_Hermes and Hermes.getMoraleDrainAdd then
        total = total + Hermes.getMoraleDrainAdd()
    end
    return total
end

function Policies.isNoFreeTime()
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.noFreeTime then
            return true
        end
    end
    return false
end

function Policies.isMentalBreakBlocked()
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.blockMentalBreak then
            return true
        end
    end
    return false
end

function Policies.isAllPriority1()
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.allPriority1 then
            return true
        end
    end
    return false
end

function Policies.getDiscontentAdd()
    local total = 0
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.discontentAdd then
            total = total + def.effects.discontentAdd
        end
    end
    return total
end

function Policies.getHeatSignatureMult()
    local mult = 1.0
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.heatSignatureMult then
            mult = mult * def.effects.heatSignatureMult
        end
    end
    if ok_Hermes and Hermes.getHeatSignatureMult then
        mult = mult * Hermes.getHeatSignatureMult()
    end
    return mult
end

function Policies.getWarmthMult()
    local mult = 1.0
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.warmthMult then
            mult = mult * def.effects.warmthMult
        end
    end
    if ok_Hermes and Hermes.getWarmthMult then
        mult = mult * Hermes.getWarmthMult()
    end
    return mult
end

function Policies.hasSupplyBonus()
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.supplyBonus then
            return true
        end
    end
    return false
end

function Policies.getSupplyDropMult()
    local mult = 1.0
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.supplyDropMult then
            mult = mult * def.effects.supplyDropMult
        end
    end
    if ok_Hermes and Hermes.getSupplyDropMult then
        mult = mult * Hermes.getSupplyDropMult()
    end
    return mult
end

function Policies.getQuotaShipmentMult()
    local mult = 1.0
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.effects.quotaShipmentMult then
            mult = mult * def.effects.quotaShipmentMult
        end
    end
    return mult
end

---------------------------------------------------------------------------
-- Step -- handle duration-based policies expiring
---------------------------------------------------------------------------

function Policies.step(dt)
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        if def.active and def.duration and def.startDay then
            local elapsed = (GameState.day - def.startDay) + (GameState.hour - (def.startHour or 0)) / 24
            if elapsed >= def.duration then
                Policies.deactivate(id)
            end
        end

    end

    -- Martial law applies continuous discontent pressure via hope.lua
    -- (caller reads getDiscontentAdd() and feeds it into Hope.applyDelta)
end

---------------------------------------------------------------------------
-- Queries for UI
---------------------------------------------------------------------------

function Policies.getAll()
    local result = {}
    for _, id in ipairs(POLICY_ORDER) do
        result[#result + 1] = POLICY_DEFS[id]
    end
    return result
end

function Policies.get(policyId)
    return POLICY_DEFS[policyId]
end

function Policies.getOrder()
    return POLICY_ORDER
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function Policies.getState()
    local state = {}
    for _, id in ipairs(POLICY_ORDER) do
        local def = POLICY_DEFS[id]
        state[id] = {
            active    = def.active,
            startDay  = def.startDay,
            startHour = def.startHour,
            lastDay   = def.lastDay,
        }
    end
    return state
end

function Policies.restoreState(state)
    if not state then return end
    for _, id in ipairs(POLICY_ORDER) do
        local saved = state[id]
        if saved then
            local def = POLICY_DEFS[id]
            def.active    = saved.active or false
            def.startDay  = saved.startDay
            def.startHour = saved.startHour
            def.lastDay   = saved.lastDay
        end
    end
end

return Policies
