-- deterioration.lua -- Building durability decay and repair
-- Buildings lose durability over time. Blizzards/whiteouts accelerate decay.
-- Low durability halves efficiency. Zero durability destroys the building.
-- Colonists with building skill can repair.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Weather   = require('src.weather.weather')
local Jobs      = require('src.colonist.jobs')

local Deterioration = {}

-- Decay rates (durability points lost per sim tick)
local BASE_DECAY      = 0.01
local STORM_DECAY     = 0.03   -- blizzard or whiteout
local LOW_THRESHOLD   = 30     -- below this, efficiency halved
local REPAIR_RATE     = 2      -- durability per second of repair work

-- Planet-specific environmental decay rates (per dt, before 20Hz normalization)
local NEMAEA_RADIATION_DECAY = 0.02   -- non-lead buildings irradiated
local NERTHUS_SALT_ROT       = 0.01   -- wooden buildings corrode in salt air
local GAIA_CORRUPTION_DECAY  = 0.03   -- all buildings during corruption season

-- Lead-shielded building defIds (immune to Nemaea radiation)
local LEAD_BUILDINGS = {
    wall_lead  = true,
    door_lead  = true,
    lead_vault = true,
}

-- Cached decay rate (updated once per frame, not per-entity)
local _cachedDecayRate = BASE_DECAY
local _decayRateFrame  = -1

-- Register repair job type if not already present
if not Jobs.TYPES.repair_building then
    Jobs.TYPES.repair_building = {
        name     = 'Repair Building',
        skill    = 'building',
        priority = 'building',
        duration = 5.0,
    }
end

---------------------------------------------------------------------------
-- Init — stamp durability onto existing building entities that lack it
---------------------------------------------------------------------------

function Deterioration.init()
    -- Stamp durability onto existing building entities that lack it
    for id, comps in ECS.query('pos') do
        if not ECS.get(id, 'durability') then
            if ECS.get(id, 'machine') or ECS.get(id, 'turret')
               or ECS.get(id, 'building_ref') or ECS.get(id, 'trap') then
                Deterioration.attach(id)
            end
        end
    end
end

-- Convenience: attach durability to an entity
function Deterioration.attach(entityId, startDurability)
    ECS.set(entityId, 'durability', {
        current     = startDurability or 100,
        max         = 100,
        repairTask  = nil,  -- task ID if a repair is queued
    })
end

---------------------------------------------------------------------------
-- Query: is this building at reduced efficiency?
---------------------------------------------------------------------------

function Deterioration.isReducedEfficiency(entityId)
    local dur = ECS.get(entityId, 'durability')
    if not dur then return false end
    return dur.current < LOW_THRESHOLD
end

function Deterioration.getEfficiencyMult(entityId)
    local dur = ECS.get(entityId, 'durability')
    if not dur then return 1.0 end
    if dur.current < LOW_THRESHOLD then return 0.5 end
    return 1.0
end

function Deterioration.getDurability(entityId)
    local dur = ECS.get(entityId, 'durability')
    if not dur then return nil end
    return dur.current, dur.max
end

---------------------------------------------------------------------------
-- ECS system: decay durability each tick, destroy at zero
---------------------------------------------------------------------------

local function decaySystem(dt, id, comps)
    local dur = comps.durability
    local pos = comps.pos

    -- Determine decay rate based on weather (cached per frame, not per entity)
    local tick = GameState.tick or 0
    if _decayRateFrame ~= tick then
        _decayRateFrame = tick
        local weatherName, _ = Weather.getCurrent()
        _cachedDecayRate = (weatherName == 'blizzard' or weatherName == 'whiteout') and STORM_DECAY or BASE_DECAY
    end
    local rate = _cachedDecayRate

    dur.current = dur.current - rate * dt * 20  -- normalize to 20Hz base rate

    -- Planet-specific environmental decay (stacks with base decay)
    local planetId = GameState.planet
    if planetId == 'nemaea' then
        -- Radiation decay: non-lead buildings lose extra durability
        local ref = ECS.get(id, 'building_ref')
        if ref and ref.defId and not LEAD_BUILDINGS[ref.defId] then
            dur.current = dur.current - NEMAEA_RADIATION_DECAY * dt * 20
        end
    elseif planetId == 'nerthus_9' then
        -- Salt water rot: wooden buildings degrade in corrosive salt air
        local ref = ECS.get(id, 'building_ref')
        if ref and ref.defId then
            local bok, BuildingMod = pcall(require, 'src.building.building')
            if bok and BuildingMod.defs then
                local def = BuildingMod.defs[ref.defId]
                if def and def.cost and def.cost.wood and def.cost.wood > 0 then
                    dur.current = dur.current - NERTHUS_SALT_ROT * dt * 20
                end
            end
        end
    elseif planetId == 'gaia_a1x' then
        -- Baldrungen corruption: all buildings decay during corruption season
        if GameState.season == 'corruption' then
            dur.current = dur.current - GAIA_CORRUPTION_DECAY * dt * 20
        end
    end

    if dur.current < 0 then dur.current = 0 end

    -- At zero: destroy building
    if dur.current <= 0 then
        -- Cancel any outstanding repair task
        if dur.repairTask then
            Jobs.cancelTask(dur.repairTask)
        end

        -- Revert tile to debris/ground
        local Building = require('src.building.building')
        if pos then
            Building.remove(pos.x, pos.y, pos.depth)
        end

        ECS.destroy(id)
        return
    end

    -- Auto-queue a repair task when durability drops below threshold
    if dur.current < LOW_THRESHOLD and not dur.repairTask then
        if pos then
            local taskId = Jobs.createTask('repair_building', pos.x, pos.y, {
                entityId = id,
                depth = pos.depth or 0,
            })
            dur.repairTask = taskId
        end
    end
end

---------------------------------------------------------------------------
-- Repair callback: when a colonist completes a repair_building task
---------------------------------------------------------------------------

function Deterioration.applyRepair(entityId, amount)
    local dur = ECS.get(entityId, 'durability')
    if not dur then return end
    dur.current = math.min(dur.max, dur.current + (amount or REPAIR_RATE))
    -- Clear repair task reference if above threshold
    if dur.current >= LOW_THRESHOLD and dur.repairTask then
        dur.repairTask = nil
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Deterioration.registerSystems()
    ECS.addSystem('deterioration', { 'durability', 'pos' }, decaySystem, 30)
end

Deterioration.registerSystems()

function Deterioration.step(dt) end  -- decay runs via ECS system

return Deterioration
