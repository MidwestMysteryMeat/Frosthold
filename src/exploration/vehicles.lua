-- vehicles.lua — STUB (system cut for scope reduction)
-- Modular vehicle construction was removed.
-- Expeditions work without vehicles.
-- This stub exists so pcall(require, ...) calls don't break.

local Vehicles = {}

function Vehicles.init()             end
function Vehicles.getState()         return nil end
function Vehicles.restoreState()     end
function Vehicles.getStats()         return nil end
function Vehicles.registerSystems()  end

return Vehicles
