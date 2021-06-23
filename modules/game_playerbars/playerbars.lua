playerBarsWindow = nil
skillsButton = nil
battleButton = nil
vipButton = nil
logoutButton = nil

function init()
	connect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})

	playerBarsWindow = g_ui.loadUI('playerbars', modules.game_interface.getRightPanel())
	playerBarsWindow:disableResize()

	skillsButton = playerBarsWindow:recursiveGetChildById('SkillsButton')
	battleButton = playerBarsWindow:recursiveGetChildById('BattleButton')
	vipButton = playerBarsWindow:recursiveGetChildById('VipButton')
	
	playerBarsWindow:getChildById('contentsPanel'):setMarginTop(3)
  
	playerBarsWindow:open()
	playerBarsWindow:setup()
end

function terminate()
	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})

	playerBarsWindow:destroy()
end

function offline()
	return true
end

function online()
	local player = g_game.getLocalPlayer()
	if player then
		skillsButton:setChecked(false)
		battleButton:setChecked(false)
		vipButton:setChecked(false)
	end
end

function getCheckedButtons(button)
	if button:isChecked() then
		return 1
	else
		return nil
	end
end

function onMiniWindowClose()
  playerBarsWindow:open()
end