# FROSTHOLD

**A Frostpunk × RimWorld colony survival sim built in Love2D — keep a crew alive on a frozen corporate deathworld, feed the quota, and decide how the run ends.**

## What it does

You manage a small colony on a hostile ice planet owned by the Mammona corporation. Colonists have needs, skills, schedules, wounds, diseases, addictions, and opinions of each other. The world pushes back with raids, megafauna, weather, fires, floods, and an anomaly that gets angrier the deeper you dig. Under it all runs a Factorio-style logistics layer — conveyor belts, splitters, filter inserters, pipes, and circuits — feeding a production economy that has to satisfy Mammona's shipment quotas. Runs end in one of four victories (or a lot of deaths), feeding a roguelite meta-campaign (MRP) that persists unlocks and nemesis raiders across planets.

Everything is driven by a sparse-set ECS (`src/ecs/ecs.lua`) over a fixed 20 Hz timestep.

## Status

**Systems-complete, art-incomplete.** All major systems are implemented and covered by a 443-assertion-passing test suite (443/443 as of 2026-07-02). The big rough edges:

- ~216 of 295 buildings, ~96 of 127 creatures, and most items render as colored shapes (no sprite yet)
- Colonists don't visually render their equipped clothing/weapons
- Balance is playtested lightly; late-game (space layer, boss routes) least of all

## How to run

Requires [LÖVE 11.4](https://love2d.org/).

```
# play
love .

# run the full test suite (no LÖVE needed — plain Lua 5.1+ works)
lua tests/run_all.lua

# scripted simulation scenarios
run_simulation_test.bat [quick|survival|endurance|combat|building|persistence|full]
```

Debug overlay: F4 in-game.

## Screenshots

_TODO — menu and colony-view captures pending._

## Known issues / roadmap

See [`docs/GAP_ANALYSIS.md`](docs/GAP_ANALYSIS.md) for the full prioritized roadmap. Short version:

1. Graves/funerals and livestock produce (quick wins)
2. Building-art batch + pawn apparel rendering (the felt gap)
3. Craftable art economy, underground belts, production stats screen
4. Romance/family, then blueprint copy-paste
5. `ui.lua`/`building.lua` are over the project's own 2000-line limit and need splitting (tracked in `CLAUDE.md`)

Project conventions live in `CLAUDE.md`; the shared task board is `TASKS.md`.

## AI development note

Developed with AI assistance — **Anthropic Claude** (Claude Code) for implementation and **OpenAI Codex** for review — following the strict ECS/persistence conventions in `CLAUDE.md`. Human direction owned the architecture, design, and priorities. The 2026-07-02 pass took the test suite from 380/443 to 443/443 (fixing free merchant purchases, missing victory triggers, and junk item spawns) with Claude. The code is well-covered by tests but has not been professionally security-audited.

## License

MIT — see [LICENSE](LICENSE). Sprites were generated for this project (see `ART_MVP_PROMPT.md` for the pipeline).
