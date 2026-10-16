-- modules/custom_costumes.lua -- RSI: Tailored Superhero Costumes for Hal Jordan & Tainted Hal
-- Replaces clashing vanilla side-profile costumes with custom superhero-tailored costumes
-- while leaving vanilla characters (Isaac, Cain, Judas, etc.) completely unaffected.

return function(Core)
local GL = Core.GL
local CustomCostumes = {}
Core.CustomCostumes = CustomCostumes

-- Table of tailored costumes for Hal Jordan
-- Maps CollectibleType -> { anm2 = path, costumeId = -1, removeOriginal = true }
CustomCostumes.Tailored = {
    [CollectibleType.COLLECTIBLE_20_20 or 245] = {
        anm2 = "gfx/characters/hal_costume_2020.anm2",
        costumeId = -1,
        removeOriginal = true,
    },
}

-- Table of blacklisted visual costumes that clash with Hal's domino mask
-- Suppresses the visual sprite only (player retains 100% stats, tears, and synergies)
CustomCostumes.Blacklist = {
    [CollectibleType.COLLECTIBLE_BIRDS_EYE or 614] = true,
}

local function SafeGetCostumeId(path)
    if not (Isaac and Isaac.GetCostumeIdByPath) then return -1 end
    local ok, id = pcall(function() return Isaac.GetCostumeIdByPath(path) end)
    if ok and type(id) == "number" then return id end
    return -1
end

local function RemoveVanillaCostume(player, collectibleId)
    if not (player and player.RemoveCostume and Isaac and Isaac.GetItemConfig) then return end
    pcall(function()
        local itemConfig = Isaac.GetItemConfig():GetCollectible(collectibleId)
        if itemConfig then
            player:RemoveCostume(itemConfig)
        end
    end)
end

local function AddTailoredCostume(player, costumeId)
    if not (player and player.AddNullCostume and costumeId and costumeId >= 0) then return end
    pcall(function()
        if player.TryRemoveNullCostume then
            player:TryRemoveNullCostume(costumeId)
        end
        player:AddNullCostume(costumeId)
    end)
end

local function RemoveTailoredCostume(player, costumeId)
    if not (player and player.TryRemoveNullCostume and costumeId and costumeId >= 0) then return end
    pcall(function()
        player:TryRemoveNullCostume(costumeId)
    end)
end

function CustomCostumes.UpdatePlayerCostumes(player)
    if not (player and player.GetPlayerType) then return end

    local isHal = false
    if Core.IsHalJordan and Core.IsHalJordan(player) then
        isHal = true
    elseif Core.IsTaintedHal and Core.IsTaintedHal(player) then
        isHal = true
    end

    -- Resolve costume IDs if not cached
    for _, entry in pairs(CustomCostumes.Tailored) do
        if entry.costumeId < 0 then
            entry.costumeId = SafeGetCostumeId(entry.anm2)
        end
    end

    local data = Core.GetPlayerData(player)
    if not data then return end
    data.TailoredCostumesAdded = data.TailoredCostumesAdded or {}

    if isHal then
        -- 1. Manage Tailored Costumes (e.g. 20/20)
        for collectibleId, entry in pairs(CustomCostumes.Tailored) do
            local hasItem = false
            pcall(function() hasItem = player:HasCollectible(collectibleId) end)

            local alreadyAdded = data.TailoredCostumesAdded[collectibleId]

            if hasItem then
                if entry.removeOriginal then
                    RemoveVanillaCostume(player, collectibleId)
                end
                if not alreadyAdded and entry.costumeId >= 0 then
                    AddTailoredCostume(player, entry.costumeId)
                    data.TailoredCostumesAdded[collectibleId] = true
                end
            else
                if alreadyAdded and entry.costumeId >= 0 then
                    RemoveTailoredCostume(player, entry.costumeId)
                    data.TailoredCostumesAdded[collectibleId] = nil
                end
            end
        end

        -- 2. Manage Blacklisted Costumes (e.g. Bird's Eye)
        for collectibleId, _ in pairs(CustomCostumes.Blacklist) do
            local hasItem = false
            pcall(function() hasItem = player:HasCollectible(collectibleId) end)
            if hasItem then
                RemoveVanillaCostume(player, collectibleId)
            end
        end
    else
        -- Regular character (Isaac, Cain, Judas, etc.): clean up tailored costumes
        for collectibleId, entry in pairs(CustomCostumes.Tailored) do
            if data.TailoredCostumesAdded[collectibleId] and entry.costumeId >= 0 then
                RemoveTailoredCostume(player, entry.costumeId)
                data.TailoredCostumesAdded[collectibleId] = nil
            end
        end
    end
end

if GL and GL.AddCallback then
    GL:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, player)
        CustomCostumes.UpdatePlayerCostumes(player)
    end)

    GL:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player)
        if not (player and player.GetPlayerType) then return end
        local isHal = (Core.IsHalJordan and Core.IsHalJordan(player)) or (Core.IsTaintedHal and Core.IsTaintedHal(player))
        if not isHal then return end

        for collectibleId, entry in pairs(CustomCostumes.Tailored) do
            if entry.removeOriginal then
                local has = false
                pcall(function() has = player:HasCollectible(collectibleId) end)
                if has then
                    RemoveVanillaCostume(player, collectibleId)
                end
            end
        end

        for collectibleId, _ in pairs(CustomCostumes.Blacklist) do
            local has = false
            pcall(function() has = player:HasCollectible(collectibleId) end)
            if has then
                RemoveVanillaCostume(player, collectibleId)
            end
        end
    end)
end

return CustomCostumes
end
