-- celestial_bodies.lua — Stars, Dyson Sphere, and other celestial features
-- Places visible celestial bodies on the space tilemap near planet positions.
-- Stars are impassable bright tiles. Nemaea's dying Dyson Sphere is a large
-- ring of debris/structure tiles surrounding its star.

local GameState = require('src.game_state')

local CelestialBodies = {}

---------------------------------------------------------------------------
-- Tile types for celestial features
---------------------------------------------------------------------------

local TILE_STAR           = 101  -- bright impassable star tile
local TILE_STAR_CORONA    = 102  -- hot corona around stars (damages ships)
local TILE_DYSON_INTACT   = 103  -- intact Dyson Sphere segment
local TILE_DYSON_CRUMBLED = 104  -- broken Dyson Sphere segment (passable, debris)
-- tile 105 reserved for future nebula system
local TILE_GRAVITY_WELL   = 106  -- near-planet gravity (slows ships)

---------------------------------------------------------------------------
-- Star system definitions
-- Each system has a star position relative to its primary planet,
-- plus optional features (twin stars, Dyson Sphere, etc.)
---------------------------------------------------------------------------

local STAR_SYSTEMS = {
    erebus_system = {
        star = { x = -30, y = -30, name = 'Erebus Star', size = 3 },
        planets = { 'erebus' },
    },
    rhea_system = {
        star = { x = 830, y = -430, name = 'Rhea Alpha', size = 3 },
        twinStar = { x = 845, y = -415, name = 'Rhea Beta', size = 2 },
        planets = { 'rhea_2' },
    },
    morvos_system = {
        star = { x = -630, y = 670, name = 'Morvos Star', size = 2 },
        planets = { 'morvos' },
    },
    nerthus_system = {
        star = { x = 370, y = 870, name = 'Nerthus Star', size = 3 },
        planets = { 'nerthus_9' },
    },
    paxtera_system = {
        star = { x = -930, y = -330, name = 'Paxtera Star', size = 3 },
        planets = { 'paxtera_prime' },
    },
    nemaea_system = {
        star = { x = 1230, y = 470, name = 'Nemaea Star', size = 2 },
        dysonSphere = {
            centerX = 1230, centerY = 470,
            radius = 15,         -- tiles from star center
            intactRatio = 0.3,   -- 30% intact, 70% crumbled
            name = 'Dying Dyson Sphere',
        },
        planets = { 'nemaea' },
    },
    gaia_system = {
        star = { x = -230, y = -1130, name = 'Gaia Star', size = 3 },
        planets = { 'gaia_a1x' },
    },
}

---------------------------------------------------------------------------
-- Stamp celestial bodies onto space tilemap chunks
---------------------------------------------------------------------------

local stamped = false

local function stampStar(setTileFn, starDef)
    local cx, cy = starDef.x, starDef.y
    local size = starDef.size or 3

    -- Star core (impassable)
    for dx = -size, size do
        for dy = -size, size do
            if dx * dx + dy * dy <= size * size then
                setTileFn(cx + dx, cy + dy, TILE_STAR)
            end
        end
    end

    -- Corona (hot, damages ships that fly through)
    local coronaSize = size + 3
    for dx = -coronaSize, coronaSize do
        for dy = -coronaSize, coronaSize do
            local dist2 = dx * dx + dy * dy
            if dist2 > size * size and dist2 <= coronaSize * coronaSize then
                setTileFn(cx + dx, cy + dy, TILE_STAR_CORONA)
            end
        end
    end
end

local function stampDysonSphere(setTileFn, dysonDef)
    local cx, cy = dysonDef.centerX, dysonDef.centerY
    local r = dysonDef.radius
    local intactRatio = dysonDef.intactRatio or 0.3

    -- Ring of Dyson Sphere segments
    local angleStep = 0.1
    local angle = 0
    while angle < math.pi * 2 do
        local tx = cx + math.floor(math.cos(angle) * r + 0.5)
        local ty = cy + math.floor(math.sin(angle) * r + 0.5)

        -- Deterministic intact vs crumbled
        local hash = ((tx * 2654435761 + ty * 1103515245) % 1000) / 1000
        if hash < intactRatio then
            setTileFn(tx, ty, TILE_DYSON_INTACT)
        else
            setTileFn(tx, ty, TILE_DYSON_CRUMBLED)
        end

        angle = angle + angleStep
    end

    -- Add some scattered debris around the sphere
    for i = 1, 40 do
        local a = (i * 0.157) + 0.3
        local dr = r + math.floor((((i * 7 + 13) % 10) - 5))
        local tx = cx + math.floor(math.cos(a) * dr + 0.5)
        local ty = cy + math.floor(math.sin(a) * dr + 0.5)
        local hash = ((tx * 374761393 + ty * 668265263) % 100) / 100
        if hash < 0.4 then
            setTileFn(tx, ty, TILE_DYSON_CRUMBLED)
        end
    end
end

local function stampGravityWell(setTileFn, planetX, planetY)
    local wellRadius = 8
    for dx = -wellRadius, wellRadius do
        for dy = -wellRadius, wellRadius do
            local dist2 = dx * dx + dy * dy
            if dist2 <= wellRadius * wellRadius and dist2 > 4 then
                local tx, ty = planetX + dx, planetY + dy
                -- Only set if currently void (don't overwrite stars/structures)
                local stOk, ST = pcall(require, 'src.space.space_tilemap')
                if stOk then
                    local current = ST.getTile(tx, ty)
                    if current == 0 then  -- VOID
                        setTileFn(tx, ty, TILE_GRAVITY_WELL)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Initialize — stamp all celestial bodies onto the space tilemap
-- Called once when space is first entered
---------------------------------------------------------------------------

function CelestialBodies.stamp()
    if stamped then return end

    local stOk, SpaceTilemap = pcall(require, 'src.space.space_tilemap')
    if not stOk then return end

    local function setTile(x, y, tileType)
        SpaceTilemap.setTile(x, y, tileType)
    end

    -- Stamp stars
    for systemId, system in pairs(STAR_SYSTEMS) do
        if system.star then
            stampStar(setTile, system.star)
        end
        if system.twinStar then
            stampStar(setTile, system.twinStar)
        end
        if system.dysonSphere then
            stampDysonSphere(setTile, system.dysonSphere)
        end
    end

    -- Stamp gravity wells around planets
    local pokGen, POIGen = pcall(require, 'src.space.poi_generator')
    if pokGen then
        local positions = POIGen.getAllPlanetPositions()
        for planetId, pos in pairs(positions) do
            stampGravityWell(setTile, pos.x, pos.y)
        end
    end

    stamped = true
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function CelestialBodies.getStarSystems()
    return STAR_SYSTEMS
end

function CelestialBodies.getNearestStar(x, y)
    local best, bestDist = nil, math.huge
    for systemId, system in pairs(STAR_SYSTEMS) do
        if system.star then
            local dx = system.star.x - x
            local dy = system.star.y - y
            local dist = dx * dx + dy * dy
            if dist < bestDist then
                best = system.star
                bestDist = dist
            end
        end
    end
    return best, math.sqrt(bestDist)
end

function CelestialBodies.isStarTile(tileType)
    return tileType == TILE_STAR or tileType == TILE_STAR_CORONA
end

function CelestialBodies.isDysonTile(tileType)
    return tileType == TILE_DYSON_INTACT or tileType == TILE_DYSON_CRUMBLED
end

function CelestialBodies.isGravityWell(tileType)
    return tileType == TILE_GRAVITY_WELL
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function CelestialBodies.getState()
    return { stamped = stamped }
end

function CelestialBodies.loadState(state)
    if not state then return end
    stamped = state.stamped or false
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

CelestialBodies.TILE_STAR           = TILE_STAR
CelestialBodies.TILE_STAR_CORONA    = TILE_STAR_CORONA
CelestialBodies.TILE_DYSON_INTACT   = TILE_DYSON_INTACT
CelestialBodies.TILE_DYSON_CRUMBLED = TILE_DYSON_CRUMBLED
-- tile 105 reserved for future nebula system
CelestialBodies.TILE_GRAVITY_WELL   = TILE_GRAVITY_WELL
CelestialBodies.STAR_SYSTEMS        = STAR_SYSTEMS

return CelestialBodies
