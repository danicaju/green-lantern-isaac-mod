-- tools/test_beam_short_wall.lua
-- SPEC-X1: haz visible pegado al muro (solo render, sin tocar dano).
-- MIN_RENDER_LEN ~20px: 20-43px dibuja fino (grosor <=1.0, sin tapar cara),
-- <20px no dibuja nada. Dano/raycast (beam_math), flare de impacto <24px,
-- flare de la mano, crecimiento SPEC-D y skip aim-up intactos.
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

if math.atan2 == nil then
    function math.atan2(y, x) return math.atan(y, x) end
end

function Color(r, g, b, a, bo, go, by)
    return { R = r, G = g, B = b, A = a, BOff = bo, GOff = go, BYOff = by }
end

-- ===================== CARGA =====================
if RegisterMod == nil then
    RegisterMod = function(name, v) return { Name = name } end
end

local coreFactoryOk, coreChunk = pcall(dofile, "modules/core.lua")
if not coreFactoryOk then
    io.stderr:write("FAIL: no se pudo cargar modules/core.lua: " .. tostring(coreChunk) .. "\n")
    os.exit(1)
end
local Core = coreChunk

local fxFactory = dofile("modules/fx_beam.lua")
fxFactory(Core)

-- Stubs de render (captura de segmentos + flares).
local renderLog = {}
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
Core.GetGLAuraSprites = function() return nil, flareSpr end
Core.GetGLSparkSprite = function() return nil end
local _isTainted = false
if not Core.IsHalJordan then Core.IsHalJordan = function() return true end end
Core.IsTaintedHal = function() return _isTainted end
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

Isaac = Isaac or {}
Isaac.WorldToScreen = function(p) return Vector.new(p.X, p.Y) end

local function fakePlayer()
    local p = { Position = Vector.new(0, 0) }
    function p:GetShootingInput() return Vector.new(1, 0) end
    return p
end

local function setWorldLen(px)
    Core.ComputeContinuousBeamEndWorld = function(p, d)
        return (p or Vector.new(0, 0)) + Vector.new(px, 0)
    end
end

local function freshFiringData(opts)
    opts = opts or {}
    local data = {
        isFiringContinuousBeam = true,
        lastShootDir = Vector.new(1, 0),
        lastRingHandOffset = Vector.new(0, 0),
        overcharge = opts.overcharge or false,
        surgeBuff = opts.surgeBuff or false,
        beamGrowthFrame = 0,
        beamGrowthDir = nil,
        beamGrowthBaseLen = 0.0,
        ringFlareTimer = 0,
    }
    return data
end

local function renderBeam(data, frame)
    renderLog = {}
    Core.RenderGLContinuousBeam(fakePlayer(), data, flareSpr, frame or 0)
    local beams, flares = {}, {}
    for _, r in ipairs(renderLog) do
        if r.sprite == "Beam" then table.insert(beams, r) end
        if r.sprite == "Flare" then table.insert(flares, r) end
    end
    return beams, flares
end

local function growthN()
    return math.floor(Core.CONTINUOUS_BEAM_GROWTH_FRAMES or 10)
end

local function warmBeam(data, px, extra)
    setWorldLen(px)
    for _ = 1, growthN() + (extra or 0) do renderBeam(data, 0) end
    return renderBeam(data, 0)
end

local function allThin(beams)
    for _, b in ipairs(beams) do
        if b.scale.Y > 1.0 + 1e-6 then return false end
    end
    return true
end

local function anyThick(beams)
    for _, b in ipairs(beams) do
        if b.scale.Y > 1.0 + 1e-6 then return true end
    end
    return false
end

-- ===================== TESTS =====================
-- 1) Constante SECTION 1 en Core, ~4px (visible pegado al muro).
check(Core.CONTINUOUS_BEAM_MIN_RENDER_LEN ~= nil,
    "Core.CONTINUOUS_BEAM_MIN_RENDER_LEN existe (SECTION 1)")
local MINL = Core.CONTINUOUS_BEAM_MIN_RENDER_LEN or -1
check(type(MINL) == "number" and MINL >= 3 and MINL <= 5,
    string.format("MIN_RENDER_LEN en [3,5] (~4), fue %s", tostring(MINL)))

-- 2) Haz degenerado (< 3px) no dibuja nada.
do
    setWorldLen(2.0)
    local d = freshFiringData()
    local beams1, flares1 = renderBeam(d, 0)
    check(#beams1 == 0, "haz <MIN: 0 segmentos en el primer frame")
    check(#flares1 == 0, "haz <MIN: sin flare de impacto")
    for _ = 1, growthN() + 2 do renderBeam(d, 0) end
    local beamsN, flaresN = renderBeam(d, 0)
    check(#beamsN == 0, "haz <MIN: 0 segmentos tras N+ frames")
    check(#flaresN == 0, "haz <MIN: sin flare de impacto tras N+ frames")
end

-- 3) Pegado al muro (8px, 15px, 20px, 30px, 43px) SI dibuja (fino <=1.0).
do
    for _, px in ipairs({ 8.0, 15.0, 20.0, 30.0, 43.0 }) do
        local d = freshFiringData()
        local beams, _ = warmBeam(d, px)
        check(#beams > 0, string.format("haz %gpx pegado al muro: dibuja al menos un segmento", px))
        check(allThin(beams), string.format("haz %gpx: grosor <=1.0 en todos los segmentos (no tapa cara)", px))
    end
    -- Con overcharge/surge/tainted el corto sigue fino (clamp solo render).
    local dOc = freshFiringData({ overcharge = true })
    local beamsOc, _ = warmBeam(dOc, 30.0)
    check(#beamsOc > 0, "haz 30px overcharge: dibuja")
    check(allThin(beamsOc), "haz 30px overcharge: grosor <=1.0 (clamp corto)")
    _isTainted = true
    local dTa = freshFiringData()
    local beamsTa, _ = warmBeam(dTa, 30.0)
    check(#beamsTa > 0, "haz 30px tainted: dibuja")
    check(allThin(beamsTa), "haz 30px tainted: grosor <=1.0 (clamp corto)")
    _isTainted = false
    -- Haz largo con overcharge conserva su grosor (>1.0): el clamp es solo corto.
    local dLong = freshFiringData({ overcharge = true })
    local beamsLong, _ = warmBeam(dLong, 200.0)
    check(anyThick(beamsLong), "haz 200px overcharge: grosor >1.0 intacto (clamp solo 20-44px)")
end

-- 4) Dano por tick intacto: beam_math sin diff, fx_beam no dana.
do
    local f = io.open("modules/beam_math.lua", "r")
    check(f ~= nil, "beam_math.lua existe")
    if f then
        local src = f:read("*a"); f:close()
        check(src:find("function Core.TickContinuousBeamDamage") ~= nil, "TickContinuousBeamDamage intacto")
        check(src:find("function Core.ComputeContinuousBeamEndWorld") ~= nil, "ComputeContinuousBeamEndWorld intacto")
        check(src:find("MIN_RENDER") == nil, "beam_math.lua sin umbral de render (dano intacto)")
    end
    local f2 = io.open("modules/fx_beam.lua", "r")
    check(f2 ~= nil, "fx_beam.lua existe")
    if f2 then
        local src = f2:read("*a"); f2:close()
        check(src:find("TickContinuousBeamDamage") == nil, "fx_beam.lua no llama a dano (solo render)")
    end
end

-- 5) Haz largo + crecimiento intactos (SPEC-D).
do
    check(type(Core.CONTINUOUS_BEAM_GROWTH_FRAMES) == "number", "CONTINUOUS_BEAM_GROWTH_FRAMES existe")
    local N = growthN()
    check(N >= 8 and N <= 12, string.format("GROWTH_FRAMES en [8,12], fue %s", tostring(N)))
    check(type(Core.ComputeBeamGrowthVisibleLength) == "function", "ComputeBeamGrowthVisibleLength intacto")
    check(type(Core.UpdateBeamGrowth) == "function", "UpdateBeamGrowth intacto")
    check(type(Core.ComputeBeamRenderStartSkip) == "function", "ComputeBeamRenderStartSkip intacto (skip aim-up)")
    check(Core.ComputeBeamRenderStartSkip(false, 100) == 0, "skip: no aim-up -> 0")
    check(Core.ComputeBeamRenderStartSkip(true, 200) > 0, "skip: aim-up largo -> >0")
    setWorldLen(200.0)
    local d = freshFiringData()
    local beams1, _ = renderBeam(d, 0)
    check(#beams1 == 0, "haz largo frame 1: aun sin longitud (crece desde 0)")
    for _ = 1, N do renderBeam(d, 0) end
    local beamsFull, flaresFull = renderBeam(d, 0)
    check(#beamsFull > 0, "haz largo full: segmentos dibujados")
    local lastX = beamsFull[#beamsFull].pos.X
    check(lastX > 200.0 - 49.0, string.format("haz largo full: llega al final (%.1f ~= 200)", lastX))
    check(#flaresFull == 1, "haz largo full: flare de impacto presente")
    if #flaresFull == 1 then
        check(math.abs(flaresFull[1].color.A - 0.95) < 1e-6, "haz largo full: flare alpha=0.95")
    end
end

-- 6) Flare de impacto en muro (visible >=8px) y flare de mano intacto.
do
    setWorldLen(200.0)
    local d = freshFiringData()
    local _, flares1 = renderBeam(d, 0)
    check(#flares1 == 0, "frame 1 (visible<8): sin flare de impacto")
    -- Haz 6px: bajo umbral flare (<8px) -> sin flare de impacto.
    local d6 = freshFiringData()
    local beams6, flares6 = warmBeam(d6, 6.0)
    check(#beams6 > 0, "haz 6px: segmentos visibles")
    check(#flares6 == 0, "haz 6px (visible<8): sin flare de impacto")
    -- Haz 20px: flare de impacto visible en el muro.
    local d20 = freshFiringData()
    local beams20, flares20 = warmBeam(d20, 20.0)
    check(#beams20 > 0, "haz 20px full: segmentos visibles")
    check(#flares20 == 1, "haz 20px full (visible>=8): flare de impacto visible en el muro")
    -- Flare de mano: RenderGLBeamAndFlareForPlayer con haz corto sigue pintando la mano.
    setWorldLen(2.0)
    local d2 = freshFiringData()
    d2.isFiringContinuousBeam = true
    renderLog = {}
    Core.RenderGLBeamAndFlareForPlayer(fakePlayer(), d2, 0)
    local handFlares = 0
    for _, r in ipairs(renderLog) do
        if r.sprite == "Flare" then handFlares = handFlares + 1 end
    end
    check(handFlares >= 1, "haz corto: flare de la mano intacto")
end

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_beam_short_wall] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
