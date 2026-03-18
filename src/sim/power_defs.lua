-- power_defs.lua — Generator type definitions for the power grid system
-- Extracted from power.lua to keep each file under 1000 lines.

local GENERATORS = {
    campfire_gen = {
        name     = 'Campfire',
        output   = 10,    -- watts
        fuelType = 'raw_wood',
        fuelRate = 0.1,   -- items per second
        co2Mult  = 1.0,   -- base CO2 multiplier
    },
    coal_burner = {
        name     = 'Coal Burner',
        output   = 30,
        fuelType = 'coal',
        fuelRate = 0.05,
        co2Mult  = 1.5,
    },
    thermal_gen = {
        name     = 'Thermal Generator',
        output   = 80,
        fuelType = 'thermal_core',
        fuelRate = 0.01,
        co2Mult  = 0.5,
    },
    fuel_cell_gen = {
        name     = 'Fuel Cell Generator',
        output   = 50,
        fuelType = 'fuel_cell',
        fuelRate = 0.02,
        co2Mult  = 0.3,
    },
    lava_tap = {
        name     = 'Lava Vent Tap',
        output   = 100,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
    },
    solar_panel = {
        name     = 'Solar Panel',
        output   = 40,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'solar',
    },
    tracking_solar = {
        name     = 'Tracking Solar Array',
        output   = 65,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'solar',
    },
    concentrated_solar = {
        name     = 'Concentrated Solar',
        output   = 100,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'solar',
    },
    wind_turbine = {
        name     = 'Wind Turbine',
        output   = 55,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'wind',
    },
    large_wind_turbine = {
        name     = 'Large Wind Turbine',
        output   = 90,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'wind',
    },
    advanced_turbine = {
        name     = 'Advanced Turbine',
        output   = 130,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'wind',
    },
    geothermal = {
        name     = 'Geothermal Vent',
        output   = 120,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0.2,
    },
    gas_burner = {
        name     = 'Gas Burner',
        output   = 45,
        fuelType = 'coal',
        fuelRate = 0.04,
        co2Mult  = 2.0,
    },
    nuclear_reactor = {
        name     = 'Nuclear Reactor',
        output   = 250,
        fuelType = 'thermal_core',
        fuelRate = 0.005,
        co2Mult  = 0.1,
        meltdownRisk = 0.0005,
    },
    chemical_burner = {
        name     = 'Chemical Burner',
        output   = 60,
        fuelType = 'components',
        fuelRate = 0.03,
        co2Mult  = 3.0,
    },
    -- fire_pit and deep_fire_pit are heat-only buildings, not power generators
    bio_reactor = {
        name     = 'Bio Reactor',
        output   = 35,
        fuelType = 'food',
        fuelRate = 0.06,
        co2Mult  = 0.8,
    },
    mini_reactor = {
        name     = 'Mini Reactor',
        output   = 90,
        fuelType = 'thermal_core',
        fuelRate = 0.008,
        co2Mult  = 0.1,
        meltdownRisk = 0.0001,
    },
    steam_turbine = {
        name     = 'Steam Turbine',
        output   = 65,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'heat',
    },
    hand_crank = {
        name     = 'Hand Crank Generator',
        output   = 12,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        manned   = true,
    },
    treadmill = {
        name     = 'Treadmill Generator',
        output   = 25,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        manned   = true,
        laborType = 'forced',
    },
    chain_gang_wheel = {
        name     = 'Chain Gang Wheel',
        output   = 50,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        manned   = true,
        laborType = 'forced',
        crewSize = 3,
    },
    waste_incinerator = {
        name     = 'Waste Incinerator',
        output   = 40,
        fuelType = 'corpse_creature',
        fuelRate = 0.02,
        co2Mult  = 4.0,
        heatOutput = 45,
    },
    hydrogen_cell = {
        name     = 'Hydrogen Fuel Cell',
        output   = 70,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'water',
    },
    lightning_rod = {
        name     = 'Lightning Rod',
        output   = 200,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'storm',
    },
    thermopile = {
        name     = 'Thermopile',
        output   = 25,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'thermal_diff',
    },
    ichor_burner = {
        name     = 'Ichor Burner',
        output   = 55,
        fuelType = 'eldritch_ichor',
        fuelRate = 0.035,
        co2Mult  = 1.8,
        heatOutput = 50,
    },

    -- Cryo-kinetic engine: generates power FROM cold — more output in lower temps
    cryo_kinetic = {
        name     = 'Cryo-Kinetic Engine',
        output   = 60,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'cold',
    },

    -- Methane digester: ferments organic waste into biogas for power
    methane_digester = {
        name     = 'Methane Digester',
        output   = 40,
        fuelType = 'food',
        fuelRate = 0.04,
        co2Mult  = 0.6,
        heatOutput = 20,
    },

    -- Plasma arc reactor: extreme output, burns steel, massive heat + CO2
    plasma_arc = {
        name     = 'Plasma Arc Reactor',
        output   = 180,
        fuelType = 'steel',
        fuelRate = 0.015,
        co2Mult  = 2.5,
        heatOutput = 100,
        meltdownRisk = 0.0003,
    },

    -- Stirling engine: improved thermopile, higher output from temp differential
    stirling_engine = {
        name     = 'Stirling Engine',
        output   = 45,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'thermal_diff',
    },

    -- Penrose engine: endgame exotic, eldritch-powered perpetual motion
    penrose_engine = {
        name     = 'Penrose Engine',
        output   = 100,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
    },

    -- Dynamo: colonist-operated but more efficient than hand crank, any worker
    dynamo = {
        name     = 'Dynamo',
        output   = 20,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        manned   = true,
    },

    -- Peat burner: burns peat/organic matter, early-mid game, decent heat
    peat_burner = {
        name     = 'Peat Burner',
        output   = 25,
        fuelType = 'any',
        fuelRate = 0.06,
        co2Mult  = 1.3,
        heatOutput = 55,
    },

    -- Fusion reactor: endgame, massive output, no fuel, requires research
    fusion_reactor = {
        name     = 'Fusion Reactor',
        output   = 400,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        meltdownRisk = 0.0001,
    },

    -- Ichor converter byproduct: processor that generates 40W as a side effect
    ichor_converter = {
        name     = 'Ichor Converter',
        output   = 40,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0.4,
    },
    -- Fuel generator: burns refined fuel from pipe network for power
    fuel_generator = {
        name     = 'Fuel Generator',
        output   = 60,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0.5,
    },

    -- Tidal generator: uses ocean currents, surface only on ocean worlds
    tidal_generator = {
        name     = 'Tidal Generator',
        output   = 70,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'water',  -- scales with water proximity
    },

    -- Thermal vent tap (underwater): taps volcanic vents on ocean floor
    thermal_vent_tap = {
        name     = 'Thermal Vent Tap',
        output   = 110,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        heatOutput = 30,
    },

    -- Current turbine: underwater turbine, constant low output
    current_turbine = {
        name     = 'Current Turbine',
        output   = 45,
        fuelType = nil,
        fuelRate = 0,
        co2Mult  = 0,
        intermittent = 'water',
    },
}

return GENERATORS
