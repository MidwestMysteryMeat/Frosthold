-- advisor.lua -- Contextual gameplay advisor
-- Reactive tip system that monitors colony state and surfaces relevant guidance.
-- Tips have priorities, cooldowns, and one-shot flags. Persists via save/load.
-- Coexists with tutorial.lua (tutorial = first 30s sequential steps, advisor = ongoing).

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local Advisor = {}

-- Lazy-loaded dependencies (pcall to avoid circular requires)
local _Power, _Hope, _Quest, _Research
local function lazyLoad()
    if _Power == nil then
        local ok; ok, _Power = pcall(require, 'src.sim.power')
        if not ok then _Power = false end
    end
    if _Hope == nil then
        local ok; ok, _Hope = pcall(require, 'src.colony.hope')
        if not ok then _Hope = false end
    end
    if _Quest == nil then
        local ok; ok, _Quest = pcall(require, 'src.quest.quest')
        if not ok then _Quest = false end
    end
    if _Research == nil then
        local ok; ok, _Research = pcall(require, 'src.research.research')
        if not ok then _Research = false end
    end
end

---------------------------------------------------------------------------
-- Tip definitions
---------------------------------------------------------------------------

local TIPS = {
    -- EARLY GAME (one-shot, high priority)
    {
        id = 'freezing_no_heat',
        text = 'Your colonists are freezing. Press B and place a campfire for warmth.',
        priority = 100,
        oneShot = true,
        minTick = 40,
        condition = function()
            local freezing = false
            for _, comps in ECS.query('colonist', 'needs') do
                if comps.needs.warmth < 35 then freezing = true; break end
            end
            if not freezing then return false end
            for _, comps in ECS.query('building_ref') do
                local bid = comps.building_ref.defId
                if bid == 'campfire' or bid == 'heater' or bid == 'fire_pit' or bid == 'deep_fire_pit' then
                    return false
                end
            end
            return true
        end,
    },
    {
        id = 'no_stockpile',
        text = 'Designate a stockpile zone (Z key) so colonists store gathered resources.',
        priority = 85,
        oneShot = true,
        minTick = 200,
        condition = function()
            return ECS.countWith('stockpile') == 0 and ECS.countWith('colonist') > 0
        end,
    },
    {
        id = 'no_beds',
        text = 'Build beds (B key) so colonists can sleep. Exhausted workers are slow.',
        priority = 80,
        oneShot = true,
        minTick = 600,
        condition = function()
            return ECS.countWith('bed') == 0 and ECS.countWith('colonist') > 0
        end,
    },
    {
        id = 'food_low_early',
        text = 'Food is running low. Hunt wildlife or build a kitchen to cook meals.',
        priority = 90,
        oneShot = true,
        minTick = 400,
        condition = function()
            return (GameState.resources.food or 0) < 15 and GameState.day <= 5
        end,
    },
    {
        id = 'no_research',
        text = 'Build a research bench (B key) to unlock new technologies.',
        priority = 60,
        oneShot = true,
        minTick = 1200,
        condition = function()
            return ECS.countWith('research_bench') == 0 and GameState.day >= 2
        end,
    },

    -- ONGOING WARNINGS (repeatable, with cooldown)
    {
        id = 'colonist_starving',
        text = 'A colonist is starving. Check food supply and cooking facilities.',
        priority = 95,
        oneShot = false,
        cooldownTicks = 1200,
        condition = function()
            for _, comps in ECS.query('colonist', 'needs') do
                if comps.needs.food < 15 then return true end
            end
            return false
        end,
    },
    {
        id = 'colonist_exhausted',
        text = 'A colonist is collapsing from exhaustion. They need a bed.',
        priority = 85,
        oneShot = false,
        cooldownTicks = 1200,
        condition = function()
            for _, comps in ECS.query('colonist', 'needs') do
                if comps.needs.rest < 10 then return true end
            end
            return false
        end,
    },
    {
        id = 'power_deficit',
        text = 'Power demand exceeds supply. Build generators or disconnect buildings.',
        priority = 75,
        oneShot = false,
        cooldownTicks = 2400,
        condition = function()
            lazyLoad()
            if not _Power or not _Power.getTotalSupply then return false end
            local supply = _Power.getTotalSupply()
            local demand = _Power.getTotalDemand()
            return demand > 0 and supply < demand
        end,
    },
    {
        id = 'no_power_source',
        text = 'Buildings need power but no generators are online. Place a generator or refuel existing ones.',
        priority = 88,
        oneShot = false,
        cooldownTicks = 1800,
        condition = function()
            lazyLoad()
            if not _Power or not _Power.getTotalSupply then return false end
            local supply = _Power.getTotalSupply()
            local demand = _Power.getTotalDemand()
            return demand > 0 and supply <= 0
        end,
    },
    {
        id = 'water_low',
        text = 'Water stores are running low. Build pumps or reduce nonessential consumption.',
        priority = 82,
        oneShot = false,
        cooldownTicks = 2400,
        condition = function()
            return (GameState.resources.water or 0) < 8 and ECS.countWith('colonist') > 0
        end,
    },
    {
        id = 'hope_critical',
        text = 'Colony hope is critically low. A revolt may be imminent.',
        priority = 92,
        oneShot = false,
        cooldownTicks = 2400,
        condition = function()
            lazyLoad()
            if not _Hope or not _Hope.getHope then return false end
            return _Hope.getHope() < 15
        end,
    },
    {
        id = 'air_bad',
        text = 'Air quality is dangerous. Seal the room or add exhausts and purifiers immediately.',
        priority = 94,
        oneShot = false,
        cooldownTicks = 1200,
        condition = function()
            local aOk, Atmosphere = pcall(require, 'src.sim.atmosphere')
            local tgOk, TileGas = pcall(require, 'src.sim.tile_gas')
            if not aOk then return false end
            for _, comps in ECS.query('colonist', 'pos') do
                local pos = comps.pos
                local o2 = Atmosphere.getTileO2 and Atmosphere.getTileO2(pos.x, pos.y, pos.depth or 0) or 100
                if o2 < 60 then return true end
                if tgOk and TileGas.isToxic and TileGas.isToxic(pos.x, pos.y, pos.depth or 0) then
                    return true
                end
            end
            return false
        end,
    },
    {
        id = 'flooding_detected',
        text = 'Water is spreading through the colony. Add sump pumps or open a drainage path.',
        priority = 84,
        oneShot = false,
        cooldownTicks = 1800,
        condition = function()
            local tOk, Thermal = pcall(require, 'src.sim.thermal')
            local fOk, Flooding = pcall(require, 'src.sim.flooding')
            if not tOk or not fOk then return false end
            for rid in pairs(Thermal.getRooms() or {}) do
                if Flooding.getWaterLevel and Flooding.getWaterLevel(rid) >= 1 then
                    return true
                end
            end
            return false
        end,
    },
    {
        id = 'idle_colonists',
        text = 'Multiple colonists are idle. Check work priorities (P key).',
        priority = 40,
        oneShot = false,
        cooldownTicks = 3600,
        minTick = 600,
        condition = function()
            local idle, total = 0, 0
            for _, comps in ECS.query('colonist') do
                total = total + 1
                if comps.colonist.state == 'idle' then idle = idle + 1 end
            end
            return total >= 3 and idle >= math.ceil(total * 0.5)
        end,
    },
    {
        id = 'no_doctor',
        text = 'No colonist has medical work priority set. Injuries will go untreated.',
        priority = 70,
        oneShot = false,
        cooldownTicks = 3600,
        condition = function()
            local hasDoctor = false
            for _, comps in ECS.query('colonist', 'workPriority') do
                local wp = comps.workPriority
                if wp and wp.medical and wp.medical > 0 then hasDoctor = true; break end
            end
            return not hasDoctor and ECS.countWith('colonist') > 0
        end,
    },
    {
        id = 'quest_board',
        text = 'New quests are available. Press Q to review colony goals and the quest board.',
        priority = 30,
        oneShot = false,
        cooldownTicks = 6000,
        minTick = 2400,
        condition = function()
            lazyLoad()
            if not _Quest or not _Quest.getAvailable then return false end
            local avail = _Quest.getAvailable()
            return avail and #avail > 0 and _Quest.getActiveCount() == 0
        end,
    },
    {
        id = 'colonist_hypothermic',
        text = 'A colonist has hypothermia. Move them to a heated room immediately.',
        priority = 93,
        oneShot = false,
        cooldownTicks = 1200,
        condition = function()
            for _, comps in ECS.query('colonist', 'needs') do
                if comps.needs.warmth < 15 then return true end
            end
            return false
        end,
    },
    {
        id = 'no_walls',
        text = 'Build walls and a door to create enclosed rooms. Sealed rooms retain heat.',
        priority = 65,
        oneShot = true,
        minTick = 800,
        condition = function()
            local wallCount = 0
            for _, comps in ECS.query('building_ref') do
                local bid = comps.building_ref.defId
                if bid and bid:find('wall') then wallCount = wallCount + 1 end
            end
            return wallCount == 0 and GameState.day >= 1
        end,
    },

    ---------------------------------------------------------------------------
    -- VICTORY PATH GUIDANCE (one-shot, mid-to-late game)
    ---------------------------------------------------------------------------

    -- General overview: triggers when the player reaches tier 3 research
    {
        id = 'victory_paths_overview',
        text = 'There are four ways off Erebus. Each requires late-tier research and a massive endgame building. Press Q to review victory paths in the quest panel.',
        priority = 45,
        oneShot = true,
        minTick = 4800,
        condition = function()
            lazyLoad()
            if not _Research or not _Research.getMaxTierCompleted then return false end
            return _Research.getMaxTierCompleted() >= 3
        end,
    },

    -- Mammona Corporate Claim path
    {
        id = 'victory_mammona_claim',
        text = 'Victory path: Mammona Corporate Claim. Research "Mammona Uplink Protocol" (requires Full Automation + Nuclear Power) then build a Transmission Array. Mammona secures the planet — but at what cost.',
        priority = 38,
        oneShot = true,
        minTick = 8000,
        condition = function()
            lazyLoad()
            if not _Research then return false end
            -- Show when player completes either prerequisite
            return (_Research.isCompleted('full_automation') or _Research.isCompleted('nuclear_power'))
                and not _Research.isCompleted('mammona_uplink')
        end,
    },

    -- Shuttle Escape path
    {
        id = 'victory_shuttle_escape',
        text = 'Victory path: Shuttle Escape. Research "Shuttle Engineering" (requires Fuel Synthesis + Full Automation) then build a Launch Pad. Whoever fits aboard escapes. The colony stays behind.',
        priority = 38,
        oneShot = true,
        minTick = 8000,
        condition = function()
            lazyLoad()
            if not _Research then return false end
            return (_Research.isCompleted('fuel_synthesis') or _Research.isCompleted('full_automation'))
                and not _Research.isCompleted('shuttle_engineering')
        end,
    },

    -- Seal Erebus path
    {
        id = 'victory_seal_erebus',
        text = 'Victory path: Seal Erebus. Research "Precursor Sealing Tech" (requires Expedition Preparation + Exotic Fluid Processing) then build a Sealing Apparatus. Shut the deep threat away forever.',
        priority = 38,
        oneShot = true,
        minTick = 8000,
        condition = function()
            lazyLoad()
            if not _Research then return false end
            return (_Research.isCompleted('expedition_prep') or _Research.isCompleted('exotic_fluids'))
                and not _Research.isCompleted('precursor_sealing')
        end,
    },

    -- Corporate Extraction path
    {
        id = 'victory_extraction',
        text = 'Victory path: Corporate Extraction. Research "Mammona Extraction Protocol" (requires Mammona Uplink + Thermal Core Synthesis) then build an Extraction Beacon. You must defeat That Which Sleeps before activating it.',
        priority = 38,
        oneShot = true,
        minTick = 10000,
        condition = function()
            lazyLoad()
            if not _Research then return false end
            return _Research.isCompleted('mammona_uplink')
                and not _Research.isCompleted('mammona_extraction')
        end,
    },

    -- Endgame research completed: remind player to build the structure
    {
        id = 'victory_research_done',
        text = 'Endgame research complete. Build the unlocked victory structure and power it to begin the charging sequence. It takes three days to charge.',
        priority = 50,
        oneShot = true,
        minTick = 6000,
        condition = function()
            lazyLoad()
            if not _Research then return false end
            return _Research.isCompleted('mammona_uplink')
                or _Research.isCompleted('shuttle_engineering')
                or _Research.isCompleted('precursor_sealing')
                or _Research.isCompleted('mammona_extraction')
        end,
    },

    -- Endgame building placed but still idle: nudge the player to start charging
    {
        id = 'victory_building_idle',
        text = 'An endgame building is placed but idle. Select it and start the charging sequence to begin your victory path.',
        priority = 48,
        oneShot = true,
        minTick = 6000,
        condition = function()
            for _, comps in ECS.query('endgame_building') do
                if comps.endgame_building.phase == 'idle' then return true end
            end
            return false
        end,
    },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local shown      = {}     -- { [tipId] = true } for one-shot tips already shown
local cooldowns   = {}     -- { [tipId] = ticksRemaining }
local activeTip   = nil    -- { id, text, timer } currently displayed
local checkInterval = 40   -- check every 2 seconds (40 ticks at 20Hz)
local checkCounter  = 0
local DISPLAY_TIME  = 8.0  -- seconds to show a tip
local enabled       = true

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Advisor.init()
    _Power, _Hope, _Quest, _Research = nil, nil, nil, nil
    shown = {}
    cooldowns = {}
    activeTip = nil
    checkCounter = 0
    enabled = true
end

---------------------------------------------------------------------------
-- Step (called each sim tick from main.lua)
---------------------------------------------------------------------------

function Advisor.step(dt)
    if not enabled then return end
    if GameState.phase ~= 'playing' then return end

    lazyLoad()

    -- Update active tip timer
    if activeTip then
        activeTip.timer = activeTip.timer - dt
        if activeTip.timer <= 0 then
            activeTip = nil
        end
    end

    -- Tick down cooldowns
    for tipId, remaining in pairs(cooldowns) do
        cooldowns[tipId] = remaining - 1
        if cooldowns[tipId] <= 0 then
            cooldowns[tipId] = nil
        end
    end

    -- Periodic condition check
    checkCounter = checkCounter + 1
    if checkCounter < checkInterval then return end
    checkCounter = 0

    -- Don't evaluate if a tip is already showing
    if activeTip then return end

    -- Find highest priority tip whose condition is met
    local best = nil
    local bestPriority = -1

    for _, tip in ipairs(TIPS) do
        if tip.oneShot and shown[tip.id] then goto continue end
        if cooldowns[tip.id] then goto continue end
        if tip.minTick and GameState.simTick < tip.minTick then goto continue end

        local ok, result = pcall(tip.condition)
        if ok and result and tip.priority > bestPriority then
            best = tip
            bestPriority = tip.priority
        end

        ::continue::
    end

    if best then
        activeTip = {
            id = best.id,
            text = best.text,
            timer = DISPLAY_TIME,
        }
        if best.oneShot then
            shown[best.id] = true
        end
        if best.cooldownTicks then
            cooldowns[best.id] = best.cooldownTicks
        end
    end
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function Advisor.draw()
    if not activeTip then return end

    local sw, sh = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local fontH = font:getHeight()

    local maxW = math.min(320, sw * 0.3)
    local padX, padY = 12, 8
    local margin = 8

    -- Word-wrap text
    local _, lines = font:getWrap(activeTip.text, maxW - padX * 2)
    local textH = #lines * fontH
    local boxW = maxW
    local boxH = textH + padY * 2 + fontH + 4

    -- Upper-right, below resource bar
    local bx = sw - boxW - margin
    local by = 60 + margin

    -- Fade in/out
    local alpha = 1.0
    if activeTip.timer < 1.0 then
        alpha = activeTip.timer
    elseif activeTip.timer > DISPLAY_TIME - 0.5 then
        alpha = (DISPLAY_TIME - activeTip.timer) / 0.5
    end
    alpha = math.max(0, math.min(1, alpha))

    -- Background
    love.graphics.setColor(0.08, 0.12, 0.18, 0.9 * alpha)
    love.graphics.rectangle('fill', bx, by, boxW, boxH, 4, 4)
    love.graphics.setColor(0.3, 0.55, 0.8, 0.7 * alpha)
    love.graphics.rectangle('line', bx, by, boxW, boxH, 4, 4)

    -- Tip text
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(activeTip.text, bx + padX, by + padY, maxW - padX * 2, 'left')

    -- Dismiss hint
    love.graphics.setColor(0.5, 0.5, 0.5, 0.6 * alpha)
    love.graphics.print('Click to dismiss', bx + padX, by + padY + textH + 4)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function Advisor.mousepressed(mx, my, button)
    if not activeTip then return false end

    local sw = love.graphics.getDimensions()
    local font = love.graphics.getFont()
    local fontH = font:getHeight()
    local maxW = math.min(320, sw * 0.3)
    local padX, padY = 12, 8
    local margin = 8

    local _, lines = font:getWrap(activeTip.text, maxW - padX * 2)
    local textH = #lines * fontH
    local boxH = textH + padY * 2 + fontH + 4

    local bx = sw - maxW - margin
    local by = 60 + margin

    if mx >= bx and mx <= bx + maxW and my >= by and my <= by + boxH then
        activeTip = nil
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Advisor.getState()
    return {
        shown = shown,
        enabled = enabled,
    }
end

function Advisor.loadState(saved)
    if not saved then return end
    shown = saved.shown or {}
    enabled = saved.enabled ~= false
end

---------------------------------------------------------------------------
-- Control
---------------------------------------------------------------------------

function Advisor.toggle()
    enabled = not enabled
end

function Advisor.isEnabled()
    return enabled
end

function Advisor.dismiss()
    activeTip = nil
end

return Advisor
