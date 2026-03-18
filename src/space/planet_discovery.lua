-- planet_discovery.lua — Planet discovery mechanic
-- Tracks which planets the player has discovered in-fiction.
-- Starting planet is auto-discovered. Others found via star charts,
-- NexLink data, sensor detection, or lore fragments.

local GameState = require('src.game_state')

local PlanetDiscovery = {}

---------------------------------------------------------------------------
-- All discoverable planets
---------------------------------------------------------------------------

local ALL_PLANETS = { 'erebus', 'rhea_2', 'morvos', 'nerthus_9', 'paxtera_prime', 'nemaea', 'gaia_a1x' }

---------------------------------------------------------------------------
-- Discovery methods
---------------------------------------------------------------------------

function PlanetDiscovery.discoverPlanet(planetId)
    if not GameState.discoveredPlanets then
        GameState.discoveredPlanets = {}
    end
    if GameState.discoveredPlanets[planetId] then return false end

    GameState.discoveredPlanets[planetId] = true

    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        local pok, PlanetDefs = pcall(require, 'src.world.planet_defs')
        local name = planetId
        if pok then
            local def = PlanetDefs.get(planetId)
            if def then name = def.name end
        end
        Alerts.send('DISCOVERY', 'Planet discovered: ' .. name .. '!')
    end

    return true
end

function PlanetDiscovery.isDiscovered(planetId)
    return GameState.discoveredPlanets and GameState.discoveredPlanets[planetId] == true
end

function PlanetDiscovery.getDiscoveredPlanets()
    local result = {}
    if not GameState.discoveredPlanets then return result end
    for _, planetId in ipairs(ALL_PLANETS) do
        if GameState.discoveredPlanets[planetId] then
            result[#result + 1] = planetId
        end
    end
    return result
end

function PlanetDiscovery.getUndiscoveredCount()
    local discovered = 0
    if GameState.discoveredPlanets then
        for _, planetId in ipairs(ALL_PLANETS) do
            if GameState.discoveredPlanets[planetId] then
                discovered = discovered + 1
            end
        end
    end
    return #ALL_PLANETS - discovered
end

---------------------------------------------------------------------------
-- Sensor detection (call when player moves in space)
---------------------------------------------------------------------------

local GRAVITY_WELL_DETECT_RANGE = 50  -- tiles from planet orbit to detect

function PlanetDiscovery.checkSensorDetection(playerX, playerY)
    local pok, POIGen = pcall(require, 'src.space.poi_generator')
    if not pok then return end

    local positions = POIGen.getAllPlanetPositions()
    for planetId, pos in pairs(positions) do
        if not PlanetDiscovery.isDiscovered(planetId) then
            local dx = pos.x - playerX
            local dy = pos.y - playerY
            if math.sqrt(dx * dx + dy * dy) <= GRAVITY_WELL_DETECT_RANGE then
                PlanetDiscovery.discoverPlanet(planetId)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Lore fragment discovery
---------------------------------------------------------------------------

local loreFragments = {}  -- { [planetId] = count }
local FRAGMENTS_TO_DISCOVER = 3

function PlanetDiscovery.addLoreFragment(planetId)
    if PlanetDiscovery.isDiscovered(planetId) then return false end

    loreFragments[planetId] = (loreFragments[planetId] or 0) + 1
    if loreFragments[planetId] >= FRAGMENTS_TO_DISCOVER then
        PlanetDiscovery.discoverPlanet(planetId)
        return true
    end

    local alOk, Alerts = pcall(require, 'src.ui.alerts')
    if alOk and Alerts.send then
        local remaining = FRAGMENTS_TO_DISCOVER - loreFragments[planetId]
        Alerts.send('DISCOVERY', 'Lore fragment found for ' .. planetId .. '. ' .. remaining .. ' more to reveal location.')
    end
    return false
end

---------------------------------------------------------------------------
-- Ensure starting planet is discovered
---------------------------------------------------------------------------

function PlanetDiscovery.init()
    if not GameState.discoveredPlanets then
        GameState.discoveredPlanets = {}
    end
    local startPlanet = GameState.planet or 'erebus'
    if startPlanet ~= 'space' then
        GameState.discoveredPlanets[startPlanet] = true
    end
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function PlanetDiscovery.getState()
    return {
        loreFragments = loreFragments,
    }
end

function PlanetDiscovery.loadState(state)
    if not state then return end
    loreFragments = state.loreFragments or {}
end

PlanetDiscovery.ALL_PLANETS = ALL_PLANETS

return PlanetDiscovery
