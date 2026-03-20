-- nemesis.lua — Named persistent enemies across deployments
-- Nemeses are created from raid encounters and stored in the MRP campaign file
-- via mrp.lua.  They carry boosted stats and personal titles, and their deaths
-- trigger a hope/storyteller event for the colony.

local Nemesis = {}

local TITLES = {
    'Scavenger of %s',
    'Butcher of %s',
    'Ravager of %s',
    'Pillager of %s',
    'Conqueror of %s',
}

---------------------------------------------------------------------------
-- Create a nemesis record from a raid encounter
---------------------------------------------------------------------------

-- raiderName  : display name for the enemy leader
-- colonyName  : the colony they are associated with (used in title)
-- kills       : how many colonists they have slain
-- lootedItem  : item name carried off as trophy (may be nil)
--
-- Returns a plain table — safe to serialize into the MRP campaign file.
function Nemesis.createFromRaid(raiderName, colonyName, kills, lootedItem)
    local titleTemplate = TITLES[math.random(#TITLES)]
    local title = string.format(titleTemplate, colonyName)

    local hpMult  = 1.10 + math.random() * 0.05
    local dmgMult = 1.10 + math.random() * 0.05

    return {
        name        = raiderName,
        title       = title,
        colonyName  = colonyName,
        hpMult      = hpMult,
        dmgMult     = dmgMult,
        lootedItem  = lootedItem,
        kills       = kills or 0,
    }
end

---------------------------------------------------------------------------
-- Pick a nemesis to lead a raid on the given planet
---------------------------------------------------------------------------

-- Returns a nemesis record, or nil if none qualifies / 70% chance skip.
function Nemesis.getRaidNemesis(planetId)
    local mok, MRP = pcall(require, 'src.sim.mrp')
    if not mok then return nil end

    local roster = MRP.getNemeses(planetId)
    if not roster or #roster == 0 then return nil end

    -- 30% chance a nemesis leads the raid
    if math.random() > 0.30 then return nil end

    return roster[math.random(#roster)]
end

---------------------------------------------------------------------------
-- Storyteller announcements
---------------------------------------------------------------------------

-- Announce that a known nemesis has been spotted near the colony.
function Nemesis.announceNemesis(nemesis)
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.logEvent then
        Storyteller.logEvent(
            'nemesis',
            nemesis.name .. ', ' .. nemesis.title .. ', has been spotted nearby.'
        )
    end
end

-- Announce that the nemesis has been killed, and grant hope.
function Nemesis.announceRevenge(nemesis)
    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.logEvent then
        Storyteller.logEvent(
            'nemesis',
            nemesis.title .. ' has fallen. The dead of ' .. nemesis.colonyName .. ' are avenged.'
        )
    end

    local hok, Hope = pcall(require, 'src.colony.hope')
    if hok and Hope.applyDelta then
        Hope.applyDelta(5, 0)
    end
end

---------------------------------------------------------------------------

return Nemesis
