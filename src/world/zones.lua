-- zones.lua - Zone designation system
-- Players draw layered zones on the tilemap: stockpiles, dumping, and allowed areas.
-- Stockpiles can filter by category, item, quality, and material.

local Zones = {}

local zones = {}          -- { [zoneId] = zone }
local nextZoneId = 1
local tileToZones = {}    -- { [tileKey] = { [zoneType] = zoneId } }

local DISPLAY_ORDER = { 'stockpile', 'dumping', 'restricted' }

local function tileKey(x, y, depth)
    return (depth or 0) * 100000000 + y * 10000 + x
end

local function getTileBucket(k, create)
    local bucket = tileToZones[k]
    if not bucket and create then
        bucket = {}
        tileToZones[k] = bucket
    end
    return bucket
end

local function unlinkTile(k, zoneType, zoneId)
    local bucket = tileToZones[k]
    if not bucket then return end
    if bucket[zoneType] == zoneId then
        bucket[zoneType] = nil
    end
    if next(bucket) == nil then
        tileToZones[k] = nil
    end
end

local function linkTile(k, zoneType, zoneId)
    local bucket = getTileBucket(k, true)
    bucket[zoneType] = zoneId
end

local function removeTileFromList(zone, x, y, depth)
    local d = depth or 0
    for i = #zone.tileList, 1, -1 do
        local tile = zone.tileList[i]
        if tile.x == x and tile.y == y and (tile.depth or 0) == d then
            table.remove(zone.tileList, i)
            break
        end
    end
end

local function deleteIfEmpty(zoneId)
    local zone = zones[zoneId]
    if zone and next(zone.tiles) == nil then
        zones[zoneId] = nil
    end
end

local function removeTileInternal(zoneId, x, y, depth)
    local zone = zones[zoneId]
    if not zone then return end
    local k = tileKey(x, y, depth)
    zone.tiles[k] = nil
    zone.items[k] = nil
    unlinkTile(k, zone.type, zoneId)
    removeTileFromList(zone, x, y, depth)
    deleteIfEmpty(zoneId)
end

function Zones.reset()
    zones = {}
    nextZoneId = 1
    tileToZones = {}
end

Zones.TYPES = {
    stockpile  = { name = 'Stockpile',    color = { 0.2, 0.5, 0.2, 0.25 } },
    dumping    = { name = 'Dumping',      color = { 0.5, 0.3, 0.1, 0.25 } },
    restricted = { name = 'Allowed Area', color = { 0.15, 0.45, 0.75, 0.20 } },
}

Zones.CATEGORIES = {
    'raw', 'material', 'advanced', 'food', 'medicine', 'drug', 'equipment', 'power',
    'corpse', 'organ', 'prosthetic', 'bionic', 'throwable', 'ammo', 'eldritch',
}

Zones.PRIORITY_NAMES = {
    [1] = 'Critical', [2] = 'Urgent', [3] = 'High',
    [4] = 'Above Normal', [5] = 'Normal', [6] = 'Below Normal',
    [7] = 'Low', [8] = 'Very Low', [9] = 'Lowest',
}

function Zones.create(zoneType, tiles, filter)
    local def = Zones.TYPES[zoneType]
    if not def then return nil end

    local id = nextZoneId
    nextZoneId = nextZoneId + 1

    local zone = {
        id = id,
        type = zoneType,
        tiles = {},
        tileList = {},
        filter = filter or {},
        itemFilter = nil,
        qualityMin = nil,
        qualityMax = nil,
        materialFilter = nil,
        items = {},
        priority = 5,
    }

    zones[id] = zone

    for _, tile in ipairs(tiles or {}) do
        Zones.addTile(id, tile.x, tile.y, tile.depth)
    end

    return id
end

function Zones.delete(zoneId)
    local zone = zones[zoneId]
    if not zone then return end
    for k in pairs(zone.tiles) do
        unlinkTile(k, zone.type, zoneId)
    end
    zones[zoneId] = nil
end

function Zones.addTile(zoneId, x, y, depth)
    local zone = zones[zoneId]
    if not zone then return end

    local d = depth or 0
    local k = tileKey(x, y, d)
    local bucket = getTileBucket(k, true)
    local existingId = bucket[zone.type]
    if existingId and existingId ~= zoneId then
        removeTileInternal(existingId, x, y, d)
    end

    if zone.tiles[k] then
        return
    end

    zone.tiles[k] = true
    zone.tileList[#zone.tileList + 1] = { x = x, y = y, depth = d }
    linkTile(k, zone.type, zoneId)
end

function Zones.removeTile(zoneId, x, y, depth)
    removeTileInternal(zoneId, x, y, depth)
end

function Zones.getZonesAt(x, y, depth)
    local bucket = tileToZones[tileKey(x, y, depth)]
    if not bucket then return nil end

    local result = {}
    for zoneType, zoneId in pairs(bucket) do
        result[zoneType] = zones[zoneId]
    end
    return result
end

function Zones.getZoneAt(x, y, depth, zoneType)
    local bucket = tileToZones[tileKey(x, y, depth)]
    if not bucket then return nil end
    if zoneType then
        local zoneId = bucket[zoneType]
        return zoneId and zones[zoneId] or nil
    end
    for _, orderedType in ipairs(DISPLAY_ORDER) do
        local zoneId = bucket[orderedType]
        if zoneId and zones[zoneId] then
            return zones[zoneId]
        end
    end
    return nil
end

function Zones.getAll()
    return zones
end

function Zones.getByType(zoneType)
    local result = {}
    for _, zone in pairs(zones) do
        if zone.type == zoneType then
            result[#result + 1] = zone
        end
    end
    return result
end

function Zones.getPriority(zoneId)
    local zone = zones[zoneId]
    return zone and zone.priority or 5
end

function Zones.setPriority(zoneId, priority)
    local zone = zones[zoneId]
    if zone then
        zone.priority = math.max(1, math.min(9, priority))
    end
end

function Zones.cyclePriority(zoneId, delta)
    local zone = zones[zoneId]
    if not zone then return end
    Zones.setPriority(zoneId, (zone.priority or 5) + (delta or 0))
end

function Zones.toggleCategory(zoneId, category)
    local zone = zones[zoneId]
    if not zone or zone.type ~= 'stockpile' then return end
    zone.filter[category] = not zone.filter[category] and true or nil
end

function Zones.acceptsItem(zoneId, itemCategory, itemId, quality, material)
    local zone = zones[zoneId]
    if not zone or zone.type ~= 'stockpile' then return false end

    if next(zone.filter) ~= nil and not zone.filter[itemCategory] then
        return false
    end

    if zone.itemFilter and itemId and not zone.itemFilter[itemId] then
        return false
    end

    if quality and (zone.qualityMin or zone.qualityMax) then
        local ok, Quality = pcall(require, 'src.world.quality')
        if ok and Quality.getRank then
            local rank = Quality.getRank(quality)
            if zone.qualityMin and rank < Quality.getRank(zone.qualityMin) then
                return false
            end
            if zone.qualityMax and rank > Quality.getRank(zone.qualityMax) then
                return false
            end
        end
    end

    if zone.materialFilter and material and not zone.materialFilter[material] then
        return false
    end

    return true
end

function Zones.setItemFilter(zoneId, itemFilter)
    local zone = zones[zoneId]
    if zone then zone.itemFilter = itemFilter end
end

function Zones.setSingleItemFilter(zoneId, itemId)
    local zone = zones[zoneId]
    if not zone then return end
    zone.itemFilter = itemId and { [itemId] = true } or nil
end

function Zones.setQualityRange(zoneId, minQuality, maxQuality)
    local zone = zones[zoneId]
    if not zone then return end
    zone.qualityMin = minQuality
    zone.qualityMax = maxQuality
end

function Zones.setMaterialFilter(zoneId, materialFilter)
    local zone = zones[zoneId]
    if zone then zone.materialFilter = materialFilter end
end

function Zones.setSingleMaterialFilter(zoneId, materialId)
    local zone = zones[zoneId]
    if not zone then return end
    zone.materialFilter = materialId and { [materialId] = true } or nil
end

function Zones.clearFilters(zoneId)
    local zone = zones[zoneId]
    if not zone or zone.type ~= 'stockpile' then return end
    zone.filter = {}
    zone.itemFilter = nil
    zone.qualityMin = nil
    zone.qualityMax = nil
    zone.materialFilter = nil
end

function Zones.getFilters(zoneId)
    local zone = zones[zoneId]
    if not zone then return nil end
    return {
        categories = zone.filter,
        items = zone.itemFilter,
        qualityMin = zone.qualityMin,
        qualityMax = zone.qualityMax,
        materials = zone.materialFilter,
    }
end

function Zones.findStockpileFor(itemCategory, itemId, quality, material)
    local candidates = {}
    for _, zone in pairs(zones) do
        if zone.type == 'stockpile' and Zones.acceptsItem(zone.id, itemCategory, itemId, quality, material) then
            candidates[#candidates + 1] = zone
        end
    end
    table.sort(candidates, function(a, b)
        return (a.priority or 5) < (b.priority or 5)
    end)

    for _, zone in ipairs(candidates) do
        for _, tile in ipairs(zone.tileList) do
            local k = tileKey(tile.x, tile.y, tile.depth)
            if not zone.items[k] then
                return zone, tile.x, tile.y, tile.depth or 0
            end
        end
    end

    return nil
end

function Zones.storeItem(zoneId, x, y, itemId, amount, depth, quality, material)
    local zone = zones[zoneId]
    if not zone then return false end
    local k = tileKey(x, y, depth)
    zone.items[k] = {
        itemId = itemId,
        amount = amount,
        quality = quality,
        material = material,
    }
    return true
end

function Zones.takeItem(zoneId, x, y, depth)
    local zone = zones[zoneId]
    if not zone then return nil end
    local k = tileKey(x, y, depth)
    local item = zone.items[k]
    zone.items[k] = nil
    return item
end

function Zones.getItemAt(zoneId, x, y, depth)
    local zone = zones[zoneId]
    if not zone then return nil end
    return zone.items[tileKey(x, y, depth)]
end

function Zones.countItems(zoneId)
    local zone = zones[zoneId]
    if not zone then return 0 end
    local count = 0
    for _ in pairs(zone.items) do
        count = count + 1
    end
    return count
end

function Zones.countTiles(zoneId)
    local zone = zones[zoneId]
    if not zone then return 0 end
    local count = 0
    for _ in pairs(zone.tiles) do
        count = count + 1
    end
    return count
end

function Zones.countFree(zoneId)
    return math.max(0, Zones.countTiles(zoneId) - Zones.countItems(zoneId))
end

function Zones.getAllStoredItems()
    local result = {}
    for _, zone in pairs(zones) do
        if zone.type == 'stockpile' then
            for _, tile in ipairs(zone.tileList) do
                local k = tileKey(tile.x, tile.y, tile.depth)
                local item = zone.items[k]
                if item then
                    result[#result + 1] = {
                        itemId   = item.itemId   or item[1],
                        amount   = item.amount   or item[2] or 1,
                        quality  = item.quality  or item[3],
                        material = item.material or item[4],
                        zoneId   = zone.id,
                        x = tile.x, y = tile.y, depth = tile.depth,
                    }
                end
            end
        end
    end
    return result
end

function Zones.hasRestrictedZones(depth)
    for _, zone in pairs(zones) do
        if zone.type == 'restricted' then
            if depth == nil then
                return true
            end
            for _, tile in ipairs(zone.tileList) do
                if (tile.depth or 0) == depth then
                    return true
                end
            end
        end
    end
    return false
end

function Zones.isTileAllowed(x, y, depth)
    local d = depth or 0
    if not Zones.hasRestrictedZones(d) then
        return true
    end
    return Zones.getZoneAt(x, y, d, 'restricted') ~= nil
end

function Zones.findNearestRestrictedTile(x, y, depth)
    local bestTile, bestDist = nil, math.huge
    local d = depth or 0

    for _, zone in pairs(zones) do
        if zone.type == 'restricted' then
            for _, tile in ipairs(zone.tileList) do
                if (tile.depth or 0) == d then
                    local dx = tile.x - x
                    local dy = tile.y - y
                    local dist = dx * dx + dy * dy
                    if dist < bestDist then
                        bestDist = dist
                        bestTile = { x = tile.x, y = tile.y, depth = d }
                    end
                end
            end
        end
    end

    return bestTile
end

function Zones.getState()
    local out = {}
    for _, zone in pairs(zones) do
        out[#out + 1] = {
            id = zone.id,
            type = zone.type,
            tileList = zone.tileList,
            filter = zone.filter,
            itemFilter = zone.itemFilter,
            qualityMin = zone.qualityMin,
            qualityMax = zone.qualityMax,
            materialFilter = zone.materialFilter,
            items = zone.items,
            priority = zone.priority,
        }
    end
    return out
end

function Zones.loadState(saved)
    Zones.reset()
    if not saved then return end

    for _, savedZone in ipairs(saved) do
        local id = savedZone.id or nextZoneId
        if id >= nextZoneId then
            nextZoneId = id + 1
        end

        local zone = {
            id = id,
            type = savedZone.type,
            tiles = {},
            tileList = savedZone.tileList or {},
            filter = savedZone.filter or {},
            itemFilter = savedZone.itemFilter,
            qualityMin = savedZone.qualityMin,
            qualityMax = savedZone.qualityMax,
            materialFilter = savedZone.materialFilter,
            items = savedZone.items or {},
            priority = savedZone.priority or 5,
        }

        zones[id] = zone

        for _, tile in ipairs(zone.tileList) do
            local d = tile.depth or 0
            local k = tileKey(tile.x, tile.y, d)
            zone.tiles[k] = true
            linkTile(k, zone.type, id)
        end
    end
end

return Zones
