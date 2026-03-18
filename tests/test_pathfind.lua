-- test_pathfind.lua — A* pathfinding tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Pathfinding')

-- Minimal world interface matching what Pathfind.find() expects:
-- world.isWalkable(x, y), world.inBounds(x, y)
local function makeGrid(w, h, blockedSet)
    blockedSet = blockedSet or {}
    local blocked = {}
    for _, pos in ipairs(blockedSet) do
        blocked[pos.y * 10000 + pos.x] = true
    end
    return {
        w = w,
        h = h,
        isWalkable = function(x, y)
            if x < 0 or x >= w or y < 0 or y >= h then return false end
            return not blocked[y * 10000 + x]
        end,
        inBounds = function(x, y)
            return x >= 0 and x < w and y >= 0 and y < h
        end,
    }
end

T.test('find returns empty table for same start and goal', function()
    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(10, 10)

    local path = Pathfind.find(5, 5, 5, 5, world)
    T.notnil(path, 'path is not nil')
    T.tablelen(path, 0, 'empty path for same start/goal')
end)

T.test('find returns nil when goal is unwalkable', function()
    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(10, 10, { { x = 8, y = 8 } })

    local path = Pathfind.find(0, 0, 8, 8, world)
    T.isnil(path, 'nil for unwalkable goal')
end)

T.test('find returns path for straight-line reachable goal', function()
    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(10, 10)

    local path = Pathfind.find(0, 0, 3, 0, world)
    T.notnil(path, 'path exists')
    T.ok(#path > 0, 'path has nodes')

    -- Last node should be the goal
    local last = path[#path]
    T.eq(last.x, 3, 'last node x is goal x')
    T.eq(last.y, 0, 'last node y is goal y')
end)

T.test('path nodes are adjacent (no teleporting)', function()
    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(10, 10)

    local path = Pathfind.find(0, 0, 5, 5, world)
    T.notnil(path, 'path found')

    -- First node should be adjacent to start (0,0)
    local first = path[1]
    local dx = math.abs(first.x - 0)
    local dy = math.abs(first.y - 0)
    T.ok(dx + dy == 1, 'first node adjacent to start')

    -- Each subsequent pair of nodes must be adjacent (Manhattan distance 1)
    for i = 2, #path do
        local prev = path[i - 1]
        local cur = path[i]
        local step = math.abs(cur.x - prev.x) + math.abs(cur.y - prev.y)
        T.eq(step, 1, 'nodes ' .. (i - 1) .. ' and ' .. i .. ' are adjacent')
    end
end)

T.test('find returns nil when goal is completely walled off', function()
    local Pathfind = require('src.util.pathfind')

    -- Build a 10x10 grid with a wall across the middle (y=5, all x blocked)
    local blocked = {}
    for x = 0, 9 do
        blocked[#blocked + 1] = { x = x, y = 5 }
    end
    local world = makeGrid(10, 10, blocked)

    local path = Pathfind.find(0, 0, 0, 9, world)
    T.isnil(path, 'nil for unreachable goal behind wall')
end)

T.test('find navigates around obstacles', function()
    local Pathfind = require('src.util.pathfind')

    -- Partial wall from x=0 to x=3 at y=2, leaves gap at x=4
    local blocked = {}
    for x = 0, 3 do
        blocked[#blocked + 1] = { x = x, y = 2 }
    end
    local world = makeGrid(10, 10, blocked)

    local path = Pathfind.find(0, 0, 0, 4, world)
    T.notnil(path, 'path exists around obstacle')

    -- Goal reached
    local last = path[#path]
    T.eq(last.x, 0, 'reaches goal x')
    T.eq(last.y, 4, 'reaches goal y')

    -- Path should not pass through any blocked tile
    for _, node in ipairs(path) do
        T.ok(world.isWalkable(node.x, node.y), 'node (' .. node.x .. ',' .. node.y .. ') is walkable')
    end
end)

T.test('path length is optimal for open grid', function()
    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(10, 10)

    -- Manhattan distance from (0,0) to (4,3) = 7
    local path = Pathfind.find(0, 0, 4, 3, world)
    T.notnil(path, 'path found')
    T.eq(#path, 7, 'path length equals Manhattan distance on open grid')
end)

T.test('find returns nil for out-of-bounds goal', function()
    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(10, 10)

    -- Goal at (15, 15) is out of bounds, so isWalkable returns false
    local path = Pathfind.find(0, 0, 15, 15, world)
    T.isnil(path, 'nil for out-of-bounds goal')
end)

T.test('find respects allowTile restriction callback', function()
    package.loaded['src.util.pathfind'] = nil
    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(10, 10)

    local path = Pathfind.find(0, 0, 3, 0, world, nil, 0, 0, {
        allowTile = function(x, y)
            return not (x == 1 and y == 0)
        end,
    })

    T.notnil(path, 'path still exists around forbidden tile')
    for _, node in ipairs(path) do
        T.ok(not (node.x == 1 and node.y == 0), 'restricted tile avoided')
    end
end)

T.test('find respects blocking energy barriers', function()
    package.loaded['src.util.pathfind'] = nil
    package.loaded['src.combat.defenses'] = {
        isBlockingBarrierAt = function(x, y)
            return x == 1 and y == 0
        end,
    }

    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(3, 1)

    local path = Pathfind.find(0, 0, 2, 0, world)
    T.isnil(path, 'barrier blocks the only route')

    package.loaded['src.util.pathfind'] = nil
    package.loaded['src.combat.defenses'] = nil
end)

T.test('colonist pathfinding respects restricted zones', function()
    H.resetAll()
    local Zones = require('src.world.zones')
    Zones.reset()

    local moverId = H.spawnTestColonist(0, 0)

    package.loaded['src.util.pathfind'] = nil
    local Pathfind = require('src.util.pathfind')
    local world = makeGrid(4, 2)

    Zones.create('restricted', {
        { x = 0, y = 0, depth = 0 },
        { x = 1, y = 0, depth = 0 },
        { x = 2, y = 0, depth = 0 },
        { x = 3, y = 0, depth = 0 },
    })

    local allowedPath = Pathfind.find(0, 0, 3, 0, world, moverId, 0, 0)
    T.notnil(allowedPath, 'path exists inside allowed area')

    local blockedPath = Pathfind.find(0, 0, 0, 1, world, moverId, 0, 0)
    T.isnil(blockedPath, 'goal outside allowed area is rejected')

    Zones.reset()
    package.loaded['src.util.pathfind'] = nil
end)
