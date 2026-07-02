-- FROSTHOLD — Game State Invariant Checker
-- src/testing/invariants.lua
-- Verifies game state consistency. Detects impossible/invalid states.

local Invariants = {}

---------------------------------------------------------------------------
-- Check results
---------------------------------------------------------------------------

local function check(condition, category, message, data)
    if condition then
        return nil
    end
    return {
        category = category,
        message = message,
        data = data or {},
    }
end

---------------------------------------------------------------------------
-- ECS Invariants
---------------------------------------------------------------------------

function Invariants.checkECS()
    local violations = {}
    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if not ok then return violations end

    -- Every entity with 'colonist' must have 'pos' and 'needs'
    for id, comps in ECS.query('colonist') do
        local pos = ECS.get(id, 'pos')
        local needs = ECS.get(id, 'needs')

        if not pos then
            violations[#violations + 1] = check(false, 'ecs_missing_component',
                'Colonist entity ' .. id .. ' missing pos component',
                { entityId = id })
        end

        if not needs then
            violations[#violations + 1] = check(false, 'ecs_missing_component',
                'Colonist entity ' .. id .. ' missing needs component',
                { entityId = id })
        end

        -- Health bounds
        local col = comps.colonist
        if col then
            if col.health and col.health < 0 then
                violations[#violations + 1] = check(false, 'invalid_value',
                    'Colonist ' .. (col.name or id) .. ' has negative health: ' .. col.health,
                    { entityId = id, health = col.health })
            end
            if col.health and col.maxHealth and col.health > col.maxHealth * 1.5 then
                violations[#violations + 1] = check(false, 'invalid_value',
                    'Colonist ' .. (col.name or id) .. ' health exceeds max: ' .. col.health .. '/' .. col.maxHealth,
                    { entityId = id, health = col.health, maxHealth = col.maxHealth })
            end
        end
    end

    -- Every entity with 'creature' must have 'pos'
    for id, comps in ECS.query('creature') do
        local pos = ECS.get(id, 'pos')
        if not pos then
            violations[#violations + 1] = check(false, 'ecs_missing_component',
                'Creature entity ' .. id .. ' missing pos component',
                { entityId = id })
        end

        local cr = comps.creature
        if cr then
            if cr.health and cr.health < 0 then
                violations[#violations + 1] = check(false, 'invalid_value',
                    'Creature ' .. (cr.species or id) .. ' has negative health: ' .. cr.health,
                    { entityId = id, health = cr.health })
            end
        end
    end

    -- Position bounds check
    local GameState = require('src.game_state')
    local mapW = GameState.mapWidth or 128
    local mapH = GameState.mapHeight or 128

    for id, comps in ECS.query('pos') do
        local pos = comps.pos
        if pos.x and (pos.x < 0 or pos.x >= mapW) then
            violations[#violations + 1] = check(false, 'out_of_bounds',
                'Entity ' .. id .. ' x position out of bounds: ' .. pos.x,
                { entityId = id, x = pos.x, mapWidth = mapW })
        end
        if pos.y and (pos.y < 0 or pos.y >= mapH) then
            violations[#violations + 1] = check(false, 'out_of_bounds',
                'Entity ' .. id .. ' y position out of bounds: ' .. pos.y,
                { entityId = id, y = pos.y, mapHeight = mapH })
        end
    end

    return violations
end

---------------------------------------------------------------------------
-- Resource Invariants
---------------------------------------------------------------------------

function Invariants.checkResources()
    local violations = {}
    local GameState = require('src.game_state')
    local resources = GameState.resources or {}

    for name, amount in pairs(resources) do
        if type(amount) ~= 'number' then
            violations[#violations + 1] = check(false, 'invalid_type',
                'Resource ' .. name .. ' is not a number: ' .. type(amount),
                { resource = name, value = amount })
        elseif amount < 0 then
            violations[#violations + 1] = check(false, 'negative_resource',
                'Resource ' .. name .. ' is negative: ' .. amount,
                { resource = name, amount = amount })
        elseif amount ~= amount then  -- NaN check
            violations[#violations + 1] = check(false, 'nan_resource',
                'Resource ' .. name .. ' is NaN',
                { resource = name })
        elseif amount == math.huge or amount == -math.huge then
            violations[#violations + 1] = check(false, 'infinite_resource',
                'Resource ' .. name .. ' is infinite',
                { resource = name, amount = amount })
        end
    end

    return violations
end

---------------------------------------------------------------------------
-- Tilemap Invariants
---------------------------------------------------------------------------

function Invariants.checkTilemap()
    local violations = {}
    local ok, World = pcall(require, 'src.world.tilemap')
    if not ok or not World.getTile then return violations end

    local GameState = require('src.game_state')
    local mapW = GameState.mapWidth or 128
    local mapH = GameState.mapHeight or 128

    -- Sample check (full map check would be too slow)
    local sampleSize = 100
    for _ = 1, sampleSize do
        local x = math.random(0, mapW - 1)
        local y = math.random(0, mapH - 1)
        local tile = World.getTile(x, y)

        if tile and tile ~= tile then  -- NaN check
            violations[#violations + 1] = check(false, 'nan_tile',
                'Tile at ' .. x .. ',' .. y .. ' is NaN',
                { x = x, y = y })
        end
    end

    return violations
end

---------------------------------------------------------------------------
-- Thermal Invariants
---------------------------------------------------------------------------

function Invariants.checkThermal()
    local violations = {}
    local GameState = require('src.game_state')

    -- Global temp should be within sane bounds (-100 to 100 C)
    local temp = GameState.globalTemp or 0
    if temp < -150 then
        violations[#violations + 1] = check(false, 'extreme_temp',
            'Global temperature impossibly low: ' .. temp,
            { temp = temp })
    elseif temp > 100 then
        violations[#violations + 1] = check(false, 'extreme_temp',
            'Global temperature impossibly high: ' .. temp,
            { temp = temp })
    end

    -- Check for NaN
    if temp ~= temp then
        violations[#violations + 1] = check(false, 'nan_temp',
            'Global temperature is NaN', {})
    end

    return violations
end

---------------------------------------------------------------------------
-- Needs Invariants
---------------------------------------------------------------------------

function Invariants.checkNeeds()
    local violations = {}
    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if not ok then return violations end

    for id, comps in ECS.query('needs') do
        local needs = comps.needs
        local needsList = { 'warmth', 'food', 'rest', 'morale' }

        for _, needName in ipairs(needsList) do
            local val = needs[needName]
            if val then
                if val ~= val then  -- NaN
                    violations[#violations + 1] = check(false, 'nan_need',
                        'Entity ' .. id .. ' need ' .. needName .. ' is NaN',
                        { entityId = id, need = needName })
                elseif val < -10 then  -- Allow slight negative for edge cases
                    violations[#violations + 1] = check(false, 'negative_need',
                        'Entity ' .. id .. ' need ' .. needName .. ' too negative: ' .. val,
                        { entityId = id, need = needName, value = val })
                elseif val > 200 then  -- Allow some overfill
                    violations[#violations + 1] = check(false, 'excessive_need',
                        'Entity ' .. id .. ' need ' .. needName .. ' too high: ' .. val,
                        { entityId = id, need = needName, value = val })
                end
            end
        end
    end

    return violations
end

---------------------------------------------------------------------------
-- Jobs Invariants
---------------------------------------------------------------------------

function Invariants.checkJobs()
    local violations = {}
    local ok, Jobs = pcall(require, 'src.colonist.jobs')
    if not ok or not Jobs.getAllTasks then return violations end

    local tasks = Jobs.getAllTasks()
    local ECS = require('src.ecs.ecs')

    for taskId, task in pairs(tasks) do
        -- Task positions should be valid
        if task.x and task.y then
            local GameState = require('src.game_state')
            local mapW = GameState.mapWidth or 128
            local mapH = GameState.mapHeight or 128

            if task.x < 0 or task.x >= mapW or task.y < 0 or task.y >= mapH then
                violations[#violations + 1] = check(false, 'invalid_task_pos',
                    'Task ' .. taskId .. ' position out of bounds: ' .. task.x .. ',' .. task.y,
                    { taskId = taskId, x = task.x, y = task.y })
            end
        end

        -- Assigned colonist should exist
        if task.assignedTo then
            if not ECS.get(task.assignedTo, 'colonist') then
                violations[#violations + 1] = check(false, 'orphan_task',
                    'Task ' .. taskId .. ' assigned to non-existent colonist ' .. task.assignedTo,
                    { taskId = taskId, assignedTo = task.assignedTo })
            end
        end
    end

    return violations
end

---------------------------------------------------------------------------
-- Power Grid Invariants
---------------------------------------------------------------------------

function Invariants.checkPower()
    local violations = {}
    local ok, Power = pcall(require, 'src.sim.power')
    if not ok then return violations end

    -- Total consumption shouldn't be negative
    if Power.getConsumption then
        local consumption = Power.getConsumption()
        if consumption and consumption < 0 then
            violations[#violations + 1] = check(false, 'negative_power',
                'Total power consumption is negative: ' .. consumption,
                { consumption = consumption })
        end
    end

    return violations
end

---------------------------------------------------------------------------
-- Combat Invariants
---------------------------------------------------------------------------

function Invariants.checkCombat()
    local violations = {}
    local ok, ECS = pcall(require, 'src.ecs.ecs')
    if not ok then return violations end

    -- Check wounds
    for id, comps in ECS.query('wounds') do
        local wounds = comps.wounds
        if wounds and wounds.list then
            for i, wound in ipairs(wounds.list) do
                if wound.severity and (wound.severity < 0 or wound.severity > 2) then
                    violations[#violations + 1] = check(false, 'invalid_wound_severity',
                        'Entity ' .. id .. ' wound ' .. i .. ' has invalid severity: ' .. wound.severity,
                        { entityId = id, woundIndex = i, severity = wound.severity })
                end
            end
        end
    end

    return violations
end

---------------------------------------------------------------------------
-- Master check function
---------------------------------------------------------------------------

function Invariants.checkAll()
    local allViolations = {}

    local checks = {
        { name = 'ECS', fn = Invariants.checkECS },
        { name = 'Resources', fn = Invariants.checkResources },
        { name = 'Tilemap', fn = Invariants.checkTilemap },
        { name = 'Thermal', fn = Invariants.checkThermal },
        { name = 'Needs', fn = Invariants.checkNeeds },
        { name = 'Jobs', fn = Invariants.checkJobs },
        { name = 'Power', fn = Invariants.checkPower },
        { name = 'Combat', fn = Invariants.checkCombat },
    }

    for _, check in ipairs(checks) do
        local ok, violations = pcall(check.fn)
        if ok and violations then
            for _, v in ipairs(violations) do
                v.checkName = check.name
                allViolations[#allViolations + 1] = v
            end
        elseif not ok then
            allViolations[#allViolations + 1] = {
                checkName = check.name,
                category = 'check_error',
                message = 'Check failed with error: ' .. tostring(violations),
                data = {},
            }
        end
    end

    return allViolations
end

---------------------------------------------------------------------------
-- Quick validation (returns true/false)
---------------------------------------------------------------------------

function Invariants.isValid()
    local violations = Invariants.checkAll()
    return #violations == 0, violations
end

return Invariants
