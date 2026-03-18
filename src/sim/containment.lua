local ECS = require('src.ecs.ecs')
local GameState = require('src.game_state')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end

local Containment = {}

local CELL_MODES = { 'study', 'stabilize', 'extract' }

Containment.CELL_MODES = CELL_MODES

local SUBJECT_TEMPLATES = {
    resonant_shard = {
        kind = 'artifact',
        subtype = 'resonant_shard',
        label = 'Resonant Shard',
        desc = 'A broken precursor shard that answers heat with whispers.',
        instability = 28,
        researchValue = 55,
        anomalyLeak = 0.03,
        tempMin = -20,
        tempMax = 5,
        preferredCell = 'locker',
        extractYield = { void_crystal = 1, components = 1 },
    },
    signal_idol = {
        kind = 'artifact',
        subtype = 'signal_idol',
        label = 'Signal Idol',
        desc = 'A humming idol that keeps answering channels nobody opened.',
        instability = 42,
        researchValue = 85,
        anomalyLeak = 0.05,
        tempMin = -15,
        tempMax = 2,
        preferredCell = 'locker',
        extractYield = { void_crystal = 2, components = 2, thermalCores = 1 },
    },
    mimic_tissue = {
        kind = 'sample',
        subtype = 'mimic_tissue',
        label = 'Mimic Tissue',
        desc = 'Warm tissue that keeps trying to remember the shape of a face.',
        instability = 36,
        researchValue = 65,
        anomalyLeak = 0.04,
        tempMin = -10,
        tempMax = 4,
        preferredCell = 'locker',
        extractYield = { eldritch_ichor = 2, caustic_liquid = 1 },
    },
    node_sample = {
        kind = 'sample',
        subtype = 'node_sample',
        label = 'Node Sample',
        desc = 'Fibrous growth taken from a living Erebus node.',
        instability = 30,
        researchValue = 70,
        anomalyLeak = 0.04,
        tempMin = -8,
        tempMax = 8,
        preferredCell = 'locker',
        extractYield = { eldritch_ichor = 2, chitin_plate = 1 },
    },
    latent_survivor = {
        kind = 'human',
        subtype = 'latent',
        label = 'Latent Survivor',
        desc = 'Looks human. Talks like a survivor. Pauses too long before answering.',
        instability = 32,
        researchValue = 55,
        anomalyLeak = 0.04,
        tempMin = -5,
        tempMax = 12,
        preferredCell = 'cell',
        extractYield = { eldritch_ichor = 1 },
        canAdmit = true,
    },
    thrall_prisoner = {
        kind = 'human',
        subtype = 'thrall',
        label = 'Erebus Thrall',
        desc = 'A person bent into service by the thing below the ice.',
        instability = 48,
        researchValue = 75,
        anomalyLeak = 0.06,
        tempMin = -10,
        tempMax = 10,
        preferredCell = 'cell',
        extractYield = { eldritch_ichor = 2, void_crystal = 1 },
    },
    vessel_host = {
        kind = 'human',
        subtype = 'vessel',
        label = 'Vessel Host',
        desc = 'Something inside them is waiting for a pressure drop.',
        instability = 64,
        researchValue = 95,
        anomalyLeak = 0.08,
        tempMin = -15,
        tempMax = 6,
        preferredCell = 'cell',
        extractYield = { eldritch_ichor = 4, void_crystal = 1 },
    },
    herald_captive = {
        kind = 'human',
        subtype = 'herald',
        label = 'Whisper Herald',
        desc = 'Still speaks in a human voice. The voice is no longer the owner.',
        instability = 78,
        researchValue = 120,
        anomalyLeak = 0.1,
        tempMin = -20,
        tempMax = 2,
        preferredCell = 'cell',
        extractYield = { eldritch_ichor = 4, void_crystal = 2, thermalCores = 1 },
    },
}

Containment.SUBJECT_TEMPLATES = SUBJECT_TEMPLATES

local state = {
    nextSubjectId = 1,
    subjects = {},
    stats = {
        recovered = 0,
        studied = 0,
        extracted = 0,
        purged = 0,
        admitted = 0,
        transferred = 0,
        breaches = 0,
    },
    log = {},
    lastDirectiveDay = 0,
}

local MAX_LOG = 24

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function deepCopy(src)
    if type(src) ~= 'table' then return src end
    local out = {}
    for k, v in pairs(src) do
        out[k] = deepCopy(v)
    end
    return out
end

local function mergeInto(dst, src)
    if not src then return dst end
    for k, v in pairs(src) do
        if type(v) == 'table' and type(dst[k]) == 'table' then
            mergeInto(dst[k], v)
        else
            dst[k] = deepCopy(v)
        end
    end
    return dst
end

local function countSubjectsWithStatus(status)
    local n = 0
    for _, subject in pairs(state.subjects) do
        if subject.status == status then
            n = n + 1
        end
    end
    return n
end

local function sendAlert(title, body, priority, jumpX, jumpY)
    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send(title, body, priority or 'info', jumpX, jumpY)
    end
end

local function logStory(title, body)
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.logEvent then
        Storyteller.logEvent(title, body)
    end
end

local function logContainment(text, priority, jumpX, jumpY)
    state.log[#state.log + 1] = {
        day = GameState.day or 1,
        hour = GameState.hour or 0,
        text = text,
        priority = priority or 'info',
        jumpX = jumpX,
        jumpY = jumpY,
    }
    while #state.log > MAX_LOG do
        table.remove(state.log, 1)
    end
end

local function applyHope(hopeDelta, discontentDelta)
    local hok, Hope = pcall(require, 'src.colony.hope')
    if hok and Hope.applyDelta then
        Hope.applyDelta(hopeDelta or 0, discontentDelta or 0)
    end
end

local function applyMorale(delta)
    for _, comps in ECS.query('colonist', 'needs') do
        if comps.colonist.state ~= 'dead' then
            comps.needs.morale = clamp((comps.needs.morale or 50) + delta, 0, 100)
        end
    end
end

local function addAnomaly(amount)
    local aok, Anomaly = pcall(require, 'src.sim.anomaly')
    if aok and Anomaly.addAnomaly then
        Anomaly.addAnomaly(amount, 'containment')
    end
end

local function spawnCellFx(pos, kind, color, duration, endRadius)
    if not pos then return end
    local vok, VFX = pcall(require, 'src.render.vfx')
    if not vok or not VFX then return end
    VFX.spawn(kind or 'burst', pos.x, pos.y, pos.depth or 0, {
        color = color,
        radius = 0.2,
        endRadius = endRadius or 0.9,
        duration = duration or 0.35,
        width = 2,
    })
end

local function getDoctrinePath()
    local dok, Doctrines = pcall(require, 'src.colony.doctrines')
    if dok and Doctrines.getChosenPath then
        return Doctrines.getChosenPath()
    end
    return nil
end

local function chooseIdentity()
    local aok, Adlib = pcall(require, 'src.util.adlib')
    if aok and Adlib.generateColonistIdentity then
        return Adlib.generateColonistIdentity()
    end
    return {
        name = 'Recovered Survivor',
        backstory = 'Pulled from a sealed chamber below the ice.',
        traits = {},
    }
end

local function normalizeSubject(subject)
    if not subject then return nil end
    subject.status = subject.status or 'field'
    subject.instability = clamp(subject.instability or 25, 0, 100)
    subject.researchProgress = subject.researchProgress or 0
    subject.extractProgress = subject.extractProgress or 0
    subject.modeProgress = subject.modeProgress or 0
    subject.incidentTimer = subject.incidentTimer or 0
    subject.discoveredDay = subject.discoveredDay or (GameState.day or 1)
    subject.discoveredHour = subject.discoveredHour or (GameState.hour or 0)
    subject.anomalyLeak = subject.anomalyLeak or 0
    subject.researchValue = subject.researchValue or 50
    subject.tempMin = subject.tempMin or -10
    subject.tempMax = subject.tempMax or 10
    subject.extractYield = deepCopy(subject.extractYield or {})
    return subject
end

local function makeSubject(templateId, overrides)
    local base = deepCopy(SUBJECT_TEMPLATES[templateId] or {})
    local subject = mergeInto(base, overrides or {})
    subject.id = state.nextSubjectId
    state.nextSubjectId = state.nextSubjectId + 1
    if subject.kind == 'human' then
        local identity = subject.identity or chooseIdentity()
        subject.identity = identity
        subject.name = subject.name or identity.name
        subject.backstory = subject.backstory or identity.backstory
        subject.traits = subject.traits or identity.traits or {}
        subject.label = subject.label or subject.name or 'Recovered Survivor'
    end
    normalizeSubject(subject)
    state.subjects[subject.id] = subject
    return subject
end

local function getCell(id)
    if not id or not ECS.isAlive(id) then return nil end
    return ECS.get(id, 'containment_cell')
end

local function getCellPos(id)
    return id and ECS.get(id, 'pos') or nil
end

local function getSubject(subjectId)
    return subjectId and state.subjects[subjectId] or nil
end

local function countContainedSubjects()
    local n = 0
    for _, comps in ECS.query('containment_cell') do
        if comps.containment_cell.subjectId then
            n = n + 1
        end
    end
    return n
end

local function compatible(cell, subject)
    if not cell or not subject then return false end
    if cell.cellType == 'locker' then
        return subject.kind ~= 'human'
    end
    return true
end

local function getRoomEnv(cellId)
    local pos = getCellPos(cellId)
    if not pos then return nil end

    local wOk, World = pcall(require, 'src.world.tilemap')
    local rOk, Rooms = pcall(require, 'src.world.rooms')
    local aOk, Atmosphere = pcall(require, 'src.sim.atmosphere')
    local fOk, Filth = pcall(require, 'src.sim.filth')
    local pOk, Power = pcall(require, 'src.sim.power')

    local roomId = wOk and World.getRoom(pos.x, pos.y, pos.depth or 0) or 0
    local roomInfo = (rOk and roomId and roomId > 0) and Rooms.getRoomInfo(roomId) or nil
    local avgTemp = roomInfo and roomInfo.avgTemp or (wOk and World.getTemp(pos.x, pos.y, pos.depth or 0)) or -40
    local o2 = (aOk and roomId and roomId > 0 and Atmosphere.getRoomO2 and Atmosphere.getRoomO2(roomId)) or 100
    local co2 = (aOk and roomId and roomId > 0 and Atmosphere.getRoomCO2 and Atmosphere.getRoomCO2(roomId)) or 0
    local filth = 0
    if fOk and roomInfo and roomInfo.contents then
        local thOk, Thermal = pcall(require, 'src.sim.thermal')
        if thOk then
            local thermalRooms = Thermal.getRooms()
            local thermalRoom = thermalRooms[roomId]
            filth = Filth.getRoomFilth(thermalRoom and thermalRoom.tiles or {}) or 0
        end
    end

    return {
        roomId = roomId or 0,
        roomType = roomInfo and roomInfo.type or nil,
        roomTypeName = roomInfo and roomInfo.typeName or 'Room',
        sealed = roomInfo and roomInfo.sealed or false,
        avgTemp = avgTemp or -40,
        o2 = o2 or 100,
        co2 = co2 or 0,
        filth = filth or 0,
        powered = pOk and Power.isConsumerPowered and Power.isConsumerPowered(cellId) or false,
        impressiveness = roomInfo and roomInfo.impressiveness or 0,
    }
end

local function getModeLabel(mode)
    if mode == 'study' then return 'Study' end
    if mode == 'stabilize' then return 'Stabilize' end
    if mode == 'extract' then return 'Extract' end
    return mode or 'Study'
end

local function computeRisk(cellId, subject)
    if not subject then return 0, nil end
    local env = getRoomEnv(cellId)
    local risk = (subject.instability or 20) * 0.35

    if not env then
        return clamp(risk + 35, 0, 100), nil
    end

    local tempPenalty = 0
    if env.avgTemp < (subject.tempMin or -10) then
        tempPenalty = math.min(18, ((subject.tempMin or -10) - env.avgTemp) * 0.8)
    elseif env.avgTemp > (subject.tempMax or 10) then
        tempPenalty = math.min(18, (env.avgTemp - (subject.tempMax or 10)) * 0.8)
    end

    risk = risk + tempPenalty
    risk = risk + math.max(0, 80 - (env.o2 or 100)) * 0.15
    risk = risk + math.max(0, (env.co2 or 0) - 25) * 0.2
    risk = risk + math.max(0, (env.filth or 0) - 4) * 0.6

    if not env.sealed then risk = risk + 16 end
    if not env.powered then risk = risk + 12 end

    if env.roomType == 'containment_lab' then
        risk = risk - 12
    elseif env.roomType == 'hospital' and subject.kind == 'human' then
        risk = risk - 4
    elseif env.roomType == 'rec_room' or env.roomType == 'dining_hall' then
        risk = risk + 10
    end

    local cell = getCell(cellId)
    if cell and cell.mode == 'extract' then
        risk = risk + 12
    elseif cell and cell.mode == 'study' then
        risk = risk + 6
    elseif cell and cell.mode == 'stabilize' then
        risk = risk - 10
    end

    local hOk, Hermes = pcall(require, 'src.sim.hermes')
    if hOk and Hermes.getPhase then
        local phaseId = Hermes.getPhase()
        if phaseId == 'corruption' then
            risk = risk + 4
        elseif phaseId == 'rogue' then
            risk = risk + 8
        end
    end

    return clamp(risk, 0, 100), env
end

local function getPendingSubjectForCell(cell)
    if not cell then return nil end
    local preferred = {}
    local fallback = {}
    for _, subject in pairs(state.subjects) do
        if subject.status == 'field' and compatible(cell, subject) then
            if (subject.preferredCell == 'locker' and cell.cellType == 'locker')
                or (subject.preferredCell ~= 'locker' and cell.cellType ~= 'locker') then
                preferred[#preferred + 1] = subject
            else
                fallback[#fallback + 1] = subject
            end
        end
    end
    table.sort(preferred, function(a, b) return (a.instability or 0) > (b.instability or 0) end)
    table.sort(fallback, function(a, b) return (a.instability or 0) > (b.instability or 0) end)
    return preferred[1] or fallback[1]
end

local function applyDoctrineOutcome(action, subject)
    local path = getDoctrinePath()
    if not path or not subject then return end

    if action == 'purge' then
        if path == 'order' then
            applyHope(1, -1)
            applyMorale(1)
        elseif path == 'communion' then
            applyHope(-2, 2)
            applyMorale(-3)
        elseif path == 'solidarity' then
            applyHope(-1, 1)
            applyMorale(-1)
        end
    elseif action == 'study' then
        if path == 'communion' then
            applyHope(1, 0)
            applyMorale(2)
        elseif path == 'order' then
            applyMorale(-1)
        end
    elseif action == 'admit' then
        if path == 'solidarity' then
            applyHope(2, -1)
            applyMorale(2)
        elseif path == 'order' then
            applyMorale(-1)
        end
    elseif action == 'extract' then
        if path == 'order' then
            applyHope(1, 0)
        elseif path == 'solidarity' then
            applyHope(-1, 1)
            applyMorale(-2)
        end
    elseif action == 'transfer' then
        if path == 'order' then
            applyHope(1, -1)
            applyMorale(1)
        elseif path == 'communion' and subject.kind ~= 'human' then
            applyHope(1, 0)
        elseif path == 'solidarity' and subject.kind == 'human' then
            applyHope(-1, 1)
            applyMorale(-2)
        end
    end
end

local function spawnHostilesNear(subject, pos, countOverride)
    local cOk, Creatures = pcall(require, 'src.creatures.creatures')
    local wOk, World = pcall(require, 'src.world.tilemap')
    if not cOk or not wOk or not pos then return 0 end

    local pool
    if subject and subject.kind == 'human' then
        if subject.subtype == 'latent' then
            pool = { 'erebus_latent', 'erebus_thrall' }
        elseif subject.subtype == 'thrall' then
            pool = { 'erebus_thrall', 'erebus_thrall', 'erebus_vessel' }
        elseif subject.subtype == 'vessel' then
            pool = { 'erebus_vessel', 'erebus_thrall' }
        else
            pool = { 'erebus_herald', 'erebus_vessel', 'erebus_thrall' }
        end
    else
        pool = { 'erebus_thrall', 'stalker', 'fleshwalker' }
    end

    local count = countOverride or (subject and subject.kind == 'human' and 2 or 3)
    local spawned = 0
    for _ = 1, count do
        for _ = 1, 12 do
            local sx = pos.x + math.random(-4, 4)
            local sy = pos.y + math.random(-4, 4)
            if World.inBounds(sx, sy) and World.isWalkable(sx, sy, pos.depth or 0) then
                local species = pool[math.random(#pool)]
                local id = Creatures.spawn(species, sx, sy, pos.depth or 0)
                if id then
                    local cr = ECS.get(id, 'creature')
                    if cr then
                        cr.hostile = true
                        cr.leashRange = 999
                        cr.aggroRange = 20
                    end
                    spawned = spawned + 1
                end
                break
            end
        end
    end
    return spawned
end

local function clearSubjectFromCell(cell)
    if not cell or not cell.subjectId then return end
    local subject = getSubject(cell.subjectId)
    if subject and subject.status == 'contained' then
        subject.status = 'field'
    end
    cell.subjectId = nil
end

local function triggerIncident(cellId, subject, risk, env)
    local cell = getCell(cellId)
    local pos = getCellPos(cellId)
    if not cell or not subject or not pos then return end

    state.stats.breaches = state.stats.breaches + 1
    subject.incidentTimer = 90 + math.random(60)
    cell.incidentCooldown = 180

    local roll = math.random()
    if subject.kind == 'human' and roll < 0.42 then
        local spawned = spawnHostilesNear(subject, pos, subject.subtype == 'herald' and 3 or 2)
        clearSubjectFromCell(cell)
        subject.status = 'breached'
        addAnomaly(4 + (subject.anomalyLeak or 0) * 60)
        applyMorale(-4)
        applyHope(-2, 2)
        spawnCellFx(pos, 'ring', { 0.95, 0.2, 0.24, 0.75 }, 0.7, 1.5)
        local text = string.format('%s breached containment near %d,%d. %d hostiles spilled into the colony.',
            subject.label or 'Subject', pos.x, pos.y, spawned)
        sendAlert('Containment Breach', text, 'critical', pos.x, pos.y)
        logContainment(text, 'critical', pos.x, pos.y)
        logStory('Containment Breach', text)
        return
    end

    if subject.kind ~= 'human' and roll < 0.55 then
        addAnomaly(6 + (subject.anomalyLeak or 0) * 80)
        applyMorale(-3)
        spawnCellFx(pos, 'burst', { 0.78, 0.24, 0.95, 0.6 }, 0.5, 1.1)
        local text = string.format('%s warped the air in %s. Heat and pressure readings are wrong.',
            subject.label or 'Specimen', env and env.roomTypeName or 'containment')
        sendAlert('Containment Distortion', text, 'major', pos.x, pos.y)
        logContainment(text, 'major', pos.x, pos.y)
        logStory('Containment Distortion', text)
        return
    end

    applyMorale(-2)
    addAnomaly(2 + (risk or 0) * 0.04)
    spawnCellFx(pos, 'burst', { 0.58, 0.78, 1.0, 0.45 }, 0.35, 0.85)
    local text = string.format('%s caused whispers and obsession around containment. The room needs intervention.',
        subject.label or 'Subject')
    sendAlert('Containment Event', text, 'major', pos.x, pos.y)
    logContainment(text, 'major', pos.x, pos.y)
    logStory('Containment Event', text)
end

local function awardOutputs(outputs, srcX, srcY, srcDepth)
    if not outputs then return end
    local Items = getItems()
    local ox = srcX or GameState.startX
    local oy = srcY or GameState.startY
    local od = srcDepth or 0
    for itemId, amount in pairs(outputs) do
        if Items then Items.spawn(ox, oy, itemId, amount, nil, od)
        else GameState.addResource(itemId, amount) end
    end
end

local function processStudy(cellId, cell, subject, dt, env, risk)
    local rate = dt * (env and env.powered and 1.0 or 0.35)
    if env and env.roomType == 'containment_lab' then
        rate = rate * 1.25
    end
    subject.modeProgress = subject.modeProgress + rate
    if subject.modeProgress < 30 then return end
    subject.modeProgress = subject.modeProgress - 30
    subject.researchProgress = subject.researchProgress + 1
    state.stats.studied = state.stats.studied + 1
    addAnomaly((subject.anomalyLeak or 0) * 2)

    local rOk, Research = pcall(require, 'src.research.research')
    if rOk and Research.addPoints then
        Research.addPoints(math.max(8, math.floor((subject.researchValue or 50) * 0.2)))
    end
    applyDoctrineOutcome('study', subject)

    if math.random() < math.max(0.03, risk / 900) then
        triggerIncident(cellId, subject, risk, env)
    end
end

local function processStabilize(cellId, cell, subject, dt, env, risk)
    local rate = dt * (env and env.powered and 1.2 or 0.4)
    if env and env.sealed then
        rate = rate * 1.15
    end
    subject.modeProgress = subject.modeProgress + rate
    if subject.modeProgress < 24 then return end
    subject.modeProgress = subject.modeProgress - 24
    subject.instability = clamp(subject.instability - math.max(2, math.floor((env and env.o2 or 100) / 40)), 0, 100)
    subject.researchProgress = math.max(0, subject.researchProgress - 0.25)
    addAnomaly((subject.anomalyLeak or 0) * 0.5)
    if math.random() < math.max(0.01, risk / 1600) then
        triggerIncident(cellId, subject, risk, env)
    end
end

local function processExtract(cellId, cell, subject, dt, env, risk)
    local rate = dt * (env and env.powered and 0.9 or 0.2)
    subject.modeProgress = subject.modeProgress + rate
    if subject.modeProgress < 36 then return end
    subject.modeProgress = subject.modeProgress - 36
    subject.extractProgress = subject.extractProgress + 1
    state.stats.extracted = state.stats.extracted + 1

    local outputs = deepCopy(subject.extractYield or {})
    if subject.kind == 'human' then
        outputs = outputs or {}
        outputs.eldritch_ichor = (outputs.eldritch_ichor or 0) + 1
    end
    local cellPos = ECS.get(cellId, 'pos')
    awardOutputs(outputs, cellPos and cellPos.x, cellPos and cellPos.y, cellPos and cellPos.depth)
    subject.instability = clamp(subject.instability + 3, 0, 100)
    addAnomaly(1.5 + (subject.anomalyLeak or 0) * 20)
    applyDoctrineOutcome('extract', subject)

    if math.random() < math.max(0.06, risk / 700) then
        triggerIncident(cellId, subject, risk + 10, env)
    end
end

local function stepCell(cellId, cell, dt)
    if not cell or not cell.subjectId then return end
    if cell.incidentCooldown and cell.incidentCooldown > 0 then
        cell.incidentCooldown = math.max(0, cell.incidentCooldown - dt)
    end
    local subject = getSubject(cell.subjectId)
    if not subject then
        cell.subjectId = nil
        return
    end
    local risk, env = computeRisk(cellId, subject)
    cell.currentRisk = risk
    cell.lastEnv = env
    subject.status = 'contained'
    subject.cellId = cellId
    subject.lastRisk = risk

    addAnomaly((subject.anomalyLeak or 0) * dt * (1 + risk / 200))
    subject.incidentTimer = math.max(0, (subject.incidentTimer or 0) - dt)

    if risk >= 65 and (subject.incidentTimer or 0) <= 0 and math.random() < ((risk - 55) / 1800) then
        triggerIncident(cellId, subject, risk, env)
    end

    if cell.mode == 'extract' then
        processExtract(cellId, cell, subject, dt, env, risk)
    elseif cell.mode == 'stabilize' then
        processStabilize(cellId, cell, subject, dt, env, risk)
    else
        processStudy(cellId, cell, subject, dt, env, risk)
    end
end

local function maybeSendDirective()
    if (GameState.day or 1) <= (state.lastDirectiveDay or 0) then return end
    if countContainedSubjects() == 0 then return end

    local hOk, Hermes = pcall(require, 'src.sim.hermes')
    local phase = hOk and Hermes.getPhase and Hermes.getPhase() or 'functional'
    local body
    if phase == 'rogue' then
        body = 'HERMES flags live specimens as priority assets. Preserve signal-bearing subjects and route anything articulate below.'
    elseif phase == 'corruption' then
        body = 'HERMES requests additional containment reporting. Corporate routing suggests at least one subject should be transferred intact.'
    else
        body = 'Mammona reminds the colony that non-mining discoveries remain company property. Catalog and contain anything that survives transport.'
    end
    sendAlert('Containment Directive', body, phase == 'rogue' and 'critical' or 'minor')
    logContainment(body, phase == 'rogue' and 'critical' or 'minor')
    state.lastDirectiveDay = GameState.day or 1
end

function Containment.init()
    state.nextSubjectId = 1
    state.subjects = {}
    state.stats = {
        recovered = 0,
        studied = 0,
        extracted = 0,
        purged = 0,
        admitted = 0,
        transferred = 0,
        breaches = 0,
    }
    state.log = {}
    state.lastDirectiveDay = 0
end

function Containment.registerFieldSubject(templateId, overrides)
    local subject = makeSubject(templateId, overrides)
    if not subject then return nil end
    subject.status = 'field'
    state.stats.recovered = state.stats.recovered + 1
    local source = overrides and overrides.source or 'field recovery'
    local label = subject.label or subject.name or 'Specimen'
    local text = string.format('%s recovered from %s. Quarantine or destroy it before it gets ideas.', label, source)
    sendAlert('Recovered Subject', text, subject.kind == 'human' and 'major' or 'minor')
    logContainment(text, subject.kind == 'human' and 'major' or 'minor')
    logStory('Recovered Subject', text)
    return subject
end

function Containment.getSubject(subjectId)
    return getSubject(subjectId)
end

function Containment.getSubjects()
    return state.subjects
end

function Containment.getStats()
    return state.stats
end

function Containment.getLog()
    return state.log
end

function Containment.getSubjectInterest()
    local interest = 0
    for _, subject in pairs(state.subjects) do
        if subject.status == 'field' or subject.status == 'contained' then
            interest = interest + (subject.researchValue or 30) * 0.12 + (subject.instability or 0) * 0.35
        end
    end
    return math.floor(interest)
end

function Containment.hasPendingSubjects()
    return countSubjectsWithStatus('field') > 0
end

function Containment.getStatusSummary()
    local pending = countSubjectsWithStatus('field')
    local housed = countContainedSubjects()
    local highest = Containment.getHighestRisk()
    return string.format('Containment: %d pending, %d housed, highest risk %.0f%%', pending, housed, highest)
end

function Containment.getHighestRisk()
    local highest = 0
    for id, comps in ECS.query('containment_cell') do
        if comps.containment_cell.subjectId then
            local risk = select(1, computeRisk(id, getSubject(comps.containment_cell.subjectId)))
            highest = math.max(highest, risk or 0)
        end
    end
    return highest
end

function Containment.assignNextSubject(cellId)
    local cell = getCell(cellId)
    if not cell then return false, 'No containment component' end
    if cell.subjectId then return false, 'Cell already occupied' end

    local subject = getPendingSubjectForCell(cell)
    if not subject then
        return false, 'No compatible field subjects'
    end

    cell.subjectId = subject.id
    cell.mode = cell.mode or 'study'
    cell.currentRisk = 0
    subject.status = 'contained'
    subject.cellId = cellId
    subject.modeProgress = 0
    local pos = getCellPos(cellId)
    local text = string.format('%s moved into %s.', subject.label or 'Specimen', cell.cellType == 'locker' and 'anomaly locker' or 'containment cell')
    logContainment(text, 'info', pos and pos.x, pos and pos.y)
    return true
end

function Containment.cycleMode(cellId)
    local cell = getCell(cellId)
    if not cell then return false, 'No containment component' end
    local idx = 1
    for i, mode in ipairs(CELL_MODES) do
        if mode == (cell.mode or 'study') then
            idx = i
            break
        end
    end
    cell.mode = CELL_MODES[(idx % #CELL_MODES) + 1]
    return true, cell.mode
end

function Containment.canAdmit(subjectId)
    local subject = getSubject(subjectId)
    return subject and subject.kind == 'human' and subject.canAdmit and (subject.instability or 0) <= 50
end

function Containment.canTransfer(subjectId)
    local subject = getSubject(subjectId)
    if not subject then
        return false, 'No subject assigned'
    end
    if subject.kind == 'human' and (subject.instability or 0) > 60 then
        return false, 'Subject is too unstable for intact transfer'
    end
    return true
end

function Containment.admitSubject(cellId)
    local cell = getCell(cellId)
    local subject = cell and getSubject(cell.subjectId)
    if not cell or not subject then return false, 'No subject assigned' end
    if not Containment.canAdmit(subject.id) then
        return false, 'Subject is not stable enough to admit'
    end

    local pos = getCellPos(cellId)
    local cOk, Colonist = pcall(require, 'src.colonist.colonist')
    if not cOk or not Colonist.spawn then
        return false, 'Colonist system unavailable'
    end

    local colonistId = Colonist.spawn((pos and pos.x or GameState.startX) + 1, pos and pos.y or GameState.startY)
    local col = colonistId and ECS.get(colonistId, 'colonist') or nil
    if col then
        col.name = subject.name or col.name
        col.backstory = subject.backstory or col.backstory
        col.traits = subject.traits or col.traits
        col._erebusTouched = true
        col._containmentOrigin = subject.subtype
        col._erebusStress = math.max(10, math.floor(subject.instability or 0))
    end
    local needs = colonistId and ECS.get(colonistId, 'needs') or nil
    if needs then
        needs.morale = clamp((needs.morale or 50) - 8, 0, 100)
    end

    state.stats.admitted = state.stats.admitted + 1
    subject.status = 'admitted'
    applyDoctrineOutcome('admit', subject)
    clearSubjectFromCell(cell)
    state.subjects[subject.id] = nil
    spawnCellFx(pos, 'burst', { 0.55, 0.88, 1.0, 0.6 }, 0.35, 0.85)

    local text = string.format('%s was admitted into the colony under watch. Nobody trusts the pauses in their answers.', subject.label or 'Survivor')
    sendAlert('Subject Admitted', text, 'major', pos and pos.x, pos and pos.y)
    logContainment(text, 'major', pos and pos.x, pos and pos.y)
    logStory('Recovered Survivor', text)
    return true, colonistId
end

function Containment.purgeSubject(cellId)
    local cell = getCell(cellId)
    local subject = cell and getSubject(cell.subjectId)
    if not cell or not subject then return false, 'No subject assigned' end

    local pos = getCellPos(cellId)
    state.stats.purged = state.stats.purged + 1
    applyDoctrineOutcome('purge', subject)
    addAnomaly(-(subject.anomalyLeak or 0) * 10)
    subject.status = 'purged'
    clearSubjectFromCell(cell)
    state.subjects[subject.id] = nil
    spawnCellFx(pos, 'burst', { 1.0, 0.28, 0.2, 0.65 }, 0.4, 1.0)

    local text = string.format('%s was purged. The room stayed silent afterwards, which was somehow worse.', subject.label or 'Subject')
    sendAlert('Purged Subject', text, 'minor', pos and pos.x, pos and pos.y)
    logContainment(text, 'minor', pos and pos.x, pos and pos.y)
    logStory('Purged Subject', text)
    return true
end

function Containment.transferSubject(cellId)
    local cell = getCell(cellId)
    local subject = cell and getSubject(cell.subjectId)
    if not cell or not subject then return false, 'No subject assigned' end

    local ok, why = Containment.canTransfer(subject.id)
    if not ok then
        return false, why
    end

    local pos = getCellPos(cellId)
    local qOk, Quotas = pcall(require, 'src.sim.quotas')
    local shipment = qOk and Quotas.registerSpecimenTransfer and Quotas.registerSpecimenTransfer(subject) or nil

    state.stats.transferred = state.stats.transferred + 1
    applyDoctrineOutcome('transfer', subject)
    addAnomaly(-(subject.anomalyLeak or 0) * 4)
    subject.status = 'transferred'
    clearSubjectFromCell(cell)
    state.subjects[subject.id] = nil
    spawnCellFx(pos, 'ring', { 0.62, 0.84, 1.0, 0.55 }, 0.55, 1.1)

    local timing
    if shipment and shipment.immediate then
        timing = string.format('Mammona folds the specimen into the next drop on day %d.', shipment.arrivalDay or (GameState.day or 1))
    else
        timing = string.format('Mammona marks the transfer for the next return-pod cycle and answers on day %d.', shipment and shipment.arrivalDay or ((GameState.day or 1) + 1))
    end
    local text = string.format('%s sealed for intact transfer. %s', subject.label or 'Subject', timing)
    sendAlert('Subject Transferred', text, subject.kind == 'human' and 'major' or 'minor', pos and pos.x, pos and pos.y)
    logContainment(text, subject.kind == 'human' and 'major' or 'minor', pos and pos.x, pos and pos.y)
    logStory('Subject Transferred', text)
    return true, shipment
end

function Containment.performAction(entityId, action)
    if action == 'assign' then
        return Containment.assignNextSubject(entityId)
    elseif action == 'cycle_mode' then
        return Containment.cycleMode(entityId)
    elseif action == 'purge' then
        return Containment.purgeSubject(entityId)
    elseif action == 'admit' then
        return Containment.admitSubject(entityId)
    elseif action == 'transfer' then
        return Containment.transferSubject(entityId)
    end
    return false, 'Unknown containment action'
end

function Containment.getCellSnapshot(cellId)
    local cell = getCell(cellId)
    if not cell then return nil end
    local subject = getSubject(cell.subjectId)
    local risk, env = computeRisk(cellId, subject)
    return {
        cellId = cellId,
        cellType = cell.cellType or 'cell',
        mode = cell.mode or 'study',
        modeLabel = getModeLabel(cell.mode or 'study'),
        subject = subject,
        risk = risk,
        env = env,
        pending = countSubjectsWithStatus('field'),
        canAssign = subject == nil and getPendingSubjectForCell(cell) ~= nil,
        canAdmit = subject ~= nil and Containment.canAdmit(subject.id) or false,
        canTransfer = subject ~= nil and select(1, Containment.canTransfer(subject.id)) or false,
    }
end

function Containment.step(dt)
    maybeSendDirective()
    for id, comps in ECS.query('containment_cell') do
        stepCell(id, comps.containment_cell, dt)
    end
end

function Containment.getState()
    return {
        nextSubjectId = state.nextSubjectId,
        subjects = state.subjects,
        stats = state.stats,
        log = state.log,
        lastDirectiveDay = state.lastDirectiveDay,
    }
end

function Containment.restoreState(saved)
    if not saved then
        Containment.init()
        return
    end
    state.nextSubjectId = saved.nextSubjectId or 1
    state.subjects = saved.subjects or {}
    for _, subject in pairs(state.subjects) do
        normalizeSubject(subject)
    end
    state.stats = mergeInto({
        recovered = 0,
        studied = 0,
        extracted = 0,
        purged = 0,
        admitted = 0,
        transferred = 0,
        breaches = 0,
    }, saved.stats or {})
    state.log = saved.log or {}
    state.lastDirectiveDay = saved.lastDirectiveDay or 0
end

return Containment
