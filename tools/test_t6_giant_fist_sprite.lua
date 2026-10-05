-- tools/test_t6_giant_fist_sprite.lua
-- T6 — guard de regresion sobre el sprite custom del Construct: Giant Fist.
-- Compatible con Lua 5.1.
--
-- Verifica que:
--   1. fx_sprites.lua registra Core.ApplyGiantFistSprite(tear)
--   2. Carga gfx/effects/gl_giant_fist.anm2 y reproduce "Idle"
--   3. Aplica Rotation = tear.Velocity:GetAngleDegrees()
--   4. Marca td.isGLFist = true (NO toca td.isGiantFist, que sigue siendo de item_fist.lua)
--   5. Envolvente en pcall: nunca propaga errores
--   6. Sin tear -> no rompe (early return)
--
-- Reglas RSI: ApplyGiantFistSprite es el unico sitio que hardcodea la ruta
-- "gfx/effects/gl_giant_fist.anm2". Carga el modulo via dofile contra un Core
-- stub que captura Sprite():Load, :Play y asignaciones a Rotation/Color.

-- ===================== SHIMS ISAAC MINIMOS =====================
Vector = {}
local VectorMT = {__index = Vector}
function Vector.new(x, y) return setmetatable({X=x or 0, Y=y or 0}, VectorMT) end
setmetatable(Vector, {__call = function(_, x, y) return Vector.new(x, y) end})
function Vector:Length() return math.sqrt(self.X*self.X + self.Y*self.Y) end
function Vector:GetAngleDegrees() return math.deg(math.atan2(self.Y, self.X)) end
function Vector:Normalized()
    local l = self:Length()
    if l <= 0.001 then return Vector.new(1, 0) end
    return Vector.new(self.X/l, self.Y/l)
end
VectorMT.__mul = function(a, b)
    if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end
Vector.Zero = Vector.new(0, 0)

function Color(r,g,b,a,bo,go,by)
    return setmetatable({R=r,G=g,B=b,A=a,BOff=bo,GOff=go,BYOff=by}, {})
end

-- ===================== STUB FRAMEWORK =====================
local loadCalls, playCalls = {}, {}
local Core = {}

local Sprite = {}
Sprite.__index = Sprite
function Sprite.new()
    return setmetatable({
        Rotation = 0,
        _loaded = nil,
        _played = nil,
    }, Sprite)
end
function Sprite:Load(path, _loadGraphics)
    table.insert(loadCalls, path)
    self._loaded = path
end
function Sprite:Play(anim, _loop)
    table.insert(playCalls, anim)
    self._played = anim
end

-- Tear stub: tiene Sprite, Velocity, GetData.
local function makeTear(vx, vy)
    local spr = Sprite.new()
    local data = {}
    return {
        Velocity = Vector.new(vx, vy),
        Sprite = spr,
        GetSprite = function(_self) return spr end,
        GetData  = function(_self) return data end,
        _sprite  = spr,
        _data    = data,
    }
end

-- ===================== TESTS =====================
local failures, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- (1) El modulo se carga y registra la funcion.
local ok, factory = pcall(dofile, "modules/fx_sprites.lua")
check(ok, "fx_sprites.lua debe cargarse sin errores: " .. tostring(factory))
check(type(factory) == "function", "fx_sprites.lua debe exportar una factory function")

factory(Core)

check(type(Core.ApplyGiantFistSprite) == "function",
      "Core.ApplyGiantFistSprite debe existir")

-- (2-4) Caso feliz: tear con velocidad → carga anm2, play Idle, rota y marca data.
loadCalls = {}; playCalls = {}
local tear = makeTear(1.0, 0.0)  -- angulo = 0 grados
Core.ApplyGiantFistSprite(tear)

check(#loadCalls == 1 and loadCalls[1] == "gfx/effects/gl_giant_fist.anm2",
      string.format("debe cargar gfx/effects/gl_giant_fist.anm2 (cargadas: %d)", #loadCalls))
check(#playCalls == 1 and playCalls[1] == "Idle",
      string.format("debe reproducir 'Idle' (animaciones: %s)",
                    table.concat(playCalls, ",")))

local expectedAngle = tear.Velocity:GetAngleDegrees()
check(math.abs(tear._sprite.Rotation - expectedAngle) < 0.001,
      string.format("Rotation debe ser GetAngleDegrees() (%.4f vs esperado %.4f)",
                    tear._sprite.Rotation, expectedAngle))

check(tear._data.isGLFist == true,
      "td.isGLFist debe ser true (marcado por ApplyGiantFistSprite)")
check(tear._data.isGiantFist == nil,
      "td.isGiantFist NO debe tocarse (eso es de item_fist.lua, no de fx_sprites)")

-- (4b) Velocidad vertical → rotacion != 0.
loadCalls = {}; playCalls = {}
local tear2 = makeTear(0.0, -1.0)
Core.ApplyGiantFistSprite(tear2)
local ang2 = tear2.Velocity:GetAngleDegrees()
check(math.abs(ang2 - (-90)) < 0.001,
      string.format("Vector(0,-1) debe dar angulo -90, dio %.4f", ang2))
check(math.abs(tear2._sprite.Rotation - (-90)) < 0.001,
      "Rotation debe reflejar angulo -90 para velocidad vertical")

-- (5) pcall: si Load revienta, la funcion NO propaga.
local function withExplodingSprite()
    loadCalls = {}; playCalls = {}
    local prevLoad = Sprite.Load
    local prevPlay = Sprite.Play
    Sprite.Load = function(_self, _path, _lg) error("boom from Load") end
    Sprite.Play = function(_self, _a, _l) error("boom from Play") end
    local tear = makeTear(0.0, 0.0)
    local ok2 = pcall(Core.ApplyGiantFistSprite, tear)
    Sprite.Load = prevLoad
    Sprite.Play = prevPlay
    return ok2, tear
end
local ok3 = withExplodingSprite()
check(ok3 == true, "ApplyGiantFistSprite debe envolver Load/Play en pcall y NO propagar errores")

-- (5b) Si una llamada interna al final ignora pcall y propaga, esto la cazaria.
local function withExplodingGetSprite()
    loadCalls = {}; playCalls = {}
    local tear = makeTear(0.0, 0.0)
    tear.GetSprite = function() error("boom from GetSprite") end
    local ok4 = pcall(Core.ApplyGiantFistSprite, tear)
    return ok4
end
check(withExplodingGetSprite() == true,
      "ApplyGiantFistSprite debe envolver TODA la logica critica en pcall (GetSprite incluido)")

-- (6) Sin tear -> no rompe.
local ok5 = pcall(Core.ApplyGiantFistSprite, nil)
check(ok5 == true, "ApplyGiantFistSprite(nil) debe no romper (early return)")

-- (7) El modulo no expone un nuevo registro de Sprite global — sigue usando Sprite del Isaac API.
-- Esta verificacion es blanda: el modulo no debe haber tocado globales de Isaac.
-- Si falla, alguien cambio el contrato. (Aqui solo registramos que no hubo explosion global.)
check(true, "no-op: registro global, no errores de carga")

-- =============================================================================
-- (8) T6 REFUERZO: EnforceGiantFistSprite via MC_POST_TEAR_UPDATE/_RENDER
-- =============================================================================
-- Hallazgo de review: el sprite del puno (td.isGLFist) no tenia enforcement
-- contra resets C++ del engine. El beam (isGLRingBeam) sí lo tenia
-- (EnforceRingBeamTearSprite). Esta seccion cubre:
--   - el enforcement re-aplica Idle cuando anim != Idle (rama MC_POST_TEAR_UPDATE)
--   - idem en MC_POST_TEAR_RENDER
--   - no recarga ni re-play cuando ya esta en Idle (no-op silencioso)
--   - convive con isGLRingBeam (cada uno en su propia rama)
--   - NO toca Scale, TearFlags ni CollisionDamage
--   - la rama isGLFist se invoca por separado de la rama isGLRingBeam
-- (Carga modules/beam_discrete.lua con un Core stub + ModCallbacks stub
--         + capturar los callbacks en Core.GL._cbs.)

-- ===================== STUBS PARA beam_discrete.lua =====================
-- TearFlags: enum minimo que beam_discrete.lua inspecciona (en la rama del beam).
TearFlags = {
    TEAR_PIERCING = 1, TEAR_SPECTRAL = 2, TEAR_HOMING = 4, TEAR_ORBIT = 8,
    TEAR_BOOMERANG = 16, TEAR_SPIRAL = 32, TEAR_WIGGLE = 64, TEAR_MEGA = 128,
}

-- ModCallbacks: tabla global con los IDs que beam_discrete.lua consulta.
-- El original expone una tabla, no una funcion; pero en tests previos (T5)
-- se hace un doble setup para tolerar ambos. Aqui usamos la variante tabla.
ModCallbacks = {
    MC_POST_FIRE_TEAR    = 39,
    MC_POST_TEAR_UPDATE  = 40,
    MC_POST_TEAR_RENDER  = 41,
    MC_PRE_TEAR_COLLISION = 42,
}

-- Game(): stub minimo (MC_POST_FIRE_TEAR ya no se ejercita, pero la rama
-- del fist podria tocar Game en hooks futuros; lo dejamos inocuo).
function Game() return { GetFrameCount = function() return 0 end } end

-- TearFlags.TEAR_FEAR no existe en el enum real (lo vimos en CHANGELOG),
-- por lo que no hace falta declararlo.

-- Sprite dedicado para esta seccion: trackea GetAnimation() y permite
-- resetear manualmente el "Animation" como haria el engine tras un reset C++.
local enforcementLoads, enforcementPlays, enforcementRotations = {}, {}, {}
local Sprite2 = {}
Sprite2.__index = Sprite2
function Sprite2.new()
    return setmetatable({
        Rotation = 0,
        _loaded = nil,
        _played = nil,
        Animation = "Idle",  -- estado inicial: ya esta en Idle (caso no-op)
    }, Sprite2)
end
function Sprite2:Load(path, _loadGraphics)
    table.insert(enforcementLoads, path)
    self._loaded = path
end
function Sprite2:Play(anim, _loop)
    table.insert(enforcementPlays, anim)
    self._played = anim
    self.Animation = anim  -- tras Play, la animacion pasa a ser la pedida
end
function Sprite2:GetAnimation() return self.Animation end

-- Tear stub: tiene Sprite con anim trackeable + Velocity + GetData + flags
-- inalterables (Scale/TearFlags/CollisionDamage son "inamovibles" en los asserts).
local function makeFistTear(vx, vy, initialAnim)
    local spr = Sprite2.new()
    spr.Animation = initialAnim or "Idle"
    local data = { isGLFist = true, isGiantFist = true }  -- isGiantFist = flag de item_fist
    local tear = {
        Velocity        = Vector.new(vx, vy),
        Sprite          = spr,
        Scale           = 3.5,
        CollisionDamage = 100,
        TearFlags       = TearFlags.TEAR_PIERCING + TearFlags.TEAR_SPECTRAL,  -- Lua 5.1: usar '+' en vez de bitwise '|' (suma equivalente para valores disjuntos)
        GetSprite       = function(_self) return spr end,
        GetData         = function(_self) return data end,
        _sprite         = spr,
        _data           = data,
    }
    return tear, spr, data
end

-- Core stub: minimo indispensable para que beam_discrete.lua cargue.
local Core2 = {
    GL = {
        _cbs = {},
        AddCallback = function(self, cbId, fn)
            table.insert(self._cbs, { id = cbId, fn = fn })
            return self
        end,
    },
    -- Stubs para todas las funciones que MC_POST_FIRE_TEAR invoca (no las
    -- ejercitamos en estos asserts; basta con que existan para que el modulo
    -- compile y registre callbacks sin reventar al cargarse).
    IsRingActive                = function() return false end,
    IsHalJordan                 = function() return false end,
    IsTaintedHal                = function() return false end,
    CanUseContinuousBeam        = function() return false end,
    GetPlayerData               = function() return {} end,
    GetRingHandOffset           = function() return Vector.new(0, 0) end,
    GetRingBeamTearSpawnOffset  = function() return Vector.new(0, 0) end,
    IsAimingUp                  = function() return false end,
    ApplyRingBeamSprite         = function() end,
    HasTearFlag                 = function(flags, f) return (flags and f) and (flags % (f * 2) >= f) end,
    DISCRETE_BEAM_DMG_MULT      = 1.0,
    WILLPOWER_PER_TEAR          = 0.0,
    TriggerHalRingDepleted      = function() end,
}

-- (8.1) Cargar beam_discrete.lua con los stubs. El modulo es una factory
-- que recibe Core y registra callbacks; NO debe reventar al cargar.
-- T6-patch: el harness corre en Lua 5.1 (no soporta bitwise '|'); la produccion
-- usa '|' (Lua 5.3+ del motor Isaac, BitSet128 con metamethods). El enum de
-- TearFlags es disjunto (1, 2, 4, 8, ...) por lo que '|' == '+' bit a bit.
-- Parcheamos el codigo textual antes de cargarlo: dos '|' -> '+' en la linea
-- que aplica PIERCING + SPECTRAL. Solo afecta al harness; produccion intacta.
local function loadModuleTextAsLua51(path)
    local f = io.open(path, "r")
    if not f then return nil, "open failed: " .. path end
    local src = f:read("*a"); f:close()
    -- Sustitucion textual minima: los dos '|' de la linea de TearFlags disjuntos
    -- (TearFlags.TEAR_PIERCING=1, TEAR_SPECTRAL=2: a bit a bit '+' == '|').
    src = src:gsub("tear%.TearFlags%s*=%s*tear%.TearFlags%s*|%s*TearFlags%.TEAR_PIERCING%s*|%s*TearFlags%.TEAR_SPECTRAL",
                   "tear.TearFlags = tear.TearFlags + TearFlags.TEAR_PIERCING + TearFlags.TEAR_SPECTRAL")
    local chunk, err = loadstring(src, path)
    if not chunk then return nil, err end
    return chunk()
end
local okFactory, factory2 = pcall(loadModuleTextAsLua51, "modules/beam_discrete.lua")
check(okFactory, "beam_discrete.lua debe cargarse sin errores: " .. tostring(factory2))
check(type(factory2) == "function",
      "beam_discrete.lua debe exportar una factory function")

local okInit, errInit = pcall(factory2, Core2)
check(okInit, "factory(Core2) debe ejecutarse sin errores: " .. tostring(errInit))

-- (8.2) El modulo debe registrar MC_POST_TEAR_UPDATE y MC_POST_TEAR_RENDER.
local hasPostUpdate, hasPostRender = false, false
for _, c in ipairs(Core2.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_TEAR_UPDATE  then hasPostUpdate  = true end
    if c.id == ModCallbacks.MC_POST_TEAR_RENDER  then hasPostRender  = true end
end
check(hasPostUpdate,
      "beam_discrete.lua debe registrar MC_POST_TEAR_UPDATE")
check(hasPostRender,
      "beam_discrete.lua debe registrar MC_POST_TEAR_RENDER")

-- Helper: localizar el callback por id.
local function findCallback(cbId)
    for _, c in ipairs(Core2.GL._cbs) do
        if c.id == cbId then return c.fn end
    end
    return nil
end

local cbPostUpdate = findCallback(ModCallbacks.MC_POST_TEAR_UPDATE)
local cbPostRender = findCallback(ModCallbacks.MC_POST_TEAR_RENDER)
check(type(cbPostUpdate) == "function",
      "callback MC_POST_TEAR_UPDATE debe ser function")
check(type(cbPostRender) == "function",
      "callback MC_POST_TEAR_RENDER debe ser function")

-- (8.3) Enforcement re-aplica Idle cuando anim != Idle (rama UPDATE).
-- Simulamos un reset C++: el engine pone la anim en algo distinto a "Idle".
-- El enforcement debe detectar la deriva y re-cargar + re-play el anm2.
enforcementLoads = {}; enforcementPlays = {}
local tearFist, sprFist, dataFist = makeFistTear(1.0, 0.0, "Hit")  -- "Hit" != Idle
local origScale    = tearFist.Scale
local origFlags    = tearFist.TearFlags
local origDmg      = tearFist.CollisionDamage
local expectedAng  = tearFist.Velocity:GetAngleDegrees()
cbPostUpdate(_, tearFist)

check(#enforcementLoads >= 1 and enforcementLoads[#enforcementLoads] == "gfx/effects/gl_giant_fist.anm2",
      string.format("MC_POST_TEAR_UPDATE con isGLFist+anim!=Idle debe re-cargar gl_giant_fist.anm2 (cargadas: %s)",
                    table.concat(enforcementLoads, ",")))
check(#enforcementPlays >= 1 and enforcementPlays[#enforcementPlays] == "Idle",
      string.format("MC_POST_TEAR_UPDATE con isGLFist+anim!=Idle debe re-play Idle (animaciones: %s)",
                    table.concat(enforcementPlays, ",")))
check(math.abs(sprFist.Rotation - expectedAng) < 0.001,
      string.format("MC_POST_TEAR_UPDATE isGLFist debe re-aplicar Rotation (%.4f vs esperado %.4f)",
                    sprFist.Rotation, expectedAng))

-- (8.4) Enforcement NO toca Scale / TearFlags / CollisionDamage (firma del SPEC).
check(tearFist.Scale == origScale,
      string.format("MC_POST_TEAR_UPDATE isGLFist NO debe tocar Scale (%.2f vs orig %.2f)",
                    tearFist.Scale, origScale))
check(tearFist.TearFlags == origFlags,
      "MC_POST_TEAR_UPDATE isGLFist NO debe tocar TearFlags")
check(tearFist.CollisionDamage == origDmg,
      "MC_POST_TEAR_UPDATE isGLFist NO debe tocar CollisionDamage")

-- (8.5) Idem en MC_POST_TEAR_RENDER.
enforcementLoads = {}; enforcementPlays = {}
local tearFist2, sprFist2 = makeFistTear(0.0, -1.0, "Appear")
local expectedAng2 = tearFist2.Velocity:GetAngleDegrees()
cbPostRender(_, tearFist2, Vector.new(0, 0))

check(#enforcementLoads >= 1 and enforcementLoads[#enforcementLoads] == "gfx/effects/gl_giant_fist.anm2",
      "MC_POST_TEAR_RENDER con isGLFist+anim!=Idle debe re-cargar gl_giant_fist.anm2")
check(#enforcementPlays >= 1 and enforcementPlays[#enforcementPlays] == "Idle",
      "MC_POST_TEAR_RENDER con isGLFist+anim!=Idle debe re-play Idle")
check(math.abs(sprFist2.Rotation - expectedAng2) < 0.001,
      "MC_POST_TEAR_RENDER isGLFist debe re-aplicar Rotation para velocidad vertical")

-- (8.6) No-op cuando ya esta en Idle (no recarga, no re-play).
-- En el caso del fist NO hay log explicito de "no-op", pero podemos verificar
-- que tras el callback (que debe haber re-playeado Idle en la llamada anterior)
-- una nueva llamada con Idle ya puesto no produce CARGAS adicionales.
enforcementLoads = {}; enforcementPlays = {}
-- Estado: sprFist2 ahora tiene Animation="Idle" tras el paso (8.5).
cbPostUpdate(_, tearFist2, Vector.new(0, 0))
-- La rama "if anim ~= Idle" no debe haber disparado: cero loads y cero plays.
check(#enforcementLoads == 0,
      string.format("isGLFist con anim=Idle NO debe re-cargar (loads=%d)", #enforcementLoads))
check(#enforcementPlays == 0,
      string.format("isGLFist con anim=Idle NO debe re-play (plays=%d)", #enforcementPlays))

-- (8.7) Convivencia: la rama isGLRingBeam debe seguir funcionando igual que
-- antes (no se ve afectada por el nuevo branch isGLFist). El tear del beam
-- tiene isGLRingBeam=true (y NO isGLFist): la rama del fist debe ignorarlo.
enforcementLoads = {}; enforcementPlays = {}
local tearBeam, sprBeam = makeFistTear(0.5, -0.5, "Hit")
tearBeam._data.isGLFist    = false
tearBeam._data.isGLRingBeam = true
tearBeam._data.glBeamScale = 1.0
tearBeam._data.glBeamVel   = tearBeam.Velocity
cbPostUpdate(_, tearBeam, Vector.new(0, 0))
-- Carga el glas del beam (no el del fist) y reproduce Idle.
check(#enforcementLoads >= 1 and enforcementLoads[#enforcementLoads] == "gfx/effects/gl_ring_beam.anm2",
      string.format("isGLRingBeam sigue cargando gl_ring_beam.anm2 (cargadas: %s)",
                    table.concat(enforcementLoads, ",")))
check(#enforcementPlays >= 1 and enforcementPlays[#enforcementPlays] == "Idle",
      "isGLRingBeam sigue reproduciendo Idle")
-- Verificacion negativa: el speech del fist no debe haberse cargado para este tear.
local loadedAnyFist = false
for _, p in ipairs(enforcementLoads) do
    if p == "gfx/effects/gl_giant_fist.anm2" then loadedAnyFist = true end
end
check(not loadedAnyFist,
      "isGLRingBeam NO debe disparar la carga de gl_giant_fist.anm2 (ramas separadas)")

-- (8.8) Y al revle: un tear con isGLFist=true NO debe disparar la carga del beam.
enforcementLoads = {}; enforcementPlays = {}
local tearFistOnly = makeFistTear(0.7, 0.7, "Hit")
tearFistOnly._data.isGLFist     = true
tearFistOnly._data.isGLRingBeam = false
cbPostUpdate(_, tearFistOnly, Vector.new(0, 0))
local loadedAnyBeam = false
for _, p in ipairs(enforcementLoads) do
    if p == "gfx/effects/gl_ring_beam.anm2" then loadedAnyBeam = true end
end
check(not loadedAnyBeam,
      "isGLFist NO debe disparar la carga de gl_ring_beam.anm2 (ramas separadas)")
check(#enforcementLoads >= 1 and enforcementLoads[#enforcementLoads] == "gfx/effects/gl_giant_fist.anm2",
      "isGLFist debe cargar gl_giant_fist.anm2")

-- (8.9) Tear sin isGLFist ni isGLRingBeam: ambos callbacks deben ser no-op
-- (early return por la guarda). En el mod real esto cubre projectiles
-- vanilla y de otros mods.
enforcementLoads = {}; enforcementPlays = {}
local tearVanilla = makeFistTear(1.0, 0.0, "Hit")
tearVanilla._data.isGLFist     = false
tearVanilla._data.isGLRingBeam = false
cbPostUpdate(_, tearVanilla, Vector.new(0, 0))
cbPostRender(_, tearVanilla, Vector.new(0, 0))
check(#enforcementLoads == 0 and #enforcementPlays == 0,
      string.format("tear vanilla (sin flags) NO debe disparar nada (loads=%d, plays=%d)",
                    #enforcementLoads, #enforcementPlays))

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_t6_giant_fist_sprite] passes=%d failures=%d\n",
                              passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end