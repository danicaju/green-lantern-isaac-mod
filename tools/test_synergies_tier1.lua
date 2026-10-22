-- tools/test_synergies_tier1.lua
-- Unit tests for Green Lantern Tier 1 Synergies:
-- Knockout Drops, Sad Bombs, Holy Light, Trisagion, Uranus, Terra, Ocular Rift, Anti-Gravity, Spirit Sword, C-Section.

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
    COLLECTIBLE_SAD_BOMBS = 220,
    COLLECTIBLE_ANTI_GRAVITY = 222,
    COLLECTIBLE_HOLY_LIGHT = 374,
    COLLECTIBLE_TRISAGION = 533,
    COLLECTIBLE_KNOCKOUT_DROPS = 577,
    COLLECTIBLE_OCULAR_RIFT = 578,
    COLLECTIBLE_SPIRIT_SWORD = 579,
    COLLECTIBLE_URANUS = 598,
    COLLECTIBLE_TERRA = 602,
    COLLECTIBLE_C_SECTION = 678,
}
EntityType = {
    ENTITY_PLAYER = 1,
    ENTITY_TEAR = 2,
    ENTITY_BOMB = 4,
    ENTITY_EFFECT = 1000,
}
TearVariant = { DEFAULT = 0 }
EffectVariant = {
    HALO = 10,
    WATER_SPLASH = 20,
    CRACK_THE_SKY = 39,
    PUNCH = 88,
    RIFT = 110,
}
SoundEffect = {
    SOUND_PUNCH = 70,
    SOUND_SUPERHOLY = 168,
    SOUND_GLASS_BREAK = 162,
    SOUND_ROCK_CRUMBLE = 143,
}
DamageFlag = { DAMAGE_NO_MODIFIERS = 0, DAMAGE_LASER = 1 }
ModCallbacks = {
    MC_PRE_TEAR_COLLISION = 1,
    MC_POST_TEAR_UPDATE = 2,
    MC_POST_ENTITY_REMOVE = 3,
    MC_POST_ENTITY_KILL = 4,
    MC_POST_KNIFE_UPDATE = 5,
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

function Core.SpawnGLConstructTear(player, pos, vel, damage, scale, flag)
    local tear = nil
    if player and player.FireTear then
        tear = player:FireTear(pos, vel, false, true, false)
    elseif Isaac and Isaac.Spawn then
        local tVar = (TearVariant and TearVariant.DEFAULT) or 0
        tear = Isaac.Spawn(EntityType.ENTITY_TEAR, tVar, 0, pos, vel, player)
    end
    if tear then
        tear.CollisionDamage = damage
        local sd = tear:GetData()
        sd.isGLRingBeam = true
        if flag then sd[flag] = true end
        Core.ApplyRingBeamSprite(tear, scale)
    end
    return tear
end

Core.GL_EMERALD_COLOR  = Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25)
Core.GL_EMERALD_BRIGHT = Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30)
Core.GL_EMERALD_DIM    = Color(0.1, 1.0, 0.38, 1, 0.15, 0.85, 0.25)

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

loadModule("modules/synergies_tier1.lua")

local function makePlayer(items)
    local itemMap = {}
    for _, id in ipairs(items or {}) do itemMap[id] = true end
    local p = {
        _ringActive = true,
        Damage = 4.0,
        Luck = 10.0, -- high luck to guarantee procs in test
        Position = Vector(100, 100),
        HasCollectible = function(_, id) return itemMap[id] == true end,
        ToPlayer = function(self) return self end,
        GetData = function(self) return Core.GetPlayerData(self) end,
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
local postTearUpdateCb = findCb(ModCallbacks.MC_POST_TEAR_UPDATE)
local postEntityRemoveCb = findCb(ModCallbacks.MC_POST_ENTITY_REMOVE)
local postEntityKillCb = findCb(ModCallbacks.MC_POST_ENTITY_KILL)
local postKnifeUpdateCb = findCb(ModCallbacks.MC_POST_KNIFE_UPDATE)

check(preTearCollisionCb ~= nil, "MC_PRE_TEAR_COLLISION registered")
check(postTearUpdateCb ~= nil, "MC_POST_TEAR_UPDATE registered")
check(postEntityRemoveCb ~= nil, "MC_POST_ENTITY_REMOVE registered")
check(postEntityKillCb ~= nil, "MC_POST_ENTITY_KILL registered")
check(postKnifeUpdateCb ~= nil, "MC_POST_KNIFE_UPDATE registered")

-- ===================== TEST 1: KNOCKOUT DROPS =====================
local pKnockout = makePlayer({ CollectibleType.COLLECTIBLE_KNOCKOUT_DROPS })
local enemyDamaged = 0
local enemyConfused = false
local enemy1 = {
    Position = Vector(150, 100),
    Velocity = Vector(0, 0),
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
    TakeDamage = function(self, dmg) enemyDamaged = dmg end,
    AddConfusion = function() enemyConfused = true end,
}
local tearKnockout = {
    SpawnerEntity = pKnockout,
    Position = Vector(145, 100),
    Velocity = Vector(10, 0),
}
playedSounds = {}
spawnedEntities = {}
preTearCollisionCb(nil, tearKnockout, enemy1, false)
check(enemyDamaged > 0, "Knockout Drops: enemy took damage from Boxing Glove construct")
check(enemyConfused == true, "Knockout Drops: enemy received concussion/confusion")
check(enemy1.Velocity.X > 0, "Knockout Drops: enemy received heavy knockback")
check(#playedSounds > 0 and playedSounds[1].sfx == SoundEffect.SOUND_PUNCH, "Knockout Drops: punch sound played")
check(pKnockout:GetData().ringFlareTimer == 8, "Knockout Drops: ring flare triggered")

-- ===================== TEST 2: HOLY LIGHT =====================
local pHoly = makePlayer({ CollectibleType.COLLECTIBLE_HOLY_LIGHT })
local holyEnemyDamaged = 0
local enemyHoly = {
    Position = Vector(200, 100),
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
    TakeDamage = function(self, dmg) holyEnemyDamaged = dmg end,
}
local tearHoly = {
    SpawnerEntity = pHoly,
    Position = Vector(195, 100),
    Velocity = Vector(10, 0),
}
playedSounds = {}
spawnedEntities = {}
preTearCollisionCb(nil, tearHoly, enemyHoly, false)
check(holyEnemyDamaged == 16.0, string.format("Holy Light: orbital laser column dealt 4x damage (%s)", tostring(holyEnemyDamaged)))
check(#playedSounds > 0 and playedSounds[1].sfx == SoundEffect.SOUND_SUPERHOLY, "Holy Light: super holy sound played")
check(pHoly:GetData().ringFlareTimer == 10, "Holy Light: ring flare triggered")

-- ===================== TEST 3: SAD BOMBS =====================
local pSad = makePlayer({ CollectibleType.COLLECTIBLE_SAD_BOMBS })
Isaac.GetPlayer = function(i) return pSad end
spawnedEntities = {}
local bombSad = {
    Type = EntityType.ENTITY_BOMB,
    Position = Vector(300, 300),
    SpawnerEntity = pSad,
    IsFetus = true,
    GetData = function() return { isGLBomb = true } end,
}
postEntityRemoveCb(nil, bombSad)
local radialShards = 0
for _, e in ipairs(spawnedEntities) do
    if e:GetData().isSadBombShard then radialShards = radialShards + 1 end
end
check(radialShards == 10, string.format("Sad Bombs: 10 radial emerald construct tears spawned on explosion, got %d", radialShards))
check(pSad:GetData().ringFlareTimer == 10, "Sad Bombs: ring flare triggered")

-- ===================== TEST 4: TRISAGION =====================
local pTris = makePlayer({ CollectibleType.COLLECTIBLE_TRISAGION })
local trisSpr = { Color = nil }
local tearTris = {
    SpawnerEntity = pTris,
    Position = Vector(100, 100),
    CollisionDamage = 4.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return trisSpr end,
}
spawnedEntities = {}
postTearUpdateCb(nil, tearTris)
check(tearTris:GetData().isGLTrisagion == true, "Trisagion: tear marked isGLTrisagion")
check(trisSpr.Color ~= nil and trisSpr.Color.G == 1.0, "Trisagion: tear styled emerald")
check(tearTris.CollisionDamage == 5.0, string.format("Trisagion: +25%% damage bonus applied (%s)", tostring(tearTris.CollisionDamage)))

-- ===================== TEST 5: URANUS =====================
local pUranus = makePlayer({ CollectibleType.COLLECTIBLE_URANUS })
Isaac.GetPlayer = function(i) return pUranus end
spawnedEntities = {}
playedSounds = {}
local enemyDead = {
    Position = Vector(400, 400),
    IsActiveEnemy = function() return true end,
}
postEntityKillCb(nil, enemyDead)
local crystalShards = 0
for _, e in ipairs(spawnedEntities) do
    if e:GetData().isUranusShard then crystalShards = crystalShards + 1 end
end
check(crystalShards == 6, string.format("Uranus: 6 construct shards spawned on crystalline enemy shatter, got %d", crystalShards))
check(#playedSounds > 0 and playedSounds[1].sfx == SoundEffect.SOUND_GLASS_BREAK, "Uranus: glass shatter sound played")

-- ===================== TEST 6: TERRA =====================
local pTerra = makePlayer({ CollectibleType.COLLECTIBLE_TERRA })
local terraSpr = { Color = nil }
local tearTerra = {
    SpawnerEntity = pTerra,
    Position = Vector(100, 100),
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return terraSpr end,
}
postTearUpdateCb(nil, tearTerra)
check(terraSpr.Color ~= nil and terraSpr.Color.GO == 0.70, "Terra: deep jade construct tint applied")

-- ===================== TEST 7: ANTI-GRAVITY =====================
local pAnti = makePlayer({ CollectibleType.COLLECTIBLE_ANTI_GRAVITY })
local antiSpr = { Color = nil }
local tearAnti = {
    SpawnerEntity = pAnti,
    Position = Vector(100, 100),
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return antiSpr end,
}
postTearUpdateCb(nil, tearAnti)
check(antiSpr.Color ~= nil and antiSpr.Color.G == 1.0, "Anti-Gravity: pulsating emerald construct node tint applied")

-- ===================== TEST 8: C-SECTION =====================
local pCS = makePlayer({ CollectibleType.COLLECTIBLE_C_SECTION })
local csSpr = { Color = nil }
local tearCS = {
    SpawnerEntity = pCS,
    Position = Vector(100, 100),
    CollisionDamage = 10.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return csSpr end,
}
postTearUpdateCb(nil, tearCS)
check(tearCS:GetData().isGLCSection == true, "C-Section: marked isGLCSection")
check(csSpr.Color ~= nil and csSpr.Color.G == 1.0, "C-Section: emerald aura applied")
check(tearCS.CollisionDamage == 12.0, string.format("C-Section: +20%% damage applied (%s)", tostring(tearCS.CollisionDamage)))

-- ===================== TEST 9: SPIRIT SWORD =====================
local pSword = makePlayer({ CollectibleType.COLLECTIBLE_SPIRIT_SWORD })
local swordSpr = { Color = nil }
local swordKnife = {
    SpawnerEntity = pSword,
    GetSprite = function() return swordSpr end,
}
postKnifeUpdateCb(nil, swordKnife)
check(swordSpr.Color ~= nil and swordSpr.Color.G == 1.0, "Spirit Sword: emerald blade construct color applied")
check(pSword:GetData().ringFlareTimer == 5, "Spirit Sword: ring flare triggered")

-- Summary
print(string.format("test_synergies_tier1.lua: %d passed, %d failed", passes, failures))
if failures > 0 then
    os.exit(1)
end
