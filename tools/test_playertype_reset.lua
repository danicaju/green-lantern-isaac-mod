-- tools/test_playertype_reset.lua
-- F4: anti-cruce de PlayerType + anillos solo-Tainted.
--   (a) cambio de tipo -> reset de run a defaults + initializedStartingItems=false
--       (rekit en el siguiente frame) + lastPlayerType actualizado.
--   (b) dueno no-Tainted -> 0 disparos de anillos robados en 120 frames
--       (ni mover ni disparar con esos familiares).
-- Compatible con Lua 5.1. Ejecutar desde la raiz del mod:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tools/test_playertype_reset.lua

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

-- ===================== ENUMS / STUBS ENGINE =====================
ModCallbacks = { MC_POST_PLAYER_UPDATE = 1003, MC_POST_UPDATE = 1002, MC_POST_NEW_ROOM = 1001 }
RoomType = { ROOM_ANGEL = 4 }
EntityType = { ENTITY_PICKUP = 5, ENTITY_FAMILIAR = 3, ENTITY_TEAR = 2, ENTITY_EFFECT = 1003 }
PickupVariant = { PICKUP_COLLECTIBLE = 100 }
EntityPartition = { PICKUP = 1 }
SoundEffect = { SOUND_BOSS2INTRO_ERRORBUZZ = 999, SOUND_SUPERHOLY = 1 }
CacheFlag = { CACHE_FLYING = 1, CACHE_SPEED = 2, CACHE_DAMAGE = 4, CACHE_SHOTSPEED = 8, CACHE_TEARFLAG = 16, CACHE_FIREDELAY = 32, CACHE_FLYING2 = 64 }
ActiveSlot = { SLOT_PRIMARY = 0 }
FamiliarVariant = { BLUE_FLY = 43 }
TearVariant = { BLUE = 0 }
TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 2 }
ButtonAction = { ACTION_DROP = 7 }
EntityFlag = { FLAG_FEAR = 1 }

PLAYER_HAL = 10
PLAYER_TAINTED = 20
PLAYER_OTHER = 1

_frameCount = 0
_testPlayers = {}
_testFamiliars = {}
_testEnemies = {}
_pickups = {}
_inputPressed = false
tearSpawnCount = 0

function RegisterMod(_, _) -- stub para modules/core.lua real
  return {
    _cbs = {},
    AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
  }
end
function Game()
  return {
    GetNumPlayers = function() return #_testPlayers end,
    GetFrameCount = function() return _frameCount or 0 end,
    GetLevel = function() return { GetCurrentRoomIndex = function() return 0 end } end,
    GetRoom = function()
      return {
        GetType = function() return RoomType.ROOM_ANGEL end,
        GetCenterPos = function() return Vector.new(0, 0) end,
      }
    end,
    GetHUD = function() return { IsVisible = function() return true end } end,
  }
end
function SFXManager() return { Play = function() end } end
Input = {}
function Input.IsActionPressed(_, _) return _inputPressed end
Isaac = {}
function Isaac.GetPlayer(i) return _testPlayers[i] end
function Isaac.FindByType(t, v, s, b)
  if t == EntityType.ENTITY_FAMILIAR then return _testFamiliars end
  return {}
end
function Isaac.FindInRadius(_, _, _) return _pickups end
function Isaac.GetRoomEntities() return _testEnemies end
function Isaac.Spawn(t, _, _, pos, vel, owner)
  if t == EntityType.ENTITY_TEAR then tearSpawnCount = tearSpawnCount + 1 end
  local e = {}
  function e:ToFamiliar() return e end
  function e:ToTear()
    if t == EntityType.ENTITY_TEAR then return e end
    return nil
  end
  e.Position = pos or Vector.new(0, 0)
  e.Velocity = vel or Vector.new(0, 0)
  e.CollisionDamage = 0
  e.TearFlags = 0
  e.Scale = 1.0
  function e:GetData() return {} end
  function e:GetSprite() return { Color = nil } end
  return e
end

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end

local function loadModule(path)
  local f = assert(io.open(path, "r"))
  local src = f:read("*a")
  f:close()
  -- Lua 5.1 (harness) no parsea `|` (OR 5.3+ usado en el mod para flags).
  -- Los flags son disjuntos: `+` equivale a OR.
  src = src:gsub("|", "+")
  local chunk, err = loadstring(src, path)
  assert(chunk, tostring(err))
  return chunk()
end

-- ===================== (E1) core.lua real: lastPlayerType = nil =====================
local Core = dofile("modules/core.lua")
check(Core ~= nil, "F4(E1): modules/core.lua carga")
-- Predicados por tipo numerico (sin Isaac real).
Core.PLAYER_HAL = PLAYER_HAL
Core.PLAYER_TAINTED_HAL = PLAYER_TAINTED
Core.ITEM_POWER_RING = 100
Core.ITEM_POWER_BATTERY = 101
Core.ITEM_COAST_CITY = 102
function Core.IsHalJordan(p) return p and p:GetPlayerType() == PLAYER_HAL end
function Core.IsTaintedHal(p) return p and p:GetPlayerType() == PLAYER_TAINTED end
function Core.EnforceTaintedHalNoRedHearts(_) end
function Core.RefreshCharacterCostume(_) end
function Core.SetEntityScaleAndColor(_, _, _) end

local probePlayer = {
  Index = 77,
  _ptype = PLAYER_HAL,
  _data = {},
  GetPlayerType = function(self) return self._ptype end,
  GetData = function(self) return self._data end,
}
local probeData = Core.GetPlayerData(probePlayer)
check(probeData.lastPlayerType == nil,
  string.format("F4(core): GetPlayerData incluye lastPlayerType=nil (fue %s)", tostring(probeData.lastPlayerType)))

-- ===================== (a) player_update: cambio de tipo -> reset + rekit =====================
local function makePlayer(idx, ptype)
  local p = {
    Index = idx,
    _ptype = ptype,
    _data = {},
    Position = Vector.new(0, 0),
    ControllerIndex = 0,
    Damage = 5.0,
    SpriteOffset = Vector.new(9, 9),
    collectibles = {},
    soulHearts = 0,
    blackHearts = 0,
    addCollectibleCalls = 0,
  }
  function p:GetPlayerType() return self._ptype end
  function p:GetData() return self._data end
  function p:GetSoulHearts() return self.soulHearts end
  function p:AddSoulHearts(n) self.soulHearts = self.soulHearts + (n or 0) end
  function p:AddBlackHearts(n) self.blackHearts = self.blackHearts + (n or 0) end
  function p:HasCollectible(id) return self.collectibles[id] == true end
  function p:AddCollectible(id, _, _, _)
    self.collectibles[id] = true
    self.addCollectibleCalls = self.addCollectibleCalls + 1
  end
  function p:AddCacheFlags(_) end
  function p:EvaluateItems() end
  function p:AnimateHappy() end
  return p
end

Core.GL._cbs = {}
local puFactory = loadModule("modules/player_update.lua")
puFactory(Core)
local playerCb = nil
for _, c in ipairs(Core.GL._cbs) do
  if c.id == ModCallbacks.MC_POST_PLAYER_UPDATE then playerCb = c.fn; break end
end
check(playerCb ~= nil, "F4(a): player_update.lua registra MC_POST_PLAYER_UPDATE")

if playerCb then
  -- Primer frame con Hal: fija lastPlayerType sin resetear (nil -> tipo).
  local p = makePlayer(0, PLAYER_HAL)
  _testPlayers = { [0] = p }
  playerCb(nil, p)
  local d0 = Core.GetPlayerData(p)
  check(d0.lastPlayerType == PLAYER_HAL,
    string.format("F4(a0): primer frame fija lastPlayerType=HAL (fue %s)", tostring(d0.lastPlayerType)))

  -- Ensuciar estado de run y cambiar de tipo Hal -> Tainted.
  -- El kit se re-concede EN EL MISMO frame (el bloque de starting-items corre
  -- despues del reset en el mismo callback): la evidencia de rekit es el delta
  -- de coleccionables + flag de vuelta a true. El mecanismo
  -- (initializedStartingItems=false) se verifica por contenido de fuente abajo.
  d0.willpower = 5.0
  d0.ringDepleted = true
  d0.overcharge = true
  d0.surgeBuff = true
  d0.overchargeTier = 2
  d0.emeraldSparks = 50.0
  d0.stolenRings = 5
  d0.coastCityActive = true
  d0.gatlingTimer = 100
  d0.fearControlTimer = 60
  d0.fearSkullTimer = 60
  d0.hadItemFlight = true
  d0.initializedStartingItems = true
  local kitsBeforeSwitch = p.addCollectibleCalls
  p._ptype = PLAYER_TAINTED
  playerCb(nil, p)
  local d1 = Core.GetPlayerData(p)
  check(d1.willpower == Core.WILLPOWER_MAX,
    string.format("F4(a1): cambio tipo resetea willpower=MAX (fue %s)", tostring(d1.willpower)))
  check(d1.ringDepleted == false, "F4(a1): cambio tipo resetea ringDepleted=false")
  check(d1.overcharge == false, "F4(a1): cambio tipo resetea overcharge=false")
  check(d1.surgeBuff == false, "F4(a1): cambio tipo resetea surgeBuff=false")
  check(d1.emeraldSparks == 0,
    string.format("F4(a1): cambio tipo resetea emeraldSparks=0 (fue %s)", tostring(d1.emeraldSparks)))
  check(d1.stolenRings == 0,
    string.format("F4(a1): cambio tipo resetea stolenRings=0 (fue %s)", tostring(d1.stolenRings)))
  check(d1.coastCityActive == false, "F4(a1): cambio tipo resetea coastCityActive=false")
  check((d1.gatlingTimer or 0) == 0,
    string.format("F4(a1): cambio tipo resetea gatlingTimer=0 (fue %s)", tostring(d1.gatlingTimer)))
  check((d1.fearControlTimer or 0) == 0,
    string.format("F4(a1): cambio tipo resetea fearControlTimer=0 (fue %s)", tostring(d1.fearControlTimer)))
  check((d1.fearSkullTimer or 0) == 0,
    string.format("F4(a1): cambio tipo resetea fearSkullTimer=0 (fue %s)", tostring(d1.fearSkullTimer)))
  check((d1.overchargeTier or 0) == 0,
    string.format("F4(a1): cambio tipo resetea overchargeTier=0 (fue %s)", tostring(d1.overchargeTier)))
  check(d1.hadItemFlight == false, "F4(a1): cambio tipo resetea hadItemFlight=false")
  -- Mecanismo de rekit (spec): el reset pone initializedStartingItems=false
  -- para que el bloque de starting-items del mismo callback re-conceda el kit.
  do
    local f = assert(io.open("modules/player_update.lua", "r"))
    local src = f:read("*a")
    f:close()
    check(src:find("initializedStartingItems = false", 1, true) ~= nil,
      "F4(a1): player_update.lua pone initializedStartingItems=false en el reset")
  end
  -- Rekit observable en el MISMO frame del cambio: flag vuelve a true y se
  -- conceden coleccionables del kit Tainted (Coast City; el anillo ya lo tenia).
  check(d1.initializedStartingItems == true,
    "F4(a1): tras reset, el mismo frame re-concede kit (initializedStartingItems=true)")
  check(p.addCollectibleCalls > kitsBeforeSwitch,
    string.format("F4(a1): rekit concede coleccionables (%d->%d)", kitsBeforeSwitch, p.addCollectibleCalls))
  check(d1.lastPlayerType == PLAYER_TAINTED,
    string.format("F4(a1): lastPlayerType se actualiza al nuevo tipo (fue %s)", tostring(d1.lastPlayerType)))

  -- Estabilidad: el siguiente frame con el mismo tipo ni resetea ni re-kitea.
  local kitsAfterSwitch = p.addCollectibleCalls
  playerCb(nil, p)
  local d2 = Core.GetPlayerData(p)
  check(d2.initializedStartingItems == true, "F4(a2): sin cambio de tipo el kit sigue concedido")
  check(p.addCollectibleCalls == kitsAfterSwitch, "F4(a2): sin cambio de tipo no se re-concede kit")
  check(d2.lastPlayerType == PLAYER_TAINTED, "F4(a2): sin cambio de tipo lastPlayerType estable")

  -- Sin cambio de tipo NO hay reset (estado sucio sobrevive).
  d2.willpower = 33.0
  playerCb(nil, p)
  check(Core.GetPlayerData(p).willpower == 33.0,
    "F4(a3): sin cambio de tipo no se resetea willpower")
end

-- ===================== (b) tainted_rings: dueno no-Tainted -> 0 disparos en 120 frames =====================
Core.GL._cbs = {}
local trFactory = loadModule("modules/tainted_rings.lua")
trFactory(Core)
local orbitCb = nil
do
  local postCbs = {}
  for _, c in ipairs(Core.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_UPDATE then table.insert(postCbs, c.fn) end
  end
  check(#postCbs >= 2, "F4(b0): tainted_rings.lua registra 2 callbacks MC_POST_UPDATE (consumo + orbita)")
  orbitCb = postCbs[#postCbs] -- el de orbita/disparo es el ultimo registrado
end

local function makeEnemy(x, y)
  return {
    Position = Vector.new(x, y),
    Velocity = Vector.new(0, 0),
    IsActiveEnemy = function(_) return true end,
    IsVulnerableEnemy = function() return true end,
    HasEntityFlags = function(_) return false end,
  }
end
local function makeFamiliar(owner, ringIdx, x, y)
  local fam = {
    Position = Vector.new(x, y),
    Velocity = Vector.new(1, 1),
    SpawnerEntity = owner,
    _fd = { isStolenRing = true, ringIndex = ringIdx },
  }
  function fam:GetData() return self._fd end
  function fam:ToFamiliar() return self end
  function fam:GetSprite() return { Color = nil } end
  function fam:ToPlayer() return nil end
  return fam
end

if orbitCb then
  -- Dueno NO Tainted (Isaac base) con 2 anillos robados huerfanos + enemigo a tiro.
  local ownerOther = makePlayer(0, PLAYER_OTHER)
  _testPlayers = { [0] = ownerOther }
  local f1 = makeFamiliar(ownerOther, 1, 10, 0)
  local f2 = makeFamiliar(ownerOther, 2, -10, 0)
  -- Los familiares deben exponer ToPlayer via SpawnerEntity: el mock de player
  -- necesita ToPlayer; se lo anadimos sin tocar el modulo.
  function ownerOther:ToPlayer() return ownerOther end
  _testFamiliars = { f1, f2 }
  _testEnemies = { makeEnemy(100, 0) }
  _pickups = {}
  _inputPressed = false
  local p1x, p1y = f1.Position.X, f1.Position.Y
  tearSpawnCount = 0
  for f = 1, 120 do
    _frameCount = f
    orbitCb(nil)
  end
  check(tearSpawnCount == 0,
    string.format("F4(b1): dueno no-Tainted -> 0 disparos en 120 frames (hubo %d)", tearSpawnCount))
  check(f1.Position.X == p1x and f1.Position.Y == p1y,
    "F4(b1): dueno no-Tainted -> familiares ni se mueven (skip total)")

  -- Control positivo: dueno Tainted SI dispara (>0 en 120 frames).
  local ownerTainted = makePlayer(0, PLAYER_TAINTED)
  function ownerTainted:ToPlayer() return ownerTainted end
  ownerTainted.Damage = 5.0
  _testPlayers = { [0] = ownerTainted }
  local g1 = makeFamiliar(ownerTainted, 1, 10, 0)
  _testFamiliars = { g1 }
  _testEnemies = { makeEnemy(100, 0) }
  tearSpawnCount = 0
  for f = 1, 120 do
    _frameCount = f
    orbitCb(nil)
  end
  check(tearSpawnCount > 0,
    string.format("F4(b2): control positivo Tainted dispara >0 en 120 frames (hubo %d)", tearSpawnCount))
end

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_playertype_reset] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
