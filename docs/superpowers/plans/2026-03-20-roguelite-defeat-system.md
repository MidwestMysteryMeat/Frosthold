# Roguelite Defeat System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework colony defeat from a dead-end into a roguelite meta-progression loop with persistent MRP currency, ruins, data discs, SOS Beacon, nemesis system, and planet history.

**Architecture:** New meta-save file (`frosthold_campaign.dat`) stores cross-run state (MRP, unlocks, planet history, nemeses). Colony legacy records are expanded to capture buildings, research, colonists for ruin spawning. New ECS buildings (SOS Beacon, Data Recovery Terminal) replace the automatic safety net. Game flow gains two new phases (requisition screens) between planet select and landing.

**Tech Stack:** Love2D 11.4, Lua 5.1/LuaJIT, custom sparse-set ECS

**Spec:** `docs/superpowers/specs/2026-03-20-roguelite-defeat-system-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|---|---|
| `src/sim/mrp.lua` | MRP economy: campaign persistence, earning, spending, permanent unlocks, per-run picks, tier thresholds |
| `src/sim/nemesis.lua` | Nemesis roster: create from raid data, persist per-planet, inject into raids, storyteller hooks |
| `src/sim/ruin_spawner.lua` | On redeployment: spawn building ruins, data discs, resource crates, graves from legacy record |
| `src/building/sos_beacon.lua` | SOS Beacon ECS system: power check, all-downed detection, countdown, colonist drop, burn-out |
| `src/building/data_terminal.lua` | Data Recovery Terminal ECS system: disc processing, research unlock/progress |
| `src/ui/requisition_panel.lua` | Mammona Requisition screen: permanent unlock tree + per-run pick shop |
| `src/ui/planet_history.lua` | Planet history timeline panel: scrollable deployment history per planet |
| `tests/test_mrp.lua` | Tests for MRP earning, spending, persistence, unlock tiers |
| `tests/test_nemesis.lua` | Tests for nemesis creation, cap, roster management |
| `tests/test_ruin_spawner.lua` | Tests for ruin/disc/crate/grave spawning from legacy data |
| `tests/test_sos_beacon.lua` | Tests for SOS Beacon firing, power dependency, burn-out |

### Modified Files

| File | Changes |
|---|---|
| `src/game_state.lua` | Add `buildingsConstructed` counter; remove `mammonaSafetyNet`, `_safetyNetUsed` |
| `src/sim/colony_legacy.lua` | Expand `recordFallenColony` to capture buildings, research, colonists, nemeses, map seed; replace `frosthold_legacies.dat` with campaign integration |
| `src/ui/game_over.lua` | Remove safety net logic, remove endless-on-death; add MRP display, "Redeployment" button, victory MRP |
| `src/ui/planet_select.lua` | Add scarred card rendering, deployment badge, history panel trigger |
| `src/persistence/save.lua` | Persist `buildingsConstructed`; add `sos_beacon` and `data_terminal` to KNOWN_COMPONENTS; register new systems in `Save.load()` |
| `src/persistence/save_helpers.lua` | Add `sos_beacon`, `data_terminal` to KNOWN_COMPONENTS |
| `src/building/building_defs_core.lua` | Add SOS Beacon and Data Recovery Terminal building definitions |
| `src/building/building_placement.lua` | Increment `GameState.buildingsConstructed` on successful placement; add `sos_beacon` and `data_terminal` entity spawn branches |
| `src/sim/raids.lua` | Integrate nemesis system: inject named captains with buffs into raids |
| `src/research/research.lua` | Add `getCompletedList()`, `getInProgressList()` for legacy snapshot; add `applyDiscProgress(techId, progress)` for data terminal |
| `src/ui/build_menu.lua` | Add SOS Beacon and Data Recovery Terminal to build menu categories |
| `main.lua` | Add 'requisition_unlocks' and 'requisition_picks' phases; wire ruin spawner in `initGameWorld`; load campaign on startup; add "Continue Campaign" / "New Game" to menu flow |

---

## Task 1: Campaign Persistence Layer (`src/sim/mrp.lua`)

Foundation for everything. The meta-save file that persists MRP, unlocks, and planet history across runs.

**Files:**
- Create: `src/sim/mrp.lua`
- Create: `tests/test_mrp.lua`

- [ ] **Step 1: Write test for MRP module initialization**

```lua
-- tests/test_mrp.lua
local MRP = require('src.sim.mrp')

local function test_init()
    MRP.reset()
    assert(MRP.getBalance() == 0, 'balance starts at 0')
    assert(MRP.getLifetime() == 0, 'lifetime starts at 0')
    assert(#MRP.getUnlocks() == 0, 'no unlocks initially')
    assert(MRP.getTier() == 0, 'tier starts at 0')
    print('PASS: test_init')
end

test_init()
```

Run: `cd F:/IceRimworld && lua tests/test_mrp.lua`
Expected: FAIL (module not found)

- [ ] **Step 2: Write minimal MRP module — state management**

```lua
-- src/sim/mrp.lua
local Helpers
local _ok, _h = pcall(require, 'src.persistence.save_helpers')
if _ok then Helpers = _h end

local MRP = {}

local state = {
    balance = 0,
    lifetime = 0,
    unlocks = {},           -- set of unlockId = true
    planetHistory = {},     -- planetId -> { list of legacy records }
    nemesisRoster = {},     -- planetId -> { list of nemesis entries }
}

local TIER_THRESHOLDS = { 100, 250, 500, 1000 }

function MRP.reset()
    state.balance = 0
    state.lifetime = 0
    state.unlocks = {}
    state.planetHistory = {}
    state.nemesisRoster = {}
end

function MRP.getBalance()
    return state.balance
end

function MRP.getLifetime()
    return state.lifetime
end

function MRP.getUnlocks()
    local list = {}
    for id in pairs(state.unlocks) do
        list[#list + 1] = id
    end
    return list
end

function MRP.hasUnlock(unlockId)
    return state.unlocks[unlockId] == true
end

function MRP.getTier()
    local tier = 0
    for _, threshold in ipairs(TIER_THRESHOLDS) do
        if state.lifetime >= threshold then
            tier = tier + 1
        end
    end
    return tier
end

return MRP
```

Run: `cd F:/IceRimworld && lua tests/test_mrp.lua`
Expected: PASS

- [ ] **Step 3: Write tests for earning and spending MRP**

```lua
local function test_earn()
    MRP.reset()
    MRP.earn(25)
    assert(MRP.getBalance() == 25)
    assert(MRP.getLifetime() == 25)
    MRP.earn(80)
    assert(MRP.getBalance() == 105)
    assert(MRP.getLifetime() == 105)
    assert(MRP.getTier() == 1, 'tier 1 at 105 lifetime')
    print('PASS: test_earn')
end

local function test_spend()
    MRP.reset()
    MRP.earn(100)
    assert(MRP.spend(30) == true, 'spend succeeds')
    assert(MRP.getBalance() == 70)
    assert(MRP.getLifetime() == 100, 'lifetime unchanged by spending')
    assert(MRP.spend(80) == false, 'spend fails if insufficient')
    assert(MRP.getBalance() == 70, 'balance unchanged on failed spend')
    print('PASS: test_spend')
end
```

Run: `cd F:/IceRimworld && lua tests/test_mrp.lua`
Expected: FAIL (earn/spend not defined)

- [ ] **Step 4: Implement earn and spend**

Add to `src/sim/mrp.lua`:

```lua
function MRP.earn(amount)
    state.balance = state.balance + amount
    state.lifetime = state.lifetime + amount
end

function MRP.spend(amount)
    if amount > state.balance then return false end
    state.balance = state.balance - amount
    return true
end
```

Run: `cd F:/IceRimworld && lua tests/test_mrp.lua`
Expected: PASS

- [ ] **Step 5: Write tests for permanent unlocks**

```lua
local function test_unlocks()
    MRP.reset()
    MRP.earn(100)
    assert(MRP.purchaseUnlock('cold_adapted_genome', 50) == true)
    assert(MRP.hasUnlock('cold_adapted_genome') == true)
    assert(MRP.getBalance() == 50)
    -- Can't buy twice
    assert(MRP.purchaseUnlock('cold_adapted_genome', 50) == false)
    assert(MRP.getBalance() == 50, 'no double charge')
    -- Can't afford
    assert(MRP.purchaseUnlock('neural_plasticity', 60) == false)
    assert(MRP.getBalance() == 50)
    print('PASS: test_unlocks')
end
```

- [ ] **Step 6: Implement purchaseUnlock**

```lua
function MRP.purchaseUnlock(unlockId, cost)
    if state.unlocks[unlockId] then return false end
    if not MRP.spend(cost) then return false end
    state.unlocks[unlockId] = true
    return true
end
```

- [ ] **Step 7: Write tests for campaign save/load persistence**

```lua
local function test_persistence()
    MRP.reset()
    MRP.earn(200)
    MRP.purchaseUnlock('cold_adapted_genome', 50)
    MRP.addPlanetDeployment('erebus', {
        colonyName = 'Test Colony',
        daysSurvived = 30,
        causeOfDeath = 'all colonists dead',
    })
    MRP.save()

    MRP.reset()
    assert(MRP.getBalance() == 0, 'reset works')

    MRP.load()
    assert(MRP.getBalance() == 150, 'balance restored')
    assert(MRP.getLifetime() == 200, 'lifetime restored')
    assert(MRP.hasUnlock('cold_adapted_genome'), 'unlock restored')
    local history = MRP.getPlanetHistory('erebus')
    assert(#history == 1, 'planet history restored')
    assert(history[1].colonyName == 'Test Colony')
    print('PASS: test_persistence')
end
```

- [ ] **Step 8: Implement planet history, nemesis roster, save/load**

```lua
function MRP.addPlanetDeployment(planetId, record)
    if not state.planetHistory[planetId] then
        state.planetHistory[planetId] = {}
    end
    local history = state.planetHistory[planetId]
    history[#history + 1] = record
end

function MRP.getPlanetHistory(planetId)
    return state.planetHistory[planetId] or {}
end

function MRP.getDeploymentCount(planetId)
    local history = state.planetHistory[planetId]
    return history and #history or 0
end

function MRP.addNemesis(planetId, nemesis)
    if not state.nemesisRoster[planetId] then
        state.nemesisRoster[planetId] = {}
    end
    local roster = state.nemesisRoster[planetId]
    roster[#roster + 1] = nemesis
    -- Cap at 3 per planet, remove oldest
    while #roster > 3 do
        table.remove(roster, 1)
    end
end

function MRP.getNemeses(planetId)
    return state.nemesisRoster[planetId] or {}
end

-- Minimal serializer for headless tests (no love.filesystem or save_helpers dependency)
local function simpleSerialize(tbl, indent)
    indent = indent or ''
    local parts = {}
    local nextIndent = indent .. '  '
    for k, v in pairs(tbl) do
        local keyStr
        if type(k) == 'number' then
            keyStr = '[' .. k .. ']'
        else
            keyStr = '["' .. tostring(k) .. '"]'
        end
        if type(v) == 'table' then
            parts[#parts + 1] = nextIndent .. keyStr .. ' = ' .. simpleSerialize(v, nextIndent)
        elseif type(v) == 'string' then
            parts[#parts + 1] = nextIndent .. keyStr .. ' = ' .. string.format('%q', v)
        elseif type(v) == 'boolean' then
            parts[#parts + 1] = nextIndent .. keyStr .. ' = ' .. tostring(v)
        else
            parts[#parts + 1] = nextIndent .. keyStr .. ' = ' .. tostring(v)
        end
    end
    if #parts == 0 then return '{}' end
    return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}'
end

-- Persistence via love.filesystem (campaign file)
local CAMPAIGN_FILE = 'frosthold_campaign.dat'

function MRP.save()
    local data = {
        balance = state.balance,
        lifetime = state.lifetime,
        unlocks = state.unlocks,
        planetHistory = state.planetHistory,
        nemesisRoster = state.nemesisRoster,
    }
    local ok, lfs = pcall(function() return love.filesystem end)
    if ok and lfs then
        -- Helpers.serialize returns 'return {...}' — write directly
        local str = Helpers and Helpers.serialize(data) or ('return ' .. simpleSerialize(data))
        lfs.write(CAMPAIGN_FILE, str)
    else
        -- Fallback for tests: write to local file with simple serializer
        local str = 'return ' .. simpleSerialize(data)
        local f = io.open(CAMPAIGN_FILE, 'w')
        if f then
            f:write(str)
            f:close()
        end
    end
end

function MRP.load()
    local str
    local ok, lfs = pcall(function() return love.filesystem end)
    if ok and lfs and lfs.getInfo(CAMPAIGN_FILE) then
        str = lfs.read(CAMPAIGN_FILE)
    else
        local f = io.open(CAMPAIGN_FILE, 'r')
        if f then
            str = f:read('*a')
            f:close()
        end
    end
    if not str then return false end

    -- Helpers.serialize and simpleSerialize both produce 'return {...}'
    -- Use loadstring directly — do NOT prepend 'return' (already in the string)
    local fn = loadstring(str)
    if not fn then return false end
    local success, data = pcall(fn)
    if not success or type(data) ~= 'table' then return false end

    state.balance = data.balance or 0
    state.lifetime = data.lifetime or 0
    state.unlocks = data.unlocks or {}
    state.planetHistory = data.planetHistory or {}
    state.nemesisRoster = data.nemesisRoster or {}
    return true
end
```

Run: `cd F:/IceRimworld && lua tests/test_mrp.lua`
Expected: PASS

- [ ] **Step 9: Write test for MRP calculation from run stats**

```lua
local function test_calculate_mrp()
    MRP.reset()
    local stats = {
        daysSurvived = 30,
        raidsSurvived = 5,
        researchCompleted = 8,
        colonistsLost = 3,
        buildingsConstructed = 20,
        bossDamaged = 0,
        bossDefeated = 0,
        milestonesCompleted = 0,
        firstDeployment = true,
    }
    local earned = MRP.calculateRunMRP(stats)
    -- 30*1 + 5*5 + 8*3 + 3*2 + 20*1 + 0 + 0 + 0 + 10 = 30+25+24+6+20+10 = 115
    assert(earned == 115, 'expected 115, got ' .. earned)
    print('PASS: test_calculate_mrp')
end
```

- [ ] **Step 10: Implement calculateRunMRP**

```lua
function MRP.calculateRunMRP(stats)
    local total = 0
    total = total + (stats.daysSurvived or 0) * 1
    total = total + (stats.raidsSurvived or 0) * 5
    total = total + (stats.researchCompleted or 0) * 3
    total = total + (stats.colonistsLost or 0) * 2
    total = total + (stats.buildingsConstructed or 0) * 1
    total = total + (stats.bossDamaged or 0) * 25
    total = total + (stats.bossDefeated or 0) * 50
    total = total + (stats.milestonesCompleted or 0) * 40
    if stats.firstDeployment then total = total + 10 end
    return total
end
```

- [ ] **Step 11: Run all tests and commit**

Run: `cd F:/IceRimworld && lua tests/test_mrp.lua`
Expected: All PASS

```bash
git add src/sim/mrp.lua tests/test_mrp.lua
git commit -m "feat: MRP campaign persistence layer — earn, spend, unlocks, planet history, save/load"
```

---

## Task 2: Expand Colony Legacy Records (`src/sim/colony_legacy.lua`)

Expand the legacy record to capture everything needed for ruin spawning.

**Files:**
- Modify: `src/sim/colony_legacy.lua`
- Modify: `src/game_state.lua` (add `buildingsConstructed`)
- Modify: `src/building/building_placement.lua` (increment counter)
- Modify: `src/persistence/save.lua` (persist counter)

- [ ] **Step 1: Add `buildingsConstructed` to GameState**

In `src/game_state.lua`, find the init() function and add `buildingsConstructed = 0` to the state fields that get reset. Also add it near the other counter fields (like `raidsSurvived`).

- [ ] **Step 2: Increment counter in building_placement.lua**

In `src/building/building_placement.lua`, inside `Building.tryPlace()` after successful placement (after cost deduction, before return true), add:

```lua
GameState.buildingsConstructed = (GameState.buildingsConstructed or 0) + 1
```

- [ ] **Step 3: Persist `buildingsConstructed` in save.lua and save_helpers.lua**

In `src/persistence/save.lua` `restoreFromData()`, where GameState fields are restored (near line 59-60 where `mammonaSafetyNet` is restored), add:
```lua
GameState.buildingsConstructed = gs.buildingsConstructed or 0
```

In `src/persistence/save_helpers.lua` `buildSaveData()`, in the `gameState` table (around line 229, after the `_safetyNetUsed` line), add:
```lua
buildingsConstructed = GameState.buildingsConstructed or 0,
```

- [ ] **Step 4: Expand `recordFallenColony` in colony_legacy.lua**

Read `src/sim/colony_legacy.lua` fully. Replace the existing `recordFallenColony` function with an expanded version that captures:

```lua
function Legacy.recordFallenColony(causeOfDeath)
    local ECS = require('src.ecs.ecs')
    local GameState = require('src.game_state')

    -- Peak population (alive + dead)
    local peakPop = 0
    local totalKills = 0
    local colonistRecords = {}
    for id, comps in ECS.query('colonist') do
        peakPop = peakPop + 1
        totalKills = totalKills + (comps.colonist.kills or 0)
        local pos = comps.pos or {}
        colonistRecords[#colonistRecords + 1] = {
            name = comps.colonist.name or 'Unknown',
            backstory = comps.colonist.backstory or '',
            deathX = pos.x or 0,
            deathY = pos.y or 0,
            skills = comps.colonist.skills or {},
        }
    end

    -- Building snapshot
    local buildingRecords = {}
    for id, comps in ECS.query('building_ref', 'pos') do
        local dur = ECS.get(id, 'durability')
        buildingRecords[#buildingRecords + 1] = {
            defId = comps.building_ref.defId or 'unknown',
            x = comps.pos.x,
            y = comps.pos.y,
            hp = dur and dur.hp or 100,
            depth = comps.pos.depth or 0,
        }
    end

    -- Research snapshot
    local completedResearch = {}
    local inProgressResearch = {}
    local rok, Research = pcall(require, 'src.research.research')
    if rok then
        if Research.getCompletedList then
            completedResearch = Research.getCompletedList()
        end
        if Research.getInProgressList then
            inProgressResearch = Research.getInProgressList()
        end
    end

    -- Resource snapshot (all resources)
    local resources = {}
    for k, v in pairs(GameState.resources or {}) do
        if v > 0 then
            resources[k] = v
        end
    end

    -- Map seed
    local mapSeed
    local wok, World = pcall(require, 'src.world.tilemap')
    if wok and World.getLayerData then
        local layerData = World.getLayerData()
        if layerData and layerData.seed then
            mapSeed = layerData.seed
        end
    end

    local record = {
        planet = GameState.planet or 'erebus',
        colonyName = GameState.colonyName or 'Unnamed Colony',
        daysSurvived = GameState.day or 0,
        peakPopulation = peakPop,
        causeOfDeath = causeOfDeath,
        wealth = GameState.getColonyWealth(),
        raidsSurvived = GameState.raidsSurvived or 0,
        buildingsConstructed = GameState.buildingsConstructed or 0,
        bossesKilled = totalKills,
        timestamp = os.time(),
        resources = resources,
        completedResearch = completedResearch,
        inProgressResearch = inProgressResearch,
        buildings = buildingRecords,
        colonists = colonistRecords,
        nemeses = {},  -- filled by nemesis system if raid caused death
        mrpEarned = 0, -- calculated and set by game_over after recording
        x = GameState.startX or 0,
        y = GameState.startY or 0,
        mapSeed = mapSeed,
        worldSeed = GameState.worldSeedNumeric,
        worldMapHex = GameState.landingZone,
    }

    -- Store in MRP campaign system
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if mok then
        MRP.addPlanetDeployment(record.planet, record)
        MRP.save()
    end

    return record
end
```

- [ ] **Step 5: Add research helper functions**

In `src/research/research.lua`, add two new functions for legacy snapshot. **IMPORTANT:** The research module uses a flat `completed` set (nodeId = true), a single `current` node ID, and a single `progress` number — NOT per-node progress. The static `NODES` table has `cost` and `tier` fields.

Add after `Research.getProgressPercent()` (around line 881):

```lua
function Research.getCompletedList()
    local list = {}
    for nodeId, done in pairs(completed) do
        if done then
            local node = NODES[nodeId]
            list[#list + 1] = { techId = nodeId, tier = node and node.tier or 1 }
        end
    end
    return list
end

function Research.getInProgressList()
    if not current then return {} end
    local node = NODES[current]
    if not node then return {} end
    return {
        { techId = current, progress = progress / node.cost }
    }
end
```

- [ ] **Step 6: Commit**

```bash
git add src/sim/colony_legacy.lua src/game_state.lua src/building/building_placement.lua src/persistence/save.lua src/research/research.lua
git commit -m "feat: expanded colony legacy records — buildings, research, colonists, map seed"
```

---

## Task 3: Nemesis System (`src/sim/nemesis.lua`)

Track named enemies that persist across deployments.

**Files:**
- Create: `src/sim/nemesis.lua`
- Create: `tests/test_nemesis.lua`
- Modify: `src/sim/raids.lua` (inject nemeses into raids)

- [ ] **Step 1: Write nemesis creation test**

```lua
-- tests/test_nemesis.lua
local Nemesis = require('src.sim.nemesis')

local function test_create()
    local n = Nemesis.createFromRaid('Krag', 'Frostfall', 3, 'steel_axe')
    assert(n.name == 'Krag')
    assert(n.colonyName == 'Frostfall')
    assert(n.kills == 3)
    assert(n.lootedItem == 'steel_axe')
    assert(n.hpMult >= 1.10 and n.hpMult <= 1.15)
    assert(n.dmgMult >= 1.10 and n.dmgMult <= 1.15)
    assert(n.title:find('Frostfall'))
    print('PASS: test_create')
end

test_create()
```

- [ ] **Step 2: Implement nemesis module**

```lua
-- src/sim/nemesis.lua
local Nemesis = {}

local TITLES = {
    'Scavenger of %s',
    'Butcher of %s',
    'Ravager of %s',
    'Pillager of %s',
    'Conqueror of %s',
}

function Nemesis.createFromRaid(raiderName, colonyName, kills, lootedItem)
    local title = string.format(
        TITLES[math.random(#TITLES)],
        colonyName
    )
    return {
        name = raiderName,
        title = title,
        colonyName = colonyName,
        hpMult = 1.10 + math.random() * 0.05,
        dmgMult = 1.10 + math.random() * 0.05,
        lootedItem = lootedItem,
        kills = kills or 0,
    }
end

return Nemesis
```

- [ ] **Step 3: Write test for nemesis injection into raids**

Test that `Nemesis.getRaidNemesis(planetId)` returns a nemesis from the MRP roster for use in raid generation.

```lua
local function test_get_raid_nemesis()
    -- Requires MRP module for roster storage
    local ok, MRP = pcall(require, 'src.sim.mrp')
    if not ok then
        print('SKIP: test_get_raid_nemesis (MRP not available)')
        return
    end
    MRP.reset()
    local n = Nemesis.createFromRaid('Krag', 'Frostfall', 3, nil)
    MRP.addNemesis('erebus', n)

    local captain = Nemesis.getRaidNemesis('erebus')
    assert(captain ~= nil, 'should return a nemesis')
    assert(captain.name == 'Krag')
    print('PASS: test_get_raid_nemesis')
end
```

- [ ] **Step 4: Implement getRaidNemesis**

```lua
function Nemesis.getRaidNemesis(planetId)
    local ok, MRP = pcall(require, 'src.sim.mrp')
    if not ok then return nil end
    local roster = MRP.getNemeses(planetId)
    if #roster == 0 then return nil end
    -- 30% chance a nemesis leads any given raid
    if math.random() > 0.30 then return nil end
    return roster[math.random(#roster)]
end
```

- [ ] **Step 5: Integrate nemesis into raids.lua**

In `src/sim/raids.lua`, in `spawnWave()` (line 1036), after the wave's creatures are spawned but before the rival injection block (line 1066), add nemesis injection. The pattern follows the existing rival system:

```lua
    -- Inject nemesis leader for humanoid raids (first wave only)
    if typeDef.humanoid and wave == activeRaid.waves[1] then
        local nok, Nemesis = pcall(require, 'src.sim.nemesis')
        if nok then
            local nemCaptain = Nemesis.getRaidNemesis(GameState.planet)
            if nemCaptain then
                -- Pick the first spawned creature in this wave to be the nemesis
                if #wave.creatures > 0 then
                    local nemId = wave.creatures[1]
                    local cr = ECS.get(nemId, 'creature')
                    if cr then
                        -- Apply stat buffs
                        cr.maxHp = math.floor((cr.maxHp or 100) * nemCaptain.hpMult)
                        cr.hp = cr.maxHp
                        cr.damage = math.floor((cr.damage or 10) * nemCaptain.dmgMult)
                        -- Set nemesis identity
                        cr.name = nemCaptain.name
                        cr.title = nemCaptain.title
                        cr.isNemesis = true
                        cr.nemesisData = nemCaptain
                    end
                    -- Announce
                    Nemesis.announceNemesis(nemCaptain)
                end
            end
        end
    end
```

Also, in the raid end/retreat logic (around line 1096-1116), add nemesis revenge detection: when an entity with `cr.isNemesis` is killed, call `Nemesis.announceRevenge(cr.nemesisData)`.

- [ ] **Step 6: Add storyteller hooks for nemesis announcements**

In `src/sim/nemesis.lua`, add:

```lua
function Nemesis.announceNemesis(nemesis)
    local ok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if ok and Storyteller.logEvent then
        Storyteller.logEvent('nemesis',
            string.format('%s, %s, has been spotted nearby.',
                nemesis.name, nemesis.title))
    end
end

function Nemesis.announceRevenge(nemesis)
    local ok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if ok and Storyteller.logEvent then
        Storyteller.logEvent('nemesis',
            string.format('%s has fallen. The dead of %s are avenged.',
                nemesis.title, nemesis.colonyName))
    end
    -- Hope boost
    local hok, Hope = pcall(require, 'src.colony.hope')
    if hok and Hope.add then
        Hope.add(5, 'Avenged the fallen')
    end
end
```

- [ ] **Step 7: Commit**

```bash
git add src/sim/nemesis.lua tests/test_nemesis.lua src/sim/raids.lua
git commit -m "feat: nemesis system — named enemies persist across deployments with stat buffs"
```

---

## Task 4: SOS Beacon Building (`src/building/sos_beacon.lua`)

Replace automatic safety net with player-built emergency beacon.

**Files:**
- Create: `src/building/sos_beacon.lua`
- Modify: `src/building/building_defs_core.lua` (add def)
- Modify: `src/persistence/save_helpers.lua` (add to KNOWN_COMPONENTS)
- Modify: `src/persistence/save.lua` (register system on load)
- Modify: `src/ui/build_menu.lua` (add to menu)
- Modify: `src/research/research.lua` (add research node if needed)

- [ ] **Step 1: Add SOS Beacon building definition**

In `src/building/building_defs_core.lua`, add after `radio_beacon`:

```lua
sos_beacon = {
    name = 'SOS Beacon',
    desc = 'Emergency distress signal. When active and powered, fires automatically if all colonists are downed. Calls 2-3 emergency reinforcements. Burns out after one use.',
    w = 2, h = 2,
    tile = Tiles.FLOOR_METAL,
    cost = { metal = 25, components = 10, circuit = 5 },
    entitySpawn = 'sos_beacon',
    powerDraw = 15,
    category = 'colony',
},
```

- [ ] **Step 2: Add `sos_beacon` to KNOWN_COMPONENTS**

In `src/persistence/save_helpers.lua`, add `'sos_beacon'` to the KNOWN_COMPONENTS list.

- [ ] **Step 3: Write SOS Beacon ECS system**

```lua
-- src/building/sos_beacon.lua
local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local SOSBeacon = {}

local COUNTDOWN_DURATION = 30  -- seconds
local EMERGENCY_COLONISTS = 2

local function sosBeaconSystem(dt, id, comps)
    local beacon = comps.sos_beacon

    -- Check power
    local _Power
    local pok, p = pcall(require, 'src.building.power')
    if pok then _Power = p end
    if _Power then
        beacon.powered = _Power.isConsumerPowered(id)
    end

    -- Must be toggled on and powered
    if not beacon.active or not beacon.powered then
        beacon.countdown = nil
        return
    end

    -- Already fired
    if beacon.fired then return end

    -- Check if all colonists are downed
    local allDowned = true
    local anyAlive = false
    for cid, ccomps in ECS.query('colonist') do
        local col = ccomps.colonist
        if col.state ~= 'dead' then
            anyAlive = true
            if col.state ~= 'downed' and col.state ~= 'incapacitated' then
                allDowned = false
                break
            end
        end
    end

    if not anyAlive then
        -- Everyone is dead, beacon can't help
        beacon.countdown = nil
        return
    end

    if allDowned and not beacon.countdown then
        -- Start countdown
        beacon.countdown = COUNTDOWN_DURATION
        -- Power surge
        beacon.powerDraw = 50

        local aok, Alerts = pcall(require, 'src.ui.alerts')
        if aok and Alerts.send then
            Alerts.send('SOS Beacon Activated',
                'Distress signal transmitted. Reinforcements inbound in ' ..
                COUNTDOWN_DURATION .. ' seconds.',
                'critical')
        end
    elseif allDowned and beacon.countdown then
        beacon.countdown = beacon.countdown - dt
        if beacon.countdown <= 0 then
            -- Fire! Spawn emergency colonists
            local pos = comps.pos
            local cok, ColMod = pcall(require, 'src.colonist.colonist')
            if cok then
                local wok, World = pcall(require, 'src.world.tilemap')
                for i = 1, EMERGENCY_COLONISTS do
                    local sx, sy = pos.x, pos.y
                    if wok then
                        -- Find walkable tile near beacon
                        for r = 1, 8 do
                            local found = false
                            for dy = -r, r do
                                for dx = -r, r do
                                    if (math.abs(dx) == r or math.abs(dy) == r)
                                        and World.inBounds(sx + dx, sy + dy)
                                        and World.isWalkable(sx + dx, sy + dy, 0) then
                                        sx, sy = sx + dx, sy + dy
                                        found = true
                                        break
                                    end
                                end
                                if found then break end
                            end
                            if found then break end
                        end
                    end
                    ColMod.spawn(sx, sy, 0)
                end
            end

            -- Log event
            local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if sok and Storyteller.logEvent then
                Storyteller.logEvent('sos_beacon',
                    'SOS Beacon fired. Emergency reinforcements have arrived.')
            end

            -- Burn out — mark as fired, don't destroy mid-tick
            -- Entity stays alive with fired=true so game_over.lua can see the state.
            -- Visual: beacon becomes inactive husk. Player can deconstruct for scrap.
            beacon.fired = true
            beacon.active = false
            beacon.countdown = nil
        end
    elseif not allDowned then
        -- Crisis averted, reset countdown
        if beacon.countdown then
            beacon.countdown = nil
            beacon.powerDraw = 15
        end
    end
end

function SOSBeacon.registerSystems()
    ECS.addSystem('sos_beacon', { 'sos_beacon', 'pos' }, sosBeaconSystem, 5)
end

SOSBeacon.registerSystems()

return SOSBeacon
```

- [ ] **Step 4: Add system registration in save.lua**

In `src/persistence/save.lua`, in the system re-registration block inside `restoreFromData()`, add:

```lua
local sosOk, SOSBeacon = pcall(require, 'src.building.sos_beacon')
if sosOk and SOSBeacon.registerSystems then SOSBeacon.registerSystems() end
```

- [ ] **Step 5: Wire SOS Beacon entity spawn in building_placement.lua**

In `src/building/building_placement.lua`, add a new `elseif` branch after the `radio_beacon` branch (around line 126). Follow the exact same pattern:

```lua
        elseif def.entitySpawn == 'sos_beacon' then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local beaconId = ECS2.spawn()
            ECS2.set(beaconId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(beaconId, 'sos_beacon', {
                powered = false,
                active = false,
                fired = false,
                countdown = nil,
            })
            ECS2.set(beaconId, 'building_ref', { type = 'sos_beacon', defId = defId })
            Power.addConsumer(beaconId, def.powerDraw, x, y, 'critical')
```

- [ ] **Step 5b: Add SOS Beacon to build menu**

In `src/ui/build_menu.lua`, find where `radio_beacon` is listed and add `sos_beacon` in the same category.

- [ ] **Step 6: Modify game_over.lua to defer defeat when SOS Beacon is active**

In `src/ui/game_over.lua`, in `GameOver.step(dt)`, replace the safety net logic with SOS Beacon deferral:

```lua
-- Check if an active SOS beacon might save the colony
local sosActive = false
for id, comps in ECS.query('sos_beacon') do
    if comps.sos_beacon.active and comps.sos_beacon.powered
        and not comps.sos_beacon.fired then
        sosActive = true
        break
    end
end

if sosActive then
    -- Defer defeat check — beacon is counting down
    return
end
```

Remove the entire `mammonaSafetyNet` block (lines 97-154 in the original file).

- [ ] **Step 7: Remove safety net fields from GameState**

In `src/game_state.lua`, remove `mammonaSafetyNet` and `_safetyNetUsed` from the state table and from `init()`.

In `src/persistence/save.lua`, remove the lines that restore these fields. Leave the load path tolerant of old saves that have them (just don't read them).

- [ ] **Step 8: Commit**

```bash
git add src/building/sos_beacon.lua src/building/building_defs_core.lua src/persistence/save_helpers.lua src/persistence/save.lua src/ui/build_menu.lua src/ui/game_over.lua src/game_state.lua
git commit -m "feat: SOS Beacon building — replaces automatic safety net with player-built emergency beacon"
```

---

## Task 5: Data Recovery Terminal (`src/building/data_terminal.lua`)

Building that processes data discs to recover research.

**Files:**
- Create: `src/building/data_terminal.lua`
- Modify: `src/building/building_defs_core.lua` (add def)
- Modify: `src/persistence/save_helpers.lua` (add to KNOWN_COMPONENTS)
- Modify: `src/persistence/save.lua` (register system on load)
- Modify: `src/research/research.lua` (add `applyDiscProgress`)

- [ ] **Step 1: Add Data Recovery Terminal building definition**

In `src/building/building_defs_core.lua`:

```lua
data_terminal = {
    name = 'Data Recovery Terminal',
    desc = 'Processes data discs recovered from fallen colonies. Restores lost research. Requires a colonist with intellectual skill to operate.',
    w = 2, h = 2,
    tile = Tiles.FLOOR_METAL,
    cost = { metal = 20, components = 8, circuit = 3 },
    entitySpawn = 'data_terminal',
    powerDraw = 20,
    category = 'production',
},
```

- [ ] **Step 2: Add `data_terminal` to KNOWN_COMPONENTS**

In `src/persistence/save_helpers.lua`, add `'data_terminal'` to the KNOWN_COMPONENTS list.

- [ ] **Step 3: Add `applyDiscProgress` to research.lua**

In `src/research/research.lua`. **IMPORTANT:** The research module tracks only ONE active research (`current`) with a single `progress` value. `completed` is a set of `nodeId = true`. `NODES` is the static definition table.

Add after `Research.getInProgressList()`:

```lua
-- Apply progress from a recovered data disc
-- quality: 'intact' (full unlock), 'degraded' (50-75%), 'partial' (given fraction)
function Research.applyDiscProgress(techId, quality, partialFraction)
    local node = NODES[techId]
    if not node then return false end
    if completed[techId] then return false end  -- already known

    if quality == 'intact' then
        -- Directly complete this tech
        Research.complete(techId)
        return true
    elseif quality == 'degraded' then
        -- Set this tech as current with 50-75% pre-filled progress
        local bonus = node.cost * (0.50 + math.random() * 0.25)
        current = techId
        progress = math.max(progress or 0, bonus)
        return true
    elseif quality == 'partial' then
        -- Set this tech as current with given partial progress
        local bonus = node.cost * (partialFraction or 0.25)
        current = techId
        progress = math.max(progress or 0, bonus)
        return true
    end
    return false
end
```

Note: For 'degraded' and 'partial' quality, this sets the tech as the active research with pre-filled progress. If the player is already researching something else, the disc processing should queue or the Data Terminal system should check `current` before starting. The terminal system (data_terminal.lua) should only process a disc if `current` is nil or matches the disc's techId.

- [ ] **Step 4: Write Data Recovery Terminal ECS system**

```lua
-- src/building/data_terminal.lua
local ECS       = require('src.ecs.ecs')

local DataTerminal = {}

local PROCESS_TIME = 30  -- seconds to process one disc

local function dataTerminalSystem(dt, id, comps)
    local terminal = comps.data_terminal

    -- Check power
    local pok, Power = pcall(require, 'src.building.power')
    if pok then
        terminal.powered = Power.isConsumerPowered(id)
    end
    if not terminal.powered then return end

    -- Check if processing a disc
    if terminal.processingDisc then
        terminal.processTimer = (terminal.processTimer or PROCESS_TIME) - dt
        if terminal.processTimer <= 0 then
            -- Complete processing
            local rok, Research = pcall(require, 'src.research.research')
            if rok and Research.applyDiscProgress then
                local disc = terminal.processingDisc
                Research.applyDiscProgress(disc.techId, disc.quality, disc.partialFraction)
            end

            -- Log completion
            local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if sok and Storyteller.logEvent then
                Storyteller.logEvent('data_recovery',
                    string.format('Data disc processed: %s research recovered.',
                        terminal.processingDisc.techId))
            end

            -- Consume the disc (remove from terminal)
            terminal.processingDisc = nil
            terminal.processTimer = nil
        end
    end
end

function DataTerminal.registerSystems()
    ECS.addSystem('data_terminal', { 'data_terminal', 'pos' }, dataTerminalSystem, 48)
end

DataTerminal.registerSystems()

return DataTerminal
```

- [ ] **Step 5: Wire Data Terminal entity spawn in building_placement.lua**

In `src/building/building_placement.lua`, add a new `elseif` branch (near the SOS Beacon branch added in Task 4):

```lua
        elseif def.entitySpawn == 'data_terminal' then
            local Power = require('src.sim.power')
            local ECS2 = require('src.ecs.ecs')
            local termId = ECS2.spawn()
            ECS2.set(termId, 'pos', { x = x, y = y, depth = depth })
            ECS2.set(termId, 'data_terminal', {
                powered = false,
                processingDisc = nil,
                processTimer = nil,
            })
            ECS2.set(termId, 'building_ref', { type = 'data_terminal', defId = defId })
            Power.addConsumer(termId, def.powerDraw, x, y, 'low')
```

- [ ] **Step 5b: Register system in save.lua**

In `src/persistence/save.lua`, add system registration for data_terminal in the load path:

```lua
local dtOk, DataTerminal = pcall(require, 'src.building.data_terminal')
if dtOk and DataTerminal.registerSystems then DataTerminal.registerSystems() end
```

Also add power consumer re-registration for `data_terminal` and `sos_beacon` components in the Power rebuild block (around lines 860-916 in save.lua). Find the block that iterates entities to re-register power consumers and add:

```lua
if ECS.get(id, 'sos_beacon') then
    Power.addConsumer(id, 15, pos.x, pos.y, 'critical')
end
if ECS.get(id, 'data_terminal') then
    Power.addConsumer(id, 20, pos.x, pos.y, 'low')
end
```

- [ ] **Step 6: Commit**

```bash
git add src/building/data_terminal.lua src/building/building_defs_core.lua src/persistence/save_helpers.lua src/persistence/save.lua src/research/research.lua
git commit -m "feat: Data Recovery Terminal — processes data discs to restore research from fallen colonies"
```

---

## Task 6: Ruin Spawner (`src/sim/ruin_spawner.lua`)

Spawns building ruins, data discs, resource crates, and graves from legacy data on redeployment.

**Files:**
- Create: `src/sim/ruin_spawner.lua`
- Create: `tests/test_ruin_spawner.lua`

- [ ] **Step 1: Write ruin spawner module**

```lua
-- src/sim/ruin_spawner.lua
local ECS = require('src.ecs.ecs')

local RuinSpawner = {}

function RuinSpawner.spawnFromLegacy(record)
    if not record then return end

    RuinSpawner.spawnBuildingRuins(record.buildings or {})
    RuinSpawner.spawnDataDiscs(record.completedResearch or {}, record.inProgressResearch or {}, record)
    RuinSpawner.spawnResourceCrates(record.resources or {}, record)
    RuinSpawner.spawnGraves(record.colonists or {})
end

function RuinSpawner.spawnBuildingRuins(buildings)
    local wok, World = pcall(require, 'src.world.tilemap')

    for _, bldg in ipairs(buildings) do
        -- 20-30% chance of being destroyed entirely
        if math.random() < 0.25 then
            goto continue
        end

        -- Spawn as degraded building entity
        local id = ECS.spawn()
        ECS.set(id, 'pos', { x = bldg.x, y = bldg.y, depth = bldg.depth or 0 })
        ECS.set(id, 'building_ref', { defId = bldg.defId, isRuin = true })
        ECS.set(id, 'durability', { hp = math.floor((bldg.hp or 100) * 0.5), maxHp = bldg.hp or 100 })

        ::continue::
    end
end

function RuinSpawner.spawnDataDiscs(completedResearch, inProgressResearch, record)
    local baseX = record.x or 0
    local baseY = record.y or 0

    -- Completed research → data discs
    for _, research in ipairs(completedResearch) do
        local tier = research.tier or 1
        local quality = tier <= 2 and 'intact' or 'degraded'

        local id = ECS.spawn()
        -- Scatter near old base
        local ox = baseX + math.random(-8, 8)
        local oy = baseY + math.random(-8, 8)
        ECS.set(id, 'pos', { x = ox, y = oy, depth = 0 })
        ECS.set(id, 'item', {
            defId = 'data_disc',
            name = 'Data Disc: ' .. (research.techId or 'unknown'),
            dataDisc = {
                techId = research.techId,
                quality = quality,
                partialFraction = nil,
            },
        })
    end

    -- In-progress research → partial discs
    for _, research in ipairs(inProgressResearch) do
        local id = ECS.spawn()
        local ox = baseX + math.random(-8, 8)
        local oy = baseY + math.random(-8, 8)
        ECS.set(id, 'pos', { x = ox, y = oy, depth = 0 })
        ECS.set(id, 'item', {
            defId = 'data_disc',
            name = 'Partial Data Disc: ' .. (research.techId or 'unknown'),
            dataDisc = {
                techId = research.techId,
                quality = 'partial',
                partialFraction = (research.progress or 0) * 0.5, -- halved
            },
        })
    end
end

function RuinSpawner.spawnResourceCrates(resources, record)
    local baseX = record.x or 0
    local baseY = record.y or 0

    for resType, amount in pairs(resources) do
        -- 30-40% salvage
        local salvage = math.floor(amount * (0.30 + math.random() * 0.10))
        if salvage > 0 then
            local id = ECS.spawn()
            local ox = baseX + math.random(-10, 10)
            local oy = baseY + math.random(-10, 10)
            ECS.set(id, 'pos', { x = ox, y = oy, depth = 0 })
            ECS.set(id, 'item', {
                defId = 'salvage_crate',
                name = 'Salvage Crate (' .. resType .. ')',
                resource = resType,
                amount = salvage,
            })
        end
    end
end

function RuinSpawner.spawnGraves(colonists)
    for _, col in ipairs(colonists) do
        local id = ECS.spawn()
        ECS.set(id, 'pos', { x = col.deathX, y = col.deathY, depth = 0 })
        ECS.set(id, 'decoration', {
            name = 'Remains of ' .. (col.name or 'Unknown'),
            backstory = col.backstory or '',
            isGrave = true,
            buried = false,
            moodRadius = 5,
            moodEffect = -3,  -- "Remains of the fallen"
        })
    end
end

-- Get ruin positions for minimap icons (pierce fog)
function RuinSpawner.getRuinPositions(record)
    local positions = {}
    for _, bldg in ipairs(record.buildings or {}) do
        positions[#positions + 1] = { x = bldg.x, y = bldg.y }
    end
    return positions
end

return RuinSpawner
```

- [ ] **Step 2: Write basic test**

```lua
-- tests/test_ruin_spawner.lua
-- Requires ECS mock or real ECS
package.path = package.path .. ';./?.lua'
local ECS = require('src.ecs.ecs')
local RuinSpawner = require('src.sim.ruin_spawner')

local function test_spawn_graves()
    ECS.init()
    local colonists = {
        { name = 'Alice', backstory = 'Miner', deathX = 10, deathY = 20, skills = {} },
        { name = 'Bob', backstory = 'Doctor', deathX = 15, deathY = 25, skills = {} },
    }
    RuinSpawner.spawnGraves(colonists)
    local count = ECS.countWith('decoration')
    assert(count == 2, 'expected 2 graves, got ' .. count)
    print('PASS: test_spawn_graves')
end

local function test_spawn_data_discs()
    ECS.init()
    local completed = {
        { techId = 'basic_construction', tier = 1 },
        { techId = 'advanced_materials', tier = 3 },
    }
    local inProgress = {
        { techId = 'power_grid', progress = 0.6 },
    }
    RuinSpawner.spawnDataDiscs(completed, inProgress, { x = 0, y = 0 })
    local count = ECS.countWith('item')
    assert(count == 3, 'expected 3 discs, got ' .. count)
    print('PASS: test_spawn_data_discs')
end

test_spawn_graves()
test_spawn_data_discs()
```

- [ ] **Step 3: Commit**

```bash
git add src/sim/ruin_spawner.lua tests/test_ruin_spawner.lua
git commit -m "feat: ruin spawner — generates ruins, data discs, crates, graves from legacy data"
```

---

## Task 7: Defeat Screen Rework (`src/ui/game_over.lua`)

New defeat/victory screen with MRP display and redeployment flow.

**Files:**
- Modify: `src/ui/game_over.lua`

- [ ] **Step 1: Read current game_over.lua fully**

Understand the existing draw/input functions before modifying.

- [ ] **Step 2: Rework GameOver.step() — remove safety net, add MRP earning**

Replace the defeat block:

```lua
if aliveCount == 0 then
    state = 'defeat'
    reason = string.format('All colonists have perished on day %d.', GameState.day)
    GameState.paused = true

    -- Record legacy
    local lok, Legacy = pcall(require, 'src.sim.colony_legacy')
    if lok and Legacy.recordFallenColony then
        lastRecord = Legacy.recordFallenColony('all colonists dead')
    end

    -- Calculate and award MRP
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if mok then
        local rok, Research = pcall(require, 'src.research.research')
        local researchCount = 0
        if rok and Research.getCompletedList then
            researchCount = #Research.getCompletedList()
        end

        local firstDeploy = MRP.getDeploymentCount(GameState.planet) <= 1
        local stats = {
            daysSurvived = GameState.day,
            raidsSurvived = GameState.raidsSurvived or 0,
            researchCompleted = researchCount,
            colonistsLost = (lastRecord and lastRecord.peakPopulation or 0),
            buildingsConstructed = GameState.buildingsConstructed or 0,
            bossDamaged = 0,
            bossDefeated = 0,
            milestonesCompleted = 0,
            firstDeployment = firstDeploy,
        }
        mrpEarned = MRP.calculateRunMRP(stats)
        MRP.earn(mrpEarned)
        if lastRecord then lastRecord.mrpEarned = mrpEarned end
        MRP.save()
    end
end
```

Add module-level variables: `local lastRecord = nil` and `local mrpEarned = 0`.

- [ ] **Step 3: Rework GameOver.draw() — new defeat screen layout**

Replace the defeat drawing block with:

```lua
if state == 'defeat' then
    -- Title
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.print('COLONY LOST', midX - 60, midY - 120)

    -- Reason
    love.graphics.setColor(0.7, 0.5, 0.5)
    love.graphics.print(reason, midX - 150, midY - 80)

    -- Stats
    love.graphics.setColor(0.5, 0.5, 0.5)
    local y = midY - 50
    love.graphics.print(string.format('Days survived: %d', GameState.day), midX - 100, y); y = y + 20
    love.graphics.print(string.format('Raids survived: %d', GameState.raidsSurvived or 0), midX - 100, y); y = y + 20
    love.graphics.print(string.format('Buildings constructed: %d', GameState.buildingsConstructed or 0), midX - 100, y); y = y + 20

    -- MRP earned
    y = y + 10
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.print(string.format('REQUISITION POINTS EARNED: %d', mrpEarned), midX - 140, y)

    -- Buttons
    y = y + 40
    love.graphics.setColor(0.3, 0.8, 0.3)
    love.graphics.print('[R] Mammona Redeployment Authorized', midX - 160, y)
    y = y + 25
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print('[F9] Load Save', midX - 50, y)
end
```

- [ ] **Step 4: Rework GameOver.keypressed() — redeployment flow**

Replace the SPACE handler:

```lua
function GameOver.keypressed(key)
    if state == 'playing' then return false end

    if state == 'defeat' or state == 'victory' then
        if key == 'r' then
            -- Redeployment: return to planet select
            state = 'playing'
            GameState.paused = false
            -- Signal main.lua to go to planet select
            GameState._redeployment = true
            return true
        end
    end

    return false  -- let F9 (load) pass through
end
```

- [ ] **Step 5: Add victory MRP earning**

In `GameOver.triggerVictory()`, add MRP calculation similar to defeat but with milestone bonus.

- [ ] **Step 6: Remove rescue state drawing and input**

Remove the entire `state == 'rescue'` block from draw() and keypressed(). Remove the `'rescue'` state entirely.

- [ ] **Step 7: Commit**

```bash
git add src/ui/game_over.lua
git commit -m "feat: reworked defeat screen — MRP display, redeployment button, removed safety net"
```

---

## Task 8: Planet Select Rework (`src/ui/planet_select.lua`)

Scarred cards, deployment badges, history panel.

**Files:**
- Modify: `src/ui/planet_select.lua`
- Create: `src/ui/planet_history.lua`

- [ ] **Step 1: Read planet_select.lua fully**

Understand the card rendering system and selection flow.

- [ ] **Step 2: Add deployment badge and scar overlay to planet cards**

In the card drawing function, after rendering the planet card, add:

```lua
-- Deployment badge and scar overlay
local mok, MRP = pcall(require, 'src.sim.mrp')
if mok then
    local deployCount = MRP.getDeploymentCount(def.id)
    if deployCount > 0 then
        -- Scar overlay (progressively darker/redder with more deployments)
        local scarAlpha = math.min(deployCount * 0.08, 0.4)
        love.graphics.setColor(0.6, 0.1, 0.1, scarAlpha)
        love.graphics.rectangle('fill', cardX, cardY, cardW, cardH)

        -- Deployment badge
        love.graphics.setColor(0.9, 0.7, 0.2, 0.9)
        love.graphics.print('Deployment ' .. (deployCount + 1), cardX + 4, cardY + cardH - 18)
    end
end
```

- [ ] **Step 3: Write planet history panel**

```lua
-- src/ui/planet_history.lua
local PlanetHistory = {}

local visible = false
local planetId = nil
local scrollY = 0

function PlanetHistory.show(pId)
    planetId = pId
    visible = true
    scrollY = 0
end

function PlanetHistory.hide()
    visible = false
end

function PlanetHistory.isVisible()
    return visible
end

function PlanetHistory.draw()
    if not visible or not planetId then return end

    local mok, MRP = pcall(require, 'src.sim.mrp')
    if not mok then return end

    local history = MRP.getPlanetHistory(planetId)
    if #history == 0 then return end

    local sw, sh = love.graphics.getDimensions()
    local panelW = 400
    local panelH = math.min(#history * 100 + 60, sh - 100)
    local panelX = (sw - panelW) / 2
    local panelY = (sh - panelH) / 2

    -- Background
    love.graphics.setColor(0.08, 0.08, 0.12, 0.95)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 6)
    love.graphics.setColor(0.3, 0.3, 0.4, 0.8)
    love.graphics.rectangle('line', panelX, panelY, panelW, panelH, 6)

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.print('DEPLOYMENT HISTORY', panelX + 20, panelY + 15)

    -- Entries
    local y = panelY + 45 - scrollY
    for i, record in ipairs(history) do
        if y > panelY + 30 and y < panelY + panelH - 20 then
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print(string.format('Deployment %d: %s', i, record.colonyName or 'Unknown'), panelX + 20, y)
            y = y + 18
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print(string.format('Days: %d | Pop: %d | Raids: %d',
                record.daysSurvived or 0, record.peakPopulation or 0, record.raidsSurvived or 0),
                panelX + 30, y)
            y = y + 18
            love.graphics.setColor(0.8, 0.3, 0.3)
            love.graphics.print('Cause: ' .. (record.causeOfDeath or 'Unknown'), panelX + 30, y)
            y = y + 18
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.print(string.format('MRP earned: %d', record.mrpEarned or 0), panelX + 30, y)
            y = y + 26
        else
            y = y + 80
        end
    end

    -- Close hint
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print('[ESC] Close', panelX + panelW - 90, panelY + panelH - 22)
end

function PlanetHistory.keypressed(key)
    if not visible then return false end
    if key == 'escape' then
        PlanetHistory.hide()
        return true
    end
    return false
end

function PlanetHistory.wheelmoved(x, y)
    if not visible then return false end
    scrollY = math.max(0, scrollY - y * 20)
    return true
end

return PlanetHistory
```

- [ ] **Step 4: Wire history panel into planet_select.lua**

Add a keybind (e.g., 'h' for history) in planet_select.lua's keypressed:

```lua
if key == 'h' then
    local def = PlanetDefs.get(selectedPlanet)
    if def then
        PlanetHistory.show(selectedPlanet)
    end
end
```

Draw the history panel on top of planet select if visible. Route input through it.

- [ ] **Step 5: Pre-select failed planet on redeployment**

In planet_select.lua init, check for `GameState._redeployment` and pre-select `GameState.planet`:

```lua
if GameState._redeployment and GameState.planet then
    selectedPlanet = GameState.planet
end
```

- [ ] **Step 6: Commit**

```bash
git add src/ui/planet_select.lua src/ui/planet_history.lua
git commit -m "feat: planet select rework — scarred cards, deployment badges, history panel"
```

---

## Task 9: Requisition Panel (`src/ui/requisition_panel.lua`)

Mammona Requisition screen for permanent unlocks and per-run picks.

**Files:**
- Create: `src/ui/requisition_panel.lua`
- Modify: `main.lua` (add requisition phases)

- [ ] **Step 1: Define unlock and pick data tables in mrp.lua**

Add to `src/sim/mrp.lua`:

```lua
MRP.PERMANENT_UNLOCKS = {
    -- Genetic Program (tier 0+)
    { id = 'cold_adapted_genome', name = 'Cold-Adapted Genome', cost = 50, tier = 0,
      category = 'genetic', desc = 'All colonists: +1 hypothermia stage resistance' },
    { id = 'enhanced_metabolism', name = 'Enhanced Metabolism', cost = 40, tier = 0,
      category = 'genetic', desc = 'Colonists eat 15% less' },
    { id = 'rapid_clotting', name = 'Rapid Clotting', cost = 45, tier = 0,
      category = 'genetic', desc = 'Bleed rate reduced, wounds heal faster' },
    { id = 'neural_plasticity', name = 'Neural Plasticity', cost = 60, tier = 1,
      category = 'genetic', desc = 'Skill learning 20% faster' },
    { id = 'stress_inoculation', name = 'Stress Inoculation', cost = 35, tier = 0,
      category = 'genetic', desc = 'Mental break thresholds lowered' },

    -- Corporate Knowledge Base (tier 0+)
    { id = 'tier1_research_archive', name = 'Tier 1 Research Archive', cost = 30, tier = 0,
      category = 'knowledge', desc = 'All Tier 1 research starts at 50% progress' },
    { id = 'structural_engineering', name = 'Structural Engineering Protocols', cost = 40, tier = 1,
      category = 'knowledge', desc = 'Buildings start with +15% HP' },
    { id = 'efficient_extraction', name = 'Efficient Extraction', cost = 35, tier = 0,
      category = 'knowledge', desc = 'Mining yields +10%' },
    { id = 'advanced_smelting', name = 'Advanced Smelting Data', cost = 50, tier = 1,
      category = 'knowledge', desc = 'Steel refining unlocked from run start' },
    { id = 'agricultural_database', name = 'Agricultural Database', cost = 40, tier = 1,
      category = 'knowledge', desc = 'Crop grow time reduced 10%' },

    -- Operational Upgrades (tier 1+)
    { id = 'expanded_deployment', name = 'Expanded Deployment', cost = 75, tier = 2,
      category = 'operations', desc = '+1 starting colonist on all runs' },
    { id = 'heavy_drop_pod', name = 'Heavy Drop Pod', cost = 60, tier = 1,
      category = 'operations', desc = 'Increased starting resource package' },
    { id = 'orbital_relay', name = 'Orbital Relay', cost = 80, tier = 2,
      category = 'operations', desc = 'Merchant caravans arrive earlier and more frequently' },
    { id = 'deep_scan_array', name = 'Deep Scan Array', cost = 50, tier = 2,
      category = 'operations', desc = 'Cave entrances visible through fog on new maps' },
}

MRP.PER_RUN_PICKS = {
    -- Operative Augments
    { id = 'combat_stims', name = 'Combat Stims', cost = 8,
      category = 'augment', desc = '+20% combat stats for one colonist', targetColonist = true },
    { id = 'mammona_datalink', name = 'Mammona Datalink', cost = 10,
      category = 'augment', desc = '+3 to one chosen skill for one colonist', targetColonist = true },
    { id = 'survival_package', name = 'Survival Package', cost = 6,
      category = 'augment', desc = 'Colonist starts with parka, medicine, weapon', targetColonist = true },
    { id = 'psi_dampener', name = 'Psi Dampener', cost = 12,
      category = 'augment', desc = 'Immune to first mental break', targetColonist = true },

    -- Deployment Bonuses
    { id = 'supply_drop', name = 'Supply Drop', cost = 10,
      category = 'deployment', desc = 'Extra starting resources' },
    { id = 'prefab_shelter', name = 'Prefab Shelter', cost = 20,
      category = 'deployment', desc = 'Start with a small pre-built heated room' },
    { id = 'advanced_toolkit', name = 'Advanced Toolkit', cost = 15,
      category = 'deployment', desc = 'Start with research bench + Data Recovery Terminal' },
    { id = 'satellite_scan', name = 'Satellite Scan', cost = 12,
      category = 'deployment', desc = 'Reveal portion of map around landing zone' },
    { id = 'ruin_survey', name = 'Ruin Survey', cost = 8,
      category = 'deployment', desc = 'See exact contents of old colony ruins before landing' },
    { id = 'threat_delay', name = 'Threat Delay', cost = 10,
      category = 'deployment', desc = 'First raid pushed back 5 days' },
    { id = 'friendly_signal', name = 'Friendly Signal', cost = 15,
      category = 'deployment', desc = 'Guaranteed refugee event in first 10 days' },
}

-- Track per-run picks for current deployment
local activeRunPicks = {}

function MRP.setRunPicks(picks)
    activeRunPicks = picks
end

function MRP.getRunPicks()
    return activeRunPicks
end

function MRP.getAvailableUnlocks()
    local tier = MRP.getTier()
    local available = {}
    for _, unlock in ipairs(MRP.PERMANENT_UNLOCKS) do
        if unlock.tier <= tier then
            available[#available + 1] = unlock
        end
    end
    return available
end
```

- [ ] **Step 2: Write requisition panel UI**

Create `src/ui/requisition_panel.lua` with two modes: 'unlocks' (permanent) and 'picks' (per-run).

The panel should:
- Show available unlocks/picks as a scrollable list
- Show MRP balance
- Allow purchasing with keyboard navigation
- Show "already owned" for purchased permanent unlocks
- For per-run picks targeting colonists, show colonist list for assignment

This is a UI-heavy file. Follow the pattern of existing panels like `src/ui/colony_panel.lua` for layout conventions.

- [ ] **Step 3: Wire requisition phases into main.lua**

In `main.lua`, add two new phases. The current flow is:
```
planet_select → world_map → drafting → starting
```

The new flow reorders `drafting` before `world_map` and inserts requisition screens:
```
planet_select → requisition_unlocks → drafting → requisition_picks → world_map → starting
```

**Phase transition changes:**
1. Find where `planet_select` transitions to `world_map` and change it to transition to `'requisition_unlocks'`
2. Add `requisition_unlocks` phase handler: draws/inputs the permanent unlock panel, transitions to `'drafting'` on confirm
3. Find where `drafting` transitions to `starting` (or `world_map`) and change it to transition to `'requisition_picks'`
4. Add `requisition_picks` phase handler: draws/inputs the per-run picks panel, transitions to `'world_map'` on confirm
5. The rest of the flow (`world_map` → `starting`) stays unchanged

Wire draw() and keypressed() for both phases to the requisition panel, passing the appropriate mode ('unlocks' or 'picks').

- [ ] **Step 4: Commit**

```bash
git add src/sim/mrp.lua src/ui/requisition_panel.lua main.lua
git commit -m "feat: Mammona Requisition panel — permanent unlocks and per-run picks"
```

---

## Task 10: Apply MRP Unlocks and Per-Run Picks

Wire the purchased upgrades into actual game systems.

**Files:**
- Modify: `src/colonist/colonist.lua` (apply genetic upgrades on spawn)
- Modify: `src/research/research.lua` (apply research archive unlock)
- Modify: `src/building/building_placement.lua` (apply structural engineering)
- Modify: `src/sim/raids.lua` (apply threat delay)
- Modify: `src/colonist/recruitment.lua` (apply friendly signal)
- Modify: `main.lua` (apply deployment bonuses on world init)

- [ ] **Step 1: Apply genetic unlocks in colonist spawn**

In `src/colonist/colonist.lua`, in the spawn function, check for MRP genetic unlocks:

```lua
local mok, MRP = pcall(require, 'src.sim.mrp')
if mok then
    if MRP.hasUnlock('cold_adapted_genome') then
        -- Increase hypothermia resistance
        col.hypothermiaResist = (col.hypothermiaResist or 0) + 1
    end
    if MRP.hasUnlock('enhanced_metabolism') then
        col.hungerRate = (col.hungerRate or 1.0) * 0.85
    end
    if MRP.hasUnlock('neural_plasticity') then
        col.learnRate = (col.learnRate or 1.0) * 1.20
    end
    if MRP.hasUnlock('stress_inoculation') then
        col.breakThreshold = (col.breakThreshold or 20) - 5
    end
end
```

- [ ] **Step 2: Apply knowledge base unlocks**

In `src/research/research.lua`, add a new function called after `Research.init()` to apply MRP knowledge unlocks. **IMPORTANT:** Research uses `completed` (set), `current` (single nodeId), `progress` (single number), and `NODES` (static defs). There is no per-node progress.

```lua
function Research.applyMRPUnlocks()
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if not mok then return end

    if MRP.hasUnlock('tier1_research_archive') then
        -- Auto-complete all tier 1 research
        for nodeId, node in pairs(NODES) do
            if node.tier == 1 and not completed[nodeId] then
                completed[nodeId] = true
            end
        end
    end

    if MRP.hasUnlock('advanced_smelting') then
        -- Auto-complete the steel refining tech specifically
        if NODES['forge_steel'] and not completed['forge_steel'] then
            completed['forge_steel'] = true
        end
    end
end
```

Call `Research.applyMRPUnlocks()` from `main.lua` in `initGameWorld()` after `Research.init()` is called.

- [ ] **Step 3: Apply per-run picks in initGameWorld**

In `main.lua` `initGameWorld()`, after colonist spawning, apply per-run picks:

```lua
local mok, MRP = pcall(require, 'src.sim.mrp')
if mok then
    local picks = MRP.getRunPicks()
    for _, pick in ipairs(picks) do
        if pick.id == 'supply_drop' then
            GameState.resources.metal = (GameState.resources.metal or 0) + 50
            GameState.resources.food = (GameState.resources.food or 0) + 100
            GameState.resources.components = (GameState.resources.components or 0) + 10
        elseif pick.id == 'threat_delay' then
            GameState.raidGraceDays = (GameState.raidGraceDays or 0) + 5
        elseif pick.id == 'friendly_signal' then
            GameState._friendlySignalActive = true
        end
        -- ... handle other picks
    end
end
```

- [ ] **Step 4: Apply threat delay in raids.lua**

In `src/sim/raids.lua`, in the initial raid timer/scheduling logic, check `GameState.raidGraceDays`:

```lua
if GameState.raidGraceDays and GameState.day <= GameState.raidGraceDays then
    return  -- raids delayed
end
```

- [ ] **Step 5: Commit**

```bash
git add src/colonist/colonist.lua src/research/research.lua src/building/building_placement.lua src/sim/raids.lua src/colonist/recruitment.lua main.lua
git commit -m "feat: apply MRP permanent unlocks and per-run picks to game systems"
```

---

## Task 11: Main Game Flow Integration

Wire the full roguelite loop: redeployment from defeat screen → planet select → requisition → drafting → ruin spawning.

**Files:**
- Modify: `main.lua`

- [ ] **Step 1: Load campaign on startup**

In `main.lua`, early in `love.load()`, load the campaign file:

```lua
local mok, MRP = pcall(require, 'src.sim.mrp')
if mok then
    MRP.load()
end
```

- [ ] **Step 2: Handle redeployment flag**

In the main update loop, check for `GameState._redeployment`:

```lua
if GameState._redeployment then
    GameState._redeployment = nil
    phase = 'planet_select'
    -- Planet is pre-selected from the failed colony
end
```

- [ ] **Step 3: Wire ruin spawning into initGameWorld**

In `initGameWorld()`, after world generation but before colonist spawning, check for legacy data:

```lua
local mok, MRP = pcall(require, 'src.sim.mrp')
if mok then
    local history = MRP.getPlanetHistory(GameState.planet)
    if #history > 0 then
        local lastRecord = history[#history]
        local rsok, RuinSpawner = pcall(require, 'src.sim.ruin_spawner')
        if rsok then
            RuinSpawner.spawnFromLegacy(lastRecord)
        end

        -- Register nemeses for raid system
        local nok, Nemesis = pcall(require, 'src.sim.nemesis')
        -- Nemeses are already in MRP roster, raids.lua reads them
    end
end
```

- [ ] **Step 4: Use same map seed on redeployment**

In `initGameWorld()`, when initializing the world, check if we're redeploying and use the legacy map seed:

```lua
local mapSeed = GameState.worldSeedNumeric
local mok, MRP = pcall(require, 'src.sim.mrp')
if mok then
    local history = MRP.getPlanetHistory(GameState.planet)
    if #history > 0 then
        local lastRecord = history[#history]
        if lastRecord.mapSeed then
            mapSeed = lastRecord.mapSeed
        end
        if lastRecord.worldSeed then
            GameState.worldSeedNumeric = lastRecord.worldSeed
        end
    end
end
World.init(mapW, mapH, mapSeed)
```

- [ ] **Step 5: Add "Continue Campaign" to main menu**

In the main menu setup (likely `main.lua` or a menu module), add a "Continue Campaign" option that loads `frosthold_campaign.dat` and goes to planet select, versus "New Game" which resets the campaign.

- [ ] **Step 6: Save campaign on victory too**

In `GameOver.triggerVictory()`, add MRP earning and campaign save logic similar to defeat.

- [ ] **Step 7: Commit**

```bash
git add main.lua
git commit -m "feat: full roguelite loop — redeployment flow, ruin spawning, campaign persistence"
```

---

## Task 12: Migration and Cleanup

Handle existing save files and remove dead code.

**Files:**
- Modify: `src/sim/mrp.lua` (add migration from old legacies)
- Modify: `src/sim/colony_legacy.lua` (redirect to MRP system)
- Modify: `src/persistence/save.lua` (tolerate old fields)

- [ ] **Step 1: Add legacy migration in MRP.load()**

In `src/sim/mrp.lua`, after loading campaign data, check for old `frosthold_legacies.dat`:

```lua
function MRP.migrateOldLegacies()
    local ok, lfs = pcall(function() return love.filesystem end)
    if not ok or not lfs then return end

    if not lfs.getInfo('frosthold_legacies.dat') then return end
    if lfs.getInfo('frosthold_legacies.dat.bak') then return end  -- already migrated

    local str = lfs.read('frosthold_legacies.dat')
    if not str then return end

    local fn = loadstring('return ' .. str)
    if not fn then return end
    local oldRecords = fn()
    if type(oldRecords) ~= 'table' then return end

    for _, old in ipairs(oldRecords) do
        local record = {
            planet = 'erebus',  -- default, old records don't have planet
            colonyName = old.colonyName or 'Unknown Colony',
            daysSurvived = old.daysSurvived or 0,
            peakPopulation = old.peakPopulation or 0,
            causeOfDeath = old.causeOfDeath or 'unknown',
            wealth = old.wealth or 0,
            raidsSurvived = old.raidsSurvived or 0,
            buildingsConstructed = 0,
            bossesKilled = old.bossesKilled or 0,
            timestamp = old.timestamp or 0,
            resources = old.resources or {},
            completedResearch = {},
            inProgressResearch = {},
            buildings = {},
            colonists = {},
            nemeses = {},
            mrpEarned = 0,
            x = old.x or 0,
            y = old.y or 0,
        }
        MRP.addPlanetDeployment(record.planet, record)
    end

    -- Rename old file
    local content = lfs.read('frosthold_legacies.dat')
    lfs.write('frosthold_legacies.dat.bak', content)
    lfs.remove('frosthold_legacies.dat')

    MRP.save()
end
```

Call `MRP.migrateOldLegacies()` at the end of `MRP.load()`.

- [ ] **Step 2: Make save.lua tolerate removed fields**

In `src/persistence/save.lua`, ensure `restoreFromData()` doesn't crash if `mammonaSafetyNet` or `_safetyNetUsed` are present in old save data — just ignore them.

- [ ] **Step 3: Clean up colony_legacy.lua**

Simplify `colony_legacy.lua` to delegate to MRP for storage. Keep `recordFallenColony()` as the main entry point but have it write to MRP instead of the old file. Remove `saveLegacies()`, `loadLegacies()`, and the old file I/O. Keep `getLegacyDestinations()` and `getLegacyLoot()` but have them read from MRP.

- [ ] **Step 4: Run full test suite**

```bash
cd F:/IceRimworld && lua tests/run_all.lua
```

Fix any failures.

- [ ] **Step 5: Commit**

```bash
git add src/sim/mrp.lua src/sim/colony_legacy.lua src/persistence/save.lua
git commit -m "feat: migration from old legacy format, cleanup dead safety net code"
```

---

## Dependency Graph

```
Task 1 (MRP persistence)
  ├→ Task 2 (expanded legacy records)
  ├→ Task 3 (nemesis system)
  ├→ Task 7 (defeat screen rework)
  ├→ Task 8 (planet select rework)
  └→ Task 9 (requisition panel)
       └→ Task 10 (apply unlocks/picks)

Task 4 (SOS Beacon) — independent
Task 5 (Data Terminal) — independent
Task 6 (Ruin Spawner) — depends on Task 2

Task 11 (main flow integration) — depends on Tasks 1-10
Task 12 (migration/cleanup) — depends on Tasks 1-2
```

**Parallel groups:**
- Group A: Tasks 1 → 2 → 6 (data pipeline)
- Group B: Tasks 4, 5 (new buildings, independent)
- Group C: Tasks 3, 7, 8, 9 → 10 (UI + nemesis, depend on Task 1)
- Final: Tasks 11, 12 (integration, depend on everything)
