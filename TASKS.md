# FROSTHOLD - Shared Task Board

> **Purpose:** Shared state between Claude Code, Codex, and Jonah.
> Both agents read this file at session start and before substantial repo work.
> Claim tasks before working, then update status again when the work is finished or blocked.
> Format is strict - agents parse the tables, so do not break the structure.

**Last updated:** 2026-03-20 by Claude Code (Task 1 complete — MRP campaign persistence layer)

---
## STATUS KEY
- `TODO` - Not started
- `IN_PROGRESS` - Someone is working on it (note who in Agent column)
- `DONE` - Complete, tested or verified
- `BLOCKED` - Waiting on something (note what in Notes column)

---
## ACTIVE TASKS

| # | Task | Status | Agent | Priority | Notes |
|---|------|--------|-------|----------|-------|

---
## RECENTLY COMPLETED

| # | Task | Completed | Agent | Notes |
|---|------|-----------|-------|-------|
| Task 1 | MRP Campaign Persistence Layer | 2026-03-20 | Claude Code | src/sim/mrp.lua + tests/test_mrp.lua. 54/54 tests pass. No regressions in full suite. |
| C63 | Migrate all addResource/spendResource callers to physical Items/StorageNetwork | 2026-03-15 | Claude Code | 25+ files migrated. addResource shim removed from game_state.lua (counter-only fallback remains). |
| C62 | MM Tasks 21-25: Main menu, scenario picker, difficulty, create world, landing rewire | 2026-03-15 | Claude Code | main_menu.lua (264 lines), start_menu.lua refactored to scenario-only, difficulty_select.lua (750 lines), create_world.lua (953 lines). Landing site rewired to existing hex world_map.lua. ColonistSelect back goes to world_map. |
| C61 | SP2 Task 3 + SP2 Tasks 4-7: Storage network + zone/build/wealth integration | 2026-03-15 | Claude Code | storage_network.lua (107 lines). Haul priority: storage buildings first. Build recipes query storage network. Wealth includes storage contents. Zones.getAllStoredItems() added. |
| C60 | SP1 Tasks 5-6 + 7-8 + 9-10 + 11: Mining/conveyors/carry/processing | 2026-03-15 | Claude Code | Mining spawns physical items at colonist feet. Conveyors carry full item data. Weight-based carry (base 50). 8 processing recipes. |
| C59 | SP1 Tasks 1-4: Item defs + items overhaul + GameState shim | 2026-03-15 | Claude Code | item_defs.lua (177 lines, 100+ items). items.lua decay removed, weight/durability added. addResource shim spawns physical items. |
| C58 | Physical Items design + Main Menu design specs | 2026-03-15 | Claude Code | Specs at docs/superpowers/specs/. Physical items: 4 sub-projects. Main menu: 7 screens + input model. |
| C57 | MM Tasks 12-14: Settings tabs, back-flow fix, input draft gate | 2026-03-15 | Claude Code | settings_panel.lua: 6-tab layout (General/Graphics/Audio/Gameplay/Controls/Dev), left tab column with gold active bar, per-tab row builders, scissor-clipped content, Settings.open() resets to General tab. input.lua: _handleRightClick movement gated behind col.drafted check; undrafted+selected opens tile context menu instead. Task 13 was already done. |
| C56 | MM Tasks 1-6: Foundation — GameState, tilemap, difficulty, factions, phase machine | 2026-03-15 | Claude Code | GameState: worldSeed/worldSeedNumeric/selectedFactions/landingSiteSelected fields + init resets. Tilemap.init(w,h,seed) + Tilemap.sampleBiome(). Difficulty.apply() guards startX/Y with landingSiteSelected. World.init gets worldSeedNumeric. Factions.init(whitelist) + getAll skips non-initialized factions. 4 stub screens (main_menu/difficulty_select/create_world/landing_site). main.lua: new phase routing for menu/scenario/difficulty/worldgen/landing in all handlers; boot starts in 'menu'. |
| C55 | SP4: Environmental item decay system | 2026-03-15 | Claude Code | Created src/world/item_decay.lua (30-second timer, 5 damage sources: extreme cold/heat/weather/fire/radiation, category vulnerability tables). Wired into main.lua (require + UpdateDeps + Profiler call after Items). Registered in save.lua load path. Deprecation comment added to spoilage.lua. All integration assertions pass. |
| C54 | SP3 Tasks 5-6: Equip panel + integration | 2026-03-15 | Claude Code | equip_panel.lua expanded to 7 slots (weapon/under/outer/head/hands/feet/accessory). slotH reduced to 55. Protection summary banner above slots shows Cold/Heat/Rad/Press/Tox. Clothing slots render name+durability% with red/yellow color at <25%/<50%. Clothing slots use Clothing.unequip()/equip() via pcall; equipment slots use Equipment functions unchanged. Item picker routes to ClothingDefs.getBySlot for clothing slots, Equipment.WEAPONS/ACCESSORIES for equipment slots. save.lua: Clothing.registerSystems() added after Suits block. main.lua untouched (clothing.lua self-registers at require time). Both files pass luajit syntax check. |
| C53 | SP3 Tasks 3-4: Wire clothing to colonist + new health stages | 2026-03-15 | Claude Code | _attachCombatComponents now calls ClothingMod.attach(id). Equipment.getArmorReduction delegates to Clothing.getProtection first, falls back to equip.armor. needsDecaySystem: clothing protection fetched via pcall, totalColdResist = trait resist + coldProt/100, capped at 95%. Added HEATSTROKE/RADIATION_SICKNESS/TOXIC_EXPOSURE stage tables + tier lookups; new needs fields heatExposure/radiation/toxicity added to all 3 spawn paths with backwards-compat guards. Heatstroke/rad/toxic health drain wired into needs decay. suits.lua annotated about coexistence. Colonist 8/8 + Equipment 8/8 pass. |
| C52 | SP3 Tasks 1-2: Clothing defs + component | 2026-03-15 | Claude Code | Created clothing_defs.lua (25 items across 5 slots + space suit multiSlot). Created clothing.lua (attach/equip/unequip/getProtection/degradeWear/degradeCombat/repair/registerSystems). Added 'clothing' to KNOWN_COMPONENTS in save_helpers.lua. ECS system 'clothing_degrade' registered at priority 12. |
| C51 | SP2 Tasks 4-7: Zone integration + build recipes + wealth + testing | 2026-03-15 | Claude Code | Items.step() tries SNet.findNearestDest before zone fallback; creates haul task with storageEntityId+storageSlotIdx. executeHaul delivers to storage building slot (storageEntityId branch) before zone branch. Added Zones.getAllStoredItems(). Jobs.designateBuild() queries SNet as fallback when GameState resources insufficient. getColonyWealth() sums storage building contents via stor.contents[]. All 5 files pass luajit syntax check. |
| C50 | SP2 Tasks 1-2: Storage building defs + component | 2026-03-15 | Claude Code | Created storage_defs.lua (7 types) + storage.lua (place/storeInSlot/findSlot/withdraw/getTotal/acceptsItem/spawnContentsOnGround). Added 7 entries to building_defs_misc.lua. Added storage branch to building_placement.lua. Added 'storage' to KNOWN_COMPONENTS. Hooked spawnContentsOnGround before ECS destroy in Building.remove. |
| C49 | Physical Items Tasks 12-14: colony wealth + KNOWN_COMPONENTS verify + save v2 compat | 2026-03-15 | Claude Code | getColonyWealth now sums ECS item entities + zone-stored items; removed legacy resources counter loop (double-count prevention); save version bumped to 2; v1→v2 migration spawns physical items from old resource counters. |
| C48 | Physical Items Task 11: processing recipes + centrifuge + refiner machines | 2026-03-15 | Claude Code | Added 8 physical-item processing chains to production_defs.lua (smelt_iron, smelt_lead_ingot, smelt_copper, forge_steel_ingot, enrich_uranium, saw_planks, cut_stone_chunk, refine_ice). Added centrifuge and refiner to MACHINES and building_defs_industry.lua. Added 13 new item entries to ITEMS table (iron_ore, copper_ore, uranium_ore, stone_chunk, logs, ice_block, iron_ingot, lead_ingot, copper_ingot, enriched_uranium, depleted_uranium, planks, fuel). Updated ITEM_TO_RES and OUTPUT_TO_RES in both production_defs.lua and production_runtime.lua. All 12 production tests pass. |
| C47 | Physical Items Tasks 9-10: weight-based carry capacity + haul weight tracking | 2026-03-15 | Claude Code | inventory.capacity replaced with maxWeight (50 base units, trait-scaled) and currentWeight. executeHaul adds weight on pickup via ItemDefs.getWeight, clears on delivery. movementSystem applies up to 30% speed penalty at max load (inventory added to colonist_move filter). Colonist.kill drops hauled items at death position. Test and helpers.lua updated to match new schema. All 8 colonist tests pass. |
| C46 | Physical Items Tasks 7-8: conveyor belt item format + inserter update | 2026-03-15 | Claude Code | Belt items extended with quality/material/durability/amount. insertItem takes optional itemData, extractItem returns full table. Belt-to-belt transfer, removal drops, and end-of-line drops all preserve extended fields. getState/loadState persist all fields. Inserters carry full item tables; normaliseItem() handles legacy string heldItem. Fixed arg-order bug in Inserters.destroy. |
| C45 | Planet selection system (Phase A-C) | 2026-03-15 | Claude Code | Foundation data layer + planet select UI + system hooks. 4 new files (`planet_defs.lua`, `planet.lua`, `planet_scenarios.lua`, `planet_select.lua`), 12 modified files. Erebus plays identically (all fields nil). |
| C44 | Soak runner + manual QA checklist | 2026-03-14 | Codex | Added soak summary/suite helpers to the benchmark harness, shipped `tools/run_soak_report.lua` with pass/warn budgets and hotspot reporting, added `QA_PLAYTEST_CHECKLIST.md`, and expanded benchmark coverage while keeping the full suite green. |
| C43 | End-to-end playthrough smoke validation | 2026-03-14 | Codex | Added headless coverage for setup -> drafting -> starting -> playing, one-time rescue then defeat, and all four wired victory routes; extended Love mocks for headless startup; and fixed a stale colonist carry-capacity test expectation. |
| C42 | Weather + hazard balance pass | 2026-03-14 | Codex | Tuned harsh-weather transition bias to avoid storm saturation, made surface napalm/bio/fallout hazards decay faster under precipitation and wind, added `tools/run_weather_probes.lua`, expanded weather/ordnance regression coverage, and stabilized test RNG resets. |
| C41 | Benchmark-driven balance pass | 2026-03-14 | Codex | Used the new harness to tune raid defaults, replaced uniform eligible-raid fallback with trigger-aware weighted selection, raised containment reclamation pressure in late containment states, added `tools/run_benchmarks.lua`, and kept the full suite green. |
| C40 | Centralized tuning + benchmark harness | 2026-03-14 | Codex | Added `src/sim/tuning.lua`, wired elastic/weather/quotas/raids/ordnance pacing constants through it, shipped deterministic benchmark + soak helpers in `src/util/benchmark.lua`, and added regression coverage while keeping the full suite green. |
| C39 | Optimization / polish implementation block | 2026-03-14 | Codex | Expanded profiler history/categories/budgets and debug surfacing, reduced HUD/render/main-loop module churn, fixed research scroll + HUD overflow issues, added lightweight world VFX for combat/containment, and repaired raid retreat casualty accounting with regression coverage. |
| C1 | Feature audit + checklist PDF | 2026-03-13 | Claude Code | 494 items, 27 pages. `FROSTHOLD_Feature_Checklist.md` and `.pdf`. |
| C2 | Phase 11+ roadmap (36 features) | 2026-03-12 | Claude Code | All complete. See `ROADMAP.md`. |
| C3 | Depth system + structural integrity | 2026-03-12 | Claude Code | Multi-layer underground support, shafts, and cave-ins. |
| C4 | Sprite art generation | 2026-03-12 | Claude Code | 379 PNGs and lazy-loaded sprite support. |
| C5 | Lore rework + faction/creature rename | 2026-03-11 | Claude Code | `LORE_BIBLE.md`, `adlib.lua` rewrite, and full codebase rename. |
| C6 | Quest system | 2026-03-11 | Claude Code | `quest.lua`, `quest_objectives.lua`, and `quest_panel.lua`. |
| C7 | Vision cones + LOS + AI Director | 2026-03-11 | Claude Code | `line_of_sight.lua` and `director.lua`. |
| C8 | Humanoid raiders | 2026-03-11 | Claude Code | `raiders.lua`, 15 species, 5 factions. |
| C9 | Build menu UI | 2026-03-11 | Claude Code | `build_menu.lua`, 9 categories, auto-categorized. |
| C10 | Major bug sweep (~50 bugs) | 2026-03-10 | Claude Code | Fixed crashes, save/load gaps, and logic bugs. |
| C11 | Content pass (descs for all buildings/creatures/diseases) | 2026-03-11 | Claude Code | 128 buildings, 35 creatures, and 5 diseases. |
| C12 | Memory system restructure | 2026-03-13 | Claude Code | Slim `MEMORY.md` index, topic files, and shared `TASKS.md`. |
| C13 | Task board audit + cleanup | 2026-03-13 | Claude Code | Removed 5 stale/invalid tasks, verified backlog against codebase. |
| C14 | Full codebase audit (bugs, bloat, lore) | 2026-03-13 | Codex | Reviewed runtime bugs, duplication, dead weight, implementation gaps, and lore consistency. |
| C15 | Audit fixes (temp/save/beds/policies/ECS) | 2026-03-13 | Codex | Fixed temperature ownership/save restore, preserved bed assignments across load, implemented quota compliance effects, repaired save detection, and reduced ECS query overhead. |
| C16 | Contextual advisor (B5) | 2026-03-13 | Claude Code | `advisor.lua` — 14 reactive tips, priority-based, one-shot + cooldown, save/load. Replaces static tutorial with ongoing guidance. |
| C17 | Recreation system (B1) | 2026-03-13 | Claude Code | `recreation.lua` — joy need, 6 rec buildings (bonfire/card table/tavern/sparring/library/radio), work_ai free-time seeking, morale integration. |
| C18 | Doctrine trees (B4) | 2026-03-13 | Claude Code | `doctrines.lua` — 3 paths (Order/Communion/Solidarity), 3 tiers each, doctrine points from hope, effects wired into work speed/joy/rec. |
| C19 | Feature verification fixes | 2026-03-13 | Codex | Verified recreation/doctrines/tutorial claims, added doctrine panel + hotkey, and implemented persistent romance bonds on top of the social system. |
| C20 | Placeholder audio pass | 2026-03-13 | Codex | Added 16 shipped placeholder `.wav` assets under `assets/audio/` and taught `sound.lua` to fall back from `.ogg` to `.wav`, including alert tier sounds. |
| C21 | Audit follow-up cleanup | 2026-03-13 | Codex | Hid archived vehicle/circuit content from research/build/production, switched merchant human sales to prisoners, fixed `Q`/task-queue hotkey conflicts, and cached optional modules out of the sim loop. |
| C22 | History canon rewrite | 2026-03-13 | Codex | Replaced procedural ancient-world history with fixed Erebus canon, preserved procedural failed outposts/rumors, added migration coverage, and aligned `swarm` late-game gating with tests/lore. |
| C23 | AI-copy cleanup + HERMES phase progression | 2026-03-13 | Codex | Tightened player-facing UI/lore copy, added live HERMES phase/directive HUD surfacing, wired day/depth/anomaly deterioration into gameplay and save/load, and added regression coverage. |
| C24 | Player-facing style cleanup pass | 2026-03-13 | Codex | Rewrote the remaining templated medium-issue blurbs in lore, difficulty UI, visitor quests, tutorial copy, storyteller events, and adlib flavor lines after the AI-style audit. |
| C25 | Baseline quota pressure system | 2026-03-13 | Codex | Added a repeating Mammona quota/supply-drop cycle with due-day shipment processing, policy/HERMES modifiers, HUD surfacing, save/load support, and regression coverage. |
| C26 | Thermal core economy alignment | 2026-03-13 | Codex | Removed generic wildlife and raid-victory thermal core minting, pushed mining-based core finds underground, retuned special raider loot away from raw cores, updated HUD copy, and added regression coverage. |
| C27 | Canon cleanup for scenarios/endings/docs | 2026-03-13 | Codex | Marked challenge scenarios as alt-canon in the UI, reframed Mammona endings as corporate outcomes in code and lore, and scrubbed stale vehicle/children/endgame copy from roadmap and checklist docs. |
| C28 | Archived scope remnants sweep | 2026-03-13 | Codex | Quarantined remaining vehicle/slavery surfaces as legacy-only, removed dead expedition vehicle math, and updated roadmap/checklist copy so cut systems stop reading as shipped features. |
| C29 | building.lua split | 2026-03-13 | Codex | Replaced the 2460-line monolith with a slim facade plus dedicated defs, placement, inspection, and shared-state modules without changing the public API. |
| C30 | save.lua split | 2026-03-13 | Codex | Split serializer/gather helpers and slot management out of the monolith, reduced `save.lua` to a 691-line load-focused facade, preserved quicksave existence semantics, and kept the full suite green. |
| C31 | Anomaly containment + Erebus-Touched system | 2026-03-14 | Codex | Added containment cells/lockers, field recoveries, Erebus-Touched raids, intact specimen transfer tied into quotas and quests, UI/HUD surfacing, save/load support, and regression coverage while repairing atmosphere/conveyor regressions. |
| C32 | production.lua split | 2026-03-14 | Codex | Split the monolith into a 12-line facade, shared catalog data, and a runtime/system module while preserving the `Production` API and full test coverage. |
| C33 | Lightweight profiler + debug surfacing | 2026-03-14 | Codex | Added `src/util/profiler.lua`, instrumented the main sim loop with per-system timings, surfaced the data in the debug panel, fixed the LuaJIT upvalue cap in `main.lua`, and added regression coverage. |
| C34 | Expedition containment follow-through | 2026-03-14 | Codex | Added expedition-specific anomaly subject/artifact recoveries, routeable containment findings per destination, storyteller logging, anomaly pressure integration, and regression coverage. |
| C35 | Weapon / defense / trap combat-effects upgrade | 2026-03-14 | Codex | Added persistent napalm, fallout, and aerosol hazard zones; wired radiation into nuclear aftermath; upgraded flame/gas/napalm turrets and traps to use payload systems; added combat hazard rendering; hardened fire/thermal coupling; and added ordnance regression coverage. |
| C36 | Optimization + bug-hunt pass | 2026-03-14 | Codex | Removed hot-path inline guarded imports from `work_ai.lua` and `agriculture.lua`, fixed depth-aware crop CO2 growth, added agriculture regression coverage, and kept the full suite green. |
| C37 | Comprehensive bug hunt + QoL research | 2026-03-14 | Codex | Audited current mechanics for live bugs and dead wiring, compared Frosthold against current colony-sim QoL expectations, and produced a prioritized fix/gap list. |
| C38 | QoL systems implementation block | 2026-03-14 | Codex | Fixed energy-barrier pathing, added layered allowed-area zones with enforcement, completed stockpile filtering/storage, surfaced zone/inserter/machine controls, added build/research search, shipped new atmosphere/logistics/containment/structural overlays, and added regression coverage. |

---
## REMOVED TASKS (with reason)

| # | Task | Reason |
|---|------|--------|
| X1 | Add taming job to work_ai.lua | Not needed. Taming uses ECS mechanics directly, not the job queue. System works as designed. |
| X2 | Multiplayer host/join UI | Cut from scope. `src/net/` deleted, stubs archived. |
| X3 | Victory condition discoverability | Already done. Quest board + 4 endgame buildings discoverable in-game. |
| X4 | Vehicle construction UI | Cut from scope. `vehicles.lua` is a 15-line stub. Expeditions work without vehicles. |
| X5 | Split ui.lua | Already done. ui.lua is 314 lines, split into focused modules. |
| X6 | Turret targeting priority UI | Not needed. Turrets auto-target closest hostile in range. Standard tower defense pattern (same as RimWorld). Over-engineering. |

---
## SCOPE CUTS (archived as stubs)

| Module | Status | Notes |
|--------|--------|-------|
| Multiplayer (`src/net/`) | Deleted, stubs in `archive/multiplayer/` | P2P/LAN was designed but cut |
| Vehicles (`vehicles.lua`) | 15-line stub | Modular vehicle construction removed, expeditions work without |
| Slavery (`slavery.lua`) | Stub | System removed |
| Circuits (`circuits.lua`) | Stub | Sensor/comparator/actuator automation replaced by simple door locks |

---
## BACKLOG (Ideas / Future Work)

| # | Idea | Category | Notes |
|---|------|----------|-------|
| B2 | Expand bond system | Colonist | Lean bond system exists. Future work: double beds, breakup aftermath, ceremonies, and partner-specific room logic. |
| B3 | Children / aging | Colonist | CUT. Cloning vat serves colony growth. Kids in high-lethality survival = design headache. |
| B6 | Expanded performance profiling | Engine | Baseline profiler shipped. Future work: add rolling history, category grouping, or export if deeper perf analysis is needed. |
| B7 | Steam integration | Platform | DEFER. No Steamworks code. Only relevant if shipping on Steam. |

---
## CONVENTIONS FOR AGENTS

1. **Before starting work:** Read this file and check for conflicts.
2. **When starting a task:** Set status to `IN_PROGRESS` and put your name in the Agent column.
3. **When finishing:** Set status to `DONE` and move the row to `RECENTLY COMPLETED` with the date and agent.
4. **If blocked:** Set `BLOCKED` and explain the blocker in `Notes`.
5. **New tasks:** Add them to `ACTIVE TASKS` with the next available number.
6. **Do not delete rows:** move completed work to `RECENTLY COMPLETED`.
7. **Update "Last updated":** change the timestamp and agent at the top whenever this file changes.
