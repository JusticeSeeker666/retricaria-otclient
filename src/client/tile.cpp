/*
 * Copyright (c) 2010-2020 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "tile.h"
#include "item.h"
#include "thingtypemanager.h"
#include "map.h"
#include "game.h"
#include "localplayer.h"
#include "effect.h"
#include "protocolgame.h"
#include "lightview.h"
#include <framework/graphics/fontmanager.h>

Tile::Tile(const Position& position) :
    m_position(position),
    m_drawElevation(0),
    m_minimapColor(0),
    m_flags(0),
    m_houseId(0),
    m_localPlayer(nullptr) {}

void Tile::drawGround(const Point& dest, float scaleFactor, LightView* lightView) {
    m_drawElevation = 0;

    for (const auto& ground : m_grounds) {
        ground->draw(dest - m_drawElevation * scaleFactor, scaleFactor, true, lightView);
        m_drawElevation += ground->getElevation();
        if (m_drawElevation > Otc::MAX_ELEVATION)
            m_drawElevation = Otc::MAX_ELEVATION;
    }
}

void Tile::drawBottom(const Point& dest, float scaleFactor, LightView* lightView) {
    for (const auto& item : m_bottomItems) {
        item->draw(dest - m_drawElevation * scaleFactor, scaleFactor, true, lightView);

        m_drawElevation += item->getElevation();
        if (m_drawElevation > Otc::MAX_ELEVATION)
            m_drawElevation = Otc::MAX_ELEVATION;
    }

    for (auto it = m_commonItems.rbegin(); it != m_commonItems.rend(); ++it) {
        const auto& item = *it;

        item->draw(dest - m_drawElevation * scaleFactor, scaleFactor, true, lightView);

        m_drawElevation += item->getElevation();
        if (m_drawElevation > Otc::MAX_ELEVATION)
            m_drawElevation = Otc::MAX_ELEVATION;
    }


    for (const auto& creature : m_walkingCreatures) {
        creature->draw(
            Point(
                dest.x + ((creature->getPosition().x - m_position.x) * Otc::TILE_PIXELS - m_drawElevation) * scaleFactor,
                dest.y + ((creature->getPosition().y - m_position.y) * Otc::TILE_PIXELS - m_drawElevation) * scaleFactor
            ), scaleFactor, lightView);
    }

    for (auto it = m_creatures.rbegin(); it != m_creatures.rend(); ++it) {
        const auto& creature = (*it);
        if (!creature->isWalking()) {
            creature->draw(dest - m_drawElevation * scaleFactor, scaleFactor, lightView);
        }
    }
}

void Tile::drawTop(const Point& dest, float scaleFactor, LightView* lightView) {
    for (const auto& effect : m_effects) {
        effect->drawEffect(dest - m_drawElevation * scaleFactor, scaleFactor, m_position.x - g_map.getCentralPosition().x, m_position.y - g_map.getCentralPosition().y, lightView);
    }

    for (const auto& item : m_topItems) {
        item->draw(dest, scaleFactor, true, lightView);
    }
}

void Tile::draw(const Point& dest, float scaleFactor, LightView* lightView) {
    drawGround(dest, scaleFactor, lightView);
    drawBottom(dest, scaleFactor, lightView);
    drawTop(dest, scaleFactor, lightView);
}

void Tile::clean() {
    m_bottomItems.clear();
    m_grounds.clear();
    m_topItems.clear();
    m_commonItems.clear();
    m_creatures.clear();
    m_things.clear();
}

void Tile::addWalkingCreature(const CreaturePtr& creature) {
    m_walkingCreatures.push_back(creature);
}

void Tile::removeWalkingCreature(const CreaturePtr& creature) {
    auto it = std::find(m_walkingCreatures.begin(), m_walkingCreatures.end(), creature);
    if (it != m_walkingCreatures.end())
        m_walkingCreatures.erase(it);
}

// TODO: Need refactoring
// Redo Stack Position System
void Tile::addThing(const ThingPtr& thing, int stackPos) {
    if (!thing)
        return;

    if (thing->isEffect()) {
        const EffectPtr& effect = thing->static_self_cast<Effect>();
        if (effect->isTopEffect())
            m_effects.insert(m_effects.begin(), effect);
        else
            m_effects.push_back(effect);
    }
    else {
        const uint8_t size = m_things.size();
        uint8_t originalStack = stackPos;

        // priority                                    854
        // 0 - ground,                        -->      -->
        // 1 - ground borders                 -->      -->
        // 2 - bottom (walls),                -->      -->
        // 3 - on top (doors)                 -->      -->
        // 4 - creatures, from top to bottom  <--      -->
        // 5 - items, from top to bottom      <--      <--
        if (stackPos < 0 || stackPos == 255) {
            int priority = thing->getStackPriority();

            // -1 or 255 => auto detect position
            // -2        => append

            bool append;
            if (stackPos == -2)
                append = true;
            else {
                append = (priority <= 3);

                // newer protocols does not store creatures in reverse order
                if (g_game.getClientVersion() >= 854 && priority == 4)
                    append = !append;
            }


            for (stackPos = 0; stackPos < size; ++stackPos) {
                int otherPriority = m_things[stackPos]->getStackPriority();
                if ((append && otherPriority > priority) || (!append && otherPriority >= priority))
                    break;
            }
        }
        else if (stackPos > (int)size)
            stackPos = size;

        m_things.insert(m_things.begin() + stackPos, thing);

        if (thing->isCreature()) {
            const CreaturePtr& creature = thing->static_self_cast<Creature>();
            m_creatures.push_back(creature);
            if (thing->isLocalPlayer()) m_localPlayer = creature;
        }
        else {
            const auto& item = thing->static_self_cast<Item>();

            if (thing->isGroundBorder() || thing->isGround()) {
                m_grounds.push_back(item);
            }
            else if (thing->isOnTop()) {
                m_topItems.push_back(item);
            }
            else if (thing->isOnBottom()) {
                m_bottomItems.push_back(item);
            }
            else {
                originalStack -= m_grounds.size() + m_bottomItems.size() + m_creatures.size();

                if (originalStack > m_commonItems.size()) {
                    m_commonItems.push_back(item);
                }
                else {
                    m_commonItems.insert(m_commonItems.begin() + originalStack, item);
                }
            }
        }

        analyzeThing(thing, true);

        if (m_things.size() > MAX_THINGS)
            removeThing(m_things[MAX_THINGS]);
    }

    thing->setPosition(m_position);
    thing->onAppear();

    if (thing->isTranslucent())
        checkTranslucentLight();
}

// TODO: Need refactoring
bool Tile::removeThing(ThingPtr thing) {
    if (!thing)
        return false;

    bool removed = false;

    if (thing->isEffect()) {
        const EffectPtr& effect = thing->static_self_cast<Effect>();
        auto it = std::find(m_effects.begin(), m_effects.end(), effect);
        if (it != m_effects.end()) {
            m_effects.erase(it);
            removed = true;
        }
    }
    else {
        const auto it = std::find(m_things.begin(), m_things.end(), thing);
        if (it != m_things.end()) {
            analyzeThing(thing, false);
            m_things.erase(it);

            if (thing->isCreature()) {
                const auto subIt = std::find(m_creatures.begin(), m_creatures.end(), thing->static_self_cast<Creature>());
                if (subIt != m_creatures.end()) {
                    if (thing->isLocalPlayer()) m_localPlayer = nullptr;
                    m_creatures.erase(subIt);
                }
            }
            else {
                const ItemPtr& item = thing->static_self_cast<Item>();
                if (thing->isGroundBorder() || thing->isGround()) {
                    const auto& subIt = std::find(m_grounds.begin(), m_grounds.end(), item);
                    if (subIt != m_grounds.end()) m_grounds.erase(subIt);
                }
                else if (thing->isOnTop()) {
                    const auto& subIt = std::find(m_topItems.begin(), m_topItems.end(), item);
                    if (subIt != m_topItems.end()) m_topItems.erase(subIt);
                }
                else if (thing->isOnBottom()) {
                    const auto& subIt = std::find(m_bottomItems.begin(), m_bottomItems.end(), item);
                    if (subIt != m_bottomItems.end()) m_bottomItems.erase(subIt);
                }
                else {
                    const auto& subIt = std::find(m_commonItems.begin(), m_commonItems.end(), item);
                    if (subIt != m_commonItems.end()) m_commonItems.erase(subIt);
                }
            }

            removed = true;
        }
    }

    thing->onDisappear();

    if (thing->isTranslucent())
        checkTranslucentLight();

    return removed;
}

ThingPtr Tile::getThing(int stackPos) {
    if (stackPos >= 0 && stackPos < (int)m_things.size())
        return m_things[stackPos];

    return nullptr;
}

int Tile::getThingStackPos(const ThingPtr& thing) {
    for (int stackpos = -1, s = m_things.size(); ++stackpos < s;) {
        if (thing == m_things[stackpos]) return stackpos;
    }

    return -1;
}

bool Tile::hasThing(const ThingPtr& thing) {
    return std::find(m_things.begin(), m_things.end(), thing) != m_things.end();
}

ThingPtr Tile::getTopThing() {
    if (isEmpty())
        return nullptr;

    const ThingPtr& topComumItem = m_commonItems.front();
    if (topComumItem) {
        return topComumItem;
    }

    return m_things[m_things.size() - 1];
}

std::vector<ItemPtr> Tile::getItems() {
    std::vector<ItemPtr> items;

    for (const ThingPtr& thing : m_things) {
        if (!thing->isItem())
            continue;

        items.push_back(thing->static_self_cast<Item>());
    }

    return items;
}

ItemPtr Tile::getGround() {
    if (!m_grounds.empty()) {
        const auto& ground = m_grounds[0];
        if (ground->isGround()) return ground;
    }

    return nullptr;
}

EffectPtr Tile::getEffect(uint16 id)
{
    for (const EffectPtr& effect : m_effects)
        if (effect->getId() == id)
            return effect;
    return nullptr;
}

int Tile::getGroundSpeed() {
    int groundSpeed = 100;
    if (const ItemPtr& ground = getGround())
        groundSpeed = ground->getGroundSpeed();

    return groundSpeed;
}

uint8 Tile::getMinimapColorByte() {
    if (m_minimapColor != 0)
        return m_minimapColor;

    for (const ItemPtr& item : m_topItems) {
        if (!item->isIgnoreLook()) return item->getMinimapColor();
    }

    for (auto it = m_bottomItems.rbegin(); it != m_bottomItems.rend(); ++it) {
        const ItemPtr& item = *it;
        if (!item->isIgnoreLook()) return item->getMinimapColor();
    }

    for (auto it = m_grounds.rbegin(); it != m_grounds.rend(); ++it) {
        const ItemPtr& item = *it;
        uint8 c = item->getMinimapColor();
        if (c != 0) return c;
    }

    return 255; // alpha
}

ThingPtr Tile::getTopLookThing() {
    for (const ItemPtr& item : m_commonItems) {
        if (!item->isIgnoreLook()) return item;
    }

    for (auto it = m_bottomItems.rbegin(); it != m_bottomItems.rend(); ++it) {
        const ItemPtr& item = *it;
        if (!item->isIgnoreLook()) return item;
    }

    for (auto it = m_grounds.rbegin(); it != m_grounds.rend(); ++it) {
        const ItemPtr& item = *it;
        if (!item->isIgnoreLook()) return item;
    }

    return nullptr;
}

ThingPtr Tile::getTopUseThing() {
    if (!m_commonItems.empty()) return m_commonItems[0];

	for (auto thing : m_things) {
		if (thing->isForceUse() || (!thing->isGround() && !thing->isGroundBorder() && !thing->isOnBottom() && !thing->isOnTop() && !thing->isCreature() && !thing->isSplash()))
			return thing;
	}

	for (auto thing : m_things) {
		if (!thing->isGround() && !thing->isGroundBorder() && !thing->isCreature() && !thing->isSplash())
			return thing;
	}

    //if (!m_creatures.empty()) return m_creatures[0];
    return m_things[0];
}

CreaturePtr Tile::getTopCreature() {
    CreaturePtr creature;
    if (!m_creatures.empty())
        return m_creatures.front();

    if (!m_walkingCreatures.empty())
        return m_walkingCreatures.back();

    // check for walking creatures in tiles around
    if (!creature) {
        for (int xi = -1; xi <= 1; ++xi) {
            for (int yi = -1; yi <= 1; ++yi) {
                Position pos = m_position.translated(xi, yi);
                if (pos == m_position)
                    continue;

                const TilePtr& tile = g_map.getTile(pos);
                if (tile) {
                    for (const CreaturePtr& c : tile->getCreatures()) {
                        if (c->isWalking() && c->getLastStepFromPosition() == m_position && c->getStepProgress() < 0.75f) {
                            return c;
                        }
                    }
                }
            }
        }
    }
    return nullptr;
}

ThingPtr Tile::getTopMoveThing() {
    if (isEmpty())
        return nullptr;

    for (const ThingPtr& thing : m_commonItems) {
        if (!thing->isNotMoveable()) return thing;
    }

    for (auto it = m_bottomItems.rbegin(); it != m_bottomItems.rend(); ++it) {
        const ItemPtr& thing = *it;
        if (!thing->isNotMoveable()) return thing;
    }

    if (hasCreature()) return m_creatures.front();

    return nullptr;
}

ThingPtr Tile::getTopMultiUseThing() {
    if (isEmpty())
        return nullptr;

    if (CreaturePtr topCreature = getTopCreature())
        return topCreature;

    for (const ThingPtr& thing : m_commonItems) {
        if (thing->isMultiUse()) return thing;
    }

    for (auto it = m_bottomItems.rbegin(); it != m_bottomItems.rend(); ++it) {
        const ItemPtr& thing = *it;
        if (thing->isMultiUse()) return thing;
    }

    return m_things[0];
}

bool Tile::isWalkable(bool ignoreCreatures) {
    if (m_countFlag.notWalkable > 0 || m_grounds.empty()) {
        return false;
    }

    if (!ignoreCreatures) {
        for (const CreaturePtr& creature : m_creatures) {
            if (!creature->isPassable() && creature->canBeSeen())
                return false;
        }
    }

    return true;
}

bool Tile::isPathable() {
    return m_countFlag.notPathable == 0;
}

bool Tile::isFullGround() {
    return m_countFlag.fullGround > 0;
}

bool Tile::isFullyOpaque() {
    return isFullGround() || m_countFlag.opaque > 0;
}

bool Tile::isSingleDimension() {
    if (!m_walkingCreatures.empty())
        return false;

    return m_countFlag.notSingleDimension == 0;
}

bool Tile::isLookPossible() {
    return m_countFlag.blockProjectile == 0;
}

bool Tile::isClickable() {

    return !m_grounds.empty() || !m_commonItems.empty() || !m_bottomItems.empty();
}

bool Tile::isEmpty() {
    return m_things.empty();
}

bool Tile::canErase() {
    return m_walkingCreatures.empty() && m_effects.empty() && isEmpty() && m_flags == 0 && m_minimapColor == 0;
}

bool Tile::isDrawable() {
    return !isEmpty() || !m_walkingCreatures.empty() || !m_effects.empty();
}

bool Tile::mustHookEast() {
    for (const ItemPtr& thing : m_bottomItems)
        if (thing->isHookEast())
            return true;

    return false;
}

bool Tile::mustHookSouth() {
    for (const ItemPtr& thing : m_bottomItems)
        if (thing->isHookSouth())
            return true;

    return false;
}

bool Tile::hasCreature() {
    return !m_creatures.empty();
}

bool Tile::limitsFloorsView(bool isFreeView) {
    // ground and walls limits the view
    const ThingPtr& firstThing = getThing(0);
    return firstThing && (firstThing->isGround() || (isFreeView ? firstThing->isOnBottom() && firstThing->blockProjectile() : firstThing->isOnBottom()));
}

int Tile::getElevation() const {
    return m_countFlag.elevation;
}

bool Tile::hasElevation(int elevation) {
    return getElevation() >= elevation;
}

void Tile::checkTranslucentLight() {
    if (m_position.z != Otc::SEA_FLOOR)
        return;

    Position downPos = m_position;
    if (!downPos.down()) return;

    TilePtr tile = g_map.getOrCreateTile(downPos);
    if (!tile)
        return;

    for (const ThingPtr& thing : m_things) {
        if (thing->isTranslucent() || thing->hasLensHelp()) {
            tile->m_flags |= TILESTATE_TRANSLUECENT_LIGHT;
            return;
        }
    }

    tile->m_flags &= ~TILESTATE_TRANSLUECENT_LIGHT;
}

void Tile::analyzeThing(const ThingPtr& thing, bool sum) {
    const int value = sum ? 1 : -1;

    if (thing->getHeight() != 1 || thing->getWidth() != 1)
        m_countFlag.notSingleDimension += value;

    if (!thing->isItem()) return;

    if (thing->isNotWalkable())
        m_countFlag.notWalkable += value;

    if (thing->isNotPathable())
        m_countFlag.notPathable += value;

    if (thing->blockProjectile())
        m_countFlag.blockProjectile += value;

    if (thing->isHookEast())
        m_countFlag.mustHookEast += value;

    if (thing->isHookSouth())
        m_countFlag.mustHookSouth += value;

    m_countFlag.totalElevation += thing->getElevation() * value;

    if (thing->hasDisplacement())
        m_countFlag.hasDisplacement += value;

    if (thing->isFullGround())
        m_countFlag.fullGround += value;

    if (thing->hasElevation())
        m_countFlag.elevation += value;

    if (thing->isOpaque())
        m_countFlag.opaque += value;

    if (thing->hasLight())
        m_countFlag.hasLight += value;

    // Check that the item is opaque, so that it does not draw anything that is less than or equal below it.
    if (thing->isOpaque() && !thing->isOnTop() && !thing->isGround() && !thing->isGroundBorder()) {
        const int commonSize = m_commonItems.size();
        if (m_countFlag.elevation > (sum ? 3 : 2) && commonSize > 2) {
            const ItemPtr& subItem = m_commonItems[1];
            subItem->canDraw(!sum);
        }
        else {
            const ItemPtr& item = thing->static_self_cast<Item>();

            if (!thing->isOnBottom()) {
                for (const ItemPtr& subItem : m_commonItems) {
                    if (subItem != item) {
                        if (subItem->hasElevation() || subItem->isOpaque()) return;

                        if (subItem->getWidth() == 1 && subItem->getHeight() == 1) {
                            subItem->canDraw(!sum);
                        }
                    }
                }
            }

            for (auto it = m_bottomItems.rbegin(); it != m_bottomItems.rend(); ++it) {
                const ItemPtr& subItem = *it;
                if (subItem != item) {
                    if (subItem->hasElevation() || subItem->isOpaque()) return;

                    if (subItem->getWidth() == 1 && subItem->getHeight() == 1) {
                        subItem->canDraw(!sum);
                    }
                }
            }

            for (const ItemPtr& subItem : m_grounds) {
                if (subItem->hasElevation()) return;

                if (subItem->getWidth() == 1 && subItem->getHeight() == 1) {
                    subItem->canDraw(!sum);
                }
            }
        }
    }
}