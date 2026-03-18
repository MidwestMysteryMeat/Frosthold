# FROSTHOLD — Project Instructions

## Project
- **Engine:** Love2D 11.4, Lua 5.1/LuaJIT
- **Genre:** Frostpunk x RimWorld colony survival sim
- **Identity:** `frosthold` (Love2D save dir)
- **Window:** 1280x720, resizable (min 960x540)
- **Tick rate:** 20Hz fixed timestep, rendering decoupled

## Architecture
- **ECS-driven:** Sparse-set ECS engine at `src/ecs/ecs.lua` is the spine of everything
- **63+ Lua source files** across 10 completed development phases
- **Entry point:** `main.lua` — game loop, system wiring
- **Global state:** `src/game_state.lua` singleton
- **Save/load:** `src/persistence/save.lua` — serializes ECS + tilemap + state

## Code Rules (Strictly Enforced)

### ECS Contract
- Components are data. Systems are logic. Entities are IDs.
- No behavior in component tables. No entity references that survive deferred destroy.
- New components MUST be added to `KNOWN_COMPONENTS` in `save.lua`.
- New ECS systems MUST be re-registered in `Save.load()` after `ECS.init()` clears systems.

### Module Design
- Files stay under 2000 lines. Split by domain, not convenience.
- `src/` subdirectories are system boundaries — respect them.
- Cross-system requires use `pcall`. Fail gracefully when dependencies aren't loaded.
- No circular dependencies. No implicit load order.

### Naming
- Modules have domain names. Functions describe their action. Variables describe their contents.
- No `handler`, `doThing`, `process` — be specific.

### Safety
- Read before writing. Trace callers, return values, and touched ECS components.
- Keep blast radius small — fix the bug, don't restructure adjacent systems.
- Read every error path: `if not entity then`, pcall failures, edge cases where colonists die mid-task.
- No debug prints in update loops or hot paths.
- No globals except established ones (ECS singleton, game_state).

### Persistence
- Any code path that mutates game state MUST survive save/load.
- New components go in `KNOWN_COMPONENTS`. New systems get registered in save.lua's load path.
- A system that works but doesn't persist is broken.

### Cleanup
- Remove dead code — stale modules, unused functions, commented-out blocks.
- No `-- TODO` as a substitute for doing the work.
- Don't introduce new patterns when existing ones work. Follow codebase conventions.

## Key Architecture Details

### Thermal System
- Generator: Frostpunk-style reactor + steam hubs, 4 power levels, overdrive with meltdown risk
- Insulated tiles: WALL_INSULATED(16), FLOOR_INSULATED(17), DOOR_SEALED(18)
- Rooms: 6 temp comfort tiers, 8 room types, impressiveness formula
- Colonists: 5 hypothermia stages

### Raid System
- Heat signature = reactor output + colonist count + thermal cores -> scales raid budget
- Swarm raids (day 30+): 3x budget, all 4 directions, no retreat
- Retreat at 50% casualties (except swarms)

### Disease System
- Immunity race: severity vs immunity to 100
- ECS-driven (registerSystems, no step())

### Colony Growth
- Prisoner capture (15% from raids), refugee events, cloning vat, radio beacon

## Task Board
- **Read `TASKS.md` at session start and before substantial repo work.**
- `TASKS.md` is the shared coordination file for Claude Code and Codex.
- Before starting a tracked task, claim it in `TASKS.md` by setting `IN_PROGRESS` and naming the agent.
- When finished, move the row to `RECENTLY COMPLETED` with the date and agent attribution.
- If blocked, set `BLOCKED` and explain the blocker in `Notes`.
- Do not delete task rows. Update or move them.

## Known Pending Work
- `ui.lua` at ~2937 lines, `building.lua` at ~2228 lines, `save.lua` at ~1160 lines: all over the 1000-line limit. Need splitting.
- Debug overlay toggled with F4 (GameState.showDebug).
