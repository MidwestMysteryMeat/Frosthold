-- poi_generator.lua — Procedural placement of space Points of Interest
-- Generates stations, derelicts, and other locations from world seed.
-- Planet positions are fixed anchors. Everything else is procedural per playthrough.

local GameState = require('src.game_state')

local POIGenerator = {}

---------------------------------------------------------------------------
-- POI type definitions
---------------------------------------------------------------------------

local POI_TYPES = {
    -- Planets (fixed anchor positions)
    planet_orbit = {
        subtypes = { 'erebus', 'rhea_2', 'morvos', 'nerthus_9', 'paxtera_prime', 'nemaea', 'gaia_a1x' },
    },

    -- UTC Ranger Outposts (safe harbors)
    utc_outpost = {
        count = { min = 3, max = 5 },
        name = 'UTC Ranger Outpost',
        services = { 'repair', 'refuel', 'trade', 'bounty_board', 'star_charts' },
        safeZone = true,
        faction = 'utc',
    },

    -- Pirate Stations (Edge of Oblivion)
    pirate_station_black_maw = {
        count = { min = 1, max = 2 },
        name = 'Black Maw Fortress',
        services = { 'black_market', 'repair', 'crew_recruitment' },
        safeZone = false,
        faction = 'black_maw',
    },
    pirate_station_void_serpents = {
        count = { min = 1, max = 2 },
        name = 'Void Serpent Den',
        services = { 'black_market', 'intel', 'crew_recruitment' },
        safeZone = false,
        faction = 'void_serpents',
    },
    pirate_station_rust_reavers = {
        count = { min = 1, max = 2 },
        name = 'Rust Reaver Junkyard',
        services = { 'salvage', 'repair', 'parts' },
        safeZone = false,
        faction = 'rust_reavers',
    },

    -- Corporate Orbitals
    starbyte_station = {
        count = { min = 2, max = 4 },
        name = 'StarByte Vending Station',
        services = { 'trade', 'morale_items' },
        safeZone = true,
        faction = 'mammona',
    },
    fortune_arms_depot = {
        count = { min = 1, max = 3 },
        name = 'Fortune Arms Depot',
        services = { 'weapons', 'ammo', 'combat_suits' },
        safeZone = true,
        faction = 'utc',
    },
    omnicorp_freight_hub = {
        count = { min = 2, max = 4 },
        name = 'OmniCorp Freight Hub',
        services = { 'bulk_trade', 'shipping_contracts' },
        safeZone = true,
        faction = 'utc',
    },
    terragen_medical = {
        count = { min = 1, max = 2 },
        name = 'TerraGen Medical Station',
        services = { 'medicine', 'surgery', 'prosthetics' },
        safeZone = true,
        faction = 'utc',
    },
    nexlink_relay = {
        count = { min = 2, max = 3 },
        name = 'NexLink Relay Hub',
        services = { 'comms_upgrade', 'star_charts', 'messages' },
        safeZone = true,
        faction = 'utc',
    },
    mammona_depot = {
        count = { min = 2, max = 3 },
        name = 'Mammona Logistics Depot',
        services = { 'quota_submission', 'supply_requisition', 'corporate_missions' },
        safeZone = true,
        faction = 'mammona',
    },

    -- Vanguard Alliance inner rim presence
    vanguard_outpost = {
        count = { min = 1, max = 2 },
        name = 'Vanguard Alliance Outpost',
        services = { 'trade', 'star_charts', 'bounty_board' },
        safeZone = true,
        faction = 'utc',
    },

    -- Unique named stations
    orbit_hub_71 = {
        count = { min = 1, max = 1 },
        name = 'Orbit Hub 71',
        services = { 'trade', 'repair', 'crew_recruitment' },
        safeZone = true,
        faction = 'independent',
        unique = true,
    },

    -- Derelicts (many, scattered)
    derelict = {
        count = { min = 15, max = 30 },
        name = 'Derelict',
        services = {},
        safeZone = false,
        faction = nil,
        subtypes = { 'mammona_cargo', 'pirate_raider', 'utc_patrol', 'pre_fortuna_surveyor', 'unknown_freighter' },
    },
}

---------------------------------------------------------------------------
-- Fixed planet positions (anchor points in space tilemap coordinates)
-- Spread across a large area so travel between them is meaningful
---------------------------------------------------------------------------

local PLANET_POSITIONS = {
    erebus       = { x = 0,    y = 0 },
    rhea_2       = { x = 800,  y = -400 },
    morvos       = { x = -600, y = 700 },
    nerthus_9    = { x = 400,  y = 900 },
    paxtera_prime = { x = -900, y = -300 },
    nemaea       = { x = 1200, y = 500 },
    gaia_a1x     = { x = -200, y = -1100 },
}

---------------------------------------------------------------------------
-- Generation
---------------------------------------------------------------------------

local function hashPosition(seed, index)
    local s = seed + index * 2654435761
    s = s % 2147483647
    s = ((s * 1103515245) + 12345) % 2147483647
    return s
end

function POIGenerator.generate(worldSeed)
    local pois = {}
    local seed = worldSeed or GameState.worldSeedNumeric or 12345
    local poiIndex = 0

    -- 1. Planet orbits (fixed positions)
    for planetId, pos in pairs(PLANET_POSITIONS) do
        local id = 'planet_' .. planetId
        pois[id] = {
            id = id,
            type = 'planet_orbit',
            subtype = planetId,
            name = planetId:gsub('_', ' '):gsub('(%a)([%w_]*)', function(a, b) return a:upper() .. b end) .. ' Orbit',
            x = pos.x,
            y = pos.y,
            faction = nil,
            services = { 'land' },
            safeZone = false,
            visited = false,
        }
    end

    -- 2. Generate procedural POIs
    for poiType, def in pairs(POI_TYPES) do
        if poiType ~= 'planet_orbit' then
            local count = def.count and (def.count.min + (hashPosition(seed, poiIndex) % (def.count.max - def.count.min + 1))) or 1
            for i = 1, count do
                poiIndex = poiIndex + 1
                local h1 = hashPosition(seed, poiIndex * 3)
                local h2 = hashPosition(seed, poiIndex * 3 + 1)

                -- Position: spread across the map, avoid planet positions
                local px = (h1 % 3000) - 1500
                local py = (h2 % 3000) - 1500

                local subtype = nil
                if def.subtypes then
                    local si = (hashPosition(seed, poiIndex * 7) % #def.subtypes) + 1
                    subtype = def.subtypes[si]
                end

                local namePrefix = def.name
                if subtype and poiType == 'derelict' then
                    local subtypeNames = {
                        mammona_cargo = 'Mammona Cargo Wreck',
                        pirate_raider = 'Gutted Raider Hull',
                        utc_patrol = 'UTC Patrol Wreckage',
                        pre_fortuna_surveyor = 'Pre-Fortuna Survey Vessel',
                        unknown_freighter = 'Unknown Freighter',
                    }
                    namePrefix = subtypeNames[subtype] or 'Derelict'
                end

                local id = poiType .. '_' .. i
                pois[id] = {
                    id = id,
                    type = poiType,
                    subtype = subtype,
                    name = namePrefix .. (count > 1 and (' ' .. i) or ''),
                    x = px,
                    y = py,
                    faction = def.faction,
                    services = def.services or {},
                    safeZone = def.safeZone or false,
                    visited = false,
                }
            end
        end
    end

    return pois
end

---------------------------------------------------------------------------
-- Initialize POIs for a new game (or lazy-init on first space entry)
---------------------------------------------------------------------------

function POIGenerator.ensureGenerated()
    if not GameState.discoveredPOIs or not next(GameState.discoveredPOIs) then
        GameState.discoveredPOIs = POIGenerator.generate(GameState.worldSeedNumeric)
    end
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function POIGenerator.getPOIsInRange(x, y, radius)
    POIGenerator.ensureGenerated()
    local result = {}
    for id, poi in pairs(GameState.discoveredPOIs) do
        local dx = poi.x - x
        local dy = poi.y - y
        if dx * dx + dy * dy <= radius * radius then
            result[#result + 1] = poi
        end
    end
    return result
end

function POIGenerator.getNearestPOI(x, y, poiType)
    POIGenerator.ensureGenerated()
    local best, bestDist = nil, math.huge
    for id, poi in pairs(GameState.discoveredPOIs) do
        if not poiType or poi.type == poiType then
            local dx = poi.x - x
            local dy = poi.y - y
            local dist = dx * dx + dy * dy
            if dist < bestDist then
                best = poi
                bestDist = dist
            end
        end
    end
    return best, math.sqrt(bestDist)
end

function POIGenerator.getPlanetPosition(planetId)
    return PLANET_POSITIONS[planetId]
end

function POIGenerator.getAllPlanetPositions()
    return PLANET_POSITIONS
end

POIGenerator.POI_TYPES = POI_TYPES
POIGenerator.PLANET_POSITIONS = PLANET_POSITIONS

return POIGenerator
