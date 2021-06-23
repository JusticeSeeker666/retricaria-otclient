-- this is the first file executed when the application starts
-- we have to load the first modules form here

SERVER_IP = "127.0.0.1"
SERVER_PORT = 7171
CLIENT_VERSION = 772

-- if g_platform.isProcessRunning("Retricaria") then
	-- g_logger.fatal('Only one client is allowed to be running at the same time.')
	-- g_logger.info(g_platform.getProcessId())
-- end

-- setup logger
g_logger.setLogFile(g_resources.getWorkDir() .. g_app.getCompactName() .. ".log")
g_logger.info(os.date("== application started at %b %d %Y %X"))

-- print first terminal message
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. '')

-- add data directory to the search path
if not g_resources.addSearchPath(g_resources.getWorkDir() .. "data", true) then
  g_logger.fatal("Unable to add data directory to the search path.")
end

-- add data directory to the search path
if not g_resources.addSearchPath(g_resources.getWorkDir() .. "modules", true) then
  g_logger.fatal("Unable to add modules directory to the search path.")
end

-- setup directory for saving configurations
g_resources.setupUserWriteDir(('%s/'):format(g_app.getCompactName()))

-- load settings
g_configs.loadSettings("/config.otml")

g_modules.discoverModules()

-- libraries modules 0-99
g_modules.autoLoadModules(99)
g_modules.ensureModuleLoaded("corelib")
g_modules.ensureModuleLoaded("gamelib")

-- client modules 100-499
g_modules.autoLoadModules(499)
g_modules.ensureModuleLoaded("client")

-- game modules 500-999
g_modules.autoLoadModules(999)
g_modules.ensureModuleLoaded("game_interface")

-- mods 1000-9999
g_modules.autoLoadModules(9999)

g_game.setClientVersion(CLIENT_VERSION)
g_game.setProtocolVersion(CLIENT_VERSION)

if not g_things.loadDat("data/Tibia.dat") then
	g_logger.fatal("Unable to load dat file")
end

if not g_sprites.loadSpr("data/Tibia.spr") then
	g_logger.fatal("Unable to load spr file")
end

EnterGame.setUniqueServer(SERVER_IP, SERVER_PORT, CLIENT_VERSION)
