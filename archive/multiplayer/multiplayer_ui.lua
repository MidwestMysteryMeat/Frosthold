-- multiplayer_ui.lua — STUB (multiplayer cut for scope reduction)
-- LAN lobby UI was removed to focus on singleplayer.
-- This stub exists so main.lua calls don't break.

local MultiplayerUI = {}

function MultiplayerUI.update()        end
function MultiplayerUI.draw()          end
function MultiplayerUI.keypressed()    return false end
function MultiplayerUI.textinput()     return false end
function MultiplayerUI.mousepressed()  return false end

return MultiplayerUI
