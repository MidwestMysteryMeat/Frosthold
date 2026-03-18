# FROSTHOLD MVP Sprite Prompt

Copy-paste this directly into Gemini. One prompt per section.

---

## PROMPT 1: TILES (11 sprites, 32x32 px)

> Generate a pixel art sprite sheet for a top-down frozen colony survival game. Overhead perspective. Crisp pixel art, NO anti-aliasing, 1-2px dark outlines, transparent PNG background. Each tile is 32x32 pixels. Tiles must be seamlessly tileable.
>
> Generate these 11 tiles in a single horizontal strip (352x32 px):
>
> 1. **snow** - flat snow ground, subtle white/light-blue texture
> 2. **ice** - glossy ice surface, cyan with white reflection highlights
> 3. **rock** - rough dark gray stone, visible cracks
> 4. **tree** - evergreen treetop from above, dark green with white snow cap
> 5. **ore_vein** - gray rock with copper/gold metallic streaks
> 6. **wall_wood** - log wall cross-section, dark brown with wood grain rings
> 7. **wall_stone** - cut stone blocks, gray with light mortar lines
> 8. **floor_wood** - plank flooring, warm brown with tan grain lines
> 9. **floor_stone** - cut stone tile grid, medium gray
> 10. **door** - wooden door seen from above, brown with dark hinge marks
> 11. **debris** - broken rubble chunks, mixed gray
>
> Style: RimWorld/Dwarf-Fortress tileset aesthetic. Cold frozen world. Limited palette (4-6 colors per tile).

---

## PROMPT 2: COLONIST (1 base + 4 overlays, 32x32 px)

> Generate pixel art character sprites for a top-down colony survival game. Each sprite is 32x32 px, transparent background, crisp pixel art, 1-2px dark outline. Character body should be roughly 24x24 centered in the tile. Overhead/slight 3/4 perspective.
>
> **Base colonist** (facing south/down):
> - Wearing a thick parka with hood up
> - Muted brown/gray earth tones
> - Small ~12px circle head, rectangular ~16x20 body
>
> Generate 5 versions on a 160x32 strip:
> 1. **idle** - standing, arms at sides
> 2. **walking** - slight leg offset implying motion
> 3. **working** - arms forward, holding invisible tool
> 4. **sleeping** - lying flat, blanket over body
> 5. **dead** - collapsed flat, gray tint

---

## PROMPT 3: CREATURES (8 sprites, various sizes)

> Generate pixel art creature sprites for a top-down frozen alien world game. Transparent background, crisp pixel art, 1-2px dark outlines. Overhead perspective.
>
> All on separate transparent canvases:
>
> **32x32 px (small):**
> 1. **frost_hare** - small white arctic rabbit, round body, long ears (~13px actual)
> 2. **ice_fox** - sleek white/silver arctic fox, bushy tail (~16px actual)
>
> **48x48 px (medium):**
> 3. **tundra_wolf** - lean gray wolf, alert ears, visible fangs (~22px actual body)
> 4. **glacier_bear** - bulky white polar bear, massive paws (~29px actual)
> 5. **stalker** - tall gaunt pale humanoid beast, long arms, hollow dark eyes (~35px actual)
> 6. **mammoth** - woolly mammoth from above, brown-gray fur, ivory tusks (~51px actual)
>
> **96x96 px (boss):**
> 7. **frost_titan** - giant humanoid ice elemental, crystalline blue body, glowing eyes
> 8. **the_pale_thing** - enormous pale horror, formless white-gray mass with dark voids and tentacle edges
>
> Style: Natural tundra colors for fauna (white, gray, brown). Bosses should feel massive and threatening.

---

## PROMPT 4: CORE BUILDINGS (12 sprites, 32x32 px)

> Generate pixel art building sprites for a top-down colony survival game. Each is 32x32 px, transparent background, crisp pixel art, 1-2px outlines. Overhead perspective. Think Frostpunk industrial aesthetic.
>
> Generate these 12 buildings on a 384x32 strip:
>
> 1. **campfire** - stone ring with orange fire glow in center
> 2. **bed** - top-down bed: brown frame, white pillow at top, colored blanket
> 3. **workbench** - wooden crafting table, scattered small tool shapes
> 4. **kitchen** - wood counter with gray pot, small steam wisps
> 5. **smelter** - dark metal furnace box, orange glow window, small chimney
> 6. **sawmill** - brown wood frame with silver circular saw blade
> 7. **research_bench** - wood desk with blue/white lab equipment and books
> 8. **turret_gun** - gray metal platform base with single dark gun barrel on top
> 9. **farm_plot** - dark brown tilled soil rows with tiny green sprouts
> 10. **torch** - brown post with warm orange glow ring radiating outward
> 11. **steam_hub** - metal dome with white steam puffs, pipe stubs in 4 directions
> 12. **solar_panel** - flat dark blue panel with lighter blue grid cell pattern
>
> Style: Industrial, functional, slightly gritty. Warm browns for wood, dark grays for metal, orange for heat/fire.

---

## PROMPT 5: ITEM ICONS (20 sprites, 16x16 px)

> Generate pixel art item icons for a colony survival game inventory system. Each icon is 16x16 px, transparent background, crisp pixel art, 1px dark outline. Must be recognizable at small size.
>
> Generate on a 320x16 strip (20 icons):
>
> 1. **wood** - brown log cross-section
> 2. **stone** - gray rock chunk
> 3. **metal** - silver-blue ingot bar
> 4. **food** - simple bread/apple shape, golden-brown
> 5. **water** - blue water droplet
> 6. **fuel** - orange-brown barrel or flame
> 7. **thermal_core** - glowing orange-red crystal
> 8. **components** - small gray gear shapes
> 9. **steel** - polished blue-silver bar
> 10. **medicine** - white bottle with green label
> 11. **bandage** - white roll with red cross
> 12. **leather** - tan-brown folded piece
> 13. **raw_meat** - red meat slab
> 14. **coal** - black shiny chunk
> 15. **circuit** - green board with gold traces
> 16. **spike** (drug) - jagged ice-blue crystal shard
> 17. **ammo_bullet** - brass cartridge with gray tip
> 18. **eldritch_ichor** - dark purple glowing vial
> 19. **cloth** - white folded fabric
> 20. **herbal_medicine** - green herb sprig
>
> Style: Clean, high-contrast, instantly readable at 16px. Limited palette per icon (3-5 colors).

---

## PROMPT 6: UI ICONS (10 sprites, 24x24 px)

> Generate pixel art UI icons for a colony survival game HUD. Each is 24x24 px, transparent background, crisp pixel art, 1px outline. Must read clearly on dark semi-transparent UI panels.
>
> Generate on a 240x24 strip:
>
> 1. **pickaxe** (mine job) - gray metal head, brown handle
> 2. **hammer** (build job) - metal hammer head, wood handle
> 3. **box_arrow** (haul job) - brown box with upward arrow
> 4. **pot** (cook job) - gray cooking pot with steam
> 5. **crosshair** (hunt job) - red/orange target crosshair
> 6. **flask** (research job) - blue science flask
> 7. **red_cross** (medical job) - white square, red cross
> 8. **sword** (draft/combat) - steel sword silhouette
> 9. **thermometer** (warmth need) - red thermometer
> 10. **moon** (rest need) - white crescent moon
>
> Style: Simple, bold silhouettes. High contrast against dark backgrounds.

---

## TOTAL MVP COUNT

| Category | Sprites | Size |
|----------|---------|------|
| Tiles | 11 | 32x32 |
| Colonist | 5 states | 32x32 |
| Creatures | 8 | 32-96px |
| Buildings | 12 | 32x32 |
| Items | 20 | 16x16 |
| UI Icons | 10 | 24x24 |
| **TOTAL** | **66 sprites** | |

This covers the minimum needed to replace all placeholder rectangles/circles with real art and have a visually playable game.
