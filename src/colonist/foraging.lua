-- foraging.lua — Tile-based resource discovery on outdoor terrain
-- Colonists with sufficient skill can forage on SNOW and PERMAFROST tiles.
-- Foraging is skill-gated: cooking for plants, hunting for tracking/meat.
-- Each tile has a cooldown before it can be foraged again.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')
local Jobs      = require('src.colonist.jobs')

local Foraging = {}

-- Per-tile cooldown tracking: { [tileKey] = ticksRemaining }
local tileCooldowns = {}
local COOLDOWN_TICKS = 500  -- sim ticks before a tile can be foraged again

-- Forageable tile types
local FORAGEABLE = {
    [Tiles.SNOW]         = true,
    [Tiles.PERMAFROST]   = true,
    [Tiles.TUNDRA_MARSH] = true,
    [Tiles.ASH_GROUND]   = true,
}

-- Drop tables: { {itemId, weight, minSkill, skillType} }
local DROP_TABLE = {
    { itemId = 'plant_fiber',     weight = 40, minSkill = 1, skillType = 'cooking' },
    { itemId = 'berries',         weight = 25, minSkill = 2, skillType = 'cooking' },
    { itemId = 'mushrooms',       weight = 20, minSkill = 3, skillType = 'cooking' },
    { itemId = 'medicinal_herb',  weight = 15, minSkill = 5, skillType = 'cooking' },
    { itemId = 'raw_meat',        weight = 10, minSkill = 3, skillType = 'hunting' },
}

local function tileKey(x, y, depth) return (depth or 0) * 100000000 + y * 10000 + x end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Foraging.init()
    tileCooldowns = {}
end

---------------------------------------------------------------------------
-- Step — tick down cooldowns
---------------------------------------------------------------------------

function Foraging.step(dt)
    -- Cooldowns decrement once per call (called at sim rate)
    for k, remaining in pairs(tileCooldowns) do
        remaining = remaining - 1
        if remaining <= 0 then
            tileCooldowns[k] = nil
        else
            tileCooldowns[k] = remaining
        end
    end
end

---------------------------------------------------------------------------
-- Check if a tile is forageable right now
---------------------------------------------------------------------------

function Foraging.canForage(x, y, depth)
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) then return false end
    local tile = World.getTile(x, y, depth or 0)
    if not FORAGEABLE[tile] then return false end
    local k = tileKey(x, y, depth)
    if tileCooldowns[k] then return false end
    return true
end

---------------------------------------------------------------------------
-- Attempt a forage at a tile. Returns itemId, amount or nil.
-- colonistId is needed to check skills.
---------------------------------------------------------------------------

function Foraging.attemptForage(colonistId, x, y, depth)
    if not Foraging.canForage(x, y, depth) then return nil end

    local col = ECS.get(colonistId, 'colonist')
    if not col or not col.skills then return nil end

    -- Put tile on cooldown regardless of success
    tileCooldowns[tileKey(x, y, depth)] = COOLDOWN_TICKS

    -- Build eligible drops based on colonist skills
    local eligible = {}
    local totalWeight = 0
    for _, drop in ipairs(DROP_TABLE) do
        local skill = col.skills[drop.skillType] or 0
        if skill >= drop.minSkill then
            eligible[#eligible + 1] = drop
            totalWeight = totalWeight + drop.weight
        end
    end

    if #eligible == 0 or totalWeight == 0 then
        return nil
    end

    -- Weighted random selection
    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, drop in ipairs(eligible) do
        cumulative = cumulative + drop.weight
        if roll <= cumulative then
            -- Amount: 1, with a small chance of 2 based on skill
            local skill = col.skills[drop.skillType] or 1
            local amount = 1
            if math.random() < skill * 0.05 then
                amount = 2
            end
            -- Trait farmMod: green_thumb +20% chance for extra yield
            if col.traits then
                for _, t in ipairs(col.traits) do
                    if t.farmMod and math.random() < t.farmMod then
                        amount = amount + 1
                    end
                end
            end
            -- Seasonal foraging bonus (thaw = +50%, deep winter = -50%)
            local sok, Seasons = pcall(require, 'src.world.seasons')
            if sok then
                local bonus = Seasons.getForageBonus()
                if bonus > 0 and math.random() < bonus then
                    amount = amount + 1
                elseif bonus < 0 and math.random() < math.abs(bonus) then
                    amount = math.max(1, amount - 1)
                end
            end
            return drop.itemId, amount
        end
    end

    return nil
end

---------------------------------------------------------------------------
-- Create a foraging task at a tile
---------------------------------------------------------------------------

-- Add 'forage' job type if not already present
if not Jobs.TYPES.forage then
    Jobs.TYPES.forage = {
        name     = 'Forage',
        skill    = 'cooking',
        priority = 'cooking',
        duration = 3.0,
    }
end

function Foraging.designateForage(x, y, depth)
    if not Foraging.canForage(x, y, depth) then return nil end
    return Jobs.createTask('forage', x, y, { depth = depth or 0 })
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Foraging.getCooldown(x, y, depth)
    return tileCooldowns[tileKey(x, y, depth)] or 0
end

function Foraging.getForageableTiles()
    return FORAGEABLE
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Foraging.getState()
    return {
        tileCooldowns = tileCooldowns,
    }
end

function Foraging.loadState(saved)
    if not saved then return end
    tileCooldowns = saved.tileCooldowns or {}
end

return Foraging
