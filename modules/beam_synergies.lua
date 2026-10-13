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
    -- 3. DR. FETUS & EPIC FETUS SYNERGIES: Hard-Light Emerald Construct Bombs & Orbital Strikes
    if include then
        pcall(function()
            local fetusMod = include("modules.synergies_fetus")
            if fetusMod then fetusMod(Core) end
        end)
    end

    -- 5. LUDOVICO TECHNIQUE SYNERGY: Hard-Light Floating Construct Orb
    GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end
        if not (CollectibleType and CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE and player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE)) then return end

        local td = tear:GetData()
        if not td.isGLLudovicoOrb then
            td.isGLLudovicoOrb = true
            if TearFlags then
                tear.TearFlags = tear.TearFlags | (TearFlags.TEAR_SPECTRAL or 1) | (TearFlags.TEAR_PIERCING or 2)
            end
        end

        pcall(function()
            local spr = tear:GetSprite()
            if spr then
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.20, 0.90, 0.30)
            end
        end)

        local frame = Game():GetFrameCount()
        if frame % 15 == 0 then
            pcall(function()
                local fxVar = (EffectVariant and EffectVariant.HALO) or 10
                local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, tear.Position, Vector.Zero, player)
                if fx then
                    Core.SetEntityScaleAndColor(fx, 0.65, Color(0.1, 1.0, 0.35, 0.70, 0.15, 0.80, 0.20))
                end
            end)
        end
    end)

    -- 6. HAEMOLACRIA SYNERGY: Hard-Light Emerald Mortar & Burst Shards
    GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end
        local haemoId = (CollectibleType and CollectibleType.COLLECTIBLE_HAEMOLACRIA) or 531
        if not (player.HasCollectible and player:HasCollectible(haemoId)) then return end

        local td = tear:GetData()
        if not td.isGLHaemoTear then
            td.isGLHaemoTear = true
            tear.DepthOffset = 25
        end

        pcall(function()
            local spr = tear:GetSprite()
            if spr then
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.20, 0.85, 0.25)
            end
        end)
    end)

    -- 7. POP! SYNERGY: Hard-Light Bouncing Construct Orbs
    GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end
        local popId = (CollectibleType and CollectibleType.COLLECTIBLE_POP) or 529
        if not (player.HasCollectible and player:HasCollectible(popId)) then return end

        local td = tear:GetData()
        if not td.isGLPopOrb then
            td.isGLPopOrb = true
        end

        pcall(function()
            local spr = tear:GetSprite()
            if spr then
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.25, 0.90, 0.30)
            end
        end)
    end)
end
