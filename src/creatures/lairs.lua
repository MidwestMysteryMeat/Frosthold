-- lairs.lua -- Creature lair spawning and management
-- Lairs are ECS entities placed on ROCK tiles near map edges during worldgen.
-- Each lair has a creature type and periodically spawns creatures.
-- Destructible: 200 HP, can be designated for destruction (mining task).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Creatures = require('src.creatures.creatures')
local Jobs      = require('src.colonist.jobs')
local Tiles     = require('src.world.tiles')

local Lairs = {}

---------------------------------------------------------------------------
-- Lair species pool (keyed by tier for worldgen variety)
---------------------------------------------------------------------------

local LAIR_TYPES = {
    -- Basic predator lairs
    { species = 'tundra_wolf',  spawnMin = 60,  spawnMax = 90,  packMin = 2, packMax = 4 },
    { species = 'ice_stalker',  spawnMin = 80,  spawnMax = 120, packMin = 1, packMax = 2 },
    { species = 'glacier_bear', spawnMin = 90,  spawnMax = 120, packMin = 1, packMax = 1 },
    -- Advanced lairs
    { species = 'dire_wolf',    spawnMin = 70,  spawnMax = 100, packMin = 3, packMax = 6 },
    { species = 'ice_brute',  spawnMin = 120, spawnMax = 180, packMin = 1, packMax = 2 },
    { species = 'stalker',      spawnMin = 100, spawnMax = 150, packMin = 1, packMax = 1 },
    { species = 'snow_ape',         spawnMin = 90,  spawnMax = 140, packMin = 1, packMax = 2 },
    { species = 'sabertooth',   spawnMin = 80,  spawnMax = 110, packMin = 1, packMax = 2 },
    -- Thermovore lairs
    { species = 'char_hound',   spawnMin = 70,  spawnMax = 100, packMin = 2, packMax = 4 },
    { species = 'bore_beetle',  spawnMin = 100, spawnMax = 140, packMin = 1, packMax = 2 },
    { species = 'razorjaw',     spawnMin = 80,  spawnMax = 120, packMin = 1, packMax = 2 },
    { species = 'spine_lurker', spawnMin = 90,  spawnMax = 130, packMin = 1, packMax = 1 },
}

Lairs.LAIR_TYPES = LAIR_TYPES

---------------------------------------------------------------------------
-- Spawn a lair entity at a given position
---------------------------------------------------------------------------

function Lairs.spawn(x, y, lairTypeIndex)
    local lairDef = LAIR_TYPES[lairTypeIndex]
    if not lairDef then return nil end

    local id = ECS.spawn()

    ECS.set(id, 'pos', { x = x, y = y, depth = 0 })

    ECS.set(id, 'lair', {
        species    = lairDef.species,
        health     = 200,
        maxHealth  = 200,
        spawnMin   = lairDef.spawnMin,
        spawnMax   = lairDef.spawnMax,
        packMin    = lairDef.packMin,
        packMax    = lairDef.packMax,
        spawnTimer = lairDef.spawnMin + math.random(math.max(1, lairDef.spawnMax - lairDef.spawnMin)),
        destroyed  = false,
    })

    return id
end

---------------------------------------------------------------------------
-- Worldgen: scatter lairs on ROCK tiles near map edges
---------------------------------------------------------------------------

function Lairs.generateForWorld(world)
    local w = world.width()
    local h = world.height()
    local edgeMargin = 15  -- how close to edge lairs can spawn
    local innerMargin = 25 -- how far from center they must be

    local cx = math.floor(w / 2)
    local cy = math.floor(h / 2)

    local placed = 0
    local maxLairs = 6
    local attempts = 0
    local maxAttempts = 200

    while placed < maxLairs and attempts < maxAttempts do
        attempts = attempts + 1

        -- Pick a position near an edge
        local x, y
        local side = math.random(4)
        if side == 1 then
            x = math.random(3, edgeMargin)
            y = math.random(3, h - 4)
        elseif side == 2 then
            x = math.random(w - edgeMargin - 1, w - 4)
            y = math.random(3, h - 4)
        elseif side == 3 then
            x = math.random(3, w - 4)
            y = math.random(3, edgeMargin)
        else
            x = math.random(3, w - 4)
            y = math.random(h - edgeMargin - 1, h - 4)
        end

        -- Must be on ROCK tile
        local tile = world.getTile(x, y)
        if tile == Tiles.ROCK then
            -- Must be far enough from colony start
            local dx = x - cx
            local dy = y - cy
            if dx * dx + dy * dy >= innerMargin * innerMargin then
                local lairType = math.random(#LAIR_TYPES)
                Lairs.spawn(x, y, lairType)
                placed = placed + 1
            end
        end
    end

    return placed
end

---------------------------------------------------------------------------
-- Damage a lair (from colonist attack during mining/destruction task)
---------------------------------------------------------------------------

function Lairs.damage(lairId, amount)
    local lair = ECS.get(lairId, 'lair')
    if not lair or lair.destroyed then return false end

    lair.health = lair.health - amount
    if lair.health <= 0 then
        lair.health = 0
        lair.destroyed = true
        ECS.destroy(lairId)
        return true -- lair destroyed
    end
    return false
end

---------------------------------------------------------------------------
-- Designate a lair for destruction (creates a mine-type task)
---------------------------------------------------------------------------

function Lairs.designateDestroy(lairId)
    local pos = ECS.get(lairId, 'pos')
    local lair = ECS.get(lairId, 'lair')
    if not pos or not lair or lair.destroyed then return nil end

    return Jobs.createTask('mine', pos.x, pos.y, {
        lairId = lairId,
        isLair = true,
    })
end

---------------------------------------------------------------------------
-- Find lair entity at a given tile position
---------------------------------------------------------------------------

function Lairs.getAt(x, y)
    for id, comps in ECS.query('pos', 'lair') do
        if comps.pos.x == x and comps.pos.y == y and not comps.lair.destroyed then
            return id, comps.lair
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- ECS system: lair spawning tick
---------------------------------------------------------------------------

local function lairSpawnSystem(dt, id, comps)
    local lair = comps.lair
    local pos  = comps.pos

    if lair.destroyed then return end

    lair.spawnTimer = lair.spawnTimer - dt

    if lair.spawnTimer > 0 then return end

    -- Reset timer
    lair.spawnTimer = lair.spawnMin + math.random(math.max(1, lair.spawnMax - lair.spawnMin))

    -- Cap total creatures on the map
    local total = ECS.countWith('creature')
    if total >= 40 then return end

    -- Spawn creatures near the lair (on walkable adjacent tiles)
    local World = require('src.world.tilemap')
    local count = math.random(lair.packMin, lair.packMax)

    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + math.random() * 0.5
        local dist = 2 + math.random(4)
        local sx = pos.x + math.floor(math.cos(angle) * dist)
        local sy = pos.y + math.floor(math.sin(angle) * dist)
        local pd = pos.depth or 0
        if World.inBounds(sx, sy) and World.isWalkable(sx, sy, pd) then
            Creatures.spawn(lair.species, sx, sy, pd)
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Lairs.registerSystems()
    ECS.addSystem('lair_spawn', { 'lair', 'pos' }, lairSpawnSystem, 30)
end

Lairs.registerSystems()

return Lairs
