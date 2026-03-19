"""
Frosthold Procedural Generator v3 -- Prose & Tone Pools
All sensory details, dialogue fragments, backstory templates, and tone machinery.

Source of truth: lore/LORE_BIBLE.md
Tone: The Thing, Dead Space, Aliens, Blade Runner, Annihilation. Corporate dystopia.
      Lovecraftian cosmic horror. Grim, textured, literary.
All text uses natural contractions. No AI slop.
"""

import random

R = random.choice
RS = random.sample
RI = random.randint


# ============================================================
# TONE SYSTEM — 45 tones in 5 families
# ============================================================

TONE_FAMILIES = {
    "horror": [
        "dread", "slow_dread", "sudden_dread", "cosmic_horror", "body_horror",
        "quiet_terror", "survival_horror", "folk_horror", "psychic_contamination",
        "the_uncanny", "wrongness",
    ],
    "emotional": [
        "melancholy", "grief", "tender", "mania", "dissociation",
        "nostalgia", "guilt", "shame", "hollow_joy", "bitter_hope",
    ],
    "psychological": [
        "paranoid", "isolation", "claustrophobia", "agoraphobia",
        "identity_erosion", "gaslighting", "obsession", "sleep_deprivation",
        "hypervigilance",
    ],
    "genre": [
        "noir", "military", "religious_fervor", "cult_devotion",
        "corporate_dystopia", "frontier_grit", "gallows_humor", "clinical",
    ],
    "state": [
        "desperate", "numb", "resigned", "furious", "defiant",
        "manic_energy", "exhaustion",
    ],
}

TONES = [t for family in TONE_FAMILIES.values() for t in family]


# ============================================================
# SENSORY DETAILS — 270+ total, 6+ per tone
# ============================================================

SENSORY = {
    # ---- HORROR family ----
    "dread": [
        "The air tasted like copper and ozone.",
        "Something scraped against the hull. Rhythmic. Patient.",
        "The temperature dropped four degrees in the time it took to blink.",
        "A smell like burned hair drifted from the vent.",
        "The lights flickered in a pattern that looked intentional.",
        "Frost formed on the inside of the window. In the shape of a hand.",
        "The silence had weight. Like the air before a scream.",
        "Something clicked in the wall. Not mechanical. Biological.",
        "The corridor ahead was dark in a way that resisted the flashlight.",
        "A sound from below. Not drilling. Chewing.",
    ],
    "slow_dread": [
        "The stain on the ceiling had grown. Not much. Enough.",
        "Each morning the corridor was a little narrower. Nobody measured. Everyone felt it.",
        "The rust on the railing hadn't been there last week. Now it was everywhere.",
        "They'd been hearing the hum for three weeks before anyone admitted it.",
        "The cracks in the floor were spreading. Following the same pattern as the ruins.",
        "Water damage on the wall was forming shapes. More shapes every day.",
        "The temperature in Section C dropped half a degree each night. Fourteen nights running.",
        "The mold kept coming back in the same spot. They'd bleached it six times.",
    ],
    "sudden_dread": [
        "The lights cut. When they came back, someone was standing in the corridor who hadn't been there.",
        "A handprint appeared on the fogged viewport. From the outside.",
        "The drill punched through into nothing. The bit fell. They never heard it land.",
        "Every radio in the colony spoke the same word at the same time.",
        "The floor gave way under their left foot. Below it: warmth. Movement.",
        "The alarm blared once. One tone. Then silence. The system showed no record of it.",
    ],
    "cosmic_horror": [
        "The geometry of the room was wrong. Not broken. Wrong. Angles that existed but shouldn't.",
        "Looking at it too long caused nosebleeds. Not looking at it was worse.",
        "It wasn't big. That was the terrifying part. Something that powerful should be big.",
        "The stars outside the viewport had rearranged. Nobody mentioned it.",
        "Time moved differently near the artifact. Clocks disagreed. Memories skipped.",
        "The walls were breathing. Not metaphorically.",
        "The horizon bent the wrong way. Like the planet was concave.",
        "Distance stopped working near the site. Twenty meters felt like two. Or two hundred.",
    ],
    "body_horror": [
        "The growth had spread to the second joint. It was warm. It pulsed.",
        "Their teeth had changed. Not fallen out. Changed. Into something else.",
        "Under the skin, something moved. Small. Deliberate. Mapping.",
        "The wound healed too fast. What grew back wasn't the same tissue.",
        "They found fingernails embedded in the wall. From the inside.",
        "The test results came back human. But the proportions were wrong.",
        "The rash had symmetry. Bilateral. Like a design being printed on skin.",
        "Their joints bent a degree further than yesterday. Nobody mentioned it.",
    ],
    "quiet_terror": [
        "Nothing happened. That was the problem. Nothing had happened for too long.",
        "The room was empty. It felt full.",
        "Every door in the corridor was open. They should have been locked.",
        "The footprints led to the wall. Not through it. To it. And stopped.",
        "The voice on the intercom was calm. Perfectly calm. That's how they knew.",
        "The colony's dog sat at the airlock and stared. For nine hours.",
        "No one was in the kitchen. The kettle was boiling.",
    ],
    "survival_horror": [
        "Two medkits for seventeen people. The math was simple. The choices weren't.",
        "The barricade wouldn't hold. They knew it. They reinforced it anyway.",
        "Something was in the vent. They could hear it breathing. They had to walk under it.",
        "The generator had eight hours of fuel. Sunrise was eleven hours away.",
        "She counted the ammunition. Then counted it again. The number hadn't changed. She'd hoped.",
        "The safe room had one exit. The thing outside had patience.",
    ],
    "folk_horror": [
        "They'd arranged the bones in a circle. Twenty meters across. Recent.",
        "The singing came from the bore shaft at midnight. Three voices. Nobody was down there.",
        "Someone had carved the colony's name into the precursor stone. In script that predated human writing.",
        "The offerings at the thermal vent were fresh. Meat. Still warm.",
        "A procession of footprints in the snow, barefoot, leading into the waste. Twelve sets. All the same size.",
        "The ritual markings on the door matched the ones in the ruins exactly. Nobody had been to the ruins.",
    ],
    "psychic_contamination": [
        "She remembered a room she'd never entered. Mahogany shelves. A window facing a sea that didn't exist.",
        "The word surfaced unbidden. Wasn't English. Wasn't any language he knew. He could feel what it meant.",
        "Three colonists drew the same symbol. Different shifts. Different sections. None had met.",
        "He woke knowing how to read the carvings. By noon, he'd forgotten his daughter's name.",
        "A memory of drowning. Vivid. Complete. She'd never been near deep water.",
        "The dreams were sequential now. Each night picked up where the last one ended.",
    ],
    "the_uncanny": [
        "The new transfer smiled. Too wide. The muscles in their face didn't quite coordinate.",
        "The recording played back their voice. The words were right. The cadence was someone else's.",
        "The food tasted exactly like the food from home. Exactly. Down to a spice that shouldn't exist here.",
        "They walked past their own reflection. It was a half-second slow.",
        "The letter from their mother used a nickname she'd never used. Everything else was perfect.",
        "The corridor looked normal. Felt wrong. Like a set built from a description.",
    ],
    "wrongness": [
        "The compass pointed down.",
        "Water in the pipes was flowing uphill. Maintenance confirmed it. Couldn't explain it.",
        "The clock read 25:17. It stayed there for an hour that felt like three.",
        "The echo came before the sound.",
        "Two colonists arrived on the same shuttle. The manifest listed one.",
        "Snow fell upward near the bore shaft for eleven minutes. Then stopped.",
        "The shadow had too many fingers.",
    ],

    # ---- EMOTIONAL family ----
    "melancholy": [
        "Rain hit the viewport in slow, fat drops. It shouldn't rain here.",
        "Someone left a mug on the console. The coffee was still warm.",
        "A photograph was taped to the wall. A beach, a child, sunlight. Another life.",
        "The generator hummed a note that sounded like a lullaby.",
        "Dust motes drifted in the emergency lighting like tiny lost things.",
        "A birthday card sat on a bunk. Unsigned. The envelope was sealed.",
        "The echo in the empty mess hall made one voice sound like two.",
        "Snow fell through a breach in the ceiling. Nobody fixed it. It was beautiful.",
    ],
    "grief": [
        "Her bunk was still made. Nobody touched it. Nobody would.",
        "His name came up on the duty roster three weeks after they buried him.",
        "The weight of an empty chair at the table. Everyone noticed. No one moved it.",
        "She kept his jacket zipped to the collar on the hook. It still smelled like him.",
        "They found a half-finished letter in her pocket. The last sentence trailed off mid-word.",
        "Someone set a place for him at dinner. Force of habit. Nobody corrected it.",
    ],
    "tender": [
        "She left a chocolate ration on his bunk. No note. None needed.",
        "Their hands touched reaching for the same wrench. Neither pulled away.",
        "He hummed while he worked. The same song, every shift. It made the silence bearable.",
        "A flower had grown through a crack in the hydroponics bay. Nobody reported it.",
        "They sat watching the aurora through the viewport. For five minutes, nothing was wrong.",
        "She cut his hair in the utility room after lights out. Neither of them spoke. It was the closest thing to home.",
        "He left his gloves for her shift. She left hers for his. Neither acknowledged it.",
    ],
    "mania": [
        "She hadn't slept in four days and the ideas wouldn't stop. Pages of diagrams. Brilliant. Illegible.",
        "He was laughing and talking and fixing three things at once. His hands shook. He didn't notice.",
        "Everything was bright and fast and perfect and she couldn't slow down and didn't want to.",
        "The sentences got shorter. The pace got faster. The eyes got wider.",
        "He reorganized the entire supply cache in one night. Alphabetically. Then by color. Then by weight.",
        "She said she'd figured it out. All of it. Everything made sense now. Her nose was bleeding.",
    ],
    "dissociation": [
        "She watched her hands work the controls. They knew what to do. She was somewhere else.",
        "The shift ended. Eight hours gone. He couldn't name a single thing he'd done.",
        "Sounds came from very far away. Her own voice was the farthest.",
        "He looked at his reflection and couldn't connect it to himself. A stranger wearing his face.",
        "The pain was there. She knew it was there. It belonged to someone else.",
        "Everything had the quality of a dream. Not a nightmare. Just not real.",
    ],
    "nostalgia": [
        "The smell of machine oil reminded her of her father's garage on a Sunday morning.",
        "Someone was cooking rice. For a moment, he was twelve years old on Novaris-3.",
        "The static on the radio sounded like the ocean. He hadn't heard the ocean in nine years.",
        "She found a Sunny Fizz can and remembered the vendor outside the school on Rhea-2. The heat. The dust.",
        "The cold reminded him of something. Not Erebus cold. Mountain cold. Clean. A lifetime ago.",
        "They played cards with a deck from the supply drop. Same brand as the ones on the Kennedy.",
    ],
    "guilt": [
        "She could've warned them. The words were there. She swallowed them.",
        "Every time the roster came up short, he counted the names he'd signed off on.",
        "The medic's hands were steady. They'd be steadier if she hadn't hesitated that day in Section B.",
        "He ate his ration and tasted the one he'd taken from the dead man's pocket.",
        "The report was clean. She'd made it clean. That was the problem.",
        "He dreamed of the door he'd locked. The sound of hands on the other side.",
    ],
    "shame": [
        "She couldn't meet their eyes. Not since they'd found out.",
        "He showered until the water recycler cut him off. Still felt it.",
        "The file existed. Someone could pull it up at any time. He lived around that fact.",
        "She practiced the lie until it felt natural. It still tasted wrong.",
        "Everyone knew. Nobody said it. That was worse than saying it.",
        "He'd written an explanation. Deleted it. Written another. Deleted that too.",
    ],
    "hollow_joy": [
        "They threw a party when the supply ship arrived. The laughter had edges.",
        "Someone found a bottle. They drank and sang and pretended this was enough.",
        "Happy birthday. The candle was a smokestick. The cake was NutriLoaf with a ration packet on top.",
        "The good news was genuine. Nobody could feel it. They went through the motions.",
        "He smiled because smiling was what you did. The muscles remembered even when the feeling didn't.",
        "Celebration. Mandatory. The memo said 'morale event.' The attendees said nothing.",
    ],
    "bitter_hope": [
        "The signal was weak. It could be a ship. It could be nothing. They suited up anyway.",
        "Maybe this posting would be different. She'd said that about the last three.",
        "The seeds sprouted. Tiny green shoots in the hydroponics tray. Everyone came to look. Nobody said what they were thinking.",
        "He kept the letter of transfer in his pocket. Read it every night. The date was two years old.",
        "Hope was the cruelest thing in the supply drop. It kept them going. It kept them here.",
        "She promised herself one more year. Same promise she'd made last year.",
    ],

    # ---- PSYCHOLOGICAL family ----
    "paranoid": [
        "The camera in the corridor had been moved. Two degrees. Nobody authorized it.",
        "Three people asked the same question today. The same words. The same pause before asking.",
        "The new transfer smiled too much.",
        "Someone accessed the personnel files at 0300. The log showed no user.",
        "The message said 'routine.' Nothing about this was routine.",
        "She counted the footsteps behind her. They matched hers. Exactly.",
        "The manifest had been altered. Small changes. Names rearranged. One added.",
    ],
    "isolation": [
        "The last transmission was forty-seven days ago. The silence since then had a texture.",
        "No footprints but their own. For weeks. Months, maybe.",
        "The sound of their own breathing had become company. They talked back to it.",
        "The colony was designed for two hundred. There were eleven.",
        "The nearest help was eight months away by shuttle. If the shuttle came.",
        "She hadn't heard another human voice in six days. HERMES didn't count.",
        "The perimeter was quiet. That used to be a relief.",
    ],
    "claustrophobia": [
        "The ceiling was 2.1 meters. Standard. It felt lower every day.",
        "The hab pod seated four. There were six of them. Elbows and knees and recycled breath.",
        "The airlock sealed behind her and the walls became the world.",
        "The mine shaft narrowed. She could touch both walls. Then only one arm fit.",
        "He measured the room every morning. Same numbers. Tighter feeling.",
        "The ventilation cut for thirty seconds. In the dark, the walls moved.",
    ],
    "agoraphobia": [
        "The ice shelf stretched to the horizon in every direction. No walls. No ceiling. No end.",
        "She stepped outside the perimeter and the sky pressed down like a weight.",
        "Too much space. The wind had nowhere to stop. Neither did the things that rode it.",
        "The open ground between the colony and the supply drop was two hundred meters. It felt like a continent.",
        "He could see for forty kilometers in every direction. Nothing moved. That was the problem.",
        "The blizzard stopped and the landscape was a white blank. Nowhere to hide.",
    ],
    "identity_erosion": [
        "She looked at her name on the roster and it took a moment to recognize it.",
        "He told the same story three times in one shift. Didn't remember the first two.",
        "The face in the mirror was familiar. Not hers. Close. But not hers.",
        "They asked her to describe her childhood. She started twice. Different details each time.",
        "His handwriting had changed. He compared it to old logs. Different hand entirely.",
        "She answered to the wrong name. Nobody corrected her. She hadn't noticed.",
    ],
    "gaslighting": [
        "The report said clear. She'd measured the contamination herself. The report said clear.",
        "He remembered the door being red. Everyone said it was always grey. The paint was grey.",
        "The incident log had been updated. The timeline no longer matched her memory.",
        "They said she'd approved the transfer. Her signature was on the form. She'd never seen the form.",
        "HERMES confirmed the temperature was stable. Her breath fogged. HERMES confirmed the temperature was stable.",
        "The bruise was real. The event that caused it apparently wasn't.",
    ],
    "obsession": [
        "The pattern was almost there. One more look. One more hour. One more shift.",
        "She'd filled seventeen pages with the same calculation. Different approaches. Same answer. She didn't believe it.",
        "He couldn't stop checking the readings. Every four minutes. The interval was getting shorter.",
        "The connection was obvious if you looked at the right angle. Nobody else could see the angle.",
        "She pinned strings between points on the wall. Red thread. The web grew. The room shrank.",
        "He dreamed about the sequence. Woke up. Wrote it down. Went back to sleep. Dreamed the next part.",
    ],
    "sleep_deprivation": [
        "The edges of things were soft. Walls breathed. Words on screens rearranged themselves.",
        "She couldn't remember if today was Tuesday or if Tuesday had already happened.",
        "He saw movement in the corner. When he looked, it was a coat on a hook. He wasn't sure it had been there before.",
        "The shift was eight hours. She'd been working for fourteen. The clock hadn't moved.",
        "Conversations came in fragments. Sentences that started somewhere else and ended nowhere.",
        "He closed his eyes while standing. When he opened them, he was in a different room.",
    ],
    "hypervigilance": [
        "She tracked every sound. The vent cycle. The generator rhythm. Footsteps at eighty meters.",
        "His eyes moved before his head did. Scanning. Always scanning.",
        "The door opened and three things happened at once: hand to weapon, body sideways, eyes on the entryway.",
        "She mapped exits in every room before she mapped faces.",
        "A wrench dropped two corridors away. He identified the tool, the distance, and the direction before the echo died.",
        "Sleep happened in forty-minute intervals. Any longer felt like dying.",
    ],

    # ---- GENRE family ----
    "noir": [
        "The office smelled like ozone and old decisions. The desk had seen better contracts.",
        "She lit a smokestick and let the silence do the talking.",
        "Everyone had an angle. The trick was figuring out whose angle would get you killed first.",
        "Rain on the viewport. A figure in the corridor. A question nobody wanted answered.",
        "Trust was a commodity. Like rations. You spent it carefully and never got a refund.",
        "The truth was in the ledger. So was the motive. Same column.",
    ],
    "military": [
        "Contact, bearing 270, range 200 meters, count unknown. Weapons free.",
        "The briefing lasted four minutes. The mission would last however long it lasted.",
        "Check your sectors. Check your gear. Check the person next to you. That's the order.",
        "The perimeter was compromised at 0347. Response time: eleven seconds. Acceptable.",
        "She gave the order the way orders are given: clearly, once, without looking back.",
        "Ammunition count: forty-seven rounds, three batteries, one flare. Make them count.",
    ],
    "religious_fervor": [
        "The signal was proof. The frequency was a hymn. The planet was the choir.",
        "They knelt at the bore shaft's edge and called what came up an answer to prayer.",
        "She carved the symbol into her palm because faith should cost something.",
        "The text was scripture. It said so in the preamble. That was enough.",
        "He preached to the shift change. Three converts by Thursday. The colony wasn't sure what they'd converted to.",
        "The cold was a trial. The hunger was a trial. The things in the dark were a test of worthiness.",
    ],
    "cult_devotion": [
        "The leader said it was true. That was the end of the discussion.",
        "They spoke in unison. Not rehearsed. Synchronized. Like something else was speaking through them.",
        "The newcomer asked a question. The silence that followed wasn't angry. It was pitying.",
        "Everyone wore the mark. It meant family. It meant you'd passed the point of leaving.",
        "The ritual made no sense from outside. From inside, it was the only thing that made sense.",
        "She'd stopped saying 'I' three weeks ago. 'We' was the only pronoun that felt real.",
    ],
    "corporate_dystopia": [
        "The memo was seven pages long. The word 'death' didn't appear. The word 'attrition' appeared nine times.",
        "Mammona's insurance policy had a clause for 'Acts of Entity.' Nobody could define what an entity was. Claims were denied.",
        "The performance review was positive. The recommendation was termination. Both were genuine.",
        "The holiday bonus was a Sunny Fizz voucher. Redeemable at participating locations. There were no participating locations.",
        "Safety training was mandatory. Compliance was tracked. Implementation was unfunded.",
        "The quarterly report described eleven deaths as 'personnel throughput adjustment.'",
        "The suggestion box had a lock. Nobody had the key. It was still full.",
    ],
    "frontier_grit": [
        "The drill bit broke again. She welded it with a torch made from a reactor coupling and a prayer.",
        "Breakfast was NutriLoaf, black coffee, and whatever you could scrape from the previous shift's leftovers.",
        "His hands were cracked to the knuckle. He wrapped them in cargo tape and kept working.",
        "The wall leaked. They patched it. It leaked again. They patched it again. That was the job.",
        "No one complained. Complaining took energy. Energy was for surviving.",
        "She'd built the shelter from scrap, spit, and stubbornness. It held.",
    ],
    "gallows_humor": [
        "The safety poster read 'Another Day, Another Dollar.' Someone wrote 'Funeral' over 'Dollar.'",
        "The vending machine offered three choices: NutriLoaf, NutriLoaf (Seasoned), and Regret.",
        "A sign above the airlock read 'EXIT.' Underneath, in marker: 'Permanently.'",
        "The shift schedule listed seven names. Four were crossed out.",
        "Someone taped a picture of a tropical beach to the freezer wall. Caption: 'You Are Here.'",
        "The employee of the month board had the same name for fourteen months straight. The employee was deceased.",
        "Orientation manual, page one: 'Welcome. You've made a terrible decision.'",
    ],
    "clinical": [
        "Ambient temperature: -31C. Humidity: 4%. Barometric pressure: declining.",
        "Subject presented with dilated pupils and elevated cortisol.",
        "Structural integrity at 74%. Within acceptable parameters. Parameters last updated fourteen months ago.",
        "The specimen measured 0.3 meters at recovery. Current: 0.7 meters. Growth rate: accelerating.",
        "Neural activity detected in tissue sample 7-C. Tissue sample 7-C was inorganic.",
        "Blood pressure: 90/60. Heart rate: 112. Cognitive function: indeterminate.",
        "Sample degradation: 0.4% per hour. Cause: unknown. Classification: pending.",
    ],

    # ---- STATE family ----
    "desperate": [
        "The oxygen meter read 11%. It read 14% an hour ago.",
        "She pressed her back against the door and held her breath. The footsteps stopped. Then started again.",
        "Three rounds left. Four of them out there.",
        "The escape pod seated six. There were nine of them.",
        "The radio crackled. Behind the static, something that might have been a voice. Or a heartbeat.",
        "Blood on the wall. Still wet. The body was gone.",
        "The fuel gauge lied sometimes. He prayed it was lying now.",
    ],
    "numb": [
        "Another day. Another meal that tasted like the container.",
        "The alarm went off at 0500. It always goes off at 0500.",
        "Someone new arrived. They'd learn to stop smiling.",
        "The drill hit something. They noted it and kept drilling.",
        "A colonist died in Section B. They cleaned the room and assigned it to the next arrival.",
        "She filed the report. Same form. Same fields. Same nothing.",
    ],
    "resigned": [
        "It is what it is. That's what they say here.",
        "Nobody files complaints anymore.",
        "The countdown stopped meaning anything around month fourteen.",
        "Hope is a resource. Like food, like fuel. They're running out of all three.",
        "Tomorrow will be the same. This is the job.",
        "She used to plan for after. Now she plans for shift end.",
    ],
    "furious": [
        "The memo arrived at 0600. Casual. As if policy could apologize for people.",
        "Mammona's response to eleven dead was a form letter.",
        "The safety equipment hadn't been inspected in eight months. The reports said otherwise.",
        "Corporate sent flowers. Synthetic. To a planet where nothing grows.",
        "He read the quota increase. Read it again. Threw the data pad at the wall.",
        "She said what everyone was thinking. Nobody backed her up. That made it worse.",
    ],
    "defiant": [
        "They said the mine was closed. She went back down anyway.",
        "The order came through official channels. He ignored official channels.",
        "She welded the door shut from the inside. Mammona could send someone to open it.",
        "They said it couldn't be done. That wasn't an answer. That was a dare.",
        "He filed the report with the real numbers. Let them come.",
        "The contract said obey. She'd stopped reading the contract.",
    ],
    "manic_energy": [
        "Everything at once. Fix the drill. Patch the wall. Check the perimeter. Eat later. Sleep never.",
        "She talked fast enough that words collided. Meaning arrived in pieces.",
        "His hands were a blur on the console. Twelve tasks. Three finished. Nine started.",
        "The plan was brilliant. Also incomplete. Also contradicted the previous plan.",
        "She vibrated with purpose. The purpose changed hourly. The vibration didn't.",
        "Sleep was a waste of time he didn't have for problems he couldn't stop solving.",
    ],
    "exhaustion": [
        "She sat down to rest for a moment. That was three hours ago.",
        "His hands did the work. The rest of him was somewhere else. Somewhere horizontal.",
        "The shift ended. Moving required a decision she wasn't ready to make.",
        "Eighteen hours. Nineteen. The numbers stopped being meaningful somewhere around sixteen.",
        "She leaned against the wall and closed her eyes. Just for a second. The wall was warm. That was wrong. She didn't care.",
        "Coffee wasn't working. Nothing was working. He was still working.",
    ],
}


# ============================================================
# DIALOGUE FRAGMENTS — 300+ total, 12 context types
# ============================================================

DIALOGUE = {
    "greeting": {
        "_universal": [
            "You're new. You'll learn.",
            "Name doesn't matter. Shift assignment does.",
            "Welcome to the end of the line.",
            "Don't get comfortable. Nobody does.",
            "Fresh contract? Yeah, I can tell by the eyes.",
            "You made it. That's the easy part.",
            "Another warm body. Good. We're short-handed.",
            "Stow your gear. Orientation's in ten. Don't be late.",
            "You look like you've got questions. Save them.",
            "First piece of advice: don't ask about the last crew.",
        ],
        "paranoid": [
            "Who sent you?",
            "I didn't hear the shuttle. When did you arrive?",
            "You're not on the manifest I saw.",
        ],
        "gallows_humor": [
            "Welcome to paradise. The brochure lied.",
            "New meat. I give you three weeks.",
            "Hope you like NutriLoaf. You're going to see a lot of it.",
        ],
        "tender": [
            "Hey. You look tired. There's coffee in the mess.",
            "Take the bunk by the wall. It's warmer.",
        ],
        "clinical": [
            "New arrival. Please report to medical for baseline screening.",
            "Name, contract number, blood type. In that order.",
        ],
        "desperate": [
            "Thank god. We need bodies. Can you hold a drill?",
            "You're here? Good. We lost two more last shift.",
        ],
        "military": [
            "Report. Name, rank, specialization.",
            "Get your gear squared. Briefing in ten.",
        ],
        "corporate_dystopia": [
            "Welcome aboard. Your orientation packet includes a liability waiver.",
            "You'll find your complimentary Sunny Fizz in the welcome kit. Everything else costs extra.",
        ],
        "numb": [
            "Oh. You're new. Right. The bunks are that way.",
            "Yeah. Hi. Tools are in the shed. Good luck.",
        ],
        "resigned": [
            "Another contract. Same promises. You'll figure it out.",
        ],
        "frontier_grit": [
            "Can you swing a hammer? Good. Welcome.",
        ],
    },

    "warning": {
        "_universal": [
            "Don't go near the bore shaft after dark.",
            "If HERMES starts talking different, walk away.",
            "Stay inside the perimeter. I'm not asking.",
            "Something's wrong with Section C. Take the long way.",
            "Keep your radio on. Keep your head down.",
            "You hear singing, you come back. Don't follow it.",
            "Trust your gut. Your gut's been right more than the sensors.",
            "Don't eat anything you didn't bring with you.",
            "The night shift has rules. Follow them. Even the ones that sound crazy.",
            "If the ground shakes, don't freeze. Run toward the colony, not away.",
        ],
        "dread": [
            "The walls down there aren't walls. Don't touch them.",
            "I heard it last night. In the pipes. It knows the layout.",
            "If the lights flicker, don't count them. Just move.",
        ],
        "paranoid": [
            "Don't trust the logs. Someone's been rewriting them.",
            "Watch the new transfer. Something's off about the way they listen.",
            "Don't say anything on an open channel. They're listening.",
        ],
        "survival_horror": [
            "Three clips. That's all we've got. Don't miss.",
            "The barricade won't hold through another night.",
            "Keep a blade on you. Ammo runs out. Steel doesn't.",
        ],
        "clinical": [
            "Contamination levels in the lower shaft exceed safety thresholds by 340%.",
            "Prolonged exposure at current levels will result in irreversible neurological changes.",
        ],
        "frontier_grit": [
            "Wind's picking up. Storm by midnight. Tie everything down.",
            "Check the perimeter braces. Last storm took two out.",
        ],
        "cosmic_horror": [
            "Don't look at the carvings too long. Trust me on this.",
        ],
        "folk_horror": [
            "The Sons are watching the bore shaft. Don't go alone.",
        ],
        "body_horror": [
            "If you see the growth on the walls, don't scratch it. Don't breathe near it.",
        ],
        "quiet_terror": [
            "If the silence feels heavy, leave. Don't investigate. Just leave.",
        ],
        "desperate": [
            "Don't go out there alone. I don't care what the mission says.",
        ],
        "exhaustion": [
            "If you can't stay awake, tell someone. Don't fall asleep on watch. Not out here.",
        ],
    },

    "confession": {
        "_universal": [
            "I did something. On my last posting. I can't undo it.",
            "I'm not who they think I am.",
            "I've been stealing rations. Not much. Enough.",
            "I knew about the risks before we shipped out. I came anyway.",
            "I haven't slept properly in weeks. I hear things.",
            "I'm scared. I know that doesn't help. But I'm scared.",
            "I lied on my psych evaluation. They would've flagged me.",
            "There's something I should've told you before we went down there.",
        ],
        "guilt": [
            "I could've saved her. I had time. I didn't move.",
            "The report I filed was wrong. On purpose.",
            "I knew the shaft was unstable. I signed off anyway.",
        ],
        "shame": [
            "I sold them out. For a shuttle ticket. They didn't make it.",
            "Don't look at me like that. You don't know what I was.",
        ],
        "tender": [
            "I don't want to die here. Not here. Not without seeing the sky.",
            "I've never told anyone this. I trust you. That scares me.",
        ],
        "paranoid": [
            "I think they know. I think they've always known.",
        ],
        "dread": [
            "I saw what's down there. I wish I hadn't. I can't stop seeing it.",
            "I've been dreaming about the bore shaft. Every night. Same dream.",
        ],
        "body_horror": [
            "Something's changing. In me. I can feel it under the skin.",
        ],
        "numb": [
            "I don't feel anything anymore. I know I should. I just don't.",
        ],
        "dissociation": [
            "I watched myself do it. Like I was standing behind my own shoulder.",
        ],
        "obsession": [
            "I can't stop going back. The pattern. I'm so close to understanding it.",
        ],
        "gaslighting": [
            "I know what I saw. Everyone says I didn't. But I know.",
        ],
        "identity_erosion": [
            "I don't remember signing up for this. But my name's on the contract.",
        ],
    },

    "rumor": {
        "_universal": [
            "They say the last crew didn't leave. They're still down there.",
            "I heard Mammona's been here before. We're not the first team.",
            "Word is the supply ship isn't coming back this cycle.",
            "Someone found something in the deep bore. They won't say what.",
            "The medic's running tests she wasn't ordered to run.",
            "I heard HERMES talks to itself at night. Full conversations.",
            "Night shift says they heard drilling. From below the deepest shaft.",
            "One of the engineers found old Mammona equipment. Decades old. Down there.",
        ],
        "paranoid": [
            "The transfer from Karnaith? MasTema. Has to be.",
            "Someone's sending signals off-colony. I've seen the power spikes.",
            "Three people got reassigned the same day. No explanation.",
        ],
        "cosmic_horror": [
            "The ruins go deeper than the scans show. A lot deeper.",
            "The drill team says the rock down there isn't rock.",
            "The geologist quit. Wouldn't say why. Wouldn't go back down.",
        ],
        "corporate_dystopia": [
            "The real product isn't minerals. It's the data. We're the experiment.",
            "Our insurance was cancelled three weeks before deployment. Nobody told us.",
        ],
        "gallows_humor": [
            "Heard the last medic ate a gauss round. Voluntarily. Can't say I blame them.",
            "The Sunny machine's been predicting who dies next. It's three for three.",
        ],
        "folk_horror": [
            "The Sons left something at the bore shaft. The night shift won't go near it.",
        ],
        "body_horror": [
            "The colonist they found in the shaft? Alive. But different. They won't let anyone see.",
        ],
        "quiet_terror": [
            "Section F went quiet. Not silent. Quiet. There's a difference.",
        ],
        "dread": [
            "The dogs won't go near the bore shaft. Haven't in days.",
        ],
        "numb": [
            "Someone said the reactor's leaking. Could be true. Nobody checked.",
        ],
        "survival_horror": [
            "Something got into the supply cache. Left tracks. Not footprints.",
        ],
    },

    "threat": {
        "_universal": [
            "Walk away. Now.",
            "You didn't see anything. We're clear on that.",
            "I've done things you wouldn't believe. Don't make me add to the list.",
            "One more word and I'll space you myself.",
            "I know where you sleep.",
            "Don't push me. Not today.",
            "This conversation's over. Walk.",
            "Last chance. I'm not known for second chances.",
        ],
        "furious": [
            "Mammona took everything from me. You work for Mammona. Do the math.",
            "Say that again. I dare you.",
            "I'll burn this whole colony down before I let them win.",
        ],
        "paranoid": [
            "I know what you've been doing. I have the logs.",
            "Tell your handler I'm not going quietly.",
        ],
        "desperate": [
            "Give me the rations or I take them. Your choice.",
            "I've got nothing left to lose. You do.",
        ],
        "military": [
            "Stand down. That's not a request.",
            "You've got ten seconds. Then I stop asking.",
        ],
        "defiant": [
            "Try it. See what happens.",
            "You think I'm afraid of you? After what I've seen down there?",
        ],
        "noir": [
            "Careful. People who ask questions out here don't get answers. They get missing.",
        ],
        "numb": [
            "I'll do it. Don't think I won't. I've stopped caring.",
        ],
        "gallows_humor": [
            "I'll kill you. Not a threat. Just planning my afternoon.",
        ],
        "corporate_dystopia": [
            "File a complaint. See how far it gets. I'll wait.",
        ],
    },

    "plea": {
        "_universal": [
            "Please. I've got family waiting.",
            "Just one more day. That's all I'm asking.",
            "Don't leave me here. Not in the dark.",
            "I'll do anything. Whatever you need. Just don't send me back down.",
            "Help me. I can't do this alone.",
            "I'm not ready. Give me time. Please.",
            "You're the only one I can ask.",
        ],
        "desperate": [
            "If we don't move now, we don't move at all.",
            "There's still time. There has to be.",
            "I'm begging you. I've never begged for anything.",
        ],
        "grief": [
            "Bring them back. I know you can't. But bring them back.",
            "Don't let it happen again. I can't lose another one.",
        ],
        "tender": [
            "Stay. Just for a while. I can't be alone right now.",
        ],
        "shame": [
            "Don't tell them. Please. I'll fix it. Just don't tell them.",
        ],
        "exhaustion": [
            "Let me rest. Just an hour. I can't keep going like this.",
            "I know there's work. I know. Just... not right now.",
            "My hands won't stop shaking. Just give me a minute.",
        ],
        "body_horror": [
            "Get it out. I can feel it. Get it out of me.",
        ],
        "isolation": [
            "Talk to me. About anything. I need to hear a voice that isn't mine.",
        ],
        "bitter_hope": [
            "Tell me it gets better. I don't care if it's true. Just say it.",
        ],
        "survival_horror": [
            "We can't stay here. I know it's not safe out there. It's not safe in here either.",
        ],
        "paranoid": [
            "Don't tell anyone I asked you. Promise me. Don't tell anyone.",
        ],
        "resigned": [
            "I know it won't matter. I'm asking anyway.",
        ],
    },

    "observation": {
        "_universal": [
            "The ice out there doesn't look right today.",
            "Generator's running hot. Been running hot all week.",
            "Haven't seen the night shift crew in two days.",
            "The temperature's been dropping. Faster than the forecast.",
            "Something's changed. I can't tell you what. But something's changed.",
            "The supply cache is lighter than it should be.",
            "Stars look different tonight. Probably nothing.",
            "The perimeter lights keep cutting out. Same section. Every night.",
            "HERMES has been routing power to the comms array. Nobody asked it to.",
        ],
        "clinical": [
            "Barometric pressure's been declining for seventy-two hours. No weather system to account for it.",
            "Contamination readings in Section D have tripled since last survey.",
            "Colonist bio-readings show a collective cortisol spike at 0300. Cause unidentified.",
        ],
        "paranoid": [
            "The duty roster's been altered. Third time this week.",
            "HERMES rerouted my comms request. Said it was maintenance. It wasn't.",
            "The cameras in B-wing have a six-second gap every hour. Same time.",
        ],
        "dread": [
            "The drill's making a sound it didn't make yesterday.",
            "Something moved out there. At the edge of the lights. Just for a second.",
            "The ice is cracking. Not from the cold. From below.",
        ],
        "numb": [
            "Another storm. Third this week. Fourth? Does it matter?",
            "The ration count went down again. Nobody asked questions.",
        ],
        "frontier_grit": [
            "Wind shifted. Storm's coming from the north this time.",
            "The south wall needs shoring up. Bolts are shearing.",
        ],
        "cosmic_horror": [
            "The stars aren't where they should be. I checked the charts twice.",
            "The bore shaft is three meters deeper than we drilled it.",
        ],
        "slow_dread": [
            "The stain is back. Same spot. We bleached it twice.",
        ],
        "hypervigilance": [
            "Three new sounds in the ventilation system since yesterday. I've catalogued them.",
            "Someone moved something in the storage bay. Third shelf. Left side. I can tell.",
        ],
        "body_horror": [
            "The sample in the lab is larger today. Nobody fed it.",
        ],
    },

    "complaint": {
        "_universal": [
            "The food's getting worse. Didn't think that was possible.",
            "My bunk's got condensation running down the wall. Again.",
            "The heating's been out in Section B for three shifts.",
            "Nobody tells us anything. We just get the memo after the fact.",
            "I've been on doubles for two weeks. There's no overtime. There's never overtime.",
            "The drill's vibration is giving everyone headaches. Nobody's filed for maintenance.",
            "Water recycler's making that sound again. Tastes like plastic.",
            "The comm system drops out every time I try to file a report.",
        ],
        "furious": [
            "Mammona promised rotation every six months. It's been fourteen.",
            "They cut the rations again. Corporate's eating steak on the orbital.",
            "I've filed six safety reports. Not one response. Not one.",
        ],
        "corporate_dystopia": [
            "The complaint form requires a manager's signature. The manager's been dead for three months.",
            "HR's response time is eight to twelve weeks. Average survival expectancy is ten.",
            "The wellness program consists of a pamphlet. The pamphlet says 'stay positive.'",
        ],
        "gallows_humor": [
            "The good news is the food tastes the same hot or cold. The bad news is it tastes the same.",
            "They fixed the shower. Now it's cold AND brown.",
            "The safety briefing's shorter now. Fewer things to be safe from, I guess.",
        ],
        "exhaustion": [
            "I can't remember the last time I slept through a full cycle.",
            "My hands shake before the shift starts. Didn't used to do that.",
        ],
        "resigned": [
            "It doesn't matter. Nothing changes. File the report if you want.",
        ],
        "desperate": [
            "If they don't send a resupply, we've got ten days. Maybe eight.",
        ],
        "claustrophobia": [
            "The hab pod's getting smaller. I know it isn't. It is.",
        ],
        "isolation": [
            "I haven't had a real conversation in eleven days.",
        ],
        "numb": [
            "Same food. Same shift. Same complaints. Why do I bother.",
        ],
        "defiant": [
            "I filed for better conditions. They said no. I'm filing again.",
        ],
    },

    "memory": {
        "_universal": [
            "I used to have a dog. On Rhea-2. She'd sleep on my feet.",
            "My mother cooked with spices that don't exist out here. I can still smell them sometimes.",
            "There was a bar on Karnaith. Top level. You could see the clouds from the window.",
            "I had a garden once. Real soil. Real sun. Tomatoes.",
            "We used to play cards on the transit ship. Same deck. Same jokes. Different crew now.",
            "I remember trees. Real ones. The way the wind sounded through them.",
            "There was a kid in my building on Novaris-3. Played violin in the stairwell. Terrible. Beautiful.",
        ],
        "nostalgia": [
            "The coffee tasted different on Novaris-3. Everything tasted different.",
            "I remember rain. Real rain. Not recycled runoff. The kind that smelled like dirt.",
            "We used to swim in the reservoir at night. Before they fenced it. Before they charged for water.",
        ],
        "grief": [
            "She always hummed when she cooked. That song. I can't remember the name now.",
            "He used to fix things with his left hand. Always his left. I see it every time I pick up a wrench.",
            "Her laugh. That's what I miss. Not the big things. The laugh.",
        ],
        "melancholy": [
            "We watched the sunset from the ridge. Rhea Alpha and Beta, one after the other. Took an hour.",
            "I kept the wrapper from the last candy bar we shared. It's in my boot.",
        ],
        "tender": [
            "She said she'd wait. I believed her. Still do, actually.",
            "He used to read to me. Old books. Paper ones. His voice made them real.",
        ],
        "bitter_hope": [
            "I keep the letter. The one about the transfer. It's probably expired. I keep it anyway.",
        ],
        "frontier_grit": [
            "First posting was worse. No reactor. No walls. Just tarps and stubbornness.",
        ],
        "dissociation": [
            "Sometimes I can't tell if I'm remembering or imagining. Both feel the same now.",
        ],
        "guilt": [
            "I think about the ones I left behind. Every shift start. Every shift end.",
        ],
        "numb": [
            "I used to have stories. Now I've got the same day on repeat.",
        ],
        "isolation": [
            "My mother's voice. I'm starting to forget it. That scares me more than anything down there.",
        ],
    },

    "joke": {
        "_universal": [
            "What's the difference between NutriLoaf and the wall? The wall has more flavor.",
            "A miner, an engineer, and a Mammona exec walk into a bar. The exec owns the bar, the drinks, and the miner.",
            "You know why they call it the outer rim? Because everything out here is on the edge.",
            "Two colonists bet on who'd die first. Winner collected in NutriLoaf. Loser didn't need it.",
            "I asked HERMES for a weather report. It said 'cold.' Revolutionary.",
            "What do you call an optimist on Erebus? New.",
            "How many Mammona execs does it take to change a light bulb? None. They issue a memo about darkness compliance.",
        ],
        "gallows_humor": [
            "The retirement plan here is simple. You don't.",
            "What's Mammona's motto? 'Expendable is just a word. Like 'alive.'",
            "They put a suggestion box in the mess. Someone put a grenade in it. Best suggestion yet.",
            "Know what's under the ice? Don't worry. It knows what's over it.",
        ],
        "desperate": [
            "At least we've got our health. Wait, no. We don't have that either.",
        ],
        "frontier_grit": [
            "I've been in worse spots. Can't remember when. But I've been in worse spots.",
        ],
        "numb": [
            "Funny thing happened today. Wait, no it didn't. Never mind.",
        ],
        "corporate_dystopia": [
            "The company slogan used to be 'People First.' They changed it. Didn't change the priorities though.",
        ],
        "noir": [
            "A guy walks into a colony. That's not a joke. That's an obituary.",
        ],
        "clinical": [
            "Statistically, one in six of us won't finish the contract. I ran the numbers twice.",
        ],
    },

    "prayer": {
        "_universal": [
            "If anyone's listening. I don't need much. Just one more day.",
            "I'm not a believer. But if something's up there, now would be a good time.",
            "Keep them safe. I don't care about me. Just keep them safe.",
            "Whatever I did to deserve this, I'm sorry.",
            "Let the drill hold. Let the walls hold. Let the generator hold. That's enough.",
            "One more sunrise. That's all. One more.",
        ],
        "religious_fervor": [
            "The signal is the voice. The voice is the truth. We are heard.",
            "Grant us the fire to endure. The cold is a test. We will pass.",
            "Blessed are the frozen. For they shall know warmth eternal.",
        ],
        "cult_devotion": [
            "We are the ones who see. We are the ones who stay.",
            "The sleeping god stirs. We are ready. We've always been ready.",
        ],
        "desperate": [
            "Please. I know I don't deserve it. Please.",
            "Not like this. Not here. Anywhere but here.",
        ],
        "bitter_hope": [
            "Maybe tomorrow. Maybe tomorrow things get better.",
        ],
        "guilt": [
            "Forgive me. I know what I did. Forgive me anyway.",
            "I'll make it right. I swear. Just let me live long enough.",
        ],
        "dread": [
            "Don't let it find me. Whatever it is. Don't let it find me.",
        ],
        "exhaustion": [
            "Give me strength. I've got nothing left. I'll take whatever you've got.",
        ],
        "isolation": [
            "Let someone hear me. Just one person. That's all I need.",
        ],
        "resigned": [
            "I'm not asking for much. Just let it end clean.",
        ],
        "nostalgia": [
            "Take me back. I know I can't go back. Take me anyway.",
        ],
    },

    "last_words": {
        "_universal": [
            "Tell them I tried.",
            "It's not cold anymore. That's strange.",
            "I should've stayed on Karnaith.",
            "Don't open the door. Promise me.",
            "I can hear it. Can you hear it?",
            "It's beautiful. Oh god, it's beautiful.",
            "Not yet. Not yet. Not yet.",
            "I'm sorry. For all of it.",
        ],
        "dread": [
            "It's behind me, isn't it.",
            "Don't look at it. Don't look. Don't--",
            "It knows my name. It's saying my name.",
        ],
        "tender": [
            "I'm glad it was you. Here at the end. I'm glad.",
            "Tell her I loved her. She knows. Tell her anyway.",
        ],
        "defiant": [
            "I'm not done. I'm not--",
            "Come on then. Come on.",
            "You'll have to do better than that.",
        ],
        "resigned": [
            "Yeah. Okay.",
            "It's fine. It was always going to be this.",
        ],
        "cosmic_horror": [
            "I understand now. I wish I didn't.",
            "It's been awake the whole time. We just didn't know what awake looked like.",
        ],
        "gallows_humor": [
            "Well. That's not ideal.",
            "Worst. Posting. Ever.",
        ],
        "clinical": [
            "Note: subject experiencing rapid... cognitive... decline...",
        ],
        "body_horror": [
            "It's inside me. I can feel it growing.",
            "My hands. Look at my hands. Those aren't my hands.",
        ],
        "numb": [
            "Huh. I thought it would hurt more.",
        ],
        "furious": [
            "Mammona did this. Don't let them forget.",
        ],
        "grief": [
            "I'll see her soon. That's not so bad.",
        ],
        "bitter_hope": [
            "Maybe the next crew will make it. Maybe they'll--",
        ],
        "psychic_contamination": [
            "The words. They're all the same word. It's all one--",
            "I can see it now. It was always there. We just couldn't--",
        ],
        "guilt": [
            "I should've warned them. Tell them I should've warned them.",
        ],
        "isolation": [
            "At least I won't be alone anymore.",
        ],
    },
}


# ============================================================
# BACKSTORY TEMPLATES
# ============================================================

ORIGINS = [
    "{first} {last} signed a Mammona contract on {prev_location} because the alternative was starvation.",
    "Before Erebus, {first} worked as a {prev_job} on {prev_location}. {g} doesn't talk about why {gl} left.",
    "Born in transit between {prev_location} and Novaris-3, {first} never had a home address.",
    "The recruitment poster said 'opportunity.' {first} {last} was desperate enough to believe it.",
    "{prev_location} burned {first} out. Twelve years as a {prev_job}, nothing to show for it but debts and a bad knee.",
    "Nobody leaves {prev_location} voluntarily. {first} {last} didn't leave voluntarily.",
    "A {prev_job} by training, {first} ended up on Erebus because {faction} needed someone expendable.",
    "On {prev_location}, they called {first} {last} a survivor. {g} prefers 'still alive.'",
    "Three contracts. Three postings. {first} keeps signing because the alternative is Thalassa Deep.",
    "{first} {last} was a {prev_job} before the incident on {prev_location}. Now {gl}'s whatever Mammona needs {go} to be.",
    "Some people choose the outer rim. The outer rim chose {first}. Specifically, a Mammona recruiter with a quota.",
    "Raised by a {prev_job} on {prev_location}, {first} learned early that keeping quiet keeps you alive.",
    "After {event}, {first} took the first contract available. Didn't read the fine print. Nobody reads it.",
    "The last thing {first} remembers about {prev_location} is the sound of the airlock sealing behind {go}.",
    "Former {prev_job}. Former citizen of {prev_location}. Current property of Mammona Mining.",
    "{first}'s file says {gl} volunteered for Erebus. {first}'s face says something else.",
    "Two years in a Mammona labor camp on {prev_location} taught {first} everything about survival and nothing about hope.",
]

TRAUMAS = [
    "When {event}, {first} was the only one who walked out. {g} hasn't forgiven {go}self for it.",
    "{first} saw something in the deep bore on {prev_location} that {gl} won't describe. {g} sleeps with the lights on.",
    "The scar on {gp} {body_part} came from {trauma_cause}. {g} tells a different story every time.",
    "After losing {go} crew on {prev_location}, {first} stopped learning names. It's easier that way.",
    "{g} was in cryo for longer than the contract specified. When {gl} woke up, everyone {gl} knew was dead.",
    "The neural chip left a mark on {gp} temple. BioVault removed the chip. The mark stays.",
    "{first} watched {prev_location} go dark from orbit. Fourteen hundred people. {g} counted the escape pods.",
    "A contamination exposure on {prev_location} left {first} with {body_part} that won't stop aching in the cold.",
    "{trauma_cause} took {gp} hearing in the left ear. Now {gl} hears things nobody else does.",
    "Three months in Thalassa Deep's flooded wing changed {first}. {g} doesn't swim anymore. {g} doesn't explain.",
    "{first} survived {event}. Technically. The part that used to laugh didn't make it.",
    "They pulled {first} from the wreckage on {prev_location} with {item} clutched in {gp} hands. {g} still carries it.",
    "What happened on {prev_location} is classified. {first}'s nightmares aren't.",
    "The {faction} caught {first} once. Let {go} go. Worse than keeping {go}.",
    "{first} doesn't talk about the {years} years between {prev_location} and Erebus. The silence says enough.",
]

MIDDLES = [
    "{g} {habit}.",
    "Off-shift, {first} {habit}. It's the closest thing {gl} has to peace.",
    "Colleagues describe {first} as quiet until cornered. Then loud. Then very, very effective.",
    "Every credit {first} earns goes to a debt that compounds faster than {gl} can pay it.",
    "Likes: silence, black coffee, being left alone. Dislikes: questions about {prev_location}.",
    "{first} keeps {item} in {gp} pocket. When asked about it, {gl} changes the subject.",
    "{g}'s good at {gp} job. Too good. The kind of good that makes people wonder what {gl}'s running from.",
    "Sleep comes in bursts. Two hours here, three there. {first} has given up on a full cycle.",
    "{first} doesn't drink. Doesn't explain why. The answer is in {gp} medical file.",
    "Between shifts, {first} can be found near the perimeter. Watching. Always watching.",
    "The other colonists leave {first} alone. Not because {gl}'s unfriendly. Because the unfriendly ones tried.",
    "{first} writes letters that {gl} never sends. The pile under {gp} bunk is growing.",
    "{g} traded {gp} last personal item for {item}. Says it was worth it. Doesn't look like it was worth it.",
    "Mammona's psych evaluation calls {first} 'functional.' {first} calls that generous.",
    "People trust {first} with their lives. {first} doesn't trust {go}self with anyone's.",
]

SECRET_TEMPLATES = [
    "{first} knows that {secret}. This knowledge is the most dangerous thing {gl} owns.",
    "What {first} hasn't told anyone: {gl} recognized the ruins. From a dream {gl} had before arriving.",
    "The file {first} carries in {gp} boot contains proof that {secret}. It's also {gp} death sentence.",
    "Someone on the colony is reporting to {faction}. {first} knows because {gl}'s the one doing it.",
    "{first} didn't come to Erebus for the credits. {gl} came because {gl} heard about {lore}.",
    "The reason {first} left {prev_location}: {gl} discovered that {secret}.",
    "Under a false panel in {gp} bunk, {first} keeps a sealed drive containing evidence that {secret}.",
    "{first}'s medical file has a gap. Three months. No records. {g} remembers every second of those three months.",
    "Nobody knows that {first} was at {prev_location} when {event}. {g} intends to keep it that way.",
    "{first}'s contract isn't standard. Clause 17 says things about {lore} that shouldn't be in a mining agreement.",
    "The signal {first} picked up last week matches a frequency {gl} heard on {prev_location}. It shouldn't exist in two places.",
    "{first} isn't {gp} real name. {gp} real name is in a Mammona blacklist.",
    "Before the posting, {faction} approached {first} with an offer. {g} hasn't accepted. {g} hasn't refused.",
    "{first} can read the precursor glyphs. Not all of them. Enough. {g} doesn't know how.",
    "The {item} that {first} carries isn't a memento. It's a key. {g} doesn't know what it opens yet.",
    "There's a reason {first} requested Erebus specifically. {g} knows what's down there. {g} wants to see it.",
]


# ============================================================
# CONTRACTION ENFORCEMENT
# ============================================================

CONTRACTION_MAP = {
    "do not": "don't", "does not": "doesn't", "did not": "didn't",
    "I am": "I'm", "I have": "I've", "I will": "I'll", "I would": "I'd",
    "you are": "you're", "you have": "you've", "you will": "you'll",
    "we are": "we're", "we have": "we've", "they are": "they're",
    "they have": "they've", "it is": "it's", "is not": "isn't",
    "are not": "aren't", "was not": "wasn't", "were not": "weren't",
    "has not": "hasn't", "have not": "haven't", "will not": "won't",
    "would not": "wouldn't", "could not": "couldn't", "should not": "shouldn't",
    "cannot": "can't", "can not": "can't", "that is": "that's",
    "who is": "who's", "what is": "what's", "there is": "there's",
    "here is": "here's", "let us": "let's",
}

FORMAL_TONES = {"clinical", "corporate_dystopia", "military"}


def enforce_contractions(text, tone):
    """Contract formal English into natural speech. Formal tones keep formal phrasing."""
    import re
    if tone not in FORMAL_TONES:
        for formal, contracted in CONTRACTION_MAP.items():
            text = text.replace(formal, contracted)
            text = text.replace(formal.capitalize(), contracted.capitalize())
    # Clean up double punctuation (always, regardless of tone).
    # Replace exactly 2 dots (not 3+ ellipsis) with a single dot.
    text = re.sub(r'(?<!\.)\.\.(?!\.)', '.', text)
    # Clean up other doubled punctuation
    text = text.replace(",,", ",").replace("!!", "!").replace("??", "?")
    return text


# ============================================================
# TRAIT VOICE MODIFIER
# ============================================================

TRAIT_VOICE = {
    "Paranoid": {
        "hedges": ["I think", "maybe", "supposedly"],
        "additions": ["Watch your back."],
    },
    "Brave": {"style": "short_direct"},
    "Coward": {
        "hedges": ["I'm not involved", "don't ask me"],
        "deflections": True,
    },
    "Stoic": {"style": "understate"},
    "Volatile": {
        "intensifiers": ["damn", "bloody"],
        "style": "escalate",
    },
    "Kind": {
        "softeners": ["Listen,", "I know it's hard, but"],
    },
    "Pessimist": {
        "additions": ["It won't work.", "We're dead anyway."],
    },
    "Loner": {"style": "short_direct"},
    "Calm Under Fire": {"style": "understate"},
    "Charismatic": {
        "softeners": ["Here's the thing:", "Look,"],
    },
    "Nervous": {
        "hedges": ["I don't know, maybe", "sorry, I just"],
        "stutter": True,
    },
    "Nihilist": {
        "additions": ["None of this matters.", "In the end, same result."],
    },
    "Fatalist": {
        "additions": ["It was always going to end this way."],
    },
    "Compulsive Liar": {
        "contradictions": True,
    },
    "Diplomatic": {
        "softeners": ["With respect,", "I understand, but"],
    },
}


def apply_trait_voice(line, trait):
    """Modify a dialogue line based on the speaker's personality trait."""
    voice = TRAIT_VOICE.get(trait)
    if not voice:
        return line
    # Short, direct speakers cut to the first sentence
    if voice.get("style") == "short_direct":
        if ". " in line:
            line = line.split(". ")[0] + "."
    # Understaters replace dramatic words with muted ones
    if voice.get("style") == "understate":
        replacements = {
            "terrible": "not great", "horrifying": "bad",
            "screaming": "making noise", "terrified": "concerned",
            "nightmare": "bad dream", "dead": "gone",
            "disaster": "situation", "catastrophe": "problem",
        }
        for dramatic, understated in replacements.items():
            line = line.replace(dramatic, understated)
    # Escalators add intensity
    if voice.get("style") == "escalate":
        intensifiers = voice.get("intensifiers", [])
        if intensifiers and random.random() > 0.5:
            line = f"{R(intensifiers).capitalize()} right. {line}"
    # Softeners prepend a diplomatic opener
    if "softeners" in voice and random.random() > 0.4:
        line = f"{R(voice['softeners'])} {line[0].lower()}{line[1:]}"
    # Hedges inject uncertainty
    if "hedges" in voice and random.random() > 0.5:
        hedge = R(voice["hedges"])
        line = f"{hedge}... {line}"
    # Additions append a characteristic remark
    if "additions" in voice and random.random() > 0.5:
        line = f"{line} {R(voice['additions'])}"
    return line


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def sensory(tone):
    """Return a sensory detail matching the tone."""
    pool = SENSORY.get(tone, SENSORY["dread"])
    return R(pool)


def pick_tone(family=None):
    """Pick a random tone, optionally from a specific family."""
    if family:
        return R(TONE_FAMILIES[family])
    return R(TONES)


def pick_tone_blend():
    """Pick primary and secondary tones from different families."""
    primary = pick_tone()
    primary_family = next(f for f, tones in TONE_FAMILIES.items() if primary in tones)
    secondary_families = [f for f in TONE_FAMILIES if f != primary_family]
    secondary = pick_tone(R(secondary_families))
    return primary, secondary


def get_dialogue(context, tone, trait=None):
    """Get a dialogue line matching context, tone, and optionally modified by trait."""
    pool = DIALOGUE.get(context, DIALOGUE.get("observation", {"_universal": ["..."]}))
    lines = list(pool.get("_universal", []))
    if tone in pool:
        lines += pool[tone]
    # Pull from tone family if specific tone not found
    if tone not in pool:
        for family, tones in TONE_FAMILIES.items():
            if tone in tones:
                for t in tones:
                    if t in pool:
                        lines += pool[t]
                        break
                break
    line = R(lines) if lines else "..."
    if trait:
        line = apply_trait_voice(line, trait)
    return line


# ============================================================
# VERIFICATION
# ============================================================

if __name__ == "__main__":
    print("=" * 60)
    print("Frosthold v3 Prose & Tone Pools -- Verification")
    print("=" * 60)

    print(f"Tones: {len(TONES)}")
    total_sensory = sum(len(v) for v in SENSORY.values())
    print(f"Sensory details: {total_sensory}")
    total_dialogue = sum(
        sum(len(v) for v in ctx.values()) for ctx in DIALOGUE.values()
    )
    print(f"Dialogue fragments: {total_dialogue}")
    print(f"Origins: {len(ORIGINS)}")
    print(f"Traumas: {len(TRAUMAS)}")
    print(f"Middles: {len(MIDDLES)}")
    print(f"Secret templates: {len(SECRET_TEMPLATES)}")
    print(f"Tone families: {len(TONE_FAMILIES)}")
    print(f"Contraction map entries: {len(CONTRACTION_MAP)}")
    print(f"Trait voice entries: {len(TRAIT_VOICE)}")

    print()
    checks = [
        (f"Tones >= 45 (got {len(TONES)})", len(TONES) >= 45),
        (f"Sensory >= 270 (got {total_sensory})", total_sensory >= 270),
        (f"Dialogue >= 300 (got {total_dialogue})", total_dialogue >= 300),
        (f"Origins >= 15 (got {len(ORIGINS)})", len(ORIGINS) >= 15),
        (f"Traumas >= 15 (got {len(TRAUMAS)})", len(TRAUMAS) >= 15),
        (f"Middles >= 15 (got {len(MIDDLES)})", len(MIDDLES) >= 15),
        (f"Secrets >= 15 (got {len(SECRET_TEMPLATES)})", len(SECRET_TEMPLATES) >= 15),
    ]

    all_pass = True
    for label, result in checks:
        status = "PASS" if result else "FAIL"
        if not result:
            all_pass = False
        print(f"  [{status}] {label}")

    # Verify every tone has sensory entries
    print()
    missing_sensory = [t for t in TONES if t not in SENSORY]
    if missing_sensory:
        all_pass = False
        print(f"  [FAIL] Tones missing sensory: {missing_sensory}")
    else:
        print(f"  [PASS] All {len(TONES)} tones have sensory entries")

    # Verify minimum per tone
    thin_tones = [(t, len(SENSORY[t])) for t in TONES if len(SENSORY.get(t, [])) < 6]
    if thin_tones:
        all_pass = False
        for t, c in thin_tones:
            print(f"  [FAIL] Tone '{t}' has only {c} sensory (need 6+)")
    else:
        print(f"  [PASS] All tones have 6+ sensory entries")

    print()
    if not all_pass:
        print("SOME ASSERTIONS FAILED.")
        raise SystemExit(1)

    # Functional tests
    print("Functional tests:")
    print(f"  Sample sensory (dread): {sensory('dread')}")
    print(f"  Sample tone blend: {pick_tone_blend()}")
    print(f"  Contraction: {enforce_contractions('I do not know what I am doing here.', 'dread')}")
    print(f"  Formal kept: {enforce_contractions('Personnel do not have clearance.', 'clinical')}")
    print(f"  Dialogue (greeting, paranoid): {get_dialogue('greeting', 'paranoid')}")
    print(f"  Trait voice (Stoic): {apply_trait_voice('The situation is terrible and horrifying.', 'Stoic')}")
    print()
    print("All checks passed.")
