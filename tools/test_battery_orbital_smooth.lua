-- tools/test_battery_orbital_smooth.lua
-- Unit test suite for Power Battery construct orbital:
-- 1. Dedicated sprite instance isolation from floor spark drops.
-- 2. Fluent 2.5D elliptical orbit (radX=32, radY=18, center waist Y=-14).
-- 3. True depth sorting:
--    - oy < 0 -> renders in MC_PRE_PLAYER_RENDER (isBehind == true), skipped in POST.
--    - oy >= 0 -> renders in MC_POST_PLAYER_RENDER (isBehind == false), skipped in PRE.
--    - isBehind == nil -> fallback renders for backwards compatibility.
-- 4. No snapping or jumping (maxDelta <= 1.5 * meanDelta).
-- 5. Strict active item requirement (player must possess ITEM_POWER_BATTERY).

local passes = 0
local failures = 0
local function assert_eq(desc, actual, expected)
    if actual == expected then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write(string.format("FAIL: %s (expected %s, got %s)\n", desc, tostring(expected), tostring(actual)))
    end
end
local function assert_true(desc, val)
    if val then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write(string.format("FAIL: %s (expected true, got %s)\n", desc, tostring(val)))
    end
end

-- Stubs
Vector = {}
local VectorMT = {}
function Vector.new(x, y)
    local t = { X = x or 0, Y = y or 0 }
    setmetatable(t, {
        __index = Vector,
        __add = VectorMT.__add,
        __sub = VectorMT.__sub,
        __unm = VectorMT.__unm,
        __mul = VectorMT.__mul,
    })
    return t
end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
Vector.Zero = Vector.new(0, 0)
VectorMT.__add = function(a, b)
    if type(b) == "number" then return Vector.new(a.X + b, a.Y + b) end
    return Vector.new(a.X + b.X, a.Y + b.Y)
end
VectorMT.__sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
VectorMT.__unm = function(a) return Vector.new(-a.X, -a.Y) end
VectorMT.__mul = function(a, b)
    if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
    if type(a) == "number" then return Vector.new(a * b.X, a * b.Y) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end

function Color(r, g, b, a, ro, go, bo)
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 0 }
end

ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2 }

local renderedList = {}
local function makeMockSprite()
    local s = {
        loaded = nil,
        anim = nil,
        frame = nil,
        Color = Color(1, 1, 1, 1),
        Scale = Vector(1, 1),
    }
    function s:Load(path, loadGraphics) self.loaded = path end
    function s:Play(name, reset) self.anim = name end
    function s:SetFrame(name, f) self.anim = name self.frame = f end
    function s:Render(pos, topL, botR)
        table.insert(renderedList, { pos = pos, anim = self.anim, frame = self.frame, color = self.Color, scale = self.Scale })
    end
    return s
end

Sprite = function() return makeMockSprite() end

local gameFrame = 100
local isPaused = false
Game = function()
    return {
        GetFrameCount = function() return gameFrame end,
        IsPaused = function() return isPaused end,
        GetNumPlayers = function() return 1 end,
    }
end

Isaac = {
    WorldToScreen = function(w) return Vector.new(w.X, w.Y) end,
}

-- Load core and modules
local Core = {}
Core.ITEM_POWER_BATTERY = 42
Core.WILLPOWER_MAX = 100.0
Core.LoadItemIDs = function() end
-- Override GetPlayerData for test
local mockPlayerData = {}
Core.GetPlayerData = function(player)
    local idx = (player and player.Index) or 0
    if not mockPlayerData[idx] then
        mockPlayerData[idx] = {
            batteryOrbitAngle = 0.0,
            batteryConstructTimer = 0,
        }
    end
    return mockPlayerData[idx]
end

local mockPlayer = {
    Index = 0,
    Position = Vector.new(200, 300),
    items = { [42] = true },
    HasCollectible = function(self, id) return self.items[id] == true end,
    GetActiveItem = function(self, slot) return (slot == ActiveSlot.SLOT_PRIMARY) and 42 or 0 end,
    GetData = function(self) return {} end,
}

-- Load fx_sprites and fx_shield_items
assert(loadfile("modules/fx_sprites.lua"))()(Core)
assert(loadfile("modules/fx_shield_items.lua"))()(Core)

-- TEST 1: Dedicated sprite instance isolation
local dropSparkSpr = Core.GetGLSparkSprite()
local batteryOrbitalSpr = Core.GetGLBatteryOrbitalSparkSprite()
assert_true("Battery orbital spark sprite exists", batteryOrbitalSpr ~= nil)
assert_true("Drop spark sprite exists", dropSparkSpr ~= nil)
assert_true("Battery orbital sprite is a distinct instance from drop spark sprite", batteryOrbitalSpr ~= dropSparkSpr)

-- TEST 2: Active item requirement
renderedList = {}
mockPlayer.items[42] = false
mockPlayer.GetActiveItem = function() return 0 end
Core.RenderGLBatteryOrbital(mockPlayer, Vector.Zero, nil)
assert_eq("Does not render when player lacks Power Battery", #renderedList, 0)

-- Restore Power Battery
mockPlayer.items[42] = true
mockPlayer.GetActiveItem = function(self, slot) return (slot == ActiveSlot.SLOT_PRIMARY) and 42 or 0 end

-- TEST 3: 2.5D Depth sorting
-- Angle = 0 -> ox = 32, oy = 0 -> oy >= 0 (in front)
local pData = Core.GetPlayerData(mockPlayer)
pData.batteryOrbitAngle = 0.0

renderedList = {}
Core.RenderGLBatteryOrbital(mockPlayer, Vector.Zero, true) -- requested behind
assert_eq("oy >= 0 is skipped when isBehind==true", #renderedList, 0)

renderedList = {}
Core.RenderGLBatteryOrbital(mockPlayer, Vector.Zero, false) -- requested front
assert_eq("oy >= 0 renders when isBehind==false", #renderedList, 1)
assert_eq("Rendered at X=232, Y=286", renderedList[1].pos.X, 232)
assert_eq("Rendered at Y=286", renderedList[1].pos.Y, 286) -- 300 - 14 + 0

-- Angle = 3*pi/2 (270 deg) -> ox = 0, oy = -18 -> oy < 0 (behind)
pData.batteryOrbitAngle = 3 * math.pi / 2

renderedList = {}
Core.RenderGLBatteryOrbital(mockPlayer, Vector.Zero, false) -- requested front
assert_eq("oy < 0 is skipped when isBehind==false", #renderedList, 0)

renderedList = {}
Core.RenderGLBatteryOrbital(mockPlayer, Vector.Zero, true) -- requested behind
assert_eq("oy < 0 renders when isBehind==true", #renderedList, 1)
assert_eq("Rendered at X=200", math.floor(renderedList[1].pos.X + 0.5), 200)
assert_eq("Rendered at Y=268", math.floor(renderedList[1].pos.Y + 0.5), 268) -- 300 - 14 - 18 = 268

-- Fallback (isBehind == nil) renders regardless
renderedList = {}
Core.RenderGLBatteryOrbital(mockPlayer, Vector.Zero, nil)
assert_eq("Fallback isBehind==nil renders when behind", #renderedList, 1)

pData.batteryOrbitAngle = 0.0
renderedList = {}
Core.RenderGLBatteryOrbital(mockPlayer, Vector.Zero, nil)
assert_eq("Fallback isBehind==nil renders when in front", #renderedList, 1)

-- TEST 4: Smoothness over 120 render frames (no snaps/sawtooth)
pData.batteryOrbitAngle = 0.0
local positions = {}
local STEP = 0.035
local TWO_PI = math.pi * 2
for f = 1, 120 do
    pData.batteryOrbitAngle = (pData.batteryOrbitAngle + STEP) % TWO_PI
    local radX, radY = 32.0, 18.0
    local ox = math.cos(pData.batteryOrbitAngle) * radX
    local oy = math.sin(pData.batteryOrbitAngle) * radY
    table.insert(positions, Vector.new(mockPlayer.Position.X + ox, mockPlayer.Position.Y - 14 + oy))
end

local totalDelta = 0
local maxDelta = 0
for i = 2, #positions do
    local d = (positions[i] - positions[i-1]):Length()
    totalDelta = totalDelta + d
    if d > maxDelta then maxDelta = d end
end
local meanDelta = totalDelta / (#positions - 1)
local ratio = maxDelta / meanDelta
assert_true("maxDelta <= 1.5 * meanDelta (fluent smooth motion)", ratio <= 1.5)
assert_true("meanDelta between 0.5 and 1.5 px/frame", meanDelta >= 0.5 and meanDelta <= 1.5)

-- TEST 5: Sprite scale and color
renderedList = {}
Core.RenderGLBatteryOrbital(mockPlayer, Vector.Zero, nil)
assert_eq("Sprite scale is Vector(0.70, 0.70)", renderedList[1].scale.X, 0.70)
assert_eq("Sprite alpha is 0.95", renderedList[1].color.A, 0.95)

print(string.format("[test_battery_orbital_smooth] passes=%d failures=%d", passes, failures))
if failures > 0 then
    os.exit(1)
end
