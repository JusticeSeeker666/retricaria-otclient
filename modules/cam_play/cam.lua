if not g_game.camSystemEnabled() then
	return
end

dofile('camlogin')
dofile('camgame')

--[[
  glocal -> g_cam

  functions:
    getFrames
    isPlaying
    startPlaying
    startRecording
    stopRecording
    stopPlaying
    preparePlaying
    isRecording
]]

local icon
local window, playerWindow
local enableCheckBox
local fileList
local writeDir = 'cam'
local camLabel
local event1
local pingLabel
local keepAliveOpcode = 200

local icons = {
  ['play'] = {widget = nil, file = "camplayer.png"},
  ['record'] = {widget = nil, file = "camrecorder.png"},
  ['menu'] = {widget = nil, file = "cammanager.png"}
}

function init()
  icons['play'].widget = modules.client_topmenu.addLeftToggleButton('cam_player', tr('CAM Player'), icons['play'].file, playClick)
  icons['record'].widget = modules.client_topmenu.addLeftToggleButton('cam_recorder', tr('CAM Recorder'), icons['record'].file, recordClick)
  icons['menu'].widget = modules.client_topmenu.addLeftButton('cam_menu', tr('CAM Manager'), icons['menu'].file, menuClick)

  window = g_ui.displayUI("cam.otui")
  playerWindow = g_ui.displayUI("camplayer.otui")
  
  fileList = window:getChildById('fileList')
  camLabel = modules.client_topmenu.getTopMenu():getChildById('camLabel')
  pingLabel = modules.client_topmenu.getTopMenu():getChildById('pingLabel')
  camLabel:setText("[CAM Player] is active")
  camLabel:hide()
  window:setVisible(false)
  playerWindow:setVisible(false)
  
  if not g_resources.directoryExists(writeDir) then
    g_resources.makeDir(writeDir)
  end

  ProtocolGame.registerExtendedOpcode(keepAliveOpcode, function(protocol, opcode, buffer) protocol:sendExtendedOpcode(keepAliveOpcode, "keep-alive") end)
end

function getPlayerWindow()
  return playerWindow
end

function playerWindowToggle()
  if playerWindow:isVisible() then
    playerWindow:hide()
  else
    playerWindow:show()
    playerWindow:focus()
  end
end

function menuClick()
  if window:isVisible() then
    window:hide()
    icons['menu'].widget:setOn(false)
  else
    window:show()
    window:focus(true)
    icons['menu'].widget:setOn(true)
    fileListRefrsh()
  end
end

function playClick()
  if g_cam.isRecording() then
    displayInfoBox("Error", "Stop recording before playing cam.")
    return
  end

  if not gameServerIsOnline() then
    if g_game.isOnline() then
      displayInfoBox("Error", "You need to be offline to play a cam.")
      return
    end
    icons['play'].widget:setOn(true)
    startServer()
  else
    icons['play'].widget:setOn(false)
    stopServer()
  end
end

function recordClick()
  if gameServerIsOnline() then return end

  if g_cam.isPlaying() then
    displayInfoBox("Error", "Stop playing to begin recording cam.")
    return 
  end

  if not g_cam.isRecording() then
    if g_game.isOnline() then 
      displayInfoBox("Error", "You need to be offline to begin recording.")
      return nil
    end
    local file = "/"..writeDir.."/"..os.date("%H %M %S - %d %b %Y") ..".cam"
    if not g_cam.startRecording(file) then
      displayInfoBox("Error", "There was some error saving your cam file.")
      return nil
    end
    icons['record'].widget:setOn(true)
  else
    local fileName = g_cam.stopRecording()
    icons['record'].widget:setOn(false)
    if fileName == "not" then
      return nil
    end
    displayInfoBox("Recording finished!", "Your recording can be found at:\n"..g_resources.getWriteDir().."\\cam".."\n\nFile:\n"..fileName:gsub("/cam/", "")..".")
  end
  return nil
end

function startServer()
  if g_game.getClientVersion() >= 840 and g_game.getFeature(GameProtocolChecksum) then
    g_game.disableFeature(GameProtocolChecksum)
  end
  
  if g_game.getClientVersion() >= 770 and g_game.getFeature(GameLoginPacketEncryption)then
    g_game.disableFeature(GameLoginPacketEncryption)
  end

  if g_game.getClientVersion() >= 953 and not g_game.getFeature(GameClientPing)then
    g_game.disableFeature(GameClientPing)
  end

  local rootPanel = modules.game_interface.getRootPanel()
  connect(rootPanel, {onKeyPress = onSpeedKeyPress})

  ProtocolGame.registerExtendedOpcode(20, modules.cam_play.sendPrivateMessage)
  camLabel:show()
  startLoginServer()
  startGameServer()
  startMoveLabel()
end

function stopServer()
  if g_game.getClientVersion() >= 840 and not g_game.getFeature(GameProtocolChecksum) then
    g_game.enableFeature(GameProtocolChecksum)
  end
  if g_game.getClientVersion() >= 770 and not g_game.getFeature(GameLoginPacketEncryption)then
    g_game.enableFeature(GameLoginPacketEncryption)
  end
  if g_game.getClientVersion() >= 953 and not g_game.getFeature(GameClientPing)then
    g_game.enableFeature(GameClientPing)
  end
  local rootPanel = modules.game_interface.getRootPanel()
  disconnect(rootPanel, {onKeyPress = onSpeedKeyPress})

  camLabel:hide()
  ProtocolGame.unregisterExtendedOpcode(20)
  stopLoginServer()
  stopGameServer()
  stopUpdateLabel()
  stopMoveLabel()
end

function terminate()
  window:destroy()
  playerWindow:destroy()

  for k,v in pairs(icons) do
    if v.widget ~= nil then
      v.widget:destroy()
    end
  end
  stopServer()
  ProtocolGame.unregisterExtendedOpcode(keepAliveOpcode)
end

function startMoveLabel()
  if event1  ~= nil then
    return
  end
  removeEvent(event1)
  event1 = cycleEvent(function ()
    if pingLabel:isVisible() and pingLabel:getText() ~= "" then
      camLabel:removeAnchor(AnchorLeft, 'none')
      camLabel:addAnchor(AnchorLeft, 'prev', AnchorRight)
      camLabel:setMarginLeft(15)
    else
      camLabel:removeAnchor(AnchorLeft, 'none')
      camLabel:addAnchor(AnchorLeft, 'prev', AnchorLeft)
      camLabel:setMarginLeft(0)
    end
  end, 250)
end

function stopMoveLabel()
  removeEvent(event1)
  event1 = nil
end

function fileListRefrsh()
  local files = {}
  local f = g_resources.listDirectoryFiles("/"..writeDir)
  for k,v in ipairs(f) do
    if g_resources.isFileType(v, "cam") then
      table.insert(files, v:match("(.*).cam"))
    end
  end

  if #files == 0 then
    return
  end

  for k,v in ipairs(fileList:getChildren()) do
    v:destroy()
  end

  for k,v in ipairs(files) do
    local widget = g_ui.createWidget('FileWidget', fileList)
    widget:getChildById('name'):setText(v)
  end

end

function fileListRemove()
  local widget = fileList:getFocusedChild()
  if not widget then
    return
  end

  if g_resources.deleteFile("/"..writeDir.."/"..widget:getChildById('name'):getText()..".cam") then
    widget:destroy()
  end
end

