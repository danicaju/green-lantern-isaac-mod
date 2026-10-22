-- modules/synergies_tier1.lua -- RSI: Sinergias Tier 1 (Hard-Light Constructs)
-- Responsabilidad unica: Knockout Drops, Sad Bombs, Holy Light, Trisagion, Uranus, Terra, Ocular Rift, Anti-Gravity, Spirit Sword, C-Section.

return function(Core)
    local GL = Core.GL

    -- Helper: spawn an emerald construct shard / burst tear
    local function SpawnConstructTear(player, pos, vel, damage, scale, flag)
        local tear = nil
        if player and player.FireTear then
            tear = player:FireTear(pos, vel, false, true, false)
        elseif Isaac and Isaac.Spawn then
            local tVar = (TearVariant and TearVariant.DEFAULT) or 0
            tear = Isaac.Spawn(EntityType.ENTITY_TEAR, tVar, 0, pos, vel, player)
            if tear and tear.ToTear then tear = tear:ToTear() end
        end
        if tear then
            tear.CollisionDamage = damage
            local sd = tear:GetData()
            sd.isGLRingBeam = true
            if flag then sd[flag] = true end
            if Core.ApplyRingBeamSprite then
                Core.ApplyRingBeamSprite(tear, scale or 0.65)
            end
        end
        return tear
    end

    -- 1. KNOCKOUT DROPS (577): Hal's signature Giant Emerald Boxing Glove Construct Punch
    local function TriggerBoxingGlovePunch(player, target, hitPos, punchDir)
        local pos = hitPos or target.Position
        local dir = punchDir or Vector(1, 0)
        pcall(function()
            local sfx = (SoundEffect and SoundEffect.SOUND_PUNCH) or 0
            if sfx > 0 and SFXManager and SFXManager().Play then
                SFXManager():Play(sfx, 1.0, 0, false, 0.95)
            end
            local fxVar = (EffectVariant and EffectVariant.PUNCH) or (EffectVariant and EffectVariant.WATER_SPLASH) or 20
            local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, pos, Vector.Zero, player)
            if fx and Core.SetEntityScaleAndColor then
                Core.SetEntityScaleAndColor(fx, 1.30, Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30))
            end
            if target and target.Velocity then
                target.Velocity = Vector((target.Velocity.X or 0) + dir.X * 14.0, (target.Velocity.Y or 0) + dir.Y * 14.0)
            end
            if target and target.TakeDamage then
                target:TakeDamage((player.Damage or 3.5) * 2.5, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
            end
            if target and target.AddConfusion then
                target:AddConfusion(EntityRef(player), 60)
            end
        end)
        local data = Core.GetPlayerData(player)
        data.ringFlareTimer = 8
    end

    -- 2. HOLY LIGHT (374): Emerald Hard-Light Orbital Laser Pillars
    local function TriggerHolyLightColumn(player, target, hitPos)
        local pos = hitPos or target.Position
        pcall(function()
            local sfx = (SoundEffect and SoundEffect.SOUND_SUPERHOLY) or 0
            if sfx > 0 and SFXManager and SFXManager().Play then
                SFXManager():Play(sfx, 0.85, 0, false, 1.20)
            end
            local fxVar = (EffectVariant and EffectVariant.CRACK_THE_SKY) or (EffectVariant and EffectVariant.HALO) or 10
            local column = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, pos, Vector.Zero, player)
            if column then
                local spr = column:GetSprite()
                if spr then spr.Color = Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30) end
            end
            if target and target.TakeDamage then
                target:TakeDamage((player.Damage or 3.5) * 4.0, DamageFlag.DAMAGE_LASER, EntityRef(player), 0)
            end
        end)
        local data = Core.GetPlayerData(player)
        data.ringFlareTimer = 10
    end

    -- 3. OCULAR RIFT (578): Emerald Gravitational Singularity Rift
    local function TriggerOcularRift(player, target, hitPos)
        local pos = hitPos or target.Position
        pcall(function()
            local riftVar = (EffectVariant and EffectVariant.RIFT) or 110
            local rift = Isaac.Spawn(EntityType.ENTITY_EFFECT, riftVar, 0, pos, Vector.Zero, player)
            if rift then
                local spr = rift:GetSprite()
                if spr then spr.Color = Color(0.1, 1.0, 0.38, 1, 0.20, 0.90, 0.30) end
            end
        end)
    end

    -- 4. ON-TEAR COLLISION: Knockout Drops, Holy Light, Ocular Rift, Terra
    GL:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, function(_, tear, collider, low)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end
        if not (collider and collider.IsActiveEnemy and collider:IsActiveEnemy(false) and collider.IsVulnerableEnemy and collider:IsVulnerableEnemy()) then return end

        local luck = player.Luck or 0
        local vel = tear.Velocity
        local dir = (vel and (vel.X ~= 0 or vel.Y ~= 0)) and vel:Normalized() or Vector(1, 0)

        -- Knockout Drops
        local hasKnockout = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_KNOCKOUT_DROPS or 577))
        if hasKnockout and math.random() < math.min(0.50, 0.15 + luck * 0.03) then
            TriggerBoxingGlovePunch(player, collider, tear.Position, dir)
        end

        -- Holy Light
        local hasHolyLight = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_HOLY_LIGHT or 374))
        if hasHolyLight and math.random() < math.min(0.50, 0.10 + luck * 0.04) then
            TriggerHolyLightColumn(player, collider, tear.Position)
        end

        -- Ocular Rift
        local hasRift = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_OCULAR_RIFT or 578))
        if hasRift and math.random() < math.min(0.35, 0.08 + luck * 0.02) then
            TriggerOcularRift(player, collider, tear.Position)
        end

        -- Terra
        local hasTerra = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_TERRA or 602))
        if hasTerra then
            pcall(function()
                local sfx = (SoundEffect and SoundEffect.SOUND_ROCK_CRUMBLE) or 0
                if sfx > 0 and SFXManager and SFXManager().Play then
                    SFXManager():Play(sfx, 0.75, 0, false, 1.1)
                end
                if collider.Velocity then
                    collider.Velocity = Vector((collider.Velocity.X or 0) + dir.X * 6.0, (collider.Velocity.Y or 0) + dir.Y * 6.0)
                end
            end)
        end
    end)

    -- 5. CONTINUOUS BEAM ENEMIES HIT: Knockout Drops, Holy Light, Ocular Rift
    local prevContHook = Core.OnContinuousBeamHitEnemy
    Core.OnContinuousBeamHitEnemy = function(player, ent, hitPos, tickDmg, segDir)
        if prevContHook then prevContHook(player, ent, hitPos, tickDmg, segDir) end
        if not player or not Core.IsRingActive(player) then return end

        local frame = Game():GetFrameCount()
        local ed = ent.GetData and ent:GetData()
        if ed then
            if ed.lastGLTier1ProcFrame and (frame - ed.lastGLTier1ProcFrame) < 25 then return end
            ed.lastGLTier1ProcFrame = frame
        end

        local luck = player.Luck or 0
        local dir = segDir or Vector(1, 0)

        if player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_KNOCKOUT_DROPS or 577)) then
            if math.random() < math.min(0.40, 0.12 + luck * 0.02) then
                TriggerBoxingGlovePunch(player, ent, hitPos, dir)
            end
        end

        if player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_HOLY_LIGHT or 374)) then
            if math.random() < math.min(0.40, 0.08 + luck * 0.03) then
                TriggerHolyLightColumn(player, ent, hitPos)
            end
        end

        if player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_OCULAR_RIFT or 578)) then
            if math.random() < math.min(0.30, 0.06 + luck * 0.02) then
                TriggerOcularRift(player, ent, hitPos)
            end
        end
    end

    -- 6. SAD BOMBS (220): 10 Radial Emerald Ring Beams on Bomb Detonation
    GL:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, function(_, entity)
        if entity.Type ~= EntityType.ENTITY_BOMB then return end
        local bomb = entity.ToBomb and entity:ToBomb()
        local spawner = entity.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player then
            local nPlayers = (Game().GetNumPlayers and Game():GetNumPlayers()) or 1
            for i = 0, nPlayers - 1 do
                local p = Isaac.GetPlayer(i)
                if p and Core.IsRingActive(p) then player = p; break end
            end
        end
        if not player or not Core.IsRingActive(player) then return end

        local bd = entity.GetData and entity:GetData()
        local isFetusOrGL = entity.IsFetus or (bd and bd.isGLBomb)
        local hasSadBombs = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_SAD_BOMBS or 220))
        if not (hasSadBombs and (isFetusOrGL or (bomb and bomb.IsFetus))) then return end

        local data = Core.GetPlayerData(player)
        data.itemTearBurstFrame = Game():GetFrameCount()
        data.ringFlareTimer = 10

        local dmg = (player.Damage or 3.5) * 1.0
        local count = 10
        for i = 0, count - 1 do
            local angle = (i / count) * math.pi * 2
            local vel = Vector(math.cos(angle) * 9.5, math.sin(angle) * 9.5)
            SpawnConstructTear(player, entity.Position, vel, dmg, 0.75, "isSadBombShard")
        end
    end)

    -- 7. TEAR UPDATES: Trisagion (533), Terra (602), Anti-Gravity (222), C-Section (678)
    GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        local hasTris = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_TRISAGION or 533))
        local hasTerra = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_TERRA or 602))
        local hasAntiGrav = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_ANTI_GRAVITY or 222))
        local hasCSection = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_C_SECTION or 678))
        if not (hasTris or hasTerra or hasAntiGrav or hasCSection) then return end

        local td = tear:GetData()
        pcall(function()
            local spr = tear:GetSprite()
            if not spr then return end
            if hasTris then
                if not td.isGLTrisagion then
                    td.isGLTrisagion = true
                    tear.CollisionDamage = (tear.CollisionDamage or player.Damage or 3.5) * 1.25
                end
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25)
                local frame = Game():GetFrameCount()
                if frame % 4 == 0 and Isaac and Isaac.Spawn then
                    local fxVar = (EffectVariant and EffectVariant.HALO) or 10
                    local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, tear.Position, Vector.Zero, player)
                    if fx and Core.SetEntityScaleAndColor then
                        Core.SetEntityScaleAndColor(fx, 0.45, Color(0.1, 1.0, 0.38, 0.60, 0.15, 0.85, 0.25))
                    end
                end
            elseif hasTerra then
                spr.Color = Color(0.08, 0.85, 0.30, 1, 0.10, 0.70, 0.15)
            elseif hasAntiGrav then
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30)
            elseif hasCSection then
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.30)
                if not td.isGLCSection then
                    td.isGLCSection = true
                    tear.CollisionDamage = (tear.CollisionDamage or player.Damage or 3.5) * 1.20
                end
            end
        end)
    end)

    -- 8. URANUS (598): Crystalline Emerald Construct Shatter Shards
    GL:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, entity)
        if not (entity and entity.IsActiveEnemy and entity:IsActiveEnemy(false)) then return end
        local nPlayers = (Game().GetNumPlayers and Game():GetNumPlayers()) or 1
        local player = nil
        for i = 0, nPlayers - 1 do
            local p = Isaac.GetPlayer(i)
            if p and Core.IsRingActive(p) and p.HasCollectible and p:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_URANUS or 598)) then
                player = p; break
            end
        end
        if not player then return end

        local data = Core.GetPlayerData(player)
        data.itemTearBurstFrame = Game():GetFrameCount()
        local dmg = (player.Damage or 3.5) * 0.40
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2
            local vel = Vector(math.cos(angle) * 7.5, math.sin(angle) * 7.5)
            SpawnConstructTear(player, entity.Position, vel, dmg, 0.55, "isUranusShard")
        end
        pcall(function()
            local sfx = (SoundEffect and SoundEffect.SOUND_GLASS_BREAK) or 0
            if sfx > 0 and SFXManager and SFXManager().Play then
                SFXManager():Play(sfx, 0.8, 0, false, 1.25)
            end
        end)
    end)

    -- 10. SPIRIT SWORD (579): Emerald Hard-Light Energy Blade Slashing
    GL:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, function(_, knife)
        local spawner = knife.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end
        if not (player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_SPIRIT_SWORD or 579))) then return end

        pcall(function()
            local spr = knife:GetSprite()
            if spr then
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.15, 0.90, 0.25)
            end
        end)
        local data = Core.GetPlayerData(player)
        data.ringFlareTimer = 5
    end)
end
