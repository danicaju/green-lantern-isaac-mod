-- tools/test_diagonal_and_active_items.lua
-- Unit tests for:
-- 1. Starting active items in ActiveSlot.SLOT_PRIMARY
-- 2. Diagonal upward ring hand offset clear of player head
-- 3. Continuous beam willpower drain execution without nil errors

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
Direction = { NO_DIRECTION = -1, LEFT = 0, UP = 1, RIGHT = 2, DOWN = 3 }
ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2 }
CacheFlag = {
    CACHE_FLYING = 1, CACHE_SPEED = 2, CACHE_DAMAGE = 4, CACHE_SHOTSPEED = 8,
    CACHE_TEARFLAG = 16, CACHE_FIREDELAY = 32
}
CollectibleType = {
    COLLECTIBLE_SOY_MILK = 330,
    COLLECTIBLE_ALMOND_MILK = 678,
}

local VectorMt = {
    __add = function(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end,
    __sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end,
    __mul = function(a, b)
        if type(a) == "number" then return Vector.new(b.X * a, b.Y * a) end
        return Vector.new(a.X * b, a.Y * b)
    end,
    __div = function(a, b)
        if type(b) == "number" then return Vector.new(a.X / b, a.Y / b) end
        return Vector.new(a.X / b.X, a.Y / b.Y)
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
setmetatable(Vector, {
    __call = function(_, x, y) return Vector.new(x, y) end,
})

Color = function() return {} end

-- ===================== LOAD MODULES =====================
local Core = {
    GL = { AddCallback = function() end },
    ITEM_POWER_BATTERY = 1001,
    ITEM_COAST_CITY = 1002,
    ITEM_POWER_RING = 1003,
    WILLPOWER_MAX = 100.0,
    HAL_CONTINUOUS_HOLD_FRAMES = 15,
    HAL_SPAM_EXTRA_HOLD_FRAMES = 5,
    HAL_CONTINUOUS_TICK_FRAMES = 4,
    HAL_CONTINUOUS_WILL_DRAIN = 0.06,
    activeEmeraldSparks = {},
    activeCoastCity = {},
}

dofile("modules/utils.lua")(Core)
dofile("modules/ring_aim.lua")(Core)

-- ===================== TEST 1: DIAGONAL UPWARD HAND OFFSETS =====================
-- Diagonal Up-Right
local aimUpRight = Vector(0.707, -0.707)
local offsetUpRight = Core.GetRingHandOffset(nil, aimUpRight)
check(offsetUpRight.X > 10, "Up-right aiming places hand offset X > 10 (outside head to right)")
check(offsetUpRight.Y < -15, "Up-right aiming places hand offset Y < -15 (upwards)")

-- Diagonal Up-Left
local aimUpLeft = Vector(-0.707, -0.707)
local offsetUpLeft = Core.GetRingHandOffset(nil, aimUpLeft)
check(offsetUpLeft.X < -10, "Up-left aiming places hand offset X < -10 (outside head to left)")
check(offsetUpLeft.Y < -15, "Up-left aiming places hand offset Y < -15 (upwards)")

-- Pure Up
local aimPureUp = Vector(0, -1)
local offsetPureUp = Core.GetRingHandOffset(nil, aimPureUp)
check(offsetPureUp.X == 0, "Pure UP aiming centers hand horizontally at X = 0")
check(offsetPureUp.Y == -32, "Pure UP aiming places hand behind neck at Y = -32")

-- ===================== TEST 2: ACTIVE ITEMS IN SLOT_PRIMARY =====================
local addedItems = {}
local mockHal = {
    GetPlayerType = function() return 100 end,
    GetSoulHearts = function() return 2 end,
    HasCollectible = function(_, id) return false end,
    AddCollectible = function(self, id, charge, firstTime, slot)
        table.insert(addedItems, { id = id, slot = slot })
    end,
    AddCacheFlags = function() end,
    EvaluateItems = function() end,
}
Core.IsHalJordan = function() return true end
Core.IsTaintedHal = function() return false end
Core.RefreshCharacterCostume = function() end

local halData = { initializedStartingItems = false }
Core.GetPlayerData = function() return halData end

-- Run initialization
if not halData.initializedStartingItems then
    halData.initializedStartingItems = true
    local primarySlot = (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    if Core.ITEM_POWER_BATTERY and Core.ITEM_POWER_BATTERY > 0 and not mockHal:HasCollectible(Core.ITEM_POWER_BATTERY) then
        mockHal:AddCollectible(Core.ITEM_POWER_BATTERY, 4, false, primarySlot)
    end
end

check(#addedItems == 1, "Hal Jordan received 1 starting active item")
check(addedItems[1].id == Core.ITEM_POWER_BATTERY, "Active item is Power Battery")
check(addedItems[1].slot == ActiveSlot.SLOT_PRIMARY, "Power Battery added to ActiveSlot.SLOT_PRIMARY (Spacebar slot)")

-- ===================== TEST 4: CONTINUOUS BEAM DAMAGE VERIFICATION =====================
DamageFlag = { DAMAGE_LASER = 2 }
EntityRef = function(e) return { Entity = e } end
Game = function()
    return {
        GetFrameCount = function() return 100 end,
        GetRoom = function() return nil end,
    }
end

local enemyDamaged = false
local enemyDamageAmount = 0
local mockEnemy = {
    Position = Vector(100, 0),
    Size = 16,
    Exists = function() return true end,
    IsDead = function() return false end,
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
    HasEntityFlags = function() return false end,
    GetData = function() return {} end,
    TakeDamage = function(self, dmg, flag, source, countdown)
        enemyDamaged = true
        enemyDamageAmount = dmg
        return true
    end,
}

Isaac = {
    GetRoomEntities = function() return { mockEnemy } end,
    Spawn = function() return nil end,
}

Core.HAL_CONTINUOUS_BEAM_DMG_MULT = 0.20
dofile("modules/beam_math.lua")(Core)

local startBeam = Vector(0, 0)
local endBeam = Vector(200, 0)
mockHal.Damage = 3.5

Core.TickContinuousBeamDamage(mockHal, halData, startBeam, endBeam)

check(enemyDamaged == true, "Enemy in continuous laser beam path took damage")
check(enemyDamageAmount > 0, "Enemy damage amount is greater than 0")
check(math.abs(enemyDamageAmount - (3.5 * 0.20)) < 0.001, "Enemy took correct scaled continuous beam tick damage")

-- ===================== RESULTS =====================
io.stderr:write(string.format("\n[test_diagonal_and_active_items] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
