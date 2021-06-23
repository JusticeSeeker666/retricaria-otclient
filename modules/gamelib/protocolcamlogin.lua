
-- @docclass
ProtocolCamLogin = extends(Protocol, "ProtocolCamLogin")

local LoginServerError = 10
local LoginServerTokenSuccess = 12
local LoginServerTokenError = 13
local LoginServerUpdate = 17
local LoginServerMotd = 20
local LoginServerUpdateNeeded = 30
local LoginServerSessionKey = 40
local LoginServerCharacterList = 100
local LoginServerExtendedCharacterList = 101

-- Since 10.76
local LoginServerRetry = 10
local LoginServerErrorNew = 11

function ProtocolCamLogin:login(accountName, accountPassword, stayLogged)
  self.connectCallback = self.sendLoginPacket
  self:connect("127.0.0.1", 7171)
end

function ProtocolCamLogin:cancelLogin()
  self:disconnect()
end

function ProtocolCamLogin:sendLoginPacket()
  local msg = OutputMessage.create()
  msg:addU8(ClientOpcodes.ClientEnterAccount)
  self:send(msg)
  self:recv()
end

function ProtocolCamLogin:onConnect()
  self.gotConnection = true
  self:connectCallback()
  self.connectCallback = nil
end

function ProtocolCamLogin:onError(msg, code)
  local text = translateNetworkError(code, self:isConnecting(), msg)
  signalcall(self.onLoginError, self, text)
end

function ProtocolCamLogin:onRecv(msg)
  while not msg:eof() do
    local opcode = msg:getU8()
    if opcode == LoginServerCharacterList then
      self:parseCharacterList(msg)
    elseif opcode == LoginServerMotd then
      self:parseMotd(msg)
    elseif opcode == LoginServerError then
      self:parseError(msg)
    end
  end
  self:disconnect()
end

function ProtocolCamLogin:parseMotd(msg)
  local motd = msg:getString()
  signalcall(self.onMotd, self, motd)
end

function ProtocolCamLogin:parseError(msg)
  local errorMessage = msg:getString()
  signalcall(self.onLoginError, self, errorMessage)
end


function ProtocolCamLogin:parseCharacterList(msg)
  local characters = {}

  local charactersCount = msg:getU8()
  for i=1,charactersCount do
    local character = {}
    character.name = msg:getString()
    character.worldName = msg:getString()
    character.worldIp = msg:getString()
    character.worldPort = msg:getU16()
    characters[i] = character
  end

  local account = {}
  account.premDays = 0
  signalcall(self.onCharacterList, self, characters, account)
end

