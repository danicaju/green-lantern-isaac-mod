-- tools/test_user_fixes_synergies.lua
-- Unit test for user fixes:
-- 1. Primary fire & Giant Fist tear invisibility
-- 2. Costume stripping on Hal Jordan and Tainted Hal
-- 3. Tainted Hal 5% fear effect per tick
-- 4. Spark decay disabled & drop rate buffed
-- 5. Mutant Spider & multi-shot angles for both firing modes
-- 6. Epic Fetus synergy allowed in CanUseContinuousBeam
-- Compatible with Lua 5.1.

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1
  else failures = failures + 1; io.stderr:write("FAIL: " .. tostring(msg) .. "\n") end
end

-- ===================== STUBS =====================
Vector = {}
function Vector.new(x, y) return { X = x or 0, Y = y or 0 } end
setmetatable(Vector, { __call = function(_, x, y) return Vector.new(x, y) end })
function Vector.Zero() return Vector.new(0, 0) end

function Color(r, g, b, a, ro, go, bo)
  return { R = r or 0, G = g or 0, B = b or 0, A = a or 0 }
end

ModCallbacks = {
  MC_POST_UPDATE = 1001,
  MC_POST_PLAYER_UPDATE = 1002,
}

CollectibleType = {
  COLLECTIBLE_MUTANT_SPIDER = 153,
  COLLECTIBLE_QUAD_SHOT = 153,
  COLLECTIBLE_INNER_EYE = 2,
  COLLECTIBLE_20_20 = 245,
  COLLECTIBLE_THE_WIZ = 398,
  COLLECTIBLE_EPIC_FETUS = 168,
  COLLECTIBLE_BRIMSTONE = 118,
  COLLECTIBLE_TECHNOLOGY = 68,
}

function RegisterMod(_, _)
  local mod = { _cbs = {} }
  function mod:AddCallback(cbId, fn) table.insert(self._cbs, { id = cbId, fn = fn }) end
  return mod
end

local Core = dofile("modules/core.lua")

-- ===================== TEST 1: CONSTANTS =====================
check(Core.TAINTED_FEAR_CHANCE == 0.05, string.format("TAINTED_FEAR_CHANCE must be 0.05 (5%%), was %s", tostring(Core.TAINTED_FEAR_CHANCE)))
check(Core.SPARK_DECAY_PER_SEC == 0.0, string.format("SPARK_DECAY_PER_SEC must be 0 (no gradual drain), was %s", tostring(Core.SPARK_DECAY_PER_SEC)))
check(Core.SPARK_DROP_CHANCE_NORMAL >= 0.20, string.format("SPARK_DROP_CHANCE_NORMAL must be >= 0.20, was %s", tostring(Core.SPARK_DROP_CHANCE_NORMAL)))
check(Core.SPARK_DROP_CHANCE_FEARED >= 0.40, string.format("SPARK_DROP_CHANCE_FEARED must be >= 0.40, was %s", tostring(Core.SPARK_DROP_CHANCE_FEARED)))

-- ===================== TEST 2: BEAM MATH & SYNERGIES =====================
local fMath = assert(io.open("modules/beam_math.lua", "r"))
local srcMath = fMath:read("*a"); fMath:close()
srcMath = srcMath:gsub("|", "+")
local chunkMath = assert(loadstring(srcMath, "modules/beam_math.lua"))
chunkMath()(Core)

Core.IsHalJordan = function() return true end
Core.IsRingActive = function() return true end

local function makePlayerWithItems(items)
  local itemMap = {}
  for _, id in ipairs(items) do itemMap[id] = true end
  return {
    HasCollectible = function(_, id) return itemMap[id] == true end,
    GetCollectibleNum = function(_, id) return itemMap[id] and 1 or 0 end,
    GetCollectibleCount = function() return #items end,
  }
end

-- Mutant Spider support
local pSpider = makePlayerWithItems({ CollectibleType.COLLECTIBLE_MUTANT_SPIDER })
check(Core.GetTapTearCount(pSpider) == 4, string.format("Mutant Spider must give 4 shots, gave %d", Core.GetTapTearCount(pSpider)))
local anglesSpider = Core.GetContinuousBeamAngles(pSpider)
check(#anglesSpider == 4, string.format("Mutant Spider must give 4 beam angles, gave %d", #anglesSpider))

-- Epic Fetus beam availability
local pEpic = makePlayerWithItems({ CollectibleType.COLLECTIBLE_EPIC_FETUS })
check(Core.CanUseContinuousBeam(pEpic) == true, "CanUseContinuousBeam must be true with Epic Fetus")

-- The Wiz angles
local pWiz = makePlayerWithItems({ CollectibleType.COLLECTIBLE_THE_WIZ })
local anglesWiz = Core.GetContinuousBeamAngles(pWiz)
check(#anglesWiz == 2 and anglesWiz[1] == -45 and anglesWiz[2] == 45, "The Wiz must give diagonal angles (-45, 45)")

-- ===================== TEST 3: COSTUMES PRESERVED =====================
local fState = assert(io.open("modules/ring_state.lua", "r"))
local srcState = fState:read("*a"); fState:close()
srcState = srcState:gsub("|", "+")
local chunkState = assert(loadstring(srcState, "modules/ring_state.lua"))
chunkState()(Core)

local removedCostumes = {}
local pCostume = {
  HasCollectible = function(_, id) return id == 25 end,
  RemoveCostume = function(_, conf) table.insert(removedCostumes, conf.ID) end,
  TryRemoveNullCostume = function() end,
}
Core.RefreshCharacterCostume(pCostume)
check(#removedCostumes == 0, "RefreshCharacterCostume must preserve item costumes so appearance changes naturally")

-- ===================== TEST 4: GIANT FIST POISON DISSIPATION =====================
local fFist = assert(io.open("modules/item_fist.lua", "r"))
local srcFist = fFist:read("*a"); fFist:close()
check(srcFist:find("isGLFistPoison") ~= nil, "Giant Fist must tag poison smoke with isGLFistPoison")
check(srcFist:find("MC_POST_EFFECT_UPDATE") ~= nil, "Giant Fist must listen to MC_POST_EFFECT_UPDATE for poison dissipation")
check(srcFist:find("glPoisonLife") ~= nil, "Giant Fist must track glPoisonLife for smooth fade and removal")
-- ===================== TEST 5: STICKY TEARS HANDLING =====================
local fHud = assert(io.open("modules/hud_render.lua", "r"))
local srcHud = fHud:read("*a"); fHud:close()
check(srcHud:find("StickTarget") ~= nil, "hud_render.lua must check StickTarget for sticky tears")
check(srcHud:find("RingFlare") ~= nil, "hud_render.lua must render RingFlare construct node when stuck")

local fDisc = assert(io.open("modules/beam_discrete.lua", "r"))
local srcDisc = fDisc:read("*a"); fDisc:close()
check(srcDisc:find("StickTarget") ~= nil, "beam_discrete.lua must check StickTarget for sticky tears")

-- ===================== TEST 6: BOSS VS BANNERS =====================
local fHal = io.open("resources/gfx/ui/boss/name_hal_jordan.png", "rb")
check(fHal ~= nil, "name_hal_jordan.png must exist")
if fHal then fHal:close() end
local fThal = io.open("resources/gfx/ui/boss/name_tainted_hal.png", "rb")
check(fThal ~= nil, "name_tainted_hal.png must exist")
if fThal then fThal:close() end
io.stderr:write(string.format("\n[test_user_fixes_synergies] passes=%d failures=%d\n", passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end
