-- modules/beam_synergies.lua -- RSI: solo sinergias laser/cuchillo del anillo. Sin Willpower, sin items activos.
return function(Core)
    local GL = Core.GL

    -- 1. LASER SYNERGIES: Brimstone, Tech X, Technology, Technology 2, Tech.5, Jacob's Ladder
    GL:AddCallback(ModCallbacks.MC_POST_LASER_INIT, function(_, laser)
        local spawner = laser.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        local ld = laser:GetData()
        local data = Core.GetPlayerData(player)

        -- Handle Hal Jordan / Tainted Hal held continuous Ring Beam (lower damage than small beams)
        if data.spawningContinuousBeam or ld.isGLContinuousBeam then
            ld.isGLContinuousBeam   = true
            ld.glLaserSynergyInit   = true
            pcall(function()
                laser.DepthOffset       = 35
                laser.CollisionDamage   = player.Damage * Core.HAL_CONTINUOUS_BEAM_DMG_MULT
                local flags             = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
                if Core.IsTaintedHal(player) then
                    flags = flags | TearFlags.TEAR_FEAR
                end
                laser.TearFlags         = flags
                local lSpr              = laser:GetSprite()
                if lSpr then
                    lSpr:SetFrame(0)
                    lSpr.Color = Color(0.1, 1.0, 0.38, 0.0, 0, 0, 0)
                end
            end)
            data.ringFlareTimer     = 4
            return
        end

        if ld.glLaserSynergyInit then return end
        ld.glLaserSynergyInit = true

        data.ringFlareTimer = 8

        -- Tint all player lasers into blazing Hard-Light Emerald Construct Beams!
        laser.DepthOffset     = 35
        laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20)
        laser.CollisionDamage = laser.CollisionDamage * 1.25
        laser.TearFlags = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
        if Core.IsTaintedHal(player) then
            laser.TearFlags = laser.TearFlags | TearFlags.TEAR_FEAR
        end

        -- Hal Jordan Willpower management for laser weapons
        if Core.IsHalJordan(player) and not data.ringDepleted then
            local frame = Game():GetFrameCount()
            if data.lastLaserDrainFrame ~= frame then
                data.lastLaserDrainFrame = frame
                local prevWillBucket = math.floor((data.willpower or Core.WILLPOWER_MAX) + 0.5)
                data.willpower = math.max(0, data.willpower - 1.2)
                local newWillBucket = math.floor(data.willpower + 0.5)
                if data.willpower <= 0 then
                    Core.TriggerHalRingDepleted(player)
                elseif newWillBucket ~= prevWillBucket then
                    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                    player:EvaluateItems()
                end
            end
        end
    end)

    GL:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE, function(_, laser)
        local spawner = laser.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        local ld = laser:GetData()
        local data = Core.GetPlayerData(player)
        data.ringFlareTimer = 4
        laser.DepthOffset   = 35
        if ld and ld.isGLContinuousBeam then
            pcall(function()
                laser.Timeout           = 60
                laser:SetTimeout(60)
                laser.OneHit            = false
                laser:SetOneHit(false)
                laser.CollisionDamage   = player.Damage * Core.HAL_CONTINUOUS_BEAM_DMG_MULT
                local flags             = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
                if Core.IsTaintedHal(player) then
                    flags = flags | TearFlags.TEAR_FEAR
                end
                laser.TearFlags         = flags
                local lSpr              = laser:GetSprite()
                if lSpr then
                    lSpr:SetFrame(0)
                    lSpr.Color = Color(0.1, 1.0, 0.38, 0.0, 0, 0, 0)
                end
            end)
        else
            laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20)
        end
    end)

    -- Throttle any legacy continuous beam EntityLaser hit frequency (once every HAL_CONTINUOUS_TICK_FRAMES = 4 frames per enemy)
    GL:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, flags, source)
        if not entity or not entity:IsActiveEnemy(false) then return end
        if (flags & DamageFlag.DAMAGE_LASER) == 0 then return end
        if not (source and source.Entity) then return end

        local srcData = source.Entity.GetData and source.Entity:GetData()
        if not (srcData and srcData.isGLContinuousBeam) then return end

        local ed = entity:GetData()
        local frame = Game():GetFrameCount()
        if ed.lastGLContBeamHitFrame and frame >= ed.lastGLContBeamHitFrame and (frame - ed.lastGLContBeamHitFrame) < Core.HAL_CONTINUOUS_TICK_FRAMES then
            return false
        end
        ed.lastGLContBeamHitFrame = frame
    end)

    -- 2. MOM'S KNIFE SYNERGY: Hard-Light Emerald Energy Blade
    GL:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, function(_, knife)
        local spawner = knife.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        knife:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.10, 0.85, 0.25)
        if knife:IsFlying() then
            local data = Core.GetPlayerData(player)
            data.ringFlareTimer = 5
        end
    end)
end
