-- tools/test_bug_fixes_audit.lua
-- Unit tests verifying the fixes found during the exhaustive codebase bug hunt:
-- 1. Burst shard suppression fix (Scatter Bombs & Compound Fracture itemTearBurstFrame)
-- 2. NaN vector prevention on direct hit reflection & orbital reflection
-- 3. NaN vector prevention on Stolen Ring targeting & Virtue Wisp push
-- 4. Cache flags on Green Lantern Ring (items.xml) & Yellow Impurity (trinkets.xml)

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- ===================== TEST 1: SCATTER BOMBS & COMPOUND FRACTURE =====================
local f1 = io.open("modules/synergies_tier3.lua", "r")
check(f1 ~= nil, "modules/synergies_tier3.lua exists")
local content1 = f1:read("*a")
f1:close()

check(content1:find("data.itemTearBurstFrame = Game():GetFrameCount()", 1, true) ~= nil,
      "Scatter Bombs sets itemTearBurstFrame to avoid suppression")

local f2 = io.open("modules/synergies_tier2.lua", "r")
check(f2 ~= nil, "modules/synergies_tier2.lua exists")
local content2 = f2:read("*a")
f2:close()

check(content2:find("data.itemTearBurstFrame = Game():GetFrameCount()", 1, true) ~= nil,
      "Compound Fracture sets itemTearBurstFrame on shard burst")

-- ===================== TEST 2: SHIELD REFLECTION VECTOR SAFETY =====================
local f3 = io.open("modules/shield.lua", "r")
check(f3 ~= nil, "modules/shield.lua exists")
local content3 = f3:read("*a")
f3:close()

check(content3:find("targetDir.X ~= targetDir.X", 1, true) ~= nil,
      "Shield orbital deflection includes explicit IEEE 754 NaN guard")
check(content3:find("diff:Length() > 0.1 and diff:Normalized()", 1, true) ~= nil,
      "Shield direct reflection guards against zero length diff")

-- ===================== TEST 3: TAINTED RINGS & VIRTUES VECTOR SAFETY =====================
local f4 = io.open("modules/tainted_rings.lua", "r")
check(f4 ~= nil, "modules/tainted_rings.lua exists")
local content4 = f4:read("*a")
f4:close()

check(content4:find("diff:Length() > 0.01 and diff:Normalized() or Vector(1, 0)", 1, true) ~= nil,
      "Tainted rings checks diff length before normalizing")

local f5 = io.open("modules/synergies_virtues.lua", "r")
check(f5 ~= nil, "modules/synergies_virtues.lua exists")
local content5 = f5:read("*a")
f5:close()

check(content5:find("if d > 0.01 then", 1, true) ~= nil,
      "Virtues Giant Fist wisp checks distance before push normalization")
check(content5:find("diff:Length() > 0.01 and diff:Normalized()", 1, true) ~= nil,
      "Virtues Gatling wisp checks distance before shoot normalization")

-- ===================== TEST 4: XML CACHE FLAGS =====================
local fXmlItems = io.open("content/items.xml", "r")
check(fXmlItems ~= nil, "content/items.xml exists")
local xmlItems = fXmlItems:read("*a")
fXmlItems:close()

check(xmlItems:find('name="Green Lantern Ring"[^>]*cache="[^"]*damage[^"]*"', 1) ~= nil,
      "Green Lantern Ring has cache attribute with damage")
check(xmlItems:find('name="Green Lantern Ring"[^>]*cache="[^"]*flying[^"]*"', 1) ~= nil,
      "Green Lantern Ring has cache attribute with flying")

local fXmlTrinkets = io.open("content/trinkets.xml", "r")
check(fXmlTrinkets ~= nil, "content/trinkets.xml exists")
local xmlTrinkets = fXmlTrinkets:read("*a")
fXmlTrinkets:close()

check(xmlTrinkets:find('name="Yellow Impurity"[^>]*cache="damage"', 1) ~= nil,
      "Yellow Impurity trinket has cache attribute with damage")

if failures == 0 then
    print(string.format("All %d checks passed in test_bug_fixes_audit.lua", passes))
    os.exit(0)
else
    print(string.format("FAILED: %d failures in test_bug_fixes_audit.lua", failures))
    os.exit(1)
end
