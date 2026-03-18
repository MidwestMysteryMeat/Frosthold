-- agriculture.lua — Greenhouse farming and crop system
-- RimWorld-inspired growth: rate = tempFactor * lightFactor * waterFactor
-- Crops halt growth below 50% light (need sun lamps indoors at night).
-- Growth times tuned for playability at 1x speed (minutes, not hours).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Agriculture = {}

local OptionalModules = {}

local function getOptionalModule(path)
    local mod = OptionalModules[path]
    if mod ~= nil then
        return mod or nil
    end
    local ok, loaded = pcall(require, path)
    OptionalModules[path] = ok and loaded or false
    return OptionalModules[path] or nil
end

-- Lazy-loaded modules (avoid pcall in hot-path crop growth system)
local _Perks
local function lazyLoadAg()
    if _Perks ~= nil then return end
    _Perks = getOptionalModule('src.colony.perks') or false
end

---------------------------------------------------------------------------
-- Light threshold — below this, light-dependent crops stop growing
-- (RimWorld uses 51%; we use 50%)
---------------------------------------------------------------------------

local MIN_LIGHT_FOR_GROWTH = 0.5

---------------------------------------------------------------------------
-- Crop definitions — RimWorld-inspired, adapted to arctic/sci-fi setting
--
-- growTime: base seconds to mature at 1x speed, ideal conditions
-- yield: { item, min, max } — harvested resource
-- idealTemp: { low, high } — optimal growth range (1.0x rate)
-- minTemp / maxTemp: growth stops or crop wilts outside these
-- seedCost: food consumed to plant
-- waterNeed: 0-3 scale, how much colony water consumed during growth
-- light: true = needs MIN_LIGHT_FOR_GROWTH to grow (halts at night outdoors)
-- co2Bonus: true = grows faster with high CO2 (fungal crops)
-- hardiness: 0-1 — tolerance to temperature extremes (higher = more forgiving)
-- desc: short description for UI
---------------------------------------------------------------------------

local CROPS = {
    -- FOOD CROPS (primary calorie sources)

    ice_rice = {
        name       = 'Ice Rice',
        desc       = 'Fast-growing grain. Low yield but quick harvests.',
        growTime   = 200,
        yield      = { item = 'food', min = 3, max = 5 },
        idealTemp  = { 10, 25 },
        minTemp    = -2,
        maxTemp    = 38,
        seedCost   = 1,
        waterNeed  = 2,
        light      = true,
        hardiness  = 0.3,
    },
    frost_potatoes = {
        name       = 'Frost Potatoes',
        desc       = 'Hardy tuber. Grows in poor conditions where other crops fail.',
        growTime   = 360,
        yield      = { item = 'food', min = 7, max = 12 },
        idealTemp  = { 5, 22 },
        minTemp    = -8,
        maxTemp    = 35,
        seedCost   = 2,
        waterNeed  = 1,
        light      = true,
        hardiness  = 0.8,
    },
    tundra_corn = {
        name       = 'Tundra Corn',
        desc       = 'Slow but high-yield grain. Needs warmth and good light.',
        growTime   = 600,
        yield      = { item = 'food', min = 14, max = 22 },
        idealTemp  = { 15, 30 },
        minTemp    = 3,
        maxTemp    = 42,
        seedCost   = 3,
        waterNeed  = 2,
        light      = true,
        hardiness  = 0.2,
    },
    thermal_berries = {
        name       = 'Thermal Berries',
        desc       = 'Heat-loving fruit. Good raw morale. Needs warm rooms.',
        growTime   = 280,
        yield      = { item = 'food', min = 4, max = 8 },
        idealTemp  = { 20, 35 },
        minTemp    = 5,
        maxTemp    = 50,
        seedCost   = 2,
        waterNeed  = 2,
        light      = true,
        hardiness  = 0.4,
    },
    alien_fungus = {
        name       = 'Alien Fungus',
        desc       = 'Grows in darkness. No water needed. Thrives on CO2.',
        growTime   = 420,
        yield      = { item = 'food', min = 6, max = 14 },
        idealTemp  = { 2, 18 },
        minTemp    = -12,
        maxTemp    = 28,
        seedCost   = 1,
        waterNeed  = 0,
        light      = false,
        co2Bonus   = true,
        hardiness  = 0.9,
    },
    haygrass = {
        name       = 'Haygrass',
        desc       = 'Fast-growing animal feed. Cannot be eaten by colonists.',
        growTime   = 180,
        yield      = { item = 'hay', min = 10, max = 18 },
        idealTemp  = { 5, 22 },
        minTemp    = -5,
        maxTemp    = 35,
        seedCost   = 1,
        waterNeed  = 1,
        light      = true,
        hardiness  = 0.7,
    },

    -- INDUSTRIAL CROPS (materials)

    healroot = {
        name       = 'Healroot',
        desc       = 'Medicinal plant. Slow growth, yields herbal medicine.',
        growTime   = 500,
        yield      = { item = 'medicine', min = 2, max = 4 },
        idealTemp  = { 8, 20 },
        minTemp    = -2,
        maxTemp    = 28,
        seedCost   = 3,
        waterNeed  = 1,
        light      = false,
        hardiness  = 0.5,
    },
    fiber_vine = {
        name       = 'Fiber Vine',
        desc       = 'Textile plant. Yields material for clothing and gear.',
        growTime   = 400,
        yield      = { item = 'hide', min = 3, max = 7 },
        idealTemp  = { 12, 28 },
        minTemp    = 0,
        maxTemp    = 38,
        seedCost   = 2,
        waterNeed  = 2,
        light      = true,
        hardiness  = 0.3,
    },
    frostweed = {
        name       = 'Frostweed',
        desc       = 'Premium textile. Very slow growth, yields superior fiber.',
        growTime   = 900,
        yield      = { item = 'hide', min = 4, max = 6 },
        idealTemp  = { 5, 15 },
        minTemp    = -10,
        maxTemp    = 25,
        seedCost   = 4,
        waterNeed  = 1,
        light      = true,
        hardiness  = 0.6,
    },

    -- DRUG CROPS

    psychoid_plant = {
        name       = 'Psychoid Plant',
        desc       = 'Source of psychoid leaves. Used in drug production.',
        growTime   = 400,
        yield      = { item = 'psychoid_leaf', min = 3, max = 6 },
        idealTemp  = { 15, 30 },
        minTemp    = 5,
        maxTemp    = 40,
        seedCost   = 3,
        waterNeed  = 1,
        light      = true,
        hardiness  = 0.3,
    },
    smokeleaf_plant = {
        name       = 'Smokeleaf Plant',
        desc       = 'Recreational herb. Moderate growth, good yield.',
        growTime   = 300,
        yield      = { item = 'smokeleaf_leaf', min = 4, max = 9 },
        idealTemp  = { 10, 26 },
        minTemp    = 0,
        maxTemp    = 34,
        seedCost   = 2,
        waterNeed  = 1,
        light      = true,
        hardiness  = 0.4,
    },
    hops_plant = {
        name       = 'Hops',
        desc       = 'Brewing ingredient. Makes beer at a brewery.',
        growTime   = 320,
        yield      = { item = 'hops', min = 6, max = 12 },
        idealTemp  = { 8, 24 },
        minTemp    = -5,
        maxTemp    = 30,
        seedCost   = 2,
        waterNeed  = 2,
        light      = true,
        hardiness  = 0.5,
    },

    -- SURFACE / OUTDOOR CROPS

    frost_moss = {
        name       = 'Frost Moss',
        desc       = 'Survives extreme cold. Low yield, but grows almost anywhere.',
        growTime   = 150,
        yield      = { item = 'plant_fiber', min = 2, max = 4 },
        idealTemp  = { -5, 10 },
        minTemp    = -30,
        maxTemp    = 20,
        seedCost   = 1,
        waterNeed  = 0,
        light      = false,
        hardiness  = 0.95,
        tier       = 'outdoor',
    },
    ice_berry = {
        name       = 'Ice Berry',
        desc       = 'Small sweet berries found on the tundra surface.',
        growTime   = 240,
        yield      = { item = 'berries', min = 4, max = 8 },
        idealTemp  = { 0, 15 },
        minTemp    = -12,
        maxTemp    = 25,
        seedCost   = 2,
        waterNeed  = 1,
        light      = true,
        hardiness  = 0.7,
        tier       = 'outdoor',
    },
    tundra_grass = {
        name       = 'Tundra Grass',
        desc       = 'Coarse grass. Animal feed and compost material.',
        growTime   = 160,
        yield      = { item = 'hay', min = 8, max = 14 },
        idealTemp  = { 0, 18 },
        minTemp    = -10,
        maxTemp    = 28,
        seedCost   = 1,
        waterNeed  = 1,
        light      = true,
        hardiness  = 0.8,
        tier       = 'outdoor',
    },

    -- UNDERGROUND / CAVE CROPS

    cave_fungus = {
        name       = 'Cave Fungus',
        desc       = 'Grows in underground caves. No light or water needed.',
        growTime   = 350,
        yield      = { item = 'food', min = 5, max = 10 },
        idealTemp  = { 0, 15 },
        minTemp    = -15,
        maxTemp    = 22,
        seedCost   = 1,
        waterNeed  = 0,
        light      = false,
        co2Bonus   = true,
        hardiness  = 0.85,
        tier       = 'outdoor',
    },
    glow_lichen = {
        name       = 'Glow Lichen',
        desc       = 'Bioluminescent cave plant. Edible, also provides faint light.',
        growTime   = 500,
        yield      = { item = 'food', min = 3, max = 6 },
        idealTemp  = { 2, 16 },
        minTemp    = -8,
        maxTemp    = 24,
        seedCost   = 2,
        waterNeed  = 0,
        light      = false,
        co2Bonus   = true,
        hardiness  = 0.7,
        tier       = 'outdoor',
    },
    deep_root = {
        name       = 'Deep Root',
        desc       = 'Starchy underground tuber. High calorie, long grow time.',
        growTime   = 700,
        yield      = { item = 'food', min = 12, max = 20 },
        idealTemp  = { 5, 18 },
        minTemp    = -5,
        maxTemp    = 25,
        seedCost   = 3,
        waterNeed  = 1,
        light      = false,
        hardiness  = 0.6,
        tier       = 'outdoor',
    },

    -- MEDICINAL CROPS

    frost_leaf = {
        name       = 'Frost Leaf',
        desc       = 'Cold-resistant medicinal herb. Yields basic medicine.',
        growTime   = 450,
        yield      = { item = 'medicinal_herb', min = 2, max = 5 },
        idealTemp  = { 0, 14 },
        minTemp    = -12,
        maxTemp    = 22,
        seedCost   = 3,
        waterNeed  = 1,
        light      = true,
        hardiness  = 0.6,
        tier       = 'outdoor',
    },
    blood_moss = {
        name       = 'Blood Moss',
        desc       = 'Red-tinged moss with antiseptic properties. Grows in caves.',
        growTime   = 600,
        yield      = { item = 'medicine', min = 3, max = 5 },
        idealTemp  = { 5, 18 },
        minTemp    = -5,
        maxTemp    = 26,
        seedCost   = 4,
        waterNeed  = 1,
        light      = false,
        hardiness  = 0.5,
        tier       = 'greenhouse',
    },

    -- EXOTIC CROPS (research-gated)

    precursor_vine = {
        name       = 'Precursor Vine',
        desc       = 'Alien growth. Yields rare bio-material. Needs controlled conditions.',
        growTime   = 900,
        yield      = { item = 'eldritch_ichor', min = 1, max = 3 },
        idealTemp  = { 15, 28 },
        minTemp    = 5,
        maxTemp    = 35,
        seedCost   = 5,
        waterNeed  = 3,
        light      = true,
        hardiness  = 0.1,
        tier       = 'hydroponic',
    },
    void_bloom = {
        name       = 'Void Bloom',
        desc       = 'Grows near anomalous sites. Yields void crystal shards.',
        growTime   = 1200,
        yield      = { item = 'void_crystal', min = 1, max = 2 },
        idealTemp  = { 10, 22 },
        minTemp    = 0,
        maxTemp    = 30,
        seedCost   = 6,
        waterNeed  = 2,
        light      = false,
        co2Bonus   = true,
        hardiness  = 0.2,
        tier       = 'hydroponic',
    },
}

Agriculture.CROPS = CROPS

---------------------------------------------------------------------------
-- Farm plot entity management
---------------------------------------------------------------------------

-- Farming tier hierarchy: hydroponic > greenhouse > outdoor
-- Higher-tier plots can grow any lower-tier crop.
local TIER_RANK = { outdoor = 1, greenhouse = 2, hydroponic = 3 }

function Agriculture.plantCrop(x, y, cropId, farmTier, depth)
    local def = CROPS[cropId]
    if not def then return nil, 'Unknown crop: ' .. tostring(cropId) end

    -- Check farming tier requirement
    local requiredTier = def.tier or 'outdoor'
    local plotTier = farmTier or 'outdoor'
    local reqRank = TIER_RANK[requiredTier] or 1
    local plotRank = TIER_RANK[plotTier] or 1
    if plotRank < reqRank then
        return nil, 'Needs ' .. requiredTier .. ' plot or better'
    end

    -- Spend seed cost (food)
    if (GameState.resources.food or 0) < def.seedCost then
        return nil, 'Not enough food for seeds'
    end
    local sOk, StorageNet = pcall(require, 'src.logistics.storage_network')
    if sOk then StorageNet.withdraw('food', def.seedCost, x, y)
    else GameState.spendResource('food', def.seedCost) end

    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth or 0 })
    ECS.set(id, 'crop', {
        type     = cropId,
        name     = def.name,
        growth   = 0,        -- 0 to growTime
        mature   = false,
        wilted   = false,
        growTime = def.growTime,
        farmTier = plotTier,
    })

    return id
end

function Agriculture.harvest(entityId)
    local crop = ECS.get(entityId, 'crop')
    if not crop or not crop.mature then return false end

    local def = CROPS[crop.type]
    if not def then return false end

    local pos = ECS.get(entityId, 'pos')
    local amount = math.random(def.yield.min, def.yield.max)
    -- Perk: agricultural_expert harvest bonus
    local Perks = getOptionalModule('src.colony.perks')
    if Perks then
        amount = amount + Perks.getSumEffect('harvestBonusFlat')
    end

    -- Spawn harvested items on the ground (hauled to stockpiles by hauling AI)
    local ItemsMod = getOptionalModule('src.world.items')
    if ItemsMod and pos then
        local cat = 'raw'
        -- Food crops get 'food' category so they route to food stockpiles
        if def.yield.item == 'food' or def.yield.item == 'berries'
            or def.yield.item == 'mushrooms' or def.yield.item == 'raw_meat' then
            cat = 'food'
        end
        ItemsMod.spawn(pos.x, pos.y, def.yield.item, amount, cat)
    else
        -- Fallback: add to global resources
        GameState.addResource(def.yield.item, amount)
    end

    ECS.destroy(entityId)
    return true, amount
end

---------------------------------------------------------------------------
-- Growth rate calculation — RimWorld-style multiplicative factors
-- finalRate = tempFactor * lightFactor * waterFactor * perkMult
-- Each factor is 0-1 (or slightly above 1 for CO2 bonus).
-- Rate of 0 = halted. Negative = wilting.
---------------------------------------------------------------------------

local function getGrowthRate(crop, pos)
    local def = CROPS[crop.type]
    if not def then return 0 end

    local World = getOptionalModule('src.world.tilemap')
    if not World then return 0 end
    local temp = World.getTemp(pos.x, pos.y, pos.depth or 0)

    -- Temperature factor
    if temp < def.minTemp then return 0 end      -- frozen
    if temp > def.maxTemp then return -0.5 end    -- wilting

    local tempFactor = 1.0
    if temp >= def.idealTemp[1] and temp <= def.idealTemp[2] then
        tempFactor = 1.0
    elseif temp < def.idealTemp[1] then
        local range = def.idealTemp[1] - def.minTemp
        if range > 0 then
            local base = (def.hardiness or 0.3) * 0.5  -- hardy crops suffer less
            tempFactor = base + (1 - base) * ((temp - def.minTemp) / range)
        end
    else
        local range = def.maxTemp - def.idealTemp[2]
        if range > 0 then
            local base = (def.hardiness or 0.3) * 0.3
            tempFactor = base + (1 - base) * ((def.maxTemp - temp) / range)
        end
    end

    -- Light factor (RimWorld: below 51% light = 0 growth for light-dependent crops)
    local lightFactor = 1.0
    if def.light then
        local Lighting = getOptionalModule('src.sim.lighting')
        if Lighting then
            local lightLevel = Lighting.getLightAt(pos.x, pos.y) or 0
            if lightLevel < MIN_LIGHT_FOR_GROWTH then
                lightFactor = 0  -- halted, not wilting
            else
                -- Scale linearly from 50% to 100% light
                lightFactor = 0.5 + 0.5 * ((lightLevel - MIN_LIGHT_FOR_GROWTH) / (1 - MIN_LIGHT_FOR_GROWTH))
            end
        end
    end

    -- CO2 bonus for fungal crops
    local co2Factor = 1.0
    if def.co2Bonus then
        local Atmo = getOptionalModule('src.sim.atmosphere')
        if Atmo then
            local co2 = Atmo.getTileCO2(pos.x, pos.y, pos.depth or 0)
            if co2 > 10 then
                co2Factor = 1 + math.min(0.5, co2 * 0.01)
            end
        end
    end

    -- Water factor
    local waterFactor = 1.0
    if def.waterNeed and def.waterNeed > 0 then
        local waterAvail = GameState.resources.water or 0
        if waterAvail <= 0 then
            waterFactor = 0.1
        elseif waterAvail < def.waterNeed * 10 then
            waterFactor = 0.3 + 0.7 * (waterAvail / (def.waterNeed * 10))
        end
    end

    -- Seasonal growth multiplier
    local seasonMult = 1.0
    local Seasons = getOptionalModule('src.world.seasons')
    if Seasons then seasonMult = Seasons.getGrowthMult() end

    -- Environmental hazard penalties
    local hazardMult = 1.0
    if GameState.toxicFallout and GameState.toxicFallout.active then hazardMult = hazardMult * 0.2 end
    if GameState.volcanicAsh and GameState.volcanicAsh.active then hazardMult = hazardMult * 0.5 end

    return tempFactor * lightFactor * waterFactor * co2Factor * seasonMult * hazardMult
end

---------------------------------------------------------------------------
-- ECS growth system — runs each tick
---------------------------------------------------------------------------

local function cropGrowthSystem(dt, id, comps)
    local crop = comps.crop
    local pos  = comps.pos

    if crop.mature or crop.wilted then return end

    local rate = getGrowthRate(crop, pos)

    if rate < 0 then
        crop.wilted = true
        return
    end

    -- Perk: agricultural_expert crop growth multiplier
    lazyLoadAg()
    if _Perks then
        rate = rate * _Perks.getMultEffect('cropGrowthMult')
    end

    crop.growth = crop.growth + dt * rate

    -- Consume water proportional to growth rate
    local def = CROPS[crop.type]
    if def and def.waterNeed and def.waterNeed > 0 and rate > 0 then
        local waterCost = def.waterNeed * 0.002 * dt * rate
        if (GameState.resources.water or 0) >= waterCost then
            GameState.resources.water = GameState.resources.water - waterCost
        end
    end

    if crop.growth >= crop.growTime then
        crop.growth = crop.growTime
        crop.mature = true
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Agriculture.getCropInfo(entityId)
    local crop = ECS.get(entityId, 'crop')
    if not crop then return nil end
    local def = CROPS[crop.type]
    return {
        type     = crop.type,
        name     = crop.name,
        desc     = def and def.desc or '',
        growth   = crop.growth,
        growTime = crop.growTime,
        progress = crop.growth / crop.growTime,
        mature   = crop.mature,
        wilted   = crop.wilted,
    }
end

function Agriculture.getCropDef(cropId)
    return CROPS[cropId]
end

function Agriculture.getAllCropDefs()
    return CROPS
end

function Agriculture.getCropsForTier(tier)
    local rank = TIER_RANK[tier] or 1
    local result = {}
    for id, def in pairs(CROPS) do
        local reqRank = TIER_RANK[def.tier or 'outdoor'] or 1
        if rank >= reqRank then
            result[id] = def
        end
    end
    return result
end

function Agriculture.getCropCount()
    local count = 0
    for _ in ECS.query('crop') do count = count + 1 end
    return count
end

function Agriculture.getMatureCrops()
    local result = {}
    for id, comps in ECS.query('crop', 'pos') do
        if comps.crop.mature then
            result[#result + 1] = { id = id, pos = comps.pos, crop = comps.crop }
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Auto-harvest: create harvest tasks for mature crops without one
---------------------------------------------------------------------------

local harvestCheckTimer = 0
local HARVEST_CHECK_INTERVAL = 5.0

function Agriculture.step(dt)
    harvestCheckTimer = harvestCheckTimer + dt
    if harvestCheckTimer < HARVEST_CHECK_INTERVAL then return end
    harvestCheckTimer = 0

    local Jobs = getOptionalModule('src.colonist.jobs')
    if not Jobs then return end
    for id, comps in ECS.query('crop', 'pos') do
        if comps.crop.mature and not comps.crop._harvestTaskId then
            local taskId = Jobs.createTask('harvest', comps.pos.x, comps.pos.y, { cropId = id })
            if taskId then
                comps.crop._harvestTaskId = taskId
            end
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Agriculture.registerSystems()
    ECS.addSystem('crop_growth', { 'crop', 'pos' }, cropGrowthSystem, 16)
end

Agriculture.registerSystems()

return Agriculture
