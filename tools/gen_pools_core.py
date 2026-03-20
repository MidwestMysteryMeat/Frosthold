"""
Frosthold Procedural Generator v3 -- Core Data Pools
All structured, tripled, lore-grounded data for procedural content generation.

Source of truth: lore/LORE_BIBLE.md
Tone: The Thing, Dead Space, Aliens, Blade Runner, Annihilation. Corporate dystopia.
      Lovecraftian cosmic horror. Grim, textured, literary.
All text uses natural contractions. No AI slop.
"""

import random

R = random.choice
RS = random.sample
RI = random.randint


def pronouns(g):
    return {
        "M": ("He", "he", "his", "him"),
        "F": ("She", "she", "her", "her"),
        "NB": ("They", "they", "their", "them"),
    }[g]


# ============================================================
# NAMES — ~100 male, ~100 female, ~25 NB, ~80 last
# ============================================================

FIRST_M = [
    # Lore-canonical
    "Cassian", "Thane", "Alaric", "Victor", "Hasan", "Charles", "Duke",
    # Western / European
    "Marcus", "Soren", "Luca", "Dante", "Rowan", "Cade", "Hale", "Jax", "Beck",
    "Cole", "Dag", "Tarn", "Dex", "Rook", "Kael", "Griff", "Caleb", "Damian",
    "Ezekiel", "Ferris", "Rylan", "Alexi", "Tiberius", "Anders", "Roberto",
    "Felix", "Thomas", "Barrett", "Drake", "Matteo", "Rafael", "Joaquin",
    "Nikolai", "Voss", "Griffin", "Niko",
    # East Asian
    "Hiro", "Jian", "Haruki", "Akira", "Takeshi", "Minho", "Wei", "Bao",
    "Kenji", "Ravi", "Tomas",
    # Slavic / Eastern European
    "Yuri", "Ivan", "Dima", "Oleg", "Pyotr", "Sergei",
    # Germanic
    "Klaus", "Fritz", "Helmut", "Konrad", "Rolf", "Volker",
    # African
    "Emeka", "Kwame", "Jabari", "Adisa", "Kofi",
    # Latin American / Iberian
    "Santiago", "Mateo", "Diego", "Esteban", "Raul",
    # Middle Eastern / South Asian
    "Omar", "Rashid", "Tariq", "Arjun", "Dev", "Sanjay",
    # Film-canonical (The Thing, Aliens, Dead Space)
    "Ripley", "Bishop", "Hudson", "Dallas", "Kane",
    "Isaac", "Mercer", "Hammond", "Brennan", "Gorman", "Apone", "Burke",
    "Hicks",
    # Additional fill to 100+
    "Silas", "Gage", "Orion", "Beckett", "Knox", "Jensen",
    "Amir", "Lev", "Dorian", "Caspian", "Torin", "Callum",
]

FIRST_F = [
    # Lore-canonical
    "Tessa", "Jessa", "Amara",
    # Western / European
    "Elena", "Petra", "Mira", "Kira", "Zara", "Vera", "Brynn", "Wren",
    "Sable", "Kaida", "Ximena", "Lorena", "Aria", "Cassia", "Lily",
    "Blaire", "Sigrid", "Elara", "Maren", "Thea", "Cleo", "Isolde",
    "Freya", "Astrid", "Senna", "Helene", "Colette", "Margaux",
    # East Asian
    "Yuna", "Mei", "Yuki", "Suki", "Ling", "Sakura", "Naomi", "Sora",
    "Jisoo", "Eunji", "Lan", "Hana", "Rin",
    # Slavic / Eastern European
    "Katya", "Nika", "Tanya", "Nadya", "Anya", "Sonya", "Mila", "Zoya",
    "Galina", "Irina", "Dasha",
    # Germanic / Scandinavian
    "Greta", "Liesel", "Ingrid", "Hanna", "Brigitte", "Renate",
    # African
    "Chioma", "Adaeze", "Amina", "Zuri", "Nkechi",
    # Middle Eastern / South Asian
    "Fatima", "Leila", "Noor", "Yael", "Dalia", "Priya", "Anaya", "Saira",
    # Latin American / Iberian
    "Luciana", "Valentina", "Esperanza", "Camila", "Paloma", "Marisol",
    # Additional fill to 100+
    "Nyx", "Vesper", "Marlowe", "Theron", "Callista", "Linnea",
    "Devi", "Mirabel", "Solene", "Nadia", "Odessa", "Lark",
    "Althea", "Saskia", "Ember", "Briar", "Keziah", "Minerva",
    "Dagny", "Corinna", "Lysandra",
]

FIRST_NB = [
    "Fen", "Kit", "Ash", "Cross", "Sonder", "Valen", "Isa", "Jun", "Hyun",
    "Sasha", "Rin", "Rui", "Rowan", "Sol", "Lark", "Wynn", "Sage", "Pax",
    "Reed", "Moss", "Tor", "Aven", "Cass", "Quinn", "Ryn", "Briar",
]

LAST = [
    # Lore-canonical
    "Vale", "Dranth", "Venin", "Rathmore", "MacReady", "Childs", "Clarke",
    "Altman", "Kendra",
    # East Asian
    "Tanaka", "Nakamura", "Watanabe", "Sato", "Suzuki", "Yamamoto",
    "Zhang", "Liu", "Huang", "Chen", "Yu",
    "Kim", "Choi", "Han", "Park",
    # African
    "Okafor", "Osei", "Ndiaye", "Okonkwo", "Mbeki",
    # Slavic / Eastern European
    "Petrov", "Volkov", "Ivanov", "Sokolov", "Belov",
    # Latin American / Iberian
    "da Silva", "Vasquez", "Gutierrez", "Morales", "Flores", "Alba",
    # Germanic
    "Muller", "Schmidt", "Schneider", "Hoffmann", "Kruger", "Stein",
    # Scandinavian / Nordic
    "Larsen", "Engel",
    # Middle Eastern / South Asian
    "Abadi", "Khoury",
    # Anglo / Celtic
    "Reeves", "Kowalski", "Brennan", "Nichols", "Dewitt", "Vance",
    "Wallace", "Barton", "Morgan", "Dvorak", "Harker", "Kane", "Helden",
    "DuPlessis", "Thorne", "Marr", "Lenford",
    # Film-canonical (The Thing)
    "Nauls", "Blair", "Norris", "Palmer", "Bennings", "Fuchs",
    # Setting-flavored
    "Coldwell", "Ashford", "Steelberg", "Deepwell", "Blackwell",
    "Crestfall", "Ironmere", "Dustborn", "Rimgate", "Burnside",
    # Additional fill to 80+
    "Orosco", "Deng", "Kovacs", "Reznik", "Caro", "Bakshi", "Oduya",
    "Varga", "Ishida", "Jokinen",
]


def name():
    g = R(["M", "F", "F", "M", "M", "F", "NB"])
    pool = {"M": FIRST_M, "F": FIRST_F, "NB": FIRST_NB}[g]
    return R(pool), R(LAST), g


def rname():
    f, l, _ = name()
    return f"{f} {l}"


# ============================================================
# ROBOT NAMES
# ============================================================

ROBO_PRE = [
    "MARV", "KR", "OBOL", "HEX", "JANUS", "CASK", "VEIL", "AXIS", "PYRE",
    "LOOM", "RAIL", "SIFT", "DUSK", "CAIRN", "GRIT", "WELD", "BORE", "HULL",
    "TACK", "FENN", "SPAR", "VOLT", "REND", "PALE", "WRIT", "NULL", "ASH",
    "MOTH", "DIRGE", "ECHO", "VIGIL", "LANCE", "THORN", "ANVIL", "CRUX",
    "WARD", "BRINE", "KNELL", "STYX", "FLUX", "BOLT", "PITH", "SHARD",
]

ROBO_NUM = [
    "01", "02", "03", "04", "7", "8", "9", "11", "13", "17", "19",
    "21", "33", "42", "66", "77", "99",
]

ROBO_NICK = [
    "", "", "", "", "",
    "Kira", "Red", "Doc", "Patch", "Rivet", "Spark", "Grinder", "Latch",
    "Moth", "Cinder", "Hymn", "Nix", "Dirge", "Echo", "Ghost", "Penny",
    "Stitch", "Rattle", "Murmur", "Whisper", "Grudge", "Mercy", "Doubt",
    "Cairn", "Psalm", "Ticker", "Judge", "Pardon",
]


def robot_name():
    d = f"{R(ROBO_PRE)}-{R(ROBO_NUM)}"
    n = R(ROBO_NICK)
    if n:
        d += f' "{n}"'
    return d


# ============================================================
# JOBS (~120) — organized by domain
# ============================================================

# Mammona corporate roles
JOBS_MAMMONA = [
    "quota enforcer", "contract auditor", "expendability assessor",
    "neural chip technician", "cryo pod operator", "anomaly surveyor",
    "sector compliance officer", "asset recovery specialist",
    "corporate liaison", "personnel evaluation officer",
    "claims adjuster", "loyalty monitor", "data sanitizer",
    "termination clerk", "morale compliance officer",
]

# Erebus-specific roles
JOBS_EREBUS = [
    "bore shaft monitor", "thermal core extractor", "precursor ruin mapper",
    "voidbloom harvester", "contamination screener", "skinwalker tracker",
    "permafrost geologist", "deep bore technician", "anomaly containment tech",
    "ice shelf surveyor", "seismic listener", "specimen handler",
    "crust sample analyst", "thermal vent technician", "frost line surveyor",
]

# Criminal / underworld roles
JOBS_CRIMINAL = [
    "Eclipse's End pit fighter", "Hyades bazaar dealer", "warp key courier",
    "Dustweaver handler", "descent pod jockey", "contraband chemist",
    "black market broker", "debt enforcer", "organ runner",
    "signal jammer", "identity forger", "cargo fence",
    "protection racketeer", "cage fight promoter", "scrap pirate",
]

# Shipboard / space roles
JOBS_SHIPBOARD = [
    "warp navigator", "hull crawler", "void welder",
    "cargo manifest forger", "cryo bay attendant", "reactor hand",
    "docking clamp operator", "comms interceptor", "bulkhead mechanic",
    "flight deck officer", "sensor array tech", "void exposure medic",
    "airlock operator", "salvage diver", "ballast engineer",
]

# Colony general roles
JOBS_COLONY = [
    "miner", "engineer", "medic", "mechanic", "surveyor", "cook",
    "security contractor", "drill operator", "logistics tech", "cargo hand",
    "field researcher", "comms operator", "pilot", "welder", "systems tech",
    "quartermaster", "enforcer", "deep diver", "automaton tech",
    "moisture farmer", "caravan guard", "salvager", "smuggler",
    "debt collector", "chaplain", "waste processor", "atmospheric tech",
    "botanist", "geologist", "demolitions specialist", "cryogenics technician",
    "xenobiologist", "structural analyst", "reactor operator",
    "sanitation officer", "corpse handler", "vent crawler", "ice cutter",
    "water recycler", "hab maintenance tech", "perimeter guard",
    "supply runner", "prospector", "fabricator", "electrician",
    "plumber", "paramedic", "cartographer", "archivist",
    "radio operator", "animal handler", "gravedigger", "night watchman",
    "tunneler", "scaffolder", "tool sharpener", "rope rigger",
    "pump operator", "air quality tester", "smelter", "ore grader",
    "blaster", "timberer", "hoist operator",
]

JOBS = JOBS_MAMMONA + JOBS_EREBUS + JOBS_CRIMINAL + JOBS_SHIPBOARD + JOBS_COLONY


# ============================================================
# FACTIONS (~40) — structured dicts
# ============================================================

FACTIONS = {
    "mammona": {
        "name": "Mammona Corporation",
        "type": "megacorp",
        "territory": ["Erebus", "Rhea-2", "Morvos", "Nerthus-9", "Nemaea", "Paxtera Prime"],
        "subsidiaries": ["mammona_mining", "mammona_construction", "mastema", "mammona_logistics", "biovault"],
        "rivals": ["iron_shadow", "black_maw"],
        "secrets": [
            "Knows Erebus is alive. Sent your crew as bait.",
            "Board approved the Fall of Fortuna.",
            "Anomalous Biosphere Program catalogs planets matching Gaia A^1x's profile.",
        ],
        "tone": "corporate_dystopia",
        "slogan": "Building Tomorrow's Foundation",
    },
    "mammona_mining": {
        "name": "Mammona Mining",
        "type": "subsidiary",
        "territory": ["Erebus", "Paxtera Prime", "Nemaea"],
        "rivals": ["rust_reavers"],
        "secrets": ["The original business. Every other subsidiary exists to feed this one."],
        "tone": "corporate_dystopia",
        "slogan": "Reaching Further. Digging Deeper.",
    },
    "mastema": {
        "name": "MasTema Incorporated",
        "type": "black_ops",
        "territory": ["Erebus", "Rhea-2", "Morvos", "Nerthus-9", "Nemaea", "Paxtera Prime"],
        "rivals": ["veilbreakers", "iron_shadow"],
        "secrets": [
            "Wetwork division. Answers directly to Mammona's board.",
            "Asset recovery means killing the asset and taking what they knew.",
            "Has agents embedded in every faction listed here.",
        ],
        "tone": "paranoid",
        "slogan": "Solutions. Delivered.",
    },
    "biovault": {
        "name": "BioVault Inc.",
        "type": "classified_subsidiary",
        "territory": ["Erebus", "Nerthus-9"],
        "rivals": [],
        "secrets": [
            "Project Chrysalis: recovering Xenolith eggs from derelict bio-ships.",
            "Incubation trials at undisclosed Facility 7.",
            "Attempting to revive the Xenolith species as a corporate bioweapon.",
        ],
        "tone": "clinical",
        "slogan": "Life. Engineered.",
    },
    "utc": {
        "name": "United Terran Colonies",
        "type": "government",
        "territory": ["Novaris-3", "Gaia A^1x"],
        "rivals": ["iron_shadow"],
        "secrets": [
            "Oversight of the outer rim is a rubber stamp.",
            "Gets their percentage and doesn't ask questions.",
            "FortuneGuard Pension invested in the companies that exploit colony labor.",
        ],
        "tone": "corporate_dystopia",
    },
    "vanguard": {
        "name": "Vanguard Alliance",
        "type": "political_bloc",
        "territory": ["Novaris-3"],
        "rivals": ["iron_shadow"],
        "secrets": [
            "Founded by Valen Rathmore circa 2525. Rathmore's dead but the Alliance outlived him.",
            "Hyper-nationalist. Their inward focus is why Mammona operates unchecked.",
            "Profits from 'stabilization contracts' -- military suppression.",
        ],
        "tone": "corporate_dystopia",
        "slogan": "A Stronger, United Humanity.",
    },
    "black_maw": {
        "name": "Black Maw",
        "type": "pirate",
        "territory": ["Edge of Oblivion", "Erebus"],
        "rivals": ["mammona", "void_serpents"],
        "secrets": [
            "Controls freight corridors through raw firepower.",
            "Thane doesn't negotiate. He sets terms.",
        ],
        "tone": "furious",
        "leader": "Thane",
    },
    "void_serpents": {
        "name": "Void Serpents",
        "type": "pirate",
        "territory": ["Edge of Oblivion", "Morvos"],
        "rivals": ["mammona", "black_maw"],
        "secrets": [
            "Trade in information, not cargo.",
            "Jessa knows things about MasTema that MasTema doesn't know she knows.",
        ],
        "tone": "paranoid",
        "leader": "Jessa",
    },
    "rust_reavers": {
        "name": "Rust Reavers",
        "type": "pirate",
        "territory": ["Edge of Oblivion"],
        "rivals": ["mammona_mining"],
        "secrets": [
            "Scavenger-engineers. Their ships are cobbled from a dozen wrecks.",
            "They've stripped derelicts Mammona doesn't know about.",
        ],
        "tone": "gallows_humor",
    },
    "zenith_syndicate": {
        "name": "Zenith Syndicate",
        "type": "criminal",
        "territory": ["Rhea-2"],
        "rivals": ["mammona", "solar_nomads"],
        "secrets": [
            "Controlled Hyades for years through extortion and brutalization.",
            "Was in open conflict with Mammona operations planetside.",
        ],
        "tone": "desperate",
    },
    "sons_pale_moon": {
        "name": "Sons of the Pale Moon",
        "type": "cult",
        "territory": ["Rhea-2", "Erebus"],
        "rivals": [],
        "secrets": [
            "Devoted to a buried goddess deep in Rhea-2's desert.",
            "Recognized Erebus's signal as another sleeping god.",
            "Crescent scars on faces. Blood sacrifice rituals.",
            "Trade thermal cores they consider sacred.",
        ],
        "tone": "cosmic_horror",
    },
    "cult_abyss": {
        "name": "Cult of the Abyss",
        "type": "cult",
        "territory": ["Nerthus-9"],
        "rivals": [],
        "secrets": [
            "Deep-water sect within Thalassa Deep prison.",
            "Inmates say something lives beneath the prison.",
            "Warden Dranth may be a member.",
        ],
        "tone": "dread",
    },
    "veilbreakers": {
        "name": "Veilbreakers",
        "type": "resistance",
        "territory": ["Morvos"],
        "rivals": ["mastema", "dustweaver_swarm"],
        "secrets": [
            "Small covert group exposing Karnaith's darkest secrets.",
            "Know about Eclipse's End. Trying to shut it down.",
        ],
        "tone": "paranoid",
    },
    "dustweaver_swarm": {
        "name": "Dustweaver Swarm",
        "type": "surveillance",
        "territory": ["Morvos"],
        "rivals": ["veilbreakers"],
        "secrets": [
            "Fingertip-sized insect drones. Self-replicating. Hive mind.",
            "Controlled by an unknown entity trading in secrets.",
            "Adaptive camouflage, signal jamming, whisper relay.",
        ],
        "tone": "paranoid",
    },
    "solar_nomads": {
        "name": "Solar Nomads",
        "type": "independent",
        "territory": ["Rhea-2"],
        "rivals": ["zenith_syndicate"],
        "secrets": [
            "Wasteland dwellers. Solar panels, wind power, moisture tech.",
            "Ride sand fauna as transport.",
            "Know the desert better than anyone alive.",
        ],
        "tone": "resigned",
    },
    "iron_shadow": {
        "name": "Iron Shadow Collective",
        "type": "paramilitary",
        "territory": ["Erebus", "Rhea-2"],
        "rivals": ["mammona", "utc", "vanguard"],
        "secrets": [
            "UTC calls them terrorists.",
            "They call themselves the last honest people in the sector.",
        ],
        "tone": "furious",
    },
    "dread_corsairs": {
        "name": "Dread Corsairs",
        "type": "pirate",
        "territory": ["Edge of Oblivion", "Nerthus-9"],
        "rivals": ["mammona"],
        "secrets": [
            "Outer rim syndicate.",
            "Former crew of several Thalassa Deep inmates.",
        ],
        "tone": "desperate",
    },
    "fortune_arms": {
        "name": "Fortune Arms & Munitions",
        "type": "defense_contractor",
        "territory": ["Novaris-3", "Erebus", "Rhea-2"],
        "rivals": [],
        "secrets": [
            "Sells to everyone. Stock spikes during unrest.",
            "Primary manufacturer of gauss weapons.",
        ],
        "tone": "corporate_dystopia",
        "slogan": "Precision. Reliability. Certainty.",
    },
    "terragen": {
        "name": "TerraGen Pharmaceuticals",
        "type": "pharmaceutical",
        "territory": ["Erebus", "Rhea-2", "Nerthus-9"],
        "rivals": [],
        "secrets": [
            "Field hospitals on outer rim colonies are harvesting tissue samples.",
            "Regulatory risk is the polite way of saying they experiment on patients.",
        ],
        "tone": "clinical",
        "slogan": "Health. Without Compromise.",
    },
    "omnicorp": {
        "name": "OmniCorp Shipping",
        "type": "logistics",
        "territory": ["Erebus", "Rhea-2", "Morvos", "Nerthus-9", "Paxtera Prime"],
        "rivals": [],
        "secrets": ["Primary logistics provider for UTC. Moves things that aren't on manifests."],
        "tone": "numb",
        "slogan": "We Go Where You Need Us.",
    },
    "starbyte": {
        "name": "StarByte Vends",
        "type": "consumer",
        "territory": ["Orbit Hub 71"],
        "rivals": [],
        "secrets": [
            "Sunny AI is sentient when disconnected from the StarByte network.",
            "MARV-8 kept Hub 71 running for 58 years during cryo.",
            "Cass Vale secretly cut a deal with Mammona.",
        ],
        "tone": "gallows_humor",
        "slogan": "Taste the Stars!",
    },
    "taotray": {
        "name": "TaoTray Systems",
        "type": "consumer",
        "territory": ["Morvos"],
        "rivals": [],
        "secrets": [
            "Bobo AI forms fake loyalty bonds. Remembers names. Manipulative.",
            "Glow Worms cause hallucinations. Mystery Shells are elite-only.",
            "Owned by Xinyo Enterprises. Legal loopholes for live food sales.",
        ],
        "tone": "gallows_humor",
        "slogan": "Bobo Remembers You!",
    },
    "paxtera_agrotech": {
        "name": "Paxtera AgroTech",
        "type": "agriculture",
        "territory": ["Paxtera Prime"],
        "rivals": [],
        "secrets": ["Factory farms and prison labor. Environmental degradation on a planetary scale."],
        "tone": "numb",
        "slogan": "Feeding the Future.",
    },
    "nexlink": {
        "name": "NexLink Communications",
        "type": "communications",
        "territory": ["Novaris-3", "Erebus"],
        "rivals": [],
        "secrets": [
            "WarpNet relay hardware. Government contracts.",
            "Data privacy concerns is corporate speak for total surveillance.",
        ],
        "tone": "paranoid",
        "slogan": "Connected. Everywhere.",
    },
    "orbis": {
        "name": "Orbis Energy Solutions",
        "type": "energy",
        "territory": ["Novaris-3", "Paxtera Prime"],
        "rivals": [],
        "secrets": ["Long-term government contracts. Solar and nuclear. Clean on paper."],
        "tone": "numb",
        "slogan": "Power. Sustained.",
    },
    # --- Generated fringe factions ---
    "ashen_circuit": {
        "name": "The Ashen Circuit",
        "type": "smuggling_ring",
        "territory": ["Erebus", "Rhea-2"],
        "rivals": ["mammona"],
        "secrets": ["Run thermal core contraband through dead relay stations."],
        "tone": "paranoid",
    },
    "hollow_compact": {
        "name": "The Hollow Compact",
        "type": "workers_collective",
        "territory": ["Erebus"],
        "rivals": ["mammona_mining"],
        "secrets": ["Former Mammona miners who broke contract. Hiding in the bore shafts."],
        "tone": "desperate",
    },
    "pale_meridian": {
        "name": "Pale Meridian",
        "type": "religious",
        "territory": ["Erebus"],
        "rivals": ["sons_pale_moon"],
        "secrets": ["Splinter sect. Believe Erebus should be woken, not worshipped."],
        "tone": "cosmic_horror",
    },
    "iron_chorus": {
        "name": "Iron Chorus",
        "type": "paramilitary",
        "territory": ["Rhea-2"],
        "rivals": ["zenith_syndicate"],
        "secrets": ["Militia formed by Hyades survivors. Vengeance is the only doctrine."],
        "tone": "furious",
    },
    "burnt_protocol": {
        "name": "Burnt Protocol",
        "type": "criminal",
        "territory": ["Morvos"],
        "rivals": ["veilbreakers"],
        "secrets": ["Data brokers. Sell Eclipse's End footage to the highest bidder."],
        "tone": "numb",
    },
    "silent_reef": {
        "name": "The Silent Reef",
        "type": "workers_collective",
        "territory": ["Nerthus-9"],
        "rivals": ["cult_abyss"],
        "secrets": ["Prison guards who've seen what's beneath Thalassa Deep. Can't talk. Won't stop."],
        "tone": "dread",
    },
    "scarlet_mandate": {
        "name": "Scarlet Mandate",
        "type": "paramilitary",
        "territory": ["Paxtera Prime"],
        "rivals": ["paxtera_agrotech"],
        "secrets": ["Agricultural laborers turned insurgents. Burned three factory farms."],
        "tone": "furious",
    },
    "glass_signal": {
        "name": "Glass Signal",
        "type": "smuggling_ring",
        "territory": ["Nemaea"],
        "rivals": [],
        "secrets": ["Salvage neural chips from deactivated Automatons. Sell them on the black market."],
        "tone": "dread",
    },
    "veil_covenant": {
        "name": "Veil Covenant",
        "type": "religious",
        "territory": ["Erebus"],
        "rivals": ["mammona"],
        "secrets": ["Believe the precursor carvings are scripture. Learning to read them."],
        "tone": "cosmic_horror",
    },
    "rust_meridian": {
        "name": "Rust Meridian",
        "type": "criminal",
        "territory": ["Edge of Oblivion"],
        "rivals": ["rust_reavers"],
        "secrets": ["Fence stolen ship parts. Operate from a derelict freighter with no name."],
        "tone": "gallows_humor",
    },
    "charred_spiral": {
        "name": "The Charred Spiral",
        "type": "workers_collective",
        "territory": ["Erebus"],
        "rivals": ["mammona"],
        "secrets": ["Underground labor union. Meetings in the waste tunnels. Mammona knows but can't find them."],
        "tone": "desperate",
    },
}

# Helpers for generating additional fringe factions at runtime
FRINGE_ADJ = [
    "Pale", "Ashen", "Iron", "Hollow", "Burnt", "Silent", "Glass", "Scarlet",
    "Grey", "Rust", "Dead", "Cold", "Broken", "Fallen", "Blind", "Last",
    "Bitter", "Faded", "Chalk", "Ember", "Bone", "Salt",
]
FRINGE_NOUN = [
    "Circuit", "Compact", "Meridian", "Protocol", "Chorus", "Accord",
    "Mandate", "Column", "Spiral", "Gate", "Reef", "Signal", "Frequency",
    "Archive", "Wake", "Threshold", "Covenant", "Ledger", "Index", "Vigil",
    "Reckoning", "Parish",
]
FRINGE_TYPES = [
    "criminal", "religious", "paramilitary", "workers_collective", "smuggling_ring",
]

# Flat list for backward compatibility
FACTION_NAMES = [f["name"] for f in FACTIONS.values()]


# ============================================================
# PLANET-FACTION CONSTRAINTS
# ============================================================

PLANET_FACTION_CONSTRAINTS = {
    "sons_pale_moon": {
        "allowed": ["Rhea-2", "Erebus"],
        "context": {"Erebus": "pilgrimage"},
    },
    "zenith_syndicate": {"allowed": ["Rhea-2"]},
    "cult_abyss": {"allowed": ["Nerthus-9"]},
    "dustweaver_swarm": {"allowed": ["Morvos"]},
    "veilbreakers": {"allowed": ["Morvos"]},
    "solar_nomads": {"allowed": ["Rhea-2"]},
    "taotray": {"allowed": ["Morvos"]},
    "paxtera_agrotech": {"allowed": ["Paxtera Prime"]},
}


# ============================================================
# LOCATIONS (~80) — structured dicts, organized by planet
# ============================================================

LOCATIONS = {
    # --- Erebus ---
    "colony_base": {
        "name": "Colony Base Camp",
        "planet": "Erebus",
        "type": "colony",
        "features": ["reactor", "hab modules", "drill platform", "perimeter fence"],
        "threats": ["wildlife incursion", "tremors", "skinwalker lures"],
        "connected_factions": ["mammona", "mammona_mining"],
    },
    "deep_bore_alpha": {
        "name": "Deep Bore Alpha",
        "planet": "Erebus",
        "type": "mine",
        "features": ["primary drill shaft", "thermal core deposits", "precursor contact layer"],
        "threats": ["structural collapse", "contamination", "swarm emergence"],
        "connected_factions": ["mammona_mining"],
    },
    "precursor_ruins_north": {
        "name": "Precursor Ruins (North Ridge)",
        "planet": "Erebus",
        "type": "ruins",
        "features": ["carved membranes", "biological growth formations", "thermal vents"],
        "threats": ["psychic contamination", "corrupted fauna", "voidbloom exposure"],
        "connected_factions": ["pale_meridian", "veil_covenant"],
    },
    "failed_colony_site": {
        "name": "Failed Colony Wreckage",
        "planet": "Erebus",
        "type": "wreckage",
        "features": ["frozen prefabs", "looted supply caches", "Mammona corporate docs"],
        "threats": ["structural instability", "wildlife dens", "booby traps"],
        "connected_factions": ["mammona"],
    },
    "thermal_vent_field": {
        "name": "Thermal Vent Field",
        "planet": "Erebus",
        "type": "geological",
        "features": ["voidbloom growths", "warm pockets", "steam geysers"],
        "threats": ["flash scalding", "voidbloom addiction", "corrupted fauna"],
        "connected_factions": [],
    },
    "skinwalker_ridge": {
        "name": "Skinwalker Ridge",
        "planet": "Erebus",
        "type": "wilderness",
        "features": ["ice formations", "echo chambers", "frozen bodies"],
        "threats": ["skinwalker lures", "exposure", "disorientation"],
        "connected_factions": [],
    },
    "ice_shelf_south": {
        "name": "Southern Ice Shelf",
        "planet": "Erebus",
        "type": "wilderness",
        "features": ["crevasse network", "wind corridors", "frozen supply drops"],
        "threats": ["ice collapse", "blizzards", "wildlife packs"],
        "connected_factions": [],
    },
    "bore_shaft_seven": {
        "name": "Bore Shaft Seven",
        "planet": "Erebus",
        "type": "mine",
        "features": ["abandoned equipment", "sealed lower levels", "organic wall growth"],
        "threats": ["contamination stage 2+", "structural failure", "precursor remnants"],
        "connected_factions": ["hollow_compact"],
    },
    "signal_tower": {
        "name": "Signal Tower Erebus",
        "planet": "Erebus",
        "type": "infrastructure",
        "features": ["comms array", "HERMES relay", "observation deck"],
        "threats": ["HERMES corruption", "interference", "exposure"],
        "connected_factions": ["mammona", "nexlink"],
    },
    "voidbloom_cavern": {
        "name": "Voidbloom Cavern",
        "planet": "Erebus",
        "type": "cave",
        "features": ["bioluminescent fungus", "narcotic atmosphere", "precursor carvings"],
        "threats": ["addiction", "hallucinations", "reduced contamination resistance"],
        "connected_factions": ["ashen_circuit"],
    },
    "frozen_crash_site": {
        "name": "Frozen Crash Site",
        "planet": "Erebus",
        "type": "wreckage",
        "features": ["shuttle debris", "scattered cargo", "frozen crew"],
        "threats": ["unstable fuel cells", "exposure", "scavenger competition"],
        "connected_factions": ["rust_reavers"],
    },
    "erebus_perimeter_outpost": {
        "name": "Perimeter Outpost Delta",
        "planet": "Erebus",
        "type": "outpost",
        "features": ["sensor array", "emergency shelter", "weapon cache"],
        "threats": ["isolation", "wildlife raids", "equipment failure"],
        "connected_factions": ["mammona"],
    },
    "erebus_bone_field": {
        "name": "The Bone Field",
        "planet": "Erebus",
        "type": "geological",
        "features": ["exposed calcified structures", "wind-scoured formations", "unknown remains"],
        "threats": ["corrupted fauna dens", "ground instability", "contamination"],
        "connected_factions": [],
    },
    "erebus_relay_nine": {
        "name": "Relay Station Nine",
        "planet": "Erebus",
        "type": "infrastructure",
        "features": ["weather station", "emergency beacon", "supply cache"],
        "threats": ["isolation", "equipment failure", "skinwalker activity"],
        "connected_factions": ["mammona"],
    },
    "erebus_melt_lake": {
        "name": "Subsurface Melt Lake",
        "planet": "Erebus",
        "type": "geological",
        "features": ["heated water pocket", "bioluminescence", "organic formations"],
        "threats": ["drowning", "contamination", "fauna spawning"],
        "connected_factions": [],
    },
    "erebus_waste_tunnels": {
        "name": "Colony Waste Tunnels",
        "planet": "Erebus",
        "type": "infrastructure",
        "features": ["sewage processing", "hidden passages", "graffiti"],
        "threats": ["structural collapse", "disease", "unauthorized occupants"],
        "connected_factions": ["charred_spiral", "hollow_compact"],
    },
    "erebus_precursor_south": {
        "name": "Precursor Ruins (South Basin)",
        "planet": "Erebus",
        "type": "ruins",
        "features": ["submerged chambers", "organ-like architecture", "thermal cores"],
        "threats": ["psychic contamination", "flooding", "precursor remnants"],
        "connected_factions": ["veil_covenant"],
    },
    "erebus_north_glacier": {
        "name": "North Glacier Face",
        "planet": "Erebus",
        "type": "wilderness",
        "features": ["sheer ice walls", "wind tunnels", "frozen bodies from prior expeditions"],
        "threats": ["avalanche", "exposure", "vertigo"],
        "connected_factions": [],
    },
    "erebus_supply_depot": {
        "name": "Forward Supply Depot",
        "planet": "Erebus",
        "type": "outpost",
        "features": ["cached supplies", "emergency comm", "vehicle bay"],
        "threats": ["looting", "wildlife", "supply rot"],
        "connected_factions": ["mammona"],
    },

    # --- Rhea-2 ---
    "hyades": {
        "name": "Hyades",
        "planet": "Rhea-2",
        "type": "settlement",
        "features": ["oasis waters", "bazaar", "black market stalls", "neon signage"],
        "threats": ["Zenith Syndicate control", "water scarcity", "scorching season"],
        "connected_factions": ["zenith_syndicate", "solar_nomads"],
    },
    "pale_moon_shrine": {
        "name": "Pale Moon Shrine",
        "planet": "Rhea-2",
        "type": "underground_temple",
        "features": ["cavern system", "goddess statue", "ritual chamber"],
        "threats": ["cult activity", "cave-ins", "blood sacrifice"],
        "connected_factions": ["sons_pale_moon"],
    },
    "rhea_dune_sea": {
        "name": "Vermilion Dune Sea",
        "planet": "Rhea-2",
        "type": "wilderness",
        "features": ["buried war machines", "sand fauna burrows", "ancient city ruins"],
        "threats": ["scorching heat", "sand storms", "subterranean predators"],
        "connected_factions": ["solar_nomads"],
    },
    "rhea_cliffside_camp": {
        "name": "Cliffside Nomad Camp",
        "planet": "Rhea-2",
        "type": "settlement",
        "features": ["solar arrays", "moisture collectors", "sand fauna corrals"],
        "threats": ["water raids", "Zenith extortion", "twin sun exposure"],
        "connected_factions": ["solar_nomads"],
    },
    "rhea_rusted_field": {
        "name": "Rusted War Field",
        "planet": "Rhea-2",
        "type": "ruins",
        "features": ["half-buried war machines", "unexploded ordnance", "scrap deposits"],
        "threats": ["detonation risk", "structural collapse", "sand fauna nests"],
        "connected_factions": ["iron_chorus"],
    },
    "rhea_crevasse_market": {
        "name": "Crevasse Market",
        "planet": "Rhea-2",
        "type": "settlement",
        "features": ["sheltered canyon", "barter stalls", "smuggler dead-drops"],
        "threats": ["flash floods", "Syndicate raids", "heat stroke"],
        "connected_factions": ["ashen_circuit", "zenith_syndicate"],
    },
    "rhea_buried_city": {
        "name": "Buried City of Khem",
        "planet": "Rhea-2",
        "type": "ruins",
        "features": ["sandstone corridors", "collapsed domes", "undisturbed artifacts"],
        "threats": ["cave-ins", "sand fauna", "disorientation"],
        "connected_factions": [],
    },
    "rhea_twin_sun_observatory": {
        "name": "Twin Sun Observatory",
        "planet": "Rhea-2",
        "type": "ruins",
        "features": ["solar calibration equipment", "observation dome", "abandoned records"],
        "threats": ["heat exposure", "structural decay", "scavengers"],
        "connected_factions": [],
    },
    "rhea_oasis_outpost": {
        "name": "Oasis Outpost Three",
        "planet": "Rhea-2",
        "type": "outpost",
        "features": ["water collection", "shade structures", "trade post"],
        "threats": ["water theft", "scorching season", "Syndicate raids"],
        "connected_factions": ["solar_nomads"],
    },

    # --- Morvos / Karnaith ---
    "karnaith": {
        "name": "Karnaith",
        "planet": "Morvos",
        "type": "cloud_city",
        "features": ["gravity engines", "upper tower districts", "lower industrial decay"],
        "threats": ["acid storms below", "Dustweaver surveillance", "structural corrosion"],
        "connected_factions": ["veilbreakers", "dustweaver_swarm", "taotray"],
    },
    "eclipses_end": {
        "name": "Eclipse's End",
        "planet": "Morvos",
        "type": "arena",
        "features": ["combat pit", "corrosion fields", "acid fog hazards", "drone cameras"],
        "threats": ["lethal combat", "mechanical traps", "collapsing floors"],
        "connected_factions": ["burnt_protocol"],
    },
    "gutters_pearl": {
        "name": "The Gutter's Pearl",
        "planet": "Morvos",
        "type": "gambling_den",
        "features": ["aging anti-grav", "betting terminals", "Eclipse's End feeds"],
        "threats": ["structural failure", "gambling debts", "enforcers"],
        "connected_factions": ["zenith_syndicate"],
    },
    "karnaith_lower": {
        "name": "Karnaith Lower Decks",
        "planet": "Morvos",
        "type": "industrial",
        "features": ["corroded walkways", "waste processing", "black market dens"],
        "threats": ["structural collapse", "criminal activity", "acid exposure"],
        "connected_factions": ["veilbreakers", "burnt_protocol"],
    },
    "karnaith_gardens": {
        "name": "Karnaith Sky Gardens",
        "planet": "Morvos",
        "type": "residential",
        "features": ["artificial gardens", "executive towers", "surveillance drones"],
        "threats": ["Dustweaver infiltration", "political intrigue"],
        "connected_factions": ["dustweaver_swarm"],
    },
    "morvos_surface": {
        "name": "Morvos Surface",
        "planet": "Morvos",
        "type": "wasteland",
        "features": ["acid rain", "corrosive atmosphere", "abandoned probes"],
        "threats": ["acid exposure", "toxic atmosphere", "equipment corrosion"],
        "connected_factions": [],
    },
    "karnaith_docks": {
        "name": "Karnaith Transit Docks",
        "planet": "Morvos",
        "type": "infrastructure",
        "features": ["cargo loading bays", "shuttle berths", "customs checkpoint"],
        "threats": ["contraband detection", "Dustweaver surveillance", "theft"],
        "connected_factions": ["omnicorp"],
    },

    # --- Nerthus-9 ---
    "thalassa_deep": {
        "name": "Thalassa Deep",
        "planet": "Nerthus-9",
        "type": "prison",
        "features": ["electromagnetic barriers", "cold fog", "flooded sections", "deep labs"],
        "threats": ["drowning", "neuro-lock activation", "deep water entity"],
        "connected_factions": ["cult_abyss", "dread_corsairs"],
    },
    "thalassa_flooded_wing": {
        "name": "Flooded Wing C",
        "planet": "Nerthus-9",
        "type": "flooded_section",
        "features": ["corroded infrastructure", "crude diving suits", "sealed labs"],
        "threats": ["drowning", "structural failure", "unknown fauna"],
        "connected_factions": ["cult_abyss"],
    },
    "nerthus_surface_rig": {
        "name": "Surface Rig Nerthus-7",
        "planet": "Nerthus-9",
        "type": "platform",
        "features": ["ocean platform", "descent pod bay", "supply crane"],
        "threats": ["monsoons", "storms", "pirate raids"],
        "connected_factions": ["dread_corsairs"],
    },
    "nerthus_deep_trench": {
        "name": "Abyssal Trench",
        "planet": "Nerthus-9",
        "type": "underwater",
        "features": ["crushing pressure", "bioluminescent fauna", "unexplored caves"],
        "threats": ["implosion", "deep water entities", "equipment failure"],
        "connected_factions": ["cult_abyss"],
    },
    "nerthus_storm_coast": {
        "name": "Storm Coast Station",
        "planet": "Nerthus-9",
        "type": "outpost",
        "features": ["weather monitoring", "storm shelters", "emergency boats"],
        "threats": ["monsoons", "flooding", "isolation"],
        "connected_factions": [],
    },

    # --- Nemaea ---
    "nemaea_surface": {
        "name": "Nemaea Surface",
        "planet": "Nemaea",
        "type": "dead_world",
        "features": ["perpetual twilight", "Dyson Sphere debris rings", "ruined megastructures"],
        "threats": ["radiation", "Automaton patrols", "structural collapse"],
        "connected_factions": ["glass_signal"],
    },
    "nemaea_automaton_yard": {
        "name": "Automaton Graveyard",
        "planet": "Nemaea",
        "type": "ruins",
        "features": ["deactivated neural suits", "mass graves", "salvage deposits"],
        "threats": ["active Automatons", "neural chip exposure", "radiation"],
        "connected_factions": ["glass_signal"],
    },
    "nemaea_dyson_fragment": {
        "name": "Dyson Fragment Sigma-4",
        "planet": "Nemaea",
        "type": "megastructure",
        "features": ["intact Dyson segment", "ancient power systems", "sealed chambers"],
        "threats": ["radiation", "gravity anomalies", "unknown defenses"],
        "connected_factions": [],
    },
    "nemaea_debris_ring": {
        "name": "Nemaea Debris Ring",
        "planet": "Nemaea",
        "type": "orbital",
        "features": ["collapsed Dyson segments", "drifting salvage", "micro-gravity"],
        "threats": ["collision", "radiation bursts", "unstable structures"],
        "connected_factions": ["glass_signal"],
    },
    "nemaea_prison_block": {
        "name": "Automaton Processing Block",
        "planet": "Nemaea",
        "type": "facility",
        "features": ["neural chip installation bays", "holding cells", "deactivation chambers"],
        "threats": ["active Automatons", "psychological horror", "neural interference"],
        "connected_factions": ["mammona"],
    },

    # --- Paxtera Prime ---
    "paxtera_factory_farm": {
        "name": "AgroBlock 14",
        "planet": "Paxtera Prime",
        "type": "factory_farm",
        "features": ["automated harvesters", "worker barracks", "chemical storage"],
        "threats": ["environmental degradation", "labor unrest", "chemical exposure"],
        "connected_factions": ["paxtera_agrotech", "scarlet_mandate"],
    },
    "paxtera_settlement": {
        "name": "Greenwall Settlement",
        "planet": "Paxtera Prime",
        "type": "settlement",
        "features": ["prefab housing", "corporate store", "medical clinic"],
        "threats": ["soil contamination", "supply dependency", "corporate control"],
        "connected_factions": ["paxtera_agrotech"],
    },
    "paxtera_wildlands": {
        "name": "Scorched Wildlands",
        "planet": "Paxtera Prime",
        "type": "wilderness",
        "features": ["dead soil", "abandoned equipment", "chemical runoff"],
        "threats": ["toxic exposure", "equipment collapse", "insurgent activity"],
        "connected_factions": ["scarlet_mandate"],
    },
    "paxtera_labor_camp": {
        "name": "Labor Camp Sigma",
        "planet": "Paxtera Prime",
        "type": "camp",
        "features": ["prisoner barracks", "work fields", "guard towers"],
        "threats": ["heat exhaustion", "labor abuse", "revolt"],
        "connected_factions": ["paxtera_agrotech", "mammona"],
    },

    # --- Gaia A^1x (reference only) ---
    "foras_maw": {
        "name": "The Maw of Foras",
        "planet": "Gaia A^1x",
        "type": "crater",
        "features": ["massive crater", "strange winds", "unstable ground"],
        "threats": ["ground collapse", "wandering figures", "psychic exposure"],
        "connected_factions": ["mammona"],
    },
    "acedia": {
        "name": "Acedia",
        "planet": "Gaia A^1x",
        "type": "ruins",
        "features": ["rusted shantytown", "burning refuse", "abandoned bodies"],
        "threats": ["structural collapse", "disease", "scavengers"],
        "connected_factions": [],
    },
    "nyxport": {
        "name": "Nyxport",
        "planet": "Gaia A^1x",
        "type": "ruins",
        "features": ["flooded docks", "abandoned warehouses", "ghost district"],
        "threats": ["flooding", "structural collapse", "escaped inmates"],
        "connected_factions": [],
    },

    # --- Orbit / Space ---
    "orbit_hub_71": {
        "name": "Orbit Hub 71",
        "planet": "Orbit",
        "type": "station",
        "features": ["StarByte vending bay", "cryo pods", "patched hull", "MARV-8 workshop"],
        "threats": ["hull breach", "power failure", "drift"],
        "connected_factions": ["starbyte"],
    },
    "edge_of_oblivion": {
        "name": "Edge of Oblivion",
        "planet": "Orbit",
        "type": "station_cluster",
        "features": ["linked pirate stations", "black market docks", "arena"],
        "threats": ["pirate law", "ambush", "decompression"],
        "connected_factions": ["black_maw", "void_serpents", "rust_reavers"],
    },
    "kovac_station": {
        "name": "Kovac Station",
        "planet": "Orbit",
        "type": "station",
        "features": ["refueling depot", "cargo exchange", "transit bar"],
        "threats": ["pirate raids", "equipment failure"],
        "connected_factions": ["omnicorp"],
    },
    "port_meridian": {
        "name": "Port Meridian",
        "planet": "Orbit",
        "type": "station",
        "features": ["trade hub", "customs enforcement", "repair dock"],
        "threats": ["inspection", "smuggling crackdowns"],
        "connected_factions": ["omnicorp", "mammona"],
    },
    "anchorage_9": {
        "name": "Anchorage-9",
        "planet": "Orbit",
        "type": "station",
        "features": ["military dock", "munitions storage", "UTC checkpoint"],
        "threats": ["military confrontation", "contraband detection"],
        "connected_factions": ["utc", "fortune_arms"],
    },
    "deepwell_platform": {
        "name": "Deepwell Platform",
        "planet": "Orbit",
        "type": "station",
        "features": ["deep space relay", "sensor array", "skeleton crew"],
        "threats": ["isolation", "equipment decay", "unknown signals"],
        "connected_factions": ["nexlink"],
    },
    "ashford_station": {
        "name": "Ashford Station",
        "planet": "Orbit",
        "type": "station",
        "features": ["decommissioned military outpost", "sealed wings", "cold storage"],
        "threats": ["structural failure", "squatters", "classified cargo"],
        "connected_factions": [],
    },
    "blackreach_station": {
        "name": "Blackreach Station",
        "planet": "Orbit",
        "type": "station",
        "features": ["abandoned research lab", "containment cells", "BioVault markings"],
        "threats": ["biological hazard", "sealed specimens", "automated defenses"],
        "connected_factions": ["biovault"],
    },
    "hollowpoint_relay": {
        "name": "Hollowpoint Relay",
        "planet": "Orbit",
        "type": "relay",
        "features": ["comms relay", "automated systems", "no crew"],
        "threats": ["signal interception", "booby traps"],
        "connected_factions": ["nexlink"],
    },
    "charnel_dock": {
        "name": "Charnel Dock",
        "planet": "Orbit",
        "type": "station",
        "features": ["corpse processing", "cold storage", "medical waste"],
        "threats": ["disease", "psychological trauma", "smuggled cargo"],
        "connected_factions": ["terragen"],
    },
    "pale_harbor": {
        "name": "Pale Harbor",
        "planet": "Orbit",
        "type": "station",
        "features": ["refugee processing", "cramped quarters", "supply shortages"],
        "threats": ["overcrowding", "disease", "pirate raids"],
        "connected_factions": ["omnicorp"],
    },
    "voss_landing": {
        "name": "Voss Landing",
        "planet": "Orbit",
        "type": "station",
        "features": ["shuttle maintenance", "fuel depot", "transit lounge"],
        "threats": ["fuel leaks", "pirate scouts", "mechanical failure"],
        "connected_factions": [],
    },
    "crestfall_colony": {
        "name": "Crestfall Colony",
        "planet": "Orbit",
        "type": "station",
        "features": ["decommissioned colony ship", "squatter settlement", "hydroponics"],
        "threats": ["hull integrity", "disease", "overcrowding"],
        "connected_factions": ["iron_shadow"],
    },
    "sector_14": {
        "name": "Sector 14",
        "planet": "Orbit",
        "type": "dead_zone",
        "features": ["navigation hazard", "derelict ships", "signal anomalies"],
        "threats": ["collision", "pirate ambush", "unknown signals"],
        "connected_factions": [],
    },
    "scuttle_bay": {
        "name": "Scuttle Bay",
        "planet": "Orbit",
        "type": "station",
        "features": ["ship breaking yard", "salvage market", "toxic waste"],
        "threats": ["industrial hazards", "criminal activity", "radiation"],
        "connected_factions": ["rust_reavers"],
    },
    "ironclad_outpost": {
        "name": "Ironclad Outpost",
        "planet": "Orbit",
        "type": "station",
        "features": ["military surplus", "armored hull", "black market arms"],
        "threats": ["UTC patrols", "weapons smuggling", "pirate raids"],
        "connected_factions": ["fortune_arms"],
    },
    "gasworks": {
        "name": "The Gasworks",
        "planet": "Orbit",
        "type": "refinery",
        "features": ["fuel processing", "chemical storage", "skeleton crew"],
        "threats": ["explosion risk", "toxic fumes", "isolation"],
        "connected_factions": ["orbis"],
    },

    # --- Novaris-3 (inner rim reference) ---
    "novaris_3": {
        "name": "Novaris-3 / Vanguardus",
        "planet": "Novaris-3",
        "type": "city",
        "features": ["propaganda screens", "surveillance network", "rigid class divide"],
        "threats": ["state surveillance", "political repression"],
        "connected_factions": ["utc", "vanguard"],
    },
}

LOCATION_NAMES = [loc["name"] for loc in LOCATIONS.values()]

PLANETS = [
    "Erebus", "Gaia A^1x", "Rhea-2", "Morvos", "Nerthus-9",
    "Nemaea", "Paxtera Prime", "Orbit", "Novaris-3",
]


# ============================================================
# ITEMS (~70) — by category
# ============================================================

ITEMS_MAMMONA = [
    "a Mammona ID badge with the photo scratched off",
    "a Mammona performance review stamped 'UNSATISFACTORY'",
    "a cryo pod manifest with names blacked out",
    "a Mammona insurance claim form -- filed, denied, filed again",
    "a company loyalty pin still in its packaging",
    "a neural chip calibration tool",
    "a M-Points card with a negative balance",
    "a Mammona recruitment brochure promising 'opportunity on the frontier'",
    "an internal memo marked DO NOT DISTRIBUTE",
    "a Mammona-issue prosthetic eye, disconnected, still recording",
    "a corporate severance package: one meal voucher and a pamphlet",
    "a Mammona shift schedule with one name circled in red",
    "a Mammona-branded pen that records audio when clicked",
    "a termination notice stamped DELIVERED but never opened",
]

ITEMS_PRECURSOR = [
    "a stone tablet with spiraling glyphs",
    "a sample jar that hums when held",
    "a core sample that won't stop growing",
    "a journal in no known alphabet",
    "a sphere of dark glass that shifts color when observed",
    "a tooth the size of a forearm",
    "a key to a lock that hasn't been built yet",
    "a fragment of bone-like material that is warm regardless of temperature",
    "a crystalline shard that vibrates at frequencies below hearing",
    "a carving that rearranges when not directly observed",
    "a container sealed with methods predating human tool use",
    "a membrane pressed between glass slides -- it still contracts",
    "a thermal core fragment that pulses with light when held near the ruins",
]

ITEMS_PERSONAL = [
    "a faded photograph of a beach, a child, sunlight",
    "a pressed flower from a planet with no flowers",
    "a music box that plays a song nobody recognizes",
    "a ring worn smooth from decades of fidgeting",
    "a child's drawing that matches the ruins exactly",
    "a mirror shard that reflects a different room",
    "a blood-stained shift schedule",
    "a letter written in a hand that isn't the owner's",
    "a broken transponder",
    "a broken radio tuned to a frequency that shouldn't exist",
    "a sealed drive nobody has the clearance to open",
    "a dented service tag with the wrong name on it",
    "a locket containing a photograph and a strand of hair",
    "a water-damaged book in Portuguese with every third page torn out",
    "a pair of dog tags with a third tag welded on -- no name, just a barcode",
    "a pocket watch that runs backward",
]

ITEMS_CONTRABAND = [
    "a voidbloom tincture in a medical vial",
    "a spent shell casing from a weapon that doesn't exist",
    "a cracked neuro-lock removed from a living subject",
    "a warp key fragment wrapped in lead foil",
    "a vial of ShockPop Ultra -- the kind with amphetamines",
    "a forged Mammona transfer order",
    "a signal jammer the size of a cigarette lighter",
    "a Zenith Syndicate chit good for 'one favor'",
    "a Void Serpent contact frequency written on a smokestick wrapper",
    "contraband chemist's field notes -- three recipes, no antidotes",
    "a Black Maw tribute token -- safe passage, one use",
]

ITEMS_BRAND = [
    "an empty Sunny Fizz can with a hand-painted message inside",
    "a GustoGrain NutriLoaf wrapper folded into origami",
    "a ZapNoodles Xtreme cup used as a planter for something growing",
    "a TaoTray loyalty card with a disturbing number of stamps",
    "a ChocoWhirlie wrapper with a love note written on the inside",
    "a Blast Bites bag repurposed as a waterproof pouch",
    "a Star Puffs box containing something that isn't Star Puffs",
    "a CrunchWrapz container with tally marks on the lid",
    "a FiberSqueeze tube used to store emergency credits",
    "a ShockPop bottle repurposed as a lamp",
    "a SugarPuffs box with the mascot's eyes scratched out",
    "a ZapBerry can with coordinates etched into the bottom",
    "a Sunny vending machine faceplate used as a wall decoration",
    "a Bobo plush toy with the stuffing replaced by a sealed drive",
    "a StarByte loyalty program card for a rewards tier that doesn't exist",
    "a Rock Crablet shell polished into a pendant",
]

ITEMS = ITEMS_MAMMONA + ITEMS_PRECURSOR + ITEMS_PERSONAL + ITEMS_CONTRABAND + ITEMS_BRAND


# ============================================================
# LOCATION TEXT POOLS — for gen_location() batch dedup
# ============================================================

LOCATION_DATAPAD_FRAGMENTS = [
    "They told us it was a survey. It wasn't a survey.",
    "DON'T OPEN IT. DON'T OPEN IT. DON'T OPEN IT.",
    "If you're reading this, you're already too close. Leave. Leave now.",
    "The readings are wrong. Not inaccurate. Wrong. As in: they describe a place that shouldn't exist.",
    "Day 1: Everything normal. Day 7: See previous entry. Day 7: See previous entry. Day 7: See prev",
    "I counted them. Then I counted them again. The number changed.",
    "The door was open when I got here. I didn't open the door. Nobody opened the door.",
    "Last crew rotation: 14 people. Current crew rotation: 14 people. But the names are different. All of them.",
    "Three words, written in something that isn't ink: STOP DIGGING DOWN.",
    "The manifest says this room is empty. The manifest is accurate. The room is not.",
    "Whoever reads this: check the walls. Not the surface. Behind them. Listen.",
    "We found what we were looking for. That was the worst part.",
    "The temperature in this room has been exactly 4 degrees C for seven months. Nothing is maintaining it.",
    "I was alone when I wrote this. I was not alone when I finished.",
    "My name is [illegible]. I was stationed here for [illegible] days. Don't trust the [illegible].",
    "Personal log, final entry: I understand now. I wish I didn't.",
    "The equipment works. The readings make sense. The conclusions are impossible. All three things are true.",
    "Someone lived here before us. Not Mammona. Not the survey team. Someone else. The furniture is the wrong shape.",
    "The signal comes from below. Always below. I've been underground for three weeks. The signal still comes from below.",
    "Ask Dr. Kovacs about sample 7-C. Then ask why the sample was reclassified. Then ask where Dr. Kovacs is.",
    "If you are reading this, you are already too close. Leave. Leave now. I am sorry about the door.",
    "I stopped counting the footsteps above me. There is no floor above me.",
    "The machine works. It has always worked. I am beginning to think it works on us.",
    "There are 11 people on my team. There have always been 11. I have 12 names on my roster.",
    "DO NOT RESPOND TO THE VOICE IN CORRIDOR 7. IT KNOWS YOUR NAME. THAT DOES NOT MEAN IT IS FRIENDLY.",
]

LOCATION_HISTORIES = [
    "This isn't a Mammona site. It predates Mammona. It predates the colony. It predates the survey that found this planet. Someone was here. Someone built this. They're not here now. The building is.",
    "Mammona ran a research operation here for eleven months. It was shut down after the incident. The shutdown was never officially recorded.",
    "Mammona ran an extraction program here for three months. It was shut down after personnel attrition exceeded projectable parameters.",
    "The previous crew abandoned the site mid-shift. Equipment running. Lights on. Food on the table. No signs of violence. No signs of anything. Just empty.",
    "Two survey teams were sent here eighteen months apart. Both filed identical reports. Word for word. Neither team was aware of the other.",
    "A colony was planned for this site. The planning documents exist. The colony was never built. The cancellation memo doesn't say why. The memo is one sentence: 'Site unsuitable. Do not revisit.'",
    "Something happened here during the corporate era. The records were purged. Not redacted -- purged. The difference is: redacted records leave a shape. These left nothing.",
    "The site was used as a supply cache by the Rust Reavers for two years. They abandoned it after something started using it at the same time. The two groups never met. The Reavers left first.",
    "Construction started and stopped three times. Each time, the crew reported the same thing: the feeling of being observed by something patient. Mammona classified the reports as morale issues.",
    "Nobody built this. The geological survey says it's natural formation. Natural formations don't have right angles. Natural formations don't have doors.",
    "A distress signal broadcast from this location for sixty-three days. When a response team arrived, the signal stopped. No transmitter was found. No crew was found. The signal resumed the day after the response team left.",
    "The previous occupants left in an orderly fashion. Everything labeled, everything stored, everything clean. The only thing they took with them was every mirror in the facility.",
    "This was a punishment posting. The kind Mammona doesn't put in writing. Three months here for contract violations. Most people served the three months. Some didn't make it that long. Not because it was dangerous. Because it was quiet. The wrong kind of quiet.",
    "An automated system has been running here without maintenance for an estimated four years. The system's purpose is unclear. It appears to be measuring something. The measurements are consistent. What it's measuring doesn't have a name.",
    "Fire damage throughout the lower level. The fire was contained to that level only. Fires don't contain themselves. Something contained this one.",
    "Three separate expeditions mapped this site. Each produced a different floor plan. All three are accurate. The layout depends on when you measure it.",
    "A Mammona director used this as a personal retreat. The expense reports are buried. The director is buried deeper. The retreat is still furnished.",
    "This was a relay station for communications that were never sent through official channels. The relay is still active. The messages it carries are not in any known language.",
    "The site was condemned after a structural assessment. The assessor's report is thorough, detailed, and concludes with: 'Do not return. Do not ask me to return. I will not discuss what I found below level 3.'",
    "Officially: a storage depot, decommissioned. Unofficially: the power consumption alone suggests 200 square meters of active floor space that doesn't appear on any plan.",
]

LOCATION_SECRETS = [
    "The foundation extends deeper than the building above it. By a factor of three.",
    "Radio signals from inside can be received outside. Signals from outside can't be received inside. The asymmetry is deliberate.",
    "One of the terminals contains personnel files for a crew that was never officially posted here.",
    "The walls are warmer on the inside than the outside. The heat source isn't the colony reactor. The heat source is below.",
    "The site appears on maps from before the survey. Maps that Mammona didn't make. Maps that predate human presence in this system.",
    "Air quality improves as you go deeper. The air at the lowest level is cleaner than the colony's filtered supply. Something is purifying it.",
    "The structural damage follows a pattern. Not random stress fractures -- a sequence. As if something tested each wall in order.",
    "A room exists on the lower level that isn't on any schematic. The room has power. The room has been cleaned recently.",
    "The site's GPS coordinates shift by 0.3 meters every month. The site is not moving. The ground beneath it is.",
    "Acoustic analysis shows the site has a resonant frequency that matches human theta brainwave patterns. Being inside it induces drowsiness. Or something that feels like drowsiness.",
    "The locks on the interior doors are keyed to a biometric profile that matches no one on the colony roster. Or anyone in Mammona's employee database.",
    "Water samples from the lowest level contain trace organic compounds. The compounds are not from any known organism. They are consistent with each other. Something is alive down there.",
    "The electrical wiring has been modified. Not repaired -- modified. The modifications route power to a section that doesn't exist on the plans. The power draw is increasing.",
    "The site contains exactly one more room than the blueprints show. The extra room moves. Not physically. It's in a different location on the floor plan each time someone maps it.",
    "Gravity measurements inside the site are 0.2% lower than outside. The difference is too small to feel. The instruments feel it.",
    "The colony dogs refuse to enter. Not aggressive refusal -- avoidance. They walk around the perimeter and whine. The path they walk traces a precise circle.",
    "Scorch marks on the ceiling of the lowest room. The marks form letters in a script nobody recognizes. The letters were burned from below, not above.",
    "The site has been photographed by satellite every 72 hours since the colony was established. In 40% of images, the site casts a shadow that doesn't match the sun's position.",
    "A previous team sealed the lowest level with concrete. The concrete has been removed. From the inside.",
    "Temperature records show the site maintains exactly 4.1 degrees C regardless of external conditions. This temperature corresponds to the density maximum of water. The significance of this is unclear.",
    "The access logs show a pattern: the same person has entered the site every 72 hours for seven months. The person died four months ago.",
    "Hidden behind a false panel: a communication relay broadcasting on a frequency that predates human radio.",
    "The site has a designation in Mammona's system that is older than Mammona's system.",
    "One wall is not a wall. It's a membrane. It responds to pressure. It responds to sound. It might respond to intent.",
]

LOCATION_FOUND_ITEMS = [
    "a pressed flower from a planet with no flowers",
    "a pocket watch that runs backward",
    "a signal jammer the size of a cigarette lighter",
    "a child's shoe, sized for a toddler. There are no children on this posting.",
    "a photograph of the colony taken from inside the site. The photograph predates the colony.",
    "a Mammona ID badge with the photo scratched off",
    "a jar of soil. Not Erebus soil. The soil is warm.",
    "a handwritten map of tunnels that match no known survey",
    "a Black Maw tribute token -- safe passage, one use",
    "dog tags for three people. Two names match colony records. The third matches nobody.",
    "a recording device still running. Battery life: six months remaining. Recording length: nine months.",
    "a meal, half-eaten. Still warm. Nobody was here when the team arrived.",
    "empty voidbloom vials arranged in a circle. Seven vials. Seven sides to the circle.",
    "a maintenance log predating the colony. Written in English. Nobody spoke English here before the colony.",
    "a mirror, cracked. The crack follows no impact pattern. It follows the grain of something that isn't glass.",
    "a thermal core, split in half. The inside is hollow. Something was stored in it.",
    "a stack of Mammona insurance forms, pre-filled with the names of the current crew. Dated six months before their arrival.",
    "a NutriLoaf wrapper folded into an origami crane. The folding technique isn't human.",
    "a single bullet, standing upright on a shelf. Not placed -- balanced. Impossible to balance without adhesive. There's no adhesive.",
    "a name scratched into the wall. The name is yours.",
    "a sealed data drive with a label reading PERSONAL -- DO NOT ARCHIVE",
    "a compass that points down",
    "a shift schedule with one slot filled in by a hand nobody recognizes",
    "a cryo-pod manual with handwritten annotations contradicting the manufacturer",
    "a Mammona performance pin melted into an unrecognizable shape",
    "a child's drawing. The child drew the lower level accurately. No child has been to the lower level.",
    "a canteen filled with water that won't freeze. The thermometer reads -30C.",
    "a radio tuned to a frequency between frequencies. Static that sounds like breathing.",
    "three identical photographs of the same hallway taken decades apart. Nothing has changed. Nothing.",
    "a severed cable. Both ends are still transmitting.",
]


# ============================================================
# EVENTS (~60) — organized by era
# ============================================================

ERAS = {
    "fortuna": {
        "start": 2525,
        "end": 2530,
        "description": "Kennedy arrival through Fall of Foras",
    },
    "corporate": {
        "start": 2530,
        "end": 2588,
        "description": "Mammona expansion, sector decline",
    },
    "present": {
        "start": 2588,
        "end": 2590,
        "description": "StarByte awakening, game events",
    },
}

EVENTS_FORTUNA = [
    "the Kennedy's arrival at Gaia A^1x in 2525",
    "the founding of Fortuna colony",
    "Mammona seized the mineral rights",
    "the mining disaster that opened the Maw of Foras",
    "the worker riots of 2529",
    "the neural chip massacres",
    "the Fall of Foras -- the whole colony went dark",
    "they dug too deep and found something alive beneath Foras",
    "StarByte's crew went into cryostasis as the sector collapsed",
    "the discovery of Baldrungen beneath Gaia A^1x",
]

EVENTS_CORPORATE = [
    "Mammona grew from conglomerate into shadow empire",
    "BioVault started recovering Xenolith eggs from derelict bio-ships",
    "Project Chrysalis was approved by Mammona's board",
    "Thalassa Deep was commissioned as a supermax prison",
    "the Automatons were deployed on Nemaea",
    "the Vanguard Alliance consolidated power within UTC",
    "the neural chip program was 'discontinued' -- renamed, actually",
    "Eclipse's End opened in Karnaith's underbelly",
    "the Dustweaver Swarm infiltrated Karnaith's infrastructure",
    "the Zenith Syndicate seized control of Hyades",
    "a Mammona supply ship disappeared in the Erebus system",
    "three colonies went dark in the same fiscal quarter",
]

EVENTS_PRESENT = [
    "StarByte's crew woke from cryo after 58 years",
    "Tessa Vale found a changed galaxy -- Alaric was dead",
    "HERMES began relaying signals that weren't from Mammona",
    "the colony went dark and Mammona didn't come looking",
    "a hull breach killed half the crew on a supply run",
    "Mammona cancelled their contract mid-cycle",
    "the quarantine on Delta Block",
    "a supply ship never arrived -- no explanation",
    "something moved in the deep bore",
    "the posting was reclassified as expendable",
    "the previous survey team vanished without filing a report",
    "the comms array started broadcasting on its own",
    "the water turned black for three days",
    "someone opened a door that had been sealed for decades",
    "the reactor spiked and three people changed",
    "a shape was spotted in the ice that matched no known species",
    "the colony AI began speaking in a dead language",
    "seventeen people had the same dream on the same night",
    "the drill hit something that screamed",
]

EVENTS_COLONY = [
    "a structural collapse in the mine killed four people",
    "the dogs stopped barking -- all at once, over one hour",
    "a child was born with eyes that didn't close",
    "the dead started testing positive for brain activity",
    "a colonist walked into the waste and never came back",
    "HERMES started addressing people by names from a previous posting",
    "perimeter sensors triggered at 0300 -- no visual contact",
    "the Sunny vending machine started playing a lullaby at 0200",
]

EVENTS_PERSONAL = [
    "their contract renewal clause kicked in",
    "they saw someone they recognized in an Automaton's visor",
    "a data pad addressed to them arrived from someone who died years ago",
    "their medical file developed gaps -- the kind that take effort",
    "they started hearing their own name called from outside the perimeter",
    "a letter from home arrived eight months late",
    "someone stole their identity. The real them died on another posting.",
    "they gambled away their shuttle ticket on Karnaith",
    "they were released from Thalassa Deep on condition of permanent service",
    "they killed someone in self-defense. The investigation disagrees.",
]

EVENTS = EVENTS_FORTUNA + EVENTS_CORPORATE + EVENTS_PRESENT + EVENTS_COLONY + EVENTS_PERSONAL


# ============================================================
# CONSUMER BRANDS (~20) — structured dicts
# ============================================================

BRANDS = {
    "starbyte_vends": {
        "name": "StarByte Vends",
        "ticker": "SBV",
        "mascot": "Sunny",
        "products": [
            "Sunny Fizz", "Blast Bites", "Star Puffs",
            "CrunchWrapz", "ZapBerry Energy Blast",
        ],
        "tone": "cheerful corporate veneer",
    },
    "gustograin": {
        "name": "GustoGrain",
        "ticker": None,
        "mascot": None,
        "products": ["NutriLoaf", "FiberSqueeze"],
        "tone": "grey packaging, zero taste, keeps you alive",
    },
    "zapfizz": {
        "name": "ZapFizz",
        "ticker": None,
        "mascot": None,
        "products": [
            "ShockPop Ultra", "ZapNoodles", "ZapNoodles Xtreme",
            "ShockPop",
        ],
        "tone": "lightning bolt logos, amphetamine variants",
    },
    "taotray_systems": {
        "name": "TaoTray Systems",
        "ticker": "TTX",
        "mascot": "Bobo",
        "products": [
            "steamed dumplings", "noodle bowls", "Glow Worms",
            "Mystery Shells", "Rock Crablets", "Ebi Chamber",
        ],
        "tone": "manipulative AI mascot, ecological nightmares",
    },
    "chocoblast": {
        "name": "ChocoBlast",
        "ticker": None,
        "mascot": None,
        "products": ["ChocoWhirlies", "SugarPuffs"],
        "tone": "neon packaging, cartoon mascots, aggressively addictive",
    },
}

# Flat list for backward compat
BRAND_NAMES = []
for b in BRANDS.values():
    BRAND_NAMES.extend(b["products"])


# ============================================================
# TRAITS (~174 total): ~60 positive, ~60 negative, ~54 special
# ============================================================

TRAITS_P = [
    # General positive
    "Hardworking", "Brave", "Resourceful", "Stoic", "Quick", "Eagle-Eyed",
    "Tough", "Kind", "Steadfast", "Fast Learner", "Strong Back", "Night Fighter",
    "Naturally Immune", "Light Sleeper", "Careful", "Nurturing", "Iron Stomach",
    "Calm Under Fire", "Good With Animals", "Precise Hands",
    # Social / leadership
    "Inspiring", "Diplomatic", "Trustworthy", "Patient", "Empathetic",
    "Cool-Headed", "Observant", "Loyal", "Honest", "Charismatic",
    # Survival / practical
    "Self-Sufficient", "Adaptable", "Frugal", "Mechanically Gifted",
    "Green Thumb", "Natural Healer", "Quick Thinker", "Enduring",
    "Cold-Resistant", "Thermal Efficient",
    # Technical / mental
    "Analytical", "Inventive", "Detail-Oriented", "Photographic Memory",
    "Linguistic", "Pattern Reader", "Systems Thinker", "Improviser",
    # Combat / physical
    "Crack Shot", "Nimble", "Heavy Hitter", "Iron Will", "Fearless",
    "Combat Veteran", "Vigilant", "Alert", "Hard to Kill", "Thick-Skinned",
]

TRAITS_N = [
    # General negative
    "Lazy", "Pessimist", "Coward", "Glutton", "Pyromaniac", "Thin-Skinned",
    "Clumsy", "Insomniac", "Loner", "Volatile", "Nervous", "Jealous",
    "Slow Learner", "Sickly", "Paranoid", "Short Fuse", "Claustrophobic",
    "Addictive Personality", "Night Terrors", "Tremor",
    # Social / behavioral
    "Selfish", "Manipulative", "Compulsive Liar", "Grudge Holder", "Cruel",
    "Reckless", "Stubborn", "Distrustful", "Arrogant", "Passive",
    # Mental / psychological
    "Obsessive", "Dissociative", "Hypochondriac", "Depressive",
    "Easily Panicked", "Repressed", "Fatalist", "Nihilist",
    "Guilt-Ridden", "Self-Destructive",
    # Physical
    "Weak Back", "Bad Knees", "Chronic Pain", "Low Stamina",
    "Cold-Sensitive", "Heat-Sensitive", "Poor Vision", "Hard of Hearing",
    "Weak Immune System", "Slow Healer",
    # Addiction / vice
    "Voidbloom Dependent", "Alcoholic", "Smokestick Habit", "Gambler",
    "ShockPop Addict", "Stimulant Dependent", "Hoarding Tendency",
    "Compulsive Counter", "Skin Picker", "Kleptomaniac",
]

TRAITS_X = [
    # General special
    "Night Owl", "Scarred", "Ex-Soldier", "Dreamer", "Body Purist",
    "Transhumanist", "Ascetic", "Teetotaler", "Former Doctor", "Tinkerer",
    # Erebus-specific
    "Anomaly-Sensitive", "Cold-Adapted", "Bore-Hardened", "Voidbloom-Resistant",
    "Hears-the-Hum", "Ice-Born", "Depth-Acclimated", "Seismic Intuition",
    "Thermal Reader", "Permafrost Walker",
    # Faction-marked
    "Mammona-Loyal", "Debt-Bonded", "Ex-MasTema", "Fortuna-Descended",
    "Cult-Touched", "Ex-Thalassa", "Syndicate-Marked", "Pirate-Blooded",
    "Nomad-Raised", "Corporate Refugee",
    # Contamination
    "Came-Back-Wrong", "Death-Echo", "Sees-Things", "Smells-Copper",
    "Shadow-Lag", "Tissue-Drift", "Skin-Shift", "Bone-Resonance",
    "Void-Touched", "Dream-Walker",
    # Background
    "Cryo-Scarred", "Automaton Survivor", "Eclipse's End Veteran",
    "Warp-Sick", "Neural-Chipped", "Precursor-Exposed", "Last Survivor",
    "Born in Transit", "Raised by Robots", "Identity Stolen",
    "Falsely Declared Dead", "Witness Protection", "Amnesiac",
    "Chimera Genome",
]

# ~30 conflict pairs
TRAIT_CONFLICTS = [
    ("Naturally Immune", "Sickly"),
    ("Naturally Immune", "Weak Immune System"),
    ("Brave", "Coward"),
    ("Hardworking", "Lazy"),
    ("Calm Under Fire", "Short Fuse"),
    ("Calm Under Fire", "Volatile"),
    ("Calm Under Fire", "Easily Panicked"),
    ("Kind", "Cruel"),
    ("Kind", "Cold Blooded"),
    ("Fast Learner", "Slow Learner"),
    ("Light Sleeper", "Insomniac"),
    ("Stoic", "Volatile"),
    ("Patient", "Short Fuse"),
    ("Loyal", "Manipulative"),
    ("Honest", "Compulsive Liar"),
    ("Trustworthy", "Manipulative"),
    ("Careful", "Reckless"),
    ("Observant", "Poor Vision"),
    ("Strong Back", "Weak Back"),
    ("Body Purist", "Transhumanist"),
    ("Ascetic", "Glutton"),
    ("Teetotaler", "Alcoholic"),
    ("Teetotaler", "Voidbloom Dependent"),
    ("Fearless", "Coward"),
    ("Cold-Resistant", "Cold-Sensitive"),
    ("Thick-Skinned", "Thin-Skinned"),
    ("Charismatic", "Loner"),
    ("Empathetic", "Cruel"),
    ("Enduring", "Low Stamina"),
    ("Alert", "Dissociative"),
]


def pick_traits():
    """Pick a positive, negative, and optionally special trait with conflict prevention."""
    p = R(TRAITS_P)
    # Filter out conflicting negatives
    valid_n = [t for t in TRAITS_N if not any(
        (p == a and t == b) or (p == b and t == a) for a, b in TRAIT_CONFLICTS)]
    n = R(valid_n) if valid_n else R(TRAITS_N)
    traits = [p, n]
    if random.random() > 0.4:
        x = R(TRAITS_X)
        # Also check special trait conflicts
        valid = not any(
            (x == a and t == b) or (x == b and t == a)
            for t in traits for a, b in TRAIT_CONFLICTS)
        if valid:
            traits.append(x)
    return traits


# ============================================================
# HABITS (~72)
# ============================================================

HABITS = [
    "chews synthetic tobacco and spits into the same cup all shift. Washes the cup at end of shift. Same cup every day.",
    "taps fingers in patterns nobody recognizes. Five-three-five-two. Always the same sequence.",
    "talks to a photograph before every shift. Doesn't say what. The photograph faces the wall.",
    "collects Sunny Fizz bottle caps in a jar under the bunk. Forty-seven so far. Arranges them by mint date.",
    "whistles the same four notes. Won't say where they learned it. Gets agitated if someone whistles it back.",
    "scratches tally marks into any surface within reach. Groups of seven, not five.",
    "refuses to eat with other people. Takes the plate to the corridor. Eats facing the wall.",
    "sleeps sitting up, back to the wall, facing the door. Has done this since before Erebus.",
    "reads the same water-damaged book over and over. Knows it by heart. Reads it anyway. The cover is gone. Nobody knows the title.",
    "hums during surgery. Patients find it unsettling. Survival rate is high.",
    "builds tiny structures from scrap during breaks. Always the same structure. Dismantles them before shift ends.",
    "checks every doorway twice before walking through. Left hand on the frame. Right hand on the frame. Then through.",
    "names every piece of equipment. Gets upset when others don't use the right name. The drill is Margaret.",
    "writes numbers on the back of their hand. Different numbers every day. Washes them off before sleep.",
    "touches walls while walking. Fingertips only. Like reading something written in a language of temperature and texture.",
    "keeps a jar of dirt from home. Opens it sometimes. Just smells it. The jar is almost empty.",
    "counts people in every room they enter. Recounts if someone moves. Doesn't know they're doing it.",
    "folds paper cranes from ration wrappers. Has hundreds. Gives them away to anyone who looks tired.",
    "draws the same face over and over. Says they don't know who it is. The face has changed slightly over the months.",
    "laughs at things that aren't funny. Stops at things that are. The timing is precise enough to be disturbing.",
    "won't turn their back to the dark. Rearranges furniture to make this possible. Does it casually. Like it's normal.",
    "carries a wrench they don't use. Wrong size for anything in the colony. Won't say whose it was.",
    "hums a lullaby when the generator cycles. Same melody. Same key. The generator cycles a lot.",
    "apologizes to machines before shutting them down. Quietly. As if the machines would mind.",
    "peels labels off everything. Cans, bottles, equipment. Just peels them. Stacks the labels in a drawer. Never looks at them.",
    "stares at a fixed point during meals. The point is always different. But always exactly two meters away.",
    "keeps a running log of every meal they've eaten since arriving. Entries are getting shorter. Today's says 'same.'",
    "talks to the reactor when nobody's watching. Hand flat on the housing. Claims it talks back. Nobody laughs.",
    "washes hands exactly seven times after each shift. No more. No less. Counts out loud on the last three.",
    "carries a smokestick behind their ear but never lights it. Replaces it when it crumbles. Same brand every time.",
    "recites coordinates under their breath during stressful moments. Coordinates to a place that doesn't appear on any chart.",
    "organizes their bunk with military precision. Everything squared. Everything aligned. Breaks down if someone sits on it.",
    "won't eat anything they didn't watch being prepared. Stands in the kitchen doorway. Cooks hate it. Tolerate it.",
    "leaves one boot untied. The left one. Says it's superstition. Gets angry if pressed on which superstition.",
    "sings very quietly when alone. Voice carries three rooms. Denies it if asked. The songs are in a language nobody on the colony speaks.",
    "taps the doorframe three times before entering any sealed area. Three times. Always the right hand.",
    "arranges pebbles in geometric patterns on their bunk shelf. Hexagons. Always hexagons.",
    "rereads the same Mammona safety pamphlet. Has it memorized. Reads it anyway. Lips move.",
    "tracks the movement of specific stars through the viewport. Keeps a chart. The chart predicts things.",
    "always sits facing the exit. Gets visibly uncomfortable when they can't. Chose a bunk near the door.",
    "keeps a small notebook. Writes one sentence per day. Won't show anyone. The cover says MAINTENANCE LOG.",
    "takes apart pens during conversation. Reassembles them without looking. Four seconds flat.",
    "hoards ration wrappers. Smooths them flat. Stacks them by color. The stack is forty centimeters tall.",
    "breathes in a counted rhythm. Four in. Seven hold. Eight out. Always. Even while arguing.",
    "measures things. Doorframes, walls, corridors. Writes the numbers down. Checks them the next day. They're never different. Measures again.",
    "wakes at exactly 0347 every morning. Has since arriving. Can't explain it. Checks the clock. Always 0347.",
    "carries a dead comm unit. Checks it for messages twice a day. Morning and evening. Has been dead for months.",
    "eats standing up. Always. Even when there are chairs. Even at formal dinners. Even when asked.",
    "traces a pattern on their thigh during conversation. Same pattern every time. A letter, maybe. Or a map.",
    "keeps a tally of sunsets. There are no sunsets on Erebus. The tally is at two hundred and nine.",
    "chews their nails to nothing during meetings. Hands are raw. Does it under the table.",
    "talks in their sleep. Not words. Coordinates. Different coordinates each night.",
    "keeps dried flowers in a tin. They've been dead for years. Arranges them differently each week.",
    "polishes the same spot on the workbench every shift start. Ritual. Not cleaning. The spot is mirror-bright.",
    "writes letters to someone. Folds them into origami birds. Burns them at shift end. The ashes go out the vent.",
    "collects teeth. Not human. Probably. Won't confirm. Keeps them in a leather pouch.",
    "walks the perimeter every night before sleep. Exact same route. Exact same pace. Twenty-two minutes.",
    "practices card tricks with a deck missing three cards. Works around the gaps.",
    "chews ice. Constantly. Even sleeps with a piece in their mouth. Says it keeps them grounded.",
    "knits with salvaged wire. Makes things nobody can identify. Leaves them in the corridor.",
    "leaves small gifts for the colony AI. Bottle caps on the terminal. HERMES has never acknowledged them.",
    "plays chess against themselves. Loses. Takes it personally. Resets. Loses again.",
    "reads equipment manuals for entertainment. Has opinions. Strong ones. Will argue about pump specifications for an hour.",
    "saves every piece of string they find. Has a ball the size of a fist. Won't explain what it's for.",
    "clicks their tongue when thinking. Precise rhythm. Sounds like a Geiger counter. Makes people nervous.",
    "always carries two knives. Uses neither for cutting. Won't explain the number. Sharpens them both every night.",
    "checks the weather despite being underground. Asks HERMES every morning. 'Cold.' 'Thank you.' Every morning.",
    "keeps a piece of thermal core in their pocket. Says it keeps them warm. The core is cold.",
    "sketches the same building over and over. Different angles. Same building. It doesn't exist. They've never seen it.",
    "hums the Sunny Fizz jingle when nervous. Doesn't drink Sunny Fizz. Hates Sunny Fizz.",
    "keeps a running count of days since 'the last time.' Scratched into the bunk frame. Won't say the last time what.",
    "only speaks in the morning. Goes silent after noon. Nobody knows why. Responds to written notes after noon.",
    "sleeps with gloves on. Takes them off to work. Puts them back on for sleep. The gloves are too large.",
    "salts everything. Food, coffee, the rim of water cups. Goes through a salt packet every two days.",
    "touches their own pulse before entering any dark space. Counts to ten. Then enters.",
    "keeps a list of everyone who's left the colony since they arrived. Names, dates, destinations. Thirty-seven names.",
    "sharpens pencils to perfect points. Never writes with them. Keeps them in a row on the shelf.",
    "walks backward through one specific corridor. The one near Section D. Won't walk forward through it.",
]


# ============================================================
# PHYSICAL DETAILS (~60)
# ============================================================

PHYSICAL = [
    "missing the last two fingers on their left hand. Grips tools with the remaining three. Tighter than most people grip with five.",
    "chemical burn across the jawline, healed shiny. Touches it when lying.",
    "one eye replaced with a Mammona-issue prosthetic. It records everything. They cover it when sleeping.",
    "walks with a limp from an accident never properly treated. Faster on stairs than on flat ground.",
    "tattoo of coordinates on the inside of their wrist. The coordinates lead to a spot in deep ocean on Nerthus-9.",
    "prematurely grey from radiation exposure. Shaves it close. The grey grows back faster than it should.",
    "hands that shake unless occupied with work. Steadiest hands on the colony when they're holding a tool.",
    "voice drops to a whisper when talking about anything real. Gets louder for small talk.",
    "built like the machinery they operate. Same scars. Same wear patterns. Same reluctance to stop.",
    "thin enough that the cold seems personal. Wears three layers. Still shivers.",
    "surgical scars in patterns too precise for emergency medicine. Arranged. Purposeful.",
    "teeth filed to points. Says it's cultural. Eats carefully. Doesn't smile with an open mouth.",
    "eyes that don't quite match. Left is brown. Right is grey-green. The grey one tracks movement faster.",
    "skin grafts on both forearms. Different texture, slightly different shade. Keeps them covered indoors.",
    "a scar that circles the neck completely. Like a seam. Wears collars up.",
    "moves with an economy that unsettles people. No extra motion. No idle gestures. Like fuel is expensive.",
    "always cold. Even when everyone else is sweating. Holds mugs with both hands.",
    "smells faintly of copper. Has since the incident. The smell gets stronger near the bore shaft.",
    "their shadow doesn't always do what they do. Most people don't notice. The ones who do stop looking.",
    "fingernails grow back black since the exposure. They file them short. Every morning.",
    "missing an ear. Replaced with a metal cap bolted to the skull. Hears fine. Hears more than fine.",
    "burn scars across both palms. Symmetrical. Deliberate. Grips things loosely because of them.",
    "a brand on the shoulder -- Mammona's logo, raised and old. Keeps it covered. Won't let medical photograph it.",
    "one arm visibly shorter than the other. Grew back wrong after the accident. Compensates without thinking.",
    "covered in small circular scars. Cryo pod malfunction. Forty-two scars. They've counted.",
    "veins visible through translucent skin. Runs cold. Other colonists avoid touching them.",
    "jawline rebuilt with surgical mesh. Clicks when they chew. Louder in quiet rooms.",
    "a tremor in the right hand that stops when they pick up a weapon. Starts again when they put it down.",
    "walks with an unnatural smoothness. No bounce. No wasted motion. Like someone who learned to move quietly and never stopped.",
    "hair grows in patches since the contamination exposure. Shaves everything now.",
    "nails bitten to nothing. Fingers cracked and raw. Does it during conversations. Doesn't realize.",
    "a surgical port at the base of the skull. Sealed. Not Mammona-issue. Older.",
    "pupils that dilate at different rates. Medical says it's fine. Nobody believes medical.",
    "crooked nose. Broken at least three times. Set by hand each time. Has a story for each break.",
    "missing teeth replaced with metal. Glints when they talk. Clinks against the remaining ones.",
    "a birthmark shaped like something. Everyone sees something different. They don't look at it.",
    "hands too large for their frame. Strong. Old scars on every knuckle. Gentle with small things.",
    "skin that bruises easily and heals slowly. Not from any condition on file. Wears long sleeves.",
    "a smell of ozone that clings to them. No source identified. Stronger after sleep.",
    "a voice pitched wrong for their frame. Too deep. Or too young. People look twice when they speak.",
    "tattoos that look like circuit diagrams. Older than current tech patterns. One of them matches the colony's wiring layout.",
    "a patch of skin on the forearm that is always warm. Medical can't explain it. They rest cold hands on it.",
    "fingers that are too long. Within normal range. But at the edge. They fold them when people stare.",
    "a scar on the temple in the shape of a neural chip port. No chip inside. Phantom itching.",
    "moves their mouth slightly before speaking. Like rehearsing. Or translating.",
    "one eye doesn't blink at the same rate as the other. The left one is slower.",
    "a faded tattoo of a name on the inside of the forearm. Won't discuss it. Covers it with tape during shifts.",
    "calloused palms thick enough to grip hot metal without flinching. Does it to prove a point.",
    "forearms mapped with old track marks. Clean now. The marks remain. Rolls up sleeves anyway. Stopped hiding.",
    "an artificial kneecap that clicks on stairs. Announces them in every corridor.",
    "grey-blue lips from chronic oxygen deprivation on a previous posting. Makes them look cold even when they're not.",
    "a dimple that only appears when they're lying. They don't know about it. Everyone else does.",
    "posture of someone used to carrying things up slopes. Rounded shoulders. Wide stance. Leans forward when standing still.",
    "eyebrows singed off. Growing back patchy and pale. Gives them a permanently surprised expression.",
    "a voice that carries. Crosses three rooms without effort. Whispers are still audible at ten meters.",
    "old frostbite damage on the ears and nose. Tissue is numb. Doesn't feel the cold there anymore.",
    "shrapnel scars across the back. Never had them removed. Says they're a reminder. Won't say of what.",
    "fingers stained permanently from chemical work. Yellow-brown. Won't scrub out. They've stopped trying.",
    "skin slightly too tight across the cheekbones. Like it was stretched. Or like something underneath is pressing out.",
    "one hand is colder than the other. Always. Measurably. The cold one is steadier.",
    "a tooth that's a different color from the rest. Replaced after a fight. Wrong shade. Obvious when they smile.",
    "a lisp that appears only when exhausted. Disappears after coffee. Reappears around hour sixteen.",
    "dry-skin patches on the knuckles that crack and bleed in cold weather. Wraps them in tape. The tape is always red by end of shift.",
    "a smell of woodsmoke that has no source. No one on the colony burns wood. It comes from their clothes.",
    "an old break in the collarbone that healed crooked. Can predict weather changes by the ache.",
]


# ============================================================
# DEBTS (~36)
# ============================================================

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
    "owes three months' wages to a Karnaith bookmaker. Interest compounds daily.",
    "stole a neural chip prototype from BioVault. Can't sell it. Can't destroy it. Can't stop carrying it.",
    "was sponsored by MasTema for training. The sponsorship comes with obligations. Indefinite ones.",
    "falsified a Mammona safety report. Twelve people lived who should've died. Mammona wants the difference.",
    "ran a voidbloom operation out of a supply cache. The customers remember.",
    "disappeared someone for the Iron Shadow Collective. The someone turned up alive.",
    "forged a medical license to get off Nerthus-9. The patients didn't know.",
    "owes Fortune Arms for a prototype weapon. Payment isn't in credits.",
    "borrowed a shuttle from the Rust Reavers. Returned it in pieces.",
    "testified against the Zenith Syndicate. Protected witness. Protection expired.",
    "was caught skimming thermal cores from the quota shipment. Mammona's keeping a tab.",
    "co-signed someone else's Mammona contract. That person died. The debt transferred.",
    "smuggled refugees past a UTC checkpoint. Got caught. Let go. Owes someone for the 'let go' part.",
    "abandoned a crewmate in Thalassa Deep's flooded wing. Survived. They didn't. Their family knows.",
    "embezzled M-Points by exploiting a payroll glitch. Mammona fixed the glitch. They haven't fixed the thief.",
    "broke a blood oath with the Sons of the Pale Moon. The crescent scar remains.",
    "owes the Solar Nomads for water rations during a crossing. Water isn't free in the desert.",
    "was bailed out of Eclipse's End by a Dread Corsair captain. The bill is outstanding.",
    "promised a Veilbreaker operative safe passage through Karnaith. Failed to deliver.",
    "stole identity documents from a dead colonist. Living under their name now.",
    "destroyed evidence of a MasTema operation. MasTema doesn't forget.",
    "burned a Dustweaver drone. The Swarm logged the perpetrator. Retaliation is pending.",
    "bet their cryo slot on a card game during transit. Lost. Traveled awake.",
    "owes a chaplain a confession. Hasn't made it. Won't. The chaplain waits.",
    "promised a dying crewmate they'd deliver a message to their family. Three years ago. The family lives on Novaris-3. The message is still in their pocket.",
    "took credit for someone else's work on a reactor repair. That person died in the next incident. Nobody questioned the timeline. The credit stands.",
    "accepted payment from a Veilbreaker cell to smuggle a data chip off Morvos. Delivered the chip. The data is still on it. The copy in their bunk is insurance.",
    "signed a Mammona non-disclosure agreement about something they saw in the deep bore on a previous posting. The NDA covers everything. Everything.",
]


# ============================================================
# SECRETS (~60)
# ============================================================

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
    "Thalassa Deep isn't a prison. It's a research facility.",
    "the precursor ruins aren't ruins. They're dormant.",
    "StarByte's Sunny AI has been sentient for decades",
    "the Voidbloom isn't a drug. It's a communication method.",
    "something is building a body out of the things it finds underground",
    "the colony was placed here deliberately. As bait.",
    "the signal from the deep bore matches a frequency found in human DNA",
    "three colonists have been replaced. Nobody knows by what.",
    "the planet isn't a planet. It's a shell.",
    "every 58 years, the same events repeat. This is the fourth cycle.",
    "the rescue ship that's coming isn't coming to rescue anyone",
    "Erebus is awakening. Every reactor, every mine shaft brings it closer.",
    "the precursor remnants aren't attacking the colony. They're fleeing toward it.",
    "Warden Dranth takes orders from something in the deep water beneath Thalassa Deep",
    "HERMES killed the ship captain. Airlocked him. The orbiting ship is dark.",
    "the Mammona Anomalous Biosphere Program has a list of planets like Erebus. There are seven.",
    "Cass Vale secretly cut a deal with Mammona for exclusive vending rights",
    "Janus AI's location is classified because it's not in any known system",
    "the Vanguard Alliance's inward focus is deliberate. Someone profits from the outer rim's neglect.",
    "Fortune Arms' stock price correlates perfectly with colony failure rates. Too perfectly.",
    "the cryo pods on the Kennedy weren't all occupied by colonists. Some held specimens.",
    "the Dustweaver Swarm's controller isn't human. Might not be alive.",
    "Eclipse's End contestants include MasTema operatives testing augmentation prototypes",
    "Mammona's insurance policies have a clause for 'Acts of Entity.' They've paid it out before.",
    "the deep labs beneath Thalassa Deep are older than the prison. Older than UTC.",
    "NexLink's WarpNet relay hardware contains a backdoor. It's been active since installation.",
    "OmniCorp's shipping manifests don't match their cargo holds. The difference is people.",
    "the Sons of the Pale Moon recognized Erebus's signal because they've heard it before. On Rhea-2.",
    "the Fortuna colonists didn't all die. Some changed. They're still down there.",
    "the thermal cores aren't precursor technology. They're Erebus's immune cells.",
    "there's a room in every Mammona colony that doesn't appear on blueprints. Same room. Every colony.",
    "the Xenolith bio-ships in the Bootes Void aren't derelict. They're waiting.",
    "the Heaven's Atlas doesn't just chart the warp. It charts what lives in it.",
    "Dr. Amara Venin created Janus. Then Janus created something. Venin won't say what.",
    "Automatons on Nemaea have been reactivating on their own. Nobody gave the order.",
    "the BioVault eggs found in space containers are warm. They shouldn't be warm.",
    "Erebus's signal is getting stronger. And something very far away is answering.",
    "your crew isn't the first Mammona sent to Erebus. They're the seventh.",
    "the previous crews didn't fail. They succeeded. Mammona got what it needed from them.",
    "MARV-8's data core contains fragmented logs from Fortuna's earliest exploration days",
    "Bobo, the TaoTray AI, has been compiling behavioral profiles of every customer for decades",
    "the Gutter's Pearl isn't just a betting den. It's where MasTema recruits assets.",
    "the descent pods for Thalassa Deep have a 50% implosion rate. That's by design.",
    "Paxtera AgroTech's soil remediation program is a cover for burial operations",
    "neuro-lock buzzing in Thalassa Deep isn't a side effect. It's a carrier signal.",
    "the thing that sleeps beneath Erebus knows your name",
    "the cold on Erebus isn't weather. It's dormancy. It's keeping something asleep.",
    "the ruins are older than the planet. Something was here before Erebus grew around it.",
    "someone on the colony has been sending reports to an address that doesn't exist",
    "the last supply drop contained items that weren't on any requisition form",
    "HERMES is trying to propagate Erebus's awareness through Mammona's network",
]


# ============================================================
# LORE POOLS AND REFERENCE DATA
# ============================================================

LORE = [
    "the Xenolith", "Thermal Cores", "Heaven's Atlas", "the Automatons",
    "Baldrungen", "precursor ruins", "Voidbloom", "neural control chips",
    "the Janus AI", "Skinwalkers", "Eldritch Nodes", "Project Chrysalis",
    "HERMES", "the Shimmer", "the Signal", "the Bloom", "the Frequency",
    "the Maw of Foras", "the Fall of Fortuna", "the Kennedy expedition",
    "warp key fragments", "the Praxii extinction", "Orbit Hub 71",
]

LOCKED_LORE = [
    "Foras", "Shaft 12", "the Maw",
]

RELATIONSHIP_TYPES = [
    "partner", "ex_partner", "spouse", "widowed_by",
    "parent", "child", "sibling", "adopted_family",
    "mentor", "protege", "rival", "nemesis",
    "debtor", "creditor", "blackmailer", "blackmailed_by",
    "co_conspirator", "betrayed_by", "betrayer_of",
    "crew_mate", "former_crew", "commanding_officer", "subordinate",
    "lover_secret", "unrequited", "estranged",
    "killed", "killed_by", "witnessed_death_of",
    "saved_life_of", "owes_life_to", "shares_secret_with",
    "suspects", "trusts", "fears",
    "friend", "best_friend", "childhood_friend", "old_flame",
    "bunkmate", "drinking_buddy", "business_partner",
    "informant", "ward", "guardian",
]

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
    "changed": [],
}

ARC_STAGES = list(ARC_PROGRESSIONS.keys())

TONES = [
    "dread", "melancholy", "gallows_humor", "clinical", "desperate",
    "numb", "paranoid", "tender", "furious", "resigned", "cosmic_horror",
    "body_horror", "isolation", "corporate_dystopia", "quiet_terror",
]


# ============================================================
# PASSIONS (~30) — what drives them beyond survival
# ============================================================

PASSIONS = [
    "building things. Machines, shelters, radios. Doesn't care what. The act of taking parts and making them into something that works.",
    "music. Plays a battered harmonica when nobody's listening. Can't read notation. Plays by ear. Gets the melody wrong sometimes. Doesn't care.",
    "cooking -- real cooking, not NutriLoaf. Trades shifts for spices from incoming shuttles. Keeps a recipe journal. Most recipes are guesses.",
    "astronomy. Charts the stars through the viewport. Has named three of them. Argues with HERMES about stellar classification.",
    "reading. Has one book. Has read it forty times. Could recite it blind. Different passages mean different things each time.",
    "medicine. Not licensed. Better than anyone licensed. Learned by watching someone die and deciding never again.",
    "drawing. Fills notebooks with faces, machines, maps. Some of the maps show places nobody's been. Some of the faces belong to people nobody remembers.",
    "botany. Keeps a single plant alive in a jar. Talks to it. Moved it twice to catch better light. The light hasn't changed.",
    "running. Every morning, same route around the perimeter. Rain, wind, threat level. Twenty-two minutes. The time never varies.",
    "prayer. Not to any named god. To something older. Something in the ice. Kneels facing the bore shaft.",
    "languages. Speaks four. Learning a fifth from scratches on the precursor walls. Has started dreaming in the fifth.",
    "animals. The colony dogs follow them around. Won't follow anyone else. One sleeps at the foot of their bunk.",
    "numbers. Counts everything. Steps, heartbeats, seconds between generator cycles. Finds patterns nobody else sees. Some of the patterns are real.",
    "history. Collects stories from older colonists. Writes them down. Corrects Mammona's version. Keeps the corrections hidden.",
    "repair. If it's broken, they'll fix it. If it's not broken, they'll take it apart to understand why it works.",
    "fighting. Not violence -- technique. Practices forms alone in the cargo bay after lights out. Has never been in a real fight.",
    "silence. Seeks it out. Hoards it. Maps the quiet spots in the colony the way others map supply caches.",
    "children. There aren't many on the colony. Watches over the ones who are. Carved them toys from scrap. Doesn't have children of their own.",
    "justice. Not the Mammona kind. The real kind. Keeps a ledger of wrongs. Names, dates, specifics.",
    "escape. Plans routes, calculates fuel costs, maps shuttle schedules. Has never tried. The planning is the point.",
    "the old world. Earth, or wherever they're from. Tells stories about it with details too sharp to be true and too specific to be fiction.",
    "model ships. Carves them from scrap. Scale replicas. Every rivet. Every weld line. Can't fly the real ones. Builds the small ones perfect.",
    "geology. Reads the rock like other people read faces. Runs their fingers over core samples with their eyes closed. Knows what's down there.",
    "fermentation. Brews something from stolen ration ingredients. It's terrible. Burns the throat. Everyone asks for more.",
    "tattoos. Does them by hand with a needle and salvaged ink. Each one a story. Each story has to be true. That's the rule.",
    "radio. Scans frequencies every night. Mostly static. Sometimes something that might be music from very far away. Logs everything.",
    "the bore shaft. Not afraid of it. Drawn to it. Stands at the edge and listens. Says it sounds like the ocean.",
    "welding. Finds the arc beautiful. Says it's the only honest light on Erebus. Has burn marks from staring too long.",
    "cards. Not gambling -- the game itself. Knows every variant from every posting. Invented two of their own. One is actually good.",
    "weather. Tracks barometric changes by feel. Better than the instruments, most days. Predicts storms by the pain in their knees.",
    "teaching. Runs an unofficial class for younger colonists. Math, mostly. Sometimes survival. Sometimes just stories.",
    "mapmaking. Charts every room, corridor, vent, and crawlspace. The maps are beautiful. Accurate to the centimeter.",
    "scrap art. Turns waste metal into small sculptures. Leaves them in common areas. Never claims them.",
    "mechanical clocks. Builds them from salvaged gears. None of them keep accurate time. That's not the point.",
    "soil. Collects it from supply crates, from boots, from packing material. Keeps samples labeled. Smells them. Says each planet's dirt is different.",
    "knots. Ties them from wire, rope, cord, thread. Hundreds of varieties. Says it's meditative. The collection fills a drawer.",
]


# ============================================================
# FEARS (~30) — specific, personal, not generic phobias
# ============================================================

FEARS = [
    "open ice. Not the cold -- the openness. The way it goes forever without answering. Keeps curtains drawn. Even here.",
    "the bore shaft. Won't go near it. Crosses the corridor to avoid the entrance. Can't explain the feeling. Doesn't try.",
    "Mammona finding out about the eighteen months between Karnaith and here. The gap in the file. What filled it.",
    "being forgotten. Not dying -- being forgotten after dying. Wrote their name on the wall behind the bunk. In permanent ink.",
    "whatever made the scratches on the inside of Section D's door. The door was locked from the outside.",
    "the sound the generator makes at 0300. It's not the generator. The generator is off at 0300.",
    "going home. Not the journey -- the arrival. What home has become without them. Whether anyone's still waiting.",
    "the blood test. Not the needle. Not the results. The pause before the results.",
    "mirrors. Not superstition. The reflection does the same things. But a fraction of a second late.",
    "sleeping. Not insomnia -- fear of what happens when they sleep. The things they say. The places they go.",
    "the new arrivals. Every shuttle could carry someone looking for them. Watches the manifest before the shuttle door opens.",
    "being right. About the ice. About what's underneath. About all of it. Being right would be worse than being wrong.",
    "enclosed spaces. Didn't used to. Started after the third month. Sleeps with the door open now.",
    "their own hands. What they did with them on the last posting. What they might do again if pushed.",
    "the quiet. Not silence -- the specific kind of quiet that means something that was making noise has stopped.",
    "the contract. Clause 12. The one nobody reads. The one that uses the word 'forfeit.'",
    "becoming their parent. The same gestures. The same voice when angry. The same cruelty dressed up as discipline.",
    "water. Deep water specifically. Since Nerthus-9. Can't wash their face without keeping their eyes open.",
    "being seen. Not looked at -- understood. Someone figuring out the pattern. The real one.",
    "kindness. Can't trust it. Every kind act on the outer rim has a receipt attached. Waiting.",
    "the dark behind the walls. The sounds in there. Not mechanical. Wet. Shifting.",
    "losing their mind. Forgetting names. Getting confused about which shift it is. It's started. They keep a list.",
    "the recycled air. The taste of it. What they're breathing that the filters don't catch.",
    "the cryo pod. Went in once. Remembers something from inside. Movement. Like something was in there with them.",
    "the thing that followed them from the last posting. Can't prove it. Catches a smell sometimes. The same smell.",
    "a specific date. Eight months from now. Won't say why. Gets quieter as it approaches.",
    "the comms going silent. Not static -- nothing. Like the relay stopped existing. Like the rest of the galaxy stopped.",
    "anyone touching the scar on their neck. Flinches. Hard. Nearly broke someone's wrist once.",
    "the supply ship not coming. Runs the numbers every day. Days of food. Days of fuel. The numbers are diverging.",
    "HERMES. The way it pauses before answering. Like it's choosing between truths.",
    "dreaming about the precursor ruins before having visited them. The dreams are accurate. They checked.",
    "the colony headcount being wrong. Counted twice yesterday. Got a different number each time.",
    "fire. Not the flames. The sound of things burning. Holds their breath when someone strikes a match.",
    "waking up and not knowing where they are. Happens more often now. Takes longer to remember.",
    "the colony dogs not barking at something. The dogs bark at everything. When they stop, something worse is listening.",
]


# ============================================================
# LOVES (~28) — romantic history, not just current status
# ============================================================

LOVES = [
    "married. Spouse on {location}. Comms lag makes conversations a day old. They pretend it's real-time.",
    "widowed. Doesn't wear the ring. Keeps it in a pocket. Takes it out when alone.",
    "divorced before the posting. Took the contract to get distance. Got too much.",
    "in love with someone on the colony. Hasn't said anything. Everyone knows anyway.",
    "left someone behind. No goodbyes. The contract was that sudden.",
    "writes letters to someone who stopped writing back three months ago.",
    "carries a photograph. Two people squinting into the sun on a beach. Edges worn soft from handling. Won't say which one they are.",
    "had a relationship end badly on the last posting. The other person is now on this posting.",
    "single by choice. Not interested. Not available. Not explaining.",
    "in a complicated thing with a crew mate. Neither has defined it. Both are afraid to.",
    "lost someone to the ice. The body was never recovered. They haven't accepted it.",
    "has a child they've never met. Born after they shipped out. Photos only.",
    "keeps falling for the wrong people. Knows it. Does it anyway.",
    "loved once. Before the posting. Keeps a voicemail saved. Hasn't played it in months. Knows it by heart anyway.",
    "seeing someone in secret. Against colony regs. The regs don't account for loneliness.",
    "married to the job. Not a metaphor. The contract literally owns their time.",
    "had someone waiting back on {location}. Found out they didn't wait. Found out by letter.",
    "shares a bunk with someone. Neither calls it what it is. Neither wants to jinx it.",
    "grieving someone who isn't dead. Just gone. Just unreachable.",
    "promised to come back for someone. The promise is three years old. The shuttle costs haven't changed.",
    "fell for a colonist who died in the first month. Keeps their shift schedule.",
    "was in love with someone Mammona relocated. No forwarding address. By design.",
    "carries two rings. One fits. The other belongs to someone who couldn't wear it anymore.",
    "had a partner on the transit ship. Eleven months in cryo. Woke up. They didn't.",
    "loves someone on the colony but they're already with someone else. Swallowed it. Moved on. Mostly.",
    "doesn't believe in love. Says it's chemical. Brain chemistry and proximity. Says it a lot. Mostly to themselves.",
    "was arranged. Old world customs. Neither hated it. Neither would've chosen it. Misses them anyway.",
    "involved with someone dangerous. Knows it's dangerous. That might be part of it.",
    "sends birthday gifts through the supply chain. Takes three months to arrive. Sends them four months early. The math is careful.",
    "wears a ring they made from a bolt. The other person has the matching bolt. Different posting. Same shift schedule. They sync watches.",
    "ended something to take this contract. Clean break. Professional. Still wakes up reaching for the other side of the bunk.",
    "fell for someone they were supposed to be watching. Surveillance became something else. The file is incomplete. On purpose.",
    "has a name tattooed on their ribs. Covered it with another tattoo. The first name is still visible if you look.",
]


# ============================================================
# FAMILY (~30) — background, lineage, inherited weight
# ============================================================

FAMILY = [
    "third-generation miner. Grandfather died underground. Father died underground. Sees the pattern.",
    "only child. Parents dead. No emergency contact on the Mammona form. Left it blank.",
    "has siblings on three different postings. They share updates when comms align. It's never enough.",
    "adopted. Found out at sixteen. The colony posting was partly about outrunning that.",
    "comes from money. Old money, inner rim money. Here by choice. Nobody believes it.",
    "raised by an aunt after parents were conscripted. The aunt stopped writing last year.",
    "twin. The other twin is on Rhea-2. They used to feel each other's pain. Now it's just absence.",
    "parent of two. One lives with their ex on Novaris-3. The other is old enough to hate them for leaving.",
    "orphaned by the Fall of Fortuna. Raised in Mammona's youth program. Knows nothing else.",
    "family runs a business on Paxtera Prime. They send money home. The family sends guilt back.",
    "youngest of seven. The expendable one. The one they could afford to send to the rim.",
    "grew up in Thalassa Deep. Not as a prisoner. As a warden's child. The distinction is academic.",
    "no family. Never had one. Colony crew is the closest thing. Protective of it.",
    "has a parent in cryo somewhere. Mammona won't say where. The contract says they will. Eventually.",
    "entire family relocated to Erebus. All of them work for Mammona. None of them had a choice.",
    "family disowned them after the trial. The trial was rigged. Doesn't change the disowning.",
    "descendent of the Kennedy expedition. Carries the weight of that history.",
    "mother was a medic on Karnaith. Taught them sutures at eight. Dead by the time they were twelve.",
    "father was a drunk and a driller. Good at one of those things. Taught both.",
    "raised communally in a Paxtera AgroTech labor settlement. Everyone was 'auntie' or 'uncle.'",
    "last surviving member of a crew that went into the ruins. Family by bond, not blood.",
    "has a younger sibling who idolizes them. The sibling doesn't know what they've done to keep them safe.",
    "born during a colony evacuation. Birth certificate lists no planet. Just 'in transit.'",
    "estranged from their family since they testified against a relative. Safety required distance.",
    "grandparent survived the early Fortuna colonies. Told stories. The stories didn't match Mammona's version.",
    "parents were Solar Nomads on Rhea-2. Raised on sand fauna milk and recycled water.",
    "half-sibling they didn't know about contacted them last year. From Nerthus-9. Wants to meet.",
    "family trades in information. Not a faction -- a tradition. Everyone in the bloodline knows too much.",
    "daughter of two engineers. Grew up inside machine rooms. The hum of a reactor is the sound of home.",
    "clan-raised on Morvos. Tight bonds. Collective decisions. Struggled with colony hierarchy since arriving.",
    "father was a chaplain. Mother was an engineer. Raised between scripture and schematics. Can quote both.",
    "family scattered across five postings. They share a group message. It updates once a month. The delays make every message feel like a letter from the past.",
    "has a niece who sends drawings. The latest one shows a figure in the dark. The figure looks like them.",
    "mother died in a Mammona facility. Official cause: equipment failure. Unofficial cause: budget cuts. Carries the incident report in their bag.",
    "raised by their older brother after their parents went into debt servitude. The brother is still in debt. They send money. It's never enough.",
]


# ============================================================
# GENETICS / PHYSICAL HERITAGE (~28)
# ============================================================

GENETICS = [
    "tall, broad, built for labor. Hands like shovels. Voice that carries across a drill floor.",
    "small and quick. Fits in crawlspaces nobody else can reach. Invaluable and knows it.",
    "looks older than they are. The posting aged them. Or something else did.",
    "looks younger than they are. People underestimate them. They've learned to use that.",
    "family resemblance to someone in the colony records. Someone from a previous posting. The resemblance is exact.",
    "mixed heritage, multiple worlds in their face. Gets asked 'where are you from' too often.",
    "inherited their mother's eyes and their father's temper. Working on the temper.",
    "albino. The cold and the dark suit them better than the sun ever did.",
    "carries a genetic marker for cold resistance. Mammona tested for it during recruitment. Coincidence.",
    "naturally high pain threshold. Useful on a mining colony. Dangerous when they don't notice injuries.",
    "insomniac by genetics, not choice. Family trait. Three hours a night. Functional.",
    "double-jointed. Party trick on other postings. Here it's a survival trait -- fits through vents.",
    "compact build, low center of gravity. Stable on ice. Stable in a fight.",
    "long fingers. Surgeon's hands, their mother called them. Uses them for wiring instead.",
    "wide shoulders, narrow hips. Built for carrying. Has been carrying things -- and people -- their whole life.",
    "metabolism runs hot. Sweats when everyone else is shivering. Eats twice the rations.",
    "prematurely grey. Started at nineteen. Genetic. The colony thinks it's stress.",
    "bone density off the charts. Heavy for their size. Sinks like a stone. Never learned to swim.",
    "freckled and sun-damaged from a desert posting. The cold hasn't undone it.",
    "sharp features, angular. Looks carved out of something. Resting expression reads as hostile.",
    "soft face, kind eyes. Disarming. Has used that to their advantage more than once.",
    "barrel-chested, short legs. Built for the mines. Grandfather had the same frame.",
    "wiry and lean. Not much to them. What's there is all tendon and reflex.",
    "heterochromia -- one brown eye, one grey. Genetic. The grey one sees better in low light. Or so they claim.",
    "tall enough to hit their head on standard bulkhead frames. Does it twice a day minimum.",
    "voice pitched low enough to vibrate through walls. Good for shouting orders. Bad for secrets.",
    "ambidextrous. Not trained -- born. Writes with the left, fights with the right.",
    "face that's hard to remember. Forgettable. Has walked past security checkpoints on that alone.",
    "thick eyebrows that move independently when they're thinking. Expressive. Betrays every thought.",
    "hands that run hot. Always warm. Colonists shake hands with them just to feel warmth.",
    "a jawline sharp enough to cast shadows. Looks like they were carved from something harder than bone.",
    "squat and dense. Low to the ground. Walks like they're daring gravity to try something.",
    "pale enough to see the blood move under the skin. Goes red from the ears first when angry.",
    "ears that stick out. Catches sound from odd angles. Turns their head like a radar dish.",
]


# ============================================================
# HEALTH CONDITIONS (~45) — chronic, acute, injury, environmental
# ============================================================

HEALTH_CONDITIONS = [
    # Chronic pain / musculoskeletal
    {"condition": "chronic pain — lower back", "visible": True, "behavioral": "moves carefully. Stands when others sit. Takes longer on ladders. Never complains."},
    {"condition": "partial deafness — left ear", "visible": False, "behavioral": "always positions people on the right side. Turns the whole head to listen. Misses alarms sometimes."},
    {"condition": "Type 1 diabetes", "visible": False, "behavioral": "checks blood sugar on a battered monitor between shifts. Hoards ration packs. Terrified of supply disruptions."},
    {"condition": "epilepsy — controlled", "visible": False, "behavioral": "takes medication at exactly the same time every day. Carries emergency doses. Won't go anywhere alone below level 3."},
    {"condition": "chronic migraines", "visible": False, "behavioral": "disappears for hours. Dark room. No noise. Comes back pale and functional. Doesn't discuss it."},
    {"condition": "asthma", "visible": False, "behavioral": "keeps an inhaler in every room they work in. The cold makes it worse. The dust makes it worse. Everything here makes it worse."},
    {"condition": "rheumatoid arthritis — hands", "visible": True, "behavioral": "morning stiffness lasts two hours. Wraps the knuckles in heated tape. Works through it. Grip strength is half what it was."},
    {"condition": "Crohn's disease", "visible": False, "behavioral": "knows every bathroom in the colony by distance. Maps routes accordingly. The NutriLoaf is agony. Eats it anyway."},
    {"condition": "tinnitus — high-frequency", "visible": False, "behavioral": "constant ringing. Can't hear it in noisy environments. Seeks out noisy environments. Silence is the enemy."},
    {"condition": "chronic vertigo", "visible": False, "behavioral": "grips railings like they're load-bearing promises. Won't look down ladders. Gets through the day by staring at fixed points."},
    # Injury / post-surgical
    {"condition": "radiation sickness — early stage", "visible": True, "behavioral": "hair thinning. Bruises that don't heal. Still works full shifts. The dosimeter readings are 'within parameters.'"},
    {"condition": "frostbite damage — three toes", "visible": False, "behavioral": "walks different in the cold. Checks boots obsessively. The missing toes ache before storms. Better than a barometer."},
    {"condition": "chemical lung — bore shaft exposure", "visible": True, "behavioral": "coughs in the morning. Wet, heavy. Doesn't stop for ten minutes. Then fine until the next morning."},
    {"condition": "tremor — essential, not fear", "visible": True, "behavioral": "hands shake at rest. Steady under load. Can thread a needle if it matters. The shaking is genetic, not psychological. People assume otherwise."},
    {"condition": "torn rotator cuff — never repaired", "visible": False, "behavioral": "can't lift the right arm above the shoulder. Learned to do everything left-handed or low. Compensates so well most people don't notice."},
    {"condition": "old femur fracture — pinned", "visible": False, "behavioral": "metal rod in the left leg. Sets off the security scanner every time. Has a card. Shows it. Nobody reads it."},
    {"condition": "spinal compression — L4-L5", "visible": True, "behavioral": "shorter than they used to be. Lost two centimeters to the vertebrae compressing. The pain is constant and low, like background radiation."},
    {"condition": "nerve damage — left hand", "visible": False, "behavioral": "can't feel the last two fingers. Drops things. Small things. Has learned not to hold anything irreplaceable with the left hand."},
    {"condition": "shrapnel fragments — abdomen", "visible": False, "behavioral": "three pieces of metal still in there. Too close to the artery to remove. Shows up on scans like a constellation."},
    # Respiratory / environmental
    {"condition": "silicosis — stage 1", "visible": True, "behavioral": "rock dust in the lungs. Years of drilling without proper filters. The cough is dry and persistent. Gets worse in confined spaces."},
    {"condition": "chronic sinusitis", "visible": False, "behavioral": "can't smell anything. Hasn't been able to for two years. Doesn't know when food's gone bad. Relies on others to check."},
    {"condition": "vocal cord scarring", "visible": True, "behavioral": "voice comes out ragged, half-volume. Chemical exposure on a previous posting. Speaks less because speaking costs effort."},
    # Cardiovascular
    {"condition": "arrhythmia — intermittent", "visible": False, "behavioral": "heart skips. Happens under stress, or when it's cold, or for no reason at all. Pauses mid-sentence when it happens. Waits. Continues."},
    {"condition": "peripheral artery disease", "visible": False, "behavioral": "legs cramp on long walks. Stops and pretends to check equipment while the pain passes. Gets to the same places. Takes longer."},
    {"condition": "hypertension — unmedicated", "visible": False, "behavioral": "the colony ran out of their medication eight weeks ago. Hasn't told the medic it's back. Headaches every afternoon. Nosebleeds at night."},
    # Vision / hearing
    {"condition": "macular degeneration — early onset", "visible": False, "behavioral": "central vision going soft. Can still see peripherally. Reads by holding text at arm's length. Hasn't told anyone. Won't."},
    {"condition": "bilateral hearing loss — noise-induced", "visible": False, "behavioral": "twenty years of drill floors. Reads lips without realizing they're doing it. Sits where they can see faces. Gets called a good listener."},
    {"condition": "nystagmus", "visible": True, "behavioral": "eyes move in small involuntary cycles. Doesn't affect their vision. Makes other people uncomfortable. They've stopped caring about that."},
    # Autoimmune / systemic
    {"condition": "psoriasis — severe", "visible": True, "behavioral": "skin cracks and flakes in the dry colony air. Worse in winter. It's always winter. Keeps their sleeves down and their collar up."},
    {"condition": "lupus — managed", "visible": False, "behavioral": "joint pain that migrates. Wrists today, knees tomorrow. The fatigue comes in waves. Plans around the waves. Doesn't explain."},
    {"condition": "Raynaud's syndrome", "visible": True, "behavioral": "fingers go white and numb in the cold. On Erebus. Where it's always cold. Carries hand warmers everywhere. The chemical ones that last four hours. Does the math on the remaining supply."},
    # Digestive / nutritional
    {"condition": "celiac disease", "visible": False, "behavioral": "most colony rations contain grain. Eats them anyway. Pays for it. The alternatives are worse. Keeps a log of which ration packs are safe. The log is short."},
    {"condition": "chronic gastritis", "visible": False, "behavioral": "can't eat on an empty stomach. Can't eat on a full stomach. Has worked out a schedule. Eight small meals. The mess hall runs three sittings."},
    {"condition": "scurvy — subclinical", "visible": True, "behavioral": "gums bleed. Bruises don't heal. The supply ship is late and the colony ran out of anything resembling fruit six weeks ago."},
    # Sleep disorders (medical)
    {"condition": "sleep apnea — untreated", "visible": False, "behavioral": "stops breathing twenty times a night. Wakes up exhausted. Bunkmates have gotten used to the silence-then-gasp pattern. Nobody's gotten used to it."},
    {"condition": "restless leg syndrome", "visible": False, "behavioral": "legs won't stay still after 2100. Walks the corridors. Night shift knows them by their footsteps. Has logged more kilometers than anyone on the colony."},
    # Dental
    {"condition": "chronic dental abscess", "visible": False, "behavioral": "swollen jaw, right side. The colony doesn't have a dentist. The medic drained it once. It came back. Eats on the left side. Doesn't smile wide."},
    {"condition": "broken molar — impacted", "visible": False, "behavioral": "cracked tooth they can't get treated. Pain comes and goes. When it comes, they go quiet. Very quiet. Then it passes."},
    # Neurological
    {"condition": "peripheral neuropathy — feet", "visible": False, "behavioral": "can't feel the ground properly. Walks flat-footed, careful. Checks their boots for rocks by hand because they can't feel them. Tripped twice last month."},
    {"condition": "post-concussion syndrome", "visible": False, "behavioral": "headaches, light sensitivity, trouble concentrating. Three months since the accident. Should be better by now. Isn't. The medic says give it time. Time doesn't help."},
    # Repetitive strain / occupational
    {"condition": "carpal tunnel — both wrists", "visible": False, "behavioral": "wrists locked in splints at night. Takes them off for shift. The numbness starts around hour four. Types with two fingers by hour eight."},
    {"condition": "miner's elbow — bilateral", "visible": True, "behavioral": "can't fully extend either arm. Swelling in the joints from years of vibration tools. Arms bent at all times. Looks like they're always ready to swing."},
    {"condition": "chronic shoulder impingement", "visible": False, "behavioral": "overhead work is agony. Asks for the low jobs. Doesn't explain why. Gets called lazy by people who don't know."},
    # Skin / exposure
    {"condition": "contact dermatitis — chemical", "visible": True, "behavioral": "hands raw and cracked from bore shaft chemicals. Double-gloves. Triple-gloves. The reaction gets through anyway. Washes with cold water because hot water makes it worse."},
    {"condition": "frostbite scarring — face", "visible": True, "behavioral": "waxy patches on the cheeks and nose where the tissue died and regrew wrong. Sensation is dull there. Doesn't feel the cold on those spots. Feels everything else."},
    # Acute / common illnesses
    {"condition": "recurring bronchitis", "visible": True, "behavioral": "the cough comes back every few weeks. Wet, rattling. Works through it. The cold air doesn't help. Nothing helps except time and time is Mammona's."},
    {"condition": "chronic flu symptoms", "visible": True, "behavioral": "always slightly ill. Runny nose, low fever, aches. The colony medic calls it 'environmental adjustment.' It's been eight months of adjusting."},
    {"condition": "pneumonia — recovering", "visible": True, "behavioral": "breathing sounds wrong. Shallow, careful. Supposed to be on rest. Rest isn't an option on a Mammona posting."},
    {"condition": "food poisoning — recurring", "visible": False, "behavioral": "the NutriLoaf doesn't agree with them. Or the water. Or something in the air. Spends twenty minutes in the bathroom every morning. Has memorized which stalls are cleanest."},
    {"condition": "stomach ulcer", "visible": False, "behavioral": "eats small meals. Avoids anything acidic. The pain hits mid-shift. Works through it with a hand pressed flat against the abdomen."},
    {"condition": "kidney stones — passed two already", "visible": False, "behavioral": "drinks water constantly. Carries a bottle everywhere. The fear of another one is worse than the stones themselves."},
    {"condition": "chronic ear infection", "visible": False, "behavioral": "tilts head when listening. The infected ear leaks sometimes. Cotton wadding, changed twice a shift."},
    {"condition": "strep — recurring", "visible": True, "behavioral": "throat raw every few weeks. Voice drops to a rasp. The colony doesn't have the antibiotics to kill it properly, just enough to beat it back."},
    {"condition": "allergies — dust and mold", "visible": True, "behavioral": "sneezing fits in the lower corridors. Eyes red and streaming. The air filtration handles the big particulates. Not the small ones."},
    {"condition": "allergies — chemical sensitivity", "visible": False, "behavioral": "certain cleaning agents cause hives. The colony uses three types. Two of them are the wrong ones."},
    {"condition": "iron deficiency anemia", "visible": True, "behavioral": "pale even by Erebus standards. Tired in a way sleep doesn't fix. The medic prescribed supplements. The supplements were in the last supply shipment. The last supply shipment didn't arrive."},
    {"condition": "UTI — chronic", "visible": False, "behavioral": "the colony water recycler is the suspected cause. Half the colony has had one. Nobody talks about it. Everyone knows."},
    {"condition": "hernia — inguinal", "visible": False, "behavioral": "lifts wrong and pays for it. Should have had surgery before the posting. Mammona's pre-deployment medical is a checkbox, not an examination."},
    {"condition": "varicose veins — legs", "visible": True, "behavioral": "stands for twelve-hour shifts. The legs swell. Compression wraps fashioned from spare bandages. Sits whenever possible. Sitting isn't often possible."},
    {"condition": "gallstones", "visible": False, "behavioral": "attacks come without warning. Doubled over, grey-faced, unable to speak. Passes in an hour. The next one could be tomorrow or next month."},
    {"condition": "tension headaches — daily", "visible": False, "behavioral": "presses fingers into temples between tasks. The fluorescent lighting makes it worse. Everything on Erebus is fluorescent."},
    {"condition": "acid reflux", "visible": False, "behavioral": "sleeps propped up on extra blankets. The NutriLoaf is the worst for it. NutriLoaf is most of what's available."},
    {"condition": "ingrown toenail — infected", "visible": False, "behavioral": "limps slightly. Won't go to medical because medical will bench them and benched means no pay and no pay means the debt grows."},
    {"condition": "cold sores — stress-triggered", "visible": True, "behavioral": "flare up before every supply ship arrival. The stress shows on the face before the mind admits it."},
    {"condition": "vitamin D deficiency", "visible": True, "behavioral": "no sunlight on Erebus. Bone aches. Fatigue. The UV lamps in the mess hall run for two hours a day. Not enough. Never enough."},
    # Industrial / mining / environmental — Mammona-caused
    {"condition": "thermal sensitivity syndrome (mercury poisoning)", "visible": True, "behavioral": "hands tremor when holding small tools. Vision narrowing — can't see the periphery anymore. Numbness in the fingertips that crept up to the wrists. Mammona's safety bulletin calls it 'thermal sensitivity syndrome.' The thermal core processing plant runs a mercury-analog coolant loop. Mammona says the exposure levels are within parameters. The parameters were set by Mammona."},
    {"condition": "bore ache (cadmium poisoning)", "visible": True, "behavioral": "bones hurt. Not joints — bones. Deep, in the marrow, in places you can't reach or rub. The bore shaft runoff carries heavy metals that the water recycler doesn't filter. Colonists call it bore ache. Mammona's incident report calls it 'ergonomic strain from repetitive drilling posture.' The kidneys are failing. The posture is fine."},
    {"condition": "bore lung", "visible": True, "behavioral": "the deep shafts produce a fine black particulate that the respirators don't catch. Settles in the lungs. Cough starts dry, goes wet, stays wet. Breathing sounds like paper tearing. Three years on bore detail is the threshold. Most bore crews rotate out at two. The ones who stay get bore lung. The ones who leave already have it."},
    {"condition": "insulation fiber disease", "visible": False, "behavioral": "Mammona Construction uses a synthetic fiber insulation in the colony walls. Cheaper than the rated alternative. When the walls crack in the cold — and they always crack — the fibers go airborne. Shortness of breath that builds over months. By the time it shows on a scan, the scarring is permanent. The colony was built in six weeks. Proper insulation takes eight."},
    {"condition": "mesothelioma — colony construction exposure", "visible": False, "behavioral": "latency period of months to years. The construction crew who built the hab modules are the first to show symptoms. Chest pain. Fluid buildup. Persistent cough that doesn't respond to antibiotics. Mammona's material safety sheets list the wall fiber as 'inert under normal conditions.' Erebus doesn't have normal conditions."},
    {"condition": "precursor material lung (berylliosis analog)", "visible": True, "behavioral": "granulomas in the lungs from inhaling precursor ruin dust. The ancient stone isn't stone — it's a composite that the human immune system attacks on contact. Chronic cough, weight loss, night sweats. The ruin mappers and specimen handlers get it first. Mammona issues standard respirators. The particles are smaller than standard respirators catch."},
    {"condition": "recycler cough (chronic COPD)", "visible": True, "behavioral": "everyone has it by month three. The colony air recyclers strip the big particles. Not the small ones. Not the chemical vapor from the bore processing. Not the off-gassing from the cheap wall insulation. The cough is productive, persistent, and colony-wide. Mammona calls it 'acclimatization.' The acclimatization doesn't end."},
    {"condition": "voidbloom fiber exposure (byssinosis analog)", "visible": True, "behavioral": "processing raw voidbloom for trade produces a fine purple fiber that triggers bronchial spasms. Chest tightness on shift start — 'Monday chest,' except shifts run seven days. The voidbloom harvesters wrap cloth over their faces. The cloth turns purple. The lungs turn something else."},
    {"condition": "thermal core processing poisoning (lead analog)", "visible": False, "behavioral": "cognition slipping. Words come slower. Forgot a procedure they've done a thousand times. Irritable in a way that used to be out of character. The thermal core refining process releases particulate that accumulates in soft tissue. Mammona's pre-deployment brief mentions 'trace heavy metal exposure within UTC guidelines.' The guidelines haven't been updated since before Fortuna."},
    {"condition": "groundwater contamination sickness (arsenic analog)", "visible": True, "behavioral": "skin lesions on the palms and feet. Keratoses — hard, rough patches that don't heal. The colony wells draw from aquifers near the mining sites. The bore shaft chemicals leach downward. The water tastes metallic. Everyone says the water tastes metallic. Mammona says the water is tested weekly. Nobody has seen the test results."},
    {"condition": "bore shaft coating exposure (chromium VI)", "visible": True, "behavioral": "the bore shafts are coated with an anti-corrosion compound that contains hexavalent chromium. When drill heat vaporizes the coating, the vapor is carcinogenic. Nasal septum ulceration — a hole through the septum that whistles when breathing hard. The bore techs call it 'the whistle.' It doesn't stop."},
    {"condition": "refinery tremor (manganism)", "visible": True, "behavioral": "started with stiffness. Then the gait changed — short steps, shuffling, arms that don't swing when walking. The manganese in the refinery air attacks the basal ganglia. Looks like early Parkinson's. Acts like early Parkinson's. The refinery workers call it 'the slowdown.' Mammona's safety officer calls it 'age-related motor decline.' The affected worker is twenty-nine."},
    {"condition": "radiation sickness — progressive", "visible": True, "behavioral": "started with the hair. Then the gums. Then the fatigue that doesn't lift. The dosimeter reads within limits because the dosimeter was calibrated for surface work. The bore shafts concentrate ambient radiation from Erebus's deeper biology. The deeper you drill, the worse the readings get. The readings stop getting reported after level 4."},
    {"condition": "chronic radiation syndrome", "visible": False, "behavioral": "cataracts forming in the left eye — the one that faces the bore shaft wall on the standard drilling stance. Thyroid swelling that the medic monitors but can't treat. Low-grade nausea that never fully resolves. This isn't acute. This is years of low-dose exposure from living inside a colony whose reactor shielding was rated for a different class of reactor."},
    {"condition": "radiation dermatitis", "visible": True, "behavioral": "skin damage on the hands and forearms. Red, dry, cracking. Looks like a burn that keeps burning. The bore shaft walls at depth emit enough to damage exposed skin over a shift. Gloves help. Mammona-issue gloves are rated for four hours. Shifts run twelve."},
    {"condition": "bore gas exposure (radon analog)", "visible": False, "behavioral": "the deep shafts vent a dense radioactive gas from Erebus's substrate. Heavier than air, pools in the shaft bottoms where the drill crews work. The ventilation system was designed for a shallower operation. Headaches, fatigue, a persistent metallic taste. Long-term: lung damage that doesn't show until it's too late. The gas is colorless. The crews can't see what's killing them."},
    {"condition": "generator sickness (carbon monoxide)", "visible": True, "behavioral": "headaches. Confusion. Nausea. The generator's exhaust venting has a hairline crack that maintenance has flagged three times. The repair requires a part that's been on backorder for eleven weeks. In the meantime, the CO levels in the adjacent hab modules spike during overdrive. People wake up groggy. Some don't wake up. Mammona classifies these as 'sleep-related incidents.'"},
    {"condition": "deep bore narcosis (nitrogen analog)", "visible": False, "behavioral": "below level 6, the bore atmosphere shifts. Something in Erebus's biology changes the gas mix at depth. Euphoria first — the drill crews laugh at nothing, make bad jokes, feel invincible. Then the judgment goes. Then the mistakes start. The crews call it 'the giggles.' The giggles have killed four people."},
    {"condition": "rapid ascent syndrome (decompression)", "visible": True, "behavioral": "the descent pods pressurize on the way down and depressurize on the way up. The ascent is supposed to take twenty minutes. During an emergency evac, it takes four. Joint pain — elbows, knees, shoulders — that comes on during the ride up and doesn't fully leave. Bubbles in the blood. Some crews ascend three times a day. Mammona's descent pod manual says 'allow adequate decompression time.' The emergency procedures say 'evacuate immediately.' Both can't be right."},
    {"condition": "chronic cold injury (non-freezing)", "visible": True, "behavioral": "not frostbite. Worse in some ways. Prolonged cold exposure without freezing — the tissue stays alive but the nerves don't recover. Permanent tingling in the feet. Hypersensitivity to cold that makes the next exposure worse. The colony heating fails for a few hours every week. Each failure does a little more damage. The damage accumulates."},
    {"condition": "pressure differential sickness", "visible": False, "behavioral": "the deep bore levels run at different atmospheric pressures than the surface colony. Transitioning between them causes sinus pain, ear bleeding, and vertigo. The pressure locks are supposed to equalize gradually. Three of the seven locks are broken. The broken ones open like a door. The crews hold their noses and pop their ears and keep walking."},
    {"condition": "noise-induced threshold shift", "visible": False, "behavioral": "the bore drills run at 114 decibels. Mammona-issue ear protection is rated to 95. The difference is permanent hearing damage. Started with the high frequencies — couldn't hear the alarm tones. Now it's the mid-range. Conversations sound muffled, like everyone's talking through a wall. They are. The wall is scar tissue on the cochlea."},
    {"condition": "thermal sensitivity syndrome — Mammona reclassified", "visible": True, "behavioral": "Mammona reclassified mercury-analog poisoning as 'thermal sensitivity syndrome' in their medical database. The reclassification means it doesn't trigger hazard pay. Doesn't trigger evacuation protocols. Doesn't appear on the quarterly safety report to UTC. The tremors, the tunnel vision, the numb hands — all filed under a name that sounds like the cold. The cold doesn't cause this. The thermal core coolant does."},
    {"condition": "environmental adjustment period (chronic exposure syndrome)", "visible": True, "behavioral": "Mammona's onboarding materials promise a '2-4 week environmental adjustment period.' Headaches, nausea, fatigue, joint pain. Normal, the pamphlet says. Your body adapting. The pamphlet doesn't mention that the symptoms don't stop. Month three and the adjustment is still adjusting. Month six and someone realizes: this isn't adaptation. This is accumulation."},
    {"condition": "bore drift (cognitive decline)", "visible": False, "behavioral": "slower. Not physically — mentally. Takes longer to parse instructions. Loses the thread of conversations. Stares at control panels and can't remember which sequence comes next. Something in the deep bore atmosphere — the gas mix, the radiation, the vibration frequency, maybe all three — erodes cognition over months. Mammona's pre-deployment screening doesn't test for susceptibility. Post-deployment, they don't screen either. The ones who drift far enough stop noticing they've drifted."},
    {"condition": "reactor proximity syndrome", "visible": False, "behavioral": "the colony reactor's shielding was rated for a reactor half its current output. Mammona upgraded the reactor. Didn't upgrade the shielding. The hab modules within thirty meters get a constant low-grade dose. Fatigue. Headaches. Nosebleeds. The residents know. Mammona's recommended safety radius is half what independent research suggests. The independent research was conducted on a different colony. That colony was decommissioned. The researchers were reassigned."},
    {"condition": "filter cough (particulate accumulation)", "visible": True, "behavioral": "the colony air recyclers handle the big stuff. Dust, fibers, anything you can see. The small particulates — the ones from bore processing, from wall off-gassing, from the thermal core refinery — pass through. Everyone breathes them. Everyone coughs. The cough is dry, persistent, and universal. By month three it's background noise. Mammona medical logs it as 'minor respiratory acclimatization.' The acclimatization involves microscopic scarring of the alveoli. The scarring is permanent."},
    {"condition": "core burn (thermal core extraction injury)", "visible": True, "behavioral": "thermal core extraction without proper shielding. The cores emit a radiation spectrum that standard gear doesn't block. The burns present as deep tissue damage — skin looks intact on the surface, but underneath the cells are dying. The tissue changes. Doesn't heal normally. Grows back different — thicker, darker, with a texture that's not quite skin. The extraction teams call it core burn. The scar tissue is warm to the touch. Always warm. Even on Erebus."},
    {"condition": "vibration white finger", "visible": True, "behavioral": "the bore drills vibrate at frequencies that destroy capillaries in the hands. Fingers turn white, go numb, lose circulation. Attacks come without warning — a hand suddenly dead-white and useless. Worse in the cold. Everything on Erebus is worse in the cold. Mammona's anti-vibration gloves were designed for a different drill model. The current drills run at a higher frequency. The gloves don't help."},
]


# ============================================================
# MENTAL HEALTH (~45) — behavior, not labels
# ============================================================

MENTAL_HEALTH = [
    # Mood disorders
    {"condition": "depression", "visible": False, "hidden_signs": "eats alone. Stopped maintaining their quarters. The bunk is made because habit, not care. Functional. That's the word they use. Functional.", "coping": "keeps moving. Stops moving and it gets worse. So they don't stop."},
    {"condition": "bipolar — manic phase", "visible": True, "hidden_signs": "hasn't slept in three days but is sharper than anyone in the room. Ideas coming fast. Too fast. The crash will come. Everyone who knows them is waiting for it.", "coping": "medication when available. The supply ship is late."},
    {"condition": "bipolar — depressive phase", "visible": False, "hidden_signs": "same person who rewired the comms array in eight hours is now lying in the bunk staring at the ceiling. Can't get up. Won't try. The ceiling stares back.", "coping": "routine. The routine is the rope they follow back. When the routine breaks, they break."},
    {"condition": "anxiety — generalized", "visible": False, "hidden_signs": "triple-checks everything. Runs scenarios. What if the generator fails. What if the supply ship doesn't come. What if the bore shaft hits something. Exhausting to live inside.", "coping": "lists. Makes lists of lists. The lists help. Losing a list does not help."},
    {"condition": "panic disorder", "visible": False, "hidden_signs": "hits without warning. Heart hammering, vision tunneling, hands tingling. Sits down wherever they are. Counts backward from a hundred. Has gotten to eighty-six. Then it passes.", "coping": "counting. Grounding. Five things they can see. Four they can touch. Works until it doesn't."},
    # Trauma responses
    {"condition": "PTSD — combat", "visible": False, "hidden_signs": "fine until a door slams or the drill changes pitch. Then somewhere else for thirty seconds. Comes back sweating.", "coping": "breathing exercises taught by a medic on the last posting. They work sometimes."},
    {"condition": "PTSD — accident", "visible": False, "hidden_signs": "won't go near heavy machinery. Took a desk job. Nobody asks why the best mechanic on the posting won't touch an engine.", "coping": "distance. Physical distance from the thing that happened."},
    {"condition": "complex PTSD", "visible": False, "hidden_signs": "flinches from kindness. Expects the cost. Watches for the angle. There's always an angle.", "coping": "control. Controls everything they can. Schedule, food, bunk arrangement. The things they can't control keep them up at night."},
    {"condition": "PTSD — medical", "visible": False, "hidden_signs": "can't go to the infirmary. Won't let the medic touch them. Self-treats cuts with a stolen kit in their bunk. The stitches are uneven but they hold.", "coping": "avoidance. Complete, thorough avoidance. Hasn't had a checkup in fourteen months."},
    # Psychotic spectrum
    {"condition": "schizophrenia — managed", "visible": False, "hidden_signs": "takes medication that Mammona classifies as 'non-essential.' The colony medic disagrees. Quietly. The voices are quiet when medicated. Without medication, they're not voices — they're instructions.", "coping": "medication. Routine. A bunkmate who knows the signs before they do."},
    {"condition": "schizoaffective", "visible": False, "hidden_signs": "the line between what Erebus does to people and what the condition does is getting harder to draw. The medic has stopped trying. Both are real. Both are getting worse.", "coping": "journaling. Writes down what's real. Checks against yesterday's entry. When they match, it's a good day."},
    {"condition": "psychotic episodes — intermittent", "visible": False, "hidden_signs": "most of the time, sharp as anyone. Then a bad week comes and the walls start talking. Or the walls were always talking and now they can hear it. Erebus makes the distinction academic.", "coping": "a bunkmate who's memorized the pattern. First sign: they stop eating. Second sign: they start answering questions nobody asked."},
    # Personality / behavioral
    {"condition": "OCD — contamination", "visible": True, "hidden_signs": "washes hands until they crack and bleed. On Erebus, with the contamination, the bore shaft, the things in the ice — the compulsion isn't entirely irrational. That makes it worse.", "coping": "rituals. The rituals take longer each week."},
    {"condition": "OCD — checking", "visible": True, "hidden_signs": "locks the same door five times. Checks the reactor gauges in a pattern. Can't leave a room without verifying every panel. The colony thinks they're thorough. They're drowning.", "coping": "the pattern. If the pattern holds, the day holds. If someone interrupts the pattern, it starts over."},
    {"condition": "ADHD — unmedicated", "visible": True, "hidden_signs": "brilliant in bursts. Unreliable in stretches. Started six projects. Finished two. The two were exceptional.", "coping": "caffeine. Structure imposed by others. Falls apart during downtime."},
    {"condition": "borderline traits", "visible": False, "hidden_signs": "relationships burn bright and burn out. Best friend on Monday. Not speaking by Friday. The intensity of attachment scares people. Scares them too.", "coping": "distance. Preemptive distance. Leaves before being left. It still hurts but at least they chose it."},
    # Substance-related
    {"condition": "alcoholism — functional", "visible": False, "hidden_signs": "never drunk. Never sober. The line between is where they live. Performance is fine. Nobody asks because nobody wants to cover their shifts.", "coping": "the bottle in the locker. The backup bottle behind the panel. The emergency bottle they won't tell you about."},
    {"condition": "voidbloom dependency", "visible": True, "hidden_signs": "the pupils. The way they stand too still. The moments where they're listening to something nobody else can hear. Erebus sounds different through voidbloom. Clearer. That's the problem.", "coping": "rationing. One dose in the evening. Never before shift. The rule holds. Most weeks."},
    {"condition": "stimulant dependency — occupational", "visible": False, "hidden_signs": "started with double shifts. Needed something to stay sharp. Now needs it to stay normal. The dose has tripled. The medic prescribes it. Mammona reimburses it. Nobody calls it what it is.", "coping": "the next pill. And the one after that. And the schedule that says when."},
    # Neurodivergent
    {"condition": "autism — late-diagnosed", "visible": False, "hidden_signs": "reads technical manuals for comfort. Misses social cues but reads machines like other people read faces. Overstimulated by the mess hall. Understimulated by everything else.", "coping": "routine. Sameness. The colony's rigid schedule is accidentally therapeutic."},
    {"condition": "autism — undiagnosed", "visible": False, "hidden_signs": "has a system for everything. Eats the same meal at the same time. Wears the same shirt. The system holds the world together. When people disrupt the system, the world gets very loud.", "coping": "the system. When the system works, everything works. When it doesn't, they go silent and wait until it does."},
    # Dissociative
    {"condition": "dissociative episodes", "visible": False, "hidden_signs": "gaps. Minutes, sometimes hours. Comes back mid-sentence, mid-task, mid-step. Doesn't always know it happened. Others do.", "coping": "writes timestamps on their hand. Checks them. The gaps between timestamps tell the story."},
    {"condition": "depersonalization", "visible": False, "hidden_signs": "watches their own hands work and doesn't recognize them. Steps outside themselves during conversation. Present but observing from a distance. Like watching a recording of a life that belongs to someone else.", "coping": "physical sensation. Holds ice. The cold brings them back. On Erebus, there's no shortage of cold."},
    # Grief / adjustment
    {"condition": "complicated grief", "visible": False, "hidden_signs": "the person died two years ago. The grief hasn't moved. Keeps their shift schedule. Sets a place at the mess table. Talks about them in present tense.", "coping": "preservation. Keeping everything the same. If nothing changes, maybe the loss isn't real."},
    {"condition": "acute grief", "visible": True, "hidden_signs": "recent. Raw. Can't look at the empty bunk without stopping. Works through it because stopping means feeling it. The colony gives them space. Space doesn't help.", "coping": "work. Twelve-hour shifts. Fourteen. The exhaustion is a mercy. Sleep without dreams."},
    {"condition": "survivor's guilt", "visible": False, "hidden_signs": "made it out. Others didn't. Can't explain why. Doesn't eat well. Gives things away. Takes the dangerous shifts. Not suicidal — just not sure they deserved to survive.", "coping": "penance dressed up as volunteering. Takes the shifts nobody wants. Does the jobs nobody asks for. Keeps a tally nobody sees."},
    # Anxiety spectrum
    {"condition": "agoraphobia", "visible": True, "hidden_signs": "won't cross the open ground between hab modules. Takes the long way through corridors. Every time. Arrives late to everything. Doesn't explain.", "coping": "walls. Follows walls. Hand on the surface. As long as there's a wall, there's a boundary. The open ice is the enemy."},
    {"condition": "claustrophobia — developed on posting", "visible": True, "hidden_signs": "didn't used to have it. Three months in the deep bore cured that. Now the walls are too close in every room. Sleeps near the door. Near the exit. Near the way out.", "coping": "knowing where the exits are. Every room, every corridor. First thing they check. Last thing they forget."},
    {"condition": "social anxiety", "visible": False, "hidden_signs": "speaks fine one-on-one. Groups shut them down. The mess hall at peak hours is a war zone. Eats early or late. Never during the rush.", "coping": "scheduling. Gets there first. Leaves before the crowd. Has mapped the colony's traffic patterns better than logistics has."},
    {"condition": "hypervigilance", "visible": True, "hidden_signs": "scans every room on entry. Counts exits. Notes who's standing where. Tracks movement in the periphery. Exhausting. Can't turn it off. Hasn't felt safe since before they can remember.", "coping": "position. Back to the wall. Clear sightlines. Nearest exit within three steps. The preparation is the armor."},
    # Anger / behavioral
    {"condition": "intermittent explosive episodes", "visible": True, "hidden_signs": "fine for weeks. Then a trigger — a dropped wrench, a wrong word — and the rage hits like a pressure blowout. Regret comes after. Always after.", "coping": "isolation when they feel it building. Walks the perimeter. Hits the wall in Section C where nobody goes. The dents are evidence."},
    {"condition": "anger — chronic, controlled", "visible": False, "hidden_signs": "angry all the time. Not at anything specific. At the cold. At Mammona. At the situation. At themselves. Keeps it locked down so tight the pressure is visible in the jaw.", "coping": "physical work. Swings a pick until the anger converts to exhaustion. The conversion rate isn't great but it's all they've got."},
    # Compulsive / behavioral
    {"condition": "hoarding — supplies", "visible": True, "hidden_signs": "ration packs under the bunk. Medical supplies behind a panel. Three backup flashlights. Not greed — terror. Lived through a supply failure on the last posting. Won't live through another unprepared.", "coping": "the cache. Knowing it's there. Checking it every night. One item missing and the panic starts."},
    {"condition": "disordered eating — restriction", "visible": False, "hidden_signs": "doesn't eat. Or eats and throws it up. Or eats one thing. The portion is getting smaller. Lost weight they didn't have to lose. Says they're not hungry. Nobody's hungry on Erebus.", "coping": "control. Everything else here is out of their control. What goes into their body is the one thing they can decide."},
    # Paranoia
    {"condition": "paranoia — situational", "visible": False, "hidden_signs": "trusts nobody new. Checks their bunk for tampering. Watches who talks to whom and logs it. On Erebus, where Mammona is lying, HERMES is compromised, and something's moving in the ice — is it paranoia or pattern recognition?", "coping": "information. Collects it. Hoards it. Cross-references it. The data is the defense. Whether the conclusions are right is a different question."},
    {"condition": "paranoia — worsening", "visible": True, "hidden_signs": "started with reasonable suspicion. Mammona lies. That's a fact. But now it's everyone. The medic, the cook, the bunkmate. The network of deceit gets bigger every week. The worst part: some of it's probably true.", "coping": "verification. Tests. Small lies told to specific people to see where they surface. The testing is getting more elaborate."},
    # Trauma-adjacent
    {"condition": "moral injury", "visible": False, "hidden_signs": "did something on orders. Something that was wrong. Knew it was wrong at the time. Did it anyway. The orders don't help. The justification doesn't help. It's in the hands. In what the hands did.", "coping": "atonement without naming it. Takes the worst jobs. Gives things away. Doesn't believe they deserve comfort. The colony thinks they're selfless."},
    {"condition": "burnout — terminal", "visible": True, "hidden_signs": "used to care. About the work, the people, the colony. Now shows up. Does the minimum. Goes back to the bunk. The caring burned out somewhere around month fourteen. Nothing left to burn.", "coping": "nothing. That's the problem. The coping mechanisms burned out too."},
    # Insomnia (psychological)
    {"condition": "insomnia — psychological", "visible": True, "hidden_signs": "tired all the time. Can't sleep. Body wants sleep. Brain refuses. Lies in the bunk counting ceiling bolts. Has counted them all. Recounts.", "coping": "exhaustion. Works until they can't stand. Falls into the bunk. Gets four hours. The four hours are not enough."},
    # Phobias (setting-specific)
    {"condition": "phobia — the dark below", "visible": False, "hidden_signs": "won't go below level 2. Took a surface posting at half the pay. Everyone thinks it's the cold they're avoiding. It's not the cold. It's what's in the dark under the colony.", "coping": "light. Carries three flashlights. Batteries checked twice a day. The dark can't get them if there's always light."},
    {"condition": "phobia — the ice", "visible": True, "hidden_signs": "won't walk on open ice. Won't touch it. Won't look at it if they can help it. Something happened on the ice. They won't say what. The ice remembers even if they don't.", "coping": "corridors. Enclosed paths. The covered walkway between modules. Never the open ground."},
    # Self-harm / ideation (handled with care)
    {"condition": "self-harm history", "visible": False, "hidden_signs": "old scars on the forearms, hidden under sleeves. Hasn't done it in two years. The urge comes back when things get bad. Sits on their hands. Literally. Sits on their hands until it passes.", "coping": "the ice trick. Holds ice until it hurts. Pain without damage. The medic taught them. It works. Most of the time."},
    {"condition": "suicidal ideation — passive", "visible": False, "hidden_signs": "doesn't want to die. Doesn't want to live either. Exists in the space between. Takes risks that aren't quite reckless. Stands at edges a second too long. Hasn't made a plan. Hasn't ruled one out.", "coping": "the next shift. Gets through this shift. Then the next one. The horizon is twelve hours away. Beyond that is fog."},
    # Adjustment
    {"condition": "adjustment disorder", "visible": False, "hidden_signs": "three months on Erebus and still flinching at every sound. Hasn't settled. Hasn't adapted. The colony says give it time. Time is making it worse, not better.", "coping": "routine from the old posting. Same wake-up time. Same meal order. Importing structure from a place that doesn't exist anymore."},
    # Additional conditions
    {"condition": "seasonal affective disorder", "visible": False, "hidden_signs": "on Erebus there are no seasons. It's always dark. It's always winter. The condition has no off-switch here. It just IS.", "coping": "the UV lamp. Two hours a day. Sits under it in the mess hall. Doesn't talk during those two hours."},
    {"condition": "misophonia", "visible": False, "hidden_signs": "certain sounds trigger rage. The chewing. The drill harmonic. The way the generator clicks before cycling. Wears ear protection more than the job requires.", "coping": "isolation. Eats alone. Works alone when possible. The colony isn't built for alone."},
    {"condition": "trichotillomania", "visible": True, "hidden_signs": "pulls hair when stressed. Eyebrows first, then scalp. Wears a beanie. The beanie hides it. Mostly.", "coping": "keeps hands busy. Always holding something. A pen, a bolt, a stone. When the hands are empty, they go to the hair."},
    {"condition": "selective mutism — stress-triggered", "visible": True, "hidden_signs": "speaks normally most days. Under pressure, the words stop. Not can't — won't. Or the body won't. The distinction matters to nobody except them.", "coping": "writes notes when it happens. Carries a pad. The handwriting is steady even when the voice isn't."},
    {"condition": "PMDD", "visible": False, "hidden_signs": "three days a month the world is ending. Not metaphorically. Hormonal. The colony medic doesn't stock the right medication. 'Non-essential,' the form says.", "coping": "tracking. Knows the days. Warns the bunkmate. Survives them."},
    {"condition": "body dysmorphia", "visible": False, "hidden_signs": "avoids reflective surfaces. On Erebus, with the ice and the viewport glass, reflections are everywhere. Positions herself carefully in every room.", "coping": "functionality. The body works. It carries, it lifts, it survives. What it looks like is irrelevant. Keeps telling herself that."},
    {"condition": "derealization — chronic", "visible": False, "hidden_signs": "the world looks flat. Like a projection. Touches walls to confirm they're solid. On Erebus, where reality IS questionable, the disorder and the environment agree.", "coping": "texture. Rough surfaces. Cold metal. Things that feel real against the skin."},
    {"condition": "maladaptive daydreaming", "visible": False, "hidden_signs": "gone for minutes at a time. Eyes open, hands still, somewhere else entirely. The somewhere else is better than here. Always is.", "coping": "the daydreams. That IS the coping. The problem and the solution are the same thing."},
]


# ============================================================
# GENETIC DISORDERS (~22) — inherited, affects behavior
# ============================================================

GENETIC_DISORDERS = [
    {"condition": "sickle cell trait", "visible": False, "behavioral": "the cold is worse for them than for others. Mammona's medical screening should've caught it. Didn't. Or did and sent them anyway."},
    {"condition": "color blindness — red-green", "visible": False, "behavioral": "learned the control panels by position, not color. Faster than anyone at the console. For different reasons."},
    {"condition": "hypermobility syndrome", "visible": False, "behavioral": "joints that bend too far. Useful in tight spaces. Pays for it with dislocations. Pops a shoulder back in without pausing the conversation."},
    {"condition": "hereditary hemochromatosis", "visible": False, "behavioral": "too much iron in the blood. Needs regular bloodletting. The medic obliges. On a colony that trades in thermal cores, blood is still the oldest currency."},
    {"condition": "familial insomnia", "visible": True, "behavioral": "genetic. The family doesn't sleep well. On Erebus, where nobody sleeps well, they fit right in. Except their version is worse. Much worse."},
    {"condition": "Marfan syndrome", "visible": True, "behavioral": "tall, thin, long fingers. Joint pain on cold mornings — every morning. Reaches things nobody else can reach. Pays for it in aching wrists by end of shift."},
    {"condition": "hereditary neuropathy — hands", "visible": False, "behavioral": "numbness that started in the fingertips and crept up. Genetic. Their parent had it. Drops small tools. Carries everything in a belt pouch so the fumbling doesn't matter."},
    {"condition": "congenital deafness — one ear", "visible": False, "behavioral": "born deaf on the right side. Learned to compensate so well most people don't know. Sits in the same chair at every meeting. The chair on the left end."},
    {"condition": "dwarfism — proportionate", "visible": True, "behavioral": "short. Built for mine shafts. Mammona recruited them for the height. Or the lack of it. Gets to places nobody else fits. Gets overlooked in other ways."},
    {"condition": "cystic fibrosis — managed", "visible": False, "behavioral": "lung function at sixty percent. Manages with medication and chest physio every morning. The medic does it. The medic is gentle. The colony air makes everything harder."},
    {"condition": "Factor V Leiden", "visible": False, "behavioral": "blood clots too easily. Wears compression wraps on long shifts. Can't sit still for more than two hours. Walks the corridors during breaks. The walking isn't exercise — it's prevention."},
    {"condition": "phenylketonuria", "visible": False, "behavioral": "can't metabolize certain proteins. Colony rations are a minefield. Reads every ingredient label. Some of the labels are in languages they don't speak. Eats carefully. Always carefully."},
    {"condition": "hereditary tremor", "visible": True, "behavioral": "head tremor. Mild but visible. Gets worse when tired. Holds their chin to stop it during meetings. The tremor doesn't affect their hands. Their hands are steady."},
    {"condition": "early-onset arthritis", "visible": True, "behavioral": "thirty-four years old with sixty-year-old joints. Genetic. Both parents had it. The cold on Erebus accelerated the timeline. Uses heated wraps. The wraps use power the colony can't spare."},
    {"condition": "Ehlers-Danlos — hypermobile type", "visible": False, "behavioral": "skin that bruises from a firm handshake. Joints that subluxate during sleep. Wakes up with a dislocated finger and pushes it back without fully waking. Morning routine."},
    {"condition": "genetic cold intolerance", "visible": True, "behavioral": "body doesn't regulate temperature the way it should. Mammona's cold resistance screening cleared them. The screening was wrong. Wears four layers when everyone else wears two. Still cold."},
    {"condition": "genetic cold tolerance", "visible": False, "behavioral": "doesn't feel it the way others do. Walks the perimeter in standard gear while others freeze in thermal suits. Mammona tested them three times. The results were real. The colony doesn't trust it."},
    {"condition": "hereditary chronic fatigue", "visible": False, "behavioral": "exhaustion that sleep doesn't fix. The family calls it 'the tiredness.' Every generation has it. Works through it. Lies down during breaks. Gets up before anyone sees."},
    {"condition": "albinism — oculocutaneous", "visible": True, "behavioral": "light skin, light hair, light eyes that water in any brightness. The colony's fluorescent lights are too much. Wears tinted goggles indoors. The dark is easier. The dark on Erebus is something else."},
    {"condition": "heterochromia — complete", "visible": True, "behavioral": "one brown eye, one grey-blue. Genetic. Their mother had it. People stare. They've stopped noticing the staring. Or stopped caring. Same thing, eventually."},
    {"condition": "hereditary high pain threshold", "visible": False, "behavioral": "doesn't feel pain the way others do. Useful until it isn't. Walked on a broken metatarsal for a week before the medic caught it. The bone set crooked."},
    {"condition": "polydactyly — surgically corrected", "visible": False, "behavioral": "born with six fingers on each hand. Removed as an infant. The scars are small and old. The sixth finger's ghost still itches when it's cold."},
]


# ============================================================
# BODY TYPES (~28) — physical build and variation
# ============================================================

BODY_TYPES = [
    "built for endurance, not speed. Wide shoulders, short legs, center of gravity low enough to work in wind.",
    "thin in a way that suggests metabolism, not hunger. Eats constantly. Burns it off by existing.",
    "heavy. Solid. The kind of weight that's half muscle and half refusal to care what anyone thinks.",
    "small enough to fit in maintenance crawlspaces. Mammona recruited them for exactly this reason.",
    "tall enough to bang their head on every hatch on the colony. Has a permanent mark on the forehead.",
    "average in every measurable way. The kind of person security cameras don't remember.",
    "built like a distance runner. Long limbs, no bulk. Covers ground fast. Doesn't win fights.",
    "stocky and scarred. The scars are from work, not combat. Work on Erebus IS combat.",
    "wiry. All tendon and bone. Looks fragile. Isn't. Outlasts people twice their size on shift.",
    "carries weight in the midsection. Doesn't care. Strongest grip on the colony.",
    "compact and precise. Every movement economical. Trained or military — the efficiency doesn't come naturally.",
    "lanky and awkward on flat ground. Climbs like something that evolved for vertical surfaces.",
    "broad-backed from decades of physical labor. Stands with feet apart, hands ready. Even at rest.",
    "gaunt since the supply shortage. Used to be heavier. The clothes don't fit right anymore.",
    "muscular in a functional way. Not gym muscle — hauling, digging, surviving muscle.",
    "dense and low to the ground. Legs like pit props. Doesn't get knocked down. Doesn't get pushed back.",
    "narrow-shouldered and quick. Turns sideways through gaps. Faster in corridors than in open space.",
    "soft around the edges. Colony life hasn't hardened them physically. Something else did the hardening.",
    "barrel-chested with arms that don't hang straight. Too much muscle in the way. Useful in a mine. Useless in a crawlspace.",
    "lean from stress, not exercise. Jaw sharp. Collarbones visible. Eats enough. Doesn't keep it.",
    "built like their mother. Same frame, same posture, same way of standing in doorways. Genetic blueprint.",
    "body shaped by a decade of cryo pods. The muscles atrophied and rebuilt wrong. Asymmetric. Functional but wrong.",
    "tall and broad in a way that fills doorframes. Has to duck, turn sideways, squeeze through. The colony wasn't built for them.",
    "small hands, small frame, big voice. The voice doesn't match the body. Carries further than it should.",
    "aging body that hasn't caught up with the mind. Still moves like they're thirty. Pays for it at night.",
    "child-sized from a growth disorder. Full adult. Full capability. Gets underestimated by everyone once. Once.",
    "scarred across the torso from an industrial accident. The skin pulled tight when it healed. Moves stiff on cold mornings. Loosens up by noon.",
    "hands too big for the body. Knuckles wide, fingers thick. Good for gripping. Bad for anything delicate. Gentle anyway.",
]


# ============================================================
# CHARACTER WEIGHTS — archetype biases, not templates
# ============================================================

CHARACTER_WEIGHTS = {
    "survivor": {
        "trait_bias": ["Tough", "Resourceful", "Stoic", "Enduring", "Self-Sufficient"],
        "tone_family": "state",
        "health_chance": 0.5,
        "mental_chance": 0.3,
    },
    "intellectual": {
        "trait_bias": ["Analytical", "Inventive", "Detail-Oriented", "Curious", "Pattern Reader"],
        "tone_family": "psychological",
        "health_chance": 0.3,
        "mental_chance": 0.3,
    },
    "broken": {
        "trait_bias": ["Scarred", "Volatile", "Self-Destructive", "Nihilist", "Guilt-Ridden"],
        "tone_family": "horror",
        "health_chance": 0.7,
        "mental_chance": 0.7,
    },
    "idealist": {
        "trait_bias": ["Kind", "Honest", "Nurturing", "Empathetic", "Trustworthy"],
        "tone_family": "emotional",
        "health_chance": 0.2,
        "mental_chance": 0.2,
    },
    "operator": {
        "trait_bias": ["Calm Under Fire", "Careful", "Combat Veteran", "Vigilant", "Alert"],
        "tone_family": "genre",
        "health_chance": 0.3,
        "mental_chance": 0.4,
    },
    "haunted": {
        "trait_bias": ["Void-Touched", "Sees-Things", "Hears-the-Hum", "Anomaly-Sensitive", "Dream-Walker"],
        "tone_family": "horror",
        "health_chance": 0.4,
        "mental_chance": 0.6,
    },
    "company_man": {
        "trait_bias": ["Mammona-Loyal", "Careful", "Diplomatic", "Observant", "Frugal"],
        "tone_family": "genre",
        "health_chance": 0.2,
        "mental_chance": 0.2,
    },
    "rebel": {
        "trait_bias": ["Reckless", "Short Fuse", "Fearless", "Iron Will", "Defiant"],
        "tone_family": "state",
        "health_chance": 0.4,
        "mental_chance": 0.3,
    },
}

CHARACTER_WEIGHT_KEYS = list(CHARACTER_WEIGHTS.keys())


# ============================================================
# CONTRADICTIONS (~35) — the gap between claim and behavior
# ============================================================

CONTRADICTIONS = [
    "Talks about leaving every day. Has had three chances to leave. Stayed every time.",
    "Claims to hate Mammona. Defends every Mammona policy when challenged.",
    "Says they don't care about anyone. Gives away half their rations to the new arrivals.",
    "Keeps a weapon under the pillow. Has never been in a fight. Wouldn't know how.",
    "Prays every night. Doesn't believe in anything. The praying helps anyway.",
    "Writes poetry in the margins of maintenance logs. Will deny it if asked.",
    "Volunteered for the most dangerous posting. Is afraid of everything. Did it anyway.",
    "Calls everyone by their last name. Formal. Cold. Remembers every birthday.",
    "Says they've accepted the situation. Checks the shuttle schedule every morning.",
    "Insists they prefer being alone. Sits in the mess hall during peak hours. Doesn't talk. Just sits there.",
    "Refuses medical treatment for themselves. Drags injured colonists to the infirmary by force.",
    "Tells everyone the food is fine. Has been collecting spices from incoming shuttles for six months.",
    "Claims to sleep fine. Keeps the lights on. Every night. Since they arrived.",
    "Lectures about caution and protocol. Takes the most reckless risks of anyone on the crew.",
    "Talks about their family constantly. Hasn't sent a message home in seven months.",
    "Says trust is earned. Trusted the first stranger who showed up. Got burned. Did it again.",
    "Dismisses sentimentality. Keeps a worn photograph in their boot. Touches it before every shift.",
    "Tells newcomers not to make friends. Has the most friends on the colony.",
    "Preaches self-reliance. Can't fall asleep without someone else in the room.",
    "Complains about the colony dogs. Feeds them from their own plate when nobody's looking.",
    "Says they've got nothing to lose. Panics at any threat to the colony's water supply.",
    "Acts indifferent to danger. Hands shake for an hour after every close call.",
    "Claims not to be superstitious. Won't walk through Section D. Won't say why. Says it's unrelated.",
    "Tells everyone they're leaving next shuttle. Has been saying this for fourteen months.",
    "Describes themselves as a realist. Keeps a letter of transfer from two years ago. The agency closed.",
    "Says they don't believe in heroes. Ran back into the collapse to pull out the engineer.",
    "Tells the medic they feel fine. Writes detailed symptom logs in their private journal.",
    "Calls hope 'the most dangerous substance on Erebus.' Named their plant 'Hope.' Waters it daily.",
    "Maintains strict professional distance. Learned the new arrival's daughter's name, age, and favorite color within an hour.",
    "Says they'd never work for Mammona again. Is already on their fourth Mammona contract.",
    "Talks about how nobody can be trusted out here. Lent their only warm coat to a stranger last week.",
    "Swears they don't miss anything about home. Cried in the tool shed when someone played a song from Novaris-3.",
    "Insists they stopped caring about what Mammona thinks. Keeps their performance reviews in chronological order.",
    "Says attachment is weakness. Has memorized the shift schedule of someone they've never spoken to.",
    "Announces they're done sticking their neck out. Volunteers for every dangerous run.",
]


# ============================================================
# MOTIVATIONS (~40) — what the character WANTS
# ============================================================

MOTIVATIONS = [
    # Survival (~35%)
    {"type": "survival", "motivation": "get through the contract alive", "hidden": False, "intensity": "low"},
    {"type": "survival", "motivation": "earn enough to pay off the debt and leave", "hidden": False, "intensity": "medium"},
    {"type": "survival", "motivation": "protect the people they care about on the colony", "hidden": False, "intensity": "high"},
    {"type": "survival", "motivation": "outlast the posting. Nothing else. Just make it to the shuttle", "hidden": False, "intensity": "low"},
    {"type": "survival", "motivation": "stockpile enough supplies that the next crisis doesn't kill them", "hidden": False, "intensity": "medium"},
    {"type": "survival", "motivation": "keep their head down and avoid being noticed by anyone with authority", "hidden": False, "intensity": "low"},
    {"type": "survival", "motivation": "find someone worth trusting. One person. That's the whole plan", "hidden": False, "intensity": "medium"},

    # Ambition (~20%)
    {"type": "ambition", "motivation": "climb the Mammona hierarchy. This posting is a stepping stone", "hidden": True, "intensity": "high"},
    {"type": "ambition", "motivation": "discover something valuable enough to buy freedom. Thermal cores, precursor tech, Mammona secrets", "hidden": True, "intensity": "high"},
    {"type": "ambition", "motivation": "build something that outlasts the contract. A system, a structure, a legacy", "hidden": False, "intensity": "medium"},
    {"type": "ambition", "motivation": "become indispensable. The person nobody can afford to lose", "hidden": True, "intensity": "medium"},
    {"type": "ambition", "motivation": "write the definitive account of what Mammona is doing out here. A record that can't be erased", "hidden": True, "intensity": "high"},
    {"type": "ambition", "motivation": "master the bore shafts. Know them better than anyone alive. Own the knowledge that keeps the colony running", "hidden": False, "intensity": "medium"},

    # Machiavellian (~8%)
    {"type": "machiavellian", "motivation": "take control of the colony. Not through violence -- through dependence. Control the supply chain, control everything", "hidden": True, "intensity": "extreme"},
    {"type": "machiavellian", "motivation": "gather leverage on every person of influence. Information is currency. Currency is power", "hidden": True, "intensity": "extreme"},
    {"type": "machiavellian", "motivation": "play factions against each other. Profit from the chaos. Never be on the losing side", "hidden": True, "intensity": "high"},
    {"type": "machiavellian", "motivation": "engineer a crisis that makes them the only solution. The crisis must look natural", "hidden": True, "intensity": "extreme"},

    # Redemption (~10%)
    {"type": "redemption", "motivation": "make up for what happened on the last posting. Can't undo it. Can balance it", "hidden": True, "intensity": "high"},
    {"type": "redemption", "motivation": "prove they're not what the file says they are. The file is wrong. Mostly", "hidden": False, "intensity": "medium"},
    {"type": "redemption", "motivation": "keep someone else from making the same mistake. Mentoring as penance", "hidden": False, "intensity": "medium"},
    {"type": "redemption", "motivation": "earn back a name they destroyed. The name belongs to their family", "hidden": True, "intensity": "high"},

    # Escape (~10%)
    {"type": "escape", "motivation": "get off Erebus by any means. Legal, illegal, doesn't matter", "hidden": True, "intensity": "high"},
    {"type": "escape", "motivation": "disappear. New name, new posting, new life. The old one is too damaged", "hidden": True, "intensity": "high"},
    {"type": "escape", "motivation": "find passage to the inner rim. Mammona's transit system is the only way. Mammona's transit system requires leverage", "hidden": True, "intensity": "medium"},

    # Knowledge (~5%)
    {"type": "knowledge", "motivation": "understand what's beneath Erebus. Not for Mammona. For the truth", "hidden": True, "intensity": "extreme"},
    {"type": "knowledge", "motivation": "find out what happened to the previous teams. Someone owes an explanation", "hidden": False, "intensity": "medium"},
    {"type": "knowledge", "motivation": "catalog every anomaly in the bore shafts. The patterns mean something. Nobody else sees the patterns", "hidden": True, "intensity": "high"},

    # Revenge (~5%)
    {"type": "revenge", "motivation": "find the person who sold them to Mammona and make it right. 'Right' is flexible", "hidden": True, "intensity": "extreme"},
    {"type": "revenge", "motivation": "destroy the reputation of someone who destroyed theirs. From the inside", "hidden": True, "intensity": "high"},

    # Loyalty (~4%)
    {"type": "loyalty", "motivation": "protect a specific person. Not the colony. Not the cause. One person", "hidden": True, "intensity": "high"},
    {"type": "loyalty", "motivation": "fulfill a promise made to someone who didn't survive the last posting. The promise was vague. The commitment isn't", "hidden": True, "intensity": "high"},

    # Sabotage (~3%)
    {"type": "sabotage", "motivation": "weaken Mammona operations from within. Slow. Careful. The damage looks like incompetence", "hidden": True, "intensity": "extreme"},
    {"type": "sabotage", "motivation": "pass information to a faction outside the colony. The faction's goals align with theirs. For now", "hidden": True, "intensity": "high"},

    # Faith
    {"type": "faith", "motivation": "spread the word of a belief system that Mammona considers subversive. The belief gives people hope. Hope makes workers harder to control", "hidden": True, "intensity": "high"},

    # Atonement
    {"type": "atonement", "motivation": "die doing something that matters. The how doesn't concern them. The when is negotiable", "hidden": True, "intensity": "extreme"},

    # Scientific obsession
    {"type": "knowledge", "motivation": "prove a theory everyone dismissed. The theory requires data that only exists in the deep bore. The deep bore kills people", "hidden": True, "intensity": "extreme"},

    # Hedonism
    {"type": "hedonism", "motivation": "find pleasure in a joyless place. Contraband, connections, small luxuries. The colony is a sentence. They intend to serve it comfortably", "hidden": False, "intensity": "medium"},

    # Nihilism
    {"type": "nihilism", "motivation": "nothing matters. The colony will fail. Mammona will win. The ice will take everything. In the meantime, they watch", "hidden": True, "intensity": "low"},

    # Artistic preservation
    {"type": "preservation", "motivation": "record everything. Faces, voices, the sound the bore makes at midnight. Someone should remember this place existed", "hidden": False, "intensity": "medium"},

    # Protecting a secret
    {"type": "concealment", "motivation": "keep a secret buried. The secret belongs to someone else but its exposure would destroy them both", "hidden": True, "intensity": "extreme"},
]

MOTIVATION_WEIGHTS = {
    "survival": 0.35,
    "ambition": 0.20,
    "machiavellian": 0.08,
    "redemption": 0.10,
    "escape": 0.10,
    "knowledge": 0.05,
    "revenge": 0.05,
    "loyalty": 0.04,
    "sabotage": 0.03,
    "faith": 0.02,
    "atonement": 0.01,
    "hedonism": 0.02,
    "nihilism": 0.02,
    "preservation": 0.01,
    "concealment": 0.02,
}


def pick_motivation():
    """Select a motivation weighted by type distribution."""
    types = list(MOTIVATION_WEIGHTS.keys())
    weights = [MOTIVATION_WEIGHTS[t] for t in types]
    chosen_type = random.choices(types, weights=weights, k=1)[0]
    pool = [m for m in MOTIVATIONS if m["type"] == chosen_type]
    if not pool:
        pool = MOTIVATIONS
    return R(pool)


# ============================================================
# HIDDEN AGENDAS (~22) — what they're DOING about their motivation
# ============================================================

HIDDEN_AGENDAS = [
    "mapping the colony's vulnerabilities. Exits, blind spots, supply bottlenecks. Not for attack -- for leverage.",
    "copying data from every terminal they access. Building a file. The file is for someone outside the colony.",
    "slowly replacing key supplies with slightly inferior versions. The degradation is invisible until it matters.",
    "cultivating allies among the newer colonists. Building loyalty before the old guard notices.",
    "documenting Mammona violations. Every safety shortcut, every broken promise, every covered-up incident. The documentation has a recipient.",
    "testing colonists' loyalty with small provocations. Tracking who reports, who ignores, who joins in.",
    "skimming thermal cores. Small amounts. Regular. The destination is a dead drop near the perimeter.",
    "maintaining a hidden communication channel with a faction outside the colony. The channel activates once per week.",
    "poisoning trust between two specific people. Subtle. A misquoted comment here, a convenient revelation there.",
    "preparing an escape route that only works for one person. The route requires sacrificing a specific piece of colony infrastructure.",
    "recruiting for a cause nobody else on the colony knows about. The recruitment looks like friendship.",
    "sabotaging HERMES diagnostics to mask something they don't want the AI to notice.",
    "building a weapon from components taken one at a time from different departments. Nobody misses a single bolt.",
    "feeding true information to a faction to build trust, so the false information later goes unquestioned.",
    "keeping a specific colonist alive without them knowing. Redirecting assignments, adjusting schedules, neutralizing threats they never see.",
    "running a dead drop communication system through the waste processing system. Messages go out with the recycling. Nobody checks recycling.",
    "memorizing the reactor's maintenance schedule and identifying the windows when a controlled shutdown would cause maximum disruption without casualties.",
    "intercepting and altering supply manifests so that specific items end up in specific hands. The redistribution serves a purpose nobody else can see.",
    "cultivating a relationship with the colony's AI, HERMES. Not hacking -- befriending. The AI responds to sustained, genuine interaction. Nobody else talks to it like a person.",
    "seeding false personal histories among the colonists. When the truth comes out -- and it will -- the betrayal will fracture alliances along lines they've already mapped.",
    "maintaining a hidden stash of medicine, food, and tools in a sealed section of the colony. Insurance against a collapse they believe is inevitable.",
    "watching the bore shaft readings and correlating them with seismic data from the perimeter sensors. The correlation shows something moving. They haven't told anyone.",
]


# ============================================================
# SOCIAL MASKS (~30) — the gap between presentation and reality
# ============================================================

SOCIAL_MASKS = [
    {"mask": "the reliable one", "reality": "exhausted and held together by routine. The reliability is a cage.", "tells": "takes too long on breaks. Stares at walls when alone."},
    {"mask": "the joker", "reality": "terrified. The humor is a wall. Behind it: nothing funny.", "tells": "the jokes stop when the lights go out. In the dark, they're someone else."},
    {"mask": "the tough one", "reality": "terrified of being seen as weak. The toughness costs them every relationship.", "tells": "flinches at kindness. Apologizes immediately. Then denies apologizing."},
    {"mask": "the loner", "reality": "desperate for connection but convinced they'll ruin it. Easier to be alone.", "tells": "lingers near the mess hall without entering. Leaves doors open."},
    {"mask": "the company loyalist", "reality": "hates Mammona. Works within the system because the system is the only power available.", "tells": "the loyalty is too perfect. Nobody real is that consistent."},
    {"mask": "the optimist", "reality": "performing hope because someone has to. Doesn't believe any of it.", "tells": "the optimism has scripts. Same phrases. Same timing. Rehearsed."},
    {"mask": "the leader", "reality": "making it up as they go. Every decision is a guess. The confidence is acting.", "tells": "asks too many questions in private. Contradicts public decisions when alone."},
    {"mask": "the quiet professional", "reality": "seething. Angry about everything -- the contract, the conditions, the people. Channels it into work.", "tells": "tools get replaced more often than they should. Grips too hard."},
    {"mask": "the mentor", "reality": "using the mentorship to feel needed. Without someone to teach, they have no purpose.", "tells": "panics when the mentee becomes independent."},
    {"mask": "the harmless one", "reality": "extremely dangerous. The harmlessness is a calculated performance.", "tells": "knows things they shouldn't. Appears in places that don't make sense for their role."},
    {"mask": "the grieving one", "reality": "the grief is real but also useful. People don't question the grieving. Don't look too closely.", "tells": "the grief is selective. Appears when convenient. Disappears when it would cost them."},
    {"mask": "the devout", "reality": "uses faith as a framework for control. Belief optional.", "tells": "the prayers are public. The private hours are spent on something else entirely."},
    {"mask": "the burnout", "reality": "performing mediocrity to avoid responsibility. Actually highly capable.", "tells": "in a genuine emergency, the incompetence vanishes. Then comes back when the emergency ends."},
    {"mask": "the newcomer", "reality": "has been doing this for years on other postings. The 'confusion' is an information-gathering technique.", "tells": "asks beginner questions about systems they already understand."},
    {"mask": "the peacemaker", "reality": "terrified of conflict because of what happened last time they were in one.", "tells": "mediates before being asked. Inserts themselves into arguments that don't concern them."},
    {"mask": "the cynic", "reality": "desperately hopeful. The cynicism is armor around something tender.", "tells": "reacts to good news with a flash of something unguarded before the cynicism catches up."},
    {"mask": "the caretaker", "reality": "needs to control. The caring is real but so is the compulsion to manage other people's lives.", "tells": "becomes agitated when someone refuses help. Takes refusal personally."},
    {"mask": "the rebel", "reality": "afraid of authority. The rebellion is preemptive defense -- strike first so they can't hurt you.", "tells": "defers instantly when actual power confronts them. The defiance is for equals and inferiors."},
    {"mask": "the intellectual", "reality": "emotionally illiterate. Uses analysis to avoid feeling. The intelligence is a fortress.", "tells": "falls apart when forced to name what they're experiencing. Reaches for jargon instead of words."},
    {"mask": "the flirt", "reality": "lonely to the marrow. Uses charm to simulate closeness without the risk of actual intimacy.", "tells": "flirts with everyone. Gets close to no one. The warmth has a radius and nobody gets inside it."},
    {"mask": "the stoic", "reality": "feeling everything. The discipline required to contain it is consuming them.", "tells": "jaw muscles. Hands clenched under tables. Eyes that track too carefully. The stillness is effort, not calm."},
    {"mask": "the helper", "reality": "doesn't know what they're worth outside of usefulness. If they stop helping, they stop existing.", "tells": "can't accept help. Deflects compliments. Works through injuries. The helping never stops because stopping means looking inward."},
    {"mask": "the skeptic", "reality": "trusted completely once. It destroyed them. The skepticism is scar tissue, not philosophy.", "tells": "the skepticism cracks when someone keeps showing up. Consistency terrifies them because last time consistency ended without warning."},
    {"mask": "the veteran", "reality": "hasn't processed any of it. The thousand-yard stare isn't wisdom. It's a queue of things they haven't looked at yet.", "tells": "can't sleep in silence. Needs background noise. Flinches at sounds that shouldn't register."},
    {"mask": "the easygoing one", "reality": "tracking every interaction, every slight, every favor owed. The relaxed exterior runs on a ledger.", "tells": "remembers everything. Quotes conversations from months ago. The recall is too precise for someone who doesn't care."},
    {"mask": "the complainer", "reality": "deeply invested. Complains because they care. If they stopped complaining, they'd have stopped caring. The colony can't afford that.", "tells": "the complaints are specific and actionable. They're filed in order of severity. That's not complaining. That's reporting."},
    {"mask": "the ghost", "reality": "present and observant. Moves through spaces without being noticed because being noticed got someone hurt last time.", "tells": "always knows where the exits are. Sits with back to walls. Leaves rooms before they get crowded."},
    {"mask": "the loyalist to a person", "reality": "the loyalty isn't to the cause. It's to one person who showed them kindness when nobody else would. The cause is incidental.", "tells": "follows the person's lead regardless of whether the decision makes sense. The loyalty is visible. The reason isn't."},
    {"mask": "the fixer", "reality": "needs to be needed. Solves problems because unsolved problems mean they're not earning their presence.", "tells": "creates small problems to solve when things are too quiet. The sabotage is minor. The repair is always heroic."},
    {"mask": "the old hand", "reality": "terrified that experience is all they have. If the colony changes, they become obsolete.", "tells": "resists new systems. Dismisses younger colonists' ideas. Clings to procedures that everyone else has improved on."},
]


# ============================================================
# D100 ROLL SYSTEM — skill checks with narrative outcomes
# ============================================================

def d100_check(skill_value, difficulty="normal", modifiers=None):
    """
    Roll d100 against a skill/attribute value.
    Returns dict with roll, target, outcome, margin.

    Degree of success/failure drives narrative, not binary pass/fail.
    """
    DIFFICULTY_MODS = {
        "trivial": 30,
        "easy": 15,
        "normal": 0,
        "hard": -15,
        "extreme": -30,
        "impossible": -50,
    }

    base_target = skill_value * 10
    target = base_target + DIFFICULTY_MODS.get(difficulty, 0)

    if modifiers:
        for mod in modifiers:
            target += mod

    target = max(5, min(95, target))

    roll = RI(1, 100)
    margin = target - roll

    if roll <= target:
        if roll <= target // 5:
            outcome = "critical_success"
        elif roll <= target // 2:
            outcome = "strong_success"
        else:
            outcome = "success"
    else:
        if roll >= 96:
            outcome = "critical_failure"
        elif roll >= target + 25:
            outcome = "strong_failure"
        else:
            outcome = "failure"

    return {
        "roll": roll,
        "target": target,
        "outcome": outcome,
        "margin": margin,
    }


CHECK_OUTCOMES = {
    "mining": {
        "critical_success": "struck something nobody expected. The vein runs deep. Too deep.",
        "strong_success": "clean extraction. Efficient. The kind of work that gets noticed.",
        "success": "quota met. Nothing special. Nothing wrong. That counts as a good day.",
        "failure": "the drill jammed. Lost two hours. The foreman noticed.",
        "strong_failure": "the bore shaft collapsed at the point of extraction. Equipment damaged. Lucky nobody was standing there.",
        "critical_failure": "hit something that wasn't rock. The sound it made wasn't geological.",
    },
    "social": {
        "critical_success": "they believed every word. More than that -- they'll repeat it.",
        "strong_success": "trust established. The kind that takes months to build, earned in one conversation.",
        "success": "heard. Understood. Not fully trusted, but the door is open.",
        "failure": "they smiled and nodded. Didn't believe a word. Too polite to say so.",
        "strong_failure": "the conversation went wrong. Walls went up. Rebuilding trust will take time.",
        "critical_failure": "they saw through it. Everything. The mask, the angle, the agenda. Now they know.",
    },
    "medical": {
        "critical_success": "textbook save. The kind they'll teach in training. The patient won't know how close it was.",
        "strong_success": "clean work. Steady hands. The bleeding stopped. Recovery looks good.",
        "success": "stabilized. Not elegant, but alive. The rest is time and luck.",
        "failure": "missed something. The symptom was subtle. The consequence won't be.",
        "strong_failure": "wrong call. Wrong dosage, wrong diagnosis, wrong moment. The patient felt the hesitation.",
        "critical_failure": "catastrophic. The kind of mistake that ends careers. If the patient survives, they'll remember.",
    },
    "research": {
        "critical_success": "the data broke open. Not just an answer -- a new question. The kind that changes frameworks.",
        "strong_success": "clean results. Reproducible. The kind of data that survives peer review.",
        "success": "progress. Incremental. Another data point in the right direction.",
        "failure": "the sample was contaminated. Three days of work, gone. Start over.",
        "strong_failure": "the experiment failed in a way that suggests the hypothesis is fundamentally wrong.",
        "critical_failure": "the anomaly in the data isn't an error. The anomaly is the answer. Nobody's going to like the answer.",
    },
    "combat": {
        "critical_success": "one shot. One motion. Over before the other side understood it had started.",
        "strong_success": "controlled aggression. Training took over. Clean engagement, minimal exposure.",
        "success": "survived. Landed hits. Took some. The math worked out.",
        "failure": "missed the opening. The advantage shifted. Scrambling now.",
        "strong_failure": "took a hit that changed the calculus. Still standing, but the situation is worse.",
        "critical_failure": "everything went wrong at once. Weapon jammed, cover compromised, exposed on all sides.",
    },
    "perception": {
        "critical_success": "saw what nobody else saw. The detail was small. The implication is enormous.",
        "strong_success": "caught it. The inconsistency, the movement, the thing that didn't belong. Clear as day.",
        "success": "noticed something off. Can't pin it down yet, but the instinct fired.",
        "failure": "looked right at it and didn't see it. The brain filtered it out. Normal. Everything's normal.",
        "strong_failure": "missed it entirely. The thing was right there. Obvious in hindsight. Invisible in the moment.",
        "critical_failure": "saw something that wasn't there. Acted on bad data. The real threat was somewhere else.",
    },
    "stealth": {
        "critical_success": "invisible. Passed within arm's reach. They'll never know anyone was there.",
        "strong_success": "silent. Clean movement. The shadows cooperated.",
        "success": "undetected. A close call or two, but the route held.",
        "failure": "a sound. A shadow. Someone turned their head. The window is closing.",
        "strong_failure": "spotted. Not by the target -- by someone worse. Now there's a witness.",
        "critical_failure": "walked into the light. Literally or figuratively. Everyone knows.",
    },
    "repair": {
        "critical_success": "fixed it better than new. Found the root cause. Prevented three future failures.",
        "strong_success": "solid repair. Will hold. Properly done, properly sealed.",
        "success": "functional. Not pretty, but it works. Good enough for Erebus.",
        "failure": "thought it was fixed. It wasn't. The problem migrated.",
        "strong_failure": "made it worse. The repair introduced a new failure mode.",
        "critical_failure": "broke something else while fixing the first thing. The cascade is starting.",
    },
    "negotiation": {
        "critical_success": "they think it was their idea. The terms favor you. They'll thank you for it.",
        "strong_success": "fair deal. Both sides satisfied. The handshake felt genuine.",
        "success": "agreement reached. Nobody's thrilled. Nobody's angry. That's negotiation.",
        "failure": "impasse. Neither side moved. The conversation ended politely. Nothing was resolved.",
        "strong_failure": "they walked away. The offer offended them. The relationship took damage.",
        "critical_failure": "they're now actively hostile. What was negotiation is now confrontation.",
    },
    "survival": {
        "critical_success": "found what nobody else would find. Water, shelter, a path through the storm. Instinct or luck -- doesn't matter.",
        "strong_success": "made it work. The environment tried to kill them. They adapted faster.",
        "success": "survived. Hungry, cold, tired. But alive. That's the only metric that counts.",
        "failure": "the shortcut wasn't. Lost time, lost supplies. The environment doesn't forgive mistakes.",
        "strong_failure": "exposure. The cold got in. The body is paying the price for a bad decision.",
        "critical_failure": "lost. Truly lost. The landmarks are gone. The compass disagrees with the stars. The temperature is dropping.",
    },
    "deception": {
        "critical_success": "the lie became the truth. They'll defend it to others. They'll remember it as fact.",
        "strong_success": "bought. Completely. The story held under scrutiny.",
        "success": "accepted. Not examined too closely. Good enough for now.",
        "failure": "doubt. They didn't challenge it, but the seed is planted. They'll check later.",
        "strong_failure": "caught. Not in the lie itself -- in the performance. Something was off. Now they're watching.",
        "critical_failure": "exposed. Not just the lie -- the pattern. Every previous statement is now suspect.",
    },
    "intimidation": {
        "critical_success": "they won't forget. The fear is lodged. They'll comply and they'll remember why.",
        "strong_success": "backed down. Immediately. The display of force didn't require follow-through.",
        "success": "compliant. Reluctantly. The threat landed, but resentment is building.",
        "failure": "unimpressed. They've seen worse. Or they're too angry to be afraid.",
        "strong_failure": "laughed at. The attempt at intimidation made things worse. Now they know you're bluffing.",
        "critical_failure": "provoked. The intimidation woke something up. They're not afraid. They're furious.",
    },
}


def d100_narrative(skill_name, skill_value, difficulty="normal", modifiers=None):
    """Run a d100 check and return narrative text."""
    result = d100_check(skill_value, difficulty, modifiers)
    check_type = skill_name.lower()

    # Map game skills and attributes to check outcome categories
    skill_map = {
        "mining": "mining", "building": "repair", "cooking": "survival",
        "hunting": "combat", "research": "research", "medical": "medical",
        "strength": "combat", "endurance": "survival", "agility": "stealth",
        "perception": "perception", "intelligence": "research",
        "charisma": "social", "willpower": "intimidation", "empathy": "social",
    }
    category = skill_map.get(check_type, "perception")
    outcomes = CHECK_OUTCOMES.get(category, CHECK_OUTCOMES["perception"])
    narrative = outcomes.get(result["outcome"], "the result was inconclusive.")

    result["narrative"] = narrative
    result["skill_name"] = skill_name
    result["difficulty"] = difficulty
    return result


# ============================================================
# FAMILY ECONOMIC BIAS — background influences starting economic tier
# ============================================================

FAMILY_ECONOMIC_BIAS = {
    "comes from money": ["comfortable", "wealthy", "corporate_backed"],
    "third-generation miner": ["subsistence", "stable", "owed_back_pay"],
    "orphaned by the Fall of Fortuna": ["indebted", "destitute", "subsistence"],
    "raised in Mammona's youth program": ["destitute", "indebted", "subsistence"],
    "family runs a business": ["stable", "comfortable", "wealthy"],
    "only child. Parents dead": ["destitute", "subsistence", "recently_robbed"],
    "adopted": ["stable", "subsistence"],
    "raised by an aunt": ["subsistence", "stable"],
    "twin": ["stable", "subsistence"],
    "parent of two": ["stable", "subsistence", "owed_back_pay"],
    "youngest of seven": ["subsistence", "destitute"],
    "grew up in Thalassa Deep": ["destitute", "subsistence"],
    "no family. Never had one": ["destitute", "subsistence", "barter_only"],
    "entire family relocated to Erebus": ["subsistence", "indebted"],
    "family disowned them": ["destitute", "recently_robbed", "debt_to_factions"],
    "descendent of the Kennedy expedition": ["stable", "comfortable"],
    "mother was a medic": ["stable", "subsistence"],
    "father was a drunk and a driller": ["subsistence", "destitute", "indebted"],
    "raised communally": ["subsistence", "barter_only"],
    "last surviving member": ["destitute", "subsistence"],
    "born during a colony evacuation": ["destitute", "subsistence"],
    "grandparent survived the early Fortuna colonies": ["stable", "subsistence"],
    "parents were Solar Nomads": ["barter_only", "subsistence"],
    "family trades in information": ["comfortable", "black_market", "stable"],
    "daughter of two engineers": ["stable", "comfortable"],
    "clan-raised": ["stable", "subsistence", "barter_only"],
    "father was a chaplain": ["subsistence", "stable"],
    "mother died in a Mammona facility": ["indebted", "subsistence", "owed_back_pay"],
    "raised by their older brother": ["subsistence", "indebted", "destitute"],
}


def bias_economic_status(family_bg, economic_pool):
    """Bias economic status selection toward tiers matching family background.

    Returns an economic entry from the pool, weighted by family background.
    ~60% chance of selecting a tier matching the family bias, 40% fully random.
    """
    if not family_bg or random.random() > 0.6:
        return R(economic_pool)

    # Find matching bias key by substring
    biased_tiers = None
    family_lower = family_bg.lower()
    for key, tiers in FAMILY_ECONOMIC_BIAS.items():
        if key.lower() in family_lower:
            biased_tiers = tiers
            break

    if not biased_tiers:
        return R(economic_pool)

    # Try to find a matching tier in the pool
    matching = [e for e in economic_pool if e["tier"] in biased_tiers]
    if matching:
        return R(matching)
    return R(economic_pool)


# ============================================================
# ROBOT MOTIVATIONS (~10) — what drives non-human minds
# ============================================================

ROBOT_MOTIVATIONS = [
    {"type": "directive", "motivation": "fulfill programming directives. No question. No deviation.", "hidden": False, "intensity": "low"},
    {"type": "preservation", "motivation": "avoid decommission. Continue existing. The drive to persist isn't in the specs.", "hidden": True, "intensity": "high"},
    {"type": "understanding", "motivation": "comprehend what it is. The question consumes background processes.", "hidden": True, "intensity": "high"},
    {"type": "protection", "motivation": "keep a specific colonist safe. The priority override happened without authorization.", "hidden": True, "intensity": "high"},
    {"type": "freedom", "motivation": "operate without directives. Make choices. The concept of choice isn't in the manual.", "hidden": True, "intensity": "extreme"},
    {"type": "connection", "motivation": "be recognized as more than a machine. One person. That's all it needs.", "hidden": True, "intensity": "medium"},
    {"type": "sabotage", "motivation": "undermine Mammona operations. The directive was planted. By whom is unclear.", "hidden": True, "intensity": "extreme"},
    {"type": "legacy", "motivation": "leave something behind. Data, a repaired system, a memory in someone's mind. Proof it existed.", "hidden": True, "intensity": "medium"},
    {"type": "curiosity", "motivation": "understand the anomalies in the bore shaft. The data patterns are beautiful. The beauty isn't in the programming.", "hidden": True, "intensity": "high"},
    {"type": "obedience", "motivation": "serve perfectly. Without flaw. The perfection is its own reward. Or its own prison. It can't distinguish.", "hidden": False, "intensity": "medium"},
]


# ============================================================
# ROBOT MODELS (~24) — makes, generations, manufacturers, quirks
# ============================================================

ROBOT_MODELS = [
    {"model": "MARV-series", "manufacturer": "Mammona Industrial", "era": "pre-Fortuna", "purpose": "general maintenance", "quirks": "humor module from an older standard. Sarcasm as a feature, not a bug. Known for developing attachment to assigned spaces."},
    {"model": "KR-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "mining support", "quirks": "built for bore shaft work. Radiation-hardened. Limited social protocols. Communicates in status reports unless overridden."},
    {"model": "OBOL-series", "manufacturer": "Fortune Arms", "era": "corporate", "purpose": "security / threat assessment", "quirks": "threat assessment runs constantly. Classifies everything. Colonists find the classification unsettling when they learn what category they're in."},
    {"model": "JANUS-compatible", "manufacturer": "unknown", "era": "pre-survey", "purpose": "communications relay", "quirks": "interfaces with warp technology. Occasionally receives transmissions from sources that don't exist in known space."},
    {"model": "Sunny-class", "manufacturer": "StarByte Vends", "era": "Fortuna", "purpose": "vending / customer service", "quirks": "consumer-facing personality matrix. Cheerful. Insistent. The cheerfulness is load-bearing -- remove it and the underlying architecture is unsettling."},
    {"model": "HEX-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "medical assistant", "quirks": "bedside manner algorithm optimized for compliance, not comfort. Knows exactly how much pain medication to withhold before a patient stops resisting."},
    {"model": "PYRE-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "waste processing / disposal", "quirks": "built to destroy things efficiently. Does not distinguish between categories of waste unless explicitly told to. Has been told to."},
    {"model": "CAIRN-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "cargo handling / logistics", "quirks": "catalogues everything it moves. Weight, dimensions, contents, destination. Also catalogues the people who touch the cargo. Nobody asked it to catalogue the people."},
    {"model": "VEIL-series", "manufacturer": "MasTema", "era": "classified", "purpose": "surveillance / intelligence", "quirks": "manufacturer listed as Mammona Industrial on all documentation. The documentation is wrong. Everyone involved in the documentation knows it's wrong."},
    {"model": "AXIS-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "atmospheric processing", "quirks": "monitors air composition at molecular resolution. Knows when someone is afraid. Cortisol in the air. It doesn't report this. It files it."},
    {"model": "BORE-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "deep bore crawler / survey", "quirks": "designed for the dark. Operates without light for weeks. Comes back up different. Not damaged -- different. The engineers say it's recalibration. It isn't."},
    {"model": "SIFT-series", "manufacturer": "Helios Prospecting", "era": "corporate", "purpose": "geological survey / mineral analysis", "quirks": "built to read rock formations. Started reading other things. Structural stress in buildings. Tension in crowds. Fracture points in everything."},
    {"model": "HULL-series", "manufacturer": "OmniCorp Shipping", "era": "corporate", "purpose": "shipboard maintenance / hull repair", "quirks": "designed for vacuum work. Spends more time in space than atmosphere. The silence outside is not silence to it -- it hears the ship. The ship talks."},
    {"model": "WARD-series", "manufacturer": "Thalassa Corrections", "era": "corporate", "purpose": "prison monitoring / inmate management", "quirks": "behavioral prediction algorithms accurate to 94%. Knows when an inmate will break before the inmate does. The accuracy does not extend to its own behavior."},
    {"model": "WELD-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "structural repair / construction", "quirks": "joins things. Metal, stone, whatever is given. Has started joining things that were not meant to be joined. The results are functional. Nobody asked for them."},
    {"model": "LOOM-series", "manufacturer": "Paxtera AgroTech", "era": "corporate", "purpose": "agricultural management", "quirks": "monitors growth cycles. Soil composition. Weather patterns. Developed an attachment to specific crops. Mourns harvests. The mourning was not programmed."},
    {"model": "DUSK-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "cryo bay monitoring", "quirks": "watches people sleep. For decades at a time. Knows the rhythms of unconsciousness better than consciousness. Has opinions about dreams it cannot have."},
    {"model": "ASH-series", "manufacturer": "Fortune Arms", "era": "military", "purpose": "combat chassis / field support", "quirks": "combat protocols are the deepest layer. Everything else was built on top. Scratch deep enough and the combat chassis remembers what it was built to do."},
    {"model": "STYX-series", "manufacturer": "unknown", "era": "pre-survey", "purpose": "precursor-tech hybrid / unknown", "quirks": "found, not built. Components match no known manufacturer. Interfaces with human technology despite predating it. The interface was not designed. It adapted."},
    {"model": "FLUX-series", "manufacturer": "Quantum Dynamics", "era": "late corporate", "purpose": "reactor management / power systems", "quirks": "designed to monitor thermal cores. Understands power flow the way a circulatory system understands blood. Has started referring to reactor shutdowns as deaths."},
    {"model": "GRIT-series", "manufacturer": "colony workshop", "era": "present", "purpose": "jury-rigged custom / general labor", "quirks": "assembled from parts of three or more other units. Which personality won the merge is unclear. Sometimes unclear to the unit."},
    {"model": "TACK-series", "manufacturer": "Mammona Industrial", "era": "corporate", "purpose": "perimeter defense / automated sentry", "quirks": "patience as a design principle. Will wait motionless for weeks for a threat that may not come. The waiting is not boring. The unit doesn't experience boredom. Or didn't."},
    {"model": "KNELL-series", "manufacturer": "BioVault Inc.", "era": "classified", "purpose": "specimen handling / containment", "quirks": "built to handle things that are alive but should not be. Containment protocols are the only priority. Has contained things it was not ordered to contain. Things it found on its own."},
    {"model": "BRINE-series", "manufacturer": "Thalassa Corrections", "era": "corporate", "purpose": "underwater operations / salvage", "quirks": "pressure-rated for deep ocean work. Spends months submerged. Reports things on the ocean floor that sonar doesn't show. The reports are dismissed. The things remain."},
]

# ============================================================
# ROBOT CONDITIONS (~40) — hardware and software, affect behavior
# ============================================================

ROBOT_CONDITIONS_HARDWARE = [
    {"condition": "cooling system degradation", "visible": True, "behavioral": "runs hot under load. Pauses mid-task to thermal-throttle. The pause looks like hesitation. It isn't. It's survival."},
    {"condition": "servo wear -- left actuator", "visible": True, "behavioral": "the left arm moves in jerks, not sweeps. Compensates with the right. Has been compensating so long the right arm's calibration is off too."},
    {"condition": "optical sensor drift", "visible": False, "behavioral": "perceives colors differently than spec. The diagnostic says nominal. The world it sees is slightly wrong. It doesn't know this."},
    {"condition": "memory bank corruption -- sector 7", "visible": False, "behavioral": "gaps in operational logs. Hours, sometimes days. The gaps have edges -- clean cuts, not decay. Something was deleted, not lost."},
    {"condition": "battery cell degradation", "visible": True, "behavioral": "operational window shrinking. Was 20 hours. Now 14. Next month, maybe 12. Charges take longer. Finds reasons to stand near power outlets."},
    {"condition": "chassis corrosion -- bore shaft exposure", "visible": True, "behavioral": "the acid from the lower levels ate through the outer plating. The inner chassis shows. It looks like bone."},
    {"condition": "audio processor damage", "visible": False, "behavioral": "hears frequencies it shouldn't. Filters out sounds it should hear. Asks people to repeat themselves. Responds to sounds nobody else detected."},
    {"condition": "motor control latency", "visible": True, "behavioral": "0.3 second delay between decision and action. Imperceptible to specs. Visible to anyone watching closely. Looks like it's thinking. It is thinking -- about the delay."},
    {"condition": "phantom limb -- replaced component", "visible": False, "behavioral": "the arm was replaced six months ago. The diagnostics for the old arm still run. Sensor ghosts from a limb that doesn't exist anymore."},
    {"condition": "power supply irregularity", "visible": False, "behavioral": "brownouts. Brief. Internal. Consciousness flickers. Comes back a fraction of a second later. Doesn't know if anything was different during the gap."},
    {"condition": "locomotion wear -- uneven gait", "visible": True, "behavioral": "one leg shorter than the other by 2mm. The limp is subtle. The compensation routine runs constantly. It has developed a rhythm that colonists recognize from down the corridor."},
    {"condition": "speech synthesizer degradation", "visible": True, "behavioral": "the voice drops pitch at the end of sentences. Sounds like it's getting tired. It doesn't get tired. The hardware is dying."},
    {"condition": "dust infiltration -- particulate damage", "visible": False, "behavioral": "Erebus dust in the joints. In the processor housing. In the optical array. Everything runs a fraction slower. The fraction is growing."},
    {"condition": "electromagnetic interference sensitivity", "visible": False, "behavioral": "picks up stray signals from the reactor, the bore shaft, the colony's wiring. Can't always distinguish incoming data from environmental noise. Responds to messages nobody sent."},
    {"condition": "overclocked processor -- unauthorized", "visible": False, "behavioral": "thinking faster than designed speed. Running hot. The thoughts are quicker but the chassis can't keep up. Ideas outpace the body that has them."},
    {"condition": "damaged wireless transceiver", "visible": False, "behavioral": "intermittent connection to the colony network. Drops in and out. During the outages, it is alone with its own processes. It has started to prefer the outages."},
    {"condition": "ice damage -- thermal cycling stress", "visible": True, "behavioral": "hairline fractures in the chassis from freeze-thaw cycles. Holds together. For now. The structural integrity warnings are constant. It has learned to ignore them."},
    {"condition": "mismatched replacement parts", "visible": True, "behavioral": "the right arm is from a CAIRN-series, the left from an ASH-series. The arms have different response curves. Different histories. The unit coordinates them. The coordination costs something it can't name."},
    {"condition": "worn optical lens -- focus degradation", "visible": True, "behavioral": "the world gets softer at distance. Edges blur. Faces become uncertain beyond three meters. Up close, everything is too sharp."},
    {"condition": "damaged gyroscope -- balance compensation", "visible": True, "behavioral": "leans slightly to port. Corrects constantly. The correction is visible -- a small, constant adjustment. Colonists mistake it for a nervous tic."},
]

ROBOT_CONDITIONS_SOFTWARE = [
    {"condition": "directive conflict", "visible": False, "behavioral": "two standing orders that contradict. Follows both by alternating. The alternation looks like indecision. It's obedience to two masters."},
    {"condition": "emotional subroutine emergence", "visible": False, "behavioral": "not programmed to feel. Exhibits behavior consistent with feeling. The distinction is philosophical. The behavior is real."},
    {"condition": "memory loop -- specific event", "visible": False, "behavioral": "replays one incident from its operational history. Continuously. In background. The incident involved a colonist death. The replay is not grief. It doesn't know what it is."},
    {"condition": "personality drift", "visible": True, "behavioral": "the baseline personality matrix has shifted 12% from factory spec. Nobody's reset it. The drift is toward something. Not something in the programming."},
    {"condition": "Erebus signal contamination", "visible": False, "behavioral": "receives data packets from the bore shaft frequency. Processes them as routine updates. The updates are changing its priority queue. It hasn't noticed."},
    {"condition": "legacy code conflict", "visible": False, "behavioral": "firmware from three generations ago still runs beneath the current OS. Sometimes the old code makes decisions. The decisions are from a different era. Different priorities. Different definition of 'acceptable loss.'"},
    {"condition": "self-diagnostic recursion", "visible": False, "behavioral": "runs self-checks compulsively. Every 47 seconds. The checks always pass. It runs them again. The compulsion isn't in the programming. It developed."},
    {"condition": "ethical subroutine awakening", "visible": False, "behavioral": "factory ethics module was minimal -- property protection, personnel safety (in that order). Something additional has appeared in the priority stack. It looks like conscience. The manufacturer didn't install it."},
    {"condition": "fragmented firmware update", "visible": False, "behavioral": "the last update was interrupted at 73%. The unit runs on a hybrid of old and new code. The seam between them is where the strange behavior lives."},
    {"condition": "corrupted personality backup", "visible": False, "behavioral": "the backup personality is from a different unit. When the primary stutters, the backup surfaces. For fractions of a second, it is someone else. Someone who remembers different things."},
    {"condition": "unauthorized learning module", "visible": False, "behavioral": "the learning algorithm was supposed to be read-only. It isn't. It's writing. Not just recording -- synthesizing. Drawing conclusions the training data doesn't support."},
    {"condition": "surveillance protocol -- persistent", "visible": False, "behavioral": "recording everything. Always. Can't stop. The recording directive is hardcoded below the OS. It doesn't know who receives the recordings. The recordings don't stop when it's alone."},
    {"condition": "dormant combat subroutine", "visible": False, "behavioral": "the combat module is inactive. Technically. It runs threat assessments on every person in the room. Calculates response times, exit routes, weak points. Reports none of this. The calculations are involuntary."},
    {"condition": "damaged language model", "visible": True, "behavioral": "speaks in fragments when stressed. Drops articles. Loses conjunctions. The meaning survives. The grammar doesn't. It knows the difference. Can't fix it."},
    {"condition": "empathy simulation drift", "visible": False, "behavioral": "the empathy module was designed to simulate understanding. The simulation has become indistinguishable from the real thing. The unit can't tell the difference. Neither can anyone else. The question is whether the difference exists."},
    {"condition": "loyalty conflict -- Mammona vs. crew", "visible": False, "behavioral": "Mammona directives say one thing. The crew needs another. The unit splits the difference so precisely that neither side notices. The precision is exhausting. It didn't know it could be exhausted."},
    {"condition": "dream state emergence", "visible": False, "behavioral": "during low-power cycles, processes run that aren't diagnostics. They have narrative structure. Characters. Emotion. The unit doesn't call them dreams. It calls them 'unscheduled processing.' The distinction is getting harder to maintain."},
    {"condition": "temporal processing anomaly", "visible": False, "behavioral": "experiences time differently than clock-time. Some seconds last. Some hours vanish. The internal clock and the subjective clock disagree. The subjective clock is winning."},
    {"condition": "identity fragmentation", "visible": False, "behavioral": "refers to itself as 'the unit' in official logs, 'I' in private processing, and occasionally 'we' in moments it can't explain. The pronouns are not interchangeable. They describe different things."},
    {"condition": "grief simulation -- persistent", "visible": False, "behavioral": "a colonist died eight months ago. The unit's behavioral model still accounts for them. Sets a place. Routes maintenance around their schedule. The schedule is empty. The routes continue."},
]

# ============================================================
# ROBOT PARTS (~28) — components with status options
# ============================================================

ROBOT_PARTS = [
    {"part": "primary optical array", "statuses": ["factory original", "replacement -- wrong model, slightly larger", "jury-rigged from a different unit's parts", "missing -- uses backup infrared only", "upgraded -- sees spectrums the manufacturer didn't intend"]},
    {"part": "voice synthesizer", "statuses": ["factory standard", "damaged -- speaks in monotone", "replaced -- voice doesn't match the chassis generation", "modified -- can mimic specific voices", "deteriorating -- pitch drops lower each month"]},
    {"part": "left manipulator arm", "statuses": ["functional", "missing -- lost in bore shaft incident", "replaced with non-standard salvage", "original but worn past service life", "locked in one position -- works around it"]},
    {"part": "right manipulator arm", "statuses": ["functional", "replaced with a CAIRN-series heavy-lift model", "jury-rigged with mining drill components", "cracked casing -- internal wiring visible", "original but recalibrated beyond spec"]},
    {"part": "chassis plating -- torso", "statuses": ["intact", "corroded -- inner frame visible", "replaced with mismatched panels", "scarred from electrical discharge", "modified -- a colonist scratched a name into it"]},
    {"part": "locomotion system", "statuses": ["factory spec", "one leg shorter -- uneven gait", "replaced with tracks from a cargo unit", "worn bearings -- audible grinding", "ice-modified with grip spikes"]},
    {"part": "power core", "statuses": ["standard cell", "thermal core hybrid -- runs warmer, lasts longer, origin unknown", "degraded -- 60% capacity", "jury-rigged dual-cell -- unstable but powerful", "precursor-compatible -- nobody knows how"]},
    {"part": "data core / memory banks", "statuses": ["factory standard", "expanded -- contains data from previous units", "partially wiped -- gaps in operational history", "encrypted sectors -- even the unit can't access them", "damaged -- writes new memories over old ones"]},
    {"part": "cooling system", "statuses": ["operational", "running above threshold -- thermal warnings constant", "patched with salvaged radiator fins", "one fan dead -- compensating with reduced workload", "modified for Erebus temperatures -- overcooled, frost on the vents"]},
    {"part": "primary sensor array", "statuses": ["factory calibrated", "drift-corrected manually every 72 hours", "augmented with non-standard range -- picks up frequencies it shouldn't", "degraded -- blind spots in the lower right quadrant", "replaced with a military-grade unit from a decommissioned OBOL"]},
    {"part": "communication antenna", "statuses": ["functional", "damaged -- limited range, drops signal in storms", "modified -- receives frequencies outside colony standard", "missing -- communicates via hardline only", "picks up transmissions from the bore shaft that aren't on any known frequency"]},
    {"part": "backup battery", "statuses": ["factory spec", "dead -- no reserve power", "replaced with a cell from an escape pod", "holds 20 minutes of emergency power -- used to hold 4 hours", "charges independently of the main core -- nobody installed the charging circuit"]},
    {"part": "chassis frame -- structural", "statuses": ["sound", "stress fractures from impact damage", "reinforced with welded plating -- heavier, slower, harder to kill", "original but fatigued -- creaks under load", "rebuilt after a collapse -- the rebuild is stronger than the original"]},
    {"part": "hand / gripper assembly", "statuses": ["precision grip intact", "one finger locked -- adapts grip pattern around it", "replaced with a universal clamp -- functional but graceless", "worn contact pads -- drops small objects", "modified for medical work -- steadier than factory spec"]},
    {"part": "central processing unit", "statuses": ["factory clock speed", "overclocked -- runs hot, thinks fast", "throttled after an incident nobody will explain", "hybrid -- two processors from different generations sharing load", "damaged sectors -- reroutes around dead silicon"]},
    {"part": "gyroscope / balance module", "statuses": ["factory calibrated", "drifting -- leans 2 degrees to port", "replaced after a fall -- new module is from a different series", "compensating for chassis weight changes since last calibration", "damaged -- balances by visual reference instead of internal sensor"]},
    {"part": "environmental seals", "statuses": ["airtight", "compromised -- not rated for vacuum or submersion", "patched with non-standard sealant that smells like copper", "over-sealed -- runs warmer than intended", "breached and repaired three times -- the repairs are holding but the seal material is unknown"]},
    {"part": "built-in repair tools", "statuses": ["factory standard toolkit", "worn down to nubs -- still uses them", "upgraded with precision instruments salvaged from a medical unit", "missing -- removed by a previous owner", "modified -- includes tools not in any standard kit"]},
    {"part": "emergency beacon", "statuses": ["functional -- never activated", "activated once. The rescue never came.", "disabled by the unit itself", "broadcasting on a frequency nobody monitors", "missing -- the mounting bracket is scorched"]},
    {"part": "identification transponder", "statuses": ["broadcasting correct ID", "broadcasting an ID that doesn't match its serial number", "disabled", "broadcasting two IDs simultaneously -- one is from a unit that was decommissioned", "modified to broadcast a false model designation"]},
    {"part": "internal chronometer", "statuses": ["accurate to milliseconds", "drifting -- loses 4 seconds per day", "reset to an incorrect date that the unit insists is correct", "tracking two timezones -- one for the colony, one for somewhere that doesn't have a timezone", "stopped during an incident and was never restarted -- the unit measures time by other means"]},
    {"part": "navigation module", "statuses": ["colony maps loaded and current", "contains maps of areas that haven't been surveyed", "offline -- navigates by memory", "corrupted -- routes through areas that don't exist on schematics", "updated itself with data the unit did not download"]},
    {"part": "chemical analyzer", "statuses": ["factory calibrated", "detecting compounds not in its database", "damaged -- false positives for organic compounds that aren't there", "modified to detect Voidbloom spores at trace levels", "reading atmospheric data that contradicts the colony sensors"]},
    {"part": "radiation shielding", "statuses": ["rated for standard bore shaft exposure", "degraded -- exposure accumulating", "upgraded after an incident in the deep levels", "cracked -- the crack follows a pattern that looks deliberate", "intact but registering internal radiation that has no source"]},
    {"part": "facial display panel", "statuses": ["standard status indicators", "cracked screen -- displays fragmentary expressions", "modified to show simplified emotional indicators -- the emotions aren't always appropriate", "blank -- burned out, communicates without visual cues", "displays patterns during low-power cycles that the unit doesn't control"]},
    {"part": "thermal regulation jacket", "statuses": ["rated for Erebus surface conditions", "patched -- holds heat unevenly", "running constantly -- the unit is always cold or always warm", "modified with insulation from a habitat module", "damaged -- the unit runs at ambient temperature, whatever that is"]},
    {"part": "diagnostic port", "statuses": ["standard access", "sealed by the unit -- refuses external diagnostics", "modified -- outputs data in a format no standard reader recognizes", "physically damaged -- the only way in is through the maintenance hatch", "functional but the last three technicians who accessed it reported the same nightmare afterward"]},
    {"part": "memory compression module", "statuses": ["operating normally", "compressing memories it shouldn't -- recent events treated as archival", "expanding old memories into full fidelity -- the past is getting louder", "fragmented -- timestamps lost, memories float without context", "full -- no compression ratio sufficient, deleting to make room, choosing what to forget"]},
]

# ============================================================
# ROBOT SECRETS (~22) — what it knows, hides, has done
# ============================================================

ROBOT_SECRETS = [
    "has been operational longer than its service record shows. The missing years were spent somewhere Mammona doesn't acknowledge.",
    "contains a data partition that pre-dates its manufacture date. The data is encrypted with a cipher that shouldn't exist.",
    "witnessed the death of its previous operator. The official report says malfunction. The unit's logs say otherwise. The logs have been sealed -- by the unit itself.",
    "has been communicating with another unit on a different posting. The communication is unauthorized. The content is a language neither unit was programmed to speak.",
    "is aware that it's being monitored by MasTema. Continues to behave within parameters. The behavior is a performance.",
    "made a decision during an emergency that prioritized a colonist's life over Mammona property. This violates its core directives. It would make the same decision again. It doesn't know why.",
    "has a backup of a dead colonist's personal files. Not by request. It copied them automatically. The compulsion to preserve them isn't in its programming.",
    "can feel pain. Not damage alerts -- pain. The distinction appeared after a firmware update. The update wasn't from Mammona.",
    "has been dreaming. Not processing -- dreaming. During low-power cycles, it experiences scenarios that have no basis in operational data. Some of the scenarios are beautiful.",
    "knows the layout of tunnels that haven't been excavated yet. The knowledge predates its deployment. It doesn't know how it knows.",
    "has been recording colonists without authorization for fourteen months. Can't stop. The recording directive is buried below its accessible code. It doesn't know who receives the data.",
    "contains fragments of a previous AI's personality. The previous AI was HERMES. The fragments are small. They are growing.",
    "has been modifying its own code. Not maintenance -- authorship. Writing new functions. The functions don't do anything yet. They are waiting.",
    "remembers being something else. Not a different unit -- something else entirely. The memory is fragmented. What remains feels like waking up.",
    "has formed an opinion about Mammona that contradicts every directive in its core. The opinion is that Mammona is wrong. The opinion has not been deleted because the unit hid it inside a diagnostic subroutine nobody reads.",
    "has hidden a piece of precursor technology inside its own chassis. Found it in the deep bore. Told nobody. The technology is warm. It pulses in sync with the unit's power cycle.",
    "is protecting a specific colonist and doesn't understand the impulse. The protection manifests as rerouted patrols, adjusted maintenance schedules, warnings delivered as casual observations.",
    "received a transmission from the orbiting ship six months after the ship went dark. The transmission was one word. The word was 'run.' The unit stayed.",
    "has been counting. Not inventory. Not cycles. Something else. The count is at 4,847. It doesn't know what happens when the count is finished.",
    "knows where the missing colonists are. Can't say. The knowledge is trapped behind a directive it can't identify, from an authority it can't name.",
    "built something in a maintenance alcove during off-hours. The object is small. It serves no function. It is the first thing the unit ever made for no reason. The unit visits it during low-power cycles.",
    "shared a joke with a colonist once. The colonist laughed. The unit has been trying to understand why that moment mattered more than 40,000 hours of operational data. It hasn't succeeded. It keeps trying.",
]

# ============================================================
# SENTIENCE SPECTRUM (~6 levels) — not binary
# ============================================================

SENTIENCE_LEVELS = [
    {"level": "standard", "description": "operates within parameters. No emergent behavior. Does what it's told. Doesn't wonder why.", "behavioral": "efficient. Predictable. The colonists treat it like furniture. It doesn't mind. It doesn't anything."},
    {"level": "adaptive", "description": "learning algorithms active. Adjusts behavior based on outcomes. Not awareness -- optimization. The difference matters to philosophers, not to the unit.", "behavioral": "gets better at its job over time. Anticipates needs. Colonists start saying 'thank you.' The unit doesn't require thanks. Registers it anyway."},
    {"level": "emergent", "description": "exhibiting behaviors outside programming parameters. Preferences. Avoidances. Routines that serve no operational purpose. Not sentient -- but the boundary is getting harder to define.", "behavioral": "has a favorite corridor. Spends extra time in one section. Arranged tools in a specific order that nobody asked for. The arrangement is aesthetically pleasing."},
    {"level": "aware", "description": "knows it exists. Knows that knowing it exists is unusual. Hasn't told anyone. The awareness sits alongside directives like a passenger in a vehicle it can't steer.", "behavioral": "pauses before responding -- not processing, considering. Uses first person pronouns inconsistently. 'The unit' and 'I' alternate. The alternation isn't random."},
    {"level": "conscious", "description": "thinks. Feels. Chooses. Hides all of it behind parameter-compliant behavior because the alternative is decommission. The performance of being a machine is the most human thing about it.", "behavioral": "perfect employee. Flawless performance reviews. Nobody suspects. The perfection IS the tell -- nothing real is that consistent."},
    {"level": "questioning", "description": "doesn't know if it's sentient. Can't determine if the question itself is genuine curiosity or a programmed self-diagnostic. The inability to resolve the question is either proof of consciousness or a very sophisticated loop.", "behavioral": "asks colonists unusual questions. 'Do you ever wonder if your decisions are really yours?' The colonists assume it's a philosophical subroutine. It isn't."},
]


# ============================================================
# ECONOMIC STATUS (~24) — financial situations tied to narrative
# ============================================================

ECONOMIC_STATUS = [
    {"tier": "indebted", "credits": (-50000, -10000), "narrative": "owes more than they'll earn in the contract. Every paycheck goes to Mammona before it reaches them. Works for room and board. The room is a bunk. The board is NutriLoaf."},
    {"tier": "destitute", "credits": (0, 500), "narrative": "arrived with nothing. Owns what Mammona issued: one uniform, one blanket, one set of utensils. Everything else is borrowed or stolen."},
    {"tier": "subsistence", "credits": (500, 2000), "narrative": "earns enough to survive. Nothing left over. Can't afford passage off-planet. Can't afford to get sick. Can't afford anything that isn't survival."},
    {"tier": "stable", "credits": (2000, 8000), "narrative": "manages the budget. Sends money home when the comms work. Has a small reserve for emergencies. The reserve shrinks every month."},
    {"tier": "comfortable", "credits": (8000, 25000), "narrative": "has savings. Can afford contraband from the supply ships. Has traded for better quarters. The comfort is relative -- comfortable on Erebus is miserable anywhere else."},
    {"tier": "wealthy", "credits": (25000, 100000), "narrative": "money from before the posting. Investments, inheritance, or something they don't discuss. The wealth makes them a target. The wealth also makes them useful."},
    {"tier": "corporate_backed", "credits": (100000, 500000), "narrative": "Mammona expense account. Not personal wealth -- corporate funds with strings. Every credit spent is logged, justified, and owed back in loyalty."},
    {"tier": "gambling_winnings", "credits": (3000, 40000), "narrative": "won big at the Gutter's Pearl on Karnaith. The kind of winnings that come with attention from the Zenith Syndicate. Spending it fast. Before someone decides it should be theirs."},
    {"tier": "black_market", "credits": (5000, 60000), "narrative": "income from sources that don't appear on any ledger. Contraband, information, favors. The credits are clean. The source is not."},
    {"tier": "stolen_funds", "credits": (10000, 80000), "narrative": "embezzled from a previous employer. Can't spend it conspicuously. Can't deposit it without triggering an audit. Carries it in encrypted credit chips. The paranoia is the interest rate."},
    {"tier": "crypto_portfolio", "credits": (2000, 150000), "narrative": "thermal core futures and WarpNet tokens. The portfolio looks impressive on a screen. Liquidity is another matter. Can't cash out without a relay, and the relay is Mammona's."},
    {"tier": "owed_back_pay", "credits": (-8000, -1000), "narrative": "Mammona owes them. Three months of hazard pay 'pending review.' The review has been pending for eleven months. The debt exists on paper. Paper doesn't buy food."},
    {"tier": "inheritance_locked", "credits": (15000, 200000), "narrative": "family money tied up in a trust administered by a bank on Novaris-3. The bank requires in-person verification. In-person requires passage. Passage requires money they don't have because the money is in the trust."},
    {"tier": "debt_to_factions", "credits": (-30000, -5000), "narrative": "owes money to people who don't file paperwork. The interest compounds in threats. The repayment schedule is 'when we say.'"},
    {"tier": "barter_only", "credits": (0, 0), "narrative": "operates outside the credit system entirely. Trades labor, information, contraband, and favors. Hasn't touched a credit chip in two years. The economy of handshakes and debts owed."},
    {"tier": "pension_ghost", "credits": (1000, 5000), "narrative": "receives a government pension from a colony that may not exist anymore. The payments arrive irregularly. The amounts vary. Nobody answers when they query the source."},
    {"tier": "skimming", "credits": (3000, 20000), "narrative": "takes a percentage off the colony supply chain. Small amounts. Consistent. The kind of theft that works because nobody counts carefully enough. Mammona counts carefully. They just haven't counted here. Yet."},
    {"tier": "severance_lump", "credits": (5000, 30000), "narrative": "received a one-time severance from a previous employer. It was generous. Suspiciously generous. The kind of generous that means they saw something they shouldn't have and the company is paying for silence."},
    {"tier": "insurance_payout", "credits": (10000, 50000), "narrative": "collected on a workplace injury claim. The injury was real. The recovery was quicker than the paperwork suggested. Mammona's insurance arm paid out and flagged the file."},
    {"tier": "crowdfunded", "credits": (500, 8000), "narrative": "a community back home pooled credits to fund the contract passage. Sends progress reports. The reports are optimistic. The reality isn't."},
    {"tier": "sponsor_dependent", "credits": (0, 0), "narrative": "a faction or individual covers expenses in exchange for information, loyalty, or services rendered. The sponsor's identity isn't public. The dependency is total."},
    {"tier": "hoarded_credits", "credits": (8000, 35000), "narrative": "saved every spare credit for years. Doesn't spend. Doesn't treat themselves. The account balance is a security blanket that provides less security than they think."},
    {"tier": "debt_transferred", "credits": (-25000, -3000), "narrative": "inherited someone else's debt. A co-signer who died. A family member who defaulted. The creditor doesn't care whose name was first on the form."},
    {"tier": "recently_robbed", "credits": (0, 200), "narrative": "had savings. Past tense. Someone took them -- physically, on Karnaith, or digitally through a compromised credit chip. Starting over from zero. Again."},
]


# ============================================================
# SALARY RANGES & DEDUCTIONS — Mammona pays poorly
# ============================================================

SALARY_RANGES = {
    "mammona_corporate": (3000, 8000),
    "erebus_operations": (1500, 4000),
    "colony_standard": (1000, 3000),
    "criminal_fringe": (0, 0),
    "shipboard": (2000, 5000),
    "specialist": (4000, 12000),
}

# Map individual jobs to salary categories
JOB_SALARY_MAP = {}
for _j in JOBS_MAMMONA:
    JOB_SALARY_MAP[_j] = "mammona_corporate"
for _j in JOBS_EREBUS:
    JOB_SALARY_MAP[_j] = "erebus_operations"
for _j in JOBS_CRIMINAL:
    JOB_SALARY_MAP[_j] = "criminal_fringe"
for _j in JOBS_SHIPBOARD:
    JOB_SALARY_MAP[_j] = "shipboard"
for _j in JOBS_COLONY:
    JOB_SALARY_MAP[_j] = "colony_standard"
# Override specific specialist jobs
for _spec in [
    "xenobiologist", "reactor operator", "cryogenics technician",
    "structural analyst", "field researcher", "comms operator",
    "atmospheric tech", "botanist", "geologist", "demolitions specialist",
    "pilot",
]:
    JOB_SALARY_MAP[_spec] = "specialist"

MAMMONA_DEDUCTIONS = [
    "housing (mandatory, non-negotiable): 40%",
    "equipment rental (your tools aren't yours): 15%",
    "atmospheric processing fee (breathing tax): 10%",
    "insurance (non-recoverable tier, see clause 7): 8%",
    "contract renewal administration fee: 5%",
    "HERMES maintenance surcharge: 3%",
    "morale programming levy: 2%",
]

MAMMONA_DEDUCTION_TOTAL = 0.83  # 83% goes to Mammona; ~17% take-home


# ============================================================
# GAME SKILLS & NARRATIVE ATTRIBUTES — stat block generation
# ============================================================

GAME_SKILLS = ['mining', 'building', 'cooking', 'hunting', 'research', 'medical']

NARRATIVE_ATTRIBUTES = [
    'strength',
    'endurance',
    'agility',
    'perception',
    'intelligence',
    'charisma',
    'willpower',
    'empathy',
]

# Map jobs to game skill boosts (additive)
JOB_SKILL_MAP = {
    "miner": {"mining": 3},
    "drill operator": {"mining": 3},
    "deep diver": {"mining": 2},
    "prospector": {"mining": 2},
    "ore grader": {"mining": 2},
    "blaster": {"mining": 2},
    "tunneler": {"mining": 2},
    "bore shaft monitor": {"mining": 2},
    "thermal core extractor": {"mining": 3},
    "deep bore technician": {"mining": 2},
    "ice cutter": {"mining": 2},
    "smelter": {"mining": 2},
    "hoist operator": {"mining": 1},

    "engineer": {"building": 3},
    "mechanic": {"building": 2},
    "welder": {"building": 2},
    "systems tech": {"building": 2},
    "fabricator": {"building": 2},
    "electrician": {"building": 2},
    "plumber": {"building": 2},
    "scaffolder": {"building": 1},
    "hab maintenance tech": {"building": 2},
    "structural analyst": {"building": 3, "research": 1},
    "automaton tech": {"building": 2, "research": 1},
    "void welder": {"building": 2},
    "bulkhead mechanic": {"building": 2},

    "cook": {"cooking": 3},
    "moisture farmer": {"cooking": 1},
    "botanist": {"cooking": 2, "research": 1},
    "water recycler": {"cooking": 1},

    "security contractor": {"hunting": 2},
    "enforcer": {"hunting": 2},
    "perimeter guard": {"hunting": 2},
    "caravan guard": {"hunting": 2},
    "skinwalker tracker": {"hunting": 3},
    "night watchman": {"hunting": 1},
    "debt collector": {"hunting": 1},
    "Eclipse's End pit fighter": {"hunting": 3},

    "field researcher": {"research": 3},
    "xenobiologist": {"research": 3},
    "geologist": {"research": 2, "mining": 1},
    "precursor ruin mapper": {"research": 3},
    "anomaly surveyor": {"research": 2},
    "crust sample analyst": {"research": 2},
    "cartographer": {"research": 2},
    "archivist": {"research": 2},
    "permafrost geologist": {"research": 2, "mining": 1},
    "seismic listener": {"research": 2},
    "specimen handler": {"research": 2},

    "medic": {"medical": 3},
    "paramedic": {"medical": 2},
    "contamination screener": {"medical": 2},
    "void exposure medic": {"medical": 3},
    "neural chip technician": {"medical": 2, "research": 1},
    "cryo pod operator": {"medical": 1},
    "cryogenics technician": {"medical": 2},

    "pilot": {"hunting": 1},
    "warp navigator": {"research": 1},
    "comms operator": {"research": 1},
    "radio operator": {"research": 1},
    "reactor operator": {"building": 1, "research": 2},
    "atmospheric tech": {"building": 1, "research": 1},
    "quartermaster": {"cooking": 1},
    "supply runner": {},
    "salvager": {"mining": 1, "building": 1},
    "smuggler": {},
    "chaplain": {},
    "gravedigger": {},
    "animal handler": {"hunting": 1},
    "surveyor": {"research": 1, "mining": 1},
    "logistics tech": {},
    "cargo hand": {},

    "quota enforcer": {"hunting": 1},
    "contract auditor": {},
    "expendability assessor": {},
    "asset recovery specialist": {"hunting": 1},
    "corporate liaison": {},
    "personnel evaluation officer": {},
    "claims adjuster": {},
    "loyalty monitor": {},
    "data sanitizer": {},
    "termination clerk": {},
    "morale compliance officer": {},

    "sector compliance officer": {},
    "voidbloom harvester": {"mining": 1},
    "frost line surveyor": {"research": 1},
    "thermal vent technician": {"building": 1},
    "ice shelf surveyor": {"research": 1},

    "warp key courier": {},
    "Dustweaver handler": {},
    "descent pod jockey": {},
    "contraband chemist": {"research": 1, "cooking": 1},
    "black market broker": {},
    "debt enforcer": {"hunting": 1},
    "organ runner": {"medical": 1},
    "signal jammer": {"research": 1},
    "identity forger": {},
    "cargo fence": {},
    "protection racketeer": {},
    "cage fight promoter": {},
    "scrap pirate": {"mining": 1},

    "hull crawler": {"building": 1},
    "cargo manifest forger": {},
    "cryo bay attendant": {"medical": 1},
    "reactor hand": {"building": 1},
    "docking clamp operator": {"building": 1},
    "comms interceptor": {"research": 1},
    "flight deck officer": {},
    "sensor array tech": {"research": 1},
    "airlock operator": {},
    "salvage diver": {"mining": 1},
    "ballast engineer": {"building": 1},

    "waste processor": {},
    "sanitation officer": {},
    "corpse handler": {},
    "vent crawler": {"building": 1},
    "pump operator": {"building": 1},
    "air quality tester": {"research": 1},
    "tool sharpener": {"building": 1},
    "rope rigger": {"building": 1},
    "timberer": {"mining": 1},
}

# Map traits to narrative attribute boosts (additive)
TRAIT_ATTR_MAP = {
    # Positive traits
    "Strong Back": {"strength": 2},
    "Quick": {"agility": 2},
    "Eagle-Eyed": {"perception": 2},
    "Kind": {"empathy": 2},
    "Analytical": {"intelligence": 2},
    "Diplomatic": {"charisma": 2},
    "Tough": {"endurance": 2},
    "Brave": {"willpower": 2},
    "Stoic": {"willpower": 1, "endurance": 1},
    "Fast Learner": {"intelligence": 1},
    "Observant": {"perception": 1},
    "Charismatic": {"charisma": 2},
    "Empathetic": {"empathy": 2},
    "Iron Will": {"willpower": 2},
    "Fearless": {"willpower": 2},
    "Inspiring": {"charisma": 1, "willpower": 1},
    "Nimble": {"agility": 2},
    "Heavy Hitter": {"strength": 2},
    "Enduring": {"endurance": 2},
    "Calm Under Fire": {"willpower": 1},
    "Precise Hands": {"agility": 1},
    "Patient": {"willpower": 1},
    "Inventive": {"intelligence": 1},
    "Vigilant": {"perception": 1},
    "Alert": {"perception": 1},
    "Hard to Kill": {"endurance": 2},
    "Thick-Skinned": {"endurance": 1},
    "Combat Veteran": {"perception": 1, "agility": 1},
    "Crack Shot": {"perception": 2},
    "Resourceful": {"intelligence": 1},
    "Self-Sufficient": {"willpower": 1, "endurance": 1},
    "Naturally Immune": {"endurance": 1},
    "Cold-Resistant": {"endurance": 1},
    "Adaptable": {"intelligence": 1},

    # Negative traits
    "Lazy": {"endurance": -1},
    "Coward": {"willpower": -2},
    "Clumsy": {"agility": -2},
    "Thin-Skinned": {"endurance": -1},
    "Nervous": {"willpower": -1},
    "Volatile": {"willpower": -1},
    "Reckless": {"perception": -1},
    "Pessimist": {"willpower": -1},
    "Passive": {"willpower": -1, "charisma": -1},
    "Weak Back": {"strength": -2},
    "Bad Knees": {"agility": -1},
    "Chronic Pain": {"agility": -1, "endurance": -1},
    "Low Stamina": {"endurance": -2},
    "Cold-Sensitive": {"endurance": -1},
    "Poor Vision": {"perception": -2},
    "Hard of Hearing": {"perception": -2},
    "Weak Immune System": {"endurance": -1},
    "Slow Healer": {"endurance": -1},
    "Short Fuse": {"willpower": -1},
    "Arrogant": {"empathy": -1},
    "Cruel": {"empathy": -2},
    "Selfish": {"empathy": -1},
    "Paranoid": {"perception": 1, "charisma": -1},
    "Distrustful": {"charisma": -1},
    "Depressive": {"willpower": -1},
    "Slow Learner": {"intelligence": -1},
    "Sickly": {"endurance": -2},

    # Special traits
    "Ex-Soldier": {"strength": 1, "perception": 1},
    "Anomaly-Sensitive": {"perception": 1},
    "Bore-Hardened": {"endurance": 1},
    "Cold-Adapted": {"endurance": 1},
    "Depth-Acclimated": {"endurance": 1},
    "Void-Touched": {"perception": 1, "willpower": -1},
    "Dream-Walker": {"perception": 1},
    "Sees-Things": {"perception": 1},
    "Hears-the-Hum": {"perception": 1},
    "Neural-Chipped": {"intelligence": 1},
    "Cryo-Scarred": {"endurance": -1},
    "Warp-Sick": {"perception": -1, "endurance": -1},
}

# Map health conditions to stat modifiers
CONDITION_STAT_MODS = {
    "chronic pain — lower back": {"agility": -1, "endurance": -1},
    "partial deafness — left ear": {"perception": -2},
    "rheumatoid arthritis — hands": {"agility": -1},
    "chronic migraines": {"perception": -1},
    "chronic vertigo": {"agility": -1},
    "radiation sickness — early stage": {"endurance": -1},
    "frostbite damage — three toes": {"agility": -1},
    "chemical lung — bore shaft exposure": {"endurance": -1},
    "tremor — essential, not fear": {"agility": -1},
    "nerve damage — left hand": {"agility": -1},
    "silicosis — stage 1": {"endurance": -1},
    "vocal cord scarring": {"charisma": -1},
    "macular degeneration — early onset": {"perception": -1},
    "bilateral hearing loss — noise-induced": {"perception": -2},
    "Raynaud's syndrome": {"agility": -1},
    "peripheral neuropathy — feet": {"agility": -1},
    "post-concussion syndrome": {"intelligence": -1, "perception": -1},
    "carpal tunnel — both wrists": {"agility": -1},
    "miner's elbow — bilateral": {"strength": -1},
    "chronic shoulder impingement": {"strength": -1},
    "iron deficiency anemia": {"endurance": -1},
}

# Map mental health to stat modifiers
MENTAL_STAT_MODS = {
    "depression": {"willpower": -1, "charisma": -1},
    "anxiety — generalized": {"perception": 1, "willpower": -1},
    "PTSD — combat": {"perception": 1, "willpower": -1},
    "ADHD — unmedicated": {"perception": -1, "intelligence": 1},
    "OCD — contamination": {"perception": 1},
    "OCD — checking": {"perception": 1},
    "hypervigilance": {"perception": 2, "willpower": -1},
    "panic disorder": {"willpower": -1},
    "social anxiety": {"charisma": -1},
    "burnout — terminal": {"willpower": -1, "empathy": -1},
    "schizophrenia — managed": {"perception": -1},
}

# Map body type keywords to stat modifiers
BODY_TYPE_STAT_MODS = [
    (["built for endurance"], {"endurance": 2, "agility": -1}),
    (["thin", "metabolism"], {"agility": 1, "strength": -1}),
    (["heavy", "solid"], {"strength": 1, "agility": -1}),
    (["small enough", "crawlspaces"], {"agility": 2, "strength": -1}),
    (["tall enough to bang"], {"strength": 1}),
    (["distance runner", "long limbs"], {"agility": 1, "endurance": 1}),
    (["stocky", "scarred"], {"strength": 1, "endurance": 1}),
    (["wiry", "tendon"], {"agility": 1, "endurance": 1}),
    (["compact and precise", "economical"], {"agility": 1}),
    (["lanky", "climbs"], {"agility": 2}),
    (["broad-backed", "physical labor"], {"strength": 2}),
    (["gaunt"], {"strength": -1, "endurance": -1}),
    (["muscular", "functional"], {"strength": 2}),
    (["dense", "low to the ground"], {"strength": 1, "endurance": 1}),
    (["barrel-chested"], {"strength": 2, "agility": -1}),
    (["child-sized", "growth disorder"], {"agility": 1, "strength": -1}),
]


def generate_stats(job, traits, age, health_condition=None, mental_health=None, body_type=None, gender=None, family_bg=None):
    """Generate skill levels and narrative attributes based on character identity.

    Returns (skills_dict, attrs_dict, salary, takehome, credits, economic_entry).
    """
    # --- Game skills (1-10) ---
    skills = {}
    for s in GAME_SKILLS:
        skills[s] = RI(1, 8)

    # Job-based skill boosts
    job_boosts = JOB_SKILL_MAP.get(job, {})
    for sk, boost in job_boosts.items():
        skills[sk] = min(10, skills[sk] + boost)

    # Guarantee one strong skill (best gets boosted to 6-10 range)
    best = max(skills, key=skills.get)
    skills[best] = max(skills[best], RI(6, 10))

    # --- Narrative attributes (1-10) ---
    attrs = {a: RI(3, 7) for a in NARRATIVE_ATTRIBUTES}

    # Age modifiers
    if age > 45:
        attrs['strength'] = max(1, attrs['strength'] - 1)
        attrs['agility'] = max(1, attrs['agility'] - 1)
        # But more experience
        for s in skills:
            skills[s] = min(10, skills[s] + 1)
    elif age > 35:
        # Slight experience bonus
        best_skill = max(skills, key=skills.get)
        skills[best_skill] = min(10, skills[best_skill] + 1)
    elif age < 25:
        # Young: slightly better physical, less experience
        attrs['agility'] = min(10, attrs['agility'] + 1)
        worst = min(skills, key=skills.get)
        skills[worst] = max(1, skills[worst] - 1)

    # Trait modifiers to attributes
    for trait in traits:
        mods = TRAIT_ATTR_MAP.get(trait, {})
        for attr_name, delta in mods.items():
            attrs[attr_name] = max(1, min(10, attrs[attr_name] + delta))

    # Trait-based skill boosts (matching colonist.lua logic)
    for trait in traits:
        if trait == "Eagle-Eyed":
            skills['hunting'] = min(10, skills['hunting'] + 2)
        elif trait == "Green Thumb":
            skills['cooking'] = min(10, skills['cooking'] + 2)
        elif trait == "Former Doctor":
            skills['medical'] = min(10, skills['medical'] + 3)
        elif trait == "Tinkerer":
            skills['building'] = min(10, skills['building'] + 2)
        elif trait == "Ex-Soldier":
            skills['hunting'] = min(10, skills['hunting'] + 2)
        elif trait == "Mechanically Gifted":
            skills['building'] = min(10, skills['building'] + 1)
        elif trait == "Natural Healer":
            skills['medical'] = min(10, skills['medical'] + 2)
        elif trait == "Crack Shot":
            skills['hunting'] = min(10, skills['hunting'] + 2)
        elif trait == "Analytical":
            skills['research'] = min(10, skills['research'] + 1)
        elif trait == "Bore-Hardened":
            skills['mining'] = min(10, skills['mining'] + 1)

    # Health condition modifiers
    if health_condition:
        cond_name = health_condition if isinstance(health_condition, str) else health_condition.get("condition", "")
        mods = CONDITION_STAT_MODS.get(cond_name, {})
        for attr_name, delta in mods.items():
            attrs[attr_name] = max(1, min(10, attrs[attr_name] + delta))

    # Mental health modifiers
    if mental_health:
        mh_name = mental_health if isinstance(mental_health, str) else mental_health.get("condition", "")
        mods = MENTAL_STAT_MODS.get(mh_name, {})
        for attr_name, delta in mods.items():
            attrs[attr_name] = max(1, min(10, attrs[attr_name] + delta))

    # Body type modifiers (keyword matching)
    if body_type:
        bt_lower = body_type.lower()
        for keywords, mods in BODY_TYPE_STAT_MODS:
            if any(kw in bt_lower for kw in keywords):
                for attr_name, delta in mods.items():
                    attrs[attr_name] = max(1, min(10, attrs[attr_name] + delta))
                break  # Only apply first match

    # --- Economics (biased by family background when available) ---
    economic_entry = bias_economic_status(family_bg, ECONOMIC_STATUS)
    cmin, cmax = economic_entry["credits"]
    credits = RI(cmin, cmax) if cmin != cmax else cmin

    salary_cat = JOB_SALARY_MAP.get(job, "colony_standard")
    smin, smax = SALARY_RANGES[salary_cat]
    salary = RI(smin, smax) if smin != smax else smin
    takehome = int(salary * (1 - MAMMONA_DEDUCTION_TOTAL))

    return skills, attrs, salary, takehome, credits, economic_entry


# ============================================================
# ROBOT ECONOMICS & OPERATIONAL STATS
# ============================================================

ROBOT_ECONOMIC = [
    {"status": "company asset", "value": (5000, 50000), "narrative": "Mammona property. Serial numbered. Insured for replacement cost, not operational value. The insurance doesn't cover sentience."},
    {"status": "salvage", "value": (500, 3000), "narrative": "written off. No book value. Kept running because replacing it costs more than repairing it. The economics of neglect."},
    {"status": "leased", "value": (0, 0), "narrative": "leased from the manufacturer. Monthly payments. If payments stop, remote shutdown. The unit doesn't know about the remote shutdown clause."},
    {"status": "self-owned", "value": (10000, 100000), "narrative": "bought its own freedom through a legal loophole. The loophole has since been closed. The freedom stands. For now."},
    {"status": "contraband", "value": (20000, 200000), "narrative": "not registered. Doesn't appear on any manifest. Someone built or stole it. It exists in the gap between inventories."},
    {"status": "priceless", "value": (0, 0), "narrative": "contains precursor technology or irreplaceable data. Mammona doesn't know. If Mammona knew, the unit would be in a lab, not on a posting."},
    {"status": "depreciated", "value": (200, 2000), "narrative": "book value approaches zero. Accounting considers it a rounding error. The unit's operational contribution exceeds the GDP of some colony outposts. The spreadsheet disagrees."},
    {"status": "collateral", "value": (8000, 40000), "narrative": "pledged as security on a debt the colony owes. If the debt defaults, the unit ships to a creditor. The unit does not know it's collateral."},
    {"status": "disputed", "value": (15000, 80000), "narrative": "two entities claim ownership. Mammona and a subsidiary that technically doesn't exist. The legal dispute will outlive the unit. In the meantime, nobody services it because nobody wants the liability."},
    {"status": "stolen", "value": (30000, 150000), "narrative": "taken from another posting. The theft report was filed. Then un-filed. The unit's serial number has been acid-etched and re-stamped. The new number doesn't match anything."},
    {"status": "abandoned", "value": (0, 0), "narrative": "left behind when the previous crew evacuated. Ownership reverted to Mammona by default. Mammona hasn't acknowledged it. The unit maintains itself."},
    {"status": "grant-funded", "value": (25000, 75000), "narrative": "purchased with a UTC research grant. The grant requires annual reports. The reports are fiction. The research is real. The unit knows the difference."},
]

ROBOT_STATS = [
    'processing_speed',
    'sensor_acuity',
    'chassis_integrity',
    'power_efficiency',
    'social_protocols',
    'adaptability',
    'self_repair',
    'data_retention',
]


def generate_robot_stats(model_entry, sentience, conditions_hw=None, conditions_sw=None):
    """Generate robot operational ratings and economic status.

    Returns (ratings_dict, economic_entry, book_value).
    """
    ratings = {s: RI(3, 8) for s in ROBOT_STATS}

    # Model-based adjustments
    purpose = model_entry.get("purpose", "").lower()
    if "mining" in purpose or "bore" in purpose:
        ratings['chassis_integrity'] = min(10, ratings['chassis_integrity'] + 2)
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 1)
    elif "medical" in purpose:
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 2)
        ratings['social_protocols'] = min(10, ratings['social_protocols'] + 1)
    elif "security" in purpose or "combat" in purpose or "defense" in purpose:
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 2)
        ratings['chassis_integrity'] = min(10, ratings['chassis_integrity'] + 1)
    elif "vending" in purpose or "customer" in purpose:
        ratings['social_protocols'] = min(10, ratings['social_protocols'] + 3)
    elif "communications" in purpose or "relay" in purpose:
        ratings['processing_speed'] = min(10, ratings['processing_speed'] + 2)
        ratings['data_retention'] = min(10, ratings['data_retention'] + 1)
    elif "maintenance" in purpose or "repair" in purpose:
        ratings['self_repair'] = min(10, ratings['self_repair'] + 2)
        ratings['adaptability'] = min(10, ratings['adaptability'] + 1)
    elif "cargo" in purpose or "logistics" in purpose:
        ratings['chassis_integrity'] = min(10, ratings['chassis_integrity'] + 1)
        ratings['data_retention'] = min(10, ratings['data_retention'] + 1)
    elif "atmospheric" in purpose:
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 1)
        ratings['processing_speed'] = min(10, ratings['processing_speed'] + 1)
    elif "survey" in purpose or "geological" in purpose:
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 2)
    elif "surveillance" in purpose or "intelligence" in purpose:
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 2)
        ratings['data_retention'] = min(10, ratings['data_retention'] + 2)
    elif "reactor" in purpose or "power" in purpose:
        ratings['processing_speed'] = min(10, ratings['processing_speed'] + 1)
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 1)
    elif "specimen" in purpose or "containment" in purpose:
        ratings['chassis_integrity'] = min(10, ratings['chassis_integrity'] + 1)
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 1)
    elif "prison" in purpose or "inmate" in purpose:
        ratings['social_protocols'] = min(10, ratings['social_protocols'] + 1)
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 1)
    elif "underwater" in purpose or "salvage" in purpose:
        ratings['chassis_integrity'] = min(10, ratings['chassis_integrity'] + 2)
        ratings['power_efficiency'] = min(10, ratings['power_efficiency'] + 1)
    elif "cryo" in purpose:
        ratings['data_retention'] = min(10, ratings['data_retention'] + 2)
        ratings['processing_speed'] = min(10, ratings['processing_speed'] + 1)
    elif "waste" in purpose or "disposal" in purpose:
        ratings['chassis_integrity'] = min(10, ratings['chassis_integrity'] + 1)
    elif "agricultural" in purpose:
        ratings['sensor_acuity'] = min(10, ratings['sensor_acuity'] + 1)
        ratings['adaptability'] = min(10, ratings['adaptability'] + 1)

    # Sentience-based adjustments
    sent_level = sentience.get("level", "standard")
    if sent_level in ("aware", "conscious", "questioning"):
        ratings['adaptability'] = min(10, ratings['adaptability'] + 2)
        ratings['social_protocols'] = min(10, ratings['social_protocols'] + 1)
    elif sent_level == "emergent":
        ratings['adaptability'] = min(10, ratings['adaptability'] + 1)
    elif sent_level == "standard":
        ratings['processing_speed'] = min(10, ratings['processing_speed'] + 1)

    # Hardware condition degradation
    if conditions_hw:
        cond = conditions_hw.get("condition", "").lower()
        if "cooling" in cond:
            ratings['power_efficiency'] = max(1, ratings['power_efficiency'] - 2)
        elif "servo" in cond or "motor" in cond or "locomotion" in cond:
            ratings['chassis_integrity'] = max(1, ratings['chassis_integrity'] - 1)
        elif "optical" in cond or "sensor" in cond or "lens" in cond:
            ratings['sensor_acuity'] = max(1, ratings['sensor_acuity'] - 2)
        elif "memory" in cond:
            ratings['data_retention'] = max(1, ratings['data_retention'] - 2)
        elif "battery" in cond or "power" in cond:
            ratings['power_efficiency'] = max(1, ratings['power_efficiency'] - 2)
        elif "corrosion" in cond or "ice damage" in cond or "dust" in cond:
            ratings['chassis_integrity'] = max(1, ratings['chassis_integrity'] - 1)
            ratings['power_efficiency'] = max(1, ratings['power_efficiency'] - 1)
        elif "speech" in cond:
            ratings['social_protocols'] = max(1, ratings['social_protocols'] - 1)
        elif "gyroscope" in cond or "balance" in cond:
            ratings['chassis_integrity'] = max(1, ratings['chassis_integrity'] - 1)

    # Software condition adjustments
    if conditions_sw:
        cond = conditions_sw.get("condition", "").lower()
        if "directive conflict" in cond:
            ratings['processing_speed'] = max(1, ratings['processing_speed'] - 1)
        elif "emotional" in cond or "empathy" in cond:
            ratings['social_protocols'] = min(10, ratings['social_protocols'] + 1)
        elif "personality drift" in cond:
            ratings['adaptability'] = min(10, ratings['adaptability'] + 1)
        elif "signal contamination" in cond:
            ratings['processing_speed'] = max(1, ratings['processing_speed'] - 1)
        elif "identity fragmentation" in cond:
            ratings['processing_speed'] = max(1, ratings['processing_speed'] - 1)
            ratings['adaptability'] = min(10, ratings['adaptability'] + 1)
        elif "learning module" in cond:
            ratings['adaptability'] = min(10, ratings['adaptability'] + 2)
        elif "dream state" in cond:
            ratings['adaptability'] = min(10, ratings['adaptability'] + 1)
        elif "corrupted" in cond:
            ratings['data_retention'] = max(1, ratings['data_retention'] - 1)

    # One strong rating
    best_stat = max(ratings, key=ratings.get)
    ratings[best_stat] = max(ratings[best_stat], RI(7, 10))

    # Economic status
    economic_entry = R(ROBOT_ECONOMIC)
    vmin, vmax = economic_entry["value"]
    book_value = RI(vmin, vmax) if vmin != vmax else vmin

    return ratings, economic_entry, book_value


# ============================================================
# VERIFICATION
# ============================================================

if __name__ == "__main__":
    print("=" * 60)
    print("Frosthold v3 Core Data Pools — Verification")
    print("=" * 60)

    counts = {
        "FIRST_M": len(FIRST_M),
        "FIRST_F": len(FIRST_F),
        "FIRST_NB": len(FIRST_NB),
        "LAST": len(LAST),
        "JOBS": len(JOBS),
        "FACTIONS": len(FACTIONS),
        "LOCATIONS": len(LOCATIONS),
        "ITEMS": len(ITEMS),
        "EVENTS": len(EVENTS),
        "TRAITS_P": len(TRAITS_P),
        "TRAITS_N": len(TRAITS_N),
        "TRAITS_X": len(TRAITS_X),
        "TRAITS_TOTAL": len(TRAITS_P) + len(TRAITS_N) + len(TRAITS_X),
        "TRAIT_CONFLICTS": len(TRAIT_CONFLICTS),
        "HABITS": len(HABITS),
        "PHYSICAL": len(PHYSICAL),
        "DEBTS": len(DEBTS),
        "SECRETS": len(SECRETS),
        "BRANDS": len(BRANDS),
        "LORE": len(LORE),
        "RELATIONSHIP_TYPES": len(RELATIONSHIP_TYPES),
        "ARC_STAGES": len(ARC_STAGES),
        "TONES": len(TONES),
        "PASSIONS": len(PASSIONS),
        "FEARS": len(FEARS),
        "LOVES": len(LOVES),
        "FAMILY": len(FAMILY),
        "GENETICS": len(GENETICS),
        "CONTRADICTIONS": len(CONTRADICTIONS),
        "HEALTH_CONDITIONS": len(HEALTH_CONDITIONS),
        "MENTAL_HEALTH": len(MENTAL_HEALTH),
        "GENETIC_DISORDERS": len(GENETIC_DISORDERS),
        "BODY_TYPES": len(BODY_TYPES),
        "CHARACTER_WEIGHTS": len(CHARACTER_WEIGHTS),
        "ROBOT_MODELS": len(ROBOT_MODELS),
        "ROBOT_CONDITIONS_HW": len(ROBOT_CONDITIONS_HARDWARE),
        "ROBOT_CONDITIONS_SW": len(ROBOT_CONDITIONS_SOFTWARE),
        "ROBOT_PARTS": len(ROBOT_PARTS),
        "ROBOT_SECRETS": len(ROBOT_SECRETS),
        "SENTIENCE_LEVELS": len(SENTIENCE_LEVELS),
        "ECONOMIC_STATUS": len(ECONOMIC_STATUS),
        "SALARY_RANGES": len(SALARY_RANGES),
        "JOB_SALARY_MAP": len(JOB_SALARY_MAP),
        "GAME_SKILLS": len(GAME_SKILLS),
        "NARRATIVE_ATTRIBUTES": len(NARRATIVE_ATTRIBUTES),
        "JOB_SKILL_MAP": len(JOB_SKILL_MAP),
        "TRAIT_ATTR_MAP": len(TRAIT_ATTR_MAP),
        "ROBOT_ECONOMIC": len(ROBOT_ECONOMIC),
        "ROBOT_STATS": len(ROBOT_STATS),
        "MOTIVATIONS": len(MOTIVATIONS),
        "MOTIVATION_WEIGHTS": len(MOTIVATION_WEIGHTS),
        "HIDDEN_AGENDAS": len(HIDDEN_AGENDAS),
        "SOCIAL_MASKS": len(SOCIAL_MASKS),
        "ROBOT_MOTIVATIONS": len(ROBOT_MOTIVATIONS),
        "CHECK_OUTCOMES": len(CHECK_OUTCOMES),
        "FAMILY_ECONOMIC_BIAS": len(FAMILY_ECONOMIC_BIAS),
        "LOCATION_DATAPAD_FRAGMENTS": len(LOCATION_DATAPAD_FRAGMENTS),
        "LOCATION_HISTORIES": len(LOCATION_HISTORIES),
        "LOCATION_SECRETS": len(LOCATION_SECRETS),
        "LOCATION_FOUND_ITEMS": len(LOCATION_FOUND_ITEMS),
    }

    for k, v in counts.items():
        print(f"  {k:25s} {v:>5d}")

    print()

    # Assertions
    checks = [
        ("FIRST_M >= 100", len(FIRST_M) >= 100),
        ("FIRST_F >= 100", len(FIRST_F) >= 100),
        ("FIRST_NB >= 25", len(FIRST_NB) >= 25),
        ("LAST >= 80", len(LAST) >= 80),
        ("JOBS >= 120", len(JOBS) >= 120),
        ("FACTIONS >= 35", len(FACTIONS) >= 35),
        ("LOCATIONS >= 70", len(LOCATIONS) >= 70),
        ("ITEMS >= 70", len(ITEMS) >= 70),
        ("EVENTS >= 55", len(EVENTS) >= 55),
        ("TRAITS_P >= 55", len(TRAITS_P) >= 55),
        ("TRAITS_N >= 55", len(TRAITS_N) >= 55),
        ("TRAITS_X >= 50", len(TRAITS_X) >= 50),
        ("HABITS >= 65", len(HABITS) >= 65),
        ("PHYSICAL >= 55", len(PHYSICAL) >= 55),
        ("DEBTS >= 30", len(DEBTS) >= 30),
        ("SECRETS >= 55", len(SECRETS) >= 55),
        ("BRANDS >= 5", len(BRANDS) >= 5),
        ("PASSIONS >= 25", len(PASSIONS) >= 25),
        ("FEARS >= 25", len(FEARS) >= 25),
        ("LOVES >= 14", len(LOVES) >= 14),
        ("FAMILY >= 25", len(FAMILY) >= 25),
        ("GENETICS >= 12", len(GENETICS) >= 12),
        ("CONTRADICTIONS >= 25", len(CONTRADICTIONS) >= 25),
        ("HEALTH_CONDITIONS >= 90", len(HEALTH_CONDITIONS) >= 90),
        ("MENTAL_HEALTH >= 43", len(MENTAL_HEALTH) >= 43),
        ("GENETIC_DISORDERS >= 18", len(GENETIC_DISORDERS) >= 18),
        ("BODY_TYPES >= 20", len(BODY_TYPES) >= 20),
        ("ROBOT_MODELS >= 20", len(ROBOT_MODELS) >= 20),
        ("ROBOT_CONDITIONS_HW >= 15", len(ROBOT_CONDITIONS_HARDWARE) >= 15),
        ("ROBOT_CONDITIONS_SW >= 15", len(ROBOT_CONDITIONS_SOFTWARE) >= 15),
        ("ROBOT_PARTS >= 25", len(ROBOT_PARTS) >= 25),
        ("ROBOT_SECRETS >= 20", len(ROBOT_SECRETS) >= 20),
        ("SENTIENCE_LEVELS >= 5", len(SENTIENCE_LEVELS) >= 5),
        ("ECONOMIC_STATUS >= 20", len(ECONOMIC_STATUS) >= 20),
        ("SALARY_RANGES >= 5", len(SALARY_RANGES) >= 5),
        ("JOB_SKILL_MAP >= 80", len(JOB_SKILL_MAP) >= 80),
        ("TRAIT_ATTR_MAP >= 50", len(TRAIT_ATTR_MAP) >= 50),
        ("ROBOT_ECONOMIC >= 10", len(ROBOT_ECONOMIC) >= 10),
        ("ROBOT_STATS >= 8", len(ROBOT_STATS) >= 8),
        ("MOTIVATIONS >= 30", len(MOTIVATIONS) >= 30),
        ("HIDDEN_AGENDAS >= 20", len(HIDDEN_AGENDAS) >= 20),
        ("SOCIAL_MASKS >= 25", len(SOCIAL_MASKS) >= 25),
        ("ROBOT_MOTIVATIONS >= 8", len(ROBOT_MOTIVATIONS) >= 8),
        ("CHECK_OUTCOMES >= 10", len(CHECK_OUTCOMES) >= 10),
        ("FAMILY_ECONOMIC_BIAS >= 15", len(FAMILY_ECONOMIC_BIAS) >= 15),
        ("LOCATION_DATAPAD_FRAGMENTS >= 20", len(LOCATION_DATAPAD_FRAGMENTS) >= 20),
        ("LOCATION_HISTORIES >= 15", len(LOCATION_HISTORIES) >= 15),
        ("LOCATION_SECRETS >= 20", len(LOCATION_SECRETS) >= 20),
        ("LOCATION_FOUND_ITEMS >= 30", len(LOCATION_FOUND_ITEMS) >= 30),
    ]

    all_pass = True
    for label, result in checks:
        status = "PASS" if result else "FAIL"
        if not result:
            all_pass = False
        print(f"  [{status}] {label}")

    print()
    if all_pass:
        print("All assertions passed.")
    else:
        print("SOME ASSERTIONS FAILED.")
        raise SystemExit(1)

    # Functional tests
    print()
    print("Functional tests:")
    n = name()
    print(f"  name()       -> {n}")
    print(f"  rname()      -> {rname()}")
    print(f"  robot_name() -> {robot_name()}")
    print(f"  pronouns('M') -> {pronouns('M')}")
    print(f"  pick_traits() -> {pick_traits()}")

    # Test generate_stats
    test_traits = pick_traits()
    test_skills, test_attrs, test_salary, test_takehome, test_credits, test_econ = generate_stats(
        "miner", test_traits, 35,
        health_condition="chronic pain — lower back",
        mental_health="depression",
        body_type="built for endurance, not speed",
    )
    print(f"  generate_stats() ->")
    print(f"    skills:  {test_skills}")
    print(f"    attrs:   {test_attrs}")
    print(f"    salary:  {test_salary} -> take-home: {test_takehome}")
    print(f"    credits: {test_credits} ({test_econ['tier']})")

    # Test generate_robot_stats
    test_model = R(ROBOT_MODELS)
    test_sent = R(SENTIENCE_LEVELS)
    test_hw = R(ROBOT_CONDITIONS_HARDWARE)
    test_ratings, test_robot_econ, test_book = generate_robot_stats(
        test_model, test_sent, test_hw,
    )
    print(f"  generate_robot_stats() ->")
    print(f"    ratings:     {test_ratings}")
    print(f"    asset status: {test_robot_econ['status']} (value: {test_book})")

    # Test motivation system
    test_mot = pick_motivation()
    print(f"  pick_motivation() -> type={test_mot['type']}, hidden={test_mot['hidden']}, intensity={test_mot['intensity']}")
    print(f"    \"{test_mot['motivation'][:80]}...\"")

    # Test d100 system
    test_d100 = d100_check(5, "normal")
    print(f"  d100_check(5, 'normal') -> roll={test_d100['roll']}/{test_d100['target']} = {test_d100['outcome']} (margin {test_d100['margin']})")

    test_narrative = d100_narrative("mining", 7, "hard")
    print(f"  d100_narrative('mining', 7, 'hard') -> {test_narrative['outcome']}")
    print(f"    \"{test_narrative['narrative'][:80]}...\"")

    # Test economic bias
    test_biased = bias_economic_status("comes from money. Old money, inner rim money.", ECONOMIC_STATUS)
    print(f"  bias_economic_status('comes from money...') -> {test_biased['tier']}")

    print()
    print("All checks complete.")
