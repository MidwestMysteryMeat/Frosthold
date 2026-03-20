local ECS = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Weather = require('src.weather.weather')

local Context = require('src.persistence.save_context')

local Helpers = {}

function Helpers.ensureSavesDir()
    love.filesystem.createDirectory(Context.SAVES_DIR)
end

function Helpers.slotFilename(slotId)
    return Context.SAVES_DIR .. '/' .. slotId .. '.dat'
end

local function serializeValue(v, indent, visited)
    local t = type(v)
    if t == 'number' then
        if v ~= v then
            return '0/0'
        end
        if v == math.huge then
            return '1/0'
        end
        if v == -math.huge then
            return '-1/0'
        end
        return tostring(v)
    elseif t == 'string' then
        return string.format('%q', v)
    elseif t == 'boolean' then
        return v and 'true' or 'false'
    elseif t == 'table' then
        if visited[v] then
            return 'nil'
        end
        visited[v] = true
        local parts = {}
        local indent2 = indent .. '  '
        local n = #v
        for i = 1, n do
            parts[#parts + 1] = indent2 .. serializeValue(v[i], indent2, visited)
        end
        for k, val in pairs(v) do
            local skip = false
            if type(k) == 'number' and k >= 1 and k <= n and math.floor(k) == k then
                skip = true
            end
            if not skip then
                local kStr
                if type(k) == 'string' and k:match('^[%a_][%w_]*$') then
                    kStr = k
                else
                    kStr = '[' .. serializeValue(k, indent2, visited) .. ']'
                end
                parts[#parts + 1] = indent2 .. kStr .. ' = ' .. serializeValue(val, indent2, visited)
            end
        end
        visited[v] = nil
        if #parts == 0 then
            return '{}'
        end
        return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}'
    end
    return 'nil'
end

function Helpers.serialize(tbl)
    return 'return ' .. serializeValue(tbl, '', {})
end

function Helpers.deserialize(str)
    local fn, err = load(str)
    if not fn then
        return nil, err
    end
    local ok, result = pcall(fn)
    if not ok then
        return nil, result
    end
    return result
end

local KNOWN_COMPONENTS = {
    'pos', 'colonist', 'needs', 'inventory', 'path',
    'schedule', 'workPriority', 'creature', 'machine',
    'bed', 'decoration', 'durability', 'building_ref',
    'merchant', 'disease', 'steam_hub', 'body', 'equipment',
    'prisoner', 'cloning_vat', 'radio_beacon', 'raid_tag', 'boss',
    'crop', 'artifact', 'sensor',
    'item', 'away', 'projectile', 'status_effects',
    'wounds', 'diseaseImmunity', 'tamed', 'suit',
    'lair', 'eldritch_growth', 'deep_drill', 'inserter', 'research_bench',
    'turret', 'trap', 'shield', 'watchtower', 'quest_board',
    'addictions', 'cover',
    'pipe_node', 'tank', 'processor',
    'battery', 'power_switch',
    'ordnance', 'stockpile', 'rival',
    'laser_fence',
    'endgame_building',
    'visitor',
    'recreation',
    'containment_cell',
    'radiation',
    'miner',
    'storage',
    'clothing',
    'ship',
    'ship_module',
    'ship_crew',
    'weapon_mount',
    'stealth',
    'space_suit',
    'npc_ship',
}

local function gatherEntities()
    local entities = {}
    local seen = {}
    for _, comp in ipairs(KNOWN_COMPONENTS) do
        for _, id in ipairs(ECS.allWith(comp)) do
            if not seen[id] then
                seen[id] = true
                local ent = { _savedId = id }
                for _, c in ipairs(KNOWN_COMPONENTS) do
                    local data = ECS.get(id, c)
                    if data and data ~= true then
                        ent[c] = data
                    elseif data == true then
                        ent[c] = true
                    end
                end
                entities[#entities + 1] = ent
            end
        end
    end
    return entities
end

local function gatherTilemap()
    local World = require('src.world.tilemap')
    local layerData = World.getLayerData()
    for _, layer in pairs(layerData.layers) do
        if layer.temps then
            local rounded = {}
            for i = 1, #layer.temps do
                rounded[i] = math.floor(layer.temps[i] * 10 + 0.5) / 10
            end
            layer.temps = rounded
        end
        layer.rooms = nil
    end
    layerData.lockedDoors = World.getLockedDoors()
    return layerData
end

local function gatherWeather()
    local name = Weather.getCurrent()
    return {
        current = name,
        timeRemaining = Weather.getTimeRemaining(),
        windAngle = Weather.getWindAngle(),
        windSpeed = Weather.getWindSpeed(),
        bloodRainFired = Weather.getBloodRainFired() or false,
    }
end

local function gatherStoryteller()
    local Storyteller = require('src.storyteller.storyteller')
    local personality = Storyteller.getPersonality()
    local state = Storyteller.getTimerState and Storyteller.getTimerState() or {}
    return {
        personality = personality,
        log = Storyteller.getLog(),
        eventTimer = state.eventTimer,
        threatSpent = state.threatSpent,
        quietBuildup = state.quietBuildup,
        lastRaidDay = state.lastRaidDay,
        cyclePhase = state.cyclePhase,
        cycleTimer = state.cycleTimer,
    }
end

local function gatherHope()
    local Hope = require('src.colony.hope')
    return Hope.getState()
end

local function gatherZones()
    local Zones = require('src.world.zones')
    return Zones.getState()
end

function Helpers.buildSaveData()
    return {
        version = 3,
        timestamp = os.time(),
        gameState = {
            day = GameState.day,
            hour = GameState.hour,
            season = GameState.season,
            speed = GameState.speed,
            paused = GameState.paused,
            simTick = GameState.simTick,
            colonyRealTime = GameState.colonyRealTime or 0,
            globalTemp = GameState.globalTemp,
            windChill = GameState.windChill,
            baseTemp = GameState.baseTemp,
            tempBias = GameState.tempBias or 0,
            resources = GameState.resources,
            camX = GameState.camX,
            camY = GameState.camY,
            camZoom = GameState.camZoom,
            mapWidth = GameState.mapWidth,
            mapHeight = GameState.mapHeight,
            startX = GameState.startX,
            startY = GameState.startY,
            creatureAggression = GameState.creatureAggression,
            weatherHarshness = GameState.weatherHarshness,
            diseasePressure = GameState.diseasePressure,
            resourceScarcity = GameState.resourceScarcity,
            fogOfWar = GameState.fogOfWar,
            autoPause = GameState.autoPause,
            exclusiveBuffs = GameState.exclusiveBuffs,
            toxicFallout = GameState.toxicFallout,
            volcanicAsh = GameState.volcanicAsh,
            endlessMode = GameState.endlessMode,
            mammonaSafetyNet = GameState.mammonaSafetyNet,
            _safetyNetUsed = GameState._safetyNetUsed,
            buildingsConstructed = GameState.buildingsConstructed or 0,
            hermesPhase = GameState.hermesPhase,
            hermesDirective = GameState.hermesDirective,
            gameMode = GameState.gameMode,
            colonyName = GameState.colonyName,
            viewDepth = GameState.viewDepth or 0,
            planet = GameState.planet or 'erebus',
            landingZone = GameState.landingZone,
            activeMap = GameState.activeMap,
            colonies = GameState.colonies,
            shipState = GameState.shipState,
            discoveredPOIs = GameState.discoveredPOIs,
            discoveredPlanets = GameState.discoveredPlanets,
            spaceChunkDiffs = GameState.spaceChunkDiffs,
            mammonaClaimed = GameState.mammonaClaimed,
            sealedDeep = GameState.sealedDeep,
            extractionComplete = GameState.extractionComplete,
            credits = GameState.credits,
        },
        tilemap = gatherTilemap(),
        entities = gatherEntities(),
        weather = gatherWeather(),
        storyteller = gatherStoryteller(),
        hope = gatherHope(),
        zones = gatherZones(),
        jobs = (function()
            local ok, Jobs = pcall(require, 'src.colonist.jobs')
            return ok and Jobs.getState() or nil
        end)(),
        tutorialDone = GameState.tutorialDone or false,
        laws = (function()
            local ok, Laws = pcall(require, 'src.colony.laws')
            return ok and Laws.getState() or nil
        end)(),
        factions = (function()
            local ok, Factions = pcall(require, 'src.colony.factions')
            return ok and Factions.getState() or nil
        end)(),
        perks = (function()
            local ok, Perks = pcall(require, 'src.colony.perks')
            return ok and Perks.getState() or nil
        end)(),
        megabeasts = (function()
            local ok, Mega = pcall(require, 'src.creatures.megabeasts')
            return ok and { totalMined = Mega.getTotalMined() } or nil
        end)(),
        history = (function()
            local ok, History = pcall(require, 'src.world.history')
            return ok and History.getState() or nil
        end)(),
        hermes = (function()
            local ok, H = pcall(require, 'src.sim.hermes')
            return ok and H.getState and H.getState() or nil
        end)(),
        quotas = (function()
            local ok, Q = pcall(require, 'src.sim.quotas')
            return ok and Q.getState and Q.getState() or nil
        end)(),
        strangeMoods = (function()
            local ok, SM = pcall(require, 'src.colonist.strange_moods')
            return ok and { activeMood = SM.getActiveMood() } or nil
        end)(),
        raids = (function()
            local ok, Raids = pcall(require, 'src.sim.raids')
            return ok and Raids.getState and Raids.getState() or nil
        end)(),
        spoilage = (function()
            local ok, Spoilage = pcall(require, 'src.sim.spoilage')
            return ok and Spoilage.getState and Spoilage.getState() or nil
        end)(),
        elasticDifficulty = (function()
            local ok, Elastic = pcall(require, 'src.sim.elastic_difficulty')
            return ok and Elastic.getState() or nil
        end)(),
        merchants = (function()
            local ok, M = pcall(require, 'src.trade.merchants')
            return ok and M.getState() or nil
        end)(),
        tradeRoutes = (function()
            local ok, TR = pcall(require, 'src.trade.trade_routes')
            return ok and TR.getState() or nil
        end)(),
        visitors = (function()
            local ok, V = pcall(require, 'src.trade.visitors')
            return ok and V.getState() or nil
        end)(),
        alerts = (function()
            local ok, A = pcall(require, 'src.ui.alerts')
            return ok and A.getState() or nil
        end)(),
        policies = (function()
            local ok, P = pcall(require, 'src.colony.policies')
            return ok and P.getState() or nil
        end)(),
        pipes = (function()
            local ok, PipesMod = pcall(require, 'src.logistics.pipes')
            return ok and PipesMod.getState and PipesMod.getState() or nil
        end)(),
        eldritchNodes = (function()
            local ok, EN = pcall(require, 'src.creatures.eldritch_nodes')
            return ok and EN.getState and EN.getState() or nil
        end)(),
        taming = (function()
            local ok, Taming = pcall(require, 'src.creatures.taming')
            return ok and Taming.getState and Taming.getState() or nil
        end)(),
        thermovoreSpawner = (function()
            local ok, TS = pcall(require, 'src.creatures.thermovore_spawner')
            return ok and TS.getState and TS.getState() or nil
        end)(),
        atmosphere = (function()
            local ok, Atmo = pcall(require, 'src.sim.atmosphere')
            return ok and Atmo.getState and Atmo.getState() or nil
        end)(),
        pollution = (function()
            local ok, Poll = pcall(require, 'src.sim.pollution')
            return ok and Poll.getState and Poll.getState() or nil
        end)(),
        lighting = (function()
            local ok, Light = pcall(require, 'src.sim.lighting')
            return ok and Light.getState and Light.getState() or nil
        end)(),
        social = (function()
            local ok, Soc = pcall(require, 'src.colonist.social')
            return ok and Soc.getState and Soc.getState() or nil
        end)(),
        conveyors = (function()
            local ok, Conv = pcall(require, 'src.logistics.conveyors')
            return ok and Conv.getState and Conv.getState() or nil
        end)(),
        foraging = (function()
            local ok, Forage = pcall(require, 'src.colonist.foraging')
            return ok and Forage.getState and Forage.getState() or nil
        end)(),
        expeditions = (function()
            local ok, Exp = pcall(require, 'src.exploration.expeditions')
            return ok and Exp.getState and Exp.getState() or nil
        end)(),
        quests = (function()
            local ok, Q = pcall(require, 'src.quest.quest')
            return ok and Q.getState and Q.getState() or nil
        end)(),
        buildingPlaced = (function()
            local ok, Bld = pcall(require, 'src.building.building')
            return ok and Bld.getState and Bld.getState() or nil
        end)(),
        visibility = (function()
            local ok, Vis = pcall(require, 'src.sim.visibility')
            return ok and Vis.getState and Vis.getState() or nil
        end)(),
        director = (function()
            local ok, Dir = pcall(require, 'src.ai.director')
            return ok and Dir.getState and Dir.getState() or nil
        end)(),
        power = (function()
            local ok, Pwr = pcall(require, 'src.sim.power')
            return ok and Pwr.getState and Pwr.getState() or nil
        end)(),
        terraform = (function()
            local ok, Tf = pcall(require, 'src.world.terraform')
            return ok and Tf.getState and Tf.getState() or nil
        end)(),
        flooding = (function()
            local ok, Fl = pcall(require, 'src.sim.flooding')
            return ok and Fl.getState and Fl.getState() or nil
        end)(),
        pressure = (function()
            local ok, Pr = pcall(require, 'src.sim.pressure')
            return ok and Pr.getState and Pr.getState() or nil
        end)(),
        fire = (function()
            local ok, Fi = pcall(require, 'src.sim.fire')
            return ok and Fi.getState and Fi.getState() or nil
        end)(),
        structural = (function()
            local ok, St = pcall(require, 'src.world.structural')
            return ok and St.getState and St.getState() or nil
        end)(),
        biocaves = (function()
            local ok, Bc = pcall(require, 'src.world.biocaves')
            return ok and Bc.getState and Bc.getState() or nil
        end)(),
        caverns = (function()
            local ok, Cv = pcall(require, 'src.world.caverns')
            return ok and Cv.getState and Cv.getState() or nil
        end)(),
        tileFluids = (function()
            local ok, Tf = pcall(require, 'src.sim.tile_fluids')
            return ok and Tf.getState and Tf.getState() or nil
        end)(),
        tileGas = (function()
            local ok, Tg = pcall(require, 'src.sim.tile_gas')
            return ok and Tg.getState and Tg.getState() or nil
        end)(),
        tileSnow = (function()
            local ok, Ts = pcall(require, 'src.sim.tile_snow')
            return ok and Ts.getState and Ts.getState() or nil
        end)(),
        research = (function()
            local ok, Res = pcall(require, 'src.research.research')
            return ok and Res.getState and Res.getState() or nil
        end)(),
        filth = (function()
            local ok, Fl = pcall(require, 'src.sim.filth')
            return ok and Fl.getState and Fl.getState() or nil
        end)(),
        ordnance = (function()
            local ok, Ord = pcall(require, 'src.combat.ordnance')
            return ok and Ord.getState and Ord.getState() or nil
        end)(),
        seasons = (function()
            local ok, Seasons = pcall(require, 'src.world.seasons')
            return ok and Seasons.getState and Seasons.getState() or nil
        end)(),
        waterFeatures = (function()
            local ok, WF = pcall(require, 'src.world.water_features')
            return ok and WF.getState and WF.getState() or nil
        end)(),
        mapSecrets = (function()
            local ok, MS = pcall(require, 'src.world.map_secrets')
            return ok and MS.getState and MS.getState() or nil
        end)(),
        skinwalker = (function()
            local ok, SW = pcall(require, 'src.creatures.skinwalker')
            return ok and SW.getState and SW.getState() or nil
        end)(),
        thermalDeepening = (function()
            local ok, TD = pcall(require, 'src.sim.thermal_deepening')
            return ok and TD.getState and TD.getState() or nil
        end)(),
        anomaly = (function()
            local ok, AN = pcall(require, 'src.sim.anomaly')
            return ok and AN.getState and AN.getState() or nil
        end)(),
        easterEggs = (function()
            local ok, EE = pcall(require, 'src.sim.easter_eggs')
            return ok and EE.getState and EE.getState() or nil
        end)(),
        workOrders = (function()
            local ok, WO = pcall(require, 'src.building.work_orders')
            return ok and WO.getState and WO.getState() or nil
        end)(),
        rivals = (function()
            local ok, R = pcall(require, 'src.sim.rivals')
            return ok and R.getState and R.getState() or nil
        end)(),
        advisor = (function()
            local ok, Adv = pcall(require, 'src.ui.advisor')
            return ok and Adv.getState and Adv.getState() or nil
        end)(),
        doctrines = (function()
            local ok, Doc = pcall(require, 'src.colony.doctrines')
            return ok and Doc.getState and Doc.getState() or nil
        end)(),
        containment = (function()
            local ok, Containment = pcall(require, 'src.sim.containment')
            return ok and Containment.getState and Containment.getState() or nil
        end)(),
        corrosion = (function()
            local ok, Corrosion = pcall(require, 'src.sim.corrosion')
            return ok and Corrosion.getState and Corrosion.getState() or nil
        end)(),
        baldrungen = (function()
            local ok, Baldrungen = pcall(require, 'src.sim.baldrungen')
            return ok and Baldrungen.getState and Baldrungen.getState() or nil
        end)(),
        shipMovement = (function()
            local ok, SM = pcall(require, 'src.space.ship_movement')
            if ok and SM.getState then return SM.getState() end
        end)(),
        spaceTilemap = (function()
            local ok, ST = pcall(require, 'src.space.space_tilemap')
            if ok and ST.getState then return ST.getState() end
        end)(),
        shipConstruction = (function()
            local ok, SC = pcall(require, 'src.space.ship_construction')
            if ok and SC.getState then return SC.getState() end
        end)(),
        npcShips = (function()
            local ok, NS = pcall(require, 'src.space.npc_ships')
            if ok and NS.getState then return NS.getState() end
        end)(),
        caravans = (function()
            local ok, C = pcall(require, 'src.space.caravans')
            if ok and C.getState then return C.getState() end
        end)(),
        spaceEconomy = (function()
            local ok, SE = pcall(require, 'src.space.space_economy')
            if ok and SE.getState then return SE.getState() end
        end)(),
        stationDocking = (function()
            local ok, SD = pcall(require, 'src.space.station_docking')
            if ok and SD.getState then return SD.getState() end
        end)(),
        planetDiscovery = (function()
            local ok, PD = pcall(require, 'src.space.planet_discovery')
            if ok and PD.getState then return PD.getState() end
        end)(),
        shipCombat = (function()
            local ok, SC = pcall(require, 'src.space.ship_combat')
            if ok and SC.getState then return SC.getState() end
        end)(),
        boarding = (function()
            local ok, B = pcall(require, 'src.space.boarding')
            if ok and B.getState then return B.getState() end
        end)(),
        stealth = (function()
            local ok, S = pcall(require, 'src.space.stealth')
            if ok and S.getState then return S.getState() end
        end)(),
        spaceHazards = (function()
            local ok, H = pcall(require, 'src.space.hazards')
            if ok and H.getState then return H.getState() end
        end)(),
        spaceEvents = (function()
            local ok, SE = pcall(require, 'src.space.space_events')
            if ok and SE.getState then return SE.getState() end
        end)(),
        easterEggsSpace = (function()
            local ok, EE = pcall(require, 'src.space.easter_eggs_space')
            if ok and EE.getState then return EE.getState() end
        end)(),
        celestialBodies = (function()
            local ok, CB = pcall(require, 'src.space.celestial_bodies')
            if ok and CB.getState then return CB.getState() end
        end)(),
    }
end

return Helpers
