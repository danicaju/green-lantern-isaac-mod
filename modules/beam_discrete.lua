-- modules/beam_discrete.lua -- RSI: disparo discreto del anillo + mantenimiento del tear beam. Sin Willpower pasivo, sin continuo, sin synergies laser.
-- Responsabilidad unica: SECTION 6 BEAM (POST_FIRE_TEAR, POST_TEAR_UPDATE, POST_TEAR_RENDER, PRE_TEAR_COLLISION + EnforceRingBeamTearSprite).
return function(Core)
  local GL = Core.GL

  -- Helper: make the engine's tear invisible and tint its sprite transparent.
  -- All GL ring beams are rendered via our own sprite system.
  local function HideTearSprite(tear)
      if not tear then return end
      tear.Visible = false
      pcall(function()
          local spr = tear:GetSprite()
          if spr then spr.Color = Color(0, 0, 0, 0) end
      end)
  end

  -- Enforce lifetime cap and per-player alive cap for GL ring beams.
  -- Returns true if the tear was removed.
  local function ApplyBeamLifetimeAndCull(tear, td)
      td.glBeamLifeFrames = (td.glBeamLifeFrames or 0) + 1
      if Core.GL_BEAM_MAX_LIFE_FRAMES and td.glBeamLifeFrames > Core.GL_BEAM_MAX_LIFE_FRAMES then
          tear:Remove()
          return true
      end

      local maxAlive = Core.GL_BEAM_MAX_ALIVE or 32
      local spawner = tear.SpawnerEntity
      local oldestBeam, oldestLife, aliveCount = nil, -1, 0
      if Isaac and Isaac.GetRoomEntities and EntityType and EntityType.ENTITY_TEAR then
          for _, ent in ipairs(Isaac.GetRoomEntities()) do
              if ent and ent.Type == EntityType.ENTITY_TEAR then
                  local other = ent:ToTear()
                  if other then
                      local od = other:GetData()
                      if od and od.isGLRingBeam and other.SpawnerEntity == spawner then
                          aliveCount = aliveCount + 1
                          local life = od.glBeamLifeFrames or 0
                          if life > oldestLife then
                              oldestLife = life
                              oldestBeam = other
                          end
                      end
                  end
              end
          end
      end
      if aliveCount > maxAlive and oldestBeam and oldestBeam ~= tear then
          oldestBeam:Remove()
      end
      return false
  end

  -- ---------------------------------------------------------------------------
  -- SECTION 6: GREEN LANTERN RING BEAM HANDLING (Hand origin + Piercing + Spectral)
  -- ---------------------------------------------------------------------------

  -- F1: whitelist de familiares cuyas lagrimas pueden estilizarse como haz
  -- esmeralda. Cualquier otro familiar conserva su lagrima vanilla intacta.
  -- Enum verificado (docs Repentance): FamiliarVariant.INCUBUS = 80,
  -- FamiliarVariant.SUCCUBUS = 96. Guardas nil + fallback numerico: sin crash.
  local ALLOWED_FAMILIAR_BEAMERS = {}
  do
      local FV = FamiliarVariant
      local incubus = (FV and (FV.INCUBUS or FV.FAMILIAR_INCUBUS)) or 80
      local succubus = (FV and (FV.SUCCUBUS or FV.FAMILIAR_SUCCUBUS)) or 96
      if incubus then ALLOWED_FAMILIAR_BEAMERS[incubus] = true end
      if succubus then ALLOWED_FAMILIAR_BEAMERS[succubus] = true end
  end

  GL:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
      local spawner = tear.SpawnerEntity
      if not spawner then return end
      local player = spawner:ToPlayer()
      if not player then
          -- Familiar tears (Incubus / Succubus): se conservan VANILLA. Antes se
          -- convertian en el haz oculto (Visible=false + sprite custom), y eso
          -- dejaba a Incubus sin lagrimas visibles. Ahora solo se tinta el
          -- sprite de la lagrima; fisica, colision y visibilidad intactas.
          local fam = nil
          pcall(function() fam = spawner:ToFamiliar() end)
          if not fam then return end
          if not ALLOWED_FAMILIAR_BEAMERS[fam.Variant] then return end
          local owner = Core.ResolveBeamPlayer(spawner)
          if owner and Core.IsRingActive(owner) and Core.ApplyFamiliarTearTint then
              Core.ApplyFamiliarTearTint(tear, owner)
          end
          return
      end

      -- When Hal's ring is depleted (0% Willpower lockout), he loses the ability to use the Power Ring and fires normal tears!
      if not Core.IsRingActive(player) then return end

      local data = Core.GetPlayerData(player)
      local td = tear:GetData()

      if data.spawningGiantFist or (td and (td.isGiantFist or td.isGLFist)) then
          tear:GetData().isGiantFist = true
          tear:GetData().isGLFist = true
          HideTearSprite(tear)
          return
      end

      local frame = Game():GetFrameCount()
      if data.lastTearSpawnFrame == frame then
          data.tearsSpawnedThisFrame = (data.tearsSpawnedThisFrame or 0) + 1
      else
          data.lastTearSpawnFrame = frame
          data.tearsSpawnedThisFrame = 1
      end

      local isItemBurst = (data.itemTearBurstFrame and math.abs(frame - data.itemTearBurstFrame) <= 2)
                         or ((data.tearsSpawnedThisFrame or 1) > 1)

      -- Suppress unbuffered C++ tears when CanUseContinuousBeam(player) is active (so holding shoot never fires a Frame-1 discrete bolt!)
      if (Core.IsHalJordan(player) or Core.IsTaintedHal(player)) and not isItemBurst then
          if data.isFiringContinuousBeam or (Core.CanUseContinuousBeam(player) and not data.allowingTapTear) then
              HideTearSprite(tear)
              if not data.isFiringContinuousBeam and tear.Velocity and tear.Velocity:Length() > 0.1 then
                  local rawDir = tear.Velocity:Normalized()
                  if Core.HasTractorBeam and Core.HasTractorBeam(player) then
                      rawDir = Core.GetTractorBeamDirection(player, rawDir)
                  end
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
      local hasTB = (Core.HasTractorBeam and Core.HasTractorBeam(player)) or (TearFlags and TearFlags.TEAR_TRACTOR_BEAM and Core.HasTearFlag(tear.TearFlags, TearFlags.TEAR_TRACTOR_BEAM))
      local baseDir     = (data.allowingTapTear and data.tapBurstBaseDir) or tear.Velocity
      if hasTB then
          baseDir = Core.GetTractorBeamDirection(player, baseDir)
          if tear.Velocity and tear.Velocity:Length() > 0.1 then
              tear.Velocity = baseDir * tear.Velocity:Length()
          end
      end
      local handOffset  = Core.GetRingHandOffset(player, baseDir)
      local spawnOffset = Core.GetRingBeamTearSpawnOffset(player, baseDir)
      local perpOffset  = Vector.Zero
      if not hasTB then
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
      end

      if isItemBurst then
          local bDir = (tear.Velocity and tear.Velocity:Length() > 0.1) and tear.Velocity:Normalized() or Vector(1, 0)
          tear.Position     = player.Position + bDir * 14.0
      else
          tear.Position     = player.Position + spawnOffset + perpOffset
      end
      tear.DepthOffset  = Core.IsAimingUp(player, baseDir) and -20 or 25
      if baseDir and baseDir:Length() > 0.01 then
          local normDir = baseDir:Normalized()
          data.lastShootDir = Vector(normDir.X, normDir.Y)
      end
      data.lastRingHandOffset = handOffset
      data.ringFlareTimer     = 6

      -- Grant Piercing (pass through enemies) + Spectral (pass through rocks/objects)
      -- (Fear de Tainted ya no va en el flag: se tira probabilidad al impactar)
      tear.TearFlags = tear.TearFlags | TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL
      HideTearSprite(tear)
      -- Balance click-vs-hold: el beam discreto pega una fraccion del dano de ficha
      -- (el Puño Gigante y ráfagas de items activos quedan excluidos)
      local btd = tear:GetData()
      if not (btd and btd.isGiantFist)
        and (Core.IsHalJordan(player) or Core.IsTaintedHal(player))
        and not isItemBurst then
          tear.CollisionDamage = tear.CollisionDamage * Core.DISCRETE_BEAM_DMG_MULT
      end

      -- Synergy scale adjustments (Chocolate Milk, Monstro's Lung, Ipecac, Haemolacria, Soy/Almond Milk)
      local sizeFactor = math.max(0.65, math.min(1.85, tear.Scale or 1.0))

      -- 2. HAL JORDAN WILLPOWER & BEAM SCALING
      if Core.IsHalJordan(player) then
          local baseScale = data.overcharge and 1.20 or (data.surgeBuff and 1.10 or 1.0)
          Core.ApplyRingBeamSprite(tear, baseScale * math.sqrt(sizeFactor))

          -- Scale willpower drain for multi-shot / lung / soy milk so rapid/volley synergies feel great
          -- Gatling: cero coste mientras dura el buff
          local drain = (data.gatlingTimer or 0) > 0 and 0 or (Core.WILLPOWER_PER_TEAR or 0.6)
          if isItemBurst then
              drain = 0
          elseif data.multiShotIndex > 0 then
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
      HideTearSprite(tear)
      local ts = tear:GetSprite()
      if ts then
          if ts:GetAnimation() ~= "Idle" then
              ts:Load("gfx/effects/gl_ring_beam.anm2", true)
              ts:Play("Idle", true)
          end
          if td and td.glBeamScale then
              ts.Scale = Vector(td.glBeamScale, td.glBeamScale)
          end
          -- Reveal with the item-driven tint (or pure white fallback) instead of a hardcoded white.
          local tint = Color(1, 1, 1, 1, 0, 0, 0)
          if td and td.glBeamTint then
              tint = td.glBeamTint
          else
              local beamPlayer = Core.ResolveBeamPlayer(tear.SpawnerEntity)
              if beamPlayer and Core.GetRingBeamVisual then
                  local ok, t = pcall(Core.GetRingBeamVisual, beamPlayer)
                  if ok and t then tint = t end
              end
          end
          ts.Color = tint
          -- D3: el motor puede forzar Visible=true en tears; si por algun
          -- motivo sigue oculto tras un reset C++, lo forzamos aqui junto al
          -- color para que el beam siempre se vea.
          tear.Visible = true
          if tear.Velocity and tear.Velocity:Length() > 0.1 then
              ts.Rotation = tear.Velocity:GetAngleDegrees()
          elseif td and td.glBeamVel and td.glBeamVel:Length() > 0.1 then
              ts.Rotation = td.glBeamVel:GetAngleDegrees()
          end
      end
  end

  -- T6: contraataque al sprite del Giant Fist. Mismo riesgo que el
  -- beam: el engine puede revertir el tear a su variante vanilla o cambiar
  -- la animacion tras un reset C++. Reaplicamos Idle (cargando el anm2
  -- esmeralda si hace falta) y la Rotation por velocidad, sin tocar
  -- Scale / TearFlags / CollisionDamage. Ramas separadas en POST_TEAR_UPDATE
  -- y POST_TEAR_RENDER, sin interferir con isGLRingBeam.
  local function EnforceGiantFistSprite(tear, td)
      local ts = tear:GetSprite()
      if ts then
          if ts:GetAnimation() ~= "Idle" then
              ts:Load("gfx/effects/gl_giant_fist.anm2", true)
              ts:Play("Idle", true)
          end
          if td and td.glFistScale and Vector then
              ts.Scale = Vector(td.glFistScale, td.glFistScale)
          end
          if Color and ts.Color then
              ts.Color = Color(1, 1, 1, 1, 0, 0, 0)
          end
          if tear.Velocity and tear.Velocity:Length() > 0.1 then
              ts.Rotation = tear.Velocity:GetAngleDegrees()
          elseif td and td.glFistVel and td.glFistVel:Length() > 0.1 then
              ts.Rotation = td.glFistVel:GetAngleDegrees()
          end
      end
  end

  -- Keep all Green Lantern Ring energy beams oriented along their straight flight vector and prevent C++ sprite/variant resets
  GL:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
      local td = tear:GetData()
      if td and td.isGLRingBeam then
          -- Lifetime cap and per-player alive cap to prevent oppressive beam spam accumulation.
          if ApplyBeamLifetimeAndCull(tear, td) then return end

          local isStuck = false
          pcall(function()
              if tear.StickTarget ~= nil then isStuck = true end
              if tear.StickTimer and tear.StickTimer > 0 then isStuck = true end
              if tear.FrameCount > 6 and tear.Velocity and tear.Velocity:Length() < 0.8 then isStuck = true end
          end)
          if isStuck then
              HideTearSprite(tear)
              return
          end

          HideTearSprite(tear)

          -- Spammeable discrete rays destroy themselves when hitting room walls
          local hitWall = false
          local impactPos = tear.Position
          if Core.IsWallAtPos then
              local pos = tear.Position
              local vel = tear.Velocity
              local speed = (vel and vel.Length and vel:Length()) or 0
              local hasVel = speed > 0.1
              local dir = hasVel and (vel.Normalized and vel:Normalized() or vel) or (td.glBeamVel and (td.glBeamVel.Normalized and td.glBeamVel:Normalized() or td.glBeamVel)) or (Vector and Vector(1, 0)) or { X = 1, Y = 0 }
              local leadDist = math.max((tear.Size or 12.0) * 0.8, speed)
              local checkPos = (Vector and Vector(pos.X + dir.X * leadDist, pos.Y + dir.Y * leadDist)) or { X = pos.X + dir.X * leadDist, Y = pos.Y + dir.Y * leadDist }

              if td.hasEnteredRoom == false then
                  if not Core.IsWallAtPos(pos) then
                      td.hasEnteredRoom = true
                  elseif (tear.FrameCount or 0) >= 5 or Core.IsWallAtPos(checkPos) then
                      hitWall = true
                      impactPos = pos
                  end
              else
                  if Core.IsWallAtPos(pos) then
                      hitWall = true
                      local inRoomPos = (Vector and Vector(pos.X - dir.X * leadDist, pos.Y - dir.Y * leadDist)) or { X = pos.X - dir.X * leadDist, Y = pos.Y - dir.Y * leadDist }
                      if not Core.IsWallAtPos(inRoomPos) then
                          local lo = inRoomPos
                          local hi = pos
                          for _ = 1, 4 do
                              local mid = (Vector and Vector((lo.X + hi.X) * 0.5, (lo.Y + hi.Y) * 0.5)) or { X = (lo.X + hi.X) * 0.5, Y = (lo.Y + hi.Y) * 0.5 }
                              if Core.IsWallAtPos(mid) then hi = mid else lo = mid end
                          end
                          impactPos = (Vector and Vector((lo.X + hi.X) * 0.5, (lo.Y + hi.Y) * 0.5)) or { X = (lo.X + hi.X) * 0.5, Y = (lo.Y + hi.Y) * 0.5 }
                      else
                          impactPos = pos
                      end
                  elseif hasVel and Core.IsWallAtPos(checkPos) then
                      hitWall = true
                      local lo = pos
                      local hi = checkPos
                      for _ = 1, 4 do
                          local mid = (Vector and Vector((lo.X + hi.X) * 0.5, (lo.Y + hi.Y) * 0.5)) or { X = (lo.X + hi.X) * 0.5, Y = (lo.Y + hi.Y) * 0.5 }
                          if Core.IsWallAtPos(mid) then hi = mid else lo = mid end
                      end
                      impactPos = (Vector and Vector((lo.X + hi.X) * 0.5, (lo.Y + hi.Y) * 0.5)) or { X = (lo.X + hi.X) * 0.5, Y = (lo.Y + hi.Y) * 0.5 }
                  end
              end
          end

          if hitWall then
              td.isGLRingBeam = false
              tear.Position = impactPos
              HideTearSprite(tear)
              pcall(function() tear.CollisionDamage = 0 end)
              pcall(function()
                  if Core.PlayRingSound and SoundEffect and SoundEffect.SOUND_TEARIMPACTS then
                      Core.PlayRingSound(SoundEffect.SOUND_TEARIMPACTS, 0.65, 1.15)
                  elseif SFXManager and SoundEffect and SoundEffect.SOUND_TEARIMPACTS then
                      local vol = (Core.SFX_VOLUME_MULT or 1.0)
                      SFXManager():Play(SoundEffect.SOUND_TEARIMPACTS, 0.65 * vol, 0, false, 1.15)
                  end
                  if Isaac and Isaac.Spawn and EntityType and EffectVariant and EffectVariant.WATER_SPLASH then
                      local zeroVec = (Vector and Vector.Zero) or { X = 0, Y = 0 }
                      local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, impactPos, zeroVec, tear)
                      if fx and Core.SetEntityScaleAndColor then
                          Core.SetEntityScaleAndColor(fx, 0.60, Color(0.1, 1.0, 0.35, 0.85, 0.15, 0.85, 0.25))
                      end
                  end
              end)
              if tear.Die then
                  tear:Die()
              else
                  tear:Remove()
              end
              return
          end

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
                  or (TearFlags.TEAR_TRACTOR_BEAM and Core.HasTearFlag(flags, TearFlags.TEAR_TRACTOR_BEAM))
              then
                  hasCurvingSynergy = true
              end
          end
          local sp = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
          if sp and Core.HasTractorBeam and Core.HasTractorBeam(sp) then
              hasCurvingSynergy = true
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
          else
              if tear.Velocity and tear.Velocity:Length() > 0.1 then
                  td.glBeamVel = Vector(tear.Velocity.X, tear.Velocity.Y)
              end
          end

          EnforceRingBeamTearSprite(tear, td)
      elseif td and td.isGLFist then
          HideTearSprite(tear)
          -- T6: refuerzo del sprite del Giant Fist (rama independiente,
          -- no interfiere con isGLRingBeam). Reaplica Idle y Rotation por velocidad.
          local sp = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
          local flags = tear.TearFlags
          local fistHasTB = (sp and Core.HasTractorBeam and Core.HasTractorBeam(sp)) or (TearFlags and TearFlags.TEAR_TRACTOR_BEAM and flags and Core.HasTearFlag(flags, TearFlags.TEAR_TRACTOR_BEAM))
          if not fistHasTB then
              if td.glFistVel and td.glFistVel:Length() > 0.1 and tear.Velocity:Length() > 0.1 then
                  local currentSpeed = tear.Velocity:Length()
                  tear.Velocity = td.glFistVel:Normalized() * currentSpeed
              end
          else
              if tear.Velocity and tear.Velocity:Length() > 0.1 then
                  td.glFistVel = Vector(tear.Velocity.X, tear.Velocity.Y)
              end
          end
          tear.FallingAcceleration = -0.04
          if tear.FallingSpeed and tear.FallingSpeed > 0 then
              tear.FallingSpeed = 0.0
          end
          EnforceGiantFistSprite(tear, td)
      end
  end)

  if ModCallbacks.MC_POST_TEAR_RENDER then
      GL:AddCallback(ModCallbacks.MC_POST_TEAR_RENDER, function(_, tear, renderOffset)
          local td = tear:GetData()
          if td and td.isGLRingBeam then
              EnforceRingBeamTearSprite(tear, td)
          elseif td and td.isGLFist then
              EnforceGiantFistSprite(tear, td)
          end
      end)
  end

  -- Spawn a crisp emerald energy flash when a piercing Ring Beam slices through an enemy
  GL:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, function(_, tear, collider, low)
      local td = tear:GetData()
      if td and td.isGLFist then
          if collider and collider.IsActiveEnemy and collider:IsActiveEnemy(false) and collider.IsVulnerableEnemy and collider:IsVulnerableEnemy() then
              local frame = Game():GetFrameCount()
              if not td.lastFistHitFrame or (frame - td.lastFistHitFrame) >= 4 then
                  td.lastFistHitFrame = frame
                  pcall(function()
                      local vol = (Core.SFX_VOLUME_MULT or 1.0)
                      SFXManager():Play(SoundEffect.SOUND_PUNCH, 0.95 * vol, 0, false, 0.95)
                      local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, collider.Position, Vector.Zero, tear)
                      if fx then
                          Core.SetEntityScaleAndColor(fx, 0.85, Color(0.1, 1.0, 0.35, 0.9, 0.2, 0.8, 0.25))
                      end
                  end)
              end
          end
          return
      end

      -- Active Combat Resolve: Landing hits with normal human tears actively recovers Willpower (+2% per hit)
      local spHuman = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
      if spHuman and Core.IsHalJordan(spHuman) then
          local sd = Core.GetPlayerData(spHuman)
          if sd and sd.ringDepleted then
              if collider and collider.IsActiveEnemy and collider:IsActiveEnemy(false) and collider.IsVulnerableEnemy and collider:IsVulnerableEnemy() then
                  if not td.glDepletedHitRefund then
                      td.glDepletedHitRefund = true
                      local maxW = (Core.GetMaxWillpower and Core.GetMaxWillpower(spHuman)) or Core.WILLPOWER_MAX
                      sd.willpower = math.min(maxW, (sd.willpower or 0) + (Core.WILLPOWER_DEPLETED_HIT_REBOOT or 2.0))
                      if sd.willpower >= Core.WILLPOWER_REBOOT_THRESHOLD then
                          Core.RestoreHalRingPower(spHuman, sd.willpower, "RING REBOOTED!")
                      end
                  end
              end
          end
      end

      if not (td and td.isGLRingBeam) then return end
      if not (collider and collider.IsActiveEnemy and collider:IsActiveEnemy(false) and collider.IsVulnerableEnemy and collider:IsVulnerableEnemy()) then return end

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
              local max = (Core.GetMaxWillpower and Core.GetMaxWillpower(sp)) or Core.WILLPOWER_MAX
              if (sd.willpower or max) < max and not sd.ringDepleted then
                  sd.willpower = math.min(max, (sd.willpower or max) + Core.WILLPOWER_HIT_REFUND)
                  sp:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                  sp:EvaluateItems()
              end
          end
      end

      -- Parallax dread: los beams de Tainted aplican Fear por probabilidad, no siempre
      if not td.glFearRolled then
          td.glFearRolled = true
          local sp2 = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
          if sp2 and Core.IsTaintedHal(sp2)
            and math.random() < (Core.TAINTED_FEAR_CHANCE or 0.25)
            and not collider:HasEntityFlags(EntityFlag.FLAG_FEAR) then
              pcall(function()
                  collider:AddFear(EntityRef(sp2), 90)
                  collider:AddEntityFlags(EntityFlag.FLAG_FEAR)
              end)
          end
      end
  end)

  GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
      if player then
          local data = Core.GetPlayerData(player)
          data.itemTearBurstFrame = Game():GetFrameCount()
      end
  end)

  GL:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, damageFlags, source, countdown)
      local player = entity and entity:ToPlayer()
      if player and Core.IsRingActive(player) then
          local data = Core.GetPlayerData(player)
          data.itemTearBurstFrame = Game():GetFrameCount()
      end
  end)
end
