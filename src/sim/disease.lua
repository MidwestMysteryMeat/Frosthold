-- disease.lua -- Disease and immunity race system
-- Three diseases: frostlung, blackrot, ice_plague.
-- Core mechanic: severity vs immunity race to 100. First to 100 wins.
-- Severity 100 + lethal = death. Immunity 100 = cured + recovery buff.
-- Treatment reduces severity rate and boosts immunity gain.
-- Runs as ECS system at priority 11 (after needs decay at 10).

local ECS        = require('src.ecs.ecs')
local GameState  = require('src.game_state')
local Jobs       = require('src.colonist.jobs')

local Disease = {}

---------------------------------------------------------------------------
-- Disease definitions
---------------------------------------------------------------------------

local DISEASES = {
    frostlung = {
        name           = 'Frostlung',
        desc           = 'Fluid buildup in the lungs from prolonged cold exposure. Slows work, reduces cold resistance.',
        severityRate   = 0.0025,    -- per second (~0.15 per game-minute)
        treatedSevMult = 0.33,
        immunityRate   = 0.0033,    -- per second base
        symptoms       = { workSpeedMult = 0.7, moraleDrain = 0.02, coldResistMod = -0.2 },
        lethal         = true,
    },
    blackrot = {
        name           = 'Blackrot',
        desc           = 'Tissue necrosis from contaminated wounds. Drains health and causes pain.',
        severityRate   = 0.0042,
        treatedSevMult = 0.25,
        immunityRate   = 0.003,
        symptoms       = { workSpeedMult = 0.5, healthDrain = 0.1, painMod = 0.3 },
        lethal         = true,
    },
    ice_plague = {
        name           = 'Ice Plague',
        desc           = 'Crystalline infection native to Erebus. Spreads through breath and contact. Kills slow.',
        severityRate   = 0.0017,
        treatedSevMult = 0.30,
        immunityRate   = 0.002,
        symptoms       = {
            workSpeedMult   = 0.6,
            moraleDrain     = 0.05,
            contagious      = true,
            contagionRadius = 3,
            contagionChance = 0.001,
        },
        lethal = true,
    },
}

Disease.DISEASES = DISEASES

---------------------------------------------------------------------------
-- Recovery immunity tracking (disease id -> expiry game-day)
-- Stored per-entity on the 'diseaseImmunity' component:
--   { [diseaseId] = expiryDay }
---------------------------------------------------------------------------

-- Treatment expiry duration in game-seconds (1 game-day = 60 real seconds
-- at 1x speed per hour * 24 hours = 1440 real seconds at 1x).
local TREATMENT_DURATION = 1440   -- 1 game-day in seconds at 1x
local RECOVERY_MORALE    = 10
local RECOVERY_DAYS      = 2      -- game-days of recovery buff
local REINFECTION_DAYS   = 5      -- game-days of same-disease immunity

local function getDiseasePressure()
    return math.max(0.5, math.min(1.5, GameState.diseasePressure or 1.0))
end

---------------------------------------------------------------------------
-- Infect a colonist with a disease
---------------------------------------------------------------------------

function Disease.infect(colonistId, diseaseId)
    if not ECS.isAlive(colonistId) then return false end

    local def = DISEASES[diseaseId]
    if not def then return false end

    local col = ECS.get(colonistId, 'colonist')
    if not col or col.state == 'dead' then return false end

    -- Plague doctor mastery: immune to disease
    local pskOk, PSkills = pcall(require, 'src.colonist.skills')
    if pskOk and PSkills.hasMastery(colonistId, 'plague_doctor') then
        local eff = PSkills.getMasteryEffect(colonistId, 'plague_doctor')
        if eff and eff.diseaseImmune then return false end
    end

    -- One disease at a time
    if ECS.has(colonistId, 'disease') then return false end

    -- Check reinfection immunity
    local immunity = ECS.get(colonistId, 'diseaseImmunity')
    if immunity and immunity[diseaseId] then
        if GameState.day < immunity[diseaseId] then
            return false
        end
        immunity[diseaseId] = nil
    end

    ECS.set(colonistId, 'disease', {
        id              = diseaseId,
        def             = def,
        severity        = 1,      -- start at 1% so it's visible immediately
        immunity        = 0,
        treated         = false,
        treatmentTimer  = 0,      -- seconds remaining on current treatment
        medicineQuality = 0,      -- 0=none, 1=herbal, 2=industrial, 3=advanced
        doctorSkill     = 0,      -- medical skill of treating doctor
        age             = 0,      -- seconds since contraction
    })

    -- Toast notification
    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk and Storyteller.logEvent then
        local name = col.name or 'A colonist'
        Storyteller.logEvent('disease', name .. ' has contracted ' .. (def.name or diseaseId) .. '.')
    end

    return true
end

---------------------------------------------------------------------------
-- Infect N random healthy colonists (storyteller API)
---------------------------------------------------------------------------

function Disease.infectRandom(diseaseId, count)
    count = count or 1
    local candidates = {}
    for id, comps in ECS.query('colonist') do
        local col = comps.colonist
        if col.state ~= 'dead' and not ECS.has(id, 'disease') then
            -- Check reinfection immunity
            local imm = ECS.get(id, 'diseaseImmunity')
            local blocked = false
            if imm and imm[diseaseId] and GameState.day < imm[diseaseId] then
                blocked = true
            end
            if not blocked then
                candidates[#candidates + 1] = id
            end
        end
    end

    -- Shuffle and pick up to count
    local infected = 0
    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end
    for i = 1, math.min(count, #candidates) do
        if Disease.infect(candidates[i], diseaseId) then
            infected = infected + 1
        end
    end
    return infected
end

---------------------------------------------------------------------------
-- Query API
---------------------------------------------------------------------------

function Disease.getDiseaseInfo(colonistId)
    return ECS.get(colonistId, 'disease')
end

function Disease.getWorkSpeedMult(colonistId)
    local d = ECS.get(colonistId, 'disease')
    if not d then return 1.0 end
    return d.def.symptoms.workSpeedMult or 1.0
end

function Disease.isContagious(colonistId)
    local d = ECS.get(colonistId, 'disease')
    if not d then return false end
    return d.def.symptoms.contagious == true
end

---------------------------------------------------------------------------
-- Treat a sick colonist (called when medical task completes on them)
---------------------------------------------------------------------------

function Disease.treat(colonistId, doctorSkill, medicineQuality)
    local d = ECS.get(colonistId, 'disease')
    if not d then return false end

    d.treated         = true
    d.treatmentTimer  = TREATMENT_DURATION
    d.doctorSkill     = math.max(d.doctorSkill, doctorSkill or 0)
    d.medicineQuality = math.max(d.medicineQuality, medicineQuality or 0)
    return true
end

---------------------------------------------------------------------------
-- Internal: compute severity rate for this tick
---------------------------------------------------------------------------

local function getSeverityRate(d, colonistId)
    local rate = d.def.severityRate * getDiseasePressure()

    -- Treatment reduces severity rate
    if d.treated then
        rate = rate * d.def.treatedSevMult
    end

    -- Low O2 increases severity by 50%
    local atmOk, Atmosphere = pcall(require, 'src.sim.atmosphere')
    if atmOk then
        local pos = ECS.get(colonistId, 'pos')
        if pos then
            local o2 = Atmosphere.getTileO2(pos.x, pos.y, pos.depth or 0)
            if o2 < 60 then
                rate = rate * 1.5
            end
        end
    end

    return rate
end

---------------------------------------------------------------------------
-- Internal: compute immunity rate for this tick
---------------------------------------------------------------------------

local function getImmunityRate(d, colonistId)
    local rate = d.def.immunityRate

    -- Resting in bed: +30%
    local col = ECS.get(colonistId, 'colonist')
    local inBed = col and (col.state == 'sleeping' or col.state == 'going_to_bed')
    if inBed then
        rate = rate * 1.3
    end

    -- Bed quality >= 2: +20%
    if inBed and col._bedId and ECS.isAlive(col._bedId) then
        local bed = ECS.get(col._bedId, 'bed')
        if bed and bed.quality >= 2 then
            rate = rate * 1.2
        end
    end

    -- Medicine quality: herbal=0%, industrial=25%, advanced=50%
    local medBonus = 0
    if d.medicineQuality == 2 then
        medBonus = 0.25
    elseif d.medicineQuality >= 3 then
        medBonus = 0.50
    end
    rate = rate * (1 + medBonus)

    -- Age penalty: -20% per decade above 40
    -- Read age from colonist component if present, default to 30
    local age = (col and col.age) or 30
    if age > 40 then
        local decades = math.floor((age - 40) / 10)
        local penalty = decades * 0.20
        rate = rate * math.max(0.1, 1 - penalty)
    end

    -- Doctor skill: +5% per level
    if d.doctorSkill > 0 then
        rate = rate * (1 + d.doctorSkill * 0.05)
    end

    -- Trait immuneMod: naturally_immune +20%, sickly -20%
    if col and col.traits then
        local immuneMod = 0
        for _, t in ipairs(col.traits) do
            if t.immuneMod then immuneMod = immuneMod + t.immuneMod end
        end
        if immuneMod ~= 0 then
            rate = rate * (1 + immuneMod)
        end
    end

    return rate
end

---------------------------------------------------------------------------
-- Internal: cure a colonist (immunity won the race)
---------------------------------------------------------------------------

local function cureDisease(id, d)
    local diseaseId = d.id

    -- Remove disease component
    ECS.remove(id, 'disease')

    -- Apply recovery buff: +morale, reinfection immunity
    local needs = ECS.get(id, 'needs')
    if needs then
        needs.morale = math.min(100, needs.morale + RECOVERY_MORALE)
    end

    -- Set recovering flag on colonist
    local col = ECS.get(id, 'colonist')
    if col then
        col._recovering      = true
        col._recoverExpiry   = GameState.day + RECOVERY_DAYS
    end

    -- Grant reinfection immunity
    local imm = ECS.get(id, 'diseaseImmunity')
    if not imm then
        imm = {}
        ECS.set(id, 'diseaseImmunity', imm)
    end
    imm[diseaseId] = GameState.day + REINFECTION_DAYS

    -- Scar trait: disease recovery
    local scarOk, ScarTraits = pcall(require, 'src.colonist.scar_traits')
    if scarOk then ScarTraits.onDiseaseRecovery(id) end

    -- Notify storyteller
    local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if stOk and Storyteller.logEvent and col then
        local diseaseName = (DISEASES[diseaseId] and DISEASES[diseaseId].name) or diseaseId
        Storyteller.logEvent('disease_cured', (col.name or 'A colonist') .. ' recovered from ' .. diseaseName .. '.')
    end
end

---------------------------------------------------------------------------
-- Internal: kill a colonist from disease
---------------------------------------------------------------------------

local function killFromDisease(id, d)
    local cOk, ColMod = pcall(require, 'src.colonist.colonist')
    if cOk then ColMod.kill(id) end
end

---------------------------------------------------------------------------
-- ECS system: disease tick (severity/immunity race, symptoms)
---------------------------------------------------------------------------

local function diseaseTickSystem(dt, id, comps)
    local col = comps.colonist
    local d   = comps.disease

    if col.state == 'dead' then return end

    d.age = d.age + dt

    -- Treatment timer countdown
    if d.treated then
        d.treatmentTimer = d.treatmentTimer - dt
        if d.treatmentTimer <= 0 then
            d.treated         = false
            d.treatmentTimer  = 0
            d.medicineQuality = 0
            d.doctorSkill     = 0
        end
    end

    -- Severity advances
    local sevRate = getSeverityRate(d, id)
    d.severity = d.severity + sevRate * dt * 100

    -- Immunity advances
    local immRate = getImmunityRate(d, id)
    d.immunity = d.immunity + immRate * dt * 100

    -- Clamp
    d.severity = math.min(100, d.severity)
    d.immunity = math.min(100, d.immunity)

    -- Check race outcome: immunity wins ties
    if d.immunity >= 100 then
        cureDisease(id, d)
        return
    end

    if d.severity >= 100 and d.def.lethal then
        killFromDisease(id, d)
        return
    end

    -- Apply symptoms
    local symptoms = d.def.symptoms
    local needs = ECS.get(id, 'needs')

    -- Morale drain
    if symptoms.moraleDrain and symptoms.moraleDrain > 0 and needs then
        needs.morale = math.max(0, needs.morale - symptoms.moraleDrain * dt)
    end

    -- Health drain (blackrot)
    if symptoms.healthDrain and symptoms.healthDrain > 0 then
        col.health = math.max(0, col.health - symptoms.healthDrain * dt)
        if col.health <= 0 and col.state ~= 'dead' then
            killFromDisease(id, d)
            return
        end
    end

    -- Vomiting from high severity (creates filth)
    if d.severity > 40 then
        local vomitChance = 0.002 * (d.severity / 100) * dt
        if math.random() < vomitChance then
            local pos = ECS.get(id, 'pos')
            if pos then
                local filthOk, FilthMod = pcall(require, 'src.sim.filth')
                if filthOk then FilthMod.onVomit(pos.x, pos.y) end
            end
        end
    end

    -- Contagion spread (ice_plague)
    if symptoms.contagious then
        local pos = ECS.get(id, 'pos')
        if pos then
            local radius = symptoms.contagionRadius or 3
            local chance = (symptoms.contagionChance or 0.001) * getDiseasePressure()
            for nid, ncomps in ECS.query('colonist', 'pos') do
                if nid ~= id and ncomps.colonist.state ~= 'dead' and (ncomps.pos.depth or 0) == (pos.depth or 0) then
                    local dx = math.abs(ncomps.pos.x - pos.x)
                    local dy = math.abs(ncomps.pos.y - pos.y)
                    if dx <= radius and dy <= radius then
                        if math.random() < chance * dt then
                            Disease.infect(nid, d.id)
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- ECS system: frostlung contraction check (healthy colonists in cold)
---------------------------------------------------------------------------

local function frostlungContractionSystem(dt, id, comps)
    local col   = comps.colonist
    local needs = comps.needs

    if col.state == 'dead' then return end
    if ECS.has(id, 'disease') then return end

    -- Only check warmth-based contraction
    if needs.warmth >= 20 then return end

    -- 0.5% per second when warmth < 20, 2% when warmth < 5
    local chance
    if needs.warmth < 5 then
        chance = 0.02
    else
        chance = 0.005
    end
    chance = chance * getDiseasePressure()

    if math.random() < chance * dt then
        Disease.infect(id, 'frostlung')
    end
end

---------------------------------------------------------------------------
-- ECS system: blackrot contraction from untreated wounds
-- 20% chance per game-day per untreated wound
---------------------------------------------------------------------------

local function blackrotContractionSystem(dt, id, comps)
    local col = comps.colonist

    if col.state == 'dead' then return end
    if ECS.has(id, 'disease') then return end

    -- Throttle: only check every 100 sim ticks (~5 seconds at 20Hz)
    if GameState.simTick % 100 ~= 0 then return end

    local wok, Wounds = pcall(require, 'src.combat.wounds')
    if not wok then return end

    local wounds = ECS.get(id, 'wounds')
    if not wounds then return end

    -- Count untreated wounds
    local untreated = 0
    for _, w in ipairs(wounds.list) do
        if w.treatment == 'untreated' then
            untreated = untreated + 1
        end
    end

    if untreated == 0 then return end

    -- 20% per game-day per wound. Convert to chance per 5-second check.
    -- 1 game-day = 1440 seconds at 1x. Check interval = 5 seconds.
    -- Chance per check = 0.20 * 5 / 1440 per wound
    local chancePerCheck = (0.20 * 5 / 1440) * getDiseasePressure()
    for _ = 1, untreated do
        if math.random() < chancePerCheck then
            Disease.infect(id, 'blackrot')
            return
        end
    end
end

---------------------------------------------------------------------------
-- ECS system: auto-create medical tasks for diseased colonists
---------------------------------------------------------------------------

local function diseaseMedicalTaskSystem(dt, id, comps)
    -- Throttle: every 100 sim ticks (~5 seconds)
    if GameState.simTick % 100 ~= 0 then return end

    local col = comps.colonist
    local d   = comps.disease

    if col.state == 'dead' then return end

    -- Only request treatment if not currently treated
    if d.treated then return end

    local pos = ECS.get(id, 'pos')
    if not pos then return end

    -- Check if a medical task already exists for this patient
    local allTasks = Jobs.getAllTasks()
    for _, task in pairs(allTasks) do
        if task.type == 'medical' and task.data.patientId == id then
            return
        end
    end

    Jobs.createTask('medical', pos.x, pos.y, {
        patientId    = id,
        diseaseTask  = true,
    })
end

---------------------------------------------------------------------------
-- ECS system: clear expired recovery buffs
---------------------------------------------------------------------------

local function recoveryCleanupSystem(dt, id, comps)
    local col = comps.colonist
    if not col._recovering then return end
    if GameState.day >= (col._recoverExpiry or 0) then
        col._recovering    = nil
        col._recoverExpiry = nil
    end
end

---------------------------------------------------------------------------
-- Register all disease systems with ECS
---------------------------------------------------------------------------

function Disease.registerSystems()
    -- Disease tick: severity/immunity race + symptoms (priority 11, alongside wound tick)
    ECS.addSystem('disease_tick',
        { 'colonist', 'disease' },
        diseaseTickSystem, 11)

    -- Frostlung contraction: cold exposure check
    ECS.addSystem('frostlung_contraction',
        { 'colonist', 'needs' },
        frostlungContractionSystem, 12)

    -- Blackrot contraction: untreated wound infection
    ECS.addSystem('blackrot_contraction',
        { 'colonist', 'wounds' },
        blackrotContractionSystem, 12)

    -- Auto-create medical tasks for diseased colonists
    ECS.addSystem('disease_medical_task',
        { 'colonist', 'disease' },
        diseaseMedicalTaskSystem, 50)

    -- Recovery buff cleanup
    ECS.addSystem('disease_recovery_cleanup',
        { 'colonist' },
        recoveryCleanupSystem, 51)
end

-- Auto-register on require
Disease.registerSystems()

return Disease
