-- pathfind.lua — A* pathfinding on tile grid with depth support
-- Returns a list of {x, y, depth} nodes from start to goal, or nil if unreachable.
-- Respects occupancy: avoids tiles occupied by other entities.
-- Shaft entrances connect adjacent depth levels as neighbors.

local Occupancy = require('src.util.occupancy')

local Pathfind = {}

local _defensesLoaded = false
local _Defenses = nil
local function isBarrierBlocking(x, y, depth)
    if not _defensesLoaded then
        _defensesLoaded = true
        local ok, mod = pcall(require, 'src.combat.defenses')
        if ok then _Defenses = mod end
    end
    return _Defenses and _Defenses.isBlockingBarrierAt and _Defenses.isBlockingBarrierAt(x, y, depth)
end

-- Check the world supplied by the caller. Reading the global tilemap here
-- polluted lightweight/test worlds with unrelated door and snow state.
local function isDoorLocked(world, x, y)
    return world.isDoorLocked and world.isDoorLocked(x, y) or false
end

local _ecsLoaded = false
local _ECS = nil
local function isColonistMover(moverId)
    if not moverId then return false end
    if not _ecsLoaded then
        _ecsLoaded = true
        local ok, mod = pcall(require, 'src.ecs.ecs')
        if ok then _ECS = mod end
    end
    return _ECS and _ECS.get and _ECS.get(moverId, 'colonist') ~= nil
end

local _zonesLoaded = false
local _Zones = nil
local function isRestrictedTileBlocked(x, y, depth)
    if not _zonesLoaded then
        _zonesLoaded = true
        local ok, mod = pcall(require, 'src.world.zones')
        if ok then _Zones = mod end
    end
    if not _Zones or not _Zones.hasRestrictedZones or not _Zones.isTileAllowed then
        return false
    end
    local d = depth or 0
    return _Zones.hasRestrictedZones(d) and not _Zones.isTileAllowed(x, y, d)
end

local _tileFluidsLoaded = false
local _TileFluids = nil
local function getWaterHazardCost(world, x, y, depth)
    if not world.getWater then return 0 end
    if not _tileFluidsLoaded then
        _tileFluidsLoaded = true
        local ok, mod = pcall(require, 'src.sim.tile_fluids')
        if ok then _TileFluids = mod end
    end
    if not _TileFluids then return 0 end
    local water = world.getWater(x, y, depth or 0)
    if water >= 6 then return 4 end
    if water >= 4 then return 2 end
    if water >= 2 then return 1 end
    return 0
end

local _tileGasLoaded = false
local _TileGas = nil
local function getGasHazardCost(world, x, y, depth)
    if not world.getGas then return 0 end
    if not _tileGasLoaded then
        _tileGasLoaded = true
        local ok, mod = pcall(require, 'src.sim.tile_gas')
        if ok then _TileGas = mod end
    end
    if not _TileGas then return 0 end
    if _TileGas.isToxic and _TileGas.isToxic(x, y, depth or 0) then
        return 4
    end
    if _TileGas.isBreathable and not _TileGas.isBreathable(x, y, depth or 0) then
        return 2
    end
    return 0
end

local MAX_NODES = 3000  -- search limit (increased for cross-depth paths)

-- Why the last failed query gave up. Purely diagnostic (the cold trace prints
-- it): a route that fails because the goal tile is occupied needs a different
-- answer from one that fails because the search ran out of budget.
Pathfind.lastFail = nil

-- Key encoding: depth * 100_000_000 + y * 10_000 + x
-- Supports x,y up to 9999 and depth up to ~90
local function key(x, y, d)
    return (d or 0) * 100000000 + y * 10000 + x
end

local function decodeKey(k)
    local d = math.floor(k / 100000000)
    local rem = k - d * 100000000
    local y = math.floor(rem / 10000)
    local x = rem - y * 10000
    return x, y, d
end

-- moverId: entity ID of the one pathfinding (so it doesn't block itself)
-- sd, gd: start and goal depth (default 0)
function Pathfind.find(sx, sy, gx, gy, world, moverId, sd, gd, opts)
    sd = sd or 0
    gd = gd or 0
    opts = opts or {}
    local respectRestricted = opts.ignoreRestricted ~= true and isColonistMover(moverId)
    local respectHazards = opts.ignoreHazards ~= true and isColonistMover(moverId)

    local function tileAllowed(x, y, depth)
        if opts.allowTile and not opts.allowTile(x, y, depth) then
            return false
        end
        if respectRestricted and isRestrictedTileBlocked(x, y, depth) then
            return false
        end
        if not opts.ignoreBarriers and isBarrierBlocking(x, y, depth) then
            return false
        end
        return true
    end

    Pathfind.lastFail = nil
    if sx == gx and sy == gy and sd == gd then return {} end
    if not world.isWalkable(gx, gy, gd) then
        Pathfind.lastFail = 'unwalkable'
        return nil
    end
    if not tileAllowed(gx, gy, gd) then
        Pathfind.lastFail = 'blocked'
        return nil
    end
    if moverId and Occupancy.isOccupiedBy(gx, gy, moverId, gd) then
        Pathfind.lastFail = 'occupied'
        return nil
    end

    local open = {}
    local openMap = {}
    local closed = {}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}

    local function heuristic(x, y, d)
        -- Manhattan + depth penalty (shaft traversal is expensive)
        return math.abs(x - gx) + math.abs(y - gy) + math.abs(d - gd) * 10
    end

    local function heapPush(node)
        open[#open + 1] = node
        local i = #open
        while i > 1 do
            local parent = math.floor(i / 2)
            if fScore[open[parent].k] > fScore[open[i].k] then
                open[parent], open[i] = open[i], open[parent]
                i = parent
            else
                break
            end
        end
    end

    local function heapPop()
        local top = open[1]
        open[1] = open[#open]
        open[#open] = nil
        local i = 1
        while true do
            local smallest = i
            local left = i * 2
            local right = i * 2 + 1
            if left <= #open and fScore[open[left].k] < fScore[open[smallest].k] then
                smallest = left
            end
            if right <= #open and fScore[open[right].k] < fScore[open[smallest].k] then
                smallest = right
            end
            if smallest ~= i then
                open[i], open[smallest] = open[smallest], open[i]
                i = smallest
            else
                break
            end
        end
        return top
    end

    local sk = key(sx, sy, sd)
    gScore[sk] = 0
    fScore[sk] = heuristic(sx, sy, sd)
    heapPush({ x = sx, y = sy, d = sd, k = sk })
    openMap[sk] = true

    local dirs = { {-1,0}, {1,0}, {0,-1}, {0,1} }
    local explored = 0
    -- Callers with a survival stake in the answer (the cold-emergency walk to
    -- a fire) can buy a bigger budget; everyday work routing keeps the cheap
    -- default so the sim stays fast.
    local nodeBudget = opts.maxNodes or MAX_NODES

    while #open > 0 do
        explored = explored + 1
        if explored > nodeBudget then
            Pathfind.lastFail = 'budget'
            return nil
        end

        local cur = heapPop()
        local ck = cur.k
        openMap[ck] = nil

        if cur.x == gx and cur.y == gy and cur.d == gd then
            -- Reconstruct path
            local path = {}
            local k2 = ck
            while k2 do
                local px, py, pd = decodeKey(k2)
                path[#path + 1] = { x = px, y = py, depth = pd }
                k2 = cameFrom[k2]
            end
            local result = {}
            for i = #path - 1, 1, -1 do
                result[#result + 1] = path[i]
            end
            return result
        end

        closed[ck] = true

        -- Cardinal neighbors on same depth
        for _, dir in ipairs(dirs) do
            local nx, ny = cur.x + dir[1], cur.y + dir[2]
            local nk = key(nx, ny, cur.d)
            if not closed[nk] and world.inBounds(nx, ny) and world.isWalkable(nx, ny, cur.d)
                and tileAllowed(nx, ny, cur.d) and not isDoorLocked(world, nx, ny) then
                -- Deep snow is punishing but NEVER an absolute wall. A long
                -- blizzard buries every outdoor tile to max depth (7); when
                -- that depth was treated as impassable, pathfinding failed
                -- across the whole surface, colonists were stranded wherever
                -- they stood, and the colony froze to death with no route to
                -- any fire. Colonists now plough through at high cost
                -- (movementSystem keeps a nonzero speed floor to match).
                local snowDepth = 0
                if world.getSnow then snowDepth = world.getSnow(nx, ny, cur.d) end

                local moveCost = 1
                -- Tile movement penalty (marsh, etc.) when the caller exposes
                -- tile lookup. Test worlds and lightweight proxies may only
                -- implement bounds + walkability.
                if world.getTile then
                    local _Tiles2 = require('src.world.tiles')
                    local nTile = world.getTile(nx, ny, cur.d)
                    local nProps = _Tiles2.get(nTile)
                    if nProps and nProps.movePenalty then
                        moveCost = nProps.movePenalty
                    end
                end
                -- Snow biases routes toward cleared ground. Surcharges are kept
                -- SMALL on purpose: the heuristic is plain Manhattan distance
                -- (min step cost 1), so a large per-tile surcharge makes the
                -- heuristic a gross underestimate and A* degenerates into
                -- Dijkstra. During a blizzard every outdoor tile carried the
                -- surcharge, so ~93% of queries blew the MAX_NODES budget and
                -- the sim dropped from ~250 to ~17 ticks/second. Real traversal
                -- slowness is modelled by TileSnow.getMovementMult, not here.
                -- ignoreSnowCost: a colonist walking to a fire before it
                -- freezes does not care that the route is knee-deep. Dropping
                -- the surcharge also keeps the Manhattan heuristic tight, which
                -- is what lets these long emergency routes finish inside the
                -- node budget during a blizzard (when every outdoor tile
                -- carries a surcharge and A* otherwise degenerates).
                if not opts.ignoreSnowCost then
                    if snowDepth >= 7 then moveCost = moveCost + 3
                    elseif snowDepth >= 5 then moveCost = moveCost + 2
                    elseif snowDepth >= 3 then moveCost = moveCost + 1
                    end
                end
                if respectHazards then
                    moveCost = moveCost + getWaterHazardCost(world, nx, ny, cur.d)
                    moveCost = moveCost + getGasHazardCost(world, nx, ny, cur.d)
                end

                if moverId and Occupancy.isOccupiedBy(nx, ny, moverId, cur.d) then
                    if not (nx == gx and ny == gy and cur.d == gd) then
                        moveCost = moveCost + 10
                    end
                end

                local tentG = gScore[ck] + moveCost
                if not gScore[nk] or tentG < gScore[nk] then
                    cameFrom[nk] = ck
                    gScore[nk] = tentG
                    fScore[nk] = tentG + heuristic(nx, ny, cur.d)
                    if not openMap[nk] then
                        heapPush({ x = nx, y = ny, d = cur.d, k = nk })
                        openMap[nk] = true
                    end
                end

                ::skip_neighbor::
            end
        end

        -- Vertical transitions: stairs, ramps, shafts (not channels — unwalkable)
        if world.getVerticalTargets then
            local upDepth, downDepth = world.getVerticalTargets(cur.x, cur.y, cur.d)
            for _, targetDepth in pairs({ upDepth, downDepth }) do
                if targetDepth then
                    local nk = key(cur.x, cur.y, targetDepth)
                    if not closed[nk] and world.isWalkable(cur.x, cur.y, targetDepth)
                        and tileAllowed(cur.x, cur.y, targetDepth) then
                        -- Ramps cost 2, stairs/shafts cost 3
                        local curTile = world.getTile and world.getTile(cur.x, cur.y, cur.d)
                        local _Tiles = require('src.world.tiles')
                        local moveCost = (_Tiles and curTile == _Tiles.RAMP_UP) and 2 or 3
                        local tentG = gScore[ck] + moveCost
                        if not gScore[nk] or tentG < gScore[nk] then
                            cameFrom[nk] = ck
                            gScore[nk] = tentG
                            fScore[nk] = tentG + heuristic(cur.x, cur.y, targetDepth)
                            if not openMap[nk] then
                                heapPush({ x = cur.x, y = cur.y, d = targetDepth, k = nk })
                                openMap[nk] = true
                            end
                        end
                    end
                end
            end
        end
    end

    Pathfind.lastFail = 'unreachable'
    return nil
end

return Pathfind
