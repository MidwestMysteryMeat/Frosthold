# FROSTHOLD — P2P Multiplayer Design Document

Session date: 2026-03-11
Status: Design phase — not yet implemented

---

## Overview

Three multiplayer modes built on a shared simulation core:

- **Offline** — solo, no networking (default)
- **Co-op** — 2-4 players share one colony over LAN (shipped, Phase 10)
- **Online** — each player runs their own colony, connected via P2P
  gossip mesh with CRDT-replicated metagame (planned, Phases 1-4)

Co-op and Online are fundamentally different architectures. Co-op is
host/client with one shared ECS and tilemap. Online is serverless P2P
where each node is authoritative for its own colony. Mode is chosen at
world creation and locked for that save.

The Online architecture exploits the fact that colony sims are
**embarrassingly parallel** — each colony is a self-contained simulation.
Inter-colony interactions (trade, raids, shared threats) are infrequent,
low-bandwidth, and tolerant of latency. No dedicated servers. No
infrastructure cost.

---

## Architecture

### Network Topology: Gossip Mesh

Each player maintains direct connections to 6-8 peers. Information ripples
through the mesh in ~log(N) hops. 100 players = ~400 total connections.

```
    A─B─C
    │╲│╱│
    D─E─F       Info propagates to all nodes
    │╱│╲│       within 3-10 seconds
    G─H─I
```

No full mesh (which doesn't scale) and no central hub (single point of failure).

### Peer Discovery

Options (zero cost):
- **Direct IP** — Player shares IP, other types it in. Works on LAN already
  via existing lua-enet code.
- **Steam Networking API** — Free for Steam games. Handles discovery, NAT
  traversal, and relay. Love2D can bind via LuaJIT FFI or C module.
- **Public DHT** — BitTorrent mainline DHT bootstrap nodes. Register game
  swarm. Free but slow discovery (30-60s).
- **Free lobby service** — Single Cloudflare Worker or equivalent holds a
  list of active player IPs. Trivial endpoint, zero cost at any realistic
  player count.

### NAT Traversal

- **STUN** — Query public STUN servers (e.g. stun.l.google.com:19302) to
  learn public IP:port. Free, ~50ms, invisible to player.
- **UDP hole punching** — Works for ~80% of NAT types. Both sides send UDP
  packets simultaneously, punching through NAT. lua-enet already uses UDP.
- **Restricted NAT (~15%)** — Hole punch still works, slightly slower.
- **Symmetric NAT (~5%)** — Hole punch fails. Fall back to Steam relay
  (free) or accept reduced peer count. Colony sim latency tolerance is
  extremely high — even 200ms relay is invisible at 20Hz sim tick with
  30s gossip intervals.

Players never see any of this. They click "Play Online", see a 1-3 second
loading screen, and are connected.

### Authority Model

```
YOUR NODE OWNS (authoritative):     SHARED (CRDT-replicated):
├─ Your colony                      ├─ Trade market prices
├─ Your colonists                   ├─ Overworld threat map
├─ Your tilemap                     ├─ Global war state
├─ Your resources                   ├─ Major Orders
├─ Your buildings                   ├─ Reputation scores
└─ Combat on your map               └─ Messages & echoes
```

Key principle: **the defender always simulates combat on their own map.**
Cross-colony raids are resolved by the defending node. No trust needed for
attacker claims.

---

## CRDT Library

### G-Counter (Grow-only Counter)

Each node has its own slot. Merge = take max per slot. Used for: creature
kill counts, expedition completions, contribution tracking.

```lua
-- Each node increments only its own slot
contributions[myNodeId] = (contributions[myNodeId] or 0) + kills

-- Merge from remote: take max per slot
for nodeId, count in pairs(remote.contributions) do
    local_contributions[nodeId] = math.max(
        local_contributions[nodeId] or 0, count
    )
end

-- Total = sum of all slots
```

No conflicts. No coordination. Order-independent. Nodes can be offline,
reconnect, merge, and converge to the same value.

### G-Set (Grow-only Set)

Used for: messages, death echoes. Items can be added but never removed
(pruning happens via TTL expiry, not deletion).

### LWW-Register (Last-Writer-Wins)

Used for: colony status, trade offers. Each write carries a timestamp.
Merge = keep the newest value.

---

## Feature 1: Colony Broadcasting

### Colony Digest

Every node broadcasts a lightweight summary every 10-30 seconds:

```lua
{
    id         = nodeId,
    name       = "Frosthold Prime",
    population = 12,
    wealth     = 4500,
    military   = 3,              -- threat tier
    day        = GameState.day,
    tradeOffers = { ... },       -- what you're selling
    tradeWants  = { ... },       -- what you're buying
    position    = { x, y },      -- overworld position
}
```

~200 bytes per digest. 8 peers × 200 bytes × every 30s = ~400 bytes/sec
baseline. Negligible bandwidth.

### Colony Browser UI

Players can open a panel showing all known colonies in the mesh:
name, population, wealth, distance, online status. Sorted by distance
or activity.

---

## Feature 2: Shared Overworld — Global War

### Threat Regions

The overworld map is divided into named regions. Each has a threat type
and a threat meter (0-100%) that rises over real-world time and falls
when players complete expeditions or kill creatures from that region.

```
┌─────────────────────────────────────────────┐
│            THE FROZEN WASTES                │
│                                             │
│   [Glacier Pass]     [Dead Forest]          │
│    Swarm: 78%         Eldritch: 34%         │
│    ████████░░          ███░░░░░░░           │
│                                             │
│   [Iron Reach]       [The Maw]              │
│    Beast Horde: 91%   Leviathan: 12%        │
│    █████████░          █░░░░░░░░░           │
└─────────────────────────────────────────────┘
```

Threat meters are G-Counter CRDTs. Contributions merge conflict-free
across all nodes. Escalation ticks based on wall-clock time so threats
progress even while individual players are offline.

When threat exceeds 80%, a Major Order auto-triggers.

If threat hits 100%, the region "falls" — all nearby colonies receive
intensified raids from that threat type until players push it back.

### Major Orders (Helldivers-style)

Shared objectives with deadlines and rewards distributed to all
participating colonies.

```
⚠ MAJOR ORDER: Push back the swarm at Glacier Pass
  Deadline: 48 hours
  Progress: ████████░░ 78% (347/500 kills)
  Reward: Thermal Core Cache (all participants)
```

**Algorithmic triggers (MVP):** When threat > 80% in any region, auto-
generate a Major Order from a template list. Deterministic — same inputs
produce same output on every node, so no coordinator is needed.

**Director triggers (advanced):** An elected narrator node can issue
custom Major Orders with narrative flavor, foreshadowing, and dynamic
difficulty adjustment (see Director System below).

### Contribution Tracking

Player actions that reduce regional threat:
- Completing expeditions to the threatened region
- Killing creatures that originate from that region
- Sending colonists on military campaigns
- Destroying lairs linked to that region

Each contribution increments the player's G-Counter slot for that region.
All nodes converge on the same total via gossip merge.

---

## Feature 3: Director System (Elected Narrator)

### Overview

One node is elected as the "Director" — a single source of truth for
narrative events. Equivalent to Helldivers' "Joel" game master. The
director produces signed events that propagate via gossip.

### Leader Election

Deterministic — no voting protocol needed. Every node computes the same
function on the same node list and gets the same answer:

```lua
function electDirector(activeNodes)
    -- Hash of (nodeId + current epoch hour) rotates director hourly
    local epoch = math.floor(os.time() / 3600)
    local best, bestScore = nil, math.huge
    for _, node in ipairs(activeNodes) do
        local score = hashInt(node.id .. tostring(epoch))
        if score < bestScore then
            bestScore = score
            best = node
        end
    end
    return best
end
```

Director rotates hourly so no single player bears the load permanently.

### What the Director Does

- Issues Major Orders with narrative flavor (foreshadowing, misdirection)
- Triggers surprise events (creature migrations, blizzard fronts)
- Adjusts difficulty dynamically (if community is struggling, ease escalation)
- Sequences narrative beats (defeating swarm triggers eldritch response)

### Verification

Other nodes verify director events before accepting:
1. Is this from the actual elected director? (check against election result)
2. Does the signature match? (tamper detection)
3. Is it reasonable? (can't fabricate a crisis in a region at 10% threat)

### Failover

Director disconnects → peers notice within 30s → all nodes recompute
election with updated node list → new director picks up immediately.
No state lost because global state lives in the CRDT, not on the
director node.

### Hybrid Approach (Recommended)

Use deterministic rules for mechanical stuff (threat escalation, contribution
counting, Major Order triggers). Use the director only for narrative flavor
(event text, surprise escalations, dynamic difficulty). Core war mechanics
keep running identically on every node even if the director is offline.

---

## Feature 4: Inter-Colony Trade

### Trade Protocol

1. Player A broadcasts trade offer: "50 metal for 30 food"
2. Offer propagates via gossip, visible to all nodes
3. Player B accepts
4. Both nodes deduct/add simultaneously
5. If either side disconnects mid-trade, both revert (timeout)

### CRDT Trade Market

Colony trade offers are LWW-Registers. Each node's current offer
overwrites their previous one. All nodes see a consistent market
of available trades. Prices emerge from supply/demand across the
colony network.

---

## Feature 5: Cross-Colony Raids

### Flow

1. Player A's threat system (or the Director) targets Player B
2. A sends raid manifest to B: `{ creatures = {...}, budget = 450 }`
3. **B's node simulates the raid on B's tilemap** (B is authoritative)
4. B reports results back to A: casualties, loot taken
5. A can't cheat because B ran the combat
6. B can't profitably lie — they're the one being raided

Uses existing raid system (`src/sim/raids.lua`) with minimal changes.
The raid manifest is just a creature list and budget — same data the
existing raid spawner already consumes.

---

## Feature 6: Dark Souls-Style Asynchronous Multiplayer

### Messages

Players write messages using a template system and place them on the
shared overworld map. Other players see them when exploring or planning
expeditions.

Templates (colony-flavored):
```
"Beware of [threat] near [location]"
"[resource] shortage ahead"
"Try building [building] before day [number]"
"Don't forget [system]"
"[number] colonists lost to [cause]"
```

Message data: ~50 bytes (template ID, word slot IDs, coordinates,
rating counter). Stored as a G-Set CRDT. Players can rate messages
(helpful/unhelpful) via PN-Counter. High-rated messages propagate
further; low-rated ones expire after 24 hours.

### Colony Death Echoes (Bloodstains)

When a colony falls, a "death echo" is placed on the overworld:

```
☠ Colony "Last Light" — Fell on Day 47
  12 colonists lost to coordinated beast assault
  [Inspect]
```

Inspecting shows:
- The colony's building layout at time of death
- What killed them (raid type, creature, starvation, disease)
- How many days they survived
- Optional: ghost replay of their final moments

Death echoes are colony snapshots (~500 bytes-1KB) stored in a G-Set
CRDT. They persist until pruned by age (e.g. 7 days).

### Colony Ghosts

Faint outlines of other colonies visible on the overworld map. Not
live — periodic snapshots showing base layout and size. Creates a
sense of shared world without real-time synchronization.

### Whispers

Atmospheric text that occasionally floats across the screen, generated
from gossip digest changes:

```
"Colony 'Iron Keep' just lost 3 colonists to frostlung..."
"A colony to the north completed the Glacier Pass order..."
"Someone discovered a thermal vent at the Dead Forest..."
```

No new system needed — formatted colony digest diffs rendered as
ambient text.

---

## Infrastructure Cost

| Component             | Solution                          | Cost |
|-----------------------|-----------------------------------|------|
| Game servers          | None — each player hosts own sim  | $0   |
| Database              | None — state is in CRDTs on nodes | $0   |
| STUN servers          | Google's public STUN              | $0   |
| NAT relay             | Steam API or skip                 | $0   |
| Discovery             | Steam API or free Cloudflare Worker | $0 |
| Bandwidth             | Players' own internet             | $0   |
| DDoS protection       | No central target to attack       | $0   |
| **Total**             |                                   | **$0** |

---

## Anti-Cheat

The weak point of P2P. Mitigations:

- **Defender authority for combat** — raids simulate on the defender's node.
  Attacker can't fake results.
- **Contribution caps** — Maximum kills/contributions per node per hour.
  Prevents inflating global war progress.
- **Peer attestation** — Multiplayer expedition members co-sign kills.
  Solo claims weighted lower.
- **Statistical outlier detection** — Flag nodes reporting 10x average
  contribution rates.
- **Social pressure** — For cooperative colony sims, cheating incentive
  is low. You're all fighting the same threats.

Not bulletproof, but sufficient for a cooperative PvE colony sim.

---

## Scale Ceiling

This model works well up to ~500-1000 concurrent players. Beyond that,
gossip propagation delay grows and CRDT merge traffic increases. At
that scale, you'd need supernode election (some nodes take on more
routing responsibility). True MMO scale (10K+) eventually needs
dedicated infrastructure somewhere.

For a colony sim community, 500 interconnected colonies is a thriving
world.

---

## Platform Support

Love2D is cross-platform out of the box:

| Platform   | Status | Notes                                    |
|------------|--------|------------------------------------------|
| Windows    | Works  | Current dev platform                     |
| Linux      | Works  | Ship .love file, players install Love2D  |
| macOS      | Works  | Wrap .love in .app bundle                |
| Steam Deck | Works  | Native Linux, no Proton needed           |

Runtime: **LuaJIT** (ships with Love2D 11.4). Implements Lua 5.1
semantics with JIT compilation (10-30x faster numerics).

### Minimum Specs

| Component | Minimum                      | Reason                          |
|-----------|------------------------------|---------------------------------|
| CPU       | Any from ~2012+              | 20Hz ECS tick on 128x128 map    |
| RAM       | 2GB (game uses ~100-200MB)   | Lua tables + sprite atlas       |
| GPU       | OpenGL 2.1 (integrated OK)   | 2D sprite rendering             |
| Storage   | ~50MB                        | 379 PNGs + Lua + Love2D runtime |
| Network   | Any broadband or hotspot     | ~400 bytes/sec baseline         |

---

## Implementation Phases

### Phase 1 — MVP: Gossip Mesh + Shared Threat Map (~1800 lines)

New files:
- `src/net/gossip.lua` (~400 lines) — Peer mesh, peer exchange, gossip protocol
- `src/net/nat.lua` (~200 lines) — STUN queries, hole punching helpers
- `src/net/crdt.lua` (~200 lines) — G-Counter, G-Set, LWW-Register, merge functions
- `src/net/global_war.lua` (~500 lines) — Threat regions, contributions, Major Orders
- `src/ui/war_map.lua` (~300 lines) — Overworld threat map UI
- Extend `src/net/network.lua` (~150 lines) — Colony digest broadcasting
- Extend `src/persistence/save.lua` (~50 lines) — Network state persistence

Validates the core concept. Two+ colonies see shared threat levels and
can cooperate on Major Orders.

### Phase 2 — Trade + Cross-Raids (~800 lines)

- `src/net/trade_net.lua` (~300 lines) — Trade protocol, atomic swaps
- `src/net/raid_net.lua` (~250 lines) — Raid manifest sending, result reporting
- Extend `src/ui/trade.lua` (~200 lines) — Network trade UI
- `src/ui/colony_browser.lua` (~250 lines) — Colony list panel (optional)

### Phase 3 — Async Multiplayer: Messages + Echoes (~600 lines)

- `src/net/messages.lua` (~250 lines) — Template messages, rating, CRDT storage
- `src/net/echoes.lua` (~200 lines) — Death echoes, colony snapshots
- `src/ui/messages.lua` (~150 lines) — Message placement/reading UI

### Phase 4 — Director System (~300 lines)

- `src/net/director.lua` (~300 lines) — Leader election, narrative events,
  verification, failover

### Recommended Approach

Build Phase 1. Test with two LAN instances. Decide if it's fun. If yes,
continue to Phase 2. Don't build the director until the algorithmic
version feels repetitive. Don't build trade until the shared threat
map hooks players. Build the plumbing first, add the poetry later.

---

## Feature 7: MGS5-Style Colony Raids (FOB Invasions)

### Overview

Players' colonies serve as defense profiles — wall layout, turret positions,
chokepoints, colonist equipment. Other players (or AI) can raid your colony
using your actual layout, like Metal Gear Solid V's Forward Operating Bases.

### Defense Snapshot

When your colony is targeted, a compressed defense snapshot is sent:

```lua
{
    tilemap   = compressedTiles,  -- wall/door layout (~1-2KB compressed)
    buildings = { ... },          -- turret positions, generator, traps
    defenders = { ... },          -- colonist positions, equipment, skills
    -- NOT included: resources, research, internal state
}
```

~2-5KB per snapshot. Sent once per raid, not continuously.

### Two Raid Modes

**Async (defender offline):**
1. Director or threat system selects target colony
2. Target's defense snapshot sent to attacker
3. Attacker's node spawns the raid using defender's layout
4. Creatures navigate defender's actual walls and turrets
5. Defender's colonist AI defends automatically (same as normal raids)
6. Result reported back. Defender sees report next login.

**Live (defender online):**
1. Same setup, but defender gets real-time alert
2. Defender can reposition colonists, activate turrets, seal doors
3. Existing raid gameplay — just creature source is another player

Both modes use the existing raid system. The only difference is where the
creature manifest comes from (another player vs the storyteller).

---

## Feature 8: AI Director

### Tier 1 — Arc-Based State Machine (Recommended)

No AI model needed. A narrative state machine with arc structure, memory,
reactive pacing, and anti-repetition. Runs deterministically on every node.

**Arc cycle:** calm → foreshadowing → rising threat → escalation → climax → calm

Each arc lasts 3-7 real-world days. The director:
- Foreshadows threats before they trigger ("Scouts report movement...")
- Reacts to player performance (winning → throw a curveball, struggling → offer help)
- Tracks narrative state to prevent repetition (no two identical arcs in a row)
- Paces events based on community morale derived from colony stats

This is how Left 4 Dead's AI Director works — a state machine, not ML.
Players can't tell the difference when it has enough variety and memory.

### Tier 2 — LLM-Flavored Text (Optional Enhancement)

Algorithm decides WHAT happens. LLM generates HOW it's described.
One API call every 4-8 hours (~$0.01/day). Director node makes the
call, gossips the text. Falls back to templates if no API key.

### Tier 3 — Full LLM Director (Not Recommended)

Overkill. Expensive at scale, hard to make deterministic. Tier 1
produces 95% of the dramatic effect at 0% of the cost.

---

## Feature 9: Modding System

### Core Principle

Mods that don't touch shared state are always compatible. Mods that add
to shared state use graceful fallback handling.

### Compatibility Tiers

```
ALWAYS COMPATIBLE (no protocol impact):
├─ UI reskins, color schemes, sound replacements
├─ Camera mods, zoom, QoL overlays
├─ New colonist names/backstories (local text)
└─ Single-player-only content (scenarios, maps)

COMPATIBLE WITH FALLBACK:
├─ New buildings → other nodes render as grey box
├─ New creatures → substituted with vanilla equivalent in raids
├─ New resources → hidden from trade offers on vanilla nodes
├─ New research → local only
└─ Balance tweaks → local simulation only

INCOMPATIBLE:
├─ Modified CRDT merge logic
├─ Changed gossip protocol format
└─ Altered threat escalation rates
```

### Mod Loading

```
mods/
├─ better_ui/
│   ├─ mod.lua         ← manifest + init
│   └─ ui_overrides.lua
├─ more_creatures/
│   ├─ mod.lua
│   ├─ creatures.lua   ← adds to creature registry
│   └─ sprites/
```

Mods are Lua files that hook into a public ModAPI:

```lua
-- mod_api.lua: registries mods can extend
ModAPI.creatures = {}   -- mod-added creature defs
ModAPI.buildings = {}   -- mod-added building defs
ModAPI.recipes = {}     -- mod-added recipes
ModAPI.hooks = {        -- event hooks mods can subscribe to
    onColonistSpawn = {},
    onBuildingPlaced = {},
    onCreatureKilled = {},
    onRaidStart = {},
}
```

Lua makes this nearly free — mods are table inserts into existing
registries. The ECS is already table-driven.

### World Mod Policies

World hosts set mod policy on creation:
- Vanilla only
- Cosmetic mods OK
- All mods OK (unknown items → fallback rendering)
- Required mod pack (specific mods + versions)

### Protocol Versioning

Colony digests include protocol version and mod manifest. Nodes with
different protocol versions can't merge CRDTs. Mod content differences
are handled gracefully via unknown-item fallback, not by blocking
connections.

---

## Scaling at RimWorld Player Counts (60K-100K)

### What Breaks at Scale

- **CRDT state size**: G-Counters with 100K slots per counter. Merging
  becomes expensive.
- **Gossip volume**: 100K colony digests = 20MB total state to propagate.
- **Discovery**: Finding peers in a 100K pool needs structure.

### Solution: World Sharding + Global Metagame

```
100,000 concurrent players
        │
  100-200 "Worlds" of 500-1000 each
        │
  ┌─────┼─────┐
  ▼     ▼     ▼
World  World  World    Each = independent gossip mesh
"Ash"  "Iron" "Void"   Own threat map, orders, trade
 500    500    500
        │
  World supernodes form second-tier mesh
        │
  Global metagame: aggregated world summaries
  "143 worlds participating, 78,432 total kills"
```

Each world is the 500-player mesh that already works. World sharding
is a UI change (world selection screen) + a lightweight world directory,
not a protocol rewrite. Gossip code inside each world doesn't change.

**CRDT scaling**: Per-world aggregation reduces 100K counter slots to
~200 (one per world). Merge cost drops 500x.

### Scaling Roadmap

| Players     | Architecture                        |
|-------------|-------------------------------------|
| 1-500       | Flat gossip mesh                    |
| 500-5,000   | World sharding (5-10 worlds)        |
| 5,000-50K   | More worlds (50-100)                |
| 50K-100K    | 200 worlds + global metagame layer  |
| 100K+       | Regional world clusters             |

---

## Game Modes

The game is a complete, offline single-player experience by default.
Multiplayer is a separate opt-in choice at world creation, not woven
into the core game. Three distinct modes share the same simulation
engine but wire up networking differently.

```
MAIN MENU
  New Colony
    Mode: [Offline ▼]
          ├─ Offline  — solo, no networking
          ├─ Co-op    — shared colony, LAN/direct IP
          └─ Online   — own colony, P2P metagame
```

Mode is chosen at world creation and locked for that save.

### Offline (default)

- Zero networking code loaded. Zero internet requirement.
- Full game: colony sim, raids, expeditions, research, storyteller.
- Can play indefinitely without ever seeing multiplayer.
- Save files are local and never uploaded.

### Co-op (shared colony)

- 2-4 players control the **same colony** on the **same tilemap**.
- Host/client architecture over LAN or direct IP (lua-enet).
- Host is authoritative. Clients send actions, host validates and
  broadcasts state deltas at 10Hz.
- All players see each other's cursors, share colonists, share
  resources. Equal control — no permission roles.
- Uses existing `network.lua` + `shared_control.lua`.
- If the host disconnects, the session ends. Clients can continue
  offline from their last-synced state.
- No internet required (LAN or direct IP).

| Aspect | Co-op |
|--------|-------|
| Tilemap | One shared |
| ECS | One shared (host authoritative) |
| Authority | Host owns all state |
| Colony count | 1 |
| Player count | 2-4 |
| Network | LAN host/client, reliable + unreliable channels |
| Save | Host saves. Clients get full sync on join |

### Online (separate colonies, shared metagame)

- Each player runs their **own colony** on their **own tilemap**.
- P2P gossip mesh — no dedicated servers, no host.
- Each node is authoritative for its own colony.
- Shared state (CRDT-replicated): threat map, trade, war state,
  messages, death echoes.
- Joins a world -> cooperative PvE metagame activates.
- Can disconnect and return at any time. Colony continues offline,
  re-merges CRDT state on reconnect.

| Aspect | Online |
|--------|--------|
| Tilemap | One per player (own colony) |
| ECS | One per player (local authority) |
| Authority | Each node owns its own colony |
| Colony count | 1 per player, up to 500 per world |
| Player count | Unlimited (gossip mesh scales) |
| Network | P2P gossip, CRDT sync, ~400 bytes/sec |
| Save | Local. CRDT state merges on reconnect |

### Mode comparison

```
              Offline    Co-op         Online
Tilemap       local      shared        per-player
Authority     local      host          per-node
Network       none       LAN h/c       P2P gossip
Trade         n/a        n/a (shared)  inter-colony
Threat map    n/a        n/a           CRDT shared
Colony death  game over  game over     rescue window
Save          local      host          local + CRDT
```

The entire networking layer is behind `GameState.multiplayerMode`
(`nil`/`'coop'`/`'online'`) and loaded via pcall. If networking
modules aren't loaded, nothing calls them, nothing breaks. The
online multiplayer layer reads colony state (population, wealth,
kills) but never writes to core sim state. Co-op networking writes
are host-validated actions only.

### PvE by Default — PvP Opt-In at World Creation

All multiplayer interaction is cooperative by default:
- **Shared threat map** — fight global threats together
- **Major Orders** — cooperative objectives with group rewards
- **Trade** — voluntary resource exchange between colonies
- **Messages / echoes** — help each other with tips and warnings
- **Cross-colony raids** — AI-generated creature waves that use another
  colony's defense layout for variety, NOT player-initiated attacks

In default PvE worlds, players cannot:
- Raid each other's colonies
- Steal from each other
- Sabotage or grief other colonies
- Send hostile creatures to other players

**PvP toggle (world creation only):**

```
CREATE WORLD
  Name: [Ashlands         ]
  PvP:  [OFF ▼]
        ├─ OFF  — purely cooperative, no player attacks
        └─ ON   — players can raid each other's colonies (MGS5-style)
```

PvP is set at world creation and cannot be changed after. Players see
the PvP status before joining. PvP worlds are clearly labeled in the
world browser so no one joins one by accident.

When PvP is ON:
- Players can send raid manifests to other colonies
- Defender's node simulates combat (defender is authoritative)
- Optional retaliation system (raid someone → they can raid you back)
- Resource stakes are capped (can't wipe someone's entire stockpile)

The only competitive element in PvE worlds is optional leaderboards
(days survived, creatures killed, colonies thriving) — visible but
with no gameplay impact.

---

## Design Decisions (Finalized 2026-03-12)

### Networking
- **Discovery:** All three options available — Steam Networking (primary),
  raw UDP+STUN (platform-independent), direct IP (LAN/friends)
- **Offline sync:** Passive contributions while offline. Colony military
  strength contributes at reduced rate. Rewards accumulate.

### Colony Death
- **Rescue window system:** 24-hour real-time timer after colony falls.
  Other players can send aid (resources, colonists). Aid threshold scales
  with colony size. Fallen player can watch + send one broadcast plea.
  If rescue fails, death echo remains as permanent overworld marker.

### Economy
- **Trade:** Direct offers on a trade board. "Selling 50 metal for 30 food."
  Another player accepts, resources swap. No complex market simulation.
- **Major Order rewards:** Tiered thresholds — Bronze (10+ kills),
  Silver (50+), Gold (100+). Everyone gets at least bronze. Motivating
  without being punishing to smaller colonies.

### Overworld
- **Threat regions:** Procedural, seed-based from world name. Same world
  name = same map. 4-8 regions scaled by player count (< 100 players = 4,
  500 players = 8).
- **Map presentation:** Hex grid. Regions are hex clusters. Colonies occupy
  hexes. Clear spatial relationships.
- **Colony positioning:** Proximity matters. Closer colonies to a threat
  region face harder raids and higher intensity. Strategic positioning.
- **World cap:** 500 colonies per world. Proven gossip mesh scale.

### Async Multiplayer (all enabled)
- Template messages with rating system
- Death echoes (bloodstains) with colony layout inspection
- Whispers (ambient floating text from gossip diffs)
- Colony ghosts (periodic snapshots on overworld)

### AI Director
- **Tone:** Grim and urgent. Frostpunk/Dark Souls atmosphere.
- **Text:** Hand-written templates with variable slots. No LLM dependency.
  Zero cost, fully offline-capable.
- **Pacing:** Director arc system handles all pacing. No fixed calendar
  events or seasonal rotation. Organic and unpredictable.

### Modding
- **Architecture:** Full Lua sandbox. Mods can override any module via
  load-order system. Maximum power for modders.
- **Conflict handling:** Load order priority. Player sets order manually.
  Later mods override earlier ones. (Skyrim/RimWorld model.)
- **Network compatibility:** Protocol version check. Unknown mod content
  gets graceful fallback (grey boxes, vanilla substitutes).

### PvP
- **Default:** PvE only. No player attacks.
- **Opt-in:** World creator can enable PvP at creation. Locked after.
  Clearly labeled in world browser.
- **Raid model:** Snapshot raids with colonist raiding parties. Attacker
  picks 3-6 colonists from their colony (with real skills, equipment,
  weapons) and a strategy (breach/sneak/rush). Receives defender's
  colony layout (~5KB). Attacker's node rebuilds the layout as a battle
  arena. AI raiders vs AI defenders. Attacker watches the fight.
  Results applied to both colonies:
  - Wounded raiders return with injuries
  - Killed raiders are permanently dead
  - Captured raiders become defender's prisoners
  - Killed defenders are dead in their colony
  - Stolen resources deducted from defender
  Real stakes on both sides. Works online or offline.
- **Raid objectives:** Attacker picks an objective before launching:
  'steal resources', 'capture colonists', or 'destroy generator'.
  Raider AI prioritizes the chosen objective.
- **Raid cooldown:** 48 real-world hour cooldown per target. Can't
  raid the same colony twice in that window. Can raid different
  colonies freely. Prevents pile-on griefing.

### Colony Viewing
- **Snapshots only.** Frozen-in-time views updated every 5 minutes.
  See buildings, walls, colonist positions (~5-10KB per snapshot).
  Inspect from the overworld hex map. Atmospheric, cheap, async.

### Timeline
- Fix remaining gaps (eldritch nodes save, taming save, storyteller log)
- Stability pass and full playtest
- Then begin Phase 1 networking

---

## Open Questions

- Mobile/web companion app for checking war map status?
- Nuclear deterrence metagame (MGS5-style thermal bombs)?
- Should spectating other colonies be possible during rescue wait?
