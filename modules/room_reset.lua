-- modules/room_reset.lua -- RSI: reset de sala (Overcharge/Surge/Coast City/emblemas/beam). Solo POST_NEW_ROOM.
-- Responsabilidad unica: limpiar estado por sala. No toca HUD, combate ni stats fuera de re-evaluar cache.
return function(Core)
    local GL = Core.GL
    GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
        Core.ClearAllCoastCities()
        -- Remove any uncollected Green Lantern emblems when leaving a room so they never persist or turn into coins!
        Core.ClearAllLanternEmblemDrops()

        for i = 0, Game():GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(i)
            if Core.IsHalJordan(player) or Core.IsTaintedHal(player) then
                Core.RefreshCharacterCostume(player)
            end
            local data = Core.GetPlayerData(player)
            if Core.IsHalJordan(player) or Core.IsTaintedHal(player) then
                Core.StopContinuousBeam(data)
                data.shootHoldFrames              = 0
                data.firedSmallBeamThisPress      = false
                data.sawShootReleaseBetweenFrames = false
                data.sawShootPressBetweenFrames   = false
                data.wasHoldingShootOnRender      = false
                data.bufferedClickDir             = nil
                data.humanTapShootDir             = nil
                data.continuousBeamGraceTimer     = 0
                data.lastContinuousBeamDir        = nil
            end
            local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
            local needsEval = false
            if (data.overcharge or data.surgeBuff) and data.overchargeRoomIdx ~= roomIdx then
                data.overcharge = false
                data.surgeBuff  = false
                needsEval = true
            end
            if data.coastCityActive then
                data.coastCityActive = false
                needsEval = true
            end
            if needsEval then
                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            end
        end
    end)
end
