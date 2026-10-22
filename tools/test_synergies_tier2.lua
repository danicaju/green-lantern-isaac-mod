-- tools/test_synergies_tier2.lua
-- Unit tests for Green Lantern Tier 2 Synergies:
-- Compound Fracture, Fire Mind, Explosivo, Flat Stone, Saturnus, Tech 2, Tech.5, Eye of the Occult, Continuum.

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
    COLLECTIBLE_TECHNOLOGY_2 = 149,
    COLLECTIBLE_TECH_5 = 244,
    COLLECTIBLE_FIRE_MIND = 257,
    COLLECTIBLE_CONTINUUM = 369,
    COLLECTIBLE_EXPLOSIVO = 400,
    COLLECTIBLE_COMPOUND_FRACTURE = 509,
    COLLECTIBLE_FLAT_STONE = 527,
    COLLECTIBLE_EYE_OF_THE_OCCULT = 601,
    COLLECTIBLE_SATURNUS = 606,
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
    POOF02 = 12,
    RED_CANDLE_FLAME = 48,
}
SoundEffect = {
    SOUND_TEARIMPACTS = 24,
    SOUND_FIREDEATH_HISS = 78,
    SOUND_SPLATTER = 67,
}
DamageFlag = { DAMAGE_NO_MODIFIERS = 0 }
ModCallbacks = {
    MC_PRE_TEAR_COLLISION = 1,
    MC_POST_TEAR_UPDATE = 2,
    MC_POST_NEW_ROOM = 3,
    MC_POST_LASER_INIT = 4,
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

loadModule("modules/synergies_tier2.lua")

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
local postNewRoomCb = findCb(ModCallbacks.MC_POST_NEW_ROOM)
local postLaserInitCb = findCb(ModCallbacks.MC_POST_LASER_INIT)

check(preTearCollisionCb ~= nil, "MC_PRE_TEAR_COLLISION registered")
check(postTearUpdateCb ~= nil, "MC_POST_TEAR_UPDATE registered")
check(postNewRoomCb ~= nil, "MC_POST_NEW_ROOM registered")
check(postLaserInitCb ~= nil, "MC_POST_LASER_INIT registered")

-- ===================== TEST 1: COMPOUND FRACTURE =====================
local pCompound = makePlayer({ CollectibleType.COLLECTIBLE_COMPOUND_FRACTURE })
local enemyComp = {
    Position = Vector(150, 100),
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
}
local tearComp = {
    SpawnerEntity = pCompound,
    Position = Vector(145, 100),
    Velocity = Vector(10, 0),
    CollisionDamage = 4.0,
    _data = {},
    GetData = function(s) return s._data end,
}
spawnedEntities = {}
playedSounds = {}
preTearCollisionCb(nil, tearComp, enemyComp, false)
local compoundShards = 0
for _, e in ipairs(spawnedEntities) do
    if e:GetData().isCompoundShard then compoundShards = compoundShards + 1 end
end
check(compoundShards == 3, string.format("Compound Fracture: 3 bone construct shards spawned, got %d", compoundShards))
check(#playedSounds > 0 and playedSounds[1].sfx == SoundEffect.SOUND_TEARIMPACTS, "Compound Fracture: impact sound played")

-- ===================== TEST 2: FIRE MIND =====================
local pFire = makePlayer({ CollectibleType.COLLECTIBLE_FIRE_MIND })
local enemyBurned = false
local enemyFireDmg = 0
local enemyFire = {
    Position = Vector(150, 100),
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
    AddBurn = function() enemyBurned = true end,
    TakeDamage = function(self, dmg) enemyFireDmg = dmg end,
}
local tearFire = {
    SpawnerEntity = pFire,
    Position = Vector(145, 100),
    Velocity = Vector(10, 0),
    CollisionDamage = 4.0,
    _data = {},
    GetData = function(s) return s._data end,
}
spawnedEntities = {}
playedSounds = {}
preTearCollisionCb(nil, tearFire, enemyFire, false)
check(enemyBurned == true, "Fire Mind: enemy received emerald plasma burn")
check(enemyFireDmg > 0, "Fire Mind: enemy took damage from emerald plasma burst")
check(pFire:GetData().ringFlareTimer == 8, "Fire Mind: ring flare triggered")

-- ===================== TEST 3: EXPLOSIVO =====================
local pExp = makePlayer({ CollectibleType.COLLECTIBLE_EXPLOSIVO })
local expDmg = 0
local enemyExp = {
    Position = Vector(150, 100),
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
    TakeDamage = function(self, dmg) expDmg = dmg end,
}
local tearExp = {
    SpawnerEntity = pExp,
    Position = Vector(145, 100),
    Velocity = Vector(10, 0),
    CollisionDamage = 4.0,
    _data = {},
    GetData = function(s) return s._data end,
}
spawnedEntities = {}
playedSounds = {}
preTearCollisionCb(nil, tearExp, enemyExp, false)
check(expDmg > 0, "Explosivo: attached emerald plasma bubble dealt burst damage")
check(pExp:GetData().ringFlareTimer == 6, "Explosivo: ring flare triggered")

-- ===================== TEST 4: FLAT STONE =====================
local pFlat = makePlayer({ CollectibleType.COLLECTIBLE_FLAT_STONE })
local flatSpr = { Color = nil }
local tearFlat = {
    SpawnerEntity = pFlat,
    Position = Vector(100, 100),
    Height = 0, -- Ground bounce
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return flatSpr end,
}
spawnedEntities = {}
postTearUpdateCb(nil, tearFlat)
local flatFx = 0
for _, e in ipairs(spawnedEntities) do
    if e.Type == EntityType.ENTITY_EFFECT then flatFx = flatFx + 1 end
end
check(flatFx > 0, "Flat Stone: spawned emerald ground shockwave on floor bounce")

-- ===================== TEST 5: EYE OF THE OCCULT =====================
local pOccult = makePlayer({ CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT })
local occultSpr = { Color = nil }
local tearOccult = {
    SpawnerEntity = pOccult,
    Position = Vector(100, 100),
    CollisionDamage = 4.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return occultSpr end,
}
postTearUpdateCb(nil, tearOccult)
check(tearOccult:GetData().isGLOccultTear == true, "Eye of the Occult: marked isGLOccultTear")
check(occultSpr.Color ~= nil and occultSpr.Color.G == 1.0, "Eye of the Occult: emerald trail color applied")
check(tearOccult.CollisionDamage == 4.8, string.format("Eye of the Occult: +20%% damage applied (%s)", tostring(tearOccult.CollisionDamage)))

-- ===================== TEST 6: CONTINUUM =====================
local pCont = makePlayer({ CollectibleType.COLLECTIBLE_CONTINUUM })
local contSpr = { Color = nil }
local tearCont = {
    SpawnerEntity = pCont,
    Position = Vector(100, 100),
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return contSpr end,
}
postTearUpdateCb(nil, tearCont)
check(contSpr.Color ~= nil and contSpr.Color.G == 1.0, "Continuum: emerald spatial warp color applied")

-- ===================== TEST 7: SATURNUS =====================
local pSat = makePlayer({ CollectibleType.COLLECTIBLE_SATURNUS })
Isaac.GetPlayer = function(i) return pSat end
spawnedEntities = {}
postNewRoomCb(nil)
local satFx = 0
for _, e in ipairs(spawnedEntities) do
    if e.Type == EntityType.ENTITY_EFFECT then satFx = satFx + 1 end
end
check(satFx > 0, "Saturnus: emerald planetary orbital ring spawned on new room")
check(pSat:GetData().ringFlareTimer == 10, "Saturnus: ring flare triggered")

-- ===================== TEST 8: TECHNOLOGY 2 & TECH.5 =====================
local pTech2 = makePlayer({ CollectibleType.COLLECTIBLE_TECHNOLOGY_2 })
local techSpr = { Color = nil }
local laserTech = {
    SpawnerEntity = pTech2,
    CollisionDamage = 2.0,
    _data = {},
    GetData = function(s) return s._data end,
    GetSprite = function() return techSpr end,
}
postLaserInitCb(nil, laserTech)
check(laserTech:GetData().glTier2LaserInit == true, "Technology 2: laser initialized")
check(techSpr.Color ~= nil and techSpr.Color.G == 1.0, "Technology 2: styled with emerald construct tint")
check(laserTech.CollisionDamage == 2.5, string.format("Technology 2: +25%% construct damage boost applied (%s)", tostring(laserTech.CollisionDamage)))

-- Summary
print(string.format("test_synergies_tier2.lua: %d passed, %d failed", passes, failures))
if failures > 0 then
    os.exit(1)
end
