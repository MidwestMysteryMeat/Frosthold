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
        ("HEALTH_CONDITIONS >= 35", len(HEALTH_CONDITIONS) >= 35),
        ("MENTAL_HEALTH >= 35", len(MENTAL_HEALTH) >= 35),
        ("GENETIC_DISORDERS >= 18", len(GENETIC_DISORDERS) >= 18),
        ("BODY_TYPES >= 20", len(BODY_TYPES) >= 20),
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
    print()
    print("All checks complete.")
