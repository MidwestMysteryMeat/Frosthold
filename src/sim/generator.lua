-- generator.lua — Steam hub heat distribution system
-- Steam hubs are standalone powered buildings that provide heat in a radius.
-- Each hub produces fixed heat output with linear falloff when powered.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Power     = require('src.sim.power')
local Thermal   = require('src.sim.thermal')

local Generator = {}

-- Lazy-loaded modules
local _Lighting
local function lazyLoadGen()
    if _Lighting ~= nil then return end
    local ok
    ok, _Lighting = pcall(require, 'src.sim.lighting')
    if not ok then _Lighting = false end
end

---------------------------------------------------------------------------
-- Steam hub definitions
---------------------------------------------------------------------------

local HUB_RADIUS      = 6
local HUB_HEAT_OUTPUT = 50      -- fixed heat at center, linear falloff
local HUB_POWER_DRAW  = 20      -- watts consumed

local HUB_COST = {
    metal        = 8,
    components   = 3,
    thermal_core = 2,
}

local HUB_COST_MAP = {
    thermal_core = 'thermalCores',
}

local function mapHubCostKey(key)
    return HUB_COST_MAP[key] or key
end

---------------------------------------------------------------------------
-- Module state
---------------------------------------------------------------------------

local hubs = {}    -- { [entityId] = true }

Generator.HUB_COST       = HUB_COST
Generator.HUB_POWER_DRAW = HUB_POWER_DRAW

---------------------------------------------------------------------------
-- Init (called on new game / load)
---------------------------------------------------------------------------

function Generator.init()
    hubs = {}
end

---------------------------------------------------------------------------
-- Steam hub placement / removal
---------------------------------------------------------------------------

function Generator.placeHub(x, y)
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) then
        return nil, 'Out of bounds'
    end
    if not World.isWalkable(x, y, 0) then
        return nil, 'Blocked tile'
    end

    for res, amount in pairs(HUB_COST) do
        local resKey = mapHubCostKey(res)
        if (GameState.resources[resKey] or 0) < amount then
            return nil, 'Not enough ' .. res
        end
    end
    for res, amount in pairs(HUB_COST) do
        local resKey = mapHubCostKey(res)
        local snetOk, SNetG = pcall(require, 'src.logistics.storage_network')
        if snetOk and SNetG.withdraw then SNetG.withdraw(resKey, amount, x, y)
        else GameState.spendResource(resKey, amount) end
    end

    local id = ECS.spawn()

    ECS.set(id, 'pos', { x = x, y = y })

    ECS.set(id, 'steam_hub', {
        powered  = false,
        active   = false,
        _lastHeat = 0,
    })

    ECS.set(id, 'machine', {
        type     = 'steam_hub',
        name     = 'Steam Hub',
        powered  = false,
    })

    Power.addConsumer(id, HUB_POWER_DRAW, x, y)

    -- Register light source for the steam hub
    lazyLoadGen()
    if _Lighting then _Lighting.addLightCustom(x, y, 6, 0.7) end

    hubs[id] = true
    return id
end

function Generator.removeHub(hubId)
    if not hubs[hubId] then return end
    local hub = ECS.get(hubId, 'steam_hub')
    local pos = ECS.get(hubId, 'pos')
    if hub and hub._lastHeat > 0 and pos then
        Thermal.removeHeatSource(pos.x, pos.y, hub._lastHeat, pos.depth or 0)
    end
    -- Remove light source
    if pos then
        lazyLoadGen()
        if _Lighting then _Lighting.removeLight(pos.x, pos.y) end
    end
    Power.removeConsumer(hubId)
    ECS.destroy(hubId)
    hubs[hubId] = nil
end

---------------------------------------------------------------------------
-- Heat zone calculation
-- Returns the temperature bonus at (x, y) from all active steam hubs.
-- Max-wins when zones overlap.
---------------------------------------------------------------------------

function Generator.getHeatBonus(x, y)
    local bonus = 0

    for hubId in pairs(hubs) do
        if ECS.isAlive(hubId) then
            local hub = ECS.get(hubId, 'steam_hub')
            local pos = ECS.get(hubId, 'pos')
            if hub and hub.active and pos then
                local dx = x - pos.x
                local dy = y - pos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                local heat = HUB_HEAT_OUTPUT * math.max(0, 1 - dist / HUB_RADIUS)
                if heat > bonus then
                    bonus = heat
                end
            end
        end
    end

    return bonus
end

---------------------------------------------------------------------------
-- ECS system: steam hub tick
---------------------------------------------------------------------------

local function steamHubSystem(dt, id, comps)
    local hub     = comps.steam_hub
    local machine = comps.machine
    local pos     = comps.pos

    -- Power status comes from Power.step via the machine component
    hub.powered = machine and machine.powered or false

    local shouldBeActive = hub.powered

    if shouldBeActive and not hub.active then
        -- Turning on: register heat source
        Thermal.addHeatSource(pos.x, pos.y, HUB_HEAT_OUTPUT)
        hub._lastHeat = HUB_HEAT_OUTPUT
        hub.active = true
    elseif not shouldBeActive and hub.active then
        -- Turning off: remove heat source
        if hub._lastHeat > 0 then
            Thermal.removeHeatSource(pos.x, pos.y, hub._lastHeat, pos.depth or 0)
            hub._lastHeat = 0
        end
        hub.active = false
    end
end

---------------------------------------------------------------------------
-- Register ECS systems
---------------------------------------------------------------------------

function Generator.registerSystems()
    ECS.addSystem('steam_hub', { 'steam_hub', 'machine', 'pos' }, steamHubSystem, 11)
end

Generator.registerSystems()

---------------------------------------------------------------------------
-- Restore module-local state from ECS after save/load
---------------------------------------------------------------------------

function Generator.restoreFromECS()
    hubs = {}

    for id, comps in ECS.query('steam_hub', 'pos') do
        hubs[id] = true
        -- Re-register as power consumer
        Power.addConsumer(id, HUB_POWER_DRAW, comps.pos.x, comps.pos.y)
        -- Re-register heat source for active hubs
        local hub = comps.steam_hub
        if hub and hub.active and hub._lastHeat and hub._lastHeat > 0 then
            Thermal.addHeatSource(comps.pos.x, comps.pos.y, hub._lastHeat)
        end
        lazyLoadGen()
        if _Lighting then _Lighting.addLightCustom(comps.pos.x, comps.pos.y, 6, 0.7) end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Generator.getHubs()
    local result = {}
    for hubId in pairs(hubs) do
        if ECS.isAlive(hubId) then
            local hub = ECS.get(hubId, 'steam_hub')
            local pos = ECS.get(hubId, 'pos')
            result[#result + 1] = {
                id      = hubId,
                pos     = pos,
                powered = hub and hub.powered or false,
                active  = hub and hub.active or false,
            }
        end
    end
    return result
end

return Generator
