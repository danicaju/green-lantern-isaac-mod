-- tools/test_t1_balance_constants.lua
-- T1 — guard de regresion sobre el balance del anillo y constantes del escudo.
-- Compatible con Lua 5.1.
--
-- Carga modules/core.lua (la fuente de verdad para balance) y verifica que:
--   1. DISCRETE_BEAM_DMG_MULT == 0.60  (cambio T1: 0.45 -> 0.60)
--   2. HAL_CONTINUOUS_BEAM_DMG_MULT == 0.35  (NO cambia, contrato explicito)
--   3. SHIELD_REFLECT_BASE == 0.25  (nueva constante)
--   4. SHIELD_REFLECT_PER_LUCK == 0.05
--   5. SHIELD_REFLECT_MAX == 0.75
--
-- No comprueba shield.lua (esa superficie sino que usa los literales hardcoded
-- sigue fuera de scope T1; lo dejamos apuntado en el handoff).

-- Stub minimo: core.lua usa RegisterMod(...) y unos cuantos nil IDs arriba.
-- Solo necesitamos que la llamada exista.
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

-- (1) DISCRETE 0.45 -> 0.60
check(Core.DISCRETE_BEAM_DMG_MULT == 0.60,
      string.format("DISCRETE_BEAM_DMG_MULT debe ser 0.60, fue %.4f",
                    Core.DISCRETE_BEAM_DMG_MULT or -1))

-- (2) Continuo NO se toca (contrato T1 explicito)
check(Core.HAL_CONTINUOUS_BEAM_DMG_MULT == 0.35,
      string.format("HAL_CONTINUOUS_BEAM_DMG_MULT debe seguir en 0.35, fue %.4f",
                    Core.HAL_CONTINUOUS_BEAM_DMG_MULT or -1))

-- (3-5) Constantes nuevas del escudo, alineadas con shield.lua
check(Core.SHIELD_REFLECT_BASE == 0.25,
      string.format("SHIELD_REFLECT_BASE debe ser 0.25, fue %.4f",
                    Core.SHIELD_REFLECT_BASE or -1))

check(Core.SHIELD_REFLECT_PER_LUCK == 0.05,
      string.format("SHIELD_REFLECT_PER_LUCK debe ser 0.05, fue %.4f",
                    Core.SHIELD_REFLECT_PER_LUCK or -1))

check(Core.SHIELD_REFLECT_MAX == 0.75,
      string.format("SHIELD_REFLECT_MAX debe ser 0.75, fue %.4f",
                    Core.SHIELD_REFLECT_MAX or -1))

-- Invariante: con Luck = 0, la formula base + luck*per_luck no debe superar MAX.
local luck0 = (Core.SHIELD_REFLECT_BASE or 0) + 0 * (Core.SHIELD_REFLECT_PER_LUCK or 0)
check(luck0 == 0.25, string.format("Luck=0 debe dar 0.25, dio %.4f", luck0))

-- Invariante: cap a SHIELD_REFLECT_MAX = 0.75 ocurre en Luck >= 10
-- (0.25 + 10*0.05 = 0.75). Verificamos que la formula clasica llega al cap.
local luck10 = math.min(
    (Core.SHIELD_REFLECT_BASE or 0) + 10 * (Core.SHIELD_REFLECT_PER_LUCK or 0),
    Core.SHIELD_REFLECT_MAX or 0.75
)
check(luck10 == 0.75, string.format("Luck=10 (cap) debe dar 0.75, dio %.4f", luck10))

-- Balance paridad: ratio hold/click >= 1.15 para MFD en {6,10,14,20}
-- (esto es lo que dice el CHANGELOG S3; con DISCRETE 0.45->0.60 seguimos manteniendo
-- paridad porque el intervalo de click escala con MFD). Sanity check aritmetico:
--   click_dps = DISCRETE / MFD
--   hold_dps  = CONT_BEAM * (30/tickFrames) * hold_factor
--   tickFrames = 4 -> 7.5 ticks/s
--   hold_factor = HOLD_FRAMES / 60 (sostenido puro)
local function ratioFor(MFD_)
        local click_dps = 1.0 * Core.DISCRETE_BEAM_DMG_MULT / MFD_
        local hold_dps  = 1.0 * Core.HAL_CONTINUOUS_BEAM_DMG_MULT * (30 / Core.HAL_CONTINUOUS_TICK_FRAMES)
        return hold_dps / click_dps
end
for _, mfd in ipairs({6, 10, 14, 20}) do
    local ratio = ratioFor(mfd)
    check(ratio >= 1.15,
          string.format("MFD=%d: ratio hold/click debe ser >=1.15, fue %.3f", mfd, ratio))
end

io.stderr:write(string.format("\n[test_t1_balance_constants] passes=%d failures=%d\n",
                          passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end