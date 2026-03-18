-- miners.lua — Factorio-style automated mining drills
-- Placed on minable ore tiles. Extract resources automatically with just power
-- (no operator needed). Multiple tiers from burner to advanced electric.
-- Bore drill digs down through z-levels until durability runs out.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')
local Power     = require('src.sim.power')
local Items     = require('src.world.items')

local Miners = {}

-- Lazy-loaded modules (cached after first require)
local _Storyteller
local function lazyStorytellerLog(category, msg)
    if _Storyteller == nil then
        local ok, mod = pcall(require, 'src.storyteller.storyteller')
        _Storyteller = ok and mod or false
    end
    if _Storyteller and _Storyteller.logEvent then
        _Storyteller.logEvent(category, msg)
    end
end

---------------------------------------------------------------------------
-- Minable tile → resource mapping
---------------------------------------------------------------------------

-- Which tiles a miner can be placed on and what they yield
local MINEABLE_TILES = {
    [Tiles.ORE_VEIN]         = { resource = 'metal',  amount = 3, resultTile = Tiles.DEBRIS },
    [Tiles.LEAD_ORE]         = { resource = 'lead',   amount = 3, resultTile = Tiles.DEBRIS },
    [Tiles.UNDERGROUND_ROCK] = { resource = 'stone',  amount = 2, resultTile = Tiles.UNDERGROUND_FLOOR },
    [Tiles.DEEP_ROCK]        = { resource = 'stone',  amount = 3, resultTile = Tiles.DEBRIS },
    [Tiles.VOLCANIC_ROCK]    = { resource = 'stone',  amount = 4, resultTile = Tiles.VOLCANIC_FLOOR },
    [Tiles.ROCK]             = { resource = 'stone',  amount = 2, resultTile = Tiles.DEBRIS },
}

Miners.MINEABLE_TILES = MINEABLE_TILES

---------------------------------------------------------------------------
-- Miner definitions
---------------------------------------------------------------------------

-- Each miner type: cycleTime (seconds per extraction), powerDraw (watts, 0 = burner),
-- yieldMult (multiplier on base resource amount), fuelRate (fuel/s for burner types)
local MINER_DEFS = {
    burner_drill = {
        name         = 'Burner Mining Drill',
        cycleTime    = 15,
        powerDraw    = 0,
        yieldMult    = 1.0,
        fuelRate      = 0.06,   -- burns fuel (wood/coal)
        exhaustChance = 0.08,   -- chance to exhaust ore tile per cycle
    },
    electric_drill = {
        name         = 'Electric Mining Drill',
        cycleTime    = 10,
        powerDraw    = 30,
        yieldMult    = 1.2,
        fuelRate      = 0,
        exhaustChance = 0.06,
    },
    advanced_drill = {
        name         = 'Advanced Mining Drill',
        cycleTime    = 6,
        powerDraw    = 60,
        yieldMult    = 1.5,
        fuelRate      = 0,
        exhaustChance = 0.04,
    },
    bore_drill = {
        name         = 'Bore Drill',
        cycleTime    = 30,     -- seconds per z-level bore
        powerDraw    = 80,
        yieldMult    = 0.5,    -- small resource yield as byproduct
        fuelRate      = 0,
        exhaustChance = 0,     -- doesn't exhaust — it moves down
        maxDurability = 5,     -- number of z-levels it can drill through
        isBore       = true,
    },
}

Miners.DEFS = MINER_DEFS

-- Upgrade tier speed/yield multipliers (stacks with base yieldMult)
local TIER_MULTS = {
    [1] = { speed = 1.15, yield = 1.10 },
    [2] = { speed = 1.30, yield = 1.20 },
    [3] = { speed = 1.45, yield = 1.35 },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Check if a tile is valid for miner placement
function Miners.isValidTile(x, y, depth, minerType)
    local World = require('src.world.tilemap')
    if not World.inBounds(x, y) then return false end
    local tile = World.getTile(x, y, depth or 0)

    if minerType == 'bore_drill' then
        -- Bore drill can be placed on any solid minable tile or underground floor
        local props = Tiles.get(tile)
        return props and (props.minable or tile == Tiles.UNDERGROUND_FLOOR
            or tile == Tiles.PERMAFROST or tile == Tiles.DEBRIS)
    end

    return MINEABLE_TILES[tile] ~= nil
end

--- Get the resource info for a tile
local function getTileResource(tile, depth)
    local info = MINEABLE_TILES[tile]
    if info then
        -- Underground tiles result in underground floor, not debris
        local result = info.resultTile
        if depth and depth > 0 and result == Tiles.DEBRIS then
            result = Tiles.UNDERGROUND_FLOOR
        end
        return info.resource, info.amount, result
    end
    return nil, 0, nil
end

---------------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------------

--- Place a miner at (x, y). Returns entity ID or nil, error.
function Miners.place(x, y, depth, minerType)
    depth = depth or 0
    local def = MINER_DEFS[minerType]
    if not def then return nil, 'Unknown miner type' end

    if not Miners.isValidTile(x, y, depth, minerType) then
        return nil, 'Cannot place miner here'
    end

    local World = require('src.world.tilemap')
    local tile = World.getTile(x, y, depth)
    local resource, amount, _ = getTileResource(tile, depth)

    local id = ECS.spawn()

    ECS.set(id, 'pos', { x = x, y = y, depth = depth })

    ECS.set(id, 'miner', {
        type          = minerType,
        progress      = 0,
        cycleTime     = def.cycleTime,
        active        = false,
        powered       = def.powerDraw == 0,  -- burners start powered
        fuel          = def.fuelRate > 0 and 100 or 0,
        resource      = resource,
        yieldAmount   = amount,
        yieldMult     = def.yieldMult,
        exhausted     = false,
        upgradeTier   = 0,
        -- Bore drill specific
        durability    = def.maxDurability or 0,
        maxDurability = def.maxDurability or 0,
        boreDepth     = depth,   -- current depth the bore is working at
    })

    ECS.set(id, 'building_ref', { type = 'miner', defId = minerType })

    -- Register as power consumer if electric
    if def.powerDraw > 0 then
        Power.addConsumer(id, def.powerDraw, x, y)
    end

    return id
end

--- Remove a miner entity
function Miners.remove(minerId)
    local miner = ECS.get(minerId, 'miner')
    if not miner then return end
    local def = MINER_DEFS[miner.type]
    if def and def.powerDraw > 0 then
        Power.removeConsumer(minerId)
    end
    ECS.destroy(minerId)
end

---------------------------------------------------------------------------
-- Fuel management (burner drills)
---------------------------------------------------------------------------

-- Ordered list for deterministic fuel selection (prefer higher-value fuels first)
local FUEL_ORDER = {
    { type = 'coal', value = 50 },
    { type = 'wood', value = 30 },
    { type = 'peat', value = 20 },
}

--- Try to consume fuel from colony resources for a burner drill.
local function refuelBurner(miner)
    for _, fuel in ipairs(FUEL_ORDER) do
        if (GameState.resources[fuel.type] or 0) >= 1 then
            GameState.spendResource(fuel.type, 1)
            miner.fuel = miner.fuel + fuel.value
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Bore drill: dig down to next z-level
---------------------------------------------------------------------------

local function boreDrillCycle(id, miner, pos)
    local World = require('src.world.tilemap')
    local targetDepth = miner.boreDepth + 1

    -- Check if target layer exists, create if needed
    if not World.hasLayer(targetDepth) then
        if World.createLayer then
            World.createLayer(targetDepth)
        else
            miner.exhausted = true
            return
        end
    end

    -- Create stair connection: current depth gets STAIR_DOWN, target gets STAIR_UP
    local curTile = World.getTile(pos.x, pos.y, miner.boreDepth)
    if curTile ~= Tiles.STAIR_DOWN and curTile ~= Tiles.STAIR_BOTH then
        -- Check if we already have an up stair here
        if curTile == Tiles.STAIR_UP then
            World.setTile(pos.x, pos.y, Tiles.STAIR_BOTH, miner.boreDepth)
        else
            World.setTile(pos.x, pos.y, Tiles.STAIR_DOWN, miner.boreDepth)
        end
    end

    -- Set target depth tile to stair up
    local targetTile = World.getTile(pos.x, pos.y, targetDepth)
    if targetTile ~= Tiles.STAIR_UP and targetTile ~= Tiles.STAIR_BOTH then
        if targetTile == Tiles.STAIR_DOWN then
            World.setTile(pos.x, pos.y, Tiles.STAIR_BOTH, targetDepth)
        else
            World.setTile(pos.x, pos.y, Tiles.STAIR_UP, targetDepth)
        end
    end

    -- Small stone yield as byproduct
    local yieldMult = miner.yieldMult
    local tierMults = TIER_MULTS[miner.upgradeTier]
    if tierMults then yieldMult = yieldMult * tierMults.yield end
    local stoneYield = math.max(1, math.floor(2 * yieldMult))
    Items.spawn(pos.x, pos.y, 'stone', stoneYield, nil, miner.boreDepth)

    -- Advance bore depth, consume durability
    miner.boreDepth = targetDepth
    miner.durability = miner.durability - 1

    -- Structural notification
    local sok, Structural = pcall(require, 'src.world.structural')
    if sok and Structural.onExcavation then
        Structural.onExcavation(pos.x, pos.y, targetDepth)
    end

    -- Log event
    lazyStorytellerLog('mining', 'Bore drill reached depth ' .. targetDepth .. '.')

    -- Check if drill broke
    if miner.durability <= 0 then
        miner.exhausted = true
        miner.active = false
        lazyStorytellerLog('mining', 'Bore drill has broken down after reaching depth ' .. targetDepth .. '.')
    end
end

---------------------------------------------------------------------------
-- Standard miner: extract resource from tile
---------------------------------------------------------------------------

local function standardMinerCycle(id, miner, pos)
    local World = require('src.world.tilemap')
    local def = MINER_DEFS[miner.type]
    local depth = pos.depth or 0

    -- Calculate yield
    local yieldMult = miner.yieldMult
    local tierMults = TIER_MULTS[miner.upgradeTier]
    if tierMults then yieldMult = yieldMult * tierMults.yield end
    local amount = math.max(1, math.floor(miner.yieldAmount * yieldMult))

    -- Spawn resource as physical item at the miner's position
    if miner.resource then
        Items.spawn(pos.x, pos.y, miner.resource, amount, nil, depth)
    end

    -- Check if ore is exhausted
    if def.exhaustChance > 0 and math.random() < def.exhaustChance then
        local tile = World.getTile(pos.x, pos.y, depth)
        local _, _, resultTile = getTileResource(tile, depth)
        if resultTile then
            World.setTile(pos.x, pos.y, resultTile, depth)
            miner.exhausted = true
            miner.active = false

            lazyStorytellerLog('mining', 'Mining drill exhausted ore deposit at (' .. pos.x .. ', ' .. pos.y .. ').')
        end
    end
end

---------------------------------------------------------------------------
-- ECS system: miner tick
---------------------------------------------------------------------------

local function minerSystem(dt, id, comps)
    local miner = comps.miner
    local pos = comps.pos

    if miner.exhausted then return end

    local def = MINER_DEFS[miner.type]
    if not def then return end

    -- Power check: electric drills need power from power grid
    if def.powerDraw > 0 then
        -- Power status is set by Power.step() on the consumer
        local powered = Power.isConsumerPowered and Power.isConsumerPowered(id)
        if powered == nil then
            -- Fallback: check building_ref for power state
            local ref = comps.building_ref
            powered = ref and ref.powered
        end
        miner.powered = powered or false
    end

    -- Fuel check: burner drills consume fuel
    if def.fuelRate > 0 then
        if miner.fuel <= 0 then
            -- Try to refuel
            if not refuelBurner(miner) then
                miner.active = false
                miner.powered = false
                return
            end
        end
        miner.fuel = miner.fuel - def.fuelRate * dt
        miner.powered = miner.fuel > 0
    end

    if not miner.powered then
        miner.active = false
        return
    end

    miner.active = true

    -- Speed multiplier from upgrade tier
    local speedMult = 1.0
    local tierMults = TIER_MULTS[miner.upgradeTier]
    if tierMults then speedMult = tierMults.speed end

    -- Advance extraction cycle
    miner.progress = miner.progress + dt * speedMult
    if miner.progress >= miner.cycleTime then
        miner.progress = miner.progress - miner.cycleTime

        if def.isBore then
            boreDrillCycle(id, miner, pos)
        else
            standardMinerCycle(id, miner, pos)
        end
    end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

function Miners.registerSystems()
    ECS.addSystem('miner_tick', { 'miner', 'pos', 'building_ref' }, minerSystem, 16)
end

Miners.registerSystems()

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Miners.getMiner(entityId)
    return ECS.get(entityId, 'miner')
end

function Miners.isActive(entityId)
    local miner = ECS.get(entityId, 'miner')
    return miner and miner.active
end

function Miners.getProgress(entityId)
    local miner = ECS.get(entityId, 'miner')
    if not miner then return 0 end
    return miner.progress / miner.cycleTime
end

function Miners.isExhausted(entityId)
    local miner = ECS.get(entityId, 'miner')
    return miner and miner.exhausted
end

function Miners.getAllMiners()
    local result = {}
    for id, comps in ECS.query('miner', 'pos') do
        result[#result + 1] = {
            id    = id,
            pos   = comps.pos,
            miner = comps.miner,
        }
    end
    return result
end

--- Get display info for a miner (for UI tooltips)
function Miners.getInfo(entityId)
    local miner = ECS.get(entityId, 'miner')
    if not miner then return nil end
    local def = MINER_DEFS[miner.type]
    return {
        name       = def and def.name or 'Unknown Drill',
        type       = miner.type,
        active     = miner.active,
        powered    = miner.powered,
        exhausted  = miner.exhausted,
        progress   = miner.progress / miner.cycleTime,
        resource   = miner.resource,
        fuel       = miner.fuel,
        isBurner   = def and def.fuelRate > 0,
        isBore     = def and def.isBore,
        durability = miner.durability,
        maxDurability = miner.maxDurability,
        upgradeTier = miner.upgradeTier,
    }
end

--- Upgrade a miner to the next tier
function Miners.upgrade(entityId)
    local miner = ECS.get(entityId, 'miner')
    if not miner then return false, 'Not a miner' end
    if miner.upgradeTier >= 3 then return false, 'Already at max tier' end
    miner.upgradeTier = miner.upgradeTier + 1
    return true
end

-- Non-ECS periodic step (placeholder for future use, e.g. stats tracking)
function Miners.step(dt)
    -- No periodic work needed outside ECS system
end

return Miners
