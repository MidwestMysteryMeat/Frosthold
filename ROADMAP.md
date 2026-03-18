# FROSTHOLD — Feature Roadmap (Phase 11+)

Scoped 2026-03-12. All 33 features across 7 categories.

## Implementation Priority Order

### Foundation Layer (implement first — other features depend on these)
1. **Quality system** (8 tiers) — items, crafting, stockpiles, trade all reference quality
2. **Material system** (20+ with properties) — items, crafting, armor, building all reference materials
3. **Passion system** (2 levels) — affects XP gain, quality rolls, UI display
4. **Skill rust** — simple addition once passion exists
5. **Damage type system** (7 types) — armor, weapons, combat all reference damage types
6. **Centralized tooltip framework** — all UI features need consistent tooltips

### Colonist Layer
7. **Traits expansion** (50+ pool, 2-3 per colonist)
8. **Backstory work locks** — backstories disable 1-2 work types
9. **Opinion modifiers** (30+ including trait-specific)
10. **Recreation/joy system** — joy + variety + quality expectations
11. **Romance & family** — lovers, marriage, breakups, morale events
12. **Children & aging** — growth stages + passive learning from nearby adults
13. **Evolving ideology** — beliefs form from colony experiences

### Combat Layer
14. **Prosthetics & bionics** (4 tiers: crude/standard/bionic/precursor)
15. **Armor slots & damage types** (3 slots, 7 damage types)
16. **Melee weapons** (12+ weapons + stances)
17. **Prisoner system** (recruit/release/harvest/interrogate)
18. **New raid tactics** (drop pods, sappers, siege, infiltrators)

### World Layer
19. **Season system** (temp shifts + events + visuals)
20. **Natural water** (rivers, meltwater floods, geysers, hot springs)
21. **Flora variety** (20+ plants, tiered farming)
22. **Map size expansion** (up to 512x512, chunk-based rendering)
23. **Map secrets** (sealed ruins, frozen colonists, Thing-mimics, precursor artifacts, caverns)
24. **Skinwalker/wendigo events** — mimics lure colonists, infiltrate colony

### Production Layer — COMPLETE
25. **Stockpile filtering** (category/item/quality/material + priority) — DONE
26. **Conditional work orders** (full bill system) — DONE
27. **Trade depth** (rep pricing, supply/demand, trade routes) — DONE

### Events Layer — COMPLETE
28. **Event expansion** (social, peaceful, environmental, eldritch/cult, burrowing creatures) — DONE
29. **Caravans & visitors** (trade caravans, refugees, diplomats, hostile scouts) — DONE
30. **Procedural history** (lore-constrained micro factions, adlib history) — DONE

### UI Layer — COMPLETE
31. **Colonist info panel** (expanded tabs + bio/combat/log + character portrait) — DONE
32. **Alert/letter system** (priority tiers, letters, audio cues) — DONE
33. **UI polish** (item tooltips, drag priorities, zone painting) — DONE

### Endgame / Unique Layer — COMPLETE
34. **Thermal deepening** (trading, heat-gated areas, storage batteries, thermal weapons, craftable cores/gear) — DONE
35. **Multiplayer expansion** (shared overworld, raids, co-op, economy — all optional per MP doc) — DONE
36. **Precursor endgame** (anomaly escalation, artifacts, That Which Sleeps arc, colony legacy) — DONE
  - That Which Sleeps: defeating it doesn't win — clears map, unlocks Mammona extraction win condition

---

## Detailed Feature Specs

### 1. Quality System
- 8 tiers: Awful / Shoddy / Poor / Normal / Good / Excellent / Masterwork / Legendary
- Crafter skill determines quality roll distribution
- Legendary requires inspiration event OR max skill (rare)
- Quality affects: item stats, beauty, value, durability
- Named legendary items with unique bonuses

### 2. Material System
- 20+ materials with property system
- Properties: flammability, thermal conductivity, beauty, durability, hardness, value
- Categories: stone (granite, slate, marble), wood, cloth, leather, metals (steel, plasteel, thermal alloy), exotic (precursor chitin, void crystal, bone, sinew)
- Material affects everything built from it

### 3. Passion System
- 2 levels: Interested (1.5x XP), Passionate (2x XP)
- Randomly assigned at colonist generation
- Displayed on skill UI with visual indicator
- Affects quality roll bonus for relevant crafting

### 4. Skill Rust
- Unused skills get 'rusty' flag after ~15 days idle
- Rusty = -20% effectiveness at that skill
- Clears after a few successful uses
- Visual indicator in skill UI

### 5. Damage Types
- 7 types: sharp, blunt, cold, fire, bio, electric, explosive
- Armor has resistance per type
- Weapons deal primary + optional secondary damage type
- Environmental sources: cold (frostbite), fire (burns), bio (disease/spore)

### 6. Traits (50+ pool)
- 2-3 traits per colonist, some mutually exclusive
- Trait categories: personality, physical, mental, background
- More gameplay-affecting traits (not just flavor)
- Trait-specific opinion modifiers and mental break triggers

### 7. Backstory Work Locks
- Each backstory disables 1-2 work types
- Example: "Noble Exile" can't clean or haul, "Pacifist Medic" can't do violence
- Displayed in colonist bio tab
- Affects colonist select screen viability

### 8. Opinion Modifiers (30+)
- Environmental: ate without table, slept on floor, ugly room, impressive room, dark room
- Social: was insulted, received gift, friend died, rival nearby, shared meal
- Comfort: ate raw food, wore tattered clothes, cold room, comfortable bed
- Trait-specific: neat colonist hates messy rooms, ascetic likes simple rooms
- Each modifier has magnitude and decay timer

### 9. Recreation
- Joy need (0-100) added to colonist needs
- Recreation types: socializing, gaming, art, music, exercise, meditation
- Variety need: diminishing returns from same type, bonus from switching
- Quality expectations: higher-expectation colonists need better recreation buildings
- Recreation buildings: horseshoe pin, chess table, library, instrument, gym

### 10. Romance & Bonds
- Colonists develop romantic interest based on opinion + compatibility
- Stages: single -> dating -> lovers -> bonded
- Bond ceremony = colony morale event
- Breakups/divorce = mood debuff
- Widowed grief (longer, more severe)
- Double beds and partner room logic

### 11. Children
- CUT FROM CURRENT SCOPE
- Colony growth is handled by rescue, recruitment, expeditions, and cloning vats.
- No pregnancy or child simulation is planned for Erebus's shipped scope.

### 12. Evolving Ideology
- Colony starts with no beliefs
- Events trigger belief formation (survived famine -> food hoarding, lost colonist to cold -> thermal priority)
- 15-20 possible beliefs, colony accumulates 3-5 over time
- Each belief provides morale modifier (positive for aligned behavior, negative for violation)
- Beliefs can shift if contradicted enough times

### 13. Prosthetics (4 tiers)
- Crude: peg leg, hook hand (50% function, craftable early)
- Standard: prosthetic leg/arm (80%, mid-game research)
- Bionic: bionic limb (120% function, late research, expensive)
- Precursor: exotic implants (150%+, found in ruins, alien aesthetics, possible side effects)
- Surgery system: medical skill check, failure = damage

### 14. Armor (3 slots, 7 damage types)
- Slots: head, torso, legs
- Each slot has resistance values per damage type
- Material determines base resistance profile
- Quality multiplies effectiveness
- Cold resistance ties into thermal system

### 15. Melee Weapons (12+ with stances)
- Weapons: knife, club, axe, spear, sword, hammer, power fist, stun baton, thermal blade, ice pick, chain weapon, precursor blade
- Stats: damage, speed, reach, armor penetration
- Special effects: stun chance, fire damage, bleed, armor pierce
- Stances: aggressive (+damage, -dodge), defensive (+block, -damage), balanced
- Skill affects hit chance and stance effectiveness

### 16. Prisoners
- Recruit: social skill checks over time, success converts prisoner to colonist
- Release: let go, faction rep bonus
- Enslave: CUT FROM CURRENT SCOPE
- Organ harvest: dark action, massive hope penalty, mental break risk for witnesses
- Interrogate: intel on raids/bases/loot, skill-based success, can injure prisoner

### 17. Raid Tactics
- Drop pods: enemies land inside base, bypass walls, force interior defense
- Sappers: dig through walls targeting weakest section, bypass killboxes
- Siege: set up camp outside, build mortars, bombard base, must sortie to break
- Infiltrators: disguised as visitors/traders, attack from within at night

### 18. Seasons
- 4 seasons with temperature curves (deep winter -60C, thaw -10C)
- Spring: meltwater floods, foraging bonus, beast migrations inward
- Summer: warmest, best foraging, raids increase
- Fall: harvest window, pre-winter stockpiling, raid lull
- Winter: deep cold, blizzards, siege raids, survival mode
- Visual: snow depth changes, ice melt puddles, aurora season, daylight shifts

### 19. Natural Water
- Frozen rivers generated on map
- Ice fishing holes: food source, skill-based yield
- Warm events cause meltwater floods (damage buildings, create temp water tiles)
- Thermal geysers: natural heat sources, buildable around, strategic positions
- Hot springs: morale bonus, minor healing for visitors

### 20. Flora (20+ with farming tiers)
- Surface: frost moss, ice berry, snow pine, tundra grass, lichen
- Underground: cave fungus, glow lichen, deep root
- Medicinal: frost leaf, blood moss
- Exotic: precursor vine, void bloom (harvestable)
- Farming tiers: basic outdoor -> greenhouse (heated) -> hydroponic (research-gated)
- Seasonal growth cycles

### 21. Map Size (up to 512x512)
- Options: 128 / 256 / 512
- Chunk-based rendering for larger maps (16x16 or 32x32 chunks)
- Only render/tick visible + nearby chunks
- Pathfinding optimization for larger maps

### 22. Map Secrets
- Sealed ruins: walled chambers with loot + dormant threats
- Frozen colonists: cryopods to thaw (random stats) or harvest
- Frozen-in-ice "colonists": Thing-style mimics that attack when thawed
- Precursor artifacts: alien devices, powerful but risky activation
- Underground caverns: cave systems with rare resources and eldritch sites
- Skinwalker events: entity mimics a colonist, lures others outside to attack

### 23. Stockpile Filtering
- Filter tree: category -> item type -> quality range -> material
- Priority levels: 1 (critical) to 4 (low)
- Higher priority stockpiles pull from lower ones via hauling
- Default stockpile accepts everything at priority 3

### 24. Work Orders (Full Bill System)
- Count targets: "make 10" or "make until 20 in stockpile"
- Material filter: restrict input materials
- Quality minimum: "only accept Good or better"
- Ingredient radius: search range for materials
- Pause/resume conditions
- Bill priority ordering per workstation
- "Do forever" option

### 25. Trade Depth
- Faction rep affects prices (allied = 20% discount, hostile = won't trade)
- Supply/demand: flood market -> price drops, scarcity -> price rises
- Permanent trade routes: establish with allied factions, regular shipments
- Trade route maintenance: requires fuel/resources, can be raided

### 26. Events Expansion
- Social: parties, weddings, funerals, feasts
- Peaceful: wandering trader, art inspiration, aurora borealis, animal self-tame
- Environmental: meteor, earthquake, meltwater surge, toxic fallout, volcanic ash
- Eldritch: strange signals, precursor ruin emergence, anomalous weather, reality tears
- Cult: ritual gatherings, possession events, whisper madness
- Creature: burrowing horrors, lurking predators, hive emergence

### 27. Visitors
- Trade caravans: faction-specific goods, stay 1-2 days
- Refugee groups: may request shelter, chance to join colony
- Diplomats: faction rep quests, alliance offers
- Traveler bands: rest and leave, share intel
- Hostile scouts: case the base, kill to prevent upcoming raid

### 28. Procedural History
- Lore-constrained: fits existing lore bible
- Micro factions: small groups with generated backstories
- Adlib history: past events, conflicts, fallen outposts
- Expedition discoveries reference generated history
- Faction relationships have historical basis

### 29. Colonist Info Panel
- Expanded existing tabs with passion display, opinion breakdown
- New Bio tab: backstory, traits, age, family tree, work restrictions
- New Combat tab: stance, kill count, scars, equipment effectiveness
- New Log tab: personal event history (last 50 events)
- Procedural character portrait: shows equipped gear, wounds, prosthetics

### 30. Alert System
- Priority tiers: critical (red), major (orange), minor (yellow)
- Click-to-zoom: clicking alert jumps camera to source
- Letter system: major events generate letters, stack in corner
- Audio cues: distinct sounds per alert type, alarm for critical
- Alerts persist until resolved

### 31. Thermal Deepening
- Thermal trading: cores as premium currency, faction-specific valuation
- Heat-gated areas: too cold without suits/heated paths, rare resources within
- Heat storage batteries: bank excess heat, buffer against blizzards
- Thermal weapons: thermal lance, cryo grenades, heat-drain turrets
- Craftable thermal gear and thermal cores

### 32. Multiplayer (all optional per MP design doc)
- Shared overworld: multiple colonies, see locations, send expeditions
- Inter-colony raids: PvP with existing raid mechanics
- Cooperative expeditions: joint missions, shared colonist contribution
- Competitive economy: dynamic thermal core market, trade route competition

### 33. Endgame
- Anomaly escalation: drilling/exploring raises anomaly level
- Higher level = stranger events, eldritch creatures, reality distortion
- Precursor artifacts: alien devices with powerful effects + dangerous side effects
- That Which Sleeps: endgame boss tied to anomaly level
  - Current canon: defeating it only opens the Mammona extraction path. Escape and sealing remain separate endings.
  - Defeating it does not win on its own - it clears the anomaly enough to permit the Mammona extraction ending
  - Extraction remains the corporate path, not the default heroic ending
- Colony legacy: fallen colonies become overworld ruins for next playthrough
