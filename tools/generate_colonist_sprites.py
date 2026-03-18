#!/usr/bin/env python3
"""Generate consistent 32x32 pixel art colonist sprites for all states.

Each sprite uses the same base body proportions (~20x26 content area centered
in 32x32 canvas) with pose/prop variations per state. Nearest-neighbor friendly.
"""

from PIL import Image, ImageDraw
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', 'colonists')
SIZE = 32

# --- Palette ---
TRANSPARENT = (0, 0, 0, 0)
SKIN        = (210, 180, 140, 255)
SKIN_DARK   = (180, 150, 110, 255)
HAIR        = (80, 55, 35, 255)
SHIRT       = (60, 100, 140, 255)    # colony blue
SHIRT_LIGHT = (80, 120, 160, 255)
PANTS       = (70, 70, 85, 255)
PANTS_LIGHT = (90, 90, 105, 255)
BOOTS       = (50, 40, 35, 255)
BLACK       = (20, 20, 20, 255)
WHITE       = (240, 240, 240, 255)
OUTLINE     = (30, 30, 40, 255)
EYE         = (40, 40, 50, 255)

# Tool/prop colors
WOOD        = (140, 100, 50, 255)
METAL       = (160, 170, 180, 255)
METAL_DARK  = (120, 130, 140, 255)
RED         = (200, 50, 40, 255)
RED_DARK    = (160, 35, 30, 255)
GREEN       = (50, 160, 60, 255)
BLUE_ICE    = (140, 180, 220, 255)
BLUE_FROST  = (100, 150, 200, 255)
ORANGE      = (220, 140, 40, 255)
YELLOW      = (220, 200, 60, 255)
FOOD_COLOR  = (180, 120, 60, 255)
CRATE       = (160, 120, 70, 255)
CRATE_DARK  = (120, 85, 45, 255)
BOOK        = (180, 160, 120, 255)
BANDAGE     = (230, 230, 220, 255)
ARMOR_PLT   = (130, 140, 150, 255)
ARMOR_DARK  = (100, 110, 120, 255)


def new_img():
    return Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)


def px(img, x, y, color):
    """Set a pixel, bounds-checked."""
    if 0 <= x < SIZE and 0 <= y < SIZE:
        img.putpixel((x, y), color)


def rect(img, x, y, w, h, color):
    """Fill a rectangle."""
    for dy in range(h):
        for dx in range(w):
            px(img, x + dx, y + dy, color)


def line_v(img, x, y, length, color):
    for i in range(length):
        px(img, x, y + i, color)


def line_h(img, x, y, length, color):
    for i in range(length):
        px(img, x + i, y, color)


# -----------------------------------------------------------------------
# Base body drawing helpers
# -----------------------------------------------------------------------

def draw_head(img, hx, hy, facing='front'):
    """Draw a 6x7 head at (hx, hy) top-left."""
    # Hair top
    rect(img, hx + 1, hy, 4, 1, HAIR)
    rect(img, hx, hy + 1, 6, 2, HAIR)
    # Face
    rect(img, hx, hy + 3, 6, 3, SKIN)
    rect(img, hx + 1, hy + 6, 4, 1, SKIN)
    # Eyes
    if facing == 'front':
        px(img, hx + 1, hy + 4, EYE)
        px(img, hx + 4, hy + 4, EYE)
    elif facing == 'right':
        px(img, hx + 3, hy + 4, EYE)
        px(img, hx + 5, hy + 4, EYE)
    elif facing == 'left':
        px(img, hx + 0, hy + 4, EYE)
        px(img, hx + 2, hy + 4, EYE)
    elif facing == 'dead':
        # X eyes
        px(img, hx + 1, hy + 3, RED)
        px(img, hx + 1, hy + 5, RED)
        px(img, hx + 4, hy + 3, RED)
        px(img, hx + 4, hy + 5, RED)
        px(img, hx + 2, hy + 4, RED)
        px(img, hx + 3, hy + 4, RED)


def draw_torso(img, tx, ty, color=SHIRT, highlight=SHIRT_LIGHT):
    """Draw 8x7 torso at (tx, ty)."""
    rect(img, tx + 1, ty, 6, 1, color)
    rect(img, tx, ty + 1, 8, 6, color)
    # Slight highlight on left side
    line_v(img, tx + 1, ty + 1, 5, highlight)


def draw_legs_standing(img, lx, ly):
    """Standing legs, 2px apart."""
    # Left leg
    rect(img, lx + 1, ly, 3, 5, PANTS)
    rect(img, lx + 1, ly + 5, 3, 2, BOOTS)
    # Right leg
    rect(img, lx + 4, ly, 3, 5, PANTS)
    rect(img, lx + 4, ly + 5, 3, 2, BOOTS)


def draw_legs_walking(img, lx, ly):
    """Walking legs, one forward one back."""
    # Left leg (forward)
    rect(img, lx, ly, 3, 5, PANTS)
    rect(img, lx, ly + 5, 3, 2, BOOTS)
    # Right leg (back)
    rect(img, lx + 5, ly + 1, 3, 4, PANTS)
    rect(img, lx + 5, ly + 5, 3, 2, BOOTS)


def draw_arm_down(img, ax, ay, side='left'):
    """Arm hanging at side."""
    rect(img, ax, ay, 2, 5, SHIRT)
    rect(img, ax, ay + 5, 2, 2, SKIN)


def draw_arm_raised(img, ax, ay, side='right'):
    """Arm raised up (for tools)."""
    rect(img, ax, ay - 3, 2, 3, SHIRT)
    rect(img, ax, ay - 4, 2, 1, SKIN)


def draw_arm_forward(img, ax, ay):
    """Arm reaching forward."""
    rect(img, ax, ay, 2, 3, SHIRT)
    rect(img, ax + 2, ay, 2, 2, SKIN)


# -----------------------------------------------------------------------
# Full colonist poses
# -----------------------------------------------------------------------

# Base position: head at (13,2), torso at (12,9), legs at (12,16)
# This centers a ~20px wide figure in 32px canvas

def sprite_idle():
    img = new_img()
    draw_head(img, 13, 2)
    draw_torso(img, 12, 9)
    draw_legs_standing(img, 12, 16)
    # Arms at sides
    draw_arm_down(img, 10, 10)
    draw_arm_down(img, 20, 10)
    return img


def sprite_walking():
    img = new_img()
    draw_head(img, 13, 2, 'right')
    draw_torso(img, 12, 9)
    draw_legs_walking(img, 12, 16)
    # Arms swinging
    draw_arm_down(img, 10, 9)
    rect(img, 20, 11, 2, 4, SHIRT)
    rect(img, 20, 15, 2, 1, SKIN)
    return img


def sprite_working():
    img = new_img()
    draw_head(img, 13, 3, 'right')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    # Left arm down
    draw_arm_down(img, 10, 11)
    # Right arm forward
    draw_arm_forward(img, 20, 11)
    # Generic tool
    rect(img, 23, 10, 2, 5, METAL)
    return img


def sprite_mining():
    img = new_img()
    draw_head(img, 13, 3, 'right')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    draw_arm_down(img, 10, 11)
    # Right arm raised with pickaxe
    draw_arm_raised(img, 20, 10)
    # Pickaxe head
    rect(img, 19, 4, 5, 2, METAL)
    line_v(img, 20, 3, 7, WOOD)  # handle
    px(img, 19, 4, METAL_DARK)
    px(img, 23, 4, METAL_DARK)
    return img


def sprite_building():
    img = new_img()
    draw_head(img, 13, 3, 'right')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    draw_arm_down(img, 10, 11)
    # Right arm raised with hammer
    draw_arm_raised(img, 20, 10)
    # Hammer
    line_v(img, 21, 3, 6, WOOD)
    rect(img, 19, 2, 5, 2, METAL)
    return img


def sprite_cooking():
    img = new_img()
    draw_head(img, 13, 3, 'front')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    # Both arms forward (stirring)
    rect(img, 10, 12, 2, 3, SHIRT)
    rect(img, 10, 15, 2, 1, SKIN)
    rect(img, 20, 12, 2, 3, SHIRT)
    rect(img, 20, 15, 2, 1, SKIN)
    # Pot/pan
    rect(img, 10, 16, 12, 2, METAL_DARK)
    rect(img, 11, 18, 10, 3, METAL)
    # Steam wisps
    px(img, 14, 15, (200, 200, 210, 150))
    px(img, 17, 14, (200, 200, 210, 120))
    return img


def sprite_researching():
    img = new_img()
    draw_head(img, 13, 3, 'front')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    # Left arm holding book
    rect(img, 10, 11, 2, 4, SHIRT)
    rect(img, 7, 12, 4, 5, BOOK)
    rect(img, 7, 12, 4, 1, HAIR)  # book spine
    # Right arm touching book
    rect(img, 20, 11, 2, 3, SHIRT)
    rect(img, 20, 14, 2, 1, SKIN)
    return img


def sprite_medical():
    img = new_img()
    draw_head(img, 13, 3, 'right')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    # Arms forward (treating patient)
    rect(img, 10, 12, 2, 3, SHIRT)
    rect(img, 10, 15, 2, 1, SKIN)
    draw_arm_forward(img, 20, 12)
    # Bandage roll
    rect(img, 23, 11, 3, 3, BANDAGE)
    # Red cross on torso
    px(img, 15, 12, RED)
    px(img, 16, 11, RED)
    px(img, 16, 12, RED)
    px(img, 16, 13, RED)
    px(img, 17, 12, RED)
    return img


def sprite_carrying():
    img = new_img()
    draw_head(img, 13, 2, 'front')
    draw_torso(img, 12, 9)
    draw_legs_standing(img, 12, 16)
    # Both arms forward holding crate
    rect(img, 10, 10, 2, 4, SHIRT)
    rect(img, 20, 10, 2, 4, SHIRT)
    # Crate
    rect(img, 11, 10, 10, 6, CRATE)
    rect(img, 11, 10, 10, 1, CRATE_DARK)
    rect(img, 11, 10, 1, 6, CRATE_DARK)
    # Slat lines
    line_h(img, 12, 13, 8, CRATE_DARK)
    return img


def sprite_armed_melee():
    img = new_img()
    draw_head(img, 13, 3, 'right')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    draw_arm_down(img, 10, 11)
    # Right arm out with sword
    rect(img, 20, 11, 2, 4, SHIRT)
    rect(img, 20, 15, 2, 1, SKIN)
    # Sword blade
    line_v(img, 22, 8, 8, METAL)
    line_v(img, 23, 9, 6, (190, 200, 210, 255))
    # Hilt
    line_h(img, 21, 16, 4, WOOD)
    return img


def sprite_armed_ranged():
    img = new_img()
    draw_head(img, 13, 3, 'right')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    # Left arm supporting
    rect(img, 10, 12, 2, 3, SHIRT)
    # Right arm aiming
    rect(img, 20, 11, 2, 3, SHIRT)
    rect(img, 22, 11, 2, 2, SKIN)
    # Rifle/bow
    rect(img, 23, 8, 2, 10, WOOD)
    rect(img, 24, 10, 3, 2, METAL)  # barrel
    px(img, 25, 9, METAL_DARK)
    return img


def sprite_eating():
    img = new_img()
    draw_head(img, 13, 3, 'front')
    draw_torso(img, 12, 10)
    draw_legs_standing(img, 12, 17)
    # Left arm on table/holding plate
    rect(img, 10, 11, 2, 4, SHIRT)
    rect(img, 10, 15, 2, 1, SKIN)
    # Right arm to mouth
    rect(img, 20, 10, 2, 3, SHIRT)
    rect(img, 19, 8, 2, 2, SKIN)
    # Food/plate below
    rect(img, 10, 22, 8, 2, (180, 180, 180, 255))  # plate
    rect(img, 12, 21, 4, 2, FOOD_COLOR)  # food on plate
    return img


def sprite_sleeping():
    """Lying down horizontally."""
    img = new_img()
    # Rotated: head on right, feet on left
    # Pillow
    rect(img, 22, 10, 6, 5, (180, 180, 200, 255))
    # Head (sideways)
    rect(img, 20, 11, 4, 4, SKIN)
    rect(img, 21, 10, 3, 2, HAIR)
    # Closed eyes
    line_h(img, 21, 13, 2, EYE)
    # Body under blanket
    rect(img, 5, 11, 16, 6, (80, 110, 150, 255))  # blanket
    rect(img, 5, 11, 16, 1, (70, 100, 140, 255))  # blanket top edge
    # Feet poking out
    rect(img, 3, 13, 3, 3, BOOTS)
    # Zzz
    px(img, 25, 7, WHITE)
    px(img, 26, 6, WHITE)
    px(img, 27, 5, WHITE)
    return img


def sprite_dead():
    """Lying down, X-eyes, muted colors."""
    img = new_img()
    # Head (sideways, on ground)
    rect(img, 20, 14, 5, 5, (180, 160, 130, 255))  # paler skin
    rect(img, 21, 13, 3, 2, HAIR)
    # X eyes
    px(img, 21, 16, RED)
    px(img, 23, 16, RED)
    px(img, 22, 15, RED)
    px(img, 22, 17, RED)
    # Body lying flat
    rect(img, 6, 14, 15, 5, (50, 80, 110, 255))  # desaturated shirt
    rect(img, 6, 19, 15, 3, (55, 55, 65, 255))  # desaturated pants
    # Arms splayed
    rect(img, 4, 15, 3, 2, (50, 80, 110, 255))
    rect(img, 3, 15, 2, 2, (180, 160, 130, 255))  # hand
    # Boots
    rect(img, 4, 20, 3, 3, BOOTS)
    return img


def sprite_mental_break():
    img = new_img()
    draw_head(img, 13, 3, 'front')
    # Red-tinted torso
    rect(img, 13, 9, 6, 1, RED_DARK)
    rect(img, 12, 10, 8, 6, RED_DARK)
    line_v(img, 13, 10, 5, RED)
    draw_legs_standing(img, 12, 17)
    # Arms flailing
    rect(img, 8, 8, 2, 2, RED_DARK)
    rect(img, 7, 7, 2, 2, SKIN)
    rect(img, 22, 8, 2, 2, RED_DARK)
    rect(img, 23, 7, 2, 2, SKIN)
    # Anger symbol above head
    px(img, 15, 0, RED)
    px(img, 17, 0, RED)
    px(img, 16, 1, RED)
    px(img, 14, 1, RED)
    px(img, 18, 1, RED)
    return img


def sprite_freezing():
    img = new_img()
    # Hunched pose, hugging self
    draw_head(img, 13, 4, 'front')
    # Blue-tinted torso (cold)
    rect(img, 13, 11, 6, 1, (50, 80, 130, 255))
    rect(img, 12, 12, 8, 5, (50, 80, 130, 255))
    line_v(img, 13, 12, 4, (60, 90, 140, 255))
    # Arms crossed over chest
    rect(img, 10, 12, 3, 4, (50, 80, 130, 255))
    rect(img, 19, 12, 3, 4, (50, 80, 130, 255))
    rect(img, 12, 13, 2, 2, SKIN)
    rect(img, 18, 13, 2, 2, SKIN)
    # Legs close together (hunched)
    rect(img, 13, 17, 3, 5, PANTS)
    rect(img, 13, 22, 3, 2, BOOTS)
    rect(img, 16, 17, 3, 5, PANTS)
    rect(img, 16, 22, 3, 2, BOOTS)
    # Frost particles
    px(img, 9, 6, BLUE_ICE)
    px(img, 23, 8, BLUE_ICE)
    px(img, 8, 14, BLUE_FROST)
    px(img, 24, 12, BLUE_FROST)
    # Shiver lines
    px(img, 11, 8, (150, 180, 220, 180))
    px(img, 21, 9, (150, 180, 220, 180))
    return img


def sprite_armored():
    img = new_img()
    draw_head(img, 13, 2, 'front')
    # Armored torso (metallic)
    rect(img, 13, 9, 6, 1, ARMOR_DARK)
    rect(img, 12, 10, 8, 6, ARMOR_PLT)
    rect(img, 13, 10, 6, 1, ARMOR_DARK)  # collar
    line_v(img, 16, 10, 5, ARMOR_DARK)  # center seam
    # Shoulder pads
    rect(img, 9, 9, 3, 3, ARMOR_PLT)
    rect(img, 20, 9, 3, 3, ARMOR_PLT)
    px(img, 10, 10, ARMOR_DARK)
    px(img, 21, 10, ARMOR_DARK)
    # Arms
    draw_arm_down(img, 10, 12)
    draw_arm_down(img, 20, 12)
    # Legs with greaves
    rect(img, 12, 16, 3, 5, PANTS)
    rect(img, 12, 16, 3, 2, ARMOR_DARK)
    rect(img, 12, 21, 3, 2, BOOTS)
    rect(img, 17, 16, 3, 5, PANTS)
    rect(img, 17, 16, 3, 2, ARMOR_DARK)
    rect(img, 17, 21, 3, 2, BOOTS)
    return img


# -----------------------------------------------------------------------
# Generate all sprites
# -----------------------------------------------------------------------

SPRITES = {
    'idle':          sprite_idle,
    'walking':       sprite_walking,
    'working':       sprite_working,
    'mining':        sprite_mining,
    'building_col':  sprite_building,
    'cooking':       sprite_cooking,
    'researching':   sprite_researching,
    'medical':       sprite_medical,
    'carrying':      sprite_carrying,
    'armed_melee':   sprite_armed_melee,
    'armed_ranged':  sprite_armed_ranged,
    'eating':        sprite_eating,
    'sleeping':      sprite_sleeping,
    'dead':          sprite_dead,
    'mental_break':  sprite_mental_break,
    'freezing':      sprite_freezing,
    'armored':       sprite_armored,
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # Back up existing sprites
    backup_dir = os.path.join(OUT_DIR, '_backup')
    os.makedirs(backup_dir, exist_ok=True)
    for fname in os.listdir(OUT_DIR):
        if fname.endswith('.png'):
            src = os.path.join(OUT_DIR, fname)
            dst = os.path.join(backup_dir, fname)
            if not os.path.exists(dst):
                import shutil
                shutil.copy2(src, dst)
                print(f'  backed up {fname}')

    for name, gen_fn in sorted(SPRITES.items()):
        img = gen_fn()
        path = os.path.join(OUT_DIR, f'{name}.png')
        img.save(path)
        print(f'  wrote {name}.png (32x32)')

    print(f'\nGenerated {len(SPRITES)} colonist sprites in {OUT_DIR}')


if __name__ == '__main__':
    main()
