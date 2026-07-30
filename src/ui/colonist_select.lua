-- colonist_select.lua — Pre-game colonist drafting screen
-- Generates a pool of candidates; player picks their starting crew.

local Adlib      = require('src.util.adlib')
local Layout = require('src.ui.ui_layout')
local Difficulty = require('src.ui.difficulty')
local GameState  = require('src.game_state')

local ColonistSelect = {}

---------------------------------------------------------------------------
-- Skill generation (mirrors colonist.lua's randomSkills)
---------------------------------------------------------------------------

local SKILLS = { 'mining', 'building', 'cooking', 'hunting', 'research', 'medical' }

local SKILL_LABELS = {
    mining = 'MIN', building = 'BLD', cooking = 'COK',
    hunting = 'HNT', research = 'RES', medical = 'MED',
}

local SKILL_COLORS = {
    mining   = {0.85, 0.65, 0.3},
    building = {0.45, 0.7, 0.9},
    cooking  = {0.9, 0.75, 0.35},
    hunting  = {0.75, 0.35, 0.35},
    research = {0.45, 0.8, 0.55},
    medical  = {0.9, 0.5, 0.55},
}

local function generateSkills(traits)
    local skills = {}
    for _, s in ipairs(SKILLS) do
        skills[s] = math.random(1, 8)
    end
    local best = SKILLS[math.random(#SKILLS)]
    skills[best] = math.max(skills[best], math.random(6, 10))
    if traits then
        for _, t in ipairs(traits) do
            if t.id == 'eagle_eye' then skills.hunting = math.min(10, skills.hunting + 2)
            elseif t.id == 'green_thumb' then skills.cooking = math.min(10, skills.cooking + 2)
            elseif t.id == 'former_doc' then skills.medical = math.min(10, skills.medical + 3)
            elseif t.id == 'tinkerer' then skills.building = math.min(10, skills.building + 2)
            elseif t.id == 'ex_soldier' then skills.hunting = math.min(10, skills.hunting + 2)
            end
        end
    end
    return skills
end

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------

local CARD_W    = 280
local CARD_H    = 300
local CARD_PAD  = 16
local HEADER_H  = 65
local FOOTER_H  = 65

-- State
local candidates    = {}
local selectedSet   = {}
local selectedCount = 0
local maxSelect     = 3
local poolSize      = 8

-- Fonts
local titleFont, headerFont, bodyFont, smallFont, tinyFont

-- Tooltip
local tooltipTrait = nil

---------------------------------------------------------------------------
-- Trait category lookup
---------------------------------------------------------------------------

local function getTraitCategory(trait)
    for _, t in ipairs(Adlib.TRAITS.positive) do
        if t.id == trait.id then return 'positive' end
    end
    for _, t in ipairs(Adlib.TRAITS.negative) do
        if t.id == trait.id then return 'negative' end
    end
    return 'neutral'
end

local TRAIT_BG = {
    positive = {0.15, 0.35, 0.2, 0.9},
    negative = {0.4, 0.15, 0.15, 0.9},
    neutral  = {0.2, 0.2, 0.35, 0.9},
}

local TRAIT_BORDER = {
    positive = {0.3, 0.6, 0.35},
    negative = {0.6, 0.3, 0.3},
    neutral  = {0.4, 0.4, 0.6},
}

-- Modifier display names and whether lower values are beneficial
local MODIFIER_DEFS = {
    { key = 'workSpeed',  label = 'Work Speed',  invertGood = false },
    { key = 'coldResist', label = 'Cold Resist',  invertGood = false },
    { key = 'foodMod',    label = 'Food Need',    invertGood = true },
    { key = 'moraleMod',  label = 'Morale',       invertGood = false },
    { key = 'restMod',    label = 'Rest Need',    invertGood = true },
    { key = 'speedMod',   label = 'Move Speed',   invertGood = false },
    { key = 'combatMod',  label = 'Combat',       invertGood = false },
    { key = 'craftMod',   label = 'Crafting',     invertGood = false },
    { key = 'huntMod',    label = 'Hunting',      invertGood = false },
    { key = 'farmMod',    label = 'Farming',      invertGood = false },
    { key = 'socialMod',  label = 'Social',       invertGood = false },
    { key = 'fireMod',    label = 'Fire Risk',    invertGood = true },
}

---------------------------------------------------------------------------
-- Init — generate candidate pool
---------------------------------------------------------------------------

function ColonistSelect.init()
    titleFont  = love.graphics.newFont(24)
    headerFont = love.graphics.newFont(14)
    bodyFont   = love.graphics.newFont(11)
    smallFont  = love.graphics.newFont(10)
    tinyFont   = love.graphics.newFont(9)

    local scenDef = Difficulty.SCENARIOS[GameState.scenario or 'crashlanded']
    maxSelect = scenDef and scenDef.colonists or 3
    poolSize  = maxSelect + 1   -- one extra to pick from per roll

    candidates = {}
    selectedSet = {}
    selectedCount = 0
    tooltipTrait = nil

    local usedBackstories = {}  -- prevent duplicate backstory text
    for i = 1, poolSize do
        local identity
        for _ = 1, 10 do
            identity = Adlib.generateColonistIdentity()
            if not usedBackstories[identity.backstory] then break end
        end
        usedBackstories[identity.backstory] = true

        local skills = generateSkills(identity.traits)
        -- Apply scenario skill modifiers so player sees final values
        if scenDef then
            if scenDef.skillBoost then
                for _, sk in ipairs(SKILLS) do
                    skills[sk] = math.min(20, skills[sk] + scenDef.skillBoost)
                end
            end
            if scenDef.capSkills then
                for _, sk in ipairs(SKILLS) do
                    skills[sk] = math.min(scenDef.capSkills, skills[sk])
                end
            end
        end
        -- Generate passions
        local passions = {}
        local sok, SkillsMod = pcall(require, 'src.colonist.skills')
        if sok and SkillsMod.generatePassions then
            local tempCol = { passions = passions }
            SkillsMod.generatePassions(tempCol)
            passions = tempCol.passions
        end
        candidates[i] = {
            name         = identity.name,
            gender       = identity.gender,
            backstory    = identity.backstory,
            disabledWork = identity.disabledWork,
            traits       = identity.traits,
            skills       = skills,
            passions     = passions,
            age          = math.random(20, 55),
        }
    end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function getCardPositions()
    local sw, sh = love.graphics.getDimensions()
    local n = #candidates
    local cols = math.min(5, n)
    local totalW = cols * CARD_W + (cols - 1) * CARD_PAD
    while totalW > sw - 40 and cols > 2 do
        cols = cols - 1
        totalW = cols * CARD_W + (cols - 1) * CARD_PAD
    end
    local rows = math.ceil(n / cols)
    local contentH = rows * CARD_H + (rows - 1) * CARD_PAD
    local baseX = math.floor((sw - totalW) / 2)
    local baseY = HEADER_H + math.floor((sh - HEADER_H - FOOTER_H - contentH) / 2)
    baseY = math.max(HEADER_H, baseY)

    local positions = {}
    for i = 1, n do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        positions[i] = {
            x = baseX + col * (CARD_W + CARD_PAD),
            y = baseY + row * (CARD_H + CARD_PAD),
        }
    end
    return positions, sw, sh
end

---------------------------------------------------------------------------
-- Draw a single candidate card
---------------------------------------------------------------------------

local function drawCard(cand, cx, cy, isSelected, isHovered)
    -- Background
    if isSelected then
        love.graphics.setColor(0.12, 0.22, 0.35, 0.95)
    elseif isHovered then
        love.graphics.setColor(0.1, 0.14, 0.22, 0.95)
    else
        love.graphics.setColor(0.07, 0.1, 0.16, 0.9)
    end
    love.graphics.rectangle('fill', cx, cy, CARD_W, CARD_H, 6)

    -- Border
    if isSelected then
        love.graphics.setColor(0.3, 0.6, 1.0)
    elseif isHovered then
        love.graphics.setColor(0.3, 0.4, 0.55)
    else
        love.graphics.setColor(0.2, 0.25, 0.35)
    end
    love.graphics.rectangle('line', cx, cy, CARD_W, CARD_H, 6)

    local pad = 8
    local y = cy + pad

    -- Name + gender
    love.graphics.setFont(headerFont)
    love.graphics.setColor(1, 1, 1)
    local gTag = ''
    if cand.gender then
        gTag = cand.gender == 'male' and ' (M)' or (cand.gender == 'female' and ' (F)' or ' (NB)')
    end
    love.graphics.printf(cand.name .. gTag, cx + pad, y, CARD_W - pad * 2, 'left')
    y = y + 20

    -- Backstory
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.65, 0.7, 0.8)
    local backstory = cand.backstory
    if #backstory > 120 then
        backstory = Layout.truncate(backstory, (CARD_W - pad * 2) * 3)
    end
    love.graphics.printf(backstory, cx + pad, y, CARD_W - pad * 2, 'left')
    -- Measure actual wrapped height so longer backstories don't overlap skills
    local _, wrappedLines = smallFont:getWrap(backstory, CARD_W - pad * 2)
    y = y + #wrappedLines * smallFont:getHeight() + 6

    -- Backstory work locks (if any)
    if cand.disabledWork and #cand.disabledWork > 0 then
        love.graphics.setColor(0.7, 0.3, 0.3)
        local lockStr = 'Cannot: ' .. table.concat(cand.disabledWork, ', ')
        love.graphics.print(lockStr, cx + pad, y - 2)
        y = y + 12
    end

    -- Skill bars
    local barW = CARD_W - pad * 2 - 34
    local barH = 8
    local barGap = 14
    for _, sk in ipairs(SKILLS) do
        local val = cand.skills[sk] or 0
        local label = SKILL_LABELS[sk]
        local color = SKILL_COLORS[sk]

        love.graphics.setColor(0.45, 0.5, 0.6)
        love.graphics.setFont(tinyFont)
        love.graphics.print(label, cx + pad, y - 1)

        local barX = cx + pad + 30
        love.graphics.setColor(0.12, 0.15, 0.22)
        love.graphics.rectangle('fill', barX, y, barW, barH, 2)

        local fillFrac = math.min(1, val / 10)
        love.graphics.setColor(color[1], color[2], color[3], 0.8)
        love.graphics.rectangle('fill', barX, y, math.floor(barW * fillFrac), barH, 2)

        love.graphics.setColor(0.65, 0.7, 0.8)
        love.graphics.print(tostring(val), barX + barW + 3, y - 1)

        -- Passion indicator
        local passion = cand.passions and cand.passions[sk] or 0
        if passion >= 2 then
            love.graphics.setColor(0.95, 0.80, 0.20)
            love.graphics.print('**', barX + barW + 16, y - 1)
        elseif passion >= 1 then
            love.graphics.setColor(0.70, 0.70, 0.35)
            love.graphics.print('*', barX + barW + 18, y - 1)
        end

        y = y + barGap
    end

    y = y + 4

    -- Trait badges
    local traitX = cx + pad
    local mx, my = love.mouse.getPosition()
    for _, trait in ipairs(cand.traits) do
        local cat = getTraitCategory(trait)
        local tw = tinyFont:getWidth(trait.name) + 10
        local th = 16

        -- Wrap to next line if badge doesn't fit
        if traitX + tw > cx + CARD_W - pad then
            traitX = cx + pad
            y = y + th + 3
        end

        love.graphics.setColor(unpack(TRAIT_BG[cat]))
        love.graphics.rectangle('fill', traitX, y, tw, th, 3)
        love.graphics.setColor(unpack(TRAIT_BORDER[cat]))
        love.graphics.rectangle('line', traitX, y, tw, th, 3)

        love.graphics.setColor(0.85, 0.9, 0.95)
        love.graphics.setFont(tinyFont)
        love.graphics.print(trait.name, traitX + 5, y + 2)

        -- Track hover for tooltip
        if pointInRect(mx, my, traitX, y, tw, th) then
            tooltipTrait = { trait = trait, x = mx, y = my, category = cat }
        end

        traitX = traitX + tw + 4
    end

    -- Selection indicator
    if isSelected then
        love.graphics.setColor(0.3, 0.7, 1.0, 0.9)
        love.graphics.setFont(smallFont)
        love.graphics.printf('SELECTED', cx, cy + CARD_H - 20, CARD_W, 'center')
    end
end

---------------------------------------------------------------------------
-- Draw trait tooltip
---------------------------------------------------------------------------

local function drawTooltip(sw, sh)
    if not tooltipTrait then return end
    local t = tooltipTrait.trait
    local cat = tooltipTrait.category

    -- Word-wrap description
    local descLines = {}
    if t.desc and #t.desc > 0 then
        local words = {}
        for word in t.desc:gmatch('%S+') do words[#words + 1] = word end
        local line = ''
        for _, word in ipairs(words) do
            local test = line == '' and word or (line .. ' ' .. word)
            if smallFont:getWidth(test) > 220 then
                descLines[#descLines + 1] = line
                line = word
            else
                line = test
            end
        end
        if line ~= '' then descLines[#descLines + 1] = line end
    end

    -- Collect stat modifiers
    local mods = {}
    for _, def in ipairs(MODIFIER_DEFS) do
        local val = t[def.key]
        if val and val ~= 0 then
            mods[#mods + 1] = { label = def.label, value = val, invertGood = def.invertGood }
        end
    end

    local lineH = smallFont:getHeight() + 2
    local ttW = 240
    local ttH = 8 + headerFont:getHeight() + 4
        + (#descLines * lineH)
        + (#mods > 0 and (6 + #mods * lineH) or 0)
        + 8

    local ttX = tooltipTrait.x + 12
    local ttY = tooltipTrait.y - 8
    if ttX + ttW > sw then ttX = tooltipTrait.x - ttW - 4 end
    if ttY + ttH > sh then ttY = sh - ttH - 4 end
    if ttY < 0 then ttY = 4 end

    -- Background
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle('fill', ttX, ttY, ttW, ttH, 4)
    love.graphics.setColor(unpack(TRAIT_BORDER[cat]))
    love.graphics.rectangle('line', ttX, ttY, ttW, ttH, 4)

    local ty = ttY + 8

    -- Trait name
    love.graphics.setFont(headerFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(t.name, ttX + 8, ty)
    ty = ty + headerFont:getHeight() + 4

    -- Description
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.6, 0.65, 0.75)
    for _, dline in ipairs(descLines) do
        love.graphics.print(dline, ttX + 8, ty)
        ty = ty + lineH
    end

    -- Stat modifiers
    if #mods > 0 then
        ty = ty + 6
        for _, m in ipairs(mods) do
            local sign = m.value > 0 and '+' or ''
            local text = string.format('%s: %s%.0f%%', m.label, sign, m.value * 100)
            local isGood = m.value > 0
            if m.invertGood then isGood = m.value < 0 end
            if isGood then
                love.graphics.setColor(0.4, 0.8, 0.5)
            else
                love.graphics.setColor(0.9, 0.4, 0.4)
            end
            love.graphics.print(text, ttX + 8, ty)
            ty = ty + lineH
        end
    end
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function ColonistSelect.draw()
    local positions, sw, sh = getCardPositions()
    tooltipTrait = nil

    -- Background
    love.graphics.clear(0.04, 0.06, 0.1)
    love.graphics.setColor(0.06, 0.08, 0.14, 0.5)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.7, 0.85, 1.0)
    local title = 'CREW SELECTION'
    local tw = titleFont:getWidth(title)
    love.graphics.print(title, math.floor((sw - tw) / 2), 10)

    -- Subtitle
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.4, 0.5, 0.6)
    local sub = string.format('Choose %d crew members for Erebus deployment  (%d / %d selected)',
        maxSelect, selectedCount, maxSelect)
    local stw = smallFont:getWidth(sub)
    love.graphics.print(sub, math.floor((sw - stw) / 2), 40)

    -- Cards
    local mx, my = love.mouse.getPosition()
    for i, cand in ipairs(candidates) do
        local pos = positions[i]
        local isSelected = selectedSet[i] == true
        local isHovered = pointInRect(mx, my, pos.x, pos.y, CARD_W, CARD_H)
        drawCard(cand, pos.x, pos.y, isSelected, isHovered)
    end

    -- Footer: Deploy button (center)
    local btnW, btnH = 240, 44
    local btnX = math.floor((sw - btnW) / 2)
    local btnY = sh - FOOTER_H + 4
    local canDeploy = (selectedCount == maxSelect)
    local btnHov = canDeploy and pointInRect(mx, my, btnX, btnY, btnW, btnH)

    if canDeploy then
        if btnHov then
            love.graphics.setColor(0.2, 0.4, 0.7, 0.95)
        else
            love.graphics.setColor(0.12, 0.25, 0.5, 0.9)
        end
    else
        love.graphics.setColor(0.08, 0.1, 0.15, 0.6)
    end
    love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 6)
    if canDeploy then
        love.graphics.setColor(0.4, 0.6, 0.9)
    else
        love.graphics.setColor(0.2, 0.25, 0.3)
    end
    love.graphics.rectangle('line', btnX, btnY, btnW, btnH, 6)

    love.graphics.setFont(headerFont)
    if canDeploy then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0.35, 0.4, 0.5)
    end
    local deployText = 'DEPLOY CREW'
    love.graphics.print(deployText,
        btnX + math.floor((btnW - headerFont:getWidth(deployText)) / 2),
        btnY + math.floor((btnH - headerFont:getHeight()) / 2))

    -- Reroll button (right of deploy)
    local reW, reH = 100, 30
    local reX = btnX + btnW + 16
    local reY = btnY + 7
    local reHov = pointInRect(mx, my, reX, reY, reW, reH)
    if reHov then
        love.graphics.setColor(0.22, 0.26, 0.35, 0.9)
    else
        love.graphics.setColor(0.12, 0.15, 0.22, 0.9)
    end
    love.graphics.rectangle('fill', reX, reY, reW, reH, 4)
    love.graphics.setColor(0.35, 0.4, 0.55)
    love.graphics.rectangle('line', reX, reY, reW, reH, 4)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.6, 0.65, 0.75)
    local reText = 'REROLL'
    love.graphics.print(reText,
        reX + math.floor((reW - smallFont:getWidth(reText)) / 2),
        reY + math.floor((reH - smallFont:getHeight()) / 2))

    -- Back button (left of deploy)
    local backW, backH = 80, 30
    local backX = btnX - backW - 16
    local backY = btnY + 7
    local backHov = pointInRect(mx, my, backX, backY, backW, backH)
    if backHov then
        love.graphics.setColor(0.22, 0.26, 0.35, 0.9)
    else
        love.graphics.setColor(0.12, 0.15, 0.22, 0.9)
    end
    love.graphics.rectangle('fill', backX, backY, backW, backH, 4)
    love.graphics.setColor(0.35, 0.4, 0.55)
    love.graphics.rectangle('line', backX, backY, backW, backH, 4)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.6, 0.65, 0.75)
    local backText = 'BACK'
    love.graphics.print(backText,
        backX + math.floor((backW - smallFont:getWidth(backText)) / 2),
        backY + math.floor((backH - smallFont:getHeight()) / 2))

    -- Tooltip (drawn last, on top of everything)
    drawTooltip(sw, sh)

    -- Keyboard hint
    love.graphics.setFont(tinyFont)
    love.graphics.setColor(0.3, 0.35, 0.45)
    local hint = 'Click to select  |  ENTER to deploy  |  ESC to go back'
    love.graphics.print(hint, math.floor((sw - tinyFont:getWidth(hint)) / 2), sh - 14)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

function ColonistSelect.mousepressed(x, y, button)
    if button ~= 1 then return end
    local positions, sw, sh = getCardPositions()

    -- Card clicks
    for i = 1, #candidates do
        local pos = positions[i]
        if pointInRect(x, y, pos.x, pos.y, CARD_W, CARD_H) then
            if selectedSet[i] then
                selectedSet[i] = nil
                selectedCount = selectedCount - 1
            elseif selectedCount < maxSelect then
                selectedSet[i] = true
                selectedCount = selectedCount + 1
            end
            return
        end
    end

    -- Deploy button
    local btnW, btnH = 240, 44
    local btnX = math.floor((sw - btnW) / 2)
    local btnY = sh - FOOTER_H + 4
    if selectedCount == maxSelect and pointInRect(x, y, btnX, btnY, btnW, btnH) then
        ColonistSelect.deploy()
        return
    end

    -- Reroll button
    local reW, reH = 100, 30
    local reX = btnX + btnW + 16
    local reY = btnY + 7
    if pointInRect(x, y, reX, reY, reW, reH) then
        ColonistSelect.init()
        return
    end

    -- Back button
    local backW, backH = 80, 30
    local backX = btnX - backW - 16
    local backY = btnY + 7
    if pointInRect(x, y, backX, backY, backW, backH) then
        GameState.phase = 'requisition_unlocks'
        return
    end
end

function ColonistSelect.keypressed(key)
    if key == 'return' or key == 'kpenter' then
        if selectedCount == maxSelect then
            ColonistSelect.deploy()
        end
    elseif key == 'escape' then
        GameState.phase = 'requisition_unlocks'
    end
end

---------------------------------------------------------------------------
-- Deploy — store selected crew and transition to game start
---------------------------------------------------------------------------

function ColonistSelect.deploy()
    local drafted = {}
    for i, cand in ipairs(candidates) do
        if selectedSet[i] then
            drafted[#drafted + 1] = {
                name         = cand.name,
                gender       = cand.gender,
                backstory    = cand.backstory,
                disabledWork = cand.disabledWork,
                traits       = cand.traits,
                skills       = cand.skills,
                passions     = cand.passions,
                age          = cand.age,
            }
        end
    end
    GameState.draftedColonists = drafted

    -- Advance to per-run requisition picks before world map
    local rok, ReqPanel = pcall(require, 'src.ui.requisition_panel')
    if rok and ReqPanel.init then
        ReqPanel.init('picks')
    end
    GameState.phase = 'requisition_picks'
end

return ColonistSelect
