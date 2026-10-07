-- tools/test_car_battery_synergies.lua
-- Unit test for Car Battery active item synergies & save resilience with Birthright.
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
function RegisterMod(_name, _ver) return {
    AddCallback = function(self, id, fn)
        self._cbs = self._cbs or {}
        table.insert(self._cbs, { id = id, fn = fn })
    end,
    HasModData = function() return true end,
    LoadModData = function() return _savedModData or "" end,
    SaveModData = function(_, s) _savedModData = s end,
} end

CollectibleType = {
    COLLECTIBLE_CAR_BATTERY = 356,
    COLLECTIBLE_BIRTHRIGHT = 619,
}
CacheFlag = {
    CACHE_FIREDELAY = 1,
    CACHE_TEARFLAG = 2,
    CACHE_SHOTSPEED = 4,
    CACHE_DAMAGE = 8,
}
ModCallbacks = {
    MC_USE_ITEM = 1,
    MC_POST_PLAYER_UPDATE = 2,
    MC_POST_NEW_ROOM = 3,
    MC_PRE_GAME_EXIT = 4,
    MC_POST_GAME_STARTED = 5,
    MC_POST_NEW_LEVEL = 6,
}
Vector = function(x, y) return { X = x or 0, Y = y or 0 } end
Color = function(r, g, b, a) return { R = r, G = g, B = b, A = a } end
ActiveSlot = { SLOT_PRIMARY = 0 }
DamageFlag = { DAMAGE_NO_MODIFIERS = 0 }
EntityRef = function() return {} end
SoundEffect = {}
SFXManager = function() return { Play = function() end } end
Game = function() return {
    GetLevel = function() return { GetCurrentRoomIndex = function() return 0 end } end,
    GetFrameCount = function() return 100 end,
    GetRoom = function() return {} end,
    GetRoomEntities = function() return {} end,
    GetNumPlayers = function() return 1 end,
    ShakeScreen = function() end,
} end
Isaac = {
    GetRoomEntities = function() return {} end,
    Spawn = function() return { ToTear = function() return { GetData = function() return {} end } end, GetSprite = function() return { Color = {} } end } end,
    GetPlayer = function() return _testPlayer end,
    GetNumPlayers = function() return 1 end,
}

json = {
    encode = function(t)
        -- Mini JSON serializer for test
        local parts = {}
        for k, v in pairs(t) do
            local valStr
            if type(v) == "table" then
                valStr = json.encode(v)
            elseif type(v) == "boolean" then
                valStr = v and "true" or "false"
            elseif type(v) == "number" then
                valStr = tostring(v)
            else
                valStr = string.format("%q", tostring(v))
            end
            table.insert(parts, string.format("%q:%s", tostring(k), valStr))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end,
    decode = function(s)
        -- Mini JSON parser stub for structured test data
        local obj = { run = { ["0"] = {} }, oath = {} }
        if s:find('"birthrightInitialized":true') then
            obj.run["0"].birthrightInitialized = true
        end
        if s:find('"ringDepleted":true') then
            obj.run["0"].ringDepleted = true
        end
        local w = s:match('"willpower":([%d%.]+)')
        if w then obj.run["0"].willpower = tonumber(w) end
        local r = s:match('"stolenRings":([%d]+)')
        if r then obj.run["0"].stolenRings = tonumber(r) end
        return obj
    end,
}

local Core = dofile("modules/core.lua")
dofile("modules/ring_state.lua")(Core)
dofile("modules/birthright.lua")(Core)
dofile("modules/save_run.lua")(Core)

local function makePlayer(isHal, isTainted, hasCar, hasBR)
    local p = {
        Index = 0,
        _isHal = isHal,
        _isTainted = isTainted,
        HasCollectible = function(_, id)
            if id == 356 then return hasCar == true end
            if id == 619 then return hasBR == true end
            return false
        end,
        GetShootingInput = function() return { Length = function() return 1 end, Normalized = function() return { X = 1, Y = 0 } end } end,
        GetHeadDirection = function() return 3 end,
        Position = { X = 100, Y = 100 },
        Damage = 3.5,
        AddCacheFlags = function() end,
        EvaluateItems = function() end,
        AnimateHappy = function() end,
    }
    p.GetData = function()
        if not p._data then p._data = {} end
        return p._data
    end
    return p
end

Core.IsHalJordan = function(p) return p._isHal == true end
Core.IsTaintedHal = function(p) return p._isTainted == true end

-- 1. SAVE & CONTINUE RESILIENCE TEST
do
    local halBR = makePlayer(true, false, false, true)
    _testPlayer = halBR
    local data = Core.GetPlayerData(halBR)
    data.willpower = 145.0
    data.birthrightInitialized = true
    data.ringDepleted = false

    -- Trigger save
    for _, cb in ipairs(Core.GL._cbs) do
        if cb.id == ModCallbacks.MC_PRE_GAME_EXIT then cb.fn(nil) end
    end
    check(_savedModData ~= nil and #_savedModData > 0, "SaveModData wrote data")

    -- Wipe and restore with continue=true
    data.willpower = 0
    data.birthrightInitialized = false
    for _, cb in ipairs(Core.GL._cbs) do
        if cb.id == ModCallbacks.MC_POST_GAME_STARTED then cb.fn(nil, true) end
    end

    check(data.willpower == 145.0, "Willpower 145.0 preserved with Birthright without being clamped to 100")
    check(data.birthrightInitialized == true, "birthrightInitialized persisted across save/continue")
end

-- 2. CAR BATTERY GATLING EXTENSION TEST
do
    dofile("modules/item_gatling.lua")(Core)
    Core.ITEM_GATLING = 6
    local halCar = makePlayer(true, false, true, false)
    _testPlayer = halCar
    local data = Core.GetPlayerData(halCar)

    for _, cb in ipairs(Core.GL._cbs) do
        if cb.id == ModCallbacks.MC_USE_ITEM then
            cb.fn(nil, Core.ITEM_GATLING, nil, halCar, 0, 0, nil)
        end
    end
    check(data.gatlingTimer == 450, "Gatling timer with Car Battery extended to 450 frames (15s)")
end

-- 3. CAR BATTERY POWER BATTERY DUAL OVERCHARGE TEST
do
    dofile("modules/item_battery.lua")(Core)
    Core.ITEM_POWER_BATTERY = 1
    local halCar = makePlayer(true, false, true, false)
    _testPlayer = halCar
    local data = Core.GetPlayerData(halCar)
    data.willpower = 20.0 -- Below normal overcharge threshold

    for _, cb in ipairs(Core.GL._cbs) do
        if cb.id == ModCallbacks.MC_USE_ITEM then
            cb.fn(nil, Core.ITEM_POWER_BATTERY, nil, halCar, 0, 0, nil)
        end
    end
    check(data.overcharge == true, "Car Battery triggers Overcharge directly")
    check(data.overchargeTier == 2, "Car Battery pushes Hal into Overcharge Tier 2 (+25% DMG)")
end

io.stderr:write(string.format("\n[test_car_battery_synergies] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
