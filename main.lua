-- FROSTHOLD — Frozen Planet Colony Survival
-- main.lua — Entry point, fixed timestep game loop
-- Two phases: 'setup' (pre-game menu) and 'playing' (simulation running).

local GameState      = require('src.game_state')
local PlanetSelect   = require('src.ui.planet_select')
local WorldMap       = require('src.ui.world_map')
local StartMenu      = require('src.ui.start_menu')
local Difficulty     = require('src.ui.difficulty')
local ColonistSelect = require('src.ui.colonist_select')
local Planet         = require('src.world.planet')

-- New pre-game flow screens (Tasks 6-11)
local MainMenu          = require('src.ui.main_menu')
local DifficultySelect  = require('src.ui.difficulty_select')
local CreateWorld       = require('src.ui.create_world')
local RequisitionPanel  = require('src.ui.requisition_panel')
local MRP               = require('src.sim.mrp')

-- All game modules (loaded eagerly so require() caching works, but only
-- initialized when the player clicks Start Colony).
local ECS         = require('src.ecs.ecs')
local World       = require('src.world.tilemap')
local Thermal     = require('src.sim.thermal')
local Weather     = require('src.weather.weather')
local Creatures   = require('src.creatures.creatures')
local Storyteller = require('src.storyteller.storyteller')
local Power       = require('src.sim.power')
local Production  = require('src.building.production')
local Occupancy   = require('src.util.occupancy')
local Profiler    = require('src.util.profiler')
local Camera      = require('src.render.camera')
local Renderer    = require('src.render.renderer')
local VFX         = require('src.render.vfx')
local Input       = require('src.ui.input')
local UI          = require('src.ui.ui')
local Building    = require('src.building.building')

local Atmosphere  = require('src.sim.atmosphere')
local Lighting    = require('src.sim.lighting')
local Rooms       = require('src.world.rooms')
local Foraging    = require('src.colonist.foraging')

local Hope        = require('src.colony.hope')
local Policies    = require('src.colony.policies')
local Doctrines   = require('src.colony.doctrines')

local Conveyors   = require('src.logistics.conveyors')
local Inserters   = require('src.logistics.inserters')
local Pipes       = require('src.logistics.pipes')
local Research    = require('src.research.research')
local Pollution   = require('src.sim.pollution')

local Expeditions = require('src.exploration.expeditions')
-- vehicles.lua cut (stubbed) -- expeditions work without vehicles
local Quest       = require('src.quest.quest')
local QuestPanel  = require('src.quest.quest_panel')

local Deterioration = require('src.sim.deterioration')
local Save        = require('src.persistence.save')
local Sound       = require('src.audio.sound')
local Minimap        = require('src.ui.minimap')
local Tutorial       = require('src.ui.tutorial')
local Advisor        = require('src.ui.advisor')
local SettingsPanel  = require('src.ui.settings_panel')

local Generator   = require('src.sim.generator')
local Disease     = require('src.sim.disease')
local Spoilage    = require('src.sim.spoilage')
local Merchants   = require('src.trade.merchants')

local Raids       = require('src.sim.raids')
local Recruitment = require('src.colonist.recruitment')

local StrangeMoods  = require('src.colonist.strange_moods')
local Factions      = require('src.colony.factions')
local History       = require('src.world.history')
local Hermes        = require('src.sim.hermes')
local EasterEggs    = require('src.sim.easter_eggs')
local Quotas        = require('src.sim.quotas')
local Containment   = require('src.sim.containment')
local Agriculture   = require('src.building.agriculture')
local Items         = require('src.world.items')
local ItemDecay     = require('src.world.item_decay')
local Equipment     = require('src.colonist.equipment')
local Jobs          = require('src.colonist.jobs')
local Recreation    = require('src.colonist.recreation')

local Elastic       = require('src.sim.elastic_difficulty')
local StatusFx      = require('src.sim.status_effects')
local Surgery       = require('src.medical.surgery')
-- slavery.lua cut (stubbed) -- prisoners are the depth system now
local Fire          = require('src.sim.fire')
local Radiation     = require('src.sim.radiation')
local Miners        = require('src.building.miners')
local EndgameSys    = require('src.sim.endgame')
local Filth         = require('src.sim.filth')
local Ordnance      = require('src.combat.ordnance')
local Defenses      = require('src.combat.defenses')
local Traps         = require('src.combat.traps')
local Taming        = require('src.creatures.taming')
local ThermoSpawn   = require('src.creatures.thermovore_spawner')
local EldritchNodes = require('src.creatures.eldritch_nodes')
local Visibility    = require('src.sim.visibility')
local Director      = require('src.ai.director')
local Raiders       = require('src.creatures.raiders')
local ExpView       = require('src.ui.expedition_view')
local Terraform     = require('src.world.terraform')
local TileFluids    = require('src.sim.tile_fluids')
local TileGas       = require('src.sim.tile_gas')
local TileSnow      = require('src.sim.tile_snow')
local Flooding      = require('src.sim.flooding')
local Pressure      = require('src.sim.pressure')
local Structural    = require('src.world.structural')
local BioCaves      = require('src.world.biocaves')
local Caverns       = require('src.world.caverns')
local ResearchPanel = require('src.ui.research_panel')
local PolicyPanel   = require('src.ui.policy_panel')
local DoctrinePanel = require('src.ui.doctrine_panel')
local TradePanel    = require('src.ui.trade_panel')
local FarmPanel     = require('src.ui.farm_panel')
local EquipPanel    = require('src.ui.equip_panel')
local GameOverScreen = require('src.ui.game_over')
local MedPanel       = require('src.ui.medical_panel')
local ColonyPanel    = require('src.ui.colony_panel')
local FactionPanel   = require('src.ui.faction_panel')
local LawsPanel      = require('src.ui.laws_panel')
local GoalsOverlay   = require('src.ui.goals_overlay')
local StarMap         = require('src.ui.star_map')
local BottomToolbar   = require('src.ui.bottom_toolbar')
local PanelManager    = require('src.ui.panel_manager')
local Seasons         = require('src.world.seasons')

local Corrosion     = require('src.sim.corrosion')
local Baldrungen    = require('src.sim.baldrungen')

local Autoplay = require('src.testing.autoplay')

local Optional = {}

local function loadOptional(path)
    local ok, mod = pcall(require, path)
    return ok and mod or false
end

local SimRunner = loadOptional('src.testing.run_simulation')
local UIShots   = loadOptional('src.testing.ui_shots')

-- Space UI panels (optional)
local ShipHUD         = loadOptional('src.ui.ship_hud')
local StationPanel    = loadOptional('src.ui.station_panel')
local CombatHUD       = loadOptional('src.ui.combat_hud')
local ContractsPanel  = loadOptional('src.ui.contracts_panel')
local TamingPanel     = loadOptional('src.ui.taming_panel')
local ShipyardPanel   = loadOptional('src.ui.shipyard_panel')

-- Interplanetary systems
local SpaceTilemap    = loadOptional('src.space.space_tilemap')
local ContextSwap     = loadOptional('src.space.context_swap')
local ShipMovement    = loadOptional('src.space.ship_movement')
local ShipManager     = loadOptional('src.space.ship_manager')
local BackgroundColony = loadOptional('src.space.background_colony')
local NPCShips        = loadOptional('src.space.npc_ships')
local Caravans        = loadOptional('src.space.caravans')
local POIGenerator    = loadOptional('src.space.poi_generator')
local StationDocking  = loadOptional('src.space.station_docking')
local SpaceEconomy    = loadOptional('src.space.space_economy')
local PlanetDiscovery = loadOptional('src.space.planet_discovery')
local ShipCombat      = loadOptional('src.space.ship_combat')
local Boarding        = loadOptional('src.space.boarding')
local Stealth         = loadOptional('src.space.stealth')
local SpaceHazards    = loadOptional('src.space.hazards')
local SpaceEvents     = loadOptional('src.space.space_events')
local EasterEggsSpace = loadOptional('src.space.easter_eggs_space')
local CelestialBodies = loadOptional('src.space.celestial_bodies')
local ShipConstruction = loadOptional('src.space.ship_construction')
local Milestones      = loadOptional('src.sim.milestones')

local function refreshOptionalModules()
    Optional.waterFeatures   = loadOptional('src.world.water_features')
    Optional.rivals          = loadOptional('src.sim.rivals')
    Optional.megabeasts      = loadOptional('src.creatures.megabeasts')
    Optional.mapSecrets      = loadOptional('src.world.map_secrets')
    Optional.colonyLegacy    = loadOptional('src.sim.colony_legacy')
    Optional.tradeRoutes     = loadOptional('src.trade.trade_routes')
    Optional.skinwalker      = loadOptional('src.creatures.skinwalker')
    Optional.thermalDeepening = loadOptional('src.sim.thermal_deepening')
    Optional.anomaly         = loadOptional('src.sim.anomaly')
    Optional.debugPanel      = loadOptional('src.ui.debug_panel')
    Optional.uiMenus         = loadOptional('src.ui.ui_menus')
end

-- Fixed timestep: 20 Hz simulation, uncapped render
local SIM_DT     = 1 / 20
local accumulator = 0
local simTime     = 0
local UpdateDeps = {
    GameState = GameState,
    Input = Input,
    Camera = Camera,
    Profiler = Profiler,
    Seasons = Seasons,
    Occupancy = Occupancy,
    ECS = ECS,
    Thermal = Thermal,
    Power = Power,
    Atmosphere = Atmosphere,
    Lighting = Lighting,
    Visibility = Visibility,
    Director = Director,
    Rooms = Rooms,
    Foraging = Foraging,
    Hope = Hope,
    Policies = Policies,
    Recreation = Recreation,
    Doctrines = Doctrines,
    Conveyors = Conveyors,
    Pipes = Pipes,
    Research = Research,
    Pollution = Pollution,
    Expeditions = Expeditions,
    Quest = Quest,
    Deterioration = Deterioration,
    Spoilage = Spoilage,
    Merchants = Merchants,
    Raids = Raids,
    Recruitment = Recruitment,
    StrangeMoods = StrangeMoods,
    Factions = Factions,
    Hermes = Hermes,
    EasterEggs = EasterEggs,
    Quotas = Quotas,
    Containment = Containment,
    Agriculture = Agriculture,
    Items = Items,
    ItemDecay = ItemDecay,
    Equipment = Equipment,
    Filth = Filth,
    Ordnance = Ordnance,
    Jobs = Jobs,
    Production = Production,
    Building = Building,
    Fire = Fire,
    Radiation = Radiation,
    Miners = Miners,
    Terraform = Terraform,
    TileFluids = TileFluids,
    TileGas = TileGas,
    TileSnow = TileSnow,
    Flooding = Flooding,
    Pressure = Pressure,
    Structural = Structural,
    BioCaves = BioCaves,
    Caverns = Caverns,
    Corrosion = Corrosion,
    Baldrungen = Baldrungen,
    Weather = Weather,
    Elastic = Elastic,
    Taming = Taming,
    ThermoSpawn = ThermoSpawn,
    EldritchNodes = EldritchNodes,
    Storyteller = Storyteller,
    Advisor = Advisor,
    DoctrinePanel = DoctrinePanel,
    GameOverScreen = GameOverScreen,
    Save = Save,
    UI = UI,
    Sound = Sound,
    Tutorial = Tutorial,
    Minimap = Minimap,
    Optional = Optional,
    VFX = VFX,
}

---------------------------------------------------------------------------
-- Screen fade transition overlay
---------------------------------------------------------------------------
local fadeAlpha = 0
local fadeDir = 0       -- 1 = fading in (to black), -1 = fading out (from black)
local fadeSpeed = 2.5
local lastPhase = nil

local function updateFade(dt)
    local phase = GameState.phase
    if phase ~= lastPhase and lastPhase then
        fadeAlpha = 1  -- start fully dark on phase change
        fadeDir = -1   -- fade out
    end
    lastPhase = phase

    if fadeDir ~= 0 then
        fadeAlpha = fadeAlpha + fadeDir * fadeSpeed * dt
        if fadeAlpha <= 0 then
            fadeAlpha = 0
            fadeDir = 0
        elseif fadeAlpha >= 1 then
            fadeAlpha = 1
            fadeDir = 0
        end
    end
end

local function drawFade()
    if fadeAlpha > 0.001 then
        love.graphics.setColor(0, 0, 0, fadeAlpha)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
    end
end

local function registerProfilerTargets()
    local targets = {
        ['Sim Tick'] = { category = 'sim', budgetMs = 50.0 },
        ['Clock'] = { category = 'sim', budgetMs = 0.25 },
        ['ECS'] = { category = 'sim', budgetMs = 4.0 },
        ['Thermal'] = { category = 'world', budgetMs = 3.0 },
        ['Atmosphere'] = { category = 'world', budgetMs = 3.0 },
        ['Lighting'] = { category = 'world', budgetMs = 2.0 },
        ['Raids'] = { category = 'ai', budgetMs = 2.5 },
        ['Containment'] = { category = 'world', budgetMs = 2.0 },
        ['Ordnance'] = { category = 'combat', budgetMs = 2.0 },
        ['Renderer:World'] = { category = 'render', budgetMs = 8.0 },
        ['VFX:World'] = { category = 'render', budgetMs = 2.5 },
        ['Renderer:Entities'] = { category = 'render', budgetMs = 6.0 },
        ['Weather:Particles'] = { category = 'render', budgetMs = 2.5 },
        ['UI:Draw'] = { category = 'ui', budgetMs = 8.0 },
        ['Minimap:Draw'] = { category = 'ui', budgetMs = 2.5 },
    }
    for name, opts in pairs(targets) do
        Profiler.register(name, opts)
    end
end

---------------------------------------------------------------------------
-- love.load — minimal setup, start in menu phase
---------------------------------------------------------------------------

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    love.graphics.setLineStyle('rough')
    love.graphics.setNewFont(16)
    math.randomseed(RUN_SEED or os.time())
    if RUN_SEED then print('[Frosthold] RNG seed pinned to ' .. RUN_SEED) end
    registerProfilerTargets()

    -- Load campaign persistence (MRP) before any game state init
    MRP.load()

    -- Migrate legacy single-file save to slot system
    Save.migrateOldSave()

    -- Load persisted audio/display/gameplay settings
    SettingsPanel.load()
    SettingsPanel.applyAll()

    GameState.phase = 'menu'
    MainMenu.init()
    PlanetSelect.init()
    WorldMap.init()
    StartMenu.init()

    -- Autoplay: skip menu and start colony immediately
    if AUTOPLAY then
        Autoplay.init({ days = AUTOPLAY_DAYS or 30 })
        GameState.phase = 'starting'
    end

    -- Simulation test mode: skip menu and run simulation agents
    if SIMULATION_TEST and SimRunner then
        local scenario = SIMULATION_SCENARIO or 'survival'
        SimRunner.setup(scenario)
        GameState.phase = 'starting'
    end

    -- Panel screenshot pass: boot straight into a colony, no agents driving it
    if UI_SHOTS and UIShots then
        GameState.phase = 'starting'
    end
end

---------------------------------------------------------------------------
-- Initialize the game world (called once when player clicks Start Colony)
---------------------------------------------------------------------------

local function initGameWorld()
    -- Keep startup under LuaJIT's 60-upvalue limit by resolving heavy boot
    -- dependencies locally. `require` is cached, so this is still cheap.
    local GameState = require('src.game_state')
    local Difficulty = require('src.ui.difficulty')
    local ECS = require('src.ecs.ecs')
    local World = require('src.world.tilemap')
    local Thermal = require('src.sim.thermal')
    local Atmosphere = require('src.sim.atmosphere')
    local Lighting = require('src.sim.lighting')
    local Foraging = require('src.colonist.foraging')
    local Seasons = require('src.world.seasons')
    local Weather = require('src.weather.weather')
    local Conveyors = require('src.logistics.conveyors')
    local Inserters = require('src.logistics.inserters')
    local Pipes = require('src.logistics.pipes')
    local Research = require('src.research.research')
    local Pollution = require('src.sim.pollution')
    local Expeditions = require('src.exploration.expeditions')
    local Quest = require('src.quest.quest')
    local Deterioration = require('src.sim.deterioration')
    local Save = require('src.persistence.save')
    local Sound = require('src.audio.sound')
    local Minimap = require('src.ui.minimap')
    local Tutorial = require('src.ui.tutorial')
    local Advisor = require('src.ui.advisor')
    local Generator = require('src.sim.generator')
    local Disease = require('src.sim.disease')
    local Spoilage = require('src.sim.spoilage')
    local Merchants = require('src.trade.merchants')
    local Raids = require('src.sim.raids')
    local Recruitment = require('src.colonist.recruitment')
    local StrangeMoods = require('src.colonist.strange_moods')
    local Factions = require('src.colony.factions')
    local History = require('src.world.history')
    local Hermes = require('src.sim.hermes')
    local Quotas = require('src.sim.quotas')
    local Containment = require('src.sim.containment')
    local Agriculture = require('src.building.agriculture')
    local Items = require('src.world.items')
    local Production = require('src.building.production')
    local Elastic = require('src.sim.elastic_difficulty')
    local StatusFx = require('src.sim.status_effects')
    local Surgery = require('src.medical.surgery')
    local Fire = require('src.sim.fire')
    local EndgameSys = require('src.sim.endgame')
    local Filth = require('src.sim.filth')
    local Ordnance = require('src.combat.ordnance')
    local Defenses = require('src.combat.defenses')
    local Traps = require('src.combat.traps')
    local Taming = require('src.creatures.taming')
    local EldritchNodes = require('src.creatures.eldritch_nodes')
    local Visibility = require('src.sim.visibility')
    local Director = require('src.ai.director')
    local Raiders = require('src.creatures.raiders')
    local Camera = require('src.render.camera')
    local Renderer = require('src.render.renderer')
    local VFX = require('src.render.vfx')
    local UI = require('src.ui.ui')
    local Input = require('src.ui.input')
    local GameOverScreen = require('src.ui.game_over')
    local Creatures = require('src.creatures.creatures')
    local Jobs = require('src.colonist.jobs')

    refreshOptionalModules()

    -- Load from save slot (Continue / Load from start menu)
    if GameState._pendingLoad then
        local slotId = GameState._pendingLoad
        GameState._pendingLoad = nil
        Save.loadSlot(slotId)
        -- Save.load() already initializes ECS, World, and all systems.
        -- Set phase and reset timing.
        GameState.phase = 'playing'
        GameOverScreen.reset()
        accumulator = 0
        simTime = 0
        return
    end

    GameState.init()
    Difficulty.apply()  -- must run before World.init to set map size + base temp
    Planet.init(GameState.planet)  -- apply planet config after difficulty
    Corrosion.init()               -- Morvos acid corrosion (no-op on other planets)
    Baldrungen.init()              -- Gaia A^1x escalation (no-op on other planets)

    -- Redeployment seed override: reuse the same map seed as the fallen colony
    local mrpSeedOk, MRPSeed = pcall(require, 'src.sim.mrp')
    if mrpSeedOk then
        local seedHistory = MRPSeed.getPlanetHistory(GameState.planet or 'erebus')
        if #seedHistory > 0 then
            local lastRec = seedHistory[#seedHistory]
            if lastRec.worldSeedNumeric then
                GameState.worldSeedNumeric = lastRec.worldSeedNumeric
            elseif lastRec.mapSeed then
                GameState.worldSeedNumeric = lastRec.mapSeed
            end
        end
    end

    -- Landing zone: apply threat scaling to creature aggression
    if GameState.landingZone and GameState.landingZone.threat then
        local threatMult = { low = 0.7, medium = 1.0, high = 1.3, extreme = 1.6 }
        local mult = threatMult[GameState.landingZone.threat] or 1.0
        GameState.creatureAggression = GameState.creatureAggression * mult
    end

    ECS.init()
    World.init(GameState.mapWidth, GameState.mapHeight, GameState.worldSeedNumeric)
    Thermal.init(World)
    Power.init()
    Atmosphere.init()
    Lighting.init(World)
    Foraging.init()
    Seasons.init()
    if Optional.waterFeatures and Optional.waterFeatures.init then Optional.waterFeatures.init() end
    Weather.init()
    Conveyors.init()
    Inserters.init()
    Pipes.init()
    Research.init()
    -- Apply MRP knowledge base unlocks (auto-complete research nodes from purchases)
    local rok, ResearchMRP = pcall(require, 'src.research.research')
    if rok and ResearchMRP.applyMRPUnlocks then
        ResearchMRP.applyMRPUnlocks()
    end
    Pollution.init()
    Expeditions.init()
    -- vehicles init removed (stubbed)
    Quest.init()
    Deterioration.init()
    Fire.init()
    Filth.init()
    Ordnance.init()
    require('src.sim.flooding').init()
    require('src.sim.pressure').init()
    require('src.sim.tile_fluids').init()
    require('src.sim.tile_gas').init()
    require('src.sim.tile_snow').init()
    Visibility.init(GameState.mapWidth, GameState.mapHeight)
    Director.init()
    Generator.init()
    Spoilage.init()
    Merchants.init()
    Raids.init()
    if Optional.rivals and Optional.rivals.init then Optional.rivals.init() end
    -- Build faction whitelist from player selection (nil = all factions)
    local factionWhitelist = nil
    if GameState.selectedFactions and #GameState.selectedFactions > 0 then
        factionWhitelist = GameState.selectedFactions
    end
    Factions.init(factionWhitelist)
    StrangeMoods.init()
    History.init()
    Hermes.init()
    EasterEggs.init()
    Quotas.init()
    Containment.init()
    Taming.init()
    EldritchNodes.init()
    if Optional.megabeasts and Optional.megabeasts.init then Optional.megabeasts.init() end

    -- Register humanoid raider species into Creatures.SPECIES
    Raiders.register()

    -- Apply scenario starting resources (Difficulty.apply already called above)
    Difficulty.applyScenario()

    -- Generate map secrets (after ECS + structures are ready)
    if Optional.mapSecrets and Optional.mapSecrets.generate then Optional.mapSecrets.generate() end

    -- Initialize colony legacy (load fallen colony records from disk)
    if Optional.colonyLegacy and Optional.colonyLegacy.init then Optional.colonyLegacy.init() end

    -- Spawn ruins from previous colony deployment (roguelite redeployment)
    local mrpRuinOk, MRPRuin = pcall(require, 'src.sim.mrp')
    if mrpRuinOk then
        local ruinHistory = MRPRuin.getPlanetHistory(GameState.planet or 'erebus')
        if #ruinHistory > 0 then
            local lastLegacy = ruinHistory[#ruinHistory]
            local rsok, RuinSpawner = pcall(require, 'src.sim.ruin_spawner')
            if rsok then
                RuinSpawner.spawnFromLegacy(lastLegacy)
            end
        end
    end

    Elastic.init()
    Doctrines.init()
    Sound.init()
    Minimap.init()
    Tutorial.init()
    Advisor.init()
    Camera.init()
    Renderer.init()
    VFX.init()
    UI.init()
    Input.init()

    -- Re-register ECS systems for modules loaded before ECS.init()
    -- (their auto-register fired at require time, then ECS.init() cleared systems)
    Creatures.registerSystems()
    Production.registerSystems()
    Generator.registerSystems()
    Disease.registerSystems()
    if Merchants.registerSystems then Merchants.registerSystems() end
    if Recruitment.registerSystems then Recruitment.registerSystems() end
    if Items.registerSystems then Items.registerSystems() end
    if StatusFx.registerSystems then StatusFx.registerSystems() end
    -- slavery registerSystems removed (stubbed)
    if Deterioration.registerSystems then Deterioration.registerSystems() end
    if Inserters.registerSystems then Inserters.registerSystems() end
    if Radiation.registerSystems then Radiation.registerSystems() end
    if Miners.registerSystems then Miners.registerSystems() end

    -- Self-registering ECS systems (first-time requires — auto-register on load)
    require('src.colonist.work_ai')
    require('src.world.zones')
    require('src.combat.body')
    require('src.combat.wounds')
    require('src.combat.ranged')
    require('src.combat.combat_ai')
    require('src.creatures.lairs')
    require('src.colonist.mental_breaks')
    require('src.colonist.social')
    require('src.colonist.addiction')
    require('src.colonist.scar_traits')
    require('src.logistics.circuits')
    require('src.creatures.megabeasts')
    require('src.colony.perks')
    local Laws = require('src.colony.laws')
    Laws.init()
    require('src.research.bench')
    require('src.creatures.bosses')
    require('src.building.deep_drill')
    require('src.building.miners')
    require('src.building.sos_beacon')
    require('src.building.decorations')
    local PipeProcessors = require('src.logistics.pipe_processors')

    -- Re-register modules loaded at top of main.lua that don't auto-register,
    -- or that need explicit registration because require() returns cached module
    if PipeProcessors.registerSystems then PipeProcessors.registerSystems() end
    if Agriculture.registerSystems then Agriculture.registerSystems() end
    if Defenses.registerSystems then Defenses.registerSystems() end
    if Jobs.registerSystems then Jobs.registerSystems() end
    if Surgery.registerSystems then Surgery.registerSystems() end
    if Traps.registerSystems then Traps.registerSystems() end
    if Ordnance.registerSystems then Ordnance.registerSystems() end
    if EndgameSys.registerSystems then EndgameSys.registerSystems() end
    local cok, ClothingMod = pcall(require, 'src.colonist.clothing')
    if cok and ClothingMod.registerSystems then ClothingMod.registerSystems() end
    if ShipMovement and ShipMovement.registerSystems then ShipMovement.registerSystems() end
    if NPCShips and NPCShips.registerSystems then NPCShips.registerSystems() end

    -- Colonist module: loaded here for the first time (not at top of main.lua).
    -- require() triggers auto-registration at module bottom — no explicit call needed.
    local Colonists = require('src.colonist.colonist')

    -- Spawn colonists: use drafted crew if available, otherwise random
    local scenDef = Difficulty.SCENARIOS[GameState.scenario]
        or Difficulty.SCENARIOS.crashlanded
        or Difficulty.SCENARIOS[Difficulty.SCENARIO_ORDER[1]]
        or { colonists = 3 }

    if GameState.draftedColonists and #GameState.draftedColonists > 0 then
        -- Player-selected crew from drafting screen (skills already adjusted)
        Colonists.spawnFromDraft(GameState.startX, GameState.startY, GameState.draftedColonists)
        GameState.draftedColonists = nil
    else
        -- Fallback: random generation (e.g., loaded from save or direct start)
        local count = scenDef.colonists or 3
        Colonists.spawnInitial(GameState.startX, GameState.startY, count)

        -- Apply scenario-specific modifiers to randomly spawned colonists
        if scenDef.skillBoost or scenDef.capSkills then
            for id, comps in ECS.query('colonist') do
                local col = comps.colonist
                if col.skills then
                    for skill, val in pairs(col.skills) do
                        if scenDef.skillBoost then
                            col.skills[skill] = math.min(20, val + scenDef.skillBoost)
                        end
                        if scenDef.capSkills then
                            col.skills[skill] = math.min(scenDef.capSkills, col.skills[skill])
                        end
                    end
                end
            end
        end
    end

    -- Standard drop-pod loadout: a hand weapon and cold gear per colonist.
    -- Must run after the crew exists and before scenario wounds are applied.
    Colonists.applyStartingLoadout(scenDef)

    -- Apply MRP per-run picks and permanent resource unlocks
    local mok, MRPWorld = pcall(require, 'src.sim.mrp')
    if mok then
        local picks = MRPWorld.getRunPicks()
        for _, pick in ipairs(picks) do
            if pick.id == 'supply_drop' then
                GameState.resources.metal = (GameState.resources.metal or 0) + 50
                GameState.resources.food = (GameState.resources.food or 0) + 100
                GameState.resources.components = (GameState.resources.components or 0) + 10
            elseif pick.id == 'threat_delay' then
                GameState.raidGraceDays = (GameState.raidGraceDays or 0) + 5
            elseif pick.id == 'friendly_signal' then
                GameState._friendlySignalActive = true
            end
        end

        -- Apply heavy_drop_pod permanent unlock
        if MRPWorld.hasUnlock('heavy_drop_pod') then
            GameState.resources.metal = (GameState.resources.metal or 0) + 30
            GameState.resources.food = (GameState.resources.food or 0) + 50
            GameState.resources.components = (GameState.resources.components or 0) + 5
        end
    end

    -- Apply scenario wounds/sickness
    if scenDef.wounded and scenDef.wounded > 0 then
        local woundCount = 0
        for id, comps in ECS.query('colonist') do
            if woundCount >= scenDef.wounded then break end
            local col = comps.colonist
            col.health = math.floor(col.maxHealth * 0.5)
            require('src.combat.wounds').apply(id, 'torso', 'cut', 0.5)
            woundCount = woundCount + 1
        end
    end

    -- Reveal starting area for fog of war
    Visibility.revealArea(GameState.startX, GameState.startY, 15)

    -- Frozen Siege: trigger immediate raid
    if scenDef.immediateRaid then
        Raids.startRaid('beast_assault')
    end

    -- Spawn crash shelter for crashlanded scenario
    if scenDef.crashShelter then
        local cx, cy = GameState.startX, GameState.startY
        local Tiles = require('src.world.tiles')
        local Beds  = require('src.building.beds')
        local ItemsMod = require('src.world.items')

        -- Build a cramped 4x3 metal wreckage shelter just north of spawn
        -- Layout (relative to shelter origin at cx-1, cy-4):
        --   MMMM      (row 0: metal walls across top)
        --   M..M      (row 1: metal walls left/right, metal floor interior)
        --   M..M      (row 2: metal walls left/right, metal floor interior)
        --   MDMM      (row 3: wall, door, wall, wall)
        local sx, sy = cx - 1, cy - 4  -- shelter top-left
        local layout = {
            { 'W', 'W', 'W', 'W' },  -- row 0
            { 'W', 'F', 'F', 'W' },  -- row 1
            { 'W', 'F', 'F', 'W' },  -- row 2
            { 'W', 'D', 'W', 'W' },  -- row 3
        }
        for row = 1, #layout do
            for col = 1, #layout[row] do
                local tx, ty = sx + col - 1, sy + row - 1
                if World.inBounds(tx, ty) then
                    local cell = layout[row][col]
                    if cell == 'W' then
                        World.setTile(tx, ty, Tiles.WALL_METAL)
                    elseif cell == 'F' then
                        World.setTile(tx, ty, Tiles.FLOOR_METAL)
                    elseif cell == 'D' then
                        World.setTile(tx, ty, Tiles.DOOR)
                    end
                end
            end
        end

        -- Place 2 beds inside (cramped — third colonist has no bed)
        Beds.place(sx + 1, sy + 1)
        Beds.place(sx + 2, sy + 1)

        -- A lit campfire inside the shelter keeps the landing zone livable
        -- while the first walls go up: it heats the bedroom AND casts a
        -- radius-6 warmth zone over the surrounding camp. It auto-refuels
        -- from colony wood, and the cold-emergency AI walks freezing
        -- colonists back to it. Floors are not buildable, so the target
        -- tile is converted to snow first to guarantee placement.
        local BuildingMod = require('src.building.building')
        local fireSpots = {
            { sx + 2, sy + 2 },  -- inside the shelter (preferred)
            { sx + 1, sy + 4 },  -- just outside the door
            { cx,     cy + 2 },
            { cx + 2, cy },
        }
        for _, spot in ipairs(fireSpots) do
            local fxs, fys = spot[1], spot[2]
            if World.inBounds(fxs, fys) then
                if not Tiles.isBuildable(World.getTile(fxs, fys)) then
                    World.setTile(fxs, fys, Tiles.SNOW)
                end
                if BuildingMod.tryPlace('campfire', fxs, fys, nil, true) then
                    break
                end
            end
        end

        -- Scatter salvageable debris tiles around the crash site
        local debrisOffsets = {
            {-2, -3}, {3, -2}, {-3, 0}, {4, -1}, {-2, 1},
            {3, 1}, {-1, 2}, {2, 2}, {4, 0},
        }
        for _, off in ipairs(debrisOffsets) do
            local dx, dy = cx + off[1], cy + off[2]
            if World.inBounds(dx, dy) then
                local tile = World.getTile(dx, dy)
                if Tiles.isBuildable(tile) or tile == Tiles.SNOW or tile == Tiles.PERMAFROST then
                    World.setTile(dx, dy, Tiles.DEBRIS)
                end
            end
        end

        -- Scatter lootable drop pod cargo near the shelter
        ItemsMod.spawn(sx + 1, sy + 2, 'metal',      5, 'raw')
        ItemsMod.spawn(sx + 2, sy + 2, 'components',  2, 'raw')
        ItemsMod.spawn(cx - 2, cy - 2, 'metal',       3, 'raw')
        ItemsMod.spawn(cx + 2, cy - 2, 'wood',        8, 'raw')
        ItemsMod.spawn(cx - 3, cy,     'fuel',         5, 'raw')
        ItemsMod.spawn(cx + 3, cy - 1, 'components',   1, 'raw')
        -- Starting food: packaged rations and raw meat from the drop pod.
        -- 15 rations (30 nutrition) + 20 raw meat (15) + 20 berries (10) =
        -- 950 nutrition, roughly a 7-day buffer for 3 colonists (each burns
        -- ~43 nutrition/day), so the colony has time to stand up its own
        -- food production. Amounts respect each item's max stack size.
        ItemsMod.spawn(cx,     cy + 1, 'ration',     15, 'food')
        ItemsMod.spawn(cx - 1, cy + 1, 'raw_meat',   20, 'food')
        ItemsMod.spawn(cx + 1, cy + 1, 'berries',    20, 'food')
        -- Reduce global food pool (food is now physical items; keep small seed budget)
        GameState.resources.food = 10

        -- Drinking water still comes from the shared colony pool, and the only
        -- early source is mining ice and hauling it home. Each colonist drinks
        -- roughly 1.2 water per full thirst cycle, so the default seed of 10
        -- ran three colonists dry on about day 3 and they died of dehydration
        -- with full bellies. 30 is a ~8 day buffer: enough time to get ice
        -- mining running, not enough to ignore it.
        GameState.resources.water = math.max(GameState.resources.water or 0, 30)

        -- Add a torch inside the shelter for initial light/warmth reference
        Lighting.addLight(sx + 2, sy + 2, 'torch')
    end

    -- Scatter creature lairs during worldgen
    local Lairs = require('src.creatures.lairs')
    Lairs.generateForWorld(World)

    -- Set game phase to playing
    GameState.phase = 'playing'
    GameOverScreen.reset()
    accumulator = 0
    simTime = 0
end

---------------------------------------------------------------------------
-- love.update — phase-gated
---------------------------------------------------------------------------

function love.update(dt)
    local D = UpdateDeps

    dt = math.min(dt, 0.25)
    updateFade(dt)

    -- Redeployment: defeat/victory screen set this flag via pressing R.
    -- Route back to planet select for the next run (roguelite loop).
    if D.GameState._redeployment then
        D.GameState._redeployment = nil
        local psok, PS = pcall(require, 'src.ui.planet_select')
        if psok and PS.init then PS.init() end
        D.GameState.phase = 'planet_select'
        return
    end

    -- Main menu
    if D.GameState.phase == 'menu' then return end

    -- Scenario picker
    if D.GameState.phase == 'scenario' then return end

    -- Difficulty + AI Director selection
    if D.GameState.phase == 'difficulty' then return end

    -- World generation settings (seed, map size, factions)
    if D.GameState.phase == 'worldgen' then return end

    -- Planet selection: waiting for player to pick a planet
    if D.GameState.phase == 'planet_select' then
        return
    end

    -- Requisition unlocks: permanent MRP purchases
    if D.GameState.phase == 'requisition_unlocks' then
        if RequisitionPanel.isDone() then
            -- Init colonist drafting and advance
            local csok, CS = pcall(require, 'src.ui.colonist_select')
            if csok and CS.init then CS.init() end
            D.GameState.phase = 'drafting'
        end
        return
    end

    -- Drafting phase: player is selecting crew members
    if D.GameState.phase == 'drafting' then
        return
    end

    -- Requisition picks: per-run MRP deployment bonuses
    if D.GameState.phase == 'requisition_picks' then
        if RequisitionPanel.isDone() then
            MRP.setRunPicks(RequisitionPanel.getPicksPurchased())
            -- Generate world map and advance
            local wok, WorldMap = pcall(require, 'src.ui.world_map')
            if wok and WorldMap.generateForPlanet then
                WorldMap.generateForPlanet(D.GameState.planet)
            end
            D.GameState.phase = 'world_map'
        end
        return
    end

    -- World map: waiting for player to pick a landing zone
    if D.GameState.phase == 'world_map' then
        return
    end

    -- Transition: ColonistSelect sets phase to 'starting' after crew is selected
    if D.GameState.phase == 'starting' then
        initGameWorld()
        return
    end

    -- Playing phase: full simulation
    D.GameState.colonyRealTime = (D.GameState.colonyRealTime or 0) + dt
    D.Input.update(dt)
    D.Camera.update(dt)

    if not D.GameState.paused then
        accumulator = accumulator + dt * D.GameState.speed
        -- Headless simulation tests may burst many more ticks per frame
        local maxBurst = SIMULATION_TEST and (SIM_DT * 64) or (SIM_DT * 8)
        if accumulator > maxBurst then accumulator = maxBurst end
    end

    while accumulator >= SIM_DT do
        local simToken = D.Profiler.begin('Sim Tick')
        simTime = simTime + SIM_DT
        D.GameState.simTick = D.GameState.simTick + 1

        D.Profiler.call('Clock', D.GameState.tickClock)
        D.Profiler.call('Seasons', D.Seasons.step, SIM_DT)
        D.Profiler.call('Occupancy', D.Occupancy.rebuild)
        D.Profiler.call('ECS', D.ECS.update, SIM_DT)
        D.Profiler.call('Thermal', D.Thermal.step, SIM_DT)
        D.Profiler.call('Power', D.Power.step, SIM_DT)
        D.Profiler.call('Atmosphere', D.Atmosphere.step, SIM_DT)
        D.Profiler.call('Lighting', D.Lighting.step, SIM_DT)
        D.Profiler.call('Visibility', D.Visibility.step)
        D.Profiler.call('Director', D.Director.step, SIM_DT)
        D.Profiler.call('Rooms', D.Rooms.step, SIM_DT)
        D.Profiler.call('Foraging', D.Foraging.step, SIM_DT)
        D.Profiler.call('Hope', D.Hope.step, SIM_DT)
        D.Profiler.call('Policies', D.Policies.step, SIM_DT)
        D.Profiler.call('Recreation', D.Recreation.step, SIM_DT)
        D.Profiler.call('Doctrines', D.Doctrines.step, SIM_DT)
        D.Profiler.call('Conveyors', D.Conveyors.step, SIM_DT)
        -- Inserters are ECS-driven (run in ECS.update above)
        D.Profiler.call('Pipes', D.Pipes.step, SIM_DT)
        D.Profiler.call('Research', D.Research.step, SIM_DT)
        D.Profiler.call('Pollution', D.Pollution.step, SIM_DT)
        D.Profiler.call('Expeditions', D.Expeditions.step, SIM_DT)
        D.Profiler.call('Quest', D.Quest.step, SIM_DT)
        D.Profiler.call('Deterioration', D.Deterioration.step, SIM_DT)
        D.Profiler.call('Spoilage', D.Spoilage.step, SIM_DT)
        D.Profiler.call('Merchants', D.Merchants.step, SIM_DT)
        if D.Optional.tradeRoutes and D.Optional.tradeRoutes.step then D.Profiler.call('Trade Routes', D.Optional.tradeRoutes.step, SIM_DT) end
        D.Profiler.call('Raids', D.Raids.step, SIM_DT)
        if D.Optional.rivals and D.Optional.rivals.step then D.Profiler.call('Rivals', D.Optional.rivals.step, SIM_DT) end
        D.Profiler.call('Recruitment', D.Recruitment.step, SIM_DT)
        D.Profiler.call('Strange Moods', D.StrangeMoods.step, SIM_DT)
        D.Profiler.call('Factions', D.Factions.step, SIM_DT)
        D.Profiler.call('Hermes', D.Hermes.step, SIM_DT)
        D.Profiler.call('Quotas', D.Quotas.step, SIM_DT)
        D.Profiler.call('Containment', D.Containment.step, SIM_DT)
        D.Profiler.call('Agriculture', D.Agriculture.step, SIM_DT)
        D.Profiler.call('Items', D.Items.step, SIM_DT)
        D.Profiler.call('ItemDecay', D.ItemDecay.step, SIM_DT)
        D.Profiler.call('Equipment', D.Equipment.step, SIM_DT)
        D.Profiler.call('Filth', D.Filth.step, SIM_DT)
        D.Profiler.call('Ordnance', D.Ordnance.step, SIM_DT)
        D.Profiler.call('Jobs', D.Jobs.step, SIM_DT)
        D.Profiler.call('Production AutoStock', D.Production.autoStock, SIM_DT)
        D.Profiler.call('Building', D.Building.update, SIM_DT)
        D.Profiler.call('Fire', D.Fire.step, SIM_DT)
        D.Profiler.call('Radiation', D.Radiation.step, SIM_DT)
        D.Profiler.call('Miners', D.Miners.step, SIM_DT)
        D.Profiler.call('Terraform', D.Terraform.step, SIM_DT)
        D.Profiler.call('Tile Fluids', D.TileFluids.step, SIM_DT)
        D.Profiler.call('Tile Gas', D.TileGas.step, SIM_DT)
        D.Profiler.call('Tile Snow', D.TileSnow.step, SIM_DT)
        D.Profiler.call('Flooding', D.Flooding.step, SIM_DT)
        D.Profiler.call('Pressure', D.Pressure.step, SIM_DT)
        D.Profiler.call('Structural', D.Structural.step, SIM_DT)
        D.Profiler.call('BioCaves', D.BioCaves.step, SIM_DT)
        D.Profiler.call('Caverns', D.Caverns.step, SIM_DT)
        D.Profiler.call('Corrosion', D.Corrosion.step, SIM_DT)
        D.Profiler.call('Baldrungen', D.Baldrungen.step, SIM_DT)
        if D.Optional.waterFeatures and D.Optional.waterFeatures.step then D.Profiler.call('Water Features', D.Optional.waterFeatures.step, SIM_DT) end
        D.Profiler.call('Weather', D.Weather.step, SIM_DT)
        D.Profiler.call('Elastic', D.Elastic.step, SIM_DT)
        D.Profiler.call('Taming', D.Taming.step, SIM_DT)
        D.Profiler.call('Breeding', D.Taming.checkBreeding, SIM_DT)
        D.Profiler.call('Thermovore Spawn', D.ThermoSpawn.step, SIM_DT)
        D.Profiler.call('Eldritch Nodes', D.EldritchNodes.step, SIM_DT)
        if D.Optional.skinwalker and D.Optional.skinwalker.step then D.Profiler.call('Skinwalker', D.Optional.skinwalker.step, SIM_DT) end
        if D.Optional.thermalDeepening and D.Optional.thermalDeepening.step then D.Profiler.call('Thermal Deepening', D.Optional.thermalDeepening.step, SIM_DT) end
        if D.Optional.anomaly and D.Optional.anomaly.step then D.Profiler.call('Anomaly', D.Optional.anomaly.step, SIM_DT) end

        -- Background colony tick (once per game day while in space)
        if ContextSwap and ContextSwap.isInSpace and ContextSwap.isInSpace() then
            if GameState.colonies then
                for colonyId, colony in pairs(GameState.colonies) do
                    if colony.lastTickDay and colony.lastTickDay < GameState.day then
                        if BackgroundColony and BackgroundColony.tick then
                            local daysPassed = GameState.day - colony.lastTickDay
                            BackgroundColony.tick(colony.snapshot, daysPassed, colony.automationScore)
                            colony.lastTickDay = GameState.day
                        end
                    end
                end
            end
        end

        -- Space systems (only active in space)
        if NPCShips and NPCShips.step then NPCShips.step(SIM_DT) end
        if Caravans and Caravans.step then Caravans.step(SIM_DT) end
        if StationDocking and StationDocking.checkProximityDocking then StationDocking.checkProximityDocking() end
        if SpaceEconomy and SpaceEconomy.checkExpiry then SpaceEconomy.checkExpiry() end
        if PlanetDiscovery and PlanetDiscovery.checkSensorDetection then
            for id, comps in ECS.query('ship', 'pos') do
                if not ECS.has(id, 'npc_ship') then
                    PlanetDiscovery.checkSensorDetection(comps.pos.x, comps.pos.y)
                    break
                end
            end
        end
        if ShipCombat and ShipCombat.step then ShipCombat.step(SIM_DT) end
        if Boarding and Boarding.step then Boarding.step(SIM_DT) end
        if Stealth and Stealth.step then Stealth.step(SIM_DT) end
        if SpaceHazards and SpaceHazards.step then SpaceHazards.step(SIM_DT) end
        if SpaceEvents and SpaceEvents.step then SpaceEvents.step(SIM_DT) end

        D.Profiler.call('Storyteller', D.Storyteller.step, SIM_DT)
        D.Profiler.call('Advisor', D.Advisor.step, SIM_DT)
        D.Profiler.call('Doctrine Panel', D.DoctrinePanel.update, SIM_DT)
        D.Profiler.call('Game Over', D.GameOverScreen.step, SIM_DT)
        D.Profiler.call('Easter Eggs', D.EasterEggs.step, SIM_DT)
        D.Profiler.finish(simToken)

        accumulator = accumulator - SIM_DT
    end

    D.GameState.alpha = accumulator / SIM_DT

    local sw, sh = love.graphics.getDimensions()
    D.Weather.updateParticles(dt, D.Camera.getX(), D.Camera.getY(), sw, sh, D.Camera.getZoom())

    D.Sound.update(dt)
    D.VFX.step(dt)
    D.Tutorial.update(dt)
    D.Minimap.update()
    D.Save.step(dt)
    D.UI.update(dt)
    if D.Optional.debugPanel and D.Optional.debugPanel.step then D.Optional.debugPanel.step(dt) end

    -- Autoplay bot tick
    if AUTOPLAY and Autoplay.isActive() then
        Autoplay.step(dt)
        if Autoplay.isDone() then
            love.event.quit(0)
        end
    end

    -- Panel screenshot pass
    if UI_SHOTS and UIShots and UIShots.isActive() then
        UIShots.step()
    end

    -- Simulation test tick
    if SIMULATION_TEST and SimRunner and SimRunner.isRunning then
        -- Start simulation after game is playing
        if GameState.phase == 'playing' and not SimRunner.isRunning() then
            SimRunner.start()
        end
        SimRunner.step(dt)
        if not SimRunner.isRunning() then
            SimRunner.printSummary()
            love.event.quit(0)
        end
    end
end

---------------------------------------------------------------------------
-- love.draw — phase-gated
---------------------------------------------------------------------------

function love.draw()
    SettingsPanel.beginColorblindPass()

    if GameState.phase == 'menu' then
        MainMenu.draw()
        drawFade()
        SettingsPanel.endColorblindPass()
        return
    end

    if GameState.phase == 'scenario' then
        -- StartMenu is reused for scenario picking
        StartMenu.draw()
        drawFade()
        SettingsPanel.endColorblindPass()
        return
    end

    if GameState.phase == 'difficulty' then
        DifficultySelect.draw()
        drawFade()
        SettingsPanel.endColorblindPass()
        return
    end

    if GameState.phase == 'worldgen' then
        CreateWorld.draw()
        drawFade()
        SettingsPanel.endColorblindPass()
        return
    end

    if GameState.phase == 'planet_select' then
        PlanetSelect.draw()
        drawFade()
        SettingsPanel.endColorblindPass()
        return
    end

    if GameState.phase == 'requisition_unlocks' or GameState.phase == 'requisition_picks' then
        RequisitionPanel.draw()
        drawFade()
        SettingsPanel.endColorblindPass()
        return
    end

    if GameState.phase == 'world_map' then
        WorldMap.draw()
        drawFade()
        SettingsPanel.endColorblindPass()
        return
    end

    if GameState.phase == 'drafting' then
        ColonistSelect.draw()
        drawFade()
        SettingsPanel.endColorblindPass()
        return
    end

    -- Loading screen while world generates
    if GameState.phase == 'starting' then
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0.02, 0.03, 0.05)
        love.graphics.rectangle('fill', 0, 0, sw, sh)

        -- Title
        love.graphics.setColor(0.5, 0.7, 0.9)
        local title = 'Generating World...'
        local font = love.graphics.getFont()
        local tw = font:getWidth(title)
        love.graphics.print(title, (sw - tw) / 2, sh / 2 - 30)

        -- Planet-specific loading flavor text
        local loadingTexts = {
            erebus        = 'Preparing the frozen wastes',
            rhea_2        = 'Heating the desert surface',
            morvos        = 'Corroding the atmosphere',
            nerthus_9     = 'Flooding the ocean depths',
            paxtera_prime = 'Growing the temperate fields',
            nemaea        = 'Scattering Dyson fragments',
            gaia_a1x      = 'Growing the paradise',
        }
        local loadingText = loadingTexts[GameState.planet] or 'Generating terrain'

        -- Animated dots
        local dots = string.rep('.', math.floor(love.timer.getTime() * 2) % 4)
        love.graphics.setColor(0.4, 0.5, 0.6)
        love.graphics.print(loadingText .. dots, (sw - font:getWidth(loadingText .. '...')) / 2, sh / 2)

        -- Pulsing bar
        local barW = 200
        local barH = 6
        local barX = (sw - barW) / 2
        local barY = sh / 2 + 30
        love.graphics.setColor(0.15, 0.18, 0.22)
        love.graphics.rectangle('fill', barX, barY, barW, barH, 3)
        local pulse = (math.sin(love.timer.getTime() * 3) + 1) / 2
        love.graphics.setColor(0.3, 0.5, 0.8, 0.6 + pulse * 0.4)
        love.graphics.rectangle('fill', barX, barY, barW * pulse, barH, 3)
        SettingsPanel.endColorblindPass()
        return
    end

    Camera.attach()
    Profiler.call('Renderer:World', Renderer.drawWorld, World, GameState)
    Profiler.call('VFX:World', VFX.draw, GameState.viewDepth or 0, World.tileSize())
    Profiler.call('Renderer:Entities', Renderer.drawEntities, ECS, GameState)
    Renderer.drawTerraformGhost(World)
    Profiler.call('Weather:Particles', Weather.drawParticles)
    Camera.detach()

    Renderer.drawDepthIndicator()
    Renderer.drawAmbientOverlay()
    local sw, sh = love.graphics.getDimensions()
    Weather.drawOverlay(sw, sh)
    Profiler.call('UI:Draw', UI.draw)

    -- A major panel is modal. The HUD chrome below used to keep drawing over
    -- the top of it — the minimap, the advisor popup and the event toast all
    -- landed inside the panel body, which is most of what "overlays on top of
    -- other UIs" meant.
    local panelOpen = PanelManager.anyOpen()
    if not panelOpen then
        Profiler.call('Minimap:Draw', Minimap.draw)
        Tutorial.draw()
        Advisor.draw()
        if ShipHUD and ShipHUD.draw then ShipHUD.draw() end
        if CombatHUD and CombatHUD.draw then CombatHUD.draw() end
        Renderer.drawEventToast(Storyteller)
    end

    -- Every major panel draws through the manager: one open at a time, and the
    -- focused panel draws last so z-order matches input focus.
    PanelManager.draw()

    -- The toolbar stays live so panels remain navigable; panels reserve
    -- Layout.BOTTOM_RESERVE at their bottom edge so nothing collides with it.
    BottomToolbar.draw()

    -- Toasts last, so panel feedback is visible on top of the panel that
    -- produced it.
    UI.drawToast()

    GameOverScreen.draw()
    drawFade()

    -- Debug info (F12 to toggle) — never across an open panel
    if GameState.showDebug and not panelOpen then
        local weatherName, weatherDef = Weather.getCurrent()
        love.graphics.setColor(1, 1, 1, 0.7)
        local raidStatus = Raids.isRaidActive() and 'RAID!' or ''
        love.graphics.print(string.format(
            'FPS: %d  Tick: %d  Colonists: %d  Creatures: %d  Temp: %.0f°C  Weather: %s  Power: %dW/%dW  Tasks: %d  Hope: %d  Discontent: %d  Heat: %d  Stress: %s(%.0f%%) Well: %d  %s',
            love.timer.getFPS(),
            GameState.simTick,
            ECS.countWith('colonist'),
            ECS.countWith('creature'),
            GameState.getEffectiveTemp(),
            weatherDef.name,
            Power.getTotalSupply(),
            Power.getTotalDemand(),
            Jobs.getUnclaimedCount(),
            Hope.getHope(),
            Hope.getDiscontent(),
            Raids.getHeatSignature(),
            Elastic.getBandId(),
            Elastic.getSmoothedStress() * 100,
            Elastic.getColonyWellness(),
            raidStatus
        ), 4, 4)
    end

    -- Autoplay overlay
    if AUTOPLAY and Autoplay.isActive() and not panelOpen then
        Autoplay.draw()
    end

    -- Simulation test overlay — suppressed behind a panel; it used to print
    -- straight across the roster's header and first rows.
    if SIMULATION_TEST and SimRunner and SimRunner.isRunning and SimRunner.isRunning()
       and not PanelManager.anyOpen() then
        local results = SimRunner.getResults()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 4, 20, 350, 80, 4)
        love.graphics.setColor(0.3, 0.8, 1.0)
        love.graphics.print(string.format(
            'SIMULATION TEST [%s]', results.scenario or 'unknown'
        ), 10, 26)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(string.format(
            'Day %d/%d  Ticks: %d  Time: %.1fs',
            results.daysReached or 0, results.targetDays or 0,
            results.ticksReached or 0, results.realTimeSeconds or 0
        ), 10, 46)
        local ic = results.issueCounts or {}
        love.graphics.setColor(1.0, 0.4, 0.4)
        love.graphics.print(string.format(
            'Issues: %d crit, %d high, %d med, %d low',
            ic.critical or 0, ic.high or 0, ic.medium or 0, ic.low or 0
        ), 10, 66)
    end

    SettingsPanel.endColorblindPass()
end

---------------------------------------------------------------------------
-- Input routing — phase-gated
---------------------------------------------------------------------------

function love.keypressed(key)
    if GameState.phase == 'menu' then
        MainMenu.keypressed(key)
        return
    end

    if GameState.phase == 'scenario' then
        StartMenu.keypressed(key)
        return
    end

    if GameState.phase == 'difficulty' then
        DifficultySelect.keypressed(key)
        return
    end

    if GameState.phase == 'worldgen' then
        CreateWorld.keypressed(key)
        return
    end

    if GameState.phase == 'planet_select' then
        PlanetSelect.keypressed(key)
        return
    end

    if GameState.phase == 'requisition_unlocks' or GameState.phase == 'requisition_picks' then
        RequisitionPanel.keypressed(key)
        return
    end

    if GameState.phase == 'world_map' then
        WorldMap.keypressed(key)
        return
    end

    if GameState.phase == 'drafting' then
        ColonistSelect.keypressed(key)
        return
    end

    if GameState.phase == 'starting' then return end

    if key == 'escape' then
        if Tutorial.isActive() then
            Tutorial.toggle()
            return
        end
        -- Build mode: ESC cancels ghost first, then exits build mode
        if GameState.buildGhost then
            GameState.buildGhost = nil
            return
        end
        if GameState.buildMode then
            GameState.buildMode = false
            GameState.selectedTool = nil
            return
        end
        -- ESC closes the focused panel before it reaches for the pause menu.
        -- It used to skip straight past every open panel and open the pause
        -- menu on top of one, which is how three layers ended up on screen.
        if PanelManager.closeTop() then return end
        if UI.isMenuOpen() then
            UI.closeMenu()
            GameState.paused = false
        else
            UI.openMenu('pause')
            GameState.paused = true
        end
        return
    end
    -- Route to menu system (save slot naming, etc.)
    if Optional.uiMenus and Optional.uiMenus.keypressed and Optional.uiMenus.keypressed(key) then return end

    if GameOverScreen.keypressed(key) then return end

    -- F11 opens the dev panel. It is registered with the panel manager, so it
    -- closes whatever else is open rather than drawing across it.
    if key == 'f11' then PanelManager.toggle('debug') return end

    -- The focused panel gets the key, and nothing behind it does. Asking every
    -- panel in turn meant whichever sat first in this list ate the keys meant
    -- for the panel actually drawn on top.
    if PanelManager.keypressed(key) then return end

    if key == 'r' and not GameState.buildMode and not love.keyboard.isDown('lshift', 'rshift') then
        -- Draft toggle takes priority when a single colonist is selected
        local selCount, selId = 0, nil
        for id in pairs(GameState.selectedEntities) do selCount = selCount + 1; selId = id end
        if selCount == 1 and selId then
            local col = ECS.get(selId, 'colonist')
            if col and col.state ~= 'dead' then
                col.drafted = not col.drafted
                if not col.drafted then col.state = 'idle'; col.task = nil end
                return
            end
        end
        PanelManager.toggle('research') return
    end
    -- Panel hotkeys. The guards stay here because they depend on game state
    -- (build mode, modifier keys, being in space); the manager owns which panel
    -- ends up visible.
    if key == 'p' and not GameState.buildMode then PanelManager.toggle('policy') return end
    if key == 'o' and not GameState.buildMode then PanelManager.toggle('doctrine') return end
    if key == 't' and not GameState.buildMode then PanelManager.toggle('trade') return end
    if key == 'e' and not GameState.buildMode then PanelManager.toggle('expedition') return end
    if key == 'g' and not GameState.buildMode then PanelManager.toggle('farm') return end
    if key == 'v' and not GameState.buildMode then PanelManager.toggle('equip') return end
    if key == 'q' and not GameState.buildMode then PanelManager.toggle('quests') return end
    if key == 'h' and not GameState.buildMode and not love.keyboard.isDown('lshift', 'rshift') then PanelManager.toggle('medical') return end
    if key == 'c' and not GameState.buildMode and not love.keyboard.isDown('lshift', 'rshift') then PanelManager.toggle('colony') return end
    if key == 'l' and not GameState.buildMode then PanelManager.toggle('laws') return end
    if key == 'i' and not GameState.buildMode then PanelManager.toggle('goals') return end
    if key == 'f' and not GameState.buildMode and love.keyboard.isDown('lshift', 'rshift') then PanelManager.toggle('factions') return end
    if key == 'y' and not GameState.buildMode then PanelManager.toggle('taming') return end
    if key == 'm' and not GameState.buildMode and GameState.activeMap == 'space' then PanelManager.toggle('starmap') return end
    if key == 'k' and not GameState.buildMode and GameState.activeMap == 'space' then
        PanelManager.toggle('contracts')
        return
    end
    if key == 'f3' then Renderer.togglePollutionOverlay() return end
    if key == 'f12' then GameState.showDebug = not GameState.showDebug return end
    if key == 'f5' then Save.quickSave(); UI.showSaveToast('Quick Saved') return end
    if key == 'f9' then Save.quickLoad(); UI.showSaveToast('Quick Loaded') return end
    if key == 'tab' then Minimap.toggle() return end
    if key == 'f1' then Tutorial.toggle() return end

    Input.keypressed(key)
    UI.keypressed(key)
end

function love.textinput(text)
    if GameState.phase == 'worldgen' then
        CreateWorld.textinput(text)
        return
    end
    if GameState.phase ~= 'playing' then return end
    if Optional.uiMenus and Optional.uiMenus.textinput and Optional.uiMenus.textinput(text) then return end
    if ResearchPanel.textinput and ResearchPanel.textinput(text) then return end
    if UI.textinput and UI.textinput(text) then return end
end

function love.keyreleased(key)
    if GameState.phase ~= 'playing' then return end
    Input.keyreleased(key)
end

function love.mousepressed(x, y, button)
    if GameState.phase == 'menu' then
        MainMenu.mousepressed(x, y, button)
        return
    end

    if GameState.phase == 'scenario' then
        StartMenu.mousepressed(x, y, button)
        return
    end

    if GameState.phase == 'difficulty' then
        DifficultySelect.mousepressed(x, y, button)
        return
    end

    if GameState.phase == 'worldgen' then
        CreateWorld.mousepressed(x, y, button)
        return
    end

    if GameState.phase == 'planet_select' then
        PlanetSelect.mousepressed(x, y, button)
        return
    end

    if GameState.phase == 'requisition_unlocks' or GameState.phase == 'requisition_picks' then
        RequisitionPanel.mousepressed(x, y, button)
        return
    end

    if GameState.phase == 'world_map' then
        WorldMap.mousepressed(x, y, button)
        return
    end

    if GameState.phase == 'drafting' then
        ColonistSelect.mousepressed(x, y, button)
        return
    end
    -- The toolbar is drawn above the panels and stays clickable, so it is asked
    -- first. Selecting an entry from it routes through the panel manager, which
    -- swaps the open panel instead of stacking a second one on top.
    if BottomToolbar.mousepressed(x, y, button) then return end

    -- Only the focused panel sees the click. Every panel used to be asked in
    -- this fixed order and each one consumed anything while visible, so a panel
    -- earlier in the list swallowed clicks aimed at the panel on top — that is
    -- why the gift and trade-route buttons did nothing.
    if PanelManager.mousepressed(x, y, button) then return end

    if CombatHUD and CombatHUD.mousepressed and CombatHUD.mousepressed(x, y, button) then return end
    if Minimap.mousepressed(x, y, button) then return end
    if Advisor.mousepressed(x, y, button) then return end
    if UI.mousepressed(x, y, button) then return end
    Input.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    if GameState.phase == 'menu' then
        MainMenu.mousereleased(x, y, button)
        return
    end
    if GameState.phase == 'difficulty' then
        DifficultySelect.mousereleased(x, y, button)
        return
    end
    if GameState.phase ~= 'playing' then return end
    UI.mousereleased(x, y, button)
    Input.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    if GameState.phase == 'menu' then
        MainMenu.mousemoved(x, y, dx, dy)
        return
    end
    if GameState.phase == 'difficulty' then
        DifficultySelect.mousemoved(x, y, dx, dy)
        return
    end
    if GameState.phase ~= 'playing' then return end
    UI.mousemoved(x, y)
end

function love.wheelmoved(dx, dy)
    if GameState.phase == 'scenario' then
        -- StartMenu reused for scenario; forward wheel if it exposes wheelmoved
        if StartMenu.wheelmoved then StartMenu.wheelmoved(dx, dy) end
        return
    end
    if GameState.phase == 'worldgen' then
        CreateWorld.wheelmoved(dx, dy)
        return
    end
    if GameState.phase == 'requisition_unlocks' or GameState.phase == 'requisition_picks' then
        RequisitionPanel.wheelmoved(dx, dy)
        return
    end
    if GameState.phase ~= 'playing' then return end
    if Optional.uiMenus and Optional.uiMenus.wheelmoved and Optional.uiMenus.wheelmoved(dx, dy) then return end
    -- Scroll goes to the focused panel, never to the camera behind it.
    if PanelManager.wheelmoved(dx, dy) then return end
    if UI.wheelmoved(dx, dy) then return end
    Camera.zoom(dy)
end

function love.resize(w, h)
    Camera.resize(w, h)
    UI.resize(w, h)
end

---------------------------------------------------------------------------
-- Error handler — capture screenshot + email crash report
---------------------------------------------------------------------------

local _origErrorHandler = love.errorhandler or love.errhand

function love.errorhandler(msg)
    -- Build traceback
    local trace = debug.traceback(tostring(msg), 2)
    local report = string.format(
        'FROSTHOLD CRASH\nDay %d  Hour %.1f  Tick %d\n\n%s',
        (GameState and GameState.day) or 0,
        (GameState and GameState.hour) or 0,
        (GameState and GameState.simTick) or 0,
        trace
    )

    -- Append autoplay log if running
    if AUTOPLAY and Autoplay and Autoplay.getLog then
        report = report .. '\n\n--- AUTOPLAY LOG ---\n' .. Autoplay.getLog()
    end

    -- Try to capture screenshot
    local screenshotSaved = false
    pcall(function()
        local timestamp = os.date('%Y%m%d_%H%M%S')
        local filename = 'crash_' .. timestamp .. '.png'
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode('png', filename)
            screenshotSaved = filename
        end)
        -- Need a present() to flush the capture
        love.graphics.present()
    end)

    -- Write error text to save dir
    pcall(function()
        local saveDir = love.filesystem.getSaveDirectory()
        local errFile = saveDir .. '/crash_error.txt'
        local f = io.open(errFile, 'w')
        if f then
            f:write(report)
            f:close()
        end
    end)

    -- Fall through to default Love2D error screen
    if _origErrorHandler then
        return _origErrorHandler(msg)
    end
end
