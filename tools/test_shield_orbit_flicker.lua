-- tools/test_shield_orbit_flicker.lua
-- TDD test: el orbital gl_solid_shield debe verse continuo (alpha 0.95) sin
-- parpadeo en la transicion Orbit(loop=true) <-> Deflect(loop=false).
--
-- Causa diagnosticada (grep Play/SetFrame + anm2 lineas 13-43):
--   * fx_shield_items.lua RenderGLSolidShieldFront cambia de animacion solo
--     con SetFrame, sin Play. Deflect tiene Loop=false: al terminar queda
--     congelado en su ultimo frame y el retorno a Orbit es un salto seco.
--   * shield.lua usa doble duracion: 12 (orbital) vs 14 (MC_ENTITY_TAKE_DMG).
--     La formula de render asume 12, asi que con 14 los frames no avanzan
--     monotonos 0-3 (clamp estira el frame 0).
--
-- Criterios que verifica:
--   (A) Todo cambio de animacion orbital va via Play; SetFrame solo se usa
--       intra-animacion (nunca SetFrame("X") con animacion activa ~= "X").
--   (B) Deflect termina con Play("Orbit"): el retorno es explicito.
--   (C) Frames Deflect monotonos 0-3 durante la rafaga deflect.
--   (D) 1 Render por jugador/frame en Front, alpha orbital 0.95.
--   (E) Duracion deflect unica en shield.lua (todos los
--       `shieldDeflectTimer = N` con el mismo N).
--
-- Compatible con Lua 5.1 (solo carga fx_shield_items.lua; shield.lua se
-- inspecciona como texto). Uso: lua tools/test_shield_orbit_flicker.lua

-- ===================== STUBS =====================
Vector = {}
function Vector.new(x, y)
    local v = { X = x or 0, Y = y or 0 }
    setmetatable(v, {
        __index = Vector,
        __add = function(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end,
        __sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end,
        __mul = function(a, b)
            if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
            if type(a) == "number" then return Vector.new(a * b.X, a * b.Y) end
            return Vector.new(a.X * b.X, a.Y * b.Y)
        end,
    })
    return v
end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector.Zero() return Vector.new(0, 0) end
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
    local l = self:Length()
    if l <= 0.001 then return Vector.new(1, 0) end
    return Vector.new(self.X / l, self.Y / l)
end

function Color(r, g, b, a, ro, go, bo)
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 0 }
end

local gameFrame = 1000
function Game()
    return { GetFrameCount = function() return gameFrame end }
end

Isaac = {}
function Isaac.WorldToScreen(v) return v end

-- Sprite stub: emula el motor (SetFrame NO cambia la animacion activa,
-- solo Play lo hace) y registra todas las llamadas.
local spriteLog = {}
local orbitalSprite = {
    activeAnim = "Orbit", -- fx_sprites.lua hace Play("Orbit") al crearlo
    Color = nil,
    Scale = nil,
}
function orbitalSprite:Play(anim, loop)
    table.insert(spriteLog, { op = "Play", anim = anim })
    self.activeAnim = anim
end
function orbitalSprite:SetFrame(anim, frame)
    table.insert(spriteLog, {
        op = "SetFrame", anim = anim, frame = frame,
        activeAtCall = self.activeAnim,
    })
end
function orbitalSprite:Render(pos, a, b)
    table.insert(spriteLog, { op = "Render" })
end

local playerData = { shieldDeflectTimer = 0, shieldOrbitAngle = 0 }
local Core = {}
Core.ITEM_SOLID_LIGHT_SHIELD = 1
Core.GetPlayerData = function(_) return playerData end
Core.GetGLSolidShieldOrbitalSprite = function() return orbitalSprite end
Core.GetShieldOrbitPos = function(player, _)
    return player.Position + Vector.new(36, 0)
end
Core.LoadItemIDs = function() end

local player = {
    Position = Vector.new(100, 100),
    Index = 0,
}
function player:HasCollectible(id) return id == Core.ITEM_SOLID_LIGHT_SHIELD end
function player:GetHeadDirection() return 3 end

-- ===================== CARGA =====================
local fxFactory = dofile("modules/fx_shield_items.lua")
fxFactory(Core)

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

local function clearLog() spriteLog = {} end
local function ops(name)
    local out = {}
    for _, e in ipairs(spriteLog) do
        if e.op == name then table.insert(out, e) end
    end
    return out
end
local function renderOnce()
    local before = #ops("Render")
    Core.RenderGLSolidShieldFront(player, Vector.Zero())
    return #ops("Render") - before
end

-- ===================== (D) 1 render/frame + alpha 0.95 =====================
clearLog()
playerData.shieldDeflectTimer = 0
for i = 1, 4 do
    gameFrame = gameFrame + 1
    check(renderOnce() == 1, "(D): RenderGLSolidShieldFront hace 1 Render por llamada (frame Orbit " .. i .. ")")
end
check(orbitalSprite.Color ~= nil and orbitalSprite.Color.A == 0.95,
    "(D): alpha orbital continuo 0.95")

-- ===================== (A)(B)(C) rafaga deflect 12 -> 0 y retorno =====================
clearLog()
playerData.shieldDeflectTimer = 12
local deflectFrames = {}
local sawPlayDeflect = false
for t = 12, 1, -1 do
    playerData.shieldDeflectTimer = t
    gameFrame = gameFrame + 1
    local logBefore = #spriteLog
    check(renderOnce() == 1, "(D): 1 Render durante Deflect (timer " .. t .. ")")
    for k = logBefore + 1, #spriteLog do
        local e = spriteLog[k]
        if e.op == "Play" and e.anim == "Deflect" then sawPlayDeflect = true end
        if e.op == "SetFrame" and e.anim == "Deflect" then
            table.insert(deflectFrames, e.frame)
        end
    end
end
check(sawPlayDeflect, "(A): entrar en Deflect usa Play('Deflect')")

-- Cross-animacion: ningun SetFrame con anim distinta de la activa.
local crossWrites = 0
for _, e in ipairs(spriteLog) do
    if e.op == "SetFrame" and e.anim ~= e.activeAtCall then crossWrites = crossWrites + 1 end
end
check(crossWrites == 0, "(A): SetFrame solo intra-animacion (0 escrituras cruzadas, hubo " .. crossWrites .. ")")

-- Frames monotonos 0-3.
local mono = true
for i = 2, #deflectFrames do
    if deflectFrames[i] < deflectFrames[i - 1] then mono = false end
end
local inRange = true
for _, f in ipairs(deflectFrames) do
    if f < 0 or f > 3 then inRange = false end
end
check(#deflectFrames == 12, "(C): 12 frames Deflect registrados (uno por timer 12..1), hubo " .. #deflectFrames)
check(mono and inRange, "(C): frames Deflect monotonos 0-3")
check(deflectFrames[#deflectFrames] == 3, "(C): Deflect termina en frame 3")

-- (B) fin del deflect: retorno explicito a Orbit via Play.
clearLog()
playerData.shieldDeflectTimer = 0
gameFrame = gameFrame + 1
renderOnce()
local sawPlayOrbit = false
for _, e in ipairs(spriteLog) do
    if e.op == "Play" and e.anim == "Orbit" then sawPlayOrbit = true end
end
check(sawPlayOrbit, "(B): Deflect termina con Play('Orbit') (sin Play hay parpadeo/salto)")

-- Tras el retorno, Orbit sigue continuo.
clearLog()
for i = 1, 3 do
    gameFrame = gameFrame + 1
    check(renderOnce() == 1, "(D): 1 Render tras retorno a Orbit (" .. i .. ")")
end

-- ===================== (E) duracion deflect unica en shield.lua =====================
local f = io.open("modules/shield.lua", "r")
local shieldSrc = f and f:read("*a") or ""
if f then f:close() end
local durations = {}
for n in shieldSrc:gmatch("shieldDeflectTimer%s*=%s*(%d+)") do
    table.insert(durations, tonumber(n))
end
check(#durations >= 2, "(E): shield.lua define duracion deflect al menos 2 veces (halladas " .. #durations .. ")")
local unique = {}
for _, n in ipairs(durations) do unique[n] = true end
local nUnique = 0
for _ in pairs(unique) do nUnique = nUnique + 1 end
check(nUnique == 1, "(E): duracion deflect unica en shield.lua (halladas: "
    .. table.concat(durations, ",") .. ")")

-- ===================== RESUMEN =====================
io.stdout:write(string.format("shield_orbit_flicker: %d ok, %d fallos\n", passes, failures))
if failures > 0 then os.exit(1) end
