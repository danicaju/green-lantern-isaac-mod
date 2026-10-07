-- tools/test_birthright_mechanics.lua
-- Unit test for custom Birthright mechanics (Hal Jordan & Parallax) and MCM defaults.
local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- Stubs
function RegisterMod(_name, _ver) return { AddCallback = function() end } end
CollectibleType = { COLLECTIBLE_BIRTHRIGHT = 619 }
ModCallbacks = { MC_POST_PLAYER_UPDATE = 1, MC_POST_NEW_ROOM = 2 }

local Core = dofile("modules/core.lua")
check(type(Core) == "table", "core.lua must return a table")

-- 1. Check default configurations
check(Core.SCREEN_SHAKE_ENABLED == true, "SCREEN_SHAKE_ENABLED default true")
check(Core.HUD_GL_DISPLAY == true, "HUD_GL_DISPLAY default true")
check(Core.SFX_VOLUME_MULT == 1.0, "SFX_VOLUME_MULT default 1.0")
check(Core.BIRTHRIGHT_ENABLED == true, "BIRTHRIGHT_ENABLED default true")

-- Load birthright module
local brFactory = dofile("modules/birthright.lua")
brFactory(Core)

-- Mock players
local function makePlayer(isHal, isTainted, hasBirthright)
    return {
        _isHal = isHal,
        _isTainted = isTainted,
        HasCollectible = function(_, id) return hasBirthright and (id == 619) end,
        GetData = function() return {} end,
        AddCacheFlags = function() end,
        EvaluateItems = function() end,
    }
end

Core.IsHalJordan = function(p) return p._isHal == true end
Core.IsTaintedHal = function(p) return p._isTainted == true end

local halNormal = makePlayer(true, false, false)
local halBR = makePlayer(true, false, true)
local tHalNormal = makePlayer(false, true, false)
local tHalBR = makePlayer(false, true, true)

-- 2. Check HasBirthright predicate
check(Core.HasBirthright(halNormal) == false, "Hal without Birthright returns false")
check(Core.HasBirthright(halBR) == true, "Hal with Birthright returns true")
check(Core.HasBirthright(tHalNormal) == false, "Tainted without Birthright returns false")
check(Core.HasBirthright(tHalBR) == true, "Tainted with Birthright returns true")

-- 3. Check dynamic max Willpower
check(Core.GetMaxWillpower(halNormal) == 100.0, "Hal normal max Willpower is 100")
check(Core.GetMaxWillpower(halBR) == 150.0, "Hal Birthright max Willpower is 150")

-- 4. Check dynamic max Stolen Rings
check(Core.GetMaxStolenRings(tHalNormal) == 10, "Tainted Hal normal max Stolen Rings is 10")
check(Core.GetMaxStolenRings(tHalBR) == 15, "Tainted Hal Birthright max Stolen Rings is 15")

-- 5. Check Birthright disabled toggle
Core.BIRTHRIGHT_ENABLED = false
check(Core.HasBirthright(halBR) == false, "When BIRTHRIGHT_ENABLED is false, HasBirthright is false")
check(Core.GetMaxWillpower(halBR) == 100.0, "When disabled, max Willpower reverts to 100")
Core.BIRTHRIGHT_ENABLED = true

io.stderr:write(string.format("\n[test_birthright_mechanics] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
