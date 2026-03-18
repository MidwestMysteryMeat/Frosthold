# Interplanetary Travel & Space Gameplay — Design Spec

**Date:** 2026-03-15
**Status:** Draft
**Scope:** Late-game ship construction, open-world space exploration, multi-colony management, space combat, station/POI interaction

---

## 1. Overview

Frosthold's endgame expands from single-planet colony survival into a living galaxy. Players build (or discover) ships, fly through open 2D space, dock at stations, fight pirates, trade with caravans, and establish colonies on all 7 planets. Space itself is a playable tilemap biome. Victory conditions become milestones that unlock new possibilities rather than ending the game.

### Design Pillars
- **Space as a Planet:** Space is an 8th planet definition. The ship is the colony. All existing ECS systems (building, combat, thermal, atmosphere, power, save/load) work on the ship map.
- **Two Ship Tiers:** A scrappy scout ship (discovered, 1-crew, stealth-capable) and an endgame colony ship (built, crew of 10+, armed freighter).
- **Open 2D Space:** A chunked procedural tilemap with asteroids, stations, caravans, pirates, derelicts. 7 planets are fixed anchors; everything else is procedurally generated from world seed.
- **FTL-Style Combat:** System-targeting (each weapon independently assigned to an enemy system), hull breaches vent atmosphere, boarding combat is room-by-room using existing colonist combat.
- **Colony Background Sim:** Colonies serialize when you leave. Automation level determines background production. No raids while absent. Return to find results of what you built (or didn't).

---

## 2. Ship Tiers

### 2.1 Scout Ship (Discovered)

- **Grid:** ~12x8 tiles
- **Crew:** 1 pilot minimum, 2-3 max comfortable
- **Cargo:** Minimal — one small hold, 10-15 item slots
- **Required modules:** Cockpit (2x2), engine (2x3), life support (1x2), mini reactor (1x1)
- **Remaining space:** ~40 free tiles for crew bunk, storage, workbench, maybe one weapon mount
- **Discovery:** Rare map secret ("Crashed Survey Vessel") or expedition reward. Damaged Mammona scout that needs progressive repair (hull → engine → life support). Lore: predecessor mission Mammona denied existed
- **Repair requirements:** Steel + components (hull), circuits + fuel (engine), pipes + insulation (life support). Each stage requires relevant research OR can be brute-forced with extra materials if found early
- **Strengths:** Stealth capable, cheap fuel, fast, nimble
- **Weaknesses:** No room for serious weapons, one hull breach is critical, minimal cargo
- **Role:** Reconnaissance, short hops, early taste of space. Scout a planet, trade at a station, run blockades

### 2.2 Colony Ship (Built)

- **Grid:** ~30x20 tiles
- **Crew:** 1 pilot minimum, practically needs 6-10+ for operations
- **Cargo:** Large holds, colony-founding supply capacity
- **Required modules:** Bridge (3x3), engine bay (3x4), life support array (2x3), reactor (existing 3x3)
- **Remaining space:** ~400+ free tiles
- **Construction:** Endgame research (reworked shuttle_engineering) unlocks shipyard building. Built on-planet over many days with massive resource cost
- **Strengths:** Armed, durable, self-sufficient for long voyages, can carry colony-founding supplies
- **Weaknesses:** Massive heat signature, cannot stealth, fuel-hungry, slow
- **Role:** Colony transport, inter-planet migration, armed trade runs

### 2.3 Prebuilt Layouts

Players choose a prebuilt layout or empty hull when constructing/discovering a ship.

**Scout prebuilts:**
- **Mammona Survey Runner** — balanced: tiny cargo bay, one weapon mount, basic sensors
- **Smuggler's Skiff** — stealth-optimized: stealth module pre-installed, hidden cargo compartment, no weapons
- **Empty Hull** — cockpit, engine, life support, mini reactor only

**Colony ship prebuilts:**
- **Mammona Frontier Hauler** — cargo-focused: large holds, minimal weapons, thick hull
- **UTC Decommissioned Corvette** — combat-focused: multiple weapon mounts, shield generator, armored bridge, lighter cargo
- **Pioneer Vessel** — balanced: farm bay, med bay, workshop, moderate cargo and weapons
- **Empty Hull** — required modules only

### 2.4 Mini Reactor (New Building)

- **Size:** 1x1
- **Power output:** Low (enough for scout ship essentials)
- **Fuel consumption:** Minimal
- **No overdrive:** Cannot overdrive, no meltdown risk
- **Purpose:** Scout ships can't fit a 3x3 reactor. The mini reactor forces real power tradeoffs — shields OR weapons OR stealth, not all three

---

## 3. Space Tilemap & Navigation

### 3.1 Space as a Planet Definition

```lua
space = {
    id = 'space',
    name = 'Space',
    subtitle = 'The Void Between',
    atmosphere = { ambientO2 = 0, ambientCO2 = 0 },
    thermal = { outdoorSnap = 1.0, undergroundBaseTemp = -270 },
    radiation = { ambientDose = 0.01 },
    -- No seasons, no creature pools, no worldMap biomes
    -- Procedural chunk generation instead of fixed tilemap
}
```

### 3.2 Chunk System

Planet colony maps remain fixed-size and unchanged. Space uses a new chunked tilemap:

- **Chunk size:** 32x32 tiles
- **Active radius:** Chunks within render distance + 1 of ship position are loaded
- **Generation:** Deterministic from `worldSeed + chunkX + chunkY`. Revisiting a chunk regenerates identical layout
- **Persistent modifications:** Mined asteroids, destroyed stations stored in a sparse diff table per chunk (`spaceChunkDiffs[chunkKey]`)
- **Content generation per chunk:** Rolls for asteroid density, debris probability, nebula presence, empty void ratio

### 3.3 Procedural Content (Seed-Based)

The 7 planets are fixed anchor positions. Everything else is procedurally generated from the world seed each playthrough:

- **Asteroid fields** — minable (ore, ice, rare minerals), block movement, provide combat cover
- **Debris fields** — salvageable wreckage, can damage hull on contact, source of components/steel
- **Nebulae** — reduce detection range (natural stealth cover), some corrosive or irradiated
- **Gravity wells** — near planets, slow movement, pull drifting ships
- **Empty void** — most of space is empty. Long stretches of nothing punctuated by discoveries

### 3.4 Navigation

- **Ship movement:** Tile-by-tile on space tilemap. Engine power determines speed (tiles per tick). Direction set by pilot at cockpit
- **Fuel consumption:** Engines burn fuel proportional to thrust. No fuel = drift (momentum carries, no steering)
- **Autopilot:** Set a destination, ship flies there. Pilot must be at cockpit. Interrupted by encounters or system damage
- **Sensor range:** How far you can see on the space map. Fog of war beyond range. Upgradeable via sensor module
- **Inter-planet travel:** Fly across the space map between planet orbital zones. Long distances, encounters along the way
- **Warp drive (optional ultra-late research):** Skip chunks of space at high fuel cost. Tied to Janus warp key lore

---

## 4. Ship Systems & FTL-Style Damage

### 4.1 Ship Systems as ECS Components

Each ship system is a building placed on the ship grid with a `ship_module` ECS component: `{ shipId, systemType, operational }`. Damaged systems degrade; destroyed systems go offline. Same architecture as colony buildings.

### 4.2 Core Systems (Required)

| System | Size (Scout/Colony) | Function | Damaged | Destroyed |
|--------|-------------------|----------|---------|-----------|
| Cockpit/Bridge | 2x2 / 3x3 | Steering, autopilot, sensors | Sensor range halved, no autopilot | Ship drifts uncontrollably |
| Engines | 2x3 / 3x4 | Thrust, speed | Speed halved, overheating begins | No thrust, drift only, overheating |
| Life Support | 1x2 / 2x3 | O2 generation, CO2 scrubbing | O2 production reduced, CO2 builds | No O2 — suits or suffocation |
| Reactor | 1x1 / 3x3 | Power for all systems | Existing meltdown risk mechanics | Total blackout |

### 4.3 Optional Systems (Player-Placed)

| System | Function | Damaged/Destroyed Effect |
|--------|----------|--------------------------|
| Shields | Absorb incoming projectile damage | Reduced / no absorption |
| Weapons (turret mounts) | Ship-to-ship combat, independently targetable | Reduced fire rate / can't fire |
| Sensors | Detection range, stealth detection | Reduced range / flying blind |
| Comms Array | Contact stations, distress calls, trade hails | Static / total silence |
| Cargo Bay | Storage capacity | Items spill, cargo lost to vacuum |
| Med Bay | Treat wounded crew | Existing medical system |
| Workshop | Repair ship systems, craft parts | Can't fabricate repair materials |
| Airlock | Controlled entry/exit for EVA, boarding chokepoint | Sealed shut or venting |
| Stealth Module | Signature reduction (scout only) | Reduced effect / signature spikes |

### 4.4 Damage Model

- **Hull HP:** Ship hull tiles have durability (like walls). Projectiles/debris that bypass shields damage hull tiles directly
- **Breach:** Hull tile at 0 HP = breach. Room vents to vacuum. Existing atmosphere system handles O2 loss. Colonists without suits take suffocation damage
- **System targeting:** FTL-style — each of the player's weapon mounts is independently assigned to a target enemy system. NPC ships target player systems based on AI priority
- **Repair:** Crew with repair task patches hull breaches (existing repair mechanic) and restores system durability. Workshop module needed to fabricate replacement parts
- **EVA repairs:** External hull damage requires crew in space suits to exit via airlock, walk on hull exterior (mag boots), repair from outside. Exposure to debris, radiation, enemy fire

### 4.5 Space Suits

- **Equipment slot item** — same system as parkas/gear
- **Function:** Prevents suffocation in vacuum, thermal protection, enables EVA
- **Durability:** Degrades with use, especially during EVA. Suit breach = emergency
- **Tiers:** Basic suit (short EVA), reinforced suit (long EVA, debris resistance), combat suit (armed EVA, boarding)

### 4.6 Stealth System

- **Heat signature in space:** Same formula as ground (power output + crew + active systems)
- **Detection range:** NPC ships have a detection radius. Ship signature determines visibility
- **Running cold:** Power down engines (drift), minimal life support, lights off = near-zero signature
- **Scout ship:** Small enough to run cold effectively. Can pass within a few tiles of a patrol undetected
- **Colony ship:** Signature floor too high even powered down. Cannot stealth — invest in weapons and shields instead
- **Active stealth module:** Late research, scout-only. Reduces signature further but drains power fast. Sprint past a blockade, not sustain indefinitely

---

## 5. Space Combat & Boarding

### 5.1 Ship-to-Ship Combat

**Engagement:** When a hostile enters sensor range (or you enter theirs), combat is live. Both ships are on the space tilemap — real positions, real distance. Not instanced.

**Player actions:**
- **Target assignment (FTL-style):** Each weapon mount independently assigned to an enemy system. Forward laser hits their shields while missile launcher targets their engines simultaneously. Multiple mounts = more simultaneous pressure
- **Evasive maneuvers:** Pilot at cockpit jukes — reduces incoming hit chance, burns fuel, slows speed
- **Flee:** Burn engines away. Speed > theirs = escape. Damaged enemy engines = easy getaway
- **Hail:** Comms array for diplomacy — surrender, bribe, bluff. Faction reputation affects success
- **Power management:** Divert reactor output between shields, weapons, engines mid-fight. Existing power priority system

**System damage consequences:**
- **O2 knocked out** (crew without suits) → suffocation
- **Engines knocked out** → no movement, ship overheats
- **Shields knocked out** → hull takes direct hits
- **Weapons knocked out** → can't fire back
- **Comms knocked out** → no distress calls, no surrender negotiation

**Damage resolution:**
- Weapon accuracy: gunner skill + distance + target evasion
- Shields absorb hits until depleted, then hull takes damage
- System damage rolls when projectile hits the tile containing that system
- Critical hits: low probability, high skill — chance to disable a system in one shot

### 5.2 Boarding Combat

**Initiation:**
- Dock alongside enemy ship (close range, both ships low speed or engines disabled)
- Breach airlock or cut through hull tile
- Colonists cross onto enemy ship's interior tilemap

**The fight:**
- Standard colonist combat mechanics on enemy ship grid
- Room-by-room clearing. Doors are chokepoints
- Atmosphere matters — breach a room and unsuited enemies suffocate
- Enemy crew fights back using same combat AI as raiders
- Target priority: bridge (capture ship), engine room (prevent flee), life support (force surrender)

**Player gets boarded:**
- Pirates dock with player's ship, breach airlock
- Defense: crew fights in own corridors. Airlock placement = chokepoint design
- Interior turrets work as hallway defense
- Sealed doors slow boarders

**Outcomes:**
- **Capture:** Take their bridge = control their ship. Salvage for parts, loot cargo, rescue prisoners
- **Surrender:** Reduce crew below threshold, they surrender. Take what you want
- **Destruction:** Blow the reactor = explosion, blast damage to nearby ships. No loot
- **Repel boarders:** Kill all boarders on your ship. They retreat or die

### 5.3 Pirate Faction Behavior

Each pirate faction has distinct combat doctrine:

- **Black Maw:** Head-on assault, heavy weapons, breach and overwhelm. Won't board — they want you dead or fleeing their corridor
- **Void Serpents:** Stealth approach, target comms first (no distress call), precision boarding with small elite crews
- **Rust Reavers:** Disable engines, dock, strip your ship for parts while you're still in it. Leave you alive but drifting

### 5.4 NPC Ship Behavior

- **UTC Rangers:** Hail first, demand inspection. Fight only if resisted or contraband found
- **Mammona Patrols:** Demand quota compliance data. Hostile if you've gone rogue from Mammona
- **Caravans:** Flee on contact with hostiles. Won't fight unless cornered
- **Pirates:** Faction-specific (see 5.3)

---

## 6. Points of Interest & Space Economy

### 6.1 Station Types

**UTC Ranger Outposts**
- Safe zone — no combat within station sensor range
- Services: repair (credits), refuel, medical, bounty board
- Trade: standard goods at fair prices, legal items only
- Intel: buy star charts revealing nearby POI locations
- Reputation gated: hostile UTC rep = denied docking

**Pirate Stations (Edge of Oblivion)**
- Three stations, one per faction (Black Maw fortress, Void Serpent den, Rust Reaver junkyard)
- Services: black market (drugs, stolen goods, contraband weapons), shady repairs, crew recruitment
- No safe zone — fights can break out
- Reputation gated: need positive faction rep to dock peacefully. Can raid hostile stations

**Corporate Orbitals**
- **StarByte Vending Station** — consumer goods, morale items, overpriced snacks. "Sunny" AI mascot
- **Fortune Arms Depot** — weapons, ammo, turret modules, combat suits. Premium prices
- **OmniCorp Freight Hub** — bulk cargo trading, shipping contracts (deliver X to Y for credits)
- **TerraGen Medical Station** — medicine, surgery, prosthetics, bionics
- **NexLink Relay** — comms upgrade modules, encrypted frequencies, long-range colony messages
- **Mammona Logistics Depot** — quota submission, supply requisition, corporate missions

**Derelicts**
- Procedurally generated wrecked ships (Mammona cargo, pirate raider, UTC patrol, pre-Fortuna surveyor)
- Board and explore — small tilemap interiors with loot, hazards, hostile occupants
- Salvageable for ship parts, rare components, lore documents, working modules

### 6.2 Mobile Caravans

- GustoGrain haulers, OmniCorp freighters, independent traders on procedural routes between stations
- Hail via comms to trade. Prices vary by cargo and destination
- Can be raided (reputation consequences with parent faction + UTC)
- Sometimes under pirate attack — intervene for rep + trade discount

### 6.3 Easter Egg Encounters

**Xenolith Hive-Ship (ultra-rare)**
- Massive derelict organic vessel. Nothing in HERMES logs or Mammona records explains it
- Interior: organic corridors, Xenolith eggs pulsing in chambers, one adult Xenolith stalking the halls
- Extremely dangerous. Xenolith is a boss-tier creature. Eggs can be harvested (containment required) or destroyed
- Lore payoff: connects to deep lore about the Praxii extinction. No hand-holding — players piece it together

**Praxii Forerunner Stations/Ships (rare)**
- Pristine geometric architecture from an extinct near-human race
- Technology that doesn't match anything in UTC databases
- Eerily preserved, completely empty. Advanced salvage (unique research materials, high-tier components)
- Scattered across space — finding multiple builds a picture of who the Praxii were and what destroyed them

### 6.4 Space Economy

- **Credits:** Primary currency at stations (existing lore as UTC standard)
- **Thermal Cores:** Accepted everywhere, premium at corporate stations
- **Reputation:** Per-faction, affects prices, docking access, mission availability. Same system as ground factions extended to space
- **Shipping contracts:** Pick up cargo at station A, deliver to B or planet surface. Timed payment on delivery. Good scout ship income
- **Bounties:** UTC posts bounties on pirates. Pirates post bounties on UTC patrols. Pick your side

---

## 7. Landing, Colony Background Sim & Multi-Colony

### 7.1 Landing Sequence

1. **Approach:** Enter planet's orbital zone on space tilemap
2. **Landing site:** Existing colony → land at built landing pad. New planet → world map hex selection (existing flow)
3. **Transition:** Ship serializes space position. Ship structure stamps onto colony tilemap at landing pad. Colonists walk off freely. Cargo accessible via hauling
4. **While docked:** Ship systems connect to colony power grid (adjacent conduits). Ship reactor can power colony or vice versa. Ship is a building complex — repairable, accessible, integrated
5. **Launch:** Player triggers from cockpit. Colonists on ship board. Everyone else stays. Ship tiles lift off, colony restores landing pad. Space tilemap loads at planet orbital position

### 7.2 Colony Background Simulation

When leaving a colony (launch), it enters background mode:

**Serialized:** Full ECS snapshot (same as save), resource counts, population, building states, automation score.

**Automation score** calculated from: conveyor networks active, inserter chains running, production machines with recipes set, farm plots with crops planted, power generation surplus.

**Background tick (once per game-day while in space):**
- **Production:** Automated machines produce at reduced rate proportional to automation score. No automation = zero output
- **Consumption:** Colonists eat, consume fuel, use resources at normal daily rates
- **Population:** No deaths from raids/events (too punishing). Starvation possible if food hits zero
- **No raids:** Storyteller only targets active map
- **No construction:** Nothing new gets built. Only existing automation runs
- **Decay:** Buildings lose durability at normal rate. Unrepaired buildings can break down

**On return:**
- Colony deserializes. Time-skip results applied
- If food hit zero: colonists starving, low HP, need immediate attention
- If fuel hit zero: reactor offline, rooms cold, hypothermia
- Log summary: "While you were gone (14 days): +340 metal ingots, -210 food, 2 machines broke down"

### 7.3 Multi-Colony Management

- **Colony registry:** `GameState.colonies = { [colonyId] = { planetId, name, state, automationScore, snapshot } }`
- **Active colony:** Only one colony (or ship) has full ECS simulation at a time
- **Status panel:** New UI showing all colonies with summary stats (population, food, production). Accessible from ship cockpit
- **Supply drops:** From orbit, drop cargo pods to colony below without landing (one-way, costs cargo pod item)

### 7.4 Crew Splitting

- Ship needs 1 pilot minimum. More crew = better repairs, combat, operations
- Colony left behind runs on its automation level. Strategic choice: take your best fighter for space pirates, leave your best farmer to keep food flowing
- No minimum colony population, but too few colonists + no automation = colony degrades

---

## 8. Endgame & Victory Rework

### 8.1 Victory as Milestone

Victories become milestones that remove constraints and open possibilities, not endings. The game never forces an end state.

**Exodus (launch pad) — REWORKED:**
- No longer a victory condition. Launch pad is step 1 of building the shipyard
- The "escape" fantasy is fulfilled by actually flying away in gameplay
- Build ship → load crew → launch → fly to a new planet. The escape IS the game now

**Mammona Claim (transmission array) — MILESTONE:**
- Signal Mammona, survive final wave. Mammona stamps "CLAIMED" on the planet
- Reward: Mammona sends reinforcements (more colonists), establishes regular supply drops, corporate trade prices improve
- Game continues — you now have a fortified corporate outpost as your base

**Seal The Deep (sealing apparatus) — MILESTONE:**
- Seal the anomaly. Anomaly drops to zero permanently on this planet
- Reward: deep mining is safe, no more anomaly events, stable colony. Perfect launch platform for space
- Game continues — the threat is contained, build freely

**Mammona Extraction (extraction beacon) — MILESTONE:**
- Defeat That Which Sleeps, call the fleet
- Reward: Mammona extraction fleet arrives, massive resource injection, access to corporate-grade ship modules
- Game continues — you've proven the planet's value. Mammona invests heavily

### 8.2 Exodus as Gateway

The key design shift: Exodus was "build ship, game over." Now it's "build ship, game begins." Research cost and resource investment remain high. But instead of a victory screen, you get the cockpit of your ship and an entire galaxy.

### 8.3 Per-Planet Endgames (Future)

- Erebus: existing 3 milestones (Claim, Seal, Extraction)
- Gaia A^1x: Baldrungen scripted fall (survive the corruption cycles)
- Nemaea: potential "shut down the Dyson Sphere" or "free the Automatons" endgame
- Other planets: can gain unique endgames in future updates

---

## 9. Research & Progression

### 9.1 New Research Nodes

**Tier 4 additions:**
- **Ship Repair Systems** — workshop module, hull patch kits, EVA repair capability
- **Space Suit Engineering** — basic/reinforced/combat suit crafting
- **Shipboard Weapons** — weapon mount buildings (laser turret, missile rack, point defense)

**Tier 5 additions/reworks:**
- **Shuttle Engineering (reworked)** — unlocks shipyard building for colony ship construction. Launch pad becomes shipyard component
- **Shield Systems** — shield generator module for ships
- **Stealth Technology** — active stealth module (scout ship only)
- **Interplanetary Navigation** — autopilot, long-range sensors, star chart system

**Tier 6 (new tier):**
- **Warp Drive** — skip chunks of space at high fuel cost. Requires Janus lore fragments. Ultra-late game

### 9.2 Scout Ship Discovery

- **Map secret:** "Crashed Survey Vessel" added to map secret pool. Rare spawn
- **Expedition reward:** Deep expedition can discover crash site
- **Repair:** Progressive — hull (steel + components), engine (circuits + fuel), life support (pipes + insulation)
- **No research gate for flying:** Find it, fix it, fly it. But without Ship Repair Systems research, you can't fix space damage. High risk early

### 9.3 Planet Discovery (In-Fiction)

Players pick their starting planet from all 7 at game start (unchanged). But in fiction, colonists only know their home planet. Other 6 must be discovered via:
- **Star charts:** Bought at UTC stations or found in derelicts
- **NexLink data:** Purchased comm frequencies revealing orbital positions
- **Exploration:** Fly far enough, sensors detect a gravity well
- **Lore fragments:** HERMES logs, Mammona documents referencing planets by name

---

## 10. Space Hazards & Events

### 10.1 Environmental Hazards

- **Debris fields:** Hull damage on contact, slow movement, minable for scrap, combat cover
- **Radiation zones:** Crew takes radiation damage over time. Suits reduce exposure. Shielded rooms block it
- **Solar flares:** Periodic — shields offline, sensors blind, autopilot disengages. More frequent near Rhea-2
- **Micrometeorite storms:** Sustained hull pelting. Gradual damage. EVA crew take injury. Shelter or flee

### 10.2 Storyteller Events

- **Distress signals:** Genuine rescue, pirate trap, or derelict beacon. Comms quality affects distinction
- **Convoy ambush:** Pirates hitting a caravan. Intervene (rep + discount), ignore, or loot aftermath (rep hit)
- **Stowaway:** After station docking, extra person aboard. Refugee? Spy? Escaped prisoner?
- **System malfunction:** Random critical system fault. Repair before cascade. Gives repair crew purpose during travel
- **Derelict encounter:** Sensors detect drifting wreck. Mini-dungeon: small tilemap, fog of war, unknown threats, guaranteed loot
- **Space whale (rare):** Massive creature drifting through void. Harmless unless provoked. Harvestable for exotic resources

---

## 11. Technical Architecture

### 11.1 "Space as a Planet" Approach

Space is treated as an 8th planet definition. The ship is the colony. All existing ECS systems work on the ship map with minimal modification. This maximizes code reuse.

### 11.2 Chunk System (New)

- Current tilemap: fixed size, fully loaded. Unchanged for planet colonies
- Space tilemap: chunked, 32x32 tiles per chunk. Only chunks near ship are active
- Generated deterministically from `worldSeed + chunkX + chunkY`
- Persistent modifications stored in sparse diff table per chunk

### 11.3 Ship Entity Architecture

- Ship is an **entity group** — collection of ECS entities bound by shared `ship` component
- `ship` component: `{ shipId, tier, pos, velocity, heading, fuel, hullHP }`
- Ship modules are buildings with `ship_module` component: `{ shipId, systemType, operational }`
- NPC ships use identical architecture — same entity group structure, same systems

### 11.4 State Transitions

**Colony -> Space (launch):**
1. Serialize active colony (full ECS snapshot + tilemap) to `colonies[colonyId]`
2. Calculate automation score from serialized state
3. Load space tilemap (chunked, centered on planet orbital position)
4. Deserialize ship entity group onto space tilemap
5. Set `GameState.activeMap = 'space'`
6. Start background colony tick timer

**Space -> Colony (land):**
1. Serialize ship entity group
2. Apply background tick results to target colony snapshot
3. Deserialize target colony (full ECS restore + tilemap)
4. Stamp ship entity group onto colony tilemap at landing pad
5. Set `GameState.activeMap = colonyId`

### 11.5 Save/Load Changes

- **Save format version 3:** Adds `colonies` table, `activeMap` field, `spaceState`
- Each colony snapshot uses existing save format (already complete serialization)
- Ship state serialized same as colony
- Backward compatible: v2 saves load as single-colony, no space

### 11.6 GameState Extensions

```lua
GameState.activeMap          -- 'space' or colonyId string
GameState.colonies           -- { [id] = { planetId, name, snapshot, automationScore, lastTickDay } }
GameState.shipState          -- { shipId, tier, fuel, position, heading, velocity }
GameState.discoveredPOIs     -- { [poiId] = { type, chunkX, chunkY, visited } }
GameState.discoveredPlanets  -- { [planetId] = true }
GameState.spaceChunkDiffs    -- { [chunkKey] = { modified tiles } }
```

### 11.7 Reused vs New Systems

**Reused (minimal changes):**
- ECS engine, all components, all systems
- Building placement, durability, repair
- Combat (melee, ranged, projectiles)
- Atmosphere (O2, CO2, vacuum)
- Power grid (reactor, conduits, consumers)
- Thermal system
- Medical, disease, needs
- Equipment, inventory, hauling
- Research tree (extended)
- Colonist AI, jobs, pathfinding
- Save serialization format
- All existing UI panels

**New systems:**
- Chunk-based tilemap loader/generator
- Ship movement and navigation
- Ship-to-ship combat targeting (FTL-style per-weapon assignment)
- Boarding transition (cross-entity-group combat)
- Colony background simulation tick
- Colony registry and state transitions (launch/land)
- Space POI generation (stations, derelicts, caravans)
- NPC ship AI (patrol routes, combat, trading)
- Stealth/detection system
- Star map UI overlay
- Space hazards and events
- Mini reactor building (1x1)
- Ship prebuilt layout system
- Shipyard building and construction flow

---

## 12. Lore Integration

### 12.1 Existing Lore That Gets Physical Presence

Everything in the lore bible that was previously flavor text gets a real location in space:

- **Edge of Oblivion** — pirate station cluster, physically dockable
- **Corporate ecosystem** — StarByte, Fortune Arms, OmniCorp, TerraGen, NexLink all have orbital stations
- **Mammona Logistics** — checkpoints, depots, patrol routes
- **UTC Rangers** — outposts, patrols, bounty boards
- **GustoGrain/consumer brands** — mobile caravans, vending stations
- **Factions** — all 13+ factions have space presence matching their ground behavior

### 12.2 Deep Lore Easter Eggs

**Xenolith Hive-Ship (ultra-rare):**
- Massive organic derelict. Nothing in any database explains it
- Interior: organic corridors, Xenolith eggs in chambers, one adult Xenolith (boss-tier) stalking halls
- Connects to Praxii extinction — players piece it together without hand-holding

**Praxii Forerunner Stations/Ships (rare):**
- Pristine geometric architecture from extinct near-human race
- Technology unmatched in UTC databases. Eerily preserved, completely empty
- Advanced salvage (unique research materials, high-tier components)
- Multiple discoveries build picture of who Praxii were and what destroyed them

### 12.3 Lore Bible Updates Required

Add to LORE_BIBLE.md:
- Skinwalkers, Eldritch Nodes, That Which Sleeps (already added this session)
- Space station types and their operators
- NPC ship classes and faction fleet compositions
- Scout ship lore (predecessor Mammona missions)
- Shipyard construction lore
- Space creature entries (space whale)

---

---

## 13. Context-Swap Protocol (Critical Architecture)

The ECS, tilemap, atmosphere, power, pipes, and 40+ other modules are global singletons with module-level state. Multi-colony and space require a clean context-swap protocol. This section defines that protocol.

### 13.1 The Problem

`ECS.init()` wipes all entities, components, and systems. Module-level locals (atmosphere's `vents`/`roomAtmo`, power's grid tables, pipes' network tables, etc.) cache entity IDs and state. Swapping contexts without resetting these caches produces stale references and crashes.

### 13.2 The Solution: Full Save/Load Cycle as Context Swap

Context switching reuses the existing `Save.save()` / `Save.load()` cycle — the same code path that already handles serializing all module state and restoring it cleanly. This is the only code path that correctly handles all 40+ modules.

**Colony -> Space (launch):**
1. Call `Save.save()` targeting `colonies[colonyId].snapshot` (writes to memory table, not disk)
2. Calculate automation score from the just-saved snapshot
3. Call `ECS.init()` — wipes everything (same as `Save.load()` does)
4. Call `Planet.init('space')` — loads space planet config
5. Initialize chunked tilemap (new `SpaceTilemap.init()` replacing fixed `World.init()`)
6. All systems re-register (same re-registration block as `Save.load()` lines 147-224)
7. Deserialize ship entities from `GameState.shipState.snapshot`
8. Set `GameState.activeMap = 'space'`

**Space -> Colony (land):**
1. Serialize ship entity group to `GameState.shipState.snapshot`
2. Apply background tick to target colony (math against snapshot counters, not ECS)
3. Call `ECS.init()` — wipes space ECS
4. Call `Save.load()` from `colonies[colonyId].snapshot` (in-memory, not disk) — this handles `Planet.init()`, tilemap restore, system re-registration, and all module state restoration
5. Spawn ship entities onto colony tilemap at landing pad coordinates (translate `pos` components)
6. Set `GameState.activeMap = colonyId`

**Key insight:** We never run two ECS worlds simultaneously. We serialize one, destroy it, and deserialize the other. This is exactly what save/load already does — we just call it at runtime instead of on user F5/F9.

### 13.3 ECS Snapshot API (New)

Add to `save.lua` / `save_helpers.lua`:

```lua
-- Serialize current ECS + module state to an in-memory table (same format as disk save)
Save.snapshotToMemory() -> table

-- Restore ECS + module state from an in-memory table (same as Save.load but from table not file)
Save.loadFromMemory(snapshotTable) -> bool
```

These are thin wrappers around the existing `buildSaveData()` and load logic, replacing file I/O with direct table passing. No new serialization format — the snapshot IS the save format.

**Tilemap handling:** `loadFromMemory` accepts an optional `skipTilemap` flag. When restoring into a space context (Colony->Space transition), `skipTilemap = true` bypasses the fixed tilemap restore block (save.lua lines 114-133) since space uses `SpaceTilemap.init()` instead of `World.init()`. When restoring a colony (Space->Colony), `skipTilemap = false` (default) and the fixed tilemap restores normally.

### 13.4 Background Colony Tick (Implementation)

The background tick does NOT use ECS. It operates on the serialized snapshot as a simple counter-based simulation:

```lua
-- src/sim/background_colony.lua
function BackgroundColony.tick(snapshot, daysPassed, automationScore)
    -- Production: append to snapshot.backgroundProduction[itemId] += dailyRate * automationScore * daysPassed
    -- Consumption: decrement food/fuel from snapshot entity items (find storage entities, reduce amounts)
    -- Decay: for each building entity in snapshot, durability -= decayRate * daysPassed
    -- Clamp: no resource goes below 0
    -- Status: if food == 0, mark colonists as starving in snapshot
    -- Return: modified snapshot + log of what changed
end
```

**Physical items compatibility:** The game uses physical ECS item entities, not resource counters. The background tick does NOT write to `GameState.resources` (deprecated). Instead:
- **Consumption:** Iterates storage entities in the snapshot, reducing item `amount` fields directly (food, fuel). If a stack hits 0, remove it from the storage slot.
- **Production:** Accumulated output stored in a separate `snapshot.backgroundProduction = { [itemId] = amount }` table. When the colony deserializes on return, `BackgroundColony.spawnProduction(snapshot)` converts this table into physical item entities at the colony's storage buildings — reusing the same pattern as the v1→v2 save migration that spawns items from counters.
- **Decay:** Directly modifies `durability.hp` fields on building entities in the snapshot.

**Automation score formula:**
```lua
automationScore = (
    activeConveyorTiles * 0.01 +
    activeInserters * 0.05 +
    machinesWithRecipes * 0.1 +
    farmPlotsWithCrops * 0.08 +
    max(0, powerSurplus / 100) * 0.1
)
-- Clamped to [0, 1]. 0 = nothing runs. 1 = full automated production.
```

These values are calculated from the snapshot's entity component data at serialization time and cached in `colonies[id].automationScore`. No ECS simulation needed.

### 13.5 Chunked Tilemap Adapter

The chunked tilemap exposes the same API as the fixed tilemap so all existing systems work unmodified:

```lua
-- src/world/space_tilemap.lua
SpaceTilemap.getTile(x, y)     -- loads chunk if needed, returns tile
SpaceTilemap.setTile(x, y, t)  -- loads chunk, sets tile, marks chunk dirty
SpaceTilemap.getTemp(x, y)     -- returns space ambient temp for tile
SpaceTilemap.getRoom(x, y)     -- returns room ID (ship interior rooms only)
```

The `World` module gets a thin dispatch layer:
```lua
function World.getTile(x, y)
    if GameState.activeMap == 'space' then
        return SpaceTilemap.getTile(x, y)
    end
    return fixedTilemap[y * mapW + x]  -- existing code
end
```

All existing systems call `World.getTile()` — they don't care whether it's backed by a fixed array or a chunk table.

### 13.6 Ship Entity Stamping (Landing/Launch)

**Landing (stamp ship onto colony map):**
```lua
function ShipManager.stampOntoColony(shipSnapshot, padX, padY)
    -- For each entity in shipSnapshot with a pos component:
    --   newX = padX + entity.pos.x - shipOriginX
    --   newY = padY + entity.pos.y - shipOriginY
    --   ECS.spawn() with remapped pos, all other components copied
    -- For each hull tile in ship grid:
    --   World.setTile(newX, newY, SHIP_HULL_TILE)
    -- Connect ship power grid to colony grid at pad adjacency
end
```

**Launch (extract ship from colony map):**
```lua
function ShipManager.extractFromColony(padX, padY, shipW, shipH)
    -- Collect all entities within ship bounding box at pad
    -- Translate pos components back to ship-local coordinates
    -- Serialize as ship snapshot
    -- Remove ship entities from colony ECS
    -- Restore landing pad tiles
end
```

### 13.7 Boarding: Side-by-Side Ship Maps

Boarding does NOT load two simultaneous tilemaps. Instead:

When boarding is initiated, the enemy ship's interior tilemap is **merged** onto the space tilemap adjacent to the player's ship. Both ships become part of one active tilemap — the space map. The breach point connects them. All combat, atmosphere, and pathfinding work on this single merged map.

When boarding ends (capture, retreat, destruction), the enemy ship tiles are removed from the space map and either despawned (destroyed) or converted to a captured ship entity.

This avoids the multi-tilemap problem entirely. The space tilemap is chunked and can accommodate arbitrary structures placed on it.

### 13.8 Ship Position vs Entity Position

The `ship` component stores navigation data (heading, velocity, fuel). The ship's position on the space tilemap uses the standard `pos` component on a ship anchor entity. Ship module buildings use standard `pos` components relative to the tilemap (same as colony buildings). No conflict — `pos` is always tilemap-relative. The `ship` component contains no `pos` field.

Corrected `ship` component:
```lua
ship = { shipId, tier, velocity, heading, fuel, hullHP }
-- Position comes from ECS.get(shipAnchorEntity, 'pos')
```

### 13.9 New ECS Components (Complete List)

All new components that must be added to `KNOWN_COMPONENTS`:

| Component | Fields | Purpose |
|-----------|--------|---------|
| `ship` | `shipId, tier, velocity, heading, fuel, hullHP` | Ship anchor entity — navigation state |
| `ship_module` | `shipId, systemType, operational, efficiency` | Ship system building (engine, cockpit, etc.) |
| `ship_crew` | `shipId, role` | Marks colonist as assigned to a ship role (pilot, gunner, etc.) |
| `weapon_mount` | `shipId, targetSystemType, targetEntityId, fireRate, accuracy` | FTL-style weapon targeting |
| `stealth` | `signatureReduction, active, powerDraw` | Active stealth module state |
| `space_suit` | `tier, durability, maxDurability, breached, evaCapable` | EVA suit state. New component separate from existing `suit` (which handles thermal protection). `suit` = thermal/environment gear. `space_suit` = vacuum/EVA gear. Both can coexist on one entity. Both need KNOWN_COMPONENTS entries (suit already has one). |
| `npc_ship` | `factionId, behavior, patrolRoute, hostility` | NPC ship AI state |

### 13.10 Save Format v3 Migration

**Version check fix:** `save.lua` line 34 must accept version 3:
```lua
if not data.version or data.version < 1 or data.version > 3 then
```

**v2 -> v3 migration:**
```lua
if data.version == 2 then
    data.version = 3
    data.activeMap = data.planet or 'erebus'  -- current planet becomes activeMap
    data.colonies = {}                         -- no colonies yet
    data.shipState = nil                       -- no ship yet
    data.discoveredPOIs = {}
    data.discoveredPlanets = { [data.planet or 'erebus'] = true }
    data.spaceChunkDiffs = {}
end
```

Existing v2 saves load normally as single-colony games with no space content.

### 13.11 GameState Initialization

All new fields initialized in `GameState.init()`:
```lua
GameState.activeMap = nil           -- set during new game setup or load
GameState.colonies = {}
GameState.shipState = nil
GameState.discoveredPOIs = {}
GameState.discoveredPlanets = {}
GameState.spaceChunkDiffs = {}
GameState.mammonaClaimed = false    -- set true by mammona_claim milestone
GameState.sealedDeep = false        -- set true by seal_deep milestone
GameState.extractionComplete = false -- set true by mammona_extraction milestone
```

### 13.12 Endgame Rework Implementation

**endgame.lua changes:**
- Remove `GameOverMod.triggerVictory()` calls from all four `activating` handlers
- Replace with `Milestone.complete(milestoneId)` calls to a new `src/sim/milestones.lua` module
- `Milestone.complete()` dispatches rewards:
  - `mammona_claim`: spawns reinforcement colonists, enables corporate supply drops (storyteller event), sets `GameState.mammonaClaimed = true`
  - `seal_deep`: sets anomaly to 0 permanently, disables anomaly events for this planet
  - `mammona_extraction`: spawns resource cache entities, unlocks corporate ship module recipes
- `launch_pad` building type: removed from `endgame.lua` entirely. Becomes a standard building that is a prerequisite tile for the `shipyard` building (new)
- Existing saves with `launch_pad` entities: `endgame_building` component stripped during v3 migration, building continues to exist as inert structure

### 13.13 Storyteller Isolation

The Storyteller must be scoped to the active map:

- On context switch (launch/land), serialize Storyteller state as part of the colony snapshot
- On restore, load Storyteller state from the snapshot
- Background colonies do NOT accumulate Storyteller threat — `Storyteller.step()` only runs on the active map
- Space gets its own Storyteller instance with space-specific event tables (distress signals, convoys, system malfaults)
- This is already how save/load works — `Storyteller.getState()` / `Storyteller.loadState()` are called during save/load. The context-swap reuses this.

### 13.14 Credits Currency

Add `credits` to `GameState.resources` as a new resource type:
```lua
credits = 0
```
- Earned: shipping contracts, bounties, selling at stations, milestone rewards
- Spent: station services (repair, refuel, medical), purchasing goods, bribes
- Persisted: standard resource serialization in save format
- Ground colonies: credits are colony-local (each colony has its own credit balance)
- Ship: carries its own credit balance

### 13.15 Space Planet Definition Location

The `space` planet definition is added to `planet_defs.lua` PLANETS table with full radiation fields:
```lua
space = {
    id = 'space',
    name = 'Space',
    subtitle = 'The Void Between',
    atmosphere = { ambientO2 = 0, ambientCO2 = 0 },
    thermal = { outdoorSnap = 1.0, undergroundBaseTemp = -270 },
    radiation = { ambientDose = 0.01, doseLethal = 5.0 },
    hermes = { enabled = false },
}
```

Added to `PLANET_ORDER` only if needed for internal iteration — NOT shown in planet selection UI (space is not a starting planet).

### 13.16 Chunk Key Format

Chunk keys use string format: `"chunkX,chunkY"` (e.g., `"5,-3"`). Generated via:
```lua
local function chunkKey(cx, cy) return cx .. ',' .. cy end
```

---

## 14. Implementation Phasing

This feature is too large for a single implementation pass. Recommended phases:

### Phase 1: Core Architecture
- Context-swap protocol (Save.snapshotToMemory / loadFromMemory)
- GameState extensions and v3 save migration
- Space planet definition
- Chunked tilemap with World API adapter
- Ship entity group (ship + ship_module components)
- Basic ship movement on space tilemap
- Launch/land state transitions (colony <-> space)
- Colony background tick (counter-based)

### Phase 2: Ship Building & Flight
- Mini reactor building
- Ship module buildings (cockpit, engine, life support, etc.)
- Shipyard building and construction flow
- Ship prebuilt layout system
- Scout ship discovery (map secret)
- Ship navigation (autopilot, fuel, sensors, fog of war)
- Ship interior building (same as colony building, on ship grid)

### Phase 3: Space Content
- Space POI generation (stations, derelicts, asteroid fields)
- Station docking and services UI
- NPC ship spawning and patrol AI
- Mobile caravans
- Credits currency and space economy
- Star map UI overlay
- Planet discovery mechanic

### Phase 4: Combat
- Ship-to-ship combat (FTL-style weapon targeting)
- Shield, weapon mount, sensor systems
- Damage model (hull breach, system damage)
- Power diversion during combat
- Boarding initiation (side-by-side map merge)
- Boarding combat (existing melee/ranged on merged map)
- Pirate faction combat behavior
- NPC ship behavior (UTC, Mammona, caravans)

### Phase 5: Stealth, Hazards & Polish
- Stealth/detection system
- Space suits and EVA
- Environmental hazards (debris, radiation, flares, micrometeorites)
- Storyteller space events
- Easter eggs (Xenolith hive-ship, Praxii stations)
- Endgame milestone rework
- Colony status panel from cockpit

---

*This document is the design source of truth for the Interplanetary Travel feature. Implementation begins with Phase 1 (core architecture) — the context-swap protocol must be proven before any feature work proceeds.*
