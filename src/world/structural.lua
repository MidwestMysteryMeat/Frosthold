-- structural.lua — Underground structural integrity and cave-in simulation
-- Excavated underground areas need support columns or natural rock pillars
-- to prevent collapse. Large open spans without support will cave in,
-- damaging entities and reverting tiles to debris/rubble.
--
-- Stability model: each underground floor tile has a stability score based on
-- its distance to the nearest support (column, natural rock, wall).
-- Tiles beyond MAX_UNSUPPORTED_SPAN from support are unstable.
-- Unstable tiles accumulate collapse pressure each tick.
-- When pressure exceeds threshold, the tile and nearby tiles collapse.

local Tiles     = require('src.world.tiles')
local GameState = require('src.game_state')
local ECS       = require('src.ecs.ecs')

local Structural = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local MAX_UNSUPPORTED_SPAN = 14  -- max tiles from support before instability
local COLLAPSE_THRESHOLD   = 300 -- pressure units before collapse triggers
local PRESSURE_RATE        = 6.0 -- pressure gained per second per unstable tile
local CHECK_INTERVAL       = 3.0 -- seconds between stability scans
local COLLAPSE_RADIUS      = 6   -- tiles affected by a collapse event
local COLLAPSE_DAMAGE      = 100 -- HP damage to entities caught in cave-in

-- Research flag: structural_engineering reduces collapse risk
local researchBonus = 0  -- 0 = none, 1 = basic (+6 span), 2 = advanced (+12 span)

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local collapseTimer = 0
-- Per-tile collapse pressure: { [depthKey] = pressure }
-- depthKey = depth * 100000000 + tileIdx
local pressure = {}

---------------------------------------------------------------------------
-- Support detection
-- A tile is "supported" if it's within span distance of a support tile.
-- Different supports have different span ranges:
--   Wood column:       8 tiles (degrades over time)
--   Stone column:      14 tiles (base, research extends)
--   Reinforced column: 26 tiles (requires advanced research)
--   Natural rock/wall: MAX_UNSUPPORTED_SPAN (14 base + research bonus)
---------------------------------------------------------------------------

local function isSupport(tileType)
    return Tiles.isSolid(tileType)
        or tileType == Tiles.SUPPORT_COLUMN
        or tileType == Tiles.SUPPORT_COLUMN_WOOD
        or tileType == Tiles.REINFORCED_COLUMN
        or tileType == Tiles.WALL_STONE
        or tileType == Tiles.WALL_METAL
        or tileType == Tiles.WALL_INSULATED
end

-- Get the effective support span of a tile type
local function getSupportSpan(tileType)
    local props = Tiles.get(tileType)
    if props and props.supportSpan then
        return props.supportSpan
    end
    -- Natural rock, walls: use base span + research
    return MAX_UNSUPPORTED_SPAN + researchBonus * 6
end

-- Wood column degradation tracking: { [depthKey] = durability (0-100) }
local columnDurability = {}
local WOOD_COLUMN_MAX_DURABILITY = 100
local WOOD_COLUMN_DECAY_RATE     = 0.014 -- per second (~2 hours real time to break)
local WOOD_COLUMN_CRITICAL       = 20    -- below this, span halved
local WOOD_COLUMN_BREAK          = 0     -- at 0, column collapses

-- BFS from all support tiles to compute distance-to-support for each open tile.
-- Each support seeds BFS up to its own span limit.
-- Returns distMap: { [tileIdx] = distance }
local function computeStabilityMap(tData, w, h, depth)
    local globalMaxSpan = MAX_UNSUPPORTED_SPAN + researchBonus * 6
    -- Find the largest possible span for BFS limit
    local bfsLimit = math.max(globalMaxSpan, 26) + 2
    local dist = {}
    local queue = {}
    local head = 1
    -- Track per-support span limits: { [seedIdx] = spanLimit }
    local supportSpan = {}

    -- Seed BFS from all support tiles
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local idx = y * w + x + 1
            if isSupport(tData[idx]) then
                local span = getSupportSpan(tData[idx])
                -- Wood columns at critical durability have halved span
                if tData[idx] == Tiles.SUPPORT_COLUMN_WOOD and depth then
                    local dk = depth * 100000000 + idx
                    local dur = columnDurability[dk]
                    if dur and dur < WOOD_COLUMN_CRITICAL then
                        span = math.floor(span * 0.5)
                    end
                end
                dist[idx] = 0
                supportSpan[idx] = span
                queue[#queue + 1] = idx
            end
        end
    end

    local DIRS = { -1, 1, -w, w }  -- left, right, up, down by index offset

    while head <= #queue do
        local ci = queue[head]
        head = head + 1
        local d = dist[ci]
        local mySpan = supportSpan[ci] or globalMaxSpan
        if d < mySpan + 1 then
            local cy = math.floor((ci - 1) / w)
            local cx = (ci - 1) % w
            for _, off in ipairs(DIRS) do
                local ni = ci + off
                -- Bounds check
                local nx = (ni - 1) % w
                local ny = math.floor((ni - 1) / w)
                if nx >= 0 and nx < w and ny >= 0 and ny < h
                   and math.abs(nx - cx) + math.abs(ny - cy) == 1 then
                    if not dist[ni] then
                        dist[ni] = d + 1
                        supportSpan[ni] = mySpan
                        queue[#queue + 1] = ni
                    end
                end
            end
        end
    end

    return dist, supportSpan, globalMaxSpan
end

---------------------------------------------------------------------------
-- Step — periodic stability scan and collapse processing
---------------------------------------------------------------------------

function Structural.step(dt)
    collapseTimer = collapseTimer + dt
    if collapseTimer < CHECK_INTERVAL then return end
    collapseTimer = 0

    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end

    local w, h = World.width(), World.height()

    -- Update research bonus
    local rOk, Research = pcall(require, 'src.research.research')
    if rOk then
        if Research.isCompleted('advanced_structural') then
            researchBonus = 2
        elseif Research.isCompleted('structural_engineering') then
            researchBonus = 1
        else
            researchBonus = 0
        end
    end

    -- Only check underground layers (depth > 0)
    for depth, layer in World.allLayers() do
        if depth > 0 then
            local tData = layer.tiles
            local distMap, spanMap, globalMaxSpan = computeStabilityMap(tData, w, h, depth)

            -- Wood column degradation
            for y = 0, h - 1 do
                for x = 0, w - 1 do
                    local idx = y * w + x + 1
                    if tData[idx] == Tiles.SUPPORT_COLUMN_WOOD then
                        local dk = depth * 100000000 + idx
                        local dur = columnDurability[dk]
                        if not dur then
                            columnDurability[dk] = WOOD_COLUMN_MAX_DURABILITY
                        else
                            dur = dur - WOOD_COLUMN_DECAY_RATE * CHECK_INTERVAL
                            if dur <= WOOD_COLUMN_BREAK then
                                -- Column breaks: revert to debris
                                tData[idx] = Tiles.DEBRIS
                                columnDurability[dk] = nil
                                -- Immediate local collapse check
                                Structural.triggerCollapse(x, y, depth, World, w, h)
                            else
                                columnDurability[dk] = dur
                            end
                        end
                    end
                end
            end

            -- Stability check for open tiles
            for y = 0, h - 1 do
                for x = 0, w - 1 do
                    local idx = y * w + x + 1
                    local tile = tData[idx]

                    -- Only open underground tiles can be unstable
                    if tile == Tiles.UNDERGROUND_FLOOR or tile == Tiles.SHAFT_ENTRANCE then
                        local d = distMap[idx] or (globalMaxSpan + 5)
                        local tileSpan = spanMap[idx] or globalMaxSpan
                        local depthKey = depth * 100000000 + idx

                        if d > tileSpan then
                            -- Unstable: accumulate pressure
                            local cur = pressure[depthKey] or 0
                            cur = cur + PRESSURE_RATE * CHECK_INTERVAL
                            if cur >= COLLAPSE_THRESHOLD then
                                Structural.triggerCollapse(x, y, depth, World, w, h)
                                pressure[depthKey] = nil
                            else
                                pressure[depthKey] = cur
                            end
                        else
                            -- Stable: bleed off pressure
                            if pressure[depthKey] then
                                pressure[depthKey] = pressure[depthKey] - CHECK_INTERVAL * 5
                                if pressure[depthKey] <= 0 then
                                    pressure[depthKey] = nil
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Collapse event — converts tiles to debris, damages entities
---------------------------------------------------------------------------

function Structural.triggerCollapse(cx, cy, depth, World, w, h)
    -- Revert tiles in radius to underground rock (rubble)
    local collapsed = {}
    for dy = -COLLAPSE_RADIUS, COLLAPSE_RADIUS do
        for dx = -COLLAPSE_RADIUS, COLLAPSE_RADIUS do
            local nx, ny = cx + dx, cy + dy
            if World.inBounds(nx, ny) then
                local tile = World.getTile(nx, ny, depth)
                if tile == Tiles.UNDERGROUND_FLOOR then
                    World.setTile(nx, ny, Tiles.DEBRIS, depth)
                    collapsed[#collapsed + 1] = { x = nx, y = ny }
                end
            end
        end
    end

    -- Clear pressure for collapsed tiles
    for _, pos in ipairs(collapsed) do
        local idx = pos.y * w + pos.x + 1
        pressure[depth * 100000000 + idx] = nil
    end

    -- Damage entities caught in cave-in
    for id, comps in ECS.query('pos', 'colonist') do
        local pos = comps.pos
        if (pos.depth or 0) == depth then
            local dist = math.abs(pos.x - cx) + math.abs(pos.y - cy)
            if dist <= COLLAPSE_RADIUS then
                local col = comps.colonist
                if col.state ~= 'dead' then
                    col.health = (col.health or 100) - COLLAPSE_DAMAGE
                    if col.health <= 0 then
                        local cOk, ColMod = pcall(require, 'src.colonist.colonist')
                        if cOk then ColMod.kill(id) end
                    end
                end
            end
        end
    end

    for id, comps in ECS.query('pos', 'creature') do
        local pos = comps.pos
        if (pos.depth or 0) == depth then
            local dist = math.abs(pos.x - cx) + math.abs(pos.y - cy)
            if dist <= COLLAPSE_RADIUS then
                local cr = comps.creature
                if (cr.health or 0) > 0 then
                    cr.health = cr.health - COLLAPSE_DAMAGE
                end
            end
        end
    end

    -- Hope penalty
    local hOk, Hope = pcall(require, 'src.colony.hope')
    if hOk then Hope.addHope(-3, 'cave-in') end

    -- Log event
    local sOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sOk and Storyteller.logEvent then
        Storyteller.logEvent('cave_in', {
            x = cx, y = cy, depth = depth,
            tiles = #collapsed,
        })
    end
end

---------------------------------------------------------------------------
-- Called after excavation — immediate instability warning check
---------------------------------------------------------------------------

function Structural.onTileExcavated(x, y, depth)
    -- Don't track surface
    if not depth or depth == 0 then return end

    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end

    local w, h = World.width(), World.height()
    local tData = World.rawTileData(depth)
    if not tData then return end

    -- Quick check: is this tile within any support's span?
    local searchRadius = 28  -- slightly beyond max possible span
    local supported = false
    for dy = -searchRadius, searchRadius do
        if supported then break end
        for dx = -searchRadius, searchRadius do
            local dist = math.abs(dx) + math.abs(dy)
            if dist <= searchRadius then
                local nx, ny = x + dx, y + dy
                if World.inBounds(nx, ny) then
                    local idx = ny * w + nx + 1
                    if isSupport(tData[idx]) then
                        local span = getSupportSpan(tData[idx])
                        if dist <= span then
                            supported = true
                            break
                        end
                    end
                end
            end
        end
    end

    -- If unsupported, seed pressure for faster collapse detection
    if not supported then
        local idx = y * w + x + 1
        local depthKey = depth * 100000000 + idx
        pressure[depthKey] = (pressure[depthKey] or 0) + PRESSURE_RATE * 10
    end
end

---------------------------------------------------------------------------
-- Stability query — UI can show stability overlay
---------------------------------------------------------------------------

function Structural.getStability(x, y, depth)
    if not depth or depth == 0 then return 1.0 end

    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return 1.0 end

    local w = World.width()
    local idx = y * w + x + 1
    local depthKey = depth * 100000000 + idx

    local p = pressure[depthKey] or 0
    return math.max(0, 1.0 - p / COLLAPSE_THRESHOLD)
end

-- Check if a tile is near enough to any support
function Structural.isSupported(x, y, depth)
    if not depth or depth == 0 then return true end

    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return true end

    local w, h = World.width(), World.height()
    local tData = World.rawTileData(depth)
    if not tData then return true end

    local searchRadius = 28
    for dy = -searchRadius, searchRadius do
        for dx = -searchRadius, searchRadius do
            local dist = math.abs(dx) + math.abs(dy)
            if dist <= searchRadius then
                local nx, ny = x + dx, y + dy
                if World.inBounds(nx, ny) then
                    local idx = ny * w + nx + 1
                    if isSupport(tData[idx]) then
                        local span = getSupportSpan(tData[idx])
                        if dist <= span then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Structural.getState()
    return {
        pressure = pressure,
        columnDurability = columnDurability,
        researchBonus = researchBonus,
    }
end

function Structural.loadState(state)
    if not state then return end
    pressure = state.pressure or {}
    columnDurability = state.columnDurability or {}
    researchBonus = state.researchBonus or 0
end

-- Query wood column durability (for UI)
function Structural.getColumnDurability(x, y, depth)
    if not depth or depth == 0 then return nil end
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return nil end
    local w = World.width()
    local idx = y * w + x + 1
    local dk = depth * 100000000 + idx
    return columnDurability[dk]
end

-- Repair a wood column (called by colonist repair task)
function Structural.repairColumn(x, y, depth)
    if not depth or depth == 0 then return end
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    local w = World.width()
    local idx = y * w + x + 1
    local dk = depth * 100000000 + idx
    columnDurability[dk] = WOOD_COLUMN_MAX_DURABILITY
end

-- Clean up column durability when a column tile is removed or replaced
function Structural.onColumnRemoved(x, y, depth)
    if not depth or depth == 0 then return end
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not wOk then return end
    local w = World.width()
    local idx = y * w + x + 1
    local dk = depth * 100000000 + idx
    columnDurability[dk] = nil
    pressure[dk] = nil
end

return Structural
