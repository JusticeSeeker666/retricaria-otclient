InventorySlotStyles = {
  [InventorySlotHead] = "HeadSlot",
  [InventorySlotNeck] = "NeckSlot",
  [InventorySlotBack] = "BackSlot",
  [InventorySlotBody] = "BodySlot",
  [InventorySlotRight] = "RightSlot",
  [InventorySlotLeft] = "LeftSlot",
  [InventorySlotLeg] = "LegSlot",
  [InventorySlotFeet] = "FeetSlot",
  [InventorySlotFinger] = "FingerSlot",
  [InventorySlotAmmo] = "AmmoSlot"
}

Icons = {}
Icons[PlayerStates.Swords] = { tooltip = tr('You may not logout during a fight'), path = '/images/game/states/logout_block', id = 'condition_logout_block' }
Icons[PlayerStates.Poison] = { tooltip = tr('You are poisoned'), path = '/images/game/states/poisoned', id = 'condition_poisoned' }
Icons[PlayerStates.Burn] = { tooltip = tr('You are burning'), path = '/images/game/states/burning', id = 'condition_burning' }
Icons[PlayerStates.Energy] = { tooltip = tr('You are electrified'), path = '/images/game/states/electrified', id = 'condition_electrified' }
Icons[PlayerStates.Drunk] = { tooltip = tr('You are drunk'), path = '/images/game/states/drunk', id = 'condition_drunk' }
Icons[PlayerStates.ManaShield] = { tooltip = tr('You are protected by a magic shield'), path = '/images/game/states/magic_shield', id = 'condition_magic_shield' }
Icons[PlayerStates.Paralyze] = { tooltip = tr('You are paralysed'), path = '/images/game/states/slowed', id = 'condition_slowed' }
Icons[PlayerStates.Haste] = { tooltip = tr('You are hasted'), path = '/images/game/states/haste', id = 'condition_haste' }
Icons[PlayerStates.Drowning] = { tooltip = tr('You are drowning'), path = '/images/game/states/drowning', id = 'condition_drowning' }
Icons[PlayerStates.Freezing] = { tooltip = tr('You are freezing'), path = '/images/game/states/freezing', id = 'condition_freezing' }
Icons[PlayerStates.Dazzled] = { tooltip = tr('You are dazzled'), path = '/images/game/states/dazzled', id = 'condition_dazzled' }
Icons[PlayerStates.Cursed] = { tooltip = tr('You are cursed'), path = '/images/game/states/cursed', id = 'condition_cursed' }
Icons[PlayerStates.PartyBuff] = { tooltip = tr('You are strengthened'), path = '/images/game/states/strengthened', id = 'condition_strengthened' }
Icons[PlayerStates.PzBlock] = { tooltip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
Icons[PlayerStates.Pz] = { tooltip = tr('You are within a protection zone'), path = '/images/game/states/protection_zone', id = 'condition_protection_zone' }
Icons[PlayerStates.Bleeding] = { tooltip = tr('You are bleeding'), path = '/images/game/states/bleeding', id = 'condition_bleeding' }
Icons[PlayerStates.Hungry] = { tooltip = tr('You are hungry'), path = '/images/game/states/hungry', id = 'condition_hungry' }
-- Icons[SkullWhite] = { tooltip = tr('White skull'), path = '/images/game/skulls/condition_skull_white', id = 'skull_white' }
-- Icons[SkullGreen] = { tooltip = tr('Green skull'), path = '/images/game/skulls/condition_skull_green', id = 'skull_green' }
-- Icons[SkullRed] = { tooltip = tr('Red skull'), path = '/images/game/skulls/condition_skull_red', id = 'skull_red' }

inventoryWindow = nil
inventoryPanel = nil
soulLabel = nil
capLabel = nil

fightOffensiveBox = nil
fightBalancedBox = nil
fightDefensiveBox = nil
chaseModeButton = nil
standModeButton = nil

safeFightButton = nil
whiteDoveBox = nil
whiteHandBox = nil
yellowHandBox = nil
redFistBox = nil
fightModeRadioGroup = nil
inventoryMinimized = false

QUEST_BUTTON = false

function init()
  inventoryWindow = g_ui.loadUI('inventory', modules.game_interface.getRightPanel())
  inventoryWindow:disableResize()

  fightOffensiveBox = inventoryWindow:recursiveGetChildById('fightOffensiveBox')
  fightBalancedBox = inventoryWindow:recursiveGetChildById('fightBalancedBox')
  fightDefensiveBox = inventoryWindow:recursiveGetChildById('fightDefensiveBox')

  chaseModeBox = inventoryWindow:recursiveGetChildById('chaseModeBox')
  standModeBox = inventoryWindow:recursiveGetChildById('standModeBox')
  safeFightButton = inventoryWindow:recursiveGetChildById('safeFightBox')

  whiteDoveBox = inventoryWindow:recursiveGetChildById('whiteDoveBox')
  whiteHandBox = inventoryWindow:recursiveGetChildById('whiteHandBox')
  yellowHandBox = inventoryWindow:recursiveGetChildById('yellowHandBox')
  redFistBox = inventoryWindow:recursiveGetChildById('redFistBox')
  
  hotkeysButton = inventoryWindow:recursiveGetChildById('hotkeysButton')

  fightModeRadioGroup = UIRadioGroup.create()
  fightModeRadioGroup:addWidget(fightOffensiveBox)
  fightModeRadioGroup:addWidget(fightBalancedBox)
  fightModeRadioGroup:addWidget(fightDefensiveBox)

  chaseModeRadioGroup = UIRadioGroup.create()
  chaseModeRadioGroup:addWidget(standModeBox)
  chaseModeRadioGroup:addWidget(chaseModeBox)

  connect(fightModeRadioGroup, { onSelectionChange = onSetFightMode })
  connect(chaseModeRadioGroup, { onSelectionChange = onSetChaseMode })
  connect(safeFightButton, { onCheckChange = onSetSafeFight })

  connect(LocalPlayer, { onInventoryChange = onInventoryChange,
                         onSoulChange = onSoulChange,
                         onFreeCapacityChange = onFreeCapacityChange,
                         onStatesChange = onStatesChange,
						 -- onSkullChange = updateCreatureSkull,
						 })

  connect(g_game, { onGameStart = refresh,
                    onGameEnd = offline,
                    onFightModeChange = update,
                    onChaseModeChange = update,
                    onSafeFightChange = update,
                    onPVPModeChange   = update,
                    onWalk = check,
                    onAutoWalk = check
                  })

  inventoryPanel = inventoryWindow:getChildById('contentsPanel')
  soulLabel = inventoryWindow:recursiveGetChildById('soulLabel')
  capLabel = inventoryWindow:recursiveGetChildById('capLabel')
  inventoryWindow:getChildById('contentsPanel'):setMarginTop(3)
  
  for k,v in pairs(Icons) do
    g_textures.preload(v.path)
  end

  if g_game.isOnline() then
     local localPlayer = g_game.getLocalPlayer()
     onSoulChange(localPlayer, localPlayer:getSoul())
     onFreeCapacityChange(localPlayer, localPlayer:getFreeCapacity())
     onStatesChange(localPlayer, localPlayer:getStates(), 0)
	 -- updateCreatureSkull(localPlayer, localPlayer:getSkull())
	 onInventoryMinimize(lastCombatControls[char].inventoryMinimize)
	 onInventoryMinimize()
     refresh()
  end

  refresh()
  inventoryWindow:setup()
end

function terminate()
  if g_game.isOnline() then
    offline()
  end

  disconnect(LocalPlayer, { onInventoryChange = onInventoryChange,
                            onSoulChange = onSoulChange,
                            onFreeCapacityChange = onFreeCapacityChange,
                            onStatesChange = onStatesChange,
                            -- onSkullChange = updateCreatureSkull
							})

  disconnect(g_game, { onGameStart = refresh,
                       onGameEnd = offline,
                       onFightModeChange = update,
                       onChaseModeChange = update,
                       onSafeFightChange = update,
                       onPVPModeChange   = update,
                       onWalk = check,
                       onAutoWalk = check })

  inventoryWindow:destroy()

  fightModeRadioGroup:destroy()
end

function update()
  local fightMode = g_game.getFightMode()
  if fightMode == FightOffensive then
    fightModeRadioGroup:selectWidget(fightOffensiveBox)
  elseif fightMode == FightBalanced then
    fightModeRadioGroup:selectWidget(fightBalancedBox)
  else
    fightModeRadioGroup:selectWidget(fightDefensiveBox)
  end

  local chaseMode = g_game.getChaseMode()
  if chaseMode == 1 then
     chaseModeRadioGroup:selectWidget(chaseModeBox, true)
  else
     chaseModeRadioGroup:selectWidget(standModeBox, true)
  end

  local safeFight = g_game.isSafeFight()
  safeFightButton:setChecked(not safeFight)

end

function check()
	if modules.client_options.getOption('autoChaseOverride') then
		if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
			g_game.setChaseMode(DontChase)
		end
	end
end

function refresh()
  local player = g_game.getLocalPlayer()
  for i = InventorySlotFirst, InventorySlotLast do
    if g_game.isOnline() then
      onInventoryChange(player, i, player:getInventoryItem(i))
    else
      onInventoryChange(player, i, nil)
    end
  end

  if player then
    local char = g_game.getCharacterName()

    local lastCombatControls = g_settings.getNode('LastCombatControls')

    if not table.empty(lastCombatControls) then
      if lastCombatControls[char] then
        g_game.setFightMode(lastCombatControls[char].fightMode)
        g_game.setChaseMode(lastCombatControls[char].chaseMode)
        g_game.setSafeFight(lastCombatControls[char].safeFight)
        if lastCombatControls[char].pvpMode then
          g_game.setPVPMode(lastCombatControls[char].pvpMode)
        end
		onInventoryMinimize(lastCombatControls[char].inventoryMinimize)
      end
    end
  end
  update()
end

function toggleIcon(bitChanged)
  local content = inventoryWindow:recursiveGetChildById('conditionPanel')
  local icon = content:getChildById(Icons[bitChanged].id)
  if icon then
    icon:destroy()
  else
    icon = loadIcon(bitChanged)
    icon:setParent(content)
  end
end

function loadIcon(bitChanged)
  local icon = g_ui.createWidget('ConditionWidget', content)
  icon:setId(Icons[bitChanged].id)
  icon:setImageSource(Icons[bitChanged].path)
  icon:setTooltip(Icons[bitChanged].tooltip)
  return icon
end

function offline()
  inventoryWindow:recursiveGetChildById('conditionPanel'):destroyChildren()
  local lastCombatControls = g_settings.getNode('LastCombatControls')
  if not lastCombatControls then
    lastCombatControls = {}
  end

  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()
    lastCombatControls[char] = {
      fightMode = g_game.getFightMode(),
      chaseMode = g_game.getChaseMode(),
      safeFight = g_game.isSafeFight(),
	  inventoryMinimize = inventoryMinimized
    }

    if g_game.getFeature(GamePVPMode) then
      lastCombatControls[char].pvpMode = g_game.getPVPMode()
    end
    -- save last combat control settings
    g_settings.setNode('LastCombatControls', lastCombatControls)
  end
end

function onStatesChange(localPlayer, now, old)
  if now == old then return end

  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then
      toggleIcon(bitChanged)
    end
  end
end

-- hooked events
function onInventoryChange(player, slot, item, oldItem)
  local itemWidget = inventoryPanel:getChildById('slot' .. slot)
  if item then
    itemWidget:setStyle('Item')
    itemWidget:setItem(item)
  else
    itemWidget:setStyle(InventorySlotStyles[slot])
    itemWidget:setItem(nil)
  end
end

function onSoulChange(localPlayer, soul)
	if (soul > 10000) then
		soulLabel:setText(tr("10K+"))
	else
		soulLabel:setText(soul)
	end
end

function onFreeCapacityChange(player, freeCapacity)
  if not freeCapacity then return end
  if freeCapacity > 99 then
    freeCapacity = math.floor(freeCapacity * 10) / 10
  end
  if freeCapacity > 999 then
    freeCapacity = math.floor(freeCapacity)
  end
  if freeCapacity > 99999 then
    freeCapacity = math.min(9999, math.floor(freeCapacity/1000)) .. "k"
  end
  capLabel:setText(freeCapacity * 100)
end

function hideLabels()
  local removeHeight = math.max(capLabel:getMarginRect().height, soulLabel:getMarginRect().height)
  capLabel:setOn(false)
  soulLabel:setOn(false)
  inventoryWindow:setHeight(math.max(inventoryWindow.minimizedHeight, inventoryWindow:getHeight() - removeHeight))
end

function onSetFightMode(self, selectedFightButton)
  if selectedFightButton == nil then return end
  local buttonId = selectedFightButton:getId()
  local fightMode
  
  if buttonId == 'fightOffensiveBox' then
    fightMode = FightOffensive
  elseif buttonId == 'fightBalancedBox' then
    fightMode = FightBalanced
  else
    fightMode = FightDefensive
  end
  g_game.setFightMode(fightMode)
end

function onSetChaseMode(self, checked, overide)
	local chaseMode
	if checked then
		chaseMode = ChaseOpponent
	else
		chaseMode = DontChase
	end
	
	-- if overide then
		-- g_game.setChaseMode(DontChase)
	-- end
  
	g_game.setChaseMode(chaseMode)
end


function onSetSafeFight(self, checked)
  g_game.setSafeFight(not checked)
end

function onSetPVPMode(self, selectedPVPButton)
  if selectedPVPButton == nil then
    return
  end

  local buttonId = selectedPVPButton:getId()
  local pvpMode = PVPWhiteDove
  if buttonId == 'whiteDoveBox' then
    pvpMode = PVPWhiteDove
  elseif buttonId == 'whiteHandBox' then
    pvpMode = PVPWhiteHand
  elseif buttonId == 'yellowHandBox' then
    pvpMode = PVPYellowHand
  elseif buttonId == 'redFistBox' then
    pvpMode = PVPRedFist
  end

  g_game.setPVPMode(pvpMode)
end

function getPVPBoxByMode(mode)
  local widget = nil
  if mode == PVPWhiteDove then
    widget = whiteDoveBox
  elseif mode == PVPWhiteHand then
    widget = whiteHandBox
  elseif mode == PVPYellowHand then
    widget = yellowHandBox
  elseif mode == PVPRedFist then
    widget = redFistBox
  end
  return widget
end

-- function updateCreatureSkull(creature, skullId)
-- local player = g_game.getLocalPlayer()
  -- if creature ~= player then return end
  -- local skullIcons = {2, 3, 4}
  -- for k,v in pairs(skullIcons) do
    -- content = inventoryWindow:recursiveGetChildById('conditionPanel')
    -- icon = content:getChildById(Icons[v].id)
	 -- if icon then
	    -- icon:destroy()
	 -- end
  -- end
  -- toggleSkullIcon(skullId)
-- end

-- function toggleSkullIcon(skullId)
-- if skullId == 0 then return end
   -- content = inventoryWindow:recursiveGetChildById('conditionPanel')
   -- icon = content:getChildById(Icons[skullId].id)
   -- if not icon then
      -- icon = loadIcon(skullId)
      -- icon:setParent(content)
   -- end
-- end

function onMiniWindowClose()
  inventoryWindow:open()
end

function onInventoryMinimize(value)
	soulPanel = inventoryWindow:recursiveGetChildById('soulPanel')
	capPanel = inventoryWindow:recursiveGetChildById('capPanel')
	optionsButton = inventoryWindow:recursiveGetChildById('optionsButton')
	hotkeysButton = inventoryWindow:recursiveGetChildById('hotkeysButton')
	questButton = inventoryWindow:recursiveGetChildById('questButton')
	stopButton = inventoryWindow:recursiveGetChildById('stopButton')
	conditionPanel = inventoryWindow:recursiveGetChildById('conditionPanel')
	miniwindowScrollBar = inventoryWindow:recursiveGetChildById('miniwindowScrollBar')
	miniwindowScrollBar:hide()

	minimizeButton = inventoryWindow:recursiveGetChildById('minButton')

	local function hideSlots(value)
		for slots = 1, 10 do
			slots = inventoryWindow:recursiveGetChildById('slot' .. slots)
			if value then slots:hide() else slots:show() end
		end
	end

	if value then
		fightOffensiveBox:setMargin(3, 97)
		fightBalancedBox:setMargin(4, 76)
		fightDefensiveBox:setMargin(3, 54)

		standModeBox:setMargin(25, 97, -15, 9)
		chaseModeBox:setMargin(25, 76, -15, 9)
		safeFightButton:setMargin(25, 54, -15, 9)

		capPanel:setMarginTop(-119)
		capPanel:setMarginLeft(-58)

		soulPanel:setMarginTop(-97)
		soulPanel:setMarginLeft(18)

		optionsButton:setMargin(6, 8)
		hotkeysButton:setMargin(3, 8)
		questButton:setMargin(29, 8)

		conditionPanel:setMarginRight(54)
		stopButton:hide()
	else
		fightOffensiveBox:setMargin(16, 29)
		fightBalancedBox:setMargin(37, 29)
		fightDefensiveBox:setMargin(57, 29)

		standModeBox:setMargin(16, 6, 0, 0)
		chaseModeBox:setMargin(36, 6, 0, 0)
		safeFightButton:setMargin(57, 6, 0, 0)

		capPanel:setMargin(2, 59, 17, 0)
		
		soulPanel:setMarginTop(3)
		soulPanel:setMarginLeft(3)

		optionsButton:setMargin(106, 10)
		hotkeysButton:setMargin(3, 10)
		questButton:setMargin(3, 10)
		stopButton:show()
		conditionPanel:setMarginRight(73)
	end
	
	inventoryMinimized = value
	hideSlots(value)
	-- soulLabel:hide()
	soulPanel:show()
	minimizeButton:setOn(value)
	inventoryWindow:setHeight(value and 68 or 171)
end
