-- test_simulation_e2e.lua — End-to-end simulation framework tests
-- These tests boot the game and run actual simulations
local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Simulation E2E')

---------------------------------------------------------------------------
-- Helper: Boot game to playing state
---------------------------------------------------------------------------

local function bootToPlaying()
    H.resetAll()

    -- Unload any cached modules
    package.loaded['main'] = nil
    package.loaded['src.ui.start_menu'] = nil
    package.loaded['src.ui.colonist_select'] = nil
    package.loaded['src.ui.game_over'] = nil

    require('tests.mock_love')
    require('main')
    love.load()
    math.randomseed(12345)

    local GameState = require('src.game_state')
    local PlanetSelect = require('src.ui.planet_select')
    local ColonistSelect = require('src.ui.colonist_select')
    local ReqPanel = require('src.ui.requisition_panel')
    local WorldMap = require('src.ui.world_map')

    -- Skip through menus to playing
    GameState.phase = 'planet_select'
    PlanetSelect.init()
    PlanetSelect.confirm()

    ReqPanel.keypressed('escape')
    love.update(0.05)

    ColonistSelect.deploy()

    ReqPanel.keypressed('escape')
    love.update(0.05)

    WorldMap.confirm()
    love.update(0.05)

    return {
        GameState = GameState,
        ECS = require('src.ecs.ecs'),
    }
end

---------------------------------------------------------------------------
-- Test: Full simulation run with all agents
---------------------------------------------------------------------------

T.test('simulation run completes without critical errors', function()
    local env = bootToPlaying()
    local GameState = env.GameState
    local ECS = env.ECS

    T.eq(GameState.phase, 'playing', 'game should be in playing phase')

    -- Load simulation framework
    local SimRunner = require('src.testing.sim_runner')
    local Agents = require('src.testing.agents.init')

    -- Create standard agent set
    SimRunner.clearAgents()
    local agents = Agents.createStandardSet()
    for _, agent in ipairs(agents) do
        SimRunner.addAgent(agent)
    end

    -- Configure for short test
    SimRunner.setScenario({
        name = 'e2e_test',
        days = 2,
    })

    -- Start simulation
    SimRunner.start()
    T.ok(SimRunner.isRunning(), 'simulation should be running')

    -- Run for 200 ticks (10 seconds of game time)
    local dt = 0.05  -- 20Hz
    for tick = 1, 200 do
        -- Advance game state
        GameState.simTick = GameState.simTick + 1
        if GameState.simTick % 20 == 0 then
            GameState.hour = GameState.hour + (1/60)  -- 1 minute per second
            if GameState.hour >= 24 then
                GameState.hour = 0
                GameState.day = GameState.day + 1
            end
        end

        -- Run ECS update
        ECS.update(dt)

        -- Run simulation step
        SimRunner.step(dt)

        -- Check for early termination
        if not SimRunner.isRunning() then
            break
        end
    end

    -- Get results
    local results = SimRunner.getResults()

    T.notnil(results, 'should have results')
    T.gt(results.ticksReached, 0, 'should have run some ticks')

    -- Check for critical issues
    local criticals = results.issueCounts.critical or 0
    T.lt(criticals, 5, 'should have fewer than 5 critical issues')

    -- Stop simulation
    if SimRunner.isRunning() then
        SimRunner.stop('test_complete')
    end
end)

---------------------------------------------------------------------------
-- Test: Invariants checker catches problems
---------------------------------------------------------------------------

T.test('invariants detect injected problems', function()
    local env = bootToPlaying()
    local GameState = env.GameState
    local ECS = env.ECS
    local Invariants = require('src.testing.invariants')

    -- Check clean state first
    local violations = Invariants.checkAll()
    local initialCount = #violations

    -- Inject a negative resource
    GameState.resources.food = -100

    violations = Invariants.checkResources()
    local foundNegative = false
    for _, v in ipairs(violations) do
        if v.category == 'negative_resource' then
            foundNegative = true
        end
    end
    T.ok(foundNegative, 'should detect negative resource')

    -- Fix and verify
    GameState.resources.food = 50
    violations = Invariants.checkResources()
    foundNegative = false
    for _, v in ipairs(violations) do
        if v.category == 'negative_resource' and v.data.resource == 'food' then
            foundNegative = true
        end
    end
    T.ok(not foundNegative, 'should not detect negative after fix')
end)

---------------------------------------------------------------------------
-- Test: ColonistAgent detects death
---------------------------------------------------------------------------

T.test('colonist agent detects death events', function()
    local env = bootToPlaying()
    local GameState = env.GameState
    local ECS = env.ECS

    local ColonistAgent = require('src.testing.agents.colonist_agent')
    local agent = ColonistAgent.new()
    agent:init()

    -- Find a colonist
    local colonistId = nil
    local colonistComp = nil
    for id, comps in ECS.query('colonist') do
        colonistId = id
        colonistComp = comps.colonist
        break
    end

    T.notnil(colonistId, 'should have a colonist')

    -- Snapshot initial state
    agent:snapshotColonists()

    -- Kill the colonist
    colonistComp.health = 0
    colonistComp.state = 'dead'

    -- Run agent tick
    agent:onTick(0.05)

    -- Check for death detection
    T.gt(#agent.deaths, 0, 'should detect death')
    T.ok(agent:hasIssues(), 'should report issues')
end)

---------------------------------------------------------------------------
-- Test: EconomyAgent tracks resource changes
---------------------------------------------------------------------------

T.test('economy agent tracks resource deltas', function()
    local env = bootToPlaying()
    local GameState = env.GameState

    local EconomyAgent = require('src.testing.agents.economy_agent')
    local agent = EconomyAgent.new()
    agent:init()

    -- Record initial resources
    local initialFood = GameState.resources.food or 0

    -- First tick to snapshot
    agent:onTick(0.05)

    -- Change resources significantly
    GameState.resources.food = initialFood + 50

    -- Second tick to detect change
    agent:onTick(0.05)

    -- Check resource history was recorded
    T.notnil(agent.resourceHistory.food, 'should track food history')
    T.gt(#agent.resourceHistory.food, 0, 'should have food entries')
end)

---------------------------------------------------------------------------
-- Test: BuildingAgent detects stuck construction
---------------------------------------------------------------------------

T.test('building agent tracks construction progress', function()
    local env = bootToPlaying()
    local ECS = env.ECS

    local BuildingAgent = require('src.testing.agents.building_agent')
    local agent = BuildingAgent.new({ autoBuild = false })
    agent:init()

    -- Create a test building under construction
    local buildingId = ECS.spawn()
    ECS.set(buildingId, 'pos', { x = 60, y = 60 })
    ECS.set(buildingId, 'building', {
        defId = 'wall_wood',
        complete = false,
        progress = 0.5,
    })

    -- Run agent tick
    agent:onTick(0.05)

    -- Check building was tracked
    T.notnil(agent.buildingStates[buildingId], 'should track building')
    T.eq(agent.buildingStates[buildingId].progress, 0.5, 'should record progress')
end)

---------------------------------------------------------------------------
-- Test: CombatAgent detects creatures
---------------------------------------------------------------------------

T.test('combat agent tracks creatures', function()
    local env = bootToPlaying()
    local ECS = env.ECS

    local CombatAgent = require('src.testing.agents.combat_agent')
    local agent = CombatAgent.new({ triggerTestRaids = false })
    agent:init()

    -- Spawn a test creature
    local creatureId = ECS.spawn()
    ECS.set(creatureId, 'pos', { x = 70, y = 70 })
    ECS.set(creatureId, 'creature', {
        species = 'frost_hare',
        health = 20,
        maxHealth = 20,
        hostile = false,
        state = 'idle',
    })

    -- Run agent tick
    agent:onTick(0.05)

    -- Check creature was tracked
    T.notnil(agent.creatureStates[creatureId], 'should track creature')

    -- Kill creature and check death detection
    local cr = ECS.get(creatureId, 'creature')
    cr.state = 'dead'
    cr.health = 0

    agent:onTick(0.05)

    -- Should have recorded combat event
    local foundDeath = false
    for _, event in ipairs(agent.combatEvents) do
        if event.type == 'creature_death' then
            foundDeath = true
        end
    end
    T.ok(foundDeath, 'should detect creature death')
end)

---------------------------------------------------------------------------
-- Test: ThermalAgent tracks temperature
---------------------------------------------------------------------------

T.test('thermal agent tracks temperature', function()
    local env = bootToPlaying()
    local GameState = env.GameState

    local ThermalAgent = require('src.testing.agents.thermal_agent')
    local agent = ThermalAgent.new()
    agent:init()

    -- Set a known temperature
    GameState.globalTemp = -45

    -- Run agent tick
    agent:onTick(0.05)

    -- Check metric was tracked
    T.notnil(agent.metrics['global_temp'], 'should track global_temp')
    T.gt(#agent.metrics['global_temp'], 0, 'should have temp entries')
end)

---------------------------------------------------------------------------
-- Test: SaveLoadAgent captures state
---------------------------------------------------------------------------

T.test('saveload agent captures state snapshot', function()
    local env = bootToPlaying()
    local GameState = env.GameState
    local ECS = env.ECS

    local SaveLoadAgent = require('src.testing.agents.saveload_agent')
    local agent = SaveLoadAgent.new({ enableRoundTrip = false })
    agent:init()

    -- Capture state
    local state = agent:captureState()

    T.notnil(state, 'should capture state')
    T.eq(state.day, GameState.day, 'should capture day')
    T.notnil(state.resources, 'should capture resources')
    T.gt(state.colonistCount, 0, 'should count colonists')
end)

---------------------------------------------------------------------------
-- Test: SimRunner orchestrates multiple agents
---------------------------------------------------------------------------

T.test('sim runner manages agent lifecycle', function()
    local env = bootToPlaying()
    local GameState = env.GameState

    local SimRunner = require('src.testing.sim_runner')
    local SimAgent = require('src.testing.sim_agent')

    -- Create test agents
    local initCalled = { a = false, b = false }
    local tickCalled = { a = 0, b = 0 }
    local finishCalled = { a = false, b = false }

    local agentA = SimAgent.new({
        name = 'AgentA',
        onInit = function() initCalled.a = true end,
        onTick = function() tickCalled.a = tickCalled.a + 1 end,
        onFinish = function() finishCalled.a = true end,
    })

    local agentB = SimAgent.new({
        name = 'AgentB',
        onInit = function() initCalled.b = true end,
        onTick = function() tickCalled.b = tickCalled.b + 1 end,
        onFinish = function() finishCalled.b = true end,
    })

    SimRunner.clearAgents()
    SimRunner.addAgent(agentA)
    SimRunner.addAgent(agentB)

    SimRunner.setScenario({ name = 'lifecycle_test', days = 1 })
    SimRunner.start()

    T.ok(initCalled.a, 'AgentA init should be called')
    T.ok(initCalled.b, 'AgentB init should be called')

    -- Run a few steps
    for i = 1, 5 do
        GameState.simTick = GameState.simTick + 1
        SimRunner.step(0.05)
    end

    T.gt(tickCalled.a, 0, 'AgentA tick should be called')
    T.gt(tickCalled.b, 0, 'AgentB tick should be called')

    -- Stop
    SimRunner.stop('test_done')

    T.ok(finishCalled.a, 'AgentA finish should be called')
    T.ok(finishCalled.b, 'AgentB finish should be called')
    T.ok(not SimRunner.isRunning(), 'should not be running after stop')
end)

---------------------------------------------------------------------------
-- Test: Results collection
---------------------------------------------------------------------------

T.test('results include all agent data', function()
    local env = bootToPlaying()
    local GameState = env.GameState

    local SimRunner = require('src.testing.sim_runner')
    local Agents = require('src.testing.agents.init')

    SimRunner.clearAgents()
    local agents = Agents.createStandardSet()
    for _, agent in ipairs(agents) do
        SimRunner.addAgent(agent)
    end

    SimRunner.setScenario({ name = 'results_test', days = 1 })
    SimRunner.start()

    -- Run briefly
    for i = 1, 10 do
        GameState.simTick = GameState.simTick + 1
        SimRunner.step(0.05)
    end

    SimRunner.stop('test_done')

    local results = SimRunner.getResults()

    T.notnil(results.scenario, 'should have scenario')
    T.notnil(results.status, 'should have status')
    T.notnil(results.issues, 'should have issues array')
    T.notnil(results.issueCounts, 'should have issue counts')
    T.notnil(results.agents, 'should have agent results')
    T.eq(#results.agents, 5, 'should have 5 agent results')
end)
