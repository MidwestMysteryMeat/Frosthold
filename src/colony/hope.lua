-- hope.lua -- Colony-wide hope/discontent dual meters + memorial system
-- Module-level state (not ECS). Step function called from main.lua each sim tick.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')
local Building  = require('src.building.building')
local Tiles     = require('src.world.tiles')

local Hope = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local state = {
    hope       = 50,
    discontent = 20,

    -- Track consecutive low/high durations (in game-days, fractional)
    despairDays  = 0,   -- days with hope < 20
    revoltDays   = 0,   -- days with discontent > 80
    revoltActive = false,
    revoltEnd    = 0,   -- GameState.day + hour fraction when revolt ends

    -- Memorial inscriptions (colonist names)
    memorials = {},     -- { { name, day } }

    -- Event log for UI
    log = {},
}

local MAX_LOG = 12

local function logMsg(msg)
    state.log[#state.log + 1] = {
        msg = msg,
        day = GameState.day,
        hour = GameState.hour,
    }
    while #state.log > MAX_LOG do
        table.remove(state.log, 1)
    end
end

---------------------------------------------------------------------------
-- Public: apply hope/discontent shifts from game events
---------------------------------------------------------------------------

function Hope.onColonistDeath(colonistName)
    state.hope       = math.max(0, state.hope - 15)
    state.discontent = math.min(100, state.discontent + 10)
    logMsg(colonistName .. ' has died. The colony mourns.')
end

function Hope.onGoodMeal()
    state.hope = math.min(100, state.hope + 2)
end

function Hope.onBuildingCompleted(buildingName)
    state.hope       = math.min(100, state.hope + 3)
    state.discontent = math.max(0, state.discontent - 1)
    logMsg((buildingName or 'A structure') .. ' completed. Hope rises.')
end

function Hope.onMemorialBuilt(colonistName)
    state.hope       = math.min(100, state.hope + 10)
    state.discontent = math.max(0, state.discontent - 5)
    state.memorials[#state.memorials + 1] = {
        name = colonistName,
        day  = GameState.day,
    }
    logMsg('A memorial was built for ' .. colonistName .. '.')
end

function Hope.onWandererJoined()
    state.hope       = math.min(100, state.hope + 5)
    state.discontent = math.max(0, state.discontent - 2)
end

function Hope.onSupplyFound()
    state.hope = math.min(100, state.hope + 3)
end

function Hope.applyDelta(hopeDelta, discontentDelta)
    if hopeDelta then
        state.hope = math.max(0, math.min(100, state.hope + hopeDelta))
    end
    if discontentDelta then
        state.discontent = math.max(0, math.min(100, state.discontent + discontentDelta))
    end
end

---------------------------------------------------------------------------
-- Dark actions — organ harvest, execution, butchering humans, plus a legacy enslavement hook for old saves.
---------------------------------------------------------------------------

local DARK_PENALTIES = {
    organ_harvest  = { hope = -12, discontent = 8, msg = 'An organ was harvested. The colony is horrified.' },
    execution      = { hope = -8,  discontent = 5, msg = 'A prisoner was executed.' },
    butcher_human  = { hope = -10, discontent = 6, msg = 'A human body was butchered. Colonists are disturbed.' },
    enslave        = { hope = -5,  discontent = 4, msg = 'Legacy event: a prisoner was enslaved.' },
}

function Hope.onDarkAction(actionType)
    local pen = DARK_PENALTIES[actionType]
    if not pen then return end
    state.hope       = math.max(0, state.hope + pen.hope)
    state.discontent = math.min(100, state.discontent + pen.discontent)
    logMsg(pen.msg)
end

---------------------------------------------------------------------------
-- Memorial building definition
---------------------------------------------------------------------------

-- Register memorial as a building type if not already present
if not Building.defs.memorial then
    Building.defs.memorial = {
        name = 'Memorial',
        w = 1, h = 1,
        tile = Tiles.FLOOR_STONE,
        cost = { stone = 5 },
    }
end

---------------------------------------------------------------------------
-- Step -- called each sim tick from main.lua
---------------------------------------------------------------------------

-- 1 game-hour = 60 real seconds at 1x. Sim runs at 20Hz.
-- hoursPerTick = (1/20) * speed / 60
-- daysPerTick  = hoursPerTick / 24

function Hope.step(dt)
    local hoursPerTick = dt / 60
    local daysPerTick  = hoursPerTick / 24

    -- Natural drift: hope drifts toward 50, discontent toward 20
    local hopeDrift = (50 - state.hope) * 0.002 * dt
    local dcDrift   = (20 - state.discontent) * 0.001 * dt
    state.hope       = math.max(0, math.min(100, state.hope + hopeDrift))
    state.discontent = math.max(0, math.min(100, state.discontent + dcDrift))

    -- Policy-driven discontent pressure (martial law, etc.)
    local polOk, Policies = pcall(require, 'src.colony.policies')
    if polOk then
        local dcAdd = Policies.getDiscontentAdd()
        if dcAdd > 0 then
            -- Scale by time so it represents a steady per-day pressure
            state.discontent = math.min(100, state.discontent + dcAdd * daysPerTick)
        end
    end

    -- Laws: discontent cap and hope floor
    local lawOk, Laws = pcall(require, 'src.colony.laws')
    if lawOk then
        local dcCap = Laws.getDiscontentCap()
        if dcCap and state.discontent > dcCap then
            state.discontent = dcCap
        end
        local hFloor = Laws.getHopeFloor()
        if hFloor and state.hope < hFloor then
            state.hope = hFloor
        end
    end

    -- Colonist count affects discontent (fewer colonists = more stress)
    local count = ECS.countWith('colonist')
    if count <= 1 and count > 0 then
        state.discontent = math.min(100, state.discontent + 0.005 * dt)
    end

    -----------------------------------------------------------------------
    -- Despair tracker: hope < 20 for 3+ game-days
    -----------------------------------------------------------------------
    if state.hope < 20 then
        state.despairDays = state.despairDays + daysPerTick
    else
        state.despairDays = math.max(0, state.despairDays - daysPerTick * 2)
    end

    if state.despairDays >= 3 then
        -- Despair event: a random colonist may leave
        state.despairDays = 0
        local colonists = ECS.allWith('colonist')
        if #colonists > 1 then
            -- Pick the living colonist with lowest morale
            local worstId, worstMorale = nil, math.huge
            for _, cid in ipairs(colonists) do
                local col = ECS.get(cid, 'colonist')
                if col and col.state ~= 'dead' then
                    local needs = ECS.get(cid, 'needs')
                    if needs and needs.morale < worstMorale then
                        worstMorale = needs.morale
                        worstId = cid
                    end
                end
            end
            if worstId then
                local col = ECS.get(worstId, 'colonist')
                local name = col and col.name or 'A colonist'
                logMsg(name .. ' has lost all hope and left the colony.')
                -- Notify social/elastic systems of departure
                local socialOk, Social = pcall(require, 'src.colonist.social')
                if socialOk then Social.onColonistDeath(worstId) end
                local edOk, Elastic = pcall(require, 'src.sim.elastic_difficulty')
                if edOk then Elastic.onColonistDeath() end
                ECS.destroy(worstId)
                state.discontent = math.min(100, state.discontent + 5)
            end
        end
    end

    -----------------------------------------------------------------------
    -- Revolt tracker: discontent > 80 for 2+ game-days
    -----------------------------------------------------------------------
    if state.revoltActive then
        local currentTime = GameState.day + GameState.hour / 24
        if currentTime >= state.revoltEnd then
            state.revoltActive = false
            state.revoltDays = 0
            logMsg('The revolt subsides. Colonists return to work.')
        end
    else
        if state.discontent > 80 then
            state.revoltDays = state.revoltDays + daysPerTick
        else
            state.revoltDays = math.max(0, state.revoltDays - daysPerTick * 2)
        end

        if state.revoltDays >= 2 then
            state.revoltActive = true
            state.revoltDays = 0
            -- Revolt lasts 1 game-day
            state.revoltEnd = GameState.day + GameState.hour / 24 + 1
            state.discontent = math.max(0, state.discontent - 15)
            logMsg('Colonists revolt! They refuse to work for a day.')
            -- Toast notification
            local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if stOk and Storyteller.logEvent then
                Storyteller.logEvent('revolt', 'Colony revolt! Colonists refuse to work.')
            end
        end
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Hope.getHope()       return state.hope end
function Hope.getDiscontent() return state.discontent end
function Hope.setHopeFloor(floor)
    if state.hope < floor then state.hope = floor end
end
function Hope.setDiscontentCap(cap)
    if state.discontent > cap then state.discontent = cap end
end
function Hope.isRevoltActive() return state.revoltActive end
function Hope.getMemorials()  return state.memorials end
function Hope.getLog()        return state.log end
function Hope.getDespairDays() return state.despairDays end
function Hope.getRevoltDays()  return state.revoltDays end

function Hope.getState()
    return state
end

return Hope
