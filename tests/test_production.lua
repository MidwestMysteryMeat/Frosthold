-- test_production.lua — Production system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Production')

local Production = require('src.building.production')
local ECS        = require('src.ecs.ecs')

T.test('ITEMS table has expected items', function()
    local expected = { 'raw_wood', 'metal_ingot', 'thermal_core', 'cooked_meat', 'bandage', 'steel', 'fuel_cell' }
    for _, key in ipairs(expected) do
        T.notnil(Production.ITEMS[key], 'missing item: ' .. key)
    end
end)

T.test('each item has name, stack, and category', function()
    for key, item in pairs(Production.ITEMS) do
        T.notnil(item.name, key .. ' missing name')
        T.notnil(item.stack, key .. ' missing stack')
        T.ok(item.stack > 0, key .. ' stack must be positive')
        T.notnil(item.category, key .. ' missing category')
    end
end)

T.test('RECIPES table has recipes with required fields', function()
    local requiredFields = { 'name', 'machine', 'inputs', 'outputs', 'time', 'power', 'skill', 'minSkill' }
    for key, recipe in pairs(Production.RECIPES) do
        for _, field in ipairs(requiredFields) do
            T.notnil(recipe[field], key .. ' missing field: ' .. field)
        end
    end
end)

T.test('recipe inputs and outputs reference valid items', function()
    for key, recipe in pairs(Production.RECIPES) do
        for itemId in pairs(recipe.inputs) do
            T.notnil(Production.ITEMS[itemId], key .. ' input references unknown item: ' .. itemId)
        end
        for itemId in pairs(recipe.outputs) do
            T.notnil(Production.ITEMS[itemId], key .. ' output references unknown item: ' .. itemId)
        end
    end
end)

T.test('MACHINES table has machine definitions with required fields', function()
    local expected = { 'sawmill', 'smelter', 'forge', 'kitchen', 'drug_lab', 'refinery' }
    for _, key in ipairs(expected) do
        T.notnil(Production.MACHINES[key], 'missing machine: ' .. key)
    end
    for key, machine in pairs(Production.MACHINES) do
        T.notnil(machine.name, key .. ' missing name')
        T.notnil(machine.size, key .. ' missing size')
        T.notnil(machine.cost, key .. ' missing cost')
        T.notnil(machine.powerDraw, key .. ' missing powerDraw')
    end
end)

T.test('every recipe references a valid machine', function()
    for key, recipe in pairs(Production.RECIPES) do
        T.notnil(Production.MACHINES[recipe.machine], key .. ' references unknown machine: ' .. recipe.machine)
    end
end)

T.test('placeMachine creates entity with machine component', function()
    H.resetAll()
    local id = Production.placeMachine('sawmill', 5, 5)
    T.notnil(id, 'placeMachine returned an id')
    T.ok(ECS.has(id, 'pos'), 'entity has pos')
    T.ok(ECS.has(id, 'machine'), 'entity has machine')

    local machine = ECS.get(id, 'machine')
    T.eq(machine.type, 'sawmill', 'machine type')
    T.eq(machine.name, 'Sawmill', 'machine name from definition')
    T.isnil(machine.recipe, 'no recipe set initially')
    T.eq(machine.active, false, 'not active initially')
end)

T.test('placeMachine returns nil for unknown machine type', function()
    H.resetAll()
    local id = Production.placeMachine('nonexistent_machine', 5, 5)
    T.isnil(id, 'nil for unknown machine')
end)

T.test('getRecipesForMachine returns correct recipes', function()
    local kitchenRecipes = Production.getRecipesForMachine('kitchen')
    T.ok(#kitchenRecipes > 0, 'kitchen has recipes')
    for _, entry in ipairs(kitchenRecipes) do
        T.eq(entry.recipe.machine, 'kitchen', 'recipe belongs to kitchen')
    end

    local forgeRecipes = Production.getRecipesForMachine('forge')
    T.ok(#forgeRecipes > 0, 'forge has recipes')
    for _, entry in ipairs(forgeRecipes) do
        T.eq(entry.recipe.machine, 'forge', 'recipe belongs to forge')
    end
end)

T.test('hidden legacy recipes do not surface in machine recipe lists', function()
    local vehicleRecipes = Production.getRecipesForMachine('vehicle_workbench')
    T.eq(#vehicleRecipes, 0, 'archived vehicle recipes stay hidden')
end)

T.test('DRUG_EFFECTS has expected entries with duration and effects', function()
    local expected = { 'spike', 'stardust', 'drift', 'smog', 'rotgut' }
    for _, key in ipairs(expected) do
        T.notnil(Production.DRUG_EFFECTS[key], 'missing drug: ' .. key)
        local drug = Production.DRUG_EFFECTS[key]
        T.notnil(drug.name, key .. ' missing name')
        T.notnil(drug.duration, key .. ' missing duration')
        T.ok(drug.duration > 0, key .. ' duration must be positive')
        T.notnil(drug.effects, key .. ' missing effects')
    end
end)

T.test('FOOD_QUALITY has expected entries with nutrition and morale', function()
    local expected = { 'raw_meat', 'cooked_meat', 'stew', 'jerky', 'feast' }
    for _, key in ipairs(expected) do
        T.notnil(Production.FOOD_QUALITY[key], 'missing food quality: ' .. key)
        local fq = Production.FOOD_QUALITY[key]
        T.notnil(fq.nutrition, key .. ' missing nutrition')
        T.notnil(fq.morale, key .. ' missing morale')
        T.notnil(fq.quality, key .. ' missing quality tier')
    end
end)
