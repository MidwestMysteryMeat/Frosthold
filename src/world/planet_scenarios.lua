-- planet_scenarios.lua — Per-planet scenario definitions
-- Scenarios moved here from difficulty.lua. Each planet defines which
-- scenarios are valid and what starting conditions they provide.

local PlanetScenarios = {}

---------------------------------------------------------------------------
-- Erebus scenarios (existing — moved from difficulty.lua)
---------------------------------------------------------------------------

local EREBUS = {
    crashlanded = {
        name = 'Drop Pod Malfunction',
        colonists = 3,
        desc = 'Your Mammona drop pod clipped debris on descent. Three survivors, a standard loadout, and wreckage barely fit for shelter. HERMES came through with you.',
        resources = { thermalCores = 0, wood = 50, stone = 30, metal = 10, food = 40, fuel = 20, components = 3, hide = 0 },
        wounded = 0,
        sick = 0,
        skillBoost = nil,
        crashShelter = true,
    },
    lone_wanderer = {
        name = 'Sole Survivor',
        colonists = 1,
        desc = 'One colonist, a little extra training, and almost no slack. A bad call can end the run.',
        resources = { thermalCores = 2, wood = 20, stone = 10, metal = 5, food = 25, fuel = 10, components = 0, hide = 0 },
        wounded = 0,
        sick = 0,
        skillBoost = 4,
    },
    lost_tribe = {
        name = 'Prior Expedition',
        colonists = 5,
        desc = 'Five survivors from an earlier Mammona crew, living off salvage and bad luck. They did not expect company.',
        resources = { thermalCores = 0, wood = 80, stone = 10, metal = 0, food = 70, fuel = 5, components = 0, hide = 15 },
        wounded = 0,
        sick = 0,
        skillBoost = nil,
        capSkills = 5,
    },
    rich_explorer = {
        name = 'Executive Observer (Alt)',
        colonists = 1,
        desc = 'An alt-canon start. A Mammona executive came planetside with good gear and no field sense.',
        resources = { thermalCores = 15, wood = 100, stone = 60, metal = 30, food = 80, fuel = 40, components = 10, hide = 10 },
        wounded = 0,
        sick = 0,
        skillBoost = 2,
    },
    naked_brutality = {
        name = 'Abandoned',
        colonists = 1,
        desc = 'Left on Erebus with a single thermal core and silence from orbit.',
        resources = { thermalCores = 1, wood = 0, stone = 0, metal = 0, food = 5, fuel = 0, components = 0, hide = 0 },
        wounded = 0,
        sick = 0,
        skillBoost = nil,
        startingGear = false,  -- "nothing" means nothing: no weapon, no coat
    },
    frozen_siege = {
        name = 'Hot Drop (Alt)',
        colonists = 4,
        desc = 'An alt-canon combat start. You hit the ground in an active kill zone and the colony barely exists.',
        resources = { thermalCores = 5, wood = 40, stone = 40, metal = 15, food = 30, fuel = 15, components = 3, hide = 0 },
        wounded = 1,
        sick = 0,
        skillBoost = nil,
        immediateRaid = true,
    },
}

local EREBUS_ORDER = { 'crashlanded', 'lone_wanderer', 'lost_tribe', 'rich_explorer', 'naked_brutality', 'frozen_siege' }

---------------------------------------------------------------------------
-- Rhea-2 scenarios (desert world — heat, water, twin suns)
---------------------------------------------------------------------------

local RHEA2 = {
    crashlanded = {
        name = 'Desert Landing',
        colonists = 3,
        desc = 'Your drop pod hit sand instead of rock. Three survivors, a busted water reclaimer, and heat that melts thought. Find shade or die.',
        resources = { thermalCores = 0, wood = 10, stone = 20, metal = 15, food = 30, fuel = 10, components = 3, hide = 0, water = 20 },
        wounded = 0, sick = 0, skillBoost = nil, crashShelter = true,
    },
    lone_wanderer = {
        name = 'Lost in the Dunes',
        colonists = 1,
        desc = 'One person, a canteen, and a compass that points at nothing useful.',
        resources = { thermalCores = 1, wood = 5, stone = 5, metal = 5, food = 15, fuel = 5, components = 0, hide = 0, water = 15 },
        wounded = 0, sick = 0, skillBoost = 4,
    },
    naked_brutality = {
        name = 'Sunstroke',
        colonists = 1,
        desc = 'Dumped in the open desert with nothing. The twin suns are already overhead.',
        resources = { thermalCores = 0, wood = 0, stone = 0, metal = 0, food = 3, fuel = 0, components = 0, hide = 0, water = 5 },
        wounded = 0, sick = 0, skillBoost = nil,
        startingGear = false,
    },
}
local RHEA2_ORDER = { 'crashlanded', 'lone_wanderer', 'naked_brutality' }

---------------------------------------------------------------------------
-- Morvos scenarios (acid world — corrosion, toxic atmosphere)
---------------------------------------------------------------------------

local MORVOS = {
    crashlanded = {
        name = 'Acid Landing',
        colonists = 3,
        desc = 'The hull is pitted and the rain is eating what is left. Find rock that does not dissolve.',
        resources = { thermalCores = 0, wood = 0, stone = 30, metal = 20, food = 30, fuel = 15, components = 5, hide = 0 },
        wounded = 1, sick = 0, skillBoost = nil, crashShelter = true,
    },
    lone_wanderer = {
        name = 'Corroded',
        colonists = 1,
        desc = 'Your suit has holes. The air burns. Move fast.',
        resources = { thermalCores = 1, wood = 0, stone = 10, metal = 10, food = 15, fuel = 5, components = 2, hide = 0 },
        wounded = 0, sick = 0, skillBoost = 4,
    },
}
local MORVOS_ORDER = { 'crashlanded', 'lone_wanderer' }

---------------------------------------------------------------------------
-- Nerthus-9 scenarios (ocean world — flooding, volcanic islands)
---------------------------------------------------------------------------

local NERTHUS = {
    crashlanded = {
        name = 'Island Crash',
        colonists = 3,
        desc = 'Your pod skipped across the ocean like a stone and lodged in a volcanic island. The water is already rising.',
        resources = { thermalCores = 0, wood = 40, stone = 20, metal = 10, food = 35, fuel = 15, components = 3, hide = 0 },
        wounded = 0, sick = 0, skillBoost = nil, crashShelter = true,
    },
    lone_wanderer = {
        name = 'Castaway',
        colonists = 1,
        desc = 'Washed ashore on a rocky outcrop. The tide is coming in.',
        resources = { thermalCores = 1, wood = 15, stone = 10, metal = 5, food = 20, fuel = 5, components = 1, hide = 0 },
        wounded = 0, sick = 0, skillBoost = 4,
    },
}
local NERTHUS_ORDER = { 'crashlanded', 'lone_wanderer' }

---------------------------------------------------------------------------
-- Paxtera Prime scenarios (corporate world — quotas, temperate)
---------------------------------------------------------------------------

local PAXTERA = {
    crashlanded = {
        name = 'Soft Landing',
        colonists = 3,
        desc = 'Green hills, clean water, breathable air. Three survivors with a standard kit and no frozen ground to fight. The easiest start in the system.',
        resources = { thermalCores = 0, wood = 60, stone = 40, metal = 15, food = 50, fuel = 15, components = 3, hide = 0 },
        wounded = 0, sick = 0, skillBoost = nil, crashShelter = true,
    },
    lone_wanderer = {
        name = 'Frontier Scout',
        colonists = 1,
        desc = 'One colonist on a temperate world. Plenty of food, plenty of wood, and plenty of time before trouble finds you.',
        resources = { thermalCores = 2, wood = 30, stone = 15, metal = 10, food = 35, fuel = 10, components = 1, hide = 0 },
        wounded = 0, sick = 0, skillBoost = 4,
    },
    lost_tribe = {
        name = 'Settlers',
        colonists = 5,
        desc = 'Five people who landed months ago and have been getting by. Basic skills, good land, and the start of something permanent.',
        resources = { thermalCores = 0, wood = 80, stone = 30, metal = 10, food = 70, fuel = 10, components = 0, hide = 10 },
        wounded = 0, sick = 0, skillBoost = nil, capSkills = 5,
    },
    rich_explorer = {
        name = 'Well-Supplied',
        colonists = 1,
        desc = 'One colonist with excellent gear on the easiest planet in the system. Relax.',
        resources = { thermalCores = 10, wood = 100, stone = 60, metal = 30, food = 80, fuel = 30, components = 8, hide = 5 },
        wounded = 0, sick = 0, skillBoost = 2,
    },
    naked_brutality = {
        name = 'Stranded',
        colonists = 1,
        desc = 'Nothing but temperate air and fertile ground. At least you will not freeze.',
        resources = { thermalCores = 0, wood = 0, stone = 0, metal = 0, food = 5, fuel = 0, components = 0, hide = 0 },
        wounded = 0, sick = 0, skillBoost = nil,
        startingGear = false,
    },
}
local PAXTERA_ORDER = { 'crashlanded', 'lone_wanderer', 'lost_tribe', 'rich_explorer', 'naked_brutality' }

---------------------------------------------------------------------------
-- Gaia A^1x scenarios (lush world — scripted fall)
---------------------------------------------------------------------------

local GAIA = {
    crashlanded = {
        name = 'Paradise Landing',
        colonists = 3,
        desc = 'The air is warm, the soil is rich, and the trees are full. Enjoy it while it lasts. Something stirs below.',
        resources = { thermalCores = 0, wood = 60, stone = 20, metal = 10, food = 60, fuel = 10, components = 2, hide = 0 },
        wounded = 0, sick = 0, skillBoost = nil, crashShelter = true,
    },
}
local GAIA_ORDER = { 'crashlanded' }

---------------------------------------------------------------------------
-- Nemaea scenarios (stubs — hull_breach is the signature start)
---------------------------------------------------------------------------

local NEMAEA = {
    hull_breach = {
        name = 'Hull Breach',
        colonists = 3,
        desc = 'Your lander took micro-debris during descent. Three crew, a sealed ship with a cracked hull, and whatever O2 remains in the tanks. Seal the breach or suffocate.',
        resources = { thermalCores = 5, wood = 0, stone = 0, metal = 20, food = 30, fuel = 15, components = 8, hide = 0 },
        wounded = 1,
        sick = 0,
        skillBoost = nil,
        startShip = true,
    },
    lone_wanderer = {
        name = 'Sole Survivor',
        colonists = 1,
        desc = 'One person in a vacuum suit with a failing O2 tank. Find shelter or die.',
        resources = { thermalCores = 2, wood = 0, stone = 0, metal = 5, food = 10, fuel = 5, components = 2, hide = 0 },
        wounded = 0,
        sick = 0,
        skillBoost = 4,
    },
}

local NEMAEA_ORDER = { 'hull_breach', 'lone_wanderer' }

---------------------------------------------------------------------------
-- Per-planet tables
---------------------------------------------------------------------------

local SCENARIOS = {
    erebus        = EREBUS,
    rhea_2        = RHEA2,
    morvos        = MORVOS,
    nerthus_9     = NERTHUS,
    paxtera_prime = PAXTERA,
    nemaea        = NEMAEA,
    gaia_a1x      = GAIA,
}

local SCENARIO_ORDERS = {
    erebus        = EREBUS_ORDER,
    rhea_2        = RHEA2_ORDER,
    morvos        = MORVOS_ORDER,
    nerthus_9     = NERTHUS_ORDER,
    paxtera_prime = PAXTERA_ORDER,
    nemaea        = NEMAEA_ORDER,
    gaia_a1x      = GAIA_ORDER,
}

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

--- Returns the scenario table for a planet, filtered to valid scenario IDs.
--- Cross-references planet_defs.scenarios to only include allowed scenarios.
function PlanetScenarios.getScenariosForPlanet(planetId)
    planetId = planetId or 'erebus'
    local allScenarios = SCENARIOS[planetId] or EREBUS

    -- Filter by planet def's allowed scenario list
    local pok, PlanetDefs = pcall(require, 'src.world.planet_defs')
    if pok then
        local pdef = PlanetDefs.get(planetId)
        if pdef and pdef.scenarios then
            local allowed = {}
            for _, sid in ipairs(pdef.scenarios) do
                if allScenarios[sid] then allowed[sid] = allScenarios[sid] end
            end
            return allowed
        end
    end
    return allScenarios
end

--- Returns the ordered scenario key list for a planet.
--- Cross-references planet_defs.scenarios to only include allowed scenarios.
function PlanetScenarios.getScenarioOrder(planetId)
    planetId = planetId or 'erebus'
    local fullOrder = SCENARIO_ORDERS[planetId] or EREBUS_ORDER

    -- Filter by planet def's allowed scenario list
    local pok, PlanetDefs = pcall(require, 'src.world.planet_defs')
    if pok then
        local pdef = PlanetDefs.get(planetId)
        if pdef and pdef.scenarios then
            local allowSet = {}
            for _, sid in ipairs(pdef.scenarios) do allowSet[sid] = true end
            local filtered = {}
            for _, sid in ipairs(fullOrder) do
                if allowSet[sid] then filtered[#filtered + 1] = sid end
            end
            return filtered
        end
    end
    return fullOrder
end

--- Returns a specific scenario def.
function PlanetScenarios.getScenario(planetId, scenarioId)
    local tbl = PlanetScenarios.getScenariosForPlanet(planetId)
    return tbl[scenarioId]
end

return PlanetScenarios
