-- tools/test_coastcity_owner.lua
-- F6: al expirar/cambiar de sala UN vortice, apagar coastCityActive=false
-- SOLO del dueno (cc.owner, fallback al comportamiento actual si owner es nil).
-- Resto (duracion/dano/pull/multiples vortices) intacto.
-- Compatible con Lua 5.1.

-- ===================== STUBS Vector/Color =====================
Vector = {}
local VectorMT = {}
function Vector.new(x, y)
    local u = setmetatable({X = x or 0, Y = y or 0}, {
        __index = Vector,
        __add = VectorMT.__add,
        __sub = VectorMT.__sub,
        __unm = VectorMT.__unm,
        __mul = VectorMT.__mul,
    })
    return u
end
setmetatable(Vector, {__call = function(_, x, y) return Vector.new(x, y) end})
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
    local l = self:Length()
    if l <= 0.001 then return Vector.new(1, 0) end
    return Vector.new(self.X / l, self.Y / l)
end
function Color(r, g, b, a, ro, go, bo)
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 0, ROff = ro, GOff = go, BOff = bo }
end
VectorMT.__add = function(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end
VectorMT.__sub = function(a, b) return Vector.new(a.X - b.X, a.Y - b.Y) end
VectorMT.__unm = function(a) return Vector.new(-a.X, -a.Y) end
VectorMT.__mul = function(a, b)
    if type(b) == "number" then return Vector.new(a.X * b, a.Y * b) end
    if type(a) == "number" then return Vector.new(a * b.X, a * b.Y) end
    return Vector.new(a.X * b.X, a.Y * b.Y)
end

-- ===================== STUBS ISAAC =====================
Isaac = {}
_testPlayers = {}
function Isaac.GetRoomEntities() return {} end
function Isaac.GetPlayer(i) return _testPlayers[i] end
function Isaac.Spawn() return { GetSprite = function() return { Color = nil } end, Scale = 1 } end

SoundEffect = { SOUND_SUPERHOLY = 1, SOUND_HELL_PORTAL2 = 2 }
DamageFlag = { DAMAGE_NO_MODIFIERS = 33554432 }
EntityRef = function(_) return {} end
EntityFlag = { FLAG_FEAR = 1 }
EntityType = { ENTITY_EFFECT = 1003 }
EffectVariant = { WATER_SPLASH = 38 }

_frameCount = 0
_currentRoomIdx = 7
_numPlayers = 1
function Game() return {
    GetNumPlayers = function() return _numPlayers end,
    GetFrameCount = function() return _frameCount end,
    GetLevel = function() return { GetCurrentRoomIndex = function() return _currentRoomIdx end } end,
    GetRoom = function() return { GetCenterPos = function() return Vector.new(0, 0) end } end,
    ShakeScreen = function() end,
} end
function SFXManager() return { Play = function() end } end
ModCallbacks = { MC_USE_ITEM = 100, MC_POST_UPDATE = 1 }

-- ===================== STUBS CORE =====================
local Core = {}
Core.GL = {
    _cbs = {},
    AddCallback = function(self, cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end,
}
Core.ITEM_COAST_CITY = 51
Core.LoadItemIDs = function() end
Core.SPARK_MAX = 100.0
Core.COAST_CITY_DURATION = 150
Core.activeCoastCityByPlayer = {}
local dataByPlayer = {}
function Core.GetPlayerData(player)
    if not dataByPlayer[player.Index] then
        dataByPlayer[player.Index] = { coastCityActive = false, coastCityFrame = 0 }
    end
    return dataByPlayer[player.Index]
end
Core.IsTaintedHal = function(p) return p._isTainted end
function Core.GetCoastCity(player)
    local key = (player and player.Index) or 0
    local cc = Core.activeCoastCityByPlayer[key]
    if not cc then
        cc = { active = false, spawnFrame = 0, roomIdx = -1, owner = nil, sparkBonus = 1.0 }
        Core.activeCoastCityByPlayer[key] = cc
    end
    return cc
end

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1
    else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end
local function makeTainted(idx)
    return {
        Index = idx, _isTainted = true,
        Position = Vector.new(0, 0), Damage = 5.0,
        AnimateHappy = function() end,
    }
end
local function findPostUpdate()
    for _, c in ipairs(Core.GL._cbs) do
        if c.id == ModCallbacks.MC_POST_UPDATE then return c.fn end
    end
    return nil
end
local function loadCoastCity()
    local factory = dofile("modules/item_coastcity.lua")
    factory(Core)
end

-- ===================== CASO 1: 2P expira P1 =====================
-- P1 (owner idx 0) expirado por duracion; P2 (owner idx 1) fresco.
-- Tras POST_UPDATE: P1 false, P2 true intacto; cc1.active=false, cc2.active=true.
Core.GL._cbs = {}
Core.activeCoastCityByPlayer = {}
dataByPlayer = {}
loadCoastCity()
local postCb = findPostUpdate()
check(postCb ~= nil, "F6(1): item_coastcity.lua registra MC_POST_UPDATE")

local p1 = makeTainted(0)
local p2 = makeTainted(1)
_testPlayers = { [0] = p1, [1] = p2 }
_numPlayers = 2
dataByPlayer[0] = { coastCityActive = true, coastCityFrame = 0 }
dataByPlayer[1] = { coastCityActive = true, coastCityFrame = 0 }
Core.activeCoastCityByPlayer = {
    [0] = { active = true, spawnFrame = 0, roomIdx = 7, owner = p1, sparkBonus = 1.0, totalDuration = 150 },
    [1] = { active = true, spawnFrame = 190, roomIdx = 7, owner = p2, sparkBonus = 1.0, totalDuration = 150 },
}
_frameCount = 200
_currentRoomIdx = 7
postCb()

check(Core.activeCoastCityByPlayer[0].active == false,
    "F6(1): el vortice expirado de P1 queda cc.active=false")
check(dataByPlayer[0].coastCityActive == false,
    "F6(1): al expirar P1, P1.coastCityActive=false")
check(Core.activeCoastCityByPlayer[1].active == true,
    "F6(1): el vortice fresco de P2 sigue cc.active=true")
check(dataByPlayer[1].coastCityActive == true,
    "F6(1): al expirar P1, P2.coastCityActive sigue true (no se apaga el dueno ajeno)")

-- ===================== CASO 2: single-player intacto =====================
Core.GL._cbs = {}
Core.activeCoastCityByPlayer = {}
dataByPlayer = {}
loadCoastCity()
postCb = findPostUpdate()
local ps = makeTainted(0)
_testPlayers = { [0] = ps }
_numPlayers = 1
dataByPlayer[0] = { coastCityActive = true, coastCityFrame = 0 }
Core.activeCoastCityByPlayer = {
    [0] = { active = true, spawnFrame = 0, roomIdx = 7, owner = ps, sparkBonus = 1.0, totalDuration = 150 },
}
_frameCount = 200
_currentRoomIdx = 7
postCb()
check(dataByPlayer[0].coastCityActive == false,
    "F6(2): single-player expirado apaga su propio coastCityActive=false")
check(Core.activeCoastCityByPlayer[0].active == false,
    "F6(2): single-player expirado queda cc.active=false")

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_coastcity_owner] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
