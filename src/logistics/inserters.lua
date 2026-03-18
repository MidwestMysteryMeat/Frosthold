-- inserters.lua — Item transfer between belts, machines, and stockpiles
-- Inserter entities sit between a source tile and a destination tile.
-- Each tick they attempt to grab an item from source and place it on dest.
-- Types: basic (1 item / 2s), fast (1 item / 0.5s), filter (specific item).
-- All inserters draw 5W from the power grid.

local ECS        = require('src.ecs.ecs')
local Power      = require('src.sim.power')
local Conveyors  = require('src.logistics.conveyors')
local Production = require('src.building.production')
local GameState  = require('src.game_state')

local Inserters = {}

---------------------------------------------------------------------------
-- Inserter type definitions
---------------------------------------------------------------------------

local TYPES = {
    basic_inserter = {
        name      = 'Basic Inserter',
        interval  = 2.0,    -- seconds between transfers
        power     = 5,      -- watts draw
        filter    = false,
        cost      = { metal_ingot = 2, components = 1 },
    },
    fast_inserter = {
        name      = 'Fast Inserter',
        interval  = 0.5,
        power     = 5,
        filter    = false,
        cost      = { metal_ingot = 3, components = 2, circuit = 1 },
    },
    filter_inserter = {
        name      = 'Filter Inserter',
        interval  = 1.0,
        power     = 5,
        filter    = true,
        cost      = { metal_ingot = 2, components = 2, circuit = 1 },
    },
    stack_inserter = {
        name      = 'Stack Inserter',
        interval  = 0.8,
        power     = 10,
        filter    = false,
        stackSize = 4,   -- transfers 4 items per grab
        cost      = { steel = 2, components = 3, circuit = 1 },
    },
    fast_filter_inserter = {
        name      = 'Fast Filter Inserter',
        interval  = 0.4,
        power     = 8,
        filter    = true,
        cost      = { steel = 2, components = 3, circuit = 2 },
    },
}

Inserters.TYPES = TYPES

---------------------------------------------------------------------------
-- Source/dest interaction helpers
---------------------------------------------------------------------------

-- Try to take one item from a source tile.
-- Returns a full item table { id, quality, material, durability, amount } or nil.
local function takeFromSource(sx, sy, filterItem)
    -- Source is a belt? extractItem now returns the full item table.
    if Conveyors.isBelt(sx, sy) then
        if filterItem then
            local onBelt = Conveyors.getItemId(sx, sy)
            if onBelt ~= filterItem then return nil end
        end
        return Conveyors.extractItem(sx, sy)
    end

    -- Source is a machine output buffer?
    for id, comps in ECS.query('pos', 'machine') do
        local pos = comps.pos
        if pos.x == sx and pos.y == sy then
            local machine = comps.machine
            for itemId, count in pairs(machine.outputBuf) do
                if count > 0 then
                    if filterItem and itemId ~= filterItem then goto skip end
                    machine.outputBuf[itemId] = count - 1
                    if machine.outputBuf[itemId] <= 0 then
                        machine.outputBuf[itemId] = nil
                    end
                    -- Machine output buffers store plain counts; wrap as item table.
                    return { id = itemId, amount = 1, quality = 'normal', durability = 100 }
                end
                ::skip::
            end
        end
    end

    -- Source is a stockpile entity?
    for id, comps in ECS.query('pos', 'stockpile') do
        local pos = comps.pos
        if pos.x == sx and pos.y == sy then
            local stock = comps.stockpile
            for itemId, count in pairs(stock.items) do
                if count > 0 then
                    if filterItem and itemId ~= filterItem then goto skip2 end
                    stock.items[itemId] = count - 1
                    if stock.items[itemId] <= 0 then
                        stock.items[itemId] = nil
                    end
                    -- Stockpile entities store plain counts; wrap as item table.
                    return { id = itemId, amount = 1, quality = 'normal', durability = 100 }
                end
                ::skip2::
            end
        end
    end

    return nil
end

-- Normalise heldItem to a table regardless of legacy string storage.
local function normaliseItem(heldItem)
    if type(heldItem) == 'string' then
        return { id = heldItem, amount = 1, quality = 'normal', durability = 100 }
    end
    return heldItem
end

-- Try to place one item onto a destination tile.
-- itemData must be a full item table { id, amount, quality, material, durability }.
-- Returns true on success.
local function placeOnDest(dx, dy, itemData)
    local itemId = itemData.id

    -- Dest is a belt?
    if Conveyors.isBelt(dx, dy) then
        return Conveyors.insertItem(dx, dy, itemId, itemData)
    end

    -- Dest is a machine input buffer?
    for id, comps in ECS.query('pos', 'machine') do
        local pos = comps.pos
        if pos.x == dx and pos.y == dy then
            local machine = comps.machine
            -- Only insert if machine has a recipe that accepts this item
            if machine.recipe then
                local recipe = Production.RECIPES[machine.recipe]
                if recipe and recipe.inputs[itemId] then
                    machine.inputBuf[itemId] = (machine.inputBuf[itemId] or 0) + 1
                    return true
                end
            end
            -- No valid recipe slot — allow generic buffer for flexibility
            machine.inputBuf[itemId] = (machine.inputBuf[itemId] or 0) + 1
            return true
        end
    end

    -- Dest is a stockpile?
    for id, comps in ECS.query('pos', 'stockpile') do
        local pos = comps.pos
        if pos.x == dx and pos.y == dy then
            local stock = comps.stockpile
            stock.items[itemId] = (stock.items[itemId] or 0) + 1
            return true
        end
    end

    return false
end

---------------------------------------------------------------------------
-- Spawn / Destroy
---------------------------------------------------------------------------

function Inserters.spawn(inserterType, x, y, sourceX, sourceY, destX, destY)
    local def = TYPES[inserterType]
    if not def then return nil end

    local id = ECS.spawn()

    ECS.set(id, 'pos', { x = x, y = y })

    ECS.set(id, 'inserter', {
        type      = inserterType,
        sourceX   = sourceX,
        sourceY   = sourceY,
        destX     = destX,
        destY     = destY,
        timer     = 0,
        interval  = def.interval,
        filterItem = nil,  -- set later for filter_inserter
        heldItem  = nil,   -- item currently being moved (in-transit)
        powered   = false,
    })

    -- Register as power consumer
    Power.addConsumer(id, def.power, x, y)

    return id
end

function Inserters.destroy(entityId)
    -- Drop held item on the ground so it isn't permanently lost
    local ins = ECS.get(entityId, 'inserter')
    if ins and ins.heldItem then
        local pos = ECS.get(entityId, 'pos')
        if pos then
            local iok, Items = pcall(require, 'src.world.items')
            if iok and Items.spawn then
                local held = normaliseItem(ins.heldItem)
                Items.spawn(pos.x, pos.y, held.id, held.amount or 1, nil, pos.depth or 0, {
                    quality    = held.quality,
                    material   = held.material,
                    durability = held.durability,
                })
            end
        end
    end
    Power.removeConsumer(entityId)
    ECS.destroy(entityId)
end

function Inserters.setFilter(entityId, itemId)
    local ins = ECS.get(entityId, 'inserter')
    if not ins then return end
    local def = TYPES[ins.type]
    if not def or not def.filter then return end
    ins.filterItem = itemId
end

---------------------------------------------------------------------------
-- System — registered with ECS
---------------------------------------------------------------------------

local function inserterSystem(dt, id, comps)
    local ins = comps.inserter
    local def = TYPES[ins.type]
    if not def then return end

    -- Check circuit control (disabled by automation)
    if ins.enabled == false then return end

    -- Check power
    local pos = comps.pos
    ins.powered = Power.isGridPowered(pos.x, pos.y)
    if not ins.powered then return end

    -- Tick cooldown
    ins.timer = ins.timer + dt
    if ins.timer < ins.interval then return end
    ins.timer = ins.timer - ins.interval

    -- If holding an item from a previous failed place, try to place again
    if ins.heldItem then
        ins.heldItem = normaliseItem(ins.heldItem)
        if placeOnDest(ins.destX, ins.destY, ins.heldItem) then
            ins.heldItem = nil
        end
        return
    end

    -- Grab from source
    local filterItem = nil
    if def.filter then
        filterItem = ins.filterItem
        if not filterItem then return end  -- filter inserter with no filter set does nothing
    end

    local grabs = def.stackSize or 1
    for _ = 1, grabs do
        -- takeFromSource returns a full item table or nil
        local grabbed = takeFromSource(ins.sourceX, ins.sourceY, filterItem)
        if not grabbed then break end

        -- Try to place immediately
        if not placeOnDest(ins.destX, ins.destY, grabbed) then
            -- Hold it until next cycle
            ins.heldItem = grabbed
            break
        end
    end
end

function Inserters.registerSystems()
    ECS.addSystem('inserters', { 'inserter', 'pos' }, inserterSystem, 16)
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Inserters.init() end

function Inserters.getAll()
    local result = {}
    for id, comps in ECS.query('inserter', 'pos') do
        result[#result + 1] = { id = id, inserter = comps.inserter, pos = comps.pos }
    end
    return result
end

function Inserters.count()
    return ECS.countWith('inserter')
end

return Inserters
