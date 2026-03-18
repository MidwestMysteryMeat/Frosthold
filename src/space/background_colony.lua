-- background_colony.lua — Counter-based simulation for absent colonies
-- Operates on serialized snapshot data, NOT live ECS.
-- Runs once per game-day for each colony the player has left behind.

local BackgroundColony = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local FOOD_PER_COLONIST_PER_DAY = 2.0
local FUEL_PER_DAY_BASE = 5.0
local DURABILITY_DECAY_PER_DAY = 0.5

local FOOD_ITEMS = { 'cooked_meat', 'stew', 'jerky', 'bread', 'ration', 'feast' }

---------------------------------------------------------------------------
-- Tick a background colony
-- snapshot: the colony's serialized save data table
-- daysPassed: integer number of game-days since last tick
-- automationScore: 0.0-1.0 (calculated at serialization)
-- Returns: log table { messages = {}, resourceChanges = {} }
---------------------------------------------------------------------------

function BackgroundColony.tick(snapshot, daysPassed, automationScore)
    if not snapshot or daysPassed <= 0 then
        return { messages = {}, resourceChanges = {} }
    end

    local log = { messages = {}, resourceChanges = {} }
    local entities = snapshot.entities or {}

    -- Count colonists
    local colonistCount = 0
    for _, ent in ipairs(entities) do
        if ent.colonist and (not ent.colonist.dead) then
            colonistCount = colonistCount + 1
        end
    end

    if colonistCount == 0 then
        log.messages[#log.messages + 1] = 'Colony abandoned — no colonists remain.'
        return log
    end

    -- Find storage entities and their contents
    local storageEntities = {}
    for _, ent in ipairs(entities) do
        if ent.storage and ent.storage.contents then
            storageEntities[#storageEntities + 1] = ent
        end
    end

    -- Helper: consume items from storage (tries all matching item IDs)
    local function consumeFromStorage(itemId, amount)
        local remaining = amount
        for _, ent in ipairs(storageEntities) do
            local stor = ent.storage
            for i = 1, (stor.slots or 0) do
                local slot = stor.contents[i]
                if slot and slot.itemId == itemId and remaining > 0 then
                    local take = math.min(slot.amount or 1, remaining)
                    slot.amount = (slot.amount or 1) - take
                    remaining = remaining - take
                    if slot.amount <= 0 then
                        stor.contents[i] = nil
                    end
                end
            end
        end
        return amount - remaining
    end

    -- Food consumption: try each food type until need is met
    local foodNeeded = math.ceil(colonistCount * FOOD_PER_COLONIST_PER_DAY * daysPassed)
    local foodConsumed = 0
    for _, foodId in ipairs(FOOD_ITEMS) do
        if foodConsumed >= foodNeeded then break end
        foodConsumed = foodConsumed + consumeFromStorage(foodId, foodNeeded - foodConsumed)
    end

    if foodConsumed < foodNeeded then
        log.messages[#log.messages + 1] = 'Food ran out! Colonists are starving.'
        for _, ent in ipairs(entities) do
            if ent.colonist and not ent.colonist.dead then
                ent.colonist.health = math.max(10, (ent.colonist.health or 100) - daysPassed * 5)
            end
        end
    end
    log.resourceChanges.food = -foodConsumed

    -- Fuel consumption
    local fuelNeeded = math.ceil(FUEL_PER_DAY_BASE * daysPassed)
    local fuelConsumed = consumeFromStorage('fuel', fuelNeeded)
    if fuelConsumed < fuelNeeded then
        log.messages[#log.messages + 1] = 'Fuel depleted! Reactor offline, colony freezing.'
    end
    log.resourceChanges.fuel = -fuelConsumed

    -- Production (automation-driven)
    if automationScore > 0 then
        if not snapshot.backgroundProduction then
            snapshot.backgroundProduction = {}
        end

        local machineCount = 0
        for _, ent in ipairs(entities) do
            if ent.machine and ent.machine.recipe then
                machineCount = machineCount + 1
            end
        end

        local produced = math.floor(machineCount * automationScore * daysPassed)
        if produced > 0 then
            snapshot.backgroundProduction['metal_ingot'] =
                (snapshot.backgroundProduction['metal_ingot'] or 0) + math.ceil(produced * 0.4)
            snapshot.backgroundProduction['lumber'] =
                (snapshot.backgroundProduction['lumber'] or 0) + math.ceil(produced * 0.3)
            snapshot.backgroundProduction['components'] =
                (snapshot.backgroundProduction['components'] or 0) + math.ceil(produced * 0.1)
            log.messages[#log.messages + 1] = 'Automated production generated ' .. produced .. ' items.'
            log.resourceChanges.produced = produced
        end
    end

    -- Building decay
    local brokenCount = 0
    for _, ent in ipairs(entities) do
        if ent.durability then
            ent.durability.hp = (ent.durability.hp or 100) - DURABILITY_DECAY_PER_DAY * daysPassed
            if ent.durability.hp <= 0 then
                ent.durability.hp = 0
                brokenCount = brokenCount + 1
            end
        end
    end
    if brokenCount > 0 then
        log.messages[#log.messages + 1] = brokenCount .. ' buildings broke down from neglect.'
    end

    return log
end

---------------------------------------------------------------------------
-- Convert backgroundProduction to physical items on colony restore
---------------------------------------------------------------------------

function BackgroundColony.spawnProduction(snapshot)
    if not snapshot or not snapshot.backgroundProduction then return end

    local produced = snapshot.backgroundProduction
    if not next(produced) then return end

    local entities = snapshot.entities or {}
    for _, ent in ipairs(entities) do
        if ent.storage and ent.storage.contents then
            local stor = ent.storage
            for itemId, amount in pairs(produced) do
                if amount > 0 then
                    for i = 1, (stor.slots or 0) do
                        if not stor.contents[i] then
                            stor.contents[i] = {
                                itemId = itemId,
                                amount = amount,
                                quality = 'normal',
                            }
                            produced[itemId] = 0
                            break
                        end
                    end
                end
            end
        end
    end

    snapshot.backgroundProduction = nil
end

return BackgroundColony
