-- circuits.lua — STUB (system cut for scope reduction)
-- Sensor/comparator/actuator automation was removed.
-- Door locking is now handled by a simple tilemap toggle.
-- This stub exists so pcall(require, ...) calls don't break.

local Circuits = {}

Circuits.SENSOR_TYPES = {}
Circuits.COMPARATORS  = {}

function Circuits.placeSensor()       return nil, 'System removed' end
function Circuits.placeComparator()   return nil, 'System removed' end
function Circuits.placeActuator()     return nil, 'System removed' end
function Circuits.wire()              return false end
function Circuits.registerSystems()   end
function Circuits.init()              end

function Circuits.isDoorLocked(x, y)
    -- Delegate to tilemap door lock (simple toggle replaces circuit logic)
    local ok, World = pcall(require, 'src.world.tilemap')
    if ok and World.isDoorLocked then
        return World.isDoorLocked(x, y)
    end
    return false
end

return Circuits
