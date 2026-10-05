-- tools/test_t3_shield_orbit_pos.lua
-- TDD test para Core.GetShieldOrbitPos (T3):
--   firma: function Core.GetShieldOrbitPos(player, data)
--   formula: player.Position + orbit*0.6 + facing*24
--     orbit  = Vector(cos(data.shieldOrbitAngle)*36, sin(data.shieldOrbitAngle)*24)
--     facing = data.lastShootDir  (fallback a head-dir via GetHeadDirection si nil)
--
-- No toca radios (36/24), angulo (data.shieldOrbitAngle), reflect ni dano:
-- aqui solo se valida la formula pura.
--
-- Compatible con Lua 5.1.

-- ===================== STUBS Vector/Color/Direction =====================
-- Isaac Vector es userdata (C++ userdata). El bug de B1 era que el codigo de
-- produccion hacia `type(facing) ~= "table"` para validar `data.lastShootDir`,
-- pero un userdata real NO es "table" en Lua, asi que el fallback se activaba
-- siempre. Para reproducir fielmente el entorno de Isaac, este stub emula
-- userdata via `newproxy(true)` (Lua 5.1) y asocia los metodos al metatable,
-- de modo que `type(v) == "userdata"` (no "table"). Asi el harness atraparia
-- el bug original.
Vector = {}
local VectorMT = {}
function Vector.new(x, y)
    local u = newproxy(true)
    local data = {X = x or 0, Y = y or 0}
    getmetatable(u).__index = function(_, k)
        if k == "X" or k == "Y" then return data[k] end
        return VectorMT[k]
    end
    getmetatable(u).__newindex = function(_, k, v) data[k] = v end
    getmetatable(u).__add = VectorMT.__add
    getmetatable(u).__sub = VectorMT.__sub
    getmetatable(u).__mul = VectorMT.__mul
    getmetatable(u).__eq = VectorMT.__eq
    getmetatable(u).__tostring = function() return string.format("Vector(%g,%g)", data.X, data.Y) end
    return u
end
setmetatable(Vector, {__call = function(_, x, y) return Vector.new(x, y) end})
function Vector:Length() return math.sqrt(self.X*self.X + self.Y*self.Y) end
function Vector:Normalized()
    local l = self:Length()
    if l <= 0.001 then return Vector.new(1, 0) end
    return Vector.new(self.X/l, self.Y/l)
end
VectorMT.__add = function(a, b)
    if type(b) == "number" then return Vector.new(a.X + b, a.Y + b) end
    return Vector.new(a.X + b.X, a.Y + b.Y)
end
VectorMT.__sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
VectorMT.__mul = function(a, b)
    if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end
VectorMT.__eq = function(a, b)
    return type(a) == "userdata" and type(b) == "userdata"
        and math.abs(a.X - b.X) < 1e-9 and math.abs(a.Y - b.Y) < 1e-9
end
Vector.Zero = Vector.new(0, 0)

-- Direction enum (subconjunto usado por ring_aim.lua y por el fallback del shield)
Direction = {
    LEFT  = 1,
    RIGHT = 0,
    UP    = 2,
    DOWN  = 3,
}

-- ===================== STUB FRAMEWORK =====================
local Core = {}

-- Cargar ring_aim.lua y aplicarlo al Core stub.
local factory = dofile("modules/ring_aim.lua")
factory(Core)

-- ===================== HELPERS =====================
local passes, failures = 0, 0
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
        io.stderr:write("FAIL: " .. tostring(name) .. " no es function en Core\n")
    end
end

-- Helper: player mock con Position (userdata) y GetHeadDirection() controlados.
local function makePlayer(posX, posY, headDir)
    local p = { Position = Vector.new(posX or 0, posY or 0) }
    function p:GetHeadDirection() return headDir or Direction.DOWN end
    return p
end

local function approx(a, b, tol)
    tol = tol or 1e-6
    return math.abs(a - b) <= tol
end

-- ===================== TESTS =====================
exists("GetShieldOrbitPos")

-- 1. angle=0 con lastShootDir hacia abajo (DOWN -> (0,1)).
--    orbit  = (cos(0)*36, sin(0)*24) = (36, 0)
--    facing = (0, 1)
--    result = (0,0) + (36,0)*0.6 + (0,1)*24 = (21.6, 24)
local p1 = makePlayer(0, 0, Direction.DOWN)
local d1 = { shieldOrbitAngle = 0, lastShootDir = Vector.new(0, 1) }
local r1 = Core.GetShieldOrbitPos(p1, d1)
check(r1 ~= nil, "angle=0 + facing DOWN: devuelve Vector no nil")
if r1 then
    check(approx(r1.X, 21.6) and approx(r1.Y, 24.0),
          string.format("angle=0 + DOWN: esperaba (21.6, 24.0), dio (%.6f, %.6f)", r1.X, r1.Y))
end

-- 2. angle=pi/2 con lastShootDir a la derecha (1,0).
--    orbit  = (cos(pi/2)*36, sin(pi/2)*24) = (0, 24)
--    facing = (1, 0)
--    result = (10,20) + (0,24)*0.6 + (1,0)*24 = (10+24, 20+14.4) = (34.0, 34.4)
local p2 = makePlayer(10, 20, Direction.RIGHT)
local d2 = { shieldOrbitAngle = math.pi / 2, lastShootDir = Vector.new(1, 0) }
local r2 = Core.GetShieldOrbitPos(p2, d2)
if r2 then
    check(approx(r2.X, 34.0) and approx(r2.Y, 34.4),
          string.format("angle=pi/2 + RIGHT: esperaba (34, 34.4), dio (%.6f, %.6f)", r2.X, r2.Y))
end

-- 3. lastShootDir = nil -> fallback a head direction via GetHeadDirection.
--    Player con headDir=UP -> facing = (0, -1).
--    angle=0 -> orbit = (36, 0)
--    result = (5, 5) + (36,0)*0.6 + (0,-1)*24 = (5+21.6, 5-24) = (26.6, -19.0)
local p3 = makePlayer(5, 5, Direction.UP)
local d3 = { shieldOrbitAngle = 0, lastShootDir = nil }
local r3 = Core.GetShieldOrbitPos(p3, d3)
if r3 then
    check(approx(r3.X, 26.6) and approx(r3.Y, -19.0),
          string.format("lastShootDir nil + headDir UP: esperaba (26.6, -19.0), dio (%.6f, %.6f)",
                        r3.X, r3.Y))
end

-- 4. lastShootDir no nil con magnitud normal -> gana sobre headDir.
--    headDir=UP -> (-1 si NO se usara), pero lastShootDir=(1,1) manda.
--    angle=pi/4 -> orbit = (cos(pi/4)*36, sin(pi/4)*24) ~ (25.4558, 16.9706)
--    result = (0,0) + (25.4558, 16.9706)*0.6 + (1,1)*24 = (15.2735 + 24, 10.1823 + 24)
--          = (39.2735, 34.1823)
local p4 = makePlayer(0, 0, Direction.UP)
local d4 = { shieldOrbitAngle = math.pi / 4, lastShootDir = Vector.new(1, 1) }
local r4 = Core.GetShieldOrbitPos(p4, d4)
if r4 then
    check(approx(r4.X, 39.2735, 1e-3) and approx(r4.Y, 34.1823, 1e-3),
          string.format("lastShootDir (1,1) gana sobre headDir: esperaba ~(39.27, 34.18), dio (%.6f, %.6f)",
                        r4.X, r4.Y))
end

-- 5. shieldOrbitAngle nil -> defaults a 0 (orbit = (36, 0)).
--    lastShootDir = (-1, 0).
--    result = (100, 200) + (36, 0)*0.6 + (-1, 0)*24 = (100 + 21.6 - 24, 200) = (97.6, 200)
local p5 = makePlayer(100, 200, Direction.DOWN)
local d5 = { lastShootDir = Vector.new(-1, 0) }  -- shieldOrbitAngle nil
local r5 = Core.GetShieldOrbitPos(p5, d5)
if r5 then
    check(approx(r5.X, 97.6) and approx(r5.Y, 200.0),
          string.format("angle nil -> 0: esperaba (97.6, 200), dio (%.6f, %.6f)",
                        r5.X, r5.Y))
end

-- 6. Firma (parametros): llamar con (player, data) devuelve Vector con X, Y numericos.
local p6 = makePlayer(0, 0, Direction.DOWN)
local d6 = { shieldOrbitAngle = 1.234, lastShootDir = Vector.new(0.7, -0.7) }
local r6 = Core.GetShieldOrbitPos(p6, d6)
check(r6 ~= nil, "firma (player, data): devuelve algo no nil")
if r6 then
    check(type(r6.X) == "number" and type(r6.Y) == "number",
          "firma: el retorno tiene campos numericos X e Y")
end

-- 7. Kill-check (regresion B1): bajo la nueva semantica, lastShootDir=Vector
--    se respeta porque tiene campos X,Y. Verifica ademas que el type-check
--    viejo (`type(v) ~= "table"`) descartaria el userdata y caeria al fallback
--    (headDir). Si el codigo de produccion volviera al guard viejo, este
--    test fallaria: el resultado caeria en la rama headDir=UP = (0,-1).
local p7 = makePlayer(0, 0, Direction.UP)
local d7 = { shieldOrbitAngle = 0, lastShootDir = Vector.new(1, 1) }
local r7 = Core.GetShieldOrbitPos(p7, d7)
if r7 then
    -- Con fix -> facing=(1,1) -> (0,0)+(36,0)*0.6+(1,1)*24 = (21.6+24, 0+24) = (45.6, 24)
    -- Con bug -> facing=(0,-1) -> (0,0)+(36,0)*0.6+(0,-1)*24 = (21.6, -24)
    check(approx(r7.X, 45.6) and approx(r7.Y, 24.0),
          string.format("B1 kill-check: lastShootDir=(1,1) debe respetarse, esperaba (45.6, 24.0), dio (%.6f, %.6f)",
                        r7.X, r7.Y))
    -- Verifica que el stub es userdata (no table) para reproducir Isaac real
    check(type(d7.lastShootDir) == "userdata",
          "B1 kill-check: stub Vector debe ser 'userdata' (no 'table') para reproducir Isaac")
end

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_t3_shield_orbit_pos] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end