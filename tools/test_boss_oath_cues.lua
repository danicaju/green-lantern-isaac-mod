-- tools/test_boss_oath_cues.lua
-- Unit test for Boss Room Dramatic Battle Oath Cues.
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
function RegisterMod(_name, _ver)
    return {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    }
end

ModCallbacks = {
    MC_POST_NEW_ROOM = 1,
}

RoomType = {
    ROOM_DEFAULT = 1,
    ROOM_BOSS = 5,
    ROOM_BOSSRUSH = 14,
}

EntityType = {
    ENTITY_EFFECT = 1000,
}

EffectVariant = {
    HALO = 1,
}

SoundEffect = {
    SOUND_SUPERHOLY = 10,
    SOUND_HELL_PORTAL2 = 20,
}

SFXManager = function()
    return {
        Play = function() end,
    }
end

local _currentRoom = {
    _type = RoomType.ROOM_BOSS,
    _clear = false,
    GetType = function(self) return self._type end,
    IsClear = function(self) return self._clear end,
}

local _screenShakeCalled = false
Game = function()
    return {
        GetNumPlayers = function() return 1 end,
        GetRoom = function() return _currentRoom end,
        GetLevel = function() return { GetCurrentRoomIndex = function() return 10 end } end,
        ShakeScreen = function(_, amt) _screenShakeCalled = true end,
    }
end

local _testPlayer = nil
Isaac = {
    GetPlayer = function() return _testPlayer end,
    GetNumPlayers = function() return 1 end,
    Spawn = function() return nil end,
    FindByType = function() return {} end,
}

Vector = setmetatable({ Zero = { X = 0, Y = 0 } }, {
    __call = function(_, x, y) return { X = x or 0, Y = y or 0 } end
})
Color = function(r, g, b, a) return { R = r, G = g, B = b, A = a } end

local Core = dofile("modules/core.lua")
check(Core.BOSS_OATH_CUES_ENABLED == true, "Core.BOSS_OATH_CUES_ENABLED default true")

local function makePlayer(isHal, isTainted)
    local p = {
        Index = 0,
        Position = { X = 100, Y = 100 },
        _isHal = isHal,
        _isTainted = isTainted,
        AddCacheFlags = function() end,
        EvaluateItems = function() end,
    }
    p.GetData = function()
        if not p._data then p._data = {} end
        return p._data
    end
    return p
end

Core.IsHalJordan = function(p) return p._isHal == true end
Core.IsTaintedHal = function(p) return p._isTainted == true end

dofile("modules/room_reset.lua")(Core)

local function triggerNewRoom()
    for _, cb in ipairs(Core.GL._cbs) do
        if cb.id == ModCallbacks.MC_POST_NEW_ROOM then
            cb.fn(nil)
        end
    end
end

-- 1. Hal Jordan entering uncleared Boss Room
do
    local hal = makePlayer(true, false)
    _testPlayer = hal
    _currentRoom._type = RoomType.ROOM_BOSS
    _currentRoom._clear = false
    _screenShakeCalled = false

    triggerNewRoom()

    local data = Core.GetPlayerData(hal)
    check(data.oathText == "NO EVIL SHALL ESCAPE MY SIGHT!", "Hal receives iconic battle oath in boss room")
    check(data.ringFlareTimer == 30, "Ring flares for 30 frames in boss room")
    check(data.oathTextTimer == 110, "Oath text timer initialized to 110 frames")
    check(_screenShakeCalled == true, "Dramatic screen shake triggered")
end

-- 2. Parallax (Tainted Hal) entering uncleared Boss Room
do
    local tainted = makePlayer(false, true)
    _testPlayer = tainted
    _currentRoom._type = RoomType.ROOM_BOSS
    _currentRoom._clear = false

    triggerNewRoom()

    local data = Core.GetPlayerData(tainted)
    check(data.oathText == "FEAR THE LIGHT OF PARALLAX!", "Parallax receives battle oath in boss room")
    check(data.ringFlareTimer == 30, "Parallax ring flares for 30 frames in boss room")
    check(data.oathTextTimer == 110, "Parallax oath text timer initialized to 110 frames")
end

-- 3. Hal Jordan entering CLEARED Boss Room does NOT trigger
do
    local hal = makePlayer(true, false)
    _testPlayer = hal
    _currentRoom._type = RoomType.ROOM_BOSS
    _currentRoom._clear = true
    local data = Core.GetPlayerData(hal)
    data.oathText = nil
    data.ringFlareTimer = 0

    triggerNewRoom()

    check(data.oathText == nil, "Cleared boss room does not trigger dramatic oath")
    check(data.ringFlareTimer == 0, "Cleared boss room does not trigger ring flare")
end

-- 4. Hal Jordan entering non-boss room does NOT trigger
do
    local hal = makePlayer(true, false)
    _testPlayer = hal
    _currentRoom._type = RoomType.ROOM_DEFAULT
    _currentRoom._clear = false
    local data = Core.GetPlayerData(hal)
    data.oathText = nil
    data.ringFlareTimer = 0

    triggerNewRoom()

    check(data.oathText == nil, "Normal room does not trigger dramatic oath")
    check(data.ringFlareTimer == 0, "Normal room does not trigger ring flare")
end

-- 5. Disabling BOSS_OATH_CUES_ENABLED prevents cues
do
    Core.BOSS_OATH_CUES_ENABLED = false
    local hal = makePlayer(true, false)
    _testPlayer = hal
    _currentRoom._type = RoomType.ROOM_BOSS
    _currentRoom._clear = false
    local data = Core.GetPlayerData(hal)
    data.oathText = nil

    triggerNewRoom()

    check(data.oathText == nil, "MCM option BOSS_OATH_CUES_ENABLED = false disables oath cues")
    Core.BOSS_OATH_CUES_ENABLED = true
end

io.stderr:write(string.format("\n[test_boss_oath_cues] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
