-- tools/test_hud_text_scale.lua
-- X2 - guard de regresion sobre la escala/anchura del texto propio de la HUD.
-- Compatible con Lua 5.1. Ejecutar desde la raiz del repo: lua tools/test_hud_text_scale.lua
--
-- Contrato cubierto (SPEC X2):
--   1. modules/hud_render.lua define Core.HUD_TEXT_SCALE == 0.8.
--   2. modules/fx_sprites.lua Core.DrawHudText consume Core.HUD_TEXT_SCALE en
--      Font:DrawStringScaled (sx == sy == escala) y cae a 1.0 si la constante no existe.
--   3. El fallback sin Font sigue usando Isaac.RenderScaledText(..., 0.5, 0.5, ...) intacto.
--   4. La barra de la HUD mide BAR_W = 30 en las DOS ramas (Hal Jordan y Tainted Hal).
--   5. La etiqueta se dibuja en hudX + 28 en las DOS ramas (antes +33).
--   6. GetCoopHUDOrigin sigue intacto: origen p0 = 48 / 40.
--
-- Determinismo: sin reloj, sin azar, sin red, sin escritura en disco. El FS solo se lee.

local failures, passes = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else
    failures = failures + 1
    io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
  end
end

local function countPlain(haystack, needle)
  local n, pos = 0, 1
  while true do
    local s, e = string.find(haystack, needle, pos, true)
    if not s then break end
    n = n + 1
    pos = e + 1
  end
  return n
end

local function readFile(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s
end

-- ===================== PARTE A: fx_sprites.DrawHudText =====================
-- Dobles: Font/KColor/Isaac.RenderScaledText. Sin motor real, sin red.
local fontCalls, renderCalls = {}, {}

Isaac = {
  RenderScaledText = function(text, x, y, sx, sy, r, g, b, a)
    table.insert(renderCalls, { text = text, x = x, y = y, sx = sx, sy = sy, r = r, g = g, b = b, a = a })
  end,
}

local CoreFx = {}
dofile("modules/fx_sprites.lua")(CoreFx)

-- (3) Fallback sin Font: Isaac.RenderScaledText con 0.5 / 0.5 (intacto).
check(type(CoreFx.DrawHudText) == "function", "fx_sprites debe definir Core.DrawHudText")
CoreFx.DrawHudText("50%", 10, 20, 1, 1, 1, 1)
check(#renderCalls == 1, "sin Font debe usarse el fallback RenderScaledText, llamadas=" .. tostring(#renderCalls))
if renderCalls[1] then
  check(renderCalls[1].sx == 0.5 and renderCalls[1].sy == 0.5,
        string.format("fallback debe escalar 0.5/0.5, fue %.4f/%.4f", renderCalls[1].sx, renderCalls[1].sy))
end

-- Font y KColor de doble: capturan los argumentos de DrawStringScaled.
local fakeFont = {
  _loaded = false,
  Load = function(self, _path) self._loaded = true end,
  IsLoaded = function(self) return self._loaded == true end,
  GetStringWidth = function(self, text) return #text * 5.5 end,
  DrawStringScaled = function(self, text, x, y, sx, sy, color, z, centered)
    table.insert(fontCalls, { text = text, x = x, y = y, sx = sx, sy = sy, color = color, z = z, centered = centered })
  end,
}
Font = function() return fakeFont end
KColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end

-- (2) Escala explicita 0.8 consumida por DrawHudText.
CoreFx.HUD_TEXT_SCALE = 0.8
CoreFx.DrawHudText("50%", 11, 21, 0.1, 0.95, 0.3, 0.95)
check(#fontCalls == 1, "con Font debe usarse DrawStringScaled, llamadas=" .. tostring(#fontCalls))
if fontCalls[1] then
  check(fontCalls[1].sx == 0.8 and fontCalls[1].sy == 0.8,
        string.format("DrawStringScaled debe usar escala 0.8/0.8, fue %.4f/%.4f", fontCalls[1].sx, fontCalls[1].sy))
  check(fontCalls[1].text == "50%" and fontCalls[1].x == 11 and fontCalls[1].y == 21,
        "DrawStringScaled debe recibir texto/posicion sin alterar")
  check(fontCalls[1].color and fontCalls[1].color.r == 0.1 and fontCalls[1].color.g == 0.95,
        "DrawStringScaled debe recibir el KColor original")
end

-- (2b) Default defensivo: sin Core.HUD_TEXT_SCALE -> escala 1.0 (no 0 ni nil).
CoreFx.HUD_TEXT_SCALE = nil
CoreFx.DrawHudText("REBOOT 10%/50%", 12, 22, 1, 0.45, 0.15, 0.95)
check(#fontCalls == 2, "segunda llamada a DrawHudText registrada, llamadas=" .. tostring(#fontCalls))
if fontCalls[2] then
  check(fontCalls[2].sx == 1.0 and fontCalls[2].sy == 1.0,
        string.format("sin HUD_TEXT_SCALE la escala debe caer a 1.0/1.0, fue %.4f/%.4f", fontCalls[2].sx, fontCalls[2].sy))
end

-- ===================== PARTE B: hud_render define la constante =====================
-- Dobles: Core.GL (AddCallback no-op) + ModCallbacks (tabla de ids).
ModCallbacks = { MC_PRE_PLAYER_RENDER = 31, MC_POST_PLAYER_RENDER = 32, MC_POST_RENDER = 33 }
local CoreHud = { GL = { AddCallback = function() end } }
dofile("modules/hud_render.lua")(CoreHud)

-- (1) La politica de tamano vive en hud_render.
check(CoreHud.HUD_TEXT_SCALE == 0.8,
      string.format("hud_render debe definir Core.HUD_TEXT_SCALE = 0.8, fue %s", tostring(CoreHud.HUD_TEXT_SCALE)))

-- ===================== PARTE C: contrato estatico de layout =====================
local hudSrc = readFile("modules/hud_bars.lua")

-- (4) BAR_W = 30 en las dos ramas; el valor viejo 36 no debe quedar.
check(countPlain(hudSrc, "local BAR_W = 30") == 2,
      "hud_bars debe declarar BAR_W = 30 en 2 ramas (Hal y Tainted), halladas " .. tostring(countPlain(hudSrc, "local BAR_W = 30")))
check(countPlain(hudSrc, "BAR_W = 36") == 0,
      "hud_bars no debe mantener BAR_W = 36, halladas " .. tostring(countPlain(hudSrc, "BAR_W = 36")))

-- (5) Etiqueta en hudX + 28 en las dos ramas; el offset viejo +33 no debe quedar.
check(countPlain(hudSrc, "hudX + 28") == 2,
      "hud_bars debe usar hudX + 28 en 2 ramas, halladas " .. tostring(countPlain(hudSrc, "hudX + 28")))
check(countPlain(hudSrc, "hudX + 33") == 0,
      "hud_bars no debe mantener hudX + 33, halladas " .. tostring(countPlain(hudSrc, "hudX + 33")))

-- (6) GetCoopHUDOrigin intacto: origen del jugador 0 en 48 / 40.
check(countPlain(hudSrc, "GetCoopHUDOrigin") >= 2,
      "GetCoopHUDOrigin debe seguir definido y usado")
check(countPlain(hudSrc, "return 48 + offX, 40 + offY") == 2,
      "GetCoopHUDOrigin debe conservar el origen 48/40 (p0 y fallback), hallados " .. tostring(countPlain(hudSrc, "return 48 + offX, 40 + offY")))
check(countPlain(hudSrc, "return 48 + offX, sH - (38 + offY)") == 1,
      "GetCoopHUDOrigin debe conservar el origen vertical p2 (48 / sH-38)")

io.stderr:write(string.format("\n[test_hud_text_scale] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
