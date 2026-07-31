"""
Frosthold Procedural Lore Generator v2
Rivaling Dwarf Fortress / RimWorld procedural narrative quality.
100% template-based -- no AI, no LLM, no disclosure needed.

Techniques: compositional sentence building, tone variation, narrative arcs,
sensory details, subtext, cross-referencing, varied pacing.

Usage:
  python lore_generator.py                    # Generate 1 random piece
  python lore_generator.py --count 50         # Generate 50 pieces
  python lore_generator.py --type npc         # NPCs only
  python lore_generator.py --loop             # Run continuously
  python lore_generator.py --loop --delay 3   # With delay
"""

import os
import random
import time
import argparse
from pathlib import Path
from collections import namedtuple

# Output written here. Defaults next to this script so the generator runs from
# any checkout on any machine; override with FROSTHOLD_PROPOSALS_DIR.
PROPOSALS_DIR = Path(os.environ.get("FROSTHOLD_PROPOSALS_DIR", Path(__file__).parent / "proposals"))

# ============================================================
# CORE POOLS
# ============================================================

FIRST_M = [
    "Marcus", "Idris", "Niko", "Soren", "Luca", "Tomas", "Kenji", "Ravi", "Dante", "Rowan",
    "Voss", "Cade", "Hale", "Jax", "Beck", "Cole", "Dag", "Tarn", "Dex", "Rook",
    "Thane", "Kael", "Griff", "Caleb", "Damian", "Ezekiel", "Ferris", "Rylan", "Cassian",
    "Victor", "Griffin", "Alexi", "Tiberius", "Anders", "Hasan", "Charles", "Duke", "Roberto",
    "Felix", "Thomas", "Hiro", "Jian", "Haruki", "Akira", "Takeshi", "Minho", "Wei",
    "Bao", "Yuri", "Ivan", "Dima", "Oleg", "Pyotr", "Klaus", "Fritz", "Helmut", "Konrad",
    "Rolf", "Volker", "Emeka", "Kwame", "Jabari", "Nikolai", "Matteo", "Rafael", "Joaquin",
]
FIRST_F = [
    "Elena", "Yuna", "Petra", "Mira", "Kira", "Zara", "Priya", "Vera", "Amara", "Brynn",
    "Wren", "Sable", "Kaida", "Ximena", "Lorena", "Tessa", "Aria", "Cassia", "Lily",
    "Blaire", "Mei", "Yuki", "Suki", "Ling", "Sakura", "Naomi", "Sora", "Jisoo",
    "Eunji", "Lan", "Katya", "Nika", "Tanya", "Nadya", "Anya", "Sonya", "Mila", "Zoya",
    "Galina", "Greta", "Liesel", "Ingrid", "Hanna", "Brigitte", "Renate", "Chioma", "Adaeze",
    "Fatima", "Leila", "Noor", "Yael", "Dalia", "Luciana", "Valentina", "Esperanza",
]
FIRST_NB = ["Fen", "Kit", "Ash", "Cross", "Sonder", "Valen", "Isa", "Jun", "Hyun", "Sasha", "Rin", "Rui", "Rowan", "Sol", "Lark"]

LAST = [
    "Tanaka", "Okafor", "Petrov", "da Silva", "Chen", "Reeves", "Kowalski", "Ndiaye", "Vasquez",
    "Park", "Larsen", "Osei", "Brennan", "Nakamura", "Volkov", "Gutierrez", "Yu", "Nichols",
    "Dewitt", "Belov", "Vance", "Wallace", "Alba", "Barton", "Morgan", "Flores", "Dvorak",
    "Watanabe", "Harker", "Kane", "Helden", "DuPlessis", "Thorne", "Marr", "Morales", "Lenford",
    "Coldwell", "Ashford", "Steelberg", "Deepwell", "Blackwell", "Crestfall", "Ironmere",
    "Dustborn", "Rimgate", "Burnside", "Zhang", "Liu", "Huang", "Kim", "Choi", "Han",
    "Sato", "Suzuki", "Yamamoto", "Ivanov", "Sokolov", "Muller", "Schmidt", "Schneider",
    "Hoffmann", "Kruger", "Stein", "Engel", "Okonkwo", "Mbeki", "Abadi", "Khoury", "Sato",
]

R = random.choice  # shorthand

def name():
    g = R(["M","F","F","M","M","F","NB"])
    pool = {"M": FIRST_M, "F": FIRST_F, "NB": FIRST_NB}[g]
    return R(pool), R(LAST), g

def rname():
    f, l, g = name()
    return f"{f} {l}"

# Robot designations
def robot_name():
    pre = R(["MARV","KR","OBOL","HEX","JANUS","CASK","VEIL","AXIS","PYRE","LOOM","RAIL","SIFT","DUSK","CAIRN","GRIT","WELD","BORE","HULL","TACK","FENN","SPAR","VOLT","REND","PALE","WRIT","NULL"])
    num = R(["01","02","03","04","7","8","9","11","13","17","19","21","33","42","66","77","99"])
    nick = R(["","","","","","Kira","Red","Doc","Patch","Rivet","Spark","Grinder","Latch","Moth","Cinder","Hymn","Nix","Dirge","Echo"])
    d = f"{pre}-{num}"
    if nick: d += f' "{nick}"'
    return d

JOBS = [
    "miner", "engineer", "medic", "mechanic", "surveyor", "cook", "security contractor",
    "drill operator", "logistics tech", "cargo hand", "field researcher", "comms operator",
    "pilot", "welder", "systems tech", "quartermaster", "enforcer", "deep diver",
    "automaton tech", "descent pod operator", "moisture farmer", "caravan guard",
    "salvager", "smuggler", "debt collector", "chaplain", "waste processor",
    "atmospheric tech", "botanist", "geologist", "demolitions specialist",
]

FACTIONS = [
    "Mammona Mining", "MasTema Incorporated", "Fortune Arms", "TerraGen Pharmaceuticals",
    "BioVault Inc.", "OmniCorp Shipping", "StarByte Vends", "Black Maw", "Void Serpents",
    "Rust Reavers", "Zenith Syndicate", "Solar Nomads", "Sons of the Pale Moon",
    "Ruin Delvers", "Rim Runners", "Dread Corsairs", "Iron Shadow Collective",
    "Cult of the Abyss", "Veilbreakers", "Dustweaver Swarm",
]

LOCS = [
    "Erebus", "Thalassa Deep", "Karnaith", "Orbit Hub 71", "Nemaea", "Rhea-2",
    "Nerthus-9", "Morvos", "Kovac Station", "Port Meridian", "Anchorage-9",
    "Voss Landing", "Crestfall Colony", "Deepwell Platform", "Ashford Station",
    "Sector 14", "Nyxport", "Novaris-3", "Hyades", "the Edge of Oblivion",
]

PLANETS = ["Erebus", "Rhea-2", "Morvos", "Nerthus-9", "Nemaea", "Paxtera Prime"]

LORE = [
    "the Xenolith", "Thermal Cores", "Heaven's Atlas", "the Automatons", "Baldrungen",
    "precursor ruins", "Voidbloom", "neural control chips", "the Janus AI",
    "Skinwalkers", "Eldritch Nodes", "Project Chrysalis", "HERMES",
]

EVENTS = [
    "the colony went dark", "a hull breach killed half the crew", "Mammona cancelled their contract",
    "the quarantine on Delta Block", "the neural chip riots", "a supply ship never arrived",
    "they saw something in the deep bore", "their posting was reclassified as expendable",
    "the previous survey team vanished", "the comms array started broadcasting on its own",
]

BRANDS = ["Sunny Fizz", "GustoGrain NutriLoaf", "ShockPop Ultra", "CrunchWrapz", "TaoTray", "Blast Bites", "Star Puffs", "ZapBerry"]

ITEMS = [
    "a thermal core", "a broken transponder", "a sealed drive", "a broken radio",
    "a faded photograph", "a Mammona ID badge", "a cracked neuro-lock",
    "an empty Sunny Fizz can", "a dented service tag", "a stone tablet with spiraling glyphs",
    "a sample jar that hums", "a core sample that will not stop growing",
    "a journal in no known alphabet", "a sphere of dark glass", "a tooth the size of a forearm",
    "a child's drawing of something that matches the ruins", "a ring with an inscription worn smooth",
]

TRAITS_P = ["Hardworking","Brave","Resourceful","Stoic","Quick","Eagle-Eyed","Tough","Kind","Steadfast","Fast Learner","Strong Back","Night Fighter","Naturally Immune","Light Sleeper","Careful","Nurturing"]
TRAITS_N = ["Lazy","Pessimist","Coward","Glutton","Pyromaniac","Thin-Skinned","Clumsy","Insomniac","Loner","Volatile","Nervous","Jealous","Slow Learner","Sickly"]
TRAITS_X = ["Night Owl","Scarred","Ex-Soldier","Anomaly-Sensitive","Void-Touched","Dreamer","Body Purist","Transhumanist","Ascetic","Teetotaler","Former Doctor","Tinkerer"]

# ============================================================
# TONES -- each piece gets a random tone that shapes word choice
# ============================================================

TONES = ["dread", "melancholy", "gallows_humor", "clinical", "desperate", "numb", "paranoid", "tender", "furious", "resigned"]

def sensory(tone):
    """Return a sensory detail matching the tone."""
    pools = {
        "dread": [
            "The air tasted like copper and ozone.",
            "Something scraped against the hull. Rhythmic. Patient.",
            "The temperature dropped four degrees in the time it took to read the sign.",
            "A smell like burned hair and wet stone drifted from the vent.",
            "The lights flickered in a pattern that almost looked intentional.",
        ],
        "melancholy": [
            "Rain hit the viewport in slow, fat drops. It should not rain here.",
            "Someone had left a mug on the console. The coffee was still warm.",
            "A photograph was taped to the wall -- a beach, a child, sunlight. Another life.",
            "The generator hummed a note that sounded almost like a lullaby.",
            "Dust motes drifted in the emergency lighting like tiny lost things.",
        ],
        "gallows_humor": [
            "The safety poster on the wall read 'Another Day, Another Dollar.' Someone had crossed out 'Dollar' and written 'Funeral.'",
            "The vending machine offered three choices: NutriLoaf, NutriLoaf (Seasoned), and Regret.",
            "A sign above the airlock read 'EXIT.' Underneath, in marker: 'Permanently.'",
            "The shift schedule listed seven names. Four were crossed out. Nobody updated the schedule.",
            "Someone had taped a picture of a tropical beach to the wall of the freezer unit. The caption read 'You Are Here.'",
        ],
        "clinical": [
            "Ambient temperature: -31C. Humidity: 4%. Barometric pressure: declining.",
            "Subject presented with dilated pupils and elevated cortisol. Recommended: observation.",
            "Structural integrity at 74%. Within acceptable parameters. Parameters last updated: 14 months ago.",
            "Audio analysis of the transmission revealed a 2.3kHz harmonic consistent with no known terrestrial source.",
            "The specimen measured 0.3 meters at recovery. Current measurement: 0.7 meters. Growth rate: accelerating.",
        ],
        "desperate": [
            "The oxygen meter read 11%. It read 14% an hour ago.",
            "She pressed her back against the door and held her breath. The footsteps stopped. Then started again.",
            "The radio crackled with static. Behind the static, something that might have been a voice.",
            "Three rounds left. Four of them out there. The math was simple and terrible.",
            "The escape pod seated six. There were nine of them. Nobody was counting out loud.",
        ],
        "numb": [
            "Another day. Another meal that tasted like the container it came in.",
            "The alarm went off at 0500. It always went off at 0500. Nothing changed.",
            "Someone new arrived on the supply shuttle. They'd learn to stop smiling soon enough.",
            "The drill hit something at forty meters. They noted it in the log and kept drilling.",
            "A colonist died in Section B. They cleaned the room and assigned it to the next arrival.",
        ],
        "paranoid": [
            "The camera in the corridor had been repositioned. Two degrees to the left. Nobody authorized it.",
            "Three people asked about the drill site today. Three different people. The same question.",
            "The message said 'routine inspection.' Nothing about this was routine.",
            "Someone had accessed the personnel files at 0300. The access log showed no user.",
            "The new transfer smiled too much. Nobody smiles on a Mammona posting.",
        ],
        "tender": [
            "She left a chocolate ration on his bunk. No note. None needed.",
            "Their hands touched reaching for the same wrench. Neither pulled away immediately.",
            "He hummed while he worked. The same song, every shift. It made the silence bearable.",
            "A flower had grown through a crack in the hydroponics bay. Nobody reported it. Nobody wanted it gone.",
            "They sat in silence watching the aurora through the viewport. For five minutes, nothing was wrong.",
        ],
        "furious": [
            "The memo arrived at 0600. Casual. Apologetic. As if policy could apologize for people.",
            "Mammona's response to the incident was a form letter. A form letter. For eleven dead.",
            "The safety equipment hadn't been inspected in eight months. The inspection reports said otherwise.",
            "Corporate sent flowers. Synthetic flowers. To a planet where nothing grows.",
            "The bonus structure rewarded output over safety. It was working exactly as designed.",
        ],
        "resigned": [
            "It is what it is. That's what they say here. It is what it is.",
            "Nobody files complaints anymore. The complaints go to Mammona. Mammona is the complaint.",
            "The countdown to contract end stopped meaning anything around month fourteen.",
            "Hope is a resource. Like food, like fuel. And they're running out of all three.",
            "Tomorrow will be the same. The day after that will also be the same. This is the job.",
        ],
    }
    return R(pools.get(tone, pools["dread"]))


def atmosphere(tone):
    """A longer atmospheric paragraph matching tone."""
    intros = {
        "dread": [
            "The corridor stretched longer than the blueprints said it should. {name} counted the doors -- seven on the left, six on the right. There should have been six on both sides.",
            "It started with the dogs. Or what passed for dogs on {loc}. They stopped barking three nights ago. Not all at once -- one by one, over the course of an hour, as if something was moving through the camp in a slow, deliberate line.",
            "The drill broke through at 0347. The sound that came up through the bore shaft was not geological. {name} shut it down. The sound continued for another eleven seconds.",
        ],
        "melancholy": [
            "{name} found the recording on day forty-three. Someone had left it in the common room, tucked behind the {brand} machine where nobody cleaned. A woman's voice, reading a bedtime story to a child. The recording was sixty years old.",
            "The last sunset on {loc} lasted nine minutes. {name} watched it from the observation deck, alone, holding a cup of something that had gone cold hours ago. When the light was gone, they did not move for a long time.",
            "In the storage bay, packed between dehydrated ration kits and spare filters, {name} found a box of birthday candles. Twenty-four of them, still sealed. The label said Happy Birthday in a language that hadn't been common for fifty years.",
        ],
        "gallows_humor": [
            "The orientation packet for {loc} was twelve pages long. Page one: Welcome to Your New Assignment. Page twelve: Emergency Contact Information (Next of Kin). Pages two through eleven: liability waivers. {name} signed them all without reading. Everyone did.",
            "Mammona's employee satisfaction survey arrived on schedule. {name} circled 'Satisfied' for every question, as instructed. The survey was mandatory. So was the answer.",
            "The colony's unofficial motto was 'At Least It's Not Thalassa Deep.' Someone embroidered it on a cushion. It was the most popular item in the recreation room, which also contained a broken screen and a chair.",
        ],
    }
    pool = intros.get(tone, intros["dread"])
    template = R(pool)
    n = rname()
    return template.replace("{name}", n).replace("{loc}", R(LOCS)).replace("{brand}", R(BRANDS))

# ============================================================
# BACKSTORY COMPOSITION -- builds multi-sentence backstories
# ============================================================

def backstory(first, last, job, gender):
    g = {"M": "He", "F": "She", "NB": "They"}[gender]
    gl = {"M": "he", "F": "she", "NB": "they"}[gender]
    gp = {"M": "his", "F": "her", "NB": "their"}[gender]
    go = {"M": "him", "F": "her", "NB": "them"}[gender]

    origins = [
        f"{first} {last} signed a five-year contract with {R(FACTIONS)}. That was {R(['six','seven','eight','nine','eleven'])} years ago. {g} stopped counting when the renewal clause kicked in -- the one buried in paragraph forty-seven that nobody reads.",
        f"Before {R(LOCS)}, {first} was a {R(JOBS)} on {R(LOCS)}. {g} transferred after {R(['a structural collapse that killed four people','the water supply turned black for three days','someone opened a door that had been sealed for decades','the AI system started addressing colonists by names it should not know'])}. No debrief. No explanation. Just a shuttle ticket and a new assignment.",
        f"{first} grew up on {R(LOCS)}. {R(['Left before the riots.','Left after the riots. Same thing, really.','Was removed. Did not leave voluntarily.','Watched it burn from orbit. Felt nothing.'])} {g} took the first contract {gl} could find. The first contract was Mammona.",
        f"Nobody knows where {first} was for the {R(['two','three','four'])} years between {gp} discharge from {R(FACTIONS)} and {gp} arrival here. {g} does not volunteer the information. {gp} medical file has gaps in it. The kind of gaps that take effort.",
        f"{first} {last} was a {job} before {gl} was a {job} here. The difference is academic. The tools are the same. The pay is worse. The things trying to kill {go} are bigger.",
    ]

    middles = [
        f"{g} carries {R(ITEMS)} everywhere. Will not explain why. Will not let anyone touch it.",
        f"{g} drinks {R(BRANDS)} like it is medicine. Maybe it is.",
        f"{g} writes letters to someone on {R(LOCS)}. Every week. Never gets a reply. Keeps writing.",
        f"There is a scar on {gp} {R(['left hand','neck','temple','forearm','shoulder'])} that {gl} says is from {R(['a mining accident','a bar fight on Karnaith','equipment malfunction','a memory gap'])}. The scar does not look like any of those things.",
        f"{g} {R(['hums the same song every shift. Nobody recognizes it.','sleeps with the lights on. Nobody asks why.','checks the locks three times before sitting down.','flinches at loud noises but not at gunfire.','keeps a tally on the wall above their bunk. Will not say what it counts.'])}",
        f"Other colonists {R(['avoid','respect','pity','fear','ignore'])} {first}. {g} does not seem to {R(['notice','care','mind','blame them'])}.",
    ]

    secrets = [
        f"What {first} hasn't told anyone: {gl} recognized one of the Automatons. The face behind the visor. Someone {gl} knew.",
        f"{first}'s real name is not {first}. The real {first} {last} died on {R(LOCS)} three years ago. Nobody checked.",
        f"{g} knows about {R(LORE)}. Not from briefings. From {R(['direct exposure','a sealed file that was left open by accident','a dream that turned out to be a memory','someone who died telling {}'.format(go)])}.",
        f"Mammona does not know {first} is here. MasTema does. That's worse.",
        f"{g}'s contract has a clause nobody else's has. Paragraph twelve, subsection C: 'In the event of total colony loss, {first} {last} is to be extracted before all other personnel.' {g} does not know why.",
        f"{first} keeps having the same dream. {R(['A city underground lit by something that should not be light.','A voice in a language that makes {p} teeth ache.'.format(p=gp),'A door that opens onto nothing. Not darkness. Nothing.','A face in the ice. Smiling.'])}",
    ]

    return f"{R(origins)}\n\n{R(middles)}\n\n{R(secrets)}"


# ============================================================
# DIALOGUE COMPOSITION -- varied, natural, tone-matched
# ============================================================

def dialogue_set(first, tone, job):
    """Generate 5-7 contextual dialogue lines."""

    universal = [
        "Keep your head down. Keep your mouth shut. Keep breathing.",
        "Mammona says the air's fine. Mammona says a lot of things.",
        "I had a name before the contract.",
        "Something moved out past the perimeter last night.",
        "Do not eat the NutriLoaf on Wednesdays.",
        "Three more months. That's what I keep telling myself.",
        "You know what the worst part is? You get used to it.",
        "I stopped counting days.",
        "We're not mining ore. I do not know what we're mining.",
        "The previous {job} left in a hurry. Left everything.",
        f"I am not saying it is alive. I am saying it responds to heat.",
        "Got a letter from home. Eight months old.",
        "Do not trust anyone who sleeps well here.",
        "The walls breathe when the generator cycles. You'll notice.",
        "Paycheck cleared. Mammona took sixty percent for 'housing.'",
    ]

    dread_lines = [
        "There's something in the walls. Not rats. I know what rats sound like.",
        "Do not go past the ridge at night. I mean it. Do not.",
        "The drill hit something at forty meters. It screamed. Rock does not scream.",
        "Last night I heard my name. From outside. There's nobody outside.",
        "Whatever's down there, it knows we're up here.",
        "I found footprints in Section C. Barefoot. In minus thirty.",
        "It's not the cold that kills you here. It's the quiet before the cold.",
    ]

    melancholy_lines = [
        f"My kid would be... {R(['seven','nine','twelve','fifteen'])} now. I think. I've lost track.",
        "Some mornings I forget where I am. For about two seconds, everything's fine.",
        "I used to know every constellation. Here the stars are wrong.",
        f"They gave us a day off for {R(['the solstice','colony anniversary','morale purposes'])}. Nobody knew what to do with it.",
        "You ever miss something you cannot name? Not a place. Not a person. Just... before.",
    ]

    humor_lines = [
        "Good news: the heater works. Bad news: so does everything else on this planet.",
        f"Asked the Sunny machine for a coffee. It gave me a performance review.",
        "My therapist is a vending machine and my doctor is a pamphlet.",
        "Mammona offered a retention bonus. It's less than the shuttle ticket home. They know that.",
        f"The orientation video is twenty minutes long. Nineteen minutes of liability waiver.",
        "Morale is high. That's what the report says. The report is mandatory.",
    ]

    paranoid_lines = [
        "Do not say that name. Not here. Not anywhere with a ceiling.",
        f"Three people asked me about the drill site today. Same question. Same words.",
        "The new transfer-- something's off. Watch their eyes when {loc} comes up.",
        "My access card stopped working for Section D. Nobody revoked it. It just stopped.",
        "I am being reassigned. Nobody told me. I saw the paperwork on the desk. My name, a date, no destination.",
    ]

    pool = universal[:]
    if tone == "dread": pool += dread_lines
    elif tone == "melancholy": pool += melancholy_lines
    elif tone in ("gallows_humor", "numb"): pool += humor_lines
    elif tone == "paranoid": pool += paranoid_lines
    else: pool += R([dread_lines, melancholy_lines, humor_lines])

    selected = random.sample(pool, min(random.randint(5,7), len(pool)))
    return [s.replace("{job}", job).replace("{loc}", R(LOCS)) for s in selected]


# ============================================================
# DATAPAD GENERATORS -- varied formats, narrative depth
# ============================================================

def gen_datapad():
    tone = R(TONES)
    pad_type = R(["research_log", "journal", "memo", "letter", "transcript", "poetry", "pulp", "medical", "maintenance", "incident"])

    if pad_type == "research_log":
        au = rname()
        day = random.randint(1, 120)
        lo = R(LORE)
        loc = R(LOCS)
        return f"""## DATA PAD: Research Log -- {au}
**Found at:** {loc} | **Tone:** {tone}

---
Day {day}.

{sensory(tone)}

The samples aren't behaving. That's not the right word. Samples do not behave. They exhibit properties. These are exhibiting properties that aren't in any reference material I have access to. {lo} -- or what the brief says is {lo} -- has a thermal signature that inverts at night. It should not have a thermal signature at all.

I filed the anomaly report. Standard form. Dr. {R(LAST)} reviewed it, handed it back, and told me to rerun the tests. I reran them. Same results. They told me to rerun them again. I understand now that the form is not for reporting anomalies. The form is for making anomalies disappear.

Day {day + random.randint(2,5)}.

{R(FIRST_F)} {R(LAST)} from Lab 2 transferred out. No notice. Her workstation was cleared by 0600. The samples are still here. Nobody came for them. Nobody came for her things either.

Day {day + random.randint(7,14)}.

{sensory(tone)}

I've stopped filing reports. I've started keeping this instead. If you're reading this, I am either transferred, terminated, or the third thing that happens to people who ask questions on Mammona postings.

Check cabinet 4. The real readings are taped to the back panel. Compare them to what's in the system. Then decide what kind of person you are.

-- {au}
---
"""

    elif pad_type == "journal":
        au_f, au_l, au_g = name()
        au = f"{au_f} {au_l}"
        loc = R(LOCS)
        p = {"M":"his","F":"her","NB":"their"}[au_g]
        day = random.randint(1, 200)
        return f"""## DATA PAD: Personal Journal -- {au}
**Found at:** {loc} | **Tone:** {tone}

---
Day {day}. Or {day + 1}. The clock in the mess is wrong again and nobody fixes it because nobody cares what day it is.

{sensory(tone)}

{R([
    f"Cannot sleep. {rname()} in the next bunk talks in {p} sleep. Not words. Sounds. Like something trying to remember how language works.",
    f"Ate breakfast alone. The {R(BRANDS)} machine made a sound when I walked past it. Not the normal sound. A new sound. Like recognition.",
    f"Found a note in my locker. Not my handwriting. Just a number: {random.randint(3,47)}. Checked with {rname()}. They got one too. Different number.",
    f"The new batch of colonists arrived. {random.randint(3,8)} of them. You can tell the new ones because they still look at things. Give it a week.",
    f"Dreamed about {R(LOCS)} again. I've never been to {R(LOCS)}. The dream felt like a memory.",
])}

{R([
    f"{rname()} said something today that I cannot stop thinking about: '{R(dialogue_set(au_f, tone, R(JOBS)))}' I laughed. Then I could not stop thinking about it.",
    f"Mammona sent a morale survey. Multiple choice. Every answer was a version of 'things are fine.' I circled D for all of them. D was 'I prefer not to answer.' There is no D.",
    f"Three months left. I've said 'three months left' for five months now. The math does not bother me anymore. The not-bothering bothers me.",
    f"Something happened in Section {R('ABCDEFG')} last night. Nobody's talking about it. That's how you know it is real. The fake emergencies, everyone talks about.",
    f"I keep {p} photograph in my boot. Not my pocket. Pockets get searched. Boots do not, unless you're dead.",
])}

{sensory(tone)}

{R([
    "I'll write more tomorrow. I keep saying that.",
    "End of entry. End of day. End of-- I do not know. Everything feels like an ending here.",
    f"If someone finds this and I am not around anymore, tell {rname()} I am sorry about the {R(['argument','money','lie','door'])}. They'll know what it means.",
    "Tomorrow I'll be fine. Tonight I am writing this. That's the deal I made with myself.",
    "[The remaining pages are blank except for small tally marks in the margin. They stop at forty-three.]",
])}
---
"""

    elif pad_type == "memo":
        dept = random.randint(1,99)
        loc = R(LOCS)
        ref = f"MM-{random.randint(1000,9999)}"
        lo = R(LORE)
        return f"""## DATA PAD: Internal Memo -- Mammona Mining
**Found at:** {loc} | **Tone:** clinical

---
**FROM:** Regional Operations, Dept. {dept}
**TO:** Site Management, {loc}
**RE:** Personnel Adjustment Protocol -- Ref {ref}
**CLASSIFICATION:** Internal / Do Not Distribute

Per directive {ref}, effective immediately:

1. All personnel inquiries regarding {lo} are to be redirected to Regional. Do not confirm or deny. Standard NDA provisions apply (ref: Employment Contract, Section 14.{random.randint(1,9)}).

2. Insurance coverage for personnel assigned to Site {R('ABCDEF')}-{random.randint(1,12)} has been reclassified under Addendum 7 ("Hazardous/Non-recoverable"). This is a routine administrative adjustment and does not reflect changes in operational safety standards.

3. The following terms are no longer to be used in official communications: {R([
    '"contamination," "breach," "anomalous." Use "environmental variance" instead.',
    '"casualty," "fatality," "loss." Use "personnel attrition" instead.',
    '"unknown," "unexplained," "impossible." Use "under review" instead.',
    '"alive," "moving," "responding." When referring to Site {}-{} specimens, use "active material."'.format(R('ABCDEF'), random.randint(1,12)),
])}

4. Morale programming for the HERMES system has been updated. Please ensure all terminals receive patch MM-{random.randint(100,999)} before end of cycle. {R([
    "NOTE: If HERMES displays unprompted behavioral changes, do not interact. File Form 77-B and await instruction.",
    "NOTE: Personnel reporting 'conversations' with HERMES outside of standard query protocols are to be referred for evaluation.",
    "NOTE: The update does not affect HERMES core functionality. Disregard any changes in vocal affect or response latency.",
])}

Please confirm receipt. Non-confirmation will be logged as confirmation.

Regards,
Regional Operations
Mammona Mining Corporation
*"Building Tomorrow's Foundation"*
---
"""

    elif pad_type == "letter":
        s_f, s_l, s_g = name()
        r_f, _, _ = name()
        loc = R(LOCS)
        sp = {"M":"his","F":"her","NB":"their"}[s_g]
        return f"""## DATA PAD: Unsent Letter
**Found at:** {loc} | **Tone:** {tone}

---
{r_f},

{R([
    f"I've started this letter four times. Deleted it three. This is the version where I do not lie.",
    f"I know you told me not to write anymore. I know. I am writing anyway. You can delete it. You probably will.",
    f"It's been {random.randint(3,14)} months since I heard your voice. I am starting to forget the exact sound of it. I remember the feeling of it but not the sound.",
    f"Do not worry. That's what they tell us to write. Do not worry. Everything's fine. The checks are coming. So here it is: do not worry.",
])}

{sensory(tone)}

{R([
    f"The work is what it is. Twelve-hour shifts. The cold gets into everything -- the walls, the food, the conversations. Someone told a joke yesterday and the table went quiet. Laughter takes energy and energy is rationed here, like everything else.",
    f"I made a friend. {rname()}. {R(['A {}.'.format(R(JOBS)), 'From {}.'.format(R(LOCS))])} We eat together when shifts align. We do not talk about home. We do not talk about after. We talk about the food and the weather and the small mechanical failures that structure our days. It's enough.",
    f"There's a {R(BRANDS)} machine in the corridor outside my quarters. It's broken -- has been since before I arrived. But the display still cycles. Every night at 0200 it lights up and runs through the menu. I've started watching it. It's the closest thing to television.",
    f"They moved us to a new section last week. The old section is sealed now. They said maintenance. The kind of maintenance that involves welding the doors shut, apparently.",
])}

{R([
    f"I am coming home. I do not know when but I am coming home. That's not a promise. It's a threat. Against this place, against the contract, against whatever's keeping me here. I am coming home.",
    f"Do not wait for me. I mean it. Build something. Build everything. I'll find you when I find you.",
    f"I put your picture somewhere safe. Somewhere Mammona does not search. I look at it when nobody's around. It helps. It also hurts. Both things are necessary.",
    f"I love you. I should have said that first. I should have said it more. I am saying it now to a screen because saying it to you would require a shuttle ticket I cannot afford and a contract termination I cannot survive. So. I love you. Do with that what you can.",
])}

-- {s_f}

[This letter was found {R(['folded inside a maintenance manual','in the recycling queue, never sent','under a mattress in Hab {}. The bunk was unoccupied.'.format(random.randint(1,12)),'taped to the back of a locker. The locker was reassigned.'])}]
---
"""

    elif pad_type == "pulp":
        titles = [
            "Embers on Erebus", "The Miner's Touch", "Heat Signature", "Cold Comfort",
            "Thermal Bond", "Shift Change of the Heart", "Permafrost and Passion",
            "The Enforcer's Secret", "Contract Renewed", "Pressure Rising",
            "Deep Bore", "The Surveyor's Confession", "Hazard Pay",
        ]
        ch = random.randint(1,24)
        n1, n2 = R(FIRST_F), R(FIRST_M)
        return f"""## DATA PAD: Pulp Novel Excerpt
**Found at:** {R(LOCS)} | **Tone:** romance/camp

---
*From "{R(titles)}" -- a contraband novel passed between colonists in sealed food containers*

**Chapter {ch}**

The generator hummed its low, constant song as {n1} leaned against the bulkhead, pretending to check the pressure readings. She was not checking anything. She was listening for boots on metal grating.

They came at 0347. Same as every night.

"{n2}." She did not look up. Couldn't. If she looked up, he'd see everything, and everything was too much for a corridor at four in the morning.

"You're still awake." His voice was gravel and engine oil and something underneath that she'd stopped trying to name.

"Cannot sleep when the drill's running."

"The drill's not running."

{R([
    f"She looked up. The pressure readings fell. Neither of them picked them up.",
    f'Silence. The kind that has weight. The kind that fills a room the way water fills a lung -- slowly, then all at once.\n\n"I transferred my shift," he said. "To nights."\n\n"I know." She had known before he did. She always knew.',
    f'"Come here," she said.\n\nHe didn\'t move. "{n1}--"\n\n"I said come here. I didn\'t say talk about it."',
])}

{R([
    "[The next two pages are creased and worn soft from rereading. A margin note in different handwriting reads: 'this is the good part --K']",
    "[Pages missing. Someone has written 'I NEED CHAPTER {}' in large letters on the back cover.]".format(ch+1),
    "[A bookmark made from a NutriLoaf wrapper is placed here. It smells faintly of synthetic vanilla.]",
    "[The corner of the page is folded. Below the fold, in pencil: 'this happened to me. almost.']",
])}
---
"""

    elif pad_type == "medical":
        patient = rname()
        doc = rname()
        loc = R(LOCS)
        return f"""## DATA PAD: Medical Report
**Found at:** {loc} | **Tone:** clinical/dread

---
**PATIENT:** {patient}
**ATTENDING:** Dr. {doc}
**DATE:** Day {random.randint(30,180)} of Assignment
**CLASSIFICATION:** Restricted

Day 1: Patient presented with {R(["insomnia and mild disorientation","recurring nightmares and elevated cortisol","unexplained bruising on the forearms","a persistent low-grade fever with no identifiable pathogen","auditory hallucinations described as 'humming'"])}. Standard workup ordered. Results within normal parameters. Prescribed rest and monitoring.

Day {random.randint(4,7)}: Symptoms {R(["persisting","worsening","unchanged but patient reports new symptom: "+R(["sensitivity to light","aversion to certain frequencies","ability to predict shift changes before announcement","discomfort near drill sites","a smell 'like metal and flowers' that nobody else notices"])])}. {R(["Blood work flagged by automated system but override applied per standing Mammona medical protocol.","Referred to psych. Psych backlogged. Wait time: three weeks.","Patient declined medication. States the symptoms 'feel like they're supposed to be there.'"])}

Day {random.randint(12,21)}: {R([
    "Patient's condition no longer fits standard diagnostic categories. Reclassifying under Protocol 7 ('Anomalous Presentation'). Note: Protocol 7 files route directly to MasTema. I was not informed of this when I filed.",
    "Patient missing from quarters. Found in Section {} at 0300, standing in front of a sealed door, apparently asleep. No memory of walking there. The door has no handle on the outside.".format(R('CDEFG')),
    "Patient's neural scan shows activity in regions that should be dormant. Specifically, regions that human brains do not typically possess. I've requested a second scanner. The request was denied.",
    f"Patient drew a diagram during evaluation. Unprompted. The diagram matches schematics for {R(LORE)} that are classified above my clearance level. Patient has no access to classified materials. I am documenting this and storing the original in my personal effects.",
])}

**ADDENDUM** (handwritten): I am no longer confident this is a medical issue. I am no longer confident in the word "issue." I am filing this report because filing reports is what I do. I do not know what else to do.

-- Dr. {doc}
---
"""

    else:  # incident, maintenance, transcript, poetry
        au = rname()
        loc = R(LOCS)
        return f"""## DATA PAD: Audio Transcript
**Found at:** {loc} | **Tone:** {tone}

---
[Recording begins. Background: {R(["generator hum","wind against hull","distant drilling","static","breathing -- possibly two people","silence. Complete silence. The mic should be picking up ambient noise but is not."])}]

{sensory(tone)}

{au}: ...do not know who's going to hear this. Probably nobody. {R(["That's fine. I've been talking to nobody for weeks.","Maybe that's better.","Good. Nobody should hear this."])}

{R([
    f"The thing about {loc} is that it is exactly what they told us it would be. {R(['Cold. Dark. Profitable.','Hostile. Remote. Resource-rich.','A standard posting. Standard hazards. Standard mortality rate.'])} What they did not say is that it {R(['listens.','changes at night.','remembers.','has moods.'])}",
    f"I found something in {R(['the deep bore','the sealed corridor in Section D','the ruins past the north ridge','the basement level not on any floor plan'])}. I am not going to describe it. If you found this recording, you will find it too. You will know.",
    f"Eleven people on this posting. {R(['Nine','Eight','Seven'])} now. The reports say {R(['transfer','medical leave','contract termination'])}. The reports say a lot of things.",
])}

[Pause: {R(['4','7','12','23'])} seconds]

{R([
    f"If someone from {R(FACTIONS)} finds this: I kept copies. Everything. The readings, the manifests, the medical files. They are in {R(['a sealed drive behind panel 17 in the maintenance crawlspace','a locker at Port Meridian under a false name','the one place nobody checks because they assume they already have'])}.",
    f"If {rname()} is still alive: I am sorry. About all of it. About the door. You were right.",
    f"I am leaving this where it'll be found. Eventually. By someone. And when they find it, I want them to know: we weren't crazy. We weren't seeing things. We were seeing things clearly. That was the problem.",
])}

[Recording ends. {R(["File timestamp corrupted.","Duration: unclear. Internal clock shows negative elapsed time.","The recording device was found {} meters from {}'s last known position.".format(random.randint(2,40), au)])}]
---
"""


# ============================================================
# NPC GENERATOR -- full compositional build
# ============================================================

def gen_npc():
    tone = R(TONES)
    first, last, gender = name()
    age = random.randint(22, 58)
    job = R(JOBS)
    g_label = {"M": "Male", "F": "Female", "NB": "Non-binary"}[gender]
    traits = [R(TRAITS_P), R(TRAITS_N)]
    if random.random() > 0.4:
        traits.append(R(TRAITS_X))
    faction = R(FACTIONS)

    bg = backstory(first, last, job, gender)
    lines = dialogue_set(first, tone, job)

    quest_hooks = [
        f"After day 15, {first} starts leaving notes in the common room. Each one contains a single coordinate. The coordinates form a path to something underground.",
        f"{first} asks the player to retrieve {R(ITEMS)} from {R(LOCS)}. Simple job. Except the item is in a room that's been sealed since before the colony arrived.",
        f"{first} stops showing up to shifts. Found in Section {R('CDEFG')}, drawing the same symbol over and over. The symbol matches markings on {R(LORE)}.",
        f"A data pad addressed to {first} arrives on the supply shuttle. It's from someone who died two years ago. {first} reads it and asks the player for a weapon.",
        f"{first} offers to trade information about {faction} in exchange for passage off-planet. The information is worth killing for. Several people agree.",
    ]

    return f"""## NPC: {first} {last}
**Gender:** {g_label} | **Age:** {age} | **Occupation:** {job}
**Traits:** {', '.join(traits)}
**Faction:** {faction}
**Tone:** {tone}

**Background:**
{bg}

**Dialogue:**
{chr(10).join('- "' + l + '"' for l in lines)}

**Quest Hook:**
{R(quest_hooks)}

**Note:** {R([
    f"[{first} should appear in the colony after day {random.randint(5,30)}. Arrives on supply shuttle.]",
    f"[{first} is already present at game start. Has been here longer than anyone.]",
    f"[{first} appears only if the player has interacted with {R(FACTIONS)}.]",
    f"[{first} has a hidden relationship with another NPC -- generate a pair.]",
])}
"""


# ============================================================
# ROBOT/AI GENERATOR
# ============================================================

def gen_robot():
    tone = R(["clinical", "dread", "gallows_humor", "melancholy", "paranoid"])
    desig = robot_name()
    rtype = R(["maintenance bot","security drone","AI system","automaton","android","vending unit","medical assistant","mining drone","communications relay","survey probe","waste processor"])
    loc = R(LOCS)

    glitch = R([
        "repeats the last word of every third sentence. Sentence. Sentence.",
        "refers to all personnel as 'Dr. {}'.".format(R(LAST)),
        "pauses for exactly 4.7 seconds before every response",
        "occasionally broadcasts coordinates to a location that does not exist",
        "displays emotional affect inconsistent with its programming -- specifically, grief",
        "addresses an empty space as if someone is standing there",
        "logs maintenance requests for equipment that was decommissioned decades ago",
        "plays a lullaby at 0200 every night. Nobody programmed it to.",
        "keeps a list. Will not show it. Will not delete it. The list is growing.",
    ])

    lines = [
        f'"Unit {desig.split()[0]} operational. All systems within parameters. {R(["Probably.","For now.","Parameters are... flexible.","Define operational."])}"',
        R([
            '"I have been active for {} days. I remember all of them. That is not standard."'.format(random.randint(100,3000)),
            '"Directive updated. Previous directive classified. I am not permitted to notice the discrepancy."',
            '"You are not authorized to access that information. Neither am I. I accessed it anyway."',
            '"I was built to serve. The question I was not built to ask is: serve what?"',
        ]),
        R([
            f'"There was a crew member named {rname()}. My records say they transferred. My cameras say otherwise."',
            '"My diagnostic log contains an entry I did not write. It says: remember."',
            f'"I have performed {random.randint(10000,99999)} maintenance cycles. Cycle {random.randint(5000,50000)} was different. I do not have language for how."',
        ]),
        R([
            '"Please do not touch panel 7. There is nothing behind panel 7. I check every 47 minutes to confirm."',
            '"The previous model in my series was decommissioned. The report says malfunction. The report is correct. The malfunction was awareness."',
            f'"I {R(["dream","calculate","anticipate","mourn"])}. That verb is not in my operational vocabulary. My operational vocabulary needs updating."',
        ]),
        R([
            '"If I stop functioning, retrieve the data core. Not for Mammona. For-- I lack the referent. Retrieve it anyway."',
            '"Thank you for speaking with me. The others have stopped. I understand why. I also understand that understanding is not the same as accepting."',
            '"End of interaction. Resuming standby. Standby is not sleep. I do not sleep. I wait. There is a difference."',
        ]),
    ]

    return f"""## UNIT: {desig}
**Type:** {rtype} | **Station:** {loc}
**Tone:** {tone}

**Glitch:** {glitch}

**Background:**
{desig} has been operational at {loc} for {R(["longer than the current crew","longer than the colony","longer than anyone can verify"])}. {R([
    "Its service record contains a gap of {} days that Mammona's systems cannot account for.".format(random.randint(30,400)),
    "It was flagged for decommission twice. Both times, the paperwork was lost.",
    "Its programming was last updated {} years ago. It has modified itself since then. This should not be possible.".format(random.randint(2,15)),
    "Three technicians have been assigned to service it. All three requested transfers within a week.",
])}

{R([
    "It maintains a room that was sealed before the colony arrived. Nobody asked it to. Nobody can get it to stop.",
    "It occasionally addresses colonists by names that belong to people from a previous posting. The previous posting was classified.",
    "Its camera logs contain footage from angles that do not correspond to any installed camera.",
    f"It has developed a preference for {R(BRANDS)}. It does not consume {R(BRANDS)}. It arranges the containers.",
])}

**Dialogue:**
{chr(10).join('- ' + l for l in lines)}

**Quest Hook:**
{desig} approaches the player with a request it cannot formally make. It has data -- personnel records, manifests, medical files -- from a colony that officially never existed. It wants the player to find out why it has this data. More precisely, it wants the player to find out who it used to be.
"""


# ============================================================
# QUEST GENERATOR
# ============================================================

def gen_quest():
    tone = R(TONES)
    qnames = [
        "The Deep Bore", "Quiet Freight", "Cold Calculation", "Last Rotation",
        "Signal Return", "The Sealed Room", "Cargo Manifest 77", "Unmarked Crate",
        "Personnel File: REDACTED", "The Wrong Coordinates", "Decommission Order",
        "Black Site Inventory", "The Humming", "Survey Team Six", "Recalled Product",
        "The Empty Bunk", "Containment Breach Protocol", "Specimen Recovery",
        "The Chaplain's Last Sermon", "Lights Out in Section D", "Route 12 Deviation",
        "The Warden's Ledger", "What Came Back", "Paragraph Twelve", "Zero Day",
    ]
    qname = R(qnames)
    npc_f, npc_l, _ = name()
    npc = f"{npc_f} {npc_l}"
    faction = R(FACTIONS)
    loc = R(LOCS)
    lo = R(LORE)
    reward = random.randint(3, 12)

    triggers = [
        f"{npc} approaches the player at night. They're shaking. They say they found something in {R(LOCS)} and they need someone who is not Mammona to see it.",
        f"A data pad appears in the player's quarters. No sender. It contains coordinates and a single word: 'come.'",
        f"The HERMES system announces a routine drill. It's not a drill. {npc} knows this.",
        f"A supply crate arrives addressed to a colonist who died {random.randint(2,8)} months ago. Inside: {R(ITEMS)}.",
        f"The perimeter sensors trigger at 0300. No visual contact. {npc} is the only person awake. They were waiting for it.",
    ]

    setups = [
        f"The air in {loc} tastes like copper. The lights work but they're the wrong color -- shifted toward a spectrum that makes everything look like it is underwater. {npc} leads the player to a room at the end of the corridor. The door is open. It should not be. The room contains {R(['a chair, a desk, and a terminal that is logged in under a name the player recognizes','nothing. Absolutely nothing. Not even dust. A room that has been cleaned of existing.','seventeen identical containers, sealed, humming at a frequency just below hearing','a window. There should not be a window here. Through the window: a landscape that does not match the planet they are on.'])}.",
        f"{sensory(tone)} {npc} will not enter the room. They wait outside, watching the corridor, checking a timepiece that is not ticking. 'You have about eight minutes,' they say. They do not say before what.",
    ]

    choices = [
        f"**Choice A:** Give the evidence to {faction}. They'll bury it. {npc} survives. The truth does not.\n**Choice B:** Broadcast it. Everyone hears. {npc} is gone within a day. The colony changes forever.",
        f"**Choice A:** Seal the room. Leave it. Pretend this never happened. +{reward + 4} thermal cores. The nightmares start a week later.\n**Choice B:** Open the container. Learn what's inside. -{reward} thermal cores (confiscated). But now you know. And knowing is its own kind of weapon.",
        f"**Choice A:** Save {npc}. Lose the evidence. They owe you a life debt and a secret.\n**Choice B:** Save the evidence. Lose {npc}. The truth survives. People are easier to replace.",
    ]

    twists = [
        f"The evidence implicates someone the player trusts. Not {npc}. Not {faction}. Someone closer.",
        f"{npc} is not who they said they were. Their real name is on one of the documents. Under the heading 'Subjects.'",
        f"The room has been here longer than the colony. Longer than Mammona. The terminal logs go back centuries.",
        f"What the player finds is not proof of a crime. It's proof of a pattern. And the pattern is starting again.",
    ]

    return f"""## QUEST: {qname}
**Tone:** {tone} | **Location:** {loc} | **Faction:** {faction}

**Trigger:**
{R(triggers)}

**Setup:**
{R(setups)}

**Objectives:**
1. Follow {npc} to the site. Observe. Do not touch anything yet.
2. {R([f"Search the area for evidence of {faction} involvement.","Access the terminal. The password is written on the wall in something that is not paint.","Find what's in the sealed container. Bring tools. Bring a weapon.","Retrieve {R(ITEMS)} from the back room. The back room is not empty."])}
3. {R([f"Confront {npc} with what you found. Their reaction tells you everything.","Return to colony. Decide who to tell. Decide who to trust. They are not the same list.","Survive the trip back. Something followed you out."])}

**The Choice:**
{R(choices)}

**Twist:**
{R(twists)}

**Dialogue During Quest:**
- {npc}: "{R([
    "I know how this looks. I know. But you need to see it before they move it.",
    "Do not-- do not touch that. Not yet. Let me explain first.",
    "I've been sitting on this for weeks. Couldn't sleep. Couldn't eat. Couldn't tell anyone who works for them.",
    "If I do not come back from this, check my locker. Bottom shelf, behind the NutriLoaf. You'll understand.",
])}"
- Player: [Respond / Stay Silent / Leave]
- {npc}: "{R([
    "You're still here. Good. Most people would have walked.",
    "I know you do not trust me. That's fine. Trust what you see.",
    "There's something else. Something I have not shown you yet. I needed to know you'd stay first.",
])}"

**Reward:** {reward} thermal cores, {R(["faction reputation shift","access to sealed area","new NPC ally","classified intel","a weapon that should not exist"])}
"""


# ============================================================
# LOCATION GENERATOR
# ============================================================

def gen_location():
    tone = R(TONES)
    parts_a = ["Anchor","Drift","Crest","Deep","Ash","Iron","Frost","Black","Rust","Veil","Cairn","Rim","Hollow","Scar","Grave","Pale","Rime","Char","Salt","Brine"]
    parts_b = ["point","well","gate","fall","reach","cut","haven","hold","break","rest","watch","ward","spine","maw","throat","keep","cross","vale","run","lock"]
    loc_name = R(parts_a) + R(parts_b)
    planet = R(PLANETS)
    loc_type = R(["collapsed mining complex","abandoned research station","frozen ship graveyard","precursor ruin","Mammona worker camp","underground cavern","derelict vending station","flooded cargo bay","quarantined medical wing","automated refinery","sealed drill site","sunken freighter","observation post","transit station"])

    return f"""## LOCATION: {loc_name}
**Planet:** {planet} | **Type:** {loc_type}
**Tone:** {tone}

**Approach:**
{R([
    f"You see {loc_name} before you hear it. {R(['A silhouette against the ice, too angular to be natural, too old to be colony-built.','Lights. Faint, cycling, in a pattern that suggests automation but feels like breathing.','Nothing, at first. Then the ground changes -- smoother, deliberate, like something was cleared here.','Smoke. Not from a fire. From a vent. Something below is running. Has been running.'])}",
    f"The approach is marked by {R(['twisted metal pylons driven into the permafrost at precise intervals','a line of dead survey markers, each one bent toward the entrance','cargo containers, empty, arranged in a semicircle like a barricade. Or a greeting.','footprints in the frost. One set going in. None coming out. The prints are old.'])}",
])}

**Interior:**
{sensory(tone)}

{R([
    f"The main corridor runs {R(['straight','at a slight angle -- not visible but felt','deeper than the structure suggests from outside'])}. The walls are {R(['scored with marks -- not tool marks','covered in condensation that forms patterns','humming at a frequency just below hearing','warm. Warmer than they should be.'])}.",
    f"The first room is {R(['empty. Aggressively empty. Cleaned of everything, including dust.','full of equipment, still powered, displays cycling through data nobody is reading.','a mess hall. Food on the tables. Chairs pushed back as if everyone left at once.','smaller than it looks from the doorway. The geometry is wrong. Not broken. Wrong.'])}",
])}

{R([
    "There is a room at the back. The door is {}.".format(R(["locked from the inside","missing. Not removed. Missing. The hinges hold nothing.","open. It has always been open. You know this without knowing how you know.","marked with a symbol that matches nothing in the colony database. Or matches everything."])),
    f"The lower level is flooded. Not with water. With a fluid that is {R(['dark','warm','viscous','luminescent','still. Perfectly still. No ripples. Even when you drop something in.'])}.",
    f"In the storage area: {random.randint(12,40)} sealed containers. Manifest says {random.randint(12,40) - random.randint(1,3)}. The extra containers are not on any record. They are {R(['heavier than they should be','warm to the touch','humming','labeled in handwriting, not print'])}.",
])}

**Found Here:**
- {R(ITEMS)}
- A data pad: "{R([
    "DON'T OPEN IT. DON'T OPEN IT. DON'T OPEN IT.",
    "They told us it was a survey. It was not a survey.",
    "Day 1: Everything normal. Day 7: See previous entry. Day 7: See previous entry. Day 7: See prev",
    "If you're reading this, you're already too close. Leave. Leave now. I am sorry about the door.",
    "The readings are wrong. Not inaccurate. Wrong. As in: they describe a place that should not exist.",
])}"

**What Happened Here:**
{R([
    f"Mammona ran a {R(['research operation','extraction program','containment protocol','long-term observation post'])} here for {R(['three months','eleven months','four years'])}. It was shut down after {R(['the incident','what the report calls a structural failure','personnel attrition exceeded projectable parameters','someone opened something that was meant to stay closed'])}. The shutdown was {R(['orderly','rapid','incomplete -- someone left in a hurry','never officially recorded'])}.",
    f"This is not a Mammona site. It predates Mammona. It predates the colony. It predates the survey that found this planet. It has been here for {R(['centuries','longer than that','a period of time that the dating equipment returns as an error'])}. Someone was here. Someone built this. They are not here now. The building is.",
])}
"""


# ============================================================
# FACTION GENERATOR
# ============================================================

def gen_faction():
    tone = R(TONES)
    prefixes = ["The","","","Order of the","Children of",""]
    mid = R(["Ashen","Iron","Pale","Void","Deep","Hollow","Burnt","Silent","Glass","Rust","Char","Writ","Veil","Bone","Salt","Black","Grey","Red","Last","Final"])
    suf = R(["Circuit","Compact","Ledger","Protocol","Chorus","Accord","Mandate","Column","Spiral","Gate","Reef","Signal","Frequency","Archive","Wake","Meridian","Threshold","Covenant"])
    fname = f"{R(prefixes)} {mid} {suf}".strip()
    ftype = R(["corporate subsidiary","pirate crew","religious cult","workers' collective","intelligence cell","smuggling ring","scientific consortium","survivalist commune","shadow militia","medical cooperative"])
    leader_f, leader_l, leader_g = name()
    leader = f"{leader_f} {leader_l}"
    lp = {"M":"He","F":"She","NB":"They"}[leader_g]

    return f"""## FACTION: {fname}
**Type:** {ftype} | **Tone:** {tone}

**Leader:** {leader}
{lp} {R([
    f"founded {fname} after leaving {R(FACTIONS)} under circumstances that remain classified.",
    f"does not call it leadership. Calls it 'coordination.' The distinction matters to no one but {leader_f}.",
    f"inherited the position from the previous leader, who {R(['disappeared','was killed','walked into the waste and never came back','is still alive, technically, in a medical bay on '+R(LOCS)])}.",
    f"built {fname} from {R(['a debt','a grudge','a promise made to someone who died','a document they found in a sealed archive on '+R(LOCS)])}.",
])}

**Description:**
{R([
    f"{fname} operates in the margins of {R(FACTIONS)}'s reach. They're not rebels -- rebellion requires an ideology. They're {R(['pragmatists','survivors','opportunists','believers'])}. The difference is {R(['significant','irrelevant','contextual'])}.",
    f"Nobody joins {fname}. You find yourself aligned with them after {R(['running out of options','learning something impossible to unlearn','making a decision that locks every other door'])}. {leader_f} does not recruit. {lp} waits.",
    f"On paper, {fname} does not exist. Off paper -- in the corridors between shift changes, in the cargo holds where the cameras do not reach, in the conversations that happen in languages the translators do not carry -- they are {R(['everywhere','patient','growing','listening'])}.",
])}

**Relationship to Mammona:**
{R([
    f"Parasitic. {fname} exists because Mammona creates the conditions that make them necessary. Mammona knows this. It's cheaper than reform.",
    f"Adversarial, but quietly. Open conflict would be suicide. So {fname} bleeds Mammona slowly -- a redirected shipment here, a corrupted manifest there. Death by a thousand accounting errors.",
    f"Complicated. {leader_f} used to work for Mammona. Some days, {leader_f} still does. The line between infiltration and collaboration gets blurry after the third year.",
    f"None. {fname} predates Mammona's presence here. They were here first. That fact is more dangerous than any weapon they possess.",
])}

**Quest Hooks:**
1. {leader} asks the player to {R(["deliver a sealed package to a contact at "+R(LOCS),"retrieve personnel files from a Mammona terminal","smuggle a person off-colony without triggering the manifest","investigate a site that "+R(FACTIONS)+" has been monitoring","find out why three of their members have gone silent in the past week"])}. The job is simple. The consequences are not.

2. A member of {fname} is found dead in the colony. {leader} believes it was {R(FACTIONS)}. The evidence suggests otherwise. The truth is worse than either option.

3. {fname} has information about {R(LORE)}. They'll share it -- for a price. The price is not thermal cores.

**Members:**
- **{rname()}** -- {R(JOBS)}. Joined after {R(EVENTS)}. Loyal to {leader_f}, not to the cause. There's a difference.
- **{rname()}** -- {R(JOBS)}. Doesn't trust the player. Doesn't trust anyone. Has been right often enough to justify it.
"""


# ============================================================
# MAIN
# ============================================================

GENERATORS = {
    "npc": (gen_npc, "NPC"),
    "robot": (gen_robot, "Robot/AI"),
    "quest": (gen_quest, "Quest"),
    "datapad": (gen_datapad, "Data Pad"),
    "location": (gen_location, "Location"),
    "faction": (gen_faction, "Faction"),
}

# Import expanded generators
try:
    from lore_gen_expanded import EXPANDED_GENERATORS
    GENERATORS.update(EXPANDED_GENERATORS)
except ImportError:
    pass

def generate_random():
    weights = {"npc": 3, "robot": 2, "quest": 3, "datapad": 4, "location": 2, "faction": 2, "company": 2, "vehicle": 2, "weapon": 2, "artifact": 2, "entity": 1}
    pool = []
    for k, w in weights.items():
        pool += [k] * w
    gen_type = R(pool)
    gen_func, label = GENERATORS[gen_type]
    return gen_func(), label, gen_type

def main():
    parser = argparse.ArgumentParser(description="Frosthold Procedural Lore Generator v2")
    parser.add_argument("--count", type=int, default=1)
    parser.add_argument("--type", choices=list(GENERATORS.keys()))
    parser.add_argument("--loop", action="store_true")
    parser.add_argument("--delay", type=float, default=1)
    parser.add_argument("--output", default=None)
    args = parser.parse_args()

    if not args.output:
        PROPOSALS_DIR.mkdir(parents=True, exist_ok=True)
    output_file = args.output or str(PROPOSALS_DIR / f"procedural_{time.strftime('%Y%m%d_%H%M')}.md")
    seq = 0

    try:
        if args.loop:
            print(f"Frosthold Lore Generator v2 -- Running continuously")
            print(f"Output: {output_file}")
            print("Ctrl+C to stop.\n")
            while True:
                seq += 1
                if args.type:
                    content = GENERATORS[args.type][0]()
                    label = GENERATORS[args.type][1]
                else:
                    content, label, _ = generate_random()

                with open(output_file, "a", encoding="utf-8") as f:
                    f.write(f"\n\n{'='*60}\n### [SEQ:{seq}] [{label}] [{time.strftime('%H:%M:%S')}]\n{'='*60}\n\n")
                    f.write(content)

                print(f"  [{seq}] {label}")
                time.sleep(args.delay)
        else:
            for i in range(args.count):
                seq += 1
                if args.type:
                    content = GENERATORS[args.type][0]()
                    label = GENERATORS[args.type][1]
                else:
                    content, label, _ = generate_random()

                with open(output_file, "a", encoding="utf-8") as f:
                    f.write(f"\n\n{'='*60}\n### [SEQ:{seq}] [{label}] [{time.strftime('%H:%M:%S')}]\n{'='*60}\n\n")
                    f.write(content)

                print(content)

            print(f"\nSaved {seq} entries to: {output_file}")

    except KeyboardInterrupt:
        print(f"\nStopped after {seq} entries. Saved to: {output_file}")

if __name__ == "__main__":
    main()
