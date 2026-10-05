-- tools/test_tainted_rings_cap.lua
-- F1: cap de Stolen Rings con anti-spam buzz.
-- Spec:
--   a cap (stolenRings >= MAX_STOLEN_RINGS): early-return tras buzz,
--     SIN spawnear familiar, SIN ent:Remove(), CON ringConsumeCooldown = 15.
--   bajo cap: +1 anillo + 1 familiar + 1 Remove (rama no-cap intacta).
-- Compatible con Lua 5.1. Mocks: Isaac / SFX / player / ent.

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
ModCallbacks = { MC_POST_NEW_ROOM = 1001, MC_POST_UPDATE = 1002 }
RoomType = { ROOM_ANGEL = 4 }
EntityType = { ENTITY_PICKUP = 5, ENTITY_FAMILIAR = 3, ENTITY_TEAR = 2 }
PickupVariant = { PICKUP_COLLECTIBLE = 100 }
EntityPartition = { PICKUP = 1 }
SoundEffect = { SOUND_BOSS2INTRO_ERRORBUZZ = 999 }
CacheFlag = { CACHE_DAMAGE = 2 }
FamiliarVariant = { BLUE_FLY = 43 }
TearVariant = { BLUE = 0 }
TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 2 }
ButtonAction = { ACTION_DROP = 7 }
EntityFlag = { FLAG_FEAR = 1 }

-- ===================== CONTADORES / ESTADO =====================
local spawnCount = 0
local removeCount = 0
local buzzCount = 0
local happyCount = 0
local _pickups = {}
local _inputPressed = true
_testPlayer = nil
_frameCount = 0

-- ===================== STUBS ENGINE =====================
Input = {}
function Input.IsActionPressed(_, _) return _inputPressed end

function SFXManager()
  return {
    Play = function(_, sfx, _, _, _, _)
      if sfx == SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ then
        buzzCount = buzzCount + 1
      end
    end,
  }
end

function Game()
  return {
    GetNumPlayers = function() return 1 end,
    GetFrameCount = function() return _frameCount or 0 end,
    GetLevel = function() return { GetCurrentRoomIndex = function() return 0 end } end,
    GetRoom = function()
      return {
        GetType = function() return RoomType.ROOM_ANGEL end,
        GetRenderMode = function() return nil end,
        GetCenterPos = function() return Vector.new(0, 0) end,
      }
    end,
    GetHUD = function() return { IsVisible = function() return true end } end,
  }
end

Isaac = {}
function Isaac.GetPlayer(_) return _testPlayer end
function Isaac.FindByType() return {} end
function Isaac.GetRoomEntities() return {} end
function Isaac.FindInRadius(_, _, _) return _pickups end
function Isaac.Spawn(_, _, _, _, _, _)
  spawnCount = spawnCount + 1
  local fam = {}
  function fam:ToFamiliar() return fam end
  function fam:ToTear() return nil end
  function fam:GetData() return {} end
  function fam:GetSprite() return { Color = nil } end
  return fam
end
function Isaac.WorldToScreen(v) return v end

-- ===================== STUB CORE =====================
local Core = {}
Core.GL = {
  _cbs = {},
  AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
}
Core.MAX_STOLEN_RINGS = 10
Core.STOLEN_RING_DMG = 0.3
local dataByPlayer = {}
function Core.GetPlayerData(player)
  if not dataByPlayer[player.Index] then
    dataByPlayer[player.Index] = { stolenRings = 0, ringConsumeCooldown = 0 }
  end
  return dataByPlayer[player.Index]
end
function Core.IsTaintedHal(p) return p._isTainted == true end
function Core.IsHalJordan(p) return p._isHal == true end
function Core.SetEntityScaleAndColor() end

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else
    failures = failures + 1
    io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
  end
end

local function makeTaintedPlayer(idx)
  return {
    Index = idx or 0,
    _isHal = false, _isTainted = true,
    Position = Vector.new(0, 0),
    ControllerIndex = 0,
    Damage = 5.0,
    AddCacheFlags = function() end,
    EvaluateItems = function() end,
    AnimateHappy = function() happyCount = happyCount + 1 end,
  }
end

local function makePickup()
  local removed = false
  local ent = {}
  function ent:GetData() return { canBeConsumedByHal = true } end
  function ent:Remove() removed = true; removeCount = removeCount + 1 end
  function ent:isRemoved() return removed end
  ent.Position = Vector.new(10, 0)
  return ent
end

local function loadTaintedRings()
  Core.GL._cbs = {}
  -- Lua 5.1 (harness) no parsea `|` (OR bit a bit, sintaxis 5.3+ usada en
  -- tainted_rings.lua para TearFlags). Preprocesamos la fuente sustituyendo
  -- `|` por `+` (flags disjuntos: equivale a OR) antes de cargarla.
  local f = assert(io.open("modules/tainted_rings.lua", "r"))
  local src = f:read("*a")
  f:close()
  src = src:gsub("|", "+")
  local chunk = assert(loadstring(src, "modules/tainted_rings.lua"))
  local factory = chunk()
  factory(Core)
end

local function findPostUpdateCallbacks()
  local out = {}
  for _, c in ipairs(Core.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_UPDATE then table.insert(out, c.fn) end
  end
  return out
end

local function runPostUpdate()
  for _, fn in ipairs(findPostUpdateCallbacks()) do fn(nil) end
end

-- ===================== CARGA =====================
loadTaintedRings()
check(#findPostUpdateCallbacks() >= 1, "F1: tainted_rings.lua registra callback MC_POST_UPDATE")

-- ===================== (1) A CAP: 0 spawns + 0 removes + buzz con cooldown =====================
dataByPlayer = {}
spawnCount, removeCount, buzzCount, happyCount = 0, 0, 0, 0
local capPlayer = makeTaintedPlayer(0)
_testPlayer = capPlayer
dataByPlayer[capPlayer.Index] = { stolenRings = Core.MAX_STOLEN_RINGS, ringConsumeCooldown = 0 }
local capEnt = makePickup()
_pickups = { capEnt }
_inputPressed = true
runPostUpdate()
local dCap = dataByPlayer[capPlayer.Index]
check(spawnCount == 0,
  string.format("F1(cap): 0 spawns a cap, hubo %d", spawnCount))
check(removeCount == 0,
  string.format("F1(cap): 0 removes a cap, hubo %d", removeCount))
check(buzzCount == 1,
  string.format("F1(cap): buzz 1 vez a cap, hubo %d", buzzCount))
check(dCap.ringConsumeCooldown == 15,
  string.format("F1(cap): cooldown=15 anti-spam a cap, fue %s", tostring(dCap.ringConsumeCooldown)))
check(dCap.stolenRings == Core.MAX_STOLEN_RINGS,
  string.format("F1(cap): stolenRings queda en cap %d, fue %s", Core.MAX_STOLEN_RINGS, tostring(dCap.stolenRings)))

-- ===================== (2) BAJO CAP: +1 anillo + 1 familiar + 1 Remove =====================
dataByPlayer = {}
spawnCount, removeCount, buzzCount, happyCount = 0, 0, 0, 0
local lowPlayer = makeTaintedPlayer(0)
_testPlayer = lowPlayer
dataByPlayer[lowPlayer.Index] = { stolenRings = 2, ringConsumeCooldown = 0 }
local lowEnt = makePickup()
_pickups = { lowEnt }
_inputPressed = true
runPostUpdate()
local dLow = dataByPlayer[lowPlayer.Index]
check(dLow.stolenRings == 3,
  string.format("F1(nocap): stolenRings 2->3, fue %s", tostring(dLow.stolenRings)))
check(spawnCount == 1,
  string.format("F1(nocap): 1 familiar spawneado, hubo %d", spawnCount))
check(removeCount == 1,
  string.format("F1(nocap): 1 Remove del pickup, hubo %d", removeCount))
check(dLow.ringConsumeCooldown == 15,
  string.format("F1(nocap): cooldown=15 tras consumir, fue %s", tostring(dLow.ringConsumeCooldown)))
check(buzzCount == 0,
  string.format("F1(nocap): sin buzz bajo cap, hubo %d", buzzCount))

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_tainted_rings_cap] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
