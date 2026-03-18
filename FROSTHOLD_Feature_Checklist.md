# FROSTHOLD — Feature & Mechanics Testing Checklist

**Frostpunk x RimWorld Colony Survival Sim**
**Love2D 11.4 | Lua 5.1/LuaJIT | 1280x720**
**Generated: 2026-03-16**

> This document lists every game feature and mechanic with its implementation status
> and testable acceptance criteria. Use the "Done" column to track QA passes.

---
## 1. CORE GAME LOOP

### Game States (6)

| Done | State | Test |
|------|-------|------|
| | Start Menu | Menu loads, buttons respond, new game starts |
| | Planet Selection | 7 planet cards display, arrow keys browse, enter confirms |
| | World Map (Hex) | Hex grid generates per-planet, landing zone selectable, info panel shows biome/resources/threat |
| | Colonist Drafting | Draft screen shows, colonists selectable, game begins |
| | Playing | Simulation runs, all systems ticking, input responsive |
| | Game Over | Triggers on all-dead, shows stats, restart/quit works |

### Time & Tick (5)

| Done | Feature | Test |
|------|---------|------|
| | 20Hz fixed timestep | Simulation advances at consistent rate regardless of FPS |
| | Pause (Space) | All simulation stops, UI still responsive, unpause resumes |
| | Speed 1x (key 1) | Normal game speed |
| | Speed 2x (key 2) | Double speed, all systems scale correctly |
| | Speed 3x (key 3) | Triple speed, no desync or skipped events |

### Camera (6)

| Done | Feature | Test |
|------|---------|------|
| | WASD/arrow pan | Camera moves in all 4 directions |
| | Scroll wheel zoom | Zoom in/out with limits, centered on cursor |
| | Edge-of-screen pan | Camera moves when cursor touches window edges |
| | Window resize | Camera adjusts, no rendering artifacts, min 960x540 |
| | Jump to entity | Click alert or colonist bar -> camera centers on target |
| | Minimap click | Click minimap -> camera jumps to that position |

---
## 2. PLAYER CONTROLS & INPUT

### Selection (6)

| Done | Feature | Test |
|------|---------|------|
| | Left-click select colonist | Single colonist selected, info panel opens |
| | Drag-box select | Green rectangle selects multiple colonists in area |
| | Shift+click add to selection | Adds/removes colonists from current selection |
| | N key cycle | Cycles through colonists alphabetically |
| | Click building | Building selected, inspection panel opens |
| | Click empty tile | Deselects current selection |

### Designation Tools (6)

| Done | Tool | Key | Test |
|------|------|-----|------|
| | Build Mode | B | Opens build menu, categories visible, buildings selectable |
| | Mine Designate | M | Drag marks tiles, blue overlay, colonists queue mining |
| | Stockpile Zone | Z | Drag paints zone, items get hauled to it |
| | Dumping Zone | X | Drag paints zone, waste hauled there |
| | Deconstruct | D | Drag marks buildings, colonists queue deconstruction |
| | Forage Designate | F | Drag marks tiles, colonists queue foraging |

### Context Menu (6)

| Done | Target | Test |
|------|--------|------|
| | Right-click colonist | Menu shows: medical, inspect options |
| | Right-click creature | Menu shows: hunt, force attack |
| | Right-click building | Menu shows: inspect, repair, deconstruct, set recipe |
| | Right-click item | Menu shows: haul, force eat, force haul |
| | Right-click rock/tree | Menu shows: force mine, force chop |
| | Right-click tile (drafted) | Selected colonist moves to tile |

### Hotkeys (16)

| Done | Key | Action | Test |
|------|-----|--------|------|
| | ESC | Cancel/menu | Cancel build -> exit build mode -> pause menu |
| | TAB | Minimap toggle | Minimap appears/disappears at bottom-right |
| | F1 | Tutorial toggle | Tutorial panel shows/hides |
| | F2 | Thermal overlay | Heat map overlay visible on tiles |
| | F3 | Pollution overlay | Pollution levels visible |
| | F4 | Debug overlay | FPS, tick, entity counts, temperatures, power |
| | F5 | Quick save | Save toast appears, file written |
| | F9 | Quick load | Load toast appears, game state restored |
| | R | Research panel | Full-screen tech tree opens/closes |
| | P | Policy panel | Policy toggles open/close |
| | T | Trade panel | Merchant trade UI opens/closes |
| | E | Expedition view | Expedition map view opens/closes |
| | G | Farm panel | Farm management opens/closes |
| | V | Equipment panel | Gear assignment opens/closes |
| | H | Medical panel | Medical overview opens/closes |
| | C | Colony panel | Colony roster opens/closes |
| | L | Event log | Event history panel opens/closes |
| | Q | Quest panel | Quest tracker opens/closes |

---
## 3. UI PANELS

### Top Bar (5)

| Done | Element | Test |
|------|---------|------|
| | Resource display | Thermal Cores, Wood, Stone, Metal, Food, Water, Fuel with tooltips |
| | Research status | Current research name + progress bar |
| | Temperature display | Colony effective temp shown, updates with conditions |
| | Day/time display | Day counter + HH:MM advances correctly |
| | Speed buttons | 1x/2x/3x + pause clickable, visual feedback on active |

### Colonist Bar (4)

| Done | Element | Test |
|------|---------|------|
| | Colonist cards | All living colonists shown with health/morale bars |
| | Status icons | Mental break (!), disease (+), injured (*), hungry (~), drafted (D), hypothermia (#) |
| | Card click | Selects colonist, opens info panel |
| | Hover tooltip | Shows name, HP, needs, status, current task |

### Alert System (15)

| Done | Alert | Test |
|------|-------|------|
| | FIRE | Appears on active fires, click jumps to fire |
| | RAID INCOMING | Appears when raid starts, click jumps to raid |
| | LOW FOOD | Triggers below food threshold |
| | LOW WATER | Triggers below water threshold |
| | LOW FUEL | Triggers below fuel threshold |
| | HYPOTHERMIA | Appears when colonist is hypothermic |
| | SUFFOCATION | Appears on low O2 |
| | IDLE COLONISTS | Shows count of idle workers |
| | SICK | Appears on active disease |
| | MENTAL BREAK | Appears on breakdown |
| | REVOLT | Appears on high discontent |
| | POWER OUTAGE | Appears on brownout |
| | CRITICAL HEALTH | Appears on near-death colonist |
| | STARVATION | Appears on starving colonist |
| | HOPE CRITICAL | Appears on dangerously low hope |

### Colonist Info Panel — 9 Tabs (9)

| Done | Tab | Test |
|------|-----|------|
| | Needs | 5 need bars (warmth/food/water/rest/morale) with values, traits, backstory |
| | Health | Body parts list (HP/max), wounds, disease, hypothermia, addictions |
| | Social | Relationships list with opinion values, color-coded friend/rival |
| | Work | Priority matrix (10 jobs x 4 levels), skills list with levels |
| | Schedule | 24hr blocks (work/eat/sleep/free), clickable to change |
| | Gear | Weapon/armor/accessory slots, equip/unequip |
| | Bio | Backstory, traits, personality |
| | Combat | Combat skills, history |
| | Log | Personal event history |

### Build Menu (5)

| Done | Feature | Test |
|------|---------|------|
| | 10 build categories | Structure/Heating/Power/Lighting/Air/Production/Colony/Logistics/Logic/Defense |
| | Building cards | Show name, cost breakdown, power draw |
| | Affordability color | Green = affordable, red = too expensive |
| | Click to select | Ghost overlay appears on map at cursor |
| | R to rotate | Direction cycles right->down->left->up |

### Building Inspection (6)

| Done | Feature | Test |
|------|---------|------|
| | Name + description | Building name and desc shown on selection |
| | Durability bar | HP bar with numeric value |
| | Machine status | Recipe, progress %, power status |
| | Reactor status | Power level, fuel %, overdrive, stress % |
| | Steam hub status | Active/inactive indicator |
| | Battery charge | Charge % with bar |

### Full-Screen Panels (8)

| Done | Panel | Key | Test |
|------|-------|-----|------|
| | Research | R | 5-tier tree, click to select/begin, cancel button, progress bar |
| | Policies | P | Toggle laws on/off, effects summary (work speed, food drain, morale) |
| | Trade | T | Buy/sell items, thermal cores currency, merchant info + timer |
| | Farm | G | Farm plots, growth status, crop picker, planting |
| | Equipment | V | Colonist gear assignment, 3 slots, equip/unequip |
| | Medical | H | Wound list, disease, surgery queue, body part HP |
| | Colony | C | Full roster, sortable columns, click to select/center |
| | Expedition | E | Off-map tilemap, fog of war, POI markers, progress |

### Pause Menu (4)

| Done | Feature | Test |
|------|---------|------|
| | ESC opens menu | Shows PAUSED, colony info, day count |
| | Resume button | Unpauses game |
| | Save/Load buttons | F5/F9 equivalent from menu |
| | Quit button | Returns to main menu or exits |

---
## 4. PLANET SYSTEM

### Planet Selection UI (7)

| Done | Feature | Test |
|------|---------|------|
| | 7 planet cards render | All 7 planets shown as horizontal cards with color, name, subtitle, difficulty badge |
| | Arrow key browsing | Left/right arrows cycle through unlocked planets |
| | Mouse click selection | Click planet card selects it |
| | Planet descriptions | Extended description shown for selected planet at bottom |
| | Difficulty badges | Standard/Easy/Hard/Very Hard/Extreme/Narrative labels correctly colored |
| | Locked planet handling | Locked planets show "Coming Soon" overlay, not selectable |
| | Configure Deployment button | Confirm advances to world_map phase with correct planet |

### Planet Definitions (7)

| Done | Planet | Difficulty | Test |
|------|--------|------------|------|
| | Erebus (Frozen World) | Standard | All nil overrides, falls through to defaults, 6 scenarios |
| | Rhea-2 (Scorched Desert) | Hard | Heat/water management, twin suns, 3 scenarios |
| | Morvos (Acid World) | Very Hard | Corrosion, toxic atmosphere, 2 scenarios |
| | Nerthus-9 (Ocean World) | Hard | Pressure, flooding, underwater, 2 scenarios |
| | Paxtera Prime (Temperate) | Easy | Mild seasons, standard colony sim, 5 scenarios |
| | Nemaea (Dead World) | Extreme | Vacuum, radiation, automatons, 2 scenarios |
| | Gaia A^1x (Fall of Fortuna) | Narrative | Baldrungen escalation, fixed ending, 1 scenario |

### World Map / Hex Grid (8)

| Done | Feature | Test |
|------|---------|------|
| | Hex grid generation | Radius-3 grid (37 hexes) generated with planet-specific biomes |
| | Biome assignment | Weighted noise-based biome picking from planet palette |
| | Resource distribution | Sparse/normal/rich assigned per hex from noise + biome bias |
| | Threat levels | Low/medium/high/extreme assigned per hex, edges higher |
| | Temperature modifier | Biome properties set temp modifier per hex |
| | Elevation | 0-1 elevation from noise displayed per hex |
| | Info panel | Right-side panel shows biome name, temp, elevation, resources, threat |
| | Confirm Landing Zone | Selected hex stores landingZone on GameState, advances to drafting |

### Per-Planet Biomes (35)

| Done | Planet | Biomes | Test |
|------|--------|--------|------|
| | Erebus | Tundra, Glacier, Volcanic, Frozen Marsh, Frozen Forest | 5 biomes with correct colors and weights |
| | Rhea-2 | Dune Sea, Canyon, Oasis, Badlands, Salt Flat | 5 biomes, desert palette |
| | Morvos | Acid Basin, Fungal Grove, Rock Platform, Toxic Marsh, Spore Field | 5 biomes, acid palette |
| | Nerthus-9 | Volcanic Island, Coral Reef, Active Volcano, Deep Ocean, Atoll | 5 biomes, ocean palette |
| | Paxtera Prime | Grassland, Forest, Farmland, Hills, Wetland | 5 biomes, temperate palette |
| | Nemaea | Crater Field, Dyson Ruins, Irradiated Wastes, Ship Wreckage, Regolith Plains | 5 biomes, dead world palette |
| | Gaia A^1x | Meadow, Dense Forest, Corrupted Zone, River Valley, Highlands | 5 biomes, lush+corrupt palette |

### Per-Planet Seasons (28)

| Done | Planet | Seasons | Test |
|------|--------|---------|------|
| | Erebus | Deep Winter / Late Winter / Thaw / Freeze | Default 15-day seasons, existing behavior |
| | Rhea-2 | Scorching (55C) / Dry (35C) / Dust Storm (40C) / Cool (20C) | 15-day desert seasons, starts in Dry |
| | Morvos | Acid Rain / Toxic Calm / Spore Bloom / Corrosion Peak | 20-day acid seasons, starts in Toxic Calm |
| | Nerthus-9 | Monsoon / Low Tide / Storm Season / Calm Waters | 18-day ocean seasons, starts in Low Tide |
| | Paxtera Prime | Spring (12C) / Summer (25C) / Autumn (10C) / Winter (-5C) | 15-day temperate seasons, starts in Spring |
| | Nemaea | Solar Maximum (120C) / Eclipse (-80C) / Solar Minimum (5C) / Debris Season (-20C) | 30-day extreme seasons, starts in Solar Minimum |
| | Gaia A^1x | Spring (15C) / Summer (28C) / Autumn (8C) / Corruption (-5C) | 15-day seasons with narrative escalation, starts in Spring |

### Per-Planet Atmosphere (7)

| Done | Planet | O2/CO2 | Test |
|------|--------|--------|------|
| | Erebus | 100/0 (breathable) | Default atmosphere |
| | Rhea-2 | 100/0 (breathable) | Desert but breathable |
| | Morvos | 70/15 (toxic) | Reduced O2, CO2 buildup, sealed rooms needed |
| | Nerthus-9 | 100/0 (breathable) | Surface breathable, underwater needs O2 |
| | Paxtera Prime | 100/0 (breathable) | Standard atmosphere |
| | Nemaea | 0/0 (vacuum) | No atmosphere, sealed habs + suits mandatory |
| | Space | 0/0 (vacuum) | Ship-only atmosphere |

### Per-Planet Secrets (7)

| Done | Planet | Secret Types | Test |
|------|--------|-------------|------|
| | Erebus | Frozen colonist, thing mimic, precursor artifact, sealed cache, dormant nest | Default secrets |
| | Rhea-2 | Buried Cryopod, Sandstone Cache, Sun Shrine, Sand Wurm Nest | 4 desert secrets |
| | Morvos | Sealed Pod, Toxic Cache, Spore Node, Corrosion Nest | 4 acid secrets |
| | Nerthus-9 | Sunken Pod, Coral Cache, Depth Beacon, Kraken Nest, BioVault Vessel, Mammona Rig, Sunken Lab, Cargo Boat, Trawler, Patrol Boat, Lifeboat, Freighter | 12 ocean secrets |
| | Paxtera Prime | Abandoned Shelter, Supply Drop, Old Bunker, Wildlife Den | 4 temperate secrets |
| | Nemaea | Automaton Pod, Dyson Cache, Signal Beacon, Drone Nest | 4 dead world secrets |
| | Gaia A^1x | Forest Shelter, Growth Cache, Corruption Node, Husk Nest | 4 Baldrungen secrets |

### Per-Planet Tuning (7)

| Done | Planet | Raid/Weather Tuning | Test |
|------|--------|---------------------|------|
| | Erebus | Default tuning | Baseline difficulty |
| | Rhea-2 | Budget base 25, +2.5/day; harshness 0.6-2.2 | Hot raids, harsh weather |
| | Morvos | Budget base 20, +1.5/day; harshness 0.8-2.5 | Lower raid frequency, extreme weather |
| | Nerthus-9 | Budget base 25, +2/day; harshness 0.5-2.0 | Standard raids with flooding |
| | Paxtera Prime | Budget base 25, +2/day; harshness 0.3-1.5 | Easy weather |
| | Nemaea | Budget base 40, +3/day; harshness 1.0-3.0; human_chance=0 | Automaton-only raids, extreme |
| | Gaia A^1x | Budget base 20, +4/day; swarm_chance 2x; harshness 0.3-2.0 | Escalating insectoid swarms |

---
## 5. PER-PLANET MECHANICS

### Rhea-2 Heat Management (4)

| Done | Feature | Test |
|------|---------|------|
| | Daytime surface temp 55C (scorching) | Colonists take heat damage outdoors during scorching season |
| | Underground base temp 25C | Underground provides shelter from heat |
| | Night operations | Daylight hours extended (5-21 in scorching), night is safer |
| | Water scarcity | Oasis tiles as water sources, condensation traps functional |

### Morvos Corrosion System (6)

| Done | Feature | Test |
|------|---------|------|
| | Planet check | Corrosion system activates only when GameState.planet == 'morvos' |
| | Outdoor corrosion | Buildings outdoors lose 0.1 durability/sec |
| | Indoor unsealed corrosion | Indoor unsealed buildings lose 0.03 durability/sec |
| | Sealed room immunity | Buildings in sealed rooms take no corrosion damage |
| | Weather multiplier | Acid storm and corrosive fog double corrosion rate (2x) |
| | Season multiplier | Corrosion peak season doubles corrosion regardless of weather |
| | Building destruction | Buildings at 0 durability destroyed and entity removed |

### Nerthus-9 Underwater Pressure (8)

| Done | Feature | Test |
|------|---------|------|
| | Planet check | Pressure system activates only on nerthus_9 |
| | Depth-based pressure | 1.0 pressure per depth level, linear scaling |
| | Surface safe | Depth 0 or above has zero pressure |
| | Sealed room protection | Enclosed rooms with no flooding negate pressure |
| | Suit resistance | Diving suit pressure rating reduces effective pressure (0-100%) |
| | Pressure damage | 0.15 HP/sec per unit of unresisted pressure |
| | Crush threshold | Pressure above 4.0 causes rapid death (2.0 HP/sec per unit) |
| | Cause of death | Crush deaths log as 'pressure_crush' |

### Nerthus-9 Flooding (4)

| Done | Feature | Test |
|------|---------|------|
| | Flow rate 2.0 | Water flows between tiles at 2x normal rate on Nerthus-9 |
| | Evaporation rate 0.3 | Slow evap in ocean environment |
| | Monsoon floods | Monsoon season weather bias heavily favors heavy_rain + storms with flooding |
| | Hurricane flooding | Hurricane weather type sets floods=true, injects water into outdoor tiles |

### Nemaea Vacuum & Radiation (6)

| Done | Feature | Test |
|------|---------|------|
| | No atmosphere | O2 = 0, CO2 = 0; colonists suffocate without sealed habs |
| | Ambient radiation | 0.02 dose/tick; lethal dose 5.0 |
| | Temperature extremes | Solar Maximum 120C, Eclipse -80C |
| | No organic wildlife | All creatures are mechanical automatons |
| | No hermes system | hermes.enabled = false |
| | Dyson Sphere themes | Solar flare, meteor shower, radiation burst weather unique to Nemaea |

### Gaia A^1x Baldrungen Escalation (10)

| Done | Feature | Test |
|------|---------|------|
| | Planet check | Baldrungen system activates only when GameState.planet == 'gaia_a1x' |
| | Corruption season detection | Season transition to 'corruption' increments corruption cycles |
| | Cycle 1 waves | 2-4 husk_crawlers spawn from map edges |
| | Cycle 2 waves | 3-5 mixed husk_crawlers + bone_beetles |
| | Cycle 3 waves | 4-7 mixed crawlers + beetles + rot_wasps |
| | Cycle 4+ waves | 6-10+ massive swarms with brood_mothers and the_emergence |
| | Spawn timer | 30-60s random interval between wave spawns during corruption |
| | Artifact shielding | 3 contained artifacts create ward, cap spawn intensity at cycle 3 |
| | Final cycle (5) | Baldrungen fully awakens; if shielded, colony survives; if not, game enters 'baldrungen_fall' mode |
| | Alerts | Corruption Wave/Baldrungen Swarm/The Emergence alerts fire at appropriate severity |

### Paxtera Prime Temperate Colony (3)

| Done | Feature | Test |
|------|---------|------|
| | Mild seasons | Spring 12C to Winter -5C; nothing like Erebus extremes |
| | Human-centric raids | Standard raid system with all factions active |
| | Full scenario selection | 5 scenarios available (crashlanded, lone_wanderer, lost_tribe, rich_explorer, naked_brutality) |

### Space (Non-Starting Planet) (3)

| Done | Feature | Test |
|------|---------|------|
| | Not selectable as starting planet | scenarios = {} prevents selection |
| | Vacuum environment | O2 = 0, outdoor temp snap 1.0, underground base temp -270C |
| | Ambient radiation | 0.01 dose, lethal 5.0 |

---
## 6. COLONIST SYSTEMS

### Needs (5)

| Done | Need | Test |
|------|------|------|
| | Warmth | Decays when cold, satisfied by heated rooms, hypothermia stages trigger |
| | Food | Decays over time, colonist seeks food, starvation -> death |
| | Water | Decays over time, colonist seeks water |
| | Rest | Decays over time, colonist seeks bed, exhaustion effects |
| | Morale | Affected by environment, social, events, triggers mental breaks at low |

### Hypothermia (5 stages)

| Done | Stage | Threshold | Test |
|------|-------|-----------|------|
| | Normal | >= 60 warmth | No effects |
| | Chilled | >= 40 | Minor speed penalty |
| | Cold | >= 20 | Moderate penalty, alert shows |
| | Hypothermic | >= 10 | Severe penalty, health damage |
| | Severe | < 10 | Near-lethal, rapid health loss |

### Work Priority System (10 job types)

| Done | Job | Test |
|------|-----|------|
| | Mining | Colonist mines designated tiles, yields resources |
| | Building | Colonist constructs placed blueprints |
| | Hauling | Colonist moves items to stockpiles |
| | Operating | Colonist operates production machines |
| | Cooking | Colonist uses kitchen to make meals |
| | Hunting | Colonist targets designated creatures |
| | Research | Colonist works at research bench, progress advances |
| | Medical | Colonist treats wounded/sick colonists |
| | Cleaning | Colonist cleans filthy areas |
| | Firefighting | Colonist auto-extinguishes active fires |

### Scheduling (4)

| Done | Block | Test |
|------|-------|------|
| | Work | Colonist performs assigned job priorities |
| | Eat | Colonist seeks food during eat blocks |
| | Sleep | Colonist seeks assigned bed |
| | Free | Colonist satisfies needs or idles |

### Skills & XP (10)

| Done | Skill | Test |
|------|-------|------|
| | Mining | Levels up from mining, affects speed |
| | Building | Levels up from construction, affects speed/quality |
| | Cooking | Levels up from cooking, affects food quality |
| | Medical | Levels up from treatment, affects success rate |
| | Combat | Levels up from fighting, affects hit chance/damage |
| | Research | Levels up from bench work, affects research speed |
| | Farming | Levels up from farm work, affects growth/yield |
| | Crafting | Levels up from crafting, affects quality |
| | Passion system | Interested (1.5x XP) / Passionate (2x XP) visible and working |
| | Skill rust | Unused skills get -20% effectiveness, clears after 3 uses |

### Traits & Backstories (3)

| Done | Feature | Test |
|------|---------|------|
| | Trait generation | Colonists spawn with random traits from adlib.lua |
| | Trait effects | Traits modify needs/work/combat/social as defined |
| | Backstory generation | Colonists get procedural backstories from adlib system |

### Scar Traits (10)

| Done | Scar | Trigger | Test |
|------|------|---------|------|
| | frostblood | Survive hypothermia | +cold resistance permanent |
| | battle_hardened | Survive raid at low HP | +combat mod permanent |
| | iron_stomach_scar | Survive starvation | +food efficiency permanent |
| | plague_immune | Survive disease | +disease immunity permanent |
| | mental_resilience | Survive mental break | +morale stability permanent |
| | efficient_metabolism | Survive long hunger | +food mod permanent |
| | deep_scars | Major wound recovery | Stat modification permanent |
| | pyromaniac_reformed | Survive pyro break | Pyro trait removed permanent |
| | blizzard_walker | Survive whiteout | +speed in snow permanent |
| | Other scars | Various hardships | Verify each trigger fires correctly |

### Draft Mode (3)

| Done | Feature | Test |
|------|---------|------|
| | Draft toggle | Selected colonist enters manual control |
| | Move command | Right-click tile -> colonist moves there |
| | Attack command | Right-click creature -> colonist attacks |

---
## 7. SOCIAL & MORALE

### Social System (5)

| Done | Feature | Test |
|------|---------|------|
| | Opinion matrix | Symmetric opinions between colonist pairs (-100 to +100) |
| | Proximity gain | Opinion increases when colonists are near each other |
| | Friends (>50) | Morale buff when friend is nearby |
| | Rivals (<-30) | Morale penalty, fight chance when adjacent |
| | Grief | -20 morale for 2 days when friend dies |

### Hope & Discontent (6)

| Done | Feature | Test |
|------|---------|------|
| | Hope meter (0-100) | Visible in UI, drifts toward 50 |
| | Discontent meter (0-100) | Visible in UI, drifts toward 20 |
| | Death impact | Colonist death drops hope by ~15 |
| | Good events raise hope | Good meal, building, etc. raise hope |
| | Despair tracking | Extended low hope -> colony-wide mental breakdown |
| | Revolt tracking | Extended high discontent -> colonist rebellion |

### Mental Breaks (8)

| Done | Break | Test |
|------|-------|------|
| | Pyromaniac | Low morale -> colonist starts fires |
| | Coward | Stress -> colonist flees, hides |
| | Glutton | Stress -> colonist binge eats food stores |
| | Berserk | Stress -> colonist attacks others |
| | Ruin drawn | Stress -> colonist wanders toward map edge |
| | Signal listener | Stress -> colonist fixates, stops working |
| | Quarantine panic | Stress -> colonist panics, runs |
| | Break recovery | Breaks have duration, colonist returns to normal |

### Addiction & Drugs (8)

| Done | Drug | Test |
|------|------|------|
| | Spike | Drug consumed, effects applied, addiction risk |
| | Stardust | Drug consumed, effects applied, addiction risk |
| | Drift | Drug consumed, effects applied, addiction risk |
| | Smog | Drug consumed, effects applied, addiction risk |
| | Shards | Drug consumed, effects applied, addiction risk |
| | Glimpse | Drug consumed, effects applied, addiction risk |
| | Surge | Drug consumed, effects applied, addiction risk |
| | Voidbloom | Drug consumed, effects applied, addiction risk |
| | Withdrawal | Addicted colonist without drug suffers penalties |

### Policies (6)

| Done | Policy | Test |
|------|--------|------|
| | Extended Shifts | Toggle on -> work speed up, morale down |
| | Rationing | Toggle on -> food consumption down, morale down |
| | Martial Law | Toggle on -> discontent suppressed, hope penalty |
| | Emergency Protocol | Toggle on -> emergency effects active |
| | Quota Compliance | Toggle on -> production bonus, morale cost |
| | Blackout Protocol | Toggle on -> heat signature reduced, warmth penalty |

---
## 8. BUILDING & CONSTRUCTION

### Placement (6)

| Done | Feature | Test |
|------|---------|------|
| | Ghost preview | Semi-transparent building follows cursor |
| | Cost check | Red ghost if resources insufficient |
| | Collision check | Cannot place on occupied tiles |
| | Multi-tile buildings | Large buildings (reactor 3x3) place correctly |
| | Line placement | Pipes/belts/walls support drag-line placement |
| | Build task created | Colonist queues construction after placement |

### Building Categories — Verify All Buildable (10)

| Done | Category | Count | Test |
|------|----------|-------|------|
| | Structure | 11 | Walls, floors, doors, columns all placeable and functional |
| | Heating | 3 | Campfire, heater, steam hub produce heat |
| | Power | 35+ | All generators produce power when fueled/conditions met |
| | Lighting | 3 | Torch, lamp, sun lamp illuminate areas |
| | Ventilation | 4 | Air intake/exhaust/purifier/scrubber affect room atmosphere |
| | Production | 14 | All machines accept recipes and produce items |
| | Colony | 2+ | Cloning vat, radio beacon, beds, memorial functional |
| | Logistics | 13+ | Conveyors, inserters, pipes, tanks placeable and transport |
| | Defense | 25+ | Turrets, traps, fortifications, laser fences placeable |
| | Endgame | 4 | Victory buildings constructible |

### Production Machines (14)

| Done | Machine | Test |
|------|---------|------|
| | Sawmill | Raw wood -> lumber |
| | Smelter | Raw ore -> metal ingots |
| | Forge | Metal -> steel, components, tools |
| | Kitchen | Raw food -> cooked meals |
| | Workbench | General crafting recipes |
| | Loom | Fiber/hide -> cloth |
| | Tannery | Raw hides -> leather |
| | Smokehouse | Meat -> jerky |
| | Drug Lab | Herbs -> drugs/medicine |
| | Butcher Table | Corpses -> meat + hide |
| | Refinery | Raw materials -> fuel |
| | Oil Refinery | Crude oil -> fuel |
| | Med Bench | Herbs -> medicine/bandages |
| | Vehicle Workbench (CUT) | Archived stub. Vehicles are not in shipped scope. |

### Recipe Selection (2)

| Done | Feature | Test |
|------|---------|------|
| | Right-click machine -> set recipe | Recipe list appears, selection applies |
| | Machine produces selected recipe | Inputs consumed, outputs created, progress visible |

### Recreation Buildings (6)

| Done | Building | Test |
|------|----------|------|
| | Bonfire | Outdoor gathering, 6 capacity, heat+light output, 0.08 joy/tick |
| | Card Table | 2 capacity, social bonds, 0.12 joy/tick |
| | Tavern Bar | 4 capacity, consumes food, 0.15 joy/tick |
| | Sparring Ring | 2 capacity, trains combat, 0.10 joy/tick |
| | Library | 3 capacity, boosts research, 0.06 joy/tick |
| | Radio Set | 4 capacity, plays music, 0.10 joy/tick, requires 5W power |

### Storage Buildings (7)

| Done | Building | Test |
|------|----------|------|
| | Crate | Basic wood storage, no protection |
| | Locker | Metal, insulated storage |
| | Shelf | Wide wall-mounted, open storage |
| | Chest | Sealed metal, weather-protected |
| | Cold Storage Unit | Powered refrigeration, 20W draw |
| | Lead-lined Vault | Radiation-shielded hazmat storage |
| | Bulk Silo | 3x3 enormous capacity for single category |

### Misc Buildings (7)

| Done | Building | Test |
|------|----------|------|
| | Medical Bench | Crafts medicine and medical supplies |
| | Deep Drill | Automated deep extraction, 50W, attracts creatures |
| | Expedition Table | Plan and launch off-map expeditions |
| | Quest Board | Post and track colony objectives |
| | Cryo Pod | Suspends colonist indefinitely, 25W draw |
| | Scrubber | Reduces pollution in nearby tiles, 20W draw |
| | Sump Pump | Drains water from flooded rooms, 15W draw |

### Containment Buildings (2)

| Done | Building | Test |
|------|----------|------|
| | Containment Cell | Powered quarantine for live subjects, 22W draw |
| | Anomaly Locker | Cold storage for artifacts and sealed anomaly samples, 12W draw |

### Structural Support (3)

| Done | Building | Test |
|------|----------|------|
| | Wood Column | Cheap support, 8-tile span, degrades over time |
| | Stone Column | Durable, 14-tile span, no degradation |
| | Reinforced Column | Maximum support, 26-tile span |

---
## 9. UNDERWATER & OCEAN BUILDINGS (Nerthus-9)

### Pressure Infrastructure (7)

| Done | Building | Test |
|------|----------|------|
| | Airlock | Sealed transition chamber, cycles open/closed, 10W draw |
| | Pressure Dome | 3x3 sealed dome, pushes water out of 5x5 area, 40W draw |
| | Diving Bell | 2x2 descent chamber, refills suit O2, 25W draw |
| | Submersible | Sealed pod, carries 2 between depths, pressure-rated, 35W draw |
| | Electrolyzer (O2 Gen) | Splits water into breathable oxygen, 30W draw |
| | Bilge Pump | High-capacity water extraction, 25W draw |
| | Condensation Trap | Passive clean water collection, no power |

### Underwater Habitats (5)

| Done | Building | Test |
|------|----------|------|
| | Underwater Habitat | 2x2 sealed quarters, insulated, 15W draw |
| | Hab Pod | 1x1 compact sealed pod for one colonist, 8W draw |
| | Hab Block | 3x3 large sealed habitat module, 25W draw |
| | Sealed Wall | Pressure-rated wall, blocks water/gas |
| | Glass Dome | Transparent pressure dome, morale bonus, blocks water/gas |

### Floating Surface Structures (4)

| Done | Building | Test |
|------|----------|------|
| | Pontoon Platform | Floating wood platform, extends buildable area over water |
| | Reinforced Dock | Metal-braced floating platform, supports heavier buildings |
| | Fishing Platform | 2x1 floating nets, generates food passively from water tiles |
| | Tidal Generator | 2x2 ocean current power, 70W output |

### Underwater Production (4)

| Done | Building | Test |
|------|----------|------|
| | Kelp Farm | 2x1 underwater hydroponics, grows kelp for food/biomass, 10W draw |
| | Desalination Unit | Converts seawater to fresh water, 20W draw |
| | Seabed Drill | 2x2 underwater mining rig, 60W draw, attracts predators, underwaterOnly |
| | Thermal Vent Tap | 2x2 taps volcanic vent, 110W output + heat |

### Underwater Power (2)

| Done | Building | Test |
|------|----------|------|
| | Thermal Vent Tap | Taps ocean floor volcanic vent, 110W, some heat |
| | Current Turbine | Underwater turbine, 45W constant output from currents |

---
## 10. WEATHER SYSTEM

### Erebus Weather (7 types)

| Done | Weather | Test |
|------|---------|------|
| | Clear | Normal conditions, full visibility |
| | Overcast | -5C temp, 0.85 visibility, light precip |
| | Snowfall | -10C temp, 0.6 visibility, snow particles |
| | Blizzard | -25C temp, 0.2 visibility, lightning |
| | Whiteout | -35C temp, 0.05 visibility, lethal |
| | Warm Front | +15C temp, rain, golden tint |
| | Aurora | -5C, 0.95 visibility, morale buff, shimmer effect |

### Rhea-2 Desert Weather (3 types)

| Done | Weather | Test |
|------|---------|------|
| | Sandstorm | +10C, 0.1 visibility, 0.9 solar penalty, orange-brown tint |
| | Heat Wave | +20C, 0.85 visibility, no solar penalty |
| | Dust Devil | +5C, 0.6 visibility, 0.2 solar penalty |

### Morvos Acid Weather (4 types)

| Done | Weather | Test |
|------|---------|------|
| | Acid Storm | -5C, 0.15 visibility, 0.85 solar penalty, 2x corrosion |
| | Corrosive Fog | 0C, 0.25 visibility, 1.5x corrosion |
| | Toxic Haze | +3C, 0.5 visibility, green tint |
| | Spore Cloud | +2C, 0.4 visibility, yellow-green tint |

### Nerthus-9 Ocean Weather (3 types)

| Done | Weather | Test |
|------|---------|------|
| | Hurricane | -8C, 0.08 visibility, floods, 3x wind, lightning |
| | Heavy Rain | -3C, 0.35 visibility, floods |
| | Storm | -5C, 0.3 visibility, 2x wind, lightning |

### Paxtera/Gaia Temperate Weather (2 types)

| Done | Weather | Test |
|------|---------|------|
| | Rain | -2C, 0.7 visibility, light precipitation |
| | Spore Fall (Gaia only) | -3C, 0.35 visibility, corruption-themed |

### Nemaea Dead World Weather (3 types)

| Done | Weather | Test |
|------|---------|------|
| | Solar Flare | +40C, 0.7 visibility, bright orange overlay |
| | Meteor Shower | -10C, 0.5 visibility, structural damage |
| | Radiation Burst | +5C, 0.8 visibility, pale green glow, radiation dose |

### Weather Mechanics (6)

| Done | Feature | Test |
|------|---------|------|
| | Markov transitions | Weather changes via weighted transition table |
| | Seasonal bias | Season affects weather probability weights |
| | Planet-specific merging | Planet weather types merge into base type table at init |
| | Harshness scaling | Severe weather duration scales with harshness, calm weather inversely |
| | Weather particles | Type-specific colored particles (snow=white, sand=orange, acid=green, rain=blue) |
| | Weather overlays | Type-specific screen-space tints render correctly |

### Blood Rain (special)

| Done | Feature | Test |
|------|---------|------|
| | Blood Rain weather type | +5C temp, 0.55 visibility, crimson tint, heavy flooding |
| | Easter egg trigger | First rain event becomes blood rain if Fischbach colonist exists |
| | Blood rain particles | Vertical red streak particles render |

---
## 11. THERMAL & ENVIRONMENT

### Thermal Diffusion (5)

| Done | Feature | Test |
|------|---------|------|
| | Room temperature | Enclosed rooms have distinct temperatures |
| | Heat sources | Campfire/heater/reactor raise room temp |
| | Wall insulation | Insulated walls retain heat better than wood/stone |
| | Wind chill | Outdoor tiles affected by weather wind |
| | Thermal overlay (F2) | Heat map visible, hot=red, cold=blue |

### Generator / Reactor (6)

| Done | Feature | Test |
|------|---------|------|
| | Placement | 3x3 reactor places correctly |
| | 4 power levels | Each level increases heat + fuel consumption |
| | Fuel consumption | Fuel depletes, reactor shuts off when empty |
| | Overdrive | Activates, stress climbs, increased output |
| | Meltdown | Stress reaches 100% -> explosion, damage radius, hope penalty |
| | Steam hubs | Extend reactor heat to distant tiles |

### Atmosphere (5)

| Done | Feature | Test |
|------|---------|------|
| | Per-room O2/CO2 | Rooms track gas levels independently |
| | CO2 buildup | Sealed rooms with fire/colonists accumulate CO2 |
| | Suffocation | Low O2 damages colonists, alert triggers |
| | Air intake | Pulls outside air into room |
| | Air purifier | Filters CO2, requires power |

### Lighting (3)

| Done | Feature | Test |
|------|---------|------|
| | Dark rooms | Rooms without light sources have darkness penalty |
| | Light sources | Torch/lamp illuminate radius, penalty removed |
| | Sun lamp | Enables crop growth indoors |

### Seasons — Erebus Default (4)

| Done | Season | Temp | Test |
|------|--------|------|------|
| | Deep Winter | -60C | 15 days, lowest temps, reduced raids |
| | Late Winter | -45C | 15 days |
| | Thaw | -15C | 15 days, meltwater floods possible, forage bonus |
| | Freeze | -30C | 15 days, temps dropping again |

---
## 12. POWER SYSTEM

### Power Grid (6)

| Done | Feature | Test |
|------|---------|------|
| | Union-find connectivity | Buildings on same grid share power |
| | Consumer priority | Critical/normal/low priority shedding during brownout |
| | Brownout | Insufficient power -> low-priority buildings shut off |
| | Power conduits | Connect distant buildings to same grid |
| | Power switch | Toggle isolates grid sections |
| | Battery charge/discharge | Batteries store excess, release during deficit |

### Power Generators (35)

| Done | Generator | Output | Test |
|------|-----------|--------|------|
| | Campfire | 10W | Burns raw_wood |
| | Coal Burner | 30W | Burns coal |
| | Thermal Generator | 80W | Burns thermal_core |
| | Fuel Cell Generator | 50W | Burns fuel_cell |
| | Lava Vent Tap | 100W | No fuel, placed on vent |
| | Solar Panel | 40W | Intermittent solar |
| | Tracking Solar Array | 65W | Intermittent solar |
| | Concentrated Solar | 100W | Intermittent solar |
| | Wind Turbine | 55W | Intermittent wind |
| | Large Wind Turbine | 90W | Intermittent wind |
| | Advanced Turbine | 130W | Intermittent wind |
| | Geothermal Vent | 120W | No fuel |
| | Gas Burner | 45W | Burns coal, high CO2 |
| | Nuclear Reactor | 250W | Burns thermal_core, meltdown risk |
| | Chemical Burner | 60W | Burns components |
| | Bio Reactor | 35W | Burns food |
| | Mini Reactor | 90W | Burns thermal_core, minor meltdown risk |
| | Steam Turbine | 65W | Intermittent heat |
| | Hand Crank | 12W | Manned, no fuel |
| | Treadmill | 25W | Manned, forced labor |
| | Chain Gang Wheel | 50W | Manned, forced labor, 3 crew |
| | Waste Incinerator | 40W | Burns corpses, high CO2+heat |
| | Hydrogen Fuel Cell | 70W | Intermittent water |
| | Lightning Rod | 200W | Intermittent storm |
| | Thermopile | 25W | Intermittent thermal diff |
| | Ichor Burner | 55W | Burns eldritch_ichor |
| | Cryo-Kinetic Engine | 60W | Intermittent cold |
| | Methane Digester | 40W | Burns food, produces heat |
| | Plasma Arc Reactor | 180W | Burns steel, meltdown risk, massive heat |
| | Stirling Engine | 45W | Intermittent thermal diff |
| | Penrose Engine | 100W | Endgame exotic, no fuel |
| | Dynamo | 20W | Manned, any worker |
| | Peat Burner | 25W | Burns any, produces heat |
| | Fusion Reactor | 400W | Endgame, no fuel, minor meltdown risk |
| | Ichor Converter | 40W | Byproduct processor |
| | Fuel Generator | 60W | Burns refined fuel |
| | Tidal Generator | 70W | Intermittent water, ocean surface |
| | Thermal Vent Tap | 110W | No fuel, ocean floor |
| | Current Turbine | 45W | Intermittent water, underwater |

---
## 13. COMBAT & DEFENSE

### Melee Combat (4)

| Done | Feature | Test |
|------|---------|------|
| | Melee attack | Colonist/creature deals damage on adjacent tile |
| | Weapon damage | Equipped weapon modifies damage output |
| | Body part targeting | Hits land on specific body parts |
| | Armor absorption | Equipped armor reduces incoming damage |

### Ranged Combat (5)

| Done | Feature | Test |
|------|---------|------|
| | Projectile firing | Colonist/turret fires projectile at target |
| | Hit probability | Affected by skill, distance, cover |
| | Cover system | Fortifications reduce hit chance on defenders |
| | Weapon types | Bow/crossbow/revolver/rifle each have distinct stats |
| | Ammo consumption | Ranged weapons consume correct ammo type |

### Body & Wounds (5)

| Done | Feature | Test |
|------|---------|------|
| | 6 body parts | Head, torso, L/R arm, L/R leg tracked independently |
| | Wound types | Cuts, burns, frostbite, fractures applied correctly |
| | Wound treatment | Medical colonist treats wounds, reduces infection |
| | Bleeding | Untreated wounds cause ongoing health loss |
| | Part destruction | Body part at 0 HP -> disability/death |

### Turrets — Spot Check (5)

| Done | Turret | Test |
|------|--------|------|
| | Ballista | Fires heavy bolts, no power, slow |
| | Gun turret | Standard turret, requires power, auto-targets |
| | Foam nozzle | Extinguishes fires in area, uses foam canisters |
| | Tesla coil | Chain lightning, hits multiple targets |
| | Mortar | Long range explosive, manual reload |

### Traps — Spot Check (5)

| Done | Trap | Test |
|------|------|------|
| | Spike trap | Damages creature on walkover, rearms |
| | Bear trap | Immobilizes + damages |
| | Incendiary trap | Sets area on fire on trigger |
| | EMP mine | Electromagnetic burst on trigger |
| | Snare trap | Holds small creatures |

### Fortifications (4)

| Done | Cover | Test |
|------|-------|------|
| | Sandbag | 40% cover, cheap |
| | Barricade | 60% cover |
| | Steel barrier | 75% cover |
| | Bunker | 85% cover |

---
## 14. RAIDS & THREATS

### Raid System (5)

| Done | Feature | Test |
|------|---------|------|
| | Heat signature scaling | Reactor + colonists + cores -> raid budget |
| | Raid spawning | Enemies spawn from map edges |
| | Retreat mechanic | Raiders flee at 50% casualties (except swarms) |
| | Raid alert | RAID INCOMING alert triggers, clickable |
| | Post-raid effects | Hope/discontent shift, prisoner capture |

### Raid Types (4)

| Done | Type | Test |
|------|------|------|
| | Beast assault | Creature wave attacks colony |
| | Siege | Enemies build up before attacking |
| | Coordinated | Multi-direction organized attack |
| | Swarm (day 30+) | 3x budget, all 4 directions, no retreat |

### Humanoid Raiders (3 factions)

| Done | Faction | Test |
|------|---------|------|
| | Outlaw raiders | Thug/brawler/gunner/marksman species spawn |
| | Scavenger raiders | Militia/scrapper/sharpshooter species spawn |
| | Mammona/MasTema | Enforcer/heavy/operative/sniper/breacher spawn |

### Creature Threats (4)

| Done | Feature | Test |
|------|---------|------|
| | Natural spawning | Creatures appear at map edges scaled to difficulty/day |
| | Creature AI states | Idle->wander->flee->chase->attack transitions |
| | Lair spawning | Lairs periodically spawn creatures nearby |
| | Aggression range | Creatures aggro within defined radius, leash back |

---
## 15. DISEASE & MEDICAL

### Diseases (5)

| Done | Disease | Test |
|------|---------|------|
| | Frostlung | Contracts from cold exposure, severity races immunity |
| | Blackrot | Severity vs immunity race, symptoms apply debuffs |
| | Ice Plague | Contagious, spreads to nearby colonists |
| | Tissue Creep | Contracts, progresses, treatable |
| | Spore Sickness | Contracts, progresses, treatable |

### Medical Mechanics (5)

| Done | Feature | Test |
|------|---------|------|
| | Immunity race | Severity vs immunity both tick toward 100 |
| | Treatment | Medical colonist treats -> boosts immunity, slows severity |
| | Lethality | Lethal diseases kill if severity hits 100 first |
| | Symptom debuffs | Sick colonists have work speed/morale penalties |
| | Reinfection window | Recently recovered colonists have temporary immunity |

### Surgery (5)

| Done | Feature | Test |
|------|---------|------|
| | Prosthetic install | Peg leg, wooden arm installable on surgery table |
| | Bionic install | Bionic leg/arm/eye installable, stat bonuses |
| | Organ harvest | Heart/lung/kidney/liver/eye harvestable (hope penalty) |
| | Amputation | Damaged limbs removable |
| | Surgery risk | Low medical skill -> failure chance -> additional wounds |

---
## 16. LOGISTICS & AUTOMATION

### Conveyors (4)

| Done | Feature | Test |
|------|---------|------|
| | Belt transport | Items move along belt in placed direction |
| | Splitter | Alternates output between two belts |
| | Belt freezing | Belts below -20C stop moving items |
| | Belt + inserter chain | Items flow from belt -> inserter -> machine |

### Inserters (3)

| Done | Type | Test |
|------|------|------|
| | Basic inserter | Moves items between belt and machine, slow |
| | Fast inserter | 2x speed of basic |
| | Filter inserter | Only moves specified item types |

### Pipe Network (6)

| Done | Feature | Test |
|------|---------|------|
| | Fluid transport | Pipes carry water/oil/ichor/fuel/coolant/waste |
| | Gas transport | Ducts carry oxygen/co2/steam/toxic_gas |
| | Tank storage | Fluid/gas tanks store and equalize |
| | Pipe freezing | Pipes freeze below threshold -> burst -> spill |
| | Insulated pipes | Resist freezing |
| | Dual union-find | Fluid and gas networks independent |

### Pipe Processors (7)

| Done | Processor | Test |
|------|-----------|------|
| | Water pump | Extracts water from ice tiles |
| | Oil refinery | Processes crude oil into fuel |
| | Coolant refiner | Produces coolant from materials |
| | Ichor converter | Processes eldritch ichor |
| | Waste processor | Breaks down industrial waste |
| | Gas separator | Separates gas mixtures |
| | Steam boiler | Generates steam from water + heat |

---
## 17. RESEARCH & PROGRESSION

### Research System (5)

| Done | Feature | Test |
|------|---------|------|
| | Research bench | Colonist works at bench, progress advances |
| | 5-tier tree | All 58 nodes visible, tier prerequisites enforced |
| | Node selection | Click node -> research begins, cancel button works |
| | Unlock effects | Completed research unlocks buildings/recipes/features |
| | Progress persistence | Research progress survives save/load |

### Research Tiers — Spot Check (5)

| Done | Tier | Sample Node | Test |
|------|------|-------------|------|
| | Tier 1 | basic_construction | Unlocks early buildings |
| | Tier 2 | agriculture | Unlocks farming buildings/crops |
| | Tier 3 | automation | Unlocks conveyors/inserters |
| | Tier 4 | missile_systems | Unlocks missile silo + warheads |
| | Tier 5 | shuttle_engineering | Unlocks launch_pad victory building |

---
## 18. TRADE & ECONOMY

### Merchant System (4)

| Done | Feature | Test |
|------|---------|------|
| | Merchant arrival | Storyteller triggers merchant visit |
| | Merchant types | Scavenger/equipment/exotic with distinct inventories |
| | Buy/sell | Player buys/sells via Trade panel, thermal cores as currency |
| | Departure timer | Merchant leaves after timer expires |

### Factions (5)

| Done | Faction | Test |
|------|---------|------|
| | Mammona Logistics | Reputation tracks, affects trade prices |
| | MasTema Ops | Reputation tracks, affects raid multiplier |
| | Scavenger Crews | Reputation tracks |
| | Ruin Delvers | Reputation tracks |
| | Rim Runners | Reputation tracks |
| | Reputation effects | Hostile (<-50) -> raids, Allied (>50) -> trade bonuses |

---
## 19. EXPLORATION & EXPEDITIONS

### Expedition System (5)

| Done | Feature | Test |
|------|---------|------|
| | Launch expedition | Select colonists + destination, expedition starts |
| | Per-planet destinations | Each planet has its own destination catalog |
| | Party composition | 1-3 colonists |
| | Success calculation | Skills + equipment + risk -> outcome tier |
| | Loot generation | Success returns resources/items to colony |

### Per-Planet Expedition Destinations (49)

| Done | Planet | Destinations | Test |
|------|--------|-------------|------|
| | Erebus | Frozen Wastes, Ice Caves, Predator Territory, Abandoned Outpost, Glacier Peak, Thermal Vents, Deep Rift, Precursor Site | 8 destinations with correct risk/reward |
| | Rhea-2 | Dune Sweep, Canyon Expedition, Oasis Search, Buried Ruins, Sun Temple, Deep Aquifer | 6 destinations with desert rewards |
| | Morvos | Acid Flats, Fungal Forest, Sealed Bunker, Spore Caves, Acid Lake Shore | 5 destinations with acid-themed rewards |
| | Nerthus-9 | Reef Dive, Island Hop, Shipwreck Dive, Deep Trench, Volcanic Vent | 5 destinations with ocean rewards |
| | Paxtera Prime | Meadow Forage, Forest Expedition, Hill Quarry, Raider Camp, Old Settlement | 5 destinations with temperate rewards |
| | Nemaea | Surface Sweep, Wreckage Field, Automaton Graveyard, Dyson Fragment, Deep Vault | 5 destinations with metal/component rewards |
| | Gaia A^1x | Meadow Gathering, River Valley, Deep Woods, Corruption Edge, Heart Chamber | 5 destinations with Baldrungen themes |

### Expedition View (4)

| Done | Feature | Test |
|------|---------|------|
| | Mini-tilemap | Expedition map visible in E panel |
| | Fog of war | Unrevealed areas dark, reveal on exploration |
| | POI markers | Entrance, loot, encounter, objective markers visible |
| | Progress timer | Countdown visible, expedition completes on finish |

### Vehicles (CUT FROM SCOPE)

| Done | Feature | Test |
|------|---------|------|
| | Vehicle construction (CUT) | Archived stub, not in shipped scope |
| | Expedition bonus (CUT) | Vehicle modifiers removed from expeditions |
| | Vehicle workbench (CUT) | Build flow removed from shipped scope |

---
## 20. CREATURES & WILDLIFE

### Creature Behavior (5)

| Done | Feature | Test |
|------|---------|------|
| | Spawning | Creatures appear at map edges, scaled by day/difficulty |
| | AI state machine | Idle->wander->flee->chase->attack works |
| | Pack behavior | Wolves/swarms move in groups |
| | Loot drops | Killed creatures drop meat/hide; special encounters can drop explicit salvage |
| | Corpse creation | Dead creatures leave corpses for butchering |

### Erebus Creatures (52 species)

| Done | Tier | Species (sample) | Count | Test |
|------|------|-------------------|-------|------|
| | Small | Frost Hare, Ice Fox, Snow Grouse, Cinder Mite, Heat Skipper | 5 | Flee on sight, low HP |
| | Medium | Tundra Wolf, Glacier Bear, Ice Stalker, Ice Brute, Snow Ape, Stalker, Shade, Dire Wolf, Mammoth, Sabertooth, Char Hound, Bore Beetle, Razorjaw, Spine Lurker | 14 | Aggressive, pack behavior where applicable |
| | Megafauna | Frost Titan, Thermal Wurm, Glacial Leviathan, Ancient Brute, Alpha Stalker, Mountain Titan, Ice Colossus, Storm Titan, Hive Matron, Gorge Worm, Iron Carapace | 11 | Multi-phase, high HP, boss mechanics |
| | Eldritch | The Hungering, The Pale Thing, That Which Sleeps, Fleshwalker, The Thermophage | 5 | Fear aura, night hunter, breach, extreme HP |
| | Eldritch Livestock | Gore Shoat, Weeping Calf, Husk Pup, Void Calf, Pit Wyrm, Bile Mold, Thorn Polyp, Nerve Cluster, Rot Bloom | 9 | Passive, eldritch types, grow into nodes |
| | Swarm | Frost Beetle, Ice Locust, Frost Wurm, Spawnling, Skitterer, Permafrost Rat, Nerve Worm, Nerve Tick | 8 | Pack spawns, no retreat, high aggro range |

### Rhea-2 Desert Creatures (12 species)

| Done | Tier | Species | Test |
|------|------|---------|------|
| | Small | Sand Lizard, Dust Scarab, Canyon Sparrow | Flee, heat resistant |
| | Medium | Dune Stalker, Sand Viper, Ridge Raptor, Sand Wurm, Sun Scorpion, Wasteland Hyena | Aggressive, heat resistant, breacher (sand wurm) |
| | Megafauna | Desert Colossus, Heat Drake, Dune Leviathan | Boss-tier, breacher, heat resistant |

### Morvos Acid Creatures (12 species)

| Done | Tier | Species | Test |
|------|------|---------|------|
| | Small | Acid Mite, Spore Crawler, Slime Beetle | Flee, acid immune |
| | Medium | Corrosion Hound, Acid Spitter, Fungal Stalker, Bile Brute, Caustic Wurm, Plague Carrier | Aggressive, acid immune, night hunter (fungal stalker) |
| | Megafauna | Acid Titan, The Dissolvent, Mire Colossus | Boss-tier, acid immune, breacher |

### Nerthus-9 Ocean Creatures (12 species)

| Done | Tier | Species | Test |
|------|------|---------|------|
| | Small | Tide Crab, Reef Fish, Kelp Drifter | Flee, aquatic |
| | Medium | Depth Lurker, Reef Shark, Pressure Eel, Kraken Spawn, Abyssal Hunter, Barnacle Titan Juvenile | Aggressive, aquatic, night hunter (abyssal hunter) |
| | Megafauna | Storm Leviathan, The Depth Mother, Tidal Colossus | Boss-tier, aquatic, breacher |

### Paxtera Prime Temperate Creatures (12 species)

| Done | Tier | Species | Test |
|------|------|---------|------|
| | Small | Field Hare, Grain Bird, Orchard Snake | Flee, temperate fauna |
| | Medium | Timber Wolf, Plains Bear, Wild Boar, Feral Bull, Apex Cat, Razorback Hog | Territorial, pack behavior, breacher (feral bull), night hunter (apex cat) |
| | Megafauna | Mammona Enforcer Mech, Great Elk, Territorial Megabear | Corporate mech + natural mega creatures |

### Nemaea Automaton Creatures (11 species)

| Done | Tier | Species | Test |
|------|------|---------|------|
| | Small | Scout Drone, Maintenance Bot | Mechanical, vacuum+radiation immune, drop components/metal |
| | Medium | Patrol Automaton, Enforcer Unit, Salvage Drone, Siege Automaton, Hunter-Killer, Containment Unit | Mechanical, no organic drops, breacher (siege), relentless pursuit (hunter-killer) |
| | Megafauna | Titan Automaton, The Warden, Dyson Sentinel | Boss-tier mechanical, breacher, fear aura (warden) |

### Gaia A^1x Creatures (12 species)

| Done | Tier | Species | Test |
|------|------|---------|------|
| | Small | Forest Rabbit, Songbird, Meadow Vole | Passive temperate fauna |
| | Medium (natural) | Timber Predator, Brook Bear, Grove Stalker | Pack hunter, territorial, night hunter |
| | Medium (Baldrungen) | Husk Crawler, Bone Beetle, Rot Wasp | Insectoid undead, no retreat, pack spawns, breacher (bone beetle) |
| | Megafauna | Brood Mother, The Emergence, Baldrungen Tendril | Massive insectoid horror spawns, breacher, fear aura |

### Xenolith Species (4)

| Done | Species | Test |
|------|---------|------|
| | Xenolith Queen | Eldritch-tier boss, 2000 HP, 50% armor, spawns 4 larvae on death, vacuum+radiation+acid immune |
| | Xenolith Drone | Megafauna, 300 HP, pack 2-5, vacuum+radiation immune |
| | Xenolith Larva | Swarm-tier, 40 HP, pack 4-10, matures into drone if not killed |
| | Xenolith Spore | Small passive, 15 HP, drifts and latches onto biomass |

### Lairs (3)

| Done | Feature | Test |
|------|---------|------|
| | Lair generation | Lairs placed during world gen |
| | Creature spawning | Lairs periodically spawn creatures nearby |
| | Lair destruction | Attacking lair destroys it, stops spawns |

### Taming (5)

| Done | Feature | Test |
|------|---------|------|
| | Tame attempt | Colonist attempts to tame wild creature |
| | Tame success | Skill check vs wildness -> creature becomes tamed |
| | Role assignment | Tamed animal assigned: livestock, hauler, guard |
| | Breeding | Tamed animals can breed (checkBreeding called) |
| | Resource yield | Livestock produce leather, meat |

---
## 21. TILE TYPES

### Base Tiles (17)

| Done | Tile | Test |
|------|------|------|
| | Void | Impassable border |
| | Snow | Walkable, buildable |
| | Ice | Walkable, not buildable |
| | Rock | Solid, minable |
| | Permafrost | Walkable, buildable |
| | Dirt | Exposed from heat, walkable, buildable |
| | Wood/Stone/Metal Floor | Walkable, insulated per material |
| | Wood/Stone/Metal Wall | Solid, insulation per material |
| | Door | Walkable, partial gas permeability |
| | Water | Not walkable |
| | Lava Vent | Natural heat source |
| | Debris | Walkable, buildable |
| | Tree | Solid, minable for wood |
| | Ore Vein | Solid, minable for metal |
| | Insulated Wall/Floor/Door | High insulation, sealed door blocks gas+water |

### Underground Tiles (14)

| Done | Tile | Test |
|------|------|------|
| | Deep Rock | Dense rock at edges, minable for stone |
| | Underground Rock | Excavatable cave stone |
| | Underground Floor | Walkable, buildable |
| | Shaft Entrance | Connects surface to underground |
| | Wood/Stone/Reinforced Column | Structural support with span 8/14/26 |
| | Fungal Floor/Wall | Bioluminescent shallow cave tiles |
| | Membrane Floor/Wall | Precursor mid-cave tiles |
| | Organ Floor/Wall | Deep cave pulsing organic tiles |
| | Growth Creep | Spreading biological growth |

### Vertical Connections (5)

| Done | Tile | Test |
|------|------|------|
| | Stair Down | Connects to layer below |
| | Stair Up | Connects to layer above |
| | Stairwell (Both) | Bidirectional |
| | Channel | Open pit, falling hazard |
| | Ramp Up | Low move cost upward connection |

### Natural Features (8)

| Done | Tile | Test |
|------|------|------|
| | Frozen River | Fishable, becomes water during thaw |
| | Geyser | Periodic steam + heat, radius 6, 40 power |
| | Hot Spring | Warm pool, morale bonus |
| | Frozen Lake | Fishable surface |
| | Frozen Sea | Walkable, not buildable |
| | Cave Entrance | Surface cave mouth, connects to depth 1 |
| | Tundra Marsh | Walkable, movement penalty 1.5x |
| | Volcanic Rock/Floor/Ash | Warm volcanic tiles |

### Lead Tiles (3)

| Done | Tile | Test |
|------|------|------|
| | Lead Wall | Radiation-shielded wall |
| | Lead Door | Radiation-shielded passage |
| | Lead Ore | Minable for lead |

### Desert Tiles — Rhea-2 (6)

| Done | Tile | Test |
|------|------|------|
| | Sand | Walkable, buildable, 1.3x move penalty |
| | Dune | Solid, excavatable for stone |
| | Sandstone | Solid, minable for stone |
| | Oasis | Water source, not walkable, fishable |
| | Cactus | Solid, choppable for food |
| | Cracked Earth | Walkable, buildable |

### Ocean Tiles — Nerthus-9 (5)

| Done | Tile | Test |
|------|------|------|
| | Ocean | Deep water, not walkable |
| | Shallows | Walkable (slow), fishable, 1.8x move penalty |
| | Coral | Solid, minable for stone |
| | Beach | Walkable, buildable |
| | Seaweed | Walkable, harvestable, 1.4x move penalty |

### Underwater Natural Resources (6)

| Done | Tile | Test |
|------|------|------|
| | Coral Deposit | Minable for stone + food bonus |
| | Mineral Nodule | Minable for metal (5 yield) |
| | Thermal Mineral | Minable for components (3 yield) |
| | Kelp Forest | Walkable, minable for food, 1.6x move penalty |
| | Sunken Wreck | Minable for metal (6) + components (2) bonus |
| | Brine Pocket | Minable for fuel (3 yield) |

### Floating/Underwater Construction (5)

| Done | Tile | Test |
|------|------|------|
| | Pontoon | Floating wood platform, 1.2x move penalty |
| | Dock | Reinforced floating platform |
| | Sealed Floor | Pressure-rated, blocks water/gas |
| | Sealed Wall | Pressure-rated, high insulation |
| | Glass Dome | Transparent, morale bonus, blocks water/gas |

### Temperate Tiles — Paxtera/Gaia (5)

| Done | Tile | Test |
|------|------|------|
| | Grass | Walkable, buildable |
| | Fertile Soil | Growth bonus 0.5, walkable, buildable |
| | Deciduous Tree | Solid, choppable for wood (4 yield) |
| | Bush | Walkable, harvestable, 1.2x move penalty |
| | Flower Field | Decorative, walkable, buildable |

### Vacuum Tiles — Nemaea (4)

| Done | Tile | Test |
|------|------|------|
| | Regolith | Lunar dust, walkable, buildable |
| | Crater | Impact crater, walkable, not buildable |
| | Metal Debris | Minable for metal (4 yield) |
| | Hull Plate | Minable for components (2 yield) |

### Space Tiles (7)

| Done | Tile | Test |
|------|------|------|
| | Space Asteroid | Minable for metal, blocks movement |
| | Space Debris | Passable, damages hull |
| | Space Star | Impassable, lethal |
| | Space Corona | Passable, extreme heat damage |
| | Dyson Sphere Intact | Solid, impassable |
| | Dyson Sphere Broken | Passable debris |
| | Space Gravity Well | Near-planet gravity, slows ships |

---
## 22. BOSSES & MEGABEASTS

### Named Bosses (4)

| Done | Boss | Test |
|------|------|------|
| | The Bull (ice brute king) | Multi-phase fight, escalating abilities |
| | Frost Titan boss | Multi-phase, telegraphed attacks (1s warning) |
| | Thermal Wurm boss | Multi-phase, unique mechanics |
| | Glacial Leviathan boss | Multi-phase, drops unique loot |

### Boss Mechanics (4)

| Done | Feature | Test |
|------|---------|------|
| | Phase transitions | Boss enters new phase at HP thresholds |
| | Telegraphed abilities | 1s warning before special attacks |
| | Unique drops | Boss-specific loot on kill (titan_heart, wurm_scale, etc.) |
| | Damage scaling | Each phase increases damage/speed multipliers |

### Procedural Megabeasts (3)

| Done | Feature | Test |
|------|---------|------|
| | Body form generation | 10 forms (serpent, spider, titan, etc.) |
| | Material variation | 10 material types affect stats |
| | Attack variety | 10 attack VFX types |

---
## 23. FIRE & HAZARDS

### Fire System (6)

| Done | Feature | Test |
|------|---------|------|
| | Fire ignition | Incendiary traps, meltdowns, campfires can start fires |
| | Fire spread | 15% base chance to adjacent flammable tiles |
| | Heat emission | Burning tiles emit 30C heat |
| | CO2 generation | Fires produce CO2 in enclosed rooms |
| | Entity damage | Entities on fire tiles take damage |
| | Weather suppression | Rain -70%, snow -50% spread chance |

### Firefighting (3)

| Done | Feature | Test |
|------|---------|------|
| | Auto-extinguish tasks | Fire auto-creates extinguish jobs for colonists |
| | Foam nozzle turret | Auto-targets fires in range, uses foam canisters |
| | Foam ordnance | Foam grenade/bomb/missile suppress fires + block ignition |

### Flooding (4)

| Done | Feature | Test |
|------|---------|------|
| | Water sources | Mined ice, burst pipes, breached water tiles |
| | Room flooding | Water level rises in enclosed rooms |
| | Drowning | Colonists take damage in deep water |
| | Pumps | Sump pumps remove water from rooms |

### Pollution (3)

| Done | Feature | Test |
|------|---------|------|
| | Pollution sources | Reactor, machines, incinerators produce pollution |
| | Pollution overlay (F3) | Pollution levels visible |
| | Scrubber | Reduces pollution in nearby tiles |

---
## 24. EXPLORATION & WORLD

### Map Secrets (5)

| Done | Secret | Test |
|------|--------|------|
| | Frozen colonist | Cryopod discoverable, thawable |
| | Thing mimic | Fake colonist, reveals as threat |
| | Precursor artifact | Discoverable, provides bonus |
| | Sealed cache | Discoverable, contains loot |
| | Dormant nest | Discoverable, may spawn creatures |

### BioCaves (3 tiers)

| Done | Tier | Depth | Test |
|------|------|-------|------|
| | Fungal | 1-2 | Fungal growth, skitterers, 5% discover chance |
| | Precursor | 3-4 | Precursor structures, spawnlings, 15% chance |
| | Organ | 5+ | Organic growth, fleshwalkers, 30% chance |

### Terraform (5)

| Done | Operation | Test |
|------|-----------|------|
| | Smooth terrain | Rough -> smooth tile conversion |
| | Clear terrain | Remove debris/growth |
| | Excavate | Mine rock/permafrost/deep rock |
| | Dig shaft | Create entrance to underground layer |
| | Lay floor | Place floor tile on dirt/cleared ground |

---
## 25. ELDRITCH & ANOMALY

### Eldritch Nodes (5)

| Done | Feature | Test |
|------|---------|------|
| | 5 growth stages | Larva->Whelp->Juvenile->Mature->Ancient |
| | 8 eldritch types | Flesh, ichor, chitin, void, serpent, bile, thorn, nerve, rot |
| | Resource production | Mature+ nodes produce resources via output buffer |
| | Mutation risk | Scales with stage, anomaly_sensitive colonists reduce risk |
| | Inserter integration | Resources extractable by inserters |

### Anomaly System (4)

| Done | Feature | Test |
|------|---------|------|
| | Anomaly level (0-100) | Rises from drilling, exploring, node growth |
| | Event thresholds | Level 20/40/60/80 trigger escalating events |
| | Boss awakening | Level 80+ -> "That Which Sleeps" awakens |
| | Win condition | Defeating boss unlocks extraction victory |

### Skinwalker Events (4)

| Done | Feature | Test |
|------|---------|------|
| | Edge spawning | Skinwalker spawns at map edge |
| | Calling phase (30s) | Eerie calls emitted |
| | Luring phase (60s) | Individual colonist lured toward edge |
| | Attack phase | Stalker/alpha_stalker/fleshwalker attacks |
| | Anomaly_sensitive resistance | Sensitive colonists resist the lure |

---
## 26. ENDGAME & VICTORY

### Victory Paths (4)

| Done | Path | Building | Test |
|------|------|----------|------|
| | Mammona Claim | transmission_array | 3-day charge -> final assault wave -> corporate claim ending |
| | Escape | launch_pad | Charge -> evacuate survivors -> escape ending |
| | Seal It | sealing_apparatus | Seal Erebus back down -> containment ending |
| | Mammona Extraction | extraction_beacon | Defeat boss first -> activate -> corporate extraction ending |

### Endgame Mechanics (3)

| Done | Feature | Test |
|------|---------|------|
| | Build phase | Endgame building constructible (expensive) |
| | Charge phase | 3 game-day charging period |
| | Final challenge | Transmission array triggers final assault before victory |

### Game Over (3)

| Done | Feature | Test |
|------|---------|------|
| | All colonists dead | Game over triggers |
| | Stats display | Days survived, peak pop, cause of death, wealth |
| | Colony legacy | Dead colony saved as legacy record for future playthroughs |

---
## 27. FARMING & FOOD

### Agriculture (5)

| Done | Feature | Test |
|------|---------|------|
| | Farm plot placement | Farm plots placeable in heated rooms |
| | Crop selection | 12 crops selectable via Farm panel |
| | Growth mechanics | tempFactor x lightFactor x waterFactor progression |
| | Harvest | Mature crops harvestable by colonists |
| | Sun lamp requirement | Indoor crops need sun lamp for light |

### Crops — Spot Check (4)

| Done | Crop | Test |
|------|------|------|
| | Ice rice | Fast grow (200s), low yield |
| | Frost potatoes | Medium grow (360s), reliable |
| | Tundra corn | Slow grow (600s), high yield |
| | Alien fungus | Grows in dark (no sun lamp needed) |

### Food Chain (4)

| Done | Feature | Test |
|------|---------|------|
| | Raw -> cooked | Kitchen converts raw meat/crops to meals |
| | Spoilage | Food items rot over time, faster in heat |
| | Smokehouse | Meat -> jerky (long shelf life) |
| | Feast recipe | High-quality meal from multiple ingredients |

---
## 28. COLONIST GROWTH & RECRUITMENT

### Colony Growth Sources (4)

| Done | Source | Test |
|------|--------|------|
| | Prisoner capture | 25% chance from raid kills -> prisoner -> recruit |
| | Refugee events | Storyteller triggers refugee arrival |
| | Cloning vat | 300s grow time, 30 food + 2 components -> new colonist |
| | Radio beacon | Passive wanderer attractor (also increases heat sig) |

### Slavery (CUT FROM SCOPE)
| Done | Feature | Test |
|------|---------|------|
| | Prisoner -> slave (CUT) | Archived stub, not a shipped system |
| | Slave work (CUT) | Archived stub, not a shipped system |
| | Escape risk (CUT) | Archived stub, not a shipped system |
| | Morale penalty (CUT) | Legacy penalty entry only, not reachable in normal play |
| | Free/sell/process (CUT) | Archived stub, not a shipped system |

### Strange Moods (4)

| Done | Feature | Test |
|------|---------|------|
| | Mood trigger | 3% per colonist per day -> colonist claims workshop |
| | Material demands | Colonist demands specific materials |
| | Artifact creation | 30s crafting -> legendary item with bonuses |
| | Failure | Timeout (120s) -> mental break or death |

---
## 29. SAVE/LOAD & PERSISTENCE

### Save System (5)

| Done | Feature | Test |
|------|---------|------|
| | Quick save (F5) | All game state written to disk, toast confirms |
| | Quick load (F9) | Game state restored from disk, toast confirms |
| | Auto-save | Every 5 real minutes, no player action required |
| | ECS serialization | All entities + components preserved |
| | Tilemap serialization | Tile data + temps + room IDs per depth layer |

### Save/Load Integrity (10)

| Done | System | Test |
|------|--------|------|
| | Colonist state | Needs, skills, traits, wounds, disease survive save/load |
| | Building state | All buildings, recipes, durability survive |
| | Thermal state | Room temperatures, reactor state survive |
| | Power grid | Generator fuel, battery charge, grid connectivity survive |
| | Research progress | Current research + completed nodes survive |
| | Pipe network | Fluid/gas levels, tank contents, processor state survive |
| | Active raid | Raid in progress survives save/load |
| | Weather/season | Current weather, season, day/time survive |
| | Planet state | GameState.planet, landing zone, planet-specific systems (pressure/corrosion/baldrungen) survive |
| | Easter egg state | Blood ocean active, blood rain fired flags survive |

---
## 30. EASTER EGGS

### Fischbach / Markiplier Easter Egg (7)

| Done | Feature | Test |
|------|---------|------|
| | Fischbach detection | System detects any living colonist with last name matching /[Ff]ischbach$/ |
| | Blood rain trigger (Erebus) | First rain event becomes blood_rain if Fischbach exists (weather.lua) |
| | Blood ocean (Nerthus-9) | Day 2 check: ocean tiles turn blood red, water rises |
| | Blood rain (other planets) | Day 2 check: 180s blood rain forced on non-ocean planets |
| | Ocean rising | Blood ocean active: water injected into surface tiles every 2s |
| | Submersible curse | Fischbach in submersible at depth causes durability drain + blood water leak |
| | Ocean calms | Fischbach dying at depth > 0 deactivates blood ocean; surface death = permanent |

### Blood Ocean Color Swaps (4)

| Done | Tile | Blood Color | Test |
|------|------|------------|------|
| | Ocean | (0.45, 0.05, 0.05) | Deep red |
| | Shallows | (0.55, 0.1, 0.1) | Shallow red |
| | Water | (0.5, 0.08, 0.08) | Blood water |
| | Seaweed | (0.35, 0.1, 0.05) | Dark red-brown |

---
## 31. MULTIPLAYER

### Network (4)

| Done | Feature | Test |
|------|---------|------|
| | Host game | lua-enet P2P host initializes |
| | Join game | Client connects to host |
| | Shared control | Actions sync between players |
| | Inter-colony trade | Trade routes between player colonies |

### Multiplayer UI (2)

| Done | Feature | Test |
|------|---------|------|
| | Host/Join screen | **MISSING** -- No UI to create or join game |
| | Player list | **MISSING** -- No connected player display |

---
## 32. MISC SYSTEMS

### Deterioration & Maintenance (3)

| Done | Feature | Test |
|------|---------|------|
| | Building decay | Buildings lose durability over time |
| | Repair task | Colonists auto-repair damaged buildings |
| | Destruction | Building at 0 durability -> destroyed |

### Decorations & Room Quality (3)

| Done | Feature | Test |
|------|---------|------|
| | Decoration placement | Decorative items placeable in rooms |
| | Room impressiveness | Formula based on size + furnishing + cleanliness |
| | Morale bonus | Better rooms -> higher colonist morale |

### Filth & Cleaning (2)

| Done | Feature | Test |
|------|---------|------|
| | Filth accumulation | Dirty areas accumulate filth over time |
| | Clean job | Colonists clean filthy areas when assigned |

### Equipment (3)

| Done | Feature | Test |
|------|---------|------|
| | Weapon equip | Colonists can be assigned melee/ranged weapons |
| | Armor equip | Colonists can be assigned armor |
| | Thermal suits | Thermal suit/exosuit for expedition protection |

### Quest System (3)

| Done | Feature | Test |
|------|---------|------|
| | Quest generation | Procedural quests created |
| | Quest objectives | Objectives trackable and completable |
| | Quest panel | Panel exists, Q hotkey wired in main.lua |

### Elastic Difficulty (2)

| Done | Feature | Test |
|------|---------|------|
| | Difficulty scaling | Threat scales with colony wealth/population |
| | Adaptation | System adapts to player performance |

---
## KNOWN GAPS SUMMARY

| # | Gap | Impact | Priority |
|---|-----|--------|----------|
| 1 | ~~Taming has no work AI job~~ | **RESOLVED** -- Taming job exists in jobs.lua | ~~HIGH~~ |
| 2 | Multiplayer has no host/join UI | Full P2P backend unreachable by players | HIGH |
| 3 | Victory condition framing | Names in docs/UI can drift if not kept in sync with the 4 live endgame outcomes | LOW |
| 4 | ~~Quest panel hotkey~~ | **RESOLVED** -- Q key wired in main.lua and quest_panel.lua | ~~LOW~~ |
| 5 | Vehicle construction UI (CUT) | Archived scope item, not a shipped feature gap | LOW |
| 6 | Turret targeting priority | No UI to set turret priorities/ranges | LOW |
| 7 | ~~Sprite art~~ | **RESOLVED** -- 379 PNGs in assets/sprites/, lazy-loaded via sprites.lua | ~~HIGH~~ |
| 8 | Merchant caravan visuals | Minimal entity representation on map | LOW |
| 9 | Taming system backend-only | No work AI job for animal husbandry | MEDIUM |
| 10 | 4 victory paths undiscoverable | No in-game guidance for players to find victory conditions | MEDIUM |

---
## TOTALS

| Category | Items |
|----------|-------|
| Core game loop | 17 |
| Player controls & input | 34 |
| UI panels | 56 |
| Planet system | 109 |
| Per-planet mechanics | 44 |
| Colonist systems | 63 |
| Social & morale | 33 |
| Building & construction | 72 |
| Underwater & ocean buildings | 22 |
| Weather system (all planets) | 35 |
| Thermal & environment | 23 |
| Power system (incl. 38 generators) | 44 |
| Combat & defense | 27 |
| Raids & threats | 16 |
| Disease & medical | 15 |
| Logistics & automation | 20 |
| Research & progression | 10 |
| Trade & economy | 10 |
| Exploration & expeditions (49 destinations) | 61 |
| Creatures & wildlife (123 species) | 105 |
| Tile types (84 tiles) | 85 |
| Bosses & megabeasts | 11 |
| Fire & hazards | 16 |
| World exploration | 13 |
| Eldritch & anomaly | 13 |
| Endgame & victory | 10 |
| Farming & food | 13 |
| Colony growth | 13 |
| Save/load | 15 |
| Easter eggs | 11 |
| Multiplayer | 6 |
| Misc systems | 16 |
| **GRAND TOTAL** | **~1,058 testable items** |

*Generated from codebase audit on 2026-03-16. Covers 7 planets, 123 creature species, 84 tile types, 38 power generators, 49 expedition destinations, 22 weather types, and full underwater/pressure/corrosion/Baldrungen mechanics.*
