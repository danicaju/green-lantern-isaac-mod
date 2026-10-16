-- tools/test_custom_costumes.lua -- Unit test for tailored superhero costumes framework

local passed = 0
local failed = 0

local function assert_eq(actual, expected, msg)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write(string.format("FAIL: %s (expected %s, got %s)\n", msg, tostring(expected), tostring(actual)))
    end
end

local function assert_true(val, msg)
    assert_eq(val, true, msg)
end

-- Mock minimal Isaac environment
_G.Isaac = _G.Isaac or {}
_G.ModCallbacks = _G.ModCallbacks or {
    MC_POST_PEFFECT_UPDATE = 1,
    MC_POST_PLAYER_RENDER = 2,
    MC_POST_PLAYER_UPDATE = 3,
}
_G.CollectibleType = _G.CollectibleType or {
    COLLECTIBLE_20_20 = 245,
    COLLECTIBLE_BIRDS_EYE = 614,
}

local mockCostumeIds = {
    ["gfx/characters/hal_costume_2020.anm2"] = 101,
}

Isaac.GetCostumeIdByPath = function(path)
    return mockCostumeIds[path] or -1
end

Isaac.GetItemConfig = function()
    return {
        GetCollectible = function(_, id)
            return { ID = id, Name = "Item_" .. id }
        end
    }
end

-- Minimal Core mock
local Core = {
    GL = {
        callbacks = {},
        AddCallback = function(self, cb, fn)
            self.callbacks[cb] = self.callbacks[cb] or {}
            table.insert(self.callbacks[cb], fn)
        end
    },
    PLAYER_HAL = 1,
    PLAYER_TAINTED_HAL = 2,
    IsHalJordan = function(p) return p.type == 1 end,
    IsTaintedHal = function(p) return p.type == 2 end,
    GetPlayerData = function(p) return p.data end,
}

-- Load module
local chunk = assert(loadfile("modules/custom_costumes.lua"))
local loader = chunk()
assert_true(type(loader) == "function", "modules/custom_costumes.lua returns loader function")

local CustomCostumes = loader(Core)
assert_true(type(CustomCostumes) == "table", "custom_costumes returns table")
assert_true(Core.CustomCostumes == CustomCostumes, "Core.CustomCostumes registered")

-- 1. Table definitions
assert_true(CustomCostumes.Tailored[245] ~= nil, "20/20 in Tailored table")
assert_eq(CustomCostumes.Tailored[245].anm2, "gfx/characters/hal_costume_2020.anm2", "20/20 anm2 path correct")
assert_true(CustomCostumes.Blacklist[614] == true, "Bird's Eye in Blacklist table")

-- 2. Mock Player (Hal Jordan) with 20/20 and Bird's Eye
local removedVanilla = {}
local addedNull = {}
local removedNull = {}

local halPlayer = {
    type = 1,
    data = {},
    items = { [245] = true, [614] = true },
    GetPlayerType = function(self) return self.type end,
    HasCollectible = function(self, id) return self.items[id] == true end,
    RemoveCostume = function(self, config) table.insert(removedVanilla, config.ID) end,
    AddNullCostume = function(self, id) table.insert(addedNull, id) end,
    TryRemoveNullCostume = function(self, id) table.insert(removedNull, id) end,
}

CustomCostumes.UpdatePlayerCostumes(halPlayer)

assert_eq(#addedNull, 1, "Added 1 tailored costume for 20/20")
assert_eq(addedNull[1], 101, "Tailored costume ID is 101")
assert_true(halPlayer.data.TailoredCostumesAdded[245] == true, "Tracked in TailoredCostumesAdded")
assert_true(#removedVanilla >= 2, "Removed vanilla 20/20 and Bird's Eye costumes")

-- 3. Reroll / Loss of item
halPlayer.items[245] = false
CustomCostumes.UpdatePlayerCostumes(halPlayer)
assert_true(#removedNull >= 2, "Removed tailored costume on item loss")
assert_true(halPlayer.data.TailoredCostumesAdded[245] == nil, "Cleaned up tracking on loss")

-- 4. Regular Character (Isaac) picking up 20/20
local regularRemoved = {}
local regularAdded = {}
local isaacPlayer = {
    type = 0, -- Regular Isaac
    data = {},
    items = { [245] = true },
    GetPlayerType = function(self) return self.type end,
    HasCollectible = function(self, id) return self.items[id] == true end,
    RemoveCostume = function(self, config) table.insert(regularRemoved, config.ID) end,
    AddNullCostume = function(self, id) table.insert(regularAdded, id) end,
    TryRemoveNullCostume = function(self, id) end,
}

CustomCostumes.UpdatePlayerCostumes(isaacPlayer)
assert_eq(#regularRemoved, 0, "Vanilla Isaac does NOT have costume removed")
assert_eq(#regularAdded, 0, "Vanilla Isaac does NOT receive tailored costume")

-- 5. Asset file checks
local f_anm2 = io.open("resources/gfx/characters/hal_costume_2020.anm2", "r")
assert_true(f_anm2 ~= nil, "hal_costume_2020.anm2 exists")
if f_anm2 then f_anm2:close() end

local f_png = io.open("resources/gfx/characters/costumes_hal/costume_245_2020.png", "r")
assert_true(f_png ~= nil, "costumes_hal/costume_245_2020.png exists")
if f_png then f_png:close() end

local f_xml = io.open("content/costumes2.xml", "r")
assert_true(f_xml ~= nil, "content/costumes2.xml exists")
if f_xml then
    local xml_content = f_xml:read("*a")
    f_xml:close()
    assert_true(xml_content:find("hal_costume_2020.anm2") ~= nil, "costumes2.xml registers hal_costume_2020.anm2")
end

if failed > 0 then
    io.stderr:write(string.format("FAILED: %d, PASSED: %d\n", failed, passed))
    os.exit(1)
else
    print(string.format("All %d assertions PASSED!", passed))
    os.exit(0)
end
