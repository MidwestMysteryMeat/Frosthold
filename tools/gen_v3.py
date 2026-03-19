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
    FIRST_M, FIRST_F, FIRST_NB, LAST,
    ROBO_PRE, ROBO_NUM, ROBO_NICK,
    JOBS, JOBS_MAMMONA, JOBS_EREBUS, JOBS_CRIMINAL, JOBS_SHIPBOARD, JOBS_COLONY,
    FACTIONS, FACTION_NAMES, PLANET_FACTION_CONSTRAINTS,
    FRINGE_ADJ, FRINGE_NOUN, FRINGE_TYPES,
    LOCATIONS, LOCATION_NAMES, PLANETS,
    ITEMS, ITEMS_MAMMONA, ITEMS_PRECURSOR, ITEMS_PERSONAL, ITEMS_CONTRABAND, ITEMS_BRAND,
    EVENTS, EVENTS_FORTUNA, EVENTS_CORPORATE, EVENTS_PRESENT, EVENTS_COLONY, EVENTS_PERSONAL,
    ERAS,
    BRANDS, BRAND_NAMES,
    TRAITS_P, TRAITS_N, TRAITS_X, TRAIT_CONFLICTS,
    HABITS, PHYSICAL, DEBTS, SECRETS, LORE, LOCKED_LORE,
    RELATIONSHIP_TYPES, ARC_PROGRESSIONS, ARC_STAGES,
    name, rname, robot_name, pronouns, pick_traits,
)

from gen_pools_text import (
    TONE_FAMILIES, TONES, SENSORY, DIALOGUE,
    ORIGINS, TRAUMAS, MIDDLES, SECRET_TEMPLATES,
    CONTRACTION_MAP, FORMAL_TONES, TRAIT_VOICE,
    enforce_contractions, apply_trait_voice,
    sensory, pick_tone, pick_tone_blend, get_dialogue,
)

# ============================================================
# SHORTCUTS & CONSTANTS
# ============================================================

R = random.choice
RI = random.randint
PROPOSALS_DIR = Path("F:/IceRimworld/proposals")
PROPOSALS_DIR.mkdir(parents=True, exist_ok=True)
STATE_PATH = Path(__file__).parent / "world_state.json"

# ============================================================
# FLAT POOL EXTRACTION
# ============================================================

# LOCATIONS is a dict of dicts; flatten to a name list
LOCATIONS_FLAT = []
for _loc_data in LOCATIONS.values():
    if isinstance(_loc_data, dict):
        LOCATIONS_FLAT.append(_loc_data.get("name", ""))
    elif isinstance(_loc_data, str):
        LOCATIONS_FLAT.append(_loc_data)
if not LOCATIONS_FLAT:
    LOCATIONS_FLAT = ["Erebus", "Karnaith", "Thalassa Deep", "Rhea-2", "Hyades"]

# ITEMS is already a flat list; no extraction needed.
# EVENTS is already a flat list; no extraction needed.


# ============================================================
# WORLD STATE — persistent across generator runs
# ============================================================

class WorldState:
    """
    Persistent state across generator runs.
    JSON file as single source of truth.
    """
    SCHEMA_VERSION = 1
    DEFAULT = {
        "version": 1,
        "divergences": [],
        "npc_states": {},
        "faction_states": {},
        "events_occurred": [],
        "frequency": {},
        "generation_log": [],
    }

    def __init__(self, path=STATE_PATH):
        self.path = Path(path)
        self.data = None
        self._load()

    def _load(self):
        """Load with corruption recovery."""
        if self.path.exists():
            try:
                raw = self.path.read_text(encoding="utf-8")
                data = json.loads(raw)
                self._validate(data)
                self.data = data
                return
            except (json.JSONDecodeError, ValueError, KeyError) as e:
                # Corruption recovery: backup the bad file, start fresh
                backup_path = self.path.with_suffix(f".corrupt_{int(time.time())}.json")
                try:
                    shutil.copy2(self.path, backup_path)
                except OSError:
                    pass
                print(f"Warning: world state corrupted ({e}), backed up to {backup_path.name}, starting fresh.")
        self.data = json.loads(json.dumps(self.DEFAULT))

    def _validate(self, data):
        """Check required keys and types."""
        required_keys = {
            "version": int,
            "divergences": list,
            "npc_states": dict,
            "faction_states": dict,
            "events_occurred": list,
            "frequency": dict,
            "generation_log": list,
        }
        for key, expected_type in required_keys.items():
            if key not in data:
                raise KeyError(f"Missing required key: {key}")
            if not isinstance(data[key], expected_type):
                raise ValueError(f"Key '{key}' expected {expected_type.__name__}, got {type(data[key]).__name__}")

    def save(self):
        """Atomic write: write to tmp file then rename."""
        tmp_path = self.path.with_suffix(".tmp")
        try:
            tmp_path.write_text(
                json.dumps(self.data, indent=2, ensure_ascii=False),
                encoding="utf-8",
            )
            # On Windows, os.replace handles atomic overwrite
            os.replace(str(tmp_path), str(self.path))
        except OSError as e:
            print(f"Error saving world state: {e}")
            # Clean up tmp if rename failed
            if tmp_path.exists():
                try:
                    tmp_path.unlink()
                except OSError:
                    pass

    def backup(self, label=""):
        """Create a labeled backup of the current state."""
        if not self.path.exists():
            return
        suffix = f"_{label}" if label else ""
        backup_path = self.path.with_suffix(f".backup{suffix}_{int(time.time())}.json")
        shutil.copy2(self.path, backup_path)
        print(f"World state backed up to: {backup_path.name}")

    def reset(self):
        """Reset to default state."""
        self.data = json.loads(json.dumps(self.DEFAULT))
        self.save()

    def is_invalidated(self, tag):
        """Check if a tag has been invalidated by a divergence."""
        for div in self.data["divergences"]:
            if isinstance(div, dict) and tag in div.get("invalidates", []):
                return True
        return False

    def is_enabled(self, tag):
        """Check if a tag is enabled (not invalidated)."""
        return not self.is_invalidated(tag)

    def get_npc(self, npc_id):
        """Get NPC state by ID."""
        return self.data["npc_states"].get(npc_id)

    def set_npc(self, npc_id, state):
        """Set NPC state."""
        self.data["npc_states"][npc_id] = state

    def track_frequency(self, pool_name, entry):
        """
        Track how often an entry from a pool has been used.
        LRU reset: when all entries have been used at least once, reset counters.
        """
        freq = self.data["frequency"].setdefault(pool_name, {})
        freq[entry] = freq.get(entry, 0) + 1

    def get_frequency(self, pool_name, entry):
        """Get usage count for a specific entry in a pool."""
        return self.data["frequency"].get(pool_name, {}).get(entry, 0)

    def log_generation(self, gen_type, label, timestamp=None):
        """Log a generation event."""
        self.data["generation_log"].append({
            "type": gen_type,
            "label": label,
            "timestamp": timestamp or time.strftime("%Y-%m-%d %H:%M:%S"),
        })

    def add_divergence(self, divergence):
        """Add a narrative divergence to the world state."""
        self.data["divergences"].append(divergence)

    def record_event(self, event):
        """Record an event as having occurred."""
        self.data["events_occurred"].append(event)


# ============================================================
# CONTEXT — shared within a generation batch
# ============================================================

class Context:
    """
    Shared context within a generation batch.
    Tracks used elements for dedup and cross-referencing.
    """

    def __init__(self, world_state=None):
        self.world = world_state or WorldState()
        self.names_used = set()
        self.locations_used = set()
        self.items_used = set()
        self.sensory_used = set()
        self.npcs = []
        self.pieces = []

    def pick_fresh(self, pool, pool_name=None):
        """
        Pick an item from pool with frequency weighting and batch dedup.
        Handles both list and dict pools (dicts pick from values).
        """
        if isinstance(pool, dict):
            entries = list(pool.values())
        elif isinstance(pool, (list, tuple)):
            entries = list(pool)
        else:
            return pool

        if not entries:
            return None

        pname = pool_name or "unknown"

        # Build weights: lower frequency = higher weight
        weights = []
        for entry in entries:
            entry_key = str(entry) if not isinstance(entry, str) else entry
            freq = self.world.get_frequency(pname, entry_key)
            weights.append(1.0 / (1.0 + freq))

        # Zero out already-used-this-batch items if possible
        # Determine the used set based on pool_name
        used_set = None
        if pname in ("names", "FIRST_M", "FIRST_F", "FIRST_NB", "LAST"):
            used_set = self.names_used
        elif pname in ("locations", "LOCATIONS", "LOCATIONS_FLAT"):
            used_set = self.locations_used
        elif pname in ("items", "ITEMS"):
            used_set = self.items_used
        elif pname in ("sensory", "SENSORY"):
            used_set = self.sensory_used

        if used_set is not None:
            adjusted = []
            for i, entry in enumerate(entries):
                entry_key = str(entry) if not isinstance(entry, str) else entry
                if entry_key in used_set:
                    adjusted.append(0.0)
                else:
                    adjusted.append(weights[i])
            # If all zeroed out, fall back to original weights
            if any(w > 0 for w in adjusted):
                weights = adjusted

        # Weighted random selection
        total = sum(weights)
        if total <= 0:
            chosen = R(entries)
        else:
            r = random.random() * total
            cumulative = 0
            chosen = entries[-1]
            for i, w in enumerate(weights):
                cumulative += w
                if r <= cumulative:
                    chosen = entries[i]
                    break

        # Track
        chosen_key = str(chosen) if not isinstance(chosen, str) else chosen
        if used_set is not None:
            used_set.add(chosen_key)
        self.world.track_frequency(pname, chosen_key)

        return chosen

    def fresh_name(self):
        """Generate a unique name for this batch."""
        attempts = 0
        while attempts < 50:
            first, last, gender = name()
            full = f"{first} {last}"
            if full not in self.names_used:
                self.names_used.add(full)
                self.names_used.add(first)
                return first, last, gender
            attempts += 1
        # Fallback: just return whatever we get
        first, last, gender = name()
        return first, last, gender

    def fresh_sensory(self, tone):
        """Get a non-repeated sensory detail for the given tone."""
        pool = SENSORY.get(tone, SENSORY.get("dread", []))
        available = [s for s in pool if s not in self.sensory_used]
        if not available:
            available = pool
        if not available:
            return ""
        chosen = R(available)
        self.sensory_used.add(chosen)
        return chosen

    def add_npc(self, npc_data):
        """Register an NPC generated in this batch."""
        self.npcs.append(npc_data)

    def get_random_npc(self):
        """Get a random NPC from this batch, or None."""
        if not self.npcs:
            return None
        return R(self.npcs)

    def add_piece(self, content, label, gen_type):
        """Register a generated piece."""
        self.pieces.append({
            "content": content,
            "label": label,
            "type": gen_type,
            "timestamp": time.strftime("%H:%M:%S"),
        })


# ============================================================
# FILTER FUNCTIONS
# ============================================================

def filter_locations_by_planet(planet):
    """Return locations constrained to a specific planet."""
    if not planet:
        return LOCATIONS
    result = {}
    for key, loc in LOCATIONS.items():
        if isinstance(loc, dict) and loc.get("planet") == planet:
            result[key] = loc
    return result


def filter_events_by_era(era):
    """Return events constrained to a specific era."""
    if not era:
        return EVENTS
    era_map = {
        "fortuna": EVENTS_FORTUNA,
        "corporate": EVENTS_CORPORATE,
        "present": EVENTS_PRESENT,
    }
    return era_map.get(era, EVENTS)


# ============================================================
# SAFE FORMAT HELPER
# ============================================================

def safe_format(template, **kwargs):
    """Format template, leaving unfilled placeholders as-is."""
    import string
    try:
        return template.format(**kwargs)
    except KeyError:
        formatter = string.Formatter()
        result = []
        for literal, field_name, format_spec, conversion in formatter.parse(template):
            result.append(literal)
            if field_name is not None:
                if field_name in kwargs:
                    result.append(str(kwargs[field_name]))
                else:
                    result.append('{' + field_name + '}')
        return ''.join(result)


# ============================================================
# BODY PARTS & TRAUMA CAUSES (for backstory template slots)
# ============================================================

BODY_PARTS = [
    "left arm", "right arm", "left hand", "right hand", "left shoulder",
    "right shoulder", "jaw", "temple", "neck", "ribs", "left knee",
    "right knee", "lower back", "left eye", "right eye", "scalp",
    "forearm", "shin", "collarbone", "sternum", "wrist",
]

TRAUMA_CAUSES = [
    "a mining collapse on the deep bore",
    "a cryo pod malfunction during transit",
    "a reactor coolant leak in the engine bay",
    "a barricade breach during a raid",
    "an accident with a drill bit that shouldn't have been running",
    "a fight in the supply cache that nobody reported",
    "a contamination exposure nobody warned them about",
    "a shuttle crash on approach to the colony",
    "a Mammona 'training exercise' that used live rounds",
    "a confrontation with something in the bore shaft",
    "an airlock malfunction during EVA",
    "a chemical spill in the processing bay",
    "a skinwalker encounter on the perimeter",
    "shrapnel from a detonation charge set too early",
    "a fall from the scaffolding during a night shift",
]


# ============================================================
# QUEST HOOKS
# ============================================================

QUEST_HOOKS = [
    "After day 15, {first} starts leaving notes in the common room. Each one contains a single coordinate.",
    "{first} asks the player to retrieve {item} from {location}. Simple job. Except the room has been sealed since before the colony arrived.",
    "Every third shift, {first} disappears for two hours. {g} comes back smelling like copper and ozone.",
    "{first} insists someone on the colony isn't who they say they are. {g} has evidence. It's convincing.",
    "A sealed drive arrives addressed to {first}. {g} won't open it alone. Needs a witness.",
    "{first} wants to reach {location} before anyone else does. Won't say why. Offers everything {gl} has.",
    "Someone is leaving {first} threats. Written in a script that matches the precursor glyphs.",
    "{first} has been hearing the same frequency as the deep bore. In {gp} sleep. Getting louder.",
    "A dead colonist's data pad contains a message for {first}. Timestamped three days from now.",
    "{first} found {item} in a place it shouldn't be. Now {gl} can't stop dreaming about where it came from.",
    "{first} needs help destroying something before Mammona finds it. The window is closing.",
    "Someone {first} thought was dead just walked into the colony. {g} isn't happy to see them.",
]


# ============================================================
# NPC GENERATOR
# ============================================================

def gen_npc(ctx, tone=None, planet=None, era=None):
    """
    Compositional NPC backstory engine.
    Builds a unique character from independent slots: origin, career,
    trauma, secret, habit, physical, debt, traits, and relationships.
    """
    # --- Tone ---
    if not tone:
        tone = pick_tone()

    # --- Identity ---
    first, last, gender = ctx.fresh_name()
    g, gl, gp, go = pronouns(gender)
    age = RI(22, 58)
    gender_label = {"M": "Male", "F": "Female", "NB": "Non-binary"}[gender]

    # --- Job ---
    job = ctx.pick_fresh(JOBS, "JOBS")

    # --- Traits ---
    traits = pick_traits()

    # --- Faction ---
    faction_keys = list(FACTIONS.keys())
    if planet:
        valid_keys = [
            k for k in faction_keys
            if planet in FACTIONS[k].get("territory", [])
        ]
        if valid_keys:
            faction_keys = valid_keys
    faction_key = R(faction_keys)
    faction_data = FACTIONS[faction_key]
    faction_name = faction_data["name"]

    # --- Location (previous posting) ---
    prev_location = ctx.pick_fresh(LOCATIONS_FLAT, "LOCATIONS_FLAT")
    location = ctx.pick_fresh(LOCATIONS_FLAT, "LOCATIONS_FLAT")

    # --- Previous job ---
    prev_job = ctx.pick_fresh(JOBS, "JOBS")
    if prev_job == job:
        prev_job = ctx.pick_fresh(JOBS, "JOBS")

    # --- Event ---
    events = filter_events_by_era(era)
    event = R(events)

    # --- Item ---
    item = R(ITEMS)

    # --- Lore reference ---
    lore = R(LORE)

    # --- Secret ---
    secret = R(SECRETS)

    # --- Habit ---
    habit = ctx.pick_fresh(HABITS, "HABITS")

    # --- Physical detail ---
    physical = ctx.pick_fresh(PHYSICAL, "PHYSICAL")

    # --- Debt ---
    debt = R(DEBTS)

    # --- Body part & trauma cause ---
    body_part = R(BODY_PARTS)
    trauma_cause = R(TRAUMA_CAUSES)

    # --- Years (for backstory filler) ---
    years = str(RI(2, 14))

    # --- Brand ---
    brand = R(BRAND_NAMES) if BRAND_NAMES else "Sunny Fizz"

    # --- Template fill kwargs ---
    # Strip trailing period from habit for templates that add their own punctuation
    habit_bare = habit.rstrip(".")
    fill = dict(
        first=first, last=last, g=g, gl=gl, gp=gp, go=go,
        faction=faction_name, prev_location=prev_location,
        prev_job=prev_job, event=event, item=item, lore=lore,
        secret=secret, habit=habit_bare, body_part=body_part,
        trauma_cause=trauma_cause, years=years, brand=brand,
        location=location,
    )

    # --- Build backstory from templates ---
    origin = safe_format(R(ORIGINS), **fill)
    trauma = safe_format(R(TRAUMAS), **fill)
    middle = safe_format(R(MIDDLES), **fill)
    secret_line = safe_format(R(SECRET_TEMPLATES), **fill)

    # Add a sensory detail for atmosphere
    sense = ctx.fresh_sensory(tone)

    backstory_parts = [origin, trauma, middle, secret_line]
    if sense:
        backstory_parts.append(sense)
    backstory = "\n\n".join(backstory_parts)

    # --- Apply contractions ---
    backstory = enforce_contractions(backstory, tone)

    # --- Dialogue lines ---
    primary_trait = traits[0] if traits else None
    dialogue_contexts = ["greeting", "warning", "confession", "observation", "rumor"]
    # Add varied contexts based on tone
    extra_contexts = ["complaint", "memory", "threat", "plea", "joke", "prayer"]
    dialogue_contexts.append(R(extra_contexts))
    if random.random() > 0.5:
        dialogue_contexts.append(R(extra_contexts))

    dialogue_lines = []
    used_lines = set()
    for dctx in dialogue_contexts:
        line = get_dialogue(dctx, tone, primary_trait)
        if line not in used_lines and line != "...":
            dialogue_lines.append(line)
            used_lines.add(line)

    # --- Relationship wiring ---
    relationship_text = ""
    other_npc = ctx.get_random_npc()
    if other_npc:
        rel_type = R(RELATIONSHIP_TYPES)
        other_name = other_npc["name"]
        rel_label = rel_type.replace("_", " ")
        relationship_text = f"{rel_label} of {other_name}"
        # Wire the relationship into both NPCs' data
        other_npc.setdefault("relationships", {})[f"{first}_{last}"] = rel_type

    # --- Quest hook ---
    hook_fill = dict(
        first=first, g=g, gl=gl, gp=gp, go=go,
        item=R(ITEMS), location=R(LOCATIONS_FLAT),
    )
    quest_hook = safe_format(R(QUEST_HOOKS), **hook_fill)
    quest_hook = enforce_contractions(quest_hook, tone)

    # --- Register NPC in context ---
    npc_data = {
        "name": f"{first} {last}",
        "id": f"{first.lower()}_{last.lower()}",
        "gender": gender,
        "age": age,
        "job": job,
        "traits": traits,
        "faction": faction_key,
        "tone": tone,
        "alive": True,
        "location": location,
        "arc_stage": "stable",
        "relationships": {},
    }
    if relationship_text and other_npc:
        rel_type_used = R(RELATIONSHIP_TYPES)
        npc_data["relationships"][other_npc["id"]] = rel_type_used
    ctx.add_npc(npc_data)

    # --- Also persist to world state ---
    ctx.world.set_npc(npc_data["id"], npc_data)

    # --- Format output ---
    trait_str = ", ".join(traits)
    dialogue_block = "\n".join(f'- "{line}"' for line in dialogue_lines)

    connection_line = f"**Connection:** {relationship_text}" if relationship_text else "**Connection:** None yet — first in batch"

    output = f"""## NPC: {first} {last}
**Gender:** {gender_label} | **Age:** {age} | **Occupation:** {job}
**Traits:** {trait_str}
**Faction:** {faction_name}
**Physical:** {physical}
**Habit:** {habit}
**Debt:** {debt}
**Tone:** {tone}

**Background:**
{backstory}

**Dialogue:**
{dialogue_block}

{connection_line}

**Quest Hook:**
{quest_hook}"""

    return output


# ============================================================
# QUEST DATA — imported from gen_pools_quest.py
# ============================================================

from gen_pools_quest import QUEST_ARCHETYPES, COLONY_SECTIONS, REWARD_TYPES


# ============================================================
# QUEST GENERATOR
# ============================================================

def gen_quest(ctx, tone=None, planet=None, era=None):
    """
    Compositional quest generator.
    Picks an archetype, fills template slots with context-appropriate values,
    applies tone blending and sensory details, adds NPC dialogue.
    """
    # --- Tone blending ---
    if tone:
        primary = tone
        secondary = pick_tone()
        # Avoid same tone for secondary
        if secondary == primary:
            secondary = pick_tone()
    else:
        primary, secondary = pick_tone_blend()

    # --- Pick archetype ---
    archetype_keys = list(QUEST_ARCHETYPES.keys())
    archetype_key = ctx.pick_fresh(archetype_keys, "quest_archetypes")
    archetype = QUEST_ARCHETYPES[archetype_key]
    genre = archetype["genre"]

    # --- NPC for the quest ---
    # Try cross-referencing an existing NPC from this batch
    existing_npc = ctx.get_random_npc()
    if existing_npc:
        npc_full = existing_npc["name"]
        parts = npc_full.split()
        npc_first = parts[0] if parts else npc_full
    else:
        first, last, gender = ctx.fresh_name()
        npc_full = f"{first} {last}"
        npc_first = first

    # --- Location ---
    location = ctx.pick_fresh(LOCATIONS_FLAT, "LOCATIONS_FLAT")

    # --- Faction ---
    faction_keys = list(FACTIONS.keys())
    faction_key = R(faction_keys)
    faction_data = FACTIONS[faction_key]
    faction_name = faction_data["name"]

    # --- Item ---
    item = R(ITEMS)

    # --- Section ---
    section = R(COLONY_SECTIONS)

    # --- Sensory detail from primary tone ---
    sense = ctx.fresh_sensory(primary)

    # --- Lore reference ---
    lore = R(LORE)

    # --- Secret ---
    secret = R(SECRETS)

    # --- Event ---
    events = filter_events_by_era(era)
    event = R(events)

    # --- Template fill dict ---
    fill = dict(
        npc=npc_full,
        npc_first=npc_first,
        location=location,
        faction=faction_name,
        item=item,
        section=section,
        sensory=sense,
        lore=lore,
        secret=secret,
        event=event,
    )

    # --- Fill archetype templates ---
    quest_name = safe_format(R(archetype["name_pool"]), **fill)
    trigger = safe_format(archetype["trigger"], **fill)
    setup = safe_format(archetype["setup"], **fill)
    objectives = [safe_format(obj, **fill) for obj in archetype["objectives"]]
    choice_block = safe_format(R(archetype["choices"]), **fill)
    twist = safe_format(R(archetype["twists"]), **fill)

    # --- Additional sensory detail from secondary tone ---
    sense2 = ctx.fresh_sensory(secondary)

    # --- Apply contractions ---
    trigger = enforce_contractions(trigger, primary)
    setup = enforce_contractions(setup, primary)
    objectives = [enforce_contractions(obj, primary) for obj in objectives]
    choice_block = enforce_contractions(choice_block, primary)
    twist = enforce_contractions(twist, primary)

    # --- Dialogue lines ---
    primary_trait = None
    if existing_npc and existing_npc.get("traits"):
        primary_trait = existing_npc["traits"][0]

    quest_dialogue_contexts = ["confession", "warning", "observation", "plea"]
    line1_ctx = R(quest_dialogue_contexts)
    line2_ctx = R([c for c in quest_dialogue_contexts if c != line1_ctx])
    d_line1 = get_dialogue(line1_ctx, primary, primary_trait)
    d_line2 = get_dialogue(line2_ctx, primary, primary_trait)

    # --- Reward ---
    reward_cores = RI(3, 15)
    reward_type = safe_format(R(REWARD_TYPES), **fill)

    # --- Format objectives ---
    obj_block = "\n".join(f"{i+1}. {obj}" for i, obj in enumerate(objectives))

    # --- Build output ---
    output = f"""## QUEST: {quest_name}
**Genre:** {genre.replace('_', ' ').title()} | **Tone:** {primary} / {secondary}
**Location:** {location} | **Faction:** {faction_name}

**Trigger:**
{trigger}

**Setup:**
{setup}

{sense2}

**Objectives:**
{obj_block}

**The Choice:**
{choice_block}

**Twist:**
{twist}

**Dialogue During Quest:**
- {npc_first}: "{d_line1}"
- Player: [Respond / Stay Silent / Leave]
- {npc_first}: "{d_line2}"

**Reward:** {reward_cores} thermal cores, {reward_type}"""

    # --- Log in context ---
    ctx.world.log_generation("quest", quest_name)

    return output


# ============================================================
# GENERATORS REGISTRY
# ============================================================

# Populated by Tasks 4-9. Each entry: gen_type -> (gen_func, label)
# gen_func signature: gen_func(ctx, tone=None, planet=None, era=None) -> str
GENERATORS = {
    "npc": (gen_npc, "NPC"),
    "quest": (gen_quest, "Quest"),
}

# Weighted type distribution for random selection
GENERATOR_WEIGHTS = {
    "npc": 3,
    "quest": 3,
    "datapad": 4,
    "location": 2,
    "faction": 2,
    "robot": 2,
    "company": 2,
    "vehicle": 2,
    "weapon": 2,
    "artifact": 2,
    "entity": 1,
    "history": 1,
}


def generate_piece(gen_type=None, ctx=None, tone=None, planet=None, era=None):
    """Generate a single piece of content."""
    if not GENERATORS:
        return None, "No Generators", None

    if ctx is None:
        ctx = Context()

    if gen_type and gen_type in GENERATORS:
        gen_func, label = GENERATORS[gen_type]
        content = gen_func(ctx, tone=tone, planet=planet, era=era)
        ctx.add_piece(content, label, gen_type)
        return content, label, gen_type

    # Weighted random selection from available generators
    pool = []
    for gtype, weight in GENERATOR_WEIGHTS.items():
        if gtype in GENERATORS:
            pool.extend([gtype] * weight)

    if not pool:
        return None, "No Generators", None

    chosen_type = R(pool)
    gen_func, label = GENERATORS[chosen_type]
    content = gen_func(ctx, tone=tone, planet=planet, era=era)
    ctx.add_piece(content, label, chosen_type)
    return content, label, chosen_type


def generate_batch(size, ctx=None, tone=None, planet=None, era=None):
    """Generate a batch of interconnected pieces."""
    if not GENERATORS:
        print("No generators registered. Register generators in Tasks 4-9.")
        return []

    if ctx is None:
        ctx = Context()

    pieces = []
    for _ in range(size):
        content, label, gen_type = generate_piece(
            ctx=ctx, tone=tone, planet=planet, era=era,
        )
        if content is not None:
            pieces.append((content, label, gen_type))

    return pieces


def generate_world(ctx, tone=None, planet=None, era=None):
    """
    Generate a complete micro-universe: a set of interconnected pieces
    that form a coherent narrative cluster.
    """
    if not GENERATORS:
        print("No generators registered. Register generators in Tasks 4-9.")
        return []

    pieces = []

    # World generation order: locations, factions, NPCs, quests, datapads, etc.
    world_plan = [
        ("location", 2),
        ("faction", 1),
        ("npc", 4),
        ("quest", 2),
        ("datapad", 3),
    ]

    for gen_type, count in world_plan:
        if gen_type not in GENERATORS:
            continue
        for _ in range(count):
            content, label, gtype = generate_piece(
                gen_type=gen_type, ctx=ctx, tone=tone, planet=planet, era=era,
            )
            if content is not None:
                pieces.append((content, label, gtype))

    # Fill remaining types if available
    for gen_type in GENERATORS:
        if gen_type not in [p[0] for p in world_plan]:
            content, label, gtype = generate_piece(
                gen_type=gen_type, ctx=ctx, tone=tone, planet=planet, era=era,
            )
            if content is not None:
                pieces.append((content, label, gtype))

    return pieces


# ============================================================
# OUTPUT FORMATTING
# ============================================================

def format_output(pieces, seq_start=1):
    """
    Format pieces into markdown with sequence numbers and timestamps.
    Matches v2 format: `=` separator lines, `[SEQ:N]`, `[Label]`, `[HH:MM:SS]`.
    """
    lines = []
    for i, piece in enumerate(pieces):
        seq = seq_start + i
        if isinstance(piece, tuple) and len(piece) >= 2:
            content, label = piece[0], piece[1]
        elif isinstance(piece, dict):
            content = piece.get("content", "")
            label = piece.get("label", "Unknown")
        else:
            content = str(piece)
            label = "Unknown"

        timestamp = time.strftime("%H:%M:%S")
        lines.append(f"\n\n{'=' * 60}")
        lines.append(f"### [SEQ:{seq}] [{label}] [{timestamp}]")
        lines.append(f"{'=' * 60}\n")
        lines.append(content)

    return "\n".join(lines)


# ============================================================
# CLI
# ============================================================

def build_cli():
    parser = argparse.ArgumentParser(
        description="Frosthold Procedural Lore Generator v3",
    )
    parser.add_argument("--count", type=int, default=1,
                        help="Number of pieces to generate")
    parser.add_argument("--type", choices=[
        "npc", "quest", "datapad", "location", "faction",
        "robot", "company", "vehicle", "weapon", "artifact", "entity", "history",
    ], help="Generate a specific type")
    parser.add_argument("--batch", type=int, default=0,
                        help="Generate an interconnected batch of N pieces")
    parser.add_argument("--world", action="store_true",
                        help="Generate a complete micro-universe")
    parser.add_argument("--loop", action="store_true",
                        help="Run continuously until interrupted")
    parser.add_argument("--delay", type=float, default=2,
                        help="Delay between loop iterations (seconds)")
    parser.add_argument("--tone",
                        help="Force a specific tone")
    parser.add_argument("--planet",
                        help="Constrain to a specific planet")
    parser.add_argument("--era", choices=["fortuna", "corporate", "present"],
                        help="Constrain to a specific era")
    parser.add_argument("--output", default=None,
                        help="Output file path")
    parser.add_argument("--diverge", action="store_true",
                        help="Create a narrative divergence branch")
    parser.add_argument("--commit",
                        help="Commit a divergence by label")
    parser.add_argument("--revert",
                        help="Revert a divergence by label")
    parser.add_argument("--state", action="store_true",
                        help="Print current world state")
    parser.add_argument("--reset", action="store_true",
                        help="Reset world state to defaults")
    parser.add_argument("--validate", action="store_true",
                        help="Validate world state integrity")
    parser.add_argument("--auto-diverge", action="store_true",
                        help="Automatically create divergences in loop mode")
    return parser


# ============================================================
# MAIN
# ============================================================

def main():
    parser = build_cli()
    args = parser.parse_args()

    ws = WorldState()

    # --- State management commands ---

    if args.state:
        print(json.dumps(ws.data, indent=2, ensure_ascii=False))
        return

    if args.validate:
        try:
            ws._validate(ws.data)
            print("World state valid.")
        except (KeyError, ValueError) as e:
            print(f"World state invalid: {e}")
            raise SystemExit(1)
        return

    if args.reset:
        ws.backup("pre_reset")
        ws.reset()
        print("World state reset to defaults.")
        return

    if args.commit:
        label = args.commit
        ws.add_divergence({
            "label": label,
            "committed": time.strftime("%Y-%m-%d %H:%M:%S"),
            "invalidates": [],
        })
        ws.save()
        print(f"Divergence '{label}' committed.")
        return

    if args.revert:
        label = args.revert
        original_count = len(ws.data["divergences"])
        ws.data["divergences"] = [
            d for d in ws.data["divergences"]
            if not (isinstance(d, dict) and d.get("label") == label)
        ]
        removed = original_count - len(ws.data["divergences"])
        ws.save()
        if removed > 0:
            print(f"Divergence '{label}' reverted ({removed} removed).")
        else:
            print(f"No divergence found with label '{label}'.")
        return

    # --- Generation commands ---

    output_file = args.output or str(
        PROPOSALS_DIR / f"procedural_v3_{time.strftime('%Y%m%d_%H%M')}.md"
    )
    seq = 0
    ctx = Context(world_state=ws)

    try:
        if args.world:
            # Generate a complete micro-universe
            pieces = generate_world(
                ctx, tone=args.tone, planet=args.planet, era=args.era,
            )
            if not pieces:
                print("No generators registered. Register generators in Tasks 4-9.")
                return

            formatted = format_output(pieces, seq_start=1)
            with open(output_file, "a", encoding="utf-8") as f:
                f.write(formatted)

            for i, (content, label, _) in enumerate(pieces):
                print(f"  [{i+1}] {label}")
                ws.log_generation(_, label)

            ws.save()
            print(f"\nWorld generated: {len(pieces)} pieces saved to {output_file}")

        elif args.batch > 0:
            # Generate an interconnected batch
            pieces = generate_batch(
                args.batch, ctx=ctx, tone=args.tone,
                planet=args.planet, era=args.era,
            )
            if not pieces:
                print("No generators registered. Register generators in Tasks 4-9.")
                return

            formatted = format_output(pieces, seq_start=1)
            with open(output_file, "a", encoding="utf-8") as f:
                f.write(formatted)

            for i, (content, label, gtype) in enumerate(pieces):
                print(f"  [{i+1}] {label}")
                ws.log_generation(gtype, label)

            ws.save()
            print(f"\nBatch complete: {len(pieces)} pieces saved to {output_file}")

        elif args.loop:
            # Continuous generation with periodic backups
            print(f"Frosthold Lore Generator v3 -- Running continuously")
            print(f"Output: {output_file}")
            print("Ctrl+C to stop.\n")

            batch_count = 0
            while True:
                batch_count += 1
                seq += 1

                content, label, gen_type = generate_piece(
                    gen_type=args.type, ctx=ctx,
                    tone=args.tone, planet=args.planet, era=args.era,
                )

                if content is None:
                    print("No generators registered. Register generators in Tasks 4-9.")
                    return

                formatted = format_output(
                    [(content, label, gen_type)], seq_start=seq,
                )
                with open(output_file, "a", encoding="utf-8") as f:
                    f.write(formatted)

                ws.log_generation(gen_type, label)
                print(f"  [{seq}] {label}")

                # Auto-diverge support
                if args.auto_diverge and args.diverge and batch_count % 25 == 0:
                    div_label = f"auto_{batch_count}_{int(time.time())}"
                    ws.add_divergence({
                        "label": div_label,
                        "committed": time.strftime("%Y-%m-%d %H:%M:%S"),
                        "invalidates": [],
                        "auto": True,
                    })
                    print(f"  [DIVERGE] Auto-divergence: {div_label}")

                # Periodic backup every 100 generations
                if batch_count % 100 == 0:
                    ws.save()
                    ws.backup(f"loop_{batch_count}")

                time.sleep(args.delay)

        else:
            # Single or count mode
            for i in range(args.count):
                seq += 1
                content, label, gen_type = generate_piece(
                    gen_type=args.type, ctx=ctx,
                    tone=args.tone, planet=args.planet, era=args.era,
                )

                if content is None:
                    print("No generators registered. Register generators in Tasks 4-9.")
                    return

                formatted = format_output(
                    [(content, label, gen_type)], seq_start=seq,
                )
                with open(output_file, "a", encoding="utf-8") as f:
                    f.write(formatted)

                ws.log_generation(gen_type, label)
                print(content)

            ws.save()
            print(f"\nSaved {seq} entries to: {output_file}")

    except KeyboardInterrupt:
        ws.save()
        print(f"\nStopped after {seq} entries. State saved. Output: {output_file}")


if __name__ == "__main__":
    main()
