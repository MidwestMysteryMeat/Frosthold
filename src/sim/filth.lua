-- filth.lua — Per-tile dirt/blood/vomit/trash accumulation and cleaning
-- Colonists track dirt, bleed, vomit from sickness, and leave meal trash.
-- Clean tasks are auto-created for tiles above a threshold.
-- Room impressiveness is penalized by average filth.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Filth = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local STEP_INTERVAL     = 5.0    -- seconds between filth scans
local CLEAN_THRESHOLD   = 20     -- filth level that triggers a clean task
local MAX_CLEAN_TASKS   = 10     -- max active clean tasks at once
local MAX_FILTH         = 100    -- per-tile cap
local OUTDOOR_DECAY     = 0.5    -- filth/sec decay on outdoor tiles (snow covers it)
local TASK_CLEAN_AMOUNT = 40     -- filth removed per clean task completion

-- Filth amounts per source
local DIRT_AMOUNT       = 3      -- foot traffic on natural ground
local DIRT_FLOOR_AMOUNT = 1      -- foot traffic on constructed floors
local BLOOD_AMOUNT      = 8      -- bleeding colonist per step
local VOMIT_AMOUNT      = 25     -- single vomit event
local TRASH_AMOUNT      = 10     -- meal waste after eating

-- Tiles that track more dirt when walked on
local DIRTY_TILES = {}  -- populated in init from Tiles

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local filthGrid = {}     -- filthGrid[depthKey] = number (0-100), key = depth*1000000 + tileIndex
local cleanTaskTiles = {} -- cleanTaskTiles[tileIndex] = taskId (avoid duplicates)
local stepTimer = 0

function Filth.init()
    filthGrid = {}
    cleanTaskTiles = {}
    stepTimer = 0
end

---------------------------------------------------------------------------
-- Core API
---------------------------------------------------------------------------

local function filthKey(x, y, depth)
    local World = require('src.world.tilemap')
    local idx = y * World.width() + x + 1
    return (depth or 0) * 1000000 + idx
end

function Filth.addFilth(x, y, amount, depth)
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) then return end
    local k = filthKey(x, y, depth)
    local cur = filthGrid[k] or 0
    filthGrid[k] = math.min(MAX_FILTH, cur + amount)
end

function Filth.getFilth(x, y, depth)
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) then return 0 end
    return filthGrid[filthKey(x, y, depth)] or 0
end

function Filth.getFilthByIndex(idx)
    return filthGrid[idx] or 0
end

function Filth.cleanTile(x, y, amount, depth)
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) then return end
    local k = filthKey(x, y, depth)
    local cur = filthGrid[k] or 0
    local newVal = cur - (amount or TASK_CLEAN_AMOUNT)
    if newVal <= 0 then
        filthGrid[k] = nil
    else
        filthGrid[k] = newVal
    end
end

-- Average filth across a set of tile indices (used by rooms)
function Filth.getRoomFilth(tileIndices)
    if not tileIndices or #tileIndices == 0 then return 0 end
    local total = 0
    for _, idx in ipairs(tileIndices) do
        total = total + (filthGrid[idx] or 0)
    end
    return total / #tileIndices
end

---------------------------------------------------------------------------
-- Filth generation hooks (called from other systems)
---------------------------------------------------------------------------

-- Called when a colonist steps onto a new tile
function Filth.onColonistStep(x, y, entityId, depth)
    local Tiles = require('src.world.tiles')
    local World = require('src.world.tilemap')
    local d = depth or 0
    local tile = World.getTile(x, y, d)
    if not tile then return end

    -- Bleeding check: colonists with untreated cuts leave blood
    local wounds = ECS.get(entityId, 'wounds')
    if wounds then
        for _, w in ipairs(wounds.list) do
            if w.type == 'cut' and w.treatment == 'untreated' and w.severity > 0.2 then
                Filth.addFilth(x, y, BLOOD_AMOUNT * w.severity, d)
                break  -- one blood deposit per step
            end
        end
    end

    -- Dirt tracking: higher chance on natural ground
    if tile == Tiles.DIRT or tile == Tiles.SNOW or tile == Tiles.PERMAFROST then
        if math.random() < 0.08 then
            Filth.addFilth(x, y, DIRT_AMOUNT, d)
        end
    elseif tile == Tiles.FLOOR_WOOD or tile == Tiles.FLOOR_STONE or
           tile == Tiles.FLOOR_METAL or tile == Tiles.FLOOR_INSULATED then
        if math.random() < 0.03 then
            Filth.addFilth(x, y, DIRT_FLOOR_AMOUNT, d)
        end
    end
end

-- Called when a colonist vomits (disease, intoxication)
function Filth.onVomit(x, y, depth)
    Filth.addFilth(x, y, VOMIT_AMOUNT, depth)
end

-- Called when a colonist finishes eating
function Filth.onMealTrash(x, y, depth)
    if math.random() < 0.4 then
        Filth.addFilth(x, y, TRASH_AMOUNT, depth)
    end
end

---------------------------------------------------------------------------
-- Step — outdoor decay + auto-create clean tasks
---------------------------------------------------------------------------

function Filth.step(dt)
    stepTimer = stepTimer + dt
    if stepTimer < STEP_INTERVAL then return end
    stepTimer = 0

    local World = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')
    local Jobs  = require('src.colonist.jobs')
    local mapW = World.width()

    -- Prune clean tasks for tiles that are already clean or task was cancelled
    for k, taskId in pairs(cleanTaskTiles) do
        local task = Jobs.getTask(taskId)
        if not task or task.complete then
            cleanTaskTiles[k] = nil
        elseif (filthGrid[k] or 0) < CLEAN_THRESHOLD then
            Jobs.cancelTask(taskId)
            cleanTaskTiles[k] = nil
        end
    end

    -- Decay outdoor filth (snow buries it)
    local decayAmount = OUTDOOR_DECAY * STEP_INTERVAL
    for k, level in pairs(filthGrid) do
        local depth = math.floor(k / 1000000)
        local idx = k - depth * 1000000
        local x = (idx - 1) % mapW
        local y = math.floor((idx - 1) / mapW)
        local tile = World.getTile(x, y, depth)
        if tile == Tiles.SNOW or tile == Tiles.ICE then
            local newLevel = level - decayAmount
            if newLevel <= 0 then
                filthGrid[k] = nil
            else
                filthGrid[k] = newLevel
            end
        end
    end

    -- Count existing clean tasks
    local activeCleanTasks = 0
    for _ in pairs(cleanTaskTiles) do
        activeCleanTasks = activeCleanTasks + 1
    end

    -- Find dirtiest tiles and create clean tasks.
    -- Only tiles near the colony (or indoors) qualify: auto-created clean
    -- tasks for wilderness blood trails marched colonists across the map
    -- into predator territory at night.
    local CLEAN_HOME_RADIUS = 24
    local homeX = GameState.startX
    local homeY = GameState.startY
    if activeCleanTasks < MAX_CLEAN_TASKS then
        local candidates = {}
        for k, level in pairs(filthGrid) do
            if level >= CLEAN_THRESHOLD and not cleanTaskTiles[k] then
                local depth = math.floor(k / 1000000)
                local idx = k - depth * 1000000
                local x = (idx - 1) % mapW
                local y = math.floor((idx - 1) / mapW)
                local nearHome = true
                if homeX and homeY then
                    nearHome = math.abs(x - homeX) <= CLEAN_HOME_RADIUS
                        and math.abs(y - homeY) <= CLEAN_HOME_RADIUS
                end
                local indoors = (World.getRoom(x, y, depth) or 0) > 0
                if nearHome or indoors then
                    candidates[#candidates + 1] = { key = k, level = level }
                end
            end
        end

        -- Sort by filth level descending (dirtiest first)
        table.sort(candidates, function(a, b) return a.level > b.level end)

        local toCreate = MAX_CLEAN_TASKS - activeCleanTasks
        for i = 1, math.min(toCreate, #candidates) do
            local c = candidates[i]
            local depth = math.floor(c.key / 1000000)
            local idx = c.key - depth * 1000000
            local x = (idx - 1) % mapW
            local y = math.floor((idx - 1) / mapW)
            local taskId = Jobs.createTask('clean', x, y, { filthLevel = c.level, depth = depth })
            if taskId then
                cleanTaskTiles[c.key] = taskId
            end
        end
    end
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Filth.getState()
    -- Only save tiles with filth > 0 (sparse)
    local data = {}
    for k, level in pairs(filthGrid) do
        data[#data + 1] = { key = k, level = level }
    end
    return { tiles = data }
end

function Filth.loadState(saved)
    filthGrid = {}
    cleanTaskTiles = {}
    stepTimer = 0
    if not saved or not saved.tiles then return end
    for _, entry in ipairs(saved.tiles) do
        -- Support both old (idx) and new (key) formats
        local k = entry.key or entry.idx or 0
        if k > 0 then
            filthGrid[k] = entry.level
        end
    end
end

return Filth
