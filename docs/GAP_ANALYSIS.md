# FROSTHOLD — Gap Analysis vs. RimWorld / Factorio / Colony-Sim Staples

_Date: 2026-07-02. Basis: full source inventory (src/, 323 Lua files), def-vs-asset
diff (script method below), test suite at 443/443 green._

## Method

Building/creature/item def tables were loaded headlessly (with `tests/mock_love`)
and their keys diffed against PNG filenames in `assets/sprites/`. Gameplay gaps
were verified absent by keyword sweep across `src/` — every claim of "missing"
below had zero (or trivially unrelated) hits.

## What FROSTHOLD already has (do not rebuild)

Thermal + generator (Frostpunk), laws/doctrines/policies/hope, full Factorio-style
logistics (belt tiers, splitters, filter/stack inserters, pipes, circuits with
sensor/comparator/actuator, storage network), power grid with batteries/solar/wind/
geothermal/nuclear, atmosphere + pressure + gas (ONI-lite), z-depth with caverns
and biocaves (DF), medical with wounds/surgery/prosthetics/bionics, disease,
addiction/drugs, taming with training/pens/breeding/slaughter, slavery + prisoners,
factions + trade + visitors, quests, expeditions + vehicles + overworld, space layer
(ships, stations, boarding), storyteller + elastic difficulty + nemesis, MRP
roguelite campaign, quality tiers, materials, seasons/weather, strange moods,
mental breaks, room impressiveness, fire/flooding/pollution/radiation/corrosion.

---

## A. Gameplay gaps (verified absent, ranked by payoff ÷ effort)

### A1. Graves, burial, and funerals — RimWorld — LOW effort, HIGH payoff
`corpse_human` is just a resource; there is no grave building, burial job, funeral
event, or grief tied to interment. A `memorial` building def already exists but has
no mechanic behind it.
**Hooks:** corpse items exist; `Social.onColonistDeath` already fires; hope.lua for
mood effects; adlib.lua can generate epitaphs. Add: grave/sarcophagus building defs,
`bury` job type, hope penalty for unburied dead, funeral social event.

### A2. Craftable art + wealth/beauty economy — RimWorld / Dwarf Fortress — MEDIUM
No sculptures, statues, or art objects anywhere (0 hits). Quality tiers
(`quality.lua`), room impressiveness (`rooms.lua`), decorations, and a procedural
text generator (`adlib.lua`) all exist — the DF-style "masterwork statue engraved
with the colony's history" is 90% pre-plumbed.
**Hooks:** add sculptor bench + art recipes to production_defs; art items carry
quality + an adlib-generated engraving describing a real event from
`world/history.lua`; impressiveness and trade value consume it.

### A3. Romance, partners, family — RimWorld — MEDIUM
`social.lua` has opinion matrix, friends, rivals, bonds — but zero romance,
marriage, or kinship (0 hits for romance/spouse/marriage). This is RimWorld's
biggest story generator.
**Hooks:** extend bond stages (friend → lover → partner); social events
(proposals, breakups) via the existing social-event system; grief multiplier on
partner death; shared bedroom expectation via rooms.

### A4. Blueprints / copy-paste / planning overlay — Factorio — MEDIUM-HIGH
Zero hits. With belt+pipe+circuit bases this is the single biggest QoL gap:
no way to copy a working furnace line, stamp repeated designs, or sketch a
plan designation before spending resources.
**Hooks:** building_placement.lua already validates placement; serialize a
rectangular selection of building defs + orientations (save_writer patterns
apply); ghost-render with the existing colored-shape fallback; planning overlay
is a zones.lua variant with no gameplay effect.

### A5. Underground belts — Factorio — LOW-MEDIUM
Belt tiers/splitters/filter inserters exist, but no underground/bridge segment
(all "underground" hits are caverns). Dense bases can't cross belt lines or
pass through walls.
**Hooks:** conveyors.lua `getMoveTargets` already resolves per-belt targets; an
underground pair is a belt with a partner lookup up to N tiles away; reuse
splitter placement UX.

### A6. Livestock produce (milk / wool / eggs) — RimWorld — LOW
Taming has training, pens, breeding, slaughter — but animals produce nothing
while alive. `hay`, `raw_fur` items already exist.
**Hooks:** per-species produce table (item, interval, handler job) in
species_defs; `Taming.step` already ticks tamed animals; add `milk`/`wool`
items + kitchen/loom recipes.

### A7. Production statistics screen — Factorio — LOW-MEDIUM
No per-item production/consumption history. With quotas demanding shipments,
players fly blind on throughput.
**Hooks:** production_runtime completions and Items.spawn are single
chokepoints; ring-buffer counters per item per day; render like the existing
colony_panel tables.

### A8. Work priorities grid — RimWorld — LOW (verify first)
`workPriority` component and per-colonist editing exist (ui_selection), but
there is no all-colonists × all-jobs matrix screen. Verify current coverage,
then add the grid panel if absent — it's the RimWorld UI players expect.

### A9. Logistics drones — Factorio bots — MEDIUM (later)
Player-owned hauler drones (drone port building, coverage radius). Creature
AI + pathfinding already support flying species (`salvage_drone`,
`maintenance_bot` exist as NPC species to reskin).

### A10. Children / colony generations — RimWorld Biotech — HIGH (campaign-fit)
No pregnancy/children/aging at all. Big lift, but uniquely valuable here because
the MRP campaign already spans multiple runs — generational colonists would
compound it. Park until A1–A8 land.

Explicitly not recommended: trains (map scale doesn't support it), mod support
(architecture cost), gas grid beyond current atmosphere sim (ONI territory).

---

## B. Art gaps (hard numbers from def-vs-asset diff)

| Category  | Defs | Have art | Missing | Fallback today |
|-----------|------|----------|---------|----------------|
| Buildings | 295  | 79       | **216** | colored rectangles |
| Creatures | 127  | 31       | **96**  | colored shapes |
| Items     | 173  | 16       | **~140**| colored dots (weapons partly covered — see B4) |
| Tiles     | ~45 enum | 30   | ~15     | colored tiles (ash/volcanic/marsh biomes mostly bare) |
| Audio     | —    | 16 files | —       | most systems silent |

### B1. Highest-frequency missing building art (do these first)
Player stares at these constantly: `door`, `wall_wood`, `wall_stone`,
`floor_wood`, `floor_stone` (entity variants), `conveyor` + `fast_conveyor` +
`express_conveyor` + all `splitter`/`inserter` tiers, `storage_chest`/`crate`/
`shelf`/`locker`, `battery`, `solar_panel` (tracking/concentrated), `wind_turbine`
(large), `hospital_bed`, `comfort_bed`, `industrial_kitchen`, `library`,
`tavern_bar`, `sun_lamp`, `hydroponic_basin`, `airlock`, `bridge`. Then the
turret family (10+ variants missing), then space/underwater sets.

### B2. Creature art priorities
Common biome fauna the player sees daily (`timber_wolf`, `plains_bear`,
`forest_rabbit`, `great_elk`, `wild_boar`, `songbird`), then raid units
(`siege_automaton`, `patrol_automaton`, `mammona_enforcer_mech`,
`hunter_killer`), then the named bosses (`the_depth_mother`, `the_warden`,
`the_emergence`, `the_dissolvent`) which currently render as colored blobs at
their most dramatic moment.

### B3. Colonist visual identity — biggest art-feel gap overall
17 state sprites, one generic parka body. The clothing system defines **25
wearables across 7 slots** and none of it renders on the pawn. RimWorld-style
layered rendering (body → apparel tint layers → held weapon) would do more for
game feel than any single system above. Weapon sprites already exist and
`armed_melee`/`armed_ranged` states prove the render hook.

### B4. Housekeeping
- Weapon sprite names are prefix-stripped (`pistol.png` for `weapon_pistol`);
  2 junk names (`sprite_016/017.png`) need renaming to real ids.
- `ART_MVP_PROMPT.md` is the existing generation pipeline — extend it with
  per-category prompt sections generated from the missing lists above
  (`ART_ASSET_TEMPLATE.md` has the format).

## Suggested sequencing

1. **A1 graves + A6 livestock produce** (days, big mood/story payoff)
2. **B1 building art batch 1 + B3 pawn apparel layers** (art pipeline pass)
3. **A2 art economy + A5 underground belts + A7 prod stats**
4. **A3 romance** then **A4 blueprints**
5. **A9 drones**, **A10 children** with the next campaign milestone
