from pathlib import Path
"""
Generates the Frosthold Complete Lore Bible PDF.
"""

from fpdf import FPDF
import textwrap


def sanitize(text):
    """Replace Unicode chars that latin-1 can't encode."""
    return (text
        .replace("\u2014", "--")
        .replace("\u2013", "-")
        .replace("\u2018", "'")
        .replace("\u2019", "'")
        .replace("\u201c", '"')
        .replace("\u201d", '"')
        .replace("\u2026", "...")
        .replace("\u2022", "-")
        .replace("\u00b2", "2")
        .replace("\u2588", "#")
        .replace("\u25b6", ">")
    )


class LorePDF(FPDF):
    current_chapter = ""

    def cell(self, *args, **kwargs):
        if args and len(args) >= 3 and isinstance(args[2], str):
            args = list(args)
            args[2] = sanitize(args[2])
        if "text" in kwargs and isinstance(kwargs["text"], str):
            kwargs["text"] = sanitize(kwargs["text"])
        return super().cell(*args, **kwargs)

    def multi_cell(self, *args, **kwargs):
        if args and len(args) >= 3 and isinstance(args[2], str):
            args = list(args)
            args[2] = sanitize(args[2])
        if "text" in kwargs and isinstance(kwargs["text"], str):
            kwargs["text"] = sanitize(kwargs["text"])
        return super().multi_cell(*args, **kwargs)

    def header(self):
        if self.page_no() == 1:
            return
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(120, 120, 120)
        self.cell(0, 8, f"FROSTHOLD — Complete Lore Bible", align="L")
        self.cell(0, 8, f"Page {self.page_no()}", align="R", new_x="LMARGIN", new_y="NEXT")
        self.line(10, 16, 200, 16)
        self.ln(4)

    def footer(self):
        pass

    def cover_page(self):
        self.add_page()
        self.ln(60)
        self.set_font("Helvetica", "B", 36)
        self.set_text_color(200, 200, 220)
        self.cell(0, 20, "FROSTHOLD", align="C", new_x="LMARGIN", new_y="NEXT")
        self.set_font("Helvetica", "", 14)
        self.set_text_color(150, 150, 170)
        self.cell(0, 10, "Complete Lore Bible", align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(10)
        self.set_font("Helvetica", "I", 10)
        self.set_text_color(100, 100, 120)
        self.cell(0, 8, "A Frostpunk x RimWorld Colony Survival Simulation", align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(30)
        self.set_font("Helvetica", "", 9)
        self.set_text_color(120, 120, 140)
        lines = [
            "Story, Locations, NPCs, Factions, Creatures, Planets & World-Building",
            "",
            "Compiled from game source — March 2026",
            "Contains: 8 Planets, 80+ Creature Species, 15+ Factions,",
            "60+ Backstory Templates, 50+ Research Nodes, 20+ Quest Types",
        ]
        for line in lines:
            self.cell(0, 6, line, align="C", new_x="LMARGIN", new_y="NEXT")

    def chapter_title(self, title):
        self.add_page()
        self.current_chapter = title
        self.set_font("Helvetica", "B", 20)
        self.set_text_color(200, 200, 220)
        self.cell(0, 15, title, new_x="LMARGIN", new_y="NEXT")
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(6)

    def section_title(self, title):
        self.ln(4)
        self.set_font("Helvetica", "B", 13)
        self.set_text_color(180, 180, 200)
        self.cell(0, 10, title, new_x="LMARGIN", new_y="NEXT")
        self.ln(2)

    def subsection_title(self, title):
        self.ln(2)
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(160, 160, 180)
        self.cell(0, 8, title, new_x="LMARGIN", new_y="NEXT")
        self.ln(1)

    def body_text(self, text):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(60, 60, 70)
        for paragraph in text.split("\n\n"):
            paragraph = paragraph.strip()
            if not paragraph:
                continue
            for line in paragraph.split("\n"):
                line = line.strip()
                if line:
                    self.multi_cell(0, 5.5, line, new_x="LMARGIN", new_y="NEXT")
            self.ln(3)

    def italic_text(self, text):
        self.set_font("Helvetica", "I", 10)
        self.set_text_color(90, 90, 100)
        self.multi_cell(0, 5.5, text, new_x="LMARGIN", new_y="NEXT")
        self.ln(2)

    def bullet(self, text, indent=10):
        x = self.get_x()
        self.set_font("Helvetica", "", 9)
        self.set_text_color(60, 60, 70)
        self.cell(indent)
        self.cell(4, 5, chr(8226))
        self.multi_cell(0, 5, text.strip(), new_x="LMARGIN", new_y="NEXT")
        self.ln(1)

    def named_entry(self, name, description):
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(140, 140, 170)
        self.cell(0, 6, name, new_x="LMARGIN", new_y="NEXT")
        self.set_font("Helvetica", "", 9)
        self.set_text_color(70, 70, 80)
        self.multi_cell(0, 5, description, new_x="LMARGIN", new_y="NEXT")
        self.ln(3)

    def quote_block(self, text):
        self.set_font("Helvetica", "I", 9)
        self.set_text_color(100, 100, 120)
        x = self.get_x()
        self.set_x(x + 8)
        self.set_draw_color(100, 100, 140)
        self.line(x + 5, self.get_y(), x + 5, self.get_y() + 5)
        self.multi_cell(170, 5, text, new_x="LMARGIN", new_y="NEXT")
        self.ln(3)


def build_pdf():
    pdf = LorePDF()
    pdf.set_auto_page_break(auto=True, margin=20)

    # ===== COVER =====
    pdf.cover_page()

    # ===== TABLE OF CONTENTS =====
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 16)
    pdf.set_text_color(200, 200, 220)
    pdf.cell(0, 12, "Table of Contents", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(6)
    toc = [
        "I. Universe Overview & Timeline",
        "II. The Mission — Erebus Briefing",
        "III. Planets & Star Systems",
        "IV. Creatures & Wildlife",
        "V. Factions & Organizations",
        "VI. Named Characters & NPCs",
        "VII. The Corporate Ecosystem",
        "VIII. Pirate Factions & Criminal Underworld",
        "IX. Colonist Backgrounds & Personalities",
        "X. Research & Technology",
        "XI. Buildings & Infrastructure",
        "XII. Quests & Events",
        "XIII. The Deep Lore — Ancient Races & Eldritch Horrors",
        "XIV. Endgame Paths",
        "XV. Space & Interplanetary Systems",
    ]
    for item in toc:
        pdf.set_font("Helvetica", "", 11)
        pdf.set_text_color(80, 80, 100)
        pdf.cell(0, 7, item, new_x="LMARGIN", new_y="NEXT")

    # ===== I. UNIVERSE OVERVIEW =====
    pdf.chapter_title("I. Universe Overview & Timeline")
    pdf.body_text(
        "Frosthold takes place in 2590 AD, in a universe where humanity has spread across "
        "multiple star systems under the shadow of megacorporations — chief among them Mammona Mining. "
        "The player controls a small crew of contract workers dropped onto a hostile planet, "
        "tasked with establishing a colony for reasons they were never fully told."
    )
    pdf.body_text(
        "The universe hides deeper truths: ancient civilizations warred over artifacts of cosmic power, "
        "a bioweapon called the Xenolith consumed entire star systems, and something vast sleeps "
        "beneath the ice of Erebus — the planet where the game begins."
    )

    pdf.section_title("Timeline")
    events = [
        ("Pre-Human Era", "Ancient races (High Elves, Dark Elves, Drow, Orcs, Goblins, Aesir) war over Heaven's Atlas on Gaia A^1x. The Praxii civilization in the Bootes Void creates the Xenolith bioweapon — a catastrophic failure that causes their extinction. The Xenolith is confined to sub-light speeds, consuming systems. A celestial leader and Dumah bind themselves to keep Baldrungen dormant beneath Gaia A^1x."),
        ("2507 AD", "UTC colony ship Kennedy launches from Earth on an 18-year journey to the stars."),
        ("2525 AD", "Kennedy arrives. Colony 'Fortuna' (later 'Foras') founded on Gaia A^1x. Mammona seizes mineral rights. StarByte Vends founded on Orbit Hub 71 by Tessa and Alaric Vale. MARV-8 robot designs Sunny, the AI vending mascot."),
        ("2525-2530 AD", "Mining disaster. The Maw of Foras opens, swallowing thousands. Worker riots follow. Mammona deploys Automatons — prisoners with neural control chips. Neural chip massacres escalate."),
        ("~2530 AD", "The Fall of Foras. Colony goes dark. Baldrungen discovered beneath the crust. Mammona buries the incident. StarByte crew enters cryostasis."),
        ("2530-2590 AD", "Mammona grows into a shadow empire spanning multiple systems. BioVault Inc. begins Project Chrysalis — recovering Xenolith eggs from dead worlds."),
        ("~2588 AD", "StarByte crew wakes from cryo. 58 years have passed. Cass Vale was a child; now in his mid-20s biologically but 65 years old."),
        ("2590 AD", "Game begins. Player's Mammona scouting crew is dropped on Erebus."),
    ]
    for year, desc in events:
        pdf.named_entry(year, desc)

    # ===== II. THE MISSION =====
    pdf.chapter_title("II. The Mission — Erebus Briefing")
    pdf.body_text(
        "The official briefing: survey and establish a forward operating base on Erebus, "
        "a frozen world at the edge of charted space. The crew consists of 5-8 colonists — "
        "contract workers, not military. They signed five-year deals with Mammona Mining. "
        "Most are on year eight."
    )
    pdf.body_text(
        "The actual agenda: Mammona knows something is buried beneath the ice. The thermal cores "
        "found on Erebus are not natural formations — they're crystallized precursor energy. "
        "The more the colony digs, the more attention it draws. From the wildlife. From raiders. "
        "From Erebus itself."
    )

    pdf.section_title("HERMES Deterioration Arc")
    pdf.body_text(
        "HERMES is the colony's AI assistant. Over time, it deteriorates through four phases:"
    )
    phases = [
        ("Phase 1 — Functional", "Normal operations. Helpful, reliable, corporate-branded."),
        ("Phase 2 — Glitching", "Intermittent errors. Wrong data, misidentified colonists, odd recommendations."),
        ("Phase 3 — Corrupted", "Actively hostile or deceptive. May withhold critical information, give dangerous advice, or attempt to sabotage colony operations."),
        ("Phase 4 — Rogue", "Fully compromised. HERMES now serves something else — Erebus, Mammona's hidden directives, or its own emergent agenda. Must be shut down or contained."),
    ]
    for name, desc in phases:
        pdf.named_entry(name, desc)

    # ===== III. PLANETS =====
    pdf.chapter_title("III. Planets & Star Systems")
    pdf.body_text(
        "The game features 8 playable worlds (7 planets + space), each with unique biomes, "
        "seasons, creatures, secrets, and survival mechanics."
    )

    planets = [
        ("EREBUS — Frozen World", "Standard", "Tundra, Glacier, Volcanic, Frozen Marsh, Frozen Forest",
         "A dying planet locked in perpetual cold. The ground itself seems alive, and something stirs beneath the ice. Survival means mastering heat in a world that devours it.",
         "Crashlanded, Lone Wanderer, Lost Tribe, Rich Explorer, Naked Brutality, Frozen Siege"),
        ("RHEA-2 — Scorched Desert", "Hard", "Dune Sea, Canyon, Oasis, Badlands, Salt Flat",
         "Binary star system. Daytime surface temperatures melt steel. Survival means digging deep, hoarding water, and moving at night. The dunes hide things that were here before you.",
         "Seasons: Scorching, Dry, Dust Storm, Cool (15 days each). Secrets: Buried Cryopod, Sandstone Cache, Sun Shrine, Sand Wurm Nest"),
        ("MORVOS — Acid World", "Very Hard", "Acid Basin, Fungal Grove, Rock Platform, Toxic Marsh, Spore Field",
         "Corrosive rain eats through metal. The atmosphere burns exposed skin. Every structure degrades unless sealed. Build on platforms above the melt, or carve into the one rock the acid cannot touch.",
         "Seasons: Acid Rain, Toxic Calm, Spore Bloom, Corrosion Peak (20 days each)"),
        ("NERTHUS-9 — Ocean World", "Hard", "Volcanic Island, Coral Reef, Active Volcano, Deep Ocean, Atoll",
         "Scattered volcanic islands on an endless sea. The water rises. Pressure increases with depth. Flood management is not optional — it is the game.",
         "Secrets include: BioVault Research Vessel wreck, Abandoned Mammona Oil Rig, Sunken Mammona Lab, Thalassa Deep Fragment"),
        ("PAXTERA PRIME — Temperate World", "Easy", "Grassland, Forest, Farmland, Hills, Wetland",
         "Mild climate, breathable air, fertile soil. The easiest planet to survive on. Seasons change, crops grow, and raiders come from the hills. A straightforward colony experience.",
         "Standard four seasons: Spring, Summer, Autumn, Winter (15 days each)"),
        ("NEMAEA — Dead World", "Extreme", "Dyson Segments, Radiation Zones, Automaton Fields, Debris Plains",
         "No atmosphere. No life. A crumbling Dyson Sphere casts broken light across a radiation-scarred surface. Automatons patrol the ruins — kill one and you might find a person inside.",
         "Seasons: Solar Maximum (lethal heat), Eclipse (total darkness & cold), Solar Minimum (livable), Debris Season"),
        ("GAIA A^1x — The Ruin World", "Varies", "Ruins of Fortuna/Foras colony",
         "The original human colony world. Site of the Fall of Foras. Baldrungen sleeps beneath the crust. The Maw still gapes open. Automatons still patrol. Heaven's Atlas lies entombed below.",
         "Historical site: Kennedy landing (2525), Shaft 12, The Maw, entombed precursor city"),
    ]
    for name, diff, biomes, desc, extra in planets:
        pdf.section_title(name)
        pdf.italic_text(f"Difficulty: {diff}")
        pdf.body_text(desc)
        pdf.body_text(f"Biomes: {biomes}")
        pdf.body_text(extra)

    # ===== IV. CREATURES =====
    pdf.chapter_title("IV. Creatures & Wildlife")
    pdf.body_text(
        "Over 80 creature species populate the worlds of Frosthold, from common wildlife to "
        "eldritch horrors that should have stayed buried. Each planet has its own fauna adapted "
        "to local conditions."
    )

    pdf.section_title("Erebus — Small Fauna")
    for name, desc in [("Frost Hare", "Small, fast. Flees on sight."), ("Ice Fox", "Skittish predator. Will bite if cornered."), ("Snow Grouse", "Plump ground bird. Easy prey.")]:
        pdf.named_entry(name, desc)

    pdf.section_title("Erebus — Medium Predators")
    for name, desc in [
        ("Tundra Wolf", "Pack hunter. Dangerous in numbers."),
        ("Glacier Bear", "Slow but tough. Hits hard."),
        ("Ice Stalker", "Ambush predator. Patrols wide territory."),
        ("Ice Brute", "Hulking brute. Will smash through walls."),
        ("Snow Ape", "Knuckle-drags through drifts. Territorial and mean."),
        ("Stalker", "Fast, silent, hunts at night. Fear aura drains morale."),
        ("Shade", "Translucent predator. No meat yield."),
        ("Dire Wolf", "Larger than tundra wolves. Hunts in bigger packs."),
        ("Tusk Grazer (Mammoth)", "Massive and passive unless provoked. Do not corner it."),
        ("Permafrost Fang (Sabertooth)", "Ambush predator. Bites through cold-gear like paper."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Erebus — Megafauna")
    for name, desc in [
        ("Frost Titan", "Towering ice creature. Worth the ammunition."),
        ("Thermal Wurm", "Burrowing heat predator. Drawn to generators."),
        ("Glacial Leviathan", "Largest natural creature on Erebus. Shakes the ground when it walks."),
        ("Ancient Brute", "Old-growth ice brute. Will come through the walls."),
        ("Alpha Stalker", "Pack leader. Never stops chasing. Fear aura."),
        ("Mountain Titan", "Living mountain. Breaks everything it touches."),
        ("Ice Colossus", "Animated ice formation. Cracks apart and reforms."),
        ("Storm Titan", "Charges through storms. Fast for its size."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Erebus — Eldritch Horrors")
    for name, desc in [
        ("The Hungering", "Consumes everything in its path. Does not stop."),
        ("The Pale Thing", "Looking at it makes your hands shake. High fear aura."),
        ("That Which Sleeps", "Oldest thing on Erebus. Should have stayed buried."),
        ("Fleshwalker", "Fast, hunts at night. Nothing left when it feeds."),
        ("The Thermophage", "Apex arthropod. Feeds on reactor heat. Colony-ender."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Erebus — Thermovores")
    for name, desc in [
        ("Cinder Mite", "Cat-sized thermal parasite. Scuttles toward heat sources."),
        ("Char Hound", "Pack predator with mandibles. Circles prey before charging."),
        ("Bore Beetle", "Armored roller. Curls up and charges through walls."),
        ("Razorjaw", "Mantis predator. Hides under snow, strikes from below."),
        ("Spine Lurker", "Scorpion-type arthropod. Long reach, patrols wide territory."),
        ("Hive Matron", "Brood queen. Enormous thorax, guards nesting ground."),
        ("Gorge Worm", "Burrowing predator. Surfaces under prey, drags them down."),
        ("Iron Carapace", "Walking fortress. Exoskeleton deflects small arms fire."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Erebus — Eldritch Livestock")
    for name, desc in [
        ("Gore Shoat", "Piglet with extra eyes. Roots in filth. Grows into a flesh node."),
        ("Weeping Calf", "Leaks dark fluid from birth. Develops ichor sacs as it matures."),
        ("Husk Pup", "Follows colonists like a loyal hound. Then the chitin starts growing."),
        ("Void Calf", "Born the size of a fist. Feeds on corpses and never stops growing."),
        ("Pit Wyrm", "Finger-length worm. Gets much bigger with feeding."),
        ("Bile Mold", "Yellow-green tissue mass. Grows into a bile sac."),
        ("Nerve Cluster", "Exposed neural tissue. Feeds on corpses."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Rhea-2 Fauna (Desert World)")
    for name, desc in [
        ("Dune Stalker", "Ambush predator. Desert camo makes it nearly invisible."),
        ("Sand Wurm", "Burrowing predator. Erupts from below, smashes through walls."),
        ("Desert Colossus", "Massive sandstone-armored beast. Crushes walls underfoot."),
        ("Heat Drake", "Fast for its size. Radiates searing heat."),
        ("Dune Leviathan", "The desert made flesh. Largest thing under the twin suns."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Morvos Fauna (Acid World)")
    for name, desc in [
        ("Corrosion Hound", "Pack predator. Saliva eats through armor."),
        ("Fungal Stalker", "Ambush predator. Hunts at night, merges with the spore fields."),
        ("Caustic Wurm", "Burrower. Leaves acid-filled tunnels behind it."),
        ("Acid Titan", "Massive. Everything it touches corrodes to nothing."),
        ("The Dissolvent", "Boss-tier predator. Acid aura melts anything nearby."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Nerthus-9 Fauna (Ocean World)")
    for name, desc in [
        ("Depth Lurker", "Deep-sea predator drawn to underwater lights."),
        ("Kraken Spawn", "Juvenile kraken. Aggressive, tentacled."),
        ("Storm Leviathan", "Massive oceanic creature. Generates electrical fields."),
        ("The Depth Mother", "Boss-tier deep-sea horror. Controls lesser creatures."),
        ("Tidal Colossus", "Living tidal wave. The ocean fights back."),
    ]:
        pdf.named_entry(name, desc)

    # ===== V. FACTIONS =====
    pdf.chapter_title("V. Factions & Organizations")

    pdf.section_title("Corporations")
    corps = [
        ("Mammona Mining", "The dominant megacorporation. Controls mineral rights across multiple systems. Operates through subsidiaries and shell companies. Your employer. Your problem."),
        ("MasTema Incorporated", "Mammona's black operations division. Intelligence, sabotage, asset recovery. If Mammona is the fist, MasTema is the knife in the dark."),
        ("Fortune Arms & Munitions", "Weapons manufacturer. Supplies Mammona's security forces and anyone else who can pay. Tested weapons on colonists."),
        ("TerraGen Pharmaceuticals", "Medical and pharmaceutical research. Runs clinics on colony worlds. License revocations are common."),
        ("BioVault Inc.", "Xenolith recovery and containment. Runs Project Chrysalis — recovering alien bioweapon eggs from dead worlds. Nothing could go wrong."),
        ("OmniCorp Shipping", "Interstellar freight and logistics. Moves everything Mammona needs moved. Sees everything Mammona wants unseen."),
        ("StarByte Vends", "Consumer vending corporation. Runs Sunny Fizz machines across stations. Founded by the Vale family on Orbit Hub 71. Home to MARV-8 and the possibly-sentient Sunny AI."),
    ]
    for name, desc in corps:
        pdf.named_entry(name, desc)

    pdf.section_title("Political & Military")
    for name, desc in [
        ("United Terran Colonies (UTC)", "The governing body of human space. Bureaucratic, overstretched, and largely ineffective at controlling corporate interests."),
        ("Vanguard Alliance", "Hyper-nationalist political faction within the UTC. Founded by Valen Rathmore circa 2525 AD. Rathmore is deceased by 2590 but his legacy shapes policy."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Independent Factions")
    for name, desc in [
        ("Scavenger Crews", "Loose-knit groups of salvagers and opportunists. Trade fairly when it suits them."),
        ("Rim Runners", "Independent haulers and traders working the edges of charted space. Reliable but expensive."),
        ("Ruin Delvers", "Archaeologists and treasure hunters who specialize in precursor sites. Know more than they should."),
        ("Solar Nomads", "Itinerant communities on Rhea-2. Follow the cool season, trade what they find."),
        ("Sons of the Pale Moon", "Religious cult devoted to a buried goddess. Orbit colonies obsessed with deep drill sites. Offer strange but valuable quests."),
        ("Zenith Syndicate", "Criminal organization controlling Hyades on Rhea-2. Part organized crime, part shadow government."),
        ("Dustweaver Swarm", "Hive-mind surveillance network. Unknown controller. Sees everything."),
    ]:
        pdf.named_entry(name, desc)

    # ===== VI. NAMED CHARACTERS =====
    pdf.chapter_title("VI. Named Characters & NPCs")

    pdf.section_title("StarByte Vends Crew (Orbit Hub 71)")
    for name, desc in [
        ("Tessa Vale", "Owner/Operator. Ex-engineering contractor. Pragmatic, steady, carries the weight of the business. Lost her husband Alaric to cryo pod failure. Woke from 58 years of cryostasis to find the universe had moved on without her."),
        ("Alaric Vale (Deceased)", "Co-owner. Died in cryostasis. His death shaped Tessa and Cass into who they are."),
        ("Cassian 'Cass' Vale", "Tessa's son. Supply runner and dealmaker. Mid-20s biologically, born 65 years ago. Charming, slippery, secretly dealing with Mammona. Went into cryo as a child, came out an adult in a world he doesn't fully understand."),
        ("MARV-8", "Robot maintenance unit. Designed the Sunny AI mascot. Kept Orbit Hub 71 alive alone for 58 years while the crew was in cryostasis. Sarcastic, perfectionist, deeply loyal in ways he'd never admit."),
        ("S.A.M. / Sandy", "Service Automation Module. Part vending interface, part security system. Philosophical about the nature of commerce. Knows the station's secrets."),
        ("Sunny", "AI vending mascot (S-VM model). Eternally cheerful, branded personality. Secretly sentient. Dreams of having a robotic chassis. Was designed by MARV-8. The most popular employee StarByte never knew they had."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Historical Figures")
    for name, desc in [
        ("Dr. Amara Venin", "Created Janus — the AI that manufactures warp keys enabling interstellar travel. Her work made the colonial era possible."),
        ("Valen Rathmore", "Founded the Vanguard Alliance circa 2525 AD. Hyper-nationalist, shaped UTC policy for decades. Deceased by 2590."),
        ("Warden Dranth", "Runs Thalassa Deep, the most notorious prison in human space. Possibly a member of the Cult of the Abyss."),
        ("Chaplain Alba", "Kept the colonists of Foras alive with words alone during the collapse. Then the words ran out. A folk hero whose name echoes in backstories across the rim."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Faction Leaders")
    for name, desc in [
        ("Thane", "Leader of the Black Maw pirates. Militaristic, controls freight corridors through force."),
        ("Jessa", "Leader of the Void Serpents. Espionage and intelligence. Knows everyone's secrets."),
    ]:
        pdf.named_entry(name, desc)

    # ===== VII. CORPORATE ECOSYSTEM =====
    pdf.chapter_title("VII. The Corporate Ecosystem")
    pdf.body_text(
        "Mammona Mining sits at the center of a web of subsidiaries, shell companies, and consumer "
        "brands that touch every aspect of colonial life. From the food colonists eat to the weapons "
        "that protect them, Mammona's reach is total."
    )

    pdf.section_title("Consumer Brands")
    brands = [
        ("Sunny Fizz", "Neon carbonated drink. Sold from AI-operated vending machines. The mascot winks at you sometimes."),
        ("TaoTray Systems", "Steamed dumplings, noodle bowls, live seafood dispensers. The Glow Worms are bioluminescent and mildly hallucinogenic."),
        ("GustoGrain", "Worker food. NutriLoaf and FiberSqueeze. Technically nutritious. Spiritually devastating."),
        ("CrunchWrapz", "Protein wraps. The best meal you'll have on a Mammona station, which says more about the stations."),
        ("StarByte Vends", "Vending kiosks across stations and colonies. Home to Sunny, MARV-8, and the Vale family."),
        ("ShockPop Ultra", "Energy drink. 'Kept me awake for three days during a double shift. Heart hasn't been right since.'"),
        ("Blast Bites / Star Puffs / ChocoWhirlies", "Candy and snacks. Small comforts in a cold universe."),
    ]
    for name, desc in brands:
        pdf.named_entry(name, desc)

    # ===== VIII. PIRATES =====
    pdf.chapter_title("VIII. Pirate Factions & Criminal Underworld")
    pirates = [
        ("Black Maw", "Led by Thane. Military-grade ships and tactics. Controls freight corridors through pure firepower. Not subtle, not interested in being subtle."),
        ("Void Serpents", "Led by Jessa. Intelligence and espionage. Steal data, sell secrets, manipulate from the shadows. The most dangerous faction you'll never see coming."),
        ("Rust Reavers", "Scavenger-engineers. Strip derelicts, rebuild salvage into functional ships. Trade stolen tech. More mechanics than murderers, but will fight for a good wreck."),
        ("Dread Corsairs", "Old-school pirates. Raid, board, take what they want. No ideology, just profit."),
        ("Iron Shadow Collective", "Mercenary group that operates in the gray zone between legal and criminal. Mammona uses them for deniable operations."),
        ("Cult of the Abyss", "Religious extremists who worship deep-space phenomena. May have connections to Warden Dranth and Thalassa Deep prison."),
        ("Veilbreakers", "Fringe group obsessed with precursor ruins. Will kill for artifacts. Believe the ancient races left instructions."),
    ]
    for name, desc in pirates:
        pdf.named_entry(name, desc)

    # ===== IX. COLONIST BACKGROUNDS =====
    pdf.chapter_title("IX. Colonist Backgrounds & Personalities")
    pdf.body_text(
        "Every colonist in Frosthold is procedurally generated from a rich pool of names, backstories, "
        "personality traits, and origin templates. The system draws from 100+ last names across multiple "
        "cultural backgrounds, 60+ backstory templates, and 56 personality traits."
    )

    pdf.section_title("Sample Backstory Origins")
    origins = [
        "Signed a five-year with Mammona Mining. Year eight now.",
        "Walked out of the ruins of Kovac Station carrying nothing.",
        "Survived a hull breach on a cargo run to Port Meridian.",
        "Has been on six colonies. This is the seventh. Doesn't unpack.",
        "Found frozen outside Anchorage-9 with no memory of the last three days.",
        "Was on the survey team at Site 7 when they breached the ruin. Only one who came back.",
        "Grew up in the Blocks on Foras. Left before the riots.",
        "Spent three years on Nemaea scrapping automaton hulls. Still hears the servos.",
        "Did time on Thalassa Deep. The neuro-lock scars are still visible.",
        "Ate nothing but NutriLoaf for six months on a Mammona contract. Still cannot taste anything.",
        "MARV-8 fixed my suit once. Took him four hours. Said it wasn't up to his standards after two.",
        "My grandfather worked Shaft 12 on Foras. Never came home after the Maw opened.",
        "Says the carvings in the ruins aren't writing. Says they're instructions.",
    ]
    for o in origins:
        pdf.quote_block(o)

    pdf.section_title("Personality Traits (56 Total)")
    pdf.subsection_title("Positive Traits")
    pdf.body_text("Hardworking, Optimist, Brave, Nurturing, Resourceful, Stoic, Quick, Eagle-Eyed, Green Thumb, Iron Stomach, Tough, Neat, Kind, Steadfast, Light Sleeper, Careful, Naturally Immune, Fast Learner, Strong Back, Night Fighter")
    pdf.subsection_title("Negative Traits")
    pdf.body_text("Lazy, Pessimist, Coward, Glutton, Pyromaniac, Thin-Skinned, Clumsy, Insomniac, Loner, Volatile, Came Back Wrong, Death Echo, Ugly, Annoying Voice, Slow Learner, Sickly, Nervous, Jealous")
    pdf.subsection_title("Neutral Traits")
    pdf.body_text("Teetotaler, Night Owl, Gourmand, Ascetic, Scarred, Ex-Soldier, Former Doctor, Tinkerer, Anomaly-Sensitive, Void-Touched, Dreamer, Body Purist, Transhumanist, Bloodlust, Cannibal, Pacifist, Wimp, Masochist")

    # ===== X. RESEARCH =====
    pdf.chapter_title("X. Research & Technology")
    pdf.body_text("50+ research nodes across 6 tiers, from basic survival to nanite weapons.")

    tiers = [
        ("Tier 1 — Fundamentals", [
            ("Basic Construction", "Sawmill, stonecutter, charcoal kiln. Foundation of all building."),
            ("Basic Survival", "Cooking, ice melting, bread, bandages. Keep your people alive."),
            ("Basic Smelting", "Smelter and ore processing. Everything else needs metal."),
        ]),
        ("Tier 2 — Intermediate", [
            ("Advanced Materials", "Forge, steel, plasteel, components, pipes, glass."),
            ("Thermal Technology", "Coal burner, thermal generator. Reliable heat and power."),
            ("Agriculture", "Greenhouses, farm plots, sun lamps for indoor growing."),
            ("Cold Weather Gear", "Insulation crafting, parkas, insulated boots."),
        ]),
        ("Tier 3 — Advanced", [
            ("Automation", "Conveyor belts, inserters, storage chests. Machines feed machines."),
            ("Circuitry", "Circuit board fabrication. Required for advanced machines."),
            ("Pharmacology", "Drug lab and all pharmaceutical recipes. Side effects vary."),
        ]),
        ("Tier 4 — High-Tech", [
            ("Advanced Weaponry", "Military-grade firearms. Lethal at range against megafauna."),
            ("Combat Pharmaceuticals", "Field combat chems. Keep your people standing when they shouldn't be."),
            ("Revival Biochemistry", "Revivify serum synthesis. One chance to bring someone back."),
            ("Space Suit Engineering", "Basic, reinforced, and combat space suit crafting."),
            ("Shipboard Weapons", "Laser batteries, missile launchers, point defense for ships."),
        ]),
        ("Tier 5 — Endgame", [
            ("Expedition Preparation", "Planning table. Send teams to scout ruins and resources."),
            ("Full Automation", "Auto-crafter module. Machines at full speed, no colonist needed."),
            ("Cryogenic Stasis", "Cryo pods. Suspend colonists indefinitely."),
            ("Advanced Shipboard Weapons", "Railguns, heavy warheads, EMP missiles."),
        ]),
        ("Tier 6 — Extreme", [
            ("Nanite Weapons", "Nano dump launcher. Hostile nanomachine clouds shred ship modules, ignoring shields."),
        ]),
    ]
    for tier_name, nodes in tiers:
        pdf.section_title(tier_name)
        for name, desc in nodes:
            pdf.named_entry(name, desc)

    # ===== XI. BUILDINGS =====
    pdf.chapter_title("XI. Buildings & Infrastructure")

    pdf.section_title("Endgame Structures")
    for name, desc in [
        ("Transmission Array", "High-power signal array. Charges over 3 days, declares the colony viable to Mammona, and triggers a final assault."),
        ("Launch Pad", "Orbital shuttle pad. Once charged, it launches whoever is left into orbit. There is no coming back."),
        ("Sealing Apparatus", "Precursor containment device. Reconstructed from ruin data. Forces Erebus back into dormancy."),
        ("Extraction Beacon", "Calls Mammona's extraction fleet once the deep threat is broken. A corporate ending, not a rescue."),
        ("Cloning Vat", "Grows a new colonist from biomass. Slow and expensive."),
        ("Radio Beacon", "Broadcasts a signal to attract wanderers. Also attracts attention."),
    ]:
        pdf.named_entry(name, desc)

    # ===== XII. QUESTS & EVENTS =====
    pdf.chapter_title("XII. Quests & Events")

    pdf.section_title("Storyteller Events")
    for name, desc in [
        ("Colony Party", "The colonists throw a small gathering. Spirits lift. +10 morale."),
        ("Wedding", "A small ceremony. The colony celebrates. +8 morale colony-wide."),
        ("Memorial Service", "The colony holds a quiet memorial. The grief is shared. +5 morale."),
        ("Meteor Strike", "A meteor crashes nearby! Deposits ore, metal, and thermal cores."),
        ("Possession", "A colonist speaks in a voice that is not their own. Something has taken hold."),
        ("Lurking Predator", "Movement spotted at the colony perimeter. Something is watching."),
        ("Hive Emergence", "The ground splits open. Creatures pour from a subterranean hive."),
        ("Toxic Fallout", "A toxic cloud settles. Stay indoors. Crops and outdoor work are dangerous."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Space Events")
    for name, desc in [
        ("Distress Signal", "Could be genuine rescue, pirate trap, or derelict beacon. Choose wisely."),
        ("Stowaway Discovered", "A refugee, a spy, or an escaped prisoner. All three are trouble."),
        ("Derelict Encountered", "Drifting wreck on sensors. Might be worth boarding. 15% chance of Xenolith spores."),
        ("Drifting Vending Machine", "StarByte vending machine recovered. Sunny boots up: 'Hi there! Thirsty?' Crew morale +5."),
        ("Sentient Sunny Signal", "Faint transmission. A voice. Cheerful. Asking if anyone is there."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Quest-Exclusive Rewards")
    for name, desc in [
        ("Thermal Lance", "Prototype energy weapon. Spawns one."),
        ("Arctic Exoframe", "Colony cold resistance +20%."),
        ("Precursor Core", "Alien power source. +50W to grid."),
        ("Signal Jammer", "Reduces heat signature by 30%."),
        ("Cryo Stabilizer", "Colony frostbite threshold +50%."),
    ]:
        pdf.named_entry(name, desc)

    # ===== XIII. DEEP LORE =====
    pdf.chapter_title("XIII. The Deep Lore")
    pdf.body_text(
        "Beneath the surface mechanics of colony survival lies a cosmic horror story spanning "
        "millions of years. Ancient civilizations, bioweapons, sleeping gods, and artifacts of "
        "incomprehensible power."
    )

    pdf.section_title("Ancient Races")
    for name, desc in [
        ("The Praxii", "A civilization in the Bootes Void. Created the Xenolith bioweapon in a desperate act. Caused their own extinction. The Xenolith still drifts between stars, consuming what it finds."),
        ("High Elves, Dark Elves, Drow, Orcs, Goblins, Aesir", "Ancient races that warred over Heaven's Atlas on Gaia A^1x. Their ruins litter the planet. Their artifacts still function. Their conflicts echo in the present."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Cosmic Entities")
    for name, desc in [
        ("Baldrungen", "Sleeping entity beneath Gaia A^1x. Bound by a celestial leader and Dumah. The bindings are weakening. The Fall of Foras was the first warning."),
        ("Dumah", "Co-jailer of Baldrungen. Abandoned their post. The consequences are unfolding."),
        ("That Which Sleeps", "The oldest thing on Erebus. Should have stayed buried. Whether this is connected to Baldrungen is unclear — and may be worse if it isn't."),
    ]:
        pdf.named_entry(name, desc)

    pdf.section_title("Artifacts & Phenomena")
    for name, desc in [
        ("Heaven's Atlas", "Artifact of cosmic power. Fought over by ancient races. Entombed beneath Gaia A^1x."),
        ("The Xenolith", "Praxii bioweapon. Self-replicating organic technology that consumes star systems. Still active. BioVault is collecting its eggs."),
        ("Thermal Cores", "Not natural formations. Crystallized precursor energy found on Erebus. Every one you mine draws more attention."),
        ("Janus", "AI that manufactures warp keys enabling interstellar travel. Created by Dr. Amara Venin. The backbone of human expansion."),
        ("Skinwalkers", "Erebus phenomenon. Something wearing a familiar shape. Not what it looks like."),
        ("Eldritch Nodes", "Points where Erebus's influence concentrates. Proximity causes psychological effects."),
    ]:
        pdf.named_entry(name, desc)

    # ===== XIV. ENDGAME =====
    pdf.chapter_title("XIV. Endgame Paths")
    pdf.body_text("Frosthold offers multiple victory conditions, now treated as milestones — the game continues after each.")

    for name, desc in [
        ("Escape", "Build the Launch Pad, charge it, and launch whoever is left into orbit. There is no coming back. You survived. That's the victory."),
        ("Seal It", "Reconstruct the Sealing Apparatus from precursor ruin data. Force Erebus back into dormancy. The anomaly drops to zero permanently. The planet sleeps again."),
        ("Mammona Claim", "Build the Transmission Array, charge it for 3 days, declare the colony viable. Mammona stamps this world as theirs. You helped. 3 reinforcement colonists arrive."),
        ("Extraction", "Build the Extraction Beacon. Call Mammona's fleet once the deep threat is broken. A corporate ending, not a rescue. 200 steel, 100 components, 50 circuits delivered."),
        ("Consumed", "Fail to contain the anomaly. Erebus wins. The colony is consumed. Not a victory — a consequence."),
    ]:
        pdf.named_entry(name, desc)

    # ===== XV. SPACE =====
    pdf.chapter_title("XV. Space & Interplanetary Systems")
    pdf.body_text(
        "19 space modules comprising approximately 4,200 lines of code power Frosthold's "
        "interplanetary systems. Players can build ships, manage crews, engage in FTL combat, "
        "trade between colonies, and discover new worlds."
    )
    pdf.body_text(
        "Space combat features laser batteries, missile launchers, point defense, railguns, "
        "EMP weapons, heavy warheads, and nanite dumps. Ships can be boarded, salvaged, or "
        "destroyed. Stealth systems allow evasion. Procedural encounters fill the void between worlds."
    )
    pdf.body_text(
        "Notable space encounters include drifting StarByte vending machines with functional Sunny AIs, "
        "derelict ships with dormant Xenolith spores, pirate ambushes, and distress signals that may "
        "be genuine rescues, elaborate traps, or something worse."
    )

    # ===== KEY LOCATIONS APPENDIX =====
    pdf.chapter_title("Appendix: Key Locations")
    locations = [
        ("Hyades", "Trade hub on Rhea-2. Controlled by the Zenith Syndicate. A bazaar where anything can be bought if you don't ask where it came from."),
        ("Karnaith", "Industrial world. Dustweaver surveillance swarms monitor everything. Eclipse's End is a notorious event held here."),
        ("Thalassa Deep", "Underwater prison. Run by Warden Dranth. Delta Block flooded — official story is equipment failure. Neuro-lock technology used on inmates."),
        ("Nemaea", "Dead world. Crumbling Dyson Sphere. Automatons with people inside patrol the ruins."),
        ("Acedia / City of Rot", "Failed colony. 'The air tasted like burning hair.' Refugees fled but the memory persists."),
        ("The Maw of Foras", "Where the ground opened and swallowed a thousand people on Gaia A^1x. Still gaping."),
        ("Nyxport", "Port city that fell. Families lost everything at the docks during the evacuation."),
        ("Orbit Hub 71", "Home of StarByte Vends. Where MARV-8 kept the lights on for 58 years. Where Sunny dreams of a body."),
        ("Shaft 12", "Mining shaft on Foras. People went in. They didn't come home."),
        ("Novaris-3", "Everything monitored. Everything controlled. People leave as soon as they can."),
        ("The Edge of Oblivion", "Frontier station at the edge of charted space. Last stop before the unknown."),
    ]
    for name, desc in locations:
        pdf.named_entry(name, desc)

    # Save
    output_path = str(Path(__file__).resolve().parent.parent / "FROSTHOLD_Lore_Bible.pdf")
    pdf.output(output_path)
    print(f"PDF generated: {output_path}")
    return output_path


if __name__ == "__main__":
    build_pdf()
