# Roguelite Defeat System — Design Spec

**Date:** 2026-03-20
**Status:** Approved
**Scope:** Rework colony defeat from a dead-end into a roguelite meta-progression loop

---

## Overview

Colony death is no longer game over. Mammona Mining Corporation doesn't abandon profitable sites — it sends another crew. Each failed colony leaves behind ruins, data, resources, and scars. The next deployment inherits the wreckage and builds on it. A global meta-currency (Mammona Requisition Points) accumulates across all runs and funds permanent upgrades and per-run bonuses.

**Core philosophy:** Death is not the end. Every failure makes the next attempt stronger. The planet remembers, and so does Mammona.

---

## 1. The Roguelite Loop

### Flow

```
All colonists dead (day 2+)
  → Defeat screen (stats + MRP breakdown)
  → "Mammona Redeployment Authorized" button OR "Load Save"
  → Planet Select (scarred cards, history panel, failed planet pre-selected)
  → Mammona Requisition Screen (spend MRP: permanent unlocks + per-run picks)
  → Colonist Drafting (new crew)
  → Landing Zone Picker (same map seed, old base visible as dim icon on minimap)
  → Drop onto map: ruins, data discs, crates, graves, fog reset
```

### Key rules

- **Unlimited redeployments.** Mammona never gives up on a planet. Every failure adds to the legacy.
- **Victory also awards MRP.** Completing a milestone on a planet with legacy history is the ultimate payoff.
- **"Continue Campaign" vs "New Game."** Campaign is the persistent MRP + planet history. New Game is a fresh slate.
- **Endless mode removed on death.** The roguelite loop replaces "press SPACE to continue in endless mode."

---

## 2. Legacy Data — What Carries Over

When a colony falls, the legacy system captures the following. On redeployment to the same planet, this data spawns into the world.

### 2.1 Map & Terrain

- Same map seed, same biomes, same cave layouts.
- **Full fog reset** — frost reclaims all visibility.
- Old colony buildings appear as **dim icons on minimap** (pierce fog), giving directional guidance.

### 2.2 Building Ruins

- Old structures spawn as degraded versions: 50% HP, some fully collapsed.
- Random 20-30% of buildings are missing entirely (destroyed by time/weather).
- Salvageable: deconstructing ruins returns partial resources.
- Power grid is dead — generator and all connections must be rebuilt.

### 2.3 Research Data Discs

Physical items that encode the old colony's research. Found scattered in ruins near research benches, labs, and server rooms.

**Three quality tiers:**

| Disc Quality | Source | Recovery |
|---|---|---|
| **Intact** | Tier 1-2 completed research | Full tech unlock after processing (~30s game time) |
| **Degraded** | Tier 3+ completed research | 50-75% progress head start, rest researched normally |
| **Partial** | In-progress research at death | Half of the progress that existed, degraded further |

**Fragility:** Discs can be destroyed by fire, explosions, or building collapse. Nemesis raiders who reach the ruins may loot or destroy them. Incentivizes reaching the old base quickly and carefully.

**Future expansion:** Data discs as rare loot in caverns/biocaves (ancient pre-collapse research), and in expedition sites from other fallen colonies.

### 2.4 Data Recovery Terminal (new building)

Required to read data discs. Without it, discs are inert inventory items.

- **Size:** 2x2
- **Research tier:** Mid-tier unlock
- **Cost:** Metal + components + circuit boards
- **Power:** 20W processing, 5W idle
- **Operation:** One colonist operates it (intellectual skill). Processes one disc at a time.

### 2.5 Stockpile Remnants

- 30-40% of old stockpile resources spawn as **lootable crates** scattered in/near old storage areas.
- Crates are physical items on the ground. Colonists haul them like any other item.

### 2.6 Fallen Colonist Graves

- Old colonists spawn as graves/skeletons at their death location.
- **Proximity mood effect:** "Remains of the fallen" (minor negative).
- **Interactable:** Can bury properly → removes negative mood, adds "Honored the dead" (positive mood).
- Carry their name and backstory for lore flavor.

### 2.7 Colony Name in Lore

- Storyteller and advisor reference the old colony by name.
- Triggered events: "You find a journal from [colonist name] of [old colony]. The final entry reads..."
- Narrative weight without mechanical impact.

---

## 3. Mammona Requisition Points (MRP)

Global meta-currency earned from every run (defeat or victory). Persists forever. Spent on permanent unlocks and per-run boosts.

### 3.1 Earning MRP

| Achievement | MRP |
|---|---|
| Per day survived | 1 |
| Per raid survived | 5 |
| Per research completed | 3 |
| Per colonist lost (over the whole run, not the final wipe) | 2 |
| Per building constructed | 1 |
| Boss damaged | 25 |
| Boss defeated | 50 |
| Milestone completed | 40 |
| First deployment to a planet | 10 |

### 3.2 Permanent Unlocks (buy once, always active)

Unlocked via MRP and organized into progression tiers (100, 250, 500, 1000 lifetime MRP thresholds reveal new rows).

**Genetic Program** (Mammona bio-augmentation):

| Unlock | MRP | Effect |
|---|---|---|
| Cold-Adapted Genome | 50 | All colonists: +1 hypothermia stage resistance |
| Enhanced Metabolism | 40 | Colonists eat 15% less |
| Rapid Clotting | 45 | Bleed rate reduced, wounds heal faster |
| Neural Plasticity | 60 | Skill learning 20% faster |
| Stress Inoculation | 35 | Mental break thresholds lowered |

**Corporate Knowledge Base** (institutional learning):

| Unlock | MRP | Effect |
|---|---|---|
| Tier 1 Research Archive | 30 | All Tier 1 research starts at 50% progress |
| Structural Engineering Protocols | 40 | Buildings start with +15% HP |
| Efficient Extraction | 35 | Mining yields +10% |
| Advanced Smelting Data | 50 | Steel refining unlocked from run start |
| Agricultural Database | 40 | Crop grow time reduced 10% |

**Operational Upgrades** (logistics/infrastructure):

| Unlock | MRP | Effect |
|---|---|---|
| Expanded Deployment | 75 | +1 starting colonist on all runs |
| Heavy Drop Pod | 60 | Increased starting resource package |
| Orbital Relay | 80 | Merchant caravans arrive earlier and more frequently |
| Deep Scan Array | 50 | Cave entrances visible through fog on new maps |

### 3.3 Per-Run Picks (consumed on use)

Purchased at the Mammona Requisition screen before each deployment. Spend as much or as little MRP as desired.

**Operative Augments** (applied to individual colonists):

| Pick | MRP | Effect |
|---|---|---|
| Combat Stims | 8 | +20% combat stats for one colonist |
| Mammona Datalink | 10 | +3 to one chosen skill for one colonist |
| Survival Package | 6 | Colonist starts with parka, medicine, weapon |
| Psi Dampener | 12 | Immune to first mental break |

**Deployment Bonuses:**

| Pick | MRP | Effect |
|---|---|---|
| Supply Drop | 10 | Extra starting resources (metal, food, components) |
| Prefab Shelter | 20 | Start with a small pre-built heated room |
| Advanced Toolkit | 15 | Start with research bench + Data Recovery Terminal |
| Satellite Scan | 12 | Reveal portion of map around landing zone |
| Ruin Survey | 8 | See exact contents of old colony ruins before landing |
| Threat Delay | 10 | First raid pushed back 5 days |
| Friendly Signal | 15 | Guaranteed refugee event in first 10 days |

---

## 4. SOS Beacon (new building)

Replaces the automatic Mammona Safety Net. Player-built last resort.

### Specs

- **Size:** 2x2
- **Research tier:** Mid-tier
- **Cost:** Metal + components + circuit boards
- **Power:** 15W idle, 50W when firing
- **Must be toggled ON** by the player — not automatic

### Behavior

1. Player builds and powers the beacon, toggles it ON.
2. When all colonists are **downed** (incapacitated, not dead yet), the beacon fires.
3. **30-second countdown** with visible flare effect and siren sound.
4. Drops 2-3 emergency colonists with basic gear near the beacon.
5. **One-time use per run** — beacon is destroyed after firing (burns out).
6. If all colonists **die** before the 30 seconds elapse, the beacon fails and the run ends via the roguelite loop.

### Power dependency

- **No power = no beacon.** If the generator is destroyed, an EMP event kills the grid, or a raid knocks out power infrastructure, the beacon cannot fire until power is restored.
- This creates real stakes around protecting power infrastructure.

---

## 5. Nemesis-Lite Threat System

### Named Enemy Persistence

- When a colony falls to a **raid**, the raid's captain (strongest enemy) gets recorded in legacy data.
- They receive a title: "Scavenger of [Colony Name]", "Butcher of [Colony Name]".
- On redeployment to that planet, they can appear leading future raids.

### Mechanical Buff (small)

- +10-15% HP and damage.
- Raids they lead path toward the old ruins (they know the location).
- They carry one looted item from the old colony (recognizable gear).

### Narrative Hooks

- Storyteller announces them: "[Name], who slaughtered the crew of [Colony], has been spotted nearby."
- Revenge kill: "The Butcher of [Colony] has fallen. The dead are avenged." + small hope boost.
- Satisfying without being mechanically mandatory.

### Non-Raid Deaths

- Colony killed by cold/starvation/disease: no nemesis spawns.
- Storyteller still references the cause: "The last crew froze on day 14. Your thermal readings are... similar."

### Cap

- Max 3 active nemeses per planet. Oldest retired if exceeded.

---

## 6. Planet Select Rework

### Scarred Planet Cards

- **First attempt:** Pristine planet art.
- **After each failure:** Card accumulates visual scarring — cracks, smoke, ruin overlays. Progressive degradation.
- **Deployment badge:** Small counter showing "Deployment 2", "Deployment 3", etc.
- **Planet is never locked.** Unlimited redeployments.

### History Panel

- Clicking a planet with prior deployments opens a scrollable timeline panel.
- Each entry shows:
  - Colony name
  - Days survived
  - Cause of death
  - Peak population
  - Notable achievements (raids survived, research completed, bosses fought)
- Final entry is always the active/next deployment.

---

## 7. Defeat Screen Rework

### Remove

- "Press SPACE to continue (endless mode)" — roguelite loop replaces this.
- Automatic Mammona Safety Net — replaced by SOS Beacon building.

### New Defeat Screen

- **Title:** "COLONY LOST" (or "SITE DECLASSIFIED" if many failures, for flavor)
- **Stats:** Days survived, colonists lost, raids survived, buildings constructed, research completed.
- **MRP Earned:** Itemized breakdown of points earned this run.
- **Two buttons:**
  - "Mammona Redeployment Authorized" → planet select
  - "Load Save" → save browser

### Victory Screen

- Same stats + MRP breakdown, triumphant tone.
- "Mammona commends your service. Requisition points awarded."
- Same two navigation options.

---

## 8. Persistence Architecture

### Meta-Save File

A new persistent file (e.g., `frosthold_campaign.dat`) separate from colony saves. Contains:

- **MRP balance** (current + lifetime earned)
- **Permanent unlocks** purchased
- **Planet history** (per planet: list of deployment records)
- **Nemesis roster** (per planet: named enemies with stats)
- **Unlock tier** (based on lifetime MRP thresholds reached)

### Legacy Record (per deployment, expanded from current colony_legacy.lua)

```lua
{
    colonyName,         -- string
    daysSurvived,       -- number
    peakPopulation,     -- number
    causeOfDeath,       -- string
    wealth,             -- number
    raidsSurvived,      -- number
    bossesKilled,       -- number
    timestamp,          -- os.time()
    resources,          -- snapshot of all resources at death
    completedResearch,  -- list of tech IDs completed
    inProgressResearch, -- list of {techId, progress%}
    buildings,          -- list of {defId, x, y, hp, depth}
    colonists,          -- list of {name, backstory, deathX, deathY, skills}
    nemeses,            -- list of {name, title, stats} from killing raid
    mrpEarned,          -- MRP awarded for this run
    x, y,               -- colony center / spawn location
    mapSeed,            -- preserved for terrain regeneration
}
```

### Ruin Spawning (on new deployment to same planet)

1. Load legacy record for this planet.
2. Regenerate terrain from `mapSeed`.
3. Spawn building ruins from `buildings` list (apply 50% HP, 20-30% random removal).
4. Spawn data discs from `completedResearch` + `inProgressResearch`.
5. Spawn resource crates from `resources` (30-40% of totals).
6. Spawn graves from `colonists` at their death locations.
7. Register nemeses for raid system.
8. Fog is fully reset; ruin positions marked on minimap.

---

## 9. Systems Modified

| System | Change |
|---|---|
| `game_over.lua` | Rework defeat/victory screens, remove endless-on-death, add MRP display, add "Redeployment" button |
| `colony_legacy.lua` | Expand legacy record significantly, add nemesis tracking, add ruin spawning logic |
| `game_state.lua` | Remove `mammonaSafetyNet` and `_safetyNetUsed`, add MRP fields |
| `planet_select.lua` | Add scarred card visuals, deployment counter, history panel |
| `save.lua` | Add meta-save (campaign file) for MRP + planet history + unlocks |
| `building_defs_core.lua` | Add SOS Beacon and Data Recovery Terminal definitions |
| `recruitment.lua` | SOS Beacon system (replaces safety net logic in game_over.lua) |
| `raids.lua` | Nemesis integration — named captains, pathing toward ruins |
| `research.lua` | Data disc processing integration |
| `main.lua` | New game flow: campaign mode, requisition screen, ruin spawning on world init |

### New Files

| File | Purpose |
|---|---|
| `src/sim/mrp.lua` | MRP economy: earning, spending, persistence, unlock tiers |
| `src/ui/requisition_panel.lua` | Mammona Requisition screen UI (permanent unlocks + per-run shop) |
| `src/ui/planet_history.lua` | Planet history timeline panel |
| `src/sim/ruin_spawner.lua` | Spawns ruins, discs, crates, graves from legacy data on new deployment |
| `src/sim/nemesis.lua` | Nemesis tracking, naming, stat buffs, storyteller integration |
| `src/building/sos_beacon.lua` | SOS Beacon building logic (or integrated into recruitment.lua) |
| `src/building/data_terminal.lua` | Data Recovery Terminal building logic |

---

## 10. What's Removed

- **Automatic Mammona Safety Net** — `mammonaSafetyNet` flag, `_safetyNetUsed` flag, auto-spawn of 2 colonists on first wipe, rescue overlay. All replaced by SOS Beacon.
- **Endless mode on death** — "Press SPACE to continue playing (endless mode)" removed from defeat screen. Endless mode remains accessible via settings/victory, just not as a death escape.
- **Static planet locking** — `def.locked` concept for "Coming Soon" planets remains, but no failure-based locking.
