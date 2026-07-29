-- test_power.lua — Power grid system tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Power')

local Power = require('src.sim.power')

T.test('GENERATORS table has expected definitions', function()
    local expected = { 'campfire_gen', 'coal_burner', 'thermal_gen', 'fuel_cell_gen', 'lava_tap' }
    for _, key in ipairs(expected) do
        T.notnil(Power.GENERATORS[key], 'missing generator: ' .. key)
    end
end)

T.test('each generator has name and output', function()
    for key, gen in pairs(Power.GENERATORS) do
        T.notnil(gen.name, key .. ' missing name')
        T.notnil(gen.output, key .. ' missing output')
        T.ok(gen.output > 0, key .. ' output must be positive')
    end
end)

T.test('init resets all state', function()
    Power.init()
    T.eq(Power.getTotalSupply(), 0, 'no supply after init')
    T.eq(Power.getTotalDemand(), 0, 'no demand after init')
end)

T.test('addConduit and removeConduit', function()
    Power.init()
    -- addConduit should not error
    T.no_throw(function() Power.addConduit(5, 5) end, 'addConduit does not throw')
    -- removeConduit should not error
    T.no_throw(function() Power.removeConduit(5, 5) end, 'removeConduit does not throw')
end)

T.test('addGenerator registers a generator', function()
    H.resetAll()
    Power.init()
    Power.addGenerator(999, 'thermal_gen', 10, 10)
    -- Step to rebuild grid so supply is calculated
    Power.step(3)
    T.gt(Power.getTotalSupply(), 0, 'supply > 0 after adding generator')
end)

T.test('addConsumer registers demand', function()
    H.resetAll()
    Power.init()
    Power.addGenerator(100, 'thermal_gen', 5, 5)
    Power.addConsumer(200, 20, 6, 5)
    Power.step(3)
    T.gt(Power.getTotalDemand(), 0, 'demand > 0 after adding consumer')
end)

T.test('getTotalSupply sums generator output', function()
    H.resetAll()
    Power.init()
    Power.addGenerator(100, 'campfire_gen', 5, 5)
    Power.addGenerator(101, 'coal_burner', 6, 5)
    Power.step(3)
    local expected = Power.GENERATORS.campfire_gen.output + Power.GENERATORS.coal_burner.output
    T.eq(Power.getTotalSupply(), expected, 'total supply matches sum of generators')
end)

T.test('isGridPowered returns true when supply meets demand', function()
    H.resetAll()
    Power.init()
    -- Generator at (5,5), consumer at (6,5) — adjacent, so connected via conduits
    Power.addGenerator(100, 'thermal_gen', 5, 5)  -- 80W
    Power.addConsumer(200, 10, 6, 5)                -- 10W demand
    Power.step(3)
    T.ok(Power.isGridPowered(6, 5), 'consumer tile is powered')
end)

T.test('isGridPowered returns false for disconnected consumer', function()
    H.resetAll()
    Power.init()
    Power.addGenerator(100, 'thermal_gen', 5, 5)
    Power.addConsumer(200, 10, 50, 50)  -- far away, not connected
    Power.step(3)
    T.eq(Power.isGridPowered(50, 50), false, 'disconnected consumer is not powered')
end)

T.test('electric heat buildings require grid power and recover after reload', function()
    H.resetAll()
    local World = require('src.world.tilemap')
    local Thermal = require('src.sim.thermal')
    local Building = require('src.building.building')

    World.init(16, 16)
    Thermal.init(World)
    Building.loadState({})
    Power.init()

    local placed = Building.tryPlace('heater', 6, 6, nil, true)
    T.ok(placed, 'heater placed')
    T.eq(Thermal.getHeatAt(6, 6), 0, 'unpowered heater emits no heat')

    Power.addGenerator(900, 'thermal_gen', 5, 6)
    Power.step(3)
    Building.update(0.1)
    T.eq(Thermal.getHeatAt(6, 6), 80, 'powered heater emits rated heat')

    local saved = Building.getState()
    Thermal.init(World)
    Building.loadState(saved)
    Power.init()
    Building.restorePowerConsumers()
    Power.addGenerator(901, 'thermal_gen', 5, 6)
    Power.step(3)
    Building.update(0.1)
    T.eq(Thermal.getHeatAt(6, 6), 80, 'loaded heater reconnects to power')

    Power.removeGenerator(901)
    Power.step(3)
    Building.update(0.1)
    T.eq(Thermal.getHeatAt(6, 6), 0, 'heater stops when grid power is lost')
end)

T.test('isGeneratorFaulted and repairGenerator', function()
    H.resetAll()
    Power.init()
    Power.addGenerator(100, 'coal_burner', 5, 5)

    T.eq(Power.isGeneratorFaulted(100), false, 'generator starts unfaulted')

    -- Manually fault the generator through repair/fault cycle test
    -- Since faulting is random, we test repairGenerator directly
    local repaired = Power.repairGenerator(100)
    T.ok(repaired, 'repairGenerator returns true for valid generator')

    T.eq(Power.isGeneratorFaulted(100), false, 'generator is not faulted after repair')
end)

T.test('repairGenerator returns false for nonexistent generator', function()
    Power.init()
    T.eq(Power.repairGenerator(9999), false, 'false for unknown generator')
end)
