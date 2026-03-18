-- game_state.lua — Global game state singleton
-- Central source of truth for colony status, time, and configuration.

local GameState = {
    -- Game phase: 'menu' → 'planet_select' → 'world_map' → 'drafting' → 'starting' → 'playing'
    phase     = 'menu',

    -- Colony identity
    colonyName = 'Frosthold',
    planet     = 'erebus',
    landingZone = nil,   -- set by world_map.lua hex selection
    scenario   = 'crashlanded',
    director   = 'chronicler',
    playerFaction = 'mammona_mining',  -- corporate employer; Mammona Mining subsidiary
    hermesPhase = 'functional',
    hermesDirective = nil,

    -- Map dimensions (tiles)
    mapWidth  = 128,
    mapHeight = 128,

    -- Starting position (center of map)
    startX = 64,
    startY = 64,

    -- World generation (set by Create World screen)
    worldSeed        = '',     -- player-entered seed string
    worldSeedNumeric = nil,    -- numeric hash for noise functions (nil = random)

    -- Faction selection (set by Scenario picker)
    selectedFactions = nil,    -- array of faction IDs, nil = all factions

    -- Landing site selection flag (set by Landing Site screen)
    landingSiteSelected = false,  -- true = startX/startY were set by player

    -- Simulation
    colonyRealTime = 0,  -- cumulative real-time seconds since colony start (persisted)
    simTick   = 0,
    alpha     = 0,    -- interpolation alpha (0-1) between sim ticks
    paused    = false,
    speed     = 1,    -- 1x, 2x, 3x
    showDebug = false, -- F3 toggles debug overlay

    -- Time
    day       = 1,
    hour      = 6.0,  -- fractional hours (6.0 = 6:00 AM)
    season    = 'winter', -- always winter on this frozen hellworld

    -- Temperature (Celsius)
    globalTemp    = -40,  -- ambient outside temperature
    windChill     = 0,    -- additional wind chill factor
    baseTemp      = -40,  -- base temp before weather modifiers
    tempBias      = 0,    -- difficulty climate modifier applied on top of seasonal baseline
    weatherHarshness = 1.0, -- difficulty modifier for storm severity/frequency

    -- Colony resources
    resources = {
        thermalCores = 0,
        wood         = 50,
        stone        = 30,
        metal        = 0,
        food         = 40,
        fuel         = 20,
        water        = 10,
        components   = 0,
        hide         = 0,
        -- Corpses
        corpse_creature = 0,
        corpse_human    = 0,
        -- Dark processing
        human_meat      = 0,
        human_leather   = 0,
        -- Organs
        organ_heart     = 0,
        organ_lung      = 0,
        organ_kidney    = 0,
        organ_liver     = 0,
        organ_eye       = 0,
        -- Prosthetics
        peg_leg         = 0,
        wooden_arm      = 0,
        prosthetic_leg  = 0,
        prosthetic_arm  = 0,
        bionic_leg      = 0,
        bionic_arm      = 0,
        bionic_eye      = 0,
        -- Drug crop materials
        psychoid_leaf   = 0,
        smokeleaf_leaf  = 0,
        hops            = 0,
        hay             = 0,
        -- Produced drugs
        spike           = 0,
        stardust        = 0,
        drift           = 0,
        smog            = 0,
        rotgut          = 0,
        shards          = 0,
        glimpse         = 0,
        surge           = 0,
        thaw            = 0,
        voidbloom       = 0,
        berserker       = 0,
        stim            = 0,
        -- Medical supplies
        bandage         = 0,
        medicine        = 0,
        advanced_medicine = 0,
        revivify_serum  = 0,
        -- Intermediate processed materials
        charcoal        = 0,
        cut_stone       = 0,
        cloth           = 0,
        glass           = 0,
        insulation      = 0,
        pipe            = 0,
        medicinal_herb  = 0,
        -- Advanced materials
        steel           = 0,
        plasteel        = 0,
        circuit         = 0,
        raw_hide        = 0,
        lead            = 0,
        -- Eldritch resources
        eldritch_ichor  = 0,
        raw_fat         = 0,
        chitin_plate    = 0,
        void_crystal    = 0,
        raw_fur         = 0,
        caustic_liquid  = 0,
        serpent_venom   = 0,
        fang            = 0,
        xenolith_egg    = 0,
        xenolith_chitin = 0,
        xenolith_tissue = 0,
        -- Weapons (melee)
        weapon_club         = 0,
        weapon_shiv         = 0,
        weapon_pipe_wrench  = 0,
        weapon_torch        = 0,
        weapon_knife        = 0,
        weapon_hatchet      = 0,
        weapon_machete      = 0,
        weapon_spear        = 0,
        weapon_axe          = 0,
        weapon_sword        = 0,
        -- Weapons (ranged)
        weapon_shortbow     = 0,
        weapon_bow          = 0,
        weapon_crossbow     = 0,
        weapon_revolver     = 0,
        weapon_pistol       = 0,
        weapon_sawed_off    = 0,
        weapon_pump_shotgun = 0,
        weapon_bolt_action  = 0,
        weapon_assault_rifle = 0,
        weapon_battle_rifle = 0,
        -- Ammo
        ammo_arrow          = 0,
        ammo_fire_arrow     = 0,
        ammo_bolt           = 0,
        ammo_bullet         = 0,
        ammo_shell          = 0,
        ammo_rocket         = 0,
        ammo_mortar_shell   = 0,
        napalm_fuel         = 0,
        foam_canister       = 0,
        gas_canister        = 0,
        acid_canister       = 0,
        poison_darts        = 0,
        -- Throwables
        grenade             = 0,
        ied                 = 0,
        molotov             = 0,
        pipe_bomb           = 0,
        -- Ordnance
        placed_charge       = 0,
        timed_bomb          = 0,
        tripwire_bomb       = 0,
        napalm_grenade      = 0,
        napalm_bomb         = 0,
        bio_grenade         = 0,
        bio_bomb            = 0,
        foam_grenade        = 0,
        foam_bomb           = 0,
        c4_charge           = 0,
        emp_charge          = 0,
        emp_grenade         = 0,
        briefcase_nuke      = 0,
        nuclear_core        = 0,
        -- Missiles
        missile_he          = 0,
        missile_napalm      = 0,
        missile_bio         = 0,
        missile_foam        = 0,
        missile_bunker      = 0,
        missile_nuke        = 0,
    },

    -- Build mode
    buildMode     = false,
    buildGhost    = nil,  -- { id, w, h } of current placement ghost
    buildDirection = 'right',  -- right/down/left/up (R to cycle)
    selectedTool  = nil,  -- 'build', 'mine', 'chop', 'harvest', 'designate'

    -- Selection
    selectedEntities = {},
    selectedZoneId = nil,

    -- Camera defaults
    camX = 0,
    camY = 0,
    camZoom = 1,

    -- View layer: which depth level the player is looking at / interacting with
    viewDepth = 0,

    -- Fog of war (Factorio-style, toggleable in game setup)
    fogOfWar = true,

    -- Difficulty axes
    creatureAggression = 1.0,
    resourceScarcity   = 1.0,
    diseasePressure    = 1.0,

    -- Auto-pause toggles (player-configurable)
    autoPause = {
        onRaid         = true,
        onDeath        = true,
        onMentalBreak  = false,
        onMeltdown     = true,
    },

    -- Mammona Safety Net — when all colonists die, Mammona drops 2 replacements (once per game)
    mammonaSafetyNet = true,
    _safetyNetUsed   = false,

    -- Interplanetary state
    activeMap = nil,
    colonies = {},
    shipState = nil,
    discoveredPOIs = {},
    discoveredPlanets = {},
    spaceChunkDiffs = {},
    mammonaClaimed = false,
    sealedDeep = false,
    extractionComplete = false,
    credits = 0,

    -- Sunny quest state
    _sunnyFound = false,
    _sunnyRescued = false,
}

function GameState.init()
    GameState.simTick = 0
    GameState.colonyRealTime = 0
    GameState.day     = 1
    GameState.hour    = 6.0
    GameState.tempBias = 0
    GameState.weatherHarshness = 1.0
    GameState.creatureAggression = 1.0
    GameState.resourceScarcity = 1.0
    GameState.diseasePressure = 1.0
    GameState.paused  = false
    GameState.speed   = 1
    GameState.viewDepth = 0
    GameState.selectedZoneId = nil
    GameState.hermesPhase = 'functional'
    GameState.hermesDirective = nil
    GameState.mammonaSafetyNet = true
    GameState._safetyNetUsed = false
    GameState.planet = 'erebus'
    GameState.landingZone = nil
    GameState.endlessMode = nil
    GameState.raidsSurvived = 0
    GameState.worldSeed = ''
    GameState.worldSeedNumeric = nil
    GameState.selectedFactions = nil
    GameState.landingSiteSelected = false
    -- Interplanetary state
    GameState.activeMap = nil
    GameState.colonies = {}
    GameState.shipState = nil
    GameState.discoveredPOIs = {}
    GameState.discoveredPlanets = {}
    GameState.spaceChunkDiffs = {}
    GameState.mammonaClaimed = false
    GameState.sealedDeep = false
    GameState.extractionComplete = false
    GameState.credits = 0
    -- Sunny quest state
    GameState._sunnyFound = false
    GameState._sunnyRescued = false
    -- Center camera on start position
    GameState.camX = GameState.startX * 32
    GameState.camY = GameState.startY * 32
end

-- Advance game clock. Called each sim tick (20Hz).
function GameState.tickClock()
    -- 1 game-hour = 60 real seconds at 1x speed
    -- GameState.speed already applied via accumulator tick rate
    local hoursPerTick = (1 / 20) / 60
    GameState.hour = GameState.hour + hoursPerTick
    if GameState.hour >= 24 then
        GameState.hour = GameState.hour - 24
        GameState.day = GameState.day + 1

        -- Clear expired environmental hazards
        if GameState.toxicFallout and GameState.day >= GameState.toxicFallout.endDay then
            GameState.toxicFallout = nil
        end
        if GameState.volcanicAsh and GameState.day >= GameState.volcanicAsh.endDay then
            GameState.volcanicAsh = nil
        end
    end
end

function GameState.isDaytime()
    local rise, set = 6, 20
    local sok, Seasons = pcall(require, 'src.world.seasons')
    if sok then
        local dl = Seasons.getDaylight()
        rise = dl.rise
        set  = dl.set
    end
    return GameState.hour >= rise and GameState.hour < set
end

function GameState.getEffectiveTemp()
    return GameState.globalTemp + GameState.windChill
end

function GameState.getColonyWealth()
    local wealth = 0

    -- Sum physical ground items
    local ok, ECSmod = pcall(require, 'src.ecs.ecs')
    if ok then
        local ItemDefs = require('src.world.item_defs')
        local Quality = require('src.world.quality')
        for eid, item in pairs(ECSmod.getAll('item') or {}) do
            if not item.hauled then
                local def = ItemDefs.get(item.itemId)
                local qData = Quality.get(item.quality or 'normal')
                local valueMult = qData and qData.valueMult or 1.0
                wealth = wealth + (def.weight * (item.amount or 1) * valueMult)
            end
        end
    end

    -- Sum zone-stored items
    local zok, Zones = pcall(require, 'src.world.zones')
    if zok and Zones.getAllStoredItems then
        local ItemDefs = require('src.world.item_defs')
        local Quality = require('src.world.quality')
        for _, storedItem in ipairs(Zones.getAllStoredItems()) do
            local def = ItemDefs.get(storedItem.itemId)
            local qData = Quality.get(storedItem.quality or 'normal')
            local valueMult = qData and qData.valueMult or 1.0
            wealth = wealth + (def.weight * (storedItem.amount or 1) * valueMult)
        end
    end

    -- Sum storage building contents
    local stOk, ECSmod2 = pcall(require, 'src.ecs.ecs')
    if stOk then
        local ItemDefs = require('src.world.item_defs')
        local Quality = require('src.world.quality')
        for _, stor in pairs(ECSmod2.getAll('storage') or {}) do
            for i = 1, (stor.slots or 0) do
                local slot = stor.contents and stor.contents[i]
                if slot then
                    local def = ItemDefs.get(slot.itemId)
                    local qData = Quality.get(slot.quality or 'normal')
                    local valueMult = qData and qData.valueMult or 1.0
                    wealth = wealth + (def.weight * (slot.amount or 1) * valueMult)
                end
            end
        end
    end

    -- Resource value table used for building cost calculations below
    local values = {
        thermalCores = 10, wood = 1, stone = 1, metal = 3,
        food = 2, fuel = 2, water = 1, components = 5, hide = 2,
        steel = 5, circuit = 8, raw_hide = 1, lead = 3,
    }
    -- Infrastructure: placed buildings contribute to base quality
    local bok, Building = pcall(require, 'src.building.building')
    if bok and Building.getAll then
        for _, info in pairs(Building.getAll()) do
            -- Base building value from its construction cost
            local bldValue = 0
            if info.def and info.def.cost then
                for res, amt in pairs(info.def.cost) do
                    bldValue = bldValue + amt * (values[res] or 2)
                end
            end
            -- Upgrades increase value
            local lvl = info.upgradeLevel or 0
            bldValue = bldValue * (1 + lvl * 0.3)
            wealth = wealth + bldValue
        end
    end
    -- Living colonists with equipment
    local ECS = require('src.ecs.ecs')
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' then
            wealth = wealth + 50  -- each colonist is worth something
        end
    end
    return math.floor(wealth)
end

-- DEPRECATED: callers now spawn Items directly via Items.spawn() or StorageNetwork.withdraw().
-- This function is kept as a counter-only fallback for legacy/error paths.
function GameState.addResource(name, amount)
    if GameState.resources[name] ~= nil then
        -- Difficulty: resource scarcity scales positive yields only (not losses)
        local actual = amount
        if amount > 0 then
            local scarcity = GameState.resourceScarcity or 1.0
            actual = math.floor(amount * scarcity + 0.5)
        end
        GameState.resources[name] = GameState.resources[name] + actual

        -- Notify quest system for gather objectives
        if actual > 0 then
            local qok, QuestMod = pcall(require, 'src.quest.quest')
            if qok and QuestMod.onResourceGathered then
                QuestMod.onResourceGathered(name, actual)
            end
        end
    end
end

function GameState.spendResource(name, amount)
    if GameState.resources[name] == nil then return false end
    if GameState.resources[name] < amount then return false end
    -- Debug: infinite resources mode skips deduction
    local dpOk, DP = pcall(require, 'src.ui.debug_panel')
    if dpOk and DP.infiniteRes then return true end
    GameState.resources[name] = GameState.resources[name] - amount
    return true
end

return GameState
