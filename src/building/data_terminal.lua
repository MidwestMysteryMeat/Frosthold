-- data_terminal.lua — Data Recovery Terminal ECS system
-- Processes data discs recovered from fallen colonies to restore research progress.
-- A colonist loads a disc into the terminal; the terminal processes it over PROCESS_TIME seconds.

local ECS = require('src.ecs.ecs')

local DataTerminal = {}

local PROCESS_TIME = 30  -- seconds to process one disc

local function dataTerminalSystem(dt, id, comps)
    local terminal = comps.data_terminal

    -- Check power
    local pOk, Power = pcall(require, 'src.sim.power')
    if pOk then
        terminal.powered = Power.isConsumerPowered(id)
    end
    if not terminal.powered then return end

    -- Processing a disc
    if terminal.processingDisc then
        terminal.processTimer = (terminal.processTimer or PROCESS_TIME) - dt
        if terminal.processTimer <= 0 then
            local disc = terminal.processingDisc
            local rOk, Research = pcall(require, 'src.research.research')
            if rOk and Research.applyDiscProgress then
                Research.applyDiscProgress(disc.techId, disc.quality, disc.partialFraction)
            end

            local stOk, Storyteller = pcall(require, 'src.storyteller.storyteller')
            if stOk and Storyteller.logEvent then
                Storyteller.logEvent('data_recovery',
                    'Data disc processed. Research data from a fallen colony has been recovered.')
            end

            local aOk, Alerts = pcall(require, 'src.ui.alerts')
            if aOk and Alerts.add then
                Alerts.add('Data disc processed. Research progress restored.', 'positive')
            end

            terminal.processingDisc = nil
            terminal.processTimer = nil
        end
        return
    end

    -- Idle — waiting for a colonist to load a disc
end

function DataTerminal.registerSystems()
    ECS.addSystem('data_terminal', { 'data_terminal', 'pos' }, dataTerminalSystem, 48)
end

DataTerminal.registerSystems()

return DataTerminal
