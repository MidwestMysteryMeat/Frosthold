-- conveyors.lua - Conveyor belt transport network
-- Items placed on belts move 1 tile/s in the belt's direction.
-- Each belt tile holds at most 1 item. Belts freeze below -20C.
-- Splitters alternate output between two downstream belts.
-- Belt items are lightweight tables, not ECS entities.

local Tilemap = require('src.world.tilemap')

local Conveyors = {}

---------------------------------------------------------------------------
-- Direction constants
---------------------------------------------------------------------------

local DIR = {
    N = { dx = 0, dy = -1 },
    S = { dx = 0, dy = 1 },
    E = { dx = 1, dy = 0 },
    W = { dx = -1, dy = 0 },
}

Conveyors.DIR = DIR

local DIR_NAME = {}
for name, d in pairs(DIR) do
    DIR_NAME[d.dx .. ',' .. d.dy] = name
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local belts = {}
local beltOrder = {}
local orderDirty = true

local function tileKey(x, y)
    return y * 10000 + x
end

local function keyToXY(k)
    local y = math.floor(k / 10000)
    local x = k - y * 10000
    return x, y
end

Conveyors.tileKey = tileKey
Conveyors.keyToXY = keyToXY

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Conveyors.init()
    belts = {}
    beltOrder = {}
    orderDirty = true
end

---------------------------------------------------------------------------
-- Belt placement / removal
---------------------------------------------------------------------------

function Conveyors.isOccupied(x, y)
    return belts[tileKey(x, y)] ~= nil
end

function Conveyors.place(x, y, direction, speed)
    if not Tilemap.inBounds(x, y) then return false end
    if not DIR[direction] then return false end

    local k = tileKey(x, y)
    if belts[k] then return false end

    belts[k] = {
        dir = direction,
        item = nil,
        frozen = false,
        speed = speed,
    }
    orderDirty = true
    return true
end

function Conveyors.placeSplitter(x, y, direction, speed)
    if not Tilemap.inBounds(x, y) then return false end
    if not DIR[direction] then return false end

    local k = tileKey(x, y)
    if belts[k] then return false end

    belts[k] = {
        dir = direction,
        item = nil,
        frozen = false,
        splitter = { lastOutput = 1 },
        speed = speed,
    }
    orderDirty = true
    return true
end

function Conveyors.remove(x, y)
    local k = tileKey(x, y)
    local belt = belts[k]
    if not belt then return false end
    if belt.item then
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn then
            Items.spawn(x, y, belt.item.id, belt.item.amount or 1, nil, 0, {
                quality    = belt.item.quality,
                material   = belt.item.material,
                durability = belt.item.durability,
            })
        end
    end
    belts[k] = nil
    orderDirty = true
    return true
end

---------------------------------------------------------------------------
-- Item insertion
---------------------------------------------------------------------------

function Conveyors.insertItem(x, y, itemId, itemData)
    local belt = belts[tileKey(x, y)]
    if not belt or belt.item or belt.frozen then return false end
    belt.item = {
        id         = itemId,
        progress   = 0,
        quality    = itemData and itemData.quality or 'normal',
        material   = itemData and itemData.material or nil,
        durability = itemData and itemData.durability or 100,
        amount     = itemData and itemData.amount or 1,
    }
    return true
end

function Conveyors.extractItem(x, y)
    local belt = belts[tileKey(x, y)]
    if not belt or not belt.item then return nil end
    local item = belt.item
    belt.item = nil
    return item  -- returns full table: {id, progress, quality, material, durability, amount}
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Conveyors.getBelt(x, y)
    return belts[tileKey(x, y)]
end

function Conveyors.hasItem(x, y)
    local belt = belts[tileKey(x, y)]
    return belt and belt.item ~= nil
end

function Conveyors.getItemId(x, y)
    local belt = belts[tileKey(x, y)]
    return belt and belt.item and belt.item.id or nil
end

function Conveyors.isBelt(x, y)
    return belts[tileKey(x, y)] ~= nil
end

function Conveyors.isFrozen(x, y)
    local belt = belts[tileKey(x, y)]
    return belt and belt.frozen
end

function Conveyors.allBelts()
    return belts
end

---------------------------------------------------------------------------
-- Splitter helpers
---------------------------------------------------------------------------

local SPLIT_OFFSETS = {
    N = { { dx = -1, dy = 0 }, { dx = 1, dy = 0 } },
    S = { { dx = -1, dy = 0 }, { dx = 1, dy = 0 } },
    E = { { dx = 0, dy = -1 }, { dx = 0, dy = 1 } },
    W = { { dx = 0, dy = -1 }, { dx = 0, dy = 1 } },
}

local function getMoveTargets(belt, x, y)
    if belt.splitter then
        local offsets = SPLIT_OFFSETS[belt.dir]
        local sp = belt.splitter
        local targets = {}
        for attempt = 1, 2 do
            local idx = ((sp.lastOutput - 1 + attempt - 1) % 2) + 1
            local off = offsets[idx]
            targets[#targets + 1] = {
                key = tileKey(x + off.dx, y + off.dy),
                nextLastOutput = (idx % 2) + 1,
            }
        end
        local d = DIR[belt.dir]
        targets[#targets + 1] = {
            key = tileKey(x + d.dx, y + d.dy),
            nextLastOutput = (sp.lastOutput % 2) + 1,
        }
        return targets
    end

    local d = DIR[belt.dir]
    return { { key = tileKey(x + d.dx, y + d.dy) } }
end

---------------------------------------------------------------------------
-- Simulation step
---------------------------------------------------------------------------

local BELT_SPEED = 1.0
local FREEZE_THRESHOLD = -20

function Conveyors.step(dt)
    if orderDirty then
        beltOrder = {}
        for k in pairs(belts) do
            beltOrder[#beltOrder + 1] = k
        end
        table.sort(beltOrder)
        orderDirty = false
    end

    for _, k in ipairs(beltOrder) do
        local belt = belts[k]
        local x, y = keyToXY(k)
        belt.frozen = Tilemap.getTemp(x, y) < FREEZE_THRESHOLD
    end

    for _, k in ipairs(beltOrder) do
        local belt = belts[k]
        if belt and not belt.frozen and belt.item then
            belt.item.progress = belt.item.progress + (belt.speed or BELT_SPEED) * dt
        end
    end

    local resolving = {}
    local resolved = {}

    local function tryMove(k)
        if resolved[k] ~= nil then return resolved[k] end
        local belt = belts[k]
        if not belt or belt.frozen or not belt.item or belt.item.progress < 1.0 then
            resolved[k] = false
            return false
        end
        if resolving[k] then
            return false
        end

        resolving[k] = true
        local x, y = keyToXY(k)
        local moved = false

        for _, candidate in ipairs(getMoveTargets(belt, x, y)) do
            local target = belts[candidate.key]
            if target and not target.frozen then
                local targetClear = not target.item
                if not targetClear and target.item.progress >= 1.0 then
                    targetClear = tryMove(candidate.key)
                end
                if targetClear and not target.item then
                    target.item = {
                        id         = belt.item.id,
                        progress   = 0,
                        quality    = belt.item.quality,
                        material   = belt.item.material,
                        durability = belt.item.durability,
                        amount     = belt.item.amount,
                    }
                    belt.item = nil
                    if belt.splitter and candidate.nextLastOutput then
                        belt.splitter.lastOutput = candidate.nextLastOutput
                    end
                    moved = true
                    break
                end
            end
        end

        if not moved and belt.item then
            belt.item.progress = 1.0
            if not belt.splitter then
                local d = DIR[belt.dir]
                local nx, ny = x + d.dx, y + d.dy
                local nk = tileKey(nx, ny)
                if not belts[nk] then
                    local iok, Items = pcall(require, 'src.world.items')
                    if iok and Items.spawn then
                        Items.spawn(nx, ny, belt.item.id, belt.item.amount or 1, nil, 0, {
                            quality    = belt.item.quality,
                            material   = belt.item.material,
                            durability = belt.item.durability,
                        })
                        belt.item = nil
                        moved = true
                    end
                end
            end
        end

        resolving[k] = nil
        resolved[k] = moved
        return moved
    end

    for _, k in ipairs(beltOrder) do
        tryMove(k)
    end
end

---------------------------------------------------------------------------
-- Stats
---------------------------------------------------------------------------

function Conveyors.count()
    local n = 0
    for _ in pairs(belts) do n = n + 1 end
    return n
end

function Conveyors.countFrozen()
    local n = 0
    for _, belt in pairs(belts) do
        if belt.frozen then n = n + 1 end
    end
    return n
end

function Conveyors.countItems()
    local n = 0
    for _, belt in pairs(belts) do
        if belt.item then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Save / Load
---------------------------------------------------------------------------

function Conveyors.getState()
    local savedBelts = {}
    for k, belt in pairs(belts) do
        local entry = { dir = belt.dir }
        if belt.item then
            entry.item = {
                id         = belt.item.id,
                progress   = belt.item.progress,
                quality    = belt.item.quality,
                material   = belt.item.material,
                durability = belt.item.durability,
                amount     = belt.item.amount,
            }
        end
        if belt.splitter then
            entry.splitter = { lastOutput = belt.splitter.lastOutput }
        end
        if belt.speed then
            entry.speed = belt.speed
        end
        savedBelts[k] = entry
    end
    return { belts = savedBelts }
end

function Conveyors.loadState(saved)
    if not saved then return end
    belts = {}
    for k, entry in pairs(saved.belts or {}) do
        belts[k] = {
            dir = entry.dir,
            item = entry.item and {
                id         = entry.item.id,
                progress   = entry.item.progress,
                quality    = entry.item.quality,
                material   = entry.item.material,
                durability = entry.item.durability,
                amount     = entry.item.amount,
            } or nil,
            frozen = false,
            splitter = entry.splitter and { lastOutput = entry.splitter.lastOutput } or nil,
            speed = entry.speed,
        }
    end
    beltOrder = {}
    orderDirty = true
end

return Conveyors
