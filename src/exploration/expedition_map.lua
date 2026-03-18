-- expedition_map.lua — Procedural mini-tilemap for visual expeditions
-- Generates 48x48 maps with POIs. Colonists physically explore them.
-- Map is a standalone data structure, not the World tilemap singleton.

local Pathfind = require('src.util.pathfind')

local ExpMap = {}

---------------------------------------------------------------------------
-- Tile constants
---------------------------------------------------------------------------

local T = {
    WALL  = 0,
    FLOOR = 1,
    ICE   = 2,  -- walkable, cosmetic
    ROCK  = 3,  -- impassable obstacle
}
ExpMap.TILES = T

---------------------------------------------------------------------------
-- Destination → template mapping
---------------------------------------------------------------------------

local TEMPLATE_MAP = {
    frozen_wastes     = 'open',
    wolf_den          = 'open',
    glacier_peak      = 'open',
    thermal_vents     = 'open',
    ice_caves         = 'cave',
    deep_rift         = 'cave',
    abandoned_outpost = 'ruins',
    ancient_ruins     = 'ruins',
}

---------------------------------------------------------------------------
-- Map data structure
---------------------------------------------------------------------------

-- Creates a blank map table.
local function createMap(w, h)
    local map = {
        w     = w,
        h     = h,
        tiles = {},  -- [y][x] = tile id
        fog   = {},  -- [y][x] = true if revealed
        pois  = {},  -- { {x, y, type, resolved, data}, ... }
        explorers = {},  -- { {x, y, targetPoi, path, pathIdx, moveTimer, entityId, name}, ... }
        log   = {},  -- { {text, time}, ... }
        elapsed = 0,
        completed = false,
        outcome = nil,  -- 'success'|'partial'|'failure' once objective resolved
        lootCollected = {},  -- { {itemId, amount}, ... }
        encountersWon = 0,
        encountersLost = 0,
    }
    for y = 0, h - 1 do
        map.tiles[y] = {}
        map.fog[y] = {}
        for x = 0, w - 1 do
            map.tiles[y][x] = T.WALL
            map.fog[y][x] = false
        end
    end
    return map
end

---------------------------------------------------------------------------
-- Map proxy for Pathfind.find() — dot-call compatible
---------------------------------------------------------------------------

local function makeProxy(map)
    local proxy = {}
    function proxy.width() return map.w end
    function proxy.height() return map.h end
    function proxy.inBounds(x, y)
        return x >= 0 and x < map.w and y >= 0 and y < map.h
    end
    function proxy.isWalkable(x, y)
        if x < 0 or x >= map.w or y < 0 or y >= map.h then return false end
        local t = map.tiles[y][x]
        return t == T.FLOOR or t == T.ICE
    end
    return proxy
end

---------------------------------------------------------------------------
-- Fog reveal (3-tile radius around explorer)
---------------------------------------------------------------------------

local function revealAround(map, cx, cy, radius)
    radius = radius or 3
    for dy = -radius, radius do
        for dx = -radius, radius do
            local x, y = cx + dx, cy + dy
            if x >= 0 and x < map.w and y >= 0 and y < map.h then
                if dx * dx + dy * dy <= radius * radius then
                    map.fog[y][x] = true
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Generation: Open template (tundra, scattered rocks/ice)
---------------------------------------------------------------------------

local function genOpen(map)
    local w, h = map.w, map.h
    -- Fill with floor
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            map.tiles[y][x] = T.FLOOR
        end
    end
    -- Border walls
    for y = 0, h - 1 do
        map.tiles[y][0] = T.WALL
        map.tiles[y][w - 1] = T.WALL
    end
    for x = 0, w - 1 do
        map.tiles[0][x] = T.WALL
        map.tiles[h - 1][x] = T.WALL
    end
    -- Scatter rock clusters
    local clusters = 8 + math.random(6)
    for _ = 1, clusters do
        local cx = 3 + math.random(w - 7)
        local cy = 3 + math.random(h - 7)
        local size = 1 + math.random(3)
        for dy = -size, size do
            for dx = -size, size do
                if math.random() < 0.6 and dx * dx + dy * dy <= size * size then
                    local x, y = cx + dx, cy + dy
                    if x > 1 and x < w - 2 and y > 1 and y < h - 2 then
                        map.tiles[y][x] = T.ROCK
                    end
                end
            end
        end
    end
    -- Scatter ice patches
    local icePatches = 5 + math.random(4)
    for _ = 1, icePatches do
        local cx = 2 + math.random(w - 5)
        local cy = 2 + math.random(h - 5)
        local size = 2 + math.random(2)
        for dy = -size, size do
            for dx = -size, size do
                local x, y = cx + dx, cy + dy
                if x > 0 and x < w - 1 and y > 0 and y < h - 1 then
                    if map.tiles[y][x] == T.FLOOR and math.random() < 0.5 then
                        map.tiles[y][x] = T.ICE
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Generation: Cave template (cellular automata)
---------------------------------------------------------------------------

local function genCave(map)
    local w, h = map.w, map.h
    -- Seed random fill (45% wall)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if x == 0 or x == w - 1 or y == 0 or y == h - 1 then
                map.tiles[y][x] = T.WALL
            else
                map.tiles[y][x] = math.random() < 0.45 and T.WALL or T.FLOOR
            end
        end
    end
    -- 5 iterations of cellular automata
    for _ = 1, 5 do
        local next = {}
        for y = 0, h - 1 do
            next[y] = {}
            for x = 0, w - 1 do
                if x == 0 or x == w - 1 or y == 0 or y == h - 1 then
                    next[y][x] = T.WALL
                else
                    local walls = 0
                    for dy = -1, 1 do
                        for dx = -1, 1 do
                            if map.tiles[y + dy][x + dx] == T.WALL then
                                walls = walls + 1
                            end
                        end
                    end
                    next[y][x] = walls >= 5 and T.WALL or T.FLOOR
                end
            end
        end
        map.tiles = next
    end
    -- Scatter ice in open areas
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            if map.tiles[y][x] == T.FLOOR and math.random() < 0.08 then
                map.tiles[y][x] = T.ICE
            end
        end
    end
end

---------------------------------------------------------------------------
-- Generation: Ruins template (rooms and corridors)
---------------------------------------------------------------------------

local function genRuins(map)
    local w, h = map.w, map.h
    -- Start with all walls
    -- Carve rooms
    local rooms = {}
    local attempts = 0
    while #rooms < 8 and attempts < 80 do
        attempts = attempts + 1
        local rw = 4 + math.random(5)
        local rh = 4 + math.random(5)
        local rx = 2 + math.random(w - rw - 4)
        local ry = 2 + math.random(h - rh - 4)
        -- Check overlap
        local overlap = false
        for _, r in ipairs(rooms) do
            if rx < r.x + r.w + 1 and rx + rw + 1 > r.x and
               ry < r.y + r.h + 1 and ry + rh + 1 > r.y then
                overlap = true
                break
            end
        end
        if not overlap then
            rooms[#rooms + 1] = { x = rx, y = ry, w = rw, h = rh }
            for dy = 0, rh - 1 do
                for dx = 0, rw - 1 do
                    map.tiles[ry + dy][rx + dx] = T.FLOOR
                end
            end
        end
    end
    -- Connect rooms with corridors
    for i = 2, #rooms do
        local a = rooms[i - 1]
        local b = rooms[i]
        local ax = math.floor(a.x + a.w / 2)
        local ay = math.floor(a.y + a.h / 2)
        local bx = math.floor(b.x + b.w / 2)
        local by = math.floor(b.y + b.h / 2)
        -- L-shaped corridor
        local cx = ax
        while cx ~= bx do
            if cx >= 0 and cx < w and ay >= 0 and ay < h then
                map.tiles[ay][cx] = T.FLOOR
            end
            cx = cx + (bx > ax and 1 or -1)
        end
        local cy = ay
        while cy ~= by do
            if bx >= 0 and bx < w and cy >= 0 and cy < h then
                map.tiles[cy][bx] = T.FLOOR
            end
            cy = cy + (by > ay and 1 or -1)
        end
    end
    -- Scatter debris (ice tiles) in corridors
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            if map.tiles[y][x] == T.FLOOR and math.random() < 0.05 then
                map.tiles[y][x] = T.ICE
            end
        end
    end
end

---------------------------------------------------------------------------
-- Find a walkable tile near a target position
---------------------------------------------------------------------------

local function findWalkableNear(map, cx, cy, radius)
    radius = radius or 8
    for r = 0, radius do
        for dy = -r, r do
            for dx = -r, r do
                local x, y = cx + dx, cy + dy
                if x >= 0 and x < map.w and y >= 0 and y < map.h then
                    if map.tiles[y][x] == T.FLOOR or map.tiles[y][x] == T.ICE then
                        return x, y
                    end
                end
            end
        end
    end
    return cx, cy
end

---------------------------------------------------------------------------
-- POI placement
---------------------------------------------------------------------------

local function placePOIs(map, risk, destId)
    local w, h = map.w, map.h
    -- Entrance at bottom-center
    local ex, ey = findWalkableNear(map, math.floor(w / 2), h - 3)
    map.pois[#map.pois + 1] = {
        x = ex, y = ey, type = 'entrance', resolved = true, data = {},
    }

    -- Objective at top area
    local ox, oy = findWalkableNear(map, math.floor(w / 2), 3)
    map.pois[#map.pois + 1] = {
        x = ox, y = oy, type = 'objective', resolved = false,
        data = { risk = risk, destId = destId },
    }

    -- Loot caches (2 + risk)
    local lootCount = 2 + math.min(risk, 3)
    for _ = 1, lootCount do
        local lx = 3 + math.random(w - 7)
        local ly = 3 + math.random(h - 7)
        lx, ly = findWalkableNear(map, lx, ly)
        map.pois[#map.pois + 1] = {
            x = lx, y = ly, type = 'loot', resolved = false, data = {},
        }
    end

    -- Encounters (risk-1, min 0)
    local encCount = math.max(0, risk - 1)
    for _ = 1, encCount do
        local ex2 = 3 + math.random(w - 7)
        local ey2 = 3 + math.random(h - 7)
        ex2, ey2 = findWalkableNear(map, ex2, ey2)
        map.pois[#map.pois + 1] = {
            x = ex2, y = ey2, type = 'encounter', resolved = false,
            data = { strength = 3 + risk * 2 },
        }
    end
end

---------------------------------------------------------------------------
-- Public: Generate a map for a given destination
---------------------------------------------------------------------------

function ExpMap.generate(destId, risk, memberIds, memberNames)
    local SIZE = 48
    local map = createMap(SIZE, SIZE)
    local template = TEMPLATE_MAP[destId] or 'open'

    if template == 'cave' then
        genCave(map)
    elseif template == 'ruins' then
        genRuins(map)
    else
        genOpen(map)
    end

    placePOIs(map, risk, destId)
    map.proxy = makeProxy(map)
    map.destId = destId
    map.risk = risk

    -- Place explorers at entrance
    local entrance = map.pois[1]
    for i, id in ipairs(memberIds) do
        local ox = (i - 1) % 3 - 1  -- spread: -1, 0, 1
        local sx, sy = findWalkableNear(map, entrance.x + ox, entrance.y)
        map.explorers[#map.explorers + 1] = {
            x = sx, y = sy,
            targetPoi = nil,
            path = nil,
            pathIdx = 1,
            moveTimer = 0,
            entityId = id,
            name = memberNames[i] or ('Colonist ' .. i),
        }
    end

    -- Reveal around entrance
    revealAround(map, entrance.x, entrance.y, 4)

    map.log[#map.log + 1] = { text = 'Expedition party enters the area.', time = 0 }

    return map
end

---------------------------------------------------------------------------
-- POI resolution
---------------------------------------------------------------------------

local function resolveLoot(map, poi, explorer)
    if poi.resolved then return end
    poi.resolved = true
    -- Roll 1-2 small rewards
    local rolls = 1 + math.random(1)
    local possibleItems = { 'wood', 'stone', 'metal', 'food', 'fuel', 'components', 'thermalCores' }
    for _ = 1, rolls do
        local item = possibleItems[math.random(#possibleItems)]
        local amt = 1 + math.random(3 + map.risk)
        map.lootCollected[#map.lootCollected + 1] = { itemId = item, amount = amt }
    end
    map.log[#map.log + 1] = {
        text = explorer.name .. ' found a supply cache!',
        time = map.elapsed,
    }
end

local function resolveEncounter(map, poi, explorer, partySize)
    if poi.resolved then return end
    poi.resolved = true
    local strength = poi.data.strength or 5
    -- Simple combat roll: party size * random(3-8) vs strength * random(2-6)
    local partyRoll = partySize * math.random(3, 8)
    local enemyRoll = strength * math.random(2, 6)
    if partyRoll >= enemyRoll then
        map.encountersWon = map.encountersWon + 1
        map.log[#map.log + 1] = {
            text = 'Hostile creatures defeated!',
            time = map.elapsed,
        }
        -- Bonus loot from encounter
        map.lootCollected[#map.lootCollected + 1] = {
            itemId = 'thermalCores', amount = 1 + math.random(map.risk),
        }
    else
        map.encountersLost = map.encountersLost + 1
        map.log[#map.log + 1] = {
            text = explorer.name .. ' was wounded in combat!',
            time = map.elapsed,
        }
    end
end

local function resolveObjective(map, poi, explorer, partySize)
    if poi.resolved then return end
    poi.resolved = true
    local risk = poi.data.risk or 3
    local roll = math.random(1, 10) + partySize
    if roll > risk + 2 then
        map.outcome = 'success'
        map.log[#map.log + 1] = {
            text = 'Objective secured! Expedition successful!',
            time = map.elapsed,
        }
    elseif roll > risk - 2 then
        map.outcome = 'partial'
        map.log[#map.log + 1] = {
            text = 'Partial success — returning with what we found.',
            time = map.elapsed,
        }
    else
        map.outcome = 'failure'
        map.log[#map.log + 1] = {
            text = 'Objective too dangerous. Retreating.',
            time = map.elapsed,
        }
    end
    map.completed = true
end

---------------------------------------------------------------------------
-- Find nearest unresolved POI for an explorer
---------------------------------------------------------------------------

local function findNearestPoi(map, ex, ey)
    local best = nil
    local bestDist = math.huge
    -- Prioritize: loot/encounter first, then objective (go to objective last)
    for _, poi in ipairs(map.pois) do
        if not poi.resolved and poi.type ~= 'entrance' then
            local dx = poi.x - ex
            local dy = poi.y - ey
            local dist = dx * dx + dy * dy
            -- Bias objective to be visited last: add large penalty
            if poi.type == 'objective' then
                -- Only target objective if no other unresolved POIs remain
                local othersExist = false
                for _, p2 in ipairs(map.pois) do
                    if not p2.resolved and p2.type ~= 'entrance' and p2.type ~= 'objective' then
                        othersExist = true
                        break
                    end
                end
                if othersExist then
                    dist = dist + 99999
                end
            end
            if dist < bestDist then
                bestDist = dist
                best = poi
            end
        end
    end
    return best
end

---------------------------------------------------------------------------
-- Step simulation — move explorers, resolve POIs
---------------------------------------------------------------------------

local MOVE_INTERVAL = 0.15  -- seconds between tile moves

function ExpMap.step(map, dt)
    if map.completed then return end

    map.elapsed = map.elapsed + dt
    local partySize = #map.explorers

    for _, exp in ipairs(map.explorers) do
        -- Assign target if none
        if not exp.targetPoi then
            exp.targetPoi = findNearestPoi(map, exp.x, exp.y)
            exp.path = nil
        end

        -- Path to target
        if exp.targetPoi and not exp.path then
            local route = Pathfind.find(exp.x, exp.y, exp.targetPoi.x, exp.targetPoi.y, map.proxy)
            if route and #route > 0 then
                exp.path = route
                exp.pathIdx = 1
            else
                -- Can't reach — mark resolved to skip
                exp.targetPoi.resolved = true
                exp.targetPoi = nil
            end
        end

        -- Move along path
        if exp.path and exp.pathIdx <= #exp.path then
            exp.moveTimer = exp.moveTimer + dt
            while exp.moveTimer >= MOVE_INTERVAL and exp.pathIdx <= #exp.path do
                exp.moveTimer = exp.moveTimer - MOVE_INTERVAL
                local node = exp.path[exp.pathIdx]
                exp.x = node.x
                exp.y = node.y
                exp.pathIdx = exp.pathIdx + 1
                revealAround(map, exp.x, exp.y, 3)
            end
        end

        -- Check if reached target POI
        if exp.targetPoi and exp.x == exp.targetPoi.x and exp.y == exp.targetPoi.y then
            local poi = exp.targetPoi
            if poi.type == 'loot' then
                resolveLoot(map, poi, exp)
            elseif poi.type == 'encounter' then
                resolveEncounter(map, poi, exp, partySize)
            elseif poi.type == 'objective' then
                resolveObjective(map, poi, exp, partySize)
            end
            exp.targetPoi = nil
            exp.path = nil
        end

        -- If path exhausted but target not reached, clear and re-acquire
        if exp.path and exp.pathIdx > #exp.path and exp.targetPoi then
            exp.path = nil
        end
    end

    -- Auto-complete if all POIs resolved but no objective reached
    local allResolved = true
    for _, poi in ipairs(map.pois) do
        if not poi.resolved and poi.type ~= 'entrance' then
            allResolved = false
            break
        end
    end
    if allResolved and not map.completed then
        map.completed = true
        if not map.outcome then
            map.outcome = 'partial'
            map.log[#map.log + 1] = {
                text = 'Area fully explored. Returning to colony.',
                time = map.elapsed,
            }
        end
    end
end

---------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------

function ExpMap.serialize(map)
    if not map then return nil end
    return {
        w = map.w, h = map.h,
        tiles = map.tiles,
        fog = map.fog,
        pois = map.pois,
        explorers = map.explorers,
        log = map.log,
        elapsed = map.elapsed,
        completed = map.completed,
        outcome = map.outcome,
        lootCollected = map.lootCollected,
        encountersWon = map.encountersWon,
        encountersLost = map.encountersLost,
        destId = map.destId,
        risk = map.risk,
    }
end

function ExpMap.deserialize(saved)
    if not saved then return nil end
    local map = saved
    map.proxy = makeProxy(map)
    return map
end

return ExpMap
