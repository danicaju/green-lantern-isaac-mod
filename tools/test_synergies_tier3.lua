-- tools/test_synergies_tier3.lua
-- Unit tests for Green Lantern Tier 3 Synergies:
-- Eye of Belial, Little Horn, Euthanasia, Blanket, Gnawed Leaf, Tech Zero, Sinus/Mucor.

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- ===================== STUBS =====================
CollectibleType = {
    COLLECTIBLE_SHOOP_DA_WHOOP = 49,
    COLLECTIBLE_GNAWED_LEAF = 210,
    COLLECTIBLE_TRINITY_SHIELD = 243,
    COLLECTIBLE_HEAD_OF_KRAMPUS = 293,
    COLLECTIBLE_SCATTER_BOMBS = 366,
    COLLECTIBLE_LITTLE_HORN = 408,
    COLLECTIBLE_MEGA_BLAST = 441,
    COLLECTIBLE_EYE_OF_BELIAL = 462,
    COLLECTIBLE_EUTHANASIA = 499,
    COLLECTIBLE_TECH_ZERO = 502,
    COLLECTIBLE_SINUS_INFECTION = 507,
    COLLECTIBLE_BLANKET = 540,
    COLLECTIBLE_NEPTUNUS = 597,
    COLLECTIBLE_MUCORMYCOSIS = 618,
    COLLECTIBLE_REVELATION = 643,
}
EntityType = {
    ENTITY_PLAYER = 1,
    ENTITY_TEAR = 2,
    ENTITY_LASER = 7,
    ENTITY_EFFECT = 1000,
}
TearVariant = { DEFAULT = 0 }
EffectVariant = {
    HALO = 10,
    PUNCH = 88,
}
SoundEffect = {
    SOUND_PUNCH = 70,
    SOUND_TEARIMPACTS = 24,
}
DamageFlag = { DAMAGE_NO_MODIFIERS = 0 }
RoomType = { ROOM_BOSS = 4 }
ModCallbacks = {
    MC_PRE_TEAR_COLLISION = 1,
    MC_POST_ENTITY_KILL = 2,
    MC_POST_NEW_ROOM = 3,
    MC_POST_PLAYER_UPDATE = 4,
    MC_POST_LASER_INIT = 5,
    MC_POST_ENTITY_REMOVE = 6,
    MC_POST_TEAR_UPDATE = 7,
}

Vector = {
    Zero = { X = 0, Y = 0 },
    new = function(x, y)
        local v = { X = x or 0, Y = y or 0 }
        v.Length = function(self) return math.sqrt(self.X * self.X + self.Y * self.Y) end
        v.Normalized = function(self)
            local l = self:Length()
            if l == 0 then return Vector.new(0, 0) end
            return Vector.new(self.X / l, self.Y / l)
        end
        return v
    end,
}
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })

Color = function(r, g, b, a, ro, go, bo)
    return { R = r, G = g, B = b, A = a, RO = ro or 0, GO = go or 0, BO = bo or 0 }
end

local playedSounds = {}
SFXManager = function() return {
    Play = function(self, sfx, vol, frame, loop, pitch)
        table.insert(playedSounds, { sfx = sfx, vol = vol, pitch = pitch })
    end
} end

local spawnedEntities = {}
Isaac = {
    Spawn = function(eType, var, sub, pos, vel, spawner)
        local spr = { Color = nil }
        local ent = {
            Type = eType,
            Variant = var,
            Position = pos,
            Velocity = vel,
            SpawnerEntity = spawner,
            _data = {},
            GetData = function(s) return s._data end,
            GetSprite = function() return spr end,
        }
        table.insert(spawnedEntities, ent)
        return ent
    end,
    GetPlayer = function(i) return nil end,
}
Game = function() return {
    GetFrameCount = function() return 100 end,
    GetNumPlayers = function() return 1 end,
    GetRoom = function() return { GetType = function() return RoomType.ROOM_BOSS end } end,
} end
EntityRef = function(e) return { Entity = e } end

-- ===================== CORE MOCK =====================
local Core = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    IsRingActive = function(p) return p._ringActive ~= false end,
    GetPlayerData = function(p)
        p._data = p._data or {}
        return p._data
    end,
    ApplyRingBeamSprite = function(tear, scale)
        tear._styled = true
        tear._beamScale = scale
    end,
    SetEntityScaleAndColor = function(ent, scale, col)
        ent._scale = scale
        ent._color = col
    end,
}

local function findCb(id)
    for _, c in ipairs(Core.GL._cbs) do
        if c.id == id then return c.fn end
    end
    return nil
end

local function loadModule(path)
    local f = assert(io.open(path, "r"))
    local src = f:read("*a"); f:close()
    src = src:gsub("|", "+")
    return assert(loadstring(src, path))()(Core)
end

loadModule("modules/synergies_tier3.lua")

local function makePlayer(items)
    local itemMap = {}
    for _, id in ipairs(items or {}) do itemMap[id] = true end
    local p = {
        _ringActive = true,
        Damage = 4.0,
        Luck = 10.0,
        Position = Vector(100, 100),
        HasCollectible = function(_, id) return itemMap[id] == true end,
        ToPlayer = function(self) return self end,
        GetData = function(self) return Core.GetPlayerData(self) end,
        GetSprite = function(self) return { Color = nil } end,
        IsInvulnerable = function(self) return self._invulnerable == true end,
        SetShieldTimer = function(self, t) self._shieldTimer = t end,
    }
    p.FireTear = function(self, pos, vel, canEye, noVer, cantTrig)
        local t = {
            Position = pos,
            Velocity = vel,
            CollisionDamage = 0,
            _data = {},
            GetData = function(s) return s._data end,
        }
        table.insert(spawnedEntities, t)
        return t
    end
    return p
end

math.random = function() return 0.01 end

local preTearCollisionCb = findCb(ModCallbacks.MC_PRE_TEAR_COLLISION)
local postEntityKillCb = findCb(ModCallbacks.MC_POST_ENTITY_KILL)
local postNewRoomCb = findCb(ModCallbacks.MC_POST_NEW_ROOM)
local postPlayerUpdateCb = findCb(ModCallbacks.MC_POST_PLAYER_UPDATE)
local postLaserInitCb = findCb(ModCallbacks.MC_POST_LASER_INIT)
local postEntityRemoveCb = findCb(ModCallbacks.MC_POST_ENTITY_REMOVE)
local postTearUpdateCb = findCb(ModCallbacks.MC_POST_TEAR_UPDATE)

check(preTearCollisionCb ~= nil, "MC_PRE_TEAR_COLLISION registered")
check(postEntityKillCb ~= nil, "MC_POST_ENTITY_KILL registered")
check(postNewRoomCb ~= nil, "MC_POST_NEW_ROOM registered")
check(postPlayerUpdateCb ~= nil, "MC_POST_PLAYER_UPDATE registered")
check(postLaserInitCb ~= nil, "MC_POST_LASER_INIT registered")
check(postEntityRemoveCb ~= nil, "MC_POST_ENTITY_REMOVE registered")
check(postTearUpdateCb ~= nil, "MC_POST_TEAR_UPDATE registered")

-- ===================== TEST 1: EYE OF BELIAL =====================
local pBelial = makePlayer({ CollectibleType.COLLECTIBLE_EYE_OF_BELIAL })
local belialSpr = { Color = nil }
local tearBelial = {
    SpawnerEntity = pBelial,
    Position = Vector(100, 100),
    CollisionDamage = 4.0,
    Scale = 1.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return belialSpr end,
}
local enemyBelial = {
    Position = Vector(150, 100),
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
}
preTearCollisionCb(nil, tearBelial, enemyBelial, false)
check(tearBelial:GetData().isBelialEmpowered == true, "Eye of Belial: tear empowered upon piercing")
check(tearBelial.CollisionDamage == 8.0, string.format("Eye of Belial: 2x damage boost applied (%s)", tostring(tearBelial.CollisionDamage)))
check(tearBelial.Scale > 1.0, "Eye of Belial: tear size enlarged")
check(belialSpr.Color ~= nil and belialSpr.Color.G == 1.0, "Eye of Belial: emerald demonic aura applied")

-- ===================== TEST 2: LITTLE HORN =====================
local pHorn = makePlayer({ CollectibleType.COLLECTIBLE_LITTLE_HORN })
local hornDmg = 0
local enemyHorn = {
    Position = Vector(150, 100),
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
    TakeDamage = function(self, dmg) hornDmg = dmg end,
}
local tearHorn = {
    SpawnerEntity = pHorn,
    Position = Vector(145, 100),
    CollisionDamage = 4.0,
    _data = {},
    GetData = function(s) return s._data end,
}
playedSounds = {}
spawnedEntities = {}
preTearCollisionCb(nil, tearHorn, enemyHorn, false)
check(hornDmg == 16.0, string.format("Little Horn: 4x Giant Fist Smash damage dealt (%s)", tostring(hornDmg)))
check(#playedSounds > 0 and playedSounds[1].sfx == SoundEffect.SOUND_PUNCH, "Little Horn: punch impact sound played")
check(pHorn:GetData().ringFlareTimer == 10, "Little Horn: ring flare triggered")

-- ===================== TEST 3: EUTHANASIA =====================
local pEuth = makePlayer({ CollectibleType.COLLECTIBLE_EUTHANASIA })
Isaac.GetPlayer = function(i) return pEuth end
spawnedEntities = {}
playedSounds = {}
local deadEnemy = {
    Position = Vector(300, 300),
    IsActiveEnemy = function() return true end,
}
postEntityKillCb(nil, deadEnemy)
local needles = 0
for _, e in ipairs(spawnedEntities) do
    if e:GetData().isEuthanasiaNeedle then needles = needles + 1 end
end
check(needles == 10, string.format("Euthanasia: 10 radial emerald needle construct shards spawned, got %d", needles))
check(#playedSounds > 0 and playedSounds[1].sfx == SoundEffect.SOUND_TEARIMPACTS, "Euthanasia: needle burst sound played")
check(pEuth:GetData().ringFlareTimer == 8, "Euthanasia: ring flare triggered")

-- ===================== TEST 4: BLANKET =====================
local pBlanket = makePlayer({ CollectibleType.COLLECTIBLE_BLANKET })
Isaac.GetPlayer = function(i) return pBlanket end
spawnedEntities = {}
postNewRoomCb(nil)
local domeFx = 0
for _, e in ipairs(spawnedEntities) do
    if e.Type == EntityType.ENTITY_EFFECT then domeFx = domeFx + 1 end
end
check(domeFx > 0, "Blanket: Emerald Aegis Dome forcefield spawned on boss entry")
check(pBlanket._shieldTimer == 90, "Blanket: protective shield timer set")
check(pBlanket:GetData().ringFlareTimer == 15, "Blanket: ring flare triggered")

-- ===================== TEST 5: GNAWED LEAF =====================
local pLeaf = makePlayer({ CollectibleType.COLLECTIBLE_GNAWED_LEAF })
pLeaf._invulnerable = true
spawnedEntities = {}
postPlayerUpdateCb(nil, pLeaf)
local leafFx = 0
for _, e in ipairs(spawnedEntities) do
    if e.Type == EntityType.ENTITY_EFFECT then leafFx = leafFx + 1 end
end
check(leafFx > 0, "Gnawed Leaf: emerald construct crystal statue aura spawned while invulnerable")

-- ===================== TEST 6: TECH ZERO =====================
local pZero = makePlayer({ CollectibleType.COLLECTIBLE_TECH_ZERO })
local laserSpr = { Color = nil }
local laserZero = {
    SpawnerEntity = pZero,
    CollisionDamage = 3.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return laserSpr end,
}
postLaserInitCb(nil, laserZero)
check(laserSpr.Color ~= nil and laserSpr.Color.G == 1.0, "Tech Zero: laser styled with emerald construct lightning")
check(math.abs(laserZero.CollisionDamage - 3.6) < 0.001, string.format("Tech Zero: +20%% construct electric damage applied (%s)", tostring(laserZero.CollisionDamage)))

-- ===================== TEST 7: MEGA BLAST =====================
local pMega = makePlayer({ CollectibleType.COLLECTIBLE_MEGA_BLAST })
local megaSpr = { Color = nil }
local laserMega = {
    SpawnerEntity = pMega,
    CollisionDamage = 10.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return megaSpr end,
}
postLaserInitCb(nil, laserMega)
check(megaSpr.Color ~= nil and megaSpr.Color.G == 1.0, "Mega Blast: colossal emerald construct laser color applied")
check(laserMega.CollisionDamage == 12.5, string.format("Mega Blast: +25%% damage applied (%s)", tostring(laserMega.CollisionDamage)))

-- ===================== TEST 8: REVELATION =====================
local pRev = makePlayer({ CollectibleType.COLLECTIBLE_REVELATION })
local revSpr = { Color = nil }
local laserRev = {
    SpawnerEntity = pRev,
    CollisionDamage = 5.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return revSpr end,
}
postLaserInitCb(nil, laserRev)
check(revSpr.Color ~= nil and revSpr.Color.G == 1.0, "Revelation: divine emerald willpower beam color applied")
check(laserRev.CollisionDamage == 6.0, string.format("Revelation: +20%% damage applied (%s)", tostring(laserRev.CollisionDamage)))

-- ===================== TEST 9: SHOOP DA WHOOP =====================
local pShoop = makePlayer({ CollectibleType.COLLECTIBLE_SHOOP_DA_WHOOP })
local shoopSpr = { Color = nil }
local laserShoop = {
    SpawnerEntity = pShoop,
    CollisionDamage = 4.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return shoopSpr end,
}
postLaserInitCb(nil, laserShoop)
check(shoopSpr.Color ~= nil and shoopSpr.Color.G == 1.0, "Shoop da Whoop: emerald hand construct beam color applied")
check(laserShoop.CollisionDamage == 5.0, string.format("Shoop da Whoop: +25%% damage applied (%s)", tostring(laserShoop.CollisionDamage)))

-- ===================== TEST 10: SCATTER BOMBS =====================
local pScatter = makePlayer({ CollectibleType.COLLECTIBLE_SCATTER_BOMBS })
spawnedEntities = {}
local bombScatter = {
    Type = EntityType.ENTITY_BOMB,
    Position = Vector(200, 200),
    SpawnerEntity = pScatter,
    IsFetus = true,
    GetData = function() return { isGLBomb = true } end,
}
postEntityRemoveCb(nil, bombScatter)
local clusterShards = 0
for _, e in ipairs(spawnedEntities) do
    if e:GetData().isScatterShard then clusterShards = clusterShards + 1 end
end
check(clusterShards == 3, string.format("Scatter Bombs: 3 emerald cluster shards spawned, got %d", clusterShards))

-- ===================== TEST 11: NEPTUNUS =====================
local pNep = makePlayer({ CollectibleType.COLLECTIBLE_NEPTUNUS })
local nepSpr = { Color = nil }
local tearNep = {
    SpawnerEntity = pNep,
    Position = Vector(100, 100),
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return nepSpr end,
}
postTearUpdateCb(nil, tearNep)
check(tearNep:GetData().isGLNeptunusStyled == true, "Neptunus: marked isGLNeptunusStyled")
check(nepSpr.Color ~= nil and nepSpr.Color.G == 1.0, "Neptunus: styled emerald")

-- Summary
print(string.format("test_synergies_tier3.lua: %d passed, %d failed", passes, failures))
if failures > 0 then
    os.exit(1)
end
