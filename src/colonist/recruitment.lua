-- recruitment.lua — Colony growth and prisoner management
-- RimWorld-style two-phase prisoner recruitment: reduce resistance, then recruit.
-- Prisoner mood (from room quality, food, medical care) multiplies recruitment speed.
-- Prison breaks scale with prisoner count and low mood.
--
-- Colony growth paths:
--   1. Prisoner capture from raids (downed raiders → prison → recruit)
--   2. Refugee events (storyteller sends groups seeking shelter)
--   3. Rescue events (downed travelers found on map)
--   4. Cloning vat (late-game: food + components + power + time)
--   5. Radio beacon (passive wanderer attractor, costs power)

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Hope      = require('src.colony.hope')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end
local _StorageNet
local function getStorageNet()
    if _StorageNet == nil then
        local ok, mod = pcall(require, 'src.logistics.storage_network')
        _StorageNet = ok and mod or false
    end
    return _StorageNet or nil
end

local Recruitment = {}

-- Lazy-loaded modules (avoid pcall in ECS tick systems)
local _Power, _RivalsMod
local function lazyLoadRecruitment()
    if _Power ~= nil then return end
    local ok
    ok, _Power = pcall(require, 'src.sim.power')
    if not ok then _Power = false end
    ok, _RivalsMod = pcall(require, 'src.sim.rivals')
    if not ok then _RivalsMod = false end
end

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local CAPTURE_CHANCE       = 0.25   -- 25% chance a raid kill spawns a prisoner
local PRISONER_FOOD_RATE   = 0.02   -- food per second
local WARDEN_VISIT_INTERVAL = 60    -- seconds between warden visits
local BASE_RESIST_REDUCTION = 1.0   -- resistance reduced per visit
local PRISON_BREAK_MTB     = 600    -- mean time between break attempts (seconds)
local CLONE_GROW_TIME      = 300
local CLONE_FOOD_COST      = 30
local CLONE_COMP_COST      = 2
local BEACON_ATTRACT_INTERVAL = 300
local BEACON_ATTRACT_CHANCE   = 0.25

---------------------------------------------------------------------------
-- Prisoner component structure:
-- {
--   name, backstory, traits, skills,
--   resistance,      -- 0-30, must reach 0 before recruitment attempts
--   mood,            -- 0-100, affects recruitment speed (0.5x at 0, 1.5x at 100)
--   fed,             -- bool, whether food was available
--   health,          -- 0-100
--   wounded,         -- bool, has untreated wounds
--   wardenTimer,     -- countdown to next warden visit
--   phase,           -- 'resist' or 'recruit'
--   recruitChance,   -- base % per attempt (10-50, based on difficulty)
--   escapeAttempts,  -- number of break attempts made
-- }
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Mood calculation for prisoners
---------------------------------------------------------------------------

local function calcPrisonerMood(prisoner, pos)
    local mood = 40  -- base: "I am a prisoner" starts at 40/100

    -- Room quality bonus
    local rok, RoomsMod = pcall(require, 'src.world.rooms')
    if rok then
        local World = require('src.world.tilemap')
        local roomId = World.getRoom(pos.x, pos.y, pos.depth or 0)
        if roomId and roomId > 0 then
            local info = RoomsMod.getRoomInfo(roomId)
            if info then
                -- Impressiveness adds mood (0-15 range)
                mood = mood + math.min(15, (info.impressiveness or 0) / 3)
                -- Temperature comfort
                if info.tempTier then
                    mood = mood + info.tempTier.morale
                end
            end
        end
    end

    -- Food quality
    if prisoner.fed then
        mood = mood + 5
    else
        mood = mood - 10
    end

    -- Wounds cause pain → mood penalty
    if prisoner.wounded then
        mood = mood - 8
    end

    -- Health factor
    if prisoner.health < 50 then
        mood = mood - math.floor((50 - prisoner.health) / 10)
    end

    return math.max(0, math.min(100, mood))
end

---------------------------------------------------------------------------
-- Mood multiplier (RimWorld-style: 0.5x at 0 mood, 1.5x at 100 mood)
---------------------------------------------------------------------------

local function moodMultiplier(mood)
    return 0.5 + (mood / 100) * 1.0
end

---------------------------------------------------------------------------
-- Find best warden (colonist with highest social/cooking skill)
---------------------------------------------------------------------------

local function findBestWarden()
    local bestId, bestSkill = nil, -1
    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.state ~= 'mental_break' and col.state ~= 'sleeping' then
            local social = (col.skills and col.skills.cooking) or 1
            if social > bestSkill then
                bestSkill = social
                bestId = id
            end
        end
    end
    return bestId, bestSkill
end

local function findAvailablePrisonerBed()
    for bedId, comps in ECS.query('bed', 'pos') do
        if comps.bed.prisoner and not comps.bed.owner then
            return bedId, comps.pos
        end
    end
    for bedId, comps in ECS.query('bed', 'pos') do
        if not comps.bed.owner then
            return bedId, comps.pos
        end
    end
    return nil, nil
end

---------------------------------------------------------------------------
-- Capture: create prisoner from downed raid creature
---------------------------------------------------------------------------

-- Faction-specific skill biases for captured prisoners
local FACTION_SKILL_BIAS = {
    mastema_ops       = { 'hunting', 'research' },
    mammona_logistics = { 'cooking', 'building' },
    scavenger_crews   = { 'building', 'mining' },
    black_maw         = { 'hunting', 'mining' },
    void_serpents     = { 'research', 'hunting' },
    rust_reavers      = { 'building', 'mining' },
    zenith_syndicate  = { 'cooking', 'hunting' },
    sons_of_pale_moon = { 'research', 'medical' },
    ruin_delvers      = { 'research', 'mining' },
    rim_runners       = { 'cooking', 'research' },
    solar_nomads      = { 'cooking', 'medical' },
}

function Recruitment.tryCapture(deadEntityId)
    if not ECS.isAlive(deadEntityId) then return false end
    local tag = ECS.get(deadEntityId, 'raid_tag')
    if not tag then return false end

    if math.random() > CAPTURE_CHANCE then return false end

    -- Need a prisoner bed
    local _, prisonPos = findAvailablePrisonerBed()
    if not prisonPos then return false end

    local pos = ECS.get(deadEntityId, 'pos')
    if not pos then return false end

    local factionId = tag.factionId  -- nil for beast raids

    local Adlib = require('src.util.adlib')
    local identity = Adlib.generateColonistIdentity()

    -- Recruitment difficulty: 10-50 base chance, harder prisoners take longer
    local difficulty = 0.3 + math.random() * 0.4  -- 30-70% difficulty
    local baseResistance = math.floor(10 + difficulty * 30)  -- 10-31 resistance
    local recruitChance = math.floor((1 - difficulty) * 40 + 10)  -- 10-38% per attempt

    local id = ECS.spawn()
    ECS.set(id, 'pos', {
        x = pos.x, y = pos.y, depth = pos.depth or 0,
        prevX = pos.x, prevY = pos.y,
    })

    local skills = {}
    local SKILL_NAMES = { 'mining', 'building', 'cooking', 'hunting', 'research', 'medical' }
    for _, s in ipairs(SKILL_NAMES) do
        skills[s] = math.random(1, 8)
    end
    -- One strong skill
    local bestSkillName = SKILL_NAMES[math.random(#SKILL_NAMES)]
    skills[bestSkillName] = math.max(skills[bestSkillName], math.random(5, 9))

    -- Faction-specific skill bias
    local biases = factionId and FACTION_SKILL_BIAS[factionId]
    if biases then
        for _, skillName in ipairs(biases) do
            skills[skillName] = math.max(skills[skillName], math.random(4, 8))
        end
    end

    ECS.set(id, 'prisoner', {
        name           = identity.name,
        gender         = identity.gender,
        backstory      = identity.backstory,
        traits         = identity.traits,
        skills         = skills,
        resistance     = baseResistance,
        mood           = 40,
        fed            = true,
        health         = 30 + math.random(40),  -- captured wounded
        wounded        = true,
        wardenTimer    = WARDEN_VISIT_INTERVAL,
        phase          = 'resist',  -- 'resist' → 'recruit'
        recruitChance  = recruitChance,
        escapeAttempts = 0,
        factionId      = factionId,
    })

    -- Faction rep hit for capturing their member
    if factionId then
        local fok, FactionsMod = pcall(require, 'src.colony.factions')
        if fok then FactionsMod.onPrisonerCaptured(factionId) end
    end

    -- If this raider is a rival, link the prisoner to the rival registry
    local rivalComp = ECS.get(deadEntityId, 'rival')
    if rivalComp then
        local rok, RivalsMod = pcall(require, 'src.sim.rivals')
        if rok and RivalsMod.onRivalCapture then
            RivalsMod.onRivalCapture(deadEntityId, id)
        end
    end

    -- Destroy the original dead raider entity now that all data has been read
    ECS.destroy(deadEntityId)

    Hope.applyDelta(1, 0)
    return true, id
end

---------------------------------------------------------------------------
-- Designate a bed as prisoner bed
---------------------------------------------------------------------------

function Recruitment.setPrisonerBed(bedEntityId, isPrisoner)
    local bed = ECS.get(bedEntityId, 'bed')
    if not bed then return false end
    bed.prisoner = isPrisoner or false
    if isPrisoner and bed.owner then
        -- Unassign any colonist from a bed being converted to prisoner use
        bed.owner = nil
    end
    return true
end

---------------------------------------------------------------------------
-- Prisoner tick system — two-phase recruitment
---------------------------------------------------------------------------

local function prisonerSystem(dt, id, comps)
    local prisoner = comps.prisoner
    local pos = comps.pos

    -- Food consumption
    if (GameState.resources.food or 0) >= PRISONER_FOOD_RATE * dt then
        GameState.resources.food = GameState.resources.food - PRISONER_FOOD_RATE * dt
        prisoner.fed = true
    else
        prisoner.fed = false
    end

    -- Natural wound healing (slow without medical treatment)
    if prisoner.wounded then
        prisoner.health = math.min(100, prisoner.health + 0.02 * dt)
        if prisoner.health >= 80 then
            prisoner.wounded = false
        end
    end

    -- Update mood
    prisoner.mood = calcPrisonerMood(prisoner, pos)

    -- Warden visit countdown
    prisoner.wardenTimer = prisoner.wardenTimer - dt
    if prisoner.wardenTimer > 0 then return end
    prisoner.wardenTimer = WARDEN_VISIT_INTERVAL

    -- Find a warden
    local wardenId, wardenSkill = findBestWarden()
    if not wardenId then return end  -- no available warden

    -- Warden negotiation ability: 0.4 + skill * 0.075 (RimWorld formula)
    local negotiation = 0.4 + (wardenSkill or 1) * 0.075
    local moodMult = moodMultiplier(prisoner.mood)

    -- Phase 1: Reduce resistance
    if prisoner.phase == 'resist' then
        local reduction = BASE_RESIST_REDUCTION * negotiation * moodMult
        prisoner.resistance = prisoner.resistance - reduction

        if prisoner.resistance <= 0 then
            prisoner.resistance = 0
            prisoner.phase = 'recruit'
        end
        return
    end

    -- Phase 2: Recruitment attempt
    if prisoner.phase == 'recruit' then
        local chance = (prisoner.recruitChance / 100) * negotiation * moodMult
        chance = math.max(0.02, math.min(0.8, chance))  -- clamp 2-80%

        if math.random() < chance then
            -- Success! Convert to colonist
            local Colonist = require('src.colonist.colonist')
            local newId = Colonist.spawn(pos.x, pos.y)
            if newId then
                local col = ECS.get(newId, 'colonist')
                if col then
                    col.name          = prisoner.name
                    col.gender        = prisoner.gender
                    col.backstory     = prisoner.backstory
                    col.traits        = prisoner.traits
                    col.skills        = prisoner.skills
                    col.health        = prisoner.health
                    col.factionOrigin = prisoner.factionId
                end
                -- Start with lower needs (just got out of prison)
                local needs = ECS.get(newId, 'needs')
                if needs then
                    needs.morale = 40 + math.random(20)
                end
                Hope.applyDelta(4, -2)
            end
            -- Notify rival system: rival has been permanently recruited
            if prisoner.isRival and prisoner.rivalId then
                lazyLoadRecruitment()
                if _RivalsMod and _RivalsMod.onRivalRecruited then
                    _RivalsMod.onRivalRecruited(prisoner.rivalId)
                end
            end
            ECS.destroy(id)
        end
    end
end

---------------------------------------------------------------------------
-- Prison break system — runs on all prisoners
---------------------------------------------------------------------------

local breakCheckTimer = 0

local function prisonBreakCheck(dt)
    breakCheckTimer = breakCheckTimer - dt
    if breakCheckTimer > 0 then return end
    breakCheckTimer = 30  -- check every 30 game seconds

    local prisonerCount = ECS.countWith('prisoner')
    if prisonerCount == 0 then return end

    -- More prisoners = more total break attempts (each rolls independently)
    for pid, comps in ECS.query('prisoner', 'pos') do
        local prisoner = comps.prisoner

        -- Base chance per check cycle
        local baseChance = 30 / PRISON_BREAK_MTB  -- ~5% per check

        -- Low mood increases chance (2x at mood 0)
        local moodFactor = 1 + (1 - prisoner.mood / 100)
        -- Wounded prisoners can't break out
        if prisoner.health < 30 then goto continue end

        local breakChance = baseChance * moodFactor

        -- Room door count reduces chance (checked via room detection)
        local rok, RoomsMod = pcall(require, 'src.world.rooms')
        if rok then
            local World = require('src.world.tilemap')
            local roomId = World.getRoom(comps.pos.x, comps.pos.y, comps.pos.depth or 0)
            if roomId and roomId > 0 then
                -- Sealed rooms are harder to escape
                local info = RoomsMod.getRoomInfo(roomId)
                if info and info.sealed then
                    breakChance = breakChance * 0.5
                end
            end
        end

        if math.random() < breakChance then
            -- Prison break! Prisoner escapes toward map edge
            prisoner.escapeAttempts = (prisoner.escapeAttempts or 0) + 1
            Hope.applyDelta(-2, 2)

            -- Faction rep recovery: their person got out
            if prisoner.factionId then
                local ffok, FactionsMod = pcall(require, 'src.colony.factions')
                if ffok then FactionsMod.onPrisonerEscaped(prisoner.factionId) end
            end

            -- Notify rival system if this was a captured rival
            if prisoner.isRival and prisoner.rivalId then
                local rvOk, RivalsMod = pcall(require, 'src.sim.rivals')
                if rvOk and RivalsMod.onPrisonerEscape then
                    RivalsMod.onPrisonerEscape(prisoner.rivalId)
                end
            end

            -- Convert to hostile creature that flees
            local World = require('src.world.tilemap')
            local Creatures = require('src.creatures.creatures')
            local escapee = Creatures.spawn('ice_stalker', comps.pos.x, comps.pos.y, comps.pos.depth)
            if escapee then
                local cr = ECS.get(escapee, 'creature')
                if cr then
                    cr.state = 'flee'
                    cr.fleeRange = 999
                    cr.hostile = false
                    cr.name = prisoner.name .. ' (escaped)'
                    cr.health = math.floor(prisoner.health * 0.8)
                end
            end
            ECS.destroy(pid)
        end
        ::continue::
    end
end

---------------------------------------------------------------------------
-- Medical treatment for prisoners (colonist doctor visits)
---------------------------------------------------------------------------

function Recruitment.treatPrisoner(prisonerId, doctorSkill)
    local prisoner = ECS.get(prisonerId, 'prisoner')
    if not prisoner then return false end
    if not prisoner.wounded then return false end

    -- Healing amount based on doctor skill
    local heal = 10 + (doctorSkill or 1) * 3
    prisoner.health = math.min(100, prisoner.health + heal)
    if prisoner.health >= 70 then
        prisoner.wounded = false
    end
    return true
end

---------------------------------------------------------------------------
-- Refugee events
---------------------------------------------------------------------------

function Recruitment.spawnRefugees(count, factionId)
    local World = require('src.world.tilemap')
    local Colonist = require('src.colonist.colonist')
    local w, h = World.width(), World.height()

    local side = math.random(4)
    local bx, by
    if side == 1 then     bx = math.random(5, w - 5); by = 3
    elseif side == 2 then bx = math.random(5, w - 5); by = h - 4
    elseif side == 3 then bx = 3;                      by = math.random(5, h - 5)
    else                  bx = w - 4;                   by = math.random(5, h - 5)
    end

    local spawned = 0
    for i = 1, count do
        local sx = bx + math.random(-2, 2)
        local sy = by + math.random(-2, 2)
        if World.inBounds(sx, sy) and World.isWalkable(sx, sy, 0) then
            local id = Colonist.spawn(sx, sy)
            if id then
                local needs = ECS.get(id, 'needs')
                if needs then
                    needs.warmth = 20 + math.random(20)
                    needs.food   = 15 + math.random(25)
                    needs.rest   = 30 + math.random(30)
                    needs.morale = 20 + math.random(20)
                end
                local col = ECS.get(id, 'colonist')
                if col then
                    col.health = 40 + math.random(40)
                    col.factionOrigin = factionId
                end
                spawned = spawned + 1
            end
        end
    end

    if spawned > 0 then
        Hope.applyDelta(2 * spawned, -1)
    end
    return spawned
end

---------------------------------------------------------------------------
-- Rescue event — downed traveler on the map
-- If rescued (carried to bed), becomes a prisoner with low resistance
---------------------------------------------------------------------------

function Recruitment.spawnDowned(x, y, factionId)
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) or not World.isWalkable(x, y, 0) then return nil end

    local Adlib = require('src.util.adlib')
    local identity = Adlib.generateColonistIdentity()

    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, prevX = x, prevY = y })

    local skills = {}
    local SKILL_NAMES = { 'mining', 'building', 'cooking', 'hunting', 'research', 'medical' }
    for _, s in ipairs(SKILL_NAMES) do
        skills[s] = math.random(1, 8)
    end

    -- Faction-specific skill bias for downed travelers
    local biases = factionId and FACTION_SKILL_BIAS[factionId]
    if biases then
        for _, skillName in ipairs(biases) do
            skills[skillName] = math.max(skills[skillName], math.random(4, 8))
        end
    end

    ECS.set(id, 'prisoner', {
        name           = identity.name,
        gender         = identity.gender,
        backstory      = identity.backstory,
        traits         = identity.traits,
        skills         = skills,
        resistance     = 3 + math.random(5),  -- very low resistance (grateful)
        mood           = 50,
        fed            = false,
        health         = 10 + math.random(20),  -- badly hurt
        wounded        = true,
        wardenTimer    = WARDEN_VISIT_INTERVAL,
        phase          = 'resist',
        recruitChance  = 40 + math.random(20),  -- easy to recruit (grateful)
        escapeAttempts = 0,
        factionId      = factionId,
    })

    return id
end

---------------------------------------------------------------------------
-- Buy a colonist from a merchant for thermal cores
---------------------------------------------------------------------------

function Recruitment.buyColonist(cost, factionId)
    if (GameState.resources.thermalCores or 0) < cost then
        return false, 'Not enough thermal cores'
    end

    if cost > 0 then
        local SNet = getStorageNet()
        if SNet then SNet.withdraw('thermalCores', cost, GameState.startX, GameState.startY)
        else GameState.spendResource('thermalCores', cost) end
    end

    local World = require('src.world.tilemap')
    local Colonist = require('src.colonist.colonist')

    local cx = GameState.startX + math.random(-3, 3)
    local cy = GameState.startY + math.random(-3, 3)
    if not World.isWalkable(cx, cy, 0) then
        cx, cy = GameState.startX, GameState.startY
    end

    local id = Colonist.spawn(cx, cy)
    if id then
        local needs = ECS.get(id, 'needs')
        if needs then
            needs.warmth = 30 + math.random(20)
            needs.food   = 30 + math.random(20)
            needs.morale = 25 + math.random(15)
        end
        local col = ECS.get(id, 'colonist')
        if col then
            col.backstory = 'Purchased from a passing caravan. Past unknown.'
            col.health = 60 + math.random(30)
            col.factionOrigin = factionId
        end
        Hope.applyDelta(2, 0)
        return true, id
    end
    return false, 'Failed to spawn'
end

function Recruitment.buyPrisoner(cost, factionId)
    if cost > 0 and (GameState.resources.thermalCores or 0) < cost then
        return false, 'Not enough thermal cores'
    end
    if cost > 0 then
        local SNet = getStorageNet()
        if SNet then SNet.withdraw('thermalCores', cost, GameState.startX, GameState.startY)
        else GameState.spendResource('thermalCores', cost) end
    end

    local _, prisonPos = findAvailablePrisonerBed()
    if not prisonPos then
        return false, 'No available prisoner bed'
    end

    local Adlib = require('src.util.adlib')
    local identity = Adlib.generateColonistIdentity()

    local id = ECS.spawn()
    ECS.set(id, 'pos', {
        x = prisonPos.x, y = prisonPos.y, depth = prisonPos.depth or 0,
        prevX = prisonPos.x, prevY = prisonPos.y,
    })

    local skills = {}
    local skillNames = { 'mining', 'building', 'cooking', 'hunting', 'research', 'medical' }
    for _, skillName in ipairs(skillNames) do
        skills[skillName] = math.random(1, 8)
    end
    local bestSkillName = skillNames[math.random(#skillNames)]
    skills[bestSkillName] = math.max(skills[bestSkillName], math.random(5, 9))

    -- Faction-specific skill bias for purchased prisoners
    local biases = factionId and FACTION_SKILL_BIAS[factionId]
    if biases then
        for _, skillName in ipairs(biases) do
            skills[skillName] = math.max(skills[skillName], math.random(4, 8))
        end
    end

    ECS.set(id, 'prisoner', {
        name           = identity.name,
        gender         = identity.gender,
        backstory      = 'Sold in restraints by a passing caravan. Past obscured by transit records.',
        traits         = identity.traits,
        skills         = skills,
        resistance     = 12 + math.random(10),
        mood           = 35,
        fed            = true,
        health         = 55 + math.random(25),
        wounded        = false,
        wardenTimer    = WARDEN_VISIT_INTERVAL,
        phase          = 'resist',
        recruitChance  = 18 + math.random(12),
        escapeAttempts = 0,
        factionId      = factionId,
    })

    Hope.applyDelta(-1, 1)
    return true, id
end

Recruitment.buySlave = Recruitment.buyPrisoner  -- legacy alias for archived human-sale saves/mods

---------------------------------------------------------------------------
-- Cloning vat
---------------------------------------------------------------------------

local function cloningVatSystem(dt, id, comps)
    local vat = comps.cloning_vat
    local pos = comps.pos

    if not vat.active then return end

    lazyLoadRecruitment()
    if _Power then
        local powered = _Power.isConsumerPowered(id)
        if not powered then
            vat.active = false
            return
        end
    end

    vat.progress = vat.progress + dt

    if vat.progress >= CLONE_GROW_TIME then
        vat.progress = 0
        vat.active = false
        vat.grown = (vat.grown or 0) + 1

        local Colonist = require('src.colonist.colonist')
        local World = require('src.world.tilemap')

        local sx, sy = pos.x, pos.y
        for dx = -2, 2 do
            for dy = -2, 2 do
                if World.inBounds(sx + dx, sy + dy) and World.isWalkable(sx + dx, sy + dy, pos.depth or 0) then
                    local newId = Colonist.spawn(sx + dx, sy + dy)
                    if newId then
                        local col = ECS.get(newId, 'colonist')
                        if col then
                            col.backstory = 'Vat-grown colonist. No memories of a former life.'
                        end
                        Hope.applyDelta(2, 0)
                    end
                    return
                end
            end
        end
    end
end

function Recruitment.startClone(vatEntityId)
    local vat = ECS.get(vatEntityId, 'cloning_vat')
    if not vat then return false, 'Not a cloning vat' end
    if vat.active then return false, 'Already growing' end

    if (GameState.resources.food or 0) < CLONE_FOOD_COST then
        return false, 'Need ' .. CLONE_FOOD_COST .. ' food'
    end
    if (GameState.resources.components or 0) < CLONE_COMP_COST then
        return false, 'Need ' .. CLONE_COMP_COST .. ' components'
    end

    local SNet = getStorageNet()
    local vatPos = ECS.get(vatEntityId, 'pos')
    local vx = vatPos and vatPos.x or GameState.startX
    local vy = vatPos and vatPos.y or GameState.startY
    if SNet then
        SNet.withdraw('food', CLONE_FOOD_COST, vx, vy)
        SNet.withdraw('components', CLONE_COMP_COST, vx, vy)
    else
        GameState.spendResource('food', CLONE_FOOD_COST)
        GameState.spendResource('components', CLONE_COMP_COST)
    end

    vat.active = true
    vat.progress = 0
    return true
end

---------------------------------------------------------------------------
-- Radio beacon
---------------------------------------------------------------------------

local function radioBeaconSystem(dt, id, comps)
    local beacon = comps.radio_beacon

    lazyLoadRecruitment()
    if _Power then
        beacon.powered = _Power.isConsumerPowered(id)
    end
    if not beacon.powered then return end

    beacon.timer = beacon.timer - dt
    if beacon.timer <= 0 then
        beacon.timer = BEACON_ATTRACT_INTERVAL
        if math.random() < BEACON_ATTRACT_CHANCE then
            Recruitment.spawnRefugees(1)
        end
    end
end

---------------------------------------------------------------------------
-- Step — non-ECS per-tick logic (prison break checks)
---------------------------------------------------------------------------

function Recruitment.step(dt)
    prisonBreakCheck(dt)
end

---------------------------------------------------------------------------
-- Register ECS systems
---------------------------------------------------------------------------

function Recruitment.registerSystems()
    ECS.addSystem('prisoner_recruit', { 'prisoner', 'pos' }, prisonerSystem, 45)
    ECS.addSystem('cloning_vat', { 'cloning_vat', 'pos' }, cloningVatSystem, 46)
    ECS.addSystem('radio_beacon', { 'radio_beacon', 'pos' }, radioBeaconSystem, 47)
end

Recruitment.registerSystems()

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Recruitment.getPrisoners()
    local list = {}
    for id, comps in ECS.query('prisoner', 'pos') do
        local p = comps.prisoner
        list[#list + 1] = {
            id             = id,
            name           = p.name,
            resistance     = p.resistance,
            mood           = p.mood,
            phase          = p.phase,
            recruitChance  = p.recruitChance,
            fed            = p.fed,
            health         = p.health,
            wounded        = p.wounded,
            pos            = comps.pos,
        }
    end
    return list
end

function Recruitment.getPrisonerCount()
    return ECS.countWith('prisoner')
end

function Recruitment.getCloneProgress(vatEntityId)
    local vat = ECS.get(vatEntityId, 'cloning_vat')
    if not vat then return 0 end
    return vat.progress / CLONE_GROW_TIME
end

---------------------------------------------------------------------------
-- Execute a prisoner
---------------------------------------------------------------------------

function Recruitment.executePrisoner(prisonerId)
    local prisoner = ECS.get(prisonerId, 'prisoner')
    if not prisoner then return false end

    -- Faction rep hit
    if prisoner.factionId then
        local fok, FactionsMod = pcall(require, 'src.colony.factions')
        if fok then FactionsMod.onPrisonerExecuted(prisoner.factionId) end
    end

    local pos = ECS.get(prisonerId, 'pos')

    -- Drop human corpse for butchering
    GameState.resources.corpse_human = (GameState.resources.corpse_human or 0) + 1

    -- Colony consequences
    Hope.applyDelta(-8, 5)
    for cid, comps in ECS.query('colonist', 'needs') do
        comps.needs.morale = math.max(0, comps.needs.morale - 10)
    end

    local hok2, Hope2 = pcall(require, 'src.colony.hope')
    if hok2 and Hope2.onDarkAction then
        Hope2.onDarkAction('execution')
    end

    ECS.destroy(prisonerId)
    return true
end

---------------------------------------------------------------------------
-- Butcher a prisoner (extreme dark action — produces corpse for processing)
---------------------------------------------------------------------------

function Recruitment.butcherPrisoner(prisonerId)
    local prisoner = ECS.get(prisonerId, 'prisoner')
    if not prisoner then return false end

    -- Faction rep hit (worst dark action)
    if prisoner.factionId then
        local fok, FactionsMod = pcall(require, 'src.colony.factions')
        if fok then FactionsMod.onPrisonerButchered(prisoner.factionId) end
    end

    GameState.resources.corpse_human = (GameState.resources.corpse_human or 0) + 1

    Hope.applyDelta(-10, 8)
    for cid, comps in ECS.query('colonist', 'needs') do
        comps.needs.morale = math.max(0, comps.needs.morale - 20)
    end

    local hok, HopeMod = pcall(require, 'src.colony.hope')
    if hok and HopeMod.onDarkAction then
        HopeMod.onDarkAction('butcher_human')
    end

    ECS.destroy(prisonerId)
    return true
end

---------------------------------------------------------------------------
-- Harvest organs from a prisoner (requires surgery table + doctor)
---------------------------------------------------------------------------

function Recruitment.harvestOrgan(prisonerId, organId, surgeryTableId)
    local sok, Surgery = pcall(require, 'src.medical.surgery')
    if not sok then return false, 'Surgery system not loaded' end

    local opId = 'harvest_' .. organId:gsub('organ_', '')
    return Surgery.queueOperation(surgeryTableId, opId, prisonerId)
end

---------------------------------------------------------------------------
-- Interrogate a prisoner for intel (raid info, loot stash locations)
---------------------------------------------------------------------------

function Recruitment.interrogate(prisonerId, warderId)
    local prisoner = ECS.get(prisonerId, 'prisoner')
    if not prisoner then return false, 'Not a prisoner' end

    -- Warden social/hunting skill determines success
    local warderCol = warderId and ECS.get(warderId, 'colonist')
    local skill = 1
    if warderCol and warderCol.skills then
        skill = math.max(warderCol.skills.hunting or 1, warderCol.skills.medical or 1)
    end

    -- Cooldown: one interrogation per 120 sim seconds
    if prisoner._lastInterrogation then
        local elapsed = (GameState.day + GameState.hour / 24) - prisoner._lastInterrogation
        if elapsed < 0.08 then return false, 'Too soon' end  -- ~2 hours game time
    end
    prisoner._lastInterrogation = GameState.day + GameState.hour / 24

    -- Success chance: 20% base + 5% per skill level, capped at 80%
    local chance = math.min(0.80, 0.20 + skill * 0.05)

    -- Prisoner mood affects willingness: low mood = easier to break
    local moodMult = 1.0 + (50 - (prisoner.mood or 40)) * 0.01
    chance = math.min(0.90, chance * moodMult)

    -- Prisoner takes morale damage from interrogation
    prisoner.mood = math.max(0, (prisoner.mood or 40) - 8)

    if math.random() > chance then
        -- Award partial XP even on failure
        local sok, Skills = pcall(require, 'src.colonist.skills')
        if sok and warderId then Skills.addXp(warderId, 'hunting', 5) end
        return false, 'Prisoner revealed nothing'
    end

    -- Success: roll intel type
    local roll = math.random(4)
    local intel
    if roll == 1 then
        -- Raid warning: delays next raid
        local rok, Raids = pcall(require, 'src.sim.raids')
        if rok and Raids.delayNextRaid then Raids.delayNextRaid(300) end
        intel = 'Next raid delayed'
    elseif roll == 2 then
        -- Resource stash: gain random resources near prisoner position
        local ppos = ECS.get(prisonerId, 'pos')
        local px = ppos and ppos.x or GameState.startX
        local py = ppos and ppos.y or GameState.startY
        local amounts = { metal = 5, components = 2, thermalCores = 1 }
        local Items = getItems()
        for res, amt in pairs(amounts) do
            if math.random() < 0.5 then
                local total = amt + math.floor(skill / 3)
                if Items then Items.spawn(px, py, res, total, nil, 0)
                else GameState.addResource(res, total) end
            end
        end
        intel = 'Revealed resource stash'
    elseif roll == 3 then
        -- Map intel: bonus resources
        local Items = getItems()
        if Items then Items.spawn(GameState.startX, GameState.startY, 'components', 2, nil, 0)
        else GameState.resources.components = (GameState.resources.components or 0) + 2 end
        intel = 'Revealed hidden supply cache'
    else
        -- Faction info: bonus thermal cores
        local Items = getItems()
        if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', 1, nil, 0)
        else GameState.resources.thermalCores = (GameState.resources.thermalCores or 0) + 1 end
        intel = 'Faction intelligence gathered'
    end

    -- Award XP
    local sok2, Skills2 = pcall(require, 'src.colonist.skills')
    if sok2 and warderId then Skills2.addXp(warderId, 'hunting', 15) end

    -- Colony hope penalty (interrogation is a dark action)
    local hok, HopeMod = pcall(require, 'src.colony.hope')
    if hok then HopeMod.applyDelta(-2, 3) end

    return true, intel
end

---------------------------------------------------------------------------
-- Release a prisoner (faction rep bonus)
---------------------------------------------------------------------------

function Recruitment.releasePrisoner(prisonerId)
    local prisoner = ECS.get(prisonerId, 'prisoner')
    if not prisoner then return false end

    -- Faction rep recovery for releasing their member
    if prisoner.factionId then
        local fok, FactionsMod = pcall(require, 'src.colony.factions')
        if fok then FactionsMod.onPrisonerReleased(prisoner.factionId) end
    end

    -- Faction goodwill bonus: thermal cores as reward
    local Items = getItems()
    if Items then Items.spawn(GameState.startX, GameState.startY, 'thermalCores', 2, nil, 0)
    else GameState.resources.thermalCores = (GameState.resources.thermalCores or 0) + 2 end

    -- Small hope bonus
    local hok, HopeMod = pcall(require, 'src.colony.hope')
    if hok then HopeMod.applyDelta(3, 2) end

    ECS.destroy(prisonerId)
    return true
end

---------------------------------------------------------------------------
-- Manual recruitment attempt (player-initiated via UI button)
---------------------------------------------------------------------------

function Recruitment.attemptManualRecruit(prisonerId)
    local prisoner = ECS.get(prisonerId, 'prisoner')
    if not prisoner then return false, 'Not a prisoner' end

    -- Must be in recruit phase (resistance already broken)
    if prisoner.phase ~= 'recruit' then
        return false, 'Resistance not broken (phase: ' .. (prisoner.phase or '?') .. ')'
    end

    -- Cooldown: prevent spamming (one manual attempt per 30 sim seconds)
    local now = (GameState.day or 0) + (GameState.hour or 0) / 24
    if prisoner._lastManualRecruit then
        local elapsed = now - prisoner._lastManualRecruit
        if elapsed < 0.02 then  -- ~0.5 hours game time
            return false, 'Too soon, wait before trying again'
        end
    end
    prisoner._lastManualRecruit = now

    -- Find best warden for the attempt
    local wardenId, wardenSkill = findBestWarden()
    if not wardenId then
        return false, 'No available warden'
    end

    local negotiation = 0.4 + (wardenSkill or 1) * 0.075
    local moodMult = moodMultiplier(prisoner.mood or 40)
    local chance = (prisoner.recruitChance / 100) * negotiation * moodMult
    chance = math.max(0.02, math.min(0.8, chance))

    if math.random() < chance then
        -- Success: convert prisoner to colonist
        local pos = ECS.get(prisonerId, 'pos')
        if not pos then
            ECS.destroy(prisonerId)
            return true, 'Recruited (no position)'
        end

        local Colonist = require('src.colonist.colonist')
        local newId = Colonist.spawn(pos.x, pos.y)
        if newId then
            local col = ECS.get(newId, 'colonist')
            if col then
                col.name          = prisoner.name
                col.gender        = prisoner.gender
                col.backstory     = prisoner.backstory
                col.traits        = prisoner.traits
                col.skills        = prisoner.skills
                col.health        = prisoner.health
                col.factionOrigin = prisoner.factionId
            end
            local needs = ECS.get(newId, 'needs')
            if needs then
                needs.morale = 40 + math.random(20)
            end
            Hope.applyDelta(4, -2)
        end

        -- Notify rival system if applicable
        if prisoner.isRival and prisoner.rivalId then
            lazyLoadRecruitment()
            if _RivalsMod and _RivalsMod.onRivalRecruited then
                _RivalsMod.onRivalRecruited(prisoner.rivalId)
            end
        end

        ECS.destroy(prisonerId)
        return true, 'Recruitment successful! ' .. (prisoner.name or 'Prisoner') .. ' joined the colony.'
    end

    -- Failure: prisoner mood drops slightly from pressure
    prisoner.mood = math.max(0, (prisoner.mood or 40) - 5)

    local displayChance = math.floor(chance * 100)
    return false, 'Recruitment failed (' .. displayChance .. '% chance). ' .. (prisoner.name or 'Prisoner') .. ' refused.'
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Recruitment.init()
    breakCheckTimer = 0
end

return Recruitment
