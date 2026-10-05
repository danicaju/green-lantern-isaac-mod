-- tools/test_had_item_flight.lua
-- F3: Hal conserva vuelo de items tras depletar; revoca solo el del anillo.
-- Spec:
--   core.lua: GetPlayerData incluye hadItemFlight = false.
--   stats.lua CACHE_FLYING Hal: activo -> data.hadItemFlight = player.CanFly
--     (muestra base ANTES de conceder) y player.CanFly = true;
--     depletado -> player.CanFly = data.hadItemFlight and true or false.
--   Tainted intacto (siempre vuela).
-- Compatible Lua 5.1. Mocks: player/Core/Game.

-- ===================== ENUMS =====================
ModCallbacks = { MC_EVALUATE_CACHE = 1008 }
CacheFlag = { CACHE_FLYING = 16, CACHE_DAMAGE = 2 }
TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 2 }

-- ===================== STUBS ENGINE =====================
function Game()
  return {
    GetLevel = function()
      return { GetCurrentRoomIndex = function() return 0 end }
    end,
  }
end

-- ===================== STUB CORE (mock) =====================
local Core = {}
Core.GL = {
  _cbs = {},
  AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
}
Core.WILLPOWER_MAX = 100.0
Core.HAL_SPEED_BONUS = 0.15
Core.HAL_SHOT_SPEED_BONUS = 0.30
Core.TAINTED_DMG_MULTIPLIER = 1.5
Core.TAINTED_TEARS_PENALTY = -1.5
Core.MAX_STOLEN_RINGS = 10
Core.STOLEN_RING_DMG = 0.3
Core.OVERCHARGE_T1_MULT = 1.15
Core.OVERCHARGE_T2_MULT = 1.25

local dataByPlayer = {}
function Core.GetPlayerData(player)
  if not dataByPlayer[player.Index] then
    dataByPlayer[player.Index] = {
      willpower = Core.WILLPOWER_MAX,
      ringDepleted = false,
      hadItemFlight = false,
      overcharge = false,
      overchargeRoomIdx = -1,
    }
  end
  return dataByPlayer[player.Index]
end
function Core.IsHalJordan(p) return p._isHal == true end
function Core.IsTaintedHal(p) return p._isTainted == true end
function Core.HasGreenLanternRing(_) return false end

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else
    failures = failures + 1
    io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
  end
end

local function makeHal(idx)
  return { Index = idx or 0, _isHal = true, _isTainted = false, CanFly = false }
end

local function makeTainted(idx)
  return { Index = idx or 0, _isHal = false, _isTainted = true, CanFly = false }
end

local function loadStats()
  Core.GL._cbs = {}
  local f = assert(io.open("modules/stats.lua", "r"))
  local src = f:read("*a")
  f:close()
  -- Lua 5.1 (harness) no parsea `|` (OR bit a bit, sintaxis 5.3+ usada en
  -- stats.lua para TearFlags). Preprocesamos sustituyendo `|` por `+`
  -- (flags disjuntos: equivale a OR) antes de cargarla.
  src = src:gsub("|", "+")
  local chunk = assert(loadstring(src, "modules/stats.lua"))
  local factory = chunk()
  factory(Core)
end

local function findEvalCache()
  local out = {}
  for _, c in ipairs(Core.GL._cbs) do
    if c.id == ModCallbacks.MC_EVALUATE_CACHE then table.insert(out, c.fn) end
  end
  return out
end

local function runFlying(player)
  for _, fn in ipairs(findEvalCache()) do
    fn(nil, player, CacheFlag.CACHE_FLYING)
  end
end

-- ===================== CARGA =====================
loadStats()
check(#findEvalCache() >= 1, "F3: stats.lua registra callback MC_EVALUATE_CACHE")

-- ===================== (1) Hal sin alas + anillo activo -> vuela + flag false =====================
dataByPlayer = {}
local p1 = makeHal(1)
p1.CanFly = false
dataByPlayer[p1.Index] = {
  willpower = Core.WILLPOWER_MAX, ringDepleted = false,
  hadItemFlight = false, overcharge = false, overchargeRoomIdx = -1,
}
runFlying(p1)
check(p1.CanFly == true, "F3(1): Hal sin alas activo vuela")
check(dataByPlayer[p1.Index].hadItemFlight == false,
  string.format("F3(1): Hal sin alas activo flag=false, fue %s",
    tostring(dataByPlayer[p1.Index].hadItemFlight)))

-- ===================== (2) Hal con alas + anillo activo -> flag true =====================
dataByPlayer = {}
local p2 = makeHal(2)
p2.CanFly = true
dataByPlayer[p2.Index] = {
  willpower = Core.WILLPOWER_MAX, ringDepleted = false,
  hadItemFlight = false, overcharge = false, overchargeRoomIdx = -1,
}
runFlying(p2)
check(p2.CanFly == true, "F3(2): Hal con alas activo vuela")
check(dataByPlayer[p2.Index].hadItemFlight == true,
  string.format("F3(2): Hal con alas activo flag=true, fue %s",
    tostring(dataByPlayer[p2.Index].hadItemFlight)))

-- ===================== (3) Depletado con alas -> sigue volando =====================
dataByPlayer = {}
local p3 = makeHal(3)
p3.CanFly = false -- motor recalcula sin el anillo; la base de items vive en hadItemFlight
dataByPlayer[p3.Index] = {
  willpower = 0.0, ringDepleted = true,
  hadItemFlight = true, overcharge = false, overchargeRoomIdx = -1,
}
runFlying(p3)
check(p3.CanFly == true, "F3(3): depletado con alas sigue volando")

-- ===================== (4) Depletado sin alas -> cae =====================
dataByPlayer = {}
local p4 = makeHal(4)
p4.CanFly = true -- venia volando por el anillo; sin base de items debe caer
dataByPlayer[p4.Index] = {
  willpower = 0.0, ringDepleted = true,
  hadItemFlight = false, overcharge = false, overchargeRoomIdx = -1,
}
runFlying(p4)
check(p4.CanFly == false, "F3(4): depletado sin alas cae")

-- ===================== (5) Tainted intacto =====================
dataByPlayer = {}
local p5 = makeTainted(5)
p5.CanFly = false
dataByPlayer[p5.Index] = {
  willpower = Core.WILLPOWER_MAX, ringDepleted = false,
  hadItemFlight = false, overcharge = false, overchargeRoomIdx = -1,
  stolenRings = 0,
}
runFlying(p5)
check(p5.CanFly == true, "F3(5): Tainted intacto vuela")

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_had_item_flight] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
