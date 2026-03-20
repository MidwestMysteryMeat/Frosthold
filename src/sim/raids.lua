-- raids.lua — Raid and swarm system
-- Orchestrates multi-wave attacks on the colony (creature and humanoid).
-- Three trigger types determine what attacks the colony:
--   activity: colony noise (mining, machines, drills, population) attracts eldritch swarms + creature raids
--   wealth:   stockpiled resources attract human faction raiders
--   heat:     thermal output draws thermovore swarms from underground
-- Swarms use inverted composition: 80% cheap bugs, 15-20% anchors. Ocean of enemies.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Creatures = require('src.creatures.creatures')
local Hope      = require('src.colony.hope')
local Tuning    = require('src.sim.tuning')

local Raids = {}

local function rtune(key, fallback)
    return Tuning.get('raids.' .. key, fallback)
end

---------------------------------------------------------------------------
-- Creature point costs (for budget-based composition)
---------------------------------------------------------------------------

-- Merge humanoid raider costs at load time
local raiderOk, Raiders = pcall(require, 'src.creatures.raiders')

local CREATURE_COST = {
    -- Small
    frost_hare      = 2,
    ice_fox         = 4,
    snow_grouse     = 1,
    -- Medium
    tundra_wolf     = 10,
    glacier_bear    = 20,
    ice_stalker     = 15,
    frost_beetle    = 3,
    ice_locust      = 4,
    frost_wurm      = 25,
    -- Lair species
    dire_wolf       = 18,
    ice_brute     = 35,
    snow_ape            = 30,
    stalker         = 40,
    sabertooth      = 22,
    mammoth         = 28,
    shade      = 25,
    -- Swarm species
    spawnling   = 8,
    skitterer         = 5,
    giant_rat       = 3,
    nerve_worm      = 2,
    nerve_tick      = 1,
    -- Megafauna
    frost_titan     = 80,
    thermal_wurm    = 70,
    glacial_leviathan = 120,
    ancient_brute   = 90,
    alpha_stalker   = 85,
    mountain_titan  = 100,
    ice_colossus    = 110,
    storm_titan     = 95,
    -- Thermovores
    cinder_mite     = 2,
    heat_skipper    = 1,
    char_hound      = 12,
    bore_beetle     = 22,
    razorjaw        = 18,
    spine_lurker    = 15,
    hive_matron     = 80,
    gorge_worm      = 90,
    iron_carapace   = 110,
    the_thermophage = 170,
    -- Eldritch
    the_hungering   = 150,
    the_pale_thing   = 160,
    that_which_sleeps  = 200,
    fleshwalker    = 140,
    -- Eldritch livestock (egg-based)
    gore_shoat      = 6,
    weeping_calf    = 6,
    husk_pup        = 7,
    void_minnow     = 12,
    pit_wyrm        = 10,
    -- Eldritch livestock (spore-based)
    bile_mold       = 5,
    thorn_polyp     = 7,
    nerve_cluster   = 10,
    rot_bloom       = 5,
}

-- Merge humanoid raider costs into creature cost table
if raiderOk and Raiders.COST then
    for id, cost in pairs(Raiders.COST) do
        CREATURE_COST[id] = cost
    end
end

---------------------------------------------------------------------------
-- Raid type definitions
---------------------------------------------------------------------------

local RAID_TYPES = {
    -- Standard creature assault: one direction, retreats at casualties
    beast_assault = {
        name        = 'Beast Assault',
        minDay      = 5,
        trigger     = 'activity',
        minActivity = 12,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.5,    -- flee when 50% killed
        waveDelay   = 0,
        pool        = { 'tundra_wolf', 'glacier_bear', 'ice_stalker' },
        budgetMult  = 1.0,
        hopeDelta   = -3,
        threatCost  = 25,
    },
    -- Siege: includes breachers that attack walls/doors
    siege = {
        name        = 'Creature Siege',
        minDay      = 12,
        trigger     = 'activity',
        minActivity = 35,
        waves       = 2,
        directions  = 1,
        retreatPct  = 0.6,
        waveDelay   = 30,
        pool        = { 'tundra_wolf', 'frost_wurm', 'ice_stalker' },
        budgetMult  = 1.3,
        hopeDelta   = -5,
        threatCost  = 40,
    },
    -- Coordinated raid: multiple directions, mixed composition
    coordinated = {
        name        = 'Coordinated Attack',
        minDay      = 20,
        trigger     = 'activity',
        minActivity = 60,
        waves       = 2,
        directions  = 2,
        retreatPct  = 0.5,
        waveDelay   = 20,
        pool        = { 'tundra_wolf', 'glacier_bear', 'ice_stalker', 'frost_wurm' },
        budgetMult  = 1.5,
        hopeDelta   = -6,
        threatCost  = 55,
    },
    -- ELDRITCH SWARMS (tiered): activity/noise-gated
    -- Colony noise (mining, machines, drills, population) attracts things from below
    -- Swarm probe: first taste, tiny eldritch crawlers
    swarm_probe = {
        name        = 'Swarm Probe',
        minDay      = 1,
        trigger     = 'activity',
        minActivity = 20,     -- a few colonists working
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.5,    -- scouts flee when thinned
        waveDelay   = 0,
        pool        = { 'nerve_tick', 'nerve_worm', 'skitterer' },
        budgetMult  = 0.8,
        hopeDelta   = -2,
        threatCost  = 15,
        swarm       = true,
    },
    -- Swarm wave: real swarm, eldritch + insectoid mix
    swarm_wave = {
        name        = 'Swarm Wave',
        minDay      = 1,
        trigger     = 'activity',
        minActivity = 50,     -- busy colony, machines running
        waves       = 2,
        directions  = 2,
        retreatPct  = 0,
        waveDelay   = 20,
        pool        = { 'nerve_tick', 'nerve_worm', 'frost_beetle', 'ice_locust',
                        'skitterer', 'spawnling' },
        budgetMult  = 1.5,
        hopeDelta   = -5,
        threatCost  = 45,
        swarm       = true,
    },
    -- The Swarm: ocean of enemies, few large anchors in a flood of small
    swarm = {
        name        = 'The Swarm',
        minDay      = 30,
        trigger     = 'activity',
        minActivity = 90,     -- large colony, drills, conveyors, production
        waves       = 3,
        directions  = 4,
        retreatPct  = 0,
        waveDelay   = 25,
        pool        = { 'nerve_tick', 'nerve_worm', 'frost_beetle', 'ice_locust',
                        'skitterer', 'spawnling', 'stalker', 'frost_wurm' },
        budgetMult  = 3.0,
        hopeDelta   = -10,
        threatCost  = 100,
        swarm       = true,
    },
    -- Swarm tide: endgame, overwhelming, large anchors in a sea of small
    swarm_tide = {
        name        = 'The Tide',
        minDay      = 45,
        trigger     = 'activity',
        minActivity = 130,    -- industrial-scale colony
        waves       = 5,
        directions  = 4,
        retreatPct  = 0,
        waveDelay   = 20,
        pool        = { 'nerve_tick', 'nerve_worm', 'frost_beetle', 'ice_locust',
                        'skitterer', 'spawnling', 'stalker', 'frost_wurm',
                        'ice_brute', 'fleshwalker' },
        budgetMult  = 5.0,
        hopeDelta   = -15,
        threatCost  = 150,
        swarm       = true,
    },

    -- THERMOVORE SWARMS (tiered): pure heat-attracted
    -- Colony thermal output draws them from underground
    thermovore_probe = {
        name        = 'Thermovore Scouts',
        minDay      = 1,
        trigger     = 'heat',
        minHeat     = 35,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.5,
        waveDelay   = 0,
        pool        = { 'cinder_mite', 'heat_skipper' },
        budgetMult  = 0.6,
        hopeDelta   = -2,
        threatCost  = 12,
        swarm       = true,
    },
    -- Thermovore emergence: real underground swarm
    thermovore_swarm = {
        name        = 'Thermovore Emergence',
        minDay      = 1,
        trigger     = 'heat',
        minHeat     = 65,
        waves       = 2,
        directions  = 2,
        retreatPct  = 0,
        waveDelay   = 15,
        pool        = { 'cinder_mite', 'heat_skipper', 'char_hound', 'bore_beetle' },
        budgetMult  = 1.5,
        hopeDelta   = -5,
        threatCost  = 40,
        swarm       = true,
    },
    -- Thermovore tide: massive underground eruption
    thermovore_tide = {
        name        = 'Thermovore Tide',
        minDay      = 1,
        trigger     = 'heat',
        minHeat     = 100,
        waves       = 4,
        directions  = 4,
        retreatPct  = 0,
        waveDelay   = 18,
        pool        = { 'cinder_mite', 'heat_skipper', 'char_hound', 'bore_beetle',
                        'razorjaw', 'spine_lurker', 'gorge_worm' },
        budgetMult  = 4.0,
        hopeDelta   = -12,
        threatCost  = 120,
        swarm       = true,
    },

    -- Outlaw raid: bandits, early-game humanoid threat
    outlaw_raid = {
        name        = 'Outlaw Raid',
        minDay      = 8,
        trigger     = 'wealth',
        minWealth   = 800,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.5,
        waveDelay   = 0,
        pool        = { 'outlaw_thug', 'outlaw_brawler', 'outlaw_gunner', 'outlaw_marksman' },
        budgetMult  = 1.0,
        hopeDelta   = -3,
        threatCost  = 20,
        humanoid    = true,
        -- outlaws are unaffiliated, no factionId
    },
    -- Faction raid: corporate or scavenger forces, mid-game
    faction_raid = {
        name        = 'Faction Raid',
        minDay      = 15,
        trigger     = 'wealth',
        minWealth   = 3000,
        waves       = 2,
        directions  = 1,
        retreatPct  = 0.5,
        waveDelay   = 20,
        pool        = { 'scav_militia', 'scav_scrapper', 'scav_sharpshooter',
                        'mammona_enforcer', 'mammona_heavy' },
        budgetMult  = 1.3,
        hopeDelta   = -5,
        threatCost  = 35,
        humanoid    = true,
        factionId   = 'scavenger_crews',  -- fallback; startRaid picks hostile faction dynamically
    },
    -- MasTema strike: elite corporate black ops, late-mid game
    -- Won't raid colonies with good Mammona rep (MasTema is Mammona's subsidiary)
    mastema_strike = {
        name        = 'MasTema Strike',
        minDay      = 25,
        trigger     = 'wealth',
        minWealth   = 8000,
        waves       = 2,
        directions  = 2,
        retreatPct  = 0.6,
        waveDelay   = 15,
        pool        = { 'mastema_operative', 'mastema_sniper', 'mastema_breacher' },
        budgetMult  = 1.5,
        hopeDelta   = -7,
        threatCost  = 50,
        humanoid    = true,
        factionId   = 'mastema_ops',
        allegiance  = 'mammona_logistics',  -- blocked if player is aligned with Mammona
    },
    -- Precursor incursion: ancient survivors, late-game
    precursor_incursion = {
        name        = 'Precursor Incursion',
        minDay      = 40,
        trigger     = 'wealth',
        minWealth   = 20000,
        waves       = 2,
        directions  = 2,
        retreatPct  = 0.4,
        waveDelay   = 25,
        pool        = { 'precursor_scout', 'precursor_warrior', 'precursor_sage' },
        budgetMult  = 2.0,
        hopeDelta   = -8,
        threatCost  = 70,
        humanoid    = true,
    },
    -- Drop pods: enemies land inside base, bypass walls
    -- MasTema corporate ops — won't attack Mammona-aligned colonies
    drop_pod = {
        name        = 'Drop Pod Assault',
        minDay      = 25,
        trigger     = 'wealth',
        minWealth   = 12000,
        waves       = 1,
        directions  = 0,     -- spawn inside base, not from edges
        retreatPct  = 0.4,
        waveDelay   = 0,
        pool        = { 'mammona_enforcer', 'mastema_operative', 'mastema_breacher' },
        budgetMult  = 1.2,
        hopeDelta   = -6,
        threatCost  = 45,
        humanoid    = true,
        spawnMode   = 'interior',  -- spawn near colony center
        factionId   = 'mastema_ops',
        allegiance  = 'mammona_logistics',
    },
    -- Sappers: dig through walls, target weakest wall section
    sapper = {
        name        = 'Sapper Raid',
        minDay      = 18,
        trigger     = 'wealth',
        minWealth   = 4000,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.5,
        waveDelay   = 0,
        pool        = { 'outlaw_thug', 'outlaw_brawler', 'scav_scrapper', 'frost_wurm' },
        budgetMult  = 1.3,
        hopeDelta   = -5,
        threatCost  = 35,
        tactic      = 'sapper',  -- AI targets walls instead of doors
    },
    -- Siege: set up camp outside, bombard with mortars, must sortie
    -- Mammona corporate siege — won't attack Mammona-aligned colonies
    siege_camp = {
        name        = 'Siege',
        minDay      = 30,
        trigger     = 'wealth',
        minWealth   = 15000,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.5,
        waveDelay   = 0,
        pool        = { 'scav_militia', 'mammona_enforcer', 'mammona_heavy', 'mastema_operative' },
        budgetMult  = 1.5,
        hopeDelta   = -7,
        threatCost  = 60,
        humanoid    = true,
        tactic      = 'siege',   -- AI stays at range, fires projectiles
        factionId   = 'mammona_logistics',
        allegiance  = 'mammona_logistics',
    },
    -- Infiltrators: disguised as visitors, attack from within at night
    infiltration = {
        name        = 'Infiltration',
        minDay      = 22,
        trigger     = 'wealth',
        minWealth   = 7000,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.3,
        waveDelay   = 0,
        pool        = { 'mastema_operative', 'mastema_sniper' },
        budgetMult  = 0.8,       -- fewer but deadlier
        hopeDelta   = -8,
        threatCost  = 40,
        humanoid    = true,
        tactic      = 'infiltrate',  -- disguised entry, delayed hostility
        factionId   = 'mastema_ops',
        allegiance  = 'mammona_logistics',
    },

    -- Black Maw pirate raid: aggressive, mid-game
    pirate_raid = {
        name        = 'Pirate Raid',
        minDay      = 12,
        trigger     = 'wealth',
        minWealth   = 800,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.4,
        waveDelay   = 0,
        pool        = { 'maw_raider', 'maw_breacher', 'maw_heavy' },
        budgetMult  = 1.2,
        hopeDelta   = -4,
        threatCost  = 30,
        humanoid    = true,
        factionId   = 'black_maw',
    },
    -- Void Serpent infiltration: small, sneaky, sabotage-focused
    serpent_infiltration = {
        name        = 'Serpent Infiltration',
        minDay      = 20,
        trigger     = 'wealth',
        minWealth   = 3000,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.3,
        waveDelay   = 0,
        pool        = { 'serpent_infiltrator', 'serpent_saboteur' },
        budgetMult  = 0.9,
        hopeDelta   = -5,
        threatCost  = 35,
        humanoid    = true,
        tactic      = 'infiltrate',
        factionId   = 'void_serpents',
    },
    -- Rust Reaver strip raid: they want your materials
    reaver_strip = {
        name        = 'Reaver Strip Raid',
        minDay      = 14,
        trigger     = 'wealth',
        minWealth   = 1000,
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.5,
        waveDelay   = 0,
        pool        = { 'reaver_scrapper', 'reaver_welder' },
        budgetMult  = 1.1,
        hopeDelta   = -3,
        threatCost  = 25,
        humanoid    = true,
        factionId   = 'rust_reavers',
    },
    -- Zenith Syndicate shakedown: well-equipped organized crime
    syndicate_shakedown = {
        name        = 'Syndicate Shakedown',
        minDay      = 18,
        trigger     = 'wealth',
        minWealth   = 2500,
        waves       = 2,
        directions  = 1,
        retreatPct  = 0.5,
        waveDelay   = 20,
        pool        = { 'zenith_thug', 'zenith_gunner', 'zenith_enforcer' },
        budgetMult  = 1.4,
        hopeDelta   = -5,
        threatCost  = 40,
        humanoid    = true,
        factionId   = 'zenith_syndicate',
    },
    -- Pale Moon crusade: cult zealots triggered by deep drilling and downward progression
    pale_moon_crusade = {
        name        = 'Pale Moon Crusade',
        minDay      = 22,
        trigger     = 'depth',   -- triggered by drilling/precursor/anomaly activity
        waves       = 2,
        directions  = 2,
        retreatPct  = 0.3,     -- fanatics don't flee easy
        waveDelay   = 15,
        pool        = { 'pale_moon_zealot', 'pale_moon_priest' },
        budgetMult  = 1.3,
        hopeDelta   = -6,
        threatCost  = 45,
        humanoid    = true,
        factionId   = 'sons_of_pale_moon',
    },
    erebus_reclamation = {
        name        = 'Erebus Reclamation',
        minDay      = 12,
        trigger     = 'containment',
        minContainment = 18,
        waves       = 2,
        directions  = 2,
        retreatPct  = 0.25,
        waveDelay   = 18,
        pool        = { 'erebus_latent', 'erebus_thrall', 'erebus_vessel', 'erebus_herald' },
        budgetMult  = 1.25,
        hopeDelta   = -7,
        threatCost  = 48,
        humanoid    = true,
    },

    -- Quota enforcement: Mammona corporate punishment for missed quotas on Paxtera Prime
    -- Triggered programmatically by quotas.lua, not by the normal storyteller cycle
    quota_enforcement = {
        name        = 'Quota Enforcement',
        minDay      = 1,
        trigger     = 'manual',     -- not picked by pickRaidType; fired by quotas.lua
        waves       = 1,
        directions  = 1,
        retreatPct  = 0.5,
        waveDelay   = 0,
        pool        = { 'mammona_enforcer', 'mammona_heavy', 'mastema_operative' },
        budgetMult  = 1.0,
        hopeDelta   = -6,
        threatCost  = 30,
        humanoid    = true,
        factionId   = 'mammona_logistics',
    },
}

Raids.RAID_TYPES = RAID_TYPES

---------------------------------------------------------------------------
-- Module state
---------------------------------------------------------------------------

local activeRaid = nil
-- {
--   type, typeDef, budget, factionId,
--   waves = { { creatures = {id,...}, spawned = bool, spawnTime } },
--   currentWave, startTime, warningTime,
--   phase = 'warning' | 'active' | 'aftermath',
--   spawnPoints = { {x,y}, ... },
--   raidCreatures = { [entityId] = true },
--   totalSpawned, totalKilled,
-- }

local raidLog = {}
local MAX_LOG = 10
local raidsSurvived = 0

local function logRaid(msg)
    raidLog[#raidLog + 1] = {
        msg  = msg,
        day  = GameState.day,
        hour = GameState.hour,
    }
    while #raidLog > MAX_LOG do
        table.remove(raidLog, 1)
    end
end

---------------------------------------------------------------------------
-- Heat signature: colony warmth attracts predators
-- More heat sources + higher temps = bigger threat multiplier
---------------------------------------------------------------------------

local function getHeatSignature()
    local sig = 0
    -- Count active heat sources (heaters, campfires, steam hubs)
    local genOk, Generator = pcall(require, 'src.sim.generator')
    if genOk and Generator.getHubs then
        local hubList = Generator.getHubs()
        for _, hub in ipairs(hubList) do
            if hub.active then sig = sig + 10 end
        end
    end
    -- Each living colonist adds warmth presence
    local livingCount = 0
    for cid, ccomps in ECS.query('colonist') do
        if ccomps.colonist.state ~= 'dead' then
            livingCount = livingCount + 1
        end
    end
    sig = sig + livingCount * 3
    -- Resources indicate a juicy target
    sig = sig + (GameState.resources.thermalCores or 0) * 0.5
    -- Blackout protocol reduces heat signature
    local polOk, Policies = pcall(require, 'src.colony.policies')
    if polOk and Policies.getHeatSignatureMult then
        sig = sig * Policies.getHeatSignatureMult()
    end
    -- Signal jammer exclusive reward: -30% heat signature
    if GameState.exclusiveBuffs and GameState.exclusiveBuffs.signal_jammer then
        sig = sig * 0.7
    end
    return sig
end

Raids.getHeatSignature = getHeatSignature

---------------------------------------------------------------------------
-- Activity level: colony noise attracts eldritch swarms
-- Mining, drilling, machines, colonists working = ground vibration
---------------------------------------------------------------------------

local function getActivityLevel()
    local activity = 0

    -- Living colonists contribute baseline noise
    local working = 0
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' then
            activity = activity + 1
            -- Colonists with active tasks generate more noise
            if comps.colonist.task then working = working + 1 end
        end
    end
    activity = activity + working * 2

    -- Active production machines
    for _, comps in ECS.query('machine') do
        if comps.machine and comps.machine.active then
            activity = activity + 3
        end
    end

    -- Deep drills are very noisy
    for _, comps in ECS.query('deep_drill') do
        if comps.deep_drill and comps.deep_drill.active then
            activity = activity + 8
        end
    end

    -- Building count (more infrastructure = more ground disturbance)
    local bok, BuildingMod = pcall(require, 'src.building.building')
    if bok and BuildingMod.getAll then
        local count = 0
        for _ in pairs(BuildingMod.getAll()) do count = count + 1 end
        activity = activity + math.floor(count * 0.5)
    end

    -- Conveyor belts running = vibration
    local cok, Conveyors = pcall(require, 'src.logistics.conveyors')
    if cok and Conveyors.getBeltCount then
        activity = activity + math.floor((Conveyors.getBeltCount() or 0) * 0.3)
    end

    return activity
end

Raids.getActivityLevel = getActivityLevel

---------------------------------------------------------------------------
-- Depth progression: deep drilling and precursor activity
-- Sons of the Pale Moon care about what you're disturbing below
---------------------------------------------------------------------------

local function getDepthProgression()
    local score = 0

    -- Active deep drills contribute heavily
    for _, comps in ECS.query('deep_drill') do
        if comps.deep_drill and comps.deep_drill.active then
            score = score + 15
        else
            score = score + 5   -- even idle drills show intent
        end
    end

    -- Explored depth layers (capped at +50 to prevent deep-dig raid spiral)
    local tok, World = pcall(require, 'src.world.tilemap')
    if tok and World.getMaxDepth then
        local maxDepth = World.getMaxDepth() or 0
        score = score + math.min(maxDepth * 10, 50)
    end

    -- Precursor research completed
    local rok, Research = pcall(require, 'src.research.research')
    if rok and Research.isCompleted then
        if Research.isCompleted('exotic_fluids') then score = score + 10 end
        if Research.isCompleted('precursor_studies') then score = score + 15 end
        if Research.isCompleted('deep_mining') then score = score + 10 end
    end

    -- Eldritch nodes discovered
    local nok, Nodes = pcall(require, 'src.creatures.eldritch_nodes')
    if nok and Nodes.getDiscoveredCount then
        score = score + (Nodes.getDiscoveredCount() or 0) * 8
    end

    return score
end

Raids.getDepthProgression = getDepthProgression

local function getContainmentPressure()
    local cok, Containment = pcall(require, 'src.sim.containment')
    if not cok or not Containment.getSubjectInterest then return 0 end
    return Containment.getSubjectInterest() or 0
end

Raids.getContainmentPressure = getContainmentPressure

---------------------------------------------------------------------------
-- Raid budget calculation
---------------------------------------------------------------------------

local function getRaidBudget(typeDef)
    local base = rtune('budget_base', 30)
        + GameState.day * rtune('budget_per_day', 2)
        + raidsSurvived * rtune('budget_per_raid_survived', 5)
    local heatMult = 1 + getHeatSignature() / math.max(1, rtune('heat_signature_divisor', 100))
    local aggression = GameState.creatureAggression or 1.0
    -- Elastic difficulty: scale raid budget by aggression modifier
    local eOk, Elastic = pcall(require, 'src.sim.elastic_difficulty')
    local elasticMod = (eOk and Elastic.getAggressionMod()) or 1.0
    -- Seasonal raid multiplier (thaw = more raids, deep winter = fewer)
    local seasonMult = 1.0
    local sok, Seasons = pcall(require, 'src.world.seasons')
    if sok then seasonMult = Seasons.getRaidMult() end
    return math.floor(base * typeDef.budgetMult * heatMult * aggression * elasticMod * seasonMult)
end

---------------------------------------------------------------------------
-- Spawn point selection
---------------------------------------------------------------------------

local function pickSpawnPoints(count)
    local World = require('src.world.tilemap')
    local w, h = World.width(), World.height()
    local sides = { 1, 2, 3, 4 }
    -- Shuffle
    for i = #sides, 2, -1 do
        local j = math.random(i)
        sides[i], sides[j] = sides[j], sides[i]
    end

    local points = {}
    for i = 1, math.min(count, 4) do
        local side = sides[i]
        local x, y
        if side == 1 then     x = math.random(5, w - 5); y = 3
        elseif side == 2 then x = math.random(5, w - 5); y = h - 4
        elseif side == 3 then x = 3;                      y = math.random(5, h - 5)
        else                  x = w - 4;                   y = math.random(5, h - 5)
        end
        -- Find walkable tile nearby
        if not World.isWalkable(x, y, 0) then
            for dx = -3, 3 do
                for dy = -3, 3 do
                    if World.inBounds(x + dx, y + dy) and World.isWalkable(x + dx, y + dy, 0) then
                        x, y = x + dx, y + dy
                        goto found
                    end
                end
            end
            ::found::
        end
        local SIDE_NAMES = { 'north', 'south', 'west', 'east' }
        points[#points + 1] = { x = x, y = y, side = SIDE_NAMES[side] }
    end
    return points
end

---------------------------------------------------------------------------
-- Interior spawn points (for drop pod raids: spawn near colonists)
---------------------------------------------------------------------------

local function pickInteriorSpawnPoints()
    local World = require('src.world.tilemap')
    local points = {}
    -- Find colonist center of mass
    local sumX, sumY, count = 0, 0, 0
    for _, comps in ECS.query('colonist', 'pos') do
        if comps.colonist.state ~= 'dead' then
            sumX = sumX + comps.pos.x
            sumY = sumY + comps.pos.y
            count = count + 1
        end
    end
    if count == 0 then return pickSpawnPoints(1) end -- fallback

    local cx = math.floor(sumX / count)
    local cy = math.floor(sumY / count)

    -- Find 2-3 walkable tiles within 10-20 tiles of colony center
    local candidates = {}
    for dx = -20, 20, 3 do
        for dy = -20, 20, 3 do
            local x, y = cx + dx, cy + dy
            local d = math.abs(dx) + math.abs(dy)
            if d >= 10 and d <= 25 and World.inBounds(x, y) and World.isWalkable(x, y, 0) then
                candidates[#candidates + 1] = { x = x, y = y, side = 'interior' }
            end
        end
    end

    -- Pick 2-3 random from candidates
    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end
    for i = 1, math.min(3, #candidates) do
        points[#points + 1] = candidates[i]
    end

    if #points == 0 then return pickSpawnPoints(1) end
    return points
end

---------------------------------------------------------------------------
-- Build wave composition from budget and pool
---------------------------------------------------------------------------

local function buildWaveComposition(budget, pool, isSwarm)
    local composition = {}
    local remaining = budget

    -- Sort pool by cost
    local sorted = {}
    for _, sp in ipairs(pool) do
        sorted[#sorted + 1] = { species = sp, cost = CREATURE_COST[sp] or 10 }
    end

    if isSwarm then
        -- SWARM: mostly cheap, few big anchors
        -- Split pool into cheap (bottom 60% by cost) and anchors (top 40%)
        table.sort(sorted, function(a, b) return a.cost < b.cost end)
        local splitIdx = math.max(1, math.ceil(#sorted * 0.6))
        local cheap = {}
        local anchors = {}
        for i, entry in ipairs(sorted) do
            if i <= splitIdx then
                cheap[#cheap + 1] = entry
            else
                anchors[#anchors + 1] = entry
            end
        end

        -- Spend 15-20% of budget on anchors (if any exist)
        if #anchors > 0 then
            local anchorBudget = math.floor(remaining * (0.15 + math.random() * 0.05))
            local anchorRemaining = anchorBudget
            for _, entry in ipairs(anchors) do
                while anchorRemaining >= entry.cost do
                    composition[#composition + 1] = entry.species
                    anchorRemaining = anchorRemaining - entry.cost
                    remaining = remaining - entry.cost
                end
            end
        end

        -- Fill the rest with cheap creatures (random picks for variety)
        while remaining > 0 do
            -- Collect all affordable cheap species
            local affordable = {}
            for _, entry in ipairs(cheap) do
                if remaining >= entry.cost then
                    affordable[#affordable + 1] = entry
                end
            end
            if #affordable == 0 then break end
            -- Pick one at random
            local pick = affordable[math.random(#affordable)]
            composition[#composition + 1] = pick.species
            remaining = remaining - pick.cost
        end
    else
        -- Standard raids: fill with expensive first, then pad with cheap
        table.sort(sorted, function(a, b) return a.cost > b.cost end)
        for _, entry in ipairs(sorted) do
            while remaining >= entry.cost do
                composition[#composition + 1] = entry.species
                remaining = remaining - entry.cost
            end
        end
    end

    -- Shuffle composition so anchors aren't all at the front
    for i = #composition, 2, -1 do
        local j = math.random(i)
        composition[i], composition[j] = composition[j], composition[i]
    end

    return composition
end

---------------------------------------------------------------------------
-- Warning time scales with infrastructure (watchtowers = longer warning)
---------------------------------------------------------------------------

local function getWarningDuration(typeDef)
    local base = rtune('warning_base', 15)
    -- Swarms get longer warning (2 game-days = ~120 real seconds at 1x)
    if typeDef.retreatPct == 0 then
        base = rtune('warning_swarm', 120)
    end
    return base
end

---------------------------------------------------------------------------
-- Start a raid
---------------------------------------------------------------------------

function Raids.startRaid(raidType)
    -- Debug: suppress raids when noRaids is active
    local dpOk, DP = pcall(require, 'src.ui.debug_panel')
    if dpOk and DP.noRaids then return nil, 'Raids suppressed (debug)' end
    if activeRaid then return nil, 'A raid is already in progress' end

    local typeDef = RAID_TYPES[raidType]
    if not typeDef then return nil, 'Unknown raid type' end
    if GameState.day < typeDef.minDay then return nil, 'Too early for this raid type' end

    local budget = getRaidBudget(typeDef)
    local spawnPoints
    if typeDef.spawnMode == 'interior' then
        spawnPoints = pickInteriorSpawnPoints()
    else
        spawnPoints = pickSpawnPoints(typeDef.directions)
    end
    local warningDur = getWarningDuration(typeDef)

    -- Build waves
    local waves = {}
    local waveBudget = math.floor(budget / typeDef.waves)
    for w = 1, typeDef.waves do
        -- Each successive wave gets bigger
        -- Swarms escalate 25% per wave (ocean effect), normal raids 10%
        local escalation = typeDef.swarm and 0.25 or 0.10
        local wb = math.floor(waveBudget * (1 + (w - 1) * escalation))
        waves[w] = {
            composition = buildWaveComposition(wb, typeDef.pool, typeDef.swarm),
            spawned     = false,
            spawnTime   = warningDur + (w - 1) * typeDef.waveDelay,
            creatures   = {},
        }
    end

    -- Determine faction sourcing this raid
    local raidFactionId = typeDef.factionId
    if raidType == 'faction_raid' then
        local ffok, FactionsMod = pcall(require, 'src.colony.factions')
        if ffok and FactionsMod.pickHostileFaction then
            raidFactionId = FactionsMod.pickHostileFaction() or raidFactionId
        end
    end

    activeRaid = {
        type          = raidType,
        typeDef       = typeDef,
        budget        = budget,
        waves         = waves,
        currentWave   = 1,
        startTime     = 0,
        warningTime   = warningDur,
        phase         = 'warning',
        spawnPoints   = spawnPoints,
        raidCreatures = {},
        totalSpawned  = 0,
        totalKilled   = 0,
        factionId     = raidFactionId,
    }

    Hope.applyDelta(typeDef.hopeDelta, 5)

    local dirList = {}
    for _, pt in ipairs(spawnPoints) do
        dirList[#dirList + 1] = pt.side or 'unknown'
    end
    local dirStr = table.concat(dirList, ' and ')

    if raidType == 'swarm' then
        logRaid('Swarm inbound. All four directions. Brace for contact.')
    else
        logRaid(typeDef.name .. ' incoming from the ' .. dirStr .. '!')
    end

    -- Alert sound and screen shake
    local sok, Sound = pcall(require, 'src.audio.sound')
    if sok then Sound.play('alert') end
    local cok, Camera = pcall(require, 'src.render.camera')
    if cok and Camera.shake then
        Camera.shake(raidType == 'swarm' and 12 or 6)
    end

    -- Auto-pause on raid
    if GameState.autoPause and GameState.autoPause.onRaid then
        GameState.paused = true
    end

    -- Allied faction reinforcements: spawn friendly tundra wolves near colony
    local fok, FactionsMod = pcall(require, 'src.colony.factions')
    if fok and FactionsMod.getAlliedReinforcements then
        local allyCount = FactionsMod.getAlliedReinforcements()
        if allyCount > 0 then
            local crok, CreaturesMod = pcall(require, 'src.creatures.creatures')
            if crok and CreaturesMod.spawn then
                local sx, sy = GameState.startX, GameState.startY
                local spawned = 0
                for i = 1, math.min(allyCount * 2, 6) do
                    local rx = sx + math.random(-4, 4)
                    local ry = sy + math.random(-4, 4)
                    local aid = CreaturesMod.spawn('tundra_wolf', rx, ry)
                    if aid then
                        local cr = ECS.get(aid, 'creature')
                        if cr then
                            cr.hostile = false
                            cr.name = 'Allied War Beast'
                            cr._reinforcement = true
                        end
                        spawned = spawned + 1
                    end
                end
                if spawned > 0 then
                    logRaid('Allied faction sent ' .. spawned .. ' war beasts to help defend!')
                end
            end
        end
    end

    return activeRaid
end

---------------------------------------------------------------------------
-- Spawn a wave's creatures
---------------------------------------------------------------------------

local function spawnWave(wave, spawnPoints, typeDef)
    local World = require('src.world.tilemap')
    local creatures = wave.composition
    local pointIdx = 1

    for _, speciesId in ipairs(creatures) do
        local sp = spawnPoints[pointIdx]
        pointIdx = (pointIdx % #spawnPoints) + 1

        -- Scatter around spawn point
        local sx = sp.x + math.random(-3, 3)
        local sy = sp.y + math.random(-3, 3)
        if World.inBounds(sx, sy) and World.isWalkable(sx, sy, 0) then
            local id = Creatures.spawn(speciesId, sx, sy, 0)
            if id then
                -- Override leash so raid creatures don't wander home
                local cr = ECS.get(id, 'creature')
                if cr then
                    cr.leashRange = 999
                    cr.aggroRange = 25
                end
                -- Tag as raid creature (include faction for prisoner capture)
                ECS.set(id, 'raid_tag', { raidType = typeDef.name, factionId = activeRaid.factionId })
                wave.creatures[#wave.creatures + 1] = id
                activeRaid.raidCreatures[id] = true
                activeRaid.totalSpawned = activeRaid.totalSpawned + 1
            end
        end
    end

    -- Inject nemesis leader for humanoid raids (first wave only)
    if typeDef.humanoid and wave == activeRaid.waves[1] then
        local nok, NemesisMod = pcall(require, 'src.sim.nemesis')
        if nok then
            local nemCaptain = NemesisMod.getRaidNemesis(GameState.planet)
            if nemCaptain then
                if #wave.creatures > 0 then
                    local nemId = wave.creatures[1]
                    local cr = ECS.get(nemId, 'creature')
                    if cr then
                        cr.maxHp  = math.floor((cr.maxHp  or 100) * nemCaptain.hpMult)
                        cr.hp     = cr.maxHp
                        cr.damage = math.floor((cr.damage or 10)  * nemCaptain.dmgMult)
                        cr.name   = nemCaptain.name
                        cr.title  = nemCaptain.title
                        cr.isNemesis   = true
                        cr.nemesisData = nemCaptain
                    end
                    NemesisMod.announceNemesis(nemCaptain)
                end
            end
        end
    end

    -- Inject rival leaders for humanoid raids (first wave only)
    if typeDef.humanoid and wave == activeRaid.waves[1] then
        local rok, RivalsMod = pcall(require, 'src.sim.rivals')
        if rok then
            local rivalIds = RivalsMod.onRaidSpawn(activeRaid.type, spawnPoints)
            for _, rid in ipairs(rivalIds) do
                ECS.set(rid, 'raid_tag', { raidType = activeRaid.type, factionId = activeRaid.factionId })
                wave.creatures[#wave.creatures + 1] = rid
                activeRaid.raidCreatures[rid] = true
                activeRaid.totalSpawned = activeRaid.totalSpawned + 1
            end
        end
    end
end

---------------------------------------------------------------------------
-- Check retreat conditions
---------------------------------------------------------------------------

local function countRaidAlive()
    local alive = 0
    for id in pairs(activeRaid.raidCreatures) do
        if ECS.isAlive(id) then
            alive = alive + 1
        end
    end
    return alive
end

local function triggerRetreat()
    -- Make all remaining raid creatures flee toward map edge
    local World = require('src.world.tilemap')
    local w, h = World.width(), World.height()
    local rok, RivalsMod = pcall(require, 'src.sim.rivals')
    for id in pairs(activeRaid.raidCreatures) do
        if ECS.isAlive(id) then
            local cr = ECS.get(id, 'creature')
            if cr then
                cr.state = 'flee'
                cr.fleeRange = 999
                cr.hostile = false
                -- Set home to nearest edge so leash pulls them off map
                local pos = ECS.get(id, 'pos')
                if pos then
                    if pos.x < w / 2 then pos.homeX = 0 else pos.homeX = w - 1 end
                    if pos.y < h / 2 then pos.homeY = 0 else pos.homeY = h - 1 end
                end
                -- Notify rival system of escape
                if rok and ECS.get(id, 'rival') then
                    RivalsMod.onRivalEscape(id)
                end
            end
        end
    end
    logRaid('The attackers are retreating!')
end

---------------------------------------------------------------------------
-- End raid
---------------------------------------------------------------------------

local function endRaid(victory)
    if not activeRaid then return end

    -- Clean up dead tags
    for id in pairs(activeRaid.raidCreatures) do
        if ECS.isAlive(id) then
            ECS.remove(id, 'raid_tag')
        end
    end

    if victory then
        raidsSurvived = raidsSurvived + 1
        GameState.raidsSurvived = raidsSurvived
        -- Scar trait: raid survived for all living colonists
        local scarOk, ScarTraits = pcall(require, 'src.colonist.scar_traits')
        if scarOk then
            for id, comps in ECS.query('colonist') do
                if comps.colonist.state ~= 'dead' then
                    ScarTraits.onRaidSurvived(id)
                end
            end
        end
        Hope.applyDelta(5, -3)
        logRaid('Raid repelled. Defenses hold.')

        -- Notify quest system
        local qok, QuestMod = pcall(require, 'src.quest.quest')
        if qok and QuestMod.onRaidSurvived then QuestMod.onRaidSurvived() end
    else
        logRaid('Raid ended. Colony took heavy losses.')

        -- Failed raids may disrupt an active trade route
        local trOk, TR = pcall(require, 'src.trade.trade_routes')
        if trOk then
            local activeRoutes = TR.getRoutes()
            if #activeRoutes > 0 then
                local target = activeRoutes[math.random(#activeRoutes)]
                TR.disrupt(target.factionId, 3)
            end
        end
    end

    activeRaid = nil
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Raids.step(dt)
    -- Tick raid delay from interrogation intel
    Raids.tickDelay(dt)

    if not activeRaid then return end

    activeRaid.startTime = activeRaid.startTime + dt

    -- Warning phase
    if activeRaid.phase == 'warning' then
        if activeRaid.startTime >= activeRaid.warningTime then
            activeRaid.phase = 'active'
        end
        return
    end

    -- Active phase: spawn waves on schedule
    if activeRaid.phase == 'active' then
        for i, wave in ipairs(activeRaid.waves) do
            if not wave.spawned and activeRaid.startTime >= wave.spawnTime then
                wave.spawned = true
                activeRaid.currentWave = i
                spawnWave(wave, activeRaid.spawnPoints, activeRaid.typeDef)
                if i > 1 then
                    logRaid('Wave ' .. i .. ' arrives!')
                end
            end
        end

        -- Count killed raid creatures. Most deaths are accounted through the
        -- death hook, but keep a fallback scan for any stale dead entries.
        local killed = activeRaid.totalKilled or 0
        for id in pairs(activeRaid.raidCreatures) do
            if not ECS.isAlive(id) then
                killed = killed + 1
                activeRaid.raidCreatures[id] = nil
            end
        end
        activeRaid.totalKilled = killed

        -- Check if all waves spawned
        local allSpawned = true
        for _, wave in ipairs(activeRaid.waves) do
            if not wave.spawned then allSpawned = false; break end
        end

        -- Retreat check — only after all waves have spawned to prevent premature retreat
        if allSpawned and activeRaid.totalSpawned > 0 and activeRaid.typeDef.retreatPct > 0 then
            local killRatio = killed / math.max(1, activeRaid.totalSpawned)
            if killRatio >= activeRaid.typeDef.retreatPct then
                triggerRetreat()
                activeRaid.phase = 'aftermath'
                return
            end
        end

        if allSpawned then
            local alive = countRaidAlive()

            -- All dead = victory
            if alive == 0 then
                endRaid(true)
                return
            end
        end

        -- Timeout: if raid lasts longer than 5 minutes real time, force end
        if activeRaid.startTime > activeRaid.warningTime + rtune('timeout_after_warning', 300) then
            local alive = countRaidAlive()
            if alive == 0 then
                endRaid(true)
            else
                triggerRetreat()
                activeRaid.phase = 'aftermath'
            end
        end
    end

    -- Aftermath: wait for retreating creatures to despawn
    if activeRaid.phase == 'aftermath' then
        local alive = countRaidAlive()
        if alive == 0 then
            endRaid(true)
        end
    end
end

---------------------------------------------------------------------------
-- Creature death hook — called when any creature dies
---------------------------------------------------------------------------

function Raids.onCreatureDeath(entityId)
    if not activeRaid then return end
    if activeRaid.raidCreatures[entityId] then
        activeRaid.totalKilled = (activeRaid.totalKilled or 0) + 1
        -- Faction rep hit for killing their raiders
        if activeRaid.factionId then
            local ffok, FactionsMod = pcall(require, 'src.colony.factions')
            if ffok then FactionsMod.onFactionCreatureKilled(activeRaid.factionId) end
        end
        -- Check for prisoner capture opportunity
        local rok, Recruitment = pcall(require, 'src.colonist.recruitment')
        if rok and Recruitment.tryCapture then
            Recruitment.tryCapture(entityId)
        end
        -- Nemesis revenge announcement
        local cr = ECS.get(entityId, 'creature')
        if cr and cr.isNemesis and cr.nemesisData then
            local nok, NemesisMod = pcall(require, 'src.sim.nemesis')
            if nok then
                NemesisMod.announceRevenge(cr.nemesisData)
            end
        end
        -- Prune dead creature from raidCreatures to avoid O(N) scans on dead entries
        activeRaid.raidCreatures[entityId] = nil
    end
end

---------------------------------------------------------------------------
-- Pick raid type based on trigger type:
--   activity: eldritch swarms + creature raids (noise/machines/colonists)
--   wealth:   human faction raids (stockpiles attract raiders)
--   heat:     thermovore swarms (thermal output draws them up)
---------------------------------------------------------------------------

local function isEligible(def, day, activity, wealth, heat, depth, containment)
    if day < def.minDay then return false end

    -- Allegiance check: raids blocked if player is aligned with the faction's
    -- corporate group (e.g. good Mammona rep also blocks MasTema raids)
    if def.allegiance then
        local afok, FactionsMod = pcall(require, 'src.colony.factions')
        if afok and FactionsMod.isGroupAligned then
            if FactionsMod.isGroupAligned(def.allegiance) then return false end
        end
    end

    local trigger = def.trigger
    if trigger == 'activity' then
        return activity >= (def.minActivity or 0)
    elseif trigger == 'heat' then
        return heat >= (def.minHeat or 0)
    elseif trigger == 'wealth' then
        return wealth >= (def.minWealth or 0)
    elseif trigger == 'depth' then
        return (depth or 0) >= 20  -- any meaningful drilling/precursor activity
    elseif trigger == 'containment' then
        return (containment or 0) >= (def.minContainment or 0)
    end
    -- No trigger defined: day-only gate
    return true
end

local function clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

local function getFallbackWeight(def, activity, wealth, heat, depth, containment)
    local trigger = def.trigger
    local weight = 1.0

    if trigger == 'activity' then
        local minValue = math.max(1, def.minActivity or 1)
        weight = clamp(activity / minValue, 0.35, 2.5) * rtune('fallback_activity_weight', 1.0)
    elseif trigger == 'heat' then
        local minValue = math.max(1, def.minHeat or 1)
        weight = clamp(heat / minValue, 0.35, 2.5) * rtune('fallback_heat_weight', 1.0)
    elseif trigger == 'wealth' then
        local minValue = math.max(1, def.minWealth or 1)
        weight = clamp(wealth / minValue, 0.35, 2.5) * rtune('fallback_wealth_weight', 1.0)
    elseif trigger == 'depth' then
        weight = clamp((depth or 0) / 20, 0.35, 2.0) * rtune('fallback_depth_weight', 1.1)
    elseif trigger == 'containment' then
        local minValue = math.max(1, def.minContainment or 1)
        weight = clamp((containment or 0) / minValue, 0.5, 2.4) * rtune('fallback_containment_weight', 1.35)
    end

    if def.humanoid then
        weight = weight * rtune('fallback_humanoid_weight', 1.08)
        -- Planet tuning can scale humanoid raid chance to zero (e.g. Nemaea)
        local humanScale = rtune('human_chance_scale', 1.0)
        if humanScale <= 0 then return 0 end
        weight = weight * humanScale
    end
    if def.swarm then
        weight = weight * rtune('fallback_swarm_weight', 0.82)
    end

    return math.max(0.05, weight)
end

local function weightedPick(candidates)
    local total = 0
    for _, entry in ipairs(candidates) do
        total = total + math.max(0, entry.weight or 0)
    end
    if total <= 0 then
        return candidates[math.random(#candidates)].typeId
    end

    local roll = math.random() * total
    for _, entry in ipairs(candidates) do
        roll = roll - math.max(0, entry.weight or 0)
        if roll <= 0 then
            return entry.typeId
        end
    end
    return candidates[#candidates].typeId
end

function Raids.pickRaidType()
    local day = GameState.day
    local heat = getHeatSignature()
    local wealth = GameState.getColonyWealth and GameState.getColonyWealth() or 0
    local activity = getActivityLevel()
    local depth = getDepthProgression()
    local containment = getContainmentPressure()

    -- Build eligible list
    local eligible = {}
    for typeId, def in pairs(RAID_TYPES) do
        if isEligible(def, day, activity, wealth, heat, depth, containment) then
            eligible[#eligible + 1] = typeId
        end
    end

    if #eligible == 0 then return 'beast_assault' end

    -- Eldritch swarms: activity-gated, highest eligible tier rolls first
    local swarmTiers = { 'swarm_tide', 'swarm', 'swarm_wave', 'swarm_probe' }
    local swarmChance = { 0.12, 0.18, 0.22, 0.18 }
    for i, tid in ipairs(swarmTiers) do
        local def = RAID_TYPES[tid]
        if def and isEligible(def, day, activity, wealth, heat, depth, containment)
            and math.random() < (swarmChance[i] * rtune('swarm_chance_scale', 1.0)) then
            return tid
        end
    end

    -- Thermovore swarms: heat-gated, highest tier first
    local thermoTiers = { 'thermovore_tide', 'thermovore_swarm', 'thermovore_probe' }
    local thermoChance = { 0.12, 0.18, 0.18 }
    for i, tid in ipairs(thermoTiers) do
        local def = RAID_TYPES[tid]
        if def and isEligible(def, day, activity, wealth, heat, depth, containment)
            and math.random() < (thermoChance[i] * rtune('thermovore_chance_scale', 1.0)) then
            return tid
        end
    end

    local containmentDef = RAID_TYPES.erebus_reclamation
    if containmentDef and isEligible(containmentDef, day, activity, wealth, heat, depth, containment)
        and math.random() < rtune('containment_reclamation_chance', 0.28) then
        return 'erebus_reclamation'
    end

    -- Pale Moon crusade: depth-triggered (drilling, precursor, anomaly)
    local pmDef = RAID_TYPES.pale_moon_crusade
    if pmDef and isEligible(pmDef, day, activity, wealth, heat, depth, containment)
        and math.random() < rtune('pale_moon_chance', 0.2) then
        return 'pale_moon_crusade'
    end

    -- Coordinated creature raid: activity-driven
    local coordDef = RAID_TYPES.coordinated
    if coordDef and isEligible(coordDef, day, activity, wealth, heat, depth, containment)
        and math.random() < rtune('coordinated_chance', 0.25) then
        return 'coordinated'
    end

    -- Human raids: wealth-gated + faction hostility
    local fok, Factions = pcall(require, 'src.colony.factions')
    local function factionHostile(fid)
        if not fok then return false end
        local rep = Factions.getRep(fid)
        return rep and rep < -10
    end

    -- Check from strongest to weakest so wealthy colonies face tougher raids
    -- Allegiance checks are handled by isEligible (blocks MasTema if Mammona-aligned)
    local humanRaids = {
        { 'precursor_incursion', 0.12 },
        { 'mastema_strike',      0.15 },
        { 'siege_camp',          0.12 },
        { 'drop_pod',            0.12 },
        { 'infiltration',        0.12 },
        { 'serpent_infiltration', 0.12, 'void_serpents' },
        { 'syndicate_shakedown', 0.15, 'zenith_syndicate' },
        { 'sapper',              0.15 },
        { 'faction_raid',        0.25 },
        { 'reaver_strip',        0.15, 'rust_reavers' },
        { 'pirate_raid',         0.2,  'black_maw' },
        { 'outlaw_raid',         0.2 },
    }

    for _, entry in ipairs(humanRaids) do
        local tid, chance, fid = entry[1], entry[2], entry[3]
        local def = RAID_TYPES[tid]
        if def and isEligible(def, day, activity, wealth, heat, depth, containment) then
            local factionCheck = true
            if fid then
                factionCheck = factionHostile(fid) or (wealth > (def.minWealth or 0) * 2)
            end
            if factionCheck and math.random() < (chance * rtune('human_chance_scale', 1.0)) then
                return tid
            end
        end
    end

    local weightedEligible = {}
    for _, typeId in ipairs(eligible) do
        weightedEligible[#weightedEligible + 1] = {
            typeId = typeId,
            weight = getFallbackWeight(RAID_TYPES[typeId], activity, wealth, heat, depth, containment),
        }
    end

    return weightedPick(weightedEligible)
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Raids.getActiveRaid()
    if not activeRaid then return nil end
    return {
        type        = activeRaid.type,
        name        = activeRaid.typeDef.name,
        phase       = activeRaid.phase,
        waveCount   = #activeRaid.waves,
        currentWave = activeRaid.currentWave,
        totalSpawned = activeRaid.totalSpawned,
        totalKilled  = activeRaid.totalKilled,
        alive       = countRaidAlive(),
        budget      = activeRaid.budget,
        timeElapsed = activeRaid.startTime,
        warningTime = activeRaid.warningTime,
    }
end

function Raids.isRaidActive()
    return activeRaid ~= nil
end

function Raids.getRaidsSurvived()
    return raidsSurvived
end

function Raids.getLog()
    return raidLog
end

function Raids.getRaidTypeDefs()
    local result = {}
    for id, def in pairs(RAID_TYPES) do
        result[#result + 1] = { id = id, name = def.name }
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function Raids.endRaid()
    if not activeRaid then return end
    -- Kill remaining raid creatures properly via Creatures.kill or ECS.destroy
    if activeRaid.raidCreatures then
        local crok, Creatures = pcall(require, 'src.creatures.creatures')
        for eid in pairs(activeRaid.raidCreatures) do
            if ECS.isAlive(eid) then
                local cr = ECS.get(eid, 'creature')
                if cr and cr.state ~= 'dead' then
                    if crok and Creatures.kill then
                        Creatures.kill(eid)
                    else
                        cr.health = 0
                        cr.state = 'dead'
                        ECS.destroy(eid)
                    end
                end
            end
        end
    end
    activeRaid = nil
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

local raidDelay = 0  -- sim seconds to delay next raid (from interrogation intel)
local lastThermovoreDay = 0   -- game-day of last thermovore raid
local THERMOVORE_COOLDOWN_DAYS = 3.0  -- min game-days between thermovore raids

function Raids.init()
    activeRaid = nil
    raidLog = {}
    raidsSurvived = 0
    raidDelay = 0
    lastThermovoreDay = 0
    GameState.raidsSurvived = 0
end

--- Delay the next raid by delaySeconds (used by interrogation intel)
function Raids.delayNextRaid(delaySeconds)
    raidDelay = raidDelay + delaySeconds
end

--- Check if raids are delayed (storyteller should call this before triggering)
function Raids.isDelayed()
    return raidDelay > 0
end

--- Tick the delay timer (call from step or storyteller)
function Raids.tickDelay(dt)
    if raidDelay > 0 then
        raidDelay = math.max(0, raidDelay - dt)
    end
end

--- Record that a thermovore raid just fired (called by storyteller)
function Raids.recordThermovoreRaid()
    lastThermovoreDay = GameState.day + (GameState.hour or 0) / 24
end

--- Check if thermovore raids are on cooldown
function Raids.isThermovoreOnCooldown()
    local currentDay = GameState.day + (GameState.hour or 0) / 24
    return (currentDay - lastThermovoreDay) < THERMOVORE_COOLDOWN_DAYS
end

---------------------------------------------------------------------------
-- Serialization support (for save/load)
---------------------------------------------------------------------------

function Raids.getState()
    local savedRaid = nil
    if activeRaid then
        -- Serialize active raid state (entity IDs in raidCreatures/wave.creatures
        -- will be remapped by save.lua on load)
        local savedWaves = {}
        for i, wave in ipairs(activeRaid.waves) do
            savedWaves[i] = {
                composition = wave.composition,
                spawned     = wave.spawned,
                spawnTime   = wave.spawnTime,
                creatures   = wave.creatures,  -- entity ID array, remapped on load
            }
        end
        -- Collect raidCreatures keys as an array for remapping
        local raidCreatureIds = {}
        for id in pairs(activeRaid.raidCreatures) do
            raidCreatureIds[#raidCreatureIds + 1] = id
        end
        savedRaid = {
            type          = activeRaid.type,
            budget        = activeRaid.budget,
            currentWave   = activeRaid.currentWave,
            startTime     = activeRaid.startTime,
            warningTime   = activeRaid.warningTime,
            phase         = activeRaid.phase,
            spawnPoints   = activeRaid.spawnPoints,
            totalSpawned  = activeRaid.totalSpawned,
            totalKilled   = activeRaid.totalKilled,
            raidCreatureIds = raidCreatureIds,
            waves         = savedWaves,
            factionId     = activeRaid.factionId,
        }
    end
    return {
        raidsSurvived = raidsSurvived,
        raidLog       = raidLog,
        raidDelay     = raidDelay > 0 and raidDelay or nil,
        lastThermovoreDay = lastThermovoreDay > 0 and lastThermovoreDay or nil,
        activeRaid    = savedRaid,
    }
end

function Raids.restoreState(saved)
    if not saved then return end
    raidsSurvived = saved.raidsSurvived or 0
    GameState.raidsSurvived = raidsSurvived
    raidLog       = saved.raidLog or {}
    raidDelay     = saved.raidDelay or 0
    lastThermovoreDay = saved.lastThermovoreDay or 0
    activeRaid    = nil  -- rebuilt below if saved

    if saved.activeRaid then
        local s = saved.activeRaid
        local typeDef = RAID_TYPES[s.type]
        if typeDef then
            -- Rebuild raidCreatures set from remapped ID array
            local raidCreatures = {}
            if s.raidCreatureIds then
                for _, id in ipairs(s.raidCreatureIds) do
                    if ECS.isAlive(id) then
                        raidCreatures[id] = true
                    end
                end
            end
            activeRaid = {
                type          = s.type,
                typeDef       = typeDef,
                budget        = s.budget,
                waves         = s.waves or {},
                currentWave   = s.currentWave or 1,
                startTime     = s.startTime or 0,
                warningTime   = s.warningTime or 0,
                phase         = s.phase or 'active',
                spawnPoints   = s.spawnPoints or {},
                raidCreatures = raidCreatures,
                totalSpawned  = s.totalSpawned or 0,
                totalKilled   = s.totalKilled or 0,
                factionId     = s.factionId,
            }
            -- Prune dead creatures from wave creature lists
            for _, wave in ipairs(activeRaid.waves) do
                if wave.creatures then
                    local alive = {}
                    for _, id in ipairs(wave.creatures) do
                        if ECS.isAlive(id) then
                            alive[#alive + 1] = id
                        end
                    end
                    wave.creatures = alive
                end
            end
        end
    end
end

return Raids
