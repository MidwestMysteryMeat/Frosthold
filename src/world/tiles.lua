-- tiles.lua — Tile type definitions and properties

local Tiles = {}

-- Tile type enum
Tiles.VOID       = 0
Tiles.SNOW       = 1
Tiles.ICE        = 2
Tiles.ROCK       = 3
Tiles.PERMAFROST = 4
Tiles.DIRT       = 5   -- exposed when heated above threshold
Tiles.FLOOR_WOOD = 6
Tiles.FLOOR_STONE= 7
Tiles.FLOOR_METAL= 8
Tiles.WALL_WOOD  = 9
Tiles.WALL_STONE = 10
Tiles.WALL_METAL = 11
Tiles.DOOR       = 12
Tiles.WATER      = 13  -- melted ice
Tiles.LAVA_VENT  = 14  -- natural heat source
Tiles.DEBRIS     = 15

-- Natural resources
Tiles.TREE       = 16
Tiles.ORE_VEIN   = 17

-- Insulated variants (Phase 10: thermal overhaul)
Tiles.WALL_INSULATED  = 18
Tiles.FLOOR_INSULATED = 19
Tiles.DOOR_SEALED     = 20

-- Underground (Phase 11: terraforming)
Tiles.DEEP_ROCK          = 21   -- dense rock at map edges, gateway to underground
Tiles.UNDERGROUND_ROCK   = 22   -- solid underground stone, excavatable
Tiles.UNDERGROUND_FLOOR  = 23   -- excavated underground space, walkable
Tiles.SHAFT_ENTRANCE     = 24   -- connects surface to underground, acts as insulated door
Tiles.SUPPORT_COLUMN_WOOD = 25  -- wooden support, cheap but degrades over time
Tiles.SUPPORT_COLUMN      = 26  -- stone structural support, durable
Tiles.REINFORCED_COLUMN   = 27  -- reinforced support, maximum span

-- Biological caves (depth-tiered)
Tiles.FUNGAL_FLOOR    = 28  -- bioluminescent mushroom floor (shallow caves)
Tiles.FUNGAL_WALL     = 29  -- organic wall with fungal growth
Tiles.MEMBRANE_FLOOR  = 30  -- precursor/organic hybrid floor (mid caves)
Tiles.MEMBRANE_WALL   = 31  -- living membrane wall, warm to touch
Tiles.ORGAN_FLOOR     = 32  -- vein-patterned floor (deep caves)
Tiles.ORGAN_WALL      = 33  -- pulsing organ wall, radiates heat
Tiles.GROWTH_CREEP    = 34  -- spreading biological growth (breached containment)

-- Vertical connections (DF-style digging)
Tiles.STAIR_DOWN      = 38  -- downward stair, connects to layer below
Tiles.STAIR_UP        = 39  -- upward stair, connects to layer above
Tiles.STAIR_BOTH      = 40  -- bidirectional stair (up+down)
Tiles.CHANNEL         = 41  -- open pit, connects down, not walkable (falling hazard)
Tiles.RAMP_UP         = 42  -- carved ramp upward, lower move cost than stairs

-- Natural water features
Tiles.FROZEN_RIVER    = 35  -- frozen river, fishable, becomes WATER during thaw
Tiles.GEYSER          = 36  -- thermal geyser, periodic steam + heat
Tiles.HOT_SPRING      = 37  -- warm pool, morale + minor healing

-- Expanded biome tiles
Tiles.FROZEN_LAKE     = 43  -- frozen lake surface, walkable, fishable
Tiles.FROZEN_SEA      = 44  -- deep frozen sea at map edges, walkable, not buildable
Tiles.CAVE_ENTRANCE   = 45  -- surface cave mouth, connects to depth 1
Tiles.TUNDRA_MARSH    = 46  -- wet tundra, walkable, slows movement
Tiles.VOLCANIC_ROCK   = 47  -- warm volcanic stone, solid, minable
Tiles.VOLCANIC_FLOOR  = 48  -- walkable volcanic ground, warm
Tiles.DEAD_TREE       = 49  -- dead/petrified tree, solid, low wood yield
Tiles.ASH_GROUND      = 50  -- ashy volcanic floor, walkable, buildable

-- Lead (radiation shielding)
Tiles.WALL_LEAD       = 51  -- lead-lined wall, blocks radiation
Tiles.DOOR_LEAD       = 52  -- lead-lined door, radiation-shielded passage
Tiles.LEAD_ORE        = 53  -- lead ore vein, mineable

-- Desert tiles (Rhea-2)
Tiles.SAND          = 54  -- loose sand, walkable, buildable
Tiles.DUNE          = 55  -- sand dune, solid, can be excavated for sand
Tiles.SANDSTONE     = 56  -- solid rock, minable for stone
Tiles.OASIS         = 57  -- water source in desert, walkable=false
Tiles.CACTUS        = 58  -- desert plant, solid, choppable for small food
Tiles.CRACKED_EARTH = 59  -- dry cracked ground, walkable, buildable

-- Ocean tiles (Nerthus-9)
Tiles.OCEAN         = 60  -- deep ocean water, not walkable, not buildable
Tiles.SHALLOWS      = 61  -- shallow water, walkable (slow), fishable
Tiles.CORAL         = 62  -- coral formation, solid, minable for stone
Tiles.BEACH         = 63  -- sandy beach, walkable, buildable
Tiles.SEAWEED       = 64  -- underwater plant, walkable, harvestable

-- Temperate tiles (Paxtera Prime, Gaia A^1x)
Tiles.GRASS         = 65  -- temperate grass, walkable, buildable
Tiles.FERTILE_SOIL  = 66  -- rich soil, walkable, buildable, growth bonus
Tiles.DECIDUOUS_TREE = 67  -- leafy tree, solid, choppable for wood
Tiles.BUSH          = 68  -- small bush, walkable, harvestable
Tiles.FLOWER_FIELD  = 69  -- decorative flowers on grass, walkable, buildable

-- Vacuum tiles (Nemaea)
Tiles.REGOLITH      = 70  -- lunar-like surface dust, walkable, buildable
Tiles.CRATER        = 71  -- impact crater, walkable, not buildable
Tiles.METAL_DEBRIS  = 72  -- Dyson Sphere wreckage, minable for metal
Tiles.HULL_PLATE    = 73  -- intact hull plating, solid, minable for components

-- Floating / underwater construction (Nerthus-9)
Tiles.PONTOON       = 74  -- floating wooden platform, buildable on water
Tiles.DOCK          = 75  -- reinforced dock platform, buildable on water
Tiles.SEALED_FLOOR  = 76  -- pressure-rated sealed floor for underwater habs
Tiles.SEALED_WALL   = 77  -- pressure-rated sealed wall, high insulation
Tiles.GLASS_DOME    = 78  -- transparent pressure dome ceiling/wall, morale bonus

-- Space tiles (interplanetary travel)
Tiles.SPACE_ASTEROID     = 99   -- minable asteroid, blocks movement
Tiles.SPACE_DEBRIS       = 100  -- ship wreckage debris, passable, damages hull
Tiles.SPACE_STAR         = 101  -- star core, impassable, lethal
Tiles.SPACE_CORONA       = 102  -- star corona, passable, extreme heat damage
Tiles.SPACE_DYSON_INTACT = 103  -- intact Dyson Sphere segment, solid
Tiles.SPACE_DYSON_BROKEN = 104  -- crumbled Dyson Sphere segment, passable debris
Tiles.SPACE_GRAVITY_WELL = 106  -- near-planet gravity, slows ships

-- Underwater natural resources (Nerthus-9 depth layers)
Tiles.CORAL_DEPOSIT   = 79  -- dense coral formation, minable for stone + food
Tiles.MINERAL_NODULE  = 80  -- manganese nodule cluster, minable for metal
Tiles.THERMAL_MINERAL = 81  -- hydrothermal vent mineral deposit, minable for components
Tiles.KELP_FOREST     = 82  -- dense underwater kelp, harvestable for food
Tiles.SUNKEN_WRECK    = 83  -- shipwreck debris, minable for metal + components
Tiles.BRINE_POCKET    = 84  -- concentrated salt pocket, minable for chemicals

-- Property tables
Tiles.props = {
    [Tiles.VOID]       = { name = 'void',       solid = true,  walkable = false, insulation = 0,   buildable = false, color = {0.05, 0.05, 0.1} },
    [Tiles.SNOW]       = { name = 'snow',        solid = false, walkable = true,  insulation = 0.3, buildable = true,  color = {0.9, 0.92, 0.95} },
    [Tiles.ICE]        = { name = 'ice',         solid = false, walkable = true,  insulation = 0.1, buildable = false, color = {0.6, 0.8, 0.95} },
    [Tiles.ROCK]       = { name = 'rock',        solid = true,  walkable = false, insulation = 0.8, buildable = false, color = {0.4, 0.38, 0.35} },
    [Tiles.PERMAFROST] = { name = 'permafrost',  solid = false, walkable = true,  insulation = 0.5, buildable = true,  color = {0.5, 0.55, 0.6} },
    [Tiles.DIRT]       = { name = 'dirt',         solid = false, walkable = true,  insulation = 0.4, buildable = true,  color = {0.45, 0.35, 0.25} },
    [Tiles.FLOOR_WOOD] = { name = 'wood floor',  solid = false, walkable = true,  insulation = 0.6, buildable = false, color = {0.55, 0.4, 0.25} },
    [Tiles.FLOOR_STONE]= { name = 'stone floor', solid = false, walkable = true,  insulation = 0.5, buildable = false, color = {0.5, 0.48, 0.45} },
    [Tiles.FLOOR_METAL]= { name = 'metal floor', solid = false, walkable = true,  insulation = 0.3, buildable = false, color = {0.55, 0.58, 0.6} },
    [Tiles.WALL_WOOD]  = { name = 'wood wall',   solid = true,  walkable = false, insulation = 0.7, buildable = false, color = {0.4, 0.3, 0.15} },
    [Tiles.WALL_STONE] = { name = 'stone wall',  solid = true,  walkable = false, insulation = 0.85,buildable = false, color = {0.35, 0.33, 0.3} },
    [Tiles.WALL_METAL] = { name = 'metal wall',  solid = true,  walkable = false, insulation = 0.9, buildable = false, color = {0.45, 0.48, 0.5} },
    [Tiles.DOOR]       = { name = 'door',         solid = false, walkable = true,  insulation = 0.5, buildable = false, color = {0.5, 0.35, 0.2}, gasPermeability = 0.75, waterPermeability = 0.45 },
    [Tiles.WATER]      = { name = 'water',        solid = false, walkable = false, insulation = 0.0, buildable = false, color = {0.2, 0.3, 0.7} },
    [Tiles.LAVA_VENT]  = { name = 'lava vent',    solid = false, walkable = false, insulation = 0.0, buildable = false, color = {0.8, 0.3, 0.1} },
    [Tiles.DEBRIS]     = { name = 'debris',       solid = false, walkable = true,  insulation = 0.2, buildable = true,  color = {0.6, 0.58, 0.55} },
    [Tiles.TREE]       = { name = 'tree',        solid = true,  walkable = false, insulation = 0.4, buildable = false, color = {0.2, 0.35, 0.15}, minable = true, resource = 'wood', resAmount = 3 },
    [Tiles.ORE_VEIN]   = { name = 'ore vein',    solid = true,  walkable = false, insulation = 0.7, buildable = false, color = {0.5, 0.4, 0.25}, minable = true, resource = 'metal', resAmount = 3 },
    [Tiles.WALL_INSULATED]  = { name = 'insulated wall',  solid = true,  walkable = false, insulation = 0.97, buildable = false, color = {0.5, 0.52, 0.58} },
    [Tiles.FLOOR_INSULATED] = { name = 'insulated floor', solid = false, walkable = true,  insulation = 0.85, buildable = false, color = {0.52, 0.50, 0.55} },
    [Tiles.DOOR_SEALED]     = { name = 'sealed door',     solid = false, walkable = true,  insulation = 0.8,  buildable = false, color = {0.48, 0.38, 0.28}, gasPermeability = 0.0, waterPermeability = 0.0 },
    [Tiles.DEEP_ROCK]       = { name = 'deep rock',       solid = true,  walkable = false, insulation = 0.95, buildable = false, color = {0.25, 0.22, 0.2},  minable = true, resource = 'stone', resAmount = 3 },
    [Tiles.UNDERGROUND_ROCK]= { name = 'underground rock', solid = true,  walkable = false, insulation = 0.9,  buildable = false, color = {0.3, 0.28, 0.25}, minable = true, resource = 'stone', resAmount = 2 },
    [Tiles.UNDERGROUND_FLOOR]={ name = 'underground floor',solid = false, walkable = true,  insulation = 0.7,  buildable = true,  color = {0.35, 0.32, 0.3},  underground = true },
    [Tiles.SHAFT_ENTRANCE]  = { name = 'shaft entrance',  solid = false, walkable = true,  insulation = 0.6,  buildable = false, color = {0.4, 0.35, 0.28},  underground = true, connects_up = true, connects_down = true },
    [Tiles.SUPPORT_COLUMN_WOOD] = { name = 'wood column',      solid = true,  walkable = false, insulation = 0.5,  buildable = false, color = {0.5, 0.38, 0.2},  underground = true, structural = true, supportSpan = 8 },
    [Tiles.SUPPORT_COLUMN]      = { name = 'stone column',     solid = true,  walkable = false, insulation = 0.8,  buildable = false, color = {0.42, 0.4, 0.38}, underground = true, structural = true, supportSpan = 14 },
    [Tiles.REINFORCED_COLUMN]   = { name = 'reinforced column', solid = true, walkable = false, insulation = 0.85, buildable = false, color = {0.48, 0.5, 0.52}, underground = true, structural = true, supportSpan = 26 },

    -- Biological caves
    [Tiles.FUNGAL_FLOOR]    = { name = 'fungal floor',    solid = false, walkable = true,  insulation = 0.6,  buildable = false, color = {0.15, 0.35, 0.25}, underground = true, biological = true },
    [Tiles.FUNGAL_WALL]     = { name = 'fungal wall',     solid = true,  walkable = false, insulation = 0.7,  buildable = false, color = {0.1, 0.28, 0.18},  underground = true, biological = true, containsGrowth = true, minable = true, resource = 'food', resAmount = 1 },
    [Tiles.MEMBRANE_FLOOR]  = { name = 'membrane floor',  solid = false, walkable = true,  insulation = 0.65, buildable = false, color = {0.35, 0.2, 0.25},  underground = true, biological = true },
    [Tiles.MEMBRANE_WALL]   = { name = 'membrane wall',   solid = true,  walkable = false, insulation = 0.75, buildable = false, color = {0.3, 0.15, 0.2},   underground = true, biological = true, containsGrowth = true, minable = true, resource = 'hide', resAmount = 2 },
    [Tiles.ORGAN_FLOOR]     = { name = 'organ floor',     solid = false, walkable = true,  insulation = 0.7,  buildable = false, color = {0.4, 0.12, 0.15},  underground = true, biological = true },
    [Tiles.ORGAN_WALL]      = { name = 'organ wall',      solid = true,  walkable = false, insulation = 0.8,  buildable = false, color = {0.35, 0.08, 0.1},  underground = true, biological = true, containsGrowth = true, minable = true, resource = 'hide', resAmount = 3 },
    [Tiles.GROWTH_CREEP]    = { name = 'growth creep',    solid = false, walkable = true,  insulation = 0.4,  buildable = false, color = {0.2, 0.3, 0.15},   underground = true, biological = true, flammable = true },

    -- Vertical connections
    [Tiles.STAIR_DOWN]  = { name = 'stair down',  solid = false, walkable = true,  insulation = 0.5, buildable = false, color = {0.38, 0.33, 0.28}, underground = true, connects_down = true },
    [Tiles.STAIR_UP]    = { name = 'stair up',    solid = false, walkable = true,  insulation = 0.5, buildable = false, color = {0.38, 0.33, 0.28}, underground = true, connects_up = true },
    [Tiles.STAIR_BOTH]  = { name = 'stairwell',   solid = false, walkable = true,  insulation = 0.5, buildable = false, color = {0.36, 0.31, 0.26}, underground = true, connects_up = true, connects_down = true },
    [Tiles.CHANNEL]     = { name = 'channel',     solid = false, walkable = false, insulation = 0.1, buildable = false, color = {0.15, 0.15, 0.2},  underground = true, connects_down = true, dangerous = true },
    [Tiles.RAMP_UP]     = { name = 'ramp up',     solid = false, walkable = true,  insulation = 0.6, buildable = false, color = {0.4, 0.36, 0.3},   underground = true, connects_up = true, ramp = true },

    -- Natural water features
    [Tiles.FROZEN_RIVER]    = { name = 'frozen river',    solid = false, walkable = true,  insulation = 0.05, buildable = false, color = {0.55, 0.75, 0.9},  fishable = true },
    [Tiles.GEYSER]          = { name = 'thermal geyser',  solid = false, walkable = false, insulation = 0.0,  buildable = false, color = {0.7, 0.5, 0.3},  heatSource = true, heatRadius = 6, heatPower = 40 },
    [Tiles.HOT_SPRING]      = { name = 'hot spring',      solid = false, walkable = true,  insulation = 0.0,  buildable = false, color = {0.3, 0.5, 0.65}, morale = true },

    -- Expanded biome tiles
    [Tiles.FROZEN_LAKE]     = { name = 'frozen lake',     solid = false, walkable = true,  insulation = 0.05, buildable = false, color = {0.5, 0.7, 0.88},  fishable = true },
    [Tiles.FROZEN_SEA]      = { name = 'frozen sea',      solid = false, walkable = true,  insulation = 0.02, buildable = false, color = {0.45, 0.65, 0.85} },
    [Tiles.CAVE_ENTRANCE]   = { name = 'cave entrance',   solid = false, walkable = true,  insulation = 0.4,  buildable = false, color = {0.2, 0.18, 0.15}, connects_down = true },
    [Tiles.TUNDRA_MARSH]    = { name = 'tundra marsh',    solid = false, walkable = true,  insulation = 0.15, buildable = false, color = {0.35, 0.45, 0.4},  movePenalty = 1.5 },
    [Tiles.VOLCANIC_ROCK]   = { name = 'volcanic rock',   solid = true,  walkable = false, insulation = 0.85, buildable = false, color = {0.25, 0.15, 0.12}, minable = true, resource = 'stone', resAmount = 4 },
    [Tiles.VOLCANIC_FLOOR]  = { name = 'volcanic floor',  solid = false, walkable = true,  insulation = 0.6,  buildable = true,  color = {0.35, 0.22, 0.18} },
    [Tiles.DEAD_TREE]       = { name = 'dead tree',       solid = true,  walkable = false, insulation = 0.3,  buildable = false, color = {0.3, 0.25, 0.2},  minable = true, resource = 'wood', resAmount = 1 },
    [Tiles.ASH_GROUND]      = { name = 'ash ground',      solid = false, walkable = true,  insulation = 0.35, buildable = true,  color = {0.32, 0.28, 0.26} },

    -- Lead (radiation shielding)
    [Tiles.WALL_LEAD]       = { name = 'lead wall',       solid = true,  walkable = false, insulation = 0.92, buildable = false, color = {0.35, 0.35, 0.4},  radiationShield = true },
    [Tiles.DOOR_LEAD]       = { name = 'lead door',       solid = false, walkable = true,  insulation = 0.75, buildable = false, color = {0.38, 0.38, 0.42}, radiationShield = true, gasPermeability = 0.2, waterPermeability = 0.1 },
    [Tiles.LEAD_ORE]        = { name = 'lead ore',        solid = true,  walkable = false, insulation = 0.8,  buildable = false, color = {0.4, 0.38, 0.45}, minable = true, resource = 'lead', resAmount = 3 },

    -- Desert
    [Tiles.SAND]          = { name = 'sand',          solid = false, walkable = true,  insulation = 0.2,  buildable = true,  color = {0.85, 0.78, 0.55}, movePenalty = 1.3 },
    [Tiles.DUNE]          = { name = 'sand dune',     solid = true,  walkable = false, insulation = 0.3,  buildable = false, color = {0.9, 0.82, 0.58}, minable = true, resource = 'stone', resAmount = 1 },
    [Tiles.SANDSTONE]     = { name = 'sandstone',     solid = true,  walkable = false, insulation = 0.7,  buildable = false, color = {0.75, 0.6, 0.4},  minable = true, resource = 'stone', resAmount = 3 },
    [Tiles.OASIS]         = { name = 'oasis',         solid = false, walkable = false, insulation = 0.0,  buildable = false, color = {0.2, 0.5, 0.4},   fishable = true },
    [Tiles.CACTUS]        = { name = 'cactus',        solid = true,  walkable = false, insulation = 0.2,  buildable = false, color = {0.3, 0.55, 0.25}, minable = true, resource = 'food', resAmount = 2 },
    [Tiles.CRACKED_EARTH] = { name = 'cracked earth', solid = false, walkable = true,  insulation = 0.35, buildable = true,  color = {0.6, 0.5, 0.35} },

    -- Ocean
    [Tiles.OCEAN]         = { name = 'ocean',         solid = false, walkable = false, insulation = 0.0,  buildable = false, color = {0.1, 0.2, 0.5} },
    [Tiles.SHALLOWS]      = { name = 'shallows',      solid = false, walkable = true,  insulation = 0.0,  buildable = false, color = {0.2, 0.4, 0.6},   fishable = true, movePenalty = 1.8 },
    [Tiles.CORAL]         = { name = 'coral',         solid = true,  walkable = false, insulation = 0.5,  buildable = false, color = {0.7, 0.4, 0.5},   minable = true, resource = 'stone', resAmount = 2 },
    [Tiles.BEACH]         = { name = 'beach',         solid = false, walkable = true,  insulation = 0.15, buildable = true,  color = {0.9, 0.85, 0.65} },
    [Tiles.SEAWEED]       = { name = 'seaweed',       solid = false, walkable = true,  insulation = 0.0,  buildable = false, color = {0.15, 0.4, 0.25},  movePenalty = 1.4 },

    -- Temperate
    [Tiles.GRASS]         = { name = 'grass',         solid = false, walkable = true,  insulation = 0.3,  buildable = true,  color = {0.35, 0.6, 0.25} },
    [Tiles.FERTILE_SOIL]  = { name = 'fertile soil',  solid = false, walkable = true,  insulation = 0.4,  buildable = true,  color = {0.4, 0.3, 0.15},   growthBonus = 0.5 },
    [Tiles.DECIDUOUS_TREE]= { name = 'tree',          solid = true,  walkable = false, insulation = 0.4,  buildable = false, color = {0.25, 0.5, 0.2},   minable = true, resource = 'wood', resAmount = 4 },
    [Tiles.BUSH]          = { name = 'bush',          solid = false, walkable = true,  insulation = 0.2,  buildable = false, color = {0.3, 0.5, 0.15},   movePenalty = 1.2 },
    [Tiles.FLOWER_FIELD]  = { name = 'flower field',  solid = false, walkable = true,  insulation = 0.25, buildable = true,  color = {0.55, 0.45, 0.6} },

    -- Vacuum
    [Tiles.REGOLITH]      = { name = 'regolith',      solid = false, walkable = true,  insulation = 0.15, buildable = true,  color = {0.45, 0.42, 0.4} },
    [Tiles.CRATER]        = { name = 'crater',        solid = false, walkable = true,  insulation = 0.1,  buildable = false, color = {0.35, 0.32, 0.3} },
    [Tiles.METAL_DEBRIS]  = { name = 'metal debris',  solid = true,  walkable = false, insulation = 0.5,  buildable = false, color = {0.5, 0.45, 0.42},  minable = true, resource = 'metal', resAmount = 4 },
    [Tiles.HULL_PLATE]    = { name = 'hull plate',    solid = true,  walkable = false, insulation = 0.8,  buildable = false, color = {0.4, 0.42, 0.48},  minable = true, resource = 'components', resAmount = 2 },

    -- Floating / underwater construction
    [Tiles.PONTOON]       = { name = 'pontoon',       solid = false, walkable = true,  insulation = 0.2,  buildable = true,  color = {0.5, 0.4, 0.25}, movePenalty = 1.2, floats = true },
    [Tiles.DOCK]          = { name = 'dock',           solid = false, walkable = true,  insulation = 0.3,  buildable = true,  color = {0.45, 0.42, 0.38}, floats = true },
    [Tiles.SEALED_FLOOR]  = { name = 'sealed floor',  solid = false, walkable = true,  insulation = 0.85, buildable = false, color = {0.42, 0.45, 0.5},  waterPermeability = 0, gasPermeability = 0 },
    [Tiles.SEALED_WALL]   = { name = 'sealed wall',   solid = true,  walkable = false, insulation = 0.95, buildable = false, color = {0.38, 0.4, 0.48},  waterPermeability = 0, gasPermeability = 0 },
    [Tiles.GLASS_DOME]    = { name = 'glass dome',    solid = true,  walkable = false, insulation = 0.6,  buildable = false, color = {0.5, 0.7, 0.8},    waterPermeability = 0, gasPermeability = 0, morale = true },

    -- Underwater natural resources
    [Tiles.CORAL_DEPOSIT]   = { name = 'coral deposit',   solid = true,  walkable = false, insulation = 0.4, buildable = false, color = {0.75, 0.45, 0.55}, minable = true, resource = 'stone', resAmount = 4, bonus = { food = 1 } },
    [Tiles.MINERAL_NODULE]  = { name = 'mineral nodule',  solid = true,  walkable = false, insulation = 0.5, buildable = false, color = {0.35, 0.3, 0.25},  minable = true, resource = 'metal', resAmount = 5 },
    [Tiles.THERMAL_MINERAL] = { name = 'thermal mineral', solid = true,  walkable = false, insulation = 0.6, buildable = false, color = {0.6, 0.4, 0.2},   minable = true, resource = 'components', resAmount = 3 },
    [Tiles.KELP_FOREST]     = { name = 'kelp forest',     solid = false, walkable = true,  insulation = 0.1, buildable = false, color = {0.1, 0.4, 0.2},   movePenalty = 1.6, minable = true, resource = 'food', resAmount = 3 },
    [Tiles.SUNKEN_WRECK]    = { name = 'sunken wreck',    solid = true,  walkable = false, insulation = 0.5, buildable = false, color = {0.4, 0.35, 0.3},  minable = true, resource = 'metal', resAmount = 6, bonus = { components = 2 } },
    [Tiles.BRINE_POCKET]    = { name = 'brine pocket',    solid = true,  walkable = false, insulation = 0.3, buildable = false, color = {0.55, 0.6, 0.5},  minable = true, resource = 'fuel', resAmount = 3 },

    -- Space tiles
    [99]  = { name = 'asteroid',          solid = true,  walkable = false, insulation = 0,   buildable = false, color = {0.45, 0.4, 0.35},  minable = true, resource = 'metal', resAmount = 5 },
    [100] = { name = 'debris',            solid = false, walkable = true,  insulation = 0,   buildable = false, color = {0.3, 0.28, 0.25} },
    [101] = { name = 'star',              solid = true,  walkable = false, insulation = 0,   buildable = false, color = {1.0, 0.95, 0.7} },
    [102] = { name = 'corona',            solid = false, walkable = true,  insulation = 0,   buildable = false, color = {1.0, 0.6, 0.2} },
    [103] = { name = 'dyson sphere',      solid = true,  walkable = false, insulation = 0.9, buildable = false, color = {0.5, 0.55, 0.6} },
    [104] = { name = 'dyson debris',      solid = false, walkable = true,  insulation = 0.3, buildable = false, color = {0.4, 0.42, 0.45} },
    [106] = { name = 'gravity well',      solid = false, walkable = true,  insulation = 0,   buildable = false, color = {0.08, 0.08, 0.15} },
}

function Tiles.get(tileType)
    return Tiles.props[tileType] or Tiles.props[Tiles.VOID]
end

function Tiles.isWalkable(tileType)
    local p = Tiles.props[tileType]
    return p and p.walkable
end

function Tiles.isSolid(tileType)
    local p = Tiles.props[tileType]
    return p and p.solid
end

function Tiles.isBuildable(tileType)
    local p = Tiles.props[tileType]
    return p and p.buildable
end

function Tiles.connectsDown(tileType)
    local p = Tiles.props[tileType]
    return p and p.connects_down
end

function Tiles.connectsUp(tileType)
    local p = Tiles.props[tileType]
    return p and p.connects_up
end

function Tiles.connectsVertical(tileType)
    local p = Tiles.props[tileType]
    return p and (p.connects_up or p.connects_down)
end

function Tiles.getGasPermeability(tileType)
    local p = Tiles.props[tileType]
    if not p then return 0 end
    if p.gasPermeability ~= nil then return p.gasPermeability end
    return p.solid and 0 or 1
end

function Tiles.getWaterPermeability(tileType)
    local p = Tiles.props[tileType]
    if not p then return 0 end
    if p.waterPermeability ~= nil then return p.waterPermeability end
    return p.solid and 0 or 1
end

return Tiles
