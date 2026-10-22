-- modules/fx_construct_tears.lua -- RSI: render de construct tears (beam/orb/node/fist).
-- Responsabilidad unica: dibujar los tears de anillo y punos con sprites custom.

return function(Core)
    function Core.RenderConstructTears(currentGameFrame)
        pcall(function()
            local tears = Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false)
            if tears and #tears > 0 then
                if not Core.glBeamTearSprite and Sprite then
                    local s = Sprite()
                    s:Load("gfx/effects/gl_ring_beam.anm2", true)
                    s:Play("Idle", true)
                    Core.glBeamTearSprite = s
                end
                if not Core.glFistTearSprite and Sprite then
                    local s = Sprite()
                    s:Load("gfx/effects/gl_giant_fist.anm2", true)
                    s:Play("Idle", true)
                    Core.glFistTearSprite = s
                end
                local animFrame = math.floor(currentGameFrame / 2) % 4
                for _, ent in ipairs(tears) do
                    local tear = ent:ToTear()
                    if tear and tear:Exists() and not tear:IsDead() then
                        local td = tear:GetData()
                        if td and td.isGLRingBeam then
                            local beamPlayer = Core.ResolveBeamPlayer and Core.ResolveBeamPlayer(tear.SpawnerEntity)
                            local beamTint = Color(1, 1, 1, 1, 0, 0, 0)
                            if beamPlayer and Core.GetRingBeamVisual then
                                local ok, t = pcall(Core.GetRingBeamVisual, beamPlayer)
                                if ok and t then beamTint = t end
                            end
                            local isStuck = false
                            pcall(function()
                                if tear.StickTarget ~= nil then isStuck = true end
                                if tear.StickTimer and tear.StickTimer > 0 then isStuck = true end
                                if tear.FrameCount > 6 and tear.Velocity and tear.Velocity:Length() < 0.8 then isStuck = true end
                            end)

                            tear.Visible = false
                            pcall(function() if tear:GetSprite() then tear:GetSprite().Color = Color(0, 0, 0, 0) end end)

                            if Core.IsWallAtPos and Core.IsWallAtPos(tear.Position) then
                                -- Ray reached room wall: do not render sprite in or beyond the wall
                            elseif isStuck then
                                local screenPos = Isaac.WorldToScreen(tear.Position)
                                if Core.glBeamTearSprite then
                                    Core.glBeamTearSprite:SetFrame("EnergyNode", animFrame)
                                    Core.glBeamTearSprite.Scale = Vector(1.1, 1.1)
                                    Core.glBeamTearSprite.Rotation = (currentGameFrame * 6) % 360
                                    Core.glBeamTearSprite.Color = beamTint
                                    Core.glBeamTearSprite:Render(screenPos, Vector.Zero, Vector.Zero)
                                end
                                local flareSpr = Core.GetGLAuraSprites and select(2, Core.GetGLAuraSprites())
                                if flareSpr then
                                    local pulse = 0.70 + 0.20 * math.sin(currentGameFrame * 0.3)
                                    flareSpr:SetFrame("RingFlare", animFrame)
                                    flareSpr.Scale = Vector(pulse, pulse)
                                    flareSpr.Color = Color(0.2, 1.0, 0.4, 0.9, 0.1, 0.7, 0.2)
                                    flareSpr:Render(screenPos, Vector.Zero, Vector.Zero)
                                end
                            else
                                if Core.glBeamTearSprite then
                                    local screenPos = Isaac.WorldToScreen(tear.Position)
                                    local scale = td.glBeamScale or 1.0
                                    local flags = tear.TearFlags
                                    local isOrb = (flags and TearFlags and (Core.HasTearFlag(flags, TearFlags.TEAR_HOMING) or Core.HasTearFlag(flags, TearFlags.TEAR_MAGNET) or Core.HasTearFlag(flags, TearFlags.TEAR_ORBIT) or Core.HasTearFlag(flags, TearFlags.TEAR_SPIRAL) or Core.HasTearFlag(flags, TearFlags.TEAR_BOOMERANG) or Core.HasTearFlag(flags, TearFlags.TEAR_WIGGLE)))
                                    local sp = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
                                    if sp and not isOrb then
                                        isOrb = (CollectibleType.COLLECTIBLE_JACOBS_LADDER and sp:HasCollectible(CollectibleType.COLLECTIBLE_JACOBS_LADDER)) or (CollectibleType.COLLECTIBLE_LODESTONE and sp:HasCollectible(CollectibleType.COLLECTIBLE_LODESTONE)) or (CollectibleType.COLLECTIBLE_TINY_PLANET and sp:HasCollectible(CollectibleType.COLLECTIBLE_TINY_PLANET))
                                    end
                                    if (not isOrb) and tear.FrameCount > 6 and tear.Velocity and tear.Velocity:Length() < 2.2 then isOrb = true end

                                    if isOrb then
                                        Core.glBeamTearSprite:SetFrame("EnergyOrb", animFrame)
                                        Core.glBeamTearSprite.Rotation = (currentGameFrame * 8) % 360
                                        Core.glBeamTearSprite.Scale = Vector(scale * 1.15, scale * 1.15)
                                        Core.glBeamTearSprite.Color = beamTint
                                        Core.glBeamTearSprite:Render(screenPos, Vector.Zero, Vector.Zero)
                                    else
                                        Core.glBeamTearSprite:SetFrame("Idle", animFrame)
                                        local currentVel = tear.Velocity
                                        local sp = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
                                        local hasTB = (sp and Core.HasTractorBeam and Core.HasTractorBeam(sp)) or (TearFlags and TearFlags.TEAR_TRACTOR_BEAM and flags and Core.HasTearFlag(flags, TearFlags.TEAR_TRACTOR_BEAM))
                                        local targetRot = (currentVel and currentVel:Length() > 0.1) and currentVel:GetAngleDegrees() or (td.glBeamVel and td.glBeamVel:GetAngleDegrees() or 0)
                                        if hasTB and sp then
                                            local tbDir = Core.GetTractorBeamDirection(sp, currentVel)
                                            targetRot = (tbDir.GetAngleDegrees and tbDir:GetAngleDegrees()) or (math.atan2(tbDir.Y, tbDir.X) * 180 / math.pi)
                                            td.lastBeamRot = targetRot
                                        elseif td.lastBeamRot then
                                            local diff = (targetRot - td.lastBeamRot + 180) % 360 - 180
                                            targetRot = td.lastBeamRot + diff * 0.4
                                            td.lastBeamRot = targetRot
                                        else
                                            td.lastBeamRot = targetRot
                                        end
                                        Core.glBeamTearSprite.Rotation = targetRot
                                        Core.glBeamTearSprite.Scale = Vector(scale, scale)
                                        Core.glBeamTearSprite.Color = beamTint
                                        Core.glBeamTearSprite:Render(screenPos, Vector.Zero, Vector.Zero)
                                    end
                                end
                            end
                        elseif td and (td.isGLFist or td.isGiantFist) then
                            tear.Visible = false
                            pcall(function() if tear:GetSprite() then tear:GetSprite().Color = Color(0, 0, 0, 0) end end)
                            if Core.glFistTearSprite then
                                local screenPos = Isaac.WorldToScreen(tear.Position)
                                local scale = td.glFistScale or 2.2
                                Core.glFistTearSprite:SetFrame("Idle", animFrame)
                                local rot = (tear.Velocity and tear.Velocity:Length() > 0.1) and tear.Velocity:GetAngleDegrees() or (td.glFistVel and td.glFistVel:GetAngleDegrees() or 0)
                                local sp = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
                                if sp and Core.HasTractorBeam and Core.HasTractorBeam(sp) then
                                    local tbDir = Core.GetTractorBeamDirection(sp, tear.Velocity)
                                    rot = (tbDir.GetAngleDegrees and tbDir:GetAngleDegrees()) or (math.atan2(tbDir.Y, tbDir.X) * 180 / math.pi)
                                end
                                Core.glFistTearSprite.Rotation = rot
                                Core.glFistTearSprite.Scale = Vector(scale, scale)
                                Core.glFistTearSprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
                                Core.glFistTearSprite:Render(screenPos, Vector.Zero, Vector.Zero)
                            end
                        end
                    end
                end
            end
        end)
    end
end
