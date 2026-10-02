-- modules/ids.lua — RSI: resolucion de IDs y predicados. Sin combate, sin HUD.
-- Se auto-registra en Core y resuelve IDs al cargarse (igual que main.lua original).

return function(Core)
    local stageApiRegistered = false

    function Core.RegisterStageAPIGraphics()
        if stageApiRegistered then return end
        if StageAPI and StageAPI.Loaded and StageAPI.AddPlayerGraphicsInfo then
            if Core.PLAYER_HAL and Core.PLAYER_HAL >= 0 then
                StageAPI.AddPlayerGraphicsInfo(Core.PLAYER_HAL, {
                    Portrait     = "gfx/ui/stage/stage_hal_jordan.png",
                    BossPortrait = "gfx/ui/boss/portrait_hal_jordan.png",
                    PortraitBig  = "gfx/ui/stage/stage_hal_jordan.png",
                    Name         = "gfx/ui/boss/name_hal_jordan.png",
                    NoShake      = false,
                })
            end
            if Core.PLAYER_TAINTED_HAL and Core.PLAYER_TAINTED_HAL >= 0 then
                StageAPI.AddPlayerGraphicsInfo(Core.PLAYER_TAINTED_HAL, {
                    Portrait     = "gfx/ui/stage/stage_tainted_hal.png",
                    BossPortrait = "gfx/ui/boss/portrait_tainted_hal.png",
                    PortraitBig  = "gfx/ui/stage/stage_tainted_hal.png",
                    Name         = "gfx/ui/boss/name_tainted_hal.png",
                    NoShake      = false,
                })
            end
            stageApiRegistered = true
        end
    end

    function Core.LoadItemIDs()
        Core.ITEM_POWER_BATTERY      = Isaac.GetItemIdByName("Power Battery")
        Core.ITEM_GIANT_FIST         = Isaac.GetItemIdByName("Construct: Giant Fist")
        Core.ITEM_GATLING            = Isaac.GetItemIdByName("Construct: Gatling")
        Core.ITEM_COAST_CITY         = Isaac.GetItemIdByName("The Tragedy of Coast City")
        Core.ITEM_SOLID_LIGHT_SHIELD = Isaac.GetItemIdByName("Solid Light Shield")
        Core.ITEM_POWER_RING         = Isaac.GetItemIdByName("Green Lantern Ring")
        Core.TRINKET_YELLOW_IMPURITY = Isaac.GetTrinketIdByName("Yellow Impurity")
        Core.COSTUME_HAL             = Isaac.GetCostumeIdByPath("gfx/characters/hal_costume.anm2")
        Core.COSTUME_TAINTED_HAL     = Isaac.GetCostumeIdByPath("gfx/characters/tainted_hal_costume.anm2")
        Core.PLAYER_HAL              = Isaac.GetPlayerTypeByName("Hal Jordan", false)
        local tHal                   = Isaac.GetPlayerTypeByName("Hal Jordan", true)
        if not tHal or tHal < 0 then
            tHal = Isaac.GetPlayerTypeByName("Tainted Hal", true)
        end
        if not tHal or tHal < 0 then
            tHal = Isaac.GetPlayerTypeByName("Tainted Hal", false)
        end
        Core.PLAYER_TAINTED_HAL = tHal
        Core.RegisterStageAPIGraphics()
    end

    function Core.IsHalJordan(player)
        if not player then return false end
        if not Core.PLAYER_HAL or Core.PLAYER_HAL < 0 then Core.LoadItemIDs() end
        return Core.PLAYER_HAL and Core.PLAYER_HAL >= 0 and player:GetPlayerType() == Core.PLAYER_HAL
    end

    function Core.IsTaintedHal(player)
        if not player then return false end
        if not Core.PLAYER_TAINTED_HAL or Core.PLAYER_TAINTED_HAL < 0 then Core.LoadItemIDs() end
        return Core.PLAYER_TAINTED_HAL and Core.PLAYER_TAINTED_HAL >= 0 and player:GetPlayerType() == Core.PLAYER_TAINTED_HAL
    end

    function Core.HasGreenLanternRing(player)
        if Core.IsHalJordan(player) or Core.IsTaintedHal(player) then return true end
        if not Core.ITEM_POWER_RING or Core.ITEM_POWER_RING < 0 then Core.LoadItemIDs() end
        return Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 and player:HasCollectible(Core.ITEM_POWER_RING)
    end

    function Core.IsRingActive(player)
        if not Core.HasGreenLanternRing(player) then return false end
        if Core.IsHalJordan(player) then
            local data = Core.GetPlayerData(player)
            if data.ringDepleted then return false end
        end
        return true
    end

    Core.LoadItemIDs()
end
