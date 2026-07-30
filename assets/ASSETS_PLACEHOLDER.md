# Assets: what ships here, and what does not

## Sprites — in the repo

`assets/sprites/` (365 PNGs) is the project's **own art**. It was generated for
Frosthold with the AI image pipeline this repo carries, so it is distributed with
the code under the repo's LICENSE. Nothing here is a third-party pack.

How it was made:

1. Prompts in `ART_MVP_PROMPT.md` / `ART_ASSET_TEMPLATE.md` produced labelled
   sprite sheets (1600x320 JPGs on a painted checkerboard).
2. `tools/slice_sprites.py` cut each sheet into individual sprites, keyed the
   checkerboard out to real alpha, and trimmed each sprite to its content — which
   is why sizes are irregular (339 distinct sizes across 365 files) rather than a
   uniform grid.
3. `tools/comfyui/` (`sprite_prompts.py` + `batch_generate.py`) is the newer,
   fully local path: it derives one prompt per asset from
   `FROSTHOLD_Art_Assets.md`.

See `ASSETS_NEEDED.md` in the repo root for the full manifest, the remaining art
gaps, and how to regenerate.

### Known cosmetic defects

A handful of sprites captured their sheet's caption text or the generator's
corner watermark during slicing, so they render with stray light-gray pixels
below the art. Confirmed cases include `crops/medicinal_moss_seed.png`,
`tiles/void.png`, `ui/moon_v2.png`, `items/steel.png`,
`items/eldritch_ichor.png`, `items/components.png` and
`crops/alien_fungus_mature.png` — see `ASSETS_NEEDED.md` for the full list.
Regenerating those individually fixes them; nothing depends on the artifacts.

## Audio — NOT in the repo

`assets/audio/` is **purchased packs licensed to the project owner only**, so it
is excluded from version control (see `.gitignore`) and is not redistributed.
The 16 expected files are listed in `ASSETS_NEEDED.md`.

The game does not require them. `src/audio/sound.lua` tolerates every missing
file, so a fresh clone simply **runs silent** — no errors, no missing-asset
crashes. Supply your own sounds at the documented paths to get audio back.

## Fonts

`assets/fonts/` is empty. The game uses Love2D's built-in font.
