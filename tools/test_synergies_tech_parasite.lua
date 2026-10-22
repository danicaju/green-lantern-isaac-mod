-- tools/test_synergies_tech_parasite.lua
-- Unit tests for Tech X lockout, Technology hard-light styling, Parasite/Cricket construct refraction, and normal bomb protection.

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
    COLLECTIBLE_MOMS_KNIFE = 114,
    COLLECTIBLE_LUDOVICO_TECHNIQUE = 316,
    COLLECTIBLE_SPIRIT_SWORD = 579,
    COLLECTIBLE_TECH_X = 395,
    COLLECTIBLE_TECHNOLOGY = 68,
    COLLECTIBLE_BRIMSTONE = 118,
    COLLECTIBLE_CHOCOLATE_MILK = 69,
    COLLECTIBLE_CURSED_EYE = 315,
    COLLECTIBLE_MONSTROS_LUNG = 229,
    COLLECTIBLE_PARASITE = 104,
    COLLECTIBLE_CRICKETS_BODY = 224,
    COLLECTIBLE_EPIC_FETUS = 168,
    COLLECTIBLE_DR_FETUS = 52,
}
BombVariant = {
    BOMB_NORMAL = 0,
    BOMB_ROCKET = 19,
    BOMB_GIGA_ROCKET = 20,
}
EntityType = {
    ENTITY_PLAYER = 1,
    ENTITY_TEAR = 2,
    ENTITY_BOMB = 4,
    ENTITY_EFFECT = 1000,
}
TearVariant = { DEFAULT = 0 }
TearFlags = {
    TEAR_SPECTRAL = 1,
    TEAR_PIERCING = 2,
    TEAR_FEAR = 4,
}
EffectVariant = { HALO = 10, WATER_SPLASH = 20 }
SoundEffect = { SOUND_TEARIMPACTS = 1 }
CacheFlag = { CACHE_DAMAGE = 8 }
EntityFlag = { FLAG_FEAR = 1 }
TearVariant = { DEFAULT = 0 }
ModCallbacks = {
    MC_POST_LASER_INIT = 1,
    MC_POST_LASER_UPDATE = 2,
    MC_POST_KNIFE_UPDATE = 3,
    MC_POST_TEAR_UPDATE = 4,
    MC_PRE_TEAR_COLLISION = 5,
    MC_POST_BOMB_INIT = 6,
    MC_POST_BOMB_UPDATE = 7,
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
SFXManager = function() return { Play = function() end } end
Game = function() return {
    GetFrameCount = function() return 100 end,
    GetRoom = function() return { GetClampedPosition = function(_, p) return p end } end,
    GetNumPlayers = function() return 1 end,
    GetRoomEntities = function() return {} end,
} end
spawnedTears = {}
Isaac = {
    GetPlayer = function() return nil end,
    GetRoomEntities = function() return {} end,
    Spawn = function(etype, variant, subtype, pos, vel, spawner)
        if etype ~= EntityType.ENTITY_TEAR then return nil end
        local t = {
            Type = etype,
            Variant = variant,
            SubType = subtype,
            Position = pos,
            Velocity = vel,
            SpawnerEntity = spawner,
            CollisionDamage = 0,
            Scale = 1.0,
            TearFlags = 0,
            _data = {},
            GetData = function(self) return self._data end,
            ToTear = function(self) return self end,
        }
        table.insert(spawnedTears, t)
        return t
    end,
}

-- ===================== CORE MOCK =====================
local Core = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    IsRingActive = function(p) return p._ringActive ~= false end,
    IsHalJordan = function(p) return p._isHal == true end,
    IsTaintedHal = function(p) return p._isTHal == true end,
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
    WILLPOWER_MAX = 100,
    TAINTED_FEAR_CHANCE = 0.25,
    GL_EMERALD_COLOR  = Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25),
    GL_EMERALD_BRIGHT = Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30),
    GL_EMERALD_DIM    = Color(0.1, 1.0, 0.38, 1, 0.15, 0.85, 0.25),
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

-- Load modules
loadModule("modules/beam_math.lua")
loadModule("modules/beam_synergies.lua")
loadModule("modules/synergies_fetus.lua")

-- ===================== TEST 1: CONTINUOUS BEAM OVERRIDES =====================
local function makePlayer(items)
    local itemMap = {}
    for _, id in ipairs(items or {}) do itemMap[id] = true end
    return {
        _ringActive = true,
        Damage = 3.5,
        Position = Vector(100, 100),
        HasCollectible = function(_, id) return itemMap[id] == true end,
        ToPlayer = function(self) return self end,
    }
end

local pBase = makePlayer({})
check(Core.CanUseContinuousBeam(pBase) == true, "Base player can use continuous beam")

local pTechX = makePlayer({ CollectibleType.COLLECTIBLE_TECH_X })
check(Core.CanUseContinuousBeam(pTechX) == false, "Tech X locks out continuous beam (prevents dual-firing during charge)")

local pTech1 = makePlayer({ CollectibleType.COLLECTIBLE_TECHNOLOGY })
check(Core.CanUseContinuousBeam(pTech1) == false, "Technology locks out continuous beam (uses emerald tech laser)")

local pBrim = makePlayer({ CollectibleType.COLLECTIBLE_BRIMSTONE })
check(Core.CanUseContinuousBeam(pBrim) == false, "Brimstone locks out continuous beam")

local pChoc = makePlayer({ CollectibleType.COLLECTIBLE_CHOCOLATE_MILK })
check(Core.CanUseContinuousBeam(pChoc) == false, "Chocolate Milk locks out continuous beam")

local pCursed = makePlayer({ CollectibleType.COLLECTIBLE_CURSED_EYE })
check(Core.CanUseContinuousBeam(pCursed) == false, "Cursed Eye locks out continuous beam")

local pMonstro = makePlayer({ CollectibleType.COLLECTIBLE_MONSTROS_LUNG })
check(Core.CanUseContinuousBeam(pMonstro) == false, "Monstro's Lung locks out continuous beam")

local pEpic = makePlayer({ CollectibleType.COLLECTIBLE_EPIC_FETUS })
check(Core.CanUseContinuousBeam(pEpic) == true, "Epic Fetus retains continuous beam orbital strike ability")

-- ===================== TEST 2: TECHNOLOGY 1 LASER STYLING =====================
local laserInitCb = findCb(ModCallbacks.MC_POST_LASER_INIT)
check(laserInitCb ~= nil, "MC_POST_LASER_INIT registered")

local techLaserSpr = { Color = nil }
local techLaser = {
    SpawnerEntity = pTech1,
    CollisionDamage = 10,
    DepthOffset = 0,
    TearFlags = 0,
    Position = Vector(100, 100),
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return techLaserSpr end,
    IsCircle = function() return false end,
}
laserInitCb(nil, techLaser)
check(techLaser:GetData().isGLTechLaser == true, "Technology laser marked isGLTechLaser")
check(techLaserSpr.Color.G == 1.0 and techLaserSpr.Color.GO == 0.95, "Technology laser styled with radiant emerald tint")
check(math.abs(techLaser.CollisionDamage - 13.0) < 0.01, "Technology laser given +30% construct damage bonus")

-- ===================== TEST 3: TECH X EMERALD CONSTRUCT RING =====================
local techXLaserSpr = { Color = nil }
local techXLaser = {
    SpawnerEntity = pTechX,
    CollisionDamage = 10,
    DepthOffset = 0,
    TearFlags = 0,
    Position = Vector(100, 100),
    Radius = 32,
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return techXLaserSpr end,
    IsCircle = function() return true end,
}
laserInitCb(nil, techXLaser)
check(techXLaser:GetData().isGLTechX == true, "Tech X ring marked isGLTechX")
check(techXLaserSpr.Color.G == 1.0, "Tech X ring styled emerald")
check(math.abs(techXLaser.CollisionDamage - 12.5) < 0.01, "Tech X ring given +25% construct damage bonus")

-- ===================== TEST 4: THE PARASITE TAP REFRACTION SHARDS =====================
local preTearCollisionCb = findCb(ModCallbacks.MC_PRE_TEAR_COLLISION)
check(preTearCollisionCb ~= nil, "MC_PRE_TEAR_COLLISION registered")

local pParasite = makePlayer({ CollectibleType.COLLECTIBLE_PARASITE })
spawnedTears = {}

local mainTear = {
    SpawnerEntity = pParasite,
    Position = Vector(150, 100),
    Velocity = Vector(10, 0), -- Moving right
    CollisionDamage = 8.0,
    _data = { isGLRingBeam = true },
    GetData = function(self) return self._data end,
}
local enemy = {
    Index = 1,
    Position = Vector(160, 100),
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
    GetData = function() return {} end,
}

preTearCollisionCb(nil, mainTear, enemy, false)
check(#spawnedTears == 2, string.format("The Parasite spawned 2 split tears on enemy hit, spawned %d", #spawnedTears))
if #spawnedTears == 2 then
    check(spawnedTears[1]._styled == true, "Parasite split tear 1 styled with ring beam sprite")
    check(spawnedTears[2]._styled == true, "Parasite split tear 2 styled with ring beam sprite")
    check(spawnedTears[1].CollisionDamage == 4.0, "Parasite split tear deals 50% damage")
    -- Moving right (10, 0) should split to perpendicular (+-90 deg)
    check(math.abs(spawnedTears[1].Velocity.X) < 0.01 and math.abs(spawnedTears[2].Velocity.X) < 0.01, "Parasite shards shoot perpendicular (Y axis)")
end

-- ===================== TEST 5: CRICKET'S BODY TAP REFRACTION SHARDS =====================
local pCricket = makePlayer({ CollectibleType.COLLECTIBLE_CRICKETS_BODY })
spawnedTears = {}
local cricketTear = {
    SpawnerEntity = pCricket,
    Position = Vector(150, 100),
    Velocity = Vector(10, 0),
    CollisionDamage = 6.0,
    _data = { isGLRingBeam = true },
    GetData = function(self) return self._data end,
}
preTearCollisionCb(nil, cricketTear, enemy, false)
check(#spawnedTears == 4, string.format("Cricket's Body spawned 4 split tears on hit, spawned %d", #spawnedTears))

-- ===================== TEST 6: CONTINUOUS BEAM PARASITE REFRACTION =====================
spawnedTears = {}
check(Core.OnContinuousBeamHitEnemy ~= nil, "Core.OnContinuousBeamHitEnemy defined")
Core.OnContinuousBeamHitEnemy(pParasite, enemy, Vector(160, 100), 2.0, Vector(1, 0))
check(#spawnedTears == 2, string.format("Continuous beam with Parasite refracts 2 construct shards, spawned %d", #spawnedTears))

-- ===================== TEST 7: NORMAL BOMBS ARE NOT GREEN =====================
local bombInitCb = findCb(ModCallbacks.MC_POST_BOMB_INIT)
check(bombInitCb ~= nil, "MC_POST_BOMB_INIT registered")

local pHal = makePlayer({})
pHal._isHal = true
Isaac.GetPlayer = function(i) return pHal end
local normalBombSpr = { Color = nil }
local normalBomb = {
    Type = EntityType.ENTITY_BOMB,
    Variant = BombVariant.BOMB_NORMAL,
    SpawnerEntity = pHal,
    IsFetus = false, -- Placed bomb via E key
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return normalBombSpr end,
}
bombInitCb(nil, normalBomb)
check(normalBomb:GetData().isGLBomb == nil, "Normal bomb placed by Hal Jordan is NOT marked isGLBomb")
check(normalBombSpr.Color == nil, "Normal bomb placed by Hal Jordan is NOT tinted green (remains 100% vanilla)")

-- Summary
print(string.format("test_synergies_tech_parasite.lua: %d passed, %d failed", passes, failures))
if failures > 0 then
    os.exit(1)
end
