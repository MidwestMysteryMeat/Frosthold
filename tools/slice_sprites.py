#!/usr/bin/env python3
"""
Frosthold Sprite Sheet Slicer
Extracts individual sprites from JPG sprite sheets with checkerboard backgrounds.
Replaces checkerboard background with transparency. Outputs RGBA PNGs.

Usage: python tools/slice_sprites.py [--dry-run] [--sheet NAME]
"""

import os
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from collections import deque

DOWNLOADS = 'C:/Users/<you>/Downloads'
REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_ROOT = str(REPO_ROOT / 'assets' / 'sprites_new')

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

def detect_checker_colors(arr):
    """Detect the two checkerboard background colors from image edge strips."""
    h, w = arr.shape[:2]
    # Sample from thin edge strips (more reliable than corner squares)
    strips = []
    strips.append(arr[:, w - 3:w, :].reshape(-1, 3))  # right edge
    strips.append(arr[:, 0:3, :].reshape(-1, 3))       # left edge
    strips.append(arr[0:3, :, :].reshape(-1, 3))        # top edge
    strips.append(arr[h - 3:h, :, :].reshape(-1, 3))    # bottom edge
    pixels = np.vstack(strips).astype(float)

    lum = pixels.mean(axis=1)
    median = np.median(lum)
    light_px = pixels[lum >= median]
    dark_px = pixels[lum < median]

    if len(light_px) == 0 or len(dark_px) == 0:
        return np.array([204.0, 204.0, 204.0]), np.array([153.0, 153.0, 153.0])

    return light_px.mean(axis=0), dark_px.mean(axis=0)


def erode_mask(mask, iterations=2):
    """Erode a boolean mask to remove isolated noise pixels."""
    for _ in range(iterations):
        new = mask.copy()
        new[1:, :] &= mask[:-1, :]
        new[:-1, :] &= mask[1:, :]
        new[:, 1:] &= mask[:, :-1]
        new[:, :-1] &= mask[:, 1:]
        mask = new
    return mask


def make_content_mask(arr, c1, c2, tolerance=30):
    """Boolean mask: True = likely sprite content, False = background.
    Uses erosion to clean JPG artifacts."""
    diff1 = arr.astype(float) - c1.reshape(1, 1, 3)
    diff2 = arr.astype(float) - c2.reshape(1, 1, 3)
    d1 = np.sqrt((diff1 ** 2).sum(axis=2))
    d2 = np.sqrt((diff2 ** 2).sum(axis=2))
    bg = (d1 < tolerance) | (d2 < tolerance)
    content = ~bg
    content = erode_mask(content, iterations=2)
    return content


def compute_checker_rates(arr, c1, c2, tolerance=28):
    """Compute per-column and per-row checkerboard match rates.
    Uses gray-range matching to handle JPG compression artifacts that blend
    checkerboard colors into intermediates.
    Returns (col_rates, row_rates) where each is a 1D array of match fractions."""
    farr = arr.astype(float)
    # Method 1: match against specific checker colors
    d1 = np.sqrt(((farr - c1.reshape(1, 1, 3)) ** 2).sum(axis=2))
    d2 = np.sqrt(((farr - c2.reshape(1, 1, 3)) ** 2).sum(axis=2))
    color_match = (d1 < tolerance) | (d2 < tolerance)

    # Method 2: match gray-range (catches JPG blended checkerboard intermediates)
    # Checkerboard pixels are unsaturated grays between c2 and c1 luminance
    r, g, b = farr[:, :, 0], farr[:, :, 1], farr[:, :, 2]
    lum = (r + g + b) / 3.0
    c1_lum = c1.mean()
    c2_lum = c2.mean()
    lo = min(c1_lum, c2_lum) - 15
    hi = max(c1_lum, c2_lum) + 15
    # Low saturation: max channel deviation from mean < 15
    max_dev = np.maximum(np.abs(r - lum), np.maximum(np.abs(g - lum), np.abs(b - lum)))
    gray_match = (lum >= lo) & (lum <= hi) & (max_dev < 15)

    matches = color_match | gray_match
    h, w = matches.shape
    col_rates = matches.sum(axis=0).astype(float) / h
    row_rates = matches.sum(axis=1).astype(float) / w
    return col_rates, row_rates


def smooth_profile(profile, window=7):
    """Smooth a 1D profile using a moving average."""
    if len(profile) < window:
        return profile.astype(float)
    kernel = np.ones(window) / window
    return np.convolve(profile.astype(float), kernel, mode='same')


def find_spans(profile, min_gap=5, threshold=3, relative_threshold=0.12):
    """Find contiguous spans where profile > threshold, separated by gaps >= min_gap.
    Uses both absolute threshold and relative threshold (fraction of max value)."""
    max_val = profile.max() if len(profile) > 0 else 0
    effective_threshold = max(threshold, max_val * relative_threshold)

    spans = []
    in_span = False
    start = 0
    gap = 0

    for i in range(len(profile)):
        if profile[i] > effective_threshold:
            if not in_span:
                start = i
                in_span = True
            gap = 0
        else:
            if in_span:
                gap += 1
                if gap >= min_gap:
                    end = i - gap
                    if end >= start:
                        spans.append((start, end + 1))
                    in_span = False

    if in_span:
        spans.append((start, len(profile)))

    return spans


def find_sprite_region(content_mask_cell):
    """Within a cell that may contain sprite + label, find the sprite portion.
    Labels are short text at the very bottom, separated by a gap from the sprite.
    Returns (y_start, y_end) relative to cell top."""
    h, w = content_mask_cell.shape
    row_sums = content_mask_cell.sum(axis=1)
    threshold = max(w * 0.01, 1)

    # Find contiguous vertical runs of content
    runs = []
    in_run = False
    start = 0
    for j in range(h):
        if row_sums[j] > threshold:
            if not in_run:
                start = j
                in_run = True
        else:
            if in_run:
                runs.append((start, j))
                in_run = False
    if in_run:
        runs.append((start, h))

    if not runs:
        return 0, h

    if len(runs) == 1:
        return runs[0]

    # Check if the bottom-most run is a label:
    # Labels are short (< 25px) and shorter than the main sprite content
    sprite_runs = runs[:-1]
    last_run = runs[-1]
    last_height = last_run[1] - last_run[0]
    max_sprite_height = max(r[1] - r[0] for r in sprite_runs)

    if last_height < max_sprite_height * 0.4 and last_height < 30:
        # Bottom run is likely a label - return extent of all other runs
        return sprite_runs[0][0], sprite_runs[-1][1]

    # No clear label - return full extent of all runs
    return runs[0][0], runs[-1][1]


def merge_nearby_boxes(bboxes, gap_x=15, gap_y=10):
    """Merge bounding boxes that are close together horizontally in the same row."""
    if not bboxes:
        return bboxes

    # Sort by y-center, then x
    bboxes = sorted(bboxes, key=lambda b: ((b[1] + b[3]) / 2, b[0]))

    merged = True
    while merged:
        merged = False
        new_bboxes = []
        used = set()
        for i, a in enumerate(bboxes):
            if i in used:
                continue
            ax1, ay1, ax2, ay2 = a
            for j, b in enumerate(bboxes):
                if j <= i or j in used:
                    continue
                bx1, by1, bx2, by2 = b
                # Check vertical overlap
                y_overlap = min(ay2, by2) - max(ay1, by1)
                min_h = min(ay2 - ay1, by2 - by1)
                if y_overlap < min_h * 0.3:
                    continue
                # Check horizontal proximity
                x_gap = max(bx1 - ax2, ax1 - bx2)
                if x_gap <= gap_x:
                    # Merge
                    ax1 = min(ax1, bx1)
                    ay1 = min(ay1, by1)
                    ax2 = max(ax2, bx2)
                    ay2 = max(ay2, by2)
                    used.add(j)
                    merged = True
            new_bboxes.append((ax1, ay1, ax2, ay2))
            used.add(i)
        bboxes = new_bboxes

    return bboxes


def split_wide_sprites(bboxes, arr, c1, c2, max_width=150):
    """Split sprites that are wider than expected by finding internal valleys."""
    result = []
    for bbox in bboxes:
        x1, y1, x2, y2 = bbox
        w = x2 - x1
        if w <= max_width:
            result.append(bbox)
            continue

        # This sprite is too wide - look for internal split points
        strip = arr[y1:y2, x1:x2]
        col_rates, _ = compute_checker_rates(strip, c1, c2, tolerance=28)
        content = (1.0 - col_rates) * (y2 - y1)

        # Find valleys: local minima below 20% of max content
        max_c = content.max()
        if max_c < 5:
            result.append(bbox)
            continue

        valley_threshold = max_c * 0.15
        # Find lowest point in each valley region
        splits = []
        in_valley = False
        valley_min = float('inf')
        valley_pos = 0
        for i in range(len(content)):
            if content[i] < valley_threshold:
                if not in_valley:
                    in_valley = True
                    valley_min = content[i]
                    valley_pos = i
                elif content[i] < valley_min:
                    valley_min = content[i]
                    valley_pos = i
            else:
                if in_valley:
                    in_valley = False
                    # Only split if the valley is between substantial content
                    if valley_pos > 15 and valley_pos < len(content) - 15:
                        splits.append(valley_pos)
                    valley_min = float('inf')

        if not splits:
            result.append(bbox)
            continue

        # Create sub-bboxes at split points
        boundaries = [0] + splits + [w]
        for i in range(len(boundaries) - 1):
            sx1 = x1 + boundaries[i]
            sx2 = x1 + boundaries[i + 1]
            if sx2 - sx1 >= 30:
                result.append((sx1, y1, sx2, y2))

    return result


def find_sprites_grid(content_mask, min_gap_x=6, min_gap_y=6, strip_labels=False, min_size=30,
                      arr=None, c1=None, c2=None, row_splits=None):
    """Find sprite bounding boxes using checker-rate column detection.
    row_splits: list of Y coordinates to split rows (e.g., [160] for a 2-row 320px sheet).
    If None, auto-detect rows."""
    h, w = content_mask.shape

    # Determine row bands
    if row_splits is not None:
        boundaries = [0] + row_splits + [h]
        row_bands = [(boundaries[i], boundaries[i + 1]) for i in range(len(boundaries) - 1)]
    else:
        # Auto-detect rows using smoothed content mask projection
        y_profile = smooth_profile(content_mask.sum(axis=1).astype(float), window=5)
        row_bands = find_spans(y_profile, min_gap=min_gap_y, threshold=w * 0.02)
        if not row_bands:
            row_bands = [(0, h)]

    # For labeled sheets, exclude label area from column detection
    label_margin = 35 if strip_labels else 0

    sprites = []
    for ry1, ry2 in row_bands:
        # Exclude label margin from detection area
        detect_y2 = max(ry1 + 20, ry2 - label_margin)
        detect_h = detect_y2 - ry1

        if arr is not None and c1 is not None:
            # Use checker rates for column detection (robust against gray sprites)
            row_col_rates, _ = compute_checker_rates(arr[ry1:detect_y2], c1, c2, tolerance=28)
            x_profile = smooth_profile((1.0 - row_col_rates) * detect_h, window=3)
            col_spans = find_spans(x_profile, min_gap=3,
                                   threshold=max(detect_h * 0.06, 2))
        else:
            row_mask = content_mask[ry1:detect_y2, :]
            x_profile = smooth_profile(row_mask.sum(axis=0).astype(float), window=7)
            col_spans = find_spans(x_profile, min_gap=min_gap_x,
                                   threshold=max(detect_h * 0.02, 2))

        for cx1, cx2 in col_spans:
            cell = content_mask[ry1:ry2, cx1:cx2]

            # Tight crop within cell
            rows_c = np.where(cell.any(axis=1))[0]
            cols_c = np.where(cell.any(axis=0))[0]
            if len(rows_c) == 0 or len(cols_c) == 0:
                continue

            ty1 = ry1 + rows_c[0]
            ty2 = ry1 + rows_c[-1] + 1
            tx1 = cx1 + cols_c[0]
            tx2 = cx1 + cols_c[-1] + 1

            if strip_labels:
                # Find sprite portion excluding label
                cell_tight = content_mask[ty1:ty2, tx1:tx2]
                sy1, sy2 = find_sprite_region(cell_tight)
                ty1 = ty1 + sy1
                ty2 = ty1 + (sy2 - sy1)

            sprite_w = tx2 - tx1
            sprite_h = ty2 - ty1
            if sprite_w >= min_size and sprite_h >= min_size:
                sprites.append((tx1, ty1, tx2, ty2))

    # Merge nearby fragments
    sprites = merge_nearby_boxes(sprites, gap_x=20, gap_y=10)

    # Split sprites that are too wide (indicates merge through narrow gaps)
    if arr is not None and c1 is not None:
        sprites = split_wide_sprites(sprites, arr, c1, c2, max_width=150)

    return sprites


def find_sprites_components(content_mask, min_area=200, dilate_px=3, strip_labels=False,
                            merge_gap=25, min_dim=40):
    """Find sprite bounding boxes via connected components on dilated mask."""
    h, w = content_mask.shape

    # Dilate to connect nearby pixels
    dilated = content_mask.copy()
    for _ in range(dilate_px):
        new = dilated.copy()
        if h > 1:
            new[1:, :] |= dilated[:-1, :]
            new[:-1, :] |= dilated[1:, :]
        if w > 1:
            new[:, 1:] |= dilated[:, :-1]
            new[:, :-1] |= dilated[:, 1:]
        dilated = new

    # Connected components via flood fill
    labels = np.zeros((h, w), dtype=np.int32)
    components = []
    current = 0

    for y in range(h):
        for x in range(w):
            if dilated[y, x] and labels[y, x] == 0:
                current += 1
                queue = deque([(y, x)])
                labels[y, x] = current
                min_x, min_y = x, y
                max_x, max_y = x, y
                area = 0

                while queue:
                    cy, cx = queue.popleft()
                    area += 1
                    min_x = min(min_x, cx)
                    min_y = min(min_y, cy)
                    max_x = max(max_x, cx)
                    max_y = max(max_y, cy)

                    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and dilated[ny, nx] and labels[ny, nx] == 0:
                            labels[ny, nx] = current
                            queue.append((ny, nx))

                if area >= min_area:
                    components.append((min_x, min_y, max_x + 1, max_y + 1, area))

    # Sort by x position (primary), then y position (secondary)
    # Group into columns: sprites within 30% overlap in X are in the same column
    components.sort(key=lambda c: (c[0], c[1]))

    # Filter: remove tiny components (noise, labels, JPG artifacts)
    if components:
        # Compute sizes, use median to establish baseline
        sizes = sorted(c[4] for c in components)
        median_area = sizes[len(sizes) // 2]
        min_threshold = max(min_area, median_area * 0.05)
        components = [c for c in components if c[4] >= min_threshold]

    result = []
    for cx1, cy1, cx2, cy2, area in components:
        if strip_labels:
            cell = content_mask[cy1:cy2, cx1:cx2]
            sy1, sy2 = find_sprite_region(cell)
            # Only strip if label region is small relative to total
            label_height = (cy2 - cy1) - sy2
            if label_height > 5 and label_height < (cy2 - cy1) * 0.35:
                cy2 = cy1 + sy2
                cy1 = cy1 + sy1

        bw = cx2 - cx1
        bh = cy2 - cy1
        if bw >= min_dim and bh >= min_dim:
            result.append((cx1, cy1, cx2, cy2))

    # Merge overlapping or nearby boxes (creature parts that dilated separately)
    result = merge_nearby_boxes(result, gap_x=merge_gap, gap_y=merge_gap)

    return result


def replace_checker_alpha(crop_arr, c1, c2, tolerance=28):
    """Replace checkerboard background with transparency via edge flood fill.
    Uses both color-distance and gray-range matching to handle JPG intermediates."""
    h, w = crop_arr.shape[:2]
    if h == 0 or w == 0:
        return np.zeros((h, w, 4), dtype=np.uint8)

    farr = crop_arr.astype(float)

    # Method 1: match against specific checker colors
    diff1 = farr - c1.reshape(1, 1, 3)
    diff2 = farr - c2.reshape(1, 1, 3)
    d1 = np.sqrt((diff1 ** 2).sum(axis=2))
    d2 = np.sqrt((diff2 ** 2).sum(axis=2))
    color_match = (d1 < tolerance) | (d2 < tolerance)

    # Method 2: gray-range matching (catches JPG-blended checker intermediates)
    r, g, b = farr[:, :, 0], farr[:, :, 1], farr[:, :, 2]
    lum = (r + g + b) / 3.0
    c1_lum, c2_lum = c1.mean(), c2.mean()
    lo = min(c1_lum, c2_lum) - 12
    hi = max(c1_lum, c2_lum) + 12
    max_dev = np.maximum(np.abs(r - lum), np.maximum(np.abs(g - lum), np.abs(b - lum)))
    gray_match = (lum >= lo) & (lum <= hi) & (max_dev < 18)

    is_bg = color_match | gray_match

    # Flood fill from edges using iterative dilation
    reachable = np.zeros((h, w), dtype=bool)

    # Seed all edge pixels that look like background
    reachable[0, :] = is_bg[0, :]
    reachable[h - 1, :] = is_bg[h - 1, :]
    reachable[:, 0] = is_bg[:, 0]
    reachable[:, w - 1] = is_bg[:, w - 1]

    # Expand iteratively
    max_iter = max(h, w)
    for _ in range(max_iter):
        expanded = reachable.copy()
        expanded[1:, :] |= reachable[:-1, :]
        expanded[:-1, :] |= reachable[1:, :]
        expanded[:, 1:] |= reachable[:, :-1]
        expanded[:, :-1] |= reachable[:, 1:]
        expanded &= is_bg
        if np.array_equal(expanded, reachable):
            break
        reachable = expanded

    # Build RGBA
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = crop_arr
    rgba[:, :, 3] = np.where(reachable, 0, 255).astype(np.uint8)
    return rgba


def tight_crop(rgba):
    """Remove fully transparent rows/columns from edges."""
    alpha = rgba[:, :, 3]
    rows = np.where(alpha.any(axis=1))[0]
    cols = np.where(alpha.any(axis=0))[0]
    if len(rows) == 0 or len(cols) == 0:
        return rgba
    return rgba[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]


def sort_reading_order(bboxes, row_tolerance=None):
    """Sort bounding boxes in reading order: top-to-bottom rows, left-to-right within rows."""
    if not bboxes:
        return bboxes

    # Determine row tolerance from median height
    if row_tolerance is None:
        heights = sorted([b[3] - b[1] for b in bboxes])
        median_h = heights[len(heights) // 2]
        row_tolerance = max(median_h * 0.6, 20)

    # Group into rows by y-center
    rows = []
    for bbox in sorted(bboxes, key=lambda b: (b[1] + b[3]) / 2):
        y_center = (bbox[1] + bbox[3]) / 2
        placed = False
        for row in rows:
            row_y = sum((b[1] + b[3]) / 2 for b in row) / len(row)
            if abs(y_center - row_y) < row_tolerance:
                row.append(bbox)
                placed = True
                break
        if not placed:
            rows.append([bbox])

    # Sort rows by average Y, within each row sort by X
    rows.sort(key=lambda row: sum((b[1] + b[3]) / 2 for b in row) / len(row))
    result = []
    for row in rows:
        row.sort(key=lambda b: b[0])
        result.extend(row)

    return result


# ---------------------------------------------------------------------------
# Sheet configurations
# ---------------------------------------------------------------------------

SHEETS = [
    # === Buildings ===
    {
        'file': 'Build.jpg',
        'outdir': 'buildings',
        'row_splits': [155],  # 1600x320, 2 rows
        'names': [
            'campfire', 'bed', 'workbench', 'kitchen', 'smelter', 'sawmill',
            'research_bench', 'turret_gun', 'farm_plot', 'torch', 'steam_hub', 'solar_panel',
            'campfire_v2', 'bed_v2', 'workbench_v2', 'kitchen_v2', 'sawmill_v2',
            'research_bench_v2', 'turret_gun_v2', 'farm_plot_v2', 'torch_v2',
            'steam_hub_v2', 'solar_panel_v2',
        ],
        'has_labels': True,
    },
    {
        'file': 'build2.jpg',
        'outdir': 'buildings',
        'names': [
            'coal_burner', 'thermal_gen', 'wind_turbine', 'nuclear_reactor',
            'heater', 'butcher_table', 'drug_lab', 'forge', 'tannery',
            'deep_drill', 'air_purifier', 'cloning_vat', 'radio_beacon', 'shield_generator',
        ],
        'has_labels': True,
    },
    {
        'file': 'build3.jpg',
        'outdir': 'buildings',
        'row_splits': [210],  # main row + small variant row at bottom
        'names': [
            'loom', 'smokehouse', 'stone_cutter', 'kiln', 'refinery',
            'surgery_table', 'expedition_table', 'quest_board', 'greenhouse',
            'memorial', 'standing_lamp', 'water_pump', 'oil_refinery', 'steam_boiler',
            'water_pump_v2', 'oil_refinery_v2', 'steam_boiler_v2',
        ],
        'has_labels': True,
    },
    {
        'file': 'buildpowerpipe.jpg',
        'outdir': 'buildings',
        'row_splits': [210],
        'names': [
            'fire_pit', 'deep_fire_pit', 'bio_reactor', 'mini_reactor',
            'hand_crank', 'treadmill', 'chain_gang_wheel', 'waste_incinerator',
            'lightning_rod', 'thermopile', 'ichor_burner', 'small_pipe', 'large_pipe', 'insulated_pipe',
            'small_pipe_v2', 'large_pipe_v2', 'insulated_pipe_v2',
        ],
        'has_labels': True,
    },

    # === Creatures ===
    {
        'file': 'Creat.jpg',
        'outdir': 'creatures',
        'method': 'components',
        'names': [
            'frost_hare', 'ice_fox', 'tundra_wolf', 'glacier_bear',
            'stalker', 'mammoth', 'frost_titan', 'the_pale_thing',
        ],
        'has_labels': True,
    },
    {
        'file': 'creat2.jpg',
        'outdir': 'creatures',
        'method': 'components',
        'names': [
            'snow_grouse', 'frost_beetle', 'ice_locust', 'skitterer',
            'dire_wolf', 'giant_rat', 'spawnling',
            'sabertooth', 'ice_stalker', 'snow_ape', 'ice_brute', 'shade',
        ],
        'has_labels': True,
    },
    {
        'file': 'Creat3.jpg',
        'outdir': 'creatures',
        'method': 'components',
        'names': [
            'fleshwalker', 'gore_shoat', 'weeping_calf', 'husk_pup',
            'pit_wyrm', 'void_minnow', 'bile_mold', 'thorn_polyp',
            'nerve_cluster', 'rot_bloom',
            'the_bull', 'the_stalker_boss', 'that_which_sleeps',
        ],
        'has_labels': True,
    },

    # === Colonists ===
    {
        'file': 'Colonist.jpg',
        'outdir': 'colonists',
        'names': ['idle', 'walking', 'working', 'sleeping', 'dead'],
    },
    {
        'file': 'colonist2.jpg',
        'outdir': 'colonists',
        'names': ['eating', 'mental_break', 'freezing', 'armed_melee', 'armed_ranged', 'armored'],
        'has_labels': True,
    },
    {
        'file': 'Colonist3.jpg',
        'outdir': 'colonists',
        'names': ['carrying', 'mining', 'building_col', 'cooking', 'researching', 'medical'],
        'has_labels': True,
    },

    # === Items ===
    {
        'file': 'item.jpg',
        'outdir': 'items',
        'row_splits': [160],
        'names': [
            'wood', 'stone', 'metal', 'bread', 'water', 'fuel', 'fuel_cell',
            'components', 'steel', 'medicine', 'leather', 'raw_meat', 'coal',
            'void_crystal', 'eldritch_ichor', 'cloth', 'herbal_medicine',
            'wood_v2', 'stone_v2', 'metal_v2', 'bread_v2', 'water_v2', 'fuel_v2', 'fuel_cell_v2',
            'components_v2', 'steel_v2', 'medicine_v2', 'leather_v2', 'raw_meat_v2', 'coal_v2',
            'void_crystal_v2', 'eldritch_ichor_v2', 'cloth_v2', 'herbal_medicine_v2',
        ],
    },
    {
        'file': 'Item2.jpg',
        'outdir': 'items',
        'row_splits': [160],
        'prefix': 'item2',
        'names': [],  # numbered fallback
    },
    {
        'file': 'Item3.jpg',
        'outdir': 'items',
        'row_splits': [160],
        'prefix': 'item3',
        'names': [],  # numbered fallback
    },

    # === Tiles ===
    # Tiles.jpg: terrain tiles on checker (row 1), floor/wall tiles edge-to-edge (row 2)
    {
        'file': 'Tiles.jpg',
        'outdir': 'tiles',
        'opaque': True,
        'manual_boxes': [
            # Row 1 terrain tiles (y=0-190, on checkerboard)
            (0, 0, 220, 145),       # snow
            (228, 4, 418, 145),     # ice
            (422, 4, 612, 145),     # rock
            (628, 10, 788, 185),    # tree_1
            (798, 10, 958, 185),    # tree_2
            (1005, 4, 1195, 165),   # ore_vein
            # Row 2 floor/wall tiles (y=290-470, edge-to-edge)
            (0, 292, 198, 468),     # wall_wood
            (202, 292, 402, 468),   # wall_stone
            (408, 292, 604, 468),   # floor_wood
            (612, 292, 800, 468),   # floor_stone
            (1002, 292, 1202, 468), # door
            (1212, 292, 1405, 468), # debris
        ],
        'names': [
            'snow', 'ice', 'rock', 'tree_1', 'tree_2', 'ore_vein',
            'wall_wood', 'wall_stone', 'floor_wood', 'floor_stone', 'door', 'debris',
        ],
    },
    {
        'file': 'Tiles2.jpg',
        'outdir': 'tiles',
        'fixed_cols': 10,
        'names': [
            'wall_metal', 'wall_insulated', 'floor_metal', 'floor_insulated',
            'door_sealed', 'permafrost', 'dirt', 'water_tile', 'lava_vent', 'void',
        ],
        'opaque': True,
    },
    {
        'file': 'Tiles3.jpg',
        'outdir': 'tiles',
        'fixed_cols': 6,
        'names': ['snow_heavy', 'ice_cracked', 'scorched', 'mud', 'moss_stone', 'metal_grate'],
        'opaque': True,
    },

    # === Defense ===
    {
        'file': 'defense.jpg',
        'outdir': 'defense',
        'row_splits': [160],
        'names': [
            'turret_ballista', 'turret_minigun', 'turret_flamethrower', 'turret_tesla',
            'turret_rocket', 'mortar', 'spike_trap', 'barricade', 'steel_barrier', 'watchtower',
            'spike_trap_v2', 'bear_trap', 'pit_trap', 'incendiary_trap', 'razor_wire',
            'frag_mine', 'barricade_v2', 'steel_barrier_v2', 'watchtower_v2',
        ],
        'has_labels': True,
    },
    {
        'file': 'defense2.jpg',
        'outdir': 'defense',
        'row_splits': [160],
        'names': [
            'turret_crossbow', 'turret_shotgun', 'turret_sniper', 'turret_autocannon',
            'turret_cryo', 'turret_laser', 'turret_railgun', 'turret_emp', 'turret_grenade_launcher',
            'snare_trap', 'spring_blade', 'acid_trap', 'cryo_mine', 'gas_trap',
            'caltrops', 'claymore', 'tripwire_alarm', 'tripwire_ied',
        ],
        'has_labels': True,
    },

    # === Weapons ===
    {
        'file': 'weapons.jpg',
        'outdir': 'weapons',
        'min_size': 10,
        'names': [
            'club', 'shiv', 'pipe_wrench', 'knife', 'hatchet', 'machete',
            'spear', 'sword_wpn', 'bow', 'crossbow_wpn', 'pistol', 'revolver',
            'bolt_action', 'pump_shotgun', 'assault_rifle', 'battle_rifle',
        ],
    },

    # === Plants ===
    {
        'file': 'plants.jpg',
        'outdir': 'crops',
        'row_splits': [180, 360, 540],  # 1456x720, 4 rows (seed/grow/mature/wilted)
        'names': [
            'frost_wheat_seed', 'thermal_berries_seed', 'alien_fungus_seed',
            'medicinal_moss_seed', 'fiber_vine_seed', 'psychoid_plant_seed',
            'smokeleaf_plant_seed', 'hops_plant_seed',
            'frost_wheat_grow', 'thermal_berries_grow', 'alien_fungus_grow',
            'medicinal_moss_grow', 'fiber_vine_grow', 'psychoid_plant_grow',
            'smokeleaf_plant_grow', 'hops_plant_grow',
            'frost_wheat_mature', 'thermal_berries_mature', 'alien_fungus_mature',
            'medicinal_moss_mature', 'fiber_vine_mature', 'psychoid_plant_mature',
            'smokeleaf_plant_mature', 'hops_plant_mature',
            'frost_wheat_wilted', 'thermal_berries_wilted', 'alien_fungus_wilted',
            'medicinal_moss_wilted', 'fiber_vine_wilted', 'psychoid_plant_wilted',
            'smokeleaf_plant_wilted', 'hops_plant_wilted',
        ],
        'has_labels': True,
    },

    # === UI ===
    {
        'file': 'UI.jpg',
        'outdir': 'ui',
        'row_splits': [160],
        'names': [
            'pickaxe', 'hammer', 'box_arrow', 'pot', 'crosshair',
            'flask', 'red_cross', 'sword', 'thermometer', 'moon',
            'pickaxe_v2', 'hammer_v2', 'box_arrow_v2', 'pot_v2', 'crosshair_v2',
            'flask_v2', 'red_cross_v2', 'sword_v2', 'thermometer_v2', 'moon_v2',
        ],
    },
    {
        'file': 'ui2.jpg',
        'outdir': 'ui',
        'names': [
            'broom', 'wrench', 'basket', 'water_drop', 'smiley', 'skull',
            'snowflake', 'pill', 'biohazard', 'shield', 'gear', 'lightning',
        ],
    },
]


# ---------------------------------------------------------------------------
# Processing pipeline
# ---------------------------------------------------------------------------

def process_sheet(config, dry_run=False):
    """Process a single sprite sheet: detect sprites, extract, save."""
    path = os.path.join(DOWNLOADS, config['file'])
    if not os.path.exists(path):
        print(f"  SKIP: {config['file']} not found")
        return []

    print(f"\n=== {config['file']} -> {config['outdir']}/ ===")

    img = Image.open(path).convert('RGB')
    arr = np.array(img)
    h, w = arr.shape[:2]
    print(f"  Sheet size: {w}x{h}")

    # Detect background
    c1, c2 = detect_checker_colors(arr)
    print(f"  Checker colors: ({c1[0]:.0f},{c1[1]:.0f},{c1[2]:.0f}) / ({c2[0]:.0f},{c2[1]:.0f},{c2[2]:.0f})")

    # Content mask
    content = make_content_mask(arr, c1, c2, tolerance=30)
    content_pct = content.sum() / content.size * 100
    print(f"  Content coverage: {content_pct:.1f}%")

    # Find sprites
    method = config.get('method', 'grid')
    strip_labels = config.get('has_labels', False)
    min_gap_x = config.get('min_gap_x', 5)
    min_gap_y = config.get('min_gap_y', 8)

    row_splits = config.get('row_splits', None)
    min_size = config.get('min_size', 30)

    fixed_cols = config.get('fixed_cols', None)
    manual_boxes = config.get('manual_boxes', None)

    if manual_boxes:
        bboxes = [tuple(b) for b in manual_boxes]
    elif method == 'components':
        bboxes = find_sprites_components(content, min_area=150, dilate_px=4, strip_labels=strip_labels,
                                         merge_gap=5, min_dim=40)
    elif fixed_cols:
        # Fixed grid: divide each row into equal-width columns
        if row_splits is not None:
            boundaries = [0] + row_splits + [h]
            row_bands = [(boundaries[i], boundaries[i + 1]) for i in range(len(boundaries) - 1)]
        else:
            row_bands = [(0, h)]
        col_w = w / fixed_cols
        bboxes = []
        for ry1, ry2 in row_bands:
            for c in range(fixed_cols):
                cx1 = int(round(c * col_w))
                cx2 = int(round((c + 1) * col_w))
                bboxes.append((cx1, ry1, cx2, ry2))
    else:
        bboxes = find_sprites_grid(content, min_gap_x=min_gap_x, min_gap_y=min_gap_y,
                                   strip_labels=strip_labels, arr=arr, c1=c1, c2=c2,
                                   row_splits=row_splits, min_size=min_size)

    # Sort in reading order
    bboxes = sort_reading_order(bboxes)

    names = config.get('names', [])
    prefix = config.get('prefix', '')
    is_opaque = config.get('opaque', False)

    print(f"  Found {len(bboxes)} sprites (expected {len(names) if names else '?'})")

    if not bboxes:
        print("  WARNING: No sprites detected!")
        return []

    # Report bounding boxes
    for i, (x1, y1, x2, y2) in enumerate(bboxes):
        name = names[i] if i < len(names) else f"{prefix}_sprite_{i:03d}" if prefix else f"sprite_{i:03d}"
        print(f"    [{i:2d}] {name}: ({x1},{y1})-({x2},{y2}) = {x2 - x1}x{y2 - y1}")

    if dry_run:
        return bboxes

    # Extract and save
    outdir = os.path.join(OUTPUT_ROOT, config['outdir'])
    os.makedirs(outdir, exist_ok=True)
    saved = []

    for i, (x1, y1, x2, y2) in enumerate(bboxes):
        name = names[i] if i < len(names) else f"{prefix}_sprite_{i:03d}" if prefix else f"sprite_{i:03d}"

        # Crop from original image
        crop = arr[y1:y2, x1:x2].copy()

        if is_opaque:
            # Tiles: keep opaque, just save as RGBA with full alpha
            rgba = np.zeros((*crop.shape[:2], 4), dtype=np.uint8)
            rgba[:, :, :3] = crop
            rgba[:, :, 3] = 255
        else:
            # Replace checkerboard with transparency
            rgba = replace_checker_alpha(crop, c1, c2, tolerance=28)

        # Tight crop
        rgba = tight_crop(rgba)

        if rgba.shape[0] < 2 or rgba.shape[1] < 2:
            print(f"    SKIP {name}: too small after crop ({rgba.shape[1]}x{rgba.shape[0]})")
            continue

        # Skip sprites that are mostly transparent (false detections)
        if not is_opaque:
            total_px = rgba.shape[0] * rgba.shape[1]
            opaque_px = (rgba[:, :, 3] > 0).sum()
            content_ratio = opaque_px / total_px if total_px > 0 else 0
            if content_ratio < 0.16:
                print(f"    SKIP {name}: only {content_ratio:.0%} content ({rgba.shape[1]}x{rgba.shape[0]})")
                continue

        out_path = os.path.join(outdir, name + '.png')
        out_img = Image.fromarray(rgba, 'RGBA')
        out_img.save(out_path)
        saved.append((name, rgba.shape[1], rgba.shape[0]))

    print(f"  Saved {len(saved)} sprites to {outdir}/")
    return saved


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    dry_run = '--dry-run' in sys.argv
    sheet_filter = None
    for arg in sys.argv[1:]:
        if arg.startswith('--sheet='):
            sheet_filter = arg.split('=', 1)[1].lower()

    if dry_run:
        print("DRY RUN: detecting sprites without saving")
    print(f"Output: {OUTPUT_ROOT}")
    os.makedirs(OUTPUT_ROOT, exist_ok=True)

    total_saved = 0
    for config in SHEETS:
        if sheet_filter and sheet_filter not in config['file'].lower():
            continue
        result = process_sheet(config, dry_run=dry_run)
        if not dry_run:
            total_saved += len(result)

    if not dry_run:
        print(f"\nDone! Saved {total_saved} sprites total to {OUTPUT_ROOT}/")
    else:
        print("\nDry run complete. Use without --dry-run to save sprites.")


if __name__ == '__main__':
    main()
