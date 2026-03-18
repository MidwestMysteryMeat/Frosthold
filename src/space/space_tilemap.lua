-- space_tilemap.lua — Chunked tilemap for space navigation
-- Generates 32x32 tile chunks procedurally from world seed.
-- Exposes same API as World (tilemap.lua) so existing systems work.
-- Planet colony maps are unaffected — they use the fixed tilemap as before.

local GameState = require('src.game_state')

local SpaceTilemap = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local CHUNK_SIZE = 32
local VOID_TILE  = 0
local ASTEROID_TILE = 99
local DEBRIS_TILE   = 100

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local chunks = {}
local shipChunkX = 0
local shipChunkY = 0
local worldSeed  = 0

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function chunkKey(cx, cy)
    return cx .. ',' .. cy
end

local function parseChunkKey(key)
    local cx, cy = key:match('([^,]+),([^,]+)')
    return tonumber(cx), tonumber(cy)
end

-- Deterministic hash for chunk seed (no global RNG side effects)
local function chunkSeed(cx, cy)
    local s = worldSeed
    s = ((s + cx * 374761393) % 2147483647)
    s = ((s + cy * 668265263) % 2147483647)
    s = ((s * 1103515245 + 12345) % 2147483647)
    return math.abs(s)
end

-- Convert world tile (x, y) to chunk coords + local offset
local function toChunkLocal(x, y)
    local cx = math.floor(x / CHUNK_SIZE)
    local cy = math.floor(y / CHUNK_SIZE)
    local lx = x - cx * CHUNK_SIZE
    local ly = y - cy * CHUNK_SIZE
    return cx, cy, lx, ly
end

local function localIdx(lx, ly)
    return ly * CHUNK_SIZE + lx + 1
end

---------------------------------------------------------------------------
-- Chunk generation
---------------------------------------------------------------------------

local function generateChunk(cx, cy)
    local key = chunkKey(cx, cy)
    if chunks[key] then return chunks[key] end

    local seed = chunkSeed(cx, cy)

    -- Deterministic per-tile hash (does NOT touch math.randomseed)
    local function tileHash(i)
        local s = seed + i * 2654435761
        s = s % 2147483647
        s = ((s * 1103515245) + 12345) % 2147483647
        return (s % 10000) / 10000
    end

    local tiles = {}
    local size = CHUNK_SIZE * CHUNK_SIZE

    for i = 1, size do
        tiles[i] = VOID_TILE
    end

    -- Apply chunk diffs (player modifications like mined asteroids)
    local diffs = GameState.spaceChunkDiffs[key]
    if diffs then
        for i, tile in pairs(diffs) do
            tiles[i] = tile
        end
    end

    -- Procedural content: asteroid clusters, debris patches
    local dist = math.sqrt(cx * cx + cy * cy)
    local asteroidChance = 0.03 + math.min(0.08, dist * 0.002)
    local debrisChance   = 0.01

    for i = 1, size do
        if not diffs or not diffs[i] then
            local r = tileHash(i)
            if r < asteroidChance then
                tiles[i] = ASTEROID_TILE
            elseif r < asteroidChance + debrisChance then
                tiles[i] = DEBRIS_TILE
            end
        end
    end

    local chunk = { tiles = tiles, generated = true }
    chunks[key] = chunk
    return chunk
end

---------------------------------------------------------------------------
-- Public API (mirrors tilemap.lua)
---------------------------------------------------------------------------

function SpaceTilemap.init(seed)
    chunks = {}
    worldSeed = seed or GameState.worldSeedNumeric or 12345
    shipChunkX = 0
    shipChunkY = 0
end

function SpaceTilemap.getTile(x, y)
    local cx, cy, lx, ly = toChunkLocal(x, y)
    local chunk = generateChunk(cx, cy)
    return chunk.tiles[localIdx(lx, ly)] or VOID_TILE
end

function SpaceTilemap.setTile(x, y, tileType)
    local cx, cy, lx, ly = toChunkLocal(x, y)
    local chunk = generateChunk(cx, cy)
    local idx = localIdx(lx, ly)
    chunk.tiles[idx] = tileType

    local key = chunkKey(cx, cy)
    if not GameState.spaceChunkDiffs[key] then
        GameState.spaceChunkDiffs[key] = {}
    end
    GameState.spaceChunkDiffs[key][idx] = tileType
end

function SpaceTilemap.getTemp(x, y)
    return -270
end

function SpaceTilemap.getRoom(x, y)
    return nil
end

function SpaceTilemap.inBounds(x, y)
    return true
end

function SpaceTilemap.getWidth()
    return 10000
end

function SpaceTilemap.getHeight()
    return 10000
end

function SpaceTilemap.setShipChunk(cx, cy)
    shipChunkX = cx
    shipChunkY = cy
end

function SpaceTilemap.unloadDistantChunks(keepRadius)
    keepRadius = keepRadius or 3
    local toRemove = {}
    for key, _ in pairs(chunks) do
        local cx, cy = parseChunkKey(key)
        if math.abs(cx - shipChunkX) > keepRadius or math.abs(cy - shipChunkY) > keepRadius then
            toRemove[#toRemove + 1] = key
        end
    end
    for _, key in ipairs(toRemove) do
        chunks[key] = nil
    end
end

function SpaceTilemap.getState()
    return {
        worldSeed = worldSeed,
        shipChunkX = shipChunkX,
        shipChunkY = shipChunkY,
    }
end

function SpaceTilemap.loadState(state)
    if not state then return end
    worldSeed = state.worldSeed or 0
    shipChunkX = state.shipChunkX or 0
    shipChunkY = state.shipChunkY or 0
end

SpaceTilemap.CHUNK_SIZE = CHUNK_SIZE
SpaceTilemap.VOID_TILE = VOID_TILE
SpaceTilemap.ASTEROID_TILE = ASTEROID_TILE
SpaceTilemap.DEBRIS_TILE = DEBRIS_TILE

return SpaceTilemap
