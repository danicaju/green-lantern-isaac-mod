-- tools/test_beam_growth.lua
-- SPEC-D: rayo continuo con crecimiento fluido estilo Brimstone (solo render).
-- Verifica: rampa monotona 0->full en N frames, len(N)==totalLen,
-- cambio de dir >~30deg reinicia desde longitud actual, co-op sin fuga,
-- dano intacto (beam_math sin tocar) y flare escala con visible.
-- Compatible Lua 5.1 (mismo flavor que el juego).

-- ===================== SHIMS =====================
Vector = {}
local VectorMT = { __index = Vector }
function Vector.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, VectorMT) end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
    local l = self:Length()
    if l <= 0.001 then return Vector.new(1, 0) end
    return Vector.new(self.X / l, self.Y / l)
end
function Vector:GetAngleDegrees() return math.deg(math.atan2(self.Y, self.X)) end
function Vector:Rotated(deg)
    local r = math.rad(deg)
    local c, s = math.cos(r), math.sin(r)
    return Vector.new(self.X * c - self.Y * s, self.X * s + self.Y * c)
end
function VectorMT.__add(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end
function VectorMT.__sub(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
function VectorMT.__mul(a, b)
    if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end
function VectorMT.__div(a, b)
    if type(b) == "number" then return Vector.new(a.X / b, a.Y / b) end
    return Vector.new(a.X / b.X, a.Y / b.Y)
end
Vector.Zero = Vector.new(0, 0)

-- Compat: algunos runtimes Lua (5.4) no traen math.atan2; el juego si.
if math.atan2 == nil then
    function math.atan2(y, x) return math.atan(y, x) end
end

function Color(r, g, b, a, bo, go, by)
    return { R = r, G = g, B = b, A = a, BOff = bo, GOff = go, BYOff = by }
end

-- ===================== CARGA =====================
local Core = {}
-- Cargar core.lua real para constantes + GetPlayerData (sin Isaac: stub minimo).
-- core.lua hace RegisterMod + Game() en algunas fns, pero a nivel top solo RegisterMod.
-- Stubear lo necesario antes del dofile.
if RegisterMod == nil then
    RegisterMod = function(name, v) return { Name = name } end
end
if Game == nil then
    Game = function()
        return {
            GetFrameCount = function() return 0 end,
            GetLevel = function()
                return { GetCurrentRoomIndex = function() return 0 end }
            end,
        }
    end
end

local coreFactoryOk, coreChunk = pcall(dofile, "modules/core.lua")
if not coreFactoryOk then
    io.stderr:write("FAIL: no se pudo cargar modules/core.lua: " .. tostring(coreChunk) .. "\n")
    os.exit(1)
end
-- core.lua devuelve tabla Core directamente (no factory).
Core = coreChunk

-- Cargar fx_beam.lua (factory que extiende Core).
local fxFactory = dofile("modules/fx_beam.lua")
fxFactory(Core)

-- Stubs de render para integracion (captura de segmentos + flare).
local renderLog = {}
local function clearLog() renderLog = {} end
local function makeStubSprite(name)
    local s = { _name = name, Scale = Vector(1, 1), Rotation = 0, Color = Color(1,1,1,1,0,0,0), _frame = nil }
    function s:SetFrame(n, f) self._frame = n end
    function s:Render(pos, off, src)
        table.insert(renderLog, { sprite = name, pos = pos, scale = self.Scale, rotation = self.Rotation, color = self.Color })
    end
    return s
end
local beamSpr = makeStubSprite("Beam")
local flareSpr = makeStubSprite("Flare")
Core.GetGLContBeamSprite = function() return beamSpr end
Core.GetGLAuraSprites = function() return nil, nil end
Core.GetGLSparkSprite = function() return nil end
if not Core.IsHalJordan then Core.IsHalJordan = function() return true end end
if not Core.IsTaintedHal then Core.IsTaintedHal = function() return false end end
local _upOverride = false
if not Core.IsAimingUp then Core.IsAimingUp = function() return _upOverride end end
if not Core.GetRingHandOffset then Core.GetRingHandOffset = function() return Vector(0, 0) end end

-- ===================== HELPERS =====================
local failures = 0
local passes = 0
local function check(cond, msg)
    if cond then passes = passes + 1
    else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end
local function exists(name)
    if type(Core[name]) == "function" or Core[name] ~= nil then passes = passes + 1
    else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(name) .. " no existe\n") end
end
local function makePlayerData()
    -- Dos datas independientes via GetPlayerData con players falsos (co-op sin fuga).
    local function fakePlayer(idx)
        local p = { Index = idx, _d = {} }
        function p:GetData() return self._d end
        return p
    end
    return fakePlayer(0), fakePlayer(1)
end

-- ===================== TESTS =====================
-- 1) Constante N en rango 8-12.
exists("CONTINUOUS_BEAM_GROWTH_FRAMES")
local N = Core.CONTINUOUS_BEAM_GROWTH_FRAMES
check(type(N) == "number" and N >= 8 and N <= 12,
    string.format("CONTINUOUS_BEAM_GROWTH_FRAMES en [8,12], fue %s", tostring(N)))
N = math.floor(N or 10)

-- 2) Estado por jugador, nunca global.
do
    local p1, p2 = makePlayerData()
    local d1 = Core.GetPlayerData(p1)
    local d2 = Core.GetPlayerData(p2)
    check(d1 ~= nil and d2 ~= nil, "GetPlayerData devuelve tabla")
    check(d1 ~= d2, "datas co-op independientes")
    check(Core.beamGrowthFrame == nil and Core.beamGrowthDir == nil and Core.lastBeamDir == nil,
        "sin globales de crecimiento en Core")
    -- Campos existen (o se crean al primer update) en data, no en Core.
    exists("ComputeBeamGrowthVisibleLength")
    exists("UpdateBeamGrowth")
end

-- 3) longitud_visible(frame) monotona 0->full, len(N)==totalLen.
do
    local total = 400.0
    local prev = -1
    for f = 0, N do
        local v = Core.ComputeBeamGrowthVisibleLength(total, f, 0)
        check(v >= prev - 1e-6,
            string.format("monotona: len(%d)=%.3f >= prev %.3f", f, v, prev))
        check(v >= -1e-6 and v <= total + 1e-6,
            string.format("acotada: len(%d)=%.3f en [0,total]", f, v))
        prev = v
    end
    local vN = Core.ComputeBeamGrowthVisibleLength(total, N, 0)
    check(math.abs(vN - total) < 1e-6,
        string.format("len(N)==totalLen: %.4f vs %.4f", vN, total))
    local vBig = Core.ComputeBeamGrowthVisibleLength(total, N + 50, 0)
    check(math.abs(vBig - total) < 1e-6, "len>N se queda en full (clamp)")
    local v0 = Core.ComputeBeamGrowthVisibleLength(total, 0, 0)
    check(v0 <= total * 0.15 + 1e-6,
        string.format("arranque ~0: len(0)=%.3f debe ser casi 0", v0))
end

-- 4) Cambio de dir >~30deg reinicia desde longitud actual (no desde 0).
do
    local total = 400.0
    local dirA = Vector(1, 0)
    -- Simular 5 frames creciendo con dirA.
    local d = { beamGrowthFrame = 0, beamGrowthDir = nil, beamGrowthBaseLen = 0 }
    local lastVisible = 0
    for i = 1, 5 do
        lastVisible = Core.UpdateBeamGrowth(d, dirA, total)
    end
    check(lastVisible > 1.0 and lastVisible < total - 1.0,
        string.format("a mitad de rampa visible=%.2f (entre 0 y total)", lastVisible))
    -- Giro pequeno (<30deg, p.ej. 10deg) NO reinicia: el frame no se resetea a 0.
    local frameBefore = d.beamGrowthFrame
    local dirSmall = dirA:Rotated(10)
    local vSmall = Core.UpdateBeamGrowth(d, dirSmall, total)
    check(d.beamGrowthFrame == frameBefore + 1,
        string.format("giro 10deg no reinicia (frame %d -> %d)", frameBefore, d.beamGrowthFrame or -1))
    check(vSmall >= lastVisible - 1e-6, "giro pequeno: visible no retrocede")
    -- Giro grande (90deg) SI reinicia pero desde longitud actual: base==visible previo.
    local visibleBeforeTurn = vSmall
    local dirB = Vector(0, 1) -- 90deg
    local vTurn = Core.UpdateBeamGrowth(d, dirB, total)
    check((d.beamGrowthFrame or -1) <= 1,
        string.format("giro 90deg reinicia rampa (frame=%s)", tostring(d.beamGrowthFrame)))
    check(math.abs((d.beamGrowthBaseLen or -1) - visibleBeforeTurn) < 2.0,
        string.format("reinicio desde actual: base=%.2f vs previo=%.2f",
            d.beamGrowthBaseLen or -1, visibleBeforeTurn))
    check(vTurn >= visibleBeforeTurn - 1e-6,
        string.format("tras giro visible=%.2f >= previo=%.2f (no colapsa a 0)", vTurn, visibleBeforeTurn))
    -- Y vuelve a crecer monotonicamente hasta full.
    local pv = vTurn
    local ok = true
    for i = 1, N do pv = Core.UpdateBeamGrowth(d, dirB, total); if pv < 0 or pv > total + 1e-6 then ok = false end end
    check(ok, "tras giro sigue acotada [0,total]")
    check(math.abs(pv - total) < 1e-6, "tras giro completa hasta full en N frames")
end

-- 5) Co-op sin fuga: dos datas no se contaminan.
do
    local p1, p2 = makePlayerData()
    local d1 = Core.GetPlayerData(p1)
    local d2 = Core.GetPlayerData(p2)
    Core.UpdateBeamGrowth(d1, Vector(1, 0), 400)
    Core.UpdateBeamGrowth(d1, Vector(1, 0), 400)
    Core.UpdateBeamGrowth(d2, Vector(0, 1), 400)
    check((d1.beamGrowthFrame or 0) ~= (d2.beamGrowthFrame or 0) or
        tostring((d1.beamGrowthDir or {}).X) ~= tostring((d2.beamGrowthDir or {}).X),
        "co-op: estados de crecimiento independientes")
    -- Girar P1 no toca P2.
    local f2before = d2.beamGrowthFrame
    Core.UpdateBeamGrowth(d1, Vector(0, -1), 400) -- giro 90deg+ en P1
    check(d2.beamGrowthFrame == f2before, "co-op: giro de P1 no reinicia P2")
end

-- 6) Dano intacto: beam_math sin tocar (firma + tick con endWorld completo).
do
    local f = io.open("modules/beam_math.lua", "r")
    check(f ~= nil, "beam_math.lua existe")
    if f then
        local src = f:read("*a"); f:close()
        check(src:find("function Core.TickContinuousBeamDamage") ~= nil, "TickContinuousBeamDamage intacto")
        check(src:find("function Core.ComputeContinuousBeamEndWorld") ~= nil, "ComputeContinuousBeamEndWorld intacto")
        check(src:find("beamGrowth") == nil and src:find("Growth") == nil,
            "beam_math.lua sin logica de crecimiento (solo render)")
    end
    local f2 = io.open("modules/firing_mode.lua", "r")
    check(f2 ~= nil, "firing_mode.lua existe")
    if f2 then
        local src = f2:read("*a"); f2:close()
        check(src:find("[Gg]rowth") == nil, "firing_mode.lua sin logica de crecimiento")
    end
end

-- 7) Render: el haz crece por frames y el flare escala con lo VISIBLE.
do
    local TOTAL_PX = 200.0
    Core.ComputeContinuousBeamEndWorld = function(p, d)
        return (p or Vector.new(0, 0)) + Vector.new(TOTAL_PX, 0)
    end
    Isaac = Isaac or {}
    Isaac.WorldToScreen = function(p) return Vector.new(p.X, p.Y) end
    local function fakeRenderPlayer()
        local p = { Position = Vector.new(0, 0) }
        function p:GetShootingInput() return Vector.new(1, 0) end
        return p
    end
    local function freshFiringData(ownerIdx)
        local p = { Index = ownerIdx, _d = {} }
        function p:GetData() return self._d end
        local d = Core.GetPlayerData(p)
        d.isFiringContinuousBeam = true
        d.lastShootDir = Vector.new(1, 0)
        d.lastRingHandOffset = Vector.new(0, 0)
        d.overcharge = false
        d.surgeBuff = false
        return d
    end
    local function renderOnce(data, frame)
        renderLog = {}
        Core.RenderGLContinuousBeam(fakeRenderPlayer(), data, flareSpr, frame or 0)
        local beams, flares = {}, {}
        for _, r in ipairs(renderLog) do
            if r.sprite == "Beam" then table.insert(beams, r) end
            if r.sprite == "Flare" then table.insert(flares, r) end
        end
        return beams, flares
    end
    -- Primer frame: casi nada visible, sin flare (visible < 24px).
    local d = freshFiringData(0)
    local beams1, flares1 = renderOnce(d, 0)
    check(#beams1 == 0, "render frame 1: haz aun sin longitud (crece desde 0)")
    check(#flares1 == 0, "render frame 1: sin flare con haz ~0")
    -- A mitad de rampa: haz parcial + flare parcial (alpha < full).
    for _ = 1, 4 do renderOnce(d, 0) end
    local beamsMid, flaresMid = renderOnce(d, 0)
    check(#beamsMid > 0, "render mid-rampa: ya hay segmentos")
    local lastMidX = beamsMid[#beamsMid].pos.X
    check(lastMidX < TOTAL_PX - 1.0,
        string.format("render mid-rampa: no llega al final (%.1f < %.1f)", lastMidX, TOTAL_PX))
    check(#flaresMid == 1, "render mid-rampa: flare ya visible en la punta")
    if #flaresMid == 1 then
        local aMid = flaresMid[1].color.A
        check(aMid > 0.0 and aMid < 0.95,
            string.format("flare mid-rampa parcial: alpha=%.3f en (0, 0.95)", aMid))
        check(math.abs(flaresMid[1].pos.X - lastMidX) < 49.0,
            "flare mid-rampa en la punta visible (no en el endWorld completo)")
    end
    -- Tras N frames: haz completo + flare full en el extremo.
    for _ = 1, N do renderOnce(d, 0) end
    local beamsFull, flaresFull = renderOnce(d, 0)
    check(#beamsFull > 0, "render full: haz completo dibujado")
    local lastFullX = beamsFull[#beamsFull].pos.X
    check(lastFullX > TOTAL_PX - 49.0,
        string.format("render full: llega al final (%.1f ~= %.1f)", lastFullX, TOTAL_PX))
    check(#flaresFull == 1, "render full: flare final presente")
    if #flaresFull == 1 then
        check(math.abs(flaresFull[1].color.A - 0.95) < 1e-6,
            string.format("flare full: alpha=0.95 (fue %.4f)", flaresFull[1].color.A))
        check(math.abs(flaresFull[1].pos.X - TOTAL_PX) < 1e-6,
            string.format("flare full: en el extremo X=%.1f (fue %.3f)", TOTAL_PX, flaresFull[1].pos.X))
    end
    -- Al soltar (isFiring=false) el proximo haz vuelve a crecer desde 0.
    d.isFiringContinuousBeam = false
    renderOnce(d, 0)
    d.isFiringContinuousBeam = true
    local beamsRe, _ = renderOnce(d, 0)
    check(#beamsRe == 0, "tras soltar: el haz reinicia desde 0")
end

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_beam_growth] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
