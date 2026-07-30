# Assets Needed

What Frosthold ships, what it is missing, and what happens when something is
absent. Nothing in this document is required to play — the game boots and runs
with every optional asset missing.

| | Status |
|---|---|
| **Sprites** (`assets/sprites/`, 365 PNGs) | Ship with the repo. Own AI-generated art, regenerable — see [Regenerating sprites](#regenerating-sprites). |
| **Audio** (`assets/audio/`, 16 files) | **Not distributed.** Purchased packs, licensed to the project owner only. Game runs silent without them. |
| **Fonts** (`assets/fonts/`) | Empty by design. Love2D's built-in font is used. |

---

## AUDIO

All 16 sounds are **optional**. `src/audio/sound.lua` lazy-loads each file on
first use; `tryLoad()` (`src/audio/sound.lua:81`) returns `false` when the file is
absent and caches that result, and every caller early-returns on `false`
(`Sound.play` line 139, `Sound.startLoop` line 156). A clone with no audio
produces **no errors and no warnings — just silence.**

**Format:** the loader looks for `.ogg` first, then falls back to the same name
with a `.wav` extension (`resolvePath`, `src/audio/sound.lua:69`). Either works.
Loops are streamed, one-shots are static. Mono or stereo; no sample-rate
requirement. Volumes are applied at play time, so master your files at a
consistent level and let the mixer scale them.

**Volume categories** (`src/audio/sound.lua:19-28`) — master `0.8`, then
`ambient 0.5`, `ui 0.7`, `creature 0.6`, `weather 0.7`, `work 0.5`.

### Wired up — these actually play

| path/pattern | type | format | dimensions | used for | required/optional | fallback behavior |
|---|---|---|---|---|---|---|
| `assets/audio/weather/blizzard_howl.{ogg,wav}` | weather loop | ogg/wav, looping | ~5-20 s seamless loop | Starts when weather becomes `blizzard` or `whiteout`, stops otherwise (`src/audio/sound.lua:185-197`) | optional | silence |
| `assets/audio/ui/click.{ogg,wav}` | ui one-shot | ogg/wav | ~50-150 ms | Every button/menu click (`src/ui/ui.lua:13`, `src/ui/build_menu.lua:10`) | optional | silence |
| `assets/audio/ui/build_place.{ogg,wav}` | ui one-shot | ogg/wav | ~200-500 ms | A building is placed; positional at the build tile (`src/building/building_placement.lua:574`) | optional | silence |
| `assets/audio/ui/task_complete.{ogg,wav}` | ui one-shot | ogg/wav | ~200-500 ms | A colonist finishes a job; positional at the task tile (`src/colonist/jobs.lua:141`) | optional | silence |
| `assets/audio/ui/alert.{ogg,wav}` | ui one-shot | ogg/wav | ~300-800 ms | Colonist mental break (positional, `src/colonist/mental_breaks.lua:431`) and raid incoming (`src/sim/raids.lua:994`) | optional | silence |
| `assets/audio/ui/alert_critical.{ogg,wav}` | ui one-shot | ogg/wav | ~300-800 ms | A `critical`-tier alert is raised (`src/ui/alerts.lua:15`, dispatched at `:60`) | optional | silence |
| `assets/audio/ui/alert_major.{ogg,wav}` | ui one-shot | ogg/wav | ~300-800 ms | A `major`-tier alert is raised (`src/ui/alerts.lua:16`) | optional | silence |
| `assets/audio/ui/alert_minor.{ogg,wav}` | ui one-shot | ogg/wav | ~300-800 ms | A `minor`-tier alert is raised (`src/ui/alerts.lua:17`) | optional | silence |

`info`-tier alerts are deliberately silent (`sound = nil`, `src/ui/alerts.lua:18`).

### Defined but not currently played

These IDs exist in the `SOUNDS` table (`src/audio/sound.lua:34-60`) and the game
would load them, but **no code path calls them today.** Supplying the files
changes nothing until a call site is added. Listed so the set of 16 is complete.

| path/pattern | type | format | dimensions | used for | required/optional | fallback behavior |
|---|---|---|---|---|---|---|
| `assets/audio/ambient/wind_loop.{ogg,wav}` | ambient loop | ogg/wav, looping | seamless loop | Intentionally disabled — "was playing constant white noise" (`src/audio/sound.lua:181`) | optional, inert | silence |
| `assets/audio/weather/snow_crunch.{ogg,wav}` | weather one-shot | ogg/wav | ~100-400 ms | Intended: footsteps on snow. No call site. | optional, inert | silence |
| `assets/audio/creature/wolf_howl.{ogg,wav}` | creature one-shot | ogg/wav | ~1-3 s | Intended: wolf ambience/aggro. No call site. | optional, inert | silence |
| `assets/audio/creature/bear_roar.{ogg,wav}` | creature one-shot | ogg/wav | ~1-3 s | Intended: bear aggro. No call site. | optional, inert | silence |
| `assets/audio/creature/titan_stomp.{ogg,wav}` | creature one-shot | ogg/wav | ~1-2 s | Intended: frost titan footfall. No call site. | optional, inert | silence |
| `assets/audio/work/pickaxe_hit.{ogg,wav}` | work one-shot | ogg/wav | ~100-300 ms | Intended: mining strike. No call site. | optional, inert | silence |
| `assets/audio/work/hammer.{ogg,wav}` | work one-shot | ogg/wav | ~100-300 ms | Intended: construction strike. No call site. | optional, inert | silence |
| `assets/audio/work/saw.{ogg,wav}` | work one-shot | ogg/wav | ~300-800 ms | Intended: sawmill/woodcutting. No call site. | optional, inert | silence |

Positional sounds attenuate linearly to silence at 40 tiles from the camera
centre (`positionalFactor`, `src/audio/sound.lua:113`).

---

## ART

Sprites ship with the repo, but **coverage is partial.** Every getter in
`src/render/sprites.lua` returns `nil` for an unmapped ID, and the renderer draws
a colored rectangle/shape instead (e.g. `src/render/renderer.lua:752-764`). A
missing sprite is never an error.

### Coverage as of this document

Counts verified against the definition tables, not estimated:

| category | defined | has a sprite | renders as a colored shape |
|---|---|---|---|
| Buildings (`src/building/building_defs.lua`) | 295 | 79 | **216** |
| Creatures (`src/creatures/species_defs.lua`) | 127 | 31 | **96** |

Sprites present on disk, by folder: `buildings` 66, `items` 92, `defense` 40,
`creatures` 38, `crops` 32, `ui` 32, `tiles` 30, `weapons` 18, `colonists` 17.

### Gaps

| path/pattern | type | format | dimensions | used for | required/optional | fallback behavior |
|---|---|---|---|---|---|---|
| `assets/sprites/buildings/<defId>.png` | building sprite | PNG RGBA | trimmed to content, ~34-131 x 68-172; scaled to tile size at draw | 216 of 295 building def IDs have no sprite | optional | colored rectangle per building type |
| `assets/sprites/creatures/<species>.png` | creature sprite | PNG RGBA | trimmed, ~57-284 x 44-274 | 96 of 127 species have no sprite | optional | colored shape sized by species `size` |
| `assets/sprites/tiles/<name>.png` | terrain tile | PNG RGBA | trimmed; `160x320` and `267x262` are the common source sizes | Unmapped tile enums, plus `ORE_VEIN` deliberately omitted — "source art too gray, checkerboard survives slicing" (`src/render/sprites.lua`) | optional | flat tile color |
| pawn apparel | overlay sprite | PNG RGBA | 32x32-ish overlay | **Nothing exists.** No apparel art and no apparel draw path anywhere in `src/render/` | missing feature | colonist drawn without apparel |
| pawn weapons | overlay sprite | PNG RGBA | trimmed, ~13-81 x 115-233 | 18 weapon sprites exist, but `Sprites.getWeapon` (`src/render/sprites.lua:200`) is **never called** | unwired | colonist drawn without a weapon |

### Shipped but never drawn

82 sprites are in the repo with no renderer call site. Their getters are defined
in `src/render/sprites.lua` but appear nowhere else in the codebase:

- `Sprites.getWeapon` (line 200) — 18 files in `assets/sprites/weapons/`
- `Sprites.getUI` (line 191) — 32 files in `assets/sprites/ui/`
- `Sprites.getCrop` (line 209) — 32 files in `assets/sprites/crops/`

Wiring these up is art-free work: the assets are already present.

### Known cosmetic defects

Some sprites captured their source sheet's caption text or the image generator's
corner watermark when they were sliced, so they render with stray light-gray
pixels below the art. Confirmed: `crops/medicinal_moss_seed.png`,
`tiles/void.png`, `ui/moon_v2.png`, `items/steel.png`,
`items/eldritch_ichor.png`, `items/components.png`,
`crops/alien_fungus_mature.png`, `crops/frost_wheat_mature.png`,
`crops/psychoid_plant_seed.png`, `items/item2_sprite_009.png`,
`buildings/treadmill.png`, `buildings/workbench_v2.png`. This list is a lower
bound — it only catches artifacts separated from the art by a transparent gap.
Regenerating an individual sprite fixes it.

Sprites still named `sprite_NNN` / `item2_sprite_NNN` / `item3_sprite_NNN` are
unnamed slicer leftovers that were never mapped to a game ID.

---

## Regenerating sprites

Two paths exist. Neither writes into `assets/sprites/` by default — both stage
output elsewhere so you can review it before copying it in.

### Local ComfyUI pipeline (preferred)

Prompts are derived per-asset from the checklist in `FROSTHOLD_Art_Assets.md`, so
adding a row there is enough to make an asset generatable.

```bash
# one-time model/LoRA setup
tools/comfyui/setup_pixelart.sh
tools/comfyui/setup_upscaler.sh

# preview what would be generated, and where each file lands
python tools/comfyui/sprite_prompts.py --count
python tools/comfyui/sprite_prompts.py --category creatures
python tools/comfyui/sprite_prompts.py --id frost_titan   # full prompt for one asset

# generate (needs a ComfyUI server; skips assets that already have a PNG)
python tools/comfyui/batch_generate.py --category creatures
python tools/comfyui/batch_generate.py --category creatures --dry-run

# optional upscale/refine pass — both paths are required
python tools/comfyui/batch_upscale.py --input ./gen_sprites --output ./gen_upscaled
```

- Entry point: `tools/comfyui/batch_generate.py`
- Prompt builder: `tools/comfyui/sprite_prompts.py` (`build_asset_list()`)
- Workflows: `workflow_pixelart.json`, `workflow_pixelart_lora.json`,
  `workflow_upscale_fast.json`, `workflow_upscale_refine.json`
- **Output: `./gen_sprites/` by default** (`--output/-o` to change). Files are
  named `<id>.png` from the asset's checklist row; the target category folder
  comes from `PROMPT_TEMPLATES` in `sprite_prompts.py`. Copy approved sprites
  into `assets/sprites/<subdir>/` yourself.
- Defaults worth knowing: `--checkpoint dreamshaper_8.safetensors`,
  `--server 127.0.0.1:8188`, `--variants 1`. `--include-existing` regenerates
  assets that already have a PNG; `--resume` continues an interrupted run.

### Sheet-slicing path (how the current 365 were made)

Generate a labelled sprite sheet from the prompts in `ART_MVP_PROMPT.md` /
`ART_ASSET_TEMPLATE.md`, save it as a JPG, then slice it:

```bash
python tools/slice_sprites.py --dry-run          # report detected sprite boxes
python tools/slice_sprites.py --sheet=creat2     # slice one sheet
python tools/slice_sprites.py                    # slice every configured sheet
```

- Entry point: `tools/slice_sprites.py`
- Sheet definitions: the `SHEETS` list — per sheet it holds the source filename,
  output subdirectory, ordered sprite names, row splits and whether the sheet has
  captions (`has_labels`)
- Input directory and output root are the `DOWNLOADS` and `OUTPUT_ROOT` constants
  at the top of the file; set them for your machine
- Output: `<OUTPUT_ROOT>/<outdir>/<name>.png`, written as trimmed RGBA with the
  checkerboard keyed out. Unnamed extras become `sprite_NNN.png`
- Review output before copying into `assets/sprites/` — this is the step that
  produced the caption-bleed defects listed above

### Procedural fallbacks

Two scripts draw sprites directly with PIL, no model required:

- `python tools/regen_sprites.py` — 96x96 creature sprites from the colors and
  sizes in `species_defs.lua`
- `python tools/generate_colonist_sprites.py` — 32x32 colonist sprites for each
  pose/state
