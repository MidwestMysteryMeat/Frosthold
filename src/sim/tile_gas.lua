-- tile_gas.lua — Per-tile gas simulation (DF-style)
-- Each tile stores a gas concentration 0-7 (0=clean air, 7=fully toxic/depleted).
-- Gas types: CO2 (heavy, sinks), toxic (from spores/vents, spreads evenly),
--            smoke (rises), spore (from biocaves, spreads slowly).
-- Gas diffuses horizontally to all non-solid neighbors and vertically through
-- stairs, channels, shafts, and ramps. Heavy gases sink, light gases rise.
-- Replaces room-level atmosphere as the source of truth; atmosphere.lua derives
-- room O2/CO2 from tile gas averages for backward-compatible effect triggers.

local Tiles = require('src.world.tiles')

local TileGas = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local MAX_GAS          = 7
local MAX_SPREAD       = 150   -- max tile updates per sim tick
local DIFFUSE_INTERVAL = 2     -- ticks between diffusion passes (0.1s at 20Hz)
local VENT_INTERVAL    = 10    -- ticks between ventilation processing
local DIRS             = { {-1,0}, {1,0}, {0,-1}, {0,1} }

-- Gas types and their behavior
-- Each tile's gas[] value is a composite: type * 8 + level
-- For simplicity, we track a single dominant gas type + concentration per tile.
-- Type 0 = CO2 (heavy, sinks), Type 1 = toxic (neutral), Type 2 = smoke (rises),
-- Type 3 = spore (slow spread)
TileGas.TYPE_CO2   = 0
TileGas.TYPE_TOXIC = 1
TileGas.TYPE_SMOKE = 2
TileGas.TYPE_SPORE = 3

-- Gas weights: negative = sinks, positive = rises, 0 = neutral
local GAS_WEIGHT = {
    [0] = -2,  -- CO2 sinks
    [1] =  0,  -- toxic is neutral
    [2] =  1,  -- smoke rises
    [3] =  0,  -- spore is neutral but slow
}

-- Diffusion rate per gas type (0.0-1.0, fraction of difference transferred)
local GAS_DIFFUSION = {
    [0] = 0.3,   -- CO2 spreads moderately
    [1] = 0.25,  -- toxic spreads moderately
    [2] = 0.4,   -- smoke spreads fast
    [3] = 0.1,   -- spore spreads slow
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

-- Per-tile gas storage: gasData[depth][idx] = { type, level }
-- We use the tilemap gas[] array for level (0-7) and a parallel type array.
-- Type array: gasType[tileKey] = gas type id (only for tiles with gas > 0)
local gasType = {}  -- { [depth*100M+idx] = type_id }

-- Dirty tiles needing processing
local gasDirty = {}
local gasDirtyCount = 0

-- Timers
local diffuseCounter = 0
local ventCounter = 0

-- Registered emitters (machines, generators, vents, biocaves)
-- { [entityOrKey] = { x, y, depth, type, rate } }
local emitters = {}

-- Registered ventilation (air intakes, exhausts, purifiers)
local ventilators = {}

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

local function markGasDirty(depth, idx)
    local k = tileKey(depth, idx)
    if not gasDirty[k] then
        gasDirty[k] = true
        gasDirtyCount = gasDirtyCount + 1
    end
end

local function clearGasDirty(k)
    if gasDirty[k] then
        gasDirty[k] = nil
        gasDirtyCount = gasDirtyCount - 1
    end
end

local function getGasPermeability(World, x, y, depth, tileType)
    if World.isDoorLocked and World.isDoorLocked(x, y) then
        return 0
    end
    return Tiles.getGasPermeability(tileType)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function TileGas.init()
    gasType = {}
    gasDirty = {}
    gasDirtyCount = 0
    diffuseCounter = 0
    ventCounter = 0
    emitters = {}
    ventilators = {}
end

---------------------------------------------------------------------------
-- Public: inject gas at a tile
---------------------------------------------------------------------------

function TileGas.addGas(x, y, amount, gasTypeId, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    depth = depth or 0
    gasTypeId = gasTypeId or TileGas.TYPE_CO2
    if not World.inBounds(x, y) then return end

    local current = World.getGas(x, y, depth)
    local newLevel = math.min(MAX_GAS, current + amount)
    if newLevel > current then
        World.setGas(x, y, newLevel, depth)
        local w = World.width()
        local idx = y * w + x + 1
        local k = tileKey(depth, idx)
        gasType[k] = gasTypeId
        markGasDirty(depth, idx)
    end
end

--- Remove gas from a tile (ventilation, purifiers)
function TileGas.removeGas(x, y, amount, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end
    depth = depth or 0

    local current = World.getGas(x, y, depth)
    local removed = math.min(current, amount)
    if removed > 0 then
        World.setGas(x, y, current - removed, depth)
        if current - removed <= 0 then
            local w = World.width()
            gasType[tileKey(depth, y * w + x + 1)] = nil
        end
    end
    return removed
end

---------------------------------------------------------------------------
-- Emitter / ventilator registration
---------------------------------------------------------------------------

function TileGas.addEmitter(id, x, y, depth, gasTypeId, rate)
    emitters[id] = { x = x, y = y, depth = depth or 0, type = gasTypeId or TileGas.TYPE_CO2, rate = rate or 1 }
end

function TileGas.removeEmitter(id)
    emitters[id] = nil
end

function TileGas.addVentilator(id, x, y, depth, ventType, rate)
    ventilators[id] = { x = x, y = y, depth = depth or 0, type = ventType or 'intake', rate = rate or 1 }
end

function TileGas.removeVentilator(id)
    ventilators[id] = nil
end

---------------------------------------------------------------------------
-- Simulation step — called each sim tick (20Hz)
---------------------------------------------------------------------------

function TileGas.step(dt)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end

    local w = World.width()
    local h = World.height()

    -- Process emitters: inject gas at source tiles
    for _, em in pairs(emitters) do
        if math.random() < em.rate * dt then
            TileGas.addGas(em.x, em.y, 1, em.type, em.depth)
        end
    end

    -- Diffusion pass (throttled)
    diffuseCounter = diffuseCounter + 1
    if diffuseCounter >= DIFFUSE_INTERVAL then
        diffuseCounter = 0
        TileGas.diffuse(World, w, h)
    end

    -- Ventilation pass (throttled)
    ventCounter = ventCounter + 1
    if ventCounter >= VENT_INTERVAL then
        ventCounter = 0
        TileGas.processVentilation(World, w)
    end

    -- Outdoor dissipation: surface tiles with gas lose 1 level periodically
    -- (wind clears gas on surface)
    do
        local surfaceGas = World.rawGasData(0)
        if surfaceGas then
            local surfaceTiles = World.rawTileData(0)
            local surfaceRooms = World.rawRoomData and World.rawRoomData(0)
            local size = w * h
            for idx = 1, size do
                local gl = surfaceGas[idx] or 0
                if gl > 0 then
                    local tile = surfaceTiles[idx]
                    -- Open sky dissipates gas (wind clears surface gas).
                    -- Enclosure, not tile material, decides this: a built
                    -- floor out in the open used to trap gas forever, so a
                    -- campfire or generator on a metal pad slowly suffocated
                    -- anyone nearby. Tiles inside a room still need a vent.
                    local openSky = (surfaceRooms and (surfaceRooms[idx] or 0) == 0)
                    if openSky
                        or tile == Tiles.SNOW or tile == Tiles.PERMAFROST
                        or tile == Tiles.DIRT or tile == Tiles.DEBRIS
                        or tile == Tiles.TUNDRA_MARSH or tile == Tiles.ASH_GROUND
                        or tile == Tiles.VOLCANIC_FLOOR or tile == Tiles.CAVE_ENTRANCE
                        or tile == Tiles.FROZEN_LAKE or tile == Tiles.FROZEN_SEA then
                        if math.random() < 0.15 then
                            surfaceGas[idx] = gl - 1
                            if surfaceGas[idx] <= 0 then
                                local k = tileKey(0, idx)
                                gasType[k] = nil
                                clearGasDirty(k)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Clean up empty entries
    local toClean = {}
    for k in pairs(gasDirty) do
        local depth, idx = decodeTileKey(k)
        local gasData = World.rawGasData(depth)
        if gasData and (gasData[idx] or 0) <= 0 then
            toClean[#toClean + 1] = k
            gasType[k] = nil
        end
    end
    for _, k in ipairs(toClean) do
        clearGasDirty(k)
    end
end

---------------------------------------------------------------------------
-- Gas diffusion
---------------------------------------------------------------------------

function TileGas.diffuse(World, w, h)
    local moves = {}
    local processed = 0

    for k in pairs(gasDirty) do
        if processed >= MAX_SPREAD then break end
        local depth, idx = decodeTileKey(k)
        local gasData = World.rawGasData(depth)
        if not gasData then goto diff_continue end

        local level = gasData[idx] or 0
        if level <= 0 then goto diff_continue end

        local gType = gasType[k] or TileGas.TYPE_CO2
        local diffRate = GAS_DIFFUSION[gType] or 0.25
        local weight = GAS_WEIGHT[gType] or 0
        local tileData = World.rawTileData(depth)

        local x = (idx - 1) % w
        local y = math.floor((idx - 1) / w)

        -- Horizontal diffusion to 4 cardinal neighbors
        for _, d in ipairs(DIRS) do
            local nx, ny = x + d[1], y + d[2]
            if nx >= 0 and nx < w and ny >= 0 and ny < h then
                local ni = ny * w + nx + 1
                local nTile = tileData[ni]
                if not Tiles.isSolid(nTile) then
                    local perm = math.min(
                        getGasPermeability(World, x, y, depth, tileData[idx]),
                        getGasPermeability(World, nx, ny, depth, nTile)
                    )
                    if perm <= 0 then goto next_dir end
                    local nLevel = gasData[ni] or 0
                    if level > nLevel + 1 then
                        local transfer = math.max(1, math.floor((level - nLevel) * diffRate))
                        transfer = math.floor(transfer * perm + 0.5)
                        if transfer < 1 then goto next_dir end
                        moves[#moves + 1] = {
                            depth = depth, fromIdx = idx, toIdx = ni,
                            amount = transfer, gType = gType,
                        }
                        processed = processed + 1
                    end
                end
                ::next_dir::
            end
        end

        -- Vertical diffusion based on gas weight
        local tile = tileData[idx]

        -- Heavy gas (CO2) sinks through downward connections
        if weight < 0 and Tiles.connectsDown(tile) then
            local belowGas = World.rawGasData(depth + 1)
            local belowTiles = belowGas and World.rawTileData(depth + 1)
            if belowGas and belowTiles then
                local belowTile = belowTiles[idx]
                if not Tiles.isSolid(belowTile) then
                    local belowLevel = belowGas[idx] or 0
                    if level > belowLevel then
                        local transfer = math.max(1, math.floor((level - belowLevel) * diffRate * 1.5))
                        moves[#moves + 1] = {
                            depth = depth, fromIdx = idx,
                            toDepth = depth + 1, toIdx = idx,
                            amount = transfer, gType = gType, vertical = true,
                        }
                        processed = processed + 1
                    end
                end
            end
        end

        -- Light gas (smoke) rises through upward connections
        if weight > 0 and Tiles.connectsUp(tile) and depth > 0 then
            local aboveGas = World.rawGasData(depth - 1)
            local aboveTiles = aboveGas and World.rawTileData(depth - 1)
            if aboveGas and aboveTiles then
                local aboveTile = aboveTiles[idx]
                if not Tiles.isSolid(aboveTile) then
                    local aboveLevel = aboveGas[idx] or 0
                    if level > aboveLevel then
                        local transfer = math.max(1, math.floor((level - aboveLevel) * diffRate * 1.5))
                        moves[#moves + 1] = {
                            depth = depth, fromIdx = idx,
                            toDepth = depth - 1, toIdx = idx,
                            amount = transfer, gType = gType, vertical = true,
                        }
                        processed = processed + 1
                    end
                end
            end
        end

        -- Neutral gas diffuses both ways through vertical connections
        if weight == 0 then
            if Tiles.connectsDown(tile) then
                local belowGas = World.rawGasData(depth + 1)
                local belowTilesN = belowGas and World.rawTileData(depth + 1)
                if belowGas and belowTilesN and not Tiles.isSolid(belowTilesN[idx]) then
                    local belowLevel = belowGas[idx] or 0
                    if level > belowLevel + 1 then
                        local transfer = math.max(1, math.floor((level - belowLevel) * diffRate * 0.5))
                        moves[#moves + 1] = {
                            depth = depth, fromIdx = idx,
                            toDepth = depth + 1, toIdx = idx,
                            amount = transfer, gType = gType, vertical = true,
                        }
                        processed = processed + 1
                    end
                end
            end
            if Tiles.connectsUp(tile) and depth > 0 then
                local aboveGas = World.rawGasData(depth - 1)
                local aboveTilesN = aboveGas and World.rawTileData(depth - 1)
                if aboveGas and aboveTilesN and not Tiles.isSolid(aboveTilesN[idx]) then
                    local aboveLevel = aboveGas[idx] or 0
                    if level > aboveLevel + 1 then
                        local transfer = math.max(1, math.floor((level - aboveLevel) * diffRate * 0.5))
                        moves[#moves + 1] = {
                            depth = depth, fromIdx = idx,
                            toDepth = depth - 1, toIdx = idx,
                            amount = transfer, gType = gType, vertical = true,
                        }
                        processed = processed + 1
                    end
                end
            end
        end

        ::diff_continue::
    end

    -- Apply moves
    for _, move in ipairs(moves) do
        local fromGas = World.rawGasData(move.depth)
        if not fromGas then goto apply_continue end

        local fromLevel = fromGas[move.fromIdx] or 0
        if fromLevel <= 0 then goto apply_continue end

        if move.vertical then
            local toGas = World.rawGasData(move.toDepth)
            if toGas then
                local toLevel = toGas[move.toIdx] or 0
                local transfer = math.min(move.amount, fromLevel, MAX_GAS - toLevel)
                if transfer > 0 then
                    fromGas[move.fromIdx] = fromLevel - transfer
                    toGas[move.toIdx]     = toLevel + transfer
                    local toKey = tileKey(move.toDepth, move.toIdx)
                    gasType[toKey] = move.gType
                    markGasDirty(move.toDepth, move.toIdx)
                end
            end
        else
            local toLevel = fromGas[move.toIdx] or 0
            local transfer = math.min(move.amount, fromLevel, MAX_GAS - toLevel)
            if transfer > 0 and fromLevel > toLevel then
                fromGas[move.fromIdx] = fromLevel - transfer
                fromGas[move.toIdx]   = toLevel + transfer
                local toKey = tileKey(move.depth, move.toIdx)
                gasType[toKey] = move.gType
                markGasDirty(move.depth, move.toIdx)
            end
        end

        ::apply_continue::
    end
end

---------------------------------------------------------------------------
-- Ventilation processing
---------------------------------------------------------------------------

function TileGas.processVentilation(World, w)
    for _, vent in pairs(ventilators) do
        local depth = vent.depth or 0
        local gasData = World.rawGasData(depth)
        if not gasData then goto vent_next end

        local idx = vent.y * w + vent.x + 1
        local level = gasData[idx] or 0

        if vent.type == 'intake' then
            -- Air intake: remove gas from tile (pulls fresh air in)
            if level > 0 then
                local remove = math.min(level, vent.rate)
                gasData[idx] = level - remove
                if gasData[idx] <= 0 then
                    gasType[tileKey(depth, idx)] = nil
                end
            end
        elseif vent.type == 'exhaust' then
            -- Exhaust: push gas out (removes from tile and neighbors)
            if level > 0 then
                gasData[idx] = math.max(0, level - vent.rate)
            end
            -- Also reduce gas in 4 neighbors
            local x = (idx - 1) % w
            local y = math.floor((idx - 1) / w)
            local dirs = { {-1,0}, {1,0}, {0,-1}, {0,1} }
            for _, d in ipairs(dirs) do
                local nx, ny = x + d[1], y + d[2]
                if World.inBounds(nx, ny) then
                    local ni = ny * w + nx + 1
                    local nl = gasData[ni] or 0
                    if nl > 0 then
                        gasData[ni] = math.max(0, nl - math.ceil(vent.rate * 0.5))
                    end
                end
            end
        elseif vent.type == 'purifier' then
            -- Purifier: converts gas to clean air (powered check done by caller)
            if level > 0 then
                local convert = math.min(level, vent.rate)
                gasData[idx] = level - convert
                if gasData[idx] <= 0 then
                    gasType[tileKey(depth, idx)] = nil
                end
            end
        end

        ::vent_next::
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function TileGas.getGasAt(x, y, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0, TileGas.TYPE_CO2 end
    local level = World.getGas(x, y, depth or 0)
    local w = World.width()
    local idx = y * w + x + 1
    local gType = gasType[tileKey(depth or 0, idx)] or TileGas.TYPE_CO2
    return level, gType
end

function TileGas.getGasLevel(x, y, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end
    return World.getGas(x, y, depth or 0)
end

function TileGas.getGasType(x, y, depth)
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return TileGas.TYPE_CO2 end
    local w = World.width()
    local idx = y * w + x + 1
    return gasType[tileKey(depth or 0, idx)] or TileGas.TYPE_CO2
end

function TileGas.getTileO2(x, y, depth)
    local level = TileGas.getGasLevel(x, y, depth)
    return math.max(0, math.min(100, 100 - (level / MAX_GAS * 100)))
end

function TileGas.getTileCO2(x, y, depth)
    local level, gType = TileGas.getGasAt(x, y, depth)
    if gType ~= TileGas.TYPE_CO2 then return 0 end
    return math.max(0, math.min(100, level / MAX_GAS * 100))
end

--- Get room O2 level (0-100) derived from tile gas data.
--- Gas level 0 = 100% O2, gas level 7 = 0% O2.
function TileGas.getRoomO2(roomId)
    local tOk, Thermal = pcall(require, 'src.sim.thermal')
    if not tOk then return 100 end
    local rooms = Thermal.getRooms()
    local room = rooms and rooms[roomId]
    if not room or not room.tiles or #room.tiles == 0 then return 100 end

    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 100 end
    local gasData = World.rawGasData(room.depth or 0)
    if not gasData then return 100 end

    local totalGas = 0
    for _, idx in ipairs(room.tiles) do
        totalGas = totalGas + (gasData[idx] or 0)
    end
    local avgGas = totalGas / #room.tiles
    -- Map gas 0-7 to O2 100-0
    return math.max(0, math.min(100, 100 - (avgGas / MAX_GAS * 100)))
end

--- Get room CO2 level (0-100) derived from tile gas data.
function TileGas.getRoomCO2(roomId)
    local tOk, Thermal = pcall(require, 'src.sim.thermal')
    if not tOk then return 0 end
    local rooms = Thermal.getRooms()
    local room = rooms and rooms[roomId]
    if not room or not room.tiles or #room.tiles == 0 then return 0 end

    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 0 end
    local gasData = World.rawGasData(room.depth or 0)
    if not gasData then return 0 end

    local totalGas = 0
    local co2Count = 0
    for _, idx in ipairs(room.tiles) do
        local gl = gasData[idx] or 0
        if gl > 0 then
            local k = tileKey(room.depth or 0, idx)
            if (gasType[k] or TileGas.TYPE_CO2) == TileGas.TYPE_CO2 then
                totalGas = totalGas + gl
                co2Count = co2Count + 1
            end
        end
    end
    if co2Count == 0 then return 0 end
    local avgCO2 = totalGas / #room.tiles
    return math.max(0, math.min(100, avgCO2 / MAX_GAS * 100))
end

--- Is the air at this tile breathable?
function TileGas.isBreathable(x, y, depth)
    local level = TileGas.getGasLevel(x, y, depth)
    return level < 5  -- gas level 5+ is dangerous
end

--- Is the air at this tile toxic?
function TileGas.isToxic(x, y, depth)
    local level, gType = TileGas.getGasAt(x, y, depth)
    return level >= 3 and (gType == TileGas.TYPE_TOXIC or gType == TileGas.TYPE_SPORE)
end

function TileGas.getDirtyCount()
    return gasDirtyCount
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function TileGas.getState()
    return {
        gasType = gasType,
        emitters = emitters,
        ventilators = ventilators,
    }
end

function TileGas.loadState(state)
    if not state then
        TileGas.init()
        return
    end
    gasType     = state.gasType or {}
    emitters    = state.emitters or {}
    ventilators = state.ventilators or {}
    diffuseCounter = 0
    ventCounter = 0

    -- Rebuild dirty set from tilemap gas data
    gasDirty = {}
    gasDirtyCount = 0
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    local w = World.width()
    local h = World.height()
    local size = w * h
    for depth, _ in World.allLayers() do
        local gasData = World.rawGasData(depth)
        if gasData then
            for idx = 1, size do
                if (gasData[idx] or 0) > 0 then
                    markGasDirty(depth, idx)
                end
            end
        end
    end
end

return TileGas
