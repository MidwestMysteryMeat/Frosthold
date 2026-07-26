-- adlib.lua - Ad-lib text and identity generation
-- Syllable-based names, randomized bios, personality traits, event flavor text.
-- Inspired by MMOLite's rumor system and NPC generators.

local Adlib = {}

---------------------------------------------------------------------------
-- Syllable pools for procedural names
---------------------------------------------------------------------------

local SYLLABLES = {
    -- Sharp/frontier (outer rim colonists)
    sharp = {
        'voss', 'kael', 'ren', 'cade', 'jax', 'hale', 'beck', 'cole',
        'tarn', 'cross', 'dex', 'kras', 'vek', 'strom', 'roth', 'zev',
        'kel', 'bran', 'fen', 'dak', 'volt', 'griff', 'cort', 'wren',
        'thane', 'harke', 'dranth', 'ferr', 'kane', 'helm',
    },
    -- Smooth/multicultural (inner rim)
    smooth = {
        'ae', 'li', 'mi', 'ren', 'si', 'el', 'na', 'ri', 'yu',
        'lor', 'ki', 'del', 'ala', 'sa', 'isa', 'ora', 'emi', 'lu',
        'ira', 'ni', 'ani', 'ko', 'ari', 'ta',
        'cael', 'syl', 'var', 'ela', 'aron',
    },
    -- Common/neutral
    common = {
        'ar', 'el', 'or', 'in', 'an', 'al', 'en', 'ir', 'ol', 'un',
        'eth', 'ash', 'ros', 'val', 'ren', 'dor',
        'kel', 'mar', 'fen', 'gal', 'til', 'cal', 'pyr', 'tek',
    },
    -- Ancient/precursor-influenced (old colony descendants, rare)
    ancient = {
        'thal', 'xir', 'dha', 'var', 'rhy', 'dral', 'mal', 'dum',
        'pra', 'xen', 'vas', 'ril', 'eth', 'lin', 'thra', 'vael',
    },
}

-- Pre-built first names split by gender
local FIRST_NAMES_M = {
    'Marcus', 'Idris', 'Niko', 'Soren', 'Luca', 'Tomas', 'Kenji', 'Ravi',
    'Dante', 'Rowan',
    'Voss', 'Cade', 'Hale', 'Jax', 'Beck', 'Cole', 'Dag', 'Tarn', 'Dex',
    'Rook', 'Thane', 'Kael', 'Griff',
    'Caleb', 'Damian', 'Ezekiel', 'Ferris', 'Rylan', 'Cassian', 'Victor',
    'Griffin', 'Alexi', 'Tiberius',
    'Anders', 'Dennis', 'Mark', 'Hasan', 'Charles', 'Michael', 'Duke',
    'Roberto', 'Felix', 'Jimmy', 'Thomas',
    'Hiro', 'Jian', 'Haruki', 'Akira', 'Takeshi', 'Minho', 'Dae',
    'Wei', 'Bao', 'Xian', 'Zhen', 'Rui',
    'Yuri', 'Ivan', 'Dima', 'Oleg', 'Pyotr', 'Boris', 'Lev', 'Ilya',
    'Klaus', 'Fritz', 'Helmut', 'Dieter', 'Konrad', 'Rolf', 'Volker', 'Lutz',
}

local FIRST_NAMES_F = {
    'Elena', 'Yuna', 'Petra', 'Mira', 'Kira', 'Zara', 'Priya', 'Vera',
    'Amara',
    'Brynn', 'Wren', 'Sable',
    'Kaida', 'Ximena', 'Lorena', 'Tessa', 'Aria', 'Cassia',
    'Lily', 'Leslie', 'Blaire',
    'Mei', 'Yuki', 'Suki', 'Ling', 'Sakura', 'Rin', 'Naomi', 'Sora',
    'Jisoo', 'Eunji', 'Lan',
    'Katya', 'Nika', 'Tanya', 'Nadya', 'Anya', 'Sonya', 'Mila', 'Zoya',
    'Galina',
    'Greta', 'Liesel', 'Ingrid', 'Hanna', 'Elke', 'Anke', 'Brigitte', 'Renate',
}

-- Gender-neutral names (used for nb, or mixed into either pool)
local FIRST_NAMES_NB = {
    'Fen', 'Kit', 'Ash', 'Cross', 'Sonder', 'Valen', 'Isa', 'Jun', 'Hyun',
    'Sasha', 'Rin', 'Rui', 'Rowan',
}

-- Last names: real surnames + compound frontier names
local LAST_NAMES = {
    -- Real-world surnames (inner rim families)
    'Tanaka', 'Okafor', 'Petrov', 'da Silva', 'Chen', 'Reeves',
    'Kowalski', 'Ndiaye', 'Vasquez', 'Park', 'Larsen', 'Osei',
    'Brennan', 'Nakamura', 'Volkov', 'Gutierrez',
    -- Old colony surnames (Fortuna-era lineage, UTC records)
    'Yu', 'Nichols', 'Dewitt', 'Belov', 'Vance', 'Fogarty',
    'Wallace', 'Alba', 'Barton', 'Morgan', 'Flores', 'Wei',
    'Dvorak', 'Watanabe', 'Coran', 'Harker', 'Jennings', 'Kane',
    'Helden', 'DuPlessis', 'Vale', 'Venin', 'Rathmore', 'Malraux',
    'Coyle', 'Thorne', 'Marr', 'Ho', 'Morales', 'Lenford',
    -- Miscellaneous surnames (varied backgrounds)
    'Ahgren', 'Anys', 'Richardson', 'Hofstetter', 'Wang',
    'Fischbach', 'Piker', 'Fu', 'Gonzalez', 'Li',
    -- East Asian (Chinese / Korean / Japanese)
    'Zhang', 'Liu', 'Huang', 'Zhou', 'Wu', 'Zhao', 'Lin', 'Sun',
    'Kim', 'Choi', 'Han', 'Yoon', 'Kang', 'Shin', 'Bae',
    'Sato', 'Suzuki', 'Ito', 'Yamamoto', 'Kimura', 'Hayashi',
    'Mori', 'Ishida', 'Ogawa',
    -- Russian
    'Ivanov', 'Sokolov', 'Kuznetsov', 'Popov', 'Lebedev',
    'Kozlov', 'Novikov', 'Morozov', 'Fedorov', 'Zaitsev',
    'Pavlov', 'Orlov', 'Vasiliev', 'Bogdanov',
    -- German
    'Muller', 'Schmidt', 'Schneider', 'Fischer', 'Weber',
    'Braun', 'Richter', 'Becker', 'Hoffmann', 'Kruger',
    'Vogt', 'Stein', 'Engel', 'Hartmann',
    -- Compound frontier names (outer rim families)
    'Coldwell', 'Ashford', 'Steelberg', 'Deepwell', 'Driftwood',
    'Stonecut', 'Blackwell', 'Crestfall', 'Ironmere', 'Dustborn',
    'Rimgate', 'Driftcut', 'Hullbreak', 'Burnside', 'Frostwell',
}

---------------------------------------------------------------------------
-- Personality traits (affect behavior + bio text)
---------------------------------------------------------------------------

local TRAITS = {
    -- Positive (20)
    positive = {
        { id = 'hardworking',   name = 'Hardworking',   workSpeed = 0.15,   desc = 'works tirelessly' },
        { id = 'optimist',      name = 'Optimist',      moraleMod = 0.2,    desc = 'keeps spirits up' },
        { id = 'brave',         name = 'Brave',         combatMod = 0.1,    desc = 'unflinching in danger' },
        { id = 'nurturing',     name = 'Nurturing',     socialMod = 0.15,   desc = 'cares for others' },
        { id = 'resourceful',   name = 'Resourceful',   craftMod = 0.1,     desc = 'makes do with less' },
        { id = 'stoic',         name = 'Stoic',         coldResist = 0.1,   desc = 'endures without complaint' },
        { id = 'quick',         name = 'Quick',         speedMod = 0.1,     desc = 'moves fast' },
        { id = 'eagle_eye',     name = 'Eagle-Eyed',    huntMod = 0.15,     desc = 'spots prey at distance' },
        { id = 'green_thumb',   name = 'Green Thumb',   farmMod = 0.2,      desc = 'can grow anything' },
        { id = 'iron_stomach',  name = 'Iron Stomach',  foodMod = -0.15,    desc = 'eats anything' },
        { id = 'tough',         name = 'Tough',         healthMod = 0.15,   desc = 'takes a beating and keeps going' },
        { id = 'neat',          name = 'Neat',          cleanMod = 0.2,     desc = 'keeps things tidy', opinionMod = 'hates_mess' },
        { id = 'kind',          name = 'Kind',          socialMod = 0.1,    desc = 'goes out of their way for others', opinionMod = 'kind_words' },
        { id = 'steadfast',     name = 'Steadfast',     breakThreshold = -15, desc = 'hard to rattle' },
        { id = 'light_sleeper', name = 'Light Sleeper', restMod = 0.1,      desc = 'sleeps efficiently' },
        { id = 'careful',       name = 'Careful',       craftMod = 0.05,    desc = 'measures twice', qualityBonus = 1 },
        { id = 'naturally_immune', name = 'Naturally Immune', immuneMod = 0.2, desc = 'shrugs off sickness' },
        { id = 'fast_learner',  name = 'Fast Learner',  xpMod = 0.15,      desc = 'picks things up quickly' },
        { id = 'strong_back',   name = 'Strong Back',   carryMod = 0.3,    desc = 'carries heavy loads' },
        { id = 'night_fighter', name = 'Night Fighter',  combatMod = 0.08, desc = 'sees well in the dark' },
    },
    -- Negative (18)
    negative = {
        { id = 'lazy',          name = 'Lazy',          workSpeed = -0.2,   desc = 'avoids exertion' },
        { id = 'pessimist',     name = 'Pessimist',     moraleMod = -0.2,  desc = 'sees the worst' },
        { id = 'coward',        name = 'Coward',        combatMod = -0.15, desc = 'flees from danger' },
        { id = 'glutton',       name = 'Glutton',       foodMod = 0.3,     desc = 'eats more than their share' },
        { id = 'pyromaniac',    name = 'Pyromaniac',    fireMod = 0.5,     desc = 'drawn to flames' },
        { id = 'thin_skinned',  name = 'Thin-Skinned',  coldResist = -0.15, desc = 'suffers the cold' },
        { id = 'clumsy',        name = 'Clumsy',        craftMod = -0.15,  desc = 'drops things' },
        { id = 'insomniac',     name = 'Insomniac',     restMod = -0.2,    desc = 'sleeps poorly' },
        { id = 'loner',         name = 'Loner',         socialMod = -0.2,  desc = 'dislikes company', opinionMod = 'annoyed_by_people' },
        { id = 'volatile',      name = 'Volatile',      moraleMod = -0.1,  desc = 'snaps under pressure', breakThreshold = 10 },
        { id = 'came_back_wrong', name = 'Came Back Wrong', moraleMod = -0.15, workSpeed = -0.10, desc = 'not quite right since the serum' },
        { id = 'death_echo',    name = 'Death Echo',    restMod = -0.25,   moraleMod = -0.10, desc = 'wakes screaming most nights' },
        { id = 'ugly',          name = 'Ugly',          socialMod = -0.1,  desc = 'hard to look at', opinionMod = 'ugly_face' },
        { id = 'annoying_voice', name = 'Annoying Voice', socialMod = -0.1, desc = 'grates on everyone nearby', opinionMod = 'annoying' },
        { id = 'slow_learner',  name = 'Slow Learner',  xpMod = -0.15,    desc = 'takes longer to pick things up' },
        { id = 'sickly',        name = 'Sickly',        immuneMod = -0.2,  desc = 'catches everything going around' },
        { id = 'nervous',       name = 'Nervous',       breakThreshold = 15, desc = 'cracks under the smallest pressure' },
        { id = 'jealous',       name = 'Jealous',       socialMod = -0.1,  desc = 'resents others\' success', opinionMod = 'envious' },
    },
    -- Neutral/flavor (18)
    neutral = {
        { id = 'teetotaler',       name = 'Teetotaler',       desc = 'refuses drink' },
        { id = 'night_owl',        name = 'Night Owl',        desc = 'prefers the dark hours' },
        { id = 'gourmand',         name = 'Gourmand',         desc = 'appreciates fine food', opinionMod = 'hates_raw_food' },
        { id = 'ascetic',          name = 'Ascetic',          desc = 'needs little comfort', opinionMod = 'likes_simple' },
        { id = 'scar_tissue',      name = 'Scarred',          desc = 'carries old wounds' },
        { id = 'ex_soldier',       name = 'Ex-Soldier',       desc = 'served a prior tour' },
        { id = 'former_doc',       name = 'Former Doctor',    desc = 'trained in medicine' },
        { id = 'tinkerer',         name = 'Tinkerer',         desc = 'fidgets with machinery' },
        { id = 'anomaly_sensitive', name = 'Anomaly-Sensitive', desc = 'picks up signals others miss' },
        { id = 'void_touched',     name = 'Void-Touched',     desc = 'touched something they shouldn\'t have', moraleMod = -0.05 },
        { id = 'dreamer',          name = 'Dreamer',          desc = 'talks about places that aren\'t on any chart', restMod = -0.1 },
        { id = 'body_purist',      name = 'Body Purist',      desc = 'refuses prosthetics and implants', opinionMod = 'hates_bionics' },
        { id = 'transhumanist',    name = 'Transhumanist',    desc = 'wants to improve the body', opinionMod = 'wants_bionics' },
        { id = 'bloodlust',        name = 'Bloodlust',        desc = 'gets satisfaction from violence', opinionMod = 'enjoys_kills' },
        { id = 'cannibal',         name = 'Cannibal',         desc = 'no issue with human meat', opinionMod = 'likes_human_meat' },
        { id = 'pacifist',         name = 'Pacifist',         desc = 'refuses to fight', disabledWork = 'hunting' },
        { id = 'wimp',             name = 'Wimp',             desc = 'goes down at the first scratch', painThreshold = 0.3 },
        { id = 'masochist',        name = 'Masochist',        desc = 'finds comfort in pain', opinionMod = 'likes_pain' },
    },
}
-- Mutually exclusive trait pairs: colonist cannot have both
TRAITS.exclusions = {
    brave = 'coward', coward = 'brave',
    optimist = 'pessimist', pessimist = 'optimist',
    hardworking = 'lazy', lazy = 'hardworking',
    neat = 'clumsy', clumsy = 'neat',
    tough = 'sickly', sickly = 'tough',
    fast_learner = 'slow_learner', slow_learner = 'fast_learner',
    stoic = 'thin_skinned', thin_skinned = 'stoic',
    kind = 'jealous', jealous = 'kind',
    body_purist = 'transhumanist', transhumanist = 'body_purist',
    ascetic = 'gourmand', gourmand = 'ascetic',
    pacifist = 'bloodlust', bloodlust = 'pacifist',
    light_sleeper = 'insomniac', insomniac = 'light_sleeper',
}

Adlib.TRAITS = TRAITS

function Adlib.getRevivalTraits(skillLevel)
    local came_back, death_echo
    for _, t in ipairs(TRAITS.negative) do
        if t.id == 'came_back_wrong' then came_back = t end
        if t.id == 'death_echo' then death_echo = t end
    end
    if skillLevel >= 9 then
        return { death_echo }
    elseif skillLevel >= 6 then
        return { came_back, death_echo }
    else
        local extras = {}
        for _, t in ipairs(TRAITS.negative) do
            if t.id ~= 'came_back_wrong' and t.id ~= 'death_echo' then
                extras[#extras + 1] = t
            end
        end
        return { came_back, death_echo, extras[math.random(#extras)] }
    end
end

---------------------------------------------------------------------------
-- Backstory fragments (ad-lib templates)
---------------------------------------------------------------------------

-- Backstory origins: string or { text, disabledWork } table
-- disabledWork locks colonist out of 1-2 work priority columns
local BACKSTORY_ORIGINS = {
    -- Corporate
    'Signed a five-year with Mammona Mining. Year eight now.',
    'Was a {job} on {place} before the contract buyout.',
    { text = 'Owes Mammona more credits than a {job} makes in a decade.', disabledWork = { 'research' } },
    'Transferred from {place} after the site went dark. No debrief.',
    'Volunteered for Erebus detail. Nobody told them what that meant.',
    { text = 'Mammona HR flagged them as "non-essential" on {place}. Reassigned here.', disabledWork = { 'research' } },
    -- Mixed
    { text = 'Deserted a UTC patrol near {place}. Still has the tags.', disabledWork = { 'cooking' } },
    'Ran a repair shop on {place} until Mammona bought the district.',
    'Left {place} to search for a missing {relative}.',
    'Was a {job} on three different rocks before landing here.',
    { text = 'Was exiled from {place} for {crime}.', disabledWork = { 'medical' } },
    { text = 'Grew up on a station that lost atmo. Doesn\'t talk about it.', disabledWork = { 'mining' } },
    'Signed on for the credits. Didn\'t read the fine print.',
    -- Frontier
    'Walked out of the ruins of {place} carrying nothing.',
    'Survived a hull breach on a cargo run to {place}.',
    'Last one standing after {place} lost power in winter.',
    { text = 'Has been on six colonies. This is the seventh. Doesn\'t unpack.', disabledWork = { 'building' } },
    { text = 'Found frozen outside {place} with no memory of the last three days.', disabledWork = { 'research' } },
    'Was found half-conscious by scouts, clutching a {item}.',
    'Wandered alone for {duration}. Beacon running the whole time.',
    -- Old colony lineage / UTC transfers
    'Family line traces back to the Kennedy expedition. Doesn\'t talk about it.',
    'Worked {ha_corp} logistics until the contract expired. Took the next ship out.',
    { text = 'Ran a TerraGen clinic on {place}. License revoked after the incident.', disabledWork = { 'research' } },
    'Used to run a StarByte vending route on the outer rim. Margins got thin.',
    'Did a rotation as a deep diver on Thalassa Deep. Survived. Most don\'t.',
    { text = 'Served with a UTC enforcer unit near {place}. Discharged early.', disabledWork = { 'cooking' } },
    'Grew up in the Blocks on Foras. Left before the riots.',
    'Was crew on a Mammona space caravan out of Paxtera. Jumped ship.',
    'Fortune Arms tested weapons on {place}. Was the test subject wrangler.',
    { text = 'Spent three years on Nemaea scrapping automaton hulls. Still hears the servos.', disabledWork = { 'research' } },
    'Ran freight for the rim runners until a Black Maw crew hit the route.',
    'Claims to be from Novaris-3. The accent checks out. The papers don\'t.',
    'Survived Eclipse\'s End on Karnaith. Won\'t say how they got entered.',
    { text = 'Was a deep diver on Thalassa Deep. Got out when Delta Block flooded.', disabledWork = { 'mining' } },
    'Rode with the Solar Nomads on Rhea-2 for a season. Still has sand in everything.',
    'Sold GustoGrain NutriLoaf out of a Mammona commissary. Couldn\'t stomach it anymore.',
    'Used to service Dustweaver swarms on Karnaith. Knows how surveillance works.',
    'Ran a TaoTray vending route through Morvos. The acid storms ate the machines.',
    { text = 'Did time on Thalassa Deep. The neuro-lock scars are still visible.', disabledWork = { 'research' } },
    'Worked OmniCorp freight between Paxtera and the inner rim. Saw what they ship.',
    'Was a Zenith Syndicate runner on Rhea-2. Got out before it got ugly.',
    'Grew up on Orbit Hub 71. Parents ran StarByte Vends. Watched MARV-8 patch the hull every morning.',
    'Used to buy Sunny Fizz from the machine on deck three. The AI winked at me once. Swear it.',
    'Worked a TaoTray vending route through Karnaith. Bobo remembered my name. Creeped me out.',
    'Ate nothing but NutriLoaf for six months on a Mammona contract. Still can not taste anything.',
    'ShockPop Ultra kept me awake for three days during a double shift. Heart has not been right since.',
    'MARV-8 fixed my suit once. Took him four hours. Said it was not up to his standards after two.',
    'Ran a StarByte kiosk on Foras before the collapse. The Sunny unit kept selling drinks during the riots.',
    'Bought a CrunchWrap from an Orbit Hub 71 vendor in 2529. Best meal that year. Last meal before cryo.',
    { text = 'Ate TaoTray Glow Worms on a dare on Karnaith. Hallucinated for two days.', disabledWork = { 'research' } },
    'Cass Vale owed me credits from a supply run. Still does. Kid is slippery.',
    'My grandfather worked Shaft 12 on Foras. Never came home after the Maw opened.',
    'Parents were from Acedia. City of Rot. Said the air tasted like burning hair.',
    'Family fled Nyxport during the Fall. Lost everything at the docks.',
    'Had an uncle in Thalassa Deep. Delta Block. Letters stopped after the flooding.',
    'Grew up on Novaris-3. Everything monitored. Everything controlled. Got out as soon as I could.',
    'Heard about the Maw of Foras from a trader. Said the ground just opened and swallowed a thousand people.',
    'Someone told me about a chaplain named Alba on Foras. Said he kept people alive with words alone. Then the words ran out.',
    'Met a man who claimed he escaped Thalassa Deep. Kept drawing the same symbol over and over. Would not explain it.',
}

local CULT_BACKSTORY_ORIGINS = {
    -- Exposure survivors
    'Was on the survey team at {place} when they breached the ruin. Only one who came back.',
    'Spent {duration} in quarantine after a deep mine exposure incident. Released early.',
    'The psych eval flagged them. Mammona sent them here anyway.',
    'Walked out of a collapsed mine shaft after {duration}. No explanation.',
    'Keeps a {cult_item} from a prior dig. Talks to it sometimes.',
    'Found a {cult_item} buried near {cult_place}. Has not slept well since.',
    -- Rogue researchers
    'Was part of Mammona\'s Anomalous Biosphere Program. Reassigned here. No explanation given.',
    'Published a paper on non-terrestrial biology. It was redacted. They were transferred.',
    'Carries a {cult_item} from a classified dig site. Won\'t say which planet.',
    'Asked too many questions about Fortuna. Now they\'re on Erebus. Coincidence.',
    'Their research notes describe organisms not in any catalog.',
    -- Ambiguous
    'Says the carvings in the ruins aren\'t writing. Says they\'re instructions.',
    'Woke one morning speaking a language no one recognized. Stopped after a day. Still remembers it.',
    'Their readings always spike near the drill sites. Nobody else\'s do.',
}

local BACKSTORY_FILLS = {
    place = {
        -- Named colonies/stations
        'Kovac Station', 'Port Meridian', 'Anchorage-9', 'New Taipei Orbital',
        'Callisto Relay', 'Voss Landing', 'the Helios Yards', 'Crestfall Colony',
        'Deepwell Platform', 'Ashford Station', 'Sector 14',
        -- Old colony sites (Kennedy-era and after)
        'Foras', 'Karnaith', 'Paxtera', 'Novaris-3', 'Vanguardus',
        'Hyades', 'Nyxport', 'Acedia', 'Orbit Hub 71',
        'the Edge of Oblivion', 'Nerthus-9', 'Rhea-2', 'Morvos',
        'Nemaea', 'the Blocks on Foras', 'the Bazaar of Hyades',
        -- Generic descriptors
        'an outer rim refinery', 'a failed mining colony',
        'a decommissioned relay station', 'the border settlements',
        'a Mammona work camp', 'an inner rim hab block',
        'a Vanguard Alliance recruitment post', 'a TerraGen field hospital',
    },
    ha_corp = {
        'Mammona Mining', 'Mammona Construction', 'MasTema',
        'Fortune Arms', 'NexLink Communications', 'Orbis Energy',
        'TerraGen Pharmaceuticals', 'Mammona', 'Paxtera AgroTech',
        'OmniCorp Shipping', 'Xinyo Enterprises', 'TaoTray Systems',
        'StarByte Vends', 'BioVault Inc.',
    },
    job = {
        'miner', 'engineer', 'medic', 'mechanic', 'surveyor',
        'cook', 'security contractor', 'drill operator', 'logistics tech',
        'cargo hand', 'field researcher', 'comms operator', 'pilot',
        'welder', 'systems tech', 'quartermaster',
        'enforcer', 'deep diver', 'automaton tech', 'warp gate operator',
        'PMC', 'descent pod operator', 'Dustweaver technician',
        'bazaar vendor', 'moisture farmer', 'caravan guard',
        'vending tech', 'StarByte route runner',
    },
    duration = {
        'three months', 'a year', 'two rotations', 'longer than they can count',
        'half a decade', 'since the last supply drop',
    },
    group = {
        'military', 'corporate', 'refugee', 'research', 'scavenger', 'transit',
    },
    crime = {
        'speaking against site management', 'hoarding rations', 'theft',
        'striking a supervisor', 'refusing reassignment', 'data breach',
    },
    relative = {
        'brother', 'sister', 'daughter', 'son', 'partner', 'old mentor',
    },
    item = {
        'thermal core', 'broken transponder', 'child\'s toy', 'sealed drive',
        'broken radio', 'faded photograph', 'small blade',
        'Mammona ID badge from Foras', 'cracked neuro-lock',
        'deactivated Janus key', 'polymer gel canister',
        'smokestick tin', 'M-Points card with no balance',
        'Thalassa Deep inmate tag', 'Eclipse\'s End contestant bracelet',
        'empty Sunny Fizz can', 'StarByte loyalty card with three stamps',
        'TaoTray voucher for one free bowl', 'dented MARV-8 service tag',
    },
    cult_place = {
        'the dig site beneath Anchorage-9', 'a collapsed precursor structure',
        'a sealed survey site on Gaia A^1x', 'a crevasse that shouldn\'t exist',
        'the deep bore at Kovac Station', 'Site 7', 'a quarantined research lab',
        'a cave system the maps didn\'t show',
        'Subsurface Sector Delta-13', 'the Maw of Foras',
        'the entombed city beneath Gaia A^1x', 'Shaft 12 on Foras',
    },
    cult_item = {
        'stone tablet covered in spiraling glyphs', 'sample jar that hums when held',
        'core sample that won\'t stop growing', 'journal written in no known alphabet',
        'fragment of carved membrane', 'sphere of dark glass that resonates',
        'tooth the size of a forearm',
        'shard of crystalline alloy that shifts color', 'rusted chain link etched with runes',
    },
    cult_rank = {
        'research lead', 'survey tech', 'containment specialist', 'site analyst',
        'field observer', 'sample handler', 'deep bore monitor',
    },
    cult_event = {
        'the samples started moving on their own',
        'the lead researcher stopped speaking and started writing on the walls',
        'something answered the sonar pulse',
        'the bore shaft sealed itself overnight',
        'the tissue samples grew back',
        'the readings went off the charts and stayed there',
    },
}

local CULT_BACKSTORY_FILLS = BACKSTORY_FILLS  -- shares all pools

---------------------------------------------------------------------------
-- Event flavor templates (used by storyteller)
---------------------------------------------------------------------------

local EVENT_FLAVOR = {
    blizzard = {
        '{adjective} wind coming in from the {direction}.',
        'Visibility drops. The frost bites {bodypart} first.',
        'White-out rolling in from the mountains. {adjective}.',
    },
    creature_sighting = {
        'Tracks in the snow. {adjective}, fresh. Something {size} passed through.',
        'A {adjective} shape moves at the edge of visibility.',
        'Ground shaking. Something {adjective} moving under the ice.',
    },
    good_fortune = {
        'Word comes in. {good_thing}.',
        'For once, something goes right. {good_thing}.',
        '{good_thing}. Nobody questions it.',
    },
    dread = {
        'Aurora cut out. Went {adjective} quiet.',
        'Something off. Colonists keep rubbing their {bodypart}.',
        'A {adjective} sound from below. Coming through the permafrost.',
    },
    eldritch = {
        'Sound from the ice. Rhythmic. Not wind. Something {eldritch_adj}.',
        'Stars appear in the wrong positions. One of them {eldritch_verb}.',
        'A colonist wakes screaming about {eldritch_noun} beneath the glacier.',
        'Shadows stretch the wrong way. Toward the {bodypart}.',
        'The floor {eldritch_verb}. Once. Then stopped.',
        'The aurora turns {eldritch_color}. Shapes in it. Too many {eldritch_limb}.',
    },
    cult_arrival = {
        'People out of the blizzard. They have dig equipment.',
        'A group walks in carrying {cult_item}. Say they were sent here.',
        'Survivors from {cult_place}. Psych profiles are flagged.',
        'Strangers at the perimeter. Drawing {eldritch_adj} symbols in the snow.',
    },
    madness = {
        'A colonist stares at the ice for hours. Whispering coordinates.',
        '{first_name} says the walls are moving. Others aren\'t arguing.',
        'Three colonists drew the same symbol independently. None can explain it.',
        'Someone rearranged the equipment overnight. The pattern {eldritch_verb}.',
        'A colonist claims the drill vibrations spell out words.',
    },
    void_rift = {
        'Ground cracked open. {eldritch_color} light coming out.',
        'Fissure in the permafrost. Air coming out of it is {eldritch_adj}.',
        'Crust buckled. Whatever\'s under there {eldritch_verb}.',
    },
    dark_ritual = {
        'The sensitives gather near the ruins. Murmuring. Everything feels {eldritch_adj}.',
        'They open the research notes by lamplight. The diagrams have changed.',
        'The readings begin. Ground beneath them {eldritch_verb}.',
    },
}

local FLAVOR_FILLS = {
    adjective = {
        'terrifying', 'ancient', 'enormous', 'bone-white', 'shrieking',
        'unnatural', 'freezing', 'rumbling', 'distant', 'familiar',
        'hollow', 'wet', 'grinding', 'low', 'sharp',
    },
    direction = {
        'north', 'northeast', 'the frozen wastes', 'the mountains',
        'the glacier fields', 'the ice shelf', 'beyond the ridge',
    },
    bodypart = {
        'fingers', 'toes', 'ears', 'the lungs', 'exposed skin', 'bones',
    },
    size = {
        'large', 'massive', 'enormous', 'oversized', 'lumbering',
    },
    good_thing = {
        'scouts found a supply cache buried in the snow',
        'a warm current pushes through the valley',
        'a wanderer arrives with field experience and steady hands',
        'the hunting party returns with a full haul',
        'a vein of ore is exposed by the shifting ice',
    },
    eldritch_adj = {
        'wrong', 'vast', 'rhythmic', 'gelatinous', 'iridescent',
        'impossible', 'nauseating', 'formless', 'ancient', 'sentient',
        'translucent', 'pulsating', 'familiar', 'alien', 'biological',
    },
    eldritch_verb = {
        'blinks', 'pulses', 'writhes', 'shifts', 'watches',
        'grows', 'breathes', 'unfolds', 'reaches', 'remembers',
        'clicks', 'contracts', 'leaks', 'hums',
    },
    eldritch_noun = {
        'geometries', 'cities', 'faces', 'halls that extend forever',
        'a sound that won\'t form a word', 'something that was already there',
        'the space between stars', 'a door that should not open',
        'teeth in the walls', 'eyes in the permafrost',
    },
    eldritch_color = {
        'a color with no name', 'raw red', 'black-green',
        'the color of static', 'bruise-purple', 'corpse-light pale',
    },
    eldritch_limb = {
        'limbs', 'mouths', 'eyes', 'angles', 'segments', 'wings',
    },
    first_name = {
        'Soren', 'Kira', 'Thane', 'Voss', 'Cade', 'Mira', 'Beck',
    },
}

---------------------------------------------------------------------------
-- Planet detection helper
---------------------------------------------------------------------------

local function getPlanetId()
    local ok, Planet = pcall(require, 'src.world.planet')
    if ok and Planet.getId then return Planet.getId() end
    return nil
end

---------------------------------------------------------------------------
-- Planet-specific FLAVOR_FILLS overrides
-- Keys here replace the matching FLAVOR_FILLS pool on that planet.
---------------------------------------------------------------------------

local PLANET_FLAVOR_FILLS = {
    rhea_2 = {
        direction = {
            'the dune sea', 'the canyon rim', 'the salt flats', 'the badlands',
            'the oasis', 'beyond the ridgeline', 'the sand wastes',
        },
        good_thing = {
            'scouts found a water cache buried in the sand',
            'a cool wind pushes through the canyon',
            'a wanderer arrives with desert survival training',
            'the foraging party found an oasis',
            'a vein of ore exposed by shifting dunes',
        },
        eldritch_noun = {
            'teeth in the sand', 'eyes in the dunes',
            'something breathing in the heat',
            'geometries', 'a sound that won\'t form a word',
            'the space between stars', 'a door that should not open',
        },
    },
    morvos = {
        direction = {
            'the acid flats', 'the fungal grove', 'the corrosion zone', 'the spore fields',
            'the rock platforms', 'beyond the toxic marsh', 'the sealed ridge',
        },
        good_thing = {
            'scouts found a sealed supply cache in acid-proof casing',
            'the toxic levels dropped overnight',
            'a fungal bloom yielded edible specimens',
            'the acid rain stopped for now',
            'a sealed bunker was spotted from the ridge',
        },
        eldritch_noun = {
            'shapes in the acid', 'spores that think',
            'the corrosion that spreads on purpose',
            'geometries', 'a sound that won\'t form a word',
            'the space between stars', 'a door that should not open',
        },
    },
    nerthus_9 = {
        direction = {
            'the open ocean', 'the reef line', 'the far island', 'the shallows',
            'the deep trench', 'beyond the atoll', 'the volcanic shore',
        },
        good_thing = {
            'the dive team found a sealed wreck with supplies',
            'the tide brought in driftwood and salvage',
            'a coral formation yielded rich mineral deposits',
            'the storm passed without flooding the hab',
            'a fishing haul came in heavy',
        },
        eldritch_noun = {
            'tentacles in the dark water', 'the pressure that watches',
            'a song from the deep',
            'geometries', 'a sound that won\'t form a word',
            'the space between stars', 'a door that should not open',
        },
    },
    paxtera_prime = {
        direction = {
            'the meadow', 'the forest edge', 'the hills', 'the river valley',
            'the farmland', 'beyond the treeline', 'the wetlands',
        },
        good_thing = {
            'the harvest came in full',
            'a wanderer arrived with farming experience',
            'scouts found a berry grove in the forest',
            'the hunting party bagged a deer',
            'a trader is heading this way from the south',
        },
        eldritch_noun = {
            'geometries', 'cities', 'faces',
            'a sound that won\'t form a word',
            'something that was already there',
            'the space between stars', 'a door that should not open',
        },
    },
    nemaea = {
        direction = {
            'the crater field', 'the Dyson ruins', 'the irradiated wastes',
            'the wreckage belt', 'the regolith plains', 'beyond the hull fragments',
        },
        good_thing = {
            'scouts found a sealed maintenance locker with components',
            'an automaton patrol passed without detecting the colony',
            'a Dyson fragment landed nearby with intact circuits',
            'the radiation levels dropped below threshold',
            'a hull plate cache was spotted on the surface',
        },
        eldritch_noun = {
            'the signal that won\'t stop', 'a machine that remembers',
            'frequencies no one assigned',
            'geometries', 'a sound that won\'t form a word',
            'the space between stars', 'a door that should not open',
        },
    },
    gaia_a1x = {
        place = {
            'Foras', 'the Blocks on Foras', 'Orbit Hub 71', 'the Maw of Foras',
            'Shaft 12', 'Kovac Station', 'Port Meridian', 'a failed mining colony',
            'a StarByte vending depot', 'the old Vale workshop',
        },
        direction = {
            'the meadow', 'the deep forest', 'the river', 'the highlands',
            'the corrupted zone', 'beyond the tree line', 'the valley floor',
        },
        good_thing = {
            'the orchard yielded more fruit than expected',
            'a wanderer arrived from a surviving settlement',
            'the corruption retreated from the south field',
            'scouts found a clean water spring in the forest',
            'the hunting party returned with a full haul',
        },
        eldritch_noun = {
            'roots that move', 'the chitinous pulse',
            'Baldrungen\'s breath',
            'geometries', 'a sound that won\'t form a word',
            'the space between stars', 'a door that should not open',
        },
    },
}

---------------------------------------------------------------------------
-- Planet-specific EVENT_FLAVOR overrides
-- If the current planet has an entry for a category, use it instead.
---------------------------------------------------------------------------

local PLANET_EVENT_FLAVOR = {
    rhea_2 = {
        blizzard = {  -- sandstorm equivalent
            '{adjective} wind driving sand from the {direction}.',
            'Visibility drops. Sand scours {bodypart}.',
            'Dune wall rolling in. {adjective}.',
        },
        creature_sighting = {
            'Tracks in the sand. {adjective}, fresh. Something {size} burrowed through.',
            'A {adjective} shape moves in the heat shimmer.',
            'Ground shifting. Something {adjective} moving under the dunes.',
        },
        dread = {
            'The twin suns set wrong. Went {adjective} quiet.',
            'Water stores are lower than reported.',
            'A {adjective} rumble from beneath the sand.',
        },
    },
    morvos = {
        blizzard = {  -- acid storm equivalent
            '{adjective} acid rain driving in from the {direction}.',
            'Corrosive fog rolling in. Seal everything.',
            'The air burns. Visibility dropping fast.',
        },
        creature_sighting = {
            'Acid-etched tracks. Something {size} crawled through.',
            'A {adjective} shape moves through the toxic haze.',
            'Spore bursts from the ground. Something {adjective} nesting below.',
        },
        dread = {
            'The air quality dropped. Filters straining.',
            'Metal surfaces are pitting faster than usual.',
            'A {adjective} hiss from the acid pools.',
        },
    },
    nerthus_9 = {
        blizzard = {  -- storm equivalent
            '{adjective} storm surge from the {direction}.',
            'Waves breaking over the seawall. Water rising fast.',
            'Hurricane-force winds. Visibility near zero.',
        },
        creature_sighting = {
            'Something {size} passed beneath the shallows.',
            'A {adjective} shadow in the deep water.',
            'Tentacle marks on the hull plates. Something was here.',
        },
        dread = {
            'The tide is rising faster than predicted.',
            'Something large is circling the island.',
            'A {adjective} vibration from the ocean floor.',
        },
    },
    paxtera_prime = {
        blizzard = {  -- rain/storm equivalent
            '{adjective} rain coming in from the {direction}.',
            'Thunder rolling over the hills. Lightning soon.',
            'Overcast and cold. Mud everywhere.',
        },
        creature_sighting = {
            'Tracks in the mud. {adjective}, fresh. Something {size} passed through.',
            'A {adjective} shape at the treeline.',
            'The livestock are restless. Predator nearby.',
        },
        dread = {
            'Smoke on the horizon. Raider camp.',
            'The well water tastes wrong.',
            'A {adjective} howl from the forest. Closer than last time.',
        },
    },
    nemaea = {
        blizzard = {  -- solar flare / meteor equivalent
            'Solar flare warning. Radiation spiking from the {direction}.',
            'Dyson fragment inbound. Take cover.',
            'Radiation burst. Suit integrity critical.',
        },
        creature_sighting = {
            'Automaton patrol detected {direction}.',
            'A {adjective} drone formation scanning the perimeter.',
            'Seismic pattern matches a {size} automaton approach.',
        },
        dread = {
            'The Dyson Sphere groans. Fragments shifting overhead.',
            'Suit O2 reserves are lower than expected.',
            'A {adjective} signal on all frequencies. Source unknown.',
        },
    },
    gaia_a1x = {
        blizzard = {  -- corruption equivalent
            'Spore fall from the {direction}. The corruption spreads.',
            'The ground trembles. Baldrungen stirs.',
            'Chitin cracking from below. Something is coming up.',
        },
        creature_sighting = {
            'Husk tracks. {adjective}, fresh. A swarm passed through.',
            'A {adjective} shape moves in the corrupted zone.',
            'The trees are dying in a line. Something {size} underneath.',
        },
        dread = {
            'The corruption crept closer overnight.',
            'A colonist found insect legs in their bedding.',
            'A {adjective} pulse from deep underground. Rhythmic.',
        },
    },
}

---------------------------------------------------------------------------
-- Effective fills: merge planet overrides onto any base fills table
---------------------------------------------------------------------------

--- Overlay planet-specific fills onto a base fills table.
--- If no planet overrides exist, returns baseFills unchanged.
local function applyPlanetFills(baseFills)
    local pid = getPlanetId()
    if pid and PLANET_FLAVOR_FILLS[pid] then
        local merged = {}
        for k, v in pairs(baseFills) do merged[k] = v end
        for k, v in pairs(PLANET_FLAVOR_FILLS[pid]) do merged[k] = v end
        return merged
    end
    return baseFills
end

--- Shorthand for applyPlanetFills(FLAVOR_FILLS).
local function getEffectiveFills()
    return applyPlanetFills(FLAVOR_FILLS)
end

---------------------------------------------------------------------------
-- Generation functions
---------------------------------------------------------------------------

-- Pick random element from array
local function pick(arr)
    return arr[math.random(#arr)]
end

-- Generate a name from syllable pool
function Adlib.generateName(pool, minSyl, maxSyl)
    pool = pool or 'common'
    minSyl = minSyl or 2
    maxSyl = maxSyl or 3
    local syls = SYLLABLES[pool] or SYLLABLES.common
    local count = minSyl + math.random(maxSyl - minSyl)
    local name = ''
    for i = 1, count do
        name = name .. pick(syls)
    end
    return name:sub(1, 1):upper() .. name:sub(2)
end

-- Pick a gendered first name pool
local function pickFirstName(gender)
    if gender == 'nb' then
        return pick(FIRST_NAMES_NB)
    elseif gender == 'female' then
        -- Small chance of a neutral name
        if math.random() < 0.15 then return pick(FIRST_NAMES_NB) end
        return pick(FIRST_NAMES_F)
    else
        if math.random() < 0.15 then return pick(FIRST_NAMES_NB) end
        return pick(FIRST_NAMES_M)
    end
end

-- Roll a random gender: 48% male, 48% female, 4% nb
function Adlib.rollGender()
    local r = math.random()
    if r < 0.48 then return 'male'
    elseif r < 0.96 then return 'female'
    else return 'nb'
    end
end

-- Generate a full name (first + last). Returns name, gender.
function Adlib.fullName(gender)
    gender = gender or Adlib.rollGender()
    if math.random() < 0.6 then
        return pickFirstName(gender) .. ' ' .. pick(LAST_NAMES), gender
    else
        -- Procedural: 10% chance of ancient syllable pool (old colony lineage)
        local r = math.random()
        local pool = r < 0.1 and 'ancient' or (r < 0.55 and 'sharp' or 'smooth')
        local first = Adlib.generateName(pool, 2, 3)
        return first .. ' ' .. pick(LAST_NAMES), gender
    end
end

-- Fill an ad-lib template: replaces {key} with random pick from fills[key]
function Adlib.fillTemplate(template, fills)
    return template:gsub('{([%w_]+)}', function(key)
        local pool = fills[key]
        if pool then return pick(pool) end
        return '{' .. key .. '}'
    end)
end

-- Generate a backstory: returns text, disabledWork table
function Adlib.generateBackstory()
    local origin = pick(BACKSTORY_ORIGINS)
    if type(origin) == 'table' then
        return Adlib.fillTemplate(origin.text, BACKSTORY_FILLS), origin.disabledWork
    end
    return Adlib.fillTemplate(origin, BACKSTORY_FILLS), nil
end

-- Generate random traits (1 positive, 0-1 negative, 0-1 neutral)
function Adlib.generateTraits()
    local result = {}
    local taken = {}  -- track trait IDs to enforce exclusions

    local function canAdd(trait)
        if taken[trait.id] then return false end
        -- Check mutual exclusion
        local excluded = TRAITS.exclusions[trait.id]
        if excluded and taken[excluded] then return false end
        return true
    end

    local function addTrait(trait)
        if canAdd(trait) then
            result[#result + 1] = trait
            taken[trait.id] = true
            return true
        end
        return false
    end

    -- Always one positive (retry up to 5 times on exclusion conflict)
    for _ = 1, 5 do
        if addTrait(pick(TRAITS.positive)) then break end
    end
    -- 60% chance of a negative
    if math.random() < 0.6 then
        for _ = 1, 5 do
            if addTrait(pick(TRAITS.negative)) then break end
        end
    end
    -- 40% chance of a neutral
    if math.random() < 0.4 then
        for _ = 1, 5 do
            if addTrait(pick(TRAITS.neutral)) then break end
        end
    end
    return result
end

-- Generate event flavor text (planet-aware)
function Adlib.eventFlavor(category)
    local pid = getPlanetId()
    local templates
    if pid and PLANET_EVENT_FLAVOR[pid] and PLANET_EVENT_FLAVOR[pid][category] then
        templates = PLANET_EVENT_FLAVOR[pid][category]
    else
        templates = EVENT_FLAVOR[category]
    end
    if not templates then return nil end
    return Adlib.fillTemplate(pick(templates), getEffectiveFills())
end

--- Return a planet-specific event flavor string for a category, or nil.
--- Used by storyteller.lua for planet-aware event messages.
function Adlib.getPlanetEventFlavor(category)
    local pid = getPlanetId()
    if not pid then return nil end
    local flavors = PLANET_EVENT_FLAVOR[pid]
    if flavors and flavors[category] then
        local pool = flavors[category]
        local raw = pool[math.random(#pool)]
        return Adlib.fillTemplate(raw, getEffectiveFills())
    end
    return nil
end

-- Easter egg trait sets for special colonists
local function getFischbachTraits()
    local good = {}
    for _, t in ipairs(TRAITS.positive) do
        if t.id == 'brave' or t.id == 'kind' or t.id == 'tough' then
            good[#good + 1] = t
        end
    end
    return good
end

-- Generate a full colonist identity
function Adlib.generateColonistIdentity()
    local backstoryText, disabledWork = Adlib.generateBackstory()
    local name, gender = Adlib.fullName()
    local traits = Adlib.generateTraits()

    -- Easter egg: if last name is Fischbach, rename to Mark and give good traits
    if name:match('%s[Ff]ischbach$') then
        name = 'Mark Fischbach'
        gender = 'male'
        traits = getFischbachTraits()
    end

    return {
        name         = name,
        gender       = gender,
        backstory    = backstoryText,
        disabledWork = disabledWork,
        traits       = traits,
    }
end

-- Generate a cult backstory
function Adlib.generateCultBackstory()
    return Adlib.fillTemplate(pick(CULT_BACKSTORY_ORIGINS), CULT_BACKSTORY_FILLS)
end

-- Generate a cultist identity (always has anomaly_sensitive trait)
function Adlib.generateCultistIdentity()
    local traits = {}
    -- Always anomaly_sensitive
    for _, t in ipairs(TRAITS.neutral) do
        if t.id == 'anomaly_sensitive' then
            traits[#traits + 1] = t
            break
        end
    end
    -- 50% chance of void-touched too
    if math.random() < 0.5 then
        for _, t in ipairs(TRAITS.neutral) do
            if t.id == 'void_touched' then
                traits[#traits + 1] = t
                break
            end
        end
    end
    -- 30% chance of a normal negative trait
    if math.random() < 0.3 then
        traits[#traits + 1] = pick(TRAITS.negative)
    end
    local cName, cGender = Adlib.fullName()
    return {
        name      = cName,
        gender    = cGender,
        backstory = Adlib.generateCultBackstory(),
        traits    = traits,
    }
end

---------------------------------------------------------------------------
-- Pronoun helpers
---------------------------------------------------------------------------

local PRONOUNS = {
    male   = { subject = 'he',   object = 'him',  possess = 'his',   reflexive = 'himself'  },
    female = { subject = 'she',  object = 'her',  possess = 'her',   reflexive = 'herself'  },
    nb     = { subject = 'they', object = 'them', possess = 'their', reflexive = 'themself' },
}

function Adlib.pronouns(gender)
    return PRONOUNS[gender] or PRONOUNS.nb
end

-- Convenience: "He/She/They"
function Adlib.subject(gender)   return Adlib.pronouns(gender).subject end
function Adlib.object(gender)    return Adlib.pronouns(gender).object end
function Adlib.possess(gender)   return Adlib.pronouns(gender).possess end

-- Capitalize first letter (for sentence starts)
function Adlib.Subject(gender)
    local s = Adlib.subject(gender)
    return s:sub(1, 1):upper() .. s:sub(2)
end

---------------------------------------------------------------------------
-- Creature name generation (for named/boss creatures)
---------------------------------------------------------------------------

local CREATURE_PREFIXES_NATIVE = {
    'Frost-Scarred', 'Massive', 'Starving', 'Alpha',
    'Rogue', 'Maddened', 'Albino', 'Elder',
    'One-Eyed', 'Ravenous', 'Pale', 'Titan',
    'Howling', 'Gaunt', 'Scarred', 'Ancient',
}

local CREATURE_PREFIXES_CORRUPTED = {
    'Tumorous', 'Split-Jawed', 'Membrane-Wrapped', 'Bloated',
    'Fissured', 'Skinless', 'Calcified', 'Overgrown',
    'Parasitic', 'Spore-Crusted', 'Boneless', 'Weeping',
    'Pale', 'Eyeless', 'Bristled', 'Pulsing',
}

local CREATURE_SUFFIXES_NATIVE = {
    'of the Deep Ice', 'the Undying', 'of the Wastes', 'Bonecrusher',
    'the Devourer', 'Frostbane', 'of the Long Dark', 'the Relentless',
    'Icemaw', 'the Howler', 'Permafrost', 'the Colossus',
}

local CREATURE_SUFFIXES_CORRUPTED = {
    'That Won\'t Die', 'from Below', 'the Unformed', 'of the Growth',
    'the Splitting', 'That Came Up', 'of the Black Tissue', 'the Formless',
    'of the Deep Vein', 'the Waking', 'That Grew Back', 'of the Membrane',
}

function Adlib.namedCreature(baseName, corrupted)
    local prefixes = corrupted and CREATURE_PREFIXES_CORRUPTED or CREATURE_PREFIXES_NATIVE
    local suffixes = corrupted and CREATURE_SUFFIXES_CORRUPTED or CREATURE_SUFFIXES_NATIVE
    local style = math.random(3)
    if style == 1 then
        return pick(prefixes) .. ' ' .. baseName
    elseif style == 2 then
        return baseName .. ' ' .. pick(suffixes)
    else
        return pick(prefixes) .. ' ' .. baseName .. ' ' .. pick(suffixes)
    end
end

---------------------------------------------------------------------------
-- Procedural artifact/equipment naming (prefix + base + suffix)
---------------------------------------------------------------------------

local ARTIFACT_PREFIXES_HUMAN = {
    'Reinforced', 'Standard-Issue', 'Salvaged', 'Hardened',
    'Military-Grade', 'Field-Modified', 'Jury-Rigged', 'Worn',
    'Heavy-Duty', 'Surplus', 'Reclaimed', 'Thermal-Rated',
    'Fortune Arms', 'Mammona-Issued', 'UTC-Stamped', 'Gauss-Chambered',
}

local ARTIFACT_PREFIXES_ALIEN = {
    'Crystalline', 'Carved', 'Membrane-Laced', 'Resonant',
    'Grown', 'Fused', 'Living', 'Pulsing', 'Calcified', 'Chitinous',
    'Precursor', 'Bone-Lattice', 'Fossilized', 'Vein-Threaded',
}

local ARTIFACT_BASES = {
    weapon = {
        'Rifle', 'Sidearm', 'Blade', 'Cleaver', 'Spear',
        'Maul', 'Crossbow', 'Hatchet', 'Knife', 'Lance',
        'Shotgun', 'Prod',
    },
    armor = {
        'Vest', 'Plate', 'Helmet', 'Gauntlets', 'Greaves',
        'Shield', 'Exoframe', 'Harness', 'Chestrig', 'Pauldron',
    },
    accessory = {
        'Tag', 'Band', 'Pendant', 'Transponder', 'Implant',
        'Visor', 'Patch', 'Sash', 'Core Fragment', 'Relic',
    },
    tool = {
        'Pickaxe', 'Hammer', 'Multitool', 'Saw', 'Drill',
        'Wrench', 'Tongs', 'Welder', 'Caliper', 'Scanner',
    },
}

local ARTIFACT_SUFFIXES_HUMAN = {
    'of the Long Dark', 'of the Outer Rim', 'of the Whiteout',
    'of the Permafrost', 'of the Old Contract', 'of Silent Running',
    'of the Last Crew', 'of Ashford Station', 'of the Supply Line',
    'of the First Drop', 'of the Garrison', 'Mark IV',
    'of the Kennedy', 'of Foras', 'of Thalassa Deep', 'of the Warp Gate',
}

local ARTIFACT_SUFFIXES_ALIEN = {
    'of the Frozen Deep', 'of the Growth', 'of the Membrane',
    'of the Void Beneath', 'That Pulses', 'of the Black Tissue',
    'of the Precursors', 'That Resonates', 'of the Living Stone',
    'of the Spore Bed', 'That Won\'t Stay Dead', 'of the Hollow',
}

function Adlib.artifactName(category, alien)
    category = category or 'weapon'
    local bases = ARTIFACT_BASES[category] or ARTIFACT_BASES.weapon
    local prefixes = alien and ARTIFACT_PREFIXES_ALIEN or ARTIFACT_PREFIXES_HUMAN
    local suffixes = alien and ARTIFACT_SUFFIXES_ALIEN or ARTIFACT_SUFFIXES_HUMAN
    local prefix = pick(prefixes)
    local base = pick(bases)

    local style = math.random(4)
    if style == 1 then
        return prefix .. ' ' .. base
    elseif style == 2 then
        return base .. ' ' .. pick(suffixes)
    elseif style == 3 then
        return prefix .. ' ' .. base .. ' ' .. pick(suffixes)
    else
        return pickFirstName(Adlib.rollGender()) .. "'s " .. base
    end
end

---------------------------------------------------------------------------
-- Location generation (settlements, POIs, ruins near the colony)
---------------------------------------------------------------------------

local LOCATION_TYPES = {
    -- Human locations
    settlement = {
        { prefix = 'Outpost',  suffix = '{loc_terrain}' },
        { prefix = 'Camp',     suffix = '{loc_terrain}' },
        { prefix = 'Site',     suffix = '{loc_designator}' },
        { prefix = '{loc_adj}', suffix = 'Platform' },
        { prefix = '{loc_adj}', suffix = 'Station' },
        { prefix = 'Forward',  suffix = 'Base {loc_designator}' },
    },
    ruin = {
        { prefix = 'Abandoned Site', suffix = '{loc_designator}' },
        { prefix = 'Failed Colony',  suffix = '{loc_old_name}' },
        { prefix = '{loc_adj}',      suffix = 'Wreckage' },
        { prefix = 'Old',            suffix = '{loc_old_name}' },
        -- Precursor ruins
        { prefix = 'The {loc_organic}', suffix = 'Structure' },
        { prefix = 'The {loc_adj}',     suffix = 'Formation' },
    },
    landmark = {
        { prefix = 'The',       suffix = '{loc_adj} {loc_formation}' },
        { prefix = '{loc_adj}', suffix = '{loc_formation}' },
        { prefix = '{loc_beast}\'s', suffix = '{loc_formation}' },
    },
    dungeon = {
        { prefix = 'Shaft',     suffix = '{loc_designator}' },
        { prefix = 'The {loc_adj}', suffix = '{loc_depth}' },
        { prefix = '{loc_beast}\'s', suffix = '{loc_depth}' },
        { prefix = 'The',       suffix = '{loc_depth} of {loc_old_name}' },
        -- Precursor depths
        { prefix = 'The {loc_organic}', suffix = '{loc_depth}' },
        { prefix = 'The {loc_adj}',     suffix = 'Cavity' },
    },
}

local LOCATION_FILLS = {
    loc_terrain = {
        'Ridge', 'Basin', 'Glacier', 'Shelf', 'Peak',
        'Crater', 'Vent', 'Plateau', 'Crag', 'Flats', 'Gap',
    },
    loc_adj = {
        'Frozen', 'Silent', 'Black', 'White', 'Iron', 'Dead',
        'Bitter', 'Howling', 'Grey', 'Shattered', 'Sunken', 'Buried',
        'Bleak', 'Pale', 'Deep', 'Storm', 'Glass', 'Collapsed',
    },
    loc_old_name = {
        'Kovac', 'Meridian', 'Anchorage', 'Ashford', 'Crestfall',
        'Deepwell', 'Helios', 'Voss', 'Callisto', 'Rimgate',
        'Blackwell', 'Sector 7', 'Burnside', 'Ironmere', 'Hullbreak',
        'Foras', 'Fortuna', 'Karnaith', 'Paxtera', 'Nyxport',
        'Acedia', 'Delta-13', 'Thalassa', 'Nemaea', 'Vanguardus',
        'Rhea', 'Morvos', 'Hyades', 'Oblivion',
    },
    loc_formation = {
        'Pillar', 'Arch', 'Spire', 'Chasm', 'Tooth', 'Gate',
        'Crown', 'Scar', 'Throat', 'Eye', 'Maw', 'Fist',
    },
    loc_beast = {
        'Wurm', 'Crawler', 'Burrower', 'Stalker', 'Leviathan',
        'Bear', 'Wolf', 'Howler', 'Titan', 'Broodmother',
    },
    loc_depth = {
        'Shaft', 'Vein', 'Cavity', 'Bore', 'Tunnel',
        'Chamber', 'Pit', 'Labyrinth', 'Vault', 'Abyss',
    },
    loc_designator = {
        '7-A', '12', '3-West', 'Gamma', 'Null', '9',
        'Alpha', '22-B', 'Prime', 'Six', 'Delta', '4-North',
    },
    loc_organic = {
        'Membrane', 'Cartilage', 'Vein', 'Tissue', 'Growth',
        'Marrow', 'Nodule', 'Cavity', 'Mucous', 'Calcified',
    },
}

function Adlib.generateLocation(locType)
    locType = locType or 'settlement'
    local templates = LOCATION_TYPES[locType]
    if not templates then templates = LOCATION_TYPES.settlement end
    local tmpl = pick(templates)
    local prefix = Adlib.fillTemplate(tmpl.prefix, LOCATION_FILLS)
    local suffix = Adlib.fillTemplate(tmpl.suffix, LOCATION_FILLS)
    return prefix .. ' ' .. suffix
end

---------------------------------------------------------------------------
-- NPC archetypes (for merchant, quest-giver, wanderer personality)
---------------------------------------------------------------------------

local NPC_ROLES = {
    'merchant', 'scout', 'scavenger', 'deserter', 'survivor', 'bounty_hunter',
    'exile', 'medic', 'wanderer', 'courier', 'prospector',
    'tinker', 'cartographer', 'salvager', 'beast_hunter', 'refugee',
}

local NPC_MOTIVATIONS = {
    'searching for {relative} lost near {place}',
    'mapping safe routes between colony sites',
    'collecting on a Mammona debt from {place}',
    'fleeing {npc_threat}',
    'carrying a sealed drive to {place}',
    'hunting {npc_quarry} for the bounty',
    'looking for shelter before the next storm',
    'looking for work. Any work.',
    'trading {npc_goods} for survival supplies',
    'investigating disappearances near {place}',
    'returning from a failed expedition to {place}',
    'carrying a warning about {npc_threat}',
    'offering data in exchange for protection',
    'trying to forget what happened at {place}',
}

local NPC_DIALOGUE = {
    greeting = {
        -- Tired worker voice (traders, merchants, tinkers)
        'You have walls. That\'s more than the last place.',
        'Three rotations on the outer rim. Each one worse.',
        'Don\'t shoot. I\'m worth more talking.',
        'You the ones running this site? Not bad. Not good either.',
        'Seen worse camps. Seen better ones go dark overnight.',
        -- Spooked survivor voice (scouts, refugees, survivors)
        'You feel it too, right? The ground. It hums.',
        'I walked here from the last site. Took four days. Didn\'t sleep once.',
        'Don\'t ask where I came from. It\'s not there anymore.',
    },
    trade = {
        'I\'ve got {npc_goods}. You need it. I need to not carry it.',
        'Three stations this month. Yours has the best walls.',
        'Everything I carry, I carried through the storm. Prices reflect that.',
        'What\'ve you got? I\'ll trade for anything I can move.',
        'Got TaoTray hot bowls if you\'ve got credits. Or thermal cores. I\'ll take cores.',
        'OmniCorp doesn\'t run this corridor. I do. That\'s why the prices are fair.',
        'StarByte Sunny Fizz. Warm, but it\'s the real thing. Not that GustoGrain paste.',
        'Got ZapNoodles Xtreme. Caffeinated. Don\'t eat more than two in a cycle.',
    },
    warning = {
        'Don\'t go {direction}. Not anymore.',
        'Something is killing the wildlife near {place}. Not eating it. Killing it.',
        'The scavenger crews pulled out of {place}. Wouldn\'t say why.',
        '{place} is gone. Just gone. Structures intact. Nobody home.',
        'The ground hums at night near {place}. The hum has a rhythm.',
        'Don\'t drill past 200 meters. I\'m serious.',
        'The ruins to the south. Stay out. I mean it.',
        'Foras had the same seismic signatures before it fell. Check your readings.',
        'MasTema has retrieval teams in the sector. Don\'t flag yourself.',
        'Black Maw runs this freight corridor now. Go around.',
        'Thalassa Deep is taking prisoners from the outer rim again. Watch your warrants.',
        'Dustweaver swarms are in the area. Assume you\'re being watched.',
    },
    rumor = {
        'They say {place} found a vein of thermal cores. Whole site fought over it.',
        'Mammona pulled a crew off {place} without explanation. Middle of a shift.',
        'Heard the scavengers lost a patrol near {place}. No tracks. No blood.',
        'Someone is building walls around {place}. Walls facing inward.',
        'HERMES broadcast something strange last cycle. Nobody will play it back.',
        'There\'s a bounty on a {npc_quarry} near {place}. Nobody\'s collected yet.',
        'Supply runs are avoiding the route past {place}. No one will say why.',
        'Prior crew left marks on the walls at {place}. Tally marks. Then the marks stop.',
        'Eclipse\'s End is still running on Karnaith. Bet on survivors. Credits or company scrip.',
        'The FortuneGuard pension is invested in every company that works us. Think about that.',
    },
    farewell = {
        'Stay warm. Stay armed. Same thing out here.',
        'If I don\'t come back, it wasn\'t personal.',
        'Keep the reactor lit. Things out there don\'t like heat.',
        'Good luck out there.',
    },
}

local NPC_FILLS = {
    npc_threat = {
        'a creature swarm from the wastes',
        'a MasTema retrieval team',
        'a burrower pack that hit their site',
        'Mammona\'s compliance enforcers',
        'something they refuse to name',
        'raiders from a failed colony',
        'a disease that changes the skin',
        'a Black Maw raiding party',
        'Void Serpent scouts running recon on the sector',
        'Rust Reaver scrappers stripping sites clean',
        'a Vanguard Alliance press gang',
        'something that came out of the warp gate wrong',
        'a Zenith Syndicate hit squad',
        'Dread Corsair privateers',
        'an Iron Shadow Collective cell',
    },
    npc_quarry = {
        'glacier bear', 'alpha tundra wolf', 'rogue frost wurm',
        'a stalker that mimics radio signals', 'an elder burrower',
        'something that leaves no tracks', 'a corrupted crawler',
        'a brood pit escapee', 'something the deep divers stirred up',
    },
    npc_goods = {
        'medical supplies', 'ammunition', 'thermal cores',
        'preserved rations', 'salvaged components', 'insulated hides',
        'survey maps of the surrounding terrain', 'salvaged Mammona hardware',
        'TerraGen medkits', 'Fortune Arms gauss rounds',
        'StarByte ration packs', 'decommissioned neuro-locks',
        'GustoGrain nutriloaf crates', 'NexLink comms modules',
        'ZapFizz ShockPop cases', 'ChocoBlast rations',
        'TaoTray hot bowls', 'Paxtera grain sacks',
        'OmniCorp shipping manifests', 'Dustweaver drone parts',
        'StarByte Sunny Fizz cases', 'StarByte Blast Bites boxes',
        'TaoTray Mystery Shells', 'ZapFizz ZapNoodles Xtreme crates',
    },
}

-- Merge shared fills into NPC fills
for k, v in pairs(BACKSTORY_FILLS) do
    if not NPC_FILLS[k] then NPC_FILLS[k] = v end
end
for k, v in pairs(FLAVOR_FILLS) do
    if not NPC_FILLS[k] then NPC_FILLS[k] = v end
end

function Adlib.generateNPC()
    local role = pick(NPC_ROLES)
    local name = Adlib.fullName()
    local fills = applyPlanetFills(NPC_FILLS)
    local motivation = Adlib.fillTemplate(pick(NPC_MOTIVATIONS), fills)
    local greeting = Adlib.fillTemplate(pick(NPC_DIALOGUE.greeting), fills)
    return {
        name       = name,
        role       = role,
        motivation = motivation,
        greeting   = greeting,
        backstory  = Adlib.generateBackstory(),
        traits     = Adlib.generateTraits(),
    }
end

function Adlib.npcDialogue(category)
    local pool = NPC_DIALOGUE[category]
    if not pool then return nil end
    return Adlib.fillTemplate(pick(pool), applyPlanetFills(NPC_FILLS))
end

function Adlib.npcRumor()
    return Adlib.fillTemplate(pick(NPC_DIALOGUE.rumor), applyPlanetFills(NPC_FILLS))
end

function Adlib.npcWarning()
    return Adlib.fillTemplate(pick(NPC_DIALOGUE.warning), applyPlanetFills(NPC_FILLS))
end

---------------------------------------------------------------------------
-- Quest generation (procedural quest templates)
---------------------------------------------------------------------------

local QUEST_TEMPLATES = {
    hunt = {
        title  = 'Hunt: {quest_target}',
        desc   = 'A {npc_quarry} spotted near {place}. '
              .. 'Kill it before it gets closer.',
        reward = { thermalCores = { 2, 5 }, reputation = { 3, 8 } },
    },
    rescue = {
        title  = 'Rescue: Survivor Near {place}',
        desc   = 'A survivor spotted near {place}. '
              .. 'Won\'t last long out there.',
        reward = { reputation = { 5, 10 }, colonist = true },
    },
    fetch = {
        title  = 'Retrieve: {quest_item} from {place}',
        desc   = 'A {quest_item} was left behind at {place}. '
              .. 'Worth sending someone.',
        reward = { thermalCores = { 1, 3 }, resources = true },
    },
    scout = {
        title  = 'Scout: {place}',
        desc   = 'Investigate reports of {quest_sighting} near {place}. '
              .. 'Report back what you find.',
        reward = { thermalCores = { 1, 2 }, mapReveal = true },
    },
    defend = {
        title  = 'Defend Against {quest_threat}',
        desc   = 'Reports of {quest_threat} heading toward the colony. '
              .. 'Get ready.',
        reward = { thermalCores = { 3, 8 }, reputation = { 5, 12 } },
    },
    investigate = {
        title  = 'Investigate: {quest_mystery}',
        desc   = '{quest_mystery_desc}',
        reward = { thermalCores = { 2, 4 }, knowledge = true },
    },
    escort = {
        title  = 'Escort: {npc_name} to {place}',
        desc   = '{npc_name} needs to get to {place}. '
              .. 'Route goes through hostile ground.',
        reward = { thermalCores = { 3, 6 }, reputation = { 5, 10 } },
    },
    anomaly_investigation = {
        title  = 'Investigate: Anomalous Activity Near {place}',
        desc   = 'Strange readings and markings near {place}. '
              .. 'Find out what\'s causing it.',
        reward = { thermalCores = { 2, 5 }, reputation = { -5, 10 } },
    },
}

local QUEST_FILLS = {
    quest_target = {
        'Rogue Glacier Bear', 'Alpha Wolf Pack', 'Elder Frost Wurm',
        'Corrupted Burrower', 'Alpha Stalker', 'Dire Wolf Alpha',
        'Swarm Broodmother', 'Void-Touched Crawler',
    },
    quest_item = {
        'medical supplies', 'thermal core cache', 'salvaged transponder',
        'research data', 'weapon cache', 'fuel reserves',
        'sealed container of components', 'intact Mammona hardware',
    },
    quest_sighting = {
        'unusual creature activity', 'smoke from an unknown source',
        'lights in the ice', 'structural remains', 'a new crevasse',
        'abandoned equipment', 'distress signals', 'precursor markings',
    },
    quest_threat = {
        'a coordinated wolf pack', 'corrupted fauna from the deep bore',
        'a stalker hunting party', 'a megafauna stampede',
        'MasTema retrieval operatives', 'scavenger raiders',
        'Black Maw boarding party', 'Rust Reaver stripping crew',
        'Vanguard Alliance conscription team',
        'Zenith Syndicate enforcers', 'Dread Corsair raiding party',
    },
    quest_mystery = {
        'The Singing Ice', 'Disappearing Scouts', 'The Black Frost',
        'Lights Below the Glacier', 'The Empty Site',
        'Symbols in the Snow', 'The Silent Herd', 'The Warm Spot',
    },
    quest_mystery_desc = {
        'Colonists report hearing rhythmic pulses from beneath the ice. Getting louder each night.',
        'Three scouts sent to {place} have not returned. No tracks lead back.',
        'A patch of frost has turned black near the colony. Nothing will grow in it.',
        'Lights pulse beneath the glacier at regular intervals. They respond to vibration.',
        'A nearby site has gone completely silent. The structures are intact.',
        'Geometric patterns in the snow. Showing up around the perimeter.',
        'A herd of animals was found standing still, facing the same direction. Alive.',
        'A patch of ground near {place} is warm. Getting warmer each day.',
    },
    npc_name = {
        'Soren Coldwell', 'Kira Deepwell', 'Thane Ashford', 'Petra Rimgate',
        'Voss Steelberg', 'Mira Crestfall', 'Beck Hullbreak', 'Cade Burnside',
    },
}

-- Merge shared fills into quest fills
for k, v in pairs(BACKSTORY_FILLS) do
    if not QUEST_FILLS[k] then QUEST_FILLS[k] = v end
end
for k, v in pairs(NPC_FILLS) do
    if not QUEST_FILLS[k] then QUEST_FILLS[k] = v end
end

function Adlib.generateQuest(questType)
    if not questType then
        local types = {}
        for k in pairs(QUEST_TEMPLATES) do types[#types + 1] = k end
        questType = pick(types)
    end
    local tmpl = QUEST_TEMPLATES[questType]
    if not tmpl then return nil end

    local fills = applyPlanetFills(QUEST_FILLS)
    local title = Adlib.fillTemplate(tmpl.title, fills)
    local desc  = Adlib.fillTemplate(tmpl.desc, fills)

    local reward = {}
    if tmpl.reward.thermalCores then
        reward.thermalCores = tmpl.reward.thermalCores[1]
            + math.random(tmpl.reward.thermalCores[2] - tmpl.reward.thermalCores[1])
    end
    if tmpl.reward.reputation then
        reward.reputation = tmpl.reward.reputation[1]
            + math.random(tmpl.reward.reputation[2] - tmpl.reward.reputation[1])
    end
    reward.colonist  = tmpl.reward.colonist or false
    reward.resources = tmpl.reward.resources or false
    reward.knowledge = tmpl.reward.knowledge or false

    return {
        type   = questType,
        title  = title,
        desc   = desc,
        reward = reward,
    }
end

---------------------------------------------------------------------------
-- Rumor system (colonists share world rumors at meal/campfire)
---------------------------------------------------------------------------

local RUMORS = {
    world = {
        -- Corporate paranoia
        'Mammona knew about this place before they sent us. The surveys are too clean.',
        'HERMES has been logging comms it shouldn\'t have access to.',
        'There were crews here before us. Mammona scrubbed the records.',
        'The contract fine print references "acceptable loss thresholds." For personnel.',
        -- Planetary dread
        'Seismic readings don\'t match any geological model. Patterns repeat.',
        'They say the ice is alive. Not as a figure of speech.',
        -- Old colony echoes
        'The Kennedy brought 500 people to Gaia A^1x. None came home.',
        'Foras fell in 2530. Mammona says it was a mining accident. It wasn\'t.',
        'UTC has a file on something called the Anomalous Biosphere Program. It\'s classified.',
        'Janus still manufactures warp keys. Nobody knows where Janus actually is.',
        'Vanguard Alliance controls half the UTC senate now. Outer rim is low priority.',
        'Automatons on Paxtera stopped responding to commands. Then started again. No one reset them.',
        'Thalassa Deep lost contact for three days last cycle. Warden says it was a drill.',
        'Eclipse\'s End on Karnaith is still running. They\'re broadcasting on black-market WarpNet.',
        'Dustweaver swarms were found outside Karnaith. Nobody knows who deployed them here.',
        'Rhea-2 went dark after something came out of the dunes. Not sand creatures. Bigger.',
        'ShockPop Ultra got pulled from three stations. The amphetamine dosage was tripled.',
        'Solar Nomads on Rhea-2 saw something moving under the sand. Said it had a face.',
        'StarByte crew on Orbit Hub 71 woke up from cryo after 58 years. Galaxy moved on without them.',
        'Tessa Vale is siphoning trade intel through StarByte vending terminals. Nobody watches the vending machines.',
        'Sunny units on three stations went offline at the same time. When they came back, they were different.',
        'TaoTray\'s Bobo AI remembered a customer from twelve years ago. By name. By order. By seat.',
        'Cass Vale cut a deal with a Mammona contractor. His mother doesn\'t know. She will.',
        'MARV-8 kept Orbit Hub 71 running alone for 58 years. Ask yourself what that does to a machine.',
        'They say Warden Dranth answers to something in the deep water beneath Thalassa Deep.',
        'Delta Block flooded on purpose. Morales filed a report. Report disappeared.',
        'The Maw of Foras is still open. Winds come out of it. Sounds like breathing.',
        'Acedia is still standing. Nobody lives there. But the lights come on at night.',
        'Novaris-3 just banned another news outlet. Fourth one this year.',
        'Dustweavers are everywhere on Karnaith. Little metal bugs. They watch everything.',
        'The Cult of the Abyss is not real. That is what Dranth wants you to think.',
    },
    faction = {
        'MasTema has an operative in every crew. Standard practice.',
        'The scavenger crews found something at {place}. They won\'t sell it.',
        'Mammona Logistics has been rerouting supply drops. Nobody approved the change.',
        'The ruin delvers pulled out of the south bore. Wouldn\'t say why.',
        'A rim runner crew went dark near {place}. Their transponder is still pinging.',
        'The salvagers were allies with the prior crew. Then the prior crew disappeared.',
        'Black Maw pirates hit a Mammona supply line near {place}. Took everything.',
        'The Void Serpents have scouts in every system. You don\'t see them. That\'s the point.',
        'Rust Reavers stripped a derelict near {place}. Said the hull was warm.',
        'Fortune Arms is selling gauss rifles to both sides of every conflict in the outer rim.',
        'TerraGen shipped medical supplies to {place}. The supplies had tracking chips.',
        'Zenith Syndicate ran Hyades on Rhea-2 for years. Mammona couldn\'t root them out.',
        'The Dread Corsairs hit an OmniCorp convoy near {place}. Took the crew too.',
        'Iron Shadow Collective has cells in the outer rim. UTC calls them terrorists. Depends who you ask.',
        'Paxtera AgroTech stock went up again. Another colony went hungry to make it happen.',
        'UTCSX traders are shorting Mammona. They know something we don\'t.',
    },
    local_area = {
        'Ground near the drill site is warm. Warmer every day.',
        'Hunters say the animals avoid a {loc_formation} to the {direction}. Smart animals.',
        'Cave system beneath us. You can hear it when the wind stops.',
        'Prior crew left marks on the walls. Tally marks. Then the marks stop.',
        'Drill logs show voids below us. Big ones. Mammona flagged them classified.',
        'Water table is dropping. Or something is absorbing it.',
    },
    creature = {
        'Wolves circle the reactor at night. Not hunting. Watching.',
        'A hunter found tracks circling the colony. Perfect circles.',
        'Megafauna are migrating the wrong direction.',
        'Something killed a glacier bear and left the meat. That\'s not predator behavior.',
        'Burrowing things are going deeper. Like they\'re running from something below them.',
        'Sound at night. Doesn\'t match any creature in the survey logs.',
    },
    ominous = {
        'Three colonists drew the same symbol in their sleep. None remember doing it.',
        'Compasses don\'t work right anymore. They point down.',
        'HERMES broadcast static for six minutes. When it stopped, it said: Acknowledged.',
        'Something in the supply cache aged fifty years overnight. Just the rations. Not the metal.',
        'Deep bore readings come back different each time. Same depth. Same drill.',
        'Shadows falling the wrong direction since last cycle.',
    },
}

local RUMOR_FILLS = {}
for k, v in pairs(BACKSTORY_FILLS) do RUMOR_FILLS[k] = v end
for k, v in pairs(LOCATION_FILLS) do RUMOR_FILLS[k] = v end
for k, v in pairs(FLAVOR_FILLS) do RUMOR_FILLS[k] = v end

function Adlib.generateRumor(category)
    if not category then
        local cats = {}
        for k in pairs(RUMORS) do cats[#cats + 1] = k end
        category = pick(cats)
    end
    local pool = RUMORS[category]
    if not pool then return nil end
    return Adlib.fillTemplate(pick(pool), applyPlanetFills(RUMOR_FILLS))
end

---------------------------------------------------------------------------
-- Faction-specific flavor text
---------------------------------------------------------------------------

local FACTION_FLAVOR = {
    mammona_logistics = {
        greeting = {
            'Mammona Logistics. Your scheduled drop is confirmed.',
            'Quota update. You\'re behind. We can help with that.',
            'Supply chain is tight. Prioritize your requests.',
        },
        hostile = {
            'Mammona Logistics has suspended supply drops to your site. Comply or freeze.',
            'A Mammona compliance team approaches. They are not here to resupply.',
        },
        allied = {
            'Mammona Logistics increases your supply frequency. Quotas adjusted accordingly.',
            'Priority shipments arrive from Logistics. Better equipment. Higher expectations.',
        },
    },
    mastema_ops = {
        greeting = {
            'MasTema Incorporated. We recover assets. You have assets we\'re interested in.',
            'Relax. We\'re here for retrieval, not enforcement. This time.',
            'Your site has flagged data we need. Cooperate and this stays simple.',
        },
        hostile = {
            'MasTema operatives move on the colony. They are not asking.',
            'MasTema has classified your site as non-compliant. Retrieval authorized.',
        },
        allied = {
            'MasTema shares intelligence on hostile activity in your sector.',
            'A MasTema security detail patrols your perimeter. Nothing gets close.',
        },
    },
    scavenger_crews = {
        greeting = {
            'We pick through what Mammona leaves behind. There\'s always something left behind.',
            'Salvage is honest work. More honest than what put it there.',
            'Got parts from {place}. Still good. Interested?',
        },
        hostile = {
            'Scavenger raiders hit from multiple directions. They know your blind spots.',
            'The scavengers have decided your stockpile is easier than digging.',
        },
        allied = {
            'Scavenger scouts share salvage locations with your crews.',
            'The scavengers consider your site a trading post. Parts flow both ways.',
        },
    },
    ruin_delvers = {
        greeting = {
            'We go where the carvings are. You\'ve seen them, right?',
            'Structures under the ice. Older than anything in the UTC record.',
            'We have data from the precursor sites. Your researchers will want this.',
        },
        hostile = {
            'The ruin delvers claim your dig site encroaches on their territory.',
            'Delvers approach in force. Say you broke something irreplaceable.',
        },
        allied = {
            'Ruin delvers share precursor site maps. Your research accelerates.',
            'Delver scouts mark safe paths through the deep bore network.',
        },
    },
    rim_runners = {
        greeting = {
            'No corp tags. No contracts. Just trade.',
            'Independent freight. We go where the credits are.',
            'Fresh route through the storm belt. Your site is on it now.',
        },
        hostile = {
            'Rim runners have blockaded the supply route. Pay the toll or fight.',
            'Independent raiders hit the perimeter. No flags. No negotiation.',
        },
        allied = {
            'Rim runner caravans stop at your site regularly. Trade booms.',
            'Independent scouts share weather data and safe routes.',
        },
    },
    black_maw = {
        greeting = {
            'Black Maw. We take what the corps abandon. Sometimes before they abandon it.',
            'Our fleet controls this corridor. Trade or leave.',
            'You\'re sitting on resources. We\'re sitting on firepower. Let\'s talk.',
        },
        hostile = {
            'Black Maw raiders breach the perimeter. Organized. Professional.',
            'The pirates hit from three directions. They\'ve been watching for days.',
        },
        allied = {
            'Black Maw flags your site as off-limits. Their patrols keep the corridor clear.',
            'Pirate scouts share warp gate schedules. Supply windows open up.',
        },
    },
    void_serpents = {
        greeting = {
            'You didn\'t see us arrive. That\'s normal.',
            'Void Serpents. We trade in information. What do you know?',
            'We were here before you noticed. Don\'t worry about how.',
        },
        hostile = {
            'Systems go dark. Stockpile seals breach. The Void Serpents were already inside.',
            'Supplies vanish overnight. No sign of entry.',
        },
        allied = {
            'Void Serpent intelligence feeds flag threats before they arrive.',
            'The Serpents share MasTema patrol routes. Avoid them or ambush them.',
        },
    },
    rust_reavers = {
        greeting = {
            'Rust Reavers. If it\'s bolted down, we unbolt it.',
            'We strip what the rim leaves behind. Got parts you can\'t get elsewhere.',
            'Scrap from Nemaea. Automaton grade. Interested?',
        },
        hostile = {
            'Rust Reavers swarm the outer walls. They want the hardware, not the crew.',
            'Reavers strip external equipment overnight. They\'ve done this before.',
        },
        allied = {
            'Reaver engineers offer maintenance and repair services. Cheap but effective.',
            'Rust Reaver salvage crews bring rare automaton components.',
        },
    },
    zenith_syndicate = {
        greeting = {
            'Zenith Syndicate. We run this sector now. Cooperate.',
            'You produce. We distribute. That\'s the arrangement.',
            'Protection costs resources. Not having protection costs more.',
        },
        hostile = {
            'Zenith enforcers breach the perimeter. They came to collect.',
            'Syndicate gunners open fire from three positions. Coordinated.',
        },
        allied = {
            'Zenith Syndicate considers your site an asset. Supplies flow in.',
            'Syndicate runners bring food and fuel. The arrangement works both ways.',
        },
    },
    solar_nomads = {
        greeting = {
            'We came from Rhea-2. Long ride. Got food if you\'ve got shelter.',
            'Solar Nomads. We don\'t stay. But we trade while we\'re here.',
            'Crossed three systems to get here. Your walls look solid.',
        },
        hostile = {
            'Nomad riders circle the colony. They\'re not trading this time.',
            'The nomads raid from the perimeter. Fast, mounted, gone before dawn.',
        },
        allied = {
            'Nomad caravans resupply your stores. Regular route now.',
            'Solar Nomad scouts share route data and weather warnings.',
        },
    },
    sons_of_pale_moon = {
        greeting = {
            'We heard the signal. Something\'s active down there. We came to check.',
            'Sons of the Pale Moon. There\'s something under your drill sites. We want access.',
            'The readings match Rhea-2. Something old is down there.',
        },
        hostile = {
            'Pale Moon zealots storm the colony. They want the drill sites.',
            'Robed figures with crescent scars rush the perimeter. No negotiation.',
        },
        allied = {
            'The Sons share thermal core caches they found near the ruins.',
            'Pale Moon priests calm anomaly-sensitive colonists. Morale holds.',
        },
    },
}

function Adlib.factionFlavor(factionId, category)
    local fac = FACTION_FLAVOR[factionId]
    if not fac then return nil end
    local pool = fac[category]
    if not pool then return nil end
    return Adlib.fillTemplate(pick(pool), applyPlanetFills(NPC_FILLS))
end

---------------------------------------------------------------------------
-- More event flavor categories (for storyteller variety)
---------------------------------------------------------------------------

EVENT_FLAVOR.raid = {
    'Scouts report movement on the {direction}. Something is coming.',
    'The perimeter alarm sounds. Shapes in the snow. {adjective} and deliberate.',
    'Not wildlife. Organized. Moving with intent.',
}
EVENT_FLAVOR.rescue = {
    'A shape collapses in the snow just outside the walls.',
    'Scouts find {first_name}, barely alive, half-buried in a drift.',
    'Someone crawling toward the colony. Been at it a while.',
}
EVENT_FLAVOR.trade = {
    'A caravan appears on the horizon. They fly {loc_adj} colors.',
    'Traders approach. Their pack animals are loaded heavy.',
    'A merchant signals from the ridge. They want to deal.',
}
EVENT_FLAVOR.disease = {
    'A colonist coughs. Then another. Then three more.',
    'Black spots appear on stored food. The spores are already in the air.',
    'Something in the water supply. Three colonists are already symptomatic.',
}
EVENT_FLAVOR.construction = {
    'The ground shifts as the foundation settles. Could be fine.',
    'Building materials arrive from the stockpile. The colony grows.',
    'Another wall goes up. Slow work in this cold.',
}
EVENT_FLAVOR.discovery = {
    'Miners break through into a {loc_adj} cavern. The air inside is {adjective}.',
    'Something in the excavated rock. Not ore. Older.',
    'The drill hits a void. Something down there {eldritch_verb}.',
}

EVENT_FLAVOR.taming = {
    'The beast stops struggling. Stares at the handler. Doesn\'t run.',
    'Low growl, then nothing. The creature lowers its head.',
    'The {creature_name} flinches, then leans into the colonist. Close enough.',
    'Hours in the freezing cold. Then it eats from an open hand.',
}
EVENT_FLAVOR.eldritch_node = {
    'The spore pulses. Sinks roots into the stone. It\'s not coming out.',
    'The node {eldritch_verb}. Something inside it is moving.',
    'It grows faster now. The colonists try not to look directly at it.',
    'The {eldritch_adj} growth spread another handspan since morning. Leaking {eldritch_color} fluid.',
    'The meat grows back. Always the same amount. Always in the same shape.',
}
EVENT_FLAVOR.breeding = {
    'New life in the pen. Small, shivering, and hungry.',
    'The animals have bred. More mouths. More meat, eventually.',
    'A {creature_name} kit was born this morning. One more thing to feed.',
}

-- Expose tables for external use
Adlib.QUEST_TEMPLATES = QUEST_TEMPLATES
Adlib.NPC_ROLES = NPC_ROLES
Adlib.RUMORS = RUMORS

return Adlib
