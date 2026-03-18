"""
regen_sprites.py — Regenerate broken creature sprites as clean 96x96 pixel art.
Leaves good sprites untouched. Uses species color/size from species_defs.
"""

import os
import math
import random
from PIL import Image, ImageDraw

SPRITE_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', 'creatures')
SIZE = 96

# Species data extracted from species_defs.lua: {id: (color_rgb_0_1, size, shape_hint)}
# shape_hint: 'rabbit', 'bird', 'canine', 'feline', 'bear', 'humanoid', 'insect',
#             'worm', 'blob', 'tentacle', 'brute', 'mammoth', 'boss'
SPECIES = {
    # BROKEN sprites to regenerate:
    'frost_beetle':     ((0.4, 0.5, 0.6),    0.3,  'insect'),
    'ice_locust':       ((0.5, 0.6, 0.7),    0.25, 'insect'),
    'snow_grouse':      ((0.85, 0.8, 0.75),  0.3,  'bird'),
    'skitterer':        ((0.5, 0.55, 0.7),   0.35, 'insect'),
    'spawnling':        ((0.3, 0.25, 0.2),   0.6,  'insect'),
    'giant_rat':        ((0.4, 0.35, 0.3),   0.25, 'rodent'),
    'dire_wolf':        ((0.35, 0.35, 0.4),  0.85, 'canine'),
    'ice_brute':        ((0.45, 0.5, 0.65),  1.5,  'brute'),
    'snow_ape':         ((0.75, 0.78, 0.82), 1.3,  'brute'),
    'sabertooth':       ((0.6, 0.5, 0.35),   0.9,  'feline'),
    'ice_stalker':      ((0.4, 0.5, 0.6),    0.8,  'feline'),
    'fleshwalker':      ((0.0, 0.0, 0.05),   2.5,  'humanoid'),
    'gore_shoat':       ((0.6, 0.15, 0.1),   0.4,  'blob'),
    'weeping_calf':     ((0.2, 0.05, 0.3),   0.5,  'blob'),
    'husk_pup':         ((0.4, 0.35, 0.25),  0.35, 'canine'),
    'void_minnow':      ((0.05, 0.0, 0.1),   0.2,  'blob'),
    'pit_wyrm':         ((0.3, 0.1, 0.15),   0.2,  'worm'),
    'bile_mold':        ((0.3, 0.4, 0.05),   0.25, 'blob'),
    'thorn_polyp':      ((0.35, 0.25, 0.2),  0.3,  'blob'),
    'nerve_cluster':    ((0.15, 0.05, 0.2),  0.2,  'blob'),
    'rot_bloom':        ((0.25, 0.15, 0.1),  0.3,  'blob'),
    'the_bull':         ((0.4, 0.35, 0.3),   2.2,  'brute'),
    'the_stalker_boss': ((0.15, 0.1, 0.1),   1.6,  'humanoid'),
    'that_which_sleeps':((0.2, 0.3, 0.5),    5.0,  'tentacle'),
    'void_minnow_lg':   ((0.05, 0.0, 0.1),   1.0,  'blob'),
    'pit_wyrm_lg':      ((0.3, 0.1, 0.15),   1.0,  'worm'),
    'ice_fox_sm':       ((0.7, 0.75, 0.85),  0.35, 'canine'),
}

# Good sprites — DO NOT TOUCH
KEEP = {
    'frost_hare', 'ice_fox', 'tundra_wolf', 'glacier_bear',
    'stalker', 'mammoth', 'frost_titan', 'the_pale_thing', 'shade',
}


def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))


def color_to_rgb(c):
    """Convert 0-1 float tuple to 0-255 int tuple."""
    return (clamp(c[0] * 255), clamp(c[1] * 255), clamp(c[2] * 255))


def darken(rgb, factor=0.6):
    return (clamp(rgb[0] * factor), clamp(rgb[1] * factor), clamp(rgb[2] * factor))


def lighten(rgb, factor=1.4):
    return (clamp(rgb[0] * factor), clamp(rgb[1] * factor), clamp(rgb[2] * factor))


def draw_outline(draw, points, color, width=1):
    """Draw a polygon outline."""
    for i in range(len(points)):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % len(points)]
        draw.line([(x1, y1), (x2, y2)], fill=color, width=width)


def draw_eyes(draw, cx, cy, size, eye_color=(255, 255, 255), pupil_color=(20, 20, 20), spacing=None):
    """Draw a pair of eyes."""
    if spacing is None:
        spacing = max(2, int(size * 0.3))
    eye_r = max(1, int(size * 0.08))
    pupil_r = max(1, eye_r - 1) if eye_r > 1 else 1

    for dx in [-spacing, spacing]:
        ex, ey = cx + dx, cy
        draw.ellipse([ex - eye_r, ey - eye_r, ex + eye_r, ey + eye_r], fill=eye_color)
        if pupil_r < eye_r:
            draw.ellipse([ex - pupil_r, ey - pupil_r, ex + pupil_r, ey + pupil_r], fill=pupil_color)


def generate_insect(draw, cx, cy, body_size, rgb, outline):
    """Bug/beetle shape: oval body, small head, antennae, legs."""
    bs = body_size
    # Body (oval)
    draw.ellipse([cx - bs, cy - bs * 0.6, cx + bs, cy + bs * 0.6], fill=rgb, outline=outline, width=2)
    # Head
    head_r = bs * 0.4
    hx = cx - bs - head_r * 0.5
    draw.ellipse([hx - head_r, cy - head_r, hx + head_r, cy + head_r], fill=lighten(rgb), outline=outline, width=2)
    # Legs (3 per side)
    leg_col = outline
    for i in range(3):
        lx = cx - bs * 0.6 + i * bs * 0.6
        for dy in [-1, 1]:
            ly = cy + dy * bs * 0.6
            draw.line([(lx, ly), (lx + bs * 0.2 * dy, ly + dy * bs * 0.5)], fill=leg_col, width=2)
    # Antennae
    draw.line([(hx - head_r * 0.3, cy - head_r), (hx - head_r * 0.8, cy - head_r - bs * 0.4)], fill=leg_col, width=1)
    draw.line([(hx + head_r * 0.3, cy - head_r), (hx + head_r * 0.5, cy - head_r - bs * 0.4)], fill=leg_col, width=1)
    # Eyes
    draw_eyes(draw, hx, cy - head_r * 0.2, head_r, spacing=max(1, int(head_r * 0.4)))


def generate_bird(draw, cx, cy, body_size, rgb, outline):
    """Bird shape: round body, small head, beak, tail."""
    bs = body_size
    # Body
    draw.ellipse([cx - bs, cy - bs * 0.65, cx + bs * 0.6, cy + bs * 0.65], fill=rgb, outline=outline, width=2)
    # Head
    head_r = bs * 0.45
    hx = cx - bs - head_r * 0.4
    hy = cy - bs * 0.3
    draw.ellipse([hx - head_r, hy - head_r, hx + head_r, hy + head_r], fill=lighten(rgb), outline=outline, width=2)
    # Beak
    beak_tip = (hx - head_r - bs * 0.3, hy)
    draw.polygon([(hx - head_r, hy - head_r * 0.3), beak_tip, (hx - head_r, hy + head_r * 0.3)],
                 fill=(200, 160, 50), outline=outline)
    # Tail feathers
    tx = cx + bs * 0.6
    draw.polygon([(tx, cy - bs * 0.2), (tx + bs * 0.5, cy - bs * 0.4),
                  (tx + bs * 0.4, cy), (tx + bs * 0.5, cy + bs * 0.4),
                  (tx, cy + bs * 0.2)], fill=darken(rgb), outline=outline)
    # Eye
    draw_eyes(draw, hx - head_r * 0.1, hy - head_r * 0.1, head_r, spacing=0)
    # Legs
    for dx in [-bs * 0.3, bs * 0.1]:
        draw.line([(cx + dx, cy + bs * 0.65), (cx + dx, cy + bs * 0.65 + bs * 0.5)], fill=outline, width=2)


def generate_canine(draw, cx, cy, body_size, rgb, outline):
    """Canine shape: elongated body, pointed head, tail, 4 legs."""
    bs = body_size
    # Body
    draw.ellipse([cx - bs, cy - bs * 0.55, cx + bs * 0.7, cy + bs * 0.55], fill=rgb, outline=outline, width=2)
    # Head (pointed)
    head_r = bs * 0.45
    hx = cx - bs - head_r * 0.3
    hy = cy - bs * 0.1
    draw.ellipse([hx - head_r, hy - head_r * 0.8, hx + head_r, hy + head_r * 0.8], fill=lighten(rgb), outline=outline, width=2)
    # Snout
    draw.polygon([(hx - head_r, hy - head_r * 0.3), (hx - head_r - bs * 0.3, hy),
                  (hx - head_r, hy + head_r * 0.3)], fill=darken(rgb), outline=outline)
    # Ears
    for dy in [-1, 1]:
        ear_y = hy - head_r * 0.8
        ear_x = hx + dy * head_r * 0.3
        draw.polygon([(ear_x, ear_y), (ear_x + dy * head_r * 0.3, ear_y - head_r * 0.5),
                      (ear_x + dy * head_r * 0.6, ear_y)], fill=rgb, outline=outline)
    # Tail
    tx = cx + bs * 0.7
    draw.arc([tx, cy - bs * 0.8, tx + bs * 0.6, cy + bs * 0.2], 0, 270, fill=outline, width=2)
    # Legs
    for lx_off in [-bs * 0.6, -bs * 0.2, bs * 0.2, bs * 0.5]:
        draw.line([(cx + lx_off, cy + bs * 0.55), (cx + lx_off, cy + bs * 0.55 + bs * 0.4)], fill=outline, width=2)
    # Eyes
    draw_eyes(draw, hx - head_r * 0.2, hy - head_r * 0.2, head_r, spacing=max(1, int(head_r * 0.3)))


def generate_feline(draw, cx, cy, body_size, rgb, outline):
    """Cat/feline shape: sleek body, round head, pointy ears, long tail."""
    bs = body_size
    # Body (sleeker than canine)
    draw.ellipse([cx - bs * 0.9, cy - bs * 0.45, cx + bs * 0.7, cy + bs * 0.45], fill=rgb, outline=outline, width=2)
    # Head
    head_r = bs * 0.4
    hx = cx - bs * 0.9 - head_r * 0.2
    hy = cy - bs * 0.05
    draw.ellipse([hx - head_r, hy - head_r, hx + head_r, hy + head_r], fill=lighten(rgb), outline=outline, width=2)
    # Ears (pointed)
    for dy in [-1, 1]:
        ear_x = hx + dy * head_r * 0.5
        ear_y = hy - head_r
        draw.polygon([(ear_x - head_r * 0.2, ear_y),
                      (ear_x, ear_y - head_r * 0.7),
                      (ear_x + head_r * 0.2, ear_y)], fill=rgb, outline=outline)
    # Tail (long curve)
    tx = cx + bs * 0.7
    points = []
    for t in range(20):
        frac = t / 19.0
        px = tx + frac * bs * 0.8
        py = cy - math.sin(frac * math.pi) * bs * 0.6
        points.append((px, py))
    if len(points) > 1:
        draw.line(points, fill=outline, width=2)
    # Legs
    for lx_off in [-bs * 0.5, -bs * 0.15, bs * 0.2, bs * 0.5]:
        draw.line([(cx + lx_off, cy + bs * 0.45), (cx + lx_off, cy + bs * 0.45 + bs * 0.35)], fill=outline, width=2)
    # Eyes (feline = green glow)
    draw_eyes(draw, hx - head_r * 0.1, hy - head_r * 0.15, head_r,
              eye_color=(180, 255, 100), pupil_color=(20, 20, 20),
              spacing=max(1, int(head_r * 0.35)))


def generate_brute(draw, cx, cy, body_size, rgb, outline):
    """Large humanoid brute: wide torso, thick arms, small head."""
    bs = body_size
    # Torso
    draw.rectangle([cx - bs * 0.6, cy - bs * 0.5, cx + bs * 0.6, cy + bs * 0.5], fill=rgb, outline=outline, width=2)
    # Head
    head_r = bs * 0.25
    hy = cy - bs * 0.5 - head_r
    draw.ellipse([cx - head_r, hy - head_r, cx + head_r, hy + head_r], fill=lighten(rgb), outline=outline, width=2)
    # Arms
    for dx in [-1, 1]:
        ax = cx + dx * bs * 0.6
        ax2 = ax + dx * bs * 0.3
        arm_x0, arm_x1 = min(ax, ax2), max(ax, ax2)
        draw.rectangle([arm_x0, cy - bs * 0.4, arm_x1, cy + bs * 0.3], fill=darken(rgb), outline=outline, width=2)
        # Fist
        fist_cx = ax + dx * bs * 0.1
        draw.ellipse([fist_cx - bs * 0.12, cy + bs * 0.2,
                      fist_cx + bs * 0.12, cy + bs * 0.45], fill=darken(rgb), outline=outline, width=2)
    # Legs
    for dx in [-1, 1]:
        lx = cx + dx * bs * 0.25
        draw.rectangle([lx - bs * 0.15, cy + bs * 0.5, lx + bs * 0.15, cy + bs * 0.5 + bs * 0.35],
                       fill=darken(rgb), outline=outline, width=2)
    # Eyes
    draw_eyes(draw, cx, hy - head_r * 0.1, head_r * 2,
              eye_color=(255, 200, 100), pupil_color=(180, 30, 30),
              spacing=max(2, int(head_r * 0.5)))


def generate_humanoid(draw, cx, cy, body_size, rgb, outline):
    """Tall humanoid: thin, menacing."""
    bs = body_size
    # Torso
    draw.polygon([(cx - bs * 0.35, cy - bs * 0.4),
                  (cx + bs * 0.35, cy - bs * 0.4),
                  (cx + bs * 0.25, cy + bs * 0.4),
                  (cx - bs * 0.25, cy + bs * 0.4)], fill=rgb, outline=outline, width=2)
    # Head
    head_r = bs * 0.2
    hy = cy - bs * 0.4 - head_r
    draw.ellipse([cx - head_r, hy - head_r, cx + head_r, hy + head_r], fill=lighten(rgb), outline=outline, width=2)
    # Arms (long, thin)
    for dx in [-1, 1]:
        ax = cx + dx * bs * 0.35
        points = [(ax, cy - bs * 0.35),
                  (ax + dx * bs * 0.15, cy),
                  (ax + dx * bs * 0.05, cy + bs * 0.35)]
        draw.line(points, fill=outline, width=3)
        # Claw
        for i in range(3):
            angle = -0.3 + i * 0.3
            claw_len = bs * 0.15
            cx2 = points[-1][0] + math.cos(angle) * claw_len * dx
            cy2 = points[-1][1] + math.sin(angle) * claw_len + claw_len * 0.5
            draw.line([points[-1], (cx2, cy2)], fill=outline, width=2)
    # Legs
    for dx in [-1, 1]:
        lx = cx + dx * bs * 0.15
        draw.line([(lx, cy + bs * 0.4), (lx + dx * bs * 0.1, cy + bs * 0.4 + bs * 0.35)], fill=outline, width=3)
    # Eyes (glowing red)
    draw_eyes(draw, cx, hy - head_r * 0.1, head_r * 2,
              eye_color=(255, 50, 50), pupil_color=(255, 0, 0),
              spacing=max(2, int(head_r * 0.5)))


def generate_blob(draw, cx, cy, body_size, rgb, outline):
    """Amorphous blob: irregular round shape with smaller bumps."""
    bs = body_size
    # Main body
    draw.ellipse([cx - bs, cy - bs * 0.7, cx + bs, cy + bs * 0.7], fill=rgb, outline=outline, width=2)
    # Bumps
    random.seed(hash(rgb))
    for _ in range(4):
        angle = random.uniform(0, math.pi * 2)
        dist = bs * random.uniform(0.5, 0.8)
        bx = cx + math.cos(angle) * dist
        by = cy + math.sin(angle) * dist * 0.7
        br = bs * random.uniform(0.2, 0.35)
        draw.ellipse([bx - br, by - br, bx + br, by + br], fill=lighten(rgb, 1.2), outline=outline, width=1)
    # Eyes (if big enough)
    if bs > 8:
        draw_eyes(draw, cx, cy - bs * 0.15, bs, spacing=max(2, int(bs * 0.25)))


def generate_worm(draw, cx, cy, body_size, rgb, outline):
    """Worm/serpent: segmented curved body."""
    bs = body_size
    segments = 8
    seg_r = bs * 0.3
    for i in range(segments):
        frac = i / (segments - 1)
        sx = cx - bs + frac * bs * 2
        sy = cy + math.sin(frac * math.pi * 2) * bs * 0.3
        # Taper
        sr = seg_r * (1.0 - abs(frac - 0.3) * 0.6)
        sr = max(2, sr)
        col = lighten(rgb, 1.0 + frac * 0.2) if i % 2 == 0 else rgb
        draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=col, outline=outline, width=1)
    # Head (first segment, slightly larger)
    hx = cx - bs
    hy = cy
    hr = seg_r * 1.2
    draw.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=lighten(rgb), outline=outline, width=2)
    # Eyes
    if hr > 3:
        draw_eyes(draw, hx, hy - hr * 0.2, hr, spacing=max(1, int(hr * 0.4)))


def generate_tentacle(draw, cx, cy, body_size, rgb, outline):
    """Eldritch mass: central body with tentacles."""
    bs = body_size
    # Tentacles first (behind body)
    random.seed(42)
    for i in range(8):
        angle = i * math.pi * 2 / 8
        points = []
        for t in range(10):
            frac = t / 9.0
            dist = bs * 0.4 + frac * bs * 0.6
            wobble = math.sin(frac * math.pi * 3 + i) * bs * 0.15
            px = cx + math.cos(angle + wobble * 0.02) * dist
            py = cy + math.sin(angle + wobble * 0.02) * dist
            points.append((px, py))
        if len(points) > 1:
            # Taper width
            for j in range(len(points) - 1):
                w = max(1, int(3 * (1 - j / len(points))))
                draw.line([points[j], points[j + 1]], fill=darken(rgb), width=w)
    # Central body
    draw.ellipse([cx - bs * 0.4, cy - bs * 0.4, cx + bs * 0.4, cy + bs * 0.4],
                 fill=rgb, outline=outline, width=2)
    # Eye (single central)
    eye_r = max(3, int(bs * 0.15))
    draw.ellipse([cx - eye_r, cy - eye_r, cx + eye_r, cy + eye_r], fill=(255, 220, 180))
    pupil_r = max(1, eye_r - 2)
    draw.ellipse([cx - pupil_r, cy - pupil_r * 2, cx + pupil_r, cy + pupil_r * 2],
                 fill=(180, 30, 30))


def generate_rodent(draw, cx, cy, body_size, rgb, outline):
    """Rat: small oval body, round ears, long tail."""
    bs = body_size
    # Body
    draw.ellipse([cx - bs * 0.8, cy - bs * 0.5, cx + bs * 0.6, cy + bs * 0.5], fill=rgb, outline=outline, width=2)
    # Head
    head_r = bs * 0.35
    hx = cx - bs * 0.8 - head_r * 0.3
    draw.ellipse([hx - head_r, cy - head_r, hx + head_r, cy + head_r], fill=lighten(rgb), outline=outline, width=2)
    # Ears (round)
    for dy in [-1, 1]:
        ear_x = hx + dy * head_r * 0.4
        ear_y = cy - head_r
        ear_r = head_r * 0.35
        draw.ellipse([ear_x - ear_r, ear_y - ear_r * 1.3, ear_x + ear_r, ear_y + ear_r * 0.5],
                     fill=(200, 150, 150), outline=outline)
    # Nose
    draw.ellipse([hx - head_r - 2, cy - 2, hx - head_r + 3, cy + 2], fill=(200, 120, 120))
    # Tail
    tx = cx + bs * 0.6
    points = []
    for t in range(15):
        frac = t / 14.0
        px = tx + frac * bs * 1.0
        py = cy + math.sin(frac * math.pi * 1.5) * bs * 0.3
        points.append((px, py))
    if len(points) > 1:
        draw.line(points, fill=outline, width=1)
    # Legs
    for lx in [-bs * 0.4, 0, bs * 0.3]:
        draw.line([(cx + lx, cy + bs * 0.5), (cx + lx, cy + bs * 0.5 + bs * 0.25)], fill=outline, width=1)
    # Eyes
    draw_eyes(draw, hx - head_r * 0.2, cy - head_r * 0.2, head_r, spacing=max(1, int(head_r * 0.3)))


GENERATORS = {
    'insect': generate_insect,
    'bird': generate_bird,
    'canine': generate_canine,
    'feline': generate_feline,
    'brute': generate_brute,
    'humanoid': generate_humanoid,
    'blob': generate_blob,
    'worm': generate_worm,
    'tentacle': generate_tentacle,
    'rodent': generate_rodent,
}


def generate_sprite(species_id, color_01, size_factor, shape):
    """Generate a single 96x96 creature sprite."""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    rgb = color_to_rgb(color_01)
    outline = darken(rgb, 0.4)

    cx = SIZE // 2
    cy = SIZE // 2

    # Scale body size: small creatures are small in the sprite, large ones fill it
    # Map size_factor to pixel body size (clamped to fit in 96x96 with margin)
    body_size = max(8, min(40, int(size_factor * 22)))

    gen = GENERATORS.get(shape, generate_blob)
    gen(draw, cx, cy, body_size, rgb, outline)

    return img


def main():
    os.makedirs(SPRITE_DIR, exist_ok=True)

    generated = 0
    skipped = 0

    for species_id, (color, size, shape) in sorted(SPECIES.items()):
        path = os.path.join(SPRITE_DIR, species_id + '.png')

        img = generate_sprite(species_id, color, size, shape)
        img.save(path)
        generated += 1
        print(f'  Generated: {species_id}.png ({shape}, size={size})')

    print(f'\nDone: {generated} sprites generated, {skipped} skipped')


if __name__ == '__main__':
    main()
