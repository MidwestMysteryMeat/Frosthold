-- quest_gen.lua -- Quest generation logic
-- All quest type generators: adlib, faction, threat, expedition, visitor petition,
-- quest chain, colonist personal, raid mission.
-- Separated from quest.lua lifecycle to keep files focused.

local ECS        = require('src.ecs.ecs')
local GameState  = require('src.game_state')
local Objectives = require('src.quest.quest_objectives')

local ok_adlib, Adlib = pcall(require, 'src.util.adlib')

local QuestGen = {}

---------------------------------------------------------------------------
-- Difficulty scaling
---------------------------------------------------------------------------

local function getDifficultyMult()
    local day = GameState.day or 1
    local wealth = GameState.getColonyWealth()
    local dayFactor = 0.5 + math.min(1.0, (day - 1) / 60)
    local wealthFactor = 0.8 + math.min(0.7, wealth / 3000)
    return dayFactor * wealthFactor
end

local function getStarRating(diffMult)
    if diffMult < 0.8 then return 1 end
    if diffMult < 1.3 then return 2 end
    return 3
end

local function scaleCount(base, diffMult)
    return math.max(1, math.floor(base * diffMult + 0.5))
end

local function scaleReward(base, diffMult)
    return math.max(1, math.floor(base * (0.7 + diffMult * 0.6) + 0.5))
end

QuestGen.getDifficultyMult = getDifficultyMult
QuestGen.getStarRating = getStarRating
QuestGen.scaleReward = scaleReward

---------------------------------------------------------------------------
-- Faction quest definitions
---------------------------------------------------------------------------

local FACTION_QUEST_DEFS = {
    mammona_logistics = {
        {
            type   = 'deliver',
            title  = 'Mammona Supply Requisition',
            desc   = 'Mammona Logistics wants %d %s delivered. They pay on receipt.',
            resources = { 'fuel', 'food', 'wood' },
            countRange = { 10, 30 },
            rewardBase = { thermalCores = 4 },
        },
        {
            type   = 'hunt',
            title  = 'Mammona Pest Control Contract',
            desc   = 'Mammona posted a bounty. Kill %d %s near their supply routes.',
            rewardBase = { thermalCores = 3 },
        },
    },
    mastema_ops = {
        {
            type   = 'hunt',
            title  = 'MasTema Retrieval: Hostile Fauna',
            desc   = 'MasTema wants biological samples. Kill %d %s. They pay well.',
            rewardBase = { thermalCores = 5 },
        },
        {
            type   = 'deliver',
            title  = 'MasTema Asset Exchange',
            desc   = 'MasTema is buying %d %s. No questions asked.',
            resources = { 'metal', 'components', 'steel' },
            countRange = { 5, 15 },
            rewardBase = { thermalCores = 6 },
        },
    },
    scavenger_crews = {
        {
            type   = 'deliver',
            title  = 'Scavenger Supply Run',
            desc   = 'A scavenger crew needs %d %s to survive the season. Help them out.',
            resources = { 'food', 'fuel', 'wood', 'hide' },
            countRange = { 8, 25 },
            rewardBase = { thermalCores = 3 },
        },
        {
            type   = 'defend_colony',
            title  = 'Scavenger Mutual Defense Pact',
            desc   = 'Scavenger crews warn of incoming hostiles. Survive the attack and they will share salvage.',
            raidDelay = { 1, 3 },
            rewardBase = { thermalCores = 5 },
        },
    },
    rim_runners = {
        {
            type   = 'deliver',
            title  = 'Rim Runner Trade Route',
            desc   = 'Rim Runners need %d %s for their next caravan. Good rate.',
            resources = { 'components', 'metal', 'circuit' },
            countRange = { 3, 12 },
            rewardBase = { thermalCores = 4 },
        },
    },
    ruin_delvers = {
        {
            type   = 'expedition',
            title  = 'Delver Expedition Request',
            desc   = 'Ruin Delvers have marked a precursor site. Send a team to investigate.',
            rewardBase = { thermalCores = 4 },
        },
        {
            type   = 'deliver',
            title  = 'Delver Research Materials',
            desc   = 'Ruin Delvers need %d %s for their field lab.',
            resources = { 'components', 'glass', 'circuit' },
            countRange = { 3, 10 },
            rewardBase = { thermalCores = 3 },
        },
    },
    black_maw = {
        {
            type   = 'hunt',
            title  = 'Black Maw Bounty',
            desc   = 'Black Maw wants %d %s cleared from their freight corridor.',
            rewardBase = { thermalCores = 5 },
        },
        {
            type   = 'deliver',
            title  = 'Black Maw Resupply',
            desc   = 'Black Maw needs %d %s. They pay well and don\'t ask where it came from.',
            resources = { 'fuel', 'metal', 'steel' },
            countRange = { 8, 20 },
            rewardBase = { thermalCores = 5 },
        },
    },
    void_serpents = {
        {
            type   = 'deliver',
            title  = 'Void Serpent Data Exchange',
            desc   = 'Void Serpents want %d %s. They\'ll share intel in return.',
            resources = { 'components', 'circuit' },
            countRange = { 3, 8 },
            rewardBase = { thermalCores = 4 },
        },
    },
    rust_reavers = {
        {
            type   = 'deliver',
            title  = 'Rust Reaver Parts Request',
            desc   = 'Reavers need %d %s for a salvage operation. Scraps for cores.',
            resources = { 'metal', 'components', 'steel' },
            countRange = { 5, 15 },
            rewardBase = { thermalCores = 3 },
        },
    },
    zenith_syndicate = {
        {
            type   = 'deliver',
            title  = 'Zenith Syndicate Tribute',
            desc   = 'Zenith Syndicate wants %d %s. Refusal has consequences.',
            resources = { 'food', 'fuel' },
            countRange = { 10, 25 },
            rewardBase = { thermalCores = 4 },
        },
        {
            type   = 'hunt',
            title  = 'Zenith Syndicate Contract Hit',
            desc   = 'Zenith wants %d %s eliminated. No questions. Good pay.',
            rewardBase = { thermalCores = 6 },
        },
    },
    solar_nomads = {
        {
            type   = 'deliver',
            title  = 'Solar Nomad Provisions',
            desc   = 'Nomads passing through need %d %s to survive the crossing.',
            resources = { 'food', 'fuel', 'hide' },
            countRange = { 8, 20 },
            rewardBase = { thermalCores = 3 },
        },
    },
    sons_of_pale_moon = {
        {
            type   = 'expedition',
            title  = 'Pale Moon Pilgrimage',
            desc   = 'The Sons want access to a precursor site. Escort their priest.',
            rewardBase = { thermalCores = 5 },
        },
        {
            type   = 'deliver',
            title  = 'Pale Moon Offering',
            desc   = 'The Sons request %d %s for a ritual. They\'re vague about the details.',
            resources = { 'thermalCores', 'components' },
            countRange = { 2, 6 },
            rewardBase = { thermalCores = 4 },
        },
    },
}

---------------------------------------------------------------------------
-- Threat-attached quest types
---------------------------------------------------------------------------

local THREAT_TYPES = {
    threatened_joiner = {
        title  = 'Threatened Survivor: %s',
        desc   = '%s is fleeing hostile creatures. Take them in, but expect pursuit.',
        raidDelay = { 1, 2 },
        rewardColonist = true,
    },
    defend_contract = {
        title  = 'Defense Contract: Hold the Line',
        desc   = 'Intel says a coordinated attack is inbound. Survive and claim the bounty.',
        raidDelay = { 0, 1 },
        raidBudgetMult = 1.5,
    },
}

---------------------------------------------------------------------------
-- Quest chain definitions
---------------------------------------------------------------------------

local CHAIN_DEFS = {
    supply_line = {
        name = 'Supply Line',
        total = 3,
        steps = {
            [1] = {
                title = 'Supply Line: Initial Shipment',
                desc = 'Deliver the first shipment. Opens a new trade route.',
                type = 'deliver',
                genObjectives = function(dm)
                    local r = ({ 'food', 'fuel', 'wood' })[math.random(3)]
                    return { Objectives.create('deliver', { resource = r, count = scaleCount(15, dm) }) }
                end,
                rewardBase = { thermalCores = 3 },
                timeLimit = 10,
                boardTTL = 8,
            },
            [2] = {
                title = 'Supply Line: Secure the Route',
                desc = 'Hostiles threaten the new supply route. Defend it.',
                type = 'defend',
                genObjectives = function(dm)
                    return { Objectives.create('defend', { count = 1 }) }
                end,
                rewardBase = { thermalCores = 5 },
                threatInfo = { raidDelay = 2, raidBudgetMult = 1.2, source = 'chain_quest' },
                timeLimit = 8,
                boardTTL = 3,
            },
            [3] = {
                title = 'Supply Line: Full Payment',
                desc = 'The route is secure. Complete the final delivery.',
                type = 'deliver',
                genObjectives = function(dm)
                    return { Objectives.create('deliver', { resource = 'metal', count = scaleCount(10, dm) }) }
                end,
                rewardBase = { thermalCores = 8 },
                timeLimit = 12,
                boardTTL = 5,
            },
        },
    },
    lost_expedition = {
        name = 'Lost Expedition',
        total = 3,
        steps = {
            [1] = {
                title = 'Lost Expedition: Search Party',
                desc = 'A previous expedition went silent. Send a team to investigate.',
                type = 'expedition',
                genObjectives = function()
                    return { Objectives.create('expedition', { destId = nil }) }
                end,
                rewardBase = { thermalCores = 4 },
                timeLimit = 0,
                boardTTL = 6,
            },
            [2] = {
                title = 'Lost Expedition: Clear the Area',
                desc = 'Survivors located. Clear hostile creatures from the area.',
                type = 'hunt',
                genObjectives = function(dm)
                    return { Objectives.create('kill', { species = nil, count = scaleCount(4, dm) }) }
                end,
                rewardBase = { thermalCores = 5, colonist = true },
                timeLimit = 10,
                boardTTL = 4,
            },
            [3] = {
                title = 'Lost Expedition: The Pursuit',
                desc = 'Something followed the survivors back. Defend the colony.',
                type = 'defend',
                genObjectives = function()
                    return { Objectives.create('defend', { count = 1 }) }
                end,
                rewardBase = { thermalCores = 6 },
                threatInfo = { raidDelay = 1, raidBudgetMult = 1.5, source = 'chain_quest' },
                timeLimit = 5,
                boardTTL = 2,
            },
        },
    },
    faction_alliance = {
        name = 'Faction Alliance',
        total = 3,
        steps = {
            [1] = {
                title = 'Alliance: Opening Tribute',
                desc = 'They want a tribute up front. Prove you\'re worth talking to.',
                type = 'deliver',
                genObjectives = function(dm)
                    local r = ({ 'food', 'fuel', 'metal' })[math.random(3)]
                    return { Objectives.create('deliver', { resource = r, count = scaleCount(12, dm) }) }
                end,
                rewardBase = { thermalCores = 2 },
                timeLimit = 8,
                boardTTL = 6,
            },
            [2] = {
                title = 'Alliance: Mutual Aid',
                desc = 'They need a favor. Do it and they\'ll remember.',
                type = 'hunt',
                genObjectives = function(dm)
                    return { Objectives.create('kill', { species = nil, count = scaleCount(3, dm) }) }
                end,
                rewardBase = { thermalCores = 4 },
                timeLimit = 12,
                boardTTL = 4,
            },
            [3] = {
                title = 'Alliance: Defense Pact',
                desc = 'Joint defense operation. Survive the attack and the alliance is official.',
                type = 'defend',
                genObjectives = function()
                    return { Objectives.create('defend', { count = 1 }) }
                end,
                rewardBase = { thermalCores = 6 },
                threatInfo = { raidDelay = 2, raidBudgetMult = 1.3, source = 'chain_quest' },
                timeLimit = 6,
                boardTTL = 3,
            },
        },
    },
}

QuestGen.CHAIN_DEFS = CHAIN_DEFS

---------------------------------------------------------------------------
-- Visitor petition templates
---------------------------------------------------------------------------

local VISITOR_PETITIONS = {
    {
        title = 'Shelter Request',
        genQuest = function(dm)
            local days = scaleCount(3, dm)
            return {
                desc = string.format('A traveler asks to sleep inside your walls for %d days.', days),
                objectives = { Objectives.create('survive', { days = days }) },
            }
        end,
        rewardBase = { thermalCores = 2, colonist = true },
    },
    {
        title = 'Medical Aid',
        genQuest = function()
            return {
                desc = 'A wounded traveler needs treatment for two days or they will not make it.',
                objectives = { Objectives.create('survive', { days = 2 }) },
            }
        end,
        rewardBase = { thermalCores = 3 },
    },
    {
        title = 'Supply Request',
        genQuest = function(dm)
            local resources = { 'food', 'fuel', 'wood' }
            local res = resources[math.random(#resources)]
            local count = scaleCount(8, dm)
            return {
                desc = string.format('Travelers need %d %s to make the next crossing.', count, res),
                objectives = { Objectives.create('deliver', { resource = res, count = count }) },
            }
        end,
        rewardBase = { thermalCores = 2 },
    },
    {
        title = 'Camp Build Request',
        genQuest = function()
            local buildings = { 'campfire', 'torch', 'shelter' }
            local buildId = buildings[math.random(#buildings)]
            return {
                desc = string.format('A group outside the walls needs a %s before nightfall.', buildId),
                objectives = { Objectives.create('build', { buildId = buildId, count = 1 }) },
            }
        end,
        rewardBase = { thermalCores = 3 },
    },
}

---------------------------------------------------------------------------
-- Colonist quest definitions (trait -> quest template)
---------------------------------------------------------------------------

local COLONIST_QUEST_DEFS = {
    ex_soldier = {
        title = '%s: Unfinished Business',
        desc  = '%s remembers dangerous creatures from their past. Hunt them down.',
        genObjectives = function(dm)
            return { Objectives.create('kill', { species = nil, count = scaleCount(3, dm) }) }
        end,
        rewardBase = { thermalCores = 4 },
    },
    tinkerer = {
        title = '%s: Prototype Project',
        desc  = '%s has an idea for a device. Gather the components.',
        genObjectives = function(dm)
            return { Objectives.create('gather', { resource = 'components', count = scaleCount(5, dm) }) }
        end,
        rewardBase = { thermalCores = 3, knowledge = true },
    },
    former_doc = {
        title = '%s: Medical Research',
        desc  = '%s wants to study local biology. Gather samples.',
        genObjectives = function(dm)
            return { Objectives.create('gather', { resource = 'hide', count = scaleCount(8, dm) }) }
        end,
        rewardBase = { thermalCores = 3, knowledge = true },
    },
    green_thumb = {
        title = '%s: Cultivation Experiment',
        desc  = '%s wants to try growing food in the cold. Set aside supplies.',
        genObjectives = function(dm)
            return { Objectives.create('gather', { resource = 'food', count = scaleCount(20, dm) }) }
        end,
        rewardBase = { thermalCores = 3 },
    },
    eagle_eye = {
        title = '%s: Scouting Report',
        desc  = '%s spotted something on the horizon. Send an expedition to investigate.',
        genObjectives = function()
            return { Objectives.create('expedition', { destId = nil }) }
        end,
        rewardBase = { thermalCores = 4 },
    },
    anomaly_sensitive = {
        title = '%s: Signal in the Ice',
        desc  = '%s says there\'s something at the precursor site. Keeps pointing at the readings.',
        genObjectives = function()
            return { Objectives.create('expedition', { destId = 'ancient_ruins' }) }
        end,
        rewardBase = { thermalCores = 6 },
    },
}

---------------------------------------------------------------------------
-- Exclusive rewards (quest-only unique items)
---------------------------------------------------------------------------

local EXCLUSIVE_REWARDS = {
    { id = 'thermal_lance',   name = 'Thermal Lance',   desc = 'Prototype energy weapon. Spawns one.',           minStars = 2, thermalCores = 12, grantItem = 'weapon_thermal_lance' },
    { id = 'arctic_exoframe', name = 'Arctic Exoframe', desc = 'Colony cold resistance +20%.',                   minStars = 3, thermalCores = 15 },
    { id = 'precursor_core',  name = 'Precursor Core',  desc = 'Alien power source. +50W to grid.',              minStars = 2, thermalCores = 10 },
    { id = 'signal_jammer',   name = 'Signal Jammer',   desc = 'Reduces heat signature by 30%.',                 minStars = 3, thermalCores = 14 },
    { id = 'cryo_stabilizer', name = 'Cryo Stabilizer', desc = 'Colony frostbite threshold +50%.',               minStars = 2, thermalCores = 8 },
}

QuestGen.EXCLUSIVE_REWARDS = EXCLUSIVE_REWARDS

local function pickExclusiveReward(stars)
    local pool = {}
    for _, er in ipairs(EXCLUSIVE_REWARDS) do
        if stars >= er.minStars then pool[#pool + 1] = er end
    end
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

---------------------------------------------------------------------------
-- Build objectives for adlib quest types
---------------------------------------------------------------------------

local function buildObjectives(questType, diffMult)
    if questType == 'hunt' then
        local species = nil
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok and Creatures.SPECIES then
            local pool = {}
            local tier = diffMult >= 1.2 and 'medium' or 'small'
            for sp, def in pairs(Creatures.SPECIES) do
                if def.tier == tier or def.tier == 'small' then
                    pool[#pool + 1] = sp
                end
            end
            if #pool > 0 then species = pool[math.random(#pool)] end
        end
        local count = scaleCount(1 + math.random(2), diffMult)
        return { { type = 'kill', params = { species = species, count = count } } }

    elseif questType == 'rescue' or questType == 'scout'
        or questType == 'investigate' or questType == 'escort'
        or questType == 'anomaly_investigation' then
        return { { type = 'expedition', params = { destId = nil } } }

    elseif questType == 'fetch' then
        local resources = { 'wood', 'metal', 'food', 'fuel', 'components' }
        local res = resources[math.random(#resources)]
        local count = scaleCount(5 + math.random(10), diffMult)
        return { { type = 'gather', params = { resource = res, count = count } } }

    elseif questType == 'defend' then
        local count = diffMult >= 1.3 and 2 or 1
        return { { type = 'defend', params = { count = count } } }

    else
        return { { type = 'gather', params = { resource = 'food', count = scaleCount(10, diffMult) } } }
    end
end

---------------------------------------------------------------------------
-- Scale reward table by difficulty
---------------------------------------------------------------------------

local function scaleRewards(reward, diffMult)
    local scaled = {}
    if reward.thermalCores then scaled.thermalCores = scaleReward(reward.thermalCores, diffMult) end
    if reward.reputation then scaled.reputation = scaleReward(reward.reputation, diffMult) end
    scaled.colonist  = reward.colonist or false
    scaled.resources = reward.resources or false
    scaled.knowledge = reward.knowledge or false
    return scaled
end

---------------------------------------------------------------------------
-- Generator: Expedition quest
---------------------------------------------------------------------------

local function generateExpeditionQuest(diffMult)
    local ook, Overworld = pcall(require, 'src.exploration.overworld')
    if not ook then return nil end
    local dests = Overworld.getAllDestinations()
    if not dests or #dests == 0 then return nil end
    local pick = dests[math.random(#dests)]
    return {
        title      = 'Expedition: ' .. pick.dest.name,
        desc       = 'Send a team to ' .. pick.dest.name .. ' and return alive.',
        type       = 'expedition_quest',
        objectives = { Objectives.create('expedition', { destId = pick.id }) },
        reward     = { thermalCores = scaleReward(2, diffMult) },
        timeLimit  = 0,
        difficulty = diffMult,
        stars      = getStarRating(diffMult),
    }
end

---------------------------------------------------------------------------
-- Generator: Faction quest
---------------------------------------------------------------------------

local function generateFactionQuest(diffMult)
    local fok, Factions = pcall(require, 'src.colony.factions')
    if not fok then return nil end
    local allFactions = Factions.getAll()
    local pool = {}
    for _, f in ipairs(allFactions) do
        if not Factions.isHostile(f.id) and FACTION_QUEST_DEFS[f.id] then
            pool[#pool + 1] = f
        end
    end
    if #pool == 0 then return nil end

    local faction = pool[math.random(#pool)]
    local defs = FACTION_QUEST_DEFS[faction.id]
    local def = defs[math.random(#defs)]

    local objectives = {}
    local title = def.title
    local desc = def.desc
    local reward = {}
    for k, v in pairs(def.rewardBase) do
        reward[k] = scaleReward(v, diffMult)
    end
    reward.factionId  = faction.id
    reward.factionRep = scaleReward(8, diffMult)

    local timeLimit = 0
    local threatInfo = nil

    if def.type == 'deliver' then
        local res = def.resources[math.random(#def.resources)]
        local minC = def.countRange[1]
        local maxC = def.countRange[2]
        local count = scaleCount(minC + math.random(maxC - minC), diffMult)
        desc = string.format(def.desc, count, res)
        objectives = { Objectives.create('deliver', { resource = res, count = count }) }
        timeLimit = math.max(5, math.floor(15 / diffMult + 0.5))

    elseif def.type == 'hunt' then
        local species = nil
        local cok, Creatures = pcall(require, 'src.creatures.creatures')
        if cok and Creatures.SPECIES then
            local spool = {}
            for sp, sdef in pairs(Creatures.SPECIES) do
                if sdef.tier == 'small' or sdef.tier == 'medium' then
                    spool[#spool + 1] = sp
                end
            end
            if #spool > 0 then species = spool[math.random(#spool)] end
        end
        local count = scaleCount(2, diffMult)
        desc = string.format(def.desc, count, species or 'hostiles')
        objectives = { Objectives.create('kill', { species = species, count = count }) }
        timeLimit = math.max(8, math.floor(20 / diffMult + 0.5))

    elseif def.type == 'expedition' then
        local ook, Overworld = pcall(require, 'src.exploration.overworld')
        if ook then
            local dests = Overworld.getAllDestinations()
            if dests and #dests > 0 then
                local pick = dests[math.random(#dests)]
                objectives = { Objectives.create('expedition', { destId = pick.id }) }
            end
        end
        if #objectives == 0 then
            objectives = { Objectives.create('expedition', { destId = nil }) }
        end

    elseif def.type == 'defend_colony' then
        objectives = { Objectives.create('defend', { count = 1 }) }
        local delayMin = def.raidDelay[1]
        local delayMax = def.raidDelay[2]
        threatInfo = {
            raidDelay      = delayMin + math.random(delayMax - delayMin),
            raidBudgetMult = 1.0 + diffMult * 0.3,
            source         = 'faction_quest',
        }
        timeLimit = math.max(5, math.floor(12 / diffMult + 0.5))
    end

    if #objectives == 0 then return nil end

    return {
        title       = title,
        desc        = desc,
        type        = def.type,
        objectives  = objectives,
        reward      = reward,
        timeLimit   = timeLimit,
        difficulty  = diffMult,
        stars       = getStarRating(diffMult),
        factionId   = faction.id,
        factionName = faction.name,
        threatInfo  = threatInfo,
    }
end

---------------------------------------------------------------------------
-- Generator: Threat-attached quest
---------------------------------------------------------------------------

local function generateThreatQuest(diffMult)
    if (GameState.day or 1) < 10 then return nil end

    local threatType = math.random() < 0.6 and 'threatened_joiner' or 'defend_contract'
    local def = THREAT_TYPES[threatType]

    local objectives = {}
    local reward = {}
    local title, desc

    if threatType == 'threatened_joiner' then
        local name = 'Unknown Survivor'
        if ok_adlib then name = Adlib.generateName() end
        title = string.format(def.title, name)
        desc  = string.format(def.desc, name)
        objectives = { Objectives.create('defend', { count = 1 }) }
        reward = { thermalCores = scaleReward(2, diffMult), colonist = true }
    else
        title = def.title
        desc  = def.desc
        local raidCount = diffMult >= 1.3 and 2 or 1
        objectives = { Objectives.create('defend', { count = raidCount }) }
        reward = { thermalCores = scaleReward(6, diffMult) }
    end

    local minDelay = def.raidDelay[1]
    local maxDelay = def.raidDelay[2]
    local raidDelay = minDelay + math.random(maxDelay - minDelay)

    return {
        title      = title,
        desc       = desc,
        type       = threatType,
        objectives = objectives,
        reward     = reward,
        timeLimit  = raidDelay + math.max(3, math.floor(8 / diffMult + 0.5)),
        difficulty = diffMult,
        stars      = getStarRating(diffMult),
        threatInfo = {
            raidDelay      = raidDelay,
            raidBudgetMult = def.raidBudgetMult or (1.0 + diffMult * 0.3),
            source         = threatType,
        },
        boardTTL = 2,
    }
end

---------------------------------------------------------------------------
-- Generator: Containment contract
---------------------------------------------------------------------------

local function generateContainmentQuest(diffMult)
    if (GameState.day or 1) < 8 then return nil end

    local cok, Containment = pcall(require, 'src.sim.containment')
    if not cok or not Containment.getStats then return nil end

    local pending = Containment.hasPendingSubjects and Containment.hasPendingSubjects()
    local templates = {
        {
            title = 'Mammona Transfer Order',
            desc = 'The charter was for ore, but intact non-mining finds still ship uphill. Transfer %d intact subjects for Mammona cataloging.',
            objectives = function()
                return { Objectives.create('transfer_subject', { count = scaleCount(pending and 1 or 2, diffMult) }) }
            end,
            reward = { thermalCores = scaleReward(4, diffMult), factionId = 'mammona_logistics', factionRep = scaleReward(5, diffMult) },
        },
        {
            title = 'Frontier Recovery Sweep',
            desc = 'Command wants fresh field recoveries before the miners destroy the evidence. Recover %d anomaly subjects intact enough for catalog work.',
            objectives = function()
                return { Objectives.create('recover_subject', { count = scaleCount(pending and 1 or 2, diffMult) }) }
            end,
            reward = { thermalCores = scaleReward(4, diffMult), factionId = 'mammona_logistics', factionRep = scaleReward(4, diffMult) },
        },
        {
            title = 'HERMES Analysis Window',
            desc = 'HERMES requests fresh specimen work. Complete %d containment study cycles before the window closes.',
            objectives = function()
                return { Objectives.create('study_subject', { count = scaleCount(2, diffMult) }) }
            end,
            reward = { thermalCores = scaleReward(5, diffMult), knowledge = true },
        },
        {
            title = 'Quarantine Amnesty Review',
            desc = 'Command wants proof that at least %d contaminated survivors can still be stabilized and admitted.',
            objectives = function()
                return { Objectives.create('admit_subject', { count = 1 }) }
            end,
            reward = { thermalCores = scaleReward(6, diffMult), factionId = 'rim_runners', factionRep = scaleReward(4, diffMult) },
        },
        {
            title = 'Emergency Purge Directive',
            desc = 'Corporate traffic flagged a breach risk. Purge %d unstable subjects before it escalates.',
            objectives = function()
                return { Objectives.create('purge_subject', { count = scaleCount(1, diffMult) }) }
            end,
            reward = { thermalCores = scaleReward(5, diffMult), factionId = 'mammona_logistics', factionRep = scaleReward(3, diffMult) },
        },
    }

    local pick = templates[math.random(#templates)]
    local objectives = pick.objectives()
    if not objectives or #objectives == 0 then return nil end
    local target = objectives[1].target or 1

    return {
        title = pick.title,
        desc = string.format(pick.desc, target),
        type = 'containment_contract',
        objectives = objectives,
        reward = pick.reward,
        timeLimit = math.max(6, math.floor(12 / math.max(0.8, diffMult) + 0.5)),
        difficulty = math.max(1.0, diffMult),
        stars = math.max(2, getStarRating(diffMult)),
        boardTTL = 4,
    }
end

---------------------------------------------------------------------------
-- Generator: Standard adlib quest (scaled)
---------------------------------------------------------------------------

local function generateAdlibQuest(diffMult)
    if not ok_adlib then return nil end
    local adlibQuest = Adlib.generateQuest()
    if not adlibQuest then return nil end

    local objConfigs = buildObjectives(adlibQuest.type, diffMult)
    local objectives = {}
    for _, cfg in ipairs(objConfigs) do
        local obj = Objectives.create(cfg.type, cfg.params)
        if obj then objectives[#objectives + 1] = obj end
    end
    if #objectives == 0 then return nil end

    local timeLimit = 0
    if adlibQuest.type == 'defend' or adlibQuest.type == 'hunt' then
        timeLimit = math.max(5, math.floor((10 + math.random(15)) / diffMult + 0.5))
    end

    local stars = getStarRating(diffMult)
    local exclusiveReward = nil
    if stars >= 2 and math.random() < 0.15 then
        exclusiveReward = pickExclusiveReward(stars)
    end

    return {
        title           = adlibQuest.title,
        desc            = adlibQuest.desc,
        type            = adlibQuest.type,
        objectives      = objectives,
        reward          = scaleRewards(adlibQuest.reward, diffMult),
        timeLimit       = timeLimit,
        difficulty      = diffMult,
        stars           = stars,
        exclusiveReward = exclusiveReward,
    }
end

---------------------------------------------------------------------------
-- Generator: Visitor petition
---------------------------------------------------------------------------

local function generateVisitorPetition(diffMult)
    if (GameState.day or 1) < 5 then return nil end
    local template = VISITOR_PETITIONS[math.random(#VISITOR_PETITIONS)]
    local result = template.genQuest(diffMult)
    if not result or not result.objectives or #result.objectives == 0 then return nil end

    local reward = {}
    for k, v in pairs(template.rewardBase) do
        if type(v) == 'number' then
            reward[k] = scaleReward(v, diffMult)
        else
            reward[k] = v
        end
    end

    return {
        title      = template.title,
        desc       = result.desc,
        type       = 'visitor_petition',
        objectives = result.objectives,
        reward     = reward,
        timeLimit  = math.max(5, math.floor(10 / diffMult + 0.5)),
        difficulty = diffMult,
        stars      = getStarRating(diffMult),
        boardTTL   = 3,
    }
end

---------------------------------------------------------------------------
-- Generator: Quest chain step
---------------------------------------------------------------------------

function QuestGen.generateChainStep(chainId, step, total, diffMult)
    local chainDef = CHAIN_DEFS[chainId]
    if not chainDef then return nil end
    local stepDef = chainDef.steps[step]
    if not stepDef then return nil end

    diffMult = diffMult or getDifficultyMult()
    local objectives = stepDef.genObjectives(diffMult)
    if not objectives or #objectives == 0 then return nil end

    local reward = {}
    for k, v in pairs(stepDef.rewardBase) do
        if type(v) == 'number' then
            reward[k] = scaleReward(v, diffMult)
        else
            reward[k] = v
        end
    end
    -- Final step bonus
    if step == total then
        reward.thermalCores = (reward.thermalCores or 0) + scaleReward(5, diffMult)
    end

    return {
        title      = stepDef.title,
        desc       = stepDef.desc,
        type       = stepDef.type,
        objectives = objectives,
        reward     = reward,
        timeLimit  = stepDef.timeLimit or 0,
        difficulty = diffMult,
        stars      = getStarRating(diffMult),
        chainId    = chainId,
        chainStep  = step,
        chainTotal = total,
        threatInfo = stepDef.threatInfo,
        boardTTL   = stepDef.boardTTL,
    }
end

local function generateChainQuest(diffMult)
    if (GameState.day or 1) < 15 then return nil end
    local chainIds = {}
    for id in pairs(CHAIN_DEFS) do chainIds[#chainIds + 1] = id end
    if #chainIds == 0 then return nil end
    local chainId = chainIds[math.random(#chainIds)]
    local chainDef = CHAIN_DEFS[chainId]
    return QuestGen.generateChainStep(chainId, 1, chainDef.total, diffMult)
end

---------------------------------------------------------------------------
-- Generator: Colonist-specific quest
---------------------------------------------------------------------------

local function generateColonistQuest(diffMult)
    if (GameState.day or 1) < 8 then return nil end
    local candidates = {}
    for id, comps in ECS.query('colonist') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.traits then
            for _, trait in ipairs(col.traits) do
                if COLONIST_QUEST_DEFS[trait.id] then
                    candidates[#candidates + 1] = { entityId = id, name = col.name, traitId = trait.id }
                end
            end
        end
    end
    if #candidates == 0 then return nil end

    local pick = candidates[math.random(#candidates)]
    local def = COLONIST_QUEST_DEFS[pick.traitId]
    local objectives = def.genObjectives(diffMult)
    if not objectives or #objectives == 0 then return nil end

    local reward = {}
    for k, v in pairs(def.rewardBase) do
        if type(v) == 'number' then
            reward[k] = scaleReward(v, diffMult)
        else
            reward[k] = v
        end
    end

    return {
        title      = string.format(def.title, pick.name),
        desc       = string.format(def.desc, pick.name),
        type       = 'colonist_personal',
        objectives = objectives,
        reward     = reward,
        timeLimit  = math.max(8, math.floor(20 / diffMult + 0.5)),
        difficulty = diffMult,
        stars      = getStarRating(diffMult),
        colonistId = pick.entityId,
    }
end

---------------------------------------------------------------------------
-- Generator: Off-map raid mission
---------------------------------------------------------------------------

local function generateRaidMission(diffMult)
    if (GameState.day or 1) < 20 then return nil end
    if diffMult < 0.8 then return nil end

    local targets = {
        { name = 'Outlaw Camp',    desc = 'Scout reports an outlaw camp nearby. Raid it for supplies.' },
        { name = 'Scavenger Cache', desc = 'A scavenger crew left a cache unguarded. Send a team to claim it.' },
        { name = 'Creature Den',   desc = 'A creature den holds valuable thermal cores. Clear it out.' },
    }
    local target = targets[math.random(#targets)]

    return {
        title      = 'Raid Mission: ' .. target.name,
        desc       = target.desc,
        type       = 'raid_mission',
        objectives = { Objectives.create('expedition', { destId = nil }) },
        reward     = { thermalCores = scaleReward(8, diffMult), resources = true },
        timeLimit  = 0,
        difficulty = diffMult,
        stars      = math.max(2, getStarRating(diffMult)),
    }
end

---------------------------------------------------------------------------
-- Planet-specific quest generators
---------------------------------------------------------------------------

local PLANET_QUESTS = {
    erebus = {
        { title = 'Deep Ice Survey', desc = 'Thermal anomaly detected beneath the glacier. Drill down and find out what is warming the rock.', objType = 'gather', resource = 'thermalCores', count = 5, reward = { thermalCores = 4 } },
        { title = 'Precursor Signal', desc = 'Faint signal from the ice shelf. Could be ruins. Could be worse. Send a team.', objType = 'expedition', reward = { thermalCores = 5 } },
        { title = 'Wolf Cull', desc = 'Pack of tundra wolves denned up too close. Thin the numbers before they get bold.', objType = 'kill', species = 'tundra_wolf', count = 4, reward = { thermalCores = 3 } },
        { title = 'Insulation Push', desc = 'Next cold snap will be bad. Get insulated walls up around the core buildings.', objType = 'build', buildId = 'wall_insulated', count = 12, reward = { thermalCores = 3 } },
        { title = 'Frozen Cache Run', desc = 'Prior expedition left a supply cache at the glacier edge. Bring it back before the ice shifts.', objType = 'gather', resource = 'metal', count = 25, reward = { thermalCores = 3 } },
    },
    rhea_2 = {
        { title = 'Water Cache Recovery', desc = 'Buried water reserve under the dunes. Dig it up before it evaporates.', objType = 'gather', resource = 'water', count = 30, reward = { thermalCores = 3 } },
        { title = 'Sandstorm Shelter', desc = 'Big sandstorm coming. Get the walls up before it hits.', objType = 'build', buildId = 'wall_metal', count = 10, reward = { thermalCores = 2 } },
        { title = 'Dune Stalker Hunt', desc = 'Dune stalkers circling the perimeter. Kill them before they come in.', objType = 'kill', species = 'dune_stalker', count = 3, reward = { thermalCores = 4, factionId = 'solar_nomads', factionRep = 10 } },
        { title = 'Oasis Expedition', desc = 'Rumor of a hidden oasis. Send a team to check it out.', objType = 'expedition', reward = { thermalCores = 4 } },
        { title = 'Sun Shrine Investigation', desc = 'The Sons of the Pale Moon want a nearby shrine explored. Relics inside.', objType = 'expedition', reward = { thermalCores = 5, factionId = 'sons_of_pale_moon', factionRep = 15 } },
    },
    morvos = {
        { title = 'Acid-Proof Seal', desc = 'Next acid storm will kill anyone near an open door. Seal the entrances.', objType = 'build', buildId = 'door_sealed', count = 5, reward = { thermalCores = 3 } },
        { title = 'Spore Sample Collection', desc = 'TerraGen wants spore samples from the acid marshes. Nasty work but they pay.', objType = 'gather', resource = 'food', count = 20, reward = { thermalCores = 5 } },
        { title = 'Corrosion Hound Pack', desc = 'Corrosion hounds denned up near the colony. Kill them.', objType = 'kill', species = 'corrosion_hound', count = 4, reward = { thermalCores = 3 } },
        { title = 'Toxic Zone Mapping', desc = 'Map the toxic marsh boundaries. Need to know where the acid stops.', objType = 'expedition', reward = { thermalCores = 4 } },
    },
    nerthus_9 = {
        { title = 'Flood Barrier Construction', desc = 'Monsoon season coming. Get seawalls up or the colony floods.', objType = 'build', buildId = 'seawall', count = 8, reward = { thermalCores = 4 } },
        { title = 'Deep Water Salvage', desc = 'Sunken wreck in the shallows. Strip it for metal.', objType = 'gather', resource = 'metal', count = 30, reward = { thermalCores = 3 } },
        { title = 'Reef Shark Cull', desc = 'Reef sharks in the fishing grounds. Kill enough to clear the area.', objType = 'kill', species = 'reef_shark', count = 3, reward = { thermalCores = 3 } },
        { title = 'Tidal Pattern Study', desc = 'Figure out the tidal patterns before the next flood hits.', objType = 'gather', resource = 'circuit', count = 5, reward = { thermalCores = 4, knowledge = true } },
        { title = 'Island Hop Expedition', desc = 'Volcanic island nearby. Send a team to see what\'s there.', objType = 'expedition', reward = { thermalCores = 5 } },
    },
    paxtera_prime = {
        { title = 'Harvest Season Preparation', desc = 'Get a full crop cycle in before autumn raids start.', objType = 'gather', resource = 'food', count = 50, reward = { thermalCores = 3 } },
        { title = 'Timber Wolf Hunt', desc = 'Timber wolves in the fields. Kill them or lose the crops.', objType = 'kill', species = 'timber_wolf', count = 3, reward = { thermalCores = 3 } },
        { title = 'Trade Route Setup', desc = 'Set up storage for trade. Caravans won\'t stop if there\'s nowhere to put the goods.', objType = 'build', buildId = 'storage_crate', count = 5, reward = { thermalCores = 4, factionId = 'rim_runners', factionRep = 10 } },
        { title = 'Wildlife Survey', desc = 'Paxtera AgroTech wants a fauna survey. Good money for legwork.', objType = 'expedition', reward = { thermalCores = 6 } },
    },
    nemaea = {
        { title = 'Radiation Shielding', desc = 'People are getting sick. Put up lead walls before it gets worse.', objType = 'build', buildId = 'wall_lead', count = 12, reward = { thermalCores = 4 } },
        { title = 'Automaton Salvage', desc = 'Patrol automaton nearby. Wreck it and strip it for parts.', objType = 'kill', species = 'patrol_automaton', count = 2, reward = { thermalCores = 6 } },
        { title = 'Dyson Fragment Recovery', desc = 'Dyson Sphere fragment crashed nearby. Rare materials inside.', objType = 'gather', resource = 'circuit', count = 15, reward = { thermalCores = 5 } },
        { title = 'Signal Decryption', desc = 'Signal coming from a nearby ruin. Crack it open and see what\'s inside.', objType = 'gather', resource = 'components', count = 10, reward = { thermalCores = 6, knowledge = true } },
    },
    gaia_a1x = {
        { title = 'Containment Protocol', desc = 'Lock down precursor artifacts before the next corruption wave.', objType = 'gather', resource = 'components', count = 10, reward = { thermalCores = 5 } },
        { title = 'Husk Crawler Purge', desc = 'Husk crawlers coming out of the corrupted zone. Kill them.', objType = 'kill', species = 'husk_crawler', count = 5, reward = { thermalCores = 3 } },
        { title = 'Forest Shelter Survey', desc = 'Abandoned shelters in the forest. Might still have supplies.', objType = 'expedition', reward = { thermalCores = 3 } },
        { title = 'Corruption Barrier', desc = 'Wall off the corrupted zone. Won\'t stop it forever but it\'ll slow it down.', objType = 'build', buildId = 'wall_stone', count = 15, reward = { thermalCores = 4 } },
    },
}

local SPACE_QUESTS = {
    { title = 'Delivery Run', desc = 'Haul cargo to a nearby station. Clock is ticking.', objType = 'deliver', resource = 'fuel', count = 10, reward = { thermalCores = 5 }, timeLimit = 8 },
    { title = 'Pirate Bounty', desc = 'Pirate vessel hitting the shipping lanes. Bounty posted. Kill it.', objType = 'kill', species = nil, count = 1, reward = { thermalCores = 8 }, timeLimit = 12 },
    { title = 'Derelict Salvage', desc = 'Wreck on sensors. Board it, strip what you can.', objType = 'expedition', reward = { thermalCores = 4 } },
    { title = 'Escort Duty', desc = 'Trade caravan needs a gun escort. Keep them alive.', objType = 'defend', count = 1, reward = { thermalCores = 6 }, timeLimit = 10 },
    { title = 'Distress Response', desc = 'Distress signal. Could be real, could be bait.', objType = 'expedition', reward = { thermalCores = 3 } },
    { title = 'Star Chart Pickup', desc = 'A NexLink relay has nav data for an unknown system. Go get it.', objType = 'expedition', reward = { thermalCores = 2 } },
    { title = 'Station Repair Contract', desc = 'Damaged station needs parts. Bring components before it falls apart.', objType = 'deliver', resource = 'components', count = 10, reward = { thermalCores = 8 }, timeLimit = 10 },
    { title = 'Xenolith Sighting', desc = 'Unknown organic vessel spotted. Nobody knows what it is. Be careful.', objType = 'expedition', reward = { thermalCores = 10 } },
}

local function buildPlanetObjective(template, diffMult)
    if template.objType == 'kill' then
        return { Objectives.create('kill', { species = template.species, count = scaleCount(template.count or 1, diffMult) }) }
    elseif template.objType == 'gather' then
        return { Objectives.create('gather', { resource = template.resource, count = scaleCount(template.count or 10, diffMult) }) }
    elseif template.objType == 'deliver' then
        return { Objectives.create('deliver', { resource = template.resource, count = scaleCount(template.count or 5, diffMult) }) }
    elseif template.objType == 'build' then
        return { Objectives.create('build', { buildId = template.buildId, count = scaleCount(template.count or 1, diffMult) }) }
    elseif template.objType == 'expedition' then
        return { Objectives.create('expedition', { destId = nil }) }
    elseif template.objType == 'defend' then
        return { Objectives.create('defend', { count = template.count or 1 }) }
    end
    return nil
end

local function generatePlanetQuest(diffMult)
    local planet = GameState.planet or 'erebus'
    local pool = PLANET_QUESTS[planet]
    if not pool or #pool == 0 then return nil end

    local template = pool[math.random(#pool)]
    local objectives = buildPlanetObjective(template, diffMult)
    if not objectives or #objectives == 0 then return nil end

    local reward = {}
    for k, v in pairs(template.reward or {}) do
        if type(v) == 'number' then
            reward[k] = scaleReward(v, diffMult)
        else
            reward[k] = v
        end
    end

    return {
        title      = template.title,
        desc       = template.desc,
        type       = 'planet_quest',
        objectives = objectives,
        reward     = reward,
        timeLimit  = template.timeLimit or math.max(8, math.floor(18 / diffMult + 0.5)),
        difficulty = diffMult,
        stars      = getStarRating(diffMult),
        planetId   = planet,
    }
end

local function generateSpaceQuest(diffMult)
    if GameState.activeMap ~= 'space' then return nil end
    if #SPACE_QUESTS == 0 then return nil end

    local template = SPACE_QUESTS[math.random(#SPACE_QUESTS)]
    local objectives = buildPlanetObjective(template, diffMult)
    if not objectives or #objectives == 0 then return nil end

    local reward = {}
    for k, v in pairs(template.reward or {}) do
        if type(v) == 'number' then
            reward[k] = scaleReward(v, diffMult)
        else
            reward[k] = v
        end
    end

    return {
        title      = template.title,
        desc       = template.desc,
        type       = 'space_quest',
        objectives = objectives,
        reward     = reward,
        timeLimit  = template.timeLimit or 0,
        difficulty = diffMult,
        stars      = math.max(2, getStarRating(diffMult)),
    }
end

---------------------------------------------------------------------------
-- Main quest dispatcher
---------------------------------------------------------------------------

function QuestGen.generate()
    local diffMult = getDifficultyMult()

    -- Space quests override normal dispatch when in space (40% chance)
    if GameState.activeMap == 'space' and math.random() < 0.4 then
        local sq = generateSpaceQuest(diffMult)
        if sq then return sq end
    end

    -- Planet-specific quest (30% chance, checked before generic roll)
    if math.random() < 0.3 then
        local pq = generatePlanetQuest(diffMult)
        if pq then return pq end
    end

    local roll = math.random(100)

    -- 8% chain quest (day 15+)
    if roll <= 8 then
        local q = generateChainQuest(diffMult)
        if q then return q end
    end
    -- 7% visitor petition (day 5+)
    if roll <= 15 then
        local q = generateVisitorPetition(diffMult)
        if q then return q end
    end
    -- 10% threat quest (day 10+)
    if roll <= 25 then
        local q = generateThreatQuest(diffMult)
        if q then return q end
    end
    -- 15% faction quest
    if roll <= 40 then
        local q = generateFactionQuest(diffMult)
        if q then return q end
    end
    -- 10% colonist personal quest (day 8+)
    if roll <= 50 then
        local q = generateColonistQuest(diffMult)
        if q then return q end
    end
    -- 10% containment contract
    if roll <= 60 then
        local q = generateContainmentQuest(diffMult)
        if q then return q end
    end
    -- 5% raid mission (day 20+)
    if roll <= 65 then
        local q = generateRaidMission(diffMult)
        if q then return q end
    end
    -- 15% expedition quest
    if roll <= 80 then
        local q = generateExpeditionQuest(diffMult)
        if q then return q end
    end
    -- 30% standard adlib quest (fallback)
    return generateAdlibQuest(diffMult)
end

return QuestGen
