-- helpers.lua — Test helper functions for resetting game state between tests

local H = {}

-- Reset ECS to clean state
function H.resetECS()
    local ECS = require('src.ecs.ecs')
    ECS.init()
end

-- Reset GameState to defaults
function H.resetGameState()
    local GS = require('src.game_state')
    GS.simTick = 0
    GS.day = 1
    GS.hour = 6.0
    GS.paused = false
    GS.speed = 1
    GS.globalTemp = -40
    GS.windChill = 0
    GS.baseTemp = -40
    GS.tempBias = 0
    GS.weatherHarshness = 1.0
    GS.creatureAggression = 1.0
    GS.resourceScarcity = 1.0
    GS.diseasePressure = 1.0
    GS.hermesPhase = 'functional'
    GS.hermesDirective = nil
    GS.buildMode = false
    GS.buildGhost = nil
    GS.selectedTool = nil
    GS.selectedEntities = {}
    GS.alpha = 0
    GS.resources = {
        thermalCores = 0,
        wood = 50,
        stone = 30,
        metal = 0,
        food = 40,
        fuel = 20,
        water = 10,
        components = 0,
        hide = 0,
        corpse_creature = 0,
        corpse_human = 0,
        human_meat = 0,
        human_leather = 0,
        steel = 0,
        circuit = 0,
        raw_hide = 0,
        bandage = 0,
        medicine = 0,
    }
end

-- Reset Jobs queue
function H.resetJobs()
    local Jobs = require('src.colonist.jobs')
    Jobs.reset()
end

-- Reset social module state (opinions, grieving, event log)
function H.resetSocial()
    local ok, Social = pcall(require, 'src.colonist.social')
    if ok and Social.loadState then Social.loadState({}) end
end

-- Reset raids module state
function H.resetRaids()
    local ok, Raids = pcall(require, 'src.sim.raids')
    if ok and Raids.init then Raids.init() end
end

function H.resetHermes()
    package.loaded['src.sim.hermes'] = nil
end

function H.resetQuotas()
    package.loaded['src.sim.quotas'] = nil
end

function H.resetEasterEggs()
    package.loaded['src.sim.easter_eggs'] = nil
end

function H.resetTuning()
    local ok, Tuning = pcall(require, 'src.sim.tuning')
    if ok and Tuning.clearOverrides then
        Tuning.clearOverrides()
    end
end

-- Reset all state for a clean test
function H.resetAll()
    math.randomseed(12345)
    H.resetTuning()
    H.resetGameState()
    H.resetECS()
    H.resetJobs()
    H.resetSocial()
    H.resetRaids()
    H.resetHermes()
    H.resetQuotas()
    H.resetEasterEggs()
end

-- Create a minimal colonist for testing
function H.spawnTestColonist(x, y, overrides)
    local ECS = require('src.ecs.ecs')
    local Schedule = require('src.colonist.schedule')
    local Jobs = require('src.colonist.jobs')

    local id = ECS.spawn()
    ECS.set(id, 'pos', {
        x = x or 64, y = y or 64,
        prevX = x or 64, prevY = y or 64,
    })
    local col = {
        name = overrides and overrides.name or 'TestColonist',
        backstory = 'A test entity.',
        traits = overrides and overrides.traits or {},
        skills = overrides and overrides.skills or {
            mining = 5, building = 5, cooking = 5,
            hunting = 5, research = 5, medical = 5,
        },
        health = 100, maxHealth = 100, sanity = 100,
        task = nil, state = 'idle',
    }
    if overrides then
        for k, v in pairs(overrides) do
            if k ~= 'skills' and k ~= 'traits' and k ~= 'name' then
                col[k] = v
            end
        end
    end
    ECS.set(id, 'colonist', col)
    ECS.set(id, 'needs', {
        warmth = overrides and overrides.warmth or 80,
        food = overrides and overrides.food or 80,
        rest = overrides and overrides.rest or 80,
        morale = overrides and overrides.morale or 70,
    })
    ECS.set(id, 'inventory', { items = {}, maxWeight = 50, currentWeight = 0 })
    ECS.set(id, 'path', { nodes = nil, index = 1, moveTimer = 0 })
    ECS.set(id, 'schedule', Schedule.default())
    ECS.set(id, 'workPriority', Jobs.defaultPriorities())
    return id
end

-- Create a minimal creature for testing
function H.spawnTestCreature(x, y, overrides)
    local ECS = require('src.ecs.ecs')
    local id = ECS.spawn()
    ECS.set(id, 'pos', {
        x = x or 70, y = y or 70,
        prevX = x or 70, prevY = y or 70,
    })
    ECS.set(id, 'creature', {
        species = overrides and overrides.species or 'frost_hare',
        health = overrides and overrides.health or 20,
        maxHealth = overrides and overrides.maxHealth or 20,
        damage = overrides and overrides.damage or 3,
        hostile = overrides and overrides.hostile or false,
        tier = overrides and overrides.tier or 'small',
        state = 'idle',
        color = { 0.7, 0.7, 0.65 },
        size = 0.4,
        name = overrides and overrides.name or 'TestCreature',
    })
    ECS.set(id, 'path', { nodes = nil, index = 1, moveTimer = 0 })
    return id
end

return H
