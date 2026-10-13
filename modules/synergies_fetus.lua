-- modules/synergies_fetus.lua -- RSI: Sinergias de Dr. Fetus y Epic Fetus (Hard-Light Constructs)
-- Responsabilidad unica: Deteccion, estilizacion construct emerald, tap fire y continuous beam orbital strikes.

return function(Core)
    local GL = Core.GL

    -- Helper to resolve ring-active owner even when Isaac engine leaves SpawnerEntity nil
    local function FindRingFetusPlayer(entity, isEpic)
        local spawner = entity.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if player and Core.IsRingActive(player) then return player end
        local nPlayers = (Game().GetNumPlayers and Game():GetNumPlayers()) or 1
        for i = 0, nPlayers - 1 do
            local p = Isaac.GetPlayer(i)
            if p and Core.IsRingActive(p) then
                local hasEpic = CollectibleType and CollectibleType.COLLECTIBLE_EPIC_FETUS and p:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS)
                local hasDr = CollectibleType and CollectibleType.COLLECTIBLE_DR_FETUS and p:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS)
                if isEpic and hasEpic then return p end
                if (not isEpic) and (hasDr or hasEpic) then return p end
                if Core.IsHalJordan(p) or Core.IsTaintedHal(p) then return p end
            end
        end
        return nil
    end

    -- 1. EPIC FETUS TARGET & ROCKET EFFECT STYLING
    GL:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, function(_, effect)
        local isRocket = (EffectVariant and EffectVariant.ROCKET and effect.Variant == EffectVariant.ROCKET) or (effect.Variant == 31)
        local isTarget = (EffectVariant and EffectVariant.TARGET and effect.Variant == EffectVariant.TARGET) or (effect.Variant == 30)
        if not (isRocket or isTarget) then return end
        local player = FindRingFetusPlayer(effect, true)
        if not player then return end

        local ed = effect:GetData()
        ed.isGLRocket = true
        pcall(function()
            local spr = effect:GetSprite()
            if spr then
                spr.Color = isRocket and Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30) or Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25)
            end
        end)
        local data = Core.GetPlayerData(player)
        data.ringFlareTimer = 10
    end)

    GL:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, function(_, effect)
        local isRocket = (EffectVariant and EffectVariant.ROCKET and effect.Variant == EffectVariant.ROCKET) or (effect.Variant == 31)
        local isTarget = (EffectVariant and EffectVariant.TARGET and effect.Variant == EffectVariant.TARGET) or (effect.Variant == 30)
        if not (isRocket or isTarget) then return end
        local ed = effect:GetData()
        if not (ed and ed.isGLRocket) then return end

        pcall(function()
            local spr = effect:GetSprite()
            if spr then
                spr.Color = isRocket and Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30) or Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25)
            end
        end)
        if isRocket and Game():GetFrameCount() % 2 == 0 then
            pcall(function()
                local spawner = effect.SpawnerEntity or (Isaac.GetPlayer and Isaac.GetPlayer(0))
                local smokeVar = (EffectVariant and EffectVariant.SMOKE_CLOUD) or 141
                local smoke = Isaac.Spawn(EntityType.ENTITY_EFFECT, smokeVar, 0, effect.Position, Vector.Zero, spawner)
                if smoke then
                    smoke.CollisionDamage = 0
                    pcall(function()
                        smoke:GetSprite().Color = Color(0.1, 1.0, 0.38, 0.65, 0.1, 0.6, 0.15)
                        smoke.Scale = 0.55
                    end)
                end
            end)
        end
    end)

    -- 2. DR. FETUS & EPIC FETUS BOMBS: Hard-Light Emerald Construct Bombs & Rockets
    GL:AddCallback(ModCallbacks.MC_POST_BOMB_INIT, function(_, bomb)
        local rocketVar = (BombVariant and BombVariant.BOMB_ROCKET) or 19
        local gigaVar = (BombVariant and BombVariant.BOMB_GIGA_ROCKET) or 20
        local isRocket = (bomb.Variant == rocketVar) or (bomb.Variant == gigaVar)
        local player = FindRingFetusPlayer(bomb, isRocket)
        if not player then return end

        local bd = bomb:GetData()
        bd.isGLBomb = true
        if isRocket then bd.isGLRocket = true end
        bomb.DepthOffset = 30
        pcall(function()
            local spr = bomb:GetSprite()
            if spr then
                spr.Color = isRocket and Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30) or Color(0.1, 1.0, 0.38, 1, 0.15, 0.85, 0.25)
            end
        end)
        local data = Core.GetPlayerData(player)
        data.ringFlareTimer = 8
    end)

    GL:AddCallback(ModCallbacks.MC_POST_BOMB_UPDATE, function(_, bomb)
        local bd = bomb:GetData()
        if not (bd and bd.isGLBomb) then return end

        pcall(function()
            local spr = bomb:GetSprite()
            if spr then
                spr.Color = bd.isGLRocket and Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30) or Color(0.1, 1.0, 0.38, 1, 0.15, 0.85, 0.25)
            end
        end)
        if bd.isGLRocket and Game():GetFrameCount() % 2 == 0 then
            pcall(function()
                local smokeVar = (EffectVariant and EffectVariant.SMOKE_CLOUD) or 141
                local smoke = Isaac.Spawn(EntityType.ENTITY_EFFECT, smokeVar, 0, bomb.Position, Vector.Zero, bomb.SpawnerEntity)
                if smoke then
                    smoke.CollisionDamage = 0
                    pcall(function()
                        smoke:GetSprite().Color = Color(0.1, 1.0, 0.38, 0.65, 0.1, 0.6, 0.15)
                        smoke.Scale = 0.55
                    end)
                end
            end)
        end
    end)

    GL:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, function(_, entity)
        if entity.Type ~= EntityType.ENTITY_BOMB then return end
        local bd = entity:GetData()
        if not (bd and bd.isGLBomb) then return end

        pcall(function()
            local effectVar = (EffectVariant and EffectVariant.WATER_SPLASH) or 10
            local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, effectVar, 0, entity.Position, Vector.Zero, entity.SpawnerEntity)
            if fx then
                Core.SetEntityScaleAndColor(fx, 1.25, Color(0.1, 1.0, 0.35, 0.95, 0.20, 0.90, 0.30))
            end
            local bonusDmg = 15.0
            local ents = Isaac.FindInRadius and Isaac.FindInRadius(entity.Position, 90.0, EntityPartition and EntityPartition.ENEMY or 0)
            if ents then
                for _, enemy in ipairs(ents) do
                    if enemy and enemy.IsVulnerableEnemy and enemy:IsVulnerableEnemy() then
                        enemy:TakeDamage(bonusDmg, DamageFlag and DamageFlag.DAMAGE_NO_MODIFIERS or 0, EntityRef(entity), 0)
                        local spawner = entity.SpawnerEntity or (Isaac.GetPlayer and Isaac.GetPlayer(0))
                        local p = spawner and spawner:ToPlayer()
                        if p and Core.IsTaintedHal(p) and EntityFlag and EntityFlag.FLAG_FEAR then
                            enemy:AddEntityFlags(EntityFlag.FLAG_FEAR)
                        end
                    end
                end
            end
        end)
    end)

    -- 3. TAP FIRE CONSTRUCT LAUNCHING
    function Core.FireFetusTapConstruct(player, data, dir, shotSpeed, spawnOffset)
        local hasEpic = CollectibleType and CollectibleType.COLLECTIBLE_EPIC_FETUS and player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS)
        local hasDr   = CollectibleType and CollectibleType.COLLECTIBLE_DR_FETUS and player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS)
        if not (hasEpic or hasDr) then return false end

        if hasEpic then
            local targetPos = Vector(player.Position.X + dir.X * 180, player.Position.Y + dir.Y * 180)
            local room = Game():GetRoom()
            if room and room.GetClampedPosition then targetPos = room:GetClampedPosition(targetPos, 20) end
            local targetVar = (EffectVariant and EffectVariant.TARGET) or 30
            local target = Isaac.Spawn(EntityType.ENTITY_EFFECT, targetVar, 0, targetPos, Vector.Zero, player)
            if target then
                target:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25)
                target:GetData().isGLRocket = true
            end
            local rocketVar = (BombVariant and BombVariant.BOMB_ROCKET) or 19
            local rocket = Isaac.Spawn(EntityType.ENTITY_BOMB, rocketVar, 0, targetPos, Vector.Zero, player)
            if rocket then
                local rd = rocket:GetData()
                rd.isGLBomb = true
                rd.isGLRocket = true
                pcall(function()
                    local spr = rocket:GetSprite()
                    if spr then spr.Color = Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30) end
                end)
            end
            data.ringFlareTimer = 10
            return true
        else
            local velSpeed = math.max(8.0, shotSpeed * 0.95)
            local vel = Vector(dir.X * velSpeed, dir.Y * velSpeed)
            pcall(function()
                local inh = player:GetTearMovementInheritance(dir)
                if inh then vel = Vector(vel.X + (inh.X or 0), vel.Y + (inh.Y or 0)) end
            end)
            local spawnPos = spawnOffset and Vector(player.Position.X + spawnOffset.X, player.Position.Y + spawnOffset.Y) or player.Position
            local bombVar = (BombVariant and BombVariant.BOMB_NORMAL) or 0
            local bomb = Isaac.Spawn(EntityType.ENTITY_BOMB, bombVar, 0, spawnPos, vel, player)
            if bomb then
                local b = bomb:ToBomb()
                if b then
                    b.IsFetus = true
                    b.ExplosionDamage = (player.Damage or 3.5) * 5.0
                end
                local bd = bomb:GetData()
                bd.isGLBomb = true
                bomb.DepthOffset = 30
                pcall(function()
                    local spr = bomb:GetSprite()
                    if spr then spr.Color = Color(0.1, 1.0, 0.38, 1, 0.15, 0.85, 0.25) end
                end)
            end
            data.ringFlareTimer = 8
            return true
        end
    end

    -- 4. CONTINUOUS BEAM CHANNELING CONSTRUCT LAUNCHING
    function Core.TickFetusContinuousSynergy(player, data, startWorld, shootDir, endWorld, frame)
        local hasEpic = CollectibleType and CollectibleType.COLLECTIBLE_EPIC_FETUS and player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS)
        local hasDr   = CollectibleType and CollectibleType.COLLECTIBLE_DR_FETUS and player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS)
        if not (hasEpic or hasDr) then return end

        if hasEpic and (frame % 45 == 0) then
            local targetVar = (EffectVariant and EffectVariant.TARGET) or 30
            local target = Isaac.Spawn(EntityType.ENTITY_EFFECT, targetVar, 0, endWorld, Vector.Zero, player)
            if target then
                target:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25)
                target:GetData().isGLRocket = true
            end
            local rocketVar = (BombVariant and BombVariant.BOMB_ROCKET) or 19
            local rocket = Isaac.Spawn(EntityType.ENTITY_BOMB, rocketVar, 0, endWorld, Vector.Zero, player)
            if rocket then
                local rd = rocket:GetData()
                rd.isGLBomb = true
                rd.isGLRocket = true
                pcall(function()
                    local spr = rocket:GetSprite()
                    if spr then spr.Color = Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30) end
                end)
            end
            data.ringFlareTimer = 10
        elseif hasDr and (frame % 30 == 0) then
            local vel = Vector(shootDir.X * 11.0, shootDir.Y * 11.0)
            local bombVar = (BombVariant and BombVariant.BOMB_NORMAL) or 0
            local bomb = Isaac.Spawn(EntityType.ENTITY_BOMB, bombVar, 0, startWorld, vel, player)
            if bomb then
                local b = bomb:ToBomb()
                if b then
                    b.IsFetus = true
                    b.ExplosionDamage = (player.Damage or 3.5) * 4.0
                end
                local bd = bomb:GetData()
                bd.isGLBomb = true
                bomb.DepthOffset = 30
                pcall(function()
                    local spr = bomb:GetSprite()
                    if spr then spr.Color = Color(0.1, 1.0, 0.38, 1, 0.15, 0.85, 0.25) end
                end)
            end
            data.ringFlareTimer = 8
        end
    end
end
