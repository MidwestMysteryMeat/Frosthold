"""
sprite_prompts.py — Parse FROSTHOLD_Art_Assets.md and generate per-asset prompts.

Each asset gets:
  - A positive prompt tuned to its category (tile, creature, building, etc.)
  - Category-specific negative prompt
  - Target output size for downscaling
  - Output filename matching the game's sprite loader convention

Usage:
    from sprite_prompts import build_asset_list
    assets = build_asset_list()  # returns list of AssetEntry dicts
    assets = build_asset_list(categories=["creatures", "buildings"])
"""

import os
import re

ASSETS_MD = os.path.join(os.path.dirname(__file__), "..", "..", "FROSTHOLD_Art_Assets.md")
SPRITES_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")

# ---------------------------------------------------------------------------
# Negative prompts — the core of good pixel art gen
# ---------------------------------------------------------------------------

# Base negatives shared across ALL categories
BASE_NEGATIVE = (
    "blurry, smooth shading, anti-aliased, gradient, soft edges, "
    "3d render, photograph, photorealistic, realistic, "
    "watermark, text, signature, logo, username, "
    "low quality, jpeg artifacts, compression artifacts, "
    "deformed, disfigured, extra limbs, mutated, "
    "out of frame, cropped, worst quality, low resolution"
)

# Category-specific negative additions
CATEGORY_NEGATIVES = {
    "tiles": (
        "character, person, creature, animal, "
        "border, frame, vignette, "
        "non-tileable, seam visible, "
        "isometric, 3d perspective"
    ),
    "creatures": (
        "human, person, humanoid, "
        "background scenery, landscape, "
        "multiple creatures, group, "
        "text label, name tag, UI element"
    ),
    "buildings": (
        "character, person, creature, "
        "outdoor landscape, sky, clouds, "
        "flat 2d, side view, "
        "modern real-world building, skyscraper"
    ),
    "items": (
        "character, person, hand holding, "
        "background scenery, landscape, "
        "large scale, building-sized, "
        "3d perspective, depth of field"
    ),
    "colonists": (
        "animal, creature, monster, "
        "background scenery, landscape, "
        "multiple people, group, "
        "anime face, manga eyes, chibi"
    ),
    "raiders": (
        "animal, creature, monster, "
        "background scenery, landscape, "
        "multiple people, group, "
        "friendly, peaceful, smiling"
    ),
    "defense": (
        "character, person, creature, "
        "outdoor landscape, sky, "
        "modern military, real-world weapon, "
        "flat 2d, no depth"
    ),
    "weapons": (
        "character, person, hand holding, "
        "background scenery, "
        "gun in holster, sheathed, "
        "modern real-world photo"
    ),
    "crops": (
        "character, person, creature, "
        "indoor scene, pot, vase, "
        "bouquet, arrangement, "
        "real photograph"
    ),
    "ui": (
        "character, person, "
        "background scenery, "
        "3d, realistic, photograph, "
        "complex scene, busy"
    ),
    "clothing": (
        "background, scenery, landscape, "
        "person wearing, mannequin, "
        "real fabric, photograph"
    ),
    "effects": (
        "character, person, solid object, "
        "background scenery, "
        "realistic, photograph"
    ),
}

def get_negative(category):
    """Build full negative prompt for a category."""
    extra = CATEGORY_NEGATIVES.get(category, "")
    if extra:
        return f"{extra}, {BASE_NEGATIVE}"
    return BASE_NEGATIVE

# ---------------------------------------------------------------------------
# Positive prompt templates per category
# ---------------------------------------------------------------------------

# Style prefix shared by everything
STYLE_PREFIX = "PIXARFK, pixel art, game sprite, 16-bit style, clean outlines, detailed pixel shading"

# Frosthold's color palette description
PALETTE = "muted palette, dark browns, steel grays, icy blues, warm orange accents"

# Category-specific prompt templates. {name} and {desc} get filled per-asset.
PROMPT_TEMPLATES = {
    "tiles": {
        "prefix": f"{STYLE_PREFIX}, top-down tile texture, seamless tileable, {PALETTE}",
        "template": "{desc} terrain tile, game tileset, top-down view, 32x32 pixel tile",
        "gen_width": 512,
        "gen_height": 512,
        "target_width": 128,
        "target_height": 128,
        "subdir": "tiles",
    },
    "creatures": {
        "prefix": f"{STYLE_PREFIX}, front-facing creature, (transparent background:1.3), centered, {PALETTE}",
        "template": "{desc}, fantasy creature, front view, full body, game enemy sprite",
        "gen_width": 512,
        "gen_height": 640,
        "target_width": 128,
        "target_height": 160,
        "subdir": "creatures",
    },
    "creatures_mega": {
        "prefix": f"{STYLE_PREFIX}, front-facing creature, (transparent background:1.3), centered, epic scale, {PALETTE}",
        "template": "{desc}, massive creature, boss monster, front view, full body, game boss sprite, imposing",
        "gen_width": 640,
        "gen_height": 768,
        "target_width": 192,
        "target_height": 230,
        "subdir": "creatures",
    },
    "buildings": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), three-quarter view, isometric, {PALETTE}",
        "template": "{desc}, game building, colony structure, industrial, survival game, 3/4 top-down view",
        "gen_width": 512,
        "gen_height": 512,
        "target_width": 96,
        "target_height": 112,
        "subdir": "buildings",
    },
    "items": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), centered item, {PALETTE}",
        "template": "{desc}, game item icon, inventory sprite, single object, centered",
        "gen_width": 512,
        "gen_height": 512,
        "target_width": 64,
        "target_height": 64,
        "subdir": "items",
    },
    "colonists": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), front-facing character, {PALETTE}",
        "template": "{desc}, colonist, survival game character, hooded winter clothing, front view, full body",
        "gen_width": 512,
        "gen_height": 640,
        "target_width": 120,
        "target_height": 200,
        "subdir": "colonists",
    },
    "raiders": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), front-facing character, {PALETTE}",
        "template": "{desc}, hostile raider, armed, menacing, post-apocalyptic gear, front view, full body",
        "gen_width": 512,
        "gen_height": 640,
        "target_width": 120,
        "target_height": 200,
        "subdir": "colonists",
    },
    "defense": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), three-quarter view, {PALETTE}",
        "template": "{desc}, defensive structure, military emplacement, survival game, 3/4 top-down view",
        "gen_width": 512,
        "gen_height": 512,
        "target_width": 96,
        "target_height": 96,
        "subdir": "defense",
    },
    "weapons": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), centered weapon, {PALETTE}",
        "template": "{desc}, weapon sprite, game weapon, single item, vertical orientation, detailed",
        "gen_width": 384,
        "gen_height": 640,
        "target_width": 48,
        "target_height": 160,
        "subdir": "weapons",
    },
    "crops": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), top-down view, {PALETTE}",
        "template": "{desc}, farm crop, growing plant, game agriculture sprite",
        "gen_width": 512,
        "gen_height": 512,
        "target_width": 128,
        "target_height": 128,
        "subdir": "crops",
    },
    "ui": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), clean icon, {PALETTE}",
        "template": "{desc}, UI icon, game interface, simple clear symbol, flat icon design",
        "gen_width": 512,
        "gen_height": 512,
        "target_width": 64,
        "target_height": 64,
        "subdir": "ui",
    },
    "clothing": {
        "prefix": f"{STYLE_PREFIX}, (transparent background:1.3), clothing item flat lay, {PALETTE}",
        "template": "{desc}, clothing item, equipment sprite, game armor, flat display",
        "gen_width": 512,
        "gen_height": 512,
        "target_width": 80,
        "target_height": 80,
        "subdir": "items",
    },
}

# ---------------------------------------------------------------------------
# Planet-specific style modifiers
# ---------------------------------------------------------------------------

PLANET_STYLE = {
    "erebus": "frozen tundra, ice and snow, cold blue lighting, arctic",
    "rhea_2": "scorched desert, sand dunes, orange and red, heat haze, arid",
    "morvos": "acid swamp, toxic green, corroded metal, fungal growths, poisonous",
    "nerthus_9": "ocean world, underwater, deep blue, coral, aquatic, bioluminescent",
    "paxtera_prime": "temperate, green fields, warm sunlight, pastoral, earth-like",
    "nemaea": "dead vacuum world, gray regolith, broken machinery, derelict, airless",
    "gaia_a1x": "corrupted paradise, overgrown ruins, eldritch infection, green and purple",
}

# ---------------------------------------------------------------------------
# Creature size tiers → prompt modifiers
# ---------------------------------------------------------------------------

MEGA_CREATURES = {
    "frost_titan", "thermal_wurm", "glacial_leviathan", "ancient_brute",
    "alpha_stalker", "mountain_titan", "ice_colossus", "storm_titan",
    "the_hungering", "the_pale_thing", "that_which_sleeps",
    "desert_colossus", "dune_leviathan", "heat_drake",
    "acid_titan", "the_dissolvent", "mire_colossus",
    "titan_automaton", "the_warden", "dyson_sentinel",
    "the_emergence", "brood_mother",
    "storm_leviathan", "the_depth_mother", "tidal_colossus",
    "territorial_megabear", "great_elk",
    "xenolith_queen",
    "the_thermophage", "iron_carapace", "hive_matron",
}

# ---------------------------------------------------------------------------
# Crop growth stage descriptions
# ---------------------------------------------------------------------------

CROP_STAGES = {
    "seed":    "tiny seed sprout, just planted, barely visible, small seedling emerging from soil",
    "grow":    "growing young plant, medium height, green leaves spreading, half-grown",
    "mature":  "fully grown mature plant, ready to harvest, lush and full, ripe",
    "wilted":  "wilted dead plant, brown and dried, frost-damaged, withered leaves",
}

# ---------------------------------------------------------------------------
# Asset description enrichment
# ---------------------------------------------------------------------------

# Extra description for assets where the name alone isn't enough
ASSET_DESCRIPTIONS = {
    # Tiles
    "void": "empty dark void, black emptiness",
    "snow": "white snow ground, fresh snowfall, arctic terrain",
    "ice": "frozen blue ice surface, cracked glacier, translucent",
    "rock": "gray stone rock, rough hewn, mountain stone",
    "permafrost": "frozen earth, permanent ice mixed with dirt",
    "dirt": "brown dirt ground, bare earth",
    "debris": "scattered rubble and broken materials",
    "fungal_floor": "bioluminescent fungal cave floor, glowing mushrooms",
    "fungal_wall": "thick fungal growth cave wall, pulsing organic matter",
    "membrane_floor": "translucent organic membrane floor, eldritch flesh",
    "membrane_wall": "pulsing organic membrane wall, veins visible",
    "organ_floor": "living organ tissue floor, wet and pulsing",
    "organ_wall": "living organ tissue wall, breathing flesh",
    "growth_creep": "spreading eldritch corruption, dark tendrils on ground",
    "lava_vent": "volcanic vent with glowing lava, molten rock, orange glow",
    "frozen_lake": "large frozen lake surface, deep blue ice",
    "frozen_river": "frozen river with ice, winding frozen water",
    "geyser": "thermal geyser, steam erupting from ground, hot spring vent",
    "hot_spring": "steaming hot spring pool, warm water in frozen ground",

    # Creatures — eldritch
    "the_hungering": "massive eldritch horror, gaping maw, endless teeth, void entity, lovecraftian",
    "the_pale_thing": "ghostly white eldritch creature, eyeless, translucent flesh, horror",
    "that_which_sleeps": "dormant cosmic horror, massive sleeping entity, ancient beyond time",
    "fleshwalker": "shambling mass of fused flesh, multiple limbs, body horror",
    "gore_shoat": "small pig-like creature made of exposed muscle and gore",
    "weeping_calf": "calf-like creature with constantly weeping sores, eldritch livestock",
    "husk_pup": "small canine husk, desiccated, hollow-eyed puppy creature",
    "void_minnow": "tiny void-touched fish creature, dark energy, translucent",
    "pit_wyrm": "underground worm creature, blind, many teeth, burrowing",
    "bile_mold": "living mold organism, dripping bile, slow-moving fungal creature",
    "thorn_polyp": "thorny polyp organism, spiny defensive creature, sessile",
    "nerve_cluster": "pulsing nerve cluster creature, exposed brain tissue, tentacles",
    "rot_bloom": "blooming rot fungus creature, spreading decay, spore cloud",

    # Buildings — key ones
    "steam_hub": "large steam distribution hub, pipes and valves, industrial, Frostpunk-style",
    "cloning_vat": "sci-fi cloning vat, glass tube with green fluid, growing clone inside",
    "radio_beacon": "tall radio antenna tower, broadcasting signal, blinking red light",
    "transmission_array": "massive satellite dish array, end-game communication device",
    "launch_pad": "rocket launch pad, space shuttle platform, end-game escape",
    "shield_generator": "energy shield projector, blue force field dome generator",
    "cryo_pod": "cryogenic stasis pod, frozen person inside, sci-fi",

    # Drugs
    "spike": "crystalline drug syringe, glowing blue stimulant",
    "stardust": "sparkling powder drug, iridescent dust in vial",
    "drift": "smoky sedative drug, calming purple haze in bottle",
    "smog": "dark inhaled drug, black smoke in canister",
    "rotgut": "crude alcohol, brown liquid in crude bottle",
    "shards": "sharp crystalline drug fragments, red glowing crystals",
    "glimpse": "psychic drug, glowing eye-shaped pill, mind-expanding",
    "surge": "combat stimulant, red adrenaline injector",
    "voidbloom": "eldritch flower drug, dark purple petals, otherworldly",
    "fang": "predator extract drug, animal tooth-shaped capsule",

    # Weapons
    "weapon_club": "crude wooden club, blunt weapon",
    "weapon_shiv": "improvised shiv knife, crude blade",
    "weapon_pipe_wrench": "heavy pipe wrench, melee tool-weapon",
    "weapon_torch": "flaming torch, fire on a stick",
    "weapon_knife": "hunting knife, sharp steel blade",
    "weapon_hatchet": "small hatchet, wood-cutting axe",
    "weapon_machete": "long machete blade, jungle knife",
    "weapon_spear": "pointed spear, long wooden shaft with metal tip",
    "weapon_sword": "steel longsword, double-edged blade",
    "weapon_axe": "ice climbing axe, pick-headed axe",
    "weapon_shortbow": "small short bow, simple wooden bow",
    "weapon_bow": "hunting bow, recurve bow with string",
    "weapon_crossbow": "mechanical crossbow, bolt-firing",
    "weapon_revolver": "six-shot revolver handgun",
    "weapon_pistol": "semi-automatic pistol",
    "weapon_sawed_off": "sawed-off double barrel shotgun",
    "weapon_pump_shotgun": "pump-action shotgun",
    "weapon_bolt_action": "bolt-action sniper rifle, long barrel",
    "weapon_assault_rifle": "automatic assault rifle, military",
    "weapon_battle_rifle": "heavy battle rifle, high-caliber",
}


# ---------------------------------------------------------------------------
# Parser: Extract assets from FROSTHOLD_Art_Assets.md
# ---------------------------------------------------------------------------

def _detect_planet(section_title):
    """Guess planet from section title."""
    title_lower = section_title.lower()
    if "erebus" in title_lower or "ice" in title_lower or "frozen" in title_lower:
        return "erebus"
    if "rhea" in title_lower or "desert" in title_lower:
        return "rhea_2"
    if "morvos" in title_lower or "acid" in title_lower:
        return "morvos"
    if "nerthus" in title_lower or "ocean" in title_lower or "underwater" in title_lower:
        return "nerthus_9"
    if "paxtera" in title_lower or "temperate" in title_lower:
        return "paxtera_prime"
    if "nemaea" in title_lower or "vacuum" in title_lower or "automaton" in title_lower:
        return "nemaea"
    if "gaia" in title_lower or "baldrungen" in title_lower:
        return "gaia_a1x"
    return None


def _detect_category(section_stack):
    """Determine asset category from markdown section hierarchy."""
    full = " ".join(section_stack).lower()

    if "tile" in full or "terrain" in full or "biome" in full or "underground" in full:
        return "tiles"
    if "creature" in full or "fauna" in full or "mega" in full or "eldritch" in full:
        if "horror" in full or "livestock" in full:
            return "creatures"
        if "megafauna" in full or "megabeast" in full:
            return "creatures"
        return "creatures"
    if "raider" in full or "humanoid" in full:
        return "raiders"
    if "building" in full or "structural" in full or "heating" in full or "production" in full:
        return "buildings"
    if "turret" in full:
        return "defense"
    if "trap" in full:
        return "defense"
    if "fortification" in full or "cover" in full or "laser fence" in full:
        return "defense"
    if "item" in full or "resource" in full or "material" in full or "food" in full:
        return "items"
    if "medicine" in full or "drug" in full or "organ" in full or "prosthetic" in full:
        return "items"
    if "weapon" in full or "melee" in full or "ranged" in full:
        return "weapons"
    if "throwable" in full or "ammunition" in full or "ordnance" in full or "missile" in full:
        return "items"
    if "crop" in full or "agriculture" in full:
        return "crops"
    if "clothing" in full or "suit" in full:
        return "clothing"
    if "ui" in full or "icon" in full or "planet" in full:
        return "ui"
    if "weather" in full or "effect" in full or "particle" in full:
        return "effects"
    if "power" in full or "generator" in full or "energy" in full:
        return "buildings"
    if "logistics" in full or "conveyor" in full or "pipe" in full or "storage" in full:
        return "buildings"
    if "sensor" in full or "circuit" in full:
        return "buildings"
    if "recreation" in full or "research" in full or "exploration" in full:
        return "buildings"
    if "ventilation" in full or "lighting" in full or "furniture" in full:
        return "buildings"
    if "mining" in full or "drill" in full:
        return "buildings"
    if "infrastructure" in full or "battery" in full or "power grid" in full:
        return "buildings"
    if "egg" in full or "spore" in full or "eldritch" in full or "corpse" in full:
        return "items"
    if "fuel" in full:
        return "items"

    return "items"  # fallback


def _already_exists(subdir, sprite_id):
    """Check if a sprite PNG already exists in assets/sprites/."""
    path = os.path.join(SPRITES_DIR, subdir, f"{sprite_id}.png")
    return os.path.isfile(path)


def parse_assets_md(path=None):
    """Parse FROSTHOLD_Art_Assets.md, return list of raw asset entries."""
    if path is None:
        path = ASSETS_MD

    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    assets = []
    section_stack = []  # [h2, h3] hierarchy
    current_planet = None

    # Regex for table rows: | Done | # | Constant | Name | or | Done | ID | Name |
    # Both formats: with numeric # column or without
    table_re = re.compile(
        r'^\|\s*(?P<done>[^|]*?)\s*\|\s*(?P<col2>[^|]*?)\s*\|\s*(?P<col3>[^|]*?)\s*\|\s*(?P<col4>[^|]*?)\s*\|'
    )
    # Simpler 3-col: | Done | ID | Name |
    table3_re = re.compile(
        r'^\|\s*(?P<done>[^|]*?)\s*\|\s*(?P<id>[^|]*?)\s*\|\s*(?P<name>[^|]*?)\s*\|'
    )

    for line in lines:
        line = line.rstrip()

        # Track section headers
        h2 = re.match(r'^## \d+\.\s+(.+)', line)
        h3 = re.match(r'^### (.+)', line)
        if h2:
            section_stack = [h2.group(1)]
            current_planet = _detect_planet(h2.group(1))
        elif h3:
            title = h3.group(1)
            section_stack = section_stack[:1] + [title]
            planet = _detect_planet(title)
            if planet:
                current_planet = planet

        # Skip header rows and separator rows
        if line.startswith('|') and ('Done' in line or '---' in line):
            continue

        # Try 4-column table (tiles, buildings with numeric IDs)
        m4 = table_re.match(line)
        if m4:
            done = m4.group('done').strip()
            col2 = m4.group('col2').strip()
            col3 = m4.group('col3').strip()
            col4 = m4.group('col4').strip()

            # Determine if col2 is a number (tile enum) or an ID string
            if col2.isdigit():
                # Tiles: | Done | # | CONSTANT | name |
                sprite_id = col3.lower().replace(' ', '_') if not col3.isupper() else col4.lower().replace(' ', '_')
                # Use the constant as the sprite ID for tiles
                sprite_id = col3.lower() if col3.isupper() else col4.lower().replace(' ', '_')
                display_name = col4 if col3.isupper() else col3
            else:
                # | Done | id | Name | extra |
                sprite_id = col2
                display_name = col3
                # col4 might be planet or output info

            if not sprite_id or sprite_id.isdigit():
                continue

            category = _detect_category(section_stack)
            assets.append({
                "id": sprite_id,
                "name": display_name,
                "category": category,
                "section": " > ".join(section_stack),
                "planet": current_planet,
                "done": bool(done.strip()),
            })
            continue

        # Try 3-column table (creatures, items)
        m3 = table3_re.match(line)
        if m3:
            done = m3.group('done').strip()
            sprite_id = m3.group('id').strip()
            display_name = m3.group('name').strip()

            if not sprite_id or sprite_id == '#' or sprite_id == 'ID':
                continue
            if sprite_id.isdigit():
                continue

            category = _detect_category(section_stack)
            assets.append({
                "id": sprite_id,
                "name": display_name,
                "category": category,
                "section": " > ".join(section_stack),
                "planet": current_planet,
                "done": bool(done.strip()),
            })

    return assets


# ---------------------------------------------------------------------------
# Prompt builder
# ---------------------------------------------------------------------------

def build_prompt(asset):
    """Build positive and negative prompts + generation config for an asset."""
    cat = asset["category"]
    sprite_id = asset["id"]
    display_name = asset["name"]
    planet = asset.get("planet")

    # Pick template — mega creatures get bigger canvas
    if cat == "creatures" and sprite_id in MEGA_CREATURES:
        tmpl = PROMPT_TEMPLATES["creatures_mega"]
    elif cat in PROMPT_TEMPLATES:
        tmpl = PROMPT_TEMPLATES[cat]
    else:
        tmpl = PROMPT_TEMPLATES["items"]

    # Build description
    desc = ASSET_DESCRIPTIONS.get(sprite_id, display_name)

    # Planet style modifier
    planet_mod = ""
    if planet and planet in PLANET_STYLE:
        planet_mod = f", {PLANET_STYLE[planet]}"

    # Assemble positive prompt
    subject = tmpl["template"].format(name=sprite_id, desc=desc)
    positive = f"{tmpl['prefix']}{planet_mod}, {subject}"

    # Negative
    negative = get_negative(cat)

    return {
        "id": sprite_id,
        "name": display_name,
        "category": cat,
        "subdir": tmpl["subdir"],
        "planet": planet,
        "positive": positive,
        "negative": negative,
        "gen_width": tmpl["gen_width"],
        "gen_height": tmpl["gen_height"],
        "target_width": tmpl["target_width"],
        "target_height": tmpl["target_height"],
    }


def build_asset_list(categories=None, skip_existing=True, include_crops_stages=True):
    """Parse art list and build full prompt list.

    Args:
        categories: list of category names to include, or None for all
        skip_existing: if True, skip assets that already have a PNG in assets/sprites/
        include_crops_stages: if True, expand each crop into 4 growth stage entries
    """
    raw = parse_assets_md()
    results = []
    seen_ids = set()

    for asset in raw:
        cat = asset["category"]

        # Filter by requested categories
        if categories and cat not in categories:
            continue

        # Deduplicate (same ID can appear in multiple sections like generators)
        if asset["id"] in seen_ids:
            continue
        seen_ids.add(asset["id"])

        # Skip effects/weather — these are particle systems, not sprites
        if cat == "effects":
            continue

        # Handle crops — expand to 4 growth stages
        if cat == "crops" and include_crops_stages:
            for stage, stage_desc in CROP_STAGES.items():
                crop_id = f"{asset['id']}_{stage}"
                if skip_existing and _already_exists("crops", crop_id):
                    continue
                crop_asset = dict(asset)
                crop_asset["id"] = crop_id
                crop_asset["name"] = f"{asset['name']} ({stage})"
                crop_asset["_stage_desc"] = stage_desc
                prompt = build_prompt(crop_asset)
                # Inject growth stage into prompt
                prompt["positive"] = prompt["positive"].replace(
                    "farm crop, growing plant",
                    f"farm crop, {stage_desc}"
                )
                prompt["id"] = crop_id
                results.append(prompt)
            continue

        # Skip existing
        tmpl = PROMPT_TEMPLATES.get(cat, PROMPT_TEMPLATES["items"])
        if skip_existing and _already_exists(tmpl["subdir"], asset["id"]):
            continue

        results.append(build_prompt(asset))

    return results


# ---------------------------------------------------------------------------
# CLI: preview prompts
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Preview sprite generation prompts")
    parser.add_argument("--category", "-c", help="Filter to category (tiles, creatures, buildings, items, etc.)")
    parser.add_argument("--skip-existing", action="store_true", default=True, help="Skip sprites that already exist (default)")
    parser.add_argument("--include-existing", action="store_true", help="Include sprites that already exist")
    parser.add_argument("--id", help="Show prompt for a specific asset ID")
    parser.add_argument("--count", action="store_true", help="Just show counts per category")
    args = parser.parse_args()

    cats = [args.category] if args.category else None
    skip = not args.include_existing

    assets = build_asset_list(categories=cats, skip_existing=skip)

    if args.id:
        for a in assets:
            if a["id"] == args.id:
                print(f"=== {a['id']} ({a['category']}) ===")
                print(f"Name: {a['name']}")
                print(f"Planet: {a.get('planet', 'none')}")
                print(f"Gen size: {a['gen_width']}x{a['gen_height']}")
                print(f"Target size: {a['target_width']}x{a['target_height']}")
                print(f"Output: assets/sprites/{a['subdir']}/{a['id']}.png")
                print(f"\nPOSITIVE:\n{a['positive']}")
                print(f"\nNEGATIVE:\n{a['negative']}")
                break
        else:
            print(f"Asset '{args.id}' not found in filtered list.")
    elif args.count:
        counts = {}
        for a in assets:
            counts[a["category"]] = counts.get(a["category"], 0) + 1
        print(f"{'Category':<15} {'Count':>6}")
        print("-" * 25)
        for cat, n in sorted(counts.items()):
            print(f"{cat:<15} {n:>6}")
        print("-" * 25)
        print(f"{'TOTAL':<15} {sum(counts.values()):>6}")
    else:
        for a in assets:
            print(f"[{a['category']:<12}] {a['id']:<30} → {a['subdir']}/{a['id']}.png  ({a['gen_width']}x{a['gen_height']} → {a['target_width']}x{a['target_height']})")
        print(f"\nTotal: {len(assets)} sprites to generate")
