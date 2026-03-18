-- shared_control.lua — STUB (multiplayer cut for scope reduction)
-- Shared colony control was removed to focus on singleplayer.
-- This stub exists so pcall(require, ...) calls don't break.

local SharedControl = {}

function SharedControl.init()             end
function SharedControl.update()           end
function SharedControl.registerAction()   end
function SharedControl.executeAction()    end
function SharedControl.drawCursors()      end

return SharedControl
