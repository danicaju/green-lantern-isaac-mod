-- tools/test_fear_timer_no_trinket.lua
-- F2: el decremento de fearControlTimer/fearSkullTimer y el ClearEntityFlags(FLAG_FEAR)
-- al llegar a 0 corren con guard timer>0 AUNQUE se haya perdido el trinket;
-- el movimiento invertido y el poof siguen gated por HasTrinket.
-- Duracion 60 y trigger de dano intactos. Compatible con Lua 5.1.

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
EntityType = { ENTITY_PLAYER = 1, ENTITY_EFFECT = 1003 }
DamageFlag = { DAMAGE_CRUSH = 1, DAMAGE_NOKILL = 2, DAMAGE_EXPLOSION = 4 }
EntityFlag = { FLAG_FEAR = 16 }
EffectVariant = { POOF04 = 4, WATER_SPLASH = 38 }
SoundEffect = { SOUND_DEATH_BURST_SMALL = 99 }

function SFXManager() return { Play = function() end } end

_testPlayers = {}
_numPlayers = 1
_frameCount = 0
_poofSpawns = 0

Isaac = {}
function Isaac.GetPlayer(i) return _testPlayers[i] end
function Isaac.Spawn(typ, variant, sub, pos, vel, parent)
  if variant == EffectVariant.POOF04 then _poofSpawns = _poofSpawns + 1 end
  return {
    GetSprite = function() return { Color = nil } end,
    Scale = 1,
  }
end

function Game()
  return {
    GetNumPlayers = function() return _numPlayers end,
    GetFrameCount = function() return _frameCount end,
  }
end

-- ===================== STUB CORE =====================
local Core = {}
Core.GL = {
  _cbs = {},
  AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
}
Core.TRINKET_YELLOW_IMPURITY = 999
local dataByPlayer = {}
function Core.GetPlayerData(player)
  if not dataByPlayer[player.Index] then dataByPlayer[player.Index] = {} end
  return dataByPlayer[player.Index]
end
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
    MoveSpeed = 1.0,
    _hasTrinket = true,
    _flags = {},
    _moveInput = Vector.new(1, 0),
  }
  function p:ToPlayer() return self end
  function p:HasTrinket(id)
    return self._hasTrinket and id == Core.TRINKET_YELLOW_IMPURITY
  end
  function p:AddEntityFlags(f) self._flags[f] = true end
  function p:ClearEntityFlags(f) self._flags[f] = nil end
  function p:HasEntityFlags(f) return self._flags[f] == true end
  function p:GetMovementInput() return self._moveInput end
  function p:SetColor(...) end
  return p
end

local function loadFear()
  local f = assert(io.open("modules/trinket_fear.lua", "r"))
  local src = f:read("*a"); f:close()
  -- Lua 5.1 (harness) no parsea `&` (AND bit a bit, sintaxis 5.3+ del motor).
  -- DAMAGE_CRUSH=1, NOKILL=2, EXPLOSION=4 son potencias de dos: `& x ~= 0`
  -- equivale a la prueba aritmetica con `%`. Solo afecta al harness.
  src = src:gsub("%(flags & DamageFlag%.DAMAGE_CRUSH%) ~=%s*0", function() return "(flags % 2 >= 1)" end)
  src = src:gsub("%(flags & DamageFlag%.DAMAGE_NOKILL%) ==%s*0", function() return "(flags % 4 < 2)" end)
  src = src:gsub("%(flags & DamageFlag%.DAMAGE_EXPLOSION%) ~=%s*0", function() return "(flags % 8 >= 4)" end)
  local chunk, err = loadstring(src, "modules/trinket_fear.lua")
  assert(chunk, err)
  local factory = chunk()
  factory(Core)
end

local function findCb(id)
  for _, c in ipairs(Core.GL._cbs) do
    if c.id == id then return c.fn end
  end
  return nil
end

-- ===================== CARGA =====================
loadFear()
local dmgCb = findCb(ModCallbacks.MC_ENTITY_TAKE_DMG)
local postCb = findCb(ModCallbacks.MC_POST_UPDATE)
check(type(dmgCb) == "function", "F2: trinket_fear.lua registra MC_ENTITY_TAKE_DMG")
check(type(postCb) == "function", "F2: trinket_fear.lua registra MC_POST_UPDATE")

-- ===================== CASO 1: trigger de dano intacto (duracion 60) =====================
dataByPlayer = {}
local p = makePlayer(0)
_testPlayers = { [0] = p }
_numPlayers = 1
_frameCount = 0
p._hasTrinket = true
dmgCb(nil, p, 1, 0, nil) -- flags=0 -> isContact (NOKILL==0) -> fear
local d = Core.GetPlayerData(p)
check(d.fearControlTimer == 60,
  string.format("F2(1): dano con trinket pone fearControlTimer=60 (fue %s)", tostring(d.fearControlTimer)))
check(d.fearSkullTimer == 60,
  string.format("F2(1): dano con trinket pone fearSkullTimer=60 (fue %s)", tostring(d.fearSkullTimer)))
check(p._flags[EntityFlag.FLAG_FEAR] == true, "F2(1): dano con trinket pone FLAG_FEAR")

-- Sin trinket el dano NO triggerea (guard intacto).
dataByPlayer = {}
local pNo = makePlayer(1)
pNo._hasTrinket = false
_testPlayers = { [0] = pNo }
dmgCb(nil, pNo, 1, 0, nil)
local dNo = Core.GetPlayerData(pNo)
check(dNo.fearControlTimer == nil, "F2(1b): dano sin trinket NO pone fearControlTimer")

-- ===================== CASO 2: quitar trinket a mitad -> timers llegan a 0 y flag se limpia =====================
dataByPlayer = {}
p = makePlayer(0)
_testPlayers = { [0] = p }
_numPlayers = 1
p._hasTrinket = true
_frameCount = 0
dmgCb(nil, p, 1, 0, nil)
d = Core.GetPlayerData(p)
-- 10 frames con trinket: 60 -> 50.
for i = 1, 10 do _frameCount = _frameCount + 1; postCb() end
check(d.fearControlTimer == 50,
  string.format("F2(2): 10 frames con trinket 60->50 (fue %s)", tostring(d.fearControlTimer)))
check(d.fearSkullTimer == 50,
  string.format("F2(2): skull 60->50 con trinket (fue %s)", tostring(d.fearSkullTimer)))
-- Quitar trinket a mitad.
p._hasTrinket = false
for i = 1, 60 do _frameCount = _frameCount + 1; postCb() end
check(d.fearControlTimer == 0,
  string.format("F2(2): tras quitar trinket los 50 restantes llegan a 0 (fue %s)", tostring(d.fearControlTimer)))
check(d.fearSkullTimer == 0,
  string.format("F2(2): skull llega a 0 sin trinket (fue %s)", tostring(d.fearSkullTimer)))
check(p._flags[EntityFlag.FLAG_FEAR] == nil,
  "F2(2): al llegar a 0 sin trinket se limpia FLAG_FEAR")

-- ===================== CASO 3: sin trinket no hay inversion ni poofs (pero el timer corre) =====================
dataByPlayer = {}
p = makePlayer(0)
_testPlayers = { [0] = p }
_numPlayers = 1
p._hasTrinket = false
d = Core.GetPlayerData(p)
d.fearControlTimer = 5
d.fearSkullTimer = 5
p._flags[EntityFlag.FLAG_FEAR] = true
p._moveInput = Vector.new(1, 0)
p.Velocity = Vector.new(0, 0)
_poofSpawns = 0
_frameCount = 4 -- %4==0: si el poof no estuviera gated, dispararia
postCb()
check(d.fearControlTimer == 4,
  string.format("F2(3): sin trinket el timer sigue corriendo 5->4 (fue %s)", tostring(d.fearControlTimer)))
check(d.fearSkullTimer == 4,
  string.format("F2(3): sin trinket skull 5->4 (fue %s)", tostring(d.fearSkullTimer)))
check(p.Velocity.X == 0 and p.Velocity.Y == 0,
  string.format("F2(3): sin trinket NO hay inversion (Velocity=%.2f,%.2f)", p.Velocity.X, p.Velocity.Y))
check(_poofSpawns == 0,
  string.format("F2(3): sin trinket NO hay poofs (spawns=%d)", _poofSpawns))
-- Correr hasta 0 sin trinket: el flag se limpia.
for i = 1, 4 do _frameCount = _frameCount + 1; postCb() end
check(d.fearControlTimer == 0, "F2(3b): sin trinket el timer llega a 0")
check(p._flags[EntityFlag.FLAG_FEAR] == nil, "F2(3b): sin trinket al llegar a 0 se limpia FLAG_FEAR")

-- ===================== CASO 4: con trinket SI hay inversion y poof (control positivo) =====================
dataByPlayer = {}
p = makePlayer(0)
_testPlayers = { [0] = p }
_numPlayers = 1
p._hasTrinket = true
d = Core.GetPlayerData(p)
d.fearControlTimer = 5
d.fearSkullTimer = 5
p._flags[EntityFlag.FLAG_FEAR] = true
p._moveInput = Vector.new(1, 0)
p.Velocity = Vector.new(0, 0)
_poofSpawns = 0
_frameCount = 4 -- %4==0 -> poof esperado
postCb()
check(p.Velocity.X < -0.1,
  string.format("F2(4): con trinket SI hay inversion (Velocity.X=%.2f)", p.Velocity.X))
check(_poofSpawns >= 1,
  string.format("F2(4): con trinket SI hay poof (spawns=%d)", _poofSpawns))

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_fear_timer_no_trinket] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
