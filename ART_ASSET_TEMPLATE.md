# FROSTHOLD - Art Asset Generation Template

Use this document as a prompt/reference for AI image generation (Gemini, etc.) to create placeholder sprite assets for a top-down colony survival game (Frostpunk x RimWorld).

---

## GLOBAL STYLE GUIDE

**Art Style:** Top-down pixel art, 2-3 pixel outlines, limited palette per sprite (4-8 colors + shading). Think RimWorld/Dwarf Fortress tileset meets Frostpunk industrial aesthetic.

**Perspective:** Directly overhead (bird's eye), slight 3/4 angle acceptable for readability on buildings/characters.

**Color Palette:**
- Environment: Cool blues, grays, whites (frozen tundra)
- Buildings: Warm browns (wood), grays (stone), blue-gray (metal), amber glow (heated)
- Colonists: Muted earth tones, parkas, hoods
- Creatures: Natural tundra colors (white, gray, brown) for fauna; sickly greens/purples for eldritch
- UI/Icons: High contrast, readable at small sizes
- Fire/Heat: Orange, amber, yellow
- Ice/Cold: Cyan, light blue, white
- Eldritch/Void: Deep purple, sickly green, dark red

**Transparency:** All sprites on transparent background (PNG with alpha).

**Naming Convention:** `category_name.png` (e.g., `tile_snow.png`, `creature_tundra_wolf.png`, `building_sawmill.png`)

---

## SPRITE SHEETS vs INDIVIDUAL FILES

Prefer **sprite sheets** where noted. Individual PNGs otherwise.

---

## 1. TILES (32x32 px each)

Deliver as a single sprite sheet: 21 tiles in a row = **672x32 px sheet**, OR individual 32x32 PNGs.

Each tile should be seamlessly tileable (edges match when repeated).

| # | ID | Description | Key Colors |
|---|-----|-------------|------------|
| 1 | void | Black empty space | Pure black |
| 2 | snow | Flat snow ground, subtle texture | White, light blue-gray |
| 3 | ice | Glossy ice surface, slight reflection | Cyan, light blue, white highlights |
| 4 | rock | Rough stone, cracks visible | Dark gray, medium gray |
| 5 | permafrost | Frozen earth, blue tint | Blue-gray, dark brown hints |
| 6 | dirt | Exposed earth, rare on this planet | Brown, dark tan |
| 7 | floor_wood | Plank flooring, visible grain | Warm brown, tan lines |
| 8 | floor_stone | Cut stone tiles, grid pattern | Medium gray, light mortar lines |
| 9 | floor_metal | Industrial metal grating | Blue-gray, dark rivets |
| 10 | floor_insulated | Padded thermal floor, warm tint | Tan-orange, quilted pattern |
| 11 | wall_wood | Log wall cross-section (top-down) | Dark brown, wood grain circles |
| 12 | wall_stone | Stone block wall, thick | Gray, mortar grid visible |
| 13 | wall_metal | Steel plated wall | Blue-gray, rivet dots |
| 14 | wall_insulated | Thick insulated wall, foam visible | Tan with orange core strip |
| 15 | door | Wooden door (hinge visible from top) | Brown, dark hinge marks |
| 16 | door_sealed | Reinforced sealed door | Metal gray, rubber gasket (orange edge) |
| 17 | water | Liquid water surface | Deep blue, subtle ripple |
| 18 | lava_vent | Glowing volcanic vent | Dark rock, orange/red glow center |
| 19 | debris | Rubble/broken rock | Mixed gray chunks, dust |
| 20 | tree | Evergreen tree top-down (snow-covered) | Dark green core, white snow cap |
| 21 | ore_vein | Rock with metallic ore streaks | Gray rock, copper/gold veins |

---

## 2. COLONISTS (32x32 px base)

Colonists are drawn as humanoid figures seen from above. Body is ~24x24 px centered in the 32x32 tile. Head is a ~12px diameter circle at top of body.

### Base Colonist Sprite (1 per direction: N/S/E/W, or just 1 static)
- **idle**: Standing, arms at sides. Parka, hood up. Muted earth tones.
- **walking**: Slight leg offset to imply motion (2-frame minimum).
- **working**: Arms forward/down, tool in hand.
- **sleeping**: Lying flat, blanket visible.
- **eating**: Seated pose, item near face.
- **dead**: Collapsed flat, no animation.
- **mental_break**: Red-tinted, erratic pose, exclamation bubble.

### Colonist Equipment Overlays (drawn on top of base sprite)
These are overlay sprites (transparent except the equipment piece). Same 32x32 canvas.

**Weapons (held in hand area):**

| Weapon | Description | Size on sprite |
|--------|-------------|----------------|
| club | Crude wooden club | ~8x4 px, brown |
| shiv | Small makeshift knife | ~6x2 px, gray glint |
| pipe_wrench | Heavy wrench | ~8x4 px, dark metal |
| knife | Hunting knife | ~7x2 px, bright edge |
| hatchet | Small axe | ~8x6 px, wood handle + metal head |
| machete | Long blade | ~10x2 px, steel |
| spear | Long pole + point | ~14x2 px, extends past body |
| sword | Standard blade | ~10x3 px, glint highlight |
| shortbow | Small bow, string visible | ~8x10 px, curved |
| bow | Full hunting bow | ~10x12 px, larger curve |
| crossbow | Mechanical crossbow | ~10x8 px, boxy mechanism |
| revolver | Small handgun | ~6x4 px, dark |
| pistol | Semi-auto pistol | ~7x4 px, dark |
| sawed_off | Short shotgun | ~8x4 px |
| pump_shotgun | Long shotgun | ~12x3 px |
| bolt_action | Rifle | ~14x3 px, extends past body |
| assault_rifle | Modern rifle | ~14x4 px, bulkier |
| battle_rifle | Heavy rifle | ~16x4 px, largest |

**Armor (body overlay):**

| Armor | Description |
|-------|-------------|
| hide_coat | Rough fur coat, brown/gray patches |
| leather_armor | Tanned leather vest, stitching visible |
| metal_plate | Steel chest plate, rivets, blue-gray |
| thermal_suit | Full body orange/tan insulated suit, visor |

### Hypothermia Stage Tints (apply as color overlay to base sprite)
- normal: No tint
- chilled: Slight blue edge glow
- cold: Blue-tinted skin
- hypothermic: Heavy blue, frost on edges
- severe: Near-white, ice crystals visible

---

## 3. CREATURES

All creature sprites fit within their tile footprint. Size multiplier determines visual scale relative to the 32px tile.

**Sprite size = 32 * size_multiplier** (but deliver all on a 32x32 canvas for small, 64x64 for medium/large, 96x96 for megafauna/bosses).

### Small Fauna (deliver at 32x32)

| Species | Size | Description | Colors |
|---------|------|-------------|--------|
| frost_hare | 0.4 (~13px) | Small arctic rabbit, round body, long ears | White, light gray |
| ice_fox | 0.5 (~16px) | Sleek arctic fox, bushy tail | White, silver-blue tips |
| snow_grouse | 0.3 (~10px) | Small plump bird | White, brown wing tips |

### Medium Fauna (deliver at 48x48)

| Species | Size | Description | Colors |
|---------|------|-------------|--------|
| tundra_wolf | 0.7 (~22px) | Lean wolf, visible fangs, alert ears | Gray, white belly |
| glacier_bear | 0.9 (~29px) | Bulky polar bear, massive paws | White, cream-yellow tint |
| ice_stalker | 0.8 (~26px) | Lean predator, low slung, glowing eyes | Dark blue-gray, cyan eyes |
| dire_wolf | 0.85 (~27px) | Larger wolf variant, scarred | Dark gray, red-brown scars |
| sabertooth | 0.9 (~29px) | Saber-toothed cat, prominent fangs | Tawny brown, white fangs |
| shade | 0.9 (~29px) | Ghostly translucent predator | Semi-transparent blue-white, glowing outline |
| stalker | 1.1 (~35px) | Tall gaunt humanoid beast, long arms | Pale flesh, dark hollow eyes |
| snow_ape | 1.3 (~42px) | Massive white gorilla, muscular | White, gray face/hands |
| ice_brute | 1.5 (~48px) | Towering ice giant, crude features | Ice blue, white frost |
| mammoth | 1.6 (~51px) | Woolly mammoth, tusks prominent | Brown-gray fur, ivory tusks |

### Swarm Creatures (deliver at 32x32, meant to appear in large numbers)

| Species | Size | Description | Colors |
|---------|------|-------------|--------|
| frost_beetle | 0.4 (~13px) | Small chitinous beetle, icy shell | Dark blue-black, ice-white shell |
| ice_locust | 0.5 (~16px) | Winged insect, fast-looking | Light blue, translucent wings |
| frost_wurm | 3.0 (~96px) | MASSIVE burrowing worm, segmented | Ice white, dark blue segments, glowing maw |
| spawnling | 0.3 (~10px) | Tiny writhing larval thing | Pink-gray, translucent |
| skitterer | 0.4 (~13px) | Fast multi-legged crawler | Dark gray, red eyes |
| giant_rat | 0.5 (~16px) | Large rat, matted fur | Brown-gray, pink tail |

### Megafauna Bosses (deliver at 96x96)

| Boss | Size | Description | Colors |
|------|------|-------------|--------|
| the_bull | 2.0+ | Massive ice brute king, crowned with ice spikes | Deep blue ice, white crown, glowing eyes |
| the_stalker | 1.6+ | Alpha stalker, elongated, multiple arms | Pale with dark veins, many limbs |
| the_pale_thing | 2.5+ | Enormous pale horror, formless mass | White-gray, dark voids, tentacle edges |
| that_which_sleeps | 3.0+ | Titanic sleeping god entity, mountain-sized | Dark earth, glowing purple fissures |
| frost_titan | 2.0 | Giant humanoid ice elemental | Pure ice blue, crystalline |
| thermal_wurm | 1.8 | Lava-veined burrowing wurm | Dark rock, orange-red veins |
| glacial_leviathan | 2.5 | Whale-sized ice creature | Blue-white, massive |
| mountain_titan | 3.0 | Mountain-shaped living stone | Gray rock, moss, glowing eyes |

### Eldritch Creatures (deliver at 48x48, unsettling designs)

| Species | Description | Colors |
|---------|-------------|--------|
| fleshwalker | Humanoid made of fused flesh, wrong proportions | Pink-red, dark stitching |
| gore_shoat | Pig-like thing, too many legs, exposed muscle | Red, dark pink, bone white |
| weeping_calf | Cow-like, eyeless, dripping dark fluid | Gray-brown, black drips |
| husk_pup | Dog-shaped husk, hollow inside | Tan-gray, dark hollow interior |
| void_minnow | Small fish-like floating entity | Dark purple, glowing spots |
| pit_wyrm | Small burrowing worm, acidic | Sickly green, yellow acid drip |
| bile_mold | Living fungal growth, pulsing | Green-yellow, brown spots |
| thorn_polyp | Coral-like growth with spines | Dark red, bone-white thorns |
| nerve_cluster | Exposed nerve bundle, twitching | Pink, white tendrils |
| rot_bloom | Flowering decay, spore cloud | Brown-green, yellow spore dots |

---

## 4. BUILDINGS (32x32 px each, all 1x1 tile)

Top-down view. Buildings should look distinct at 32x32 and also work zoomed to 128x128 (4x zoom). Thick outlines (2px) for readability.

### Walls & Floors
(Covered in Tiles section above)

### Power Generators (16 types)

| Building | Description | Key Visual |
|----------|-------------|------------|
| campfire_gen | Small fire ring, stones around flames | Orange glow center, gray stone ring |
| coal_burner | Industrial furnace box, chimney pipe | Dark metal box, orange window, smoke pipe |
| thermal_gen | Sleek reactor using thermal cores | Cyan glow, metal casing, core slot visible |
| fuel_cell_gen | Clean energy cell rack | White/green, small clean rectangles |
| lava_tap | Pipe tapping into ground, orange glow | Metal frame over orange vent |
| solar_panel | Flat blue-black panel, grid pattern | Dark blue, lighter blue grid cells |
| wind_turbine | Turbine top-down (3 blades from center) | White/gray blades, dark hub |
| geothermal | Wide pipe into earth, steam wisps | Metal pipe, white steam puffs |
| gas_burner | Boxy burner, exhaust vents | Metal, orange flame window, side vents |
| nuclear_reactor | Heavy shielded box, radiation symbol | Lead gray, yellow hazard stripe, green glow |
| fire_pit | Dug pit with burning wood | Dark earth ring, orange/red fire center |
| deep_fire_pit | Deeper contained pit, less smoke | Stone-lined pit, contained orange glow |
| bio_reactor | Organic tank, green liquid visible | Glass tank, green bubbling liquid |
| mini_reactor | Smaller nuclear device | Similar to nuclear but smaller, fewer hazard marks |
| steam_turbine | Spinning turbine housing | Metal casing, white steam pipes |
| hand_crank | Lever/crank mechanism | Wood frame, metal crank handle |
| treadmill | Walking belt mechanism | Wood/metal frame, belt surface |
| chain_gang_wheel | Large wheel with chains | Big wood wheel, dark chain links |
| waste_incinerator | Thick box, heavy smoke | Dark metal, thick chimney, orange slot |
| hydrogen_cell | Clean cell with water input | White/blue, water droplet icon, clean look |
| lightning_rod | Tall rod (seen from top = circle + cross) | Metal point, spark marks |
| thermopile | Flat thermal collector | Dark with red/blue halves (hot/cold side) |
| ichor_burner | Eldritch furnace, pulsing purple | Dark metal, purple glow, dripping |

### Defense - Turrets (17 types)

**REUSE NOTE:** Many turrets share a base platform sprite. Create 1 base (gray metal platform, 20x20px) and swap the weapon on top.

| Turret | Weapon on top | Colors |
|--------|---------------|--------|
| ballista | Large wooden crossbow mechanism | Brown wood, rope |
| crossbow | Small auto-crossbow | Brown/metal |
| gun | Single barrel | Dark metal, muzzle flash point |
| minigun | Multi-barrel rotating | Dark metal, 4 barrels visible |
| shotgun | Wide short barrel | Dark metal, wide bore |
| mortar | Angled tube (circle from top) | Green-gray, dark bore hole |
| rocket | Tube launcher | OD green, rocket tip visible |
| laser | Lens/crystal emitter | White/cyan, crystal point |
| tesla | Coil on top, sparks | Copper coil, blue spark arcs |
| flamethrower | Nozzle with flame tank | Dark + orange tank, nozzle |
| cryo | Frosted nozzle | Blue/white, frost buildup |
| railgun | Long thin barrel, capacitor bank | Silver, blue capacitor glow |
| emp | Dish emitter | Metal dish, purple pulse rings |
| sniper | Very long thin barrel | Dark, longest barrel |
| autocannon | Medium rotating barrel | Dark metal, ammo belt |
| grenade_launcher | Drum magazine launcher | OD green, round drum |
| heavy_mg | Heavy machine gun on tripod | Dark metal, belt-fed, chunky |

### Defense - Traps (18 types)

**REUSE NOTE:** Many traps share a ground plate sprite. Create 1 base plate (gray/brown, subtle), swap the mechanism.

| Trap | Description | Colors |
|------|-------------|--------|
| spike_trap | Spikes pointing up from plate | Gray metal spikes on brown plate |
| deadfall_trap | Heavy weight on trigger | Brown wood, stone weight |
| pit_trap | Dark hole in ground | Dark center, crumbled edge |
| snare_trap | Wire loop on ground | Thin gray wire loop |
| razor_wire | Coiled sharp wire | Silver wire, red rust/blood |
| bear_trap | Metal jaw trap | Dark metal jaws |
| spring_blade | Hidden blade mechanism | Metal plate, blade edge visible |
| incendiary_trap | Fire bomb mechanism | Orange canister, fuse wire |
| emp_mine | Electronic mine | Metal disc, blue light |
| acid_trap | Acid vial on trigger | Glass vial, green liquid |
| cryo_mine | Freezing mine | Metal disc, white frost |
| frag_mine | Shrapnel mine | Metal disc, red light |
| gas_trap | Gas canister trap | Yellow canister, skull mark |
| caltrops | Scattered sharp metal pieces | Silver scattered points |
| tripwire_alarm | Thin wire + bell | Wire line, small bell |
| punji_pit | Bamboo spike pit | Dark pit, wooden spikes |
| tripwire_ied | Wire + explosive | Wire + brown explosive pack |
| claymore | Directional mine | Green rectangle, "FRONT TOWARD ENEMY" |

### Production Buildings (13 types)

| Building | Description | Colors |
|----------|-------------|--------|
| sawmill | Circular saw blade visible, log feed | Brown wood frame, silver blade |
| smelter | Hot furnace, ore input | Dark metal, orange glow, chimney |
| forge | Anvil + hammer area | Dark metal, anvil shape, orange ember |
| kitchen | Cooking surface, pot/pan | Wood counter, gray pot, steam |
| workbench | Crafting table, tools scattered | Wood surface, small tool shapes |
| loom | Weaving frame, thread visible | Wood frame, colored thread lines |
| tannery | Leather stretching rack | Brown wood, tan hide stretched |
| smokehouse | Enclosed smoker, vent | Wood box, smoke wisps from top |
| drug_lab | Chemistry setup, vials | Metal table, colored vial shapes |
| butcher_table | Bloody cutting surface | Wood + red stains, cleaver |
| surgery_table | Clean medical table | White/steel, green cross icon |
| refinery | Chemical processing tower | Metal tanks, pipes, steam |
| stone_cutter | Chisel + stone block workspace | Gray stone, metal chisel |

### Utility Buildings

| Building | Description | Colors |
|----------|-------------|--------|
| bed | Top-down bed, pillow + blanket | Brown frame, white pillow, colored blanket |
| memorial | Small stone marker/tombstone | Gray stone, cross/symbol |
| torch | Standing torch (circle of light from top) | Brown post, orange glow ring |
| standing_lamp | Electric lamp (brighter circle) | Metal post, white/yellow glow ring |
| heater | Radiator unit | Metal gray, orange heat fins |
| greenhouse | Glass-topped growing area | Green inside, glass frame (blue-white edges) |
| farm_plot | Tilled soil plot | Dark brown rows, small green sprouts |
| cloning_vat | Green liquid tank, figure inside | Glass tube, green glow, humanoid shadow |
| radio_beacon | Antenna tower (from top = radial lines) | Metal, blinking red light at center |
| steam_hub | Central steam distributor, pipes radiating | Metal dome, white steam, pipe stubs in 4 dirs |
| deep_drill | Drilling rig, rotating head | Metal frame, drill bit center |
| research_bench | Lab table with books/microscope | Wood desk, blue/white equipment |
| expedition_table | Map table with pins | Wood desk, paper map, colored pins |
| quest_board | Wooden notice board | Brown board, pinned papers |
| air_intake | Vent/grate pulling air in | Metal grate, arrow-in icon |
| air_exhaust | Vent pushing air out | Metal grate, arrow-out icon |
| air_purifier | Filter unit, clean air | White unit, green "clean" indicator |
| shield_generator | Dome projector | Metal base, blue dome outline |
| watchtower | Elevated platform (from top = square + figure) | Wood platform, railing |
| bunker | Reinforced box, slit windows | Concrete gray, dark slits |
| sandbag | Sandbag wall segment | Tan bags, stacked |
| barricade | Wooden spike barrier | Brown wood, pointed tips outward |
| steel_barrier | Metal wall segment | Steel gray, rivets |

### Pipe/Fluid Infrastructure

| Building | Description | Colors |
|----------|-------------|--------|
| small_pipe | Narrow pipe (top-down = line) | Gray, fluid color visible inside |
| large_pipe | Wide pipe | Larger gray, fluid color |
| insulated_pipe | Pipe with insulation wrap | Gray + orange wrap |
| small_duct | Narrow air duct | Light gray, vent slits |
| large_duct | Wide air duct | Light gray, larger slits |
| sealed_duct | Airtight duct | Gray + rubber seal edge |
| fluid_tank_small | Small liquid storage | Metal cylinder, fluid window |
| fluid_tank_large | Large liquid storage | Bigger metal cylinder |
| gas_canister | Gas storage cylinder | Metal, colored band for gas type |
| pressurized_tank | High-pressure tank | Thick metal, pressure gauge |
| water_pump | Pump mechanism | Metal, blue water marks |
| oil_refinery | Small refinery tower | Metal, dark oil stains |
| coolant_refiner | Coolant processing | Metal, cyan coolant marks |
| ichor_converter | Eldritch fluid processor | Dark metal, purple ichor stains |
| waste_processor | Waste treatment unit | Gray, brown waste marks |
| gas_separator | Gas splitting unit | Metal, multiple colored output pipes |
| steam_boiler | Water-to-steam converter | Metal, white steam output |

---

## 5. ITEMS / RESOURCES (16x16 px icons)

Small icons for inventory, stockpile display, crafting UI. Must be clear and recognizable at 16x16.

Deliver as a sprite sheet if possible: items in a grid.

### Raw Materials

| Item | Description | Colors |
|------|-------------|--------|
| raw_wood | Log cross-section or stick bundle | Brown, tan rings |
| raw_stone | Rough rock chunk | Gray, irregular shape |
| raw_ore | Rock with metal flecks | Gray + copper/gold specks |
| raw_ice | Ice crystal chunk | Cyan, white, transparent look |
| raw_meat | Red meat slab | Red, pink, fat marbling |
| raw_hide | Folded animal skin | Brown, furry texture edge |
| thermal_core | Glowing energy crystal | Orange-red glow, crystalline |
| plant_fiber | Bundle of fibers | Green, stringy |
| coal | Black chunk | Near-black, slight sheen |
| berries | Small berry cluster | Red/blue dots on green stem |
| mushrooms | Small mushroom cluster | Tan cap, white stem |
| medicinal_herb | Green herb sprig | Green leaves, small flower |
| raw_fat | White fat chunk | White-yellow, glossy |
| raw_fur | Piece of fur | Brown/white, fluffy texture |

### Processed Materials

| Item | Description | Colors |
|------|-------------|--------|
| lumber | Cut plank | Light brown, clean edges |
| cut_stone | Squared stone block | Gray, flat faces |
| metal_ingot | Metal bar | Silver-blue, shiny |
| leather | Tanned leather piece | Tan-brown, smooth |
| cloth | Folded fabric | White/colored, soft folds |
| water | Water droplet or flask | Blue, droplet shape |
| charcoal | Dark processed coal | Black, cleaner than raw coal |
| steel | Steel bar, polished | Blue-silver, very clean |
| components | Gears + small parts | Metal gray, gear shapes |
| circuit | Circuit board | Green board, gold traces |
| fuel_cell | Energy cell | Silver canister, green indicator |

### Food Items

| Item | Description | Colors |
|------|-------------|--------|
| cooked_meat | Browned meat | Brown, grill marks |
| stew | Bowl of stew | Brown bowl, orange-brown liquid |
| jerky | Dried meat strip | Dark brown, strip shape |
| bread | Loaf of bread | Golden brown, round |
| ration | Wrapped emergency ration | Gray wrap, red cross |
| feast | Elaborate meal platter | Multiple colored foods on plate |

### Medical

| Item | Description | Colors |
|------|-------------|--------|
| bandage | Rolled white bandage | White roll, red cross |
| medicine | Medicine bottle/syringe | White bottle, green label |

### Drugs (use similar vial/pill shapes, differentiated by color)

| Drug | Container | Accent Color |
|------|-----------|-------------|
| spike | Crystal shard | Ice blue, jagged |
| stardust | Fine powder pouch | White, sparkle dots |
| drift | Liquid vial | Amber-orange |
| smog | Smoke canister | Gray-green, wispy |
| rotgut | Bottle | Brown, crude label |
| shards | Broken crystal pieces | Pink-purple |
| glimpse | Eye-dropper vial | Yellow-gold |
| surge | Injector syringe | Electric blue |
| thaw | Warm liquid vial | Red-orange, steam |
| voidbloom | Dark flower | Deep purple, black center |

### Drug Crop Leaves

| Item | Description | Colors |
|------|-------------|--------|
| psychoid_leaf | Narrow pointed leaf | Dark green, purple vein |
| smokeleaf_leaf | Broad serrated leaf | Green, lighter edges |
| hops | Hop flower cone | Light green, layered petals |

### Organs (disturbing but clinical)

| Item | Description | Colors |
|------|-------------|--------|
| organ_heart | Anatomical heart | Dark red |
| organ_lung | Lung shape | Pink |
| organ_kidney | Kidney bean shape | Dark red-brown |
| organ_liver | Liver shape | Dark brown-red |
| organ_eye | Eyeball | White, colored iris |

### Prosthetics

| Item | Description | Colors |
|------|-------------|--------|
| peg_leg | Simple wooden peg | Brown wood |
| wooden_arm | Carved wooden arm | Brown wood, joint lines |
| prosthetic_leg | Metal leg | Silver, joint visible |
| prosthetic_arm | Metal arm | Silver, joint visible |
| bionic_leg | High-tech leg, glowing | Silver + cyan glow lines |
| bionic_arm | High-tech arm, glowing | Silver + cyan glow lines |
| bionic_eye | Cybernetic eye | Silver ring, red/cyan lens |

### Corpses

| Item | Description | Colors |
|------|-------------|--------|
| corpse_creature | Dead animal lump | Gray-brown, x-eyes |
| corpse_human | Wrapped body | Gray cloth wrap, dark stains |

### Dark Processing

| Item | Description | Colors |
|------|-------------|--------|
| human_meat | Like raw_meat but paler | Pale pink, unsettling |
| human_leather | Like leather but pale | Pale tan, disturbing |

### Weapons (16x16 icons for inventory/crafting)
Same weapons as colonist overlays but as standalone icons.

### Ammunition

| Item | Description | Colors |
|------|-------------|--------|
| ammo_arrow | Arrow with feather | Brown shaft, gray tip, white feather |
| ammo_fire_arrow | Arrow with flame tip | Brown shaft, orange flame tip |
| ammo_bolt | Crossbow bolt | Short dark shaft, metal tip |
| ammo_bullet | Bullet/cartridge | Brass casing, gray tip |
| ammo_shell | Shotgun shell | Red tube, brass base |
| ammo_rocket | Rocket projectile | OD green tube, red tip |
| ammo_mortar_shell | Mortar round | OD green, teardrop shape |

### Throwables

| Item | Description | Colors |
|------|-------------|--------|
| grenade | Frag grenade | OD green, ring pull |
| ied | Improvised explosive | Duct tape, wires, red light |
| molotov | Bottle with rag | Glass bottle, orange rag flame |
| pipe_bomb | Pipe with fuse | Metal pipe, fuse wire |

### Eldritch Resources

| Item | Description | Colors |
|------|-------------|--------|
| eldritch_ichor | Glowing dark liquid vial | Dark purple, inner glow |
| chitin_plate | Insectoid armor piece | Dark blue-black, ridged |
| void_crystal | Impossible geometry crystal | Deep purple, black core |
| caustic_liquid | Corrosive vial, bubbling | Yellow-green, bubble marks |
| serpent_venom | Fang-marked vial | Dark green, fang icon |
| fang | Large creature tooth | Bone white, sharp point |

---

## 6. CROPS (32x32 px, 4 growth stages each)

Each crop needs 4 sprites: seedling, growing, mature, wilted.

| Crop | Seedling | Growing | Mature | Wilted |
|------|----------|---------|--------|--------|
| frost_wheat | Small green sprout | Taller stalks, blue-green | Full golden wheat heads | Brown, drooping |
| thermal_berries | Tiny red dot sprout | Bush forming, green | Full berry bush, bright red berries | Gray-brown, dried |
| alien_fungus | Small gray dot | Mushroom caps forming | Large glowing mushroom cluster, bioluminescent | Dark, collapsed |
| medicinal_moss | Green fuzz patch | Spreading moss, thicker | Full bright green moss carpet | Brown, dried |
| fiber_vine | Thin green tendril | Climbing vine, leafy | Thick vine web, harvestable fibers | Brown, brittle |
| psychoid_plant | Small dark sprout | Dark green bush, buds | Full plant, purple-tinged leaves | Wilted, gray |
| smokeleaf_plant | Small leafy sprout | Bushy, serrated leaves | Full bushy plant, ready to harvest | Dried yellow-brown |
| hops_plant | Tiny vine start | Climbing vine with buds | Full hop cones hanging | Dried, brown cones |

---

## 7. WEATHER / EFFECTS (various sizes)

### Particle Effects (8x8 px each, for particle systems)
- **snowflake**: White, 6-pointed, various rotation
- **rain_drop**: Blue streak, vertical
- **ice_shard**: Cyan angular piece (for blizzard)
- **ember**: Orange-red dot (for fire)
- **smoke**: Gray circle, feathered edge
- **blood_splat**: Red drops
- **spore**: Yellow-green dot (for disease)
- **spark**: White/yellow flash (for electrical)

### Screen Overlays (full-screen tint, not sprites)
- clear: No overlay
- light_snow: White dots, sparse
- heavy_snow: White dots, dense
- blizzard: White streaks, heavy
- whiteout: Near-white overlay, minimal visibility
- rain: Blue streaks
- aurora: Green/purple shimmering bands at top

---

## 8. UI ICONS (24x24 px)

### Resource Icons (for top bar)
- thermal_core_icon: Orange crystal
- wood_icon: Log
- stone_icon: Rock
- metal_icon: Ingot
- food_icon: Apple/bread
- water_icon: Water droplet (blue)
- fuel_icon: Flame/barrel

### Job Type Icons (for work priority panel)
- mine_icon: Pickaxe
- build_icon: Hammer
- haul_icon: Box with arrow
- cook_icon: Pot/spatula
- hunt_icon: Crosshair/bow
- research_icon: Flask/book
- medical_icon: Red cross
- clean_icon: Broom
- operate_icon: Gear/wrench
- forage_icon: Basket

### Tool Icons (for bottom toolbar)
- select_tool: Arrow cursor
- build_tool: Hammer + blueprint
- mine_tool: Pickaxe
- chop_tool: Axe
- harvest_tool: Sickle
- designate_tool: Dotted rectangle
- draft_tool: Sword/shield

### Need Icons (for colonist panel)
- warmth_icon: Thermometer (red)
- food_icon: Fork/plate
- water_icon: Water droplet
- rest_icon: Moon/bed
- morale_icon: Smiley face

### Status Icons (for colonist portrait area)
- disease_icon: Green biohazard
- wounded_icon: Red bandage
- mental_break_icon: Red exclamation
- addiction_icon: Pill with warning
- hypothermia_icon: Blue snowflake
- starving_icon: Empty plate

---

## 9. MINIMAP MARKERS (2-3 px dots)

| Marker | Color |
|--------|-------|
| colonist | Green |
| hostile_creature | Red |
| neutral_creature | Yellow |
| building | Gray |
| fire | Orange |
| raid_direction | Red arrow |

---

## SPRITE REUSE GUIDE

To minimize unique art needed, reuse base sprites with tint/overlay:

**Walls:** 1 base wall texture, tint for wood (brown), stone (gray), metal (blue-gray), insulated (tan)
**Floors:** 1 base floor texture, tint for each material
**Turrets:** 1 platform base + swap weapon top
**Traps:** 1 ground plate base + swap mechanism
**Drug vials:** 1 vial shape + color swap per drug
**Organs:** Similar red shapes, vary silhouette
**Prosthetics:** 2 bases (wood, metal) + bionic glow overlay
**Creature tiers:** Same species base, scale up + add detail for higher tiers
**Armor:** Layer overlays on colonist base

**Estimated unique sprites needed: ~270 (down from 570+ total assets)**

---

## DELIVERY FORMAT

- **Format:** PNG, 32-bit with alpha transparency
- **Background:** Transparent (checkerboard in editor)
- **Color depth:** 8-bit per channel (standard RGBA)
- **Anti-aliasing:** None (crisp pixel art, no sub-pixel smoothing)
- **Outline:** 1-2px dark outline on all sprites for readability
- **File naming:** `category/subcategory_name.png`

### Directory Structure:
```
assets/sprites/
  tiles/          (32x32 each)
  colonists/      (32x32 each)
  creatures/      (32-96px per size class)
  buildings/      (32x32 each)
  items/          (16x16 each)
  crops/          (32x32, 4 stages each)
  effects/        (8x8 particles)
  ui/             (24x24 icons)
  weapons/        (overlays + icons)
```

---

## PROMPT TEMPLATE FOR GEMINI

Copy this block and paste into Gemini with a specific category:

> Generate pixel art sprites for a top-down colony survival game set on a frozen alien world. Art style: RimWorld-meets-Frostpunk pixel art. Perspective: top-down/overhead. Palette: cold blues and grays for environment, warm industrial tones for buildings, muted earth tones for characters.
>
> **Specifications:**
> - Size: [SIZE]x[SIZE] pixels
> - Transparent PNG background
> - Crisp pixel art, no anti-aliasing
> - 1-2px dark outline for readability
> - Limited palette (4-8 colors per sprite + shading)
>
> **Generate the following sprites:**
> [PASTE SPECIFIC TABLE FROM ABOVE]
>
> Each sprite should be clearly distinct and recognizable at its target size. Label each sprite clearly.
