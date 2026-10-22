-- tools/test_lote2_decisions.lua
-- Harness para las 5 decisiones del Lote 2 de la auditoria:
-- D1 blend de tintes, D2 clamp de escala, D3 lagrima del motor visible (beam),
-- D4 Lost Contact flash sin falsos positivos, D5 willpower exacto en continue.

local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end
local function approx(a, b, eps)
    eps = eps or 0.0001
    return math.abs((a or 0) - (b or 0)) < eps
end
local function checkColor(got, expected, label)
    check(approx(got.R, expected.R), label .. " R expected " .. tostring(expected.R) .. " got " .. tostring(got.R))
    check(approx(got.G, expected.G), label .. " G expected " .. tostring(expected.G) .. " got " .. tostring(got.G))
    check(approx(got.B, expected.B), label .. " B expected " .. tostring(expected.B) .. " got " .. tostring(got.B))
    check(approx(got.A, expected.A), label .. " A expected " .. tostring(expected.A) .. " got " .. tostring(got.A))
    check(approx(got.RO or 0, expected.RO or 0), label .. " RO expected " .. tostring(expected.RO or 0) .. " got " .. tostring(got.RO or 0))
    check(approx(got.GO or 0, expected.GO or 0), label .. " GO expected " .. tostring(expected.GO or 0) .. " got " .. tostring(got.GO or 0))
    check(approx(got.BO or 0, expected.BO or 0), label .. " BO expected " .. tostring(expected.BO or 0) .. " got " .. tostring(got.BO or 0))
end

-- ===================== STUBS =====================
CollectibleType = {
    COLLECTIBLE_SOY_MILK = 330,
    COLLECTIBLE_LOST_CONTACT = 213,
    COLLECTIBLE_MIDAS_TOUCH = 202,
    COLLECTIBLE_SACRED_HEART = 182,
    COLLECTIBLE_DEATHS_TOUCH = 187,
    COLLECTIBLE_8_INCH_NAILS = 359,
    COLLECTIBLE_TECHNOLOGY = 68,
    COLLECTIBLE_TECH_X = 395,
}
Direction = { RIGHT = 0, LEFT = 1, UP = 2, DOWN = 3 }
FamiliarVariant = { INCUBUS = 80, SUCCUBUS = 96 }
EntityType = { ENTITY_TEAR = 2, ENTITY_EFFECT = 1000 }
TearVariant = { DEFAULT = 0 }
TearFlags = {
    TEAR_PIERCING = 1,
    TEAR_SPECTRAL = 2,
    TEAR_FEAR = 4,
    TEAR_TRACTOR_BEAM = 8,
    TEAR_WIGGLE = 16,
}
EffectVariant = { WATER_SPLASH = 1 }
SoundEffect = { SOUND_TEARIMPACTS = 1, SOUND_PUNCH = 2 }
ModCallbacks = {
    MC_POST_FIRE_TEAR = 1,
    MC_POST_TEAR_UPDATE = 2,
    MC_PRE_TEAR_COLLISION = 3,
    MC_POST_TEAR_RENDER = 4,
    MC_POST_GAME_STARTED = 5,
    MC_POST_PLAYER_INIT = 6,
    MC_POST_NEW_LEVEL = 7,
    MC_PRE_GAME_EXIT = 8,
}
CacheFlag = { CACHE_FLYING = 1, CACHE_SPEED = 2, CACHE_DAMAGE = 4, CACHE_SHOTSPEED = 8, CACHE_TEARFLAG = 16, CACHE_FIREDELAY = 32 }
ActiveSlot = { SLOT_PRIMARY = 0, SLOT_POCKET = 2 }

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
        __eq = VectorMT.__eq,
    })
    return t
end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function Vector:Normalized()
    local l = self:Length()
    if l <= 0.001 then return Vector.new(1, 0) end
    return Vector.new(self.X / l, self.Y / l)
end
function Vector:GetAngleDegrees() return math.deg(math.atan2(self.Y, self.X)) end
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
VectorMT.__eq = function(a, b)
    return type(a) == "table" and type(b) == "table"
        and math.abs(a.X - b.X) < 1e-9 and math.abs(a.Y - b.Y) < 1e-9
end

function Color(r, g, b, a, ro, go, bo)
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 0, RO = ro or 0, GO = go or 0, BO = bo or 0 }
end

-- Minimal json para save_run.lua (tablas planas con numeros/booleanos/strings).
json = {}
local function jsonEncVal(v, out)
    local t = type(v)
    if t == "boolean" then out[#out + 1] = v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "0"
        else out[#out + 1] = string.format("%.17g", v) end
    elseif t == "string" then out[#out + 1] = string.format("%q", v)
    elseif t == "table" then
        out[#out + 1] = "{"
        local first = true
        for k, vv in pairs(v) do
            if not first then out[#out + 1] = "," end
            first = false
            out[#out + 1] = string.format("%q", tostring(k))
            out[#out + 1] = ":"
            jsonEncVal(vv, out)
        end
        out[#out + 1] = "}"
    else error("json: unsupported type " .. t) end
end
function json.encode(v)
    local out = {}
    jsonEncVal(v, out)
    return table.concat(out)
end
function json.decode(s)
    if type(s) ~= "string" then error("json: expected string") end
    local pos, n = 1, #s
    local function skipWs() while pos <= n and s:sub(pos, pos):match("%s") do pos = pos + 1 end end
    local parseVal
    local function parseStr()
        pos = pos + 1
        local buf = {}
        while pos <= n do
            local c = s:sub(pos, pos)
            if c == '"' then pos = pos + 1 return table.concat(buf)
            elseif c == "\\" then
                local e = s:sub(pos + 1, pos + 1)
                if e == "n" then buf[#buf + 1] = "\n"
                elseif e == "r" then buf[#buf + 1] = "\r"
                elseif e == "t" then buf[#buf + 1] = "\t"
                elseif e == '"' then buf[#buf + 1] = '"'
                elseif e == "\\" then buf[#buf + 1] = "\\"
                else buf[#buf + 1] = e end
                pos = pos + 2
            else buf[#buf + 1] = c; pos = pos + 1 end
        end
        error("json: unterminated string")
    end
    local function parseNum()
        local ns, ne = s:find("^%-?%d+%.?%d*", pos)
        if not ns then error("json: bad number") end
        local es, ee = s:find("^[eE][%+\-]?%d+", ne + 1)
        if es then ne = ee end
        local num = tonumber(s:sub(ns, ne))
        if num == nil then error("json: bad number") end
        pos = ne + 1
        return num
    end
    local function parseObj()
        pos = pos + 1
        local out = {}
        skipWs()
        if s:sub(pos, pos) == "}" then pos = pos + 1 return out end
        while true do
            skipWs()
            if s:sub(pos, pos) ~= '"' then error("json: expected key") end
            local k = parseStr()
            skipWs()
            if s:sub(pos, pos) ~= ":" then error("json: expected colon") end
            pos = pos + 1
            out[k] = parseVal()
            skipWs()
            local c = s:sub(pos, pos)
            if c == "," then pos = pos + 1
            elseif c == "}" then pos = pos + 1 return out
            else error("json: expected comma or close") end
        end
    end
    parseVal = function()
        skipWs()
        local c = s:sub(pos, pos)
        if c == "{" then return parseObj()
        elseif c == '"' then return parseStr()
        elseif c == "t" and s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
        elseif c == "f" and s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
        elseif c == "-" or c:match("%d") then return parseNum()
        else error("json: corrupt") end
    end
    local v = parseVal()
    skipWs()
    if pos <= n then error("json: trailing data") end
    if type(v) ~= "table" then error("json: top-level must be object") end
    return v
end

local _modDataStore = nil
local _modDataExists = false
function RegisterMod(_, _)
    local mod = { _cbs = {} }
    function mod:AddCallback(cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end
    function mod:SaveModData(s) _modDataStore = s; _modDataExists = true end
    function mod:LoadModData() return _modDataStore end
    function mod:HasModData() return _modDataExists end
    return mod
end

local _testPlayers = {}
function Game()
    return {
        GetNumPlayers = function() return #_testPlayers end,
        GetFrameCount = function() return 0 end,
        GetLevel = function() return { GetCurrentRoomIndex = function() return 0 end, GetStage = function() return 1 end } end,
    }
end
Isaac = { GetPlayer = function(i) return _testPlayers[i + 1] end }
SFXManager = function()
    return { Play = function() end }
end

-- ===================== HELPERS =====================
local function loadModule(path)
    local f = assert(io.open(path, "r"))
    local src = f:read("*a")
    f:close()
    -- Lua 5.1 CLI no entiende operadores bitwise (| & ~). Reemplazo seguro
    -- para syntax-check; los flags usados son disjuntos, '+' equivale a OR.
    src = src:gsub("([%a%d_%)%]])%s*|%s*", "%1 + ")
    src = src:gsub("([%a%d_%)%]])%s*&%s*", "%1 + ")
    src = src:gsub("~([%a%d_(%[])", "-%1")
    local chunk, err = loadstring(src, path)
    assert(chunk, tostring(err))
    return chunk()
end

local function cbsFor(id)
    local out = {}
    for _, c in ipairs(Core.GL._cbs) do
        if c.id == id then table.insert(out, c.fn) end
    end
    return out
end
local function fire(id, ...)
    for _, fn in ipairs(cbsFor(id)) do fn(nil, ...) end
end

local function makePlayer(items)
    local map = {}
    for _, id in ipairs(items or {}) do map[id] = true end
    return {
        HasCollectible = function(_, id) return map[id] == true end,
    }
end

-- ===================== D1: BLEND DE TINTES =====================
Core = dofile("modules/core.lua")
Core.GetMaxWillpower = function() return Core.WILLPOWER_MAX end
Core.IsHalJordan = function(p) return p ~= nil and p._isHal == true end
Core.IsTaintedHal = function(p) return p ~= nil and p._isTainted == true end
Core.IsRingActive = function() return true end
Core.RestoreHalRingPower = function() end
Core.TriggerHalRingDepleted = function() end
Core.SetEntityScaleAndColor = function() end
local tintFactory = dofile("modules/synergies_ring_tint.lua")
check(type(tintFactory) == "function", "D1: synergies_ring_tint factory")
tintFactory(Core)
check(type(Core.GetRingBeamVisual) == "function", "D1: GetRingBeamVisual definida")

local MIDAS_TINT = Color(1.0, 0.95, 0.35, 1.0, 0.55, 0.45, 0.05)
local SACRED_TINT = Color(1, 1, 1, 1, 0, 0, 0)
local DEATH_TINT = Color(0.35, 0.95, 0.5, 1.0, 0, 0, 0)

local function blendGeom(colors)
    local n = #colors
    local r, g, b = 1, 1, 1
    local a, ro, go, bo = 0, 0, 0, 0
    for _, c in ipairs(colors) do
        r = r * c.R; g = g * c.G; b = b * c.B
        a = a + c.A; ro = ro + (c.RO or 0); go = go + (c.GO or 0); bo = bo + (c.BO or 0)
    end
    local invN = 1.0 / n
    local function clamp01(x) return math.max(0, math.min(1, x)) end
    return { R = clamp01(r ^ invN), G = clamp01(g ^ invN), B = clamp01(b ^ invN),
             A = clamp01(a / n), RO = ro / n, GO = go / n, BO = bo / n }
end

local t1, s1 = Core.GetRingBeamVisual(makePlayer({CollectibleType.COLLECTIBLE_MIDAS_TOUCH, CollectibleType.COLLECTIBLE_SACRED_HEART}))
checkColor(t1, blendGeom({MIDAS_TINT, SACRED_TINT}), "D1: Midas + Sacred Heart blend")
check(not (approx(t1.R, 1) and approx(t1.G, 1) and approx(t1.B, 1)), "D1: Midas + Sacred no es blanco puro")

local t2, s2 = Core.GetRingBeamVisual(makePlayer({CollectibleType.COLLECTIBLE_DEATHS_TOUCH, CollectibleType.COLLECTIBLE_SACRED_HEART}))
checkColor(t2, blendGeom({DEATH_TINT, SACRED_TINT}), "D1: Death's Touch + Sacred Heart blend")
check(t2.G > t2.R and t2.G > t2.B, "D1: Death + Sacred conserva tonalidad verde")

-- ===================== D2: CLAMP DE ESCALA =====================
local aimFactory = loadModule("modules/ring_aim.lua")
check(type(aimFactory) == "function", "D2: ring_aim factory")
aimFactory(Core)
check(Core.GL_BEAM_MAX_SCALE == 2.25, "D2: constante GL_BEAM_MAX_SCALE definida")

local function makeTear(player)
    local spr = {
        Animation = "",
        Scale = Vector.Zero,
        Color = Color(1, 1, 1, 1, 0, 0, 0),
        Rotation = 0,
        Load = function(self, path) end,
        Play = function(self, anim) self.Animation = anim end,
        GetAnimation = function(self) return self.Animation end,
    }
    local data = {}
    return {
        SpawnerEntity = player,
        Velocity = Vector(1, 0),
        Position = Vector(0, 0),
        Visible = true,
        FallingAcceleration = 0,
        FallingSpeed = 0,
        DepthOffset = 0,
        GetSprite = function() return spr end,
        GetData = function() return data end,
    }, data, spr
end

local highScalePlayer = makePlayer({
    CollectibleType.COLLECTIBLE_8_INCH_NAILS,
    CollectibleType.COLLECTIBLE_LOST_CONTACT,
    CollectibleType.COLLECTIBLE_DEATHS_TOUCH,
    CollectibleType.COLLECTIBLE_SACRED_HEART,
})
function highScalePlayer:ToPlayer() return self end
local tear2, td2, spr2 = makeTear(highScalePlayer)
Core.ApplyRingBeamSprite(tear2, 1.5)
check(td2.glBeamScale <= Core.GL_BEAM_MAX_SCALE, "D2: escala final clampada a <= " .. tostring(Core.GL_BEAM_MAX_SCALE) .. " (fue " .. tostring(td2.glBeamScale) .. ")")

-- ===================== D3: VISIBLE=TRUE TRAS ENFORCE =====================
local beamFactory = loadModule("modules/beam_discrete.lua")
check(type(beamFactory) == "function", "D3: beam_discrete factory")
-- Core.ApplyRingBeamSprite ya esta cargado desde ring_aim.
beamFactory(Core)

local function makeBeamTear()
    local spr = {
        Animation = "Idle",
        Scale = Vector(1, 1),
        Color = Color(1, 1, 1, 1, 0, 0, 0),
        Rotation = 0,
        Load = function(self, path) end,
        Play = function(self, anim) self.Animation = anim end,
        GetAnimation = function(self) return self.Animation end,
    }
    local data = { isGLRingBeam = true, glBeamScale = 1.3, glBeamTint = Color(0.1, 1.0, 0.2, 0.9, 0, 0, 0) }
    return {
        SpawnerEntity = nil,
        Velocity = Vector(1, 0),
        Position = Vector(0, 0),
        Visible = false,
        GetSprite = function() return spr end,
        GetData = function() return data end,
    }, data, spr
end

local tear3, td3, spr3 = makeBeamTear()
local renderCbs = cbsFor(ModCallbacks.MC_POST_TEAR_RENDER)
check(#renderCbs >= 1, "D3: POST_TEAR_RENDER registrado")
renderCbs[1](nil, tear3, Vector.Zero)
check(tear3.Visible == true, "D3: el enforcement deja la lagrima del motor visible (el beam lo dibuja el motor)")
check(spr3.Color.A > 0.01, "D3: color del sprite restaurado (no transparente)")

-- ===================== D4: LOST CONTACT SIN FALSOS POSITIVOS =====================
local synFactory = loadModule("modules/beam_synergies.lua")
check(type(synFactory) == "function", "D4: beam_synergies factory")
synFactory(Core)

local spawnCalls = {}
Isaac.Spawn = function(_, variant, sub, pos, vel, spawner)
    table.insert(spawnCalls, { variant = variant, pos = pos })
    return nil
end

local lostContactPlayer = makePlayer({CollectibleType.COLLECTIBLE_LOST_CONTACT})
function lostContactPlayer:ToPlayer() return self end
function lostContactPlayer:HasCollectible(id) return id == CollectibleType.COLLECTIBLE_LOST_CONTACT end

local function makeTearEntity(player)
    local data = {}
    return {
        SpawnerEntity = player,
        Position = Vector(0, 0),
        Velocity = Vector(1, 0),
        GetData = function() return data end,
        ToTear = function(self) return self end,
        TearFlags = 0,
    }, data
end

local playerTear, _ = makeTearEntity(lostContactPlayer)
local friendlyTear, _ = makeTearEntity(lostContactPlayer)
friendlyTear.SpawnerEntity = nil -- desconocido: no debe generar flash
local collisionCbs = cbsFor(ModCallbacks.MC_PRE_TEAR_COLLISION)
check(#collisionCbs >= 1, "D4: PRE_TEAR_COLLISION registrado")
-- beam_synergies registra el segundo callback de collision; usamos el ultimo.
local synCollisionCb = collisionCbs[#collisionCbs]
spawnCalls = {}
synCollisionCb(nil, playerTear, friendlyTear, false)
check(#spawnCalls == 0, "D4: spawner nil -> sin flash de Lost Contact")

-- ===================== D5: WILLPOWER EXACTO AL CONTINUAR =====================
Core = dofile("modules/core.lua")
Core.GetMaxWillpower = function() return Core.WILLPOWER_MAX end
Core.IsHalJordan = function(p) return p ~= nil and p._isHal == true end
Core.IsTaintedHal = function(p) return p ~= nil and p._isTainted == true end
Core.LoadItemIDs = function() end
Core.RefreshCharacterCostume = function() end

local saveFactory = loadModule("modules/save_run.lua")
local initFactory = loadModule("modules/init_players.lua")
check(type(saveFactory) == "function", "D5: save_run factory")
check(type(initFactory) == "function", "D5: init_players factory")
saveFactory(Core)
initFactory(Core)

local function makeGamePlayer(idx, isHal, isTainted)
    local data = {}
    local p = {
        Index = idx,
        _data = data,
        _isHal = (isHal == true),
        _isTainted = (isTainted == true),
        _cacheFlags = 0,
    }
    function p:GetData() return self._data end
    function p:GetPlayerType() return 0 end
    function p:ToPlayer() return self end
    function p:SetPocketActiveItem() end
    function p:FullCharge() end
    function p:AddCacheFlags(flags) self._cacheFlags = self._cacheFlags + flags end
    function p:EvaluateItems() end
    function p:HasCollectible() return false end
    function p:GetActiveItem() return 0 end
    return p
end

_testPlayers = { makeGamePlayer(0, true) }
local p = _testPlayers[1]
local d = Core.GetPlayerData(p)
d.willpower = 33.75
d.ringDepleted = true
d.overcharge = true
d.overchargeTier = 2

fire(ModCallbacks.MC_PRE_GAME_EXIT)

-- Simula sesion fresca: POST_GAME_STARTED(true) restaura y marca flag,
-- luego POST_PLAYER_INIT no debe pisar willpower/ringDepleted/overcharge/tier.
p._data = {}
fire(ModCallbacks.MC_POST_GAME_STARTED, true)
fire(ModCallbacks.MC_POST_PLAYER_INIT, p)

local rd = Core.GetPlayerData(p)
check(approx(rd.willpower, 33.75), "D5: willpower restaurado exacto (fue " .. tostring(rd.willpower) .. ")")
check(rd.ringDepleted == true, "D5: ringDepleted restaurado")
check(rd.overcharge == true, "D5: overcharge restaurado")
check(rd.overchargeTier == 2, "D5: overchargeTier restaurado")

-- Partida nueva: POST_GAME_STARTED(false) no restaura, POST_PLAYER_INIT resetea.
p._data = {}
d = Core.GetPlayerData(p)
d.willpower = 12.0
d.ringDepleted = true
d.overcharge = true
d.overchargeTier = 2
fire(ModCallbacks.MC_POST_GAME_STARTED, false)
fire(ModCallbacks.MC_POST_PLAYER_INIT, p)
rd = Core.GetPlayerData(p)
check(approx(rd.willpower, Core.WILLPOWER_MAX), "D5: partida nueva -> willpower MAX")
check(rd.ringDepleted == false, "D5: partida nueva -> ringDepleted false")
check(rd.overcharge == false, "D5: partida nueva -> overcharge false")
check(rd.overchargeTier == 0, "D5: partida nueva -> overchargeTier 0")

-- Tainted Hal: sparks/rings se preservan en continue.
_testPlayers = { makeGamePlayer(0, false, true) }
p = _testPlayers[1]
d = Core.GetPlayerData(p)
d.emeraldSparks = 77.5
d.stolenRings = 4
fire(ModCallbacks.MC_PRE_GAME_EXIT)
p._data = {}
fire(ModCallbacks.MC_POST_GAME_STARTED, true)
fire(ModCallbacks.MC_POST_PLAYER_INIT, p)
rd = Core.GetPlayerData(p)
check(approx(rd.emeraldSparks, 77.5), "D5: Tainted Hal emeraldSparks restaurado")
check(rd.stolenRings == 4, "D5: Tainted Hal stolenRings restaurado")

-- ===================== RESUMEN =====================
print(string.format("test_lote2_decisions.lua: %d passed, %d failed", passes, failures))
if failures > 0 then os.exit(1) end
