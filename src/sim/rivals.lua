-- rivals.lua — Persistent raider rival system
-- Named raider leaders who survive encounters, adapt, and return stronger.
-- Rivals are stored in a registry between raids. When a humanoid raid spawns,
-- active rivals from the matching faction lead the wave as elite entities.
--
-- Lifecycle: generated during raid -> combat -> killed/escaped/captured
--   KILLED:    roll "cheat death" by tier. Survive = return scarred + stronger.
--   ESCAPED:   gain XP, may adapt to colony defenses.
--   CAPTURED:  become prisoner. May escape back to faction as insider.
--   DOWNED:    health <= 0 but not dead. Crawl offscreen or get captured.
--
-- Legally distinct from Nemesis: evolution is outcome-driven (raid results),
-- not memory-dialogue-driven (no "I remember you burned me" callbacks).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Rivals = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local MAX_RIVALS = 8       -- global cap on living rivals
local MAX_TIER   = 4       -- grunt_leader -> captain -> warlord -> commander
local CHEAT_DEATH_BASE = 0.35  -- base chance to survive death (tier 1)
local CHEAT_DEATH_PER_TIER = 0.15  -- +15% per tier
local RIVAL_SPAWN_CHANCE = 0.40    -- chance to generate a new rival per humanoid raid
local RECOVERY_DAYS = 3    -- days before a wounded rival can raid again
local PROMOTE_THRESHOLD = 3 -- encounters survived before tier-up

---------------------------------------------------------------------------
-- Tier definitions
---------------------------------------------------------------------------

local TIERS = {
    [1] = { title = 'Grunt Leader', hpMult = 1.5, dmgMult = 1.3, armorBonus = 0.05 },
    [2] = { title = 'Captain',      hpMult = 2.0, dmgMult = 1.6, armorBonus = 0.10 },
    [3] = { title = 'Warlord',      hpMult = 2.8, dmgMult = 2.0, armorBonus = 0.15 },
    [4] = { title = 'Commander',    hpMult = 3.5, dmgMult = 2.5, armorBonus = 0.20 },
}

Rivals.TIERS = TIERS

---------------------------------------------------------------------------
-- Rival scars (gained when cheating death)
---------------------------------------------------------------------------

local SCAR_TYPES = {
    { id = 'burn_scars',     name = 'Burn Scars',     desc = 'scarred by fire',         hpBonus = 10, traitGain = 'fire_resistant' },
    { id = 'missing_eye',    name = 'Missing Eye',    desc = 'lost an eye in combat',   dmgBonus = 2,  traitGain = 'cautious' },
    { id = 'metal_jaw',      name = 'Metal Jaw',      desc = 'jaw replaced with steel', hpBonus = 15 },
    { id = 'frost_scarred',  name = 'Frost-Scarred',  desc = 'survived deep cold',      hpBonus = 5,  traitGain = 'cold_adapted' },
    { id = 'stitched_torso', name = 'Stitched',       desc = 'held together by wire',   hpBonus = 20 },
    { id = 'prosthetic_arm', name = 'Prosthetic Arm', desc = 'replaced a lost limb',    dmgBonus = 4 },
    { id = 'nerve_damage',   name = 'Nerve Damage',   desc = 'dulled pain response',    hpBonus = 10, traitGain = 'fearless' },
    { id = 'deep_grudge',    name = 'Deep Grudge',    desc = 'fixated on revenge',      dmgBonus = 3,  traitGain = 'aggressive' },
}

---------------------------------------------------------------------------
-- Rival traits (affect combat behavior and stats)
---------------------------------------------------------------------------

local RIVAL_TRAITS = {
    bold        = { name = 'Bold',        desc = 'charges without hesitation', aggroBonus = 10 },
    cautious    = { name = 'Cautious',    desc = 'hangs back, waits for openings', speedMod = -0.1 },
    aggressive  = { name = 'Aggressive',  desc = 'attacks relentlessly', dmgMult = 1.15, retreatMod = -0.1 },
    fearless    = { name = 'Fearless',    desc = 'ignores pain', retreatMod = -0.2 },
    tactical    = { name = 'Tactical',    desc = 'flanks and repositions', speedMod = 0.15 },
    fire_resistant  = { name = 'Fire-Resistant',  desc = 'learned to avoid flames' },
    cold_adapted    = { name = 'Cold-Adapted',    desc = 'shrugs off the cold' },
    wall_breaker    = { name = 'Wall Breaker',    desc = 'targets defenses first' },
    hunter          = { name = 'Hunter',          desc = 'targets wounded colonists' },
    grudge_bearer   = { name = 'Grudge Bearer',   desc = 'fixates on the colonist who hurt them' },
}

Rivals.RIVAL_TRAITS = RIVAL_TRAITS

---------------------------------------------------------------------------
-- Faction -> species pool for rival generation
---------------------------------------------------------------------------

local FACTION_SPECIES = {
    outlaw          = { 'outlaw_brawler', 'outlaw_gunner', 'outlaw_marksman' },
    scavenger_crews = { 'scav_scrapper', 'scav_sharpshooter' },
    mammona_logistics = { 'mammona_enforcer', 'mammona_heavy' },
    mastema_ops     = { 'mastema_operative', 'mastema_sniper', 'mastema_breacher' },
    precursor       = { 'precursor_warrior', 'precursor_sage' },
    black_maw       = { 'maw_raider', 'maw_breacher', 'maw_heavy' },
    void_serpents   = { 'serpent_infiltrator', 'serpent_saboteur' },
    rust_reavers    = { 'reaver_scrapper', 'reaver_welder' },
    zenith_syndicate = { 'zenith_thug', 'zenith_gunner', 'zenith_enforcer' },
    sons_of_pale_moon = { 'pale_moon_zealot', 'pale_moon_priest' },
}

-- Map raid types to factions
local RAID_FACTION = {
    outlaw_raid         = 'outlaw',
    faction_raid        = 'scavenger_crews',
    mastema_strike      = 'mastema_ops',
    precursor_incursion = 'precursor',
    drop_pod            = 'mammona_logistics',
    sapper              = 'outlaw',
    siege_camp          = 'mammona_logistics',
    infiltration        = 'mastema_ops',
    pirate_raid         = 'black_maw',
    serpent_infiltration = 'void_serpents',
    reaver_strip        = 'rust_reavers',
    syndicate_shakedown = 'zenith_syndicate',
    pale_moon_crusade   = 'sons_of_pale_moon',
}

Rivals.RAID_FACTION = RAID_FACTION

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local registry = {}    -- { [rivalId] = rivalData }
local nextRivalId = 1
local deadRivals = {}  -- last 10 dead rivals (for storyteller flavor)

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

function Rivals.init()
    registry = {}
    nextRivalId = 1
    deadRivals = {}
end

---------------------------------------------------------------------------
-- Generate a new rival
---------------------------------------------------------------------------

local function pickTraits(count)
    local keys = {}
    for k in pairs(RIVAL_TRAITS) do keys[#keys + 1] = k end
    local picked = {}
    for i = 1, math.min(count, #keys) do
        local idx = math.random(#keys)
        picked[#picked + 1] = keys[idx]
        table.remove(keys, idx)
    end
    return picked
end

function Rivals.generate(faction, tier)
    if Rivals.countAlive() >= MAX_RIVALS then return nil end

    tier = tier or 1
    local aok, Adlib = pcall(require, 'src.util.adlib')
    if not aok then return nil end

    local identity = Adlib.generateColonistIdentity()
    local speciesPool = FACTION_SPECIES[faction]
    if not speciesPool or #speciesPool == 0 then return nil end

    local species = speciesPool[math.random(#speciesPool)]
    local cok, Creatures = pcall(require, 'src.creatures.creatures')
    local sp = cok and Creatures.SPECIES and Creatures.SPECIES[species]
    if not sp then return nil end

    local tierDef = TIERS[tier]
    local traits = pickTraits(1 + math.floor(tier / 2))

    local rival = {
        id         = nextRivalId,
        name       = identity.name,
        backstory  = identity.backstory,
        faction    = faction,
        species    = species,
        tier       = tier,
        title      = tierDef.title,

        -- Base stats (scaled from species)
        baseHealth = math.floor(sp.health * tierDef.hpMult),
        baseDamage = math.floor(sp.damage * tierDef.dmgMult),
        armorBonus = tierDef.armorBonus,

        -- History
        encounters    = 0,    -- total raids participated in
        escapes       = 0,    -- times retreated alive
        kills         = 0,    -- colonists killed
        colonistKills = {},   -- { colonistName, day } — trophies
        scars         = {},   -- scar IDs gained from cheating death
        traits        = traits,
        weaknesses    = {},   -- discoverable via prisoner interrogation

        -- Status
        alive         = true,
        recovering    = false,
        recoveryDay   = 0,    -- day when recovery ends
        captured      = false,
        prisonerId    = nil,
        entityId      = nil,  -- live ECS entity ID during a raid (nil between raids)

        -- Timestamps
        createdDay    = GameState.day,
        lastSeenDay   = GameState.day,
        lastRaidType  = nil,
    }

    nextRivalId = nextRivalId + 1
    registry[rival.id] = rival

    return rival
end

---------------------------------------------------------------------------
-- Query helpers
---------------------------------------------------------------------------

function Rivals.get(rivalId)
    return registry[rivalId]
end

function Rivals.getAll()
    return registry
end

function Rivals.countAlive()
    local n = 0
    for _, r in pairs(registry) do
        if r.alive then n = n + 1 end
    end
    return n
end

function Rivals.getForFaction(faction)
    local result = {}
    for _, r in pairs(registry) do
        if r.alive and not r.captured and not r.recovering and r.faction == faction then
            result[#result + 1] = r
        end
    end
    return result
end

function Rivals.getByEntityId(entityId)
    for _, r in pairs(registry) do
        if r.entityId == entityId then return r end
    end
    return nil
end

---------------------------------------------------------------------------
-- Compute effective stats (base + scar bonuses)
---------------------------------------------------------------------------

function Rivals.getEffectiveStats(rival)
    local hp = rival.baseHealth
    local dmg = rival.baseDamage
    local armor = rival.armorBonus

    -- Scar bonuses
    for _, scarId in ipairs(rival.scars) do
        for _, sdef in ipairs(SCAR_TYPES) do
            if sdef.id == scarId then
                hp = hp + (sdef.hpBonus or 0)
                dmg = dmg + (sdef.dmgBonus or 0)
                break
            end
        end
    end

    -- Trait multipliers
    for _, traitId in ipairs(rival.traits) do
        local tdef = RIVAL_TRAITS[traitId]
        if tdef and tdef.dmgMult then
            dmg = math.floor(dmg * tdef.dmgMult)
        end
    end

    -- Encounter scaling (+5% HP and +3% dmg per encounter survived)
    local encScale = 1 + rival.encounters * 0.05
    hp = math.floor(hp * encScale)
    dmg = math.floor(dmg * (1 + rival.encounters * 0.03))

    return { health = hp, damage = dmg, armor = armor }
end

---------------------------------------------------------------------------
-- Spawn a rival as an ECS entity during a raid
---------------------------------------------------------------------------

function Rivals.spawnEntity(rival, x, y)
    local cok, Creatures = pcall(require, 'src.creatures.creatures')
    if not cok then return nil end

    local sp = Creatures.SPECIES[rival.species]
    if not sp then return nil end

    local id = Creatures.spawn(rival.species, x, y, 0)
    if not id then return nil end

    local cr = ECS.get(id, 'creature')
    if not cr then return nil end

    -- Apply rival stats
    local stats = Rivals.getEffectiveStats(rival)
    cr.health    = stats.health
    cr.maxHealth = stats.health
    cr.damage    = stats.damage
    cr.name      = rival.title .. ' ' .. rival.name
    cr.size      = (sp.size or 8) * 1.3  -- visually larger

    -- Armor: species base + rival tier bonus (always apply if rival has armor)
    local baseArmor = sp.armorReduction or 0
    if baseArmor + rival.armorBonus > 0 then
        cr.armorReduction = baseArmor + rival.armorBonus
    end

    -- Override for raid behavior
    cr.leashRange = 999
    cr.aggroRange = 30  -- slightly wider than normal raiders

    -- Mark as rival entity
    ECS.set(id, 'rival', { rivalId = rival.id })

    rival.entityId = id
    rival.lastSeenDay = GameState.day

    return id
end

---------------------------------------------------------------------------
-- Raid integration: inject rivals into a humanoid raid wave
-- Called from raids.lua after spawnWave
---------------------------------------------------------------------------

function Rivals.onRaidSpawn(raidType, spawnPoints)
    local faction = RAID_FACTION[raidType]
    if not faction then return {} end

    local available = Rivals.getForFaction(faction)
    local injected = {}

    -- Spawn existing rivals
    for _, rival in ipairs(available) do
        if #spawnPoints > 0 then
            local sp = spawnPoints[math.random(#spawnPoints)]
            local sx = sp.x + math.random(-2, 2)
            local sy = sp.y + math.random(-2, 2)
            local wok, World = pcall(require, 'src.world.tilemap')
            if wok and World.inBounds(sx, sy) and World.isWalkable(sx, sy, 0) then
                local entityId = Rivals.spawnEntity(rival, sx, sy)
                if entityId then
                    rival.encounters = rival.encounters + 1
                    rival.lastRaidType = raidType
                    injected[#injected + 1] = entityId
                end
            end
        end
    end

    -- Maybe generate a new rival if none participated
    if #injected == 0 and math.random() < RIVAL_SPAWN_CHANCE then
        local rival = Rivals.generate(faction, 1)
        if rival and #spawnPoints > 0 then
            local sp = spawnPoints[math.random(#spawnPoints)]
            local sx = sp.x + math.random(-2, 2)
            local sy = sp.y + math.random(-2, 2)
            local wok, World = pcall(require, 'src.world.tilemap')
            if wok and World.inBounds(sx, sy) and World.isWalkable(sx, sy, 0) then
                local entityId = Rivals.spawnEntity(rival, sx, sy)
                if entityId then
                    rival.encounters = 1
                    rival.lastRaidType = raidType
                    injected[#injected + 1] = entityId

                    -- Announce
                    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
                    if sok then
                        Storyteller.logEvent('Rival Spotted',
                            rival.title .. ' ' .. rival.name .. ' leads the attackers.')
                    end
                end
            end
        end
    end

    return injected
end

---------------------------------------------------------------------------
-- Death handling: called when a rival entity's health hits 0
-- Returns true if the rival cheated death (should not be destroyed)
---------------------------------------------------------------------------

function Rivals.onRivalDeath(entityId, killerId)
    local rival = Rivals.getByEntityId(entityId)
    if not rival then return false end

    -- Roll cheat death
    local cheatChance = CHEAT_DEATH_BASE + (rival.tier - 1) * CHEAT_DEATH_PER_TIER
    -- Higher encounters = more likely to survive (they're crafty)
    cheatChance = math.min(0.85, cheatChance + rival.encounters * 0.03)

    if math.random() < cheatChance then
        -- Survived: add a scar, go into recovery
        local scar = SCAR_TYPES[math.random(#SCAR_TYPES)]
        -- Don't duplicate scars
        local hasScar = false
        for _, s in ipairs(rival.scars) do
            if s == scar.id then hasScar = true; break end
        end
        if not hasScar then
            rival.scars[#rival.scars + 1] = scar.id
            -- Gain trait from scar if applicable
            if scar.traitGain then
                local hasTrait = false
                for _, t in ipairs(rival.traits) do
                    if t == scar.traitGain then hasTrait = true; break end
                end
                if not hasTrait then
                    rival.traits[#rival.traits + 1] = scar.traitGain
                end
            end
        end

        rival.recovering = true
        rival.recoveryDay = GameState.day + RECOVERY_DAYS + math.random(3)
        -- Keep entityId: entity is still alive (fleeing). Cleared on escape or actual death.

        -- Check for promotion
        if rival.encounters >= PROMOTE_THRESHOLD * rival.tier and rival.tier < MAX_TIER then
            rival.tier = rival.tier + 1
            rival.title = TIERS[rival.tier].title
            -- Recalculate base stats for new tier
            local cok, Creatures = pcall(require, 'src.creatures.creatures')
            local sp = cok and Creatures.SPECIES and Creatures.SPECIES[rival.species]
            if sp then
                rival.baseHealth = math.floor(sp.health * TIERS[rival.tier].hpMult)
                rival.baseDamage = math.floor(sp.damage * TIERS[rival.tier].dmgMult)
                rival.armorBonus = TIERS[rival.tier].armorBonus
            end
        end

        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok then
            Storyteller.logEvent('Rival Survives',
                rival.name .. ' (' .. rival.title .. ') survived. Expected to recover and raid again.')
        end

        return true  -- don't destroy: let creature flee offscreen
    end

    -- Actually dead
    rival.alive = false
    rival.entityId = nil

    -- Record in dead rivals log
    deadRivals[#deadRivals + 1] = {
        name = rival.name, title = rival.title, faction = rival.faction,
        tier = rival.tier, kills = rival.kills, encounters = rival.encounters,
        killedDay = GameState.day, killedBy = killerId,
    }
    while #deadRivals > 10 do table.remove(deadRivals, 1) end

    -- Power vacuum: promote a random lower-tier rival of same faction
    for _, r in pairs(registry) do
        if r.alive and r.faction == rival.faction and r.tier < rival.tier then
            r.tier = math.min(MAX_TIER, r.tier + 1)
            r.title = TIERS[r.tier].title
            local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if sok then
                Storyteller.logEvent('Rival Promoted',
                    r.name .. ' promoted to ' .. r.title .. ' after ' .. rival.name .. '\'s death.')
            end
            break  -- only promote one
        end
    end

    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok then
        Storyteller.logEvent('Rival Killed',
            rival.title .. ' ' .. rival.name .. ' is dead.' ..
            (rival.kills > 0 and (' They killed ' .. rival.kills .. ' of ours.') or ''))
    end

    return false  -- proceed with normal death
end

---------------------------------------------------------------------------
-- Escape handling: rival retreated from a raid
---------------------------------------------------------------------------

function Rivals.onRivalEscape(entityId)
    local rival = Rivals.getByEntityId(entityId)
    if not rival then return end

    rival.escapes = rival.escapes + 1
    rival.entityId = nil

    -- Adaptation: chance to gain a defensive trait based on colony equipment
    if math.random() < 0.3 then
        local adaptTraits = { 'cautious', 'tactical', 'wall_breaker' }
        local pick = adaptTraits[math.random(#adaptTraits)]
        local has = false
        for _, t in ipairs(rival.traits) do
            if t == pick then has = true; break end
        end
        if not has then
            rival.traits[#rival.traits + 1] = pick
        end
    end

    -- Check for promotion
    if rival.encounters >= PROMOTE_THRESHOLD * rival.tier and rival.tier < MAX_TIER then
        rival.tier = rival.tier + 1
        rival.title = TIERS[rival.tier].title
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        local sp = cok and Creatures.SPECIES and Creatures.SPECIES[rival.species]
        if sp then
            rival.baseHealth = math.floor(sp.health * TIERS[rival.tier].hpMult)
            rival.baseDamage = math.floor(sp.damage * TIERS[rival.tier].dmgMult)
            rival.armorBonus = TIERS[rival.tier].armorBonus
        end

        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok then
            Storyteller.logEvent('Rival Promoted',
                rival.name .. ' promoted to ' .. rival.title .. '.')
        end
    end
end

---------------------------------------------------------------------------
-- Colonist kill tracking
---------------------------------------------------------------------------

function Rivals.onColonistKilled(entityId, colonistName)
    local rival = Rivals.getByEntityId(entityId)
    if not rival then return end

    rival.kills = rival.kills + 1
    rival.colonistKills[#rival.colonistKills + 1] = {
        name = colonistName,
        day  = GameState.day,
    }

    -- Kill trophies grant flat stat boosts
    rival.baseDamage = rival.baseDamage + 2
    rival.baseHealth = rival.baseHealth + 5
end

---------------------------------------------------------------------------
-- Capture integration: when a rival is captured as prisoner
---------------------------------------------------------------------------

function Rivals.onRivalCapture(entityId, prisonerId)
    local rival = Rivals.getByEntityId(entityId)
    if not rival then return end

    rival.captured = true
    rival.prisonerId = prisonerId
    rival.entityId = nil

    -- Apply rival identity to prisoner component
    local prisoner = ECS.get(prisonerId, 'prisoner')
    if prisoner then
        prisoner.name = rival.name
        prisoner.isRival = true
        prisoner.rivalId = rival.id
        -- Rivals are harder to recruit
        prisoner.resistance = math.min(80, prisoner.resistance + rival.tier * 10)
        prisoner.recruitChance = math.max(5, prisoner.recruitChance - rival.tier * 5)
    end
end

---------------------------------------------------------------------------
-- Prisoner escape: rival breaks free and returns to faction
---------------------------------------------------------------------------

function Rivals.onPrisonerEscape(rivalId)
    local rival = registry[rivalId]
    if not rival then return end

    rival.captured = false
    rival.prisonerId = nil
    rival.recovering = true
    rival.recoveryDay = GameState.day + 2

    -- Insider knowledge: gain tactical trait
    local has = false
    for _, t in ipairs(rival.traits) do
        if t == 'tactical' then has = true; break end
    end
    if not has then
        rival.traits[#rival.traits + 1] = 'tactical'
    end

    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok then
        Storyteller.logEvent('Rival Escapes',
            rival.name .. ' escaped captivity. They know the layout of the colony now.')
    end
end

---------------------------------------------------------------------------
-- Prisoner recruited: rival becomes a colonist permanently
---------------------------------------------------------------------------

function Rivals.onRivalRecruited(rivalId)
    local rival = registry[rivalId]
    if not rival then return end

    rival.alive = false
    rival.captured = false
    rival.prisonerId = nil
end

---------------------------------------------------------------------------
-- Step: recovery timers, off-screen events
---------------------------------------------------------------------------

function Rivals.step(dt)
    for _, rival in pairs(registry) do
        if rival.alive and rival.recovering then
            if GameState.day >= rival.recoveryDay then
                rival.recovering = false
            end
        end
    end
end

---------------------------------------------------------------------------
-- Info for UI / tooltips
---------------------------------------------------------------------------

function Rivals.getRivalSummary(rivalId)
    local r = registry[rivalId]
    if not r then return nil end

    local scarNames = {}
    for _, scarId in ipairs(r.scars) do
        for _, sdef in ipairs(SCAR_TYPES) do
            if sdef.id == scarId then
                scarNames[#scarNames + 1] = sdef.name
                break
            end
        end
    end

    local traitNames = {}
    for _, tid in ipairs(r.traits) do
        local tdef = RIVAL_TRAITS[tid]
        if tdef then traitNames[#traitNames + 1] = tdef.name end
    end

    return {
        name       = r.name,
        title      = r.title,
        faction    = r.faction,
        tier       = r.tier,
        encounters = r.encounters,
        escapes    = r.escapes,
        kills      = r.kills,
        scars      = scarNames,
        traits     = traitNames,
        alive      = r.alive,
        captured   = r.captured,
        recovering = r.recovering,
    }
end

function Rivals.getDeadRivals()
    return deadRivals
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Rivals.getState()
    return {
        registry    = registry,
        nextRivalId = nextRivalId,
        deadRivals  = deadRivals,
    }
end

function Rivals.loadState(saved)
    registry = {}
    nextRivalId = 1
    deadRivals = {}
    if not saved then return end

    registry    = saved.registry or {}
    nextRivalId = saved.nextRivalId or 1
    deadRivals  = saved.deadRivals or {}

    -- Clear live entity refs (stale after load)
    for _, r in pairs(registry) do
        r.entityId = nil
    end
end

return Rivals
