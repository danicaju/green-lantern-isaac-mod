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

        -- NOTE: el rayo continuo es 100% Lua (TickContinuousBeamDamage) + sprite;
        -- nunca se spawnea EntityLaser propio, asi que no hay rama isGLContinuousBeam.

        if ld.glLaserSynergyInit then return end
        ld.glLaserSynergyInit = true

        data.ringFlareTimer = 8

        -- Tint all player lasers into blazing Hard-Light Emerald Construct Beams!
        laser.DepthOffset     = 35
        laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20)
        laser.CollisionDamage = laser.CollisionDamage * 1.25
        laser.TearFlags = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
        if Core.IsTaintedHal(player) and math.random() < (Core.TAINTED_FEAR_CHANCE or 0.25) then
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

        local data = Core.GetPlayerData(player)
        data.ringFlareTimer = 4
        laser.DepthOffset   = 35
        laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20)
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
