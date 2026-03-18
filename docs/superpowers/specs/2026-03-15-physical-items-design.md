# Physical Item System, Storage Buildings, Clothing & Environmental Decay

**Date:** 2026-03-15
**Status:** Approved

## Summary

Replace Frosthold's abstract resource counter system with physical item entities. Add storage buildings with power-grid networking, a 5-slot clothing/apparel system with multi-environment protection stats and degradation, and environment-driven item decay replacing arbitrary timers. This is the foundation for making the game feel like a real physical world across all 7 planets.

## Scope Decomposition

Four sub-projects, built in order (each depends on the previous):

1. **Physical Item Entities** — replace counters with real droppable/haulable items
2. **Storage Buildings + Power-Grid Networking** — lockers, crates, shelves that organize zone items
3. **Clothing/Apparel System** — 5-slot wearable layers with protection stats + degradation
4. **Environmental Item Decay** — weather/temperature-driven damage replacing arbitrary timer

---

## Sub-Project 1: Physical Item Entities

### Item Component

Every physical item is an ECS entity with `pos` and `item` components:

```lua
item = {
    itemId = 'iron_ore',
    amount = 1,
    category = 'raw_ore',
    material = 'iron',
    quality = 'normal',        -- awful/poor/normal/fine/superior/masterwork/legendary
    durability = 100,          -- 0-100, degrades from environment/use
    weight = 3.0,              -- per unit, affects hauling and stack limits
}
```

**Note:** Items on the ground are ECS entities with `pos` + `item` components. Items inside storage buildings are **data in the storage component's slots** — NOT ECS entities. This means the decay system only iterates ECS entities with `pos` + `item` (ground items), and storage contents are inherently protected. When an item enters storage, the ground entity is destroyed and slot data is created. When withdrawn, a new entity is spawned.

### Item Categories

- `raw_ore` — iron ore, lead ore, copper ore, uranium ore
- `raw_stone` — stone chunks
- `raw_wood` — logs
- `raw_ice` — ice blocks
- `ingot` — iron ingot, lead ingot, copper ingot, enriched uranium, depleted uranium
- `plank` — wood planks
- `cut_stone` — stone blocks
- `food_raw` — raw meat, berries, mushrooms
- `food_cooked` — meals
- `component` — circuits, pipes, glass
- `fuel` — fuel cells, charcoal
- `medicine` — bandages, medicine, serum
- `thermal_core` — thermal cores (high-value, tradeable)
- `weapon` — all weapon types
- `armor` — armor pieces
- `clothing` — all clothing items
- `accessory` — small wearable items
- `liquid` — water containers, fuel canisters (carried in sealed containers)
- `hazmat` — uranium ore, radioactive materials (special handling)

### Item Weights and Stacking

Stacking is weight-based. Each storage slot has a weight capacity. Stack per slot = `floor(slotMaxWeight / itemWeight)`.

| Item Type | Weight/unit | Stack in 200-wt slot |
|-----------|-------------|----------------------|
| Raw ore (iron, lead, copper) | 3.0 | 66 |
| Uranium ore | 4.0 | 50 |
| Raw stone | 4.0 | 50 |
| Logs | 5.0 | 40 |
| Raw ice | 2.5 | 80 |
| Ingots (iron, lead, copper, steel) | 3.5 | 57 |
| Enriched uranium | 4.0 | 50 |
| Depleted uranium | 4.0 | 50 |
| Planks | 2.0 | 100 |
| Cut stone | 3.5 | 57 |
| Food (raw) | 1.0 | 200 |
| Food (cooked) | 1.5 | 133 |
| Components | 0.5 | 400 |
| Fuel cells | 2.0 | 100 |
| Medicine | 0.3 | 666 |
| Thermal cores | 5.0 | 40 |
| Weapons | varies | 1 (unique) |
| Armor | varies | 1 (unique) |
| Clothing | varies | 1 (unique, has own durability) |
| Accessories | 0.5 | 10 per slot (unique-ish) |
| Water containers | 2.0 | 100 |

### Stacking Rules

Items stack in a slot only when ALL of these match: `itemId`, `quality`, `material`. Different qualities of the same item cannot share a slot. This means a storage building holding "iron ore (normal)" and "iron ore (fine)" uses 2 slots, not 1.

### Three Mining Methods

**1. Colonist Mining (manual)**
- Colonist walks to designated tile, breaks it over time (existing mechanic)
- On tile break: `Items.spawn(colonistX, colonistY, oreType, amount)` — physical item drops at colonist's feet
- Replaces current `GameState.addResource()` calls in work_ai.lua mining code
- Mining output by tile type:
  - ROCK → stone chunk (amount: 2 + skill bonus)
  - ORE_VEIN → iron ore (amount: 1-3 based on skill)
  - LEAD_ORE → lead ore (amount: 1-2)
  - ICE → ice block (amount: 2)
  - TREE → logs (amount: 2-4)

**2. Stationary Miner (building)**
- Placed adjacent to ore vein node
- Auto-extracts ore on tick interval (1 ore per ~10 seconds at base speed)
- Outputs item one tile behind it (opposite face from the ore)
- Requires power connection
- Output tile receives item — if belt/chest/inserter is there, item enters that system
- If output tile is full/blocked, miner pauses until cleared
- Colonist maintains/refuels periodically (maintenance task)

**3. Bore Miner (automated)**
- Placed facing a direction
- Moves forward one tile per cycle, destroying the tile and producing the appropriate item
- Outputs items behind it (starting position, where belt/chest should be)
- Stops when: hits empty/walkable space, runs out of power, hits map edge
- Expensive to build (steel + components + circuits)
- Late-game tech (requires research)

### Processing Chains

```
iron_ore    → [smelter]     → iron_ingot
lead_ore    → [smelter]     → lead_ingot
copper_ore  → [smelter]     → copper_ingot
iron_ingot + fuel → [forge]  → steel
uranium_ore → [centrifuge]  → enriched_uranium + depleted_uranium
logs        → [sawmill]     → planks
stone_chunk → [stonecutter] → cut_stone
raw_ice     → [refiner]     → water
```

All processing machines follow the Factorio pattern: input slot, processing time, output slot. Output goes to the tile behind the machine (belt/chest/ground).

### Conveyor Belt Item Format

Existing conveyors use lightweight tables (`{ id = itemId, progress = 0 }`), NOT ECS entities. This is correct for performance — belt items should NOT be full ECS entities because `pos` updates every belt tick would be expensive at scale.

**Belt item data format (extended from current):**
```lua
beltItem = {
    id = 'iron_ore',
    amount = 1,
    quality = 'normal',
    material = 'iron',
    durability = 100,
    progress = 0,        -- 0-1 position on belt tile
}
```

**Conversion boundaries:**
- **Ground → Belt (inserter pickup or direct drop):** Destroy ground item ECS entity, create belt item table with same data fields.
- **Belt → Ground (belt end or inserter drop):** Create ground item ECS entity from belt item table data.
- **Belt → Storage (inserter):** Write belt item data into storage slot. No ECS entity involved.
- **Storage → Belt (inserter):** Read storage slot data, create belt item table.
- **Machine output → Belt:** Machine creates belt item table from recipe output.

This means the existing conveyor/inserter code structure stays intact — belt items remain lightweight tables. Only the table gains extra fields (quality, material, durability).

### GameState.resources Migration

**Move to physical items (remove counters):**
- All raw materials: wood, stone, metal, ore, ice, hide
- All processed materials: ingots, planks, cut stone, steel, circuits, pipes, glass
- All consumables: food, medicine, fuel, water, bandages, serum
- All equipment: weapons, armor, clothing
- Thermal cores

**Remain as counters (not physical):**
- Research points
- Reputation (faction system)
- Colony wealth score (computed from physical items + buildings + colonists)

**Migration approach — compatibility shim for incremental transition:**

The codebase has ~96 call sites across ~30 files that use `addResource`/`spendResource`. Rewriting all of them atomically is too risky. Instead:

1. Keep `GameState.addResource(name, amount)` as a **thin wrapper** that calls `Items.spawn()` at a designated drop-off point (colony center or nearest stockpile zone entrance). This lets all existing call sites continue working during migration.

2. Keep `GameState.spendResource(name, amount)` as a **thin wrapper** that calls `StorageNetwork.withdraw()` from the nearest storage. Returns true/false like before.

3. Migrate files one-by-one to call `Items.spawn()` / `StorageNetwork.withdraw()` directly, with proper spawn coordinates and colonist context.

4. Once all call sites are migrated, remove the shim wrappers.

**Key call sites requiring migration (30+ files):**
- `src/colonist/work_ai.lua` — mining, crafting, production output
- `src/storyteller/storyteller.lua` — event rewards (~11 calls)
- `src/storyteller/events_expansion.lua` — expansion event rewards
- `src/trade/merchants.lua` — trade buy/sell (~6 calls)
- `src/trade/trade_routes.lua` — automated trade
- `src/colonist/recruitment.lua` — recruitment costs
- `src/colonist/equipment.lua` — autoEquip resource consumption
- `src/colonist/suits.lua` — suit crafting resource costs
- `src/creatures/eldritch_nodes.lua` — node harvest rewards (~7 calls)
- `src/exploration/expeditions.lua` — expedition rewards
- `src/quest/quest.lua` — quest rewards (~5 calls)
- `src/building/agriculture.lua` — harvest output
- `src/building/upgrades.lua` — upgrade costs
- `src/medical/surgery.lua` — surgery material costs
- `src/combat/hunting.lua` — butchering output
- `src/colony/factions.lua` — tribute/gift costs
- `src/colonist/strange_moods.lua` — mood crafting
- Plus: caverns.lua, map_secrets.lua, biocaves.lua, visitors.lua, autoplay.lua

**Colony wealth calculation:**
`GameState.getColonyWealth()` must be rewritten to scan `StorageNetwork.getTotal()` for each item type across all networks, plus ground items, plus building values, plus colonist values. This feeds the raid heat signature system — must not break.

**Backward save compatibility:**
On loading a pre-migration save (detected by save version number), run a one-time conversion: iterate `GameState.resources`, spawn physical item entities at colony center or nearest stockpile zone for each non-zero counter, then clear the counters.

**Colonist death/removal:**
When a colonist dies or is removed while carrying items, all carried items are spawned as ground entities at the colonist's position.

### Colonist Carry Capacity

Weight-based:
- Base carry capacity: 50 weight units
- Strong trait: 75 weight units
- Weak trait: 30 weight units
- Hauling speed reduced proportionally to carry weight ratio: `speed = baseSpeed * (1 - 0.3 * (carryWeight / maxCarry))`
- Colonist can carry multiple items up to weight limit (replaces single-item hauling)

---

## Sub-Project 2: Storage Buildings + Power-Grid Networking

### Storage Buildings

| Building | Slots | Weight/slot | Total capacity | Size | Protection | Special |
|----------|-------|-------------|----------------|------|------------|---------|
| Crate | 4 | 200 | 800 | 1x1 | None | Cheap, wood or metal |
| Locker | 8 | 200 | 1,600 | 1x1 | Weather | Metal construction |
| Shelf | 6 | 150 | 900 | 2x1 | Partial (roofed only) | Items visually displayed |
| Chest | 12 | 250 | 3,000 | 1x1 | Full (weather + temp) | Heavy, stone or metal |
| Cold storage unit | 8 | 200 | 1,600 | 2x2 | Full + cold preservation | Powered, keeps food frozen |
| Lead-lined vault | 6 | 300 | 1,800 | 2x2 | Full + radiation shielding | Blocks radiation emission |
| Bulk silo | 30 | 900 | 27,000 | 3x3 | Full | Single category filter only |

### Storage Building Component

```lua
storage = {
    slots = {},           -- array of {itemId, amount, quality, material, durability, weight} or nil
    capacity = 8,         -- number of slots
    maxSlotWeight = 200,  -- weight limit per slot
    filter = {},          -- accepted categories {raw_ore = true, ingot = true, ...}
    protection = {
        weather = true,   -- shields from rain/snow/storm
        cold = true,      -- shields from cold damage
        heat = false,     -- shields from heat damage
        radiation = false,-- shields from radiation
        pressure = false, -- shields from vacuum/depth pressure
    },
    powered = false,      -- requires power grid connection to function?
}
```

### Zones + Storage Buildings Interaction

Stockpile zones continue to work as floor-level designation. Storage buildings are placed inside zones to upgrade storage:

- **Zone without buildings:** items sit on ground tiles (1 stack per tile, exposed to environment)
- **Zone with buildings:** haulers prioritize putting items into storage buildings first, ground tiles as overflow
- **Building without zone:** still functions as manual storage, but no auto-hauling to it
- **Building inside zone with matching filter:** auto-haul targets the building's slots first

### Power-Grid Networking

All storage buildings connected to the same power grid share a logical inventory:

```lua
StorageNetwork.query(itemId, amount)
-- Returns: bool hasEnough, table sources [{storageEntityId, slotIdx, available}]
-- Checks all powered+connected storage buildings

StorageNetwork.withdraw(itemId, amount, requestingEntityId)
-- Removes items from nearest source(s) to the requesting colonist
-- Returns: table of {storageEntityId, slotIdx, withdrawn} for pathfinding

StorageNetwork.deposit(itemId, amount, storageEntityId, slotIdx)
-- Adds item to specific storage building slot

StorageNetwork.getTotal(itemId)
-- Returns: total amount of itemId across all networked storage

StorageNetwork.findNearestSource(itemId, fromX, fromY)
-- Returns: storageEntityId, slotIdx, x, y for pathfinding
```

**Network membership:**
- Storage building has power component connected to a power grid → member of that grid's network
- Unpowered storage → local only, not queryable by network
- Multiple separate power grids → multiple separate networks
- Connecting two grids (running a power line) merges their networks

**Build/craft recipe flow:**
1. Player orders "build wall" (costs 5 cut_stone)
2. System calls `StorageNetwork.query('cut_stone', 5)` on the nearest power grid
3. If available: colonist gets assigned haul task from nearest source
4. Colonist walks to source storage, withdraws items, carries to build site
5. If NOT available on network: check ground items in zones as fallback

### Hauling Priority

1. Ground items in zone → storage building in same zone (if space + filter match)
2. Ground items in zone → ground tile in same zone (if no building space)
3. Ground items outside zone → nearest accepting zone (building first, ground fallback)
4. Storage building overflow → ground tile in same zone

---

## Sub-Project 3: Clothing/Apparel System

### 5 Equipment Slots

| Slot | Examples | Primary stats |
|------|----------|---------------|
| Under layer | thermal undershirt, cooling vest, rad-suit liner | Base insulation, comfort |
| Outer layer | parka, hazmat suit, space suit, acid cloak | Major environmental protection |
| Head | wool hat, helmet, rebreather, rad hood | Head protection, sensory |
| Hands | insulated gloves, work gloves, rad gauntlets | Dexterity vs protection |
| Feet | boots, insulated boots, mag-boots, flippers | Movement speed vs protection |

### Clothing Component

```lua
clothing = {
    slot = 'outer',          -- which slot this fills
    cold = 35,               -- cold resistance (0-100)
    heat = 10,               -- heat resistance (0-100)
    pressure = 0,            -- vacuum/depth pressure resistance (0-100)
    radiation = 5,           -- radiation shielding (0-100)
    toxicity = 0,            -- chemical/acid resistance (0-100)
    durability = 100,        -- current condition (0-100)
    maxDurability = 100,     -- max condition (quality affects this)
    armor = 8,               -- physical damage reduction
    speedMod = -0.05,        -- movement speed modifier (negative = slower)
    workMod = 0.0,           -- work speed modifier (e.g., bulky gloves = -0.1)
    material = 'hide',       -- determines repair cost and base stats
    quality = 'normal',      -- scales all stat values
}
```

### Protection Calculation

Total colonist protection per stat = sum of all worn clothing pieces for that stat.

```lua
colonistCold = under.cold + outer.cold + head.cold + hands.cold + feet.cold
```

Compared against environment threshold:
- Erebus ambient cold = 80 → need 80+ total cold rating or take hypothermia damage
- Nemaea radiation = 60, pressure = 100 → need matching ratings
- Morvos toxicity = 70 → need matching toxicity rating during acid storms
- Rhea-2 heat = 75 → need matching heat rating

Deficit = `max(0, environmentDemand - totalProtection)`. Deficit drives damage rate for health effects:
- Cold deficit → hypothermia stages (existing 5-stage system)
- Heat deficit → heatstroke stages (new, mirrors hypothermia)
- Radiation deficit → radiation sickness stages (new)
- Pressure deficit → pressure damage (new, rapid — vacuum kills fast)
- Toxicity deficit → toxic exposure stages (new)

### Space Suits (Nemaea)

Space suits are a single clothing item with a `multiSlot` flag:

```lua
spaceSuit = {
    slot = 'outer',
    multiSlot = {'outer', 'head', 'hands', 'feet'},  -- occupies all 4 slots
    cold = 40, heat = 20, pressure = 90, radiation = 70, toxicity = 30,
    durability = 100, maxDurability = 100,
    armor = 5, speedMod = -0.15, workMod = -0.10,
    material = 'steel',
    o2Tank = 100,            -- current O2 level (0-100)
    o2MaxTank = 100,         -- max O2 capacity
    o2DrainRate = 2.0,       -- O2 units per game-hour in vacuum
}
```

**Multi-slot behavior:**
- Equipping a `multiSlot` item fills ALL listed slots. Unequipping clears all.
- Cannot equip if ANY of the listed slots is already occupied (must remove existing gear first).
- Combat damage to any body area reduces the single suit's durability (not per-slot).
- At 0 durability: suit destroyed, ALL slots cleared, immediate vacuum exposure.
- O2 tank drains while in unpressurized tiles. Refilled at airlocks or O2 stations.
- Very expensive to craft (steel + glass + circuits + cloth).

### Degradation

**Wear from use:**
- Passive: 0.1 durability/game-hour while worn
- Work clothes: 2x degradation rate during active work
- In storage: no wear

**Combat damage:**
- Hit to a body area damages clothing in that slot
- 5-15 durability per hit taken (scaled by damage amount)
- Armor stat reduces incoming damage but the clothing still degrades

**Environmental exposure:**
- Acid storms: 3.0 durability/hour to outer layer
- Vacuum: 0.5 durability/hour to unsealed clothing
- Extreme cold (<-50C): 0.3 durability/hour (brittleness)
- Flooding: 2.0 durability/hour (water damage)

**At 0 durability:**
- Clothing destroyed, removed from colonist
- Warning notification at 25%: "[Name]'s [item] is falling apart"
- Warning at 10%: "[Name]'s [item] is about to break"

### Repair

- Colonists with crafting skill repair at a workbench
- Costs material matching the clothing material (hide, cloth, metal)
- Restores durability proportional to skill level
- Cannot repair past `maxDurability` (which is set by quality tier)

### Migration from Current Equipment System

- Current `equipment.lua` has weapon/armor/accessory slots
- Weapons stay as-is (separate from clothing)
- Current 4 armor types (hide_coat, leather_armor, metal_plate, thermal_suit) become `outer` slot clothing with armor stat + appropriate protection values
- Current accessories migrate to the `accessory` slot (unchanged)
- New slots: under, head, hands, feet

**`src/colonist/suits.lua` migration:**
- Existing thermal suits and exosuits become clothing items in the `outer` slot
- Thermal suit `coldResist` percentage → `cold` rating value (e.g., 50% resist = cold: 50)
- Exosuit `carryMult` → `carryMod` field on clothing (e.g., +0.5 = 50% extra carry capacity)
- Exosuit `damageMult` → `armor` stat on clothing
- Suit durability and degradation already exists in suits.lua — migrates cleanly to clothing `durability`
- After migration, `suits.lua` is deleted (functionality absorbed into `clothing.lua`)

**`Equipment.autoEquip()` rewrite:**
- Currently checks `GameState.resources[mat] >= 1` and calls `GameState.spendResource('metal', 1)` to create gear from thin air
- Must change to: query `StorageNetwork` for actual physical weapon/clothing items, then physically transfer them to the colonist (remove from storage slot, add to colonist's equipment/clothing slots)
- If no suitable gear exists in storage, colonist goes without (no more conjuring equipment from counters)

---

## Sub-Project 4: Environmental Item Decay

### Damage Sources

| Hazard | Affects | Immune | Condition |
|--------|---------|--------|-----------|
| Extreme cold (<-40C) | Organics, liquids, cloth | Stone, ore, metal, ingots | On ground, unroofed or unheated room |
| Extreme heat (>50C) | Organics, electronics, wood | Stone, ore, metal ingots | On ground, exposed |
| Blizzard/storm | All exposed items (minor) | — | Unroofed tile during event |
| Acid storm (Morvos) | Everything except stone/glass | Stone, glass | Unroofed during acid event |
| Radiation (ambient/uranium) | Organics, cloth, food | Metal, stone, lead-lined contents | Above radiation threshold |
| Vacuum (Nemaea) | Sealed containers, organics | Raw ore, stone, metal | Unpressurized tile |
| Flooding (Nerthus-9) | Metal (rust), organics (rot), electronics | Stone, glass, sealed containers | Submerged tile |
| Fire | Wood, cloth, organics, fuel | Stone, metal, ore | Adjacent to fire source |

### Permanently Immune Items

These never decay from normal environmental exposure:
- Raw stone chunks
- Raw ore (iron, lead, copper — they're already rocks)
- Metal ingots (already refined)
- Cut stone blocks
- Depleted uranium (inert)

They can still be destroyed by extreme events (fire for prolonged exposure, acid storms) but not by cold, heat, or normal weather.

### Damage Rates (durability loss per game-hour)

| Condition | Rate |
|-----------|------|
| Normal environmental exposure | 0.5/hour (~8 game-days to destroy at 100 durability) |
| Severe weather event (blizzard, acid storm) | 2.0/hour |
| Flooding | 3.0/hour |
| Fire | 10.0/hour |
| Radiation (ambient) | 0.3/hour (slow contamination) |
| Vacuum (organics) | 1.0/hour (desiccation) |

### Protection Hierarchy

1. **Inside storage building with matching protection flag** → immune to that hazard type
2. **Inside roofed room** → protected from weather events, still vulnerable to room-level hazards (temperature, radiation, flooding)
3. **On ground in zone, roofed** → same as roofed room
4. **On ground, unroofed** → fully exposed to all environmental hazards

### Decay System Implementation

New ECS system: `ItemDecay.step(dt)`
- Runs every 30 game-seconds (not every tick — performance)
- Iterates all item entities with `pos` + `item` components (ground items only)
- Items inside storage buildings are slot data, NOT ECS entities — they are never iterated by this system and are inherently protected
- Checks tile conditions: roofed, room temperature, weather event active, radiation level, flooded, fire nearby
- Applies durability damage based on vulnerability table
- At durability 0: item entity destroyed, notification sent via existing `src/ui/alerts.lua`
- Items with `immune` flag in their item definition (from `item_defs.lua`) skip environmental checks entirely

**Storage building destruction:**
When a storage building is destroyed (deconstructed, combat, fire), all items in its slots are spawned as ground item entities at the building's position. These are then exposed to environmental decay normally.

### Existing System Retirement

**`src/sim/spoilage.lua`:**
- Currently tracks food spoilage colony-wide based on temperature
- Replaced by per-item decay: food items on the ground lose durability based on tile temperature
- Food in cold storage buildings is preserved (not an ECS entity, no decay)
- `spoilage.lua` retired after sub-project 4 is complete

**`src/sim/deterioration.lua`:**
- Currently handles building durability decay from weather
- Remains unchanged — building deterioration is separate from item decay
- Both systems coexist: buildings degrade via deterioration.lua, items via item_decay.lua

### Remove Arbitrary 10-Minute Decay

Current `items.lua` has a `DECAY_TIME = 600` (10 minutes) that destroys all ground items. This is removed entirely. Items persist on the ground indefinitely unless damaged by environmental conditions or manually deconstructed.

---

## Files Summary

### Sub-Project 1: Physical Items

| File | Action | Description |
|------|--------|-------------|
| `src/world/items.lua` | MODIFY | Remove DECAY_TIME, add weight/durability fields, expand spawn() |
| `src/world/item_defs.lua` | NEW | Item definitions table (weights, categories, immunities, stacking rules) |
| `src/game_state.lua` | MODIFY | Add compatibility shim wrappers, remove physical resource counters incrementally |
| `src/colonist/work_ai.lua` | MODIFY | Replace addResource() with Items.spawn() in mining/production |
| `src/colonist/jobs.lua` | MODIFY | Update haul tasks for weight-based carrying |
| `src/colonist/colonist.lua` | MODIFY | Implement weight-based carry capacity, drop items on death |
| `src/world/tilemap.lua` | MODIFY | Mining output → item spawn instead of counter |
| `src/building/miners.lua` | MODIFY | Replace addResource() with Items.spawn() in existing miner buildings |
| `src/building/processing.lua` | NEW | Smelter, sawmill, stonecutter, centrifuge, forge, refiner machine logic |
| `src/building/machine_defs.lua` | NEW | Processing recipe definitions (input/output/time) |
| `src/logistics/conveyors.lua` | MODIFY | Extend belt item tables with quality/material/durability fields |
| `src/logistics/inserters.lua` | MODIFY | Handle extended belt item data at conversion boundaries |
| `src/storyteller/storyteller.lua` | MODIFY | Migrate ~11 addResource calls to Items.spawn |
| `src/trade/merchants.lua` | MODIFY | Migrate trade to physical items |
| `src/creatures/eldritch_nodes.lua` | MODIFY | Migrate ~7 addResource calls |
| `src/quest/quest.lua` | MODIFY | Migrate quest reward calls |
| Plus ~15 more files | MODIFY | See migration audit in GameState.resources Migration section |

### Sub-Project 2: Storage Buildings

| File | Action | Description |
|------|--------|-------------|
| `src/building/storage.lua` | NEW | Storage building definitions, slot management |
| `src/logistics/storage_network.lua` | NEW | Power-grid networked inventory queries |
| `src/world/zones.lua` | MODIFY | Integrate zone + storage building hauling priority |
| `src/building/building.lua` | MODIFY | Add storage building types to building registry |
| `src/colonist/work_ai.lua` | MODIFY | Build/craft recipes use StorageNetwork.query() |

### Sub-Project 3: Clothing

| File | Action | Description |
|------|--------|-------------|
| `src/colonist/clothing.lua` | NEW | Clothing definitions, slot management, protection calc, multiSlot logic |
| `src/colonist/clothing_defs.lua` | NEW | Clothing item definitions (stats per piece, per planet) |
| `src/colonist/equipment.lua` | MODIFY | Migrate armor to clothing system, rewrite autoEquip for physical items |
| `src/colonist/suits.lua` | DELETE | Functionality absorbed into clothing.lua (thermal suits → outer slot clothing) |
| `src/colonist/health.lua` | MODIFY | Add heatstroke, radiation sickness, pressure damage, toxic exposure stages |
| `src/ui/equip_panel.lua` | MODIFY | Show 5 clothing slots + weapons + accessories |
| `src/colonist/colonist.lua` | MODIFY | Add clothing component with 5 slots |

### Sub-Project 4: Environmental Decay

| File | Action | Description |
|------|--------|-------------|
| `src/world/item_decay.lua` | NEW | ECS system for environment-driven durability damage |
| `src/world/items.lua` | MODIFY | Remove DECAY_TIME, add durability checks |
| `src/building/storage.lua` | MODIFY | Spawn ground items on building destruction |
| `src/sim/spoilage.lua` | DELETE | Replaced by per-item food decay in item_decay.lua |

### Persistence

**New components for `KNOWN_COMPONENTS` in `save.lua`:**
- `storage` — storage building slot data
- `clothing` — worn clothing with durability and protection stats
- `carrying` — colonist carry state (items being hauled, for mid-haul save/load)
- `machine` — processing machine state (input buffer, output buffer, progress timer)
- Updated `item` component — new fields: weight, durability (remove old `protected` field if present)

**Systems to re-register in `Save.load()` after `ECS.init()`:**
- `ItemDecay.registerSystems()` — environmental decay ticks
- `Clothing.registerSystems()` — wear degradation ticks
- Processing machine systems (from `processing.lua`)

**StorageNetwork runtime state:**
- Does NOT need separate persistence — reconstructed on load from ECS state
- On load: scan all entities with `storage` + `power` components, rebuild network membership from power grid connectivity (same pattern as existing power system rebuild in save.lua lines 670-777)

**Save version bump:**
- Increment save version number to detect pre-migration saves
- Old save load path: convert `GameState.resources` counters to physical item entities (one-time migration)

---

## Dependencies

- Existing ECS system (`src/ecs/ecs.lua`) — items are entities, no changes needed
- Existing power grid (`src/systems/power.lua`) — storage network piggybacks on power connectivity
- Existing thermal system — clothing protection feeds into existing temperature calculations
- Existing conveyor/inserter systems — modified to handle physical items
- Existing zone system — extended with storage building priority
- Existing pathfinding — colonists path to nearest storage source

## Out of Scope

- Crafting recipe UI overhaul (current recipe system works, just needs to query storage network)
- Trade UI changes (traders buy/sell physical items — requires rework but separate project)
- Visual item rendering on ground/shelves (art task, not system design)
- Item sorting/organization AI (colonists auto-haul by priority, no complex sorting logic)
