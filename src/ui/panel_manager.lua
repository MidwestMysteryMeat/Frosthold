-- panel_manager.lua — the single owner of major-panel visibility and focus.
--
-- Every panel used to keep its own `visible` flag and main.lua asked each one
-- in turn whether it wanted the click. Two problems followed from that:
--
--   * Nothing stopped two full-screen panels being open at once, so the
--     roster showed through the diplomacy screen.
--   * Whichever panel sat earliest in main.lua's if-chain swallowed every
--     click and keypress, so the buttons on the panel actually drawn on top
--     were dead. That is why "gift" and "trade" looked broken.
--
-- This module fixes both by making the panels mutually exclusive and by
-- routing input to the topmost open panel only.
--
-- Panels are not rewritten to register themselves. They are adapted: the
-- manager reads their existing isVisible()/isOpen() and drives their existing
-- toggle()/close(). Panels opened from elsewhere (a docking event, a context
-- menu) are adopted into the stack on the next sync, so focus stays correct
-- even for paths that never call in here.

local Layout = require('src.ui.ui_layout')

local PanelManager = {}

---------------------------------------------------------------------------
-- Registry
--
-- `key` is documentation only — main.lua still owns the raw hotkey guards
-- (build mode, shift, space-only) because those depend on game state.
---------------------------------------------------------------------------

local PANELS = {
    { id = 'research',   path = 'src.ui.research_panel',   label = 'Research',   key = 'R' },
    { id = 'policy',     path = 'src.ui.policy_panel',     label = 'Policy',     key = 'P' },
    { id = 'doctrine',   path = 'src.ui.doctrine_panel',   label = 'Doctrine',   key = 'O' },
    { id = 'laws',       path = 'src.ui.laws_panel',       label = 'Laws',       key = 'L' },
    { id = 'factions',   path = 'src.ui.faction_panel',    label = 'Factions',   key = 'Shift+F' },
    { id = 'farm',       path = 'src.ui.farm_panel',       label = 'Farm',       key = 'G' },
    { id = 'trade',      path = 'src.ui.trade_panel',      label = 'Trade',      key = 'T' },
    { id = 'equip',      path = 'src.ui.equip_panel',      label = 'Equipment',  key = 'V' },
    { id = 'taming',     path = 'src.ui.taming_panel',     label = 'Taming',     key = 'Y' },
    { id = 'medical',    path = 'src.ui.medical_panel',    label = 'Medical',    key = 'H' },
    { id = 'colony',     path = 'src.ui.colony_panel',     label = 'Roster',     key = 'C' },
    { id = 'quests',     path = 'src.quest.quest_panel',   label = 'Quests',     key = 'Q' },
    { id = 'goals',      path = 'src.ui.goals_overlay',    label = 'Goals',      key = 'I' },
    { id = 'expedition', path = 'src.ui.expedition_view',  label = 'Expedition', key = 'E' },
    { id = 'starmap',    path = 'src.ui.star_map',         label = 'Star Map',   key = 'M' },
    { id = 'contracts',  path = 'src.ui.contracts_panel',  label = 'Contracts',  key = 'K' },
    { id = 'station',    path = 'src.ui.station_panel',    label = 'Station',    key = nil },
    { id = 'shipyard',   path = 'src.ui.shipyard_panel',   label = 'Shipyard',   key = nil },
    { id = 'debug',      path = 'src.ui.debug_panel',      label = 'Debug',      key = 'F11' },
}

PanelManager.PANELS = PANELS

local byId = {}
for _, spec in ipairs(PANELS) do byId[spec.id] = spec end

local cache = {}
local stack = {}   -- panel ids, last entry is the focused panel

---------------------------------------------------------------------------
-- Module adapters
---------------------------------------------------------------------------

local function moduleFor(id)
    local spec = byId[id]
    if not spec then return nil end
    if cache[id] == nil then
        local ok, mod = pcall(require, spec.path)
        cache[id] = ok and mod or false
    end
    return cache[id] or nil
end

PanelManager.moduleFor = moduleFor

-- Panels never agreed on a name for "am I on screen": most expose isVisible,
-- quest_panel and debug_panel expose isOpen, expedition_view exposes isActive.
-- All three are accepted rather than renamed, to keep the blast radius small.
local function panelVisible(mod)
    if not mod then return false end
    if mod.isVisible then return mod.isVisible() and true or false end
    if mod.isOpen then return mod.isOpen() and true or false end
    if mod.isActive then return mod.isActive() and true or false end
    return false
end

--- Close a panel whatever API it exposes. Prefers an explicit close() and
--- falls back to toggle(), then verifies the panel really went away so a
--- panel that ignores both cannot wedge the stack.
local function forceClose(mod)
    if not panelVisible(mod) then return true end
    if mod.close then mod.close() end
    if panelVisible(mod) and mod.toggle then mod.toggle() end
    return not panelVisible(mod)
end

local function stackIndex(id)
    for i, entry in ipairs(stack) do
        if entry == id then return i end
    end
    return nil
end

--- Reconcile the stack with what the panels themselves believe. Drops panels
--- that closed on their own (a row click that dismisses the roster) and adopts
--- panels opened outside the manager (ShipyardPanel.open from a context menu).
local function sync()
    for i = #stack, 1, -1 do
        if not panelVisible(moduleFor(stack[i])) then
            table.remove(stack, i)
        end
    end
    for _, spec in ipairs(PANELS) do
        if panelVisible(moduleFor(spec.id)) and not stackIndex(spec.id) then
            stack[#stack + 1] = spec.id
        end
    end
end

PanelManager.sync = sync

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function PanelManager.isRegistered(id)
    return byId[id] ~= nil
end

function PanelManager.isOpen(id)
    return panelVisible(moduleFor(id))
end

--- Id of the focused (topmost) panel, or nil.
function PanelManager.top()
    sync()
    return stack[#stack]
end

--- True when any managed panel is on screen. Callers use this to keep HUD
--- chrome and debug overlays from drawing across a panel.
function PanelManager.anyOpen()
    for _, spec in ipairs(PANELS) do
        if panelVisible(moduleFor(spec.id)) then return true end
    end
    return false
end

function PanelManager.openIds()
    sync()
    local ids = {}
    for _, id in ipairs(stack) do ids[#ids + 1] = id end
    return ids
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------

--- Open `id`, closing every other managed panel first. One major panel at a
--- time is the whole point: stacked full-screen panels were unreadable.
function PanelManager.open(id)
    local mod = moduleFor(id)
    if not mod then return false end

    for _, spec in ipairs(PANELS) do
        if spec.id ~= id then
            forceClose(moduleFor(spec.id))
        end
    end
    for i = #stack, 1, -1 do stack[i] = nil end

    if not panelVisible(mod) and mod.toggle then
        mod.toggle()
    end
    if not panelVisible(mod) then return false end

    stack[1] = id
    return true
end

function PanelManager.close(id)
    local mod = moduleFor(id)
    if not mod then return false end
    local closed = forceClose(mod)
    sync()
    return closed
end

--- Close the focused panel. This is what ESC does; it used to fall straight
--- through to the pause menu, which then drew on top of the still-open panel.
function PanelManager.closeTop()
    sync()
    local id = stack[#stack]
    if not id then return false end
    forceClose(moduleFor(id))
    sync()
    return true
end

function PanelManager.closeAll()
    local closedAny = false
    for _, spec in ipairs(PANELS) do
        local mod = moduleFor(spec.id)
        if panelVisible(mod) then
            forceClose(mod)
            closedAny = true
        end
    end
    for i = #stack, 1, -1 do stack[i] = nil end
    return closedAny
end

function PanelManager.toggle(id)
    if PanelManager.isOpen(id) then
        return PanelManager.close(id)
    end
    return PanelManager.open(id)
end

---------------------------------------------------------------------------
-- Draw — topmost last, so z-order matches focus
---------------------------------------------------------------------------

function PanelManager.draw()
    sync()
    for _, id in ipairs(stack) do
        local mod = moduleFor(id)
        if mod and mod.draw then
            mod.draw()
            -- A panel that returned early mid-clip would otherwise leave the
            -- scissor set for everything drawn after it.
            if Layout.clipDepth() > 0 then Layout.resetClip() end
        end
    end
end

---------------------------------------------------------------------------
-- Input — the focused panel gets it, and nobody else
---------------------------------------------------------------------------

-- An open panel is modal, so it consumes the event whether or not its own
-- handler claims it. Letting an unclaimed click through would land on the world
-- behind the panel and clear the colonist selection.
local function routed(method, ...)
    sync()
    local id = stack[#stack]
    if not id then return false end
    local mod = moduleFor(id)
    if mod and mod[method] then mod[method](...) end
    return true
end

function PanelManager.keypressed(key)
    return routed('keypressed', key)
end

function PanelManager.mousepressed(x, y, button)
    return routed('mousepressed', x, y, button)
end

function PanelManager.wheelmoved(dx, dy)
    return routed('wheelmoved', dx, dy)
end

function PanelManager.mousereleased(x, y, button)
    sync()
    local id = stack[#stack]
    if not id then return false end
    local mod = moduleFor(id)
    if mod and mod.mousereleased then mod.mousereleased(x, y, button) end
    return true
end

---------------------------------------------------------------------------
-- Test / reload support
---------------------------------------------------------------------------

function PanelManager.reset()
    for i = #stack, 1, -1 do stack[i] = nil end
end

--- Replace a panel module with a stub. Tests use this to exercise the
--- exclusivity state machine without loading nineteen real panels.
function PanelManager.injectForTest(id, mod)
    if not byId[id] then
        byId[id] = { id = id, path = 'test:' .. id, label = id }
        PANELS[#PANELS + 1] = byId[id]
    end
    cache[id] = mod or false
    PanelManager.reset()
end

return PanelManager
