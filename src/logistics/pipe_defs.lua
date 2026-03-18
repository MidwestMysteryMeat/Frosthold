------------------------------------------------------------------------
-- pipe_defs.lua — Pure data definitions for the pipe/fluid network
-- No requires. No logic. Just tables.
------------------------------------------------------------------------

local M = {}

------------------------------------------------------------------------
-- FLUIDS — Liquid types that flow through pipes
------------------------------------------------------------------------
-- viscosity: throughput multiplier (higher = slower)
-- freezeTemp: °C below which fluid freezes in pipes
-- burstDamage: damage dealt to room when a frozen pipe bursts
------------------------------------------------------------------------

M.FLUIDS = {
    water = {
        name        = "Water",
        color       = {0.2, 0.4, 0.8},
        viscosity   = 1.0,
        freezeTemp  = 0,
        burstDamage = 3,
    },
    oil = {
        name        = "Crude Oil",
        color       = {0.15, 0.1, 0.05},
        viscosity   = 1.8,
        freezeTemp  = -10,
        burstDamage = 5,
    },
    ichor = {
        name        = "Eldritch Ichor",
        color       = {0.4, 0.1, 0.5},
        viscosity   = 2.5,
        freezeTemp  = -40,
        burstDamage = 8,
    },
    fuel = {
        name        = "Refined Fuel",
        color       = {0.8, 0.5, 0.1},
        viscosity   = 1.2,
        freezeTemp  = -25,
        burstDamage = 6,
    },
    coolant = {
        name        = "Coolant",
        color       = {0.3, 0.8, 0.9},
        viscosity   = 0.9,
        freezeTemp  = -60,
        burstDamage = 2,
    },
    waste = {
        name        = "Waste Water",
        color       = {0.5, 0.4, 0.2},
        viscosity   = 1.1,
        freezeTemp  = -5,
        burstDamage = 4,
    },
}

------------------------------------------------------------------------
-- GASES — Gas types that flow through ducts
------------------------------------------------------------------------
-- density: affects leak rate when duct is damaged
-- toxic: whether exposure harms colonists
-- leakRate: units/s lost through a damaged duct
------------------------------------------------------------------------

M.GASES = {
    oxygen = {
        name     = "Oxygen",
        color    = {0.6, 0.8, 1.0},
        density  = 0.8,
        toxic    = false,
        leakRate = 0.5,
    },
    co2 = {
        name     = "Carbon Dioxide",
        color    = {0.4, 0.4, 0.4},
        density  = 1.2,
        toxic    = false,
        leakRate = 0.3,
    },
    steam = {
        name     = "Steam",
        color    = {0.9, 0.9, 0.95},
        density  = 0.5,
        toxic    = false,
        leakRate = 0.8,
    },
    toxic_gas = {
        name     = "Toxic Gas",
        color    = {0.5, 0.8, 0.2},
        density  = 1.5,
        toxic    = true,
        leakRate = 0.2,
    },
}

------------------------------------------------------------------------
-- PIPE_DEFS — Pipe and duct building types
------------------------------------------------------------------------
-- throughput: units/s per network node
-- medium: 'fluid' or 'gas'
-- durability: HP before the pipe breaks
-- freezeResist: bonus °C tolerance before freezing kicks in
-- leakChanceOnDamage: probability (0-1) of springing a leak per hit
-- cost: resources required to build
------------------------------------------------------------------------

M.PIPE_DEFS = {
    small_pipe = {
        name              = "Small Pipe",
        throughput        = 8,
        medium            = "fluid",
        durability        = 50,
        freezeResist      = 0,
        leakChanceOnDamage = 0.3,
        cost              = {metal = 2},
    },
    large_pipe = {
        name              = "Large Pipe",
        throughput        = 25,
        medium            = "fluid",
        durability        = 80,
        freezeResist      = 5,
        leakChanceOnDamage = 0.2,
        cost              = {metal = 5, components = 1},
    },
    insulated_pipe = {
        name              = "Insulated Pipe",
        throughput        = 12,
        medium            = "fluid",
        durability        = 60,
        freezeResist      = 20,
        leakChanceOnDamage = 0.15,
        cost              = {metal = 3, components = 1},
    },
    small_duct = {
        name              = "Small Duct",
        throughput        = 6,
        medium            = "gas",
        durability        = 40,
        freezeResist      = 0,
        leakChanceOnDamage = 0.4,
        cost              = {metal = 1},
    },
    large_duct = {
        name              = "Large Duct",
        throughput        = 20,
        medium            = "gas",
        durability        = 70,
        freezeResist      = 5,
        leakChanceOnDamage = 0.25,
        cost              = {metal = 4, components = 1},
    },
    sealed_duct = {
        name              = "Sealed Duct",
        throughput        = 10,
        medium            = "gas",
        durability        = 50,
        freezeResist      = 0,
        leakChanceOnDamage = 0.05,
        cost              = {metal = 2, components = 2},
    },
}

------------------------------------------------------------------------
-- TANK_DEFS — Storage buildings for fluids and gases
------------------------------------------------------------------------
-- capacity: maximum stored units
-- pressurized: if true, tank does not leak when damaged
------------------------------------------------------------------------

M.TANK_DEFS = {
    fluid_tank_small = {
        name        = "Small Fluid Tank",
        capacity    = 200,
        medium      = "fluid",
        pressurized = false,
        cost        = {metal = 8},
    },
    fluid_tank_large = {
        name        = "Large Fluid Tank",
        capacity    = 800,
        medium      = "fluid",
        pressurized = false,
        cost        = {metal = 20, steel = 3},
    },
    gas_canister = {
        name        = "Gas Canister",
        capacity    = 150,
        medium      = "gas",
        pressurized = false,
        cost        = {metal = 6},
    },
    pressurized_tank = {
        name        = "Pressurized Tank",
        capacity    = 500,
        medium      = "gas",
        pressurized = true,
        cost        = {steel = 8, components = 3},
    },
}

------------------------------------------------------------------------
-- PROCESSOR_DEFS — Machines that convert, pump, or destroy fluids/gases
------------------------------------------------------------------------
-- inputFluid/outputFluid: key into FLUIDS or GASES (nil if N/A)
-- inputMedium/outputMedium: 'fluid', 'gas', or nil
-- inputRate/outputRate: units/s consumed/produced
-- wasteFluid/wasteRate: secondary output (nil if none)
-- powerDraw: watts consumed
-- powerOutput: watts generated (ichor_converter only)
-- co2Emission: units/s of CO2 released into the room
-- heatConsume: thermal units consumed per tick (steam_boiler)
------------------------------------------------------------------------

M.PROCESSOR_DEFS = {
    water_pump = {
        name         = "Water Pump",
        inputFluid   = nil,
        inputMedium  = nil,
        outputFluid  = "water",
        outputMedium = "fluid",
        inputRate    = 0,
        outputRate   = 3.0,
        wasteFluid   = nil,
        wasteRate    = 0,
        powerDraw    = 15,
        powerOutput  = 0,
        co2Emission  = 0,
        heatConsume  = 0,
        cost         = {metal = 6, components = 2},
    },
    oil_refinery = {
        name         = "Oil Refinery",
        inputFluid   = "oil",
        inputMedium  = "fluid",
        outputFluid  = "fuel",
        outputMedium = "fluid",
        inputRate    = 2.0,
        outputRate   = 1.5,
        wasteFluid   = "waste",
        wasteRate    = 0.5,
        powerDraw    = 35,
        powerOutput  = 0,
        co2Emission  = 0,
        heatConsume  = 0,
        cost         = {metal = 20, components = 5, steel = 3},
    },
    coolant_refiner = {
        name         = "Coolant Refiner",
        inputFluid   = "water",
        inputMedium  = "fluid",
        outputFluid  = "coolant",
        outputMedium = "fluid",
        inputRate    = 1.5,
        outputRate   = 1.0,
        wasteFluid   = nil,
        wasteRate    = 0,
        powerDraw    = 20,
        powerOutput  = 0,
        co2Emission  = 0,
        heatConsume  = 0,
        cost         = {metal = 12, components = 4},
    },
    ichor_converter = {
        name         = "Ichor Converter",
        inputFluid   = "ichor",
        inputMedium  = "fluid",
        outputFluid  = nil,
        outputMedium = nil,
        inputRate    = 0.8,
        outputRate   = 0,
        wasteFluid   = nil,
        wasteRate    = 0,
        powerDraw    = 10,
        powerOutput  = 40,
        co2Emission  = 0,
        heatConsume  = 0,
        cost         = {steel = 10, components = 6, circuit = 2},
    },
    waste_processor = {
        name         = "Waste Processor",
        inputFluid   = "waste",
        inputMedium  = "fluid",
        outputFluid  = nil,
        outputMedium = nil,
        inputRate    = 2.0,
        outputRate   = 0,
        wasteFluid   = nil,
        wasteRate    = 0,
        powerDraw    = 12,
        powerOutput  = 0,
        co2Emission  = 0.05,
        heatConsume  = 0,
        cost         = {metal = 10, components = 3},
    },
    gas_separator = {
        name         = "Gas Separator",
        inputFluid   = "co2",
        inputMedium  = "gas",
        outputFluid  = "oxygen",
        outputMedium = "gas",
        inputRate    = 1.0,
        outputRate   = 0.6,
        wasteFluid   = nil,
        wasteRate    = 0,
        powerDraw    = 25,
        powerOutput  = 0,
        co2Emission  = 0,
        heatConsume  = 0,
        cost         = {steel = 8, components = 5, circuit = 1},
    },
    steam_boiler = {
        name         = "Steam Boiler",
        inputFluid   = "water",
        inputMedium  = "fluid",
        outputFluid  = "steam",
        outputMedium = "gas",
        inputRate    = 1.5,
        outputRate   = 2.0,
        wasteFluid   = nil,
        wasteRate    = 0,
        powerDraw    = 0,
        powerOutput  = 0,
        co2Emission  = 0,
        heatConsume  = 30,
        cost         = {metal = 15, components = 4},
    },
    oil_pump = {
        name         = "Oil Pump",
        inputFluid   = nil,
        inputMedium  = nil,
        outputFluid  = "oil",
        outputMedium = "fluid",
        inputRate    = 0,
        outputRate   = 1.5,
        wasteFluid   = nil,
        wasteRate    = 0,
        powerDraw    = 25,
        powerOutput  = 0,
        co2Emission  = 0,
        heatConsume  = 0,
        cost         = {metal = 12, components = 4, steel = 2},
    },
    fuel_generator = {
        name         = "Fuel Generator",
        inputFluid   = "fuel",
        inputMedium  = "fluid",
        outputFluid  = nil,
        outputMedium = nil,
        inputRate    = 1.0,
        outputRate   = 0,
        wasteFluid   = "waste",
        wasteRate    = 0.1,
        powerDraw    = 0,
        powerOutput  = 60,
        co2Emission  = 0.1,
        heatConsume  = 0,
        cost         = {steel = 6, components = 4, circuit = 1},
    },
    ichor_extractor = {
        name         = "Ichor Extractor",
        inputFluid   = nil,
        inputMedium  = nil,
        outputFluid  = "ichor",
        outputMedium = "fluid",
        inputRate    = 0,
        outputRate   = 0.8,
        wasteFluid   = "waste",
        wasteRate    = 0.2,
        powerDraw    = 20,
        powerOutput  = 0,
        co2Emission  = 0,
        heatConsume  = 0,
        needsEldritchNode = true,
        cost         = {steel = 8, components = 5, circuit = 1},
    },
}

------------------------------------------------------------------------
-- SPILL_EFFECTS — Environmental consequences when fluids/gases escape
------------------------------------------------------------------------
-- tempDelta: instant temperature change to the room (°C)
-- pollutionRate: pollution units/s while spill is active
-- slipHazard: colonists can slip and fall on this
-- toxicRadius: tile radius of toxic zone (0 = non-toxic)
-- duration: seconds the spill persists before evaporating/draining
------------------------------------------------------------------------

M.SPILL_EFFECTS = {
    water = {
        tempDelta     = -5,
        pollutionRate = 0,
        slipHazard    = true,
        toxicRadius   = 0,
        duration      = 30,
    },
    oil = {
        tempDelta     = 0,
        pollutionRate = 0.3,
        slipHazard    = true,
        toxicRadius   = 0,
        duration      = 60,
    },
    ichor = {
        tempDelta     = -10,
        pollutionRate = 0.5,
        slipHazard    = true,
        toxicRadius   = 3,
        duration      = 120,
    },
    fuel = {
        tempDelta     = 0,
        pollutionRate = 0.2,
        slipHazard    = true,
        toxicRadius   = 0,
        duration      = 45,
    },
    coolant = {
        tempDelta     = -15,
        pollutionRate = 0.1,
        slipHazard    = false,
        toxicRadius   = 0,
        duration      = 40,
    },
    waste = {
        tempDelta     = 0,
        pollutionRate = 0.4,
        slipHazard    = true,
        toxicRadius   = 2,
        duration      = 50,
    },
    toxic_gas = {
        tempDelta     = 0,
        pollutionRate = 0.6,
        slipHazard    = false,
        toxicRadius   = 5,
        duration      = 90,
    },
    steam = {
        tempDelta     = 10,
        pollutionRate = 0,
        slipHazard    = false,
        toxicRadius   = 0,
        duration      = 15,
    },
    oxygen = {
        tempDelta     = 0,
        pollutionRate = 0,
        slipHazard    = false,
        toxicRadius   = 0,
        duration      = 10,
    },
    co2 = {
        tempDelta     = 0,
        pollutionRate = 0.1,
        slipHazard    = false,
        toxicRadius   = 2,
        duration      = 30,
    },
}

------------------------------------------------------------------------
-- FREEZE_STAGES — Progression of pipe freezing over time
------------------------------------------------------------------------
-- threshold: seconds the pipe has been below its freeze point
-- stage: human-readable name
-- throughputMult: multiplier on pipe throughput (0 = fully blocked)
-- damagePerTick: HP lost per sim tick while in this stage
-- burstChance: probability per tick of catastrophic burst (0-1)
------------------------------------------------------------------------

M.FREEZE_STAGES = {
    {
        threshold      = 0,
        stage          = "normal",
        throughputMult = 1.0,
        damagePerTick  = 0,
        burstChance    = 0,
    },
    {
        threshold      = 10,
        stage          = "frost_buildup",
        throughputMult = 0.5,
        damagePerTick  = 0,
        burstChance    = 0,
    },
    {
        threshold      = 30,
        stage          = "frozen",
        throughputMult = 0,
        damagePerTick  = 1,
        burstChance    = 0,
    },
    {
        threshold      = 60,
        stage          = "burst_risk",
        throughputMult = 0,
        damagePerTick  = 2,
        burstChance    = 0.2,
    },
    {
        threshold      = 90,
        stage          = "burst",
        throughputMult = 0,
        damagePerTick  = 0,
        burstChance    = 1.0,
    },
}

------------------------------------------------------------------------
-- DAMAGE_TYPES — Sources of pipe/duct damage
------------------------------------------------------------------------
-- name: display name
-- baseDamage: default HP removed per event
------------------------------------------------------------------------

M.DAMAGE_TYPES = {
    temperature = {
        name       = "Freeze Damage",
        baseDamage = 1,
    },
    creature_attack = {
        name       = "Creature Attack",
        baseDamage = 15,
    },
    explosion = {
        name       = "Explosion",
        baseDamage = 30,
    },
    deterioration = {
        name       = "Deterioration",
        baseDamage = 0.1,
    },
}

return M
