-- NOTE: art/audio are NOT in the repo — they are owner-licensed packs
-- stripped from version control (see assets/ASSETS_PLACEHOLDER.md).
-- Loaders below must tolerate missing files on fresh clones.
-- sprites.lua — Sprite loader and cache
-- Lazy-loads PNGs from assets/sprites/, caches Love2D Image objects.
-- Provides mapping from game IDs (tile types, species, items) to sprites.

local Tiles = require('src.world.tiles')

local Sprites = {}

local cache = {}       -- path → Love2D Image
local SPRITE_ROOT = 'assets/sprites/'

---------------------------------------------------------------------------
-- Core loader
---------------------------------------------------------------------------

local function loadSprite(subdir, filename)
    local path = SPRITE_ROOT .. subdir .. '/' .. filename .. '.png'
    if cache[path] then return cache[path] end

    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
        img:setFilter('nearest', 'nearest')
        cache[path] = img
        return img
    end
    cache[path] = false  -- mark as missing so we don't retry
    return nil
end

--- Get a sprite by subdirectory and name. Returns Image or nil.
function Sprites.get(subdir, name)
    if not name then return nil end
    local cached = cache[SPRITE_ROOT .. subdir .. '/' .. name .. '.png']
    if cached == false then return nil end
    if cached then return cached end
    return loadSprite(subdir, name)
end

---------------------------------------------------------------------------
-- Tile sprites
---------------------------------------------------------------------------

-- Map tile enum → sprite filename
-- Tiles whose sliced sprites have checkerboard artifacts are omitted
-- so the renderer falls back to colored shapes for them.
local TILE_SPRITE = {
    [Tiles.VOID]            = 'void',
    [Tiles.SNOW]            = 'snow',
    [Tiles.ICE]             = 'ice',
    [Tiles.ROCK]            = 'rock',
    [Tiles.PERMAFROST]      = 'permafrost',
    [Tiles.DIRT]            = 'dirt',
    [Tiles.FLOOR_WOOD]      = 'floor_wood',
    [Tiles.FLOOR_STONE]     = 'floor_stone',
    [Tiles.FLOOR_METAL]     = 'floor_metal',
    [Tiles.WALL_WOOD]       = 'wall_wood',
    [Tiles.WALL_STONE]      = 'wall_stone',
    [Tiles.WALL_METAL]      = 'wall_metal',
    [Tiles.DOOR]            = 'door',
    [Tiles.WATER]           = 'water_tile',
    [Tiles.LAVA_VENT]       = 'lava_vent',
    [Tiles.DEBRIS]          = 'debris',
    -- ORE_VEIN omitted: source art too gray, checkerboard survives slicing
    [Tiles.WALL_INSULATED]  = 'wall_insulated',
    [Tiles.FLOOR_INSULATED] = 'floor_insulated',
    [Tiles.DOOR_SEALED]     = 'door_sealed',
    -- Expanded biomes
    [Tiles.FROZEN_LAKE]     = 'frozen_lake',
    [Tiles.FROZEN_SEA]      = 'frozen_sea',
    [Tiles.CAVE_ENTRANCE]   = 'cave_entrance',
    [Tiles.TUNDRA_MARSH]    = 'tundra_marsh',
    [Tiles.VOLCANIC_ROCK]   = 'volcanic_rock',
    [Tiles.VOLCANIC_FLOOR]  = 'volcanic_floor',
    [Tiles.DEAD_TREE]       = 'dead_tree',
    [Tiles.ASH_GROUND]      = 'ash_ground',
}

-- Tree tiles alternate between tree_1 and tree_2 based on position hash
local TREE_SPRITES = { 'tree_1', 'tree_2' }

--- Get tile sprite. Returns Image or nil.
function Sprites.getTile(tileType, tileX, tileY)
    if tileType == Tiles.TREE then
        -- Deterministic variation based on position
        local idx = ((tileX or 0) * 7 + (tileY or 0) * 13) % #TREE_SPRITES + 1
        return Sprites.get('tiles', TREE_SPRITES[idx])
    end
    local name = TILE_SPRITE[tileType]
    if not name then return nil end
    return Sprites.get('tiles', name)
end

---------------------------------------------------------------------------
-- Creature sprites
---------------------------------------------------------------------------

--- Get creature sprite by species name. Returns Image or nil.
function Sprites.getCreature(species)
    return Sprites.get('creatures', species)
end

---------------------------------------------------------------------------
-- Colonist sprites
---------------------------------------------------------------------------

-- Map col.state string to sprite filename
local STATE_SPRITE = {
    sleeping      = 'sleeping',
    dead          = 'dead',
    eating        = 'eating',
    mental_break  = 'mental_break',
    working       = 'working',
    moving_to_task= 'walking',
    going_to_bed  = 'walking',
    wandering     = 'walking',
    fighting      = 'armed_melee',
    fleeing       = 'walking',
    idle          = 'idle',
}

-- Map task type to more specific sprite when state == 'working'
local TASK_SPRITE = {
    mine     = 'mining',
    build    = 'building_col',
    cook     = 'cooking',
    research = 'researching',
    medical  = 'medical',
    treat    = 'medical',
    haul     = 'carrying',
    hunt     = 'armed_ranged',
    clean    = 'working',
    operate  = 'working',
}

--- Determine colonist visual state from col component + optional task type.
function Sprites.getColonistState(col, taskType)
    -- Priority overrides
    if col.state == 'dead' then return 'dead' end
    if col.mentalBreak then return 'mental_break' end
    if col.hypothermiaStage and col.hypothermiaStage >= 3 then return 'freezing' end

    -- When working, use task-specific sprite if available
    if col.state == 'working' and taskType then
        return TASK_SPRITE[taskType] or 'working'
    end

    return STATE_SPRITE[col.state] or 'idle'
end

--- Get colonist sprite by state name (already mapped to filename).
--- Returns Image or nil.
function Sprites.getColonist(stateName)
    return Sprites.get('colonists', stateName or 'idle')
end

---------------------------------------------------------------------------
-- Item sprites
---------------------------------------------------------------------------

--- Get item sprite by item name. Returns Image or nil.
function Sprites.getItem(itemName)
    return Sprites.get('items', itemName)
end

---------------------------------------------------------------------------
-- Building entity sprites (machines, turrets, traps, beds, etc.)
---------------------------------------------------------------------------

--- Get building sprite by building def ID. Returns Image or nil.
function Sprites.getBuilding(defId)
    return Sprites.get('buildings', defId)
end

---------------------------------------------------------------------------
-- Defense sprites (turrets, traps, barriers)
---------------------------------------------------------------------------

--- Get defense sprite by type ID. Returns Image or nil.
function Sprites.getDefense(typeId)
    return Sprites.get('defense', typeId)
end

---------------------------------------------------------------------------
-- UI icon sprites
---------------------------------------------------------------------------

--- Get UI icon sprite. Returns Image or nil.
function Sprites.getUI(name)
    return Sprites.get('ui', name)
end

---------------------------------------------------------------------------
-- Weapon sprites
---------------------------------------------------------------------------

--- Get weapon sprite. Returns Image or nil.
function Sprites.getWeapon(name)
    return Sprites.get('weapons', name)
end

---------------------------------------------------------------------------
-- Crop sprites
---------------------------------------------------------------------------

--- Get crop sprite. Returns Image or nil.
function Sprites.getCrop(name)
    return Sprites.get('crops', name)
end

---------------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------------

function Sprites.preloadTiles()
    for tileType, name in pairs(TILE_SPRITE) do
        Sprites.get('tiles', name)
    end
    for _, name in ipairs(TREE_SPRITES) do
        Sprites.get('tiles', name)
    end
end

function Sprites.getCacheSize()
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    return count
end

return Sprites
