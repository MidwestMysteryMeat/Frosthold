-- thermal_deepening.lua — Heat-gated zones, battery heat exchange, thermal core synthesis
-- Heat-gated areas are extreme regions below the planet-relative cold threshold
-- that damage unprotected colonists.
-- Thermal batteries store excess room heat and release it when temps drop.
-- Thermal core valuation varies by faction.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ThermalDeepening = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

-- Colonists in tiles colder than this without a thermal suit take cold damage.
-- Keep the gate below normal outdoor ambient so ordinary weather does not
-- turn the entire starting surface into a deep-cold damage zone.
local HEAT_GATE_MARGIN    = 25   -- degrees below planet ambient
local HEAT_GATE_FLOOR     = -60  -- never gate warmer than this
local COLD_DAMAGE_RATE    = 0.5  -- HP per sim-second without suit
local COLD_CHECK_INTERVAL = 2.0  -- seconds between cold damage ticks

local function getHeatGateThreshold()
    local base = GameState.baseTemp or -40
    return math.min(HEAT_GATE_FLOOR, base - HEAT_GATE_MARGIN)
end

-- Battery heat exchange
local BATTERY_HEAT_ABSORB = 0.02   -- fraction of excess heat absorbed per tick
local BATTERY_HEAT_RELEASE = 0.015 -- fraction of stored heat released per tick
local BATTERY_RELEASE_THRESHOLD = 5 -- release heat when room temp < target by this much
local BATTERY_ABSORB_THRESHOLD  = 5 -- absorb heat when room temp > target by this much
local BATTERY_TARGET_TEMP = 18     -- comfortable room target for battery logic

-- Thermal core synthesis (resource costs checked in production recipes)
local CORE_SYNTH_RESEARCH = 'thermal_synthesis'  -- research node needed

---------------------------------------------------------------------------
-- Heat-gated zone tracking
-- Marks map regions too cold for unprotected colonists.
-- Deep cold zones contain valuable deposits (thermal alloy ore, precursor fragments).
---------------------------------------------------------------------------

local coldCheckTimer = 0

-- Apply cold damage to colonists in heat-gated zones without thermal suits
local function checkHeatGatedDamage(dt)
    coldCheckTimer = coldCheckTimer + dt
    if coldCheckTimer < COLD_CHECK_INTERVAL then return end
    coldCheckTimer = 0

    local tokT, Thermal = pcall(require, 'src.sim.thermal')
    if not tokT then return end

    local tokC, Clothing = pcall(require, 'src.colonist.clothing')
    local gateThreshold = getHeatGateThreshold()

    for id, comps in ECS.query('colonist', 'pos', 'needs') do
        local col = comps.colonist
        if col.state == 'dead' or col.state == 'away_expedition' then goto nextCol end

        local pos = comps.pos
        local temp = Thermal.getTileTemp(pos.x, pos.y)

        if temp and temp < gateThreshold then
            -- Check if colonist has clothing cold protection
            local protected = false
            if tokC and Clothing.getProtection then
                local prot = Clothing.getProtection(id)
                if prot then
                    -- 40+ cold rating provides enough protection to survive
                    protected = (prot.cold or 0) >= 40
                end
            end

            if not protected then
                -- Apply cold damage
                local dmg = COLD_DAMAGE_RATE * COLD_CHECK_INTERVAL
                col.health = math.max(0, (col.health or col.maxHealth) - dmg)

                -- Accelerate hypothermia
                local needs = comps.needs
                if needs and needs.warmth then
                    needs.warmth = math.max(0, needs.warmth - 8)
                end

                -- Log event
                local ciOk, CI = pcall(require, 'src.ui.colonist_info')
                if ciOk and CI.logEvent then
                    CI.logEvent(id, 'Suffering from extreme cold exposure')
                end
            end
        end

        ::nextCol::
    end
end

---------------------------------------------------------------------------
-- Battery heat exchange
-- Thermal batteries in rooms absorb excess heat when room is warm
-- and release stored heat when room gets cold. This buffers against
-- temperature swings (blizzards, reactor shutdowns).
---------------------------------------------------------------------------

local batteryExchangeTimer = 0
local BATTERY_EXCHANGE_INTERVAL = 1.0  -- every second

local function batteryHeatExchange(dt)
    batteryExchangeTimer = batteryExchangeTimer + dt
    if batteryExchangeTimer < BATTERY_EXCHANGE_INTERVAL then return end
    batteryExchangeTimer = 0

    local tokT, Thermal = pcall(require, 'src.sim.thermal')
    if not tokT then return end

    local rooms = Thermal.getRooms()
    if not rooms then return end

    for id, comps in ECS.query('battery', 'pos') do
        local bat = comps.battery
        if not bat or not bat.capacity then goto nextBat end

        -- Only thermal batteries participate in heat exchange
        -- (identified by high capacity + low charge efficiency = molten salt)
        if bat.chargeEff and bat.chargeEff > 0.5 then goto nextBat end

        local pos = comps.pos
        local temp = Thermal.getTileTemp(pos.x, pos.y)
        if not temp then goto nextBat end

        local stored = bat.stored or 0
        local capacity = bat.capacity or 3000

        if temp > BATTERY_TARGET_TEMP + BATTERY_ABSORB_THRESHOLD then
            -- Room is hot: absorb excess heat into battery
            local excess = temp - BATTERY_TARGET_TEMP
            local absorb = excess * BATTERY_HEAT_ABSORB * BATTERY_EXCHANGE_INTERVAL
            local space = capacity - stored
            if space > 0 then
                local actual = math.min(absorb * capacity * 0.01, space)
                bat.stored = stored + actual
            end

        elseif temp < BATTERY_TARGET_TEMP - BATTERY_RELEASE_THRESHOLD then
            -- Room is cold: release stored heat
            if stored > 0 then
                local deficit = BATTERY_TARGET_TEMP - temp
                local release = deficit * BATTERY_HEAT_RELEASE * BATTERY_EXCHANGE_INTERVAL
                local actual = math.min(release * capacity * 0.01, stored)
                bat.stored = stored - actual

                -- Push heat into the room via heat source system
                local heatWatts = actual * 0.1  -- convert stored energy to warmth push
                Thermal.addHeatSource(pos.x, pos.y, heatWatts, pos.depth or 0)

                -- Remove the temporary heat boost next tick
                -- (battery heat is a pulse, not permanent source)
                bat._pendingHeatRemoval = { x = pos.x, y = pos.y, watts = heatWatts, depth = pos.depth or 0 }
            end
        end

        -- Clean up previous tick's temporary heat source
        if bat._lastHeatRemoval then
            local r = bat._lastHeatRemoval
            Thermal.removeHeatSource(r.x, r.y, r.watts, r.depth)
            bat._lastHeatRemoval = nil
        end
        if bat._pendingHeatRemoval then
            bat._lastHeatRemoval = bat._pendingHeatRemoval
            bat._pendingHeatRemoval = nil
        end

        ::nextBat::
    end
end

---------------------------------------------------------------------------
-- Deep cold zone resource deposits
-- Spawns rare resource tiles in extremely cold map regions during mapgen.
-- Called once from map generation (not every tick).
---------------------------------------------------------------------------

function ThermalDeepening.seedDeepColdResources(tilemap)
    local tokT, Tiles = pcall(require, 'src.world.tiles')
    if not tokT then return end

    local w, h = tilemap.width(), tilemap.height()
    local tData = tilemap.rawTileData()
    local tempData = tilemap.rawTempData()

    local depositsPlaced = 0
    local maxDeposits = math.floor(w * h * 0.0005)  -- ~0.05% of map

    -- Scan for tiles in deep cold regions (edges and corners tend to be coldest)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if depositsPlaced >= maxDeposits then return depositsPlaced end

            local idx = y * w + x + 1
            local temp = tempData[idx]
            local tile = tData[idx]

            -- Only place on walkable ground tiles in deep cold zones
            if temp and temp < getHeatGateThreshold()
               and not Tiles.isSolid(tile)
               and tile ~= Tiles.LAVA_VENT then
                -- 3% chance per eligible tile
                if math.random() < 0.03 then
                    -- Place ore vein (thermal alloy source)
                    tData[idx] = Tiles.ORE_VEIN
                    depositsPlaced = depositsPlaced + 1
                end
            end
        end
    end

    return depositsPlaced
end

---------------------------------------------------------------------------
-- Faction thermal core valuation
-- Each faction has a different multiplier for thermal core trade value.
---------------------------------------------------------------------------

local CORE_VALUATION = {
    mammona_logistics  = 1.2,  -- standard corporate value
    mastema_ops        = 1.5,  -- black ops prize them for weapon research
    scavenger_crews    = 0.8,  -- limited use for low-tech groups
    ruin_delvers       = 1.8,  -- core expertise, highest value
    rim_runners        = 1.0,  -- neutral market rate
    black_maw          = 1.3,  -- pirates know what cores are worth
    void_serpents      = 1.4,  -- intel on core sources
    rust_reavers       = 0.9,  -- prefer raw materials over cores
    zenith_syndicate   = 1.6,  -- fence stolen cores at premium
    solar_nomads       = 1.1,  -- modest valuation
    sons_of_pale_moon  = 2.0,  -- cores have religious significance
}

function ThermalDeepening.getCoreValuation(factionId)
    return CORE_VALUATION[factionId] or 1.0
end

function ThermalDeepening.getCoreTradeMult(factionId)
    local base = CORE_VALUATION[factionId] or 1.0
    local fok, Factions = pcall(require, 'src.colony.factions')
    if fok then
        local tradeMult = Factions.getTradeMult(factionId)
        return base * tradeMult
    end
    return base
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function ThermalDeepening.getHeatGateThreshold()
    return getHeatGateThreshold()
end

function ThermalDeepening.isTileHeatGated(x, y)
    local tokT, Thermal = pcall(require, 'src.sim.thermal')
    if not tokT then return false end
    local temp = Thermal.getTileTemp(x, y)
    return temp and temp < getHeatGateThreshold()
end

function ThermalDeepening.getBatteryHeatLevel(entityId)
    local bat = ECS.get(entityId, 'battery')
    if not bat then return 0, 0 end
    return bat.stored or 0, bat.capacity or 0
end

---------------------------------------------------------------------------
-- Step (called from main loop)
---------------------------------------------------------------------------

function ThermalDeepening.step(dt)
    checkHeatGatedDamage(dt)
    batteryHeatExchange(dt)
end

---------------------------------------------------------------------------
-- Serialization (stateless — all state lives in ECS battery components)
---------------------------------------------------------------------------

function ThermalDeepening.getState()
    return {
        coldCheckTimer = coldCheckTimer,
        batteryExchangeTimer = batteryExchangeTimer,
    }
end

function ThermalDeepening.restoreState(state)
    if not state then return end
    coldCheckTimer = state.coldCheckTimer or 0
    batteryExchangeTimer = state.batteryExchangeTimer or 0

    -- Clear stale battery heat removal refs (they reference pre-save Thermal state)
    local eok, ECSMod = pcall(require, 'src.ecs.ecs')
    if eok then
        for _, comps in ECSMod.query('battery') do
            local bat = comps.battery
            if bat then
                bat._pendingHeatRemoval = nil
                bat._lastHeatRemoval = nil
            end
        end
    end
end

return ThermalDeepening
