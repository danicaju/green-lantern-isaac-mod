-- tools/test_new_synergies.lua
-- Unit tests for Book of Virtues, BFFS!, Golden Trinket / Mom's Box, and Encyclopedia.
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
CollectibleType = {
    COLLECTIBLE_CAR_BATTERY = 356,
    COLLECTIBLE_BOOK_OF_VIRTUES = 584,
    COLLECTIBLE_BFFS = 247,
    COLLECTIBLE_MOMS_BOX = 439,
    COLLECTIBLE_LUDOVICO_TECHNIQUE = 316,
    COLLECTIBLE_EPIC_FETUS = 168,
}
EntityType = {
    ENTITY_PLAYER = 1,
    ENTITY_TEAR = 2,
    ENTITY_FAMILIAR = 3,
    ENTITY_BOMB = 4,
    ENTITY_PICKUP = 5,
    ENTITY_EFFECT = 1000,
}
FamiliarVariant = { WISP = 239 }
PickupVariant = { PICKUP_LIL_BATTERY = 90 }
EffectVariant = {
    HALO = 10,
    WATER_SPLASH = 20,
    TARGET = 30,
    ROCKET = 31,
    SMOKE_CLOUD = 141,
}
TearVariant = { DEFAULT = 0 }
TearFlags = {
    TEAR_SPECTRAL = 1,
    TEAR_PIERCING = 2,
    TEAR_FEAR = 4,
}
CacheFlag = { CACHE_DAMAGE = 8 }
ModCallbacks = {
    MC_FAMILIAR_INIT = 1,
    MC_FAMILIAR_UPDATE = 2,
    MC_POST_FIRE_TEAR = 3,
    MC_POST_ENTITY_KILL = 4,
    MC_USE_ITEM = 5,
    MC_EVALUATE_CACHE = 6,
    MC_POST_GAME_STARTED = 7,
    MC_PRE_PICKUP_COLLISION = 8,
    MC_POST_LASER_INIT = 9,
    MC_POST_LASER_UPDATE = 10,
    MC_POST_KNIFE_UPDATE = 11,
    MC_POST_EFFECT_INIT = 12,
    MC_POST_EFFECT_UPDATE = 13,
    MC_POST_BOMB_INIT = 14,
    MC_POST_BOMB_UPDATE = 15,
    MC_POST_ENTITY_REMOVE = 16,
    MC_POST_TEAR_UPDATE = 17,
}
DamageFlag = { DAMAGE_NO_MODIFIERS = 0 }
Vector = {
    Zero = { X = 0, Y = 0 },
    new = function(x, y) return { X = x or 0, Y = y or 0 } end,
}
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })

Color = function(r, g, b, a, ro, go, bo)
    return { R = r, G = g, B = b, A = a }
end
EntityRef = function(e) return { Entity = e } end
SFXManager = function() return { Play = function() end } end
Game = function() return {
    GetLevel = function() return { GetCurrentRoomIndex = function() return 0 end } end,
    GetFrameCount = function() return 90 end,
    GetRoomEntities = function() return {} end,
} end
Isaac = {
    Spawn = function() return nil end,
    FindByType = function() return {} end,
    GetRoomEntities = function() return {} end,
    WorldToScreen = function(v) return v end,
}

-- ===================== TEST 1: BOOK OF VIRTUES WISPS =====================
local Core = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    ITEM_POWER_BATTERY = 101,
    ITEM_GIANT_FIST = 102,
    ITEM_COAST_CITY = 103,
    ITEM_GATLING = 104,
    ApplyRingBeamSprite = function(tear, scale)
        tear._styled = true
        tear._beamScale = scale
    end,
}

dofile("modules/synergies_virtues.lua")(Core)

local function findCb(id)
    for _, c in ipairs(Core.GL._cbs) do
        if c.id == id then return c.fn end
    end
end

local famInitCb = findCb(ModCallbacks.MC_FAMILIAR_INIT)
check(famInitCb ~= nil, "Virtues: MC_FAMILIAR_INIT registered")

-- Test Power Battery Wisp
local spr1 = { Color = nil }
local wisp1 = {
    Type = EntityType.ENTITY_FAMILIAR,
    Variant = 239,
    SubType = 101,
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return spr1 end,
    MaxHitPoints = 2,
    HitPoints = 2,
}
famInitCb(nil, wisp1)
check(wisp1:GetData().isGLWisp == true, "Virtues: Power Battery wisp marked isGLWisp")
check(wisp1.MaxHitPoints == 6.0, "Virtues: Power Battery wisp has 6 HP")

-- Test Giant Fist Wisp
local spr2 = { Color = nil }
local wisp2 = {
    Type = EntityType.ENTITY_FAMILIAR,
    Variant = 239,
    SubType = 102,
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return spr2 end,
    Scale = 1.0,
    MaxHitPoints = 2,
    HitPoints = 2,
}
famInitCb(nil, wisp2)
check(wisp2.Scale == 1.30, "Virtues: Giant Fist wisp has 1.30 scale")
check(wisp2.MaxHitPoints == 8.0, "Virtues: Giant Fist wisp has 8 HP")

-- Test Wisp Firing Tear
local fireTearCb = findCb(ModCallbacks.MC_POST_FIRE_TEAR)
local tearEnt = {
    SpawnerEntity = wisp1,
    TearFlags = 0,
    Visible = true,
    GetSprite = function() return { Color = {} } end,
}
fireTearCb(nil, tearEnt)
check(tearEnt._styled == true, "Virtues: tear styled with ApplyRingBeamSprite")
check(tearEnt.Visible == false, "Virtues: vanilla tear hidden")

-- ===================== TEST 2: YELLOW IMPURITY SCALING =====================
local testStatsData = {}
local statsCore = {
    GL = { AddCallback = function(self, id, fn) self._fn = fn end },
    TRINKET_YELLOW_IMPURITY = 201,
    GetPlayerData = function() return testStatsData end,
    IsHalJordan = function() return false end,
    IsTaintedHal = function() return false end,
    HasGreenLanternRing = function() return false end,
}
local sf = io.open("modules/stats.lua", "r")
local statsSrc = sf and sf:read("*a") or ""
if sf then sf:close() end
local statsFactory = assert(loadstring(statsSrc:gsub("|", "+"), "stats.lua"))()
statsFactory(statsCore)
local statsCb = statsCore.GL._fn

local function makePlayerWithTrinketMult(multiplier)
    return {
        Damage = 10.0,
        HasTrinket = function(_, id) return id == 201 end,
        GetTrinketMultiplier = function() return multiplier end,
    }
end

-- Normal trinket (1x) -> 1.50x DMG
local p1 = makePlayerWithTrinketMult(1)
statsCb(nil, p1, CacheFlag.CACHE_DAMAGE)
check(math.abs(p1.Damage - 15.0) < 0.001, "Yellow Impurity: mult 1 grants 1.50x DMG (15.0)")

-- Golden or Mom's Box (2x) -> 1.75x DMG
local p2 = makePlayerWithTrinketMult(2)
statsCb(nil, p2, CacheFlag.CACHE_DAMAGE)
check(math.abs(p2.Damage - 17.5) < 0.001, "Yellow Impurity: mult 2 grants 1.75x DMG (17.5)")

-- Golden + Mom's Box (3x) -> 2.00x DMG
local p3 = makePlayerWithTrinketMult(3)
statsCb(nil, p3, CacheFlag.CACHE_DAMAGE)
check(math.abs(p3.Damage - 20.0) < 0.001, "Yellow Impurity: mult 3 grants 2.00x DMG (20.0)")

-- ===================== TEST 3: CAR BATTERY OVERCHARGE NON-HAL =====================
local battCore = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn) self._cbs[id] = fn end,
    },
    ITEM_POWER_BATTERY = 301,
    LoadItemIDs = function() end,
    GetPlayerData = function() return testStatsData end,
    IsHalJordan = function() return false end,
}
dofile("modules/item_battery.lua")(battCore)
local useItemCb = battCore.GL._cbs[ModCallbacks.MC_USE_ITEM]

local nonHalPlayerWithCar = {
    Position = Vector(0, 0),
    Damage = 3.5,
    HasCollectible = function(_, id) return id == 356 end, -- Car Battery
    AddCacheFlags = function() end,
    EvaluateItems = function() end,
    AnimateHappy = function() end,
}
testStatsData.overchargeTier = 0
useItemCb(nil, 301, nil, nonHalPlayerWithCar, 0, 0, 0)
check(testStatsData.overchargeTier == 2, "Power Battery: non-Hal with Car Battery gets Tier 2 (+25% DMG)")

-- ===================== TEST 4: ENCYCLOPEDIA & COMMUNITY MOD REGISTRATION =====================
SpecialistDance = {
    _items = {},
    RegisterItem = function(self, id, isGood)
        table.insert(self._items, { id = id, isGood = isGood })
    end,
}
PogLite = {
    _pogs = {},
    AddPogCostume = function(self, name, id)
        table.insert(self._pogs, { name = name, id = id })
    end,
}
Encyclopedia = {
    _chars = {},
    _items = {},
    _trinkets = {},
    AddCharacter = function(c) table.insert(Encyclopedia._chars, c) end,
    AddItem = function(i) table.insert(Encyclopedia._items, i) end,
    AddTrinket = function(t) table.insert(Encyclopedia._trinkets, t) end,
    ItemPools = { POOL_SHOP = 1, POOL_TREASURE = 2, POOL_ANGEL = 3, POOL_DEVIL = 4, POOL_CURSE = 5, POOL_PLANETARIUM = 6 },
}
local encCore = {
    GL = { AddCallback = function() end },
    PLAYER_HAL = 1,
    PLAYER_TAINTED_HAL = 2,
    ITEM_POWER_BATTERY = 10,
    ITEM_GIANT_FIST = 11,
    ITEM_COAST_CITY = 12,
    ITEM_GATLING = 13,
    ITEM_SOLID_LIGHT_SHIELD = 14,
    ITEM_POWER_RING = 15,
    TRINKET_YELLOW_IMPURITY = 20,
}
dofile("modules/compat_encyclopedia.lua")(encCore)
encCore.RegisterEncyclopedia()
check(#Encyclopedia._chars == 2, "Encyclopedia: 2 characters registered")
check(#Encyclopedia._items == 6, "Encyclopedia: 6 items registered")
check(#Encyclopedia._trinkets == 1, "Encyclopedia: 1 trinket registered")
check(#SpecialistDance._items == 1 and SpecialistDance._items[1].id == 15, "Specialist Dance: Ring registered as quality item")
check(#PogLite._pogs == 1 and PogLite._pogs[1].id == 15, "PogLite: Ring registered for pog costume")

-- ===================== TEST 5: DR. FETUS HARD-LIGHT CONSTRUCT BOMBS =====================
local beamCore = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    IsRingActive = function(p) return p._ringActive ~= false end,
    GetPlayerData = function(p) return p._data or {} end,
    IsTaintedHal = function(p) return p._isTainted == true end,
    IsHalJordan = function(p) return p._isHal == true end,
    TriggerHalRingDepleted = function() end,
    SetEntityScaleAndColor = function(ent, scale, col)
        ent._scale = scale
        ent._color = col
    end,
}
local fBeam = assert(io.open("modules/beam_synergies.lua", "r"))
local srcBeam = fBeam:read("*a"); fBeam:close()
srcBeam = srcBeam:gsub("|", "+")
local chunkBeam = assert(loadstring(srcBeam, "modules/beam_synergies.lua"))
chunkBeam()(beamCore)

local function findBeamCb(id)
    for _, c in ipairs(beamCore.GL._cbs) do
        if c.id == id then return c.fn end
    end
end

local bombInitCb = findBeamCb(ModCallbacks.MC_POST_BOMB_INIT)
check(bombInitCb ~= nil, "BeamSynergies: MC_POST_BOMB_INIT registered")

local playerStub = {
    _ringActive = true,
    _data = { ringFlareTimer = 0 },
    ToPlayer = function(self) return self end,
}
local bombSpr = { Color = nil }
local bombEnt = {
    Type = EntityType.ENTITY_BOMB,
    SpawnerEntity = playerStub,
    DepthOffset = 0,
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return bombSpr end,
}
bombInitCb(nil, bombEnt)
check(bombEnt:GetData().isGLBomb == true, "Dr Fetus: bomb marked isGLBomb")
check(bombEnt.DepthOffset == 30, "Dr Fetus: bomb DepthOffset set to 30")
check(bombSpr.Color ~= nil and bombSpr.Color.G == 1.0, "Dr Fetus: bomb tinted emerald")
check(playerStub._data.ringFlareTimer == 8, "Dr Fetus: ring flare timer triggered on bomb drop")

local bombUpdateCb = findBeamCb(ModCallbacks.MC_POST_BOMB_UPDATE)
check(bombUpdateCb ~= nil, "BeamSynergies: MC_POST_BOMB_UPDATE registered")
bombSpr.Color = nil
bombUpdateCb(nil, bombEnt)
check(bombSpr.Color ~= nil and bombSpr.Color.G == 1.0, "Dr Fetus: bomb update maintains emerald tint")

local entityRemoveCb = findBeamCb(ModCallbacks.MC_POST_ENTITY_REMOVE)
check(entityRemoveCb ~= nil, "BeamSynergies: MC_POST_ENTITY_REMOVE registered")
local spawnedFx = nil
local origSpawn = Isaac.Spawn
Isaac.Spawn = function(eType, var, sub, pos, vel, spawner)
    spawnedFx = {
        Type = eType,
        Variant = var,
        Position = pos,
        SpawnerEntity = spawner,
    }
    return spawnedFx
end
bombEnt.Position = Vector(100, 200)
entityRemoveCb(nil, bombEnt)
Isaac.Spawn = origSpawn
check(spawnedFx ~= nil and spawnedFx.Type == EntityType.ENTITY_EFFECT, "Dr Fetus: explosion spawns construct burst effect")
check(spawnedFx._scale == 1.25, "Dr Fetus: construct effect scale set to 1.25")

-- ===================== TEST 6: LUDOVICO TECHNIQUE HARD-LIGHT CONSTRUCT ORB =====================
local tearUpdateCb = findBeamCb(ModCallbacks.MC_POST_TEAR_UPDATE)
check(tearUpdateCb ~= nil, "BeamSynergies: MC_POST_TEAR_UPDATE registered")

local playerLudo = {
    _ringActive = true,
    _data = {},
    ToPlayer = function(self) return self end,
    HasCollectible = function(self, id) return id == CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE end,
}
local tearSpr = { Color = nil }
local ludoTear = {
    Type = EntityType.ENTITY_TEAR,
    SpawnerEntity = playerLudo,
    TearFlags = 0,
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return tearSpr end,
    Position = Vector(50, 50),
}
tearUpdateCb(nil, ludoTear)
check(ludoTear:GetData().isGLLudovicoOrb == true, "Ludovico: tear marked isGLLudovicoOrb")
check(tearSpr.Color ~= nil and tearSpr.Color.G == 1.0, "Ludovico: orb tinted emerald")

-- ===================== TEST 7: BAG OF CRAFTING RECIPES XML =====================
local rf = io.open("content/recipes.xml", "r")
check(rf ~= nil, "Recipes: content/recipes.xml exists")
if rf then
    local content = rf:read("*a")
    rf:close()
    local expectedItems = {
        "Power Battery",
        "Giant Fist",
        "The Tragedy of Coast City",
        "Gatling",
        "Solid Light Shield",
        "Green Lantern Ring",
    }
    for _, item in ipairs(expectedItems) do
        local pat = '<recipe%s+result="' .. item:gsub("%-", "%%-") .. '"%s+ingredients="([^"]+)"'
        local ingredients = content:match(pat)
        check(ingredients ~= nil, "Recipes: recipe for '" .. item .. "' found in recipes.xml")
        if ingredients then
            local count = 0
            for _ in ingredients:gmatch("%S+") do count = count + 1 end
            check(count == 8, "Recipes: '" .. item .. "' has exactly 8 ingredients, found " .. count)
        end
    end
end

-- ===================== RESULTS =====================
io.stderr:write(string.format("\n[test_new_synergies] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
