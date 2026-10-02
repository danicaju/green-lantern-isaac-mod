-- modules/beam_discrete.lua -- RSI: disparo discreto del anillo + mantenimiento del tear beam. Sin Willpower pasivo, sin continuo, sin synergies laser.
-- Responsabilidad unica: SECTION 6 BEAM (POST_FIRE_TEAR, POST_TEAR_UPDATE, POST_TEAR_RENDER, PRE_TEAR_COLLISION + EnforceRingBeamTearSprite).
return function(Core)
  local GL = Core.GL

  -- ---------------------------------------------------------------------------
  -- SECTION 6: GREEN LANTERN RING BEAM HANDLING (Hand origin + Piercing + Spectral)
  -- ---------------------------------------------------------------------------

  GL:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
      local spawner = tear.SpawnerEntity
      if not spawner then return end
      local player = spawner:ToPlayer()
      if not player then return end

      -- When Hal's ring is depleted (0% Willpower lockout), he loses the ability to use the Power Ring and fires normal tears!
      if not Core.IsRingActive(player) then return end

      local data = Core.GetPlayerData(player)

      -- Suppress unbuffered C++ tears when CanUseContinuousBeam(player) is active (so holding shoot never fires a Frame-1 discrete bolt!)
      if Core.IsHalJordan(player) or Core.IsTaintedHal(player) then
          local td = tear:GetData()
          if not (td and td.isGiantFist) then
              if data.isFiringContinuousBeam or (Core.CanUseContinuousBeam(player) and not data.allowingTapTear) then
                  if not data.isFiringContinuousBeam and tear.Velocity and tear.Velocity:Length() > 0.1 then
                      local rawDir = tear.Velocity:Normalized()
                      data.lastShootDir = Vector(rawDir.X, rawDir.Y)
                      if (data.shootHoldFrames or 0) == 0 then
                          data.shootHoldFrames         = 1
                          data.firedSmallBeamThisPress = false
                      end
                  end
                  tear:Remove()
                  return
              end
          end
      end

      local frame = Game():GetFrameCount()
      if Core.IsHalJordan(player) or Core.IsTaintedHal(player) then
          data.lastSmallBeamFrame = frame
          if not data.firingBufferedClick then
              data.firedSmallBeamThisPress = true
              data.bufferedClickDir        = nil
          end
      end

      -- Multi-shot fan offset (20/20, Inner Eye, Mutant Spider, Monstro's Lung, Conjoined)
      if data.multiShotFrame == frame then
          data.multiShotIndex = (data.multiShotIndex or 0) + 1
      else
          data.multiShotFrame = frame
          data.multiShotIndex = 0
      end

      -- 1. Snap projectile spawn position to the outstretched Power Ring hand!
      local baseDir     = (data.allowingTapTear and data.tapBurstBaseDir) or tear.Velocity
      local handOffset  = Core.GetRingHandOffset(player, baseDir)
      local spawnOffset = Core.GetRingBeamTearSpawnOffset(player, baseDir)
      local perpOffset  = Vector.Zero
      if data.allowingTapTear and (data.tapBurstCount or 1) > 1 and baseDir:Length() > 0.1 then
          local dir        = baseDir:Normalized()
          local perp       = Vector(-dir.Y, dir.X)
          local laneOffset = (data.tapBurstIndex or 1) - ((data.tapBurstCount or 1) + 1) * 0.5
          perpOffset       = perp * math.max(-14.0, math.min(14.0, laneOffset * 5.5))
      elseif data.multiShotIndex > 0 and tear.Velocity:Length() > 0.1 then
          local dir = tear.Velocity:Normalized()
          local perp = Vector(-dir.Y, dir.X)
          local side = (data.multiShotIndex % 2 == 1) and 1 or -1
          local tier = math.ceil(data.multiShotIndex / 2)
          perpOffset = perp * (side * math.min(tier * 5.5, 14.0))
      end

      tear.Position     = player.Position + spawnOffset + perpOffset
      tear.DepthOffset  = Core.IsAimingUp(player, baseDir) and -20 or 25
      if baseDir and baseDir:Length() > 0.01 then
          local normDir = baseDir:Normalized()
          data.lastShootDir = Vector(normDir.X, normDir.Y)
      end
      data.lastRingHandOffset = handOffset
      data.ringFlareTimer     = 6

      -- Grant Piercing (pass through enemies) + Spectral (pass through rocks/objects)
      tear.TearFlags = tear.TearFlags | TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL
      if Core.IsTaintedHal(player) then
          tear.TearFlags = tear.TearFlags | TearFlags.TEAR_FEAR
      end

      -- Synergy scale adjustments (Chocolate Milk, Monstro's Lung, Ipecac, Haemolacria, Soy/Almond Milk)
      local sizeFactor = math.max(0.65, math.min(1.85, tear.Scale or 1.0))

      -- 2. HAL JORDAN WILLPOWER & BEAM SCALING
      if Core.IsHalJordan(player) then
          local baseScale = data.overcharge and 1.20 or (data.surgeBuff and 1.10 or 1.0)
          Core.ApplyRingBeamSprite(tear, baseScale * math.sqrt(sizeFactor))

          -- Scale willpower drain for multi-shot / lung / soy milk so rapid/volley synergies feel great
          local drain = Core.WILLPOWER_PER_TEAR
          if data.multiShotIndex > 0 then
              drain = drain * 0.25 -- Multi-shot / Monstro's Lung extra beams cost 75% less willpower
          end
          if CollectibleType.COLLECTIBLE_SOY_MILK and player:HasCollectible(CollectibleType.COLLECTIBLE_SOY_MILK) then
              drain = drain * 0.20
          elseif CollectibleType.COLLECTIBLE_ALMOND_MILK and player:HasCollectible(CollectibleType.COLLECTIBLE_ALMOND_MILK) then
              drain = drain * 0.25
          end

          local prevWillBucket = math.floor((data.willpower or Core.WILLPOWER_MAX) + 0.5)
          data.willpower = math.max(0, (data.willpower or Core.WILLPOWER_MAX) - drain)
          local newWillBucket = math.floor(data.willpower + 0.5)

          local isFinalBurstTear = (not data.allowingTapTear) or ((data.tapBurstIndex or 1) >= (data.tapBurstCount or 1))
          if data.willpower <= 0 and isFinalBurstTear then
              Core.TriggerHalRingDepleted(player)
          elseif newWillBucket ~= prevWillBucket and isFinalBurstTear then
              player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
              player:EvaluateItems()
          end
      elseif Core.IsTaintedHal(player) then
          -- 3. TAINTED HAL (PARALLAX): Larger, heavy emerald construct energy blast from the ring
          tear.Scale = tear.Scale * 1.35
          Core.ApplyRingBeamSprite(tear, 1.28 * math.sqrt(sizeFactor))
      else
          -- Any other character holding Green Lantern Ring
          Core.ApplyRingBeamSprite(tear, 1.05 * math.sqrt(sizeFactor))
      end
  end)

  local function EnforceRingBeamTearSprite(tear, td)
      local ts = tear:GetSprite()
      if ts then
          if ts:GetAnimation() ~= "Idle" then
              ts:Load("gfx/effects/gl_ring_beam.anm2", true)
              ts:Play("Idle", true)
          end
          if td.glBeamScale then
              ts.Scale = Vector(td.glBeamScale, td.glBeamScale)
          end
          ts.Color = Color(1, 1, 1, 1, 0, 0, 0)
          if tear.Velocity and tear.Velocity:Length() > 0.1 then
              ts.Rotation = tear.Velocity:GetAngleDegrees()
          elseif td.glBeamVel and td.glBeamVel:Length() > 0.1 then
              ts.Rotation = td.glBeamVel:GetAngleDegrees()
          end
      end
  end

  -- Keep all Green Lantern Ring energy beams oriented along their straight flight vector and prevent C++ sprite/variant resets
  GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
      local td = tear:GetData()
      if not (td and td.isGLRingBeam) then return end

      tear.DepthOffset = Core.IsAimingUp(nil, tear.Velocity) and -20 or 25

      -- Keep discrete Ring Beam bolts flying straight (prevents post-depletion curve/circle artifacts unless homing/orbit is active)
      local flags = tear.TearFlags
      local hasCurvingSynergy = false
      if TearFlags and flags then
          if Core.HasTearFlag(flags, TearFlags.TEAR_HOMING)
              or Core.HasTearFlag(flags, TearFlags.TEAR_ORBIT)
              or Core.HasTearFlag(flags, TearFlags.TEAR_BOOMERANG)
              or Core.HasTearFlag(flags, TearFlags.TEAR_SPIRAL)
              or Core.HasTearFlag(flags, TearFlags.TEAR_WIGGLE)
          then
              hasCurvingSynergy = true
          end
      end
      if not hasCurvingSynergy then
          if td.glBeamVel and td.glBeamVel:Length() > 0.1 and tear.Velocity:Length() > 0.1 then
              local currentSpeed = tear.Velocity:Length()
              tear.Velocity = td.glBeamVel:Normalized() * currentSpeed
          end
          tear.FallingAcceleration = -0.04
          if tear.FallingSpeed and tear.FallingSpeed > 0 then
              tear.FallingSpeed = 0.0
          end
      end

      EnforceRingBeamTearSprite(tear, td)
  end)

  if ModCallbacks.MC_POST_TEAR_RENDER then
      GL:AddCallback(ModCallbacks.MC_POST_TEAR_RENDER, function(_, tear, renderOffset)
          local td = tear:GetData()
          if not (td and td.isGLRingBeam) then return end
          EnforceRingBeamTearSprite(tear, td)
      end)
  end

  -- Spawn a crisp emerald energy flash when a piercing Ring Beam slices through an enemy
  GL:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, function(_, tear, collider, low)
      local td = tear:GetData()
      if not (td and td.isGLRingBeam) then return end
      if not (collider and collider:IsActiveEnemy(false) and collider:IsVulnerableEnemy()) then return end

      local frame = Game():GetFrameCount()
      if not td.lastPierceFlashFrame or (frame - td.lastPierceFlashFrame) >= 5 then
          td.lastPierceFlashFrame = frame
          local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, collider.Position, Vector.Zero, tear)
          Core.SetEntityScaleAndColor(fx, 0.70, Color(0.1, 1.0, 0.35, 0.9, 0.15, 0.85, 0.25))
      end

      -- Willpower refund: cada beam que impacta devuelve una pizca (premia punteria)
      if not td.glRefundGiven then
          td.glRefundGiven = true
          local sp = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
          if sp and Core.IsHalJordan(sp) then
              local sd = Core.GetPlayerData(sp)
              local max = Core.WILLPOWER_MAX
              if (sd.willpower or max) < max and not sd.ringDepleted then
                  sd.willpower = math.min(max, (sd.willpower or max) + Core.WILLPOWER_HIT_REFUND)
                  sp:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                  sp:EvaluateItems()
              end
          end
      end
  end)
end
