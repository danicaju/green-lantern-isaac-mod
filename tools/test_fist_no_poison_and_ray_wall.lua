-- tools/test_fist_no_poison_and_ray_wall.lua
-- Verification for:
-- 1. Giant Fist poison completely removed (no SMOKE_CLOUD, no isGLFistPoison, rocks still destroy)
-- 2. Core.IsWallAtPos accurately identifies room boundary and wall tiles while ignoring rocks/pits
-- 3. Spammeable discrete rays (isGLRingBeam) destroy themselves upon hitting walls, but pass over rocks/pits

local passes = 0
local failures = 0

local function check(cond, msg)
  if cond then
    passes = passes + 1
  else
    failures = failures + 1
    io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
  end
end

-- ===================== TEST 1: GIANT FIST CODE INTEGRITY =====================
local fFist = assert(io.open("modules/item_fist.lua", "r"))
local srcFist = fFist:read("*a")
fFist:close()

check(srcFist:find("isGLFistPoison") == nil, "item_fist.lua must not reference isGLFistPoison")
check(srcFist:find("SMOKE_CLOUD") == nil, "item_fist.lua must not reference SMOKE_CLOUD")
check(srcFist:find("glPoisonLife") == nil, "item_fist.lua must not reference glPoisonLife")
check(srcFist:find("UpdateFistPoisonCloud") == nil, "item_fist.lua must not define UpdateFistPoisonCloud")
check(srcFist:find("GRID_ROCK") ~= nil, "item_fist.lua must keep rock destruction")
check(srcFist:find("ApplyGiantFistSprite") ~= nil, "item_fist.lua must call ApplyGiantFistSprite")

-- ===================== TEST 2: CORE.ISWALLATPOS BEHAVIOR =====================
Vector = {}
local VectorMT = { __index = Vector }
function Vector.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, VectorMT) end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
  local l = self:Length()
  if l <= 0.001 then return Vector.new(1, 0) end
  return Vector.new(self.X / l, self.Y / l)
end
function Vector:GetAngleDegrees() return 0 end
function VectorMT.__add(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end
function VectorMT.__sub(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
function VectorMT.__mul(a, b)
  if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
  return Vector.new(a.X * b.X, a.Y * b.Y)
end
Vector.Zero = Vector.new(0, 0)

GridCollisionClass = {
  COLLISION_NONE = 0,
  COLLISION_SOLID = 1,
  COLLISION_WALL = 2,
  COLLISION_WALL_EXCEPT_PLAYER = 3,
  COLLISION_PIT = 4,
}

local mockGridCol = GridCollisionClass.COLLISION_NONE
local mockInRoom = true

Game = function()
  return {
    GetRoom = function()
      return {
        IsPositionInRoom = function(_, pos, margin) return mockInRoom end,
        GetGridCollisionAtPos = function(_, pos) return mockGridCol end,
      }
    end,
    GetFrameCount = function() return 10 end,
  }
end

local fMath = assert(io.open("modules/beam_math.lua", "r"))
local srcMath = fMath:read("*a"); fMath:close()
local mathCore = {}
local chunkMath = assert(loadstring(srcMath, "modules/beam_math.lua"))
chunkMath()(mathCore)

check(type(mathCore.IsWallAtPos) == "function", "Core.IsWallAtPos must be defined in modules/beam_math.lua")

-- Inside room with COLLISION_NONE -> NOT a wall
mockInRoom = true
mockGridCol = GridCollisionClass.COLLISION_NONE
check(mathCore.IsWallAtPos(Vector(200, 200)) == false, "Open room position is not a wall")

-- Inside room over a ROCK (COLLISION_SOLID) -> NOT a wall (spectral tears pass through rocks)
mockGridCol = GridCollisionClass.COLLISION_SOLID
check(mathCore.IsWallAtPos(Vector(200, 200)) == false, "Rock (COLLISION_SOLID) is not a wall for spectral rays")

-- Inside room over a PIT (COLLISION_PIT) -> NOT a wall (spectral tears pass over pits)
mockGridCol = GridCollisionClass.COLLISION_PIT
check(mathCore.IsWallAtPos(Vector(200, 200)) == false, "Pit (COLLISION_PIT) is not a wall for spectral rays")

-- Inside room over a WALL (COLLISION_WALL) -> IS a wall
mockGridCol = GridCollisionClass.COLLISION_WALL
check(mathCore.IsWallAtPos(Vector(200, 200)) == true, "Grid collision WALL is recognized as a wall")

-- Inside room over COLLISION_WALL_EXCEPT_PLAYER -> IS a wall
mockGridCol = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
check(mathCore.IsWallAtPos(Vector(200, 200)) == true, "Grid collision WALL_EXCEPT_PLAYER is recognized as a wall")

-- GridEntityType.GRID_WALL via GetGridEntityFromPos -> IS a wall
GridEntityType = { GRID_WALL = 4 }
local mockWallEnt = { GetType = function() return GridEntityType.GRID_WALL end }
Game = function()
  return {
    GetRoom = function()
      return {
        IsPositionInRoom = function(_, pos, margin) return true end,
        GetGridCollisionAtPos = function(_, pos) return GridCollisionClass.COLLISION_NONE end,
        GetGridEntityFromPos = function(_, pos) return (pos.X >= 500) and mockWallEnt or nil end,
      }
    end,
    GetFrameCount = function() return 10 end,
  }
end
check(mathCore.IsWallAtPos(Vector(550, 200)) == true, "GridEntityType.GRID_WALL is recognized as a wall")
check(mathCore.IsWallAtPos(Vector(200, 200)) == false, "Position without GRID_WALL is not a wall")

-- Restore original Game mock
Game = function()
  return {
    GetRoom = function()
      return {
        IsPositionInRoom = function(_, pos, margin) return mockInRoom end,
        GetGridCollisionAtPos = function(_, pos) return mockGridCol end,
      }
    end,
    GetFrameCount = function() return 10 end,
  }
end

-- Outside room boundary (IsPositionInRoom == false) -> IS a wall
mockInRoom = false
mockGridCol = GridCollisionClass.COLLISION_NONE
check(mathCore.IsWallAtPos(Vector(900, 200)) == true, "Out of room bounds is recognized as a wall")

-- ===================== TEST 3: DISCRETE RAY WALL DESTRUCTION =====================
RegisterMod = function(name, v)
  local cbs = {}
  return {
    _cbs = cbs,
    AddCallback = function(_, id, fn) table.insert(cbs, { id = id, fn = fn }) end,
  }
end
ModCallbacks = {
  MC_POST_FIRE_TEAR = 1,
  MC_POST_TEAR_UPDATE = 2,
  MC_PRE_TEAR_COLLISION = 3,
  MC_USE_ITEM = 4,
  MC_ENTITY_TAKE_DMG = 5,
}
TearFlags = {
  TEAR_PIERCING = 1,
  TEAR_SPECTRAL = 2,
}
EntityType = { ENTITY_TEAR = 2, ENTITY_EFFECT = 1000 }
EffectVariant = { WATER_SPLASH = 41 }
SoundEffect = { SOUND_TEARIMPACTS = 1 }
Color = function(r, g, b, a, ro, go, bo) return { R = r, G = g, B = b, A = a } end

local spawnedFx = {}
local playedSounds = {}
SFXManager = function()
  return {
    Play = function(_, sfx, vol, frame, loop, pitch)
      table.insert(playedSounds, { sfx = sfx, vol = vol, pitch = pitch })
    end,
  }
end
Isaac = {
  Spawn = function(t, v, st, pos, vel, spawner)
    local fx = { Type = t, Variant = v, Position = pos }
    table.insert(spawnedFx, fx)
    return fx
  end,
}

local fDisc = assert(io.open("modules/beam_discrete.lua", "r"))
local srcDisc = fDisc:read("*a"); fDisc:close()
local srcDisc51 = srcDisc:gsub("|", "+")
local chunkDisc = assert(loadstring(srcDisc51, "modules/beam_discrete.lua"))

local discCore = {
  GL = RegisterMod("gl_test_wall_destroy", 1),
  IsAimingUp = function() return false end,
  HasTearFlag = function() return false end,
  SetEntityScaleAndColor = function() end,
  IsWallAtPos = function(pos)
    -- Wall at X >= 400
    return pos and pos.X >= 400
  end,
  ResolveBeamPlayer = function() return nil end,
}
chunkDisc()(discCore)

local postTearUpdateFn
for _, cb in ipairs(discCore.GL._cbs) do
  if cb.id == ModCallbacks.MC_POST_TEAR_UPDATE then postTearUpdateFn = cb.fn end
end
check(type(postTearUpdateFn) == "function", "beam_discrete must register MC_POST_TEAR_UPDATE")

-- Ray flying in open room towards wall: X = 200, velocity = (10, 0), leadDist = 10.4
-- checkPos.X = 210.4 < 400 -> Should NOT die
local tearDied = false
local tearRemoved = false
local rayTear = {
  Position = Vector(200, 100),
  Velocity = Vector(10, 0),
  Visible = true,
  TearFlags = 3,
  Size = 13,
  GetSprite = function()
    return {
      Color = {},
      GetAnimation = function() return "Idle" end,
      Load = function() end,
      Play = function() end,
    }
  end,
  GetData = function(self)
    self._d = self._d or { isGLRingBeam = true }
    return self._d
  end,
  Die = function() tearDied = true end,
  Remove = function() tearRemoved = true end,
}

postTearUpdateFn(nil, rayTear)
check(tearDied == false and tearRemoved == false, "Ray in open room does NOT die")
check(rayTear:GetData().isGLRingBeam == true, "Ray in open room remains isGLRingBeam = true")

-- Now ray approaches wall: X = 395, velocity = (10, 0), speed = 10, leadDist = 10.4
-- checkPos.X = 405.4 >= 400 -> Hits wall and destroys itself on wall surface!
rayTear.Position = Vector(395, 100)
spawnedFx = {}
playedSounds = {}
postTearUpdateFn(nil, rayTear)
check(tearDied == true, "Ray destroying itself calls Die() upon hitting wall")
check(rayTear:GetData().isGLRingBeam == false, "Ray isGLRingBeam cleared upon wall collision")
check(rayTear.Visible == false, "Ray visibility set to false upon wall collision")
check(#spawnedFx > 0, "Emerald splash effect spawned when ray destroys itself on wall")
check(#playedSounds > 0, "Tear impact sound played when ray destroys itself on wall")
check(spawnedFx[1].Position.X >= 395 and spawnedFx[1].Position.X <= 400.1, "Splash spawned exactly at wall boundary surface")

-- Fast ray: velocity = (20, 0), pos = 385, checkPos.X = 405 >= 400 -> Hits wall cleanly
tearDied = false
local fastRay = {
  Position = Vector(385, 100),
  Velocity = Vector(20, 0),
  Visible = true,
  TearFlags = 3,
  Size = 13,
  GetSprite = function() return { Color = {}, GetAnimation = function() return "Idle" end, Load = function() end, Play = function() end } end,
  GetData = function(self) self._d = self._d or { isGLRingBeam = true }; return self._d end,
  Die = function() tearDied = true end,
}
postTearUpdateFn(nil, fastRay)
check(tearDied == true, "Fast ray (speed 20) correctly detects wall and calls Die()")
check(fastRay.Position.X >= 398 and fastRay.Position.X <= 400.1, "Fast ray impact point is accurately clamped to wall surface")

-- Inward shot while flying at wall margin: starts at X = 405 (in wall margin), moving LEFT into open room (vel = -15, 0)
local inwardDied = false
local inwardRay = {
  Position = Vector(405, 100),
  Velocity = Vector(-15, 0),
  Visible = true,
  TearFlags = 3,
  Size = 13,
  FrameCount = 0,
  GetSprite = function() return { Color = {}, GetAnimation = function() return "Idle" end, Load = function() end, Play = function() end } end,
  GetData = function(self) self._d = self._d or { isGLRingBeam = true, hasEnteredRoom = false }; return self._d end,
  Die = function() inwardDied = true end,
}
postTearUpdateFn(nil, inwardRay)
check(inwardDied == false, "Inward shot from wall border does NOT die immediately on frame 0/1")
check(inwardRay:GetData().isGLRingBeam == true, "Inward shot remains isGLRingBeam = true while entering room")

-- Next frame inward ray has entered room: pos = 390 < 400
inwardRay.Position = Vector(390, 100)
postTearUpdateFn(nil, inwardRay)
check(inwardDied == false, "Inward ray inside room remains alive")
check(inwardRay:GetData().hasEnteredRoom == true, "Inward ray hasEnteredRoom updated to true")

-- ===================== TEST 4: GIANT FIST DESTROYS ROCKS WITHOUT POISON =====================
local rockDestroyed = false
local mockRock = {
  GetType = function() return 2 end, -- GRID_ROCK
  Destroy = function() rockDestroyed = true end,
  Position = Vector(100, 100),
}
Game = function()
  return {
    GetFrameCount = function() return 1 end,
    GetRoom = function()
      return {
        GetGridIndex = function() return 5 end,
        GetGridEntity = function() return mockRock end,
      }
    end,
    ShakeScreen = function() end,
  }
end
GridEntityType = {
  GRID_ROCK = 2, GRID_ROCKB = 3, GRID_ROCKT = 4, GRID_ROCK_BOMB = 5,
  GRID_ROCK_ALT = 6, GRID_ROCK_SS = 7, GRID_ROCK_SPIKED = 8,
  GRID_ROCK_ALT2 = 9, GRID_ROCK_GOLD = 10, GRID_TNT = 11, GRID_POOP = 14,
}
EffectVariant.POOF01 = 15

local mockFist = {
  Position = Vector(100, 100),
  Velocity = Vector(20, 0),
  GetData = function(self)
    self._d = self._d or { isGiantFist = true }
    return self._d
  end,
}
Isaac.FindByType = function(t, v)
  if t == 2 then return { mockFist } end -- ENTITY_TEAR
  return {}
end

local fistCore2 = { GL = RegisterMod("gl_fist_rock_test", 1) }
local srcFist51 = srcFist:gsub("|", "+")
local chunkFist2 = assert(loadstring(srcFist51, "modules/item_fist.lua"))
chunkFist2()(fistCore2)

local fistPostUpdateFn
for _, cb in ipairs(fistCore2.GL._cbs) do
  if cb.id == ModCallbacks.MC_POST_UPDATE then fistPostUpdateFn = cb.fn end
end
check(type(fistPostUpdateFn) == "function", "item_fist must register MC_POST_UPDATE")

spawnedFx = {}
fistPostUpdateFn()
check(rockDestroyed == true, "Giant Fist destroys rocks on contact")
for _, fx in ipairs(spawnedFx) do
  check(fx.Variant ~= 141, "Giant Fist must never spawn EffectVariant.SMOKE_CLOUD (141)")
end

io.stderr:write(string.format("\n[test_fist_no_poison_and_ray_wall] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
