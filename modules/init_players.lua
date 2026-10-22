-- modules/init_players.lua -- RSI: solo init de partida y jugador. Sin combate, sin HUD, sin stats.
-- SECTION 4: POST_GAME_STARTED + POST_PLAYER_INIT. Estado via Core.*, IDs via Core.LoadItemIDs().
return function(Core)
    local GL = Core.GL

    GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
        Core.LoadItemIDs()
        Core.ClearAllCoastCities()
        Core.ClearAllLanternEmblemDrops()
    end)

    GL:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player)
        if not player then return end
        Core.LoadItemIDs()

        -- HAL JORDAN INIT
        if Core.IsHalJordan(player) then
            local data = Core.GetPlayerData(player)
            -- D5: en partida continuada preservamos willpower y estado de anillo
            -- restaurados por save_run.lua; en partida nueva se resetean.
            local isContinue = (data._glContinuedRun == true)
            local savedWill, savedRingDepleted, savedOvercharge, savedOverchargeTier, savedSurgeBuff
            if isContinue then
                savedWill            = data.willpower
                savedRingDepleted    = data.ringDepleted
                savedOvercharge      = data.overcharge
                savedOverchargeTier  = data.overchargeTier
                savedSurgeBuff       = data.surgeBuff
            end
            data.willpower                    = Core.WILLPOWER_MAX
            data.ringDepleted                 = false
            data.overcharge                   = false
            data.surgeBuff                    = false
            data.overchargeTier               = 0
            data.overchargeRoomIdx            = -1
            data.shootHoldFrames              = 0
            data.lastShootUpdateFrame         = -1
            data.lastSmallBeamFrame           = -999
            data.lastDiscreteClickReleaseFrame = -999
            data.firedSmallBeamThisPress      = false
            data.lastShootDir                 = nil
            data.renderLastShootDir           = nil
            data.wasHoldingShootOnRender      = false
            data.sawShootReleaseBetweenFrames = false
            data.sawShootPressBetweenFrames   = false
            data.bufferedClickDir             = nil
            data.bufferedClickExpireFrame     = 0
            data.humanTapShootDir             = nil
            data.humanTapExpireFrame          = 0
            data.isFiringContinuousBeam       = false
            data.spawningContinuousBeam       = false
            data.continuousBeamGraceTimer     = 0
            data.allowingTapTear              = false
            if isContinue then
                data.willpower            = savedWill
                data.ringDepleted         = savedRingDepleted
                data.overcharge           = savedOvercharge
                data.overchargeTier       = savedOverchargeTier
                data.surgeBuff            = savedSurgeBuff
                data._glContinuedRun      = false
            end
            pcall(function()
                local pocketSlot = (ActiveSlot and ActiveSlot.SLOT_POCKET) or 2
                if Core.ITEM_POWER_BATTERY and Core.ITEM_POWER_BATTERY > 0 and player.SetPocketActiveItem then
                    if not player.GetActiveItem or player:GetActiveItem(pocketSlot) ~= Core.ITEM_POWER_BATTERY then
                        player:SetPocketActiveItem(Core.ITEM_POWER_BATTERY, pocketSlot, true)
                        if player.FullCharge then player:FullCharge(pocketSlot, true) end
                    end
                end
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
            end)
        end

        -- TAINTED HAL INIT
        if Core.IsTaintedHal(player) then
            local data = Core.GetPlayerData(player)
            -- D5: en partida continuada preservamos progreso restaurado.
            local isContinue = (data._glContinuedRun == true)
            local savedSparks, savedRings
            if isContinue then
                savedSparks = data.emeraldSparks
                savedRings  = data.stolenRings
            end
            data.emeraldSparks                = 0.0
            data.stolenRings                  = 0
            data.coastCityActive              = false
            data.coastCityFrame               = 0
            data.shootHoldFrames              = 0
            data.lastShootUpdateFrame         = -1
            data.lastSmallBeamFrame           = -999
            data.lastDiscreteClickReleaseFrame = -999
            data.firedSmallBeamThisPress      = false
            data.lastShootDir                 = nil
            data.renderLastShootDir           = nil
            data.wasHoldingShootOnRender      = false
            data.sawShootReleaseBetweenFrames = false
            data.sawShootPressBetweenFrames   = false
            data.bufferedClickDir             = nil
            data.bufferedClickExpireFrame     = 0
            data.humanTapShootDir             = nil
            data.humanTapExpireFrame          = 0
            data.isFiringContinuousBeam       = false
            data.spawningContinuousBeam       = false
            data.continuousLaser              = nil
            data.continuousBeamGraceTimer     = 0
            data.allowingTapTear              = false
            if isContinue then
                data.emeraldSparks   = savedSparks
                data.stolenRings     = savedRings
                data._glContinuedRun = false
            end
            pcall(function()
                local pocketSlot = (ActiveSlot and ActiveSlot.SLOT_POCKET) or 2
                if Core.ITEM_COAST_CITY and Core.ITEM_COAST_CITY > 0 and player.SetPocketActiveItem then
                    if not player.GetActiveItem or player:GetActiveItem(pocketSlot) ~= Core.ITEM_COAST_CITY then
                        player:SetPocketActiveItem(Core.ITEM_COAST_CITY, pocketSlot, true)
                        if player.FullCharge then player:FullCharge(pocketSlot, true) end
                    end
                end
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG)
            end)
        end
    end)
end
