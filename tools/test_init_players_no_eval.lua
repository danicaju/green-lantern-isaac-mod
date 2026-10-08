-- tools/test_init_players_no_eval.lua
-- Regression test: MC_POST_PLAYER_INIT must NEVER call player:EvaluateItems().
-- Calling EvaluateItems during player initialization crashes Isaac with an
-- uncatchable C++ access violation minidump when continuing an existing run.
-- Compatible with Lua 5.1.

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end

-- ===================== STUBS =====================
Vector = {}
function Vector.new(x, y) return { X = x or 0, Y = y or 0 } end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector.Zero() return Vector.new(0, 0) end

function Color(r, g, b, a, ro, go, bo)
  return { R = r or 0, G = g or 0, B = b or 0, A = a or 0, ROff = ro, GOff = go, BOff = bo }
end

ModCallbacks = {
  MC_POST_GAME_STARTED = 2001,
  MC_POST_PLAYER_INIT = 2004,
}

CacheFlag = {
  CACHE_FLYING = 1,
  CACHE_SPEED = 2,
  CACHE_DAMAGE = 4,
  CACHE_SHOTSPEED = 8,
  CACHE_TEARFLAG = 16,
  CACHE_FIREDELAY = 32,
}

function RegisterMod(_, _)
  local mod = { _cbs = {} }
  function mod:AddCallback(cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end
  return mod
end

local Core = dofile("modules/core.lua")

local itemIDsLoaded = false
local coastCitiesCleared = false
local emblemDropsCleared = false

Core.LoadItemIDs = function() itemIDsLoaded = true end
Core.ClearAllCoastCities = function() coastCitiesCleared = true end
Core.ClearAllLanternEmblemDrops = function() emblemDropsCleared = true end

local function makePlayer(isHal, isTainted)
  local p = {
    _data = {},
    _isHal = isHal,
    _isTainted = isTainted,
    evaluateCalls = 0,
    addCacheCalls = 0,
  }
  function p:GetData() return self._data end
  function p:AddCacheFlags(_) self.addCacheCalls = self.addCacheCalls + 1 end
  function p:EvaluateItems()
    self.evaluateCalls = self.evaluateCalls + 1
    error("EvaluateItems called in MC_POST_PLAYER_INIT! This crashes Isaac on continue!")
  end
  return p
end

Core.IsHalJordan = function(p) return p._isHal == true end
Core.IsTaintedHal = function(p) return p._isTainted == true end

-- ===================== LOAD MODULE =====================
local f = assert(io.open("modules/init_players.lua", "r"))
local src = f:read("*a")
f:close()
src = src:gsub("|", "+")
local chunk, err = loadstring(src, "modules/init_players.lua")
assert(chunk, tostring(err))
local factory = chunk()
factory(Core)

local initCb, gameStartCb = nil, nil
for _, c in ipairs(Core.GL._cbs) do
  if c.id == ModCallbacks.MC_POST_PLAYER_INIT then initCb = c.fn end
  if c.id == ModCallbacks.MC_POST_GAME_STARTED then gameStartCb = c.fn end
end

check(initCb ~= nil, "init_players: MC_POST_PLAYER_INIT registered")
check(gameStartCb ~= nil, "init_players: MC_POST_GAME_STARTED registered")

-- ===================== TEST HAL JORDAN INIT =====================
do
  local hal = makePlayer(true, false)
  local ok, callErr = pcall(function() initCb(nil, hal) end)
  check(ok, string.format("Hal Jordan init does not throw error: %s", tostring(callErr)))
  check(hal.evaluateCalls == 0, "Hal Jordan init does NOT call EvaluateItems")
  check(hal.addCacheCalls == 1, "Hal Jordan init safely adds cache flags")
  local d = Core.GetPlayerData(hal)
  check(d.willpower == Core.WILLPOWER_MAX, "Hal Jordan init sets willpower to MAX")
  check(d.ringDepleted == false, "Hal Jordan init sets ringDepleted to false")
end

-- ===================== TEST TAINTED HAL INIT =====================
do
  local thal = makePlayer(false, true)
  local ok, callErr = pcall(function() initCb(nil, thal) end)
  check(ok, string.format("Tainted Hal init does not throw error: %s", tostring(callErr)))
  check(thal.evaluateCalls == 0, "Tainted Hal init does NOT call EvaluateItems")
  check(thal.addCacheCalls == 1, "Tainted Hal init safely adds cache flags")
  local d = Core.GetPlayerData(thal)
  check(d.emeraldSparks == 0.0, "Tainted Hal init sets emeraldSparks to 0.0")
  check(d.stolenRings == 0, "Tainted Hal init sets stolenRings to 0")
end

-- ===================== TEST GAME STARTED =====================
do
  itemIDsLoaded = false
  coastCitiesCleared = false
  emblemDropsCleared = false
  gameStartCb(nil, false)
  check(itemIDsLoaded, "MC_POST_GAME_STARTED loads item IDs")
  check(coastCitiesCleared, "MC_POST_GAME_STARTED clears coast cities")
  check(emblemDropsCleared, "MC_POST_GAME_STARTED clears emblem drops")
end

-- ===================== SUMMARY =====================
io.stderr:write(string.format("\n[test_init_players_no_eval] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
