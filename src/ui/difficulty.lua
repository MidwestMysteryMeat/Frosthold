-- difficulty.lua -- Difficulty settings applied at game start
-- Settings are not changeable mid-game. Presets and custom sliders.
-- Stored in GameState so they persist through save/load.

local GameState = require('src.game_state')

local Difficulty = {}

---------------------------------------------------------------------------
-- Presets
---------------------------------------------------------------------------

Difficulty.PRESETS = {
    story = {
        name        = 'Story Mode',
        baseTemp    = -15,
        creatures   = 0.4,
        weather     = 0.5,
        disease     = 0.4,
        resources   = 1.8,
        storyteller = 'watcher',
        desc        = 'A forgiving Erebus. Lighter raids, softer weather, slower disease, and surplus supplies so the colony can recover from mistakes.',
    },
    easy = {
        name        = 'Stable Orbit',
        baseTemp    = -25,
        creatures   = 0.6,
        weather     = 0.8,
        disease     = 0.7,
        resources   = 1.4,
        storyteller = 'chronicler',
        desc        = 'Warmer weather, smaller wildlife packs, and steadier cargo from orbit.',
    },
    normal = {
        name        = 'Standard Deployment',
        baseTemp    = -40,
        creatures   = 1.0,
        weather     = 1.0,
        disease     = 1.0,
        resources   = 1.0,
        storyteller = 'chronicler',
        desc        = 'Baseline Erebus. Cold ground, hungry wildlife, and no spare cushion.',
    },
    hard = {
        name        = 'Deep Freeze',
        baseTemp    = -50,
        creatures   = 1.5,
        weather     = 1.2,
        disease     = 1.15,
        resources   = 0.7,
        storyteller = 'tyrant',
        desc        = 'Long cold snaps, meaner wildlife, and leaner supply drops.',
    },
    brutal = {
        name        = 'Awakening',
        baseTemp    = -60,
        creatures   = 2.0,
        weather     = 1.4,
        disease     = 1.3,
        resources   = 0.5,
        storyteller = 'tyrant',
        desc        = 'The cold bites from day one and every mistake sticks.',
    },
}

-- Ordered keys for deterministic UI rendering
Difficulty.PRESET_ORDER = { 'story', 'easy', 'normal', 'hard', 'brutal' }

---------------------------------------------------------------------------
-- Scenario definitions — delegated to planet_scenarios.lua
-- Difficulty.SCENARIOS / SCENARIO_ORDER are computed from the active planet.
---------------------------------------------------------------------------

local PlanetScenarios = require('src.world.planet_scenarios')

--- Returns scenarios and order for the given planet (defaults to current).
function Difficulty.getScenariosForPlanet(planetId)
    planetId = planetId or (GameState.planet or 'erebus')
    return PlanetScenarios.getScenariosForPlanet(planetId),
           PlanetScenarios.getScenarioOrder(planetId)
end

-- Backwards-compatible tables: point at Erebus scenarios by default.
-- start_menu.lua reads these for iteration.
Difficulty.SCENARIOS = PlanetScenarios.getScenariosForPlanet('erebus')
Difficulty.SCENARIO_ORDER = PlanetScenarios.getScenarioOrder('erebus')

--- Refresh SCENARIOS/SCENARIO_ORDER tables for a specific planet.
--- Called by start_menu when the player picks a planet.
function Difficulty.setPlanetScenarios(planetId)
    Difficulty.SCENARIOS = PlanetScenarios.getScenariosForPlanet(planetId)
    Difficulty.SCENARIO_ORDER = PlanetScenarios.getScenarioOrder(planetId)
end

---------------------------------------------------------------------------
-- AI Director definitions (references storyteller personalities)
---------------------------------------------------------------------------

Difficulty.DIRECTORS = {
    watcher    = { name = 'HERMES - Stable',    desc = 'Longer gaps between incidents and fewer stacked crises.' },
    chronicler = { name = 'HERMES - Standard',  desc = 'Steady pressure with enough time to patch the damage.' },
    tyrant     = { name = 'HERMES - Aggressive', desc = 'Short lulls, harder hits, and faster escalation.' },
    silence    = { name = 'HERMES - Dormant',   desc = 'Long quiet stretches, then a concentrated blow.' },
    maelstrom  = { name = 'HERMES - Corrupted', desc = 'Erratic pacing with broken patterns and rough prediction.' },
}

Difficulty.DIRECTOR_ORDER = { 'watcher', 'chronicler', 'tyrant', 'silence', 'maelstrom' }

---------------------------------------------------------------------------
-- Current settings (defaults to Normal)
---------------------------------------------------------------------------

-- Map size options
Difficulty.MAP_SIZES = { 128, 256, 512 }
Difficulty.MAP_SIZE_NAMES = { [128] = 'Small (128)', [256] = 'Medium (256)', [512] = 'Large (512)' }

local settings = {
    preset     = 'normal',
    baseTemp   = -40,
    creatures  = 1.0,    -- creature aggression multiplier (0.5x - 2.0x)
    weather    = 1.0,    -- weather severity multiplier (0.5x - 1.5x)
    disease    = 1.0,    -- disease severity multiplier (0.5x - 1.5x)
    resources  = 1.0,    -- resource yield multiplier (0.5x - 2.0x)
    storyteller = 'chronicler',
    scenario   = 'crashlanded',
    fogOfWar   = true,   -- Factorio-style fog of war (default on)
    safetyNet  = true,   -- Mammona one-time rescue when all colonists die
    mapSize    = 128,     -- 128, 256, or 512
}

---------------------------------------------------------------------------
-- Apply a preset
---------------------------------------------------------------------------

function Difficulty.applyPreset(presetName)
    local p = Difficulty.PRESETS[presetName]
    if not p then return end
    settings.preset     = presetName
    settings.baseTemp   = p.baseTemp
    settings.creatures  = p.creatures
    settings.weather    = p.weather or 1.0
    settings.disease    = p.disease or 1.0
    settings.resources  = p.resources
    settings.storyteller = p.storyteller
end

---------------------------------------------------------------------------
-- Custom sliders
---------------------------------------------------------------------------

function Difficulty.setBaseTemp(temp)
    settings.baseTemp = math.max(-60, math.min(-20, temp))
    settings.preset = 'custom'
end

function Difficulty.setCreatureAggression(mult)
    settings.creatures = math.max(0.5, math.min(2.0, mult))
    settings.preset = 'custom'
end

function Difficulty.setRaidPressure(mult)
    Difficulty.setCreatureAggression(mult)
end

function Difficulty.setWeatherHarshness(mult)
    settings.weather = math.max(0.5, math.min(1.5, mult))
    settings.preset = 'custom'
end

function Difficulty.setDiseasePressure(mult)
    settings.disease = math.max(0.5, math.min(1.5, mult))
    settings.preset = 'custom'
end

function Difficulty.setResourceScarcity(mult)
    settings.resources = math.max(0.5, math.min(2.0, mult))
    settings.preset = 'custom'
end

function Difficulty.setStoryteller(name)
    if Difficulty.DIRECTORS[name] then
        settings.storyteller = name
    end
end

function Difficulty.setScenario(name)
    if Difficulty.SCENARIOS[name] then
        settings.scenario = name
    end
end

function Difficulty.configure(config)
    config = config or {}
    if config.preset and Difficulty.PRESETS[config.preset] then
        Difficulty.applyPreset(config.preset)
    else
        settings.preset = 'custom'
    end

    if config.baseTemp ~= nil then
        settings.baseTemp = math.max(-60, math.min(-20, config.baseTemp))
    end
    if config.creatures ~= nil then
        settings.creatures = math.max(0.5, math.min(2.0, config.creatures))
    end
    if config.weather ~= nil then
        settings.weather = math.max(0.5, math.min(1.5, config.weather))
    end
    if config.disease ~= nil then
        settings.disease = math.max(0.5, math.min(1.5, config.disease))
    end
    if config.resources ~= nil then
        settings.resources = math.max(0.5, math.min(2.0, config.resources))
    end
    if config.storyteller ~= nil then
        settings.storyteller = Difficulty.DIRECTORS[config.storyteller] and config.storyteller or settings.storyteller
    end
    if config.scenario ~= nil and Difficulty.SCENARIOS[config.scenario] then
        settings.scenario = config.scenario
    end
    if config.safetyNet ~= nil then
        settings.safetyNet = (config.safetyNet ~= false)
    end
    if config.fogOfWar ~= nil then
        settings.fogOfWar = (config.fogOfWar ~= false)
    end
    if config.mapSize ~= nil then
        Difficulty.setMapSize(config.mapSize)
    end

    if config.presetName then
        settings.preset = config.presetName
    elseif not (config.preset and Difficulty.PRESETS[config.preset]) then
        settings.preset = 'custom'
    end
end

function Difficulty.getScenario()
    return settings.scenario
end

---------------------------------------------------------------------------
-- Apply to GameState (call once at game start, before first tick)
---------------------------------------------------------------------------

function Difficulty.apply()
    local normalBaseTemp = (Difficulty.PRESETS.normal and Difficulty.PRESETS.normal.baseTemp) or -40

    -- Base temperature
    GameState.tempBias   = settings.baseTemp - normalBaseTemp
    GameState.baseTemp   = settings.baseTemp
    GameState.globalTemp = settings.baseTemp

    -- Map size
    local ms = settings.mapSize or 128
    GameState.mapWidth  = ms
    GameState.mapHeight = ms
    if not GameState.landingSiteSelected then
        GameState.startX = math.floor(ms / 2)
        GameState.startY = math.floor(ms / 2)
    end

    -- Store multipliers so other systems can read them
    GameState.creatureAggression = settings.creatures
    GameState.weatherHarshness   = settings.weather
    GameState.diseasePressure    = settings.disease
    GameState.resourceScarcity   = settings.resources
    GameState.fogOfWar           = settings.fogOfWar
    GameState.mammonaSafetyNet   = settings.safetyNet

    -- Storyteller personality
    local Storyteller = require('src.storyteller.storyteller')
    Storyteller.init(settings.storyteller)

    -- Adjust starting resources by scarcity multiplier
    for res, amount in pairs(GameState.resources) do
        GameState.resources[res] = math.floor(amount * settings.resources)
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Difficulty.getSettings()
    return settings
end

function Difficulty.getPresetName()
    return settings.preset
end

function Difficulty.getBaseTemp()
    return settings.baseTemp
end

function Difficulty.getCreatureAggression()
    return settings.creatures
end

function Difficulty.getRaidPressure()
    return settings.creatures
end

function Difficulty.getWeatherHarshness()
    return settings.weather
end

function Difficulty.getDiseasePressure()
    return settings.disease
end

function Difficulty.getResourceScarcity()
    return settings.resources
end

function Difficulty.getStoryteller()
    return settings.storyteller
end

function Difficulty.setMapSize(size)
    -- Validate
    for _, valid in ipairs(Difficulty.MAP_SIZES) do
        if size == valid then
            settings.mapSize = size
            return
        end
    end
end

function Difficulty.getMapSize()
    return settings.mapSize or 128
end

function Difficulty.setFogOfWar(enabled)
    settings.fogOfWar = (enabled ~= false)
end

function Difficulty.getFogOfWar()
    return settings.fogOfWar
end

function Difficulty.setSafetyNet(enabled)
    settings.safetyNet = (enabled ~= false)
end

function Difficulty.getSafetyNet()
    return settings.safetyNet
end

---------------------------------------------------------------------------
-- UI draw helper (for a settings screen before game starts)
---------------------------------------------------------------------------

function Difficulty.draw(x, y)
    local font = love.graphics.getFont()
    local lineH = font:getHeight() + 4

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print('-- Difficulty Settings --', x, y)
    y = y + lineH * 1.5

    -- Presets
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print('Presets:', x, y)
    y = y + lineH
    for pid, p in pairs(Difficulty.PRESETS) do
        if pid == settings.preset then
            love.graphics.setColor(0.3, 0.9, 0.4)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        love.graphics.print(string.format('  [%s] %s  (%.0f C, raid x%.1f, weather x%.1f, disease x%.1f, resources x%.1f, %s)',
            pid, p.name, p.baseTemp, p.creatures, p.weather or 1.0, p.disease or 1.0, p.resources, p.storyteller), x, y)
        y = y + lineH
    end

    y = y + lineH * 0.5
    love.graphics.setColor(0.8, 0.85, 0.9)
    love.graphics.print(string.format('Current: %s  |  Temp: %.0f C  |  Raid: x%.1f  |  Weather: x%.1f  |  Disease: x%.1f  |  Resources: x%.1f  |  AI: %s',
        settings.preset, settings.baseTemp, settings.creatures, settings.weather, settings.disease, settings.resources, settings.storyteller), x, y)
end

-- Apply scenario resources (call after Difficulty.apply() to override with scenario-specific resources)
function Difficulty.applyScenario()
    local scenDef = Difficulty.SCENARIOS[settings.scenario]
    if not scenDef then return end

    -- Override starting resources from scenario
    for res, amount in pairs(scenDef.resources) do
        GameState.resources[res] = math.floor(amount * settings.resources)
    end

    -- Store scenario info for colonist spawning
    GameState.scenario = settings.scenario
    GameState.director = settings.storyteller
end

-- Init to Normal by default
Difficulty.applyPreset('normal')

return Difficulty
