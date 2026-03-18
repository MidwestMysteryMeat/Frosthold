-- context_swap.lua — Orchestrates colony <-> space transitions
-- Uses Save.snapshotToMemory / loadFromMemory for clean ECS context swap.
-- No multi-ECS instance needed — we serialize one world, destroy it, load another.

local GameState = require('src.game_state')

local ContextSwap = {}

---------------------------------------------------------------------------
-- Calculate automation score from a colony snapshot
---------------------------------------------------------------------------

local function calculateAutomationScore(snapshot)
    if not snapshot or not snapshot.entities then return 0 end

    local conveyors = 0
    local inserters = 0
    local machines  = 0
    local farms     = 0
    local powerSurplus = 0

    for _, ent in ipairs(snapshot.entities) do
        if ent.inserter then inserters = inserters + 1 end
        if ent.machine and ent.machine.recipe then machines = machines + 1 end
        if ent.crop and ent.crop.cropId then farms = farms + 1 end
    end

    -- Conveyor count from saved belt data
    if snapshot.conveyors and snapshot.conveyors.belts then
        for _ in pairs(snapshot.conveyors.belts) do
            conveyors = conveyors + 1
        end
    end

    -- Power surplus approximation from generator count
    if snapshot.power and snapshot.power.generators then
        for _ in pairs(snapshot.power.generators) do
            powerSurplus = powerSurplus + 50
        end
    end

    local score = (
        conveyors * 0.01 +
        inserters * 0.05 +
        machines * 0.1 +
        farms * 0.08 +
        math.max(0, powerSurplus / 100) * 0.1
    )

    return math.min(1.0, math.max(0, score))
end

---------------------------------------------------------------------------
-- Colony -> Space (launch from planet)
---------------------------------------------------------------------------

function ContextSwap.launchToSpace(colonyId, shipSnapshot)
    local sok, Save = pcall(require, 'src.persistence.save')
    if not sok then return false end

    -- 1. Snapshot current colony
    local colonySnapshot = Save.snapshotToMemory()
    local automationScore = calculateAutomationScore(colonySnapshot)

    -- 2. Store in colonies registry
    GameState.colonies[colonyId] = {
        planetId = GameState.planet,
        name = GameState.colonyName or ('Colony on ' .. GameState.planet),
        snapshot = colonySnapshot,
        automationScore = automationScore,
        lastTickDay = GameState.day,
    }

    -- 3. Switch to space context
    GameState.activeMap = 'space'
    GameState.planet = 'space'

    -- 4. Init space tilemap
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then Planet.init('space') end

    local stOk, SpaceTilemap = pcall(require, 'src.space.space_tilemap')
    if stOk then SpaceTilemap.init(GameState.worldSeedNumeric) end

    -- 4b. Stamp celestial bodies (stars, Dyson Sphere, gravity wells)
    local cbOk, CelestialBodies = pcall(require, 'src.space.celestial_bodies')
    if cbOk then CelestialBodies.stamp() end

    -- 4c. Ensure POIs are generated
    local poiOk, POIGen = pcall(require, 'src.space.poi_generator')
    if poiOk then POIGen.ensureGenerated() end

    -- 5. Load ship into fresh ECS context (skip tilemap — space uses chunks)
    if shipSnapshot then
        Save.loadFromMemory(shipSnapshot, true)
        -- IMPORTANT: loadFromMemory restores GameState from the snapshot,
        -- which may set activeMap/planet to old values. Override to space.
        GameState.activeMap = 'space'
        GameState.planet = 'space'
    end

    return true
end

---------------------------------------------------------------------------
-- Space -> Colony (land on planet)
---------------------------------------------------------------------------

function ContextSwap.landOnColony(colonyId)
    local colony = GameState.colonies[colonyId]
    if not colony or not colony.snapshot then return false end

    local sok, Save = pcall(require, 'src.persistence.save')
    if not sok then return false end

    -- 1. Snapshot ship state
    GameState.shipState = {
        snapshot = Save.snapshotToMemory(),
    }

    -- 2. Apply background tick to colony
    local bgOk, BackgroundColony = pcall(require, 'src.space.background_colony')
    if bgOk then
        local daysPassed = math.max(0, GameState.day - (colony.lastTickDay or GameState.day))
        if daysPassed > 0 then
            local log = BackgroundColony.tick(colony.snapshot, daysPassed, colony.automationScore)
            colony.lastTickDay = GameState.day
            GameState._backgroundLog = log
        end
        -- Spawn background production as physical items
        BackgroundColony.spawnProduction(colony.snapshot)
    end

    -- 3. Load colony context (with tilemap)
    Save.loadFromMemory(colony.snapshot, false)

    -- 4. Restore active map
    GameState.activeMap = colonyId
    GameState.planet = colony.planetId

    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then Planet.init(colony.planetId) end

    return true
end

---------------------------------------------------------------------------
-- New colony on a new planet (first landing)
---------------------------------------------------------------------------

function ContextSwap.landOnNewPlanet(planetId, colonyName)
    local sok, Save = pcall(require, 'src.persistence.save')
    if not sok then return false end

    -- 1. Snapshot ship state
    GameState.shipState = {
        snapshot = Save.snapshotToMemory(),
    }

    -- 2. Set up new game state for the planet
    GameState.planet = planetId
    GameState.activeMap = planetId .. '_' .. tostring(os.time())
    GameState.colonyName = colonyName or ('Colony on ' .. planetId)

    -- 3. Planet init will be handled by the normal new-game flow
    -- The caller should trigger world generation after this
    return GameState.activeMap
end

---------------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------------

function ContextSwap.isInSpace()
    return GameState.activeMap == 'space'
end

function ContextSwap.getColonyList()
    local list = {}
    for id, colony in pairs(GameState.colonies) do
        list[#list + 1] = {
            id = id,
            name = colony.name,
            planetId = colony.planetId,
            automationScore = colony.automationScore,
            lastTickDay = colony.lastTickDay,
        }
    end
    return list
end

ContextSwap.calculateAutomationScore = calculateAutomationScore

return ContextSwap
