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

-- 3. Check modules/eid_synergies.lua for bilingual synergy descriptions
local eidSynergiesFile = readFile("modules/eid_synergies.lua")
check(eidSynergiesFile ~= nil, "modules/eid_synergies.lua must exist")

local mockCore = {
    ITEM_POWER_RING = 999,
    PLAYER_HAL = 10,
    PLAYER_TAINTED_HAL = 11,
    LoadItemIDs = function() end,
    IsHalJordan = function(p) return p.isHal end,
    IsTaintedHal = function(p) return p.isTHal end,
}

local eidInit = dofile("modules/eid_synergies.lua")
check(type(eidInit) == "function", "modules/eid_synergies.lua must return an initializer function")
eidInit(mockCore)

check(type(mockCore.EIDSynergyDescriptions) == "table", "Core.EIDSynergyDescriptions must be registered")
check(type(mockCore.EnsureEIDSynergiesRegistered) == "function", "Core.EnsureEIDSynergiesRegistered must be defined")
check(type(mockCore.GetSynergyDescription) == "function", "Core.GetSynergyDescription must be defined")

-- Verify key items across tiers have bilingual entries
local testIds = {
    577, -- Knockout Drops (Tier 1)
    220, -- Sad Bombs (Tier 1)
    374, -- Holy Light (Tier 1)
    509, -- Compound Fracture (Tier 2)
    257, -- Fire Mind (Tier 2)
    527, -- Flat Stone (Tier 2)
    462, -- Eye of Belial (Tier 3)
    408, -- Little Horn (Tier 3)
    441, -- Mega Blast (Tier 3)
    643, -- Revelation (Tier 3)
    49,  -- Shoop da Whoop (Tier 3)
    366, -- Scatter Bombs (Tier 3)
    597, -- Neptunus (Tier 3)
}

for _, id in ipairs(testIds) do
    local descEn = mockCore.GetSynergyDescription(id, false)
    local descEs = mockCore.GetSynergyDescription(id, true)
    check(descEn ~= nil and #descEn > 5, "Item " .. id .. " must have English synergy description")
    check(descEs ~= nil and #descEs > 5, "Item " .. id .. " must have Spanish synergy description")
end

-- Verify mock EID modifier and synergy registration
local mockEID = {
    modifiers = {},
    synergies = {},
    charSynergies = {},
    addDescriptionModifier = function(self, name, cond, cb)
        table.insert(self.modifiers, { name = name, cond = cond, cb = cb })
    end,
    addSynergy = function(self, id, withId, text, title, lang)
        table.insert(self.synergies, { id = id, withId = withId, text = text, lang = lang })
    end,
    addCharacterSynergy = function(self, charId, id, text, title, lang)
        table.insert(self.charSynergies, { charId = charId, id = id, text = text, lang = lang })
    end,
    appendToDescription = function(self, descObj, text)
        descObj.Description = (descObj.Description or "") .. text
    end,
    getLanguage = function() return "en_us" end,
}

EID = mockEID
Game = function()
    return {
        GetNumPlayers = function() return 1 end,
    }
end
Isaac = Isaac or {}
Isaac.GetPlayer = function() return { isHal = true, HasCollectible = function() return false end } end

mockCore.EnsureEIDSynergiesRegistered()

check(#mockEID.modifiers > 0, "GL description modifier registered in EID")
check(#mockEID.synergies > 0, "Native EID synergies registered")
check(#mockEID.charSynergies > 0, "Native character synergies registered")

-- Test modifier execution on a pedestal
local testPedestal = {
    ObjType = 5,
    ObjVariant = 100,
    ObjSubType = 577, -- Knockout Drops
    Description = "Base Knockout Drops description",
}

local modRecord = mockEID.modifiers[1]
check(modRecord.cond(testPedestal) == true, "Modifier condition returns true when Hal is present")
modRecord.cb(testPedestal)
check(testPedestal.Description:find("Boxing Glove") ~= nil, "Pedestal description appended with Green Lantern synergy")

io.stderr:write(string.format("\n[test_item_pools_and_eid] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
