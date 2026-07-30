# V3 Procedural Lore Generator — Design Specification

## Overview

Complete rewrite of the Frosthold procedural content generator. 100% template-based, no LLM, no AI disclosure needed. Rivals Dwarf Fortress and RimWorld in procedural narrative depth. All content grounded in the canonical lore bible.

**Goal:** Generate interconnected, lore-accurate narrative content (NPCs, quests, datapads, locations, factions, relationships) with divergence tracking, overnight batch capability, and zero repetition.

**Quality target:** 100/10. Every piece compelling. Deep variety. No repetition. Tone-accurate. Lore-consistent.

**Tone references:** The Thing, Dead Space, Aliens, Blade Runner, Annihilation, Color Out of Space, The Void, The Ritual, Terminator, Philip K. Dick, RimWorld, Dwarf Fortress.

---

## 1. Pool Architecture

### Structure

All pools are **structured dicts**, not flat lists. A faction is a name + type + relationships + territory + secrets + associated tone. This structure enables cross-referencing without a world-state simulation.

```python
FACTIONS = {
    "mammona": {
        "name": "Mammona Corporation",
        "type": "megacorp",
        "subsidiaries": ["Mammona Mining", "MasTema Incorporated", "BioVault Inc.", "Mammona Logistics", "Mammona Construction"],
        "territory": ["Erebus", "Gaia A^1x", "Paxtera Prime", "Nerthus-9", "Nemaea"],
        "rivals": ["black_maw", "void_serpents", "iron_shadow"],
        "secrets": [
            "approved the Fall of Foras",  # colony called both "Fortuna" and "Foras"; canonical event name is "Fall of Foras"
            "cataloging planets matching Baldrungen's biological profile",
            "your crew is a deliberate probe to provoke Erebus's response",
        ],
        "tone": "corporate_dystopia",
        "slogan": "Building Tomorrow's Foundation",
    },
    ...
}
```

Same pattern for locations (planet + type + features + threats + connected_factions), creatures (origin + behavior + escalation_tier), items (category + origin + lore_significance), and NPCs (when pre-seeded).

### 45 Tones

Organized into families for blending:

**Horror (11):**
dread, slow_dread, sudden_dread, cosmic_horror, body_horror, quiet_terror, survival_horror, folk_horror, psychic_contamination, the_uncanny, wrongness

**Emotional (10):**
melancholy, grief, tender, mania, dissociation, nostalgia, guilt, shame, hollow_joy, bitter_hope

**Psychological (9):**
paranoid, isolation, claustrophobia, agoraphobia, identity_erosion, gaslighting, obsession, sleep_deprivation, hypervigilance

**Genre (8):**
noir, military, religious_fervor, cult_devotion, corporate_dystopia, frontier_grit, gallows_humor, clinical

**State (7):**
desperate, numb, resigned, furious, defiant, manic_energy, exhaustion

Each tone has 6+ sensory details (~270 total).

Quests and datapads support **tone blending**: primary tone (80%) + secondary tone (20%). A survival_horror quest with a tender secondary tone has one human moment in the terror — that's what makes it feel real.

---

## 2. Tripled Content Pools

All content pulled from the canonical lore bible. Target counts:

| Pool | v2 Count | v3 Target | Source |
|------|----------|-----------|--------|
| Tones | 15 | 45 | Genre analysis + emotional granularity |
| Sensory details | ~86 | ~270 | 6+ per tone |
| First names (M) | ~75 | ~100 | Diverse global + lore canonical |
| First names (F) | ~65 | ~100 | Diverse global + lore canonical |
| First names (NB) | ~20 | ~25 | Expanded |
| Last names | ~70 | ~80 | + MacReady, Dranth, Venin, Rathmore, Vale |
| Jobs | 39 | ~120 | Mammona, Erebus, criminal, shipboard roles |
| Factions | 20 | ~40 | All canonical + generated fringe groups (see fringe generation rules below) |
| Locations | 28 | ~80 | Every canonical location + sub-locations by planet |
| Items | 23 | ~70 | Mammona corporate, precursor, personal, contraband, brands |
| Events | 20 | ~60 | Fortuna-era, recent history, colony-level, personal |
| Traits (positive) | 20 | ~60 | + Erebus-specific, faction-marked |
| Traits (negative) | 20 | ~60 | + contamination, psychological |
| Traits (special) | 18 | ~54 | + came-back-wrong, death-echo, tissue-drift |
| Trait conflicts | 10 | ~30 | All contradictory pairs |
| Habits | 24 | ~72 | Lore-grounded behaviors |
| Physical details | 20 | ~60 | + voidbloom stains, Thalassa brands, contamination |
| Debts | 12 | ~36 | Mammona contracts, faction debts, moral debts |
| Secrets | 20 | ~60 | Tiered: colony, corporate, cosmic |
| Consumer brands | 8 | ~20 | StarByte, GustoGrain, ZapFizz, TaoTray, ChocoBlast (product/flavor generation only) |
| Dialogue fragments | ~80 | 300+ | By tone x context x trait modifier |

### Pool Details

**Jobs (~120)** organized by domain:
- Mammona corporate: quota enforcer, contract auditor, expendability assessor, neural chip technician, cryo pod operator, anomaly surveyor, sector compliance officer
- Erebus operations: bore shaft monitor, thermal core extractor, precursor ruin mapper, voidbloom harvester, contamination screener, skinwalker tracker, permafrost geologist
- Criminal/fringe: Eclipse's End pit fighter, Hyades bazaar dealer, warp key courier, Dustweaver handler, descent pod jockey, contraband chemist
- Shipboard: warp navigator, hull crawler, void welder, cargo manifest forger, cryo bay attendant
- Colony standard: miner, engineer, medic, mechanic, surveyor, cook, security contractor, drill operator, logistics tech, cargo hand, field researcher, comms operator, pilot, welder, systems tech, quartermaster, enforcer, deep diver, automaton tech, moisture farmer, caravan guard, salvager, smuggler, debt collector, chaplain, waste processor, atmospheric tech, botanist, geologist, demolitions specialist, cryogenics technician, xenobiologist, structural analyst, reactor operator, sanitation officer, corpse handler, vent crawler, ice cutter

**Locations (~80)** organized by planet:
- Erebus: colony sectors A-G, deep bore sites 1-5, precursor ruin clusters, skinwalker territory, the north ridge, thermal vent fields, frozen wreckage fields
- Gaia A^1x: Foras ruins, Acedia (City of Rot), Nyxport, the Maw of Foras, Kennedy landing site
- Rhea-2: Hyades bazaar, Pale Moon Shrine, dune ruins, Solar Nomad camp trails, buried war machines, the vermilion wastes
- Morvos: Karnaith upper towers, Karnaith lower industrial, Eclipse's End arena, the Gutter's Pearl, acid storm shelters
- Nerthus-9: Thalassa Deep wings A-F, descent pod bay, flooded sectors, deep water observation, Warden's quarters
- Nemaea: Dyson Sphere ruins, automaton foundries, sealed caverns, fossilized megastructures
- Paxtera Prime: factory farms, labor camps, AgroTech headquarters, worker barracks
- Orbit/Space: Hub 71 (StarByte), relay stations, derelict ships, warp gate approaches, Mammona supply depots (accessible via `--planet orbit`)
- UTC Inner Rim: Novaris-3 / Vanguardus (Vanguard Alliance HQ, surveillance state — appears in backstories and corporate memos, not direct gameplay)

**Note:** Gaia A^1x locations are **reference-only**. The generator must not create new sub-locations or events on this planet. Foras, Shaft 12, the Maw, and all Fortuna-era details are locked lore — referenced but never expanded.

**Fringe faction generation:** Non-canonical factions are generated using curated naming pools: `[Adjective] [Noun]` (e.g., "Pale Circuit", "Ashen Compact", "Iron Meridian"). Required fields: territory (must not overlap canonical faction home territory), size (cell/crew/network), type (criminal/religious/paramilitary/workers_collective/smuggling_ring). Fringe factions fill the gap between ~20 canonical factions and the ~40 target.

**Brands vs. corporations:** Consumer brands (StarByte Vends, GustoGrain, ZapFizz, TaoTray, ChocoBlast) are for item/flavor generation — Sunny Fizz cans, NutriLoaf wrappers, ShockPop empties. Corporate entities (Fortune Arms & Munitions, NexLink Communications, Orbis Energy, TerraGen Pharmaceuticals, Paxtera AgroTech, OmniCorp Shipping) belong in the factions pool and are used for backstory/quest generation, not product references.

**Secrets (~60)** tiered by danger:
- Colony-level: someone's skimming thermal cores, the medic's license is forged, Section D was sealed before arrival, the food supply has been contaminated, someone is signaling outside the perimeter
- Corporate: Mammona approved Fortuna's destruction, crew is bait, HERMES was compromised from deployment, insurance was reclassified to non-recoverable before landing, the contract renewal clause is automatic
- Cosmic: Erebus is alive, precursor remnants are people, Xenolith are expanding toward inhabited systems, Baldrungen stirs beneath Gaia A^1x, every 58 years the same events repeat, the planet is a shell

---

## 3. Compositional Generators

### NPC Generator

Builds from 5-7 independent compositional slots:

```
origin (planet + era + circumstance)
  + career path (faction + job + why they left)
  + trauma (event + consequence + coping mechanism)
  + secret (tier + content + who else knows)
  + habit + physical detail + debt
  + trait set (conflict-prevented, drives dialogue/backstory modifiers)
  + relationships (wired to other NPCs in batch)
  = unique backstory with built-in quest hooks
```

**Trait logic modifies output:**
- Paranoid NPC: hedges statements, references surveillance, sees patterns
- Brave NPC: direct, short sentences, doesn't explain
- Coward NPC: deflects, blames others, minimizes involvement
- Stoic NPC: understates everything, dry delivery
- Anomaly-sensitive NPC: references things others can't perceive
- Mammona-loyal NPC: corporate euphemisms, justifies company decisions
- Contaminated NPC: language drifts, echoes Erebus, wrong metaphors

### Quest Generator (30+ Archetypes)

Organized by genre:

**Survival horror:** containment breach, the thing among us, quarantine, specimen escape, lights out, the hunting, infection spread

**Investigation:** missing person, sealed room, corrupted data, identity crisis, signal trace, who sent the message, the wrong manifest

**Faction tension:** sabotage, infiltration, betrayal, power struggle, debt collection, mutiny, double agent, territory dispute

**Expedition:** deep bore descent, ruin exploration, surface trek, first contact, recovery mission, salvage run, the long walk

**Moral dilemma:** mercy killing, who gets the escape pod, whistleblower, cover-up, the contaminated child, sacrifice play

**Escalation:** last stand, swarm warning, entity manifestation, HERMES rogue, extraction countdown, the signal stops, reactor critical

Each archetype is a template with 5-6 variable slots (NPC, location, faction, item, secret, tone). Quests reference NPCs from the same generation batch. Each quest has:
- Trigger (how it starts)
- Setup (atmospheric scene-setting with sensory details)
- 3 objectives
- A meaningful choice (with consequences tracked in world state)
- A twist
- Contextual dialogue (NPC-specific, tone-matched)
- Reward

### Dialogue Generator (300+ Fragments)

Organized by **tone x context x trait modifier**.

**12 context pools:** greeting, warning, confession, rumor, threat, plea, observation, complaint, memory, joke, prayer, last_words

**Trait modifiers** adjust phrasing per context. A "warning" from a paranoid NPC sounds different than a warning from a stoic NPC:
- Paranoid: "Three people asked about the drill site today. Same question. Same words. Don't be the fourth."
- Stoic: "Stay away from the drill site."
- Coward: "I'm not saying anything about the drill site. I'm not involved. Ask someone else."

**Natural contractions enforced:** "don't" not "do not", "I'm" not "I am", "they've" not "they have" — in dialogue and personal writing. Corporate memos and clinical reports stay formal by design.

### Datapad Generator (Narrative Arcs)

Multi-entry journals (5-7 entries) that tell a **complete story**:

**Arc types:**
- Research log: discovery → anomaly → escalation → cover-up → disappearance
- Personal journal: arrival → routine → suspicion → deterioration → final entry
- Corporate memo chain: directive → compliance → incident → reclassification → silence
- Unsent letter series: hope → doubt → fear → acceptance → the one that says too much
- Medical report: symptoms → tests → escalation → reclassification → addendum in different handwriting
- Maintenance log: routine → irregularity → pattern → the thing that doesn't fit → stopped logging
- Audio transcript: conversation → revelation → argument → silence → [recording ends]

Each entry references the same NPCs, locations, and timeline. Entry 5 pays off what entry 1 set up. Tone consistent across the arc with escalation built in.

### Expanded Type Generators

The following generators are carried forward from v2/expanded, rebuilt with the compositional approach and structured pools:

- **Robot/AI:** Designation + type + glitch + backstory + dialogue. Glitches are lore-grounded (HERMES corruption patterns, Sunny sentience, MARV-8 awareness). Dialogue reflects machine identity crisis.
- **Company:** Name (generated from curated prefix/suffix pools) + type + parent corp + CEO + public product + actual product (the secret). Corporate satire grounded in Mammona's structure.
- **Vehicle:** Name + registration + type + captain + condition + history + cargo. Condition reflects outer rim decay. History references canonical routes and events.
- **Weapon:** Model + type + description + specs + found context + lore note. Specs include side effects. Found contexts are atmospheric micro-stories.
- **Artifact:** Designation + origin (precursor/Xenolith/unknown) + appearance + properties + discovery log + current status + Mammona classification. Properties are cosmic horror — proximity effects, biological changes, temporal displacement.
- **Entity:** Designation + type + first contact account + observed properties + Mammona assessment + colonist reactions. Lovecraftian — entities are processes, not creatures.

All types support the shared context bag and reference NPCs/locations/factions from the same batch.

### History Generator

Generates 5-10 "things that happened before the player" grounded in the Fortuna-to-Erebus timeline:
- Failed survey teams, sealed sections, crashed supply shuttles, previous postings
- Each history event becomes a shared reference for NPCs, quests, and datapads
- Constrained to canonical timeline:
  - `fortuna` era: 2525-2530 (Kennedy arrival, colony founding, Maw opening, neural massacres, the Fall)
  - `corporate` era: 2530-2588 (Mammona expansion, BioVault Xenolith recovery, StarByte cryo period, sector decline)
  - `present` era: 2588-2590+ (StarByte awakening, game events, HERMES deployment)
- The `--era` flag constrains output to one of these periods

### Relationship Web (Context Bag)

When generating a batch, a shared context dict tracks everything:

```python
context = {
    "npcs": [...],              # generated so far, with relationships
    "faction_tensions": [...],  # active conflicts between factions
    "history_events": [...],    # referenced historical events
    "locations_used": set(),    # avoid repetition
    "items_used": set(),        # avoid repetition
    "sensory_used": set(),      # avoid repetition
    "secrets_revealed": [...],  # for cross-referencing
    "names_used": set(),        # no duplicate names
}
```

Later generators pull from earlier ones:
- Quest #3 references NPC #1 by name
- Datapad #2 mentions the same faction tension as Quest #1
- NPC #5's secret connects to NPC #2's trauma
- Location #3 contains the item NPC #4 has been searching for

Not a simulation — a shared context bag that creates the illusion of a living world.

---

## 4. File Structure & Output

### Files

```
tools/
  gen_pools_core.py    # ~1200 lines — names, jobs, factions, locations, items, events, traits, brands
  gen_pools_text.py    # ~1200 lines — tones, sensory details, dialogue fragments, backstory templates
  gen_v3.py            # ~1500 lines — generators + compositional logic + divergence engine
  world_state.json     # persistent state (divergences, NPC web, generation log)
  gen_pools.py         # (preserved, v2 reference)
  lore_generator.py    # (preserved, v2 reference)
  lore_gen_expanded.py # (preserved, v3 absorbs its generators)
```

Pools are split into two files to stay under the 2000-line limit (CLAUDE.md rule). `gen_pools_core.py` holds structured data (factions, locations, items, etc.). `gen_pools_text.py` holds prose pools (sensory details, dialogue, backstory templates). Both are imported by `gen_v3.py`.

### CLI

```bash
python gen_v3.py                          # 1 random piece
python gen_v3.py --count 50              # 50 pieces
python gen_v3.py --type npc              # NPCs only (npc|quest|datapad|location|faction|robot|company|vehicle|weapon|artifact|entity)
python gen_v3.py --batch 20             # 20 interconnected pieces (shared context)
python gen_v3.py --world                # full world seed (history + factions + NPC roster + quests + datapads)
python gen_v3.py --loop --delay 2       # continuous overnight generation
python gen_v3.py --tone survival_horror # force a tone family
python gen_v3.py --planet erebus        # constrain to planet
python gen_v3.py --era fortuna          # constrain to historical era (fortuna|corporate|present)
python gen_v3.py --diverge              # propose 2-3 divergence events for review
python gen_v3.py --commit div_001       # approve a divergence into world state
python gen_v3.py --state                # print current world state summary
python gen_v3.py --revert div_001       # undo a divergence
python gen_v3.py --reset                # reset world state to canon baseline
```

### Output

All output goes to `proposals/` directory as markdown files. Same format as v2 with section headers, timestamps, sequence numbers. Ready for human review and cherry-picking.

`--batch` mode: generates a coherent cluster where pieces reference each other.

`--world` mode: generates a complete micro-universe — 5-10 history events, 3-5 faction tensions, 8-12 NPCs with relationship web, 4-6 quests involving those NPCs, 5-8 datapads referencing the same events and people.

`--loop` mode: continuous overnight generation. Each batch shares context within itself. The divergence engine accumulates state across the run so later batches build on earlier output. Deduplication prevents repetition across the entire session.

**Output file rules:** One output file per invocation, with pieces separated by markdown section headers and sequence numbers (matching v2 format). `--loop` appends to a single session file throughout the run. `--world` creates a single file with all interconnected pieces. `--batch` creates a single file per batch. Naming convention: `procedural_v3_YYYYMMDD_HHMM.md`.

---

## 5. Quality Controls

### Anti-Repetition
- **Within-batch dedup:** Track used names, locations, items, sensory details. Never repeat within a single batch.
- **Cross-batch frequency:** Recently-used entries get deprioritized via frequency counter persisted in world state.
- **Sentence structure variation:** Each compositional slot has 3+ syntactic patterns. "He carries X" / "X never leaves his side" / "There's always X in his pocket." Same content, different rhythm.

### Tone Coherence
- Every piece gets a tone assignment. All sub-generators (sensory, dialogue, backstory) respect it.
- **Tone blending** for quests and datapads: primary tone (80%) + secondary tone (20%). A survival_horror quest with a tender secondary has one human moment in the terror.

### Lore Guardrails
- **Planet-faction constraints:**
  - Sons of the Pale Moon → Rhea-2 (origin, Pale Moon Shrine) or Erebus (migrated, drawn by sleeping god signal). Generator must contextualize their Erebus presence as pilgrimage, not homeland.
  - Zenith Syndicate → Rhea-2 only (unless diverged via divergence engine).
  - Cult of the Abyss → Thalassa Deep only.
  - Dustweavers → Morvos only.
  - Veilbreakers → Morvos only (covert group exposing Karnaith's secrets).
- **Timeline constraints:** Fortuna events locked to 2525-2530. StarByte crew wakes 2588. Game is 2590. No anachronisms.
- **Locked lore:** Foras, Shaft 12, the Maw — referenced but never expanded or contradicted by the generator.
- **Technology tiers:** Outer rim gets salvaged/scavenged gear. No cutting-edge corporate tech without a smuggling or espionage explanation.

### Contraction Enforcement
- Post-processing converts formal to natural in dialogue and personal writing: "do not" → "don't", "I am" → "I'm", etc.
- Corporate memos stay formal (that IS the tone).
- Clinical reports stay clinical.

### Trait-Dialogue Coherence
- Paranoid NPCs hedge and reference surveillance
- Brave NPCs are blunt and direct
- Coward NPCs deflect and minimize
- Stoic NPCs understate everything
- Each NPC sounds like a different person because their traits shape their vocabulary

---

## 6. Divergence Engine

### Core Concept

A `world_state.json` file accumulates decisions and changes. Every generation run reads it, respects it, and optionally writes new divergences back. The generator can branch from canon, but it tracks every branch and never contradicts itself.

### Divergence Records

```json
{
    "divergences": [
        {
            "id": "div_001",
            "subject": "zenith_syndicate",
            "type": "faction_migration",
            "description": "Zenith Syndicate expelled from Hyades, relocated to Karnaith lower levels",
            "cause": "Solar Nomads reclaimed the oasis by force",
            "timestamp": "day_47",
            "consequences": [
                "Hyades is now Solar Nomad territory",
                "Zenith operates as refugees on Morvos, desperate and volatile",
                "Rhea-2 black market collapsed, smuggling routes shifted to Karnaith"
            ],
            "invalidates": ["zenith_controls_hyades", "hyades_black_market_active"],
            "enables": ["zenith_karnaith_plotlines", "solar_nomad_trade_quests"]
        }
    ]
}
```

### Constraint Propagation
- Each divergence has `invalidates` (things no longer true) and `enables` (new possibilities).
- Generators check both before composing content.
- A quest requiring Hyades black market won't fire if invalidated.
- New quest archetypes about displaced faction refugees become available when enabled.

### Divergence Workflow
1. `--diverge` proposes 1-3 branching events based on current state → written to `proposals/` for review
2. Human reviews and approves
3. `--commit div_001` adds approved divergence to world state
4. All future generation respects the new state
5. `--revert div_001` undoes if needed

### Canon Layer
- Canon = lore bible facts true at game start (day 0)
- Divergences layer on top, overriding canon where specified
- The generator always knows the difference and tracks the chain
- Divergences can cascade (Zenith moves to Karnaith → Zenith takes over Eclipse's End)
- Engine prevents divergences that break earlier ones

### Locked Lore
Foras, Shaft 12, the Maw, Baldrungen's binding, the Fortuna timeline — these never diverge. They are historical facts, not mutable present-state.

### NPC Web of Life

Every NPC is a node in a relationship web that evolves with the world state.

**Relationship types:**
partner, ex_partner, spouse, widowed_by, parent, child, sibling, adopted_family, mentor, protege, rival, nemesis, debtor, creditor, blackmailer, blackmailed_by, co_conspirator, betrayed_by, betrayer_of, crew_mate, former_crew, commanding_officer, subordinate, lover_secret, unrequited, estranged, killed, killed_by, witnessed_death_of, saved_life_of, owes_life_to, shares_secret_with, suspects, trusts, fears

**NPC state tracking:**
```json
{
    "elena_petrov": {
        "relationships": {
            "marcus_chen": {"type": "ex_partner", "status": "bitter", "history": "separated after Karnaith"},
            "wren_ashford": {"type": "mentor", "status": "protective", "history": "trained her on Rhea-2"},
            "cass_vale": {"type": "debtor", "status": "desperate", "history": "owes him for shuttle passage"}
        },
        "alive": true,
        "location": "erebus_sector_c",
        "loyalty": "none",
        "arc_stage": "desperate"
    }
}
```

**Relationships are always bidirectional** — if Elena is Marcus's ex, Marcus is Elena's ex. The generator enforces this automatically.

**Arc stages** track emotional trajectory:
```
stable → stressed → desperate → broken → rebuilt
      → suspicious → paranoid → violent
      → curious → obsessed → lost
      → loyal → betrayed → vengeful
      → healthy → sick → contaminated → changed
```

Each stage modifies dialogue pool, quest hooks, and how other NPCs reference them.

**Dead NPC handling:** Dead NPCs remain in the web with `"alive": false`. They appear in backstories, datapads, and memories ("the late...", "what happened to...") but are never assigned as active quest contacts or dialogue partners. Divergences can kill NPCs; all connected relationships get a grief/relief/guilt arc update based on relationship type.

**Life event propagation:**
- NPC injured → connected NPCs' arcs shift (protective, angry, guilty, indifferent — based on relationship type)
- NPC betrays another → relationship type flips (co_conspirator → betrayed_by), arc stages update, new quest hooks emerge
- NPC dies → all connected NPCs get state update. Grief, relief, fear, guilt. The web vibrates.
- Secret exposed → propagates along trust edges. If Elena shares_secret_with Wren, and Wren is captured, the secret is at risk. Quest hook: rescue or silence.

**Web-aware generation output:**
NPCs reference each other by name with relationship-appropriate tone. Backstories mention shared history. Dialogue includes callbacks to other NPCs. The generator doesn't just list relationships — it weaves them into the prose.

### Consistency Guarantee

**The generator can never produce content that contradicts its own world state.** Every output is filtered through current state before composition. If a contradiction would occur, that compositional slot re-rolls. The world_state.json file is the single source of truth.

---

## 7. Overnight Operation

### Loop Mode

```bash
python gen_v3.py --loop --delay 2 --batch 15
```

Generates batches of 15 interconnected pieces every 2 seconds, continuously. Each batch:
1. Loads current world state
2. Generates a context-connected cluster
3. Appends to output file in `proposals/`
4. Updates frequency counters (anti-repetition)
5. Optionally proposes divergences (if `--auto-diverge` flag set)

### Overnight Expectations

At 2-second delay with batch size 15:
- ~27,000 pieces per hour
- ~216,000 pieces overnight (8 hours)
- All pieces cross-referenced within their batch
- World state accumulates, later batches build on earlier output

### Pool Exhaustion Strategy

With ~270 sensory details and ~80 locations, true zero-repetition across 216K pieces is mathematically impossible. The strategy:

- **Within-batch:** Strict dedup. Never repeat a name, sensory detail, or location within a single batch of 15 pieces.
- **Cross-batch:** Frequency-weighted LRU. Each pool entry has a usage counter. Entries with lower counts are strongly preferred. When all entries in a pool have been used at least once, the counter resets for that pool (full cycle complete). This ensures even distribution before any repetition occurs.
- **Session metrics:** Track pools-exhausted count. Log when a full cycle completes. This tells you how deep the variety goes before recycling.
- **Practical expectation:** With tripled pools, a full cycle through all sensory details takes ~45 batches (~675 pieces). Locations cycle every ~5-6 batches. Names cycle much later (~200+ batches). The overnight run will produce many cycles, but each cycle shuffles differently. Repetition is distributed, not clustered.

### World State Integrity

The `world_state.json` file is the single source of truth. Corruption during overnight runs would be catastrophic.

- **Schema validation:** On load, validate all required keys exist and types are correct. Reject and log malformed state rather than generating with corrupted data.
- **Atomic writes:** Write to `world_state.tmp.json`, then rename to `world_state.json`. Prevents partial-write corruption on crash.
- **Periodic backups:** During `--loop` mode, snapshot `world_state.json` to `world_state_backup_HHMM.json` every 100 batches.
- **`--validate` flag:** CLI option to validate the current world state file and report any issues without generating content.
- **Recovery:** If `world_state.json` is corrupted, fall back to most recent backup. If no backup exists, `--reset` regenerates from canon baseline.

### Output Organization

```
proposals/
  procedural_v3_20260318_2200.md    # timestamped output file
```
```
tools/
  world_state.json                   # accumulated state (lives with the generator)
  world_state_backup_*.json          # periodic backups during --loop
```

Output file uses same v2 format: sequence numbers, type labels, timestamps, markdown sections. Ready for human review.

---

## Non-Goals (Explicitly Out of Scope)

- **Lua port:** Separate future project. Python generator is the content pipeline and design sandbox.
- **LLM integration:** 100% template-based. No AI calls. No disclosure needed.
- **GUI:** CLI only. Output is markdown files for review.
- **Game integration:** Generator writes to `proposals/`. Game integration happens when content is reviewed and manually ported or when the Lua port is built.
- **Full world simulation:** The relationship web and divergence engine create the *illusion* of a living world through cross-referencing, not through actual simulation.
