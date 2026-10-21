-- tools/test_beam_lifetime_and_splits.lua
-- TDD: beam GL tiene vida maxima y tope de beams vivos; splits Parasite/Cricket
-- visibles (spawn directo, no FireTear); Neptunus bloquea rayo continuo.

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
function RegisterMod(name, ver)
    return {
        Name = name,
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    }
end

Vector = {}
local VectorMT = { __index = Vector }
function Vector.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, VectorMT) end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
    local l = self:Length()
    if l == 0 then return Vector.new(0, 0) end
    return Vector.new(self.X / l, self.Y / l)
end
function Vector:GetAngleDegrees() return math.deg(math.atan2(self.Y, self.X)) end
function VectorMT.__add(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end
function VectorMT.__sub(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
function VectorMT.__mul(a, b)
    if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end
function VectorMT.__div(a, b)
    if type(b) == "number" then return Vector.new(a.X / b, a.Y / b) end
    return Vector.new(a.X / b.X, a.Y / b.Y)
end
Vector.Zero = Vector.new(0, 0)

Color = function(r, g, b, a, ro, go, bo)
    return { R = r, G = g, B = b, A = a, RO = ro or 0, GO = go or 0, BO = bo or 0 }
end

Game = function()
    return {
        GetFrameCount = function() return _G._testFrame or 0 end,
        GetRoom = function()
            return {
                GetClampedPosition = function(_, p) return p end,
                IsPositionInRoom = function() return true end,
            }
        end,
        GetNumPlayers = function() return 1 end,
        GetRoomEntities = function() return {} end,
        GetLevel = function() return { GetCurrentRoomIndex = function() return 0 end } end,
    }
end

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
    COLLECTIBLE_NEPTUNUS = 597,
    COLLECTIBLE_PARASITE = 104,
    COLLECTIBLE_CRICKETS_BODY = 224,
}
TearFlags = {
    TEAR_SPECTRAL = 1,
    TEAR_PIERCING = 2,
    TEAR_FEAR = 4,
    TEAR_HOMING = 8,
    TEAR_ORBIT = 16,
    TEAR_BOOMERANG = 32,
    TEAR_SPIRAL = 64,
    TEAR_WIGGLE = 128,
    TEAR_TRACTOR_BEAM = 256,
}
EntityType = { ENTITY_TEAR = 2, ENTITY_EFFECT = 1000 }
EffectVariant = { WATER_SPLASH = 20, HALO = 10 }
SoundEffect = { SOUND_TEARIMPACTS = 1 }
CacheFlag = { CACHE_DAMAGE = 8 }
ModCallbacks = {
    MC_POST_FIRE_TEAR = 1,
    MC_POST_TEAR_UPDATE = 2,
    MC_PRE_TEAR_COLLISION = 3,
    MC_POST_TEAR_RENDER = 4,
    MC_POST_LASER_INIT = 5,
    MC_POST_LASER_UPDATE = 6,
    MC_POST_KNIFE_UPDATE = 7,
    MC_USE_ITEM = 8,
    MC_ENTITY_TAKE_DMG = 9,
}
SFXManager = function() return { Play = function() end } end

local spawnedEntities = {}
_G._roomEntities = {}
Isaac = {
    Spawn = function(etype, variant, subtype, pos, vel, spawner)
        local ent = {
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
            GetSprite = function()
                return {
                    Color = Color(1, 1, 1, 1, 0, 0, 0),
                    Load = function() end,
                    Play = function() end,
                    SetFrame = function() end,
                    GetAnimation = function() return "Idle" end,
                    Scale = Vector(1, 1),
                    Rotation = 0,
                }
            end,
            ToTear = function(self) return self end,
            Remove = function() self._removed = true end,
        }
        table.insert(spawnedEntities, ent)
        return ent
    end,
    GetRoomEntities = function() return _G._roomEntities end,
}

-- ===================== CORE =====================
local Core = dofile("modules/core.lua")

-- Mocks adicionales de Core que necesitan los modulos
Core.IsRingActive = function(p) return p._ringActive ~= false end
Core.IsHalJordan = function(p) return p._isHal == true end
Core.IsTaintedHal = function(p) return p._isTHal == true end
Core.IsAimingUp = function() return false end
Core.IsWallAtPos = function() return false end
Core.HasTearFlag = function(flags, flag)
    return math.floor((flags or 0) / (flag or 1)) % 2 == 1
end
Core.HasTractorBeam = function() return false end
Core.GetTractorBeamDirection = function(_, dir) return dir end
Core.GetRingHandOffset = function() return Vector(0, 0) end
Core.GetRingBeamTearSpawnOffset = function() return Vector(0, 0) end
Core.GetMaxWillpower = function() return Core.WILLPOWER_MAX end
Core.ApplyRingBeamSprite = function(tear, scale)
    tear._styled = true
    tear._beamScale = scale
    local td = tear:GetData()
    td.isGLRingBeam = true
    td.glBeamScale = scale
    if tear.Velocity and tear.Velocity:Length() > 0.1 then
        td.glBeamVel = Vector(tear.Velocity.X, tear.Velocity.Y)
    end
end
Core.SetEntityScaleAndColor = function(ent, scale, col)
    ent._scale = scale
    ent._color = col
end
Core.TriggerHalRingDepleted = function() end
Core.RestoreHalRingPower = function() end
Core.PlayRingSound = function() end

-- ===================== HELPERS =====================
local function loadModule(path)
    local f = assert(io.open(path, "r"))
    local src = f:read("*a"); f:close()
    src = src:gsub("|", " + ")
    return assert(loadstring(src, path))()(Core)
end

loadModule("modules/beam_math.lua")

-- Capturar el callback POST_TEAR_UPDATE de beam_discrete (el primero de ese id).
local cbsBeforeDiscrete = #Core.GL._cbs
loadModule("modules/beam_discrete.lua")
local postTearUpdateCb = nil
for i = cbsBeforeDiscrete + 1, #Core.GL._cbs do
    local cb = Core.GL._cbs[i]
    if cb.id == ModCallbacks.MC_POST_TEAR_UPDATE then
        postTearUpdateCb = cb.fn
        break
    end
end

loadModule("modules/beam_synergies.lua")
-- Capturar el ultimo PRE_TEAR_COLLISION (registrado por beam_synergies).
local preTearCollisionCb = nil
for i = #Core.GL._cbs, 1, -1 do
    local cb = Core.GL._cbs[i]
    if cb.id == ModCallbacks.MC_PRE_TEAR_COLLISION then
        preTearCollisionCb = cb.fn
        break
    end
end

check(postTearUpdateCb ~= nil, "MC_POST_TEAR_UPDATE registered")
check(preTearCollisionCb ~= nil, "MC_PRE_TEAR_COLLISION registered")

local function makePlayer(items)
    local itemMap = {}
    for _, id in ipairs(items or {}) do itemMap[id] = true end
    return {
        _ringActive = true,
        _isHal = true,
        Damage = 3.5,
        Position = Vector(100, 100),
        HasCollectible = function(_, id) return itemMap[id] == true end,
        ToPlayer = function(self) return self end,
        _data = {},
        GetData = function(self) return self._data end,
    }
end

local function makeFakeTear(player, idx)
    local t = {
        Type = EntityType.ENTITY_TEAR,
        Index = idx or 1,
        Position = Vector(100 + (idx or 0), 100),
        Velocity = Vector(10, 0),
        CollisionDamage = 3.5,
        Scale = 1.0,
        FrameCount = 0,
        Size = 12,
        Visible = true,
        FallingSpeed = 0,
        FallingAcceleration = 0,
        SpawnerEntity = player,
        _removed = false,
        _data = { isGLRingBeam = true, glBeamVel = Vector(10, 0) },
        GetData = function(self) return self._data end,
        ToTear = function(self) return self end,
        GetSprite = function()
            return {
                Color = Color(1, 1, 1, 1, 0, 0, 0),
                Load = function() end,
                Play = function() end,
                SetFrame = function() end,
                GetAnimation = function() return "Idle" end,
                Scale = Vector(1, 1),
                Rotation = 0,
            }
        end,
        Die = function(self) self._dead = true end,
        Remove = function(self) self._removed = true end,
    }
    table.insert(_G._roomEntities, t)
    return t
end

-- ===================== TEST 1: CONSTANTES =====================
check(Core.GL_BEAM_MAX_LIFE_FRAMES == 120,
      string.format("GL_BEAM_MAX_LIFE_FRAMES debe ser 120, fue %s", tostring(Core.GL_BEAM_MAX_LIFE_FRAMES)))
check(Core.GL_BEAM_MAX_ALIVE == 32,
      string.format("GL_BEAM_MAX_ALIVE debe ser 32, fue %s", tostring(Core.GL_BEAM_MAX_ALIVE)))

-- ===================== TEST 2: VIDA MAXIMA =====================
do
    local p = makePlayer({})
    local tear = makeFakeTear(p, 1)
    local maxLife = Core.GL_BEAM_MAX_LIFE_FRAMES or 120
    for f = 1, maxLife do
        tear.FrameCount = f
        postTearUpdateCb(nil, tear)
    end
    check(tear._removed == false,
          string.format("beam sobrevive hasta frame %d (removed=%s)", maxLife, tostring(tear._removed)))
    tear.FrameCount = maxLife + 1
    postTearUpdateCb(nil, tear)
    check(tear._removed == true,
          string.format("beam se elimina al superar MAX_LIFE (frame %d)", maxLife + 1))
end

-- ===================== TEST 3: TOPE DE BEAMS VIVOS =====================
do
    local p = makePlayer({})
    local maxAlive = Core.GL_BEAM_MAX_ALIVE or 32
    local tears = {}
    for i = 1, maxAlive + 1 do
        local t = makeFakeTear(p, i)
        t.FrameCount = i
        postTearUpdateCb(nil, t)
        table.insert(tears, t)
    end
    local removedCount = 0
    for _, t in ipairs(tears) do
        if t._removed then removedCount = removedCount + 1 end
    end
    check(removedCount == 1,
          string.format("con %d beams, solo el mas antiguo se remueve (removed=%d)", maxAlive + 1, removedCount))
    check(tears[1]._removed == true, "el beam mas antiguo (index 1) es el removido")
end

-- ===================== TEST 4: SPLITS VISIBLES (Parasite) =====================
do
    spawnedEntities = {}
    local pParasite = makePlayer({ CollectibleType.COLLECTIBLE_PARASITE })
    -- NO definimos pParasite.FireTear: forzamos spawn directo.
    local mainTear = makeFakeTear(pParasite, 99)
    mainTear.Position = Vector(150, 100)
    mainTear.Velocity = Vector(10, 0)
    mainTear.CollisionDamage = 8.0
    local enemy = {
        Index = 1,
        Position = Vector(160, 100),
        IsActiveEnemy = function() return true end,
        IsVulnerableEnemy = function() return true end,
        GetData = function() return {} end,
    }
    preTearCollisionCb(nil, mainTear, enemy, false)
    check(#spawnedEntities == 2,
          string.format("Parasite spawnea 2 splits sin FireTear, spawneados=%d", #spawnedEntities))
    if #spawnedEntities == 2 then
        for i, t in ipairs(spawnedEntities) do
            local td = t:GetData()
            check(td.isGLRingBeam == true, string.format("split %d marca isGLRingBeam", i))
            check(td.isParasiteShard == true, string.format("split %d marca isParasiteShard", i))
            check(t._styled == true, string.format("split %d tiene ApplyRingBeamSprite", i))
            check(Core.HasTearFlag(t.TearFlags, TearFlags.TEAR_SPECTRAL),
                  string.format("split %d tiene SPECTRAL", i))
            check(Core.HasTearFlag(t.TearFlags, TearFlags.TEAR_PIERCING),
                  string.format("split %d tiene PIERCING", i))
        end
    end
end

-- ===================== TEST 5: SPLITS VISIBLES (Cricket) =====================
do
    spawnedEntities = {}
    local pCricket = makePlayer({ CollectibleType.COLLECTIBLE_CRICKETS_BODY })
    local mainTear = makeFakeTear(pCricket, 99)
    mainTear.Position = Vector(150, 100)
    mainTear.Velocity = Vector(10, 0)
    mainTear.CollisionDamage = 6.0
    local enemy = {
        Index = 2,
        Position = Vector(160, 100),
        IsActiveEnemy = function() return true end,
        IsVulnerableEnemy = function() return true end,
        GetData = function() return {} end,
    }
    preTearCollisionCb(nil, mainTear, enemy, false)
    check(#spawnedEntities == 4,
          string.format("Cricket's Body spawnea 4 splits sin FireTear, spawneados=%d", #spawnedEntities))
    if #spawnedEntities == 4 then
        for i, t in ipairs(spawnedEntities) do
            local td = t:GetData()
            check(td.isGLRingBeam == true, string.format("cricket split %d marca isGLRingBeam", i))
            check(td.isCricketShard == true, string.format("cricket split %d marca isCricketShard", i))
        end
    end
end

-- ===================== TEST 6: NEPTUNUS BLOQUEA RAYO CONTINUO =====================
do
    local pNeptunus = makePlayer({ CollectibleType.COLLECTIBLE_NEPTUNUS })
    check(Core.CanUseContinuousBeam(pNeptunus) == false,
          "Neptunus debe bloquear CanUseContinuousBeam")
end

-- Summary
print(string.format("test_beam_lifetime_and_splits.lua: %d passed, %d failed", passes, failures))
if failures > 0 then
    os.exit(1)
end
