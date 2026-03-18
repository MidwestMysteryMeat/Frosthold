# Frosthold QA Playtest Checklist

Use this after the automated suite is green. The goal is not just "no crash"; it is "the run stays readable, recoverable, and on-theme."

## Quick Commands

Run the automated baseline first:

```powershell
luajit tests/run_all.lua
luajit tools/run_soak_report.lua
```

If either fails, fix that before manual playtesting.

## Session Matrix

Run these four sessions:

1. `Crashlanded / Standard Deployment / HERMES - Standard`
2. `Crashlanded / Deep Freeze / HERMES - Aggressive`
3. `Sole Survivor / Standard Deployment / HERMES - Corrupted`
4. `Prior Expedition / Stable Orbit / HERMES - Standard`

## Pass/Fail Rules

Mark the session as a `FAIL` if any of these happen:

- Start flow is confusing or blocks progress.
- The colony dies to an unreadable chain with no clear lesson.
- A core system stops surfacing its state when it matters.
- The player cannot understand why a raid, breach, quota, or defeat happened.
- UI panels or overlays fight each other or hide critical information.
- Endgame buildings or victory conditions feel disconnected from the rest of the run.

## Early Game: Days 1-5

Check these in the first run:

- Start menu -> crew draft -> live colony flow is clear.
- The starting shelter, beds, food, and initial tasks are legible.
- Heat, atmosphere, and power read clearly without debug knowledge.
- The advisor gives useful guidance instead of repeating noise.
- Build and research search are fast enough to use under pressure.
- A new player can find work priorities, bills, zones, and overlays without guessing too much.
- Quota timing is understandable within the first cycle.

Questions to answer:

- Did I know what to build first?
- Did the HUD explain quota/HERMES/containment pressure well enough?
- Did any colonist behavior look obviously wrong or stuck?

## Mid Game: Days 6-20

Push into real colony management:

- Make at least one stockpile with filters.
- Create at least one allowed area and verify colonists respect it.
- Set at least one machine bill and adjust its settings.
- Use logistics overlays and confirm they help more than they clutter.
- Trigger at least one real raid and one bad weather event.
- Use at least two defense/trap types.
- Save, load, and continue the run.

Questions to answer:

- Are raids varied enough without feeling random?
- Do weapons, traps, fire, gas, and hazard fields read clearly?
- Do bills, inserters, and stockpiles feel like tools or chores?
- Is any screen too dense to use during a live threat?

## Late Game: Containment Run

In one session, deliberately pursue containment content:

- Recover at least one artifact subject and one Erebus-Touched human.
- Build containment cells and switch between modes.
- Study, purge, and transfer at least one subject.
- Let one containment problem escalate far enough to create pressure.
- Observe doctrine, social, quota, and HERMES reactions.
- Turn on containment, atmosphere, and structural overlays while managing it.

Questions to answer:

- Does containment feel like a core pillar, not a side feature?
- Are subject states and risks understandable before a breach?
- Does the horror tone come through in play, not just in lore text?
- Does HERMES feel like a real pressure source?

## Endgame Validation

Over one or more runs, verify all of these:

- `Transmission Array`
- `Launch Pad`
- `Sealing Apparatus`
- `Extraction Beacon`
- One total-wipe rescue
- One post-rescue final defeat

Questions to answer:

- Did the route feel earned?
- Did the route match the lore?
- Did the UI communicate what was required before activation?

## Visual/Audio Polish Checks

Watch for these specifically:

- Projectile and hazard VFX are readable at normal zoom.
- Fire, napalm, bio clouds, fallout, and containment pulses are visually distinct.
- Overlays stay readable when weather, combat, and alerts stack.
- Long HUD strings do not overlap or clip.
- Placeholder audio is not missing or firing at the wrong moment.

## Bug-Hunt Prompts

Deliberately try to break these:

- Cancel or reorder bills while a machine is active.
- Toggle overlays rapidly while selecting buildings and zones.
- Move colonists between allowed areas during raids or breaches.
- Save/load with active hazards, containment subjects, quotas due, and a live raid.
- Run long sessions on 2x and 3x speed.
- Force a rescue, then continue to endless mode and keep playing.

## Session Log Template

Copy this for each run:

```text
Scenario:
Difficulty:
Director:
Run length:
Outcome:

Top 3 friction points:
1.
2.
3.

Top 3 strongest moments:
1.
2.
3.

Unreadable system states:
- 

Bugs:
- 

Balance notes:
- 

UI/UX notes:
- 

Lore/tone notes:
- 
```
