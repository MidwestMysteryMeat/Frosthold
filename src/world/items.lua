-- items.lua — Ground item entity system
-- Items dropped on the world are ECS entities with pos + item components.
-- Hauling AI picks them up and moves them to stockpiles.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local ItemDefs  = require('src.world.item_defs')

local Items = {}

function Items.spawn(x, y, itemId, amount, category, depth, opts)
    opts = opts or {}
    local def = ItemDefs.get(itemId)
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth or 0 })
    ECS.set(id, 'item', {
        itemId     = itemId,
        amount     = amount or 1,
        category   = category or def.category,
        quality    = opts.quality,
        material   = opts.material,
        weight     = def.weight,
        durability = opts.durability or 100,
        hauled     = false,  -- true when a colonist is carrying this
    })
    return id
end

function Items.getAt(x, y, depth)
    local d = depth or 0
    for id, comps in ECS.query('pos', 'item') do
        if comps.pos.x == x and comps.pos.y == y and (comps.pos.depth or 0) == d and not comps.item.hauled then
            return id, comps.item
        end
    end
    return nil
end

function Items.getAllUnhauled()
    local result = {}
    for id, comps in ECS.query('pos', 'item') do
        if not comps.item.hauled then
            result[#result + 1] = { id = id, pos = comps.pos, item = comps.item }
        end
    end
    return result
end

function Items.pickup(itemEntityId)
    local item = ECS.get(itemEntityId, 'item')
    if item then
        item.hauled = true
    end
end

function Items.destroy(itemEntityId)
    ECS.destroy(itemEntityId)
end

---------------------------------------------------------------------------
-- Find nearest edible food — searches stockpile zones then ground items
-- Returns { source='zone', zoneId, x, y, depth, itemId }
--      or { source='ground', entityId, x, y, depth, itemId }
--      or nil if no food found
---------------------------------------------------------------------------

function Items.findNearestFood(px, py, pd, foodQualityTable, allowFn)
    local zok, Zones = pcall(require, 'src.world.zones')
    if not zok then return nil end
    pd = pd or 0

    local bestDist = math.huge
    local bestFood = nil

    -- Prefer cooked food: score = distance - quality bonus
    local qualityBonus = { lavish = 8, fine = 4, simple = 2, preserved = 1, raw = 0, forbidden = -20 }

    -- Search stockpile zones for food items
    local stockpiles = Zones.getByType('stockpile')
    for _, zone in ipairs(stockpiles) do
        for _, t in ipairs(zone.tileList) do
            local k = (t.depth or 0) * 100000000 + t.y * 10000 + t.x
            local item = zone.items[k]
            if item then
                local fq = foodQualityTable[item.itemId]
                if fq and (not allowFn or allowFn(t.x, t.y, t.depth or 0)) then
                    local dx, dy = px - t.x, py - t.y
                    local dd = (pd ~= (t.depth or 0)) and 1000 or 0
                    local dist = math.sqrt(dx * dx + dy * dy) + dd
                    local bonus = qualityBonus[fq.quality] or 0
                    local score = dist - bonus
                    if score < bestDist then
                        bestDist = score
                        bestFood = {
                            source = 'zone', zoneId = zone.id,
                            x = t.x, y = t.y, depth = t.depth or 0,
                            itemId = item.itemId,
                        }
                    end
                end
            end
        end
    end

    -- Also search ground items (unhauled food)
    for id, comps in ECS.query('pos', 'item') do
        local item = comps.item
        if not item.hauled then
            local ipos = comps.pos
            local fq = foodQualityTable[item.itemId]
            if fq and (not allowFn or allowFn(ipos.x, ipos.y, ipos.depth or 0)) then
                local dx, dy = px - ipos.x, py - ipos.y
                local dd = (pd ~= (ipos.depth or 0)) and 1000 or 0
                local dist = math.sqrt(dx * dx + dy * dy) + dd
                local bonus = qualityBonus[fq.quality] or 0
                local score = dist - bonus
                if score < bestDist then
                    bestDist = score
                    bestFood = {
                        source = 'ground', entityId = id,
                        x = ipos.x, y = ipos.y, depth = ipos.depth or 0,
                        itemId = item.itemId,
                    }
                end
            end
        end
    end

    return bestFood
end

---------------------------------------------------------------------------
-- Auto-haul — periodically create haul tasks for unhauled ground items
---------------------------------------------------------------------------

local haulCheckTimer = 0
local HAUL_CHECK_INTERVAL = 5.0

function Items.step(dt)
    haulCheckTimer = haulCheckTimer + dt
    if haulCheckTimer < HAUL_CHECK_INTERVAL then return end
    haulCheckTimer = 0

    local Jobs  = require('src.colonist.jobs')
    local Zones = require('src.world.zones')

    for id, comps in ECS.query('pos', 'item') do
        local item = comps.item
        if not item.hauled and (not item._haulTaskId or not Jobs.getTask(item._haulTaskId)) then
            item._haulTaskId = nil  -- clear stale reference
            local taskCreated = false

            -- Try storage building first (before zone fallback)
            local snetOk, SNet = pcall(require, 'src.logistics.storage_network')
            if snetOk and SNet.findNearestDest then
                local def = ItemDefs.get(item.itemId)
                local dest = SNet.findNearestDest(item.itemId, item.amount, def and def.category or item.category,
                    comps.pos.x, comps.pos.y)
                if dest then
                    local taskId = Jobs.createTask('haul', comps.pos.x, comps.pos.y, {
                        toX = dest.x, toY = dest.y, toDepth = comps.pos.depth or 0,
                        depth = comps.pos.depth or 0,
                        itemId = item.itemId, amount = item.amount,
                        quality = item.quality, material = item.material,
                        itemEntityId = id,
                        storageEntityId = dest.entityId,
                        storageSlotIdx = dest.slotIdx,
                    })
                    if taskId then
                        item._haulTaskId = taskId
                        taskCreated = true
                    end
                end
            end

            -- Fallback: find a stockpile zone that accepts this item
            if not taskCreated then
                local zone, sx, sy, sd = Zones.findStockpileFor(item.category, item.itemId, item.quality, item.material)
                if zone then
                    local taskId = Jobs.createTask('haul', comps.pos.x, comps.pos.y, {
                        toX = sx, toY = sy, toDepth = sd or 0,
                        depth = comps.pos.depth or 0,
                        itemId = item.itemId,
                        amount = item.amount,
                        quality = item.quality,
                        material = item.material,
                        itemEntityId = id,
                        zoneId = zone.id,
                    })
                    if taskId then
                        item._haulTaskId = taskId
                    end
                end
            end
        end
    end
end

return Items
