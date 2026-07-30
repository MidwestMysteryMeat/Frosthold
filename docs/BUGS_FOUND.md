# Bugs found — 2026-07-30 audit

Found by adding `luacheck` to the repo for the first time (it had none, and no
repo in the account did) and triaging the high-signal codes by hand.

All findings are pre-existing and present on `main`. Fixed on `audit/slim`.

Severity: **Crash** = throws · **Silent** = wrong behaviour, no error ·
**Latent** = wrong but currently unreachable or masked.

---

## 1. `src/space/hazards.lua` — star corona only ever burned one colonist

| | |
|---|---|
| **Severity** | Silent |
| **Code** | `W512` loop is executed at most once |

```lua
for cid in ECS.query('colonist') do
    local col = ECS.get(cid, 'colonist')
    if col and not col.dead then
        col.health = math.max(1, (col.health or 100) - dt * 3)
    end
    break          -- <-- outside the if
end
```

`STAR_CORONA` is an area hazard: it damages `ship.hullHP` unconditionally and is
clearly meant to burn the crew. But the `break` sits *outside* the `if`, so the
loop always exits on its first iteration. Only one colonist ever took heat damage
— and if that first entity happened to be dead, **nobody did**.

Compare `src/creatures/creatures.lua:297`, which places `break` *inside* the `if`
— that is the correct "find the first match" idiom, and is almost certainly what
this was copy-pasted from.

**Fix:** removed the `break`. All living colonists now take corona damage.
**Behaviour change:** yes — corona is meaningfully more dangerous than before.

---

## 2. `src/building/production_runtime.lua` — two `ITEM_TO_RES` tables, diverged

| | |
|---|---|
| **Severity** | Latent |
| **Code** | `W411` variable redefined |

`ITEM_TO_RES` was defined twice in the same scope:

- line 26: `local ITEM_TO_RES = defs.ITEM_TO_RES` — **111 entries**
- line 247: a 64-line hardcoded literal — **113 entries**

The second shadowed the first, and every use site sat after line 247 — so the
line-26 binding was dead, shadowed before it was ever read.

The two tables did not match. The runtime literal carried `lead` and `lead_ore`;
the shared defs table did not. Worse, the export was written twice:

```lua
src/building/production.lua:9       Production.ITEM_TO_RES = defs.ITEM_TO_RES   -- 111
src/building/production_runtime.lua Production.ITEM_TO_RES = ITEM_TO_RES        -- 113, overwrites
```

Whichever ran last won. `src/building/work_orders.lua:200` reads that export to
map an output item to a stockpile resource, so lead handling depended on module
init order rather than on the data.

**Fix:** added `lead` and `lead_ore` to the defs table (now the complete
113-entry source of truth), deleted the runtime duplicate and its re-export.
`-70 lines`, one source of truth, no shadowing.

---

## 3. `src/util/pathfind.lua` — orphaned `::skip_neighbor::` label

| | |
|---|---|
| **Severity** | Cosmetic (dead syntax) |
| **Code** | `W521` unused label |

The neighbour loop ended with `::skip_neighbor::`, but **the file contains no
`goto` at all**. The label was left behind by a refactor that replaced a
skip-jump with structured cost surcharges (the current code adds movement cost
rather than skipping tiles).

Harmless at runtime — a label with no jump is a no-op — but it advertises a
control-flow path that no longer exists.

**Fix:** removed the label. No behaviour change.

---

## 4. `src/ui/ui.lua` — double negative in the laser-fence toggle

| | |
|---|---|
| **Severity** | Cosmetic |
| **Code** | `W581` |

`fence.toggled = not (fence.toggled ~= false)` → rewritten as
`fence.toggled = (fence.toggled == false)`. Identical behaviour, legible.

---

## 5. `src/colonist/jobs.lua` — allowed-area restriction was calculated, then ignored

| | |
|---|---|
| **Severity** | Silent |
| **Code** | `W311` value assigned but never used |

`Jobs.findBestTask` correctly set `canDo = false` when a task or its drop-off
was outside the active allowed area. It then inserted the task into the
candidate bucket unconditionally, without checking `canDo` again. Colonists
therefore selected forbidden work whenever it otherwise won priority/distance
sorting.

**Fix:** only insert the task after the allowed-area result passes. A regression
test puts a forbidden task closer than an allowed one and verifies the farther
allowed task wins. The test also exposed cross-test zone leakage, so
`H.resetAll()` now resets zones.

---

## Verified NOT bugs

Worth recording, because each looked like one:

- **`table.unpack` in `src/ecs/ecs.lua:7` and `src/util/profiler.lua:17`** (`W143`,
  "accessing undefined field 'unpack' of global 'table'"). Both use the correct
  compatibility idiom — `local unpack = unpack or table.unpack` and
  `local unpackFn = table.unpack or unpack`. `table.unpack` is nil under LuaJIT
  and `unpack` is nil under 5.2+, so the `or` covers both. Confirmed with
  `luajit -e 'print(table.unpack, unpack)'`.
- **`src/world/tilemap.lua:572`** (`W412`, `seed` redefined as an argument).
  `local seed = mapSeed` shadows the `seed` parameter, but
  `mapSeed = seed or love.math.random(...)` runs 11 lines earlier, so the value
  is identical. Redundant, not broken.
- **Eight of the nine `W512` hits.** `Fire.getFirstFirePos`,
  `ShipManager.getShipAnchor`, `ShipMovement.setHeading`, the two
  `getSingleKey`/`getSingleFilterKey` helpers, and the selected-entity lookups in
  `debug_panel.lua` / `input.lua` are all deliberate "take the first key of this
  table" idioms. Only `hazards.lua` was wrong.
- **`src/ui/colonist_info.lua:107`** (`W411`, `sok` redefined). Two independent
  `pcall(require, ...)` results reusing the same name; each is consumed
  immediately after assignment. Sloppy, not a defect.
- **`src/ui/settings_panel.lua:595`** (`W113`, undefined `jit`). `jit` is a real
  LuaJIT global and the line type-checks it (`type(jit) == 'table'`) before use.
  Declared in `.luacheckrc` instead of "fixed".

Hit rate: **21 high-signal warnings triaged, 4 real findings, 1 with gameplay
impact.** The `W512` class was worth running — it is the same code that exposed a
real quest-marker bug in TavernQuest.

---

## Security fix (separate commit)

`main.lua`'s crash handler silently emailed a crash report **and a screenshot of
the player's screen** to the developer, by shelling out through `os.execute` to
`tools/send_error_email.py`. On a public repo that is undisclosed telemetry from
anyone who plays and hits an error, plus a command-injection surface via
string-formatted paths. Removed; the handler still writes `crash_error.txt`
locally. `tools/run_autoplay.py` did the same and now prints local paths.

---

## Follow-up verification

The original pass stopped at **0 errors / 120 warnings**, so the documented
`luacheck .` command still exited nonzero and was not yet a usable gate. The
follow-up pass resolved all 120:

- 61 intentional `main.lua` startup shadows are now scoped with a local
  luacheck directive and an explanation of the LuaJIT upvalue limit.
- The other 16 `W431` sites now reuse or clearly rename their cached modules.
- Dead stores/imports were removed, deliberate take-first loops use `next()` or
  a single iterator call, and Lua 5.1/5.2 `unpack` compatibility remains intact.
- The `W311` in `jobs.lua` was the real allowed-area bug described above.

**Current verification:** `luacheck .` reports **0 warnings / 0 errors** and the
headless suite passes **543/543**.
