-- test_factions_gift.lua — gifting resources to a faction.
--
-- The reported symptom was "gift/trade don't seem to work". Two separate bugs
-- were behind it:
--   1. sendGift checked GameState.resources only. Goods are physical items now,
--      so thermalCores/metal/components sit at 0 in that counter and the button
--      answered "Not enough thermalCores" while a stockpile held plenty.
--   2. It then called StorageNetwork.withdraw and threw away the return value,
--      so a gift paid from the counter deducted nothing and bought free rep.

local T = require('tests.test_framework')

T.suite('Factions: gifting')

local GameState = require('src.game_state')
local Factions  = require('src.colony.factions')

local FACTION = 'mammona_logistics'   -- prefers fuel
local OTHER   = 'ruin_delvers'        -- prefers components, no corporate sibling

local function reset(resources)
    GameState.init()
    Factions.init()
    for name, amount in pairs(resources or {}) do
        GameState.resources[name] = amount
    end
end

---------------------------------------------------------------------------
-- Availability
---------------------------------------------------------------------------

T.test('getGiftableAmount reports the counter pool', function()
    reset({ fuel = 12 })
    T.eq(Factions.getGiftableAmount('fuel'), 12, 'counter total is visible')
end)

T.test('getGiftableAmount is zero for an unknown resource', function()
    reset({})
    T.eq(Factions.getGiftableAmount('unobtainium'), 0, 'unknown resource has none')
    T.eq(Factions.getGiftableAmount(nil), 0, 'nil resource has none')
end)

---------------------------------------------------------------------------
-- Deduction — the "free rep" half of the bug
---------------------------------------------------------------------------

T.test('a gift deducts the resource', function()
    reset({ fuel = 20 })
    local ok = Factions.sendGift(FACTION, 'fuel', 5)
    T.ok(ok, 'the gift went through')
    T.eq(GameState.resources.fuel, 15, 'five fuel actually left the colony')
end)

T.test('a gift raises reputation, doubled for the preferred resource', function()
    reset({ fuel = 20, metal = 20 })
    local before = Factions.getRep(OTHER)
    local ok, gain = Factions.sendGift(OTHER, 'metal', 5)
    T.ok(ok, 'non-preferred gift accepted')
    T.eq(gain, 2.5, 'base rate is half the amount')
    T.eq(Factions.getRep(OTHER), before + 2.5, 'reputation moved by the reported amount')

    reset({ components = 20 })
    local ok2, gain2 = Factions.sendGift(OTHER, 'components', 5)
    T.ok(ok2, 'preferred gift accepted')
    T.eq(gain2, 5, 'the preferred resource is worth double')
end)

T.test('repeated gifts accumulate reputation and drain the resource', function()
    reset({ fuel = 20 })
    for _ = 1, 4 do
        T.ok((Factions.sendGift(FACTION, 'fuel', 5)), 'gift accepted')
    end
    T.eq(GameState.resources.fuel, 0, 'all twenty fuel was spent')
    T.eq(Factions.getRep(FACTION), 20 + 4 * 5, 'four preferred gifts at +5 each')
end)

---------------------------------------------------------------------------
-- Graceful failure
---------------------------------------------------------------------------

T.test('an unaffordable gift fails, says why, and changes nothing', function()
    reset({ fuel = 2 })
    local repBefore = Factions.getRep(FACTION)
    local ok, err = Factions.sendGift(FACTION, 'fuel', 5)
    T.ok(not ok, 'the gift was refused')
    T.ok(tostring(err):find('Not enough'), 'the reason names the shortfall: ' .. tostring(err))
    T.ok(tostring(err):find('fuel'), 'and names the resource')
    T.eq(GameState.resources.fuel, 2, 'nothing was deducted')
    T.eq(Factions.getRep(FACTION), repBefore, 'and no reputation was granted')
end)

T.test('gifting with an empty colony fails rather than granting free rep', function()
    reset({ thermalCores = 0 })
    local repBefore = Factions.getRep('mastema_ops')
    local ok = Factions.sendGift('mastema_ops', 'thermalCores', 5)
    T.ok(not ok, 'refused with nothing in store')
    T.eq(Factions.getRep('mastema_ops'), repBefore, 'reputation unchanged')
end)

T.test('an unknown faction is refused', function()
    reset({ fuel = 50 })
    local ok, err = Factions.sendGift('not_a_faction', 'fuel', 5)
    T.ok(not ok, 'refused')
    T.eq(err, 'Unknown faction', 'with a clear reason')
    T.eq(GameState.resources.fuel, 50, 'nothing spent')
end)

T.test('a nil or non-positive amount is refused', function()
    reset({ fuel = 50 })
    T.ok(not (Factions.sendGift(FACTION, 'fuel', 0)), 'zero is refused')
    T.ok(not (Factions.sendGift(FACTION, 'fuel', -5)), 'negative is refused')
    T.ok(not (Factions.sendGift(FACTION, nil, 5)), 'a nil resource is refused')
    T.eq(GameState.resources.fuel, 50, 'nothing spent')
end)

---------------------------------------------------------------------------
-- Trade routes gate on standing, which gifting is the way to reach
---------------------------------------------------------------------------

T.test('a trade route needs allied standing, and gifting can get there', function()
    reset({ fuel = 200 })
    local TradeRoutes = require('src.trade.trade_routes')
    TradeRoutes.restoreState({ routes = {}, log = {} })

    local ok, err = TradeRoutes.establish(FACTION)
    T.ok(not ok, 'not allied yet, so no route')
    T.ok(tostring(err):find('allied'), 'the refusal explains the requirement')

    -- Preferred gifts at +5 rep each, from a +20 corporate start.
    for _ = 1, 8 do Factions.sendGift(FACTION, 'fuel', 5) end
    T.eq(Factions.getStanding(FACTION), 'allied', 'enough tribute reaches allied')

    T.ok((TradeRoutes.establish(FACTION)), 'now the route can be established')
    T.ok(TradeRoutes.hasRoute(FACTION), 'and it is recorded')
    TradeRoutes.cancel(FACTION)
end)
