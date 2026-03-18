-- storage.lua — Storage building entity system
-- Handles slot-based item storage for crate/locker/shelf/chest/cold_storage/lead_vault/bulk_silo.
-- Items stack in a slot only when itemId, quality, AND material all match.
-- Weight limit per slot is stor.maxSlotWeight (from StorageDefs).

local ECS        = require('src.ecs.ecs')
local StorageDefs = require('src.building.storage_defs')

local Storage = {}

-- Spawn a storage entity at (x, y, depth) for the given storageType (def key).
-- Returns the entity id, or nil on unknown type.
function Storage.place(x, y, depth, storageType)
    local def = StorageDefs.get(storageType)
    if not def then return nil end

    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth or 0 })
    ECS.set(id, 'storage', {
        storageType  = storageType,
        slots        = def.slots,
        maxSlotWeight = def.maxSlotWeight,
        keepsFrozen  = def.keepsFrozen or false,
        singleCategory = def.singleCategory or false,
        protection   = def.protection or {},
        -- slot entries: { itemId, quality, material, durability, amount, weight }
        -- indexed 1..slots; nil means empty
        contents     = {},
        -- category filter — nil means accept all; set to a category string for singleCategory silos
        filterCategory = nil,
    })
    ECS.set(id, 'building_ref', { type = 'storage', defId = storageType })
    return id
end

-- Store amount of itemId in slot slotIdx (1-based).
-- quality, material, durability are optional item attributes.
-- Returns true on success, false + reason string on failure.
function Storage.storeInSlot(storageId, slotIdx, itemId, amount, quality, material, durability)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return false, 'no storage component' end
    if slotIdx < 1 or slotIdx > stor.slots then return false, 'slot out of range' end

    local ItemDefs = require('src.world.item_defs')
    local def = ItemDefs.get(itemId)
    if not def then return false, 'unknown item' end

    local slotWeight = (def.weight or 1.0) * (amount or 1)
    local existing = stor.contents[slotIdx]
    if existing then
        -- Must match itemId, quality, AND material to stack
        if existing.itemId ~= itemId
            or existing.quality ~= quality
            or existing.material ~= material then
            return false, 'slot mismatch'
        end
        local newWeight = (def.weight or 1.0) * (existing.amount + (amount or 1))
        if newWeight > stor.maxSlotWeight then
            return false, 'slot weight exceeded'
        end
        existing.amount = existing.amount + (amount or 1)
    else
        if slotWeight > stor.maxSlotWeight then
            return false, 'slot weight exceeded'
        end
        stor.contents[slotIdx] = {
            itemId     = itemId,
            quality    = quality,
            material   = material,
            durability = durability or 100,
            amount     = amount or 1,
        }
    end
    return true
end

-- Find a usable slot for the given item.  Returns slot index, or nil if none found.
-- Prefers an existing matching slot (stacking); falls back to an empty slot.
function Storage.findSlot(storageId, itemId, amount, quality, material)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return nil end

    local ItemDefs = require('src.world.item_defs')
    local def = ItemDefs.get(itemId)
    if not def then return nil end

    local firstEmpty = nil

    for i = 1, stor.slots do
        local slot = stor.contents[i]
        if slot then
            -- Check for a stackable slot
            if slot.itemId == itemId
                and slot.quality == quality
                and slot.material == material then
                local newWeight = (def.weight or 1.0) * (slot.amount + (amount or 1))
                if newWeight <= stor.maxSlotWeight then
                    return i
                end
            end
        else
            if not firstEmpty then
                local needed = (def.weight or 1.0) * (amount or 1)
                if needed <= stor.maxSlotWeight then
                    firstEmpty = i
                end
            end
        end
    end

    return firstEmpty
end

-- Remove up to `amount` of itemId (matching quality and material) from storage.
-- Returns how many were actually removed.
function Storage.withdraw(storageId, itemId, amount, quality, material)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return 0 end

    local remaining = amount or 1
    for i = 1, stor.slots do
        if remaining <= 0 then break end
        local slot = stor.contents[i]
        if slot and slot.itemId == itemId
            and (not quality or slot.quality == quality)
            and (not material or slot.material == material) then
            local take = math.min(slot.amount, remaining)
            slot.amount = slot.amount - take
            remaining = remaining - take
            if slot.amount <= 0 then
                stor.contents[i] = nil
            end
        end
    end

    return (amount or 1) - remaining
end

-- Count total amount of itemId stored (across all slots, all qualities/materials).
function Storage.getTotal(storageId, itemId)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return 0 end

    local total = 0
    for i = 1, stor.slots do
        local slot = stor.contents[i]
        if slot and slot.itemId == itemId then
            total = total + slot.amount
        end
    end
    return total
end

-- Check whether this storage unit accepts an item.
-- category is the ItemDefs category string.
-- Returns true/false.
function Storage.acceptsItem(storageId, itemId, category)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return false end

    -- singleCategory silos: if filterCategory is set, must match
    if stor.singleCategory and stor.filterCategory then
        if stor.filterCategory ~= category then
            return false
        end
    end

    -- Check there is at least one usable slot
    local slot = Storage.findSlot(storageId, itemId, 1, nil, nil)
    return slot ~= nil
end

-- Drop all stored items as ground entities at the storage position.
-- Call this before destroying the storage entity.
function Storage.spawnContentsOnGround(storageId)
    local stor = ECS.get(storageId, 'storage')
    local pos  = ECS.get(storageId, 'pos')
    if not stor or not pos then return end

    local iok, Items = pcall(require, 'src.world.items')
    if not iok then return end

    local ItemDefs = require('src.world.item_defs')

    for i = 1, stor.slots do
        local slot = stor.contents[i]
        if slot and slot.amount > 0 then
            local def = ItemDefs.get(slot.itemId)
            if def then
                Items.spawn(pos.x, pos.y, slot.itemId, slot.amount,
                    def.category, pos.depth or 0, {
                        quality    = slot.quality,
                        material   = slot.material,
                        durability = slot.durability,
                    })
            end
            stor.contents[i] = nil
        end
    end
end

return Storage
