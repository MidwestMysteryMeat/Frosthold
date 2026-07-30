-- ui_hud.lua — Resource bar, time bar, critical alerts, colonist bar, selection box, toolbar

local GameState = require('src.game_state')
local Layout    = require('src.ui.ui_layout')
local ECS       = require('src.ecs.ecs')

local HUD = {}

-- Hit zones (rebuilt each frame during draw)
local speedBtns = {}
local pauseBtn = nil
local colonistCards = {}
local alertHitZones = {}
local resourceHitZones = {}

-- Shared screen dimensions (set via resize)
local screenW, screenH = 1280, 720

-- HUD fonts (created lazily to avoid issues before love.load)
local hudFontMain, hudFontSmall, hudFontTiny
local function getHudFonts()
    if not hudFontMain then
        hudFontMain  = love.graphics.newFont(14)
        hudFontSmall = love.graphics.newFont(12)
        hudFontTiny  = love.graphics.newFont(10)
    end
    return hudFontMain, hudFontSmall, hudFontTiny
end

local DAY_SECONDS = 24 * 60
local FOOD_RESOURCE_NUTRITION = 20
local METRIC_SAMPLE_INTERVAL = 10
local METRIC_WINDOW = 180
local metricHistory = {}
local lastMetricSample = nil
local lastMetricTick = -1
local colonySnapshot = nil
local colonySnapshotTick = -1
local foodEquivalentValue = 0
local foodEquivalentTick = -1

local _Production, _Zones, _Policies, _Laws, _Research, _Hermes, _Quotas
local _Containment, _Fire, _Raids, _Hope, _Power, _Jobs, _World
local _TileGas, _Atmosphere, _Rooms, _Building
local _modsLoaded = false

local function lazyLoadHUDMods()
    if _modsLoaded then return end
    _modsLoaded = true
    local ok
    ok, _Production = pcall(require, 'src.building.production')
    if not ok then _Production = false end
    ok, _Zones = pcall(require, 'src.world.zones')
    if not ok then _Zones = false end
    ok, _Policies = pcall(require, 'src.colony.policies')
    if not ok then _Policies = false end
    ok, _Laws = pcall(require, 'src.colony.laws')
    if not ok then _Laws = false end
    ok, _Research = pcall(require, 'src.research.research')
    if not ok then _Research = false end
    ok, _Hermes = pcall(require, 'src.sim.hermes')
    if not ok then _Hermes = false end
    ok, _Quotas = pcall(require, 'src.sim.quotas')
    if not ok then _Quotas = false end
    ok, _Containment = pcall(require, 'src.sim.containment')
    if not ok then _Containment = false end
    ok, _Fire = pcall(require, 'src.sim.fire')
    if not ok then _Fire = false end
    ok, _Raids = pcall(require, 'src.sim.raids')
    if not ok then _Raids = false end
    ok, _Hope = pcall(require, 'src.colony.hope')
    if not ok then _Hope = false end
    ok, _Power = pcall(require, 'src.sim.power')
    if not ok then _Power = false end
    ok, _Jobs = pcall(require, 'src.colonist.jobs')
    if not ok then _Jobs = false end
    ok, _World = pcall(require, 'src.world.tilemap')
    if not ok then _World = false end
    ok, _TileGas = pcall(require, 'src.sim.tile_gas')
    if not ok then _TileGas = false end
    ok, _Atmosphere = pcall(require, 'src.sim.atmosphere')
    if not ok then _Atmosphere = false end
    ok, _Rooms = pcall(require, 'src.world.rooms')
    if not ok then _Rooms = false end
    ok, _Building = pcall(require, 'src.building.building')
    if not ok then _Building = false end
end

-- Delegates to ui_layout so there is one truncation implementation. The local
-- version walked byte indices, which splits multi-byte characters and makes
-- font:getWidth throw.
local function truncateTextForWidth(text, maxWidth, font)
    if maxWidth and maxWidth <= 0 then return tostring(text or '') end
    return Layout.truncate(text, maxWidth, font)
end

HUD._truncateTextForWidth = truncateTextForWidth

function HUD.resize(w, h)
    screenW = w
    screenH = h
end

function HUD.getScreenSize()
    return screenW, screenH
end

function HUD.getSpeedBtns() return speedBtns end
function HUD.getPauseBtn() return pauseBtn end
function HUD.getColonistCards() return colonistCards end
function HUD.getAlertHitZones() return alertHitZones end
function HUD.getResourceHitZones() return resourceHitZones end

local function resetMetricHistory()
    metricHistory = {}
    lastMetricSample = nil
    lastMetricTick = -1
    colonySnapshot = nil
    colonySnapshotTick = -1
    foodEquivalentValue = 0
    foodEquivalentTick = -1
end

local function getColonySnapshot()
    if colonySnapshotTick == GameState.simTick and colonySnapshot then
        return colonySnapshot
    end

    local stats = { total = 0, healthy = 0, injured = 0, sick = 0, drafted = 0, idle = 0 }
    for id, comps in ECS.query('colonist') do
        local col = comps.colonist
        if col.state ~= 'dead' then
            stats.total = stats.total + 1
            if (col.health or 100) < (col.maxHealth or 100) then
                stats.injured = stats.injured + 1
            else
                stats.healthy = stats.healthy + 1
            end
            if ECS.get(id, 'disease') then
                stats.sick = stats.sick + 1
            end
            if col.drafted then
                stats.drafted = stats.drafted + 1
            end
            if col.state == 'idle' then
                stats.idle = stats.idle + 1
            end
        end
    end

    colonySnapshot = stats
    colonySnapshotTick = GameState.simTick
    return stats
end

local function getFoodEquivalent()
    if foodEquivalentTick == GameState.simTick then
        return foodEquivalentValue
    end

    lazyLoadHUDMods()
    local total = (GameState.resources.food or 0) * FOOD_RESOURCE_NUTRITION
    local fqTable = (_Production and _Production.FOOD_QUALITY) or {}
    if _Zones and _Zones.getAll then
        for _, zone in pairs(_Zones.getAll()) do
            if zone.items then
                for _, item in pairs(zone.items) do
                    local fq = item and fqTable[item.itemId]
                    if fq then
                        total = total + fq.nutrition * (item.amount or 1)
                    end
                end
            end
        end
    end
    for _, comps in ECS.query('item') do
        local item = comps.item
        local fq = item and fqTable[item.itemId]
        if fq and not item.hauled then
            total = total + fq.nutrition * (item.amount or 1)
        end
    end

    foodEquivalentValue = total
    foodEquivalentTick = GameState.simTick
    return foodEquivalentValue
end

local function getPopulationStats()
    return getColonySnapshot()
end

local function getFoodDemandPerSecond()
    local count = getColonySnapshot().total
    if count <= 0 then return 0 end

    local mult = 1.0
    lazyLoadHUDMods()
    if _Policies and _Policies.getFoodDrainMult then
        mult = mult * _Policies.getFoodDrainMult()
    end
    if _Laws and _Laws.getFoodDrainMult then
        mult = mult * _Laws.getFoodDrainMult()
    end

    return count * 0.03 * mult
end

local function getWaterDemandPerSecond()
    local count = getColonySnapshot().total
    if count <= 0 then return 0 end

    local mult = 1.0
    lazyLoadHUDMods()
    if _Policies and _Policies.getFoodDrainMult then
        mult = mult * _Policies.getFoodDrainMult()
    end
    if _Laws and _Laws.getFoodDrainMult then
        mult = mult * _Laws.getFoodDrainMult()
    end

    return count * 0.04 * mult / 50
end

local function sampleMetrics()
    local now = GameState.colonyRealTime or 0
    if lastMetricSample and now < lastMetricSample then
        resetMetricHistory()
    end
    if lastMetricTick == GameState.simTick then return end
    lastMetricTick = GameState.simTick
    if lastMetricSample and now - lastMetricSample < METRIC_SAMPLE_INTERVAL then
        return
    end

    metricHistory[#metricHistory + 1] = {
        time = now,
        temp = GameState.getEffectiveTemp(),
        foodEq = getFoodEquivalent(),
        water = GameState.resources.water or 0,
        fuel = GameState.resources.fuel or 0,
    }
    lastMetricSample = now

    while #metricHistory > 0 and now - metricHistory[1].time > METRIC_WINDOW do
        table.remove(metricHistory, 1)
    end
end

local function getMetricRate(field)
    if #metricHistory < 2 then return nil end
    local oldest = metricHistory[1]
    local newest = metricHistory[#metricHistory]
    local dt = newest.time - oldest.time
    if dt <= 0 then return nil end
    local delta = (oldest[field] or 0) - (newest[field] or 0)
    if delta <= 0 then return 0 end
    return delta / dt
end

local function formatDaysRemaining(amount, ratePerSecond)
    if not amount or amount <= 0 then return '0d' end
    if not ratePerSecond or ratePerSecond <= 0 then return '--' end
    return string.format('%.1fd', amount / (ratePerSecond * DAY_SECONDS))
end

local function getTempTrend()
    if #metricHistory < 2 then return '-', { 0.8, 0.8, 0.8 } end
    local newest = metricHistory[#metricHistory]
    local targetTime = newest.time - 60
    local oldest = metricHistory[1]
    for i = #metricHistory - 1, 1, -1 do
        if metricHistory[i].time <= targetTime then
            oldest = metricHistory[i]
            break
        end
    end
    local delta = newest.temp - oldest.temp
    if delta > 2 then return '^', { 1.0, 0.72, 0.32 } end
    if delta < -2 then return 'v', { 0.45, 0.8, 1.0 } end
    return '-', { 0.8, 0.8, 0.8 }
end

---------------------------------------------------------------------------
-- Resource bar (top)
---------------------------------------------------------------------------

function HUD.drawResourceBar()
    sampleMetrics()
    lazyLoadHUDMods()
    local mainFont, smallFont = getHudFonts()
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(mainFont)

    local y = 20
    local x = 200
    local res = GameState.resources
    local foodRate = getMetricRate('foodEq')
    if not foodRate or foodRate <= 0 then
        foodRate = getFoodDemandPerSecond()
    end
    local waterRate = getMetricRate('water')
    if not waterRate or waterRate <= 0 then
        waterRate = getWaterDemandPerSecond()
    end
    local fuelRate = getMetricRate('fuel')
    local foodDays = formatDaysRemaining(getFoodEquivalent(), foodRate)
    local waterDays = formatDaysRemaining(res.water or 0, waterRate)
    local fuelDays = formatDaysRemaining(res.fuel or 0, fuelRate)
    local items = {
        { 'Cores',  res.thermalCores, {1, 0.5, 0.2},   'Thermal Cores: Recovered precursor assemblies used in trade, research, and key structures. Best found in ruins, deep drilling, and expeditions.' },
        { 'Wood',   res.wood,         {0.6, 0.4, 0.2},  'Wood: Used for basic structures and fuel' },
        { 'Stone',  res.stone,        {0.5, 0.5, 0.5},  'Stone: Used for walls and foundations' },
        { 'Metal',  res.metal,        {0.4, 0.5, 0.6},  'Metal: Used for machines and advanced structures' },
        { 'Food',   res.food,         {0.3, 0.7, 0.3},  'Food remaining at current burn: ' .. foodDays },
        { 'Water',  res.water or 0,   {0.2, 0.6, 0.9},  'Water remaining at current burn: ' .. waterDays },
        { 'Fuel',   res.fuel,         {0.8, 0.6, 0.2},  'Fuel remaining at current burn: ' .. fuelDays },
    }

    local font = love.graphics.getFont()
    local rowH = font:getHeight() + 10

    -- Stronger background for panel separation from map
    love.graphics.setColor(0.03, 0.04, 0.07, 0.85)
    love.graphics.rectangle('fill', 0, y - 4, screenW, rowH, 3)
    love.graphics.setColor(0.2, 0.25, 0.35, 0.6)
    love.graphics.line(0, y - 4 + rowH, screenW, y - 4 + rowH)

    resourceHitZones = {}
    for _, item in ipairs(items) do
        local label, val, col, tip = item[1], item[2], item[3], item[4]
        local text = string.format('%s: %d', label, val)
        if label == 'Food' then
            text = string.format('%s: %d (%s)', label, val, foodDays)
        elseif label == 'Water' then
            text = string.format('%s: %d (%s)', label, val, waterDays)
        elseif label == 'Fuel' then
            text = string.format('%s: %d (%s)', label, val, fuelDays)
        end
        love.graphics.setColor(col[1], col[2], col[3], 1.0)
        love.graphics.print(text, x, y)
        local zoneW = font:getWidth(text) + 16
        resourceHitZones[#resourceHitZones + 1] = { x = x, y = y - 4, w = zoneW, h = rowH, tooltip = tip }
        x = x + zoneW + 10
    end

    -- Research status (below resource bar)
    local statusY = y + rowH - 2
    local statusFont = font
    local statusRowH = font:getHeight() + 4
    local researchShown = false
    if _Research then
        local currentId, prog = _Research.getCurrent()
        if currentId then
            local node = _Research.getNode(currentId)
            local nodeName = node and node.name or currentId
            local totalCost = node and node.cost or 1
            local pct = totalCost > 0 and (prog / totalCost * 100) or 0
            local label = truncateTextForWidth(string.format('Research: %s  %.0f%%', nodeName, pct), 250, statusFont)

            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle('fill', 0, statusY, 480, statusRowH, 2)
            love.graphics.setColor(0.5, 0.7, 0.9, 0.8)
            love.graphics.print(label, 200, statusY)

            -- Small progress bar
            local barX, barW, barH = 460, 60, 8
            love.graphics.setColor(0.12, 0.12, 0.15)
            love.graphics.rectangle('fill', barX, statusY + 6, barW, barH, 2)
            love.graphics.setColor(0.3, 0.6, 0.9)
            love.graphics.rectangle('fill', barX, statusY + 6, barW * math.min(1, pct / 100), barH, 2)
            researchShown = true
        end
    end

    local quotaShown = false
    if _Hermes and _Hermes.getPhaseName then
        local directive = _Hermes.getCurrentDirective and _Hermes.getCurrentDirective() or nil
        local directiveLabel = directive and directive.title:gsub('^HERMES Directive:%s*', '') or 'No active directive'
        local commsPct = math.floor(((_Hermes.getCommsQuality and _Hermes.getCommsQuality()) or 1.0) * 100 + 0.5)
        local hermesY = researchShown and (statusY + statusRowH) or statusY
        local hermesText = truncateTextForWidth(string.format('HERMES: %s  Comms: %d%%  %s',
            _Hermes.getPhaseName(), commsPct, directiveLabel), 450, statusFont)

        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle('fill', 0, hermesY, 660, statusRowH, 2)
        love.graphics.setColor(0.75, 0.82, 0.95, 0.85)
        love.graphics.print(hermesText, 200, hermesY)
        quotaShown = true
    end

    if _Quotas and _Quotas.getStatusSummary then
        local quotaY = statusY
        if researchShown then quotaY = quotaY + statusRowH end
        if quotaShown then quotaY = quotaY + statusRowH end

        local quotaText = truncateTextForWidth(_Quotas.getStatusSummary(), 650, statusFont)
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle('fill', 0, quotaY, 860, statusRowH, 2)
        love.graphics.setColor(0.78, 0.76, 0.66, 0.85)
        love.graphics.print(quotaText, 200, quotaY)

        if _Containment and _Containment.getStatusSummary then
            local containmentY = quotaY + statusRowH
            local containmentText = truncateTextForWidth(_Containment.getStatusSummary(), 650, statusFont)
            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.rectangle('fill', 0, containmentY, 860, statusRowH, 2)
            love.graphics.setColor(0.72, 0.84, 0.92, 0.85)
            love.graphics.print(containmentText, 200, containmentY)
        end
    end
    love.graphics.setFont(prevFont)
end

function HUD.drawResourceTooltip()
    local mx, my = love.mouse.getPosition()
    for _, zone in ipairs(resourceHitZones) do
        if mx >= zone.x and mx <= zone.x + zone.w and my >= zone.y and my <= zone.y + zone.h then
            local font = love.graphics.getFont()
            local tw = font:getWidth(zone.tooltip) + 12
            local th = font:getHeight() + 6
            local tx = math.min(mx, screenW - tw - 4)
            love.graphics.setColor(0.05, 0.06, 0.08, 0.92)
            love.graphics.rectangle('fill', tx, zone.y + zone.h + 2, tw, th, 3)
            love.graphics.setColor(0.85, 0.87, 0.9)
            love.graphics.print(zone.tooltip, tx + 6, zone.y + zone.h + 5)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Time / speed bar (clickable)
---------------------------------------------------------------------------

function HUD.drawTimeBar()
    sampleMetrics()
    local mainFont = getHudFonts()
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(mainFont)

    speedBtns = {}
    pauseBtn = nil

    local font = love.graphics.getFont()
    local rowH = font:getHeight() + 10
    local btnH = font:getHeight() + 4
    local x = screenW - 320
    local y = 20

    love.graphics.setColor(0.03, 0.04, 0.07, 0.85)
    love.graphics.rectangle('fill', x - 8, y - 4, 348, rowH, 3)

    -- Temperature
    love.graphics.setColor(0.6, 0.8, 1)
    love.graphics.print(string.format('%.0f°C', GameState.getEffectiveTemp()), x, y)

    local trend, trendColor = getTempTrend()
    love.graphics.setColor(trendColor)
    love.graphics.print(trend, x + 50, y)

    -- Day/time
    love.graphics.setColor(0.9, 0.85, 0.7)
    local hour = math.floor(GameState.hour)
    local min  = math.floor((GameState.hour % 1) * 60)
    love.graphics.print(string.format('Day %d  %02d:%02d', GameState.day, hour, min), x + 70, y)

    -- Speed buttons (clickable)
    local speedLabels = { '1x', '2x', '3x' }
    local speedX = x + 220
    local btnW = 30
    for i = 1, 3 do
        local bx = speedX + (i - 1) * (btnW + 2)
        speedBtns[i] = { x = bx, y = y - 2, w = btnW, h = btnH, speed = i }

        if not GameState.paused and i == GameState.speed then
            love.graphics.setColor(0.15, 0.55, 0.3)
            love.graphics.rectangle('fill', bx, y - 2, btnW, btnH, 3)
            love.graphics.setColor(0.3, 1, 0.5)
        else
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle('fill', bx, y - 2, btnW, btnH, 3)
            love.graphics.setColor(0.5, 0.5, 0.5)
        end
        love.graphics.print(speedLabels[i], bx + 4, y)
    end

    -- Pause button
    local px = speedX + 3 * (btnW + 2) + 4
    pauseBtn = { x = px, y = y - 2, w = 32, h = btnH }
    if GameState.paused then
        love.graphics.setColor(0.6, 0.15, 0.15)
        love.graphics.rectangle('fill', px, y - 2, 32, btnH, 3)
        love.graphics.setColor(1, 0.3, 0.3)
    else
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle('fill', px, y - 2, 32, btnH, 3)
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    love.graphics.print('||', px + 6, y)

    local pop = getPopulationStats()
    love.graphics.setColor(0.03, 0.04, 0.07, 0.75)
    love.graphics.rectangle('fill', x - 8, y + rowH - 2, 348, rowH - 4, 2)
    love.graphics.setColor(0.82, 0.86, 0.9, 0.9)
    love.graphics.print(string.format(
        'Pop %d  Healthy %d  Inj %d  Sick %d  Draft %d',
        pop.total, pop.healthy, pop.injured, pop.sick, pop.drafted
    ), x, y + rowH - 2)
    love.graphics.setFont(prevFont)
end

---------------------------------------------------------------------------
-- Critical alerts row (below resource bar)
---------------------------------------------------------------------------

function HUD.drawAlerts()
    lazyLoadHUDMods()
    local alerts = {}

    -- Fire alert
    if _Fire then
        local count = _Fire.getFireCount()
        if count > 0 then
            local fx, fy = nil, nil
            if _Fire.getFirstFirePos then
                fx, fy = _Fire.getFirstFirePos()
            end
            alerts[#alerts + 1] = {
                text = 'FIRE x' .. count, color = {1, 0.4, 0.1},
                jumpX = fx, jumpY = fy,
            }
        end
    end

    -- Raid alert (with warning countdown)
    if _Raids and _Raids.isRaidActive() then
        local raidInfo = _Raids.getActiveRaid()
        if raidInfo and raidInfo.phase == 'warning' then
            local remaining = math.max(0, raidInfo.warningTime - raidInfo.timeElapsed)
            alerts[#alerts + 1] = {
                text = string.format('RAID INCOMING %ds', math.ceil(remaining)),
                color = {1, 0.6, 0.2},
            }
        elseif raidInfo then
            local alive = raidInfo.alive or 0
            alerts[#alerts + 1] = {
                text = string.format('RAID (%d alive)', alive),
                color = {1, 0.2, 0.2},
            }
        else
            alerts[#alerts + 1] = { text = 'RAID IN PROGRESS', color = {1, 0.2, 0.2} }
        end
    end

    -- Low food warning
    if (GameState.resources.food or 0) < 20 then
        alerts[#alerts + 1] = { text = 'LOW FOOD', color = {1, 0.8, 0.2} }
    end

    -- Low water warning
    if (GameState.resources.water or 0) < 5 then
        alerts[#alerts + 1] = { text = 'LOW WATER', color = {0.2, 0.6, 0.9} }
    end

    -- Low fuel warning
    if (GameState.resources.fuel or 0) < 10 then
        alerts[#alerts + 1] = { text = 'LOW FUEL', color = {0.8, 0.6, 0.2} }
    end

    -- Hypothermia
    local hypoCount = 0
    local hypoPos = nil
    for _, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.hypothermia and col.hypothermia >= 2 then
            hypoCount = hypoCount + 1
            if not hypoPos then hypoPos = comps.pos end
        end
    end
    if hypoCount > 0 then
        alerts[#alerts + 1] = {
            text = 'HYPOTHERMIA x' .. hypoCount, color = {0.4, 0.7, 1},
            jumpX = hypoPos and hypoPos.x, jumpY = hypoPos and hypoPos.y,
        }
    end

    -- Suffocation
    local suffCount = 0
    local suffPos = nil
    for _, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' and col._suffocating and col._suffocating >= 2 then
            suffCount = suffCount + 1
            if not suffPos then suffPos = comps.pos end
        end
    end
    if suffCount > 0 then
        alerts[#alerts + 1] = {
            text = 'SUFFOCATING x' .. suffCount, color = {0.6, 0.3, 0.7},
            jumpX = suffPos and suffPos.x, jumpY = suffPos and suffPos.y,
        }
    end

    -- Idle colonists
    local idleCount = 0
    for _, comps in ECS.query('colonist') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.state == 'idle' then
            idleCount = idleCount + 1
        end
    end
    if idleCount > 0 then
        alerts[#alerts + 1] = { text = 'IDLE x' .. idleCount, color = {0.7, 0.7, 0.4} }
    end

    -- Disease
    local sickCount = 0
    local sickPos = nil
    for id, comps in ECS.query('colonist', 'disease', 'pos') do
        local d = comps.disease
        if d and d.id then
            sickCount = sickCount + 1
            if not sickPos then sickPos = comps.pos end
        end
    end
    if sickCount > 0 then
        alerts[#alerts + 1] = {
            text = 'SICK x' .. sickCount, color = {0.6, 0.9, 0.3},
            jumpX = sickPos and sickPos.x, jumpY = sickPos and sickPos.y,
        }
    end

    -- Mental breaks
    local breakCount = 0
    local breakPos = nil
    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state == 'mental_break' then
            breakCount = breakCount + 1
            if not breakPos then breakPos = comps.pos end
        end
    end
    if breakCount > 0 then
        alerts[#alerts + 1] = {
            text = 'MENTAL BREAK x' .. breakCount, color = {0.9, 0.3, 0.6},
            jumpX = breakPos and breakPos.x, jumpY = breakPos and breakPos.y,
        }
    end

    if _Containment and _Containment.getHighestRisk then
        local highestRisk = _Containment.getHighestRisk()
        if highestRisk >= 70 then
            alerts[#alerts + 1] = { text = string.format('CONTAINMENT %.0f%%', highestRisk), color = {1, 0.3, 0.2} }
        elseif _Containment.hasPendingSubjects and _Containment.hasPendingSubjects() then
            alerts[#alerts + 1] = { text = 'UNHOUSED SUBJECTS', color = {0.8, 0.7, 0.3} }
        end
    end

    -- Colony revolt
    if _Hope and _Hope.isRevoltActive() then
        alerts[#alerts + 1] = { text = 'REVOLT', color = {0.9, 0.2, 0.2} }
    end

    -- Power outage
    if _Power and _Power.getTotalSupply and _Power.getTotalDemand then
        local supply = _Power.getTotalSupply()
        local demand = _Power.getTotalDemand()
        if demand > 0 and supply < demand then
            alerts[#alerts + 1] = {
                text = string.format('POWER %dW/%dW', supply, demand),
                color = {1, 0.7, 0.2},
            }
        end
    end

    -- Colonist downed (health < 30)
    local downedCount = 0
    local downedPos = nil
    for id, comps in ECS.query('colonist', 'pos') do
        local col = comps.colonist
        if col.state ~= 'dead' and col.health < 30 then
            downedCount = downedCount + 1
            if not downedPos then downedPos = comps.pos end
        end
    end
    if downedCount > 0 then
        alerts[#alerts + 1] = {
            text = 'CRITICAL x' .. downedCount, color = {1, 0.15, 0.15},
            jumpX = downedPos and downedPos.x, jumpY = downedPos and downedPos.y,
        }
    end

    -- Starvation (food need < 10)
    local starveCount = 0
    local starvePos = nil
    for id, comps in ECS.query('colonist', 'needs', 'pos') do
        local col = comps.colonist
        local needs = comps.needs
        if col.state ~= 'dead' and needs and needs.food and needs.food < 10 then
            starveCount = starveCount + 1
            if not starvePos then starvePos = comps.pos end
        end
    end
    if starveCount > 0 then
        alerts[#alerts + 1] = {
            text = 'STARVING x' .. starveCount, color = {0.9, 0.5, 0.1},
            jumpX = starvePos and starvePos.x, jumpY = starvePos and starvePos.y,
        }
    end

    -- Hope critical (< 15)
    if _Hope and _Hope.getHope() < 15 then
        alerts[#alerts + 1] = { text = string.format('HOPE CRITICAL (%.0f)', _Hope.getHope()), color = {0.7, 0.2, 0.5} }
    end

    -- Epidemic (3+ sick colonists)
    if sickCount >= 3 then
        alerts[#alerts + 1] = { text = 'EPIDEMIC x' .. sickCount, color = {0.4, 0.8, 0.2} }
    end

    if #alerts == 0 then
        alertHitZones = {}
        return
    end

    alertHitZones = {}
    local font = love.graphics.getFont()
    local alertH = font:getHeight() + 6
    local alertY = 50
    local alertX = 8
    local t = love.timer.getTime()
    local pulse = 0.7 + 0.3 * math.sin(t * 4)

    for _, alert in ipairs(alerts) do
        local c = alert.color
        local tw = font:getWidth(alert.text) + 14
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', alertX, alertY, tw, alertH, 3, 3)
        love.graphics.setColor(c[1], c[2], c[3], pulse)
        love.graphics.rectangle('line', alertX, alertY, tw, alertH, 3, 3)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.print(alert.text, alertX + 7, alertY + 3)

        -- Store clickable zone for camera jump
        if alert.jumpX and alert.jumpY then
            alertHitZones[#alertHitZones + 1] = {
                x = alertX, y = alertY, w = tw, h = alertH,
                jumpX = alert.jumpX, jumpY = alert.jumpY,
            }
        end

        alertX = alertX + tw + 6
    end
end

---------------------------------------------------------------------------
-- Colonist bar (persistent row below alerts)
---------------------------------------------------------------------------

function HUD.drawColonistBar()
    lazyLoadHUDMods()
    colonistCards = {}
    local colonists = {}
    for id, comps in ECS.query('colonist', 'needs') do
        local col = comps.colonist
        if col.state ~= 'dead' then
            colonists[#colonists + 1] = { id = id, col = col, needs = comps.needs }
        end
    end
    if #colonists == 0 then return end

    table.sort(colonists, function(a, b) return (a.col.name or '') < (b.col.name or '') end)

    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local barY = 76
    local cardW = math.max(90, fh * 6)
    local cardH = fh * 3 + 14
    local gap = 4
    local startX = 8

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', 0, barY - 2, screenW, cardH + 4, 2)

    local overflowCount = 0
    for i, c in ipairs(colonists) do
        local cx = startX + (i - 1) * (cardW + gap)
        if cx + cardW > screenW - 50 then
            overflowCount = #colonists - i + 1
            break
        end

        colonistCards[#colonistCards + 1] = { x = cx, y = barY, w = cardW, h = cardH, id = c.id }

        -- Card background (color-coded by status)
        local isSelected = GameState.selectedEntities[c.id]
        if isSelected then
            love.graphics.setColor(0.2, 0.35, 0.5, 0.8)
        elseif c.col._mentalBreak then
            love.graphics.setColor(0.25, 0.08, 0.08, 0.85)
        elseif c.col.health < (c.col.maxHealth or 100) * 0.3 then
            love.graphics.setColor(0.25, 0.12, 0.08, 0.85)
        elseif c.col.state == 'fleeing' then
            love.graphics.setColor(0.22, 0.18, 0.05, 0.85)
        else
            love.graphics.setColor(0.12, 0.12, 0.15, 0.8)
        end
        love.graphics.rectangle('fill', cx, barY, cardW, cardH, 3)

        -- Border
        if isSelected then
            love.graphics.setColor(0.4, 0.7, 1, 0.8)
        else
            love.graphics.setColor(0.3, 0.3, 0.35, 0.6)
        end
        love.graphics.rectangle('line', cx, barY, cardW, cardH, 3)

        -- Name (truncated)
        local name = Layout.truncate(c.col.name or '???', cardW - 6)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(name, cx + 3, barY + 2)

        -- Health bar
        local hpFrac = math.max(0, c.col.health / math.max(1, c.col.maxHealth or 100))
        local hpW = cardW - 6
        local barStartY = barY + fh + 4
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle('fill', cx + 3, barStartY, hpW, 5)
        if hpFrac < 0.3 then
            love.graphics.setColor(0.9, 0.2, 0.1)
        elseif hpFrac < 0.6 then
            love.graphics.setColor(0.9, 0.7, 0.1)
        else
            love.graphics.setColor(0.2, 0.7, 0.3)
        end
        love.graphics.rectangle('fill', cx + 3, barStartY, hpW * hpFrac, 5)

        -- Mood bar
        local mood = (c.needs.morale or 50) / 100
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle('fill', cx + 3, barStartY + 7, hpW, 4)
        if mood < 0.3 then
            love.graphics.setColor(0.9, 0.2, 0.1)
        elseif mood < 0.5 then
            love.graphics.setColor(0.9, 0.6, 0.1)
        else
            love.graphics.setColor(0.2, 0.6, 0.8)
        end
        love.graphics.rectangle('fill', cx + 3, barStartY + 7, hpW * mood, 4)

        -- Status icons (top-right corner, small colored symbols)
        local iconW = font:getWidth('!') + 2
        local iconX = cx + cardW - iconW
        local iconY = barY + 2

        -- Mental break (red !)
        if c.col._mentalBreak then
            love.graphics.setColor(1, 0.2, 0.2)
            love.graphics.print('!', iconX, iconY)
            iconX = iconX - iconW
        end

        -- Disease (green +)
        local disease = ECS.get(c.id, 'disease')
        if disease and disease.id then
            love.graphics.setColor(0.4, 0.9, 0.3)
            love.graphics.print('+', iconX, iconY)
            iconX = iconX - iconW
        end

        -- Injured (orange *)
        local wounds = ECS.get(c.id, 'wounds')
        if wounds and wounds.list and #wounds.list > 0 then
            love.graphics.setColor(0.9, 0.6, 0.2)
            love.graphics.print('*', iconX, iconY)
            iconX = iconX - iconW
        end

        -- Hungry (yellow ~)
        if c.needs.food and c.needs.food < 25 then
            love.graphics.setColor(0.9, 0.8, 0.2)
            love.graphics.print('~', iconX, iconY)
            iconX = iconX - iconW
        end

        -- Drafted (cyan D)
        if c.col.drafted then
            love.graphics.setColor(0.2, 0.9, 1)
            love.graphics.print('D', iconX, iconY)
            iconX = iconX - iconW
        end

        -- Hypothermia (blue snowflake)
        if c.col.hypothermia and c.col.hypothermia >= 2 then
            love.graphics.setColor(0.4, 0.7, 1)
            love.graphics.print('#', iconX, iconY)
        end

        -- Task label (show job type when working, state otherwise)
        local taskLabel = c.col.state or 'idle'
        if c.col.task and _Jobs then
            local jtask = _Jobs.getTask(c.col.task.taskId)
            if jtask and jtask.def then
                taskLabel = jtask.def.name or jtask.type
            end
        end
        taskLabel = truncateTextForWidth(taskLabel, cardW - 6, font)
        love.graphics.setColor(0.6, 0.6, 0.5)
        love.graphics.print(taskLabel, cx + 3, barStartY + 14)
    end

    if overflowCount > 0 then
        love.graphics.setColor(0.8, 0.7, 0.4, 0.9)
        love.graphics.print('+' .. overflowCount .. ' more', screenW - 48, barY + 12)
    end
end

---------------------------------------------------------------------------
-- Colonist bar tooltip
---------------------------------------------------------------------------

function HUD.drawColonistBarTooltip(contextMenuOpen, menuStackLen)
    if contextMenuOpen or menuStackLen > 0 then return end
    lazyLoadHUDMods()
    local mx, my = love.mouse.getPosition()
    for _, card in ipairs(colonistCards) do
        if mx >= card.x and mx <= card.x + card.w and my >= card.y and my <= card.y + card.h then
            local col = ECS.get(card.id, 'colonist')
            local needs = ECS.get(card.id, 'needs')
            if not col or col.state == 'dead' then return end

            local lines = {}
            lines[#lines + 1] = col.name or '???'
            lines[#lines + 1] = string.format('HP: %.0f/%d', math.max(0, col.health), col.maxHealth or 100)
            if needs then
                lines[#lines + 1] = string.format('Food: %.0f  Rest: %.0f  Morale: %.0f',
                    needs.food or 0, needs.rest or 0, needs.morale or 0)
            end
            -- Status effects
            if col._mentalBreak then
                lines[#lines + 1] = 'MENTAL BREAK: ' .. (col._mentalBreak.type or '?')
            end
            local disease = ECS.get(card.id, 'disease')
            if disease and disease.id then
                lines[#lines + 1] = 'Sick: ' .. disease.id
            end
            if col.hypothermia and col.hypothermia >= 2 then
                local stages = {'chilled', 'cold', 'hypothermic', 'severe', 'critical'}
                lines[#lines + 1] = 'Hypothermia: ' .. (stages[col.hypothermia] or '?')
            end
            -- Task
            local taskLabel = col.state or 'idle'
            if col.task and _Jobs then
                local jtask = _Jobs.getTask(col.task.taskId)
                if jtask and jtask.def then taskLabel = jtask.def.name or jtask.type end
            end
            lines[#lines + 1] = 'Task: ' .. taskLabel

            -- Draw tooltip
            local font = love.graphics.getFont()
            local tipLineH = font:getHeight() + 2
            local maxW = 0
            for _, l in ipairs(lines) do
                local w = font:getWidth(l)
                if w > maxW then maxW = w end
            end
            local tipW = maxW + 16
            local tipH = #lines * tipLineH + 8
            local tipX = math.min(mx + 12, screenW - tipW - 4)
            local tipY = my + card.h + 4

            love.graphics.setColor(0.06, 0.06, 0.09, 0.95)
            love.graphics.rectangle('fill', tipX, tipY, tipW, tipH, 4, 4)
            love.graphics.setColor(0.3, 0.35, 0.45, 0.7)
            love.graphics.rectangle('line', tipX, tipY, tipW, tipH, 4, 4)

            local ly = tipY + 4
            for j, l in ipairs(lines) do
                if j == 1 then
                    love.graphics.setColor(1, 1, 1)
                else
                    love.graphics.setColor(0.7, 0.7, 0.7)
                end
                love.graphics.print(l, tipX + 8, ly)
                ly = ly + tipLineH
            end
            return
        end
    end
end

---------------------------------------------------------------------------
-- Selection box (drag rectangle)
---------------------------------------------------------------------------

function HUD.drawSelectionBox()
    local Input = require('src.ui.input')
    local box = Input.getSelectionBox()
    if not box then return end
    love.graphics.setColor(0, 1, 0, 0.15)
    love.graphics.rectangle('fill', box.x, box.y, box.w, box.h)
    love.graphics.setColor(0, 1, 0, 0.6)
    love.graphics.rectangle('line', box.x, box.y, box.w, box.h)
end

---------------------------------------------------------------------------
-- Toolbar (bottom-left)
---------------------------------------------------------------------------

function HUD.drawToolbar()
    local tool = GameState.selectedTool
    local label = nil

    if GameState.buildMode then
        label = 'BUILD MODE (B to toggle, RMB cancel)'
    elseif tool == 'mine' then
        label = 'MINE DESIGNATE (M to toggle, drag tiles, ESC cancel)'
    elseif tool == 'zone_stockpile' then
        label = 'STOCKPILE ZONE (Z to toggle, drag area, ESC cancel)'
    elseif tool == 'zone_dumping' then
        label = 'DUMPING ZONE (X to toggle, drag area, ESC cancel)'
    elseif tool == 'zone_restricted' then
        label = 'ALLOWED AREA (Y to toggle, drag area, ESC cancel)'
    elseif tool == 'deconstruct' then
        label = 'DECONSTRUCT (D to toggle, drag area, ESC cancel)'
    elseif tool == 'forage' then
        label = 'FORAGE DESIGNATE (F to toggle, drag tiles, ESC cancel)'
    end

    if not label then return end

    local font = love.graphics.getFont()
    local tw = font:getWidth(label) + 16
    local x, y = 8, screenH - 230
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', x, y, tw, 30, 4)
    love.graphics.setColor(0.8, 0.9, 1)
    love.graphics.print(label, x + 8, y + 8)
end

---------------------------------------------------------------------------
-- Tile hover tooltip
---------------------------------------------------------------------------

function HUD.drawTileTooltip(contextMenuOpen, menuStackLen)
    -- Don't show during build mode (build ghost tooltip exists) or menus
    if GameState.buildMode or contextMenuOpen or menuStackLen > 0 then return end
    lazyLoadHUDMods()

    local mx, my = love.mouse.getPosition()
    -- Don't show tooltip if mouse is over UI panels (top 110px or bottom 200px)
    if my < 110 or my > screenH - 200 then return end

    local Camera = require('src.render.camera')
    local tx, ty = Camera.screenToTile(mx, my)
    if not _World or not _World.inBounds(tx, ty) then return end

    local Tiles = require('src.world.tiles')
    local vd = GameState.viewDepth or 0
    local tileType = _World.getTile(tx, ty, vd)
    local tileProp = Tiles.props[tileType]
    local tileName = tileProp and tileProp.name or '???'
    local lines = {
        string.format('(%d,%d) d%d  %s', tx, ty, vd, tileName),
    }

    local temp = _World.getTemp(tx, ty, vd)

    -- Entity at tile
    local entityStr = ''
    for id, comps in ECS.query('colonist', 'pos') do
        local p = comps.pos
        if p.x == tx and p.y == ty and (p.depth or 0) == vd and comps.colonist.state ~= 'dead' then
            entityStr = '  ' .. (comps.colonist.name or '???')
            break
        end
    end
    if entityStr == '' then
        for id, comps in ECS.query('creature', 'pos') do
            local p = comps.pos
            if p.x == tx and p.y == ty and (p.depth or 0) == vd then
                entityStr = '  ' .. (comps.creature.species or '???')
                break
            end
        end
    end
    if entityStr == '' then
        for id, comps in ECS.query('artifact', 'pos') do
            local p = comps.pos
            if p.x == tx and p.y == ty and (p.depth or 0) == vd then
                entityStr = '  ' .. (comps.artifact.name or 'Artifact')
                break
            end
        end
    end
    if entityStr == '' then
        for id, comps in ECS.query('item', 'pos') do
            local p = comps.pos
            if p.x == tx and p.y == ty and (p.depth or 0) == vd then
                local item = comps.item
                local itemLabel = item.itemId or '???'
                -- Enhance with production item name
                if _Production and _Production.ITEMS and _Production.ITEMS[item.itemId] then
                    itemLabel = _Production.ITEMS[item.itemId].name
                end
                if item.amount and item.amount > 1 then
                    itemLabel = itemLabel .. ' x' .. item.amount
                end
                if item.quality and item.quality ~= 'normal' then
                    itemLabel = itemLabel .. ' (' .. item.quality .. ')'
                end
                if item.material then
                    itemLabel = item.material .. ' ' .. itemLabel
                end
                entityStr = '  ' .. itemLabel
                break
            end
        end
    end
    if entityStr == '' then
        for id, comps in ECS.query('building_ref', 'pos') do
            local p = comps.pos
            if _Building and p.x == tx and p.y == ty and (p.depth or 0) == vd then
                local def = _Building.defs[comps.building_ref.defId]
                entityStr = '  ' .. (def and def.name or comps.building_ref.defId)
                break
            end
        end
    end

    -- Zone info
    local zoneStr = ''
    if _Zones then
        local zone = _Zones.getZoneAt(tx, ty, vd)
        if zone then
            local zt = _Zones.TYPES[zone.type]
            zoneStr = '  [' .. (zt and zt.name or zone.type) .. ']'
        end
    end

    local water = _World.getWater and _World.getWater(tx, ty, vd) or 0
    local gasLevel, gasType = 0, nil
    if _TileGas and _TileGas.getGasAt then
        gasLevel, gasType = _TileGas.getGasAt(tx, ty, vd)
    end
    local gasLabel = 'clean'
    if gasType == 0 then gasLabel = 'CO2'
    elseif gasType == 1 then gasLabel = 'toxic'
    elseif gasType == 2 then gasLabel = 'smoke'
    elseif gasType == 3 then gasLabel = 'spore'
    end

    local o2, co2 = 100, 0
    if _Atmosphere then
        if _Atmosphere.getTileO2 then o2 = _Atmosphere.getTileO2(tx, ty, vd) end
        if _Atmosphere.getTileCO2 then co2 = _Atmosphere.getTileCO2(tx, ty, vd) end
    end

    local statLine = string.format('Temp %.0fC  Water %d/7  Gas %s %d/7', temp or 0, water or 0, gasLabel, gasLevel or 0)
    lines[#lines + 1] = statLine

    local roomId = _World.getRoom(tx, ty, vd) or 0
    if roomId > 0 then
        if _Rooms and _Rooms.getRoomInfo then
            local info = _Rooms.getRoomInfo(roomId)
            if info then
                lines[#lines + 1] = string.format(
                    'Room %s  Q %.1f  O2 %d%%  CO2 %d%%',
                    info.typeName or 'Room',
                    info.quality or 0,
                    math.floor(o2 + 0.5),
                    math.floor(co2 + 0.5)
                )
            end
        end
    else
        lines[#lines + 1] = string.format('Outdoors  O2 %d%%  CO2 %d%%', math.floor(o2 + 0.5), math.floor(co2 + 0.5))
    end

    if entityStr ~= '' then
        lines[#lines + 1] = entityStr:sub(3)
    end
    if zoneStr ~= '' then
        lines[#lines + 1] = zoneStr:sub(3)
    end

    if _World.getVerticalTargets and Tiles.connectsVertical(tileType) then
        local upDepth, downDepth = _World.getVerticalTargets(tx, ty, vd)
        local parts = {}
        if upDepth then parts[#parts + 1] = 'up ' .. upDepth end
        if downDepth then parts[#parts + 1] = 'down ' .. downDepth end
        if #parts > 0 then
            lines[#lines + 1] = 'Vertical ' .. table.concat(parts, '  ')
        end
    end

    local font = love.graphics.getFont()
    local tw = 0
    for _, line in ipairs(lines) do
        tw = math.max(tw, font:getWidth(line))
    end
    local boxH = #lines * font:getHeight() + 6

    -- Position tooltip near cursor
    local tipX = mx + 16
    local tipY = my - 24
    if tipX + tw + 12 > screenW then tipX = mx - tw - 20 end
    if tipY < 0 then tipY = my + 16 end

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', tipX - 4, tipY - 2, tw + 8, boxH, 3, 3)
    love.graphics.setColor(0.85, 0.85, 0.8)
    for i, line in ipairs(lines) do
        love.graphics.print(line, tipX, tipY + (i - 1) * font:getHeight())
    end
end

return HUD
