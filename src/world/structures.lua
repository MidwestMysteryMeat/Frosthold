-- structures.lua — Procedural pre-existing structures placed during map gen
-- Generates ruins, outposts, camps, bunkers, vaults, and compounds.
-- Modifies tileData directly during Tilemap.init().
-- Loot spawned as ground items after tile placement.

local Tiles = require('src.world.tiles')

local Structures = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function areaIs(tileData, mapW, x, y, w, h, allowed)
    for dy = 0, h - 1 do
        for dx = 0, w - 1 do
            local idx = (y + dy) * mapW + (x + dx) + 1
            local t = tileData[idx]
            local ok = false
            for _, a in ipairs(allowed) do
                if t == a then ok = true; break end
            end
            if not ok then return false end
        end
    end
    return true
end

local function areaIsRock(tileData, mapW, x, y, w, h)
    for dy = -1, h do
        for dx = -1, w do
            local idx = (y + dy) * mapW + (x + dx) + 1
            local t = tileData[idx]
            if t ~= Tiles.ROCK and t ~= Tiles.ORE_VEIN then return false end
        end
    end
    return true
end

local function farFromCenter(x, y, w, h, mapW, mapH, minDist)
    local cx, cy = math.floor(mapW / 2), math.floor(mapH / 2)
    return math.abs(x + w / 2 - cx) > minDist or math.abs(y + h / 2 - cy) > minDist
end

---------------------------------------------------------------------------
-- Room primitives
---------------------------------------------------------------------------

local function placeRoom(tileData, mapW, x, y, w, h, wallTile, floorTile)
    for dy = 0, h - 1 do
        for dx = 0, w - 1 do
            local idx = (y + dy) * mapW + (x + dx) + 1
            local isEdge = dx == 0 or dx == w - 1 or dy == 0 or dy == h - 1
            tileData[idx] = isEdge and wallTile or floorTile
        end
    end
end

local SIDES = { 'north', 'south', 'east', 'west' }

local function addDoor(tileData, mapW, x, y, w, h, side, doorTile)
    local dx, dy
    doorTile = doorTile or Tiles.DOOR
    if side == 'north' then
        dx, dy = math.random(1, w - 2), 0
    elseif side == 'south' then
        dx, dy = math.random(1, w - 2), h - 1
    elseif side == 'west' then
        dx, dy = 0, math.random(1, h - 2)
    else -- east
        dx, dy = w - 1, math.random(1, h - 2)
    end
    tileData[(y + dy) * mapW + (x + dx) + 1] = doorTile
end

local function decayWalls(tileData, mapW, x, y, w, h, fraction)
    local walls = {}
    for dy = 0, h - 1 do
        for dx = 0, w - 1 do
            local isEdge = dx == 0 or dx == w - 1 or dy == 0 or dy == h - 1
            if isEdge then
                local idx = (y + dy) * mapW + (x + dx) + 1
                local t = tileData[idx]
                if t == Tiles.WALL_WOOD or t == Tiles.WALL_STONE or t == Tiles.WALL_METAL then
                    walls[#walls + 1] = idx
                end
            end
        end
    end
    local toRemove = math.floor(#walls * fraction)
    for _ = 1, toRemove do
        if #walls == 0 then break end
        local pick = math.random(1, #walls)
        tileData[walls[pick]] = Tiles.DEBRIS
        table.remove(walls, pick)
    end
end

---------------------------------------------------------------------------
-- Loot tables
---------------------------------------------------------------------------

local LOOT = {
    ruin = {
        { item = 'metal_ingot',  min = 1, max = 4, w = 20 },
        { item = 'components',   min = 1, max = 2, w = 15 },
        { item = 'raw_stone',    min = 2, max = 6, w = 25 },
        { item = 'cloth',        min = 1, max = 3, w = 15 },
        { item = 'ammo_bullet',  min = 3, max = 10, w = 15 },
        { item = 'medicine',     min = 1, max = 2, w = 10 },
    },
    outpost = {
        { item = 'metal_ingot',       min = 2, max = 6,  w = 18 },
        { item = 'ammo_bullet',       min = 5, max = 15, w = 18 },
        { item = 'ammo_shell',        min = 2, max = 8,  w = 12 },
        { item = 'weapon_bolt_action', min = 1, max = 1, w = 5 },
        { item = 'weapon_pistol',     min = 1, max = 1,  w = 8 },
        { item = 'bandage',           min = 2, max = 5,  w = 14 },
        { item = 'components',        min = 1, max = 3,  w = 15 },
        { item = 'grenade',           min = 1, max = 2,  w = 10 },
    },
    camp = {
        { item = 'raw_wood',         min = 3, max = 8,  w = 25 },
        { item = 'raw_meat',         min = 1, max = 4,  w = 20 },
        { item = 'cloth',            min = 1, max = 3,  w = 20 },
        { item = 'weapon_knife',     min = 1, max = 1,  w = 10 },
        { item = 'weapon_shortbow',  min = 1, max = 1,  w = 10 },
        { item = 'ammo_arrow',       min = 5, max = 15, w = 15 },
    },
    bunker = {
        { item = 'steel',                min = 2, max = 5,  w = 14 },
        { item = 'circuit',              min = 1, max = 3,  w = 10 },
        { item = 'components',           min = 2, max = 5,  w = 14 },
        { item = 'weapon_assault_rifle', min = 1, max = 1,  w = 5 },
        { item = 'weapon_pump_shotgun',  min = 1, max = 1,  w = 7 },
        { item = 'ammo_bullet',          min = 10, max = 30, w = 14 },
        { item = 'medicine',             min = 2, max = 4,  w = 12 },
        { item = 'fuel_cell',            min = 1, max = 3,  w = 10 },
        { item = 'grenade',              min = 1, max = 3,  w = 9 },
        { item = 'ammo_shell',           min = 3, max = 10, w = 5 },
    },
    vault = {
        { item = 'steel',               min = 4, max = 10, w = 14 },
        { item = 'circuit',             min = 2, max = 5,  w = 14 },
        { item = 'components',          min = 3, max = 7,  w = 14 },
        { item = 'thermal_core',        min = 2, max = 6,  w = 12 },
        { item = 'weapon_battle_rifle', min = 1, max = 1,  w = 5 },
        { item = 'fuel_cell',           min = 2, max = 5,  w = 10 },
        { item = 'grenade',             min = 2, max = 5,  w = 8 },
        { item = 'medicine',            min = 3, max = 6,  w = 10 },
        { item = 'void_crystal',        min = 1, max = 2,  w = 5 },
        { item = 'ammo_rocket',         min = 1, max = 3,  w = 8 },
    },
}

local function rollLoot(tableName, rolls)
    local lt = LOOT[tableName]
    if not lt then return {} end
    local totalW = 0
    for _, e in ipairs(lt) do totalW = totalW + e.w end
    local result = {}
    for _ = 1, rolls do
        local roll = math.random() * totalW
        local cumul = 0
        for _, e in ipairs(lt) do
            cumul = cumul + e.w
            if roll <= cumul then
                result[#result + 1] = { item = e.item, count = math.random(e.min, e.max) }
                break
            end
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Structure generators
---------------------------------------------------------------------------

local OPEN = { Tiles.SNOW, Tiles.PERMAFROST, Tiles.ASH_GROUND, Tiles.VOLCANIC_FLOOR, Tiles.TUNDRA_MARSH }

local function generateRuin(tileData, mapW, mapH)
    local w, h = math.random(5, 9), math.random(5, 8)
    for _ = 1, 30 do
        local x = math.random(10, mapW - w - 10)
        local y = math.random(10, mapH - h - 10)
        if areaIs(tileData, mapW, x, y, w, h, OPEN)
           and farFromCenter(x, y, w, h, mapW, mapH, 15) then
            placeRoom(tileData, mapW, x, y, w, h, Tiles.WALL_STONE, Tiles.FLOOR_STONE)
            decayWalls(tileData, mapW, x, y, w, h, 0.4 + math.random() * 0.3)
            if math.random() > 0.4 then
                addDoor(tileData, mapW, x, y, w, h, SIDES[math.random(1, 4)])
            end
            return { type = 'ruin', x = x, y = y, w = w, h = h,
                     loot = rollLoot('ruin', math.random(2, 4)) }
        end
    end
end

local function generateOutpost(tileData, mapW, mapH)
    local w, h = math.random(6, 10), math.random(5, 8)
    for _ = 1, 30 do
        local x = math.random(10, mapW - w - 10)
        local y = math.random(10, mapH - h - 10)
        if areaIs(tileData, mapW, x, y, w, h, OPEN)
           and farFromCenter(x, y, w, h, mapW, mapH, 20) then
            placeRoom(tileData, mapW, x, y, w, h, Tiles.WALL_STONE, Tiles.FLOOR_STONE)
            decayWalls(tileData, mapW, x, y, w, h, math.random() * 0.2)
            addDoor(tileData, mapW, x, y, w, h, SIDES[math.random(1, 4)])
            return { type = 'outpost', x = x, y = y, w = w, h = h,
                     loot = rollLoot('outpost', math.random(3, 5)) }
        end
    end
end

local function generateCamp(tileData, mapW, mapH)
    local w, h = math.random(4, 6), math.random(4, 5)
    for _ = 1, 30 do
        local x = math.random(8, mapW - w - 8)
        local y = math.random(8, mapH - h - 8)
        if areaIs(tileData, mapW, x, y, w, h, OPEN)
           and farFromCenter(x, y, w, h, mapW, mapH, 12) then
            placeRoom(tileData, mapW, x, y, w, h, Tiles.WALL_WOOD, Tiles.FLOOR_WOOD)
            decayWalls(tileData, mapW, x, y, w, h, 0.6 + math.random() * 0.3)
            return { type = 'camp', x = x, y = y, w = w, h = h,
                     loot = rollLoot('camp', math.random(1, 3)) }
        end
    end
end

local function generateBunker(tileData, mapW, mapH)
    local w, h = math.random(6, 10), math.random(5, 8)
    for _ = 1, 50 do
        local x = math.random(10, mapW - w - 10)
        local y = math.random(10, mapH - h - 10)
        if areaIsRock(tileData, mapW, x, y, w, h) then
            placeRoom(tileData, mapW, x, y, w, h, Tiles.WALL_METAL, Tiles.FLOOR_METAL)
            addDoor(tileData, mapW, x, y, w, h, SIDES[math.random(1, 4)], Tiles.DOOR_SEALED)
            return { type = 'bunker', x = x, y = y, w = w, h = h,
                     loot = rollLoot('bunker', math.random(3, 6)) }
        end
    end
end

local function generateVault(tileData, mapW, mapH)
    local w, h = math.random(4, 6), math.random(4, 5)
    for _ = 1, 50 do
        local x = math.random(10, mapW - w - 10)
        local y = math.random(10, mapH - h - 10)
        if areaIsRock(tileData, mapW, x, y, w, h) then
            placeRoom(tileData, mapW, x, y, w, h, Tiles.WALL_METAL, Tiles.FLOOR_METAL)
            -- No door: completely sealed. Must mine through rock to discover.
            return { type = 'vault', x = x, y = y, w = w, h = h,
                     loot = rollLoot('vault', math.random(4, 7)) }
        end
    end
end

local function generateCompound(tileData, mapW, mapH)
    local w1, h1 = math.random(5, 8), math.random(5, 7)
    local w2, h2 = math.random(4, 7), math.random(4, 6)
    local totalW = w1 + w2 - 1
    local totalH = math.max(h1, h2)
    for _ = 1, 30 do
        local x = math.random(12, mapW - totalW - 12)
        local y = math.random(12, mapH - totalH - 12)
        if areaIs(tileData, mapW, x, y, totalW, totalH, OPEN)
           and farFromCenter(x, y, totalW, totalH, mapW, mapH, 18) then
            placeRoom(tileData, mapW, x, y, w1, h1, Tiles.WALL_STONE, Tiles.FLOOR_STONE)
            local x2 = x + w1 - 1
            placeRoom(tileData, mapW, x2, y, w2, h2, Tiles.WALL_STONE, Tiles.FLOOR_STONE)
            -- Interior door on shared wall
            local doorY = y + math.random(1, math.min(h1, h2) - 2)
            tileData[doorY * mapW + x2 + 1] = Tiles.DOOR
            -- Exterior door on room 1
            addDoor(tileData, mapW, x, y, w1, h1, 'west')
            -- Moderate decay on both rooms
            decayWalls(tileData, mapW, x, y, w1, h1, 0.1 + math.random() * 0.25)
            decayWalls(tileData, mapW, x2, y, w2, h2, 0.1 + math.random() * 0.2)
            return { type = 'compound', x = x, y = y, w = totalW, h = totalH,
                     loot = rollLoot('outpost', math.random(4, 7)) }
        end
    end
end

---------------------------------------------------------------------------
-- Main generation
---------------------------------------------------------------------------

local structureRecords = {}

local GENERATORS = {
    { gen = generateRuin,     weight = 25 },
    { gen = generateOutpost,  weight = 20 },
    { gen = generateCamp,     weight = 20 },
    { gen = generateBunker,   weight = 15 },
    { gen = generateVault,    weight = 10 },
    { gen = generateCompound, weight = 10 },
}

local totalGenWeight = 0
for _, g in ipairs(GENERATORS) do totalGenWeight = totalGenWeight + g.weight end

function Structures.generate(tileData, mapW, mapH)
    structureRecords = {}

    -- Largest generator (compound) needs a 14x7 footprint plus 12-tile margins;
    -- smaller maps make the placement intervals empty and math.random errors.
    if mapW < 40 or mapH < 40 then return end

    local area = mapW * mapH
    local target = math.max(3, math.min(12, math.floor(area / 2500) + math.random(-1, 2)))

    local placed = 0
    for _ = 1, target * 3 do
        if placed >= target then break end

        local roll = math.random() * totalGenWeight
        local cumul = 0
        for _, g in ipairs(GENERATORS) do
            cumul = cumul + g.weight
            if roll <= cumul then
                local rec = g.gen(tileData, mapW, mapH)
                if rec then
                    -- Overlap check (3-tile buffer)
                    local overlap = false
                    for _, existing in ipairs(structureRecords) do
                        if rec.x < existing.x + existing.w + 3
                           and rec.x + rec.w + 3 > existing.x
                           and rec.y < existing.y + existing.h + 3
                           and rec.y + rec.h + 3 > existing.y then
                            overlap = true
                            break
                        end
                    end
                    if not overlap then
                        structureRecords[#structureRecords + 1] = rec
                        placed = placed + 1
                    end
                end
                break
            end
        end
    end

    return structureRecords
end

---------------------------------------------------------------------------
-- Loot spawning — called after ECS/Items are ready
---------------------------------------------------------------------------

function Structures.spawnLoot()
    local ok, Items = pcall(require, 'src.world.items')
    if not ok then return end
    local ecsOk, ECS = pcall(require, 'src.ecs.ecs')
    if not ecsOk then return end

    local pOk, Production = pcall(require, 'src.building.production')

    for _, rec in ipairs(structureRecords) do
        if not rec.loot then goto next_structure end
        for _, loot in ipairs(rec.loot) do
            local lx = rec.x + math.random(1, math.max(1, rec.w - 2))
            local ly = rec.y + math.random(1, math.max(1, rec.h - 2))
            local cat = 'raw'
            if pOk and Production.ITEMS[loot.item] then
                cat = Production.ITEMS[loot.item].category
            end
            local eid = Items.spawn(lx, ly, loot.item, loot.count, cat)
            -- Structure loot doesn't decay quickly — already been here for ages
            local itemComp = ECS.get(eid, 'item')
            if itemComp then itemComp._decayTimer = 86400 end
        end
        ::next_structure::
    end
end

function Structures.getRecords()
    return structureRecords
end

return Structures
