# Physical Item Entities — Implementation Plan (Sub-Project 1 of 4)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace abstract GameState resource counters with physical item ECS entities that drop on the ground, get hauled, and stack in storage — making resources visible and tangible.

**Architecture:** New `item_defs.lua` defines all item types with weights, categories, and immunities. `items.lua` removes the 10-minute decay timer and gains weight/durability fields. `GameState.addResource()` and `spendResource()` become compatibility shims that delegate to `Items.spawn()` and zone/storage queries during the migration period. Mining in `work_ai.lua` and `miners.lua` switches to spawning physical items. Conveyor belt item tables gain quality/material/durability fields. Colonist carry capacity becomes weight-based.

**Tech Stack:** Love2D 11.4, Lua 5.1/LuaJIT, sparse-set ECS at `src/ecs/ecs.lua`

**Spec:** `docs/superpowers/specs/2026-03-15-physical-items-design.md`

---

## Chunk 1: Item Definitions + Item Entity Overhaul

### Task 1: Create item definitions table

**Files:**
- Create: `src/world/item_defs.lua`

- [ ] **Step 1: Read existing item categories**

Read `src/world/items.lua` (lines 10-23) for the current item component fields. Read `src/game_state.lua` (lines 46-182) for all resource names that need definitions.

- [ ] **Step 2: Create item_defs.lua with all item definitions**

```lua
local ItemDefs = {}

-- Category constants
ItemDefs.CATEGORIES = {
    'raw_ore', 'raw_stone', 'raw_wood', 'raw_ice',
    'ingot', 'plank', 'cut_stone',
    'food_raw', 'food_cooked',
    'component', 'fuel', 'medicine', 'thermal_core',
    'weapon', 'armor', 'clothing', 'accessory',
    'liquid', 'hazmat',
    'corpse', 'organ', 'prosthetic',
    'drug', 'ordnance', 'ammo',
    'hide', 'eldritch',
}

-- Item definition format:
-- { category, weight, immune, maxStack (computed from weight but capped here) }
-- immune = true means never takes environmental decay damage
ItemDefs.ITEMS = {
    -- Raw materials (immune to normal environmental decay)
    iron_ore     = { category = 'raw_ore',   weight = 3.0, immune = true },
    lead_ore     = { category = 'raw_ore',   weight = 3.0, immune = true },
    copper_ore   = { category = 'raw_ore',   weight = 3.0, immune = true },
    uranium_ore  = { category = 'hazmat',    weight = 4.0, immune = true, radioactive = true },
    stone_chunk  = { category = 'raw_stone', weight = 4.0, immune = true },
    logs         = { category = 'raw_wood',  weight = 5.0, immune = false },
    ice_block    = { category = 'raw_ice',   weight = 2.5, immune = true },

    -- Processed materials
    iron_ingot   = { category = 'ingot', weight = 3.5, immune = true },
    lead_ingot   = { category = 'ingot', weight = 3.5, immune = true },
    copper_ingot = { category = 'ingot', weight = 3.5, immune = true },
    steel        = { category = 'ingot', weight = 3.5, immune = true },
    enriched_uranium  = { category = 'hazmat', weight = 4.0, immune = true, radioactive = true },
    depleted_uranium  = { category = 'ingot',  weight = 4.0, immune = true },
    planks       = { category = 'plank',     weight = 2.0, immune = false },
    cut_stone    = { category = 'cut_stone', weight = 3.5, immune = true },
    charcoal     = { category = 'fuel',      weight = 1.5, immune = false },
    cloth        = { category = 'component', weight = 0.5, immune = false },
    glass        = { category = 'component', weight = 1.0, immune = true },
    insulation   = { category = 'component', weight = 0.5, immune = false },
    pipe         = { category = 'component', weight = 1.5, immune = true },
    circuit      = { category = 'component', weight = 0.5, immune = false },
    raw_hide     = { category = 'hide',      weight = 1.5, immune = false },

    -- Food
    food         = { category = 'food_raw',    weight = 1.0, immune = false },
    cooked_meal  = { category = 'food_cooked', weight = 1.5, immune = false },
    berries      = { category = 'food_raw',    weight = 0.5, immune = false },
    mushrooms    = { category = 'food_raw',    weight = 0.5, immune = false },
    raw_meat     = { category = 'food_raw',    weight = 1.5, immune = false },

    -- Medicine
    bandage      = { category = 'medicine', weight = 0.3, immune = false },
    medicine     = { category = 'medicine', weight = 0.3, immune = false },
    advanced_medicine = { category = 'medicine', weight = 0.3, immune = false },
    revivify_serum    = { category = 'medicine', weight = 0.5, immune = false },
    medicinal_herb    = { category = 'medicine', weight = 0.3, immune = false },

    -- Core resources
    thermalCores = { category = 'thermal_core', weight = 5.0, immune = true },
    water        = { category = 'liquid',        weight = 2.0, immune = false },
    fuel         = { category = 'fuel',          weight = 2.0, immune = false },
    components   = { category = 'component',     weight = 0.5, immune = false },
    hide         = { category = 'hide',          weight = 1.5, immune = false },

    -- Corpses & organs
    corpse_creature = { category = 'corpse', weight = 15.0, immune = false },
    corpse_human    = { category = 'corpse', weight = 20.0, immune = false },
    human_meat      = { category = 'food_raw', weight = 2.0, immune = false },
    human_leather   = { category = 'hide',     weight = 1.5, immune = false },
    organ_heart  = { category = 'organ', weight = 0.5, immune = false },
    organ_lung   = { category = 'organ', weight = 0.5, immune = false },
    organ_kidney = { category = 'organ', weight = 0.3, immune = false },
    organ_liver  = { category = 'organ', weight = 0.5, immune = false },
    organ_eye    = { category = 'organ', weight = 0.1, immune = false },

    -- Prosthetics
    peg_leg        = { category = 'prosthetic', weight = 2.0, immune = true },
    wooden_arm     = { category = 'prosthetic', weight = 1.5, immune = false },
    prosthetic_leg = { category = 'prosthetic', weight = 3.0, immune = true },
    prosthetic_arm = { category = 'prosthetic', weight = 2.5, immune = true },
    bionic_leg     = { category = 'prosthetic', weight = 4.0, immune = true },
    bionic_arm     = { category = 'prosthetic', weight = 3.5, immune = true },
    bionic_eye     = { category = 'prosthetic', weight = 0.5, immune = true },

    -- Eldritch materials
    eldritch_ichor = { category = 'eldritch', weight = 1.0, immune = false },
    raw_fat        = { category = 'eldritch', weight = 2.0, immune = false },
    chitin_plate   = { category = 'eldritch', weight = 3.0, immune = true },
    void_crystal   = { category = 'eldritch', weight = 2.0, immune = true },
    raw_fur        = { category = 'hide',     weight = 1.5, immune = false },
    caustic_liquid = { category = 'eldritch', weight = 1.5, immune = false },
    serpent_venom  = { category = 'eldritch', weight = 0.5, immune = false },
    fang           = { category = 'eldritch', weight = 0.3, immune = true },

    -- lead (raw)
    lead           = { category = 'raw_ore', weight = 3.5, immune = true },
    -- metal (legacy name, maps to iron_ore or iron_ingot depending on context)
    metal          = { category = 'ingot', weight = 3.5, immune = true },
    -- stone (legacy name)
    stone          = { category = 'raw_stone', weight = 4.0, immune = true },
    -- wood (legacy name)
    wood           = { category = 'raw_wood', weight = 5.0, immune = false },
}

-- Drugs: all lightweight, not immune
local drugItems = {
    'psychoid_leaf', 'smokeleaf_leaf', 'hops', 'hay',
    'spike', 'stardust', 'drift', 'smog', 'rotgut', 'shards',
    'glimpse', 'surge', 'thaw', 'voidbloom', 'berserker', 'stim',
}
for _, name in ipairs(drugItems) do
    ItemDefs.ITEMS[name] = { category = 'drug', weight = 0.3, immune = false }
end

-- Weapons: unique per item, weight varies
-- (Weapon defs already exist in equipment.lua — reference weight from there)
-- For now, use generic weight. Sub-project 3 will refine.
local weaponItems = {
    'weapon_club', 'weapon_shiv', 'weapon_pipe_wrench', 'weapon_torch',
    'weapon_knife', 'weapon_hatchet', 'weapon_machete', 'weapon_spear',
    'weapon_axe', 'weapon_sword', 'weapon_shortbow', 'weapon_bow',
    'weapon_crossbow', 'weapon_revolver', 'weapon_pistol',
    'weapon_sawed_off', 'weapon_pump_shotgun', 'weapon_bolt_action',
    'weapon_assault_rifle', 'weapon_battle_rifle',
}
for _, name in ipairs(weaponItems) do
    ItemDefs.ITEMS[name] = { category = 'weapon', weight = 3.0, immune = true, unique = true }
end

-- Ammo
local ammoItems = {
    'ammo_arrow', 'ammo_fire_arrow', 'ammo_bolt', 'ammo_bullet',
    'ammo_shell', 'ammo_rocket', 'ammo_mortar_shell',
}
for _, name in ipairs(ammoItems) do
    ItemDefs.ITEMS[name] = { category = 'ammo', weight = 0.2, immune = true }
end

-- Ordnance
local ordnanceItems = {
    'grenade', 'ied', 'molotov', 'pipe_bomb', 'placed_charge', 'timed_bomb',
    'tripwire_bomb', 'napalm_grenade', 'napalm_bomb', 'bio_grenade',
    'bio_bomb', 'foam_grenade', 'foam_bomb', 'c4_charge', 'emp_charge',
    'emp_grenade', 'briefcase_nuke', 'nuclear_core',
    'napalm_fuel', 'foam_canister', 'gas_canister', 'acid_canister', 'poison_darts',
}
for _, name in ipairs(ordnanceItems) do
    ItemDefs.ITEMS[name] = { category = 'ordnance', weight = 1.0, immune = true }
end

-- Missiles
local missileItems = {
    'missile_he', 'missile_napalm', 'missile_bio',
    'missile_foam', 'missile_bunker', 'missile_nuke',
}
for _, name in ipairs(missileItems) do
    ItemDefs.ITEMS[name] = { category = 'ordnance', weight = 5.0, immune = true }
end

--- Look up item definition. Returns def table or a default.
function ItemDefs.get(itemId)
    return ItemDefs.ITEMS[itemId] or { category = 'component', weight = 1.0, immune = false }
end

--- Check if an item type is immune to environmental decay.
function ItemDefs.isImmune(itemId)
    local def = ItemDefs.get(itemId)
    return def.immune == true
end

--- Check if an item type is unique (cannot stack — weapons, armor, clothing).
function ItemDefs.isUnique(itemId)
    local def = ItemDefs.get(itemId)
    return def.unique == true
end

--- Get weight per unit for an item type.
function ItemDefs.getWeight(itemId)
    local def = ItemDefs.get(itemId)
    return def.weight
end

--- Get category for an item type.
function ItemDefs.getCategory(itemId)
    local def = ItemDefs.get(itemId)
    return def.category
end

return ItemDefs
```

- [ ] **Step 3: Test — require item_defs and verify lookups**

Run: `love .`
In debug console or a temp test: `local ID = require('src.world.item_defs'); print(ID.get('iron_ore').weight)` → should print 3.0.

- [ ] **Step 4: Commit**

```bash
git add src/world/item_defs.lua
git commit -m "feat: add item definitions table with weights, categories, and immunities"
```

---

### Task 2: Overhaul items.lua — remove decay timer, add weight/durability

**Files:**
- Modify: `src/world/items.lua`

- [ ] **Step 1: Read items.lua fully**

Read `src/world/items.lua`. Note:
- `DECAY_TIME = 600` at line 132
- `itemDecaySystem` registered at line 189
- `spawn()` at lines 10-23
- `step()` at lines 151-182

- [ ] **Step 2: Add ItemDefs require**

At top of file, add:
```lua
local ItemDefs = require('src.world.item_defs')
```

- [ ] **Step 3: Update spawn() to include weight and durability**

Modify `Items.spawn()` to pull defaults from ItemDefs:

```lua
function Items.spawn(x, y, itemId, amount, category, depth, opts)
    opts = opts or {}
    local def = ItemDefs.get(itemId)
    local id = ECS.spawn()
    ECS.set(id, 'pos', { x = x, y = y, depth = depth or 0 })
    ECS.set(id, 'item', {
        itemId   = itemId,
        amount   = amount or 1,
        category = category or def.category,
        quality  = opts.quality or 'normal',
        material = opts.material,
        durability = opts.durability or 100,
        weight   = def.weight,
        hauled   = false,
    })
    return id
end
```

- [ ] **Step 4: Remove the DECAY_TIME constant and itemDecaySystem**

Delete the `DECAY_TIME = 600` line and the entire `itemDecaySystem` ECS system registration (the system that counts down `_decayTimer` and destroys items). Items will no longer auto-decay — that functionality moves to `item_decay.lua` in sub-project 4.

- [ ] **Step 5: Test — spawn an item, verify it persists past 10 minutes**

Run: `love .`
Start a game. Use debug to call `Items.spawn(64, 64, 'stone_chunk', 5)`. Wait 11+ game-minutes. Item should still exist on the ground (no more auto-decay).

- [ ] **Step 6: Commit**

```bash
git add src/world/items.lua
git commit -m "feat: items gain weight/durability from item_defs, remove 10-min decay timer"
```

---

### Task 3: Add item_defs entries to KNOWN_COMPONENTS / save system

**Files:**
- Modify: `src/persistence/save_helpers.lua`

- [ ] **Step 1: Read KNOWN_COMPONENTS**

Read `src/persistence/save_helpers.lua` lines 85-107. Verify `'item'` is already in the list (it is).

- [ ] **Step 2: Verify item component saves correctly with new fields**

The `item` component is already in `KNOWN_COMPONENTS`. The new fields (`weight`, `durability`) are just additional table keys — Lua table serialization will pick them up automatically. No save_helpers change needed for this task.

However, verify that the save system handles `nil` values gracefully (e.g., `material = nil` should not crash serialization). Read the serialization function to confirm.

- [ ] **Step 3: Test — save and load a game with physical items**

Run: `love .`
Start game, spawn items via debug, save (F5), load (F9). Items should persist with all fields intact.

- [ ] **Step 4: Commit (if any changes were needed)**

```bash
git add src/persistence/save_helpers.lua
git commit -m "fix: verify item component persistence with new weight/durability fields"
```

---

## Chunk 2: GameState Compatibility Shim

### Task 4: Create addResource/spendResource compatibility shims

**Files:**
- Modify: `src/game_state.lua`

- [ ] **Step 1: Read current addResource and spendResource**

Read `src/game_state.lua` lines 323-351. Note:
- `addResource` applies `resourceScarcity` multiplier and notifies quest system
- `spendResource` checks availability, respects debug infinite-resources mode

- [ ] **Step 2: Add Items require with pcall (avoid circular deps)**

At top of `game_state.lua` or inside the functions (lazy require):
```lua
-- Inside addResource, lazy require to avoid circular dependency
local function getItems()
    local ok, mod = pcall(require, 'src.world.item_defs')
    return ok and mod or nil
end
```

- [ ] **Step 3: Modify addResource to spawn physical items**

Keep the existing function signature and behavior, but ADD item spawning alongside the counter increment. During migration, both the counter AND the physical item exist — this lets us migrate consumers one by one.

```lua
function GameState.addResource(name, amount)
    if GameState.resources[name] == nil then return end

    local actual = amount
    if amount > 0 then
        local scarcity = GameState.resourceScarcity or 1.0
        actual = math.floor(amount * scarcity + 0.5)
    end
    GameState.resources[name] = GameState.resources[name] + actual

    -- Spawn physical item at colony center (shim behavior)
    if actual > 0 then
        local ok, Items = pcall(require, 'src.world.items')
        if ok and Items.spawn then
            local sx = GameState.startX or 64
            local sy = GameState.startY or 64
            Items.spawn(sx, sy, name, actual, nil, 0)
        end
    end

    -- Notify quest system
    if actual > 0 then
        local qok, QuestMod = pcall(require, 'src.quest.quest')
        if qok and QuestMod.onResourceGathered then
            QuestMod.onResourceGathered(name, actual)
        end
    end
end
```

**Important:** During migration, this means resources exist in TWO places (counter + physical item). Consumers that still read from `GameState.resources[name]` will work. New consumers that read from storage/ground will also work. We'll remove the counter increment once all consumers are migrated.

- [ ] **Step 4: Keep spendResource unchanged for now**

`spendResource` continues to deduct from counters. It will be migrated to `StorageNetwork.withdraw()` in sub-project 2 (storage buildings). For now, the counter is the source of truth for spending.

- [ ] **Step 5: Test — mine a rock, verify both counter increments AND physical item spawns**

Run: `love .`
Designate a rock for mining. After colonist mines it:
- `GameState.resources.stone` should increase (counter still works)
- A physical stone item entity should appear at colony center

- [ ] **Step 6: Commit**

```bash
git add src/game_state.lua
git commit -m "feat: addResource shim spawns physical items alongside counter increment"
```

---

## Chunk 3: Mining → Physical Items

### Task 5: Migrate work_ai.lua mining to spawn items at colonist position

**Files:**
- Modify: `src/colonist/work_ai.lua`

- [ ] **Step 1: Read executeMine() in work_ai.lua**

Read `src/colonist/work_ai.lua` lines 140-260. Note all `GameState.addResource()` calls and the colonist position (`pos.x`, `pos.y`, `pos.depth`).

- [ ] **Step 2: Add Items require**

Add at top of work_ai.lua:
```lua
local Items = require('src.world.items')
```

- [ ] **Step 3: Replace addResource calls with Items.spawn at colonist position**

For each mining output, change from:
```lua
GameState.addResource('stone', 2 + math.floor(skill / 3))
```
to:
```lua
Items.spawn(pos.x, pos.y, 'stone', 2 + math.floor(skill / 3), nil, pos.depth)
```

Apply this pattern to ALL mining addResource calls in executeMine():

| Line | Old call | New call |
|------|----------|----------|
| ~148 | `addResource('thermalCores', 1)` | `Items.spawn(pos.x, pos.y, 'thermalCores', 1, nil, pos.depth)` |
| ~197 | `addResource('stone', 2 + ...)` | `Items.spawn(pos.x, pos.y, 'stone', 2 + ..., nil, pos.depth)` |
| ~200 | `addResource('metal', 1 + ...)` | `Items.spawn(pos.x, pos.y, 'metal', 1 + ..., nil, pos.depth)` |
| ~206 | `addResource('water', 2)` | `Items.spawn(pos.x, pos.y, 'water', 2, nil, pos.depth)` |
| ~209 | `addResource('wood', 3 + ...)` | `Items.spawn(pos.x, pos.y, 'wood', 3 + ..., nil, pos.depth)` |
| ~212 | `addResource('hide', 1)` | `Items.spawn(pos.x, pos.y, 'hide', 1, nil, pos.depth)` |
| ~223 | `addResource('metal', 3 + ...)` | `Items.spawn(pos.x, pos.y, 'metal', 3 + ..., nil, pos.depth)` |
| ~224 | `addResource('stone', 1)` | `Items.spawn(pos.x, pos.y, 'stone', 1, nil, pos.depth)` |
| ~229 | `addResource('stone', 3 + ...)` | `Items.spawn(pos.x, pos.y, 'stone', 3 + ..., nil, pos.depth)` |
| ~231 | `addResource('metal', 1)` | `Items.spawn(pos.x, pos.y, 'metal', 1, nil, pos.depth)` |
| ~238 | `addResource('stone', 2 + ...)` | `Items.spawn(pos.x, pos.y, 'stone', 2 + ..., nil, pos.depth)` |
| ~245 | `addResource('lead', 3 + ...)` | `Items.spawn(pos.x, pos.y, 'lead', 3 + ..., nil, pos.depth)` |
| ~246 | `addResource('stone', 1)` | `Items.spawn(pos.x, pos.y, 'stone', 1, nil, pos.depth)` |
| ~250 | `addResource('stone', 4 + ...)` | `Items.spawn(pos.x, pos.y, 'stone', 4 + ..., nil, pos.depth)` |
| ~254 | `addResource('wood', 1 + ...)` | `Items.spawn(pos.x, pos.y, 'wood', 1 + ..., nil, pos.depth)` |

**Keep the quest notification:** After each `Items.spawn()`, still notify the quest system:
```lua
local qok, QuestMod = pcall(require, 'src.quest.quest')
if qok and QuestMod.onResourceGathered then
    QuestMod.onResourceGathered(itemId, actual)
end
```

- [ ] **Step 4: Also migrate executeForage() (line ~549)**

The foraging fallback at line 549 also calls `addResource`. Change it to spawn items at colonist position with the same pattern.

- [ ] **Step 5: Remove the addResource shim's item spawning for migrated resources**

Now that mining spawns items directly at the colonist, the shim in `GameState.addResource()` would double-spawn for mining outputs. Two options:
- **Option A:** Leave the shim — it means double items during migration (acceptable, items are free)
- **Option B:** Remove the shim's `Items.spawn()` call now that direct callers are migrated

Choose **Option A** for now — the shim still serves non-migrated callers (storyteller rewards, quest rewards, etc). We'll clean up after all callers are migrated.

- [ ] **Step 6: Test — mine a rock, verify item drops at colonist's feet**

Run: `love .`
Designate a rock. Watch colonist mine it. A physical stone item should appear at the colonist's position (not colony center). The item should be haulable to a stockpile zone.

- [ ] **Step 7: Commit**

```bash
git add src/colonist/work_ai.lua
git commit -m "feat: mining spawns physical items at colonist position instead of counter"
```

---

### Task 6: Migrate miners.lua to spawn physical items

**Files:**
- Modify: `src/building/miners.lua`

- [ ] **Step 1: Read miners.lua addResource calls**

Read `src/building/miners.lua`. Find:
- Line ~255: `GameState.addResource('stone', ...)` — bore drill byproduct
- Line ~295: `GameState.addResource(miner.resource, amount)` — standard miner harvest

- [ ] **Step 2: Add Items require**

```lua
local Items = require('src.world.items')
```

- [ ] **Step 3: Replace addResource with Items.spawn at output tile**

For standard miners, the output tile is one tile behind the miner (opposite its facing direction). Find where the miner's position and direction are determined, calculate the output tile, and spawn there:

```lua
-- Replace: GameState.addResource(miner.resource, amount)
-- With:
local outputX, outputY = getOutputTile(pos.x, pos.y, miner.facing)
Items.spawn(outputX, outputY, miner.resource, amount, nil, pos.depth)
```

If the output tile calculation doesn't exist yet, compute it from the miner's facing/direction and position. The output tile is the tile the miner faces AWAY from (behind it).

For bore drill byproduct:
```lua
-- Replace: GameState.addResource('stone', stoneYield)
-- With:
Items.spawn(miner.startX, miner.startY, 'stone', stoneYield, nil, pos.depth)
```
Bore drill outputs behind its starting position.

- [ ] **Step 4: Test — place a miner on ore, verify items appear at output tile**

Run: `love .`
Place an electric drill on an ore vein. Wait for a cycle. A physical iron ore item should appear on the output tile behind the miner.

- [ ] **Step 5: Commit**

```bash
git add src/building/miners.lua
git commit -m "feat: miners spawn physical items at output tile instead of counter"
```

---

## Chunk 4: Conveyor Belt Integration

### Task 7: Extend conveyor belt item format

**Files:**
- Modify: `src/logistics/conveyors.lua`

- [ ] **Step 1: Read conveyor belt item structure**

Read `src/logistics/conveyors.lua`. Current belt item: `{ id = itemId, progress = 0 }`. Only two fields.

- [ ] **Step 2: Extend insertItem to accept full item data**

Change `Conveyors.insertItem(x, y, itemId)` to accept an optional data table:

```lua
function Conveyors.insertItem(x, y, itemId, itemData)
    local belt = getBelt(x, y)
    if not belt or belt.item or belt.frozen then return false end
    belt.item = {
        id = itemId,
        progress = 0,
        quality  = itemData and itemData.quality or 'normal',
        material = itemData and itemData.material or nil,
        durability = itemData and itemData.durability or 100,
        amount   = itemData and itemData.amount or 1,
    }
    return true
end
```

- [ ] **Step 3: Extend extractItem to return full item data**

Change `Conveyors.extractItem(x, y)` to return the full item table:

```lua
function Conveyors.extractItem(x, y)
    local belt = getBelt(x, y)
    if not belt or not belt.item then return nil end
    local item = belt.item
    belt.item = nil
    return item  -- returns full table: {id, progress, quality, material, durability, amount}
end
```

- [ ] **Step 4: Fix belt-to-belt transfer to preserve full item data**

In `Conveyors.step()`, find line ~260 where belt-to-belt transfer happens:
```lua
target.item = { id = belt.item.id, progress = 0 }
```
This strips all extended fields. Change to:
```lua
target.item = {
    id = belt.item.id,
    progress = 0,
    quality = belt.item.quality,
    material = belt.item.material,
    durability = belt.item.durability,
    amount = belt.item.amount,
}
```

Also fix `Conveyors.remove()` at line ~110 which spawns items when belts are removed:
```lua
-- Old: Items.spawn(x, y, belt.item.id, 1)
-- New:
Items.spawn(x, y, belt.item.id, belt.item.amount or 1, nil, depth, {
    quality = belt.item.quality,
    material = belt.item.material,
    durability = belt.item.durability,
})
```

Also fix belt end-of-line item drop at line ~280-281:
```lua
-- Old: Items.spawn(nx, ny, belt.item.id, 1)
-- New:
Items.spawn(nx, ny, belt.item.id, belt.item.amount or 1, nil, depth, {
    quality = belt.item.quality,
    material = belt.item.material,
    durability = belt.item.durability,
})
```

- [ ] **Step 5: Update Conveyors.getState()/loadState() for extended fields**

In `Conveyors.getState()` at line ~333, change the save format:
```lua
-- Old: { id = belt.item.id, progress = belt.item.progress }
-- New:
{ id = belt.item.id, progress = belt.item.progress,
  quality = belt.item.quality, material = belt.item.material,
  durability = belt.item.durability, amount = belt.item.amount }
```

In `Conveyors.loadState()` at line ~352, the restored item table already receives all saved fields as table keys — no change needed if the save format includes them.

- [ ] **Step 6: Test — place item on belt, verify quality/material survive transit and save/load**

Run: `love .`
Use debug to spawn an item, place it on a belt via inserter or direct `Conveyors.insertItem()`. Let it travel. Extract at the end. Verify quality and material fields are preserved.

- [ ] **Step 7: Commit**

```bash
git add src/logistics/conveyors.lua
git commit -m "feat: conveyor belt items carry quality, material, durability, amount"
```

---

### Task 8: Update inserters for extended item data

**Files:**
- Modify: `src/logistics/inserters.lua`

- [ ] **Step 1: Read inserter takeFromSource and placeOnDest**

Read `src/logistics/inserters.lua` lines 66-155. Note how items are represented as strings or simple tables.

- [ ] **Step 2: Update takeFromSource to capture full item data**

When taking from a belt: `Conveyors.extractItem()` now returns a full table. Store it in `ins.heldItem` as-is (not just the id string).

When taking from a ground item (ECS entity): read the `item` component fields and create an item data table:
```lua
local itemComp = ECS.get(entityId, 'item')
ins.heldItem = {
    id = itemComp.itemId,
    quality = itemComp.quality,
    material = itemComp.material,
    durability = itemComp.durability,
    amount = itemComp.amount,
}
Items.destroy(entityId)  -- remove ground entity
```

When taking from a machine output buffer: similar pattern — read the buffer data.

- [ ] **Step 3: Update placeOnDest to pass full item data**

When placing on belt: `Conveyors.insertItem(x, y, heldItem.id, heldItem)`
When placing on ground: `Items.spawn(x, y, heldItem.id, heldItem.amount, nil, depth, { quality = heldItem.quality, material = heldItem.material, durability = heldItem.durability })`
When placing in stockpile zone: pass full data to zone storage.

- [ ] **Step 4: Test — inserter moves items between belt and storage, data preserved**

Run: `love .`
Set up inserter between belt and stockpile. Items should move with quality/material/durability intact.

- [ ] **Step 5: Commit**

```bash
git add src/logistics/inserters.lua
git commit -m "feat: inserters handle full item data (quality, material, durability)"
```

---

## Chunk 5: Colonist Carry Capacity + Haul System

### Task 9: Weight-based colonist carry capacity

**Files:**
- Modify: `src/colonist/colonist.lua`

- [ ] **Step 1: Read inventory component initialization**

Read `src/colonist/colonist.lua` lines 243-246. Current: `capacity = math.floor(10 * (1 + carryMod))`.

- [ ] **Step 2: Change inventory to weight-based**

Replace the inventory component initialization:

```lua
inventory = {
    items = {},
    maxWeight = math.floor(50 * (1 + carryMod)),  -- base 50, modified by traits
    currentWeight = 0,
}
```

Also update `spawnFromDraft()` (line ~308) where inventory is set:
```lua
ECS.set(id, 'inventory', {
    items = {},
    maxWeight = math.floor(50 * (1 + dCarryMod)),
    currentWeight = 0,
})
```

- [ ] **Step 3: Add helper functions for inventory management**

Add to colonist.lua or a new section:

```lua
--- Add item to colonist's carry inventory.
--- Returns true if item fits, false if over weight limit.
function Colonist.addCarryItem(colonistId, itemId, amount, quality, material, durability)
    local inv = ECS.get(colonistId, 'inventory')
    if not inv then return false end
    local ItemDefs = require('src.world.item_defs')
    local itemWeight = ItemDefs.getWeight(itemId) * (amount or 1)
    if inv.currentWeight + itemWeight > inv.maxWeight then return false end

    inv.items[#inv.items + 1] = {
        itemId = itemId,
        amount = amount or 1,
        quality = quality,
        material = material,
        durability = durability,
    }
    inv.currentWeight = inv.currentWeight + itemWeight
    return true
end

--- Drop all carried items at position.
function Colonist.dropCarriedItems(colonistId, x, y, depth)
    local inv = ECS.get(colonistId, 'inventory')
    if not inv then return end
    local Items = require('src.world.items')
    for _, carried in ipairs(inv.items) do
        Items.spawn(x, y, carried.itemId, carried.amount, nil, depth, {
            quality = carried.quality,
            material = carried.material,
            durability = carried.durability,
        })
    end
    inv.items = {}
    inv.currentWeight = 0
end
```

- [ ] **Step 4: Wire item drop on colonist death**

Find colonist death handling (search for `state = 'dead'` or where colonist entities are cleaned up). On death, find any hauled item entities belonging to this colonist and unhaulmark them so they drop at the colonist's position:

```lua
-- On colonist death:
local pos = ECS.get(colonistId, 'pos')
if pos then
    -- Find any items this colonist was hauling and drop them
    for id, item in pairs(ECS.getAll('item') or {}) do
        if item.hauled and item._haulerId == colonistId then
            item.hauled = false
            item._haulerId = nil
            -- Move item to colonist's death position
            local ipos = ECS.get(id, 'pos')
            if ipos then
                ipos.x = pos.x
                ipos.y = pos.y
                ipos.depth = pos.depth or 0
            end
        end
    end
    -- Clear carry weight
    local inv = ECS.get(colonistId, 'inventory')
    if inv then inv.currentWeight = 0 end
end
```

**Note:** This requires that `Items.pickup()` sets `item._haulerId = colonistId` so we can find hauled items belonging to a dead colonist. Update `Items.pickup()` to accept a hauler ID parameter.

- [ ] **Step 5: Test — verify colonist inventory uses weight, items drop on death**

Run: `love .`
Check that colonists still haul items. Kill a colonist (via debug) while they're hauling — items should drop at their position.

- [ ] **Step 6: Commit**

```bash
git add src/colonist/colonist.lua
git commit -m "feat: weight-based colonist carry capacity, drop items on death"
```

---

### Task 10: Update haul task execution for new item format

**Files:**
- Modify: `src/colonist/work_ai.lua`

- [ ] **Step 1: Read executeHaul in work_ai.lua**

Read `src/colonist/work_ai.lua` around lines 312-389 (the `executeHaul` function). Note how items are picked up (`Items.pickup(id)`) and delivered to zones (`Zones.storeItem()`).

- [ ] **Step 2: Track carry weight without duplicating item data**

The existing haul system marks ground items with `hauled = true` and the entity persists until delivery. To avoid duplicating item data (entity + carry inventory), use the carry inventory ONLY for weight tracking — not as a second copy of the item:

```lua
-- After: Items.pickup(taskData.itemEntityId)
-- Track weight on colonist (for speed penalty) but don't duplicate item data
local itemComp = ECS.get(taskData.itemEntityId, 'item')
if itemComp then
    local ItemDefs = require('src.world.item_defs')
    local inv = ECS.get(colonistId, 'inventory')
    if inv then
        inv.currentWeight = inv.currentWeight + (ItemDefs.getWeight(itemComp.itemId) * (itemComp.amount or 1))
    end
end
```

- [ ] **Step 3: Clear carry weight on haul dropoff**

In the dropoff phase, after storing in zone and destroying entity:

```lua
-- Deliver to zone (existing code)
Zones.storeItem(zoneId, destX, destY, taskData.itemId, taskData.amount,
    taskData.depth, taskData.quality, taskData.material)
-- Destroy the ground entity (existing code)
Items.destroy(taskData.itemEntityId)
-- Clear carry weight
local inv = ECS.get(colonistId, 'inventory')
if inv then inv.currentWeight = 0 end
```

**Note:** The ground item entity is the single source of truth for item data. The colonist's carry inventory only tracks weight for the speed penalty. On colonist death, `dropCarriedItems` uses the hauled entity (which still exists with `hauled = true`) — we need to find and unhaulmark it instead of spawning duplicates.

- [ ] **Step 4: Add hauling speed modifier based on carry weight**

Find where colonist movement speed is calculated during hauling. Apply the weight penalty:

```lua
local inv = ECS.get(colonistId, 'inventory')
if inv and inv.maxWeight > 0 then
    local ratio = inv.currentWeight / inv.maxWeight
    speed = speed * (1 - 0.3 * ratio)
end
```

- [ ] **Step 5: Test — haul items to stockpile, verify weight affects speed**

Run: `love .`
Mine rocks, watch colonists haul stone to stockpile. Heavy items (stone at 4.0 weight) should slow the colonist more than light items.

- [ ] **Step 6: Commit**

```bash
git add src/colonist/work_ai.lua
git commit -m "feat: haul tasks use weight-based carry, heavy items slow colonists"
```

---

## Chunk 6: Processing Machines

### Task 11: Extend existing production system with physical item processing

**Files:**
- Modify: `src/building/production_defs.lua` (add new recipes)
- Modify: `src/building/production_runtime.lua` (output items instead of counters)
- Create: `src/building/machine_defs.lua` (supplementary definitions if needed)

**IMPORTANT:** The codebase already has `production_defs.lua`, `production_runtime.lua`, and a `machine` ECS component with `inputBuf`/`outputBuf` fields that inserters read. Do NOT create a parallel system. Extend the existing one.

- [ ] **Step 1: Read existing production system**

Read `src/building/production_defs.lua` and `src/building/production_runtime.lua` to understand:
- How `Production.RECIPES` and `Production.MACHINES` are structured
- How `machine.inputBuf` and `machine.outputBuf` work
- How inserters interact with these buffers (see `inserters.lua` lines 77-93)
- How machines currently consume resources (likely `GameState.spendResource`) and produce output (likely `GameState.addResource`)

- [ ] **Step 2: Add physical-item processing recipes to existing production system**

If the existing `production_defs.lua` already has recipe structures, add the new processing chain recipes to it. If it doesn't support the input-buffer → process → output-buffer pattern needed for physical items, create `machine_defs.lua` as a supplementary file:

```lua
local MachineDefs = {}

MachineDefs.RECIPES = {
    smelter = {
        { input = {iron_ore = 1},   output = {iron_ingot = 1},   time = 5.0 },
        { input = {lead_ore = 1},   output = {lead_ingot = 1},   time = 5.0 },
        { input = {copper_ore = 1}, output = {copper_ingot = 1}, time = 5.0 },
    },
    forge = {
        { input = {iron_ingot = 1, fuel = 1}, output = {steel = 1}, time = 8.0 },
    },
    sawmill = {
        { input = {logs = 1}, output = {planks = 2}, time = 4.0 },
    },
    stonecutter = {
        { input = {stone = 2}, output = {cut_stone = 1}, time = 6.0 },
    },
    centrifuge = {
        { input = {uranium_ore = 2}, output = {enriched_uranium = 1, depleted_uranium = 1}, time = 15.0 },
    },
    refiner = {
        { input = {ice_block = 2}, output = {water = 1}, time = 3.0 },
    },
}

MachineDefs.BUILDINGS = {
    smelter     = { name = 'Smelter',     size = {2, 2}, power = 40, recipes = 'smelter' },
    forge       = { name = 'Forge',       size = {2, 2}, power = 60, recipes = 'forge' },
    sawmill     = { name = 'Sawmill',     size = {2, 1}, power = 20, recipes = 'sawmill' },
    stonecutter = { name = 'Stonecutter', size = {2, 1}, power = 20, recipes = 'stonecutter' },
    centrifuge  = { name = 'Centrifuge',  size = {2, 2}, power = 80, recipes = 'centrifuge' },
    refiner     = { name = 'Refiner',     size = {1, 1}, power = 30, recipes = 'refiner' },
}

function MachineDefs.getRecipes(machineType)
    local key = MachineDefs.BUILDINGS[machineType]
    if not key then return {} end
    return MachineDefs.RECIPES[key.recipes] or {}
end

return MachineDefs
```

- [ ] **Step 3: Modify existing production runtime to use physical items**

The key change: when a machine completes processing, instead of calling `GameState.addResource()`, it should place the output item data in `machine.outputBuf` for inserters to pick up. Inserters (updated in Task 8) handle the full item data format.

If `production_runtime.lua` already uses `outputBuf`, modify the completion handler to store full item data:
```lua
-- Old: GameState.addResource(outputId, outputAmount)
-- New:
machine.outputBuf = {
    id = outputId,
    amount = outputAmount,
    quality = Quality.roll(operatorSkill),  -- quality based on operator skill
    material = nil,
    durability = 100,
}
```

Similarly, input consumption should read from `machine.inputBuf` (which inserters fill with physical item data) instead of `GameState.spendResource()`.

- [ ] **Step 4: Verify machine component is in KNOWN_COMPONENTS**

`'machine'` is already in `KNOWN_COMPONENTS` (line 88 of save_helpers.lua). The existing component handles save/load for machines. Verify the extended `inputBuf`/`outputBuf` data (now including quality/material/durability) serializes correctly.

- [ ] **Step 6: Test — place a smelter, feed it iron ore via inserter, get iron ingot out**

Run: `love .`
Place a smelter. Put iron ore on a belt leading to it via inserter. Verify the smelter processes it and outputs iron ingot on its output side.

- [ ] **Step 6: Commit**

```bash
git add src/building/machine_defs.lua src/building/production_defs.lua src/building/production_runtime.lua
git commit -m "feat: processing machines produce physical items (smelter, forge, sawmill, stonecutter, centrifuge, refiner)"
```

---

## Chunk 7: Integration and Colony Wealth

### Task 12: Update colony wealth calculation

**Files:**
- Modify: `src/game_state.lua`

- [ ] **Step 1: Read current getColonyWealth()**

Read `src/game_state.lua` lines 283-319. Note how it sums `GameState.resources` values.

- [ ] **Step 2: Add physical item wealth to the calculation**

Keep the existing counter-based wealth as a fallback, but also sum physical items:

```lua
function GameState.getColonyWealth()
    local wealth = 0

    -- Sum physical ground items
    local ECS = require('src.ecs.ecs')
    for id, item in pairs(ECS.getAll('item') or {}) do
        local ItemDefs = require('src.world.item_defs')
        local def = ItemDefs.get(item.itemId)
        local Quality = require('src.world.quality')
        local qData = Quality.get(item.quality or 'normal')
        local valueMult = qData and qData.valueMult or 1.0
        wealth = wealth + (def.weight * item.amount * valueMult)
    end

    -- Sum zone-stored items
    local ok, Zones = pcall(require, 'src.world.zones')
    if ok and Zones.getAllStoredItems then
        for _, storedItem in ipairs(Zones.getAllStoredItems()) do
            local ItemDefs = require('src.world.item_defs')
            local def = ItemDefs.get(storedItem.itemId)
            wealth = wealth + (def.weight * (storedItem.amount or 1))
        end
    end

    -- NOTE: Do NOT sum legacy GameState.resources counters here.
    -- During migration, the addResource shim spawns physical items AND increments
    -- counters for non-migrated call sites. Counting both would double-count.
    -- Physical items (ground + zone) are the authoritative source of wealth.
    -- Legacy counters will be removed entirely once all call sites are migrated.

    -- Buildings and colonists (existing logic)
    -- ... keep existing building/colonist wealth code ...

    return wealth
end
```

- [ ] **Step 3: Test — verify wealth calculation includes physical items**

Run: `love .`
Mine some resources. Check colony wealth in UI. Should reflect both counters and physical items.

- [ ] **Step 4: Commit**

```bash
git add src/game_state.lua
git commit -m "feat: colony wealth includes physical item entities"
```

---

### Task 13: Add inventory component to KNOWN_COMPONENTS for carrying state

**Files:**
- Modify: `src/persistence/save_helpers.lua`

- [ ] **Step 1: Verify inventory is in KNOWN_COMPONENTS**

Read the list. `'inventory'` is already present. The new fields (`maxWeight`, `currentWeight`, `items` array with full item data) are just additional table keys — serialization handles them automatically.

- [ ] **Step 2: Add 'processing' to KNOWN_COMPONENTS if not present**

If `processing.lua` uses a new component name (not `'machine'`), add it. If it reuses `'machine'`, no change needed.

- [ ] **Step 3: Test — save/load with items in colonist inventory and processing machines**

Run: `love .`
Have colonist haul something. Save mid-haul. Load. Colonist should still be carrying the item. Processing machines should resume.

- [ ] **Step 4: Commit**

```bash
git add src/persistence/save_helpers.lua
git commit -m "fix: ensure processing and carry state persist across save/load"
```

---

### Task 14: Save backward compatibility — convert old saves

**Files:**
- Modify: `src/persistence/save.lua` or `src/persistence/save_helpers.lua`

- [ ] **Step 1: Read save version handling**

Find where save version is stored and checked in the save/load system. Look for a version field in the save data.

- [ ] **Step 2: Update save version guard to accept version 2**

In `save.lua` line ~34, the current code rejects any save that isn't version 1:
```lua
if not data.version or data.version ~= 1 then
```
Change to accept both versions:
```lua
if not data.version or (data.version ~= 1 and data.version ~= 2) then
```

- [ ] **Step 3: Add migration path for pre-physical-item saves**

In the load path, after restoring GameState, check if this is a pre-migration save:

```lua
-- After loading GameState from save data:
if saveData.version == 1 then
    -- Migrate: spawn physical items from resource counters
    local Items = require('src.world.items')
    local sx, sy = GameState.startX or 64, GameState.startY or 64
    for name, count in pairs(GameState.resources) do
        if count > 0 and name ~= 'research' then
            Items.spawn(sx, sy, name, count, nil, 0)
        end
    end
    -- Bump version
    saveData.version = 2
end
```

- [ ] **Step 4: Set save version on new saves**

When saving, include a version field:
```lua
saveData.version = 2
```

- [ ] **Step 5: Test — load an old save, verify resources converted to physical items**

Create a save with the old system (or use an existing save). Load it. Physical items should appear at colony center. Save again. Reload. Items should persist without re-migration.

- [ ] **Step 6: Commit**

```bash
git add src/persistence/save.lua src/persistence/save_helpers.lua
git commit -m "feat: backward-compatible save migration for physical items"
```

---

### Task 15: Integration test — full physical items flow

**Files:** None (manual testing)

- [ ] **Step 1: Test complete mining → hauling → stockpile flow**

1. Start new game
2. Designate rocks/trees/ore for mining
3. Colonists mine → physical items drop at their feet
4. Auto-haul creates haul tasks
5. Colonists carry items to stockpile zones
6. Items stored in zones
7. Verify no duplicate resource counting (counter + physical)

- [ ] **Step 2: Test miner building → belt → inserter → storage flow**

1. Place electric drill on ore vein
2. Belt behind drill
3. Inserter from belt to stockpile
4. Verify items flow: drill → belt → inserter → stockpile
5. Quality/material/durability preserved through chain

- [ ] **Step 3: Test processing chain**

1. Smelter with inserters
2. Iron ore in → iron ingot out
3. Verify recipe timing and output

- [ ] **Step 4: Test save/load with physical items**

1. Mine resources, let items scatter on ground and in stockpiles
2. Save (F5)
3. Load (F9)
4. All items persist at correct positions with correct data

- [ ] **Step 5: Test old save migration**

If available, load a pre-migration save. Resources should convert to physical items.

- [ ] **Step 6: Test colonist death drops items**

Kill a colonist mid-haul (debug). Items should drop at their position.

- [ ] **Step 7: Fix any issues found**

Address bugs discovered during testing.

- [ ] **Step 8: Final commit**

```bash
git add -A
git commit -m "fix: integration polish for physical item entities"
```
