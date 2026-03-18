-- tile_fluids.lua — Per-tile water simulation (DF-style)
-- Each tile stores a water level 0-7 (0=dry, 7=full).
-- Water flows horizontally to lower neighbors, falls through vertical connections
-- (stairs, channels, shafts), and rises under pressure.
-- Freezing/thawing tied to tile temperature. Evaporation in warm areas.
-- Replaces room-level flooding as the source of truth; flooding.lua derives
-- room water levels from tile averages for backward-compatible effect triggers.

local Tiles = require('src.world.tiles')

local TileFluids = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local MAX_WATER       = 7
local MAX_SPREAD      = 200   -- max tile updates per sim tick (performance cap)
local FREEZE_TEMP     = -5    -- water begins freezing below this (Celsius)
local THAW_TEMP       = 2     -- ice begins thawing above this
local EVAP_TEMP       = 15    -- water evaporates above this
local EVAP_INTERVAL   = 200   -- ticks between evaporation passes (~10s at 20Hz)
local FREEZE_INTERVAL = 60    -- ticks between freeze/thaw passes (~3s)
local PRESSURE_HEIGHT = 4     -- water column height needed to push water up
local DIRS            = { {-1,0}, {1,0}, {0,-1}, {0,1} }

-- Water injected by various sources
TileFluids.ICE_MINE_WATER   = 4   -- mining an ice tile
TileFluids.PIPE_BURST_WATER = 5   -- burst pipe
TileFluids.RAIN_WATER       = 1   -- rainfall on outdoor tiles

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

-- Dirty tile set: tiles with water > 0 that need processing.
-- Key: depth * 100_000_000 + tileIdx
local dirty = {}
local dirtyCount = 0

-- Freeze progress: { [tileKey] = ticks } — accumulated freeze time
local freezeProgress = {}

-- Timers
local evapCounter  = 0
local freezeCounter = 0

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function tileKey(depth, idx)
    return (depth or 0) * 100000000 + idx
end

local function decodeTileKey(k)
    local depth = math.floor(k / 100000000)
    local idx = k - depth * 100000000
    return depth, idx
end

local function markDirty(depth, idx)
    local k = tileKey(depth, idx)
    if not dirty[k] then
        dirty[k] = true
        dirtyCount = dirtyCount + 1
    end
end

local function clearDirty(k)
    if dirty[k] then
        dirty[k] = nil
        dirtyCount = dirtyCount - 1
    end
end

local function getWaterPermeability(World, x, y, depth, tileType)
    if World.isDoorLocked and World.isDoorLocked(x, y) then
        return 0
    end
    return Tiles.getWaterPermeability(tileType)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function TileFluids.init()
    dirty = {}
    dirtyCount = 0
    freezeProgress = {}
    evapCounter = 0
    freezeCounter = 0
end

---------------------------------------------------------------------------
-- Public: inject water at a tile (called by terraform, pipes, etc.)
---------------------------------------------------------------------------

function TileFluids.addWater(x, y, amount, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    depth = depth or 0
    if not World.inBounds(x, y) then return end

    local current = World.getWater(x, y, depth)
    local newLevel = math.min(MAX_WATER, current + amount)
    if newLevel > current then
        World.setWater(x, y, newLevel, depth)
        local w = World.width()
        markDirty(depth, y * w + x + 1)
    end
end

--- Remove water from a tile (pumps, consumption)
function TileFluids.removeWater(x, y, amount, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end
    depth = depth or 0

    local current = World.getWater(x, y, depth)
    local removed = math.min(current, amount)
    if removed > 0 then
        World.setWater(x, y, current - removed, depth)
    end
    return removed
end

---------------------------------------------------------------------------
-- Simulation step — called each sim tick (20Hz)
---------------------------------------------------------------------------

function TileFluids.step(dt)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end

    local w = World.width()
    local h = World.height()

    -- Phase 1: Gravity flow (water falls through vertical connections)
    local processed = 0
    local gravityMoves = {}  -- collect moves to apply after scan

    for k in pairs(dirty) do
        if processed >= MAX_SPREAD then break end
        local depth, idx = decodeTileKey(k)
        local waterData = World.rawWaterData(depth)
        if not waterData then goto grav_continue end

        local level = waterData[idx] or 0
        if level <= 0 then goto grav_continue end

        local tileData = World.rawTileData(depth)
        local tile = tileData[idx]

        -- Check if this tile connects downward
        if Tiles.connectsDown(tile) then
            local belowDepth = depth + 1
            local belowWater = World.rawWaterData(belowDepth)
            local belowTiles = belowWater and World.rawTileData(belowDepth)
            if belowWater and belowTiles then
                local belowTile = belowTiles[idx]
                -- Only flow into non-solid tiles
                if not Tiles.isSolid(belowTile) then
                    local belowLevel = belowWater[idx] or 0
                    if belowLevel < MAX_WATER then
                        local transfer = math.min(level, MAX_WATER - belowLevel)
                        gravityMoves[#gravityMoves + 1] = {
                            fromDepth = depth, toDepth = belowDepth, idx = idx,
                            amount = transfer,
                        }
                        processed = processed + 1
                    end
                end
            end
        end

        -- Channels allow water to fall even without connects_down on the tile below
        -- (the channel IS the hole)
        ::grav_continue::
    end

    -- Apply gravity moves
    for _, move in ipairs(gravityMoves) do
        local fromWater = World.rawWaterData(move.fromDepth)
        local toWater   = World.rawWaterData(move.toDepth)
        if fromWater and toWater then
            local fromLevel = fromWater[move.idx] or 0
            local toLevel   = toWater[move.idx] or 0
            local transfer  = math.min(move.amount, fromLevel, MAX_WATER - toLevel)
            if transfer > 0 then
                fromWater[move.idx] = fromLevel - transfer
                toWater[move.idx]   = toLevel + transfer
                markDirty(move.toDepth, move.idx)
                if fromWater[move.idx] <= 0 then
                    clearDirty(tileKey(move.fromDepth, move.idx))
                end
            end
        end
    end

    -- Phase 2: Horizontal spreading (equalize with cardinal neighbors)
    local horizMoves = {}
    processed = 0

    for k in pairs(dirty) do
        if processed >= MAX_SPREAD then break end
        local depth, idx = decodeTileKey(k)
        local waterData = World.rawWaterData(depth)
        if not waterData then goto horiz_continue end

        local level = waterData[idx] or 0
        if level <= 0 then
            clearDirty(k)
            goto horiz_continue
        end

        local tileData = World.rawTileData(depth)
        local x = (idx - 1) % w
        local y = math.floor((idx - 1) / w)

        -- Check 4 cardinal neighbors
        for _, d in ipairs(DIRS) do
            local nx, ny = x + d[1], y + d[2]
            if nx >= 0 and nx < w and ny >= 0 and ny < h then
                local ni = ny * w + nx + 1
                local nTile = tileData[ni]
                -- Water flows into walkable non-solid tiles (not through walls)
                if not Tiles.isSolid(nTile) then
                    local perm = math.min(
                        getWaterPermeability(World, x, y, depth, tileData[idx]),
                        getWaterPermeability(World, nx, ny, depth, nTile)
                    )
                    if perm <= 0 then goto next_dir end
                    local nLevel = waterData[ni] or 0
                    if level > nLevel + 1 then
                        local transfer = math.floor((level - nLevel) / 4)
                        if transfer < 1 then transfer = 1 end
                        transfer = math.floor(transfer * perm + 0.5)
                        if transfer < 1 then transfer = 1 end
                        horizMoves[#horizMoves + 1] = {
                            depth = depth, fromIdx = idx, toIdx = ni,
                            amount = transfer,
                        }
                        processed = processed + 1
                    end
                end
                ::next_dir::
            end
        end

        ::horiz_continue::
    end

    -- Apply horizontal moves (staged to prevent multi-hop)
    for _, move in ipairs(horizMoves) do
        local waterData = World.rawWaterData(move.depth)
        if waterData then
            local fromLevel = waterData[move.fromIdx] or 0
            local toLevel   = waterData[move.toIdx] or 0
            local transfer  = math.min(move.amount, fromLevel, MAX_WATER - toLevel)
            if transfer > 0 and fromLevel > toLevel + 1 then
                waterData[move.fromIdx] = fromLevel - transfer
                waterData[move.toIdx]   = toLevel + transfer
                markDirty(move.depth, move.toIdx)
                if waterData[move.fromIdx] <= 0 then
                    clearDirty(tileKey(move.depth, move.fromIdx))
                end
            end
        end
    end

    -- Phase 3: Pressure (simplified — full columns push water up through stairs)
    for k in pairs(dirty) do
        local depth, idx = decodeTileKey(k)
        if depth <= 0 then goto pressure_continue end
        local waterData = World.rawWaterData(depth)
        if not waterData then goto pressure_continue end
        local level = waterData[idx] or 0
        if level < MAX_WATER then goto pressure_continue end

        local tileData = World.rawTileData(depth)
        local tile = tileData[idx]

        -- Only push up through tiles that connect upward (stairs, shafts)
        if not Tiles.connectsUp(tile) then goto pressure_continue end

        -- Count water column below (same x,y, consecutive depths)
        local columnHeight = 1
        local checkDepth = depth + 1
        while columnHeight < PRESSURE_HEIGHT do
            local belowWater = World.rawWaterData(checkDepth)
            if not belowWater then break end
            local belowLevel = belowWater[idx] or 0
            if belowLevel < MAX_WATER then break end
            columnHeight = columnHeight + 1
            checkDepth = checkDepth + 1
        end

        if columnHeight >= PRESSURE_HEIGHT then
            local aboveDepth = depth - 1
            local aboveWater = World.rawWaterData(aboveDepth)
            local aboveTiles = aboveWater and World.rawTileData(aboveDepth)
            if aboveWater and aboveTiles then
                local aboveTile = aboveTiles[idx]
                if not Tiles.isSolid(aboveTile) then
                    local aboveLevel = aboveWater[idx] or 0
                    if aboveLevel < MAX_WATER then
                        local push = math.min(2, MAX_WATER - aboveLevel)
                        aboveWater[idx] = aboveLevel + push
                        waterData[idx]  = level - push
                        markDirty(aboveDepth, idx)
                    end
                end
            end
        end

        ::pressure_continue::
    end

    -- Phase 4: Periodic freezing / thawing
    freezeCounter = freezeCounter + 1
    if freezeCounter >= FREEZE_INTERVAL then
        freezeCounter = 0
        TileFluids.processFreezing(World, w, h)
    end

    -- Phase 5: Periodic evaporation
    evapCounter = evapCounter + 1
    if evapCounter >= EVAP_INTERVAL then
        evapCounter = 0
        TileFluids.processEvaporation(World, w, h)
    end

    -- Clean up: remove dirty entries with no water
    local toClean = {}
    for k in pairs(dirty) do
        local depth, idx = decodeTileKey(k)
        local waterData = World.rawWaterData(depth)
        if waterData and (waterData[idx] or 0) <= 0 then
            toClean[#toClean + 1] = k
        end
    end
    for _, k in ipairs(toClean) do
        clearDirty(k)
    end
end

---------------------------------------------------------------------------
-- Freeze / Thaw pass
---------------------------------------------------------------------------

function TileFluids.processFreezing(World, w, h)
    for depth, _ in World.allLayers() do
        local waterData = World.rawWaterData(depth)
        local tempData  = World.rawTempData(depth)
        local tileData  = World.rawTileData(depth)
        if not waterData or not tempData or not tileData then goto fz_next end

        local size = w * h
        for idx = 1, size do
            local wl = waterData[idx] or 0
            local temp = tempData[idx] or -40

            local k = tileKey(depth, idx)
            if wl > 0 and temp < FREEZE_TEMP then
                -- Accumulate freeze progress
                freezeProgress[k] = (freezeProgress[k] or 0) + 1
                -- Freeze after sustained cold (6 passes = ~18 seconds)
                if freezeProgress[k] >= 6 then
                    waterData[idx] = 0
                    tileData[idx] = Tiles.ICE
                    freezeProgress[k] = nil
                    clearDirty(k)
                end
            elseif tileData[idx] == Tiles.ICE and temp > THAW_TEMP then
                -- Thaw ice back to water
                freezeProgress[k] = (freezeProgress[k] or 0) - 2  -- thaws 2x faster
                if (freezeProgress[k] or 0) <= -4 then
                    -- Restore appropriate tile type based on depth
                    if depth == 0 then
                        tileData[idx] = Tiles.WATER
                    else
                        tileData[idx] = Tiles.UNDERGROUND_FLOOR
                    end
                    waterData[idx] = 3  -- partial water from melted ice
                    freezeProgress[k] = nil
                    markDirty(depth, idx)
                end
            elseif freezeProgress[k] then
                -- Not freezing or thawing; decay progress
                freezeProgress[k] = freezeProgress[k] - 1
                if freezeProgress[k] <= 0 then
                    freezeProgress[k] = nil
                end
            end
        end

        ::fz_next::
    end
end

---------------------------------------------------------------------------
-- Evaporation pass
---------------------------------------------------------------------------

function TileFluids.processEvaporation(World, w, h)
    for depth, _ in World.allLayers() do
        local waterData = World.rawWaterData(depth)
        local tempData  = World.rawTempData(depth)
        if not waterData or not tempData then goto ev_next end

        local size = w * h
        for idx = 1, size do
            local wl = waterData[idx] or 0
            if wl > 0 then
                local temp = tempData[idx] or -40
                if temp > EVAP_TEMP then
                    waterData[idx] = wl - 1
                    if waterData[idx] <= 0 then
                        clearDirty(tileKey(depth, idx))
                    end
                end
                -- Surface outdoor tiles drain slowly (rain runoff)
                if depth == 0 then
                    local tileData = World.rawTileData(depth)
                    local tile = tileData[idx]
                    -- Snow/permafrost/dirt are outdoor-ish
                    if tile == Tiles.SNOW or tile == Tiles.PERMAFROST or tile == Tiles.DIRT then
                        if math.random() < 0.1 then
                            waterData[idx] = math.max(0, wl - 1)
                        end
                    end
                end
            end
        end

        ::ev_next::
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

--- Get average water level (0-7) for all tiles in a room.
--- Used by flooding.lua to derive room-level water for effects.
function TileFluids.getRoomWaterLevel(roomId)
    local tOk, Thermal = pcall(require, 'src.sim.thermal')
    if not tOk then return 0 end
    local rooms = Thermal.getRooms()
    local room = rooms and rooms[roomId]
    if not room or not room.tiles or #room.tiles == 0 then return 0 end

    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end
    local waterData = World.rawWaterData(room.depth or 0)
    if not waterData then return 0 end

    local total = 0
    for _, idx in ipairs(room.tiles) do
        total = total + (waterData[idx] or 0)
    end
    -- Map 0-7 per tile to 0.0-1.0 room level
    return (total / #room.tiles) / MAX_WATER
end

--- Get water level at a specific tile
function TileFluids.getWaterAt(x, y, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end
    return World.getWater(x, y, depth or 0)
end

--- Check if a tile is submerged (water level >= 6)
function TileFluids.isSubmerged(x, y, depth)
    return TileFluids.getWaterAt(x, y, depth) >= 6
end

--- Get movement speed multiplier for a tile based on water level
function TileFluids.getMovementMult(x, y, depth)
    local level = TileFluids.getWaterAt(x, y, depth)
    if level >= 6 then return 0.3 end
    if level >= 4 then return 0.6 end
    if level >= 2 then return 0.8 end
    return 1.0
end

function TileFluids.getDirtyCount()
    return dirtyCount
end

--- Mark all wet tiles on a depth layer as dirty (call after bulk water writes).
--- Used by caverns.lua after generating underground lakes.
function TileFluids.markLayerDirty(depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    local waterData = World.rawWaterData(depth)
    if not waterData then return end
    local w = World.width()
    local h = World.height()
    local size = w * h
    for idx = 1, size do
        if (waterData[idx] or 0) > 0 then
            markDirty(depth, idx)
        end
    end
end

---------------------------------------------------------------------------
-- Event hooks (called by other systems)
---------------------------------------------------------------------------

--- Called when an ice tile is mined underground
function TileFluids.onIceMined(x, y, depth)
    TileFluids.addWater(x, y, TileFluids.ICE_MINE_WATER, depth)
end

--- Called when a pipe bursts
function TileFluids.onPipeBurst(x, y, depth)
    TileFluids.addWater(x, y, TileFluids.PIPE_BURST_WATER, depth)
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

-- Water arrays are saved as part of tilemap layer data (water[]).
-- Only module-specific state needs separate save/load.

function TileFluids.getState()
    -- Rebuild dirty set from water data on load, so we don't need to save it
    return {
        freezeProgress = freezeProgress,
    }
end

function TileFluids.loadState(state)
    freezeProgress = (state and state.freezeProgress) or {}
    evapCounter = 0
    freezeCounter = 0

    -- Rebuild dirty set from tilemap water data
    dirty = {}
    dirtyCount = 0
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    local w = World.width()
    local h = World.height()
    local size = w * h
    for depth, _ in World.allLayers() do
        local waterData = World.rawWaterData(depth)
        if waterData then
            for idx = 1, size do
                if (waterData[idx] or 0) > 0 then
                    markDirty(depth, idx)
                end
            end
        end
    end
end

return TileFluids
