-- tools/test_t5_oath_text.lua
-- TDD test para T5: juramentos poeticos "IN BRIGHTEST DAY..." (bateria Hal) e
-- "I AM PARALLAX!" (Coast City Tainted), con timer 90 y render Tainted.
--
-- Spec:
--   1. modules/item_battery.lua: tras el refill, si el player es Hal Jordan,
--      data.oathText = "IN BRIGHTEST DAY..." y data.oathTextTimer = 90.
--      Convive con el statusMsg mecanico existente (no lo sustituye semantica,
--      solo actualiza el texto poetico en pantalla).
--   2. modules/item_coastcity.lua: tras activar, data.oathText = "I AM PARALLAX!"
--      y data.oathTextTimer = 90.
--   3. modules/hud_render.lua: extiende el render de oathText/oathTextTimer a la
--      rama IsTaintedHal. Mismo patron que Hal: decremento currentGameFrame%2,
--      color verde Tainted. NO duplica decrementos.
--
-- Solo toca los 3 ficheros del SPEC. No toca Willpower/overcharge/RING OFFLINE/REBOOT.
-- Compatible con Lua 5.1.

-- ===================== STUBS Vector/Color =====================
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
function Vector.Zero() return Vector.new(0, 0) end
VectorMT.__add = function(a, b)
    if type(b) == "number" then return Vector.new(a.X + b, a.Y + b) end
    return Vector.new(a.X + b.X, a.Y + b.Y)
end
VectorMT.__sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
VectorMT.__unm = function(a) return Vector.new(-a.X, -a.Y) end
VectorMT.__mul = function(a, b)
    if type(b) == "number" then return Vector.new(a * b, a * b) end
    if type(a) == "number" then return Vector.new(a * b.X, a * b.Y) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end
function Color(r, g, b, a, ro, go, bo)
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 0, ROff = ro, GOff = go, BOff = bo }
end

-- ===================== STUBS ISAAC =====================
Isaac = {}
function Isaac.GetRoomEntities() return {} end
function Isaac.FindByType() return {} end
function Isaac.GetPlayer(_) return _testPlayer end
function Isaac.WorldToScreen(v) return v end
function Isaac.Spawn() return { GetSprite = function() return { Color = nil } end, Scale = 1 } end

-- SoundEffect para que SFXManager():Play no rompa.
SoundEffect = { SOUND_BATTERYCHARGE = 1, SOUND_POWERUP_SPEWER = 2, SOUND_SUPERHOLY = 3, SOUND_HELL_PORTAL2 = 4 }

-- DamageFlag / EntityRef / EntityFlag / EntityType / EffectVariant / CacheFlag.
DamageFlag = setmetatable({DAMAGE_NO_MODIFIERS = 33554432}, {__index = function(_, _) return 0 end})
EntityRef = function(_) return {} end
EntityFlag = { FLAG_FEAR = 1 }
EntityType = { ENTITY_EFFECT = 1003, ENTITY_PROJECTILE = 9 }
EffectVariant = { HALO = 1, WATER_SPLASH = 38 }
CacheFlag = {
    CACHE_FLYING = 1, CACHE_DAMAGE = 2, CACHE_SHOTSPEED = 4, CACHE_TEARFLAG = 8,
}

function Game() return {
    GetNumPlayers = function() return 1 end,
    GetFrameCount = function() return _frameCount or 0 end,
    GetLevel      = function() return { GetCurrentRoomIndex = function() return 0 end } end,
    GetRoom       = function() return { GetRenderMode = function() return nil end, GetCenterPos = function() return Vector.new(0, 0) end } end,
    GetHUD        = function() return { IsVisible = function() return true end } end,
    ShakeScreen   = function() end,
} end
function SFXManager() return { Play = function() end } end
function Options() return { HUDOffset = 0 } end
-- En el mod real, `Options` es una tabla global directa (no funcion).
Options = { HUDOffset = 0 }
function ModCallbacks() return {
    MC_USE_ITEM = 100, MC_POST_UPDATE = 1, MC_POST_RENDER = 32,
    MC_PRE_PLAYER_RENDER = 31, MC_POST_PLAYER_RENDER = 32,
} end
-- Necesario para la asignacion de tablas tipo `ModCallbacks.MC_USE_ITEM = ...` en el
-- source. Reasignable a una tabla real.
ModCallbacks = {
    MC_USE_ITEM          = 100,
    MC_POST_UPDATE       = 1,
    MC_POST_RENDER       = 32,
    MC_PRE_PLAYER_RENDER = 31,
    MC_POST_PLAYER_RENDER = 33,
}

-- ===================== STUBS CORE =====================
local Core = {}
Core.GL = {
    _cbs = {},
    AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
}

-- Constantes minimas para que item_battery / item_coastcity / hud_render carguen.
Core.ITEM_POWER_BATTERY  = 50   -- ID ficticio positivo para test
Core.ITEM_COAST_CITY     = 51
Core.LoadItemIDs         = function() end
Core.WILLPOWER_MAX                  = 100.0
Core.OVERCHARGE_T1_THRESHOLD        = 50.0
Core.OVERCHARGE_T2_THRESHOLD        = 90.0
Core.OVERCHARGE_T1_MULT             = 1.15
Core.OVERCHARGE_T2_MULT             = 1.25
Core.SPARK_MAX                      = 100.0
Core.COAST_CITY_DURATION            = 150
Core.MAX_STOLEN_RINGS               = 10
Core.STOLEN_RING_DMG                = 0.3

-- Estado por jugador. En el mod real, Core.GetPlayerData(player) consulta
-- player:GetData() y rellena con un template; aqui simplificamos a un map por
-- player.Index.
local dataByPlayer = {}
function Core.GetPlayerData(player)
    if not dataByPlayer[player.Index] then
        dataByPlayer[player.Index] = {
            willpower = Core.WILLPOWER_MAX,
            emeraldSparks = 0,
            stolenRings = 0,
            ringDepleted = false,
            overcharge = false,
            overchargeTier = 0,
            surgeBuff = false,
            coastCityActive = false,
            coastCityFrame = 0,
            coastCityBoost = 1.0,
            ringFlareTimer = 0,
            batteryConstructTimer = 0,
            oathText = "",
            oathTextTimer = 0,
        }
    end
    return dataByPlayer[player.Index]
end

Core.IsHalJordan  = function(p) return p._isHal end
Core.IsTaintedHal = function(p) return p._isTainted end
Core.GetCoastCity = function(p)
    return { active = false, spawnFrame = 0, roomIdx = -1, owner = p, sparkBonus = 1.0, totalDuration = Core.COAST_CITY_DURATION }
end
Core.activeCoastCityByPlayer = {}

-- RestoreHalRingPower: en el mod real hace mucho mas. Aqui solo aplicamos el
-- efecto minimo necesario para que el test sea realista: fija willpower al
-- max y limpia ringDepleted (sin tocar oathText — el item_battery.lua debe
-- ocuparse de eso, segun el SPEC de T5).
function Core.RestoreHalRingPower(player, newWillpower, _statusText)
    local d = Core.GetPlayerData(player)
    local wasDepleted = d.ringDepleted
    d.willpower = newWillpower or Core.WILLPOWER_MAX
    d.ringDepleted = (d.willpower <= 0)
    -- En el mod real, aqui se setea oathText SOLO si fue un reboot fresco.
    -- Pero como T5 indica que item_battery debe sobreescribirlo SIEMPRE con
    -- "IN BRIGHTEST DAY...", este stub no debe tocar el texto (deja que
    -- item_battery lo haga).
    return wasDepleted
end

-- Stubs de render (hud_render.lua los consume; aqui solo necesitamos que
-- existan para que el modulo cargue).
local drawTextCalls = {}
Core.DrawHudText = function(text, x, y, r, g, b, a)
    table.insert(drawTextCalls, { text = text, x = x, y = y, r = r, g = g, b = b, a = a })
end
Core.RenderGLSparkDrops          = function() end
Core.RenderGLPlayerAura          = function() end
Core.RenderGLSolidShieldBehind   = function() end
Core.RenderGLSolidShieldFront    = function() end
Core.RenderGLActiveItemAndTrinketEffects = function() end
Core.RenderGLBeamAndFlareForPlayer        = function() end
Core.IsRingActive                = function() return false end
Core.IsPlayerAimingUpForRender   = function() return false end
Core.EnsureEIDRegistered         = function() end
Core.RegisterStageAPIGraphics    = function() end
Core.SetEntityScaleAndColor      = function() end
Core.ApplyRingBeamSprite         = function() end
Core.CanUseContinuousBeam        = function() return false end
Core.StopContinuousBeam          = function() end
Core.GetShieldOrbitPos           = function() return Vector.new(36, 0) end
Core.SpawnLanternEmblemDrop      = function() end

-- RenderScaledText (engine).
Isaac.RenderScaledText = function() end

-- Isaac.Spawn ya stub arriba.
function Isaac.Spawn() return { GetSprite = function() return { Color = nil } end, Scale = 1 } end

-- ===================== HELPERS DE TEST =====================
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
local function resetData()
    dataByPlayer = {}
    drawTextCalls = {}
    Core.GL._cbs = {}
end

local function makeHalPlayer(idx)
    return {
        Index  = idx or 0,
        _isHal = true, _isTainted = false,
        Position = Vector.new(0, 0),
        Damage   = 3.5,
        Type     = 1,
        GetShootingInput = function() return Vector.new(0, 0) end,
        AddCacheFlags     = function() end,
        EvaluateItems     = function() end,
        AnimateHappy      = function() end,
        AddHearts         = function() end,
    }
end
local function makeTaintedPlayer(idx)
    return {
        Index  = idx or 0,
        _isHal = false, _isTainted = true,
        Position = Vector.new(0, 0),
        Damage   = 5.0,
        Type     = 1,
        GetShootingInput = function() return Vector.new(0, 0) end,
        AddCacheFlags     = function() end,
        EvaluateItems     = function() end,
        AnimateHappy      = function() end,
        AddHearts         = function() end,
        AddBlackHearts    = function() end,
        AddFear           = function() end,
    }
end

-- Busca el callback MC_USE_ITEM registrado por battery/coastcity.
local function findUseItemCallback()
    for _, c in ipairs(Core.GL._cbs) do
        if c.id == ModCallbacks.MC_USE_ITEM then return c.fn end
    end
    return nil
end
local function findPostRenderCallback()
    for _, c in ipairs(Core.GL._cbs) do
        if c.id == ModCallbacks.MC_POST_RENDER then return c.fn end
    end
    return nil
end

-- Carga los modulos bajo stub. Todos retornan factory(Core); los invocamos.
local function loadItemBattery()
    local factory = dofile("modules/item_battery.lua")
    factory(Core)
end
local function loadItemCoastCity()
    local factory = dofile("modules/item_coastcity.lua")
    factory(Core)
end
local function loadHudRender()
    local factory = dofile("modules/hud_render.lua")
    factory(Core)
end

-- ===================== (1) item_battery.lua: oath "IN BRIGHTEST DAY..." =====================
resetData()
loadItemBattery()
local useCb = findUseItemCallback()
check(useCb ~= nil, "T5(1): item_battery.lua registra un callback MC_USE_ITEM")

-- Caso A: Hal Jordan pulsa Power Battery con Willpower ALTO (no depleted) →
-- tras el refill debe quedar oathText = "IN BRIGHTEST DAY..." y timer = 90.
local hal = makeHalPlayer(0)
_testPlayer = hal
dataByPlayer[hal.Index] = { willpower = 80, ringDepleted = false }
useCb(nil, Core.ITEM_POWER_BATTERY, nil, hal, 0, 0, 0)

local d = dataByPlayer[hal.Index]
check(d.oathText == "IN BRIGHTEST DAY...",
      string.format("T5(1.A): oathText tras Battery en Hal debe ser 'IN BRIGHTEST DAY...', fue '%s'", tostring(d.oathText)))
check(d.oathTextTimer == 90,
      string.format("T5(1.A): oathTextTimer tras Battery en Hal debe ser 90, fue %s", tostring(d.oathTextTimer)))
-- d no debe ser nil (comprobacion sanity)
assert(d ~= nil, "data no debe ser nil tras Battery")

-- Caso B: statusMsg mecanico "OVERCHARGE MAX! (+25% DMG)" sigue siendo el que
-- se pasa a Core.RestoreHalRingPower (convive: el statusMsg no se sustituye
-- semanticamente, solo se actualiza el texto poetico del HUD). Verificamos que
-- NO se cambia la API: el statusText que recibe RestoreHalRingPower es el
-- mecanico ("OVERCHARGE MAX! (+25% DMG)" / "OVERCHARGE! (+15% DMG)" /
-- "WILLPOWER RESTORED!"). Lo capturamos espiando RestoreHalRingPower.
resetData()
local lastStatusText = nil
local origRestore = Core.RestoreHalRingPower
Core.RestoreHalRingPower = function(p, w, st) lastStatusText = st; return origRestore(p, w, st) end
loadItemBattery()
useCb = findUseItemCallback()
local hal2 = makeHalPlayer(0)
_testPlayer = hal2
dataByPlayer[hal2.Index] = { willpower = 95, ringDepleted = false }  -- >= T2 threshold
useCb(nil, Core.ITEM_POWER_BATTERY, nil, hal2, 0, 0, 0)
check(lastStatusText == "OVERCHARGE MAX! (+25% DMG)",
      string.format("T5(1.B): statusMsg mecanico sigue siendo 'OVERCHARGE MAX! (+25%% DMG)', fue '%s'", tostring(lastStatusText)))
-- Y el oath poetico sigue presente.
check(dataByPlayer[hal2.Index].oathText == "IN BRIGHTEST DAY...",
      "T5(1.B): el oath poetico se sobreescribe incluso en overcharge T2")
check(dataByPlayer[hal2.Index].oathTextTimer == 90,
      "T5(1.B): el oathTextTimer se mantiene en 90 en overcharge T2")
Core.RestoreHalRingPower = origRestore

-- Caso C: Tainted NO debe recibir el oath "IN BRIGHTEST DAY..." (ese es solo de Hal).
-- En Tainted, la rama de item_battery cae al else y llama
-- player:AddCacheFlags + EvaluateItems. Verificamos que NO se setea el oath.
resetData()
loadItemBattery()
useCb = findUseItemCallback()
local tainted = makeTaintedPlayer(0)
_testPlayer = tainted
dataByPlayer[tainted.Index] = { willpower = 0, ringDepleted = false, emeraldSparks = 0, stolenRings = 0 }
useCb(nil, Core.ITEM_POWER_BATTERY, nil, tainted, 0, 0, 0)
check(dataByPlayer[tainted.Index].oathText ~= "IN BRIGHTEST DAY...",
      string.format("T5(1.C): Tainted NO debe recibir oath 'IN BRIGHTEST DAY...', fue '%s'", tostring(dataByPlayer[tainted.Index].oathText)))

-- ===================== (2) item_coastcity.lua: oath "I AM PARALLAX!" =====================
resetData()
loadItemCoastCity()
useCb = findUseItemCallback()
check(useCb ~= nil, "T5(2): item_coastcity.lua registra un callback MC_USE_ITEM")

-- Tainted Hal pulsa Coast City. Tras activar, oathText = "I AM PARALLAX!" y timer = 90.
local th = makeTaintedPlayer(0)
_testPlayer = th
dataByPlayer[th.Index] = { emeraldSparks = 50.0, stolenRings = 2, coastCityActive = false, coastCityBoost = 1.0 }
local ret = useCb(nil, Core.ITEM_COAST_CITY, nil, th, 0, 0, 0)
local d2 = dataByPlayer[th.Index]
check(d2.oathText == "I AM PARALLAX!",
      string.format("T5(2.A): oathText tras Coast City en Tainted debe ser 'I AM PARALLAX!', fue '%s'", tostring(d2.oathText)))
check(d2.oathTextTimer == 90,
      string.format("T5(2.A): oathTextTimer tras Coast City en Tainted debe ser 90, fue %s", tostring(d2.oathTextTimer)))
-- Sanity: la activacion sigue funcionando (coastCityActive=true, sparks=0).
check(d2.coastCityActive == true, "T5(2.A): coastCityActive se mantiene en true tras activar")
check(d2.emeraldSparks == 0.0, "T5(2.A): emeraldSparks se consume al activar (0.0)")
check(ret == true, "T5(2.A): useCoastCity devuelve true (consume la carga)")

-- Caso B (T5 fix): Hal Jordan (no Tainted) pulsa el item por consola. El bug
-- era que item_coastcity.lua seteaba "I AM PARALLAX!" para todos los usuarios;
-- el juramento poetico "I AM PARALLAX!" es exclusivo de Tainted Hal, NO debe
-- aparecer si el player NO es Core.IsTaintedHal(player).
-- Tras activar Coast City con un Hal (no Tainted), oathText NO debe contener
-- "I AM PARALLAX!" y oathTextTimer NO debe quedar en 90.
resetData()
loadItemCoastCity()
useCb = findUseItemCallback()
local hal_cc = makeHalPlayer(0)
_testPlayer = hal_cc
dataByPlayer[hal_cc.Index] = { emeraldSparks = 50.0, stolenRings = 2, coastCityActive = false, coastCityBoost = 1.0 }
useCb(nil, Core.ITEM_COAST_CITY, nil, hal_cc, 0, 0, 0)
local d_cc = dataByPlayer[hal_cc.Index]
check(d_cc.oathText ~= "I AM PARALLAX!",
      string.format("T5(2.B): Hal (no Tainted) NO debe recibir oath 'I AM PARALLAX!', fue '%s'", tostring(d_cc.oathText)))
check(d_cc.oathTextTimer ~= 90,
      string.format("T5(2.B): Hal (no Tainted) NO debe recibir oathTextTimer=90, fue %s", tostring(d_cc.oathTextTimer)))
-- Sanity: la activacion sigue funcionando (el fix solo afecta el texto, no la mecanica).
check(d_cc.coastCityActive == true, "T5(2.B): coastCityActive se mantiene en true tras activar (Hal no Tainted)")
check(d_cc.emeraldSparks == 0.0, "T5(2.B): emeraldSparks se consume al activar (0.0, Hal no Tainted)")

-- ===================== (3) hud_render.lua: render Tainted del oathText =====================
-- Estructura: tras cargar hud_render, el callback MC_POST_RENDER (lastRender
-- pattern) debe poder pintar oathText/oathTextTimer para Tainted Hal. La forma
-- robusta de verificar es: ejercitar el callback con un Tainted que tenga
-- oathText activo y confirmar que se llama a DrawHudText con su texto y el
-- color verde Tainted (0.0, 0.85, 0.4) o el de lleno (0.25, 1.0, 0.55).
resetData()
loadHudRender()
local postCb = findPostRenderCallback()
check(postCb ~= nil, "T5(3): hud_render.lua registra un callback MC_POST_RENDER")

local th2 = makeTaintedPlayer(0)
_testPlayer = th2
dataByPlayer[th2.Index] = {
    willpower = 0,
    emeraldSparks = 75.0,
    stolenRings = 0,
    ringDepleted = false,
    overcharge = false,
    overchargeTier = 0,
    surgeBuff = false,
    coastCityActive = false,
    coastCityFrame = 0,
    coastCityBoost = 1.0,
    ringFlareTimer = 0,
    batteryConstructTimer = 0,
    oathText = "I AM PARALLAX!",
    oathTextTimer = 90,
    renderLastShootDir = nil,
    wasHoldingShootOnRender = false,
}
_frameCount = 0
postCb()

local drewOath = false
local drewOathColor = nil
for _, c in ipairs(drawTextCalls) do
    if c.text == "I AM PARALLAX!" then
        drewOath = true
        drewOathColor = { c.r, c.g, c.b }
    end
end
check(drewOath,
      "T5(3.A): rama IsTaintedHal pinta el texto oathText 'I AM PARALLAX!'")
check(drewOathColor ~= nil and math.abs(drewOathColor[1] - 0.0)  < 0.01 and math.abs(drewOathColor[2] - 0.85) < 0.01 and math.abs(drewOathColor[3] - 0.4)  < 0.01,
      string.format("T5(3.A): rama Tainted pinta el oath con color verde Tainted (0,0.85,0.4), fue (%.2f,%.2f,%.2f)",
                    drewOathColor and drewOathColor[1] or -1,
                    drewOathColor and drewOathColor[2] or -1,
                    drewOathColor and drewOathColor[3] or -1))

-- (3.B) Decremento: solo en currentGameFrame % 2 == 0 Y con Game frame que
-- avanza (OPT2b: juego congelado no consume timer). Frames 4 (par) -> 89,
-- 5 (impar) -> 89 (NO decrementa), 6 (par) -> 88. Se usan frames frescos
-- porque el modulo recuerda lastRenderGameFrame entre llamadas.
-- Resetear el timer a 90 porque la seccion (3.A) ya lo decremento.
dataByPlayer[th2.Index].oathTextTimer = 90
_frameCount = 4
postCb()
check(dataByPlayer[th2.Index].oathTextTimer == 89,
      string.format("T5(3.B): frame par (%%2==0) decrementa timer 90->89, fue %d", dataByPlayer[th2.Index].oathTextTimer or -1))
_frameCount = 5
postCb()
check(dataByPlayer[th2.Index].oathTextTimer == 89,
      string.format("T5(3.B): frame impar (%%2==1) NO decrementa, fue %d", dataByPlayer[th2.Index].oathTextTimer or -1))
_frameCount = 6
postCb()
check(dataByPlayer[th2.Index].oathTextTimer == 88,
      string.format("T5(3.B): frame par siguiente decrementa 89->88, fue %d", dataByPlayer[th2.Index].oathTextTimer or -1))

-- (3.C) Sin duplicacion: el decremento solo ocurre UNA VEZ por frame/jugador.
-- Tras los 3 frames anteriores (0,1,2) partiendo de 90, el timer debe ser 88,
-- no 87 (un decremento por par) ni menos. Lo verificamos otra vez desde un
-- estado conocido.
dataByPlayer[th2.Index].oathTextTimer = 90
_frameCount = 4  -- par
postCb()
check(dataByPlayer[th2.Index].oathTextTimer == 89,
      string.format("T5(3.C): un solo decremento por frame par, fue %d", dataByPlayer[th2.Index].oathTextTimer or -1))

-- (3.D) Compatibilidad: la rama Hal (IsHalJordan) sigue decrementando con
-- currentGameFrame%2 — verificamos que el Oath Hal pre-existente no se rompe
-- ni se duplica.
dataByPlayer = {}
drawTextCalls = {}
local hal3 = makeHalPlayer(0)
_testPlayer = hal3
dataByPlayer[hal3.Index] = {
    willpower = 100.0,
    emeraldSparks = 0,
    stolenRings = 0,
    ringDepleted = false,
    overcharge = false,
    overchargeTier = 0,
    surgeBuff = false,
    coastCityActive = false,
    coastCityFrame = 0,
    coastCityBoost = 1.0,
    ringFlareTimer = 0,
    batteryConstructTimer = 0,
    oathText = "IN BRIGHTEST DAY...",
    oathTextTimer = 90,
    renderLastShootDir = nil,
    wasHoldingShootOnRender = false,
}
_frameCount = 0
postCb()
_frameCount = 1
postCb()
_frameCount = 2
postCb()
check(dataByPlayer[hal3.Index].oathTextTimer == 88,
      string.format("T5(3.D): rama Hal sigue decrementando 1/2 frames (90->88 en 3 frames), fue %d", dataByPlayer[hal3.Index].oathTextTimer or -1))

-- ===================== (4) Heuristica: no duplicacion de decrementos en fuente =====================
local srcHud = io.open("modules/hud_render.lua", "r")
local hudContent = srcHud and srcHud:read("*a") or ""
srcHud:close()
-- Debe haber exactamente 2 decrementos de data.oathTextTimer (1 rama Hal,
-- 1 rama Tainted). El SPEC exige "mismo patron que Hal" — eso significa
-- que Tainted tiene su propio bloque dentro de su rama IsTaintedHal, asi
-- que por jugador solo se decrementa una vez por frame.
local _, decCount = hudContent:gsub("data%.oathTextTimer%s*=%s*data%.oathTextTimer%s*%-%s*1", "")
check(decCount == 2,
      string.format("T5(4): hud_render.lua debe tener exactamente 2 decrementos de oathTextTimer (rama Hal + rama Tainted), tiene %d", decCount))
-- Y la rama Tainted debe contener una referencia a oathText/oathTextTimer
-- (para que sepamos que la hemos anadido).
local _, refCount = hudContent:gsub("oathTextTimer", "")
check(refCount >= 4,
      string.format("T5(4): hud_render.lua debe mencionar oathTextTimer >=4 veces (2 decrementos + 2 referencias), tiene %d", refCount))
-- Y el decremento de Tainted debe estar DENTRO de la rama IsTaintedHal (no
-- suelto en el bucle de jugadores). Comprobamos que la posicion del decremento
-- de Tainted esta DESPUES del `if Core.IsTaintedHal(player)` en el archivo.
local posIfTainted  = hudContent:find("if Core.IsTaintedHal(player)", 1, true)
local posTaintedDec = hudContent:find("oathTextTimer = data.oathTextTimer - 1", posIfTainted or 1, true)
-- Y debe haber EXACTAMENTE una ocurrencia entre el `if` y el proximo `if Core.IsHalJordan`
-- (que en este archivo no existe despues, asi que usamos fin de archivo).
-- Mas simple: comprobamos que el decremento aparece despues del if tainted.
check(posTaintedDec ~= nil and posIfTainted ~= nil and posTaintedDec > posIfTainted,
      "T5(4): el decremento de Tainted esta dentro de la rama IsTaintedHal (despues del if)")

-- ===================== (5) Heuristica: textos exactos en cada modulo =====================
local srcBat = io.open("modules/item_battery.lua", "r")
local batContent = srcBat and srcBat:read("*a") or ""
srcBat:close()
check(batContent:find("IN BRIGHTEST DAY%.%.%.", 1, false) ~= nil,
      "T5(5): item_battery.lua contiene 'IN BRIGHTEST DAY...'")
-- El seteo va en la rama Hal (Core.IsHalJordan), no suelto.
local batHalRegionStart = batContent:find("IsHalJordan", 1, true)
check(batHalRegionStart ~= nil,
      "T5(5): item_battery.lua contiene una rama IsHalJordan")
local hasOathInHal = false
if batHalRegionStart then
    -- Busca 'IN BRIGHTEST DAY...' en cualquier sitio del archivo (debe estar
    -- en la rama Hal o cerca, junto al seteo de timer).
    hasOathInHal = batContent:find("IN BRIGHTEST DAY%.%.%.", 1, false) ~= nil
end
check(hasOathInHal,
      "T5(5): 'IN BRIGHTEST DAY...' esta en item_battery.lua")

local srcCc = io.open("modules/item_coastcity.lua", "r")
local ccContent = srcCc and srcCc:read("*a") or ""
srcCc:close()
check(ccContent:find("I AM PARALLAX!", 1, true) ~= nil,
      "T5(5): item_coastcity.lua contiene 'I AM PARALLAX!'")
check(ccContent:find("oathTextTimer", 1, true) ~= nil,
      "T5(5): item_coastcity.lua setea oathTextTimer")

-- ===================== (6) Heuristica: ningun modulo fuera de los 3 tocados =====================
-- El SPEC dice "Solo esos 3 ficheros". Verificamos que el resto de modulos
-- no referencian los nuevos textos poeticos.
local poeticTexts = { "IN BRIGHTEST DAY%.%.%.", "I AM PARALLAX!" }
local touchedPoetic = {}
for _, fname in ipairs(poeticTexts) do
    local pattern = fname
    local f = io.popen("grep -l \"" .. pattern:gsub("%%", "%%") .. "\" modules/*.lua 2>nul")
    if f then
        local found = f:read("*a") or ""
        f:close()
        for line in found:gmatch("[^\n]+") do
            touchedPoetic[line] = true
        end
    end
end
-- touchedPoetic contiene paths como "modules/item_battery.lua". Solo esperamos
-- los 3 del SPEC.
local allowedFiles = {
    ["modules/item_battery.lua"]   = true,
    ["modules/item_coastcity.lua"] = true,
    ["modules/hud_render.lua"]     = true,
}
for path, _ in pairs(touchedPoetic) do
    check(allowedFiles[path] == true,
          string.format("T5(6): el texto poetico solo debe vivir en los 3 ficheros del SPEC, pero aparece en %s", path))
end

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_t5_oath_text] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
