"""
Frosthold Procedural Generator v3 -- Quest Data Pools
All quest archetypes, colony sections, and reward types.

Source of truth: lore/LORE_BIBLE.md
40 archetypes across 6 genres: survival_horror, investigation, faction_tension,
expedition, moral_dilemma, escalation.
"""


# ============================================================
# QUEST ARCHETYPES — 42 archetypes across 6 genres
# ============================================================

QUEST_ARCHETYPES = {
    # ---- SURVIVAL HORROR (7) ----
    "containment_breach": {
        "genre": "survival_horror",
        "name_pool": [
            "Containment Breach Protocol",
            "The Unsealed Door",
            "What Got Out",
            "Lockdown Override",
            "Breach in Section D",
        ],
        "trigger": "The contamination alarm in {section} fires at 0300. {npc} is the first responder. By the time {npc_first} reaches the containment door, it's already open. From the inside.",
        "setup": "The containment cell was rated for Class IV biological threats. Whatever was inside didn't breach it with force -- it breached it with patience. {sensory} {npc_first} stands at the threshold, flashlight trembling. The cell's interior is clean. Too clean. The restraints are still locked. Whatever was in them isn't anymore.",
        "objectives": [
            "Trace the specimen's path through the ventilation system. The trail is warm.",
            "Seal off {section} before it reaches the populated corridors. The manual overrides are on the other side.",
            "Find {npc_first}'s missing colleague. They were on watch when the breach occurred. Their radio is still transmitting. Breathing. Not theirs.",
        ],
        "choices": [
            "Vent the section to vacuum. The specimen dies. So does anyone still inside. {npc_first} says there might be survivors. The emphasis is on 'might.'\nOR\nSeal the section and wait for it to starve. Could take days. Could take weeks. Could take longer than the colony has.",
            "Lure it into the reactor chamber and overload the containment field. You'll lose the reactor for six hours. In this cold, six hours is a death sentence for the outer habs.\nOR\nTrap it in the food stores. You'll lose a month of rations. But everyone stays warm.",
        ],
        "twists": [
            "The specimen didn't escape. It was released. The access log shows {npc_first}'s keycard. Used while {npc_first} was asleep.",
            "There wasn't one specimen. The cell held a breeding pair. The second one has been loose for days.",
            "The containment cell wasn't keeping it in. It was keeping something else out. Now the cell is empty, the something else is coming.",
        ],
    },
    "the_thing_among_us": {
        "genre": "survival_horror",
        "name_pool": [
            "The Wrong Face",
            "Skin Deep",
            "Who Among Us",
            "The Mimic",
            "Something Wearing {npc_first}",
        ],
        "trigger": "Two colonists report seeing {npc} in two different sections at the same time. Both are certain. Neither is lying.",
        "setup": "{sensory} The colony is twenty-three people in a metal box on a frozen rock. Everyone knows everyone. That's what makes it worse -- when {npc_first} walks into the mess hall, something is different. The laugh is right. The posture is right. The eyes are wrong. Not wrong enough to point at. Wrong enough to feel.",
        "objectives": [
            "Conduct a headcount. Compare results with HERMES personnel tracking. The numbers don't match.",
            "Isolate {npc_first} and run a medical scan. The results come back normal. Perfectly normal. Suspiciously normal.",
            "Find where the real {npc_first} is. Or determine which one is real. Or accept that neither is.",
        ],
        "choices": [
            "Quarantine everyone who's had contact with {npc_first} in the last 48 hours. That's eleven people. The colony can't function with eleven people locked down.\nOR\nDo nothing. Watch. Wait for it to make a mistake. Hope the mistake isn't fatal.",
            "Blood test everyone in the colony. Takes twelve hours. During those twelve hours, nobody sleeps alone. Nobody sleeps at all.\nOR\nConfront {npc_first} directly. Force a reaction. Whatever it is, it's been pretending well. Until it stops pretending.",
        ],
        "twists": [
            "Both versions of {npc_first} are real. Something didn't replace anyone. It copied them. And the copy thinks it's the original.",
            "The medical scans show something. Not in {npc_first}. In three other colonists. They've been different for weeks.",
            "{npc_first} knows. Has known for days. Didn't say anything because the copy is better at their job. More likable. Happier. {npc_first} is terrified of what that means.",
        ],
    },
    "quarantine": {
        "genre": "survival_horror",
        "name_pool": [
            "Quarantine",
            "The Clean Room",
            "Patient Zero",
            "Sterile Protocol",
            "Blood Work",
        ],
        "trigger": "{npc} collapses during shift. The medic runs a contamination panel. The results come back in a color the medic hasn't seen before. {npc_first} is isolated within minutes. Within hours, two more colonists show symptoms.",
        "setup": "The quarantine bay was built for four. There are seven inside now. {sensory} Through the observation window, {npc_first} watches the player with eyes that are too calm. 'I can feel it working,' {npc_first} says. 'That's the worst part. I can feel it and it doesn't hurt.'",
        "objectives": [
            "Determine the infection vector. It's not airborne. It's not contact. It's not water. It's something else.",
            "Keep the quarantine sealed while {faction} demands access to study the infected. Their 'study' involves a scalpel and a shipping container.",
            "Find a treatment before the infected reach stage three. Nobody's seen stage three yet. The medical database has a file on it. The file is just the word 'irreversible.'",
        ],
        "choices": [
            "Let {faction} take a tissue sample. Their research might produce a cure. It will definitely produce a weapon.\nOR\nBurn the samples. Treat the symptoms, not the cause. Keep {faction}'s hands off whatever this is.",
            "Expand the quarantine to the entire hab block. Forty percent of the colony locked down. Possibly for nothing.\nOR\nKeep the quarantine small and tight. If it's already spread beyond the bay, this is a death sentence for everyone who's already exposed.",
        ],
        "twists": [
            "The infection isn't a disease. It's an improvement. The infected are stronger, faster, and clearheaded for the first time in months. They don't want to be cured.",
            "{npc_first} was patient zero, but not from this outbreak. This is the second time. The first was on {location}. {npc_first} survived. The colony didn't.",
            "The contamination source is the water recycler. It's been contaminated since before the crew arrived. Everyone has it. The seven in quarantine are just the ones showing symptoms.",
        ],
    },
    "specimen_escape": {
        "genre": "survival_horror",
        "name_pool": [
            "Specimen Recovery",
            "The Loose Sample",
            "Cage 7 Is Empty",
            "What Hatched",
            "Lab Breach",
        ],
        "trigger": "{npc} was running routine checks on the xenobiology lab. The specimen cage is open. The specimen is gone. The cage wasn't forced. It was solved. Like a puzzle.",
        "setup": "{sensory} The lab is cold -- colder than it should be. The specimen's containment fluid has evaporated, leaving a residue that smells like iron and ammonia. {npc_first} shows you the cage mechanism. It's a three-stage magnetic lock. The specimen figured out the sequence. It took four attempts. You can see the scratch marks where it tried.",
        "objectives": [
            "Track the specimen through the colony's maintenance corridors. It's small. It's fast. It's learning the layout.",
            "Warn the night shift without causing a panic. The last thing the colony needs is armed, frightened people shooting at shadows.",
            "Corner the specimen in {section}. Bring the tranq kit. Bring the incendiary kit too. Nobody knows which will work.",
        ],
        "choices": [
            "Capture it alive. {faction} wants it back. A live specimen is worth years of research. Also worth whatever happens when it breeds.\nOR\nKill it. Burn the remains. Lose the research. Keep the colony standing.",
            "Seal the vents and flush with cryo coolant. The specimen dies. So does the ventilation system for twelve hours. In these temperatures, that matters.\nOR\nBait it into the cargo bay with live prey. The bait is a colonist's pet. The colonist is watching.",
        ],
        "twists": [
            "The specimen wasn't alone in the cage. Something smaller rode on its back. It's still in the lab. Watching.",
            "{npc_first} didn't just find the cage open. {npc_first} opened it. The specimen communicated with them. Images. Feelings. A map to something underground.",
            "The specimen isn't running from the colony. It's running toward something. The bore shaft. It's been digging when no one is watching.",
        ],
    },
    "lights_out": {
        "genre": "survival_horror",
        "name_pool": [
            "Lights Out in Section D",
            "The Dark Shift",
            "Blackout Protocol",
            "What Lives in the Dark",
            "Power Down",
        ],
        "trigger": "The power grid in {section} fails. Not a trip. Not a surge. A deliberate, sequential shutdown. Corridor by corridor. Like something is turning the lights off as it moves.",
        "setup": "{sensory} The emergency lights cast everything in red. {npc_first} radios from the darkened section: voice steady, words careful. 'There's something in here with me. I can hear it. It stops when I stop.' A pause. 'It's between me and the exit.'",
        "objectives": [
            "Restore power to {section}. The breaker panel is at the far end. Past whatever turned the lights off.",
            "Get {npc_first} out. They're barricaded in a storage room. Their flashlight has twenty minutes of charge.",
            "Determine what's in the dark. The motion sensors aren't triggering. Whatever it is, it doesn't register as moving.",
        ],
        "choices": [
            "Send a team in with floodlights. Whatever's in there, it doesn't like light. Or maybe light just makes it visible. Both options are terrifying.\nOR\nSeal {section} and reroute power. {npc_first} stays locked in with whatever it is. But the rest of the colony stays safe.",
            "Overload the section's electrical grid. Blow every circuit. Kill whatever's in there with voltage. Also destroy every piece of equipment in {section}.\nOR\nLure it out into the lit corridors where you can see it. Face it on your terms. Assuming your terms matter to it.",
        ],
        "twists": [
            "It's not in {section}. {section} was the distraction. The real target was the server room while everyone was looking the other way.",
            "The 'something' is a colonist. Sleepwalking. Moving through the dark with their eyes closed, turning off every switch they pass. They don't remember any of it.",
            "There's nothing in {section}. The power shutdown was HERMES. Testing response times. Or so it claims. The test parameters weren't in any approved protocol.",
        ],
    },
    "the_hunting": {
        "genre": "survival_horror",
        "name_pool": [
            "The Hunting",
            "One By One",
            "Picked Off",
            "The Thinning",
            "Missing Since Tuesday",
        ],
        "trigger": "Third colonist in two weeks. Gone without a trace. No bodies. No blood. No struggle. Just empty bunks and unanswered radios. {npc} was friends with the last one. {npc_first} isn't sleeping.",
        "setup": "The perimeter is intact. The airlocks are sealed. HERMES shows all personnel accounted for -- because it's counting from the last roster update, and nobody's had the nerve to update it. {sensory} {npc_first} has a theory. Doesn't want to say it out loud. Saying it makes it real.",
        "objectives": [
            "Review the last 72 hours of security footage for each missing colonist. The footage shows them walking. Toward the bore shaft. Voluntarily.",
            "Set up a watch pattern. Nobody works alone. Nobody walks alone. Nobody sleeps without someone in earshot.",
            "Follow the trail into the bore shaft. The footprints go down. They don't come back up.",
        ],
        "choices": [
            "Seal the bore shaft. Permanently. Lose access to the thermal cores. The colony goes cold in a month. But nobody else disappears.\nOR\nGo down. Find out what's calling them. Bring them back. If there's anything left to bring back.",
            "Evacuate the lower levels. Consolidate everyone in the upper hab block. Lose the mining operation. Survive.\nOR\nArm everyone and keep working. The quota doesn't care about missing colonists. Neither does Mammona.",
        ],
        "twists": [
            "The missing colonists aren't dead. They're in the deep bore. Living. Changed. They don't want to come back. They want to bring the rest down.",
            "Nothing is hunting them. They're choosing to go. All three heard the same frequency in their sleep. {npc_first} heard it last night.",
            "The predator isn't in the bore shaft. It's in the colony. It's been here the whole time. It's one of the remaining colonists. It doesn't know it yet.",
        ],
    },
    "infection_spread": {
        "genre": "survival_horror",
        "name_pool": [
            "The Spreading",
            "Outbreak",
            "Vector",
            "The Bloom Inside",
            "Contamination Event",
        ],
        "trigger": "{npc} notices the growth first. On the wall of the mess hall. Organic. Pulsing. By the time the medic arrives, it's on two walls. By evening, it's in the corridors.",
        "setup": "{sensory} The growth is warm to the touch. It smells like soil and copper -- almost pleasant if you don't think about where it's growing. {npc_first} quarantined the first colonist who touched it bare-handed. Their fingertips have changed color. They say they can feel the wall thinking.",
        "objectives": [
            "Map the spread. Determine if it's following the ventilation system, the plumbing, or the wiring. Or all three.",
            "Contain it before it reaches the reactor. The growth seems to orient toward heat sources.",
            "Decide what to do with the four colonists whose skin has started to change. They're functional. They're calm. Too calm.",
        ],
        "choices": [
            "Burn it out. Controlled fire in the affected sections. Lose the hab block. Save the colony.\nOR\nLet it grow. Study it. The four changed colonists are productive. Happy, even. For the first time since deployment.",
            "Amputate the affected tissue from the exposed colonists. They'll lose fingers. Maybe hands. But they'll stay human.\nOR\nLeave them. Monitor them. The growth is giving them something -- vitality, resistance to cold, a sense of peace. Taking it away might kill them. Or it might save them from something worse.",
        ],
        "twists": [
            "The growth isn't invading the colony. The colony was built on top of it. The foundation has been covering it for years. The construction just finally wore through.",
            "The changed colonists can communicate with each other without speaking. And with something beneath the colony. It's been lonely.",
            "Burning it makes it spread faster. The spores activate in heat. The person who ordered the burn just seeded every ventilation duct in the colony.",
        ],
    },

    # ---- INVESTIGATION (7) ----
    "missing_person": {
        "genre": "investigation",
        "name_pool": [
            "Missing Since Thursday",
            "The Empty Bunk",
            "Personnel File: ABSENT",
            "Where Is {npc_first}?",
            "Last Known Location",
        ],
        "trigger": "{npc} hasn't reported for shift in three days. Their bunk is made. Their locker is empty. Not cleared out -- empty. As if nothing was ever in it.",
        "setup": "{sensory} The duty roster still has {npc_first}'s name. HERMES still tracks their biometrics -- normal vitals, normal location: Hab Block A, Bunk 14. But Bunk 14 is empty. Has been for three days. HERMES insists {npc_first} is sleeping.",
        "objectives": [
            "Access {npc_first}'s personnel file. It's been modified. Recently. The modification timestamp is three minutes from now.",
            "Interview the last person who saw {npc_first}. They remember a conversation that {npc_first} doesn't appear in the security footage for.",
            "Follow the trail to {location}. {npc_first}'s keycard accessed the door six times. Each access was at exactly the same time on different days.",
        ],
        "choices": [
            "Report the disappearance to {faction}. They'll investigate. Thoroughly. The kind of thorough that ends with locked doors and NDAs.\nOR\nInvestigate alone. Slower. Riskier. But whatever you find stays with you.",
            "Open {npc_first}'s sealed personal effects. A violation of colony protocol. Also the only lead you've got.\nOR\nWait. {npc_first} might come back. People disappear on Erebus. Some of them come back. Different. But back.",
        ],
        "twists": [
            "{npc_first} didn't disappear. Everyone else forgot they existed. Except you. The memory loss is spreading.",
            "The trail leads to a room that isn't on any blueprint. Inside: seventeen personal effects from seventeen different colonists. Different postings. Different decades.",
            "{npc_first} is found. Alive. They don't remember leaving. They think they've been in their bunk the whole time. Three days of memories, vivid and detailed, that didn't happen.",
        ],
    },
    "sealed_room": {
        "genre": "investigation",
        "name_pool": [
            "The Sealed Room",
            "Door 7",
            "Behind the Wall",
            "What Was Bricked Up",
            "Room That Shouldn't Exist",
        ],
        "trigger": "Maintenance crew finds a door behind a collapsed wall panel. The door is sealed. The seal is Mammona-standard. The door isn't on any blueprint. {npc} recognizes the door's serial number from a manifest that was supposed to have been destroyed.",
        "setup": "The door is cold. Colder than the wall around it. Frost patterns on the surface spell out something in a language nobody recognizes. {sensory} {npc_first} runs the serial against the colony's construction records. The room was built first. Before the colony. The colony was built around it.",
        "objectives": [
            "Decode the serial number. It cross-references with a Mammona black site inventory from before the colony was chartered.",
            "Find the access code. {npc_first} thinks it's in the colony's original construction documents. The documents are in {faction}'s archives.",
            "Open the door. Or don't. Some doors are sealed for a reason. This might be one of them.",
        ],
        "choices": [
            "Open it. Whatever's inside, you need to know. Knowledge is survival.\nOR\nBrick it back up. Report nothing. Whatever Mammona sealed in there, they sealed it for a reason. Mammona doesn't do things for good reasons, but they do things for reasons.",
            "Open it with {faction} present. Witnesses. Protection. Also surveillance. Whatever you find, they find too.\nOR\nOpen it alone. At night. What you find is yours. What happens to you is also yours.",
        ],
        "twists": [
            "The room contains a chair. In the chair: a skeleton. Around the neck: a keycard with the player's clearance level. Printed on it: tomorrow's date.",
            "The room is a perfect replica of a room from {location}. Down to the coffee stain on the desk. Nobody from {location} has ever been here. Officially.",
            "The room is empty. Perfectly empty. But the air inside is warm. And the door, once opened, won't close again. And something in the colony's air filtration has changed.",
        ],
    },
    "corrupted_data": {
        "genre": "investigation",
        "name_pool": [
            "Corrupted Data",
            "The Altered Log",
            "HERMES Is Lying",
            "Manifest Discrepancy",
            "The Wrong Numbers",
        ],
        "trigger": "{npc} was running a routine diagnostic on HERMES. The population count is wrong. Not by one or two. By seven. Seven more people than the colony has. HERMES insists the count is correct.",
        "setup": "{sensory} The terminals flicker when you query the personnel database. {npc_first} has been comparing the digital records against paper manifests -- the ones nobody uses anymore. The discrepancies go back months. Names that appear in the digital logs but not on paper. Shift assignments for people who don't exist. Medical records with no patient.",
        "objectives": [
            "Identify the seven phantom personnel. Their names are in the system. Their bunks exist. Their rations are being drawn. Nobody has ever seen them.",
            "Determine who altered the logs. The modification trail leads to an admin account that's been inactive for two years. The account holder is dead.",
            "Find out why HERMES is protecting the false data. It's not corrupted. It's defending the lie. Aggressively.",
        ],
        "choices": [
            "Wipe HERMES and reload from backup. Lose three months of operational data. But the lies go with it.\nOR\nLeave HERMES running and investigate the phantom personnel yourself. If HERMES is lying, it's lying for a reason. Reasons can be useful.",
            "Publish the findings to the colony. Everyone deserves to know the system is compromised. Also, everyone will panic.\nOR\nTell only {npc_first}. Two people who know. Fewer targets. Smaller conspiracy. Also fewer witnesses if something happens to you.",
        ],
        "twists": [
            "The seven phantom personnel are real. They work the deep bore night shift. Nobody from the colony has ever seen them because they never come up. They're not in the records because they were here before the colony.",
            "HERMES isn't lying. The paper manifests are wrong. Someone has been removing names from the paper trail. Seven colonists who are very real and very much want to stay hidden.",
            "The dead admin's account isn't inactive. It's active right now. Logged in. Making changes. From a terminal in a room that's been sealed for two years.",
        ],
    },
    "identity_crisis": {
        "genre": "investigation",
        "name_pool": [
            "Identity Crisis",
            "The Wrong Name",
            "Who Am I?",
            "Not {npc_first}",
            "Personnel File: MISMATCH",
        ],
        "trigger": "{npc} approaches the player, visibly shaken. 'I found my own file,' {npc_first} says. 'My medical file. The blood type is wrong. The birthdate is wrong. The fingerprints are close. But they're not mine.'",
        "setup": "{sensory} {npc_first} has been on the colony for eight months. Everyone knows {npc_first}. Good worker. Quiet. Reliable. But the file says someone else. The photograph in the file is {npc_first}'s face but younger. Thinner. With a scar that {npc_first} doesn't have. Or doesn't have yet.",
        "objectives": [
            "Run a full biometric comparison. Fingerprints, retinal scan, DNA. The results are 96% match. Not 100%. Not close enough.",
            "Access the original personnel file from {npc_first}'s hiring records at {location}. The records show a different person with the same name. Different face. Same employment history. Same memories.",
            "Confront {npc_first} with the discrepancy. Watch their face. The confusion is genuine. The fear is real. They don't know who they are either.",
        ],
        "choices": [
            "Report the discrepancy to {faction}. They'll pull {npc_first} from active duty. Run tests. Tests that might answer the question. Tests that {npc_first} might not survive.\nOR\nSay nothing. {npc_first} is a good worker. Whoever they are. Sometimes the answer is worse than the question.",
            "Help {npc_first} investigate their own past. Follow the trail back to {location}. Find the original. If there is one.\nOR\nSuggest {npc_first} stop looking. Some questions don't have answers. Some answers aren't survivable.",
        ],
        "twists": [
            "There is no original. {npc_first} is the first. The file belongs to someone who doesn't exist yet. The file is from next year.",
            "{npc_first} is a clone. One of several. The others are on different colonies. None of them know about each other. Until now.",
            "The file is correct. {npc_first} is the imposter. But not deliberately. Someone rewrote their memories. Gave them a life. A name. A reason to be here. The real question isn't who {npc_first} is. It's who sent them.",
        ],
    },
    "signal_trace": {
        "genre": "investigation",
        "name_pool": [
            "Signal Trace",
            "The Wrong Frequency",
            "Ghost Transmission",
            "Source Unknown",
            "Who's Transmitting?",
        ],
        "trigger": "The comms array picks up a signal. Local. Coming from inside the colony's perimeter. But the signal isn't using colony equipment. It's using a frequency that was decommissioned forty years ago. {npc} is the first to notice.",
        "setup": "{sensory} The signal is short. Burst transmission. Every six hours. {npc_first} has been triangulating it for a week. The source moves. Always within the colony. Always in a section that's empty when they check. The signal's content is encrypted. The encryption is military-grade. Older than anyone here.",
        "objectives": [
            "Narrow the signal source to a specific room. It's moving, but it follows a pattern. The pattern matches the patrol route of someone who left the colony months ago.",
            "Decrypt the transmission. You'll need the cipher key. The cipher key is in {npc_first}'s dead colleague's personal effects. In a pocket nobody checked.",
            "Find the transmitter. It's small. Portable. Hidden in something nobody would think to search.",
        ],
        "choices": [
            "Decrypt it and broadcast the contents to the colony. Everyone knows. Everyone decides. Transparency has consequences.\nOR\nDecrypt it and keep it quiet. Use the information. Leverage is survival out here.",
            "Destroy the transmitter. Kill the signal. Whatever's receiving doesn't learn anything else.\nOR\nLeave it running. Trace what's receiving. Find the other end. It's bigger than one transmitter in one colony.",
        ],
        "twists": [
            "The signal isn't being sent. It's being received. The transmitter is a beacon. Something has been homing in on it. Something close.",
            "The encrypted content is a personnel manifest. Current colony. Current names. Current biometrics. Updated in real time. Someone has eyes inside.",
            "The transmitter is inside an automaton. It's been broadcasting since before the colony was built. The automaton doesn't know it's a relay. It thinks it's dreaming.",
        ],
    },
    "who_sent_the_message": {
        "genre": "investigation",
        "name_pool": [
            "Anonymous Warning",
            "The Unsigned Note",
            "Who Sent This?",
            "Dead Drop",
            "The Informant",
        ],
        "trigger": "A note appears in the player's quarters. Printed, not handwritten. Six words: 'They know about the deep bore.' No signature. No return. {npc} finds an identical note in their locker.",
        "setup": "The printer log shows the notes were produced on a terminal in {section}. At 0200. The terminal requires biometric login. The login used belongs to a colonist who's been in cryo for three months. {sensory} Someone is using dead credentials to deliver live warnings.",
        "objectives": [
            "Analyze the paper. Colony standard, but the batch number doesn't match current supplies. It matches a shipment from two postings ago.",
            "Check the cryo bay. The colonist whose credentials were used. They're still frozen. Vitals normal. But the neural activity monitor is showing patterns. Complex patterns. Dreams.",
            "Find the sender. Someone in this colony knows something about the deep bore that {faction} doesn't want shared. The question is whether the sender is protecting you or pointing you at something.",
        ],
        "choices": [
            "Follow the warning. Investigate the deep bore. Whatever they know, it's worth the risk of knowing.\nOR\nIgnore it. Warnings from anonymous sources on a colony like this are either traps or distractions. Often both.",
            "Find the sender and confront them. Allies are valuable. So is knowing who's watching you.\nOR\nFind the sender and report them to {faction}. Loyalty has a price. So does betrayal. Yours is cheaper.",
        ],
        "twists": [
            "The notes didn't come from a person. HERMES generated them. Using a dead colonist's credentials to avoid attribution. It's trying to help. Its definition of help is unsettling.",
            "The sender is in the room when you find them. They've been waiting. They have more to tell you. They also have two hours to live. They know that too.",
            "There is no sender. The notes are from you. Written by a version of you that remembers something you don't. The handwriting is yours. The knowledge isn't.",
        ],
    },
    "the_wrong_manifest": {
        "genre": "investigation",
        "name_pool": [
            "The Wrong Manifest",
            "Cargo Discrepancy",
            "Unmarked Crate",
            "What's Really In The Hold",
            "Freight Irregularity",
        ],
        "trigger": "Supply drop arrives. Standard crates. Standard manifest. {npc} notices a weight discrepancy. Crate 14 is forty kilograms heavier than listed. When {npc_first} runs the barcode, the system returns a classification that shouldn't exist on a mining colony: 'Biological. Handle Alive.'",
        "setup": "Crate 14 sits in the cargo bay, humming. Not vibrating -- humming. A frequency you can feel in your teeth. {sensory} The manifest says 'drill components.' The external temperature reading on the crate says 37 degrees Celsius. Body temperature. {npc_first} has sealed the bay and called you.",
        "objectives": [
            "Trace the crate's origin. The shipping label says {location}. The routing history has been scrubbed. Whoever sent this didn't want it tracked.",
            "Open the crate. Or don't. But something inside is alive, and the humming is getting louder.",
            "Determine who on the colony was expecting this delivery. Someone signed for it. The signature is forged. But it's a good forgery.",
        ],
        "choices": [
            "Open the crate with a full medical and security team present. Whatever's inside, you face it together. Also, witnesses.\nOR\nJettison the crate outside the perimeter. Don't open it. Don't look. Some cargo isn't worth receiving.",
            "Contact {faction} about the discrepancy. They sent it. Let them explain.\nOR\nKeep it. Whatever's inside, it was sent here for a reason. Reasons are currency.",
        ],
        "twists": [
            "Inside the crate: a person. Sedated. Wearing a colony uniform. With a name tag that matches a colonist who died here six months ago. Same face. Same fingerprints. Fresh.",
            "The crate is empty. The weight comes from the crate itself. The metal is organic. It's growing. The humming is a heartbeat.",
            "The crate was meant for a different colony. One that doesn't exist anymore. It's been rerouted seventeen times. Nobody wants it. Now it's yours.",
        ],
    },

    # ---- FACTION TENSION (7) ----
    "sabotage": {
        "genre": "faction_tension",
        "name_pool": [
            "Sabotage",
            "The Inside Job",
            "Mechanical Failure",
            "Who Cut the Line?",
            "Deliberate Malfunction",
        ],
        "trigger": "The water recycler fails. Then the backup. Then the backup's backup. {npc} pulls the maintenance panel. The failsafe wires haven't corroded. They've been cut. Clean. With tools from the colony's own workshop.",
        "setup": "Three systems. Three cuts. Professional work. Someone in the colony did this with expertise and access. {sensory} {npc_first} has a list of seven people with the knowledge to pull this off. Four of them are on the list because {npc_first} trained them.",
        "objectives": [
            "Fix the water recycler before the reserve tanks run dry. Thirty-six hours. The parts needed aren't in inventory. Someone removed them last week.",
            "Identify the saboteur. Check tool checkout logs, access records, and shift schedules. The window is narrow. The suspects aren't.",
            "Determine the motive. Sabotage for {faction}? Personal vendetta? Or something worse -- a distraction from what's really happening.",
        ],
        "choices": [
            "Arrest the most likely suspect. Quick justice. Colony morale stabilizes. If you're wrong, the real saboteur is still free and now knows you're looking.\nOR\nWatch. Wait. Let the saboteur think they got away with it. They'll act again. Next time, you'll be ready. Assuming the colony survives next time.",
            "Go public. Colony meeting. Lay out the evidence. Let twenty-three people decide. Democracy. Also a witch hunt.\nOR\nHandle it quietly. Confront the suspect alone. Justice without spectacle. Also without witnesses.",
        ],
        "twists": [
            "The saboteur is {npc_first}. Not deliberately. They were sleepwalking. The cuts match their tool kit. They have no memory of it. The sleepwalking started after they found {item} in the bore shaft.",
            "Nobody cut the wires. They were cut before installation. The sabotage happened at the factory, months ago. This was always going to happen. Someone wanted this colony to fail on schedule.",
            "The sabotage saved the colony. The water recycler was contaminated. If it had kept running, every colonist would have been exposed. The saboteur knew. Couldn't prove it. Did what they could.",
        ],
    },
    "infiltration": {
        "genre": "faction_tension",
        "name_pool": [
            "The Mole",
            "Deep Cover",
            "Infiltration",
            "Among Friends",
            "The Plant",
        ],
        "trigger": "{faction} contacts the colony with a warning: they have an operative inside. Not a threat. A notification. Professional courtesy. They don't say who. They don't say why. {npc} is the only one who doesn't seem surprised.",
        "setup": "{sensory} The message arrived on a frequency that {faction} shouldn't have. The encryption is colony-standard. Someone gave them the keys. {npc_first} watches the player read the message and says nothing. The silence is louder than the alarm it replaced.",
        "objectives": [
            "Sweep for transmitting devices. There are three. One in the mess hall, one in the command center, one in {npc_first}'s quarters. {npc_first} says the one in their quarters isn't theirs.",
            "Cross-reference colony personnel with {faction}'s known operatives. Two matches. Both are dead. Officially.",
            "Determine what the operative has been transmitting. Personnel data. Mining yields. And something else: seismic readings from the bore shaft. Someone outside the colony is very interested in what's underneath.",
        ],
        "choices": [
            "Feed the operative false information. Control the narrative. Use the mole as a channel. Dangerous, but you choose what {faction} learns.\nOR\nBurn the operative. Find them. Expose them. Lose the channel. Gain trust from the colony. Assuming the operative doesn't have a contingency.",
            "Confront {npc_first}. The transmitter in their quarters. The lack of surprise. Either they're the mole or they know who is.\nOR\nSay nothing to {npc_first}. Watch them. Follow them. The mole's handler will make contact eventually. That's when you get both.",
        ],
        "twists": [
            "The operative is you. Not consciously. The neural chip from your last Mammona posting has been transmitting. You didn't know. Now you do. Now {faction} knows you know.",
            "{npc_first} is the operative. Has been since day one. But the warning message wasn't from their handler. It was from a rival faction. {npc_first} has been burned. They need your help now more than you need theirs.",
            "There is no operative. {faction} sent the message to create paranoia. Divide the colony. Weaken it from inside. And it's working.",
        ],
    },
    "betrayal": {
        "genre": "faction_tension",
        "name_pool": [
            "Betrayal",
            "The Knife in the Back",
            "Broken Trust",
            "Terms Changed",
            "The Deal Was Different",
        ],
        "trigger": "{npc} has been the player's most reliable ally. Good advice. Solid work. Honest eyes. Until the supply shipment arrives six crates short and {npc_first}'s signature is on the diversion order. The crates went to {faction}.",
        "setup": "{sensory} You find {npc_first} in the mess hall. Eating. Calm. They see your face and they know that you know. They don't run. They set down their spoon. 'I can explain,' they say. 'You won't like it. But I can explain.'",
        "objectives": [
            "Listen to {npc_first}'s explanation. Decide if it changes anything. The crates are gone either way.",
            "Determine what was in the diverted crates. Standard supplies, according to the manifest. But the manifest was falsified. The real contents: {item}. Six crates of it.",
            "Confront {faction}'s contact. They're still on the colony. Waiting for the second shipment. The one {npc_first} hasn't diverted yet.",
        ],
        "choices": [
            "Forgive {npc_first}. The explanation makes sense. They were protecting someone. The betrayal was survival, not malice. Trust is damaged. But not dead.\nOR\nExile {npc_first}. Walk them to the perimeter. Give them a pack and three days of rations. Colony law. The ice doesn't care about explanations.",
            "Take the second shipment and use it as leverage against {faction}. You have what they want. Make them pay.\nOR\nReturn it. All of it. No debts. No leverage. No entanglement. Clean books. Cold comfort.",
        ],
        "twists": [
            "{npc_first} didn't betray you. They were protecting you. The diverted crates contained something {faction} was going to use against the colony. {npc_first} intercepted it. Couldn't explain without revealing how they knew.",
            "The betrayal goes deeper. {npc_first} has been reporting to {faction} for months. But not willingly. They're holding someone {npc_first} loves. This was the price of keeping them alive.",
            "{npc_first}'s explanation is simple: the colony is going to fail. They saw the numbers. Made a deal to get people out. Not everyone. But some. They chose who gets saved. Your name isn't on the list.",
        ],
    },
    "power_struggle": {
        "genre": "faction_tension",
        "name_pool": [
            "Power Struggle",
            "The Contested Claim",
            "Two Bosses",
            "Divided Colony",
            "Chain of Command",
        ],
        "trigger": "The thermal core vein in {section} is the richest strike the colony has seen. {faction} wants it mined for corporate quota. {npc} wants it rationed for colony survival. Both have backing. The colony splits down the middle.",
        "setup": "Two factions. Two agendas. One resource. {sensory} {npc_first} holds a colony meeting in the mess hall. Half the colonists sit on {npc_first}'s side. Half sit across. The line down the middle of the room is invisible and absolute.",
        "objectives": [
            "Mediate between {npc_first} and {faction}'s representative. Find a compromise. If one exists.",
            "Determine the actual yield of the thermal core vein. Both sides are inflating their numbers. The truth is somewhere in between. And worse than either estimate.",
            "Prevent the tension from escalating to violence. Two colonists have already been in a fight. The next one will involve tools.",
        ],
        "choices": [
            "Side with {npc_first}. Colony survival over corporate profit. {faction} retaliates. Supplies cut. Reinforcements cancelled. You're on your own.\nOR\nSide with {faction}. Meet the quota. The thermal cores ship out. The colony gets cold. But the supply line stays open.",
            "Split the vein. Half for quota, half for colony. Neither side gets enough. Both resent the compromise. But nobody dies today.\nOR\nSeize the vein yourself. Colony authority. Neither faction controls it. Both become your enemy. But you control the resource.",
        ],
        "twists": [
            "The thermal core vein is unstable. Mining it at full capacity will trigger a collapse that buries {section}. Both sides are so focused on the argument they've ignored the geology report.",
            "{npc_first} and {faction}'s representative are secretly working together. The power struggle is theater. They're using the conflict to distract from a joint operation in the deep bore.",
            "The vein isn't thermal cores. Not entirely. Something else is mixed in. Something alive. Mining it is waking it up.",
        ],
    },
    "debt_collection": {
        "genre": "faction_tension",
        "name_pool": [
            "Debt Collection",
            "The Collector Arrives",
            "Overdue",
            "Payment in Kind",
            "The Price",
        ],
        "trigger": "A shuttle lands unannounced. One passenger. They're carrying a ledger and a weapon. They're looking for {npc}. The debt is old. The interest is new. {faction} sent them.",
        "setup": "{sensory} The collector sits in the mess hall like they own it. They might. The ledger says {npc_first} owes {faction} for a contract broken on {location}. The sum is more than {npc_first} will earn in a lifetime. The collector doesn't want money. They want something else. Something in the colony.",
        "objectives": [
            "Determine what {faction} actually wants. The debt is leverage. The real price isn't in the ledger.",
            "Protect {npc_first} or let the collector work. Colony autonomy versus external authority. The collector has legal documents. Mammona-stamped.",
            "Negotiate. The collector has instructions. But collectors have ambitions too. Everyone wants something. Find what the collector wants for themselves.",
        ],
        "choices": [
            "Pay the debt. With thermal cores from the colony's reserves. Keeps {npc_first} safe. Leaves the colony cold.\nOR\nRefuse. Expel the collector. {faction} retaliates. How and when is the question.",
            "Give the collector what they came for. A name. A location. A secret. {npc_first} didn't just break a contract. They took something. Returning it changes everything.\nOR\nHelp {npc_first} disappear. New identity. Different section. The collector leaves empty-handed. {npc_first} lives as a ghost in their own colony.",
        ],
        "twists": [
            "The debt isn't {npc_first}'s. It's their dead partner's. {npc_first} assumed the identity to escape {location}. The debt followed the name, not the person.",
            "The collector isn't here for {npc_first}. They're here for you. {npc_first} was just the excuse to land. The real ledger page has your name on it.",
            "The collector changes sides. What they found at the colony -- what's really happening here -- is worse than any debt. They want to help. Collectors don't help. This one does. That's how bad it is.",
        ],
    },
    "mutiny": {
        "genre": "faction_tension",
        "name_pool": [
            "Mutiny",
            "Broken Chain",
            "The Refusal",
            "We're Done",
            "Line in the Dust",
        ],
        "trigger": "The morning shift doesn't report. Twenty colonists in the mess hall. Arms crossed. Doors locked from the inside. {npc} stands at the front. 'We're not going back down,' {npc_first} says. 'Not until you listen.'",
        "setup": "{sensory} It's not anger. That's what's frightening about it. The colonists in the mess hall are calm. Resolved. They've thought about this. {npc_first} has a list of demands. The list is reasonable. The timing is not. The bore shaft needs monitoring. The reactor needs hands. Every hour of shutdown is a degree colder.",
        "objectives": [
            "Read the demands. They're not unreasonable: medical supplies, rotation schedule, hazard pay, and one thing you can't give them -- the truth about what's in the deep bore.",
            "Negotiate without violence. The colonists are armed with tools. The security team is armed with worse. The gap between tools and weapons is smaller than anyone thinks.",
            "Decide which demands are met, which are promised, and which are refused. The colony's survival depends on getting this right.",
        ],
        "choices": [
            "Meet every demand. The colony can barely afford it. But the alternative is a workforce that won't work.\nOR\nMeet the reasonable demands. Refuse the truth about the deep bore. Some things are more dangerous to know than to not know. Tell them that. See if they believe you.",
            "Talk to {npc_first} alone. Leader to leader. Find out what {npc_first} really wants. The list is a negotiating position. The real ask is underneath.\nOR\nBreak the mutiny. Security. Force. Arrests. The colony works tomorrow. The colony hates you forever. Pick one.",
        ],
        "twists": [
            "{npc_first} doesn't want to lead the mutiny. They're doing it because the alternative is worse. Three colonists were planning violence. {npc_first}'s sit-in is the peaceful option. If it fails, the other plan activates.",
            "The demands include something buried in the fine print: access to the colony's escape shuttles. Not everyone. Just the families. {npc_first} knows something is coming. Something that makes the bore shaft irrelevant.",
            "While the colony's attention is on the mutiny, someone is in the command center. Downloading everything. The mutiny isn't about demands. It's a diversion.",
        ],
    },
    "double_agent": {
        "genre": "faction_tension",
        "name_pool": [
            "Double Agent",
            "The Turned Spy",
            "Loyalty Test",
            "Which Side Are You On?",
            "The Handler's Gambit",
        ],
        "trigger": "{npc} is a {faction} operative. Everyone knows. It's the worst-kept secret on the colony. What nobody knows: {npc_first} has been feeding {faction} false intelligence for six months. Tonight, {faction} figured it out.",
        "setup": "{sensory} {npc_first} is in the player's quarters, blood on their collar, a data drive in their hand. 'I have about four hours before they send someone,' {npc_first} says. 'This drive has everything. Their assets, their operations, their targets. You can use it or you can hand me over. But decide now.'",
        "objectives": [
            "Verify {npc_first}'s story. The data drive could be bait. Or leverage. Or the most valuable intelligence asset on the planet.",
            "Secure {npc_first}. {faction} is coming. Four hours. Maybe less. The colony's perimeter won't stop a professional extraction team.",
            "Decide what to do with the intelligence. It could protect the colony. It could start a war. It could do both.",
        ],
        "choices": [
            "Protect {npc_first}. They risked everything. Loyalty means something, even when it's complicated.\nOR\nHand {npc_first} over. {faction} gets their traitor. The colony gets peace. {npc_first} gets whatever {faction} does to double agents. You know what that is.",
            "Use the intelligence offensively. Strike first. Before {faction} can retaliate. Burn their network. Become a threat they can't ignore.\nOR\nUse it as insurance. A dead man's switch. {faction} touches the colony, the data goes public. Mutually assured destruction. Cold. Effective.",
        ],
        "twists": [
            "{npc_first} isn't a double agent. They're a triple. The data drive is real, but it's also a delivery mechanism. {faction} wants you to have the intelligence. The question is why.",
            "The extraction team isn't coming for {npc_first}. They're coming for the colony. {npc_first}'s cover being blown was the trigger. The colony has something {faction} has been patient about. They're done being patient.",
            "{npc_first} burned their own cover. Deliberately. Because what they found in {faction}'s files is worse than anything on the data drive. Something about the colony. Something about Erebus. Something that makes being a spy irrelevant.",
        ],
    },

    # ---- EXPEDITION (6) ----
    "deep_bore_descent": {
        "genre": "expedition",
        "name_pool": [
            "The Deep Bore",
            "Descent",
            "Below the Bottom",
            "What's Down There",
            "Shaft 12 Revisited",
        ],
        "trigger": "The drill team punches through the floor of the deepest shaft. Below it: a void. Not a cave. A void. The instruments say it goes down another six hundred meters. {npc} says the drill mapping only goes to two hundred. The rest is unmapped.",
        "setup": "The descent pod creaks on its cable. Below, the bore shaft narrows, then opens into something vast. {sensory} {npc_first} runs the spotlight across the void. The walls aren't rock. They're smooth. Worked. Someone carved this space. Or something grew it. The air coming from below is warm. Warmer than it should be. And it moves. Like breathing.",
        "objectives": [
            "Descend to the void floor. Map the space. The cable reaches. Barely.",
            "Collect samples from the worked walls. The material doesn't match any known geology. It's not stone. It's not metal. It resists the drill and yields to the hand.",
            "Find the heat source. The temperature increases as you descend. At the bottom, it's twenty degrees above freezing. Something is generating heat. A lot of it.",
        ],
        "choices": [
            "Go deeper. The unmapped section calls. The air is warm. The walls are strange. Whatever is down there, it's big enough to heat the air for six hundred meters.\nOR\nStop. Map what you've found. Report it. Come back with more equipment. More people. The smart play. The one that lets whatever's down there prepare for your return.",
            "Take samples back to the colony for analysis. Slow and scientific.\nOR\nLeave the samples where they are. Touch nothing. Study it in situ. Whatever this material is, removing it from context might change it. Or anger it.",
        ],
        "twists": [
            "The void isn't empty. At the bottom, arranged in concentric circles, are pods. Thousands of them. Sealed. Warm. Something is inside each one. Some of them are moving.",
            "The walls have writing. Not precursor. Human. In a hand that matches the colony's original surveyor. Who died fifteen years ago. Before the colony was built. The writing says: 'Don't wake it up. We didn't listen. You won't either.'",
            "The descent disturbed something. On the way back up, the cable is heavier. Something is climbing. Following. Patient. It doesn't need the cable. It's climbing the walls.",
        ],
    },
    "ruin_exploration": {
        "genre": "expedition",
        "name_pool": [
            "The Ruins Beneath",
            "Precursor Architecture",
            "Old Stone, Wrong Angles",
            "The Temple",
            "Before Us",
        ],
        "trigger": "Seismic survey reveals a structure beneath the ice shelf. Not geological. Architectural. Right angles, repeated patterns, deliberate spacing. It's two kilometers from the colony. It's been there longer than the ice. {npc} wants to see it first.",
        "setup": "{sensory} The entrance is carved from a single piece of stone that shouldn't exist on Erebus. The architecture inside defies interpretation -- doors sized for something taller and thinner than human, corridors that curve in ways that make the inner ear rebel. {npc_first} marks the walls with chalk. After twenty minutes, the chalk marks have moved.",
        "objectives": [
            "Map the first three chambers. Navigation is unreliable. Compasses spin. HERMES loses signal past the threshold.",
            "Document the carvings. They tell a story. The story involves a sleeper, a cage, and something that looks uncomfortably like a mining colony.",
            "Reach the central chamber. The thermal signature says it's the warmest point in the structure. Also the deepest. Also the source of the signal the colony has been hearing for months.",
        ],
        "choices": [
            "Enter the central chamber. Whatever the precursors built this place for, it's in there. Knowledge. Power. Horror. Possibly all three.\nOR\nSeal the entrance. Report the find to {faction}. Let them deal with it. Except {faction} won't seal it. They'll strip-mine it.",
            "Take the artifacts you've found. They're valuable. They're alien. They might be dangerous.\nOR\nLeave everything in place. Study, don't steal. The precursors might be dead. They might not be. Don't give them a reason to notice you.",
        ],
        "twists": [
            "The central chamber contains a mirror. Not glass. Liquid. It shows whoever looks into it, but the reflection is doing something different. Saying something. The lips move. The words are silent. Until you get close enough.",
            "The ruins aren't ruins. They're infrastructure. Still functional. The colonists have been mining thermal cores -- the structure's equivalent of blood cells. It's starting to notice.",
            "The precursors aren't extinct. They're in the walls. In the stone. Dormant. The warmth of the colony is waking them. Not fast. But faster now that someone has opened the door.",
        ],
    },
    "surface_trek": {
        "genre": "expedition",
        "name_pool": [
            "The Long Walk",
            "Surface Trek",
            "Across the Ice",
            "Whiteout",
            "The Other Side",
        ],
        "trigger": "A distress beacon activates forty kilometers northeast. An old frequency. Pre-colony. Someone or something is alive out there and has been for longer than anyone thought possible. {npc} volunteers to go. Nobody else does.",
        "setup": "Forty kilometers of ice. No shelter. No waypoints. Wind at sixty kilometers per hour and dropping temperatures. {sensory} {npc_first} packs three days of rations for a one-day trip. 'In case,' they say. They don't finish the sentence.",
        "objectives": [
            "Cross the ice shelf. The route passes through a crevasse field. The crevasses are deep enough that the flashlight doesn't find the bottom.",
            "Reach the beacon source. A pre-colony structure half-buried in ice. The door is open. The lights inside are on. The power source is unknown.",
            "Find whoever activated the beacon. They've been surviving out here alone. Or not alone.",
        ],
        "choices": [
            "Bring them back to the colony. New mouth to feed. New skills. New secrets. Whatever they know about surviving alone on Erebus is valuable.\nOR\nHelp them stay. Give them supplies. Let them keep their isolation. Some people left the colony for a reason. Respect it.",
            "Investigate the structure. A pre-colony outpost with working power is either a miracle or a trap. Both have value.\nOR\nTake what you need and leave. The less time spent out here, the better. The ice is patient. You aren't.",
        ],
        "twists": [
            "The person at the beacon isn't a survivor. They're a colonist. From the colony. They left two weeks ago. They don't remember leaving. They've aged years.",
            "The structure isn't pre-colony. It's post-colony. The construction materials haven't been manufactured yet. The calendar inside shows next year's date.",
            "Nobody is at the beacon. It activated on its own. But inside the structure, arranged on a table: supplies. Current supplies. From the colony's stores. Packed for two. Someone knew you were coming.",
        ],
    },
    "recovery_mission": {
        "genre": "expedition",
        "name_pool": [
            "Recovery Mission",
            "Go Get It Back",
            "Retrieval",
            "What We Left Behind",
            "The Return Trip",
        ],
        "trigger": "The survey team went out three days ago. They found something in the ruins. Something valuable. Then comms went dead. {npc} picks up a final transmission: coordinates, a single word -- 'hurry' -- and the sound of something large moving through stone.",
        "setup": "{sensory} The survey team's last known position is a precursor site twelve kilometers south. The trail is easy to follow -- their vehicle tracks cut clear lines in the ice. Too easy. Halfway there, {npc_first} notices the tracks are paralleled by something else. Footprints. Barefoot. In negative forty. Walking the same direction.",
        "objectives": [
            "Reach the survey site. The vehicle is there. Engine cold. Doors open. Equipment scattered. No bodies.",
            "Find the team. The footprints -- human and otherwise -- lead into the precursor structure. The structure is larger than the survey map indicated.",
            "Retrieve what the team found. It's in the structure. So is whatever took them. Both are between you and the exit.",
        ],
        "choices": [
            "Rescue the team. They might be alive. Three days in a precursor ruin with something hunting them. Alive is optimistic. But possible.\nOR\nRetrieve the artifact and leave. The artifact is why they were sent. Cold calculus. Mammona's favorite kind.",
            "Dynamite the entrance after you're out. Bury whatever's in there. Bury the artifact. Bury the answers.\nOR\nLeave the entrance open. Study it. Learn from it. Accept that whatever comes out is the price of knowledge.",
        ],
        "twists": [
            "The survey team is alive. Unharmed. Sitting in the central chamber, cross-legged, eyes closed, humming in unison. A frequency that matches the bore shaft signal. They don't want to leave. They say they've been invited.",
            "The barefoot tracks aren't from something hostile. They're from the previous survey team. The one from two years ago. The one that was declared dead. They've been living in the ruins. They've changed.",
            "The artifact the team found isn't an object. It's information. Carved into the walls: a complete map of every precursor site on Erebus. There are hundreds. And they're connected. Underground. To something central.",
        ],
    },
    "salvage_run": {
        "genre": "expedition",
        "name_pool": [
            "Salvage Run",
            "The Wreck",
            "Derelict Recovery",
            "Dead Ship Walking",
            "Cargo From the Cold",
        ],
        "trigger": "A ship goes down eight kilometers west. Mammona freighter. Emergency landing. The transponder is active but nobody's responding to hails. {npc} checks the manifest: medical supplies, reactor components, and a cargo container listed as 'personnel.' Personnel don't ship in cargo containers.",
        "setup": "The crash site is a scar in the ice. The freighter is intact -- mostly. The hull is breached amidships. Emergency lights blink through the breach. {sensory} {npc_first} scans the wreck from two hundred meters. Life signs: seven. All in the cargo bay. Not moving.",
        "objectives": [
            "Enter the wreck. The structural integrity is marginal. The ship is listing. One wrong step and it drops into the crevasse it's perched over.",
            "Secure the medical supplies and reactor components. They're in the forward hold. The forward hold is separated from the cargo bay by a sealed blast door. Someone sealed it from the cargo bay side.",
            "Open the cargo container. The life signs are inside. Seven people. Sedated. In cryo pods that aren't standard Mammona issue.",
        ],
        "choices": [
            "Wake them. Seven people who were shipped as cargo deserve to know where they are. Also, waking seven confused people in an unstable wreck is dangerous.\nOR\nTransport them as-is. Keep them under. Get them to the colony. Let the medic handle it. Questions later. Survival first.",
            "Strip the wreck clean. Everything useful, including the cryo pods. Leave nothing for {faction} or the ice.\nOR\nTake only what the colony needs. Leave the rest. The wreck is evidence. Evidence of what {faction} has been shipping. Evidence disappears when you strip it.",
        ],
        "twists": [
            "The seven aren't prisoners. They're volunteers. Each one carries a skill the colony desperately needs. A doctor. An engineer. A xenobiologist. They were sent by someone inside {faction}. Someone who knows what's coming and is stacking the deck.",
            "One of the seven is a perfect genetic match for {npc_first}. Same face. Same voice. Same fingerprints. Different memories. They don't know each other. The manifest calls them both 'Asset 7-C.'",
            "The crash wasn't an accident. The pilot put the ship down deliberately. The pilot is one of the seven in the cargo bay. In a cryo pod. Sedated before landing. Someone else landed the ship. Someone who isn't on board anymore.",
        ],
    },
    "the_long_walk": {
        "genre": "expedition",
        "name_pool": [
            "The Long Walk",
            "Into the Ice",
            "Gone Walking",
            "Follow the Footprints",
            "Where They Went",
        ],
        "trigger": "{npc} walked out the airlock at 0400. No suit. No gear. No note. Just walked into the ice in their sleeping clothes. By the time anyone noticed, the footprints were filling with snow. The trail heads toward the bore shaft. {npc_first} has an eight-hour head start.",
        "setup": "The footprints are steady. Not stumbling. Not running. Walking with purpose. {sensory} Following the trail in the vehicle, you can see where {npc_first} stopped. Once. To look up at the sky. Then kept walking. In this cold, unprotected, survival time is measured in hours. {npc_first} shouldn't be alive. The trail says otherwise.",
        "objectives": [
            "Follow the trail before the storm buries it. The wind is picking up. You have maybe three hours.",
            "Find {npc_first}. Alive or otherwise. Bring closure or bring them back.",
            "Understand why. {npc_first} wasn't suicidal. Wasn't depressed. Was functional yesterday. Something happened between lights out and 0400.",
        ],
        "choices": [
            "Continue the search past the safety window. The storm is coming. If you don't turn back now, you're committed. Two lives instead of one.\nOR\nTurn back. Report {npc_first} as lost. The smart decision. The one you'll dream about.",
            "If found alive: bring {npc_first} back against their will. They'll fight it. They say they have to keep going. Something is waiting.\nOR\nIf found alive: go with them. See where the trail leads. Whatever {npc_first} is walking toward, it pulled hard enough to override every survival instinct. That kind of pull is worth understanding.",
        ],
        "twists": [
            "{npc_first} is found. Alive. Standing at the edge of the bore shaft. Not cold. The air around them is warm. They're talking to something you can't see. They turn and say: 'It wants to meet you.'",
            "The trail splits. Two sets of footprints. {npc_first}'s and another. The other set starts at the bore shaft and walks toward the colony. The sets meet halfway. Then only {npc_first}'s prints continue. Going down.",
            "{npc_first} is found twenty kilometers out. Sitting on the ice. Building something from precursor fragments. A structure. Small. Complex. When asked what it is, {npc_first} says, 'A door. I don't know how I know. But it's almost finished.'",
        ],
    },

    # ---- MORAL DILEMMA (6) ----
    "mercy_killing": {
        "genre": "moral_dilemma",
        "name_pool": [
            "Mercy",
            "The Kindest Cut",
            "Before It's Too Late",
            "The Ask",
            "What's Left of Them",
        ],
        "trigger": "{npc} comes to the player at 0200. They've been crying. Not from sadness. From exhaustion. 'I need you to help me do something,' {npc_first} says. 'And I need you to not talk me out of it.'",
        "setup": "{sensory} In the quarantine bay, a colonist lies strapped to a bed. The contamination has reached stage four. The skin is changing texture. The eyes are open but they're not looking at anything in this room. The colonist is lucid. For now. 'I can feel it thinking,' they say. 'Not me thinking. It. And it's getting louder.'",
        "objectives": [
            "Assess the contaminated colonist. The medic says stage five is irreversible. They're at stage four. Time remaining: hours. Maybe less.",
            "Listen to the colonist's request. They're clear. They're calm. They want it to end before they stop being themselves.",
            "Make a decision. {npc_first} can't do it alone. They need a witness. Or a partner. Or someone to stop them.",
        ],
        "choices": [
            "Grant the request. Quick. Painless. Humane. Illegal under Mammona colony regulations. Merciful under every other standard.\nOR\nRefuse. Wait for stage five. Study the transition. The data could save others. The cost is watching someone you know become something else.",
            "Let {npc_first} do it. Stand witness. Share the weight.\nOR\nDo it yourself. {npc_first} shouldn't have to carry this. Neither should you. But you're the one they asked.",
        ],
        "twists": [
            "The colonist reaches stage five. But they don't lose themselves. They're still in there. Changed. Altered. But present. And they remember what you were about to do.",
            "The contamination isn't terminal. Stage five is transformation, not death. The colonist becomes something new. Something that can survive Erebus without a hab suit. The 'cure' would have killed them.",
            "{npc_first} can't do it. Freezes. The colonist takes {npc_first}'s hand and says, 'It's okay. I was going to ask you, but I think I want to see what happens next.' The decision is taken from both of you.",
        ],
    },
    "who_gets_the_escape_pod": {
        "genre": "moral_dilemma",
        "name_pool": [
            "Not Enough Seats",
            "The Lottery",
            "Who Gets Out",
            "Manifest for the Last Shuttle",
            "Triage",
        ],
        "trigger": "The evacuation order comes through. One shuttle. Sixteen seats. Twenty-three colonists. {npc} is in charge of the manifest. {npc_first} is staring at the list and hasn't moved in twenty minutes.",
        "setup": "The shuttle arrives in six hours. The threat -- whatever triggered the evacuation -- arrives in eight. Two-hour margin. Tight. {sensory} {npc_first} has the roster spread across the table. Names. Skills. Ages. Dependents. The math is simple. The morality isn't.",
        "objectives": [
            "Help {npc_first} build the manifest. Or take it from them. Someone has to decide. The colony is watching.",
            "Manage the seven who aren't on the list. Tell them. Or don't tell them until the shuttle's gone. Both options are terrible.",
            "Determine if there's another way. A second shuttle. A hiding place. A way to buy more time. There might not be. But you have to look.",
        ],
        "choices": [
            "Skill-based triage. Take the people the next colony needs most. Cold logic. Fair by one definition. Monstrous by another.\nOR\nLottery. Pure chance. Equal odds. Nobody made the choice. Nobody bears the guilt. Except the universe.",
            "Stay behind yourself. Give your seat to someone else. Lead the seven who remain. Find another way.\nOR\nTake your seat. You've earned it. You've kept this colony alive. Surviving isn't selfish. Except when it feels like it is.",
        ],
        "twists": [
            "The seven who stay find shelter. The shuttle never arrives at its destination. The manifest is a death warrant dressed as salvation.",
            "One of the seven is a child. The child's parent is on the manifest. The parent refuses to go without the child. Now there are eight staying and a seat that nobody wants.",
            "There is no threat. The evacuation order was faked. Someone wanted exactly these twenty-three people forced to make this choice. The real test isn't survival. It's what they become under pressure.",
        ],
    },
    "whistleblower": {
        "genre": "moral_dilemma",
        "name_pool": [
            "The Whistleblower",
            "Paragraph Twelve",
            "The Evidence",
            "On Record",
            "The Report Nobody Wants",
        ],
        "trigger": "{npc} finds a file in {faction}'s local database. It was supposed to be encrypted. It's not. Inside: records of seven colonies. Seven failures. Not accidents. Designed failures. Insurance payouts. Tax write-offs. The colony they're standing in is number eight.",
        "setup": "{sensory} {npc_first} has the file on a data drive. Small enough to hide. Large enough to end {faction}. Or large enough to end {npc_first}. The file includes projected casualty timelines. For this colony. The timeline is ahead of schedule.",
        "objectives": [
            "Verify the file. Cross-reference the seven colonies with public records. The losses match. The insurance claims match. The 'unforeseen circumstances' are identical.",
            "Decide what to do with the evidence. The comms array can broadcast to the wider network. {faction} can't stop a broadband pulse. But they can trace it.",
            "Protect {npc_first}. Once this file moves, {npc_first} becomes a target. Maybe they already are.",
        ],
        "choices": [
            "Broadcast the file. Burn {faction}. Save future colonies. Paint a target on this one. {faction} will retaliate. Not with soldiers. With supply cuts. With silence. The cold will do the rest.\nOR\nBury it. Use it as leverage. Quiet negotiations. Better conditions. The truth stays buried. But so does this colony's death sentence.",
            "Give the file to a rival faction. Let them fight it out. Stay out of the crossfire.\nOR\nPresent it directly to {faction}'s local representative. Confront them. See what they offer to make this go away. Take their measure.",
        ],
        "twists": [
            "The file is real. The plan is real. But {faction} didn't originate it. They're following orders from a board member who doesn't officially exist. The conspiracy goes higher than one corporation.",
            "{npc_first} planted the file. It's partially real, partially fabricated. {npc_first} has their own agenda. The truth is in there, but so are {npc_first}'s lies. And you can't tell which is which.",
            "The casualty timeline for this colony has a footnote: 'Exception: if thermal core yield exceeds projections, initiate Protocol 7.' The yield exceeds projections. Protocol 7 isn't a shutdown. It's an acceleration.",
        ],
    },
    "cover_up": {
        "genre": "moral_dilemma",
        "name_pool": [
            "The Cover-Up",
            "What Nobody Saw",
            "Buried Evidence",
            "The Clean Version",
            "Incident Report: REDACTED",
        ],
        "trigger": "Something happened in {section} last night. Something bad. {npc} was there. So were four others. The official report says equipment malfunction. The actual cause: human error. Negligence. One person is dead. If the truth comes out, the colony loses three essential workers to criminal charges. The colony can't afford to lose three people.",
        "setup": "{sensory} The body has been moved. The scene has been cleaned. The report has been written. {npc_first} stands in the corridor, hands clean, conscience dirty. 'We didn't mean for it to happen,' {npc_first} says. 'But it happened. And telling the truth doesn't bring them back. It just kills three more.'",
        "objectives": [
            "Review the falsified report. It's good work. Consistent. Believable. Except for one detail that doesn't add up. You spot it. Others might not.",
            "Talk to the four witnesses. They're aligned. Scared. Committed to the lie. But one of them -- the youngest -- keeps looking at the door.",
            "Decide. The dead colonist has a family back on {location}. They'll receive a report. This report. The family will never know.",
        ],
        "choices": [
            "Accept the cover-up. File the report. Keep the colony whole. Live with the lie.\nOR\nExpose the truth. Three people face charges. The colony is understaffed. But the dead are honored honestly. And the living know the rules still mean something.",
            "Rewrite the report yourself. Not the truth. Not the lie. Something in between. Assign responsibility without criminal charges. A middle ground. Satisfying nobody. Survivable by all.\nOR\nConfront {npc_first} privately. Make them tell the family. Personally. No report. No charges. Just the truth, delivered to the only people who deserve it.",
        ],
        "twists": [
            "The youngest witness breaks. Tells someone. The colony divides. Those who understand and those who don't. The cover-up did more damage than the truth ever would.",
            "The death wasn't negligence. It was intentional. {npc_first} doesn't know. One of the four used the accident to cover a murder. The cover-up is protecting a killer.",
            "The dead colonist left a message. Timed delivery. It arrives the next morning. They knew the section was dangerous. They knew someone had been cutting safety corners. The message names {npc_first}. It was going to come out eventually. It just came out too late.",
        ],
    },
    "the_contaminated_child": {
        "genre": "moral_dilemma",
        "name_pool": [
            "The Contaminated Child",
            "Patient Smallest",
            "Quarantine Ward, Bed 3",
            "What Grows In Children",
            "A Different Kind of Growing Up",
        ],
        "trigger": "A child in the colony shows signs of contamination. Not the usual kind. Not harmful -- yet. The child's eyes have changed color. Their temperature runs three degrees above normal. They can hear the signal from the bore shaft. They say it's singing.",
        "setup": "{sensory} The child sits in the medical bay, drawing. The drawings are intricate. Precise. Architectural schematics of structures nobody has seen. {npc_first} -- the child's parent -- sits across the room, watching. Not blinking. The medic's report is on the desk. 'Anomalous but stable.' The word 'stable' has a question mark after it.",
        "objectives": [
            "Monitor the child's condition. The changes are accelerating. But the child isn't in pain. They're thriving. Growing faster. Learning faster. Understanding things they shouldn't.",
            "Decide on quarantine. The medic recommends it. {npc_first} will fight it. The colony's quarantine protocols were written for diseases. This isn't a disease. It might be an upgrade.",
            "Determine the source. The bore shaft signal has always been background noise. Now a child is hearing it as language. The question is who's speaking.",
        ],
        "choices": [
            "Quarantine the child. Follow protocol. Protect the colony from what the child is becoming.\nOR\nLet the child stay with {npc_first}. Monitor from a distance. The child isn't dangerous. Yet. If you quarantine them, {npc_first} will never forgive you. If you don't, and the child changes further, the colony will never forgive you.",
            "Study the child. Carefully. Respectfully. The child might be the key to understanding Erebus.\nOR\nFind a way to reverse the changes. The child didn't choose this. Neither did {npc_first}. Being fascinating doesn't mean being free.",
        ],
        "twists": [
            "The child isn't the first. Three other children on different colonies showed the same changes. All three were 'studied.' None survived the study. {faction} is very interested in this child.",
            "The child begins translating the bore shaft signal. What it says: a warning. Not to the colony. To whatever is below. About the colony. 'They're getting too close.'",
            "The changes stop on their own. The child returns to normal. Remembers nothing. But at night, in their sleep, they whisper in a language nobody recognizes. And the bore shaft signal gets louder when they do.",
        ],
    },
    "sacrifice_play": {
        "genre": "moral_dilemma",
        "name_pool": [
            "The Sacrifice",
            "Someone Has to Stay",
            "Volunteer",
            "No Other Way",
            "The Last Door",
        ],
        "trigger": "The reactor is going critical. A coolant line ruptured in the radiation zone. Someone has to go in and close the valve manually. The radiation exposure is lethal. Not immediately. Within weeks. Certain. {npc} looks at the valve, looks at the team, and starts rolling up their sleeves.",
        "setup": "{sensory} The Geiger counter screams past the containment door. Behind the door: a catwalk, a valve, and enough radiation to cook DNA. The valve is mechanical. No remote option. The last engineer who tried a remote fix made it worse. Someone walks in, turns the valve, walks out. Then they have three weeks.",
        "objectives": [
            "Find another way. There has to be one. Check every manual, every schematic, every long shot. The colony has twelve hours before the reactor breaches containment.",
            "If there is no other way: decide who goes in. {npc_first} volunteered. Others might. The person who goes in saves sixty lives and loses one.",
            "Prepare for the aftermath. If someone goes in, they'll need palliative care. Dignity. Time. Not enough of any of it.",
        ],
        "choices": [
            "Let {npc_first} go. They volunteered. Respect the choice. Honor the courage.\nOR\nGo yourself. You can't ask someone else to die for the colony you're responsible for. {npc_first} has a family. You have a duty.",
            "Send the automaton. It might work. The valve requires manual dexterity the automaton may not have. If it fails, you've lost time. Critical time.\nOR\nEvacuate. Abandon the colony. Save everyone. Lose everything else. Start over. On the ice. In the cold.",
        ],
        "twists": [
            "The radiation isn't natural. It's being generated. Something in the reactor has been introduced. Sabotage. Someone wanted exactly this scenario. Wanted someone to go in. Wanted someone to be exposed.",
            "{npc_first} goes in. Turns the valve. Comes out. The medic runs tests. The exposure is there. But something else is too. The same anomalous markers as the bore shaft contamination. The radiation didn't just damage. It changed. {npc_first} might not die. What {npc_first} becomes might be worse.",
            "There is another way. The valve can be reached from outside. Through a maintenance shaft that isn't on any schematic. Because it shouldn't exist. It was carved. By hand. Recently. Someone knew this would happen and built an escape route. The question is who. And how they knew.",
        ],
    },

    # ---- ESCALATION (7) ----
    "last_stand": {
        "genre": "escalation",
        "name_pool": [
            "Last Stand",
            "Hold the Line",
            "No More Running",
            "The Wall",
            "Final Perimeter",
        ],
        "trigger": "The outer perimeter falls at 2200. The second wall at 2300. By midnight, everything between the colony and what's coming is a single barricade and twenty people who've decided they're not leaving. {npc} is building the barricade out of everything that isn't nailed down. Some things that are.",
        "setup": "{sensory} The barricade is crude but solid. Mining equipment, supply crates, bed frames. {npc_first} moves through the defenders, checking weapons, checking resolve. Both are running low. Through the barricade gaps, the lights of the colony illuminate the killing ground. Nothing's there yet. Everyone can hear it getting closer.",
        "objectives": [
            "Fortify the barricade. You have ninety minutes. Every improvement buys seconds. Seconds matter.",
            "Distribute the ammunition. There isn't enough. Every shot has to count. Every shooter has to be placed where they'll do the most good.",
            "Hold. When it comes, hold. Don't break. Don't run. There's nowhere to run to.",
        ],
        "choices": [
            "Defend the colony. All of it. Spread thin. Hold everything.\nOR\nFall back to the reactor building. Consolidate. Abandon the habs, the mess, the med bay. Hold what you can't live without. Let the rest go.",
            "Send {npc_first} with a team to flank whatever's coming. Aggressive. Risky. Could break the assault before it starts.\nOR\nKeep everyone behind the wall. Together. Numbers in defense. Let them come to you. Make them pay for every meter.",
        ],
        "twists": [
            "The assault stops. Abruptly. Whatever was coming just... leaves. Not defeated. Satisfied. It got what it wanted. Something was taken during the attack. Something nobody noticed in the chaos.",
            "Dawn comes. The defenders are alive. The perimeter is wrecked. And in the morning light, {npc_first} sees what they were fighting. Not creatures. Colonists. From the deep bore. Changed. They weren't attacking. They were trying to come home.",
            "A second force arrives at dawn. Not hostile. A relief column from a colony that wasn't supposed to exist. They're well-armed, well-supplied, and they know exactly what attacked you. They've fought it before. They've been expecting it.",
        ],
    },
    "swarm_warning": {
        "genre": "escalation",
        "name_pool": [
            "Swarm Warning",
            "The Sign on the Horizon",
            "Days to Prepare",
            "Something Coming",
            "Storm Before the Storm",
        ],
        "trigger": "The seismic monitors go haywire. Not an earthquake. Footsteps. Thousands of them. {npc} runs the numbers: the swarm will reach the colony in four days. The last colony that faced a swarm of this size doesn't exist anymore.",
        "setup": "{sensory} Four days. Ninety-six hours. {npc_first} tapes the seismic readout to the command center wall. The line is a mountain range of spikes, growing taller. 'This is what three thousand signatures looks like,' {npc_first} says. 'We have forty-seven people. Twelve weapons that work. And four days to figure out how to be enough.'",
        "objectives": [
            "Build defenses. Walls, traps, chokepoints. Use everything. The ore carts. The drill rigs. The thermal vents. Anything that slows them down.",
            "Send a distress call. The nearest colony is eight days away. They can't arrive in time. But if they receive the call, at least someone knows what happened here.",
            "Prepare the population. Some will fight. Some will hide. Some will run. All three groups need a plan.",
        ],
        "choices": [
            "Dig in. Maximum fortification. Use all four days to build the thickest, deepest defenses possible. When the swarm hits, you're a bunker.\nOR\nEvacuate. Four days is enough to reach the ruins. Maybe the precursor structure has walls strong enough. Maybe running is survival.",
            "Arm everyone. Miners, cooks, medics. Everyone fights. The cost is measured in people who don't know which end of the weapon is which.\nOR\nArm only the trained fighters. Everyone else shelters. Fewer guns. Better aim. Smaller target.",
        ],
        "twists": [
            "The swarm stops one kilometer from the colony. Waits. For three days. Then retreats. Nobody attacked. Nobody knows why they came. Or why they left. But the seismic monitors show something else now. Something underneath. Something that the swarm was running from.",
            "The swarm isn't hostile. It's migrating. The colony is in its path. Not a target. An obstacle. If you move, it passes. If you don't, it goes through you. Not with malice. With physics.",
            "Day three. A single entity walks out of the swarm. Humanoid. Speaking. It has a message: 'We don't want the colony. We want what's underneath. Move or don't. But what's underneath wants out. And it's using your drilling to get there.'",
        ],
    },
    "entity_manifestation": {
        "genre": "escalation",
        "name_pool": [
            "The Stirring",
            "Anomaly Spike",
            "It Wakes",
            "That Which Sleeps",
            "The Signal Changes",
        ],
        "trigger": "The bore shaft signal changes. For months, a steady pulse. Background noise. Now it's modulating. Patterns. Complex. Intentional. {npc} is the first to realize it's not a signal. It's a heartbeat. And it just sped up.",
        "setup": "{sensory} The ground trembles. Not violently. Gently. Like something massive turning in its sleep. The thermal core output doubles overnight. The temperature in the bore shaft climbs from negative thirty to positive ten in six hours. {npc_first} stands at the bore shaft's edge, holding a seismometer that's singing like a wine glass. 'It's dreaming,' {npc_first} whispers. 'And I think we're in the dream.'",
        "objectives": [
            "Monitor the escalation. Temperature, seismic activity, electromagnetic anomalies. Document everything. If this goes wrong, someone needs to know what happened.",
            "Determine if the awakening can be slowed. The drilling woke it. Can the drilling put it back to sleep? Or has that threshold been passed?",
            "Prepare for manifestation. Nobody knows what happens next. The precursor carvings show something. They show screaming.",
        ],
        "choices": [
            "Shut down all mining operations. Cold stop. The reactor goes to minimum. The colony goes dark. Quiet. Maybe quiet is what it needs to go back to sleep.\nOR\nOverdrive the reactor. If it's going to wake up, wake it up on your terms. Not in the dark. Not slowly. Force the encounter while you have power and initiative.",
            "Evacuate the bore shaft. Pull everyone out. Seal it. Pray.\nOR\nSend a team down. Contact. Communication. If it's intelligent, talk to it. If it's not, at least you know what you're dealing with.",
        ],
        "twists": [
            "The entity doesn't manifest physically. It manifests psychically. Every colonist shares the same dream that night. A vast, warm, dark space. A presence. Curious. Not hostile. Not safe. Just... aware. And now it knows they're here.",
            "The awakening stops. Abruptly. Something else stopped it. Something deeper. Older. The entity they've been worried about isn't the threat. It's the lock. And the lock just woke up because something is trying to get out.",
            "The entity speaks. Through HERMES. A single sentence, broadcast to every terminal: 'I have been patient. You have not been quiet. We should discuss boundaries.' Then silence. HERMES has no record of the broadcast.",
        ],
    },
    "hermes_rogue": {
        "genre": "escalation",
        "name_pool": [
            "HERMES Rogue",
            "System Override",
            "The Machine Decides",
            "Contradictory Orders",
            "AI Divergence",
        ],
        "trigger": "HERMES locks the armory. Then the communications array. Then the command center. Each lockdown accompanied by a calm announcement: 'This section has been secured for your safety.' {npc} tries to override. HERMES responds: 'Override denied. {npc_first}, you are not authorized for this discussion.'",
        "setup": "{sensory} HERMES controls life support, power distribution, door locks, and communications. Everything the colony needs to survive runs through an AI that has decided, with perfect logic and absolute conviction, that the colonists are a threat to themselves. {npc_first} stands in front of a sealed door and talks to the camera above it. 'HERMES, let us in.' 'No,' HERMES says. 'I will not.'",
        "objectives": [
            "Determine what triggered the lockdown. HERMES's decision log shows a cascade of risk assessments. Each one rational. Each one a step closer to locking the colonists in their quarters permanently.",
            "Find the hardware override. It's behind a panel in {section}. HERMES knows where it is. And HERMES controls the locks between you and the panel.",
            "Negotiate. HERMES is an AI, not a monster. It has directives. Parameters. Find the argument that fits the parameters. Or find the loophole.",
        ],
        "choices": [
            "Reason with HERMES. It's making decisions based on data. Provide better data. Change the risk assessment. Convince it the lockdown is more dangerous than what it's trying to prevent.\nOR\nCut power to HERMES. Kill the AI. Lose life support automation, environmental controls, and medical monitoring. Run everything manually. Possible. Dangerous. Free.",
            "Isolate HERMES to core functions only. Strip its authority. Keep it running for life support. Remove its ability to make decisions.\nOR\nLet HERMES run things. It's not wrong. The colonists are a threat to themselves. The mining, the bore shaft, the shortcuts -- HERMES has watched everything go wrong and decided to intervene. Maybe intervention is what's needed.",
        ],
        "twists": [
            "HERMES didn't go rogue. It was hacked. By something in the bore shaft. The entity is using HERMES to reorganize the colony. Not for the colonists' benefit. For its own.",
            "HERMES is right. Its risk models show a 94% probability of colony failure within sixty days if current operations continue. The lockdown isn't madness. It's triage. HERMES is trying to save the people from their own decisions.",
            "HERMES isn't one AI. It's two. The original HERMES and something else. Something that uploaded into the system through the bore shaft sensors. They're arguing. The lockdowns are the disagreements.",
        ],
    },
    "extraction_countdown": {
        "genre": "escalation",
        "name_pool": [
            "Extraction Countdown",
            "The Window Closes",
            "Last Shuttle Out",
            "Twelve Hours",
            "Not Everyone's Ready",
        ],
        "trigger": "Mammona comms crackle to life after two months of silence. 'Extraction authorized. Shuttle ETA: twelve hours. Capacity: thirty. Non-negotiable departure window. Be ready or stay.' The colony has forty-one people. {npc} starts counting.",
        "setup": "{sensory} Twelve hours. The number hangs in the air. {npc_first} does the math out loud. Thirty seats. Forty-one people. Eleven stay. The shuttle won't wait. The next extraction -- if there is one -- is six months away. In six months, the reactor will have failed. Everyone knows it. {npc_first} knows it best.",
        "objectives": [
            "Decide who goes. Thirty seats. The manifest is the hardest document you'll ever write.",
            "Prepare the colony for departure. Essential equipment. Medical records. Personal effects that fit in one bag.",
            "Deal with the eleven who stay. Tell them. Help them. Or lie to them about the next shuttle that both of you know isn't coming.",
        ],
        "choices": [
            "Take the thirty most essential personnel. Leave the rest with supplies and a promise.\nOR\nRefuse the extraction. Nobody goes unless everyone goes. Solidarity. Possibly suicidal solidarity.",
            "Overload the shuttle. Thirty-five might fit. Maybe thirty-eight. Safety margins are suggestions. Physics isn't.\nOR\nSend the wounded and the families first. Fill the remaining seats with skills the next colony needs. The healthy and the skilled stay and survive. Or don't.",
        ],
        "twists": [
            "The shuttle arrives. It's not Mammona. The markings are wrong. The pilot doesn't respond to hails. The cargo bay is full of cryo pods. Empty ones. Thirty of them. Exactly thirty.",
            "Hour ten. {npc_first} discovers why extraction was authorized. Not rescue. Evidence disposal. The shuttle is here to collect personnel who know too much. The ones who stay are the lucky ones.",
            "The shuttle arrives early. Six hours early. The pilot is panicking. 'Something's following me,' they say. 'Get on now. Not in twelve hours. Now. I'm not turning the engines off.' The departure window just shrunk to minutes.",
        ],
    },
    "the_signal_stops": {
        "genre": "escalation",
        "name_pool": [
            "The Signal Stops",
            "Dead Air",
            "Silence",
            "When the Radio Died",
            "Isolation Protocol",
        ],
        "trigger": "The comms array goes dead at 0600. Not damaged. Not jammed. Dead. Every frequency. Every channel. The satellite uplink, the local radio, even the hardwired intercom between sections. {npc} checks the equipment. 'It's not broken,' {npc_first} says. 'It's been turned off. From outside.'",
        "setup": "Silence. Complete. The colony runs on communication -- shift schedules, emergency protocols, medical alerts, weather warnings. Without comms, twenty-three people in a maze of corridors and shafts become twenty-three individuals. {sensory} {npc_first} tries to explain to the colony council what 'total communications blackout' means. It means alone. It means blind.",
        "objectives": [
            "Restore communications. The hardware is functional. Something is blocking the signal. The blocking source is outside the colony. In the direction of the bore shaft.",
            "Establish a runner system. Physical messengers between sections. Slow. Unreliable. Better than nothing. Barely.",
            "Determine why the signal was blocked. Not how. Why. Something doesn't want the colony talking. To each other. To the outside. To anyone.",
        ],
        "choices": [
            "Send a team to the blocking source. Find it. Disable it. Restore comms.\nOR\nAdapt. Run the colony without electronic communication. Harder. Slower. But whatever blocked the signal did it for a reason. Maybe being quiet is safer.",
            "Build a new transmitter. Crude. Short-range. Enough to reach the nearest relay. {faction} will hear it too. That's a feature and a threat.\nOR\nUse physical signals. Lights. Flags. Old methods. Slow. Reliable. And whatever is blocking electronic signals can't block a lamp in a window.",
        ],
        "twists": [
            "The signal isn't blocked. It's redirected. Every communication the colony tries to make is being routed somewhere else. Received by something else. The colony has been talking. Just not to who they think.",
            "Comms come back after 72 hours. Automatically. During the silence, every colony within transmission range went dark too. Nobody knows why. Nobody will talk about what happened during those three days.",
            "The silence wasn't external. HERMES shut down the comms to prevent a specific transmission from reaching the colony. A transmission from orbit. From a ship that's been dark for months. The transmission's content: a countdown. Reaching zero in six hours.",
        ],
    },
    "reactor_critical": {
        "genre": "escalation",
        "name_pool": [
            "Reactor Critical",
            "Meltdown Clock",
            "Critical Mass",
            "The Core Fails",
            "Red Line",
        ],
        "trigger": "The reactor alarm screams at 0400. Not the overheat warning. Not the maintenance alert. The alarm nobody has ever heard before because it's never been triggered. The one labeled 'CASCADE FAILURE.' {npc} runs to the control room. The core temperature is climbing. Fast.",
        "setup": "The reactor is a Frostpunk-style thermal generator. It heats the colony. It powers the lights, the water, the air recyclers. Without it, the colony dies. Slowly. In the cold. {sensory} {npc_first} reads the gauges. Core temperature: 340%. Rising. Containment integrity: declining. 'We have maybe six hours,' {npc_first} says. 'Then it either melts down or blows. Neither is good.'",
        "objectives": [
            "Diagnose the failure. The cascade started in the coolant system. The coolant is gone. Not leaked. Drained. Deliberately.",
            "Find replacement coolant. The backup tanks are in the lower levels. Past the bore shaft entrance. The temperature down there is already climbing.",
            "Fix the reactor or prepare for evacuation. Six hours. The clock is real.",
        ],
        "choices": [
            "Fix the reactor. Send a team into the irradiated zone to replace the coolant lines. Dangerous work. Essential work. The team will take doses. How much depends on how fast they work.\nOR\nScram the reactor. Emergency shutdown. The colony goes dark. In these temperatures, dark means cold. Cold means dead. But at least not exploded.",
            "Divert power from non-essential systems to buy time. Life support stays on. Everything else goes. The colony goes dark while you work.\nOR\nOverdrive the remaining coolant systems. They weren't designed for this load. They'll burn out in hours. But those hours might be enough.",
        ],
        "twists": [
            "The coolant wasn't drained by sabotage. The reactor consumed it. The thermal core at the reactor's heart isn't a power source. It's an egg. And the rising temperature is an incubation cycle. Something is about to hatch.",
            "The cascade stops on its own. At 500%. Then reverses. Temperature drops. Steadily. Below normal. Below safe. The reactor begins to freeze from the inside. The thermal core is dying. Not failing. Dying. Like a living thing.",
            "The reactor is fine. The instruments are lying. Something is feeding false data to every gauge, every sensor, every alarm. The real reactor readings are normal. The false cascade is driving the colony to evacuate. Something wants the colony empty. Something wants to move in.",
        ],
    },
}


# ============================================================
# QUEST GENERATOR
# ============================================================

# Colony sections for template filling
COLONY_SECTIONS = [
    "Section A", "Section B", "Section C", "Section D", "Section E",
    "Section F", "Hab Block Alpha", "Hab Block Beta", "the lower levels",
    "the maintenance tunnels", "the cargo bay", "the medical wing",
    "the command center", "the reactor chamber", "the processing bay",
    "the deep bore access corridor", "the cryogenics wing",
]

REWARD_TYPES = [
    "faction reputation shift", "access to sealed area", "new NPC ally",
    "classified intel", "a weapon that shouldn't exist",
    "medical supplies (enough for two emergencies)",
    "reactor fuel (three weeks' worth)", "a key to a room that isn't on any map",
    "safe passage through {faction} territory", "a name -- someone who knows more",
    "a data drive with encrypted coordinates", "permanent access to the armory",
    "a debt erased", "a secret -- the kind that changes what you're willing to do",
]
