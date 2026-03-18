"""
Sprite Slicer v4 — Row-grid slicing + checkerboard removal + auto-detect mode.

Fixes over v3:
- Checkerboard bg properly removed from ALL sprites (including tiles)
- "fill" mode for tiles: content fills entire target size
- "auto_detect" mode for creatures: connected-component extraction (no even grid)
- Bottom trim removes Gemini text labels
- Weapons at 32x32
"""

import cv2
import numpy as np
from PIL import Image
from collections import Counter
import os

DOWNLOADS = os.path.expanduser("~/Downloads")
OUTPUT_BASE = r"F:\IceRimworld\assets\sprites"

# ─────────────────────────────────────────────────────────────────────
# Sheet definitions
# "fill": True = tile/crop fill mode (stretch to fill entire target, fully opaque)
# "auto_detect": True = find sprites via connected components (for uneven layouts)
# "trim_bottom": fraction of cell height to crop from bottom (text labels)
# "inset": fraction of cell to trim from each edge (grid mode only)
# ─────────────────────────────────────────────────────────────────────

SHEETS = [
    # ── BATCH 1 ──
    {
        "file": "Tiles.jpg", "dir": "tiles", "size": 32, "fill": True, "inset": 0.25,
        "rows": [
            (["snow", "ice", "rock", "tree_1", "tree_2", "ore_vein"], 0.0, 0.35),
            (["wall_wood", "wall_stone", "floor_wood", "floor_stone", "door", "debris"], 0.40, 1.0),
        ]
    },
    {
        "file": "Colonist.jpg", "dir": "colonists", "size": 32, "trim_bottom": 0.12,
        "rows": [
            (["idle", "walking", "working", "sleeping", "dead"], 0.0, 1.0),
        ]
    },
    {
        "file": "Creat.jpg", "dir": "creatures", "size": None,
        "crops": [
            # (name, x1_frac, y1_frac, x2_frac, y2_frac) — exact regions per sprite
            ("frost_hare",     0.00, 0.00, 0.07, 0.42),
            ("ice_fox_sm",     0.00, 0.42, 0.07, 0.85),
            ("ice_fox",        0.07, 0.10, 0.17, 0.85),
            ("tundra_wolf",    0.17, 0.10, 0.27, 0.85),
            ("glacier_bear",   0.27, 0.00, 0.39, 0.88),
            ("stalker",        0.39, 0.00, 0.50, 0.88),
            ("mammoth",        0.49, 0.05, 0.63, 0.88),
            ("frost_titan",    0.63, 0.00, 0.82, 0.88),
            ("the_pale_thing", 0.82, 0.00, 1.00, 0.88),
        ]
    },
    {
        "file": "Build.jpg", "dir": "buildings", "size": 32, "trim_bottom": 0.08,
        "rows": [
            (["campfire", "bed", "workbench", "kitchen", "smelter", "sawmill",
              "research_bench", "turret_gun", "farm_plot", "torch", "steam_hub", "solar_panel"], 0.0, 0.45),
            (["campfire_v2", "bed_v2", "workbench_v2", "kitchen_v2", "sawmill_v2", "research_bench_v2",
              "turret_gun_v2", "farm_plot_v2", "torch_v2", "steam_hub_v2"], 0.50, 1.0),
        ]
    },
    {
        "file": "item.jpg", "dir": "items", "size": 16, "trim_bottom": 0.08,
        "rows": [
            (["wood", "stone", "metal", "bread", "water", "fuel", "thermal_core",
              "components", "steel", "medicine", "bandage", "leather", "raw_meat",
              "coal", "circuit", "spike", "ammo_bullet", "eldritch_ichor", "cloth", "herbal_medicine"], 0.0, 0.45),
            (["wood_v2", "stone_v2", "metal_v2", "bread_v2", "water_v2", "fuel_v2", "thermal_core_v2",
              "components_v2", "medicine_v2", "bandage_v2", "leather_v2", "coal_v2", "circuit_v2",
              "ammo_bullet_v2", "eldritch_ichor_v2", "cloth_v2", "herbal_medicine_v2"], 0.50, 1.0),
        ]
    },
    {
        "file": "UI.jpg", "dir": "ui", "size": 24, "trim_bottom": 0.08,
        "rows": [
            (["pickaxe", "hammer", "box_arrow", "pot", "crosshair", "flask",
              "red_cross", "sword", "thermometer", "moon"], 0.0, 0.45),
            (["pickaxe_v2", "hammer_v2", "box_arrow_v2", "pot_v2", "crosshair_v2", "flask_v2",
              "red_cross_v2", "sword_v2", "thermometer_v2", "moon_v2"], 0.50, 1.0),
        ]
    },

    # ── BATCH 2 ──
    {
        "file": "Tiles2.jpg", "dir": "tiles", "size": 32, "fill": True, "inset": 0.18,
        "rows": [
            (["wall_metal", "wall_insulated", "floor_metal", "floor_insulated",
              "door_sealed", "permafrost", "dirt", "water_tile", "lava_vent", "void"], 0.0, 1.0),
        ]
    },
    {
        "file": "colonist2.jpg", "dir": "colonists", "size": 32, "trim_bottom": 0.12,
        "rows": [
            (["eating", "mental_break", "freezing", "armed_melee", "armed_ranged", "armored"], 0.0, 1.0),
        ]
    },
    {
        "file": "creat2.jpg", "dir": "creatures", "size": None, "trim_bottom": 0.20,
        "rows": [
            (["snow_grouse", "frost_beetle", "ice_locust", "skitterer"], 0.0, 0.30),
            (["dire_wolf", "giant_rat", "spawnling", "sabertooth", "ice_stalker",
              "snow_ape", "ice_brute", "shade"], 0.35, 1.0),
        ]
    },
    {
        "file": "build2.jpg", "dir": "buildings", "size": 32, "trim_bottom": 0.08,
        "rows": [
            (["coal_burner", "thermal_gen", "wind_turbine", "nuclear_reactor",
              "heater", "butcher_table", "drug_lab", "forge", "tannery",
              "deep_drill", "air_purifier", "cloning_vat", "radio_beacon", "shield_generator"], 0.0, 1.0),
        ]
    },
    {
        "file": "defense.jpg", "dir": "defense", "size": 32, "trim_bottom": 0.08,
        "rows": [
            (["turret_ballista", "turret_minigun", "turret_flamethrower", "turret_tesla",
              "turret_rocket", "mortar", "spike_trap", "barricade", "steel_barrier", "watchtower"], 0.0, 0.45),
            (["spike_trap_v2", "bear_trap", "pit_trap", "incendiary_trap", "razor_wire",
              "frag_mine", "sandbag", "barricade_v2", "steel_barrier_v2", "watchtower_v2"], 0.50, 1.0),
        ]
    },
    {
        "file": "Item2.jpg", "dir": "items", "size": 16, "trim_bottom": 0.08,
        "rows": [
            (["raw_ice", "raw_hide", "thermal_core_alt", "lumber", "cut_stone", "charcoal",
              "jerky", "ration", "raw_fat", "organ_heart", "peg_leg", "stardust",
              "drift", "voidbloom", "ammo_arrow", "ammo_shell", "grenade", "molotov",
              "void_crystal", "chitin_plate", "serpent_venom"], 0.0, 0.45),
            (["raw_ice_v2", "raw_hide_v2", "thermal_core_v3", "lumber_v2", "cut_stone_v2", "charcoal_v2",
              "raw_fur", "stew", "feast", "organ_heart_v2", "organ_eye", "bionic_arm",
              "stardust_v2", "drift_v2", "voidbloom_v2", "ammo_arrow_v2", "ammo_shell_v2",
              "grenade_v2", "molotov_v2", "void_crystal_v2", "chitin_plate_v2", "serpent_venom_v2"], 0.50, 1.0),
        ]
    },
    {
        "file": "ui2.jpg", "dir": "ui", "size": 24, "trim_bottom": 0.08,
        "rows": [
            (["broom", "wrench", "basket", "water_drop", "smiley", "skull",
              "snowflake", "pill", "biohazard", "shield", "gear", "lightning"], 0.0, 1.0),
        ]
    },

    # ── BATCH 3 ──
    {
        "file": "Tiles3.jpg", "dir": "tiles", "size": 32, "fill": True, "inset": 0.18,
        "rows": [
            (["snow_heavy", "ice_cracked", "scorched", "mud", "moss_stone", "metal_grate"], 0.0, 1.0),
        ]
    },
    {
        "file": "Colonist3.jpg", "dir": "colonists", "size": 32, "trim_bottom": 0.12,
        "rows": [
            (["carrying", "mining", "building_col", "cooking", "researching", "medical"], 0.0, 1.0),
        ]
    },
    {
        "file": "Creat3.jpg", "dir": "creatures", "size": None, "trim_bottom": 0.20,
        "rows": [
            (["fleshwalker", "gore_shoat", "weeping_calf", "husk_pup",
              "void_minnow_lg", "pit_wyrm_lg"], 0.0, 0.40),
            (["void_minnow", "pit_wyrm", "bile_mold", "thorn_polyp",
              "nerve_cluster", "rot_bloom"], 0.42, 0.55),
            (["the_bull", "the_stalker_boss", "that_which_sleeps"], 0.55, 1.0),
        ]
    },
    {
        "file": "build3.jpg", "dir": "buildings", "size": 32, "trim_bottom": 0.08,
        "rows": [
            (["loom", "smokehouse", "stone_cutter", "kiln", "refinery",
              "surgery_table", "expedition_table", "quest_board", "greenhouse",
              "memorial", "standing_lamp", "water_pump", "oil_refinery", "steam_boiler"], 0.0, 0.75),
        ]
    },
    {
        "file": "buildpowerpipe.jpg", "dir": "buildings", "size": 32, "trim_bottom": 0.08,
        "rows": [
            (["fire_pit", "deep_fire_pit", "bio_reactor", "mini_reactor",
              "hand_crank", "treadmill", "chain_gang_wheel", "waste_incinerator",
              "lightning_rod", "thermopile", "ichor_burner", "small_pipe", "large_pipe", "insulated_pipe"], 0.0, 0.75),
        ]
    },
    {
        "file": "defense2-1.jpg", "dir": "defense", "size": 32, "trim_bottom": 0.08,
        "rows": [
            (["turret_crossbow", "turret_shotgun", "turret_sniper", "turret_autocannon",
              "turret_cryo", "turret_laser", "turret_railgun", "turret_emp", "turret_grenade_launcher"], 0.0, 0.45),
            (["snare_trap", "spring_blade", "acid_trap", "cryo_mine", "gas_trap",
              "caltrops", "claymore", "tripwire_alarm", "tripwire_ied"], 0.50, 1.0),
        ]
    },
    {
        "file": "Item3.jpg", "dir": "items", "size": 16, "trim_bottom": 0.08,
        "rows": [
            (["fuel_cell", "cloth_alt", "insulation", "glass", "pipe",
              "cooked_meat", "bread_alt", "feast", "human_meat", "human_leather",
              "corpse_creature", "corpse_human", "bionic_eye", "organ_lung", "organ_kidney",
              "organ_liver", "parka", "boots"], 0.0, 0.45),
            (["fuel_cell_v2", "boots_v2", "cut_stone_alt", "cooked_meat_v2", "bread_v2",
              "corpse_creature_v2", "corpse_human_v2", "prosthetic_leg", "bionic_leg",
              "bionic_eye_v2", "organ_lung_v2", "organ_kidney_v2", "parka_v2", "boots_v3",
              "smog", "shards", "rotgut", "surge"], 0.50, 1.0),
        ]
    },
    {
        "file": "weapons.jpg", "dir": "weapons", "size": 32, "trim_bottom": 0.12,
        "rows": [
            (["club", "shiv", "pipe_wrench", "knife", "hatchet", "machete",
              "spear", "sword_wpn", "shortbow", "bow", "crossbow_wpn",
              "revolver", "pistol", "sawed_off", "pump_shotgun", "bolt_action",
              "assault_rifle", "battle_rifle"], 0.0, 1.0),
        ]
    },
    {
        "file": "plants.jpg", "dir": "crops", "size": 32, "fill": True,
        "rows": [
            (["frost_wheat_seed", "thermal_berries_seed", "alien_fungus_seed",
              "medicinal_moss_seed", "fiber_vine_seed", "psychoid_plant_seed",
              "smokeleaf_plant_seed", "hops_plant_seed"], 0.0, 0.22),
            (["frost_wheat_grow", "thermal_berries_grow", "alien_fungus_grow",
              "medicinal_moss_grow", "fiber_vine_grow", "psychoid_plant_grow",
              "smokeleaf_plant_grow", "hops_plant_grow"], 0.24, 0.48),
            (["frost_wheat_mature", "thermal_berries_mature", "alien_fungus_mature",
              "medicinal_moss_mature", "fiber_vine_mature", "psychoid_plant_mature",
              "smokeleaf_plant_mature", "hops_plant_mature"], 0.50, 0.74),
            (["frost_wheat_wilted", "thermal_berries_wilted", "alien_fungus_wilted",
              "medicinal_moss_wilted", "fiber_vine_wilted", "psychoid_plant_wilted",
              "smokeleaf_plant_wilted", "hops_plant_wilted"], 0.76, 1.0),
        ]
    },
]


# ─────────────────────────────────────────────────────────────────────
# Checkerboard detection & removal
# ─────────────────────────────────────────────────────────────────────

def detect_checker_colors(img_np, corner_size=50):
    """Detect the two checkerboard colors from image corners.

    Uses the corner with highest local variance (most likely to be pure
    checkerboard), avoiding sprite-content corners.
    """
    h, w = img_np.shape[:2]
    cs = min(corner_size, h // 3, w // 3)
    if cs < 5:
        return None, None

    # Check all 4 corners, pick the one with highest pixel variance
    # (checkerboard alternates light/dark = high variance)
    corners = [
        img_np[0:cs, 0:cs],           # top-left
        img_np[0:cs, w-cs:w],         # top-right
        img_np[h-cs:h, 0:cs],         # bottom-left
        img_np[h-cs:h, w-cs:w],       # bottom-right
    ]

    best_patch = None
    best_var = -1
    for patch in corners:
        # Variance of grayscale values
        gray = patch.mean(axis=2)
        var = gray.var()
        if var > best_var:
            best_var = var
            best_patch = patch

    if best_var < 100:  # too low variance = not checkerboard
        return None, None

    # K-means on the best (most checkered) corner
    pixels = best_patch.reshape(-1, 3).astype(np.float32)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 1.0)
    _, labels, centers = cv2.kmeans(pixels, 2, None, criteria, 5, cv2.KMEANS_PP_CENTERS)

    c1 = centers[0]
    c2 = centers[1]

    # Verify they're both grayish (R ≈ G ≈ B, within 15)
    for c in [c1, c2]:
        if max(c) - min(c) > 15:
            return None, None

    # Verify they're distinct (not the same color)
    if np.sqrt(np.sum((c1 - c2) ** 2)) < 30:
        return None, None

    return c1, c2


def remove_checkerboard(img_pil, tolerance=40, use_flood_fill=True, checker_colors=None):
    """Remove checkerboard background using detected checker colors.

    Args:
        tolerance: Color distance threshold for checkerboard matching.
        use_flood_fill: If True, only remove bg pixels connected to edges
            (safe for sprites with gray tones). If False, remove ALL matching
            pixels (more aggressive, good for tiles with distinct colors).
        checker_colors: Optional (c1, c2) tuple of pre-detected checker colors
            from the full source image. If None, detects from this image.
    """
    img_np = np.array(img_pil.convert("RGB"))
    h, w = img_np.shape[:2]

    if checker_colors is not None:
        c1, c2 = checker_colors
    else:
        c1, c2 = detect_checker_colors(img_np)
    if c1 is None:
        # Fallback to corner-sampling approach
        return make_transparent_corner(img_np)

    img_float = img_np.astype(np.float32)

    # Build mask: pixel matches either checker color within tolerance
    diff1 = np.sqrt(np.sum((img_float - c1.reshape(1, 1, 3)) ** 2, axis=2))
    diff2 = np.sqrt(np.sum((img_float - c2.reshape(1, 1, 3)) ** 2, axis=2))
    bg_mask = (diff1 < tolerance) | (diff2 < tolerance)

    if use_flood_fill:
        # Only remove bg pixels reachable from edges (safe for gray sprites)
        edge_seed = np.zeros((h, w), dtype=bool)
        edge_seed[0, :] = True
        edge_seed[-1, :] = True
        edge_seed[:, 0] = True
        edge_seed[:, -1] = True
        bg_final = flood_fill_mask(bg_mask, edge_seed)
    else:
        # Aggressive: remove ALL matching pixels (for tiles with distinct colors)
        bg_final = bg_mask

    # Create RGBA
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = img_np
    rgba[:, :, 3] = np.where(bg_final, 0, 255)

    # Light cleanup: close small holes, remove tiny noise
    alpha = rgba[:, :, 3]
    kernel = np.ones((3, 3), np.uint8)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_CLOSE, kernel)
    kernel_sm = np.ones((2, 2), np.uint8)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, kernel_sm)
    rgba[:, :, 3] = alpha

    return Image.fromarray(rgba, "RGBA")


def flood_fill_mask(bg_candidates, seed_mask):
    """Flood fill: expand seed_mask through bg_candidates using connected components."""
    # bg_candidates: bool mask of pixels that COULD be background
    # seed_mask: bool mask of starting positions (edges)
    # Returns: bool mask of background pixels connected to edges

    # Seed must also be bg candidate
    start = bg_candidates & seed_mask

    # Use OpenCV connectedComponents on bg_candidates
    bg_uint8 = bg_candidates.astype(np.uint8) * 255
    n_labels, labels = cv2.connectedComponents(bg_uint8, connectivity=8)

    # Find which labels touch the edges
    edge_labels = set()
    h, w = labels.shape
    edge_labels.update(labels[0, :].tolist())
    edge_labels.update(labels[-1, :].tolist())
    edge_labels.update(labels[:, 0].tolist())
    edge_labels.update(labels[:, -1].tolist())
    edge_labels.discard(0)  # 0 is non-bg

    # Mark all pixels belonging to edge-connected bg components
    result = np.zeros_like(bg_candidates)
    for lbl in edge_labels:
        result |= (labels == lbl)

    return result


def make_transparent_corner(img_np):
    """Fallback: corner-sampling background removal (from v3)."""
    h, w = img_np.shape[:2]
    pixels = []
    margin = 3
    samples = 50
    for x in range(0, w, max(1, w // samples)):
        for y in range(margin):
            pixels.append(img_np[y, x, :3].tolist())
    for x in range(0, w, max(1, w // samples)):
        for y in range(h - margin, h):
            pixels.append(img_np[y, x, :3].tolist())
    for y in range(0, h, max(1, h // samples)):
        for x in range(margin):
            pixels.append(img_np[y, x, :3].tolist())
    for y in range(0, h, max(1, h // samples)):
        for x in range(w - margin, w):
            pixels.append(img_np[y, x, :3].tolist())

    if not pixels:
        return Image.fromarray(np.dstack([img_np, np.full((h, w), 255, np.uint8)]), "RGBA")

    quantized = [(int(p[0]) // 8 * 8, int(p[1]) // 8 * 8, int(p[2]) // 8 * 8) for p in pixels]
    counter = Counter(quantized)
    bg_colors = [np.array(c, dtype=np.float32) for c, _ in counter.most_common(6)]

    img_float = img_np.astype(np.float32)
    bg_mask = np.zeros((h, w), dtype=bool)
    for bg in bg_colors:
        diff = np.sqrt(np.sum((img_float - bg.reshape(1, 1, 3)) ** 2, axis=2))
        bg_mask |= (diff < 18)

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = img_np
    rgba[:, :, 3] = np.where(bg_mask, 0, 255)

    kernel = np.ones((3, 3), np.uint8)
    rgba[:, :, 3] = cv2.morphologyEx(rgba[:, :, 3], cv2.MORPH_CLOSE, kernel)
    kernel_sm = np.ones((2, 2), np.uint8)
    rgba[:, :, 3] = cv2.morphologyEx(rgba[:, :, 3], cv2.MORPH_OPEN, kernel_sm)

    return Image.fromarray(rgba, "RGBA")


# ─────────────────────────────────────────────────────────────────────
# Auto-detect mode: connected component extraction for uneven layouts
# ─────────────────────────────────────────────────────────────────────

def extract_auto(strip_rgba, names, target_size, fill=False):
    """Find individual sprites by detecting vertical gaps in the alpha channel.

    Much more reliable than connected components — analyzes column-wise alpha
    sums to find the natural gaps between sprites, then splits at gap centers.
    If fill=True, stretches sprite to fill entire target (for tiles).
    """
    alpha = np.array(strip_rgba)[:, :, 3]
    h, w = alpha.shape
    n = len(names)

    # Column-wise average alpha
    col_avg = alpha.astype(float).sum(axis=0) / h

    # Binary: columns with significant sprite content
    content_mask = col_avg > 12

    # Find gap runs (contiguous False columns)
    gaps = []
    start = None
    for x in range(w):
        if not content_mask[x] and start is None:
            start = x
        elif content_mask[x] and start is not None:
            gaps.append((start, x))
            start = None
    if start is not None:
        gaps.append((start, w))

    # Exclude edge gaps (touching x=0 or x=w)
    interior_gaps = [(s, e) for s, e in gaps if s > 5 and e < w - 5]

    # Merge nearby gaps separated by less than min_sprite pixels of content
    # (these are artifacts within a single sprite, not real separations)
    min_sprite = 25
    merged = []
    for s, e in interior_gaps:
        if merged and s - merged[-1][1] < min_sprite:
            # Merge with previous gap
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))

    # Now pick n-1 gaps from the merged list.
    # Prefer wider gaps (more likely to be real separations).
    merged_with_width = [(s, e, e - s) for s, e in merged]
    merged_with_width.sort(key=lambda g: -g[2])  # widest first

    if len(merged_with_width) >= n - 1:
        selected = sorted(merged_with_width[:n - 1], key=lambda g: g[0])
    else:
        selected = sorted(merged_with_width, key=lambda g: g[0])

    # Build region boundaries from split points
    split_xs = [0]
    for s, e, wid in selected:
        split_xs.append((s + e) // 2)
    split_xs.append(w)

    # If we still don't have enough regions, subdivide the widest
    while len(split_xs) - 1 < n:
        widths = [split_xs[i + 1] - split_xs[i] for i in range(len(split_xs) - 1)]
        widest = max(range(len(widths)), key=lambda i: widths[i])
        mid = (split_xs[widest] + split_xs[widest + 1]) // 2
        split_xs.insert(widest + 1, mid)

    # Extract each sprite region
    results = []
    for i, name in enumerate(names):
        if i >= len(split_xs) - 1:
            break
        rx1 = split_xs[i]
        rx2 = split_xs[i + 1]

        region = strip_rgba.crop((rx1, 0, rx2, strip_rgba.height))

        # Trim transparent borders
        bbox = region.getbbox()
        if bbox is None:
            print(f"    WARN: {name} empty region, skipping")
            continue
        trimmed = region.crop(bbox)

        # Determine target
        t = target_size
        if t is None:
            t = auto_target_size(trimmed.width, trimmed.height)

        if fill:
            # Fill mode: stretch to fill entire target, make fully opaque
            result = trimmed.resize((t, t), Image.NEAREST)
            result_np = np.array(result)
            result_np[:, :, 3] = 255
            result = Image.fromarray(result_np, "RGBA")
        else:
            # Center mode: preserve aspect ratio, center on transparent canvas
            tw, th = trimmed.size
            scale = min(t / tw, t / th)
            new_w = max(1, int(tw * scale))
            new_h = max(1, int(th * scale))
            trimmed = trimmed.resize((new_w, new_h), Image.NEAREST)

            result = Image.new("RGBA", (t, t), (0, 0, 0, 0))
            ox = (t - new_w) // 2
            oy = (t - new_h) // 2
            result.paste(trimmed, (ox, oy))

        results.append((name, result))

    return results


def auto_target_size(w, h):
    """Pick target size based on detected sprite dimensions."""
    max_dim = max(w, h)
    if max_dim < 50:
        return 32
    elif max_dim < 90:
        return 48
    else:
        return 96


# ─────────────────────────────────────────────────────────────────────
# Main processing
# ─────────────────────────────────────────────────────────────────────

def _opaque_fraction(img_rgba):
    """Return fraction of pixels with alpha > 128."""
    alpha = np.array(img_rgba)[:, :, 3]
    return (alpha > 128).sum() / max(1, alpha.size)


def process_sheet(sheet):
    """Process a single sprite sheet."""
    src = os.path.join(DOWNLOADS, sheet["file"])
    if not os.path.exists(src):
        print(f"  SKIP: {sheet['file']} not found")
        return 0

    print(f"  {sheet['file']}...")
    img = Image.open(src).convert("RGB")
    img_w, img_h = img.size
    is_fill = sheet.get("fill", False)
    is_auto = sheet.get("auto_detect", False)
    trim_bot_frac = sheet.get("trim_bottom", 0.0)
    inset_frac = sheet.get("inset", 0.0)

    output_dir = os.path.join(OUTPUT_BASE, sheet["dir"])
    os.makedirs(output_dir, exist_ok=True)

    # Detect checker colors once from the full source image
    img_np = np.array(img)
    checker_colors = detect_checker_colors(img_np)

    # ── Explicit crop mode: per-sprite coordinates ──
    if "crops" in sheet:
        count = 0
        for name, x1f, y1f, x2f, y2f in sheet["crops"]:
            cx1 = int(img_w * x1f)
            cy1 = int(img_h * y1f)
            cx2 = int(img_w * x2f)
            cy2 = int(img_h * y2f)
            cell = img.crop((cx1, cy1, cx2, cy2))

            target = sheet["size"]
            cell_rgba = remove_checkerboard(cell, checker_colors=checker_colors)
            bbox = cell_rgba.getbbox()
            if bbox is None:
                print(f"    WARN: {name} empty after bg removal, skipping")
                continue
            trimmed = cell_rgba.crop(bbox)

            if target is None:
                target = auto_target_size(trimmed.width, trimmed.height)

            tw, th = trimmed.size
            scale = min(target / tw, target / th)
            new_w = max(1, int(tw * scale))
            new_h = max(1, int(th * scale))
            trimmed = trimmed.resize((new_w, new_h), Image.NEAREST)

            result = Image.new("RGBA", (target, target), (0, 0, 0, 0))
            ox = (target - new_w) // 2
            oy = (target - new_h) // 2
            result.paste(trimmed, (ox, oy))

            out_path = os.path.join(output_dir, f"{name}.png")
            result.save(out_path)
            count += 1

        print(f"    -> {count} sprites")
        return count

    # ── Row-based mode ──
    count = 0
    for names, row_top_frac, row_bot_frac in sheet["rows"]:
        n = len(names)
        y1 = int(img_h * row_top_frac)
        y2 = int(img_h * row_bot_frac)
        row_h = y2 - y1
        bot_trim = int(row_h * trim_bot_frac)

        # Crop the row strip (with bottom trim for text labels)
        strip = img.crop((0, y1, img_w, y2 - bot_trim))

        if is_auto:
            # Auto-detect mode: remove bg from entire strip, find sprites
            strip_rgba = remove_checkerboard(strip, checker_colors=checker_colors)
            sprites = extract_auto(strip_rgba, names, sheet["size"], fill=is_fill)
            for name, result in sprites:
                out_path = os.path.join(output_dir, f"{name}.png")
                result.save(out_path)
                count += 1
        else:
            # Grid mode: divide strip into even columns
            col_w = img_w / n

            for i, name in enumerate(names):
                x1 = int(col_w * i)
                x2 = int(col_w * (i + 1))

                cell_w = x2 - x1
                cell_h = strip.height
                ix = int(cell_w * inset_frac)
                iy = int(cell_h * inset_frac)

                cell = strip.crop((x1 + ix, iy, x2 - ix, cell_h - iy))

                target = sheet["size"]
                if target is None:
                    target = auto_target_size(cell.width, cell.height)

                # Remove checkerboard background
                # For fill-mode tiles, check if cell color is close to checker gray —
                # if so, use flood-fill (edge-connected only) to preserve interior content.
                # For non-gray tiles, aggressive removal is fine.
                cell_np_check = np.array(cell.convert("RGB"))
                cell_brightness = cell_np_check.mean()
                if is_fill and cell_brightness < 25:
                    # Cell is very dark (void) — skip bg removal entirely
                    cell_rgba = cell.convert("RGBA")
                elif is_fill:
                    # For fill-mode tiles, check if center color is grayish
                    # (close to checkerboard) — use flood-fill to preserve content
                    ch, cw = cell_np_check.shape[:2]
                    center = cell_np_check[ch//4:3*ch//4, cw//4:3*cw//4]
                    center_avg = center.mean(axis=(0, 1))
                    color_range = max(center_avg) - min(center_avg)
                    use_flood = color_range < 25  # grayish center = flood-fill safer
                    cell_rgba = remove_checkerboard(cell, use_flood_fill=use_flood, checker_colors=checker_colors)
                else:
                    cell_rgba = remove_checkerboard(cell, use_flood_fill=True, checker_colors=checker_colors)

                # Trim transparent borders
                bbox = cell_rgba.getbbox()
                if bbox is None or (is_fill and _opaque_fraction(cell_rgba) < 0.25):
                    # bg removal wiped too much content — use raw crop instead
                    cell_rgba = cell.convert("RGBA")
                    bbox = cell_rgba.getbbox()
                    if bbox is None:
                        print(f"    WARN: {name} empty after bg removal, skipping")
                        continue
                trimmed = cell_rgba.crop(bbox)

                if is_fill:
                    # Fill mode: find largest connected component (the actual tile sprite),
                    # ignore stray bg/neighbor pixels, stretch to fill target
                    trimmed_np = np.array(trimmed)
                    trim_alpha = trimmed_np[:, :, 3]

                    # Edge bleed removal: compare edge columns/rows to center color.
                    # If an edge strip's average hue differs sharply from center, zero it.
                    th, tw = trim_alpha.shape
                    if tw > 8 and th > 8:
                        center_rgb = trimmed_np[th//4:3*th//4, tw//4:3*tw//4, :3].mean(axis=(0,1))
                        edge_width = max(3, tw // 8)
                        for side in ['left', 'right', 'top', 'bottom']:
                            if side == 'left':
                                edge_strip = trimmed_np[:, :edge_width, :3]
                                def zero(): trimmed_np[:, :edge_width, 3] = 0
                            elif side == 'right':
                                edge_strip = trimmed_np[:, -edge_width:, :3]
                                def zero(): trimmed_np[:, -edge_width:, 3] = 0
                            elif side == 'top':
                                edge_strip = trimmed_np[:edge_width, :, :3]
                                def zero(): trimmed_np[:edge_width, :, 3] = 0
                            else:
                                edge_strip = trimmed_np[-edge_width:, :, :3]
                                def zero(): trimmed_np[-edge_width:, :, 3] = 0
                            strip_avg = edge_strip.mean(axis=(0,1))
                            color_dist = np.sqrt(np.sum((strip_avg - center_rgb) ** 2))
                            if color_dist > 30:
                                zero()
                        trimmed = Image.fromarray(trimmed_np, "RGBA")
                        bbox = trimmed.getbbox()
                        if bbox:
                            trimmed = trimmed.crop(bbox)
                        trim_alpha = np.array(trimmed)[:, :, 3]

                    # Erode alpha by 2px to break thin edge bleed connections
                    erode_k = np.ones((3, 3), np.uint8)
                    eroded = cv2.erode(trim_alpha, erode_k, iterations=2)
                    _, labels = cv2.connectedComponents(eroded, connectivity=8)

                    # Find largest non-background label
                    unique, counts = np.unique(labels, return_counts=True)
                    label_counts = sorted(zip(unique, counts), key=lambda x: -x[1])
                    best_label = 0
                    for lbl, cnt in label_counts:
                        if lbl != 0:  # skip bg (label 0)
                            best_label = lbl
                            break
                    if best_label > 0:
                        # Dilate the winning component back to recover original edges
                        comp_mask = (labels == best_label).astype(np.uint8) * 255
                        dilated = cv2.dilate(comp_mask, erode_k, iterations=2)
                        # Intersect with original alpha to stay within sprite bounds
                        mask = np.minimum(dilated, trim_alpha)
                        trimmed_np = np.array(trimmed)
                        trimmed_np[:, :, 3] = mask
                        trimmed = Image.fromarray(trimmed_np, "RGBA")
                        # Re-trim to the component bbox
                        bbox2 = trimmed.getbbox()
                        if bbox2:
                            trimmed = trimmed.crop(bbox2)

                    result = trimmed.resize((target, target), Image.NEAREST)
                    # Make fully opaque: fill transparent pixels with average
                    # sprite color so checkerboard gray doesn't bleed through
                    result_np = np.array(result)
                    alpha = result_np[:, :, 3]
                    opaque = alpha > 128
                    if opaque.any():
                        avg_rgb = result_np[opaque, :3].mean(axis=0).astype(np.uint8)
                        transparent = ~opaque
                        result_np[transparent, 0] = avg_rgb[0]
                        result_np[transparent, 1] = avg_rgb[1]
                        result_np[transparent, 2] = avg_rgb[2]
                    result_np[:, :, 3] = 255
                    result = Image.fromarray(result_np, "RGBA")
                else:
                    # Center mode: preserve aspect ratio, center on transparent canvas
                    tw, th = trimmed.size
                    scale = min(target / tw, target / th)
                    new_w = max(1, int(tw * scale))
                    new_h = max(1, int(th * scale))
                    trimmed = trimmed.resize((new_w, new_h), Image.NEAREST)

                    result = Image.new("RGBA", (target, target), (0, 0, 0, 0))
                    ox = (target - new_w) // 2
                    oy = (target - new_h) // 2
                    result.paste(trimmed, (ox, oy))

                out_path = os.path.join(output_dir, f"{name}.png")
                result.save(out_path)
                count += 1

    print(f"    -> {count} sprites")
    return count


def main():
    print("=" * 60)
    print("FROSTHOLD Sprite Slicer v4")
    print("=" * 60)

    import shutil
    if os.path.exists(OUTPUT_BASE):
        shutil.rmtree(OUTPUT_BASE)
    os.makedirs(OUTPUT_BASE, exist_ok=True)

    total = 0
    for sheet in SHEETS:
        total += process_sheet(sheet)

    print(f"\n{total} total sprites -> {OUTPUT_BASE}")
    print()
    for d in sorted(set(s["dir"] for s in SHEETS)):
        full_path = os.path.join(OUTPUT_BASE, d)
        if os.path.exists(full_path):
            files = sorted([f for f in os.listdir(full_path) if f.endswith('.png')])
            print(f"  {d}/ ({len(files)})")


if __name__ == "__main__":
    main()
