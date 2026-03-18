# Storage Buildings + Power-Grid Networking — Implementation Plan (Sub-Project 2 of 4)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add storage buildings (crate, locker, shelf, chest, cold storage, lead-lined vault, bulk silo) that organize items within stockpile zones, with a power-grid networked inventory system that lets colonists query and withdraw from any connected storage.

**Architecture:** New `storage` ECS component on storage building entities holds slot data. `storage_network.lua` queries all powered storage buildings on the same power grid using `Power.getGridRoot()` union-find. Build/craft recipes query the network instead of `GameState.spendResource()`. Hauling priority: zone buildings first, zone ground as overflow.

**Tech Stack:** Love2D 11.4, Lua 5.1/LuaJIT, sparse-set ECS, union-find power grid

**Spec:** `docs/superpowers/specs/2026-03-15-physical-items-design.md` (Sub-Project 2)

---

## Chunk 1: Storage Building Definitions and Component

### Task 1: Create storage building definitions

**Files:**
- Create: `src/building/storage_defs.lua`
- Modify: `src/building/building_defs_misc.lua` (or appropriate defs file)

- [ ] **Step 1: Read existing building definition patterns**

Read `src/building/building_defs_core.lua` or `building_defs_industry.lua` to understand the definition format: `{ name, cost, w, h, tile, entitySpawn, powerDraw, ... }`.

- [ ] **Step 2: Create storage_defs.lua**

```lua
local StorageDefs = {}

StorageDefs.BUILDINGS = {
    crate = {
        name = 'Crate',
        cost = { wood = 10 },
        w = 1, h = 1,
        slots = 4,
        maxSlotWeight = 200,
        protection = { weather = false, cold = false, heat = false, radiation = false, pressure = false },
        powerDraw = 0,
    },
    locker = {
        name = 'Locker',
        cost = { metal = 8 },
        w = 1, h = 1,
        slots = 8,
        maxSlotWeight = 200,
        protection = { weather = true, cold = true, heat = false, radiation = false, pressure = false },
        powerDraw = 0,
    },
    shelf = {
        name = 'Shelf',
        cost = { wood = 8, metal = 2 },
        w = 2, h = 1,
        slots = 6,
        maxSlotWeight = 150,
        protection = { weather = false, cold = false, heat = false, radiation = false, pressure = false },
        powerDraw = 0,
    },
    chest = {
        name = 'Chest',
        cost = { metal = 12, stone = 5 },
        w = 1, h = 1,
        slots = 12,
        maxSlotWeight = 250,
        protection = { weather = true, cold = true, heat = true, radiation = false, pressure = false },
        powerDraw = 0,
    },
    cold_storage = {
        name = 'Cold Storage Unit',
        cost = { steel = 8, components = 3, circuit = 1 },
        w = 2, h = 2,
        slots = 8,
        maxSlotWeight = 200,
        protection = { weather = true, cold = true, heat = true, radiation = false, pressure = false },
        powerDraw = 20,
        keepsFrozen = true,
    },
    lead_vault = {
        name = 'Lead-lined Vault',
        cost = { lead = 15, steel = 5 },
        w = 2, h = 2,
        slots = 6,
        maxSlotWeight = 300,
        protection = { weather = true, cold = true, heat = true, radiation = true, pressure = false },
        powerDraw = 0,
    },
    bulk_silo = {
        name = 'Bulk Silo',
        cost = { steel = 20, stone = 15, components = 5 },
        w = 3, h = 3,
        slots = 30,
        maxSlotWeight = 900,
        protection = { weather = true, cold = true, heat = true, radiation = false, pressure = false },
        powerDraw = 0,
        singleCategory = true,
    },
}

function StorageDefs.get(buildingType)
    return StorageDefs.BUILDINGS[buildingType]
end

return StorageDefs
```

- [ ] **Step 3: Register storage buildings in building defs**

Add entries to the appropriate `building_defs_*.lua` file for each storage building, following the existing pattern. Each needs: `name`, `cost`, `w`, `h`, `tile` (use MACHINE or FLOOR), `entitySpawn = 'storage'`.

- [ ] **Step 4: Commit**

---

### Task 2: Implement storage component and placement

**Files:**
- Create: `src/building/storage.lua`
- Modify: `src/building/building_placement.lua`
- Modify: `src/persistence/save_helpers.lua`

- [ ] **Step 1: Create storage.lua module**

```lua
local Storage = {}
local ECS = require('src.ecs.ecs')
local StorageDefs = require('src.building.storage_defs')
local ItemDefs = require('src.world.item_defs')

function Storage.place(x, y, depth, storageType)
    local def = StorageDefs.get(storageType)
    if not def then return nil, 'Unknown storage type' end

    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth or 0 })
    ECS.set(id, 'storage', {
        type = storageType,
        slots = {},            -- array of slot data or nil
        capacity = def.slots,
        maxSlotWeight = def.maxSlotWeight,
        filter = {},           -- category filter { raw_ore = true, ... }
        protection = def.protection,
        powered = def.powerDraw == 0,  -- unpowered buildings are always "powered"
        singleCategory = def.singleCategory or false,
    })
    return id
end

--- Store item in a specific slot. Returns true on success.
function Storage.storeInSlot(storageId, slotIdx, itemId, amount, quality, material, durability)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return false end
    if slotIdx < 1 or slotIdx > stor.capacity then return false end

    local slot = stor.slots[slotIdx]
    if slot then
        -- Check if stackable (same itemId + quality + material)
        if slot.itemId == itemId and slot.quality == quality and slot.material == material then
            local def = ItemDefs.get(itemId)
            local newWeight = (slot.amount + amount) * def.weight
            if newWeight <= stor.maxSlotWeight then
                slot.amount = slot.amount + amount
                return true
            end
        end
        return false  -- slot occupied with different item or full
    end

    -- Empty slot
    local def = ItemDefs.get(itemId)
    if amount * def.weight > stor.maxSlotWeight then return false end
    stor.slots[slotIdx] = {
        itemId = itemId,
        amount = amount,
        quality = quality or 'normal',
        material = material,
        durability = durability or 100,
    }
    return true
end

--- Find first available slot for an item. Returns slotIdx or nil.
function Storage.findSlot(storageId, itemId, amount, quality, material)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return nil end

    local def = ItemDefs.get(itemId)

    -- First try to stack with existing matching slots
    for i = 1, stor.capacity do
        local slot = stor.slots[i]
        if slot and slot.itemId == itemId and slot.quality == quality and slot.material == material then
            local newWeight = (slot.amount + amount) * def.weight
            if newWeight <= stor.maxSlotWeight then
                return i
            end
        end
    end

    -- Then find empty slot
    for i = 1, stor.capacity do
        if not stor.slots[i] then
            return i
        end
    end

    return nil  -- full
end

--- Withdraw amount of itemId from storage. Returns actual amount withdrawn.
function Storage.withdraw(storageId, itemId, amount, quality, material)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return 0 end

    local remaining = amount
    for i = 1, stor.capacity do
        local slot = stor.slots[i]
        if slot and slot.itemId == itemId then
            if (not quality or slot.quality == quality) and (not material or slot.material == material) then
                local take = math.min(remaining, slot.amount)
                slot.amount = slot.amount - take
                remaining = remaining - take
                if slot.amount <= 0 then
                    stor.slots[i] = nil
                end
                if remaining <= 0 then break end
            end
        end
    end
    return amount - remaining
end

--- Get total amount of an item across all slots.
function Storage.getTotal(storageId, itemId)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return 0 end

    local total = 0
    for i = 1, stor.capacity do
        local slot = stor.slots[i]
        if slot and slot.itemId == itemId then
            total = total + slot.amount
        end
    end
    return total
end

--- Check if storage accepts this item category.
function Storage.acceptsItem(storageId, itemId, category)
    local stor = ECS.get(storageId, 'storage')
    if not stor then return false end

    -- Single-category silos only accept one category
    if stor.singleCategory then
        -- Check if silo already has items — must match category
        for i = 1, stor.capacity do
            if stor.slots[i] then
                local existingDef = ItemDefs.get(stor.slots[i].itemId)
                if existingDef.category ~= category then
                    return false
                end
                break
            end
        end
    end

    -- Check filter
    if next(stor.filter) and not stor.filter[category] then
        return false
    end
    return true
end

--- Spawn all stored items on ground when building is destroyed.
function Storage.spawnContentsOnGround(storageId)
    local stor = ECS.get(storageId, 'storage')
    local pos = ECS.get(storageId, 'pos')
    if not stor or not pos then return end

    local Items = require('src.world.items')
    for i = 1, stor.capacity do
        local slot = stor.slots[i]
        if slot then
            Items.spawn(pos.x, pos.y, slot.itemId, slot.amount, nil, pos.depth or 0, {
                quality = slot.quality,
                material = slot.material,
                durability = slot.durability,
            })
            stor.slots[i] = nil
        end
    end
end

return Storage
```

- [ ] **Step 2: Add storage entity spawning to building_placement.lua**

In `Building.tryPlace()`, add a branch for `entitySpawn == 'storage'`:
```lua
elseif def.entitySpawn == 'storage' then
    local Storage = require('src.building.storage')
    local storId = Storage.place(x, y, depth, defId)
    if def.powerDraw and def.powerDraw > 0 then
        Power.addConsumer(storId, def.powerDraw, x, y)
    end
```

- [ ] **Step 3: Add 'storage' to KNOWN_COMPONENTS**

In `src/persistence/save_helpers.lua`, add `'storage'` to the KNOWN_COMPONENTS list.

- [ ] **Step 4: Wire storage building destruction**

Find where buildings are destroyed/deconstructed. Add a call to `Storage.spawnContentsOnGround(entityId)` before the entity is removed.

- [ ] **Step 5: Test — place a crate, verify storage component exists**

Run: `love .` — place a crate from build menu. Inspect entity to verify storage component with 4 empty slots.

- [ ] **Step 6: Commit**

---

## Chunk 2: Storage Network

### Task 3: Implement power-grid networked storage queries

**Files:**
- Create: `src/logistics/storage_network.lua`

- [ ] **Step 1: Create storage_network.lua**

```lua
local StorageNetwork = {}
local ECS = require('src.ecs.ecs')
local Storage = require('src.building.storage')
local ItemDefs = require('src.world.item_defs')

--- Get all storage buildings on the same power grid as position (x, y).
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

--- Check if enough of an item exists across networked storage.
--- Returns: hasEnough (bool), sources (table of {entityId, slotIdx, available})
function StorageNetwork.query(itemId, amount, fromX, fromY)
    local storages = getNetworkedStorages(fromX or 64, fromY or 64)
    local total = 0
    local sources = {}

    for _, s in ipairs(storages) do
        local stor = s.storage
        for i = 1, stor.capacity do
            local slot = stor.slots[i]
            if slot and slot.itemId == itemId then
                sources[#sources + 1] = {
                    entityId = s.entityId,
                    slotIdx = i,
                    available = slot.amount,
                    x = s.pos.x,
                    y = s.pos.y,
                }
                total = total + slot.amount
            end
        end
    end

    return total >= amount, sources
end

--- Withdraw items from nearest networked storage.
--- Returns actual amount withdrawn.
function StorageNetwork.withdraw(itemId, amount, fromX, fromY)
    local _, sources = StorageNetwork.query(itemId, amount, fromX, fromY)
    if #sources == 0 then return 0 end

    -- Sort by distance to requester
    local fx, fy = fromX or 64, fromY or 64
    table.sort(sources, function(a, b)
        local da = math.abs(a.x - fx) + math.abs(a.y - fy)
        local db = math.abs(b.x - fx) + math.abs(b.y - fy)
        return da < db
    end)

    local remaining = amount
    for _, src in ipairs(sources) do
        local taken = Storage.withdraw(src.entityId, itemId, remaining)
        remaining = remaining - taken
        if remaining <= 0 then break end
    end
    return amount - remaining
end

--- Get total of an item across all networked storage from position.
function StorageNetwork.getTotal(itemId, fromX, fromY)
    local storages = getNetworkedStorages(fromX or 64, fromY or 64)
    local total = 0
    for _, s in ipairs(storages) do
        total = total + Storage.getTotal(s.entityId, itemId)
    end
    return total
end

--- Find nearest storage building with the item.
function StorageNetwork.findNearestSource(itemId, fromX, fromY)
    local _, sources = StorageNetwork.query(itemId, 1, fromX, fromY)
    if #sources == 0 then return nil end

    local fx, fy = fromX, fromY
    local best, bestDist = nil, math.huge
    for _, src in ipairs(sources) do
        local d = math.abs(src.x - fx) + math.abs(src.y - fy)
        if d < bestDist then
            best = src
            bestDist = d
        end
    end
    return best
end

--- Find nearest storage building with space for an item.
function StorageNetwork.findNearestDest(itemId, amount, category, fromX, fromY)
    local storages = getNetworkedStorages(fromX or 64, fromY or 64)

    local fx, fy = fromX, fromY
    local best, bestDist = nil, math.huge
    for _, s in ipairs(storages) do
        if Storage.acceptsItem(s.entityId, itemId, category) then
            local slotIdx = Storage.findSlot(s.entityId, itemId, amount)
            if slotIdx then
                local d = math.abs(s.pos.x - fx) + math.abs(s.pos.y - fy)
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
```

- [ ] **Step 2: Test — query empty network returns false**

Run: `love .` — place a crate on a power grid. Query for iron_ore. Should return false, empty sources.

- [ ] **Step 3: Commit**

---

## Chunk 3: Zone + Storage Integration

### Task 4: Update hauling to prioritize storage buildings

**Files:**
- Modify: `src/world/items.lua` (auto-haul step function)
- Modify: `src/world/zones.lua` (add getAllStoredItems)

- [ ] **Step 1: Update Items.step() auto-haul to check storage buildings first**

In `Items.step()`, before calling `Zones.findStockpileFor()`, check if there's a storage building that accepts the item:

```lua
-- Try storage building first
local ok, SNet = pcall(require, 'src.logistics.storage_network')
if ok then
    local dest = SNet.findNearestDest(item.itemId, item.amount, def.category, comps.pos.x, comps.pos.y)
    if dest then
        -- Create haul task to storage building
        taskId = Jobs.createTask('haul', comps.pos.x, comps.pos.y, {
            toX = dest.x, toY = dest.y, toDepth = comps.pos.depth or 0,
            depth = comps.pos.depth or 0,
            itemId = item.itemId, amount = item.amount,
            quality = item.quality, material = item.material,
            itemEntityId = id,
            storageEntityId = dest.entityId,
            storageSlotIdx = dest.slotIdx,
        })
        item._haulTaskId = taskId
        -- Skip zone fallback
        goto continue
    end
end
-- Existing zone-based hauling as fallback
```

- [ ] **Step 2: Update executeHaul to handle storage building destination**

In `src/colonist/work_ai.lua`, find `executeHaul()`. Add a branch: if `task.data.storageEntityId` exists, store in the storage building instead of a zone:

```lua
if task.data.storageEntityId then
    local Storage = require('src.building.storage')
    Storage.storeInSlot(task.data.storageEntityId, task.data.storageSlotIdx,
        task.data.itemId, task.data.amount,
        task.data.quality, task.data.material, 100)
    Items.destroy(task.data.itemEntityId)
else
    -- Existing zone storage logic
    Zones.storeItem(...)
end
```

- [ ] **Step 3: Add Zones.getAllStoredItems()**

In `src/world/zones.lua`, add:

```lua
function Zones.getAllStoredItems()
    local result = {}
    for _, zone in pairs(zones) do
        if zone.type == 'stockpile' then
            for _, tile in ipairs(zone.tileList) do
                local k = tileKey(tile.x, tile.y, tile.depth)
                local item = zone.items[k]
                if item then
                    result[#result + 1] = {
                        itemId = item.itemId or item[1],
                        amount = item.amount or item[2] or 1,
                        quality = item.quality or item[3],
                        material = item.material or item[4],
                        zoneId = zone.id,
                        x = tile.x, y = tile.y, depth = tile.depth,
                    }
                end
            end
        end
    end
    return result
end
```

- [ ] **Step 4: Test — haul items to storage building instead of zone ground**

Place a crate in a stockpile zone. Mine rocks. Colonists should haul stone to the crate first, then overflow to zone ground.

- [ ] **Step 5: Commit**

---

### Task 5: Update build recipes to query storage network

**Files:**
- Modify: `src/colonist/jobs.lua` (designateBuild resource checking)

- [ ] **Step 1: Read jobs.designateBuild() resource checking**

Read `src/colonist/jobs.lua` lines 425-449. Resources are checked via `GameState.resources[resKey] >= amount` and spent via `GameState.spendResource()`.

- [ ] **Step 2: Add storage network fallback for resource checking**

After the existing `GameState.resources` check fails, try the storage network:

```lua
-- Existing check:
if (GameState.resources[resKey] or 0) < amount then
    -- Try storage network
    local ok, SNet = pcall(require, 'src.logistics.storage_network')
    if ok then
        local hasEnough = SNet.query(res, amount, x, y)
        if not hasEnough then
            -- Refund already-spent resources and fail
            ...
            return nil
        end
        -- Withdraw from storage
        SNet.withdraw(res, amount, x, y)
        spent[res] = amount
    else
        -- No storage network, original failure
        ...
        return nil
    end
else
    -- Original path: spend from GameState counter
    GameState.spendResource(res, amount)
    spent[res] = amount
end
```

- [ ] **Step 3: Test — build a wall using resources from storage building**

Place a crate, put cut_stone in it (via debug or hauling). Designate a wall build that costs cut_stone. Verify it deducts from the storage building.

- [ ] **Step 4: Commit**

---

## Chunk 4: Colony Wealth + Integration

### Task 6: Add storage building items to colony wealth

**Files:**
- Modify: `src/game_state.lua`

- [ ] **Step 1: Update getColonyWealth() to include storage building contents**

In `GameState.getColonyWealth()`, add after the ground item summing:

```lua
-- Sum storage building contents
for eid, stor in pairs(ECSmod.getAll('storage') or {}) do
    for i = 1, (stor.capacity or 0) do
        local slot = stor.slots and stor.slots[i]
        if slot then
            local def = ItemDefs.get(slot.itemId)
            local qData = Quality.get(slot.quality or 'normal')
            local valueMult = qData and qData.valueMult or 1.0
            wealth = wealth + (def.weight * (slot.amount or 1) * valueMult)
        end
    end
end
```

- [ ] **Step 2: Commit**

---

### Task 7: Integration test

- [ ] **Step 1: Test full flow — mine → haul to storage building → build from storage**

1. Start game, place crate in stockpile zone
2. Mine rocks → colonists haul stone to crate
3. Verify crate slots fill up
4. Designate wall build → stone deducted from crate
5. Verify crate slot amounts decrease

- [ ] **Step 2: Test storage building destruction drops items**

Place crate with items. Deconstruct crate. Items should appear on ground.

- [ ] **Step 3: Test power grid networking**

Place two crates on same power grid. Put stone in crate A. Build wall near crate B. Verify system finds stone in crate A.

- [ ] **Step 4: Test unpowered storage**

Place crate NOT on power grid. Put items in it. Verify StorageNetwork.query does NOT find them. But manual hauling to/from it still works.

- [ ] **Step 5: Fix any issues found**
