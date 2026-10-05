-- tools/test_shield_bypass_player.lua
-- F7: bypass por-jugador (glShieldBypassBy = player.Index).
--   (A) Rama orbital: al fallar el roll marca glShieldBypassBy = player.Index
--       y NO destruye el proyectil.
--   (B) 2P: bypass de P1 (By=0) NO exime a P2 (Index=1) -> P2 refleja normal
--       (spawn tear); el mismo proyectil SI exime a P1 (sin tear, return nil).
--   (C) Single-player intacto: bypass propio exime (sin tear).
--   (D) Invariantes: formulas Luck via Core.SHIELD_REFLECT_*; dano/reflect intactos.
-- Compatible con Lua 5.1.

-- ===================== STUBS Vector/Color =====================
Vector = {}
local VectorMT = {}
function Vector.new(x, y)
  local t = { X = x or 0, Y = y or 0 }
  setmetatable(t, {
    __index = Vector,
    __add = VectorMT.__add,
    __sub = VectorMT.__sub,
    __unm = VectorMT.__unm,
    __mul = VectorMT.__mul,
    __eq = VectorMT.__eq,
    __tostring = function(self) return string.format("Vector(%g,%g)", self.X, self.Y) end,
  })
  return t
end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
  local l = self:Length()
  if l <= 0.001 then return Vector.new(1, 0) end
  return Vector.new(self.X / l, self.Y / l)
end
function Vector.Zero() return Vector.new(0, 0) end
VectorMT.__add = function(a, b)
  if type(b) == "number" then return Vector.new(a.X + b, a.Y + b) end
  return Vector.new(a.X + b.X, a.Y + b.Y)
end
VectorMT.__sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
VectorMT.__unm = function(a) return Vector.new(-a.X, -a.Y) end
VectorMT.__mul = function(a, b)
  if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
  if type(a) == "number" then return Vector.new(a * b.X, a * b.Y) end
  return Vector.new(a.X * b.X, a.Y * b.Y)
end
VectorMT.__eq = function(a, b)
  return type(a) == "table" and type(b) == "table"
    and math.abs(a.X - b.X) < 1e-9 and math.abs(a.Y - b.Y) < 1e-9
end
function Color(r, g, b, a, ro, go, bo)
  return { R = r or 0, G = g or 0, B = b or 0, A = a or 0, ROff = ro, GOff = go, BOff = bo }
end

-- ===================== ENUMS =====================
EntityType = { ENTITY_PLAYER = 1, ENTITY_PROJECTILE = 9, ENTITY_TEAR = 2, ENTITY_EFFECT = 1003 }
TearVariant = { BLUE = 1 }
EffectVariant = { WATER_SPLASH = 38 }
TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 4 }
DamageFlag = { DAMAGE_NO_MODIFIERS = 33554432 }
Direction = { LEFT = 1, RIGHT = 0, UP = 2, DOWN = 3 }
SoundEffect = { SOUND_TEARS_FIRE = 14, SOUND_ROCK_CRUMBLE = 62 }
ModCallbacks = { MC_POST_UPDATE = 1, MC_ENTITY_TAKE_DMG = 2 }

-- ===================== STUBS JUEGO =====================
local projectiles = {}
local roomEnts = {}
local _players = {}
local _numPlayers = 1

Isaac = {}
function Isaac.FindByType(_, _, _, _) return projectiles end
function Isaac.GetRoomEntities() return roomEnts end
function Isaac.GetPlayer(i) return _players[i or 0] end
function Isaac.WorldToScreen(v) return v end
function Isaac.Spawn(etype, evar, _, pos, vel, _owner)
  if etype == EntityType.ENTITY_TEAR then
    return {
      Position = pos, Velocity = vel,
      CollisionDamage = 0, TearFlags = 0, Scale = 1,
      GetSprite = function(self) return { Color = nil } end,
      ToTear = function(self) return self end,
    }
  elseif etype == EntityType.ENTITY_EFFECT then
    return { GetSprite = function(self) return { Color = nil } end, Scale = 1 }
  end
  return nil
end

function Game()
  return {
    GetNumPlayers = function() return _numPlayers end,
    GetFrameCount = function() return 0 end,
  }
end
function SFXManager() return { Play = function() end } end

-- ===================== STUB CORE =====================
local Core = {}
Core.GL = { _cbs = {}, AddCallback = function(self, id, fn) table.insert(self._cbs, { id = id, fn = fn }) end }
Core.SHIELD_REFLECT_BASE = 0.25
Core.SHIELD_REFLECT_PER_LUCK = 0.05
Core.SHIELD_REFLECT_MAX = 0.75
Core.ITEM_SOLID_LIGHT_SHIELD = 1
local dataByIndex = {}
Core.GetPlayerData = function(player) return dataByIndex[player.Index] end
Core.LoadItemIDs = function() end
Core.GetShieldOrbitPos = function(player, _) return player.Position end

local tearSpawnCount = 0
local origSpawn = Isaac.Spawn
function Isaac.Spawn(etype, evar, idx, pos, vel, owner)
  if etype == EntityType.ENTITY_TEAR then tearSpawnCount = tearSpawnCount + 1 end
  return origSpawn(etype, evar, idx, pos, vel, owner)
end

-- Cargar shield.lua (parche `|` -> `+` para Lua 5.1, igual que test T4).
local function loadShieldFactory(path)
  local f = io.open(path, "r")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  local patched, n = src:gsub(
    "| TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING",
    "+ TearFlags.TEAR_SPECTRAL + TearFlags.TEAR_PIERCING",
    2, true)
  assert(n == 2, "F7: se esperaban 2 OR en shield.lua, halladas " .. tostring(n))
  local chunk, err = loadstring(patched, path)
  assert(chunk, err)
  return chunk()
end
loadShieldFactory("modules/shield.lua")(Core)

local function findCb(id)
  for _, c in ipairs(Core.GL._cbs) do if c.id == id then return c.fn end end
  return nil
end
local orbitalCb = findCb(ModCallbacks.MC_POST_UPDATE)
local dmgCb = findCb(ModCallbacks.MC_ENTITY_TAKE_DMG)
assert(orbitalCb, "F7: falta callback MC_POST_UPDATE")
assert(dmgCb, "F7: falta callback MC_ENTITY_TAKE_DMG")

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end

local function makePlayer(idx, posX, posY, opts)
  opts = opts or {}
  local p = {
    Index = idx, Type = EntityType.ENTITY_PLAYER,
    Position = Vector.new(posX or 0, posY or 0),
    Damage = opts.damage or 3.5, Luck = opts.luck or 0,
    _hasShield = opts.hasShield ~= false,
  }
  function p:HasCollectible(id) return id == Core.ITEM_SOLID_LIGHT_SHIELD and self._hasShield end
  function p:ToPlayer() return self end
  function p:GetData() return self end
  return p
end

local function makeProj(posX, posY)
  local proj = {
    Position = Vector.new(posX, posY), Velocity = Vector.new(-4, 0),
    Type = EntityType.ENTITY_PROJECTILE, _dead = false, _data = {},
  }
  function proj:IsVulnerableEnemy() return false end
  function proj:IsDead() return self._dead end
  function proj:Die() self._dead = true end
  function proj:GetData() return self._data end
  function proj:ToProjectile() return self end
  return proj
end

local origRandom = math.random

-- ===================== (A) ORBITAL MARCA POR-JUGADOR =====================
-- 2P: P1 en (0,0), P2 lejos en (500,500). Proyectil junto a P1.
local p1 = makePlayer(0, 0, 0, { hasShield = true, luck = 0 })
local p2 = makePlayer(1, 500, 500, { hasShield = true, luck = 0 })
_players = { [0] = p1, [1] = p2 }
_numPlayers = 2
dataByIndex = { [0] = { shieldOrbitAngle = 0, shieldDeflectTimer = 0 }, [1] = { shieldOrbitAngle = 0, shieldDeflectTimer = 0 } }

math.random = function() return 1.0 end -- miss seguro (chance max 0.75)
local projMark = makeProj(5, 0)
projectiles = { projMark }
roomEnts = {}
orbitalCb()
math.random = origRandom

check(projMark:GetData().glShieldBypassBy == 0,
  string.format("F7(A): orbital miss marca glShieldBypassBy=0 (P1), fue %s", tostring(projMark:GetData().glShieldBypassBy)))
check(projMark._dead == false, "F7(A): orbital miss NO destruye el proyectil")

-- ===================== (B) 2P: BYPASS P1 NO EXIME A P2 =====================
-- El proyectil marcado por P1 (By=0) golpea a P2: debe reflejar normal con roll favorable.
math.random = function() return 0.0 end -- hit seguro
tearSpawnCount = 0
local retP2 = dmgCb(nil, p2, 1.0, 0, { Entity = projMark })
check(tearSpawnCount >= 1,
  string.format("F7(B): bypass P1 NO exime a P2 -> P2 refleja (tears=%d)", tearSpawnCount))
check(retP2 == false, "F7(B): bypass P1 golpeando a P2 debe bloquear (return false)")

-- El mismo proyectil golpeando a P1: SI exime (sin reflect, sin bloqueo).
tearSpawnCount = 0
local retP1 = dmgCb(nil, p1, 1.0, 0, { Entity = projMark })
check(retP1 == nil, "F7(B): bypass P1 golpeando a P1 retorna nil (sin bloque)")
check(tearSpawnCount == 0,
  string.format("F7(B): bypass P1 golpeando a P1 NO spawnea tear (fueron %d)", tearSpawnCount))
math.random = origRandom

-- ===================== (C) SINGLE-PLAYER INTACTO =====================
local sp = makePlayer(0, 0, 0, { hasShield = true, luck = 0 })
_players = { [0] = sp }
_numPlayers = 1
dataByIndex = { [0] = { shieldOrbitAngle = 0, shieldDeflectTimer = 0 } }
math.random = function() return 1.0 end
local projSP = makeProj(5, 0)
projectiles = { projSP }
roomEnts = {}
orbitalCb()
math.random = origRandom
check(projSP:GetData().glShieldBypassBy == 0, "F7(C): 1P orbital miss marca By=propio")
check(projSP._dead == false, "F7(C): 1P orbital miss no destruye")
math.random = function() return 0.0 end
tearSpawnCount = 0
local retSP = dmgCb(nil, sp, 1.0, 0, { Entity = projSP })
math.random = origRandom
check(retSP == nil, "F7(C): 1P bypass propio retorna nil (respeta bypass)")
check(tearSpawnCount == 0, "F7(C): 1P bypass propio no spawnea tear")

-- Sin bypass y roll favorable en 1P: refleja normal (rama intacta).
math.random = function() return 0.0 end
local projClean = makeProj(0, 0)
tearSpawnCount = 0
local retClean = dmgCb(nil, sp, 1.0, 0, { Entity = projClean })
math.random = origRandom
check(tearSpawnCount >= 1, "F7(C): 1P sin bypass y roll favorable spawnea tear (reflect intacto)")
check(retClean == false, "F7(C): 1P sin bypass refleja y bloquea (return false)")

-- ===================== (D) INVARIANTES =====================
local f = io.open("modules/shield.lua", "r")
local content = f and f:read("*a") or ""
if f then f:close() end
check(content:find("Core.SHIELD_REFLECT_BASE", 1, true) ~= nil, "F7(D): referencia Core.SHIELD_REFLECT_BASE")
check(content:find("Core.SHIELD_REFLECT_PER_LUCK", 1, true) ~= nil, "F7(D): referencia Core.SHIELD_REFLECT_PER_LUCK")
check(content:find("Core.SHIELD_REFLECT_MAX", 1, true) ~= nil, "F7(D): referencia Core.SHIELD_REFLECT_MAX")
check(content:find("glShieldBypassBy", 1, true) ~= nil, "F7(D): usa glShieldBypassBy (por-jugador)")
check(content:find("player.Index", 1, true) ~= nil, "F7(D): compara player.Index")
check(content:find("player.Damage * 1.5", 1, true) ~= nil, "F7(D): dano reflect intacto (player.Damage * 1.5)")

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_shield_bypass_player] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
