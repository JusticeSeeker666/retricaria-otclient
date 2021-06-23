-- private variables
local background
local infoWindow
local notesWindow

local accesAccountLink = "https://realesta74.net/register.php"
local websiteLink = "https://realesta74.net/"
downloadClient = "https://realesta74.net/downloads/RealestaClient.zip"

local infoTexts = {
 [1] = "Realesta Client",
 [2] = "Version 7.4",
 [3] = "Copyright (C) 2012-2018",
 [4] = "Realesta Team",
 [5] = "All rights reserved.",
 [6] = "Official Website",
 [7] = "Realesta74.net",
}

-- public functions
function init()
  background = g_ui.displayUI('background')
  background:lower()

  clientVersionLabel = background:getChildById('clientVersionLabel')
  clientVersionLabel:setText(g_app.getName() .. ' ' .. g_app.getVersion() .. '\n' ..
                             'Rev  ' .. g_app.getBuildRevision() .. ' ('.. g_app.getBuildCommit() .. ')\n' ..
                             'Built on ' .. g_app.getBuildDate() .. '\n' .. g_app.getBuildCompiler())

  if not g_game.isOnline() then
    addEvent(function() g_effects.fadeIn(clientVersionLabel, 1500) end)
  end

  connect(g_game, { onGameStart = hide })
  connect(g_game, { onGameEnd = show })
end

function terminate()
  disconnect(g_game, { onGameStart = hide })
  disconnect(g_game, { onGameEnd = show })

  g_effects.cancelFade(background:getChildById('clientVersionLabel'))
  background:destroy()

  Background = nil
end

function hide()
  background:hide()
end

function show()
  background:show()
end

function hideVersionLabel()
  background:getChildById('clientVersionLabel'):hide()
end

function setVersionText(text)
  clientVersionLabel:setText(text)
end

function getBackground()
  return background
end