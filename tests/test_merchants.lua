-- test_merchants.lua -- Merchant trading regression tests

local T = require('tests.test_framework')
local H = require('tests.helpers')

T.suite('Merchants')

local ECS       = require('src.ecs.ecs')
local World     = require('src.world.tilemap')
local GameState = require('src.game_state')
local Merchants = require('src.trade.merchants')

local function addBed(x, y, isPrisoner)
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, prevX = x, prevY = y, depth = 0 })
    ECS.set(id, 'bed', { owner = nil, comfort = 0.5, prisoner = isPrisoner or false })
    return id
end

local function prepTrader()
    H.resetAll()
    World.init(24, 24)
    GameState.startX = 12
    GameState.startY = 12
    GameState.resources.thermalCores = 200
    Merchants.init()

    local traderId, err = Merchants.spawnTrader('exotic')
    T.notnil(traderId, err)

    local merchant = ECS.get(traderId, 'merchant')
    merchant.arrived = true
    merchant.inventory = {
        { item = 'prisoner', stock = 1, buyPrice = 25, sellPrice = 0 },
    }

    return traderId, merchant
end

T.test('buying a prisoner spawns a prisoner instead of a colonist', function()
    prepTrader()
    addBed(12, 12, true)

    local beforePrisoners = ECS.countWith('prisoner')
    local beforeColonists = ECS.countWith('colonist')
    local beforeCores = GameState.resources.thermalCores

    local ok, qty, totalCost = Merchants.buyItem('prisoner', 1)
    T.eq(ok, true, 'purchase succeeds')
    T.eq(qty, 1, 'one prisoner purchased')
    T.eq(ECS.countWith('prisoner'), beforePrisoners + 1, 'prisoner entity added')
    T.eq(ECS.countWith('colonist'), beforeColonists, 'no colonist spawned')
    T.eq(GameState.resources.thermalCores, beforeCores - totalCost, 'currency spent once')
end)

T.test('prisoner purchase fails cleanly without a bed and refunds cost', function()
    prepTrader()

    local beforeCores = GameState.resources.thermalCores
    local ok, err = Merchants.buyItem('prisoner', 1)

    T.eq(ok, false, 'purchase rejected without a bed')
    T.eq(err, 'No available prisoner bed', 'clear error message')
    T.eq(ECS.countWith('prisoner'), 0, 'no prisoner spawned')
    T.eq(GameState.resources.thermalCores, beforeCores, 'currency refunded on failure')
end)
