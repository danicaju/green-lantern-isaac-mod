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
        Core.LoadItemIDs()

        -- HAL JORDAN INIT
        if Core.IsHalJordan(player) then
            local data = Core.GetPlayerData(player)
            data.willpower                    = Core.WILLPOWER_MAX
            data.ringDepleted                 = false
            data.overcharge                   = false
            data.surgeBuff                    = false
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
            data.continuousLaser              = nil
            data.continuousBeamGraceTimer     = 0
            data.allowingTapTear              = false
            pcall(function()
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
            end)
        end

        -- TAINTED HAL INIT
        if Core.IsTaintedHal(player) then
            local data = Core.GetPlayerData(player)
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
            pcall(function()
                player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG)
            end)
        end
    end)
end
