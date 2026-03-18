local StorageNetwork = {}
local ECS = require('src.ecs.ecs')
local Storage = require('src.building.storage')
local ItemDefs = require('src.world.item_defs')

local function getNetworkedStorages(x, y)
    local ok, Power = pcall(require, 'src.sim.power')
    if not ok then return {} end

    local gridRoot = Power.getGridRoot(x, y)
    if not gridRoot then return {} end

    local result = {}
    for eid, stor in pairs(ECS.getAll('storage') or {}) do
        local pos = ECS.get(eid, 'pos')
        if pos then
            local storRoot = Power.getGridRoot(pos.x, pos.y)
            if storRoot and storRoot == gridRoot then
                result[#result + 1] = { entityId = eid, storage = stor, pos = pos }
            end
        end
    end
    return result
end

function StorageNetwork.query(itemId, amount, fromX, fromY)
    local storages = getNetworkedStorages(fromX or 64, fromY or 64)
    local total = 0
    local sources = {}

    for _, s in ipairs(storages) do
        local stor = s.storage
        for i = 1, (stor.slots or 0) do
            local slot = stor.contents and stor.contents[i]
            if slot and slot.itemId == itemId then
                sources[#sources + 1] = {
                    entityId = s.entityId, slotIdx = i,
                    available = slot.amount,
                    x = s.pos.x, y = s.pos.y,
                }
                total = total + slot.amount
            end
        end
    end

    return total >= amount, sources
end

function StorageNetwork.withdraw(itemId, amount, fromX, fromY)
    local _, sources = StorageNetwork.query(itemId, amount, fromX, fromY)
    if #sources == 0 then return 0 end

    local fx, fy = fromX or 64, fromY or 64
    table.sort(sources, function(a, b)
        return (math.abs(a.x - fx) + math.abs(a.y - fy)) < (math.abs(b.x - fx) + math.abs(b.y - fy))
    end)

    local remaining = amount
    for _, src in ipairs(sources) do
        local taken = Storage.withdraw(src.entityId, itemId, remaining)
        remaining = remaining - taken
        if remaining <= 0 then break end
    end
    return amount - remaining
end

function StorageNetwork.getTotal(itemId, fromX, fromY)
    local storages = getNetworkedStorages(fromX or 64, fromY or 64)
    local total = 0
    for _, s in ipairs(storages) do
        total = total + Storage.getTotal(s.entityId, itemId)
    end
    return total
end

function StorageNetwork.findNearestSource(itemId, fromX, fromY)
    local _, sources = StorageNetwork.query(itemId, 1, fromX, fromY)
    if #sources == 0 then return nil end

    local best, bestDist = nil, math.huge
    for _, src in ipairs(sources) do
        local d = math.abs(src.x - fromX) + math.abs(src.y - fromY)
        if d < bestDist then best = src; bestDist = d end
    end
    return best
end

function StorageNetwork.findNearestDest(itemId, amount, category, fromX, fromY)
    local storages = getNetworkedStorages(fromX or 64, fromY or 64)

    local best, bestDist = nil, math.huge
    for _, s in ipairs(storages) do
        if Storage.acceptsItem(s.entityId, itemId, category) then
            local slotIdx = Storage.findSlot(s.entityId, itemId, amount)
            if slotIdx then
                local d = math.abs(s.pos.x - fromX) + math.abs(s.pos.y - fromY)
                if d < bestDist then
                    best = { entityId = s.entityId, slotIdx = slotIdx, x = s.pos.x, y = s.pos.y }
                    bestDist = d
                end
            end
        end
    end
    return best
end

return StorageNetwork
