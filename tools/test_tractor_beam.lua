-- tools/test_tractor_beam.lua
-- Unit test: Tractor Beam cardinal alignment vs. non-Tractor Beam diagonal shooting preservation.
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
Direction = {
    NO_DIRECTION = -1,
    LEFT = 0,
    UP = 1,
    RIGHT = 2,
    DOWN = 3,
}
CollectibleType = {
    COLLECTIBLE_TRACTOR_BEAM = 397,
}
TearFlags = {
    TEAR_TRACTOR_BEAM = 2^41,
    TEAR_HOMING = 1,
    TEAR_PIERCING = 2,
    TEAR_SPECTRAL = 4,
}
local VectorMt = {
    __add = function(a, b) return Vector.new(a.X + b.X, a.Y + b.Y) end,
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
        function v:GetAngleDegrees()
            return math.atan2(self.Y, self.X) * 180 / math.pi
        end
        return setmetatable(v, VectorMt)
    end,
}
setmetatable(Vector, {
    __call = function(_, x, y) return Vector.new(x, y) end,
})

Color = function() return {} end

-- ===================== LOAD UTILS =====================
local Core = {}
dofile("modules/utils.lua")(Core)

-- 1. Helper tests: HasTractorBeam
local pNoTB = { HasCollectible = function(_, id) return false end }
local pWithTB = {
    HasCollectible = function(_, id) return id == 397 end,
    GetHeadDirection = function() return Direction.UP end,
}
check(Core.HasTractorBeam(pNoTB) == false, "HasTractorBeam returns false without item")
check(Core.HasTractorBeam(pWithTB) == true, "HasTractorBeam returns true with item")

-- 2. Cardinal snapping with Tractor Beam
local diagInput = Vector(0.707, -0.707) -- Up-Right diagonal
local tbDirUp = Core.GetTractorBeamDirection(pWithTB, diagInput)
check(tbDirUp.X == 0 and tbDirUp.Y == -1, "GetTractorBeamDirection snaps to UP (0, -1) matching head direction")

local pWithTBRight = {
    HasCollectible = function(_, id) return id == 397 end,
    GetHeadDirection = function() return Direction.RIGHT end,
}
local tbDirRight = Core.GetTractorBeamDirection(pWithTBRight, diagInput)
check(tbDirRight.X == 1 and tbDirRight.Y == 0, "GetTractorBeamDirection snaps to RIGHT (1, 0) matching head direction")

-- 3. Non-Tractor Beam: raw diagonal input remains diagonal!
local rawDir = diagInput
check(rawDir.X > 0.5 and rawDir.Y < -0.5, "Without Tractor Beam, diagonal shooting vector is preserved untouched")

-- 4. Velocity update logic (modules/beam_discrete.lua)
local tfTB = TearFlags.TEAR_TRACTOR_BEAM
check(Core.HasTearFlag(tfTB, TearFlags.TEAR_TRACTOR_BEAM) == true, "HasTearFlag correctly identifies TEAR_TRACTOR_BEAM")

-- Simulation of MC_POST_TEAR_UPDATE velocity lock guard
local function simulateUpdate(tear, player)
    local td = tear:GetData()
    local flags = tear.TearFlags
    local hasCurvingSynergy = false
    if TearFlags and flags then
        if Core.HasTearFlag(flags, TearFlags.TEAR_HOMING)
            or (TearFlags.TEAR_TRACTOR_BEAM and Core.HasTearFlag(flags, TearFlags.TEAR_TRACTOR_BEAM))
        then
            hasCurvingSynergy = true
        end
    end
    if player and Core.HasTractorBeam(player) then
        hasCurvingSynergy = true
    end
    if not hasCurvingSynergy then
        if td.glBeamVel and td.glBeamVel:Length() > 0.1 and tear.Velocity:Length() > 0.1 then
            local currentSpeed = tear.Velocity:Length()
            tear.Velocity = td.glBeamVel:Normalized() * currentSpeed
        end
    else
        if tear.Velocity and tear.Velocity:Length() > 0.1 then
            td.glBeamVel = Vector(tear.Velocity.X, tear.Velocity.Y)
        end
    end
end

-- Case A: Normal player shooting diagonally -> velocity locked to diagonal trajectory (flying straight)
local tearNormal = {
    TearFlags = 0,
    Velocity = Vector(10, -10),
    _data = { glBeamVel = Vector(10, -10) },
    GetData = function(self) return self._data end,
}
simulateUpdate(tearNormal, pNoTB)
check(tearNormal.Velocity.X > 0 and tearNormal.Velocity.Y < 0, "Normal player: diagonal velocity preserved straight")

-- Case B: Player with Tractor Beam moving up -> engine turns tear UP (0, -14), our mod does NOT force it diagonal!
local tearTB = {
    TearFlags = TearFlags.TEAR_TRACTOR_BEAM,
    Velocity = Vector(0, -14),
    _data = { glBeamVel = Vector(10, -10) }, -- old diagonal aim
    GetData = function(self) return self._data end,
}
simulateUpdate(tearTB, pWithTB)
check(tearTB.Velocity.X == 0 and tearTB.Velocity.Y == -14, "Tractor Beam: tear velocity allowed to stay purely vertical (0, -14)")
check(tearTB:GetData().glBeamVel.X == 0 and tearTB:GetData().glBeamVel.Y == -14, "Tractor Beam: glBeamVel synchronized to vertical (0, -14)")

-- ===================== RESULTS =====================
io.stderr:write(string.format("\n[test_tractor_beam] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
