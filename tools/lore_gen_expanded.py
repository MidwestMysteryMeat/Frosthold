"""
Expanded generators for Frosthold Procedural Lore Generator.
Adds: Companies, Vehicles, Weapons, Artifacts, Entities, expanded NPCs/Quests.
"""

import random
R = random.choice

# Import base pools
from lore_generator import (
    name, rname, robot_name, FIRST_M, FIRST_F, LAST, JOBS, FACTIONS,
    LOCS, PLANETS, LORE, BRANDS, ITEMS, TRAITS_P, TRAITS_N, TRAITS_X,
    EVENTS, sensory, TONES, dialogue_set,
)

# ============================================================
# EXPANDED POOLS
# ============================================================

SKILLS = ["Mining", "Engineering", "Medical", "Combat", "Research", "Cooking", "Construction", "Botany", "Piloting", "Demolitions", "Electronics", "Logistics", "Diplomacy", "Survival", "Xenobiology", "Cryptography", "Navigation", "Fabrication"]

HABITS = [
    "chews synthetic tobacco", "taps their fingers in patterns nobody recognizes",
    "talks to a photograph before every shift", "collects bottle caps from Sunny Fizz cans",
    "whistles the same four notes on repeat", "scratches tally marks into any surface within reach",
    "refuses to eat with other people", "sleeps sitting up, back to the wall",
    "reads the same book over and over -- a water-damaged copy of something in Portuguese",
    "hums during surgery. Patients find it unsettling. The survival rate is high.",
    "builds tiny structures from scrap metal during breaks. Dismantles them before shift ends.",
    "checks every doorway twice before walking through",
    "names every piece of equipment. Gets upset when others use the wrong name.",
    "writes numbers on the back of their hand. Different numbers every day.",
    "touches walls as they walk, like reading braille nobody else can see",
]

DEBTS = [
    "owes Mammona more than a decade of wages for a contract buyout",
    "borrowed from the Zenith Syndicate to pay for a family medical procedure",
    "stole cargo from the Black Maw and has been running since",
    "defaulted on a TerraGen pharmaceutical trial -- they own the data in their blood",
    "gambled away their shuttle ticket home on Karnaith",
    "sold information to the Void Serpents once. Once was enough to own them forever.",
    "took the fall for a superior's negligence. The debt is silence.",
    "owes a life debt to someone who died before it could be repaid",
]

PHYSICAL = [
    "missing the last two fingers on their left hand", "a chemical burn across the jawline",
    "one eye replaced with a Mammona-issued prosthetic that records everything",
    "walks with a limp from a mining accident that was never properly treated",
    "tattoo of coordinates on the inside of their wrist -- the coordinates lead to empty space",
    "prematurely grey from radiation exposure on Nemaea",
    "hands that shake unless occupied with work",
    "a voice that drops to a whisper when talking about anything that matters",
    "built like the machinery they operate -- broad, scarred, load-bearing",
    "thin enough that the cold seems personal. Eats like someone who learned to go without.",
    "surgical scars in a pattern too precise for emergency medicine",
]

VEHICLE_TYPES = ["shuttle", "cargo hauler", "mining rig", "patrol skiff", "drop pod", "survey crawler", "ice cutter", "ore barge", "escape pod", "armored transport", "deep bore rig", "atmospheric skimmer", "salvage tug", "med-evac runner"]

VEHICLE_NAMES_PRE = ["Rust", "Grey", "Cold", "Dead", "Last", "Iron", "Pale", "Black", "Drift", "Scar", "Bone", "Ash", "Salt", "Null", "Deep"]
VEHICLE_NAMES_SUF = ["Runner", "Knife", "Cradle", "Mouth", "Promise", "Horizon", "Debt", "Margin", "Profit", "Verdict", "Passage", "Anchor", "Line", "Hymn"]

WEAPON_TYPES = ["sidearm", "rifle", "shotgun", "mining laser repurposed as weapon", "shock baton", "pneumatic bolt gun", "thermal lance", "arc welder modified for combat", "chemical sprayer", "nail gun", "flare launcher", "vibrational cutter", "EMP emitter", "kinetic hammer"]

WEAPON_NAMES = ["Mammona Arms M-Series", "Fortune Arms Mk", "Colony Workshop Special", "Cobbled Together", "Pre-Collapse Relic", "Prototype", "Field Modified", "Black Market", "Standard Issue", "Restricted", "Decommissioned"]

ARTIFACT_ORIGINS = ["precursor", "Xenolith-derived", "unknown -- predates survey", "Praxii remnant", "Baldrungen resonance", "ancient race technology", "anomalous natural formation"]

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
]

ENTITY_TYPES = ["eldritch", "xenolith-born", "precursor guardian", "anomalous intelligence", "void presence", "gestalt organism", "parasitic consciousness", "temporal echo", "dream predator", "living architecture"]

COMPANY_TYPES = ["mining subsidiary", "pharmaceutical division", "security contractor", "logistics arm", "research division", "consumer products", "insurance underwriter", "human resources consultancy", "waste management", "communications network", "terraforming division", "cryogenics firm"]

COMPANY_SLOGANS = [
    "Building Tomorrow's Foundation", "Efficiency Through Excellence", "Your Future. Our Commitment.",
    "Reaching Further. Digging Deeper.", "People First. Always.", "Solutions for a Changing Galaxy.",
    "Trusted Since the Kennedy Expedition.", "Where Humanity Meets Opportunity.",
    "Progress Has a Name.", "We Go Where You Need Us.",
]


# ============================================================
# COMPANY GENERATOR
# ============================================================

def gen_company():
    tone = R(TONES)
    prefixes = ["Apex", "Crest", "Vanguard", "Meridian", "Helios", "Arcturus", "Nexus", "Pinnacle", "Vertex", "Forge", "Frontier", "Basalt", "Sterling", "Cobalt", "Obsidian", "Kinetic", "Quantum", "Orbital", "Fathom", "Zenith"]
    suffixes = ["Industries", "Corp", "Solutions", "Systems", "Dynamics", "Works", "Consolidated", "Partners", "Group", "Holdings", "International", "Unlimited", "Technical", "Services", "Logistics"]
    cname = f"{R(prefixes)} {R(suffixes)}"
    ctype = R(COMPANY_TYPES)
    parent = R(["Mammona Mining", "OmniCorp Shipping", "TerraGen Pharmaceuticals", "Fortune Arms", "independent -- technically"])
    ceo_f, ceo_l, ceo_g = name()
    ceo = f"{ceo_f} {ceo_l}"
    cp = {"M": "He", "F": "She", "NB": "They"}[ceo_g]

    products = [
        f"A line of atmospheric filters that {R(['work as advertised', 'contain a tracking compound Mammona can activate remotely', 'slowly degrade after warranty expiration -- by design'])}.",
        f"A {R(['neural interface', 'medical implant', 'communications device', 'mining tool', 'ration supplement'])} marketed as {R(['revolutionary', 'essential', 'government-approved', 'the industry standard'])}. Side effects include {R(['memory gaps', 'heightened aggression', 'dependence', 'vivid dreams about places the user has never been', 'a faint humming only the user can hear'])}.",
        f"Contract labor placement services. They provide workers to Mammona postings. The workers {R(['sign voluntarily -- technically', 'are drawn from debt pools and prison populations', 'rarely complete their contracts', 'are not always informed of their destination'])}.",
        f"A patented {R(['extraction process', 'preservation method', 'analysis tool', 'recycling system'])} that is {R(['slightly illegal in three systems', 'suspiciously effective', 'built on research conducted at Thalassa Deep', 'based on reverse-engineered precursor technology'])}.",
    ]

    secrets = [
        f"The company does not exist on paper. It is a shell for {R(FACTIONS)} to move resources without oversight.",
        f"Three of its board members also sit on the Mammona board. The regulatory conflict has been noted. It has not been addressed.",
        f"{ceo} founded the company after leaving {R(FACTIONS)} with data that {R(['should not exist', 'was supposed to be destroyed', 'describes something Mammona found and buried', 'contains personnel records for a colony that was never officially established'])}.",
        f"The company's primary product is a cover story. Its actual function is {R(['intelligence gathering for MasTema', 'laundering thermal cores off the books', 'recruiting personnel for Project Chrysalis', 'monitoring Xenolith activity without Mammona oversight'])}.",
    ]

    return f"""## COMPANY: {cname}
**Type:** {ctype} | **Parent:** {parent}
**Tone:** {tone}

**Slogan:** *"{R(COMPANY_SLOGANS)}"*

**CEO/Director:** {ceo}
{cp} {R([
    f"came up through {R(FACTIONS)} before pivoting to the private sector. The pivot was not voluntary.",
    f"has never visited any of the sites {cname} operates. This is deliberate.",
    f"signs every memo personally. The signature has been analyzed. It is not always the same hand.",
    f"is the third person to hold this position. The previous two are {R(['dead', 'missing', 'employed by Mammona under different names', 'on Thalassa Deep'])}.",
])}

**Public Product:**
{R(products)}

**Actual Product:**
{R(secrets)}

**NPCs:**
- **{rname()}** -- {R(JOBS)}. Works for {cname} officially. Reports to {R(FACTIONS)} unofficially. {R(['Knows too much to be safe.', 'Suspects nothing. That makes them useful.', 'Is aware of the arrangement and negotiating better terms.'])}
- **{rname()}** -- {R(JOBS)}. Joined after {R(EVENTS)}. {R(HABITS)}. Carries {R(ITEMS)}.

**Quest Hook:**
A shipment from {cname} arrives at the colony. The manifest says {R(["atmospheric filters", "medical supplies", "mining equipment", "ration supplements"])}. The crate weighs {R(["too much", "nothing -- it should weigh something", "exactly what the manifest says, which is suspicious because Mammona manifests are never accurate"])}. Opening it {R(["requires authorization nobody on the colony has", "reveals contents that do not match the manifest", "triggers a silent alarm that nobody was told about", "is not recommended. The label says so. In three languages."])}.
"""


# ============================================================
# VEHICLE GENERATOR
# ============================================================

def gen_vehicle():
    tone = R(TONES)
    vtype = R(VEHICLE_TYPES)
    vname = f"The {R(VEHICLE_NAMES_PRE)} {R(VEHICLE_NAMES_SUF)}"
    reg = f"{R('ABCDEFGHJKLMNPQRSTVWXYZ')}{R('ABCDEFGHJKLMNPQRSTVWXYZ')}-{random.randint(100,999)}"
    owner = R(FACTIONS)
    loc = R(LOCS)
    captain_f, captain_l, captain_g = name()
    captain = f"{captain_f} {captain_l}"
    cp = {"M": "He", "F": "She", "NB": "They"}[captain_g]

    conditions = [
        "Hull scoring consistent with micrometeorite damage. Or weapons fire. The report does not distinguish.",
        "The port engine runs hot. Always has. The mechanic who could fix it died on Karnaith.",
        f"The navigation system references {R(['waypoints that do not correspond to any known location', 'a star chart that is three decades out of date', 'a route through space that should be empty but is not', 'coordinates for a planet that Mammona delisted from the registry'])}.",
        "The cargo bay smells like ozone and copper regardless of what it carries. Nobody talks about it.",
        f"The AI assistant responds to a name that is not in its programming: {R(['Miriam', 'Father', 'the Warden', 'it does not have a name, but it answers to a specific frequency'])}.",
    ]

    histories = [
        f"Previously registered to {R(FACTIONS)}. Sold at auction after {R(EVENTS)}. The auction records have been altered.",
        f"Built at the {R(['Helios Yards', 'Karnaith orbital drydock', 'a facility that no longer exists'])}. Serial numbers indicate it is {random.randint(5,40)} years old. The hull material suggests it is older.",
        f"Has made the {R(LOCS)}-{R(LOCS)} run {random.randint(12,200)} times. Not all trips are in the log. The unlogged trips {R(['carried cargo that does not have names', 'delivered personnel to locations that are not on charts', 'returned empty. They did not leave empty.'])}.",
    ]

    return f"""## VEHICLE: {vname}
**Registration:** {reg} | **Type:** {vtype}
**Owner:** {owner} | **Home Port:** {loc}
**Tone:** {tone}

**Captain/Operator:** {captain}
{cp} {R([
    f"has been flying {vname} for {random.randint(2,15)} years. {cp} and the ship have an understanding.",
    f"inherited the ship from {R(['the previous captain, who disappeared', 'a debt settlement', 'a card game on Hyades that nobody talks about'])}.",
    f"is not the registered owner. The registered owner is {R(['dead', 'fictional', 'a Mammona subsidiary that does not acknowledge ownership'])}.",
])}

**Condition:**
{R(conditions)}

**History:**
{R(histories)}

**Cargo Bay Contents (current):**
{R([
    f"- {random.randint(20,200)} crates of {R(['thermal cores', 'NutriLoaf', 'mining equipment', 'sealed containers marked FRAGILE/BIOLOGICAL', 'ammunition', 'medical supplies past their expiration'])}",
    f"- One container that is not on the manifest. {captain_f} {R(['knows about it', 'does not know about it', 'knows about it and wishes they did not'])}.",
    f"- Empty. Officially empty. The hold smells like {R(['copper', 'antiseptic', 'ozone', 'something organic'])} and the walls have scratch marks at shoulder height.",
])}
- {R(ITEMS)} (found under the pilot seat, origin unknown)

**Quest Hook:**
{vname} docks at the colony with {R([
    "a distress beacon that was broadcasting when the ship arrived. The crew says the beacon is not theirs.",
    "one fewer crew member than it left with. Nobody on board will discuss the discrepancy.",
    f"cargo addressed to {rname()} -- a colonist who has been dead for {random.randint(2,8)} months.",
    "damage to the hull that the captain insists happened in transit. The damage pattern is consistent with something trying to get out, not in.",
    f"a passenger who says they were picked up at {R(LOCS)}. {R(LOCS)} has been abandoned for years.",
])}
"""


# ============================================================
# WEAPON GENERATOR
# ============================================================

def gen_weapon():
    tone = R(TONES)
    wtype = R(WEAPON_TYPES)
    wname_pre = R(WEAPON_NAMES)
    model = f"{R(['', '', 'Modified '])}{wname_pre} {R(['', str(random.randint(1,12)), R(['I','II','III','IV','V','VII'])])}"
    nickname = R([
        "", "", "",
        f' -- colonists call it "{R(["the Negotiator","the Dentist","Last Word","Bad News","the Convincer","Problem Solver","Dear John","the Question","Mammona Retirement Plan","Severance Package","Loud Opinion","the Discussion","Shift Change"])}"',
    ])

    return f"""## WEAPON: {model.strip()}{nickname}
**Type:** {wtype}
**Tone:** {tone}

**Description:**
{R([
    f"Standard-issue {wtype} found on most Mammona postings. Reliable, ugly, and chambered for rounds that Mammona happens to be the sole manufacturer of. That last part is not a coincidence.",
    f"Not standard-issue. Not legal on most postings. {R(['Found in a sealed locker with no ownership record.', 'Assembled from parts that should not fit together but do.', 'Predates the colony by decades. Still works. Works better than it should.'])}",
    f"Modified beyond recognition from its original design. Whoever built this {R(['knew exactly what they were doing', 'was desperate', 'was not building a weapon -- they were building a solution to a specific problem', 'left instructions scratched into the grip'])}.",
    f"A tool first. A weapon second. The line between the two on a Mammona posting is {R(['thin', 'theoretical', 'a matter of paperwork', 'whatever keeps you breathing'])}.",
])}

**Specifications:**
- Effective Range: {R(["close", "medium", "long", "personal -- if you can see their expression, you are in range"])}
- Ammunition: {R(["standard ballistic", "thermal cell", "pneumatic", "chemical cartridge", "energy cell (Mammona proprietary)", "whatever fits -- the chamber is not selective"])}
- Maintenance: {R(["low -- built for people who do not have time to clean their weapons", "high -- temperamental, punishes neglect", "unknown -- nobody has opened the casing. The casing does not appear to have seams."])}
- Side Effects: {R(["none (officially)", "mild hearing loss with sustained use", "vibration in the hands that persists for hours after firing", "a sound on discharge that colonists describe as 'wrong'", "the weapon grows warm between uses. Not from residual heat. It generates its own."])}

**Found:** {R([
    f"In a weapons locker on {R(LOCS)}. The locker was registered to {rname()}, who {R(['transferred out six months ago', 'is listed as deceased', 'denies ownership', 'has never been to this posting'])}.",
    f"On the body of a {R(JOBS)} found outside the perimeter. {R(['No identification.', 'The weapon was the only thing not taken.', 'The safety was still on.'])}",
    f"In a crate labeled {R(['MEDICAL SUPPLIES', 'ATMOSPHERIC FILTERS', 'PERSONAL EFFECTS -- RETURN TO FAMILY', 'DO NOT OPEN'])}.",
    "Mounted above a bunk in the barracks. No one claims it. No one touches it. It has been there longer than anyone on the posting.",
])}

**Lore Note:** {R([
    "Mammona officially discourages personal weapons on postings. Mammona also does not send enough security personnel. The policy exists to transfer liability, not to protect anyone.",
    "Fortune Arms discontinued this model after a recall that was never made public. The units that were not recalled are worth more than most postings pay in a year.",
    "This weapon has kill marks. Not scratched into the grip -- etched into the barrel with precision tools. Whoever carried this was not counting for pride. They were keeping a record.",
    "The serial number has been filed off. Then re-etched. Then filed off again. Someone is having an argument with themselves.",
])}
"""


# ============================================================
# ARTIFACT/TECH GENERATOR
# ============================================================

def gen_artifact():
    tone = R(["dread", "clinical", "paranoid", "melancholy"])
    origin = R(ARTIFACT_ORIGINS)
    appearance = R(ARTIFACT_APPEARANCES)
    finder = rname()
    loc = R(LOCS)

    art_names = [
        f"Object {random.randint(100,999)}-{R('ABCDEFG')}",
        f"The {R(['Breath','Eye','Tooth','Spine','Cradle','Mouth','Whisper','Frequency','Threshold','Weight'])} of {R(['Erebus','the Void','Silence','the Deep','Nothing','the Absent','the Unremembered'])}",
        f"Artifact {R('ABCDEFGHJK')}-{random.randint(1,99)} ({R(['CLASSIFIED','RESTRICTED','PENDING REVIEW','DO NOT DISTRIBUTE','SEE PROTOCOL 7'])})",
    ]

    effects = [
        f"Proximity causes {R(['headaches','vivid dreams','an awareness of being observed','a compulsion to draw specific patterns','the sensation of remembering something that never happened','nausea that passes exactly when you stop looking at it'])}.",
        f"Instruments within {random.randint(2,10)} meters {R(['malfunction','give readings that are internally consistent but physically impossible','function better than their specifications allow','display data in a language that is not programmed into them'])}.",
        f"Biological tissue within {R(['touching distance','line of sight','the same room'])} {R(['heals at an accelerated rate','ages', 'changes -- subtly, at the cellular level, in ways that take weeks to notice','resonates. Bones hum. Teeth ache. The body knows something the mind does not.'])}.",
        f"It {R(['responds to specific individuals and ignores others -- the criteria are unclear','is heavier at night','generates heat in patterns that match no known power source','emits a signal on a frequency that human technology cannot produce but can receive'])}.",
    ]

    return f"""## ARTIFACT: {R(art_names)}
**Origin:** {origin} | **Found at:** {loc}
**Discovered by:** {finder}
**Tone:** {tone}

**Appearance:**
{appearance}

**Properties:**
{R(effects)}

{R(effects)}

**Discovery Log:**
{finder} found the artifact on Day {random.randint(10,180)} during {R(["routine excavation", "a survey of the deep bore", "an unauthorized exploration of the sealed sector", "maintenance work in a sub-level that is not on the colony schematics", "a search for a missing colonist"])}. {R([
    "Initial reaction was to file a standard anomaly report. The report was never logged. Not rejected -- never logged. As if the system did not recognize the form.",
    f"They brought it to Dr. {R(LAST)}, who examined it for three hours, then locked it in a cabinet and told {finder} to forget about it. {finder} has not forgotten.",
    "They did not find the artifact. The artifact was in their quarters when they returned from shift. Nobody entered their quarters. The lock log confirms this.",
    "It was not buried. It was placed. Deliberately, precisely, in a location that the excavation schedule would reach on exactly that day. Someone or something knew the schedule.",
])}

**Current Status:**
{R([
    f"Secured in Lab {R('ABCDEF')}, Shelf {random.randint(1,12)}. Access restricted to Level 4 clearance. Nobody on the colony has Level 4 clearance.",
    f"In the personal possession of {rname()}, who {R(['refuses to surrender it', 'does not know they have it -- it appeared in their belongings', 'is using it as a paperweight and sees nothing unusual about it'])}.",
    f"Missing. Was in storage as of Day {random.randint(30,100)}. Last inventory found the container sealed, undisturbed, and empty.",
    "Exactly where it was found. Four different people have tried to relocate it. Each one walked into the room, reached for it, then changed their mind. Independently. Sincerely. The artifact weighs less than a kilogram.",
])}

**Mammona Classification:** {R([
    f"Unclassified. Because classifying it would require acknowledging it exists.",
    f"Filed under 'Geological Sample.' It is not geological. It is not a sample.",
    f"Protocol 7 -- routes directly to MasTema. The colony site manager has not been informed.",
    f"Officially: mineral deposit. Unofficially: the three researchers assigned to study it have requested transfers. None have been approved.",
])}
"""


# ============================================================
# ENTITY GENERATOR
# ============================================================

def gen_entity():
    tone = R(["dread", "clinical", "paranoid"])
    etype = R(ENTITY_TYPES)
    planet = R(PLANETS)

    entity_names = [
        f"The {R(['Listening','Breathing','Waiting','Remembering','Growing','Watching','Counting','Dreaming'])} {R(['Thing','Presence','Pattern','Signal','Frequency','Architecture','Silence'])}",
        f"Entity {R('ABCDEFG')}-{random.randint(1,99)}",
        f"Designation: {R(['UNKNOWN','NULL','UNDEFINED','SEE ATTACHED','[REDACTED]','DO NOT NAME'])}",
    ]

    return f"""## ENTITY: {R(entity_names)}
**Type:** {etype} | **Location:** {planet}
**Tone:** {tone}

**First Contact:**
{R([
    f"It was not seen. It was {R(['felt','inferred','calculated','dreamed','remembered -- by people who had never encountered it before'])}. The first indication was {R(['a change in the ambient temperature that instruments could not account for','the dogs. All of them. At once. Not barking. Listening.','a shift in the drilling pattern that the equipment made on its own','three colonists drawing the same symbol independently on the same day'])}.",
    f"Survey team {random.randint(1,12)} reported contact on Day {random.randint(30,120)}. The report was {R(['filed, read, and destroyed within the hour','written in a language the survey team did not speak','accurate. That was the problem.','incomplete. The final paragraph is blank. The team insists they wrote something.'])}.",
    f"Nobody made contact. Contact was made with them. The distinction {R(['matters','is academic','is the only thing that matters','was not understood until it was too late'])}.",
])}

**Observed Properties:**
- It is {R(["not alive in any way biology recognizes. It is active.", "alive in a way biology has no framework for. Conventional terms apply imprecisely at best.", "a pattern. Not a creature. Not a force. A pattern that the universe is running.", "older than the planet. Possibly older than the star."])}
- It {R(["does not communicate. It adjusts. Things near it change to accommodate it. Including people.", "communicates through dreams. Not metaphorically. It inserts information into the sleep cycle with surgical precision.", "is not aware of individual humans. It is aware of the colony the way a person is aware of bacteria.", "wants something. Nobody knows what. Knowing what would require understanding something that the human brain is not configured to understand."])}
- Proximity effects include: {R(["temporal displacement (minutes, not hours -- clocks disagree, memories skip)", "biological changes at the cellular level -- benign, possibly beneficial, deeply unsettling", "a sense of recognition. As if meeting someone you have known for years. The entity has not been here for years.", "language acquisition. Colonists begin understanding symbols and sounds they have never been exposed to."])}

**Mammona Assessment:**
{R([
    '"Geological anomaly. Recommend continued monitoring." The assessment has not been updated in three years. The monitoring has not been conducted.',
    '"Potential asset. Recommend containment study." The containment study was approved, funded, and staffed. The staff lasted eleven days.',
    '"Not a threat at current levels of activity." Current levels of activity have been increasing at a rate of 2.3% per week for seven months.',
    '"Does not exist. See amended survey data." The amended survey data was created after the original survey team was reassigned to Thalassa Deep.',
])}

**Colonist Reactions:**
- "{R(["It knows my name. I have not introduced myself. Nobody has.", "I am not afraid of it. I should be. The not-being-afraid is the thing that scares me.", "I think it is lonely. I do not know why I think that. I do not want to know.", "It has been here longer than anything. Longer than the ice. Longer than the rock under the ice. It was here when there was nothing and it will be here when there is nothing again."])}"
- "{R(["The dreams are getting clearer. I wish they would stop. I also wish they would not.", "Yesterday it moved. Not physically. It moved the way a thought moves -- from one place to another without crossing the space between.", "I built a shrine. I do not remember building it. It is made of materials I do not have access to.", "Other people cannot see it. I envy them. I also pity them."])}"

**Data Pad Found Nearby:**
{sensory(tone)}
"Whatever this is, it is not malevolent. Malevolence requires intent. This is something else. This is a process. We are not its enemy. We are not its friend. We are not even its concern. We are the environment in which it is happening."
"""


# ============================================================
# REGISTER ALL
# ============================================================

EXPANDED_GENERATORS = {
    "company": (gen_company, "Company"),
    "vehicle": (gen_vehicle, "Vehicle"),
    "weapon": (gen_weapon, "Weapon"),
    "artifact": (gen_artifact, "Artifact"),
    "entity": (gen_entity, "Entity"),
}
