-- test_cold_survival.lua — guards on the "froze to death doing nothing" class
--
-- Every case here reproduces a specific way an acceptance run lost a colonist
-- to exposure while it was standing still at full health:
--   * the warmth search only accepted tiles above 15C, but the simulation
--     restores warmth above 10C, so a survivable tile was refused
--   * the walk-home fallback was gated behind warmth < 30, i.e. it unlocked
--     only after hypothermia had started draining HP
--   * long emergency routes blew the pathfinder's node budget during a blizzard
--   * a colonist with no bed lay down on open ground at -50C
--   * hunger outranked warmth even when the colony had no food at all, which
--     switched the cold emergency off permanently
--   * a mental break switched off warmth-seeking, movement AND self-defence

local T = require('tests.test_framework')
local H = require('tests.helpers')

--- Flat, walkable, uniformly freezing surface with a known ambient.
local function coldWorld(size, temp)
    local World = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')
    World.init(size, size)
    require('src.sim.lighting').init(World)
    require('src.sim.thermal').init(World)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            World.setTile(x, y, Tiles.SNOW, 0)
            World.setTemp(x, y, temp, 0)
        end
    end
    require('src.util.occupancy').rebuild()
    return World
end

---------------------------------------------------------------------------
T.suite('Cold survival: the warmth search accepts what the sim accepts')

T.test('a 12C tile is a valid refuge, not just a >15C one', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local GameState = require('src.game_state')
    local WorkAI    = require('src.colonist.work_ai')
    local World     = coldWorld(48, -50)

    GameState.hour = 10          -- work block
    GameState.startX, GameState.startY = 40, 40

    -- The only relief on the map sits in the 10-15C band a campfire's outer
    -- falloff ring produces. colonist.lua gains warmth above 10C, so this is
    -- survival; the old search rejected it and the colonist froze in place.
    for x = 18, 22 do
        for y = 18, 22 do World.setTemp(x, y, 12.0, 0) end
    end

    local id = H.spawnTestColonist(10, 20, { warmth = 30, food = 90, water = 90 })
    require('src.util.occupancy').rebuild()
    WorkAI.registerSystems()

    local col = ECS.get(id, 'colonist')
    for _ = 1, 40 do
        ECS.update(0.05)
        if col.state == 'seeking_warmth' then break end
    end
    T.eq(col.state, 'seeking_warmth', 'colonist commits to the 12C refuge')
    local path = ECS.get(id, 'path')
    T.ok(path.nodes and #path.nodes > 0, 'and has a route to walk')
end)

T.test('the walk home fires well above warmth 30', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local GameState = require('src.game_state')
    local WorkAI    = require('src.colonist.work_ai')
    local World     = coldWorld(48, -70)

    GameState.hour = 10
    -- Home is warm; nothing else on the map is.
    GameState.startX, GameState.startY = 40, 40
    World.setTemp(40, 40, 25.0, 0)

    -- 34 tiles out, so the ring scan cannot see the landing site directly.
    -- Warmth 45 at -70C is ~112 seconds of life, which trips the time-to-freeze
    -- trigger while leaving the colonist well clear of the old warmth < 30 gate.
    local id = H.spawnTestColonist(6, 40, { warmth = 45, food = 90, water = 90 })
    require('src.util.occupancy').rebuild()
    WorkAI.registerSystems()

    local col = ECS.get(id, 'colonist')
    for _ = 1, 40 do
        ECS.update(0.05)
        if col.state == 'seeking_warmth' then break end
    end
    T.eq(col.state, 'seeking_warmth', 'starts walking home at warmth 45')
    T.ok(ECS.get(id, 'needs').warmth > 30,
        'and does so before hypothermia damage begins')
end)

---------------------------------------------------------------------------
T.suite('Cold survival: emergency pathfinding budget')

T.test('maxNodes raises the search limit for survival routes', function()
    H.resetAll()
    local Pathfind = require('src.util.pathfind')
    local World    = coldWorld(64, -50)

    -- A long route across an open map. The default budget is 3000 expanded
    -- nodes; a survival caller can buy more.
    local route = Pathfind.find(2, 2, 60, 60, World, nil, 0, 0,
        { maxNodes = 20000 })
    T.notnil(route, 'a long route is found with a raised budget')
    T.ok(#route > 60, 'and it really is long (' .. tostring(route and #route) .. ')')
end)

T.test('a failed search records why it gave up', function()
    H.resetAll()
    local Pathfind = require('src.util.pathfind')
    local Tiles    = require('src.world.tiles')
    local World    = coldWorld(32, -50)

    World.setTile(20, 20, Tiles.WALL_STONE, 0)
    T.isnil(Pathfind.find(2, 2, 20, 20, World, nil, 0, 0), 'no route into a wall')
    T.eq(Pathfind.lastFail, 'unwalkable', 'failure reason is reported')

    T.notnil(Pathfind.find(2, 2, 4, 4, World, nil, 0, 0), 'a clear route succeeds')
    T.isnil(Pathfind.lastFail, 'and clears the previous failure reason')
end)

T.test('ignoreSnowCost drops the deep-snow surcharge', function()
    H.resetAll()
    local Pathfind = require('src.util.pathfind')
    local World    = coldWorld(32, -50)
    if not World.setSnow then return end   -- snow layer optional

    for y = 0, 31 do
        for x = 0, 31 do World.setSnow(x, y, 7, 0) end
    end
    -- Both must still find a route; the point is that the emergency variant
    -- does not pay a per-tile surcharge that flattens the heuristic.
    T.notnil(Pathfind.find(2, 2, 28, 28, World, nil, 0, 0,
        { maxNodes = 20000, ignoreSnowCost = true }),
        'snow-blind emergency route still succeeds through max-depth snow')
end)

---------------------------------------------------------------------------
T.suite('Cold survival: nobody sleeps on frozen ground')

T.test('a colonist with no bed stays awake on a freezing tile', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local GameState = require('src.game_state')
    local WorkAI    = require('src.colonist.work_ai')
    coldWorld(32, -50)

    GameState.hour = 2                -- sleep block
    GameState.startX, GameState.startY = 16, 16

    -- Warmth is comfortable, so the old guard (warmth < 40) never engaged and
    -- the colonist slept off the first 15 points of the drain lying down.
    local id = H.spawnTestColonist(4, 4, { warmth = 55, food = 90, water = 90 })
    require('src.util.occupancy').rebuild()
    WorkAI.registerSystems()

    local col = ECS.get(id, 'colonist')
    for _ = 1, 20 do ECS.update(0.05) end
    T.ok(col.state ~= 'sleeping', 'does not bed down on open ground (state: '
        .. tostring(col.state) .. ')')
end)

T.test('a colonist with no bed does sleep on a warm tile', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local GameState = require('src.game_state')
    local WorkAI    = require('src.colonist.work_ai')
    local World     = coldWorld(32, -50)

    GameState.hour = 2
    GameState.startX, GameState.startY = 16, 16
    World.setTemp(4, 4, 22.0, 0)      -- beside the fire

    local id = H.spawnTestColonist(4, 4, { warmth = 80, food = 90, water = 90 })
    require('src.util.occupancy').rebuild()
    WorkAI.registerSystems()

    local col = ECS.get(id, 'colonist')
    for _ = 1, 20 do
        ECS.update(0.05)
        if col.state == 'sleeping' then break end
    end
    T.eq(col.state, 'sleeping', 'sleeps rough where the ground is survivable')
end)

---------------------------------------------------------------------------
T.suite('Cold survival: hunger does not outrank warmth when there is no food')

T.test('an empty larder hands priority back to the cold emergency', function()
    H.resetAll()
    local ECS       = require('src.ecs.ecs')
    local GameState = require('src.game_state')
    local WorkAI    = require('src.colonist.work_ai')
    local World     = coldWorld(32, -50)

    GameState.hour = 10
    GameState.startX, GameState.startY = 16, 16
    World.setTemp(16, 16, 25.0, 0)    -- a lit fire at home
    -- No food items exist anywhere in the world.

    -- food 18 is below URGENT_FOOD (35): hunger used to suppress the warmth
    -- search outright, and with no food to walk to the colonist stood still and
    -- froze at full HP a few tiles from the fire.
    local id = H.spawnTestColonist(10, 16, { warmth = 30, food = 18, water = 90 })
    require('src.util.occupancy').rebuild()
    WorkAI.registerSystems()

    local col = ECS.get(id, 'colonist')
    for _ = 1, 120 do
        ECS.update(0.05)
        if col.state == 'seeking_warmth' then break end
    end
    T.eq(col.state, 'seeking_warmth', 'starving colonist still heads for warmth')
end)

---------------------------------------------------------------------------
T.suite('Cold survival: a mental break is not a death sentence')

T.test('survivalOverride flags a colonist running out of warmth', function()
    H.resetAll()
    local MB    = require('src.colonist.mental_breaks')
    MB.registerSystems()
    coldWorld(32, -90)                -- drain 0.5/s

    local pos   = { x = 4, y = 4, depth = 0 }
    local col   = { name = 'T' }
    T.eq(MB.survivalOverride(1, col, pos, { warmth = 20, food = 90, water = 90 }),
        'cold', '20 warmth at -90C is 40 seconds of life: cold wins')
    T.isnil(MB.survivalOverride(1, col, pos, { warmth = 100, food = 90, water = 90 }),
        'a full warmth bar is not an emergency')
end)

T.test('survivalOverride flags a hostile in biting range', function()
    H.resetAll()
    local MB = require('src.colonist.mental_breaks')
    MB.registerSystems()
    coldWorld(32, 20)                 -- warm, so cold cannot be the trigger

    local pos = { x = 10, y = 10, depth = 0 }
    local col = { name = 'T' }
    local needs = { warmth = 100, food = 90, water = 90 }
    T.isnil(MB.survivalOverride(1, col, pos, needs), 'nothing nearby yet')

    H.spawnTestCreature(12, 10, { hostile = true, species = 'tundra_wolf' })
    T.eq(MB.survivalOverride(1, col, pos, needs), 'threat',
        'a hostile two tiles away ends the break so the colonist can react')
end)

T.test('the cold cuts a mental break short, penalty and all', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    require('src.colonist.mental_breaks').registerSystems()
    coldWorld(32, -90)

    local id  = H.spawnTestColonist(4, 4, { warmth = 15, food = 90, water = 90 })
    local col = ECS.get(id, 'colonist')
    local needs = ECS.get(id, 'needs')
    needs.morale = 50
    col.state = 'mental_break'
    col.sanity = 0

    for _ = 1, 5 do ECS.update(0.05) end

    T.ok(col.state ~= 'mental_break', 'break does not hold a freezing colonist')
    T.isnil(col._mentalBreak, 'break state cleared')
    T.eq(col._breakCutShortBy, 'cold', 'and records why')
    T.ok(needs.morale < 50, 'the morale penalty still lands (no free pass)')
end)

T.test('a mental break in a warm safe room runs its course', function()
    H.resetAll()
    local ECS = require('src.ecs.ecs')
    require('src.colonist.mental_breaks').registerSystems()
    coldWorld(32, 20)

    local id  = H.spawnTestColonist(4, 4, { warmth = 90, food = 90, water = 90 })
    local col = ECS.get(id, 'colonist')
    col.state = 'mental_break'
    col.sanity = 0

    for _ = 1, 5 do ECS.update(0.05) end
    T.eq(col.state, 'mental_break', 'a safe colonist still gets to break down')
    T.notnil(col._mentalBreak, 'break is running')
end)
