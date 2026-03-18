-- milestones.lua — Victory milestone system
-- Replaces game-ending triggerVictory calls with milestone rewards
-- that open new gameplay without forcing an end state.

local GameState = require('src.game_state')

local Milestones = {}

---------------------------------------------------------------------------
-- Milestone definitions
---------------------------------------------------------------------------

local MILESTONE_DEFS = {
    mammona_claim = {
        name = 'Mammona Claim',
        desc = 'Mammona stamped this world as theirs. You helped.',
    },
    seal_deep = {
        name = 'Seal The Deep',
        desc = 'The anomaly is contained. The planet sleeps again.',
    },
    mammona_extraction = {
        name = 'Mammona Extraction',
        desc = 'Fleet inbound. Mammona wants the reserves. They\'re bringing everyone.',
    },
}

---------------------------------------------------------------------------
-- Complete a milestone
---------------------------------------------------------------------------

function Milestones.complete(milestoneId)
    local def = MILESTONE_DEFS[milestoneId]
    if not def then return false end

    if milestoneId == 'mammona_claim' then
        GameState.mammonaClaimed = true

        -- Reward: spawn reinforcement colonists
        local cok, Colonist = pcall(require, 'src.colonist.colonist')
        if cok and Colonist.spawnInitial then
            Colonist.spawnInitial(GameState.startX, GameState.startY, 3)
        end

        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok and Storyteller.logEvent then
            Storyteller.logEvent('milestone_mammona_claim', {})
        end

    elseif milestoneId == 'seal_deep' then
        GameState.sealedDeep = true

        -- Reward: set anomaly to 0 permanently
        local aok, Anomaly = pcall(require, 'src.sim.anomaly')
        if aok then
            if Anomaly.setLevel then Anomaly.setLevel(0) end
            if Anomaly.setSealedPermanently then Anomaly.setSealedPermanently(true) end
        end

        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok and Storyteller.logEvent then
            Storyteller.logEvent('milestone_seal_deep', {})
        end

    elseif milestoneId == 'mammona_extraction' then
        GameState.extractionComplete = true

        -- Reward: massive resource injection
        local items = {
            { itemId = 'steel', amount = 200 },
            { itemId = 'components', amount = 100 },
            { itemId = 'circuit', amount = 50 },
        }
        local iok, Items = pcall(require, 'src.world.items')
        if iok and Items.spawn then
            for _, item in ipairs(items) do
                Items.spawn(GameState.startX + math.random(-3, 3),
                           GameState.startY + math.random(-3, 3),
                           item.itemId, item.amount)
            end
        end

        local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
        if sok and Storyteller.logEvent then
            Storyteller.logEvent('milestone_mammona_extraction', {})
        end
    end

    return true
end

---------------------------------------------------------------------------
-- Query
---------------------------------------------------------------------------

function Milestones.isComplete(milestoneId)
    if milestoneId == 'mammona_claim' then return GameState.mammonaClaimed end
    if milestoneId == 'seal_deep' then return GameState.sealedDeep end
    if milestoneId == 'mammona_extraction' then return GameState.extractionComplete end
    return false
end

function Milestones.getDef(milestoneId)
    return MILESTONE_DEFS[milestoneId]
end

return Milestones
