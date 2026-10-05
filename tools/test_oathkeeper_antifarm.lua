-- tools/test_oathkeeper_antifarm.lua
-- F8a: antifarm Oathkeeper. El bonus (soul hearts / sparks 20) solo se otorga
-- una vez por run via flag por-jugador data.oathGrantedThisRun.
-- Spec:
--   1. Doble INIT mismo run -> solo 1 otorga (soul hearts 1 vez, flag true).
--   2. Sparks 55 intactos (math.max, no overwrite 55->20).
--   3. Sparks 0 -> 20 (piso minimo).
-- Compatible con Lua 5.1.

-- ===================== STUBS =====================
ModCallbacks = {
  MC_POST_GAME_STARTED = 1,
  MC_POST_NEW_LEVEL = 2,
  MC_POST_PLAYER_INIT = 3,
}
LevelStage = { STAGE3_1 = 3 }
json = {
  encode = function(_) return "{}" end,
  decode = function(_) return {} end,
}
function Game()
  return {
    GetNumPlayers = function() return 1 end,
    GetFrameCount = function() return 0 end,
    GetLevel = function()
      return { GetStage = function() return 0 end }
    end,
  }
end
Isaac = {}
function Isaac.GetPlayer(_) return nil end

-- ===================== CORE STUB =====================
local Core = {}
Core.GL = {
  _cbs = {},
  AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
  SaveModData = function(_) end,
  HasModData = function() return false end,
  LoadModData = function() return "{}" end,
}
Core.Progress = nil -- lo crea progress.lua
Core.SPARK_MAX = 100.0
function Core.GetPlayerData(player)
  local d = player:GetData()
  if not d.GreenLantern then
    d.GreenLantern = { emeraldSparks = 0.0 }
  end
  return d.GreenLantern
end
function Core.IsHalJordan(p) return p._isHal == true end
function Core.IsTaintedHal(p) return p._isTainted == true end

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
  local store = {}
  return {
    Index = idx or 0,
    _isHal = true, _isTainted = false,
    _store = store,
    _soulCount = 0,
    GetData = function(self) return self._store end,
    AddSoulHearts = function(self, n)
      self._soulCount = (self._soulCount or 0) + (n or 0)
    end,
    GetSoulCount = function(self) return self._soulCount or 0 end,
  }
end

local function makeTainted(idx, sparks)
  local store = { GreenLantern = { emeraldSparks = sparks or 0.0 } }
  return {
    Index = idx or 0,
    _isHal = false, _isTainted = true,
    _store = store,
    GetData = function(self) return self._store end,
  }
end

local function loadProgress()
  Core.GL._cbs = {}
  local factory = dofile("modules/progress.lua")
  factory(Core)
end

local function findInitCallback()
  for _, c in ipairs(Core.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_PLAYER_INIT then return c.fn end
  end
  return nil
end

-- ===================== CARGA =====================
loadProgress()
local initCb = findInitCallback()
check(initCb ~= nil, "F8a: progress.lua registra callback MC_POST_PLAYER_INIT")

-- ===================== (1) Doble INIT Hal mismo run -> 1 otorga =====================
Core.Progress.oathkeeperHal = true
Core.Progress.oathkeeperTainted = false
local hal = makeHal(0)
initCb(nil, hal)
initCb(nil, hal)
local halData = Core.GetPlayerData(hal)
check(hal:GetSoulCount() == 2,
  string.format("F8a(1): doble INIT Hal mismo run otorga 1 vez (2 soul hearts), fue %s", tostring(hal:GetSoulCount())))
check(halData.oathGrantedThisRun == true,
  "F8a(1): flag data.oathGrantedThisRun queda true tras otorgar (Hal)")

-- ===================== (2) Sparks 55 intactos =====================
Core.Progress.oathkeeperHal = false
Core.Progress.oathkeeperTainted = true
local t55 = makeTainted(0, 55.0)
initCb(nil, t55)
local d55 = Core.GetPlayerData(t55)
check(d55.emeraldSparks == 55.0,
  string.format("F8a(2): sparks 55 intactos tras INIT (math.max, no overwrite), fue %s", tostring(d55.emeraldSparks)))
check(d55.oathGrantedThisRun == true,
  "F8a(2): flag data.oathGrantedThisRun queda true tras otorgar (Tainted 55)")
-- Segundo INIT no debe pisar ni re-otorgar.
initCb(nil, t55)
local d55b = Core.GetPlayerData(t55)
check(d55b.emeraldSparks == 55.0,
  string.format("F8a(2b): doble INIT no pisa sparks 55, fue %s", tostring(d55b.emeraldSparks)))

-- ===================== (3) Sparks 0 -> 20 =====================
local t0 = makeTainted(1, 0.0)
initCb(nil, t0)
local d0 = Core.GetPlayerData(t0)
check(d0.emeraldSparks == 20.0,
  string.format("F8a(3): sparks 0 -> 20 piso minimo, fue %s", tostring(d0.emeraldSparks)))
check(d0.oathGrantedThisRun == true,
  "F8a(3): flag data.oathGrantedThisRun queda true tras otorgar (Tainted 0->20)")

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_oathkeeper_antifarm] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
