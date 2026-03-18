-- visibility.lua — Factorio-style fog of war with vision cones
-- Tiles start unexplored (black). Colonists reveal tiles within their
-- vision cone (facing-aware, LOS-blocked by walls). Buildings and
-- watchtowers use circular reveal. Once explored, tiles stay visible
-- in a dimmed "memory" state. Active sight shows real-time.
-- Toggleable via GameState.fogOfWar (default true).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Visibility = {}

-- Per-tile state: flat arrays indexed by (y * width + x + 1)
local explored = {}   -- boolean: has any sight source ever seen this tile?
local visible  = {}   -- boolean: is any sight source currently seeing this tile?
local mapW, mapH = 0, 0

-- Registered sight sources: { [key] = { x, y, radius } }
local sightSources = {}

-- Per-colonist cone data for renderer (rebuilt each step)
-- { [entityId] = { x, y, facing, halfFov, range, tiles = {idx1, idx2, ...} } }
local colonistCones = {}

-- Default sight radii
Visibility.COLONIST_SIGHT     = 14
Visibility.COLONIST_NIGHT     = 8
Visibility.WATCHTOWER_SIGHT   = 25
Visibility.BUILDING_SIGHT     = 4
Visibility.RADIO_BEACON_SIGHT = 40

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Visibility.init(w, h)
    mapW = w or GameState.mapWidth
    mapH = h or GameState.mapHeight
    local size = mapW * mapH
    explored = {}
    visible  = {}
    sightSources = {}
    colonistCones = {}
    for i = 1, size do
        explored[i] = false
        visible[i]  = false
    end
end

---------------------------------------------------------------------------
-- Sight source management (static sources: buildings, watchtowers)
---------------------------------------------------------------------------

function Visibility.addSight(key, x, y, radius)
    sightSources[key] = { x = x, y = y, radius = radius }
end

function Visibility.removeSight(key)
    sightSources[key] = nil
end

function Visibility.updateSight(key, x, y, radius)
    local src = sightSources[key]
    if src then
        src.x = x
        src.y = y
        if radius then src.radius = radius end
    end
end

---------------------------------------------------------------------------
-- Reveal an area (used at game start to reveal spawn zone)
---------------------------------------------------------------------------

function Visibility.revealArea(cx, cy, radius)
    local r2 = radius * radius
    local minX = math.max(0, cx - radius)
    local maxX = math.min(mapW - 1, cx + radius)
    local minY = math.max(0, cy - radius)
    local maxY = math.min(mapH - 1, cy + radius)
    for ty = minY, maxY do
        for tx = minX, maxX do
            local dx = tx - cx
            local dy = ty - cy
            if dx * dx + dy * dy <= r2 then
                explored[ty * mapW + tx + 1] = true
            end
        end
    end
end

---------------------------------------------------------------------------
-- Step — rebuild visible[] from all sight sources, update explored[]
-- Called each sim tick (20Hz).
---------------------------------------------------------------------------

function Visibility.step()
    if not GameState.fogOfWar then return end

    local size = mapW * mapH
    -- Clear visible
    for i = 1, size do
        visible[i] = false
    end

    colonistCones = {}

    -- LOS module for cone-based colonist sight
    local lok, LOS = pcall(require, 'src.sim.line_of_sight')

    -- Gather sight from colonists (cone-based with LOS)
    local daytime = GameState.isDaytime()
    local colSight = daytime and Visibility.COLONIST_SIGHT or Visibility.COLONIST_NIGHT
    local halfFov = lok and LOS.COLONIST_FOV / 2 or (math.pi * 7 / 18)

    for id, comps in ECS.query('pos', 'colonist') do
        local pos = comps.pos
        local col = comps.colonist
        if col.state ~= 'dead' then
            local facing = col.facing or 0
            if lok then
                -- Cone-based visibility with raycasting
                local coneTiles = {}
                LOS.markConeTiles(pos.x, pos.y, facing, halfFov, colSight,
                    function(tx, ty)
                        local idx = ty * mapW + tx + 1
                        visible[idx]  = true
                        explored[idx] = true
                        coneTiles[#coneTiles + 1] = idx
                    end)
                colonistCones[id] = {
                    x = pos.x, y = pos.y,
                    facing = facing,
                    halfFov = halfFov,
                    range = colSight,
                    tiles = coneTiles,
                }
            else
                -- Fallback: circular reveal if LOS module unavailable
                Visibility.markVisible(pos.x, pos.y, colSight)
            end
        end
    end

    -- Gather sight from registered static sources (watchtowers, buildings, beacons)
    -- Static sources use circular reveal (no facing)
    for _, src in pairs(sightSources) do
        Visibility.markVisible(src.x, src.y, src.radius)
    end
end

---------------------------------------------------------------------------
-- Mark tiles visible within a circular radius (also marks explored)
-- Used for buildings and static sources that have no facing direction.
---------------------------------------------------------------------------

function Visibility.markVisible(cx, cy, radius)
    local r2 = radius * radius
    local minX = math.max(0, cx - radius)
    local maxX = math.min(mapW - 1, cx + radius)
    local minY = math.max(0, cy - radius)
    local maxY = math.min(mapH - 1, cy + radius)
    for ty = minY, maxY do
        for tx = minX, maxX do
            local dx = tx - cx
            local dy = ty - cy
            if dx * dx + dy * dy <= r2 then
                local idx = ty * mapW + tx + 1
                visible[idx]  = true
                explored[idx] = true
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Visibility.isExplored(x, y)
    if not GameState.fogOfWar then return true end
    if x < 0 or x >= mapW or y < 0 or y >= mapH then return false end
    return explored[y * mapW + x + 1]
end

function Visibility.isVisible(x, y)
    if not GameState.fogOfWar then return true end
    if x < 0 or x >= mapW or y < 0 or y >= mapH then return false end
    return visible[y * mapW + x + 1]
end

function Visibility.rawExplored()
    return explored
end

function Visibility.rawVisible()
    return visible
end

function Visibility.getMapSize()
    return mapW, mapH
end

--- Returns per-colonist cone data for rendering.
--- Each entry: { x, y, facing, halfFov, range, tiles = {idx...} }
function Visibility.getColonistCones()
    return colonistCones
end

---------------------------------------------------------------------------
-- Save/load — only explored[] persists (visible is recomputed each tick)
---------------------------------------------------------------------------

function Visibility.getState()
    local runs = {}
    local i = 1
    local size = mapW * mapH
    while i <= size do
        local val = explored[i] and true or false
        local count = 1
        while i + count <= size and (explored[i + count] and true or false) == val do
            count = count + 1
        end
        runs[#runs + 1] = { v = val, n = count }
        i = i + count
    end
    return { mapW = mapW, mapH = mapH, runs = runs, sightSources = sightSources }
end

function Visibility.loadState(saved)
    if not saved then return end
    mapW = saved.mapW or GameState.mapWidth
    mapH = saved.mapH or GameState.mapHeight
    local size = mapW * mapH
    explored = {}
    visible  = {}
    for i = 1, size do
        explored[i] = false
        visible[i]  = false
    end
    if saved.runs then
        local idx = 1
        for _, run in ipairs(saved.runs) do
            for j = 1, run.n do
                if idx <= size then
                    explored[idx] = run.v
                end
                idx = idx + 1
            end
        end
    end
    if saved.sightSources then
        sightSources = saved.sightSources
    end
end

return Visibility
