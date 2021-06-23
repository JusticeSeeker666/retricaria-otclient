local defaultOptions = {
  vsync = false,
  showFps = true,
  showPing = true,
  fullscreen = false,
  classicControl = false,
  autoChaseOverride = true,
  showStatusMessagesInConsole = true,
  showEventMessagesInConsole = true,
  showInfoMessagesInConsole = true,
  showTimestampsInConsole = true,
  showLevelsInConsole = true,
  showPrivateMessagesInConsole = true,
  showPrivateMessagesOnScreen = true,
  showRightPanel = true,
  showRightSecondPanel = false,
  showRightThirdPanel = false,
  showLeftPanel = false,
  showLeftSecondPanel = false,
  showLeftThirdPanel = false,
  panelPriorite = true,
  moveWindowsToPanel = false,
  foregroundFrameRate = 61,
  backgroundFrameRate = 201,
  painterEngine = 0,
  enableLights = true,
  ambientLight = 25,
  displayNames = true,
  displayHealth = true,
  displayMana = true,
  displayText = true,
  dontStretchShrink = false,
  turnDelay = 30,
  hotkeyDelay = 30,
    
  wsadWalking = false,
  walkFirstStepDelay = 200,
  walkTurnDelay = 100,
  walkStairsDelay = 50,
  walkTeleportDelay = 200,
  walkCtrlTurnDelay = 150,
}

local optionsWindow
local optionsButton
local optionsTabBar
local options = {}
local generalPanel
local consolePanel
local graphicsPanel
local audioButton
local panelPrioriteRadioGroup

local function setupGraphicsEngines()
  local enginesRadioGroup = UIRadioGroup.create()
  local ogl1 = graphicsPanel:getChildById('opengl1')
  local ogl2 = graphicsPanel:getChildById('opengl2')
  local dx9 = graphicsPanel:getChildById('directx9')
  enginesRadioGroup:addWidget(ogl1)
  enginesRadioGroup:addWidget(ogl2)
  enginesRadioGroup:addWidget(dx9)

  if g_window.getPlatformType() == 'WIN32-EGL' then
    enginesRadioGroup:selectWidget(dx9)
    ogl1:setEnabled(false)
	ogl1:hide()
    ogl2:setEnabled(false)
	ogl2:hide()
    dx9:setEnabled(true)
  else
    ogl1:setEnabled(g_graphics.isPainterEngineAvailable(1))
    ogl2:setEnabled(g_graphics.isPainterEngineAvailable(2))
    dx9:setEnabled(false)
    if g_graphics.getPainterEngine() == 2 then
      enginesRadioGroup:selectWidget(ogl2)
    else
      enginesRadioGroup:selectWidget(ogl1)
    end

	if not dx9:isEnabled() then
	  dx9:hide()
	end
	
    if g_app.getOs() ~= 'windows' then
      dx9:hide()
    end
  end

  enginesRadioGroup.onSelectionChange = function(self, selected)
    if selected == ogl1 then
      setOption('painterEngine', 1)
    elseif selected == ogl2 then
      setOption('painterEngine', 2)
    end
  end

  if not g_graphics.canCacheBackbuffer() then
    graphicsPanel:getChildById('foregroundFrameRate'):disable()
    graphicsPanel:getChildById('foregroundFrameRateLabel'):disable()
  end
end

function init()
  for k,v in pairs(defaultOptions) do
    g_settings.setDefault(k, v)
    options[k] = v
  end

  optionsWindow = g_ui.displayUI('options')
  optionsWindow:hide()

  optionsTabBar = optionsWindow:getChildById('optionsTabBar')
  optionsTabBar:setContentWidget(optionsWindow:getChildById('optionsTabContent'))

  g_keyboard.bindKeyDown('Ctrl+Shift+F', function() toggleOption('fullscreen') end)
  g_keyboard.bindKeyDown('Ctrl+N', toggleDisplays)

  generalPanel = g_ui.loadUI('game')
  optionsTabBar:addTab(tr('Game'), generalPanel, '/images/optionstab/game')

  consolePanel = g_ui.loadUI('console')
  optionsTabBar:addTab(tr('Console'), consolePanel, '/images/optionstab/console')

  graphicsPanel = g_ui.loadUI('graphics')
  optionsTabBar:addTab(tr('Graphics'), graphicsPanel, '/images/optionstab/graphics')

  panelsPanel = g_ui.loadUI('panels')
  optionsTabBar:addTab(tr('Panels'), panelsPanel, '/images/optionstab/panels')
  --Additional panels actions
  --Choose panel priorite
  panelPrioriteRadioGroup = UIRadioGroup.create()
  local leftPanelMode = panelsPanel:getChildById('leftPanelMode')
  local rightPanelMode = panelsPanel:getChildById('rightPanelMode')
  panelPrioriteRadioGroup:addWidget(leftPanelMode)
  panelPrioriteRadioGroup:addWidget(rightPanelMode)
  panelPrioriteRadioGroup.onSelectionChange = function(self, selected)
    if selected == rightPanelMode then
      setOption('panelPriorite', true)
    elseif selected == leftPanelMode then
      setOption('panelPriorite', false)
    end
  end

  optionsButton = modules.client_topmenu.addLeftButton('optionsButton', tr('Options'), '/images/topbuttons/options', toggle)

  addEvent(function() setup() end)
  
  connect(g_game, { onGameStart = online,
                     onGameEnd = offline })                    
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                     onGameEnd = offline })  

  g_keyboard.unbindKeyDown('Ctrl+Shift+F')
  g_keyboard.unbindKeyDown('Ctrl+N')
  optionsWindow:destroy()
  optionsButton:destroy()
end

function setup()
  setupGraphicsEngines()

  -- load options
  for k,v in pairs(defaultOptions) do
    if type(v) == 'boolean' then
      setOption(k, g_settings.getBoolean(k), true)
    elseif type(v) == 'number' then
      setOption(k, g_settings.getNumber(k), true)
    elseif type(v) == 'string' then
      setOption(k, g_settings.getString(k), true)
    end
  end
  
  if g_game.isOnline() then
    online()
  end  
end

function toggle()
  if optionsWindow:isVisible() then
    hide()
  else
    show()
  end
end

function show()
  optionsWindow:show()
  optionsWindow:raise()
  optionsWindow:focus()
end

function hide()
  optionsWindow:hide()
end

function toggleDisplays()
  if options['displayNames'] and options['displayHealth'] and options['displayMana'] then
    setOption('displayNames', false)
  elseif options['displayHealth'] then
    setOption('displayHealth', false)
    setOption('displayMana', false)
  else
    if not options['displayNames'] and not options['displayHealth'] then
      setOption('displayNames', true)
    else
      setOption('displayHealth', true)
      setOption('displayMana', true)
    end
  end
end

function toggleOption(key)
  setOption(key, not getOption(key))
end

function setOption(key, value, force)
  if not force and options[key] == value then return end
  local gameMapPanel = modules.game_interface.getMapPanel()

  if key == 'vsync' then
    g_window.setVerticalSync(value)
  elseif key == 'showFps' then
    modules.client_topmenu.setFpsVisible(value)
  elseif key == 'showPing' then
    modules.client_topmenu.setPingVisible(value)
  elseif key == 'fullscreen' then
    g_window.setFullscreen(value)
  elseif key == 'panelPriorite' then
    if value then
      panelPrioriteRadioGroup:selectWidget(panelsPanel:getChildById('rightPanelMode'))
    else
      panelPrioriteRadioGroup:selectWidget(panelsPanel:getChildById('leftPanelMode'))
    end
  elseif key == 'showRightPanel' then
    modules.game_interface.getRightPanel():setOn(value)
  elseif key == 'showRightSecondPanel' then
    modules.game_interface.getRightSecondPanel():setOn(value)
  elseif key == 'showRightThirdPanel' then
    modules.game_interface.getRightThirdPanel():setOn(value)
  elseif key == 'showLeftPanel' then
    modules.game_interface.getLeftPanel():setOn(value)
  elseif key == 'showLeftSecondPanel' then
    modules.game_interface.getLeftSecondPanel():setOn(value)
  elseif key == 'showLeftThirdPanel' then
    modules.game_interface.getLeftThirdPanel():setOn(value)
  elseif key == 'moveWindowsToPanel' then
    g_settings.set('moveWindowsToPanel', true)
  elseif key == 'backgroundFrameRate' then
    local text, v = value, value
    if value <= 0 or value >= 201 then text = 'max' v = 0 end
    graphicsPanel:getChildById('backgroundFrameRateLabel'):setText(tr('Game framerate limit: %s', text))
    g_app.setBackgroundPaneMaxFps(v)
  elseif key == 'foregroundFrameRate' then
    local text, v = value, value
    if value <= 0 or value >= 61 then  text = 'max' v = 0 end
    graphicsPanel:getChildById('foregroundFrameRateLabel'):setText(tr('Interface framerate limit: %s', text))
    g_app.setForegroundPaneMaxFps(v)
  elseif key == 'enableLights' then
    gameMapPanel:setDrawLights(value and options['ambientLight'] < 100)
    graphicsPanel:getChildById('ambientLight'):setEnabled(value)
    graphicsPanel:getChildById('ambientLightLabel'):setEnabled(value)
  elseif key == 'ambientLight' then
    graphicsPanel:getChildById('ambientLightLabel'):setText(tr('Ambient light: %s%%', value))
    gameMapPanel:setMinimumAmbientLight(value/100)
    gameMapPanel:setDrawLights(options['enableLights'] and value < 100)
  elseif key == 'painterEngine' then
    g_graphics.selectPainterEngine(value)
  elseif key == 'displayNames' then
    gameMapPanel:setDrawNames(value)
  elseif key == 'displayHealth' then
    gameMapPanel:setDrawHealthBars(value)
  elseif key == 'displayMana' then
    gameMapPanel:setDrawManaBar(value)
  elseif key == 'displayText' then
    gameMapPanel:setDrawTexts(value)
  elseif key == 'dontStretchShrink' then
    addEvent(function()
      modules.game_interface.updateStretchShrink()
    end)
  elseif key == 'hotkeyDelay' then
    generalPanel:getChildById('hotkeyDelayLabel'):setText(tr('Hotkey delay: %sms', value))
  elseif key == 'dash' then
    if value then
      g_game.setMaxPreWalkingSteps(2)
    else 
      g_game.setMaxPreWalkingSteps(1)    
    end
  elseif key == 'wsadWalking' then
    if modules.game_console and modules.game_console.consoleToggleChat:isChecked() ~= value then
      modules.game_console.consoleToggleChat:setChecked(value)
    end
  elseif key == 'hotkeyDelay' then
    generalPanel:getChildById('hotkeyDelayLabel'):setText(tr('Hotkey delay: %s ms', value))  
  elseif key == 'walkFirstStepDelay' then
    generalPanel:getChildById('walkFirstStepDelayLabel'):setText(tr('Walk delay after first step: %s ms', value))  
  elseif key == 'walkTurnDelay' then
    generalPanel:getChildById('walkTurnDelayLabel'):setText(tr('Walk delay after turn: %s ms', value))  
  elseif key == 'walkStairsDelay' then
    generalPanel:getChildById('walkStairsDelayLabel'):setText(tr('Walk delay after floor change: %s ms', value))  
  elseif key == 'walkTeleportDelay' then
    generalPanel:getChildById('walkTeleportDelayLabel'):setText(tr('Walk delay after teleport: %s ms', value))  
  elseif key == 'walkCtrlTurnDelay' then
    generalPanel:getChildById('walkCtrlTurnDelayLabel'):setText(tr('Walk delay after ctrl turn: %s ms', value))  
  end

  -- change value for keybind updates
  for _,panel in pairs(optionsTabBar:getTabsPanel()) do
    local widget = panel:recursiveGetChildById(key)
    if widget then
      if widget:getStyle().__class == 'UICheckBox' then
        widget:setChecked(value)
      elseif widget:getStyle().__class == 'UIScrollBar' then
        widget:setValue(value)
      elseif widget:getStyle().__class == 'UIComboBox' then
        if type(value) == "string" then
          widget:setCurrentOption(value, true)
          break
        end
        if value == nil or value < 1 then 
          value = 1
        end
        if widget.currentIndex ~= value then
          widget:setCurrentIndex(value, true)
        end
      end
      break
    end
  end

  g_settings.set(key, value)
  options[key] = value
end

function getOption(key)
  return options[key]
end

function addTab(name, panel, icon)
  optionsTabBar:addTab(name, panel, icon)
end

function addButton(name, func, icon)
  optionsTabBar:addButton(name, func, icon)
end

function removeTab(name)
  optionsTabBar:removeTab(optionsTabBar:getTab(name))
end

-- hide/show

function online()
  setLightOptionsVisibility(not g_game.getFeature(GameForceLight))
end

function offline()
  setLightOptionsVisibility(true)
end

-- classic view

-- graphics
function setLightOptionsVisibility(value)
  graphicsPanel:getChildById('enableLights'):setEnabled(value)
  graphicsPanel:getChildById('ambientLightLabel'):setEnabled(value)
  graphicsPanel:getChildById('ambientLight'):setEnabled(value)  
end