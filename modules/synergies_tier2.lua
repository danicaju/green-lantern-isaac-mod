-- modules/synergies_tier2.lua -- RSI: Sinergias Tier 2 (Attack Modifiers & Weapon Enhancements)
-- Responsabilidad unica: Compound Fracture, Fire Mind, Explosivo, Flat Stone, Saturnus, Tech 2, Tech.5, Eye of the Occult, Continuum.

return function(Core)
    local GL = Core.GL

    local function SpawnConstructShard(player, pos, vel, damage, scale, flag)
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
                Core.ApplyRingBeamSprite(tear, scale or 0.55)
            end
        end
        return tear
    end

    -- 1. PRE-TEAR COLLISION: Compound Fracture (509), Fire Mind (257), Explosivo (400)
    GL:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, function(_, tear, collider, low)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end
        if not (collider and collider.IsActiveEnemy and collider:IsActiveEnemy(false) and collider.IsVulnerableEnemy and collider:IsVulnerableEnemy()) then return end

        local td = tear:GetData()
        local luck = player.Luck or 0
        local vel = tear.Velocity
        local dir = (vel and (vel.X ~= 0 or vel.Y ~= 0)) and vel:Normalized() or Vector(1, 0)
        local baseDmg = tear.CollisionDamage or player.Damage or 3.5

        -- Compound Fracture (509): Bone construct splinter shards
        local hasCompound = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_COMPOUND_FRACTURE or 509))
        if hasCompound and not (td and td.isCompoundShard) then
            pcall(function()
                local sfx = (SoundEffect and SoundEffect.SOUND_TEARIMPACTS) or 0
                if sfx > 0 and SFXManager and SFXManager().Play then
                    SFXManager():Play(sfx, 0.7, 0, false, 1.2)
                end
                local data = Core.GetPlayerData(player)
                data.itemTearBurstFrame = Game():GetFrameCount()
                for i = -1, 1 do
                    local angle = math.atan2(dir.Y, dir.X) + i * 0.40
                    local sVel = Vector(math.cos(angle) * 7.5, math.sin(angle) * 7.5)
                    SpawnConstructShard(player, tear.Position, sVel, baseDmg * 0.50, 0.50, "isCompoundShard")
                end
            end)
        end

        -- Fire Mind (257): Emerald plasma burns & combustions
        local hasFireMind = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_FIRE_MIND or 257))
        if hasFireMind then
            pcall(function()
                if collider.AddBurn then
                    collider:AddBurn(EntityRef(player), 75, baseDmg * 0.40)
                end
                -- 15% + luck * 3% chance for emerald plasma burst
                if math.random() < math.min(0.50, 0.15 + luck * 0.03) then
                    local fxVar = (EffectVariant and EffectVariant.RED_CANDLE_FLAME) or (EffectVariant and EffectVariant.FIRE_WAVE) or 10
                    local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, tear.Position, Vector.Zero, player)
                    if fx and Core.SetEntityScaleAndColor then
                        Core.SetEntityScaleAndColor(fx, 1.2, Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25))
                    end
                    local sfx = (SoundEffect and SoundEffect.SOUND_FIREDEATH_HISS) or (SoundEffect and SoundEffect.SOUND_EXPLOSION_WEAK) or 0
                    if sfx > 0 and SFXManager and SFXManager().Play then
                        SFXManager():Play(sfx, 0.8, 0, false, 1.1)
                    end
                    collider:TakeDamage(baseDmg * 2.0, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
                    local data = Core.GetPlayerData(player)
                    data.ringFlareTimer = 8
                end
            end)
        end

        -- Explosivo (400): Emerald hard-light sticky plasma bubble
        local hasExplosivo = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_EXPLOSIVO or 400))
        if hasExplosivo and math.random() < math.min(0.40, 0.12 + luck * 0.03) then
            pcall(function()
                local sfx = (SoundEffect and SoundEffect.SOUND_SPLATTER) or 0
                if sfx > 0 and SFXManager and SFXManager().Play then
                    SFXManager():Play(sfx, 0.75, 0, false, 1.3)
                end
                local fxVar = (EffectVariant and EffectVariant.HALO) or 10
                local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, collider.Position, Vector.Zero, player)
                if fx and Core.SetEntityScaleAndColor then
                    Core.SetEntityScaleAndColor(fx, 0.75, Color(0.1, 1.0, 0.38, 0.8, 0.25, 0.95, 0.30))
                end
                collider:TakeDamage(baseDmg * 2.2, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
                local data = Core.GetPlayerData(player)
                data.ringFlareTimer = 6
            end)
        end
    end)

    -- 2. CONTINUOUS BEAM ENEMIES HIT: Compound Fracture & Fire Mind procs
    local prevContHook = Core.OnContinuousBeamHitEnemy
    Core.OnContinuousBeamHitEnemy = function(player, ent, hitPos, tickDmg, segDir)
        if prevContHook then prevContHook(player, ent, hitPos, tickDmg, segDir) end
        if not player or not Core.IsRingActive(player) then return end

        local frame = Game():GetFrameCount()
        local ed = ent.GetData and ent:GetData()
        if ed then
            if ed.lastGLTier2ProcFrame and (frame - ed.lastGLTier2ProcFrame) < 20 then return end
            ed.lastGLTier2ProcFrame = frame
        end

        local luck = player.Luck or 0
        local dir = segDir or Vector(1, 0)
        local spawnPos = hitPos or ent.Position

        -- Compound Fracture continuous beam splinter
        if player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_COMPOUND_FRACTURE or 509)) then
            if math.random() < 0.25 then
                for i = -1, 1, 2 do
                    local angle = math.atan2(dir.Y, dir.X) + i * 0.50
                    local sVel = Vector(math.cos(angle) * 7.0, math.sin(angle) * 7.0)
                    pcall(function()
                        SpawnConstructShard(player, spawnPos, sVel, tickDmg * 1.5, 0.45, "isCompoundShard")
                    end)
                end
            end
        end

        -- Fire Mind continuous beam combustion
        if player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_FIRE_MIND or 257)) then
            pcall(function()
                if ent.AddBurn then ent:AddBurn(EntityRef(player), 60, tickDmg * 1.2) end
            end)
        end
    end

    -- 3. POST-TEAR UPDATE: Flat Stone (527), Eye of the Occult (601), Continuum (369)
    GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        local hasFlatStone = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_FLAT_STONE or 527))
        local hasOccult = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT or 601))
        local hasContinuum = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_CONTINUUM or 369))
        if not (hasFlatStone or hasOccult or hasContinuum) then return end

        local td = tear:GetData()
        pcall(function()
            local spr = tear:GetSprite()
            if not spr then return end

            -- Flat Stone (527): Emerald bouncing construct shockwaves
            if hasFlatStone then
                local h = tear.Height or 0
                if h >= -2 and not td.lastBounceFrame then
                    td.lastBounceFrame = Game():GetFrameCount()
                    local fxVar = (EffectVariant and EffectVariant.POOF02) or (EffectVariant and EffectVariant.HALO) or 10
                    local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, tear.Position, Vector.Zero, player)
                    if fx and Core.SetEntityScaleAndColor then
                        Core.SetEntityScaleAndColor(fx, 0.50, Color(0.1, 1.0, 0.38, 0.65, 0.15, 0.85, 0.25))
                    end
                elseif h < -5 then
                    td.lastBounceFrame = nil
                end
            end

            -- Eye of the Occult (601): Emerald energy trail
            if hasOccult then
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.25, 0.95, 0.30)
                if not td.isGLOccultTear then
                    td.isGLOccultTear = true
                    tear.CollisionDamage = (tear.CollisionDamage or player.Damage or 3.5) * 1.20
                end
            end

            -- Continuum (369): Dimensional construct warp
            if hasContinuum then
                spr.Color = Color(0.1, 1.0, 0.38, 1, 0.15, 0.90, 0.25)
            end
        end)
    end)

    -- 4. SATURNUS (606): Emerald Hard-Light Orbital Planetary Ring on New Room
    GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
        local nPlayers = (Game().GetNumPlayers and Game():GetNumPlayers()) or 1
        for i = 0, nPlayers - 1 do
            local player = Isaac.GetPlayer(i)
            if player and Core.IsRingActive(player) then
                local hasSaturnus = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_SATURNUS or 606))
                if hasSaturnus then
                    pcall(function()
                        local fxVar = (EffectVariant and EffectVariant.HALO) or 10
                        local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, player.Position, Vector.Zero, player)
                        if fx and Core.SetEntityScaleAndColor then
                            Core.SetEntityScaleAndColor(fx, 1.40, Color(0.1, 1.0, 0.38, 0.60, 0.20, 0.90, 0.25))
                        end
                    end)
                    local data = Core.GetPlayerData(player)
                    data.ringFlareTimer = 10
                end
            end
        end
    end)

    -- 5. LASER SYNERGIES: Technology 2 (149) & Tech.5 (244)
    GL:AddCallback(ModCallbacks.MC_POST_LASER_INIT, function(_, laser)
        local spawner = laser.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        local hasTech2 = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_TECHNOLOGY_2 or 149))
        local hasTech5 = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_TECH_5 or 244))
        if not (hasTech2 or hasTech5) then return end

        local ld = laser:GetData()
        if ld.glTier2LaserInit then return end
        ld.glTier2LaserInit = true

        pcall(function()
            laser.DepthOffset = 35
            laser:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25)
            laser.CollisionDamage = laser.CollisionDamage * 1.25
        end)
    end)
end
