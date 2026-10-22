-- tools/test_incubus_fetus_fix.lua
-- Verifica los dos reportes del usuario:
--   1) Incubus no disparaba lagrimas: la rama de familiares ya NO lo convierte
--      en el haz oculto; solo tinta su lagrima vanilla.
--   2) Epic Fetus demasiado fuerte con el canal continuo: intervalos subidos
--      (90 / 60 frames) y dano reducido en el canal (x2.0).

local passed, failed = 0, 0
local function check(cond, name)
    if cond then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name)
    end
end

local function readFile(rel)
    local f = io.open(rel, "rb")
    if not f then return nil end
    local src = f:read("*a")
    f:close()
    return src
end

local root = "."
local beam = readFile(root .. "/modules/beam_discrete.lua")
local aim = readFile(root .. "/modules/ring_aim.lua")
local fetus = readFile(root .. "/modules/synergies_fetus.lua")

check(beam ~= nil, "beam_discrete.lua existe")
check(aim ~= nil, "ring_aim.lua existe")
check(fetus ~= nil, "synergies_fetus.lua existe")

-- ---- 1) Incubus ----
check(beam and beam:find("Core.ApplyFamiliarTearTint", 1, true) ~= nil,
      "Incubus: beam_discrete usa ApplyFamiliarTearTint en la rama de familiares")
check(aim and aim:find("function Core.ApplyFamiliarTearTint", 1, true) ~= nil,
      "Incubus: Core.ApplyFamiliarTearTint definido en ring_aim.lua")
check(aim and aim:find("td.glFamiliarTint = true", 1, true) ~= nil,
      "Incubus: la lagrima tintada no se marca como isGLRingBeam")
check(aim and aim:find("td.isGLRingBeam = true", 1, true) ~= nil,
      "Incubus: el haz oculto sigue existiendo para el jugador (no se rompe el beam)")

-- La rama familiar no debe ocultar la lagrima con HideTearSprite.
local famBranch = beam and beam:match("if not player then(.-)\n      end")
check(famBranch ~= nil, "Incubus: rama de familiares localizable")
check(famBranch and famBranch:find("HideTearSprite", 1, true) == nil,
      "Incubus: la rama de familiares NO oculta la lagrima")
check(famBranch and famBranch:find("ApplyRingBeamSprite", 1, true) == nil,
      "Incubus: la rama de familiares NO aplica el haz oculto")

-- ---- 2) Epic / Dr. Fetus ----
check(fetus and fetus:find("frame % 90 == 0", 1, true) ~= nil,
      "Fetus: canal Epic cada 90 frames")
check(fetus and fetus:find("frame % 45 == 0", 1, true) == nil,
      "Fetus: ya no hay cohete cada 45 frames")
check(fetus and fetus:find("frame % 60 == 0", 1, true) ~= nil,
      "Fetus: canal Dr. Fetus cada 60 frames")
check(fetus and fetus:find("frame % 30 == 0", 1, true) == nil,
      "Fetus: ya no hay bomba cada 30 frames")
check(fetus and fetus:find("(dmgMult or 5.0)", 1, true) ~= nil,
      "Fetus: el disparo normal conserva x5.0 por defecto")
check(fetus and fetus:find("SpawnEpicFetusRocket(player, strikePos, data, 2.0)", 1, true) ~= nil,
      "Fetus: el cohete del canal continuo usa x2.0")
check(fetus and fetus:find("(player.Damage or 3.5) * 2.0", 1, true) ~= nil,
      "Fetus: la bomba del canal continuo usa x2.0")
check(fetus and fetus:find("(player.Damage or 3.5) * 4.0", 1, true) == nil,
      "Fetus: sin bombas x4.0 en el canal continuo")

print(string.format("\ntest_incubus_fetus_fix.lua: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
