local m_gameServer
local m_gameProtocol
local writeDir = 'cam'
local m_frames = nil
local frameCounter = 1
local runSendLoop = true
local speedCounter = 3
local playerWindow, playerWindow_fileName, playerWindow_timeBar, playerWindow_timeNow, playerWindow_timeMax
local sendLoopHandle 

local speedArray = {
  {str = "0.25", value = 1/0.25},
  {str = "0.50", value = 1/0.5},
  {str = "1.00", value = 1},
  {str = "2.00", value = 1/2},
  {str = "4.00", value = 1/4},
  {str = "8.00", value = 1/8},
  {str = "16.00", value = 1/16},
  {str = "32.00", value = 1/32},
  {str = "64.00", value = 1/64},
  {str = "128.00", value = 1/128},
  {str = "256.00", value = 1/256}
}

local walkArray = {
  [ClientOpcodes.ClientWalkNorth] = Directions.North,
  [ClientOpcodes.ClientWalkSouth] = Directions.South,
  [ClientOpcodes.ClientWalkEast] = Directions.East,
  [ClientOpcodes.ClientWalkWest] = Directions.West,
  [ClientOpcodes.ClientWalkNorthEast] = Directions.NorthEast,
  [ClientOpcodes.ClientWalkNorthWest] = Directions.NorthWest,
  [ClientOpcodes.ClientWalkSouthEast] = Directions.SouthEast,
  [ClientOpcodes.ClientWalkSouthWest] = Directions.SouthWest,
}

if not g_game.camSystemEnabled() then
	return
end

local time = 0
local updateLabelEvent

local isPaused = false
local pausedTime = nil
local timeChanged = nil
local keepAliveEvent = nil
local keepAliveOpcode = 200
local timeBeforePause = 0
local timeAfterPause = 0
local advanceInTime = false
local timePercentBeforePause = 0
local timePercentAfterPause = 0
local backInTime = false

function timeBarOnValueChange(scrollbar, value)
  if g_cam.isPlaying() and isPaused then
    local timeNowText = millisToHour((g_cam.getDuration() * tonumber(value))/100)
    playerWindow_timeNow:setText(timeNowText)
  end
end

function gameServerIsOnline()
  if not m_gameServer then
    return false
  end
  if m_gameServer:isOpen() then
    return true
  end
end

function startGameServer()
  playerWindow = modules.cam_play.getPlayerWindow()
  playerWindow_fileName = playerWindow:getChildById('fileName')
  playerWindow_timeBar = playerWindow:getChildById('timeBar')
  playerWindow_timeNow = playerWindow:getChildById('timeNow')
  playerWindow_timeMax = playerWindow:getChildById('timeMax')


  if m_gameServer ~= nil then
    if m_gameServer:isOpen() then
      return
    end
  end

  m_gameServer = Server.create(7172)

  if m_gameServer == nil then
    print("Failed to create cam server on port 7172")
    return
  end
  m_gameServer.onAccept = gameServerOnAccept
  m_gameServer:acceptNext()
end

function stopGameServer()
  playerWindow = nil

  if not m_gameServer then return end
  if not m_gameServer:isOpen() then return end

  m_gameServer:close()

  if not m_gameProtocol then return end

  if m_gameProtocol:isConnected() then
    local c = m_gameProtocol:getConnection()
    if c then
      print(string.format("%s has been disconnected.", iptostring(c:getIp())))
    end
      m_gameProtocol:disconnect()
  end
end

function gameServerOnAccept(self, connection, errorMsg, errorCode)
  if errorCode ~= 0 and errorMsg then
    print(string.format("ERROR %d - %s\nServer Closed", errorCode, errorMsg))
    stopGameServer()
    return
  end

  if connection ~= nil then
    if connection:getIp() == 0 then
      return
    end
      if g_game.getClientVersion() >= 840 then
        g_game.disableFeature(GameProtocolChecksum)
      end
      if g_game.getClientVersion() >= 770 then
        g_game.disableFeature(GameLoginPacketEncryption)
      end
      if g_game.getClientVersion() >= 953 and not g_game.getFeature(GameClientPing)then
        g_game.disableFeature(GameClientPing)
      end

    print(string.format("%s is online on GAME.", iptostring(connection:getIp())))
    m_gameProtocol = Protocol.create()
    m_gameProtocol:setConnection(connection)
    m_gameProtocol.onRecv = onGameRecv
    m_gameProtocol.onError = onGameError
    
    m_gameProtocol:recv()
  else
    print("ERROR onAccept() -- Connection is null.")
  end
  m_gameServer:acceptNext()
end

function onGameRecv(protocol, inputMsg)
  if inputMsg:getMessageSize() <= 0 then
    print("RECV < 0")
    return
  end
  parseGameMsg(protocol, inputMsg)
  protocol:recv()
end

function parseGameMsg(protocol, inputMsg)
  local opcode = inputMsg:getU8()
  if opcode == ClientOpcodes.ClientEnterGame then
    if g_cam.isPlaying() then
      return
    end

    if inputMsg:eof() then
      return
    end

    local fileName = inputMsg:getString()
    if not g_cam.preparePlaying("/"..writeDir.."/"..fileName..".cam") then
      return
    end

    if not g_cam.startPlaying() then
      return
    end

    if g_cam.readFrames(10) <= 0 then
      g_cam.stopPlaying()
      m_gameProtocol:disconnect()
      return
    end

    m_frames = g_cam.getFrames()
    if #m_frames == 0 then
      g_cam.stopPlaying()
      m_gameProtocol:disconnect()
      return
    end
    playerWindow_fileName:setText(fileName)
    time = 0
    isPaused = false
    timePercentAfterPause = 0
    timePercentBeforePause = 0

    if backInTime == false then
        timeAfterPause = 0
        timeBeforePause = 0
    end

    advanceInTime = false
    m_gameProtocol:send(m_frames[1]:getMsg())
    time = m_frames[1]:getTime()
    frameCounter = 2
    addEvent(function() sendLoop() end)
  end

  if opcode == ClientOpcodes.ClientLeaveGame then
    m_gameProtocol:disconnect()
    g_cam.stopPlaying()
    stopUpdateLabel()
  end

  for k,v in pairs(walkArray) do
    if opcode == k then
      local player = g_game.getLocalPlayer()
      if player then
        local dir = player:getDirection()
        local out = OutputMessage.create()
        out:addU8(GameServerOpcodes.GameServerCancelWalk)
        out:addU8(dir)
        protocol:send(out)
      end
    end
  end

  if opcode == ClientOpcodes.ClientAutoWalk then
    local player = g_game.getLocalPlayer()
    if player then
      local dir = player:getDirection()
      local out = OutputMessage.create()
      out:addU8(GameServerOpcodes.GameServerCancelWalk)
      out:addU8(dir)
      protocol:send(out)
    end
  end
end

function sendLoop()
  if not g_cam.isPlaying() then
    print("is not playing")
    m_gameProtocol:disconnect()
    stopUpdateLabel()
    return
  end
  if not m_gameProtocol:isConnected() then
    print("is not connected")
    g_cam.stopPlaying()
    stopUpdateLabel()
    return
  end

  if frameCounter > #m_frames then
    m_gameProtocol:disconnect()
    g_cam.stopPlaying()
    stopUpdateLabel()
    return
  end

  if isPaused then
    removeEvent(sendLoopHandle)
    sendLoopHandle = scheduleEvent(sendLoop, 1000)
    return
  end

  if advanceInTime and time > math.floor(timeAfterPause) then
    advanceInTime = false
    speedCounter = 3
  end

  if backInTime and time > math.floor(timeAfterPause) then
    backInTime = false
    speedCounter = 3
  end

  m_gameProtocol:send(m_frames[frameCounter]:getMsg())
  time = m_frames[frameCounter]:getTime()
  startUpdateLabel()
  frameCounter = frameCounter + 1
  if m_frames[frameCounter] then
    removeEvent(sendLoopHandle)
    sendLoopHandle = scheduleEvent(function()
      sendLoop()
    end, (m_frames[frameCounter]:getTime() - time) * speedArray[speedCounter].value)
  else
    if g_cam.readFrames(10) <= 0 then
      g_cam.stopPlaying()
      stopUpdateLabel()
      m_gameProtocol:disconnect()
    else
      frameCounter = 1
      m_frames = g_cam.getFrames()
      removeEvent(sendLoopHandle)
      sendLoopHandle = scheduleEvent(function ()
        sendLoop()
      end, (m_frames[frameCounter]:getTime() - time) * speedArray[speedCounter].value)
    end
  end
end


function onGameError(protocol, errorMsg, errorCode)
  local connection = protocol:getConnection()
  local ip = ""
  if connection then
    ip = iptostring(connection:getIp())
  end

  if errorCode ~= 995 then
    print(string.format("ERROR %d - %s\nClient: %s. Server Closed", errorCode, errorMsg, ip))
  end
  stopGameServer()
end

function sendPrivateMessage(self, opcode, msg)
  local msgTable = loadstring(msg)()
  if not msgTable then
    return
  end

  local message = msgTable.message
  local tabName = msgTable.name
  local tab = modules.game_console.getTab(tabName)

  if not tab then
    tab = modules.game_console.addTab(tabName, true)
  end

  modules.game_console.sendMessage(message, tab)
end

function sendMessageHook(message, tab)
  if not g_cam.isRecording() then 
    return
  end

  local name = tab:getText()

  local outputMsg = OutputMessage.create()
  outputMsg:addU8(GameServerOpcodes.GameServerExtendedOpcode) --extended opcode
  outputMsg:addU8(20) -- My opcode for private and npc messages
  outputMsg:addString("local ret = { name = '"..name.."', message = '"..message.."'}; return ret")

  local inputMsg = InputMessage.create()
  inputMsg:setBuffer(outputMsg:getBuffer())
  g_cam.writeMessage(inputMsg)
end

function startUpdateLabel()
  if updateLabelEvent ~= nil then
    stopUpdateLabel()
  end
  updateLabelEvent = cycleEvent(function()
    updateCamLabel()
  end, 250)
end

function stopUpdateLabel()
  removeEvent(updateLabelEvent)
  updateLabelEvent = nil
  updateCamLabel()
end

function updateCamLabel()
  local camLabel = modules.client_topmenu.getTopMenu():getChildById('camLabel')
  if g_cam.isPlaying() then
    local nowTime = millisToHour(time)
    local duration = millisToHour(g_cam.getDuration())
    local text = string.format("[CAM Player] Speed - %s | Time - %s / %s", speedArray[speedCounter].str, nowTime, duration)
    if camLabel:getText() ~= text then
      camLabel:setText(text)
    end

    if not isPaused then
      playerWindow_timeNow:setText(nowTime)
      playerWindow_timeMax:setText(duration)

      local nowSeconds = math.floor(time / 1000)
      local durationSeconds = math.floor(g_cam.getDuration() / 1000)
      local onePercent = durationSeconds/100
      local percent = math.floor(nowSeconds/onePercent)

      playerWindow_timeBar:setValue(percent)
    end

  else
    local text = "[CAM Player] is active"
    if camLabel:getText() ~= text then
      camLabel:setText(text)
    end
  end
end

function millisToHour(millis)
  local seconds = math.floor((millis / 1000) % 60)
  local minutes = math.floor(((millis / (1000*60)) % 60))
  local hours   = math.floor(((millis / (1000*60*60)) % 24))
  local text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
  return text
end

--- Aceleracao

function onSpeedKeyPress(self, keyCode, keyboardModifiers)
  if keyboardModifiers ~= 0 then
    return
  end

  if not g_cam.isPlaying() or not g_game.isOnline() then
    return
  end

  if keyCode == KeyUp then
    if speedCounter < #speedArray then
      speedCounter = speedCounter + 1
    end
  elseif keyCode == KeyDown then
    if speedCounter > 1 then
      speedCounter = speedCounter - 1
    end
  end
end

-- controles play/pause/avançar

function onStopClick()
  isPaused = not isPaused
  if isPaused then
    keepAliveLoop()
    timeBeforePause = time
    timePercentBeforePause = playerWindow_timeBar:getValue()
    playerWindow_timeBar:setEnabled(true)
  else
    removeEvent(keepAliveEvent)
    timePercentAfterPause = playerWindow_timeBar:getValue()
    if timePercentAfterPause > timePercentBeforePause then
        timeAfterPause = (timePercentAfterPause/100) * g_cam.getDuration()
        advanceInTime = true
        speedCounter = #speedArray
    elseif timePercentAfterPause < timePercentBeforePause then
        timeAfterPause = (timePercentAfterPause/100) * g_cam.getDuration()
        backInTime = true
        speedCounter = #speedArray

        m_gameProtocol:disconnect()
        g_cam.stopPlaying()
        stopUpdateLabel()

        scheduleEvent(function() CharacterList.doLogin() end, 500)
    end
    playerWindow_timeBar:setEnabled(false)
  end
end

function keepAliveLoop()
  if isPaused then
    removeEvent(keepAliveEvent)
    keepAliveEvent = cycleEvent(function ()
      if not isPaused then
        removeEvent(keepAliveEvent)
      else
        sendKeepAlivePacket()
      end
    end, 1000)
  else
    keepAliveEvent = cycleEvent(function ()
      if not isPaused then
        removeEvent(keepAliveEvent)
      else
        sendKeepAlivePacket()
      end
    end, 1000) 
  end
end

function sendKeepAlivePacket()
  if g_cam.isPlaying() and isPaused then
    local msg = OutputMessage.create()
    msg:addU8(ClientOpcodes.ClientExtendedOpcode)
    msg:addU8(keepAliveOpcode)
    msg:addString("keep-alive")
    m_gameProtocol:send(msg)
  end
end


