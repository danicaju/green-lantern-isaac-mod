-- tools/test_save_continue.lua
-- F8b: persistencia save/continue de run (willpower/sparks/rings/tier).
--   (1) save->load identicos; (2) corrupto/vacio->defaults sin crash + clamp
--       de rangos; (3) 2P sin cross-talk; (4) sin isContinued no restaura.
-- F8c: slot COMPARTIDO SaveModData con secciones namespaced {oath, run}.
--   progress.lua posee `oath`; save_run.lua posee `run`; ambos hacen
--   read-modify-write (cargar todo, actualizar solo su seccion, guardar todo).
--   (5) unlock -> exit -> continue: oath Y run sobreviven;
--   (6) unlock tras exit no borra run;
--   (7) slot corrupto -> defaults por seccion sin crash ni cross-talk.
-- Compatible con Lua 5.1. Ejecutar desde la raiz del mod:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tools/test_save_continue.lua

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
ModCallbacks = { MC_POST_GAME_STARTED = 2001, MC_POST_NEW_LEVEL = 2002, MC_PRE_GAME_EXIT = 2003, MC_POST_PLAYER_INIT = 2004 }
CacheFlag = { CACHE_FLYING = 1, CACHE_SPEED = 2, CACHE_DAMAGE = 4, CACHE_SHOTSPEED = 8, CACHE_TEARFLAG = 16 }
LevelStage = { STAGE3_1 = 3 }

-- Slot unico de SaveModData, como en Isaac real (un string por mod).
local _modDataStore = nil
local _modDataExists = false

function RegisterMod(_, _) -- stub para modules/core.lua real
  local mod = { _cbs = {} }
  function mod:AddCallback(cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end
  function mod:SaveModData(s) _modDataStore = s; _modDataExists = true end
  function mod:LoadModData() return _modDataStore end
  function mod:HasModData() return _modDataExists end
  return mod
end

_testStage = 1
_testPlayers = {}
function Game()
  return {
    GetNumPlayers = function() return #_testPlayers end,
    GetFrameCount = function() return 0 end,
    GetLevel = function()
      return {
        GetCurrentRoomIndex = function() return 0 end,
        GetStage = function() return _testStage end,
      }
    end,
  }
end
Isaac = {}
function Isaac.GetPlayer(i) return _testPlayers[i + 1] end

-- ===================== STUB json (codec recursivo: tablas anidadas + booleanos) =====================
-- Soporta el slot compartido {oath = {...}, run = {["0"] = {...}}} y los
-- legados planos. Corrupto/vacio -> error (los modulos caen a defaults).
json = {}
local function jsonEncVal(v, out)
  local t = type(v)
  if t == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then
      out[#out + 1] = "0"
    else
      out[#out + 1] = string.format("%.17g", v)
    end
  elseif t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "table" then
    out[#out + 1] = "{"
    local first = true
    for k, vv in pairs(v) do
      if not first then out[#out + 1] = "," end
      first = false
      out[#out + 1] = string.format("%q", tostring(k))
      out[#out + 1] = ":"
      jsonEncVal(vv, out)
    end
    out[#out + 1] = "}"
  else
    error("json: unsupported type " .. t)
  end
end
function json.encode(v)
  local out = {}
  jsonEncVal(v, out)
  return table.concat(out)
end
function json.decode(s)
  if type(s) ~= "string" then error("json: expected string") end
  local pos, n = 1, #s
  local function skipWs()
    while pos <= n and s:sub(pos, pos):match("%s") do pos = pos + 1 end
  end
  local parseVal
  local function parseStr()
    pos = pos + 1 -- come '"'
    local buf = {}
    while pos <= n do
      local c = s:sub(pos, pos)
      if c == '"' then
        pos = pos + 1
        return table.concat(buf)
      elseif c == "\\" then
        local e = s:sub(pos + 1, pos + 1)
        if e == "n" then buf[#buf + 1] = "\n"
        elseif e == "r" then buf[#buf + 1] = "\r"
        elseif e == "t" then buf[#buf + 1] = "\t"
        elseif e == '"' then buf[#buf + 1] = '"'
        elseif e == "\\" then buf[#buf + 1] = "\\"
        else buf[#buf + 1] = e end
        pos = pos + 2
      else
        buf[#buf + 1] = c
        pos = pos + 1
      end
    end
    error("json: unterminated string")
  end
  local function parseNum()
    local ns, ne = s:find("^%-?%d+%.?%d*", pos)
    if not ns then error("json: bad number") end
    local es, ee = s:find("^[eE][%+%-]?%d+", ne + 1)
    if es then ne = ee end
    local num = tonumber(s:sub(ns, ne))
    if num == nil then error("json: bad number") end
    pos = ne + 1
    return num
  end
  local function parseObj()
    pos = pos + 1 -- come '{'
    local out = {}
    skipWs()
    if s:sub(pos, pos) == "}" then pos = pos + 1 return out end
    while true do
      skipWs()
      if s:sub(pos, pos) ~= '"' then error("json: expected key") end
      local k = parseStr()
      skipWs()
      if s:sub(pos, pos) ~= ":" then error("json: expected colon") end
      pos = pos + 1
      out[k] = parseVal()
      skipWs()
      local c = s:sub(pos, pos)
      if c == "," then pos = pos + 1
      elseif c == "}" then pos = pos + 1 return out
      else error("json: expected comma or close") end
    end
  end
  parseVal = function()
    skipWs()
    local c = s:sub(pos, pos)
    if c == "{" then return parseObj()
    elseif c == '"' then return parseStr()
    elseif c == "t" and s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
    elseif c == "f" and s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
    elseif c == "-" or c:match("%d") then return parseNum()
    else error("json: corrupt") end
  end
  local v = parseVal()
  skipWs()
  if pos <= n then error("json: trailing data") end
  if type(v) ~= "table" then error("json: top-level must be object") end
  return v
end

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end
local function feq(a, b) return math.abs((a or 0) - (b or 0)) < 1e-9 end

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

local function makePlayer(idx, isHal)
  local p = { Index = idx, _data = {}, _isHal = (isHal == true), _isTainted = false }
  function p:GetData() return self._data end
  function p:GetPlayerType() return 0 end
  return p
end
local function wipe(p) p._data = {} end
local function setRun(p, w, s, r, t)
  local d = Core.GetPlayerData(p)
  d.willpower, d.emeraldSparks, d.stolenRings, d.overchargeTier = w, s, r, t
end
local function getRun(p)
  local d = Core.GetPlayerData(p)
  return d.willpower, d.emeraldSparks, d.stolenRings, d.overchargeTier
end

local function cbsFor(id)
  local out = {}
  for _, c in ipairs(Core.GL._cbs) do
    if c.id == id then table.insert(out, c.fn) end
  end
  return out
end
local function fire(id, ...)
  for _, fn in ipairs(cbsFor(id)) do fn(nil, ...) end
end

-- ===================== (E1) core real + progress + save_run registran =====================
Core = dofile("modules/core.lua")
check(Core ~= nil, "F8b(E1): modules/core.lua carga")
-- ids.lua real necesita API del juego; stub minimo de identidad para el unlock.
Core.IsHalJordan = function(p) return p ~= nil and p._isHal == true end
Core.IsTaintedHal = function(p) return p ~= nil and p._isTainted == true end
local progressFactory = loadModule("modules/progress.lua")
check(type(progressFactory) == "function", "F8c(E1): modules/progress.lua retorna factory")
local saveFactory = loadModule("modules/save_run.lua")
check(type(saveFactory) == "function", "F8b(E1): modules/save_run.lua retorna factory")
progressFactory(Core) -- orden de main.lua: progress antes que save_run
saveFactory(Core)
check(#cbsFor(ModCallbacks.MC_PRE_GAME_EXIT) >= 1, "F8b(E1): save_run registra MC_PRE_GAME_EXIT")
check(#cbsFor(ModCallbacks.MC_POST_NEW_LEVEL) >= 2, "F8c(E1): progress + save_run registran MC_POST_NEW_LEVEL")
check(#cbsFor(ModCallbacks.MC_POST_GAME_STARTED) >= 2, "F8c(E1): progress + save_run registran MC_POST_GAME_STARTED")
check(#cbsFor(ModCallbacks.MC_POST_PLAYER_INIT) >= 1, "F8c(E1): progress registra MC_POST_PLAYER_INIT")

-- ===================== (1) save->load identicos (1P) =====================
do
  _testPlayers = { makePlayer(0) }
  _testStage = 1
  _modDataStore, _modDataExists = nil, false
  setRun(_testPlayers[1], 73.5, 42.25, 4, 1)
  fire(ModCallbacks.MC_PRE_GAME_EXIT)
  check(_modDataExists and type(_modDataStore) == "string" and #_modDataStore > 0,
    "F8b(1): PRE_GAME_EXIT guarda string no vacio via SaveModData")
  wipe(_testPlayers[1])
  fire(ModCallbacks.MC_POST_GAME_STARTED, true)
  local w, s, r, t = getRun(_testPlayers[1])
  check(feq(w, 73.5), string.format("F8b(1): willpower roundtrip 73.5 (fue %s)", tostring(w)))
  check(feq(s, 42.25), string.format("F8b(1): sparks roundtrip 42.25 (fue %s)", tostring(s)))
  check(r == 4, string.format("F8b(1): rings roundtrip 4 (fue %s)", tostring(r)))
  check(t == 1, string.format("F8b(1): tier roundtrip 1 (fue %s)", tostring(t)))
  print(string.format("[test_save_continue] save->load ok: willpower=%s sparks=%s rings=%s tier=%s", tostring(w), tostring(s), tostring(r), tostring(t)))
end

-- ===================== (2) corrupto/vacio->defaults + clamp =====================
do
  _testPlayers = { makePlayer(0) }
  _testStage = 1
  _modDataStore, _modDataExists = "!!!CORRUPT-NOT-JSON!!!", true
  setRun(_testPlayers[1], 10.0, 90.0, 9, 2)
  local ok = pcall(fire, ModCallbacks.MC_POST_GAME_STARTED, true)
  check(ok, "F8b(2): save corrupto no crashea al continuar")
  local w, s, r, t = getRun(_testPlayers[1])
  check(feq(w, Core.WILLPOWER_MAX), string.format("F8b(2): corrupto->willpower default MAX (fue %s)", tostring(w)))
  check(feq(s, 0), string.format("F8b(2): corrupto->sparks default 0 (fue %s)", tostring(s)))
  check(r == 0, string.format("F8b(2): corrupto->rings default 0 (fue %s)", tostring(r)))
  check(t == 0, string.format("F8b(2): corrupto->tier default 0 (fue %s)", tostring(t)))

  _modDataStore, _modDataExists = "", true
  setRun(_testPlayers[1], 10.0, 90.0, 9, 2)
  local ok2 = pcall(fire, ModCallbacks.MC_POST_GAME_STARTED, true)
  check(ok2, "F8b(2): save vacio no crashea al continuar")
  local w2 = getRun(_testPlayers[1])
  check(feq(w2, Core.WILLPOWER_MAX), string.format("F8b(2): vacio->willpower default MAX (fue %s)", tostring(w2)))

  -- Rangos/tipos invalidos se clampan, sin crash (legado plano).
  _modDataStore = '{"0":{"emeraldSparks":-5,"overchargeTier":7,"stolenRings":99,"willpower":9999}}'
  _modDataExists = true
  local ok3 = pcall(fire, ModCallbacks.MC_POST_GAME_STARTED, true)
  check(ok3, "F8b(2): valores fuera de rango no crashean")
  local w3, s3, r3, t3 = getRun(_testPlayers[1])
  check(feq(w3, Core.WILLPOWER_MAX), string.format("F8b(2): willpower 9999 clamp a MAX (fue %s)", tostring(w3)))
  check(feq(s3, 0), string.format("F8b(2): sparks -5 clamp a 0 (fue %s)", tostring(s3)))
  check(r3 == Core.MAX_STOLEN_RINGS, string.format("F8b(2): rings 99 clamp a MAX %d (fue %s)", Core.MAX_STOLEN_RINGS, tostring(r3)))
  check(t3 == 2, string.format("F8b(2): tier 7 clamp a 2 (fue %s)", tostring(t3)))
  print("[test_save_continue] corrupto->defaults ok; clamp ok")
end

-- ===================== (3) 2P sin cross-talk (via POST_NEW_LEVEL) =====================
do
  _testPlayers = { makePlayer(0), makePlayer(1) }
  _testStage = 1
  _modDataStore, _modDataExists = nil, false
  setRun(_testPlayers[1], 80.0, 11.0, 2, 1)
  setRun(_testPlayers[2], 30.0, 77.0, 6, 2)
  fire(ModCallbacks.MC_POST_NEW_LEVEL)
  check(_modDataExists, "F8b(3): POST_NEW_LEVEL guarda via SaveModData")
  wipe(_testPlayers[1]); wipe(_testPlayers[2])
  fire(ModCallbacks.MC_POST_GAME_STARTED, true)
  local w0, s0, r0, t0 = getRun(_testPlayers[1])
  local w1, s1, r1, t1 = getRun(_testPlayers[2])
  check(feq(w0, 80.0) and feq(s0, 11.0) and r0 == 2 and t0 == 1,
    string.format("F8b(3): P0 restaura lo suyo (fue %s/%s/%s/%s)", tostring(w0), tostring(s0), tostring(r0), tostring(t0)))
  check(feq(w1, 30.0) and feq(s1, 77.0) and r1 == 6 and t1 == 2,
    string.format("F8b(3): P1 restaura lo suyo (fue %s/%s/%s/%s)", tostring(w1), tostring(s1), tostring(r1), tostring(t1)))
  print("[test_save_continue] 2P sin cross-talk ok")
end

-- ===================== (4) sin isContinued no restaura =====================
do
  _testPlayers = { makePlayer(0) }
  _testStage = 1
  _modDataStore, _modDataExists = nil, false
  setRun(_testPlayers[1], 80.0, 11.0, 2, 1)
  fire(ModCallbacks.MC_PRE_GAME_EXIT)
  setRun(_testPlayers[1], 5.0, 5.0, 1, 0)
  fire(ModCallbacks.MC_POST_GAME_STARTED, false)
  local w, s, r, t = getRun(_testPlayers[1])
  check(feq(w, 5.0) and feq(s, 5.0) and r == 1 and t == 0,
    string.format("F8b(4): partida nueva no restaura (fue %s/%s/%s/%s)", tostring(w), tostring(s), tostring(r), tostring(t)))
end

-- ===================== (5) unlock -> exit -> continue: oath Y run sobreviven =====================
do
  _testPlayers = { makePlayer(0, true) } -- Hal
  _testStage = 1
  _modDataStore, _modDataExists = nil, false
  Core.Progress.oathkeeperHal = false
  Core.Progress.oathkeeperTainted = false
  setRun(_testPlayers[1], 73.5, 42.25, 4, 1)
  _testStage = LevelStage.STAGE3_1
  fire(ModCallbacks.MC_POST_NEW_LEVEL) -- desbloquea oath; ambos guardan read-modify-write
  check(Core.Progress.oathkeeperHal == true, "F8c(5): unlock Hal en Womb I pone oathkeeperHal")
  local okSlot, slot = pcall(json.decode, _modDataStore)
  check(okSlot and type(slot) == "table" and type(slot.oath) == "table"
      and slot.oath.oathkeeperHal == true,
    "F8c(5): slot compartido conserva seccion oath tras unlock")
  check(okSlot and type(slot) == "table" and type(slot.run) == "table"
      and slot.run["0"] ~= nil and feq(slot.run["0"].willpower, 73.5),
    "F8c(5): slot compartido conserva seccion run tras unlock (read-modify-write)")
  fire(ModCallbacks.MC_PRE_GAME_EXIT) -- solo save_run guarda; oath debe sobrevivir
  local okSlot2, slot2 = pcall(json.decode, _modDataStore)
  check(okSlot2 and type(slot2) == "table" and type(slot2.oath) == "table"
      and slot2.oath.oathkeeperHal == true,
    "F8c(5): exit (save_run) no pisa la seccion oath")
  -- Sesion fresca: memoria a defaults, slot intacto.
  wipe(_testPlayers[1])
  Core.Progress.oathkeeperHal = false
  Core.Progress.oathkeeperTainted = false
  _testStage = 1
  fire(ModCallbacks.MC_POST_GAME_STARTED, true)
  local w, s, r, t = getRun(_testPlayers[1])
  check(feq(w, 73.5) and feq(s, 42.25) and r == 4 and t == 1,
    string.format("F8c(5): continue restaura run tras unlock+exit (fue %s/%s/%s/%s)", tostring(w), tostring(s), tostring(r), tostring(t)))
  check(Core.Progress.oathkeeperHal == true,
    "F8c(5): continue restaura oathkeeperHal (slot compartido no pisado)")
  check(Core.Progress.oathkeeperTainted == false,
    "F8c(5): oathkeeperTainted sigue false (secciones independientes)")
  print("[test_save_continue] unlock->exit->continue ok: oath Y run sobreviven")
end

-- ===================== (6) unlock tras exit no borra run =====================
do
  _testPlayers = { makePlayer(0, true) } -- Hal
  _testStage = 1
  _modDataStore, _modDataExists = nil, false
  Core.Progress.oathkeeperHal = false
  Core.Progress.oathkeeperTainted = false
  setRun(_testPlayers[1], 61.0, 17.5, 3, 2)
  fire(ModCallbacks.MC_PRE_GAME_EXIT) -- run guardada primero, sin oath
  _testStage = LevelStage.STAGE3_1
  fire(ModCallbacks.MC_POST_NEW_LEVEL) -- unlock tardio: progress Save no debe borrar run
  check(Core.Progress.oathkeeperHal == true, "F8c(6): unlock tardio pone oathkeeperHal")
  local okSlot, slot = pcall(json.decode, _modDataStore)
  check(okSlot and type(slot) == "table" and type(slot.run) == "table"
      and slot.run["0"] ~= nil and feq(slot.run["0"].willpower, 61.0)
      and feq(slot.run["0"].emeraldSparks, 17.5),
    "F8c(6): unlock tras exit conserva seccion run (slot=" .. tostring(_modDataStore) .. ")")
  check(okSlot and type(slot) == "table" and type(slot.oath) == "table"
      and slot.oath.oathkeeperHal == true,
    "F8c(6): slot conserva seccion oath tras unlock tardio")
  -- Ciclo completo: sesion fresca + continue -> ambas sobreviven.
  wipe(_testPlayers[1])
  Core.Progress.oathkeeperHal = false
  Core.Progress.oathkeeperTainted = false
  _testStage = 1
  fire(ModCallbacks.MC_POST_GAME_STARTED, true)
  local w, s, r, t = getRun(_testPlayers[1])
  check(feq(w, 61.0) and feq(s, 17.5) and r == 3 and t == 2,
    string.format("F8c(6): continue restaura run guardada antes del unlock (fue %s/%s/%s/%s)", tostring(w), tostring(s), tostring(r), tostring(t)))
  check(Core.Progress.oathkeeperHal == true,
    "F8c(6): continue restaura oath tras unlock tardio")
  print("[test_save_continue] unlock-tras-exit ok: run no borrada, oath presente")
end

-- ===================== (7) slot corrupto -> defaults por seccion, sin crash =====================
do
  _testPlayers = { makePlayer(0, true) }
  _testStage = 1
  _modDataStore, _modDataExists = "!!!CORRUPT-NOT-JSON!!!", true
  Core.Progress.oathkeeperHal = true -- stale: debe caer a defaults al cargar corrupto
  Core.Progress.oathkeeperTainted = true
  setRun(_testPlayers[1], 10.0, 90.0, 9, 2)
  local ok = pcall(fire, ModCallbacks.MC_POST_GAME_STARTED, true)
  check(ok, "F8c(7): slot corrupto no crashea con slot compartido")
  local w, s, r, t = getRun(_testPlayers[1])
  check(feq(w, Core.WILLPOWER_MAX) and feq(s, 0) and r == 0 and t == 0,
    string.format("F8c(7): corrupto->run defaults (fue %s/%s/%s/%s)", tostring(w), tostring(s), tostring(r), tostring(t)))
  check(Core.Progress.oathkeeperHal == false and Core.Progress.oathkeeperTainted == false,
    "F8c(7): corrupto->oath defaults (false/false), sin tumbar run")
  print("[test_save_continue] corrupto->defaults por seccion ok")
end

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_save_continue] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
