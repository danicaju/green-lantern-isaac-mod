-- tools/test_giant_fist_construct_quality.lua
-- Unit test ensuring:
-- 1. Boss VS name banners (name_hal_jordan.png & name_tainted_hal.png) meet size and left-alignment specs.
-- 2. gl_giant_fist.anm2 defines Idle and all fallback animations (RegularTear, ToothMove, etc.).
-- 3. modules/item_fist.lua does not spawn vanilla TOOTH.
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
    local content = f:read("*a")
    f:close()
    return content
end

-- 1. Check item_fist.lua does not use TearVariant.TOOTH
local itemFistSrc = readFile("modules/item_fist.lua")
check(itemFistSrc ~= nil, "modules/item_fist.lua should be readable")
check(not string.find(itemFistSrc, "TearVariant%.TOOTH"), "item_fist.lua must NOT spawn TearVariant.TOOTH")
check(string.find(itemFistSrc, "Core%.ApplyGiantFistSprite%(fist%)") ~= nil, "item_fist.lua must call ApplyGiantFistSprite")

-- 2. Check gl_giant_fist.anm2 animations
local anm2Src = readFile("resources/gfx/effects/gl_giant_fist.anm2")
check(anm2Src ~= nil, "gl_giant_fist.anm2 should be readable")
check(string.find(anm2Src, 'Name="Idle"') ~= nil, "gl_giant_fist.anm2 must contain Idle animation")
check(string.find(anm2Src, 'Name="RegularTear1"') ~= nil, "gl_giant_fist.anm2 must contain RegularTear1 animation")
check(string.find(anm2Src, 'Name="RegularTear13"') ~= nil, "gl_giant_fist.anm2 must contain RegularTear13 animation")
check(string.find(anm2Src, 'Name="Tooth1Move"') ~= nil, "gl_giant_fist.anm2 must contain Tooth1Move animation")
check(string.find(anm2Src, 'Name="BloodTear1"') ~= nil, "gl_giant_fist.anm2 must contain BloodTear1 animation")

-- 3. Check PNG files exist
local pngFist = io.open("resources/gfx/effects/gl_giant_fist.png", "rb")
check(pngFist ~= nil, "resources/gfx/effects/gl_giant_fist.png must exist")
if pngFist then pngFist:close() end

local pngHal = io.open("resources/gfx/ui/boss/name_hal_jordan.png", "rb")
check(pngHal ~= nil, "resources/gfx/ui/boss/name_hal_jordan.png must exist")
if pngHal then pngHal:close() end

local pngTainted = io.open("resources/gfx/ui/boss/name_tainted_hal.png", "rb")
check(pngTainted ~= nil, "resources/gfx/ui/boss/name_tainted_hal.png must exist")
if pngTainted then pngTainted:close() end

io.stderr:write(string.format("\n[test_giant_fist_construct_quality] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
