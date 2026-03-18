-- debug_panel.lua — Developer tools panel
-- Toggle with F7. Tabs: God Mode, Events, Raids, Creatures, Colonists, Weather, Resources, World.
-- All actions are immediate. Click to trigger.

local ECS       = require('src.ecs.ecs')
local GameState = require('src.game_state')

local DebugPanel = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local open       = false
local activeTab  = 'god'
local scrollY    = 0        -- per-tab scroll offset
local MAX_SCROLL = 0        -- recalculated per draw
local hoverItem  = nil      -- { tab, id } for highlight
local statusMsg  = nil      -- brief feedback message
local statusTimer = 0

-- God mode flags (persistent while game runs)
DebugPanel.godMode       = false   -- colonists invulnerable
DebugPanel.infiniteRes   = false   -- resources never deplete
DebugPanel.instantBuild  = false   -- buildings place instantly
DebugPanel.noRaids       = false   -- suppress raids
DebugPanel.revealMap     = false   -- disable fog of war
DebugPanel.noColdDamage  = false   -- no hypothermia/cold damage
DebugPanel.noNeeds       = false   -- needs don't decay

---------------------------------------------------------------------------
-- Tab definitions
---------------------------------------------------------------------------

local TABS = {
    { id = 'god',       label = 'God Mode' },
    { id = 'events',    label = 'Events' },
    { id = 'raids',     label = 'Raids' },
    { id = 'creatures', label = 'Creatures' },
    { id = 'colonists', label = 'Colonists' },
    { id = 'weather',   label = 'Weather' },
    { id = 'resources', label = 'Resources' },
    { id = 'profiler',  label = 'Profiler' },
    { id = 'world',     label = 'World' },
}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local PANEL_PAD   = 12
local TAB_W       = 100
local TAB_H       = 28
local ITEM_H      = 24
local HEADER_H    = 22
local TOGGLE_W    = 180
local BTN_W       = 200
local BTN_H       = 22

---------------------------------------------------------------------------
-- Toggle / query
---------------------------------------------------------------------------

function DebugPanel.toggle()
    open = not open
    scrollY = 0
    hoverItem = nil
end

function DebugPanel.isOpen()
    return open
end

function DebugPanel.close()
    open = false
end

---------------------------------------------------------------------------
-- Status flash
---------------------------------------------------------------------------

local function flash(msg)
    statusMsg = msg
    statusTimer = 2.0
end

---------------------------------------------------------------------------
-- God mode toggles
---------------------------------------------------------------------------

local GOD_TOGGLES = {
    { id = 'godMode',      label = 'God Mode (Invulnerable)',   desc = 'Colonists cannot die' },
    { id = 'infiniteRes',  label = 'Infinite Resources',        desc = 'Resources never deplete' },
    { id = 'instantBuild', label = 'Instant Build',             desc = 'Buildings complete immediately' },
    { id = 'noRaids',      label = 'No Raids',                  desc = 'Suppress all raid events' },
    { id = 'revealMap',    label = 'Reveal Map',                desc = 'Disable fog of war' },
    { id = 'noColdDamage', label = 'No Cold Damage',            desc = 'Disable hypothermia and frostbite' },
    { id = 'noNeeds',      label = 'Freeze Needs',              desc = 'Colonist needs stay at current values' },
}

---------------------------------------------------------------------------
-- Event data (gathered lazily)
---------------------------------------------------------------------------

local eventCache = nil

local function getEventList()
    if eventCache then return eventCache end

    local categories = {
        { cat = 'Weather',     ids = {} },
        { cat = 'Creature',    ids = {} },
        { cat = 'Colony',      ids = {} },
        { cat = 'Threat',      ids = {} },
        { cat = 'Other',       ids = {} },
    }

    local catMap = {}
    for _, c in ipairs(categories) do catMap[c.cat] = c.ids end

    local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
    if sok and Storyteller.getEventDefs then
        local defs = Storyteller.getEventDefs()
        for eventId, def in pairs(defs) do
            local t = def.type or 'other'
            local bucket
            if t == 'weather' then bucket = catMap['Weather']
            elseif t == 'creature' then bucket = catMap['Creature']
            elseif t == 'colony' then bucket = catMap['Colony']
            elseif t == 'threat' then bucket = catMap['Threat']
            else bucket = catMap['Other']
            end
            bucket[#bucket + 1] = { id = eventId, name = def.name or eventId }
        end
    end

    -- Sort each category alphabetically
    for _, c in ipairs(categories) do
        table.sort(c.ids, function(a, b) return a.name < b.name end)
    end

    -- Filter out empty categories
    local result = {}
    for _, c in ipairs(categories) do
        if #c.ids > 0 then result[#result + 1] = c end
    end

    eventCache = result
    return result
end

---------------------------------------------------------------------------
-- Raid types
---------------------------------------------------------------------------

local raidCache = nil

local function getRaidTypes()
    if raidCache then return raidCache end
    local rok, Raids = pcall(require, 'src.sim.raids')
    if rok and Raids.getRaidTypeDefs then
        raidCache = Raids.getRaidTypeDefs()
    else
        -- Fallback: known raid type IDs
        raidCache = {
            { id = 'beast_assault',     name = 'Beast Assault' },
            { id = 'siege',             name = 'Siege' },
            { id = 'coordinated',       name = 'Coordinated Attack' },
            { id = 'swarm',             name = 'The Swarm' },
            { id = 'thermovore_swarm',  name = 'Thermovore Swarm' },
            { id = 'outlaw_raid',       name = 'Outlaw Raid' },
            { id = 'faction_raid',      name = 'Faction Raid' },
            { id = 'mastema_strike',    name = 'MasTema Strike' },
        }
    end
    return raidCache
end

---------------------------------------------------------------------------
-- Creature species
---------------------------------------------------------------------------

local creatureCache = nil

local function getCreatureSpecies()
    if creatureCache then return creatureCache end

    local categories = {
        { cat = 'Small Fauna',         tier = 'small',              species = {} },
        { cat = 'Medium Fauna',        tier = 'medium',             species = {} },
        { cat = 'Megafauna',           tier = 'megafauna',          species = {} },
        { cat = 'Eldritch',            tier = 'eldritch',           species = {} },
        { cat = 'Eldritch Livestock',  tier = 'eldritch_livestock', species = {} },
        { cat = 'Swarm',              tier = 'swarm',              species = {} },
        { cat = 'Other',              tier = 'other',              species = {} },
    }

    local tierMap = {}
    for _, c in ipairs(categories) do tierMap[c.tier] = c.species end

    local cok, Creatures = pcall(require, 'src.creatures.creatures')
    if cok and Creatures.getSpeciesDefs then
        local defs = Creatures.getSpeciesDefs()
        for speciesId, def in pairs(defs) do
            local tier = def.tier or 'other'
            local bucket = tierMap[tier] or tierMap['other']
            bucket[#bucket + 1] = {
                id = speciesId,
                name = def.name or speciesId,
                hp = def.health or 0,
            }
        end
    else
        -- Fallback: common species
        local fallback = {
            'frost_hare', 'ice_fox', 'snow_grouse',
            'tundra_wolf', 'glacier_bear', 'ice_stalker', 'ice_brute', 'snow_ape', 'stalker',
            'frost_titan', 'thermal_wurm', 'glacial_leviathan',
            'the_hungering', 'the_pale_thing', 'that_which_sleeps', 'fleshwalker',
            'char_hound', 'bore_beetle', 'razorjaw',
            'frost_beetle', 'ice_locust', 'spawnling',
        }
        for _, sid in ipairs(fallback) do
            tierMap['other'][#tierMap['other'] + 1] = { id = sid, name = sid, hp = 0 }
        end
    end

    for _, c in ipairs(categories) do
        table.sort(c.species, function(a, b) return a.name < b.name end)
    end

    local result = {}
    for _, c in ipairs(categories) do
        if #c.species > 0 then result[#result + 1] = c end
    end

    creatureCache = result
    return result
end

---------------------------------------------------------------------------
-- Weather types
---------------------------------------------------------------------------

local WEATHER_TYPES = {
    { id = 'clear',      name = 'Clear' },
    { id = 'overcast',   name = 'Overcast' },
    { id = 'snowfall',   name = 'Snowfall' },
    { id = 'blizzard',   name = 'Blizzard' },
    { id = 'whiteout',   name = 'Whiteout' },
    { id = 'warm_front', name = 'Warm Front' },
    { id = 'aurora',     name = 'Aurora' },
}

---------------------------------------------------------------------------
-- Resource categories
---------------------------------------------------------------------------

local RESOURCE_GROUPS = {
    { cat = 'Base',       keys = { 'thermalCores', 'wood', 'stone', 'metal', 'water', 'fuel', 'food', 'components', 'hide' } },
    { cat = 'Processed',  keys = { 'steel', 'circuit', 'charcoal', 'cut_stone', 'cloth', 'glass', 'insulation', 'pipe' } },
    { cat = 'Medical',    keys = { 'bandage', 'medicine', 'advanced_medicine', 'revivify_serum' } },
    { cat = 'Weapons',    keys = { 'weapon_bolt_action', 'weapon_assault_rifle', 'weapon_battle_rifle', 'weapon_thermal_lance', 'weapon_thermal_blade' } },
    { cat = 'Ammo',       keys = { 'ammo_arrow', 'ammo_bullet', 'ammo_shell', 'ammo_rocket', 'ammo_thermal', 'ammo_mortar_shell' } },
    { cat = 'Drugs',      keys = { 'spike', 'stardust', 'drift', 'smog', 'rotgut', 'shards', 'glimpse', 'surge', 'thaw', 'voidbloom' } },
}

---------------------------------------------------------------------------
-- Draw helpers
---------------------------------------------------------------------------

local fonts = {}

local function ensureFonts()
    if fonts.header then return end
    fonts.header = love.graphics.newFont(14)
    fonts.body   = love.graphics.newFont(11)
    fonts.small  = love.graphics.newFont(9)
end

local hitZones = {}

local function addHitZone(x, y, w, h, action)
    hitZones[#hitZones + 1] = { x = x, y = y, w = w, h = h, action = action }
end

local function drawToggle(x, y, label, enabled)
    local bx = x
    local by = y
    local bw = 16
    local bh = 14

    -- Checkbox
    if enabled then
        love.graphics.setColor(0.2, 0.7, 0.3, 0.9)
        love.graphics.rectangle('fill', bx, by + 2, bw, bh, 2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print('X', bx + 3, by + 1)
    else
        love.graphics.setColor(0.3, 0.3, 0.35, 0.8)
        love.graphics.rectangle('fill', bx, by + 2, bw, bh, 2)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle('line', bx, by + 2, bw, bh, 2)
    end

    -- Label
    love.graphics.setColor(0.85, 0.85, 0.85)
    love.graphics.print(label, bx + bw + 6, by + 1)
end

local function drawButton(x, y, w, h, label, hovered)
    if hovered then
        love.graphics.setColor(0.2, 0.35, 0.55, 0.95)
    else
        love.graphics.setColor(0.12, 0.18, 0.28, 0.85)
    end
    love.graphics.rectangle('fill', x, y, w, h, 3)
    love.graphics.setColor(0.35, 0.5, 0.7, 0.8)
    love.graphics.rectangle('line', x, y, w, h, 3)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print(label, x + 6, y + 3)
end

local function drawSectionHeader(x, y, text)
    love.graphics.setColor(0.6, 0.75, 0.9)
    love.graphics.setFont(fonts.header)
    love.graphics.print(text, x, y)
    love.graphics.setColor(0.25, 0.35, 0.5, 0.6)
    love.graphics.line(x, y + 16, x + 500, y + 16)
    love.graphics.setFont(fonts.body)
end

local function drawSparkline(x, y, w, h, values, color)
    if not values or #values < 2 then
        love.graphics.setColor(0.18, 0.2, 0.24, 0.85)
        love.graphics.rectangle('line', x, y, w, h, 3)
        return
    end

    local minV, maxV = values[1], values[1]
    for i = 2, #values do
        minV = math.min(minV, values[i])
        maxV = math.max(maxV, values[i])
    end
    local span = math.max(0.001, maxV - minV)
    local lastIdx = #values

    love.graphics.setColor(0.08, 0.1, 0.14, 0.9)
    love.graphics.rectangle('fill', x, y, w, h, 3)
    love.graphics.setColor(0.18, 0.2, 0.24, 0.85)
    love.graphics.rectangle('line', x, y, w, h, 3)

    local points = {}
    for i, value in ipairs(values) do
        local px = x + ((i - 1) / math.max(1, lastIdx - 1)) * w
        local norm = (value - minV) / span
        local py = y + h - norm * h
        points[#points + 1] = px
        points[#points + 1] = py
    end

    love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.95)
    if #points >= 4 then
        love.graphics.line(points)
    end
end

---------------------------------------------------------------------------
-- Tab content drawers
-- Each returns the total content height so we can compute scroll bounds.
---------------------------------------------------------------------------

local function drawGodTab(cx, cy, cw, mx, my)
    local y = cy
    for _, tog in ipairs(GOD_TOGGLES) do
        local enabled = DebugPanel[tog.id]
        drawToggle(cx, y, tog.label, enabled)
        addHitZone(cx, y, TOGGLE_W + 40, ITEM_H, function()
            DebugPanel[tog.id] = not DebugPanel[tog.id]
            flash(tog.label .. ': ' .. (DebugPanel[tog.id] and 'ON' or 'OFF'))
            -- Side effects
            if tog.id == 'revealMap' then
                GameState.fogOfWar = not DebugPanel.revealMap
            end
        end)
        -- Description
        love.graphics.setColor(0.45, 0.45, 0.5)
        love.graphics.setFont(fonts.small)
        love.graphics.print(tog.desc, cx + TOGGLE_W + 50, y + 3)
        love.graphics.setFont(fonts.body)
        y = y + ITEM_H
    end

    y = y + 12

    -- Quick actions
    drawSectionHeader(cx, y, 'Quick Actions')
    y = y + HEADER_H

    local actions = {
        { label = 'Heal All Colonists',    fn = function()
            for id, comps in ECS.query('colonist', 'needs') do
                local col = comps.colonist
                col.health = col.maxHealth or 100
                comps.needs.warmth = 100
                comps.needs.food = 100
                comps.needs.rest = 100
                comps.needs.morale = 100
                if comps.needs.water then comps.needs.water = 100 end
            end
            flash('All colonists healed and needs filled')
        end },
        { label = 'Kill All Hostiles',     fn = function()
            local killed = 0
            for id, comps in ECS.query('creature') do
                local cr = comps.creature
                if cr.hostile then
                    cr.health = 0
                    cr.state = 'dead'
                    killed = killed + 1
                end
            end
            flash('Killed ' .. killed .. ' hostile creatures')
        end },
        { label = 'Fill All Resources (+100)', fn = function()
            for res in pairs(GameState.resources) do
                GameState.resources[res] = (GameState.resources[res] or 0) + 100
            end
            flash('Added 100 to all resources')
        end },
        { label = 'Unlock All Research',   fn = function()
            local rok, Research = pcall(require, 'src.research.research')
            if rok and Research.unlockAll then
                Research.unlockAll()
                flash('All research unlocked')
            elseif rok and Research.NODES then
                for nodeId in pairs(Research.NODES) do
                    Research.complete(nodeId)
                end
                flash('All research completed')
            else
                flash('Research module not available')
            end
        end },
        { label = 'Max Hope / Zero Discontent', fn = function()
            local hok, Hope = pcall(require, 'src.colony.hope')
            if hok then
                Hope.applyDelta(100, -100)
                flash('Hope maxed, discontent zeroed')
            end
        end },
        { label = 'Clear Anomaly',         fn = function()
            local aok, Anomaly = pcall(require, 'src.sim.anomaly')
            if aok and Anomaly.onBossDefeated then
                Anomaly.onBossDefeated()
                flash('Anomaly cleared')
            end
        end },
    }

    for _, act in ipairs(actions) do
        local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
        drawButton(cx, y, BTN_W, BTN_H, act.label, hov)
        addHitZone(cx, y, BTN_W, BTN_H, act.fn)
        y = y + BTN_H + 4
    end

    return y - cy
end

local function drawEventsTab(cx, cy, cw, mx, my)
    local y = cy
    local events = getEventList()

    for _, cat in ipairs(events) do
        drawSectionHeader(cx, y, cat.cat .. ' (' .. #cat.ids .. ')')
        y = y + HEADER_H

        for _, ev in ipairs(cat.ids) do
            local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
            drawButton(cx, y, BTN_W, BTN_H, ev.name, hov)
            addHitZone(cx, y, BTN_W, BTN_H, function()
                local sok, Storyteller = pcall(require, 'src.storyteller.storyteller')
                if sok and Storyteller.executeEvent then
                    local result = Storyteller.executeEvent(ev.id)
                    flash('Event: ' .. ev.name .. (result and '' or ' (rejected)'))
                elseif sok and Storyteller.fireEvent then
                    Storyteller.fireEvent(ev.id)
                    flash('Event: ' .. ev.name)
                else
                    flash('Cannot fire event: storyteller API unavailable')
                end
            end)
            y = y + BTN_H + 2
        end
        y = y + 6
    end

    -- Fallback if no events found
    if #events == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No events available (storyteller.getEventDefs not found)', cx, y)
        y = y + 20
    end

    return y - cy
end

local function drawRaidsTab(cx, cy, cw, mx, my)
    local y = cy
    drawSectionHeader(cx, y, 'Trigger Raid')
    y = y + HEADER_H

    local raids = getRaidTypes()
    for _, r in ipairs(raids) do
        local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
        drawButton(cx, y, BTN_W, BTN_H, r.name or r.id, hov)
        addHitZone(cx, y, BTN_W, BTN_H, function()
            local rok, Raids = pcall(require, 'src.sim.raids')
            if rok and Raids.startRaid then
                local result, err = Raids.startRaid(r.id)
                if result then
                    flash('Raid started: ' .. (r.name or r.id))
                else
                    flash('Raid failed: ' .. (err or 'unknown'))
                end
            else
                flash('Raid module not available')
            end
        end)
        y = y + BTN_H + 2
    end

    y = y + 12
    drawSectionHeader(cx, y, 'Raid Controls')
    y = y + HEADER_H

    local hov1 = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
    drawButton(cx, y, BTN_W, BTN_H, 'End Active Raid', hov1)
    addHitZone(cx, y, BTN_W, BTN_H, function()
        local rok, Raids = pcall(require, 'src.sim.raids')
        if rok and Raids.endRaid then
            Raids.endRaid()
            flash('Raid ended')
        elseif rok and Raids.getActiveRaid then
            local ar = Raids.getActiveRaid()
            if ar then ar.phase = 'complete' end
            flash('Raid force-completed')
        end
    end)
    y = y + BTN_H + 4

    return y - cy
end

local function drawCreaturesTab(cx, cy, cw, mx, my)
    local y = cy

    love.graphics.setColor(0.5, 0.55, 0.6)
    love.graphics.print('Creatures spawn near colony center.', cx, y)
    y = y + 16

    local species = getCreatureSpecies()
    for _, cat in ipairs(species) do
        drawSectionHeader(cx, y, cat.cat .. ' (' .. #cat.species .. ')')
        y = y + HEADER_H

        -- Two-column layout for compact display
        local col2x = cx + BTN_W + 8
        local colIdx = 0
        for _, sp in ipairs(cat.species) do
            local bx = (colIdx % 2 == 0) and cx or col2x
            local by = y
            local label = sp.name
            if sp.hp > 0 then label = label .. ' (' .. sp.hp .. ' HP)' end
            local hov = mx >= bx and mx <= bx + BTN_W and my >= by and my <= by + BTN_H
            drawButton(bx, by, BTN_W, BTN_H, label, hov)
            addHitZone(bx, by, BTN_W, BTN_H, function()
                local cok, Creatures = pcall(require, 'src.creatures.creatures')
                if cok and Creatures.spawn then
                    local sx = (GameState.startX or 64) + math.random(-10, 10)
                    local sy = (GameState.startY or 64) + math.random(-10, 10)
                    Creatures.spawn(sp.id, sx, sy, 0)
                    flash('Spawned: ' .. sp.name)
                else
                    flash('Creature module not available')
                end
            end)
            if colIdx % 2 == 1 then y = y + BTN_H + 2 end
            colIdx = colIdx + 1
        end
        if colIdx % 2 == 1 then y = y + BTN_H + 2 end
        y = y + 6
    end

    return y - cy
end

local function drawColonistsTab(cx, cy, cw, mx, my)
    local y = cy

    drawSectionHeader(cx, y, 'Spawn')
    y = y + HEADER_H

    local spawnActions = {
        { label = 'Spawn Random Colonist', fn = function()
            local cok, Col = pcall(require, 'src.colonist.colonist')
            if cok and Col.spawn then
                local sx = (GameState.startX or 64) + math.random(-5, 5)
                local sy = (GameState.startY or 64) + math.random(-5, 5)
                Col.spawn(sx, sy)
                flash('Colonist spawned')
            end
        end },
        { label = 'Spawn 5 Colonists', fn = function()
            local cok, Col = pcall(require, 'src.colonist.colonist')
            if cok and Col.spawn then
                for i = 1, 5 do
                    local sx = (GameState.startX or 64) + math.random(-8, 8)
                    local sy = (GameState.startY or 64) + math.random(-8, 8)
                    Col.spawn(sx, sy)
                end
                flash('5 colonists spawned')
            end
        end },
        { label = 'Spawn Prisoner', fn = function()
            local rok, Recruitment = pcall(require, 'src.colonist.recruitment')
            if rok and Recruitment.spawnDowned then
                Recruitment.spawnDowned(math.random(5, 20), math.random(5, 20))
                flash('Prisoner spawned')
            else
                flash('Recruitment module not available')
            end
        end },
    }

    for _, act in ipairs(spawnActions) do
        local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
        drawButton(cx, y, BTN_W, BTN_H, act.label, hov)
        addHitZone(cx, y, BTN_W, BTN_H, act.fn)
        y = y + BTN_H + 4
    end

    y = y + 8
    drawSectionHeader(cx, y, 'Modify Selected Colonist')
    y = y + HEADER_H

    local selId = GameState.selectedEntities and GameState.selectedEntities[1] or nil
    if not selId or not ECS.get(selId, 'colonist') then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('Select a colonist first.', cx, y)
        y = y + 20
    else
        local col = ECS.get(selId, 'colonist')
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print('Selected: ' .. (col.name or 'Unknown'), cx, y)
        y = y + 18

        local modActions = {
            { label = 'Max All Skills (10)',   fn = function()
                if col.skills then
                    for sk in pairs(col.skills) do col.skills[sk] = 10 end
                    flash('Skills maxed for ' .. (col.name or 'colonist'))
                end
            end },
            { label = 'Full Heal',             fn = function()
                col.health = col.maxHealth or 100
                local needs = ECS.get(selId, 'needs')
                if needs then
                    needs.warmth = 100; needs.food = 100; needs.rest = 100; needs.morale = 100
                    if needs.water then needs.water = 100 end
                end
                local body = ECS.get(selId, 'body')
                if body and body.parts then
                    for _, part in pairs(body.parts) do
                        part.hp = part.maxHp or part.hp
                    end
                end
                flash('Fully healed ' .. (col.name or 'colonist'))
            end },
            { label = 'Trigger Mental Break',  fn = function()
                local mok, MB = pcall(require, 'src.colonist.mental_breaks')
                if mok and MB.triggerBreak then
                    MB.triggerBreak(selId)
                    flash('Mental break triggered')
                end
            end },
            { label = 'Kill Colonist',         fn = function()
                col.health = 0
                col.state = 'dead'
                flash('Killed ' .. (col.name or 'colonist'))
            end },
        }

        for _, act in ipairs(modActions) do
            local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
            drawButton(cx, y, BTN_W, BTN_H, act.label, hov)
            addHitZone(cx, y, BTN_W, BTN_H, act.fn)
            y = y + BTN_H + 4
        end
    end

    return y - cy
end

local function drawWeatherTab(cx, cy, cw, mx, my)
    local y = cy

    -- Current weather
    local wok, Weather = pcall(require, 'src.weather.weather')
    if wok then
        local current = Weather.getCurrent and Weather.getCurrent() or 'unknown'
        love.graphics.setColor(0.7, 0.8, 0.9)
        love.graphics.print('Current: ' .. tostring(current), cx, y)
        y = y + 18
    end

    drawSectionHeader(cx, y, 'Set Weather')
    y = y + HEADER_H

    for _, w in ipairs(WEATHER_TYPES) do
        local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
        drawButton(cx, y, BTN_W, BTN_H, w.name, hov)
        addHitZone(cx, y, BTN_W, BTN_H, function()
            if wok and Weather.forceWeather then
                Weather.forceWeather(w.id)
                flash('Weather set: ' .. w.name)
            elseif wok and Weather.setWeather then
                Weather.setWeather(w.id)
                flash('Weather set: ' .. w.name)
            else
                flash('Weather API not available')
            end
        end)
        y = y + BTN_H + 2
    end

    y = y + 12
    drawSectionHeader(cx, y, 'Temperature Override')
    y = y + HEADER_H

    local temps = { -60, -40, -20, -10, 0, 10, 20 }
    for _, t in ipairs(temps) do
        local label = string.format('Set Ambient: %d C', t)
        local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
        drawButton(cx, y, BTN_W, BTN_H, label, hov)
        addHitZone(cx, y, BTN_W, BTN_H, function()
            GameState.globalTemp = t
            GameState.baseTemp = t
            flash('Temperature set to ' .. t .. ' C')
        end)
        y = y + BTN_H + 2
    end

    return y - cy
end

local function drawResourcesTab(cx, cy, cw, mx, my)
    local y = cy
    local amounts = { 10, 50, 100, 500 }

    for _, group in ipairs(RESOURCE_GROUPS) do
        drawSectionHeader(cx, y, group.cat)
        y = y + HEADER_H

        for _, res in ipairs(group.keys) do
            local current = GameState.resources[res] or 0
            love.graphics.setColor(0.65, 0.65, 0.65)
            love.graphics.print(string.format('%s: %d', res, current), cx, y + 3)

            -- +N buttons
            local bx = cx + 180
            for _, amt in ipairs(amounts) do
                local label = '+' .. amt
                local bw = 36
                local hov = mx >= bx and mx <= bx + bw and my >= y and my <= y + BTN_H
                drawButton(bx, y, bw, BTN_H, label, hov)
                addHitZone(bx, y, bw, BTN_H, function()
                    GameState.resources[res] = (GameState.resources[res] or 0) + amt
                    flash(res .. ' +' .. amt)
                end)
                bx = bx + bw + 4
            end

            -- Zero button
            local zLabel = 'Zero'
            local zw = 36
            local zhov = mx >= bx and mx <= bx + zw and my >= y and my <= y + BTN_H
            drawButton(bx, y, zw, BTN_H, zLabel, zhov)
            addHitZone(bx, y, zw, BTN_H, function()
                GameState.resources[res] = 0
                flash(res .. ' zeroed')
            end)

            y = y + BTN_H + 2
        end
        y = y + 6
    end

    return y - cy
end

local function drawProfilerTab(cx, cy, cw, mx, my)
    local y = cy
    local pok, Profiler = pcall(require, 'src.util.profiler')
    if not pok then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print('Profiler module unavailable.', cx, y)
        return 20
    end

    love.graphics.setColor(0.7, 0.8, 0.9)
    love.graphics.print('Capture sim timings live. Sorted by average ms per call.', cx, y)
    y = y + 20

    local enabled = Profiler.isEnabled and Profiler.isEnabled() or false
    local toggleLabel = enabled and 'Disable Capture' or 'Enable Capture'
    local hovToggle = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
    drawButton(cx, y, BTN_W, BTN_H, toggleLabel, hovToggle)
    addHitZone(cx, y, BTN_W, BTN_H, function()
        local active = Profiler.toggle and Profiler.toggle() or false
        flash('Profiler ' .. (active and 'enabled' or 'disabled'))
    end)

    local resetX = cx + BTN_W + 8
    local hovReset = mx >= resetX and mx <= resetX + 120 and my >= y and my <= y + BTN_H
    drawButton(resetX, y, 120, BTN_H, 'Reset Samples', hovReset)
    addHitZone(resetX, y, 120, BTN_H, function()
        if Profiler.reset then Profiler.reset() end
        flash('Profiler samples cleared')
    end)
    y = y + BTN_H + 10

    local entries = Profiler.getEntries and Profiler.getEntries() or {}
    local simTick = Profiler.getEntry and Profiler.getEntry('Sim Tick') or nil
    local frame = Profiler.getFrameSummary and Profiler.getFrameSummary() or nil
    local categories = Profiler.getCategorySummaries and Profiler.getCategorySummaries() or {}

    if simTick then
        love.graphics.setColor(0.85, 0.88, 0.92)
        love.graphics.print(string.format('Sim Tick  avg %.3f ms  last %.3f  max %.3f  calls %d',
            simTick.avgMs or 0, simTick.lastMs or 0, simTick.maxMs or 0, simTick.calls or 0), cx, y)
        y = y + 18

        local history = Profiler.getHistory and Profiler.getHistory('Sim Tick') or {}
        drawSparkline(cx, y, math.min(360, cw - 20), 42, history, {0.4, 0.78, 1.0, 0.95})
        y = y + 50
    end

    if frame then
        drawSectionHeader(cx, y, 'Last Frame')
        y = y + HEADER_H
        love.graphics.setColor(0.82, 0.84, 0.88)
        love.graphics.print(string.format('Frame %.3f ms  inner %.3f ms', frame.frameMs or 0, frame.innerMs or 0), cx, y)
        y = y + 16
        if frame.hottest then
            love.graphics.setColor(0.7, 0.78, 0.92)
            love.graphics.print(string.format('Hotspot: %s (%.3f ms)', frame.hottest.name, frame.hottest.elapsedMs or 0), cx, y)
            y = y + 16
        end
        if frame.overBudget and #frame.overBudget > 0 then
            love.graphics.setColor(0.95, 0.58, 0.22)
            love.graphics.print(string.format('Budget overruns: %d', #frame.overBudget), cx, y)
            y = y + 16
        end
    end

    drawSectionHeader(cx, y, 'Categories')
    y = y + HEADER_H
    local shownCats = 0
    for _, category in ipairs(categories) do
        love.graphics.setColor(0.78, 0.82, 0.88)
        love.graphics.print(string.format('%s  avg %.3f ms  max %.3f  entries %d',
            category.category, category.avgMs or 0, category.maxMs or 0, category.entries or 0), cx, y)
        y = y + 16
        shownCats = shownCats + 1
        if shownCats >= 5 then break end
    end

    drawSectionHeader(cx, y, 'Top Systems')
    y = y + HEADER_H

    love.graphics.setColor(0.55, 0.6, 0.66)
    love.graphics.setFont(fonts.small)
    love.graphics.print('Name', cx, y)
    love.graphics.print('Avg', cx + 220, y)
    love.graphics.print('Last', cx + 290, y)
    love.graphics.print('Max', cx + 360, y)
    love.graphics.print('Calls', cx + 430, y)
    love.graphics.setFont(fonts.body)
    y = y + 14

    local shown = 0
    for _, entry in ipairs(entries) do
        if entry.name ~= 'Sim Tick' then
            local color = entry.overBudget and { 1.0, 0.7, 0.42 } or { 0.82, 0.84, 0.88 }
            love.graphics.setColor(color)
            love.graphics.print(entry.name, cx, y)
            love.graphics.print(string.format('%.3f', entry.avgMs or 0), cx + 220, y)
            love.graphics.print(string.format('%.3f', entry.lastMs or 0), cx + 290, y)
            love.graphics.print(string.format('%.3f', entry.maxMs or 0), cx + 360, y)
            local callsText = tostring(entry.calls or 0)
            if entry.budgetMs then
                callsText = callsText .. string.format('  (%.1f)', entry.budgetMs)
            end
            love.graphics.print(callsText, cx + 430, y)
            y = y + 16
            shown = shown + 1
            if shown >= 18 then break end
        end
    end

    if shown == 0 then
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.print(enabled and 'No samples recorded yet.' or 'Enable capture to start collecting timings.', cx, y)
        y = y + 18
    end

    return y - cy
end

local function drawWorldTab(cx, cy, cw, mx, my)
    local y = cy

    -- Time display
    love.graphics.setColor(0.7, 0.8, 0.9)
    love.graphics.print(string.format('Day: %d  Hour: %02d:00  Tick: %d',
        GameState.day or 1, math.floor(GameState.hour or 6), GameState.simTick or 0), cx, y)
    y = y + 20

    drawSectionHeader(cx, y, 'Time Controls')
    y = y + HEADER_H

    local timeActions = {
        { label = 'Advance 1 Hour',   fn = function()
            GameState.hour = (GameState.hour or 6) + 1
            if GameState.hour >= 24 then
                GameState.hour = GameState.hour - 24
                GameState.day = (GameState.day or 1) + 1
            end
            flash('Advanced 1 hour')
        end },
        { label = 'Advance 1 Day',    fn = function()
            GameState.day = (GameState.day or 1) + 1
            flash('Day ' .. GameState.day)
        end },
        { label = 'Advance 10 Days',  fn = function()
            GameState.day = (GameState.day or 1) + 10
            flash('Day ' .. GameState.day)
        end },
        { label = 'Set Dawn (06:00)', fn = function()
            GameState.hour = 6
            flash('Set to dawn')
        end },
        { label = 'Set Night (22:00)', fn = function()
            GameState.hour = 22
            flash('Set to night')
        end },
    }

    for _, act in ipairs(timeActions) do
        local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
        drawButton(cx, y, BTN_W, BTN_H, act.label, hov)
        addHitZone(cx, y, BTN_W, BTN_H, act.fn)
        y = y + BTN_H + 4
    end

    y = y + 8
    drawSectionHeader(cx, y, 'Speed')
    y = y + HEADER_H

    for _, spd in ipairs({ 1, 2, 3, 5, 10 }) do
        local label = spd .. 'x Speed'
        local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
        drawButton(cx, y, BTN_W, BTN_H, label, hov)
        addHitZone(cx, y, BTN_W, BTN_H, function()
            GameState.speed = spd
            flash('Speed set to ' .. spd .. 'x')
        end)
        y = y + BTN_H + 2
    end

    y = y + 8
    drawSectionHeader(cx, y, 'Anomaly')
    y = y + HEADER_H

    local aok, Anomaly = pcall(require, 'src.sim.anomaly')
    if aok then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(string.format('Level: %.1f  Tier: %s',
            Anomaly.getLevel(), Anomaly.getTier()), cx, y)
        y = y + 18

        local anomActions = {
            { label = 'Set Anomaly to 0',   fn = function() Anomaly.addAnomaly(-Anomaly.getLevel(), 'debug') end },
            { label = 'Set Anomaly to 50',  fn = function() Anomaly.addAnomaly(50 - Anomaly.getLevel(), 'debug') end },
            { label = 'Set Anomaly to 100', fn = function() Anomaly.addAnomaly(100 - Anomaly.getLevel(), 'debug') end },
            { label = 'Awaken Boss',        fn = function()
                if Anomaly.awakenBoss then
                    Anomaly.addAnomaly(100, 'debug')
                    Anomaly.awakenBoss()
                    flash('Boss awakened')
                end
            end },
        }

        for _, act in ipairs(anomActions) do
            local hov = mx >= cx and mx <= cx + BTN_W and my >= y and my <= y + BTN_H
            drawButton(cx, y, BTN_W, BTN_H, act.label, hov)
            addHitZone(cx, y, BTN_W, BTN_H, act.fn)
            y = y + BTN_H + 4
        end
    end

    return y - cy
end

---------------------------------------------------------------------------
-- Main draw
---------------------------------------------------------------------------

function DebugPanel.draw()
    if not open then return end
    ensureFonts()

    local sw, sh = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    hitZones = {}

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Panel background
    local panelX = 20
    local panelY = 20
    local panelW = sw - 40
    local panelH = sh - 40

    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 6)
    love.graphics.setColor(0.2, 0.3, 0.5, 0.6)
    love.graphics.rectangle('line', panelX, panelY, panelW, panelH, 6)

    -- Title
    love.graphics.setFont(fonts.header)
    love.graphics.setColor(0.9, 0.6, 0.2)
    love.graphics.print('DEBUG TOOLS', panelX + PANEL_PAD, panelY + 8)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(fonts.small)
    love.graphics.print('F7 to close', panelX + 120, panelY + 10)

    -- Status message
    if statusMsg and statusTimer > 0 then
        love.graphics.setColor(0.3, 0.9, 0.4, math.min(1.0, statusTimer))
        love.graphics.setFont(fonts.body)
        love.graphics.print(statusMsg, panelX + panelW - 300, panelY + 10)
    end

    -- Tab bar (left sidebar)
    local tabX = panelX + PANEL_PAD
    local tabY = panelY + 32
    love.graphics.setFont(fonts.body)

    for i, tab in ipairs(TABS) do
        local ty = tabY + (i - 1) * (TAB_H + 2)
        local isSel = (activeTab == tab.id)
        local isHov = mx >= tabX and mx <= tabX + TAB_W and my >= ty and my <= ty + TAB_H

        if isSel then
            love.graphics.setColor(0.15, 0.25, 0.4, 0.9)
            love.graphics.rectangle('fill', tabX, ty, TAB_W, TAB_H, 3)
            love.graphics.setColor(0.4, 0.6, 0.9)
            love.graphics.rectangle('line', tabX, ty, TAB_W, TAB_H, 3)
            love.graphics.setColor(1, 1, 1)
        elseif isHov then
            love.graphics.setColor(0.1, 0.15, 0.25, 0.6)
            love.graphics.rectangle('fill', tabX, ty, TAB_W, TAB_H, 3)
            love.graphics.setColor(0.8, 0.85, 0.9)
        else
            love.graphics.setColor(0.55, 0.6, 0.65)
        end
        love.graphics.print(tab.label, tabX + 8, ty + 6)

        addHitZone(tabX, ty, TAB_W, TAB_H, function()
            activeTab = tab.id
            scrollY = 0
        end)
    end

    -- Content area (scrollable)
    local contentX = panelX + PANEL_PAD + TAB_W + 16
    local contentY = panelY + 32
    local contentW = panelW - TAB_W - PANEL_PAD * 3 - 16
    local contentH = panelH - 40

    -- Scissor clip for scrolling
    love.graphics.setScissor(contentX, contentY, contentW, contentH)
    love.graphics.push()
    love.graphics.translate(0, -scrollY)

    -- Adjust mouse Y for scroll offset
    local smy = my + scrollY

    love.graphics.setFont(fonts.body)
    local totalH = 0
    if activeTab == 'god' then
        totalH = drawGodTab(contentX, contentY, contentW, mx, smy)
    elseif activeTab == 'events' then
        totalH = drawEventsTab(contentX, contentY, contentW, mx, smy)
    elseif activeTab == 'raids' then
        totalH = drawRaidsTab(contentX, contentY, contentW, mx, smy)
    elseif activeTab == 'creatures' then
        totalH = drawCreaturesTab(contentX, contentY, contentW, mx, smy)
    elseif activeTab == 'colonists' then
        totalH = drawColonistsTab(contentX, contentY, contentW, mx, smy)
    elseif activeTab == 'weather' then
        totalH = drawWeatherTab(contentX, contentY, contentW, mx, smy)
    elseif activeTab == 'resources' then
        totalH = drawResourcesTab(contentX, contentY, contentW, mx, smy)
    elseif activeTab == 'profiler' then
        totalH = drawProfilerTab(contentX, contentY, contentW, mx, smy)
    elseif activeTab == 'world' then
        totalH = drawWorldTab(contentX, contentY, contentW, mx, smy)
    end

    MAX_SCROLL = math.max(0, totalH - contentH + 20)

    love.graphics.pop()
    love.graphics.setScissor()

    -- Scroll indicator
    if MAX_SCROLL > 0 then
        local barH = contentH * (contentH / (totalH + 20))
        local barY = contentY + (scrollY / MAX_SCROLL) * (contentH - barH)
        love.graphics.setColor(0.3, 0.4, 0.5, 0.5)
        love.graphics.rectangle('fill', contentX + contentW - 6, barY, 4, barH, 2)
    end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function DebugPanel.mousepressed(x, y, button)
    if not open then return false end
    if button ~= 1 then return true end  -- consume all clicks when open

    -- Hit zones are drawn in translated (scrolled) coordinates for content,
    -- but tab zones use screen coordinates. We check with scroll offset applied
    -- to mouse y. Tab zones were drawn without translation so they match
    -- screen-space y directly. Content zones were drawn translated by -scrollY
    -- so their stored y is in content-space; mouse y needs +scrollY to match.
    -- Since both are in the same array, we just check both transforms and
    -- pick the first match.
    local sy = y + scrollY  -- scrolled mouse y (for content items)
    for _, zone in ipairs(hitZones) do
        -- Try scroll-adjusted first (content zones)
        if x >= zone.x and x <= zone.x + zone.w
           and sy >= zone.y and sy <= zone.y + zone.h then
            zone.action()
            return true
        end
        -- Try direct screen-space (tab zones, which aren't scrolled)
        if x >= zone.x and x <= zone.x + zone.w
           and y >= zone.y and y <= zone.y + zone.h then
            zone.action()
            return true
        end
    end

    return true  -- consume click
end

function DebugPanel.wheelmoved(dx, dy)
    if not open then return false end
    scrollY = math.max(0, math.min(MAX_SCROLL, scrollY - dy * 30))
    return true
end

function DebugPanel.keypressed(key)
    if key == 'f7' then
        DebugPanel.toggle()
        return true
    end
    if open and key == 'escape' then
        DebugPanel.close()
        return true
    end
    return open  -- consume all keys when open
end

---------------------------------------------------------------------------
-- Step (for status timer)
---------------------------------------------------------------------------

function DebugPanel.step(dt)
    if statusTimer > 0 then
        statusTimer = statusTimer - dt
    end
end

return DebugPanel
