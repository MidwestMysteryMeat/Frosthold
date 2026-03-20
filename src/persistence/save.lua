-- save.lua -- Save/Load system

local ECS = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Weather = require('src.weather.weather')

local Context = require('src.persistence.save_context')
local Helpers = require('src.persistence.save_helpers')

local Save = {}

require('src.persistence.save_writer')(Save)
require('src.persistence.save_slots')(Save)

---------------------------------------------------------------------------
-- Internal: restore game from a parsed data table
-- skipTilemap: if true, skip tilemap restore (for space context-swap)
---------------------------------------------------------------------------
local function restoreFromData(data, skipTilemap)
    local gs = data.gameState
    if gs then
        GameState.day = gs.day or 1
        GameState.hour = gs.hour or 6.0
        GameState.season = gs.season or 'winter'
        GameState.speed = gs.speed or 1
        GameState.paused = gs.paused or false
        GameState.simTick = gs.simTick or 0
        GameState.colonyRealTime = gs.colonyRealTime or 0
        GameState.globalTemp = gs.globalTemp or -40
        GameState.windChill = gs.windChill or 0
        GameState.baseTemp = gs.baseTemp or -40
        GameState.tempBias = gs.tempBias or 0
        GameState.camX = gs.camX or 0
        GameState.camY = gs.camY or 0
        GameState.camZoom = gs.camZoom or 1
        GameState.mapWidth = gs.mapWidth or 128
        GameState.mapHeight = gs.mapHeight or 128
        GameState.startX = gs.startX or 64
        GameState.startY = gs.startY or 64
        GameState.creatureAggression = gs.creatureAggression or 1
        GameState.weatherHarshness = gs.weatherHarshness or 1
        GameState.diseasePressure = gs.diseasePressure or 1
        GameState.resourceScarcity = gs.resourceScarcity or 1
        GameState.fogOfWar = gs.fogOfWar ~= false
        if gs.autoPause then
            for k, v in pairs(gs.autoPause) do
                GameState.autoPause[k] = v
            end
        end
        if gs.resources then
            for k, v in pairs(gs.resources) do
                GameState.resources[k] = v
            end
        end
        GameState.exclusiveBuffs = gs.exclusiveBuffs or {}
        GameState.toxicFallout = gs.toxicFallout
        GameState.volcanicAsh = gs.volcanicAsh
        GameState.endlessMode = gs.endlessMode or false
        GameState.mammonaSafetyNet = gs.mammonaSafetyNet ~= false
        GameState._safetyNetUsed = gs._safetyNetUsed or false
        GameState.buildingsConstructed = gs.buildingsConstructed or 0
        GameState.hermesPhase = gs.hermesPhase or 'functional'
        GameState.hermesDirective = gs.hermesDirective
        GameState.gameMode = gs.gameMode
        GameState.colonyName = gs.colonyName
        GameState.viewDepth = gs.viewDepth or 0
        GameState.planet = gs.planet or 'erebus'
        GameState.landingZone = gs.landingZone
        GameState.activeMap = gs.activeMap or gs.planet or 'erebus'
        GameState.colonies = gs.colonies or {}
        GameState.shipState = gs.shipState or nil
        GameState.discoveredPOIs = gs.discoveredPOIs or {}
        GameState.discoveredPlanets = gs.discoveredPlanets or {}
        GameState.spaceChunkDiffs = gs.spaceChunkDiffs or {}
        GameState.mammonaClaimed = gs.mammonaClaimed or false
        GameState.sealedDeep = gs.sealedDeep or false
        GameState.extractionComplete = gs.extractionComplete or false
        GameState.credits = gs.credits or 0
    end

    -- Migrate version 1 saves: spawn physical items for old resource counters
    if (data.version or 1) == 1 then
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn and GameState.resources then
            local ItemDefs = require('src.world.item_defs')
            local sx = GameState.startX or 64
            local sy = GameState.startY or 64
            for name, count in pairs(GameState.resources) do
                if type(count) == 'number' and count > 0 then
                    local def = ItemDefs.ITEMS[name]
                    if def then
                        Items.spawn(sx, sy, name, count, nil, 0)
                    end
                    -- Skip unknown items silently (weapons, organs, etc. that aren't in item_defs)
                end
            end
        end
    end

    -- v2 → v3 migration: add interplanetary defaults
    if data.version == 2 then
        data.version = 3
        local gs = data.gameState or {}
        gs.activeMap = gs.planet or 'erebus'
        gs.colonies = {}
        gs.shipState = nil
        gs.discoveredPOIs = {}
        gs.discoveredPlanets = { [gs.planet or 'erebus'] = true }
        gs.spaceChunkDiffs = {}
        gs.mammonaClaimed = false
        gs.sealedDeep = false
        gs.extractionComplete = false
        gs.credits = 0
        data.gameState = gs
    end

    -- Initialize planet config from save data (before system re-registration)
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then
        Planet.init(GameState.planet)
    end

    if not skipTilemap and data.tilemap then
        local World = require('src.world.tilemap')
        local tm = data.tilemap
        if tm.layers then
            World.init(tm.w or tm.width, tm.h or tm.height)
            World.loadLayerData(tm)
            if tm.lockedDoors then
                World.setLockedDoors(tm.lockedDoors)
            end
        else
            World.init(tm.width, tm.height)
            local tData = World.rawTileData()
            local tempData = World.rawTempData()
            local size = tm.width * tm.height
            for i = 1, size do
                tData[i] = tm.tiles[i] or 0
                tempData[i] = tm.temps[i] or -40
            end
        end
    end

    ECS.init()
    local idRemap = {}
    if data.entities then
        for _, ent in ipairs(data.entities) do
            local oldId = ent._savedId
            local id = ECS.spawn()
            if oldId then
                idRemap[oldId] = id
            end
            for compName, compData in pairs(ent) do
                if compName ~= '_savedId' then
                    ECS.set(id, compName, compData)
                end
            end
        end
    end

    local Colonist = require('src.colonist.colonist')
    Colonist.registerSystems()
    local Creatures = require('src.creatures.creatures')
    Creatures.registerSystems()
    local ProductionMod = require('src.building.production')
    ProductionMod.registerSystems()
    local WorkAI = require('src.colonist.work_ai')
    WorkAI.registerSystems()
    local CombatAI = require('src.combat.combat_ai')
    if CombatAI.registerSystems then CombatAI.registerSystems() end
    local Body = require('src.combat.body')
    if Body.registerSystems then Body.registerSystems() end
    local Wounds = require('src.combat.wounds')
    if Wounds.registerSystems then Wounds.registerSystems() end
    local Ranged = require('src.combat.ranged')
    if Ranged.registerSystems then Ranged.registerSystems() end
    local MentalBreaks = require('src.colonist.mental_breaks')
    if MentalBreaks.registerSystems then MentalBreaks.registerSystems() end
    local Social = require('src.colonist.social')
    if Social.registerSystems then Social.registerSystems() end
    local Addiction = require('src.colonist.addiction')
    if Addiction.registerSystems then Addiction.registerSystems() end
    -- Clothing system (replaces legacy suits.lua)
    local cok, Clothing = pcall(require, 'src.colonist.clothing')
    if cok and Clothing.registerSystems then Clothing.registerSystems() end
    -- Migrate legacy 'suit' components to clothing items
    if cok and Clothing.equip then
        local SUIT_TO_CLOTHING = {
            thermal_suit = 'thermal_suit',
            exosuit = 'exosuit',
            diving_suit = 'diving_suit',
            space_suit = 'space_suit',
        }
        for eid, suit in pairs(ECS.getAll('suit') or {}) do
            local clothingId = SUIT_TO_CLOTHING[suit.suitId]
            if clothingId then
                -- Ensure colonist has clothing component
                if not ECS.get(eid, 'clothing') then
                    Clothing.attach(eid)
                end
                Clothing.equip(eid, clothingId, 'normal')
                -- Transfer durability from old suit
                local clothComp = ECS.get(eid, 'clothing')
                if clothComp and clothComp.outer then
                    clothComp.outer.durability = suit.durability or 100
                    if suit.o2Remaining then
                        clothComp.outer._o2Remaining = suit.o2Remaining
                    end
                end
            end
            -- Remove legacy suit component
            ECS.remove(eid, 'suit')
        end
    end
    local Lairs = require('src.creatures.lairs')
    if Lairs.registerSystems then Lairs.registerSystems() end
    local Bosses = require('src.creatures.bosses')
    if Bosses.registerSystems then Bosses.registerSystems() end
    local Bench = require('src.research.bench')
    if Bench.registerSystems then Bench.registerSystems() end
    local DeepDrill = require('src.building.deep_drill')
    if DeepDrill.registerSystems then DeepDrill.registerSystems() end
    local DeteriorationMod = require('src.sim.deterioration')
    if DeteriorationMod.registerSystems then DeteriorationMod.registerSystems() end
    local MerchantsMod = require('src.trade.merchants')
    if MerchantsMod.registerSystems then MerchantsMod.registerSystems() end
    local DiseaseMod = require('src.sim.disease')
    if DiseaseMod.registerSystems then DiseaseMod.registerSystems() end
    local GeneratorMod = require('src.sim.generator')
    if GeneratorMod.registerSystems then GeneratorMod.registerSystems() end
    local RecruitmentMod = require('src.colonist.recruitment')
    if RecruitmentMod.registerSystems then RecruitmentMod.registerSystems() end
    local ScarTraitsMod = require('src.colonist.scar_traits')
    if ScarTraitsMod.registerSystems then ScarTraitsMod.registerSystems() end
    local AgricultureMod = require('src.building.agriculture')
    if AgricultureMod.registerSystems then AgricultureMod.registerSystems() end
    local LawsMod = require('src.colony.laws')
    if LawsMod.registerSystems then LawsMod.registerSystems() end
    local ItemsMod = require('src.world.items')
    if ItemsMod.registerSystems then ItemsMod.registerSystems() end
    local ItemDecayMod = require('src.world.item_decay')
    if ItemDecayMod.registerSystems then ItemDecayMod.registerSystems() end
    local StatusFxMod = require('src.sim.status_effects')
    if StatusFxMod.registerSystems then StatusFxMod.registerSystems() end
    local DefensesMod = require('src.combat.defenses')
    if DefensesMod.registerSystems then DefensesMod.registerSystems() end
    local TrapsMod = require('src.combat.traps')
    if TrapsMod.registerSystems then TrapsMod.registerSystems() end
    local SurgeryMod = require('src.medical.surgery')
    if SurgeryMod.registerSystems then SurgeryMod.registerSystems() end
    local InsertersMod = require('src.logistics.inserters')
    if InsertersMod.registerSystems then InsertersMod.registerSystems() end
    local PipesMod = require('src.logistics.pipes')
    if PipesMod.registerSystems then PipesMod.registerSystems() end
    local PipeProcessors = require('src.logistics.pipe_processors')
    if PipeProcessors.registerSystems then PipeProcessors.registerSystems() end
    local OrdnanceMod = require('src.combat.ordnance')
    if OrdnanceMod.registerSystems then OrdnanceMod.registerSystems() end
    local EndgameMod = require('src.sim.endgame')
    if EndgameMod.registerSystems then EndgameMod.registerSystems() end
    local VisitorsMod = require('src.trade.visitors')
    if VisitorsMod.registerSystems then VisitorsMod.registerSystems() end
    local RadiationMod = require('src.sim.radiation')
    if RadiationMod.registerSystems then RadiationMod.registerSystems() end
    local MinersMod = require('src.building.miners')
    if MinersMod.registerSystems then MinersMod.registerSystems() end
    local npcOk, NPCShipsMod = pcall(require, 'src.space.npc_ships')
    if npcOk and NPCShipsMod.registerSystems then NPCShipsMod.registerSystems() end
    local smOk, ShipMovementMod = pcall(require, 'src.space.ship_movement')
    if smOk and ShipMovementMod.registerSystems then ShipMovementMod.registerSystems() end

    local RaidersReg = require('src.creatures.raiders')
    if RaidersReg.register then RaidersReg.register() end

    if data.weather then
        Weather.init()
        if data.weather.current then
            Weather.force(data.weather.current, data.weather.timeRemaining or 60)
        end
        if Weather.setWind then
            Weather.setWind(data.weather.windAngle, data.weather.windSpeed)
        end
        if data.weather.bloodRainFired and Weather.setBloodRainFired then
            Weather.setBloodRainFired(true)
        end
    end

    if data.storyteller then
        local Storyteller = require('src.storyteller.storyteller')
        Storyteller.init(data.storyteller.personality or 'steady')
        if data.storyteller.log and Storyteller.restoreLog then
            Storyteller.restoreLog(data.storyteller.log)
        end
        if Storyteller.restoreTimerState then
            Storyteller.restoreTimerState(data.storyteller)
        end
    end

    if data.hope then
        local Hope = require('src.colony.hope')
        local hs = Hope.getState()
        for k, v in pairs(data.hope) do
            hs[k] = v
        end
    end

    local Jobs = require('src.colonist.jobs')
    if data.jobs then
        Jobs.loadState(data.jobs)
        Jobs.remapEntityIds(idRemap)
    else
        Jobs.reset()
    end

    local Zones = require('src.world.zones')
    if data.zones and Zones.loadState then
        Zones.loadState(data.zones)
    elseif data.zones then
        Zones.reset()
        for _, zd in ipairs(data.zones) do
            local zid = Zones.create(zd.type, zd.tileList or {}, zd.filter)
            if zid and zd.items then
                local all = Zones.getAll()
                local zone = all[zid]
                if zone then zone.items = zd.items end
            end
        end
    else
        Zones.reset()
    end

    GameState.tutorialDone = data.tutorialDone or false

    if data.laws then
        local ok, Laws = pcall(require, 'src.colony.laws')
        if ok then Laws.restoreState(data.laws) end
    end
    if data.factions then
        local ok, Factions = pcall(require, 'src.colony.factions')
        if ok then Factions.restoreState(data.factions) end
    end
    if data.perks then
        local ok, Perks = pcall(require, 'src.colony.perks')
        if ok then Perks.restoreState(data.perks) end
    end
    if data.megabeasts then
        local ok, Mega = pcall(require, 'src.creatures.megabeasts')
        if ok then Mega.setTotalMined(data.megabeasts.totalMined) end
    end
    if data.history then
        local ok, History = pcall(require, 'src.world.history')
        if ok then History.restoreState(data.history) end
    end
    do
        local ok, HRestore = pcall(require, 'src.sim.hermes')
        if ok then
            if data.hermes and HRestore.restoreState then
                HRestore.restoreState(data.hermes)
            elseif HRestore.init then
                HRestore.init()
            end
        end
    end
    do
        local ok, QRestore = pcall(require, 'src.sim.quotas')
        if ok then
            if data.quotas and QRestore.restoreState then
                QRestore.restoreState(data.quotas)
            elseif QRestore.init then
                QRestore.init()
            end
        end
    end
    if data.elasticDifficulty then
        local ok, Elastic = pcall(require, 'src.sim.elastic_difficulty')
        if ok then Elastic.restoreState(data.elasticDifficulty) end
    end
    if data.merchants then
        local ok, MerchantsRestore = pcall(require, 'src.trade.merchants')
        if ok then MerchantsRestore.restoreState(data.merchants) end
    end
    if data.tradeRoutes then
        local ok, TRRestore = pcall(require, 'src.trade.trade_routes')
        if ok then TRRestore.restoreState(data.tradeRoutes) end
    end
    if data.visitors then
        if data.visitors.activeIds then
            for i, oldId in ipairs(data.visitors.activeIds) do
                data.visitors.activeIds[i] = idRemap[oldId] or oldId
            end
        end
        local ok, VRestore = pcall(require, 'src.trade.visitors')
        if ok then VRestore.restoreState(data.visitors) end
    end
    if data.alerts then
        local ok, ARestore = pcall(require, 'src.ui.alerts')
        if ok then ARestore.restoreState(data.alerts) end
    end
    if data.policies then
        local ok, PoliciesRestore = pcall(require, 'src.colony.policies')
        if ok then PoliciesRestore.restoreState(data.policies) end
    end
    if data.raids then
        local ok, RaidsRestore = pcall(require, 'src.sim.raids')
        if ok and RaidsRestore.restoreState then
            if data.raids.activeRaid then
                local ar = data.raids.activeRaid
                if ar.raidCreatureIds then
                    for i, oldId in ipairs(ar.raidCreatureIds) do
                        ar.raidCreatureIds[i] = idRemap[oldId] or oldId
                    end
                end
                if ar.waves then
                    for _, wave in ipairs(ar.waves) do
                        if wave.creatures then
                            for i, oldId in ipairs(wave.creatures) do
                                wave.creatures[i] = idRemap[oldId] or oldId
                            end
                        end
                    end
                end
            end
            RaidsRestore.restoreState(data.raids)
        end
    end
    if data.spoilage then
        local ok, SpoilageRestore = pcall(require, 'src.sim.spoilage')
        if ok and SpoilageRestore.loadState then SpoilageRestore.loadState(data.spoilage) end
    end
    if data.strangeMoods and data.strangeMoods.activeMood then
        local ok, SMRestore = pcall(require, 'src.colonist.strange_moods')
        if ok and SMRestore.restoreActiveMood then
            SMRestore.restoreActiveMood(data.strangeMoods.activeMood)
        end
    end
    if data.pipes then
        local ok, PipesRestore = pcall(require, 'src.logistics.pipes')
        if ok and PipesRestore.loadState then PipesRestore.loadState(data.pipes) end
    end
    if data.thermovoreSpawner then
        local ok, TSRestore = pcall(require, 'src.creatures.thermovore_spawner')
        if ok and TSRestore.loadState then TSRestore.loadState(data.thermovoreSpawner) end
    end
    if data.atmosphere then
        local ok, AtmoRestore = pcall(require, 'src.sim.atmosphere')
        if ok and AtmoRestore.loadState then AtmoRestore.loadState(data.atmosphere) end
    end
    if data.pollution then
        local ok, PollRestore = pcall(require, 'src.sim.pollution')
        if ok and PollRestore.loadState then
            if data.pollution.scrubbers then
                local remapped = {}
                for oldId, scrubber in pairs(data.pollution.scrubbers) do
                    local newId = idRemap[oldId] or oldId
                    remapped[newId] = scrubber
                end
                data.pollution.scrubbers = remapped
            end
            PollRestore.loadState(data.pollution)
        end
    end
    if data.lighting then
        local ok, LightRestore = pcall(require, 'src.sim.lighting')
        if ok and LightRestore.loadState then LightRestore.loadState(data.lighting) end
    end
    if data.social then
        local ok, SocRestore = pcall(require, 'src.colonist.social')
        if ok and SocRestore.loadState then
            if data.social.opinions then
                local remapped = {}
                for oldA, inner in pairs(data.social.opinions) do
                    local newA = idRemap[oldA] or oldA
                    remapped[newA] = {}
                    for oldB, score in pairs(inner) do
                        local newB = idRemap[oldB] or oldB
                        remapped[newA][newB] = score
                    end
                end
                data.social.opinions = remapped
            end
            if data.social.grieving then
                local remapped = {}
                for oldId, griefData in pairs(data.social.grieving) do
                    local newId = idRemap[oldId] or oldId
                    remapped[newId] = griefData
                end
                data.social.grieving = remapped
            end
            SocRestore.loadState(data.social)
        end
    end
    if data.conveyors then
        local ok, ConvRestore = pcall(require, 'src.logistics.conveyors')
        if ok and ConvRestore.loadState then ConvRestore.loadState(data.conveyors) end
    end
    if data.foraging then
        local ok, ForageRestore = pcall(require, 'src.colonist.foraging')
        if ok and ForageRestore.loadState then ForageRestore.loadState(data.foraging) end
    end
    if data.expeditions then
        local ok, ExpRestore = pcall(require, 'src.exploration.expeditions')
        if ok and ExpRestore.loadState then
            if data.expeditions.activeExpeditions then
                for _, exp in ipairs(data.expeditions.activeExpeditions) do
                    if exp.memberIds then
                        for i, oldId in ipairs(exp.memberIds) do
                            exp.memberIds[i] = idRemap[oldId] or oldId
                        end
                    end
                end
            end
            ExpRestore.loadState(data.expeditions)
        end
    end
    if data.quests then
        local ok, QuestRestore = pcall(require, 'src.quest.quest')
        if ok and QuestRestore.loadState then QuestRestore.loadState(data.quests) end
    end
    if data.buildingPlaced then
        local ok, BldRestore = pcall(require, 'src.building.building')
        if ok and BldRestore.loadState then BldRestore.loadState(data.buildingPlaced) end
    end
    if data.visibility then
        local ok, VisRestore = pcall(require, 'src.sim.visibility')
        if ok and VisRestore.loadState then VisRestore.loadState(data.visibility) end
    end
    if data.director then
        local ok, DirRestore = pcall(require, 'src.ai.director')
        if ok and DirRestore.loadState then DirRestore.loadState(data.director) end
    end
    if data.terraform then
        local ok, TfRestore = pcall(require, 'src.world.terraform')
        if ok and TfRestore.loadState then TfRestore.loadState(data.terraform) end
    end
    if data.fire then
        local ok, FiRestore = pcall(require, 'src.sim.fire')
        if ok and FiRestore.loadState then FiRestore.loadState(data.fire) end
    end
    if data.flooding then
        local ok, FlRestore = pcall(require, 'src.sim.flooding')
        if ok and FlRestore.loadState then FlRestore.loadState(data.flooding) end
    end
    if data.pressure then
        local ok, PrRestore = pcall(require, 'src.sim.pressure')
        if ok and PrRestore.loadState then PrRestore.loadState(data.pressure) end
    end
    if data.structural then
        local ok, StRestore = pcall(require, 'src.world.structural')
        if ok and StRestore.loadState then StRestore.loadState(data.structural) end
    end
    if data.biocaves then
        local ok, BcRestore = pcall(require, 'src.world.biocaves')
        if ok and BcRestore.loadState then
            if data.biocaves.activeMimics then
                for _, m in ipairs(data.biocaves.activeMimics) do
                    m.id = idRemap[m.id] or m.id
                end
            end
            BcRestore.loadState(data.biocaves)
        end
    end
    if data.caverns then
        local ok, CvRestore = pcall(require, 'src.world.caverns')
        if ok and CvRestore.loadState then CvRestore.loadState(data.caverns) end
    end
    if data.tileFluids then
        local ok, TfRestore = pcall(require, 'src.sim.tile_fluids')
        if ok and TfRestore.loadState then TfRestore.loadState(data.tileFluids) end
    end
    if data.tileGas then
        local ok, TgRestore = pcall(require, 'src.sim.tile_gas')
        if ok and TgRestore.loadState then TgRestore.loadState(data.tileGas) end
    end
    if data.tileSnow then
        local ok, TsRestore = pcall(require, 'src.sim.tile_snow')
        if ok and TsRestore.loadState then TsRestore.loadState(data.tileSnow) end
    end
    if data.eldritchNodes then
        local ok, ENRestore = pcall(require, 'src.creatures.eldritch_nodes')
        if ok and ENRestore.restoreState then ENRestore.restoreState(data.eldritchNodes) end
    end
    if data.taming then
        local ok, TamingRestore = pcall(require, 'src.creatures.taming')
        if ok and TamingRestore.restoreState then TamingRestore.restoreState(data.taming) end
    end
    if data.research then
        local ok, ResearchRestore = pcall(require, 'src.research.research')
        if ok and ResearchRestore.restoreState then ResearchRestore.restoreState(data.research) end
    end
    if data.ordnance then
        local ok, OrdRestore = pcall(require, 'src.combat.ordnance')
        if ok and OrdRestore.loadState then OrdRestore.loadState(data.ordnance) end
    end
    if data.filth then
        local ok, FilthRestore = pcall(require, 'src.sim.filth')
        if ok and FilthRestore.loadState then FilthRestore.loadState(data.filth) end
    end
    if data.seasons then
        local ok, SeasonsRestore = pcall(require, 'src.world.seasons')
        if ok and SeasonsRestore.loadState then SeasonsRestore.loadState(data.seasons) end
    end
    if data.waterFeatures then
        local ok, WFRestore = pcall(require, 'src.world.water_features')
        if ok and WFRestore.loadState then WFRestore.loadState(data.waterFeatures) end
    end
    if data.mapSecrets then
        local ok, MSRestore = pcall(require, 'src.world.map_secrets')
        if ok and MSRestore.loadState then
            if data.mapSecrets.records then
                for _, rec in ipairs(data.mapSecrets.records) do
                    rec.id = idRemap[rec.id] or rec.id
                end
            end
            MSRestore.loadState(data.mapSecrets)
        end
    end
    if data.skinwalker then
        local ok, SWRestore = pcall(require, 'src.creatures.skinwalker')
        if ok and SWRestore.loadState then
            if data.skinwalker.activeHunts then
                for _, hunt in pairs(data.skinwalker.activeHunts) do
                    hunt.entityId = idRemap[hunt.entityId] or hunt.entityId
                    if hunt.targetId then
                        hunt.targetId = idRemap[hunt.targetId] or hunt.targetId
                    end
                end
            end
            SWRestore.loadState(data.skinwalker)
        end
    end
    if data.thermalDeepening then
        local ok, TDRestore = pcall(require, 'src.sim.thermal_deepening')
        if ok and TDRestore.restoreState then TDRestore.restoreState(data.thermalDeepening) end
    end
    if data.anomaly then
        if data.anomaly.bossEntityId then
            data.anomaly.bossEntityId = idRemap[data.anomaly.bossEntityId] or data.anomaly.bossEntityId
        end
        local ok, ANRestore = pcall(require, 'src.sim.anomaly')
        if ok and ANRestore.restoreState then ANRestore.restoreState(data.anomaly) end
    end
    do
        local ok, EERestore = pcall(require, 'src.sim.easter_eggs')
        if ok then
            if data.easterEggs and EERestore.restoreState then
                EERestore.restoreState(data.easterEggs)
            elseif EERestore.init then
                EERestore.init()
            end
        end
    end
    if data.rivals then
        local ok, RivalsRestore = pcall(require, 'src.sim.rivals')
        if ok and RivalsRestore.loadState then RivalsRestore.loadState(data.rivals) end
    end
    if data.workOrders then
        local ok, WORestore = pcall(require, 'src.building.work_orders')
        if ok and WORestore.restoreState then WORestore.restoreState(data.workOrders) end
    end
    if data.advisor then
        local ok, AdvRestore = pcall(require, 'src.ui.advisor')
        if ok and AdvRestore.loadState then AdvRestore.loadState(data.advisor) end
    end
    if data.doctrines then
        local ok, DocRestore = pcall(require, 'src.colony.doctrines')
        if ok and DocRestore.loadState then DocRestore.loadState(data.doctrines) end
    end
    do
        local ok, ContainmentRestore = pcall(require, 'src.sim.containment')
        if ok then
            if data.containment and ContainmentRestore.restoreState then
                if data.containment.subjects then
                    for _, subject in pairs(data.containment.subjects) do
                        if subject.cellId then
                            subject.cellId = idRemap[subject.cellId] or subject.cellId
                        end
                    end
                end
                ContainmentRestore.restoreState(data.containment)
            elseif ContainmentRestore.init then
                ContainmentRestore.init()
            end
        end
    end

    if data.corrosion then
        local ok, CorrosionRestore = pcall(require, 'src.sim.corrosion')
        if ok and CorrosionRestore.loadState then CorrosionRestore.loadState(data.corrosion) end
    end
    if data.baldrungen then
        local ok, BaldrungenRestore = pcall(require, 'src.sim.baldrungen')
        if ok and BaldrungenRestore.loadState then BaldrungenRestore.loadState(data.baldrungen) end
    end

    -- Space subsystem restore
    if data.shipMovement then
        local ok, SM = pcall(require, 'src.space.ship_movement')
        if ok and SM.loadState then SM.loadState(data.shipMovement) end
    end
    if data.spaceTilemap then
        local ok, ST = pcall(require, 'src.space.space_tilemap')
        if ok and ST.loadState then ST.loadState(data.spaceTilemap) end
    end
    if data.shipConstruction then
        local ok, SC = pcall(require, 'src.space.ship_construction')
        if ok and SC.loadState then SC.loadState(data.shipConstruction) end
    end
    if data.npcShips then
        local ok, NS = pcall(require, 'src.space.npc_ships')
        if ok and NS.loadState then NS.loadState(data.npcShips) end
    end
    if data.caravans then
        local ok, C = pcall(require, 'src.space.caravans')
        if ok and C.loadState then C.loadState(data.caravans) end
    end
    if data.spaceEconomy then
        local ok, SE = pcall(require, 'src.space.space_economy')
        if ok and SE.loadState then SE.loadState(data.spaceEconomy) end
    end
    if data.stationDocking then
        local ok, SD = pcall(require, 'src.space.station_docking')
        if ok and SD.loadState then SD.loadState(data.stationDocking) end
    end
    if data.planetDiscovery then
        local ok, PD = pcall(require, 'src.space.planet_discovery')
        if ok and PD.loadState then PD.loadState(data.planetDiscovery) end
    end
    if data.shipCombat then
        local ok, SC = pcall(require, 'src.space.ship_combat')
        if ok and SC.loadState then SC.loadState(data.shipCombat) end
    end
    if data.boarding then
        local ok, B = pcall(require, 'src.space.boarding')
        if ok and B.loadState then B.loadState(data.boarding) end
    end
    if data.stealth then
        local ok, S = pcall(require, 'src.space.stealth')
        if ok and S.loadState then S.loadState(data.stealth) end
    end
    if data.spaceHazards then
        local ok, H = pcall(require, 'src.space.hazards')
        if ok and H.loadState then H.loadState(data.spaceHazards) end
    end
    if data.spaceEvents then
        local ok, SE = pcall(require, 'src.space.space_events')
        if ok and SE.loadState then SE.loadState(data.spaceEvents) end
    end
    if data.easterEggsSpace then
        local ok, EE = pcall(require, 'src.space.easter_eggs_space')
        if ok and EE.loadState then EE.loadState(data.easterEggsSpace) end
    end
    if data.celestialBodies then
        local ok, CB = pcall(require, 'src.space.celestial_bodies')
        if ok and CB.loadState then CB.loadState(data.celestialBodies) end
    end

    for _, comps in ECS.query('item') do
        if comps.item then comps.item._haulTaskId = nil end
    end
    for _, comps in ECS.query('colonist') do
        if comps.colonist then
            if comps.colonist._bedId then
                comps.colonist._bedId = idRemap[comps.colonist._bedId] or comps.colonist._bedId
            end
            comps.colonist._recTarget = nil
        end
    end
    for _, comps in ECS.query('bed') do
        if comps.bed then
            if comps.bed.owner then
                comps.bed.owner = idRemap[comps.bed.owner] or comps.bed.owner
            end
            comps.bed.occupied = false
        end
    end
    for _, comps in ECS.query('machine') do
        if comps.machine then comps.machine.assignee = nil end
    end
    for _, comps in ECS.query('crop') do
        if comps.crop then comps.crop._harvestTaskId = nil end
    end
    for _, comps in ECS.query('durability') do
        if comps.durability then comps.durability.repairTask = nil end
    end
    for _, comps in ECS.query('turret') do
        if comps.turret then comps.turret.target = nil end
    end
    for _, comps in ECS.query('creature') do
        if comps.creature then comps.creature.target = nil end
    end
    for _, comps in ECS.query('colonist') do
        if comps.colonist then comps.colonist.task = nil end
    end
    for _, comps in ECS.query('recreation') do
        if comps.recreation then
            comps.recreation.users = {}
            comps.recreation.userCount = 0
        end
    end
    for _, comps in ECS.query('deep_drill') do
        local drill = comps.deep_drill
        if drill.operatorId then
            drill.operatorId = idRemap[drill.operatorId]  -- nil if colonist gone; drill re-assigns
        end
    end

    local Occupancy = require('src.util.occupancy')
    Occupancy.rebuild()

    local Power = require('src.sim.power')
    Power.init()
    for id, comps in ECS.query('building_ref', 'pos') do
        local ref = comps.building_ref
        local pos = comps.pos
        if ref.type == 'generator' then
            local BuildingMod = require('src.building.building')
            local def = BuildingMod.defs[ref.defId]
            if def and def.genType then
                Power.addGenerator(id, def.genType, pos.x, pos.y)
            end
        elseif ref.type == 'battery' then
            local batComp = ECS.get(id, 'battery')
            local cap = batComp and batComp.capacity or 1000
            local eff = batComp and batComp.chargeEff
            local sd = batComp and batComp.selfDischarge
            Power.addBattery(id, pos.x, pos.y, cap, eff, sd)
        elseif ref.type == 'power_switch' then
            Power.addSwitch(id, pos.x, pos.y)
        elseif ref.type == 'sump_pump' then
            local fOk, FloodingMod = pcall(require, 'src.sim.flooding')
            if fOk and FloodingMod.addPump then
                local World = require('src.world.tilemap')
                local roomId = World.getRoom and World.getRoom(pos.x, pos.y, pos.depth or 0) or 0
                FloodingMod.addPump(id, roomId, 0.03)
            end
            local BuildingMod = require('src.building.building')
            local def = BuildingMod.defs[ref.defId]
            if def and def.powerDraw then
                Power.addConsumer(id, def.powerDraw, pos.x, pos.y)
            end
        elseif ref.type == 'light_source' then
            local BuildingMod = require('src.building.building')
            local def = BuildingMod.defs[ref.defId]
            if def and def.powerDraw then
                Power.addConsumer(id, def.powerDraw, pos.x, pos.y, 'low')
            end
        elseif ref.type == 'endgame' then
            local BuildingMod = require('src.building.building')
            local def = BuildingMod.defs[ref.defId]
            if def and def.powerDraw then
                Power.addConsumer(id, def.powerDraw, pos.x, pos.y, 'critical')
            end
        elseif ref.type == 'cryo_pod' or ref.type == 'scrubber' or ref.type == 'containment' then
            local BuildingMod = require('src.building.building')
            local def = BuildingMod.defs[ref.defId]
            if def and def.powerDraw then
                Power.addConsumer(id, def.powerDraw, pos.x, pos.y)
            end
        end
    end

    for id, comps in ECS.query('pos') do
        local pos = comps.pos
        if ECS.get(id, 'machine') then
            local mach = ECS.get(id, 'machine')
            local BuildingMod = require('src.building.building')
            local matched = false
            for _, def in pairs(BuildingMod.defs) do
                if (def.machineType == mach.type or def.ventType == mach.type) and def.powerDraw then
                    Power.addConsumer(id, def.powerDraw, pos.x, pos.y)
                    matched = true
                    break
                end
            end
            -- Processors use processorType, not machineType
            if not matched and ECS.get(id, 'processor') then
                for _, def in pairs(BuildingMod.defs) do
                    if def.processorType == mach.type and def.powerDraw then
                        Power.addConsumer(id, def.powerDraw, pos.x, pos.y)
                        break
                    end
                end
            end
        end
        if ECS.get(id, 'turret') then
            local turret = ECS.get(id, 'turret')
            local BuildingMod = require('src.building.building')
            for _, def in pairs(BuildingMod.defs) do
                if def.turretType == turret.type and def.powerDraw then
                    Power.addConsumer(id, def.powerDraw, pos.x, pos.y)
                    break
                end
            end
        end
        if ECS.get(id, 'shield') then
            Power.addConsumer(id, 50, pos.x, pos.y, 'critical')
        end
        if ECS.get(id, 'cloning_vat') then
            Power.addConsumer(id, 30, pos.x, pos.y)
        end
        if ECS.get(id, 'radio_beacon') then
            Power.addConsumer(id, 15, pos.x, pos.y, 'low')
        end
        if ECS.get(id, 'deep_drill') then
            Power.addConsumer(id, 50, pos.x, pos.y)
        end
        if ECS.get(id, 'miner') then
            local miner = ECS.get(id, 'miner')
            local mok, MinersMod = pcall(require, 'src.building.miners')
            if mok and MinersMod.DEFS then
                local mdef = MinersMod.DEFS[miner.type]
                if mdef and mdef.powerDraw > 0 then
                    Power.addConsumer(id, mdef.powerDraw, pos.x, pos.y)
                end
            end
        end
    end

    -- Re-register vents with Atmosphere from ECS machine components
    local atOk, AtmoMod = pcall(require, 'src.sim.atmosphere')
    if atOk then
        local World = require('src.world.tilemap')
        local BuildingMod = require('src.building.building')
        for id, comps in ECS.query('machine', 'pos') do
            local mach = ECS.get(id, 'machine')
            for _, def in pairs(BuildingMod.defs) do
                if def.ventType and def.ventType == mach.type then
                    local rid = World.getRoom(comps.pos.x, comps.pos.y, comps.pos.depth or 0) or 0
                    AtmoMod.addVent(id, def.ventType, rid, comps.pos.x, comps.pos.y, id, comps.pos.depth or 0)
                    break
                end
            end
        end
    end

    local GenMod = require('src.sim.generator')
    if GenMod.restoreFromECS then GenMod.restoreFromECS() end

    if data.power then
        if data.power.generators then
            local remapped = {}
            for oldId, state in pairs(data.power.generators) do
                local newId = idRemap[oldId] or oldId
                if state.assignees then
                    local remappedWorkers = {}
                    for _, wid in ipairs(state.assignees) do
                        local newWid = idRemap[wid]
                        if newWid then remappedWorkers[#remappedWorkers + 1] = newWid end
                    end
                    state.assignees = remappedWorkers
                    state.assignedCount = #remappedWorkers
                end
                remapped[newId] = state
            end
            data.power.generators = remapped
        end
        if data.power.batteries then
            local remapped = {}
            for oldId, state in pairs(data.power.batteries) do
                local newId = idRemap[oldId] or oldId
                remapped[newId] = state
            end
            data.power.batteries = remapped
        end
        Power.loadState(data.power)
    end

    local goOk, GameOverMod = pcall(require, 'src.ui.game_over')
    if goOk and GameOverMod.reset then GameOverMod.reset() end

    GameState._lastAutoSaveDay = GameState.day
    return true
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Save.load(filename)
    filename = filename or Context.QUICK_SAVE_FILE
    if not love.filesystem.getInfo(filename) then
        print('[Save] No save file found: ' .. filename)
        return false
    end

    local str, err = love.filesystem.read(filename)
    if not str then
        print('[Save] ERROR reading save file: ' .. tostring(err))
        return false
    end

    local data, dErr = Helpers.deserialize(str)
    if not data then
        print('[Save] ERROR deserializing: ' .. tostring(dErr))
        return false
    end

    if not data.version or data.version < 1 or data.version > 3 then
        print('[Save] Unknown save version: ' .. tostring(data.version))
        return false
    end

    local ok = restoreFromData(data, false)
    if ok then
        print('[Save] Loaded from ' .. filename)
    end
    return ok
end

---------------------------------------------------------------------------
-- In-memory snapshot API for context-swap (interplanetary travel)
---------------------------------------------------------------------------

function Save.snapshotToMemory()
    return Helpers.buildSaveData()
end

function Save.loadFromMemory(snapshotData, skipTilemap)
    if not snapshotData then return false end
    return restoreFromData(snapshotData, skipTilemap or false)
end

return Save
