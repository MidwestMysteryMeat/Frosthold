local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Playthrough Smoke')

local function unloadBootstrapModules()
    package.loaded['main'] = nil
    package.loaded['src.ui.start_menu'] = nil
    package.loaded['src.ui.colonist_select'] = nil
    package.loaded['src.ui.difficulty'] = nil
    package.loaded['src.ui.game_over'] = nil
end

local function countAliveColonists(ECS)
    local alive = 0
    for _, comps in ECS.query('colonist') do
        if comps.colonist.state ~= 'dead' then
            alive = alive + 1
        end
    end
    return alive
end

local function killAllColonists(ECS)
    for _, comps in ECS.query('colonist') do
        comps.colonist.state = 'dead'
        comps.colonist.health = 0
    end
end

local function bootToPlaying()
    H.resetAll()
    unloadBootstrapModules()
    require('tests.mock_love')

    require('main')
    love.load()
    math.randomseed(12345)

    local GameState = require('src.game_state')
    local StartMenu = require('src.ui.start_menu')
    local ColonistSelect = require('src.ui.colonist_select')

    T.eq(GameState.phase, 'menu', 'boot starts in menu phase')

    -- Skip main menu: jump directly to planet_select (legacy path)
    GameState.phase = 'planet_select'
    local PlanetSelect = require('src.ui.planet_select')
    PlanetSelect.init()

    -- Skip planet selection (select Erebus and advance to world map)
    PlanetSelect.confirm()
    T.eq(GameState.phase, 'world_map', 'planet confirm enters world_map phase')

    -- Skip world map (confirm default landing zone — now goes directly to drafting)
    local WorldMap = require('src.ui.world_map')
    WorldMap.generateForPlanet('erebus')
    WorldMap.confirm()
    T.eq(GameState.phase, 'drafting', 'world map confirm enters drafting phase')
    ColonistSelect.deploy()
    T.eq(GameState.phase, 'starting', 'crew deployment enters starting phase')
    love.update(0.05)
    T.eq(GameState.phase, 'playing', 'world init reaches playing phase')

    return {
        GameState = GameState,
        ECS = require('src.ecs.ecs'),
        GameOver = require('src.ui.game_over'),
        Endgame = require('src.sim.endgame'),
    }
end

local function spawnEndgameBuilding(kind)
    local ECS = require('src.ecs.ecs')
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = 80, y = 80, prevX = 80, prevY = 80, depth = 0 })
    ECS.set(id, 'endgame_building', {
        type = kind,
        powered = false,
        chargeProgress = 0,
        phase = 'idle',
        finalWaveSpawned = false,
    })
    return id
end

local VICTORY_TYPES = {
    transmission_array = 'mammona_signal',
    launch_pad = 'exodus',
    sealing_apparatus = 'seal_deep',
    extraction_beacon = 'mammona_extraction',
}

local function runVictoryRoute(kind, setupFn)
    local env = bootToPlaying()
    local ECS = env.ECS
    local GameOver = env.GameOver
    local Endgame = env.Endgame
    local Power = require('src.sim.power')
    local buildingId = spawnEndgameBuilding(kind)
    local eg = ECS.get(buildingId, 'endgame_building')

    local capturedType
    local capturedReason
    local origTrigger = GameOver.triggerVictory
    local origPowered = Power.isConsumerPowered
    local raids
    local origRaidActive

    GameOver.triggerVictory = function(vType, vReason)
        capturedType = vType
        capturedReason = vReason
        return origTrigger(vType, vReason)
    end
    Power.isConsumerPowered = function()
        return true
    end

    local ok, err = pcall(function()
        local started, startErr = Endgame.startCharging(buildingId)
        T.ok(started, startErr or 'endgame charging should start')
        T.eq(eg.phase, 'charging', 'building enters charging phase')

        ECS.update(1.0)
        T.gt(eg.chargeProgress, 0, 'charging advances when powered')

        eg.chargeProgress = Endgame.CHARGE_TIME
        eg.phase = 'ready'

        if setupFn then
            setupFn(env, buildingId, eg)
        end

        local activated, actErr = Endgame.activate(buildingId)
        T.ok(activated, actErr or 'endgame activation should succeed')

        if kind == 'transmission_array' then
            raids = require('src.sim.raids')
            origRaidActive = raids.isRaidActive
            ECS.update(0.2)
            T.ok(eg.finalWaveSpawned, 'transmission array spawns its final wave')
            raids.isRaidActive = function()
                return false
            end
            ECS.update(0.2)
        else
            ECS.update(0.2)
        end

        T.eq(GameOver.getState(), 'victory', 'victory state should be reached')
        T.eq(capturedType, VICTORY_TYPES[kind], 'victory type should match route')
        T.ok(type(capturedReason) == 'string' and #capturedReason > 0, 'victory reason should be populated')
    end)

    GameOver.triggerVictory = origTrigger
    Power.isConsumerPowered = origPowered
    if raids and origRaidActive then
        raids.isRaidActive = origRaidActive
    end

    if not ok then
        error(err, 0)
    end
end

T.test('fresh start flow reaches playing with drafted crew', function()
    local env = bootToPlaying()
    T.eq(env.ECS.countWith('colonist'), 3, 'crashlanded scenario boots with three colonists')
    T.eq(countAliveColonists(env.ECS), 3, 'starting crew is alive')
end)

T.test('SOS beacon defers defeat while active then defeat fires without beacon', function()
    local env = bootToPlaying()
    local ECS = env.ECS
    local GameState = env.GameState
    local GameOver = env.GameOver
    local Power = require('src.sim.power')

    -- Spawn an active SOS beacon entity
    local beaconId = ECS.spawn()
    ECS.set(beaconId, 'pos', { x = 64, y = 64, depth = 0 })
    ECS.set(beaconId, 'sos_beacon', {
        powered = true,
        active = true,
        fired = false,
        countdown = nil,
    })

    GameState.day = 2
    killAllColonists(env.ECS)
    GameOver.step(2.1)

    T.eq(GameOver.getState(), 'playing', 'active SOS beacon defers defeat check')

    -- Now mark beacon as fired (burnt out)
    local beacon = ECS.get(beaconId, 'sos_beacon')
    beacon.fired = true
    beacon.active = false

    GameOver.step(2.1)

    T.eq(GameOver.getState(), 'defeat', 'defeat fires after beacon is burnt out')
    T.eq(GameState.paused, true, 'defeat pauses the game')
end)

T.test('launch pad route reaches exodus victory', function()
    runVictoryRoute('launch_pad')
end)

T.test('sealing apparatus route reaches seal-the-deep victory', function()
    runVictoryRoute('sealing_apparatus')
end)

T.test('extraction beacon route reaches Mammona extraction after boss defeat', function()
    runVictoryRoute('extraction_beacon', function()
        local Anomaly = require('src.sim.anomaly')
        Anomaly.onBossDefeated()
    end)
end)

T.test('transmission array route reaches Mammona claim victory after final wave', function()
    runVictoryRoute('transmission_array')
end)
