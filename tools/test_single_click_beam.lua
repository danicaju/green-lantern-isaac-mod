-- tools/test_single_click_beam.lua
-- Regresion: un solo clic izquierdo debe generar UNA sola lagrima pequena.
-- Antes se encolaba el clic por varias vias (press de render, release de render
-- y release de gameplay) y el jugador veia dos beams por clic.

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

local src = readFile("modules/firing_mode.lua")
check(src ~= nil, "firing_mode.lua existe")

-- 1) Existe el helper de dedupe.
check(src and src:find("local function QueueDiscreteClick", 1, true) ~= nil,
      "existe QueueDiscreteClick")
check(src and src:find("if data.clickQueuedThisPress then return end", 1, true) ~= nil,
      "el helper ignora encolados repetidos de la misma pulsacion")

-- 2) Solo el helper escribe bufferedClickDir con un Vector (una unica via).
local _, vectorWrites = (src or ""):gsub("data%.bufferedClickDir%s*=%s*Vector%(", "")
check(vectorWrites == 1,
      "una sola via encola el clic (encontradas " .. tostring(vectorWrites) .. ")")

-- 3) Las 3 vias usan el helper.
local _, helperCalls = (src or ""):gsub("QueueDiscreteClick%(", "")
-- 1 definicion + 3 llamadas = 4
check(helperCalls == 4, "las 3 vias usan QueueDiscreteClick (calls=" .. tostring(helperCalls) .. ")")

-- 4) La pulsacion se marca como consumida tras disparar el burst.
check(src and src:find("data.firingBufferedClick = false%s*\n%s*%-%- Marca la pulsacion", 1) ~= nil,
      "el burst marca la pulsacion como consumida")
local consumedIdx = src and src:find("data.firedSmallBeamThisPress = true", 1, true)
local bufferedNilIdx = src and src:find("data.tapBurstCount, data.tapBurstIndex, data.tapBurstBaseDir = nil", 1, true)
check(consumedIdx ~= nil and bufferedNilIdx ~= nil and consumedIdx < bufferedNilIdx,
      "firedSmallBeamThisPress se activa al consumir el clic buffereado")

-- 5) El flag se libera al consumir o expirar para no bloquear el siguiente clic.
local _, releases = (src or ""):gsub("data%.clickQueuedThisPress%s*=%s*false", "")
check(releases >= 2, "el flag se libera al consumir y al expirar (releases=" .. tostring(releases) .. ")")

-- 6) La lagrima nativa del motor (C++) se suprime SIEMPRE para Hal/Tainted,
--    sin depender del willpower restante. Si sobrevive, el motor la dibuja
--    ademas del beam manual y el jugador ve DOS lagrimas por clic.
local beam = readFile("modules/beam_discrete.lua")
check(beam ~= nil and beam:find("not data.allowingTapTear", 1, true) ~= nil,
      "beam suprime toda lagrima nativa no permitida")
check(beam ~= nil and beam:find("CanUseContinuousBeam(player) and not data.allowingTapTear", 1, true) == nil,
      "la supresion ya no depende de CanUseContinuousBeam")

-- 7) La rama de tap con el anillo agotado debe marcar allowingTapTear o la
--    supresion anterior borraria su propia lagrima.
local tapStart = src and src:find("data.ringDepleted and data.humanTapShootDir", 1, true)
local tapEnd = src and src:find("if data.bufferedClickDir", 1, true)
local tapBlock = (tapStart and tapEnd and tapEnd > tapStart) and src:sub(tapStart, tapEnd) or ""
check(tapBlock:find("data.allowingTapTear = true", 1, true) ~= nil,
      "el tap con anillo agotado se marca como permitido")

print(string.format("\ntest_single_click_beam.lua: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
