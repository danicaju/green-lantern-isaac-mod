-- tools/test_shield_orbit_smooth.lua
-- SPEC-A: orbital gl_solid_shield sin trompicones.
--
-- Causa: MC_POST_UPDATE corre a ritmo logico (30Hz) pero el render va a 60Hz.
-- Avanzar el angulo solo en POST_UPDATE muestra cada posicion 2 frames
-- seguidos (patron d,0,d,0...): judder visible = "trompicones".
--
-- Criterios que verifica:
--   (1) El angulo avanza a ritmo de render (60Hz) con la MISMA velocidad
--       angular/segundo que el legacy (0.065 rad/tick-logico @30Hz).
--       Harness: 120 ticks de render con POST_UPDATE cada 2 ticks;
--       aserta maxDeltaPos <= 1.5 * meanDeltaPos (sin salto >2x) y que el
--       angulo total recorrido == 60 * 0.065 (sin duplicar velocidad).
--   (2) Render y colision comparten fuente Core.GetShieldOrbitPos, sin
--       data.shieldWorldPos divergente (grep en shield.lua y fx_shield_items.lua).
--   (3) Invariantes intactos: radio 22px, formula reflect Luck-scaled via
--       Core.SHIELD_REFLECT_*, sin literales en la formula de chance.
--
-- No toca probabilidad reflect, radio, formula GetShieldOrbitPos, dano contacto.
-- Compatible con Lua 5.1. Uso: lua tools/test_shield_orbit_smooth.lua

-- ===================== STUBS Vector/Color/Direction =====================
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

function Color(r, g, b, a, ro, go, bo)
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 0 }
end

Direction = { LEFT = 1, RIGHT = 0, UP = 2, DOWN = 3 }
EntityType = { ENTITY_PLAYER = 1, ENTITY_PROJECTILE = 9, ENTITY_TEAR = 2, ENTITY_EFFECT = 1003 }
TearVariant = { BLUE = 1 }
EffectVariant = { WATER_SPLASH = 38 }
TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 4 }
DamageFlag = { DAMAGE_NO_MODIFIERS = 33554432 }
SoundEffect = { SOUND_TEARS_FIRE = 14, SOUND_ROCK_CRUMBLE = 62 }
ModCallbacks = { MC_POST_UPDATE = 1, MC_ENTITY_TAKE_DMG = 2, MC_POST_RENDER = 3, MC_POST_PLAYER_RENDER = 4 }

-- ===================== STUBS JUEGO =====================
local projectiles = {}
local roomEnts = {}
local logicFrame = 0

local _player = {
    Index = 0,
    Type = EntityType.ENTITY_PLAYER,
    Position = Vector.new(100, 100), -- estatico: aisla el stepping orbital
    Damage = 3.5,
    Luck = 0,
}
function _player:HasCollectible(id) return id == 1 end
function _player:ToPlayer() return self end
function _player:GetHeadDirection() return Direction.DOWN end

Isaac = {}
function Isaac.FindByType(_, _, _, _) return projectiles end
function Isaac.GetRoomEntities() return roomEnts end
function Isaac.GetPlayer(_) return _player end
function Isaac.WorldToScreen(v) return v end
function Isaac.Spawn() return nil end

function Game()
    return {
        GetNumPlayers = function() return 1 end,
        GetFrameCount = function() return logicFrame end,
        IsPaused = function() return false end,
    }
end
function SFXManager() return { Play = function() end } end

-- ===================== STUB CORE + FORMULA REAL =====================
local Core = {}
Core.GL = {
    _cbs = {},
    AddCallback = function(self, id, fn) table.insert(self._cbs, { id = id, fn = fn }) end,
}
Core.SHIELD_REFLECT_BASE = 0.25
Core.SHIELD_REFLECT_PER_LUCK = 0.05
Core.SHIELD_REFLECT_MAX = 0.75
Core.ITEM_SOLID_LIGHT_SHIELD = 1
local playerData = { shieldOrbitAngle = 0, lastShootDir = Vector.new(0, 1), shieldDeflectTimer = 0 }
Core.GetPlayerData = function(_) return playerData end
Core.LoadItemIDs = function() end

-- Formula REAL de produccion (ring_aim.lua, sin modificar).
dofile("modules/ring_aim.lua")(Core)

-- shield.lua usa `|` (Lua 5.3+ del motor); parche a `+` para Lua 5.1 como T4/F7.
local function loadShieldFactory(path)
    local f = io.open(path, "r")
    local src = f and f:read("*a") or ""
    if f then f:close() end
    local patched, n = src:gsub(
        "| TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING",
        "+ TearFlags.TEAR_SPECTRAL + TearFlags.TEAR_PIERCING",
        2, true)
    assert(n == 2, "smooth: se esperaban 2 OR en shield.lua, halladas " .. tostring(n))
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
assert(orbitalCb, "smooth: falta callback MC_POST_UPDATE")
local renderCb = findCb(ModCallbacks.MC_POST_RENDER) or findCb(ModCallbacks.MC_POST_PLAYER_RENDER)

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1
    else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end

-- ===================== (1) SIMULACION 60Hz RENDER + 30Hz LOGICA =====================
local N_RENDER = 120
local positions = {}
playerData.shieldOrbitAngle = 0
local angleStart = playerData.shieldOrbitAngle
for tick = 1, N_RENDER do
    if renderCb then renderCb() end
    if tick % 2 == 0 then
        logicFrame = logicFrame + 1
        orbitalCb()
    end
    local pos = Core.GetShieldOrbitPos(_player, playerData)
    assert(pos, "smooth: GetShieldOrbitPos devolvio nil")
    table.insert(positions, { X = pos.X, Y = pos.Y })
end
local angleEnd = playerData.shieldOrbitAngle

local deltas = {}
local sum = 0
for i = 2, #positions do
    local dx = positions[i].X - positions[i - 1].X
    local dy = positions[i].Y - positions[i - 1].Y
    local d = math.sqrt(dx * dx + dy * dy)
    table.insert(deltas, d)
    sum = sum + d
end
local mean = sum / #deltas
local mx = 0
for _, d in ipairs(deltas) do if d > mx then mx = d end end

io.stderr:write(string.format("smooth: N=%d meanDelta=%.4f maxDelta=%.4f ratio=%.3f angleTotal=%.6f\n",
    N_RENDER, mean, mx, mx / mean, angleEnd - angleStart))

check(mean > 0, "(1): el orbital avanza (meanDelta > 0)")
check(mx <= 1.5 * mean,
    string.format("(1): sin salto >2x: maxDelta(%.4f) <= 1.5*mean(%.4f)", mx, mean))

-- Misma velocidad angular/segundo que legacy: 60 ticks logicos * 0.065.
local expectedTotal = 60 * 0.065
check(math.abs((angleEnd - angleStart) - expectedTotal) < 1e-6,
    string.format("(1): misma velocidad angular/segundo: total %.6f == legacy %.6f",
        angleEnd - angleStart, expectedTotal))

-- (1b) Wrap 2pi sin teletransporte: angulo cerca de 2pi, 10 renders mas.
playerData.shieldOrbitAngle = math.pi * 2 - 0.05
local wrapPos = {}
for tick = 1, 10 do
    if renderCb then renderCb() end
    if tick % 2 == 0 then
        logicFrame = logicFrame + 1
        orbitalCb()
    end
    local pos = Core.GetShieldOrbitPos(_player, playerData)
    table.insert(wrapPos, { X = pos.X, Y = pos.Y })
end
local wmax = 0
for i = 2, #wrapPos do
    local dx = wrapPos[i].X - wrapPos[i - 1].X
    local dy = wrapPos[i].Y - wrapPos[i - 1].Y
    local d = math.sqrt(dx * dx + dy * dy)
    if d > wmax then wmax = d end
end
check(wmax <= 1.5 * mean,
    string.format("(1b): wrap 2pi sin teletransporte: maxDeltaWrap(%.4f) <= 1.5*mean(%.4f)", wmax, mean))

-- ===================== (2) FUENTE UNICA, SIN shieldWorldPos =====================
local function readFile(path)
    local f = io.open(path, "r")
    local s = f and f:read("*a") or ""
    if f then f:close() end
    return s
end
local shieldSrc = readFile("modules/shield.lua")
local fxSrc = readFile("modules/fx_shield_items.lua")
check(shieldSrc:find("Core.GetShieldOrbitPos", 1, true) ~= nil,
    "(2): shield.lua (colision) usa Core.GetShieldOrbitPos")
check(fxSrc:find("Core.GetShieldOrbitPos", 1, true) ~= nil,
    "(2): fx_shield_items.lua (render) usa Core.GetShieldOrbitPos")
check(not shieldSrc:find("shieldWorldPos", 1, true),
    "(2): shield.lua sin shieldWorldPos divergente")
check(not fxSrc:find("shieldWorldPos", 1, true),
    "(2): fx_shield_items.lua sin shieldWorldPos divergente")

-- El avance del angulo vive a ritmo de render, NO en POST_UPDATE (no duplicar).
local _, postEnd = shieldSrc:find("AddCallback%(ModCallbacks%.MC_POST_UPDATE", 1)
local _, dmgStart = shieldSrc:find("AddCallback%(ModCallbacks%.MC_ENTITY_TAKE_DMG", 1)
local orbitalRegion = shieldSrc:sub(postEnd or 1, (dmgStart or #shieldSrc) - 1)
check(not orbitalRegion:find("shieldOrbitAngle", 1, true),
    "(2): POST_UPDATE no toca shieldOrbitAngle (avance unico a ritmo render)")

-- ===================== (3) INVARIANTES: radio, reflect, dano =====================
check(shieldSrc:find("dist <= 22", 1, true) ~= nil,
    "(3): radio colision orbital 22px intacto")
check(shieldSrc:find("Core.SHIELD_REFLECT_BASE", 1, true) ~= nil,
    "(3): referencia Core.SHIELD_REFLECT_BASE")
check(shieldSrc:find("Core.SHIELD_REFLECT_PER_LUCK", 1, true) ~= nil,
    "(3): referencia Core.SHIELD_REFLECT_PER_LUCK")
check(shieldSrc:find("Core.SHIELD_REFLECT_MAX", 1, true) ~= nil,
    "(3): referencia Core.SHIELD_REFLECT_MAX")
check(shieldSrc:find("player.Damage * 1.5", 1, true) ~= nil,
    "(3): dano reflect intacto (player.Damage * 1.5)")

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_shield_orbit_smooth] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
