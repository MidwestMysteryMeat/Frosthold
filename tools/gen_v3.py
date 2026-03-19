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
    PASSIONS, FEARS, LOVES, FAMILY, GENETICS,
    HEALTH_CONDITIONS, MENTAL_HEALTH, GENETIC_DISORDERS, BODY_TYPES,
    CHARACTER_WEIGHTS, CHARACTER_WEIGHT_KEYS,
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
# DIVERGENCE ENGINE — proposal, commit, revert, constraint propagation
# ============================================================

# Locked subjects that must never be affected by divergences
_LOCKED_SUBJECTS = set()
for _locked in LOCKED_LORE:
    _LOCKED_SUBJECTS.add(_locked.lower())
# Add specific keys that must never be touched
_LOCKED_SUBJECTS.update({"foras", "shaft 12", "shaft_12", "the maw", "baldrungen", "fortuna"})

# Faction keys safe for divergence (exclude locked lore references)
_DIVERGENCE_SAFE_FACTIONS = [
    k for k in FACTIONS
    if not any(locked in k.lower() for locked in _LOCKED_SUBJECTS)
    and not any(locked in FACTIONS[k].get("name", "").lower() for locked in _LOCKED_SUBJECTS)
]

# Location keys safe for divergence
_DIVERGENCE_SAFE_LOCATIONS = [
    k for k, v in LOCATIONS.items()
    if isinstance(v, dict)
    and not any(locked in v.get("name", "").lower() for locked in _LOCKED_SUBJECTS)
    and not any(locked in k.lower() for locked in _LOCKED_SUBJECTS)
]


def _touches_locked_lore(*texts):
    """Return True if any text references locked lore subjects."""
    for text in texts:
        if not text:
            continue
        lower = text.lower()
        for locked in _LOCKED_SUBJECTS:
            if locked in lower:
                return True
    return False


def _propose_faction_migration(ws):
    """Propose a faction relocating to or withdrawing from a planet."""
    if len(_DIVERGENCE_SAFE_FACTIONS) < 1:
        return None
    fk = R(_DIVERGENCE_SAFE_FACTIONS)
    faction = FACTIONS[fk]
    fname = faction["name"]
    territories = faction.get("territory", [])
    if not territories:
        return None

    if random.random() < 0.5 and len(territories) > 1:
        # Withdrawal
        planet = R(territories)
        if _touches_locked_lore(planet):
            return None
        return {
            "type": "faction_migration",
            "subject": fk,
            "description": f"{fname} withdraws operations from {planet}",
            "cause": R([
                f"Resource exhaustion on {planet} forced a pullback",
                f"Escalating hostilities on {planet} made operations untenable",
                f"Corporate restructuring eliminated the {planet} division",
                f"A catastrophic incident on {planet} destroyed their foothold",
                f"Internal power struggle led to abandonment of {planet} assets",
            ]),
            "timestamp": f"day_{RI(1, 180)}",
            "consequences": [
                f"{fname} no longer operates on {planet}",
                f"Power vacuum on {planet} in {fname}'s former territory",
            ],
            "invalidates": [f"{fk}_at_{planet}"],
            "enables": [f"power_vacuum_{planet}", f"{fk}_displaced"],
        }
    else:
        # Expansion
        all_planets = [p for p in PLANETS if p not in territories and not _touches_locked_lore(p)]
        if not all_planets:
            return None
        new_planet = R(all_planets)
        return {
            "type": "faction_migration",
            "subject": fk,
            "description": f"{fname} expands operations to {new_planet}",
            "cause": R([
                f"New resource deposits discovered on {new_planet}",
                f"Strategic opportunity after a rival's collapse on {new_planet}",
                f"Refugee members established a foothold on {new_planet}",
                f"A covert deal granted {fname} access to {new_planet}",
            ]),
            "timestamp": f"day_{RI(1, 180)}",
            "consequences": [
                f"{fname} now has a presence on {new_planet}",
                f"Existing factions on {new_planet} must respond to {fname}'s arrival",
            ],
            "invalidates": [],
            "enables": [f"{fk}_at_{new_planet}", f"{fk}_expanding"],
        }


def _propose_faction_conflict(ws):
    """Propose an armed conflict or trade war between two factions."""
    if len(_DIVERGENCE_SAFE_FACTIONS) < 2:
        return None
    fk_a, fk_b = random.sample(_DIVERGENCE_SAFE_FACTIONS, 2)
    fa, fb = FACTIONS[fk_a], FACTIONS[fk_b]
    fname_a, fname_b = fa["name"], fb["name"]

    # Find a shared planet for the conflict
    shared = [p for p in fa.get("territory", []) if p in fb.get("territory", [])
              and not _touches_locked_lore(p)]

    conflict_type = R(["armed skirmish", "trade war", "sabotage campaign",
                        "blockade", "assassination attempt", "territory dispute"])

    planet_clause = f" on {R(shared)}" if shared else " across contested shipping lanes"

    return {
        "type": "faction_conflict",
        "subject": f"{fk_a}_vs_{fk_b}",
        "description": f"{conflict_type.title()} erupts between {fname_a} and {fname_b}{planet_clause}",
        "cause": R([
            f"Long-simmering rivalry finally boiled over",
            f"A border incident escalated beyond recovery",
            f"Intelligence leak exposed covert operations",
            f"Resource scarcity forced both sides into the same territory",
            f"A betrayal within shared supply chains",
        ]),
        "timestamp": f"day_{RI(1, 180)}",
        "consequences": [
            f"{fname_a} and {fname_b} are now openly hostile",
            f"Trade routes between their territories are disrupted",
            f"Neutral parties forced to pick sides",
        ],
        "invalidates": [f"{fk_a}_allied_{fk_b}", f"{fk_b}_allied_{fk_a}"],
        "enables": [f"{fk_a}_vs_{fk_b}_conflict", f"war_profiteering_{fk_a}_{fk_b}"],
    }


def _propose_secret_revealed(ws):
    """Propose a major secret becoming public knowledge."""
    # Filter out secrets that reference locked lore
    safe_secrets = [s for s in SECRETS if not _touches_locked_lore(s)]
    if not safe_secrets:
        return None

    secret = R(safe_secrets)
    revealer_type = R(["a whistleblower", "a leaked datapad", "a dying confession",
                        "intercepted comms", "a Veilbreaker broadcast", "an anonymous tip",
                        "a disgruntled employee", "a compromised AI"])

    return {
        "type": "secret_revealed",
        "subject": "public",
        "description": f"It becomes public knowledge that {secret}",
        "cause": f"Revealed by {revealer_type}",
        "timestamp": f"day_{RI(1, 180)}",
        "consequences": [
            "Trust in the implicated parties collapses",
            "Demand for answers from colony leadership",
            "Related cover-ups begin to fall apart",
        ],
        "invalidates": [f"secret_hidden_{hash(secret) % 10000:04d}"],
        "enables": ["public_unrest", "investigation_launched"],
    }


def _propose_npc_death(ws):
    """Propose the death of an NPC currently in world state."""
    living_npcs = [
        (npc_id, npc) for npc_id, npc in ws.data["npc_states"].items()
        if isinstance(npc, dict) and npc.get("alive", True)
        and not _touches_locked_lore(npc.get("name", ""), npc_id)
    ]
    if not living_npcs:
        # No tracked NPCs; propose a generic named death
        first, last, gender = name()
        npc_name = f"{first} {last}"
        npc_id = f"npc_{first.lower()}_{last.lower()}"
        if _touches_locked_lore(npc_name, npc_id):
            return None
        cause = R([
            "a mining collapse in the deep bore",
            "exposure during a perimeter patrol",
            "a contamination event in the lower levels",
            "an ambush by hostile fauna",
            "a reactor coolant failure",
            "an airlock malfunction during EVA",
            "a confrontation that escalated beyond control",
            "a medical emergency with no supplies available",
        ])
        return {
            "type": "npc_death",
            "subject": npc_id,
            "description": f"{npc_name} is killed by {cause}",
            "cause": cause,
            "timestamp": f"day_{RI(1, 180)}",
            "consequences": [
                f"{npc_name}'s responsibilities must be reassigned",
                f"Morale impact on anyone who knew {first}",
            ],
            "invalidates": [f"{npc_id}_alive"],
            "enables": [f"{npc_id}_dead", f"vacancy_{npc_id}"],
        }

    npc_id, npc = R(living_npcs)
    npc_name = npc.get("name", npc_id)
    first = npc_name.split()[0] if " " in npc_name else npc_name
    cause = R([
        "a mining collapse in the deep bore",
        "exposure during a perimeter patrol",
        "a contamination event in the lower levels",
        "an ambush by hostile fauna",
        "a reactor coolant failure",
        "an airlock malfunction during EVA",
        "a confrontation that escalated beyond control",
        "a medical emergency with no supplies available",
    ])

    return {
        "type": "npc_death",
        "subject": npc_id,
        "description": f"{npc_name} is killed by {cause}",
        "cause": cause,
        "timestamp": f"day_{RI(1, 180)}",
        "consequences": [
            f"{npc_name}'s responsibilities must be reassigned",
            f"Morale impact on anyone who knew {first}",
            f"Relationships involving {first} are severed or transformed",
        ],
        "invalidates": [f"{npc_id}_alive"],
        "enables": [f"{npc_id}_dead", f"vacancy_{npc_id}"],
    }


def _propose_npc_betrayal(ws):
    """Propose an NPC betraying their faction or allies."""
    living_npcs = [
        (npc_id, npc) for npc_id, npc in ws.data["npc_states"].items()
        if isinstance(npc, dict) and npc.get("alive", True)
        and npc.get("faction")
        and not _touches_locked_lore(npc.get("name", ""), npc_id, npc.get("faction", ""))
    ]
    if not living_npcs:
        # Generate a betrayal with a new name
        first, last, gender = name()
        npc_name = f"{first} {last}"
        if _touches_locked_lore(npc_name):
            return None
        fk = R(_DIVERGENCE_SAFE_FACTIONS)
        fname = FACTIONS[fk]["name"]
        rival_keys = [r for r in FACTIONS[fk].get("rivals", [])
                      if r in FACTIONS and r in _DIVERGENCE_SAFE_FACTIONS]
        if rival_keys:
            target_key = R(rival_keys)
            target_name = FACTIONS[target_key]["name"]
        else:
            target_key = R([k for k in _DIVERGENCE_SAFE_FACTIONS if k != fk])
            target_name = FACTIONS[target_key]["name"]

        motivation = R([
            "ideological disillusionment",
            "a better offer from the other side",
            "blackmail material held by the enemy",
            "revenge for a personal loss",
            "survival -- they had no other choice",
        ])
        return {
            "type": "betrayal",
            "subject": f"npc_{first.lower()}_{last.lower()}",
            "description": f"{npc_name} of {fname} defects to {target_name}",
            "cause": f"Motivated by {motivation}",
            "timestamp": f"day_{RI(1, 180)}",
            "consequences": [
                f"{fname} loses internal intelligence",
                f"{target_name} gains an insider with knowledge of {fname}'s operations",
                f"Trust within {fname} erodes",
            ],
            "invalidates": [f"npc_{first.lower()}_{last.lower()}_loyal_{fk}"],
            "enables": [f"npc_{first.lower()}_{last.lower()}_allied_{target_key}",
                        f"{fk}_security_breach"],
        }

    npc_id, npc = R(living_npcs)
    npc_name = npc.get("name", npc_id)
    fk = npc.get("faction", "")
    fname = FACTIONS.get(fk, {}).get("name", fk)
    rival_keys = [r for r in FACTIONS.get(fk, {}).get("rivals", [])
                  if r in FACTIONS and r in _DIVERGENCE_SAFE_FACTIONS]
    if rival_keys:
        target_key = R(rival_keys)
    else:
        candidates = [k for k in _DIVERGENCE_SAFE_FACTIONS if k != fk]
        target_key = R(candidates) if candidates else fk
    target_name = FACTIONS.get(target_key, {}).get("name", target_key)

    motivation = R([
        "ideological disillusionment",
        "a better offer from the other side",
        "blackmail material held by the enemy",
        "revenge for a personal loss",
        "survival -- they had no other choice",
    ])
    return {
        "type": "betrayal",
        "subject": npc_id,
        "description": f"{npc_name} of {fname} defects to {target_name}",
        "cause": f"Motivated by {motivation}",
        "timestamp": f"day_{RI(1, 180)}",
        "consequences": [
            f"{fname} loses internal intelligence",
            f"{target_name} gains an insider with knowledge of {fname}'s operations",
            f"Trust within {fname} erodes",
        ],
        "invalidates": [f"{npc_id}_loyal_{fk}"],
        "enables": [f"{npc_id}_allied_{target_key}", f"{fk}_security_breach"],
    }


def _propose_territory_change(ws):
    """Propose a location changing hands between factions."""
    if not _DIVERGENCE_SAFE_LOCATIONS:
        return None
    loc_key = R(_DIVERGENCE_SAFE_LOCATIONS)
    loc = LOCATIONS[loc_key]
    loc_name = loc.get("name", loc_key)
    planet = loc.get("planet", "unknown")

    connected = loc.get("connected_factions", [])
    safe_connected = [f for f in connected if f in _DIVERGENCE_SAFE_FACTIONS]

    # Pick old and new controller
    if safe_connected:
        old_controller_key = R(safe_connected)
    else:
        old_controller_key = R(_DIVERGENCE_SAFE_FACTIONS)
    old_name = FACTIONS.get(old_controller_key, {}).get("name", old_controller_key)

    candidates = [k for k in _DIVERGENCE_SAFE_FACTIONS if k != old_controller_key
                  and planet in FACTIONS[k].get("territory", [])]
    if not candidates:
        candidates = [k for k in _DIVERGENCE_SAFE_FACTIONS if k != old_controller_key]
    if not candidates:
        return None
    new_controller_key = R(candidates)
    new_name = FACTIONS.get(new_controller_key, {}).get("name", new_controller_key)

    method = R([
        "a coordinated assault",
        "a prolonged siege",
        "an internal coup",
        "sabotage and infiltration",
        "economic pressure and buyout",
        "abandonment followed by occupation",
    ])

    return {
        "type": "territory_change",
        "subject": loc_key,
        "description": f"{loc_name} on {planet} falls from {old_name} to {new_name} via {method}",
        "cause": f"{new_name} seized control through {method}",
        "timestamp": f"day_{RI(1, 180)}",
        "consequences": [
            f"{old_name} loses control of {loc_name}",
            f"{new_name} now controls {loc_name} and its resources",
            f"Personnel at {loc_name} must swear new allegiance or flee",
        ],
        "invalidates": [f"{old_controller_key}_controls_{loc_key}"],
        "enables": [f"{new_controller_key}_controls_{loc_key}",
                    f"{loc_key}_contested"],
    }


def _propose_alliance_formed(ws):
    """Propose two factions forming a temporary or permanent alliance."""
    if len(_DIVERGENCE_SAFE_FACTIONS) < 2:
        return None

    fk_a, fk_b = random.sample(_DIVERGENCE_SAFE_FACTIONS, 2)
    fa, fb = FACTIONS[fk_a], FACTIONS[fk_b]
    fname_a, fname_b = fa["name"], fb["name"]

    # Alliances between rivals are more interesting
    is_rivals = fk_b in fa.get("rivals", []) or fk_a in fb.get("rivals", [])

    if is_rivals:
        reason = R([
            "a mutual existential threat forced cooperation",
            "a shared enemy made old grudges irrelevant",
            "a charismatic intermediary brokered an impossible peace",
            "economic collapse left no alternative",
        ])
    else:
        reason = R([
            "aligned strategic interests in the outer rim",
            "a trade agreement that benefits both sides",
            "a shared intelligence network against a common rival",
            "mutual defense pact after recent attacks",
            "a resource-sharing treaty to survive the season",
        ])

    alliance_type = R(["military pact", "trade alliance", "intelligence-sharing agreement",
                        "non-aggression treaty", "mutual defense compact"])

    return {
        "type": "alliance_formed",
        "subject": f"{fk_a}_and_{fk_b}",
        "description": f"{fname_a} and {fname_b} form a {alliance_type}",
        "cause": reason,
        "timestamp": f"day_{RI(1, 180)}",
        "consequences": [
            f"{fname_a} and {fname_b} now cooperate openly",
            f"Rivals of both factions face a stronger combined front",
        ] + ([f"Former rivalry between {fname_a} and {fname_b} is suspended"] if is_rivals else []),
        "invalidates": ([f"{fk_a}_vs_{fk_b}_conflict", f"{fk_b}_vs_{fk_a}_conflict"] if is_rivals else []),
        "enables": [f"{fk_a}_allied_{fk_b}", f"{fk_b}_allied_{fk_a}"],
    }


def _propose_resource_crisis(ws):
    """Propose a resource shortage or environmental crisis on a planet."""
    safe_planets = [p for p in PLANETS if not _touches_locked_lore(p)]
    if not safe_planets:
        return None

    planet = R(safe_planets)
    crisis = R([
        ("thermal core depletion", "Primary thermal core veins on {planet} are exhausted",
         ["energy rationing across {planet}", "mining operations shift to secondary deposits",
          "faction conflicts over remaining reserves intensify"]),
        ("supply line collapse", "Major supply route to {planet} is severed",
         ["food and medical shortages on {planet}", "black market prices skyrocket",
          "desperate factions resort to raiding"]),
        ("atmospheric contamination", "Toxic bloom contaminates {planet}'s habitable zones",
         ["evacuation of exposed sectors", "medical infrastructure overwhelmed",
          "quarantine zones established"]),
        ("seismic destabilization", "Geological instability threatens infrastructure on {planet}",
         ["structural collapses in mining operations", "surface settlements relocate",
          "underground operations suspended"]),
    ])

    crisis_type, desc_template, consequences_templates = crisis
    description = desc_template.format(planet=planet)
    consequences = [c.format(planet=planet) for c in consequences_templates]

    return {
        "type": "resource_crisis",
        "subject": planet,
        "description": description,
        "cause": R([
            "Years of unchecked extraction",
            "A cascading infrastructure failure",
            "Deliberate sabotage by an unknown party",
            "Natural geological shift",
            "Corporate negligence and deferred maintenance",
        ]),
        "timestamp": f"day_{RI(1, 180)}",
        "consequences": consequences,
        "invalidates": [f"{planet}_stable_supply"],
        "enables": [f"{planet}_crisis_{crisis_type.replace(' ', '_')}",
                    f"{planet}_emergency"],
    }


def propose_divergences(ws):
    """Propose 1-3 divergence events based on current world state."""
    proposals = []

    div_types = [
        _propose_faction_migration,
        _propose_faction_conflict,
        _propose_secret_revealed,
        _propose_npc_death,
        _propose_npc_betrayal,
        _propose_territory_change,
        _propose_alliance_formed,
        _propose_resource_crisis,
    ]

    n = RI(1, 3)
    for func in random.sample(div_types, min(n, len(div_types))):
        proposal = func(ws)
        if proposal:
            # Assign sequential ID
            proposal["id"] = f"div_{len(ws.data['divergences']) + len(proposals) + 1:03d}"
            proposals.append(proposal)

    return proposals


def commit_divergence(ws, div_id):
    """Commit a proposed divergence to world state."""
    # Check if divergence already committed
    if any(d.get("id") == div_id for d in ws.data["divergences"]):
        print(f"Divergence {div_id} already committed.")
        return

    # Find it in the pending proposals
    pending_path = Path(__file__).parent / "pending_divergences.json"
    if not pending_path.exists():
        print("No pending divergences. Run --diverge first.")
        return

    with open(pending_path, "r", encoding="utf-8") as f:
        pending = json.load(f)

    div = next((d for d in pending if d.get("id") == div_id), None)
    if not div:
        print(f"Divergence {div_id} not found in pending proposals.")
        return

    # Check it doesn't break earlier divergences
    for existing in ws.data["divergences"]:
        if any(tag in div.get("invalidates", []) for tag in existing.get("enables", [])):
            print(f"  WARNING: {div_id} would invalidate tags enabled by {existing.get('id', '?')}. Committing anyway.")

    # Apply NPC lifecycle effects for npc_death divergences
    if div.get("type") == "npc_death":
        npc_id = div.get("subject", "")
        npc = ws.get_npc(npc_id)
        if npc:
            update_npc_state(ws, npc_id, {"alive": False, "cause_of_death": div.get("cause", "unknown")})

    # Apply NPC lifecycle effects for betrayal divergences
    if div.get("type") == "betrayal":
        npc_id = div.get("subject", "")
        npc = ws.get_npc(npc_id)
        if npc:
            # Extract target faction from the enables tags
            new_faction = None
            for tag in div.get("enables", []):
                if tag.startswith(f"{npc_id}_allied_"):
                    new_faction = tag[len(f"{npc_id}_allied_"):]
                    break
            changes = {"arc_stage": "betrayed"}
            if new_faction:
                changes["faction"] = new_faction
            update_npc_state(ws, npc_id, changes)

    div["committed_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    ws.data["divergences"].append(div)
    ws.save()
    print(f"Committed divergence {div_id}: {div['description']}")


def revert_divergence(ws, div_id):
    """Remove a divergence from world state."""
    before = len(ws.data["divergences"])
    ws.data["divergences"] = [d for d in ws.data["divergences"] if d.get("id") != div_id]
    if len(ws.data["divergences"]) < before:
        ws.save()
        print(f"Reverted divergence {div_id}.")
    else:
        print(f"Divergence {div_id} not found.")


def update_npc_state(ws, npc_id, changes):
    """Update NPC state and propagate through relationship web."""
    npc = ws.get_npc(npc_id)
    if not npc:
        return

    for key, val in changes.items():
        npc[key] = val

    # Death propagation: update arc stages of related NPCs
    if changes.get("alive") is False:
        for rel_id, rel in npc.get("relationships", {}).items():
            related = ws.get_npc(rel_id)
            if related and related.get("alive", True):
                rel_type = rel.get("type", "")
                if rel_type in ("partner", "spouse", "mentor", "parent", "child"):
                    # Close relationships trigger grief
                    new_stage = "broken"
                    if "broken" in ARC_PROGRESSIONS:
                        new_stage = "broken"
                    related["arc_stage"] = new_stage
                elif rel_type in ("rival", "nemesis"):
                    # Rival's death can bring resolution
                    related["arc_stage"] = "rebuilt"
                elif rel_type in ("debtor",):
                    # Debt cleared by death
                    related["arc_stage"] = "stable"
                ws.set_npc(rel_id, related)

    # Arc progression validation
    if "arc_stage" in changes:
        new_stage = changes["arc_stage"]
        old_stage = npc.get("_prev_arc_stage", npc.get("arc_stage"))
        if old_stage and old_stage in ARC_PROGRESSIONS:
            valid_next = ARC_PROGRESSIONS[old_stage]
            if new_stage not in valid_next and valid_next:
                # Force to nearest valid progression
                npc["arc_stage"] = new_stage  # Allow override but log it
                npc["_arc_forced"] = True

    ws.set_npc(npc_id, npc)
    ws.save()


def check_faction_at_location(ws, faction_key, location):
    """Check if a faction is valid at a location given divergences."""
    return not ws.is_invalidated(f"{faction_key}_at_{location}")


def check_faction_controls(ws, faction_key, location_key):
    """Check if a faction still controls a location given divergences."""
    return not ws.is_invalidated(f"{faction_key}_controls_{location_key}")


def check_npc_alive(ws, npc_id):
    """Check if an NPC is still alive given divergences."""
    return not ws.is_invalidated(f"{npc_id}_alive")


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
        self.nicknames_used = set()
        self.robot_dialogue_used = set()
        self.robot_quest_hooks_used = set()
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


def gender_replace(text, gender):
    """Replace generic they/their in pool text with NPC's actual pronouns.

    Physical details and habits use 'they/their' as a generic placeholder
    for the NPC.  When the NPC has a known gender, swap to the correct
    pronouns -- but ONLY for subject/possessive uses that clearly refer to
    the NPC, not for object-of-verb uses like "Dismantles them" where
    'them' refers to things, not the person.

    Safe to replace:
      - "they're"  (subject contraction -- always the NPC)
      - "their X"  (possessive -- the NPC's body part / possession)
      - "they " at start of sentence / after ". " (subject position)
    NOT safe to replace:
      - "them" after verbs like Dismantles/shutting/Smooths/Folds/Burns
        (refers to objects, not the NPC)
    """
    import re
    if gender not in ("M", "F"):
        return text

    he_she = "he" if gender == "M" else "she"
    He_She = "He" if gender == "M" else "She"
    his_her = "his" if gender == "M" else "her"
    His_Her = "His" if gender == "M" else "Her"
    him_her = "him" if gender == "M" else "her"
    hes_shes = "he's" if gender == "M" else "she's"
    Hes_Shes = "He's" if gender == "M" else "She's"

    # "they're" / "They're" -- always the NPC as subject
    text = text.replace("they're", hes_shes).replace("They're", Hes_Shes)

    # "their" as possessive -- always the NPC's possession/body part
    text = text.replace("their ", his_her + " ").replace("Their ", His_Her + " ")

    # "they" as subject: at start of string, or after ". " or "-- " or "; "
    text = re.sub(r'(?:^|(?<=\. ))They ', He_She + ' ', text)
    text = re.sub(r'(?:^|(?<=\. ))they ', he_she + ' ', text)
    text = re.sub(r'(?<=-- )They ', He_She + ' ', text)
    text = re.sub(r'(?<=-- )they ', he_she + ' ', text)
    text = re.sub(r'(?<=; )They ', He_She + ' ', text)
    text = re.sub(r'(?<=; )they ', he_she + ' ', text)

    # "keeps them warm" -- "them" = NPC
    text = text.replace("keeps them ", "keeps " + him_her + " ")

    # Do NOT replace "them" in other positions (Dismantles them, Smooths them, etc.)
    return text


def fix_nb_verbs(text, gender):
    """Fix verb conjugation for non-binary They/them pronouns.

    Templates use He/She/They as subject with singular verb forms.
    When the subject is They, the verb needs plural conjugation.
    """
    if gender != "NB":
        return text
    fixes = [
        ("They taps", "They tap"), ("they taps", "they tap"),
        ("They hasn't", "They haven't"), ("they hasn't", "they haven't"),
        ("They doesn't", "They don't"), ("they doesn't", "they don't"),
        ("They wasn't", "They weren't"), ("they wasn't", "they weren't"),
        ("They isn't", "They aren't"), ("they isn't", "they aren't"),
        ("They has ", "They have "), ("they has ", "they have "),
        ("They was ", "They were "), ("they was ", "they were "),
        ("They does ", "They do "), ("they does ", "they do "),
        ("They goes", "They go"), ("they goes", "they go"),
        ("They carries", "They carry"), ("they carries", "they carry"),
        ("They drinks", "They drink"), ("they drinks", "they drink"),
        ("They writes", "They write"), ("they writes", "they write"),
        ("They keeps", "They keep"), ("they keeps", "they keep"),
        ("They checks", "They check"), ("they checks", "they check"),
        ("They sleeps", "They sleep"), ("they sleeps", "they sleep"),
        ("They flinches", "They flinch"), ("they flinches", "they flinch"),
        ("They hums", "They hum"), ("they hums", "they hum"),
        ("They works", "They work"), ("they works", "they work"),
        ("They says", "They say"), ("they says", "they say"),
        ("They knows", "They know"), ("they knows", "they know"),
        ("They makes", "They make"), ("they makes", "they make"),
        ("They takes", "They take"), ("they takes", "they take"),
        ("They comes", "They come"), ("they comes", "they come"),
        ("They looks", "They look"), ("they looks", "they look"),
        ("They seems", "They seem"), ("they seems", "they seem"),
        ("They feels", "They feel"), ("they feels", "they feel"),
        ("They stops", "They stop"), ("they stops", "they stop"),
        ("They starts", "They start"), ("they starts", "they start"),
        ("They gets", "They get"), ("they gets", "they get"),
        ("They thinks", "They think"), ("they thinks", "they think"),
        ("They calls", "They call"), ("they calls", "they call"),
        ("They walks", "They walk"), ("they walks", "they walk"),
        ("They leaves", "They leave"), ("they leaves", "they leave"),
        ("They lives", "They live"), ("they lives", "they live"),
        ("They tells", "They tell"), ("they tells", "they tell"),
        ("They runs", "They run"), ("they runs", "they run"),
        ("They finds", "They find"), ("they finds", "they find"),
        ("They asks", "They ask"), ("they asks", "they ask"),
        ("They gives", "They give"), ("they gives", "they give"),
        ("They sees", "They see"), ("they sees", "they see"),
        ("They wants", "They want"), ("they wants", "they want"),
        ("They needs", "They need"), ("they needs", "they need"),
        ("They tries", "They try"), ("they tries", "they try"),
        ("They turns", "They turn"), ("they turns", "they turn"),
        ("They puts", "They put"), ("they puts", "they put"),
        ("They moves", "They move"), ("they moves", "they move"),
        ("They stands", "They stand"), ("they stands", "they stand"),
        ("They sits", "They sit"), ("they sits", "they sit"),
        ("They holds", "They hold"), ("they holds", "they hold"),
        ("They plays", "They play"), ("they plays", "they play"),
        ("They falls", "They fall"), ("they falls", "they fall"),
        ("They watches", "They watch"), ("they watches", "they watch"),
        ("They reaches", "They reach"), ("they reaches", "they reach"),
        ("They wishes", "They wish"), ("they wishes", "they wish"),
        ("They refuses", "They refuse"), ("they refuses", "they refuse"),
        ("They prefers", "They prefer"), ("they prefers", "they prefer"),
        ("They owns", "They own"), ("they owns", "they own"),
        ("They shows", "They show"), ("they shows", "they show"),
        ("They sends", "They send"), ("they sends", "they send"),
        ("They brings", "They bring"), ("they brings", "they bring"),
        ("They hears", "They hear"), ("they hears", "they hear"),
        ("They loves", "They love"), ("they loves", "they love"),
        ("They eats", "They eat"), ("they eats", "they eat"),
        ("They fights", "They fight"), ("they fights", "they fight"),
        ("They dies", "They die"), ("they dies", "they die"),
        ("They reads", "They read"), ("they reads", "they read"),
        ("They speaks", "They speak"), ("they speaks", "they speak"),
        ("They lies", "They lie"), ("they lies", "they lie"),
        ("They counts", "They count"), ("they counts", "they count"),
        ("They trades", "They trade"), ("they trades", "they trade"),
        ("They signs", "They sign"), ("they signs", "they sign"),
        ("They helps", "They help"), ("they helps", "they help"),
        ("They dreams", "They dream"), ("they dreams", "they dream"),
        ("They offers", "They offer"), ("they offers", "they offer"),
        # Handle "has" at end of sentence (no trailing space)
        ("They has.", "They have."), ("they has.", "they have."),
        ("They has,", "They have,"), ("they has,", "they have,"),
        ("They was.", "They were."), ("they was.", "they were."),
        ("They was,", "They were,"), ("they was,", "they were,"),
        ("They does.", "They do."), ("they does.", "they do."),
        ("They does,", "They do,"), ("they does,", "they do,"),
        ("They remembers", "They remember"), ("they remembers", "they remember"),
        ("They intends", "They intend"), ("they intends", "they intend"),
        ("They appears", "They appear"), ("they appears", "they appear"),
        ("They believes", "They believe"), ("they believes", "they believe"),
        ("They manages", "They manage"), ("they manages", "they manage"),
        ("They produces", "They produce"), ("they produces", "they produce"),
        ("They continues", "They continue"), ("they continues", "they continue"),
        ("They remains", "They remain"), ("they remains", "they remain"),
    ]
    for wrong, right in fixes:
        text = text.replace(wrong, right)
    # Regex catch-all: "They [verb]s " where verb ends in common patterns
    import re
    # Match "They <word>s " where word is 3+ chars and ends with s (but not ss, us, is)
    def _fix_they_verb(m):
        verb = m.group(1)
        # Don't fix words that naturally end in s (is, was, has — already handled above)
        # Don't fix words ending in ss, us, is (e.g. "discusses", "focuses")
        if verb.endswith(("ss", "us")):
            return m.group(0)
        # Strip trailing 's' for simple cases, 'es' for -ches/-shes/-xes/-zes
        if verb.endswith(("ches", "shes", "xes", "zes", "sses")):
            return m.group(0).replace(verb, verb[:-2])
        if verb.endswith(("ies",)):
            return m.group(0).replace(verb, verb[:-3] + "y")
        if verb.endswith("s") and not verb.endswith(("ss",)):
            return m.group(0).replace(verb, verb[:-1])
        return m.group(0)
    text = re.sub(r'\b[Tt]hey ([a-z]{3,}s)\b', _fix_they_verb, text)
    return text


def format_relationship(rel_type, other_name):
    """Format a relationship for display with proper phrasing per type."""
    special = {
        "killed": f"killed {other_name}",
        "killed_by": f"killed by {other_name}",
        "betrayed_by": f"betrayed by {other_name}",
        "betrayer_of": f"betrayed {other_name}",
        "saved_life_of": f"saved the life of {other_name}",
        "owes_life_to": f"owes their life to {other_name}",
        "shares_secret_with": f"shares a secret with {other_name}",
        "witnessed_death_of": f"witnessed the death of {other_name}",
        "blackmailer": f"blackmailing {other_name}",
        "blackmailed_by": f"blackmailed by {other_name}",
        "fears": f"fears {other_name}",
        "trusts": f"trusts {other_name}",
        "suspects": f"suspects {other_name}",
        "crew_mate": f"crew mate of {other_name}",
        "former_crew": f"former crew mate of {other_name}",
        "commanding_officer": f"commanding officer of {other_name}",
        "co_conspirator": f"co-conspirator with {other_name}",
        "lover_secret": f"secret lover of {other_name}",
        "unrequited": f"unrequited feelings for {other_name}",
        "estranged": f"estranged from {other_name}",
        "adopted_family": f"adopted family of {other_name}",
        "widowed_by": f"widowed by {other_name}",
    }
    if rel_type in special:
        return special[rel_type]
    return f"{rel_type.replace('_', ' ')} of {other_name}"


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
    # --- Discovery (found something strange) ---
    "{first} found {item} in a place it shouldn't be. Now {gl} can't stop dreaming about where it came from.",
    "A dead colonist's data pad contains a message for {first}. Timestamped three days from now.",
    "{first} found a room behind the wall in Section C. It's furnished. Someone lived there. Recently.",
    "Drill team hit a cavity at depth. Inside: a {item}, intact, and warm to the touch. {first} won't let anyone else near it.",
    "{first} found writing on the inside of a sealed pipe. Same handwriting as {gp} own. {g} doesn't remember writing it.",
    "A thermal core pulled from the deep bore has a serial number. A Mammona serial number. From a colony that doesn't exist.",
    # --- Return (someone from the past appears) ---
    "Someone {first} thought was dead just walked into the colony. {g} isn't happy to see them.",
    "A name from {first}'s past showed up on the incoming shuttle manifest. {g} has three days to decide what to do about it.",
    "{first} received a package from {location}. No return address. Inside: {item} and a note that says 'You know what to do.'",
    "A colonist {first} worked with on {location} arrived on the last shuttle. They won't make eye contact.",
    "Someone claiming to be {first}'s sibling is asking questions in the mess hall. {first} doesn't have a sibling.",
    "The new transfer has the same scar pattern as someone {first} buried on {location}. Same placement. Same depth.",
    # --- Signal (intercepted/detected something) ---
    "{first} has been hearing the same frequency as the deep bore. In {gp} sleep. Getting louder.",
    "Someone is leaving {first} threats. Written in a script that matches the precursor glyphs.",
    "{first} picked up a signal on a dead frequency. Coordinates embedded in the static. They point to something under the colony.",
    "HERMES sent {first} a private message at 0300. {first} won't say what it said. HERMES denies sending it.",
    "The comms relay is broadcasting a repeating pattern. {first} recognized it. It's a lullaby {gp} mother used to sing.",
    "{first} intercepted a coded transmission between the colony and an unknown receiver. The encryption matches MasTema protocols.",
    # --- Observation (noticed a pattern others missed) ---
    "Every third shift, {first} disappears for two hours. {g} comes back smelling like copper and ozone.",
    "{first} insists someone on the colony isn't who they say they are. {g} has evidence. It's convincing.",
    "After day 15, {first} starts leaving notes in the common room. Each one contains a single coordinate.",
    "{first} has been tracking the generator's power output. The numbers don't match the fuel consumption. Something else is drawing power.",
    "{first} noticed that the bore shaft temperature spikes every 72 hours. Exactly. Nobody else has put the pattern together.",
    "{first} charted the colony's illness reports over six months. The pattern matches the tidal cycle of something that shouldn't have tides.",
    # --- Request (needs help with something specific) ---
    "{first} asks the player to retrieve {item} from {location}. Simple job. Except the room has been sealed since before the colony arrived.",
    "{first} wants to reach {location} before anyone else does. Won't say why. Offers everything {gl} has.",
    "{first} needs help destroying something before Mammona finds it. The window is closing.",
    "A sealed drive arrives addressed to {first}. {g} won't open it alone. Needs a witness.",
    "{first} needs someone to watch a corridor for two hours while {gl} does something {gl} won't explain. Payment: a favor to be named later.",
    "{first} wants to send a message off-colony without using the Mammona relay. Needs parts. Needs help. Needs silence.",
    "{first} has a list of five names. Four are colonists. One is dead. {g} needs help figuring out which name is wrong.",
    # --- Disappearance (someone/something missing) ---
    "{first}'s bunkmate hasn't been seen in three days. The bunk is made. The locker is empty. Nobody remembers them leaving.",
    "The {item} {first} kept in {gp} locker is gone. Replaced with something identical but wrong. The weight is different.",
    "{first} reports that {gp} tools were moved during the night. Not stolen. Rearranged. Into a shape.",
    "A section of the colony has gone quiet. {first} is the last person who went in. {g} came back. Won't say where the others are.",
    "{first}'s shift partner vanished during a routine bore shaft check. The equipment came back. The person didn't.",
    # --- Offer (has something to trade or share) ---
    "{first} has information about {location} that Mammona would kill for. Literally. {g}'s offering it to you first.",
    "{first} found a way to extend the reactor's fuel cycle by thirty percent. The method involves something from the precursor ruins. {g} needs help getting it.",
    "{first} is willing to share the location of a hidden cache at {location}. In exchange: help getting off Erebus.",
    "{first} has a working comms unit that bypasses the Mammona relay. Offers ten minutes of unsupervised transmission time. Price: one favor.",
    "{first} built something in the workshop after hours. Won't say what. Says it could change everything. Needs someone to test it.",
    # --- Threat (something is coming for them) ---
    "{first} is being stalked. Not by colony fauna. By another colonist. {g} knows who. Can't prove it.",
    "MasTema sent {first} a contract termination notice. On Erebus, termination isn't administrative.",
    "{first} received a countdown. Numbers scratched into {gp} bunk frame. Nobody saw who did it. The number is getting smaller.",
    "Something followed {first} back from {location}. {g} can hear it at night. Scratching. Getting closer.",
    "{first} overheard a conversation about {go}. Plans. Specifics. Names of people who'd benefit from {gp} absence.",
    # --- Change (something about them is different) ---
    "{first} can suddenly read the precursor glyphs. Started three days ago. It's getting easier. That scares {go}.",
    "{first}'s handwriting has changed. {g} noticed it in the shift log. Same words. Different hand.",
    "{first} hasn't been eating. Says {gl}'s not hungry. Says {gl} hasn't been hungry since the last bore shaft shift.",
    "The dogs started following {first} three days ago. All of them. At once. {first} doesn't know why.",
    "{first} woke up in a different part of the colony with no memory of walking there. For the third time this week.",
    # --- Secret (carrying dangerous information) ---
    "{first} has a data chip that proves Mammona knew about the bore shaft anomaly before the colony was placed. The chip has a kill-switch.",
    "{first} knows where the previous crew is. Not dead. Not gone. Somewhere in the colony. Behind a wall that shouldn't be there.",
    "{first} intercepted a manifest. The next supply ship is carrying something that's not on the official cargo list. Something alive.",
    "{first} figured out what the thermal cores actually are. Hasn't told anyone. Can't un-know it. Needs to decide what to do.",
    "{first} has proof that one of the colonists is a MasTema plant. The proof is also evidence of {first}'s own crimes.",
]


# ============================================================
# RELATIONSHIP WEB — bidirectional NPC wiring
# ============================================================

def _get_inverse_relationship(rel_type):
    """Map asymmetric relationships to their inverse. Symmetric types return themselves."""
    INVERSES = {
        "mentor": "protege", "protege": "mentor",
        "parent": "child", "child": "parent",
        "debtor": "creditor", "creditor": "debtor",
        "blackmailer": "blackmailed_by", "blackmailed_by": "blackmailer",
        "betrayed_by": "betrayer_of", "betrayer_of": "betrayed_by",
        "killed": "killed_by", "killed_by": "killed",
        "saved_life_of": "owes_life_to", "owes_life_to": "saved_life_of",
        "commanding_officer": "subordinate", "subordinate": "commanding_officer",
        "widowed_by": "killed",
    }
    return INVERSES.get(rel_type, rel_type)


def _generate_relationship_history(npc, other, rel_type):
    """Generate a 1-sentence history for the relationship between two NPCs."""
    other_first = other["name"].split()[0]
    npc_first = npc["name"].split()[0]
    templates = {
        "partner": [
            f"met on {R(LOCATIONS_FLAT)} during a double shift",
            "started quietly, nobody noticed for months",
            f"bonded over shared rations on {R(LOCATIONS_FLAT)}",
        ],
        "ex_partner": [
            f"separated after {R(LOCATIONS_FLAT)}",
            "it ended badly, nobody talks about it",
            "split over a disagreement about what they saw in the bore shaft",
        ],
        "spouse": [
            f"married in a brief ceremony on {R(LOCATIONS_FLAT)}",
            "colony records list them as bonded, no ceremony on file",
        ],
        "widowed_by": [
            f"{other_first} didn't come back from the last survey run",
            f"lost {other_first} during the {R(LOCATIONS_FLAT)} incident",
        ],
        "parent": [
            f"raised {other_first} on {R(LOCATIONS_FLAT)} before the transfer",
            f"{other_first} was born mid-transit, no birth planet on file",
        ],
        "child": [
            f"grew up on {R(LOCATIONS_FLAT)}, hasn't spoken to {other_first} in years",
            f"followed {other_first} into the same line of work",
        ],
        "sibling": [
            f"grew up together on {R(LOCATIONS_FLAT)}",
            "same parents, different postings, reunited by accident",
            "don't look alike but finish each other's sentences",
        ],
        "adopted_family": [
            f"took {other_first} in after {R(LOCATIONS_FLAT)}",
            "not blood, but closer than blood",
        ],
        "mentor": [
            f"trained {other_first} on {R(LOCATIONS_FLAT)}",
            f"taught {other_first} everything about the bore systems",
            f"took {other_first} under wing after the previous mentor vanished",
        ],
        "protege": [
            f"learned the trade from {other_first} on {R(LOCATIONS_FLAT)}",
            f"{other_first} saw potential, nobody else did",
        ],
        "rival": [
            f"competing since {R(LOCATIONS_FLAT)}",
            "same job, different methods",
            f"both applied for the same posting on {R(LOCATIONS_FLAT)}, neither forgot",
        ],
        "nemesis": [
            f"this goes back to {R(LOCATIONS_FLAT)}, and it's personal",
            "one of them crossed a line, the other one remembers",
        ],
        "debtor": [
            R(["owes for shuttle passage", "owes for a medical procedure", "owes for silence"]),
            f"borrowed heavily before the {R(LOCATIONS_FLAT)} posting",
        ],
        "creditor": [
            f"lent resources during the {R(LOCATIONS_FLAT)} crisis",
            "keeps a ledger, never forgets a debt",
        ],
        "blackmailer": [
            f"knows what {other_first} did on {R(LOCATIONS_FLAT)}",
            f"has documentation that Mammona would pay to see",
        ],
        "blackmailed_by": [
            f"{other_first} has leverage, and they both know it",
            "pays in silence and favors",
        ],
        "co_conspirator": [
            f"planned something together on {R(LOCATIONS_FLAT)} that can't be undone",
            "share a secret that would get them both spaced",
        ],
        "betrayed_by": [
            f"{other_first} sold them out on {R(LOCATIONS_FLAT)}",
            f"trusted {other_first} with something important, regrets it",
        ],
        "betrayer_of": [
            f"made a choice on {R(LOCATIONS_FLAT)} that {other_first} hasn't forgiven",
            "did what needed doing, doesn't apologize for it",
        ],
        "crew_mate": [
            f"served together on {R(LOCATIONS_FLAT)}",
            "same shift rotation for two years running",
            f"pulled the same detail on the {R(LOCATIONS_FLAT)} transit",
        ],
        "former_crew": [
            f"used to run together on {R(LOCATIONS_FLAT)}, before things changed",
            "the crew dissolved, the memories didn't",
        ],
        "commanding_officer": [
            f"gave {other_first} orders on {R(LOCATIONS_FLAT)}",
            f"ran the operation that {other_first} survived",
        ],
        "subordinate": [
            f"took orders from {other_first} on {R(LOCATIONS_FLAT)}",
            f"followed {other_first} into a situation that went wrong",
        ],
        "lover_secret": [
            "nobody on the colony knows about this",
            f"started on {R(LOCATIONS_FLAT)}, kept it quiet since",
        ],
        "unrequited": [
            f"watches {other_first} across the mess hall, says nothing",
            f"wrote letters to {other_first} that were never sent",
        ],
        "estranged": [
            f"haven't spoken since {R(LOCATIONS_FLAT)}",
            "same colony, different worlds",
        ],
        "killed": [
            f"it happened on {R(LOCATIONS_FLAT)}, officially an accident",
            "the details are in a sealed file somewhere",
        ],
        "killed_by": [
            f"the killing happened on {R(LOCATIONS_FLAT)}, the silence happened after",
        ],
        "witnessed_death_of": [
            f"was there when it happened on {R(LOCATIONS_FLAT)}",
            "saw everything, reported nothing",
        ],
        "saved_life_of": [
            f"pulled {other_first} out of a collapsed section on {R(LOCATIONS_FLAT)}",
            f"intervened during the {R(LOCATIONS_FLAT)} incident",
        ],
        "owes_life_to": [
            f"would be dead without {other_first}, and they both know it",
            f"{other_first} dragged them out of {R(LOCATIONS_FLAT)} alive",
        ],
        "shares_secret_with": [
            f"both know what's in Section {R(['A','B','C','D','E','F'])}",
            f"found something on {R(LOCATIONS_FLAT)} that they agreed never to report",
        ],
        "suspects": [
            f"watches {other_first} too closely during shift changes",
            f"keeps notes on {other_first}'s movements",
        ],
        "trusts": [
            f"the only person on {R(LOCATIONS_FLAT)} worth trusting",
            f"would follow {other_first} into the bore shaft, no questions",
        ],
        "fears": [
            f"avoids {other_first} when possible, won't say why",
            f"something about {other_first} isn't right, hasn't been since {R(LOCATIONS_FLAT)}",
        ],
    }
    pool = templates.get(rel_type, [f"connected through shared history on {R(LOCATIONS_FLAT)}"])
    return R(pool)


def wire_relationships(ctx):
    """Wire NPCs in a batch into a relationship web. Bidirectional."""
    npcs = ctx.npcs
    if len(npcs) < 2:
        return
    for npc in npcs:
        n_rels = RI(1, min(3, len(npcs) - 1))
        others = [o for o in npcs if o["id"] != npc["id"] and o["id"] not in npc.get("relationships", {})]
        if not others:
            continue
        for other in random.sample(others, min(n_rels, len(others))):
            rel_type = R(RELATIONSHIP_TYPES)
            history = _generate_relationship_history(npc, other, rel_type)
            # Set bidirectional
            npc.setdefault("relationships", {})[other["id"]] = {
                "type": rel_type, "status": "active", "history": history,
            }
            inverse = _get_inverse_relationship(rel_type)
            other.setdefault("relationships", {})[npc["id"]] = {
                "type": inverse, "status": "active", "history": history,
            }


# ============================================================
# ARC-STAGE DIALOGUE TONES
# ============================================================

ARC_STAGE_TONE_MAP = {
    "desperate": "desperate",
    "broken": "numb",
    "paranoid": "paranoid",
    "vengeful": "furious",
    "contaminated": "cosmic_horror",
    "changed": "cosmic_horror",
    "obsessed": "obsession",
    "lost": "isolation",
    "violent": "furious",
    "sick": "body_horror",
    "stressed": "desperate",
    "suspicious": "paranoid",
    "grief": "melancholy",
    "betrayed": "furious",
    "rebuilt": "tender",
    "loyal": "tender",
    "curious": "clinical",
    "healthy": "gallows_humor",
}


def get_arc_dialogue_tone(npc):
    """Get tone override based on NPC's arc stage. Returns None for stable/unknown."""
    stage = npc.get("arc_stage", "stable")
    return ARC_STAGE_TONE_MAP.get(stage)


# ============================================================
# NPC GENERATOR
# ============================================================

def gen_npc(ctx, tone=None, planet=None, era=None):
    """
    Compositional NPC backstory engine.
    Builds a unique character from independent slots: origin, career,
    trauma, secret, habit, physical, debt, traits, passion, fear,
    love, family, genetics, and relationships.
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

    # --- Character weight (archetype bias) ---
    character_weight = None
    weight_data = None
    if random.random() < 0.5:  # 50% chance of an archetype bias
        character_weight = R(CHARACTER_WEIGHT_KEYS)
        weight_data = CHARACTER_WEIGHTS[character_weight]

    # --- Traits ---
    traits = pick_traits()

    # --- Apply character weight bias to traits ---
    if weight_data and weight_data.get("trait_bias"):
        # Try to swap in one biased trait (doesn't force, just biases)
        bias_pool = weight_data["trait_bias"]
        candidate = R(bias_pool)
        # Check if candidate is in the right category and doesn't conflict
        all_trait_pools = TRAITS_P + TRAITS_N + TRAITS_X
        if candidate in all_trait_pools:
            conflicts = False
            for t in traits:
                for a, b in TRAIT_CONFLICTS:
                    if (candidate == a and t == b) or (candidate == b and t == a):
                        conflicts = True
                        break
                if conflicts:
                    break
            if not conflicts and candidate not in traits:
                # Replace one trait of the same category if possible
                if candidate in TRAITS_P and any(t in TRAITS_P for t in traits):
                    for i, t in enumerate(traits):
                        if t in TRAITS_P:
                            traits[i] = candidate
                            break
                elif candidate in TRAITS_N and any(t in TRAITS_N for t in traits):
                    for i, t in enumerate(traits):
                        if t in TRAITS_N:
                            traits[i] = candidate
                            break
                elif candidate in TRAITS_X:
                    if len(traits) > 2 and traits[-1] in TRAITS_X:
                        traits[-1] = candidate
                    elif len(traits) <= 2:
                        traits.append(candidate)

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
    habit = gender_replace(habit, gender)

    # --- Physical detail ---
    physical = ctx.pick_fresh(PHYSICAL, "PHYSICAL")
    physical = gender_replace(physical, gender)

    # --- Debt ---
    debt = R(DEBTS)

    # --- Body part & trauma cause ---
    body_part = R(BODY_PARTS)
    trauma_cause = R(TRAUMA_CAUSES)

    # --- Years (for backstory filler) ---
    years = str(RI(2, 14))

    # --- Brand ---
    brand = R(BRAND_NAMES) if BRAND_NAMES else "Sunny Fizz"

    # --- New identity layers ---
    passion = ctx.pick_fresh(PASSIONS, "PASSIONS")
    passion = gender_replace(passion, gender)

    fear_raw = ctx.pick_fresh(FEARS, "FEARS")
    fear_raw = gender_replace(fear_raw, gender)

    love_template = ctx.pick_fresh(LOVES, "LOVES")
    love_status = safe_format(love_template, location=R(LOCATIONS_FLAT),
                              first=first, last=last, g=g, gl=gl, gp=gp, go=go)
    love_status = gender_replace(love_status, gender)

    family_bg = ctx.pick_fresh(FAMILY, "FAMILY")
    family_bg = gender_replace(family_bg, gender)

    genetic_detail = ctx.pick_fresh(GENETICS, "GENETICS")
    genetic_detail = gender_replace(genetic_detail, gender)

    # --- Body type ---
    body_type = ctx.pick_fresh(BODY_TYPES, "BODY_TYPES")
    body_type = gender_replace(body_type, gender)

    # --- Health condition ---
    health_chance = weight_data["health_chance"] if weight_data else 0.35
    health_cond = None
    health_cond_text = None
    if random.random() < health_chance:
        health_cond = R(HEALTH_CONDITIONS)
        health_cond_text = f"{health_cond['condition']}: {health_cond['behavioral']}"
        health_cond_text = gender_replace(health_cond_text, gender)

    # --- Mental health ---
    mental_chance = weight_data["mental_chance"] if weight_data else 0.3
    mental_health_cond = None
    mental_health_text = None
    if random.random() < mental_chance:
        mental_health_cond = R(MENTAL_HEALTH)
        mh_behavior = mental_health_cond["hidden_signs"]
        mh_coping = mental_health_cond.get("coping", "")
        mental_health_text = f"{mh_behavior}"
        if mh_coping:
            mental_health_text += f" {mh_coping}"
        mental_health_text = gender_replace(mental_health_text, gender)

    # --- Genetic disorder ---
    genetic_disorder = None
    genetic_disorder_text = None
    if random.random() < 0.15:
        genetic_disorder = R(GENETIC_DISORDERS)
        genetic_disorder_text = f"{genetic_disorder['condition']}: {genetic_disorder['behavioral']}"
        genetic_disorder_text = gender_replace(genetic_disorder_text, gender)

    # --- Hidden condition (affects behavior, not labeled) ---
    hidden_condition = None
    hidden_behavioral = None
    if random.random() > 0.6:  # 40% chance
        hidden_pool = MENTAL_HEALTH + HEALTH_CONDITIONS
        hidden_entry = R(hidden_pool)
        hidden_condition = hidden_entry.get("condition", "")
        # Extract behavioral text without the label
        if "hidden_signs" in hidden_entry:
            hidden_behavioral = hidden_entry["hidden_signs"]
            coping = hidden_entry.get("coping", "")
            if coping:
                hidden_behavioral += f" {coping}"
        elif "behavioral" in hidden_entry:
            hidden_behavioral = hidden_entry["behavioral"]
        if hidden_behavioral:
            hidden_behavioral = gender_replace(hidden_behavioral, gender)

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

    # --- Weave hidden condition into backstory as behavioral detail ---
    if hidden_behavioral:
        backstory_parts.append(hidden_behavioral)

    backstory = "\n\n".join(backstory_parts)

    # --- Apply contractions ---
    backstory = enforce_contractions(backstory, tone)
    passion = enforce_contractions(passion, tone)
    fear_raw = enforce_contractions(fear_raw, tone)
    love_status = enforce_contractions(love_status, tone)
    family_bg = enforce_contractions(family_bg, tone)
    genetic_detail = enforce_contractions(genetic_detail, tone)
    body_type = enforce_contractions(body_type, tone)
    if health_cond_text:
        health_cond_text = enforce_contractions(health_cond_text, tone)
    if mental_health_text:
        mental_health_text = enforce_contractions(mental_health_text, tone)
    if genetic_disorder_text:
        genetic_disorder_text = enforce_contractions(genetic_disorder_text, tone)

    # --- Fix NB pronoun verb conjugation ---
    backstory = fix_nb_verbs(backstory, gender)
    passion = fix_nb_verbs(passion, gender)
    fear_raw = fix_nb_verbs(fear_raw, gender)
    love_status = fix_nb_verbs(love_status, gender)
    family_bg = fix_nb_verbs(family_bg, gender)
    genetic_detail = fix_nb_verbs(genetic_detail, gender)
    body_type = fix_nb_verbs(body_type, gender)
    if health_cond_text:
        health_cond_text = fix_nb_verbs(health_cond_text, gender)
    if mental_health_text:
        mental_health_text = fix_nb_verbs(mental_health_text, gender)
    if genetic_disorder_text:
        genetic_disorder_text = fix_nb_verbs(genetic_disorder_text, gender)

    # --- Arc stage (most start stable, some arrive mid-arc) ---
    arc_stage = "stable"
    if random.random() < 0.25:
        arc_stage = R(ARC_STAGES)

    # --- Dialogue lines (arc-stage tone override) ---
    primary_trait = traits[0] if traits else None
    dialogue_tone = tone
    arc_tone = ARC_STAGE_TONE_MAP.get(arc_stage)
    if arc_tone:
        dialogue_tone = arc_tone

    dialogue_contexts = ["greeting", "warning", "confession", "observation", "rumor"]
    # Add varied contexts based on tone
    extra_contexts = ["complaint", "memory", "threat", "plea", "joke", "prayer"]
    dialogue_contexts.append(R(extra_contexts))
    if random.random() > 0.5:
        dialogue_contexts.append(R(extra_contexts))

    dialogue_lines = []
    used_lines = set()
    for dctx in dialogue_contexts:
        line = get_dialogue(dctx, dialogue_tone, primary_trait)
        if line not in used_lines and line != "...":
            dialogue_lines.append(line)
            used_lines.add(line)

    # --- Preliminary relationship text (wire_relationships fills the full web later) ---
    relationship_text = ""
    other_npc = ctx.get_random_npc()
    if other_npc:
        rel_type = R(RELATIONSHIP_TYPES)
        other_name = other_npc["name"]
        relationship_text = format_relationship(rel_type, other_name)

    # --- Quest hook ---
    hook_fill = dict(
        first=first, g=g, gl=gl, gp=gp, go=go,
        item=R(ITEMS), location=R(LOCATIONS_FLAT),
    )
    quest_hook = safe_format(R(QUEST_HOOKS), **hook_fill)
    quest_hook = enforce_contractions(quest_hook, tone)
    quest_hook = fix_nb_verbs(quest_hook, gender)

    # --- Register NPC in context ---
    npc_data = {
        "name": f"{first} {last}",
        "id": f"{first.lower()}_{last.lower()}",
        "gender": gender,
        "age": age,
        "job": job,
        "traits": traits,
        "passion": passion,
        "fear": fear_raw,
        "love": love_status,
        "family": family_bg,
        "genetics": genetic_detail,
        "body_type": body_type,
        "health_condition": health_cond["condition"] if health_cond else None,
        "mental_health": mental_health_cond["condition"] if mental_health_cond else None,
        "genetic_disorder": genetic_disorder["condition"] if genetic_disorder else None,
        "hidden_condition": hidden_condition,
        "character_weight": character_weight,
        "faction": faction_key,
        "tone": tone,
        "alive": True,
        "location": location,
        "arc_stage": arc_stage,
        "relationships": {},
    }
    ctx.add_npc(npc_data)

    # --- Also persist to world state ---
    ctx.world.set_npc(npc_data["id"], npc_data)

    # --- Format output ---
    trait_str = ", ".join(traits)
    dialogue_block = "\n".join(f'- "{line}"' for line in dialogue_lines)

    connection_line = f"**Connection:** {relationship_text}" if relationship_text else "**Connection:** None yet -- first in batch"

    arc_display = f" | **Arc Stage:** {arc_stage}" if arc_stage != "stable" else ""

    # Clean up trailing punctuation for identity composition
    genetic_clean = genetic_detail.rstrip(".")
    family_clean = family_bg.rstrip(".")
    body_clean = body_type.rstrip(".")

    # Build health/condition lines (only visible/stated conditions appear here)
    condition_lines = []
    if health_cond_text:
        condition_lines.append(f"**Health:** {health_cond_text}")
    if mental_health_text and mental_health_cond and mental_health_cond.get("visible"):
        # Only show mental health in the sheet if it's visible
        condition_lines.append(f"**Mental Health:** {mental_health_cond['condition']} — {mental_health_text}")
    if genetic_disorder_text and genetic_disorder and genetic_disorder.get("visible"):
        condition_lines.append(f"**Genetic:** {genetic_disorder_text}")
    condition_block = "\n".join(condition_lines) if condition_lines else ""

    weight_display = f" | **Archetype:** {character_weight}" if character_weight else ""

    output = f"""## NPC: {first} {last}
**Gender:** {gender_label} | **Age:** {age} | **Occupation:** {job}
**Traits:** {trait_str}
**Faction:** {faction_name}{arc_display}{weight_display}
**Tone:** {tone}

**Identity:**
{body_clean}. {genetic_clean}. {family_clean}.

**Background:**
{backstory}

**What Drives Them:** {passion}
**What Haunts Them:** {fear_raw}

**Dialogue:**
{dialogue_block}

**Connections:**
{connection_line}
**Love:** {love_status}

**Physical:** {physical}
**Habit:** {habit}
**Debt:** {debt}"""

    if condition_block:
        output += f"\n\n{condition_block}"

    output += f"""

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

    # --- Relationship context ---
    rel_context = ""
    if existing_npc and existing_npc.get("relationships"):
        rel_ids = list(existing_npc["relationships"].keys())
        rel_id = R(rel_ids)
        rel_npc = next((n for n in ctx.npcs if n["id"] == rel_id), None)
        if rel_npc:
            rel = existing_npc["relationships"][rel_id]
            rel_data = rel if isinstance(rel, dict) else {"type": rel, "history": ""}
            rel_type_str = rel_data.get("type", str(rel))
            rel_history = rel_data.get("history", "")
            history_suffix = f" {rel_history}." if rel_history else ""
            rel_display = format_relationship(rel_type_str, rel_npc['name'])
            rel_context = f"\n**Connection:** {npc_full} -- {rel_display}.{history_suffix}"

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

**Reward:** {reward_cores} thermal cores, {reward_type}{rel_context}"""

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

    # Entry 1: Discovery (randomized opening)
    opening_variants = [
        f"""The samples aren't behaving. That's not the right word. Samples don't behave. They exhibit properties. These are exhibiting properties outside any reference material available to me. {lo} -- or what the brief says is {lo} -- has a thermal signature that inverts at night. It shouldn't have a thermal signature at all.

Ran the spectrograph three times. Same result. The crystalline structure shifts at the molecular level when the temperature drops below -20C. Not fracturing. Reorganizing. Like it's adapting.""",

        f"""The readings don't make sense. Not wrong -- they make sense, just not in any framework I was trained in. {lo} is producing output that the spectrometer interprets as noise. It isn't noise. Noise is random. This has structure. Mathematical structure. The kind that implies a system behind it.

I ran the analysis twice. Both times the software flagged the data as 'instrument error.' The instrument is fine. I calibrated it this morning. The data is accurate. The data is also impossible.""",

        f"""I wasn't looking for anomalies. I was running standard assays on material recovered from {loc}. That's what makes this worse. A standard assay. Routine. And then the mass spectrometer returned a molecular weight that doesn't correspond to any element on the periodic table.

Not a compound. Not an alloy. An element. One that shouldn't exist. {lo} has been sitting in this lab for two weeks and nobody noticed because nobody ran the right test. I ran the right test. I wish I hadn't.""",

        f"""Something is wrong with the control group. The control group should be the one thing that's not wrong. That's what 'control' means. The baseline samples from {loc} are changing at the same rate as the experimental ones. No stimulus. No exposure. Sealed containers, inert atmosphere, stable temperature.

They're changing anyway. And they're changing in the same direction as {lo}. Like there's a signal I can't see. Like the experiment is running itself.""",

        f"""Day one, the numbers were clean. Day two, the numbers were clean but different. Day three, the numbers were clean, different, and impossible. I'm on day five now and I've stopped calling them numbers. They're a sequence. {lo} is outputting a sequence that my equipment translates into data.

Data implies encoding. Encoding implies intent. I am not comfortable with what that implies about {lo}. I am less comfortable with what it implies about the people who sent me here to study it.""",
    ]
    entries.append(f"""Day {day}.

{ctx.fresh_sensory(tone)}

{R(opening_variants)}

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
    """Corporate memo chain with 4 structural variants to avoid repetition."""
    variant = R(["standard", "investigation", "equipment_req", "safety_audit"])
    return _memo_chain_variant(variant, ctx, tone, first, last, g, gl, gp, go, loc)


def _memo_chain_variant(variant, ctx, tone, first, last, g, gl, gp, go, loc):
    """Dispatch to a memo chain variant. Each has different structure, length, and departments."""
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

    if variant == "standard":
        # Original: directive -> acknowledge -> incident -> reclassification -> comms ban -> MasTema assessment
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

        entries.append(f"""**FROM:** {manager_first} {manager_last}, Site Manager
**TO:** Regional Operations, Dept. {dept}
**RE:** RE: Operational Parameters Update -- Ref {ref}
**CLASSIFICATION:** Internal

Confirming receipt of directive {ref}.

Quota increase noted. For the record: current staffing at {loc} is {RI(60, 80)}% of recommended minimums. Equipment maintenance backlog is {RI(3, 8)} weeks. Requesting additional personnel and/or revised timeline.

Regarding {lo}: understood. Will redirect inquiries per protocol. Note: inquiries have increased {RI(200, 400)}% since last quarter. Redirecting them is becoming operationally noticeable.

Regarding HERMES patch: installed. Two terminals in {section} displaying anomalous responses post-update. Have submitted Form 77-B as instructed.

-- {manager_first} {manager_last}""")

        incident = R([
            f"During routine extraction in {site}, drill team encountered a cavity at {RI(80, 300)}m depth. Cavity was not on geological survey. Cavity contains structures. The structures are not natural. Drill team has been reassigned to surface duties pending further instruction.",
            f"Thermal core output from {site} spiked {RI(300, 800)}% above baseline for {RI(2, 10)} minutes. During the spike, {RI(2, 5)} personnel reported nosebleeds, disorientation, and 'a feeling of being observed.' Equipment readings have returned to normal. Personnel have not.",
            f"Three colonists attempted to access the sealed sublevel beneath {site}. They had no authorization, no tools, and no explanation for their behavior. Each reported 'being asked to come downstairs.' All three named different people as having asked them. All three people named are deceased.",
        ])
        entries.append(f"""**FROM:** {manager_first} {manager_last}, Site Manager
**TO:** Regional Operations, Dept. {dept}
**RE:** URGENT -- Incident Report, {site}
**CLASSIFICATION:** Restricted

Incident occurred at {RI(0, 23):02d}:{RI(0, 59):02d} today. Details:

{incident}

Awaiting instruction. Please advise.

-- {manager_first} {manager_last}""")

        entries.append(f"""**FROM:** Regional Operations, Dept. {dept}
**TO:** {manager_first} {manager_last}, Site Manager
**RE:** RE: URGENT -- Incident Report, {site} -- Ref {ref2}
**CLASSIFICATION:** Restricted / Eyes Only

{manager_last}:

The incident is reclassified as an "Environmental Variance Event" (EVE). Update all internal documentation accordingly.

The following terms are no longer to be used in official communications: {R([
    '"anomalous," "unexplained," "impossible." Use "under review" instead.',
    '"structures," "construction," "design." Use "geological formations" instead.',
    '"voice," "sound," "tone." Use "acoustic artifact" instead.',
])}

Personnel exhibiting continued symptoms should be referred to Medical for standard stress evaluation (Form 12-C). Do not use the word "symptoms." Use "scheduling concern."

This matter does not require further reporting unless a second EVE occurs.

-- Regional Operations""")

        entries.append(f"""**FROM:** Asset Assessment Division, MasTema Inc.
**TO:** {director_first} {director_last}, Regional Director
**CC:** [REDACTED]
**RE:** {loc} -- Ref {ref3}
**CLASSIFICATION:** VERMILLION / EYES ONLY

Director {director_last}:

The site is performing as intended. The {R([
    "personnel responses", "geological activity", "environmental conditions", "behavioral modifications",
])} described in Reports {ref} through {ref2} are consistent with projections from {R([
    "the Erebus Viability Study (2571)", "Project THRESHOLD Phase 2",
    "the Anomalous Biosphere Program's baseline models", "Dr. Venin's original survey data",
])}.

Recommendation: maintain current staffing. Do not evacuate. Do not reinforce.

If Site Manager {manager_last} files further reports, reassign {R(["them", "the site manager position"])}. The new manager should receive Briefing Packet VERMILLION-7 upon assignment.

-- Asset Assessment
MasTema Incorporated
*"Solutions. Delivered."*""")

    elif variant == "investigation":
        # Internal investigation chain: compliance flags anomaly -> investigator dispatched -> interviews -> cover-up -> investigator reassigned
        investigator_first, investigator_last, _ = ctx.fresh_name()
        witness_first, witness_last, _ = ctx.fresh_name()
        form_ref = f"CF-{RI(1000, 9999)}"

        entries.append(f"""**FROM:** Compliance & Oversight, Dept. {dept}
**TO:** Internal Affairs, Regional
**RE:** Anomalous Reporting Pattern -- {loc} -- Ref {form_ref}
**CLASSIFICATION:** Restricted

Automated compliance review has flagged the following at {loc}:

- {RI(7, 19)} Form 77-B submissions in {RI(2, 4)} weeks (baseline average: {RI(1, 3)} per quarter)
- {RI(3, 6)} personnel transfer requests citing 'personal reasons' (no further elaboration provided)
- Medical bay utilization up {RI(150, 350)}% with {RI(60, 90)}% of cases classified as 'stress-related'
- {RI(2, 4)} requisitions for equipment not standard to {loc}'s operational profile

Pattern is consistent with either widespread morale failure or an unreported critical event. Recommending field investigation.

-- Compliance & Oversight
Mammona Mining Corporation""")

        entries.append(f"""**FROM:** {investigator_first} {investigator_last}, Field Investigator
**TO:** Compliance & Oversight, Dept. {dept}
**RE:** Initial Assessment -- {loc} -- Ref {form_ref}
**CLASSIFICATION:** Restricted

Arrived at {loc} on Day {RI(1, 30)}. Initial observations:

Site Manager {manager_last} was cooperative but evasive. Answered direct questions with references to Mammona policy documents. Refused to discuss {lo} without citing Section 14 of the employment contract {RI(3, 7)} times in a single interview.

Personnel morale is not low. It is absent. These people are not unhappy. They are careful. There is a difference.

{R([
    f"The drill team refuses night shifts in {site}. No formal complaints filed. They simply do not go. Management has not enforced the schedule.",
    f"Medical records show {RI(4, 9)} cases of identical symptoms: insomnia, disorientation, and 'a sense of being observed.' All cases diagnosed as stress. All patients given the same anxiolytic. None reported improvement.",
    f"HERMES terminal in Section {section} is unplugged. Has been for {RI(2, 6)} weeks. Nobody reconnected it. When I asked why, three different people said 'it was saying things.'",
])}

Will continue investigation.

-- {investigator_first} {investigator_last}""")

        entries.append(f"""**FROM:** {investigator_first} {investigator_last}, Field Investigator
**TO:** Compliance & Oversight, Dept. {dept}
**RE:** Witness Interview Summary -- {loc} -- Ref {form_ref}
**CLASSIFICATION:** Restricted / Eyes Only

Conducted {RI(6, 12)} interviews over {RI(3, 5)} days. Summary:

{witness_first} {witness_last} ({R(JOBS)}): Described an event in {site} that does not appear in any incident log. Provided a date. Provided details. Began crying during the account. Refused to sign the transcript. Said signing it "would make it real."

{RI(3, 5)} other personnel corroborated {witness_last}'s account independently. No collaboration detected. Details are consistent to an unusual degree -- not paraphrased, not interpreted, but identical. As if they all saw the same recording.

Site Manager {manager_last} denies the event occurred. The denial was prepared. Rehearsed. Word-perfect.

I have the unsigned transcripts. I do not know what to do with them.

-- {investigator_first} {investigator_last}""")

        entries.append(f"""**FROM:** Regional Operations, Dept. {dept2}
**TO:** {investigator_first} {investigator_last}, Field Investigator
**RE:** Investigation Closure -- {loc} -- Ref {form_ref}
**CLASSIFICATION:** Restricted / Eyes Only

Investigator {investigator_last}:

Your investigation at {loc} is concluded effective immediately. Please submit all materials -- transcripts, recordings, personal notes -- to Dept. {dept2} via secured courier. Do not retain copies.

Your next assignment is {R(["Thalassa Deep", "Karnaith Orbital", "Rhea-2 Processing Station"])}. Transport departs in 48 hours.

The compliance flag that initiated this investigation has been resolved. The resolution is administrative, not investigative. We appreciate your diligence.

Do not contact {loc} personnel after departure.

-- Regional Operations
Mammona Mining Corporation
*"Building Tomorrow's Foundation"*""")

    elif variant == "equipment_req":
        # Equipment requisition chain: site requests gear -> denied -> site requests again citing emergency -> partial approval -> the approved equipment is wrong -> silence
        tech_first, tech_last, _ = ctx.fresh_name()
        req_ref = f"EQ-{RI(1000, 9999)}"
        equipment = R([
            "deep-bore seismic array", "Class IV containment unit",
            "wide-spectrum frequency analyzer", "cryo-rated hazmat suits (6)",
            "neural-shielded communications relay", "specimen transport pods (3)",
        ])
        fallback_equipment = R([
            "standard atmospheric filters", "replacement drill bits (bulk)",
            "NutriLoaf (resupply, 6 months)", "HERMES terminal maintenance kit",
            "fire suppression canisters", "morale improvement package (poster set)",
        ])

        entries.append(f"""**FROM:** {manager_first} {manager_last}, Site Manager
**TO:** Supply & Logistics, Dept. {dept}
**RE:** Priority Equipment Requisition -- Ref {req_ref}
**CLASSIFICATION:** Internal

Requesting immediate allocation of the following:

1. {equipment}
2. Personnel with training on the above (current staff is unqualified)
3. Consultation with specialist division regarding {lo}

Justification: conditions at {site} have exceeded parameters addressable with current equipment. Details in attached incident reports (Refs {ref}, {ref2}).

This is the third requisition for this equipment. Previous requests returned: 'budget insufficient' and 'not applicable to site profile.' It is applicable. I am asking again.

-- {manager_first} {manager_last}""")

        entries.append(f"""**FROM:** Supply & Logistics, Dept. {dept}
**TO:** {manager_first} {manager_last}, Site Manager
**RE:** RE: Priority Equipment Requisition -- Ref {req_ref}
**CLASSIFICATION:** Internal

{manager_last}:

Request denied. {R([
    f"The {equipment} is not currently allocated to outer-rim postings. Budget code: RESTRICTED ASSET CLASS.",
    f"Equipment allocation for {loc} was finalized prior to deployment. Amendments require authorization from Dept. {dept2}, which has not been granted.",
    f"The specialist consultation you've requested requires a referral from MasTema. Mammona cannot initiate MasTema referrals. This is by design.",
])}

Alternative: we can expedite delivery of {fallback_equipment}. Please confirm if this is acceptable.

-- Supply & Logistics
Mammona Mining Corporation""")

        entries.append(f"""**FROM:** {manager_first} {manager_last}, Site Manager
**TO:** Supply & Logistics, Dept. {dept}
**RE:** RE: RE: Priority Equipment Requisition -- Ref {req_ref}
**CLASSIFICATION:** Restricted

With respect: {fallback_equipment} will not address the situation at {site}.

I am filing this request a fourth time. I am also filing a formal safety concern (Form 19-A) and a personnel risk assessment (Form 22-D). The situation at {loc} constitutes a {R(["Class II environmental hazard", "Category B anomalous exposure risk", "personnel safety emergency under Article 7 of the Colony Charter"])}.

If this equipment is not provided within {RI(7, 21)} days, I will be forced to suspend operations at {site}. I understand the contractual implications. I accept them.

-- {manager_first} {manager_last}""")

        entries.append(f"""**FROM:** Supply & Logistics, Dept. {dept}
**TO:** {manager_first} {manager_last}, Site Manager
**RE:** Partial Approval -- Ref {req_ref}
**CLASSIFICATION:** Internal

Partial approval granted. The following has been dispatched:

1. {fallback_equipment}
2. One (1) {R(["junior safety officer", "medical technician", "equipment calibration specialist"])} (ETA: {RI(3, 8)} weeks)

The {equipment} remains unavailable. Your Form 19-A has been received and is under review. Estimated review timeline: {RI(6, 18)} months.

Please note: suspension of operations at {site} will trigger a contract compliance review for all personnel at {loc}. This is not a threat. This is policy.

-- Supply & Logistics
Mammona Mining Corporation
*"Building Tomorrow's Foundation"*""")

        entries.append(f"""**FROM:** {tech_first} {tech_last}, {R(["Safety Officer", "Equipment Specialist"])}
**TO:** {manager_first} {manager_last}, Site Manager
**RE:** Arrival and Assessment -- {loc}
**CLASSIFICATION:** Internal

{manager_last}:

I arrived yesterday. I've reviewed the situation at {site}.

I need to be direct: the equipment they sent me with is not relevant to what's happening here. {R([
    "The atmospheric filters are for a chemical hazard. This is not a chemical hazard.",
    "My training covers standard safety protocols. What I'm seeing does not fall under standard safety protocols.",
    "The calibration tools they issued are for Mammona-standard equipment. Several systems here have components I cannot identify.",
])}

I believe the partial approval was not intended to address the problem. I believe it was intended to demonstrate that the problem was being addressed. There is a difference.

I would like to request a transfer. I would also like to request that you not file this memo. If it enters the system, I will not get the transfer.

-- {tech_first} {tech_last}""")

    elif variant == "safety_audit":
        # Safety audit response: corporate sends audit form -> site responds with real data -> corporate rejects data -> site resubmits sanitized version -> corporate approves -> whistleblower addendum
        auditor_first, auditor_last, _ = ctx.fresh_name()
        audit_ref = f"SA-{RI(1000, 9999)}"

        entries.append(f"""**FROM:** Safety & Compliance Division
**TO:** Site Management, {loc}
**RE:** Annual Safety Audit -- Ref {audit_ref}
**CLASSIFICATION:** Internal / Mandatory Response

This is your annual safety audit notification for {loc}. Please complete and return Form 31-A (Site Safety Assessment) within 14 business days.

Areas of assessment:
- Personnel injury and fatality rates
- Equipment failure logs
- Environmental hazard incidents
- Psychological wellness indicators
- Emergency protocol compliance

Note: failure to submit within the deadline will result in automatic classification of {loc} as 'compliant.' This is not a favorable outcome. It means we stop asking.

-- Safety & Compliance Division
Mammona Mining Corporation""")

        entries.append(f"""**FROM:** {manager_first} {manager_last}, Site Manager
**TO:** Safety & Compliance Division
**RE:** RE: Annual Safety Audit -- Ref {audit_ref} -- HONEST VERSION
**CLASSIFICATION:** Restricted

Submitting Form 31-A with actual figures:

- Personnel injuries: {RI(14, 30)} (reported: {RI(3, 7)})
- Fatalities: {RI(2, 5)} (reported: {RI(0, 1)})
- Equipment failures: {RI(20, 45)} incidents, {RI(6, 12)} involving {R(["unexplained system behavior", "autonomous equipment operation", "readings inconsistent with physical reality"])}
- Environmental hazards: {R(["ongoing, unclassifiable", "present, worsening, defying standard categorization", "active -- see attached incident reports that were rejected by Regional"])}
- Psychological wellness: {RI(40, 70)}% of personnel displaying symptoms consistent with {R(["chronic stress disorder", "anomalous exposure syndrome", "sustained environmental trauma"])}
- Emergency protocol compliance: protocols are followed. Protocols do not cover what is happening here.

I know this form will be rejected. I'm submitting it anyway. The record should exist somewhere, even if that somewhere is a rejection file.

-- {manager_first} {manager_last}""")

        entries.append(f"""**FROM:** Safety & Compliance Division
**TO:** {manager_first} {manager_last}, Site Manager
**RE:** RE: RE: Annual Safety Audit -- Ref {audit_ref}
**CLASSIFICATION:** Internal

{manager_last}:

Form 31-A has been returned for revision. The following issues were identified:

1. Fatality and injury figures exceed the statistical model for a site of {loc}'s profile. Please verify data entry.
2. The term "{R(["unclassifiable", "autonomous", "anomalous"])}" is not a recognized category in Form 31-A. Please select from the approved dropdown options.
3. Environmental hazard descriptions must use standardized language per Appendix C. "Defying standard categorization" is not in Appendix C.

Please resubmit within 7 business days using approved terminology and verified figures.

-- Safety & Compliance Division""")

        entries.append(f"""**FROM:** {manager_first} {manager_last}, Site Manager
**TO:** Safety & Compliance Division
**RE:** RE: RE: RE: Annual Safety Audit -- Ref {audit_ref}
**CLASSIFICATION:** Internal

Resubmitting Form 31-A with approved terminology and figures that fit the statistical model.

- Personnel injuries: {RI(3, 7)}
- Fatalities: {RI(0, 1)}
- Equipment failures: {RI(4, 8)} (routine wear)
- Environmental hazards: none (within parameters)
- Psychological wellness: adequate
- Emergency protocol compliance: full

These numbers are not true. You know they are not true. I know you know. This form is not a safety assessment. It is a liability document. I understand that now.

Please file it.

-- {manager_first} {manager_last}""")

        entries.append(f"""**FROM:** Safety & Compliance Division
**TO:** Site Management, {loc}
**RE:** Audit Complete -- Ref {audit_ref}
**CLASSIFICATION:** Internal

Form 31-A accepted. {loc} is classified as COMPLIANT for the current audit cycle.

Congratulations on maintaining safety standards. A certificate of compliance will be included in the next supply drop.

-- Safety & Compliance Division
Mammona Mining Corporation
*"Your Safety Is Our Priority"*""")

        # Whistleblower addendum (50% chance of inclusion)
        if random.random() > 0.5:
            entries.append(f"""**ADDENDUM** (found attached to a printed copy of the above, taped to the inside of a maintenance panel in Section {section}):

The real numbers are in {manager_last}'s first submission -- Ref {audit_ref}, version 1. It was rejected. It will always be rejected. The system is not broken. The system is working as designed. The design does not include the truth.

{RI(2, 5)} people are dead. {RI(8, 20)} are injured. The rest of us are changing.

If you find this, do not file a report. Reports go to Mammona. Mammona already knows.

-- [{R(["unsigned", "illegible", "a name that does not appear on the colony roster"])}]""")

    return entries


def _datapad_unsent_letters(ctx, tone, first, last, g, gl, gp, go, loc):
    """Unsent letters home. 4 structural variants to avoid repetition across batches."""
    recipient_first, _, _ = ctx.fresh_name()
    brand = R(BRAND_NAMES) if BRAND_NAMES else "Sunny Fizz"
    job = R(JOBS)
    prev_loc = ctx.pick_fresh(LOCATIONS_FLAT, "LOCATIONS_FLAT")

    variant = R(["classic", "angry", "practical", "apologetic"])

    if variant == "classic":
        return _unsent_classic(ctx, tone, first, last, g, gl, gp, go, loc,
                               recipient_first, brand, job, prev_loc)
    elif variant == "angry":
        return _unsent_angry(ctx, tone, first, last, g, gl, gp, go, loc,
                             recipient_first, brand, job, prev_loc)
    elif variant == "practical":
        return _unsent_practical(ctx, tone, first, last, g, gl, gp, go, loc,
                                 recipient_first, brand, job, prev_loc)
    else:
        return _unsent_apologetic(ctx, tone, first, last, g, gl, gp, go, loc,
                                  recipient_first, brand, job, prev_loc)


def _unsent_classic(ctx, tone, first, last, g, gl, gp, go, loc,
                    recipient_first, brand, job, prev_loc):
    """Variant 1 -- Hope deteriorating to desperation."""
    entries = []

    # Entry 1: Hope (randomized)
    opener_pool = [
        f"I made it. {R(['The shuttle was fourteen hours late', 'The transit was rough -- two people got sick in cryo', 'Landing was ugly, but the hull held'])} and I'm here. {loc}.",
        f"Writing this from the bunk. First night. {loc} is {R(['colder than the briefing suggested', 'exactly what I expected, which is the problem', 'real now, not just a name on a contract'])}.",
        f"The shuttle touched down at {R(['0400', '0600', '2200'])} and {loc} was waiting. {R(['Grey. Quiet. Cold.', 'Wind like a blade. Ice like a mirror.', 'Smaller than the brochure. Colder than the warning.'])}",
    ]
    colony_detail = R([
        f"The colony is smaller than the briefing suggested. {RI(15, 40)} people, maybe.",
        f"There's about {RI(20, 50)} of us. The {brand} machine works. That's the highlight.",
        f"Met the shift lead. {R(['Quiet type.', 'Barely looked at me.', 'Said welcome like it was an apology.'])}",
    ])
    entries.append(f"""{recipient_first},

{R(opener_pool)} {R(["It's cold. I knew it would be cold. I wasn't ready.", "The pay is real and the contract is signed.", "I keep telling myself this is temporary."])} In {RI(8, 18)} months I'll be back with enough credits to {R(["clear the debt", "start over", "get us out"])}.

{colony_detail} I've got a bunk, a locker, and {R(["a view of ice in every direction", "nothing resembling a window", "a ceiling low enough to touch"])}.

{R(["Miss you.", "I'll write again soon.", "Thinking of you."])}

-- {first}

[{R(["This letter was found folded inside a maintenance manual.", "Found tucked into a boot.", "Discovered in a locker during reassignment."])} It was never sent.]""")

    # Entry 2: Doubt
    quiet_detail = R([
        f"the quiet between the hours that's different. On {prev_loc} the quiet was just quiet. Here it has a texture.",
        f"the way the walls feel closer at night. Not physically. But my body thinks so.",
        f"the sound the generator makes at 0300. Like it's breathing. Machines don't breathe.",
    ])
    entries.append(f"""{recipient_first},

{R(["I started three versions of this. Deleted them.", "I don't know how to write this letter.", "I've been carrying this blank page for a week."])} {R(["The first was too honest. The second was too cheerful.", "Everything I write sounds like a lie or a cry for help.", "The words I need don't exist in the language we share."])}

Work's fine. I'm a {job} here{R([', same as ' + prev_loc, '', ', for now'])}. {R(["The hours are long but the hours were always long.", "I've done worse for less.", "The routine helps."])} It's {quiet_detail}

{R(["That sounds crazy. I'm not crazy.", "I know how this reads. I'm fine.", "Don't worry about me."])} I'm just {R(["tired and far away", "adjusting", "learning the shape of this place"])}.

-- {first}

[{R(["Found between the mattress and the bunk frame.", "Folded into the back of a photograph.", "Slipped inside a ration wrapper."])} Unsent.]""")

    # Entry 3: Fear
    entries.append(f"""{recipient_first},

{R(["Don't come here.", "I need you to stay where you are.", "Promise me you won't follow me."])} {R([
    "I know we talked about it -- you joining me after the first rotation. Don't.",
    "Whatever plan we had, forget it. Stay where you are.",
    "If anyone offers you a contract for " + loc + ", tear it up.",
])} Stay on {R(["Novaris-3", "Rhea-2", "Karnaith"])}. Stay where there's {R(["sunlight and noise", "people who sleep through the night", "gravity that feels honest"])}.

{ctx.fresh_sensory(tone)}

Something is wrong with this place. {R([
    "I can't tell you what because I don't have words for it yet.",
    "Not broken-wrong. Alive-wrong. Like the ground knows I'm standing on it.",
    "The kind of wrong that doesn't show up on instruments but your bones know.",
])} {R([
    "It's not the cold, it's not the work, it's not Mammona. It's underneath all of that.",
    "Everyone here feels it. Nobody says it. That silence is louder than the drill.",
    "I wake up at the same time every night and the walls are humming.",
])}

I'm fine. {R(["I want you to know that.", "That's the official version.", "For now."])}

-- {first}

[{R([
    "Found in the recycling queue. Never sent.",
    "Recovered from a sealed envelope in the waste processor.",
    "Found crumpled in the pocket of a jacket left on a hook.",
])}]""")

    # Entry 4: Acceptance
    feature_detail = R([
        "the walls hum at a frequency that isn't on any diagnostic chart",
        "HERMES says good morning in a voice that almost but doesn't quite sound like a person",
        "the perimeter lights flicker at 0200 every night like something is testing them",
        "I can hear my own heartbeat when I walk past Section D",
        "the coffee tastes different depending on which corridor I drink it in",
    ])
    entries.append(f"""{recipient_first},

{R([
    "I stopped counting the days. Not because I gave up. Because the days stopped being countable.",
    "Time moves differently here. I don't mean metaphorically. The clocks disagree with each other.",
    "I've been here long enough that 'here' has stopped feeling like a place and started feeling like a state of being.",
])}

I've made peace with some things. The cold. The food. The way {feature_detail}. {R([
    "These are just facts now. Features of the landscape.",
    "I've stopped fighting it. That's not the same as accepting it.",
    "You learn to live inside the strangeness. Or the strangeness learns to live inside you.",
])}

{R([
    "I love you. I think about you in the mornings before the shift starts.",
    "I still remember your face. That's what I hold onto.",
    "You're the only real thing left. Everything else here is approximation.",
])}

-- {first}

[Found hidden inside a {brand} can with the top carefully cut and resealed. Never sent.]""")

    # Entry 5: The one that says too much
    final_options = [
        f"""{recipient_first},

I know what's underneath. {R([
    "I've known for a while. I think everyone here knows.",
    "Mammona knows. They've always known. The contract is a leash, not a lifeline.",
    "The drill isn't looking for resources. It's looking for something else.",
])} {R([
    "Saying it would make it real, and real things have to be dealt with.",
    "I can't write it down. Writing it down makes it permanent.",
    "The words exist but putting them in order would break something.",
])}

{R([
    "Burn this letter. Burn all of them. Forget my name if you must.",
    "Don't look for me. If I come back, I'll find you. If I don't, remember me as I was.",
    "I love you more than I'm afraid. That has to be enough.",
])}

-- {first}

[{R([
    "This letter was found inside the lining of a jacket. The bunk was made. The locker was empty. Contract status: ACTIVE.",
    "Found folded into a paper crane on the observation deck windowsill. Facing outward.",
    "Discovered sealed inside a wall panel during renovation. The panel had not been opened in years.",
])}]""",
    ]
    entries.append(R(final_options))

    return entries


def _unsent_angry(ctx, tone, first, last, g, gl, gp, go, loc,
                  recipient_first, brand, job, prev_loc):
    """Variant 2 -- Resentful, shifting to protective. Short, clipped sentences."""
    entries = []

    # Entry 1: Resentment
    entries.append(f"""{recipient_first},

{R([
    "You knew. You knew what this place was and you let me sign.",
    "The recruiter smiled when I signed. Same smile you had.",
    "I'm here because of you. Let's not pretend otherwise.",
])} {loc}. {R([
    "It's exactly as bad as the rumors said. Worse, actually, because the rumors were optimistic.",
    "Cold doesn't begin to cover it. Cold is a season. This is a condition.",
    "The brochure should just say 'we're sorry' and leave it at that.",
])}

{R([
    "Don't write back. I won't read it.",
    "I'm not looking for sympathy. I'm looking for an explanation.",
    "This isn't a letter. It's a receipt.",
])}

-- {first}

[{R(["Found crumpled near the recycler.", "Torn in half, then taped back together.", "Written on the back of a Mammona safety pamphlet."])}]""")

    # Entry 2: Grudging detail
    entries.append(f"""{recipient_first},

{R([
    "Fine. I'll tell you what it's like since you asked. You didn't ask. I'm telling you anyway.",
    "I said I wouldn't write again. I lied. I'm good at that. Learned from the best.",
    "Another letter I won't send. These are becoming a habit.",
])}

{R([
    f"The work is {job}. Same thing I did on {prev_loc} except here the equipment is older and the people are quieter.",
    f"I work the {R(['day', 'night', 'double'])} shift. The food is NutriLoaf. The coffee is brown water. The {brand} machine is the best thing here.",
    f"My bunkmate doesn't talk. I respect that. Talking requires having something to say.",
])}

{ctx.fresh_sensory(tone)}

{R([
    "The anger is fading. I don't know what's replacing it. Something heavier.",
    "I'm starting to understand why you did it. That makes it worse.",
    "This place has a way of making grudges feel small.",
])}

-- {first}

[Unsent. {R(["Folded neatly.", "Edges worn from handling.", "Ink smudged."])}]""")

    # Entry 3: Shift toward concern
    entries.append(f"""{recipient_first},

{R([
    "Something happened last night that I can't explain to anyone here.",
    "I'm not angry anymore. I'm scared. Those are different.",
    "I need to say this before whatever is happening to me finishes happening.",
])}

{R([
    f"Don't come to {loc}. I know I said I didn't want to hear from you. I'm saying something different now. Don't come here.",
    f"If Mammona offers you a contract -- any contract, any posting -- don't take it. Walk away. Run if you must.",
    f"Stay away from anything connected to {loc}. Anything. Anyone who mentions it. Any company that operates near it.",
])}

{ctx.fresh_sensory(tone)}

{R([
    "The anger was easier. The anger made sense. What I'm feeling now doesn't have a name.",
    "I can't protect you from here. This letter is the closest I can get.",
    "I was wrong to blame you. I was wrong about a lot of things. I'm right about this: stay away.",
])}

-- {first}

[{R(["Found in a boot, tightly rolled.", "Hidden behind a wall panel.", "Tucked into a medical kit."])}]""")

    # Entry 4: Something breaking
    entries.append(f"""{recipient_first},

{R([
    "I've been thinking about what I'd say if I saw you. The list changes every day.",
    "The person who wrote that first letter -- the angry one -- I don't recognize them anymore.",
    "I forgive you. That's not generosity. I just don't have room for it anymore.",
])}

{R([
    "This place takes things from you. Not all at once. A little each day. Things you didn't know you had until they're gone.",
    f"I used to dream about {prev_loc}. Now I dream about corridors I've never walked. They feel more real than the ones I walk every day.",
    "The colony is changing. Or I'm changing. The difference is academic.",
])}

{R([
    "If I said I loved you it would sound like goodbye. So I won't.",
    "You were the last person I was angry at. Now I'm not angry at anyone. That should feel like progress.",
    "I miss the version of me that could be angry about small things.",
])}

-- {first}

[{R(["Unsent. Ink faded.", "Found pressed between pages of a maintenance manual.", "Discovered during bunk reassignment."])}]""")

    # Entry 5: Final -- protective warning
    entries.append(f"""{recipient_first},

{R([
    f"This is the last one. Not because I'm done writing. Because writing these letters is the last honest thing I do here and I need to stop before {loc} takes that too.",
    "I don't have much time. Not in the dramatic sense. In the sense that I can feel myself becoming someone who wouldn't write this letter. So I'm writing it now.",
    "You won't understand this letter. That's the point. If you understood it, it would mean you'd been here. And you can't come here.",
])}

{R([
    "Whatever you hear about me -- about this posting, about what happened here -- believe the version where I was trying to protect you. That's the true one.",
    "I'm leaving this where someone will find it. Not for you. For whoever comes next. So they know that someone here was still trying.",
    "If my name shows up on a manifest or a report or a memorial, don't look into it. Remember me from before. The before-version was better.",
])}

{R([
    "I'm sorry. For the anger and for everything after it.",
    "Take care of yourself. That's not a platitude. It's the only thing I have left to give.",
    "Goodbye, " + recipient_first + ". The word feels different when you mean it.",
])}

-- {first}

[{R([
    "Found inside the hull plating near an airlock. The writer had to remove two bolts to place it there.",
    "Recovered from a sealed envelope addressed to a transit hub that no longer exists.",
    "This letter was found. The writer was not.",
])}]""")

    return entries


def _unsent_practical(ctx, tone, first, last, g, gl, gp, go, loc,
                      recipient_first, brand, job, prev_loc):
    """Variant 3 -- Logistics and updates that become coded messages. Clinical becoming cryptic."""
    entries = []
    section = R(["A", "B", "C", "D", "E", "F"])

    # Entry 1: Practical update
    entries.append(f"""{recipient_first},

{R([
    "Posting update. Contract terms as discussed.",
    "Status report. You asked me to keep you informed.",
    "Quick note before the comms window closes.",
])} {R([
    f"Arrived {loc}, Day 1. Assigned {job}. Hab {RI(1, 16)}, bunk {R(['upper', 'lower'])}.",
    f"Transit complete. {loc} is operational. My assignment is {job}, Section {section}.",
    f"On site. Equipment functional. Personnel: {RI(18, 45)} total. My shift is {R(['06-14', '14-22', '22-06'])}.",
])}

{R([
    f"Rations adequate. {brand} available. Medical on site. Standard Mammona package.",
    f"Facilities are basic but serviceable. Generator runs steady. Water recycler operational.",
    f"Living conditions match the contract spec. Barely.",
])}

{R([
    "Will update next cycle.",
    "More when I know more.",
    "End of report.",
])}

-- {first}

[{R(["Found in outgoing mail, unstamped.", "Recovered from a data pad, draft folder.", "Written on regulation paper. Never filed."])}]""")

    # Entry 2: Details with edges
    entries.append(f"""{recipient_first},

{R([
    "Follow-up to previous. Some observations.",
    "Week two. Adjusting to the routine.",
    "Continuing the record as agreed.",
])}

{R([
    f"Inventory discrepancy: manifest lists {RI(40, 80)} crates, I count {RI(35, 75)}. Difference unaccounted for. Quartermaster says normal variance. Normal variance is 2%. This is {RI(6, 15)}%.",
    f"Section {section} access restricted as of Day {RI(5, 12)}. No memo. No announcement. The door just locked. I asked. Nobody asked.",
    f"Night shift reports sounds from the bore shaft between 0200-0400. Maintenance says drill harmonics. The drill doesn't run at night.",
])}

{ctx.fresh_sensory(tone)}

{R([
    "Noting for the record.",
    "I'm keeping my own counts now. Separate ledger.",
    "Something here doesn't add up. That might be the point.",
])}

-- {first}

[Unsent.]""")

    # Entry 3: Coded observations
    entries.append(f"""{recipient_first},

{R([
    "Read this carefully.",
    "The following is accurate. Interpret accordingly.",
    "I'm going to describe what I see. What I mean is something else.",
])}

{R([
    f"The weather has been stable. [There are no weather patterns inside a colony.] The garden is growing well. [There is no garden.] The neighbors are friendly. [The word 'friendly' is doing a lot of work in that sentence.]",
    f"Equipment inspection passed on all counts. [I was not permitted to inspect Section {section}.] All personnel accounted for. [Define 'accounted for.'] Morale is adequate. [Mammona's word, not mine.]",
    f"The mail system is functioning normally. [These letters aren't going through the mail system.] I'm in good health. [By the standards of this posting, everyone is in good health until they aren't.] Work continues. [The nature of the work has changed. I can't say how.]",
])}

{R([
    "If you understand what I'm not saying, you'll know what to do.",
    "Read between the lines. Then burn the lines.",
    "I trust you to hear what I can't write.",
])}

-- {first}

[{R([
    "Found folded into a complex pattern -- specific folds appear intentional, possibly encoding additional information.",
    "Written in two colors of ink. The color changes correspond to no obvious pattern.",
    "Margins contain numbers that don't match any colony reference system.",
])}]""")

    # Entry 4: The mask slipping
    entries.append(f"""{recipient_first},

{R([
    "I've been writing these like reports because reports are safe. Reports have structure. What's happening doesn't have structure.",
    "I can't keep doing this in code. Either you understand or you don't. Here it is plain.",
    "The practical format was a coping mechanism. The mechanism is failing.",
])}

{ctx.fresh_sensory(tone)}

{R([
    f"Mammona is not mining {loc}. I don't know what they're doing. I know it requires people. I know the people don't always leave. I know the books are wrong in ways that are too precise to be accidental.",
    f"I've been documenting everything. Times, dates, inventory numbers, personnel movements. The pattern is there. I can see it. What I can't see is the reason. The reason is underground.",
    f"Three people have 'transferred' since I arrived. The shuttle hasn't come. Nobody questions this. I questioned it once. The look I got was the most honest communication I've had on this posting.",
])}

{R([
    "I need you to remember everything I've written. If something happens, the details matter.",
    "Keep these letters. Keep them somewhere safe. They're evidence of something.",
    "I'm done being careful. Careful people disappear quietly.",
])}

-- {first}

[{R(["Found in a waterproof container buried outside the perimeter.", "Hidden inside a modified data pad with a false back.", "Sealed in an envelope addressed to a law firm that went bankrupt three years ago."])}]""")

    # Entry 5: Final -- the document itself is the message
    entries.append(f"""{recipient_first},

{R([
    f"Attached to this letter you will find nothing. The attachment was removed. By me. Before I hid this. The attachment is in a different location. If you're reading this, contact the following and say my name: {R(FACTION_NAMES)}.",
    f"I've stopped writing reports and started writing instructions. Step one: do not come to {loc}. Step two: contact {R(FACTION_NAMES)}. Step three: give them the number on the back of this letter. Step four: forget my name. Step five: there is no step five. You'll understand when you get to step four.",
    f"This letter is the last piece of a set. If you have all of them, you have coordinates. Not in the text. In the paper. I folded them. The creases are a map. I learned that trick from someone here. Someone who was here before us. Someone who left this way because it was the only way to leave.",
])}

{R([
    "I love you. That's not code for anything. It's the one true sentence in all of these letters.",
    "Don't mourn me yet. Don't celebrate either. Just remember.",
    "Whatever happens next, I was here. I saw it. These letters prove it.",
])}

-- {first}

[{R([
    "This letter was found in a sealed container welded to the underside of a cargo pod. The weld was professional. The container was waterproof, fireproof, and bore no markings.",
    "Found inside a hollowed-out copy of a Mammona employee handbook. Pages 47-52 had been replaced with this letter and four pages of numbers.",
    "Recovered from the personal effects of " + first + " " + last + ". Effects were found. " + first + " was not.",
])}]""")

    return entries


def _unsent_apologetic(ctx, tone, first, last, g, gl, gp, go, loc,
                       recipient_first, brand, job, prev_loc):
    """Variant 4 -- Writer is hiding something they did. Each letter tries to confess but can't."""
    entries = []

    # Entry 1: Casual, but something is off
    entries.append(f"""{recipient_first},

{R([
    "Hey. I know it's been a while.",
    "I should have written sooner. I don't have a good excuse.",
    "I owe you a letter. I owe you more than that.",
])} {R([
    f"I'm on {loc} now. New posting. Clean start. That's what I'm calling it.",
    f"{loc}. Different planet, same job, same Mammona. Different me. Maybe.",
    f"I took a contract on {loc}. I had reasons. The reasons made sense at the time.",
])}

{R([
    "There's something I need to tell you. Not in this letter. In the next one. I promise.",
    "I've been rehearsing a conversation with you in my head. The rehearsal always goes badly.",
    "I'll explain everything. Soon. When I find the right words.",
])}

-- {first}

[{R(["Found under a pillow.", "Tucked into a locker door hinge.", "Written on the back of a shift schedule."])} Never sent.]""")

    # Entry 2: Getting closer to the truth, then retreating
    entries.append(f"""{recipient_first},

{R([
    f"I said I'd explain. I'm going to try. Bear with me.",
    f"Okay. Here goes. The reason I left {prev_loc} --",
    f"You deserve the truth. I'm going to give you the truth. Starting now.",
])}

{R([
    f"When I was on {prev_loc}, I did something. Not something illegal. Something worse than illegal. Something that I can't take back and can't make right and can't explain without you looking at me the way I look at myself.",
    f"Before I shipped out, there was a choice. Not a big dramatic choice. A quiet one. The kind where you pick the easy option and tell yourself it was the only option. It wasn't. I knew it wasn't. I picked it anyway.",
    f"Remember when I said I had to leave {prev_loc} because of the contract? That was true. The part I left out was why the contract was the only option left.",
])}

{R([
    "I can't finish this sentence. I've tried four times.",
    "I was going to tell you everything. I got to the hard part and stopped.",
    "The next letter. I'll say it in the next letter.",
])}

{ctx.fresh_sensory(tone)}

-- {first}

[Unsent. {R(["Edges torn, as if partially destroyed then reconsidered.", "Written in pencil, parts erased and rewritten.", "Multiple crossed-out lines visible."])}]""")

    # Entry 3: Deflection through describing the colony
    entries.append(f"""{recipient_first},

{R([
    "I know I said I'd tell you. I will. But first let me tell you about this place.",
    "Not ready yet. Instead, let me describe where I am. So you can picture it.",
    "I'm stalling. I know I'm stalling. Let me stall a little longer.",
])}

{R([
    f"{loc} is the kind of place that makes you understand why Mammona pays what it pays. {RI(15, 40)} people, one generator, and enough ice to bury a city. The {brand} machine is the closest thing to joy.",
    f"The colony runs on routine. Wake, work, eat, sleep. The routine keeps the thinking at bay. I've become very fond of routine.",
    f"I work as a {job}. The work is honest. That's more than I can say for the person doing it.",
])}

{ctx.fresh_sensory(tone)}

{R([
    "I'll tell you soon. I mean it this time.",
    "The thing I need to say is getting heavier. I carry it everywhere.",
    "Every letter I write that doesn't contain the truth makes the truth harder to tell.",
])}

-- {first}

[{R(["Unsent. Folded but not sealed.", "Found in a stack of blank paper, as if hidden.", "Written on both sides. The second side is almost illegible."])}]""")

    # Entry 4: Almost there
    _breach_type = R(["containment breach", "shaft collapse", "contamination", "evacuation failure"])
    _consequence = R(["admitting what I'd been doing", "losing everything", "prison -- or worse"])
    entries.append(f"""{recipient_first},

{R([
    f"Okay. No more stalling. What I did on {prev_loc}:",
    f"You need to know this. Even if you hate me after.",
    f"I'm going to write it fast, before I lose the nerve again.",
])}

{R([
    f"I knew about the {_breach_type}. Before it happened. I had the data. I could have warned people. I didn't, because warning them would have meant explaining how I got the data, and explaining that would have meant {_consequence}.",
    f"Someone trusted me with something on {prev_loc}. Information. The kind that could have saved people. I traded it. Not for credits. For a transfer. For survival. My survival. Not theirs.",
    f"I left someone behind. On {prev_loc}. Not by accident. By choice. They were counting on me and I calculated the odds and I walked away. The math was right. The math is always right. The math doesn't account for the sound they made when they realized I wasn't coming back.",
])}

{R([
    "There. I said it. I can't unsay it.",
    "That's what I've been carrying. Now you're carrying it too. I'm sorry for that.",
    "I keep hoping that writing it down will make it lighter. It doesn't.",
])}

-- {first}

[{R(["Written in a single sitting. No corrections. No hesitation marks.", "The pen pressed hard enough to score the paper beneath.", "Found sealed with wax. The seal was never broken."])}]""")

    # Entry 5: Final -- the confession completed
    entries.append(f"""{recipient_first},

{R([
    f"I told you the what. Here's the why: there is no why. I was scared and selfish and alive and those three things together are the whole explanation.",
    f"The previous letter was the confession. This one is the part where I stop pretending that confession makes it better.",
    f"You know now. What you do with it is up to you. I have no right to ask for forgiveness. So I'm asking for something smaller: remember that I told you. Not everyone would.",
])}

{R([
    f"{loc} is the right place for someone like me. A posting at the end of the line for a person who ran out of line. The cold here matches something inside.",
    f"I thought coming to {loc} would be penance. It isn't. Penance requires someone to forgive you. Nobody here knows what I did. I'm just another colonist with a past they don't talk about.",
    f"I've stopped expecting to feel better. That's not self-pity. It's accuracy.",
])}

{R([
    "If these letters ever reach you, know that the person who wrote them was trying. Failing. But trying.",
    "I love you. I know that doesn't fix anything. It's still true.",
    "Don't come looking for me. Not because of the danger. Because the person you'd find isn't the person you remember.",
])}

-- {first}

[{R([
    "This letter was found with four others, bundled with string, hidden in the wall cavity behind a bunk. The bunk was unassigned. The cavity was not on any schematic.",
    "Recovered from a sealed data pad. The pad's encryption key was the recipient's name. The recipient has been contacted. They declined to comment.",
    "Found in the personal effects of " + first + " " + last + ". Status: " + R(["transferred", "missing", "contract terminated -- reason: unspecified"]) + ".",
])}]""")

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
        f"aware of things. Things {pgl} shouldn't be aware of. {pg} knew about the supply ship delay before comms received the update",
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

    # Wire NPCs into a relationship web after all pieces are generated
    wire_relationships(ctx)

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

    # World generation order: locations, factions, NPCs, then wire relationships,
    # then quests (so quests can reference wired relationships), then datapads.
    pre_wire_plan = [
        ("location", 2),
        ("faction", 1),
        ("npc", 4),
    ]
    post_wire_plan = [
        ("quest", 2),
        ("datapad", 3),
    ]

    for gen_type, count in pre_wire_plan:
        if gen_type not in GENERATORS:
            continue
        for _ in range(count):
            content, label, gtype = generate_piece(
                gen_type=gen_type, ctx=ctx, tone=tone, planet=planet, era=era,
            )
            if content is not None:
                pieces.append((content, label, gtype))

    # Wire NPCs into a relationship web before generating quests
    wire_relationships(ctx)

    for gen_type, count in post_wire_plan:
        if gen_type not in GENERATORS:
            continue
        for _ in range(count):
            content, label, gtype = generate_piece(
                gen_type=gen_type, ctx=ctx, tone=tone, planet=planet, era=era,
            )
            if content is not None:
                pieces.append((content, label, gtype))

    # Fill remaining types if available
    planned_types = {p[0] for p in pre_wire_plan + post_wire_plan}
    for gen_type in GENERATORS:
        if gen_type not in planned_types:
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

    if args.diverge:
        proposals = propose_divergences(ws)
        if not proposals:
            print("No divergences could be proposed from current state.")
            return
        # Save to pending file
        pending_path = Path(__file__).parent / "pending_divergences.json"
        # Merge with existing pending if any
        existing_pending = []
        if pending_path.exists():
            try:
                with open(pending_path, "r", encoding="utf-8") as f:
                    existing_pending = json.load(f)
            except (json.JSONDecodeError, OSError):
                existing_pending = []
        all_pending = existing_pending + proposals
        with open(pending_path, "w", encoding="utf-8") as f:
            json.dump(all_pending, f, indent=2, ensure_ascii=False)
        # Also write to proposals dir for human review
        review_path = PROPOSALS_DIR / f"divergences_{time.strftime('%Y%m%d_%H%M%S')}.json"
        with open(review_path, "w", encoding="utf-8") as f:
            json.dump(proposals, f, indent=2, ensure_ascii=False)
        print(f"Proposed {len(proposals)} divergence(s). Review and use --commit <id> to apply.")
        for p in proposals:
            print(f"  {p['id']}: {p['description']}")
        print(f"\nPending file: {pending_path}")
        print(f"Review copy:  {review_path}")
        return

    if args.commit:
        commit_divergence(ws, args.commit)
        return

    if args.revert:
        revert_divergence(ws, args.revert)
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
                if args.auto_diverge and batch_count % 25 == 0:
                    auto_proposals = propose_divergences(ws)
                    for ap in auto_proposals:
                        ap["auto"] = True
                        ap["committed_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
                        ws.data["divergences"].append(ap)
                        print(f"  [DIVERGE] {ap['id']}: {ap['description']}")

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
