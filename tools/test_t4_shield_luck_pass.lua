-- tools/test_t4_shield_luck_pass.lua
-- TDD test para T4 (migración a Core.GetShieldOrbitPos + reflect Luck-scaled + bypass):
--
--   (1) fx_shield_items.lua: el render usa Core.GetShieldOrbitPos(player, data)
--       en vez de data.shieldWorldPos. Si la función devuelve nil (no existe
--       aún, datos incompletos), cae al fallback (player.Position + Vector(36,0)).
--
--   (2) shield.lua:
--       (a) NO escribe data.shieldWorldPos (compat eliminada en T4).
--       (b) Rama orbital: roll Luck-scaled.
--           chance = min(SHIELD_REFLECT_BASE + Luck * SHIELD_REFLECT_PER_LUCK,
--                        SHIELD_REFLECT_MAX)
--           Si falla el roll, marca proj:GetData().glShieldBypass = true
--           y NO destruye el proyectil (deja pasar).
--           Si pasa el roll, refleja (mismo comportamiento de antes).
--       (c) Rama MC_ENTITY_TAKE_DMG: si srcEnt:GetData().glShieldBypass == true,
--           return sin reflect y sin bloquear. Si no, refleja según las
--           constantes Core.SHIELD_REFLECT_* (sin literales 0.25/0.05/0.75).
--
-- No toca radios del orbital, dmg del contacto, SFX ni posición del aura.
-- Compatible con Lua 5.1.

-- ===================== STUBS Vector/Color/Direction =====================
Vector = {}
local VectorMT = {}
function Vector.new(x, y)
    local u
    if newproxy then
        u = newproxy(true)
        local data = {X = x or 0, Y = y or 0}
        getmetatable(u).__index = function(_, k)
            if k == "X" or k == "Y" then return data[k] end
            return Vector[k]
        end
        getmetatable(u).__newindex = function(_, k, v) data[k] = v end
        getmetatable(u).__add = VectorMT.__add
        getmetatable(u).__sub = VectorMT.__sub
        getmetatable(u).__unm = VectorMT.__unm
        getmetatable(u).__mul = VectorMT.__mul
        getmetatable(u).__eq = VectorMT.__eq
        getmetatable(u).__tostring = function() return string.format("Vector(%g,%g)", data.X, data.Y) end
    else
        -- PUC 5.1 sin newproxy: tabla normal con metatable.
        u = setmetatable({X = x or 0, Y = y or 0}, {
            __index = Vector,
            __add = VectorMT.__add,
            __sub = VectorMT.__sub,
            __unm = VectorMT.__unm,
            __mul = VectorMT.__mul,
            __eq = VectorMT.__eq,
            __tostring = function(self) return string.format("Vector(%g,%g)", self.X, self.Y) end,
        })
    end
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
VectorMT.__unm = function(a) return Vector.new(-a.X, -a.Y) end
VectorMT.__mul = function(a, b)
    if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
    if type(a) == "number" then return Vector.new(a * b.X, a * b.Y) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end
function Vector.Zero() return Vector.new(0, 0) end

-- Color stub (production usa Color(R,G,B,A,ROff,GOff,BOff)).
function Color(r, g, b, a, ro, go, bo)
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 0, ROff = ro, GOff = go, BOff = bo }
end

-- ===================== ENUMS ISAAC (subconjunto) =====================
Isaac = {}
EntityType = {
    ENTITY_PLAYER    = 1,
    ENTITY_PROJECTILE = 9,
    ENTITY_TEAR       = 2,
    ENTITY_EFFECT     = 1003,
}
TearVariant = { BLUE = 1 }
EffectVariant = { WATER_SPLASH = 38 }
TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 4 }
DamageFlag = { DAMAGE_NO_MODIFIERS = 33554432 }
Direction = { LEFT = 1, RIGHT = 0, UP = 2, DOWN = 3 }
SoundEffect = { SOUND_TEARS_FIRE = 14, SOUND_ROCK_CRUMBLE = 62 }
ActiveSlot = { SLOT_PRIMARY = 0 }
ModCallbacks = {
    MC_POST_UPDATE          = 1,
    MC_ENTITY_TAKE_DMG      = 2,
    MC_POST_PLAYER_RENDER   = 32,
}
DamageFlag = setmetatable({}, {__index = function(_, k)
    if k == "DAMAGE_NO_MODIFIERS" then return 33554432 end
    return 0
end})

-- ===================== STUBS JUEGO =====================
-- Iteradores FindByType/GetRoomEntities controlables por test.
local projectiles = {}
local roomEnts = {}

function Isaac.FindByType(_, _, _, _) return projectiles end
function Isaac.GetRoomEntities() return roomEnts end
function Isaac.GetPlayer(_) return _testPlayer end  -- los tests arman el player
function Isaac.WorldToScreen(v) return v end  -- los tests inyectan vectores directos
function Isaac.Spawn(etype, evar, _, pos, vel, _owner)
    -- Sólo nos interesa el spawn del tear reflejado para contarlo.
    if etype == EntityType.ENTITY_TEAR then
        return {
            Position = pos, Velocity = vel,
            CollisionDamage = 0, TearFlags = 0, Scale = 1,
            _spawnTear = true,
            GetSprite = function(self) return { Color = nil } end,
            ToTear = function(self) return self end,
        }
    elseif etype == EntityType.ENTITY_EFFECT then
        return {
            GetSprite = function(self) return { Color = nil } end,
            Scale = 1,
        }
    end
    return nil
end

function Game() return { GetNumPlayers = function() return 1 end, GetFrameCount = function() return 0 end } end
function SFXManager() return { Play = function() end } end

-- ===================== STUBS CORE =====================
local Core = {}
Core.GL = {
    _cbs = {},
    AddCallback = function(self, _, fn) table.insert(self._cbs, fn) end,
}
-- Constantes de balance (mismas que core.lua declara).
Core.SHIELD_REFLECT_BASE       = 0.25
Core.SHIELD_REFLECT_PER_LUCK   = 0.05
Core.SHIELD_REFLECT_MAX        = 0.75
Core.ITEM_SOLID_LIGHT_SHIELD   = 1  -- ID ficticio positivo
Core.GetPlayerData = function() return _dataOverride end
Core.LoadItemIDs = function() end

-- GetShieldOrbitPos inyectable. Por defecto: player.Position + Vector(36,0).
Core.GetShieldOrbitPos = function(player, data)
    return player.Position + Vector.new(36, 0)
end

-- Registro de spawns de tear (para validar reflect vs pass).
local tearSpawnCount = 0
local origSpawn = Isaac.Spawn
function Isaac.Spawn(etype, evar, idx, pos, vel, owner)
    if etype == EntityType.ENTITY_TEAR then
        tearSpawnCount = tearSpawnCount + 1
    end
    return origSpawn(etype, evar, idx, pos, vel, owner)
end

-- Cargar shield.lua y fx_shield_items.lua.
-- shield.lua usa el operador `|` (Lua 5.3+, válido en el motor del juego).
-- Para poder parsearlo con Lua 5.1 (test runner) sustituimos por string las dos
-- ocurrencias exactas `| TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING`
-- por `+ ... + ...` (los stubs de TearFlags son potencias de 2, así que la
-- suma equivale al OR bitwise).
local function loadShieldFactory(path)
    local f = io.open(path, "r")
    local src = f and f:read("*a") or ""
    if f then f:close() end
    local patched, n = src:gsub(
        "| TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING",
        "+ TearFlags.TEAR_SPECTRAL + TearFlags.TEAR_PIERCING",
        2,    -- shield.lua tiene exactamente 2 sitios con este OR
        true  -- plain text (sin metacaracteres de patrón Lua)
    )
    assert(n == 2, "test_t4: se esperaban 2 ocurrencias del OR en shield.lua, halladas " .. tostring(n))
    local chunk, err = loadstring(patched, path)
    assert(chunk, err)
    return chunk()
end
local shieldFactory = loadShieldFactory("modules/shield.lua")
shieldFactory(Core)
local fxFactory = dofile("modules/fx_shield_items.lua")
fxFactory(Core)

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
    else failures = failures + 1; io.stderr:write("FAIL: "..name.." no es function\n") end
end

-- Player mock con todo lo que usan shield.lua + fx_shield_items.lua.
local function makePlayer(posX, posY, opts)
    opts = opts or {}
    local p = {
        Position = Vector.new(posX or 0, posY or 0),
        Damage   = opts.damage or 3.5,
        Luck     = opts.luck or 0,
        Type     = EntityType.ENTITY_PLAYER,
        _headDir = opts.headDir or Direction.DOWN,
        _hasShield = opts.hasShield ~= false,
    }
    function p:HasCollectible(id) return id == Core.ITEM_SOLID_LIGHT_SHIELD and self._hasShield end
    function p:HasTrinket() return false end
    function p:GetActiveItem() return -1 end
    function p:GetHeadDirection() return self._headDir end
    function p:GetData() return self._data end
    function p:SetData(d) self._data = d end
    function p:ToPlayer() return self end
    return p
end

local function makeData(opts)
    opts = opts or {}
    local d = {}
    for k, v in pairs(opts) do d[k] = v end
    d.shieldOrbitAngle = d.shieldOrbitAngle or 0
    d.lastShootDir     = d.lastShootDir or Vector.new(1, 0)
    d.shieldDeflectTimer = d.shieldDeflectTimer or 0
    return d
end

-- Ejecuta el callback MC_POST_UPDATE registrado por shield.lua.
-- internals: iny. de projectiles / enemies.
local function runShieldUpdate(perFrame)
    if perFrame ~= nil then
        projectiles = perFrame.projectiles or {}
        roomEnts    = perFrame.roomEnts    or {}
    end
    -- Solo invoca el primer callback (orbital update). El callback de
    -- MC_ENTITY_TAKE_DMG se invoca manualmente con su firma completa.
    if Core.GL._cbs[1] then Core.GL._cbs[1]() end
end

-- ===================== (a) Compat shieldWorldPos eliminada =====================
-- El orbital NO debe escribir data.shieldWorldPos.
local player = makePlayer(0, 0, { hasShield = true })
local data   = makeData()
player:SetData({ GreenLantern = data })
_dataOverride = data
projectiles, roomEnts = {}, {}
_testPlayer = player
runShieldUpdate({})
check(data.shieldWorldPos == nil,
      "T4(a): shield.lua ya NO debe escribir data.shieldWorldPos")

-- ===================== (1) fx_shield_items.lua usa GetShieldOrbitPos =====================
exists("RenderGLSolidShieldBehind")
exists("RenderGLSolidShieldFront")

-- Sprite stub neutral para que RenderGLSolidShieldFront/Behind avancen
-- hasta la lectura de Core.GetShieldOrbitPos.
local function makeShieldSpr()
    return {
        SetFrame = function() end,
        Render   = function() end,
        Scale    = Vector.new(1, 1),
        Color    = nil,
    }
end
Core.GetGLSolidShieldSprite = function() return makeShieldSpr() end

-- Spy sobre Core.GetShieldOrbitPos: contar invocaciones.
local orbitCalls = 0
local orbitReturn = Vector.new(50, 50)
Core.GetShieldOrbitPos = function(p, d)
    orbitCalls = orbitCalls + 1
    return orbitReturn
end

local renderOffset = Vector.new(0, 0)
local playerForRender = makePlayer(100, 100, { hasShield = true })
playerForRender:SetData({ GreenLantern = makeData() })

orbitCalls = 0
Core.RenderGLSolidShieldFront(playerForRender, renderOffset)
check(orbitCalls >= 1,
      "T4(1): RenderGLSolidShieldFront debe llamar a Core.GetShieldOrbitPos")

-- Behind (aura hexagonal sobre el torso) NO consume la posición del orbital,
-- solo el SPEC exige migrar donde se leía data.shieldWorldPos (Front).
-- Verificamos que Behind sigue funcionando y no rompe con GetShieldOrbitPos=nil.
local behindOk = pcall(function()
    Core.RenderGLSolidShieldBehind(playerForRender, renderOffset)
end)
check(behindOk, "T4(1): RenderGLSolidShieldBehind sigue funcionando")

-- Fallback: si Core.GetShieldOrbitPos devuelve nil → render cae a
-- (player.Position + Vector(36, 0)). Verificamos que no rompe.
local renderOk = pcall(function()
    Core.GetShieldOrbitPos = function() return nil end
    Core.RenderGLSolidShieldFront(playerForRender, renderOffset)
    Core.RenderGLSolidShieldBehind(playerForRender, renderOffset)
end)
check(renderOk,
      "T4(1): render con GetShieldOrbitPos=nil no debe romper (fallback interno)")

-- ===================== (2b) Rama orbital: Luck-scaled, bypass =====================
-- Restablecer GetShieldOrbitPos a un comportamiento controlable.
local function makeProj(posX, posY)
    local proj = {
        Position = Vector.new(posX, posY),
        Velocity = Vector.new(-4, 0),
        Type     = EntityType.ENTITY_PROJECTILE,
        _dead = false,
        _data = {},
    }
    function proj:IsVulnerableEnemy() return false end
    function proj:IsDead() return self._dead end
    function proj:Die() self._dead = true end
    function proj:GetData() return self._data end
    function proj:ToProjectile() return self end
    return proj
end

-- Forzar el roll siempre "miss" → 0% reflect.
local origRandom = math.random
math.random = function(_, _) return 1.0 end  -- > MAX, falla siempre

local p2 = makePlayer(0, 0, { hasShield = true, luck = 0 })
local d2 = makeData({ shieldOrbitAngle = 0, lastShootDir = Vector.new(1, 0) })
p2:SetData({ GreenLantern = d2 })
_dataOverride = d2
_testPlayer = p2

-- Proyectil cerca del orbital. GetShieldOrbitPos devuelve (0,0).
Core.GetShieldOrbitPos = function() return Vector.new(0, 0) end
local projA = makeProj(5, 0)   -- dist = 5 <= 22, sería "atrapado" antes
projectiles = { projA }
roomEnts    = {}
runShieldUpdate()

check(projA:GetData().glShieldBypass == true,
      "T4(2b): al fallar el roll, el proyectil lleva glShieldBypass = true")
check(projA._dead == false,
      "T4(2b): al fallar el roll, el proyectil NO debe morir (deja pasar)")

-- Forzar roll siempre "hit" → 0% reflect imposible.
math.random = function(_, _) return 0.0 end
local projB = makeProj(5, 0)
projectiles = { projB }
roomEnts    = {}
runShieldUpdate()
check(projB:GetData().glShieldBypass == nil,
      "T4(2b): al pasar el roll, NO se marca glShieldBypass")
check(projB._dead == true,
      "T4(2b): al pasar el roll, el proyectil muere (reflect)")

math.random = origRandom  -- restaurar

-- ===================== (2b-T4) Rama orbital: SKIP si ya trae glShieldBypass =====================
-- Bug T4: un proyectil lento que falla el roll lleva glShieldBypass=true, pero
-- sigue dentro del radio 22px del orbital varios frames. Sin el skip, el bucle
-- orbital re-tira el dado cada frame, inflando el bloqueo real por encima
-- del 25-75% declarado. Aqui verificamos que el orbital SALTA el proyectil
-- si ya trae la marca (mismo estilo nil-safe que el guard de la rama MC_ENTITY_TAKE_DMG).
local p2b = makePlayer(0, 0, { hasShield = true, luck = 0 })
local d2b = makeData({ shieldOrbitAngle = 0, lastShootDir = Vector.new(1, 0) })
p2b:SetData({ GreenLantern = d2b })
_dataOverride = d2b
_testPlayer = p2b

-- Proyectil con bypass YA marcado (simula que ya falló el roll en un frame previo).
local projC = makeProj(5, 0)
projC:GetData().glShieldBypass = true

-- Forzar el roll a "hit" para maximizar la señal: sin el skip, el orbital
-- re-entraría, pasaría el dado y mataría al proyectil. Con el skip, no debe
-- tocar ni la marca ni el flag _dead.
math.random = function(_, _) return 0.0 end
Core.GetShieldOrbitPos = function() return Vector.new(0, 0) end
projectiles = { projC }
roomEnts    = {}
runShieldUpdate()

check(projC._dead == false,
      "T4(2b-skip): orbital NO debe re-matar un proyectil ya marcado con glShieldBypass")
-- Y la marca debe seguir exactamente como estaba (no se sobreescribe, no se borra).
check(projC:GetData().glShieldBypass == true,
      "T4(2b-skip): orbital NO debe tocar glShieldBypass de un proyectil ya marcado")

-- Y el SKIP debe ser nil-safe: GetData() que devuelve nil no debe reventar.
local projD = makeProj(7, 0)
projD.GetData = function() return nil end  -- silencia: produce el caso nil
projectiles = { projD }
roomEnts    = {}
local skipNilSafe = pcall(function() runShieldUpdate() end)
check(skipNilSafe,
      "T4(2b-skip): skip de glShieldBypass debe ser nil-safe (pcall sobre GetData)")

math.random = origRandom

-- Kill-check: si se elimina el skip de glShieldBypass en el bucle orbital, el
-- test anterior debe fallar. Heurística sobre modules/shield.lua: el bucle de
-- proyectiles debe contener `glShieldBypass` ANTES de cualquier `math.random`
-- en la rama de radius<=22. Sin esto, un proyectil pre-marcado sería
-- re-evaluado cada frame.
local srcShield = io.open("modules/shield.lua", "r")
local shieldContent = srcShield and srcShield:read("*a") or ""
srcShield:close()

-- Encuentra el bucle de proyectiles orbital (entre MC_POST_UPDATE y el callback
-- de MC_ENTITY_TAKE_DMG).
local _, postEnd = shieldContent:find("AddCallback%(ModCallbacks%.MC_POST_UPDATE", 1)
local _, dmgStart = shieldContent:find("AddCallback%(ModCallbacks%.MC_ENTITY_TAKE_DMG", 1)
local orbitalRegion = shieldContent:sub(postEnd or 1, (dmgStart or #shieldContent) - 1)
local bypassInOrbital = orbitalRegion:find("glShieldBypass", 1, true) ~= nil
check(bypassInOrbital,
      "T4(2b-skip): el bucle orbital (entre MC_POST_UPDATE y MC_ENTITY_TAKE_DMG) " ..
      "debe contener un skip sobre glShieldBypass")

-- ===================== (2c) MC_ENTITY_TAKE_DMG con bypass =====================
-- Si el srcEnt lleva glShieldBypass = true → callback devuelve sin bloquear.
-- Verificamos que NO spawnea tear (no reflect).
local p3 = makePlayer(0, 0, { hasShield = true, luck = 0 })
local d3 = makeData()
p3:SetData({ GreenLantern = d3 })
_testPlayer = p3

local bypassProj = makeProj(0, 0)
bypassProj:GetData().glShieldBypass = true

tearSpawnCount = 0
local sourceProj = { Entity = bypassProj }
-- Ejecutar el callback de daño (segundo registrado).
local dmgCallback
for i, cb in ipairs(Core.GL._cbs) do
    if i == 2 then dmgCallback = cb; break end
end
local ret = dmgCallback(nil, p3, 1.0, 0, sourceProj)
check(ret == nil,
      "T4(2c): srcEnt con glShieldBypass → callback retorna nil (sin bloque)")
check(tearSpawnCount == 0,
      "T4(2c): srcEnt con glShieldBypass → NO se spawnea tear reflejado")

-- Si el srcEnt NO lleva glShieldBypass → comportamiento normal (reflect si pasa roll).
-- Forzar roll a 0 (pasa) → debería reflejar.
math.random = function(_, _) return 0.0 end
local noBypassProj = makeProj(0, 0)
tearSpawnCount = 0
local src3 = { Entity = noBypassProj }
local ret3 = dmgCallback(nil, p3, 1.0, 0, src3)
-- Puede devolver nil (no bloqueó) o false (bloqueó). Lo importante: spawn de tear.
check(tearSpawnCount >= 1,
      "T4(2c): sin glShieldBypass y roll favorable → spawn de tear reflejado")
math.random = origRandom

-- Invariante de fórmula: shield.lua NO debe usar literales 0.25/0.05/0.75.
-- Leemos el fuente del módulo y comprobamos que la rama MC_ENTITY_TAKE_DMG
-- use Core.SHIELD_REFLECT_*.
local src = io.open("modules/shield.lua", "r")
local content = src and src:read("*a") or ""
src:close()
local hasBaseConst = content:find("Core.SHIELD_REFLECT_BASE", 1, true) ~= nil
local hasLuckConst = content:find("Core.SHIELD_REFLECT_PER_LUCK", 1, true) ~= nil
local hasMaxConst  = content:find("Core.SHIELD_REFLECT_MAX", 1, true) ~= nil
check(hasBaseConst, "T4(2c): shield.lua referencia Core.SHIELD_REFLECT_BASE")
check(hasLuckConst, "T4(2c): shield.lua referencia Core.SHIELD_REFLECT_PER_LUCK")
check(hasMaxConst,  "T4(2c): shield.lua referencia Core.SHIELD_REFLECT_MAX")

-- Y NO debe quedar la rama vieja con literales 0.25/0.05/0.75 en el cálculo
-- de chance. Aceptamos esos números en comentarios/changelog, pero NO en
-- la fórmula activa (línea con `math.random`). Heurística: la línea
-- "math.min(...)" o "chance =" debe incluir los nombres de constantes.
local formulaLine
for line in content:gmatch("[^\n]+") do
    if line:find("chance", 1, true) and line:find("SHIELD_REFLECT", 1, true) then
        formulaLine = line; break
    end
end
check(formulaLine ~= nil,
      "T4(2c): existe una línea 'chance' que referencia Core.SHIELD_REFLECT_*")

-- Y que la rama MC_ENTITY_TAKE_DMG respete el bypass antes del roll.
-- Heurística: el código fuente debe contener el orden
--   glShieldBypass -> return
-- ANTES de cualquier `math.random` o spawn de tear.
local function cbRegion(cbName)
    -- Buscamos el registro del callback (no menciones en comentarios).
    local _, finish = content:find("AddCallback%(ModCallbacks%.MC_ENTITY_TAKE_DMG", 1)
    if not finish then return "" end
    -- Tomamos hasta el final del archivo (en este mod solo hay 1 callback de este tipo).
    return content:sub(finish)
end
local region = cbRegion()
local bypassIdx    = region:find("glShieldBypass", 1, true)
local rollIdxInCb  = region:find("math.random", 1, true)
check(bypassIdx ~= nil,
      "T4(2c): rama MC_ENTITY_TAKE_DMG referencia glShieldBypass")
check(rollIdxInCb ~= nil,
      "T4(2c): rama MC_ENTITY_TAKE_DMG aún conserva un roll (caso normal)")
check(bypassIdx < rollIdxInCb,
      "T4(2c): el guard glShieldBypass debe ir ANTES del math.random")

-- Y NO debe haber escritura de data.shieldWorldPos en shield.lua.
check(not content:find("data.shieldWorldPos", 1, true),
      "T4(a): shield.lua NO debe contener 'data.shieldWorldPos' (ni lectura ni escritura)")

-- Y el render debe usar Core.GetShieldOrbitPos.
local fxSrc = io.open("modules/fx_shield_items.lua", "r")
local fxContent = fxSrc and fxSrc:read("*a") or ""
fxSrc:close()
check(fxContent:find("Core.GetShieldOrbitPos", 1, true) ~= nil,
      "T4(1): fx_shield_items.lua referencia Core.GetShieldOrbitPos")
check(not fxContent:find("data.shieldWorldPos", 1, true),
      "T4(1): fx_shield_items.lua NO debe leer data.shieldWorldPos")

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_t4_shield_luck_pass] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end