local Tiles = require('src.world.tiles')

return {
    -- Medical
    med_bench = {
        name = 'Medical Bench', desc = 'Crafts medicine and medical supplies.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 8, components = 3 },
        entitySpawn = 'machine',
        machineType = 'med_bench',
    },

    -- Deep drilling
    deep_drill = {
        name = 'Deep Drill', desc = 'Automated deep extraction. 50W. Rare resources. Attracts creatures.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { steel = 10, components = 5, circuit = 2 },
        entitySpawn = 'deep_drill',
        powerDraw = 50,
    },

    -- Conditional automation (archived)
    circuit_sensor = {
        name = 'Sensor', desc = 'Detects temperature, light, or presence. Outputs a signal.',
        w = 1, h = 1,
        tile = nil,
        cost = { metal = 3, components = 2, circuit = 1 },
        entitySpawn = 'circuit',
        circuitType = 'circuit_sensor',
        hidden = true,
    },
    circuit_comparator = {
        name = 'Comparator', desc = 'Compares two signals. Outputs true or false.',
        w = 1, h = 1,
        tile = nil,
        cost = { metal = 2, components = 2, circuit = 1 },
        entitySpawn = 'circuit',
        circuitType = 'circuit_comparator',
        hidden = true,
    },
    circuit_actuator = {
        name = 'Actuator', desc = 'Opens doors, toggles heaters, or triggers alarms from a signal.',
        w = 1, h = 1,
        tile = nil,
        cost = { metal = 3, components = 2, circuit = 1 },
        entitySpawn = 'circuit',
        circuitType = 'circuit_actuator',
        hidden = true,
    },

    -- Expedition
    expedition_table = {
        name = 'Expedition Table', desc = 'Plan and launch off-map expeditions from here.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_WOOD,
        cost = { wood = 10, metal = 5, components = 2 },
        entitySpawn = 'expedition_table',
    },

    -- Quest
    quest_board = {
        name = 'Quest Board', desc = 'Post and track colony objectives. Check for new contracts.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_WOOD,
        cost = { wood = 8, metal = 2 },
        entitySpawn = 'quest_board',
    },

    -- Cryogenic
    cryo_pod = {
        name = 'Cryo Pod', desc = 'Suspends a colonist indefinitely. Keeps them alive until treatment is ready.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { steel = 10, components = 5, circuit = 3 },
        entitySpawn = 'cryo_pod',
        powerDraw = 25,
    },

    -- Pollution
    scrubber = {
        name = 'Scrubber', desc = 'Reduces pollution in nearby tiles. Requires power.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 10, components = 4, circuit = 1 },
        entitySpawn = 'scrubber',
        powerDraw = 20,
    },

    containment_cell = {
        name = 'Containment Cell', desc = 'Powered quarantine room for live subjects, survivors, and anything that still talks back.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 14, components = 5, circuit = 2 },
        entitySpawn = 'containment',
        cellType = 'cell',
        powerDraw = 22,
    },
    anomaly_locker = {
        name = 'Anomaly Locker', desc = 'Cold storage for artifacts, tissue, and sealed anomaly samples.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 10, components = 3, circuit = 1 },
        entitySpawn = 'containment',
        cellType = 'locker',
        powerDraw = 12,
    },

    -- Flooding control
    sump_pump = {
        name = 'Sump Pump', desc = 'Drains water from flooded rooms. Keep the underground dry.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 8, components = 3 },
        entitySpawn = 'sump_pump',
        powerDraw = 15,
    },

    -- Structural support
    wood_column = {
        name = 'Wood Column', desc = 'Cheap support. Prevents cave-ins but degrades over time and supports less area.',
        w = 1, h = 1,
        tile = Tiles.SUPPORT_COLUMN_WOOD,
        cost = { wood = 6 },
    },
    support_column = {
        name = 'Stone Column', desc = 'Durable support. No degradation. Covers a wide area around itself.',
        w = 1, h = 1,
        tile = Tiles.SUPPORT_COLUMN,
        cost = { stone = 8, metal = 2 },
    },
    reinforced_column = {
        name = 'Reinforced Column', desc = 'Maximum structural support. Holds up massive underground halls.',
        w = 1, h = 1,
        tile = Tiles.REINFORCED_COLUMN,
        cost = { metal = 10, components = 4 },
    },

    -- Recreation
    bonfire = {
        name = 'Bonfire', desc = 'Outdoor gathering spot. Cheap warmth and a little joy.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_STONE,
        cost = { wood = 8 },
        heatOutput = 30,
        -- Warmth zone: heats nearby tiles even outdoors (capped so it never
        -- overheats an already-warm room).
        heatDanger = { radius = 4, tempOffset = 60, maxTemp = 25 },
        lightPreset = 'campfire',
        sightRadius = 5,
        entitySpawn = 'recreation',
        recType = 'bonfire', recJoy = 0.08, recCapacity = 6,
    },
    card_table = {
        name = 'Card Table', desc = 'Two colonists play cards. Builds social bonds.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_WOOD,
        cost = { wood = 10 },
        entitySpawn = 'recreation',
        recType = 'card_table', recJoy = 0.12, recCapacity = 2,
    },
    tavern_bar = {
        name = 'Tavern Bar', desc = 'Serves drinks and raises spirits. Consumes food slowly.',
        w = 2, h = 1,
        tile = Tiles.FLOOR_WOOD,
        cost = { wood = 20, metal = 5 },
        entitySpawn = 'recreation',
        recType = 'tavern', recJoy = 0.15, recCapacity = 4,
    },
    sparring_ring = {
        name = 'Sparring Ring', desc = 'Colonists train combat skills while blowing off steam.',
        w = 2, h = 2,
        tile = Tiles.FLOOR_STONE,
        cost = { wood = 15, metal = 5 },
        entitySpawn = 'recreation',
        recType = 'sparring', recJoy = 0.10, recCapacity = 2,
    },
    library = {
        name = 'Library', desc = 'Quiet reading. Slow joy but boosts research speed nearby.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_WOOD,
        cost = { wood = 15, components = 2 },
        entitySpawn = 'recreation',
        recType = 'library', recJoy = 0.06, recCapacity = 3,
    },
    radio_set = {
        name = 'Radio Set', desc = 'Plays music from old broadcasts. Small footprint, decent mood lift.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 8, components = 3 },
        powerDraw = 5,
        entitySpawn = 'recreation',
        recType = 'radio', recJoy = 0.10, recCapacity = 4,
    },

    -- Storage buildings
    crate = {
        name = 'Crate', desc = 'Basic open-top wooden crate. No environmental protection.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_WOOD,
        cost = { wood = 10 },
        entitySpawn = 'storage',
    },
    locker = {
        name = 'Locker', desc = 'Metal locker. Keeps contents dry and away from the cold.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 8 },
        entitySpawn = 'storage',
    },
    shelf = {
        name = 'Shelf', desc = 'Wide wall-mounted shelf. Open storage, decent capacity.',
        w = 2, h = 1,
        tile = Tiles.FLOOR_WOOD,
        cost = { wood = 8, metal = 2 },
        entitySpawn = 'storage',
    },
    chest = {
        name = 'Chest', desc = 'Sealed metal chest. Protects contents from weather, cold, and heat.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 12, stone = 5 },
        entitySpawn = 'storage',
    },
    cold_storage = {
        name = 'Cold Storage Unit', desc = 'Powered refrigeration unit. Keeps perishables frozen indefinitely.',
        w = 2, h = 2,
        tile = Tiles.FLOOR_METAL,
        cost = { steel = 8, components = 3, circuit = 1 },
        entitySpawn = 'storage',
        powerDraw = 20,
    },
    lead_vault = {
        name = 'Lead-lined Vault', desc = 'Radiation-shielded vault for hazardous materials and radioactive cargo.',
        w = 2, h = 2,
        tile = Tiles.FLOOR_METAL,
        cost = { lead = 15, steel = 5 },
        entitySpawn = 'storage',
    },
    bulk_silo = {
        name = 'Bulk Silo', desc = 'Enormous silo for a single item category. Maximum bulk capacity.',
        w = 3, h = 3,
        tile = Tiles.FLOOR_METAL,
        cost = { steel = 20, stone = 15, components = 5 },
        entitySpawn = 'storage',
    },

    ---------------------------------------------------------------------------
    -- Underwater / Pressure buildings (Nerthus-9, shared with Nemaea airlocks)
    ---------------------------------------------------------------------------

    airlock = {
        name = 'Airlock', desc = 'Sealed transition chamber. Keeps water and vacuum out. Cycles open/closed.',
        w = 1, h = 1,
        tile = Tiles.DOOR_SEALED,
        cost = { steel = 12, components = 5, circuit = 2 },
        powerDraw = 10,
        category = 'infrastructure',
    },

    pressure_dome = {
        name = 'Pressure Dome', desc = 'Sealed dome. Pushes water out of a 5x5 area when powered. Build habs inside.',
        w = 3, h = 3,
        tile = Tiles.FLOOR_INSULATED,
        cost = { steel = 30, components = 10, circuit = 4, glass = 6 },
        powerDraw = 40,
        category = 'infrastructure',
    },

    diving_bell = {
        name = 'Diving Bell', desc = 'Descent chamber. Enter on land, ride it down. Refills suit O2.',
        w = 2, h = 2,
        tile = Tiles.FLOOR_METAL,
        cost = { steel = 20, components = 8, circuit = 3 },
        powerDraw = 25,
        category = 'infrastructure',
    },

    submersible = {
        name = 'Submersible', desc = 'Sealed pod. Carries 2 between depths. Pressure-rated, O2 supply. Something about it unsettles crew named Fischbach.',
        w = 1, h = 3,
        tile = Tiles.SEALED_FLOOR,
        cost = { steel = 30, components = 12, circuit = 5, glass = 8 },
        powerDraw = 35,
        category = 'infrastructure',
        underwaterOnly = false,
    },

    o2_generator = {
        name = 'Electrolyzer', desc = 'Splits water into breathable oxygen. Need it for any sealed hab.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { steel = 15, components = 6, circuit = 3 },
        entitySpawn = 'machine',
        machineType = 'electrolyzer',
        powerDraw = 30,
        category = 'life_support',
    },

    water_pump = {
        name = 'Bilge Pump', desc = 'High-capacity water extraction. Pumps water out of sealed rooms faster than a sump pump.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { steel = 10, components = 4 },
        entitySpawn = 'sump_pump',
        powerDraw = 25,
        category = 'infrastructure',
    },

    underwater_hab = {
        name = 'Underwater Habitat', desc = 'Sealed quarters for living underwater. Insulated, pressure-rated.',
        w = 2, h = 2,
        tile = Tiles.FLOOR_INSULATED,
        cost = { steel = 18, components = 6, circuit = 2, glass = 3 },
        powerDraw = 15,
        category = 'infrastructure',
    },

    condensation_trap = {
        name = 'Condensation Trap', desc = 'Collects clean water from humidity. Passive, no power. Slow but reliable.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 8, glass = 2 },
        category = 'life_support',
    },

    ---------------------------------------------------------------------------
    -- Floating surface structures (built on ocean/shallows tiles)
    ---------------------------------------------------------------------------

    pontoon_platform = {
        name = 'Pontoon Platform', desc = 'Floating wooden platform. Extends buildable area over water. Cheap but fragile.',
        w = 1, h = 1,
        tile = Tiles.PONTOON,
        cost = { wood = 12 },
        category = 'infrastructure',
    },

    reinforced_dock = {
        name = 'Reinforced Dock', desc = 'Metal-braced floating platform. Sturdier than pontoons. Supports heavier buildings.',
        w = 1, h = 1,
        tile = Tiles.DOCK,
        cost = { wood = 6, metal = 8 },
        category = 'infrastructure',
    },

    fishing_platform = {
        name = 'Fishing Platform', desc = 'Floating platform with nets. Generates food passively from nearby water tiles.',
        w = 2, h = 1,
        tile = Tiles.DOCK,
        cost = { wood = 15, metal = 5 },
        entitySpawn = 'machine',
        machineType = 'fishing_platform',
        category = 'food',
    },

    tidal_generator = {
        name = 'Tidal Generator', desc = 'Runs on ocean currents. Place on or next to water.',
        w = 2, h = 2,
        tile = Tiles.DOCK,
        cost = { steel = 15, components = 6, circuit = 2 },
        entitySpawn = 'generator',
        genType = 'tidal_generator',
        category = 'power',
    },

    ---------------------------------------------------------------------------
    -- Underwater hab variety (sealed rooms at depth)
    ---------------------------------------------------------------------------

    underwater_hab_small = {
        name = 'Hab Pod', desc = 'Compact sealed pod. Fits one colonist and their gear. Barely.',
        w = 1, h = 1,
        tile = Tiles.SEALED_FLOOR,
        cost = { steel = 10, components = 3, glass = 1 },
        powerDraw = 8,
        category = 'infrastructure',
    },

    underwater_hab_large = {
        name = 'Hab Block', desc = 'Large sealed habitat module. Comfortable quarters for a small crew.',
        w = 3, h = 3,
        tile = Tiles.SEALED_FLOOR,
        cost = { steel = 30, components = 10, circuit = 4, glass = 6 },
        powerDraw = 25,
        category = 'infrastructure',
    },

    sealed_wall = {
        name = 'Sealed Wall', desc = 'Pressure-rated wall. Blocks water and gas. Required for underwater room boundaries.',
        w = 1, h = 1,
        tile = Tiles.SEALED_WALL,
        cost = { steel = 8, components = 2 },
        category = 'infrastructure',
    },

    glass_dome = {
        name = 'Glass Dome', desc = 'Transparent pressure-rated dome panel. Lets colonists see the ocean. Morale bonus.',
        w = 1, h = 1,
        tile = Tiles.GLASS_DOME,
        cost = { steel = 6, glass = 8, components = 3 },
        category = 'infrastructure',
    },

    thermal_vent_tap = {
        name = 'Thermal Vent Tap', desc = 'Taps a volcanic vent on the ocean floor. High power output, some heat.',
        w = 2, h = 2,
        tile = Tiles.SEALED_FLOOR,
        cost = { steel = 25, components = 10, circuit = 4 },
        entitySpawn = 'generator',
        genType = 'thermal_vent_tap',
        category = 'power',
    },

    current_turbine = {
        name = 'Current Turbine', desc = 'Underwater turbine. Generates power from ocean currents. Steady low output.',
        w = 1, h = 1,
        tile = Tiles.SEALED_FLOOR,
        cost = { steel = 12, components = 5 },
        entitySpawn = 'generator',
        genType = 'current_turbine',
        category = 'power',
    },

    kelp_farm = {
        name = 'Kelp Farm', desc = 'Underwater hydroponics. Grows kelp for food and biomass. Needs light or power.',
        w = 2, h = 1,
        tile = Tiles.SEALED_FLOOR,
        cost = { steel = 10, glass = 4, components = 2 },
        entitySpawn = 'machine',
        machineType = 'kelp_farm',
        powerDraw = 10,
        category = 'food',
    },

    desalination_unit = {
        name = 'Desalination Unit', desc = 'Converts seawater into fresh water. Without it, you drink salt.',
        w = 1, h = 1,
        tile = Tiles.SEALED_FLOOR,
        cost = { steel = 12, components = 5, circuit = 2 },
        entitySpawn = 'machine',
        machineType = 'desalinator',
        powerDraw = 20,
        category = 'life_support',
    },

    seabed_drill = {
        name = 'Seabed Drill', desc = 'Underwater mining rig. Works submerged, no seal needed. Pulls ore from the ocean floor. Attracts predators.',
        w = 2, h = 2,
        tile = nil,  -- does NOT replace tile (sits on flooded ground)
        cost = { steel = 25, components = 10, circuit = 4 },
        entitySpawn = 'deep_drill',
        powerDraw = 60,
        category = 'mining',
        underwaterOnly = true,  -- can only be placed at depth > 0 on ocean worlds
        attractsCreatures = true,
    },

    -- Vehicles
    vehicle_workbench = {
        name = 'Vehicle Workbench (Legacy)', desc = 'Archived cut-scope building retained only so legacy saves do not hard-fail.',
        w = 1, h = 1,
        tile = Tiles.FLOOR_METAL,
        cost = { metal = 15, components = 5, steel = 5 },
        entitySpawn = 'machine',
        machineType = 'vehicle_workbench',
        hidden = true,
    },
}
