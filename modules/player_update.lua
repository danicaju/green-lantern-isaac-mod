-- modules/player_update.lua -- RSI: cabecera POST_PLAYER_UPDATE (battery timer, hearts, starting items, SpriteOffset, reboot).
-- Responsabilidad unica: mantenimiento por frame. NO incluye dual firing ni buffered/human tap (otro modulo).
return function(Core)
    local GL = Core.GL
    GL:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
        local data = Core.GetPlayerData(player)
        -- F4: anti-cruce de PlayerType (Glitched Crown / D4 / co-op swap).
        -- Si el tipo cambia desde el ultimo frame, resetear estado de run a
        -- defaults y forzar re-kit (initializedStartingItems=false).
        local curType = player:GetPlayerType()
        if data.lastPlayerType ~= nil and data.lastPlayerType ~= curType then
            data.willpower                = Core.WILLPOWER_MAX
            data.ringDepleted             = false
            data.overcharge               = false
            data.surgeBuff                = false
            data.overchargeTier           = 0
            data.overchargeRoomIdx        = -1
            data.emeraldSparks            = 0.0
            data.stolenRings              = 0
            data.coastCityActive          = false
            data.gatlingTimer             = 0
            data.fearControlTimer         = 0
            data.fearSkullTimer           = 0
            data.hadItemFlight            = false
            data.initializedStartingItems = false
        end
        data.lastPlayerType = curType
        if data.batteryConstructTimer and data.batteryConstructTimer > 0 then
            data.batteryConstructTimer = data.batteryConstructTimer - 1
        end
        if Core.IsTaintedHal(player) then
            Core.EnforceTaintedHalNoRedHearts(player)
        end
        if not data.initializedStartingItems then
            data.initializedStartingItems = true
            pcall(function()
                if Core.IsHalJordan(player) then
                    if player:GetSoulHearts() < 2 then
                        player:AddSoulHearts(2)
                    end
                    if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 and not player:HasCollectible(Core.ITEM_POWER_RING) then
                        player:AddCollectible(Core.ITEM_POWER_RING, 0, false)
                    end
                    local pocketSlot = (ActiveSlot and ActiveSlot.SLOT_POCKET) or 2
                    if Core.ITEM_POWER_BATTERY and Core.ITEM_POWER_BATTERY > 0 then
                        if player.SetPocketActiveItem then
                            if not player.GetActiveItem or player:GetActiveItem(pocketSlot) ~= Core.ITEM_POWER_BATTERY then
                                player:SetPocketActiveItem(Core.ITEM_POWER_BATTERY, pocketSlot, true)
                                if player.FullCharge then
                                    player:FullCharge(pocketSlot, true)
                                end
                            end
                        else
                            player:AddCollectible(Core.ITEM_POWER_BATTERY, 4, false, pocketSlot)
                        end
                    end
                    Core.RefreshCharacterCostume(player)
                    player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
                    player:EvaluateItems()
                elseif Core.IsTaintedHal(player) then
                    Core.EnforceTaintedHalNoRedHearts(player)
                    if (player:GetSoulHearts() or 0) <= 0 then
                        player:AddBlackHearts(6)
                    end
                    if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 and not player:HasCollectible(Core.ITEM_POWER_RING) then
                        player:AddCollectible(Core.ITEM_POWER_RING, 0, false)
                    end
                    local pocketSlot = (ActiveSlot and ActiveSlot.SLOT_POCKET) or 2
                    if Core.ITEM_COAST_CITY and Core.ITEM_COAST_CITY > 0 then
                        if player.SetPocketActiveItem then
                            if not player.GetActiveItem or player:GetActiveItem(pocketSlot) ~= Core.ITEM_COAST_CITY then
                                player:SetPocketActiveItem(Core.ITEM_COAST_CITY, pocketSlot, true)
                                if player.FullCharge then
                                    player:FullCharge(pocketSlot, true)
                                end
                            end
                        else
                            player:AddCollectible(Core.ITEM_COAST_CITY, 4, false, pocketSlot)
                        end
                    end
                    Core.RefreshCharacterCostume(player)
                    player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG)
                    player:EvaluateItems()
                end
            end)
        end

        -- Free primary slot if holding signature item, ensuring it resides in pocket slot
        local pocketSlot = (ActiveSlot and ActiveSlot.SLOT_POCKET) or 2
        local primarySlot = (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
        if Core.IsHalJordan(player) and Core.ITEM_POWER_BATTERY and Core.ITEM_POWER_BATTERY > 0 and player.GetActiveItem then
            if player:GetActiveItem(primarySlot) == Core.ITEM_POWER_BATTERY then
                if player.RemoveCollectible then
                    player:RemoveCollectible(Core.ITEM_POWER_BATTERY, true, primarySlot)
                end
            end
            if player:GetActiveItem(pocketSlot) ~= Core.ITEM_POWER_BATTERY and player.SetPocketActiveItem then
                player:SetPocketActiveItem(Core.ITEM_POWER_BATTERY, pocketSlot, true)
                if player.FullCharge then player:FullCharge(pocketSlot, true) end
            end
        elseif Core.IsTaintedHal(player) and Core.ITEM_COAST_CITY and Core.ITEM_COAST_CITY > 0 and player.GetActiveItem then
            if player:GetActiveItem(primarySlot) == Core.ITEM_COAST_CITY then
                if player.RemoveCollectible then
                    player:RemoveCollectible(Core.ITEM_COAST_CITY, true, primarySlot)
                end
            end
            if player:GetActiveItem(pocketSlot) ~= Core.ITEM_COAST_CITY and player.SetPocketActiveItem then
                player:SetPocketActiveItem(Core.ITEM_COAST_CITY, pocketSlot, true)
                if player.FullCharge then player:FullCharge(pocketSlot, true) end
            end
        end

        if Core.IsHalJordan(player) or Core.IsTaintedHal(player) then
            player.SpriteOffset = Vector.Zero
            if data.ringFlareTimer and data.ringFlareTimer > 0 then
                data.ringFlareTimer = data.ringFlareTimer - 1
            end
        end

        if Core.IsHalJordan(player) then
            local frame = Game():GetFrameCount()
            local maxW = (Core.GetMaxWillpower and Core.GetMaxWillpower(player)) or Core.WILLPOWER_MAX
            if data.ringDepleted or (data.willpower or 0) <= 0 then
                if data.lastDepletedRegenFrame ~= frame then
                    data.lastDepletedRegenFrame = frame
                    data.willpower = math.min(maxW, (data.willpower or 0) + Core.WILLPOWER_PASSIVE_REBOOT_RATE)
                    if data.willpower >= Core.WILLPOWER_REBOOT_THRESHOLD then
                        Core.RestoreHalRingPower(player, data.willpower, "RING REBOOTED!")
                    end
                end
            elseif not data.isFiringContinuousBeam and (frame - (data.lastSmallBeamFrame or -999)) > 60 then
                -- Natural out-of-combat focus: slowly recovers willpower when resting / not shooting
                if (data.willpower or 0) < maxW then
                    data.willpower = math.min(maxW, (data.willpower or 0) + 0.12)
                end
            end
        end
    end)
end
