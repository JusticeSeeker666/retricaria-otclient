local m_loginServer
local m_loginProtocol

local LoginServerError = 10
local LoginServerTokenSuccess = 12
local LoginServerTokenError = 13
local LoginServerUpdate = 17
local LoginServerMotd = 20
local LoginServerUpdateNeeded = 30
local LoginServerSessionKey = 40
local LoginServerCharacterList = 100
local LoginServerExtendedCharacterList = 101
local LoginServerRetry = 10
local LoginServerErrorNew = 11

local writeDir = 'cam'

function serverIsOnline()
  if not m_loginServer then
    return false
  end
  if m_loginServer:isOpen() then
    return true
  end
end
-- character list server
function startLoginServer()
  if m_loginServer ~= nil then
    if m_loginServer:isOpen() then
      return
    end
  end

  m_loginServer = Server.create(7171)

  if m_loginServer == nil then
    return
  end
  m_loginServer.onAccept = loginServerOnAccept
  m_loginServer:acceptNext()
end

function stopLoginServer()
  if not m_loginServer then return end
  if not m_loginServer:isOpen() then return end

  m_loginServer:close()

  if not m_loginProtocol then return end

  if m_loginProtocol:isConnected() then
    local c = m_loginProtocol:getConnection()
    if c then
      print(string.format("%s has been disconnected.", iptostring(c:getIp())))
    end
      m_loginProtocol:disconnect()
  end
end

function loginServerOnAccept(self, connection, errorMsg, errorCode)
  if errorCode ~= 0 and errorMsg then
    print(string.format("ERROR %d - %s\nServer Closed", errorCode, errorMsg))
    stopLoginServer()
    return
  end

  if connection ~= nil then
    if connection:getIp() == 0 then
      return
    end
    if g_game.getClientVersion() >= 840 and g_game.getFeature(GameProtocolChecksum) then
      g_game.disableFeature(GameProtocolChecksum)
    end
     if g_game.getClientVersion() >= 770 and g_game.getFeature(GameLoginPacketEncryption)then
      g_game.disableFeature(GameLoginPacketEncryption)
    end
  

    print(string.format("%s is online on login.", iptostring(connection:getIp())))
    m_loginProtocol = Protocol.create()
    m_loginProtocol:setConnection(connection)
    m_loginProtocol.onRecv = onRecv
    m_loginProtocol.onError = onError
    
    m_loginProtocol:recv()
  else
    print("ERROR onAccept() -- Conexao nula")
  end
  m_loginServer:acceptNext()
end

function onRecv(protocol, inputMsg)
  if inputMsg:getMessageSize() <= 0 then
    return
  end
  parseMsg(protocol, inputMsg)
  protocol:recv()
end

function parseMsg(protocol, inputMsg)
  local opcode = inputMsg:getU8()
  if opcode ~= ClientOpcodes.ClientEnterAccount then
    sendError(protocol, 'Unexpected packet.')
  end

  
  local files = {}
  local realDir = g_resources.getWriteDir().."\\"..writeDir
  local f = g_resources.listDirectoryFiles("/"..writeDir)
  for k,v in ipairs(f) do
    if g_resources.isFileType(v, "cam") then
      table.insert(files, v:match("(.*).cam"))
    end
  end

  if #files == 0 then
    sendError(protocol, string.format('No cam file has been found at: %s', realDir))
  elseif #files >= 1 then
    sendCamFiles(protocol, files)
  end

end

function sendError(protocol, str)
  local output = OutputMessage.create()
  output:addU8(LoginServerError)
  output:addString(str)
  protocol:send(output)
  protocol:disconnect()
end

function sendCamFiles(protocol, files)
  local output = OutputMessage.create()
  output:addU8(LoginServerCharacterList)

  output:addU8(#files)
  for i=1, #files do
    output:addString(files[i]) -- char name
    output:addString("CAM") -- world name
    output:addString("127.0.0.1") -- world ip
    output:addU16(7172)
  end
  protocol:send(output)
end

function onError(protocol, errorMsg, errorCode)
  local connection = protocol:getConnection()
  local ip = ""
  if connection then
    ip = iptostring(connection:getIp())
  end
  if errorCode ~= 995 then
    print(string.format("ERROR %d - %s\nClient: %s. Server Closed", errorCode, errorMsg, ip))
  end
  stopLoginServer()
end
