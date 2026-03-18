-- ship_defs.lua — Ship tier definitions and prebuilt layouts
-- Defines hull sizes, required modules, and preset layouts for both ship tiers.

local ShipDefs = {}

---------------------------------------------------------------------------
-- Ship tiers
---------------------------------------------------------------------------

ShipDefs.TIERS = {
    scout = {
        id = 'scout',
        name = 'Scout Ship',
        gridW = 12,
        gridH = 8,
        fuelCapacity = 100,
        baseSpeed = 3,
        baseStealth = 0.3,
        requiredModules = {
            { id = 'cockpit',       name = 'Cockpit',       w = 2, h = 2 },
            { id = 'engine',        name = 'Engine',        w = 2, h = 3 },
            { id = 'life_support',  name = 'Life Support',  w = 1, h = 2 },
            { id = 'mini_reactor',  name = 'Mini Reactor',  w = 1, h = 1 },
        },
    },
    colony = {
        id = 'colony',
        name = 'Colony Ship',
        gridW = 30,
        gridH = 20,
        fuelCapacity = 500,
        baseSpeed = 1,
        baseStealth = 1.0,
        requiredModules = {
            { id = 'bridge',             name = 'Bridge',             w = 3, h = 3 },
            { id = 'engine_bay',         name = 'Engine Bay',         w = 3, h = 4 },
            { id = 'life_support_array', name = 'Life Support Array', w = 2, h = 3 },
            { id = 'reactor',            name = 'Reactor',            w = 3, h = 3 },
        },
    },
}

---------------------------------------------------------------------------
-- Prebuilt layouts
---------------------------------------------------------------------------

ShipDefs.PREBUILTS = {
    scout_survey_runner = {
        tier = 'scout',
        name = 'Mammona Survey Runner',
        desc = 'Balanced scout with cargo bay and one weapon mount.',
        modules = {
            { id = 'cockpit',      x = 5, y = 1 },
            { id = 'engine',       x = 0, y = 3 },
            { id = 'life_support', x = 3, y = 1 },
            { id = 'mini_reactor', x = 3, y = 3 },
        },
        extras = {
            { building = 'storage_crate', x = 8, y = 1 },
            { building = 'bed',           x = 8, y = 4 },
        },
    },
    scout_smuggler = {
        tier = 'scout',
        name = "Smuggler's Skiff",
        desc = 'Runs cold and quiet. Hidden cargo holds, no weapons.',
        modules = {
            { id = 'cockpit',      x = 5, y = 1 },
            { id = 'engine',       x = 0, y = 3 },
            { id = 'life_support', x = 3, y = 1 },
            { id = 'mini_reactor', x = 3, y = 3 },
        },
        extras = {
            { building = 'storage_crate', x = 8, y = 1 },
            { building = 'storage_crate', x = 9, y = 1 },
            { building = 'bed',           x = 8, y = 4 },
        },
    },
    scout_empty = {
        tier = 'scout',
        name = 'Empty Hull',
        desc = 'Required modules only. Maximum creative freedom.',
        modules = {
            { id = 'cockpit',      x = 5, y = 1 },
            { id = 'engine',       x = 0, y = 3 },
            { id = 'life_support', x = 3, y = 1 },
            { id = 'mini_reactor', x = 3, y = 3 },
        },
        extras = {},
    },
    colony_hauler = {
        tier = 'colony',
        name = 'Mammona Frontier Hauler',
        desc = 'Cargo-focused. Large holds, minimal weapons, thick hull.',
        modules = {
            { id = 'bridge',             x = 13, y = 1 },
            { id = 'engine_bay',         x = 0,  y = 8 },
            { id = 'life_support_array', x = 4,  y = 1 },
            { id = 'reactor',            x = 4,  y = 8 },
        },
        extras = {},
    },
    colony_corvette = {
        tier = 'colony',
        name = 'UTC Decommissioned Corvette',
        desc = 'Combat-focused. Multiple weapon mounts, shields, armored bridge.',
        modules = {
            { id = 'bridge',             x = 13, y = 1 },
            { id = 'engine_bay',         x = 0,  y = 8 },
            { id = 'life_support_array', x = 4,  y = 1 },
            { id = 'reactor',            x = 4,  y = 8 },
        },
        extras = {},
    },
    colony_pioneer = {
        tier = 'colony',
        name = 'Pioneer Vessel',
        desc = 'Balanced. Farm bay, med bay, workshop, moderate everything.',
        modules = {
            { id = 'bridge',             x = 13, y = 1 },
            { id = 'engine_bay',         x = 0,  y = 8 },
            { id = 'life_support_array', x = 4,  y = 1 },
            { id = 'reactor',            x = 4,  y = 8 },
        },
        extras = {},
    },
    colony_empty = {
        tier = 'colony',
        name = 'Empty Hull',
        desc = 'Required modules only. Full creative freedom.',
        modules = {
            { id = 'bridge',             x = 13, y = 1 },
            { id = 'engine_bay',         x = 0,  y = 8 },
            { id = 'life_support_array', x = 4,  y = 1 },
            { id = 'reactor',            x = 4,  y = 8 },
        },
        extras = {},
    },
}

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

function ShipDefs.getTier(tierId)
    return ShipDefs.TIERS[tierId]
end

function ShipDefs.getPrebuilt(prebuiltId)
    return ShipDefs.PREBUILTS[prebuiltId]
end

function ShipDefs.getPrebuiltsForTier(tierId)
    local result = {}
    for id, def in pairs(ShipDefs.PREBUILTS) do
        if def.tier == tierId then
            result[#result + 1] = { id = id, def = def }
        end
    end
    return result
end

return ShipDefs
