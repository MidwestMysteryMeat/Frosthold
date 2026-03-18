-- director.lua — Alien: Isolation-style AI Director (dual-brain system)
--
-- Every AI entity has two "brains":
--   Brain 1 (Sensory): Vision cone + LOS — what the entity can directly see.
--   Brain 2 (Director): Ambient awareness — nudges entities toward areas of
--                        interest without revealing exact positions.
--
-- The Director maintains a coarse interest grid. Colonist activity, noise,
-- heat, fire, and combat all generate interest. Creatures query the Director
-- for a biased wander target when idle. The hint is intentionally imprecise —
-- offset by 5-15 tiles — so the creature must use its own senses to find
-- and engage targets. This creates tension: the creature is "in the right
-- area" but hasn't spotted you yet.
--
-- For colonists: the Director provides shared threat awareness. When any
-- colonist spots a hostile, all colonists get a general alert about the
-- threat zone. They won't know exact positions but will be vigilant.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Director = {}

---------------------------------------------------------------------------
-- Interest grid: coarse cells covering the map
---------------------------------------------------------------------------

local CELL_SIZE = 8   -- tiles per cell (128/8 = 16x16 grid = 256 cells)
local cells = {}      -- [cellKey] = { score, cx, cy }
local gridW, gridH = 0, 0

-- Shared threat reports: { [cellKey] = { x, y, tick, strength } }
local threatReports = {}

-- Constants: interest generation
local INTEREST_DECAY       = 0.85   -- per-update decay multiplier
local COLONIST_INTEREST    = 1.5    -- idle colonist presence
local WORK_INTEREST        = 3.0    -- active work (mining, building)
local COMBAT_INTEREST      = 8.0    -- fighting generates lots of attention
local FIRE_INTEREST        = 5.0    -- fires draw creatures
local REACTOR_INTEREST     = 2.0    -- thermal reactor heat signature

-- Constants: hint generation
local BASE_HINT_OFFSET     = 12     -- base tiles of imprecision
local MIN_HINT_OFFSET      = 5      -- minimum offset even at max interest
local HINT_SCORE_THRESHOLD = 0.5    -- ignore cells below this

-- Constants: threat awareness
local THREAT_DURATION      = 200    -- ticks before threat report expires
local THREAT_ALERT_RANGE   = 20     -- tile radius for colonist alert awareness

-- Update timer
local updateTimer = 0
local UPDATE_INTERVAL = 1.0  -- seconds between interest grid updates

local function cellKey(cx, cy) return cy * 10000 + cx end

local function tileToCell(x, y)
    return math.floor(x / CELL_SIZE), math.floor(y / CELL_SIZE)
end

local function cellToTile(cx, cy)
    return cx * CELL_SIZE + math.floor(CELL_SIZE / 2),
           cy * CELL_SIZE + math.floor(CELL_SIZE / 2)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Director.init()
    gridW = math.ceil((GameState.mapWidth or 128) / CELL_SIZE)
    gridH = math.ceil((GameState.mapHeight or 128) / CELL_SIZE)
    cells = {}
    threatReports = {}
    updateTimer = 0
end

---------------------------------------------------------------------------
-- Interest management
---------------------------------------------------------------------------

function Director.addInterest(tileX, tileY, amount)
    local cx, cy = tileToCell(tileX, tileY)
    local k = cellKey(cx, cy)
    local cell = cells[k]
    if cell then
        cell.score = cell.score + amount
    else
        cells[k] = { score = amount, cx = cx, cy = cy }
    end
end

--- Noise event: mining, construction, explosions, gunfire.
--- Radiates interest to adjacent cells.
function Director.onNoise(tileX, tileY, intensity)
    intensity = intensity or 1.0
    local cx, cy = tileToCell(tileX, tileY)
    -- Center cell gets full noise
    local k = cellKey(cx, cy)
    local cell = cells[k]
    if cell then
        cell.score = cell.score + intensity * 5.0
    else
        cells[k] = { score = intensity * 5.0, cx = cx, cy = cy }
    end
    -- Adjacent cells get half
    for _, d in ipairs({ {1,0},{-1,0},{0,1},{0,-1} }) do
        local nx, ny = cx + d[1], cy + d[2]
        if nx >= 0 and nx < gridW and ny >= 0 and ny < gridH then
            local nk = cellKey(nx, ny)
            local ncell = cells[nk]
            if ncell then
                ncell.score = ncell.score + intensity * 2.5
            else
                cells[nk] = { score = intensity * 2.5, cx = nx, cy = ny }
            end
        end
    end
end

---------------------------------------------------------------------------
-- Threat awareness: colonists share sighting reports
---------------------------------------------------------------------------

--- Called when any colonist spots a hostile creature.
function Director.reportThreat(tileX, tileY, strength)
    local cx, cy = tileToCell(tileX, tileY)
    local k = cellKey(cx, cy)
    threatReports[k] = {
        x = tileX, y = tileY,
        tick = GameState.simTick,
        strength = strength or 1.0,
    }
end

--- Check if there's an active threat report near (x, y).
--- Returns (threatX, threatY, strength) or nil.
--- The position is the general area, not exact.
function Director.getNearbyThreat(x, y)
    local bestDist = THREAT_ALERT_RANGE * THREAT_ALERT_RANGE
    local bestReport = nil
    local curTick = GameState.simTick

    for _, report in pairs(threatReports) do
        if curTick - report.tick < THREAT_DURATION then
            local dx = report.x - x
            local dy = report.y - y
            local dSq = dx * dx + dy * dy
            if dSq < bestDist then
                bestDist = dSq
                bestReport = report
            end
        end
    end

    if not bestReport then return nil end
    -- Add slight offset so colonists know the area, not the exact tile
    local ox = bestReport.x + math.random(-3, 3)
    local oy = bestReport.y + math.random(-3, 3)
    return ox, oy, bestReport.strength
end

---------------------------------------------------------------------------
-- Step: decay interest, gather new from world state
---------------------------------------------------------------------------

function Director.step(dt)
    updateTimer = updateTimer + dt
    if updateTimer < UPDATE_INTERVAL then return end
    updateTimer = 0

    -- Decay all cells
    local toRemove = {}
    for k, cell in pairs(cells) do
        cell.score = cell.score * INTEREST_DECAY
        if cell.score < 0.1 then
            toRemove[#toRemove + 1] = k
        end
    end
    for _, k in ipairs(toRemove) do
        cells[k] = nil
    end

    -- Expire old threat reports
    local curTick = GameState.simTick
    local threatExpire = {}
    for k, report in pairs(threatReports) do
        if curTick - report.tick >= THREAT_DURATION then
            threatExpire[#threatExpire + 1] = k
        end
    end
    for _, k in ipairs(threatExpire) do
        threatReports[k] = nil
    end

    -- Interest from colonist positions and activities
    for _, comps in ECS.query('pos', 'colonist') do
        local pos = comps.pos
        local col = comps.colonist
        if col.state ~= 'dead' then
            local interest = COLONIST_INTEREST
            if col.state == 'working' then
                interest = WORK_INTEREST
            elseif col.state == 'fighting' then
                interest = COMBAT_INTEREST
            end
            Director.addInterest(pos.x, pos.y, interest)
        end
    end

    -- Interest from active fires
    local fok, Fire = pcall(require, 'src.sim.fire')
    if fok then
        for _, fire in pairs(Fire.getActiveFires()) do
            Director.addInterest(fire.x, fire.y, FIRE_INTEREST)
        end
    end

    -- Interest from steam hub heat signatures
    local gok, Gen = pcall(require, 'src.sim.generator')
    if gok and Gen.getHubs then
        for _, hub in ipairs(Gen.getHubs()) do
            if hub.active and hub.pos then
                Director.addInterest(hub.pos.x, hub.pos.y, REACTOR_INTEREST * 0.5)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Hint generation: biased wander target for creatures
---------------------------------------------------------------------------

--- Get a hint destination for a creature at (x, y).
--- Returns (hintX, hintY, strength) or nil if no interesting areas.
--- The hint is intentionally imprecise.
function Director.getHint(x, y, maxRange)
    maxRange = maxRange or 50
    local creatureCx, creatureCy = tileToCell(x, y)
    local cellRange = math.ceil(maxRange / CELL_SIZE)

    -- Find highest-interest cell within range
    local bestKey, bestScore = nil, 0
    for k, cell in pairs(cells) do
        local dcx = math.abs(cell.cx - creatureCx)
        local dcy = math.abs(cell.cy - creatureCy)
        if dcx <= cellRange and dcy <= cellRange then
            -- Weight by score, slight distance penalty
            local dist = math.max(1, dcx + dcy)
            local weight = cell.score / (1 + dist * 0.15)
            if weight > bestScore then
                bestScore = weight
                bestKey = k
            end
        end
    end

    if not bestKey or bestScore < HINT_SCORE_THRESHOLD then return nil end

    local best = cells[bestKey]
    local hintX, hintY = cellToTile(best.cx, best.cy)

    -- Intentional imprecision: stronger signal = slightly less offset
    local accuracy = math.min(1, bestScore / 15)
    local offset = BASE_HINT_OFFSET * (1 - accuracy * 0.4) + MIN_HINT_OFFSET
    local angle = math.random() * math.pi * 2
    local r = offset * (0.4 + math.random() * 0.6)
    hintX = hintX + math.floor(math.cos(angle) * r)
    hintY = hintY + math.floor(math.sin(angle) * r)

    -- Clamp to map
    local wok, World = pcall(require, 'src.world.tilemap')
    if wok then
        hintX = math.max(1, math.min(World.width() - 2, hintX))
        hintY = math.max(1, math.min(World.height() - 2, hintY))
    end

    return hintX, hintY, bestScore
end

---------------------------------------------------------------------------
-- Debug: interest grid data
---------------------------------------------------------------------------

function Director.getInterestAt(tileX, tileY)
    local cx, cy = tileToCell(tileX, tileY)
    local cell = cells[cellKey(cx, cy)]
    return cell and cell.score or 0
end

function Director.getInterestCells(threshold)
    threshold = threshold or 0.5
    local result = {}
    for _, cell in pairs(cells) do
        if cell.score >= threshold then
            local tx, ty = cellToTile(cell.cx, cell.cy)
            result[#result + 1] = { x = tx, y = ty, score = cell.score }
        end
    end
    return result
end

function Director.getThreatReports()
    return threatReports
end

---------------------------------------------------------------------------
-- Save/load
---------------------------------------------------------------------------

function Director.getState()
    return { cells = cells, threatReports = threatReports }
end

function Director.loadState(saved)
    if not saved then return end
    cells = saved.cells or {}
    threatReports = saved.threatReports or {}
end

return Director
