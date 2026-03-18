# Interplanetary Travel — Phase 1: Core Architecture

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the foundational context-swap, chunked tilemap, ship entity, and colony background simulation systems that all subsequent interplanetary phases depend on.

**Architecture:** The context-swap reuses the existing Save.save()/Save.load() cycle to swap between colony and space ECS contexts — no multi-instance ECS needed. Space is defined as an 8th planet in planet_defs.lua. A chunked tilemap adapter wraps the existing World API so all systems work in space without modification. Ships are ECS entity groups with `ship` and `ship_module` components.

**Tech Stack:** Love2D 11.4, Lua 5.1/LuaJIT, existing ECS at src/ecs/ecs.lua

**Spec:** `docs/superpowers/specs/2026-03-15-interplanetary-travel-design.md` (Sections 11, 13, 14)

**NOTE:** Milestone rework (spec Phase 5) is front-loaded into this phase since it's a prerequisite for removing game-ending behavior.

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `src/space/space_tilemap.lua` | Chunked tilemap for space — generates/loads/unloads 32x32 chunks, same API as World |
| `src/space/context_swap.lua` | Orchestrates colony↔space transitions using Save snapshot API |
| `src/space/background_colony.lua` | Counter-based background simulation for absent colonies |
| `src/space/ship_manager.lua` | Ship entity group creation, stamping onto colony map, extraction on launch |
| `src/space/ship_defs.lua` | Ship tier definitions, prebuilt layouts, required module specs |
| `src/space/ship_movement.lua` | Ship navigation on space tilemap — thrust, heading, drift, fuel |
| `src/sim/milestones.lua` | Milestone reward system replacing victory triggers |

### Modified Files
| File | Changes |
|------|---------|
| `src/world/planet_defs.lua` | Add `space` planet definition |
| `src/world/tilemap.lua` | Add dispatch layer in getTile/setTile/getTemp/getRoom to route to SpaceTilemap when activeMap == 'space' |
| `src/persistence/save.lua` | Accept version 3, add snapshotToMemory/loadFromMemory, skip tilemap for space context |
| `src/persistence/save_helpers.lua` | Add new components to KNOWN_COMPONENTS, serialize new GameState fields |
| `src/game_state.lua` | Add activeMap, colonies, shipState, discoveredPOIs, discoveredPlanets, spaceChunkDiffs, milestone flags |
| `src/sim/endgame.lua` | Replace triggerVictory calls with Milestone.complete calls, remove launch_pad from endgame |
| `src/ecs/ecs.lua` | No changes needed (getAll already added this session) |
| `main.lua` | Wire space systems init, handle activeMap for update loop |

---

## Chunk 1: GameState Extensions & Save Format v3

### Task 1: Add New GameState Fields

**Files:**
- Modify: `src/game_state.lua`

- [ ] **Step 1: Read current GameState.init()**

Read `src/game_state.lua` to confirm current init() at lines 235-264.

- [ ] **Step 2: Add new fields to GameState defaults (top of file)**

In the GameState table definition (around line 10), add after the existing fields:

```lua
-- Interplanetary state
activeMap = nil,
colonies = {},
shipState = nil,
discoveredPOIs = {},
discoveredPlanets = {},
spaceChunkDiffs = {},
mammonaClaimed = false,
sealedDeep = false,
extractionComplete = false,
credits = 0,
```

- [ ] **Step 3: Add new fields to GameState.init()**

In `GameState.init()` (around line 235), add after existing resets:

```lua
GameState.activeMap = nil
GameState.colonies = {}
GameState.shipState = nil
GameState.discoveredPOIs = {}
GameState.discoveredPlanets = {}
GameState.spaceChunkDiffs = {}
GameState.mammonaClaimed = false
GameState.sealedDeep = false
GameState.extractionComplete = false
GameState.credits = 0
```

- [ ] **Step 4: Verify no syntax errors**

Run: `cd F:\IceRimworld && lua src/game_state.lua`
Expected: No errors (module loads cleanly)

- [ ] **Step 5: Commit**

```
feat(gamestate): add interplanetary state fields

Add activeMap, colonies, shipState, discoveredPOIs, discoveredPlanets,
spaceChunkDiffs, milestone flags, and credits to GameState for
interplanetary travel support.
```

---

### Task 2: Add New Components to KNOWN_COMPONENTS

**Files:**
- Modify: `src/persistence/save_helpers.lua`

- [ ] **Step 1: Read current KNOWN_COMPONENTS**

Read `src/persistence/save_helpers.lua` lines 85-109.

- [ ] **Step 2: Add new components**

After `'clothing',` (the last entry, line 108), add:

```lua
    'ship',
    'ship_module',
    'ship_crew',
    'weapon_mount',
    'stealth',
    'space_suit',
    'npc_ship',
```

- [ ] **Step 3: Add new GameState fields to buildSaveData()**

In `buildSaveData()` gameState table (around line 192), add after the existing fields:

```lua
        activeMap = GameState.activeMap,
        colonies = GameState.colonies,
        shipState = GameState.shipState,
        discoveredPOIs = GameState.discoveredPOIs,
        discoveredPlanets = GameState.discoveredPlanets,
        spaceChunkDiffs = GameState.spaceChunkDiffs,
        mammonaClaimed = GameState.mammonaClaimed,
        sealedDeep = GameState.sealedDeep,
        extractionComplete = GameState.extractionComplete,
        credits = GameState.credits,
```

Also add space subsystem state to `buildSaveData()` alongside other subsystem state blocks:

```lua
        shipMovement = (function()
            local ok, SM = pcall(require, 'src.space.ship_movement')
            if ok and SM.getState then return SM.getState() end
        end)(),
        spaceTilemap = (function()
            local ok, ST = pcall(require, 'src.space.space_tilemap')
            if ok and ST.getState then return ST.getState() end
        end)(),
```

And in the restore block of `restoreFromData` (or `Save.load`), add:

```lua
    -- Space subsystem restore
    if data.shipMovement then
        local ok, SM = pcall(require, 'src.space.ship_movement')
        if ok and SM.loadState then SM.loadState(data.shipMovement) end
    end
    if data.spaceTilemap then
        local ok, ST = pcall(require, 'src.space.space_tilemap')
        if ok and ST.loadState then ST.loadState(data.spaceTilemap) end
    end
```

- [ ] **Step 4: Commit**

```
feat(save): add interplanetary components and state to save format
```

---

### Task 3: Update Save.load() for Version 3

**Files:**
- Modify: `src/persistence/save.lua`

- [ ] **Step 1: Read current version check**

Read `src/persistence/save.lua` lines 30-40.

- [ ] **Step 2: Update version check to accept v3**

Replace line 34:
```lua
if not data.version or (data.version ~= 1 and data.version ~= 2) then
```
With:
```lua
if not data.version or data.version < 1 or data.version > 3 then
```

- [ ] **Step 3: Add v2 → v3 migration block**

After the existing v1 → v2 migration block (around line 90-106), add:

```lua
-- v2 → v3 migration: add interplanetary defaults
if data.version == 2 then
    data.version = 3
    local gs = data.gameState or {}
    gs.activeMap = gs.planet or 'erebus'
    gs.colonies = {}
    gs.shipState = nil
    gs.discoveredPOIs = {}
    gs.discoveredPlanets = { [gs.planet or 'erebus'] = true }
    gs.spaceChunkDiffs = {}
    gs.mammonaClaimed = false
    gs.sealedDeep = false
    gs.extractionComplete = false
    gs.credits = 0
    data.gameState = gs
end
```

- [ ] **Step 4: Add new field restoration in the GameState restore block**

After the existing GameState field restoration (around line 87), add:

```lua
GameState.activeMap = gs.activeMap or gs.planet or 'erebus'
GameState.colonies = gs.colonies or {}
GameState.shipState = gs.shipState or nil
GameState.discoveredPOIs = gs.discoveredPOIs or {}
GameState.discoveredPlanets = gs.discoveredPlanets or {}
GameState.spaceChunkDiffs = gs.spaceChunkDiffs or {}
GameState.mammonaClaimed = gs.mammonaClaimed or false
GameState.sealedDeep = gs.sealedDeep or false
GameState.extractionComplete = gs.extractionComplete or false
GameState.credits = gs.credits or 0
```

- [ ] **Step 5: Update version number in save_helpers buildSaveData()**

In `src/persistence/save_helpers.lua`, change:
```lua
version = 2,
```
to:
```lua
version = 3,
```

- [ ] **Step 6: Verify existing save loads**

Launch game, load a save, verify no errors. Save again, verify save file has `version = 3`.

- [ ] **Step 7: Commit**

```
feat(save): support save format v3 with interplanetary migration

Accept version 3 saves. Migrate v2 saves by adding interplanetary
defaults (activeMap, colonies, discoveredPlanets, milestone flags).
```

---

### Task 4: Add snapshotToMemory / loadFromMemory to Save

**Files:**
- Modify: `src/persistence/save.lua`

- [ ] **Step 1: Add Save.snapshotToMemory()**

Add at the end of save.lua, before `return Save`:

```lua
---------------------------------------------------------------------------
-- In-memory snapshot API for context-swap (interplanetary travel)
---------------------------------------------------------------------------

function Save.snapshotToMemory()
    local Helpers = require('src.persistence.save_helpers')
    return Helpers.buildSaveData()
end
```

- [ ] **Step 2: Extract shared restore logic from Save.load()**

The existing `Save.load()` has ~400 lines of GameState restoration, tilemap restoration, ECS entity spawning, system re-registration, and subsystem state restoration. Rather than duplicating this (which will diverge and break), extract the core restore logic into an internal function that both `Save.load()` and the new `Save.loadFromMemory()` share.

In `save.lua`, find the block from GameState field restoration (line ~39) through the end of subsystem restoration (line ~584). Wrap it in a local function:

```lua
-- Internal: restore game state from a parsed data table
-- skipTilemap: if true, skip tilemap restore (for space context)
local function restoreFromData(data, skipTilemap)
    -- [MOVE the entire existing restore block here — lines 39-584]
    -- This includes:
    --   1. GameState field restoration (all fields including new interplanetary ones)
    --   2. Planet.init()
    --   3. Tilemap restore (guarded by skipTilemap flag)
    --   4. ECS.init() + entity spawning + idRemap
    --   5. System re-registration (all 35+ registerSystems calls)
    --   6. Subsystem state restoration with idRemap (raids, social, jobs, etc.)
    --   7. Entity ID cleanup (dangling references, bed reassignment, etc.)
    return true
end
```

Then simplify `Save.load()` to:
```lua
function Save.load(slot)
    local path = getSavePath(slot)
    local content = love.filesystem.read(path)
    if not content then return false end
    local data = Helpers.deserialize(content)
    if not data then return false end
    -- Version check and migration (unchanged)
    if not data.version or data.version < 1 or data.version > 3 then
        return false
    end
    -- v1->v2 and v2->v3 migrations (unchanged)
    ...
    return restoreFromData(data, false)
end
```

And add `loadFromMemory`:
```lua
function Save.loadFromMemory(snapshotData, skipTilemap)
    if not snapshotData then return false end
    return restoreFromData(snapshotData, skipTilemap or false)
end
```

**CRITICAL:** The existing `restoreFromData` logic must be moved verbatim — do NOT rewrite or simplify the subsystem restore block. It contains entity ID remapping for raids, social opinions, jobs, visitors, biocaves, and other systems that will silently corrupt if omitted. Add the `skipTilemap` guard around the tilemap restore section only.

The only addition to `restoreFromData` is the `skipTilemap` guard:
```lua
if not skipTilemap and data.tilemap then
    -- existing tilemap restore code
end
```

And restoring the new interplanetary GameState fields at the end of the GameState block:
```lua
GameState.activeMap = gs.activeMap or gs.planet or 'erebus'
GameState.colonies = gs.colonies or {}
GameState.shipState = gs.shipState
GameState.discoveredPOIs = gs.discoveredPOIs or {}
GameState.discoveredPlanets = gs.discoveredPlanets or {}
GameState.spaceChunkDiffs = gs.spaceChunkDiffs or {}
GameState.mammonaClaimed = gs.mammonaClaimed or false
GameState.sealedDeep = gs.sealedDeep or false
GameState.extractionComplete = gs.extractionComplete or false
GameState.credits = gs.credits or 0
```

- [ ] **Step 3: Verify existing save/load still works**

Launch game, create a new colony, F5 save, F9 load. Verify no regressions.

- [ ] **Step 4: Commit**

```
feat(save): add in-memory snapshot API for context-swap

Save.snapshotToMemory() captures full game state to a table.
Save.loadFromMemory(data, skipTilemap) restores from table,
with optional tilemap skip for space context transitions.
```

---

## Chunk 2: Space Planet Definition & Chunked Tilemap

### Task 5: Add Space Planet Definition

**Files:**
- Modify: `src/world/planet_defs.lua`

- [ ] **Step 1: Read current planet_defs.lua**

Read `src/world/planet_defs.lua` to find the PLANETS table and PLANET_ORDER array.

- [ ] **Step 2: Add space planet definition**

After the `gaia_a1x` entry (before the closing `}` of the PLANETS table), add:

```lua
    ---------------------------------------------------------------------------
    -- SPACE — The void between worlds (not a starting planet)
    ---------------------------------------------------------------------------
    space = {
        id       = 'space',
        name     = 'Space',
        subtitle = 'The Void Between',
        desc     = 'The cold vacuum between worlds. No air, no gravity, no mercy. Your ship is your only shelter.',
        color    = { 0.1, 0.1, 0.2 },
        difficultyLabel = 'N/A',
        scenarios = {},
        thermal = { outdoorSnap = 1.0, undergroundBaseTemp = -270 },
        atmosphere = { ambientO2 = 0, ambientCO2 = 0 },
        radiation = { ambientDose = 0.01, doseLethal = 5.0 },
        hermes = { enabled = false },
        tuning = {
            raids = { budget_base = 0, budget_per_day = 0 },
            weather = { harshness_min = 0, harshness_max = 0 },
        },
    },
```

- [ ] **Step 3: Do NOT add 'space' to PLANET_ORDER**

Space is not a starting planet. It should not appear in planet selection UI. Leave PLANET_ORDER unchanged.

- [ ] **Step 4: Commit**

```
feat(planets): add space void planet definition

Space is the 8th planet def — vacuum, no atmosphere, radiation,
no HERMES, no raids. Not in PLANET_ORDER (not selectable at start).
```

---

### Task 6: Create Space Tilemap Module

**Files:**
- Create: `src/space/space_tilemap.lua`

- [ ] **Step 1: Create src/space directory**

```bash
mkdir -p src/space
```

- [ ] **Step 2: Write the space tilemap module**

```lua
-- space_tilemap.lua — Chunked tilemap for space navigation
-- Generates 32x32 tile chunks procedurally from world seed.
-- Exposes same API as World (tilemap.lua) so existing systems work.
-- Planet colony maps are unaffected — they use the fixed tilemap as before.

local GameState = require('src.game_state')
local Tiles     = require('src.world.tiles')

local SpaceTilemap = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local CHUNK_SIZE = 32
local VOID_TILE  = Tiles.VOID or 0
local ASTEROID_TILE = 99   -- new tile type for asteroid (will register in tiles.lua)
local DEBRIS_TILE   = 100  -- new tile type for debris

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local chunks = {}        -- { ["cx,cy"] = { tiles = {}, generated = true } }
local shipChunkX = 0     -- chunk the ship is in
local shipChunkY = 0
local worldSeed  = 0

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function chunkKey(cx, cy)
    return cx .. ',' .. cy
end

local function parseChunkKey(key)
    local cx, cy = key:match('([^,]+),([^,]+)')
    return tonumber(cx), tonumber(cy)
end

-- Deterministic hash for chunk generation
local function chunkSeed(cx, cy)
    local s = worldSeed
    s = s + cx * 374761393
    s = s + cy * 668265263
    s = (s * s * s) % 2147483647
    return math.abs(s)
end

-- Convert world tile (x, y) to chunk coords + local offset
local function toChunkLocal(x, y)
    local cx = math.floor(x / CHUNK_SIZE)
    local cy = math.floor(y / CHUNK_SIZE)
    local lx = x - cx * CHUNK_SIZE
    local ly = y - cy * CHUNK_SIZE
    return cx, cy, lx, ly
end

local function localIdx(lx, ly)
    return ly * CHUNK_SIZE + lx + 1
end

---------------------------------------------------------------------------
-- Chunk generation
---------------------------------------------------------------------------

local function generateChunk(cx, cy)
    local key = chunkKey(cx, cy)
    if chunks[key] then return chunks[key] end

    local seed = chunkSeed(cx, cy)
    -- Deterministic per-tile hash (does NOT touch math.randomseed)
    local function tileHash(i)
        local s = seed + i * 2654435761
        s = s % 2147483647
        s = ((s * 1103515245) + 12345) % 2147483647
        return (s % 10000) / 10000
    end

    local tiles = {}
    local size = CHUNK_SIZE * CHUNK_SIZE

    -- Default: empty void
    for i = 1, size do
        tiles[i] = VOID_TILE
    end

    -- Apply chunk diffs (player modifications like mined asteroids)
    local diffs = GameState.spaceChunkDiffs[key]
    if diffs then
        for i, tile in pairs(diffs) do
            tiles[i] = tile
        end
    end

    -- Procedural content: asteroid clusters, debris patches
    -- Density varies by distance from origin (planets are near origin)
    local dist = math.sqrt(cx * cx + cy * cy)
    local asteroidChance = 0.03 + math.min(0.08, dist * 0.002)
    local debrisChance   = 0.01

    for i = 1, size do
        if not diffs or not diffs[i] then
            local r = tileHash(i)
            if r < asteroidChance then
                tiles[i] = ASTEROID_TILE
            elseif r < asteroidChance + debrisChance then
                tiles[i] = DEBRIS_TILE
            end
        end
    end

    local chunk = { tiles = tiles, generated = true }
    chunks[key] = chunk
    return chunk
end

---------------------------------------------------------------------------
-- Public API (mirrors tilemap.lua)
---------------------------------------------------------------------------

function SpaceTilemap.init(seed)
    chunks = {}
    worldSeed = seed or GameState.worldSeedNumeric or 12345
    shipChunkX = 0
    shipChunkY = 0
end

function SpaceTilemap.getTile(x, y)
    local cx, cy, lx, ly = toChunkLocal(x, y)
    local chunk = generateChunk(cx, cy)
    return chunk.tiles[localIdx(lx, ly)] or VOID_TILE
end

function SpaceTilemap.setTile(x, y, tileType)
    local cx, cy, lx, ly = toChunkLocal(x, y)
    local chunk = generateChunk(cx, cy)
    local idx = localIdx(lx, ly)
    chunk.tiles[idx] = tileType

    -- Record modification for persistence
    local key = chunkKey(cx, cy)
    if not GameState.spaceChunkDiffs[key] then
        GameState.spaceChunkDiffs[key] = {}
    end
    GameState.spaceChunkDiffs[key][idx] = tileType
end

function SpaceTilemap.getTemp(x, y)
    -- Space is uniformly cold (-270C)
    -- Ship interior temps handled by atmosphere/thermal systems per-room
    return -270
end

function SpaceTilemap.getRoom(x, y)
    -- Rooms are managed by the room system for ship interior tiles
    -- Void tiles have no room
    return nil
end

function SpaceTilemap.inBounds(x, y)
    -- Space is infinite — always in bounds
    return true
end

function SpaceTilemap.getWidth()
    -- Return a large value for systems that query map size
    return 10000
end

function SpaceTilemap.getHeight()
    return 10000
end

function SpaceTilemap.setShipChunk(cx, cy)
    shipChunkX = cx
    shipChunkY = cy
end

function SpaceTilemap.getLoadedChunks()
    return chunks
end

function SpaceTilemap.unloadDistantChunks(keepRadius)
    keepRadius = keepRadius or 3
    local toRemove = {}
    for key, _ in pairs(chunks) do
        local cx, cy = parseChunkKey(key)
        if math.abs(cx - shipChunkX) > keepRadius or math.abs(cy - shipChunkY) > keepRadius then
            toRemove[#toRemove + 1] = key
        end
    end
    for _, key in ipairs(toRemove) do
        chunks[key] = nil
    end
end

function SpaceTilemap.getState()
    return {
        worldSeed = worldSeed,
        shipChunkX = shipChunkX,
        shipChunkY = shipChunkY,
    }
end

function SpaceTilemap.loadState(state)
    if not state then return end
    worldSeed = state.worldSeed or 0
    shipChunkX = state.shipChunkX or 0
    shipChunkY = state.shipChunkY or 0
end

SpaceTilemap.CHUNK_SIZE = CHUNK_SIZE
SpaceTilemap.VOID_TILE = VOID_TILE
SpaceTilemap.ASTEROID_TILE = ASTEROID_TILE
SpaceTilemap.DEBRIS_TILE = DEBRIS_TILE

return SpaceTilemap
```

- [ ] **Step 3: Commit**

```
feat(space): add chunked space tilemap module

Procedural 32x32 chunk generation from world seed. Same API as
World tilemap (getTile/setTile/getTemp/inBounds). Persists player
modifications via spaceChunkDiffs. Unloads distant chunks.
```

---

### Task 7: Add World Tilemap Dispatch Layer

**Files:**
- Modify: `src/world/tilemap.lua`

- [ ] **Step 1: Read current getTile, setTile, getTemp, inBounds**

Read `src/world/tilemap.lua` — find getTile (around line 1045), setTile, getTemp, inBounds functions.

- [ ] **Step 2: Add dispatch at top of module**

Near the top of tilemap.lua, after local declarations, add:

```lua
local function isSpaceActive()
    local ok, GS = pcall(require, 'src.game_state')
    return ok and GS.activeMap == 'space'
end

local function getSpaceTilemap()
    local ok, ST = pcall(require, 'src.space.space_tilemap')
    if ok then return ST end
    return nil
end
```

- [ ] **Step 3: Wrap getTile with dispatch**

Replace the existing `Tilemap.getTile` function:

```lua
function Tilemap.getTile(x, y, depth)
    if isSpaceActive() then
        local ST = getSpaceTilemap()
        if ST then return ST.getTile(x, y) end
    end
    if not Tilemap.inBounds(x, y) then return Tiles.VOID end
    local L = _layer(depth)
    if not L then return Tiles.VOID end
    return L.tiles[_idx(x, y)]
end
```

- [ ] **Step 4: Wrap setTile with dispatch**

Find the existing `Tilemap.setTile` and add dispatch at the top:

```lua
function Tilemap.setTile(x, y, tileType, depth)
    if isSpaceActive() then
        local ST = getSpaceTilemap()
        if ST then ST.setTile(x, y, tileType); return end
    end
    -- existing implementation follows
```

- [ ] **Step 5: Wrap getTemp with dispatch**

Find existing `Tilemap.getTemp` and add:

```lua
function Tilemap.getTemp(x, y, depth)
    if isSpaceActive() then
        local ST = getSpaceTilemap()
        if ST then return ST.getTemp(x, y) end
    end
    -- existing implementation follows
```

- [ ] **Step 6: Wrap inBounds with dispatch**

Find existing `Tilemap.inBounds` and add:

```lua
function Tilemap.inBounds(x, y)
    if isSpaceActive() then return true end
    -- existing implementation follows
```

- [ ] **Step 7: Verify no regressions**

Launch game, start a new colony on Erebus, verify tiles render and thermal system works.

- [ ] **Step 8: Commit**

```
feat(tilemap): add space tilemap dispatch layer

World.getTile/setTile/getTemp/inBounds now route to SpaceTilemap
when GameState.activeMap == 'space'. Colony maps unaffected.
```

---

## Chunk 3: Context Swap & Background Colony

### Task 8: Create Context Swap Module

**Files:**
- Create: `src/space/context_swap.lua`

- [ ] **Step 1: Write the context swap module**

```lua
-- context_swap.lua — Orchestrates colony ↔ space transitions
-- Uses Save.snapshotToMemory / loadFromMemory for clean ECS context swap.
-- No multi-ECS instance needed — we serialize one world, destroy it, load another.

local GameState = require('src.game_state')

local ContextSwap = {}

---------------------------------------------------------------------------
-- Calculate automation score from a colony snapshot
---------------------------------------------------------------------------

local function calculateAutomationScore(snapshot)
    if not snapshot or not snapshot.entities then return 0 end

    local conveyors = 0
    local inserters = 0
    local machines  = 0
    local farms     = 0
    local powerSurplus = 0

    for _, ent in ipairs(snapshot.entities) do
        if ent.inserter then inserters = inserters + 1 end
        if ent.machine and ent.machine.recipe then machines = machines + 1 end
        if ent.crop and ent.crop.cropId then farms = farms + 1 end
    end

    -- Conveyor count from saved belt data
    if snapshot.conveyors and snapshot.conveyors.belts then
        for _ in pairs(snapshot.conveyors.belts) do
            conveyors = conveyors + 1
        end
    end

    -- Power surplus approximation from generator count
    if snapshot.power and snapshot.power.generators then
        for _ in pairs(snapshot.power.generators) do
            powerSurplus = powerSurplus + 50  -- rough per-generator estimate
        end
    end

    local score = (
        conveyors * 0.01 +
        inserters * 0.05 +
        machines * 0.1 +
        farms * 0.08 +
        math.max(0, powerSurplus / 100) * 0.1
    )

    return math.min(1.0, math.max(0, score))
end

---------------------------------------------------------------------------
-- Colony -> Space (launch from planet)
---------------------------------------------------------------------------

function ContextSwap.launchToSpace(colonyId, shipSnapshot)
    -- 1. Snapshot current colony
    local sok, Save = pcall(require, 'src.persistence.save')
    if not sok then return false end
    local colonySnapshot = Save.snapshotToMemory()
    local automationScore = calculateAutomationScore(colonySnapshot)

    -- 2. Store in colonies registry
    GameState.colonies[colonyId] = {
        planetId = GameState.planet,
        name = GameState.colonyName or ('Colony on ' .. GameState.planet),
        snapshot = colonySnapshot,
        automationScore = automationScore,
        lastTickDay = GameState.day,
    }

    -- 3. Switch to space context
    GameState.activeMap = 'space'
    GameState.planet = 'space'

    -- 4. Init space tilemap
    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then Planet.init('space') end

    local stOk, SpaceTilemap = pcall(require, 'src.space.space_tilemap')
    if stOk then SpaceTilemap.init(GameState.worldSeedNumeric) end

    -- 5. Load ship into fresh ECS context (skip tilemap — space uses chunks)
    if shipSnapshot then
        Save.loadFromMemory(shipSnapshot, true)
        -- IMPORTANT: loadFromMemory restores GameState from the snapshot,
        -- which may set activeMap/planet to old values. Override to space.
        GameState.activeMap = 'space'
        GameState.planet = 'space'
    end

    return true
end

---------------------------------------------------------------------------
-- Space -> Colony (land on planet)
---------------------------------------------------------------------------

function ContextSwap.landOnColony(colonyId)
    local colony = GameState.colonies[colonyId]
    if not colony or not colony.snapshot then return false end

    -- 1. Snapshot ship state
    local sok, Save = pcall(require, 'src.persistence.save')
    if not sok then return false end
    GameState.shipState = {
        snapshot = Save.snapshotToMemory(),
    }

    -- 2. Apply background tick to colony
    local bgOk, BackgroundColony = pcall(require, 'src.space.background_colony')
    if bgOk then
        local daysPassed = math.max(0, GameState.day - (colony.lastTickDay or GameState.day))
        if daysPassed > 0 then
            local log = BackgroundColony.tick(colony.snapshot, daysPassed, colony.automationScore)
            colony.lastTickDay = GameState.day
            -- Store log for display on return
            GameState._backgroundLog = log
        end
    end

    -- 3. Load colony context (with tilemap)
    Save.loadFromMemory(colony.snapshot, false)

    -- 4. Restore active map
    GameState.activeMap = colonyId
    GameState.planet = colony.planetId

    local pok, Planet = pcall(require, 'src.world.planet')
    if pok then Planet.init(colony.planetId) end

    return true
end

---------------------------------------------------------------------------
-- New colony on a new planet (first landing)
---------------------------------------------------------------------------

function ContextSwap.landOnNewPlanet(planetId, colonyName)
    -- 1. Snapshot ship state
    local sok, Save = pcall(require, 'src.persistence.save')
    if not sok then return false end
    GameState.shipState = {
        snapshot = Save.snapshotToMemory(),
    }

    -- 2. Set up new game state for the planet
    GameState.planet = planetId
    GameState.activeMap = planetId .. '_' .. tostring(os.time())
    GameState.colonyName = colonyName or ('Colony on ' .. planetId)

    -- 3. Planet init will be handled by the normal new-game flow
    -- The caller should trigger world generation after this
    return GameState.activeMap
end

---------------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------------

function ContextSwap.isInSpace()
    return GameState.activeMap == 'space'
end

function ContextSwap.getColonyList()
    local list = {}
    for id, colony in pairs(GameState.colonies) do
        list[#list + 1] = {
            id = id,
            name = colony.name,
            planetId = colony.planetId,
            automationScore = colony.automationScore,
            lastTickDay = colony.lastTickDay,
        }
    end
    return list
end

ContextSwap.calculateAutomationScore = calculateAutomationScore

return ContextSwap
```

- [ ] **Step 2: Commit**

```
feat(space): add context swap module for colony/space transitions

ContextSwap.launchToSpace() serializes colony, loads ship into space.
ContextSwap.landOnColony() applies background tick, restores colony.
Uses Save.snapshotToMemory/loadFromMemory for clean ECS swap.
```

---

### Task 9: Create Background Colony Module

**Files:**
- Create: `src/space/background_colony.lua`

- [ ] **Step 1: Write the background colony simulation**

```lua
-- background_colony.lua — Counter-based simulation for absent colonies
-- Operates on serialized snapshot data, NOT live ECS.
-- Runs once per game-day for each colony the player has left behind.

local BackgroundColony = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local FOOD_PER_COLONIST_PER_DAY = 2.0
local FUEL_PER_DAY_BASE = 5.0
local DURABILITY_DECAY_PER_DAY = 0.5

---------------------------------------------------------------------------
-- Tick a background colony
-- snapshot: the colony's serialized save data table
-- daysPassed: integer number of game-days since last tick
-- automationScore: 0.0-1.0 (calculated at serialization)
-- Returns: log table { messages = {}, resourceChanges = {} }
---------------------------------------------------------------------------

function BackgroundColony.tick(snapshot, daysPassed, automationScore)
    if not snapshot or daysPassed <= 0 then
        return { messages = {}, resourceChanges = {} }
    end

    local log = { messages = {}, resourceChanges = {} }
    local entities = snapshot.entities or {}

    -- Count colonists
    local colonistCount = 0
    for _, ent in ipairs(entities) do
        if ent.colonist and (not ent.colonist.dead) then
            colonistCount = colonistCount + 1
        end
    end

    if colonistCount == 0 then
        log.messages[#log.messages + 1] = 'Colony abandoned — no colonists remain.'
        return log
    end

    -- Find storage entities and their contents
    local storageEntities = {}
    for _, ent in ipairs(entities) do
        if ent.storage and ent.storage.contents then
            storageEntities[#storageEntities + 1] = ent
        end
    end

    -- Helper: consume items from storage
    local function consumeFromStorage(itemId, amount)
        local remaining = amount
        for _, ent in ipairs(storageEntities) do
            local stor = ent.storage
            for i = 1, (stor.slots or 0) do
                local slot = stor.contents[i]
                if slot and slot.itemId == itemId and remaining > 0 then
                    local take = math.min(slot.amount or 1, remaining)
                    slot.amount = (slot.amount or 1) - take
                    remaining = remaining - take
                    if slot.amount <= 0 then
                        stor.contents[i] = nil
                    end
                end
            end
        end
        return amount - remaining  -- actually consumed
    end

    -- Food consumption
    local foodNeeded = math.ceil(colonistCount * FOOD_PER_COLONIST_PER_DAY * daysPassed)
    local foodConsumed = consumeFromStorage('cooked_meat', math.ceil(foodNeeded * 0.5))
    foodConsumed = foodConsumed + consumeFromStorage('stew', math.ceil(foodNeeded * 0.3))
    foodConsumed = foodConsumed + consumeFromStorage('jerky', foodNeeded - foodConsumed)

    if foodConsumed < foodNeeded then
        log.messages[#log.messages + 1] = 'Food ran out! Colonists are starving.'
        for _, ent in ipairs(entities) do
            if ent.colonist and not ent.colonist.dead then
                ent.colonist.health = math.max(10, (ent.colonist.health or 100) - daysPassed * 5)
            end
        end
    end
    log.resourceChanges.food = -foodConsumed

    -- Fuel consumption
    local fuelNeeded = math.ceil(FUEL_PER_DAY_BASE * daysPassed)
    local fuelConsumed = consumeFromStorage('fuel', fuelNeeded)
    if fuelConsumed < fuelNeeded then
        log.messages[#log.messages + 1] = 'Fuel depleted! Reactor offline, colony freezing.'
    end
    log.resourceChanges.fuel = -fuelConsumed

    -- Production (automation-driven)
    if automationScore > 0 then
        if not snapshot.backgroundProduction then
            snapshot.backgroundProduction = {}
        end

        -- Simplified: each machine with a recipe produces a small output
        local machineCount = 0
        for _, ent in ipairs(entities) do
            if ent.machine and ent.machine.recipe then
                machineCount = machineCount + 1
            end
        end

        -- Generic production: machineCount * automationScore * daysPassed items
        local produced = math.floor(machineCount * automationScore * daysPassed)
        if produced > 0 then
            -- Distribute across common outputs
            snapshot.backgroundProduction['metal_ingot'] =
                (snapshot.backgroundProduction['metal_ingot'] or 0) + math.ceil(produced * 0.4)
            snapshot.backgroundProduction['lumber'] =
                (snapshot.backgroundProduction['lumber'] or 0) + math.ceil(produced * 0.3)
            snapshot.backgroundProduction['components'] =
                (snapshot.backgroundProduction['components'] or 0) + math.ceil(produced * 0.1)
            log.messages[#log.messages + 1] = 'Automated production generated ' .. produced .. ' items.'
            log.resourceChanges.produced = produced
        end
    end

    -- Building decay
    local brokenCount = 0
    for _, ent in ipairs(entities) do
        if ent.durability then
            ent.durability.hp = (ent.durability.hp or 100) - DURABILITY_DECAY_PER_DAY * daysPassed
            if ent.durability.hp <= 0 then
                ent.durability.hp = 0
                brokenCount = brokenCount + 1
            end
        end
    end
    if brokenCount > 0 then
        log.messages[#log.messages + 1] = brokenCount .. ' buildings broke down from neglect.'
    end

    return log
end

---------------------------------------------------------------------------
-- Convert backgroundProduction to physical items on colony restore
---------------------------------------------------------------------------

function BackgroundColony.spawnProduction(snapshot)
    if not snapshot or not snapshot.backgroundProduction then return end

    local produced = snapshot.backgroundProduction
    if not next(produced) then return end

    -- Find first storage entity with free slots
    local entities = snapshot.entities or {}
    for _, ent in ipairs(entities) do
        if ent.storage and ent.storage.contents then
            local stor = ent.storage
            for itemId, amount in pairs(produced) do
                if amount > 0 then
                    -- Find empty slot
                    for i = 1, (stor.slots or 0) do
                        if not stor.contents[i] then
                            stor.contents[i] = {
                                itemId = itemId,
                                amount = amount,
                                quality = 'normal',
                            }
                            produced[itemId] = 0
                            break
                        end
                    end
                end
            end
        end
    end

    -- Clear processed production
    snapshot.backgroundProduction = nil
end

return BackgroundColony
```

- [ ] **Step 2: Commit**

```
feat(space): add background colony simulation

Counter-based tick for absent colonies — consumes food/fuel from
storage entities, produces items based on automation score, decays
buildings. Spawns production as physical items on colony return.
```

---

## Chunk 4: Ship Definitions, Ship Manager & Milestones

### Task 10: Create Ship Definitions

**Files:**
- Create: `src/space/ship_defs.lua`

- [ ] **Step 1: Write ship tier and prebuilt definitions**

```lua
-- ship_defs.lua — Ship tier definitions and prebuilt layouts
-- Defines hull sizes, required modules, and preset layouts for both ship tiers.

local ShipDefs = {}

---------------------------------------------------------------------------
-- Ship tiers
---------------------------------------------------------------------------

ShipDefs.TIERS = {
    scout = {
        id = 'scout',
        name = 'Scout Ship',
        gridW = 12,
        gridH = 8,
        fuelCapacity = 100,
        baseSpeed = 3,      -- tiles per tick at full thrust
        baseStealth = 0.3,  -- signature multiplier (lower = stealthier)
        requiredModules = {
            { id = 'cockpit',       name = 'Cockpit',       w = 2, h = 2 },
            { id = 'engine',        name = 'Engine',        w = 2, h = 3 },
            { id = 'life_support',  name = 'Life Support',  w = 1, h = 2 },
            { id = 'mini_reactor',  name = 'Mini Reactor',  w = 1, h = 1 },
        },
    },
    colony = {
        id = 'colony',
        name = 'Colony Ship',
        gridW = 30,
        gridH = 20,
        fuelCapacity = 500,
        baseSpeed = 1,
        baseStealth = 1.0,  -- cannot effectively stealth
        requiredModules = {
            { id = 'bridge',          name = 'Bridge',          w = 3, h = 3 },
            { id = 'engine_bay',      name = 'Engine Bay',      w = 3, h = 4 },
            { id = 'life_support_array', name = 'Life Support Array', w = 2, h = 3 },
            { id = 'reactor',         name = 'Reactor',         w = 3, h = 3 },
        },
    },
}

---------------------------------------------------------------------------
-- Prebuilt layouts
-- Each layout is a list of { moduleId, x, y } placements + optional
-- extra buildings (beds, storage, etc.) at specific coordinates.
---------------------------------------------------------------------------

ShipDefs.PREBUILTS = {
    -- Scout prebuilts
    scout_survey_runner = {
        tier = 'scout',
        name = 'Mammona Survey Runner',
        desc = 'Balanced scout with cargo bay and one weapon mount.',
        modules = {
            { id = 'cockpit',      x = 5, y = 1 },
            { id = 'engine',       x = 0, y = 3 },
            { id = 'life_support', x = 3, y = 1 },
            { id = 'mini_reactor', x = 3, y = 3 },
        },
        extras = {
            { building = 'storage_crate', x = 8, y = 1 },
            { building = 'bed',           x = 8, y = 4 },
        },
    },
    scout_smuggler = {
        tier = 'scout',
        name = "Smuggler's Skiff",
        desc = 'Stealth-optimized. Hidden cargo, no weapons.',
        modules = {
            { id = 'cockpit',      x = 5, y = 1 },
            { id = 'engine',       x = 0, y = 3 },
            { id = 'life_support', x = 3, y = 1 },
            { id = 'mini_reactor', x = 3, y = 3 },
        },
        extras = {
            { building = 'storage_crate', x = 8, y = 1 },
            { building = 'storage_crate', x = 9, y = 1 },
            { building = 'bed',           x = 8, y = 4 },
        },
    },
    scout_empty = {
        tier = 'scout',
        name = 'Empty Hull',
        desc = 'Required modules only. Maximum creative freedom.',
        modules = {
            { id = 'cockpit',      x = 5, y = 1 },
            { id = 'engine',       x = 0, y = 3 },
            { id = 'life_support', x = 3, y = 1 },
            { id = 'mini_reactor', x = 3, y = 3 },
        },
        extras = {},
    },
    -- Colony ship prebuilts
    colony_hauler = {
        tier = 'colony',
        name = 'Mammona Frontier Hauler',
        desc = 'Cargo-focused. Large holds, minimal weapons, thick hull.',
        modules = {
            { id = 'bridge',              x = 13, y = 1 },
            { id = 'engine_bay',          x = 0,  y = 8 },
            { id = 'life_support_array',  x = 4,  y = 1 },
            { id = 'reactor',             x = 4,  y = 8 },
        },
        extras = {},
    },
    colony_corvette = {
        tier = 'colony',
        name = 'UTC Decommissioned Corvette',
        desc = 'Combat-focused. Multiple weapon mounts, shields, armored bridge.',
        modules = {
            { id = 'bridge',              x = 13, y = 1 },
            { id = 'engine_bay',          x = 0,  y = 8 },
            { id = 'life_support_array',  x = 4,  y = 1 },
            { id = 'reactor',             x = 4,  y = 8 },
        },
        extras = {},
    },
    colony_pioneer = {
        tier = 'colony',
        name = 'Pioneer Vessel',
        desc = 'Balanced. Farm bay, med bay, workshop, moderate everything.',
        modules = {
            { id = 'bridge',              x = 13, y = 1 },
            { id = 'engine_bay',          x = 0,  y = 8 },
            { id = 'life_support_array',  x = 4,  y = 1 },
            { id = 'reactor',             x = 4,  y = 8 },
        },
        extras = {},
    },
    colony_empty = {
        tier = 'colony',
        name = 'Empty Hull',
        desc = 'Required modules only. Full creative freedom.',
        modules = {
            { id = 'bridge',              x = 13, y = 1 },
            { id = 'engine_bay',          x = 0,  y = 8 },
            { id = 'life_support_array',  x = 4,  y = 1 },
            { id = 'reactor',             x = 4,  y = 8 },
        },
        extras = {},
    },
}

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

function ShipDefs.getTier(tierId)
    return ShipDefs.TIERS[tierId]
end

function ShipDefs.getPrebuilt(prebuiltId)
    return ShipDefs.PREBUILTS[prebuiltId]
end

function ShipDefs.getPrebuiltsForTier(tierId)
    local result = {}
    for id, def in pairs(ShipDefs.PREBUILTS) do
        if def.tier == tierId then
            result[#result + 1] = { id = id, def = def }
        end
    end
    return result
end

return ShipDefs
```

- [ ] **Step 2: Commit**

```
feat(space): add ship tier and prebuilt layout definitions

Two tiers (scout 12x8, colony 30x20) with required modules,
speed/stealth/fuel stats. 7 prebuilt layouts across both tiers.
```

---

### Task 11: Create Ship Manager Module

**Files:**
- Create: `src/space/ship_manager.lua`

- [ ] **Step 1: Write ship manager**

```lua
-- ship_manager.lua — Ship entity group management
-- Creates ship entities from definitions, stamps ships onto colony maps
-- for landing, and extracts them on launch.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ShipManager = {}

---------------------------------------------------------------------------
-- Create a ship entity group from a tier + prebuilt definition
---------------------------------------------------------------------------

function ShipManager.createShip(tierId, prebuiltId)
    local ok, ShipDefs = pcall(require, 'src.space.ship_defs')
    if not ok then return nil end

    local tier = ShipDefs.getTier(tierId)
    if not tier then return nil end

    local prebuilt = prebuiltId and ShipDefs.getPrebuilt(prebuiltId)

    -- Create ship anchor entity
    local shipId = ECS.spawn()
    ECS.set(shipId, 'ship', {
        shipId   = shipId,
        tier     = tierId,
        velocity = 0,
        heading  = 0,       -- radians, 0 = right
        fuel     = tier.fuelCapacity,
        hullHP   = 100,
    })
    ECS.set(shipId, 'pos', { x = 0, y = 0 })

    -- Place required modules as entities
    local modules = (prebuilt and prebuilt.modules) or {}
    for _, mod in ipairs(modules) do
        local modId = ECS.spawn()
        ECS.set(modId, 'pos', { x = mod.x, y = mod.y })
        ECS.set(modId, 'ship_module', {
            shipId     = shipId,
            systemType = mod.id,
            operational = true,
            efficiency = 1.0,
        })
        ECS.set(modId, 'durability', { hp = 100, maxHp = 100 })
    end

    -- Place extra buildings from prebuilt
    if prebuilt and prebuilt.extras then
        for _, extra in ipairs(prebuilt.extras) do
            local extraId = ECS.spawn()
            ECS.set(extraId, 'pos', { x = extra.x, y = extra.y })
            ECS.set(extraId, 'building_ref', { buildingId = extra.building })
            ECS.set(extraId, 'ship_module', {
                shipId     = shipId,
                systemType = extra.building,
                operational = true,
                efficiency = 1.0,
            })
            ECS.set(extraId, 'durability', { hp = 100, maxHp = 100 })
        end
    end

    return shipId
end

---------------------------------------------------------------------------
-- Stamp ship entities onto a colony tilemap at landing pad position
---------------------------------------------------------------------------

function ShipManager.stampOntoColony(shipSnapshot, padX, padY)
    if not shipSnapshot or not shipSnapshot.entities then return false end

    local World = require('src.world.tilemap')
    local Tiles = require('src.world.tiles')

    -- Find ship origin from the anchor entity's pos
    local originX, originY = 0, 0
    for _, ent in ipairs(shipSnapshot.entities) do
        if ent.ship then
            originX = ent.pos and ent.pos.x or 0
            originY = ent.pos and ent.pos.y or 0
            break
        end
    end

    -- Spawn ship entities with translated positions
    for _, ent in ipairs(shipSnapshot.entities) do
        local id = ECS.spawn()
        for compName, compData in pairs(ent) do
            if compName == '_savedId' then
                -- skip
            elseif compName == 'pos' then
                -- Translate position relative to landing pad
                ECS.set(id, 'pos', {
                    x = padX + (compData.x - originX),
                    y = padY + (compData.y - originY),
                })
            else
                ECS.set(id, compName, compData)
            end
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Extract ship entities from colony tilemap on launch
---------------------------------------------------------------------------

function ShipManager.extractFromColony(padX, padY, shipW, shipH)
    local snapshot = { entities = {} }

    -- Component list for extraction — mirrors KNOWN_COMPONENTS in save_helpers.lua
    -- plus new ship components. Must stay in sync with save_helpers.lua.
    local EXTRACT_COMPONENTS = {
        'pos', 'colonist', 'needs', 'inventory', 'path',
        'schedule', 'workPriority', 'creature', 'machine',
        'bed', 'decoration', 'durability', 'building_ref',
        'merchant', 'disease', 'steam_hub', 'body', 'equipment',
        'prisoner', 'cloning_vat', 'radio_beacon', 'raid_tag', 'boss',
        'crop', 'artifact', 'sensor',
        'item', 'away', 'projectile', 'status_effects',
        'wounds', 'diseaseImmunity', 'tamed', 'suit',
        'lair', 'eldritch_growth', 'deep_drill', 'inserter', 'research_bench',
        'turret', 'trap', 'shield', 'watchtower', 'quest_board',
        'addictions', 'cover',
        'pipe_node', 'tank', 'processor',
        'battery', 'power_switch',
        'ordnance', 'stockpile', 'rival',
        'laser_fence', 'endgame_building', 'visitor', 'recreation',
        'containment_cell', 'radiation', 'miner', 'storage', 'clothing',
        'ship', 'ship_module', 'ship_crew', 'weapon_mount',
        'stealth', 'space_suit', 'npc_ship',
    }

    -- Find all entities within the ship bounding box
    local toRemove = {}
    for id, comps in ECS.query('pos') do
        local pos = comps.pos
        if pos.x >= padX and pos.x < padX + shipW
           and pos.y >= padY and pos.y < padY + shipH then
            local ent = { _savedId = id }
            for _, c in ipairs(EXTRACT_COMPONENTS) do
                local data = ECS.get(id, c)
                if data then
                    if c == 'pos' then
                        ent.pos = {
                            x = data.x - padX,
                            y = data.y - padY,
                        }
                    else
                        ent[c] = data
                    end
                end
            end
            snapshot.entities[#snapshot.entities + 1] = ent
            toRemove[#toRemove + 1] = id
        end
    end

    -- Remove ship entities from colony ECS
    for _, id in ipairs(toRemove) do
        ECS.destroy(id)
    end

    return snapshot
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function ShipManager.getShipAnchor()
    for id, comps in ECS.query('ship') do
        return id, comps.ship
    end
    return nil
end

function ShipManager.getShipModules(shipId)
    local modules = {}
    for id, comps in ECS.query('ship_module') do
        if comps.ship_module.shipId == shipId then
            modules[#modules + 1] = {
                entityId = id,
                systemType = comps.ship_module.systemType,
                operational = comps.ship_module.operational,
                efficiency = comps.ship_module.efficiency,
            }
        end
    end
    return modules
end

return ShipManager
```

- [ ] **Step 2: Commit**

```
feat(space): add ship manager for entity group lifecycle

Creates ship entities from defs, stamps onto colony map for landing
(translating positions), extracts on launch. Queries ship anchor
and modules via ECS.
```

---

### Task 12: Create Milestones Module

**Files:**
- Create: `src/sim/milestones.lua`
- Modify: `src/sim/endgame.lua`

- [ ] **Step 1: Write milestones module**

```lua
-- milestones.lua — Victory milestone system
-- Replaces game-ending triggerVictory calls with milestone rewards
-- that open new gameplay without forcing an end state.

local GameState = require('src.game_state')

local Milestones = {}

---------------------------------------------------------------------------
-- Milestone definitions
---------------------------------------------------------------------------

local MILESTONE_DEFS = {
    mammona_claim = {
        name = 'Mammona Claim',
        desc = 'Mammona has stamped this world as a secured industrial foothold.',
    },
    seal_deep = {
        name = 'Seal The Deep',
        desc = 'The anomaly is contained. The planet sleeps again.',
    },
    mammona_extraction = {
        name = 'Mammona Extraction',
        desc = 'The fleet is inbound. Mammona is coming for the reserves.',
    },
}

---------------------------------------------------------------------------
-- Complete a milestone
---------------------------------------------------------------------------

function Milestones.complete(milestoneId)
    local def = MILESTONE_DEFS[milestoneId]
    if not def then return false end

    if milestoneId == 'mammona_claim' then
        GameState.mammonaClaimed = true

        -- Reward: spawn reinforcement colonists
        local cok, Colonist = pcall(require, 'src.colonist.colonist')
        if cok and Colonist.spawnInitial then
            Colonist.spawnInitial(GameState.startX, GameState.startY, 3)
        end

        -- Log event
        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok and Storyteller.logEvent then
            Storyteller.logEvent('milestone_mammona_claim', {})
        end

    elseif milestoneId == 'seal_deep' then
        GameState.sealedDeep = true

        -- Reward: set anomaly to 0 permanently
        local aok, Anomaly = pcall(require, 'src.sim.anomaly')
        if aok then
            if Anomaly.setLevel then Anomaly.setLevel(0) end
            if Anomaly.setSealedPermanently then Anomaly.setSealedPermanently(true) end
        end

        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok and Storyteller.logEvent then
            Storyteller.logEvent('milestone_seal_deep', {})
        end

    elseif milestoneId == 'mammona_extraction' then
        GameState.extractionComplete = true

        -- Reward: massive resource injection
        local items = {
            { itemId = 'steel', amount = 200 },
            { itemId = 'components', amount = 100 },
            { itemId = 'circuits', amount = 50 },
        }
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn then
            for _, item in ipairs(items) do
                Items.spawn(GameState.startX + math.random(-3, 3),
                           GameState.startY + math.random(-3, 3),
                           item.itemId, item.amount)
            end
        end

        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok and Storyteller.logEvent then
            Storyteller.logEvent('milestone_mammona_extraction', {})
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function Milestones.isComplete(milestoneId)
    if milestoneId == 'mammona_claim' then return GameState.mammonaClaimed end
    if milestoneId == 'seal_deep' then return GameState.sealedDeep end
    if milestoneId == 'mammona_extraction' then return GameState.extractionComplete end
    return false
end

function Milestones.getDef(milestoneId)
    return MILESTONE_DEFS[milestoneId]
end

return Milestones
```

- [ ] **Step 2: Read current endgame.lua**

Read `src/sim/endgame.lua` to find the four `triggerVictory` calls.

- [ ] **Step 3: Replace triggerVictory calls with Milestone.complete**

In `endgame.lua`, replace each `GameOverMod.triggerVictory(...)` call:

For `transmission_array` (mammona claim):
```lua
-- Replace: GameOverMod.triggerVictory('mammona_claim', ...)
-- With:
local mok, Milestones = pcall(require, 'src.sim.milestones')
if mok then Milestones.complete('mammona_claim') end
```

For `sealing_apparatus` (seal deep):
```lua
local mok, Milestones = pcall(require, 'src.sim.milestones')
if mok then Milestones.complete('seal_deep') end
```

For `extraction_beacon` (mammona extraction):
```lua
local mok, Milestones = pcall(require, 'src.sim.milestones')
if mok then Milestones.complete('mammona_extraction') end
```

For `launch_pad`: Remove the entire activating handler. The launch_pad building type should no longer trigger any endgame phase. Remove it from the ENDGAME_TYPES table if it exists there, or change its handler to do nothing (it becomes a prerequisite building for the shipyard, not an endgame trigger).

- [ ] **Step 4: Commit**

```
feat(endgame): replace victory endings with milestone rewards

Victory conditions no longer end the game. Mammona Claim spawns
reinforcements, Seal Deep zeroes anomaly, Extraction injects
resources. Launch pad removed from endgame triggers (becomes
shipyard prerequisite in future phase).
```

---

### Task 13: Create Ship Movement Module

**Files:**
- Create: `src/space/ship_movement.lua`

- [ ] **Step 1: Write ship movement system**

```lua
-- ship_movement.lua — Ship navigation on space tilemap
-- Handles thrust, heading, drift, fuel consumption.
-- Registered as an ECS system that ticks for entities with 'ship' + 'pos'.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local ShipMovement = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local FUEL_PER_THRUST = 0.1   -- fuel consumed per tile moved
local DRIFT_DECAY     = 0.95  -- velocity multiplier when no thrust (drift slows)

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local targetX, targetY = nil, nil   -- autopilot destination
local thrustActive = false

---------------------------------------------------------------------------
-- ECS System
---------------------------------------------------------------------------

function ShipMovement.registerSystems()
    ECS.addSystem('ship_movement', {'ship', 'pos'}, function(dt, id, comps)
        if GameState.activeMap ~= 'space' then return end

        local ship = comps.ship
        local pos  = comps.pos

        -- Autopilot: set heading toward target
        if targetX and targetY then
            local dx = targetX - pos.x
            local dy = targetY - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < 2 then
                -- Arrived
                targetX, targetY = nil, nil
                ship.velocity = 0
                thrustActive = false
            else
                ship.heading = math.atan2(dy, dx)
                thrustActive = true
            end
        end

        -- Apply thrust
        if thrustActive and ship.fuel > 0 then
            local ok, ShipDefs = pcall(require, 'src.space.ship_defs')
            local tier = ok and ShipDefs.getTier(ship.tier)
            local maxSpeed = tier and tier.baseSpeed or 2

            ship.velocity = math.min(maxSpeed, ship.velocity + 0.5)
            ship.fuel = math.max(0, ship.fuel - FUEL_PER_THRUST * ship.velocity)
        else
            -- Drift (no fuel or no thrust)
            ship.velocity = ship.velocity * DRIFT_DECAY
            if ship.velocity < 0.01 then ship.velocity = 0 end
        end

        -- Move ship
        if ship.velocity > 0 then
            local moveX = math.cos(ship.heading) * ship.velocity * dt
            local moveY = math.sin(ship.heading) * ship.velocity * dt

            pos.x = pos.x + moveX
            pos.y = pos.y + moveY

            -- Update chunk tracking
            local stOk, SpaceTilemap = pcall(require, 'src.space.space_tilemap')
            if stOk then
                local cx = math.floor(pos.x / SpaceTilemap.CHUNK_SIZE)
                local cy = math.floor(pos.y / SpaceTilemap.CHUNK_SIZE)
                SpaceTilemap.setShipChunk(cx, cy)
                SpaceTilemap.unloadDistantChunks(3)
            end
        end
    end)
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

function ShipMovement.setAutopilot(x, y)
    targetX = x
    targetY = y
    thrustActive = true
end

function ShipMovement.cancelAutopilot()
    targetX, targetY = nil, nil
    thrustActive = false
end

function ShipMovement.setThrust(active)
    thrustActive = active
end

function ShipMovement.setHeading(radians)
    local shipId, ship = nil, nil
    for id, comps in ECS.query('ship') do
        shipId = id
        ship = comps.ship
        break
    end
    if ship then
        ship.heading = radians
    end
end

function ShipMovement.getState()
    return {
        targetX = targetX,
        targetY = targetY,
        thrustActive = thrustActive,
    }
end

function ShipMovement.loadState(state)
    if not state then return end
    targetX = state.targetX
    targetY = state.targetY
    thrustActive = state.thrustActive or false
end

return ShipMovement
```

- [ ] **Step 2: Commit**

```
feat(space): add ship movement system

ECS system for ship navigation — thrust, heading, drift, fuel
consumption, autopilot to coordinates. Tracks chunk position
for space tilemap loading/unloading.
```

---

### Task 14: Wire Space Systems into Main Loop

**Files:**
- Modify: `main.lua`

- [ ] **Step 1: Read main.lua system init and update blocks**

Read `main.lua` lines 100-150 (requires) and lines 820-830 (update loop).

- [ ] **Step 2: Add space module requires**

Near the top of main.lua with other requires, add:

```lua
local SpaceTilemap   = require('src.space.space_tilemap')
local ContextSwap    = require('src.space.context_swap')
local ShipMovement   = require('src.space.ship_movement')
local ShipManager    = require('src.space.ship_manager')
local BackgroundColony = require('src.space.background_colony')
local Milestones     = require('src.sim.milestones')
```

Use the same `pcall` + `loadOptional` pattern used by other optional modules if needed.

- [ ] **Step 3: Register ship movement system in initGameWorld**

In the system registration block (around line 496-549), add:

```lua
if ShipMovement and ShipMovement.registerSystems then ShipMovement.registerSystems() end
```

- [ ] **Step 4: Add background colony tick to update loop**

In the simulation update block (inside the fixed timestep `while accumulator >= SIM_DT`), add after existing system steps:

```lua
-- Background colony tick (once per game day while in space)
if ContextSwap.isInSpace() and GameState.colonies then
    for colonyId, colony in pairs(GameState.colonies) do
        if colony.lastTickDay and colony.lastTickDay < GameState.day then
            local daysPassed = GameState.day - colony.lastTickDay
            BackgroundColony.tick(colony.snapshot, daysPassed, colony.automationScore)
            colony.lastTickDay = GameState.day
        end
    end
end
```

- [ ] **Step 5: Verify game launches without errors**

Launch game, start new colony, verify no crashes from new requires.

- [ ] **Step 6: Commit**

```
feat(main): wire space systems into game loop

Register ship movement system, add background colony tick in
update loop, require all space modules at startup.
```

---

### Task 15: Integration Smoke Test

- [ ] **Step 1: Launch game, start new colony on Erebus**

Verify:
- Game starts normally
- F5 save works (save format is now v3)
- F9 load works (v3 loads correctly)
- No errors in console

- [ ] **Step 2: Verify v2 save migration**

If a v2 save exists, load it. Verify:
- Migrates to v3 without errors
- GameState.activeMap is set to 'erebus'
- GameState.discoveredPlanets contains 'erebus'
- GameState.colonies is empty table

- [ ] **Step 3: Verify space planet def loads**

In Love2D console or debug, run:
```lua
local PlanetDefs = require('src.world.planet_defs')
print(PlanetDefs.exists('space'))  -- should print true
local def = PlanetDefs.get('space')
print(def.atmosphere.ambientO2)    -- should print 0
```

- [ ] **Step 4: Verify space tilemap generates**

```lua
local ST = require('src.space.space_tilemap')
ST.init(12345)
local tile = ST.getTile(100, 100)
print('Space tile at 100,100:', tile)  -- should be VOID or ASTEROID
```

- [ ] **Step 5: Commit integration test results**

```
test: verify phase 1 core architecture integration

Confirmed: v3 save format, v2 migration, space planet def,
chunked tilemap generation, all existing systems unaffected.
```

---

## Summary

**Phase 1 delivers:**
1. GameState extensions for interplanetary state (Task 1)
2. New ECS components registered for persistence (Task 2)
3. Save format v3 with v2 migration (Task 3)
4. In-memory snapshot API for context-swap (Task 4)
5. Space planet definition (Task 5)
6. Chunked space tilemap with World API dispatch (Tasks 6-7)
7. Context swap orchestration (Task 8)
8. Background colony simulation (Task 9)
9. Ship definitions and prebuilt layouts (Task 10)
10. Ship entity group management (Task 11)
11. Milestone system replacing victory endings (Task 12)
12. Ship movement ECS system (Task 13)
13. Main loop integration (Task 14)
14. Integration smoke test (Task 15)

**What Phase 2 builds on top of this:**
- Ship interior building (place walls/modules on ship grid)
- Mini reactor building definition
- Shipyard construction flow
- Scout ship map secret discovery
- Ship navigation UI (heading, autopilot, fuel gauge)
- Ship interior rendering
