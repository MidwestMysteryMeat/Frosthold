-- FROSTHOLD — Simulation Agents Index
-- src/testing/agents/init.lua
-- Central import point for all simulation test agents.

local Agents = {}

-- Load all agent modules
Agents.ColonistAgent = require('src.testing.agents.colonist_agent')
Agents.BuildingAgent = require('src.testing.agents.building_agent')
Agents.CombatAgent = require('src.testing.agents.combat_agent')
Agents.EconomyAgent = require('src.testing.agents.economy_agent')
Agents.SaveLoadAgent = require('src.testing.agents.saveload_agent')
Agents.ThermalAgent = require('src.testing.agents.thermal_agent')

-- Factory function to create all standard agents
function Agents.createStandardSet(config)
    config = config or {}
    return {
        Agents.ColonistAgent.new(config.colonist),
        Agents.BuildingAgent.new(config.building),
        Agents.CombatAgent.new(config.combat),
        Agents.EconomyAgent.new(config.economy),
        Agents.ThermalAgent.new(config.thermal),
    }
end

-- Factory function to create full set including save/load
function Agents.createFullSet(config)
    config = config or {}
    local agents = Agents.createStandardSet(config)
    agents[#agents + 1] = Agents.SaveLoadAgent.new(config.saveload)
    return agents
end

-- List available agent types
function Agents.list()
    return {
        'ColonistAgent',
        'BuildingAgent',
        'CombatAgent',
        'EconomyAgent',
        'SaveLoadAgent',
        'ThermalAgent',
    }
end

return Agents
