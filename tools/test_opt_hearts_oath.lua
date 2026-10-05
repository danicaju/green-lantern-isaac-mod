-- tools/test_opt_hearts_oath.lua
-- OPT2: vetos BLENDED/ETERNAL en Tainted Hal (golden permitido) + oathTextTimer
-- congelado cuando el juego esta congelado (POST_RENDER 60Hz vs Game frame).
-- Compatible Lua 5.1. Ejecutar desde la raiz del mod:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tools/test_opt_hearts_oath.lua

-- ===================== STUBS BASE =====================
Vector = {}
local VectorMT = {}
VectorMT.__add = function(a, b)
  if type(b) == "number" then return Vector.new(a.X + b, a.Y + b) end
  return Vector.new(a.X + b.X, a.Y + b.Y)
end
VectorMT.__sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
function Vector.new(x, y)
  local u = setmetatable({ X = x or 0, Y = y or 0 }, { __index = Vector, __add = VectorMT.__add, __sub = VectorMT.__sub })
  return u
end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
  local l = self:Length()
  if l <= 0.001 then return Vector.new(1, 0) end
  return Vector.new(self.X / l, self.Y / l)
end

ModCallbacks = {
  MC_POST_UPDATE = 1,
  MC_POST_PEFFECT_UPDATE = 5,
  MC_PRE_PICKUP_COLLISION = 23,
  MC_POST_RENDER = 32,
  MC_PRE_PLAYER_RENDER = 31,
  MC_POST_PLAYER_RENDER = 33,
}

PickupVariant = { PICKUP_HEART = 10 }
HeartSubType = {
  HEART_FULL = 1,
  HEART_HALF = 2,
  HEART_DOUBLEPACK = 3,
  HEART_SCARED = 4,
  HEART_ROTTEN = 5,
  HEART_BONE = 6,
  HEART_BLENDED = 7,
  HEART_ETERNAL = 8,
  HEART_GOLDEN = 9,
}

_testPlayer = nil
_frameCount = 0

Isaac = {}
function Isaac.GetPlayer(_) return _testPlayer end
function Isaac.WorldToScreen(v) return v end
Isaac.RenderScaledText = function() end

function Game() return {
  GetNumPlayers = function() return 1 end,
  GetFrameCount = function() return _frameCount or 0 end,
  GetLevel = function() return { GetCurrentRoomIndex = function() return 0 end } end,
  GetRoom = function() return { GetRenderMode = function() return nil end } end,
  GetHUD = function() return { IsVisible = function() return true end } end,
} end

Options = { HUDOffset = 0 }

-- ===================== STUB CORE =====================
local Core = {}
Core.GL = {
  _cbs = {},
  AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
}
Core.WILLPOWER_MAX = 100.0
Core.SPARK_MAX = 100.0

local dataByPlayer = {}
function Core.GetPlayerData(player)
  if not dataByPlayer[player.Index] then
    dataByPlayer[player.Index] = {
      willpower = Core.WILLPOWER_MAX,
      emeraldSparks = 0,
      stolenRings = 0,
      ringDepleted = false,
      overcharge = false,
      oathText = "",
      oathTextTimer = 0,
      wasHoldingShootOnRender = false,
      shootHoldFrames = 0,
      isFiringContinuousBeam = false,
    }
  end
  return dataByPlayer[player.Index]
end
Core.IsHalJordan = function(p) return p._isHal end
Core.IsTaintedHal = function(p) return p._isTainted end
Core.EnforceTaintedHalNoRedHearts = function(_) end

local drawTextCalls = {}
Core.DrawHudText = function(text, x, y, r, g, b, a)
  table.insert(drawTextCalls, { text = text, x = x, y = y, r = r, g = g, b = b, a = a })
end
Core.RenderGLSparkDrops = function() end
Core.RenderGLPlayerAura = function() end
Core.RenderGLSolidShieldBehind = function() end
Core.RenderGLSolidShieldFront = function() end
Core.RenderGLActiveItemAndTrinketEffects = function() end
Core.RenderGLBeamAndFlareForPlayer = function() end
Core.IsRingActive = function() return false end
Core.IsPlayerAimingUpForRender = function() return false end
Core.EnsureEIDRegistered = function() end
Core.RegisterStageAPIGraphics = function() end
Core.StopContinuousBeam = function() end

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else
    failures = failures + 1
    io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
  end
end

local function makeTainted(idx)
  return {
    Index = idx or 0,
    _isHal = false, _isTainted = true,
    Position = Vector.new(0, 0),
    GetShootingInput = function() return Vector.new(0, 0) end,
    ToPlayer = function(self) return self end,
  }
end
local function makeHal(idx)
  return {
    Index = idx or 0,
    _isHal = true, _isTainted = false,
    Position = Vector.new(0, 0),
    GetShootingInput = function() return Vector.new(0, 0) end,
    ToPlayer = function(self) return self end,
  }
end

local function findCb(id)
  for _, c in ipairs(Core.GL._cbs) do
    if c.id == id then return c.fn end
  end
  return nil
end

-- ===================== CARGA MODULOS =====================
local fHearts = assert(loadstring(assert(io.open("modules/tainted_hearts.lua", "r")):read("*a"), "tainted_hearts.lua"))
fHearts()(Core)
local pickupCb = findCb(ModCallbacks.MC_PRE_PICKUP_COLLISION)
check(pickupCb ~= nil, "OPT(hearts): tainted_hearts.lua registra MC_PRE_PICKUP_COLLISION")

local fHud = assert(loadstring(assert(io.open("modules/hud_render.lua", "r")):read("*a"), "hud_render.lua"))
fHud()(Core)
local postCb = findCb(ModCallbacks.MC_POST_RENDER)
check(postCb ~= nil, "OPT(oath): hud_render.lua registra MC_POST_RENDER")

local function isVetoed(sub)
  local p = makeTainted(0)
  _testPlayer = p
  local pickup = { Variant = PickupVariant.PICKUP_HEART, SubType = sub }
  local collider = { ToPlayer = function() return p end }
  return pickupCb(nil, pickup, collider, false) == true
end

-- ===================== (1) VETO BLENDED =====================
check(isVetoed(HeartSubType.HEART_BLENDED),
  "OPT(1): Tainted Hal veta corazon BLENDED (bloquea pickup)")

-- ===================== (2) VETO ETERNAL =====================
check(isVetoed(HeartSubType.HEART_ETERNAL),
  "OPT(2): Tainted Hal veta corazon ETERNAL (bloquea pickup)")

-- ===================== (3) GOLDEN PERMITIDO =====================
check(not isVetoed(HeartSubType.HEART_GOLDEN),
  "OPT(3): Tainted Hal permite corazon GOLDEN (no bloquea pickup)")

-- ===================== (4) FREEZE NO CONSUME TIMER =====================
dataByPlayer = {}
drawTextCalls = {}
local hal = makeHal(0)
_testPlayer = hal
dataByPlayer[hal.Index] = {
  willpower = 100.0, emeraldSparks = 0, stolenRings = 0,
  ringDepleted = false, overcharge = false,
  oathText = "IN BRIGHTEST DAY...", oathTextTimer = 90,
  wasHoldingShootOnRender = false, shootHoldFrames = 0,
  isFiringContinuousBeam = false,
}
_frameCount = 10 -- par: el primer render avanza y decrementa 90 -> 89
postCb()
check(dataByPlayer[hal.Index].oathTextTimer == 89,
  string.format("OPT(4a): frame par que avanza decrementa 90->89, fue %s",
    tostring(dataByPlayer[hal.Index].oathTextTimer)))
-- Mismo Game frame congelado: POST_RENDER repite pero el timer NO debe moverse
postCb()
check(dataByPlayer[hal.Index].oathTextTimer == 89,
  string.format("OPT(4b): juego congelado NO consume oathTextTimer (sigue 89), fue %s",
    tostring(dataByPlayer[hal.Index].oathTextTimer)))
-- El juego avanza a otro par: vuelve a decrementar 89 -> 88
_frameCount = 12
postCb()
check(dataByPlayer[hal.Index].oathTextTimer == 88,
  string.format("OPT(4c): al avanzar a frame par decrementa 89->88, fue %s",
    tostring(dataByPlayer[hal.Index].oathTextTimer)))

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_opt_hearts_oath] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
