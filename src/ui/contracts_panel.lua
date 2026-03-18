-- contracts_panel.lua — Shipping contracts and bounty tracking panel
-- Shows available contracts at current station + active contracts.
-- Toggle with K key in space.

local GameState = require('src.game_state')

local ContractsPanel = {}

local visible = false
local hitZones = {}
local scrollY = 0

function ContractsPanel.toggle()
    visible = not visible
    hitZones = {}
    scrollY = 0
end

function ContractsPanel.isVisible()
    return visible
end

function ContractsPanel.draw()
    if not visible then return end
    if GameState.activeMap ~= 'space' then return end

    local sw, sh = love.graphics.getDimensions()
    hitZones = {}

    -- Full-screen backdrop
    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    -- Header
    love.graphics.setColor(0.08, 0.1, 0.14)
    love.graphics.rectangle('fill', 0, 0, sw, 50)
    love.graphics.setColor(0.2, 0.3, 0.45)
    love.graphics.line(0, 50, sw, 50)

    love.graphics.setColor(0.9, 0.85, 0.6)
    love.graphics.print('CONTRACTS & BOUNTIES', 20, 16)
    love.graphics.setColor(0.45, 0.45, 0.45)
    love.graphics.print('K / ESC to close', sw - 140, 16)

    -- Credits display
    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.print('Credits: ' .. (GameState.credits or 0), sw - 200, 60)

    local y = 80

    -- Active contracts
    love.graphics.setColor(0.7, 0.85, 1.0)
    love.graphics.print('ACTIVE CONTRACTS', 20, y)
    y = y + 24

    local seOk, SpaceEconomy = pcall(require, 'src.space.space_economy')
    if seOk then
        local active = SpaceEconomy.getActiveContracts()
        if #active == 0 then
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.print('No active contracts.', 30, y)
            y = y + 20
        else
            for i, contract in ipairs(active) do
                -- Card background
                love.graphics.setColor(0.1, 0.12, 0.16, 0.9)
                love.graphics.rectangle('fill', 20, y, sw - 40, 50, 4)
                love.graphics.setColor(0.25, 0.35, 0.5, 0.6)
                love.graphics.rectangle('line', 20, y, sw - 40, 50, 4)

                -- Contract info
                love.graphics.setColor(0.85, 0.85, 0.85)
                love.graphics.print(contract.name .. ' — ' .. contract.desc, 30, y + 4)
                love.graphics.setColor(0.9, 0.8, 0.3)
                love.graphics.print('Reward: ' .. contract.reward .. ' cr', 30, y + 22)

                local daysLeft = (contract.timeLimit or 30) - (GameState.day - (contract.dayAccepted or 0))
                if daysLeft > 5 then
                    love.graphics.setColor(0.5, 0.7, 0.5)
                else
                    love.graphics.setColor(0.9, 0.3, 0.3)
                end
                love.graphics.print(daysLeft .. ' days left', sw - 150, y + 22)

                -- Complete button
                local btnX, btnY, btnW, btnH = sw - 130, y + 4, 80, 18
                love.graphics.setColor(0.2, 0.5, 0.3, 0.8)
                love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 3)
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.print('Complete', btnX + 8, btnY + 2)
                hitZones[#hitZones + 1] = {
                    x = btnX, y = btnY, w = btnW, h = btnH,
                    action = 'complete_contract', contractId = contract.id,
                }

                y = y + 56
            end
        end
    end

    y = y + 20

    -- Station contracts (if docked)
    local sdOk, StationDocking = pcall(require, 'src.space.station_docking')
    local station = sdOk and StationDocking.getDockedStation()

    if station then
        love.graphics.setColor(0.7, 0.85, 1.0)
        love.graphics.print('AVAILABLE AT ' .. (station.name or 'Station'):upper(), 20, y)
        y = y + 24

        if seOk then
            local available = SpaceEconomy.getContractsAtStation(station.id)
            if #available == 0 then
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.print('No contracts available.', 30, y)
                y = y + 20
            else
                for i, contract in ipairs(available) do
                    love.graphics.setColor(0.08, 0.1, 0.14, 0.9)
                    love.graphics.rectangle('fill', 20, y, sw - 40, 50, 4)
                    love.graphics.setColor(0.2, 0.3, 0.4, 0.6)
                    love.graphics.rectangle('line', 20, y, sw - 40, 50, 4)

                    love.graphics.setColor(0.8, 0.8, 0.8)
                    love.graphics.print(contract.name .. ' — ' .. contract.desc, 30, y + 4)
                    love.graphics.setColor(0.9, 0.8, 0.3)
                    love.graphics.print('Reward: ' .. contract.reward .. ' cr', 30, y + 22)
                    love.graphics.setColor(0.5, 0.5, 0.5)
                    love.graphics.print('Time limit: ' .. (contract.timeLimit or '?') .. ' days', 250, y + 22)

                    -- Accept button
                    local btnX, btnY2, btnW, btnH = sw - 120, y + 4, 70, 18
                    love.graphics.setColor(0.3, 0.4, 0.6, 0.8)
                    love.graphics.rectangle('fill', btnX, btnY2, btnW, btnH, 3)
                    love.graphics.setColor(0.9, 0.9, 0.9)
                    love.graphics.print('Accept', btnX + 10, btnY2 + 2)
                    hitZones[#hitZones + 1] = {
                        x = btnX, y = btnY2, w = btnW, h = btnH,
                        action = 'accept_contract', contractId = contract.id,
                    }

                    y = y + 56
                end
            end
        end
    else
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.print('Dock at a station to see available contracts.', 20, y)
    end
end

function ContractsPanel.keypressed(key)
    if not visible then return false end
    if key == 'escape' or key == 'k' then
        ContractsPanel.toggle()
        return true
    end
    return false
end

function ContractsPanel.mousepressed(x, y, button)
    if not visible then return false end
    if button ~= 1 then return false end

    for _, zone in ipairs(hitZones) do
        if x >= zone.x and x <= zone.x + zone.w
           and y >= zone.y and y <= zone.y + zone.h then
            local seOk, SpaceEconomy = pcall(require, 'src.space.space_economy')
            if seOk then
                if zone.action == 'accept_contract' then
                    SpaceEconomy.acceptContract(zone.contractId)
                elseif zone.action == 'complete_contract' then
                    SpaceEconomy.completeContract(zone.contractId)
                end
            end
            return true
        end
    end
    return false
end

return ContractsPanel
