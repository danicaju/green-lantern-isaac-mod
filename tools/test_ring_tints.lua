-- tools/test_ring_tints.lua
-- TDD unit tests for modules/synergies_ring_tint.lua
-- Verifica: tabla de visuales, defaults, tintes por item, precedencia, guards y pcall.

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end
local function approx(a, b, eps)
    eps = eps or 0.0001
    return math.abs(a - b) < eps
end
local function checkColor(got, expected, label)
    check(approx(got.R, expected.R), label .. " R expected " .. expected.R .. " got " .. got.R)
    check(approx(got.G, expected.G), label .. " G expected " .. expected.G .. " got " .. got.G)
    check(approx(got.B, expected.B), label .. " B expected " .. expected.B .. " got " .. got.B)
    check(approx(got.A, expected.A), label .. " A expected " .. expected.A .. " got " .. got.A)
    check(approx(got.RO or 0, expected.RO or 0), label .. " RO expected " .. (expected.RO or 0) .. " got " .. (got.RO or 0))
    check(approx(got.GO or 0, expected.GO or 0), label .. " GO expected " .. (expected.GO or 0) .. " got " .. (got.GO or 0))
    check(approx(got.BO or 0, expected.BO or 0), label .. " BO expected " .. (expected.BO or 0) .. " got " .. (got.BO or 0))
end

-- ===================== STUBS =====================
CollectibleType = {
    COLLECTIBLE_SOY_MILK = 330,
    COLLECTIBLE_LOST_CONTACT = 213,
    COLLECTIBLE_MIDAS_TOUCH = 202,
    COLLECTIBLE_SACRED_HEART = 182,
    COLLECTIBLE_DEATHS_TOUCH = 187,
    COLLECTIBLE_8_INCH_NAILS = 359,
    COLLECTIBLE_TECHNOLOGY = 68,
    COLLECTIBLE_TECH_X = 395,
}

Color = function(r, g, b, a, ro, go, bo)
    return { R = r, G = g, B = b, A = a, RO = ro or 0, GO = go or 0, BO = bo or 0 }
end

-- ===================== LOAD MODULE =====================
local Core = {}
local factory = dofile("modules/synergies_ring_tint.lua")
check(type(factory) == "function", "synergies_ring_tint.lua returns a factory function")
factory(Core)
check(type(Core.GetRingBeamVisual) == "function", "Core.GetRingBeamVisual is defined")

-- ===================== HELPERS =====================
local function makePlayer(items)
    local map = {}
    for _, id in ipairs(items or {}) do map[id] = true end
    return {
        HasCollectible = function(_, id) return map[id] == true end,
    }
end

local WHITE = Color(1, 1, 1, 1, 0, 0, 0)
local SOY_TINT = Color(0.75, 1.0, 0.8, 0.9, 0, 0, 0)
local LOST_TINT = Color(0.55, 1.0, 0.75, 1.0, 0, 0, 0)
local MIDAS_TINT = Color(1.0, 0.95, 0.35, 1.0, 0.55, 0.45, 0.05)
local SACRED_TINT = Color(1, 1, 1, 1, 0, 0, 0)
local DEATH_TINT = Color(0.35, 0.95, 0.5, 1.0, 0, 0, 0)
local NAILS_TINT = Color(0.85, 1.0, 0.9, 1.0, 0, 0, 0)
local TECH_TINT = Color(0.75, 1.0, 0.9, 1.0, 0, 0.05, 0.1)

-- ===================== TESTS =====================
-- 1) Sin items: blanco puro y escala 1.0
local t, s = Core.GetRingBeamVisual(makePlayer({}))
checkColor(t, WHITE, "no items tint")
check(approx(s, 1.0), "no items scale is 1.0")

-- 2) Cada item individual devuelve su tinte y escala documentados
local cases = {
    { {CollectibleType.COLLECTIBLE_SOY_MILK}, SOY_TINT, 0.8, "Soy Milk" },
    { {CollectibleType.COLLECTIBLE_LOST_CONTACT}, LOST_TINT, 1.15, "Lost Contact" },
    { {CollectibleType.COLLECTIBLE_MIDAS_TOUCH}, MIDAS_TINT, 1.0, "Midas Touch" },
    { {CollectibleType.COLLECTIBLE_SACRED_HEART}, SACRED_TINT, 1.2, "Sacred Heart" },
    { {CollectibleType.COLLECTIBLE_DEATHS_TOUCH}, DEATH_TINT, 1.15, "Death's Touch" },
    { {CollectibleType.COLLECTIBLE_8_INCH_NAILS}, NAILS_TINT, 1.4, "8 Inch Nails" },
    { {CollectibleType.COLLECTIBLE_TECHNOLOGY}, TECH_TINT, 1.0, "Technology" },
    { {CollectibleType.COLLECTIBLE_TECH_X}, TECH_TINT, 1.0, "Tech X" },
}
for _, c in ipairs(cases) do
    local tint, scale = Core.GetRingBeamVisual(makePlayer(c[1]))
    checkColor(tint, c[2], c[4] .. " tint")
    check(approx(scale, c[3]), c[4] .. " scale is " .. c[3])
end

-- 3) Blend multiplicativo suave: media geometrica de RGB + media de alpha/offset.
-- Un item blanco (Sacred Heart) aclara el tono sin borrarlo.
local function blendColors(colors)
    local n = #colors
    local r, g, b = 1.0, 1.0, 1.0
    local a, ro, go, bo = 0.0, 0.0, 0.0, 0.0
    for _, c in ipairs(colors) do
        r = r * c.R; g = g * c.G; b = b * c.B
        a = a + c.A; ro = ro + (c.RO or 0); go = go + (c.GO or 0); bo = bo + (c.BO or 0)
    end
    local invN = 1.0 / n
    local function clamp01(x) return math.max(0, math.min(1, x)) end
    return {
        R = clamp01(r ^ invN), G = clamp01(g ^ invN), B = clamp01(b ^ invN),
        A = clamp01(a / n), RO = ro / n, GO = go / n, BO = bo / n,
    }
end

local tintMix, scaleMix = Core.GetRingBeamVisual(makePlayer({
    CollectibleType.COLLECTIBLE_SOY_MILK,
    CollectibleType.COLLECTIBLE_8_INCH_NAILS,
}))
checkColor(tintMix, blendColors({SOY_TINT, NAILS_TINT}), "Soy Milk + 8 Inch Nails: blended tint (geometric mean)")
check(approx(scaleMix, 0.8 * 1.4), "Soy Milk + 8 Inch Nails scale multiplied")

local tintOverride, scaleOverride = Core.GetRingBeamVisual(makePlayer({
    CollectibleType.COLLECTIBLE_MIDAS_TOUCH,
    CollectibleType.COLLECTIBLE_SACRED_HEART,
}))
local midasSacredBlend = blendColors({MIDAS_TINT, SACRED_TINT})
checkColor(tintOverride, midasSacredBlend, "Midas + Sacred Heart: white lightens gold instead of replacing it")
check(tintOverride.R < 1.0 or tintOverride.G < 1.0 or tintOverride.B < 1.0,
    "Midas + Sacred Heart: tint is not pure white (gold tone preserved)")
check(approx(scaleOverride, 1.0 * 1.2), "Midas + Sacred Heart scale multiplied")

-- 4) Jugador nil devuelve blanco + 1.0 sin error
local nilTint, nilScale = Core.GetRingBeamVisual(nil)
checkColor(nilTint, WHITE, "nil player tint")
check(approx(nilScale, 1.0), "nil player scale")

-- 5) pcall: HasCollectible que lanza error no crasha y devuelve blanco
local badPlayer = {
    HasCollectible = function() error("intentional") end,
}
local badTint, badScale = Core.GetRingBeamVisual(badPlayer)
checkColor(badTint, WHITE, "bad player pcall tint")
check(approx(badScale, 1.0), "bad player pcall scale")

-- 6) Guard sin CollectibleType: recargar modulo con global nil no falla y devuelve blanco
local savedCT = CollectibleType
CollectibleType = nil
local Core2 = {}
local ok, err = pcall(function()
    dofile("modules/synergies_ring_tint.lua")(Core2)
end)
check(ok, "module loads without CollectibleType: " .. tostring(err))
if ok then
    local g, sc = Core2.GetRingBeamVisual(makePlayer({}))
    checkColor(g, WHITE, "nil CollectibleType default tint")
    check(approx(sc, 1.0), "nil CollectibleType default scale")
end
CollectibleType = savedCT

-- Summary
print(string.format("test_ring_tints.lua: %d passed, %d failed", passes, failures))
if failures > 0 then
    os.exit(1)
end
