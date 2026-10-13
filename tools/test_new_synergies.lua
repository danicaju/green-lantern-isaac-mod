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
    MC_POST_NEW_LEVEL = 18,
    MC_POST_PLAYER_UPDATE = 19,
    MC_POST_NEW_ROOM = 20,
    MC_POST_RENDER = 21,
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

-- ===================== TEST 8: HOMING CONTINUOUS BEAM SYNERGY =====================
local aimCore = {
    ITEM_POWER_RING = 15,
}
local fAim = assert(io.open("modules/ring_aim.lua", "r"))
local srcAim = fAim:read("*a"); fAim:close()
srcAim = srcAim:gsub("|", "+")
local chunkAim = assert(loadstring(srcAim, "modules/ring_aim.lua"))
chunkAim()(aimCore)

local homingPlayer = {
    HasCollectible = function(_, id) return id == 3 end, -- Spoon Bender (3)
    HasHomingTypeTears = function() return false end,
}
check(aimCore.HasHomingSynergy(homingPlayer) == true, "Homing: Spoon Bender detected as homing synergy")

-- Simulate an enemy in front-right (+X, +Y)
local enemyStub = {
    Position = Vector(200, 80),
    Exists = function() return true end,
    IsDead = function() return false end,
    IsActiveEnemy = function() return true end,
    IsVulnerableEnemy = function() return true end,
}
local origGetEntities = Isaac.GetRoomEntities
Isaac.GetRoomEntities = function() return { enemyStub } end
local curvedDir = aimCore.GetHomingBeamDirection(homingPlayer, Vector(0, 0), Vector(1, 0))
Isaac.GetRoomEntities = origGetEntities

check(curvedDir.Y > 0.1, "Homing: continuous beam deflected towards enemy (+Y)")
check(curvedDir.X > 0.8, "Homing: continuous beam maintains forward momentum (+X)")

-- ===================== TEST 9: TINY PLANET CONTINUOUS BEAM SYNERGY =====================
local mathCore = {
    GetTapTearCount = function() return 1 end,
}
local fMath = assert(io.open("modules/beam_math.lua", "r"))
local srcMath = fMath:read("*a"); fMath:close()
srcMath = srcMath:gsub("|", "+")
local chunkMath = assert(loadstring(srcMath, "modules/beam_math.lua"))
chunkMath()(mathCore)

local tpPlayer = {
    HasCollectible = function(_, id) return id == 233 end, -- Tiny Planet (233)
}
local tpAngles = mathCore.GetContinuousBeamAngles(tpPlayer)
check(#tpAngles == 4, "Tiny Planet: 4 orbital construct beam angles generated")
check(math.abs((tpAngles[2] - tpAngles[1]) % 360 - 90) < 0.01, "Tiny Planet: 90-degree spacing between beams")

local tpEndWorld = mathCore.ComputeContinuousBeamEndWorld(Vector(100, 100), Vector(1, 0), 180.0)
local tpDist = (tpEndWorld.X - 100)
check(math.abs(tpDist - 180.0) < 1.0, "Tiny Planet: beam range clamped to 180 units")

-- ===================== TEST 10: HAEMOLACRIA & POP! CONSTRUCT SYNERGIES =====================
local haemoPlayer = {
    _ringActive = true,
    ToPlayer = function(self) return self end,
    HasCollectible = function(_, id) return id == 531 end, -- Haemolacria
}
local haemoSpr = { Color = nil }
local haemoTear = {
    Type = EntityType.ENTITY_TEAR,
    SpawnerEntity = haemoPlayer,
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return haemoSpr end,
}
-- Find the Haemolacria callback (6th callback in beamCore)
for _, c in ipairs(beamCore.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_TEAR_UPDATE then
        c.fn(nil, haemoTear)
    end
end
check(haemoTear:GetData().isGLHaemoTear == true, "Haemolacria: marked as isGLHaemoTear")
check(haemoSpr.Color ~= nil and haemoSpr.Color.G == 1.0, "Haemolacria: mortar tinted emerald")

local popPlayer = {
    _ringActive = true,
    ToPlayer = function(self) return self end,
    HasCollectible = function(_, id) return id == 529 end, -- Pop!
}
local popSpr = { Color = nil }
local popTear = {
    Type = EntityType.ENTITY_TEAR,
    SpawnerEntity = popPlayer,
    _data = {},
    GetData = function(self) return self._data end,
    GetSprite = function() return popSpr end,
}
for _, c in ipairs(beamCore.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_TEAR_UPDATE then
        c.fn(nil, popTear)
    end
end
check(popTear:GetData().isGLPopOrb == true, "Pop!: marked as isGLPopOrb")
check(popSpr.Color ~= nil and popSpr.Color.G == 1.0, "Pop!: bouncing orb tinted emerald")

-- ===================== TEST 11: CUSTOM CHALLENGES =====================
local cf = io.open("content/challenges.xml", "r")
check(cf ~= nil, "Challenges: content/challenges.xml exists")
if cf then
    local content = cf:read("*a")
    cf:close()
    check(content:find('name="In Brightest Day"') ~= nil, "Challenges: 'In Brightest Day' challenge defined")
    check(content:find('name="Blackest Night"') ~= nil, "Challenges: 'Blackest Night' challenge defined")
end

local chalCore = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    PLAYER_HAL = 1,
    PLAYER_TAINTED_HAL = 2,
    ITEM_SOLID_LIGHT_SHIELD = 14,
    ITEM_GIANT_FIST = 11,
    ITEM_POWER_BATTERY = 10,
    ITEM_COAST_CITY = 12,
    TRINKET_YELLOW_IMPURITY = 20,
}
ModCallbacks.MC_POST_NEW_LEVEL = 18
dofile("modules/challenges.lua")(chalCore)

local chalStartCb = nil
local chalLevelCb = nil
for _, c in ipairs(chalCore.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_GAME_STARTED then chalStartCb = c.fn end
    if c.id == ModCallbacks.MC_POST_NEW_LEVEL then chalLevelCb = c.fn end
end
check(chalStartCb ~= nil, "Challenges: MC_POST_GAME_STARTED registered")
check(chalLevelCb ~= nil, "Challenges: MC_POST_NEW_LEVEL registered")

-- Test In Brightest Day setup
local testP = {
    _pType = 0,
    _items = {},
    _trinkets = {},
    CanShoot = true,
    GetPlayerType = function(self) return self._pType end,
    ChangePlayerType = function(self, t) self._pType = t end,
    HasCollectible = function(self, id) return self._items[id] == true end,
    AddCollectible = function(self, id) self._items[id] = true end,
    HasTrinket = function(self, id) return self._trinkets[id] == true end,
    AddTrinket = function(self, id) self._trinkets[id] = true end,
}
Isaac.GetPlayer = function() return testP end
Game = function()
    return {
        GetNumPlayers = function() return 1 end,
        GetLevel = function()
            return {
                _curses = 0,
                AddCurse = function(self, c) self._curses = self._curses + c end,
            }
        end,
    }
end

Isaac.GetChallenge = function() return 1 end
Isaac.GetChallengeIdByName = function(name)
    if name == "In Brightest Day" then return 1 end
    if name == "Blackest Night" then return 2 end
    return -1
end

chalStartCb(nil, false)
check(testP._pType == chalCore.PLAYER_HAL, "Challenges: In Brightest Day sets player to Hal")
check(testP.CanShoot == false, "Challenges: In Brightest Day sets blindfold (CanShoot=false)")
check(testP:HasCollectible(chalCore.ITEM_SOLID_LIGHT_SHIELD), "Challenges: In Brightest Day grants Solid Light Shield")
check(testP:HasCollectible(chalCore.ITEM_GIANT_FIST), "Challenges: In Brightest Day grants Giant Fist")

-- Test Blackest Night setup
testP._pType = 0
testP.CanShoot = true
Isaac.GetChallenge = function() return 2 end
chalStartCb(nil, false)
check(testP._pType == chalCore.PLAYER_TAINTED_HAL, "Challenges: Blackest Night sets player to Tainted Hal")
check(testP:HasCollectible(chalCore.ITEM_COAST_CITY), "Challenges: Blackest Night grants Coast City")
check(testP:HasTrinket(chalCore.TRINKET_YELLOW_IMPURITY), "Challenges: Blackest Night grants Yellow Impurity")

-- ===================== TEST 12: DYNAMIC HARD-LIGHT LIGHTING =====================
local lightCore = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    DYNAMIC_LIGHTING_ENABLED = true,
    IsRingActive = function() return true end,
    GetPlayerData = function(p) return p._data or {} end,
}
dofile("modules/fx_lighting.lua")(lightCore)

local lightUpdateCb = nil
local lightRoomCb = nil
for _, c in ipairs(lightCore.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_PLAYER_UPDATE then lightUpdateCb = c.fn end
    if c.id == ModCallbacks.MC_POST_NEW_ROOM then lightRoomCb = c.fn end
end
check(lightUpdateCb ~= nil, "Lighting: MC_POST_PLAYER_UPDATE registered")
check(lightRoomCb ~= nil, "Lighting: MC_POST_NEW_ROOM registered")

local spawnedLight = nil
local origSpawn = Isaac.Spawn
Isaac.Spawn = function(eType, var, sub, pos, vel, spawner)
    spawnedLight = {
        Type = eType,
        Variant = var,
        Position = pos,
        DepthOffset = 0,
        _data = {},
        GetData = function(self) return self._data end,
        Exists = function() return true end,
        IsDead = function() return false end,
        GetSprite = function() return { Color = {} } end,
    }
    return spawnedLight
end

local lightPlayer = {
    Position = Vector(100, 150),
    _data = { isFiringContinuousBeam = true },
}
lightUpdateCb(nil, lightPlayer)
Isaac.Spawn = origSpawn

check(lightPlayer._data.glLightEntity ~= nil, "Lighting: light entity created on continuous beam")
check(lightPlayer._data.glLightEntity:GetData().isGLLight == true, "Lighting: marked as isGLLight")

-- ===================== TEST 13: MULTIPLAYER CO-OP HUD CORNER POSITIONING =====================
local renderedTexts = {}
local origRenderScaled = Isaac.RenderScaledText
Isaac.RenderScaledText = function(txt, x, y, sx, sy, r, g, b, a)
    table.insert(renderedTexts, { x = x, y = y, txt = txt })
end
Isaac.GetScreenWidth = function() return 480 end
Isaac.GetScreenHeight = function() return 270 end

local p1Hal = { _data = { willpower = 80 }, Index = 0 }
local p2Hal = { _data = { willpower = 90 }, Index = 1 }

local hudCore = {
    GL = {
        _cbs = {},
        AddCallback = function(self, id, fn)
            table.insert(self._cbs, { id = id, fn = fn })
        end,
    },
    HUD_GL_DISPLAY = true,
    GetPlayerData = function(p) return p._data end,
    IsHalJordan = function() return true end,
    IsTaintedHal = function() return false end,
    GetMaxWillpower = function() return 100 end,
    WILLPOWER_MAX = 100,
    DrawHudText = function() end,
}
local fHud = assert(io.open("modules/hud_render.lua", "r"))
local srcHud = fHud:read("*a"); fHud:close()
srcHud = srcHud:gsub("|", "+")
local chunkHud = assert(loadstring(srcHud, "modules/hud_render.lua"))
chunkHud()(hudCore)

local hudRenderCb = nil
for _, c in ipairs(hudCore.GL._cbs) do
    if c.id == ModCallbacks.MC_POST_RENDER then hudRenderCb = c.fn end
end
check(hudRenderCb ~= nil, "Co-op HUD: MC_POST_RENDER callback found")

-- Simulate two Hal players in co-op
Game = function()
    return {
        GetHUD = function() return { IsVisible = function() return true end } end,
        GetNumPlayers = function() return 2 end,
        IsPaused = function() return false end,
        GetFrameCount = function() return 100 end,
    }
end
hudCore.EnsureEIDRegistered = function() end
hudCore.RegisterStageAPIGraphics = function() end

Isaac.GetPlayer = function(i)
    if i == 0 then return p1Hal
    elseif i == 1 then return p2Hal end
    return nil
end

hudRenderCb()
Isaac.RenderScaledText = origRenderScaled

-- P1 must be in top-left (x around 48, y around 36)
-- P2 must be in top-right (x around 400, y around 36)
check(#renderedTexts >= 2, "Co-op HUD: both players rendered HUD elements")
local p1X = renderedTexts[1].x
local p2X = renderedTexts[3] and renderedTexts[3].x or renderedTexts[2].x
check(p1X == 48, "Co-op HUD: Player 1 rendered in top-left (X=48)")
check(p2X == (480 - 80), "Co-op HUD: Player 2 rendered in top-right (X=400)")

-- ===================== TEST 14: SCI-FI SOUND EFFECTS & PLAYRINGSOUND =====================
local playedSounds = {}
SFXManager = function()
    return {
        Play = function(self, id, vol, frame, loop, pitch)
            table.insert(playedSounds, { id = id, vol = vol, pitch = pitch })
        end,
    }
end

local utilsCore = {
    SFX_VOLUME_MULT = 1.0,
}
local fUtils = assert(io.open("modules/utils.lua", "r"))
local srcUtils = fUtils:read("*a"); fUtils:close()
srcUtils = srcUtils:gsub("|", "+")
local chunkUtils = assert(loadstring(srcUtils, "modules/utils.lua"))
chunkUtils()(utilsCore)

utilsCore.PlayRingSound(145, 0.80, 1.25)
check(#playedSounds == 1, "SFX: sound was played via PlayRingSound")
check(playedSounds[1].id == 145, "SFX: correct sound id 145")
check(math.abs(playedSounds[1].vol - 0.80) < 0.01, "SFX: volume matches base 0.80")
check(math.abs(playedSounds[1].pitch - 1.25) < 0.01, "SFX: pitch matches 1.25")

-- Test volume multiplier scaling
utilsCore.SFX_VOLUME_MULT = 0.50
utilsCore.PlayRingSound(145, 0.80, 1.25)
check(#playedSounds == 2, "SFX: second sound played")
check(math.abs(playedSounds[2].vol - 0.40) < 0.01, "SFX: volume scaled by 0.50x multiplier (0.40)")

-- ===================== RESULTS =====================
io.stderr:write(string.format("\n[test_new_synergies] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
