-- tools/test_item_pools_and_eid.lua
-- Unit test for valid canonical Repentance item pool names and bilingual EID translations.
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
    local content = f:read("*a") or ""
    f:close()
    return content
end

-- 1. Check itempools.xml
local poolsXml = readFile("content/itempools.xml")
check(poolsXml ~= nil, "content/itempools.xml must exist")

if poolsXml then
    -- Check that no old capitalized names exist
    check(not poolsXml:find('Name="Treasure Room"'), 'Must not contain legacy "Treasure Room"')
    check(not poolsXml:find('Name="Shop"'), 'Must not contain legacy "Shop"')

    -- Check canonical pools exist
    local canonicalPools = { "treasure", "shop", "planetarium", "angel", "devil", "curse" }
    for _, pool in ipairs(canonicalPools) do
        local needle = 'Pool Name="' .. pool .. '"'
        check(poolsXml:find(needle, 1, true) ~= nil, "itempools.xml must define pool " .. pool)
    end
end

-- 2. Check fx_sprites.lua for bilingual EID registrations
local fxSprites = readFile("modules/fx_sprites.lua")
check(fxSprites ~= nil, "modules/fx_sprites.lua must exist")

if fxSprites then
    check(fxSprites:find('"en_us"', 1, true) ~= nil, "Must support en_us")
    check(fxSprites:find('"es"', 1, true) ~= nil, "Must support es")
    check(fxSprites:find("Batería de Poder", 1, true) ~= nil, "Spanish translation for Power Battery")
    check(fxSprites:find("Puño Gigante", 1, true) ~= nil, "Spanish translation for Giant Fist")
    check(fxSprites:find("La Tragedia de Coast City", 1, true) ~= nil, "Spanish translation for Coast City")
    check(fxSprites:find("Ametralladora Gatling", 1, true) ~= nil, "Spanish translation for Gatling")
    check(fxSprites:find("Escudo de Luz Sólida", 1, true) ~= nil, "Spanish translation for Solid Light Shield")
    check(fxSprites:find("Anillo de Linterna Verde", 1, true) ~= nil, "Spanish translation for Green Lantern Ring")
    check(fxSprites:find("setModIndicatorName", 1, true) ~= nil, "EID mod indicator name must be registered")
    check(fxSprites:find("{{Collectible356}} Car Battery", 1, true) ~= nil, "English Car Battery synergy markup must be present")
    check(fxSprites:find("{{Collectible356}} Pila de coche", 1, true) ~= nil, "Spanish Car Battery synergy markup must be present")
    check(fxSprites:find("EID.addSynergy", 1, true) ~= nil, "EID.addSynergy hook must be supported")
    check(fxSprites:find("%[Car Battery%]: Instant Tier 2 Overcharge") ~= nil, "Inspection info must describe Power Battery synergy")
    check(fxSprites:find("%[Car Battery%]: Fires dual parallel giant fists") ~= nil, "Inspection info must describe Giant Fist synergy")
end

io.stderr:write(string.format("\n[test_item_pools_and_eid] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
