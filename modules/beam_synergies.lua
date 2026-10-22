-- modules/beam_synergies.lua -- RSI: solo sinergias laser/cuchillo del anillo. Sin Willpower, sin items activos.
return function(Core)
    local GL = Core.GL

    -- Base flags applied to every GL split/construct tear.
    local BASE_SPLIT_FLAGS = (TearFlags and (TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING)) or 0

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

        local isTech1 = player.HasCollectible and player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY or 68)
        local isTechX = (laser.IsCircle and laser:IsCircle()) or (player.HasCollectible and player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_X or 395))
        if isTech1 then ld.isGLTechLaser = true end
        if isTechX then ld.isGLTechX = true end

        -- Tint all player lasers into blazing Hard-Light Emerald Construct Beams!
        laser.DepthOffset     = 35
        pcall(function() laser:GetSprite().Color = isTech1 and Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25) or Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20) end)
        local dmgMult = isTech1 and 1.30 or 1.25
        laser.CollisionDamage = laser.CollisionDamage * dmgMult
        laser.TearFlags = laser.TearFlags | BASE_SPLIT_FLAGS
        if Core.IsTaintedHal(player) and math.random() < (Core.TAINTED_FEAR_CHANCE or 0.25) then
            laser.TearFlags = laser.TearFlags | TearFlags.TEAR_FEAR
        end

        -- Hal Jordan Willpower management for laser weapons
        if Core.IsHalJordan(player) and not data.ringDepleted then
            local frame = Game():GetFrameCount()
            if data.lastLaserDrainFrame ~= frame then
                data.lastLaserDrainFrame = frame
                local prevWillBucket = math.floor((data.willpower or Core.WILLPOWER_MAX) + 0.5)
                data.willpower = math.max(0, (data.willpower or Core.WILLPOWER_MAX) - 1.2)
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
        local ld = laser:GetData()
        pcall(function() laser:GetSprite().Color = ld.isGLTechLaser and Color(0.1, 1.0, 0.38, 1, 0.20, 0.95, 0.25) or Color(0.1, 1.0, 0.38, 1, 0.06, 0.78, 0.20) end)

        local frame = Game():GetFrameCount()
        if ld.isGLTechLaser and (frame % 12 == 0) and Isaac and Isaac.Spawn then
            local fxVar = (EffectVariant and EffectVariant.HALO) or 10
            local sparkPos = laser.Position
            if laser.GetEndPoint then
                local endPt = laser:GetEndPoint()
                local t = (frame % 3) * 0.4
                sparkPos = laser.Position * (1 - t) + endPt * t
            end
            local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, sparkPos, Vector.Zero, player)
            if fx and Core.SetEntityScaleAndColor then
                Core.SetEntityScaleAndColor(fx, 0.35, Color(0.1, 1.0, 0.38, 0.8, 0.2, 0.9, 0.3))
            end
        elseif ld.isGLTechX and (frame % 8 == 0) and Isaac and Isaac.Spawn then
            local fxVar = (EffectVariant and EffectVariant.HALO) or 10
            local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, laser.Position, Vector.Zero, player)
            if fx and Core.SetEntityScaleAndColor then
                local rad = (laser.Radius or 24)
                Core.SetEntityScaleAndColor(fx, rad / 32.0, Color(0.1, 1.0, 0.38, 0.6, 0.15, 0.85, 0.25))
            end
        end
    end)

    -- 2. MOM'S KNIFE SYNERGY: Hard-Light Emerald Energy Blade
    GL:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, function(_, knife)
        local spawner = knife.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        pcall(function() knife:GetSprite().Color = Color(0.1, 1.0, 0.38, 1, 0.10, 0.85, 0.25) end)
        if knife:IsFlying() then
            local data = Core.GetPlayerData(player)
            data.ringFlareTimer = 5
        end
    end)

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

    -- 8. THE PARASITE & CRICKET'S BODY SYNERGIES: Hard-Light Refraction Shards
    local function SpawnSplitTear(player, pos, vel, damage, scale, flag)
        local tear = nil
        -- FireTear triggers MC_POST_FIRE_TEAR, which removes the split under
        -- continuous beam suppression. Use direct spawn so the shard survives.
        if Isaac and Isaac.Spawn then
            local tVar = (TearVariant and TearVariant.DEFAULT) or 0
            local ent = Isaac.Spawn(EntityType.ENTITY_TEAR, tVar, 0, pos, vel, player)
            if ent and ent.ToTear then tear = ent:ToTear() end
        end
        if tear then
            tear.CollisionDamage = damage
            tear.TearFlags = tear.TearFlags | BASE_SPLIT_FLAGS
            if Core.IsTaintedHal(player) then
                tear.TearFlags = tear.TearFlags | TearFlags.TEAR_FEAR
            end
            local sd = tear:GetData()
            sd.isGLRingBeam = true
            if flag then sd[flag] = true end
            if Core.ApplyRingBeamSprite then
                Core.ApplyRingBeamSprite(tear, scale or 0.60)
            end
        end
        return tear
    end

    GL:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, function(_, tear, collider, low)
        local spawner = tear.SpawnerEntity
        local player = spawner and spawner:ToPlayer()
        if not player or not Core.IsRingActive(player) then return end

        -- Lost Contact: emerald flash when the player's tear blocks an enemy projectile.
        if tear and type(tear.ToTear) == "function" and tear:ToTear()
           and collider and type(collider.ToTear) == "function" and collider:ToTear() then
            local colSpawner = collider.SpawnerEntity
            local isEnemyShot = true
            if colSpawner then
                pcall(function()
                    if colSpawner:ToPlayer() then isEnemyShot = false end
                    local cf = colSpawner:ToFamiliar()
                    if cf and (cf.Player or (cf.SpawnerEntity and cf.SpawnerEntity:ToPlayer())) then
                        isEnemyShot = false
                    end
                end)
            end
            if isEnemyShot then
                local lostContact = (CollectibleType and CollectibleType.COLLECTIBLE_LOST_CONTACT) or 213
                if player.HasCollectible and player:HasCollectible(lostContact) then
                    local td = tear:GetData()
                    local frame = Game():GetFrameCount()
                    if not (td.lostContactFlashFrame and (frame - td.lostContactFlashFrame) < 3) then
                        td.lostContactFlashFrame = frame
                        pcall(function()
                            if Isaac and Isaac.Spawn and EntityType and EffectVariant and EffectVariant.WATER_SPLASH then
                                local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, collider.Position, Vector.Zero, player)
                                if fx and Core.SetEntityScaleAndColor then
                                    Core.SetEntityScaleAndColor(fx, 0.55, Color(0.1, 1.0, 0.35, 0.85, 0.15, 0.85, 0.25))
                                end
                            end
                        end)
                    end
                end
            end
        end

        if not (collider and collider.IsActiveEnemy and collider:IsActiveEnemy(false) and collider.IsVulnerableEnemy and collider:IsVulnerableEnemy()) then return end

        local td = tear:GetData()
        if not td or td.isParasiteShard or td.isCricketShard then return end

        local hasParasite = player.HasCollectible and player:HasCollectible(CollectibleType.COLLECTIBLE_PARASITE or 104)
        local hasCricket = player.HasCollectible and player:HasCollectible(CollectibleType.COLLECTIBLE_CRICKETS_BODY or 224)
        if not (hasParasite or hasCricket) then return end

        td.glRefractHit = td.glRefractHit or {}
        local colIdx = collider.Index or collider.InitSeed or 0
        if td.glRefractHit[colIdx] then return end
        td.glRefractHit[colIdx] = true

        local vel = tear.Velocity
        local spd = 8.0
        local dirX, dirY = 1, 0
        if vel and (vel.X ~= 0 or vel.Y ~= 0) then
            local len = math.sqrt(vel.X * vel.X + vel.Y * vel.Y)
            if len > 0.01 then
                dirX, dirY = vel.X / len, vel.Y / len
                spd = math.max(7.0, math.min(13.0, len))
            end
        end

        local baseDmg = tear.CollisionDamage or player.Damage or 3.5
        local sfx = (SoundEffect and SoundEffect.SOUND_TEARIMPACTS) or 0
        if sfx > 0 and SFXManager and SFXManager() and SFXManager().Play then
            SFXManager():Play(sfx, 0.6, 0, false, 1.25)
        end

        if hasParasite then
            local leftVel = Vector(-dirY * spd, dirX * spd)
            local rightVel = Vector(dirY * spd, -dirX * spd)
            SpawnSplitTear(player, tear.Position, leftVel, baseDmg * 0.50, 0.65, "isParasiteShard")
            SpawnSplitTear(player, tear.Position, rightVel, baseDmg * 0.50, 0.65, "isParasiteShard")
        end

        if hasCricket then
            local diagSpd = spd * 0.85
            local diags = {
                Vector( (dirX - dirY) * 0.707 * diagSpd, (dirX + dirY) * 0.707 * diagSpd ),
                Vector( (dirX + dirY) * 0.707 * diagSpd, (-dirX + dirY) * 0.707 * diagSpd ),
                Vector( (-dirX - dirY) * 0.707 * diagSpd, (dirX - dirY) * 0.707 * diagSpd ),
                Vector( (-dirX + dirY) * 0.707 * diagSpd, (-dirX - dirY) * 0.707 * diagSpd ),
            }
            for _, dVel in ipairs(diags) do
                SpawnSplitTear(player, tear.Position, dVel, baseDmg * 0.50, 0.55, "isCricketShard")
            end
        end
    end)

    -- 9. CONTINUOUS BEAM REFRACTION SYNERGY: The Parasite & Cricket's Body
    function Core.OnContinuousBeamHitEnemy(player, ent, hitPos, tickDmg, segDir)
        if not player or not Core.IsRingActive(player) then return end
        local hasParasite = player.HasCollectible and player:HasCollectible(CollectibleType.COLLECTIBLE_PARASITE or 104)
        local hasCricket = player.HasCollectible and player:HasCollectible(CollectibleType.COLLECTIBLE_CRICKETS_BODY or 224)
        if not (hasParasite or hasCricket) then return end

        local frame = Game():GetFrameCount()
        local ed = ent.GetData and ent:GetData()
        if ed then
            if ed.lastGLRefractFrame and (frame - ed.lastGLRefractFrame) < 12 then return end
            ed.lastGLRefractFrame = frame
        end

        local dirX, dirY = 1, 0
        if segDir and (segDir.X ~= 0 or segDir.Y ~= 0) then
            local len = math.sqrt(segDir.X * segDir.X + segDir.Y * segDir.Y)
            if len > 0.01 then dirX, dirY = segDir.X / len, segDir.Y / len end
        end

        local splitDmg = (player.Damage or 3.5) * 0.50
        local spawnPos = hitPos or ent.Position

        if hasParasite then
            local leftVel = Vector(-dirY * 8.0, dirX * 8.0)
            local rightVel = Vector(dirY * 8.0, -dirX * 8.0)
            SpawnSplitTear(player, spawnPos, leftVel, splitDmg, 0.60, "isParasiteShard")
            SpawnSplitTear(player, spawnPos, rightVel, splitDmg, 0.60, "isParasiteShard")
        end

        if hasCricket then
            local diags = {
                Vector( (dirX - dirY) * 0.707 * 7.0, (dirX + dirY) * 0.707 * 7.0 ),
                Vector( (dirX + dirY) * 0.707 * 7.0, (-dirX + dirY) * 0.707 * 7.0 ),
                Vector( (-dirX - dirY) * 0.707 * 7.0, (dirX - dirY) * 0.707 * 7.0 ),
                Vector( (-dirX + dirY) * 0.707 * 7.0, (-dirX - dirY) * 0.707 * 7.0 ),
            }
            for _, dVel in ipairs(diags) do
                SpawnSplitTear(player, spawnPos, dVel, splitDmg * 0.8, 0.50, "isCricketShard")
            end
        end
    end
end
