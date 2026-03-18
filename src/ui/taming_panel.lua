-- taming_panel.lua — Tamed animal management panel
-- Toggle with Y key. Shows all tamed creatures with role/health/bond/hunger.

local GameState = require('src.game_state')

local ok_ecs, ECS = pcall(require, 'src.ecs.ecs')
local ok_taming, Taming = pcall(require, 'src.creatures.taming')
local ok_species, SpeciesDefs = pcall(require, 'src.creatures.species_defs')

local TamingPanel = {}

local visible = false
local scrollY = 0
local hitZones = {}  -- clickable rects: { x, y, w, h, action, id }
local confirmSlaughter = nil  -- entityId awaiting confirmation

local ROLES = { 'guard', 'hauler', 'livestock', 'eldritch_livestock' }
local ROLE_LABELS = {
    guard = 'Guard', hauler = 'Hauler',
    livestock = 'Livestock', eldritch_livestock = 'Eldritch',
}

local function nextRole(current)
    for i, r in ipairs(ROLES) do
        if r == current then return ROLES[(i % #ROLES) + 1] end
    end
    return ROLES[1]
end

local function speciesDisplayName(species)
    if ok_species and SpeciesDefs and SpeciesDefs[species] then
        return SpeciesDefs[species].name or species
    end
    return species:gsub('_', ' '):gsub('^%l', string.upper)
end

function TamingPanel.toggle()
    visible = not visible
    scrollY = 0
    hitZones = {}
    confirmSlaughter = nil
end

function TamingPanel.isVisible() return visible end

function TamingPanel.draw()
    if not visible then return end
    if not ok_taming then return end

    local sw, sh = love.graphics.getDimensions()
    hitZones = {}

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header bar
    love.graphics.setColor(0.1, 0.12, 0.16)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(0.25, 0.35, 0.45)
    love.graphics.line(0, 50, sw, 50)

    local count = Taming.getTamedCount and Taming.getTamedCount() or 0
    love.graphics.setColor(0.9, 0.85, 0.6)
    love.graphics.print(string.format('TAMED ANIMALS (%d)', count), 20, 16)
    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('Y / ESC to close', sw - 140, 16)

    -- Get all tamed
    local tamed = Taming.getAllTamed and Taming.getAllTamed() or {}

    -- Empty state
    if #tamed == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print('No tamed animals. Assign colonists to taming jobs.', sw / 2 - 180, sh / 2 - 10)
        return
    end

    -- Sort by species then id
    table.sort(tamed, function(a, b)
        if a.species == b.species then return a.id < b.id end
        return a.species < b.species
    end)

    -- Card layout
    local cardH = 64
    local cardW = math.min(sw - 40, 700)
    local startX = math.floor((sw - cardW) / 2)
    local cy = 60 - scrollY

    for _, animal in ipairs(tamed) do
        if cy + cardH > 50 and cy < sh - 10 then
            -- Card background
            love.graphics.setColor(0.07, 0.07, 0.09)
            love.graphics.rectangle('fill', startX, cy, cardW, cardH - 2, 3)
            love.graphics.setColor(0.18, 0.18, 0.22)
            love.graphics.rectangle('line', startX, cy, cardW, cardH - 2, 3)

            local col1 = startX + 8
            local col2 = startX + 200
            local col3 = startX + 420

            -- Species name + individual name
            love.graphics.setColor(0.9, 0.85, 0.6)
            love.graphics.print(speciesDisplayName(animal.species), col1, cy + 4)
            if animal.name then
                love.graphics.setColor(0.6, 0.6, 0.6)
                love.graphics.print(animal.name, col1, cy + 20)
            end

            -- Health bar
            local hp = (animal.health or 0)
            local maxHP = (animal.maxHP or 100)
            local hpFrac = maxHP > 0 and (hp / maxHP) or 0
            love.graphics.setColor(0.15, 0.15, 0.15)
            love.graphics.rectangle('fill', col1, cy + 38, 120, 8, 2)
            local hr, hg = 1, 1
            if hpFrac < 0.5 then hg = hpFrac * 2 end
            if hpFrac > 0.5 then hr = (1 - hpFrac) * 2 end
            love.graphics.setColor(hr, hg, 0.1)
            love.graphics.rectangle('fill', col1, cy + 38, 120 * hpFrac, 8, 2)
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print(string.format('HP %d/%d', hp, maxHP), col1 + 125, cy + 34)

            -- Bond bar
            local bond = animal.bond or 1
            local bondFrac = bond / 10
            love.graphics.setColor(0.15, 0.15, 0.15)
            love.graphics.rectangle('fill', col2, cy + 6, 100, 8, 2)
            love.graphics.setColor(0.3, 0.6, 0.9)
            love.graphics.rectangle('fill', col2, cy + 6, 100 * bondFrac, 8, 2)
            love.graphics.setColor(0.6, 0.7, 0.8)
            love.graphics.print(string.format('Bond %d/10', bond), col2 + 105, cy + 2)

            -- Hunger indicator
            local hunger = animal.hunger or 100
            local hungerColor
            if hunger > 70 then hungerColor = {0.4, 0.8, 0.4}
            elseif hunger > 30 then hungerColor = {0.8, 0.7, 0.3}
            else hungerColor = {0.9, 0.3, 0.3} end
            love.graphics.setColor(hungerColor[1], hungerColor[2], hungerColor[3])
            love.graphics.print(string.format('Hunger: %d%%', math.floor(hunger)), col2, cy + 22)

            -- Trained abilities
            local trainedList = {}
            if animal.trained then
                for ab in pairs(animal.trained) do
                    trainedList[#trainedList + 1] = ab
                end
            end
            if #trainedList > 0 then
                love.graphics.setColor(0.5, 0.7, 0.5)
                love.graphics.print(table.concat(trainedList, ', '), col2, cy + 38)
            end

            -- Role button (clickable to cycle)
            local roleLbl = ROLE_LABELS[animal.role] or animal.role or '?'
            local roleBtnX = col3
            local roleBtnW = 90
            love.graphics.setColor(0.12, 0.18, 0.25)
            love.graphics.rectangle('fill', roleBtnX, cy + 6, roleBtnW, 22, 3)
            love.graphics.setColor(0.3, 0.5, 0.7)
            love.graphics.rectangle('line', roleBtnX, cy + 6, roleBtnW, 22, 3)
            love.graphics.setColor(0.8, 0.85, 0.9)
            love.graphics.print(roleLbl, roleBtnX + 6, cy + 9)
            hitZones[#hitZones + 1] = {
                x = roleBtnX, y = cy + 6, w = roleBtnW, h = 22,
                action = 'role', id = animal.id, currentRole = animal.role,
            }

            -- Slaughter button
            local slBtnX = col3
            local slBtnW = 90
            local isConfirm = (confirmSlaughter == animal.id)
            if isConfirm then
                love.graphics.setColor(0.5, 0.08, 0.08)
            else
                love.graphics.setColor(0.25, 0.08, 0.08)
            end
            love.graphics.rectangle('fill', slBtnX, cy + 34, slBtnW, 22, 3)
            love.graphics.setColor(0.8, 0.3, 0.3)
            love.graphics.rectangle('line', slBtnX, cy + 34, slBtnW, 22, 3)
            love.graphics.setColor(0.9, 0.4, 0.4)
            love.graphics.print(isConfirm and 'Confirm?' or 'Slaughter', slBtnX + 6, cy + 37)
            hitZones[#hitZones + 1] = {
                x = slBtnX, y = cy + 34, w = slBtnW, h = 22,
                action = 'slaughter', id = animal.id,
            }
        end
        cy = cy + cardH
    end
end

function TamingPanel.keypressed(key)
    if not visible then return false end
    if key == 'y' or key == 'escape' then
        visible = false
        confirmSlaughter = nil
        return true
    end
    return true  -- consume all keys while open
end

function TamingPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return true end

    for _, zone in ipairs(hitZones) do
        if x >= zone.x and x <= zone.x + zone.w
        and y >= zone.y and y <= zone.y + zone.h then
            if zone.action == 'role' then
                -- Cycle role via ECS
                if ok_ecs then
                    local tamed = ECS.get(zone.id, 'tamed')
                    if tamed then
                        tamed.role = nextRole(zone.currentRole)
                    end
                end
                confirmSlaughter = nil
                return true
            elseif zone.action == 'slaughter' then
                if confirmSlaughter == zone.id then
                    -- Confirmed: slaughter
                    if ok_taming then Taming.slaughter(zone.id) end
                    confirmSlaughter = nil
                else
                    confirmSlaughter = zone.id
                end
                return true
            end
        end
    end

    -- Click outside buttons clears confirmation
    confirmSlaughter = nil
    return true
end

function TamingPanel.wheelmoved(dx, dy)
    if not visible then return false end
    scrollY = math.max(0, scrollY - dy * 30)
    return true
end

return TamingPanel
