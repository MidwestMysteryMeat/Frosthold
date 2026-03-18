-- spoilage.lua — Temperature-dependent food spoilage
-- Food decays based on storage temperature. Sealed rooms below -10°C act as
-- freezers and preserve food indefinitely. Warm rooms accelerate rot.
-- Colony-wide food quality degrades as spoilage accumulates, eventually
-- triggering hope loss and food poisoning risk.
--
-- DEPRECATED for per-item physical food decay: src/world/item_decay.lua now
-- handles durability damage on individual food item entities based on tile
-- temperature, weather, fire, and radiation. This module remains active for
-- the colony-wide food quality / food-poisoning model, which operates on
-- GameState.resources.food (legacy aggregate counter) and is independent of
-- the physical item ECS. Do not delete until the aggregate food counter is
-- fully retired.

local GameState = require('src.game_state')
local Thermal   = require('src.sim.thermal')
local Hope      = require('src.colony.hope')

local Spoilage = {}

---------------------------------------------------------------------------
-- Food type definitions
---------------------------------------------------------------------------

local FOOD_TYPES = {
    raw_meat    = { name = 'Raw Meat',       spoilDays = 2,   preserved = false },
    berries     = { name = 'Berries',        spoilDays = 3,   preserved = false },
    mushrooms   = { name = 'Mushrooms',      spoilDays = 4,   preserved = false },
    cooked_meat = { name = 'Grilled Meat',   spoilDays = 5,   preserved = false },
    stew        = { name = 'Hearty Stew',    spoilDays = 4,   preserved = false },
    bread       = { name = 'Frost Bread',    spoilDays = 6,   preserved = false },
    jerky       = { name = 'Smoked Jerky',   spoilDays = 30,  preserved = true },
    ration      = { name = 'Pemmican',       spoilDays = 999, preserved = true },
    feast       = { name = 'Frontier Feast', spoilDays = 1,   preserved = false },
    human_meat  = { name = 'Human Meat',     spoilDays = 2,   preserved = false },
}

-- Weighted average spoil time for unpreserved foods (used as baseline denominator)
local averageSpoilDays
do
    local sum, count = 0, 0
    for _, def in pairs(FOOD_TYPES) do
        if not def.preserved then
            sum = sum + def.spoilDays
            count = count + 1
        end
    end
    averageSpoilDays = sum / math.max(1, count)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local foodQuality    = 100   -- 0–100 average freshness of colony food stores
local spoiledFood    = 0     -- accumulator: food units lost since last event
local freezerRoomIds = {}    -- { [roomId] = true } rooms cold enough to preserve food

local freezerCapacity      = 0  -- total tile count in freezer rooms
local totalStorageCapacity = 0  -- total tile count in all sealed rooms

-- Room scan runs on a cooldown, not every tick
local scanCooldown   = 0
local SCAN_INTERVAL  = 5  -- seconds between room temperature scans

-- Game-day duration in real seconds at 1x speed:
-- 1 game-hour = 60 real seconds, 24 hours per day → 1440 real seconds per game-day
local SECONDS_PER_GAME_DAY = 24 * 60

-- Threshold: food spoilage accumulates this much before triggering an event
local SPOIL_EVENT_THRESHOLD = 5

-- Freezer temperature ceiling (°C) — sealed rooms at or below this preserve food
local FREEZER_TEMP = -10

---------------------------------------------------------------------------
-- Temperature → spoilage rate multiplier
---------------------------------------------------------------------------

local function getSpoilMultiplier(tempC)
    if tempC < -20 then return 0    end -- frozen solid, no decay
    if tempC < 0   then return 0.25 end -- cold storage
    if tempC < 10  then return 0.5  end -- cool, slowed decay
    if tempC < 20  then return 1.0  end -- room temperature (baseline)
    return 2.0                          -- heat accelerates rot
end

---------------------------------------------------------------------------
-- Room scanning — identify freezer rooms and storage capacity
---------------------------------------------------------------------------

local function scanRooms()
    local thermalRooms = Thermal.getRooms()

    freezerRoomIds = {}
    freezerCapacity = 0
    totalStorageCapacity = 0

    for rid, room in pairs(thermalRooms) do
        if not room.sealed then goto continue end

        local tileCount = #room.tiles
        totalStorageCapacity = totalStorageCapacity + tileCount

        if room.avgTemp <= FREEZER_TEMP then
            freezerRoomIds[rid] = true
            freezerCapacity = freezerCapacity + tileCount
        end

        ::continue::
    end
end

-- Average temperature of non-freezer sealed rooms (where food spoils)
local function getAverageWarmTemp()
    local thermalRooms = Thermal.getRooms()
    local sum, count = 0, 0

    for rid, room in pairs(thermalRooms) do
        if room.sealed and not freezerRoomIds[rid] then
            sum = sum + room.avgTemp
            count = count + 1
        end
    end

    if count == 0 then
        -- No sealed warm rooms — food is effectively outdoors
        return GameState.getEffectiveTemp()
    end
    return sum / count
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Spoilage.init()
    foodQuality = 100
    spoiledFood = 0
    freezerRoomIds = {}
    freezerCapacity = 0
    totalStorageCapacity = 0
    scanCooldown = 0
end

---------------------------------------------------------------------------
-- Step — called each sim tick (20 Hz)
---------------------------------------------------------------------------

function Spoilage.step(dt)
    -- Periodic room scan (expensive, no need every tick)
    scanCooldown = scanCooldown - dt
    if scanCooldown <= 0 then
        scanRooms()
        scanCooldown = SCAN_INTERVAL
    end

    -- Fraction of food stored in freezer rooms vs all sealed rooms
    local frozenFraction = freezerCapacity / math.max(1, totalStorageCapacity)
    local warmFraction   = 1 - frozenFraction

    -- Only warm-stored food spoils; frozen food is perfectly preserved
    if warmFraction <= 0 then return end

    local avgWarmTemp = getAverageWarmTemp()
    local spoilMult   = getSpoilMultiplier(avgWarmTemp)
    if spoilMult <= 0 then return end

    -- Preservist mastery: any colonist with preservist reduces colony spoil rate by 50%
    local preservistMod = 1.0
    local pskOk, PSkills = pcall(require, 'src.colonist.skills')
    if pskOk then
        local ECSmod = require('src.ecs.ecs')
        for cid, _ in ECSmod.query('colonist') do
            if PSkills.hasMastery(cid, 'preservist') then
                local eff = PSkills.getMasteryEffect(cid, 'preservist')
                if eff and eff.spoilMult then
                    preservistMod = math.min(preservistMod, eff.spoilMult)
                end
                break
            end
        end
    end

    -- Base spoilage: fraction of total food lost per real second
    -- warmFraction of the food spoils at spoilMult rate over averageSpoilDays game-days
    local baseSpoilRate = warmFraction * spoilMult * preservistMod / (averageSpoilDays * SECONDS_PER_GAME_DAY)

    -- Scale by dt (GameState.speed already applied via accumulator tick rate)
    local foodLost = GameState.resources.food * baseSpoilRate * dt
    if foodLost < 0.001 then return end

    spoiledFood = spoiledFood + foodLost
    GameState.resources.food = math.max(0, GameState.resources.food - foodLost)

    -- Quality degrades proportional to loss relative to total stores
    -- Losing 1 unit when you have 10 is worse than losing 1 out of 100
    local totalFood = GameState.resources.food + foodLost  -- pre-loss total
    local qualityLoss = (foodLost / math.max(1, totalFood)) * 5
    foodQuality = math.max(0, foodQuality - qualityLoss)

    -- Natural quality recovery when food isn't spoiling fast
    -- (fresh food brought in dilutes old stock)
    if foodQuality < 100 and GameState.resources.food > 0 then
        foodQuality = math.min(100, foodQuality + 0.001 * dt)
    end

    -- Fire hope event when enough food has spoiled
    if spoiledFood >= SPOIL_EVENT_THRESHOLD then
        local lost = math.floor(spoiledFood)
        if lost > 0 then
            Hope.applyDelta(-3, 2)
        end
        spoiledFood = spoiledFood - lost
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Spoilage.getFoodQuality()
    return foodQuality
end

function Spoilage.getFreezerCapacity()
    return freezerCapacity
end

function Spoilage.getTotalStorageCapacity()
    return totalStorageCapacity
end

function Spoilage.getSpoilRate()
    local frozenFraction = freezerCapacity / math.max(1, totalStorageCapacity)
    local warmFraction   = 1 - frozenFraction
    local avgWarmTemp    = getAverageWarmTemp()
    local spoilMult      = getSpoilMultiplier(avgWarmTemp)
    return warmFraction * spoilMult / (averageSpoilDays * SECONDS_PER_GAME_DAY)
end

function Spoilage.isFreezerRoom(roomId)
    return freezerRoomIds[roomId] == true
end

-- Food poisoning risk: low food quality means colonists may get sick
-- Returns probability (0–1) of food poisoning per meal
function Spoilage.getFoodPoisoningChance()
    if foodQuality >= 30 then return 0 end
    return 0.15
end

-- Expose food type definitions for UI and other systems
function Spoilage.getFoodTypes()
    return FOOD_TYPES
end

function Spoilage.getSpoiledAccumulator()
    return spoiledFood
end

---------------------------------------------------------------------------
-- Serialization support (for save/load)
---------------------------------------------------------------------------

function Spoilage.getState()
    return {
        foodQuality = foodQuality,
        spoiledFood = spoiledFood,
    }
end

function Spoilage.loadState(saved)
    if not saved then return end
    foodQuality = saved.foodQuality or 100
    spoiledFood = saved.spoiledFood or 0
end

return Spoilage
