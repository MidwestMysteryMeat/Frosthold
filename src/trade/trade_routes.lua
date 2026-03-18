-- trade_routes.lua — Permanent trade routes with allied factions
-- Establish a route with an allied faction to receive regular shipments.
-- Routes require fuel maintenance and can be disrupted by raids.

local GameState = require('src.game_state')
local _Items
local function getItems()
    if _Items == nil then
        local ok, mod = pcall(require, 'src.world.items')
        _Items = ok and mod or false
    end
    return _Items or nil
end
local _StorageNet
local function getStorageNet()
    if _StorageNet == nil then
        local ok, mod = pcall(require, 'src.logistics.storage_network')
        _StorageNet = ok and mod or false
    end
    return _StorageNet or nil
end

local TradeRoutes = {}

---------------------------------------------------------------------------
-- Route definitions: what each faction ships via trade route
---------------------------------------------------------------------------

local ROUTE_DEFS = {
    mammona_logistics = {
        goods = {
            { item = 'fuel',         min = 8,  max = 20 },
            { item = 'thermalCores', min = 2,  max = 5 },
            { item = 'coal',         min = 10, max = 25 },
        },
        fuelCost = 5,       -- fuel per shipment
        interval = 3,       -- game-days between shipments
    },
    mastema_ops = {
        goods = {
            { item = 'metal',      min = 5,  max = 12 },
            { item = 'components', min = 2,  max = 5 },
            { item = 'steel',      min = 3,  max = 8 },
        },
        fuelCost = 8,
        interval = 4,
    },
    scavenger_crews = {
        goods = {
            { item = 'food',  min = 10, max = 25 },
            { item = 'wood',  min = 8,  max = 20 },
            { item = 'hide',  min = 3,  max = 8 },
        },
        fuelCost = 3,
        interval = 2,
    },
    ruin_delvers = {
        goods = {
            { item = 'thermalCores', min = 3,  max = 7 },
            { item = 'components',   min = 1,  max = 4 },
        },
        fuelCost = 10,
        interval = 5,
    },
    rim_runners = {
        goods = {
            { item = 'components', min = 3,  max = 6 },
            { item = 'circuit',    min = 1,  max = 3 },
            { item = 'fuel',       min = 5,  max = 12 },
        },
        fuelCost = 6,
        interval = 3,
    },
    black_maw = {
        goods = {
            { item = 'fuel',  min = 8,  max = 20 },
            { item = 'metal', min = 5,  max = 12 },
            { item = 'steel', min = 3,  max = 8 },
        },
        fuelCost = 8,
        interval = 4,
    },
    void_serpents = {
        goods = {
            { item = 'components', min = 3,  max = 7 },
            { item = 'circuit',    min = 1,  max = 3 },
        },
        fuelCost = 7,
        interval = 4,
    },
    rust_reavers = {
        goods = {
            { item = 'metal',      min = 8,  max = 18 },
            { item = 'components', min = 2,  max = 5 },
        },
        fuelCost = 4,
        interval = 3,
    },
    zenith_syndicate = {
        goods = {
            { item = 'food', min = 8,  max = 20 },
            { item = 'fuel', min = 5,  max = 12 },
        },
        fuelCost = 6,
        interval = 3,
    },
    solar_nomads = {
        goods = {
            { item = 'food', min = 10, max = 25 },
            { item = 'hide', min = 3,  max = 8 },
        },
        fuelCost = 3,
        interval = 2,
    },
    sons_of_pale_moon = {
        goods = {
            { item = 'thermalCores', min = 2, max = 5 },
        },
        fuelCost = 10,
        interval = 6,
    },
}

TradeRoutes.ROUTE_DEFS = ROUTE_DEFS

---------------------------------------------------------------------------
-- Module state
---------------------------------------------------------------------------

local routes = {}      -- { [factionId] = route }
local log = {}
local MAX_LOG = 20

local function logMsg(msg)
    log[#log + 1] = {
        msg  = msg,
        day  = GameState.day,
        hour = GameState.hour,
    }
    while #log > MAX_LOG do table.remove(log, 1) end
end

---------------------------------------------------------------------------
-- Establish / cancel routes
---------------------------------------------------------------------------

function TradeRoutes.establish(factionId)
    local def = ROUTE_DEFS[factionId]
    if not def then return false, 'No trade route available for this faction' end

    -- Require allied standing
    local fOk, Factions = pcall(require, 'src.colony.factions')
    if not fOk then return false, 'Faction system unavailable' end
    if not Factions.isAllied(factionId) then
        return false, 'Must be allied with ' .. factionId .. ' to establish a trade route'
    end

    if routes[factionId] then
        return false, 'Trade route already established'
    end

    routes[factionId] = {
        factionId     = factionId,
        dayEstablished = GameState.day,
        lastShipment  = GameState.day,
        disrupted     = false,
        disruptedUntil = 0,
        totalShipments = 0,
    }

    logMsg('Trade route established with ' .. (Factions.FACTION_DEFS[factionId].name or factionId) .. '.')
    return true
end

function TradeRoutes.cancel(factionId)
    if not routes[factionId] then return false end
    routes[factionId] = nil

    local fOk, Factions = pcall(require, 'src.colony.factions')
    local name = factionId
    if fOk and Factions.FACTION_DEFS[factionId] then
        name = Factions.FACTION_DEFS[factionId].name
    end
    -- Canceling a route hurts reputation
    if fOk then Factions.modifyRep(factionId, -10) end
    logMsg('Trade route with ' .. name .. ' canceled.')
    return true
end

---------------------------------------------------------------------------
-- Disruption (called by raid system when raiders target a trade route)
---------------------------------------------------------------------------

function TradeRoutes.disrupt(factionId, durationDays)
    local route = routes[factionId]
    if not route then return false end
    route.disrupted = true
    route.disruptedUntil = GameState.day + (durationDays or 3)

    local fOk, Factions = pcall(require, 'src.colony.factions')
    local name = factionId
    if fOk and Factions.FACTION_DEFS[factionId] then
        name = Factions.FACTION_DEFS[factionId].name
    end
    logMsg('Trade route with ' .. name .. ' disrupted for ' .. (durationDays or 3) .. ' days.')
    return true
end

---------------------------------------------------------------------------
-- Step — process shipments on interval
---------------------------------------------------------------------------

function TradeRoutes.step(dt)
    local fOk, Factions = pcall(require, 'src.colony.factions')

    -- Collect routes to cancel (can't mutate table during pairs)
    local toCancel = {}

    for factionId, route in pairs(routes) do
        local def = ROUTE_DEFS[factionId]
        if not def then goto nextRoute end

        -- Auto-cancel if no longer allied
        if fOk and not Factions.isAllied(factionId) then
            local name = factionId
            if Factions.FACTION_DEFS[factionId] then
                name = Factions.FACTION_DEFS[factionId].name
            end
            logMsg('Trade route with ' .. name .. ' ended: no longer allied.')
            toCancel[#toCancel + 1] = factionId
            goto nextRoute
        end

        -- Clear disruption when time expires
        if route.disrupted and GameState.day >= route.disruptedUntil then
            route.disrupted = false
            route.disruptedUntil = 0
        end

        -- Skip if disrupted
        if route.disrupted then goto nextRoute end

        -- Check if shipment is due
        local daysSince = GameState.day - route.lastShipment
        if daysSince < def.interval then goto nextRoute end

        -- Check fuel cost
        local fuel = GameState.resources.fuel or 0
        if fuel < def.fuelCost then
            -- Not enough fuel: skip this shipment, don't advance timer
            goto nextRoute
        end

        -- Pay fuel and deliver goods
        local SNet = getStorageNet()
        if SNet then SNet.withdraw('fuel', def.fuelCost, GameState.startX, GameState.startY)
        else GameState.spendResource('fuel', def.fuelCost) end
        route.lastShipment = GameState.day
        route.totalShipments = route.totalShipments + 1

        local delivered = {}
        local Items = getItems()
        for _, g in ipairs(def.goods) do
            local qty = math.random(g.min, g.max)
            if Items then Items.spawn(GameState.startX, GameState.startY, g.item, qty, nil, 0)
            else GameState.addResource(g.item, qty) end
            delivered[#delivered + 1] = qty .. ' ' .. g.item
        end

        -- Small rep boost for each successful delivery
        if fOk then Factions.modifyRep(factionId, 1) end

        local name = factionId
        if fOk and Factions.FACTION_DEFS[factionId] then
            name = Factions.FACTION_DEFS[factionId].name
        end
        logMsg('Shipment from ' .. name .. ': ' .. table.concat(delivered, ', ') .. '.')

        ::nextRoute::
    end

    -- Apply deferred cancellations
    for _, fid in ipairs(toCancel) do
        routes[fid] = nil
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function TradeRoutes.getRoutes()
    local result = {}
    for factionId, route in pairs(routes) do
        local def = ROUTE_DEFS[factionId]
        result[#result + 1] = {
            factionId     = factionId,
            interval      = def and def.interval or 0,
            fuelCost      = def and def.fuelCost or 0,
            disrupted     = route.disrupted,
            disruptedUntil = route.disruptedUntil,
            lastShipment  = route.lastShipment,
            totalShipments = route.totalShipments,
            dayEstablished = route.dayEstablished,
        }
    end
    return result
end

function TradeRoutes.hasRoute(factionId)
    return routes[factionId] ~= nil
end

function TradeRoutes.getRoute(factionId)
    return routes[factionId]
end

function TradeRoutes.getLog()
    return log
end

-- Get all factions eligible for a new trade route (allied + not already established)
function TradeRoutes.getEligible()
    local fOk, Factions = pcall(require, 'src.colony.factions')
    if not fOk then return {} end

    local eligible = {}
    for factionId in pairs(ROUTE_DEFS) do
        if Factions.isAllied(factionId) and not routes[factionId] then
            local def = Factions.FACTION_DEFS[factionId]
            eligible[#eligible + 1] = {
                factionId = factionId,
                name      = def and def.name or factionId,
                interval  = ROUTE_DEFS[factionId].interval,
                fuelCost  = ROUTE_DEFS[factionId].fuelCost,
                goods     = ROUTE_DEFS[factionId].goods,
            }
        end
    end
    return eligible
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function TradeRoutes.getState()
    return {
        routes = routes,
        log    = log,
    }
end

function TradeRoutes.restoreState(state)
    if not state then return end
    routes = state.routes or {}
    log    = state.log or {}
end

return TradeRoutes
