-- terraform.lua — Terraforming operations and permafrost thaw simulation
-- Player designates areas for terrain modification (smooth, clear, excavate, lay floor).
-- Permafrost thaw: tiles above a temperature threshold for extended time convert to DIRT.
-- Colonists execute terraform tasks through the job system.

local Tiles     = require('src.world.tiles')
local GameState = require('src.game_state')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end
local _StorageNet
local function getStorageNet()
    if _StorageNet == nil then
        local ok, mod = pcall(require, 'src.logistics.storage_network')
        _StorageNet = ok and mod or false
    end
    return _StorageNet or nil
end

local Terraform = {}

---------------------------------------------------------------------------
-- Operation definitions
-- source: tile types this op can target
-- result: what the tile becomes
-- duration: base work time in seconds
-- skill: required colonist skill (nil = any)
-- cost: resource cost table (nil = free)
-- yield: resource yield table (nil = nothing)
---------------------------------------------------------------------------

Terraform.OPS = {
    smooth = {
        name     = 'Smooth',
        desc     = 'Level rough terrain into workable ground.',
        source   = { [Tiles.DEBRIS] = true },
        result   = Tiles.DIRT,
        duration = 2.0,
        skill    = 'mining',
        yield    = { stone = 1 },
    },
    clear = {
        name     = 'Clear',
        desc     = 'Remove debris and expose bare ground.',
        source   = { [Tiles.DEBRIS] = true },
        result   = Tiles.SNOW,
        duration = 1.5,
        skill    = nil,
    },
    excavate_rock = {
        name     = 'Excavate',
        desc     = 'Dig out solid rock.',
        source   = { [Tiles.ROCK] = true },
        result   = Tiles.DEBRIS,
        duration = 4.0,
        skill    = 'mining',
        yield    = { stone = 2 },
    },
    excavate_permafrost = {
        name     = 'Excavate',
        desc     = 'Dig out frozen ground.',
        source   = { [Tiles.PERMAFROST] = true },
        result   = Tiles.DEBRIS,
        duration = 3.0,
        skill    = 'mining',
        yield    = { stone = 1 },
    },
    excavate_deep_rock = {
        name     = 'Excavate Deep Rock',
        desc     = 'Dig into deep underground stone.',
        source   = { [Tiles.DEEP_ROCK] = true },
        result   = Tiles.UNDERGROUND_FLOOR,
        duration = 5.0,
        skill    = 'mining',
        yield    = { stone = 3 },
    },
    excavate_underground_rock = {
        name     = 'Excavate Underground',
        desc     = 'Hollow out underground stone.',
        source   = { [Tiles.UNDERGROUND_ROCK] = true },
        result   = Tiles.UNDERGROUND_FLOOR,
        duration = 4.0,
        skill    = 'mining',
        yield    = { stone = 2 },
    },
    excavate_biological_wall = {
        name     = 'Excavate Cavern Wall',
        desc     = 'Cut through living cavern tissue and fungal growth.',
        source   = { [Tiles.FUNGAL_WALL] = true, [Tiles.MEMBRANE_WALL] = true, [Tiles.ORGAN_WALL] = true },
        result   = Tiles.UNDERGROUND_FLOOR,
        duration = 4.5,
        skill    = 'mining',
    },
    excavate_volcanic_rock = {
        name     = 'Excavate Volcanic',
        desc     = 'Dig out volcanic stone.',
        source   = { [Tiles.VOLCANIC_ROCK] = true },
        result   = Tiles.VOLCANIC_FLOOR,
        duration = 4.0,
        skill    = 'mining',
        yield    = { stone = 4 },
    },
    dig_shaft = {
        name     = 'Dig Shaft',
        desc     = 'Dig a shaft entrance connecting to the layer below.',
        source   = { [Tiles.DEEP_ROCK] = true, [Tiles.UNDERGROUND_ROCK] = true, [Tiles.UNDERGROUND_FLOOR] = true },
        result   = Tiles.SHAFT_ENTRANCE,
        duration = 6.0,
        skill    = 'mining',
        cost     = { wood = 4, metal = 2 },
        yield    = { stone = 2 },
    },
    drain = {
        name     = 'Drain',
        desc     = 'Dig drainage channels to remove standing water.',
        source   = { [Tiles.WATER] = true },
        result   = Tiles.DIRT,
        duration = 3.0,
        skill    = 'mining',
    },

    -- DF-style vertical digging
    dig_stair_down = {
        name     = 'Dig Stairs Down',
        desc     = 'Carve a stairway leading to the layer below.',
        source   = { [Tiles.UNDERGROUND_FLOOR] = true, [Tiles.DEEP_ROCK] = true,
                     [Tiles.UNDERGROUND_ROCK] = true, [Tiles.PERMAFROST] = true },
        result   = Tiles.STAIR_DOWN,
        duration = 5.0,
        skill    = 'mining',
        cost     = { stone = 2 },
        yield    = { stone = 1 },
    },
    dig_stair_up = {
        name     = 'Dig Stairs Up',
        desc     = 'Carve a stairway leading to the layer above.',
        source   = { [Tiles.UNDERGROUND_FLOOR] = true, [Tiles.UNDERGROUND_ROCK] = true },
        result   = Tiles.STAIR_UP,
        duration = 5.0,
        skill    = 'mining',
        cost     = { stone = 2 },
    },
    dig_channel = {
        name     = 'Dig Channel',
        desc     = 'Remove the floor to create an open pit to the layer below. Dangerous.',
        source   = { [Tiles.UNDERGROUND_FLOOR] = true, [Tiles.SNOW] = true,
                     [Tiles.PERMAFROST] = true, [Tiles.DIRT] = true },
        result   = Tiles.CHANNEL,
        duration = 3.0,
        skill    = 'mining',
        yield    = { stone = 1 },
    },
    carve_ramp = {
        name     = 'Carve Ramp',
        desc     = 'Carve a ramp from solid rock for smooth vertical movement.',
        source   = { [Tiles.UNDERGROUND_ROCK] = true, [Tiles.DEEP_ROCK] = true },
        result   = Tiles.RAMP_UP,
        duration = 4.0,
        skill    = 'mining',
        yield    = { stone = 2 },
    },
}

---------------------------------------------------------------------------
-- Permafrost thaw tracking
-- Tiles above THAW_THRESHOLD for THAW_TICKS_REQUIRED accumulate warmth
-- and eventually convert PERMAFROST -> DIRT.
---------------------------------------------------------------------------

local THAW_THRESHOLD      = 5     -- degrees C
local THAW_TICKS_REQUIRED = 600   -- ~30 seconds at 20Hz
local THAW_CHECK_INTERVAL = 5.0   -- seconds between scans

local thawProgress = {}   -- { [depth*100000000+tileIdx] = warmTicks }
local thawTimer    = 0

local function thawKey(depth, idx) return (depth or 0) * 100000000 + idx end

---------------------------------------------------------------------------
-- Validation
---------------------------------------------------------------------------

function Terraform.canApply(opId, x, y, depth)
    local World = require('src.world.tilemap')
    local op = Terraform.OPS[opId]
    if not op then return false end

    local tile = World.getTile(x, y, depth)
    if not op.source[tile] then return false end

    -- Check resource cost
    if op.cost then
        for res, amount in pairs(op.cost) do
            if (GameState.resources[res] or 0) < amount then return false end
        end
    end

    return true
end

-- Find the appropriate excavation op for a tile
function Terraform.getExcavateOp(tileType)
    if tileType == Tiles.ROCK       then return 'excavate_rock' end
    if tileType == Tiles.PERMAFROST then return 'excavate_permafrost' end
    if tileType == Tiles.DEEP_ROCK  then return 'excavate_deep_rock' end
    if tileType == Tiles.UNDERGROUND_ROCK then return 'excavate_underground_rock' end
    if tileType == Tiles.VOLCANIC_ROCK then return 'excavate_volcanic_rock' end
    if tileType == Tiles.FUNGAL_WALL or tileType == Tiles.MEMBRANE_WALL or tileType == Tiles.ORGAN_WALL then
        return 'excavate_biological_wall'
    end
    return nil
end

---------------------------------------------------------------------------
-- Execute a terraform operation (called by work_ai when task completes)
---------------------------------------------------------------------------

function Terraform.execute(opId, x, y, depth)
    local World = require('src.world.tilemap')
    local op = Terraform.OPS[opId]
    if not op then return false end

    depth = depth or 0
    local tile = World.getTile(x, y, depth)
    if not op.source[tile] then return false end

    -- Deduct cost
    if op.cost then
        local SNet = getStorageNet()
        for res, amount in pairs(op.cost) do
            if SNet then SNet.withdraw(res, amount, x, y)
            else GameState.spendResource(res, amount) end
        end
    end

    -- Special handling for vertical operations
    if opId == 'dig_shaft' then
        World.digShaftDown(x, y, depth)

    elseif opId == 'dig_stair_down' then
        World.setTile(x, y, Tiles.STAIR_DOWN, depth)
        local toDepth = depth + 1
        World.createLayer(toDepth)
        -- Place matching stair up below, clear surrounding area
        local belowTile = World.getTile(x, y, toDepth)
        if belowTile == Tiles.STAIR_DOWN then
            World.setTile(x, y, Tiles.STAIR_BOTH, toDepth)
        else
            World.setTile(x, y, Tiles.STAIR_UP, toDepth)
        end
        -- Clear a small area around the stair on the destination layer
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    local nx, ny = x + dx, y + dy
                    if World.inBounds(nx, ny) then
                        local nt = World.getTile(nx, ny, toDepth)
                        if nt == Tiles.UNDERGROUND_ROCK then
                            World.setTile(nx, ny, Tiles.UNDERGROUND_FLOOR, toDepth)
                        end
                    end
                end
            end
        end

    elseif opId == 'dig_stair_up' then
        -- Validate layer above exists and is accessible
        if depth > 0 then
            local aboveTile = World.getTile(x, y, depth - 1)
            World.setTile(x, y, Tiles.STAIR_UP, depth)
            -- Place matching connection above
            if aboveTile == Tiles.STAIR_UP then
                World.setTile(x, y, Tiles.STAIR_BOTH, depth - 1)
            elseif not Tiles.connectsDown(aboveTile) then
                World.setTile(x, y, Tiles.STAIR_DOWN, depth - 1)
            end
        else
            World.setTile(x, y, op.result, depth)
        end

    elseif opId == 'dig_channel' then
        World.setTile(x, y, Tiles.CHANNEL, depth)
        local toDepth = depth + 1
        World.createLayer(toDepth)
        -- Excavate the tile below if it's solid
        local belowTile = World.getTile(x, y, toDepth)
        if belowTile == Tiles.UNDERGROUND_ROCK or belowTile == Tiles.DEEP_ROCK then
            World.setTile(x, y, Tiles.UNDERGROUND_FLOOR, toDepth)
        end

    elseif opId == 'carve_ramp' then
        World.setTile(x, y, Tiles.RAMP_UP, depth)
        -- Ensure layer above has a walkable tile for the ramp to connect to
        if depth > 0 then
            local aboveTile = World.getTile(x, y, depth - 1)
            if not Tiles.isWalkable(aboveTile) and not Tiles.connectsDown(aboveTile) then
                World.setTile(x, y, Tiles.STAIR_DOWN, depth - 1)
            end
        end

    elseif opId == 'excavate_biological_wall' then
        local floorTile = Tiles.UNDERGROUND_FLOOR
        if tile == Tiles.FUNGAL_WALL then
            floorTile = Tiles.FUNGAL_FLOOR
        elseif tile == Tiles.MEMBRANE_WALL then
            floorTile = Tiles.MEMBRANE_FLOOR
        elseif tile == Tiles.ORGAN_WALL then
            floorTile = Tiles.ORGAN_FLOOR
        end
        World.setTile(x, y, floorTile, depth)

    else
        World.setTile(x, y, op.result, depth)
    end

    -- Grant yield
    if op.yield then
        local Items = getItems()
        for res, amount in pairs(op.yield) do
            if Items then Items.spawn(x, y, res, amount, nil, depth)
            else GameState.addResource(res, amount) end
        end
    end

    -- Mining ice tiles: inject water at tile level
    if tile == Tiles.ICE then
        local tfOk, TileFluids = pcall(require, 'src.sim.tile_fluids')
        if tfOk and TileFluids.onIceMined then
            TileFluids.onIceMined(x, y, depth)
        end
    end

    -- Clean up biocave growth tracking if the original tile was biological
    local tileProps = Tiles.get(tile)
    if tileProps and (tileProps.biological or tileProps.containsGrowth or tile == Tiles.GROWTH_CREEP) then
        local bcOk2, BioCaves2 = pcall(require, 'src.world.biocaves')
        if bcOk2 and BioCaves2.onTileRemoved then
            BioCaves2.onTileRemoved(x, y, depth)
        end
    end

    -- Megabeast trigger on deep rock excavation
    if tile == Tiles.DEEP_ROCK or tile == Tiles.UNDERGROUND_ROCK then
        local megaOk, Mega = pcall(require, 'src.creatures.megabeasts')
        if megaOk then Mega.onTileMined() end
    end

    -- Structural integrity check after any excavation underground
    -- All ops that remove solid rock need structural reevaluation
    if depth > 0 and (op.result == Tiles.UNDERGROUND_FLOOR or opId == 'dig_shaft'
                      or opId == 'dig_stair_down' or opId == 'dig_stair_up'
                      or opId == 'dig_channel' or opId == 'carve_ramp') then
        local sOk, Structural = pcall(require, 'src.world.structural')
        if sOk and Structural.onTileExcavated then
            Structural.onTileExcavated(x, y, depth)
        end
    end

    -- Cavern breach check — tile-type based, not depth-gated
    -- Fires when excavating biological tiles at any depth
    if depth > 0 then
        local origProps = Tiles.get(tile)
        if origProps and origProps.biological then
            local cvOk, Caverns = pcall(require, 'src.world.caverns')
            if cvOk and Caverns.isCavernDepth and Caverns.isCavernDepth(depth) then
                if not Caverns.isBreached(depth) then
                    Caverns.onBreach(depth)
                end
            else
                local bcOk, BioCaves = pcall(require, 'src.world.biocaves')
                if bcOk and BioCaves.onExcavation then
                    BioCaves.onExcavation(x, y, depth)
                end
            end
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Permafrost thaw step — periodic scan of tracked tiles
---------------------------------------------------------------------------

function Terraform.step(dt)
    thawTimer = thawTimer + dt
    if thawTimer < THAW_CHECK_INTERVAL then return end
    thawTimer = 0

    local World = require('src.world.tilemap')
    local w = World.width()
    local h = World.height()
    local size = w * h

    -- Scan tiles with existing thaw progress
    local toRemove = {}
    for tk, ticks in pairs(thawProgress) do
        local depth = math.floor(tk / 100000000)
        local idx = tk - depth * 100000000
        local tData = World.rawTileData(depth)
        local tTemp = World.rawTempData(depth)
        local tile = tData[idx]
        if tile ~= Tiles.PERMAFROST then
            toRemove[#toRemove + 1] = tk
        else
            local temp = tTemp[idx]
            if temp > THAW_THRESHOLD then
                ticks = ticks + math.floor(THAW_CHECK_INTERVAL * 20)
                if ticks >= THAW_TICKS_REQUIRED then
                    local x = (idx - 1) % w
                    local y = math.floor((idx - 1) / w)
                    World.setTile(x, y, Tiles.DIRT, depth)
                    toRemove[#toRemove + 1] = tk
                else
                    thawProgress[tk] = ticks
                end
            else
                ticks = math.max(0, ticks - math.floor(THAW_CHECK_INTERVAL * 10))
                if ticks == 0 then
                    toRemove[#toRemove + 1] = tk
                else
                    thawProgress[tk] = ticks
                end
            end
        end
    end
    for _, tk in ipairs(toRemove) do
        thawProgress[tk] = nil
    end

    -- Scan for new permafrost tiles above threshold near heated rooms
    for depth, _ in World.allLayers() do
        local tData = World.rawTileData(depth)
        local tTemp = World.rawTempData(depth)
        local rData = World.rawRoomData(depth)
        for idx = 1, size do
            if tData[idx] == Tiles.PERMAFROST and rData[idx] > 0 then
                local tk = thawKey(depth, idx)
                if tTemp[idx] > THAW_THRESHOLD and not thawProgress[tk] then
                    thawProgress[tk] = 1
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Underground tile queries
---------------------------------------------------------------------------

function Terraform.isUnderground(tileType)
    return tileType == Tiles.UNDERGROUND_FLOOR
        or tileType == Tiles.UNDERGROUND_ROCK
        or tileType == Tiles.DEEP_ROCK
        or tileType == Tiles.SHAFT_ENTRANCE
        or tileType == Tiles.STAIR_DOWN
        or tileType == Tiles.STAIR_UP
        or tileType == Tiles.STAIR_BOTH
        or tileType == Tiles.CHANNEL
        or tileType == Tiles.RAMP_UP
end

function Terraform.isUndergroundAt(x, y, depth)
    if depth and depth > 0 then return true end  -- any tile on depth > 0 is underground
    local World = require('src.world.tilemap')
    return Terraform.isUnderground(World.getTile(x, y, depth))
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Terraform.getState()
    return {
        thawProgress = thawProgress,
    }
end

function Terraform.loadState(state)
    if not state then return end
    thawProgress = state.thawProgress or {}
end

return Terraform
