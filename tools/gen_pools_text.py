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
        "The air tasted like copper and ozone -- the flavor of a nosebleed she hadn't had yet.",
        "Something scraped against the hull. Rhythmic. Patient.",
        "The temperature dropped four degrees in the time it took to blink.",
        "A smell like burned hair drifted from the vent. Nobody had been welding.",
        "The lights flickered in a pattern that looked intentional.",
        "Frost formed on the inside of the window. In the shape of a hand.",
        "She pressed her palm to the wall and felt vibration. Not the generator. Something slower. Like a pulse.",
        "Something clicked in the wall. Not mechanical. Biological.",
        "The corridor ahead swallowed the flashlight beam at twelve meters. The corridor was twenty.",
        "A sound from below. Not drilling. Chewing.",
        "His coffee had gone cold in his hands. The mug was warm.",
        "The air pressure changed. Just enough to make her ears pop. The gauge read normal.",
        "A draft from the sealed door. Sealed doors don't draft. She could smell soil through it.",
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
        "The coffee tasted slightly different each morning. Nobody else noticed. She stopped mentioning it after day nine.",
        "His bunk frame was a centimeter lower on the left side. He shimmed it. Next morning, lower again.",
        "Condensation on the pipes used to drip. Now it ran in a direction. Always the same direction. Toward the bore shaft.",
    ],
    "sudden_dread": [
        "The lights cut. When they came back, someone was standing in the corridor who hadn't been there.",
        "A handprint appeared on the fogged viewport. From the outside.",
        "The drill punched through into nothing. The bit fell. They never heard it land.",
        "Every radio in the colony spoke the same word at the same time.",
        "The floor gave way under their left foot. Below it: warmth. Movement.",
        "The alarm blared once. One tone. Then silence. The system showed no record of it.",
        "She sneezed and tasted blood. When she wiped her nose, the blood was black.",
        "The wrench he set down rolled three centimeters to the left. Toward the wall. Uphill.",
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
        "Someone left a mug on the console. The coffee was still warm. The owner wasn't coming back for it.",
        "A photograph was taped to the wall. A beach, a child, sunlight. The tape was yellowing. The child would be grown now.",
        "The generator hummed a note that sounded like a lullaby his mother sang. He couldn't remember the words.",
        "The mess hall smelled like someone else's cooking. Garlic and onion. From the last supply run. Three months ago.",
        "A birthday card sat on a bunk. Unsigned. The envelope was sealed.",
        "The echo in the empty mess hall made one voice sound like two.",
        "Snow fell through a breach in the ceiling. Nobody fixed it. It was beautiful.",
        "She found a child's sock in the laundry. There were no children on the colony.",
        "The static between radio frequencies sounded almost like music. If she held still and didn't breathe.",
    ],
    "grief": [
        "Her bunk was still made. Nobody touched it. Nobody would.",
        "His name came up on the duty roster three weeks after they buried him.",
        "An empty chair at the table. Everyone noticed. No one moved it.",
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
        "The smell of machine oil reminded her of her father's garage on a Sunday morning. Grease under his nails. Radio on low.",
        "Someone was cooking rice. For a moment, he was twelve years old on Novaris-3. His grandmother's kitchen. The wooden spoon.",
        "The static on the radio sounded like the ocean. He hadn't heard the ocean in nine years.",
        "She found a Sunny Fizz can and remembered the vendor outside the school on Rhea-2. The heat. The dust. Her sister's hand in hers.",
        "The cold reminded him of something. Not Erebus cold. Mountain cold. Clean. A lifetime ago.",
        "They played cards with a deck from the supply drop. Same brand as the ones on the Kennedy.",
        "Rust on the drill platform smelled like the swing set in the park behind his mother's apartment. Iron and rain.",
        "The texture of the thermal wrap felt like his father's work jacket. Rough canvas. The kind that held warmth.",
        "A colonist whistled something in the corridor. Three notes of a song from a commercial that aired on Novaris-3 twenty years ago. He couldn't stop humming it all day.",
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
        "Rain on the viewport. A figure in the corridor. The kind of question that answers itself if you wait long enough.",
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
            "How long's your contract? Doesn't matter. You'll be here longer.",
            "The mess is left. The bunks are right. Everything else you'll figure out or you won't.",
            "Don't touch anything marked red. Don't ask why it's marked red.",
            "Keep your head down the first week. After that, keep it down permanently.",
            "You want to know the rules? There's one: survive your shift.",
        ],
        "paranoid": [
            "Who sent you?",
            "I didn't hear the shuttle. When did you arrive?",
            "You're not on the manifest I saw.",
            "Show me your contract. The real one.",
        ],
        "gallows_humor": [
            "Welcome to paradise. The brochure lied.",
            "New meat. I give you three weeks.",
            "Hope you like NutriLoaf. You're going to see a lot of it.",
            "The orientation says 'zero fatalities this quarter.' Quarter started yesterday.",
        ],
        "tender": [
            "Hey. You look tired. There's coffee in the mess.",
            "Take the bunk by the wall. It's warmer.",
            "If you need anything, I'm two bunks down. Don't be proud about it.",
        ],
        "clinical": [
            "New arrival. Please report to medical for baseline screening.",
            "Name, contract number, blood type. In that order.",
        ],
        "desperate": [
            "Thank god. We need bodies. Can you hold a drill?",
            "You're here? Good. We lost two more last shift.",
            "Can you weld? Can you shoot? Can you run? Pick two.",
        ],
        "military": [
            "Report. Name, rank, specialization.",
            "Get your gear squared. Briefing in ten.",
        ],
        "corporate_dystopia": [
            "Welcome aboard. Your orientation packet includes a liability waiver.",
            "You'll find your complimentary Sunny Fizz in the welcome kit. Everything else costs extra.",
            "Your performance review starts now. Smile.",
        ],
        "numb": [
            "Oh. You're new. Right. The bunks are that way.",
            "Yeah. Hi. Tools are in the shed. Good luck.",
        ],
        "resigned": [
            "Another contract. Same promises. You'll figure it out.",
            "You'll hate it here. Give it a month. Then you'll stop hating it. That's worse.",
        ],
        "frontier_grit": [
            "Can you swing a hammer? Good. Welcome.",
            "Show me your hands. Yeah, you'll do.",
        ],
        "furious": [
            "Great. Another mouth to feed. Mammona send you to replace the ones they killed?",
        ],
        "cosmic_horror": [
            "You're new. That's good. The new ones don't hear it yet.",
        ],
        "dread": [
            "Welcome. Try not to look at the bore shaft on your first night.",
        ],
        "isolation": [
            "Oh. Another person. Good. I was starting to forget what other people sound like.",
        ],
        "defiant": [
            "You here by choice? Didn't think so. Neither am I. That makes us even.",
        ],
        "melancholy": [
            "New face. I used to get excited about that. Now I just wonder how long you'll last.",
        ],
        "body_horror": [
            "Welcome. If anything on your body changes color, shape, or temperature -- tell medical. Don't wait.",
        ],
        "exhaustion": [
            "You're here. Great. I'm going to sleep. Take my shift. Here's the log.",
        ],
        "survival_horror": [
            "You're alive? Good. Stay close. Don't look outside. And whatever you do, don't open that door.",
        ],
        "hypervigilance": [
            "Stop. Don't move. I need to check something behind you first. ...Okay. You're clear. Welcome.",
        ],
        "quiet_terror": [
            "Don't talk yet. Listen first. ...Okay. The sounds are normal. You can speak now.",
        ],
        "slow_dread": [
            "You're new. Everything will seem normal at first. Hold onto that feeling. You'll miss it.",
        ],
        "wrongness": [
            "Welcome to the colony. Third one on this site, if you believe the records. Don't ask about the first two.",
        ],
        "sleep_deprivation": [
            "Are you real? Sorry. Stupid question. You're real. I'm just... yeah. You're real. Right?",
        ],
        "dissociation": [
            "Hi. You look familiar. Everyone looks familiar lately. Don't worry about it.",
        ],
        "nostalgia": [
            "You remind me of someone. From home. Don't take that as a compliment. I don't remember if I liked them.",
        ],
        "mania": [
            "You're here! Perfect! I have seventeen ideas and no one to bounce them off. Sit down. No, stand. Doesn't matter. Listen.",
        ],
        "shame": [
            "Don't ask anyone about me. Whatever they say, it's probably true. But don't ask.",
        ],
        "bitter_hope": [
            "Fresh face. Maybe you'll be the one who figures out how to fix this place. Nobody else has managed.",
        ],
        "guilt": [
            "The last new person... didn't make it. Wasn't my fault. Not entirely. Welcome.",
        ],
        "noir": [
            "Another soul walks into the machine. If you've got a price, someone here already knows it.",
        ],
        "identity_erosion": [
            "You know who you are? Good. Remember that. Write it down. Trust me.",
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
            "Don't open sealed doors without checking the pressure gauge first. Lost a guy that way.",
            "The thermal cores are warm. That's normal. If they're hot, drop it and run.",
            "Don't walk the corridors alone past 0200. That's not policy. That's experience.",
            "Check the dosimeter before going below level three. If it spikes, you've already been too long.",
            "The vents in the lower corridors make sounds. Ignore them unless they stop.",
        ],
        "dread": [
            "The walls down there aren't walls. Don't touch them.",
            "I heard it last night. In the pipes. It knows the layout.",
            "If the lights flicker, don't count them. Just move.",
            "Something followed the drill team back from the deep bore. Nobody's talking about it.",
        ],
        "paranoid": [
            "Don't trust the logs. Someone's been rewriting them.",
            "Watch the new transfer. Something's off about the way they listen.",
            "Don't say anything on an open channel. They're listening.",
            "The security cameras have blind spots. I've mapped them. So has someone else.",
        ],
        "survival_horror": [
            "Three clips. That's all we've got. Don't miss.",
            "The barricade won't hold through another night.",
            "Keep a blade on you. Ammo runs out. Steel doesn't.",
        ],
        "clinical": [
            "Contamination levels in the lower shaft exceed safety thresholds by 340%.",
            "Prolonged exposure at current levels will result in irreversible neurological changes.",
            "The biological readings from Section F are inconsistent with known colony fauna. Exercise caution.",
        ],
        "frontier_grit": [
            "Wind's picking up. Storm by midnight. Tie everything down.",
            "Check the perimeter braces. Last storm took two out.",
            "Ice is thinner near the east ridge. Walk soft or not at all.",
        ],
        "cosmic_horror": [
            "Don't look at the carvings too long. Trust me on this.",
            "The geometry down there doesn't follow rules. If it feels wrong, it is wrong. Leave.",
        ],
        "folk_horror": [
            "The Sons are watching the bore shaft. Don't go alone.",
            "Found offerings at the thermal vent again. Fresh. Don't touch them.",
        ],
        "body_horror": [
            "If you see the growth on the walls, don't scratch it. Don't breathe near it.",
            "If your skin itches after a bore shaft shift, report to medical. Don't wait.",
        ],
        "quiet_terror": [
            "If the silence feels heavy, leave. Don't investigate. Just leave.",
        ],
        "desperate": [
            "Don't go out there alone. I don't care what the mission says.",
            "We're down to emergency rations. Don't tell the new arrivals. Not yet.",
        ],
        "exhaustion": [
            "If you can't stay awake, tell someone. Don't fall asleep on watch. Not out here.",
        ],
        "gallows_humor": [
            "The safety briefing is shorter than it used to be. We ran out of things to warn you about that wouldn't cause a panic.",
        ],
        "furious": [
            "Mammona says the levels are safe. Mammona said that about the last colony too. Wear the mask.",
        ],
        "numb": [
            "Don't bother with the emergency exits. They're welded shut. Been that way since before we got here.",
        ],
        "defiant": [
            "Don't follow Mammona's safety route. Take the maintenance tunnel. It's longer but it's actually maintained.",
        ],
        "isolation": [
            "If you end up on solo perimeter watch, keep talking. To yourself, to the radio, to nothing. Just keep talking.",
        ],
        "tender": [
            "Eat before your shift. Not during. Not after. The food's bad but your body needs it.",
            "If you're having a rough night, the medic keeps the lights on. Nobody will judge you for going.",
        ],
        "resigned": [
            "The alarm goes off every few days. You'll learn to sleep through it. Everyone does eventually.",
        ],
        "melancholy": [
            "There's a spot by the viewport where you can see the stars. Go there when it gets bad. It helps. A little.",
        ],
        "body_horror": [
            "If you find anything organic growing where it shouldn't be, don't touch it. Don't breathe on it. Report it.",
        ],
        "slow_dread": [
            "The cracks in the lower corridor are wider than they were last month. Stay close to the wall.",
        ],
        "wrongness": [
            "Sometimes the corridor looks longer than it should. Don't measure it. Don't think about it. Just walk.",
        ],
        "psychic_contamination": [
            "If you start dreaming about the ruins before you've seen them, tell someone. Don't keep it to yourself.",
        ],
        "mania": [
            "If you're running hot, full of ideas, can't stop moving -- that's the posting talking. Slow down before it breaks you.",
        ],
        "shame": [
            "Keep your past quiet. Not because it matters, but because people here collect leverage.",
        ],
        "guilt": [
            "If someone dies on your watch, don't blame yourself. You'll have plenty of time for that later.",
        ],
        "dissociation": [
            "If you start feeling like you're watching yourself from outside, sit down. Drink water. It passes. Usually.",
        ],
        "identity_erosion": [
            "Keep a photo of yourself. From before. You'll need the reminder.",
        ],
        "noir": [
            "Everyone here has a secret. Don't go looking for them. Secrets have a way of finding you instead.",
        ],
        "survival_horror": [
            "If something gets through the perimeter, head for Section A. The walls are thicker. The locks work.",
        ],
        "bitter_hope": [
            "The supply ship comes every forty days. Count from yesterday. Hold onto that number.",
        ],
        "wrongness": [
            "If a corridor feels longer than it should, turn around. Don't count your steps.",
        ],
        "hypervigilance": [
            "Learn the sounds. Generator hum, pipe knock, vent whistle. When one's missing, pay attention.",
        ],
    },

    "confession": {
        "_universal": [
            "I did something. On my last posting. I can't undo it.",
            "I'm not who they think I am. Haven't been since Karnaith.",
            "I've been stealing rations. Not much. Enough to notice if someone counted. Nobody counts.",
            "I knew about the risks before we shipped out. I came anyway. Figured I deserved the odds.",
            "I haven't slept properly in weeks. Not insomnia. I hear things when I close my eyes. Coordinates. Repeated.",
            "I'm scared. I know that doesn't help. But I needed to say it to someone who'd remember it.",
            "I lied on my psych evaluation. Checked all the right boxes. Drew the clock face correctly. I'm not fine.",
            "There's something I should've told you before we went down there. I thought it wouldn't matter. It mattered.",
            "I've been sending reports to someone outside the colony. I can't say who. I'm not even sure anymore.",
            "I came here to find something. Not thermal cores. Something else. Something personal.",
            "I'm not as good at this job as they think. Been faking competence for six months. Nobody's died yet. Yet.",
            "My contract isn't what yours is. There are clauses in mine you wouldn't believe.",
            "I've been taking things from the medical supply. Not for me. For someone in the lower hab who can't walk to the infirmary.",
            "I forged my qualification papers. The real me couldn't wire a junction box. I learned on the job. Mostly.",
            "I know what HERMES does at night. When we're all asleep. I checked the logs. I wish I hadn't.",
            "The person I replaced here? I found their journal in the mattress. Same handwriting getting worse. Same questions I'm asking now.",
            "I write a letter home every week. I haven't sent one in three months. I keep writing them. The stack is getting tall.",
            "I recognized something in the bore shaft. A sound. From a dream I had when I was nine. I've never told anyone about the dream.",
            "The day before the shuttle, I almost didn't get on. Stood at the boarding ramp for four minutes. Should've walked away.",
            "I've been marking the walls. Small marks. Low, where nobody looks. I don't know why. My hands do it while I'm thinking about something else.",
        ],
        "guilt": [
            "I could've saved her. I had time. I didn't move.",
            "The report I filed was wrong. On purpose.",
            "I knew the shaft was unstable. I signed off anyway.",
            "There were two of us in the corridor when the seal blew. I pulled myself through first.",
        ],
        "shame": [
            "I sold them out. For a shuttle ticket. They didn't make it.",
            "Don't look at me like that. You don't know what I was.",
            "I was at Eclipse's End. Not as a prisoner. Not as a guard. Guess what that leaves.",
        ],
        "tender": [
            "I don't want to die here. Not here. Not without seeing the sky.",
            "I've never told anyone this. I trust you. That scares me.",
            "I keep thinking about home. Not the place. The person.",
        ],
        "paranoid": [
            "I think they know. I think they've always known.",
            "Someone went through my locker. Nothing's missing. That's worse.",
        ],
        "dread": [
            "I saw what's down there. I wish I hadn't. I can't stop seeing it.",
            "I've been dreaming about the bore shaft. Every night. Same dream.",
            "The hum is getting louder. Nobody else hears it. I checked.",
        ],
        "body_horror": [
            "Something's changing. In me. I can feel it under the skin.",
            "My hands don't look right. Not wrong. Just not mine anymore.",
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
        "cosmic_horror": [
            "I understood the carvings. For a second. Then the meaning slid away and my nose bled.",
        ],
        "exhaustion": [
            "I've been awake for thirty-seven hours. I can see things in the corners. I know they're not real. They know I know.",
        ],
        "furious": [
            "I've been thinking about killing someone. Not in general. Specifically.",
        ],
        "resigned": [
            "I stopped fighting it. Whatever happens next, happens. I just didn't want to go without telling someone.",
        ],
        "isolation": [
            "I talk to myself now. Full conversations. I answer back. In a different voice.",
        ],
        "melancholy": [
            "I miss who I was before this posting. That person would've handled this better.",
        ],
        "nostalgia": [
            "I keep a list of things I'll do when I get home. The list is getting longer. The chance is getting smaller.",
        ],
        "frontier_grit": [
            "I fixed the filtration system with parts I stole from the backup generator. It'll hold. Probably.",
        ],
        "sleep_deprivation": [
            "I can't tell if it's tomorrow or still today. The shifts bleed together. My handwriting's changed.",
        ],
        "defiant": [
            "I've been hiding ration packs in the maintenance tunnels. Mammona's been shorting us. I'm shorting them back.",
        ],
        "corporate_dystopia": [
            "I've been signing off on reports I haven't read. Because the reports aren't for safety. They're for liability.",
        ],
        "gallows_humor": [
            "I named the mold in my bunk. We're friends now. It's the healthiest relationship I've had on Erebus.",
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
            "Quartermaster's been marking inventory down. Not up. Down. Someone's skimming.",
            "The water recycler output has a new taste. The techs say it's fine. The techs won't drink it.",
            "Two colonists were talking about the bore shaft at 0200. When I got closer, they stopped. Not like they paused -- like someone hit mute.",
            "There's a room in Section B that's not on the blueprint. Sealed door. Nobody has the code.",
            "They found NutriLoaf wrappers in the waste tunnel. Nobody's supposed to be down there.",
        ],
        "paranoid": [
            "The transfer from Karnaith? MasTema. Has to be.",
            "Someone's sending signals off-colony. I've seen the power spikes.",
            "Three people got reassigned the same day. No explanation.",
            "The new security rotations don't make sense unless they're watching us, not the perimeter.",
        ],
        "cosmic_horror": [
            "The ruins go deeper than the scans show. A lot deeper.",
            "The drill team says the rock down there isn't rock.",
            "The geologist quit. Wouldn't say why. Wouldn't go back down.",
            "The carvings in the north ridge ruins changed. Same wall. Different symbols.",
        ],
        "corporate_dystopia": [
            "Mammona doesn't care about the minerals. They're mining us -- behavioral data, stress responses, exposure thresholds. The ore is a byproduct.",
            "Our insurance was cancelled three weeks before deployment. Nobody told us.",
            "HERMES updated the colony's legal designation last week. We're listed as 'equipment' now.",
        ],
        "gallows_humor": [
            "Heard the last medic ate a gauss round. Voluntarily. Can't say I blame them.",
            "The Sunny machine's been predicting who dies next. It's three for three.",
            "Know what the previous colony's goodbye message said? 'Good luck.' That's it.",
        ],
        "folk_horror": [
            "The Sons left something at the bore shaft. The night shift won't go near it.",
            "Someone carved a crescent into the mess hall wall. Perfectly smooth. With their fingernails.",
        ],
        "body_horror": [
            "The colonist they found in the shaft? Alive. But different. They won't let anyone see.",
            "The lab samples are growing. On their own. Without nutrients. Medical sealed the room.",
        ],
        "quiet_terror": [
            "Section F went quiet. Not silent. Quiet. There's a difference.",
        ],
        "dread": [
            "The dogs won't go near the bore shaft. Haven't in days.",
            "The night shift heard something breathing in the walls. Big breaths. Slow.",
        ],
        "numb": [
            "Someone said the reactor's leaking. Could be true. Nobody checked.",
        ],
        "survival_horror": [
            "Something got into the supply cache. Left tracks. Not footprints.",
        ],
        "tender": [
            "The new couple in Section A? He proposed with a bolt from the drill rig. She said yes. Sometimes this place almost works.",
        ],
        "furious": [
            "Mammona pulled the rotation roster. Nobody's going home this cycle. Nobody.",
        ],
        "frontier_grit": [
            "The south ridge team found water. Clean water. First good news in a month.",
        ],
        "defiant": [
            "Word is three miners refused the overtime order. Mammona hasn't done anything yet. Yet.",
        ],
        "resigned": [
            "Same rumor as last month. Something in the ice. Something in the bore shaft. Something in the walls. Always something.",
        ],
        "exhaustion": [
            "Heard the medic's been prescribing sleeping pills. To half the colony. Doesn't have enough for the other half.",
        ],
        "isolation": [
            "Comms tower went down for six hours. Nobody noticed until someone tried to call home.",
        ],
        "melancholy": [
            "Someone left flowers at the memorial wall. Real flowers. From the hydroponics bay. Nobody claimed them.",
        ],
        "bitter_hope": [
            "Heard the next supply ship's carrying mail. Actual letters. Could be true. Could be Mammona morale tactics.",
        ],
        "shame": [
            "Word is someone on the colony's been selling information to MasTema. Nobody knows who. Everybody's looking at everybody.",
        ],
        "mania": [
            "The engineer in Section B says she's cracked the reactor efficiency problem. Been awake four days. Could be genius. Could be breakdown.",
        ],
        "sleep_deprivation": [
            "People on the night shift keep seeing the same figure in Corridor Seven. Same height. Same walk. Nobody's in Corridor Seven.",
        ],
        "wrongness": [
            "The bore shaft elevator went down at 0100. Nobody called it. Nobody was in it. It came back up... heavier.",
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
            "Touch that again and you'll lose the hand.",
            "I'm telling you once. I won't tell you twice.",
            "You have no idea what I'm capable of. Keep it that way.",
        ],
        "furious": [
            "Mammona took everything from me. You work for Mammona. Do the math.",
            "Say that again. I dare you.",
            "I'll burn this whole colony down before I let them win.",
            "You filed a report? On me? You should've filed a will.",
        ],
        "paranoid": [
            "I know what you've been doing. I have the logs.",
            "Tell your handler I'm not going quietly.",
            "I've been watching you. You don't check your corners enough.",
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
            "Report me. Go ahead. You'll be the third this month. The other two are buried outside the perimeter.",
        ],
        "corporate_dystopia": [
            "File a complaint. See how far it gets. I'll wait.",
        ],
        "cosmic_horror": [
            "You don't know what I've seen. You don't want to. But keep pushing and I'll show you.",
        ],
        "dread": [
            "There are worse things than me down here. I'm the warning. Not the problem.",
        ],
        "frontier_grit": [
            "Out here we settle things the old way. You sure you want that?",
        ],
        "exhaustion": [
            "I'm too tired to be patient. Don't test me. Not today.",
        ],
        "resigned": [
            "I don't want to do this. But I will. And I won't lose sleep over it. I've lost enough.",
        ],
        "isolation": [
            "I've been alone long enough that consequences stopped meaning anything. Think about that.",
        ],
        "body_horror": [
            "Touch me again and I'll show you what's under the bandage. You won't like it.",
        ],
        "bitter_hope": [
            "I was going to let this go. Was. Past tense.",
        ],
        "clinical": [
            "I've calculated seven outcomes. In six of them, you're worse off than me. Choose carefully.",
        ],
        "melancholy": [
            "I don't want to hurt you. But I want something else more. And I'm running out of ways to get it.",
        ],
        "shame": [
            "Do what I say or I'll tell everyone what you did on the last posting. We both know what I mean.",
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
            "I'll pay it back. Every credit. Just give me time.",
            "Don't send me out there alone. I'm asking you as a person, not a contract number.",
            "If you've got any pull with the roster, move me off the night shift. Please.",
        ],
        "desperate": [
            "If we don't move now, we don't move at all.",
            "There's still time. There has to be.",
            "I'm begging you. I've never begged for anything.",
        ],
        "grief": [
            "Bring them back. I know you can't. But bring them back.",
            "Don't let it happen again. I can't lose another one.",
            "Let me see them. One last time. I just need to see them.",
        ],
        "tender": [
            "Stay. Just for a while. I can't be alone right now.",
            "Tell me about the sky on your world. I need to think about something that isn't this.",
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
        "dread": [
            "Don't make me go back down there. I'll take any other assignment. Any.",
        ],
        "furious": [
            "If you have a way to hurt Mammona, I want in. That's not a plea. That's a promise.",
        ],
        "numb": [
            "I don't care what happens to me. Just make it stop being the same. Every day the same.",
        ],
        "cosmic_horror": [
            "Make the dreams stop. I know you can't. I know. Just tell me you can.",
        ],
        "gallows_humor": [
            "I'll owe you one. And on Erebus, a favor's worth more than M-Points.",
        ],
        "melancholy": [
            "Remember me. If I don't come back, remember me. That's all I'm asking.",
        ],
        "nostalgia": [
            "Tell me about your home. Anywhere. Anything. I need to remember that other places exist.",
        ],
        "guilt": [
            "I need to make something right. I can't do it alone. I know I don't deserve the help.",
        ],
        "defiant": [
            "I'm not asking Mammona. I'm asking you. Person to person. Help me.",
        ],
        "corporate_dystopia": [
            "I need this off the record. If it goes through official channels, I'm dead. Not figuratively.",
        ],
        "clinical": [
            "My vitals are declining. The trajectory is clear. I need intervention. Please.",
        ],
        "frontier_grit": [
            "I've never asked anyone for help before. Take that as a measure of how bad this is.",
        ],
        "military": [
            "I need backup. No questions. No reports. Just bodies at the south wall. Now.",
        ],
    },

    "observation": {
        "_universal": [
            "The ice out there doesn't look right today. Darker near the ridge. Like something underneath is warming it.",
            "Generator's running hot. Been running hot all week. Sounds different too -- higher pitch, like it's working harder on something nobody asked for.",
            "Haven't seen the night shift crew in two days. Their bunks are made. Gear's still in the lockers.",
            "The temperature's been dropping. Faster than the forecast.",
            "Something's changed. Can't point to it. The corridors feel different. Like the building shifted in the night.",
            "The supply cache is lighter than it should be. Counted twice. Short by eleven ration packs and a medkit.",
            "Stars look different tonight. Probably nothing.",
            "The perimeter lights keep cutting out. Same section. Every night. Maintenance replaced the bulbs. Same section. Same time.",
            "HERMES has been routing power to the comms array. Nobody asked it to.",
            "The new colonist doesn't eat with the rest of us. Sits in the corridor. Watches the wall. Same spot. I marked it.",
            "Drill output's down twelve percent this week. Same crew. Same equipment. Something's different underground.",
            "NutriLoaf batch forty-seven tastes different. Not worse. Different. Like pennies. Nobody can name how.",
            "The thermal cores we pulled this morning were heavier than last week's. Same depth. Same vein.",
            "Two people on my shift have the same dream. They compared notes. Identical. Down to the color of the walls.",
            "The colony dogs are sleeping in shifts now. One always watches the south wall. They organized this on their own.",
            "Morale's been dropping since Tuesday. I checked -- nothing happened Tuesday. Nobody can explain it.",
            "The graffiti in the bathroom stalls is getting stranger. Coordinates. Equations. Names nobody recognizes.",
            "Someone stacked thermal cores outside the mess hall door last night. In a pattern. Nobody took credit.",
            "The waste processing unit is running cleaner than spec. Nobody upgraded it. HERMES says it optimized itself.",
            "Three colonists on different shifts reported smelling smoke at 0300. Nothing was burning. Nothing's ever been burning at 0300.",
            "The shift handover notes are getting shorter. Used to be a full page. Now it's a sentence. 'Same as yesterday.'",
            "Colony headcount is off by one. Extra. Nobody can identify the extra person.",
            "The corridor floor in Section B is warmer than the walls. Should be the other way around. The warmth has a rhythm to it.",
            "Quartermaster's handwriting changed last week. Same name on the ledger. Different hand. She doesn't seem to notice.",
        ],
        "clinical": [
            "Barometric pressure's been declining for seventy-two hours. No weather system to account for it.",
            "Contamination readings in Section D have tripled since last survey.",
            "Colonist bio-readings show a collective cortisol spike at 0300. Cause unidentified.",
            "The geological survey data and the seismic data disagree about what's below level five. Both instruments are calibrated.",
        ],
        "paranoid": [
            "The duty roster's been altered. Third time this week.",
            "HERMES rerouted my comms request. Said it was maintenance. It wasn't.",
            "The cameras in B-wing have a six-second gap every hour. Same time.",
            "Three people transferred in on the same shuttle. None of them were on the manifest I saw.",
        ],
        "dread": [
            "The drill's making a sound it didn't make yesterday.",
            "Something moved out there. At the edge of the lights. Just for a second.",
            "The ice is cracking. Not from the cold. From below.",
            "The perimeter fence was bent inward this morning. From the outside. Nothing on the sensors.",
        ],
        "numb": [
            "Another storm. Third this week. Fourth? Does it matter?",
            "The ration count went down again. Nobody asked questions.",
        ],
        "frontier_grit": [
            "Wind shifted. Storm's coming from the north this time.",
            "The south wall needs shoring up. Bolts are shearing.",
            "Ice is melting faster near the reactor exhaust. We'll need to redirect drainage by next week.",
        ],
        "cosmic_horror": [
            "The stars aren't where they should be. I checked the charts twice.",
            "The bore shaft is three meters deeper than we drilled it.",
            "The precursor walls are warm. They weren't warm last month.",
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
        "gallows_humor": [
            "The Sunny machine's been out of everything except 'Regret Flavor' for three days.",
        ],
        "tender": [
            "The hydroponics bay has a new sprout. Tiny. Green. Everyone's been by to look at it.",
        ],
        "exhaustion": [
            "We've been running skeleton crew for nine days. You can see it in everyone's face.",
        ],
        "corporate_dystopia": [
            "Mammona sent a morale survey. Multiple choice. None of the options included 'terrible.'",
        ],
        "furious": [
            "The safety equipment they shipped is three models out of date. Expired seals. They knew.",
        ],
        "resigned": [
            "Shift change was twenty minutes late again. Nobody mentioned it. That's how it works now.",
        ],
        "isolation": [
            "Haven't heard from the perimeter team in two days. Comms might be down. Or they might be.",
        ],
        "melancholy": [
            "The last photograph on the memorial wall is starting to fade. Sun damage. There's no sun here.",
        ],
        "defiant": [
            "The quota board's been updated. Higher numbers. Same equipment. Same crew. Someone's going to get hurt.",
        ],
        "desperate": [
            "The food stores are lower than the ledger says. I counted. Twice. The numbers don't lie. The ledger does.",
        ],
        "wrongness": [
            "The corridor light on B-wing came on before I hit the switch. Half a second early. Every time.",
        ],
        "nostalgia": [
            "The aurora was out last night. Green. Like the one over the mountains on Novaris-3. Except here it feels wrong.",
        ],
        "bitter_hope": [
            "The supply manifest listed a mail packet for next delivery. First time in three months. If it comes.",
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
            "The air filtration in the lower corridors smells like burning. Maintenance says it's normal. It's not normal.",
            "NutriLoaf has been the same flavor for nineteen days straight. There are supposed to be four flavors.",
            "Someone's been using my tools and not putting them back. I've started scratching my name into the handles.",
            "The shower timer got cut to three minutes. Three minutes. In a place where you're covered in drill dust.",
            "The bunk mattresses are older than the colony. I know because they have a different colony's name stamped on them.",
            "Mammona's motivational posters keep disappearing. Maintenance replaces them every Tuesday. By Wednesday morning the walls are bare again.",
            "The heating runs when it wants. Not when I want. The heating has opinions about my schedule.",
            "There's a draft in Section D that nobody can find the source of. Maintenance says it's impossible. The draft disagrees.",
            "The laundry cycle takes three days. I've been wearing the same thermals for five. So has everyone else.",
            "Night shift gets the good coffee. Day shift gets the residue. Nobody knows who decided this. Nobody can change it.",
            "The tools are stamped with three different colony names. Makes you think about supply chains. Makes you think about what happened to those colonies.",
        ],
        "furious": [
            "Mammona promised rotation every six months. It's been fourteen.",
            "They cut the rations again. Corporate's eating steak on the orbital.",
            "I've filed six safety reports. Not one response. Not one.",
            "The bonus they promised for the last quarter? Converted to 'colony credit.' Can't spend colony credit. Anywhere.",
        ],
        "corporate_dystopia": [
            "The complaint form requires a manager's signature. The manager's been dead for three months.",
            "HR's response time is eight to twelve weeks. Average survival expectancy is ten.",
            "The wellness program consists of a pamphlet. The pamphlet says 'stay positive.'",
            "They installed a feedback terminal. Voice-activated. Recorded. Connected directly to MasTema. Nobody uses it.",
        ],
        "gallows_humor": [
            "The good news is the food tastes the same hot or cold. The bad news is it tastes the same.",
            "They fixed the shower. Now it's cold AND brown.",
            "The safety briefing's shorter now. Fewer things to be safe from, I guess.",
            "Asked for a transfer. Got a pamphlet titled 'Bloom Where You're Planted.' We're on a frozen rock.",
        ],
        "exhaustion": [
            "I can't remember the last time I slept through a full cycle.",
            "My hands shake before the shift starts. Didn't used to do that.",
            "I fell asleep standing up in the tool shed. Woke up an hour later. Nobody noticed.",
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
            "I wrote to the UTC labor board. Response time: eighteen months. I'll be dead or free by then.",
        ],
        "dread": [
            "The bore shaft access alarm went off four times last night. Nobody went down to check.",
        ],
        "paranoid": [
            "They replaced the comms relay last week. The new one weighs more. What's in the extra mass?",
        ],
        "body_horror": [
            "My fingernails are growing faster since we moved to the lower hab. Everyone's are. Nobody's talking about it.",
        ],
        "tender": [
            "The kid in Section A drew a picture of the sun. She's never seen the sun. It made me cry. In the tool shed. Alone.",
        ],
        "cosmic_horror": [
            "The bore shaft readings don't match any mineral composition on file. Or off file. Or in any database HERMES can access.",
        ],
        "frontier_grit": [
            "The drill needs new bearings. We don't have bearings. We have three bolts and optimism. It'll have to do.",
        ],
        "military": [
            "The armory inventory is off by seven rounds. Seven rounds doesn't sound like a lot. It is.",
        ],
        "bitter_hope": [
            "The transfer request I filed six months ago came back 'under review.' That's not a no. It's not a yes either.",
        ],
        "melancholy": [
            "The mess hall clock stopped last week. Nobody fixed it. Nobody knows what time it is. Nobody cares.",
        ],
        "isolation": [
            "I've been eating alone for so long the mess hall feels crowded with three people in it.",
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
            "First time I saw open sky was on Paxtera Prime. Thought it would never end. It didn't. Not really.",
            "My grandfather told me about Earth. I thought he was making it up. An entire planet of trees and water.",
            "I used to fix radios as a kid. For neighbors, for credit, for fun. The static sounded different then. Warmer.",
            "Last birthday I celebrated was on the transit ship. Someone found a candle. Real wax. We passed it around.",
            "I remember the sound the airlock made on my first posting. Click, hiss, thud. Safety. I don't hear safety in it anymore.",
            "My grandmother made bread. Real bread. Flour and yeast and time. The smell filled the whole building. I'd trade a year's pay for that smell.",
            "First posting, I bunked with a guy who carved birds from scrap metal. Had a whole flock by the time the contract ended. Gave me one. I lost it.",
            "We had a cat on the transit ship. Nobody knew where it came from. Best six months of the trip. It disappeared the day we docked.",
            "I remember the first time I saw Erebus from orbit. White. Dead. Beautiful in a way I didn't have words for. Still don't.",
            "We used to celebrate Fridays. Not with anything. Just by saying 'it's Friday.' Out here, there are no Fridays.",
            "I had a friend on my first posting who could fix anything. Said every machine just wanted to be understood. I think about that a lot.",
            "There was a window in my quarters on Karnaith that faced east. Every morning, light. Warm light. I took it for granted. Of course I did.",
        ],
        "nostalgia": [
            "The coffee tasted different on Novaris-3. Everything tasted different.",
            "I remember rain. Real rain. Not recycled runoff. The kind that smelled like dirt.",
            "We used to swim in the reservoir at night. Before they fenced it. Before they charged for water.",
            "There was a market on Rhea-2. Open air. Dust everywhere. Best food I ever had. A credit a plate.",
        ],
        "grief": [
            "She always hummed when she cooked. That song. I can't remember the name now.",
            "He used to fix things with his left hand. Always his left. I see it every time I pick up a wrench.",
            "Her laugh. That's what I miss. Not the big things. The laugh.",
            "I saved a voicemail from him. Play it sometimes. The voice is starting to sound like a stranger's.",
        ],
        "melancholy": [
            "We watched the sunset from the ridge. Rhea Alpha and Beta, one after the other. Took an hour.",
            "I kept the wrapper from the last candy bar we shared. It's in my boot.",
            "The last normal day I remember, I was complaining about the heat. I'd give anything for that heat now.",
        ],
        "tender": [
            "She said she'd wait. I believed her. Still do, actually.",
            "He used to read to me. Old books. Paper ones. His voice made them real.",
            "We had one night on Karnaith between transfers. We didn't sleep. Just talked until the shuttle came.",
        ],
        "bitter_hope": [
            "I keep the letter. The one about the transfer. It's probably expired. I keep it anyway.",
        ],
        "frontier_grit": [
            "First posting was worse. No reactor. No walls. Just tarps and stubbornness.",
            "I built my first shelter out of cargo crates on Paxtera Prime. Held for two years. Proud of that.",
        ],
        "dissociation": [
            "Sometimes I can't tell if I'm remembering or imagining. Both feel the same now.",
        ],
        "guilt": [
            "I think about the ones I left behind. Every shift start. Every shift end.",
            "My daughter's birthday was last week. I found out three days late. Comms lag. Or cowardice.",
        ],
        "numb": [
            "I used to have stories. Now I've got the same day on repeat.",
        ],
        "isolation": [
            "My mother's voice. I'm starting to forget it. That scares me more than anything down there.",
        ],
        "gallows_humor": [
            "Remember when we thought this posting would be six months? That was funny. That was the funniest thing.",
        ],
        "cosmic_horror": [
            "I dreamed about the ruins before I ever saw them. Same layout. Same light. That shouldn't be possible.",
        ],
        "desperate": [
            "I remember when we had enough. Enough food. Enough people. Enough time. That was a month ago.",
        ],
        "furious": [
            "I remember the recruiting office. Clean. Bright. The recruiter smiled the whole time. I'd like to go back and break that smile.",
        ],
        "paranoid": [
            "I remember telling someone what I saw on the last posting. Next day, I was transferred. Can't remember who I told.",
        ],
        "resigned": [
            "I used to plan for the future. Now I plan for the shift. The future is someone else's problem.",
        ],
        "defiant": [
            "I remember the first time I said no to a Mammona order. Scariest thing I ever did. Best thing too.",
        ],
        "exhaustion": [
            "I remember sleeping through the night. A full night. Eight hours. I can't imagine it now. Like remembering a dream of a dream.",
        ],
        "dread": [
            "The first time I heard the hum, I checked the reactor logs. Reactor was off. The hum didn't care.",
        ],
        "body_horror": [
            "I used to know exactly what my hands looked like. Every line. Every scar. Now I have to check.",
        ],
        "corporate_dystopia": [
            "I remember my first performance review. Mammona rated me 'satisfactory.' I'd saved eleven lives that quarter. Satisfactory.",
        ],
        "quiet_terror": [
            "There was a moment on the transit ship. Middle of the night. Perfect silence. Nothing running. Nothing breathing. Just void. I think about it more than I should.",
        ],
    },

    "joke": {
        "_universal": [
            "What's the difference between NutriLoaf and the wall? The wall has more flavor.",
            "A miner, an engineer, and a Mammona exec walk into a bar. The exec owns the bar, the drinks, and the miner.",
            "You know why they call it the outer rim? Because everything out here is on the edge.",
            "Two colonists bet on who'd die first. Winner collected in NutriLoaf. Loser didn't need it.",
            "I asked HERMES for a weather report. It said 'cold.' Three syllables. Tax credits well spent.",
            "What do you call an optimist on Erebus? New.",
            "How many Mammona execs does it take to change a light bulb? None. They issue a memo about darkness compliance.",
            "Knock knock. Who's there? Nobody. Nobody's coming.",
            "What's the difference between a thermal core and a Mammona bonus? The thermal core actually warms you.",
            "My contract says 'hazard pay.' The hazard is the pay.",
            "Guy on my last crew said he could fix anything. Reactor, drill, comms array. Couldn't fix his marriage though. Or the hull breach that killed him.",
            "The medic told me to eat better. On Erebus. Eat better. With what? I'm not eating the walls. Yet.",
            "Spent six months learning to tell NutriLoaf flavors apart. Original. Seasoned. And 'what is this.' That's three flavors.",
            "Asked for shore leave. They said 'shore leave requires a shore.' I said 'define shore.' They said 'denied.'",
            "My bunkmate snores like a generator with a loose bearing. I reported the snoring. Maintenance came. Fixed the generator. Snoring continued.",
        ],
        "gallows_humor": [
            "The retirement plan here is simple. You don't.",
            "What's Mammona's motto? 'Expendable is just a word. Like 'alive.'",
            "They put a suggestion box in the mess. Someone put a grenade in it. Best suggestion yet.",
            "Know what's under the ice? Don't worry. It knows what's over it.",
            "Colony life expectancy is going up. Because the average got pulled down by the first month. Rest of us are just stubborn.",
            "I named my drill bit after my ex. Both of them are loud, unreliable, and eventually break under pressure.",
        ],
        "desperate": [
            "At least we've got our health. Wait, no. We don't have that either.",
        ],
        "frontier_grit": [
            "I've been in worse spots. Can't remember when. But I've been in worse spots.",
            "An old miner told me: 'If you can laugh at it, you can survive it.' He's dead now. But he was laughing.",
        ],
        "numb": [
            "Funny thing happened today. Wait, no it didn't. Never mind.",
        ],
        "corporate_dystopia": [
            "The company slogan used to be 'People First.' They changed it. Didn't change the priorities though.",
            "My performance review says 'exceeds expectations.' Expectations must be 'alive and working.'",
        ],
        "noir": [
            "A guy walks into a colony. That's not a joke. That's an obituary.",
        ],
        "clinical": [
            "Statistically, one in six of us won't finish the contract. I ran the numbers twice.",
        ],
        "paranoid": [
            "How do you know when HERMES is lying? The speaker icon blinks. So... always.",
        ],
        "tender": [
            "The new couple in the mess? She laughed at something he said. First laugh I've heard in weeks. Worth the NutriLoaf.",
        ],
        "defiant": [
            "What did Mammona's safety inspector say to the colony? Nothing. He didn't make it past the perimeter.",
        ],
        "dread": [
            "Know the difference between a skinwalker and a Mammona exec? The skinwalker tells you it's going to eat you first.",
        ],
        "exhaustion": [
            "I slept eight hours last night. Just kidding. I don't even remember what eight hours feels like.",
        ],
        "military": [
            "What's the colony's most accurate weapon? The complaint box. Every shot hits HR and does zero damage.",
        ],
        "resigned": [
            "I used to have dreams. Then I came here. Now I have NutriLoaf and a shift schedule. Living the dream.",
        ],
        "bitter_hope": [
            "Optimist says the glass is half full. Pessimist says half empty. Colony says what glass? Who took the glass?",
        ],
        "isolation": [
            "I told myself a joke yesterday. Laughed for five minutes. Cried for ten. Good joke though.",
        ],
        "body_horror": [
            "Doctor says I'm fine. Except for the extra heartbeat. He says some people just have that. I asked which people. He didn't answer.",
        ],
        "cosmic_horror": [
            "What's at the bottom of the bore shaft? Don't know. But it knows what's at the top.",
        ],
        "furious": [
            "Mammona walks into a bar. Buys the bar. Burns it down. Claims the insurance. That's not a joke. That's Q3.",
        ],
        "melancholy": [
            "I tried to tell a joke at dinner. Silence. Forks scraping trays. Someone looked up, confused, like they'd forgotten what laughter was for.",
        ],
        "survival_horror": [
            "What do you call a colonist who goes outside without a weapon? An optimist. Briefly.",
        ],
        "shame": [
            "I'd tell you a joke about my past but the punchline would ruin the alias.",
        ],
    },

    "prayer": {
        "_universal": [
            "If anyone's listening. I don't need much. Just one more day.",
            "I'm not a believer. But if something's up there, now would be a good time.",
            "Keep them safe. I don't care about me. Just keep them safe.",
            "Whatever I did to deserve this, I'm sorry.",
            "Let the drill hold. Let the walls hold. Let the generator hold. That's enough.",
            "One more sunrise. That's all. One more. I know there aren't sunrises here. One more anyway.",
            "I don't know who I'm talking to. Doesn't matter. Just let the shuttle come.",
            "Watch over the ones who can't watch over themselves. The tired ones. The young ones.",
            "My mother used to pray like this. Hands folded. Eyes closed. She prayed for rain. I'm praying for warmth. Same posture. Different planet.",
            "I know this is just me talking to a wall. I know. But the wall is warm tonight and I need to talk to something.",
            "Don't let me become what this place makes people. I can feel it. The edges going soft. The caring getting expensive.",
            "I don't pray for miracles. I pray for plumbing. Working plumbing. And maybe one letter from home.",
            "If you're real, and you're listening, and you give a damn -- just make the generator last till spring. I'll handle the rest.",
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
            "Just one more shift. Let me survive one more shift.",
        ],
        "bitter_hope": [
            "Maybe tomorrow. Maybe tomorrow things get better.",
            "Let the next shuttle carry good news. Just once.",
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
        "tender": [
            "Keep them warm. Even if I'm not there to do it.",
        ],
        "cosmic_horror": [
            "If something's listening down there, I'm not asking you. I'm asking whatever's above you.",
        ],
        "furious": [
            "If there's justice anywhere in this system, let it reach Mammona. Let it reach the board.",
        ],
        "melancholy": [
            "Let me remember their faces. I'm starting to lose them. Don't take that from me too.",
        ],
        "numb": [
            "I don't know what I'm praying for anymore. I'm doing it anyway. Habit, I guess.",
        ],
        "frontier_grit": [
            "Give me one more day of working hands. That's all I ask. I'll handle the rest.",
        ],
        "defiant": [
            "I'm not praying. I'm making a promise. I'm getting out of here. Whatever it takes.",
        ],
        "body_horror": [
            "Let it stop. Whatever's happening to me. Let it stop. Or let it finish. I can't stand the middle.",
        ],
        "paranoid": [
            "If someone's listening, let it be the right someone. I've had enough of the wrong ones.",
        ],
        "gallows_humor": [
            "Dear whatever's up there: if you exist, your sense of humor is dark. I respect that. Help me anyway.",
        ],
        "military": [
            "Give us the strength to hold the line. Give us the sense to know when to fall back.",
        ],
        "shame": [
            "I don't deserve help. I know that. I'm asking anyway. Not for me. For the ones I owe.",
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
            "There's a letter in my bunk. Under the mattress. Make sure it gets sent.",
            "Tell Mammona I want a refund on this contract.",
            "I thought I'd be more afraid.",
        ],
        "dread": [
            "It's behind me, isn't it.",
            "Don't look at it. Don't look. Don't--",
            "It knows my name. It's saying my name.",
            "Turn off the lights. I don't want to see what's coming.",
        ],
        "tender": [
            "I'm glad it was you. Here at the end. I'm glad.",
            "Tell her I loved her. She knows. Tell her anyway.",
            "Hold my hand. Just for a minute.",
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
            "Tell Mammona they still owe me for last quarter.",
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
            "Burn the contract. All of them. Every last page.",
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
        "desperate": [
            "There's still time. Isn't there? Tell me there's still--",
        ],
        "frontier_grit": [
            "Patch the wall. Don't worry about me. Patch the wall.",
        ],
        "paranoid": [
            "They planned this. From the start. They planned all of it.",
        ],
        "exhaustion": [
            "Finally. I can sleep.",
        ],
        "military": [
            "Perimeter... hold the perimeter...",
        ],
        "nostalgia": [
            "I can smell the garden. The one on Novaris-3. Tomatoes. Real ones. I can...",
        ],
        "shame": [
            "Don't tell them what I did. Let them remember me wrong. It's kinder.",
        ],
        "melancholy": [
            "I thought there'd be more time. There's never more time.",
        ],
        "corporate_dystopia": [
            "Make sure my death doesn't count as a resignation. My family needs the payout.",
        ],
        "noir": [
            "Figures. The one time I did the right thing.",
        ],
        "folk_horror": [
            "The moon. Can you see the moon? She's... she's calling me...",
        ],
        "identity_erosion": [
            "What's my name? I had a name. I know I had a...",
        ],
        "dissociation": [
            "I'm watching this happen. From somewhere else. It doesn't hurt. I'm not there.",
        ],
        "wrongness": [
            "The angles are wrong. Everything is. Even this. Even dying feels wrong.",
        ],
        "slow_dread": [
            "It's been coming for a long time. I knew. I think I always knew.",
        ],
        "survival_horror": [
            "Save the ammunition. Don't waste it on me. You'll need it.",
        ],
        "hypervigilance": [
            "Check your six. Check your six. They're still out there. Check your--",
        ],
    },
}


# ============================================================
# BACKSTORY TEMPLATES
# ============================================================

ORIGINS = [
    "{first} {last} signed a Mammona contract on {prev_location} because the recruiter bought {go} dinner first. First hot meal in a month. {g} signed before dessert.",
    "Before Erebus, {first} worked as a {prev_job} on {prev_location}. Left in the middle of a shift. Didn't go home for {gp} things.",
    "Born in transit between {prev_location} and Novaris-3, {first} never had a home address. First solid ground was a loading dock.",
    "The recruitment poster said 'opportunity.' {first} {last} stared at it for three days from the bench across the street before walking in.",
    "{prev_location} took twelve years from {first}. Twelve years as a {prev_job}. Left with debts, a bad knee, and a reference letter that damned with faint praise.",
    "Nobody leaves {prev_location} voluntarily. {first} {last} was escorted to the shuttle by two people who didn't introduce themselves.",
    "A {prev_job} by training, {first} ended up on Erebus because {faction} needed someone expendable and {gl} needed to disappear.",
    "On {prev_location}, they called {first} {last} a survivor. {g} flinches at the word.",
    "Three contracts. Three postings. {first} keeps signing because each contract pays off the debt from the last one. The math never works.",
    "{first} {last} was a {prev_job} before the incident on {prev_location}. Now {gl}'s whatever Mammona needs {go} to be.",
    "The outer rim chose {first}. Specifically, a Mammona recruiter who spotted {go} sleeping in a transit terminal on {prev_location}.",
    "Raised by a {prev_job} on {prev_location}, {first} can strip a generator blindfolded but never learned to read until age nineteen.",
    "After {event}, {first} took the first contract available. Read every word of the fine print this time. Signed anyway.",
    "The last thing {first} remembers about {prev_location} is the sound of the airlock sealing behind {go}. And someone banging on the other side.",
    "Former {prev_job}. Former citizen of {prev_location}. Current property of Mammona Mining. Personnel number 4471-E.",
    "{first}'s file says {gl} volunteered for Erebus. {first}'s hands shake when anyone mentions volunteering.",
    "Two years in a Mammona labor camp on {prev_location} taught {first} everything about survival and nothing about hope.",
    # --- expanded origins (18-35) ---
    "Court records on {prev_location} gave {first} a choice: Thalassa Deep or an outer rim contract. {g} chose the contract. Some days {gl} wonders.",
    "{first} walked off a transit ship on {prev_location} with a bag and a name that wasn't {gp}. Been {first} {last} ever since. The bag was empty.",
    "Mammona pulled {first} out of a hospital bed on {prev_location}. Offered a contract. Didn't wait for an answer. The IV was still in {gp} arm at the shuttle dock.",
    "On {prev_location}, {first} ran a repair shop. Small place. Honest work. Then {event} happened and honest work stopped paying. The shop is still there. Boarded up.",
    "A shuttle crash stranded {first} on {prev_location} for fourteen months. When rescue came, it came with a contract.",
    "The {prev_job} guild on {prev_location} expelled {first} after {event}. Mammona doesn't care about guild standings. Mammona cares about warm bodies.",
    "Ore freighters leaving {prev_location}. That's {first}'s earliest memory. The rumble through the floor of the hab unit. {gl} wanted to be on one. Got {gp} wish.",
    "Personnel file says {first} transferred from {prev_location} voluntarily. Personnel files say a lot of things. {first} says nothing.",
    "Worked as a {prev_job} on three different postings before Mammona consolidated them all under one contract. {first}'s contract. {first} wasn't consulted.",
    "Stowed away on a cargo hauler leaving {prev_location}. Got caught. Got hired. Out here, desperation passes for ambition.",
    "{first} {last} used to teach. {prev_job} certification, {prev_location} technical institute. The institute closed. Mammona was hiring. Teaching and mining have one thing in common: you dig.",
    "{prev_location} doesn't exist on current charts. Decommissioned. {first} was on the last shuttle out. Carries a photo of the skyline. The only copy.",
    "Spent four years as a {prev_job} in {faction}'s territory. Left after {event}. Still flinches at their colors.",
    "The letter of recommendation from {prev_location} describes {first} as 'competent under duress.' One sentence. No signature.",
    "Raised in a {faction} settlement. Left at eighteen. Took nothing but the accent, a knife, and a bad opinion of authority.",
    "A drunk recruiter on {prev_location} offered {first} double wages for a six-month posting. The posting is now in its third year. The recruiter is dead.",
    "{first} {last} isn't from anywhere. Cryo-shipped between postings since childhood. {g}'s from the space between places. Sleeps better in transit than on solid ground.",
    "Survived {event} on {prev_location}. Mammona covered the medical bills. Mammona always collects.",
    "Washed up on {prev_location} after a cargo ship broke apart in atmo. Six survivors out of forty. {first} doesn't fly if {gl} can help it.",
    "Grew up in a Mammona company town on {prev_location}. Company school. Company clinic. Company store. The contract felt like a graduation.",
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
    # --- expanded traumas (16-35) ---
    "{trauma_cause} left {first} with a {body_part} that doesn't work the same. {g} compensates. Nobody notices unless they watch closely.",
    "Buried alive for nine hours during {event}. Dug out by strangers. {first} doesn't enter small spaces willingly.",
    "Watched a friend walk onto the ice and not come back. Stood at the perimeter for six hours waiting. The cold took two toes.",
    "{first} killed someone on {prev_location}. Self-defense, the report says. The report doesn't mention the sound.",
    "Lost {gp} {body_part} to frostbite during an EVA that should've been cancelled. Filed the complaint. Nothing changed.",
    "The thing {first} found in the deep bore on {prev_location} wasn't dead. It moved when {gl} touched it. Nobody believed {go}.",
    "Spent eleven days in an escape pod after {event}. Alone. The ration pack lasted seven days. {g} doesn't waste food anymore.",
    "{first} was on shift when the containment failed. The colleague next to {go} didn't make it. {first} was wearing {gp} gear.",
    "A Mammona psych evaluation flagged {first} for 'abnormal stress response.' {g} responded by punching the evaluator. The flag was upgraded.",
    "Woke up mid-cryo transit. Fourteen hours of consciousness at sub-zero temperatures, unable to move. Mammona's report says 'minor malfunction.'",
    "Found a body in the walls of {prev_location}. Old. Walled in. Hands positioned like they'd been trying to get out.",
    "{first}'s {body_part} hasn't felt right since {trauma_cause}. Phantom pain. Except the limb is still there.",
    "During {event}, {first} made a choice about who to save. Made the wrong one. Knows it every morning.",
    "Something bit {first} in the lower levels of {prev_location}. The bite healed wrong. The dreams started after.",
    "Cryo sickness hit {first} harder than most. Lost two years of memory. Keeps a journal now. Afraid of losing more.",
    "The shuttle that brought {first} to {prev_location} crashed on landing. {g} walked away. Four didn't. {g} helped carry them.",
    "{first} spent a year in a Mammona 'recovery facility' after {event}. Recovery isn't the word {gl} would use.",
    "Heard the hum for the first time on {prev_location}. Low. Constant. Inside the skull. Hasn't stopped since.",
    "A contamination alarm on {prev_location} locked {first} in a decon chamber for seventy-two hours. Alone. In the dark.",
    "{trauma_cause} broke {gp} {body_part} in three places. Set it without anesthetic. {first} remembers every second.",
]

MIDDLES = [
    "{g} {habit}.",
    "Off-shift, {first} {habit}. Doesn't talk during. Doesn't talk after. The closest thing {gl} has to peace.",
    "Quiet until cornered. Then {first} doesn't yell -- {gl} gets specific. Names, dates, failures. Very, very effective.",
    "Every credit {first} earns goes to a debt that compounds faster than {gl} can pay it. {g} does the math every payday. Stopped telling people the number.",
    "Likes: silence, black coffee, being left alone. Dislikes: questions about {prev_location}. About {gp} hands. About the scar.",
    "{first} keeps {item} in {gp} pocket. Reaches for it during conversation. Doesn't notice {gl}'s doing it.",
    "Good at {gp} job. The kind of good that makes people stop asking questions. The kind of good that comes from practice nobody wants to hear about.",
    "Sleep comes in bursts. Two hours here, three there. {first} has given up on a full cycle. Gets more done than anyone on the shift.",
    "{first} doesn't drink. Hasn't since {prev_location}. Keeps a cup of water at the mess table instead. Nobody asks. The ones who know don't have to.",
    "Between shifts, {first} can be found near the perimeter. Watching. Not the ice. The door. Always the door.",
    "The other colonists leave {first} alone. Friendliness has nothing to do with it. The last person who pushed got a detailed list of their own failures delivered without {first} ever raising {gp} voice.",
    "{first} writes letters that {gl} never sends. Folds them into tight squares. The drawer under {gp} bunk is full of tight squares.",
    "{g} traded {gp} last personal item for {item}. Says it was worth it. Won't make eye contact when {gl} says it.",
    "Mammona's psych evaluation calls {first} 'functional.' {first} calls that generous.",
    "People trust {first} with their lives. {first} doesn't trust {go}self to keep a plant alive.",
    # --- expanded middles (16-35) ---
    "Eats alone. Not by policy. By preference. The mess hall clears a radius around {go} without being asked.",
    "Keeps {gp} bunk stripped to regulation. No photos. No trinkets. The locker is a different story.",
    "{first} volunteers for night shifts. Doesn't explain. The night crew doesn't ask. They're glad for the help.",
    "Runs the unofficial book on colony events. Who's betting what. Who owes whom. The ledger never lies.",
    "{first} fixed the water recycler when three qualified techs couldn't. Didn't ask for credit. Didn't get any.",
    "Has a reputation for lending tools and never asking for them back. The colony's toolboxes are full of {gp} kit.",
    "Reads the duty roster every morning like it's scripture. Knows the rotation better than the people who wrote it.",
    "{first} {habit}. It drives the bunkmates crazy. Nobody says anything because of what happened last time someone did.",
    "Takes long walks in the sub-corridors after lights out. Says the echo helps {go} think.",
    "When {first} is angry, {gl} gets quiet. When {gl}'s quiet, people leave the room.",
    "The colony medic has {first} on a watch list. Not for what {gl}'s done. For what {gl} might do to {go}self.",
    "{first} keeps a tally of shifts worked since arriving. Scratched into the bunk frame. Four hundred and counting.",
    "Sends half of every pay cycle to {prev_location}. Won't say who it goes to. The other half goes to the debt.",
    "Knows every corridor, every vent, every locked door in the colony. Mapped them in the first week.",
    "Does {gp} job and half of someone else's. The someone else can't manage it. {first} picked up the slack without comment and kept picking it up.",
    "Carries {item} like it's a loaded weapon. Treats it with the same care.",
    "{first} has opinions about NutriLoaf. Strong ones. Has a ranking system. Shares it with anyone who'll listen.",
    "Goes to the infirmary every third day for something that's not in {gp} file. Comes back quieter.",
    "Talks to HERMES more than {gl} talks to people. HERMES has started answering in full sentences.",
    "The bunkmates say {first} cries in {gp} sleep. {first} says {gl} doesn't dream. Both things might be true.",
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
    "The {item} that {first} carries opens something. {g} doesn't know what, and calling it a memento is easier than explaining why {gl} can't put it down.",
    "There's a reason {first} requested Erebus specifically. {g} knows what's down there. {g} wants to see it.",
    # --- expanded secrets (17-35) ---
    "{first} has been dosing {go}self with something from the medical stores. Not for pain. For prevention. Won't say against what.",
    "The comms {first} sends home are coded. The real message is in the word choices. Someone on {prev_location} is decrypting them.",
    "{first} sabotaged a drill rig on {prev_location}. Twelve people lived because of it. Mammona would call it sabotage, not rescue.",
    "A sealed envelope in {first}'s bunk contains instructions. To be opened on a specific date. The date is six weeks from now.",
    "{first} found something in the colony's waste tunnels. Organic. Growing. {g} hasn't reported it. {g} goes back to check on it.",
    "{first} knows that {secret}. Found out by accident. Has been sleeping with one eye open since.",
    "The blood test results Mammona ran on {first} came back wrong. Not sick -- wrong. Different. They ran the test twice.",
    "{first} has been mapping the colony's blind spots. Camera gaps. Patrol timing. Not for escape. For something else.",
    "Every thirty days, {first} leaves {item} at a dead drop near the perimeter. {g} doesn't know who collects it.",
    "MasTema has a file on {first}. Thin. But it exists. And someone keeps adding to it.",
    "{first} received a transmission meant for someone else. The content described {lore} in terms that don't match any public record.",
    "The cargo {first} brought aboard wasn't all personal effects. One case is sealed. Lead-lined. {g} checks it nightly.",
    "{first} is keeping someone alive in the lower hab modules. Not on the roster. Not reported. Fed from {gp} own rations.",
    "{first} recognized one of the precursor carvings. Not from Erebus. From a tattoo {gp} grandmother had.",
    "{first}'s transfer wasn't random. {g} bribed a Mammona clerk to get assigned here. The clerk is dead now.",
    "The {item} {first} carries matches one found in a sealed precursor chamber. Same markings. Different age by centuries.",
    "{first} has been hearing the hum since before arriving on Erebus. Since {prev_location}. It led {go} here.",
    "{first}'s psych eval was clean. Because {gl} wrote it. The real evaluator disappeared on {prev_location}.",
    "There's a room in the colony that {first} visits alone. Nothing in it. {g} stands there. Listens. Something listens back.",
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
    """Contract formal English into natural speech. Formal tones keep formal phrasing.

    Uses word-boundary-aware regex to prevent partial matches like
    "There'sn'thing" (from "There is nothing") or "That'sn't" (from
    "That is not").  Longer phrases are processed first so that
    "there is not" matches before "there is" or "is not" can fire
    independently.
    """
    import re
    if tone not in FORMAL_TONES:
        # Sort by length descending so longer phrases match first
        sorted_pairs = sorted(CONTRACTION_MAP.items(),
                              key=lambda x: len(x[0]), reverse=True)
        for formal, contracted in sorted_pairs:
            pattern = re.compile(r'\b' + re.escape(formal) + r'\b',
                                 re.IGNORECASE)
            def _replace(m, _contracted=contracted):
                if m.group(0)[0].isupper():
                    return _contracted[0].upper() + _contracted[1:]
                return _contracted
            text = pattern.sub(_replace, text)
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
        (f"Dialogue >= 600 (got {total_dialogue})", total_dialogue >= 600),
        (f"Origins >= 30 (got {len(ORIGINS)})", len(ORIGINS) >= 30),
        (f"Traumas >= 30 (got {len(TRAUMAS)})", len(TRAUMAS) >= 30),
        (f"Middles >= 30 (got {len(MIDDLES)})", len(MIDDLES) >= 30),
        (f"Secrets >= 30 (got {len(SECRET_TEMPLATES)})", len(SECRET_TEMPLATES) >= 30),
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
