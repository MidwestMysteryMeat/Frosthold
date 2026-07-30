-- tilemap.lua — Multi-layer tile grid with procedural generation
-- Stores tile data, temperature per-tile, and room membership per depth layer.
-- Depth 0 = surface. Deeper layers created on-demand when shafts are dug.
-- All accessors accept optional depth param (default 0) for backward compat.

local Tiles = require('src.world.tiles')

local Tilemap = {}

local CHUNK_SIZE = 16  -- tiles per chunk side
local TILE_SIZE  = 32  -- pixels per tile

Tilemap.CHUNK_SIZE = CHUNK_SIZE
Tilemap.TILE_SIZE  = TILE_SIZE

-- Per-layer data: layers[depth] = { tiles={}, temps={}, rooms={}, water={}, gas={}, snow={} }
local layers = {}
local mapW, mapH = 0, 0
local maxDepth = 0
local mapSeed = 0

-- Convenience refs to surface layer (depth 0) for backward compat
local tileData, tempData, roomData

-- Simple door lock state: { [tileKey] = true } for locked doors
local lockedDoors = {}
local function doorKey(x, y) return y * 100000 + x end

-- Space tilemap dispatch helpers
local function isSpaceActive()
    local ok, GS = pcall(require, 'src.game_state')
    return ok and GS.activeMap == 'space'
end

local _cachedSpaceTilemap
local function getSpaceTilemap()
    if not _cachedSpaceTilemap then
        local ok, ST = pcall(require, 'src.space.space_tilemap')
        if ok then _cachedSpaceTilemap = ST end
    end
    return _cachedSpaceTilemap
end

---------------------------------------------------------------------------
-- Layer management
---------------------------------------------------------------------------

local function ensureLayer(depth)
    if layers[depth] then return layers[depth] end
    local size = mapW * mapH
    local layer = { tiles = {}, temps = {}, rooms = {}, water = {}, gas = {}, snow = {} }

    -- Planet-aware underground generation
    local planetId = nil
    local undergroundTemp = -20
    local pLok, PlanetMod = pcall(require, 'src.world.planet')
    if pLok then
        planetId = PlanetMod.getId()
        undergroundTemp = PlanetMod.get('thermal.undergroundBaseTemp', -20)
    end
    local isUnderwater = (planetId == 'nerthus_9')

    -- New underground layers start as solid rock
    for i = 1, size do
        layer.tiles[i] = Tiles.UNDERGROUND_ROCK
        layer.temps[i] = undergroundTemp
        layer.rooms[i] = 0
        layer.water[i] = isUnderwater and 7 or 0  -- ocean worlds: fully flooded underground
        layer.gas[i]   = 0
        layer.snow[i]  = 0
    end

    -- Procedural cave pockets: use noise seeded by depth for variety
    local seed = mapSeed + depth * 1000
    for y = 0, mapH - 1 do
        for x = 0, mapW - 1 do
            local idx = y * mapW + x + 1
            local nx, ny = x / mapW, y / mapH
            local caveNoise = love.math.noise(nx * 8 + seed + 100, ny * 8 + seed + 100)
            -- Deeper = slightly more open caves
            local threshold = 0.75 - depth * 0.02
            if caveNoise > threshold then
                layer.tiles[idx] = isUnderwater and Tiles.SHALLOWS or Tiles.UNDERGROUND_FLOOR
            end

            if isUnderwater then
                -- Nerthus-9: underwater resources
                local resNoise = love.math.noise(nx * 10 + seed + 200, ny * 10 + seed + 200)
                local detNoise = love.math.noise(nx * 15 + seed + 400, ny * 15 + seed + 400)

                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK then
                    if resNoise > 0.82 then
                        layer.tiles[idx] = Tiles.MINERAL_NODULE
                    elseif resNoise > 0.76 - depth * 0.01 then
                        layer.tiles[idx] = Tiles.CORAL_DEPOSIT
                    elseif detNoise > 0.88 then
                        layer.tiles[idx] = Tiles.THERMAL_MINERAL
                    elseif detNoise > 0.82 and depth >= 2 then
                        layer.tiles[idx] = Tiles.SUNKEN_WRECK
                    elseif detNoise < 0.12 and depth >= 3 then
                        layer.tiles[idx] = Tiles.BRINE_POCKET
                    end
                end
                -- Kelp forests in open underwater areas (shallow depths)
                if layer.tiles[idx] == Tiles.SHALLOWS and depth <= 2 then
                    local kelpNoise = love.math.noise(nx * 12 + seed + 500, ny * 12 + seed + 500)
                    if kelpNoise > 0.65 then
                        layer.tiles[idx] = Tiles.KELP_FOREST
                    end
                end

            elseif planetId == 'rhea_2' then
                -- Rhea-2: desert underground — sandstone caves, buried oases, rich ore
                local resNoise = love.math.noise(nx * 10 + seed + 200, ny * 10 + seed + 200)
                local detNoise = love.math.noise(nx * 14 + seed + 400, ny * 14 + seed + 400)
                local moistNoise = love.math.noise(nx * 6 + seed + 600, ny * 6 + seed + 600)

                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK then
                    -- Sandstone replaces some underground rock
                    local sandNoise = love.math.noise(nx * 8 + seed + 700, ny * 8 + seed + 700)
                    if sandNoise > 0.55 then
                        layer.tiles[idx] = Tiles.SANDSTONE
                    end
                end

                -- Ore veins (richer than Erebus — desert has mineral wealth below)
                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK or layer.tiles[idx] == Tiles.SANDSTONE then
                    if resNoise > 0.72 - depth * 0.02 then
                        layer.tiles[idx] = Tiles.ORE_VEIN
                    elseif detNoise > 0.82 - depth * 0.01 then
                        layer.tiles[idx] = Tiles.LEAD_ORE
                    end
                end

                -- Buried oases: pockets of water + fertile soil underground
                if layer.tiles[idx] == Tiles.UNDERGROUND_FLOOR then
                    if moistNoise > 0.78 then
                        -- Water pocket (precious on desert world)
                        layer.water[idx] = math.random(3, 6)
                    elseif moistNoise > 0.7 then
                        -- Fertile cave floor (can grow crops underground)
                        layer.tiles[idx] = Tiles.FERTILE_SOIL
                    end
                end

                -- Ice pockets at depth (frozen aquifer — major water source)
                if (layer.tiles[idx] == Tiles.UNDERGROUND_ROCK or layer.tiles[idx] == Tiles.SANDSTONE)
                    and depth >= 2 then
                    local iceNoise = love.math.noise(nx * 10 + seed + 300, ny * 10 + seed + 300)
                    if iceNoise > 0.85 then
                        layer.tiles[idx] = Tiles.ICE
                    end
                end

            elseif planetId == 'morvos' then
                -- Morvos: acid-resistant rock, fungal caves, toxic pockets
                local resNoise = love.math.noise(nx * 10 + seed + 200, ny * 10 + seed + 200)
                local fungNoise = love.math.noise(nx * 8 + seed + 500, ny * 8 + seed + 500)

                -- Fungal caves are more common underground on Morvos
                if layer.tiles[idx] == Tiles.UNDERGROUND_FLOOR then
                    if fungNoise > 0.5 then
                        layer.tiles[idx] = Tiles.FUNGAL_FLOOR
                    end
                end
                -- Ore in solid rock
                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK then
                    if resNoise > 0.76 - depth * 0.01 then
                        layer.tiles[idx] = Tiles.ORE_VEIN
                    end
                end
                -- Toxic gas pockets in caves
                if layer.tiles[idx] == Tiles.FUNGAL_FLOOR and fungNoise > 0.75 then
                    layer.gas[idx] = math.random(2, 5)
                end

            elseif planetId == 'nemaea' then
                -- Nemaea: buried Dyson Sphere wreckage, hull plates, components
                local debNoise = love.math.noise(nx * 10 + seed + 200, ny * 10 + seed + 200)
                local detNoise = love.math.noise(nx * 14 + seed + 400, ny * 14 + seed + 400)

                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK then
                    if debNoise > 0.8 then
                        layer.tiles[idx] = Tiles.HULL_PLATE
                    elseif debNoise > 0.72 then
                        layer.tiles[idx] = Tiles.METAL_DEBRIS
                    elseif detNoise > 0.82 - depth * 0.01 then
                        layer.tiles[idx] = Tiles.LEAD_ORE  -- radiation shielding
                    end
                end

            elseif planetId == 'gaia_a1x' then
                -- Gaia: lush underground with fungal growth, becomes corrupted deeper
                local fungNoise = love.math.noise(nx * 8 + seed + 500, ny * 8 + seed + 500)
                local resNoise = love.math.noise(nx * 12 + seed + 200, ny * 12 + seed + 200)

                if layer.tiles[idx] == Tiles.UNDERGROUND_FLOOR then
                    if depth <= 2 and fungNoise > 0.45 then
                        layer.tiles[idx] = Tiles.FUNGAL_FLOOR  -- natural bioluminescent caves
                    elseif depth >= 3 and fungNoise > 0.35 then
                        -- Deep = Baldrungen corruption (organ/membrane tiles)
                        if fungNoise > 0.7 then
                            layer.tiles[idx] = Tiles.ORGAN_FLOOR
                        else
                            layer.tiles[idx] = Tiles.MEMBRANE_FLOOR
                        end
                    end
                end
                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK then
                    if depth >= 3 and fungNoise > 0.6 then
                        -- Corrupted walls deeper down
                        if fungNoise > 0.8 then
                            layer.tiles[idx] = Tiles.ORGAN_WALL
                        else
                            layer.tiles[idx] = Tiles.MEMBRANE_WALL
                        end
                    elseif resNoise > 0.78 - depth * 0.01 then
                        layer.tiles[idx] = Tiles.ORE_VEIN
                    end
                end

            else
                -- Standard underground (Erebus, Paxtera, and fallback)
                local oreNoise = love.math.noise(nx * 12 + seed + 200, ny * 12 + seed + 200)
                -- Deeper = richer ore
                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK and oreNoise > 0.78 - depth * 0.01 then
                    layer.tiles[idx] = Tiles.ORE_VEIN
                end
                -- Lead ore veins (rarer than metal, found deeper)
                local leadNoise = love.math.noise(nx * 14 + seed + 250, ny * 14 + seed + 250)
                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK and leadNoise > 0.85 - depth * 0.01 then
                    layer.tiles[idx] = Tiles.LEAD_ORE
                end
                -- Ice pockets (flood hazard)
                local iceNoise = love.math.noise(nx * 10 + seed + 300, ny * 10 + seed + 300)
                if layer.tiles[idx] == Tiles.UNDERGROUND_ROCK and iceNoise > 0.88 then
                    layer.tiles[idx] = Tiles.ICE
                end
            end
        end
    end

    layers[depth] = layer
    if depth > maxDepth then maxDepth = depth end

    -- Generate cavern structure at fixed depths (3, 6, 9)
    local cOk, Caverns = pcall(require, 'src.world.caverns')
    if cOk and Caverns.isCavernDepth and Caverns.isCavernDepth(depth) then
        Caverns.generateCavern(depth, layer.tiles, layer.water, mapW, mapH, seed)
    end

    return layer
end

---------------------------------------------------------------------------
-- Planet-specific terrain generation (non-Erebus worlds)
---------------------------------------------------------------------------

local function generatePlanetTerrain(surface, w, h, seed, planetId)
    local tiles = surface.tiles
    local temps = surface.temps

    -- Base temp lookup from planet seasons (use first season's baseTemp as default)
    local baseTemp = 0
    local pok2, PlanetDefs = pcall(require, 'src.world.planet_defs')
    if pok2 then
        local pdef = PlanetDefs.get(planetId)
        if pdef and pdef.seasons and pdef.seasons.defs then
            local startSeason = pdef.seasons.startSeason
            if startSeason and pdef.seasons.defs[startSeason] then
                baseTemp = pdef.seasons.defs[startSeason].baseTemp or 0
            end
        end
    end

    if planetId == 'rhea_2' then
        -- Desert terrain: sand, dunes, sandstone ridges, rare oases
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                local nx, ny = x / w, y / h
                local elev = love.math.noise(nx * 6 + seed, ny * 6 + seed)
                local moisture = love.math.noise(nx * 4 + seed + 100, ny * 4 + seed + 100)
                local detail = love.math.noise(nx * 12 + seed + 200, ny * 12 + seed + 200)

                local tile
                if elev > 0.72 then
                    tile = Tiles.SANDSTONE
                elseif elev > 0.6 then
                    if detail > 0.7 then tile = Tiles.DUNE
                    else tile = Tiles.CRACKED_EARTH end
                elseif moisture > 0.75 and elev < 0.4 then
                    if detail > 0.85 then tile = Tiles.OASIS
                    else tile = Tiles.SAND end
                elseif detail > 0.82 then
                    tile = Tiles.CACTUS
                elseif elev < 0.3 then
                    tile = Tiles.CRACKED_EARTH
                else
                    tile = Tiles.SAND
                end
                tiles[idx] = tile
                temps[idx] = baseTemp + (math.random() - 0.5) * 4
            end
        end
        -- Ore veins
        for _ = 1, math.floor(w * h / 800) do
            local ox = math.random(2, w - 3)
            local oy = math.random(2, h - 3)
            for dy = -1, 1 do for dx = -1, 1 do
                local idx = (oy + dy) * w + (ox + dx) + 1
                if idx >= 1 and idx <= w * h and math.random() < 0.6 then
                    tiles[idx] = Tiles.ORE_VEIN
                end
            end end
        end

    elseif planetId == 'morvos' then
        -- Acid world: rock platforms over toxic pools, fungal patches
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                local nx, ny = x / w, y / h
                local elev = love.math.noise(nx * 5 + seed, ny * 5 + seed)
                local acid = love.math.noise(nx * 8 + seed + 300, ny * 8 + seed + 300)
                local detail = love.math.noise(nx * 12 + seed + 200, ny * 12 + seed + 200)

                local tile
                if elev > 0.65 then
                    if detail > 0.7 then tile = Tiles.VOLCANIC_ROCK
                    else tile = Tiles.ROCK end
                elseif acid > 0.65 then
                    tile = Tiles.WATER  -- acid pools (rendered as water)
                elseif elev < 0.3 then
                    if detail > 0.6 then tile = Tiles.FUNGAL_FLOOR
                    else tile = Tiles.DIRT end
                else
                    if detail > 0.85 then tile = Tiles.DEAD_TREE
                    else tile = Tiles.ASH_GROUND end
                end
                tiles[idx] = tile
                temps[idx] = baseTemp + (math.random() - 0.5) * 3
            end
        end
        -- Ore veins in rock areas
        for _ = 1, math.floor(w * h / 600) do
            local ox = math.random(2, w - 3)
            local oy = math.random(2, h - 3)
            for dy = -1, 1 do for dx = -1, 1 do
                local idx = (oy + dy) * w + (ox + dx) + 1
                if idx >= 1 and idx <= w * h and tiles[idx] == Tiles.ROCK and math.random() < 0.5 then
                    tiles[idx] = Tiles.ORE_VEIN
                end
            end end
        end

    elseif planetId == 'nerthus_9' then
        -- Ocean world: islands in deep water, beaches, shallows, coral
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                local nx, ny = x / w, y / h
                local elev = love.math.noise(nx * 4 + seed, ny * 4 + seed)
                local island = love.math.noise(nx * 8 + seed + 500, ny * 8 + seed + 500)
                local detail = love.math.noise(nx * 14 + seed + 200, ny * 14 + seed + 200)

                local tile
                -- Higher threshold = more ocean
                if elev < 0.35 then
                    if detail > 0.8 then tile = Tiles.CORAL
                    else tile = Tiles.OCEAN end
                elseif elev < 0.42 then
                    if detail > 0.7 then tile = Tiles.SEAWEED
                    else tile = Tiles.SHALLOWS end
                elseif elev < 0.47 then
                    tile = Tiles.BEACH
                elseif island > 0.6 and elev > 0.55 then
                    if detail > 0.75 then tile = Tiles.TREE
                    else tile = Tiles.GRASS end
                elseif elev > 0.7 then
                    tile = Tiles.ROCK
                else
                    tile = Tiles.GRASS
                end
                tiles[idx] = tile
                temps[idx] = baseTemp + (math.random() - 0.5) * 3
            end
        end
        -- Ore veins in rock
        for _ = 1, math.floor(w * h / 1000) do
            local ox = math.random(2, w - 3)
            local oy = math.random(2, h - 3)
            local idx = oy * w + ox + 1
            if tiles[idx] == Tiles.ROCK then tiles[idx] = Tiles.ORE_VEIN end
        end

    elseif planetId == 'paxtera_prime' then
        -- Temperate: grass, forests, fertile soil, mild terrain
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                local nx, ny = x / w, y / h
                local elev = love.math.noise(nx * 5 + seed, ny * 5 + seed)
                local moisture = love.math.noise(nx * 6 + seed + 100, ny * 6 + seed + 100)
                local detail = love.math.noise(nx * 12 + seed + 200, ny * 12 + seed + 200)

                local tile
                if elev > 0.75 then
                    tile = Tiles.ROCK
                elseif moisture > 0.65 and elev < 0.5 then
                    if detail > 0.6 then tile = Tiles.FERTILE_SOIL
                    else tile = Tiles.GRASS end
                elseif elev > 0.55 then
                    if detail > 0.5 then tile = Tiles.DECIDUOUS_TREE
                    else tile = Tiles.GRASS end
                elseif moisture > 0.7 and detail > 0.75 then
                    tile = Tiles.WATER
                elseif detail > 0.88 then
                    tile = Tiles.FLOWER_FIELD
                elseif detail > 0.78 then
                    tile = Tiles.BUSH
                else
                    tile = Tiles.GRASS
                end
                tiles[idx] = tile
                temps[idx] = baseTemp + (math.random() - 0.5) * 3
            end
        end
        -- Ore and trees
        for _ = 1, math.floor(w * h / 800) do
            local ox = math.random(2, w - 3)
            local oy = math.random(2, h - 3)
            local idx = oy * w + ox + 1
            if tiles[idx] == Tiles.ROCK then tiles[idx] = Tiles.ORE_VEIN end
        end

    elseif planetId == 'nemaea' then
        -- Dead world: regolith, craters, metal debris, hull plates
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                local nx, ny = x / w, y / h
                local elev = love.math.noise(nx * 5 + seed, ny * 5 + seed)
                local debris = love.math.noise(nx * 10 + seed + 600, ny * 10 + seed + 600)
                local detail = love.math.noise(nx * 15 + seed + 200, ny * 15 + seed + 200)

                local tile
                if elev > 0.72 then
                    if debris > 0.6 then tile = Tiles.HULL_PLATE
                    else tile = Tiles.ROCK end
                elseif debris > 0.75 then
                    tile = Tiles.METAL_DEBRIS
                elseif detail > 0.85 then
                    tile = Tiles.CRATER
                elseif elev < 0.25 then
                    tile = Tiles.CRATER
                else
                    tile = Tiles.REGOLITH
                end
                tiles[idx] = tile
                temps[idx] = baseTemp + (math.random() - 0.5) * 10
            end
        end
        -- Lead ore (radiation shielding material)
        for _ = 1, math.floor(w * h / 500) do
            local ox = math.random(2, w - 3)
            local oy = math.random(2, h - 3)
            local idx = oy * w + ox + 1
            if tiles[idx] == Tiles.ROCK then tiles[idx] = Tiles.LEAD_ORE end
        end

    elseif planetId == 'gaia_a1x' then
        -- Lush world: dense forests, rivers, fertile ground
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                local nx, ny = x / w, y / h
                local elev = love.math.noise(nx * 4 + seed, ny * 4 + seed)
                local moisture = love.math.noise(nx * 5 + seed + 100, ny * 5 + seed + 100)
                local detail = love.math.noise(nx * 12 + seed + 200, ny * 12 + seed + 200)

                local tile
                if elev > 0.7 then
                    tile = Tiles.ROCK
                elseif moisture > 0.65 then
                    if detail > 0.5 then tile = Tiles.DECIDUOUS_TREE
                    else tile = Tiles.FERTILE_SOIL end
                elseif elev < 0.25 and moisture > 0.45 then
                    if detail > 0.7 then tile = Tiles.WATER
                    else tile = Tiles.BUSH end
                elseif detail > 0.85 then
                    tile = Tiles.FLOWER_FIELD
                elseif detail > 0.6 then
                    tile = Tiles.DECIDUOUS_TREE
                else
                    tile = Tiles.GRASS
                end
                tiles[idx] = tile
                temps[idx] = baseTemp + (math.random() - 0.5) * 3
            end
        end
        -- Ore veins
        for _ = 1, math.floor(w * h / 800) do
            local ox = math.random(2, w - 3)
            local oy = math.random(2, h - 3)
            local idx = oy * w + ox + 1
            if tiles[idx] == Tiles.ROCK then tiles[idx] = Tiles.ORE_VEIN end
        end

    else
        -- Unknown planet: default to dirt
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local idx = y * w + x + 1
                tiles[idx] = Tiles.DIRT
                temps[idx] = baseTemp
            end
        end
    end

    -- Clear starting area for all planets (9x9 walkable zone at center)
    local cx = math.floor(w / 2)
    local cy = math.floor(h / 2)
    local clearTile = Tiles.SAND  -- default clear tile
    if planetId == 'nerthus_9' then clearTile = Tiles.BEACH
    elseif planetId == 'paxtera_prime' or planetId == 'gaia_a1x' then clearTile = Tiles.GRASS
    elseif planetId == 'nemaea' then clearTile = Tiles.REGOLITH
    elseif planetId == 'morvos' then clearTile = Tiles.ASH_GROUND
    end
    for dy = -4, 4 do
        for dx = -4, 4 do
            local sx = cx + dx
            local sy = cy + dy
            if sx >= 0 and sx < w and sy >= 0 and sy < h then
                local idx = sy * w + sx + 1
                tiles[idx] = clearTile
                temps[idx] = baseTemp
            end
        end
    end

    -- Initialize water/gas/snow layers to 0
    for i = 1, w * h do
        surface.water[i] = 0
        surface.gas[i] = 0
        surface.snow[i] = 0
    end
end

---------------------------------------------------------------------------
-- Init / generation (surface layer only; underground created on demand)
---------------------------------------------------------------------------

function Tilemap.init(w, h, requestedSeed)
    mapW = w
    mapH = h
    layers = {}
    maxDepth = 0
    lockedDoors = {}
    mapSeed = requestedSeed or love.math.random(1, 999999)

    local pok, Planet = pcall(require, 'src.world.planet')

    -- Create surface layer
    local surface = { tiles = {}, temps = {}, rooms = {}, water = {}, gas = {}, snow = {} }
    layers[0] = surface

    local seed = mapSeed

    -- Landing zone: shift seed and pass ore scale to terrain generators
    local GameState = require('src.game_state')
    local landingZone = GameState.landingZone
    if landingZone then
        seed = seed + (landingZone.q or 0) * 7 + (landingZone.r or 0) * 13
    end

    -- Planet-specific terrain generation
    local planetId
    if pok then planetId = Planet.getId() end

    if planetId and planetId ~= 'erebus' then
        generatePlanetTerrain(surface, w, h, seed, planetId)
    else

    ---------------------------------------------------------------------------
    -- Pass 1: Biome-aware base terrain
    ---------------------------------------------------------------------------
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local idx = y * w + x + 1

            local nx = x / w
            local ny = y / h
            local elevation = love.math.noise(nx * 6 + seed, ny * 6 + seed)
            local moisture  = love.math.noise(nx * 4 + seed + 100, ny * 4 + seed + 100)
            local biomeN    = love.math.noise(nx * 3.5 + seed + 400, ny * 3.5 + seed + 400)

            -- Determine biome zone
            -- 'default' = original snow/permafrost/ice/rock
            -- 'frozen_forest' = dense trees on snow
            -- 'marsh'  = wet tundra lowlands
            -- 'volcanic' = warm volcanic terrain
            -- 'dead_forest' = dead trees and ash
            -- 'glacier' = dense ice formations
            local biome = 'default'
            if biomeN < 0.2 and elevation < 0.55 then
                biome = 'marsh'
            elseif biomeN < 0.38 and moisture > 0.45 and elevation < 0.65 then
                biome = 'frozen_forest'
            elseif biomeN > 0.78 and elevation > 0.45 then
                biome = 'volcanic'
            elseif biomeN > 0.62 and elevation > 0.4 and elevation < 0.72 then
                biome = 'dead_forest'
            elseif elevation > 0.68 and moisture > 0.6 then
                biome = 'glacier'
            end

            local tile
            if biome == 'marsh' then
                -- Wet tundra lowlands
                local marshDetail = love.math.noise(nx * 12 + seed + 410, ny * 12 + seed + 410)
                if marshDetail > 0.7 then
                    tile = Tiles.FROZEN_RIVER  -- scattered shallow frozen water
                elseif marshDetail > 0.4 then
                    tile = Tiles.TUNDRA_MARSH
                else
                    tile = Tiles.SNOW
                end
            elseif biome == 'frozen_forest' then
                -- Dense tree coverage
                local treeDensity = love.math.noise(nx * 8 + seed + 500, ny * 8 + seed + 500)
                if elevation > 0.55 then
                    tile = Tiles.PERMAFROST
                elseif treeDensity > 0.3 then
                    tile = Tiles.TREE
                else
                    tile = Tiles.SNOW
                end
            elseif biome == 'volcanic' then
                -- Volcanic terrain
                local ventN = love.math.noise(nx * 20 + seed + 300, ny * 20 + seed + 300)
                if elevation > 0.72 then
                    tile = Tiles.VOLCANIC_ROCK
                elseif ventN > 0.85 then
                    tile = Tiles.LAVA_VENT
                elseif elevation > 0.55 then
                    tile = Tiles.VOLCANIC_FLOOR
                else
                    tile = Tiles.ASH_GROUND
                end
            elseif biome == 'dead_forest' then
                -- Dead trees and ash
                local treeN = love.math.noise(nx * 10 + seed + 420, ny * 10 + seed + 420)
                if treeN > 0.45 then
                    tile = Tiles.DEAD_TREE
                elseif elevation > 0.55 then
                    tile = Tiles.PERMAFROST
                else
                    tile = Tiles.ASH_GROUND
                end
            elseif biome == 'glacier' then
                -- Dense ice with rocky outcrops
                if elevation > 0.78 then
                    tile = Tiles.ROCK
                else
                    tile = Tiles.ICE
                end
            else
                -- Default biome (original logic)
                if elevation > 0.72 then
                    tile = Tiles.ROCK
                elseif elevation > 0.55 then
                    tile = Tiles.PERMAFROST
                elseif moisture > 0.65 then
                    tile = Tiles.ICE
                else
                    tile = Tiles.SNOW
                end

                -- Lava vents in default biome
                local vent = love.math.noise(nx * 20 + seed + 300, ny * 20 + seed + 300)
                if vent > 0.92 and tile ~= Tiles.ROCK then
                    tile = Tiles.LAVA_VENT
                end

                -- Trees in default biome
                if tile == Tiles.SNOW or tile == Tiles.PERMAFROST then
                    local treeDensity = love.math.noise(nx * 8 + seed + 500, ny * 8 + seed + 500)
                    local treeDetail  = love.math.noise(nx * 16 + seed + 600, ny * 16 + seed + 600)
                    if treeDensity > 0.5 and treeDetail > 0.6 then
                        tile = Tiles.TREE
                    end
                end
            end

            -- Ore veins in any rock type
            if tile == Tiles.ROCK or tile == Tiles.VOLCANIC_ROCK then
                local oreNoise = love.math.noise(nx * 12 + seed + 700, ny * 12 + seed + 700)
                if oreNoise > 0.75 then
                    tile = Tiles.ORE_VEIN
                end
            end

            surface.tiles[idx] = tile
            surface.temps[idx] = -40
            surface.rooms[idx] = 0
            surface.water[idx] = 0
            surface.gas[idx]   = 0
            surface.snow[idx]  = 0
        end
    end

    ---------------------------------------------------------------------------
    -- Pass 2: Deep rock at map edges and scattered patches
    ---------------------------------------------------------------------------
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local idx = y * w + x + 1
            local cur = surface.tiles[idx]
            if cur == Tiles.ROCK or cur == Tiles.VOLCANIC_ROCK then
                local edgeDist = math.min(x, y, w - 1 - x, h - 1 - y)
                local deepNoise = love.math.noise(x / w * 10 + seed + 800, y / h * 10 + seed + 800)
                if edgeDist < 8 and deepNoise > 0.4 then
                    surface.tiles[idx] = Tiles.DEEP_ROCK
                elseif deepNoise > 0.82 then
                    surface.tiles[idx] = Tiles.DEEP_ROCK
                end
            end
        end
    end

    -- Underground rock clusters behind deep rock
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local idx = y * w + x + 1
            if surface.tiles[idx] == Tiles.DEEP_ROCK then
                local deepNeighbors = 0
                for _, d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
                    local bx, by = x + d[1], y + d[2]
                    if bx >= 0 and bx < w and by >= 0 and by < h then
                        local nIdx = by * w + bx + 1
                        if surface.tiles[nIdx] == Tiles.DEEP_ROCK or surface.tiles[nIdx] == Tiles.ROCK
                           or surface.tiles[nIdx] == Tiles.VOLCANIC_ROCK then
                            deepNeighbors = deepNeighbors + 1
                        end
                    end
                end
                if deepNeighbors >= 3 then
                    local caveNoise = love.math.noise(x / w * 14 + seed + 900, y / h * 14 + seed + 900)
                    if caveNoise > 0.55 then
                        surface.tiles[idx] = Tiles.UNDERGROUND_ROCK
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Pass 3: Frozen lakes (interior water bodies)
    ---------------------------------------------------------------------------
    local lakeNoise_seed = seed + 900
    local lakesPlaced = 0
    local MAX_LAKES = 3 + (seed % 3)  -- 3-5 lakes
    for y = 6, h - 7 do
        if lakesPlaced >= MAX_LAKES then break end
        for x = 6, w - 7 do
            if lakesPlaced >= MAX_LAKES then break end
            local nx, ny = x / w, y / h
            local lakeN = love.math.noise(nx * 5 + lakeNoise_seed, ny * 5 + lakeNoise_seed)
            if lakeN > 0.78 then
                local cur = surface.tiles[y * w + x + 1]
                if cur == Tiles.SNOW or cur == Tiles.ICE or cur == Tiles.PERMAFROST then
                    -- Flood-fill a lake body (8-25 tiles)
                    local lakeQueue = { {x = x, y = y} }
                    local lakeHead = 1
                    local lakeVisited = {}
                    local lakeTiles = {}
                    local maxSize = 8 + love.math.random(17)
                    while lakeHead <= #lakeQueue and #lakeTiles < maxSize do
                        local p = lakeQueue[lakeHead]; lakeHead = lakeHead + 1
                        local pk = p.y * w + p.x
                        if not lakeVisited[pk] then
                            lakeVisited[pk] = true
                            local pidx = p.y * w + p.x + 1
                            local pt = surface.tiles[pidx]
                            if (pt == Tiles.SNOW or pt == Tiles.ICE or pt == Tiles.PERMAFROST
                                or pt == Tiles.TUNDRA_MARSH) and p.x > 2 and p.x < w - 3
                                and p.y > 2 and p.y < h - 3 then
                                lakeTiles[#lakeTiles + 1] = pidx
                                for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                                    local qx, qy = p.x + d[1], p.y + d[2]
                                    if not lakeVisited[qy * w + qx] then
                                        lakeQueue[#lakeQueue + 1] = { x = qx, y = qy }
                                    end
                                end
                            end
                        end
                    end
                    if #lakeTiles >= 8 then
                        for _, li in ipairs(lakeTiles) do
                            surface.tiles[li] = Tiles.FROZEN_LAKE
                        end
                        lakesPlaced = lakesPlaced + 1
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Pass 4: Frozen seas (map edge coastlines)
    ---------------------------------------------------------------------------
    local seaSeed = seed + 1100
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local edgeDist = math.min(x, y, w - 1 - x, h - 1 - y)
            if edgeDist < 12 then
                local nx, ny = x / w, y / h
                local seaN = love.math.noise(nx * 6 + seaSeed, ny * 6 + seaSeed)
                -- Stronger near edges, fades toward interior
                local edgeFactor = 1 - (edgeDist / 12)
                if seaN + edgeFactor * 0.3 > 0.75 then
                    local idx = y * w + x + 1
                    local cur = surface.tiles[idx]
                    if cur == Tiles.SNOW or cur == Tiles.ICE or cur == Tiles.PERMAFROST
                       or cur == Tiles.TUNDRA_MARSH then
                        surface.tiles[idx] = Tiles.FROZEN_SEA
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Pass 5: Frozen rivers (1-2 rivers snaking across the map)
    ---------------------------------------------------------------------------
    local numRivers = 1 + (seed % 2)  -- 1 or 2 rivers
    for r = 1, numRivers do
        local rx, ry, dirX, dirY
        local edge = (seed + r * 7) % 4
        if edge == 0 then
            rx = math.floor(w * 0.2 + love.math.random() * w * 0.6)
            ry = 0; dirX = 0; dirY = 1
        elseif edge == 1 then
            rx = 0; ry = math.floor(h * 0.2 + love.math.random() * h * 0.6)
            dirX = 1; dirY = 0
        elseif edge == 2 then
            rx = math.floor(w * 0.2 + love.math.random() * w * 0.6)
            ry = h - 1; dirX = 0; dirY = -1
        else
            rx = w - 1; ry = math.floor(h * 0.2 + love.math.random() * h * 0.6)
            dirX = -1; dirY = 0
        end
        local riverWidth = 1 + (seed % 2)
        for step = 1, math.floor(math.max(w, h) * 1.2) do
            for rw = 0, riverWidth - 1 do
                local px, py
                if dirX == 0 then px, py = rx + rw, ry
                else px, py = rx, ry + rw end
                if px >= 0 and px < w and py >= 0 and py < h then
                    local idx = py * w + px + 1
                    local cur = surface.tiles[idx]
                    if cur ~= Tiles.ROCK and cur ~= Tiles.DEEP_ROCK and cur ~= Tiles.LAVA_VENT
                       and cur ~= Tiles.VOLCANIC_ROCK and cur ~= Tiles.FROZEN_SEA then
                        surface.tiles[idx] = Tiles.FROZEN_RIVER
                    end
                end
            end
            rx = rx + dirX
            ry = ry + dirY
            local meander = love.math.noise(rx * 0.1 + seed + r * 200, ry * 0.1 + seed + r * 200)
            if meander > 0.6 then
                if dirX == 0 then rx = rx + 1 else ry = ry + 1 end
            elseif meander < 0.4 then
                if dirX == 0 then rx = rx - 1 else ry = ry - 1 end
            end
            rx = math.max(0, math.min(w - 1, rx))
            ry = math.max(0, math.min(h - 1, ry))
            if rx <= 0 or rx >= w - 1 or ry <= 0 or ry >= h - 1 then break end
        end
    end

    ---------------------------------------------------------------------------
    -- Pass 6: Geysers + hot springs (2-4 per map, away from center)
    ---------------------------------------------------------------------------
    local numGeysers = 2 + (seed % 3)
    for g = 1, numGeysers do
        local attempts = 0
        while attempts < 20 do
            local gx = math.floor(love.math.random() * (w - 10) + 5)
            local gy = math.floor(love.math.random() * (h - 10) + 5)
            local distFromCenter = math.abs(gx - math.floor(w/2)) + math.abs(gy - math.floor(h/2))
            if distFromCenter > 20 then
                local idx = gy * w + gx + 1
                local cur = surface.tiles[idx]
                if cur == Tiles.SNOW or cur == Tiles.PERMAFROST or cur == Tiles.ICE
                   or cur == Tiles.ASH_GROUND or cur == Tiles.VOLCANIC_FLOOR then
                    surface.tiles[idx] = Tiles.GEYSER
                    for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                        local sx, sy = gx + d[1], gy + d[2]
                        if sx >= 0 and sx < w and sy >= 0 and sy < h then
                            local sIdx = sy * w + sx + 1
                            local sCur = surface.tiles[sIdx]
                            if sCur ~= Tiles.ROCK and sCur ~= Tiles.DEEP_ROCK
                               and sCur ~= Tiles.LAVA_VENT and sCur ~= Tiles.GEYSER then
                                surface.tiles[sIdx] = Tiles.HOT_SPRING
                                break
                            end
                        end
                    end
                    break
                end
            end
            attempts = attempts + 1
        end
    end

    ---------------------------------------------------------------------------
    -- Pass 7: Surface cave entrances (2-5 per map, in rocky terrain)
    ---------------------------------------------------------------------------
    local numCaves = 2 + (seed % 4)  -- 2-5 caves
    local cavePositions = {}
    for c = 1, numCaves do
        local attempts = 0
        while attempts < 30 do
            local cx2 = math.floor(love.math.random() * (w - 20) + 10)
            local cy2 = math.floor(love.math.random() * (h - 20) + 10)
            -- Must be away from center and other caves
            local distCenter = math.abs(cx2 - math.floor(w/2)) + math.abs(cy2 - math.floor(h/2))
            local tooClose = false
            for _, cp in ipairs(cavePositions) do
                if math.abs(cx2 - cp.x) + math.abs(cy2 - cp.y) < 15 then
                    tooClose = true; break
                end
            end
            if distCenter > 20 and not tooClose then
                local idx = cy2 * w + cx2 + 1
                local cur = surface.tiles[idx]
                if cur == Tiles.ROCK or cur == Tiles.DEEP_ROCK or cur == Tiles.UNDERGROUND_ROCK then
                    surface.tiles[idx] = Tiles.CAVE_ENTRANCE
                    cavePositions[#cavePositions + 1] = { x = cx2, y = cy2 }
                    -- Clear 2 adjacent tiles for approach
                    for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                        local ax, ay = cx2 + d[1], cy2 + d[2]
                        if ax >= 0 and ax < w and ay >= 0 and ay < h then
                            local aIdx = ay * w + ax + 1
                            local aCur = surface.tiles[aIdx]
                            if aCur == Tiles.ROCK or aCur == Tiles.DEEP_ROCK
                               or aCur == Tiles.UNDERGROUND_ROCK then
                                surface.tiles[aIdx] = Tiles.PERMAFROST
                            end
                        end
                    end
                    break
                end
            end
            attempts = attempts + 1
        end
    end

    ---------------------------------------------------------------------------
    -- Pass 8: Clear starting area
    ---------------------------------------------------------------------------
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    for dy = -4, 4 do
        for dx = -4, 4 do
            local tx, ty = cx + dx, cy + dy
            if tx >= 0 and tx < w and ty >= 0 and ty < h then
                local idx = ty * w + tx + 1
                local cur = surface.tiles[idx]
                if Tiles.isSolid(cur) or not Tiles.isWalkable(cur) then
                    surface.tiles[idx] = Tiles.PERMAFROST
                end
            end
        end
    end

    end -- planet terrain if/else

    -- Set convenience refs
    tileData = surface.tiles
    tempData = surface.temps
    roomData = surface.rooms

    -- Procedural pre-existing structures
    local sOk, Structures = pcall(require, 'src.world.structures')
    if sOk then
        Structures.generate(tileData, w, h)
        Structures.spawnLoot()
    end
end

---------------------------------------------------------------------------
-- Depth layer API
---------------------------------------------------------------------------

function Tilemap.getMaxDepth()   return maxDepth end
function Tilemap.hasLayer(depth) return layers[depth] ~= nil end

-- Create a new depth layer (called when digging a shaft down)
function Tilemap.createLayer(depth)
    return ensureLayer(depth)
end

-- Create a shaft connection: place shaft entrance on both layers
function Tilemap.digShaftDown(x, y, fromDepth)
    local toDepth = fromDepth + 1
    local fromLayer = layers[fromDepth]
    if not fromLayer then return false end

    ensureLayer(toDepth)
    local toLayer = layers[toDepth]

    -- Place shaft entrance on the source layer
    local idx = y * mapW + x + 1
    fromLayer.tiles[idx] = Tiles.SHAFT_ENTRANCE

    -- Place shaft entrance on the destination layer + clear surrounding tiles
    toLayer.tiles[idx] = Tiles.SHAFT_ENTRANCE
    -- Clear a small area around the shaft on the new layer
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = x + dx, y + dy
            if nx >= 0 and nx < mapW and ny >= 0 and ny < mapH then
                local ni = ny * mapW + nx + 1
                if toLayer.tiles[ni] == Tiles.UNDERGROUND_ROCK then
                    toLayer.tiles[ni] = Tiles.UNDERGROUND_FLOOR
                end
            end
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Accessors (all accept optional depth, default 0)
---------------------------------------------------------------------------

function Tilemap.width()  return mapW end
function Tilemap.height() return mapH end
function Tilemap.tileSize() return TILE_SIZE end

function Tilemap.inBounds(x, y)
    if isSpaceActive() then return true end
    return x >= 0 and x < mapW and y >= 0 and y < mapH
end

local function _idx(x, y)
    return y * mapW + x + 1
end

local function _layer(depth)
    return layers[depth or 0]
end

function Tilemap.getTile(x, y, depth)
    if isSpaceActive() then
        local ST = getSpaceTilemap()
        if ST then return ST.getTile(x, y) end
    end
    if not Tilemap.inBounds(x, y) then return Tiles.VOID end
    local L = _layer(depth)
    if not L then return Tiles.VOID end
    return L.tiles[_idx(x, y)]
end

function Tilemap.setTile(x, y, tileType, depth)
    if isSpaceActive() then
        local ST = getSpaceTilemap()
        if ST then ST.setTile(x, y, tileType); return end
    end
    if not Tilemap.inBounds(x, y) then return end
    local L = _layer(depth)
    if not L then return end
    L.tiles[_idx(x, y)] = tileType
end

function Tilemap.getTemp(x, y, depth)
    if isSpaceActive() then
        local ST = getSpaceTilemap()
        if ST then return ST.getTemp(x, y) end
    end
    if not Tilemap.inBounds(x, y) then return -60 end
    local L = _layer(depth)
    if not L then return -60 end
    return L.temps[_idx(x, y)]
end

function Tilemap.setTemp(x, y, temp, depth)
    if not Tilemap.inBounds(x, y) then return end
    local L = _layer(depth)
    if not L then return end
    L.temps[_idx(x, y)] = temp
end

function Tilemap.getRoom(x, y, depth)
    if not Tilemap.inBounds(x, y) then return 0 end
    local L = _layer(depth)
    if not L then return 0 end
    return L.rooms[_idx(x, y)]
end

function Tilemap.setRoom(x, y, roomId, depth)
    if not Tilemap.inBounds(x, y) then return end
    local L = _layer(depth)
    if not L then return end
    L.rooms[_idx(x, y)] = roomId
end

function Tilemap.isWalkable(x, y, depth)
    if not Tilemap.inBounds(x, y) then return false end
    local L = _layer(depth)
    if not L then return false end
    return Tiles.isWalkable(L.tiles[_idx(x, y)])
end

function Tilemap.isSolid(x, y, depth)
    if not Tilemap.inBounds(x, y) then return true end
    local L = _layer(depth)
    if not L then return true end
    return Tiles.isSolid(L.tiles[_idx(x, y)])
end

-- Water level per tile (0-7)
function Tilemap.getWater(x, y, depth)
    if not Tilemap.inBounds(x, y) then return 0 end
    local L = _layer(depth)
    if not L or not L.water then return 0 end
    return L.water[_idx(x, y)] or 0
end

function Tilemap.setWater(x, y, level, depth)
    if not Tilemap.inBounds(x, y) then return end
    local L = _layer(depth)
    if not L then return end
    if not L.water then L.water = {} end
    L.water[_idx(x, y)] = math.max(0, math.min(7, level))
end

function Tilemap.rawWaterData(depth)
    local L = _layer(depth)
    return L and L.water
end

-- Gas concentration per tile (0-7)
function Tilemap.getGas(x, y, depth)
    if not Tilemap.inBounds(x, y) then return 0 end
    local L = _layer(depth)
    if not L or not L.gas then return 0 end
    return L.gas[_idx(x, y)] or 0
end

function Tilemap.setGas(x, y, level, depth)
    if not Tilemap.inBounds(x, y) then return end
    local L = _layer(depth)
    if not L then return end
    if not L.gas then L.gas = {} end
    L.gas[_idx(x, y)] = math.max(0, math.min(7, level))
end

function Tilemap.rawGasData(depth)
    local L = _layer(depth)
    return L and L.gas
end

-- Snow depth per tile (0-7)
function Tilemap.getSnow(x, y, depth)
    if not Tilemap.inBounds(x, y) then return 0 end
    local L = _layer(depth)
    if not L or not L.snow then return 0 end
    return L.snow[_idx(x, y)] or 0
end

function Tilemap.setSnow(x, y, level, depth)
    if not Tilemap.inBounds(x, y) then return end
    local L = _layer(depth)
    if not L then return end
    if not L.snow then L.snow = {} end
    L.snow[_idx(x, y)] = math.max(0, math.min(7, level))
end

function Tilemap.rawSnowData(depth)
    local L = _layer(depth)
    return L and L.snow
end

-- Check if a tile is a shaft entrance (connects to adjacent depth)
function Tilemap.isShaft(x, y, depth)
    return Tilemap.getTile(x, y, depth) == Tiles.SHAFT_ENTRANCE
end

--- Check if a tile connects downward (stairs, channels, shafts)
function Tilemap.connectsDown(x, y, depth)
    return Tiles.connectsDown(Tilemap.getTile(x, y, depth))
end

--- Check if a tile connects upward (stairs, ramps, shafts)
function Tilemap.connectsUp(x, y, depth)
    return Tiles.connectsUp(Tilemap.getTile(x, y, depth))
end

--- Get vertical target depth(s) for a tile. Returns up, down (each nil or depth int).
function Tilemap.getVerticalTargets(x, y, depth)
    depth = depth or 0
    local tile = Tilemap.getTile(x, y, depth)
    local up, down = nil, nil

    if Tiles.connectsUp(tile) and depth > 0 then
        -- Verify the tile above also connects down (paired connection)
        local aboveTile = Tilemap.getTile(x, y, depth - 1)
        if aboveTile ~= Tiles.VOID and (Tiles.connectsDown(aboveTile) or Tiles.isWalkable(aboveTile)) then
            up = depth - 1
        end
    end

    if Tiles.connectsDown(tile) then
        -- Surface cave entrance: auto-create depth 1 and clear arrival area per entrance
        if depth == 0 and tile == Tiles.CAVE_ENTRANCE then
            if not layers[1] then ensureLayer(1) end
            local layer1 = layers[1]
            local ci = _idx(x, y)
            -- Only clear if arrival tile is still solid (idempotent per entrance)
            if layer1.tiles[ci] == Tiles.UNDERGROUND_ROCK or layer1.tiles[ci] == Tiles.ORE_VEIN then
                layer1.tiles[ci] = Tiles.STAIR_BOTH
                for cdy = -2, 2 do
                    for cdx = -2, 2 do
                        if cdx ~= 0 or cdy ~= 0 then
                            local cnx, cny = x + cdx, y + cdy
                            if cnx >= 0 and cnx < mapW and cny >= 0 and cny < mapH then
                                local cni = cny * mapW + cnx + 1
                                if layer1.tiles[cni] == Tiles.UNDERGROUND_ROCK then
                                    layer1.tiles[cni] = Tiles.UNDERGROUND_FLOOR
                                end
                            end
                        end
                    end
                end
            end
        end
        -- Verify layer below exists and tile below connects up or is walkable
        local L = _layer(depth + 1)
        if L then
            local belowTile = L.tiles[_idx(x, y)]
            if belowTile and (Tiles.connectsUp(belowTile) or Tiles.isWalkable(belowTile)) then
                down = depth + 1
            end
        end
    end

    return up, down
end

-- Legacy compat: get the depth of a shaft's other end
function Tilemap.getShaftTarget(x, y, depth)
    depth = depth or 0
    local tile = Tilemap.getTile(x, y, depth)
    if not Tiles.connectsVertical(tile) then return nil end
    local up, down = Tilemap.getVerticalTargets(x, y, depth)
    return up or down
end

---------------------------------------------------------------------------
-- Chunk queries (for rendering culling)
---------------------------------------------------------------------------

function Tilemap.getVisibleRange(camX, camY, camW, camH, zoom)
    local x1 = math.max(0, math.floor(camX / TILE_SIZE) - 1)
    local y1 = math.max(0, math.floor(camY / TILE_SIZE) - 1)
    local x2 = math.min(mapW - 1, math.floor((camX + camW / zoom) / TILE_SIZE) + 1)
    local y2 = math.min(mapH - 1, math.floor((camY + camH / zoom) / TILE_SIZE) + 1)
    return x1, y1, x2, y2
end

---------------------------------------------------------------------------
-- Neighbor iteration (for thermal diffusion)
---------------------------------------------------------------------------

function Tilemap.neighbors4(x, y)
    local i = 0
    local dirs = { {-1,0}, {1,0}, {0,-1}, {0,1} }
    return function()
        while i < 4 do
            i = i + 1
            local nx, ny = x + dirs[i][1], y + dirs[i][2]
            if Tilemap.inBounds(nx, ny) then
                return nx, ny
            end
        end
    end
end

---------------------------------------------------------------------------
-- Raw data access (for thermal sim bulk operations)
-- Optional depth param; default 0 returns surface arrays.
---------------------------------------------------------------------------

function Tilemap.rawTileData(depth)
    local L = _layer(depth)
    return L and L.tiles or tileData
end

function Tilemap.rawTempData(depth)
    local L = _layer(depth)
    return L and L.temps or tempData
end

function Tilemap.rawRoomData(depth)
    local L = _layer(depth)
    return L and L.rooms or roomData
end

function Tilemap.rawIndex(x, y) return _idx(x, y) end

-- Iterate all depth layers: returns depth, layer pairs
function Tilemap.allLayers()
    local d = -1
    return function()
        d = d + 1
        while d <= maxDepth do
            if layers[d] then return d, layers[d] end
            d = d + 1
        end
    end
end

---------------------------------------------------------------------------
-- Persistence helpers
---------------------------------------------------------------------------

function Tilemap.getLayerData()
    local data = { w = mapW, h = mapH, seed = mapSeed, maxDepth = maxDepth, layers = {} }
    for depth = 0, maxDepth do
        if layers[depth] then
            data.layers[depth] = {
                tiles = layers[depth].tiles,
                temps = layers[depth].temps,
                rooms = layers[depth].rooms,
                water = layers[depth].water,
                gas   = layers[depth].gas,
                snow  = layers[depth].snow,
            }
        end
    end
    return data
end

function Tilemap.loadLayerData(data)
    if not data then return end
    mapW = data.w or mapW
    mapH = data.h or mapH
    mapSeed = data.seed or 0
    maxDepth = data.maxDepth or 0
    layers = {}
    if data.layers then
        for depth, ldata in pairs(data.layers) do
            layers[depth] = {
                tiles = ldata.tiles or {},
                temps = ldata.temps or {},
                rooms = ldata.rooms or {},
                water = ldata.water or {},
                gas   = ldata.gas   or {},
                snow  = ldata.snow  or {},
            }
        end
    end
    -- Update convenience refs
    if layers[0] then
        tileData = layers[0].tiles
        tempData = layers[0].temps
        roomData = layers[0].rooms
    end
end

---------------------------------------------------------------------------
-- Door lock toggle (simple replacement for circuit-based door locking)
---------------------------------------------------------------------------

function Tilemap.isDoorLocked(x, y)
    return lockedDoors[doorKey(x, y)] == true
end

function Tilemap.setDoorLocked(x, y, locked)
    local dk = doorKey(x, y)
    if locked then
        lockedDoors[dk] = true
    else
        lockedDoors[dk] = nil
    end
end

function Tilemap.toggleDoorLock(x, y)
    local dk = doorKey(x, y)
    if lockedDoors[dk] then
        lockedDoors[dk] = nil
    else
        lockedDoors[dk] = true
    end
    return lockedDoors[dk] == true
end

function Tilemap.getLockedDoors()
    return lockedDoors
end

function Tilemap.setLockedDoors(data)
    lockedDoors = data or {}
end

---------------------------------------------------------------------------
-- Lightweight biome sampling — runs noise without generating tiles.
-- Used by the landing site preview screen to color-code world regions.
-- Returns: biome (string), elevation (0-1), moisture (0-1)
---------------------------------------------------------------------------

function Tilemap.sampleBiome(x, y, seed, w, h)
    local nx = x / w
    local ny = y / h
    local elevation = love.math.noise(nx * 6 + seed, ny * 6 + seed)
    local moisture  = love.math.noise(nx * 4 + seed + 100, ny * 4 + seed + 100)
    local biomeN    = love.math.noise(nx * 3.5 + seed + 400, ny * 3.5 + seed + 400)

    local biome = 'default'
    if biomeN < 0.2 and elevation < 0.55 then
        biome = 'marsh'
    elseif biomeN < 0.38 and moisture > 0.45 and elevation < 0.65 then
        biome = 'frozen_forest'
    elseif biomeN > 0.78 and elevation > 0.45 then
        biome = 'volcanic'
    elseif biomeN > 0.62 and elevation > 0.4 and elevation < 0.72 then
        biome = 'dead_forest'
    elseif elevation > 0.68 and moisture > 0.6 then
        biome = 'glacier'
    end

    return biome, elevation, moisture
end

return Tilemap
