healthInfoWindow = nil
healthBar = nil
healthLabel = nil
manaLabel = nil
manaBar = nil
healthTooltip = 'Your character health is %d out of %d.'
manaTooltip = 'Your character mana is %d out of %d.'

function init()
  connect(LocalPlayer, { onHealthChange = onHealthChange,
                         onManaChange = onManaChange })

  connect(g_game, { onGameEnd = offline })

  healthInfoWindow = g_ui.loadUI('healthinfo', modules.game_interface.getRightPanel())
  healthInfoWindow:disableResize()
  healthBar = healthInfoWindow:recursiveGetChildById('healthBar')
  manaBar = healthInfoWindow:recursiveGetChildById('manaBar')
  healthLabel = healthInfoWindow:recursiveGetChildById('healthLabel')
  manaLabel = healthInfoWindow:recursiveGetChildById('manaLabel')
  
  healthInfoWindow:getChildById('contentsPanel'):setMarginTop(5)
  
  if g_game.isOnline() then
    local localPlayer = g_game.getLocalPlayer()
    onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
    onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
  end

  healthInfoWindow:setup()
end

function terminate()
  disconnect(LocalPlayer, { onHealthChange = onHealthChange,
                            onManaChange = onManaChange })

  disconnect(g_game, {
    onGameEnd = offline
  })

  healthInfoWindow:destroy()
end

function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

function onHealthChange(localPlayer, health, maxHealth)
  healthLabel:setText(""..health.. "")
  healthBar:setTooltip(tr(healthTooltip, health, maxHealth))
  healthBar:setValue(health, 0, maxHealth)
  
  local healthPercent = ((health*100)/maxHealth)
  local globalWidth = healthBar:getImageTextureWidth() -- 100%
  local sizePercent = ((healthPercent*globalWidth)/100) -- x%
  local percent = round(sizePercent, decimal)
  healthBar:setWidth(percent)
  healthBar:setImageClip(torect('0 0 ' .. tonumber(percent) .. ' 0'))
end

function onManaChange(localPlayer, mana, maxMana)
  manaLabel:setText(""..mana.. "")
  manaBar:setTooltip(tr(manaTooltip, mana, maxMana))
  manaBar:setValue(mana, 0, maxMana)
  
  local manaPercent = ((mana*100)/maxMana)
  local globalWidth = manaBar:getImageTextureWidth() -- 100%

  local sizePercent = ((manaPercent*globalWidth)/100) -- x%
  local percent = round(sizePercent, decimal)
  manaBar:setWidth(percent)
  manaBar:setImageClip(torect('0 0 ' .. tonumber(percent) .. ' 0'))
end

function hideExperience()
  healthInfoWindow:setHeight(math.max(healthInfoWindow.minimizedHeight, healthInfoWindow:getHeight() - removeHeight))
end

function setHealthTooltip(tooltip)
  healthTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    healthBar:setTooltip(tr(healthTooltip, localPlayer:getHealth(), localPlayer:getMaxHealth()))
  end
end

function setManaTooltip(tooltip)
  manaTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    manaBar:setTooltip(tr(manaTooltip, localPlayer:getMana(), localPlayer:getMaxMana()))
  end
end

function onMiniWindowClose()
  healthInfoWindow:open()
end
