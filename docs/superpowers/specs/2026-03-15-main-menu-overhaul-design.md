# Main Menu Overhaul + Landing Site + Input Model

**Date:** 2026-03-15
**Status:** Approved

## Summary

Restructure Frosthold's pre-game flow from a single combined setup screen into sequential RimWorld-style screens. Add a proper main menu with background art, surface existing but hidden world generation features (seeds, map sizes, biomes, factions), add landing site selection, and split right-click input behavior by colonist draft state.

## New Game Flow

```
MAIN MENU → SCENARIO → DIFFICULTY + AI DIRECTOR → CREATE WORLD → LANDING SITE → CREW SELECT → PLAY
```

Six interactive screens plus two transient phases. Each screen handles one decision. Back/Next navigation between them.

### Game Phases

New phase progression in `GameState.phase`:

```
'menu' → 'scenario' → 'difficulty' → 'worldgen' → 'landing' → 'drafting' → 'starting' → 'playing'
```

- `'starting'` is a transient phase — `main.lua` calls `initGameWorld()` immediately, then sets `'playing'`. No draw or input handling.
- Replaces current `'setup' → 'drafting' → 'starting' → 'playing'`.

### main.lua Event Routing

The following `love` callbacks currently short-circuit for non-`'playing'` phases and must be extended to route events to pre-game screens:
- `love.textinput` — needed for seed text input on the Create World screen
- `love.wheelmoved` — needed for scrollable lists (scenarios, factions)
- `love.mousemoved` / `love.mousereleased` — needed for slider drags in settings/difficulty
- All pre-game screens receive `keypressed`, `mousepressed` via phase-gated `if` branches (same pattern as existing `'setup'` / `'drafting'` routing)

## Screen Specifications

### Screen 1: Main Menu

**File:** `src/ui/main_menu.lua` (NEW)

**Layout:**
- Full-screen background image (`assets/menu_bg.png`)
- Falls back to a dark gradient if image not found
- "FROSTHOLD" title, large font, positioned upper-right
- Subtitle: "A colony survival sim"
- Vertical button stack, right-aligned (matching RimWorld placement):
  - **Continue** — only shown if an autosave exists
  - **New Colony** — enters scenario screen
  - **Load Game** — opens save browser
  - **Options** — opens settings panel
  - **Credits** — shows credits
  - **Quit** — exits to OS
- Version string bottom-left corner
- Buttons use existing UI color palette (warm gold on dark background)

**Font Sizes (at 1280x720 base):**
- Title: 48px+
- Subtitle: 18px
- Buttons: 20px, minimum 200px wide, 40px tall
- All text must be readable at 960x540 minimum resolution

**Behavior:**
- `main_menu.init()` — load background image, set up fonts
- `main_menu.draw()` — render background, title, buttons
- `main_menu.mousepressed(x, y, button)` — button hit testing
- `main_menu.keypressed(key)` — keyboard nav (up/down/enter)

**Load Game:** Opens existing save browser (`SaveMenu`) as an overlay on the main menu. Not a separate phase — the main menu stays in `'menu'` phase and draws the save list on top. This matches existing behavior where save browser is an overlay.

**Credits:** Simple scrolling text screen. Reads credits from a hardcoded string or `assets/credits.txt` if present. Any key or click returns to main menu. Not a separate phase — rendered as overlay on main menu.

**Continue:** Loads the most recent autosave directly (calls `Save.load()` with latest save file). Only shown when `Save.listSaves()` returns at least one entry.

### Screen 2: Choose Scenario

**File:** `src/ui/start_menu.lua` (MODIFY — strip to scenario-only)

**Layout:**
- Two-panel layout over semi-transparent dark background (game art visible behind)
- Left panel: scrollable list of 6 scenarios
  - Each entry: scenario name (bold) + 1-line description + colonist count
  - Selected entry highlighted
- Right panel: full description of selected scenario
  - Scenario name (large)
  - Flavor text paragraph
  - "Start with:" section listing colonist count and starting resources
- Bottom bar: Back / Next buttons

**Existing Scenarios (from difficulty.lua):**
1. Drop Pod Malfunction (3 colonists)
2. Sole Survivor (1 colonist)
3. Prior Expedition (5 colonists)
4. Executive Observer (1 colonist)
5. Abandoned (1 colonist)
6. Hot Drop (4 colonists, wounded)

### Screen 3: Difficulty + AI Director

**File:** `src/ui/difficulty_select.lua` (NEW — separated from start_menu.lua for single-responsibility)

**Layout:**
- Two sections, side by side or stacked
- Left/top: Difficulty selection
  - 5 presets as selectable cards with name + description
  - Custom tuning section below: 4 sliders (raid pressure, weather, disease, resources)
  - Switching presets resets sliders; modifying sliders switches to "Custom"
  - Safety Net toggle (Mammona rescue on wipe)
- Right/bottom: AI Director selection
  - 5 HERMES variants as selectable cards with personality description
  - Selected director highlighted with full description
- Bottom bar: Back / Next

### Screen 4: Create World

**File:** `src/ui/create_world.lua` (NEW)

**Layout (modeled after RimWorld's "Create world" screen):**
- Left column: World parameters
  - **Seed:** text input field (editable) + "Randomize seed" button
    - Alphanumeric input, max 20 characters. String hashed to numeric seed via simple hash function (sum of byte values * position, modulo large prime) for `love.math.noise` compatibility.
    - Empty field on Generate → auto-randomize before proceeding.
    - Stored in `GameState.worldSeed` (string) and `GameState.worldSeedNumeric` (number).
  - **Map Size:** 3 selectable buttons
    - Small (128) / Medium (256) / Large (512)
    - Surfaces existing `Difficulty.MAP_SIZES`
    - Default: Small (128)
- Right column: Factions
  - Scrollable list of starting factions from `FACTION_DEFS` in `factions.lua`
  - Each entry: faction icon/color + name + delete button
  - "Add..." button at bottom to pick from remaining available factions
  - Minimum 2 factions required (delete button disabled at minimum)
  - Player's own faction (`mammona_mining`) is always included and non-removable
  - Selected faction list stored in `GameState.selectedFactions` (table of faction keys)
  - `Factions.init()` modified to accept an optional whitelist parameter — only initializes diplomacy for whitelisted factions. Non-selected factions do not spawn, trade, or raid.
- Bottom bar: Back / Generate

**"Generate" action:**
1. Store seed string in `GameState.worldSeed`, compute numeric hash into `GameState.worldSeedNumeric`
2. Apply map size via `Difficulty.setMapSize()`
3. Store faction selections in `GameState.selectedFactions`
4. **Do NOT call `World.init()` here** — full world generation happens later in the `'starting'` phase inside `initGameWorld()`. The landing site screen uses lightweight noise preview only.
5. Transition to `'landing'` phase

### Screen 5: Landing Site

**File:** `src/ui/landing_site.lua` (NEW)

**Layout:**
- Main area: zoomed-out overview of the generated tilemap
  - Mini-map style rendering — each game tile = 1-2 pixels
  - Biome regions color-coded:
    - marsh: teal (#2a8a7a)
    - frozen_forest: dark green (#2d5a3d)
    - volcanic: warm red (#8a3a2a)
    - dead_forest: gray (#5a5a4a)
    - glacier: bright white-blue (#c0d8e8)
    - default: blue-white (#8ab0c8)
  - Landing marker shown where player clicks
  - Camera centered on marker position

- Bottom-left info panel (on hover):
  - Biome name
  - Elevation (from noise)
  - Nearby features (lava vents, rivers, ore density)

- Bottom bar: Back / Select random site / Next

**Behavior:**
- Click on map: place landing marker, update `GameState.startX/startY`
- "Select random site": pick a random valid (non-lava, non-deep-water) tile
- Must select a site before Next is enabled

**Biome Preview Rendering (lightweight, no full world gen):**
- New function: `Tilemap.sampleBiome(x, y, seed, mapWidth, mapHeight)` — runs the 3 noise functions (elevation, moisture, biome) from `tilemap.lua` lines 118-120 and returns the biome name for that coordinate. No tile creation, no entity spawning.
- Landing site screen creates a `love.image.newImageData(mapWidth, mapHeight)` and fills each pixel by calling `sampleBiome()` with the biome color palette.
- Converted to a `love.graphics.newImage()` for display. Generated once on screen entry, not per-frame.
- This avoids the chicken-and-egg problem: `World.init()` and all dependent systems (ECS, Thermal, Power, etc.) are only called during the `'starting'` phase inside `initGameWorld()`.

**Landing coord persistence:**
- `Difficulty.apply()` currently overwrites `GameState.startX/startY` with map center. Modify `Difficulty.apply()` to skip overwriting these fields if `GameState.landingSiteSelected == true` (new flag set by landing site screen).

### Screen 6: Crew Select

**File:** `src/ui/colonist_select.lua` (NO CHANGES)

Existing crew selection screen works as-is. Receives scenario colonist count from previous selections.

### Screen 7: Play

Existing flow — `initGameWorld()` called, transitions to `'playing'` phase.

## Options Panel Restructure

**File:** `src/ui/settings_panel.lua` (MODIFY)

Add tabbed category navigation on the left side, settings content on the right. Matches RimWorld's options layout.

**Tabs:**
1. **General** — Autosave interval (future), save folder info
2. **Graphics** — Resolution (8 presets), fullscreen toggle, v-sync toggle
3. **Audio** — Master, ambient, UI, creature, weather, work volume sliders (existing)
4. **Gameplay** — Auto-pause triggers, fog of war, colorblind mode (existing)
5. **Controls** — Edge scroll toggle, zoom sensitivity, drag sensitivity
6. **Dev** — Debug overlay toggle (F4), verbose logging

**Visual:**
- Tab buttons: left column, ~150px wide, full height
- Active tab highlighted with accent color
- Content area: right side, scrollable if needed
- Close button (X) top-right or OK button bottom-center
- Semi-transparent dark background panel

**Navigation:**
- Default active tab: General (first tab)
- Panel does not remember last-viewed tab between opens
- Keyboard: up/down to switch tabs, Escape to close
- Dev tab always visible (not gated behind debug flag — it's how you enable debug)

## Input Model Changes

**File:** `src/ui/input.lua` (MODIFY)

### Right-Click Behavior by Draft State

**Undrafted colonist selected (or no colonist selected):**
- Right-click on any target → open context menu
- Right-click on ground → open context menu (tile info, available actions)
- Right-drag → camera pan
- No direct movement commands

**Drafted colonist selected:**
- Right-click on walkable ground → move colonist to tile
- Right-click on enemy creature → attack-move
- Right-click on friendly/building/item → open context menu
- Right-drag → camera pan

### Implementation

In `Input._handleRightClick(x, y)`:

```lua
-- After drag detection resolves to "short click":
local selectedCol = getSelectedColonist()
if selectedCol and selectedCol.drafted then
    local targetEntity = findEntityAt(wx, wy)
    if targetEntity and isHostile(targetEntity) then
        -- Attack-move command
        issueAttackCommand(selectedCol, targetEntity)
    elseif targetEntity and (isFriendly(targetEntity) or isBuilding(targetEntity) or isItem(targetEntity)) then
        -- Context menu for non-hostile entities
        Context.open(sx, sy, targetId, targetType, colonistId, tileX, tileY, depth)
    else
        -- Move to ground tile
        issueMoveCommand(selectedCol, tileX, tileY)
    end
else
    -- Not drafted or no colonist: always context menu
    Context.open(sx, sy, targetId, targetType, colonistId, tileX, tileY, depth)
end
```

The existing `Input._handleRightClick` already has the drag-vs-click threshold detection. The change is gating the move/attack path behind `col.drafted`.

## Files Summary

| File | Action | Description |
|------|--------|-------------|
| `src/ui/main_menu.lua` | NEW | Title screen with background art + button stack |
| `src/ui/create_world.lua` | NEW | Seed input, map size, faction selection |
| `src/ui/landing_site.lua` | NEW | Biome mini-map with landing point selection |
| `src/ui/start_menu.lua` | MODIFY | Strip to scenario-only picker (remove difficulty/director columns) |
| `src/ui/settings_panel.lua` | MODIFY | Add tabbed category layout |
| `src/ui/difficulty.lua` | MODIFY | Extract data; UI moves to difficulty_select or start_menu phase |
| `src/ui/input.lua` | MODIFY | Gate right-click move/attack behind col.drafted |
| `src/ui/ui_context.lua` | MODIFY | Add ground/tile context options for undrafted right-click |
| `main.lua` | MODIFY | New phase state machine, route to new screens |
| `src/game_state.lua` | MODIFY | New phase values, seed field, landing coords |
| `src/ui/difficulty_select.lua` | NEW | Difficulty presets + AI Director selection screen |
| `src/world/tilemap.lua` | MODIFY | Accept seed parameter in init, expose `sampleBiome()` function |
| `src/colony/factions.lua` | MODIFY | `Factions.init()` accepts optional faction whitelist |
| `assets/menu_bg.png` | NEW | Placeholder gradient until real art exists |

## Tilemap Seed Injection

`Tilemap.init(w, h)` must be modified to accept an optional third parameter:

```lua
function Tilemap.init(w, h, seed)
    mapSeed = seed or love.math.random(1, 999999)
    -- rest of init unchanged
end
```

When called from `initGameWorld()`, pass `GameState.worldSeedNumeric`:
```lua
World.init(GameState.mapWidth, GameState.mapHeight, GameState.worldSeedNumeric)
```

If `GameState.worldSeedNumeric` is nil (e.g. loading a save), the existing random behavior is preserved.

## Keyboard Navigation

All pre-game screens support:
- **Escape** — Back (return to previous screen)
- **Enter** — Next / confirm (when a valid selection exists)
- **Up/Down** — Navigate lists (scenarios, difficulties, factions)

## Dependencies

- Existing `difficulty.lua` scenario/difficulty/director definitions stay as data — just displayed differently
- Existing `tilemap.lua` biome generation noise — reused for landing site preview via `sampleBiome()`
- Existing `colonist_select.lua` — no changes needed
- Existing `factions.lua` — faction list read for Create World screen, `init()` modified for whitelist

## Out of Scope

- World map globe view (RimWorld's 3D planet) — too complex, use flat mini-map instead
- Mod support screen
- Tutorial system
- Key rebinding UI (placeholder "Modify" button for future)
- Multiplayer lobby (exists in archive but not wired)
