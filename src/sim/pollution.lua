-- pollution.lua — Per-tile industrial pollution simulation
-- Machines produce pollution when active. Pollution diffuses slowly to
-- neighbors (much slower than thermal). High pollution attracts creatures
-- and degrades terrain.
--
-- Pollution value per tile: 0 (clean) to 100 (severely polluted).
-- >50 multiplies creature spawn rate.
-- >80 degrades TUNDRA/SNOW/PERMAFROST → DEBRIS over time.

local Tiles     = require('src.world.tiles')
local Tilemap   = require('src.world.tilemap')
local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Pollution = {}

---------------------------------------------------------------------------
-- Pollution emission rates per machine type (units/s while active)
---------------------------------------------------------------------------

local EMISSION_RATES = {
    smelter    = 0.8,
    forge      = 1.2,
    refinery   = 1.5,
    drug_lab   = 0.6,
    kiln       = 0.4,
    smokehouse = 0.3,
    melter     = 0.2,
}

Pollution.EMISSION_RATES = EMISSION_RATES

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local DIFFUSION_RATE     = 0.02   -- per tick (much slower than thermal)
local DECAY_RATE         = 0.005  -- natural decay per tick per tile
local CREATURE_THRESHOLD = 50     -- pollution above this attracts creatures
local DEGRADE_THRESHOLD  = 80     -- pollution above this degrades terrain
local DEGRADE_RATE       = 0.001  -- chance per tick per tile to degrade
local MAX_POLLUTION      = 100

-- Tiles that can degrade into DEBRIS
local DEGRADABLE = {
    [Tiles.SNOW]       = true,
    [Tiles.PERMAFROST] = true,
    [Tiles.DIRT]       = true,
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local pollData = {}   -- flat array, same indexing as tilemap (y * w + x + 1)
local newPollBuf = {} -- reusable buffer for diffusion (avoid per-tick allocation)
local mapW, mapH = 0, 0
local scrubbers  = {}  -- { [entityId] = { x, y, radius, rate } }

-- Diffusion neighbor offsets (hoisted from inner loop)
local DIFF_DIRS = { {-1,0}, {1,0}, {0,-1}, {0,1} }

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Pollution.init()
    mapW = Tilemap.width()
    mapH = Tilemap.height()
    local size = mapW * mapH
    pollData = {}
    newPollBuf = {}
    for i = 1, size do
        pollData[i] = 0
        newPollBuf[i] = 0
    end
    scrubbers = {}
end

---------------------------------------------------------------------------
-- Scrubber registration (from pollution_control research)
---------------------------------------------------------------------------

function Pollution.addScrubber(entityId, x, y, radius, rate)
    scrubbers[entityId] = { x = x, y = y, radius = radius or 5, rate = rate or 2.0 }
end

function Pollution.removeScrubber(entityId)
    scrubbers[entityId] = nil
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Pollution.step(dt)
    local tData = Tilemap.rawTileData()

    -- Phase 1: Emit pollution from active industrial machines
    for id, comps in ECS.query('pos', 'machine') do
        local machine = comps.machine
        if machine.active then
            local rate = EMISSION_RATES[machine.type]
            if rate then
                local pos = comps.pos
                if Tilemap.inBounds(pos.x, pos.y) then
                    local idx = pos.y * mapW + pos.x + 1
                    pollData[idx] = math.min(MAX_POLLUTION, pollData[idx] + rate * dt)
                end
            end
        end
    end

    -- Phase 2: Scrubbers reduce pollution in their radius
    for _, scrub in pairs(scrubbers) do
        local sx, sy = scrub.x, scrub.y
        local r = scrub.radius
        local reduction = scrub.rate * dt
        for dy = -r, r do
            for dx = -r, r do
                local tx, ty = sx + dx, sy + dy
                if Tilemap.inBounds(tx, ty) then
                    if dx * dx + dy * dy <= r * r then
                        local idx = ty * mapW + tx + 1
                        pollData[idx] = math.max(0, pollData[idx] - reduction)
                    end
                end
            end
        end
    end

    -- Phase 3: Diffusion — average with neighbors (Jacobi iteration)
    local decayTick = DECAY_RATE * dt * 20
    local diffTick = DIFFUSION_RATE * dt * 20
    for y = 0, mapH - 1 do
        for x = 0, mapW - 1 do
            local idx = y * mapW + x + 1
            local cur = pollData[idx]
            local tile = tData[idx]

            -- Walls block pollution spread
            if Tiles.isSolid(tile) then
                newPollBuf[idx] = math.max(0, cur - decayTick)
                goto next_tile
            end

            local sum = 0
            local count = 0
            for i = 1, 4 do
                local d = DIFF_DIRS[i]
                local nx, ny = x + d[1], y + d[2]
                if nx >= 0 and nx < mapW and ny >= 0 and ny < mapH then
                    local ni = ny * mapW + nx + 1
                    if not Tiles.isSolid(tData[ni]) then
                        sum = sum + pollData[ni]
                        count = count + 1
                    end
                end
            end

            local diffused = cur
            if count > 0 then
                diffused = cur + (sum / count - cur) * diffTick
            end

            diffused = diffused - decayTick
            newPollBuf[idx] = math.max(0, math.min(MAX_POLLUTION, diffused))

            ::next_tile::
        end
    end

    -- Write back from pooled buffer
    local size = mapW * mapH
    for i = 1, size do
        pollData[i] = newPollBuf[i]
    end

    -- Phase 4: Terrain degradation at high pollution
    for y = 0, mapH - 1 do
        for x = 0, mapW - 1 do
            local idx = y * mapW + x + 1
            if pollData[idx] > DEGRADE_THRESHOLD then
                local tile = tData[idx]
                if DEGRADABLE[tile] then
                    if math.random() < DEGRADE_RATE * dt * 20 then
                        Tilemap.setTile(x, y, Tiles.DEBRIS)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Pollution.get(x, y)
    if not Tilemap.inBounds(x, y) then return 0 end
    return pollData[y * mapW + x + 1]
end

function Pollution.set(x, y, value)
    if not Tilemap.inBounds(x, y) then return end
    pollData[y * mapW + x + 1] = math.max(0, math.min(MAX_POLLUTION, value))
end

function Pollution.rawData()
    return pollData
end

-- Creature spawn multiplier based on max pollution in the map region
-- Returns 1.0 (no effect) to 3.0 (heavily polluted)
function Pollution.getCreatureSpawnMultiplier()
    local maxPoll = 0
    for i = 1, mapW * mapH do
        if pollData[i] > maxPoll then
            maxPoll = pollData[i]
        end
    end
    if maxPoll <= CREATURE_THRESHOLD then return 1.0 end
    -- Linear scale from 1.0 at threshold to 3.0 at 100
    local t = (maxPoll - CREATURE_THRESHOLD) / (MAX_POLLUTION - CREATURE_THRESHOLD)
    return 1.0 + t * 2.0
end

-- Local spawn multiplier at a specific tile
function Pollution.getTileSpawnMultiplier(x, y)
    local p = Pollution.get(x, y)
    if p <= CREATURE_THRESHOLD then return 1.0 end
    local t = (p - CREATURE_THRESHOLD) / (MAX_POLLUTION - CREATURE_THRESHOLD)
    return 1.0 + t * 2.0
end

-- Average pollution across the whole map
function Pollution.getAveragePollution()
    local sum = 0
    local count = mapW * mapH
    if count == 0 then return 0 end
    for i = 1, count do
        sum = sum + pollData[i]
    end
    return sum / count
end

-- Count tiles above a pollution threshold
function Pollution.countAbove(threshold)
    local n = 0
    for i = 1, mapW * mapH do
        if pollData[i] > threshold then n = n + 1 end
    end
    return n
end

-- Peak pollution value on the map
function Pollution.getPeak()
    local peak = 0
    for i = 1, mapW * mapH do
        if pollData[i] > peak then peak = pollData[i] end
    end
    return peak
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Pollution.getState()
    return {
        pollData  = pollData,
        scrubbers = scrubbers,
        mapW      = mapW,
        mapH      = mapH,
    }
end

function Pollution.loadState(saved)
    if not saved then return end
    mapW      = saved.mapW or 0
    mapH      = saved.mapH or 0
    scrubbers = saved.scrubbers or {}
    pollData  = saved.pollData or {}
    -- Ensure pollData is the right size
    local size = mapW * mapH
    for i = #pollData + 1, size do
        pollData[i] = 0
    end
end

return Pollution
