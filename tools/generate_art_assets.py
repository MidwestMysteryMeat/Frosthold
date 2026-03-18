#!/usr/bin/env python3
"""
generate_art_assets.py — Scans the Frosthold codebase and generates
an updated art asset checklist in Markdown format.

Run from repo root:  python tools/generate_art_assets.py
Output:              FROSTHOLD_Art_Assets.md

Re-run anytime the codebase changes to get an accurate asset list.
"""

import os
import re
import sys
from collections import OrderedDict
from datetime import date

# ---------------------------------------------------------------------------
# Paths (relative to repo root)
# ---------------------------------------------------------------------------
SRC = 'src'
FILES = {
    'tiles':        os.path.join(SRC, 'world', 'tiles.lua'),
    'zones':        os.path.join(SRC, 'world', 'zones.lua'),
    'weather':      os.path.join(SRC, 'weather', 'weather.lua'),
    'creatures':    os.path.join(SRC, 'creatures', 'creatures.lua'),
    'bosses':       os.path.join(SRC, 'creatures', 'bosses.lua'),
    'lairs':        os.path.join(SRC, 'creatures', 'lairs.lua'),
    'megabeasts':   os.path.join(SRC, 'creatures', 'megabeasts.lua'),
    'raiders':      os.path.join(SRC, 'creatures', 'raiders.lua'),
    'eldritch':     os.path.join(SRC, 'creatures', 'eldritch_nodes.lua'),
    'building':     os.path.join(SRC, 'building', 'building.lua'),
    'production':   os.path.join(SRC, 'building', 'production.lua'),
    'agriculture':  os.path.join(SRC, 'building', 'agriculture.lua'),
    'decorations':  os.path.join(SRC, 'building', 'decorations.lua'),
    'defenses':     os.path.join(SRC, 'combat', 'defenses.lua'),
    'traps':        os.path.join(SRC, 'combat', 'traps.lua'),
    'ordnance':     os.path.join(SRC, 'combat', 'ordnance.lua'),
    'body':         os.path.join(SRC, 'combat', 'body.lua'),
    'equipment':    os.path.join(SRC, 'colonist', 'equipment.lua'),
    'addiction':    os.path.join(SRC, 'colonist', 'addiction.lua'),
    'suits':        os.path.join(SRC, 'colonist', 'suits.lua'),
    'disease':      os.path.join(SRC, 'sim', 'disease.lua'),
    'mental':       os.path.join(SRC, 'colonist', 'mental_breaks.lua'),
    'policies':     os.path.join(SRC, 'colony', 'policies.lua'),
    'merchants':    os.path.join(SRC, 'trade', 'merchants.lua'),
    'pipe_defs':    os.path.join(SRC, 'logistics', 'pipe_defs.lua'),
    'research':     os.path.join(SRC, 'research', 'research.lua'),
    'overworld':    os.path.join(SRC, 'exploration', 'overworld.lua'),
    'endgame':      os.path.join(SRC, 'sim', 'endgame.lua'),
}


def read_file(path):
    """Read a Lua file, return contents or empty string if missing."""
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            return f.read()
    except FileNotFoundError:
        print(f"  WARN: {path} not found, skipping")
        return ''


# ---------------------------------------------------------------------------
# Extraction helpers
# ---------------------------------------------------------------------------

def extract_constants(text, pattern):
    """Extract NAME = number constants."""
    return re.findall(pattern, text)


def extract_table_keys(text, table_name):
    """Extract top-level keys from 'local TABLE = { key = {' — depth-aware."""
    keys = []
    # Match 'local TABLE = {' or 'Module.TABLE = {' or just 'TABLE = {'
    table_start = re.search(rf'(?:local\s+|(?:\w+\.))?{table_name}\s*=\s*\{{', text)
    if not table_start:
        return keys

    # Walk character-by-character tracking brace depth
    # Only capture 'key = {' when depth == 1 (directly inside the parent table)
    depth = 1
    pos = table_start.end()
    while pos < len(text) and depth > 0:
        # Skip string literals
        if text[pos] in ("'", '"'):
            quote = text[pos]
            pos += 1
            while pos < len(text) and text[pos] != quote:
                if text[pos] == '\\':
                    pos += 1
                pos += 1
            pos += 1
            continue
        # Skip line comments
        if text[pos:pos+2] == '--':
            nl = text.find('\n', pos)
            pos = nl + 1 if nl >= 0 else len(text)
            continue

        if text[pos] == '{':
            depth += 1
        elif text[pos] == '}':
            depth -= 1

        # At depth 1, look for 'key = {' pattern starting at current line
        if depth == 2 and text[pos] == '{':
            # We just entered depth 2 — look backwards for 'key ='
            line_start = text.rfind('\n', 0, pos) + 1
            before = text[line_start:pos].strip()
            m = re.match(r'^(\w+)\s*=\s*$', before)
            if m:
                keys.append(m.group(1))

        pos += 1
    return keys


def extract_dot_keys(text, table_var):
    """Extract keys from 'TABLE.key = {' pattern."""
    return re.findall(rf'{table_var}\.(\w+)\s*=\s*\{{', text)


def extract_field(text, key, field):
    """Extract a string field value from a table entry: key = { ... field = 'value' ... }"""
    # Find the entry
    entry_match = re.search(rf'{key}\s*=\s*\{{', text)
    if not entry_match:
        return None
    pos = entry_match.end()
    brace_depth = 1
    while pos < len(text) and brace_depth > 0:
        if text[pos] == '{':
            brace_depth += 1
        elif text[pos] == '}':
            brace_depth -= 1
        pos += 1
    block = text[entry_match.start():pos]
    m = re.search(rf"{field}\s*=\s*'([^']*)'", block)
    if m:
        return m.group(1)
    m = re.search(rf'{field}\s*=\s*"([^"]*)"', block)
    if m:
        return m.group(1)
    return None


def extract_number_field(text, key, field):
    """Extract a numeric field value from a table entry."""
    entry_match = re.search(rf'{key}\s*=\s*\{{', text)
    if not entry_match:
        return None
    pos = entry_match.end()
    brace_depth = 1
    while pos < len(text) and brace_depth > 0:
        if text[pos] == '{':
            brace_depth += 1
        elif text[pos] == '}':
            brace_depth -= 1
        pos += 1
    block = text[entry_match.start():pos]
    m = re.search(rf'{field}\s*=\s*([\d.]+)', block)
    if m:
        return float(m.group(1))
    return None


def extract_entries_with_fields(text, table_name, fields):
    """Extract top-level table keys and specified fields — depth-aware."""
    results = []
    # Match 'local TABLE = {' or 'Module.TABLE = {' or just 'TABLE = {'
    table_start = re.search(rf'(?:local\s+|(?:\w+\.))?{table_name}\s*=\s*\{{', text)
    if not table_start:
        return results

    # Walk through the table tracking depth, collect top-level entry positions
    entries = []  # list of (key, entry_start, entry_end)
    depth = 1
    pos = table_start.end()
    while pos < len(text) and depth > 0:
        # Skip string literals
        if text[pos] in ("'", '"'):
            quote = text[pos]
            pos += 1
            while pos < len(text) and text[pos] != quote:
                if text[pos] == '\\':
                    pos += 1
                pos += 1
            pos += 1
            continue
        # Skip line comments
        if text[pos:pos+2] == '--':
            nl = text.find('\n', pos)
            pos = nl + 1 if nl >= 0 else len(text)
            continue

        if text[pos] == '{':
            depth += 1
            if depth == 2:
                # Entering a top-level entry — look back for key name
                line_start = text.rfind('\n', 0, pos) + 1
                before = text[line_start:pos].strip()
                m = re.match(r'^(\w+)\s*=\s*$', before)
                if m:
                    entry_key = m.group(1)
                    entry_content_start = pos + 1
                    # Find the matching close brace
                    edepth = 1
                    epos = entry_content_start
                    while epos < len(text) and edepth > 0:
                        if text[epos] in ("'", '"'):
                            eq = text[epos]
                            epos += 1
                            while epos < len(text) and text[epos] != eq:
                                if text[epos] == '\\':
                                    epos += 1
                                epos += 1
                            epos += 1
                            continue
                        if text[epos:epos+2] == '--':
                            enl = text.find('\n', epos)
                            epos = enl + 1 if enl >= 0 else len(text)
                            continue
                        if text[epos] == '{':
                            edepth += 1
                        elif text[epos] == '}':
                            edepth -= 1
                        epos += 1
                    entries.append((entry_key, pos, epos))
                    pos = epos
                    depth = 1  # back at parent table level
                    continue
        elif text[pos] == '}':
            depth -= 1

        pos += 1

    # Extract fields from each entry block
    for key, start, end in entries:
        entry_block = text[start:end]
        entry = {'id': key}
        for f in fields:
            sm = re.search(rf"{f}\s*=\s*'([^']*)'", entry_block)
            if sm:
                entry[f] = sm.group(1)
            else:
                sm = re.search(rf'{f}\s*=\s*"([^"]*)"', entry_block)
                if sm:
                    entry[f] = sm.group(1)
                else:
                    sm = re.search(rf'{f}\s*=\s*([\d.]+)', entry_block)
                    if sm:
                        entry[f] = sm.group(1)
                    else:
                        sm = re.search(rf'{f}\s*=\s*(true|false)', entry_block)
                        if sm:
                            entry[f] = sm.group(1)
        results.append(entry)
    return results


def extract_array_field(text, table_name, field):
    """Extract a field from entries in an array-style table."""
    results = []
    # Match 'local TABLE = {' or 'Module.TABLE = {' or just 'TABLE = {'
    table_start = re.search(rf'(?:local\s+|(?:\w+\.))?{table_name}\s*=\s*\{{', text)
    if not table_start:
        return results
    brace_depth = 1
    pos = table_start.end()
    while pos < len(text) and brace_depth > 0:
        if text[pos] == '{':
            brace_depth += 1
        elif text[pos] == '}':
            brace_depth -= 1
        pos += 1
    block = text[table_start.start():pos]
    for m in re.finditer(rf"{field}\s*=\s*'([^']*)'", block):
        results.append(m.group(1))
    return results


# ---------------------------------------------------------------------------
# Section generators
# ---------------------------------------------------------------------------

def section_tiles(text):
    """Extract tile definitions from Tiles.NAME = number pattern."""
    consts = re.findall(r'Tiles\.(\w+)\s*=\s*(\d+)', text)
    tiles = [(name, int(num)) for name, num in consts
             if name.isupper() and not name.startswith('_')]
    tiles.sort(key=lambda x: x[1])
    return tiles


def categorize_tiles(tiles):
    """Group tiles into categories."""
    categories = OrderedDict()
    categories['Natural Terrain'] = []
    categories['Floors'] = []
    categories['Walls'] = []
    categories['Doors'] = []
    categories['Natural Resources'] = []
    categories['Underground'] = []
    categories['Biological'] = []
    categories['Special'] = []

    for name, tid in tiles:
        nl = name.lower()
        if nl in ('void', 'snow', 'ice', 'rock', 'permafrost', 'dirt', 'debris'):
            categories['Natural Terrain'].append((name, tid))
        elif 'floor' in nl or nl == 'growth_creep':
            if 'fungal' in nl or 'membrane' in nl or 'organ' in nl or 'growth' in nl:
                categories['Biological'].append((name, tid))
            elif 'underground' in nl:
                categories['Underground'].append((name, tid))
            else:
                categories['Floors'].append((name, tid))
        elif 'wall' in nl or 'column' in nl:
            if 'fungal' in nl or 'membrane' in nl or 'organ' in nl:
                categories['Biological'].append((name, tid))
            elif 'underground' in nl or 'support' in nl or 'reinforced' in nl:
                categories['Underground'].append((name, tid))
            else:
                categories['Walls'].append((name, tid))
        elif 'door' in nl:
            categories['Doors'].append((name, tid))
        elif nl in ('tree', 'ore_vein'):
            categories['Natural Resources'].append((name, tid))
        elif nl in ('water', 'lava_vent'):
            categories['Special'].append((name, tid))
        elif nl in ('deep_rock', 'shaft_entrance'):
            categories['Underground'].append((name, tid))
        else:
            categories['Special'].append((name, tid))

    return categories


def categorize_buildings(entries):
    """Categorize building definitions by their properties."""
    cats = OrderedDict()
    cats['Structural'] = []
    cats['Heating & Thermal'] = []
    cats['Ventilation'] = []
    cats['Lighting'] = []
    cats['Furniture'] = []
    cats['Decorations'] = []
    cats['Production Machines'] = []
    cats['Power Generation'] = []
    cats['Power Infrastructure'] = []
    cats['Logistics: Conveyors'] = []
    cats['Logistics: Inserters'] = []
    cats['Logistics: Pipes & Ducts'] = []
    cats['Logistics: Tanks'] = []
    cats['Logistics: Processors'] = []
    cats['Colony Growth'] = []
    cats['Research & Exploration'] = []
    cats['Turrets'] = []
    cats['Traps'] = []
    cats['Fortifications & Cover'] = []
    cats['Laser Fences & Barriers'] = []
    cats['Sensors'] = []
    cats['Special Defense'] = []
    cats['Endgame'] = []
    cats['Missiles & Heavy Ordnance'] = []
    cats['Medical'] = []
    cats['Other'] = []

    for e in entries:
        eid = e['id']
        es = e.get('entitySpawn', '')
        cat = e.get('category', '')

        if 'turret' in eid or es == 'turret':
            cats['Turrets'].append(e)
        elif '_trap' in eid or 'mine' in eid or es == 'trap':
            cats['Traps'].append(e)
        elif eid in ('wall_wood', 'wall_stone', 'wall_insulated', 'floor_wood',
                      'floor_stone', 'floor_insulated', 'door', 'door_sealed',
                      'reinforced_column', 'support_column', 'wood_column'):
            cats['Structural'].append(e)
        elif eid in ('campfire', 'heater', 'steam_hub'):
            cats['Heating & Thermal'].append(e)
        elif eid in ('air_intake', 'air_exhaust', 'air_purifier', 'scrubber'):
            cats['Ventilation'].append(e)
        elif eid in ('torch', 'standing_lamp', 'sun_lamp'):
            cats['Lighting'].append(e)
        elif eid in ('bed', 'memorial', 'farm_plot', 'greenhouse'):
            cats['Furniture'].append(e)
        elif eid in ('shelf', 'rug', 'painting', 'trophy_mount'):
            cats['Decorations'].append(e)
        elif eid in ('sawmill', 'smelter', 'forge', 'workbench', 'kitchen', 'loom',
                      'tannery', 'smokehouse', 'drug_lab', 'refinery', 'butcher_table',
                      'kiln', 'oil_refinery', 'med_bench', 'vehicle_workbench'):
            cats['Production Machines'].append(e)
        elif eid in ('deep_drill', 'research_bench'):
            cats['Research & Exploration'].append(e)
        elif eid in ('surgery_table',):
            cats['Medical'].append(e)
        elif any(x in eid for x in ('fire_pit', 'deep_fire_pit', 'coal_burner', 'gas_burner',
                                     'hand_crank', 'treadmill', 'chain_gang', 'solar_panel',
                                     'wind_turbine', 'thermopile', 'bio_reactor', 'mini_reactor',
                                     'nuclear_reactor', 'chemical_burner', 'ichor_burner',
                                     'waste_incinerator', 'geothermal', 'steam_turbine',
                                     'hydrogen_cell', 'lightning_rod', 'dynamo', 'stirling',
                                     'penrose', 'peat_burner', 'plasma_arc', 'fusion',
                                     'eldritch_accumulator', 'lava_tap', 'reactor_gen',
                                     'cryo_kinetic', 'thermal_gen')):
            cats['Power Generation'].append(e)
        elif any(x in eid for x in ('battery', 'capacitor', 'thermal_battery', 'power_conduit',
                                     'power_switch', 'transmission')):
            cats['Power Infrastructure'].append(e)
        elif eid in ('conveyor', 'splitter'):
            cats['Logistics: Conveyors'].append(e)
        elif 'inserter' in eid:
            cats['Logistics: Inserters'].append(e)
        elif any(x in eid for x in ('pipe', 'duct')) and 'pipe_bomb' not in eid:
            cats['Logistics: Pipes & Ducts'].append(e)
        elif 'tank' in eid or eid == 'gas_canister':
            cats['Logistics: Tanks'].append(e)
        elif eid in ('water_pump', 'sump_pump', 'coolant_refiner', 'ichor_converter',
                      'gas_separator', 'steam_boiler', 'waste_processor', 'methane_digester'):
            cats['Logistics: Processors'].append(e)
        elif eid in ('cloning_vat', 'radio_beacon'):
            cats['Colony Growth'].append(e)
        elif eid in ('quest_board', 'expedition_table', 'cryo_pod', 'cryo_cell'):
            cats['Research & Exploration'].append(e)
        elif any(x in eid for x in ('sandbag', 'barricade', 'steel_barrier', 'bunker',
                                     'razor_wire')):
            cats['Fortifications & Cover'].append(e)
        elif any(x in eid for x in ('laser_gate', 'laser_fence', 'laser_grid',
                                     'electrified_wall', 'shield_curtain')):
            cats['Laser Fences & Barriers'].append(e)
        elif 'sensor' in eid:
            cats['Sensors'].append(e)
        elif eid in ('watchtower', 'shield_generator'):
            cats['Special Defense'].append(e)
        elif any(x in eid for x in ('launch_pad', 'sealing_apparatus', 'transmission_array')):
            cats['Endgame'].append(e)
        elif any(x in eid for x in ('missile', 'sam_launcher', 'rocket_pod')):
            cats['Missiles & Heavy Ordnance'].append(e)
        elif eid in ('comparator', 'actuator'):
            cats['Logistics: Conveyors'].append(e)
        else:
            cats['Other'].append(e)

    # Remove empty categories
    return OrderedDict((k, v) for k, v in cats.items() if v)


def categorize_items(entries):
    """Categorize item definitions."""
    cats = OrderedDict()
    cats['Raw Resources'] = []
    cats['Processed Materials'] = []
    cats['Advanced Materials'] = []
    cats['Food'] = []
    cats['Medicine'] = []
    cats['Drugs'] = []
    cats['Organs'] = []
    cats['Prosthetics & Bionics'] = []
    cats['Melee Weapons'] = []
    cats['Ranged Weapons'] = []
    cats['Throwables'] = []
    cats['Ammunition'] = []
    cats['Ordnance'] = []
    cats['Missiles'] = []
    cats['Eldritch Eggs & Spores'] = []
    cats['Eldritch Resources'] = []
    cats['Corpses & Dark Products'] = []
    cats['Boss Drops'] = []
    cats['Equipment Overlays'] = []
    cats['Fuel & Power'] = []
    cats['Misc'] = []

    for e in entries:
        eid = e['id']
        cat = e.get('category', '')

        if cat == 'raw' or eid in ('raw_wood', 'raw_stone', 'raw_ore', 'raw_ice', 'raw_meat',
                                     'raw_hide', 'thermal_core', 'plant_fiber', 'coal',
                                     'berries', 'mushrooms', 'medicinal_herb'):
            cats['Raw Resources'].append(e)
        elif eid in ('lumber', 'cut_stone', 'metal_ingot', 'leather', 'cloth', 'water',
                      'charcoal'):
            cats['Processed Materials'].append(e)
        elif eid in ('steel', 'components', 'circuit', 'insulation', 'pipe', 'glass'):
            cats['Advanced Materials'].append(e)
        elif eid in ('cooked_meat', 'stew', 'jerky', 'bread', 'ration', 'feast'):
            cats['Food'].append(e)
        elif eid in ('bandage', 'medicine', 'thaw'):
            cats['Medicine'].append(e)
        elif eid in ('spike', 'stardust', 'drift', 'smog', 'rotgut', 'shards', 'glimpse',
                      'surge', 'voidbloom', 'fang', 'psychoid_leaf', 'smokeleaf_leaf', 'hops'):
            cats['Drugs'].append(e)
        elif 'organ_' in eid:
            cats['Organs'].append(e)
        elif any(x in eid for x in ('peg_leg', 'wooden_arm', 'prosthetic_', 'bionic_')):
            cats['Prosthetics & Bionics'].append(e)
        elif eid.startswith('weapon_') and eid in ('weapon_club', 'weapon_shiv',
                'weapon_pipe_wrench', 'weapon_torch', 'weapon_knife', 'weapon_hatchet',
                'weapon_machete', 'weapon_spear', 'weapon_sword', 'weapon_axe'):
            cats['Melee Weapons'].append(e)
        elif eid.startswith('weapon_'):
            cats['Ranged Weapons'].append(e)
        elif eid in ('grenade', 'ied', 'molotov', 'pipe_bomb'):
            cats['Throwables'].append(e)
        elif eid.startswith('ammo_') or eid in ('napalm_fuel', 'foam_canister', 'gas_canister',
                                                  'acid_canister', 'poison_darts'):
            cats['Ammunition'].append(e)
        elif any(x in eid for x in ('_charge', '_bomb', 'briefcase_nuke', 'nuclear_core',
                                     'napalm_grenade', 'bio_grenade', 'foam_grenade',
                                     'emp_grenade', 'emp_charge')):
            cats['Ordnance'].append(e)
        elif eid.startswith('missile_'):
            cats['Missiles'].append(e)
        elif any(x in eid for x in ('_egg', 'spore_')):
            cats['Eldritch Eggs & Spores'].append(e)
        elif eid in ('eldritch_ichor', 'raw_fat', 'chitin_plate', 'void_crystal',
                      'raw_fur', 'caustic_liquid', 'serpent_venom'):
            cats['Eldritch Resources'].append(e)
        elif eid in ('corpse_creature', 'corpse_human', 'human_meat', 'human_leather'):
            cats['Corpses & Dark Products'].append(e)
        elif any(x in eid for x in ('titan_heart', 'leviathan_core', 'void_heart',
                                     'wurm_scale', 'godstone', 'stalker_skull',
                                     'titan_spine', 'giant_crown')):
            cats['Boss Drops'].append(e)
        elif eid in ('parka', 'boots', 'hide_coat', 'leather_armor', 'metal_plate',
                      'warm_scarf', 'lucky_charm', 'medkit_pouch', 'scope',
                      'thermal_suit', 'exosuit'):
            cats['Equipment Overlays'].append(e)
        elif eid == 'fuel_cell':
            cats['Fuel & Power'].append(e)
        else:
            cats['Misc'].append(e)

    return OrderedDict((k, v) for k, v in cats.items() if v)


# ---------------------------------------------------------------------------
# Sprite reuse logic
# ---------------------------------------------------------------------------

SPRITE_FAMILIES = {
    # Creatures
    'Wolf family': ['tundra_wolf', 'dire_wolf'],
    'Primate family': ['snow_ape', 'ice_brute'],
    'Stalker family': ['stalker', 'shade', 'alpha_stalker'],
    'Titan family': ['frost_titan', 'mountain_titan', 'ice_colossus', 'storm_titan'],
    'Bug family': ['frost_beetle', 'skitterer', 'ice_locust'],
    'Blob family': ['bile_mold', 'rot_bloom'],
    'Polyp family': ['thorn_polyp', 'nerve_cluster'],

    # Buildings
    'Wall material': ['wall_wood', 'wall_stone', 'wall_metal', 'wall_insulated'],
    'Floor material': ['floor_wood', 'floor_stone', 'floor_metal', 'floor_insulated'],
    'Vent family': ['air_intake', 'air_exhaust', 'air_purifier'],
    'Furnace family': ['smelter', 'forge', 'refinery'],
    'Counter family': ['kitchen', 'smokehouse', 'butcher_table'],
    'Table family': ['workbench', 'loom', 'tannery'],
    'Fire pit family': ['fire_pit', 'deep_fire_pit', 'coal_burner', 'gas_burner'],
    'Wheel family': ['hand_crank', 'treadmill', 'chain_gang_wheel'],
    'Reactor family': ['bio_reactor', 'mini_reactor', 'nuclear_reactor'],
    'Burner family': ['chemical_burner', 'ichor_burner', 'waste_incinerator'],
    'Inserter color': ['basic_inserter', 'fast_inserter', 'filter_inserter'],
    'Pipe base': ['small_pipe', 'large_pipe', 'insulated_pipe'],
    'Duct base': ['small_duct', 'large_duct', 'sealed_duct'],
    'Cover progression': ['sandbag', 'barricade', 'steel_barrier', 'bunker'],
    'Mine family': ['tripwire_ied', 'claymore', 'frag_mine'],

    # Items
    'Rock pile family': ['raw_stone', 'raw_ore', 'coal'],
    'Plant bundle family': ['plant_fiber', 'berries', 'mushrooms', 'medicinal_herb'],
    'Block stack family': ['lumber', 'cut_stone', 'metal_ingot', 'charcoal'],
    'Parts pile family': ['steel', 'components', 'circuit', 'pipe'],
    'Bowl family': ['stew', 'feast'],
    'Drug pouch family': ['spike', 'stardust', 'shards'],
    'Drug bottle family': ['drift', 'smog', 'rotgut', 'surge'],
    'Blade family': ['weapon_knife', 'weapon_machete', 'weapon_sword'],
    'Bow family': ['weapon_shortbow', 'weapon_bow', 'weapon_crossbow'],
    'Pistol family': ['weapon_revolver', 'weapon_pistol'],
    'Shotgun family': ['weapon_sawed_off', 'weapon_pump_shotgun'],
    'Rifle family': ['weapon_bolt_action', 'weapon_assault_rifle', 'weapon_battle_rifle'],
    'Arrow family': ['ammo_arrow', 'ammo_fire_arrow', 'ammo_bolt'],
    'Egg family': ['flesh_egg', 'ichor_egg', 'chitin_egg', 'void_egg', 'wyrm_egg'],
    'Spore family': ['spore_bile', 'spore_thorn', 'spore_nerve', 'spore_rot'],
    'Vial family': ['eldritch_ichor', 'caustic_liquid', 'serpent_venom'],
    'Organ jar family': ['organ_heart', 'organ_lung', 'organ_kidney', 'organ_liver', 'organ_eye'],
    'Limb tier family': ['peg_leg/prosthetic_leg/bionic_leg', 'wooden_arm/prosthetic_arm/bionic_arm'],
}


def count_unique_sprites(items, families):
    """Estimate unique base sprites needed after family reuse."""
    all_family_members = set()
    for members in families.values():
        for m in members:
            for sub in m.split('/'):
                all_family_members.add(sub)

    unique = 0
    family_bases = 0
    recolors = 0
    for item in items:
        iid = item if isinstance(item, str) else item.get('id', '')
        if iid in all_family_members:
            # Check if it's the first member of any family (= base sprite)
            for members in families.values():
                flat = []
                for m in members:
                    flat.extend(m.split('/'))
                if iid in flat:
                    if iid == flat[0]:
                        family_bases += 1
                    else:
                        recolors += 1
                    break
        else:
            unique += 1

    return unique + family_bases, recolors


# ---------------------------------------------------------------------------
# Main generator
# ---------------------------------------------------------------------------

def generate():
    # Find repo root
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    os.chdir(repo_root)

    print("Scanning Frosthold codebase for art assets...")

    # Read all files
    data = {}
    for key, path in FILES.items():
        data[key] = read_file(path)
        if data[key]:
            print(f"  OK: {path}")

    out = []
    total_items = 0
    total_base_sprites = 0

    def w(line=''):
        out.append(line)

    # -----------------------------------------------------------------------
    # Header
    # -----------------------------------------------------------------------
    w('# FROSTHOLD — Art Asset Checklist')
    w()
    w('**Frostpunk x RimWorld Colony Survival Sim**')
    w(f'**Love2D 11.4 | 32px tiles | 1280x720**')
    w(f'**Auto-generated: {date.today().isoformat()}**')
    w()
    w('> This document is auto-generated by `tools/generate_art_assets.py`.')
    w('> Re-run anytime the codebase changes: `python tools/generate_art_assets.py`')
    w()

    # -----------------------------------------------------------------------
    # 1. TILES & TERRAIN
    # -----------------------------------------------------------------------
    w('---')
    w('## 1. TILES & TERRAIN')
    w()
    tiles = section_tiles(data['tiles'])
    tile_cats = categorize_tiles(tiles)
    for cat_name, cat_tiles in tile_cats.items():
        if not cat_tiles:
            continue
        w(f'### {cat_name} ({len(cat_tiles)})')
        w()
        w('| Done | # | Constant | Name |')
        w('|------|---|----------|------|')
        for name, tid in cat_tiles:
            # Pull human-readable name from Tiles.props if available
            prop_name = extract_field(data['tiles'], rf'\[Tiles\.{name}\]', 'name')
            display = prop_name if prop_name else name.lower().replace('_', ' ')
            w(f'| | {tid} | {name} | {display} |')
        w()

    tile_count = len(tiles)
    tile_sprites = max(tile_count - 8, tile_count)  # rough estimate
    total_items += tile_count
    w(f'**Tiles total: {tile_count} items**')
    w()

    # Zone overlays
    zone_keys = extract_table_keys(data['zones'], 'ZONE_TYPES') if data['zones'] else []
    if not zone_keys:
        zone_keys = re.findall(r"type\s*==\s*'(\w+)'", data['zones']) if data['zones'] else []
        zone_keys = list(set(zone_keys))
    if not zone_keys:
        zone_keys = ['stockpile', 'dumping', 'restricted']
    w(f'### Zone Overlays ({len(zone_keys)})')
    w('> SPRITE TIP: 1 crosshatch pattern, tint per zone color.')
    w()
    for z in zone_keys:
        w(f'- {z}')
    w()
    total_items += len(zone_keys)

    # -----------------------------------------------------------------------
    # 2. COLONISTS
    # -----------------------------------------------------------------------
    w('---')
    w('## 2. COLONISTS')
    w()
    w('### Base Model (1 model, multiple anim states)')
    w('- Idle, Walking (4-dir), Working, Sleeping, Injured/Downed, Dead/Corpse')
    w()

    # Hypothermia stages
    w('### Hypothermia Stages (5) — tint ramp, NOT separate sprites')
    w('| Stage | Warmth | Tint |')
    w('|-------|--------|------|')
    w('| normal | >= 60 | No tint |')
    w('| chilled | >= 40 | 5% blue |')
    w('| cold | >= 20 | 15% blue |')
    w('| hypothermic | >= 10 | 30% blue + frost overlay |')
    w('| severe | < 10 | 50% blue + heavy frost |')
    w()

    # Equipment overlays from equipment.lua
    equip = data['equipment']
    weapons_melee = extract_table_keys(equip, 'MELEE_WEAPONS') if equip else []
    weapons_ranged = extract_table_keys(equip, 'RANGED_WEAPONS') if equip else []
    armors = extract_table_keys(equip, 'ARMORS') if equip else []
    accessories = extract_table_keys(equip, 'ACCESSORIES') if equip else []

    if not weapons_melee:
        weapons_melee = re.findall(r"WEAPONS\[?'?(\w+)'?\]?\s*=\s*\{[^}]*type\s*=\s*'melee'", equip)
    if not weapons_ranged:
        weapons_ranged = re.findall(r"WEAPONS\[?'?(\w+)'?\]?\s*=\s*\{[^}]*type\s*=\s*'ranged'", equip)

    w('### Equipment Overlay Layers')
    w()

    # Suits
    suit_keys = extract_table_keys(data['suits'], 'SUIT_DEFS') if data['suits'] else []
    if not suit_keys:
        suit_keys = extract_table_keys(data['suits'], 'SUITS') if data['suits'] else []
    if not suit_keys:
        suit_keys = ['thermal_suit', 'exosuit']
    w(f'**Suits ({len(suit_keys)} overlays):**')
    for s in suit_keys:
        w(f'- {s}')
    w()

    # Body parts
    body_parts = extract_table_keys(data['body'], 'BODY_PARTS') if data['body'] else []
    if not body_parts:
        body_parts = extract_table_keys(data['body'], 'PARTS') if data['body'] else []
    if not body_parts:
        body_parts = ['head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg']
    w(f'### Body Part Diagram ({len(body_parts)} zones)')
    w('> 1 human silhouette + injury tint overlay per zone')
    w()
    for bp in body_parts:
        w(f'- {bp}')
    w()

    # -----------------------------------------------------------------------
    # 3. CREATURES
    # -----------------------------------------------------------------------
    w('---')
    w('## 3. CREATURES')
    w()
    creatures = extract_entries_with_fields(data['creatures'], 'SPECIES',
                                           ['name', 'tier', 'size', 'hostile', 'desc'])

    # Group by tier
    tier_groups = OrderedDict()
    tier_order = ['small', 'medium', 'megafauna', 'eldritch', 'eldritch_livestock', 'swarm']
    tier_labels = {
        'small': 'Small Fauna',
        'medium': 'Medium Fauna',
        'megafauna': 'Megafauna',
        'eldritch': 'Eldritch Horrors',
        'eldritch_livestock': 'Eldritch Livestock',
        'swarm': 'Swarm Creatures',
    }
    for t in tier_order:
        tier_groups[t] = []
    for c in creatures:
        t = c.get('tier', 'medium')
        if t not in tier_groups:
            tier_groups[t] = []
        tier_groups[t].append(c)

    for tier, group in tier_groups.items():
        if not group:
            continue
        label = tier_labels.get(tier, tier.title())
        w(f'### {label} ({len(group)} species)')
        w()
        w('| Done | ID | Name | Size | Description |')
        w('|------|----|------|------|-------------|')
        for c in group:
            w(f"| | {c['id']} | {c.get('name', '')} | {c.get('size', '')} | {c.get('desc', '')[:60]} |")
        w()
        total_items += len(group)

    w(f'**Creatures total: {sum(len(g) for g in tier_groups.values())} species**')
    w()

    # -----------------------------------------------------------------------
    # 4. BOSSES
    # -----------------------------------------------------------------------
    w('---')
    w('## 4. BOSSES')
    w()
    bosses = extract_table_keys(data['bosses'], 'BOSS_DEFS')
    if not bosses:
        bosses = extract_dot_keys(data['bosses'], 'BOSS_DEFS')
    w(f'### Named Bosses ({len(bosses)})')
    w()
    w('| Done | ID | Description |')
    w('|------|----|-------------|')
    for b in bosses:
        name = extract_field(data['bosses'], b, 'name') or b
        w(f'| | {b} | {name} |')
    w()
    total_items += len(bosses)

    # -----------------------------------------------------------------------
    # 5. MEGABEASTS
    # -----------------------------------------------------------------------
    w('---')
    w('## 5. PROCEDURAL MEGABEASTS')
    w()
    forms = extract_table_keys(data['megabeasts'], 'BODY_FORMS')
    if not forms:
        forms = extract_array_field(data['megabeasts'], 'BODY_FORMS', 'id')
    materials = extract_table_keys(data['megabeasts'], 'BODY_MATERIALS')
    if not materials:
        materials = extract_array_field(data['megabeasts'], 'BODY_MATERIALS', 'id')
    attacks = extract_table_keys(data['megabeasts'], 'ATTACK_TYPES')
    if not attacks:
        attacks = extract_array_field(data['megabeasts'], 'ATTACK_TYPES', 'id')

    w(f'### Body Forms — {len(forms)} unique silhouettes')
    for f in forms:
        w(f'- {f}')
    w()
    w(f'### Body Materials — {len(materials)} palette swaps')
    for m in materials:
        w(f'- {m}')
    w()
    w(f'### Attack VFX — {len(attacks)} effect animations')
    for a in attacks:
        w(f'- {a}')
    w()
    total_items += len(forms) + len(materials) + len(attacks)

    # -----------------------------------------------------------------------
    # 6. LAIRS
    # -----------------------------------------------------------------------
    w('---')
    w('## 6. CREATURE LAIRS')
    w()
    lair_species = extract_array_field(data['lairs'], 'LAIR_TYPES', 'species')
    if not lair_species:
        lair_species = re.findall(r"species\s*=\s*'(\w+)'", data['lairs'])
    w(f'### Lairs ({len(lair_species)})')
    w('> 3 base types (cave/den/nest) x 3 states (intact/damaged/destroyed)')
    w()
    for s in lair_species:
        w(f'- {s} lair')
    w()
    total_items += len(lair_species)

    # -----------------------------------------------------------------------
    # 7. RAIDERS (humanoid enemy species)
    # -----------------------------------------------------------------------
    w('---')
    w('## 7. HUMANOID RAIDERS')
    w()
    raider_text = data['raiders']
    raider_species = extract_table_keys(raider_text, 'SPECIES')

    w(f'### Raider Species ({len(raider_species)})')
    w('> Humanoid enemies use colonist base model + faction clothing overlays')
    w()
    w('| Done | ID | Name |')
    w('|------|----|------|')
    for r in raider_species:
        name = extract_field(raider_text, r, 'name') or r
        w(f'| | {r} | {name} |')
    w()
    total_items += len(raider_species)

    # -----------------------------------------------------------------------
    # 8. NPCs & MERCHANTS
    # -----------------------------------------------------------------------
    w('---')
    w('## 8. NPCs & MERCHANTS')
    w()
    merchants = extract_table_keys(data['merchants'], 'MERCHANT_TYPES')
    if not merchants:
        merchants = extract_table_keys(data['merchants'], 'MERCHANTS')
    if not merchants:
        merchants = re.findall(r"id\s*=\s*'(\w+)'", data['merchants'])
    w(f'### Merchant Types ({len(merchants)})')
    w('> 1 base humanoid model + faction outfit color swaps')
    w()
    for m in merchants:
        w(f'- {m}')
    w()
    total_items += len(merchants)

    # -----------------------------------------------------------------------
    # 9. BUILDINGS
    # -----------------------------------------------------------------------
    w('---')
    w('## 9. BUILDINGS')
    w()
    building_entries = extract_entries_with_fields(data['building'], 'defs',
                                                   ['name', 'desc', 'category', 'entitySpawn',
                                                    'powerDraw', 'powerOutput'])
    # Also get dot-style definitions
    dot_keys = extract_dot_keys(data['building'], 'defs')
    existing_ids = {e['id'] for e in building_entries}
    for dk in dot_keys:
        if dk not in existing_ids:
            name = extract_field(data['building'], dk, 'name') or dk
            desc = extract_field(data['building'], dk, 'desc') or ''
            es = extract_field(data['building'], dk, 'entitySpawn') or ''
            building_entries.append({'id': dk, 'name': name, 'desc': desc, 'entitySpawn': es})

    bldg_cats = categorize_buildings(building_entries)

    for cat_name, bldgs in bldg_cats.items():
        w(f'### {cat_name} ({len(bldgs)})')
        w()
        w('| Done | ID | Name | Description |')
        w('|------|----|------|-------------|')
        for b in bldgs:
            w(f"| | {b['id']} | {b.get('name', '')} | {b.get('desc', '')[:70]} |")
        w()
        total_items += len(bldgs)

    w(f'**Buildings total: {len(building_entries)}**')
    w()

    # -----------------------------------------------------------------------
    # 10. DEFENSES (turrets, traps, laser fences)
    # -----------------------------------------------------------------------
    w('---')
    w('## 10. DEFENSES')
    w()

    # Turrets
    turrets = extract_entries_with_fields(data['defenses'], 'TURRET_DEFS',
                                          ['name', 'damage', 'range', 'powered'])
    w(f'### Turrets ({len(turrets)})')
    w('> SPRITE TIP: 1 shared turret base pedestal. Swap weapon barrel on top.')
    w()
    w('| Done | ID | Name | Dmg | Range |')
    w('|------|----|------|-----|-------|')
    for t in turrets:
        w(f"| | {t['id']} | {t.get('name', '')} | {t.get('damage', '')} | {t.get('range', '')} |")
    w()
    total_items += len(turrets)

    # Traps
    traps = extract_entries_with_fields(data['traps'], 'TRAP_DEFS',
                                        ['name', 'damage', 'aoe', 'ordnanceType'])
    w(f'### Traps ({len(traps)})')
    w('> SPRITE TIP: Plate/snare/mine base families with color/detail swaps')
    w()
    w('| Done | ID | Name | Dmg | AOE |')
    w('|------|----|------|-----|-----|')
    for t in traps:
        w(f"| | {t['id']} | {t.get('name', '')} | {t.get('damage', '')} | {t.get('aoe', '')} |")
    w()
    total_items += len(traps)

    # Laser fences
    lasers = extract_entries_with_fields(data['defenses'], 'LASER_DEFS',
                                         ['name', 'damagePerSec', 'powerDraw'])
    if lasers:
        w(f'### Laser Fences & Barriers ({len(lasers)})')
        w()
        w('| Done | ID | Name | DPS | Power |')
        w('|------|----|------|-----|-------|')
        for l in lasers:
            w(f"| | {l['id']} | {l.get('name', '')} | {l.get('damagePerSec', '')} | {l.get('powerDraw', '')}W |")
        w()
        total_items += len(lasers)

    # Ordnance
    ordnance = extract_entries_with_fields(data['ordnance'], 'TYPES',
                                            ['name', 'damage', 'radius']) if data['ordnance'] else []
    if not ordnance:
        ordnance_keys = extract_table_keys(data['ordnance'], 'TYPES') if data['ordnance'] else []
        ordnance = [{'id': k} for k in ordnance_keys]
    if ordnance:
        w(f'### Ordnance Types ({len(ordnance)})')
        w()
        for o in ordnance:
            w(f"- {o['id']}")
        w()
        total_items += len(ordnance)

    # -----------------------------------------------------------------------
    # 11. ITEMS
    # -----------------------------------------------------------------------
    w('---')
    w('## 11. ITEMS')
    w()
    items = extract_entries_with_fields(data['production'], 'ITEMS',
                                        ['name', 'stack', 'category', 'desc'])
    dot_items = extract_dot_keys(data['production'], 'ITEMS')
    existing_item_ids = {e['id'] for e in items}
    for di in dot_items:
        if di not in existing_item_ids:
            name = extract_field(data['production'], di, 'name') or di
            items.append({'id': di, 'name': name})

    item_cats = categorize_items(items)

    for cat_name, cat_items in item_cats.items():
        w(f'### {cat_name} ({len(cat_items)})')
        w()
        w('| Done | ID | Name |')
        w('|------|----|------|')
        for item in cat_items:
            w(f"| | {item['id']} | {item.get('name', '')} |")
        w()
        total_items += len(cat_items)

    w(f'**Items total: {len(items)}**')
    w()

    # -----------------------------------------------------------------------
    # 12. AGRICULTURE
    # -----------------------------------------------------------------------
    w('---')
    w('## 12. AGRICULTURE')
    w()
    crops = extract_entries_with_fields(data['agriculture'], 'CROP_DEFS',
                                        ['name', 'growTime', 'yield'])
    if not crops:
        crops = extract_entries_with_fields(data['agriculture'], 'CROPS',
                                            ['name', 'growTime', 'yield'])
    w(f'### Crops ({len(crops)})')
    w('> SPRITE TIP: Generic seed/sprout shared across crops. Mature stage unique per crop.')
    w()
    w('| Done | ID | Name | Grow Time |')
    w('|------|----|------|-----------|')
    for c in crops:
        w(f"| | {c['id']} | {c.get('name', '')} | {c.get('growTime', '')}s |")
    w()
    total_items += len(crops)

    # -----------------------------------------------------------------------
    # 13. ELDRITCH GROWTH
    # -----------------------------------------------------------------------
    w('---')
    w('## 13. ELDRITCH GROWTH')
    w()
    eldritch_types = extract_table_keys(data['eldritch'], 'ELDRITCH_TYPES')
    if not eldritch_types:
        eldritch_types = extract_array_field(data['eldritch'], 'ELDRITCH_TYPES', 'id')
    stages = extract_table_keys(data['eldritch'], 'STAGES')
    if not stages:
        stages = extract_array_field(data['eldritch'], 'STAGES', 'name')
    if not stages:
        stages = ['larva', 'whelp', 'juvenile', 'mature', 'ancient']

    w(f'### Types: {len(eldritch_types)}, Stages: {len(stages)}')
    w(f'### Total growth visuals: {len(eldritch_types)} x {len(stages)} = {len(eldritch_types) * len(stages)}')
    w('> SPRITE TIP: Draw juvenile (1x), scale up for mature (1.8x) and ancient (3x)')
    w()
    w('**Types:**')
    for t in eldritch_types:
        w(f'- {t}')
    w()
    w('**Stages:**')
    for s in stages:
        w(f'- {s}')
    w()
    total_items += len(eldritch_types) * len(stages)

    # -----------------------------------------------------------------------
    # 14. FLUIDS & GASES
    # -----------------------------------------------------------------------
    w('---')
    w('## 14. FLUIDS & GASES')
    w()
    fluids = extract_table_keys(data['pipe_defs'], 'FLUIDS')
    if not fluids:
        fluids = extract_array_field(data['pipe_defs'], 'FLUIDS', 'id')
    gases = extract_table_keys(data['pipe_defs'], 'GASES')
    if not gases:
        gases = extract_array_field(data['pipe_defs'], 'GASES', 'id')
    w(f'### Fluids ({len(fluids)}) — 1 base flow anim + color tints')
    for f in fluids:
        w(f'- {f}')
    w()
    w(f'### Gases ({len(gases)}) — 1 base haze particle + color tints')
    for g in gases:
        w(f'- {g}')
    w()
    total_items += len(fluids) + len(gases)

    # -----------------------------------------------------------------------
    # 15. DISEASES & STATUS
    # -----------------------------------------------------------------------
    w('---')
    w('## 15. DISEASES & STATUS')
    w()
    diseases = extract_entries_with_fields(data['disease'], 'DISEASES',
                                           ['name', 'desc', 'lethal'])
    if not diseases:
        diseases = extract_entries_with_fields(data['disease'], 'DISEASE_DEFS',
                                               ['name', 'desc', 'lethal'])
    w(f'### Diseases ({len(diseases)})')
    w()
    w('| Done | ID | Name |')
    w('|------|----|------|')
    for d in diseases:
        w(f"| | {d['id']} | {d.get('name', '')} |")
    w()
    total_items += len(diseases)

    # Mental breaks
    breaks = extract_table_keys(data['mental'], 'BREAK_TYPES')
    if not breaks:
        breaks = extract_table_keys(data['mental'], 'BREAKS')
    if not breaks:
        breaks = re.findall(r"(\w+)\s*=\s*\{[^}]*name\s*=", data['mental']) if data['mental'] else []

    w(f'### Mental Break Icons ({len(breaks)})')
    for b in breaks:
        w(f'- {b}')
    w()

    # -----------------------------------------------------------------------
    # 16. WEATHER
    # -----------------------------------------------------------------------
    w('---')
    w('## 16. WEATHER')
    w()
    weather = extract_entries_with_fields(data['weather'], 'WEATHER_TYPES',
                                          ['tempMod', 'visibility', 'snowRate'])
    if not weather:
        weather = extract_entries_with_fields(data['weather'], 'TYPES',
                                              ['tempMod', 'visibility', 'snowRate'])
    w(f'### Weather Types ({len(weather)})')
    w('> SPRITE TIP: 1 snow particle scaled by density/speed. NOT separate systems.')
    w()
    w('| Done | Weather | Temp | Vis |')
    w('|------|---------|------|-----|')
    for we in weather:
        w(f"| | {we['id']} | {we.get('tempMod', '')}C | {we.get('visibility', '')} |")
    w()
    total_items += len(weather)

    # -----------------------------------------------------------------------
    # 17. RESEARCH
    # -----------------------------------------------------------------------
    w('---')
    w('## 17. RESEARCH TREE')
    w()
    research = extract_entries_with_fields(data['research'], 'RESEARCH_NODES',
                                           ['id', 'tier', 'cost'])
    if not research:
        research = extract_entries_with_fields(data['research'], 'NODES',
                                               ['id', 'tier', 'cost'])
    # Group by tier
    tiers = {}
    for r in research:
        t = r.get('tier', '?')
        if t not in tiers:
            tiers[t] = []
        tiers[t].append(r)

    for t in sorted(tiers.keys()):
        nodes = tiers[t]
        w(f'### Tier {t} ({len(nodes)} nodes)')
        for n in nodes:
            w(f"- {n['id']}")
        w()
    w(f'**Research nodes total: {len(research)}** (each needs a small icon)')
    w()
    total_items += len(research)

    # -----------------------------------------------------------------------
    # 18. POLICIES
    # -----------------------------------------------------------------------
    w('---')
    w('## 18. POLICIES')
    w()
    policies = extract_table_keys(data['policies'], 'POLICIES')
    if not policies:
        policies = extract_table_keys(data['policies'], 'POLICY_DEFS')
    w(f'### Policy Icons ({len(policies)})')
    for p in policies:
        w(f'- {p}')
    w()
    total_items += len(policies)

    # -----------------------------------------------------------------------
    # 19. EFFECTS & PARTICLES
    # -----------------------------------------------------------------------
    w('---')
    w('## 19. EFFECTS & PARTICLES')
    w()
    effects = [
        'Fire (burning tiles/traps)', 'Flamethrower cone', 'Snow particles (5 weather levels)',
        'Wind streaks (blizzard/whiteout)', 'Aurora overlay', 'Projectile trail',
        'Explosion burst (grenades/IEDs/mines/ordnance)', 'Blood splatter',
        'Hypothermia frost overlay', 'Pollution haze', 'Thermal shimmer',
        'Muzzle flash', 'Fluid spill (pipe burst)', 'Frozen pipe overlay',
        'Shield bubble (generator)', 'Tesla arc', 'Laser beam', 'Cryo blast cone',
        'Napalm fire spread', 'Gas cloud (gas turret/trap)',
        'Acid splash', 'EMP pulse', 'Nuclear flash', 'Foam spread',
    ]
    w(f'### Effect Animations ({len(effects)})')
    w()
    for e in effects:
        w(f'- [ ] {e}')
    w()
    total_items += len(effects)

    # -----------------------------------------------------------------------
    # 20. ENDGAME
    # -----------------------------------------------------------------------
    endgame_keys = extract_table_keys(data['endgame'], 'ENDGAME_BUILDINGS') if data['endgame'] else []
    if not endgame_keys:
        endgame_keys = extract_table_keys(data['endgame'], 'VICTORY_PATHS') if data['endgame'] else []
    if endgame_keys:
        w('---')
        w('## 20. ENDGAME STRUCTURES')
        w()
        w(f'### Victory Path Buildings ({len(endgame_keys)})')
        for e in endgame_keys:
            w(f'- {e}')
        w()
        total_items += len(endgame_keys)

    # -----------------------------------------------------------------------
    # 21. UI ICONS
    # -----------------------------------------------------------------------
    w('---')
    w('## 21. UI ICONS & ELEMENTS')
    w()
    ui_items = [
        ('Resource Bar', 6, 'Thermal Cores, Wood, Stone, Metal, Food, Fuel'),
        ('Need Bar', 4, 'Warmth, Food, Rest, Morale'),
        ('Game Controls', 4, 'Pause, Speed 1x/2x/3x'),
        ('Build Menu Categories', 14, 'Walls, Heating, Vent, Furniture, Deco, Production, Power, Logistics, Turrets, Traps, Forts, Colony, Agriculture, Missiles'),
        ('Cursor Icons', 5, 'Select, Mine, Build, Cancel, Designate'),
        ('Hope/Discontent Meters', 2, 'Rising arrow, Storm cloud'),
        ('Body Part Diagram', 1, '1 figure + highlight zones'),
    ]
    ui_total = 0
    for name, count, desc in ui_items:
        w(f'### {name} ({count} icons)')
        w(f'- {desc}')
        w()
        ui_total += count
    w(f'### Research Node Icons ({len(research)})')
    w(f'### Policy Icons ({len(policies)})')
    w(f'### Mental Break Icons ({len(breaks)})')
    w()
    ui_total += len(research) + len(policies) + len(breaks)
    total_items += ui_total

    # -----------------------------------------------------------------------
    # FINAL SUMMARY
    # -----------------------------------------------------------------------
    w('---')
    w('## FINAL SUMMARY')
    w()
    w(f'**Total visual items: ~{total_items}+**')
    w()
    w('> After sprite family reuse (shared bases + recolors), estimated ~270-320 unique base sprites needed.')
    w('> ~50% reduction via material swaps, palette tints, scaling, and overlay layers.')
    w()
    w(f'*Generated from codebase on {date.today().isoformat()}*')
    w()

    # Write output
    output_path = 'FROSTHOLD_Art_Assets.md'
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out))

    print(f"\nWrote {output_path} ({len(out)} lines)")
    print(f"Total items catalogued: ~{total_items}")


if __name__ == '__main__':
    generate()
