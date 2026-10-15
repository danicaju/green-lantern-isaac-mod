-- tools/test_death_epitaphs_and_encyclopedia.lua
-- Unit tests for comic death epitaphs and encyclopedia expansion.

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- ===================== TEST 1: DEATH EPITAPHS MODULE =====================
local callbacks = {}
local mockGL = {
    AddCallback = function(self, id, fn)
        callbacks[id] = fn
    end
}

ModCallbacks = {
    MC_POST_GAME_STARTED = 1,
    MC_POST_RENDER = 2,
}

local mockCore = {
    GL = mockGL,
    DEATH_EPITAPHS_ENABLED = true,
    activeDeathEpitaph = nil,
    SFX_VOLUME_MULT = 1.0,
    IsHalJordan = function(p) return p._type == 10 end,
    IsTaintedHal = function(p) return p._type == 11 end,
}

local initEpitaphs = dofile("modules/death_epitaphs.lua")
check(type(initEpitaphs) == "function", "modules/death_epitaphs.lua returns a loader function")
initEpitaphs(mockCore)

check(type(mockCore.HAL_EPITAPHS) == "table", "HAL_EPITAPHS table exists")
check(#mockCore.HAL_EPITAPHS >= 5, "HAL_EPITAPHS has at least 5 quotes (" .. tostring(#mockCore.HAL_EPITAPHS) .. ")")
for idx, entry in ipairs(mockCore.HAL_EPITAPHS) do
    check(type(entry.quote) == "string" and #entry.quote > 0, "Hal quote " .. idx .. " has valid quote text")
    check(type(entry.author) == "string" and #entry.author > 0, "Hal quote " .. idx .. " has valid author text")
end

check(type(mockCore.PARALLAX_EPITAPHS) == "table", "PARALLAX_EPITAPHS table exists")
check(#mockCore.PARALLAX_EPITAPHS >= 5, "PARALLAX_EPITAPHS has at least 5 quotes (" .. tostring(#mockCore.PARALLAX_EPITAPHS) .. ")")
for idx, entry in ipairs(mockCore.PARALLAX_EPITAPHS) do
    check(type(entry.quote) == "string" and #entry.quote > 0, "Parallax quote " .. idx .. " has valid quote text")
    check(type(entry.author) == "string" and #entry.author > 0, "Parallax quote " .. idx .. " has valid author text")
end

-- Test state reset on game started
mockCore.activeDeathEpitaph = { quote = "Old Quote", author = "Old Author", timer = 100 }
callbacks[ModCallbacks.MC_POST_GAME_STARTED](nil, false)
check(mockCore.activeDeathEpitaph == nil, "MC_POST_GAME_STARTED resets activeDeathEpitaph")

-- Setup Isaac & Game mocks for death render testing
local playersInGame = {}
Game = function()
    return {
        GetNumPlayers = function() return #playersInGame end
    }
end

local renderedTexts = {}
Isaac = {
    GetPlayer = function(idx) return playersInGame[idx + 1] end,
    GetScreenWidth = function() return 480 end,
    GetScreenHeight = function() return 270 end,
    RenderScaledText = function(text, x, y, sx, sy, r, g, b, a)
        table.insert(renderedTexts, { text = text, x = x, y = y, a = a })
    end
}

local sfxPlayed = {}
SFXManager = function()
    return {
        Play = function(s, sfxId, vol, frame, loop, pitch)
            table.insert(sfxPlayed, { id = sfxId, vol = vol, pitch = pitch })
        end
    }
end
SoundEffect = {
    SOUND_BATTERYDISCHARGE = 55,
    SOUND_HELL_PORTAL2 = 77,
}

-- Case A: Player is alive Hal Jordan -> no epitaph
local livingHal = {
    _type = 10,
    IsDead = function() return false end,
    GetSprite = function() return { IsPlaying = function() return false end } end,
}
playersInGame = { livingHal }
callbacks[ModCallbacks.MC_POST_RENDER](nil)
check(mockCore.activeDeathEpitaph == nil, "Living player does not trigger death epitaph")
check(#renderedTexts == 0, "No text rendered while alive")

-- Case B: Player is dead Hal Jordan -> Hal death epitaph triggered
local deadHal = {
    _type = 10,
    IsDead = function() return true end,
    GetSprite = function() return { IsPlaying = function() return true end } end,
}
playersInGame = { deadHal }
callbacks[ModCallbacks.MC_POST_RENDER](nil)
check(mockCore.activeDeathEpitaph ~= nil, "Dead Hal triggers activeDeathEpitaph")
check(mockCore.activeDeathEpitaph.isTainted == false, "Dead Hal epitaph has isTainted == false")
check(#renderedTexts >= 3, "Hal death epitaph rendered title, quote, and author")
check(#sfxPlayed == 1 and sfxPlayed[1].id == 55, "Hal played battery discharge sfx")

-- Case C: Second render frame increments timer
renderedTexts = {}
callbacks[ModCallbacks.MC_POST_RENDER](nil)
check(mockCore.activeDeathEpitaph.timer == 2, "Epitaph timer increments per render tick")
check(#renderedTexts >= 3, "Rendered text continued onto next frame")

-- Case D: Parallax death triggers Parallax quote & portal sound
mockCore.activeDeathEpitaph = nil
renderedTexts = {}
sfxPlayed = {}
local deadParallax = {
    _type = 11,
    IsDead = function() return true end,
    GetSprite = function() return { IsPlaying = function() return true end } end,
}
playersInGame = { deadParallax }
callbacks[ModCallbacks.MC_POST_RENDER](nil)
check(mockCore.activeDeathEpitaph ~= nil, "Dead Parallax triggers activeDeathEpitaph")
check(mockCore.activeDeathEpitaph.isTainted == true, "Dead Parallax has isTainted == true")
check(#sfxPlayed == 1 and sfxPlayed[1].id == 77, "Parallax played hell portal sfx")

-- Case E: Toggle disabled
mockCore.activeDeathEpitaph = nil
renderedTexts = {}
mockCore.DEATH_EPITAPHS_ENABLED = false
callbacks[ModCallbacks.MC_POST_RENDER](nil)
check(mockCore.activeDeathEpitaph == nil, "When DEATH_EPITAPHS_ENABLED is false, no epitaph triggers")
check(#renderedTexts == 0, "When DEATH_EPITAPHS_ENABLED is false, no text rendered")
mockCore.DEATH_EPITAPHS_ENABLED = true

-- ===================== TEST 2: ENCYCLOPEDIA EXPANSION =====================
local initEncyclopedia = dofile("modules/compat_encyclopedia.lua")
check(type(initEncyclopedia) == "function", "modules/compat_encyclopedia.lua returns a loader function")
initEncyclopedia(mockCore)

-- Test Core.GetModChallengeInfo
check(type(mockCore.GetModChallengeInfo) == "function", "Core.GetModChallengeInfo exists")

local c1 = mockCore.GetModChallengeInfo(1)
check(c1 ~= nil and c1.Name == "In Brightest Day", "Challenge 1 info returns In Brightest Day")
check(c1.Character == "Hal Jordan", "Challenge 1 character is Hal Jordan")
check(c1.Goal:find("Mom's Heart", 1, true) ~= nil, "Challenge 1 goal is Mom's Heart")

local c2 = mockCore.GetModChallengeInfo(2)
check(c2 ~= nil and c2.Name == "Emerald Twilight", "Challenge 2 info returns Emerald Twilight")
check(c2.Character:find("Parallax", 1, true) ~= nil, "Challenge 2 character references Parallax")
check(c2.Goal:find("Satan", 1, true) ~= nil, "Challenge 2 goal is Satan")

local c3 = mockCore.GetModChallengeInfo(3)
check(c3 ~= nil and c3.Name == "Blackest Night", "Challenge 3 info returns Blackest Night")
check(c3.Goal:find("The Lamb", 1, true) ~= nil, "Challenge 3 goal is The Lamb")

local c4 = mockCore.GetModChallengeInfo(4)
check(c4 ~= nil and c4.Name == "Sinestro Corps War", "Challenge 4 info returns Sinestro Corps War")
check(c4.Goal:find("Mega Satan", 1, true) ~= nil, "Challenge 4 goal is Mega Satan")

-- Lookup by string
local cNamed = mockCore.GetModChallengeInfo("emerald twilight")
check(cNamed ~= nil and cNamed.ID == 2, "Core.GetModChallengeInfo handles case-insensitive name lookup")

local cInvalid = mockCore.GetModChallengeInfo(999)
check(cInvalid == nil, "Invalid challenge ID returns nil")

-- Test Encyclopedia Registration
mockCore.PLAYER_HAL = 10
mockCore.PLAYER_TAINTED_HAL = 11
mockCore.ITEM_POWER_BATTERY = 201
mockCore.ITEM_GIANT_FIST = 202
mockCore.ITEM_COAST_CITY = 203
mockCore.ITEM_GATLING = 204
mockCore.ITEM_SOLID_LIGHT_SHIELD = 205
mockCore.ITEM_POWER_RING = 206
mockCore.TRINKET_YELLOW_IMPURITY = 301

local encAddedCharacters = {}
local encAddedItems = {}
local encAddedTrinkets = {}
local encAddedChallenges = {}

Encyclopedia = {
    ItemPools = { POOL_SHOP = 1, POOL_TREASURE = 2, POOL_DEVIL = 3, POOL_ANGEL = 4, POOL_CURSE = 5, POOL_PLANETARIUM = 6 },
    AddCharacter = function(tbl) table.insert(encAddedCharacters, tbl) end,
    AddItem = function(tbl) table.insert(encAddedItems, tbl) end,
    AddTrinket = function(tbl) table.insert(encAddedTrinkets, tbl) end,
    AddChallenge = function(tbl) table.insert(encAddedChallenges, tbl) end,
}

mockCore.RegisterEncyclopedia()

check(#encAddedCharacters == 2, "Registered 2 characters in Encyclopedia (Hal Jordan and Parallax)")
check(#encAddedItems == 6, "Registered 6 items in Encyclopedia (" .. tostring(#encAddedItems) .. ")")
check(#encAddedTrinkets == 1, "Registered 1 trinket in Encyclopedia")
check(#encAddedChallenges == 4, "Registered all 4 DC challenges in Encyclopedia (" .. tostring(#encAddedChallenges) .. ")")

-- Verify item synergies and wiki descriptions
local foundRing, foundBattery, foundFist, foundShield = false, false, false, false
for _, it in ipairs(encAddedItems) do
    check(type(it.WikiDescription) == "string" and #it.WikiDescription > 0, "Item " .. it.Name .. " has WikiDescription")
    if it.ID == mockCore.ITEM_POWER_RING then
        foundRing = true
        check(type(it.Synergies) == "table" and #it.Synergies >= 4, "Power Ring has rich synergies (" .. tostring(#it.Synergies) .. ")")
    elseif it.ID == mockCore.ITEM_POWER_BATTERY then
        foundBattery = true
        check(type(it.Synergies) == "table" and #it.Synergies >= 2, "Power Battery has Car Battery synergy")
    elseif it.ID == mockCore.ITEM_GIANT_FIST then
        foundFist = true
        check(type(it.Synergies) == "table" and #it.Synergies >= 2, "Giant Fist has synergies")
    elseif it.ID == mockCore.ITEM_SOLID_LIGHT_SHIELD then
        foundShield = true
        check(type(it.Synergies) == "table" and #it.Synergies >= 2, "Solid Light Shield has synergies")
    end
end
check(foundRing and foundBattery and foundFist and foundShield, "All core constructs have registered synergies in Encyclopedia")

-- Verify MCM option exists in fx_mcm.lua
local mcmFile = io.open("modules/fx_mcm.lua", "r")
check(mcmFile ~= nil, "modules/fx_mcm.lua exists")
local mcmContent = mcmFile:read("*a")
mcmFile:close()
check(mcmContent:find("DEATH_EPITAPHS_ENABLED", 1, true) ~= nil, "DEATH_EPITAPHS_ENABLED option registered in fx_mcm.lua")

print(string.format("PASSED: %d, FAILED: %d", passes, failures))
if failures > 0 then
    os.exit(1)
end
