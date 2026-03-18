# FROSTHOLD — Development Phases

┌──────────────────────────────────┬──────────┬─────────────────────────────────────────────────────────────────────────┐
│            System                │ Priority │                             Description                               │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Game loop + ECS                  │ Phase 1  │ Fixed 20Hz timestep, sparse-set ECS, deferred destroy          (DONE) │
│ Tilemap + terrain gen            │ Phase 1  │ 128x128 chunk grid, 16 tile types, Perlin noise procedural     (DONE) │
│ Thermal diffusion                │ Phase 1  │ Per-tile heat spread, insulation, room detection, heat sources  (DONE) │
│ Colonist spawning + needs        │ Phase 1  │ Names, skills, 4 needs (warmth/food/rest/morale), death         (DONE) │
│ A* pathfinding                   │ Phase 1  │ Binary heap, occupancy avoidance, group spread                  (DONE) │
│ Camera + renderer                │ Phase 1  │ WASD/edge/drag pan, zoom, tile render, thermal overlay          (DONE) │
│ UI framework                     │ Phase 1  │ Resource bar, time/speed, selection panel, build mode            (DONE) │
│ Building placement               │ Phase 1  │ Walls, floors, doors, campfire, heater — tile swap + cost       (DONE) │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Weather                          │ Phase 2  │ 7 types (clear→blizzard→whiteout), transitions, snow particles  (DONE) │
│ Creatures                        │ Phase 2  │ 9 species, 3 tiers, flee/chase/attack AI, thermal core drops    (DONE) │
│ Storyteller AI                   │ Phase 2  │ 3 personalities, threat budgeting, 9 event types, event toast   (DONE) │
│ Ad-lib generation                │ Phase 2  │ Syllable names, backstories, 28 traits, event flavor templates  (DONE) │
│ Production chains                │ Phase 2  │ 52 items, 30 recipes, 14 machines, input/output buffers         (DONE) │
│ Power grid                       │ Phase 2  │ Union-find connectivity, 5 generators, fuel drain, brownout     (DONE) │
│ Drug system                      │ Phase 2  │ 5 drugs with real effects (stim, painkiller, warmth, berserker) (DONE) │
│ Occupancy                        │ Phase 2  │ No entity overlap, path avoidance, reserve/release per step     (DONE) │
│ Trait effects                    │ Phase 2  │ Cold resist, food drain, morale shift, speed, work speed, sanity(DONE) │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Work priority system             │ Phase 3  │ Player-configurable priority matrix per colonist (1-4 or off)   (DONE) │
│ Job/task queue                   │ Phase 3  │ Mine, build, haul, operate, cook, hunt, research, medical, clean(DONE) │
│ Zone designations                │ Phase 3  │ Stockpiles with item filters, dumping zones, restricted areas   (DONE) │
│ Hauling system                   │ Phase 3  │ Ground → stockpile, stockpile → machine input, output → stockpile(DONE)│
│ Scheduling                       │ Phase 3  │ 24hr blocks: work/eat/sleep/free — per-colonist configurable    (DONE) │
│ Bed assignment + sleep           │ Phase 3  │ Beds as entities, assigned colonist, rest recovery when sleeping(DONE) │
│ Food consumption                 │ Phase 3  │ Eat task during eat block, food quality → morale, dining area   (DONE) │
│ Item entities                    │ Phase 3  │ Dropped items on ground, carried items, stockpile storage       (DONE) │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Air quality / O2                 │ Phase 4  │ Per-room O2 depletion, CO2 from colonists + machines + generators(DONE)│
│ Generator CO2 / faults           │ Phase 4  │ Faulty generators emit extra CO2, risk of gas leak events       (DONE) │
│ Ventilation buildings            │ Phase 4  │ Intake vent (cold+O2), exhaust vent (CO2 out), air purifier     (DONE) │
│ Suffocation + stale air          │ Phase 4  │ O2 < 60% → work debuff, O2 < 30% → health drain, 0% → death   (DONE) │
│ Room requirements                │ Phase 4  │ Barracks needs beds, kitchen needs stove, workshop needs bench  (DONE) │
│ Room quality                     │ Phase 4  │ Size + floor + temp + air quality + furniture → morale modifier (DONE) │
│ Lighting system                  │ Phase 4  │ Darkness penalty, torch/lamp buildings, light radius per tile   (DONE) │
│ Foraging                         │ Phase 4  │ Tile-based resource discovery, skill-gated, cooldown per tile   (DONE) │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Body part injuries               │ Phase 5  │ Head/torso/arms/legs, targeted damage, part-specific consequences(DONE)│
│ Wound types + treatment          │ Phase 5  │ Cuts, burns, frostbite, fractures — bandage → medicine → surgery(DONE) │
│ Creature lairs                   │ Phase 5  │ Destructible worldgen spawners, timed creature waves, raid source(DONE)│
│ Noise / detection                │ Phase 5  │ Activity noise radius, wall dampening, creature aggro on noise  (DONE) │
│ Hunting tasks                    │ Phase 5  │ Designate creature, colonist equips weapon + pursues with AI    (DONE) │
│ Ranged combat                    │ Phase 5  │ Frost rifle, hunting bow — projectile entities, range/accuracy  (DONE) │
│ Combat AI                        │ Phase 5  │ Flee vs fight based on traits + equipment + health, formation   (DONE) │
│ Colonist weapons + armor         │ Phase 5  │ Equipment slots, damage reduction, weapon damage types          (DONE) │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Hope / Discontent                │ Phase 6  │ Colony-wide dual meters, event-driven, despair/revolt countdowns(DONE) │
│ Policy / law system              │ Phase 6  │ Permanent colony modifiers with trade-offs (extended shifts, etc)(DONE)│
│ Mental break expansion           │ Phase 6  │ Trait-specific: pyromaniac fires, coward flees, glutton binges  (DONE) │
│ Social relationships             │ Phase 6  │ Opinion scores, friends/rivals, social fights, death grief      (DONE) │
│ Addiction system                 │ Phase 6  │ Repeated drug use → dependency → withdrawal → need + health drain(DONE)│
│ Stress reactions                 │ Phase 6  │ Minor disruptions at morale < 30, frequent but less catastrophic(DONE) │
│ Funeral / memorial               │ Phase 6  │ Colonist death → hope hit, build memorial → partial hope recovery(DONE)│
│ Contraband / drug theft          │ Phase 6  │ Certain traits steal drugs from storage during free time        (DONE) │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Conveyor belts                   │ Phase 7  │ Directional tile transport, item buffers, splitters, freezing   (DONE) │
│ Inserters / loaders              │ Phase 7  │ Belt ↔ machine input/output, auto-feed production chains        (DONE) │
│ Pipe / fluid network             │ Phase 7  │ Water transport, coolant loops, waste — clone of power grid     (DONE) │
│ Research tree                    │ Phase 7  │ 5 tiers, prerequisite graph, unlocks recipes + buildings        (DONE) │
│ Research bench + task            │ Phase 7  │ Machine type, colonist operates, progress bar, discovery events (DONE) │
│ Thermal waste / pollution        │ Phase 7  │ Industrial output attracts creatures, tile degradation in radius(DONE) │
│ Belt freezing                    │ Phase 7  │ Uninsulated belts freeze, items stop — reason to enclose factori(DONE) │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Expedition system                │ Phase 8  │ Send colonists off-map, timed return, random event resolution   (DONE) │
│ Overworld map                    │ Phase 8  │ Simplified expedition destinations with risk/reward descriptions (DONE) │
│ Thermal suit / exosuit           │ Phase 8  │ Late-game craftable, halves cold drain, doubles damage, needs fu(DONE) │
│ Deep drilling                    │ Phase 8  │ Access resources beneath permafrost/rock, requires research     (DONE) │
│ Megafauna boss encounters        │ Phase 8  │ Scripted multi-phase fights, unique drops, storyteller-triggered (DONE) │
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ Save / load                      │ Phase 9  │ Serialize ECS + tilemap + game state to disk, load on startup   (DONE) │
│ Deterioration / maintenance      │ Phase 9  │ Buildings decay over time + weather, repair tasks, efficiency los(DONE) │
│ Room decorations                 │ Phase 9  │ Shelves, rugs, paintings → room quality bonus                   (DONE) │
│ Minimap                          │ Phase 9  │ Corner overlay showing terrain, buildings, entities             (DONE) │
│ Sound / music                    │ Phase 9  │ Ambient wind, blizzard audio, UI sounds, creature calls         (DONE) │
│ Proper sprite art                │ Phase 9  │ Replace placeholder rectangles/circles with actual sprites      (TODO) │
│ Tutorial                         │ Phase 9  │ Guided first 10 minutes, contextual tooltips                   (DONE) │
│ Difficulty settings              │ Phase 9  │ Storyteller + base temp + creature aggression + resource scarcity(DONE)│
├──────────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────────────────┤
│ P2P / LAN multiplayer            │ Phase 10 │ lua-enet networking, state sync, host authority                 (DONE) │
│ Shared colony control            │ Phase 10 │ Multiple players managing same colony                           (DONE) │
│ Trade between colonies           │ Phase 10 │ Inter-colony resource exchange, caravan mechanic                (DONE) │
└──────────────────────────────────┴──────────┴─────────────────────────────────────────────────────────────────────────┘

## File Inventory (63 Lua source files)

### Core (Phase 1)
- `main.lua` — Entry point, game loop, system wiring
- `conf.lua` — LÖVE2D configuration
- `src/ecs/ecs.lua` — Sparse-set ECS engine
- `src/game_state.lua` — Global state singleton
- `src/world/tilemap.lua` — 128x128 tilemap + terrain gen
- `src/world/tiles.lua` — 16 tile type definitions
- `src/sim/thermal.lua` — Thermal diffusion + room detection
- `src/sim/power.lua` — Union-find power grid
- `src/render/camera.lua` — Camera pan/zoom
- `src/render/renderer.lua` — World + entity rendering
- `src/ui/input.lua` — Mouse/keyboard input
- `src/ui/ui.lua` — UI overlay panels
- `src/util/pathfind.lua` — A* pathfinding
- `src/util/occupancy.lua` — Entity occupancy tracking
- `src/building/building.lua` — Building defs + placement

### Phase 2
- `src/weather/weather.lua` — Weather state machine + particles
- `src/creatures/creatures.lua` — 9 species, AI behaviors
- `src/storyteller/storyteller.lua` — Event director AI
- `src/util/adlib.lua` — Name/backstory/trait generation
- `src/building/production.lua` — 52 items, 30 recipes, 14 machines

### Phase 3 — Core Autonomy
- `src/colonist/colonist.lua` — Colonist spawning + needs decay
- `src/colonist/jobs.lua` — Job/task queue + priority system
- `src/colonist/schedule.lua` — 24-hour schedule blocks
- `src/colonist/work_ai.lua` — Work AI (schedule→task→execute)
- `src/world/zones.lua` — Zone designations (stockpile/dumping)
- `src/world/items.lua` — Ground item entities
- `src/building/beds.lua` — Bed entities + assignment

### Phase 4 — Environment
- `src/sim/atmosphere.lua` — Per-room O2/CO2
- `src/sim/lighting.lua` — Per-tile light levels
- `src/world/rooms.lua` — Room type detection + quality
- `src/colonist/foraging.lua` — Tile-based resource gathering

### Phase 5 — Combat
- `src/combat/body.lua` — Body part system (6 parts)
- `src/combat/wounds.lua` — Wound types + treatment
- `src/combat/ranged.lua` — Projectile combat
- `src/combat/combat_ai.lua` — Fight/flee AI
- `src/combat/hunting.lua` — Hunting task execution
- `src/colonist/equipment.lua` — Weapon/armor slots
- `src/creatures/lairs.lua` — Creature lair spawners

### Phase 6 — Morale
- `src/colony/hope.lua` — Hope/discontent meters
- `src/colony/policies.lua` — Colony policy system
- `src/colonist/mental_breaks.lua` — Trait-specific breaks
- `src/colonist/social.lua` — Social relationships
- `src/colonist/addiction.lua` — Drug addiction/withdrawal

### Phase 7 — Logistics
- `src/logistics/conveyors.lua` — Conveyor belt system
- `src/logistics/inserters.lua` — Machine loaders
- `src/logistics/pipes.lua` — Fluid transport network
- `src/research/research.lua` — 20-node research tree
- `src/research/bench.lua` — Research bench ECS system
- `src/sim/pollution.lua` — Industrial pollution

### Phase 8 — Exploration
- `src/exploration/expeditions.lua` — Off-map expeditions
- `src/exploration/overworld.lua` — 8 expedition destinations
- `src/colonist/suits.lua` — Thermal suit/exosuit
- `src/building/deep_drill.lua` — Deep resource drilling
- `src/creatures/bosses.lua` — 3 megafauna boss encounters

### Phase 9 — Polish
- `src/persistence/save.lua` — Save/load serialization
- `src/sim/deterioration.lua` — Building decay + repair
- `src/building/decorations.lua` — Room decoration items
- `src/ui/minimap.lua` — Corner minimap overlay
- `src/audio/sound.lua` — Sound manager + categories
- `src/ui/tutorial.lua` — Step-based tutorial
- `src/ui/difficulty.lua` — Difficulty presets

### Phase 10 — Multiplayer
- `src/net/network.lua` — lua-enet P2P networking
- `src/net/shared_control.lua` — Shared colony control
- `src/net/trade.lua` — Inter-colony trade
