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

#ifndef TILE_H
#define TILE_H

#include "declarations.h"
#include "mapview.h"
#include "effect.h"
#include "creature.h"
#include "item.h"
#include <framework/luaengine/luaobject.h>

enum tileflags_t : uint32
{
    TILESTATE_NONE = 0,
    TILESTATE_PROTECTIONZONE = 1 << 0,
    TILESTATE_TRASHED = 1 << 1,
    TILESTATE_OPTIONALZONE = 1 << 2,
    TILESTATE_NOLOGOUT = 1 << 3,
    TILESTATE_HARDCOREZONE = 1 << 4,
    TILESTATE_REFRESH = 1 << 5,

    // internal usage
    TILESTATE_HOUSE = 1 << 6,
    TILESTATE_TELEPORT = 1 << 17,
    TILESTATE_MAGICFIELD = 1 << 18,
    TILESTATE_MAILBOX = 1 << 19,
    TILESTATE_TRASHHOLDER = 1 << 20,
    TILESTATE_BED = 1 << 21,
    TILESTATE_DEPOT = 1 << 22,
    TILESTATE_TRANSLUECENT_LIGHT = 1 << 23,

    TILESTATE_LAST = 1 << 24
};

class Tile : public LuaObject
{
public:
    enum {
        MAX_THINGS = 10
    };

    Tile(const Position& position);

    void draw(const Point& dest, float scaleFactor, LightView* lightView = nullptr);

public:
    void clean();

    void addWalkingCreature(const CreaturePtr& creature);
    void removeWalkingCreature(const CreaturePtr& creature);

    void addThing(const ThingPtr& thing, int stackPos);
    bool removeThing(ThingPtr thing);
    ThingPtr getThing(int stackPos);
    EffectPtr getEffect(uint16 id);
    bool hasThing(const ThingPtr& thing);
    int getThingStackPos(const ThingPtr& thing);
    ThingPtr getTopThing();

    ThingPtr getTopLookThing();
    ThingPtr getTopUseThing();
    CreaturePtr getTopCreature();
    ThingPtr getTopMoveThing();
    ThingPtr getTopMultiUseThing();

    const Position& getPosition() { return m_position; }
    int getDrawElevation() { return m_drawElevation; }
    std::vector<ItemPtr> getItems();
    std::vector<CreaturePtr> getWalkingCreatures() { return m_walkingCreatures; }
    std::vector<ThingPtr> getThings() { return m_things; }
    std::vector<CreaturePtr> Tile::getCreatures() { return m_creatures; }
    ItemPtr getGround();
    int getGroundSpeed();
    uint8 getMinimapColorByte();
    int getThingCount() { return m_things.size() + m_effects.size(); }
    bool isPathable();
    bool isWalkable(bool ignoreCreatures = false);
    bool isFullGround();
    bool isFullyOpaque();
    bool isSingleDimension();
    bool isLookPossible();
    bool isClickable();
    bool isEmpty();
    bool isDrawable();
    bool hasTranslucentLight() { return m_flags & TILESTATE_TRANSLUECENT_LIGHT; }
    bool mustHookSouth();
    bool mustHookEast();
    bool hasCreature();
    bool limitsFloorsView(bool isFreeView = false);
    bool canErase();
    int getElevation() const;
    bool hasElevation(int elevation = 1);
    void overwriteMinimapColor(uint8 color) { m_minimapColor = color; }

    void remFlag(uint32 flag) { m_flags &= ~flag; }
    void setFlag(uint32 flag) { m_flags |= flag; }
    void setFlags(uint32 flags) { m_flags = flags; }
    bool hasFlag(uint32 flag) { return (m_flags & flag) == flag; }
    uint32 getFlags() { return m_flags; }

    void setHouseId(uint32 hid) { m_houseId = hid; }
    uint32 getHouseId() { return m_houseId; }
    bool isHouseTile() { return m_houseId != 0 && (m_flags & TILESTATE_HOUSE) == TILESTATE_HOUSE; }

    void select() { m_selected = true; }
    void unselect() { m_selected = false; }
    bool isSelected() { return m_selected; }

    TilePtr asTile() { return static_self_cast<Tile>(); }

    bool hasDisplacement() { return m_countFlag.hasDisplacement > 0; }
    bool hasLight() { return m_countFlag.hasLight > 0; }
    void analyzeThing(const ThingPtr& thing, bool sum);

    bool hasGroundsToDraw() const { return !m_grounds.empty(); }
    bool hasBottomToDraw() const { return !m_bottomItems.empty() || !m_commonItems.empty() || !m_creatures.empty() || !m_walkingCreatures.empty(); }
    bool hasTopToDraw() const { return !m_topItems.empty() || !m_effects.empty(); }

    void drawGround(const Point& dest, float scaleFactor, LightView* lightView = nullptr);
    void drawBottom(const Point& dest, float scaleFactor, LightView* lightView = nullptr);
    void drawTop(const Point& dest, float scaleFactor, LightView* lightView);

private:
    void checkTranslucentLight();

    Position m_position;
    uint8 m_drawElevation;
    uint8 m_minimapColor;
    uint32 m_flags, m_houseId;

    stdext::boolean<false> m_selected;

    stdext::packed_vector<CreaturePtr> m_walkingCreatures;
    stdext::packed_vector<ThingPtr> m_things;

    std::vector<EffectPtr> m_effects;
    std::vector<ItemPtr> m_grounds;
    std::vector<ItemPtr> m_topItems;
    std::vector<ItemPtr> m_commonItems;
    std::vector<ItemPtr> m_bottomItems;
    std::vector<CreaturePtr> m_creatures;

    struct CountFlag {
        int fullGround = 0;
        int notWalkable = 0;
        int notPathable = 0;
        int notSingleDimension = 0;
        int blockProjectile = 0;
        int mustHookEast = 0;
        int mustHookSouth = 0;
        int totalElevation = 0;
        int hasDisplacement = 0;
        int isNotPathable = 0;
        int elevation = 0;
        int opaque = 0;
        int hasLight = 0;
    };

    CountFlag m_countFlag;

    CreaturePtr m_localPlayer;
};

#endif
