-- colony_legacy.lua — Colony legacy system
-- When a colony falls (all colonists die), its stats are saved as a legacy record.
-- Legacy colonies appear as overworld ruins in future playthroughs.
-- Players can send expeditions to fallen colony sites for unique loot.
--
-- Storage is delegated to the MRP campaign layer (frosthold_campaign.dat).
-- MRP.load() is called in main.lua at startup; no file I/O here.

local GameState = require('src.game_state')

local Legacy = {}

---------------------------------------------------------------------------
-- Record a fallen colony
---------------------------------------------------------------------------

function Legacy.recordFallenColony(causeOfDeath)
    local ECS = require('src.ecs.ecs')

    -- Count all colonist entities (alive and dead) and tally boss kills
    local peakPop = 0
    local bossesKilled = 0
    for id, comps in ECS.query('colonist') do
        peakPop = peakPop + 1
        local col = comps.colonist
        bossesKilled = bossesKilled + (col.bossKills or 0)
    end

    -- Snapshot all resources with amount > 0
    local resSnapshot = {}
    for res, amount in pairs(GameState.resources or {}) do
        if amount > 0 then
            resSnapshot[res] = amount
        end
    end

    -- Snapshot all placed buildings (entities with building_ref + pos)
    local buildingSnapshot = {}
    for id, comps in ECS.query('building_ref', 'pos') do
        local ref = comps.building_ref
        local pos = comps.pos
        local dur = ECS.get(id, 'durability')
        buildingSnapshot[#buildingSnapshot + 1] = {
            defId = ref.defId,
            x     = pos.x,
            y     = pos.y,
            hp    = dur and dur.hp or nil,
            depth = pos.depth or 0,
        }
    end

    -- Snapshot research state
    local researchCompleted = {}
    local researchInProgress = {}
    local rok, ResearchMod = pcall(require, 'src.research.research')
    if rok and ResearchMod.getCompletedList then
        researchCompleted = ResearchMod.getCompletedList()
    end
    if rok and ResearchMod.getInProgressList then
        researchInProgress = ResearchMod.getInProgressList()
    end

    -- Snapshot colonist records
    local colonistRecords = {}
    for id, comps in ECS.query('colonist') do
        local col = comps.colonist
        local pos = comps.pos
        local inv = ECS.get(id, 'inventory')
        local skillList = {}
        if inv and inv.skills then
            for skillId, lvl in pairs(inv.skills) do
                skillList[#skillList + 1] = { skill = skillId, level = lvl }
            end
        end
        colonistRecords[#colonistRecords + 1] = {
            name      = col.name or 'Unknown',
            backstory = col.backstory or nil,
            deathX    = pos and pos.x or nil,
            deathY    = pos and pos.y or nil,
            skills    = skillList,
        }
    end

    -- Map seed from tilemap (best-effort via pcall)
    local mapSeed = GameState.worldSeedNumeric
    local wok, World = pcall(require, 'src.world.tilemap')
    if wok and World.getLayerData then
        local layerData = World.getLayerData()
        if layerData and layerData.seed then
            mapSeed = layerData.seed
        end
    end

    local record = {
        planetId              = GameState.planet or 'erebus',
        colonyName            = GameState.colonyName or 'Unnamed Colony',
        daysSurvived          = GameState.day or 0,
        peakPopulation        = peakPop,
        causeOfDeath          = causeOfDeath or 'unknown',
        wealth                = GameState.getColonyWealth and GameState.getColonyWealth() or 0,
        raidsSurvived         = GameState.raidsSurvived or 0,
        buildingsConstructed  = GameState.buildingsConstructed or 0,
        bossesKilled          = bossesKilled,
        timestamp             = os.time(),
        resources             = resSnapshot,
        buildings             = buildingSnapshot,
        researchCompleted     = researchCompleted,
        researchInProgress    = researchInProgress,
        colonists             = colonistRecords,
        mapSeed               = mapSeed,
        worldSeedNumeric      = GameState.worldSeedNumeric,
        landingZone           = GameState.landingZone,
        nemeses               = {},
        mrpEarned             = 0,
        x                     = GameState.startX or math.random(30, 100),
        y                     = GameState.startY or math.random(30, 100),
    }

    -- Store via MRP campaign layer
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if mok then
        MRP.addPlanetDeployment(record.planetId, record)
        MRP.save()
    end

    return record
end

---------------------------------------------------------------------------
-- Query legacies — reads from MRP for all planets
---------------------------------------------------------------------------

function Legacy.getLegacies()
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if not mok then return {} end
    local all = {}
    local planets = { 'erebus', 'rhea2', 'morvos', 'nerthus9', 'paxteraprime', 'nemaea', 'gaiaa1x' }
    for _, planetId in ipairs(planets) do
        local history = MRP.getPlanetHistory(planetId)
        for _, rec in ipairs(history) do
            all[#all + 1] = rec
        end
    end
    return all
end

function Legacy.getLegacyCount()
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if not mok then return 0 end
    local count = 0
    local planets = { 'erebus', 'rhea2', 'morvos', 'nerthus9', 'paxteraprime', 'nemaea', 'gaiaa1x' }
    for _, planetId in ipairs(planets) do
        count = count + MRP.getDeploymentCount(planetId)
    end
    return count
end

-- Get legacies formatted as overworld expedition destinations
function Legacy.getLegacyDestinations()
    local legacies = Legacy.getLegacies()
    local dests = {}
    for i, leg in ipairs(legacies) do
        dests[#dests + 1] = {
            id          = 'legacy_ruin_' .. i,
            name        = 'Ruins of ' .. (leg.colonyName or 'Unknown Colony'),
            desc        = string.format(
                'Former colony. Survived %d days, population peaked at %d. Fell to %s.',
                leg.daysSurvived or 0, leg.peakPopulation or 0, leg.causeOfDeath or 'unknown'),
            risk        = math.min(5, math.floor((leg.daysSurvived or 0) / 20) + 1),
            minParty    = 1,
            duration    = 90 + (leg.daysSurvived or 0),
            x           = leg.x,
            y           = leg.y,
            resources   = leg.resources,
            daysFallen  = leg.daysSurvived,
        }
    end
    return dests
end

-- Get loot table for a legacy ruin expedition (index into getLegacies list)
function Legacy.getLegacyLoot(legacyIndex)
    local legacies = Legacy.getLegacies()
    local leg = legacies[legacyIndex]
    if not leg then return {} end

    local loot = {}

    -- Salvage a fraction of the fallen colony's resources
    for res, amount in pairs(leg.resources or {}) do
        local salvage = math.floor(amount * 0.15)
        if salvage > 0 then
            loot[#loot + 1] = { resource = res, amount = salvage }
        end
    end

    -- Bonus: longer-lived colonies have better salvage
    if (leg.daysSurvived or 0) > 30 then
        loot[#loot + 1] = { resource = 'components', amount = math.floor(leg.daysSurvived / 10) }
    end
    if (leg.daysSurvived or 0) > 60 then
        loot[#loot + 1] = { resource = 'thermalCores', amount = math.floor(leg.daysSurvived / 20) }
    end

    return loot
end

---------------------------------------------------------------------------
-- Init — MRP.load() in main.lua handles campaign data; nothing to do here
---------------------------------------------------------------------------

function Legacy.init()
    -- No-op: campaign data is loaded by MRP.load() in main.lua at startup.
end

return Legacy
