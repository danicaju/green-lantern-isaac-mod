-- modules/synergies_tier3.lua -- RSI: Sinergias Tier 3 (Exotic Status, Lasers & Defense Synergies)
-- Responsabilidad unica: Tech Zero, Eye of Belial, Little Horn, Euthanasia, Sinus/Mucor, Gnawed Leaf, Blanket, Mega Blast, Revelation, Shoop/Krampus, Scatter Bombs, Neptunus.

return function(Core)
    local GL = Core.GL

    -- 1. PRE-TEAR COLLISION: Eye of Belial (462), Little Horn (408), Sinus (507), Mucor (618)
    GL:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, function(_, tear, collider, low)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end
        if not (collider and collider.IsActiveEnemy and collider:IsActiveEnemy(false) and collider.IsVulnerableEnemy and collider:IsVulnerableEnemy()) then return end

        local td = tear:GetData()
        local luck = player.Luck or 0
        local baseDmg = tear.CollisionDamage or player.Damage or 3.5

        -- Eye of Belial (462): Empowered piercing emerald dread bolt
        local hasBelial = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_EYE_OF_BELIAL or 462))
        if hasBelial and not (td and td.isBelialEmpowered) then
            td.isBelialEmpowered = true
            pcall(function()
                tear.CollisionDamage = baseDmg * 2.0
                tear.Scale = (tear.Scale or 1.0) * 1.35
                local spr = tear:GetSprite()
                if spr then spr.Color = Color(0.1, 1.0, 0.38, 1, 0.40, 1.0, 0.35) end
                local fxVar = (EffectVariant and EffectVariant.HALO) or 10
                local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, tear.Position, Vector.Zero, player)
                if fx and Core.SetEntityScaleAndColor then
                    Core.SetEntityScaleAndColor(fx, 0.65, Color(0.1, 1.0, 0.38, 0.85, 0.3, 0.95, 0.3))
                end
            end)
        end

        -- Little Horn (408): Emerald Giant Fist Construct Smash
        local hasLittleHorn = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_LITTLE_HORN or 408))
        if hasLittleHorn and math.random() < math.min(0.40, 0.10 + luck * 0.03) then
            pcall(function()
                local sfx = (SoundEffect and SoundEffect.SOUND_PUNCH) or 0
                if sfx > 0 and SFXManager and SFXManager().Play then
                    SFXManager():Play(sfx, 1.0, 0, false, 0.85)
                end
                local fxVar = (EffectVariant and EffectVariant.PUNCH) or 88
                local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, collider.Position, Vector.Zero, player)
                if fx and Core.SetEntityScaleAndColor then
                    Core.SetEntityScaleAndColor(fx, 1.6, Color(0.1, 1.0, 0.38, 1, 0.35, 1.0, 0.35))
                end
                collider:TakeDamage(baseDmg * 4.0, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
                local data = Core.GetPlayerData(player)
                data.ringFlareTimer = 10
            end)
        end

        -- Sinus Infection (507) & Mucormycosis (618): Emerald construct tracking tag
        local hasSinus = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_SINUS_INFECTION or 507))
        local hasMucor = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_MUCORMYCOSIS or 618))
        if (hasSinus or hasMucor) and math.random() < math.min(0.50, 0.15 + luck * 0.03) then
            local ed = collider.GetData and collider:GetData()
            if ed and not ed.glConstructTagged then
                ed.glConstructTagged = true
                ed.glTagTimer = 90
                ed.glTagDmg = baseDmg * 0.35
            end
        end
    end)

    -- 2. POST-ENTITY-KILL: Euthanasia (499) Emerald Needle Burst
    GL:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, entity)
        if not (entity and entity.IsActiveEnemy and entity:IsActiveEnemy(false)) then return end
        local nPlayers = (Game().GetNumPlayers and Game():GetNumPlayers()) or 1
        local player = nil
        for i = 0, nPlayers - 1 do
            local p = Isaac.GetPlayer(i)
            if p and Core.IsRingActive(p) and p.HasCollectible and p:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_EUTHANASIA or 499)) then
                player = p; break
            end
        end
        if not player then return end

        local data = Core.GetPlayerData(player)
        data.itemTearBurstFrame = Game():GetFrameCount()
        data.ringFlareTimer = 8
        local dmg = (player.Damage or 3.5) * 0.75
        for i = 0, 9 do
            local angle = (i / 10) * math.pi * 2
            local vel = Vector(math.cos(angle) * 10.5, math.sin(angle) * 10.5)
            Core.SpawnGLConstructTear(player, entity.Position, vel, dmg, 0.50, "isEuthanasiaNeedle")
        end
        pcall(function()
            local sfx = (SoundEffect and SoundEffect.SOUND_TEARIMPACTS) or 0
            if sfx > 0 and SFXManager and SFXManager().Play then
                SFXManager():Play(sfx, 0.8, 0, false, 1.35)
            end
        end)
    end)

    -- 3. POST-NEW-ROOM: Blanket (540) Emerald Aegis Dome
    GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
        local room = Game and Game().GetRoom and Game():GetRoom()
        local isBossRoom = room and room.GetType and (room:GetType() == (RoomType.ROOM_BOSS or 4))
        if not isBossRoom then return end

        local nPlayers = (Game().GetNumPlayers and Game():GetNumPlayers()) or 1
        for i = 0, nPlayers - 1 do
            local player = Isaac.GetPlayer(i)
            if player and Core.IsRingActive(player) then
                local hasBlanket = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_BLANKET or 540))
                if hasBlanket then
                    pcall(function()
                        local fxVar = (EffectVariant and EffectVariant.HALO) or 10
                        local dome = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, player.Position, Vector.Zero, player)
                        if dome and Core.SetEntityScaleAndColor then
                            Core.SetEntityScaleAndColor(dome, 1.8, Color(0.1, 1.0, 0.38, 0.75, 0.25, 0.95, 0.30))
                        end
                        if player.SetShieldTimer then player:SetShieldTimer(90) end
                    end)
                    local data = Core.GetPlayerData(player)
                    data.ringFlareTimer = 15
                end
            end
        end
    end)

    -- 4. POST-PLAYER-UPDATE: Gnawed Leaf (210) & Tagged Enemy Ticks
    GL:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
        if not Core.IsRingActive(player) then return end

        local hasLeaf = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_GNAWED_LEAF or 210))
        if hasLeaf then
            local spr = player:GetSprite()
            if spr and player.IsInvulnerable and player:IsInvulnerable() then
                local frame = Game():GetFrameCount()
                if (frame % 4) == 0 and Isaac and Isaac.Spawn then
                    local fxVar = (EffectVariant and EffectVariant.HALO) or 10
                    local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, player.Position, Vector.Zero, player)
                    if fx and Core.SetEntityScaleAndColor then
                        Core.SetEntityScaleAndColor(fx, 0.70, Color(0.1, 1.0, 0.38, 0.45, 0.20, 0.85, 0.25))
                    end
                end
            end
        end
    end)

    -- 5. LASER SYNERGIES: Tech Zero (502), Mega Blast (441), Revelation (643), Shoop da Whoop (49), Krampus (293)
    GL:AddCallback(ModCallbacks.MC_POST_LASER_INIT, function(_, laser)
        local spawner = laser.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        local hasZero = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_TECH_ZERO or 502))
        local hasMega = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_MEGA_BLAST or 441))
        local hasRev = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_REVELATION or 643))
        local hasShoop = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_SHOOP_DA_WHOOP or 49))
        local hasKrampus = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_HEAD_OF_KRAMPUS or 293))

        if not (hasZero or hasMega or hasRev or hasShoop or hasKrampus) then return end

        local ld = laser:GetData()
        if ld.glLaserTier3Init then return end
        ld.glLaserTier3Init = true

        pcall(function()
            if hasMega then
                laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.40, 1.0, 0.40)
                laser.CollisionDamage = laser.CollisionDamage * 1.25
            elseif hasRev then
                laser:GetSprite().Color = Core.GL_EMERALD_BRIGHT
                laser.CollisionDamage = laser.CollisionDamage * 1.20
            elseif hasShoop or hasKrampus then
                laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.25)
                laser.CollisionDamage = laser.CollisionDamage * 1.25
            elseif hasZero then
                laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.30, 1.0, 0.35)
                laser.CollisionDamage = laser.CollisionDamage * 1.20
            end
            local data = Core.GetPlayerData(player)
            data.ringFlareTimer = 8
        end)
    end)

    -- 6. SCATTER BOMBS (366): Dr. Fetus Emerald Cluster Bombs
    GL:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, function(_, entity)
        if entity.Type ~= EntityType.ENTITY_BOMB then return end
        local spawner = entity.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        local hasScatter = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_SCATTER_BOMBS or 366))
        local ed = entity.GetData and entity:GetData()
        local isFetusOrGL = entity.IsFetus or (ed and ed.isGLBomb)
        if not (hasScatter and isFetusOrGL) then return end

        local data = Core.GetPlayerData(player)
        data.itemTearBurstFrame = Game():GetFrameCount()
        data.ringFlareTimer = 8
        local dmg = (player.Damage or 3.5) * 0.70
        for i = 0, 2 do
            local angle = (i / 3) * math.pi * 2 + math.random() * 0.5
            local vel = Vector(math.cos(angle) * 6.5, math.sin(angle) * 6.5)
            Core.SpawnGLConstructTear(player, entity.Position, vel, dmg, 0.60, "isScatterShard")
        end
    end)

    -- 7. NEPTUNUS (597): Rapid-Fire Emerald Construct Burst
    GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        local hasNep = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_NEPTUNUS or 597))
        if not hasNep then return end

        local td = tear:GetData()
        if not td.isGLNeptunusStyled then
            td.isGLNeptunusStyled = true
            pcall(function()
                local spr = tear:GetSprite()
                if spr then spr.Color = Core.GL_EMERALD_COLOR end
            end)
        end
    end)

    -- 8. CONTINUOUS BEAM ENEMIES HIT: Tagged enemy proc
    local prevContHook = Core.OnContinuousBeamHitEnemy
    Core.OnContinuousBeamHitEnemy = function(player, ent, hitPos, tickDmg, segDir)
        if prevContHook then prevContHook(player, ent, hitPos, tickDmg, segDir) end
        if not player or not Core.IsRingActive(player) then return end

        local ed = ent.GetData and ent:GetData()
        if ed and ed.glConstructTagged and ent:Exists() and not ent:IsDead() then
            pcall(function()
                ent:TakeDamage(tickDmg * 0.40, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
            end)
        end
    end
end
