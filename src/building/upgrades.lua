-- upgrades.lua — Building upgrade system
-- Reinforcing buildings bumps stats within limits. Bridges to next tier, doesn't replace it.
-- A max-upgraded campfire (~56 heat) approaches but never reaches a base fire pit (60).

local GameState = require('src.game_state')

local ok_Building, Building = pcall(require, 'src.building.building')
local ok_Thermal,  Thermal   = pcall(require, 'src.sim.thermal')
local ok_Lighting, Lighting  = pcall(require, 'src.sim.lighting')

local Upgrades = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

-- Stat multipliers per upgrade tier (relative to base def values).
-- primary: main output stat (heatOutput, power output, light radius).
-- fuelRate: fuel efficiency (lower = burns less fuel).
local TIER_MULTS = {
    [1] = { primary = 1.15, fuelRate = 0.95 },
    [2] = { primary = 1.30, fuelRate = 0.90 },
    [3] = { primary = 1.40, fuelRate = 0.85 },
}

-- Per-building upgrade definitions.
-- Buildings not listed here cannot be upgraded.
-- Cost scaling: tier 1 ~75% of base build cost, tier 2 ~125%, tier 3 ~175%.
local UPGRADE_DEFS = {
    ---------------------------------------------------------------------------
    -- Heat buildings
    ---------------------------------------------------------------------------
    campfire = { maxTier = 3, costs = {
        [1] = { wood = 6, stone = 2 },
        [2] = { wood = 10, stone = 4, metal = 2 },
        [3] = { wood = 14, stone = 6, metal = 4 },
    }},
    fire_pit = { maxTier = 3, costs = {
        [1] = { stone = 6, wood = 4 },
        [2] = { stone = 10, metal = 3 },
        [3] = { stone = 14, metal = 6, components = 1 },
    }},
    deep_fire_pit = { maxTier = 3, costs = {
        [1] = { stone = 10, metal = 2 },
        [2] = { stone = 18, metal = 4 },
        [3] = { stone = 26, metal = 7, components = 2 },
    }},
    heater = { maxTier = 3, costs = {
        [1] = { metal = 8, components = 1 },
        [2] = { metal = 12, components = 3 },
        [3] = { metal = 18, components = 4, steel = 2 },
    }},
    bonfire = { maxTier = 2, costs = {
        [1] = { wood = 6 },
        [2] = { wood = 10, stone = 3 },
    }},

    ---------------------------------------------------------------------------
    -- Power generators
    ---------------------------------------------------------------------------
    coal_burner = { maxTier = 3, costs = {
        [1] = { metal = 8, components = 1 },
        [2] = { metal = 12, components = 3 },
        [3] = { metal = 18, components = 4, steel = 2 },
    }},
    gas_burner = { maxTier = 3, costs = {
        [1] = { metal = 6, components = 1 },
        [2] = { metal = 10, components = 3 },
        [3] = { metal = 14, components = 4, steel = 2 },
    }},
    thermal_gen = { maxTier = 3, costs = {
        [1] = { metal = 9, components = 2 },
        [2] = { metal = 15, components = 4 },
        [3] = { metal = 21, components = 5, steel = 3 },
    }},
    peat_burner = { maxTier = 3, costs = {
        [1] = { stone = 8, metal = 4 },
        [2] = { stone = 12, metal = 6, components = 1 },
        [3] = { stone = 18, metal = 9, components = 2 },
    }},
    wind_turbine = { maxTier = 2, costs = {
        [1] = { metal = 9, components = 3 },
        [2] = { metal = 15, components = 5 },
    }},
    solar_panel = { maxTier = 2, costs = {
        [1] = { metal = 6, components = 2 },
        [2] = { metal = 10, components = 4 },
    }},
    bio_reactor = { maxTier = 2, costs = {
        [1] = { metal = 9, components = 3 },
        [2] = { metal = 15, components = 5 },
    }},
    mini_reactor = { maxTier = 2, costs = {
        [1] = { steel = 8, components = 4, circuit = 1 },
        [2] = { steel = 12, components = 6, circuit = 2 },
    }},
    fuel_cell_gen = { maxTier = 2, costs = {
        [1] = { metal = 8, components = 3 },
        [2] = { metal = 14, components = 5 },
    }},
    geothermal = { maxTier = 2, costs = {
        [1] = { metal = 15, components = 4, steel = 4 },
        [2] = { metal = 25, components = 6, steel = 6 },
    }},

    ---------------------------------------------------------------------------
    -- Automated miners
    ---------------------------------------------------------------------------
    burner_drill = { maxTier = 2, statType = 'none', costs = {
        [1] = { metal = 5, stone = 6 },
        [2] = { metal = 8, components = 2 },
    }},
    electric_drill = { maxTier = 3, statType = 'none', costs = {
        [1] = { metal = 8, components = 3 },
        [2] = { metal = 14, components = 5 },
        [3] = { metal = 20, components = 6, circuit = 1 },
    }},
    advanced_drill = { maxTier = 3, statType = 'none', costs = {
        [1] = { steel = 6, components = 4, circuit = 1 },
        [2] = { steel = 10, components = 6, circuit = 2 },
        [3] = { steel = 14, components = 8, circuit = 3 },
    }},
    bore_drill = { maxTier = 2, statType = 'none', costs = {
        [1] = { steel = 8, components = 5, circuit = 2 },
        [2] = { steel = 14, components = 8, circuit = 4 },
    }},
    deep_drill = { maxTier = 2, statType = 'none', costs = {
        [1] = { steel = 6, components = 4, circuit = 1 },
        [2] = { steel = 10, components = 6, circuit = 2 },
    }},

    ---------------------------------------------------------------------------
    -- Walls (no primary stat -- upgrade implies durability, tracked externally)
    ---------------------------------------------------------------------------
    wall_insulated = { maxTier = 2, statType = 'none', costs = {
        [1] = { metal = 3, components = 1 },
        [2] = { metal = 5, components = 2 },
    }},

    ---------------------------------------------------------------------------
    -- Lights
    ---------------------------------------------------------------------------
    torch = { maxTier = 2, statType = 'light', costs = {
        [1] = { wood = 2 },
        [2] = { wood = 3, metal = 1 },
    }},
    standing_lamp = { maxTier = 2, statType = 'light', costs = {
        [1] = { metal = 4, components = 1 },
        [2] = { metal = 6, components = 2 },
    }},
}

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

--- Reverse-lookup the defId string for a placed building's def table.
--- Building.defs is keyed by defId; placed buildings store the def reference
--- but not the string key. This scans once per call (small table).
local function findDefId(def)
    if not ok_Building then return nil end
    for id, d in pairs(Building.defs) do
        if d == def then return id end
    end
    return nil
end

--- Return the upgrade tier for a placed building (0 if never upgraded).
local function getTier(info)
    return (info and info.upgradeLevel) or 0
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Return the UPGRADE_DEFS entry for a defId, or nil if not upgradable.
function Upgrades.getUpgradeDef(defId)
    return UPGRADE_DEFS[defId]
end

--- Calculate the effective value of a stat at a given upgrade tier.
--- statName: 'heatOutput', 'fuelRate', 'lightRadius', 'lightIntensity', 'power'
--- Returns the base def value when tier is 0 or the stat is unrecognized.
function Upgrades.getEffectiveStatByDef(defId, upgradeLevel, statName)
    local def = ok_Building and Building.defs[defId]
    if not def then return 0 end

    local tier = upgradeLevel or 0
    if tier <= 0 then
        return def[statName] or 0
    end

    local mults = TIER_MULTS[tier]
    if not mults then return def[statName] or 0 end

    local upgDef = UPGRADE_DEFS[defId]

    -- Fuel rate uses the fuelRate multiplier
    if statName == 'fuelRate' then
        return (def.fuelRate or 0) * mults.fuelRate
    end

    -- Light stats use the primary multiplier on radius
    if statName == 'lightRadius' then
        local base = def.lightRadius
        if not base and def.lightPreset and ok_Lighting then
            local preset = Lighting.PRESETS[def.lightPreset]
            base = preset and preset.radius
        end
        return (base or 0) * mults.primary
    end

    if statName == 'lightIntensity' then
        local base = def.lightIntensity
        if not base and def.lightPreset and ok_Lighting then
            local preset = Lighting.PRESETS[def.lightPreset]
            base = preset and preset.intensity
        end
        -- Intensity caps at 1.0
        return math.min(1.0, (base or 0) * mults.primary)
    end

    -- Walls with statType 'none' have no scaled stat
    if upgDef and upgDef.statType == 'none' then
        return def[statName] or 0
    end

    -- Default: treat as primary stat (heatOutput, power, etc.)
    return (def[statName] or 0) * mults.primary
end

--- Same as getEffectiveStatByDef but takes a placed building info table.
function Upgrades.getEffectiveStat(info, statName)
    if not info or not info.def then return 0 end
    local defId = findDefId(info.def)
    if not defId then return info.def[statName] or 0 end
    return Upgrades.getEffectiveStatByDef(defId, getTier(info), statName)
end

--- Return the cost table for the next upgrade tier, or nil if not upgradable.
function Upgrades.getUpgradeCost(x, y, depth)
    if not ok_Building then return nil end
    local info = Building.getAt(x, y, depth)
    if not info then return nil end

    local defId = findDefId(info.def)
    if not defId then return nil end

    local upgDef = UPGRADE_DEFS[defId]
    if not upgDef then return nil end

    local nextTier = getTier(info) + 1
    if nextTier > upgDef.maxTier then return nil end

    return upgDef.costs[nextTier]
end

--- Gather full upgrade info for a placed building at (x, y).
--- Returns nil if no building exists there.
--- Returns { defId, currentTier, maxTier, nextCost, statPreview } or
--- { defId, currentTier, maxTier, nextCost = nil } when already at max.
function Upgrades.getUpgradeInfo(x, y, depth)
    if not ok_Building then return nil end
    local info = Building.getAt(x, y, depth)
    if not info then return nil end

    local defId = findDefId(info.def)
    if not defId then return nil end

    local upgDef = UPGRADE_DEFS[defId]
    local currentTier = getTier(info)
    local maxTier = upgDef and upgDef.maxTier or 0

    local result = {
        defId       = defId,
        currentTier = currentTier,
        maxTier     = maxTier,
        nextCost    = nil,
        statPreview = nil,
    }

    if not upgDef then return result end

    local nextTier = currentTier + 1
    if nextTier > maxTier then return result end

    result.nextCost = upgDef.costs[nextTier]

    -- Build stat preview: current value vs next-tier value for relevant stats
    local preview = {}
    local statNames = { 'heatOutput', 'fuelRate' }

    -- Include light stats for light-type buildings
    if upgDef.statType == 'light' or info.def.lightPreset or info.def.lightRadius then
        statNames[#statNames + 1] = 'lightRadius'
    end

    for _, stat in ipairs(statNames) do
        local cur = Upgrades.getEffectiveStatByDef(defId, currentTier, stat)
        local nxt = Upgrades.getEffectiveStatByDef(defId, nextTier, stat)
        if cur > 0 or nxt > 0 then
            preview[stat] = { current = cur, next = nxt }
        end
    end

    result.statPreview = preview
    return result
end

--- Check whether the building at (x, y) can be upgraded right now.
--- Returns true or false + a reason string.
function Upgrades.canUpgrade(x, y, depth)
    if not ok_Building then return false, 'Building system unavailable' end

    local info = Building.getAt(x, y, depth)
    if not info then return false, 'No building here' end

    local defId = findDefId(info.def)
    if not defId then return false, 'Unknown building type' end

    local upgDef = UPGRADE_DEFS[defId]
    if not upgDef then return false, 'This building cannot be upgraded' end

    local nextTier = getTier(info) + 1
    if nextTier > upgDef.maxTier then return false, 'Already at max tier' end

    -- Check resource cost
    local cost = upgDef.costs[nextTier]
    if not cost then return false, 'No upgrade cost defined' end

    for res, amount in pairs(cost) do
        if (GameState.resources[res] or 0) < amount then
            return false, 'Not enough ' .. res
        end
    end

    return true
end

--- Apply the next upgrade tier to the building at (x, y).
--- Validates prerequisites, spends resources, updates live systems.
--- Returns true on success, or false + reason on failure.
function Upgrades.applyUpgrade(x, y, depth)
    local canDo, reason = Upgrades.canUpgrade(x, y, depth)
    if not canDo then return false, reason end

    local info = Building.getAt(x, y, depth)
    local defId = findDefId(info.def)
    local upgDef = UPGRADE_DEFS[defId]
    local oldTier = getTier(info)
    local newTier = oldTier + 1
    local cost = upgDef.costs[newTier]

    -- Spend resources
    local sOk, StorageNet = pcall(require, 'src.logistics.storage_network')
    for res, amount in pairs(cost) do
        if sOk then StorageNet.withdraw(res, amount, x, y)
        else GameState.spendResource(res, amount) end
    end

    -- Record old effective values before bumping tier
    local oldHeat = Upgrades.getEffectiveStatByDef(defId, oldTier, 'heatOutput')

    -- Bump tier on the placed building
    info.upgradeLevel = newTier

    -- Compute new effective values
    local newHeat = Upgrades.getEffectiveStatByDef(defId, newTier, 'heatOutput')

    -- Update thermal system (swap heat source magnitude)
    if ok_Thermal and info.def.heatOutput and info.active then
        if oldHeat ~= 0 then
            Thermal.removeHeatSource(x, y, oldHeat, info.depth or 0)
        end
        if newHeat ~= 0 then
            Thermal.addHeatSource(x, y, newHeat, info.depth or 0,
                info.def.heatTarget, info.def.heatDanger, info.def.heatControllable)
        end
    end

    -- Update lighting system (remove old, add new with scaled values)
    if ok_Lighting and (info.def.lightPreset or info.def.lightRadius) then
        Lighting.removeLight(x, y)
        local newRadius    = Upgrades.getEffectiveStatByDef(defId, newTier, 'lightRadius')
        local newIntensity = Upgrades.getEffectiveStatByDef(defId, newTier, 'lightIntensity')
        if newRadius > 0 then
            Lighting.addLightCustom(x, y, newRadius, newIntensity)
        end
    end

    -- Update miner upgrade tier on the ECS component (match depth too)
    if info.def.minerType then
        local ECS = require('src.ecs.ecs')
        local bDepth = info.depth or 0
        for mid, comps in ECS.query('miner', 'pos') do
            if comps.pos.x == x and comps.pos.y == y and (comps.pos.depth or 0) == bDepth then
                comps.miner.upgradeTier = newTier
                break
            end
        end
    end

    -- Update power generator output if this is a generator building
    if info.def.genType then
        local pok, Power = pcall(require, 'src.sim.power')
        if pok and Power.setGeneratorOutputMult then
            local ECS = require('src.ecs.ecs')
            -- Find the generator entity at this position
            local gens = Power.getGenerators()
            for eid, gen in pairs(gens) do
                if gen.x == x and gen.y == y then
                    local mults = TIER_MULTS[newTier]
                    Power.setGeneratorOutputMult(eid, mults and mults.primary or 1.0)
                    break
                end
            end
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Accessors for external systems
---------------------------------------------------------------------------

--- Return the TIER_MULTS table (read-only usage by power.lua, building.lua).
function Upgrades.getTierMults()
    return TIER_MULTS
end

--- Return the fuel rate multiplier for a placed building.
--- Convenience for Building.update() to call instead of raw def.fuelRate.
function Upgrades.getFuelRateMult(info)
    local tier = getTier(info)
    if tier <= 0 then return 1.0 end
    local mults = TIER_MULTS[tier]
    return mults and mults.fuelRate or 1.0
end

--- Return the primary stat multiplier for a placed building.
--- Used by power.lua to scale generator output.
function Upgrades.getPrimaryMult(info)
    local tier = getTier(info)
    if tier <= 0 then return 1.0 end
    local mults = TIER_MULTS[tier]
    return mults and mults.primary or 1.0
end

return Upgrades
