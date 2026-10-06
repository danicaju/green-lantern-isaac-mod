-- tools/test_balance_dps.lua
-- SPEC-C — balance cadencia/dano Hal + Tainted: tabla DPS click vs hold por personaje.
-- Compatible con Lua 5.1. Ejecutar desde la raiz del repo:
--   lua tools/test_balance_dps.lua
--
-- Numeros aprobados que verifica:
--   1. Hal: MaxFireDelay +2  (Core.HAL_FIREDELAY_BONUS == 2)
--   2. Hal: base willMult 1.00 -> 1.10 (Core.HAL_WILL_BASE_MULT == 1.10)
--   3. Tainted: TAINTED_DMG_MULTIPLIER 1.5 -> 1.35 (-10% dano)
--   4. Tainted: TAINTED_TEARS_PENALTY -1.5 -> -2.0 (cadencia mas lenta)
--   5. Desigualdad recalculada en el MFD efectivo de Hal (10 base + 2 = 12):
--      hold >= click x 1.15 con la formula real de modules/firing_mode.lua:174
--      (mci = max(6, min(10, floor(MFD * 0.70)))). MFD=12 -> mci=8 ->
--      click=2.25, hold=2.625, ratio=1.1667 >= 1.15 OK. Sin el +2
--      (MFD=10 -> mci=7 -> ratio~1.02) el hold NO dominaba: por eso el +2
--      era necesario. La formula de intervalo NO cambia.
-- No toca Willpower/drenajes/overcharge, ni DISCRETE_BEAM_DMG_MULT,
-- ni beam_synergies, ni HUD.
--
-- E2 (pulido, sin cambios de numeros): rama CACHE_FIREDELAY de Hal bajo
-- if not data.ringDepleted (depletado = lagrimas normales, sin +2) y
-- fallbacks or en Tainted (1.35 / -2.0) y Hal (1.10 / 2). La seccion
-- (11)-(12) lo verifica comportamentalmente con dobles (GL/Game/CacheFlag/
-- player falsos, IDs inyectados) cargando modules/stats.lua via loadstring
-- con | -> + (el lua5.1 del harness no tiene bitwise; el juego si).

-- Stub minimo: core.lua usa RegisterMod(...) arriba del todo.
function RegisterMod(_name, _ver) return {} end

local Core = dofile("modules/core.lua")
assert(type(Core) == "table", "core.lua debe devolver una tabla")

local failures, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

local function approx(a, b, tol)
    return math.abs(a - b) <= (tol or 0.001)
end

-- (1-2) Nuevas constantes de Hal en Core (fuente de verdad SECTION 1).
check(Core.HAL_FIREDELAY_BONUS == 2,
      string.format("HAL_FIREDELAY_BONUS debe ser 2, fue %s",
                    tostring(Core.HAL_FIREDELAY_BONUS)))
check(Core.HAL_WILL_BASE_MULT == 1.10,
      string.format("HAL_WILL_BASE_MULT debe ser 1.10, fue %s",
                    tostring(Core.HAL_WILL_BASE_MULT)))

-- (3-4) Tainted: 1.5 -> 1.35 y -1.5 -> -2.0.
check(Core.TAINTED_DMG_MULTIPLIER == 1.35,
      string.format("TAINTED_DMG_MULTIPLIER debe ser 1.35, fue %.4f",
                    Core.TAINTED_DMG_MULTIPLIER or -1))
check(Core.TAINTED_TEARS_PENALTY == -2.0,
      string.format("TAINTED_TEARS_PENALTY debe ser -2.0, fue %.4f",
                    Core.TAINTED_TEARS_PENALTY or -99))

-- (5) Cableado en modules/stats.lua: Hal usa la base 1.10 y suma +2 a MaxFireDelay.
local fh = io.open("modules/stats.lua", "r")
local statsSrc = fh and fh:read("*a") or ""
if fh then fh:close() end
check(statsSrc:find("HAL_WILL_BASE_MULT", 1, true) ~= nil,
      "stats.lua debe usar Core.HAL_WILL_BASE_MULT (base willMult 1.10)")
check(statsSrc:find("HAL_FIREDELAY_BONUS", 1, true) ~= nil,
      "stats.lua debe usar Core.HAL_FIREDELAY_BONUS (Hal MaxFireDelay +2)")
check(statsSrc:find("CACHE_FIREDELAY", 1, true) ~= nil,
      "stats.lua debe tener rama CACHE_FIREDELAY para Hal")

-- (6) Tabla DPS con la formula real de firing_mode.lua:174.
local function mciFor(MFD_)
    return math.max(6, math.min(10, math.floor(MFD_ * 0.70)))
end
local function dpsFor(MFD_)
    local mci = mciFor(MFD_)
    local click = Core.DISCRETE_BEAM_DMG_MULT * (30 / mci)
    local hold = Core.HAL_CONTINUOUS_BEAM_DMG_MULT * (30 / Core.HAL_CONTINUOUS_TICK_FRAMES)
    return click, hold, hold / click, mci
end

io.stderr:write("\n-- Tabla DPS (unidades de beam x Dano; ratio = hold/click) --\n")
local rows = {
    { name = "Hal MFD=10 (base, sin +2)",        mfd = 10 },
    { name = "Hal MFD=12 (10+2, efectivo)",      mfd = 10 + (Core.HAL_FIREDELAY_BONUS or 0) },
    { name = "Hal MFD=14 (lagrimas bajas)",      mfd = 14 },
    { name = "Tainted MFD=16 (10+2.0x3)",        mfd = 10 + math.abs(Core.TAINTED_TEARS_PENALTY or 0) * 3 },
}
for _, r in ipairs(rows) do
    local click, hold, ratio, mci = dpsFor(r.mfd)
    io.stderr:write(string.format("  %-32s MFD=%4.1f mci=%d click=%6.4f hold=%6.4f ratio=%6.4f\n",
                                  r.name, r.mfd, mci, click, hold, ratio))
end

-- (7) Desigualdad recalculada: Hal efectivo (MFD=12) hold >= click x 1.15.
do
    local halMFD = 10 + (Core.HAL_FIREDELAY_BONUS or 0)
    local click, hold, ratio = dpsFor(halMFD)
    check(halMFD == 12,
          string.format("MFD efectivo de Hal debe ser 12, fue %.1f", halMFD))
    check(approx(ratio, 1.1667),
          string.format("Hal MFD=12: ratio debe ser ~1.1667, fue %.4f", ratio))
    check(hold >= click * 1.15,
          string.format("Hal MFD=12: hold (%.4f) debe ser >= click x 1.15 (%.4f)",
                        hold, click * 1.15))
end

-- (8) Justificacion del +2: sin el (MFD=10) el hold NO domina x1.15.
do
    local click, hold, ratio = dpsFor(10)
    check(approx(ratio, 1.0204),
          string.format("MFD=10: ratio debe ser ~1.0204, fue %.4f", ratio))
    check(hold < click * 1.15,
          "MFD=10 (sin +2): el hold no llega a click x 1.15, luego el +2 era necesario")
end

-- (9) Tainted: el hold sigue viable y el dano baja un 10% exacto.
do
    local tmfd = 10 + math.abs(Core.TAINTED_TEARS_PENALTY or 0) * 3
    check(tmfd == 16,
          string.format("MFD efectivo Tainted debe ser 16, fue %.1f", tmfd))
    local click, hold, ratio = dpsFor(tmfd)
    check(approx(ratio, 1.4583),
          string.format("Tainted MFD=16: ratio debe ser ~1.4583, fue %.4f", ratio))
    check(hold > click, "Tainted: el hold debe seguir por encima del click")
    check(approx((Core.TAINTED_DMG_MULTIPLIER or 0) / 1.5, 0.90),
          "Tainted: 1.35/1.5 debe ser 0.90 (-10% de dano)")
end

-- (10) Hal: +10% de base en toda la curva (0% y 100% Willpower).
do
    local base = Core.HAL_WILL_BASE_MULT or -1
    check(approx(base + 0.15 * 0.0, 1.10), "Hal willMult a 0% debe ser 1.10")
    check(approx(base + 0.15 * 1.0 + 0.10, 1.35), "Hal willMult a 100% debe ser 1.35")
end

-- (11) E2: guard ringDepleted en el firedelay de Hal (comportamental).
-- Carga la factoria real de modules/stats.lua con dobles minimos.
do
    ModCallbacks = { MC_EVALUATE_CACHE = 1 }
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_FIREDELAY = 2, CACHE_SPEED = 3,
                  CACHE_SHOTSPEED = 4, CACHE_FLYING = 5, CACHE_TEARFLAG = 6 }
    TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 2 }
    Vector = function(x, y) return { X = x, Y = y } end
    Game = function()
        return { GetLevel = function()
            return { GetCurrentRoomIndex = function() return 7 end }
        end }
    end

    -- IDs inyectados (no dependen de ids.lua ni del engine).
    Core.PLAYER_HAL = 100
    Core.PLAYER_TAINTED_HAL = 101
    function Core.IsHalJordan(p) return p and p:GetPlayerType() == 100 end
    function Core.IsTaintedHal(p) return p and p:GetPlayerType() == 101 end

    local savedCB = nil
    Core.GL = { AddCallback = function(_, _, cb) savedCB = cb end }

    -- lua5.1 del harness no soporta BARRA (bitwise del juego): MAS equivale
    -- aqui porque los flags son potencias de dos y parten de 0.
    local src51 = statsSrc:gsub("|", "+")
    local factory = assert(loadstring(src51, "stats.lua"))()
    factory(Core)
    check(savedCB ~= nil, "E2: stats.lua debe registrar MC_EVALUATE_CACHE")

    local function fakePlayer(ptype, mfd, dmg)
        local store = {}
        return {
            MaxFireDelay = mfd or 10, Damage = dmg or 3.5,
            MoveSpeed = 1, ShotSpeed = 1, CanFly = false, TearFlags = 0,
            GetPlayerType = function() return ptype end,
            GetData = function() return store end,
            HasTrinket = function() return false end,
            HasCollectible = function() return false end,
        }
    end

    if savedCB then
        -- 11a: Hal con anillo activo suma +2.
        local hal = fakePlayer(100, 10)
        Core.GetPlayerData(hal).ringDepleted = false
        savedCB(nil, hal, CacheFlag.CACHE_FIREDELAY)
        check(hal.MaxFireDelay == 10 + (Core.HAL_FIREDELAY_BONUS or 0),
              string.format("E2: Hal activo debe quedar en MFD=12, fue %.1f", hal.MaxFireDelay))
        -- 11b: Hal depletado NO suma (guard ringDepleted). Mata el mutante
        -- "guard eliminado": sin el, este check daria 12 y fallaria.
        local dep = fakePlayer(100, 10)
        Core.GetPlayerData(dep).ringDepleted = true
        savedCB(nil, dep, CacheFlag.CACHE_FIREDELAY)
        check(dep.MaxFireDelay == 10,
              string.format("E2: Hal depletado debe seguir en MFD=10, fue %.1f", dep.MaxFireDelay))
    end

    -- 11c: el guard vive textualmente en el bloque firedelay de Hal
    -- (primera rama CACHE_FIREDELAY del fichero).
    do
        local fdPos = statsSrc:find("if cacheFlag == CacheFlag.CACHE_FIREDELAY then", 1, true)
        local fdBlock = fdPos and statsSrc:sub(fdPos, fdPos + 600) or ""
        check(fdBlock:find("ringDepleted", 1, true) ~= nil
              and fdBlock:find("HAL_FIREDELAY_BONUS", 1, true) ~= nil,
              "E2: bloque firedelay de Hal debe contener guard ringDepleted + HAL_FIREDELAY_BONUS")
    end

    -- (12) E2: fallbacks OR cuando la constante falta (nil).
    local keepDmg, keepTears = Core.TAINTED_DMG_MULTIPLIER, Core.TAINTED_TEARS_PENALTY
    local keepBase, keepBonus = Core.HAL_WILL_BASE_MULT, Core.HAL_FIREDELAY_BONUS
    if savedCB then
        -- 12a: Tainted sin TAINTED_TEARS_PENALTY usa -2.0 -> MFD=16.
        Core.TAINTED_TEARS_PENALTY = nil
        local t = fakePlayer(101, 10)
        savedCB(nil, t, CacheFlag.CACHE_FIREDELAY)
        check(t.MaxFireDelay == 16,
              string.format("E2: Tainted sin const debe caer a MFD=16 (or -2.0), fue %.1f", t.MaxFireDelay))
        -- 12b: Tainted sin TAINTED_DMG_MULTIPLIER usa 1.35.
        Core.TAINTED_DMG_MULTIPLIER = nil
        local t2 = fakePlayer(101, 10, 3.5)
        savedCB(nil, t2, CacheFlag.CACHE_DAMAGE)
        check(approx(t2.Damage, 3.5 * 1.35),
              string.format("E2: Tainted sin const debe pegar 3.5x1.35=%.4f, fue %.4f", 3.5 * 1.35, t2.Damage))
        -- 12c: Hal sin HAL_WILL_BASE_MULT usa 1.10 (will 100 -> 1.35x pico).
        Core.HAL_WILL_BASE_MULT = nil
        local h = fakePlayer(100, 10, 3.5)
        local hd = Core.GetPlayerData(h)
        hd.ringDepleted = false
        hd.willpower = 100.0
        savedCB(nil, h, CacheFlag.CACHE_DAMAGE)
        check(approx(h.Damage, 3.5 * 1.35),
              string.format("E2: Hal sin const base debe pegar 3.5x1.35=%.4f, fue %.4f", 3.5 * 1.35, h.Damage))
    end
    Core.TAINTED_DMG_MULTIPLIER, Core.TAINTED_TEARS_PENALTY = keepDmg, keepTears
    Core.HAL_WILL_BASE_MULT, Core.HAL_FIREDELAY_BONUS = keepBase, keepBonus
    check(Core.TAINTED_DMG_MULTIPLIER == 1.35 and Core.TAINTED_TEARS_PENALTY == -2.0
          and Core.HAL_WILL_BASE_MULT == 1.10 and Core.HAL_FIREDELAY_BONUS == 2,
          "E2: constantes restauradas tras probar fallbacks")
end
io.stderr:write(string.format("\n[test_balance_dps] passes=%d failures=%d\n",
                              passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
