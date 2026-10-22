-- tools/test_audit_lote1.lua
-- Auditoria lote 1 (F1-F7), verificada de forma estatica sobre el source + un
-- stub del callback MC_POST_FIRE_TEAR de beam_discrete.lua:
--   F1. Whitelist de familiares para el estilo haz esmeralda (familiar overreach).
--   F2. Fallback de normalizacion con (dir.X or 0).
--   F3. Dr. Fetus / Epic Fetus en continuousBeamOverrideItems (APARCADO: revisa).
--   F4. pcall en las 3 llamadas criticas al limite de entidades.
--   F5. overchargeTier = 0 en los defaults de GetPlayerData.
--   F6. Purga de indices de jugadores desconectados antes de serializar.
--   F7. Cero accesos CollectibleType.COLLECTIBLE_ sin guard en los 3 tiers.
-- Sin red, sin escritura en FS: solo io.open en lectura + dofile del modulo.

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*a")
    f:close()
    return c
end

local function count(hay, needle)
    local n, from = 0, 1
    while true do
        local s = hay:find(needle, from, true)
        if not s then break end
        n = n + 1
        from = s + #needle
    end
    return n
end

-- true si el literal `needle` aparece en una linea contenida dentro de un
-- bloque pcall(function() ... end) (miramos su linea y las 2 anteriores).
local function wrappedInPcall(content, needle)
    local s = content:find(needle, 1, true)
    if not s then return false end
    local lineStart = content:sub(1, s):match("^.*\n()") or 1
    local regionStart = lineStart
    for _ = 1, 2 do
        local prev = content:sub(1, regionStart - 2):match("^.*\n()")
        if not prev then break end
        regionStart = prev
    end
    return content:sub(regionStart, s):find("pcall(", 1, true) ~= nil
end

-- ===================== TEST 1: F1 WHITELIST DE FAMILIARES =====================
local bd = readFile("modules/beam_discrete.lua")
check(bd ~= nil, "modules/beam_discrete.lua exists")
check(bd and bd:find("ALLOWED_FAMILIAR_BEAMERS", 1, true) ~= nil,
      "F1: whitelist ALLOWED_FAMILIAR_BEAMERS presente en beam_discrete.lua")
check(bd and bd:find("INCUBUS", 1, true) ~= nil and bd:find("SUCCUBUS", 1, true) ~= nil,
      "F1: la whitelist referencia Incubus y Succubus")

-- Stub del juego + carga real del modulo (comportamiento, no solo texto).
local callbacks = {}
ModCallbacks = {
    MC_POST_FIRE_TEAR = 1,
    MC_POST_TEAR_UPDATE = 2,
    MC_POST_TEAR_RENDER = 3,
    MC_PRE_TEAR_COLLISION = 4,
    MC_USE_ITEM = 5,
    MC_ENTITY_TAKE_DMG = 6,
}
Color = function() return {} end
FamiliarVariant = { INCUBUS = 80, SUCCUBUS = 96 }

local beamCalls = 0
local Core = {
    GL = { AddCallback = function(self, id, fn) callbacks[id] = fn end },
    IsRingActive = function() return true end,
    ApplyRingBeamSprite = function() beamCalls = beamCalls + 1 end,
    GetPlayerData = function() return {} end,
    ResolveBeamPlayer = function(spawner)
        if not spawner then return nil end
        local ok, player = pcall(function() return spawner:ToPlayer() end)
        if ok and player then return player end
        local fam = nil
        pcall(function() fam = spawner:ToFamiliar() end)
        if fam and fam.Player then return fam.Player end
        return nil
    end,
}

-- Carga como en el resto de harness: shim de los operadores bitwise Lua 5.3
-- (|) a + para poder compilar con Lua 5.1, igual que hacen los tests existentes.
local function loadModule(path)
    local src = readFile(path)
    if not src then return nil, "missing " .. path end
    local patched = src:gsub("|", "+")
    local chunk, err = loadstring(patched, path)
    if not chunk then return nil, err end
    return chunk()
end

local modFn, loadErr = loadModule("modules/beam_discrete.lua")
check(type(modFn) == "function",
      "F1: beam_discrete.lua carga como modulo" ..
      (type(modFn) == "function" and "" or (" (" .. tostring(loadErr) .. ")")))
if type(modFn) == "function" then
    local okInit = pcall(modFn, Core)
    check(okInit, "F1: beam_discrete.lua se inicializa con stubs")
    local fire = callbacks[ModCallbacks.MC_POST_FIRE_TEAR]
    check(type(fire) == "function", "F1: callback MC_POST_FIRE_TEAR registrado")

    local function makeTear(variant, owner)
        local fam = { Variant = variant, Player = owner }
        local spawner = {
            ToPlayer = function() return nil end,
            ToFamiliar = function() return fam end,
        }
        return {
            SpawnerEntity = spawner,
            Scale = 1.0,
            Visible = true,
            GetData = function() return {} end,
        }
    end

    local owner = { IsGLPlayer = true }

    -- Familiar NO permitido: la lagrima vanilla queda intacta.
    beamCalls = 0
    local tearBad = makeTear(1234, owner)
    fire(nil, tearBad)
    check(beamCalls == 0, "F1: familiar fuera de la whitelist NO recibe ApplyRingBeamSprite")
    check(tearBad.Visible == true, "F1: la lagrima del familiar no permitido queda intacta")

    -- Familiar permitido (Incubus): ahora recibe TINTE esmeralda sobre su
    -- lagrima VANILLA. Antes se convertia en el haz oculto (Visible=false +
    -- sprite custom) y eso dejaba a Incubus sin lagrimas visibles.
    beamCalls = 0
    local tintCalls = 0
    Core.ApplyFamiliarTearTint = function() tintCalls = tintCalls + 1 end
    local tearOk = makeTear(FamiliarVariant.INCUBUS, owner)
    fire(nil, tearOk)
    check(beamCalls == 0, "F1: Incubus NO se convierte en haz oculto (conserva fisica vanilla)")
    check(tintCalls == 1, "F1: Incubus recibe ApplyFamiliarTearTint")
    check(tearOk.Visible ~= false, "F1: la lagrima de Incubus no se oculta")
end

-- ===================== TEST 2: F2 FALLBACK DE NORMALIZACION =====================
local bm = readFile("modules/beam_math.lua")
check(bm ~= nil, "modules/beam_math.lua exists")
check(bm and bm:find("Vector((dir.X or 0) / dLen, (dir.Y or 0) / dLen)", 1, true) ~= nil,
      "F2: fallback de normalizacion con (dir.X or 0) y (dir.Y or 0)")
check(bm and bm:find("(dir.X or 1) / dLen", 1, true) == nil,
      "F2: sin el fallback antiguo (dir.X or 1)")

-- ========== TEST 3: F3 DR. FETUS / EPIC FETUS (APARCADO - CONFLICTO) ==========
-- F3 pedia anadir Dr. Fetus / Epic Fetus a continuousBeamOverrideItems. NO se
-- aplica porque revierte una decision de usuario commiteada y testeada:
--   * tools/test_user_fixes_synergies.lua (user fix #6):
--     "Epic Fetus synergy allowed in CanUseContinuousBeam"
--   * tools/test_synergies_tech_parasite.lua:
--     "Epic Fetus retains continuous beam orbital strike ability"
--   * modules/synergies_fetus.lua: Core.TickFetusContinuousSynergy quedaria
--     inalcanzable (firing_mode.lua:138 solo corre con haz continuo).
-- IDs vanilla verificados en la wiki: Dr. Fetus = 52 (5.100.52), Epic Fetus = 168
-- (la SPEC ponia `or 248` para Dr. Fetus, ID incorrecto).
-- Guardia: si F3 se aplica, falla aqui Y en los 2 tests de arriba; hay que
-- actualizarlos con aprobacion del usuario en ese caso.
local overrideBlock = bm and bm:match("continuousBeamOverrideItems = {(.-)}")
check(overrideBlock ~= nil, "F3: lista continuousBeamOverrideItems localizable")
check(overrideBlock and overrideBlock:find("COLLECTIBLE_DR_FETUS", 1, true) == nil,
      "F3[APARCADO]: Dr. Fetus sigue fuera de la lista (protege el fix de usuario)")
check(overrideBlock and overrideBlock:find("COLLECTIBLE_EPIC_FETUS", 1, true) == nil,
      "F3[APARCADO]: Epic Fetus sigue fuera de la lista (protege el fix de usuario)")

-- ===================== TEST 4: F4 PCALL AL LIMITE DE ENTIDADES =====================
local t2 = readFile("modules/synergies_tier2.lua")
check(t2 ~= nil, "modules/synergies_tier2.lua exists")
check(t2 and wrappedInPcall(t2, "Core.SpawnGLConstructTear(player, spawnPos"),
      "F4: Core.SpawnGLConstructTear del beam continuo envuelto en pcall")

local tv = readFile("modules/synergies_virtues.lua")
check(tv ~= nil, "modules/synergies_virtues.lua exists")
check(tv and wrappedInPcall(tv, "ent:TakeDamage(dmg,"),
      "F4: ent:TakeDamage del wisp Giant Fist envuelto en pcall")
check(tv and wrappedInPcall(tv, "Isaac.Spawn(EntityType.ENTITY_TEAR, tearVar"),
      "F4: Isaac.Spawn del wisp Gatling envuelto en pcall")

-- ===================== TEST 5: F5 DEFAULT overchargeTier =====================
local core = readFile("modules/core.lua")
check(core ~= nil, "modules/core.lua exists")
check(core and core:find("overchargeTier = 0,", 1, true) ~= nil,
      "F5: overchargeTier = 0 en los defaults de GetPlayerData")

-- ===================== TEST 6: F6 PURGA DE JUGADORES DESCONECTADOS =====================
local sr = readFile("modules/save_run.lua")
check(sr ~= nil, "modules/save_run.lua exists")
check(sr and sr:find("for k in pairs(snapshot) do", 1, true) ~= nil,
      "F6: purga de claves del snapshot presente")
check(sr and sr:find("snapshot[k] = nil", 1, true) ~= nil,
      "F6: la purga elimina claves no conectadas")
check(sr and sr:find("Game():GetNumPlayers()", 1, true) ~= nil,
      "F6: la purga usa el numero de jugadores conectados")
local purgePos = sr and sr:find("pairs(snapshot)", 1, true)
local encPos = sr and sr:find("json.encode(slot)", 1, true)
check(purgePos ~= nil and encPos ~= nil and purgePos < encPos,
      "F6: la purga ocurre antes de serializar el snapshot")

-- ===================== TEST 7: F7 GUARDS CollectibleType EN TIERS =====================
local tierFiles = {
    "modules/synergies_tier1.lua",
    "modules/synergies_tier2.lua",
    "modules/synergies_tier3.lua",
}
for _, path in ipairs(tierFiles) do
    local c = readFile(path)
    check(c ~= nil, path .. " exists")
    if c then
        local total = count(c, "CollectibleType.COLLECTIBLE_")
        local guarded = count(c, "CollectibleType and CollectibleType.COLLECTIBLE_")
        check(total == guarded,
              "F7: 0 accesos CollectibleType.COLLECTIBLE_ sin guard en " .. path ..
              " (total=" .. total .. ", guardados=" .. guarded .. ")")
    end
end

if failures == 0 then
    print(string.format("All %d checks passed in test_audit_lote1.lua (failures=%d)", passes, failures))
    os.exit(0)
else
    print(string.format("FAILED: %d failures in test_audit_lote1.lua (passes=%d, failures=%d)", failures, passes, failures))
    os.exit(1)
end
