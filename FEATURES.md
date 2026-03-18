# FROSTHOLD — Complete Feature Trace and Game Design Document

## Part 1: Game Loop Flow

### Architecture: Fixed Timestep, Phase-Gated Loop

`main.lua` drives the entire game. Two phases exist: `setup` (pre-game menu) and `playing` (simulation running). A third transient phase, `starting`, triggers world initialization.

**Tick constants** (`main.lua:74`):
- `SIM_DT = 1/20` — 20Hz simulation tick (50ms per tick)
- `accumulator` — collects elapsed real time, consumed in integer `SIM_DT` chunks
- `love.update(dt)` caps dt at 0.25s before adding to accumulator, preventing spiral-of-death

### Per-Frame Execution Order (love.update)

**Phase: setup** — returns immediately. StartMenu handles input.

**Phase: starting** — calls `initGameWorld()` once and returns.

**Phase: playing** — runs the following sequence every frame:

```
1. accumulator += dt
2. Input.update(dt)        -- camera pan keys, held keys
3. Camera.update(dt)       -- smooth camera movement
4. [SIM TICK LOOP] while accumulator >= SIM_DT:
   4.01  simTime += SIM_DT
   4.02  GameState.simTick += 1
   4.03  GameState.tickClock()          -- advance game hour
   4.04  Occupancy.rebuild()            -- recompute reserved tiles
   4.05  ECS.update(SIM_DT)             -- run ALL ECS systems
   4.06  Thermal.step(SIM_DT)          -- heat diffusion
   4.07  Power.step(SIM_DT)            -- grid update, fuel, fault
   4.08  Atmosphere.step(SIM_DT)       -- O2/CO2 per room
   4.09  Lighting.step(SIM_DT)         -- darkness penalty
   4.10  Rooms.step(SIM_DT)            -- room quality/temp tiers
   4.11  Foraging.step(SIM_DT)         -- forage site availability
   4.12  Hope.step(SIM_DT)             -- hope/discontent drift + events
   4.13  Policies.step(SIM_DT)         -- policy cooldown and effects
   4.14  Conveyors.step(SIM_DT)        -- belt item movement
   4.15  Inserters.step(SIM_DT)        -- inserter arm logic
   4.16  Pipes.step(SIM_DT)            -- freeze, flow, spill
   4.17  Research.step(SIM_DT)         -- no-op (bench drives progress)
   4.18  Pollution.step(SIM_DT)        -- pollution spread
   4.19  Expeditions.step(SIM_DT)      -- expedition elapsed, resolution
   4.20  Deterioration.step(SIM_DT)    -- building decay, repair tasks
   4.21  Spoilage.step(SIM_DT)         -- food item decay
   4.22  Merchants.step(SIM_DT)        -- trade caravan events
   4.23  Raids.step(SIM_DT)            -- raid phases, spawning, retreat
   4.24  Recruitment.step(SIM_DT)      -- wanderer attraction, radio beacon
   4.25  StrangeMoods.step(SIM_DT)     -- colonist strange mood inspiration
   4.26  Factions.step(SIM_DT)         -- inter-faction relations
   4.27  Agriculture.step(SIM_DT)      -- crop growth, harvest tasks
   4.28  Items.step(SIM_DT)            -- item entity decay
   4.29  Equipment.step(SIM_DT)        -- equipment durability
   4.30  Jobs.step(SIM_DT)             -- stale task cleanup (every 10s)
   4.31  Production.autoStock(SIM_DT)  -- machine input pull / output push (every 3s)
   4.32  Building.update(SIM_DT)       -- heat building fuel consumption
   4.33  Fire.step(SIM_DT)             -- fire spread, damage
   4.34  Weather.step(SIM_DT)          -- weather transitions
   4.35  Elastic.step(SIM_DT)          -- elastic difficulty adjustment
   4.36  Taming.step(SIM_DT)           -- tamed animal management
   4.37  Taming.checkBreeding(SIM_DT)  -- breeding cooldowns
   4.38  EldritchNodes.step(SIM_DT)    -- node HP, loot, events
   4.39  Storyteller.step(SIM_DT)      -- event scheduling and firing
   4.40  accumulator -= SIM_DT
5. GameState.alpha = accumulator / SIM_DT  -- interpolation factor for render
6. Weather.updateParticles(dt, ...)    -- real-time particle movement (not tick-gated)
7. Sound.update(dt)
8. Tutorial.update(dt)
9. Minimap.update()
10. Save.step(dt)                      -- auto-save every 300s
11. UI.update(dt)                      -- panel animations, menu updates
```

**Critical ordering notes:**
- `ECS.update` (step 4.05) runs all registered ECS systems including needs decay (priority 10), disease tick (11), mental breaks (12), production (15), movement (20), creature AI (25), work AI (28), combat AI (29), slavery (29), processor tick (30), and jobs registration (50+). This runs before `Thermal.step`, which means ECS systems see last frame's tile temperatures.
- `Thermal.step` runs after ECS so the thermal system can query current colonist heat sources and generator output set this tick.
- `Raids.step` runs after `Merchants.step` — both are time-gated events in the storyteller pipeline, but raids are independent.
- `Storyteller.step` is the last simulation step each tick. It fires events after observing the full state of all other systems.

### ECS System Priority Table (within ECS.update)

| Priority | Systems |
|---|---|
| 10 | needsDecaySystem (colonist needs decay, hypothermia) |
| 11 | disease_tick |
| 12 | frostlung_contraction, blackrot_contraction, mental_breaks |
| 15 | productionSystem (machines) |
| 20 | movementSystem (colonist pathfinding) |
| 25 | creatureAI, lairs tick |
| 28 | workAI |
| 29 | combatAI, slaverySystem |
| 30 | processorSystem (pipe_processors) |
| 50+ | disease_medical_task, disease_recovery_cleanup, bench research tick |

---

## Part 2: World Initialization

`initGameWorld()` (`main.lua:95`) is called once when the player clicks "Start Colony." Order matters:

1. `GameState.init()` — clear resources, set defaults
2. `ECS.init()` — clear all entities and systems
3. `World.init(128, 128)` — generate 128×128 tilemap via Perlin noise, place terrain features
4. Core sim systems init: `Thermal`, `Power`, `Atmosphere`, `Lighting`
5. Logistics: `Foraging`, `Conveyors`, `Inserters`, `Pipes`, `Research`, `Pollution`
6. World events: `Expeditions`, `Deterioration`, `Fire`, `Generator`, `Spoilage`
7. Social/faction systems: `Merchants`, `Raids`, `Factions`, `StrangeMoods`, `History`
8. Creature systems: `Taming`, `EldritchNodes`
9. `Difficulty.apply()` / `Difficulty.applyScenario()` — set resource multipliers, scenario starting conditions
10. `Elastic.init()` — set elastic difficulty baseline
11. Presentation: `Sound`, `Minimap`, `Tutorial`, `Camera`, `Renderer`, `UI`, `Input`
12. ECS system self-registration via `require` — all modules in the list at `main.lua:137–160` register their systems on require
13. Colonist spawn: `Colonists.spawnInitial(startX, startY, count)` using `scenDef.colonists`
14. Scenario modifiers: skill boosts, caps, wounds, immediate raid
15. `Lairs.generateForWorld(World)` — scatter creature spawners
16. Set `GameState.phase = 'playing'`

---

## Part 3: Player Interaction Loop

### Input Sources

**Keyboard** (`src/ui/input.lua`):
- `1/2/3` — set game speed to 1x/2x/3x via `GameState.speed`
- `space` — toggle pause (`GameState.paused`)
- `b` — enter build mode; opens building menu
- `m` — mine designation tool; subsequent LMB drag designates tiles
- `z` — stockpile zone creation tool
- `x` — dumping zone creation tool
- `f` — forage designation tool
- `f2` — toggle thermal overlay on renderer
- `escape` — cancel current tool or open pause menu
- `f5` — `Save.save()`
- `f9` — `Save.load()`
- `tab` — `Minimap.toggle()`
- `f1` — `Tutorial.toggle()`

**Mouse actions:**
- LMB drag — selection box: on release, box-selects all colonist entities whose tile position falls within the screen-space box; selects single entity on single click
- LMB drag in tool mode — mine/zone drag creates a rectangular region designation
- LMB in build mode — places building ghost; confirms placement by submitting a `build` task to `Jobs`
- RMB — cancel build mode; or issue move order to all selected colonists (computes individual A* paths via `Pathfind.find`, writes to `path.nodes`)
- MMB drag — camera pan

**Mouse input consumption** (`src/ui/ui.lua`): `UI.mousepressed` is called first and returns `true` if any menu is open or a UI element was clicked. This prevents world interaction while menus are active.

### Player-Facing UI

**Resource bar** (top of screen, `src/ui/ui.lua`): Displays live `GameState.resources` values for: Cores, Wood, Stone, Metal, Food, Fuel.

**Time/speed bar** (top-right): Shows day, hour, game speed.

**Selection panel** (bottom): For single colonist: name, HP, task/progress percentage, four need bars (warmth/food/rest/morale), all six skill levels, trait list (color-coded good/neutral/bad), backstory text. For multiple colonists: count and name list.

**Debug bar** (top-left, `main.lua:328`): FPS, simTick, colonist count, creature count, ambient temp, weather name, power supply/demand, unclaimed task count, hope, discontent, heat signature, elastic band, stress %, wellness, raid status.

**Menus**: Pause menu (Escape) — dimmed overlay. Other menus pushed/popped from `UI`'s menu stack.

### Player Decisions and Their Code Paths

| Player Action | Code Path |
|---|---|
| Click "Start Colony" | `StartMenu.mousepressed` → `GameState.phase = 'starting'` → `initGameWorld()` |
| Place a building | `Input` click → ghost placement → `Jobs.designateBuild` → task in queue → colonist claims it → `Work_AI` arrives → `Building.tryPlace` executes |
| Designate mining | `Input` drag → `Jobs.designateMine` per tile → tasks in queue → colonist claims → `Work_AI` executes mine task |
| Set machine recipe | UI interaction → `machine.recipe = recipeId` → `productionSystem` picks it up next tick |
| Set colonist schedule | UI schedule grid → `schedule[hour] = blockType` |
| Set colonist work priorities | UI priority grid → `workPriority[col] = 1–4 or 0` |
| Issue move order (RMB) | `Pathfind.find(pos, target)` → `path.nodes = result` |
| Launch expedition | `Expeditions.launch(destId, memberIds)` |
| Enslave prisoner | `Slavery.enslave(prisonerId)` |
| Apply law/policy | `Laws.apply(lawId)` or `Policies.apply(policyId)` |
| F5/F9 | `Save.save()` / `Save.load()` |

---

## Part 4: All Game Systems

### 4.1 Thermal System (`src/sim/thermal.lua`)

**What it does**: Simulates heat diffusion across the 128×128 tilemap. Rooms enclosed by walls accumulate heat from sources; outdoor tiles bleed toward ambient temperature; insulated tiles resist transfer.

**ECS components used**: None directly. Reads tile data from tilemap. Queries ECS for generator hubs via `Generator.getHeatBonus`.

**Step sequence** (every sim tick):
1. Room detection every 5s: BFS flood-fill from non-solid tiles. Rooms touching the map edge get roomId=0 (outdoor). Enclosed rooms get positive roomId.
2. Point heat sources applied: LAVA_VENT tiles and registered `heatSources[idx]` entries add watts×dt×0.1 to tile temperature.
3. Generator heat zones: queries `Generator.getHeatBonus(x,y)` for reactor/steam hub heat radius.
4. Jacobi diffusion: each non-solid tile averages with its four neighbors. Transfer rate reduced by `1.0 - neighbor_insulation×0.5`. DIFFUSION_RATE=0.15. Dual-buffer (read old, write new) for stability.
5. Outdoor bleed: roomId=0 tiles converge toward `GameState.globalTemp` at OUTDOOR_BLEED=0.3 per tick.
6. Wind chill: indoor tiles adjacent to outdoor tiles lose heat × windFactor × (1-worstInsulation) × 0.1.
7. Room average temperature updated for use by Rooms, colonist needs, disease.

**Insulated tile types**: WALL_INSULATED (18), FLOOR_INSULATED (19), DOOR_SEALED (20) — all reduce transfer rate.

**Player visibility**: Thermal overlay (F2). Room temperatures shown in room inspection panel.

### 4.2 Power System (`src/sim/power.lua`)

**What it does**: Union-find grid connecting conduit tiles into power networks. Tracks supply (generators) and demand (consumers) per network root. Enables/disables machines based on power availability.

**ECS components used**: `generator` (output, fuelType, fuelRate), `consumer` (demand, powered), `machine` (powered field written by power step).

**22 generator types** including: hand_crank, campfire_heat, wind_turbine, water_wheel, solar_panel, coal_furnace, geothermal, steam_engine, reactor, small_reactor, bio_gas, treadmill, chain_gang_wheel, nuclear_power, lightning_rod, thermal_differential, thermoelectric, heat_converter, and intermittent variants.

**Step sequence** (every 2s): Rebuild union-find by scanning conduit tiles, merge adjacent. Sum supply/demand per root. Fuel consumption each tick. Auto-refuel from `GameState.resources`. Nuclear meltdown check. Fault roll (0.1%/tick) creates repair task. Brownout check: if supply < demand for root, `machine.powered = false` for all consumers in that grid. CO2 emission computed.

**Manned generators**: hand_crank, treadmill, chain_gang_wheel create `operate_generator` tasks. Output scaled by `crewPresent / crewNeeded`.

**Intermittent generation**: solar output follows time-of-day cosine curve with weather penalty; wind scales with `windChill`; storm only during lightning weather; heat generators scale 0–1 from tile temp range 20–80°C; thermal differential uses indoor/outdoor temp delta.

**Player visibility**: Power supply/demand shown in debug bar and building inspection panel. Machines show "unpowered" state.

### 4.3 Atmosphere System (`src/sim/atmosphere.lua`)

**What it does**: Tracks O2 and CO2 levels per room. Colonists consume O2 and produce CO2. Ventilation buildings transfer gases between rooms.

**ECS components used**: Reads `pos` of colonists to find their room. Writes to colonist `needs` for O2 debuff.

**Effects on colonists** (in needs decay system): O2 < 60% applies work speed debuff. O2 < 0% deals 5 HP/s damage.

**Step**: Colonists consume O2 proportional to count per room per tick. Ventilation buildings (registered via `Building.tryPlace` with `def.ventType`) move gas between adjacent rooms. CO2 emission from power generators also routed here.

**CO2 from pipe processors**: `waste_processor` emits CO2 via `Atmosphere.injectCO2` — currently a pending implementation (no-op until method is added).

### 4.4 Lighting System (`src/sim/lighting.lua`)

**What it does**: Per-tile darkness value based on time of day and light source placement. Darkness below threshold applies morale penalty to colonists.

**Step**: At night hours, tiles without a nearby torch/lamp/window are dark. Colonist needs decay system reads `Lighting.isDark(x,y)` and subtracts from morale if colonist is in darkness.

### 4.5 Rooms System (`src/world/rooms.lua`)

**What it does**: Computes room quality (impressiveness) and temperature comfort tier. Room quality affects bed sleep bonus, morale, and building unlocks.

**6 temperature tiers**: freezing (<-20°C), very_cold (-20 to -5), cold (-5 to 5), comfortable (5 to 22), warm (22 to 35), hot (>35°C).

**8 room types**: barracks, dining, hospital, lab, workshop, storage, rec_room, throne.

**Impressiveness formula**: weighted sum of room type, decoration count, floor type, size, and connected luxury buildings. Written to `GameState.roomQuality[roomId]`.

### 4.6 Colonist Needs (`src/colonist/colonist.lua`, needsDecaySystem priority 10)

**ECS components**: `colonist`, `needs`, `pos`, `schedule`.

**Warmth decay**: `delta = (10 - tileTemp) * 0.02 * (1 - coldResist) * dt`. Insulated floors reduce decay. Thaw drug adds `warmth = 40`.

**Food drain**: `0.02/s` base, modified by policy/law `foodDrainMult`. Starvation (food < 5) deals health drain.

**Rest drain**: `0.01/s` during work hours (recovers during sleep block). Addiction activeEffect scales by `GameState.speed`.

**Morale integration**: `(warmth + food + rest) / 3` plus trait modifiers, room quality, hypothermia stage penalty, policy modifiers, lighting penalty. Net morale changes sanity over time.

**5 hypothermia stages** (determined by warmth need):
- normal (warmth ≥ 60): no penalty
- chilled (40–60): -10% work speed
- cold (20–40): -30% work speed, -10% move speed
- hypothermic (10–20): -50% work speed, -30% move, 0.5 HP/s drain
- severe (<10): -80% work speed, -50% move, 2 HP/s drain

**Death**: health ≤ 0 → state = 'dead', drops `corpse_human` entity, notifies Hope(-15 hope, +10 discontent), Social (grief spread), Elastic (wellness impact). `ECS.destroy(id)` deferred.

### 4.7 Work AI (`src/colonist/work_ai.lua`, priority 28)

**ECS filter**: `colonist, pos, path, schedule, workPriority`.

**Schedule dispatch** (reads `GameState.hour`):
- SLEEP: find bed via `Beds.findForColonist`, path to it, rest recovery 0.15/s × (1 + quality×0.3)
- EAT: consume `GameState.resources.food` (quality-weighted), recover needs.food
- FREE: idle wander, morale recovery 0.03/s
- WORK: call `Jobs.findBestTask` and execute

**Work task executors**:
- `mine`: tile durability countdown at `effectiveSkill×dt`, converts tile to floor, drops resource item, updates pathfinding grid
- `build`: calls `Building.tryPlace(defId, x, y, builderId)`
- `haul`: instant — takes item, places in stockpile
- `hunt`: delegates to `Hunting.execute`
- `medical`: calls `Wounds.treat(id, slot, skill, quality)` or `Disease.treat(id, skill, quality)` based on patient condition
- `harvest`: calls `Agriculture.harvest(x, y, colonistId)`
- `forage`: calls `Foraging.attemptForage(x, y, colonistId)`
- `operate_generator`: registers crew with generator, drains rest at 0.02/s, never completes
- `research`: advances `Research.addPoints(skillLevel × dt)`

**Work speed modifiers** (`getWorkSpeedMods`): combines policy modifier + addiction activeEffect + mental_break reaction + law modifier + status effect modifier. Multiplied into all task progress rates.

**Skill effectiveness**: calls `Skills.getEffectiveLevel` which includes polymath mastery bonus (+1 to all skills if mastery acquired).

### 4.8 Job System (`src/colonist/jobs.lua`)

**Task queue**: `taskQueue[id] = {type, def, x, y, data, claimed, progress, complete}`.

**findBestTask algorithm**: Iterates priority levels 1→4. Within each level, scans work columns in order: medical, hauling, cooking, building, mining, operating, hunting, research, cleaning. For each column matching a colonist's priority setting, collects unclaimed tasks and sorts by Manhattan distance squared. Returns nearest task at highest priority level.

**findTaskForSlave**: Simpler — nearest task from slave-allowed types (mine, build, haul, operate, cook, clean, operate_generator).

**Claim**: Task gets `claimed = entityId`. Work_AI checks `col.task` for claimed task on each tick.

**Cleanup** (every 10s): removes `complete` tasks, unclaims tasks from dead colonists, removes harvest tasks for consumed crops, removes mine tasks for already-mined tiles.

**Designation helpers**: `designateMine` checks tile type (ROCK/ICE/TREE/ORE_VEIN) before queuing. `designateBuild` creates build task with building def and position. `requestHaul` creates haul task for item entity.

### 4.9 Combat System (`src/combat/combat_ai.lua`, priority 29)

**ECS filter**: `colonist, pos, path`.

**Detection**: 12 tile radius (5 if sleeping/eating).

**Fight-or-flee**: coward trait threshold 70% HP, brave 20% HP, default 40%. No weapon + not brave = always flee.

**Flee**: A* path 10 tiles away from threat; if pathfinding fails, random direction.

**Fight — ranged** (cooldown 1.5s): calls `Ranged.fire(attackerId, targetId)` — computes hit chance from skill and range, deals damage on hit, applies wound.

**Fight — melee** (cooldown 0.8s): `base = floor((2×level/5+2) × damage × (skillLevel/10) / 50) + 2`. 5% + 1%/skill crit for 1.5× damage. Berserker mastery +25%, brave trait +10%, ex_soldier +15%.

**Body part targeting**: `Body.randomPart()` returns weighted random part (head/torso/arms/legs). `Body.damagePart` applies armor reduction, then calls `Wounds.apply(id, part, woundType, severity)`.

### 4.10 Wound and Medical System (`src/combat/wounds.lua`, `src/medical/surgery.lua`)

**Wound types**: cut, burn, frostbite, fracture. Stored in `colonist.wounds` list as `{part, type, severity}`.

**Wound effects**: severity reduces movement and work speed. Fractures immobilize the affected limb.

**Treatment**: `Wounds.treat(id, slot, skill, quality)` — medical colonist applies bandage/medicine, reducing severity over time proportional to doctor skill and medicine quality.

**Surgery** (`src/medical/surgery.lua`): organ harvest and transplant. Called from `Slavery.harvestOrgan`. Requires surgery table building. Handles prosthetic installation.

### 4.11 Disease System (`src/sim/disease.lua`, ECS-only)

**3 diseases with distinct behavior**:
- `frostlung`: 0.25% severity/s. Triggered by `warmth < 20` (0.5%/s chance) or `warmth < 5` (2%/s). Symptom: cold resistance reduced.
- `blackrot`: 0.42% severity/s, health drain 0.1/s. Triggered by untreated wounds. More lethal.
- `ice_plague`: 0.17% severity/s, morale drain. CONTAGIOUS — 3-tile radius spread at 0.1% chance/s.

**Immunity race**: Both `severity` and `immunity` advance each tick. Immunity rate boosts: in bed (+30%), quality bed 2+ (+20%), medicine quality industrial (+25%), advanced (+50%), doctor skill (+5%/level). If severity reaches 100 first → death. If immunity reaches 100 first → cure.

**Cure**: remove disease component, +10 morale, set `_recovering` flag (prevents reinfection 5 game-days), grant scar trait.

**Treatment** (`Disease.treat`): sets `treated = true`, `treatmentTimer = TREATMENT_DURATION` (1 game-day), records doctor skill and medicine quality (takes max of current/new values).

### 4.12 Raid System (`src/sim/raids.lua`)

**4 raid types**:
- `beast_assault` (day 5+): 1 wave, 1 direction, retreat at 50% casualties
- `siege` (day 12+): 2 waves, breacher pool in composition
- `coordinated` (day 20+): 2 waves, 2 directions simultaneously
- `swarm` (day 30+): 3 waves, all 4 directions, NO retreat, 3× budget

**Heat signature**: `reactor output + PowerLevel×10 + overdrive×20 + colonists×3 + thermalCores×0.5`.

**Budget formula**: `floor((30 + day×2 + raidsSurvived×5) × typeDef.budgetMult × heatMult × aggression × elasticMod)`.

**Wave composition**: expensive creatures first, cheap fill remainder. Sorted by CREATURE_COST table.

**Raid phases**: warning (15s, 120s for swarm), active (spawn waves on schedule), aftermath (wait for retreaters to despawn or die).

**Victory**: all raid creatures dead → raidsSurvived++, salvage thermalCores = budget×0.1, Hope+5, scar trait roll for survivors.

**Prisoner capture**: `onCreatureDeath` checks if creature is in `raidCreatures` set → calls `Recruitment.tryCapture` with 25% chance.

### 4.13 Hope and Morale System (`src/colony/hope.lua`)

**Dual meters**: `hope` (0–100) and `discontent` (0–100). Independent trajectories.

**Natural drift**: hope → 50 at 0.2%/s, discontent → 20 at 0.1%/s.

**Events** (via `Hope.onEvent`, `Hope.onDarkAction`):
- colonist death: hope-15, discontent+10
- good meal: +2 hope
- building completed: +3 hope
- memorial built: +10 hope, discontent-5
- wanderer joined: +5 hope
- organ_harvest: hope-12, discontent+8
- execution: hope-8, discontent+5
- butcher_human: hope-10, discontent+6
- enslave: hope-5, discontent+4

**Despair**: hope < 20 for 3+ game-days → lowest-morale colonist voluntarily leaves (ECS.destroy).

**Revolt**: discontent > 80 for 2+ game-days → 1-day revolt, all colonists refuse work (`Hope.isRevoltActive()` checked in work_ai). Discontent-15 after revolt ends.

**Laws/policies**: can cap discontent maximum, set hope floors.

### 4.14 Production System (`src/building/production.lua`)

**Item catalog**: 52+ items across categories: raw, material, advanced, food, medicine, drug, corpse, organ, prosthetic, bionic, equipment, throwable, eldritch, ammo, power.

**30 recipes** across 15 machine types. Recipe fields: machine type, inputs (itemId → count), outputs (itemId → count), time (seconds), power draw, required skill, minimum skill level.

**Machine ECS component** (`machine`): type, name, recipe, inputBuf, outputBuf, progress, active, powered, assignee.

**productionSystem** (priority 15, filter: `machine`):
1. Check recipe set
2. Check power: if recipe.power > 0 and not machine.powered, stall
3. Check inputBuf has all required inputs
4. On start: consume inputs from inputBuf, set active=true, progress=0
5. Each tick: `progress += dt × speedMult` (1.0 + (skill-1)×0.08 + trait workSpeed/craftMod bonuses)
6. On complete: compute qualityMult (poor <3 = 0.85, normal = 1.0, good 6–8 = 1.15, excellent 9+ = 1.3; master_smith mastery always 1.3). Push outputs to outputBuf. Award 15 XP to assignee.
7. Dark recipe (butcher_human): Hope.onDarkAction, all colonists -15 morale.

**autoStock** (every 3s): Iterates all `machine` entities. Pulls inputs from `GameState.resources` if inputBuf < 3 batches. Pushes outputBuf back to `GameState.resources`. Uses ITEM_TO_RES and OUTPUT_TO_RES lookup tables mapping recipe item IDs to resource keys.

**Drug effects table** (`Production.DRUG_EFFECTS`): 11 drugs with duration and effects (workSpeedBuff, morale delta, restDrain, sanityDrain, painReduce, healthRegen, damageBuff, coldResistBuff, warmth, socialBuff).

**Food quality table** (`Production.FOOD_QUALITY`): nutrition value, morale modifier, quality tier per food type. Feast: nutrition=50, morale=+20. Human meat: nutrition=20, morale=-40.

### 4.15 Pipe Network (`src/logistics/pipes.lua`)

**Dual union-find networks**: separate `fluid` and `gas` networks. Nodes are ECS entities with `pipe_node` component.

**Fluid types** (from `src/logistics/pipe_defs.lua`): water, oil, coolant, ichor, sewage, fuel_liquid. 4 gases: oxygen, nitrogen, steam, toxic_gas. 6 pipe types with varying throughput and insulation. 4 tank types. 7 processor types.

**step(dt) sequence**:
1. Rebuild fluid network every 2s (union-find from pipe nodes). 3-phase fluid conservation: before rebuild, record network levels by tile; after rebuild, redistribute proportionally to new topology.
2. Rebuild gas network every 2s similarly.
3. Freeze/deterioration check every 1s: read tile temperature from tilemap, advance `frozenTime` if below freeze threshold, apply throughput reduction stages, burst check (burstChance per stage), burst = spill + repair task + node removal.
4. Leak tick: passive fluid loss at leak rate, occasional spill entity spawn.
5. Production tick: source nodes inject fluid up to network capacity.
6. Consumption tick: sink nodes drain from network.
7. Tank equalization: tanks push/pull 5 units/s when level exceeds 50% of capacity.
8. Spill tick: age spill entities, apply `tempDelta` to tiles, `pollutionRate` to pollution system, `toxicRadius` status effects to nearby colonists. Fuel spills can ignite fire via `Fire.ignite`.

**Freeze stages** (from pipe_defs.lua): progressive frozenTime thresholds → throughputMult reduction → damagePerTick to pipe node HP → burstChance when fully frozen.

### 4.16 Research System (`src/research/research.lua`)

**35 nodes across 5 tiers**. Colony-wide state: `completed[nodeId]`, `current`, `progress`.

**Progress driven by bench**: research bench ECS system (registered in `src/research/bench.lua`) increments `Research.addPoints(skillLevel×dt)` when an assigned colonist is present and powered.

**Unlock types**: `recipes` (check via `Research.isRecipeUnlocked`), `buildings` (via `isBuildingUnlocked`), `equipment` (via `isEquipmentUnlocked`).

**Key research paths**:
- basic_survival → field_medicine → pharmacology (unlocks drug_lab)
- basic_smelting → advanced_materials → fluid_systems (tier 3) → advanced_plumbing (tier 4) → exotic_fluids (tier 5)
- basic_defenses → advanced_defenses → heavy_ordnance → experimental_defenses
- advanced_materials → thermal_tech → compact_reactors → nuclear_power

### 4.17 Elastic Difficulty (`src/sim/elastic_difficulty.lua`)

**Purpose**: Dynamically adjusts raid difficulty, loot drops, and event frequency based on colony wellness.

**Metrics**: colony wellness (resource levels, colonist count, health averages), colony stress (recent deaths, wounds, morale averages). Computed each step as exponentially smoothed moving average.

**Band system**: `getBandId()` returns current difficulty band name. `getSmoothedStress()` returns 0–1 stress value. `getColonyWellness()` returns 0–100 wellness.

**Modifiers applied**: raid budget multiplied by `elasticMod` from Raids. Creature loot multiplied by `lootMod` from Creatures.kill. Storyteller event frequency adjusted.

### 4.18 Creatures (`src/creatures/creatures.lua`)

**40+ species**, 3 tiers. Tamed creatures wander near pen anchor.

**creatureAI system** (priority 25):
1. Tamed: wander within tameRange of pen, ignore colonists.
2. Non-tamed: find nearest colonist, apply night hunter aggroRange doubling (hours 20–6). Fear aura drain to nearby colonists. If hostile + in aggroRange → chase. At adjacent tile → attack (cooldown 1s): `armor reduction → Body.randomPart → Body.damagePart → Wounds.apply → death check`. Leash check: if >leashRange from home, return home. Passive: flee if colonist in fleeRange. Idle wander 1%/tick.

**Natural spawn**: every `SPAWN_INTERVAL / (aggression × reinforcement)` seconds. Species weights by day (small early, megafauna day 45+, eldritch day 45+).

**Creature.kill**: thermal core drop (scaled by `elasticMod × bigGameHunterMastery`), corpse entity for butchering, notifies Raids (prisoner capture roll), notifies Hunting (hide drop), notifies EldritchNodes.

### 4.19 Slavery System (`src/colonist/slavery.lua`, priority 29)

**Component**: `slave` (converted from `prisoner`).

**Slave work**: reduced food rate (0.015 vs 0.02), same warmth decay, rest drains 0.015/s (collapse at rest<5, recover to 30). Uses `Jobs.findTaskForSlave`. Work speed = `(1 + (skill-1)×0.1) × 0.8`.

**Escape**: every 30s check `BASE_ESCAPE_CHANCE × (1-obedience)`, doubled if morale < 20.

**Colony morale penalty**: -3 per slave per tick integrated into morale for all colonists.

**Dark actions**: `executeSlave`, `harvestOrgan` (→ Surgery), `butcherSlave` — each with specific Hope and morale penalties.

### 4.20 Expeditions (`src/exploration/expeditions.lua`)

**Max 2 concurrent**. Party 1–3 colonists. Colonists with `away` component are skipped by all simulation systems.

**Outcome chance**: `base = 0.70 - risk×0.08` + size bonus + hunting skill bonus + equipment bonus + cold resist bonus + vehicle bonus + perk bonus. Clamped 10–95%.

**Success**: full `Overworld.rollRewards`. Partial: partial rewards + 30% injury chance per member. Failure: no rewards, all injured; risk≥4 adds 15% death chance, risk≥5 adds 25%.

**Return**: survivors set back to colonist state, `away` component removed, positioned near colony center.

### 4.21 Storyteller (`src/storyteller/storyteller.lua`)

**3 personalities**: benevolent, neutral, ruthless — adjust event frequency and severity.

**9 event types**: raid, supply_drop, wanderer, disease_outbreak, blizzard, merchant, creature_surge, refugee, eldritch_awakening.

**Threat budgeting**: tracks colony threat level from raid outcomes, wealth, colonist count. Schedules events at computed intervals modified by personality and elastic difficulty.

**step(dt)**: decrements event timer. On fire: resolves event (spawns storyteller-generated content), emits toast notification to renderer.

### 4.22 Fire System (`src/sim/fire.lua`)

**Fire entities** with `fire` component on tiles. Spreads to adjacent flammable tiles each tick. Deals damage to colonists and buildings in tile. Fuel pipe spills can ignite adjacent fire. Nuclear meltdown triggers `Fire.ignite` from power.lua.

### 4.23 Agriculture (`src/building/agriculture.lua`)

**Crop growth**: ECS system, crops have `crop` component with growTime, elapsed, yield. When elapsed ≥ growTime, creates harvest task via Jobs. Worker executes harvest, adds food/fiber/leaves to GameState.resources.

**Farm zone**: designated tiles where seeds are planted.

### 4.24 Strange Moods and Mental Breaks

**Mental breaks** (`src/colonist/mental_breaks.lua`, priority 12): triggered at sanity ≤ 0. Pyromaniac sets adjacent floor tiles to DEBRIS. Coward paths to map edge. Glutton eats 5 food/s from colony. Berserk attacks nearest entity every 2s.

**Strange moods** (`src/colonist/strange_moods.lua`): periodic inspiration events requiring specific resources. If resources provided, colonist produces a masterwork item with morale bonus.

**Social relationships** (`src/colonist/social.lua`): opinion table per colonist pair. Friends, rivals, grief propagation on death.

### 4.25 Eldritch Nodes (`src/creatures/eldritch_nodes.lua`)

**Node entities** generated during world gen via `EldritchNodes.init`. Nodes have HP and loot tables.

**step**: damaged nodes spawn eldritch creatures. Killed nodes drop eldritch resources (ichor, fat, chitin, void crystal). Node kill notified by `Creatures.kill` callback. Storyteller event `eldritch_awakening` fully activates dormant nodes.

---

## Part 5: Five Core Simulation Chains

### Chain 1: Temperature → Colonist Health → Medical → Death

1. `Weather.step(dt)` (`main.lua:4.34`) sets `GameState.globalTemp` and `windChill` from weather type `tempMod`.
2. `Thermal.step(dt)` (`main.lua:4.06`) applies outdoor bleed and wind chill to tile temperatures, diffuses heat.
3. `ECS.update` runs `needsDecaySystem` (priority 10, `colonist.lua`): reads `Tilemap.getTemp(pos.x, pos.y)`, computes warmth delta `(10 - tileTemp) × 0.02 × (1 - coldResist) × dt`, decrements `needs.warmth`.
4. When `needs.warmth < 40`, colonist enters hypothermia stages. At severe (<10), `health -= 2×dt`.
5. If health ≤ 0: `col.state = 'dead'`, corpse entity spawned. `Hope.onColonistDied(id)` (-15 hope, +10 discontent). `Social.onDeath(id)` (grief spread). `Elastic.onColonistDied(id)` (wellness impact). `ECS.destroy(id)` deferred.
6. At O2 < 0% (Atmosphere system): additional 5 HP/s damage.
7. `disease_tick` (priority 11): if frostlung active (contracted when warmth < 20), severity increases 0.25%/s. Severity ≥ 100 → colonist dies same as health = 0.
8. `disease_medical_task` (priority 50, every 100 ticks): if colonist has disease and no medical task claimed, creates `medical` task.
9. `Jobs.findBestTask` returns medical task at priority 1 (highest column).
10. Medical colonist arrives, `Wounds.treat` or `Disease.treat` executed in work_ai.
11. `Disease.treat`: sets `treated = true`, records doctor skill and medicine quality.
12. `disease_tick`: treated severity grows at `treatedSevMult` (reduced fraction). Immunity grows faster with medicine quality and bed quality.
13. If immunity reaches 100: disease cured. If severity reaches 100 first: lethal → same death path as step 5.

**Key files**: `src/weather/weather.lua`, `src/sim/thermal.lua`, `src/colonist/colonist.lua`, `src/sim/disease.lua`, `src/colonist/work_ai.lua`, `src/colonist/jobs.lua`, `src/combat/wounds.lua`

### Chain 2: Building → Power → Machines → Production

1. Player selects building from UI menu → `Input` creates build task via `Jobs.designateBuild(defId, x, y)`.
2. Building colonist claims task → paths to site → `work_ai` calls `Building.tryPlace(defId, x, y, builderId)`.
3. `Building.tryPlace` checks resources → `GameState.spendResource` → places tile → dispatches `entitySpawn`:
   - For 'machine': `Production.placeMachine(machineId, x, y)` spawns ECS entity with `machine` component. If `def.powerDraw > 0`, `Power.addConsumer(eid, powerDraw, x, y)`.
   - For 'generator': `Power.addGenerator(eid, genType, x, y)`.
   - For conduit tiles: registers in `Power.conduits` table for union-find.
4. `Power.step(dt)` (every 2s): rebuilds union-find across conduit tiles. Sums generator outputs per network root. Compares supply vs demand. Sets `machine.powered = (supply >= demand)`.
5. Player sets recipe on machine via UI → `machine.recipe = recipeId`.
6. `Production.autoStock` (every 3s): pulls recipe inputs from `GameState.resources` into `machine.inputBuf` if buffer < 3 batches.
7. `productionSystem` (priority 15, ECS.update): checks `machine.powered`, checks inputBuf, consumes inputs, advances `machine.progress` by `dt × speedMult`.
8. On recipe completion: pushes outputs to `machine.outputBuf`. Awards skill XP to assignee.
9. `Production.autoStock` (every 3s): flushes `outputBuf` to `GameState.resources` via OUTPUT_TO_RES mapping.
10. Resources now available for other production chains, building costs, or colonist consumption.

**Key files**: `src/ui/input.lua`, `src/building/building.lua`, `src/sim/power.lua`, `src/building/production.lua`

### Chain 3: Raids → Combat → Wounds → Medical

1. `Raids.step(dt)` advances raid timer. When threshold reached: `Storyteller.step` triggers raid event, or direct `RaidsMod.startRaid(type)` from scenario init.
2. Warning phase (15s): alert notification, `Renderer.drawEventToast`.
3. Active phase: `Raids.step` calls `Creatures.spawn(speciesId, edgeTileX, edgeTileY)` per wave composition. Sets `creature.hostile = true`, `creature.raidId`.
4. `creatureAI` (priority 25): finds nearest colonist within aggroRange. Paths toward target.
5. At adjacent tile: attack cooldown check. `Body.randomPart()` selects target part. `Body.damagePart(targetId, part, damage)` applies armor reduction. `Wounds.apply(targetId, part, type, severity)` adds wound to `colonist.wounds`.
6. If health ≤ 0: colonist death chain (Chain 1, step 5).
7. `combatAI` (priority 29): colonist detects hostile creature at ≤12 tiles. Fight-or-flee determination. If fighting: ranged `Ranged.fire` or melee attack.
8. Raid creature killed: `Creatures.kill(id)` → `Raids.onCreatureDeath(id)` → 25% chance `Recruitment.tryCapture` → prisoner ECS entity spawned.
9. 50% casualties (non-swarm): surviving raid creatures set `state = 'flee'`, path toward edge, despawn on leaving map.
10. All raid creatures dead: raidsSurvived++, thermal core salvage, Hope+5, scar trait application.
11. Injured colonists: `disease_medical_task` or Wounds system creates `medical` task.
12. Medical colonist executes `Wounds.treat` → bandage/medicine reduces wound severity over time.
13. Prisoners: `Slavery.enslave` converts prisoner component to slave. Or prisoner escapes via 15%/30s check.

**Key files**: `src/sim/raids.lua`, `src/creatures/creatures.lua`, `src/combat/combat_ai.lua`, `src/combat/wounds.lua`, `src/combat/body.lua`, `src/colonist/recruitment.lua`, `src/colonist/slavery.lua`

### Chain 4: Pipe Network → Fluid Flow → Processors → Resources

1. Player places pipe building via `Building.tryPlace('pipe', x, y)` → `Pipes.addPipeNode(x, y, nodeType, medium)`.
2. Player places processor via `Building.tryPlace('processor', x, y, processorType)` → `Processors.place(x, y, processorType)`:
   - ECS entity with `processor` and `pos` components
   - `ensurePipeNode` for input/output mediums
   - If powerDraw > 0: `machine` component + `Power.addConsumer`
3. `Pipes.step(dt)` (every 2s): union-find rebuild across all `pipe_node` entities. Networks formed per medium type. Source nodes inject fluid up to network capacity. Sink nodes drain.
4. Freeze check (every 1s): tile temperature read via `Tilemap.getTemp`. If below freeze threshold: `frozenTime += dt`. Throughput reduction per stage. Burst check → spill entity + repair task + node removal.
5. Spill entity: `tempDelta` applied to nearby tiles (thermal impact), `pollutionRate` added to pollution, `toxicRadius` applies status effect to nearby colonists, fuel spill → `Fire.ignite`.
6. `processorSystem` (priority 30, ECS.update): per powered processor:
   - Power check via `machine.powered`
   - steam_boiler: check tile temp ≥ 50°C, drain tile heat
   - `Pipes.hasFluid(x, y, inputFluid, needed, medium)` → `Pipes.consumeFluid`
   - `Pipes.injectFluid(x, y, outputFluid, rate×dt, outputMedium)` — produced fluid enters network
   - Waste fluid injected into waste medium
   - CO2 emission pending `Atmosphere.injectCO2`
7. Fluid in network is available to downstream sinks (machines consuming fluid, tanks storing it).
8. Tank equalization: tanks push/pull 5 units/s when level > 50% capacity.

**Key files**: `src/logistics/pipes.lua`, `src/logistics/pipe_processors.lua`, `src/logistics/pipe_defs.lua`, `src/building/building.lua`

### Chain 5: Colony Morale → Hope/Discontent → Mental Breaks → Policies

1. `needsDecaySystem` (priority 10): morale = `(warmth + food + rest) / 3` + trait modifiers + room quality + hypothermia penalty + lighting penalty. Written to `needs.morale`.
2. `mental_breaks` (priority 12): when `colonist.sanity ≤ 0` (sanity degrades when morale persistently low), picks break type by trait: pyromaniac, coward, glutton, berserk. Applies duration and effects. Martial law policy blocks break (sets sanity=30 instead).
3. Stress reactions (morale < 30, 0.1%/tick): complaining bubble, slacking (50% work speed), crying (stand still).
4. `Hope.step(dt)`: hope drifts toward 50, discontent toward 20. Events from colonist deaths, builds, meals applied as deltas. `getWorkSpeedMods` in work_ai reads stress reactions.
5. Despair (hope < 20 for 3+ game-days): lowest-morale colonist leaves.
6. Revolt (discontent > 80 for 2+ days): `Hope.isRevoltActive()` returns true. `work_ai` checks this at top of WORK block — forces idle state for all colonists for revolt duration.
7. Player responds via Policies: `Policies.apply(policyId)` — examples: martial_law (blocks mental breaks, discontent cap set), food_rationing (reduces food drain, discontent+5/day), communal_meals (hope+3/day), open_borders (recruitment boost).
8. `Policies.step(dt)`: applies ongoing policy effects each tick. Policy cooldowns prevent spam.
9. Laws (permanent colony decisions): `Laws.apply(lawId)` — examples: cannibalism (enables human_meat food, hope-3 cap removed), organ_harvesting (enables surgery on prisoners), execution (enables colonist execution dark action).

**Key files**: `src/colonist/colonist.lua`, `src/colonist/mental_breaks.lua`, `src/colony/hope.lua`, `src/colony/policies.lua`, `src/colony/laws.lua`

### Chain 6: Research → Unlocks → New Buildings/Recipes

1. Player designates colonist to research via work priority matrix (sets `workPriority.research = 1`).
2. `Jobs.step` ensures research bench has a `research` task. Bench must be built and powered.
3. `work_ai`: colonist enters research bench, calls `Research.addPoints(skillLevel × dt × speedMult)`.
4. `bench.lua` ECS system (priority ~50): also directly increments research progress if colonist is assigned.
5. `Research.addPoints`: adds to `progress`. When `progress ≥ node.cost`: `completed[nodeId] = true`, reset `current` and `progress`, return `true, finishedNode`.
6. `research.lua` calls `Research.onComplete(nodeId)` which sets unlock flags.
7. On next build menu open: `UI` calls `Research.isBuildingUnlocked(defId)` — hides/shows buildings. `Production.getRecipesForMachine` filters via `Research.isRecipeUnlocked`.
8. Player can now place newly unlocked buildings (e.g., drug_lab after pharmacology, refinery after fluid_systems) and assign newly unlocked recipes to machines.

**Key files**: `src/research/research.lua`, `src/research/bench.lua`, `src/building/building.lua`, `src/building/production.lua`

---

## Part 6: Save/Load Cycle

### What Is Saved (`src/persistence/save.lua`)

**Serialized data**:
- `GameState` fields: all resource counts, phase, colony name, speed, simTick, day, hour, globalTemp, windChill, baseTemp, mapWidth, mapHeight, scenario, startX/Y, selected entities, build mode state
- Tilemap: `tiles[]` flat array (tile types), `temps[]` flat array (temperatures per tile)
- ECS entities: all 37 KNOWN_COMPONENTS scanned per entity. Entities with at least one known component are serialized with all their component data.
- Weather: current type, timeRemaining, transition alpha, particle state
- Storyteller: event log, threat level, next event timer
- Hope system: hope, discontent, despairDays, revoltDays, revoltActive, memorials, log
- Zones: all zone designations with tile lists and types
- Placed buildings: building def IDs and positions (for heat source restoration)
- Tutorial flag
- 13 additional system states: laws, factions, perks, megabeasts, history, vehicles, strangeMoods, raids (raidsSurvived + raidLog), spoilage, elasticDifficulty, merchants, policies, pipes (getState/loadState)

**KNOWN_COMPONENTS** (37 components): colonist, needs, pos, path, creature, inventory, schedule, workPriority, machine, generator, consumer, conduit, bed, decoration, turret, trap, cover, shield, pipe_node, tank, processor, machine_hub, reactor, steam_hub, disease, crop, zone_marker, item, equipment, away, slave, prisoner, body, wounds, ranged, status_effect, addictions.

### What Is Rebuilt After Load (not saved)

- **Power grid**: `Power.init()` called after load. Grid topology rebuilt from `conduit` components of ECS entities. Generators and consumers re-registered from `generator`/`consumer` components.
- **Pathfinding grid**: rebuilt from tilemap tile data.
- **ECS systems**: `ECS.init()` clears ALL registered systems. `Save.load()` explicitly calls `registerSystems()` on ~30 modules to re-register every ECS system.
- **Occupancy map**: rebuilt by `Occupancy.rebuild()` on first tick after load.
- **Thermal room detection**: next `Thermal.step` re-runs flood-fill room detection.

### What Is Lost (known gaps)

- **Conveyor belt grid**: belt grid is module-local in `conveyors.lua` and is NOT serialized. After load, the belt network is empty until belts are rebuilt by the player.
- **Task queue**: all active tasks are lost. Colonist `_haulTaskId` fields are explicitly cleared on items after load. New tasks are generated naturally within 10s as `Jobs.step` runs.
- **Active raid state**: only `raidsSurvived` and `raidLog` persist. An in-progress raid does not resume after load.
- **Sound state**: ambient tracks restart from beginning.
- **Particle systems**: weather particles restart empty, repopulate within seconds.

### Load Sequence Detail

1. `loadstring` deserializes save string in sandboxed environment (`setfenv(fn, {})`).
2. `GameState` fields restored.
3. `World.init(w, h)` re-runs tilemap generation — then immediately overwrites `tiles[]` and `temps[]` arrays with saved data.
4. `ECS.init()` — clears ALL entities and systems.
5. ECS entity restoration loop: for each saved entity, `ECS.spawn()` to get same (or new) ID, then `ECS.set(id, comp, data)` for each saved component.
6. All 30 `registerSystems()` calls re-register ECS systems in priority order.
7. System-specific restore calls: `Weather.loadState`, `Storyteller.loadState`, `Hope.loadState`, `Zones.loadState`, `Buildings.loadState` (restores heat sources), `Raids.restoreState`, `Spoilage.loadState`, `Elastic.loadState`, `Merchants.loadState`, `Policies.loadState`, `Pipes.loadState`.
8. Stale `_haulTaskId` cleared from all item entities.
9. `GameState.phase = 'playing'`.

---

## Essential Files Reference

| File | Role |
|---|---|
| `F:\IceRimworld\main.lua` | Entry point, game loop, exact sim tick order |
| `F:\IceRimworld\src\game_state.lua` | Global state singleton, resources, clock |
| `F:\IceRimworld\src\ecs\ecs.lua` | Sparse-set ECS engine |
| `F:\IceRimworld\src\colonist\colonist.lua` | Colonist spawn, needsDecaySystem, movementSystem, death |
| `F:\IceRimworld\src\colonist\work_ai.lua` | All task execution logic |
| `F:\IceRimworld\src\colonist\jobs.lua` | Task queue, findBestTask, designation helpers |
| `F:\IceRimworld\src\sim\thermal.lua` | Jacobi heat diffusion, room detection |
| `F:\IceRimworld\src\sim\power.lua` | Union-find power grid, 22 generator types |
| `F:\IceRimworld\src\sim\disease.lua` | Disease ECS systems, immunity race |
| `F:\IceRimworld\src\sim\raids.lua` | Raid phases, heat signature, budget, prisoner capture |
| `F:\IceRimworld\src\colony\hope.lua` | Hope/discontent dual meters, revolt, despair |
| `F:\IceRimworld\src\colony\policies.lua` | Policy system |
| `F:\IceRimworld\src\building\building.lua` | 100+ building defs, tryPlace dispatcher |
| `F:\IceRimworld\src\building\production.lua` | 52 items, 30 recipes, machine ECS system, autoStock |
| `F:\IceRimworld\src\logistics\pipes.lua` | Dual union-find pipe networks, freeze, spill |
| `F:\IceRimworld\src\logistics\pipe_defs.lua` | Fluid/gas/pipe/processor definitions |
| `F:\IceRimworld\src\logistics\pipe_processors.lua` | ECS processor system |
| `F:\IceRimworld\src\research\research.lua` | 35-node research tree, unlock checks |
| `F:\IceRimworld\src\combat\combat_ai.lua` | Fight-or-flee, ranged/melee execution |
| `F:\IceRimworld\src\combat\wounds.lua` | Wound application and treatment |
| `F:\IceRimworld\src\creatures\creatures.lua` | Species catalog, creatureAI, natural spawn |
| `F:\IceRimworld\src\colonist\mental_breaks.lua` | Break types, stress reactions |
| `F:\IceRimworld\src\colonist\slavery.lua` | Prisoner conversion, slave work, dark actions |
| `F:\IceRimworld\src\exploration\expeditions.lua` | Off-map expeditions, outcome math |
| `F:\IceRimworld\src\persistence\save.lua` | Serialization, KNOWN_COMPONENTS, load sequence |
| `F:\IceRimworld\src\weather\weather.lua` | 7 weather types, transitions, particle system |
| `F:\IceRimworld\src\ui\input.lua` | All player input translation |
| `F:\IceRimworld\src\ui\ui.lua` | Resource bar, selection panel, menu stack |
| `F:\IceRimworld\src\colonist\schedule.lua` | 24-hour schedule blocks |