# Main Menu Overhaul + Landing Site + Input Model — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure Frosthold's pre-game flow into sequential RimWorld-style screens, add landing site selection, surface hidden world gen features, and gate right-click movement behind draft state.

**Architecture:** New phase state machine in main.lua routes to dedicated screen modules. Each screen is a self-contained Lua module with `init/draw/mousepressed/keypressed` methods. Existing data definitions (scenarios, difficulties, directors, factions, map sizes) stay in their current files — new screens just display them. Landing site preview uses lightweight noise sampling, not full world gen.

**Tech Stack:** Love2D 11.4, Lua 5.1/LuaJIT, ECS at `src/ecs/ecs.lua`

**Spec:** `docs/superpowers/specs/2026-03-15-main-menu-overhaul-design.md`

---

## Chunk 1: Foundation — Phase Machine, GameState, Tilemap API

### Task 1: Extend GameState with new fields

**Files:**
- Modify: `src/game_state.lua`

- [ ] **Step 1: Read current GameState fields**

Read `src/game_state.lua` fully — note where `phase`, `mapWidth`, `startX`, `startY`, `draftedColonists` are defined (around lines 4-221).

- [ ] **Step 2: Add new fields to GameState table**

Add these fields to the state table (near the existing `startX`/`startY` fields):

```lua
-- World generation (set by Create World screen)
worldSeed = '',              -- player-entered seed string
worldSeedNumeric = nil,      -- numeric hash for noise functions (nil = random)
selectedFactions = nil,      -- table of faction keys selected for this world
landingSiteSelected = false, -- true when player has chosen landing coords
```

- [ ] **Step 3: Reset new fields in GameState.init()**

In `GameState.init()` (around line 223), add resets for the new fields:

```lua
self.worldSeed = ''
self.worldSeedNumeric = nil
self.selectedFactions = nil
self.landingSiteSelected = false
```

- [ ] **Step 4: Test manually — launch game, confirm no errors**

Run: `love .` from project root
Expected: Game launches to existing start menu without errors. New fields exist but are unused.

- [ ] **Step 5: Commit**

```bash
git add src/game_state.lua
git commit -m "feat: add world gen fields to GameState (seed, factions, landing site)"
```

---

### Task 2: Modify Tilemap to accept seed parameter and expose sampleBiome

**Files:**
- Modify: `src/world/tilemap.lua`

- [ ] **Step 1: Read tilemap init and biome generation code**

Read `src/world/tilemap.lua` lines 95-140 to understand `Tilemap.init(w, h)` signature and `mapSeed` usage.

- [ ] **Step 2: Add optional seed parameter to Tilemap.init**

Change line ~101 from:
```lua
mapSeed = love.math.random(1, 999999)
```
to:
```lua
function Tilemap.init(w, h, seed)
    -- ... existing code ...
    mapSeed = seed or love.math.random(1, 999999)
```

Make sure the function signature on the `function Tilemap.init(w, h)` line gains the third `seed` parameter.

- [ ] **Step 3: Add Tilemap.sampleBiome function**

Add a new exported function at the end of the module (before `return Tilemap`). This runs ONLY the noise math — no tile creation, no entity spawning:

```lua
--- Sample biome type at (x, y) without generating tiles.
--- Used by landing site screen for lightweight preview.
--- @param x number tile X coordinate
--- @param y number tile Y coordinate
--- @param seed number numeric seed
--- @param w number map width
--- @param h number map height
--- @return string biome name, number elevation, number moisture
function Tilemap.sampleBiome(x, y, seed, w, h)
    local nx, ny = x / w, y / h
    local elevation = love.math.noise(nx * 6 + seed, ny * 6 + seed)
    local moisture  = love.math.noise(nx * 4 + seed + 100, ny * 4 + seed + 100)
    local biomeN    = love.math.noise(nx * 3.5 + seed + 400, ny * 3.5 + seed + 400)

    local biome = 'default'
    if biomeN < 0.2 and elevation < 0.55 then
        biome = 'marsh'
    elseif biomeN < 0.38 and moisture > 0.45 and elevation < 0.65 then
        biome = 'frozen_forest'
    elseif biomeN > 0.78 and elevation > 0.45 then
        biome = 'volcanic'
    elseif biomeN > 0.62 and elevation > 0.4 and elevation < 0.72 then
        biome = 'dead_forest'
    elseif elevation > 0.68 and moisture > 0.6 then
        biome = 'glacier'
    end

    return biome, elevation, moisture
end
```

- [ ] **Step 4: Test manually — launch game, start new colony, confirm terrain generates normally**

Run: `love .`
Expected: Game works exactly as before — seed defaults to random when no third arg passed. Terrain looks normal.

- [ ] **Step 5: Commit**

```bash
git add src/world/tilemap.lua
git commit -m "feat: tilemap accepts seed param, add sampleBiome for landing preview"
```

---

### Task 3: Modify Difficulty.apply() to preserve landing site coords

**Files:**
- Modify: `src/ui/difficulty.lua`

- [ ] **Step 1: Read Difficulty.apply()**

Read `src/ui/difficulty.lua` lines 286-317. Find where `GameState.startX` and `GameState.startY` are set (around lines 298-299):
```lua
GameState.startX = math.floor(ms / 2)
GameState.startY = math.floor(ms / 2)
```

- [ ] **Step 2: Guard startX/startY assignment**

Change the two lines to:
```lua
if not GameState.landingSiteSelected then
    GameState.startX = math.floor(ms / 2)
    GameState.startY = math.floor(ms / 2)
end
```

- [ ] **Step 3: Test manually — start game, confirm default start position unchanged**

Run: `love .`
Start a new colony. Verify colonists spawn at map center as before (landingSiteSelected defaults to false, so the guard is a no-op).

- [ ] **Step 4: Commit**

```bash
git add src/ui/difficulty.lua
git commit -m "fix: preserve player-selected landing coords in Difficulty.apply()"
```

---

### Task 4: Wire seed through initGameWorld

**Files:**
- Modify: `main.lua`

**NOTE:** In this codebase, `World` IS `Tilemap` — they are the same module (`src/world/tilemap.lua` is required as `World`). There is no separate `src/world/world.lua`. The call `World.init(w, h)` directly calls `Tilemap.init(w, h)`.

- [ ] **Step 1: Read initGameWorld World.init call**

Read `main.lua` line ~384 where `World.init(GameState.mapWidth, GameState.mapHeight)` is called. Confirm that `World` is required from `src.world.tilemap`.

- [ ] **Step 2: Pass seed to World.init**

Change:
```lua
World.init(GameState.mapWidth, GameState.mapHeight)
```
to:
```lua
World.init(GameState.mapWidth, GameState.mapHeight, GameState.worldSeedNumeric)
```

Since `World` IS `Tilemap`, and Task 2 already added the optional `seed` parameter to `Tilemap.init(w, h, seed)`, this will pass through directly.

- [ ] **Step 3: Test — start new game, confirm no errors**

Run: `love .`
Expected: Game starts normally. worldSeedNumeric is nil, so Tilemap falls back to random seed.

- [ ] **Step 4: Commit**

```bash
git add main.lua
git commit -m "feat: wire player seed through initGameWorld to Tilemap"
```

---

### Task 5: Modify Factions.init to accept whitelist

**Files:**
- Modify: `src/colony/factions.lua`

- [ ] **Step 1: Read Factions.init()**

Read `src/colony/factions.lua` lines 179-186. Currently initializes ALL factions to rep=0 (Mammona corps to rep=20).

- [ ] **Step 2: Add optional whitelist parameter**

**NOTE:** `FACTION_DEFS` is a hash table (keyed by faction id), NOT an array. Use `pairs()` not `ipairs()`.

Change `Factions.init()` to accept an optional whitelist:

```lua
function Factions.init(whitelist)
    reputation = {}
    for fid, def in pairs(FACTION_DEFS) do
        if not whitelist or whitelist[fid] then
            reputation[fid] = 0
        end
    end
    -- Mammona corps start friendly (if in whitelist or no whitelist)
    if reputation['mammona_logistics'] then
        reputation['mammona_logistics'] = 20
    end
    if reputation['mastema_ops'] then
        reputation['mastema_ops'] = 20
    end
end
```

- [ ] **Step 3: Wire whitelist from GameState in initGameWorld**

In `main.lua`'s `initGameWorld()`, find where `Factions.init()` is called. Change to:

```lua
local factionWhitelist = nil
if GameState.selectedFactions then
    factionWhitelist = {}
    for _, fid in ipairs(GameState.selectedFactions) do
        factionWhitelist[fid] = true
    end
end
Factions.init(factionWhitelist)
```

- [ ] **Step 4: Fix Factions.getAll() to only return initialized factions**

Read `Factions.getAll()` (line ~468). It iterates `FACTION_DEFS` (not `reputation`), so non-whitelisted factions would still appear with rep=0. Add a guard:

```lua
-- In Factions.getAll(), change the loop body to skip factions not in reputation:
for fid, def in pairs(FACTION_DEFS) do
    if reputation[fid] ~= nil then  -- only include initialized factions
        -- existing code to add to results
    end
end
```

This is a REQUIRED change, not conditional.

- [ ] **Step 5: Test — start game, confirm all factions still appear (no whitelist set)**

Run: `love .`
Expected: All factions work as before — whitelist is nil, so all get initialized.

- [ ] **Step 6: Commit**

```bash
git add src/colony/factions.lua main.lua
git commit -m "feat: Factions.init accepts optional whitelist for world creation"
```

---

### Task 6: Extend main.lua phase routing for new phases

**Files:**
- Modify: `main.lua`

- [ ] **Step 1: Read all phase-gated sections in main.lua**

Identify every `if GameState.phase ==` check. Key locations:
- `love.load()` — sets initial phase (line ~294)
- `love.update()` — lines 645-768
- `love.draw()` — lines 774-883
- `love.keypressed()` — lines 889-976
- `love.mousepressed()` — lines 990-1017
- `love.mousereleased()` — lines 1019-1023
- `love.wheelmoved()` — lines 1030-1048
- `love.textinput()` — lines 978-983

- [ ] **Step 2: Create stub modules for new screens FIRST (before adding requires)**

Create minimal stub files so `require()` won't fail. Each stub exports init/draw/keypressed/mousepressed as no-ops:

**`src/ui/main_menu.lua`:**
```lua
local MainMenu = {}

function MainMenu.init() end
function MainMenu.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FROSTHOLD - Main Menu (stub)", 100, 100)
end
function MainMenu.keypressed(key) end
function MainMenu.mousepressed(x, y, button) end

return MainMenu
```

**`src/ui/difficulty_select.lua`:**
```lua
local DifficultySelect = {}

function DifficultySelect.init() end
function DifficultySelect.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Difficulty Select (stub)", 100, 100)
end
function DifficultySelect.keypressed(key) end
function DifficultySelect.mousepressed(x, y, button) end
function DifficultySelect.mousereleased(x, y, button) end

return DifficultySelect
```

**`src/ui/create_world.lua`:**
```lua
local CreateWorld = {}

function CreateWorld.init() end
function CreateWorld.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Create World (stub)", 100, 100)
end
function CreateWorld.keypressed(key) end
function CreateWorld.mousepressed(x, y, button) end
function CreateWorld.mousereleased(x, y, button) end
function CreateWorld.textinput(text) end
function CreateWorld.wheelmoved(x, y) end

return CreateWorld
```

**`src/ui/landing_site.lua`:**
```lua
local LandingSite = {}

function LandingSite.init() end
function LandingSite.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Landing Site (stub)", 100, 100)
end
function LandingSite.keypressed(key) end
function LandingSite.mousepressed(x, y, button) end
function LandingSite.wheelmoved(x, y) end

return LandingSite
```

- [ ] **Step 3: Add requires for new screen modules at top of main.lua**

Add near existing UI requires:
```lua
local MainMenu = require('src.ui.main_menu')
local DifficultySelect = require('src.ui.difficulty_select')
local CreateWorld = require('src.ui.create_world')
local LandingSite = require('src.ui.landing_site')
```

- [ ] **Step 4: Change initial phase from 'setup' to 'menu'**

In `love.load()` (line ~294), change:
```lua
GameState.phase = 'setup'
```
to:
```lua
GameState.phase = 'menu'
MainMenu.init()
```

- [ ] **Step 5: Remove old 'setup' phase branches**

Search main.lua for all `GameState.phase == 'setup'` checks and remove/replace them. The 'setup' phase is dead — it's been split into 'menu', 'scenario', 'difficulty', 'worldgen', 'landing'.

- [ ] **Step 6: Add phase routing in love.update()**

The `love.update()` function needs to handle new pre-game phases (they are no-ops like 'setup' was, but must not fall through to the playing update):

```lua
if GameState.phase == 'menu' or GameState.phase == 'scenario' or GameState.phase == 'difficulty'
    or GameState.phase == 'worldgen' or GameState.phase == 'landing' then
    return  -- pre-game screens have no update logic
elseif GameState.phase == 'drafting' then
    -- existing no-op
```

- [ ] **Step 7: Add phase routing in love.draw()**

Add new phase branches before the existing 'setup' branch:
```lua
if GameState.phase == 'menu' then
    MainMenu.draw()
elseif GameState.phase == 'scenario' then
    StartMenu.draw()
elseif GameState.phase == 'difficulty' then
    DifficultySelect.draw()
elseif GameState.phase == 'worldgen' then
    CreateWorld.draw()
elseif GameState.phase == 'landing' then
    LandingSite.draw()
elseif GameState.phase == 'drafting' then
    -- existing ColonistSelect.draw()
```

- [ ] **Step 8: Add phase routing in love.keypressed()**

Add new branches:
```lua
if GameState.phase == 'menu' then
    MainMenu.keypressed(key)
    return
elseif GameState.phase == 'scenario' then
    StartMenu.keypressed(key)
    return
elseif GameState.phase == 'difficulty' then
    DifficultySelect.keypressed(key)
    return
elseif GameState.phase == 'worldgen' then
    CreateWorld.keypressed(key)
    return
elseif GameState.phase == 'landing' then
    LandingSite.keypressed(key)
    return
elseif GameState.phase == 'drafting' then
    -- existing
```

- [ ] **Step 9: Add phase routing in love.mousepressed()**

Same pattern — route to each screen's `.mousepressed(x, y, button)`.

- [ ] **Step 10: Add love.mousemoved() routing for pre-game phases**

Currently `love.mousemoved` returns early for non-playing phases. Add routing for difficulty screen (slider drags):
```lua
if GameState.phase == 'difficulty' then
    DifficultySelect.mousemoved(x, y, dx, dy)
    return
elseif GameState.phase == 'playing' then
    -- existing code
end
```

- [ ] **Step 11: Extend love.mousereleased() for pre-game phases**

Change the guard from `phase ~= 'playing'` to allow new phases:
```lua
if GameState.phase == 'worldgen' then
    CreateWorld.mousereleased(x, y, button)
elseif GameState.phase == 'difficulty' then
    DifficultySelect.mousereleased(x, y, button)
elseif GameState.phase == 'playing' then
    UI.mousereleased(x, y, button)
    Input.mousereleased(x, y, button)
end
```

- [ ] **Step 12: Extend love.textinput() for worldgen phase**

Change the guard to allow worldgen:
```lua
if GameState.phase == 'worldgen' then
    CreateWorld.textinput(text)
    return
elseif GameState.phase ~= 'playing' then
    return
end
```

- [ ] **Step 13: Extend love.wheelmoved() for pre-game scrollable lists**

```lua
if GameState.phase == 'scenario' then
    StartMenu.wheelmoved(x, y)
    return
elseif GameState.phase == 'worldgen' then
    CreateWorld.wheelmoved(x, y)
    return
elseif GameState.phase == 'landing' then
    LandingSite.wheelmoved(x, y)
    return
elseif GameState.phase ~= 'playing' then
    return
end
```

- [ ] **Step 14: Test — game launches and shows MainMenu stub**

Run: `love .`
Expected: "FROSTHOLD - Main Menu (stub)" shown on screen. No errors in console.

- [ ] **Step 15: Commit**

```bash
git add main.lua src/ui/main_menu.lua src/ui/difficulty_select.lua src/ui/create_world.lua src/ui/landing_site.lua
git commit -m "feat: extend phase machine for sequential pre-game screens (stubs)"
```

---

## Chunk 2: Main Menu Screen

### Task 7: Implement MainMenu with background art and button stack

**Files:**
- Modify: `src/ui/main_menu.lua`
- Create: `assets/menu_bg.png` (placeholder)

- [ ] **Step 1: Read existing UI styling patterns**

Read `src/ui/start_menu.lua` lines 65-80 (init/fonts) and lines 182-240 (draw) to understand the project's font creation and drawing conventions (colors, button styles, layout math).

- [ ] **Step 2: Create placeholder background image**

Create a simple 1280x720 dark gradient PNG. If `love.image` can't easily generate one, use a programmatic fallback in the draw code — draw a gradient rectangle. No need for an actual PNG file initially; the code will draw a gradient if the image isn't found.

- [ ] **Step 3: Implement MainMenu module**

Replace the stub `src/ui/main_menu.lua` with full implementation:

```lua
local MainMenu = {}

local Save = require('src.persistence.save_slots')  -- save_slots has exists(), getMostRecentSave(), getSlotList()

local titleFont, subtitleFont, buttonFont, versionFont
local bgImage
local hoverIndex = 0

-- Button definitions (order matters)
local buttons = {}

local function rebuildButtons()
    buttons = {}
    -- Continue only if saves exist
    if Save.exists and Save.exists() then
        buttons[#buttons + 1] = { label = 'Continue',   action = 'continue' }
    end
    buttons[#buttons + 1] = { label = 'New Colony',  action = 'new' }
    buttons[#buttons + 1] = { label = 'Load Game',   action = 'load' }
    buttons[#buttons + 1] = { label = 'Options',     action = 'options' }
    buttons[#buttons + 1] = { label = 'Credits',     action = 'credits' }
    buttons[#buttons + 1] = { label = 'Quit',        action = 'quit' }
end

function MainMenu.init()
    titleFont    = love.graphics.newFont(48)
    subtitleFont = love.graphics.newFont(18)
    buttonFont   = love.graphics.newFont(20)
    versionFont  = love.graphics.newFont(12)

    -- Try to load background image
    local ok, img = pcall(love.graphics.newImage, 'assets/menu_bg.png')
    bgImage = ok and img or nil

    rebuildButtons()
    hoverIndex = 0
end

local function getButtonLayout()
    local W, H = love.graphics.getDimensions()
    local btnW, btnH = 220, 44
    local gap = 10
    local totalH = #buttons * btnH + (#buttons - 1) * gap
    local startX = W - btnW - 80
    local startY = (H - totalH) / 2 + 60
    return startX, startY, btnW, btnH, gap
end

function MainMenu.draw()
    local W, H = love.graphics.getDimensions()

    -- Background
    if bgImage then
        local sx = W / bgImage:getWidth()
        local sy = H / bgImage:getHeight()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(bgImage, 0, 0, 0, sx, sy)
    else
        -- Gradient fallback: dark blue-gray to black (two triangles)
        local mesh = love.graphics.newMesh({
            {0, 0,  0, 0,  0.08, 0.12, 0.20, 1},  -- top-left: dark blue
            {W, 0,  1, 0,  0.08, 0.12, 0.20, 1},  -- top-right
            {W, H,  1, 1,  0.02, 0.03, 0.05, 1},  -- bottom-right: near black
            {0, H,  0, 1,  0.02, 0.03, 0.05, 1},  -- bottom-left
        }, 'fan')
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(mesh)
    end

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.85, 0.9, 0.95)
    local titleText = 'FROSTHOLD'
    local titleW = titleFont:getWidth(titleText)
    love.graphics.print(titleText, W - titleW - 80, 80)

    -- Subtitle
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.6, 0.65, 0.7)
    local subText = 'A colony survival sim'
    local subW = subtitleFont:getWidth(subText)
    love.graphics.print(subText, W - subW - 80, 135)

    -- Buttons
    local bx, by, bw, bh, gap = getButtonLayout()
    love.graphics.setFont(buttonFont)
    local mx, my = love.mouse.getPosition()
    for i, btn in ipairs(buttons) do
        local y = by + (i - 1) * (bh + gap)
        local hover = mx >= bx and mx <= bx + bw and my >= y and my <= y + bh

        -- Button background
        if hover then
            love.graphics.setColor(0.55, 0.42, 0.2, 0.95)
        else
            love.graphics.setColor(0.35, 0.28, 0.15, 0.85)
        end
        love.graphics.rectangle('fill', bx, y, bw, bh, 4)

        -- Button border
        love.graphics.setColor(0.6, 0.5, 0.3, 0.6)
        love.graphics.rectangle('line', bx, y, bw, bh, 4)

        -- Button text (centered)
        love.graphics.setColor(0.9, 0.85, 0.75)
        local tw = buttonFont:getWidth(btn.label)
        local th = buttonFont:getHeight()
        love.graphics.print(btn.label, bx + (bw - tw) / 2, y + (bh - th) / 2)
    end

    -- Version string
    love.graphics.setFont(versionFont)
    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.print('Frosthold v0.1 (dev)', 10, H - 24)
end

function MainMenu.mousepressed(x, y, button)
    if button ~= 1 then return end

    local bx, by, bw, bh, gap = getButtonLayout()
    for i, btn in ipairs(buttons) do
        local btnY = by + (i - 1) * (bh + gap)
        if x >= bx and x <= bx + bw and y >= btnY and y <= btnY + bh then
            MainMenu._doAction(btn.action)
            return
        end
    end
end

function MainMenu._doAction(action)
    local GameState = require('src.game_state')
    if action == 'new' then
        local StartMenu = require('src.ui.start_menu')
        StartMenu.init()
        GameState.phase = 'scenario'
    elseif action == 'continue' then
        -- Load most recent save
        local recent = Save.getMostRecentSave and Save.getMostRecentSave()
        if recent then
            GameState._pendingLoad = recent.slot or recent.id or 1
            GameState.phase = 'starting'
        end
    elseif action == 'load' then
        -- Open save browser overlay (use existing SaveMenu)
        local ok, SaveMenu = pcall(require, 'src.ui.save_menu')
        if ok and SaveMenu then
            SaveMenu.open()
        end
    elseif action == 'options' then
        local ok, Settings = pcall(require, 'src.ui.settings_panel')
        if ok and Settings then
            Settings.open()
        end
    elseif action == 'credits' then
        -- Simple credits overlay — TODO
    elseif action == 'quit' then
        love.event.quit()
    end
end

function MainMenu.keypressed(key)
    if key == 'return' or key == 'kpenter' then
        -- Default action: New Colony
        MainMenu._doAction('new')
    elseif key == 'escape' then
        love.event.quit()
    end
end

return MainMenu
```

- [ ] **Step 4: Test — launch game, see main menu with title and buttons**

Run: `love .`
Expected: Dark gradient background, "FROSTHOLD" title upper-right, button stack with hover effects. Click "New Colony" to transition (will show scenario stub or current start menu depending on wiring).

- [ ] **Step 5: Commit**

```bash
git add src/ui/main_menu.lua
git commit -m "feat: implement main menu screen with title, buttons, gradient background"
```

---

## Chunk 3: Scenario Selection Screen

### Task 8: Convert start_menu.lua to scenario-only picker

**Files:**
- Modify: `src/ui/start_menu.lua`

- [ ] **Step 1: Read current start_menu.lua fully**

Read all 636 lines. Understand the 3-column layout, the custom tuning section, and the button handling.

- [ ] **Step 2: Refactor to two-panel scenario picker**

Strip out the difficulty and AI director columns. Keep only:
- Left panel: scrollable scenario list with name + description + colonist count
- Right panel: full description of selected scenario
- Bottom bar: Back / Next

The scenario data stays in `difficulty.lua` (`Difficulty.SCENARIOS`, `Difficulty.SCENARIO_ORDER`).

Key changes:
1. Remove column 2 (difficulty) and column 3 (director) drawing code
2. Remove custom tuning sliders
3. Remove safety net toggle
4. Remove "SELECT CREW" button — replace with "Next" (transitions to 'difficulty' phase)
5. Add "Back" button (transitions to 'menu' phase)
6. Layout: left panel ~40% width for scenario list, right panel ~55% for details, with padding

The `selected.scenario` state stays. `StartMenu.getSelected()` continues to work.

- [ ] **Step 3: Update StartMenu.startGame() → rename to StartMenu.next()**

Old `startGame()` applied all selections and transitioned to 'drafting'. Now it only stores the scenario choice and transitions to 'difficulty':

```lua
function StartMenu.next()
    -- Scenario is already stored in selected.scenario
    GameState.scenario = selected.scenario
    local DifficultySelect = require('src.ui.difficulty_select')
    DifficultySelect.init(selected.scenario)
    GameState.phase = 'difficulty'
end
```

- [ ] **Step 4: Add Back button handler**

```lua
if key == 'escape' then
    GameState.phase = 'menu'
    local MainMenu = require('src.ui.main_menu')
    MainMenu.init()
end
```

- [ ] **Step 5: Add wheelmoved for scrollable scenario list**

```lua
function StartMenu.wheelmoved(x, y)
    scrollOffset = scrollOffset - y * 30
    scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
end
```

- [ ] **Step 6: Test — New Colony → scenario screen shows only scenarios, Back returns to menu**

Run: `love .`
Click "New Colony" → should show two-panel scenario picker. Click Back → returns to main menu. Click Next → transitions to difficulty stub.

- [ ] **Step 7: Commit**

```bash
git add src/ui/start_menu.lua
git commit -m "refactor: strip start_menu to scenario-only picker with Back/Next"
```

---

## Chunk 4: Difficulty + AI Director Screen

### Task 9: Implement difficulty_select.lua

**Files:**
- Modify: `src/ui/difficulty_select.lua` (replace stub)

- [ ] **Step 1: Read difficulty data structures**

Read `src/ui/difficulty.lua` lines 13-147 for `PRESETS`, `PRESET_ORDER`, `DIRECTORS`, `DIRECTOR_ORDER`. Also read lines 232-276 for `Difficulty.configure()`.

- [ ] **Step 2: Implement DifficultySelect module**

Replace the stub with a full implementation. Layout:
- Left section (~50%): Difficulty presets as selectable rows, custom tuning sliders below
- Right section (~50%): AI Director selection as selectable rows with description
- Safety Net toggle at bottom
- Bottom bar: Back / Next

Use the same visual style as the scenario screen (dark panels, gold accent buttons, hover effects).

State:
```lua
local selected = {
    difficulty = 'normal',
    director = 'chronicler',
    safetyNet = true,
    raid = 1.0, weather = 1.0, disease = 1.0, resources = 1.0,
    baseTemp = -40,
}
```

Key functions:
- `DifficultySelect.init(scenario)` — receive scenario from previous screen, set defaults
- `DifficultySelect.draw()` — render two-section layout
- `DifficultySelect.mousepressed(x, y, button)` — hit testing for preset/director/slider/button clicks
- `DifficultySelect.mousereleased(x, y, button)` — end slider drags
- `DifficultySelect.keypressed(key)` — Escape=Back, Enter=Next
- `DifficultySelect.next()` — apply selections via `Difficulty.configure()`, transition to 'worldgen'
- `DifficultySelect.back()` — transition to 'scenario'

The custom tuning sliders reuse the existing logic from the old start_menu.lua (4 axes: raid, weather, disease, resources with preset segments).

- [ ] **Step 3: Wire DifficultySelect.next() to configure and transition**

```lua
function DifficultySelect.next()
    Difficulty.configure({
        preset = selected.difficulty,
        baseTemp = selected.baseTemp,
        creatures = selected.raid,
        weather = selected.weather,
        disease = selected.disease,
        resources = selected.resources,
        storyteller = selected.director,
        scenario = GameState.scenario,
        safetyNet = selected.safetyNet,
    })
    local CreateWorld = require('src.ui.create_world')
    CreateWorld.init()
    GameState.phase = 'worldgen'
end
```

- [ ] **Step 4: Test — full flow from menu → scenario → difficulty, Back works at each step**

Run: `love .`
Menu → New Colony → pick scenario → Next → difficulty screen with presets and directors. Click difficulty presets, verify custom tuning appears. Back returns to scenario.

- [ ] **Step 5: Commit**

```bash
git add src/ui/difficulty_select.lua
git commit -m "feat: implement difficulty + AI director selection screen"
```

---

## Chunk 5: Create World Screen

### Task 10: Implement create_world.lua

**Files:**
- Modify: `src/ui/create_world.lua` (replace stub)

- [ ] **Step 1: Read Difficulty.MAP_SIZES and FACTION_DEFS**

Read `src/ui/difficulty.lua` lines 153-155 for map sizes. Read `src/colony/factions.lua` lines 14-141 for faction definitions — note the `id`, `name`, `desc` fields.

- [ ] **Step 2: Implement seed hash function**

```lua
local function hashSeed(str)
    if str == '' then return nil end
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 999999
    end
    return hash + 1  -- avoid 0
end
```

- [ ] **Step 3: Implement CreateWorld module**

Replace the stub with full implementation. Layout:
- Left column (~45%): World parameters
  - "Seed:" label + text input field + "Randomize seed" button
  - "Map Size:" label + 3 selectable buttons (Small/Medium/Large)
- Right column (~50%): Factions
  - Title "Factions"
  - Scrollable list of faction entries (name + delete button)
  - "Add..." button at bottom
- Bottom bar: Back / Generate

State:
```lua
local seedText = ''
local seedCursorBlink = 0
local seedFocused = false
local mapSizeIdx = 1  -- index into Difficulty.MAP_SIZES
local activeFactions = {}  -- array of faction id strings
local availableFactions = {}  -- factions not yet added
local factionScrollOffset = 0
```

Key functions:
- `CreateWorld.init()` — populate activeFactions with all faction ids, reset seed
- `CreateWorld.draw()` — render two-column layout with text input, buttons, faction list
- `CreateWorld.textinput(text)` — append to seedText if focused (max 20 chars, alphanumeric only)
- `CreateWorld.keypressed(key)` — backspace to delete from seed, Escape=Back, Enter=Generate
- `CreateWorld.mousepressed(x, y, button)` — hit test: seed field focus, randomize, map size buttons, faction delete/add, Back/Generate
- `CreateWorld.wheelmoved(x, y)` — scroll faction list
- `CreateWorld.generate()` — hash seed, store in GameState, transition to 'landing'

- [ ] **Step 4: Implement Generate action**

```lua
function CreateWorld.generate()
    -- Seed
    if seedText == '' then
        seedText = tostring(love.math.random(100000, 999999))
    end
    GameState.worldSeed = seedText
    GameState.worldSeedNumeric = hashSeed(seedText)

    -- Map size
    local mapSize = Difficulty.MAP_SIZES[mapSizeIdx]
    Difficulty.setMapSize(mapSize)
    GameState.mapWidth = mapSize
    GameState.mapHeight = mapSize

    -- Factions
    GameState.selectedFactions = {}
    for i, fid in ipairs(activeFactions) do
        GameState.selectedFactions[i] = fid
    end

    -- Transition
    local LandingSite = require('src.ui.landing_site')
    LandingSite.init()
    GameState.phase = 'landing'
end
```

- [ ] **Step 5: Test — full flow through Create World, seed input works, map size selectable**

Run: `love .`
Navigate to Create World screen. Type a seed, select map size, remove/add factions. Click Generate → transitions to landing stub.

- [ ] **Step 6: Commit**

```bash
git add src/ui/create_world.lua
git commit -m "feat: implement Create World screen (seed, map size, faction selection)"
```

---

## Chunk 6: Landing Site Screen

### Task 11: Implement landing_site.lua

**Files:**
- Modify: `src/ui/landing_site.lua` (replace stub)

- [ ] **Step 1: Implement biome preview image generation**

Use `Tilemap.sampleBiome()` to generate a preview image:

```lua
local Tilemap = require('src.world.tilemap')

local BIOME_COLORS = {
    marsh        = {0.16, 0.54, 0.48},
    frozen_forest = {0.18, 0.35, 0.24},
    volcanic     = {0.54, 0.23, 0.16},
    dead_forest  = {0.35, 0.35, 0.29},
    glacier      = {0.75, 0.85, 0.91},
    default      = {0.54, 0.69, 0.78},
}

local function generatePreviewImage(seed, w, h)
    local imgData = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local biome, elev = Tilemap.sampleBiome(x, y, seed, w, h)
            local c = BIOME_COLORS[biome] or BIOME_COLORS.default
            -- Slight elevation shading
            local shade = 0.7 + elev * 0.3
            imgData:setPixel(x, y, c[1] * shade, c[2] * shade, c[3] * shade, 1)
        end
    end
    return love.graphics.newImage(imgData)
end
```

- [ ] **Step 2: Implement LandingSite module**

Replace stub with full implementation:

State:
```lua
local previewImage = nil
local mapW, mapH = 128, 128
local landingX, landingY = nil, nil
local hoverX, hoverY = nil, nil
local hoverBiome = ''
```

Key functions:
- `LandingSite.init()` — read GameState seed/map size, call `generatePreviewImage()`, center default landing on map center
- `LandingSite.draw()` — render scaled preview image centered on screen, landing marker, hover tooltip, bottom bar (Back / Select random / Next)
- `LandingSite.mousepressed(x, y, button)` — click on preview = set landing point, click buttons
- `LandingSite.keypressed(key)` — Escape=Back, Enter=Next (if site selected)
- `LandingSite.next()` — store landing in GameState, transition to 'drafting'

Layout:
- Preview image scaled to fit ~80% of screen height, centered
- Landing marker: bright circle/crosshair on selected tile
- Bottom-left panel: biome name, elevation on hover
- Bottom bar: Back / Select random site / Next

- [ ] **Step 3: Implement Next action**

```lua
function LandingSite.next()
    if not landingX then return end
    GameState.startX = landingX
    GameState.startY = landingY
    GameState.landingSiteSelected = true

    local ColonistSelect = require('src.ui.colonist_select')
    ColonistSelect.init()
    GameState.phase = 'drafting'
end
```

- [ ] **Step 4: Implement Select Random Site**

```lua
local function selectRandomSite()
    for attempt = 1, 100 do
        local rx = love.math.random(10, mapW - 10)
        local ry = love.math.random(10, mapH - 10)
        local biome = Tilemap.sampleBiome(rx, ry, GameState.worldSeedNumeric, mapW, mapH)
        if biome ~= 'volcanic' then  -- avoid lava
            landingX, landingY = rx, ry
            return
        end
    end
    -- Fallback: center
    landingX, landingY = math.floor(mapW / 2), math.floor(mapH / 2)
end
```

- [ ] **Step 5: Test — full flow through landing site, preview image renders, click to select**

Run: `love .`
Navigate through all screens to Landing Site. Verify biome preview image appears with colored zones. Click to place landing marker. Click Next → transitions to crew select.

- [ ] **Step 6: Commit**

```bash
git add src/ui/landing_site.lua
git commit -m "feat: implement landing site screen with biome preview and site selection"
```

---

## Chunk 7: Settings Panel Tabs + ColonistSelect Back-Flow Fix

### Task 12: Add tabbed categories to settings panel

**Files:**
- Modify: `src/ui/settings_panel.lua`

- [ ] **Step 1: Read current settings panel structure**

Read `src/ui/settings_panel.lua` fully (654 lines). Note how sections are drawn sequentially — Audio (lines 385-400), Display (lines 404-418), Gameplay (lines 422-435).

- [ ] **Step 2: Add tab state and tab definitions**

Add at top of module:
```lua
local activeTab = 'general'
local TABS = {
    { id = 'general',  label = 'General',  icon = nil },
    { id = 'graphics', label = 'Graphics', icon = nil },
    { id = 'audio',    label = 'Audio',    icon = nil },
    { id = 'gameplay', label = 'Gameplay', icon = nil },
    { id = 'controls', label = 'Controls', icon = nil },
    { id = 'dev',      label = 'Dev',      icon = nil },
}
```

- [ ] **Step 3: Refactor draw to render tabs + content**

Split the panel into:
- Left column (150px): tab buttons stacked vertically, active tab highlighted
- Right area: only render settings for the active tab

Each tab's content is a function:
```lua
local function drawGeneralTab(x, y, w, h) ... end
local function drawGraphicsTab(x, y, w, h) ... end
local function drawAudioTab(x, y, w, h) ... end
local function drawGameplayTab(x, y, w, h) ... end
local function drawControlsTab(x, y, w, h) ... end
local function drawDevTab(x, y, w, h) ... end
```

Move existing drawing code into the appropriate tab functions.

- [ ] **Step 4: Add tab click handling in mousepressed**

In the left column area, check which tab was clicked and set `activeTab`.

- [ ] **Step 5: Add General tab content**

General tab shows: save folder path (display only), version info.

- [ ] **Step 6: Add Controls tab content**

Controls tab shows: edge scroll toggle, zoom sensitivity slider, drag sensitivity slider. These may be display-only placeholders initially if the settings don't exist yet.

- [ ] **Step 7: Add Dev tab content**

Dev tab shows: debug overlay toggle (`GameState.showDebug`), verbose logging toggle.

- [ ] **Step 8: Ensure settings panel can open from main menu**

The settings panel's `open()` function should work regardless of phase. Verify the draw/input routing handles settings overlay in the 'menu' phase.

- [ ] **Step 9: Test — open Options from main menu, switch tabs, all settings render correctly**

Run: `love .`
Main Menu → Options → tab panel appears with 6 tabs. Click each tab — content changes. Audio sliders still work. Close returns to main menu.

- [ ] **Step 10: Commit**

```bash
git add src/ui/settings_panel.lua
git commit -m "refactor: add tabbed categories to settings panel (General/Graphics/Audio/Gameplay/Controls/Dev)"
```

---

### Task 13: Fix ColonistSelect back-flow for new phase structure

**Files:**
- Modify: `src/ui/colonist_select.lua`

- [ ] **Step 1: Read ColonistSelect back/deploy flow**

Read `src/ui/colonist_select.lua` lines 566-645. Find where Back sets `GameState.phase = 'setup'` and where Deploy sets `GameState.phase = 'starting'`.

- [ ] **Step 2: Update Back to return to 'landing' phase**

Change:
```lua
GameState.phase = 'setup'
```
to:
```lua
GameState.phase = 'landing'
local LandingSite = require('src.ui.landing_site')
LandingSite.init()
```

- [ ] **Step 3: Test — Back from crew select returns to landing site**

Run: `love .`
Navigate to crew select, click Back → should return to landing site with preview intact.

- [ ] **Step 4: Commit**

```bash
git add src/ui/colonist_select.lua
git commit -m "fix: ColonistSelect Back returns to landing site instead of old setup"
```

---

## Chunk 8: Input Model — Draft-Gated Right-Click

### Task 14: Gate right-click movement behind draft state

**Files:**
- Modify: `src/ui/input.lua`

- [ ] **Step 1: Read _handleRightClick fully**

Read `src/ui/input.lua` lines 408-563. Understand the flow:
1. Get tile coords (line 410)
2. Find acting colonist (lines 414-425)
3. Drafted attack-move on creature (lines 428-443)
4. Context menu checks: colonist, corpse, creature, building, item, tile (lines 445-522)
5. **Fallback: move selected colonists** (lines 524-562)

- [ ] **Step 2: Guard the movement fallback with draft check**

The movement code at lines 524-562 is the "else" branch — when no entity was found for context menu. Wrap it in a draft check:

Find the code block that starts with something like:
```lua
-- Move selected colonists to tile
```

Wrap the entire movement section:
```lua
-- Only allow direct movement for drafted colonists
local canMove = false
if actingColonistId then
    local col = ECS.get(actingColonistId, 'colonist')
    if col and col.drafted then
        canMove = true
    end
end

if canMove then
    -- existing movement code (pathfinding and assignment)
else
    -- Open context menu for ground tile (actingColonistId may be nil — that's OK)
    if actingColonistId then
        Context.open(x, y, nil, 'tile', actingColonistId, tx, ty, GameState.viewDepth)
    end
    -- If no colonist selected and clicking empty ground, do nothing (camera pan handled by drag)
end
```

**NOTE:** The variable in `input.lua` is `actingColonistId` (an entity ID number), NOT `actingColonist`. Read the actual variable name from the code before implementing.

- [ ] **Step 3: Verify drafted attack-move still works**

The existing drafted attack-move code (lines 428-443) runs BEFORE the movement fallback, so it should still work. Verify by reading the flow — if a drafted colonist right-clicks on a creature, `Hunting.designate()` is called before reaching the movement section.

- [ ] **Step 4: Test — undrafted colonist right-click shows context menu, drafted colonist right-click moves**

Run: `love .`
Start a new game. Select an undrafted colonist. Right-click on empty ground → should show context menu (not move). Press R to draft the colonist. Right-click on empty ground → should move the colonist.

- [ ] **Step 5: Commit**

```bash
git add src/ui/input.lua
git commit -m "feat: gate right-click movement behind draft state, undrafted gets context menu"
```

---

## Chunk 9: Integration Testing and Polish

### Task 15: Full flow integration test

**Files:** None (manual testing)

- [ ] **Step 1: Test complete new game flow**

Run: `love .`
1. Main Menu appears with title, gradient, buttons
2. Click "New Colony" → Scenario screen
3. Select scenario → Next → Difficulty screen
4. Select difficulty + director → Next → Create World screen
5. Enter seed, pick map size, manage factions → Generate → Landing Site
6. Click to select landing site → Next → Crew Select
7. Pick crew → Deploy → Game starts at selected landing coordinates

Verify each Back button returns to the correct previous screen.

- [ ] **Step 2: Test Continue button**

If a save exists, verify Continue loads the most recent save directly.

- [ ] **Step 3: Test Load Game**

Verify Load Game opens save browser overlay on the main menu.

- [ ] **Step 4: Test Options from main menu**

Verify Options opens tabbed settings panel, all tabs work, close returns to menu.

- [ ] **Step 5: Test draft-gated input**

In a running game:
- Undrafted colonist: right-click ground → context menu (no movement)
- Draft colonist (R): right-click ground → moves to tile
- Draft colonist: right-click on enemy → attack-move
- Undraft colonist (R): right-click on colonist → context menu (treat, draft, etc.)

- [ ] **Step 6: Test seed reproducibility**

Start two new games with the same seed and map size. Verify the landing site biome preview is identical for both.

- [ ] **Step 7: Test edge cases**

- Empty seed → auto-randomized on Generate
- Delete all factions to minimum (2) → delete button disabled
- Landing on volcanic tile → allowed (player's choice)
- Very large map (512) → preview still renders (may take a moment)
- ESC from main menu → quit
- ESC from any pre-game screen → Back

- [ ] **Step 8: Fix any issues found**

Address bugs, layout problems, or flow breaks discovered during testing.

- [ ] **Step 9: Final commit**

```bash
git add -A
git commit -m "fix: integration polish for main menu overhaul"
```
