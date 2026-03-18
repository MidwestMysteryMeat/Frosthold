# Clothing/Apparel System — Implementation Plan (Sub-Project 3 of 4)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5-slot clothing system (under, outer, head, hands, feet) with environmental protection stats (cold, heat, pressure, radiation, toxicity), degradation from wear/combat/environment, and migrate existing armor/suits into the new system.

**Architecture:** New `clothing.lua` manages 5 wearable slots on colonists alongside existing weapon/accessory equipment. `clothing_defs.lua` defines all clothing items with protection stats. Existing armor types become outer-slot clothing. Existing suits.lua is absorbed. Health effects extended with heatstroke, radiation sickness, pressure damage, and toxic exposure stages mirroring the existing hypothermia system.

**Tech Stack:** Love2D 11.4, Lua 5.1/LuaJIT, sparse-set ECS

**Spec:** `docs/superpowers/specs/2026-03-15-physical-items-design.md` (Sub-Project 3)

---

## Chunk 1: Clothing Definitions + Component

### Task 1: Create clothing definitions

**Files:**
- Create: `src/colonist/clothing_defs.lua`

- [ ] **Step 1: Create clothing_defs.lua**

Define all clothing items. Each has: slot, protection stats (cold/heat/pressure/radiation/toxicity), durability, armor, speed/work modifiers, material, and optional multiSlot for space suits.

```lua
local ClothingDefs = {}

ClothingDefs.ITEMS = {
    -- UNDER LAYER
    thermal_undershirt = {
        slot = 'under', name = 'Thermal Undershirt',
        cold = 15, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 0, speedMod = 0, workMod = 0,
        material = 'cloth', cost = { cloth = 3 },
    },
    cooling_vest = {
        slot = 'under', name = 'Cooling Vest',
        cold = 5, heat = 20, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 0, speedMod = 0, workMod = 0,
        material = 'cloth', cost = { cloth = 2, components = 1 },
    },
    rad_suit_liner = {
        slot = 'under', name = 'Rad-Suit Liner',
        cold = 5, heat = 5, pressure = 10, radiation = 20, toxicity = 10,
        maxDurability = 80, armor = 0, speedMod = 0, workMod = -0.05,
        material = 'cloth', cost = { cloth = 2, lead = 1 },
    },

    -- OUTER LAYER (includes migrated armor)
    hide_coat = {
        slot = 'outer', name = 'Hide Coat',
        cold = 25, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 3, speedMod = 0, workMod = 0,
        material = 'hide', cost = { hide = 4 },
    },
    leather_armor = {
        slot = 'outer', name = 'Leather Armor',
        cold = 15, heat = 8, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 5, speedMod = -0.05, workMod = 0,
        material = 'hide', cost = { hide = 6 },
    },
    metal_plate = {
        slot = 'outer', name = 'Metal Plate Armor',
        cold = 5, heat = 5, pressure = 5, radiation = 5, toxicity = 0,
        maxDurability = 150, armor = 10, speedMod = -0.15, workMod = -0.10,
        material = 'metal', cost = { metal = 8 },
    },
    parka = {
        slot = 'outer', name = 'Parka',
        cold = 35, heat = 0, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 2, speedMod = -0.05, workMod = 0,
        material = 'cloth', cost = { cloth = 5, hide = 2 },
    },
    thermal_suit = {
        slot = 'outer', name = 'Thermal Suit',
        cold = 50, heat = 10, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 4, speedMod = -0.05, workMod = 0,
        material = 'insulation', cost = { insulation = 3, metal = 2, circuit = 1 },
    },
    hazmat_suit = {
        slot = 'outer', name = 'Hazmat Suit',
        cold = 10, heat = 15, pressure = 20, radiation = 30, toxicity = 50,
        maxDurability = 80, armor = 2, speedMod = -0.10, workMod = -0.10,
        material = 'cloth', cost = { cloth = 4, components = 2, glass = 1 },
    },
    acid_cloak = {
        slot = 'outer', name = 'Acid Cloak',
        cold = 10, heat = 10, pressure = 0, radiation = 0, toxicity = 40,
        maxDurability = 60, armor = 1, speedMod = 0, workMod = 0,
        material = 'hide', cost = { hide = 3, glass = 2 },
    },
    exosuit = {
        slot = 'outer', name = 'Exosuit',
        cold = 30, heat = 15, pressure = 10, radiation = 5, toxicity = 5,
        maxDurability = 100, armor = 8, speedMod = 0.10, workMod = 0.05,
        material = 'steel', cost = { steel = 5, circuit = 3 },
        carryMod = 0.5, damageMod = 1.0,
    },

    -- HEAD
    wool_hat = {
        slot = 'head', name = 'Wool Hat',
        cold = 15, heat = 0, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 80, armor = 0, speedMod = 0, workMod = 0,
        material = 'cloth', cost = { cloth = 2 },
    },
    helmet = {
        slot = 'head', name = 'Helmet',
        cold = 5, heat = 5, pressure = 5, radiation = 0, toxicity = 0,
        maxDurability = 120, armor = 5, speedMod = 0, workMod = 0,
        material = 'metal', cost = { metal = 4 },
    },
    rebreather = {
        slot = 'head', name = 'Rebreather',
        cold = 5, heat = 5, pressure = 15, radiation = 5, toxicity = 30,
        maxDurability = 80, armor = 1, speedMod = 0, workMod = -0.05,
        material = 'components', cost = { components = 3, glass = 1 },
    },
    rad_hood = {
        slot = 'head', name = 'Radiation Hood',
        cold = 10, heat = 5, pressure = 0, radiation = 25, toxicity = 10,
        maxDurability = 80, armor = 1, speedMod = 0, workMod = 0,
        material = 'cloth', cost = { cloth = 2, lead = 2 },
    },

    -- HANDS
    insulated_gloves = {
        slot = 'hands', name = 'Insulated Gloves',
        cold = 15, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 80, armor = 1, speedMod = 0, workMod = -0.05,
        material = 'cloth', cost = { cloth = 2 },
    },
    work_gloves = {
        slot = 'hands', name = 'Work Gloves',
        cold = 5, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 2, speedMod = 0, workMod = 0.05,
        material = 'hide', cost = { hide = 2 },
    },
    rad_gauntlets = {
        slot = 'hands', name = 'Radiation Gauntlets',
        cold = 5, heat = 5, pressure = 5, radiation = 20, toxicity = 5,
        maxDurability = 80, armor = 2, speedMod = 0, workMod = -0.10,
        material = 'metal', cost = { metal = 3, lead = 1 },
    },

    -- FEET
    boots = {
        slot = 'feet', name = 'Boots',
        cold = 10, heat = 5, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 2, speedMod = 0, workMod = 0,
        material = 'hide', cost = { hide = 3 },
    },
    insulated_boots = {
        slot = 'feet', name = 'Insulated Boots',
        cold = 20, heat = 0, pressure = 0, radiation = 0, toxicity = 0,
        maxDurability = 100, armor = 2, speedMod = -0.05, workMod = 0,
        material = 'hide', cost = { hide = 3, cloth = 1 },
    },
    mag_boots = {
        slot = 'feet', name = 'Mag-Boots',
        cold = 5, heat = 5, pressure = 20, radiation = 0, toxicity = 0,
        maxDurability = 80, armor = 3, speedMod = -0.10, workMod = 0,
        material = 'metal', cost = { metal = 4, components = 2 },
    },

    -- MULTI-SLOT: SPACE SUIT
    space_suit = {
        slot = 'outer', name = 'Space Suit',
        multiSlot = { 'outer', 'head', 'hands', 'feet' },
        cold = 40, heat = 20, pressure = 90, radiation = 70, toxicity = 30,
        maxDurability = 100, armor = 5, speedMod = -0.15, workMod = -0.10,
        material = 'steel', cost = { steel = 10, glass = 5, circuit = 3, cloth = 4 },
        o2MaxTank = 100, o2DrainRate = 2.0,
    },
}

function ClothingDefs.get(clothingId)
    return ClothingDefs.ITEMS[clothingId]
end

function ClothingDefs.getBySlot(slot)
    local result = {}
    for id, def in pairs(ClothingDefs.ITEMS) do
        if def.slot == slot then
            result[#result + 1] = { id = id, def = def }
        end
    end
    return result
end

return ClothingDefs
```

- [ ] **Step 2: Commit**

---

### Task 2: Create clothing component and management module

**Files:**
- Create: `src/colonist/clothing.lua`

- [ ] **Step 1: Create clothing.lua**

The clothing component stores 5 slots on a colonist. Each slot holds a worn item with current durability.

Key functions:
- `Clothing.attach(entityId)` — adds empty clothing component
- `Clothing.equip(entityId, clothingId, quality)` — equip clothing in appropriate slot(s)
- `Clothing.unequip(entityId, slot)` — remove clothing from slot
- `Clothing.getProtection(entityId)` — sum protection across all slots
- `Clothing.degradeWear(entityId, dt)` — passive wear degradation
- `Clothing.degradeCombat(entityId, slot, damage)` — combat hit degradation
- `Clothing.repair(entityId, slot)` — restore durability

Clothing component structure:
```lua
clothing = {
    under = nil,  -- { id, name, cold, heat, pressure, radiation, toxicity, durability, maxDurability, armor, speedMod, workMod, material, quality }
    outer = nil,
    head = nil,
    hands = nil,
    feet = nil,
}
```

multiSlot items (space suit): equipping sets the same item reference in all listed slots. Unequipping any slot clears all.

- [ ] **Step 2: Register clothing degradation ECS system**

Register a system that ticks every sim step:
- Passive wear: -0.1 durability/game-hour per worn item
- Work activities: 2x rate if colonist is performing work (state ~= 'idle')
- At 0 durability: destroy the item, clear slot, fire notification
- At 25%: warning notification
- At 10%: critical warning

- [ ] **Step 3: Add 'clothing' to KNOWN_COMPONENTS**

In `src/persistence/save_helpers.lua`, add `'clothing'`.

- [ ] **Step 4: Commit**

---

### Task 3: Wire clothing to colonist spawn and equipment system

**Files:**
- Modify: `src/colonist/colonist.lua`
- Modify: `src/colonist/equipment.lua`

- [ ] **Step 1: Attach clothing component on colonist spawn**

In `Colonist._attachCombatComponents(id)` (line ~368-373), add:
```lua
local cok, ClothingMod = pcall(require, 'src.colonist.clothing')
if cok then ClothingMod.attach(id) end
```

- [ ] **Step 2: Migrate armor from equipment to clothing**

In `equipment.lua`:
- Remove `ARMORS` table (line 79-109)
- Remove `equipArmor()`, `unequipArmor()`, `getArmorReduction()`, `getTypedResist()`, `getArmorResist()`, `getArmorQuality()`, `bestAvailableArmor()`
- Change `getArmorReduction(entityId)` to query `Clothing.getProtection(entityId).armor` instead
- Change `getTypedResist(entityId, damageType)` to map clothing protection stats to resist values
- Update `autoEquip()` to equip clothing items instead of armor from resource counters

OR simpler approach: keep `equipment.lua` functions as thin wrappers that delegate to `Clothing`:

```lua
function Equipment.getArmorReduction(entityId)
    local ok, Clothing = pcall(require, 'src.colonist.clothing')
    if ok then
        local prot = Clothing.getProtection(entityId)
        return prot.armor or 0
    end
    return 0
end
```

- [ ] **Step 3: Delete suits.lua system registration**

In `src/colonist/suits.lua`, find where `Suits.registerSystems()` is called. The suit degradation system should be replaced by clothing degradation. Either:
- Remove the `registerSystems` call entirely
- Or make `Suits.equip()` delegate to `Clothing.equip()` for backward compatibility

For now, keep `suits.lua` alive but have it delegate to clothing.lua. Full deletion happens after all callers are migrated.

- [ ] **Step 4: Commit**

---

## Chunk 2: Health Effects + Protection Calculation

### Task 4: Add new health effect stages

**Files:**
- Modify: `src/colonist/colonist.lua`

- [ ] **Step 1: Add heatstroke stages (mirrors hypothermia)**

Next to the existing `HYPOTHERMIA` table (line ~383), add:

```lua
local HEATSTROKE = {
    { name = 'normal',     maxHeat = 40, workMult = 1.0, moveMult = 1.0, healthDrain = 0,   morale = 0 },
    { name = 'warm',       maxHeat = 60, workMult = 0.9, moveMult = 1.0, healthDrain = 0,   morale = -1 },
    { name = 'overheated', maxHeat = 75, workMult = 0.7, moveMult = 0.9, healthDrain = 0,   morale = -3 },
    { name = 'heat_stroke',maxHeat = 90, workMult = 0.5, moveMult = 0.7, healthDrain = 0.5, morale = -6 },
    { name = 'severe_heat',maxHeat = 999,workMult = 0.2, moveMult = 0.5, healthDrain = 2,   morale = -10 },
}

local RADIATION_SICKNESS = {
    { name = 'normal',       maxRad = 10,  workMult = 1.0, moveMult = 1.0, healthDrain = 0,   morale = 0 },
    { name = 'mild_exposure',maxRad = 30,  workMult = 0.9, moveMult = 1.0, healthDrain = 0,   morale = -1 },
    { name = 'rad_sickness', maxRad = 50,  workMult = 0.7, moveMult = 0.8, healthDrain = 0.3, morale = -4 },
    { name = 'acute_rad',    maxRad = 75,  workMult = 0.4, moveMult = 0.6, healthDrain = 1.0, morale = -8 },
    { name = 'lethal_rad',   maxRad = 999, workMult = 0.1, moveMult = 0.3, healthDrain = 3.0, morale = -15 },
}

local PRESSURE_DAMAGE = {
    { name = 'normal',        maxDef = 0,   healthDrain = 0 },
    { name = 'mild_exposure', maxDef = 30,  healthDrain = 1.0 },
    { name = 'severe',        maxDef = 60,  healthDrain = 5.0 },
    { name = 'critical',      maxDef = 999, healthDrain = 15.0 },
}

local TOXIC_EXPOSURE = {
    { name = 'normal',      maxTox = 10,  workMult = 1.0, moveMult = 1.0, healthDrain = 0,   morale = 0 },
    { name = 'irritation',  maxTox = 30,  workMult = 0.9, moveMult = 1.0, healthDrain = 0,   morale = -2 },
    { name = 'poisoned',    maxTox = 50,  workMult = 0.6, moveMult = 0.8, healthDrain = 0.5, morale = -5 },
    { name = 'toxic_shock', maxTox = 999, workMult = 0.3, moveMult = 0.5, healthDrain = 2.0, morale = -10 },
}
```

- [ ] **Step 2: Integrate clothing protection into temperature damage**

Find the needsDecaySystem (line ~436) where cold damage is calculated. Currently uses `coldResist` from suits. Change to query `Clothing.getProtection()`:

```lua
local cok, Clothing = pcall(require, 'src.colonist.clothing')
local protection = cok and Clothing.getProtection(id) or { cold = 0, heat = 0, radiation = 0, pressure = 0, toxicity = 0 }

-- Cold damage: deficit = environment demand - protection
local envCold = math.max(0, (10 - tileTemp) * 2)  -- scale temperature to demand
local coldDeficit = math.max(0, envCold - protection.cold)
if coldDeficit > 0 then
    needs.warmth = math.max(0, needs.warmth - coldDeficit * 0.02 * dt)
end
```

- [ ] **Step 3: Add radiation/pressure/toxicity needs to colonist component**

Add new fields to the colonist needs component:
```lua
needs.radiation = 0      -- 0-100 radiation exposure level
needs.pressure = 0       -- 0-100 pressure exposure level
needs.toxicity = 0       -- 0-100 toxic exposure level
```

These accumulate when protection deficit exists and decrease when protected.

- [ ] **Step 4: Apply health effects from new stages**

In the needs decay system, after hypothermia processing, add heatstroke/radiation/pressure/toxicity damage using the same pattern.

- [ ] **Step 5: Commit**

---

## Chunk 3: Equipment Panel Update

### Task 5: Update equip panel for 5 clothing slots

**Files:**
- Modify: `src/ui/equip_panel.lua`

- [ ] **Step 1: Expand slot display from 3 to 8 slots**

Current: weapon, armor, accessory (3 slots)
New: weapon, under, outer, head, hands, feet, accessory (7 slots)

Change the slots array in the gear detail view:
```lua
local Clothing = require('src.colonist.clothing')
local clothingComp = Clothing and Clothing.getComponent(selectedColonist)

slots = {
    { key = 'weapon',    label = 'WEAPON',    data = equip.weapon,    type = 'equipment' },
    { key = 'under',     label = 'UNDER',     data = clothingComp and clothingComp.under,  type = 'clothing' },
    { key = 'outer',     label = 'OUTER',     data = clothingComp and clothingComp.outer,  type = 'clothing' },
    { key = 'head',      label = 'HEAD',      data = clothingComp and clothingComp.head,   type = 'clothing' },
    { key = 'hands',     label = 'HANDS',     data = clothingComp and clothingComp.hands,  type = 'clothing' },
    { key = 'feet',      label = 'FEET',      data = clothingComp and clothingComp.feet,   type = 'clothing' },
    { key = 'accessory', label = 'ACCESSORY', data = equip.accessory, type = 'equipment' },
}
```

- [ ] **Step 2: Update slot card display for clothing items**

For clothing slots, show:
- Item name + quality
- Durability bar (green → yellow → red)
- Protection stats: `Cold: +X  Heat: +X  Rad: +X`
- Armor value if > 0

- [ ] **Step 3: Update item picker for clothing**

When picking for a clothing slot, list items from `ClothingDefs.getBySlot(slot)` instead of equipment lists.

- [ ] **Step 4: Add protection summary**

At the top of the gear detail view, show total protection across all clothing:
```
Protection — Cold: 85  Heat: 30  Pressure: 0  Radiation: 25  Toxicity: 0
```

- [ ] **Step 5: Commit**

---

## Chunk 4: Integration

### Task 6: Register systems and test

**Files:**
- Modify: `main.lua` (if needed for system registration)
- Modify: `src/persistence/save.lua` (re-register clothing systems on load)

- [ ] **Step 1: Ensure clothing system registered in main.lua**

If `Clothing.registerSystems()` isn't auto-called on require, add the registration call to main.lua near where Equipment and Suits systems are registered.

- [ ] **Step 2: Register clothing systems in save.lua load path**

In `Save.load()`, after `ECS.init()`, add:
```lua
local cok, Clothing = pcall(require, 'src.colonist.clothing')
if cok and Clothing.registerSystems then Clothing.registerSystems() end
```

- [ ] **Step 3: Test — equip clothing, verify protection stats**

Launch game, open equip panel (V), equip a parka (outer slot). Verify:
- Protection summary shows Cold: 35
- Colonist takes less cold damage
- Durability ticks down slowly

- [ ] **Step 4: Test — clothing degrades and breaks**

Use debug to set durability to 5. Verify warning notification. Let it hit 0 — clothing should be destroyed and removed from slot.

- [ ] **Step 5: Test — save/load with clothing**

Equip clothing, save, load. Clothing should persist in all slots with correct durability.

- [ ] **Step 6: Commit**
