-- decorations.lua -- Room decoration buildings
-- Decorations are ECS entities with a 'decoration' component.
-- Beauty values improve room quality when placed inside enclosed rooms.
-- Placed via the same building placement pattern as other structures.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')

local Decorations = {}

---------------------------------------------------------------------------
-- Decoration definitions
---------------------------------------------------------------------------

Decorations.defs = {
    shelf = {
        name   = 'Shelf',
        beauty = 2,
        cost   = { wood = 2 },
        tile   = nil,  -- does not change tile, placed on existing floor
    },
    rug = {
        name   = 'Rug',
        beauty = 3,
        cost   = { cloth = 3 },
        tile   = nil,
    },
    painting = {
        name   = 'Painting',
        beauty = 5,
        cost   = { wood = 1, dye = 2 },
        tile   = nil,
    },
    trophy_mount = {
        name   = 'Trophy Mount',
        beauty = 8,
        cost   = { wood = 1, thermal_core = 1 },
        tile   = nil,
    },
}

---------------------------------------------------------------------------
-- Placement (mirrors building.lua pattern)
---------------------------------------------------------------------------

function Decorations.tryPlace(defId, x, y, depth)
    local def = Decorations.defs[defId]
    if not def then return false, 'Unknown decoration' end

    depth = depth or 0
    local World = require('src.world.tilemap')

    -- Must be in bounds and on walkable floor
    if not World.inBounds(x, y) then return false, 'Out of bounds' end
    if not World.isWalkable(x, y, depth) then return false, 'Must place on floor' end

    -- Cannot stack decorations on the same tile
    for _, comps in ECS.query('pos', 'decoration') do
        if comps.pos.x == x and comps.pos.y == y and (comps.pos.depth or 0) == depth then
            return false, 'Tile already has a decoration'
        end
    end

    -- Check cost against GameState.resources
    -- 'cloth', 'dye', and 'thermal_core' may map to the resource bag differently.
    -- The resource bag uses: wood, stone, metal, food, fuel, thermalCores, components
    -- Map decoration costs to the resource names.
    local costMap = {
        wood          = 'wood',
        cloth         = 'components',   -- cloth proxied through components for now
        dye           = 'food',         -- dye proxied through food (placeholder)
        thermal_core  = 'thermalCores',
    }

    for res, amount in pairs(def.cost) do
        local mapped = costMap[res] or res
        if (GameState.resources[mapped] or 0) < amount then
            return false, 'Not enough ' .. res
        end
    end

    -- Spend resources
    for res, amount in pairs(def.cost) do
        local mapped = costMap[res] or res
        GameState.resources[mapped] = GameState.resources[mapped] - amount
    end

    -- Spawn decoration entity
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth, prevX = x, prevY = y })
    ECS.set(id, 'decoration', {
        type   = defId,
        name   = def.name,
        beauty = def.beauty,
    })

    return true
end

function Decorations.remove(x, y)
    for id, comps in ECS.query('pos', 'decoration') do
        if comps.pos.x == x and comps.pos.y == y then
            ECS.destroy(id)
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Room beauty calculation
---------------------------------------------------------------------------

-- Sum beauty of all decorations inside a given set of tile positions.
-- tileSet: { [tileKey] = true } where tileKey = y * mapW + x
-- mapW: map width for index computation
function Decorations.sumBeautyInRoom(tileSet, mapW)
    local total = 0
    for id, comps in ECS.query('pos', 'decoration') do
        local px, py = comps.pos.x, comps.pos.y
        local idx = py * mapW + px + 1
        if tileSet[idx] then
            total = total + comps.decoration.beauty
        end
    end
    return total
end

-- Get room quality bonus: total beauty / room tile count.
-- roomTiles: array of tile indices (as from thermal room.tiles)
-- mapW: map width
function Decorations.roomQualityBonus(roomTiles, mapW)
    if not roomTiles or #roomTiles == 0 then return 0 end
    local tileSet = {}
    for _, idx in ipairs(roomTiles) do
        tileSet[idx] = true
    end
    local beauty = Decorations.sumBeautyInRoom(tileSet, mapW)
    return beauty / #roomTiles
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Decorations.getAt(x, y)
    for id, comps in ECS.query('pos', 'decoration') do
        if comps.pos.x == x and comps.pos.y == y then
            return id, comps.decoration
        end
    end
    return nil
end

function Decorations.getDefs()
    return Decorations.defs
end

return Decorations
