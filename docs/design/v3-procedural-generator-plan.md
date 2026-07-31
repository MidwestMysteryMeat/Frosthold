# V3 Procedural Lore Generator — Implementation Plan


**Goal:** Build a lore-accurate procedural content generator that produces interconnected NPCs, quests, datapads, locations, factions, and more with divergence tracking and overnight batch capability.

**Architecture:** Three Python files in `tools/`. Two pool files (`gen_pools_core.py` for structured data, `gen_pools_text.py` for prose/tone content) feed into `gen_v3.py` which contains all generators, the context bag, divergence engine, and CLI. A `world_state.json` file tracks persistent state across runs.

**Tech Stack:** Python 3.x stdlib only (random, json, argparse, time, pathlib, os, shutil). No external dependencies.

**Spec:** `docs/design/v3-procedural-generator-design.md`

**Lore source of truth:** `lore/LORE_BIBLE.md`

---

## File Map

| File | Responsibility | ~Lines |
|------|---------------|--------|
| `tools/gen_pools_core.py` | Structured data: names, jobs, factions, locations, items, events, traits, brands, habits, physical, debts, secrets | ~1200 |
| `tools/gen_pools_text.py` | Prose pools: 45 tones with families, ~270 sensory details, dialogue fragments (300+), backstory templates, atmosphere paragraphs | ~1200 |
| `tools/gen_v3.py` | All generators, context bag, world state, divergence engine, CLI | ~1500 |
| `tools/gen_v3_expanded.py` | Expanded generators: robot, company, vehicle, weapon, artifact, entity | ~500 |
| `tools/world_state.json` | Persistent state (created at runtime, not committed — add to `.gitignore`) | N/A |

Split `gen_v3.py` and `gen_v3_expanded.py` from the start to stay under line limits. Main file handles NPC/quest/datapad/history + infrastructure + divergence. Expanded file handles the 6 secondary generators.

---

## Task 1: gen_pools_core.py — Structured Data Pools

**Files:**
- Create: `tools/gen_pools_core.py`

This is the largest single task — all structured data pools, tripled from v2, lore-grounded. Read `lore/LORE_BIBLE.md` and `tools/gen_pools.py` (v3 foundation) as source material.

- [ ] **Step 1: Create file with header, imports, and name pools**

```python
"""
Frosthold Procedural Generator v3 — Core Data Pools
All content grounded in LORE_BIBLE.md. No invented lore.
"""
import random
R = random.choice
RS = random.sample
RI = random.randint

# Helper
def pronouns(g):
    return {"M": ("He","he","his","him"), "F": ("She","she","her","her"), "NB": ("They","they","their","them")}[g]

def name():
    g = R(["M","F","F","M","M","F","NB"])
    pool = {"M": FIRST_M, "F": FIRST_F, "NB": FIRST_NB}[g]
    return R(pool), R(LAST), g

def rname():
    f, l, _ = name()
    return f"{f} {l}"
```

Write ~100 male names, ~100 female names, ~25 NB names, ~80 last names. Include all lore-canonical names (Vale, Dranth, Venin, Rathmore, MacReady, Childs, Clarke, etc.) mixed with diverse global names from v2's `gen_pools.py`.

- [ ] **Step 2: Add robot name generator**

Carry forward from `gen_pools.py` with expanded prefix/number/nickname pools (~40 prefixes, ~20 numbers, ~30 nicknames).

- [ ] **Step 3: Add jobs pool (~120 entries)**

Organize by domain as structured list with comments:
```python
JOBS_MAMMONA = ["quota enforcer", "contract auditor", ...]
JOBS_EREBUS = ["bore shaft monitor", "thermal core extractor", ...]
JOBS_CRIMINAL = ["Eclipse's End pit fighter", ...]
JOBS_SHIPBOARD = ["warp navigator", ...]
JOBS_COLONY = ["miner", "engineer", ...]
JOBS = JOBS_MAMMONA + JOBS_EREBUS + JOBS_CRIMINAL + JOBS_SHIPBOARD + JOBS_COLONY
```

- [ ] **Step 4: Add factions as structured dicts (~40 entries)**

Every canonical faction from lore bible as a dict with: name, type, territory, rivals, secrets, tone, slogan (if corporate). Include Mammona Corporation (parent + subsidiaries), UTC, Vanguard Alliance, all 3 pirate factions (Black Maw, Void Serpents, Rust Reavers), Zenith Syndicate, all cult/independent groups (Sons of the Pale Moon, Cult of the Abyss, Veilbreakers, Dustweaver Swarm, Solar Nomads, Iron Shadow Collective), corporate entities (Fortune Arms, TerraGen, BioVault, OmniCorp, StarByte Vends, TaoTray, NexLink, Orbis Energy, Paxtera AgroTech), plus 10-15 generated fringe factions using `[Adj] [Noun]` naming.

Add fringe faction generation helper:
```python
FRINGE_ADJ = ["Pale", "Ashen", "Iron", "Hollow", ...]
FRINGE_NOUN = ["Circuit", "Compact", "Meridian", "Protocol", ...]
FRINGE_TYPES = ["criminal", "religious", "paramilitary", "workers_collective", "smuggling_ring"]
```

- [ ] **Step 5: Add locations as structured dicts (~80 entries)**

Organized by planet. Each location has: name, planet, type, features (list), threats (list), connected_factions (list). Cover all planets from spec: Erebus, Gaia A^1x (reference-only), Rhea-2, Morvos, Nerthus-9, Nemaea, Paxtera Prime, Orbit/Space, Novaris-3 (inner rim reference). Mark Gaia A^1x locations with `"reference_only": True`.

Planet-faction constraint table:
```python
PLANET_FACTION_CONSTRAINTS = {
    "sons_of_the_pale_moon": {"allowed": ["Rhea-2", "Erebus"], "context": {"Erebus": "pilgrimage"}},
    "zenith_syndicate": {"allowed": ["Rhea-2"]},
    "cult_of_the_abyss": {"allowed": ["Nerthus-9"]},
    "dustweaver_swarm": {"allowed": ["Morvos"]},
    "veilbreakers": {"allowed": ["Morvos"]},
}
```

- [ ] **Step 6: Add items (~70), events (~60), brands (~20)**

Items organized by category: mammona_corporate, precursor, personal, contraband, brand_detritus. Events organized by era: fortuna (2525-2530), corporate (2530-2588), present (2588-2590+), colony_level, personal. Brands as structured dicts with products list.

```python
ERAS = {
    "fortuna": {"start": 2525, "end": 2530, "description": "Kennedy arrival through Fall of Foras"},
    "corporate": {"start": 2530, "end": 2588, "description": "Mammona expansion, sector decline"},
    "present": {"start": 2588, "end": 2590, "description": "StarByte awakening, game events"},
}
```

- [ ] **Step 7: Add traits (~174 total) with conflict prevention**

~60 positive, ~60 negative, ~54 special. Include Erebus-specific (anomaly-sensitive, cold-adapted, bore-hardened, voidbloom-resistant), faction-marked (Mammona-loyal, debt-bonded, ex-MasTema), and contamination traits (came-back-wrong, death-echo, tissue-drift, shadow-lag). ~30 conflict pairs. `pick_traits()` function from gen_pools.py carried forward.

- [ ] **Step 8: Add habits (~72), physical details (~60), debts (~36), secrets (~60)**

Habits: lore-grounded behaviors (voidbloom-specific, Mammona-specific, Erebus-specific, psychological). Physical: contamination marks, Thalassa brands, prosthetic details, radiation effects. Debts: Mammona contract spirals, faction debts, moral debts, life debts. Secrets tiered by danger: colony, corporate, cosmic.

- [ ] **Step 9: Add lore pools**

Lore references, locked lore list, technology items, creature types, full relationship types list (all 34 from spec), and structured arc progressions with valid transitions:
```python
LOCKED_LORE = ["Foras", "Shaft 12", "the Maw", "Baldrungen", "the Fortuna timeline"]

RELATIONSHIP_TYPES = [
    "partner", "ex_partner", "spouse", "widowed_by",
    "parent", "child", "sibling", "adopted_family",
    "mentor", "protege", "rival", "nemesis",
    "debtor", "creditor", "blackmailer", "blackmailed_by",
    "co_conspirator", "betrayed_by", "betrayer_of",
    "crew_mate", "former_crew", "commanding_officer", "subordinate",
    "lover_secret", "unrequited", "estranged",
    "killed", "killed_by", "witnessed_death_of",
    "saved_life_of", "owes_life_to",
    "shares_secret_with", "suspects", "trusts", "fears",
]

# Branching arc progressions — maps each stage to valid successors
ARC_PROGRESSIONS = {
    "stable": ["stressed", "suspicious", "curious", "loyal", "healthy"],
    "stressed": ["desperate", "stable"],
    "desperate": ["broken", "stable"],
    "broken": ["rebuilt", "desperate"],
    "rebuilt": ["stable"],
    "suspicious": ["paranoid", "stable"],
    "paranoid": ["violent", "suspicious"],
    "violent": ["broken"],
    "curious": ["obsessed", "stable"],
    "obsessed": ["lost", "curious"],
    "lost": ["broken"],
    "loyal": ["betrayed", "stable"],
    "betrayed": ["vengeful", "broken"],
    "vengeful": ["broken", "rebuilt"],
    "healthy": ["sick", "stable"],
    "sick": ["contaminated", "healthy"],
    "contaminated": ["changed", "sick"],
    "changed": [],  # terminal
}
ARC_STAGES = list(ARC_PROGRESSIONS.keys())
```

- [ ] **Step 10: Verify pool counts**

Add a `if __name__ == "__main__"` block that prints all pool sizes:
```python
if __name__ == "__main__":
    pools = {"FIRST_M": FIRST_M, "FIRST_F": FIRST_F, ...}
    for name, pool in pools.items():
        print(f"  {name}: {len(pool)}")
    # Assert minimums
    assert len(FIRST_M) >= 100, f"FIRST_M too small: {len(FIRST_M)}"
    assert len(JOBS) >= 120, f"JOBS too small: {len(JOBS)}"
    ...
```

Run: `cd tools && python gen_pools_core.py`
Expected: All pool counts printed, all assertions pass.

- [ ] **Step 11: Commit**

```bash
git add tools/gen_pools_core.py
git commit -m "feat: add v3 core data pools — tripled, lore-grounded structured dicts"
```

---

## Task 2: gen_pools_text.py — Prose & Tone Pools

**Files:**
- Create: `tools/gen_pools_text.py`

All prose content: 45 tones, ~270 sensory details, dialogue fragments, backstory templates, atmosphere paragraphs. Read existing `tools/gen_pools.py` SENSORY dict as starting point and triple it.

- [ ] **Step 1: Create file with tone definitions**

```python
"""
Frosthold Procedural Generator v3 — Prose & Tone Pools
45 tones organized into 5 families. ~270 sensory details. 300+ dialogue fragments.
"""
import random
R = random.choice

TONE_FAMILIES = {
    "horror": ["dread", "slow_dread", "sudden_dread", "cosmic_horror", "body_horror",
               "quiet_terror", "survival_horror", "folk_horror", "psychic_contamination",
               "the_uncanny", "wrongness"],
    "emotional": ["melancholy", "grief", "tender", "mania", "dissociation",
                  "nostalgia", "guilt", "shame", "hollow_joy", "bitter_hope"],
    "psychological": ["paranoid", "isolation", "claustrophobia", "agoraphobia",
                      "identity_erosion", "gaslighting", "obsession", "sleep_deprivation",
                      "hypervigilance"],
    "genre": ["noir", "military", "religious_fervor", "cult_devotion", "corporate_dystopia",
              "frontier_grit", "gallows_humor", "clinical"],
    "state": ["desperate", "numb", "resigned", "furious", "defiant", "manic_energy", "exhaustion"],
}
TONES = [t for family in TONE_FAMILIES.values() for t in family]
```

- [ ] **Step 2: Add sensory details for horror tones (11 tones x 6+ each = ~70)**

Each tone needs 6+ unique sensory details. Carry forward the best from v2 `gen_pools.py` SENSORY dict, expand with new entries matching each tone's specific flavor. `slow_dread` is patient and building; `sudden_dread` is sharp and immediate; `folk_horror` is rural and ritualistic; etc.

```python
SENSORY = {
    "dread": [
        "The air tasted like copper and ozone.",
        "Something scraped against the hull. Rhythmic. Patient.",
        ...  # 6+ entries
    ],
    "slow_dread": [
        "The stain on the ceiling had grown since yesterday. Nobody mentioned it.",
        ...
    ],
    ...
}
```

- [ ] **Step 3: Add sensory details for emotional tones (10 tones x 6+ = ~60)**

Melancholy, grief, tender, mania, dissociation, nostalgia, guilt, shame, hollow_joy, bitter_hope. Each needs distinct sensory texture. Grief is heavy and still; mania is fast and bright; dissociation is disconnected and floaty.

- [ ] **Step 4: Add sensory details for psychological tones (9 x 6+ = ~55)**

Paranoid, isolation, claustrophobia, agoraphobia, identity_erosion, gaslighting, obsession, sleep_deprivation, hypervigilance.

- [ ] **Step 5: Add sensory details for genre + state tones (15 x 6+ = ~90)**

Noir, military, religious_fervor, cult_devotion, corporate_dystopia, frontier_grit, gallows_humor, clinical, desperate, numb, resigned, furious, defiant, manic_energy, exhaustion.

- [ ] **Step 6: Add `sensory()` and `pick_tone()` helpers**

```python
def sensory(tone):
    """Return a sensory detail matching the tone."""
    pool = SENSORY.get(tone, SENSORY["dread"])
    return R(pool)

def pick_tone(family=None):
    """Pick a random tone, optionally from a specific family."""
    if family:
        return R(TONE_FAMILIES[family])
    return R(TONES)

def pick_tone_blend():
    """Pick primary (80%) and secondary (20%) tones from different families."""
    primary = pick_tone()
    primary_family = next(f for f, tones in TONE_FAMILIES.items() if primary in tones)
    secondary_families = [f for f in TONE_FAMILIES if f != primary_family]
    secondary = pick_tone(R(secondary_families))
    return primary, secondary
```

- [ ] **Step 7: Add dialogue fragments (300+ total)**

Organized by context type (12 pools) with tone variants:

```python
DIALOGUE = {
    "greeting": {
        "_universal": [
            "You're new. You'll learn.",
            "Don't touch anything in Section D.",
            ...
        ],
        "paranoid": ["Who sent you?", "You're the third person today. Same corridor.", ...],
        "gallows_humor": ["Welcome to paradise. The brochure lied.", ...],
        ...
    },
    "warning": { ... },
    "confession": { ... },
    "rumor": { ... },
    "threat": { ... },
    "plea": { ... },
    "observation": { ... },
    "complaint": { ... },
    "memory": { ... },
    "joke": { ... },
    "prayer": { ... },
    "last_words": { ... },
}
```

Target: ~25 entries per context type across all tone variants = 300+ total. `_universal` entries work for any tone. Tone-specific entries override when tone matches.

Include trait-modified dialogue function:
```python
def get_dialogue(context, tone, trait=None):
    """Get a dialogue line matching context, tone, and optionally modified by trait."""
    pool = DIALOGUE.get(context, DIALOGUE["observation"])
    lines = pool.get("_universal", [])[:]
    if tone in pool:
        lines += pool[tone]
    # Trait modifiers adjust word choice
    line = R(lines) if lines else "..."
    if trait:
        line = apply_trait_voice(line, trait)
    return line
```

- [ ] **Step 8: Add backstory templates**

Origin templates, trauma templates, middle (habit/behavior) templates, secret templates — each with 3+ syntactic variations per slot. These use `{first}`, `{last}`, `{g}`, `{gl}`, `{gp}`, `{go}` placeholders for pronoun injection.

```python
ORIGINS = [
    "{first} {last} signed a five-year contract with {faction}. That was {years} years ago. {g} stopped counting when the renewal clause kicked in.",
    "Before {location}, {first} was a {prev_job} on {prev_location}. {g} transferred after {event}.",
    ...  # 15+ origin templates
]

TRAUMAS = [
    "{g} doesn't talk about {event}. Nobody who was there does.",
    "The scar on {gp} {body_part} is from {trauma_cause}. That's what {gl} says. The scar doesn't match.",
    ...  # 15+ trauma templates
]

MIDDLES = [
    "{g} carries {item} everywhere. Won't explain why.",
    "{g} {habit}. Nobody asks anymore.",
    ...  # 15+ middle templates
]

SECRET_TEMPLATES = [
    "What {first} hasn't told anyone: {secret}.",
    "{first}'s real name isn't {first}. The real {first} {last} died on {location}.",
    ...  # 15+ secret templates
]
```

- [ ] **Step 9: Add atmosphere paragraph templates**

Longer atmospheric paragraphs for quest setups and location descriptions. Organized by tone, using `{name}`, `{loc}`, `{brand}` placeholders. ~5 per tone for the most common tones, ~3 for others.

- [ ] **Step 10: Add contraction enforcement function**

```python
CONTRACTION_MAP = {
    "do not": "don't", "does not": "doesn't", "did not": "didn't",
    "I am": "I'm", "I have": "I've", "I will": "I'll", "I would": "I'd",
    "you are": "you're", "you have": "you've", "you will": "you'll",
    "we are": "we're", "we have": "we've", "they are": "they're",
    "they have": "they've", "it is": "it's", "it has": "it's",
    "is not": "isn't", "are not": "aren't", "was not": "wasn't",
    "were not": "weren't", "has not": "hasn't", "have not": "haven't",
    "will not": "won't", "would not": "wouldn't", "could not": "couldn't",
    "should not": "shouldn't", "cannot": "can't", "can not": "can't",
    "that is": "that's", "who is": "who's", "what is": "what's",
    "there is": "there's", "here is": "here's",
    "let us": "let's",
}

FORMAL_TONES = {"clinical", "corporate_dystopia", "military"}

def enforce_contractions(text, tone):
    """Convert formal to natural in dialogue/personal writing. Leave formal tones alone."""
    if tone in FORMAL_TONES:
        return text
    for formal, contracted in CONTRACTION_MAP.items():
        text = text.replace(formal, contracted)
        text = text.replace(formal.capitalize(), contracted.capitalize())
    return text
```

- [ ] **Step 11: Add trait voice modifier**

```python
TRAIT_VOICE = {
    "Paranoid": {"hedges": ["I think", "maybe", "supposedly"], "additions": ["Watch your back.", "Don't trust anyone."]},
    "Brave": {"style": "short_direct"},
    "Coward": {"hedges": ["I'm not involved", "don't ask me", "someone else"], "deflections": True},
    "Stoic": {"style": "understate"},
    ...
}

def apply_trait_voice(line, trait):
    """Modify a dialogue line based on the speaker's primary trait."""
    voice = TRAIT_VOICE.get(trait)
    if not voice:
        return line
    if voice.get("style") == "short_direct":
        # Trim to first sentence if multi-sentence
        if ". " in line:
            line = line.split(". ")[0] + "."
    if voice.get("style") == "understate":
        line = line.replace("terrible", "not great").replace("horrifying", "bad")
    return line
```

- [ ] **Step 12: Verify pool counts and test helpers**

```python
if __name__ == "__main__":
    print(f"Tones: {len(TONES)}")
    total_sensory = sum(len(v) for v in SENSORY.values())
    print(f"Sensory details: {total_sensory}")
    total_dialogue = sum(sum(len(v) for v in ctx.values()) for ctx in DIALOGUE.values())
    print(f"Dialogue fragments: {total_dialogue}")
    assert len(TONES) >= 45
    assert total_sensory >= 270
    assert total_dialogue >= 300
    # Test helpers
    print(f"Sample sensory (dread): {sensory('dread')}")
    print(f"Sample tone blend: {pick_tone_blend()}")
    print(f"Contraction test: {enforce_contractions('I do not know what I am doing here.', 'dread')}")
    print("All checks passed.")
```

Run: `cd tools && python gen_pools_text.py`

- [ ] **Step 13: Commit**

```bash
git add tools/gen_pools_text.py
git commit -m "feat: add v3 prose pools — 45 tones, 270+ sensory, 300+ dialogue, backstory templates"
```

---

## Task 3: gen_v3.py — Infrastructure & CLI

**Files:**
- Create: `tools/gen_v3.py`

Core infrastructure: imports, context bag, world state management, anti-repetition, CLI argument parsing, output formatting. No generators yet — just the skeleton they plug into.

- [ ] **Step 1: Create file with imports and WorldState class**

```python
"""
Frosthold Procedural Lore Generator v3
Lore-accurate. Compositional. Interconnected. Overnight-capable.
Usage: python gen_v3.py --help
"""
import random
import json
import time
import argparse
import os
import shutil
from pathlib import Path

from gen_pools_core import (
    name, rname, pronouns, robot_name, JOBS, FACTIONS, LOCATIONS,
    ITEMS, EVENTS, BRANDS, TRAITS_P, TRAITS_N, TRAITS_X, pick_traits,
    HABITS, PHYSICAL, DEBTS, SECRETS, LORE, ERAS, LOCKED_LORE,
    PLANET_FACTION_CONSTRAINTS, RELATIONSHIP_TYPES, ARC_STAGES,
    FRINGE_ADJ, FRINGE_NOUN, FRINGE_TYPES,
)
from gen_pools_text import (
    TONES, TONE_FAMILIES, SENSORY, DIALOGUE, sensory, pick_tone,
    pick_tone_blend, get_dialogue, enforce_contractions, apply_trait_voice,
    ORIGINS, TRAUMAS, MIDDLES, SECRET_TEMPLATES,
)

R = random.choice
PROPOSALS_DIR = Path(os.environ.get("FROSTHOLD_PROPOSALS_DIR", Path(__file__).parent / "proposals"))
PROPOSALS_DIR.mkdir(parents=True, exist_ok=True)
STATE_PATH = Path(__file__).parent / "world_state.json"
```

- [ ] **Step 2: Add WorldState class**

```python
class WorldState:
    """Persistent state across generator runs. Single source of truth."""
    SCHEMA_VERSION = 1
    DEFAULT = {
        "version": 1,
        "divergences": [],
        "npc_states": {},
        "faction_states": {},
        "events_occurred": [],
        "frequency": {},      # pool entry usage counts
        "generation_log": [], # what's been generated (recent only)
    }

    def __init__(self, path=STATE_PATH):
        self.path = Path(path)
        self.data = self._load()

    def _load(self):
        if not self.path.exists():
            return dict(self.DEFAULT)
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self._validate(data)
            return data
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            print(f"WARNING: world_state.json corrupted ({e}), using default")
            return dict(self.DEFAULT)

    def _validate(self, data):
        for key in self.DEFAULT:
            if key not in data:
                raise KeyError(f"Missing required key: {key}")

    def save(self):
        tmp = self.path.with_suffix(".tmp.json")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.data, f, indent=2, ensure_ascii=False)
        shutil.move(str(tmp), str(self.path))

    def backup(self, label=""):
        backup_name = f"world_state_backup_{label or time.strftime('%H%M')}.json"
        backup_path = self.path.parent / backup_name
        shutil.copy2(str(self.path), str(backup_path))

    def reset(self):
        self.data = dict(self.DEFAULT)
        self.save()

    def is_invalidated(self, tag):
        for div in self.data["divergences"]:
            if tag in div.get("invalidates", []):
                return True
        return False

    def is_enabled(self, tag):
        for div in self.data["divergences"]:
            if tag in div.get("enables", []):
                return True
        return False

    def get_npc(self, npc_id):
        return self.data["npc_states"].get(npc_id)

    def set_npc(self, npc_id, state):
        self.data["npc_states"][npc_id] = state

    def track_frequency(self, pool_name, entry):
        freq = self.data["frequency"].setdefault(pool_name, {})
        freq[entry] = freq.get(entry, 0) + 1
```

- [ ] **Step 3: Add Context class (batch context bag)**

```python
class Context:
    """Shared context within a generation batch. Tracks used elements for dedup and cross-referencing."""

    def __init__(self, world_state=None):
        self.world = world_state or WorldState()
        self.npcs = []              # NPCs generated in this batch
        self.faction_tensions = []  # active conflicts
        self.history_events = []    # referenced history
        self.locations_used = set()
        self.items_used = set()
        self.sensory_used = set()
        self.secrets_revealed = []
        self.names_used = set()
        self.pieces = []            # all generated pieces (for output)

    def pick_fresh(self, pool, pool_name=None):
        """Pick an item from pool that hasn't been used in this batch. Frequency-weighted."""
        used_attr = None
        if pool_name == "names":
            used_attr = self.names_used
        elif pool_name == "locations":
            used_attr = self.locations_used
        elif pool_name == "items":
            used_attr = self.items_used
        elif pool_name == "sensory":
            used_attr = self.sensory_used

        available = [x for x in pool if x not in (used_attr or set())]
        if not available:
            available = list(pool)  # pool exhausted within batch, allow reuse

        # Frequency-weighted selection
        if pool_name and self.world:
            freq = self.world.data["frequency"].get(pool_name, {})
            min_freq = min((freq.get(str(x), 0) for x in available), default=0)
            least_used = [x for x in available if freq.get(str(x), 0) <= min_freq]
            pick = R(least_used) if least_used else R(available)
        else:
            pick = R(available)

        if used_attr is not None:
            used_attr.add(pick)
        if pool_name and self.world:
            self.world.track_frequency(pool_name, str(pick))
            # LRU reset: when all entries used at least once, reset counters
            freq = self.world.data["frequency"].get(pool_name, {})
            if len(freq) >= len(pool) and all(v >= 1 for v in freq.values()):
                self.world.data["frequency"][pool_name] = {}
        return pick

    def fresh_name(self):
        """Generate a name not yet used in this batch."""
        for _ in range(50):
            f, l, g = name()
            full = f"{f} {l}"
            if full not in self.names_used:
                self.names_used.add(full)
                return f, l, g
        return name()  # fallback

    def fresh_sensory(self, tone):
        """Get a sensory detail not yet used in this batch."""
        pool = SENSORY.get(tone, SENSORY.get("dread", []))
        available = [s for s in pool if s not in self.sensory_used]
        if not available:
            available = pool
        pick = R(available) if available else "The air felt wrong."
        self.sensory_used.add(pick)
        return pick

    def add_npc(self, npc_data):
        self.npcs.append(npc_data)

    def get_random_npc(self):
        return R(self.npcs) if self.npcs else None

    def add_piece(self, content, label, gen_type):
        self.pieces.append({"content": content, "label": label, "type": gen_type})
```

- [ ] **Step 4: Add output formatting and CLI**

```python
def format_output(pieces, seq_start=1):
    """Format a list of pieces into markdown output."""
    lines = []
    for i, piece in enumerate(pieces):
        seq = seq_start + i
        lines.append(f"\n\n{'='*60}")
        lines.append(f"### [SEQ:{seq}] [{piece['label']}] [{time.strftime('%H:%M:%S')}]")
        lines.append(f"{'='*60}\n")
        lines.append(piece["content"])
    return "\n".join(lines)


def build_cli():
    parser = argparse.ArgumentParser(description="Frosthold Procedural Lore Generator v3")
    parser.add_argument("--count", type=int, default=1, help="Number of pieces to generate")
    parser.add_argument("--type", choices=["npc","quest","datapad","location","faction",
                        "robot","company","vehicle","weapon","artifact","entity","history"],
                        help="Generate specific type only")
    parser.add_argument("--batch", type=int, default=0, help="Generate N interconnected pieces")
    parser.add_argument("--world", action="store_true", help="Generate full world seed")
    parser.add_argument("--loop", action="store_true", help="Run continuously")
    parser.add_argument("--delay", type=float, default=2, help="Delay between loop iterations")
    parser.add_argument("--tone", help="Force a specific tone")
    parser.add_argument("--planet", help="Constrain to planet")
    parser.add_argument("--era", choices=["fortuna","corporate","present"], help="Constrain to era")
    parser.add_argument("--output", default=None, help="Output file path")
    # Divergence commands
    parser.add_argument("--diverge", action="store_true", help="Propose divergence events")
    parser.add_argument("--commit", help="Commit a divergence by ID")
    parser.add_argument("--revert", help="Revert a divergence by ID")
    parser.add_argument("--state", action="store_true", help="Print world state summary")
    parser.add_argument("--reset", action="store_true", help="Reset world state to canon")
    parser.add_argument("--validate", action="store_true", help="Validate world state file")
    parser.add_argument("--auto-diverge", action="store_true", help="Auto-propose divergences in loop")
    return parser
```

- [ ] **Step 5: Add main() with all modes**

Write the main function that dispatches to: single generation, count mode, batch mode, world mode, loop mode, divergence commands, state inspection. Use placeholder `generate_piece()` and `generate_batch()` functions that will be filled in by later tasks.

```python
# Build LOCATIONS_FLAT from structured LOCATIONS dict (available to all generators)
LOCATIONS_FLAT = []
for _loc_data in LOCATIONS.values():
    if isinstance(_loc_data, dict):
        LOCATIONS_FLAT.append(_loc_data.get("name", ""))
    elif isinstance(_loc_data, str):
        LOCATIONS_FLAT.append(_loc_data)
if not LOCATIONS_FLAT:
    LOCATIONS_FLAT = ["Erebus", "Karnaith", "Thalassa Deep", "Rhea-2", "Hyades"]

# Placeholder generators (replaced in tasks 4-8)
GENERATORS = {}  # populated as generators are added

def filter_locations_by_planet(planet):
    """Return locations constrained to a specific planet."""
    if not planet:
        return LOCATIONS_FLAT
    return [loc for key, loc_data in LOCATIONS.items()
            if isinstance(loc_data, dict) and loc_data.get("planet", "").lower() == planet.lower()
            for loc in [loc_data.get("name", "")]] or LOCATIONS_FLAT

def filter_events_by_era(era):
    """Return events constrained to a specific era."""
    if not era:
        return EVENTS
    era_info = ERAS.get(era)
    if not era_info:
        return EVENTS
    return [e for e in EVENTS if e.get("era", "present") == era] if isinstance(EVENTS[0], dict) else EVENTS

def generate_piece(gen_type=None, ctx=None, tone=None, planet=None, era=None):
    if ctx is None:
        ctx = Context()
    if gen_type is None:
        gen_type = R(list(GENERATORS.keys()))
    gen_func, label = GENERATORS[gen_type]
    content = gen_func(ctx, tone=tone, planet=planet, era=era)
    ctx.add_piece(content, label, gen_type)
    return content, label, gen_type

def generate_batch(size, ctx=None, tone=None, planet=None, era=None):
    if ctx is None:
        ctx = Context(WorldState())
    for _ in range(size):
        generate_piece(ctx=ctx, tone=tone, planet=planet, era=era)
    return ctx

def main():
    parser = build_cli()
    args = parser.parse_args()
    ws = WorldState()

    # State management commands
    if args.state:
        print(json.dumps(ws.data, indent=2))
        return
    if args.reset:
        ws.reset()
        print("World state reset to canon baseline.")
        return
    if args.validate:
        try:
            ws._validate(ws.data)
            print("World state valid.")
        except Exception as e:
            print(f"World state INVALID: {e}")
        return
    if args.commit:
        # handled in divergence engine (Task 9)
        print(f"Commit divergence: {args.commit}")
        return
    if args.revert:
        print(f"Revert divergence: {args.revert}")
        return

    output_file = args.output or str(PROPOSALS_DIR / f"procedural_v3_{time.strftime('%Y%m%d_%H%M')}.md")
    seq = 0

    try:
        if args.world:
            ctx = Context(ws)
            # World mode generates a complete micro-universe
            generate_world(ctx, tone=args.tone, planet=args.planet, era=args.era)
            with open(output_file, "a", encoding="utf-8") as f:
                f.write(format_output(ctx.pieces, seq + 1))
            seq += len(ctx.pieces)
            print(f"World seed: {len(ctx.pieces)} pieces -> {output_file}")

        elif args.batch > 0:
            ctx = generate_batch(args.batch, tone=args.tone, planet=args.planet, era=args.era)
            with open(output_file, "a", encoding="utf-8") as f:
                f.write(format_output(ctx.pieces, seq + 1))
            seq += len(ctx.pieces)
            print(f"Batch: {len(ctx.pieces)} pieces -> {output_file}")

        elif args.loop:
            batch_size = args.batch if args.batch > 0 else 15
            batch_count = 0
            print(f"Frosthold Lore Generator v3 -- Running continuously (batch size: {batch_size})")
            print(f"Output: {output_file}")
            print("Ctrl+C to stop.\n")
            while True:
                batch_count += 1
                ctx = generate_batch(batch_size, tone=args.tone, planet=args.planet, era=args.era)
                if args.auto_diverge and batch_count % 50 == 0:
                    proposals = propose_divergences(ws) if 'propose_divergences' in dir() else []
                    for p in proposals:
                        print(f"    [divergence proposed] {p.get('description', p.get('id', ''))}")
                with open(output_file, "a", encoding="utf-8") as f:
                    f.write(format_output(ctx.pieces, seq + 1))
                seq += len(ctx.pieces)
                print(f"  [batch {batch_count}] {len(ctx.pieces)} pieces (total: {seq})")
                if batch_count % 100 == 0:
                    ws.save()
                    ws.backup(str(batch_count))
                time.sleep(args.delay)

        else:
            for _ in range(args.count):
                seq += 1
                ctx = Context(ws)
                content, label, _ = generate_piece(
                    gen_type=args.type, ctx=ctx, tone=args.tone, planet=args.planet, era=args.era)
                with open(output_file, "a", encoding="utf-8") as f:
                    f.write(format_output(ctx.pieces, seq))
                print(content)
            print(f"\nSaved {seq} entries to: {output_file}")

        ws.save()

    except KeyboardInterrupt:
        ws.save()
        print(f"\nStopped after {seq} entries. Saved to: {output_file}")

def generate_world(ctx, tone=None, planet=None, era=None):
    """Generate a complete micro-universe: history + factions + NPCs + quests + datapads."""
    # Generate history events first (referenced by everything else)
    for _ in range(RI(5, 10)):
        generate_piece("history", ctx=ctx, tone=tone, planet=planet, era=era) if "history" in GENERATORS else None
    # Generate NPCs (they form the relationship web)
    for _ in range(RI(8, 12)):
        generate_piece("npc", ctx=ctx, tone=tone, planet=planet, era=era) if "npc" in GENERATORS else None
    # Wire relationships after NPC generation
    wire_relationships(ctx) if 'wire_relationships' in dir() else None
    # Generate quests involving those NPCs
    for _ in range(RI(4, 6)):
        generate_piece("quest", ctx=ctx, tone=tone, planet=planet, era=era) if "quest" in GENERATORS else None
    # Generate datapads referencing the same world
    for _ in range(RI(5, 8)):
        generate_piece("datapad", ctx=ctx, tone=tone, planet=planet, era=era) if "datapad" in GENERATORS else None
    # Sprinkle in expanded types
    for gen_type in ["robot", "location", "artifact"]:
        if gen_type in GENERATORS and random.random() > 0.3:
            generate_piece(gen_type, ctx=ctx, tone=tone, planet=planet, era=era)

if __name__ == "__main__":
    main()
```

- [ ] **Step 6: Test infrastructure**

Run: `cd tools && python gen_v3.py --state`
Expected: Prints default world state JSON.

Run: `cd tools && python gen_v3.py --validate`
Expected: "World state valid."

Run: `cd tools && python gen_v3.py --reset`
Expected: "World state reset to canon baseline."

- [ ] **Step 7: Commit**

```bash
git add tools/gen_v3.py
git commit -m "feat: add v3 generator infrastructure — WorldState, Context, CLI, output formatting"
```

---

## Task 4: NPC Generator

**Files:**
- Modify: `tools/gen_v3.py`

The core generator. Compositional backstory engine with trait-driven modifiers and relationship wiring.

- [ ] **Step 1: Add `gen_npc()` function**

Builds from compositional slots: origin + career + trauma + secret + habit + physical + debt + traits + relationships. Uses `Context` for cross-referencing and dedup.

```python
def gen_npc(ctx, tone=None, planet=None, era=None):
    tone = tone or pick_tone()
    first, last, gender = ctx.fresh_name()
    G, g, gp, go = pronouns(gender)
    age = RI(22, 58)
    job = ctx.pick_fresh(JOBS, "jobs")
    traits = pick_traits()
    faction_key = R(list(FACTIONS.keys()))
    faction = FACTIONS[faction_key]

    # Compositional build
    origin = R(ORIGINS).format(first=first, last=last, g=G, gl=g, gp=gp, go=go,
        faction=faction["name"], location=ctx.pick_fresh(LOCATIONS_FLAT, "locations"),
        prev_job=R(JOBS), prev_location=R(LOCATIONS_FLAT), event=R(EVENTS), years=R(["six","seven","eight","nine","eleven"]))

    trauma = R(TRAUMAS).format(first=first, g=G, gl=g, gp=gp, go=go,
        event=R(EVENTS), body_part=R(["left hand","neck","temple","forearm","shoulder"]),
        trauma_cause=R(["a mining accident","a bar fight on Karnaith","equipment malfunction","a memory gap"]))

    habit = ctx.pick_fresh(HABITS, "habits")
    physical = ctx.pick_fresh(PHYSICAL, "physical")
    debt = R(DEBTS)
    secret = R(SECRETS)

    middle = R(MIDDLES).format(first=first, g=G, gl=g, gp=gp, go=go,
        item=R(ITEMS), brand=R(list(BRANDS.keys())), habit=habit, location=R(LOCATIONS_FLAT))

    secret_text = R(SECRET_TEMPLATES).format(first=first, last=last, g=G, gl=g, gp=gp, go=go,
        secret=secret, location=R(LOCATIONS_FLAT), faction=faction["name"],
        lore=R(LORE))

    # Trait-driven dialogue
    lines = []
    for ctx_type in RS(["greeting","warning","observation","rumor","complaint","memory"], RI(5,7)):
        line = get_dialogue(ctx_type, tone, traits[0] if traits else None)
        lines.append(line)

    # Relationship wiring (to existing NPCs in batch)
    rel_text = ""
    if ctx.npcs:
        other = R(ctx.npcs)
        rel_type = R(RELATIONSHIP_TYPES)
        rel_text = f"\n**Connection:** {rel_type.replace('_', ' ')} of {other['name']}."

    backstory = enforce_contractions(f"{origin}\n\n{middle}\n\n{secret_text}", tone)

    # Build NPC data for context tracking
    npc_data = {
        "name": f"{first} {last}",
        "id": f"{first.lower()}_{last.lower()}",
        "gender": gender, "age": age, "job": job,
        "traits": traits, "faction": faction_key,
        "tone": tone, "alive": True,
        "location": R(LOCATIONS_FLAT) if LOCATIONS_FLAT else "unknown",
        "arc_stage": "stable",
        "relationships": {},
    }
    ctx.add_npc(npc_data)

    g_label = {"M": "Male", "F": "Female", "NB": "Non-binary"}[gender]
    return f"""## NPC: {first} {last}
**Gender:** {g_label} | **Age:** {age} | **Occupation:** {job}
**Traits:** {', '.join(traits)}
**Faction:** {faction["name"]}
**Physical:** {physical}
**Habit:** {habit}
**Tone:** {tone}

**Background:**
{backstory}

**Dialogue:**
{chr(10).join('- "' + enforce_contractions(l, tone) + '"' for l in lines)}
{rel_text}
"""
```

- [ ] **Step 2: Register in GENERATORS dict**

```python
GENERATORS["npc"] = (gen_npc, "NPC")
```

- [ ] **Step 3: Note — LOCATIONS_FLAT is already defined in Task 3 infrastructure**

It is built from LOCATIONS at module level and available to all generators. No action needed here.

- [ ] **Step 4: Test NPC generation**

Run: `cd tools && python gen_v3.py --type npc --count 3`
Expected: 3 unique NPCs with backstories, dialogue, traits, no crashes.

- [ ] **Step 5: Commit**

```bash
git add tools/gen_v3.py
git commit -m "feat: add compositional NPC generator with trait-driven dialogue"
```

---

## Task 5: Quest Generator (30+ Archetypes)

**Files:**
- Modify: `tools/gen_v3.py`

30+ quest archetypes organized by genre. Each archetype is a function that fills variable slots from context.

- [ ] **Step 1: Add quest archetype templates**

Define quest archetypes as template dicts:

```python
QUEST_ARCHETYPES = {
    # SURVIVAL HORROR
    "containment_breach": {
        "genre": "survival_horror",
        "name_pool": ["Containment Breach", "Broken Seal", "It Got Out", "Protocol Failure"],
        "trigger": "The alarm in {section} hasn't stopped for three hours. {npc} says the seal failed. Something is loose.",
        "setup": "{sensory} The corridor ahead is dark. Not power-failure dark. Deliberately dark.",
        "objectives": [
            "Reach {section} without being detected.",
            "Assess the breach. Determine what escaped.",
            "Seal or destroy — the choice defines everything after."
        ],
        "choices": [
            "**Seal it back:** Restore containment. The thing is still alive. Still growing. But it's contained. For now.",
            "**Destroy it:** Burn the section. Lose everything inside — equipment, data, and anyone who didn't get out."
        ],
        "twists": ["The breach wasn't accidental. Someone opened it.", "What escaped isn't what was in the container."],
    },
    "the_thing_among_us": { ... },
    "quarantine": { ... },
    # ... 30+ archetypes across all 6 genres
}
```

Write at least 5 archetypes per genre (survival_horror, investigation, faction_tension, expedition, moral_dilemma, escalation) = 30+ total. Each has: name_pool, trigger, setup, objectives (3), choices (2), twists (2+).

- [ ] **Step 2: Add `gen_quest()` function**

Picks an archetype, fills slots from context (NPCs, locations, factions, items), applies tone blending:

```python
def gen_quest(ctx, tone=None):
    primary, secondary = pick_tone_blend() if not tone else (tone, pick_tone())
    archetype_key = R(list(QUEST_ARCHETYPES.keys()))
    arch = QUEST_ARCHETYPES[archetype_key]

    npc_ref = ctx.get_random_npc()
    npc_name = npc_ref["name"] if npc_ref else rname()
    faction = R(list(FACTIONS.values()))
    loc = ctx.pick_fresh(LOCATIONS_FLAT, "locations")
    item = ctx.pick_fresh(ITEMS, "items")
    section = f"Section {R('ABCDEFG')}"

    quest_name = R(arch["name_pool"])
    trigger = arch["trigger"].format(npc=npc_name, section=section, ...)
    setup = arch["setup"].format(sensory=ctx.fresh_sensory(primary), ...)
    # ... fill all template slots

    return f"""## QUEST: {quest_name}
**Genre:** {arch['genre']} | **Tone:** {primary} / {secondary}
**Location:** {loc} | **Faction:** {faction['name']}

**Trigger:**
{trigger}

**Setup:**
{setup}

{ctx.fresh_sensory(primary)}

**Objectives:**
1. {objectives[0]}
2. {objectives[1]}
3. {objectives[2]}

**The Choice:**
{R(arch['choices'])}

**Twist:**
{R(arch['twists'])}

**Reward:** {RI(3,12)} thermal cores, {R(["faction reputation shift","access to sealed area","new NPC ally","classified intel"])}
"""
```

- [ ] **Step 3: Register and test**

```python
GENERATORS["quest"] = (gen_quest, "Quest")
```

Run: `cd tools && python gen_v3.py --type quest --count 5`
Expected: 5 quests with different archetypes, tones, filled slots.

- [ ] **Step 4: Commit**

```bash
git add tools/gen_v3.py
git commit -m "feat: add quest generator with 30+ archetypes across 6 genres"
```

---

## Task 6: Datapad & History Generators

**Files:**
- Modify: `tools/gen_v3.py`

Multi-entry narrative arc datapads (5-7 entries each) and history event generator.

- [ ] **Step 1: Add history generator**

```python
def gen_history(ctx, tone=None):
    tone = tone or pick_tone()
    # Generate a "thing that happened before the player arrived"
    templates = [
        "Three survey teams preceded yours. Team {n}'s report was filed on Day {day}. Team {n2}'s report contradicted it. Team {n3}'s report was never filed.",
        "Section {section} was sealed on Day {day} of the previous posting. The seal is Mammona-grade. Nobody on this posting has the clearance to open it. Nobody on this posting ordered it sealed.",
        ...  # 15+ history event templates
    ]
    ...
GENERATORS["history"] = (gen_history, "History Event")
```

- [ ] **Step 2: Add datapad generator with 7 arc types**

Each arc type generates 5-7 entries that tell a complete story:

```python
def gen_datapad(ctx, tone=None):
    primary, secondary = pick_tone_blend() if not tone else (tone, pick_tone())
    arc_type = R(["research_log", "journal", "memo_chain", "unsent_letter_series",
                  "medical_report", "maintenance_log", "audio_transcript"])
    # Note: unsent_letter_series = letters that are NEVER SENT. Found folded, recycled, hidden.
    # The "unsent" constraint is the narrative device — increasing desperation with no outlet.

    # Get or create an author NPC
    author_first, author_last, author_g = ctx.fresh_name()
    G, g, gp, go = pronouns(author_g)
    loc = ctx.pick_fresh(LOCATIONS_FLAT, "locations")

    if arc_type == "research_log":
        return gen_datapad_research(ctx, primary, secondary, author_first, author_last, G, g, gp, go, loc)
    elif arc_type == "journal":
        return gen_datapad_journal(ctx, primary, secondary, ...)
    ...
```

Write a dedicated sub-function for each arc type. Each produces 5-7 entries with escalation, consistent NPC/location references, and a payoff in the final entry.

- [ ] **Step 3: Register and test**

```python
GENERATORS["datapad"] = (gen_datapad, "Data Pad")
```

Run: `cd tools && python gen_v3.py --type datapad --count 3`
Expected: 3 multi-entry datapads with coherent narrative arcs.

- [ ] **Step 4: Commit**

```bash
git add tools/gen_v3.py
git commit -m "feat: add datapad generator (7 arc types) and history generator"
```

---

## Task 7: Expanded Generators

**Files:**
- Modify: `tools/gen_v3.py` (or create `tools/gen_v3_expanded.py` if main file is getting large)

Robot, company, vehicle, weapon, artifact, entity generators. Rebuilt from v2 with compositional approach and context awareness.

- [ ] **Step 1: Add robot/AI generator**

Carry forward from v2 `lore_generator.py:gen_robot()`, rebuild with structured pools, context bag, and HERMES/Sunny/MARV-8 lore grounding.

- [ ] **Step 2: Add company generator**

From v2 `lore_gen_expanded.py:gen_company()`, rebuild with Mammona subsidiary structure.

- [ ] **Step 3: Add vehicle generator**

From v2, rebuild with canonical route references and context NPCs.

- [ ] **Step 4: Add weapon generator**

From v2, rebuild with Fortune Arms lore and atmospheric found-contexts.

- [ ] **Step 5: Add artifact generator**

From v2, rebuild with precursor/Xenolith origins and cosmic horror properties.

- [ ] **Step 6: Add entity generator**

From v2, rebuild with Lovecraftian "process not creature" framing.

- [ ] **Step 7: Add location and faction generators**

Location generator using structured LOCATIONS pool. Faction generator with fringe faction generation.

- [ ] **Step 8: Register all and test**

```python
GENERATORS.update({
    "robot": (gen_robot, "Robot/AI"),
    "company": (gen_company, "Company"),
    "vehicle": (gen_vehicle, "Vehicle"),
    "weapon": (gen_weapon, "Weapon"),
    "artifact": (gen_artifact, "Artifact"),
    "entity": (gen_entity, "Entity"),
    "location": (gen_location, "Location"),
    "faction": (gen_faction, "Faction"),
})
```

Run: `cd tools && python gen_v3.py --count 20`
Expected: Mix of all generator types, no crashes.

- [ ] **Step 9: Commit**

```bash
git add tools/gen_v3.py  # or tools/gen_v3_expanded.py if split
git commit -m "feat: add expanded generators — robot, company, vehicle, weapon, artifact, entity, location, faction"
```

---

## Task 8: Relationship Web & NPC Wiring

**Files:**
- Modify: `tools/gen_v3.py`

Wire NPCs together in batches. Bidirectional relationships, web-aware prose generation.

- [ ] **Step 1: Add relationship wiring to batch generation**

After generating NPCs in a batch, wire them together:

```python
def wire_relationships(ctx):
    """Wire NPCs in a batch into a relationship web."""
    npcs = ctx.npcs
    if len(npcs) < 2:
        return
    # Each NPC gets 1-3 relationships to other NPCs in batch
    for npc in npcs:
        n_rels = RI(1, min(3, len(npcs) - 1))
        others = [o for o in npcs if o["id"] != npc["id"]]
        for other in RS(others, n_rels):
            rel_type = R(RELATIONSHIP_TYPES)
            history = generate_relationship_history(npc, other, rel_type)
            # Bidirectional
            npc["relationships"][other["id"]] = {"type": rel_type, "status": "active", "history": history}
            inverse = get_inverse_relationship(rel_type)
            other["relationships"][npc["id"]] = {"type": inverse, "status": "active", "history": history}

def get_inverse_relationship(rel_type):
    INVERSES = {
        "mentor": "protege", "protege": "mentor",
        "debtor": "creditor", "creditor": "debtor",
        "killed": "killed_by", "killed_by": "killed",
        "blackmailer": "blackmailed_by", "blackmailed_by": "blackmailer",
        "betrayed_by": "betrayer_of", "betrayer_of": "betrayed_by",
        "saved_life_of": "owes_life_to", "owes_life_to": "saved_life_of",
        "commanding_officer": "subordinate", "subordinate": "commanding_officer",
        "parent": "child", "child": "parent",
    }
    return INVERSES.get(rel_type, rel_type)  # symmetric types return themselves

def generate_relationship_history(npc, other, rel_type):
    templates = {
        "ex_partner": [f"separated after {R(LOCATIONS_FLAT)}", "it ended badly", "nobody talks about it"],
        "mentor": [f"trained {other['name'].split()[0]} on {R(LOCATIONS_FLAT)}", "took them under their wing"],
        "debtor": [f"owes for {R(['shuttle passage','a medical procedure','silence','a favor on Karnaith'])}"],
        "rival": [f"competing since {R(LOCATIONS_FLAT)}", "same job, different methods"],
        "crew_mate": [f"served together on {R(LOCATIONS_FLAT)}", f"survived {R(EVENTS)} together"],
        ...
    }
    pool = templates.get(rel_type, [f"connected through {R(EVENTS)}"])
    return R(pool)
```

- [ ] **Step 2: Hook into batch and world generation**

Call `wire_relationships(ctx)` after NPC generation in `generate_batch()` and `generate_world()`.

- [ ] **Step 3: Add arc-stage-aware dialogue selection**

When an NPC has an arc_stage other than "stable", modify their dialogue pool:
```python
ARC_STAGE_TONE_MAP = {
    "desperate": "desperate", "broken": "numb", "paranoid": "paranoid",
    "vengeful": "furious", "contaminated": "wrongness", "changed": "cosmic_horror",
    "obsessed": "obsession", "grief": "grief", "violent": "furious",
    "sick": "body_horror", "lost": "dissociation",
}

def get_arc_dialogue_tone(npc):
    """If NPC has a non-stable arc stage, return a tone override for their dialogue."""
    stage = npc.get("arc_stage", "stable")
    return ARC_STAGE_TONE_MAP.get(stage)
```

In `gen_npc()` and `gen_quest()`, when picking dialogue for an NPC with a known arc_stage, use the overridden tone:
```python
dialogue_tone = get_arc_dialogue_tone(npc_ref) or tone
line = get_dialogue(ctx_type, dialogue_tone, traits[0])
```

- [ ] **Step 4: Make quest generator relationship-aware**

If a quest picks an NPC from context who has relationships, reference the connected NPCs:
```python
# In gen_quest, after picking npc_ref:
if npc_ref and npc_ref.get("relationships"):
    connected = R(list(npc_ref["relationships"].keys()))
    connected_npc = next((n for n in ctx.npcs if n["id"] == connected), None)
    if connected_npc:
        # Weave into quest text
        rel = npc_ref["relationships"][connected]
        ...
```

- [ ] **Step 5: Test batch with relationships**

Run: `cd tools && python gen_v3.py --batch 10`
Expected: 10 pieces where NPCs reference each other, quests mention NPC connections, arc stages affect dialogue tone.

- [ ] **Step 6: Commit**

```bash
git add tools/gen_v3.py
git commit -m "feat: add relationship web — bidirectional NPC wiring, arc-stage dialogue, web-aware generation"
```

---

## Task 9: Divergence Engine

**Files:**
- Modify: `tools/gen_v3.py`

State tracking, constraint propagation, divergence proposal/commit/revert, NPC lifecycle.

- [ ] **Step 1: Add divergence proposal generator**

```python
def propose_divergences(ws):
    """Propose 1-3 divergence events based on current world state."""
    proposals = []
    # Faction migration
    proposals.append({
        "id": f"div_{len(ws.data['divergences'])+1:03d}",
        "subject": R(list(FACTIONS.keys())),
        "type": R(["faction_migration", "npc_death", "faction_conflict", "secret_revealed",
                    "territory_change", "alliance_formed", "betrayal"]),
        ...
    })
    return proposals[:RI(1,3)]
```

- [ ] **Step 2: Add commit and revert logic**

Wire `--commit` and `--revert` CLI args to WorldState methods:

```python
def commit_divergence(ws, div_id):
    # Load from proposals, add to world state
    ...

def revert_divergence(ws, div_id):
    ws.data["divergences"] = [d for d in ws.data["divergences"] if d["id"] != div_id]
    ws.save()
```

- [ ] **Step 3: Add constraint checking to generators**

Before generating content that references a faction's territory or NPC's status, check world state:

```python
def check_faction_location(ws, faction_key, location):
    """Check if a faction is still valid at a location, considering divergences."""
    if ws.is_invalidated(f"{faction_key}_controls_{location}"):
        return False
    return True
```

- [ ] **Step 4: Add NPC lifecycle updates**

```python
def update_npc_state(ws, npc_id, changes):
    """Update an NPC's state and propagate through relationship web."""
    npc = ws.get_npc(npc_id)
    if not npc:
        return
    for key, val in changes.items():
        npc[key] = val
    # If NPC died, propagate through relationships
    if changes.get("alive") is False:
        for rel_id, rel in npc.get("relationships", {}).items():
            related = ws.get_npc(rel_id)
            if related:
                # Shift arc based on relationship type
                if rel["type"] in ("partner", "spouse", "mentor", "parent"):
                    related["arc_stage"] = "grief"
                elif rel["type"] in ("rival", "nemesis"):
                    related["arc_stage"] = "rebuilt"
    ws.set_npc(npc_id, npc)
    ws.save()
```

- [ ] **Step 5: Test divergence workflow**

Run: `cd tools && python gen_v3.py --diverge` → produces proposals
Run: `cd tools && python gen_v3.py --state` → shows current state
Run: `cd tools && python gen_v3.py --commit div_001` → commits divergence
Run: `cd tools && python gen_v3.py --state` → shows updated state with divergence
Run: `cd tools && python gen_v3.py --revert div_001` → reverts
Run: `cd tools && python gen_v3.py --state` → divergence removed

- [ ] **Step 6: Commit**

```bash
git add tools/gen_v3.py
git commit -m "feat: add divergence engine — proposal, commit, revert, NPC lifecycle, constraint propagation"
```

---

## Task 10: Integration & Overnight Testing

**Files:**
- Modify: `tools/gen_v3.py` (final polish)

End-to-end testing of all modes. Verify quality and overnight readiness.

- [ ] **Step 1: Test single generation for each type**

```bash
cd tools
python gen_v3.py --type npc
python gen_v3.py --type quest
python gen_v3.py --type datapad
python gen_v3.py --type robot
python gen_v3.py --type company
python gen_v3.py --type vehicle
python gen_v3.py --type weapon
python gen_v3.py --type artifact
python gen_v3.py --type entity
python gen_v3.py --type location
python gen_v3.py --type faction
python gen_v3.py --type history
```

Expected: Each produces well-formatted output, no crashes, no `KeyError`, no empty fields.

- [ ] **Step 2: Test batch mode**

```bash
python gen_v3.py --batch 20
```

Expected: 20 cross-referenced pieces. NPCs reference each other. Quests reference batch NPCs. No duplicate names within batch.

- [ ] **Step 3: Test world mode**

```bash
python gen_v3.py --world
```

Expected: Complete micro-universe with history events, interconnected NPCs, quests referencing those NPCs, datapads referencing the same events. Output is one coherent file.

- [ ] **Step 4: Test tone and planet filters**

```bash
python gen_v3.py --batch 10 --tone survival_horror
python gen_v3.py --batch 10 --planet erebus
python gen_v3.py --batch 10 --era fortuna
```

Expected: All output respects the filter constraints.

- [ ] **Step 5: Test loop mode (short run)**

```bash
python gen_v3.py --loop --delay 1 --batch 5
# Let run for ~10 seconds, Ctrl+C
```

Expected: Multiple batches generated, appended to single file, world state saved, no crashes on interrupt.

- [ ] **Step 6: Test divergence workflow end-to-end**

```bash
python gen_v3.py --diverge
python gen_v3.py --state
python gen_v3.py --batch 10  # should respect diverged state
python gen_v3.py --reset
```

- [ ] **Step 7: Review output quality**

Open the generated `proposals/procedural_v3_*.md` file. Verify:
- Writing quality matches v2 tone (dark, literary, textured)
- No AI slop ("delve", "tapestry", "myriad")
- Natural contractions in dialogue
- Formal tone in corporate memos
- Cross-references between pieces feel natural
- No lore violations

- [ ] **Step 8: Fix any issues found**

Address crashes, empty fields, lore violations, quality issues.

- [ ] **Step 9: Final commit**

```bash
git add tools/gen_v3.py tools/gen_pools_core.py tools/gen_pools_text.py
git commit -m "feat: v3 procedural generator complete — all generators, batch/world/loop modes, divergence engine"
```

---

## Execution Notes

- **Add `world_state.json` and `world_state_backup_*.json` to `.gitignore`** in the first commit.
- **Sentence structure variation rule:** Within each template category (ORIGINS, TRAUMAS, MIDDLES, SECRET_TEMPLATES), ensure at least 3 distinct sentence structures are represented. Don't write 15 origins that all start with "{first} {last} signed..." — vary the syntax.
- **`get_inverse_relationship()` must cover ALL asymmetric types** from RELATIONSHIP_TYPES. The code snippet in Task 8 shows 11 pairs — expand to cover all asymmetric relationships (parent/child, commanding_officer/subordinate, mentor/protege, debtor/creditor, blackmailer/blackmailed_by, betrayed_by/betrayer_of, killed/killed_by, saved_life_of/owes_life_to, witnessed_death_of/witnessed_death_of). Symmetric types (partner, rival, crew_mate, sibling, co_conspirator, shares_secret_with, etc.) return themselves.
- **All `gen_*()` functions accept `tone=None, planet=None, era=None`** keyword args. Use `planet` to filter locations via `filter_locations_by_planet()`. Use `era` to filter events via `filter_events_by_era()`.
- **Tasks 1-2 are the heaviest** — writing thousands of lines of hand-crafted prose and structured data. These are the content foundation everything else builds on.
- **Tasks 3-9 are code-heavy** but shorter. The generator logic is relatively straightforward compositional template expansion.
- **Task 10 is integration testing** — catching the edge cases.
- If `gen_v3.py` exceeds ~1500 lines during tasks 4-9, split expanded generators (robot, company, vehicle, weapon, artifact, entity) into `tools/gen_v3_expanded.py` and import them.
- The lore bible at `lore/LORE_BIBLE.md` is the source of truth for all content. When writing pools, read it. Don't invent lore.
- Locked lore (Foras, Shaft 12, the Maw) must never be expanded by the generator. Reference only.
- All dialogue must use natural contractions except in formal tones (clinical, corporate_dystopia, military).
