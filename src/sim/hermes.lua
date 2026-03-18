-- hermes.lua -- Corporate overseer deterioration and directive system
-- Tracks HERMES phase drift from time, anomaly pressure, and deep activity.
-- As HERMES degrades it issues different directives, trims comms reliability,
-- and applies small colony-wide modifiers that the player can feel.

local GameState = require('src.game_state')

local Hermes = {}

local PHASES = {
    functional = {
        id = 'functional',
        name = 'Functional',
        alertPriority = 'info',
        boardCap = 4,
        commsQuality = 1.0,
        directiveInterval = 4,
        intro = 'HERMES is stable. Corporate traffic is coming through clean.',
    },
    interference = {
        id = 'interference',
        name = 'Interference',
        alertPriority = 'minor',
        boardCap = 4,
        commsQuality = 0.85,
        directiveInterval = 3,
        intro = 'Static bleeds into the channel. Some packets arrive late or wrong.',
    },
    corruption = {
        id = 'corruption',
        name = 'Corruption',
        alertPriority = 'major',
        boardCap = 3,
        commsQuality = 0.6,
        directiveInterval = 2,
        intro = 'HERMES is mixing corporate orders with something from below.',
    },
    rogue = {
        id = 'rogue',
        name = 'Rogue',
        alertPriority = 'critical',
        boardCap = 2,
        commsQuality = 0.35,
        directiveInterval = 2,
        intro = 'The orbit link is gone. HERMES is still talking.',
    },
}

local PHASE_ORDER = { 'functional', 'interference', 'corruption', 'rogue' }

local DIRECTIVES = {
    quota_push = {
        phases = { 'functional' },
        title = 'HERMES Directive: Quota Push',
        body = 'Keep outbound shipments on schedule. Mammona wants clean numbers and no excuses.',
        effects = { supplyDropMult = 1.08, moraleDrainAdd = 0.02 },
    },
    heater_audit = {
        phases = { 'functional' },
        title = 'HERMES Directive: Heater Audit',
        body = 'Reduce waste heat, log every fuel burn, and hold the line on efficiency.',
        effects = { heatSignatureMult = 0.92, warmthMult = 0.97 },
    },
    survey_window = {
        phases = { 'functional' },
        title = 'HERMES Directive: Survey Window',
        body = 'Catalog exposed wreckage and relay anything stamped Mammona property.',
        effects = { workSpeedMult = 1.03 },
    },
    signal_triage = {
        phases = { 'interference' },
        title = 'HERMES Directive: Signal Triage',
        body = 'Relay traffic degraded. Nonessential board traffic is being queued behind compliance traffic.',
        effects = { boardCapDelta = -1 },
    },
    priority_heat = {
        phases = { 'interference' },
        title = 'HERMES Directive: Priority Heat',
        body = 'Hold heat output below reportable thresholds. Stay warm enough. Do not invite notice.',
        effects = { heatSignatureMult = 0.9, warmthMult = 0.95 },
    },
    compliance_echo = {
        phases = { 'interference' },
        title = 'HERMES Directive: Compliance Echo',
        body = 'Acknowledge quota variance. Acknowledge static. Acknowledge the second signal if heard.',
        effects = { moraleDrainAdd = 0.04, supplyDropMult = 1.04 },
    },
    contradictory_orders = {
        phases = { 'corruption' },
        title = 'HERMES Directive: Contradictory Orders',
        body = 'Increase output. Conserve stores. Hold the drills. Avoid surface losses. Confirm all four.',
        effects = { workSpeedMult = 0.97, moraleDrainAdd = 0.06 },
    },
    bore_hold = {
        phases = { 'corruption' },
        title = 'HERMES Directive: Bore Hold',
        body = 'Do not power down the deep bore. The return signal strengthens when the bore stays open.',
        effects = { workSpeedMult = 1.04, warmthMult = 0.94, heatSignatureMult = 1.05 },
    },
    redacted_board = {
        phases = { 'corruption' },
        title = 'HERMES Directive: Board Redaction',
        body = 'Quest traffic partially redacted pending audit. Missing lines may be restored later.',
        effects = { boardCapDelta = -1, supplyDropMult = 0.95 },
    },
    open_channel = {
        phases = { 'rogue' },
        title = 'HERMES Directive: OPEN CHANNEL',
        body = 'KEEP THE CHANNEL OPEN. ROUTE POWER BELOW. REPORT DREAMS. REPORT WHISPERS. REPORT DELAYS.',
        effects = { moraleDrainAdd = 0.08, heatSignatureMult = 1.12, warmthMult = 0.92 },
    },
    return_below = {
        phases = { 'rogue' },
        title = 'HERMES Directive: RETURN BELOW',
        body = 'Surface work is waste. Return below and remain where the signal can hear you.',
        effects = { boardCapDelta = -1, workSpeedMult = 0.95, moraleDrainAdd = 0.05 },
    },
    asset_yield = {
        phases = { 'rogue' },
        title = 'HERMES Directive: ASSET YIELD',
        body = 'Surface inventory marked expendable. Keep the core line fed and stop asking for relief.',
        effects = { supplyDropMult = 0.82, moraleDrainAdd = 0.06, workSpeedMult = 0.96 },
    },
}

local state = {
    phase = 'functional',
    lastPhaseDay = 1,
    pressure = 0,
    currentDirectiveId = nil,
    lastDirectiveDay = 0,
    nextDirectiveDay = 1,
}

local function syncGameState()
    GameState.hermesPhase = state.phase
    GameState.hermesDirective = state.currentDirectiveId
end

local function currentDirective()
    return state.currentDirectiveId and DIRECTIVES[state.currentDirectiveId] or nil
end

local function getPhaseDef()
    return PHASES[state.phase] or PHASES.functional
end

local function inPhase(def, phaseId)
    if not def.phases then return false end
    for _, allowed in ipairs(def.phases) do
        if allowed == phaseId then return true end
    end
    return false
end

local function getDepthPressure()
    local rok, Raids = pcall(require, 'src.sim.raids')
    if not rok or not Raids.getDepthProgression then return 0 end
    return Raids.getDepthProgression() or 0
end

local function getAnomalyPressure()
    local aok, Anomaly = pcall(require, 'src.sim.anomaly')
    if not aok or not Anomaly.getLevel then return 0 end
    return Anomaly.getLevel() or 0
end

local function computePressure()
    local dayPressure = math.max(0, (GameState.day or 1) - 1)
    local anomalyPressure = math.floor(getAnomalyPressure() / 10)
    local depthPressure = math.floor(getDepthPressure() / 12)
    return dayPressure + anomalyPressure + depthPressure
end

local function pickPhase(pressure)
    if pressure >= 30 then return 'rogue' end
    if pressure >= 14 then return 'corruption' end
    if pressure >= 7 then return 'interference' end
    return 'functional'
end

local function sendAlert(title, body, priority)
    local aok, Alerts = pcall(require, 'src.ui.alerts')
    if aok and Alerts.send then
        Alerts.send(title, body, priority or 'info')
    end
end

local function logHermes(title, body)
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.logEvent then
        Storyteller.logEvent(title, body, 0)
    end
end

local function refreshQuestBoard()
    if not package.loaded['src.quest.quest'] then
        return
    end
    local qok, Quest = pcall(require, 'src.quest.quest')
    if qok and Quest.refreshBoard then
        Quest.refreshBoard()
    end
end

local function chooseDirective(sendLetter)
    local pool = {}
    for id, def in pairs(DIRECTIVES) do
        if inPhase(def, state.phase) then
            pool[#pool + 1] = id
        end
    end
    if #pool == 0 then
        state.currentDirectiveId = nil
        return
    end

    state.currentDirectiveId = pool[math.random(#pool)]
    state.lastDirectiveDay = GameState.day or 1
    state.nextDirectiveDay = state.lastDirectiveDay + (getPhaseDef().directiveInterval or 3)
    syncGameState()
    refreshQuestBoard()

    if sendLetter then
        local directive = currentDirective()
        if directive then
            sendAlert(directive.title, directive.body, getPhaseDef().alertPriority)
            logHermes(directive.title, directive.body)
        end
    end
end

local hermesEnabled = true

function Hermes.init()
    -- Check planet config for HERMES disable flag
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok and Planet.get('hermes.enabled', true) == false then
        hermesEnabled = false
        state.phase = 'functional'
        state.pressure = 0
        state.currentDirectiveId = nil
        syncGameState()
        return
    end

    hermesEnabled = true
    state.phase = 'functional'
    state.lastPhaseDay = GameState.day or 1
    state.pressure = 0
    state.currentDirectiveId = nil
    state.lastDirectiveDay = 0
    state.nextDirectiveDay = GameState.day or 1
    chooseDirective(false)
    syncGameState()
end

function Hermes.step(dt)
    if not hermesEnabled then return end
    local pressure = computePressure()
    state.pressure = pressure
    local nextPhase = pickPhase(pressure)

    if nextPhase ~= state.phase then
        state.phase = nextPhase
        state.lastPhaseDay = GameState.day or state.lastPhaseDay
        syncGameState()

        local phaseDef = getPhaseDef()
        local title = 'HERMES: ' .. phaseDef.name
        sendAlert(title, phaseDef.intro, phaseDef.alertPriority)
        logHermes(title, phaseDef.intro)

        chooseDirective(true)
        return
    end

    local today = GameState.day or 1
    if today >= (state.nextDirectiveDay or today) and today ~= state.lastDirectiveDay then
        chooseDirective(true)
    end
end

function Hermes.isEnabled()
    return hermesEnabled
end

function Hermes.getPhase()
    return state.phase, getPhaseDef()
end

function Hermes.getPhaseName()
    return getPhaseDef().name
end

function Hermes.getCurrentDirective()
    local directive = currentDirective()
    if not directive then return nil end
    return {
        id = state.currentDirectiveId,
        title = directive.title,
        body = directive.body,
        effects = directive.effects or {},
    }
end

function Hermes.getPressure()
    return state.pressure or 0
end

function Hermes.getCommsQuality()
    return getPhaseDef().commsQuality or 1.0
end

function Hermes.getQuestBoardCap(defaultCap)
    local phaseCap = getPhaseDef().boardCap or defaultCap
    local directive = currentDirective()
    local delta = 0
    if directive and directive.effects and directive.effects.boardCapDelta then
        delta = directive.effects.boardCapDelta
    end
    return math.max(1, math.min(defaultCap, phaseCap + delta))
end

function Hermes.getWorkSpeedMult()
    local directive = currentDirective()
    if directive and directive.effects and directive.effects.workSpeedMult then
        return directive.effects.workSpeedMult
    end
    return 1.0
end

function Hermes.getMoraleDrainAdd()
    local directive = currentDirective()
    if directive and directive.effects and directive.effects.moraleDrainAdd then
        return directive.effects.moraleDrainAdd
    end
    return 0
end

function Hermes.getHeatSignatureMult()
    local directive = currentDirective()
    if directive and directive.effects and directive.effects.heatSignatureMult then
        return directive.effects.heatSignatureMult
    end
    return 1.0
end

function Hermes.getWarmthMult()
    local directive = currentDirective()
    if directive and directive.effects and directive.effects.warmthMult then
        return directive.effects.warmthMult
    end
    return 1.0
end

function Hermes.getSupplyDropMult()
    local directive = currentDirective()
    if directive and directive.effects and directive.effects.supplyDropMult then
        return directive.effects.supplyDropMult
    end
    return 1.0
end

function Hermes.getStatusSummary()
    local directive = currentDirective()
    if directive then
        return getPhaseDef().name .. ' - ' .. directive.title
    end
    return getPhaseDef().name
end

function Hermes.getState()
    return {
        phase = state.phase,
        lastPhaseDay = state.lastPhaseDay,
        pressure = state.pressure,
        currentDirectiveId = state.currentDirectiveId,
        lastDirectiveDay = state.lastDirectiveDay,
        nextDirectiveDay = state.nextDirectiveDay,
    }
end

function Hermes.restoreState(saved)
    if not saved then
        Hermes.init()
        return
    end

    state.phase = PHASES[saved.phase] and saved.phase or 'functional'
    state.lastPhaseDay = saved.lastPhaseDay or (GameState.day or 1)
    state.pressure = saved.pressure or 0
    state.currentDirectiveId = DIRECTIVES[saved.currentDirectiveId] and saved.currentDirectiveId or nil
    state.lastDirectiveDay = saved.lastDirectiveDay or 0
    state.nextDirectiveDay = saved.nextDirectiveDay or ((GameState.day or 1) + 1)
    if not state.currentDirectiveId then
        chooseDirective(false)
    else
        syncGameState()
    end
end

return Hermes
