-- slavery.lua — STUB (system cut for scope reduction)
-- Slave labor was removed. Prisoners are the depth system now.
-- This stub exists so pcall(require, ...) calls don't break.

local Slavery = {}

function Slavery.enslave()           return false, 'System removed' end
function Slavery.free()              return false end
function Slavery.executeSlave()      return false end
function Slavery.harvestOrgan()      return false, 'System removed' end
function Slavery.butcherSlave()      return false end
function Slavery.getMoralePenalty()   return 0 end
function Slavery.getSlaveCount()     return 0 end
function Slavery.getSlaves()         return {} end
function Slavery.registerSystems()   end
function Slavery.init()              end

return Slavery
