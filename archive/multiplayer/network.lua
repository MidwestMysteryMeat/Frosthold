-- network.lua — STUB (multiplayer cut for scope reduction)
-- LAN P2P networking was removed to focus on singleplayer.
-- This stub exists so pcall(require, ...) calls don't break.

local Network = {}

function Network.init()                end
function Network.update()              end
function Network.isAvailable()         return false end
function Network.isConnected()         return false end
function Network.getRole()             return 'none' end
function Network.hostGame()            return false, 'Multiplayer removed' end
function Network.joinGame()            return false, 'Multiplayer removed' end
function Network.disconnect()          end
function Network.getPlayerList()       return {} end
function Network.getLocalPlayerId()    return nil end
function Network.sendAction()          end
function Network.setCallback()         end
function Network.registerSystems()     end

return Network
