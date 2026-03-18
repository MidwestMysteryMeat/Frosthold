-- tile_snow.lua — Per-tile snow accumulation simulation
-- Each tile stores a snow depth 0-7 (0=clear, 7=buried/impassable).
-- Snow accumulates on outdoor surface tiles during weather events,
-- drifts against walls based on wind direction, falls through open
-- vertical connections (channels, shafts), and melts from heat sources
-- (heated rooms, fire, generators, warm weather) into water via tile_fluids.
-- Indoor/sealed rooms are protected from accumulation.
-- Deep snow blocks movement and doors. Blizzard exposure is lethal.

local Tiles = require('src.world.tiles')

local _TileFluids
local function lazyLoadFluids()
    if _TileFluids ~= nil then return end
    local ok
    ok, _TileFluids = pcall(require, 'src.sim.tile_fluids')
    if not ok then _TileFluids = false end
end

local TileSnow = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local MAX_SNOW         = 7
local ACCUMULATE_INTERVAL = 10   -- ticks between accumulation passes (~0.5s at 20Hz)
local MELT_INTERVAL       = 20   -- ticks between melt passes (~1s at 20Hz)
local DRIFT_INTERVAL      = 40   -- ticks between wind drift passes (~2s)
local FALL_INTERVAL       = 30   -- ticks between vertical fall passes

-- Temperature thresholds
local MELT_TEMP        = -2    -- snow melts above this (Celsius)
local FAST_MELT_TEMP   = 5     -- snow melts rapidly above this

-- Movement multipliers by snow depth
local MOVE_MULT = {
    [0] = 1.0, [1] = 0.95, [2] = 0.85,
    [3] = 0.7, [4] = 0.55, [5] = 0.4,
    [6] = 0.25, [7] = 0.0,  -- impassable
}

-- Snow depth at which doors are blocked
local DOOR_BLOCK_DEPTH = 6

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local accumCounter = 0
local meltCounter  = 0
local driftCounter = 0
local fallCounter  = 0

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function TileSnow.init()
    accumCounter = 0
    meltCounter  = 0
    driftCounter = 0
    fallCounter  = 0
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Check if a tile is "outdoors" (not in a sealed room, not solid)
local function isOutdoor(tileType, roomId)
    if Tiles.isSolid(tileType) then return false end
    -- Room 0 = outdoor. Sealed rooms block snow.
    return roomId == 0
end

-- Check if a tile is sheltered (inside any room, sealed or not)
local function isSheltered(roomId, rooms)
    if roomId == 0 then return false end
    local room = rooms and rooms[roomId]
    -- Any room with walls counts as shelter, even if unsealed
    return room ~= nil
end

---------------------------------------------------------------------------
-- Accumulation pass — snow falls from weather onto outdoor tiles
---------------------------------------------------------------------------

function TileSnow.processAccumulation(World, w, h, snowRate, windAngle, windSpeed)
    if snowRate <= 0 then return end

    local tileData = World.rawTileData(0)
    local snowData = World.rawSnowData(0)
    local roomData = World.rawRoomData(0)
    if not tileData or not snowData or not roomData then return end

    -- Get room data for shelter check
    local tOk, Thermal = pcall(require, 'src.sim.thermal')
    local rooms = tOk and Thermal.getRooms() or nil

    local size = w * h
    -- Wind direction bias for drift accumulation
    local windDx = math.cos(windAngle)
    local windDy = math.sin(windAngle)

    for idx = 1, size do
        local tile = tileData[idx]
        local rid = roomData[idx] or 0

        -- Only accumulate on outdoor non-solid tiles
        if not isOutdoor(tile, rid) then goto acc_next end

        -- Skip sheltered tiles (inside any room structure)
        if isSheltered(rid, rooms) then goto acc_next end

        -- Skip water tiles, lava vents, volcanic warm tiles, cave mouths, etc.
        if tile == Tiles.WATER or tile == Tiles.LAVA_VENT or tile == Tiles.GEYSER
            or tile == Tiles.HOT_SPRING or tile == Tiles.FROZEN_LAKE
            or tile == Tiles.FROZEN_SEA or tile == Tiles.FROZEN_RIVER
            or tile == Tiles.VOLCANIC_FLOOR or tile == Tiles.CAVE_ENTRANCE then
            goto acc_next
        end

        local current = snowData[idx] or 0
        if current >= MAX_SNOW then goto acc_next end

        -- Base accumulation chance scaled by snowRate
        -- snowRate: 0.01 (overcast) to 0.3 (whiteout)
        local chance = snowRate * 0.6
        if math.random() < chance then
            snowData[idx] = math.min(MAX_SNOW, current + 1)
        end

        ::acc_next::
    end
end

---------------------------------------------------------------------------
-- Wind drift pass — snow drifts against walls on the leeward side
---------------------------------------------------------------------------

function TileSnow.processDrift(World, w, h, windAngle, windSpeed)
    if windSpeed < 0.2 then return end

    local tileData = World.rawTileData(0)
    local snowData = World.rawSnowData(0)
    if not tileData or not snowData then return end

    -- Wind direction: snow moves WITH the wind and piles against obstacles
    local windDx = math.cos(windAngle)
    local windDy = math.sin(windAngle)

    -- Primary wind direction (dominant axis)
    local dx = windDx > 0.3 and 1 or (windDx < -0.3 and -1 or 0)
    local dy = windDy > 0.3 and 1 or (windDy < -0.3 and -1 or 0)
    if dx == 0 and dy == 0 then return end

    local size = w * h
    for idx = 1, size do
        local current = snowData[idx] or 0
        if current < 2 then goto drift_next end  -- need snow to drift

        local x = (idx - 1) % w
        local y = math.floor((idx - 1) / w)

        -- Check the downwind neighbor
        local nx, ny = x + dx, y + dy
        if nx < 0 or nx >= w or ny < 0 or ny >= h then goto drift_next end

        local ni = ny * w + nx + 1
        local nTile = tileData[ni]

        -- If downwind neighbor is a wall, pile snow on THIS tile (leeward drift)
        if Tiles.isSolid(nTile) then
            if current < MAX_SNOW and math.random() < windSpeed * 0.15 then
                snowData[idx] = current + 1
            end
        else
            -- Move snow downwind if the neighbor has less
            local nSnow = snowData[ni] or 0
            if current > nSnow + 2 and math.random() < windSpeed * 0.1 then
                snowData[idx] = current - 1
                snowData[ni] = nSnow + 1
            end
        end

        ::drift_next::
    end
end

---------------------------------------------------------------------------
-- Melt pass — heat sources and warm tiles melt snow into water
---------------------------------------------------------------------------

function TileSnow.processMelt(World, w, h)
    lazyLoadFluids()

    -- Process all layers (snow can exist underground via vertical fall)
    for depth, _ in World.allLayers() do
        local snowData = World.rawSnowData(depth)
        local tempData = World.rawTempData(depth)
        local tileData = World.rawTileData(depth)
        if not snowData or not tempData then goto melt_layer_next end

        local size = w * h
        for idx = 1, size do
            local snow = snowData[idx] or 0
            if snow <= 0 then goto melt_next end

            local temp = tempData[idx] or -40

            if temp > MELT_TEMP then
                -- Melt rate scales with temperature above threshold
                local meltChance
                if temp > FAST_MELT_TEMP then
                    meltChance = 0.5 + (temp - FAST_MELT_TEMP) * 0.05
                else
                    meltChance = 0.15 + (temp - MELT_TEMP) * 0.03
                end

                if math.random() < math.min(0.9, meltChance) then
                    snowData[idx] = snow - 1

                    -- Melt into water (1 snow = partial water unit)
                    if _TileFluids and snow >= 3 then
                        local x = (idx - 1) % w
                        local y = math.floor((idx - 1) / w)
                        _TileFluids.addWater(x, y, 1, depth)
                    end
                end
            end

            ::melt_next::
        end

        ::melt_layer_next::
    end
end

---------------------------------------------------------------------------
-- Vertical fall — snow falls through open shafts, channels, stairwells
---------------------------------------------------------------------------

function TileSnow.processVerticalFall(World, w, h)
    -- Only surface snow falls down
    local snowData = World.rawSnowData(0)
    local tileData = World.rawTileData(0)
    if not snowData or not tileData then return end

    local size = w * h
    for idx = 1, size do
        local snow = snowData[idx] or 0
        if snow <= 0 then goto fall_next end

        local tile = tileData[idx]

        -- Snow falls through vertical connections (channels, open shafts)
        if Tiles.connectsDown(tile) then
            local belowSnow = World.rawSnowData(1)
            local belowTiles = belowSnow and World.rawTileData(1)
            if belowSnow and belowTiles then
                local belowTile = belowTiles[idx]
                if not Tiles.isSolid(belowTile) then
                    local belowLevel = belowSnow[idx] or 0
                    if belowLevel < MAX_SNOW and math.random() < 0.2 then
                        snowData[idx] = snow - 1
                        belowSnow[idx] = belowLevel + 1
                    end
                end
            end
        end

        ::fall_next::
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function TileSnow.getSnowAt(x, y, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end
    return World.getSnow(x, y, depth or 0)
end

function TileSnow.getMovementMult(x, y, depth)
    local snow = TileSnow.getSnowAt(x, y, depth)
    return MOVE_MULT[snow] or 1.0
end

function TileSnow.isImpassable(x, y, depth)
    return TileSnow.getSnowAt(x, y, depth) >= MAX_SNOW
end

function TileSnow.isDoorBlocked(x, y, depth)
    return TileSnow.getSnowAt(x, y, depth) >= DOOR_BLOCK_DEPTH
end

--- Get average snow depth for all tiles in a room (0.0 to 1.0 scale).
function TileSnow.getRoomSnowLevel(roomId)
    local tOk, Thermal = pcall(require, 'src.sim.thermal')
    if not tOk then return 0 end
    local rooms = Thermal.getRooms()
    local room = rooms and rooms[roomId]
    if not room or not room.tiles or #room.tiles == 0 then return 0 end

    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end
    local snowData = World.rawSnowData(room.depth or 0)
    if not snowData then return 0 end

    local total = 0
    for _, idx in ipairs(room.tiles) do
        total = total + (snowData[idx] or 0)
    end
    return (total / #room.tiles) / MAX_SNOW
end

---------------------------------------------------------------------------
-- Step — called each sim tick (20Hz)
---------------------------------------------------------------------------

function TileSnow.step(dt)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end

    local w = World.width()
    local h = World.height()

    -- Get weather data
    local weatherOk, Weather = pcall(require, 'src.weather.weather')
    local snowRate = 0
    local windAngle = 0
    local windSpeed = 0
    if weatherOk then
        local _, wType = Weather.getCurrent()
        snowRate = wType and wType.snowRate or 0
        windAngle = Weather.getWindAngle()
        windSpeed = Weather.getWindSpeed()
    end

    -- Accumulation (most frequent during weather)
    accumCounter = accumCounter + 1
    if accumCounter >= ACCUMULATE_INTERVAL then
        accumCounter = 0
        TileSnow.processAccumulation(World, w, h, snowRate, windAngle, windSpeed)
    end

    -- Wind drift
    driftCounter = driftCounter + 1
    if driftCounter >= DRIFT_INTERVAL then
        driftCounter = 0
        if snowRate > 0 then
            TileSnow.processDrift(World, w, h, windAngle, windSpeed)
        end
    end

    -- Melting (heat-driven)
    meltCounter = meltCounter + 1
    if meltCounter >= MELT_INTERVAL then
        meltCounter = 0
        TileSnow.processMelt(World, w, h)
    end

    -- Vertical fall through open connections
    fallCounter = fallCounter + 1
    if fallCounter >= FALL_INTERVAL then
        fallCounter = 0
        TileSnow.processVerticalFall(World, w, h)
    end
end

---------------------------------------------------------------------------
-- Persistence
-- Snow depth is stored in tilemap layer data (snow[] arrays).
-- No module-specific state to save beyond counters (which reset is fine).
---------------------------------------------------------------------------

function TileSnow.getState()
    return {}
end

function TileSnow.loadState(state)
    accumCounter = 0
    meltCounter  = 0
    driftCounter = 0
    fallCounter  = 0
end

return TileSnow
