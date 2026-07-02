-- test_simulation.lua — Tests for the simulation agent framework
local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Simulation Framework')

---------------------------------------------------------------------------
-- SimAgent base class
---------------------------------------------------------------------------

T.test('SimAgent creates with defaults', function()
    H.resetAll()
    local SimAgent = require('src.testing.sim_agent')

    local agent = SimAgent.new({ name = 'TestAgent' })

    T.eq(agent.name, 'TestAgent')
    T.eq(agent.enabled, true)
    T.eq(#agent.issues, 0)
    T.eq(#agent.actions, 0)
end)

T.test('SimAgent reports issues with correct severity', function()
    H.resetAll()
    local SimAgent = require('src.testing.sim_agent')

    local agent = SimAgent.new({ name = 'TestAgent' })
    agent:init()

    agent:critical('test', 'critical issue')
    agent:high('test', 'high issue')
    agent:medium('test', 'medium issue')
    agent:low('test', 'low issue')

    T.eq(#agent.issues, 4)
    T.eq(agent:countIssues('critical'), 1)
    T.eq(agent:countIssues('high'), 1)
    T.eq(agent:countIssues('medium'), 1)
    T.eq(agent:countIssues('low'), 1)
end)

T.test('SimAgent tracks metrics', function()
    H.resetAll()
    local SimAgent = require('src.testing.sim_agent')

    local agent = SimAgent.new({ name = 'TestAgent' })
    agent:init()

    agent:trackMetric('test_metric', 10)
    agent:trackMetric('test_metric', 20)
    agent:trackMetric('test_metric', 30)

    T.notnil(agent.metrics['test_metric'])
    T.eq(#agent.metrics['test_metric'], 3)
end)

---------------------------------------------------------------------------
-- Invariants checker
---------------------------------------------------------------------------

T.test('Invariants detects negative resources', function()
    H.resetAll()
    local Invariants = require('src.testing.invariants')
    local GameState = require('src.game_state')

    -- Set a negative resource
    GameState.resources.food = -10

    local violations = Invariants.checkResources()

    T.gt(#violations, 0)
    local foundNegative = false
    for _, v in ipairs(violations) do
        if v.category == 'negative_resource' then
            foundNegative = true
            break
        end
    end
    T.ok(foundNegative, 'should detect negative resource')

    -- Reset
    GameState.resources.food = 40
end)

T.test('Invariants checkAll runs all checks', function()
    H.resetAll()
    local Invariants = require('src.testing.invariants')

    local violations = Invariants.checkAll()

    T.notnil(violations)
    -- Should be a table (may be empty if state is valid)
    T.eq(type(violations), 'table')
end)

---------------------------------------------------------------------------
-- SimRunner
---------------------------------------------------------------------------

T.test('SimRunner manages agents', function()
    H.resetAll()
    local SimRunner = require('src.testing.sim_runner')
    local SimAgent = require('src.testing.sim_agent')

    SimRunner.clearAgents()

    local agent1 = SimAgent.new({ name = 'Agent1' })
    local agent2 = SimAgent.new({ name = 'Agent2' })

    SimRunner.addAgent(agent1)
    SimRunner.addAgent(agent2)

    T.notnil(SimRunner.getAgent('Agent1'))
    T.notnil(SimRunner.getAgent('Agent2'))

    SimRunner.removeAgent('Agent1')
    T.isnil(SimRunner.getAgent('Agent1'))
    T.notnil(SimRunner.getAgent('Agent2'))

    SimRunner.clearAgents()
end)

T.test('SimRunner sets scenario', function()
    H.resetAll()
    local SimRunner = require('src.testing.sim_runner')

    SimRunner.setScenario({
        name = 'test_scenario',
        days = 5,
    })

    -- Can't directly test internal state, but the function should not error
    T.ok(true)
end)

---------------------------------------------------------------------------
-- Agent factory
---------------------------------------------------------------------------

T.test('Agents factory creates standard set', function()
    H.resetAll()
    local Agents = require('src.testing.agents.init')

    local agentSet = Agents.createStandardSet()

    T.eq(#agentSet, 5)  -- colonist, building, combat, economy, thermal

    -- Check each agent has a name
    for _, agent in ipairs(agentSet) do
        T.notnil(agent.name)
    end
end)

T.test('Agents factory creates full set', function()
    H.resetAll()
    local Agents = require('src.testing.agents.init')

    local agentSet = Agents.createFullSet()

    T.eq(#agentSet, 6)  -- standard + saveload
end)

T.test('Agents list returns all types', function()
    H.resetAll()
    local Agents = require('src.testing.agents.init')

    local types = Agents.list()

    T.gt(#types, 0)
    -- Should include key agent types
    local hasColonist = false
    local hasCombat = false
    for _, t in ipairs(types) do
        if t == 'ColonistAgent' then hasColonist = true end
        if t == 'CombatAgent' then hasCombat = true end
    end
    T.ok(hasColonist, 'should include ColonistAgent')
    T.ok(hasCombat, 'should include CombatAgent')
end)

---------------------------------------------------------------------------
-- Individual agents
---------------------------------------------------------------------------

T.test('ColonistAgent initializes correctly', function()
    H.resetAll()
    local ColonistAgent = require('src.testing.agents.colonist_agent')

    local agent = ColonistAgent.new()

    T.eq(agent.name, 'ColonistAgent')
    agent:init()
    T.eq(#agent.deaths, 0)
    T.eq(#agent.mentalBreaks, 0)
end)

T.test('BuildingAgent initializes correctly', function()
    H.resetAll()
    local BuildingAgent = require('src.testing.agents.building_agent')

    local agent = BuildingAgent.new({ autoBuild = false })

    T.eq(agent.name, 'BuildingAgent')
    T.eq(agent.autoBuild, false)
    agent:init()
end)

T.test('CombatAgent initializes correctly', function()
    H.resetAll()
    local CombatAgent = require('src.testing.agents.combat_agent')

    local agent = CombatAgent.new({ triggerTestRaids = false })

    T.eq(agent.name, 'CombatAgent')
    T.eq(agent.triggerTestRaids, false)
    agent:init()
    T.eq(#agent.raids, 0)
end)

T.test('EconomyAgent initializes correctly', function()
    H.resetAll()
    local EconomyAgent = require('src.testing.agents.economy_agent')

    local agent = EconomyAgent.new()

    T.eq(agent.name, 'EconomyAgent')
    agent:init()
end)

T.test('ThermalAgent initializes correctly', function()
    H.resetAll()
    local ThermalAgent = require('src.testing.agents.thermal_agent')

    local agent = ThermalAgent.new()

    T.eq(agent.name, 'ThermalAgent')
    agent:init()
end)

T.test('SaveLoadAgent initializes correctly', function()
    H.resetAll()
    local SaveLoadAgent = require('src.testing.agents.saveload_agent')

    local agent = SaveLoadAgent.new({ enableRoundTrip = false })

    T.eq(agent.name, 'SaveLoadAgent')
    T.eq(agent.enableRoundTrip, false)
    agent:init()
end)

---------------------------------------------------------------------------
-- RunSimulation entry point
---------------------------------------------------------------------------

T.test('RunSimulation lists scenarios', function()
    H.resetAll()
    local RunSimulation = require('src.testing.run_simulation')

    local scenarios = RunSimulation.listScenarios()

    T.gt(#scenarios, 0)

    -- Should have standard scenarios
    local hasQuick = false
    local hasSurvival = false
    for _, s in ipairs(scenarios) do
        if s == 'quick' then hasQuick = true end
        if s == 'survival' then hasSurvival = true end
    end
    T.ok(hasQuick, 'should have quick scenario')
    T.ok(hasSurvival, 'should have survival scenario')
end)

T.test('RunSimulation setup does not error', function()
    H.resetAll()
    local RunSimulation = require('src.testing.run_simulation')

    -- Should not throw
    local scenario = RunSimulation.setup('quick')

    T.notnil(scenario)
    T.eq(scenario.name, 'quick')
end)

---------------------------------------------------------------------------
-- Integration: ColonistAgent detects issues
---------------------------------------------------------------------------

T.test('ColonistAgent detects critical warmth', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    local ColonistAgent = require('src.testing.agents.colonist_agent')

    -- Spawn colonist with critical warmth
    local id = H.spawnTestColonist(64, 64, { warmth = 3 })

    local agent = ColonistAgent.new()
    agent:init()
    agent:onTick(0.05)

    -- Should have reported critical warmth
    T.ok(agent:hasIssues(), 'should report issues for critical warmth')
end)

T.test('EconomyAgent detects negative resources', function()
    H.resetAll()
    local GameState = require('src.game_state')
    local EconomyAgent = require('src.testing.agents.economy_agent')

    local agent = EconomyAgent.new()
    agent:init()

    -- Set negative resource
    GameState.resources.food = -5

    agent:onTick(0.05)

    T.ok(agent:hasIssues(), 'should report issues for negative resources')

    -- Reset
    GameState.resources.food = 40
end)
