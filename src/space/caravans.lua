-- caravans.lua — Mobile trade convoys in space
-- Move between stations on procedural routes. Hailable via comms.
-- Can be raided (reputation consequences). Sometimes under pirate attack.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Caravans = {}

---------------------------------------------------------------------------
-- Caravan definitions
---------------------------------------------------------------------------

local CARAVAN_TYPES = {
    gustograin_hauler = {
        name = 'GustoGrain Supply Hauler',
        faction = 'mammona',
        cargo = {
            { itemId = 'food', amount = 50, price = 2 },
            { itemId = 'ration', amount = 30, price = 3 },
            { itemId = 'water', amount = 40, price = 1 },
        },
        speed = 1,
        hullHP = 60,
    },
    omnicorp_freighter = {
        name = 'OmniCorp Freight Runner',
        faction = 'utc',
        cargo = {
            { itemId = 'steel', amount = 40, price = 5 },
            { itemId = 'components', amount = 20, price = 8 },
            { itemId = 'fuel', amount = 60, price = 3 },
        },
        speed = 1,
        hullHP = 80,
    },
    independent_trader = {
        name = 'Independent Trader',
        faction = 'independent',
        cargo = {
            { itemId = 'medicine', amount = 15, price = 10 },
            { itemId = 'circuit', amount = 10, price = 12 },
            { itemId = 'insulation', amount = 25, price = 4 },
        },
        speed = 2,
        hullHP = 40,
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local activeCaravans = {}  -- { [entityId] = { typeId, routeIndex, waypoints, underAttack } }
local spawnTimer = 0
local SPAWN_INTERVAL = 60  -- seconds between caravan spawns
local MAX_CARAVANS = 3

---------------------------------------------------------------------------
-- Route generation
---------------------------------------------------------------------------

local function generateRoute()
    -- Pick 2-4 random POI positions as waypoints
    local waypoints = {}
    local pois = GameState.discoveredPOIs or {}
    local candidates = {}
    for _, poi in pairs(pois) do
        if poi.type ~= 'derelict' and poi.type ~= 'planet_orbit' then
            candidates[#candidates + 1] = { x = poi.x, y = poi.y }
        end
    end

    if #candidates < 2 then
        -- Fallback: random positions
        for i = 1, 3 do
            waypoints[i] = { x = math.random(-1000, 1000), y = math.random(-1000, 1000) }
        end
    else
        local count = math.min(#candidates, math.random(2, 4))
        local used = {}
        for i = 1, count do
            local idx
            repeat
                idx = math.random(#candidates)
            until not used[idx]
            used[idx] = true
            waypoints[i] = candidates[idx]
        end
    end

    return waypoints
end

---------------------------------------------------------------------------
-- Spawn
---------------------------------------------------------------------------

function Caravans.spawnCaravan()
    if GameState.activeMap ~= 'space' then return end

    local count = 0
    for _ in pairs(activeCaravans) do count = count + 1 end
    if count >= MAX_CARAVANS then return end

    -- Pick random type
    local typeKeys = {}
    for k in pairs(CARAVAN_TYPES) do typeKeys[#typeKeys + 1] = k end
    local typeId = typeKeys[math.random(#typeKeys)]
    local def = CARAVAN_TYPES[typeId]

    local waypoints = generateRoute()
    if #waypoints == 0 then return end

    -- Spawn at first waypoint
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = waypoints[1].x, y = waypoints[1].y })
    ECS.set(id, 'ship', {
        shipId = id,
        tier = 'npc',
        velocity = 0,
        heading = 0,
        fuel = 500,
        hullHP = def.hullHP,
    })
    ECS.set(id, 'npc_ship', {
        factionId = def.faction,
        behavior = 'trade_route',
        hostility = 'friendly',
        templateId = 'caravan',
        name = def.name,
        aiState = 'trade_route',
        targetId = nil,
        speed = def.speed,
        detectionRange = 6,
        weaponCount = 0,
        cargo = true,
    })

    activeCaravans[id] = {
        typeId = typeId,
        routeIndex = 1,
        waypoints = waypoints,
        underAttack = false,
        cargo = {},
    }

    -- Copy cargo
    for _, item in ipairs(def.cargo) do
        activeCaravans[id].cargo[#activeCaravans[id].cargo + 1] = {
            itemId = item.itemId,
            amount = item.amount,
            price = item.price,
        }
    end
end

---------------------------------------------------------------------------
-- Step (move caravans along routes)
---------------------------------------------------------------------------

function Caravans.step(dt)
    if GameState.activeMap ~= 'space' then return end

    -- Spawn timer
    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnTimer = SPAWN_INTERVAL
        Caravans.spawnCaravan()
    end

    -- Move active caravans
    for entityId, caravan in pairs(activeCaravans) do
        if not ECS.isAlive(entityId) then
            activeCaravans[entityId] = nil
        else
            local pos = ECS.get(entityId, 'pos')
            local ship = ECS.get(entityId, 'ship')
            if pos and ship and caravan.waypoints then
                local wp = caravan.waypoints[caravan.routeIndex]
                if wp then
                    local dx = wp.x - pos.x
                    local dy = wp.y - pos.y
                    local dist = math.sqrt(dx * dx + dy * dy)

                    if dist < 2 then
                        -- Arrived at waypoint, move to next
                        caravan.routeIndex = caravan.routeIndex + 1
                        if caravan.routeIndex > #caravan.waypoints then
                            -- Route complete, loop back
                            caravan.routeIndex = 1
                        end
                    else
                        ship.heading = math.atan2(dy, dx)
                        ship.velocity = (ECS.get(entityId, 'npc_ship') or {}).speed or 1
                        pos.x = pos.x + math.cos(ship.heading) * ship.velocity * dt
                        pos.y = pos.y + math.sin(ship.heading) * ship.velocity * dt
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Trade with caravan (called when player docks/hails)
---------------------------------------------------------------------------

function Caravans.getCaravanCargo(entityId)
    local caravan = activeCaravans[entityId]
    if not caravan then return nil end
    return caravan.cargo
end

function Caravans.buyFromCaravan(entityId, itemIndex, amount)
    local caravan = activeCaravans[entityId]
    if not caravan or not caravan.cargo then return false, 'No caravan' end

    local item = caravan.cargo[itemIndex]
    if not item then return false, 'Invalid item' end
    if item.amount < amount then return false, 'Not enough stock' end

    local totalCost = item.price * amount
    if GameState.credits < totalCost then return false, 'Not enough credits' end

    GameState.credits = GameState.credits - totalCost
    item.amount = item.amount - amount

    -- Add items to player (spawn as physical items near player ship)
    local iok, Items = pcall(require, 'src.world.items')
    if iok and Items.spawn then
        -- Find player ship position
        for pid, pcomps in ECS.query('ship', 'pos') do
            if not ECS.has(pid, 'npc_ship') then
                Items.spawn(math.floor(pcomps.pos.x), math.floor(pcomps.pos.y), item.itemId, amount)
                break
            end
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function Caravans.isCaravan(entityId)
    return activeCaravans[entityId] ~= nil
end

function Caravans.getActiveCount()
    local count = 0
    for _ in pairs(activeCaravans) do count = count + 1 end
    return count
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Caravans.getState()
    return {
        spawnTimer = spawnTimer,
        -- Note: active caravans are ECS entities and persist via entity serialization
        -- Route data stored here for restoration
        routes = activeCaravans,
    }
end

function Caravans.loadState(state)
    if not state then return end
    spawnTimer = state.spawnTimer or 0
    activeCaravans = state.routes or {}
end

return Caravans
