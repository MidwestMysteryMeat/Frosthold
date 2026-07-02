# FROSTHOLD Simulation Testing Framework

End-to-end simulation testing system that plays the game automatically and detects issues.

## Quick Start

### Run via Love2D command line:
```bash
# Run default survival scenario (30 days)
love . --simulation

# Run quick smoke test (5 days)
love . --simulation --scenario quick

# Run full comprehensive test (50 days)
love . --simulation --scenario full
```

### Run via batch file (Windows):
```batch
run_simulation_test.bat survival
```

## Available Scenarios

| Scenario | Days | Description |
|----------|------|-------------|
| `quick` | 5 | Quick smoke test |
| `survival` | 30 | Standard survival test |
| `endurance` | 100 | Extended endurance test |
| `combat` | 20 | Combat stress test with frequent raids |
| `building` | 15 | Building system stress test |
| `persistence` | 10 | Save/load round-trip testing |
| `full` | 50 | Comprehensive test with all agents |

## Simulation Agents

### ColonistAgent
Tests colonist survival loop:
- Needs tracking (warmth, food, rest, morale)
- Health monitoring
- Death detection and cause inference
- Mental break tracking
- Stuck colonist detection

### BuildingAgent
Tests building systems:
- Construction progress tracking
- Stuck construction detection
- Optional auto-build for stress testing
- Building state validation

### CombatAgent
Tests combat systems:
- Raid detection and tracking
- Creature state monitoring
- Wound tracking
- Combat event logging
- Optional test raid triggering

### EconomyAgent
Tests economic systems:
- Resource flow tracking
- Critical shortage detection
- Negative resource detection (bug)
- Production monitoring
- Economy health assessment

### ThermalAgent
Tests temperature systems:
- Global temperature tracking
- Colonist warmth monitoring
- Heating infrastructure checking
- Generator state monitoring
- Room temperature sampling

### SaveLoadAgent
Tests persistence:
- Save/load timing
- State comparison before/after load
- Round-trip integrity verification
- Performance monitoring

## Invariant Checker

The invariant checker validates game state consistency:
- ECS component presence (colonists have pos, needs)
- Resource validity (no negative, no NaN, no infinity)
- Position bounds checking
- Thermal validity
- Needs bounds
- Job validity
- Power grid validity
- Combat state validity

## Output

Results are:
1. Printed to console with color-coded severity
2. Displayed as overlay during test (when running with graphics)
3. Exported to JSON file in save directory

### Issue Severity Levels
- **CRITICAL**: Game-breaking bugs (crashes, data corruption)
- **HIGH**: Serious bugs (deaths due to bugs, invalid states)
- **MEDIUM**: Notable issues (stuck constructions, performance)
- **LOW**: Minor issues (non-critical warnings)

## Programmatic Usage

```lua
local RunSimulation = require('src.testing.run_simulation')

-- Setup and run
RunSimulation.setup('survival')
RunSimulation.start()

-- In update loop
RunSimulation.step(dt)

-- Check results
if not RunSimulation.isRunning() then
    local results = RunSimulation.getResults()
    print('Issues found:', #results.issues)
end
```

### Creating Custom Agents

```lua
local SimAgent = require('src.testing.sim_agent')

local MyAgent = {}

function MyAgent.new(config)
    config = config or {}
    config.name = 'MyAgent'
    
    local agent = SimAgent.new(config)
    
    function agent:onInit()
        -- Initialize tracking
    end
    
    function agent:onTick(dt)
        -- Check game state, report issues
        if someProblem then
            self:high('category', 'Problem detected', { details = 'here' })
        end
    end
    
    function agent:onFinish()
        -- Final analysis
    end
    
    return agent
end

return MyAgent
```

## File Structure

```
src/testing/
  sim_agent.lua      -- Base agent class
  sim_runner.lua     -- Test orchestrator
  invariants.lua     -- State validity checker
  run_simulation.lua -- Entry point with scenarios
  autoplay.lua       -- Legacy autoplay bot
  agents/
    init.lua           -- Agent index
    colonist_agent.lua
    building_agent.lua
    combat_agent.lua
    economy_agent.lua
    thermal_agent.lua
    saveload_agent.lua
```

## Adding New Scenarios

Edit `src/testing/run_simulation.lua`:

```lua
local SCENARIOS = {
    -- Add your scenario
    my_scenario = {
        name = 'my_scenario',
        description = 'My custom test scenario',
        days = 15,
        agents = { 'colonist', 'combat' },
        agentConfig = {
            combat = {
                triggerTestRaids = true,
                raidIntervalDays = 2,
            },
        },
    },
}
```

## CI Integration

The simulation framework can be run in CI to catch regressions:

```yaml
- name: Run simulation tests
  run: |
    love . --simulation --scenario quick
    # Exit code 0 = no critical issues
```

Results are exported to `simulation_results_<timestamp>.json` in the save directory.
