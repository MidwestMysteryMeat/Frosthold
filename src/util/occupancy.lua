-- occupancy.lua — Tracks which tiles are occupied by entities
-- Rebuilt each sim tick from entity positions.
-- Used by pathfinding (avoid occupied tiles) and movement (block final step).
-- Depth-aware: key encodes (x, y, depth) for multi-layer support.

local ECS = require('src.ecs.ecs')

local Occupancy = {}

local occupied = {}  -- { [key] = entityId }

-- Key encoding: depth * 100_000_000 + y * 10_000 + x
-- Matches pathfind.lua encoding. Supports x,y up to 9999, depth up to ~90.
local function key(x, y, d)
    return (d or 0) * 100000000 + y * 10000 + x
end

function Occupancy.rebuild()
    -- Wipe by replacing with empty table (faster than nil-ing keys for sparse tables)
    occupied = {}
    for id, comps in ECS.query('pos', 'colonist') do
        local col = comps.colonist
        if col.state ~= 'dead' then
            local pos = comps.pos
            occupied[key(pos.x, pos.y, pos.depth)] = id
        end
    end
    for id, comps in ECS.query('pos', 'creature') do
        local cr = comps.creature
        if cr.state ~= 'dead' then
            local pos = comps.pos
            occupied[key(pos.x, pos.y, pos.depth)] = id
        end
    end
end

function Occupancy.isOccupied(x, y, depth)
    return occupied[key(x, y, depth)] ~= nil
end

function Occupancy.getAt(x, y, depth)
    return occupied[key(x, y, depth)]
end

-- Check if tile is occupied by someone other than the given entity
function Occupancy.isOccupiedBy(x, y, excludeId, depth)
    local eid = occupied[key(x, y, depth)]
    return eid ~= nil and eid ~= excludeId
end

-- Reserve a tile for an entity (called when movement commits)
function Occupancy.reserve(x, y, entityId, depth)
    occupied[key(x, y, depth)] = entityId
end

-- Release a tile
function Occupancy.release(x, y, entityId, depth)
    local k = key(x, y, depth)
    if occupied[k] == entityId then
        occupied[k] = nil
    end
end

return Occupancy
