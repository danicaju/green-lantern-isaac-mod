-- modules/synergies_fetus.lua -- RSI: Sinergias de Dr. Fetus y Epic Fetus (Hard-Light Constructs)
-- Responsabilidad unica: Deteccion, estilizacion construct emerald, tap fire y continuous beam orbital strikes.

return function(Core)
    local GL = Core.GL

    -- Helper: check if a ring-active player owns this Dr./Epic Fetus entity.
    local function IsFetusOwner(player, entity, isEpic)
        local ed = entity.GetData and entity:GetData()
        local hasEpic = CollectibleType and CollectibleType.COLLECTIBLE_EPIC_FETUS and player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS)
        local hasDr = CollectibleType and CollectibleType.COLLECTIBLE_DR_FETUS and player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS)
        if isEpic then
            return hasEpic or (ed and ed.isGLRocket)
        else
            return hasDr or entity.IsFetus or (ed and ed.isGLBomb)
        end
    end

    -- Helper to resolve ring-active owner even when Isaac engine leaves SpawnerEntity nil
    local function FindRingFetusPlayer(entity, isEpic)
        local spawner = entity.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if player and Core.IsRingActive(player) and IsFetusOwner(player, entity, isEpic) then
            return player
        end
        local nPlayers = (Game().GetNumPlayers and Game():GetNumPlayers()) or 1
        for i = 0, nPlayers - 1 do
            local p = Isaac.GetPlayer(i)
            if p and Core.IsRingActive(p) and IsFetusOwner(p, entity, isEpic) then
                return p
            end
        end
        return nil
    end

    local function NormalizeVector(v, fallback)
        if not v then return fallback or Vector(1, 0) end
        if v.Length and v.Normalized then
            if v:Length() > 0.001 then return v:Normalized() end
        elseif v.X and v.Y then
            local len = math.sqrt(v.X * v.X + v.Y * v.Y)
            if len > 0.001 then
                return Vector(v.X / len, v.Y / len)
            end
        end
        return fallback or Vector(1, 0)
    end

    -- Helper: emerald smoke trail for Epic Fetus rockets.
    local function SpawnRocketSmoke(pos, spawner)
        pcall(function()
            local smokeVar = (EffectVariant and EffectVariant.SMOKE_CLOUD) or 141
            local smoke = Isaac.Spawn(EntityType.ENTITY_EFFECT, smokeVar, 0, pos, Vector.Zero, spawner)
            if smoke then
                smoke.CollisionDamage = 0
                pcall(function()
                    smoke:GetSprite().Color = Color(0.1, 1.0, 0.38, 0.65, 0.1, 0.6, 0.15)
                    smoke.Scale = 0.55
                end)
            end
        end)
    end

    -- Helper: spawn Epic Fetus target marker + rocket bomb at a world position.
    -- dmgMult permite nerfear SOLO los cohetes del canal continuo sin tocar el
    -- disparo normal de Epic Fetus (que sigue usando el multiplicador clasico).
    local function SpawnEpicFetusRocket(player, pos, data, dmgMult)
        local targetVar = (EffectVariant and EffectVariant.TARGET) or 30
        local target = Isaac.Spawn(EntityType.ENTITY_EFFECT, targetVar, 0, pos, Vector.Zero, player)
        if target then
            target:GetSprite().Color = Core.GL_EMERALD_COLOR
            target:GetData().isGLRocket = true
        end
        local rocketVar = (BombVariant and BombVariant.BOMB_ROCKET) or 19
        local rocket = Isaac.Spawn(EntityType.ENTITY_BOMB, rocketVar, 0, pos, Vector.Zero, player)
        if rocket then
            local rd = rocket:GetData()
            rd.isGLBomb = true
            rd.isGLRocket = true
            pcall(function()
                local spr = rocket:GetSprite()
                if spr then spr.Color = Core.GL_EMERALD_BRIGHT end
            end)
        end
        data.ringFlareTimer = 10
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
                spr.Color = isRocket and Core.GL_EMERALD_BRIGHT or Core.GL_EMERALD_COLOR
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
                spr.Color = isRocket and Core.GL_EMERALD_BRIGHT or Core.GL_EMERALD_COLOR
            end
        end)
        if isRocket and Game():GetFrameCount() % 2 == 0 then
            local spawner = effect.SpawnerEntity or (Isaac.GetPlayer and Isaac.GetPlayer(0))
            SpawnRocketSmoke(effect.Position, spawner)
        end
    end)

    -- 2. DR. FETUS & EPIC FETUS BOMBS: Hard-Light Emerald Construct Bombs & Rockets
    GL:AddCallback(ModCallbacks.MC_POST_BOMB_INIT, function(_, bomb)
        local rocketVar = (BombVariant and BombVariant.BOMB_ROCKET) or 19
        local gigaVar = (BombVariant and BombVariant.BOMB_GIGA_ROCKET) or 20
        local isRocket = (bomb.Variant == rocketVar) or (bomb.Variant == gigaVar)
        local bd = bomb:GetData()
        local isFetusBomb = (bomb.IsFetus == true) or (bd and bd.isGLBomb == true)
        -- STRICT: only actual Dr. Fetus shots or Epic Fetus rockets are styled. Normal inventory bombs remain 100% vanilla.
        if not (isRocket or isFetusBomb) then return end

        local player = FindRingFetusPlayer(bomb, isRocket)
        if not player then return end

        bd.isGLBomb = true
        if isRocket then bd.isGLRocket = true end
        bomb.DepthOffset = 30
        pcall(function()
            local spr = bomb:GetSprite()
            if spr then
                spr.Color = isRocket and Core.GL_EMERALD_BRIGHT or Core.GL_EMERALD_DIM
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
                spr.Color = bd.isGLRocket and Core.GL_EMERALD_BRIGHT or Core.GL_EMERALD_DIM
            end
        end)
        if bd.isGLRocket and Game():GetFrameCount() % 2 == 0 then
            SpawnRocketSmoke(bomb.Position, bomb.SpawnerEntity)
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
            local aimDir = NormalizeVector(dir, data.lastShootDir or Vector(1, 0))
            local targetPos = Vector(player.Position.X + aimDir.X * 180, player.Position.Y + aimDir.Y * 180)
            local room = Game and Game().GetRoom and Game():GetRoom()
            if room and room.GetClampedPosition then targetPos = room:GetClampedPosition(targetPos, 20) end
            SpawnEpicFetusRocket(player, targetPos, data)
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
                    b.ExplosionDamage = (player.Damage or 3.5) * (dmgMult or 5.0)
                end
                local bd = bomb:GetData()
                bd.isGLBomb = true
                bomb.DepthOffset = 30
                pcall(function()
                    local spr = bomb:GetSprite()
                    if spr then spr.Color = Core.GL_EMERALD_DIM end
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

        -- Nerf: 1 cohete cada 90 frames (3 s) en vez de cada 45 (1.5 s). El
        -- dano del cohete continua ademas se reduce a x2.0 (ver abajo).
        if hasEpic and (frame % 90 == 0) then
            local aimDir = NormalizeVector(shootDir, Vector(1, 0))
            local strikePos = nil
            local room = Game and Game().GetRoom and Game():GetRoom()
            local ents = Isaac.FindInRadius and Isaac.FindInRadius(player.Position + aimDir * 150, 180, EntityPartition and EntityPartition.ENEMY or 0)
            if ents then
                for _, e in ipairs(ents) do
                    if e and e.IsVulnerableEnemy and e:IsVulnerableEnemy() then
                        strikePos = e.Position
                        break
                    end
                end
            end
            if not strikePos then
                strikePos = Vector(player.Position.X + aimDir.X * 200, player.Position.Y + aimDir.Y * 200)
                if room and room.GetClampedPosition then strikePos = room:GetClampedPosition(strikePos, 24) end
            end

            SpawnEpicFetusRocket(player, strikePos, data, 2.0)
        elseif hasDr and (frame % 60 == 0) then
            local vel = Vector(shootDir.X * 11.0, shootDir.Y * 11.0)
            local bombVar = (BombVariant and BombVariant.BOMB_NORMAL) or 0
            local bomb = Isaac.Spawn(EntityType.ENTITY_BOMB, bombVar, 0, startWorld, vel, player)
            if bomb then
                local b = bomb:ToBomb()
                if b then
                    b.IsFetus = true
                    -- Nerf del canal continuo: x2.0 en vez de x4.0.
                    b.ExplosionDamage = (player.Damage or 3.5) * 2.0
                end
                local bd = bomb:GetData()
                bd.isGLBomb = true
                bomb.DepthOffset = 30
                pcall(function()
                    local spr = bomb:GetSprite()
                    if spr then spr.Color = Core.GL_EMERALD_DIM end
                end)
            end
            data.ringFlareTimer = 8
        end
    end
end
