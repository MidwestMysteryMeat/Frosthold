-- planet.lua — Singleton API for the active planet
-- Other systems call Planet.get() to read planet-specific config.
-- If a field is nil, callers use their own defaults (Erebus behavior).

local Planet = {}

local activeDef = nil
local activeId  = nil

---------------------------------------------------------------------------
-- Init — loads planet def, applies Tuning overrides, sets GameState.planet
---------------------------------------------------------------------------

function Planet.init(planetId)
    planetId = planetId or 'erebus'

    local PlanetDefs = require('src.world.planet_defs')
    local def = PlanetDefs.get(planetId)
    if not def then
        print('[Planet] Unknown planet: ' .. tostring(planetId) .. ', falling back to erebus')
        planetId = 'erebus'
        def = PlanetDefs.get('erebus')
    end

    activeDef = def
    activeId  = planetId

    -- Store on GameState
    local GameState = require('src.game_state')
    GameState.planet = planetId

    -- Apply Tuning overrides from planet def
    if def.tuning then
        local tok, Tuning = pcall(require, 'src.sim.tuning')
        if tok then
            Tuning.applyOverrides(def.tuning)
        end
    end
end

---------------------------------------------------------------------------
-- Getters
---------------------------------------------------------------------------

function Planet.getId()
    return activeId or 'erebus'
end

function Planet.getDef()
    return activeDef
end

--- Dot-path getter into the active planet def.
--- e.g. Planet.get('atmosphere.ambientO2', 100)
function Planet.get(field, fallback)
    if not activeDef then return fallback end
    if not field or field == '' then return fallback end

    local cursor = activeDef
    for part in tostring(field):gmatch('[^%.]+') do
        if type(cursor) ~= 'table' then
            return fallback
        end
        cursor = cursor[part]
        if cursor == nil then
            return fallback
        end
    end
    return cursor
end

--- Returns planet season defs or nil (use Erebus defaults).
function Planet.getSeasons()
    if not activeDef then return nil end
    return activeDef.seasons
end

--- Returns planet weather type overrides or nil.
function Planet.getWeatherTypes()
    if not activeDef then return nil end
    return activeDef.weatherTypes
end

--- Returns creature pool filter list or nil (use all species).
function Planet.getCreaturePools()
    if not activeDef then return nil end
    return activeDef.creatures and activeDef.creatures.pools or nil
end

--- Returns planet biome profile or nil.
function Planet.getBiomeProfile()
    if not activeDef then return nil end
    return activeDef.tilemap and activeDef.tilemap.biomeProfile or nil
end

--- Returns planet secret types override or nil.
function Planet.getSecretTypes()
    if not activeDef then return nil end
    return activeDef.secrets and activeDef.secrets.types or nil
end

--- Returns planet endgame buildings or nil (all 4).
function Planet.getEndgameBuildings()
    if not activeDef then return nil end
    return activeDef.endgame and activeDef.endgame.buildings or nil
end

--- Returns scenarios valid for this planet.
function Planet.getScenarios()
    if not activeDef then return nil end
    return activeDef.scenarios
end

return Planet
