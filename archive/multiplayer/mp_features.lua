-- mp_features.lua — STUB (multiplayer cut for scope reduction)
-- NPC colony stand-ins and inter-colony features were removed.
-- This stub exists so pcall(require, ...) calls don't break.

local MPFeatures = {}

function MPFeatures.init()                    end
function MPFeatures.initMarket()              end
function MPFeatures.registerNetworkActions()   end
function MPFeatures.step()                    end
function MPFeatures.getState()                return nil end
function MPFeatures.restoreState()            end

return MPFeatures
