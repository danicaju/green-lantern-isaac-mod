-- tools/test_fx_beam_render_skip.lua
-- Tests TDD para S7: ComputeBeamRenderStartSkip + verificación de que RenderGLContinuousBeam
-- usa ese skip como `dist` inicial al apuntar arriba.
-- Compatible con Lua 5.1 (mismo flavor que el juego).

-- Shims de las APIs de Isaac mínimas que usa fx_beam.lua.
Vector = {}
local VectorMT = {__index = Vector}
function Vector.new(x, y) return setmetatable({X=x or 0, Y=y or 0}, VectorMT) end
setmetatable(Vector, {__call = function(_, x, y) return Vector.new(x, y) end})
function Vector:Length() return math.sqrt(self.X*self.X + self.Y*self.Y) end
function Vector:Normalized()
    local l = self:Length()
    if l <= 0.001 then return Vector.new(1, 0) end
    return Vector.new(self.X/l, self.Y/l)
end
function Vector:GetAngleDegrees() return math.deg(math.atan2(self.Y, self.X)) end
function VectorMT.__add(a, b)
    if type(b) == "number" then return Vector.new(a.X + b, a.Y + b) end
    return Vector.new(a.X + b.X, a.Y + b.Y)
end
function VectorMT.__sub(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
function VectorMT.__mul(a, b)
    if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end
function VectorMT.__div(a, b)
    if type(b) == "number" then return Vector.new(a.X / b, a.Y / b) end
    return Vector.new(a.X / b.X, a.Y / b.Y)
end
function VectorMT.__eq(a, b)
    if type(a) == "table" and type(b) == "table" then
        return math.abs(a.X - b.X) < 1e-9 and math.abs(a.Y - b.Y) < 1e-9
    end
    return false
end
function VectorMT.__tostring(v) return string.format("Vector(%.3f, %.3f)", v.X, v.Y) end
Vector.Zero = Vector.new(0, 0)

-- Compat: algunos runtimes Lua (5.4) no traen math.atan2; el juego si.
if math.atan2 == nil then
    function math.atan2(y, x) return math.atan(y, x) end
end

function Color(r,g,b,a,bo,go,by)
    return setmetatable({R=r,G=g,B=b,A=a,BOff=bo,GOff=go,BYOff=by}, {})
end

-- Carga fx_beam.lua y la ejecuta contra un Core stub. Capturamos las invocaciones
-- a beamSpr:Render(...) para validar que NO se pinta el segmento 0..skip cuando aim-up,
-- y que SÍ se pinta el resto del haz.

-- ===================== STUB FRAMEWORK =====================
local Core = {}
Core.SPARK_COLLECT_FRAMES = 1
Core.SPARK_LIFETIME_FRAMES = 1
Core.SPARK_BLINK_FRAMES = 1
Core.WILLPOWER_MAX = 100
Core.HAL_CONTINUOUS_TICK_FRAMES = 4
Core.HAL_CONTINUOUS_WILL_DRAIN = 0.06
-- SPEC-D: el haz crece 0->full en N renders; el harness calienta la rampa
-- antes de asertar posiciones (ver runRender).
Core.CONTINUOUS_BEAM_GROWTH_FRAMES = 10

-- Captura de renders.
local renderLog = {}
local function clearLog() renderLog = {} end

-- Stub de sprite que registra cada Render().
local function makeStubSprite(name)
    local s = {
        _name = name,
        Scale = Vector(1,1),
        Rotation = 0,
        Color = Color(1,1,1,1,0,0,0),
        _frame = nil,
    }
    function s:SetFrame(n, f) self._frame = n end
    function s:Render(pos, off, src)
        table.insert(renderLog, {
            sprite = name,
            pos = pos,
            scale = self.Scale,
            rotation = self.Rotation,
            frame = self._frame,
        })
    end
    return s
end

local beamSpr = makeStubSprite("Beam")
local flareSpr = makeStubSprite("Flare")

Core.GetGLSparkSprite = function() return nil end
Core.GetGLAuraSprites = function() return nil, nil end
Core.GetGLContBeamSprite = function() return beamSpr end
Core.IsHalJordan = function() return false end
Core.IsTaintedHal = function() return false end
Core.IsAimingUp = function(p, v) return _upOverride end
Core.GetPlayerData = function() return _dataOverride end
Core.GetRingHandOffset = function() return Vector(0, -32) end  -- simula aim-up
Core.ComputeContinuousBeamEndWorld = function(p, d)
    -- Devuelve un endWorld tal que la longitud en pantalla entre start y end sea ~200 px.
    -- Como el juego real haría WorldToScreen + diferencia, lo simulamos devolviendo
    -- una distancia suficiente y dejando que el código existente use la conversión.
    -- Para tests deterministas vamos a inyectar screenLen vía override (ver más abajo).
    return (p or Vector(0,0)) + (d or Vector(1,0)) * 100
end

-- Cargar fx_beam.lua.
local factory = dofile("modules/fx_beam.lua")
factory(Core)

-- ===================== HELPERS =====================
local failures = 0
local passes = 0

local function check(cond, msg)
    if cond then passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

local function exists(name)
    if type(Core[name]) == "function" then passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(name) .. " no existe\n")
    end
end

-- ===================== STUB DE PLAYER (mínimo) =====================
-- Devuelve startWorld=(0,0) y endWorld=(worldDeltaPx,0). WorldToScreen devuelve lo mismo,
-- por lo que la diferencia en pantalla es exactamente worldDeltaPx px.
local function makePlayer(worldDeltaPx)
    -- Override ComputeContinuousBeamEndWorld para que devuelva un endWorld tal que la
    -- distancia en pantalla entre start y end sea exactamente worldDeltaPx.
    Core.ComputeContinuousBeamEndWorld = function(p, d)
        return (p or Vector.new(0,0)) + Vector.new(worldDeltaPx, 0)
    end
    local player = {
        Position = Vector.new(0, 0),
        _lastShootingInput = Vector.new(0, -1),  -- apuntando arriba
    }
    function player:GetShootingInput()
        return self._lastShootingInput
    end
    -- Isaac stub. Sin zoom/offset: pasamos tal cual.
    Isaac = Isaac or {}
    Isaac.WorldToScreen = function(p)
        return Vector.new(p.X, p.Y)
    end
    return player
end

local function makeData(opts)
    opts = opts or {}
    local data = {
        isFiringContinuousBeam = opts.firing ~= false,
        lastShootDir = opts.dir or Vector(0, -1),
        lastRingHandOffset = Vector(0, -32),
        overcharge = false,
        surgeBuff = false,
        willpower = 100,
        -- SPEC-D: estado de crecimiento como en GetPlayerData (sin nil-tolerancia implicita).
        beamGrowthFrame = 0,
        beamGrowthDir = nil,
        beamGrowthBaseLen = 0.0,
    }
    return data
end

-- ===================== TESTS UNITARIOS =====================

exists("ComputeBeamRenderStartSkip")

check(Core.ComputeBeamRenderStartSkip(false, 100) == 0, "no aim-up: skip=0")
check(Core.ComputeBeamRenderStartSkip(false, 200) == 0, "no aim-up largo: skip=0")
check(Core.ComputeBeamRenderStartSkip(false, 0) == 0, "no aim-up 0: skip=0")

check(Core.ComputeBeamRenderStartSkip(true, 200) > 0, "aim-up 200: skip>0")
check(Core.ComputeBeamRenderStartSkip(true, 80) > 0, "aim-up 80: skip>0")

check(Core.ComputeBeamRenderStartSkip(true, 14) == 0, "aim-up == skip: 0")
check(Core.ComputeBeamRenderStartSkip(true, 13.5) == 0, "aim-up < skip: 0")
check(Core.ComputeBeamRenderStartSkip(true, 4) == 0, "aim-up 4: 0")
check(Core.ComputeBeamRenderStartSkip(true, 0) == 0, "aim-up 0: 0")

local v = Core.ComputeBeamRenderStartSkip(true, 200)
check(v > 12 and v < 16, "skip ~14px (12<v<16)")

-- Constancia del skip (no escala con la longitud del haz).
local v2 = Core.ComputeBeamRenderStartSkip(true, 1000)
check(math.abs(v2 - v) < 0.5, "skip constante independiente de longitud")

-- ===================== TESTS DE INTEGRACIÓN DE RENDER =====================
-- Verifica que al apuntar arriba con haz largo:
--   - el primer segmento dibujado está a dist >= skip
--   - NO se dibuja nada en dist=0
-- Verifica que sin aim-up:
--   - sí se dibuja desde dist=0

local function runRender(worldDeltaPx, up)
    clearLog()
    _upOverride = up
    local player = makePlayer(worldDeltaPx)
    _dataOverride = makeData({ firing = true, dir = Vector(0, -1) })
    Isaac.WorldToScreen = function(p)
        return Vector.new(p.X, p.Y)
    end
    -- SPEC-D: calienta la rampa de crecimiento (N renders) y descarta el log;
    -- las aserciones de abajo validan el haz a longitud completa, como antes.
    local warmupN = Core.CONTINUOUS_BEAM_GROWTH_FRAMES or 10
    for _ = 1, warmupN do
        Core.RenderGLContinuousBeam(player, _dataOverride, flareSpr, 0)
    end
    clearLog()
    Core.RenderGLContinuousBeam(player, _dataOverride, flareSpr, 0)
end

-- Aim-up con haz largo (200px screen).
runRender(200, true)
local beamRendersUp = {}
for _, r in ipairs(renderLog) do
    if r.sprite == "Beam" then table.insert(beamRendersUp, r) end
end

-- El primer render debe estar en X >= skip (~14).
check(#beamRendersUp > 0, "aim-up largo: se dibuja al menos un segmento del haz")
if #beamRendersUp > 0 then
    local firstX = beamRendersUp[1].pos.X
    check(firstX >= 13.5,
          string.format("aim-up largo: primer render debe estar a X>=~14, fue %.3f", firstX))
end

-- Aim-up con haz corto (10px screen) → el haz es más corto que el skip, así que NO se
-- recorta: se dibuja entero. La función ComputeBeamRenderStartSkip devuelve 0 en ese caso.
runRender(10, true)
local beamRendersShortUp = 0
for _, r in ipairs(renderLog) do
    if r.sprite == "Beam" then beamRendersShortUp = beamRendersShortUp + 1 end
end
check(beamRendersShortUp > 0,
       "aim-up con haz<=skip: se dibuja entero (skip devuelve 0; no queda nada recortable)")
if beamRendersShortUp > 0 then
    -- Verifica que el primer segmento sí está en X=0 (no se aplicó skip).
    local firstX = nil
    for _, r in ipairs(renderLog) do
        if r.sprite == "Beam" then firstX = r.pos.X; break end
    end
    check(firstX ~= nil and firstX < 0.001,
          string.format("aim-up haz corto: primer render debe estar en X=0, fue %.3f", firstX or -1))
end

-- Sin aim-up: primer render debe estar exactamente en X=0 (dist inicial 0).
runRender(200, false)
local beamRendersFlat = {}
for _, r in ipairs(renderLog) do
    if r.sprite == "Beam" then table.insert(beamRendersFlat, r) end
end
check(#beamRendersFlat > 0, "no aim-up: se dibuja haz completo")
if #beamRendersFlat > 0 then
    local firstX = beamRendersFlat[1].pos.X
    check(firstX < 0.001,
          string.format("no aim-up: primer render debe estar en X=0, fue %.3f", firstX))
end

-- Aim-up con haz 60 → primer render debe estar en X >= ~14 (no en 0).
runRender(60, true)
local beamRenders60 = {}
for _, r in ipairs(renderLog) do
    if r.sprite == "Beam" then table.insert(beamRenders60, r) end
end
check(#beamRenders60 > 0, "aim-up 60px: se dibuja el resto tras el skip")
if #beamRenders60 > 0 then
    local firstX = beamRenders60[1].pos.X
    check(firstX >= 13.5,
          string.format("aim-up 60: primer render debe estar a X>=~14, fue %.3f", firstX))
    local lastX = beamRenders60[#beamRenders60].pos.X
    check(lastX < 60.001,
          string.format("aim-up 60: último render debe estar antes del final X=60, fue %.3f", lastX))
end

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_fx_beam_render_skip] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end