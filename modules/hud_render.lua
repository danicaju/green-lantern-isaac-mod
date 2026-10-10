-- modules/hud_render.lua -- RSI: render player + HUD + ItemMenu guard + 60Hz poll.
return function(Core)
  local GL = Core.GL

  if ModCallbacks.MC_PRE_PLAYER_RENDER then
    GL:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, renderOffset)
      if RenderMode and Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
      local p0 = Isaac.GetPlayer(0)
      if not p0 or player.Index == p0.Index then
        Core.RenderGLSparkDrops(false)
      end
      Core.RenderGLPlayerAura(player)
      Core.RenderGLSolidShieldBehind(player, renderOffset)
      if Core.RenderGLBatteryOrbital then
        Core.RenderGLBatteryOrbital(player, renderOffset, true)
      end
      if Core.IsRingActive(player) then
        local data = Core.GetPlayerData(player)
        if Core.IsPlayerAimingUpForRender(player, data) then
          Core.RenderGLBeamAndFlareForPlayer(player, data, Game():GetFrameCount())
        end
      end
      return nil
    end)
  end

  GL:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player, renderOffset)
    if RenderMode and Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
    local p0 = Isaac.GetPlayer(0)
    if not p0 or player.Index == p0.Index then
      if ModCallbacks.MC_PRE_PLAYER_RENDER then
        Core.RenderGLSparkDrops(true)
      else
        Core.RenderGLSparkDrops(nil)
      end
    end
    if not ModCallbacks.MC_PRE_PLAYER_RENDER then
      Core.RenderGLPlayerAura(player)
      Core.RenderGLSolidShieldBehind(player, renderOffset)
      if Core.RenderGLBatteryOrbital then
        Core.RenderGLBatteryOrbital(player, renderOffset, nil)
      end
    end
    Core.RenderGLSolidShieldFront(player, renderOffset)
    if ModCallbacks.MC_PRE_PLAYER_RENDER and Core.RenderGLBatteryOrbital then
      Core.RenderGLBatteryOrbital(player, renderOffset, false)
    end
    Core.RenderGLActiveItemAndTrinketEffects(player, renderOffset)
    if not Core.IsRingActive(player) then return end
    local data = Core.GetPlayerData(player)
    if (not ModCallbacks.MC_PRE_PLAYER_RENDER) or (not Core.IsPlayerAimingUpForRender(player, data)) then
      Core.RenderGLBeamAndFlareForPlayer(player, data, Game():GetFrameCount())
    end
  end)

  local lastRenderGameFrame = -1
  local frozenRenderFrames = 0
  local imVisibleBeforeFreeze = false

  GL:AddCallback(ModCallbacks.MC_POST_RENDER, function(_)
    Core.EnsureEIDRegistered()
    Core.RegisterStageAPIGraphics()
    local currentGameFrame = Game():GetFrameCount()
    local gameAdvancedThisRender = (currentGameFrame ~= lastRenderGameFrame)
    if currentGameFrame == lastRenderGameFrame then
      frozenRenderFrames = frozenRenderFrames + 1
    else
      lastRenderGameFrame = currentGameFrame
      frozenRenderFrames = 0
      if _G.Onseshigo and _G.Onseshigo.ItemMenu and _G.Onseshigo.ItemMenu.Vars then
        imVisibleBeforeFreeze = _G.Onseshigo.ItemMenu.Vars.isVisible and true or false
      end
    end
    if _G.Onseshigo and _G.Onseshigo.ItemMenu and _G.Onseshigo.ItemMenu.Vars then
      local imVars = _G.Onseshigo.ItemMenu.Vars
      if frozenRenderFrames > 2 then
        if not imVisibleBeforeFreeze then imVars.isVisible = false end
        imVars.editModes = true
      elseif not imVars.isVisible then
        imVars.editModes = true
      end
    end

    local isPaused = false
    pcall(function() isPaused = Game():IsPaused() end)
    if not isPaused then
      local TWO_PI = math.pi * 2
      for i = 0, Game():GetNumPlayers() - 1 do
        local p = Isaac.GetPlayer(i)
        if p then
          local d = Core.GetPlayerData(p)
          if d then
            d.batteryOrbitAngle = ((d.batteryOrbitAngle or 0) + 0.035) % TWO_PI
          end
        end
      end
    end

    for i = 0, Game():GetNumPlayers() - 1 do
      local p = Isaac.GetPlayer(i)
      if p and (Core.IsHalJordan(p) or Core.IsTaintedHal(p)) then
        local d = Core.GetPlayerData(p)
        local shootIn = p:GetShootingInput()
        local holdingNow = (shootIn and shootIn:Length() > 0.1) or false
        if holdingNow then
          local rawDir = shootIn:Normalized()
          d.renderLastShootDir = Vector(rawDir.X, rawDir.Y)
          if d.wasHoldingShootOnRender == false then
            d.sawShootPressBetweenFrames = true
          end
        else
          if d.wasHoldingShootOnRender == true or (d.shootHoldFrames or 0) > 0 then
            d.sawShootReleaseBetweenFrames = true
          end
          if d.isFiringContinuousBeam then
            Core.StopContinuousBeam(d)
          end
        end
        d.wasHoldingShootOnRender = holdingNow
      end
    end
    if Core.HUD_GL_DISPLAY == false then return end
    if Game():GetHUD() and not Game():GetHUD():IsVisible() then return end
    local hudOffset = (Options and Options.HUDOffset) or 0
    local baseX = 48 + math.floor(hudOffset * 20)
    local baseY = 40 + math.floor(hudOffset * 12)
    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if player then
        local hudX = baseX
        local hudY = baseY + (i * 14)
        local data = Core.GetPlayerData(player)
        if Core.IsHalJordan(player) then
          local maxWill = (Core.GetMaxWillpower and Core.GetMaxWillpower(player)) or Core.WILLPOWER_MAX
          local pct = math.max(0.0, math.min(1.0, (data.willpower or 0) / maxWill))
          local BAR_W = 36
          Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * 0.14, 0.9, 0.08, 0.08, 0.08, 0.85)
          local r, g, b = 0.1, 0.95, 0.3
          if data.ringDepleted then
            r, g, b = 1.0, 0.45, 0.15
          elseif data.overcharge then
            r, g, b = 1.0, 0.88, 0.15
          elseif data.surgeBuff then
            r, g, b = 0.35, 1.0, 0.65
          elseif pct >= 0.995 then
            r, g, b = 0.35, 1.0, 0.55
          end
          if pct > 0 then
            Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * pct * 0.14, 0.9, r, g, b, 0.95)
          end
          local label = string.format("%.0f%%", data.willpower or 0)
          if (data.gatlingTimer or 0) > 0 then
            label = string.format("%.0f%% GATLING", data.willpower or 0)
          elseif data.ringDepleted then
            label = string.format("REBOOT %.0f%%/%.0f%%", data.willpower or 0, Core.WILLPOWER_REBOOT_THRESHOLD)
          elseif data.overcharge then
            local bonus = (data.overchargeTier or 1) >= 2 and "+25%DMG" or "+15%DMG"
            label = string.format("%.0f%% %s", data.willpower or 0, bonus)
          end
          Core.DrawHudText(label, hudX + 33, hudY - 2, r, g, b, 0.95)
          if data.oathTextTimer and data.oathTextTimer > 0 then
            if gameAdvancedThisRender and currentGameFrame % 2 == 0 then data.oathTextTimer = data.oathTextTimer - 1 end
            if data.oathText then
              local hp = Isaac.WorldToScreen(player.Position + Vector(0, -48))
              Core.DrawHudText(data.oathText, math.floor(hp.X - 38), math.floor(hp.Y), r, g, b, math.min(0.95, data.oathTextTimer / 20.0))
            end
          end
        end
        if Core.IsTaintedHal(player) then
          local pct = math.max(0.0, math.min(1.0, data.emeraldSparks / Core.SPARK_MAX))
          local BAR_W = 36
          Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * 0.14, 0.9, 0.08, 0.08, 0.08, 0.85)
          local r, g, b = 0.0, 0.85, 0.4
          if pct >= 1.0 then r, g, b = 0.25, 1.0, 0.55 end
          if pct > 0 then
            Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * pct * 0.14, 0.9, r, g, b, 0.95)
          end
          local label = pct >= 1.0 and "100%" or string.format("%.0f%%", data.emeraldSparks)
          if data.stolenRings > 0 then
            label = string.format("%s [%d]", label, data.stolenRings)
          end
          Core.DrawHudText(label, hudX + 33, hudY - 2, r, g, b, 0.95)
          if data.oathTextTimer and data.oathTextTimer > 0 then
            if gameAdvancedThisRender and currentGameFrame % 2 == 0 then data.oathTextTimer = data.oathTextTimer - 1 end
            if data.oathText then
              local hp = Isaac.WorldToScreen(player.Position + Vector(0, -48))
              Core.DrawHudText(data.oathText, math.floor(hp.X - 38), math.floor(hp.Y), r, g, b, math.min(0.95, data.oathTextTimer / 20.0))
            end
          end
        end
      end
    end

    -- Render discrete ring beams and Giant Fist constructs with pure custom sprites (never showing vanilla tears)
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
              local isStuck = false
              pcall(function()
                if tear.StickTarget ~= nil then isStuck = true end
                if tear.StickTimer and tear.StickTimer > 0 then isStuck = true end
                if tear.FrameCount > 6 and tear.Velocity and tear.Velocity:Length() < 0.8 then isStuck = true end
              end)

              tear.Visible = false
              pcall(function() if tear:GetSprite() then tear:GetSprite().Color = Color(0, 0, 0, 0) end end)

              if isStuck then
                local screenPos = Isaac.WorldToScreen(tear.Position)
                if Core.glBeamTearSprite then
                  Core.glBeamTearSprite:SetFrame("EnergyNode", animFrame)
                  Core.glBeamTearSprite.Scale = Vector(1.1, 1.1)
                  Core.glBeamTearSprite.Rotation = (currentGameFrame * 6) % 360
                  Core.glBeamTearSprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
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
                    Core.glBeamTearSprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
                    Core.glBeamTearSprite:Render(screenPos, Vector.Zero, Vector.Zero)
                  else
                    Core.glBeamTearSprite:SetFrame("Idle", animFrame)
                    local currentVel = tear.Velocity
                    local targetRot = (currentVel and currentVel:Length() > 0.1) and currentVel:GetAngleDegrees() or (td.glBeamVel and td.glBeamVel:GetAngleDegrees() or 0)
                    if td.lastBeamRot then
                      local diff = (targetRot - td.lastBeamRot + 180) % 360 - 180
                      targetRot = td.lastBeamRot + diff * 0.4
                    end
                    td.lastBeamRot = targetRot
                    Core.glBeamTearSprite.Rotation = targetRot
                    Core.glBeamTearSprite.Scale = Vector(scale, scale)
                    Core.glBeamTearSprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
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
  end)
end
