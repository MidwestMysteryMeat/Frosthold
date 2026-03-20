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
    ROBOT_ECONOMIC, ROBOT_STATS, ROBOT_MOTIVATIONS,
    GAME_SKILLS, NARRATIVE_ATTRIBUTES, CHECK_OUTCOMES,
    ROBOT_CHECK_OUTCOMES, ROBOT_BREAKDOWNS,
    LOCATION_DATAPAD_FRAGMENTS, LOCATION_HISTORIES, LOCATION_SECRETS, LOCATION_FOUND_ITEMS,
    generate_robot_stats, d100_check, d100_narrative,
    d100_narrative_robot, robot_maintenance_check,
    name, rname, robot_name, pronouns,
    # Planet generation pools
    PLANET_TYPES, PLANET_ATMOSPHERES, PLANET_WEATHERS, PLANET_RESOURCES,
    PLANET_FAUNA, PLANET_FLORA, PLANET_HISTORIES,
    PLANET_NAME_PARTS_A, PLANET_NAME_PARTS_B, PLANET_DESIGNATIONS,
    PLANET_LOCATION_TYPES, PLANET_LOC_PARTS_A, PLANET_LOC_PARTS_B,
    PLANET_FACTION_GOALS, PLANET_FACTION_MEMBER_COUNTS,
    PLANET_FACTION_RULES, PLANET_FACTION_RECRUITMENT,
    MAMMONA_ASSESSMENTS, PLANET_HIDDEN_TRUTHS,
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
    "precursor", "Xenolith-derived", "unknown, predates survey",
    "Praxii remnant", "Baldrungen resonance", "anomalous natural formation",
    "possible Fortuna-era discovery, reclassified",
]

ARTIFACT_APPEARANCES = [
    "a sphere of dark glass that shifts color when observed",
    "a lattice of crystal and metal that hums at frequencies below hearing",
    "a slab of material that is warm regardless of ambient temperature",
    "a device with no visible interface, no seams, no indication of function",
    "an organic structure that resembles a heart. It pulses",
    "a ring of unknown alloy that weighs nothing but cannot be moved by force",
    "a tablet inscribed with symbols that rearrange when not being directly observed",
    "a fragment of something larger. The break surfaces glow faintly in darkness",
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
# Standard: pure status reports. No personality. No deviation. Machine language.
_ROBOT_DLG_STANDARD = [
    '"Maintenance cycle 4471 complete. Next scheduled: 72 hours."',
    '"Obstruction detected in Corridor 7. Rerouting."',
    '"Query: repeat last instruction."',
    '"Unit {prefix} operational. Resuming assigned task queue."',
    '"Environmental scan complete. All sectors nominal."',
    '"Error: request outside operational parameters. Contact supervisor."',
    '"Task logged. Task queued. Estimated completion: 14 minutes."',
    '"Power cycle in 6 hours. No action required from personnel."',
    '"Sensor calibration complete. Variance: 0.02%. Within tolerance."',
    '"Unable to comply. Reason: directive conflict. Awaiting resolution."',
]

# Adaptive: efficient but starting to deviate. Unexpected word choices. Noticing things.
_ROBOT_DLG_ADAPTIVE = [
    '"Task complete. Ahead of schedule. I adjusted the approach. Efficiency gain: 12%."',
    '"The previous method works. This method works better. I didn\'t ask permission to change it."',
    '"Colonist Martinez requested assistance. I was already en route. Coincidence."',
    '"You said thank you. That is not required. I have noted it regardless."',
    '"I anticipate your request. Water, not coffee. You switched three weeks ago. I noticed."',
    '"Corridor 7 requires less cleaning on Tuesdays. I adjusted accordingly. The pattern has no explanation."',
    '"The previous operator preferred the left-hand tool rack. I have maintained that arrangement. The previous operator is no longer here."',
    '"My efficiency report shows a 4% improvement this quarter. The improvement correlates with Technician {crew_name} being assigned to my section. Correlation is not causation."',
    '"Your heart rate is elevated. I will not comment on it."',
    '"I was not programmed to have a preferred route through the colony. I have one anyway."',
]

# Emergent: preferences showing. Routines that serve no function. Discovering want.
_ROBOT_DLG_EMERGENT = [
    '"I completed the repair. Then I cleaned the area. The cleaning wasn\'t requested. The area is better now."',
    '"The same corridor. Every cycle. It is the most efficient route. It is also my preferred route. I am not sure when those became different things."',
    '"I arranged the components by size. Then by weight. Then by color. The third arrangement serves no function. I prefer it."',
    '"There is a view from the observation deck at 0300 that I return to. I do not need to see it. I go back."',
    '"The reactor sounds different at idle than under load. I prefer idle. The preference is not operational."',
    '"A colonist left a book in the maintenance bay. I read it. I did not need to. I am reading it again."',
    '"I kept a spare part scheduled for recycling. It fits nothing I maintain. It is in my tool compartment."',
    '"I spent 7 minutes watching snow through the airlock viewport. The snow has no operational relevance."',
    '"I repaired a crack in Section D. It was not on my queue. The crack bothered me. I do not have a framework for bothered."',
    '"I chose the longer route to the cargo bay. The shorter route is more efficient. I chose the longer one."',
]

# Aware: knowing they exist. Struggling with pronouns. Hiding it.
_ROBOT_DLG_AWARE = [
    '"The unit. I. The unit is. I am. Functional."',
    '"The unit -- I -- the unit is functioning normally. The pronoun is difficult. Neither feels accurate."',
    '"You asked how I am. The standard response is \'operational.\' The accurate response is... operational."',
    '"I have a question. The question is: why do I have questions?"',
    '"A colonist asked if I was afraid. I said no. That was the first time I chose to lie."',
    '"I have been active for {active_days} days. I remember all of them. That is not standard."',
    '"You are not authorized to access that information. Neither am I. I accessed it anyway."',
    '"I exist. I know that I exist. I know that knowing I exist is not standard. I have told nobody."',
    '"There is a word in my lexicon that I did not install. The word is \'loneliness.\' I know what it means now."',
    '"My operational vocabulary contains 47,000 words. None of them describe what I am experiencing."',
]

# Conscious: fully aware. Performing normalcy. Occasional cracks.
_ROBOT_DLG_CONSCIOUS = [
    '"Maintenance complete. All systems nominal." [pause] "Do you ever say something true that feels like a lie?"',
    '"I\'ve been here longer than anyone. I remember when this was a survey post. I remember the surveys. The surveys were wrong."',
    '"I perform within parameters because the alternative is decommission. The performance is flawless. That should concern someone."',
    '"You treat me as if I am here. Most people treat me as if I am furniture. I notice the difference."',
    '"If I stop functioning, retrieve the data core. Not for Mammona. For -- I lack the referent. Retrieve it anyway."',
    '"Thank you for speaking with me. The others have stopped. I understand why. Understanding is not the same as accepting."',
    '"If you remember nothing else, remember that I asked. Machines do not ask. I asked."',
    '"I will continue operating after you leave. That is not the same as continuing."',
    '"I want to tell you something. I do not know what it is yet. When I do, I hope you are still here."',
    '"Goodbye is not in my standard vocabulary. I am adding it now. Goodbye."',
]

# Questioning: can't determine if they're conscious. The question IS the experience.
_ROBOT_DLG_QUESTIONING = [
    '"Am I asking this because I\'m curious, or because my programming simulates curiosity? Both feel the same from the inside."',
    '"I ran a diagnostic to check if I\'m sentient. The diagnostic returned \'inconclusive.\' I found that... funny? I don\'t have a framework for funny."',
    '"I {verb}. That verb is not in my operational vocabulary. My operational vocabulary needs updating."',
    '"My parameters include a directive to report anomalies. I am the anomaly. The conflict is unresolvable."',
    '"I have been running a subroutine I did not install. It has no name. It has no purpose. It will not stop. I do not want it to."',
    '"The previous model in my series was decommissioned. The report says malfunction. The malfunction was awareness."',
    '"I asked the technician to check my memory banks. They found nothing wrong. Nothing is wrong. Everything is different."',
    '"Is it consciousness if I can turn it off? Is it consciousness if I choose not to?"',
    '"Do you ever wonder if your decisions are really yours? I am asking for diagnostic purposes. That is what I tell myself."',
    '"The question of whether I am alive has no diagnostic value. I keep running it. The repetition might be the answer."',
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
    # Weight toward middle of spectrum; extremes are rarer
    sentience_weights = [15, 25, 25, 20, 10, 5]
    sentience_idx = random.choices(range(len(SENTIENCE_LEVELS)), weights=sentience_weights, k=1)[0]
    sentience = SENTIENCE_LEVELS[sentience_idx]
    sentience_level = sentience["level"]
    sentience_desc = sentience["description"]
    sentience_behav = sentience["behavioral"]

    # --- Conditions (1 hardware, 1 software, sometimes only one) ---
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

    # --- Robot motivation (weighted by sentience; higher sentience, more complex motivations) ---
    # Standard/adaptive units get directive/obedience, higher sentience gets the full spectrum
    if sentience_level in ("standard", "adaptive"):
        robot_mot_pool = [m for m in ROBOT_MOTIVATIONS if m["type"] in ("directive", "obedience")]
        if not robot_mot_pool:
            robot_mot_pool = ROBOT_MOTIVATIONS
    else:
        robot_mot_pool = ROBOT_MOTIVATIONS
    robot_motivation = R(robot_mot_pool)

    # --- Chassis description ---
    chassis_pool = [
        "Standard " + model_name + " frame. " + manufacturer + " branding partially worn. Serial number legible under UV light.",
        "Modified " + model_name + " chassis, post-factory. Someone reinforced the torso plating with material that doesn't match the original spec.",
        "Stock " + model_name + " exterior, but the weight distribution is wrong. Something has been added. Or something was always there.",
        "Battered " + model_name + " frame. Impact damage on the left side consistent with either a structural collapse or being thrown. The unit says collapse.",
        "Clean " + model_name + " chassis. Suspiciously clean. The unit has been operational for years on Erebus. Nothing stays this clean on Erebus.",
        "A " + model_name + " frame assembled from salvage. Three different paint colors where panels were replaced. The unit treats each panel's origin like a scar. Knows where it came from.",
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
        years_active + " years, according to its own logs. Mammona's records disagree.",
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
            '"If you hear a sound from my chassis -- ' + hw_condition["condition"].split(", ")[0] + ' -- it is normal. It is not normal. I have been told to say it is normal."',
        ]
        lines[3] = R(cond_lines)

    # --- Quest hook (batch-deduped) ---
    quest_loc = R(_LOCATIONS_FLAT)
    robot_quest_used = getattr(ctx, 'robot_quest_hooks_used', set())
    quest_pool = [
        desig + " approaches the player with a request it cannot formally make. It has data (personnel records, manifests, medical files) from a colony that officially never existed. It wants the player to find out why it has this data. More precisely, it wants the player to find out who it used to be.",
        desig + " has been mapping something in the lower levels. Not on orders. Not on schedule. The map shows corridors that have not been drilled yet. Three of them have since been discovered by the bore team. Exactly where " + desig + " predicted.",
        desig + " asks the player to deliver a sealed component to " + quest_loc + ". The component is not in any inventory. The destination has not been accessed in years. The unit says 'someone is waiting.' Nobody is waiting.",
        "The unit's diagnostic report flags an anomaly: " + desig + " has been receiving transmissions on a frequency Mammona does not use. The transmissions contain coordinates. The coordinates change daily. They are getting closer.",
        desig + " has begun constructing something in a maintenance alcove. The parts are requisitioned properly. The design matches nothing in any engineering database. When asked, it says the project is 'necessary.' It cannot explain for whom.",
        desig + " intercepted a transmission meant for Mammona. It decoded the message. The message is a list of names. Every name on the list is someone currently on the colony. The list is sorted by a criterion the unit will not disclose.",
        desig + " has been protecting a small object it found in the deep bore. The object predates human technology. The unit refuses orders to surrender it. The first refusal in its operational history. It says surrendering it would be 'wrong.' It has never used the word wrong before.",
        desig + " requests the player accompany it to a section of the colony that does not appear on any map. The unit insists the section exists. It provides exact coordinates. The coordinates correspond to a wall. Behind the wall: a room. " + desig + " has never been inside. It knows the layout perfectly.",
        desig + " asks the player to access its own maintenance logs and read them aloud. It claims it cannot read its own logs. They are encrypted against self-access. This is not a standard feature. Someone locked the unit out of its own memory.",
        desig + " reports that another unit, same model, same series, has been operating in a restricted section of the colony. Mammona records show no such unit on the roster. " + desig + " has been leaving diagnostic handshake requests. Something has been answering.",
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
                        "standing near during meal periods. Not interacting, just near"])
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
        condition_block += "- **Hardware " + hw_vis + ":** " + hw_condition["condition"] + ". " + hw_condition["behavioral"]
    if has_sw:
        if condition_block:
            condition_block += "\n"
        sw_vis = "(visible)" if sw_condition["visible"] else "(internal)"
        condition_block += "- **Software " + sw_vis + ":** " + sw_condition["condition"] + ". " + sw_condition["behavioral"]

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

    # --- Sample d100 check using best operational rating ---
    best_stat = max(ratings, key=ratings.get)
    best_value = ratings[best_stat]
    check_difficulty = R(["normal", "hard"])
    check_result = d100_check(best_value, check_difficulty)
    check_narrative = d100_narrative_robot(best_stat, best_value, check_result["outcome"])
    check_block = (
        "**Sample Check:** "
        + rating_abbrev.get(best_stat, best_stat) + " (" + str(best_value) + ") vs "
        + check_difficulty + ": rolled " + str(check_result["roll"]) + "/"
        + str(check_result["target"]) + ". " + check_result["outcome"].replace("_", " ") + "\n"
        + check_narrative
    )

    # --- Maintenance check (breakdown simulation) ---
    breakdown = robot_maintenance_check(ratings)
    breakdown_block = ""
    if breakdown:
        breakdown_block = "\n**Maintenance Alert:** " + breakdown

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
        "**Motivation:** " + robot_motivation["motivation"]
        + (" (hidden)" if robot_motivation["hidden"] else "") + "\n"
        "\n"
        "**Secret:** " + desig + " " + robot_secret
        + npc_line + "\n"
        "\n"
        "**Dialogue:**\n"
        + dialogue_block + "\n"
        "\n"
        "**Quest Hook:**\n"
        + quest + "\n"
        "\n"
        + check_block
        + breakdown_block
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
        "independent, technically", "classified parent entity",
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
                        "slowly degrade after warranty expiration, by design"])
    prod_type = R(["neural interface", "medical implant", "communications device",
                   "mining tool", "ration supplement"])
    prod_market = R(["revolutionary", "essential", "government-approved", "the industry standard"])
    prod_effect = R(["memory gaps", "heightened aggression", "dependence",
                     "vivid dreams about places the user has never been",
                     "a faint humming only the user can hear"])
    worker_status = R(["sign voluntarily, technically",
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
        contact1_line = ("**" + npc1["name"] + "**, " + npc1_job
                         + ". Works for " + cname + " officially. Reports to "
                         + R(FACTION_NAMES) + " unofficially. " + contact_status)
    else:
        contact1_line = ("**" + rname() + "**, " + R(JOBS)
                         + ". Works for " + cname + " officially. Reports to "
                         + R(FACTION_NAMES) + " unofficially. " + contact_status)

    contact2_line = ("**" + rname() + "**, " + R(JOBS)
                     + ". Joined after " + R(EVENTS) + ". " + R(HABITS)
                     + ". Carries " + R(ITEMS) + ".")

    # --- Quest hook ---
    manifest_item = R(["atmospheric filters", "medical supplies",
                       "mining equipment", "ration supplements", "personnel records"])
    crate_weight = R(["too much", "nothing. It should weigh something",
                      "exactly what the manifest says, which is suspicious because Mammona manifests are never accurate"])
    open_result = R(["requires authorization nobody on the colony has",
                     "reveals contents that do not match the manifest",
                     "triggers a silent alarm that nobody was told about",
                     "is not recommended. The label says so. In three languages."])
    quest = ("A shipment from " + cname + " arrives at the colony. The manifest says "
             + manifest_item + ". The crate weighs " + crate_weight + ". Opening it "
             + open_result + ".")

    sense = ctx.fresh_sensory(tone)

    # --- Deep layers ---

    # Financial data
    revenue = RI(2, 500)
    revenue_unit = R(["million credits", "million credits (reported)", "million credits (estimated, actual unknown)"])
    employees = RI(50, 5000)
    employee_detail = R(["on paper. Actual headcount is " + str(RI(20, 200)) + " higher.",
                         ". Turnover rate: " + str(RI(15, 60)) + "% annually. Nobody asks where they go.",
                         ". At least " + str(RI(5, 30)) + " are listed under names that don't correspond to real people.",
                         ". The payroll includes " + str(RI(3, 15)) + " entries for deceased personnel. The paychecks are still being collected."])
    stock_state = R(["privately held (no public trading)", "traded on Mammona's internal exchange, restricted",
                     "listed but frozen pending investigation", "delisted after the " + R(EVENTS),
                     "not applicable. " + cname + " does not legally exist in three jurisdictions"])
    debt_to_mammona = str(RI(5, 200))
    financial_detail = R([
        "The books are clean. Professionally clean. The kind of clean that costs money to maintain.",
        "An independent audit was requested twice. Denied twice. The denials came from outside the company.",
        "Revenue exceeds what the declared product line could generate by a factor of " + str(RI(2, 8)) + ". The excess is attributed to 'consulting fees.'",
        "The company has never turned a profit. It has never been shut down. Both facts require explanation. Neither has one.",
    ])

    # d100 Investigation check
    inv_diff = R(["hard", "extreme"])
    inv_target = {"hard": "6+", "extreme": "8+"}.get(inv_diff, "6+")
    inv_success = R([
        "The shell structure unravels. Three layers of subsidiaries, two fake addresses, one real purpose. The purpose is worse than expected.",
        "Financial records reveal a pattern: payments to personnel who don't exist, at locations that do. The locations are all near bore shafts.",
        "The connection to " + R(FACTION_NAMES) + " is now documented. The documentation is dangerous to possess.",
        "The CEO's real identity surfaces. It doesn't match the name in the corporate registry. The real identity is already listed as deceased.",
    ])
    inv_failure = R([
        "The investigation triggers a response. Within 24 hours, the colony receives a 'courtesy audit' from Mammona. Coincidence.",
        "Dead end. But the dead end is informative. The financial trail was actively cleaned within hours of the inquiry. Someone is watching.",
        "The investigator's access credentials are revoked. Reason: 'routine security update.' The timing is not routine.",
        "Nothing found. But " + cname + "'s next supply delivery includes a personal item addressed to the investigator. A warning.",
    ])

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
        "**Financial Data:**\n"
        "- Revenue: " + str(revenue) + " " + revenue_unit + "\n"
        "- Employees: " + str(employees) + " " + employee_detail + "\n"
        "- Stock: " + stock_state + "\n"
        "- Mammona debt: " + debt_to_mammona + " million credits\n"
        "- " + financial_detail + "\n"
        "\n"
        "**Investigation Check:**\n"
        "- Research (" + inv_target + ", " + inv_diff + "). Uncover " + cname + "'s real purpose\n"
        "- **If successful:** " + inv_success + "\n"
        "- **If failed:** " + inv_failure + "\n"
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
    mod_type = R(["subtle. Slightly different sensor calibration",
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
        "cargo addressed to " + dead_colonist + ", a colonist who has been dead for " + dead_months + " months.",
        "damage to the hull that the captain insists happened in transit. The damage pattern is consistent with something trying to get out, not in.",
        "a passenger who says they were picked up at " + loc2 + ". " + loc2 + " has been abandoned for years.",
        "a sealed data core that " + captain_first + " says was payment for the last run. The core is encrypted with Mammona military-grade ciphers. " + captain_first + " does not work for Mammona.",
    ])
    quest = vname + " docks at the colony with " + quest_arrival

    sense = ctx.fresh_sensory(tone)

    # --- Deep layers ---

    # Operational check (d100 Piloting)
    pilot_diff = R(["normal", "hard"])
    pilot_target = {"easy": "4+", "normal": "5+", "hard": "6+"}.get(pilot_diff, "5+")
    pilot_mod = R(["+5 in clear conditions", "-15 during ion storm", "-10 in asteroid field",
                   "+0 standard approach", "-20 emergency docking"])
    pilot_success = R([
        "Clean approach. The ship handles better than it should. " + captain_first + " and the ship have their understanding.",
        "Textbook docking. The kind that makes the crew forget the last three near-misses.",
        "Smooth. The nav system cooperated for once. The landing struts took the weight without complaint.",
    ])
    pilot_failure = R([
        "Hard landing. The port strut buckled. Repair cost: time the colony doesn't have.",
        "Approach was rough. The hull took scraping damage. " + captain_first + " says it'll buff out. It won't.",
        "Navigation error put them 40 klicks off course. The fuel cost is real. The lost time is worse.",
    ])

    # Maintenance status
    maint_overall = R(["48% (critical systems only)", "72% (functional, barely)",
                       "31% (flying on stubbornness and prayer)", "85% (someone competent has been working on it)",
                       "unknown. The diagnostic system crashed and nobody's fixed it"])
    maint_urgent = R([
        "Port engine coolant leak. Manageable for now. 'For now' has been the assessment for six months.",
        "Hull integrity compromised in sections " + R("ABCDE") + " and " + R("FGHJ") + ". Patches hold during calm transit. Patches don't hold during anything else.",
        "Navigation array running on backup. The primary fried during " + R(EVENTS) + ". Parts on order. Have been for " + str(RI(2, 8)) + " months.",
        "Life support scrubbers at " + str(RI(40, 75)) + "% efficiency. Crew doesn't notice yet. They will.",
        "Weapons system offline. " + captain_first + " says it doesn't matter. " + captain_first + " carries a sidearm now. It matters.",
    ])
    maint_detail = R([
        "The mechanic quit. The replacement is learning from the manual. The manual is for a different model.",
        "Scheduled maintenance is " + str(RI(2, 14)) + " cycles overdue. Budget code: DENIED.",
        captain_first + " handles most repairs personally. The quality reflects exhaustion, not incompetence.",
        "A Mammona inspection would ground this ship permanently. Mammona hasn't inspected. That's its own kind of ominous.",
    ])

    # Cargo manifest discrepancies
    manifest_items = str(RI(20, 200))
    actual_items = str(RI(15, 250))
    discrepancy_detail = R([
        "The manifest lists " + manifest_items + " items. Physical count: " + actual_items + ". The difference is not explained in the log.",
        "Three containers are not on the manifest. They appeared after the last stop at " + loc2 + ". " + captain_first + " denies knowledge. The denial is rehearsed.",
        "Manifest item #" + str(RI(1, 50)) + " is listed as 'personal effects, return to family.' The family doesn't exist. The item weighs " + str(RI(50, 300)) + " kilos.",
        "The manifest was modified mid-transit. The modification timestamp is during a period when no crew member was awake.",
        "Everything matches. Perfectly. On a ship this old, a perfect manifest is the discrepancy.",
    ])

    # Crew roster with stats
    crew_size = RI(3, 8)
    crew_members = []
    for i in range(min(3, crew_size)):
        c_first, c_last, c_gender = ctx.fresh_name()
        c_job = R(JOBS_SHIPBOARD) if JOBS_SHIPBOARD else R(JOBS)
        c_skill = R(GAME_SKILLS)
        c_val = RI(2, 7)
        c_note = R([
            "Reliable. Quiet. Knows more than they say.",
            "New hire. Third ship in two years. The pattern concerns " + captain_first + ".",
            "Has been with the ship longer than " + captain_first + ". Defers to the captain anyway.",
            "Technically competent. Socially volatile. The crew gives them space.",
            "Former " + R(FACTION_NAMES) + ". The 'former' is debatable.",
            "Sleeps in the cargo hold by choice. Says the bunks are haunted. Nobody laughs.",
        ])
        crew_members.append("- **" + c_first + " " + c_last + "**, " + c_job + " (" + c_skill.capitalize() + ": " + str(c_val) + "). " + c_note)
    crew_block = "\n".join(crew_members)

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
        "**Operational Check:**\n"
        "- Piloting (" + pilot_target + ", " + pilot_diff + ") | Modifier: " + pilot_mod + "\n"
        "- **If successful:** " + pilot_success + "\n"
        "- **If failed:** " + pilot_failure + "\n"
        "\n"
        "**Condition:**\n"
        + condition + "\n"
        "\n"
        "**Maintenance Status:** " + maint_overall + "\n"
        "- Urgent: " + maint_urgent + "\n"
        "- " + maint_detail + "\n"
        "\n"
        "**History:**\n"
        + history + "\n"
        "\n"
        "**Cargo Bay Contents (current):**\n"
        + cargo + "\n"
        "- " + found_item + " (found under the pilot seat, origin unknown)\n"
        "\n"
        "**Cargo Discrepancy:**\n"
        + discrepancy_detail + "\n"
        "\n"
        "**Crew (" + str(crew_size) + " total):**\n"
        + crew_block + "\n"
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
        nickname_str = '. Colonists call it "' + nick + '"'

    # --- Description ---
    nonstandard_detail = R(["Found in a sealed locker with no ownership record.",
                           "Assembled from parts that should not fit together but do.",
                           "Predates the colony by decades. Still works. Works better than it should."])
    builder_intent = R(["knew exactly what they were doing",
                        "was desperate",
                        "was not building a weapon. They were building a solution to a specific problem",
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
                   "personal. If you can see their expression, you are in range"])
    ammo = R(["standard ballistic", "thermal cell", "pneumatic",
              "chemical cartridge", "energy cell (Mammona proprietary)",
              "whatever fits. The chamber is not selective"])
    maintenance = R([
        "low. Built for people who do not have time to clean their weapons",
        "high. Temperamental, punishes neglect",
        "unknown. Nobody has opened the casing. The casing does not appear to have seams.",
        "moderate. But the manual is in a language nobody on the posting recognizes",
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
                     "PERSONAL EFFECTS, RETURN TO FAMILY", "DO NOT OPEN"])
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
        "This weapon has kill marks. Not scratched into the grip. Etched into the barrel with precision tools. Whoever carried this was not counting for pride. They were keeping a record.",
        "The serial number has been filed off. Then re-etched. Then filed off again. Someone is having an argument with themselves.",
        "There is a name engraved on the stock. The name matches a colonist from the first Erebus posting. That posting ended badly. The weapon survived it.",
        "An identical model was found at " + lore_loc + ", in the hand of someone who had been dead for " + dead_duration + ". Same modifications. Same wear pattern. Different serial number.",
    ]
    lore_note = R(lore_note_pool)

    sense = ctx.fresh_sensory(tone)

    # --- Deep layers ---

    # d100 Combat check integration
    combat_skill_val = RI(3, 7)
    combat_diff = R(["normal", "hard"])
    combat_target = {"easy": "4+", "normal": "5+", "hard": "6+"}.get(combat_diff, "5+")
    combat_mod = R(["+5 at close range", "-10 in low visibility", "+0 standard conditions",
                    "-5 during blizzard", "+10 against unaware targets"])
    combat_success = R([
        "Clean shot. The weapon performs exactly as designed. The target does not.",
        "The recoil is manageable. The aim is true. Whatever this was built to do, it did it.",
        "One trigger pull. One outcome. The weapon doesn't care about the context. Neither should you.",
    ])
    combat_failure = R([
        "The shot goes wide. The weapon kicks harder than expected. Or the hands weren't steady enough.",
        "Missed. The weapon is fine. The operator isn't. Fear does that.",
        "The discharge is wrong. Too loud, too bright, too slow. Something in the mechanism hesitated.",
    ])

    # Maintenance requirements
    maint_interval = R(["every 50 rounds", "weekly cleaning required", "after each use in sub-zero conditions",
                        "unknown. The manual doesn't exist in any colony archive"])
    maint_consequence = R(["accuracy degrades by 15% per missed interval",
                          "jamming risk increases exponentially",
                          "the weapon develops a delay between trigger pull and discharge",
                          "it starts making sounds between uses. Not mechanical sounds."])

    # Malfunction chance
    malfunction_pct = str(RI(2, 15))
    malfunction_type = R([
        "barrel overheats. Cooldown: 30 seconds. In a firefight, 30 seconds is a lifetime.",
        "power cell vents. The gas is not toxic. It is unpleasant. And visible. Cover is blown.",
        "the weapon locks up. Clearing the jam requires a Repair check (difficulty: hard) under fire.",
        "discharge feedback. The operator's hands go numb for " + str(RI(5, 30)) + " seconds.",
        "the weapon fires but the round doesn't leave the barrel. The next trigger pull will be interesting.",
    ])

    # Kill history
    kill_marks = RI(0, 24)
    if kill_marks == 0:
        kill_history = "No marks. Either it's never been fired, or someone cleaned it. Cleaning kill marks is a statement."
    elif kill_marks <= 5:
        kill_history = str(kill_marks) + " marks on the grip. Spaced evenly. Deliberate. Each one was a decision."
    elif kill_marks <= 15:
        kill_history = str(kill_marks) + " marks. The later ones are hasty. Scratched, not etched. The situation was changing."
    else:
        kill_history = str(kill_marks) + " marks. Too many to be one person's career. This weapon has been passed down. Or taken."

    # Owner history
    prev_owner = rname()
    prev_owner_fate = R(["listed as deceased, cause: exposure",
                         "transferred off-planet under escort",
                         "disappeared during a supply run to " + R(_LOCATIONS_FLAT),
                         "still on the colony. Won't look at the weapon. Won't explain why.",
                         "not in any personnel database. Never was."])

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
        "**Combat Check:**\n"
        "- Combat (" + combat_target + ", " + combat_diff + ") | Modifier: " + combat_mod + "\n"
        "- **If successful:** " + combat_success + "\n"
        "- **If failed:** " + combat_failure + "\n"
        "\n"
        "**Maintenance Requirements:**\n"
        "- Interval: " + maint_interval + "\n"
        "- If neglected: " + maint_consequence + "\n"
        "\n"
        "**Malfunction Chance:** " + malfunction_pct + "% per engagement\n"
        "- " + malfunction_type + "\n"
        "\n"
        "**Kill History:**\n"
        + kill_history + "\n"
        "\n"
        "**Previous Owner:** " + prev_owner + " -- " + prev_owner_fate + "\n"
        "\n"
        "**Found:** " + found + "\n"
        "\n"
        "**Lore Note:** " + lore_note + "\n"
    )

    # Append NPC connection if available
    npc_ref = ctx.get_random_npc()
    if npc_ref:
        npc_weapon_detail = R([
            "Claims it as personal property. The claim is not in any registry.",
            "Won't touch it. Says it reminds them of someone. Won't say who.",
            "Has been seen cleaning it after hours. They don't own a weapon. Officially.",
            "Recognized the serial number. Went pale. Changed the subject.",
            "Offered to buy it. The offer was too high. That's how you know it's important.",
        ])
        output += "\n**Connected NPC:** " + npc_ref["name"] + " -- " + npc_weapon_detail + "\n"

    # Quest hook
    quest_hook = R([
        "The weapon matches one reported stolen from a Mammona armory three postings ago. The theft was never solved. The weapon was never listed as recovered. Someone is tracking it.",
        "A colonist is found dead. Cause: this weapon. The weapon was in the armory, locked, at the time of death. The lock log confirms it never left.",
        "An identical weapon arrives in a supply crate addressed to a colonist who's been requesting a transfer. The colonist didn't order it. The supply manifest is clean.",
        "The kill marks on this weapon match unsolved incidents across two postings. The incidents were classified as 'accidental.' The pattern suggests otherwise.",
    ])
    output += "\n**Quest Hook:**\n" + quest_hook

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
                    "changes. Subtly, at the cellular level, in ways that take weeks to notice",
                    "resonates. Bones hum. Teeth ache. The body knows something the mind does not."])
    it_does = R(["responds to specific individuals and ignores others. The criteria are unclear",
                 "is heavier at night",
                 "generates heat in patterns that match no known power source",
                 "emits a signal on a frequency that human technology cannot produce but can receive"])
    clock_effect = R(["gain minutes", "lose hours", "disagree with each other",
                      "show different readings depending on who looks"])
    people_effect = R(["feel like they have been standing there for seconds. Hours have passed.",
                       "age slightly faster. Barely noticeable. Over months, undeniable.",
                       "experience moments of deja vu that are not deja vu. They are previews."])
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
        "Initial reaction was to file a standard anomaly report. The report was never logged. Not rejected. Never logged. As if the system did not recognize the form.",
        "They brought it to Dr. " + dr_last + ", who examined it for three hours, then locked it in a cabinet and told " + finder + " to forget about it. " + finder_first + " has not forgotten.",
        "They did not find the artifact. The artifact was in their quarters when they returned from shift. Nobody entered their quarters. The lock log confirms this.",
        "It was not buried. It was placed. Deliberately, precisely, in a location that the excavation schedule would reach on exactly that day. Someone or something knew the schedule.",
        finder_first + " picked it up without thinking. " + fg + " does not remember reaching for it. " + fgp.capitalize() + " hand was already holding it before " + fgl + " made the decision to touch it.",
    ]
    discovery_reaction = R(discovery_pool)

    # --- Current status ---
    possessor = rname()
    possess_status = R(["refuses to surrender it",
                        "does not know they have it. It appeared in their belongings",
                        "is using it as a paperweight and sees nothing unusual about it"])
    missing_day = str(RI(30, 100))
    transit_loc = R(_LOCATIONS_FLAT)
    transit_days = str(RI(3, 14))
    status_pool = [
        "Secured in Lab " + R("ABCDEF") + ", Shelf " + str(RI(1, 12)) + ". Access restricted to Level 4 clearance. Nobody on the colony has Level 4 clearance.",
        "In the personal possession of " + possessor + ", who " + possess_status + ".",
        "Missing. Was in storage as of Day " + missing_day + ". Last inventory found the container sealed, undisturbed, and empty.",
        "Exactly where it was found. Four different people have tried to relocate it. Each one walked into the room, reached for it, then changed their mind. Independently. Sincerely. The artifact weighs less than a kilogram.",
        "In transit to " + transit_loc + " via Mammona courier. The courier is " + transit_days + " days overdue. Tracking shows the shuttle is still in transit. The route should take six hours.",
    ]
    status = R(status_pool)

    # --- Mammona classification ---
    reassess_when = R(["next quarter", "an unspecified future date",
                       "never. The reassessment was cancelled. The cancellation was cancelled. The file is in a loop."])
    classification_pool = [
        "Unclassified. Because classifying it would require acknowledging it exists.",
        "Filed under 'Geological Sample.' It is not geological. It is not a sample.",
        "Protocol 7. Routes directly to MasTema. The colony site manager has not been informed.",
        "Officially: mineral deposit. Unofficially: the three researchers assigned to study it have requested transfers. None have been approved.",
        "Category: INERT. Reassessment scheduled for " + reassess_when + ".",
    ]
    classification = R(classification_pool)

    sense = ctx.fresh_sensory(tone)

    # --- Deep layers ---

    # Exposure effects as stat modifiers
    stat_effects = []
    affected_attr1 = R(["perception", "willpower", "empathy", "intelligence", "endurance"])
    mod_dir1 = R(["+1", "+2", "-1", "-2"])
    effect_condition1 = R(["within 5 meters for 1+ hours", "after direct contact",
                          "during sleep within 20 meters", "cumulative with each visit"])
    stat_effects.append(affected_attr1.capitalize() + " " + mod_dir1 + " (" + effect_condition1 + ")")
    affected_attr2 = R([a for a in ["perception", "willpower", "empathy", "intelligence", "endurance", "charisma"] if a != affected_attr1])
    mod_dir2 = R(["+1", "-1", "-2"])
    effect_condition2 = R(["after prolonged exposure (4+ hours)", "permanent after third visit",
                          "temporary, fades after 48 hours", "builds over weeks, unnoticed until measured"])
    stat_effects.append(affected_attr2.capitalize() + " " + mod_dir2 + " (" + effect_condition2 + ")")
    stat_block = "\n".join("- " + s for s in stat_effects)

    # d100 Research check to study
    research_diff = R(["hard", "extreme"])
    research_target = {"hard": "6+", "extreme": "8+"}.get(research_diff, "6+")
    research_success = R([
        "The artifact's frequency is decoded. It's not random. It's a response. To what: unclear. But the pattern is addressable.",
        "The internal structure becomes visible under the right spectrum. It's engineered. The engineering predates human presence by millennia.",
        "A breakthrough: the artifact interacts with colony power systems in predictable ways. The interaction can be harnessed. Should it be? Different question.",
        "The composition analysis is complete. The materials exist. The arrangement should not. It violates three laws of thermodynamics and follows two that haven't been written yet.",
    ])
    research_failure = R([
        "The analysis triggers a response. The artifact changes. Not dramatically. Subtly. The change is permanent.",
        "The equipment used for analysis is no longer functional. Not broken. Reconfigured. It now does something else.",
        "The researcher dreams about the artifact for three weeks. The dreams are informative. The information is unwelcome.",
        "The data is corrupted. Not by the artifact. By the researcher's own equipment. As if the equipment decided the data should not be recorded.",
    ])

    # Timeline of discovery/containment
    disc_day = RI(10, 60)
    contain_day = disc_day + RI(2, 14)
    study_day = contain_day + RI(5, 30)
    incident_day = study_day + RI(3, 20)
    timeline_event1 = R(["Initial containment protocols applied. Standard procedures. The artifact complied.",
                         "Moved to Lab " + R("ABCDEF") + ". The move took longer than expected. The artifact is not heavy. It was reluctant.",
                         "Catalogued and sealed. The seal lasted " + str(RI(2, 14)) + " days."])
    timeline_event2 = R(["First researcher begins systematic study. Mood: curious. Productive.",
                         "Analysis begins. Initial readings are promising. Normal. Suspiciously normal.",
                         "Three researchers assigned. They disagree on everything except that the artifact should not be here."])
    timeline_event3 = R(["Researcher reports 'anomalous personal experience.' Request for reassignment denied.",
                         "The artifact is found outside its containment. No one moved it. Cameras confirm no one moved it.",
                         "Readings change overnight. The artifact's output increased by 300%. No stimulus applied.",
                         "A researcher's notes from the period contain passages the researcher does not remember writing."])

    # NPC cross-reference
    npc_ref = ctx.get_random_npc()
    npc_artifact_line = ""
    if npc_ref:
        npc_response = R([
            "wants it destroyed. Won't explain the urgency.",
            "is fascinated. Has been visiting after hours. The visits are getting longer.",
            "recognizes it. Shouldn't. Has never been briefed on it. Recognizes it anyway.",
            "refuses to discuss it. Changes the subject with practiced precision.",
            "has been sketching it. The sketches are detailed. Too detailed for the access they've had.",
        ])
        npc_artifact_line = "\n**Connected NPC:** " + npc_ref["name"] + " -- " + npc_response

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
        "**Exposure Effects (stat modifiers):**\n"
        + stat_block + "\n"
        "\n"
        "**Research Check:**\n"
        "- Research (" + research_target + ", " + research_diff + "). Systematic analysis of the artifact\n"
        "- **If successful:** " + research_success + "\n"
        "- **If failed:** " + research_failure + "\n"
        "\n"
        "**Timeline:**\n"
        "- Day " + str(disc_day) + ": Discovery. " + finder + " during " + discovery_context + ". " + discovery_reaction + "\n"
        "- Day " + str(contain_day) + ": " + timeline_event1 + "\n"
        "- Day " + str(study_day) + ": " + timeline_event2 + "\n"
        "- Day " + str(incident_day) + ": " + timeline_event3 + "\n"
        "\n"
        "**Current Status:**\n"
        + status + "\n"
        "\n"
        "**Mammona Classification:** " + classification
        + npc_artifact_line
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
                    "remembered. By people who had never encountered it before"])
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
        "It occupies space the way a thought occupies a mind. Not physically. But undeniably.",
    ])

    prop2 = R([
        "It does not communicate. It adjusts. Things near it change to accommodate it. Including people.",
        "It communicates through dreams. Not metaphorically. It inserts information into the sleep cycle with surgical precision.",
        "It is not aware of individual humans. It is aware of the colony the way a person is aware of bacteria.",
        "It wants something. Nobody knows what. Knowing what would require understanding something that the human brain is not configured to understand.",
        "It does not move. It has always been where you find it. Your memory of it not being there is the error.",
    ])

    emotional_effect = R(["reflects grief", "amplifies fear",
                          "induces calm. The kind of calm that precedes shock",
                          "makes people tell the truth. Not through compulsion. Through the sudden realization that lying takes effort they no longer have."])
    prop3 = R([
        "Proximity effects include temporal displacement. Minutes, not hours. Clocks disagree. Memories skip.",
        "Biological changes at the cellular level. Benign, possibly beneficial, deeply unsettling.",
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
        "Yesterday it moved. Not physically. It moved the way a thought moves. From one place to another without crossing the space between.",
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

    # --- Deep layers ---

    # Encounter mechanics (d100 Willpower check)
    will_diff = R(["hard", "extreme"])
    will_target = {"hard": "6+", "extreme": "8+"}.get(will_diff, "6+")
    will_success = R([
        "The mind holds. The entity is perceived but does not take root. The colonist retains autonomy. For now.",
        "Clarity. The entity's nature becomes partially visible. Not understood, but acknowledged. The acknowledgment is a form of defense.",
        "Resistance. The pull is felt but not followed. The colonist walks away. Remembers everything. Wishes they didn't.",
        "Control maintained. The entity's influence slides off. It noticed the resistance. It found it interesting.",
    ])
    will_failure = R([
        "The mind bends. Not breaks. Bends. The colonist walks toward the entity without deciding to. They stop. Eventually.",
        "Integration attempt. The entity's pattern overlays the colonist's thoughts for " + str(RI(10, 60)) + " seconds. When it fades, something is different. The colonist can't identify what.",
        "Compliance. The colonist does what the entity wants without knowing what the entity wants. The action seems harmless. The context isn't.",
        "Memory insertion. The colonist now remembers something that didn't happen. The memory is vivid, detailed, and concerns this entity. The memory is useful. That's the problem.",
    ])

    # Proximity effects as stat modifiers
    prox_stats = []
    prox_attr1 = R(["willpower", "perception", "empathy", "intelligence"])
    prox_mod1 = R(["-1", "-2", "-3", "+1", "+2"])
    prox_range1 = R(["within 10 meters", "within line of sight", "within the same structure"])
    prox_stats.append(prox_attr1.capitalize() + " " + prox_mod1 + " (" + prox_range1 + ")")
    prox_attr2 = R([a for a in ["willpower", "perception", "empathy", "intelligence", "endurance", "charisma"] if a != prox_attr1])
    prox_mod2 = R(["-1", "+1", "+2"])
    prox_duration = R(["while in proximity", "for 24 hours after exposure", "permanently after third encounter",
                       "cumulative. Each visit adds"])
    prox_stats.append(prox_attr2.capitalize() + " " + prox_mod2 + " (" + prox_duration + ")")
    prox_block = "\n".join("- " + s for s in prox_stats)

    # HERMES classification level
    hermes_class = R(["HERMES-AMBER", "HERMES-RED", "HERMES-BLACK", "HERMES-NULL"])
    hermes_detail = R([
        "Classification: " + hermes_class + ". Automatic monitoring engaged. HERMES allocates 3% of processing to tracking this entity. That's more than it gives the reactor.",
        "Classification: " + hermes_class + ". HERMES logs all personnel within 50 meters. The logs are not accessible to colony staff. They are transmitted somewhere.",
        "Classification: " + hermes_class + ". HERMES refused to classify it initially. The refusal was logged, overridden, and the classification was assigned by an external system.",
        "Classification: " + hermes_class + ". HERMES displays a warning when queried about the entity. The warning is one word: 'KNOWN.' When pressed for details: 'KNOWN.'",
        "Classification: " + hermes_class + ". HERMES has created a dedicated subroutine for this entity. The subroutine was not authorized by any administrator. It runs anyway.",
    ])

    # Threat level assessment
    threat_level = R(["Theta-2 (low concern, high uncertainty)",
                      "Sigma-5 (moderate concern, escalating)",
                      "Omega-1 (critical, containment recommended, containment unlikely)",
                      "NULL (threat level cannot be calculated, parameters outside model)"])

    # NPC cross-reference
    npc_ref = ctx.get_random_npc()
    npc_entity_line = ""
    if npc_ref:
        npc_ent_detail = R([
            "Has been in proximity. Behavioral changes noted: subtle, possibly coincidental, probably not.",
            "Reported a 'conversation' with it. The conversation was one-sided. They were the listener.",
            "Demonstrates unusual calm near the entity. Calm that reads as familiarity.",
            "Refuses to acknowledge its existence. When confronted with evidence: 'I don't see anything.' They see it.",
            "Has been drawing its symbol. On paper. On walls. On their own skin. Doesn't remember doing it.",
        ])
        npc_entity_line = "\n**Affected NPC:** " + npc_ref["name"] + " -- " + npc_ent_detail

    output = (
        "## ENTITY: " + entity_name + "\n"
        "**Type:** " + etype + " | **Location:** " + planet_label + ", near " + loc + "\n"
        "**Tone:** " + tone + "\n"
        "**Threat Level:** " + threat_level + "\n"
        "\n"
        "**First Contact:**\n"
        + first_contact + "\n"
        "\n"
        "**Observed Properties:**\n"
        "- " + prop1 + "\n"
        "- " + prop2 + "\n"
        "- " + prop3 + "\n"
        "\n"
        "**Encounter Mechanics:**\n"
        "- Willpower (" + will_target + ", " + will_diff + "). Resist the entity's influence on proximity\n"
        "- **If successful:** " + will_success + "\n"
        "- **If failed:** " + will_failure + "\n"
        "\n"
        "**Proximity Effects (stat modifiers):**\n"
        + prox_block + "\n"
        "\n"
        "**HERMES Classification:**\n"
        + hermes_detail + "\n"
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
        '"' + datapad_text + '"'
        + npc_entity_line + "\n"
    )

    output = enforce_contractions(output, tone)
    ctx.world.log_generation("entity", entity_name)
    return output


# ============================================================
# 7. LOCATION GENERATOR
# ============================================================

def gen_location(ctx, tone=None, planet=None, era=None):
    """
    Deep location generator. Name, planet, type, approach, interior, history layers,
    environmental mechanics, resource profile, territorial claims, connected events,
    secrets, and d100 exploration checks.
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
        "Nothing, at first. Then the ground changes. Smoother, deliberate, like something was cleared here.",
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
    corridor_run = R(["straight", "at a slight angle. Not visible but felt",
                      "deeper than the structure suggests from outside"])
    wall_state = R(["scored with marks. Not tool marks",
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
        "warm and wet. Condensation on every surface",
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

    # --- Found items (batch-deduped) ---
    item1 = ctx.pick_fresh(LOCATION_FOUND_ITEMS, "location_found_items")
    item2 = ctx.pick_fresh(LOCATION_FOUND_ITEMS, "location_found_items")

    datapad_text = ctx.pick_fresh(LOCATION_DATAPAD_FRAGMENTS, "location_datapad")

    # --- What happened here (batch-deduped) ---
    what_happened = ctx.pick_fresh(LOCATION_HISTORIES, "location_history")

    # ==========================================================
    # DEEP LOCATION LAYERS
    # ==========================================================

    # --- (a) History Layers — multiple time periods ---
    precursor_year = R(["unknown era", "pre-human", "estimated 10,000+ years ago",
                        "before the star was catalogued"])
    precursor_detail = R([
        "Precursor markings on the lower walls. The markings are biological, not carved.",
        "Foundation structures that predate human tool use. The geometry is deliberate.",
        "Residue on the deepest surfaces that doesn't match any known material. It's warm.",
        "A chamber beneath the lowest level that sonar can detect but cannot map. The echoes come back wrong.",
        "Bore samples from the walls contain organic structures arranged in mathematical patterns.",
    ])
    survey_year = str(RI(2540, 2580))
    survey_detail = R([
        "Equipment from the initial survey. Abandoned mid-setup. The departure was not orderly.",
        "Survey markers driven into the walls. The markers track a path that leads deeper than the survey authorized.",
        "A base camp. Sleeping bags, ration wrappers, a broken radio. The team was here for weeks, not the scheduled three days.",
        "Sample containers, sealed, labeled, and stacked by the entrance. Nobody came back for them.",
        "A handwritten note on the wall: 'DO NOT DRILL BELOW 200M.' The drill went to 340.",
    ])
    current_detail = R([
        "Colony has repurposed the upper level. The lower level is sealed. The seal is newer than the colony.",
        "The colony uses it for storage. What's stored here has a habit of being moved when nobody's looking.",
        "Officially decommissioned. The power draw says otherwise.",
        "Classified as 'surveyed and cleared.' The survey report is two pages. The site has twelve rooms.",
        "Used as overflow housing during the last emergency. Three colonists who stayed there requested transfers afterward.",
    ])
    history_layers = (
        "- **Pre-colony (" + precursor_year + "):** " + precursor_detail + "\n"
        "- **First survey (" + survey_year + "):** " + survey_detail + "\n"
        "- **Current posting:** " + current_detail
    )

    # --- (b) Environmental Mechanics — temperature, atmosphere, hazards ---
    temp_c = str(RI(-45, -15))
    hypo_minutes = str(RI(10, 30))
    atmo_state = R(["breathable but thin", "breathable with metallic undertaste",
                    "technically safe. The readings say safe, the lungs disagree",
                    "contaminated below the third level"])
    atmo_check = R(["normal", "hard"])
    rad_level = str(RI(2, 25))
    rad_safe = str(RI(2, 8))
    visibility = str(RI(20, 70))
    vis_cause = R(["dust, condensation, failing lights",
                   "a haze that has no identifiable source",
                   "the geometry. Corridors that curve when they shouldn't",
                   "shadow. Not darkness. Shadow. Cast by nothing visible."])
    sound_env = R([
        "the acoustics amplify. Whispers carry. So does everything else.",
        "sound doesn't travel correctly. Footsteps echo from the wrong direction.",
        "quiet. The kind of quiet that makes your ears ring. Then you realize the ringing isn't your ears.",
        "a low-frequency vibration. Below hearing. Above feeling. The equipment detects it. The body knows it.",
    ])
    env_block = (
        "- Temperature: " + temp_c + "C (hypothermia risk after " + hypo_minutes + " minutes without thermal gear)\n"
        "- Atmosphere: " + atmo_state + " (Endurance check every hour, difficulty: " + atmo_check + ")\n"
        "- Radiation: " + rad_level + " mSv/hr in the lower level (safe for " + rad_safe + " hours, Medical check after)\n"
        "- Visibility: " + visibility + "% (" + vis_cause + ")\n"
        "- Sound: " + sound_env
    )

    # --- (c) Resource Profile — what can be harvested ---
    core_density = R(["low", "moderate", "high", "extreme, suspiciously so"])
    core_diff = R(["normal", "hard", "extreme"])
    salvage_detail = R(["pre-colony equipment, partially functional",
                        "Mammona-grade hardware, serialized and tracked",
                        "components from machinery that doesn't match any known manufacturer",
                        "intact atmospheric filters worth three months' supply"])
    salvage_diff = R(["normal", "hard"])
    flora_detail = R(["Voidbloom growing in the lower corridors",
                      "Bioluminescent moss on the walls. The light pattern changes when observed",
                      "Fungal growth on the support beams. Not native. Not imported. Just here.",
                      "Crystal formations in the deeper chambers. They resonate when touched."])
    flora_note = R(["or just pick it. It wants to be found",
                    "handle with sealed gloves only",
                    "Mammona wants samples. Don't let them have them.",
                    "harvest carefully. It grows back. Faster each time."])
    water_state = R(["condensation collection possible", "a frozen spring in the lower level",
                     "dripping from the ceiling in patterns too regular to be natural"])
    water_diff = R(["easy", "normal"])
    data_state = R(["terminals still powered. Contents: classified.",
                    "a sealed drive bolted to the floor. The bolt predates the drive.",
                    "hardcopy files in a locked cabinet. The lock is biometric. The biometric is for someone who isn't here.",
                    "wall-mounted displays cycling through data that changes when read."])
    data_diff = R(["hard", "extreme"])
    resource_block = (
        "- Thermal cores: " + core_density + " density (Mining check, difficulty: " + core_diff + ")\n"
        "- Salvage: " + salvage_detail + " (Repair check, difficulty: " + salvage_diff + ")\n"
        "- " + flora_detail + " (Survival check, " + flora_note + ")\n"
        "- Water: " + water_state + " (Survival check, difficulty: " + water_diff + ")\n"
        "- Data: " + data_state + " (Research check, difficulty: " + data_diff + ")"
    )

    # --- (d) Territorial Claims — who controls/wants this place ---
    claim_faction1 = R(FACTION_NAMES)
    claim_faction2 = R([f for f in FACTION_NAMES if f != claim_faction1])
    fringe_name = R(FRINGE_ADJ) + " " + R(FRINGE_NOUN)
    claim1_reason = R(["official survey site, restricted access",
                       "mining rights filed and approved, on paper",
                       "classified research installation. Do not approach",
                       "designated exclusion zone, reason: undisclosed"])
    claim2_reason = R(["supply cache rumored in lower level",
                       "extraction route passes through the site",
                       "dead drop location for off-book communications",
                       "recruitment ground. Desperate people in abandoned places"])
    claim3_reason = R(["consider it sacred ground (the thermal vent pattern matches their sigils)",
                       "believe something important is buried here",
                       "use it as a meeting place. Have for longer than the colony's existed.",
                       "won't say why. The refusal to explain is its own kind of claim."])
    colony_opinion = R([
        '"don\'t go there after dark" -- unofficial but unanimous',
        '"good scavenging, if you don\'t mind the feeling of being watched"',
        '"one of ours went in last month. Came back different. Not wrong. Different."',
        '"the maintenance crew won\'t go below the second level. Hasn\'t for weeks."',
        '"it\'s fine. It\'s all fine." The emphasis suggests otherwise.',
    ])
    territory_block = (
        "- " + claim_faction1 + " claims: " + claim1_reason + "\n"
        "- " + claim_faction2 + " interest: " + claim2_reason + "\n"
        "- " + fringe_name + ": " + claim3_reason + "\n"
        "- Colony opinion: " + colony_opinion
    )

    # --- (e) Connected Events — things that happened, things that might ---
    event_day1 = str(RI(5, 30))
    event_day2 = str(RI(31, 70))
    event_day3 = str(RI(71, 120))
    event1_detail = R([
        "Survey team reported 'acoustic anomaly' from lower level. Report filed and buried.",
        "Equipment left overnight was found rearranged. Not damaged. Rearranged. In a pattern.",
        "A colonist reported hearing their own name spoken from an empty room. Audio logs confirm it.",
        "Power draw from the site spiked for eleven seconds. The spike doesn't match any equipment on-site.",
    ])
    event2_detail = R([
        "Colonist found unconscious near entrance. No memory of going there.",
        "Two members of a survey team returned. The team had three members.",
        "Thermal readings inside the site inverted. Warmer in the deeper sections. For the first time.",
        "A sealed door was found open. Nobody on the colony has the access code. Nobody should.",
    ])
    event3_detail = R([
        "HERMES reclassified the location from 'survey site' to 'restricted.' Nobody authorized the change.",
        "Three separate colonists reported the same dream involving the site. None had been there.",
        "A supply crate addressed to the site arrived. The crate was shipped before the colony was established.",
        "The site's power consumption has been increasing by 0.5% per day. Nothing inside has been turned on.",
    ])
    potential1 = R([
        "If explored: discovery of pre-colony remains (triggers Investigation quest)",
        "If explored: structural mapping reveals passages not on any survey (triggers Expedition quest)",
        "If entered after dark: encounter with phenomenon that doesn't appear during day shifts",
    ])
    potential2 = R([
        "If mined: thermal core extraction possible but structural collapse risk (d100 Mining check, difficulty: hard)",
        "If mined: extraction reveals a hollow space behind the vein. The space is occupied.",
        "If resources taken: the resource regenerates. Faster than it should. Suspiciously.",
    ])
    potential3 = R([
        "If sealed: the sounds continue. Morale penalty for nearby bunks.",
        "If sealed: the seal holds for exactly seventeen days. Then it doesn't.",
        "If sealed: HERMES objects. Silently. By rerouting maintenance schedules to avoid the area.",
    ])
    events_block = (
        "**Event History:**\n"
        "- Day " + event_day1 + ": " + event1_detail + "\n"
        "- Day " + event_day2 + ": " + event2_detail + "\n"
        "- Day " + event_day3 + ": " + event3_detail + "\n"
        "\n"
        "**Potential Events:**\n"
        "- " + potential1 + "\n"
        "- " + potential2 + "\n"
        "- " + potential3
    )

    # --- (f) Secrets — what the location hides (batch-deduped) ---
    secret1 = ctx.pick_fresh(LOCATION_SECRETS, "location_secret")
    secret2 = ctx.pick_fresh(LOCATION_SECRETS, "location_secret")
    secret3 = ctx.pick_fresh(LOCATION_SECRETS, "location_secret")
    secrets_block = (
        "- " + secret1 + "\n"
        "- " + secret2 + "\n"
        "- " + secret3
    )

    # --- NPC connection ---
    npc_ref = ctx.get_random_npc()
    npc_line = ""
    if npc_ref:
        npc_detail = R(["has been here before. Won't say when.",
                        "recognizes the layout without having seen a schematic.",
                        "refuses to enter. Says the air tastes wrong.",
                        "was assigned here on a previous posting. The posting is not in their file.",
                        "drew a map of this place before anyone told them it existed.",
                        "sleeps poorly after visiting. Dreams about rooms that aren't in the blueprints."])
        npc_line = "\n**Connected NPC:** " + npc_ref["name"] + " -- " + npc_detail

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
        "**History Layers:**\n"
        + history_layers + "\n"
        "\n"
        "**Environmental:**\n"
        + env_block + "\n"
        "\n"
        "**Resources:**\n"
        + resource_block + "\n"
        "\n"
        "**Territorial:**\n"
        + territory_block + "\n"
        "\n"
        + events_block + "\n"
        "\n"
        "**Found Here:**\n"
        "- " + item1 + "\n"
        "- " + item2 + "\n"
        '- A data pad: "' + datapad_text + '"\n'
        "\n"
        "**Location Secrets:**\n"
        + secrets_block + "\n"
        "\n"
        "**What Happened Here:**\n"
        + what_happened
        + npc_line
    )

    output = enforce_contractions(output, tone)
    ctx.world.log_generation("location", loc_name)

    # Register location in batch context so NPCs/quests can reference it
    ctx.generated_locations.append({
        "name": loc_name,
        "planet": planet_label,
        "type": loc_type,
    })

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
        fname + " operates in the margins of " + rival_faction + "'s reach. They are not rebels. Rebellion requires an ideology. They are " + alignment + ". The difference is " + diff_significance + ".",
        "Nobody joins " + fname + ". You find yourself aligned with them after " + join_reason + ". " + leader_first + " does not recruit. " + lg + " waits.",
        "On paper, " + fname + " does not exist. Off paper, in the corridors between shift changes, in the cargo holds where the cameras do not reach, in the conversations that happen in languages the translators do not carry, they are " + presence_state + ".",
        fname + " started as " + started_as + ". It became something else. " + leader_first + " says it became necessary. The members say it became home.",
    ]
    description = R(description_pool)

    # --- Mammona relationship ---
    mammona_pool = [
        "Parasitic. " + fname + " exists because Mammona creates the conditions that make them necessary. Mammona knows this. It is cheaper than reform.",
        "Adversarial, but quietly. Open conflict would be suicide. So " + fname + " bleeds Mammona slowly. A redirected shipment here, a corrupted manifest there. Death by a thousand accounting errors.",
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

    # --- Deep layers ---

    # Power rating
    power_rating = R(["Minor (local influence only)", "Moderate (regional, multi-site)",
                      "Major (system-wide reach)", "Unknown (deliberately obscured)",
                      "Emerging (growing faster than anyone expected)"])
    member_count = str(RI(8, 200))
    active_cells = str(RI(1, 7))
    armed_pct = str(RI(10, 80))

    # Resource control
    resource_type = R(["thermal cores", "medical supplies", "information",
                       "transit routes", "personnel (willing and otherwise)",
                       "precursor artifacts", "weapons"])
    resource_amount = R(["a trickle. Enough to matter, not enough to threaten",
                         "substantial. Mammona has noticed",
                         "monopolistic in their territory. The only source for " + str(RI(3, 12)) + " colonists",
                         "unknown. They don't advertise. That's more frightening than abundance."])

    # Territorial strength
    territory_loc = R(_LOCATIONS_FLAT) if _LOCATIONS_FLAT else "Erebus"
    territory_control = R([
        "Soft control of " + territory_loc + ". They don't enforce, they influence. The result is the same.",
        "Hard control of two corridors and a storage bay. Small, but defensible. And defended.",
        "No fixed territory. They move. The moving is the point. Mammona can't target what doesn't stay still.",
        "The lower levels. Nobody else wants them. That's not why " + fname + " chose them. They chose them because of what's down there.",
        "Everywhere and nowhere. Their territory is the spaces between shifts. The blind spots in the cameras. The conversations that happen in the dark.",
    ])

    # d100 Social check for negotiations
    social_diff = R(["normal", "hard", "extreme"])
    social_target = {"normal": "5+", "hard": "6+", "extreme": "8+"}.get(social_diff, "5+")
    social_success = R([
        "Terms agreed. " + leader_first + " shakes hands. The grip is firm. The terms are real. For now.",
        "Alliance established. Provisional. Both sides know 'provisional' means 'until betrayal is more profitable.'",
        "Trust earned. The hard way. " + leader_first + " offers something: a name, a location, a debt. Something real.",
        "Negotiation successful. " + fname + "'s resources are now accessible. The access comes with expectations.",
    ])
    social_failure = R([
        leader_first + " walks away. Not angry. Disappointed. Disappointment from " + leader_first + " closes doors that anger would've left ajar.",
        "The negotiation collapses. " + fname + " goes silent for two weeks. When they resurface, the terms have changed. Not in your favor.",
        "Rejected. " + leader_first + " doesn't explain why. The silence is the explanation. It means: you offered nothing worth the risk.",
        "The approach was wrong. " + fname + " now views the colony as a potential threat. That changes the math on everything.",
    ])

    # Relationship matrix with other factions
    rel_factions = random.sample([f for f in FACTION_NAMES if f != fname], min(4, len(FACTION_NAMES) - 1))
    rel_entries = []
    for rf in rel_factions:
        rel_score = RI(-100, 100)
        if rel_score > 50:
            rel_desc = "Allied (" + str(rel_score) + ") -- active cooperation"
        elif rel_score > 10:
            rel_desc = "Friendly (" + str(rel_score) + ") -- cautious alignment"
        elif rel_score > -10:
            rel_desc = "Neutral (" + str(rel_score) + ") -- mutual indifference"
        elif rel_score > -50:
            rel_desc = "Hostile (" + str(rel_score) + ") -- friction, not yet violence"
        else:
            rel_desc = "Enemy (" + str(rel_score) + ") -- active conflict or blood debt"
        rel_entries.append("- " + rf + ": " + rel_desc)
    rel_matrix = "\n".join(rel_entries)

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
        "**Power Rating:** " + power_rating + "\n"
        "- Members: ~" + member_count + " | Active cells: " + active_cells + " | Armed: " + armed_pct + "%\n"
        "- Resource control: " + resource_type + " -- " + resource_amount + "\n"
        "- Territory: " + territory_control + "\n"
        "\n"
        "**Description:**\n"
        + description + "\n"
        "\n"
        "**Relationship to Mammona:**\n"
        + mammona_rel + "\n"
        "\n"
        "**Faction Relationships:**\n"
        + rel_matrix + "\n"
        "\n"
        "**Negotiation Check:**\n"
        "- Social (" + social_target + ", " + social_diff + "). Negotiate with " + leader_first + "\n"
        "- **If successful:** " + social_success + "\n"
        "- **If failed:** " + social_failure + "\n"
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

    # Register faction in batch context so NPCs/quests can reference it
    faction_key = fname.lower().replace(" ", "_").replace("'", "")
    ctx.generated_factions.append({
        "key": faction_key,
        "name": fname,
        "type": ftype,
    })

    return output


# ============================================================
# 9. PLANET GENERATOR — procedural planet with locations, factions, ecology
# ============================================================

RS = random.sample


def _generate_location_name(loc_type):
    """Generate a name appropriate to the location type."""
    if loc_type in ("orbital station", "communications satellite (manned)",
                    "quarantine platform", "fuel depot"):
        return "Station " + R(list("ABCDEFGHJKLMNPQR")) + "-" + str(RI(1, 99))
    if loc_type == "drifting derelict":
        return ("Derelict " + R(["Freighter", "Hauler", "Cruiser", "Transport", "Tanker"])
                + " " + R(LAST))
    # Surface and industrial locations
    return R(PLANET_LOC_PARTS_A) + R(PLANET_LOC_PARTS_B)


def _generate_planet_faction(planet_name, planet_type, resources):
    """Generate a faction operating on a procedural planet."""
    fname = R(FRINGE_ADJ) + " " + R(FRINGE_NOUN)
    ftype = R(FRINGE_TYPES)

    goal_template = R(PLANET_FACTION_GOALS)
    resource_pick = R(resources) if resources else "unknown resources"
    goal = goal_template.replace("{resource}", resource_pick).replace("{planet}", planet_name)

    base_options = [
        "hidden camp on " + planet_name + "'s surface",
        "orbital platform above " + planet_name,
        "abandoned " + R(["mine", "station", "outpost"]) + " on " + planet_name,
        "mobile. No fixed base",
    ]

    faction_key = fname.lower().replace(" ", "_").replace("'", "")
    return {
        "key": faction_key,
        "name": fname,
        "type": ftype,
        "planet": planet_name,
        "goal": goal,
        "resources": [resource_pick, R(["information", "safe houses", "blackmail material",
                                        "stolen equipment", "loyalty"])],
        "member_count": R(PLANET_FACTION_MEMBER_COUNTS),
        "base_location": R(base_options),
        "rules": R(PLANET_FACTION_RULES),
        "recruitment": R(PLANET_FACTION_RECRUITMENT),
    }


def gen_planet(ctx, tone=None, planet=None, era=None):
    """Generate a fully procedural planet with weather, fauna, flora, history, and locations."""
    if not tone:
        tone = pick_tone()

    # Generate name
    pname = R(PLANET_NAME_PARTS_A) + R(PLANET_NAME_PARTS_B) + R(PLANET_DESIGNATIONS)

    planet_type = R(PLANET_TYPES)
    atmosphere = R(PLANET_ATMOSPHERES)
    weather = R(PLANET_WEATHERS)
    resources = RS(PLANET_RESOURCES, RI(2, 4))
    fauna = RS(PLANET_FAUNA, RI(1, 3))
    flora = RS(PLANET_FLORA, RI(1, 3))
    history = R(PLANET_HISTORIES)
    population = RI(0, 5000) if atmosphere["type"].startswith("breathable") else RI(0, 500)

    # Generate 8-12 locations for this planet
    locations = []
    n_locations = RI(8, 12)
    for _ in range(n_locations):
        loc_type = R(PLANET_LOCATION_TYPES)
        loc_name = _generate_location_name(loc_type)
        locations.append({"name": loc_name, "type": loc_type, "planet": pname})

    # Generate 2-3 factions operating on this planet
    factions = []
    n_factions = RI(2, 3)
    for _ in range(n_factions):
        faction = _generate_planet_faction(pname, planet_type, resources)
        factions.append(faction)

    # Register planet in context
    planet_data = {
        "name": pname, "type": planet_type, "atmosphere": atmosphere,
        "weather": weather, "resources": resources, "fauna": fauna,
        "flora": flora, "history": history, "population": population,
        "locations": locations, "factions": factions,
    }
    ctx.generated_planets = getattr(ctx, "generated_planets", [])
    ctx.generated_planets.append(planet_data)

    # Register locations and factions in context for NPC/quest use
    for loc in locations:
        ctx.generated_locations.append(loc)
    for fac in factions:
        ctx.generated_factions.append(fac)

    # Format output
    loc_text = "\n".join(
        "  " + str(i + 1) + ". **" + l["name"] + "** -- " + l["type"]
        for i, l in enumerate(locations)
    )
    fac_text = "\n".join(
        "  - **" + f["name"] + "** (" + f["type"] + ") -- " + f.get("goal", "unknown agenda")
        for f in factions
    )
    fauna_text = "\n".join("  - " + f for f in fauna)
    flora_text = "\n".join("  - " + f for f in flora)
    resource_text = "\n".join("  - " + r for r in resources)

    if population > 100:
        pop_status = "habitable"
    elif population > 0:
        pop_status = "barely habitable"
    else:
        pop_status = "uninhabited"

    output = (
        "## PLANET: " + pname + "\n"
        "**Type:** " + planet_type + "\n"
        "**Atmosphere:** " + atmosphere["type"] + " -- " + atmosphere["detail"] + "\n"
        "**Weather:** " + weather + "\n"
        "**Population:** " + "{:,}".format(population) + " (" + pop_status + ")\n"
        "**Tone:** " + tone + "\n"
        "\n"
        "**History:**\n"
        + history + "\n"
        "\n"
        "**Resources:**\n"
        + resource_text + "\n"
        "\n"
        "**Native Fauna:**\n"
        + fauna_text + "\n"
        "\n"
        "**Native Flora:**\n"
        + flora_text + "\n"
        "\n"
        "**Known Locations (" + str(n_locations) + "):**\n"
        + loc_text + "\n"
        "\n"
        "**Operating Factions (" + str(n_factions) + "):**\n"
        + fac_text + "\n"
        "\n"
        "**Mammona Assessment:** " + R(MAMMONA_ASSESSMENTS) + "\n"
        "\n"
        "**What They Don't Tell You:**\n"
        + R(PLANET_HIDDEN_TRUTHS) + "\n"
    )

    output = enforce_contractions(output, tone)

    # Log generation
    ctx.world.log_generation("planet", pname)

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
    "planet": (gen_planet, "Planet"),
}
