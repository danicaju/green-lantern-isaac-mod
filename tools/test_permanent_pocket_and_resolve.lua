-- tools/test_permanent_pocket_and_resolve.lua
-- Unit tests for permanent pocket active items, Active Combat Resolve (+2% hit / +10% kill), and Dual Battery Charging.

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- ===================== TEST 1: PLAYERS.XML POCKETACTIVE =====================
local fXml = assert(io.open("content/players.xml", "r"))
local srcXml = fXml:read("*a"); fXml:close()
check(srcXml:find('pocketActive=""') ~= nil, "players.xml: pocketActive is empty for custom HUD compatibility")
check(srcXml:find('pocketActive="Power Battery"') == nil, "players.xml: Hal Jordan does not use pocketActive attribute")

-- ===================== STUBS =====================
CollectibleType = {
    COLLECTIBLE_TAMMYS_HEAD = 38,
    COLLECTIBLE_D6 = 105,
}
PickupVariant = {
    PICKUP_LIL_BATTERY = 90,
}
EntityType = {
    ENTITY_PLAYER = 1,
    ENTITY_TEAR = 2,
    ENTITY_BOMB = 4,
    ENTITY_EFFECT = 1000,
}
ActiveSlot = {
    SLOT_PRIMARY = 0,
    SLOT_SECONDARY = 1,
    SLOT_POCKET = 2,
}
CacheFlag = {
    CACHE_FLYING = 1,
    CACHE_DAMAGE = 2,
    CACHE_SPEED = 4,
    CACHE_SHOTSPEED = 8,
    CACHE_TEARFLAG = 16,
    CACHE_FIREDELAY = 32,
}
SoundEffect = {
    SOUND_BATTERYCHARGE = 1,
}
ModCallbacks = {
    MC_POST_PLAYER_UPDATE = 1,
    MC_PRE_TEAR_COLLISION = 2,
    MC_POST_NPC_DEATH = 3,
    MC_PRE_PICKUP_COLLISION = 4,
}
Vector = {
    Zero = { X = 0, Y = 0 },
    new = function(x, y) return { X = x or 0, Y = y or 0 } end,
}
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })

Color = function(r, g, b, a, ro, go, bo)
    return { R = r, G = g, B = b, A = a, RO = ro or 0, GO = go or 0, BO = bo or 0 }
end
SFXManager = function() return { Play = function() end } end
Game = function() return {
    GetFrameCount = function() return 100 end,
    GetNumPlayers = function() return 1 end,
} end
EntityRef = function(e) return { Entity = e } end
Isaac = { GetPlayer = function(i) return nil end }

local Core = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    ITEM_POWER_BATTERY = 101,
    ITEM_COAST_CITY = 103,
    ITEM_POWER_RING = 105,
    WILLPOWER_MAX = 100.0,
    WILLPOWER_REBOOT_THRESHOLD = 20.0,
    WILLPOWER_PASSIVE_REBOOT_RATE = 0.085,
    WILLPOWER_KILL_REBOOT_BONUS = 10.0,
    WILLPOWER_DEPLETED_HIT_REBOOT = 2.0,
    IsHalJordan = function(p) return p._isHal == true end,
    IsTaintedHal = function(p) return p._isTHal == true end,
    IsRingActive = function(p) return p._ringActive ~= false end,
    GetPlayerData = function(p)
        p._data = p._data or {}
        return p._data
    end,
    RestoreHalRingPower = function(p, newW, text)
        local d = p._data or {}
        d.willpower = newW or 100.0
        d.ringDepleted = false
        d._lastStatus = text
    end,
    RefreshCharacterCostume = function() end,
    EnforceTaintedHalNoRedHearts = function() end,
    SetEntityScaleAndColor = function() end,
}

local function findCb(id)
    for _, c in ipairs(Core.GL._cbs) do
        if c.id == id then return c.fn end
    end
    return nil
end

local function loadModule(path)
    local f = assert(io.open(path, "r"))
    local src = f:read("*a"); f:close()
    src = src:gsub("|", "+")
    return assert(loadstring(src, path))()(Core)
end

loadModule("modules/player_update.lua")
loadModule("modules/beam_discrete.lua")
loadModule("modules/tainted_sparks.lua")
loadModule("modules/item_battery.lua")

local playerUpdateCb = findCb(ModCallbacks.MC_POST_PLAYER_UPDATE)
local preTearCollisionCb = findCb(ModCallbacks.MC_PRE_TEAR_COLLISION)
local npcDeathCb = findCb(ModCallbacks.MC_POST_NPC_DEATH)
local prePickupCb = findCb(ModCallbacks.MC_PRE_PICKUP_COLLISION)

check(playerUpdateCb ~= nil, "MC_POST_PLAYER_UPDATE registered")
check(preTearCollisionCb ~= nil, "MC_PRE_TEAR_COLLISION registered")
check(npcDeathCb ~= nil, "MC_POST_NPC_DEATH registered")
check(prePickupCb ~= nil, "MC_PRE_PICKUP_COLLISION registered")

-- ===================== TEST 2: PERMANENT POCKET ITEM RETENTION =====================
local activeSlots = { [0] = 0, [2] = 0 }
local addedCollectibles = {}
local pHal = {
    _isHal = true,
    _data = {
        initializedStartingItems = false,
        willpower = 100.0,
        ringDepleted = false,
    },
    GetPlayerType = function() return 0 end,
    GetSoulHearts = function() return 2 end,
    AddSoulHearts = function() end,
    HasCollectible = function(_, id) return id == Core.ITEM_POWER_RING end,
    GetActiveItem = function(_, slot) return activeSlots[slot] or 0 end,
    SetActiveCharge = function(_, c, slot) end,
    GetActiveCharge = function(_, slot) return 4 end,
    AddCollectible = function(self, id, charge, costume, slot)
        table.insert(addedCollectibles, { id = id, slot = slot })
    end,
    SetPocketActiveItem = function(self, id, slot, keepInPools)
        activeSlots[slot] = id
    end,
    FullCharge = function(self, slot, force) end,
    RemoveCollectible = function(self, id, _, slot)
        if activeSlots[slot] == id then activeSlots[slot] = 0 end
    end,
    AddCacheFlags = function() end,
    EvaluateItems = function() end,
    ToPlayer = function(self) return self end,
}

playerUpdateCb(nil, pHal)
check(activeSlots[ActiveSlot.SLOT_POCKET] == Core.ITEM_POWER_BATTERY, "Hal Jordan starting pocket slot contains Power Battery")
check(activeSlots[ActiveSlot.SLOT_PRIMARY] == nil or activeSlots[ActiveSlot.SLOT_PRIMARY] == 0, "Hal Jordan primary active slot is empty and ready for item pickups")

-- Now simulate Hal picking up The D6 in SLOT_PRIMARY
activeSlots[ActiveSlot.SLOT_PRIMARY] = CollectibleType.COLLECTIBLE_D6
playerUpdateCb(nil, pHal)
check(activeSlots[ActiveSlot.SLOT_PRIMARY] == CollectibleType.COLLECTIBLE_D6, "Hal Jordan holds The D6 in primary active slot")
check(activeSlots[ActiveSlot.SLOT_POCKET] == Core.ITEM_POWER_BATTERY, "Hal Jordan still retains Power Battery permanently in pocket slot (can hold 2 active items)")

-- ===================== TEST 3: ACTIVE COMBAT RESOLVE (+2% WILLPOWER PER HIT) =====================
pHal._data.ringDepleted = true
pHal._data.willpower = 10.0 -- depleted at 10%

local enemy = {
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
}
local normalTear = {
    SpawnerEntity = pHal,
    _data = {}, -- Normal tear (not a GL ring beam)
    GetData = function(s) return s._data end,
}

preTearCollisionCb(nil, normalTear, enemy, false)
check(pHal._data.willpower == 12.0, string.format("Depleted hit granted +2%% Willpower (current: %.1f%%)", pHal._data.willpower))
check(pHal._data.ringDepleted == true, "Ring remains depleted below 20% reboot threshold")

-- Second hit takes it to 14%
local tear2 = { SpawnerEntity = pHal, _data = {}, GetData = function(s) return s._data end }
preTearCollisionCb(nil, tear2, enemy, false)
check(pHal._data.willpower == 14.0, "Second hit takes Willpower to 14%")

-- Multiple hits to cross 20% reboot threshold
pHal._data.willpower = 19.0
local tearReboot = { SpawnerEntity = pHal, _data = {}, GetData = function(s) return s._data end }
preTearCollisionCb(nil, tearReboot, enemy, false)
check(pHal._data.ringDepleted == false, "Ring successfully rebooted upon reaching 21% Willpower!")
check(pHal._data._lastStatus == "RING REBOOTED!", "Reboot status text triggered")

-- ===================== TEST 4: KILL RESOLVE (+10% WILLPOWER PER KILL) =====================
pHal._data.ringDepleted = true
pHal._data.willpower = 5.0
Isaac.GetPlayer = function(i) return pHal end

local deadNpc = {
    IsEnemy = function() return true end,
    IsActiveEnemy = function() return true end,
    HasEntityFlags = function() return false end,
}
npcDeathCb(nil, deadNpc)
check(pHal._data.willpower == 15.0, string.format("Depleted kill granted +10%% Willpower (current: %.1f%%)", pHal._data.willpower))

-- Another kill crosses threshold and reboots
npcDeathCb(nil, deadNpc)
check(pHal._data.willpower >= 20.0 and pHal._data.ringDepleted == false, "Kill rebooted ring upon crossing 20% threshold!")

-- ===================== TEST 5: DUAL CHARGING FLOOR BATTERY =====================
pHal._data.willpower = 40.0
local primaryCharges = 1
pHal.GetActiveItem = function(_, slot) return slot == ActiveSlot.SLOT_PRIMARY and CollectibleType.COLLECTIBLE_D6 or 0 end
pHal.GetActiveCharge = function(_, slot) return primaryCharges end
pHal.GetActiveMaxCharge = function(_, slot) return 6 end
pHal.SetActiveCharge = function(_, c, slot) primaryCharges = c end

local pickupRemoved = false
local floorBattery = {
    Variant = PickupVariant.PICKUP_LIL_BATTERY,
    SubType = 1, -- Standard Lil Battery (+50 Willpower, +2 active charges)
    Remove = function() pickupRemoved = true end,
    PlayPickupSound = function() end,
}

prePickupCb(nil, floorBattery, pHal, false)
check(pHal._data.willpower == 90.0, string.format("Floor battery refilled Willpower to 90%% (was 40%%, got %.1f%%)", pHal._data.willpower))
check(primaryCharges == 3, string.format("Dual Charging: D6 charged by +2 bars (was 1, now %d)", primaryCharges))

-- Summary
print(string.format("test_permanent_pocket_and_resolve.lua: %d passed, %d failed", passes, failures))
if failures > 0 then
    os.exit(1)
end
