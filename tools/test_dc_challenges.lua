-- tools/test_dc_challenges.lua
-- Unit tests for DC-themed challenges (In Brightest Day, Emerald Twilight, Blackest Night, Sinestro Corps War)

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- ===================== TEST 1: CONTENT/CHALLENGES.XML =====================
local f = io.open("content/challenges.xml", "r")
check(f ~= nil, "content/challenges.xml exists")
local content = f:read("*a")
f:close()

check(content:find('name="In Brightest Day"', 1, true) ~= nil, "In Brightest Day defined in XML")
check(content:find('name="Emerald Twilight"', 1, true) ~= nil, "Emerald Twilight defined in XML")
check(content:find('name="Blackest Night"', 1, true) ~= nil, "Blackest Night defined in XML")
check(content:find('name="Sinestro Corps War"', 1, true) ~= nil, "Sinestro Corps War defined in XML")
check(content:find('canshoot="false"', 1, true) ~= nil, "Blindfold canshoot=false defined")
check(content:find('getcurse="9"', 1, true) ~= nil, "Blackest Night curse bitmask defined")
check(content:find('megasatan="true"', 1, true) ~= nil, "Sinestro Corps War megasatan defined")

-- ===================== TEST 2: LUA CHALLENGE LOGIC =====================
local callbacks = {}
local mockGL = {
    AddCallback = function(self, id, fn)
        callbacks[id] = fn
    end
}

ModCallbacks = {
    MC_POST_GAME_STARTED = 1,
    MC_POST_NEW_LEVEL = 2,
    MC_PRE_SPAWN_CLEAN_AWARD = 3,
    MC_POST_ENTITY_KILL = 4,
}

local mockCore = {
    GL = mockGL,
    PLAYER_HAL = 10,
    PLAYER_TAINTED_HAL = 11,
    ITEM_SOLID_LIGHT_SHIELD = 101,
    ITEM_GIANT_FIST = 102,
    ITEM_POWER_BATTERY = 103,
    ITEM_COAST_CITY = 104,
    TRINKET_YELLOW_IMPURITY = 501,
    WILLPOWER_MAX = 100,
    MAX_STOLEN_RINGS = 10,
    LoadItemIDs = function() end,
    GetPlayerData = function(p) return p._data end,
}

local function makePlayer(pType)
    local p = {
        _type = pType or 0,
        _items = {},
        _trinkets = {},
        _soulHearts = 0,
        _activeCharge = { [0] = 0, [1] = 0, [2] = 0 },
        _data = {},
        CanShoot = true,
        GetPlayerType = function(s) return s._type end,
        ChangePlayerType = function(s, t) s._type = t end,
        HasCollectible = function(s, id) return s._items[id] == true end,
        AddCollectible = function(s, id, charge, touch) s._items[id] = true end,
        HasTrinket = function(s, id) return s._trinkets[id] == true end,
        AddTrinket = function(s, id) s._trinkets[id] = true end,
        GetSoulHearts = function(s) return s._soulHearts end,
        AddSoulHearts = function(s, h) s._soulHearts = s._soulHearts + h end,
        GetActiveItem = function(s, slot) return slot == 0 and 102 or (slot == 2 and s._pocketItem or 0) end,
        SetPocketActiveItem = function(s, id, slot, active) s._items[id] = true; s._pocketItem = id end,
        FullCharge = function(s, slot, force) end,
        AddBlackHearts = function(s, h) s._soulHearts = s._soulHearts + h end,
        NeedsCharge = function(s, slot) return true end,
        GetActiveCharge = function(s, slot) return s._activeCharge[slot] or 0 end,
        SetActiveCharge = function(s, c, slot) s._activeCharge[slot] = c end,
    }
    return p
end

local activeChallenge = 0
local activeStage = 1
local addedCurses = 0

Isaac = {
    GetChallenge = function() return activeChallenge end,
    GetChallengeIdByName = function(name)
        if name == "In Brightest Day" then return 1
        elseif name == "Emerald Twilight" then return 2
        elseif name == "Blackest Night" then return 3
        elseif name == "Sinestro Corps War" then return 4
        end
        return -1
    end,
    GetPlayer = function(i) return mockPlayer end,
}

Game = function()
    return {
        GetNumPlayers = function() return 1 end,
        GetLevel = function()
            return {
                GetStage = function() return activeStage end,
                AddCurse = function(_, c) addedCurses = c end,
            }
        end,
    }
end

-- Load module
dofile("modules/challenges.lua")(mockCore)

local postGameStartedCb = callbacks[ModCallbacks.MC_POST_GAME_STARTED]
local postNewLevelCb = callbacks[ModCallbacks.MC_POST_NEW_LEVEL]
local preCleanAwardCb = callbacks[ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD]

check(postGameStartedCb ~= nil, "MC_POST_GAME_STARTED registered")
check(postNewLevelCb ~= nil, "MC_POST_NEW_LEVEL registered")
check(preCleanAwardCb ~= nil, "MC_PRE_SPAWN_CLEAN_AWARD registered")

-- Test Challenge 1: In Brightest Day
activeChallenge = 1
mockPlayer = makePlayer(0)
postGameStartedCb(nil, false)
check(mockPlayer:GetPlayerType() == mockCore.PLAYER_HAL, "In Brightest Day sets Hal Jordan")
check(mockPlayer.CanShoot == false, "In Brightest Day sets blindfold (CanShoot = false)")
check(mockPlayer:HasCollectible(mockCore.ITEM_SOLID_LIGHT_SHIELD), "In Brightest Day grants Solid Light Shield")
check(mockPlayer:HasCollectible(mockCore.ITEM_GIANT_FIST), "In Brightest Day grants Giant Fist")
check(mockPlayer:HasCollectible(mockCore.ITEM_POWER_BATTERY), "In Brightest Day grants Power Battery")
check(mockPlayer._data.oathText:find("IN BRIGHTEST DAY") ~= nil, "In Brightest Day oath text set")

check(mockPlayer._data.willpower == mockCore.WILLPOWER_MAX, "In Brightest Day initializes Willpower to max")
check(mockPlayer._pocketItem == mockCore.ITEM_POWER_BATTERY, "In Brightest Day puts Power Battery in pocket item slot")

-- Floor advance in Challenge 1 preserves blindfold
mockPlayer.CanShoot = true
activeStage = 2
postNewLevelCb(nil)
check(mockPlayer.CanShoot == false, "In Brightest Day re-enforces blindfold on floor advance")

-- Test room clear bonus in Challenge 1
mockPlayer._data.willpower = 40
mockPlayer._activeCharge[0] = 0
preCleanAwardCb(nil)
check(mockPlayer._data.willpower == 65, "In Brightest Day grants +25 Willpower on room clear")
check(mockPlayer._activeCharge[0] == 2, "In Brightest Day grants +2 active item charges on room clear")

-- Test Challenge 2: Emerald Twilight
activeChallenge = 2
mockPlayer = makePlayer(0)
postGameStartedCb(nil, false)
check(mockPlayer:GetPlayerType() == mockCore.PLAYER_HAL, "Emerald Twilight starts as Hal Jordan")
check(mockPlayer:HasCollectible(mockCore.ITEM_COAST_CITY), "Emerald Twilight grants Coast City")
check(mockPlayer._pocketItem == mockCore.ITEM_POWER_BATTERY, "Emerald Twilight grants Power Battery in pocket slot")
check(mockPlayer._data.stolenRings == 1, "Emerald Twilight starts with 1 Stolen Ring")
check(mockPlayer._data.oathText:find("EMERALD TWILIGHT") ~= nil, "Emerald Twilight oath set")

-- Floor transitions in Emerald Twilight
activeStage = 2
postNewLevelCb(nil)
check(mockPlayer._data.stolenRings == 3, "Emerald Twilight adds +2 Stolen Rings on floor advance")

activeStage = 9
postNewLevelCb(nil)
check(mockPlayer:GetPlayerType() == mockCore.PLAYER_TAINTED_HAL, "Emerald Twilight transforms into Parallax in late game (Stage 9+)")
check(mockPlayer._pocketItem == mockCore.ITEM_COAST_CITY, "Emerald Twilight Parallax transition grants Coast City pocket")
check(mockPlayer._data.oathText:find("PARALLAX") ~= nil, "Parallax transformation oath set")

-- Test Challenge 3: Blackest Night
activeChallenge = 3
mockPlayer = makePlayer(0)
addedCurses = 0
postGameStartedCb(nil, false)
check(mockPlayer:GetPlayerType() == mockCore.PLAYER_TAINTED_HAL, "Blackest Night sets Tainted Hal")
check(mockPlayer:HasCollectible(mockCore.ITEM_COAST_CITY), "Blackest Night grants Coast City")
check(mockPlayer._pocketItem == mockCore.ITEM_COAST_CITY, "Blackest Night puts Coast City in pocket slot")
check(mockPlayer:HasTrinket(mockCore.TRINKET_YELLOW_IMPURITY), "Blackest Night grants Yellow Impurity")
check(mockPlayer._soulHearts >= 6, "Blackest Night gives starting black hearts")
check(mockPlayer._data.oathText:find("BLACKEST NIGHT") ~= nil, "Blackest Night oath set")

postNewLevelCb(nil)
check(addedCurses == 9, "Blackest Night forces Curse of Darkness + Unknown (1 + 8 = 9)")

-- Test Challenge 4: Sinestro Corps War
activeChallenge = 4
mockPlayer = makePlayer(0)
addedCurses = 0
postGameStartedCb(nil, false)
check(mockPlayer:GetPlayerType() == mockCore.PLAYER_HAL, "Sinestro Corps War sets Hal Jordan")
check(mockPlayer:HasTrinket(mockCore.TRINKET_YELLOW_IMPURITY), "Sinestro Corps War grants Yellow Impurity")
check(mockPlayer._pocketItem == mockCore.ITEM_POWER_BATTERY, "Sinestro Corps War puts Power Battery in pocket slot")
check(mockPlayer._data.willpower == mockCore.WILLPOWER_MAX, "Sinestro Corps War initializes Willpower to max")
check(mockPlayer._data.oathText:find("NO EVIL SHALL ESCAPE") ~= nil, "Sinestro Corps War oath set")

postNewLevelCb(nil)
check(addedCurses == 1, "Sinestro Corps War forces Curse of Darkness (1)")

io.stderr:write(string.format("\n[test_dc_challenges] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
