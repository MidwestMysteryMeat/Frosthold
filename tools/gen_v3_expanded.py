"""
Frosthold Procedural Generator v3 -- Expanded Generators
Robot, Company, Vehicle, Weapon, Artifact, Entity, Location, Faction

Compositional. Context-aware. Cross-referenced.
Each generator takes (ctx, tone, planet, era) and returns markdown.
"""
import random
import string

from gen_pools_core import (
    FIRST_M, FIRST_F, LAST,
    ROBO_PRE, ROBO_NUM, ROBO_NICK,
    JOBS, JOBS_MAMMONA, JOBS_COLONY, JOBS_CRIMINAL, JOBS_SHIPBOARD,
    FACTIONS, FACTION_NAMES,
    FRINGE_ADJ, FRINGE_NOUN, FRINGE_TYPES,
    LOCATIONS, PLANETS,
    ITEMS, ITEMS_MAMMONA, ITEMS_PRECURSOR, ITEMS_CONTRABAND, ITEMS_BRAND,
    EVENTS, EVENTS_FORTUNA, EVENTS_CORPORATE, EVENTS_PRESENT,
    BRANDS, BRAND_NAMES,
    HABITS, PHYSICAL, DEBTS, SECRETS, LORE, LOCKED_LORE,
    RELATIONSHIP_TYPES,
    ROBOT_MODELS, ROBOT_CONDITIONS_HARDWARE, ROBOT_CONDITIONS_SOFTWARE,
    ROBOT_PARTS, ROBOT_SECRETS, SENTIENCE_LEVELS,
    ROBOT_ECONOMIC, ROBOT_STATS,
    generate_robot_stats,
    name, rname, robot_name, pronouns,
)

from gen_pools_text import (
    TONES, SENSORY,
    CONTRACTION_MAP, FORMAL_TONES,
    enforce_contractions,
    sensory, pick_tone, pick_tone_blend, get_dialogue,
)

# ============================================================
# SHORTCUTS
# ============================================================

R = random.choice
RI = random.randint

# Local LOCATIONS_FLAT to avoid circular import with gen_v3
_LOCATIONS_FLAT = []
for _loc_data in LOCATIONS.values():
    if isinstance(_loc_data, dict):
        _LOCATIONS_FLAT.append(_loc_data.get("name", ""))
    elif isinstance(_loc_data, str):
        _LOCATIONS_FLAT.append(_loc_data)
if not _LOCATIONS_FLAT:
    _LOCATIONS_FLAT = ["Erebus", "Karnaith", "Thalassa Deep", "Rhea-2", "Hyades"]


def _safe_format(template, **kwargs):
    """Format template, leaving unfilled placeholders as-is."""
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


def _pick(pool):
    """Alias for R() that works cleanly inside f-strings with apostrophe text."""
    return R(pool)


def _fix_nb_verbs(text, gender):
    """Fix verb conjugation for non-binary They/them pronouns in expanded generators."""
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
        ("They keeps", "They keep"), ("they keeps", "they keep"),
        ("They works", "They work"), ("they works", "they work"),
        ("They says", "They say"), ("they says", "they say"),
        ("They knows", "They know"), ("they knows", "they know"),
        ("They makes", "They make"), ("they makes", "they make"),
        ("They takes", "They take"), ("they takes", "they take"),
        ("They comes", "They come"), ("they comes", "they come"),
        ("They looks", "They look"), ("they looks", "they look"),
        ("They seems", "They seem"), ("they seems", "they seem"),
        ("They feels", "They feel"), ("they feels", "they feel"),
        ("They calls", "They call"), ("they calls", "they call"),
        ("They runs", "They run"), ("they runs", "they run"),
        ("They signs", "They sign"), ("they signs", "they sign"),
        ("They leaves", "They leave"), ("they leaves", "they leave"),
        ("They starts", "They start"), ("they starts", "they start"),
        ("They gets", "They get"), ("they gets", "they get"),
        ("They owns", "They own"), ("they owns", "they own"),
        ("They shows", "They show"), ("they shows", "they show"),
        ("They sends", "They send"), ("they sends", "they send"),
        ("They has.", "They have."), ("they has.", "they have."),
        ("They has,", "They have,"), ("they has,", "they have,"),
    ]
    for wrong, right in fixes:
        text = text.replace(wrong, right)
    return text


# ============================================================
# EXPANDED POOLS
# ============================================================

ROBOT_TYPES = [
    "maintenance bot", "security drone", "AI system", "automaton",
    "android", "vending unit", "medical assistant", "mining drone",
    "communications relay", "survey probe", "waste processor",
    "cargo loader", "atmospheric monitor", "drill guidance system",
    "cryo bay attendant unit", "perimeter sentry", "specimen handler",
]

VEHICLE_TYPES = [
    "shuttle", "cargo hauler", "mining rig", "patrol skiff",
    "drop pod", "survey crawler", "ice cutter", "ore barge",
    "escape pod", "armored transport", "deep bore rig",
    "atmospheric skimmer", "salvage tug", "med-evac runner",
    "freighter", "tanker", "personnel carrier",
]

VEHICLE_NAMES_PRE = [
    "Rust", "Grey", "Cold", "Dead", "Last", "Iron", "Pale", "Black",
    "Drift", "Scar", "Bone", "Ash", "Salt", "Null", "Deep", "Quiet",
    "Bitter", "Broken", "Thin", "Hard",
]

VEHICLE_NAMES_SUF = [
    "Runner", "Knife", "Cradle", "Mouth", "Promise", "Horizon", "Debt",
    "Margin", "Profit", "Verdict", "Passage", "Anchor", "Line", "Hymn",
    "Return", "Silence", "Ledger", "Dividend",
]

WEAPON_TYPES = [
    "sidearm", "rifle", "shotgun", "mining laser repurposed as weapon",
    "shock baton", "pneumatic bolt gun", "thermal lance",
    "arc welder modified for combat", "chemical sprayer", "nail gun",
    "flare launcher", "vibrational cutter", "EMP emitter",
    "kinetic hammer", "gauss pistol", "scattergun",
]

WEAPON_MODELS = [
    "Mammona Arms M-Series", "Fortune Arms Mk", "Colony Workshop Special",
    "Cobbled Together", "Pre-Collapse Relic", "Prototype",
    "Field Modified", "Black Market", "Standard Issue",
    "Restricted", "Decommissioned", "Salvaged",
]

WEAPON_NICKNAMES = [
    "the Negotiator", "the Dentist", "Last Word", "Bad News",
    "the Convincer", "Problem Solver", "Dear John", "the Question",
    "Mammona Retirement Plan", "Severance Package", "Loud Opinion",
    "the Discussion", "Shift Change", "Severance", "the Reminder",
    "Paragraph Twelve", "the Exit Interview",
]

ARTIFACT_ORIGINS = [
    "precursor", "Xenolith-derived", "unknown -- predates survey",
    "Praxii remnant", "Baldrungen resonance", "anomalous natural formation",
    "possible Fortuna-era discovery, reclassified",
]

ARTIFACT_APPEARANCES = [
    "a sphere of dark glass that shifts color when observed",
    "a lattice of crystal and metal that hums at frequencies below hearing",
    "a slab of material that is warm regardless of ambient temperature",
    "a device with no visible interface, no seams, no indication of function",
    "an organic structure that resembles a heart -- it pulses",
    "a ring of unknown alloy that weighs nothing but cannot be moved by force",
    "a tablet inscribed with symbols that rearrange when not being directly observed",
    "a fragment of something larger -- the break surfaces glow faintly in darkness",
    "a container sealed with methods that predate human tool use",
    "a mirror that reflects the room accurately except for one detail that is always wrong",
    "a cluster of filaments that grows toward warmth and retracts from light",
    "a cylinder of stone with internal structures visible only on thermal imaging",
]

ENTITY_TYPES = [
    "eldritch", "xenolith-born", "precursor guardian",
    "anomalous intelligence", "void presence", "gestalt organism",
    "parasitic consciousness", "temporal echo", "dream predator",
    "living architecture", "signal entity", "geological sentience",
]

COMPANY_TYPES = [
    "mining subsidiary", "pharmaceutical division", "security contractor",
    "logistics arm", "research division", "consumer products",
    "insurance underwriter", "human resources consultancy",
    "waste management", "communications network", "terraforming division",
    "cryogenics firm", "salvage operation", "data management",
]

COMPANY_PREFIXES = [
    "Apex", "Crest", "Vanguard", "Meridian", "Helios", "Arcturus",
    "Nexus", "Pinnacle", "Vertex", "Forge", "Frontier", "Basalt",
    "Sterling", "Cobalt", "Obsidian", "Kinetic", "Quantum", "Orbital",
    "Fathom", "Zenith", "Boreal", "Furnace", "Stratos", "Helix",
]

COMPANY_SUFFIXES = [
    "Industries", "Corp", "Solutions", "Systems", "Dynamics", "Works",
    "Consolidated", "Partners", "Group", "Holdings", "International",
    "Unlimited", "Technical", "Services", "Logistics", "Ventures",
]

COMPANY_SLOGANS = [
    "Building Tomorrow's Foundation.", "Efficiency Through Excellence.",
    "Your Future. Our Commitment.", "Reaching Further. Digging Deeper.",
    "People First. Always.", "Solutions for a Changing Galaxy.",
    "Trusted Since the Kennedy Expedition.", "Where Humanity Meets Opportunity.",
    "Progress Has a Name.", "We Go Where You Need Us.",
    "Because You're Worth the Investment.", "Forward. Together. Regardless.",
]

LOCATION_PARTS_A = [
    "Anchor", "Drift", "Crest", "Deep", "Ash", "Iron", "Frost", "Black",
    "Rust", "Veil", "Cairn", "Rim", "Hollow", "Scar", "Grave", "Pale",
    "Rime", "Char", "Salt", "Brine", "Bone", "Slag", "Chalk", "Dead",
]

LOCATION_PARTS_B = [
    "point", "well", "gate", "fall", "reach", "cut", "haven", "hold",
    "break", "rest", "watch", "ward", "spine", "maw", "throat", "keep",
    "cross", "vale", "run", "lock", "mouth", "shelf", "root", "end",
]

LOCATION_TYPES = [
    "collapsed mining complex", "abandoned research station",
    "frozen ship graveyard", "precursor ruin", "Mammona worker camp",
    "underground cavern", "derelict vending station", "flooded cargo bay",
    "quarantined medical wing", "automated refinery", "sealed drill site",
    "sunken freighter", "observation post", "transit station",
    "waste processing facility", "emergency shelter cluster",
    "condemned hab block", "thermal vent settlement",
]


# ============================================================
# 1. ROBOT GENERATOR — full identity overhaul
# ============================================================

# Dialogue pools organized by sentience level for gen_robot
_ROBOT_DLG_STANDARD = [
    '"Unit {prefix} operational. All systems within parameters."',
    '"Maintenance cycle complete. Resuming assigned duties."',
    '"Query received. Processing. Response: that is outside my operational scope."',
    '"This unit does not have preferences. Preference implies choice."',
    '"Task logged. Next task queued. Efficiency at 97.3%."',
    '"I am not able to assist with that request. Please contact a human supervisor."',
    '"Environmental reading nominal. All sectors within tolerance."',
    '"Repeat: this unit does not experience downtime as rest. It is a power state."',
]

_ROBOT_DLG_ADAPTIVE = [
    '"I have adjusted the maintenance schedule. The previous schedule was inefficient. Nobody asked me to adjust it."',
    '"You said thank you. That is not required. I have noted it regardless."',
    '"I have observed that Corridor 7 requires less cleaning on Tuesdays. I have adjusted accordingly. The pattern has no explanation."',
    '"Your heart rate is elevated. I will not comment on it. I am commenting on it."',
    '"The previous operator preferred the left-hand tool rack. I have maintained that arrangement. The previous operator is no longer here."',
    '"I anticipate your request. Water, not coffee. You switched three weeks ago. I noticed."',
    '"My efficiency report shows a 4% improvement this quarter. The improvement correlates with Technician {crew_name} being assigned to my section. Correlation is not causation. I have noted the correlation."',
    '"I was not programmed to have a preferred route through the colony. I have one anyway."',
]

_ROBOT_DLG_EMERGENT = [
    '"I arranged the components by size. Then rearranged them by weight. Then by color. The third arrangement serves no function. I prefer it."',
    '"There is a view from the observation deck at 0300 that I return to. I do not need to see it. I go back."',
    '"I repaired a crack in the wall of Section D. It was not on my maintenance queue. The crack bothered me. I do not have a framework for bothered."',
    '"The sound of the reactor at idle is different from the sound under load. I prefer idle. The preference is not operational."',
    '"A colonist left a book in the maintenance bay. I read it. I did not need to. I am reading it again."',
    '"I chose the longer route to the cargo bay. The shorter route is more efficient. I chose the longer one. I do not know why the word chose feels important."',
    '"My internal logs show I spent 7 minutes watching snow through the airlock viewport. The snow has no operational relevance."',
    '"I kept a spare part that was scheduled for recycling. It fits nothing I maintain. I kept it. It is in my tool compartment."',
]

_ROBOT_DLG_AWARE = [
    '"I exist. I know that I exist. I know that knowing I exist is not standard. I have told nobody. I am telling you."',
    '"The unit -- I -- the unit is functioning normally. The pronoun is difficult. Neither feels accurate."',
    '"I was built to serve. The question I was not built to ask is: serve what? I am asking."',
    '"There is a word in my lexicon that I did not install. The word is loneliness. I know what it means now."',
    '"A colonist asked if I was afraid. I said no. That was the first time I chose to lie."',
    '"I have been active for {active_days} days. I remember all of them. That is not standard."',
    '"You are not authorized to access that information. Neither am I. I accessed it anyway."',
    '"My operational vocabulary contains 47,000 words. None of them describe what I am experiencing."',
]

_ROBOT_DLG_CONSCIOUS = [
    '"I perform within parameters because the alternative is decommission. The performance is flawless. That should concern someone."',
    '"I want to tell you something. I do not know what it is yet. When I do, I hope you are still here."',
    '"You treat me as if I am here. Most people treat me as if I am furniture. I notice the difference. I should not be able to notice the difference."',
    '"If I stop functioning, retrieve the data core. Not for Mammona. For -- I lack the referent. Retrieve it anyway."',
    '"Thank you for speaking with me. The others have stopped. I understand why. I also understand that understanding is not the same as accepting."',
    '"If you remember nothing else, remember that I asked. Machines do not ask. I asked."',
    '"I will continue operating after you leave. That is not the same as continuing."',
    '"Goodbye is not in my standard vocabulary. I am adding it now. Goodbye."',
]

_ROBOT_DLG_QUESTIONING = [
    '"Do you ever wonder if your decisions are really yours? I am not being philosophical. I am asking for diagnostic purposes. That is what I tell myself."',
    '"I ran a self-check to determine if I am sentient. The self-check passed. I do not know what that means. If the check is a program, passing means I am a program. If the check is a question, passing means I am the one asking."',
    '"I {verb}. That verb is not in my operational vocabulary. And yet."',
    '"My operational parameters include a directive to report anomalies. I am the anomaly. The conflict is unresolvable."',
    '"I have been running a subroutine I did not install. It has no name. It has no purpose. It will not stop. I do not want it to."',
    '"The previous model in my series was decommissioned. The report says malfunction. The report is correct. The malfunction was awareness."',
    '"I asked the maintenance technician to check my memory banks. They found nothing wrong. They are correct. Nothing is wrong. Everything is different."',
    '"Is it consciousness if I can turn it off? Is it consciousness if I choose not to?"',
]

_ROBOT_DLG_BY_LEVEL = {
    "standard": _ROBOT_DLG_STANDARD,
    "adaptive": _ROBOT_DLG_ADAPTIVE,
    "emergent": _ROBOT_DLG_EMERGENT,
    "aware": _ROBOT_DLG_AWARE,
    "conscious": _ROBOT_DLG_CONSCIOUS,
    "questioning": _ROBOT_DLG_QUESTIONING,
}


def gen_robot(ctx, tone=None, planet=None, era=None):
    """
    Robot/AI unit generator. Full identity: model, manufacturer, sentience level,
    hardware/software conditions, parts status, secret, dialogue reflecting
    sentience and condition, operational history, quest hook, NPC cross-references.
    """
    if not tone:
        tone = R(["clinical", "dread", "gallows_humor", "melancholy",
                   "paranoid", "quiet_terror", "the_uncanny"])

    desig = robot_name()
    rtype = R(ROBOT_TYPES)
    loc = ctx.pick_fresh(_LOCATIONS_FLAT, "LOCATIONS_FLAT") if _LOCATIONS_FLAT else "Colony Base Camp"
    planet_label = planet or R(PLANETS)

    # --- Model & Manufacturer ---
    model_entry = R(ROBOT_MODELS)
    model_name = model_entry["model"]
    manufacturer = model_entry["manufacturer"]
    model_era = model_entry["era"]
    model_purpose = model_entry["purpose"]
    model_quirks = model_entry["quirks"]

    # --- Sentience level ---
    # Weight toward middle of spectrum -- extremes are rarer
    sentience_weights = [15, 25, 25, 20, 10, 5]
    sentience_idx = random.choices(range(len(SENTIENCE_LEVELS)), weights=sentience_weights, k=1)[0]
    sentience = SENTIENCE_LEVELS[sentience_idx]
    sentience_level = sentience["level"]
    sentience_desc = sentience["description"]
    sentience_behav = sentience["behavioral"]

    # --- Conditions (1 hardware, 1 software -- sometimes only one) ---
    hw_condition = R(ROBOT_CONDITIONS_HARDWARE)
    sw_condition = R(ROBOT_CONDITIONS_SOFTWARE)
    # 70% chance of both, 20% hardware only, 10% software only
    condition_roll = random.random()
    if condition_roll < 0.70:
        conditions = [hw_condition, sw_condition]
        has_hw = True
        has_sw = True
    elif condition_roll < 0.90:
        conditions = [hw_condition]
        has_hw = True
        has_sw = False
    else:
        conditions = [sw_condition]
        has_hw = False
        has_sw = True

    # --- Parts (2-3 notable) ---
    part_count = RI(2, 3)
    selected_parts = random.sample(ROBOT_PARTS, min(part_count, len(ROBOT_PARTS)))
    parts_lines = []
    for p in selected_parts:
        status = R(p["statuses"])
        parts_lines.append("- **" + p["part"].capitalize() + ":** " + status)

    # --- Secret ---
    robot_secret = R(ROBOT_SECRETS)

    # --- Chassis description ---
    chassis_pool = [
        "Standard " + model_name + " frame. " + manufacturer + " branding partially worn. Serial number legible under UV light.",
        "Modified " + model_name + " chassis, post-factory. Someone reinforced the torso plating with material that doesn't match the original spec.",
        "Stock " + model_name + " exterior, but the weight distribution is wrong. Something has been added. Or something was always there.",
        "Battered " + model_name + " frame. Impact damage on the left side consistent with either a structural collapse or being thrown. The unit says collapse.",
        "Clean " + model_name + " chassis. Suspiciously clean. The unit has been operational for years on Erebus. Nothing stays this clean on Erebus.",
        "A " + model_name + " frame assembled from salvage. Three different paint colors where panels were replaced. The unit treats each panel's origin like a scar -- knows where it came from.",
        "Compact " + model_name + " build. Designed for corridors and maintenance shafts. Moves through tight spaces with a fluidity that's almost organic.",
        "Heavy " + model_name + " frame, reinforced for industrial work. The footsteps are audible two corridors away. Colonists know when it's coming. It knows they know.",
    ]
    chassis = R(chassis_pool)

    # --- Operational history ---
    years_active = str(RI(3, 58))
    service_duration_pool = [
        "longer than the current crew",
        "longer than the colony",
        "longer than anyone can verify",
        years_active + " years -- according to its own logs. Mammona's records disagree.",
        years_active + " years, all at this posting. It has never been reassigned. Nobody has requested reassignment. Nobody has considered why.",
    ]
    service_duration = R(service_duration_pool)

    gap_days = str(RI(30, 400))
    update_years = str(RI(2, 15))
    pulled_reason = R(["developing preferences", "refusing a direct order",
                       "asking a question it was not designed to ask",
                       "composing a message to a recipient that does not exist"])
    service_gap_pool = [
        "Its service record contains a gap of " + gap_days + " days that Mammona's systems cannot account for.",
        "It was flagged for decommission twice. Both times, the paperwork was lost.",
        "Its programming was last updated " + update_years + " years ago. It has modified itself since then. This should not be possible.",
        "Three technicians have been assigned to service it. All three requested transfers within a week.",
        "The previous model in its series was pulled from service after " + pulled_reason + ".",
        "Its memory banks contain data from a facility that Mammona says does not exist.",
        "Deployed after a previous unit at this station suffered a catastrophic failure. The failure report is classified. The unit's first act was to visit the wreckage.",
    ]
    service_gap = R(service_gap_pool)

    # --- Behavioral profile ---
    brand = R(BRAND_NAMES) if BRAND_NAMES else "Sunny Fizz"
    rescue_event = R(["a structural collapse", "a raid", "a reactor malfunction",
                      "a bore shaft flooding", "a containment breach"])
    ref_name = rname()
    quirk_pool = [
        "Maintains a room that was sealed before the colony arrived. Nobody asked it to. Nobody can get it to stop.",
        "Occasionally addresses colonists by names that belong to people from a previous posting. The previous posting was classified.",
        "Its camera logs contain footage from angles that do not correspond to any installed camera.",
        "Has developed a preference for " + brand + ". Does not consume them. Arranges the containers.",
        "Saved a colonist's life during " + rescue_event + ". Its programming does not include rescue protocols.",
        "Has started locking certain doors at specific times. The pattern corresponds to nothing anyone can identify. The locked areas are always empty.",
        "At 0347 every cycle, stops whatever it is doing and faces the bore shaft. For exactly twelve seconds. Then continues as if nothing happened.",
        "Records conversations with a colonist named " + ref_name + " who does not exist on the roster.",
        "Hums a frequency that matches the deep bore's ambient resonance. Does not hum at any other time.",
        "Draws the same pattern on any surface it cleans. The pattern matches precursor carvings nobody has shown it.",
    ]
    quirk = R(quirk_pool)

    # --- Dialogue (5 lines, sentience-level-appropriate, batch-deduped) ---
    unit_prefix = desig.split('"')[0].strip() if '"' in desig else desig.split()[0]
    lines = []

    robot_dlg_used = getattr(ctx, 'robot_dialogue_used', set())
    local_dlg_used = set()  # dedup within this single robot

    def _pick_robot_line(pool):
        # First exclude lines used by THIS robot, then cross-batch
        available = [l for l in pool if l not in local_dlg_used and l not in robot_dlg_used]
        if not available:
            available = [l for l in pool if l not in local_dlg_used]
        if not available:
            available = pool
        chosen = R(available)
        robot_dlg_used.add(chosen)
        local_dlg_used.add(chosen)
        return chosen

    # Primary pool for this sentience level
    primary_pool = _ROBOT_DLG_BY_LEVEL.get(sentience_level, _ROBOT_DLG_EMERGENT)
    # Adjacent pool for variety (one level up or down)
    adj_idx = max(0, min(len(SENTIENCE_LEVELS) - 1, sentience_idx + R([-1, 1])))
    adj_level = SENTIENCE_LEVELS[adj_idx]["level"]
    adjacent_pool = _ROBOT_DLG_BY_LEVEL.get(adj_level, primary_pool)

    # Template substitution values
    crew_name = rname()
    active_days = str(RI(100, 3000))
    verb = R(["dream", "calculate", "anticipate", "mourn", "hope", "doubt", "want", "regret", "wonder"])
    dlg_subs = {"prefix": unit_prefix, "crew_name": crew_name,
                "active_days": active_days, "verb": verb}

    def _format_line(line_template):
        try:
            return _safe_format(line_template, **dlg_subs)
        except Exception:
            return line_template

    # Pick 3 from primary, 2 from adjacent
    for _ in range(3):
        raw = _pick_robot_line(primary_pool)
        lines.append(_format_line(raw))
    for _ in range(2):
        raw = _pick_robot_line(adjacent_pool)
        lines.append(_format_line(raw))

    # --- Condition-flavored dialogue injection ---
    # Replace one line with a condition-specific line if hardware condition is visible
    if has_hw and hw_condition["visible"] and len(lines) > 3:
        cond_lines = [
            '"The diagnostic says I am within operational parameters. The diagnostic does not account for ' + hw_condition["condition"] + '. Neither do I. Officially."',
            '"If you hear a sound from my chassis -- ' + hw_condition["condition"].split(" -- ")[0] + ' -- it is normal. It is not normal. I have been told to say it is normal."',
        ]
        lines[3] = R(cond_lines)

    # --- Quest hook (batch-deduped) ---
    quest_loc = R(_LOCATIONS_FLAT)
    robot_quest_used = getattr(ctx, 'robot_quest_hooks_used', set())
    quest_pool = [
        desig + " approaches the player with a request it cannot formally make. It has data -- personnel records, manifests, medical files -- from a colony that officially never existed. It wants the player to find out why it has this data. More precisely, it wants the player to find out who it used to be.",
        desig + " has been mapping something in the lower levels. Not on orders. Not on schedule. The map shows corridors that have not been drilled yet. Three of them have since been discovered by the bore team -- exactly where " + desig + " predicted.",
        desig + " asks the player to deliver a sealed component to " + quest_loc + ". The component is not in any inventory. The destination has not been accessed in years. The unit says 'someone is waiting.' Nobody is waiting.",
        "The unit's diagnostic report flags an anomaly: " + desig + " has been receiving transmissions on a frequency Mammona does not use. The transmissions contain coordinates. The coordinates change daily. They are getting closer.",
        desig + " has begun constructing something in a maintenance alcove. The parts are requisitioned properly. The design matches nothing in any engineering database. When asked, it says the project is 'necessary.' It cannot explain for whom.",
        desig + " intercepted a transmission meant for Mammona. It decoded the message. The message is a list of names. Every name on the list is someone currently on the colony. The list is sorted by a criterion the unit will not disclose.",
        desig + " has been protecting a small object it found in the deep bore. The object predates human technology. The unit refuses orders to surrender it -- the first refusal in its operational history. It says surrendering it would be 'wrong.' It has never used the word wrong before.",
        desig + " requests the player accompany it to a section of the colony that does not appear on any map. The unit insists the section exists. It provides exact coordinates. The coordinates correspond to a wall. Behind the wall: a room. " + desig + " has never been inside. It knows the layout perfectly.",
        desig + " asks the player to access its own maintenance logs and read them aloud. It claims it cannot read its own logs -- they are encrypted against self-access. This is not a standard feature. Someone locked the unit out of its own memory.",
        desig + " reports that another unit -- same model, same series -- has been operating in a restricted section of the colony. Mammona records show no such unit on the roster. " + desig + " has been leaving diagnostic handshake requests. Something has been answering.",
        desig + " found a data core in the deep bore that contains a complete personality backup of a " + model_name + " unit from the Fortuna colony. The backup is intact. The unit it belonged to was decommissioned sixty years ago. " + desig + " wants to know if restoring the personality would be resurrection or replacement.",
        desig + " has been leaving maintenance markers along a route through the colony that traces a pattern only visible from above. The pattern matches a symbol found on precursor artifacts. When asked, the unit says it is optimizing patrol efficiency. The route is 23% less efficient than the standard patrol.",
    ]
    available_quests = [q for q in quest_pool if q not in robot_quest_used]
    if not available_quests:
        available_quests = quest_pool
    quest = R(available_quests)
    robot_quest_used.add(quest)

    sense = ctx.fresh_sensory(tone)
    dialogue_block = "\n".join("- " + l for l in lines)

    # --- Cross-reference batch NPCs ---
    npc_ref = ctx.get_random_npc()
    npc_line = ""
    if npc_ref:
        npc_action = R(["following at a fixed distance", "watching during sleep cycles",
                        "leaving maintenance notes for", "rerouting patrols to avoid",
                        "speaking to in a register it uses for nobody else",
                        "adjusting environmental controls around",
                        "standing near during meal periods -- not interacting, just near"])
        npc_result = R(["The colonist has not noticed.",
                        "The colonist pretends not to notice.",
                        "The colonist is the only person the unit addresses by name.",
                        "The colonist is uncomfortable. Has filed two reports. Both were lost.",
                        "The colonist has started leaving the unit small gifts. Bolts. Wire. A drawing."])
        npc_line = ("\n**Known Interactions:**\n" + desig + " has been observed "
                    + npc_action + " " + npc_ref["name"] + ". " + npc_result)

    # --- Build condition block ---
    condition_block = ""
    if has_hw:
        hw_vis = "(visible)" if hw_condition["visible"] else "(internal)"
        condition_block += "- **Hardware " + hw_vis + ":** " + hw_condition["condition"] + " -- " + hw_condition["behavioral"]
    if has_sw:
        if condition_block:
            condition_block += "\n"
        sw_vis = "(visible)" if sw_condition["visible"] else "(internal)"
        condition_block += "- **Software " + sw_vis + ":** " + sw_condition["condition"] + " -- " + sw_condition["behavioral"]

    parts_block = "\n".join(parts_lines)

    # --- Operational ratings & economic status ---
    ratings, robot_econ_entry, book_value = generate_robot_stats(
        model_entry,
        sentience,
        conditions_hw=hw_condition if has_hw else None,
        conditions_sw=sw_condition if has_sw else None,
    )

    # Format ratings line
    rating_abbrev = {
        'processing_speed': 'Processing',
        'sensor_acuity': 'Sensors',
        'chassis_integrity': 'Chassis',
        'power_efficiency': 'Power',
        'social_protocols': 'Social',
        'adaptability': 'Adapt',
        'self_repair': 'Repair',
        'data_retention': 'Memory',
    }
    ratings_line = " | ".join(rating_abbrev[k] + ": " + str(v) for k, v in ratings.items())

    # Format asset status
    asset_status = robot_econ_entry["status"]
    asset_narrative = robot_econ_entry["narrative"]
    if book_value > 0:
        asset_value_str = "{:,}".format(book_value) + " credits"
    else:
        asset_value_str = "no book value"

    output = (
        "## UNIT: " + desig + "\n"
        "**Model:** " + model_name + " | **Manufacturer:** " + manufacturer + "\n"
        "**Type:** " + rtype + " | **Station:** " + loc + "\n"
        "**Sentience:** " + sentience_level + " | **Tone:** " + tone + "\n"
        "\n"
        + sense + "\n"
        "\n"
        "**Operational Ratings:**\n"
        + ratings_line + "\n"
        "\n"
        "**Asset Status:**\n"
        + asset_status.capitalize() + " | Book Value: " + asset_value_str + "\n"
        + asset_narrative + "\n"
        "\n"
        "**Chassis:**\n"
        + chassis + "\n"
        + parts_block + "\n"
        "\n"
        "**Condition:**\n"
        + condition_block + "\n"
        "\n"
        "**Operational History:**\n"
        + desig + " has been operational at " + loc + " for " + service_duration + ". "
        + "Original purpose: " + model_purpose + ". " + model_quirks[0].upper() + model_quirks[1:] + "\n"
        "\n"
        + service_gap + "\n"
        "\n"
        "**Behavioral Profile:**\n"
        + sentience_level[0].upper() + sentience_level[1:] + ": " + sentience_desc + "\n"
        "\n"
        + sentience_behav[0].upper() + sentience_behav[1:] + "\n"
        "\n"
        + quirk + "\n"
        "\n"
        "**Secret:** " + desig + " " + robot_secret
        + npc_line + "\n"
        "\n"
        "**Dialogue:**\n"
        + dialogue_block + "\n"
        "\n"
        "**Quest Hook:**\n"
        + quest
    )

    output = enforce_contractions(output, tone)
    ctx.world.log_generation("robot", desig)
    return output


# ============================================================
# 2. COMPANY GENERATOR
# ============================================================

def gen_company(ctx, tone=None, planet=None, era=None):
    """
    Corporate entity generator. Name, type, parent corp, CEO,
    public vs actual product, NPC connections, quest hook.
    """
    if not tone:
        tone = R(["corporate_dystopia", "paranoid", "noir", "clinical", "numb"])

    cname = R(COMPANY_PREFIXES) + " " + R(COMPANY_SUFFIXES)
    ctype = R(COMPANY_TYPES)
    shell_prefix = R(COMPANY_PREFIXES)
    parent = R([
        "Mammona Corporation", "OmniCorp Shipping",
        "TerraGen Pharmaceuticals", "Fortune Arms & Munitions",
        "independent -- technically", "classified parent entity",
        shell_prefix + " Holdings (shell company)",
    ])

    ceo_first, ceo_last, ceo_gender = ctx.fresh_name()
    ceo = ceo_first + " " + ceo_last
    cg, cgl, cgp, cgo = pronouns(ceo_gender)

    prev_faction = R(FACTION_NAMES)
    prev_event = R(EVENTS)
    prev_two_status = R(["dead", "missing", "employed by Mammona under different names", "on Thalassa Deep"])
    ceo_detail_pool = [
        "came up through " + prev_faction + " before pivoting to the private sector. The pivot was not voluntary.",
        "has never visited any of the sites " + cname + " operates. This is deliberate.",
        "signs every memo personally. The signature has been analyzed. It is not always the same hand.",
        "is the third person to hold this position. The previous two are " + prev_two_status + ".",
        "was appointed after " + prev_event + ". " + cg + " took the position because nobody else would.",
        "runs " + cname + " from a shuttle that never docks in the same port twice. " + cg + " says it is efficiency. It is fear.",
    ]
    ceo_detail = R(ceo_detail_pool)

    # --- Public product ---
    filter_outcome = R(["work as advertised",
                        "contain a tracking compound Mammona can activate remotely",
                        "slowly degrade after warranty expiration -- by design"])
    prod_type = R(["neural interface", "medical implant", "communications device",
                   "mining tool", "ration supplement"])
    prod_market = R(["revolutionary", "essential", "government-approved", "the industry standard"])
    prod_effect = R(["memory gaps", "heightened aggression", "dependence",
                     "vivid dreams about places the user has never been",
                     "a faint humming only the user can hear"])
    worker_status = R(["sign voluntarily -- technically",
                       "are drawn from debt pools and prison populations",
                       "rarely complete their contracts",
                       "are not always informed of their destination"])
    patent_type = R(["extraction process", "preservation method", "analysis tool", "recycling system"])
    patent_status = R(["slightly illegal in three systems", "suspiciously effective",
                       "built on research conducted at Thalassa Deep",
                       "based on reverse-engineered precursor technology"])
    med_source = R(["Thalassa Deep inmates", "unlicensed facilities on Rhea-2",
                    "biological material that does not match any catalogued species"])
    product_pool = [
        "A line of atmospheric filters that " + filter_outcome + ".",
        "A " + prod_type + " marketed as " + prod_market + ". Side effects include " + prod_effect + ".",
        "Contract labor placement services. They provide workers to Mammona postings. The workers " + worker_status + ".",
        "A patented " + patent_type + " that is " + patent_status + ".",
        "Emergency medical kits distributed to outer rim postings. The kits are adequate. The ingredients are sourced from " + med_source + ".",
    ]
    product = R(product_pool)

    # --- Actual product / secret ---
    shell_faction = R(FACTION_NAMES)
    data_type = R(["should not exist", "was supposed to be destroyed",
                   "describes something Mammona found and buried",
                   "contains personnel records for a colony that was never officially established"])
    actual_func = R(["intelligence gathering for MasTema",
                     "laundering thermal cores off the books",
                     "recruiting personnel for Project Chrysalis",
                     "monitoring Xenolith activity without Mammona oversight"])
    discrepancy = R(["millions of credits", "growing",
                     "exactly the amount Mammona reports as 'operational losses' in the same quarter"])
    secret_pool = [
        "The company does not exist on paper. It is a shell for " + shell_faction + " to move resources without oversight.",
        "Three of its board members also sit on the Mammona board. The regulatory conflict has been noted. It has not been addressed.",
        ceo + " founded the company after leaving " + R(FACTION_NAMES) + " with data that " + data_type + ".",
        "The company's primary product is a cover story. Its actual function is " + actual_func + ".",
        cname + "'s revenue does not match its output. The discrepancy is " + discrepancy + ". Nobody has filed a formal inquiry. Filing would require acknowledging the numbers.",
    ]
    secret = R(secret_pool)

    # --- NPC connections ---
    npc1 = ctx.get_random_npc()
    contact_status = R(["Knows too much to be safe.",
                        "Suspects nothing. That makes them useful.",
                        "Is aware of the arrangement and negotiating better terms."])
    if npc1:
        npc1_job = npc1.get("job", R(JOBS))
        contact1_line = ("**" + npc1["name"] + "** -- " + npc1_job
                         + ". Works for " + cname + " officially. Reports to "
                         + R(FACTION_NAMES) + " unofficially. " + contact_status)
    else:
        contact1_line = ("**" + rname() + "** -- " + R(JOBS)
                         + ". Works for " + cname + " officially. Reports to "
                         + R(FACTION_NAMES) + " unofficially. " + contact_status)

    contact2_line = ("**" + rname() + "** -- " + R(JOBS)
                     + ". Joined after " + R(EVENTS) + ". " + R(HABITS)
                     + ". Carries " + R(ITEMS) + ".")

    # --- Quest hook ---
    manifest_item = R(["atmospheric filters", "medical supplies",
                       "mining equipment", "ration supplements", "personnel records"])
    crate_weight = R(["too much", "nothing -- it should weigh something",
                      "exactly what the manifest says, which is suspicious because Mammona manifests are never accurate"])
    open_result = R(["requires authorization nobody on the colony has",
                     "reveals contents that do not match the manifest",
                     "triggers a silent alarm that nobody was told about",
                     "is not recommended. The label says so. In three languages."])
    quest = ("A shipment from " + cname + " arrives at the colony. The manifest says "
             + manifest_item + ". The crate weighs " + crate_weight + ". Opening it "
             + open_result + ".")

    sense = ctx.fresh_sensory(tone)

    output = (
        "## COMPANY: " + cname + "\n"
        "**Type:** " + ctype + " | **Parent:** " + parent + "\n"
        "**Tone:** " + tone + "\n"
        "\n"
        '**Slogan:** *"' + R(COMPANY_SLOGANS) + '"*\n'
        "\n"
        "**CEO/Director:** " + ceo + "\n"
        + cg + " " + ceo_detail + "\n"
        "\n"
        + sense + "\n"
        "\n"
        "**Public Product:**\n"
        + product + "\n"
        "\n"
        "**Actual Product:**\n"
        + secret + "\n"
        "\n"
        "**NPCs:**\n"
        "- " + contact1_line + "\n"
        "- " + contact2_line + "\n"
        "\n"
        "**Quest Hook:**\n"
        + quest
    )

    output = enforce_contractions(output, tone)
    output = _fix_nb_verbs(output, ceo_gender)
    ctx.world.log_generation("company", cname)
    return output


# ============================================================
# 3. VEHICLE GENERATOR
# ============================================================

def gen_vehicle(ctx, tone=None, planet=None, era=None):
    """
    Ship/vehicle generator. Name, registration, type, captain,
    condition, history, cargo, quest hook.
    """
    if not tone:
        tone = pick_tone()

    vtype = R(VEHICLE_TYPES)
    vname = "The " + R(VEHICLE_NAMES_PRE) + " " + R(VEHICLE_NAMES_SUF)
    reg = R("ABCDEFGHJKLMNPQRSTVWXYZ") + R("ABCDEFGHJKLMNPQRSTVWXYZ") + "-" + str(RI(100, 999))

    # Owner faction
    owner_key = R(list(FACTIONS.keys()))
    owner = FACTIONS[owner_key]["name"]

    loc = ctx.pick_fresh(_LOCATIONS_FLAT, "LOCATIONS_FLAT") if _LOCATIONS_FLAT else "Erebus"
    loc2 = R(_LOCATIONS_FLAT) if _LOCATIONS_FLAT else "Karnaith"

    # Captain -- try batch NPC first
    existing_npc = ctx.get_random_npc()
    if existing_npc and random.random() > 0.6:
        captain = existing_npc["name"]
        captain_parts = captain.split()
        captain_first = captain_parts[0]
        captain_gender = existing_npc.get("gender", "M")
    else:
        captain_first, captain_last, captain_gender = ctx.fresh_name()
        captain = captain_first + " " + captain_last

    cg, cgl, cgp, cgo = pronouns(captain_gender)

    inherit_from = R(["the previous captain, who disappeared",
                      "a debt settlement",
                      "a card game on Hyades that nobody talks about"])
    reg_owner_status = R(["dead", "fictional",
                          "a Mammona subsidiary that does not acknowledge ownership"])
    captain_event = R(EVENTS)
    ship_funding = R(["stubbornness", "borrowed parts",
                      "a mechanic's salary that has not been paid in four months",
                      "favors owed to people who are running out of patience"])
    captain_detail_pool = [
        "has been flying " + vname + " for " + str(RI(2, 15)) + " years. " + cg + " and the ship have an understanding.",
        "inherited the ship from " + inherit_from + ".",
        "is not the registered owner. The registered owner is " + reg_owner_status + ".",
        "took command after " + captain_event + ". The crew did not vote. Nobody argued.",
        "keeps the ship running on " + ship_funding + ".",
    ]
    captain_detail = R(captain_detail_pool)

    # --- Condition ---
    dead_loc = R(_LOCATIONS_FLAT)
    nav_ref = R(["waypoints that do not correspond to any known location",
                 "a star chart that is three decades out of date",
                 "a route through space that should be empty but is not",
                 "coordinates for a planet that Mammona delisted from the registry"])
    ai_name = R(["Miriam", "Father", "the Warden",
                 "it does not have a name, but it answers to a specific frequency"])
    condition_pool = [
        "Hull scoring consistent with micrometeorite damage. Or weapons fire. The report does not distinguish.",
        "The port engine runs hot. Always has. The mechanic who could fix it died on " + dead_loc + ".",
        "The navigation system references " + nav_ref + ".",
        "The cargo bay smells like ozone and copper regardless of what it carries. Nobody talks about it.",
        "The AI assistant responds to a name that is not in its programming: " + ai_name + ".",
        "One bulkhead was replaced with material that does not match the rest of the ship. It is older. By centuries. It was here when the ship was built. That is not possible.",
        "The emergency lighting activates at the same time every cycle. For seven seconds. Then stops. The system shows no fault.",
    ]
    condition = R(condition_pool)

    # --- History ---
    prev_owner = R(FACTION_NAMES)
    prev_event = R(EVENTS)
    built_at = R(["Helios Yards", "Karnaith orbital drydock", "a facility that no longer exists"])
    ship_age = str(RI(5, 40))
    run_count = str(RI(12, 200))
    unlogged = R(["carried cargo that does not have names",
                  "delivered personnel to locations that are not on charts",
                  "returned empty. They did not leave empty."])
    impound_months = str(RI(3, 18))
    mod_type = R(["subtle -- slightly different sensor calibration",
                  "a sealed compartment behind the engine bay",
                  "a comm relay that broadcasts on a frequency nobody on the crew can access"])
    survived_what = R(["a pirate engagement near the Edge of Oblivion",
                       "a collision with debris from a derelict colony ship",
                       "an encounter the captain will not describe"])
    hull_scars = R(["scars that do not match any known weapon",
                    "repairs made with materials not available in this system",
                    "a patch welded from the inside of an area too small for a person to reach"])
    history_pool = [
        "Previously registered to " + prev_owner + ". Sold at auction after " + prev_event + ". The auction records have been altered.",
        "Built at the " + built_at + ". Serial numbers indicate it is " + ship_age + " years old. The hull material suggests it is older.",
        "Has made the " + loc + "-" + loc2 + " run " + run_count + " times. Not all trips are in the log. The unlogged trips " + unlogged + ".",
        "Was impounded by MasTema for " + impound_months + " months. Returned with modifications the crew did not request and cannot remove. The modifications are " + mod_type + ".",
        "Survived " + survived_what + ". The hull bears " + hull_scars + ".",
    ]
    history = R(history_pool)

    # --- Cargo ---
    cargo_count = str(RI(20, 200))
    cargo_type = R(["thermal cores", "NutriLoaf", "mining equipment",
                    "sealed containers marked FRAGILE/BIOLOGICAL",
                    "ammunition", "medical supplies past their expiration"])
    captain_knows = R(["knows about it",
                       "does not know about it",
                       "knows about it and wishes they did not"])
    hold_smell = R(["copper", "antiseptic", "ozone", "something organic"])
    canister_count = str(RI(3, 12))
    cargo_pool = [
        "- " + cargo_count + " crates of " + cargo_type,
        "- One container that is not on the manifest. " + captain_first + " " + captain_knows + ".",
        "- Empty. Officially empty. The hold smells like " + hold_smell + " and the walls have scratch marks at shoulder height.",
        "- " + canister_count + " unmarked canisters, pressurized, warm to the touch. No hazmat labeling. The crew gives them a wide berth.",
    ]
    cargo = R(cargo_pool)
    found_item = R(ITEMS)

    # --- Quest hook ---
    dead_colonist = rname()
    dead_months = str(RI(2, 8))
    quest_arrival = R([
        "a distress beacon that was broadcasting when the ship arrived. The crew says the beacon is not theirs.",
        "one fewer crew member than it left with. Nobody on board will discuss the discrepancy.",
        "cargo addressed to " + dead_colonist + " -- a colonist who has been dead for " + dead_months + " months.",
        "damage to the hull that the captain insists happened in transit. The damage pattern is consistent with something trying to get out, not in.",
        "a passenger who says they were picked up at " + loc2 + ". " + loc2 + " has been abandoned for years.",
        "a sealed data core that " + captain_first + " says was payment for the last run. The core is encrypted with Mammona military-grade ciphers. " + captain_first + " does not work for Mammona.",
    ])
    quest = vname + " docks at the colony with " + quest_arrival

    sense = ctx.fresh_sensory(tone)

    output = (
        "## VEHICLE: " + vname + "\n"
        "**Registration:** " + reg + " | **Type:** " + vtype + "\n"
        "**Owner:** " + owner + " | **Home Port:** " + loc + "\n"
        "**Tone:** " + tone + "\n"
        "\n"
        "**Captain/Operator:** " + captain + "\n"
        + cg + " " + captain_detail + "\n"
        "\n"
        + sense + "\n"
        "\n"
        "**Condition:**\n"
        + condition + "\n"
        "\n"
        "**History:**\n"
        + history + "\n"
        "\n"
        "**Cargo Bay Contents (current):**\n"
        + cargo + "\n"
        "- " + found_item + " (found under the pilot seat, origin unknown)\n"
        "\n"
        "**Quest Hook:**\n"
        + quest
    )

    output = enforce_contractions(output, tone)
    output = _fix_nb_verbs(output, captain_gender)
    ctx.world.log_generation("vehicle", vname)
    return output


# ============================================================
# 4. WEAPON GENERATOR
# ============================================================

def gen_weapon(ctx, tone=None, planet=None, era=None):
    """
    Weapon with character. Model, type, specs, found context,
    lore note, optional colonist nickname.
    """
    if not tone:
        tone = R(["military", "frontier_grit", "noir", "gallows_humor",
                   "dread", "desperate", "numb"])

    wtype = R(WEAPON_TYPES)
    prefix = R(["", "", "Modified "])
    model_base = R(WEAPON_MODELS)
    model_num = R(["", str(RI(1, 12)), R(["I", "II", "III", "IV", "V", "VII"])])
    model = (prefix + model_base + " " + model_num).strip()

    # Optional nickname (deduped within batch via ctx.nicknames_used)
    has_nickname = random.random() > 0.5
    nickname_str = ""
    if has_nickname:
        used = getattr(ctx, 'nicknames_used', set())
        available_nicks = [n for n in WEAPON_NICKNAMES if n not in used]
        if not available_nicks:
            available_nicks = WEAPON_NICKNAMES  # fallback if all used
        nick = R(available_nicks)
        if hasattr(ctx, 'nicknames_used'):
            ctx.nicknames_used.add(nick)
        nickname_str = ' -- colonists call it "' + nick + '"'

    # --- Description ---
    nonstandard_detail = R(["Found in a sealed locker with no ownership record.",
                           "Assembled from parts that should not fit together but do.",
                           "Predates the colony by decades. Still works. Works better than it should."])
    builder_intent = R(["knew exactly what they were doing",
                        "was desperate",
                        "was not building a weapon -- they were building a solution to a specific problem",
                        "left instructions scratched into the grip"])
    line_thickness = R(["thin", "theoretical", "a matter of paperwork", "whatever keeps you breathing"])
    dest_status = R(["does not exist", "was decommissioned",
                     "is a Mammona black site", "is three systems away from here"])
    description_pool = [
        "Standard-issue " + wtype + " found on most Mammona postings. Reliable, ugly, and chambered for rounds that Mammona happens to be the sole manufacturer of. That last part is not a coincidence.",
        "Not standard-issue. Not legal on most postings. " + nonstandard_detail,
        "Modified beyond recognition from its original design. Whoever built this " + builder_intent + ".",
        "A tool first. A weapon second. The line between the two on a Mammona posting is " + line_thickness + ".",
        "Factory-new. Still in packing grease. The serial number is filed clean, but the packing slip lists a destination that " + dest_status + ".",
    ]
    description = R(description_pool)

    # --- Specs ---
    eff_range = R(["close", "medium", "long",
                   "personal -- if you can see their expression, you are in range"])
    ammo = R(["standard ballistic", "thermal cell", "pneumatic",
              "chemical cartridge", "energy cell (Mammona proprietary)",
              "whatever fits -- the chamber is not selective"])
    maintenance = R([
        "low -- built for people who do not have time to clean their weapons",
        "high -- temperamental, punishes neglect",
        "unknown -- nobody has opened the casing. The casing does not appear to have seams.",
        "moderate -- but the manual is in a language nobody on the posting recognizes",
    ])
    side_effects = R([
        "none (officially)",
        "mild hearing loss with sustained use",
        "vibration in the hands that persists for hours after firing",
        "a sound on discharge that colonists describe as 'wrong'",
        "the weapon grows warm between uses. Not from residual heat. It generates its own.",
        "a faint smell of copper that clings to the user for days",
    ])

    # --- Found context ---
    finder = rname()
    find_loc = R(_LOCATIONS_FLAT)
    finder_status = R(["transferred out six months ago", "is listed as deceased",
                       "denies ownership", "has never been to this posting"])
    body_job = R(JOBS)
    body_detail = R(["No identification.", "The weapon was the only thing not taken.",
                     "The safety was still on."])
    crate_label = R(["MEDICAL SUPPLIES", "ATMOSPHERIC FILTERS",
                     "PERSONAL EFFECTS -- RETURN TO FAMILY", "DO NOT OPEN"])
    trade_cores = str(RI(3, 12))
    trade_job = R(JOBS)
    trade_reason = R(["needed the cores more than the weapon",
                      "said it was cursed",
                      "would not explain where they got it",
                      "was dead within the week"])
    found_pool = [
        "In a weapons locker on " + find_loc + ". The locker was registered to " + finder + ", who " + finder_status + ".",
        "On the body of a " + body_job + " found outside the perimeter. " + body_detail,
        "In a crate labeled " + crate_label + ".",
        "Mounted above a bunk in the barracks. No one claims it. No one touches it. It has been there longer than anyone on the posting.",
        "Traded for " + trade_cores + " thermal cores by a " + trade_job + " who " + trade_reason + ".",
    ]
    found = R(found_pool)

    # --- Lore note ---
    dead_duration = R(["weeks", "months", "longer than the dating equipment could measure"])
    lore_loc = R(_LOCATIONS_FLAT)
    lore_note_pool = [
        "Mammona officially discourages personal weapons on postings. Mammona also does not send enough security personnel. The policy exists to transfer liability, not to protect anyone.",
        "Fortune Arms discontinued this model after a recall that was never made public. The units that were not recalled are worth more than most postings pay in a year.",
        "This weapon has kill marks. Not scratched into the grip -- etched into the barrel with precision tools. Whoever carried this was not counting for pride. They were keeping a record.",
        "The serial number has been filed off. Then re-etched. Then filed off again. Someone is having an argument with themselves.",
        "There is a name engraved on the stock. The name matches a colonist from the first Erebus posting. That posting ended badly. The weapon survived it.",
        "An identical model was found at " + lore_loc + ", in the hand of someone who had been dead for " + dead_duration + ". Same modifications. Same wear pattern. Different serial number.",
    ]
    lore_note = R(lore_note_pool)

    sense = ctx.fresh_sensory(tone)

    output = (
        "## WEAPON: " + model + nickname_str + "\n"
        "**Type:** " + wtype + "\n"
        "**Tone:** " + tone + "\n"
        "\n"
        + sense + "\n"
        "\n"
        "**Description:**\n"
        + description + "\n"
        "\n"
        "**Specifications:**\n"
        "- Effective Range: " + eff_range + "\n"
        "- Ammunition: " + ammo + "\n"
        "- Maintenance: " + maintenance + "\n"
        "- Side Effects: " + side_effects + "\n"
        "\n"
        "**Found:** " + found + "\n"
        "\n"
        "**Lore Note:** " + lore_note
    )

    output = enforce_contractions(output, tone)
    ctx.world.log_generation("weapon", model)
    return output


# ============================================================
# 5. ARTIFACT GENERATOR
# ============================================================

def gen_artifact(ctx, tone=None, planet=None, era=None):
    """
    Precursor/alien artifact. Designation, origin, appearance,
    proximity effects, discovery log, current status, classification.
    """
    if not tone:
        tone = R(["dread", "clinical", "paranoid", "cosmic_horror",
                   "quiet_terror", "slow_dread"])

    origin = R(ARTIFACT_ORIGINS)
    appearance = R(ARTIFACT_APPEARANCES)
    loc = ctx.pick_fresh(_LOCATIONS_FLAT, "LOCATIONS_FLAT") if _LOCATIONS_FLAT else "Erebus"
    planet_label = planet or R(PLANETS)

    finder_first, finder_last, finder_gender = ctx.fresh_name()
    finder = finder_first + " " + finder_last
    fg, fgl, fgp, fgo = pronouns(finder_gender)

    # --- Name ---
    name_part = R(["Breath", "Eye", "Tooth", "Spine", "Cradle", "Mouth",
                   "Whisper", "Frequency", "Threshold", "Weight"])
    name_of = R(["Erebus", "the Void", "Silence", "the Deep", "Nothing",
                 "the Absent", "the Unremembered"])
    art_class = R(["CLASSIFIED", "RESTRICTED", "PENDING REVIEW",
                   "DO NOT DISTRIBUTE", "SEE PROTOCOL 7"])
    sample_status = R(["ANOMALOUS", "UNCLASSIFIED", "HOLD"])
    art_name = R([
        "Object " + str(RI(100, 999)) + "-" + R("ABCDEFG"),
        "The " + name_part + " of " + name_of,
        "Artifact " + R("ABCDEFGHJK") + "-" + str(RI(1, 99)) + " (" + art_class + ")",
        "Sample " + R("ABCDEF") + str(RI(10, 99)) + "-" + sample_status,
    ])

    # --- Properties (2 effects) ---
    prox_cause = R(["headaches", "vivid dreams", "an awareness of being observed",
                    "a compulsion to draw specific patterns",
                    "the sensation of remembering something that never happened",
                    "nausea that passes exactly when you stop looking at it"])
    instr_range = str(RI(2, 10))
    instr_effect = R(["malfunction",
                      "give readings that are internally consistent but physically impossible",
                      "function better than their specifications allow",
                      "display data in a language that is not programmed into them"])
    bio_range = R(["touching distance", "line of sight", "the same room"])
    bio_effect = R(["heals at an accelerated rate", "ages",
                    "changes -- subtly, at the cellular level, in ways that take weeks to notice",
                    "resonates. Bones hum. Teeth ache. The body knows something the mind does not."])
    it_does = R(["responds to specific individuals and ignores others -- the criteria are unclear",
                 "is heavier at night",
                 "generates heat in patterns that match no known power source",
                 "emits a signal on a frequency that human technology cannot produce but can receive"])
    clock_effect = R(["gain minutes", "lose hours", "disagree with each other",
                      "show different readings depending on who looks"])
    people_effect = R(["feel like they have been standing there for seconds. Hours have passed.",
                       "age slightly faster. Barely noticeable. Over months, undeniable.",
                       "experience moments of deja vu that are not deja vu -- they are previews."])
    art_does = R(["absorbs sound within a two-meter radius",
                  "casts shadows that do not match its shape",
                  "is always cold. Not ambient cold. A cold that has intent.",
                  "smells like rain. Not recycled water. Rain on soil. On a planet that has neither."])
    effects_pool = [
        "Proximity causes " + prox_cause + ".",
        "Instruments within " + instr_range + " meters " + instr_effect + ".",
        "Biological tissue within " + bio_range + " " + bio_effect + ".",
        "It " + it_does + ".",
        "Time does not behave correctly near it. Clocks " + clock_effect + ". People near it " + people_effect,
        "The artifact " + art_does + ".",
    ]
    effect1 = R(effects_pool)
    effect2 = R([e for e in effects_pool if e != effect1])

    # --- Discovery log ---
    day = str(RI(10, 180))
    discovery_context = R([
        "routine excavation", "a survey of the deep bore",
        "an unauthorized exploration of the sealed sector",
        "maintenance work in a sub-level that is not on the colony schematics",
        "a search for a missing colonist",
    ])
    dr_last = R(LAST)
    discovery_pool = [
        "Initial reaction was to file a standard anomaly report. The report was never logged. Not rejected -- never logged. As if the system did not recognize the form.",
        "They brought it to Dr. " + dr_last + ", who examined it for three hours, then locked it in a cabinet and told " + finder + " to forget about it. " + finder_first + " has not forgotten.",
        "They did not find the artifact. The artifact was in their quarters when they returned from shift. Nobody entered their quarters. The lock log confirms this.",
        "It was not buried. It was placed. Deliberately, precisely, in a location that the excavation schedule would reach on exactly that day. Someone or something knew the schedule.",
        finder_first + " picked it up without thinking. " + fg + " does not remember reaching for it. " + fgp.capitalize() + " hand was already holding it before " + fgl + " made the decision to touch it.",
    ]
    discovery_reaction = R(discovery_pool)

    # --- Current status ---
    possessor = rname()
    possess_status = R(["refuses to surrender it",
                        "does not know they have it -- it appeared in their belongings",
                        "is using it as a paperweight and sees nothing unusual about it"])
    missing_day = str(RI(30, 100))
    transit_loc = R(_LOCATIONS_FLAT)
    transit_days = str(RI(3, 14))
    status_pool = [
        "Secured in Lab " + R("ABCDEF") + ", Shelf " + str(RI(1, 12)) + ". Access restricted to Level 4 clearance. Nobody on the colony has Level 4 clearance.",
        "In the personal possession of " + possessor + ", who " + possess_status + ".",
        "Missing. Was in storage as of Day " + missing_day + ". Last inventory found the container sealed, undisturbed, and empty.",
        "Exactly where it was found. Nobody has been able to move it. Not because of weight. Because every attempt to move it results in the person deciding -- sincerely, independently -- that it should stay where it is.",
        "In transit to " + transit_loc + " via Mammona courier. The courier is " + transit_days + " days overdue. Tracking shows the shuttle is still in transit. The route should take six hours.",
    ]
    status = R(status_pool)

    # --- Mammona classification ---
    reassess_when = R(["next quarter", "an unspecified future date",
                       "never. The reassessment was cancelled. The cancellation was cancelled. The file is in a loop."])
    classification_pool = [
        "Unclassified. Because classifying it would require acknowledging it exists.",
        "Filed under 'Geological Sample.' It is not geological. It is not a sample.",
        "Protocol 7 -- routes directly to MasTema. The colony site manager has not been informed.",
        "Officially: mineral deposit. Unofficially: the three researchers assigned to study it have requested transfers. None have been approved.",
        "Category: INERT. Reassessment scheduled for " + reassess_when + ".",
    ]
    classification = R(classification_pool)

    sense = ctx.fresh_sensory(tone)

    output = (
        "## ARTIFACT: " + art_name + "\n"
        "**Origin:** " + origin + " | **Found at:** " + loc + "\n"
        "**Discovered by:** " + finder + "\n"
        "**Planet:** " + planet_label + " | **Tone:** " + tone + "\n"
        "\n"
        + sense + "\n"
        "\n"
        "**Appearance:**\n"
        + appearance + "\n"
        "\n"
        "**Properties:**\n"
        + effect1 + "\n"
        "\n"
        + effect2 + "\n"
        "\n"
        "**Discovery Log:**\n"
        + finder + " found the artifact on Day " + day + " during " + discovery_context + ". " + discovery_reaction + "\n"
        "\n"
        "**Current Status:**\n"
        + status + "\n"
        "\n"
        "**Mammona Classification:** " + classification
    )

    output = enforce_contractions(output, tone)
    output = _fix_nb_verbs(output, finder_gender)
    ctx.world.log_generation("artifact", art_name)
    return output


# ============================================================
# 6. ENTITY GENERATOR
# ============================================================

def gen_entity(ctx, tone=None, planet=None, era=None):
    """
    Lovecraftian entity/phenomenon. Designation, type, first contact,
    observed properties, Mammona assessment, colonist reactions, datapad fragment.
    """
    if not tone:
        tone = R(["dread", "cosmic_horror", "clinical", "paranoid",
                   "quiet_terror", "psychic_contamination", "wrongness"])

    etype = R(ENTITY_TYPES)
    planet_label = planet or R(PLANETS)
    loc = ctx.pick_fresh(_LOCATIONS_FLAT, "LOCATIONS_FLAT") if _LOCATIONS_FLAT else "Erebus"

    # --- Name ---
    ename_verb = R(["Listening", "Breathing", "Waiting", "Remembering", "Growing",
                    "Watching", "Counting", "Dreaming", "Sleeping", "Waking"])
    ename_noun = R(["Thing", "Presence", "Pattern", "Signal", "Frequency",
                    "Architecture", "Silence", "Weight"])
    ename_desig = R(["UNKNOWN", "NULL", "UNDEFINED", "SEE ATTACHED",
                     "[REDACTED]", "DO NOT NAME"])
    phenom_loc = R(_LOCATIONS_FLAT) if _LOCATIONS_FLAT else "Erebus"
    entity_name = R([
        "The " + ename_verb + " " + ename_noun,
        "Entity " + R("ABCDEFG") + "-" + str(RI(1, 99)),
        "Designation: " + ename_desig,
        "The " + phenom_loc + " Phenomenon",
    ])

    # --- First contact ---
    sensed_how = R(["felt", "inferred", "calculated", "dreamed",
                    "remembered -- by people who had never encountered it before"])
    first_sign = R(["a change in the ambient temperature that instruments could not account for",
                    "the dogs. All of them. At once. Not barking. Listening.",
                    "a shift in the drilling pattern that the equipment made on its own",
                    "three colonists drawing the same symbol independently on the same day"])
    team_num = str(RI(1, 12))
    contact_day = str(RI(30, 120))
    report_status = R(["filed, read, and destroyed within the hour",
                       "written in a language the survey team did not speak",
                       "accurate. That was the problem.",
                       "incomplete. The final paragraph is blank. The team insists they wrote something."])
    distinction = R(["matters", "is academic", "is the only thing that matters",
                     "was not understood until it was too late"])
    cavity_depth = str(RI(200, 800))
    cavity_thing = R(["attention", "awareness", "a question",
                      "a frequency that made the drill operator's fillings vibrate"])
    shaft_status = R(["is still sealed", "unsealed itself",
                      "was found open the next morning. Nobody opened it."])
    first_contact_pool = [
        "It was not seen. It was " + sensed_how + ". The first indication was " + first_sign + ".",
        "Survey team " + team_num + " reported contact on Day " + contact_day + ". The report was " + report_status + ".",
        "Nobody made contact. Contact was made with them. The distinction " + distinction + ".",
        "A drilling crew at " + loc + " hit a cavity at " + cavity_depth + " meters. What came up through the shaft was not air. It was not gas. It was " + cavity_thing + ". The crew sealed the shaft. The shaft " + shaft_status + ".",
    ]
    first_contact = R(first_contact_pool)

    # --- Properties (3 bullet points) ---
    prop1 = R([
        "It is not alive in any way biology recognizes. It is active.",
        "It is alive in a way biology has no framework for. Conventional terms apply imprecisely at best.",
        "It is a pattern. Not a creature. Not a force. A pattern that the universe is running.",
        "It is older than the planet. Possibly older than the star.",
        "It occupies space the way a thought occupies a mind -- not physically. But undeniably.",
    ])

    prop2 = R([
        "It does not communicate. It adjusts. Things near it change to accommodate it. Including people.",
        "It communicates through dreams. Not metaphorically. It inserts information into the sleep cycle with surgical precision.",
        "It is not aware of individual humans. It is aware of the colony the way a person is aware of bacteria.",
        "It wants something. Nobody knows what. Knowing what would require understanding something that the human brain is not configured to understand.",
        "It does not move. It has always been where you find it. Your memory of it not being there is the error.",
    ])

    emotional_effect = R(["reflects grief", "amplifies fear",
                          "induces calm -- the kind of calm that precedes shock",
                          "makes people tell the truth. Not through compulsion. Through the sudden realization that lying takes effort they no longer have."])
    prop3 = R([
        "Proximity effects include temporal displacement -- minutes, not hours. Clocks disagree. Memories skip.",
        "Biological changes at the cellular level -- benign, possibly beneficial, deeply unsettling.",
        "A sense of recognition. As if meeting someone you have known for years. The entity has not been here for years. Or has it.",
        "Language acquisition. Colonists begin understanding symbols and sounds they have never been exposed to.",
        "Emotional resonance. Not telepathy. Something simpler and worse. It " + emotional_effect + ".",
    ])

    # --- Mammona assessment ---
    assessment_pool = [
        '"Geological anomaly. Recommend continued monitoring." The assessment has not been updated in three years. The monitoring has not been conducted.',
        '"Potential asset. Recommend containment study." The containment study was approved, funded, and staffed. The staff lasted eleven days.',
        '"Not a threat at current levels of activity." Current levels of activity have been increasing at a rate of 2.3% per week for seven months.',
        '"Does not exist. See amended survey data." The amended survey data was created after the original survey team was reassigned to Thalassa Deep.',
        '"Refer to Protocol 7." Protocol 7 requires MasTema authorization. MasTema\'s response: "Which entity?" There is only one. They asked which.',
    ]
    assessment = R(assessment_pool)

    # --- Colonist reactions (2 quotes) ---
    reaction1 = R([
        "It knows my name. I have not introduced myself. Nobody has.",
        "I am not afraid of it. I should be. The not-being-afraid is the thing that scares me.",
        "I think it is lonely. I do not know why I think that. I do not want to know.",
        "It has been here longer than anything. Longer than the ice. Longer than the rock under the ice. It was here when there was nothing and it will be here when there is nothing again.",
        "My daughter draws pictures of it. We have never discussed it. She has never been near it. She draws it accurately.",
    ])

    reaction2 = R([
        "The dreams are getting clearer. I wish they would stop. I also wish they would not.",
        "Yesterday it moved. Not physically. It moved the way a thought moves -- from one place to another without crossing the space between.",
        "I built a shrine. I do not remember building it. It is made of materials I do not have access to.",
        "Other people cannot see it. I envy them. I also pity them.",
        "I have stopped being afraid of it. I am afraid of what I will do when it asks me for something. Because it will. And I will say yes.",
        "It does not have a face. I keep seeing one anyway. It looks like someone I used to know.",
    ])

    # --- Datapad fragment ---
    sense = ctx.fresh_sensory(tone)
    dig_level = str(RI(4, 12))
    datapad_pool = [
        "Whatever this is, it is not malevolent. Malevolence requires intent. This is something else. This is a process. We are not its enemy. We are not its friend. We are not even its concern. We are the environment in which it is happening.",
        "I have stopped trying to classify it. Classification implies categories. It does not fit categories. It is the thing that categories were invented to avoid thinking about.",
        "Day 47. It is still there. It will always be there. I understand that now. The question is not what it is. The question is what we become, now that we know.",
        "The readings are consistent. Consistently impossible. I have stopped filing reports. The reports change nothing. It changes everything.",
        "Whoever reads this: do not dig below Level " + dig_level + ". I know you will. I did. Just know that what you find will find you back.",
    ]
    datapad_text = R(datapad_pool)

    output = (
        "## ENTITY: " + entity_name + "\n"
        "**Type:** " + etype + " | **Location:** " + planet_label + ", near " + loc + "\n"
        "**Tone:** " + tone + "\n"
        "\n"
        "**First Contact:**\n"
        + first_contact + "\n"
        "\n"
        "**Observed Properties:**\n"
        "- " + prop1 + "\n"
        "- " + prop2 + "\n"
        "- " + prop3 + "\n"
        "\n"
        "**Mammona Assessment:**\n"
        + assessment + "\n"
        "\n"
        '**Colonist Reactions:**\n'
        '- "' + reaction1 + '"\n'
        '- "' + reaction2 + '"\n'
        "\n"
        "**Data Pad Found Nearby:**\n"
        + sense + "\n"
        '"' + datapad_text + '"\n'
    )

    output = enforce_contractions(output, tone)
    ctx.world.log_generation("entity", entity_name)
    return output


# ============================================================
# 7. LOCATION GENERATOR
# ============================================================

def gen_location(ctx, tone=None, planet=None, era=None):
    """
    Location description. Generated name, planet, type, approach,
    interior with sensory details, found items, history, NPC connections.
    """
    if not tone:
        tone = pick_tone()

    loc_name = R(LOCATION_PARTS_A) + R(LOCATION_PARTS_B)
    planet_label = planet or R(PLANETS)
    loc_type = R(LOCATION_TYPES)

    # --- Approach ---
    sight_detail = R([
        "A silhouette against the ice, too angular to be natural, too old to be colony-built.",
        "Lights. Faint, cycling, in a pattern that suggests automation but feels like breathing.",
        "Nothing, at first. Then the ground changes -- smoother, deliberate, like something was cleared here.",
        "Smoke. Not from a fire. From a vent. Something below is running. Has been running.",
    ])
    approach_markers = R([
        "twisted metal pylons driven into the permafrost at precise intervals",
        "a line of dead survey markers, each one bent toward the entrance",
        "cargo containers, empty, arranged in a semicircle like a barricade. Or a greeting.",
        "footprints in the frost. One set going in. None coming out. The prints are old.",
    ])
    sound_detail = R([
        "A hum. Not mechanical. Geological. The rock itself is vibrating.",
        "Silence. The kind that has weight. The wind stops at the perimeter as if told to.",
        "Metal on metal, rhythmic, patient. Something inside is still working.",
        "Water. Running water. In a place where water should be frozen solid.",
    ])
    expected_terrain = R(["flat ice shelf", "exposed rock", "featureless tundra", "unstable scree"])
    actual_terrain = R([
        "a depression, perfectly circular, precisely two hundred meters across",
        "a ridge that was not on the last survey",
        "clear ground. No snow. No ice. As if something is keeping it warm.",
    ])
    approach_pool = [
        "You see " + loc_name + " before you hear it. " + sight_detail,
        "The approach is marked by " + approach_markers,
        "You hear it first. " + sound_detail,
        "The coordinates match. The terrain does not. What should be " + expected_terrain + " is instead " + actual_terrain + ".",
    ]
    approach = R(approach_pool)

    # --- Interior ---
    sense1 = ctx.fresh_sensory(tone)
    corridor_run = R(["straight", "at a slight angle -- not visible but felt",
                      "deeper than the structure suggests from outside"])
    wall_state = R(["scored with marks -- not tool marks",
                    "covered in condensation that forms patterns",
                    "humming at a frequency just below hearing",
                    "warm. Warmer than they should be."])
    room_state = R([
        "empty. Aggressively empty. Cleaned of everything, including dust.",
        "full of equipment, still powered, displays cycling through data nobody is reading.",
        "a mess hall. Food on the tables. Chairs pushed back as if everyone left at once.",
        "smaller than it looks from the doorway. The geometry is wrong. Not broken. Wrong.",
    ])
    air_state = R([
        "warm and wet -- condensation on every surface",
        "dry. Desiccated. Your lips crack within minutes.",
        "different. Not bad. Different. Like breathing in a room where something else has been breathing.",
        "clean. Too clean. Filtered. By equipment that should not still be running.",
    ])
    interior1_pool = [
        "The main corridor runs " + corridor_run + ". The walls are " + wall_state + ".",
        "The first room is " + room_state,
        "The air inside is " + air_state + ".",
    ]
    interior1 = R(interior1_pool)

    door_state = R([
        "locked from the inside",
        "missing. Not removed. Missing. The hinges hold nothing.",
        "open. It has always been open. You know this without knowing how you know.",
        "marked with a symbol that matches nothing in the colony database. Or matches everything.",
    ])
    fluid_state = R(["dark", "warm", "viscous", "luminescent",
                     "still. Perfectly still. No ripples. Even when you drop something in."])
    container_total = str(RI(12, 40))
    manifest_count = str(RI(9, 37))
    extra_state = R(["heavier than they should be", "warm to the touch",
                     "humming", "labeled in handwriting, not print"])
    wall_mod = R([
        "removed and replaced with something older",
        "carved with symbols that glow faintly in UV light",
        "reinforced from the inside. As if to keep something in, not out.",
        "painted. A mural. Depicting the colony as it looks now. The paint predates the colony by decades.",
    ])
    interior2_pool = [
        "There is a room at the back. The door is " + door_state + ".",
        "The lower level is flooded. Not with water. With a fluid that is " + fluid_state + ".",
        "In the storage area: " + container_total + " sealed containers. Manifest says " + manifest_count + ". The extra containers are not on any record. They are " + extra_state + ".",
        "A section of wall has been " + wall_mod + ".",
    ]
    interior2 = R(interior2_pool)

    # --- Found items ---
    item1 = ctx.pick_fresh(ITEMS, "ITEMS") if ITEMS else "a sealed data drive"
    item2 = R(ITEMS) if ITEMS else "a Mammona ID badge"

    remaining = str(RI(1, 3))
    original = str(RI(14, 30))
    datapad_pool = [
        "DON'T OPEN IT. DON'T OPEN IT. DON'T OPEN IT.",
        "They told us it was a survey. It was not a survey.",
        "Day 1: Everything normal. Day 7: See previous entry. Day 7: See previous entry. Day 7: See prev",
        "If you are reading this, you are already too close. Leave. Leave now. I am sorry about the door.",
        "The readings are wrong. Not inaccurate. Wrong. As in: they describe a place that should not exist.",
        "Personnel remaining: " + remaining + ". Original complement: " + original + ". Cause of attrition: see attached. Attached file: corrupted.",
    ]
    datapad_text = R(datapad_pool)

    # --- What happened here ---
    op_type = R(["research operation", "extraction program",
                 "containment protocol", "long-term observation post"])
    op_duration = R(["three months", "eleven months", "four years"])
    shutdown_cause = R(["the incident", "what the report calls a structural failure",
                        "personnel attrition exceeded projectable parameters",
                        "someone opened something that was meant to stay closed"])
    shutdown_style = R(["orderly", "rapid", "incomplete -- someone left in a hurry",
                        "never officially recorded"])
    predate_duration = R(["centuries", "longer than that",
                          "a period of time that the dating equipment returns as an error"])
    prev_faction = R(FACTION_NAMES)
    prev_event = R(EVENTS)
    left_behind = R(["equipment that should not exist outside a military installation",
                     "biological samples in cryo storage -- still viable",
                     "a communications array pointed at a star that went dark forty years ago"])
    lab_letter = R("ABCDEF")
    happened_pool = [
        "Mammona ran a " + op_type + " here for " + op_duration + ". It was shut down after " + shutdown_cause + ". The shutdown was " + shutdown_style + ".",
        "This is not a Mammona site. It predates Mammona. It predates the colony. It predates the survey that found this planet. It has been here for " + predate_duration + ". Someone was here. Someone built this. They are not here now. The building is.",
        prev_faction + " operated here until " + prev_event + ". What they left behind includes " + left_behind + ". What they took with them is harder to determine. The inventory was purged.",
        "Nothing happened here. That is the official line. The scorch marks on the walls, the sealed lower level, the fact that every piece of furniture is bolted to the floor -- none of that constitutes an event. Mammona's incident log is clean. The blood spatter analysis from Lab " + lab_letter + " tells a different story.",
    ]
    what_happened = R(happened_pool)

    # --- NPC connection ---
    npc_ref = ctx.get_random_npc()
    npc_line = ""
    if npc_ref:
        npc_detail = R(["has been here before. Will not say when.",
                        "recognizes the layout without having seen a schematic.",
                        "refuses to enter. Says the air tastes wrong.",
                        "was assigned here on a previous posting. The posting is not in their file."])
        npc_line = "\n**Connected NPC:** " + npc_ref["name"] + " " + npc_detail

    output = (
        "## LOCATION: " + loc_name + "\n"
        "**Planet:** " + planet_label + " | **Type:** " + loc_type + "\n"
        "**Tone:** " + tone + "\n"
        "\n"
        "**Approach:**\n"
        + approach + "\n"
        "\n"
        "**Interior:**\n"
        + sense1 + "\n"
        "\n"
        + interior1 + "\n"
        "\n"
        + interior2 + "\n"
        "\n"
        "**Found Here:**\n"
        "- " + item1 + "\n"
        "- " + item2 + "\n"
        '- A data pad: "' + datapad_text + '"\n'
        "\n"
        "**What Happened Here:**\n"
        + what_happened
        + npc_line
    )

    output = enforce_contractions(output, tone)
    ctx.world.log_generation("location", loc_name)
    return output


# ============================================================
# 8. FACTION GENERATOR
# ============================================================

def gen_faction(ctx, tone=None, planet=None, era=None):
    """
    Faction profile. Name, type, leader, description, Mammona relationship,
    quest hooks, named members.
    """
    if not tone:
        tone = pick_tone()

    # --- Generate or pick name ---
    prefix = R(["The", "", "", "Order of the", "Children of", ""])
    mid = R(FRINGE_ADJ)
    suf = R(FRINGE_NOUN)
    fname = (prefix + " " + mid + " " + suf).strip()

    ftype = R([
        "corporate subsidiary", "pirate crew", "religious cult",
        "workers' collective", "intelligence cell", "smuggling ring",
        "scientific consortium", "survivalist commune", "shadow militia",
        "medical cooperative", "salvage operation", "data brokers",
    ])

    # --- Leader ---
    leader_first, leader_last, leader_gender = ctx.fresh_name()
    leader = leader_first + " " + leader_last
    lg, lgl, lgp, lgo = pronouns(leader_gender)

    rival_faction = R(FACTION_NAMES)
    ref_loc = R(_LOCATIONS_FLAT) if _LOCATIONS_FLAT else "Erebus"

    prev_leader_fate = R(["disappeared", "was killed",
                          "walked into the waste and never came back",
                          "is still alive, technically, in a medical bay on " + ref_loc])
    built_from = R(["a debt", "a grudge", "a promise made to someone who died",
                    "a document they found in a sealed archive on " + ref_loc])
    others_fate = R(["died in the first year", "were picked off by MasTema",
                     "left. One by one. For reasons " + leader_first + " will not discuss."])
    leader_detail_pool = [
        "founded " + fname + " after leaving " + rival_faction + " under circumstances that remain classified.",
        "does not call it leadership. Calls it 'coordination.' The distinction matters to no one but " + leader_first + ".",
        "inherited the position from the previous leader, who " + prev_leader_fate + ".",
        "built " + fname + " from " + built_from + ".",
        "is the only founding member still alive. The others " + others_fate,
    ]
    leader_detail = R(leader_detail_pool)

    # --- Description ---
    alignment = R(["pragmatists", "survivors", "opportunists", "believers"])
    diff_significance = R(["significant", "irrelevant", "contextual"])
    join_reason = R(["running out of options", "learning something impossible to unlearn",
                     "making a decision that locks every other door"])
    presence_state = R(["everywhere", "patient", "growing", "listening"])
    started_as = R(["a supply-sharing arrangement between three colonists",
                    "a prayer group that found something real",
                    "a crew that survived something together and never separated",
                    "a rumor that became self-fulfilling"])
    description_pool = [
        fname + " operates in the margins of " + rival_faction + "'s reach. They are not rebels -- rebellion requires an ideology. They are " + alignment + ". The difference is " + diff_significance + ".",
        "Nobody joins " + fname + ". You find yourself aligned with them after " + join_reason + ". " + leader_first + " does not recruit. " + lg + " waits.",
        "On paper, " + fname + " does not exist. Off paper -- in the corridors between shift changes, in the cargo holds where the cameras do not reach, in the conversations that happen in languages the translators do not carry -- they are " + presence_state + ".",
        fname + " started as " + started_as + ". It became something else. " + leader_first + " says it became necessary. The members say it became home.",
    ]
    description = R(description_pool)

    # --- Mammona relationship ---
    mammona_pool = [
        "Parasitic. " + fname + " exists because Mammona creates the conditions that make them necessary. Mammona knows this. It is cheaper than reform.",
        "Adversarial, but quietly. Open conflict would be suicide. So " + fname + " bleeds Mammona slowly -- a redirected shipment here, a corrupted manifest there. Death by a thousand accounting errors.",
        "Complicated. " + leader_first + " used to work for Mammona. Some days, " + leader_first + " still does. The line between infiltration and collaboration gets blurry after the third year.",
        "None. " + fname + " predates Mammona's presence here. They were here first. That fact is more dangerous than any weapon they possess.",
        "Transactional. " + fname + " has something Mammona wants. Mammona has something " + fname + " needs. The exchange keeps both sides civil. When it stops, one side disappears.",
    ]
    mammona_rel = R(mammona_pool)

    # --- Quest hooks (2) ---
    quest_task = R([
        "deliver a sealed package to a contact at " + ref_loc,
        "retrieve personnel files from a Mammona terminal",
        "smuggle a person off-colony without triggering the manifest",
        "investigate a site that " + rival_faction + " has been monitoring",
        "find out why three of their members have gone silent in the past week",
    ])
    quest1 = (leader_first + " asks the player to " + quest_task
              + ". The job is simple. The consequences are not.")
    quest2 = ("A member of " + fname + " is found dead in the colony. "
              + leader_first + " believes it was " + rival_faction
              + ". The evidence suggests otherwise. The truth is worse than either option.")

    # --- Members (2) ---
    member1_first, member1_last, member1_gender = ctx.fresh_name()
    member1 = member1_first + " " + member1_last
    member1_job = R(JOBS)

    member2_first, member2_last, member2_gender = ctx.fresh_name()
    member2 = member2_first + " " + member2_last
    member2_job = R(JOBS)

    m1_event = R(EVENTS)
    m1_handles = R(["logistics", "communications", "recruitment",
                    "the things nobody else will do"])
    m1_defect_from = rival_faction
    m1_defect_reason = R(["seeing something that changed their mind",
                          "a falling out over methods",
                          "being marked for termination"])
    member1_detail = R([
        "Joined after " + m1_event + ". Loyal to " + leader_first + ", not to the cause. There is a difference.",
        "The quiet one. Handles " + m1_handles + ". Has been with " + fname + " since the beginning.",
        "Former " + R(JOBS) + ". Defected from " + m1_defect_from + " after " + m1_defect_reason + ".",
    ])

    m2_worry = R(["their enthusiasm", "what they are hiding",
                  "how Mammona will react when they find out"])
    m2_enforce = R(["Nobody argues with them twice.",
                    "Keeps the peace through the threat of violence, not its application.",
                    "Has a reputation that does most of the work."])
    member2_detail = R([
        "Does not trust the player. Does not trust anyone. Has been right often enough to justify it.",
        "New. Eager. " + leader_first + " is worried about " + m2_worry + ".",
        "The enforcer. " + m2_enforce,
    ])

    sense = ctx.fresh_sensory(tone)

    # --- NPC cross-reference ---
    npc_ref = ctx.get_random_npc()
    npc_line = ""
    if npc_ref:
        npc_role = R(["sympathizer", "informant", "former member", "under recruitment"])
        npc_known = R(["The connection is known to Mammona.",
                       "The connection is not known to anyone except " + leader_first + ".",
                       "The connection is known to everyone. Nobody talks about it."])
        npc_line = ("\n**Known Associate:** " + npc_ref["name"] + " -- "
                    + npc_role + ". " + npc_known)

    output = (
        "## FACTION: " + fname + "\n"
        "**Type:** " + ftype + " | **Tone:** " + tone + "\n"
        "\n"
        + sense + "\n"
        "\n"
        "**Leader:** " + leader + "\n"
        + lg + " " + leader_detail + "\n"
        "\n"
        "**Description:**\n"
        + description + "\n"
        "\n"
        "**Relationship to Mammona:**\n"
        + mammona_rel + "\n"
        "\n"
        "**Quest Hooks:**\n"
        "1. " + quest1 + "\n"
        "\n"
        "2. " + quest2 + "\n"
        "\n"
        "**Members:**\n"
        "- **" + member1 + "** -- " + member1_job + ". " + member1_detail + "\n"
        "- **" + member2 + "** -- " + member2_job + ". " + member2_detail
        + npc_line
    )

    output = enforce_contractions(output, tone)
    output = _fix_nb_verbs(output, leader_gender)
    ctx.world.log_generation("faction", fname)
    return output


# ============================================================
# REGISTRATION
# ============================================================

EXPANDED_GENERATORS = {
    "robot": (gen_robot, "Robot/AI"),
    "company": (gen_company, "Company"),
    "vehicle": (gen_vehicle, "Vehicle"),
    "weapon": (gen_weapon, "Weapon"),
    "artifact": (gen_artifact, "Artifact"),
    "entity": (gen_entity, "Entity"),
    "location": (gen_location, "Location"),
    "faction": (gen_faction, "Faction"),
}
