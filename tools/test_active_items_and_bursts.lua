-- tools/test_active_items_and_bursts.lua
-- Unit tests for Tammy's Head 10-tear burst fix, Willpower dynamic regeneration, and pocket active items.

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- ===================== STUBS =====================
ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2 }
CollectibleType = { COLLECTIBLE_TAMMYS_HEAD = 38 }
CacheFlag = { CACHE_FLYING = 1, CACHE_DAMAGE = 2, CACHE_TEARFLAG = 4, CACHE_SPEED = 8, CACHE_SHOTSPEED = 16, CACHE_FIREDELAY = 32 }
TearFlags = { TEAR_SPECTRAL = 1, TEAR_PIERCING = 2, TEAR_FEAR = 4, TEAR_TRACTOR_BEAM = 8 }
EntityFlag = { FLAG_FEAR = 1 }
DamageFlag = { DAMAGE_NO_MODIFIERS = 0 }
ModCallbacks = {
    MC_POST_FIRE_TEAR = 1,
    MC_USE_ITEM = 2,
    MC_ENTITY_TAKE_DMG = 3,
    MC_POST_PLAYER_UPDATE = 4,
    MC_POST_NPC_DEATH = 5,
    MC_PRE_SPAWN_CLEAN_AWARD = 6,
    MC_PRE_PICKUP_COLLISION = 7,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_EFFECT = 1000 }
PickupVariant = { PICKUP_LIL_BATTERY = 90 }
EffectVariant = { WATER_SPLASH = 10 }
SoundEffect = { SOUND_BATTERYCHARGE = 1, SOUND_HELL_PORTAL2 = 2 }

local VectorMt = {
    __add = function(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end,
    __sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end,
    __mul = function(a, b)
        if type(a) == "number" then return Vector.new(b.X * a, b.Y * a) end
        return Vector.new(a.X * b, a.Y * b)
    end,
}
Vector = {
    Zero = { X = 0, Y = 0 },
    new = function(x, y)
        local v = { X = x or 0, Y = y or 0 }
        function v:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
        function v:Normalized()
            local l = self:Length()
            if l > 0.0001 then return Vector.new(self.X / l, self.Y / l) end
            return Vector.new(0, 0)
        end
        return setmetatable(v, VectorMt)
    end,
}
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })

Color = function(r, g, b, a, ro, go, bo) return { R = r, G = g, B = b, A = a } end
EntityRef = function(e) return { Entity = e } end
SFXManager = function() return { Play = function() end } end
Game = function() return {
    GetFrameCount = function() return 100 end,
    GetNumPlayers = function() return 1 end,
    GetRoomEntities = function() return {} end,
    GetLevel = function() return { GetCurrentRoomIndex = function() return 0 end } end,
} end
Isaac = {
    GetPlayer = function(i) return playerStub end,
    GetRoomEntities = function() return {} end,
    Spawn = function() return nil end,
}

-- ===================== TEST 1: TAMMY'S HEAD 10-TEAR BURST PRESERVATION =====================
local Core = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    IsHalJordan = function() return true end,
    IsTaintedHal = function() return false end,
    IsRingActive = function() return true end,
    CanUseContinuousBeam = function() return true end,
    HasTractorBeam = function() return false end,
    HasTearFlag = function(flags, flag) return (flags >= flag) end,
    GetRingHandOffset = function() return Vector(10, -5) end,
    GetRingBeamTearSpawnOffset = function() return Vector(12, -4) end,
    IsAimingUp = function() return false end,
    ApplyRingBeamSprite = function(tear, scale) tear._appliedSprite = true end,
    DISCRETE_BEAM_DMG_MULT = 0.35,
    WILLPOWER_MAX = 100.0,
    WILLPOWER_REBOOT_THRESHOLD = 25.0,
    WILLPOWER_PASSIVE_REBOOT_RATE = 0.5,
    WILLPOWER_KILL_REBOOT_BONUS = 3.0,
    WILLPOWER_ROOM_REBOOT_BONUS = 25.0,
    ITEM_POWER_BATTERY = 1001,
    ITEM_COAST_CITY = 1002,
    ITEM_POWER_RING = 1003,
}

local fDisc = assert(io.open("modules/beam_discrete.lua", "r"))
local srcDisc = fDisc:read("*a"); fDisc:close()
srcDisc = srcDisc:gsub("|", "+")
local chunkDisc = assert(loadstring(srcDisc, "modules/beam_discrete.lua"))
chunkDisc()(Core)

local function findCb(id)
    local list = {}
    for _, c in ipairs(Core.GL._cbs) do
        if c.id == id then table.insert(list, c.fn) end
    end
    return list
end

local postFireTearCb = findCb(ModCallbacks.MC_POST_FIRE_TEAR)[1]
local useItemCb = findCb(ModCallbacks.MC_USE_ITEM)[1]
check(postFireTearCb ~= nil, "MC_POST_FIRE_TEAR registered in beam_discrete")
check(useItemCb ~= nil, "MC_USE_ITEM registered in beam_discrete")

local halData = {
    allowingTapTear = false,
    isFiringContinuousBeam = false,
    willpower = 100,
}
local playerStub = {
    Position = Vector(100, 100),
    Damage = 10.0,
    ToPlayer = function(self) return self end,
}
Core.GetPlayerData = function(p) return halData end

-- 1. Simulate Tammy's Head activation (COLLECTIBLE_TAMMYS_HEAD = 38)
useItemCb(nil, 38, nil, playerStub, 0, 0, 0)
check(halData.itemTearBurstFrame == 100, "Tammy's Head records itemTearBurstFrame = 100")

-- 2. Fire 10 radial tears from Tammy's Head
local firedTears = {}
for i = 1, 10 do
    local angle = (i - 1) * (360 / 10)
    local rad = math.rad(angle)
    local dir = Vector(math.cos(rad), math.sin(rad))
    local tearData = {}
    local tearObj = {
        Type = EntityType.ENTITY_TEAR,
        SpawnerEntity = playerStub,
        Position = Vector(100, 100),
        Velocity = dir * 10.0,
        TearFlags = 0,
        CollisionDamage = 35.0, -- Tammy's head +25 base damage
        Scale = 1.0,
        Visible = true,
        _removed = false,
        _data = tearData,
        GetData = function(self) return self._data end,
        GetSprite = function() return { Color = nil } end,
        Remove = function(self) self._removed = true end,
    }
    postFireTearCb(nil, tearObj)
    table.insert(firedTears, tearObj)
end

-- 3. Verify all 10 tears survived without being removed
local removedCount = 0
for _, t in ipairs(firedTears) do
    if t._removed then removedCount = removedCount + 1 end
end
check(removedCount == 0, "Tammy's Head: all 10 burst tears SURVIVED (0 removed)")
check(firedTears[1].CollisionDamage == 35.0, "Tammy's Head: burst tear preserved full damage (not reduced by 0.35x)")
check(firedTears[1]._appliedSprite == true, "Tammy's Head: tears received emerald ring beam sprite")
check((firedTears[1].TearFlags + 0) > 0, "Tammy's Head: tears received piercing/spectral flags")

-- ===================== TEST 2: NO TIME-BASED WILLPOWER REGENERATION =====================
-- Out-of-combat test: Willpower must NOT increase passively over time when resting / not shooting
local fUpdate = assert(io.open("modules/player_update.lua", "r"))
local srcUpdate = fUpdate:read("*a"); fUpdate:close()
srcUpdate = srcUpdate:gsub("|", "+")
local chunkUpdate = assert(loadstring(srcUpdate, "modules/player_update.lua"))
chunkUpdate()(Core)

local postPlayerUpdateCb = findCb(ModCallbacks.MC_POST_PLAYER_UPDATE)[1]
check(postPlayerUpdateCb ~= nil, "MC_POST_PLAYER_UPDATE registered")

-- Player resting (not shooting for >60 frames)
halData.willpower = 40.0
halData.lastSmallBeamFrame = 20 -- last shot at frame 20, current frame is 100 (diff = 80 > 60)
halData.isFiringContinuousBeam = false
halData.ringDepleted = false
Core.GetMaxWillpower = function() return 100.0 end
Core.RestoreHalRingPower = function(p, w) halData.willpower = w end
Core.EnforceTaintedHalNoRedHearts = function() end

playerStub.GetPlayerType = function() return 100 end
playerStub.GetSoulHearts = function() return 2 end
playerStub.HasCollectible = function() return true end

postPlayerUpdateCb(nil, playerStub)
check(halData.willpower == 40.0, "No time-based regen: Hal Jordan willpower stays unchanged when resting (" .. tostring(halData.willpower) .. " == 40.0)")

-- ===================== TEST 3: ACTIVE ITEM WILLPOWER SURGE =====================
local fBatt = assert(io.open("modules/item_battery.lua", "r"))
local srcBatt = fBatt:read("*a"); fBatt:close()
srcBatt = srcBatt:gsub("|", "+")
local chunkBatt = assert(loadstring(srcBatt, "modules/item_battery.lua"))
chunkBatt()(Core)

local batteryUseItemCbs = findCb(ModCallbacks.MC_USE_ITEM)
local anyActiveUseCb = batteryUseItemCbs[#batteryUseItemCbs] -- last registered MC_USE_ITEM in item_battery

halData.willpower = 50.0
-- Player activates D6 (itemID = 105) instead of Power Battery
anyActiveUseCb(nil, 105, nil, playerStub, 0, 0, 0)
check(halData.willpower == 70.0, "Using any active item (D6) grants +20 Willpower surge (50 -> 70)")

-- ===================== TEST 4: ROOM CLEAR & ENEMY KILL WILLPOWER REWARDS =====================
local fSparks = assert(io.open("modules/tainted_sparks.lua", "r"))
local srcSparks = fSparks:read("*a"); fSparks:close()
srcSparks = srcSparks:gsub("|", "+")
local chunkSparks = assert(loadstring(srcSparks, "modules/tainted_sparks.lua"))
chunkSparks()(Core)

local killCb = findCb(ModCallbacks.MC_POST_NPC_DEATH)[1]
local cleanAwardCb = findCb(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD)[1]

-- Normal enemy kill grants +1 Willpower
halData.willpower = 60.0
local enemyNpc = {
    Position = Vector(150, 150),
    IsEnemy = function() return true end,
    IsActiveEnemy = function() return true end,
    MaxHitPoints = 20,
    HasEntityFlags = function() return false end,
}
killCb(nil, enemyNpc)
check(halData.willpower == 61.0, "Killing an enemy grants +1.0 Willpower (60 -> 61)")

-- Room clear grants +20 Willpower
cleanAwardCb(nil)
check(halData.willpower == 81.0, "Clearing a room grants +20.0 Willpower (61 -> 81)")

-- ===================== TEST 5: TAINTED HAL ACTIVE ITEM SPARK SYNERGY =====================
local tHalData = { emeraldSparks = 25.0 }
local tPlayerStub = {
    Position = Vector(100, 100),
    Damage = 12.0,
    ToPlayer = function(self) return self end,
}
Core.IsHalJordan = function() return false end
Core.IsTaintedHal = function(p) return p == tPlayerStub end
Core.GetPlayerData = function(p) return tHalData end

-- Find tainted active item callback
local tActiveCb = findCb(ModCallbacks.MC_USE_ITEM)[#findCb(ModCallbacks.MC_USE_ITEM)]
tActiveCb(nil, 38, nil, tPlayerStub, 0, 0, 0) -- use Tammy's Head on Tainted Hal
check(tHalData.emeraldSparks == 10.0, "Tainted Hal: using active item consumed 15 emerald sparks (25 -> 10)")

-- ===================== TEST 6: POCKET ACTIVE INITIALIZATION =====================
local addedItems = {}
local mockPlayer = {
    GetPlayerType = function() return 100 end,
    GetSoulHearts = function() return 2 end,
    HasCollectible = function(_, id) return false end,
    AddCollectible = function(self, id, charge, firstTime, slot)
        table.insert(addedItems, { id = id, slot = slot })
    end,
    SetPocketActiveItem = function(self, id, slot, keep)
        table.insert(addedItems, { id = id, slot = slot })
    end,
    FullCharge = function() end,
    AddCacheFlags = function() end,
    EvaluateItems = function() end,
}
Core.IsHalJordan = function() return true end
Core.IsTaintedHal = function() return false end
halData.initializedStartingItems = false
Core.GetPlayerData = function() return halData end

postPlayerUpdateCb(nil, mockPlayer)
local hasPocketBattery = false
for _, item in ipairs(addedItems) do
    if item.id == Core.ITEM_POWER_BATTERY and item.slot == ActiveSlot.SLOT_POCKET then
        hasPocketBattery = true
        break
    end
end
check(hasPocketBattery == true, "Hal Jordan receives Power Battery in ActiveSlot.SLOT_POCKET (Pocket slot)")

print(string.format("\n[test_active_items_and_bursts] passes=%d failures=%d", passes, failures))
if failures > 0 then os.exit(1) end
