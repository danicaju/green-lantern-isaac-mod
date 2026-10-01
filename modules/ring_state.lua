-- modules/ring_state.lua -- RSI: estado del anillo (sin corazones rojos Tainted, costume, deplecion/reboot Hal). Sin callbacks.
return function(Core)
    -- Ensure Tainted Hal NEVER has Red Heart Containers (or Bone/Red/Rotten hearts) and NEVER converts red hearts into Black Hearts
    function Core.EnforceTaintedHalNoRedHearts(player)
        if not Core.IsTaintedHal(player) then return end
        pcall(function()
            local removedContainer = false
            local maxHearts = player:GetMaxHearts()
            if maxHearts and maxHearts > 0 then
                player:AddMaxHearts(-maxHearts, true)
                removedContainer = true
            end
            if player.GetBoneHearts and player.AddBoneHearts then
                local boneHearts = player:GetBoneHearts()
                if boneHearts and boneHearts > 0 then
                    player:AddBoneHearts(-boneHearts)
                    removedContainer = true
                end
            end
            local redHearts = player:GetHearts()
            if redHearts and redHearts > 0 then
                player:AddHearts(-redHearts)
            end
            if player.GetRottenHearts and player.AddRottenHearts then
                local rottenHearts = player:GetRottenHearts()
                if rottenHearts and rottenHearts > 0 then
                    player:AddRottenHearts(-rottenHearts)
                end
            end
            -- Only grant a safety Black Heart if stripping a Red/Bone Heart Container left the player with 0 Soul/Black hearts
            -- (never trigger during normal combat death when removedContainer is false!)
            if removedContainer and (player:GetSoulHearts() or 0) <= 0 then
                player:AddBlackHearts(2)
            end
        end)
    end

    function Core.RefreshCharacterCostume(player)
        -- Remove any legacy null costumes so that standard Isaac item costumes and mod visual effects
        -- render directly and interact naturally with Hal Jordan and Tainted Hal sprites
        pcall(function()
            if Core.COSTUME_HAL and Core.COSTUME_HAL >= 0 then
                player:TryRemoveNullCostume(Core.COSTUME_HAL)
            end
            if Core.COSTUME_TAINTED_HAL and Core.COSTUME_TAINTED_HAL >= 0 then
                player:TryRemoveNullCostume(Core.COSTUME_TAINTED_HAL)
            end
        end)
    end

    -- Power down Hal Jordan's Green Lantern Ring when Willpower reaches 0% (loses ring construct capabilities, fights with normal un-nerfed human tears)
    function Core.TriggerHalRingDepleted(player)
        if not player or not Core.IsHalJordan(player) then return end
        local data = Core.GetPlayerData(player)
        data.ringDepleted              = true
        data.willpower                 = 0
        data.overcharge                = false
        data.surgeBuff                 = false
        data.continuousBeamGraceTimer  = 0
        data.lastContinuousBeamDir     = nil
        data.shootHoldFrames           = 0
        data.firedSmallBeamThisPress   = false
        data.sawShootReleaseBetweenFrames = false
        data.sawShootPressBetweenFrames   = false
        data.bufferedClickDir          = nil
        data.humanTapShootDir          = nil
        data.allowingTapTear           = false
        data.ringFlareTimer            = 0
        data.oathTextTimer             = 95
        data.oathText                  = "RING OFFLINE! FIGHT ON!"
        Core.StopContinuousBeam(data)
        pcall(function()
            local sfx = (SoundEffect and (SoundEffect.SOUND_BATTERYDISCHARGE or SoundEffect.SOUND_THUMBS_DOWN)) or 0
            if sfx > 0 then
                SFXManager():Play(sfx, 0.85, 0, false, 0.95)
            end
            local handPos = player.Position + (data.lastRingHandOffset or Vector(18, -14))
            local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, handPos, Vector.Zero, player)
            Core.SetEntityScaleAndColor(fx, 0.65, Color(0.2, 1.0, 0.4, 0.9, 0.15, 0.65, 0.2))
        end)
        pcall(function()
            player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
            player:EvaluateItems()
        end)
        Core.RefreshCharacterCostume(player)
    end

    -- Restore Hal Jordan's Green Lantern Ring power and cleanly reset shooting state so discrete left-click beams fire straight & true
    function Core.RestoreHalRingPower(player, newWillpower, statusText)
        if not player or not Core.IsHalJordan(player) then return end
        local data = Core.GetPlayerData(player)
        local wasDepleted = data.ringDepleted
        local willpowerMax = Core.WILLPOWER_MAX or 100.0
        data.willpower    = math.max(0.0, math.min(willpowerMax, newWillpower or willpowerMax))
        data.ringDepleted = (data.willpower <= 0)
        if wasDepleted and not data.ringDepleted then
            data.shootHoldFrames              = 0
            data.firedSmallBeamThisPress      = false
            data.sawShootReleaseBetweenFrames = false
            data.sawShootPressBetweenFrames   = false
            data.bufferedClickDir             = nil
            data.humanTapShootDir             = nil
            data.allowingTapTear              = false
            data.continuousBeamGraceTimer     = 0
            data.lastContinuousBeamDir        = nil
            data.ringFlareTimer               = 16
            data.oathTextTimer                = 90
            data.oathText                     = statusText or "RING REBOOTED!"
            Core.StopContinuousBeam(data)
            -- Immediately clamp FireDelay >= 2 so C++ EntityPlayer::Update() cannot fire an unbuffered native circle tear
            -- before MC_POST_PLAYER_UPDATE runs!
            if Core.CanUseContinuousBeam(player) then
                player.FireDelay = math.max(player.FireDelay or 0, 2)
            end
            -- Convert any in-flight normal human tears fired right before/on the reboot frame into full Ring Beams
            pcall(function()
                local baseScale = data.overcharge and 1.20 or (data.surgeBuff and 1.10 or 1.0)
                for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false)) do
                    local tear = ent and ent:ToTear()
                    if tear then
                        local td = tear:GetData()
                        local spawner = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
                        if spawner and spawner.Index == player.Index and not (td and (td.isGLRingBeam or td.isGiantFist)) then
                            tear.TearFlags = tear.TearFlags | TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL
                            local sizeFactor = math.max(0.65, math.min(1.85, tear.Scale or 1.0))
                            Core.ApplyRingBeamSprite(tear, baseScale * math.sqrt(sizeFactor))
                        end
                    end
                end
            end)
            pcall(function()
                local sfx = (SoundEffect and (SoundEffect.SOUND_BATTERYCHARGE or SoundEffect.SOUND_SUPERHOLY)) or 0
                if sfx > 0 then
                    SFXManager():Play(sfx, 0.85, 0, false, 1.08)
                end
                local handPos = player.Position + (data.lastRingHandOffset or Vector(18, -14))
                local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, handPos, Vector.Zero, player)
                Core.SetEntityScaleAndColor(fx, 0.70, Color(0.15, 1.0, 0.45, 0.95, 0.2, 0.85, 0.3))
            end)
        end
        pcall(function()
            player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG)
            player:EvaluateItems()
        end)
        if Core.CanUseContinuousBeam(player) then
            player.FireDelay = math.max(player.FireDelay or 0, 2)
        end
        Core.RefreshCharacterCostume(player)
    end
end
