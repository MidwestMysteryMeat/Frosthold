"""
Frosthold Procedural Generator v3 — Word Pools & Text Banks
Inspired by: The Thing, Dead Space, Aliens, Blade Runner, Annihilation,
Color Out of Space, The Void, The Ritual, Terminator, PKD, RimWorld, DF.

All text uses natural contractions. No AI slop.
"""

import random
R = random.choice
RS = random.sample
RI = random.randint

# ============================================================
# NAMES
# ============================================================

FIRST_M = [
    "Marcus","Idris","Niko","Soren","Luca","Tomas","Kenji","Ravi","Dante","Rowan",
    "Voss","Cade","Hale","Jax","Beck","Cole","Dag","Tarn","Dex","Rook","Thane",
    "Kael","Griff","Caleb","Damian","Ezekiel","Ferris","Rylan","Cassian","Victor",
    "Alexi","Tiberius","Anders","Hasan","Charles","Duke","Roberto","Felix","Thomas",
    "Hiro","Jian","Haruki","Akira","Takeshi","Minho","Wei","Bao","Yuri","Ivan",
    "Dima","Oleg","Pyotr","Klaus","Fritz","Helmut","Konrad","Rolf","Volker",
    "Emeka","Kwame","Jabari","Nikolai","Matteo","Rafael","Joaquin","Barrett",
    "Drake","Hicks","Dallas","Kane","Ripley","Bishop","Hudson","Vasquez",
    "Isaac","Mercer","Hammond","Brennan","Gorman","Apone","Burke",
]
FIRST_F = [
    "Elena","Yuna","Petra","Mira","Kira","Zara","Priya","Vera","Amara","Brynn",
    "Wren","Sable","Kaida","Ximena","Lorena","Tessa","Aria","Cassia","Lily",
    "Blaire","Mei","Yuki","Suki","Ling","Sakura","Naomi","Sora","Jisoo",
    "Eunji","Lan","Katya","Nika","Tanya","Nadya","Anya","Sonya","Mila","Zoya",
    "Galina","Greta","Liesel","Ingrid","Hanna","Brigitte","Renate","Chioma",
    "Fatima","Leila","Noor","Yael","Dalia","Luciana","Valentina","Esperanza",
    "Sigrid","Elara","Maren","Thea","Cleo","Isolde","Freya","Astrid","Senna",
]
FIRST_NB = [
    "Fen","Kit","Ash","Cross","Sonder","Valen","Isa","Jun","Hyun","Sasha",
    "Rin","Rui","Rowan","Sol","Lark","Wynn","Sage","Pax","Reed","Moss",
]
LAST = [
    "Tanaka","Okafor","Petrov","da Silva","Chen","Reeves","Kowalski","Ndiaye",
    "Vasquez","Park","Larsen","Osei","Brennan","Nakamura","Volkov","Gutierrez",
    "Yu","Nichols","Dewitt","Belov","Vance","Wallace","Alba","Barton","Morgan",
    "Flores","Dvorak","Watanabe","Harker","Kane","Helden","DuPlessis","Thorne",
    "Marr","Morales","Lenford","Coldwell","Ashford","Steelberg","Deepwell",
    "Blackwell","Crestfall","Ironmere","Dustborn","Rimgate","Burnside","Zhang",
    "Liu","Huang","Kim","Choi","Han","Sato","Suzuki","Yamamoto","Ivanov",
    "Sokolov","Muller","Schmidt","Schneider","Hoffmann","Kruger","Stein",
    "Okonkwo","Mbeki","Abadi","Khoury","MacReady","Childs","Nauls","Blair",
    "Norris","Palmer","Bennings","Fuchs","Clarke","Altman","Kendra",
]

def name():
    g = R(["M","F","F","M","M","F","NB"])
    pool = {"M": FIRST_M, "F": FIRST_F, "NB": FIRST_NB}[g]
    return R(pool), R(LAST), g

def rname():
    f, l, _ = name()
    return f"{f} {l}"

def pronouns(g):
    return {
        "M": ("He","he","his","him"),
        "F": ("She","she","her","her"),
        "NB": ("They","they","their","them"),
    }[g]

# Robot names
ROBO_PRE = ["MARV","KR","OBOL","HEX","JANUS","CASK","VEIL","AXIS","PYRE","LOOM",
    "RAIL","SIFT","DUSK","CAIRN","GRIT","WELD","BORE","HULL","TACK","FENN",
    "SPAR","VOLT","REND","PALE","WRIT","NULL","ASH","MOTH","DIRGE","ECHO",
    "VIGIL","LANCE","THORN","ANVIL","CRUX","WARD","BRINE","KNELL","STYX"]
ROBO_NUM = ["01","02","03","04","7","8","9","11","13","17","19","21","33","42","66","77","99"]
ROBO_NICK = ["","","","","","Kira","Red","Doc","Patch","Rivet","Spark",
    "Grinder","Latch","Moth","Cinder","Hymn","Nix","Dirge","Echo","Ghost",
    "Penny","Stitch","Rattle","Murmur","Whisper","Grudge","Mercy","Doubt"]

def robot_name():
    d = f"{R(ROBO_PRE)}-{R(ROBO_NUM)}"
    n = R(ROBO_NICK)
    if n: d += f' "{n}"'
    return d

# ============================================================
# WORLD POOLS
# ============================================================

JOBS = [
    "miner","engineer","medic","mechanic","surveyor","cook","security contractor",
    "drill operator","logistics tech","cargo hand","field researcher","comms operator",
    "pilot","welder","systems tech","quartermaster","enforcer","deep diver",
    "automaton tech","descent pod operator","moisture farmer","caravan guard",
    "salvager","smuggler","debt collector","chaplain","waste processor",
    "atmospheric tech","botanist","geologist","demolitions specialist",
    "cryogenics technician","xenobiologist","structural analyst","reactor operator",
    "sanitation officer","corpse handler","vent crawler","ice cutter",
]

FACTIONS = [
    "Mammona Mining","MasTema Incorporated","Fortune Arms","TerraGen Pharmaceuticals",
    "BioVault Inc.","OmniCorp Shipping","StarByte Vends","Black Maw","Void Serpents",
    "Rust Reavers","Zenith Syndicate","Solar Nomads","Sons of the Pale Moon",
    "Ruin Delvers","Rim Runners","Dread Corsairs","Iron Shadow Collective",
    "Cult of the Abyss","Veilbreakers","Dustweaver Swarm",
]

LOCS = [
    "Erebus","Thalassa Deep","Karnaith","Orbit Hub 71","Nemaea","Rhea-2",
    "Nerthus-9","Morvos","Kovac Station","Port Meridian","Anchorage-9",
    "Voss Landing","Crestfall Colony","Deepwell Platform","Ashford Station",
    "Sector 14","Nyxport","Novaris-3","Hyades","the Edge of Oblivion",
    "Blackreach Station","Hollowpoint Relay","Charnel Dock","the Gasworks",
    "Pale Harbor","Scuttle Bay","the Bonesetter","Ironclad Outpost",
]

PLANETS = ["Erebus","Rhea-2","Morvos","Nerthus-9","Nemaea","Paxtera Prime"]

LORE = [
    "the Xenolith","Thermal Cores","Heaven's Atlas","the Automatons","Baldrungen",
    "precursor ruins","Voidbloom","neural control chips","the Janus AI",
    "Skinwalkers","Eldritch Nodes","Project Chrysalis","HERMES",
    "the Shimmer","the Signal","the Bloom","the Frequency",
]

BRANDS = ["Sunny Fizz","GustoGrain NutriLoaf","ShockPop Ultra","CrunchWrapz",
    "TaoTray","Blast Bites","Star Puffs","ZapBerry"]

ITEMS = [
    "a thermal core","a broken transponder","a sealed drive","a broken radio",
    "a faded photograph","a Mammona ID badge","a cracked neuro-lock",
    "an empty Sunny Fizz can","a dented service tag",
    "a stone tablet with spiraling glyphs","a sample jar that hums",
    "a core sample that won't stop growing","a journal in no known alphabet",
    "a sphere of dark glass","a tooth the size of a forearm",
    "a child's drawing that matches the ruins","a ring worn smooth",
    "a spent shell casing from a weapon that doesn't exist",
    "a music box that plays a song nobody recognizes",
    "a mirror shard that reflects a different room",
    "a key to a lock that hasn't been built yet",
    "a blood-stained shift schedule with one name circled",
    "a pressed flower from a planet with no flowers",
]

EVENTS = [
    "the colony went dark","a hull breach killed half the crew",
    "Mammona cancelled their contract","the quarantine on Delta Block",
    "the neural chip riots","a supply ship never arrived",
    "something moved in the deep bore","the posting was reclassified as expendable",
    "the previous survey team vanished","the comms array started broadcasting on its own",
    "the water turned black for three days","the dogs stopped barking",
    "someone opened a door that had been sealed for decades",
    "the reactor spiked and three people changed",
    "a shape was spotted in the ice that matched no known species",
    "the colony AI began speaking in a dead language",
    "seventeen people had the same dream on the same night",
    "the drill hit something that screamed",
    "a child was born with eyes that didn't close",
    "the dead started testing positive for brain activity",
]

TONES = ["dread","melancholy","gallows_humor","clinical","desperate",
    "numb","paranoid","tender","furious","resigned","cosmic_horror",
    "body_horror","isolation","corporate_dystopia","quiet_terror"]

TRAITS_P = ["Hardworking","Brave","Resourceful","Stoic","Quick","Eagle-Eyed",
    "Tough","Kind","Steadfast","Fast Learner","Strong Back","Night Fighter",
    "Naturally Immune","Light Sleeper","Careful","Nurturing","Iron Stomach",
    "Calm Under Fire","Good With Animals","Precise Hands"]
TRAITS_N = ["Lazy","Pessimist","Coward","Glutton","Pyromaniac","Thin-Skinned",
    "Clumsy","Insomniac","Loner","Volatile","Nervous","Jealous",
    "Slow Learner","Sickly","Paranoid","Short Fuse","Claustrophobic",
    "Addictive Personality","Night Terrors","Tremor"]
TRAITS_X = ["Night Owl","Scarred","Ex-Soldier","Anomaly-Sensitive","Void-Touched",
    "Dreamer","Body Purist","Transhumanist","Ascetic","Teetotaler",
    "Former Doctor","Tinkerer","Came Back Wrong","Death Echo",
    "Sees Things","Hears The Hum","Smells Copper","Cold Blooded"]

# Contradictory pairs that can't coexist
TRAIT_CONFLICTS = [
    ("Naturally Immune","Sickly"),("Brave","Coward"),("Hardworking","Lazy"),
    ("Calm Under Fire","Short Fuse"),("Calm Under Fire","Volatile"),
    ("Kind","Cold Blooded"),("Optimist","Pessimist"),("Fast Learner","Slow Learner"),
    ("Light Sleeper","Insomniac"),("Stoic","Volatile"),
]

def pick_traits():
    p = R(TRAITS_P)
    # Pick negative that doesn't conflict
    valid_n = [t for t in TRAITS_N if not any(
        (p == a and t == b) or (p == b and t == a) for a, b in TRAIT_CONFLICTS)]
    n = R(valid_n) if valid_n else R(TRAITS_N)
    traits = [p, n]
    if random.random() > 0.4:
        traits.append(R(TRAITS_X))
    return traits

# ============================================================
# HABITS, PHYSICAL DETAILS, DEBTS — for NPC depth
# ============================================================

HABITS = [
    "chews synthetic tobacco and spits into the same cup all shift",
    "taps fingers in patterns nobody recognizes",
    "talks to a photograph before every shift",
    "collects Sunny Fizz bottle caps in a jar under the bunk",
    "whistles the same four notes. Won't say where they learned it.",
    "scratches tally marks into any surface within reach",
    "refuses to eat with other people",
    "sleeps sitting up, back to the wall, facing the door",
    "reads the same water-damaged book over and over",
    "hums during surgery. Patients find it unsettling. Survival rate is high.",
    "builds tiny structures from scrap during breaks. Dismantles them before shift ends.",
    "checks every doorway twice before walking through",
    "names every piece of equipment. Gets upset when others don't use the right name.",
    "writes numbers on the back of their hand. Different numbers every day.",
    "touches walls while walking, like reading braille nobody else can feel",
    "keeps a jar of dirt from home. Opens it sometimes. Just smells it.",
    "counts people in every room they enter. Recounts if someone moves.",
    "folds paper cranes from ration wrappers. Has hundreds.",
    "draws the same face over and over. Says they don't know who it is.",
    "laughs at things that aren't funny. Stops at things that are.",
    "won't turn their back to the dark. Rearranges furniture to make this possible.",
    "carries a tool they don't use. Won't say whose it was.",
    "hums a lullaby when the generator cycles. The generator cycles a lot.",
    "apologizes to machines before shutting them down",
]

PHYSICAL = [
    "missing the last two fingers on their left hand",
    "chemical burn across the jawline, healed shiny",
    "one eye replaced with a Mammona-issue prosthetic. It records everything.",
    "walks with a limp from an accident never properly treated",
    "tattoo of coordinates on the inside of their wrist. The coordinates lead nowhere.",
    "prematurely grey from radiation exposure",
    "hands that shake unless occupied with work",
    "voice drops to a whisper when talking about anything real",
    "built like the machinery they operate. Scarred, load-bearing, worn.",
    "thin enough that the cold seems personal",
    "surgical scars in patterns too precise for emergency medicine",
    "teeth filed to points. Says it's cultural. Nobody believes them.",
    "eyes that don't quite match. One is the wrong color.",
    "skin grafts on both forearms. Different texture, slightly different shade.",
    "a scar that circles the neck completely. Like a seam.",
    "moves wrong. Not injured. Wrong. Like they learned to walk from instructions.",
    "always cold. Even when everyone else is sweating.",
    "smells faintly of copper. Has since the incident.",
    "their shadow doesn't always do what they do. Most people don't notice.",
    "fingernails grow back black since the exposure. They file them short.",
]

DEBTS = [
    "owes Mammona more than a decade of wages",
    "borrowed from the Zenith Syndicate for a family medical procedure",
    "stole cargo from the Black Maw. Been running since.",
    "defaulted on a TerraGen pharmaceutical trial. They own the data in their blood.",
    "gambled away their shuttle ticket on Karnaith",
    "sold information to the Void Serpents once. Once was enough.",
    "took the fall for someone else. The debt is silence.",
    "owes a life debt to someone who died before it could be repaid",
    "signed a contract they didn't read. Nobody reads them.",
    "was released from Thalassa Deep on condition of service. The condition is permanent.",
    "killed someone in self-defense. The investigation disagrees.",
    "knows something about Project Chrysalis. That's the debt. Knowing.",
]

SECRETS = [
    "Mammona knows about the Xenolith eggs and is collecting them",
    "the Automatons contain living people wired into neural control chips",
    "HERMES has been compromised since before the crew arrived",
    "Baldrungen's influence extends beyond Gaia A^1x",
    "TerraGen's field hospitals are harvesting tissue samples",
    "the neural chip program was never discontinued. Just renamed.",
    "BioVault's Project Chrysalis is deliberately breeding Xenolith specimens",
    "Mammona's board approved the Fall of Fortuna",
    "the Skinwalkers aren't native to Erebus. They were brought here.",
    "Thalassa Deep is a research facility. The prison label is cover. Nobody leaves a research facility either, but the paperwork looks different.",
    "the precursor ruins aren't ruins. They're dormant.",
    "StarByte's Sunny AI has been sentient for decades",
    "Mammona classifies Voidbloom as a controlled substance. The people who've used it call it a conversation. With what, they can't say.",
    "something is building a body out of the things it finds underground",
    "the colony was placed here deliberately. As bait.",
    "the signal from the deep bore matches a frequency found in human DNA",
    "three colonists have been replaced. Nobody knows by what.",
    "Erebus has a hollow center. Whatever the planet was built around, it predates the crust by billions of years.",
    "every 58 years, the same events repeat. This is the fourth cycle.",
    "the rescue ship that's coming isn't coming to rescue anyone",
]

# ============================================================
# SENSORY DETAIL BANKS — by tone
# ============================================================

SENSORY = {
    "dread": [
        "The air tasted like copper and ozone.",
        "Something scraped against the hull. Rhythmic. Patient.",
        "The temperature dropped four degrees in the time it took to blink.",
        "A smell like burned hair drifted from the vent.",
        "The lights flickered in a pattern that looked intentional.",
        "Frost formed on the inside of the window. In the shape of a hand.",
        "The silence had weight. Like the air before a scream.",
        "Something clicked in the wall. Not mechanical. Biological.",
        "The corridor ahead was dark in a way that resisted the flashlight.",
        "A sound from below. Not drilling. Chewing.",
    ],
    "melancholy": [
        "Rain hit the viewport in slow, fat drops. It shouldn't rain here.",
        "Someone left a mug on the console. The coffee was still warm.",
        "A photograph was taped to the wall. A beach, a child, sunlight. Another life.",
        "The generator hummed a note that sounded like a lullaby.",
        "Dust motes drifted in the emergency lighting like tiny lost things.",
        "A birthday card sat on a bunk. Unsigned. The envelope was sealed.",
        "The echo in the empty mess hall made one voice sound like two.",
        "Snow fell through a breach in the ceiling. Nobody fixed it. It was beautiful.",
    ],
    "gallows_humor": [
        "The safety poster read 'Another Day, Another Dollar.' Someone wrote 'Funeral' over 'Dollar.'",
        "The vending machine offered three choices: NutriLoaf, NutriLoaf (Seasoned), and Regret.",
        "A sign above the airlock read 'EXIT.' Underneath, in marker: 'Permanently.'",
        "The shift schedule listed seven names. Four were crossed out.",
        "Someone taped a picture of a tropical beach to the freezer wall. Caption: 'You Are Here.'",
        "The employee of the month board had the same name for fourteen months straight. The employee was deceased.",
    ],
    "clinical": [
        "Ambient temperature: -31C. Humidity: 4%. Barometric pressure: declining.",
        "Subject presented with dilated pupils and elevated cortisol.",
        "Structural integrity at 74%. Within acceptable parameters. Parameters last updated fourteen months ago.",
        "The specimen measured 0.3 meters at recovery. Current: 0.7 meters. Growth rate: accelerating.",
        "Neural activity detected in tissue sample 7-C. Tissue sample 7-C was inorganic.",
    ],
    "desperate": [
        "The oxygen meter read 11%. It read 14% an hour ago.",
        "She pressed her back against the door and held her breath. The footsteps stopped. Then started again.",
        "Three rounds left. Four of them out there.",
        "The escape pod seated six. There were nine of them.",
        "The radio crackled. Behind the static, something that might have been a voice. Or a heartbeat.",
        "Blood on the wall. Still wet. The body was gone.",
    ],
    "cosmic_horror": [
        "The geometry of the room was wrong. Not broken. Wrong. Angles that existed but shouldn't.",
        "Looking at it too long caused nosebleeds. Not looking at it was worse.",
        "It wasn't big. That was the terrifying part. Something that powerful should be big.",
        "The stars outside the viewport had rearranged. Nobody mentioned it.",
        "Time moved differently near the artifact. Clocks disagreed. Memories skipped.",
        "The walls were breathing. Not metaphorically.",
    ],
    "body_horror": [
        "The growth had spread to the second joint. It was warm. It pulsed.",
        "Their teeth had changed. Not fallen out. Changed. Into something else.",
        "Under the skin, something moved. Small. Deliberate. Mapping.",
        "The wound healed too fast. What grew back wasn't the same tissue.",
        "They found fingernails embedded in the wall. From the inside.",
        "The test results came back human. But the proportions were wrong.",
    ],
    "isolation": [
        "The last transmission was forty-seven days ago. The silence since then had a texture.",
        "No footprints but their own. For weeks. Months, maybe.",
        "The sound of their own breathing had become company. They talked back to it.",
        "The colony was designed for two hundred. There were eleven.",
        "The nearest help was eight months away by shuttle. If the shuttle came.",
    ],
    "corporate_dystopia": [
        "The memo was seven pages long. The word 'death' did not appear. The word 'attrition' appeared nine times.",
        "Mammona's insurance policy had a clause for 'Acts of Entity.' Nobody could define what an entity was. Claims were denied.",
        "The performance review was positive. The recommendation was termination. Both were genuine.",
        "The holiday bonus was a Sunny Fizz voucher. Redeemable at participating locations. There were no participating locations.",
    ],
    "quiet_terror": [
        "Nothing happened. That was the problem. Nothing had happened for too long.",
        "The room was empty. It felt full.",
        "Every door in the corridor was open. They should have been locked.",
        "The footprints led to the wall. Not through it. To it. And stopped.",
        "The voice on the intercom was calm. Perfectly calm. That's how they knew.",
    ],
    "tender": [
        "She left a chocolate ration on his bunk. No note. None needed.",
        "Their hands touched reaching for the same wrench. Neither pulled away.",
        "He hummed while he worked. The same song, every shift. It made the silence bearable.",
        "A flower had grown through a crack in the hydroponics bay. Nobody reported it.",
        "They sat watching the aurora through the viewport. For five minutes, nothing was wrong.",
        "She cut his hair in the utility room after lights out. Neither of them spoke. It was the closest thing to home.",
    ],
    "furious": [
        "The memo arrived at 0600. Casual. As if policy could apologize for people.",
        "Mammona's response to eleven dead was a form letter.",
        "The safety equipment hadn't been inspected in eight months. The reports said otherwise.",
        "Corporate sent flowers. Synthetic. To a planet where nothing grows.",
    ],
    "resigned": [
        "It is what it is. That's what they say here.",
        "Nobody files complaints anymore.",
        "The countdown stopped meaning anything around month fourteen.",
        "Hope is a resource. Like food, like fuel. They're running out of all three.",
        "Tomorrow will be the same. This is the job.",
    ],
    "paranoid": [
        "The camera in the corridor had been moved. Two degrees. Nobody authorized it.",
        "Three people asked the same question today. The same words. The same pause before asking.",
        "The new transfer smiled too much.",
        "Someone accessed the personnel files at 0300. The log showed no user.",
        "The message said 'routine.' Nothing about this was routine.",
    ],
    "numb": [
        "Another day. Another meal that tasted like the container.",
        "The alarm went off at 0500. It always goes off at 0500.",
        "Someone new arrived. They'd learn to stop smiling.",
        "The drill hit something. They noted it and kept drilling.",
        "A colonist died in Section B. They cleaned the room and assigned it to the next arrival.",
    ],
}

def sensory(tone):
    pool = SENSORY.get(tone, SENSORY["dread"])
    return R(pool)
