require('tests.mock_love')

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Simulation: HERMES')

local function reloadHermes()
    package.loaded['src.sim.hermes'] = nil
    return require('src.sim.hermes')
end

local function reloadAnomaly()
    package.loaded['src.sim.anomaly'] = nil
    return require('src.sim.anomaly')
end

T.test('init starts functional and syncs GameState', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Hermes = reloadHermes()

    GS.day = 1
    Hermes.init()

    local phase, def = Hermes.getPhase()
    local directive = Hermes.getCurrentDirective()

    T.eq(phase, 'functional', 'starts in functional phase')
    T.eq(def.name, 'Functional', 'phase definition returned')
    T.eq(GS.hermesPhase, 'functional', 'GameState phase synced')
    T.notnil(directive, 'directive chosen on init')
    T.eq(GS.hermesDirective, directive.id, 'GameState directive synced')
    T.eq(Hermes.getQuestBoardCap(4), 4, 'functional phase keeps full board cap')
end)

T.test('phase progression follows day thresholds from lore', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Hermes = reloadHermes()

    Hermes.init()

    GS.day = 8
    Hermes.step(0.05)
    T.eq(select(1, Hermes.getPhase()), 'interference', 'day 8 enters interference')

    GS.day = 15
    Hermes.step(0.05)
    T.eq(select(1, Hermes.getPhase()), 'corruption', 'day 15 enters corruption')

    GS.day = 31
    Hermes.step(0.05)
    T.eq(select(1, Hermes.getPhase()), 'rogue', 'day 31 enters rogue')
end)

T.test('anomaly pressure can accelerate phase drift', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Hermes = reloadHermes()
    local Anomaly = reloadAnomaly()

    GS.day = 1
    Hermes.init()
    Anomaly.restoreState({
        level = 70,
        totalAccumulated = 70,
        bossAwakened = false,
        bossDefeated = false,
        extractionReady = false,
        bossEntityId = nil,
        lastEventDay = 0,
        dayTracker = 0,
    })

    Hermes.step(0.05)

    T.eq(select(1, Hermes.getPhase()), 'interference', 'high anomaly pressure advances HERMES')
    T.eq(Hermes.getPressure(), 7, 'pressure reflects anomaly contribution')
end)

T.test('restoreState preserves directive effects and board reduction', function()
    H.resetAll()
    local GS = require('src.game_state')
    local Hermes = reloadHermes()

    Hermes.restoreState({
        phase = 'corruption',
        lastPhaseDay = 15,
        pressure = 18,
        currentDirectiveId = 'redacted_board',
        lastDirectiveDay = 15,
        nextDirectiveDay = 17,
    })

    local directive = Hermes.getCurrentDirective()

    T.eq(select(1, Hermes.getPhase()), 'corruption', 'restored phase kept')
    T.eq(GS.hermesPhase, 'corruption', 'GameState phase restored')
    T.notnil(directive, 'restored directive available')
    T.eq(directive.id, 'redacted_board', 'specific directive restored')
    T.eq(GS.hermesDirective, 'redacted_board', 'GameState directive restored')
    T.eq(Hermes.getQuestBoardCap(4), 2, 'corruption + redaction trims board to 2')
    T.near(Hermes.getSupplyDropMult(), 0.95, 0.001, 'directive effect restored')
end)
