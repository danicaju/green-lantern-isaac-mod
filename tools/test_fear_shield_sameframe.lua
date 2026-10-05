-- tools/test_fear_shield_sameframe.lua
-- F5: si el escudo bloquea el dano (shieldBlockedFrame == frame actual),
-- Yellow Impurity NO aplica fear el mismo frame. Sin bloqueo -> fear 60.
-- Compatible con Lua 5.1.

-- ===================== SHIMS Vector/Color =====================
Vector = {}
local VectorMT = {}
function Vector.new(x, y)
  local u = setmetatable({ X = x or 0, Y = y or 0 }, {
    __index = Vector,
    __add = VectorMT.__add,
    __sub = VectorMT.__sub,
    __unm = VectorMT.__unm,
    __mul = VectorMT.__mul,
  })
  return u
end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
  local l = self:Length()
  if l <= 0.001 then return Vector.new(1, 0) end
  return Vector.new(self.X / l, self.Y / l)
end
function Color(r, g, b, a, ro, go, bo)
  return { R = r, G = g, B = b, A = a, ROff = ro, GOff = go, BOff = bo }
end
VectorMT.__add = function(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end
VectorMT.__sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
VectorMT.__unm = function(a) return Vector.new(-a.X, -a.Y) end
VectorMT.__mul = function(a, b)
  if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
  if type(a) == "number" then return Vector.new(a * b.X, a * b.Y) end
  return Vector.new(a.X * b.X, a.Y * b.Y)
end
Vector.Zero = Vector.new(0, 0)

-- ===================== STUBS ISAAC =====================
ModCallbacks = { MC_ENTITY_TAKE_DMG = 11, MC_POST_UPDATE = 1, MC_POST_ENTITY_KILL = 68 }
EntityType = { ENTITY_PLAYER = 1, ENTITY_PROJECTILE = 9, ENTITY_TEAR = 2, ENTITY_EFFECT = 1003 }
EntityFlag = { FLAG_FEAR = 16 }
DamageFlag = { DAMAGE_CRUSH = 1, DAMAGE_NOKILL = 2, DAMAGE_EXPLOSION = 4, DAMAGE_NO_MODIFIERS = 33554432 }
TearVariant = { BLUE = 1 }
EffectVariant = { POOF04 = 4, WATER_SPLASH = 38 }
TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 4 }
SoundEffect = { SOUND_TEARS_FIRE = 14, SOUND_DEATH_BURST_SMALL = 99 }

function SFXManager() return { Play = function() end } end

_frameCount = 100
Isaac = {}
function Isaac.GetPlayer(i) return nil end
function Isaac.Spawn(typ, variant, sub, pos, vel, parent)
  return {
    GetSprite = function() return { Color = nil } end,
    Scale = 1, CollisionDamage = 0, TearFlags = 0,
  }
end

function Game()
  return {
    GetNumPlayers = function() return 1 end,
    GetFrameCount = function() return _frameCount end,
  }
end

-- ===================== STUB CORE =====================
local Core = {}
Core.GL = {
  _cbs = {},
  AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
}
Core.SHIELD_REFLECT_BASE = 0.25
Core.SHIELD_REFLECT_PER_LUCK = 0.05
Core.SHIELD_REFLECT_MAX = 0.75
Core.ITEM_SOLID_LIGHT_SHIELD = 1
Core.TRINKET_YELLOW_IMPURITY = 999
local dataByIndex = {}
function Core.GetPlayerData(player)
  if not dataByIndex[player.Index] then dataByIndex[player.Index] = {} end
  return dataByIndex[player.Index]
end
function Core.LoadItemIDs() end
function Core.GetShieldOrbitPos(player, _) return player.Position end
function Core.HasGreenLanternRing(_) return false end

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end

local function makePlayer(idx)
  local p = {
    Index = idx,
    Type = EntityType.ENTITY_PLAYER,
    Position = Vector.new(0, 0),
    Velocity = Vector.new(0, 0),
    Damage = 3.5, Luck = 0, MoveSpeed = 1.0,
    _hasShield = true, _hasTrinket = true, _flags = {},
  }
  function p:ToPlayer() return self end
  function p:HasCollectible(id) return self._hasShield and id == Core.ITEM_SOLID_LIGHT_SHIELD end
  function p:HasTrinket(id) return self._hasTrinket and id == Core.TRINKET_YELLOW_IMPURITY end
  function p:AddEntityFlags(f) self._flags[f] = true end
  function p:ClearEntityFlags(f) self._flags[f] = nil end
  function p:SetColor(...) end
  return p
end

local function makeProj()
  local proj = {
    Position = Vector.new(10, 0), Velocity = Vector.new(-4, 0),
    Type = EntityType.ENTITY_PROJECTILE, _data = {},
  }
  function proj:GetData() return self._data end
  return proj
end

local function loadShield()
  local f = assert(io.open("modules/shield.lua", "r"))
  local src = f:read("*a"); f:close()
  local patched, n = src:gsub(
    "| TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING",
    "+ TearFlags.TEAR_SPECTRAL + TearFlags.TEAR_PIERCING",
    2, true)
  assert(n == 2, "F5: se esperaban 2 OR en shield.lua, halladas " .. tostring(n))
  local chunk, err = loadstring(patched, "modules/shield.lua")
  assert(chunk, err)
  local factory = chunk()
  factory(Core)
end

local function loadFear()
  local f = assert(io.open("modules/trinket_fear.lua", "r"))
  local src = f:read("*a"); f:close()
  src = src:gsub("%(flags & DamageFlag%.DAMAGE_CRUSH%) ~=%s*0", function() return "(flags % 2 >= 1)" end)
  src = src:gsub("%(flags & DamageFlag%.DAMAGE_NOKILL%) ==%s*0", function() return "(flags % 4 < 2)" end)
  src = src:gsub("%(flags & DamageFlag%.DAMAGE_EXPLOSION%) ~=%s*0", function() return "(flags % 8 >= 4)" end)
  local chunk, err = loadstring(src, "modules/trinket_fear.lua")
  assert(chunk, err)
  local factory = chunk()
  factory(Core)
end

loadShield()
loadFear()

local dmgCbs = {}
for _, c in ipairs(Core.GL._cbs) do
  if c.id == ModCallbacks.MC_ENTITY_TAKE_DMG then table.insert(dmgCbs, c.fn) end
end
check(#dmgCbs == 2, "F5: shield + fear registran MC_ENTITY_TAKE_DMG (2 callbacks)")
local shieldCb, fearCb = dmgCbs[1], dmgCbs[2]

local origRandom = math.random

-- ===================== CASO A: bloqueo mismo frame -> sin fear =====================
dataByIndex = {}
local pA = makePlayer(0)
_frameCount = 100
math.random = function() return 0.0 end -- reflect seguro
local projA = makeProj()
local retBlock = shieldCb(nil, pA, 1.0, 0, { Entity = projA })
math.random = origRandom
check(retBlock == false, "F5(A): shield bloquea (return false) con roll favorable")
local dA = Core.GetPlayerData(pA)
check(dA.shieldBlockedFrame == 100,
  string.format("F5(A): shield setea shieldBlockedFrame=100 (fue %s)", tostring(dA.shieldBlockedFrame)))
-- Mismo frame: fear debe saltar el debuff.
fearCb(nil, pA, 1, 0, nil) -- flags=0 -> contacto
check(dA.fearControlTimer == nil,
  string.format("F5(A): bloqueo mismo frame -> sin fearControlTimer (fue %s)", tostring(dA.fearControlTimer)))
check(dA.fearSkullTimer == nil,
  string.format("F5(A): bloqueo mismo frame -> sin fearSkullTimer (fue %s)", tostring(dA.fearSkullTimer)))
check(pA._flags[EntityFlag.FLAG_FEAR] ~= true, "F5(A): bloqueo mismo frame -> sin FLAG_FEAR")

-- ===================== CASO B: sin bloqueo -> fear 60 =====================
dataByIndex = {}
local pB = makePlayer(0)
_frameCount = 200
-- Sin llamar a shield (sin bloqueo): fear aplica normal.
fearCb(nil, pB, 1, 0, nil)
local dB = Core.GetPlayerData(pB)
check(dB.fearControlTimer == 60,
  string.format("F5(B): sin bloqueo -> fearControlTimer=60 (fue %s)", tostring(dB.fearControlTimer)))
check(dB.fearSkullTimer == 60,
  string.format("F5(B): sin bloqueo -> fearSkullTimer=60 (fue %s)", tostring(dB.fearSkullTimer)))
check(pB._flags[EntityFlag.FLAG_FEAR] == true, "F5(B): sin bloqueo -> FLAG_FEAR puesto")

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_fear_shield_sameframe] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
