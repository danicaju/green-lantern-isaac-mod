-- tools/test_audit_fixes.lua
-- Verification suite for audit bug fixes:
-- 1. challenges.xml without hardcoded id attributes (custom challenges visible).
-- 2. metadata.xml challenges tag.
-- 3. shield.lua minDmg definition in MC_ENTITY_TAKE_DMG (no nil crash in math.max).
-- 4. beam_discrete.lua local flags in isGLFist branch.
-- 5. ids.lua nil player safety in HasGreenLanternRing.
-- 6. core.lua nil player safety in GetPlayerData.
-- 7. utils.lua Core.PlayRingOverchargeChime alias.

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

-- ===================== TEST 1: CHALLENGES.XML & METADATA =====================
local f = io.open("content/challenges.xml", "r")
check(f ~= nil, "content/challenges.xml exists")
local xml = f:read("*a")
f:close()

check(xml:find('<?xml version="1.0" encoding="UTF-8"?>', 1, true) ~= nil, "challenges.xml has XML declaration")
check(xml:find('<challenge%s+[^>]*id=', 1) == nil, "challenges.xml has NO hardcoded id attributes on custom challenges")
check(xml:find('name="In Brightest Day"', 1, true) ~= nil, "In Brightest Day defined")
check(xml:find('name="Emerald Twilight"', 1, true) ~= nil, "Emerald Twilight defined")
check(xml:find('name="Blackest Night"', 1, true) ~= nil, "Blackest Night defined")
check(xml:find('name="Sinestro Corps War"', 1, true) ~= nil, "Sinestro Corps War defined")

local fMeta = io.open("metadata.xml", "r")
check(fMeta ~= nil, "metadata.xml exists")
local metaXml = fMeta:read("*a")
fMeta:close()
check(metaXml:find('<tag id="challenges"/>', 1, true) ~= nil or metaXml:find('<tag id="Challenges"/>', 1, true) ~= nil, "metadata.xml contains challenges tag")

-- ===================== TEST 2: CORE NIL SAFETY =====================
RegisterMod = function(name, ver)
    return {
        AddCallback = function() end,
        SaveModData = function() end,
        LoadModData = function() return "{}" end,
        HasModData = function() return false end,
    }
end
Vector = function(x, y) return { X = x or 0, Y = y or 0 } end
Color = function(...) return {} end

local Core = dofile("modules/core.lua")
check(type(Core.GetPlayerData) == "function", "Core.GetPlayerData exists")
local nilData = Core.GetPlayerData(nil)
check(type(nilData) == "table", "Core.GetPlayerData(nil) returns table safely")
local dummyData = Core.GetPlayerData({})
check(type(dummyData) == "table", "Core.GetPlayerData({}) returns table safely")

-- ===================== TEST 3: IDS NIL SAFETY =====================
Isaac = {
    GetItemIdByName = function() return 1 end,
    GetTrinketIdByName = function() return 1 end,
    GetCostumeIdByPath = function() return 1 end,
    GetPlayerTypeByName = function() return 1 end,
}
dofile("modules/ids.lua")(Core)
check(type(Core.HasGreenLanternRing) == "function", "Core.HasGreenLanternRing exists")
local hasRingNil = Core.HasGreenLanternRing(nil)
check(hasRingNil == false, "Core.HasGreenLanternRing(nil) returns false safely")
local isRingActiveNil = Core.IsRingActive(nil)
check(isRingActiveNil == false, "Core.IsRingActive(nil) returns false safely")

-- ===================== TEST 4: UTILS CHIME ALIAS =====================
dofile("modules/utils.lua")(Core)
check(type(Core.PlayOverchargeChime) == "function", "Core.PlayOverchargeChime exists")
check(Core.PlayRingOverchargeChime == Core.PlayOverchargeChime, "Core.PlayRingOverchargeChime aliases Core.PlayOverchargeChime")

-- ===================== TEST 5: SHIELD REFLECT minDmg =====================
local mockCallbacks = {}
local mockGL = {
    AddCallback = function(self, id, fn)
        mockCallbacks[id] = mockCallbacks[id] or {}
        table.insert(mockCallbacks[id], fn)
    end
}
Core.GL = mockGL
Core.ITEM_SOLID_LIGHT_SHIELD = 104
Core.SHIELD_REFLECT_BASE = 1.0
Core.SHIELD_REFLECT_MAX = 1.0
Core.SHIELD_REFLECT_PER_LUCK = 0

EntityType = {
    ENTITY_PLAYER = 1,
    ENTITY_TEAR = 2,
    ENTITY_PROJECTILE = 9,
    ENTITY_EFFECT = 1000,
}
EffectVariant = { WATER_SPLASH = 1 }
TearVariant = { DEFAULT = 0 }
TearFlags = {
    TEAR_SPECTRAL = 1,
    TEAR_PIERCING = 2,
    TEAR_TRACTOR_BEAM = 4,
}
SoundEffect = {
    SOUND_METAL_CLINK = 1,
    SOUND_TEARS_FIRE = 2,
}
SFXManager = function()
    return { Play = function() end }
end

local spawnedTears = {}
Isaac = {
    GetPlayer = function(i) return mockPlayer end,
    Spawn = function(eType, var, sub, pos, vel, spawner)
        local t = {
            Type = eType,
            Position = pos,
            Velocity = vel,
            CollisionDamage = 0,
            TearFlags = 0,
            Visible = true,
            ToTear = function(self) return self end,
            GetSprite = function(self) return { Color = nil } end,
            GetData = function(self) return {} end,
        }
        if eType == EntityType.ENTITY_TEAR then
            table.insert(spawnedTears, t)
        end
        return t
    end,
    GetRoomEntities = function() return {} end,
    FindByType = function() return {} end,
}
Game = function()
    return {
        GetNumPlayers = function() return 1 end,
        GetFrameCount = function() return 100 end,
        GetRoom = function()
            return {
                GetCenterPos = function() return Vector(200, 200) end,
            }
        end,
    }
end

Vector = {}
local VectorMT = {}
VectorMT.__add = function(a, b) return Vector(a.X + b.X, a.Y + b.Y) end
VectorMT.__sub = function(a, b) return Vector(a.X - b.X, a.Y - b.Y) end
VectorMT.__unm = function(a) return Vector(-a.X, -a.Y) end
VectorMT.__mul = function(a, b)
    if type(b) == "number" then return Vector(a.X * b, a.Y * b) end
    if type(a) == "number" then return Vector(a * b.X, a * b.Y) end
    return Vector(a.X * b.X, a.Y * b.Y)
end

function Vector.new(x, y)
    local t = { X = x or 0, Y = y or 0 }
    t.Length = function(s) return math.sqrt(s.X * s.X + s.Y * s.Y) end
    t.Normalized = function(s)
        local l = s:Length()
        return l > 0 and Vector(s.X / l, s.Y / l) or Vector(1, 0)
    end
    setmetatable(t, VectorMT)
    return t
end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
Vector.Zero = Vector(0, 0)

mockPlayer = {
    Index = 0,
    Type = EntityType.ENTITY_PLAYER,
    Position = Vector(100, 100),
    Damage = 5.0,
    Luck = 0,
    ToPlayer = function(self) return self end,
    HasCollectible = function(self, id) return id == Core.ITEM_SOLID_LIGHT_SHIELD end,
    GetData = function(self) return { GreenLantern = {} } end,
}

ModCallbacks = {
    MC_POST_UPDATE = 1,
    MC_ENTITY_TAKE_DMG = 2,
    MC_POST_RENDER = 3,
}

local function loadShieldFactory(path)
    local f = io.open(path, "r")
    local src = f and f:read("*a") or ""
    if f then f:close() end
    local patched = src:gsub(
        "| TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING",
        "+ TearFlags.TEAR_SPECTRAL + TearFlags.TEAR_PIERCING"
    )
    local chunk, err = loadstring(patched, path)
    assert(chunk, err)
    return chunk()
end

loadShieldFactory("modules/shield.lua")(Core)

local takeDmgCb = nil
if mockCallbacks[ModCallbacks.MC_ENTITY_TAKE_DMG] then
    takeDmgCb = mockCallbacks[ModCallbacks.MC_ENTITY_TAKE_DMG][1]
end
check(takeDmgCb ~= nil, "MC_ENTITY_TAKE_DMG registered in shield.lua")

if takeDmgCb then
    local projectileSource = {
        Entity = {
            Type = EntityType.ENTITY_PROJECTILE,
            Position = Vector(110, 100),
            Velocity = Vector(-5, 0),
            GetData = function(self) return {} end,
        }
    }

    local blocked = takeDmgCb(nil, mockPlayer, 1.0, 0, projectileSource)
    check(blocked == false, "Damage was blocked (reflected) by Solid Light Shield")
    check(#spawnedTears > 0, "Reflected tear spawned")
    local ref = spawnedTears[#spawnedTears]
    check(ref.CollisionDamage > 0, "Reflected tear has non-zero CollisionDamage (minDmg passed)")
    check(ref.CollisionDamage == 7.5, "Reflected tear deals player.Damage * 1.5 = 7.5")
end

-- ===================== TEST 6: BEAM DISCRETE FLAGS IN GIANT FIST =====================
local fBeam = io.open("modules/beam_discrete.lua", "r")
check(fBeam ~= nil, "modules/beam_discrete.lua exists")
local beamContent = fBeam:read("*a")
fBeam:close()
check(beamContent:find("local flags = tear.TearFlags%s*local fistHasTB", 1) ~= nil or
      beamContent:find("local flags = tear.TearFlags%s*\n%s*local fistHasTB", 1) ~= nil,
      "Giant Fist branch defines local flags before fistHasTB check")

-- ===================== TEST 7: ITEM GATLING LUA 5.1 COMPATIBILITY =====================
local gatlingOk, gatlingModule = pcall(function() return dofile("modules/item_gatling.lua") end)
check(gatlingOk == true, "modules/item_gatling.lua loads cleanly in Lua 5.1 without syntax errors")

-- ===================== TEST 8: GIANT FIST DESTROYABLE ROCK TYPES =====================
local fFist = io.open("modules/item_fist.lua", "r")
check(fFist ~= nil, "modules/item_fist.lua exists")
local fistContent = fFist:read("*a")
fFist:close()
check(fistContent:find("GRID_ROCK_SS", 1, true) ~= nil, "Giant Fist supports GRID_ROCK_SS")
check(fistContent:find("GRID_ROCK_SPIKED", 1, true) ~= nil, "Giant Fist supports GRID_ROCK_SPIKED")
check(fistContent:find("GRID_ROCK_GOLD", 1, true) ~= nil, "Giant Fist supports GRID_ROCK_GOLD")
check(fistContent:find("GRID_TNT", 1, true) ~= nil, "Giant Fist supports GRID_TNT")

-- ===================== TEST 9: LEVEL & ROOM NIL GUARDS =====================
local fCoast = io.open("modules/item_coastcity.lua", "r")
local coastContent = fCoast:read("*a")
fCoast:close()
check(coastContent:find("local roomIdx%s*=%s*Game%(%):GetLevel%(%):GetCurrentRoomIndex%(%)") == nil,
      "item_coastcity.lua does not call GetLevel():GetCurrentRoomIndex() unguarded")

local fHud = io.open("modules/hud_render.lua", "r")
local hudContent = fHud:read("*a")
fHud:close()
check(hudContent:find("Game%(%):GetRoom%(%):GetRenderMode%(%)") == nil,
      "hud_render.lua does not call GetRoom():GetRenderMode() unguarded")

io.stderr:write(string.format("\n[test_audit_fixes] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
