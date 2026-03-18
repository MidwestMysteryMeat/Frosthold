-- line_of_sight.lua — Raycasting and vision cone calculations
-- Provides tile-based LOS checks through the tilemap.
-- Walls, rocks, and trees are opaque. Floors, doors, snow are transparent.

local LOS = {}

-- Vision cone parameters
LOS.COLONIST_FOV    = math.pi * 7 / 9   -- 140° total (70° half)
LOS.CREATURE_FOV    = math.pi * 5 / 9   -- 100° total (50° half)
LOS.PREY_FOV        = math.pi * 8 / 9   -- 160° total (80° half)
LOS.PERIPHERAL_RANGE = 3                -- tiles always visible around entity

-- Cache opaque tile set (built once on first use)
local opaqueSet = nil

local function buildOpaqueSet()
    local ok, Tiles = pcall(require, 'src.world.tiles')
    if not ok then return {} end
    local set = {}
    -- Walls block vision
    if Tiles.WALL_WOOD      then set[Tiles.WALL_WOOD]      = true end
    if Tiles.WALL_STONE     then set[Tiles.WALL_STONE]     = true end
    if Tiles.WALL_METAL     then set[Tiles.WALL_METAL]     = true end
    if Tiles.WALL_INSULATED then set[Tiles.WALL_INSULATED] = true end
    -- Natural solids block vision
    if Tiles.ROCK           then set[Tiles.ROCK]           = true end
    if Tiles.TREE           then set[Tiles.TREE]           = true end
    if Tiles.ORE_VEIN       then set[Tiles.ORE_VEIN]       = true end
    -- Void blocks
    if Tiles.VOID           then set[Tiles.VOID]           = true end
    return set
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function LOS.isOpaque(tileType)
    if not opaqueSet then opaqueSet = buildOpaqueSet() end
    return opaqueSet[tileType] == true
end

--- Bresenham raycast: returns true if LOS is clear from (x0,y0) to (x1,y1).
--- Checks intermediate tiles only (not start tile).
function LOS.raycast(x0, y0, x1, y1, depth)
    local World = require('src.world.tilemap')
    local d = depth or 0
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    local cx, cy = x0, y0

    while true do
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            cx = cx + sx
        end
        if e2 < dx then
            err = err + dx
            cy = cy + sy
        end

        -- Reached destination
        if cx == x1 and cy == y1 then return true end

        -- Out of bounds or opaque tile blocks
        if not World.inBounds(cx, cy) then return false end
        local tile = World.getTile(cx, cy, d)
        if LOS.isOpaque(tile) then return false end
    end
end

--- Check if (tx,ty) is within a vision cone.
--- facing: radians (0=right, π/2=down, π=left, 3π/2=up)
--- halfFov: half the field of view in radians
--- range: max sight distance
function LOS.inCone(cx, cy, tx, ty, facing, halfFov, range)
    local dx = tx - cx
    local dy = ty - cy
    local distSq = dx * dx + dy * dy
    if distSq > range * range then return false end
    if distSq == 0 then return true end

    local angle = math.atan2(dy, dx)
    local diff = angle - facing
    -- Normalize to [-π, π]
    if diff > math.pi then diff = diff - 2 * math.pi
    elseif diff < -math.pi then diff = diff + 2 * math.pi end

    return math.abs(diff) <= halfFov
end

--- Full visibility check: cone + LOS raycast.
function LOS.canSee(cx, cy, tx, ty, facing, halfFov, range, depth)
    local dx = tx - cx
    local dy = ty - cy
    local distSq = dx * dx + dy * dy

    -- Always see tiles within peripheral range
    if distSq <= LOS.PERIPHERAL_RANGE * LOS.PERIPHERAL_RANGE then
        return LOS.raycast(cx, cy, tx, ty, depth)
    end

    if not LOS.inCone(cx, cy, tx, ty, facing, halfFov, range) then
        return false
    end
    return LOS.raycast(cx, cy, tx, ty, depth)
end

--- Compute facing angle from movement (prevX,prevY) -> (x,y).
--- Returns nil if no movement.
function LOS.facingFromMovement(prevX, prevY, x, y)
    local dx = x - prevX
    local dy = y - prevY
    if dx == 0 and dy == 0 then return nil end
    return math.atan2(dy, dx)
end

--- Compute facing angle toward a specific target tile.
function LOS.facingToward(fromX, fromY, toX, toY)
    local dx = toX - fromX
    local dy = toY - fromY
    if dx == 0 and dy == 0 then return 0 end
    return math.atan2(dy, dx)
end

---------------------------------------------------------------------------
-- Batch: get all visible tiles in a cone with LOS
-- Used by visibility.lua for fog of war reveal
---------------------------------------------------------------------------

function LOS.markConeTiles(cx, cy, facing, halfFov, range, markFn, depth)
    local World = require('src.world.tilemap')
    local d = depth or 0
    local r = math.ceil(range)
    local mapW = World.width()
    local mapH = World.height()
    local minX = math.max(0, cx - r)
    local maxX = math.min(mapW - 1, cx + r)
    local minY = math.max(0, cy - r)
    local maxY = math.min(mapH - 1, cy + r)
    local rSq = range * range
    local pSq = LOS.PERIPHERAL_RANGE * LOS.PERIPHERAL_RANGE

    for ty = minY, maxY do
        for tx = minX, maxX do
            local dx = tx - cx
            local dy = ty - cy
            local dSq = dx * dx + dy * dy
            if dSq <= rSq then
                -- Peripheral: always visible if LOS clear
                if dSq <= pSq then
                    if dSq == 0 or LOS.raycast(cx, cy, tx, ty, d) then
                        markFn(tx, ty)
                    end
                elseif LOS.inCone(cx, cy, tx, ty, facing, halfFov, range) then
                    if LOS.raycast(cx, cy, tx, ty, d) then
                        markFn(tx, ty)
                    end
                end
            end
        end
    end
end

return LOS
