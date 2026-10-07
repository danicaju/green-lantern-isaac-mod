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
            if (Core.IsHalJordan(player) or Core.IsTaintedHal(player)) and Core.RefreshCharacterCostume then
                Core.RefreshCharacterCostume(player)
            end
            local data = Core.GetPlayerData(player)
            if Core.IsHalJordan(player) or Core.IsTaintedHal(player) then
                if Core.StopContinuousBeam then
                    Core.StopContinuousBeam(data)
                end
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
            if needsEval and CacheFlag then
                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                player:AddCacheFlags(CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            end
        end

        -- Boss Room Dramatic Battle Oath Cue
        pcall(function()
            if Core.BOSS_OATH_CUES_ENABLED ~= false and Game then
                local room = Game():GetRoom()
                if room then
                    local rtype = room:GetType()
                    local bossRoomId = (RoomType and RoomType.ROOM_BOSS) or 5
                    local bossRushId = (RoomType and RoomType.ROOM_BOSSRUSH) or 14
                    local isBoss = (rtype == bossRoomId or rtype == bossRushId)
                    local isUncleared = true
                    if room.IsClear then
                        isUncleared = not room:IsClear()
                    end
                    if isBoss and isUncleared then
                        for i = 0, Game():GetNumPlayers() - 1 do
                            local player = Isaac.GetPlayer(i)
                            if player and (Core.IsHalJordan(player) or Core.IsTaintedHal(player)) then
                                local data = Core.GetPlayerData(player)
                                data.ringFlareTimer = 30
                                if Core.IsHalJordan(player) then
                                    data.oathText = "NO EVIL SHALL ESCAPE MY SIGHT!"
                                else
                                    data.oathText = "FEAR THE LIGHT OF PARALLAX!"
                                end
                                data.oathTextTimer = 110
                                local vol = (Core.SFX_VOLUME_MULT or 1.0)
                                local zeroVec = Vector.Zero or (Vector and Vector(0, 0)) or nil
                                pcall(function()
                                    if Core.IsHalJordan(player) then
                                        local sfx = (SoundEffect and SoundEffect.SOUND_SUPERHOLY) or 0
                                        if sfx > 0 and SFXManager then
                                            SFXManager():Play(sfx, 0.90 * vol, 0, false, 1.15)
                                        end
                                        if Isaac and EntityType and EntityType.ENTITY_EFFECT and EffectVariant and EffectVariant.HALO then
                                            local shock = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HALO, 0, player.Position, zeroVec, player)
                                            if shock and Core.SetEntityScaleAndColor then
                                                Core.SetEntityScaleAndColor(shock, 1.3, Color(0.15, 1.0, 0.35, 0.85, 0.1, 0.7, 0.15))
                                            end
                                        end
                                    else
                                        local sfx = (SoundEffect and SoundEffect.SOUND_HELL_PORTAL2) or (SoundEffect and SoundEffect.SOUND_SUPERHOLY) or 0
                                        if sfx > 0 and SFXManager then
                                            SFXManager():Play(sfx, 0.85 * vol, 0, false, 1.25)
                                        end
                                        if Isaac and EntityType and EntityType.ENTITY_EFFECT and EffectVariant and EffectVariant.HALO then
                                            local shock = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HALO, 0, player.Position, zeroVec, player)
                                            if shock and Core.SetEntityScaleAndColor then
                                                Core.SetEntityScaleAndColor(shock, 1.3, Color(1.0, 0.85, 0.1, 0.85, 0.6, 0.5, 0.05))
                                            end
                                        end
                                    end
                                    local g = Game and Game()
                                    if Core.SCREEN_SHAKE_ENABLED ~= false and g and g.ShakeScreen then
                                        g:ShakeScreen(3)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end)
    end)
end
