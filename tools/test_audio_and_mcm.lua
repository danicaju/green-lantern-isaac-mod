-- tools/test_audio_and_mcm.lua
-- Unit tests for Comic Audio Cues & Mod Config Menu (MCM) sliders/toggles

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- ===================== TEST 1: CORE DEFAULTS =====================
RegisterMod = function() return { AddCallback = function() end } end
local Core = dofile("modules/core.lua")

check(Core.BEAM_OPACITY == 1.0, "Core.BEAM_OPACITY default is 1.0")
check(Core.BEAM_WIDTH_MULT == 1.0, "Core.BEAM_WIDTH_MULT default is 1.0")
check(Core.RING_FLARE_INTENSITY == 1.0, "Core.RING_FLARE_INTENSITY default is 1.0")
check(Core.AURA_GLOW_SCALE == 1.0, "Core.AURA_GLOW_SCALE default is 1.0")
check(Core.AURA_GLOW_OPACITY == 1.0, "Core.AURA_GLOW_OPACITY default is 1.0")

check(Core.OVERCHARGE_CHIME_ENABLED == true, "Core.OVERCHARGE_CHIME_ENABLED default is true")
check(Core.LOW_WILLPOWER_WARNING_ENABLED == true, "Core.LOW_WILLPOWER_WARNING_ENABLED default is true")
check(Core.CONSTRUCT_SFX_ENABLED == true, "Core.CONSTRUCT_SFX_ENABLED default is true")

-- ===================== TEST 2: AUDIO CUES =====================
local playedSounds = {}
SoundEffect = {
    SOUND_SUPERHOLY = 266,
    SOUND_HOLY = 54,
    SOUND_BATTERYCHARGE = 170,
    SOUND_BATTERYDISCHARGE = 71,
    SOUND_PUNCH = 88,
    SOUND_GLASS_BREAK = 89,
}

SFXManager = function()
    return {
        Play = function(_, sfx, vol, frameDelay, loop, pitch)
            table.insert(playedSounds, { sfx = sfx, vol = vol, pitch = pitch })
        end
    }
end

-- Load utils into Core
dofile("modules/utils.lua")(Core)

check(type(Core.PlayOverchargeChime) == "function", "Core.PlayOverchargeChime defined")
check(type(Core.PlayLowWillpowerWarning) == "function", "Core.PlayLowWillpowerWarning defined")
check(type(Core.PlayRingRebootChime) == "function", "Core.PlayRingRebootChime defined")
check(type(Core.PlayConstructPunchSound) == "function", "Core.PlayConstructPunchSound defined")
check(type(Core.PlayCrystallizationSound) == "function", "Core.PlayCrystallizationSound defined")

-- Test Overcharge Chime
playedSounds = {}
Core.PlayOverchargeChime(nil)
check(#playedSounds == 1 and playedSounds[1].sfx == SoundEffect.SOUND_SUPERHOLY, "Overcharge chime plays SUPERHOLY sound")

Core.OVERCHARGE_CHIME_ENABLED = false
playedSounds = {}
Core.PlayOverchargeChime(nil)
check(#playedSounds == 0, "Overcharge chime muted when OVERCHARGE_CHIME_ENABLED is false")
Core.OVERCHARGE_CHIME_ENABLED = true

-- Test Low Willpower Warning
playedSounds = {}
Core.PlayLowWillpowerWarning(nil)
check(#playedSounds == 1 and playedSounds[1].sfx == SoundEffect.SOUND_BATTERYDISCHARGE, "Low willpower warning plays BATTERYDISCHARGE sound")

Core.LOW_WILLPOWER_WARNING_ENABLED = false
playedSounds = {}
Core.PlayLowWillpowerWarning(nil)
check(#playedSounds == 0, "Low willpower warning muted when LOW_WILLPOWER_WARNING_ENABLED is false")
Core.LOW_WILLPOWER_WARNING_ENABLED = true

-- Test Ring Reboot Chime
playedSounds = {}
Core.PlayRingRebootChime(nil)
check(#playedSounds == 1 and playedSounds[1].sfx == SoundEffect.SOUND_BATTERYCHARGE, "Reboot chime plays BATTERYCHARGE sound")

-- Test Construct Punch and Crystallization
playedSounds = {}
Core.PlayConstructPunchSound(nil, true)
check(#playedSounds == 1 and playedSounds[1].sfx == SoundEffect.SOUND_PUNCH, "Construct punch plays PUNCH sound")

playedSounds = {}
Core.PlayCrystallizationSound(nil)
check(#playedSounds == 1 and playedSounds[1].sfx == SoundEffect.SOUND_GLASS_BREAK, "Crystallization plays GLASS_BREAK sound")

-- ===================== TEST 3: MOD CONFIG MENU (MCM) =====================
local mcmSettings = {}
ModConfigMenuOptionType = { NUMBER = 1, BOOLEAN = 2 }
ModConfigMenu = {
    AddSetting = function(modId, subCat, opt)
        table.insert(mcmSettings, { modId = modId, subCat = subCat, opt = opt })
    end
}

dofile("modules/fx_mcm.lua")(Core)

check(#mcmSettings >= 15, "MCM settings registered (>15 options)")

-- Check that categories exist
local foundCats = {}
for _, s in ipairs(mcmSettings) do
    foundCats[s.subCat] = true
end

check(foundCats["Accessibility"] == true, "MCM has Accessibility subcategory")
check(foundCats["Visuals"] == true, "MCM has Visuals subcategory")
check(foundCats["Audio"] == true, "MCM has Audio subcategory")
check(foundCats["Controls"] == true, "MCM has Controls subcategory")
check(foundCats["Balance"] == true, "MCM has Balance subcategory")

-- Test changing a Visual setting via MCM callback
local opacitySetting = nil
for _, s in ipairs(mcmSettings) do
    if s.subCat == "Visuals" and s.opt.Display():find("Opacidad del rayo") then
        opacitySetting = s
        break
    end
end
check(opacitySetting ~= nil, "Opacity setting exists in Visuals")
if opacitySetting then
    opacitySetting.opt.OnChange(0.75)
    check(math.abs(Core.BEAM_OPACITY - 0.75) < 0.001, "BEAM_OPACITY updated via MCM OnChange")
    check(opacitySetting.opt.Display():find("0.75") ~= nil, "MCM display reflects updated opacity value")
end

-- Test changing an Audio setting via MCM callback
local audioSetting = nil
for _, s in ipairs(mcmSettings) do
    if s.subCat == "Audio" and s.opt.Display():find("Campana de sobrecarga") then
        audioSetting = s
        break
    end
end
check(audioSetting ~= nil, "Audio setting exists for Overcharge Chime")
if audioSetting then
    audioSetting.opt.OnChange(false)
    check(Core.OVERCHARGE_CHIME_ENABLED == false, "OVERCHARGE_CHIME_ENABLED updated via MCM callback")
    check(audioSetting.opt.Display():find("OFF") ~= nil, "MCM display shows OFF")
end

io.stderr:write(string.format("\n[test_audio_and_mcm] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
