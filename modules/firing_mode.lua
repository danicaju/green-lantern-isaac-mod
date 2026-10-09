-- modules/firing_mode.lua -- RSI: dual firing mode + buffered tap + FireDelay>=2 + pickup/swap.
return function(Core)
  local GL = Core.GL

  GL:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    local data = Core.GetPlayerData(player)
    if Core.IsHalJordan(player) or Core.IsTaintedHal(player) then
      local frame = Game():GetFrameCount()
      if data.lastSmallBeamFrame and frame < data.lastSmallBeamFrame then
        data.lastSmallBeamFrame = -999
        data.lastDiscreteClickReleaseFrame = -999
      end
      local shootInput = player:GetShootingInput()
      local isHoldingShoot = (shootInput and shootInput:Length() > 0.1) or false
      local canUseBeam = Core.CanUseContinuousBeam(player)
      local recentClickSpam = (frame - (data.lastDiscreteClickReleaseFrame or -999)) <= 12
      local holdThreshold = Core.HAL_CONTINUOUS_HOLD_FRAMES + (recentClickSpam and Core.HAL_SPAM_EXTRA_HOLD_FRAMES or 0)
      if data.sawShootReleaseBetweenFrames then
        data.sawShootReleaseBetweenFrames = false
        local releaseDir = data.lastShootDir or data.renderLastShootDir
        if (data.shootHoldFrames or 0) > 0
          and data.shootHoldFrames < holdThreshold
          and not data.firedSmallBeamThisPress
          and releaseDir
        then
          if canUseBeam then
            data.bufferedClickDir = Vector(releaseDir.X, releaseDir.Y)
            data.bufferedClickExpireFrame = frame + 15
            data.lastDiscreteClickReleaseFrame = frame
          elseif Core.IsHalJordan(player) and data.ringDepleted then
            data.humanTapShootDir = Vector(releaseDir.X, releaseDir.Y)
            data.humanTapExpireFrame = frame + 12
          end
        end
        if data.isFiringContinuousBeam or data.continuousLaser then
          Core.StopContinuousBeam(data)
        end
        data.shootHoldFrames = 0
        data.firedSmallBeamThisPress = false
        data.continuousBeamGraceTimer = 0
        data.lastContinuousBeamDir = nil
        recentClickSpam = (frame - (data.lastDiscreteClickReleaseFrame or -999)) <= 12
        holdThreshold = Core.HAL_CONTINUOUS_HOLD_FRAMES + (recentClickSpam and Core.HAL_SPAM_EXTRA_HOLD_FRAMES or 0)
      end
      if not isHoldingShoot and data.sawShootPressBetweenFrames then
        data.sawShootPressBetweenFrames = false
        local tapDir = data.renderLastShootDir or data.lastShootDir
        if tapDir then
          if canUseBeam then
            data.bufferedClickDir = Vector(tapDir.X, tapDir.Y)
            data.bufferedClickExpireFrame = frame + 15
            data.lastDiscreteClickReleaseFrame = frame
          elseif Core.IsHalJordan(player) and data.ringDepleted then
            data.humanTapShootDir = Vector(tapDir.X, tapDir.Y)
            data.humanTapExpireFrame = frame + 12
          end
        end
      else
        data.sawShootPressBetweenFrames = false
      end
      if isHoldingShoot and canUseBeam then
        local rawDir = shootInput:Normalized()
        local shootDir = Vector(rawDir.X, rawDir.Y)
        local handOffset = Core.GetRingHandOffset(player, shootDir)
        data.lastShootDir = shootDir
        data.lastRingHandOffset = handOffset
        if (data.shootHoldFrames or 0) == 0 then
          data.firedSmallBeamThisPress = false
        end
        local switchedBeamDir = false
        if (not recentClickSpam) and (data.continuousBeamGraceTimer or 0) > 0 and data.lastContinuousBeamDir then
          local dot = shootDir.X * data.lastContinuousBeamDir.X + shootDir.Y * data.lastContinuousBeamDir.Y
          if dot < 0.75 then
            switchedBeamDir = true
          end
        end
        if data.lastShootUpdateFrame ~= frame then
          data.lastShootUpdateFrame = frame
          if switchedBeamDir then
            data.shootHoldFrames = math.max((data.shootHoldFrames or 0) + 1, holdThreshold)
          else
            data.shootHoldFrames = (data.shootHoldFrames or 0) + 1
          end
        end
        if data.shootHoldFrames < holdThreshold then
          player.FireDelay = math.max(player.FireDelay, 2)
          data.ringFlareTimer = math.max(data.ringFlareTimer or 0, 3)
        else
          data.isFiringContinuousBeam = true
          data.continuousBeamGraceTimer = 4
          data.lastContinuousBeamDir = Vector(shootDir.X, shootDir.Y)
          data.bufferedClickDir = nil
          player.FireDelay = math.max(player.FireDelay, 5)
          data.ringFlareTimer = 4
          if frame % Core.HAL_CONTINUOUS_TICK_FRAMES == 0 then
            local angles = (Core.GetContinuousBeamAngles and Core.GetContinuousBeamAngles(player)) or { 0 }
            local startWorld = player.Position + handOffset
            for _, ang in ipairs(angles) do
              local rayDir = (ang == 0) and shootDir or (shootDir.Rotated and shootDir:Rotated(ang) or shootDir)
              local endWorld = Core.ComputeContinuousBeamEndWorld(startWorld, rayDir)
              local dmgStart = Core.IsAimingUp(player, rayDir) and (player.Position + Vector(0, -8)) or startWorld
              Core.TickContinuousBeamDamage(player, data, dmgStart, endWorld)
            end
          end
          if Core.IsHalJordan(player) then
            local drain = Core.HAL_CONTINUOUS_WILL_DRAIN
            if CollectibleType and CollectibleType.COLLECTIBLE_SOY_MILK and player:HasCollectible(CollectibleType.COLLECTIBLE_SOY_MILK) then
              drain = drain * 0.35
            elseif CollectibleType and CollectibleType.COLLECTIBLE_ALMOND_MILK and player:HasCollectible(CollectibleType.COLLECTIBLE_ALMOND_MILK) then
              drain = drain * 0.40
            end
            local prevWillBucket = math.floor((data.willpower or Core.WILLPOWER_MAX) + 0.5)
            data.willpower = math.max(0, (data.willpower or Core.WILLPOWER_MAX) - drain)
            local newWillBucket = math.floor(data.willpower + 0.5)
            if data.willpower <= 0 then
              Core.TriggerHalRingDepleted(player)
            elseif newWillBucket ~= prevWillBucket then
              player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
              player:EvaluateItems()
            end
          end
        end
      elseif isHoldingShoot and Core.IsHalJordan(player) and data.ringDepleted then
        local rawDir = shootInput:Normalized()
        local shootDir = Vector(rawDir.X, rawDir.Y)
        data.lastShootDir = shootDir
        if data.lastShootUpdateFrame ~= frame then
          data.lastShootUpdateFrame = frame
          data.shootHoldFrames = (data.shootHoldFrames or 0) + 1
        end
      else
        if (data.continuousBeamGraceTimer or 0) > 0 then
          data.continuousBeamGraceTimer = data.continuousBeamGraceTimer - 1
          if data.continuousBeamGraceTimer <= 0 then
            data.lastContinuousBeamDir = nil
          end
        end
        local releaseDir = data.lastShootDir or data.renderLastShootDir
        if (data.shootHoldFrames or 0) > 0
          and data.shootHoldFrames < holdThreshold
          and not data.firedSmallBeamThisPress
          and releaseDir
        then
          if canUseBeam then
            data.bufferedClickDir = Vector(releaseDir.X, releaseDir.Y)
            data.bufferedClickExpireFrame = frame + 15
            data.lastDiscreteClickReleaseFrame = frame
          elseif Core.IsHalJordan(player) and data.ringDepleted then
            data.humanTapShootDir = Vector(releaseDir.X, releaseDir.Y)
            data.humanTapExpireFrame = frame + 12
          end
        end
        if data.isFiringContinuousBeam or data.continuousLaser then
          Core.StopContinuousBeam(data)
        end
        data.shootHoldFrames = 0
        data.firedSmallBeamThisPress = false
      end
      if Core.IsHalJordan(player) and data.ringDepleted and data.humanTapShootDir then
        if frame > (data.humanTapExpireFrame or 0) then
          data.humanTapShootDir = nil
        elseif (player.FireDelay or 0) <= 0 then
          local dir = Vector(data.humanTapShootDir.X, data.humanTapShootDir.Y)
          data.humanTapShootDir = nil
          local shotSpeed = math.max(6.0, (player.ShotSpeed or 1.0) * 10.0)
          local vel = dir * shotSpeed
          pcall(function()
            vel = vel + player:GetTearMovementInheritance(dir)
            player:FireTear(player.Position, vel, false, false, false)
          end)
          player.FireDelay = math.max(player.MaxFireDelay or 10, 5)
        end
      end
      if data.bufferedClickDir and not data.isFiringContinuousBeam then
        if frame > (data.bufferedClickExpireFrame or 0) or not Core.CanUseContinuousBeam(player) then
          data.bufferedClickDir = nil
        else
          local minClickInterval = math.max(6, math.min(10, math.floor((player.MaxFireDelay or 10) * 0.70)))
          if (data.gatlingTimer or 0) > 0 then minClickInterval = 2 end
          if (frame - (data.lastSmallBeamFrame or -999)) >= minClickInterval then
            local dir = Vector(data.bufferedClickDir.X, data.bufferedClickDir.Y)
            data.bufferedClickDir = nil
            data.lastSmallBeamFrame = frame
            local spawnOffset = Core.GetRingBeamTearSpawnOffset(player, dir)
            local shotSpeed = math.max(6.0, (player.ShotSpeed or 1.0) * 10.0)
            local shotCount = Core.GetTapTearCount(player)
            data.allowingTapTear = true
            data.firingBufferedClick = true
            data.tapBurstCount = shotCount
            data.tapBurstBaseDir = dir
            pcall(function()
              for sIdx = 1, shotCount do
                data.tapBurstIndex = sIdx
                local shotDir = dir
                if shotCount >= 3 and dir.Rotated then
                  local spreadDeg = (sIdx - (shotCount + 1) * 0.5) * 3.5
                  shotDir = dir:Rotated(spreadDeg)
                end
                local vel = shotDir * shotSpeed
                pcall(function()
                  vel = vel + player:GetTearMovementInheritance(shotDir)
                end)
                player:FireTear(player.Position + spawnOffset, vel, false, false, false)
              end
            end)
            data.allowingTapTear = false
            data.firingBufferedClick = false
            data.tapBurstCount = nil
            data.tapBurstIndex = nil
            data.tapBurstBaseDir = nil
            player.FireDelay = math.max(player.MaxFireDelay or 10, 2)
          end
        end
      end
      if Core.CanUseContinuousBeam(player) then
        player.FireDelay = math.max(player.FireDelay, 2)
      end
    end
    local count = player:GetCollectibleCount()
    local activeId = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY)
    local queueEmpty = player:IsItemQueueEmpty()
    if data.lastCollectibleCount ~= count
      or data.lastActiveItem ~= activeId
      or (data.wasQueueEmpty == false and queueEmpty == true)
    then
      data.lastCollectibleCount = count
      data.lastActiveItem = activeId
      Core.RefreshCharacterCostume(player)
      local hasShield = Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0
        and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD)
      if not hasShield then
        data.grantedSolidShieldHearts = false
      elseif not data.grantedSolidShieldHearts then
        data.grantedSolidShieldHearts = true
        player:AddSoulHearts(2)
        pcall(function()
          SFXManager():Play(SoundEffect.SOUND_HOLY, 1.0, 0, false, 1.0)
        end)
        data.shieldDeflectTimer = 16
      end
      if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 and player:HasCollectible(Core.ITEM_POWER_RING) then
        if not data.grantedRingVisual then
          data.grantedRingVisual = true
          data.ringFlareTimer = 24
        end
      end
    end
    data.wasQueueEmpty = queueEmpty
  end)
end
