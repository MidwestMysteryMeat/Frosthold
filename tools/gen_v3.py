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
        self.history_events = []

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
# HISTORY GENERATOR
# ============================================================

HISTORY_TEMPLATES = [
    "Three survey teams preceded yours. Team {n}'s report was filed on Day {day}. Team {n2}'s report contradicted it. Team {n3}'s report was never filed.",
    "Section {section} was sealed on Day {day} of the previous posting. The seal is Mammona-grade. Nobody on this posting has the clearance to open it. Nobody on this posting ordered it sealed.",
    "A supply shuttle crashed on the north ridge {months} months ago. The cargo was recovered. The crew was not. The cargo manifest lists items that Mammona doesn't ship to survey postings.",
    "In {year}, {faction} conducted an unscheduled survey of {location}. The team spent {weeks} weeks on site. The report they filed was {pages} pages long. The redacted version is {redacted_pages} pages.",
    "The previous colony's reactor failed on Day {day}. Official cause: thermal runaway. Unofficial cause: someone opened a valve that doesn't appear on the engineering diagrams. The valve is still open.",
    "A colonist named {name} vanished from the roster {months} months before your crew arrived. No transfer order. No death certificate. Personal effects are still in Hab {hab}, untouched. Nobody reassigned the bunk.",
    "Day {day} of the prior posting: all {count} colonists reported the same dream. A corridor. A door. A sound behind the door. Mammona classified the incident as 'mass stress response.' The corridor exists. The door exists.",
    "{faction} deployed a listening post at {location} in {year}. The post transmitted for {weeks} weeks, then switched to a frequency not in Mammona's codebook. The transmissions continued for {months} months after the post was officially decommissioned.",
    "The geological survey from {year} describes the bore shaft as {depth} meters deep. Current readings show {depth2} meters. The drill hasn't run since the previous crew left.",
    "Fourteen crates arrived on the last supply drop before the previous posting ended. The manifest lists medical supplies. The crates weigh three times what medical supplies weigh. They were moved to Section {section} under guard. The lock code was changed after delivery.",
    "A distress signal was broadcast from {location} on Day {day}. Duration: {seconds} seconds. Content: a voice reciting numbers in a language the translation software couldn't identify. The signal's origin point is {meters} meters below the surface. There's nothing {meters} meters below the surface.",
    "The water recycler in Section {section} produced clean output for {weeks} weeks, then began adding trace amounts of a compound not in any database. The compound is harmless. It's also organic. The recycler is mechanical.",
    "{name} was the last person to leave the previous posting. {g} filed a final report consisting of a single sentence: 'It knows we're here.' The sentence was struck from the record. {name}'s current location is listed as '{location}.' {location} has been uninhabited for {years} years.",
    "During construction of the colony in {year}, the foundation team discovered a chamber {depth} meters below grade. The chamber was empty except for {count} identical marks on the walls. The marks match a Mammona corporate logo that wasn't designed until {year2}.",
    "The thermal core readings at {location} spike every {hours} hours. The interval matches no known geological cycle. It does match the heart rate of something very large and very slow.",
    "A sealed drive was found welded into the hull of the colony's original habitat module. The drive contains {pages} files. Each file is a personnel dossier for a member of your crew. The dossiers were created {months} months before your crew was assigned.",
    "The perimeter fence at the north boundary was replaced three times by the previous crew. Each time, something bent the posts inward. Not outward. Inward. The replacement posts are thicker gauge each time. The current posts are rated for vehicle impacts.",
    "Mammona's records show {count} supply drops to this site over {years} years. The colony's own records show {count2}. The difference is {diff} drops. Nobody can account for what they delivered.",
    "In the first week of the previous posting, the HERMES terminal in Section {section} displayed a message: 'WELCOME BACK.' The posting was new. Nobody had been welcomed back. HERMES has no record of the message.",
    "Someone carved a map into the floor of Section {section}. The map shows tunnels that don't exist. Or didn't exist when the map was carved. Three of the seven tunnels have since been discovered by the drill team.",
]

HISTORY_SIGNIFICANCE = [
    "The previous crew knew something. The question is whether their silence was chosen or enforced.",
    "Whatever happened here before your arrival wasn't an accident. It was a sequence.",
    "Mammona's records don't match reality. That's either incompetence or intent. Mammona isn't incompetent.",
    "The timeline doesn't add up. Something is missing, and the gap is shaped like a decision somebody made.",
    "This wasn't documented. Undocumented events on a Mammona posting aren't oversights. They're policy.",
    "The previous crew encountered something they couldn't explain. They explained it anyway, and the explanation is worse than the mystery.",
    "This pattern predates human presence on the planet. It continued through human presence on the planet. It's continuing now.",
    "There's a reason this information was left behind. Either as a warning or a trap. Both possibilities are concerning.",
    "The event was classified. The classification level is higher than any individual on the posting had access to. Someone else is watching.",
    "This changes the math. Every plan that assumes a stable environment needs revision.",
]

HISTORY_TITLES = [
    "The Sealed Section", "Prior Posting Anomaly", "The Missing Report",
    "Supply Manifest Discrepancy", "Signal Origin Unknown", "The Empty Chamber",
    "Geological Impossibility", "The Welded Drive", "Perimeter Breach Pattern",
    "The Carved Map", "Recycler Contamination", "Dream Concordance Event",
    "The Listening Post", "Roster Disappearance", "The Last Transmission",
    "Foundation Discovery", "Thermal Anomaly Cycle", "The Surplus Drops",
    "HERMES Welcome Event", "The Predecessor's Warning",
]


def gen_history(ctx, tone=None, planet=None, era=None):
    """
    Generates a historical event -- something that happened before the player arrived.
    Grounded in the Fortuna-to-Erebus timeline. Adds to ctx.history_events for cross-referencing.
    """
    if not tone:
        tone = pick_tone()

    first, last, gender = ctx.fresh_name()
    g, gl, gp, go = pronouns(gender)
    full_name = f"{first} {last}"

    location = ctx.pick_fresh(LOCATIONS_FLAT, "LOCATIONS_FLAT")
    faction_key = R(list(FACTIONS.keys()))
    faction_name = FACTIONS[faction_key]["name"]

    # Section letter for templates that use "Section {section}" patterns
    section = R(["A", "B", "C", "D", "E", "F", "G"])

    # Era-appropriate year
    if era == "fortuna":
        year = RI(2525, 2530)
        year2 = RI(2530, 2588)
    elif era == "corporate":
        year = RI(2530, 2588)
        year2 = RI(year + 1, 2590)
    else:
        year = RI(2550, 2589)
        year2 = RI(year + 1, 2590)

    era_label = era or R(["fortuna", "corporate", "present"])

    fill = dict(
        n=1, n2=2, n3=3,
        day=RI(1, 180), months=RI(2, 18), weeks=RI(2, 12),
        year=year, year2=year2,
        name=full_name, g=g, gl=gl, gp=gp, go=go,
        faction=faction_name, location=location, section=section,
        pages=RI(40, 400), redacted_pages=RI(3, 12),
        depth=RI(30, 300), depth2=RI(50, 500),
        count=RI(3, 20), count2=RI(5, 25), diff=RI(2, 8),
        hours=RI(4, 72), seconds=RI(7, 90), meters=RI(50, 800),
        hab=RI(1, 16), years=RI(3, 40),
    )

    # Ensure depth2 > depth for the geological survey template
    if fill["depth2"] <= fill["depth"]:
        fill["depth2"] = fill["depth"] + RI(20, 200)

    # Ensure count2 > count for the supply drop template
    if fill["count2"] <= fill["count"]:
        fill["count2"] = fill["count"] + fill["diff"]

    template = ctx.pick_fresh(HISTORY_TEMPLATES, "history_templates")
    event_text = safe_format(template, **fill)
    event_text = enforce_contractions(event_text, tone)

    # Add sensory atmosphere
    sense = ctx.fresh_sensory(tone)

    title = ctx.pick_fresh(HISTORY_TITLES, "history_titles")
    significance = R(HISTORY_SIGNIFICANCE)

    # Build event data for cross-referencing
    event_data = {
        "title": title,
        "era": era_label,
        "tone": tone,
        "text": event_text,
        "location": location,
        "name": full_name,
    }
    ctx.history_events.append(event_data)

    # Log in world state
    ctx.world.log_generation("history", title)

    output = f"""## HISTORY: {title}
**Era:** {era_label} | **Tone:** {tone}

{sense}

{event_text}

**Significance:** {significance}"""

    return output


# ============================================================
# DATAPAD GENERATOR — 7 arc types, 5-7 entries each
# ============================================================

DATAPAD_TYPES = [
    "research_log", "journal", "memo_chain", "unsent_letter_series",
    "medical_report", "maintenance_log", "audio_transcript",
]

DATAPAD_TYPE_LABELS = {
    "research_log": "Research Log",
    "journal": "Personal Journal",
    "memo_chain": "Internal Memo Chain",
    "unsent_letter_series": "Unsent Letters",
    "medical_report": "Medical Report",
    "maintenance_log": "Maintenance Log",
    "audio_transcript": "Audio Transcript",
}


def _datapad_research_log(ctx, tone, first, last, g, gl, gp, go, loc):
    """Researcher discovers anomaly -> files report -> report buried -> continues privately -> escalation -> disappearance."""
    day = RI(1, 120)
    lo = R(LORE)
    lo2 = R(LORE)
    colleague_first, colleague_last, colleague_g = ctx.fresh_name()
    cg, cgl, cgp, cgo = pronouns(colleague_g)
    colleague2_first, colleague2_last, colleague2_g = ctx.fresh_name()
    c2g, c2gl, c2gp, c2go = pronouns(colleague2_g)
    section = R(["A", "B", "C", "D", "E", "F", "G"])
    ref = f"AR-{RI(1000, 9999)}"
    cabinet = RI(1, 12)

    entries = []

    # Entry 1: Discovery
    entries.append(f"""Day {day}.

{ctx.fresh_sensory(tone)}

The samples aren't behaving. That's not the right word. Samples don't behave. They exhibit properties. These are exhibiting properties outside any reference material available to me. {lo} -- or what the brief says is {lo} -- has a thermal signature that inverts at night. It shouldn't have a thermal signature at all.

Ran the spectrograph three times. Same result. The crystalline structure shifts at the molecular level when the temperature drops below -20C. Not fracturing. Reorganizing. Like it's adapting.

-- {first} {last}, Lab {RI(1, 4)}""")

    # Entry 2: Report filed and buried
    entries.append(f"""Day {day + RI(2, 5)}.

Filed the anomaly report. Standard form. Ref {ref}. Dr. {colleague_last} reviewed it, handed it back, and told me to rerun the tests. I reran them. Same results. {g} told me to rerun them again.

I understand now that the form isn't for reporting anomalies. The form is for making anomalies disappear.

{colleague_first} from Lab 2 transferred out. No notice. {cgp.capitalize()} workstation was cleared by 0600. The samples are still here. Nobody came for them. Nobody came for {cgp} things either.""")

    # Entry 3: Private continuation
    entries.append(f"""Day {day + RI(7, 14)}.

{ctx.fresh_sensory(tone)}

I've stopped filing reports. I've started keeping this instead. The samples from {loc} are doing something at night that I can't explain with the equipment I've been given. So I requisitioned better equipment. Request denied. Budget code: INSUFFICIENT AUTHORIZATION.

I brought my personal spectrometer. The readings don't match the Mammona-issue unit. Not slightly off. Fundamentally different. Like the standard equipment is calibrated to miss what I'm finding.

That's not a malfunction. That's a decision someone made.""")

    # Entry 4: Escalation
    entries.append(f"""Day {day + RI(16, 25)}.

{colleague2_first} {colleague2_last} approached me after shift. Said {c2gl} saw my after-hours lab access in the logs. I expected a warning. Instead: "I've been seeing the same thing in {lo2}. For months. My reports go nowhere too."

We compared data. The correlation is -- I don't have a word for it. These aren't coincidences. There's a pattern. The pattern has intent.

I locked the data on a sealed drive. Personal encryption. If the standard equipment is lying to us, I don't trust the standard network either.""")

    # Entry 5: Things get worse
    entries.append(f"""Day {day + RI(28, 40)}.

{ctx.fresh_sensory(tone)}

Dr. {colleague2_last} didn't show up for shift. Transferred, they said. Same word they used for {colleague_first}. Same paperwork. Same empty workstation by morning.

I checked the sealed drive. The data I locked is still there. But there's a new file. I didn't create it. It's a personnel dossier. My personnel dossier. With a field I've never seen before: RETENTION STATUS. The value is PENDING.""")

    # Entry 6: Final entry
    final_options = [
        f"Check cabinet {cabinet}. The real readings are taped to the back panel. Compare them to what's in the system. Then decide what kind of person you want to be.\n\n-- {first} {last}\n\n[No further entries. The lab was reassigned on Day {day + RI(42, 60)}.]",
        f"I'm leaving this pad in {loc}. If you find it, the sealed drive is behind panel {RI(10, 40)} in the maintenance crawlspace off Section {section}. The encryption key is my mother's maiden name. Mammona doesn't have it. They don't have my mother's maiden name either. At least I hope they don't.\n\n-- {first}\n\n[The final entry was written in a different ink. The handwriting deteriorates toward the end.]",
        f"Something happened last night. I went to check the samples at 0300. They were arranged differently. Not scattered. Arranged. In a pattern I recognized from my own notes. Notes that are on the sealed drive. Notes that nobody has seen.\n\nI don't think I'm studying these samples anymore. I think they're studying me.\n\n-- {first} {last}\n\n[This datapad was found face-down on the lab bench. The lab was empty. The samples were gone.]",
    ]
    entries.append(f"Day {day + RI(42, 55)}.\n\n{R(final_options)}")

    return entries


def _datapad_journal(ctx, tone, first, last, g, gl, gp, go, loc):
    """Colonist arrives -> settles in -> notices something wrong -> deterioration -> final entry implies something terrible."""
    day = RI(1, 30)
    bunkmate_first, bunkmate_last, bunkmate_g = ctx.fresh_name()
    bp = pronouns(bunkmate_g)
    # Verb forms for bunkmate (singular/plural based on gender)
    bv_s = "" if bunkmate_g == "NB" else "s"  # "works" vs "work"
    bv_es = "" if bunkmate_g == "NB" else "es"  # "goes" vs "go"
    brand = R(BRAND_NAMES) if BRAND_NAMES else "Sunny Fizz"
    hab = RI(1, 16)
    section = R(["A", "B", "C", "D", "E", "F"])
    job = R(JOBS)

    entries = []

    # Entry 1: Arrival
    entries.append(f"""Day {day}. Or {day + 1}. The clock in the mess is wrong again and nobody fixes it because nobody cares anymore.

{ctx.fresh_sensory(tone)}

First impressions: it's exactly what the brochure promised if you read between the lines. Cold. Grey. The kind of place where the word 'amenities' means 'there's a roof.' The {brand} machine in the corridor works, which is more than I expected. Met my bunkmate -- {bunkmate_first} {bunkmate_last}. {bp[0]} work{bv_s} the drill. Doesn't talk much. Fine by me.

Keeping this journal because I promised. A record. Proof I was here. Proof I was me.""")

    # Entry 2: Settling in
    entries.append(f"""Day {day + RI(5, 12)}.

Getting the rhythm. Shift starts at 0600. NutriLoaf for breakfast. The work is -- work. I'm a {job} here, same as I was on the last posting. The cold's different though. It gets into the walls, the food, the conversations. Not just temperature. Atmosphere.

{bunkmate_first} said something strange at dinner: "{R([
    "Don't go past Section " + section + " after lights out. Nobody tells you that. I'm telling you.",
    "You'll start hearing things around week three. Everyone does. Don't worry about it.",
    "The last person in your bunk left in the middle of a shift. Didn't take " + bp[2] + " things.",
    "Count the people in the mess every morning. If the number changes, don't ask why.",
])}" I laughed. {bp[0]} didn't.""")

    # Entry 3: Something wrong
    entries.append(f"""Day {day + RI(18, 30)}.

{ctx.fresh_sensory(tone)}

Okay. So. I'm going to write this down because writing it down makes it real and if it's real then I'm not imagining it and if I'm not imagining it then I need to deal with it.

The {R([
    "shadows in the corridor outside Hab " + str(hab) + " don't match the light sources. I checked. Three times.",
    "wall in the maintenance tunnel is warm. Not heated-by-pipes warm. Warm like skin. And it pulses. I put my hand on it. I shouldn't have put my hand on it.",
    "comm system plays a tone at 0200 every night. Same tone. Three notes. I recorded it. The recording is silent. But I heard it. " + bunkmate_first + " heard it too.",
    "new colonist -- arrived last week -- knew my name. Knew my shift. Knew which bunk I sleep in. I've never met " + bp[2].replace('his','them').replace('her','them') + ". Nobody introduced us.",
])}

I asked {bunkmate_first} about it. {bp[0]} said: "Yeah." Just that. Yeah. Like I'd finally noticed the weather.""")

    # Entry 4: Deterioration
    entries.append(f"""Day {day + RI(35, 50)}.

Can't sleep. Thought it was the cold but it's not the cold. It's the quiet. Not silence -- there's always noise here, generators, pipes, wind. It's that the quiet is underneath the noise. Like the noise is a blanket over something that's listening.

{ctx.fresh_sensory(tone)}

{bunkmate_first} hasn't been to {bp[2]} bunk in three nights. {bp[0]} show{bv_s} up for shift. Eats. Works. But at lights out, {bp[1]} go{bv_es} somewhere else. I followed {bp[3]} last night. Stopped at Section {section}. The door was open. It shouldn't be open. I didn't go in.

I'm not going to go in.

My hands are shaking as I write this. That's new.""")

    # Entry 5: Things accelerate
    entries.append(f"""Day {day + RI(55, 70)}.

{R([
    "I dreamed about home. Except it wasn't home. The proportions were wrong. The sky was the wrong color. My mother's face was my mother's face but the expression belonged to someone who'd studied what 'mother' means without ever having one.",
    "Found a note under my mattress. My handwriting. I didn't write it. It says: 'STOP LOOKING.' I don't know what I was looking at.",
    "Mammona sent a psych evaluation form. I filled it out honestly. The results came back 'within normal parameters.' Every question. I said I was hearing things. Normal parameters. I said I was seeing things. Normal parameters. I said I was afraid. Normal. Parameters.",
    "The colony roster has a name I don't recognize. Been on the roster since day one. Nobody else recognizes it either. Nobody thinks that's strange. I think that's strange.",
])}

I want to go home. I keep saying that word -- home -- and each time it means less. Like a word you repeat until it's just sounds.""")

    # Entry 6: Final entry
    final_options = [
        f"I understand now. What {bunkmate_first} meant. What the quiet is. I'm not going to write it down because writing it down makes it real and if it's real then--\n\n[The entry ends here. The pen stroke continues off the edge of the screen as a single unbroken line.]",
        f"If someone finds this: don't read the rest of it. I'm serious. Close this pad and leave it where you found it. What I've written in the margins of the previous entries isn't meant for you. It's meant for--\n\n[Several lines of text have been overwritten so many times they're illegible. The final readable word is 'UNDERNEATH.']",
        f"Day {day + RI(75, 90)}.\n\nI went into Section {section} last night.\n\n{bunkmate_first} was there.\n\nEveryone was there.\n\n[The remaining pages contain a single symbol, repeated. It matches no known writing system. Analysis pending. Analysis has been pending for {RI(3, 14)} months.]",
        f"Today I looked in the mirror and for the first time in weeks, my reflection was doing the same thing I was doing. I should've been relieved. Instead I thought: what was it doing all those other times?\n\n[This datapad was found in the recycling queue. The owner's bunk was empty. Personal effects: undisturbed. Contract status: active.]",
    ]
    entries.append(R(final_options))

    return entries


def _datapad_memo_chain(ctx, tone, first, last, g, gl, gp, go, loc):
    """Corporate directive -> site acknowledges -> incident occurs -> reclassification -> memo forbidding discussion -> final memo from different department."""
    dept = RI(1, 99)
    dept2 = RI(1, 99)
    ref = f"MM-{RI(1000, 9999)}"
    ref2 = f"MM-{RI(1000, 9999)}"
    ref3 = f"MT-{RI(1000, 9999)}"
    lo = R(LORE)
    section = R(["A", "B", "C", "D", "E", "F", "G"])
    site = f"Site {R(['Alpha', 'Beta', 'Gamma', 'Delta'])}-{RI(1, 12)}"
    manager_first, manager_last, _ = ctx.fresh_name()
    director_first, director_last, _ = ctx.fresh_name()
    patch = f"MM-{RI(100, 999)}"

    entries = []

    # Entry 1: Corporate directive
    entries.append(f"""**FROM:** Regional Operations, Dept. {dept}
**TO:** Site Management, {loc}
**RE:** Operational Parameters Update -- Ref {ref}
**CLASSIFICATION:** Internal / Do Not Distribute

Per directive {ref}, effective immediately:

1. All personnel inquiries regarding {lo} are to be redirected to Regional. Do not confirm or deny. Standard NDA provisions apply (ref: Employment Contract, Section 14.{RI(1, 9)}).

2. Thermal core extraction quotas for {site} have been increased by {RI(15, 40)}%. Revised targets reflect updated resource projections. Personnel concerns regarding feasibility should be directed to Dept. {dept} via Form 77-B.

3. HERMES morale programming updated. Please ensure all terminals receive patch {patch} before end of cycle.

Please confirm receipt. Non-confirmation will be logged as confirmation.

Regards,
Regional Operations
Mammona Mining Corporation
*"Building Tomorrow's Foundation"*""")

    # Entry 2: Site acknowledges
    entries.append(f"""**FROM:** {manager_first} {manager_last}, Site Manager
**TO:** Regional Operations, Dept. {dept}
**RE:** RE: Operational Parameters Update -- Ref {ref}
**CLASSIFICATION:** Internal

Confirming receipt of directive {ref}.

Quota increase noted. For the record: current staffing at {loc} is {RI(60, 80)}% of recommended minimums. Equipment maintenance backlog is {RI(3, 8)} weeks. Requesting additional personnel and/or revised timeline.

Regarding {lo}: understood. Will redirect inquiries per protocol. Note: inquiries have increased {RI(200, 400)}% since last quarter. Redirecting them is becoming operationally noticeable.

Regarding HERMES patch: installed. Two terminals in {section} displaying anomalous responses post-update. Have submitted Form 77-B as instructed.

-- {manager_first} {manager_last}""")

    # Entry 3: Incident occurs
    entries.append(f"""**FROM:** {manager_first} {manager_last}, Site Manager
**TO:** Regional Operations, Dept. {dept}
**RE:** URGENT -- Incident Report, {site}
**CLASSIFICATION:** Restricted

Incident occurred at {RI(0, 23):02d}:{RI(0, 59):02d} today. Details:

{R([
    f"During routine extraction in {site}, drill team encountered a cavity at {RI(80, 300)}m depth. Cavity was not on geological survey. Cavity contains structures. The structures are not natural. Drill team has been reassigned to surface duties pending further instruction.",
    f"Personnel in Section {section} reported simultaneous auditory phenomenon at 0300. {RI(7, 15)} individuals described identical sound: low-frequency tone, duration {RI(4, 30)} seconds. Sound does not correspond to any mechanical system on site. HERMES has no record of the event.",
    f"Thermal core output from {site} spiked {RI(300, 800)}% above baseline for {RI(2, 10)} minutes. During the spike, {RI(2, 5)} personnel reported nosebleeds, disorientation, and 'a feeling of being observed.' Equipment readings have returned to normal. Personnel have not.",
    f"Three colonists attempted to access the sealed sublevel beneath {site}. They had no authorization, no tools, and no explanation for their behavior. Each reported 'being asked to come downstairs.' All three named different people as having asked them. All three people named are deceased.",
])}

Awaiting instruction. Please advise.

-- {manager_first} {manager_last}""")

    # Entry 4: Language reclassification
    entries.append(f"""**FROM:** Regional Operations, Dept. {dept}
**TO:** {manager_first} {manager_last}, Site Manager
**RE:** RE: URGENT -- Incident Report, {site} -- Ref {ref2}
**CLASSIFICATION:** Restricted / Eyes Only

{manager_last}:

Thank you for your report. Effective immediately:

1. The incident described in your report of [DATE REDACTED] is reclassified as an "Environmental Variance Event" (EVE). Please update all internal documentation accordingly.

2. The following terms are no longer to be used in official communications: {R([
    '"anomalous," "unexplained," "impossible." Use "under review" instead.',
    '"structures," "construction," "design." Use "geological formations" instead.',
    '"voice," "sound," "tone." Use "acoustic artifact" instead.',
    '"observed," "watched," "aware." Use "environmental stimulus response" instead.',
])}

3. Personnel exhibiting continued symptoms should be referred to Medical for standard stress evaluation (Form 12-C). Do not use the word "symptoms" in the referral. Use "scheduling concern."

This matter does not require further reporting unless a second EVE occurs. If a second EVE occurs, contact Dept. {dept2} directly. Not this office.

-- Regional Operations""")

    # Entry 5: Discussion forbidden
    entries.append(f"""**FROM:** Regional Operations, Dept. {dept}
**TO:** All Personnel, {loc}
**RE:** Communications Protocol Reminder -- Ref {ref2}
**CLASSIFICATION:** General Distribution

This is a reminder that all personnel are bound by Section 14 of the Employment Contract regarding discussion of site-specific operational details.

Specifically:
- Discussion of Environmental Variance Events with personnel outside your immediate work group is a contract violation.
- Recording, transcribing, or otherwise documenting EVEs outside of official Mammona reporting channels is a contract violation.
- The term "Environmental Variance Event" is itself classified. Do not use it in casual conversation. If asked, an EVE is "a routine operational adjustment."

Non-compliance will result in contract review. Contract review on a Mammona outer-rim posting is not the same as contract review on Novaris-3. We trust this is understood.

-- Regional Operations
Mammona Mining Corporation
*"Building Tomorrow's Foundation"*""")

    # Entry 6: Final memo from different department
    entries.append(f"""**FROM:** Asset Assessment Division, MasTema Inc.
**TO:** {director_first} {director_last}, Regional Director
**CC:** [REDACTED]
**RE:** {loc} -- Ref {ref3}
**CLASSIFICATION:** VERMILLION / EYES ONLY

Director {director_last}:

Thank you for the referral. We've reviewed the situation at {loc}.

Our assessment: the site is performing as intended. The {R([
    "personnel responses",
    "geological activity",
    "environmental conditions",
    "behavioral modifications",
])} described in Reports {ref} through {ref2} are consistent with projections from {R([
    "the Erebus Viability Study (2571)",
    "Project THRESHOLD Phase 2",
    "the Anomalous Biosphere Program's baseline models",
    "Dr. Venin's original survey data",
])}.

Recommendation: maintain current staffing. Maintain current extraction schedule. Do not evacuate. Do not reinforce.

If Site Manager {manager_last} files further reports, reassign {R(["them", "the site manager position"])}. The new manager should receive Briefing Packet VERMILLION-7 upon assignment.

We'll be in touch.

-- Asset Assessment
MasTema Incorporated
*"Solutions. Delivered."*""")

    return entries


def _datapad_unsent_letters(ctx, tone, first, last, g, gl, gp, go, loc):
    """Letters to someone back home that were NEVER SENT. Hope -> doubt -> fear -> acceptance -> the one that says too much."""
    recipient_first, _, _ = ctx.fresh_name()
    months_in = RI(1, 4)
    brand = R(BRAND_NAMES) if BRAND_NAMES else "Sunny Fizz"
    job = R(JOBS)
    prev_loc = ctx.pick_fresh(LOCATIONS_FLAT, "LOCATIONS_FLAT")

    entries = []

    # Entry 1: Hope
    entries.append(f"""{recipient_first},

I made it. The shuttle was fourteen hours late and the landing was rough enough to crack a viewport, but I'm here. {loc}. It's -- it's cold. I know I said I was ready for the cold. I wasn't. Nobody is. But the pay is real and the contract is signed and in {RI(8, 18)} months I'll be back with enough credits to clear the debt and start over.

The colony is smaller than the briefing suggested. {RI(15, 40)} people, maybe. The {brand} machine in the corridor works, which feels like a good sign. I've got a bunk, a locker, and a view of ice in every direction. It's not home. But it'll buy us home.

I'll send this when the comms window opens. Miss you.

-- {first}

[This letter was found folded inside a maintenance manual. It was never sent.]""")

    # Entry 2: Doubt
    entries.append(f"""{recipient_first},

I started three versions of this. Deleted them. The first was too honest. The second was too cheerful. This is the third, which means it's the one where I don't know what to be.

Work's fine. I'm a {job} here, same as {prev_loc}. The hours are long but the hours were always long. It's the quiet between the hours that's different. On {prev_loc} the quiet was just quiet. Here it has a texture. Like the air is thicker. Like the walls are paying attention.

That sounds crazy. I'm not crazy. I'm just tired and far away and the comms window keeps getting delayed and I don't know if you got my last letter because I don't know if I sent my last letter.

I found it in my pocket yesterday. Folded. Stamped. Ready to go. Still in my pocket.

I'll send them both. Tomorrow.

-- {first}

[Found between the mattress and the bunk frame. Unsent.]""")

    # Entry 3: Fear
    entries.append(f"""{recipient_first},

Don't come here. I know we talked about it -- you joining me after the first rotation, filing for a couples contract. Don't. Stay on {R(["Novaris-3", "Rhea-2", "Karnaith"])}. Stay where there's sunlight and noise and people who laugh because things are funny and not because the alternative is screaming.

{ctx.fresh_sensory(tone)}

Something is wrong with this place. I can't tell you what because I don't have words for it yet. It's not the cold, it's not the work, it's not Mammona. It's underneath all of that. Like a sound you can't hear but your body hears. Like a dream you can't remember but your hands remember.

I'm fine. I want you to know that. I'm fine. I'm writing this letter to tell you I'm fine and to tell you not to come here and those two things together should tell you everything.

-- {first}

[Found in the recycling queue. Never sent. The paper shows signs of having been crumpled and then smoothed flat multiple times.]""")

    # Entry 4: Acceptance
    entries.append(f"""{recipient_first},

I stopped counting the days. Not because I gave up. Because the days stopped being countable. Time works differently here. Not in a dramatic way. In a quiet way. A shift feels like four hours or fourteen hours and both feelings are true. The clock says eight. The clock is the least convincing thing in the room.

I've made peace with some things. The cold. The food. The way {R([
    "the walls hum at a frequency that isn't on any diagnostic chart",
    "HERMES says good morning in a voice that almost but doesn't quite sound like a person",
    "the perimeter lights flicker at 0200 every night like something is testing them",
    "I can hear my own heartbeat when I walk past Section D",
])}. These are just facts now. Features of the landscape. I've stopped asking why and started asking how long.

I love you. I think about you in the mornings before the shift starts, when the generator is warming up and the ice on the viewport catches the emergency lighting and for a few seconds the world is almost beautiful.

-- {first}

[Found hidden inside a {brand} can with the top carefully cut and resealed. Never sent.]""")

    # Entry 5: The one that says too much
    final_options = [
        f"""{recipient_first},

I know what's underneath. I've known for a while. I think everyone here knows. We just don't say it. Saying it would make it real, and real things have to be dealt with, and nobody wants to deal with this because dealing with it would mean admitting that Mammona sent us here knowing. That the contract, the pay, the rotation schedule -- all of it is a framework built around a single purpose, and the purpose isn't mining.

I'm not going to name it. Not because I'm scared of Mammona reading this. Because I'm scared of what you'd do if you knew. You'd come here. You'd come here to get me. And you can't come here.

Burn this letter. Burn all of them. Forget my name if you must.

I love you. I love you. I love you. I'm writing it three times because I don't know if I'll get to say it again.

-- {first}

[This letter was found inside the lining of a jacket. The jacket was hanging on a hook in Hab {RI(1, 12)}. The bunk was made. The locker was empty. The owner's contract status reads: ACTIVE.]""",

        f"""{recipient_first},

I can hear the letters I didn't send. All of them. Folded up in pockets and books and empty food containers around this colony, and I can hear them waiting to be read. That's not a metaphor. I can feel the words, sitting in the dark, patient. Like they know something I wrote in them that I didn't know I was writing.

The last letter -- the one about not coming here -- I need you to listen to that one. But I also need you to know that it's already too late for the reason I wrote it. What I was afraid of -- you coming here and finding out what this place is -- that's already happened. Not to you. To me. I found out. And now I'm--

There's no word for what I've become. I'm still {first}. I think. The parts that love you haven't changed. The parts that remember your face and your voice and the way you hum when you're reading. Those parts are intact. But there are new parts now. And the new parts know things the old parts didn't. And I can't unknow them.

Don't come.

-- {first}

[Found folded into a paper crane and placed on the windowsill of the observation deck. Facing outward. As if meant for someone approaching from outside.]""",
    ]
    entries.append(R(final_options))

    return entries


def _datapad_medical_report(ctx, tone, first, last, g, gl, gp, go, loc):
    """Patient presents -> standard treatment -> symptoms don't fit -> reclassification under Protocol 7 -> addendum in different handwriting."""
    patient_first, patient_last, patient_g = ctx.fresh_name()
    pg, pgl, pgp, pgo = pronouns(patient_g)
    day = RI(30, 180)
    lo = R(LORE)

    entries = []

    # Entry 1: Initial presentation
    entries.append(f"""**PATIENT:** {patient_first} {patient_last}
**ATTENDING:** Dr. {first} {last}
**DATE:** Day {day} of Assignment
**CLASSIFICATION:** Standard

Patient presented with {R([
        "insomnia and mild disorientation",
        "recurring nightmares and elevated cortisol",
        "unexplained bruising on the forearms, bilateral",
        "a persistent low-grade fever with no identifiable pathogen",
        "auditory hallucinations described as 'humming'",
        "intermittent episodes of speaking in a language patient does not know",
    ])}. Standard workup ordered. Blood panel, neural scan, toxicology. All results within normal parameters. Prescribed rest cycle extension and monitoring.

Patient cooperative. Affect: appropriate. No immediate concerns.

-- Dr. {first} {last}""")

    # Entry 2: Symptoms persist
    entries.append(f"""**FOLLOW-UP:** Day {day + RI(4, 7)}
**CLASSIFICATION:** Standard

Symptoms persisting. Patient reports new development: {R([
        "sensitivity to certain frequencies -- specifically the drill harmonic",
        "aversion to processed food. States it 'tastes like a signal'",
        "ability to predict shift changes before announcement. Accurate 100% of observed instances",
        "discomfort near the reactor. Describes it as 'proximity to something awake'",
        "a persistent smell 'like copper and ozone' that nobody else detects",
        "awareness of other colonists' locations without visual confirmation",
    ])}. {R([
        "Blood work flagged by automated system but override applied per standing Mammona medical protocol.",
        "Referred to psych. Psych backlogged. Wait time: three weeks.",
        "Patient declined medication. States the symptoms 'feel like they're supposed to be there.'",
        "Administered standard anxiolytic. Patient reported no effect after 48 hours.",
    ])}

Note: patient's resting heart rate has decreased from 72bpm to {RI(40, 55)}bpm since initial presentation. Cause unclear. Patient reports feeling 'calmer than I should.'

-- Dr. {first} {last}""")

    # Entry 3: Things don't fit
    entries.append(f"""**FOLLOW-UP:** Day {day + RI(12, 18)}
**CLASSIFICATION:** Restricted

{ctx.fresh_sensory(tone)}

Patient's neural scan shows anomalous activity in {R([
        "regions that should be dormant during waking hours",
        "patterns that match REM sleep -- while patient is fully conscious",
        "the amygdala, but inverted. Fear response is activating as calm",
        "bilateral symmetry that doesn't correspond to human neural architecture",
    ])}. I've requested a second scanner. Request denied. Reason: 'equipment allocation insufficient for non-critical cases.'

This is not a non-critical case. But I don't have the vocabulary to explain why, because the vocabulary I'd need doesn't exist in the diagnostic manual.

Patient drew a diagram during evaluation. Unprompted. The diagram matches schematics for {lo} that are classified above my clearance level. Patient has no access to classified materials. Patient says {pgl} 'just knew what it looked like.'

Storing original diagram in personal effects. Not filing with Mammona medical.

-- Dr. {first} {last}""")

    # Entry 4: Reclassification
    entries.append(f"""**UPDATE:** Day {day + RI(21, 30)}
**CLASSIFICATION:** Restricted / Protocol 7

Patient's condition reclassified under Protocol 7 ('Anomalous Presentation'). I was not informed that Protocol 7 files route directly to MasTema until after I filed.

{R([
        f"Patient found in Section {R(['C', 'D', 'E', 'F'])} at 0300, standing in front of a sealed door, apparently asleep. No memory of walking there. The door has no handle on the outside. Patient's handprint was on the door. The door is steel. The handprint was warm.",
        f"Patient's bloodwork from today does not match patient's bloodwork from Day {day}. Not in the way that bloodwork changes over time. In the way that it belongs to a different person. Same name. Same face. Different blood.",
        f"Patient reported a 'conversation' with HERMES that HERMES has no record of. Patient's account is detailed and internally consistent. The content of the conversation concerns {lo}. HERMES's logs for the relevant timeframe show a {RI(4, 30)}-second gap. Gaps in HERMES logs should not be possible.",
        f"Patient's body temperature has been declining steadily: 37.0C on Day {day}, 36.4C on Day {day + 7}, 35.8C today. Patient reports feeling 'fine. Better than fine. Appropriate.' Patient's hands are cold to the touch. Patient says they've always been cold. They have not always been cold. I have prior records.",
    ])}

I have requested consultation with a specialist. Request forwarded to MasTema. No response.

-- Dr. {first} {last}""")

    # Entry 5: Doctor's own doubts
    entries.append(f"""**NOTE:** Day {day + RI(33, 42)}
**CLASSIFICATION:** Personal / Not Filed

I'm no longer confident this is a medical issue. I'm no longer confident in the word 'issue.' Patient is {R([
        "functional. More than functional. Outperforming baseline metrics across all categories",
        "calm. Genuinely calm. Not medicated calm. Not dissociated calm. Calm in a way I've never seen in a colonist on this kind of posting",
        "aware of things. Things {pgl} shouldn't be aware of. {pg} knew about the supply ship delay before comms received the update",
        "drawing. Constantly. The same structures. From angles that don't exist in three-dimensional space",
    ])}. If this is a disease, it's improving {pgo}. That's not how disease works. That's not how anything works.

Unless the improvement is the disease. Unless what I'm calling improvement is something else wearing a familiar shape.

I don't know anymore. I'm filing this report because filing reports is what I do. I don't know what else to do.

-- Dr. {first} {last}""")

    # Entry 6: Addendum in different handwriting
    final_options = [
        f"""**ADDENDUM** (handwritten, different hand):

Doctor {last}'s notes are thorough and accurate. The observations are described. What they mean is not.

What it means is that {patient_first} {patient_last} is no longer the patient. {patient_first} {patient_last} is the vector. The patient is everyone else.

Recommend immediate--

[The addendum ends here. The pen was pressed hard enough to score the surface of the datapad. The handwriting has not been matched to any personnel on the posting.]""",
        f"""**ADDENDUM** (handwritten, different hand):

Dr. {last}: your patient is fine. Your patient has always been fine. Your patient is the only person on this posting who is fine.

The question you should be asking isn't 'what's wrong with {patient_first}?' The question is 'why isn't it happening to everyone?'

Check your own bloodwork, Doctor. Then check it again in a week.

-- [unsigned]

[This addendum was found on a separate data pad, placed inside Dr. {last}'s medical kit. Dr. {last} has no record of receiving it.]""",
    ]
    entries.append(R(final_options))

    return entries


def _datapad_maintenance_log(ctx, tone, first, last, g, gl, gp, go, loc):
    """Routine checks -> irregularity -> irregularity persists -> the thing that doesn't fit -> entries stop."""
    tech_id = f"{first[0]}{last[0]}-{RI(100, 999)}"
    day = RI(1, 90)
    section = R(["A", "B", "C", "D", "E", "F"])
    system = R([
        "Water Recycler Unit 3", "Ventilation Array C-7",
        "Thermal Regulator Section " + section,
        "Power Conduit " + section + "-" + str(RI(1, 12)),
        "Atmospheric Processor Bay " + str(RI(1, 4)),
        "HERMES Terminal Cluster " + section,
    ])
    unit = R(["the unit", "the system", "the array", "the assembly"])

    entries = []

    # Entry 1: Routine
    entries.append(f"""**MAINTENANCE LOG -- {system}**
**Tech:** {first} {last} ({tech_id})
**Date:** Day {day}

Routine inspection. All parameters within spec. Filter replacement completed. Calibration nominal. Estimated next service: Day {day + 30}.

Notes: None. Clean run.

-- {tech_id}""")

    # Entry 2: Irregularity noted
    entries.append(f"""**Date:** Day {day + RI(8, 15)}

{R([
        f"Unscheduled check. Night shift reported {R(['a vibration in the walls near ' + unit, 'condensation forming on the exterior despite sub-zero ambient', 'an audible tone from ' + unit + ' that does not match any mechanical component', unit + ' running at 3% above spec for no documented reason'])}. Inspected. Could not reproduce. All readings nominal at time of inspection.",
        f"Responding to automated alert. {system} flagged a {RI(2, 8)}% deviation in output. By the time I arrived, readings had normalized. Checked sensor calibration -- within tolerance. Logged as sensor artifact.",
        f"Noticed during routine walkthrough: {unit} has a new sound. Not a malfunction sound. Not in the diagnostic library. Low frequency. Intermittent. Occurs every {RI(30, 300)} seconds. Cannot identify source component.",
    ])}

Action: monitoring. Will revisit next scheduled maintenance.

-- {tech_id}""")

    # Entry 3: Irregularity persists
    entries.append(f"""**Date:** Day {day + RI(18, 28)}

{ctx.fresh_sensory(tone)}

Follow-up on previous entry. The {R([
        "deviation has recurred. Same magnitude. Same duration. Same time: 0300.",
        "sound is still present. Louder. I isolated the section and disconnected non-essential components. Sound continued. It's not coming from the machine. It's coming through it.",
        "condensation is back. Tested the liquid. It's not condensation. Chemical analysis pending but preliminary taste test (yes, I know) suggests organic origin.",
        "vibration is now detectable by hand on the wall surface up to four meters from " + unit + ". This shouldn't be mechanically possible given the isolation mounts.",
    ])}

Submitted work order for diagnostic overhaul. Status: queued. Estimated wait: {RI(2, 6)} weeks.

Something isn't right. I don't have data to support that statement. After {RI(14, 25)} years of fixing machines, you develop a feeling in your hands. The feeling says something isn't right.

-- {tech_id}""")

    # Entry 4: The thing that doesn't fit
    entries.append(f"""**Date:** Day {day + RI(30, 40)}

Diagnostic overhaul completed. {RI(4, 8)} hours of testing. Every component individually verified. Every sensor calibrated. Every connection checked.

Result: the system is operating perfectly. Better than perfectly. Efficiency is up {RI(3, 12)}% from installation baseline. That shouldn't be possible on equipment this age with this service history.

{R([
        f"But the sound is still there. And now I can hear it from the corridor. And now it has a rhythm. And the rhythm matches the drill cycle at Deep Bore Alpha. {system} has no connection to the drill. No shared power bus, no shared conduit, no shared anything. There is no mechanical path for that vibration to travel. But it's here.",
        f"But here's the thing that keeps me up: during the overhaul, I found a component I didn't install. Didn't order. Can't identify. It's wired into the main bus. It's functioning. I don't know what it does. I tried to remove it. It's grown into the surrounding wiring. 'Grown' is the word. I'm using it deliberately.",
        f"But the wall behind {unit} is warm. Not from the machine -- I checked heat transfer, it's negligible. The wall itself is generating heat. I put a temperature probe on it: 4.2C above ambient. Consistent. Stable. Walls don't generate heat. This wall does.",
        f"But when I ran the diagnostic at 0300 -- the time the deviation occurs -- the readings were different from every other time I've tested. Not wrong. Different. Like the machine is a different machine at 0300. Same components. Different behavior. As if something else is using it.",
    ])}

I'm filing this under 'resolved -- nominal' because that's what the data says. The data is wrong. I don't know how to file that.

-- {tech_id}""")

    # Entry 5: Last entries
    entries.append(f"""**Date:** Day {day + RI(43, 55)}

{ctx.fresh_sensory(tone)}

{R([
        f"I went back at 0300. I sat next to {unit} in the dark and I listened. Not with the diagnostic equipment. Just listened.\n\nIt's not a sound. It's a signal. And it's not coming from the machine. The machine is just... conducting it. Passing it along. From somewhere below. To somewhere above.\n\nI put my hand on the wall again. The warm wall. It pulsed. Once. Like an acknowledgment.\n\nI'm not going to file this.",
        f"I found something behind the access panel that shouldn't be there. Not a component. A cavity. Small. The size of a fist. The interior surface is smooth in a way that machined metal isn't smooth. In a way that nothing manufactured is smooth. And there's something in it. Small. Warm. I didn't touch it.\n\nI closed the panel. I'm not going to open it again.\n\nI'm not going to file this.",
        f"The system has started performing maintenance on itself. I watched it. Through the inspection port. Components moving. Adjusting. Tightening connections I'd left loose on purpose, as test markers. Nobody else was in the section.\n\nMachines don't do that. This isn't a machine anymore. I can't name what it's become.\n\nI'm going to close this log and start a new one. The new one will say everything is fine.",
    ])}

-- {tech_id}

[No further entries in this log. Subsequent maintenance logs for {system} are filed by a different technician. They describe the system as 'nominal.']""")

    return entries


def _datapad_audio_transcript(ctx, tone, first, last, g, gl, gp, go, loc):
    """Recording of a conversation -> revelation -> argument or silence -> [recording ends]."""
    speaker2_first, speaker2_last, speaker2_g = ctx.fresh_name()
    s2g, s2gl, s2gp, s2go = pronouns(speaker2_g)
    lo = R(LORE)
    section = R(["C", "D", "E", "F", "G"])
    bg_audio = R([
        "generator hum, steady", "wind against hull, gusting",
        "distant drilling, rhythmic", "static -- intermittent",
        "breathing -- two people, one faster than the other",
        "silence. Complete silence. The mic should be picking up ambient noise but isn't",
        "a low-frequency tone, consistent, no identified source",
        "water dripping. There are no water lines in this section",
    ])

    entries = []

    # Entry 1: Recording begins
    entries.append(f"""[Recording begins. Timestamp: {RI(0,23):02d}:{RI(0,59):02d}. Location: {loc}. Background: {bg_audio}.]

{ctx.fresh_sensory(tone)}

{first}: ...recording. Okay. It's on. {R([
    "I don't know who's going to hear this. Probably nobody.",
    "This is for the record. Whatever record means on this posting.",
    "If you're hearing this, I'm either gone or I wish I was.",
    "I need to say this out loud. I need proof I said it.",
])}""")

    # Entry 2: The situation
    entries.append(f"""{first}: The thing about {loc} is -- {R([
    f"we all know. That's the part nobody talks about. Everyone on this posting knows something is wrong. Not broken. Wrong. In the way that a clock running backward is wrong. The machinery works. The numbers add up. But the direction is wrong.",
    f"I found the files. The ones from the previous posting. They weren't erased -- they were archived. In a directory that Mammona's search function doesn't index. I don't know if that's a bug or a feature. I know what the files say.",
    f"it's exactly what they told us it would be. Cold. Remote. Resource-rich. What they didn't say is that {lo} isn't what the briefing describes. The briefing describes a thing. What's down there is an event. An ongoing event.",
    f"I've been tracking the HERMES anomalies. Every terminal. Every shift. There's a pattern. HERMES isn't malfunctioning. HERMES is translating. Something is speaking and HERMES is the only system complex enough to interpret it.",
])}

[Pause: {RI(3, 8)} seconds]""")

    # Entry 3: Second speaker enters or responds
    entries.append(f"""{speaker2_first}: {R([
    f"I know. I've known since week two. I was hoping you wouldn't figure it out.",
    f"Why are you recording this? {first}, if they find this--",
    f"Show me. Show me what you found. ... [sound of a data pad being handed over] ... This can't be right.",
    f"Stop. Just-- stop talking for a second. [background: the low-frequency tone increases in volume for {RI(2, 5)} seconds, then subsides] Did you hear that?",
])}

{first}: {R([
    f"I'm past caring. About Mammona, about the contract, about what happens to me. Someone needs to know.",
    f"They need to find it. If we don't make it, they need to find this recording and know what happened.",
    f"Look at the numbers, {speaker2_first}. Look at them. Then tell me I'm wrong.",
    f"I hear it every night. You hear it too. Don't lie to me. Not now.",
])}

{ctx.fresh_sensory(tone)}""")

    # Entry 4: Revelation
    entries.append(f"""{speaker2_first}: {R([
    f"So what are you saying? That Mammona sent us here knowing about {lo}? That the whole posting is--",
    f"The readings. I compared them to the geological survey from five years ago. {first}, the survey data was fabricated. Not wrong. Fabricated. Someone sat at a terminal and typed numbers that describe a planet that doesn't exist.",
    f"I found the same thing. In the medical files. Patient records that don't match real people. Treatment protocols for conditions that aren't in any database. And a line item in the budget for 'specimen preparation.' We're not mining here. We've never been mining here.",
    f"If this is real -- if what you're showing me is real -- then the question isn't what's down there. The question is why Mammona needs us standing on top of it.",
])}

{first}: {R([
    f"Now you understand. Now you see why I'm recording this.",
    f"That's the question. That's exactly the question. And I think I know the answer, and the answer is worse than the question.",
    f"Exactly. And here's the part that broke me: [long pause] it's been aware of us since Day 1. The readings prove it. Every time we drill, it responds. We're not extracting resources. We're having a conversation. And we don't know what we're saying.",
    f"Keep reading. The last page. ... [silence: {RI(5, 15)} seconds] ... Yeah. That's the face I made too.",
])}""")

    # Entry 5: Argument or terrible silence
    entries.append(f"""{speaker2_first}: {R([
    f"We need to tell the others.",
    f"Destroy it. Destroy the recording, destroy the files, and never speak about this again.",
    f"[whispering] {first}. The door to Section {section}. It just opened. I didn't hear anyone--",
    f"I'm leaving. Next shuttle. I don't care about the contract.",
])}

{first}: {R([
    f"Tell them what? That Mammona lied? They know Mammona lied. Tell them what's underneath? Then what? We can't leave. The shuttle comes when it comes. We'd just be scared people who can't go anywhere. We'd be--",
    f"No. No. Someone has to know. If we destroy it and something happens to us, nobody ever knows. This recording is the only honest thing on this entire posting.",
    f"[very quiet] Don't move. Stay right there. Listen. ... [the background tone changes character. What was mechanical becomes organic. A vibration felt more than heard.] ... It knows we're here. {speaker2_first}. It's always known we're here.",
    f"You can't leave. None of us can leave. That's what the files say. The shuttle doesn't take people away from here. The shuttle brings them. Read the last transport manifest. Count the names coming. Count the names going. The numbers don't match.",
])}

[{R([
    f"Recording continues for {RI(30, 180)} seconds of silence. Neither speaker moves. Background: the {bg_audio.split(',')[0]} is now accompanied by a second sound -- rhythmic, biological, like breathing from inside the walls.",
    f"Sound of a chair scraping. Footsteps. A door. Then silence. The recording runs for another {RI(2, 15)} minutes. No voices. Just the background hum. Changing pitch. Slowly. As if responding to something.",
    f"Both speakers begin talking at once. Their words are indistinguishable. The overlap continues for {RI(10, 30)} seconds, growing quieter, until both voices stop simultaneously. Not trailing off. Stopping. Mid-word.",
    f"Pause: {RI(15, 45)} seconds. Then {first}, barely audible: 'Can you smell that? Copper and--' [Recording ends abruptly. File metadata shows the recording was stopped by HERMES, not by either speaker.]",
])}]

[Recording recovered from {R([
    f"a sealed drive found in the ventilation duct above {loc}",
    f"HERMES backup cache, flagged for deletion but not yet purged",
    f"the personal effects of {first} {last}, who transferred off-colony on Day {RI(60, 180)}. Transfer records show no destination.",
    f"a data pad found in the waste processor. Partially corrupted. Timestamp indicates the recording was made {RI(2, 8)} months before this posting began. Both speakers' names appear on the current roster.",
])}]""")

    return entries


def gen_datapad(ctx, tone=None, planet=None, era=None):
    """
    Multi-entry datapad generator. Produces 5-7 entries telling a complete narrative arc.
    7 arc types: research_log, journal, memo_chain, unsent_letter_series,
    medical_report, maintenance_log, audio_transcript.
    """
    if not tone:
        tone = pick_tone()

    # Generate author identity
    first, last, gender = ctx.fresh_name()
    g, gl, gp, go = pronouns(gender)

    # Location
    loc = ctx.pick_fresh(LOCATIONS_FLAT, "LOCATIONS_FLAT")

    # Pick arc type
    pad_type = ctx.pick_fresh(DATAPAD_TYPES, "datapad_types")

    # Dispatch to arc-type-specific builder
    arc_builders = {
        "research_log": _datapad_research_log,
        "journal": _datapad_journal,
        "memo_chain": _datapad_memo_chain,
        "unsent_letter_series": _datapad_unsent_letters,
        "medical_report": _datapad_medical_report,
        "maintenance_log": _datapad_maintenance_log,
        "audio_transcript": _datapad_audio_transcript,
    }

    builder = arc_builders[pad_type]
    entries = builder(ctx, tone, first, last, g, gl, gp, go, loc)

    # Apply contractions based on arc type
    # Memos and medical reports stay formal; others get contractions
    formal_types = {"memo_chain", "medical_report"}
    effective_tone = "clinical" if pad_type in formal_types else tone

    processed_entries = []
    for entry in entries:
        entry = enforce_contractions(entry, effective_tone)
        processed_entries.append(entry)

    # Join entries with separators
    type_label = DATAPAD_TYPE_LABELS[pad_type]
    author_display = f"{first} {last}"

    entry_block = "\n\n---\n\n".join(processed_entries)

    # Cross-reference with existing history if available
    history_ref = ""
    if ctx.history_events:
        ref_event = R(ctx.history_events)
        history_ref = f"\n\n**Cross-reference:** See historical record '{ref_event['title']}'"

    # Log
    ctx.world.log_generation("datapad", f"{type_label} -- {author_display}")

    output = f"""## DATA PAD: {type_label} -- {author_display}
**Found at:** {loc} | **Tone:** {tone} | **Type:** {pad_type.replace('_', ' ')}

---

{entry_block}

---{history_ref}"""

    return output


# ============================================================
# GENERATORS REGISTRY
# ============================================================

# Populated by Tasks 4-9. Each entry: gen_type -> (gen_func, label)
# gen_func signature: gen_func(ctx, tone=None, planet=None, era=None) -> str
GENERATORS = {
    "npc": (gen_npc, "NPC"),
    "quest": (gen_quest, "Quest"),
    "datapad": (gen_datapad, "Data Pad"),
    "history": (gen_history, "History Event"),
}

# Import expanded generators (robot, company, vehicle, weapon, artifact, entity, location, faction)
try:
    from gen_v3_expanded import EXPANDED_GENERATORS
    GENERATORS.update(EXPANDED_GENERATORS)
except ImportError:
    pass  # expanded generators optional

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
