-- merchants.lua — NPC merchant caravan trading system
-- Storyteller triggers merchant visits. Merchants spawn at map edge, walk to
-- colony center, open a trade window for a fixed duration, then walk back
-- and despawn. All trades use thermal_cores as currency.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Pathfind  = require('src.util.pathfind')
local Hope      = require('src.colony.hope')
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

local Merchants = {}

-- Spend counter-based currency: drain networked storage first, then take the
-- shortfall from the GameState counter. SNet.withdraw returns what it took;
-- ignoring that return made purchases free when currency sat in the counter.
local function spendCurrency(currency, amount)
    if amount <= 0 then return end
    local taken = 0
    local SNet = getStorageNet()
    if SNet then
        taken = SNet.withdraw(currency, amount, GameState.startX, GameState.startY) or 0
    end
    if taken < amount then
        GameState.spendResource(currency, amount - taken)
    end
end

-- Refund goes straight back to the counter: addResource would apply the
-- scarcity multiplier, and the currency name is not a spawnable item id.
local function refundCurrency(currency, amount)
    if amount <= 0 then return end
    GameState.resources[currency] = (GameState.resources[currency] or 0) + amount
end

---------------------------------------------------------------------------
-- Merchant type definitions
---------------------------------------------------------------------------

local MERCHANT_TYPES = {
    scavenger = {
        name = 'Scavenger Caravan',
        factionId = 'scavenger_crews',
        inventory = {
            { item = 'wood',  min = 15, max = 40, buyPrice = 2, sellPrice = 1 },
            { item = 'stone', min = 10, max = 30, buyPrice = 2, sellPrice = 1 },
            { item = 'food',  min = 10, max = 25, buyPrice = 3, sellPrice = 1 },
            { item = 'hide',  min = 3,  max = 8,  buyPrice = 4, sellPrice = 2 },
        },
        currency     = 'thermalCores',
        stayDuration = 120,
        minWealth    = 0,
    },
    equipment = {
        name = 'Equipment Trader',
        factionId = 'mastema_ops',
        inventory = {
            { item = 'metal',      min = 5,  max = 15, buyPrice = 5, sellPrice = 2 },
            { item = 'components', min = 2,  max = 6,  buyPrice = 8, sellPrice = 3 },
            { item = 'fuel',       min = 5,  max = 15, buyPrice = 3, sellPrice = 1 },
        },
        currency     = 'thermalCores',
        stayDuration = 120,
        minWealth    = 500,
    },
    exotic = {
        name = 'Rim Runner Trader',
        factionId = 'rim_runners',
        inventory = {
            { item = 'components',   min = 3,  max = 8,  buyPrice = 6,  sellPrice = 3 },
            { item = 'circuit',      min = 1,  max = 3,  buyPrice = 15, sellPrice = 5 },
            { item = 'thermalCores', min = 5,  max = 15, buyPrice = 0,  sellPrice = 0 },
            { item = 'fuel',         min = 8,  max = 20, buyPrice = 4,  sellPrice = 2 },
            { item = 'prisoner',     min = 1,  max = 2,  buyPrice = 25, sellPrice = 0 },
        },
        currency     = 'thermalCores',
        stayDuration = 90,
        minWealth    = 1000,
    },
    pirate = {
        name = 'Black Maw Fence',
        factionId = 'black_maw',
        inventory = {
            { item = 'fuel',         min = 10, max = 30, buyPrice = 2,  sellPrice = 1 },
            { item = 'metal',        min = 8,  max = 20, buyPrice = 4,  sellPrice = 2 },
            { item = 'steel',        min = 3,  max = 10, buyPrice = 7,  sellPrice = 3 },
            { item = 'prisoner',     min = 1,  max = 3,  buyPrice = 20, sellPrice = 0 },
        },
        currency     = 'thermalCores',
        stayDuration = 80,
        minWealth    = 800,
    },
    intelligence = {
        name = 'Void Serpent Broker',
        factionId = 'void_serpents',
        inventory = {
            { item = 'components',   min = 4,  max = 10, buyPrice = 5,  sellPrice = 2 },
            { item = 'circuit',      min = 2,  max = 5,  buyPrice = 12, sellPrice = 4 },
        },
        currency     = 'thermalCores',
        stayDuration = 60,
        minWealth    = 1200,
    },
    salvager = {
        name = 'Rust Reaver Scrapper',
        factionId = 'rust_reavers',
        inventory = {
            { item = 'metal',        min = 10, max = 25, buyPrice = 3,  sellPrice = 1 },
            { item = 'components',   min = 3,  max = 8,  buyPrice = 6,  sellPrice = 2 },
            { item = 'steel',        min = 5,  max = 12, buyPrice = 5,  sellPrice = 2 },
        },
        currency     = 'thermalCores',
        stayDuration = 100,
        minWealth    = 600,
    },
    syndicate = {
        name = 'Zenith Syndicate Runner',
        factionId = 'zenith_syndicate',
        inventory = {
            { item = 'food',         min = 10, max = 30, buyPrice = 2,  sellPrice = 1 },
            { item = 'fuel',         min = 8,  max = 20, buyPrice = 3,  sellPrice = 1 },
            { item = 'prisoner',     min = 1,  max = 2,  buyPrice = 18, sellPrice = 0 },
        },
        currency     = 'thermalCores',
        stayDuration = 70,
        minWealth    = 500,
    },
    nomad = {
        name = 'Solar Nomad Trader',
        factionId = 'solar_nomads',
        inventory = {
            { item = 'food',  min = 12, max = 35, buyPrice = 2, sellPrice = 1 },
            { item = 'hide',  min = 5,  max = 15, buyPrice = 3, sellPrice = 1 },
            { item = 'fuel',  min = 5,  max = 15, buyPrice = 3, sellPrice = 1 },
        },
        currency     = 'thermalCores',
        stayDuration = 90,
        minWealth    = 300,
    },
    cultist = {
        name = 'Pale Moon Pilgrim',
        factionId = 'sons_of_pale_moon',
        inventory = {
            { item = 'thermalCores', min = 3,  max = 8,  buyPrice = 0,  sellPrice = 0 },
            { item = 'components',   min = 2,  max = 5,  buyPrice = 8,  sellPrice = 3 },
        },
        currency     = 'thermalCores',
        stayDuration = 60,
        minWealth    = 1500,
    },
}

Merchants.MERCHANT_TYPES = MERCHANT_TYPES

---------------------------------------------------------------------------
-- Resource value table (for colony wealth calculation)
---------------------------------------------------------------------------

local RESOURCE_VALUES = {
    thermalCores = 10,
    wood         = 1,
    stone        = 1,
    metal        = 3,
    food         = 2,
    fuel         = 2,
    components   = 5,
    hide         = 2,
    circuit      = 8,
}

---------------------------------------------------------------------------
-- Module state
---------------------------------------------------------------------------

local activeMerchant = nil  -- entity ID of the current merchant, or nil
local tradeCompleted = false -- whether any trade happened during this visit
local log = {}
local MAX_LOG = 12

-- Supply/demand price pressure (persists across merchant visits)
-- Positive pressure = colony is buying a lot = price goes up
-- Negative pressure = colony is selling a lot = price goes down
local pricePressure = {}  -- { [itemName] = float, ... }
local PRESSURE_DECAY = 0.95      -- decay per merchant visit (5% drift to baseline)
local PRESSURE_BUY_STEP = 0.03   -- price increase per unit bought
local PRESSURE_SELL_STEP = 0.02  -- price decrease per unit sold
local MAX_PRESSURE = 0.5         -- cap: prices can shift +/-50%

local function logMsg(msg)
    log[#log + 1] = {
        msg  = msg,
        day  = GameState.day,
        hour = GameState.hour,
    }
    while #log > MAX_LOG do
        table.remove(log, 1)
    end
end

---------------------------------------------------------------------------
-- Colony wealth
---------------------------------------------------------------------------

local function getColonyWealth()
    local wealth = 0
    for res, amount in pairs(GameState.resources) do
        wealth = wealth + (amount * (RESOURCE_VALUES[res] or 1))
    end
    return wealth
end

Merchants.getColonyWealth = getColonyWealth

---------------------------------------------------------------------------
-- Negotiator bonus — best cooking skill among colonists, +/-1.5% per level
---------------------------------------------------------------------------

local function getNegotiatorBonus()
    local bestCooking = 0
    for _, comps in ECS.query('colonist') do
        local col = comps.colonist
        if col.skills and col.skills.cooking then
            if col.skills.cooking > bestCooking then
                bestCooking = col.skills.cooking
            end
        end
    end
    return bestCooking * 0.015
end

---------------------------------------------------------------------------
-- Generate merchant inventory from type definition
---------------------------------------------------------------------------

local function rollInventory(typeDef)
    local inv = {}
    for _, slot in ipairs(typeDef.inventory) do
        local qty = math.random(slot.min, slot.max)
        inv[#inv + 1] = {
            item      = slot.item,
            stock     = qty,
            buyPrice  = slot.buyPrice,
            sellPrice = slot.sellPrice,
        }
    end
    return inv
end

---------------------------------------------------------------------------
-- Pick a spawn position on the map edge
---------------------------------------------------------------------------

local function pickEdgePosition()
    local World = require('src.world.tilemap')
    local w = World.width()
    local h = World.height()
    local side = math.random(4)
    local x, y

    if side == 1 then       -- north
        x = math.random(5, w - 5); y = 2
    elseif side == 2 then   -- south
        x = math.random(5, w - 5); y = h - 3
    elseif side == 3 then   -- west
        x = 2; y = math.random(5, h - 5)
    else                     -- east
        x = w - 3; y = math.random(5, h - 5)
    end

    -- Find a walkable tile near the chosen spot
    if not World.isWalkable(x, y, 0) then
        for dx = -2, 2 do
            for dy = -2, 2 do
                if World.isWalkable(x + dx, y + dy, 0) then
                    return x + dx, y + dy
                end
            end
        end
    end
    return x, y
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Merchants.init()
    activeMerchant = nil
    tradeCompleted = false
    log = {}
end

---------------------------------------------------------------------------
-- Spawn a merchant
---------------------------------------------------------------------------

local ARRIVAL_DIST = 5  -- tiles from colony center to count as "arrived"

function Merchants.spawnTrader(merchantType)
    -- Only one merchant at a time
    if activeMerchant and ECS.isAlive(activeMerchant) then
        return nil, 'A merchant is already visiting'
    end

    local typeDef = MERCHANT_TYPES[merchantType]
    if not typeDef then
        return nil, 'Unknown merchant type: ' .. tostring(merchantType)
    end

    -- Wealth gate
    local wealth = getColonyWealth()
    if wealth < typeDef.minWealth then
        return nil, 'Colony wealth too low for this merchant type'
    end

    local sx, sy = pickEdgePosition()

    local id = ECS.spawn()

    ECS.set(id, 'pos', {
        x = sx, y = sy,
        prevX = sx, prevY = sy,
        targetX = nil, targetY = nil,
    })

    ECS.set(id, 'merchant', {
        type       = merchantType,
        typeDef    = typeDef,
        inventory  = rollInventory(typeDef),
        arrived    = false,
        stayTimer  = typeDef.stayDuration,
        departing  = false,
        spawnX     = sx,
        spawnY     = sy,
    })

    ECS.set(id, 'path', {
        nodes     = nil,
        index     = 1,
        moveTimer = 0,
    })

    activeMerchant = id
    tradeCompleted = false

    -- Hope boost on arrival
    Hope.applyDelta(3, -1)
    logMsg(typeDef.name .. ' spotted approaching the colony!')

    return id
end

---------------------------------------------------------------------------
-- Movement helpers
---------------------------------------------------------------------------

local MERCHANT_SPEED = 2.5  -- tiles per second

local function pathTo(id, tx, ty)
    local World = require('src.world.tilemap')
    local pos = ECS.get(id, 'pos')
    if not pos then return end
    local nodes = Pathfind.find(pos.x, pos.y, tx, ty, World, id)
    local path = ECS.get(id, 'path')
    if path then
        path.nodes     = nodes
        path.index     = 1
        path.moveTimer = 0
    end
end

local function isNear(pos, tx, ty, dist)
    local dx = pos.x - tx
    local dy = pos.y - ty
    return (dx * dx + dy * dy) <= dist * dist
end

---------------------------------------------------------------------------
-- ECS system: merchant movement and lifecycle
---------------------------------------------------------------------------

local function merchantSystem(dt, id, comps)
    local pos  = comps.pos
    local merc = comps.merchant
    local path = comps.path

    -- Store previous position for interpolation
    pos.prevX = pos.x
    pos.prevY = pos.y

    -- Walk along path
    if path.nodes and path.index <= #path.nodes then
        local World = require('src.world.tilemap')
        path.moveTimer = path.moveTimer + dt * MERCHANT_SPEED
        while path.moveTimer >= 1 and path.index <= #path.nodes do
            local node = path.nodes[path.index]
            path.moveTimer = path.moveTimer - 1
            if World.inBounds(node.x, node.y) then
                pos.x = node.x
                pos.y = node.y
            end
            path.index = path.index + 1
        end
        if path.index > #path.nodes then
            path.nodes = nil
            path.index = 1
        end
    end

    -- Phase: traveling to colony
    if not merc.arrived and not merc.departing then
        local centerX = GameState.startX
        local centerY = GameState.startY
        if isNear(pos, centerX, centerY, ARRIVAL_DIST) then
            merc.arrived = true
            logMsg(merc.typeDef.name .. ' has arrived and is ready to trade.')
        elseif not path.nodes then
            -- Need a path to colony center
            pathTo(id, centerX, centerY)
        end
        return
    end

    -- Phase: trading (countdown)
    if merc.arrived and not merc.departing then
        merc.stayTimer = merc.stayTimer - dt
        if merc.stayTimer <= 0 then
            merc.departing = true
            if tradeCompleted then
                Hope.applyDelta(2, 0)
            end
            logMsg(merc.typeDef.name .. ' is packing up and leaving.')
            pathTo(id, merc.spawnX, merc.spawnY)
        end
        return
    end

    -- Phase: departing
    if merc.departing then
        local World = require('src.world.tilemap')
        if isNear(pos, merc.spawnX, merc.spawnY, 3) then
            -- Reached map edge, despawn
            -- Decay price pressure toward baseline on merchant departure
            for item, p in pairs(pricePressure) do
                pricePressure[item] = p * PRESSURE_DECAY
                if math.abs(pricePressure[item]) < 0.005 then
                    pricePressure[item] = nil
                end
            end
            logMsg(merc.typeDef.name .. ' has left the area.')
            ECS.destroy(id)
            if activeMerchant == id then
                activeMerchant = nil
            end
        elseif not path.nodes then
            -- Re-path if stuck
            pathTo(id, merc.spawnX, merc.spawnY)
        end
    end
end

---------------------------------------------------------------------------
-- Trade execution
---------------------------------------------------------------------------

local function findMerchantSlot(merc, itemName)
    for _, slot in ipairs(merc.inventory) do
        if slot.item == itemName then
            return slot
        end
    end
    return nil
end

function Merchants.buyItem(itemName, quantity)
    if not activeMerchant or not ECS.isAlive(activeMerchant) then
        return false, 'No merchant available'
    end

    local merc = ECS.get(activeMerchant, 'merchant')
    if not merc or not merc.arrived or merc.departing then
        return false, 'Merchant is not ready to trade'
    end

    local slot = findMerchantSlot(merc, itemName)
    if not slot then
        return false, 'Merchant does not sell ' .. tostring(itemName)
    end

    if slot.buyPrice <= 0 then
        return false, tostring(itemName) .. ' is not for sale'
    end

    quantity = math.min(quantity, slot.stock)
    if quantity <= 0 then
        return false, 'Merchant is out of stock for ' .. tostring(itemName)
    end

    -- Apply negotiator discount + faction trade modifier + supply/demand pressure
    local bonus = getNegotiatorBonus()
    local factionMult = 1.0
    local fok, Factions = pcall(require, 'src.colony.factions')
    if fok and merc.typeDef.factionId then
        factionMult = Factions.getTradeMult(merc.typeDef.factionId)
    end
    local pressure = pricePressure[itemName] or 0
    local pressureMult = 1 + math.max(-MAX_PRESSURE, math.min(MAX_PRESSURE, pressure))
    local pricePerUnit = math.max(1, math.floor(slot.buyPrice * (1 - bonus) * factionMult * pressureMult + 0.5))
    local totalCost = pricePerUnit * quantity

    -- Check currency
    local currency = merc.typeDef.currency
    if (GameState.resources[currency] or 0) < totalCost then
        -- Buy as many as we can afford
        quantity = math.floor((GameState.resources[currency] or 0) / pricePerUnit)
        if quantity <= 0 then
            return false, 'Not enough ' .. currency
        end
        totalCost = pricePerUnit * quantity
    end

    -- Human purchases spawn entities instead of adding a resource entry.
    if itemName == 'prisoner' or itemName == 'slave' or itemName == 'colonist' then
        local rok, Recruitment = pcall(require, 'src.colonist.recruitment')
        if not rok then
            return false, 'Recruitment system unavailable'
        end

        spendCurrency(currency, totalCost)

        local spawned = 0
        for i = 1, quantity do
            local ok, err
            if itemName == 'colonist' then
                ok, err = Recruitment.buyColonist(0, merc.typeDef.factionId)
            else
                ok, err = Recruitment.buyPrisoner(0, merc.typeDef.factionId)
            end
            if ok then
                spawned = spawned + 1
            else
                local refund = pricePerUnit * (quantity - spawned)
                refundCurrency(currency, refund)
                if spawned == 0 then
                    return false, err or 'Purchase failed'
                end
                quantity = spawned
                totalCost = pricePerUnit * quantity
                break
            end
        end
    else
        -- Execute
        spendCurrency(currency, totalCost)
        local Items = getItems()
        if Items then Items.spawn(GameState.startX, GameState.startY, itemName, quantity, nil, 0)
        else GameState.addResource(itemName, quantity) end
    end
    slot.stock = slot.stock - quantity
    tradeCompleted = true

    -- Supply/demand: buying increases price pressure
    pricePressure[itemName] = (pricePressure[itemName] or 0) + quantity * PRESSURE_BUY_STEP

    -- Notify faction system of trade
    if fok and merc.typeDef.factionId then
        Factions.onTradeCompleted(merc.typeDef.factionId)
    end

    logMsg(string.format('Bought %d %s for %d %s.', quantity, itemName, totalCost, currency))
    return true, quantity, totalCost
end

function Merchants.sellItem(itemName, quantity)
    if not activeMerchant or not ECS.isAlive(activeMerchant) then
        return false, 'No merchant available'
    end

    local merc = ECS.get(activeMerchant, 'merchant')
    if not merc or not merc.arrived or merc.departing then
        return false, 'Merchant is not ready to trade'
    end

    -- Find the slot to get sell price (merchant must deal in this item)
    local slot = findMerchantSlot(merc, itemName)
    if not slot then
        return false, 'Merchant does not buy ' .. tostring(itemName)
    end

    if slot.sellPrice <= 0 then
        return false, 'Merchant will not buy ' .. tostring(itemName)
    end

    -- Check player inventory
    local available = GameState.resources[itemName] or 0
    quantity = math.min(quantity, available)
    if quantity <= 0 then
        return false, 'You have no ' .. tostring(itemName) .. ' to sell'
    end

    -- Apply negotiator bonus (better sale price) + faction trade modifier + supply/demand pressure
    local bonus = getNegotiatorBonus()
    local factionMult = 1.0
    local fok, Factions = pcall(require, 'src.colony.factions')
    if fok and merc.typeDef.factionId then
        factionMult = Factions.getTradeMult(merc.typeDef.factionId)
    end
    local pressure = pricePressure[itemName] or 0
    -- Selling pushes prices down (inverse of buy pressure on sell side)
    local pressureMult = 1 + math.max(-MAX_PRESSURE, math.min(MAX_PRESSURE, -pressure))
    local pricePerUnit = math.max(1, math.floor(slot.sellPrice * (1 + bonus) * factionMult * pressureMult + 0.5))
    local totalEarned = pricePerUnit * quantity

    -- Execute
    local SNet2 = getStorageNet()
    if SNet2 then SNet2.withdraw(itemName, quantity, GameState.startX, GameState.startY)
    else GameState.spendResource(itemName, quantity) end
    local currency = merc.typeDef.currency
    local Items2 = getItems()
    if Items2 then Items2.spawn(GameState.startX, GameState.startY, currency, totalEarned, nil, 0)
    else GameState.addResource(currency, totalEarned) end
    tradeCompleted = true

    -- Supply/demand: selling decreases price pressure
    pricePressure[itemName] = (pricePressure[itemName] or 0) - quantity * PRESSURE_SELL_STEP

    logMsg(string.format('Sold %d %s for %d %s.', quantity, itemName, totalEarned, currency))
    return true, quantity, totalEarned
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Merchants.getActiveMerchant()
    if not activeMerchant or not ECS.isAlive(activeMerchant) then
        activeMerchant = nil
        return nil
    end
    local merc = ECS.get(activeMerchant, 'merchant')
    local pos  = ECS.get(activeMerchant, 'pos')
    if not merc then return nil end
    return {
        id        = activeMerchant,
        type      = merc.type,
        name      = merc.typeDef.name,
        inventory = merc.inventory,
        arrived   = merc.arrived,
        departing = merc.departing,
        stayTimer = merc.stayTimer,
        currency  = merc.typeDef.currency,
        pos       = pos,
    }
end

function Merchants.isTrading()
    if not activeMerchant or not ECS.isAlive(activeMerchant) then
        return false
    end
    local merc = ECS.get(activeMerchant, 'merchant')
    return merc and merc.arrived and not merc.departing
end

function Merchants.getLog()
    return log
end

function Merchants.getPricePressure(itemName)
    if itemName then return pricePressure[itemName] or 0 end
    return pricePressure
end

function Merchants.getState()
    return {
        pricePressure = pricePressure,
        activeMerchant = activeMerchant,
        log = log,
    }
end

function Merchants.restoreState(s)
    if not s then return end
    pricePressure = s.pricePressure or {}
    log = s.log or {}
    -- Restore active merchant reference if entity still exists
    if s.activeMerchant and ECS.isAlive(s.activeMerchant) then
        activeMerchant = s.activeMerchant
    else
        activeMerchant = nil
    end
end

---------------------------------------------------------------------------
-- Merchant type selection (wealth-weighted for storyteller)
---------------------------------------------------------------------------

function Merchants.pickMerchantType()
    local wealth = getColonyWealth()
    local eligible = {}
    for typeId, def in pairs(MERCHANT_TYPES) do
        if wealth >= def.minWealth then
            eligible[#eligible + 1] = typeId
        end
    end
    if #eligible == 0 then
        return 'scavenger'
    end
    return eligible[math.random(#eligible)]
end

---------------------------------------------------------------------------
-- Step — called each sim tick
---------------------------------------------------------------------------

function Merchants.step(dt)
    -- The ECS system handles merchant entity ticking.
    -- This function exists for any non-ECS per-tick merchant logic.
    -- Currently a no-op; the merchantSystem does the work via ECS.update().
end

---------------------------------------------------------------------------
-- Register ECS systems
---------------------------------------------------------------------------

function Merchants.registerSystems()
    ECS.addSystem('merchant_lifecycle', { 'pos', 'merchant', 'path' }, merchantSystem, 50)
end

-- Auto-register on require
Merchants.registerSystems()

return Merchants
