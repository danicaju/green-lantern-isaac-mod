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

    -- 3. EPIC FETUS SYNERGY: Hard-Light Emerald Energy Rocket
    GL:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, function(_, effect)
        local isRocket = (EffectVariant and EffectVariant.ROCKET and effect.Variant == EffectVariant.ROCKET) or (effect.Variant == 31)
        local isTarget = (EffectVariant and EffectVariant.TARGET and effect.Variant == EffectVariant.TARGET) or (effect.Variant == 30)
        if not (isRocket or isTarget) then return end
        local spawner = effect.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player then
            for i = 0, Game():GetNumPlayers() - 1 do
                local p = Isaac.GetPlayer(i)
                if Core.IsRingActive(p) and CollectibleType and CollectibleType.COLLECTIBLE_EPIC_FETUS and p:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) then
                    player = p
                    break
                end
            end
        end
        if not player or not Core.IsRingActive(player) then return end

        local ed = effect:GetData()
        ed.isGLRocket = true
        effect:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.15, 0.9, 0.25)
        local data = Core.GetPlayerData(player)
        data.ringFlareTimer = 10
    end)

    GL:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, function(_, effect)
        local isRocket = (EffectVariant and EffectVariant.ROCKET and effect.Variant == EffectVariant.ROCKET) or (effect.Variant == 31)
        local isTarget = (EffectVariant and EffectVariant.TARGET and effect.Variant == EffectVariant.TARGET) or (effect.Variant == 30)
        if not (isRocket or isTarget) then return end
        local ed = effect:GetData()
        if not (ed and ed.isGLRocket) then return end

        effect:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.15, 0.9, 0.25)
        if isRocket and Game():GetFrameCount() % 2 == 0 then
            pcall(function()
                local smoke = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SMOKE_CLOUD, 0, effect.Position, Vector.Zero, nil)
                if smoke then
                    smoke:GetSprite().Color = Color(0.1, 1.0, 0.38, 0.65, 0.1, 0.6, 0.15)
                    smoke.Scale = 0.55
                end
            end)
        end
    end)
end
