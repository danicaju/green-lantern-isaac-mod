-- modules/hud_render.lua -- RSI: solo render player + HUD + inspector + ItemMenu guard + 60Hz poll.
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
    end
    Core.RenderGLSolidShieldFront(player, renderOffset)
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
    if Game():GetHUD() and not Game():GetHUD():IsVisible() then return end
    local hudOffset = (Options and Options.HUDOffset) or 0
    local baseX = 48 + math.floor(hudOffset * 20)
    local baseY = 33 + math.floor(hudOffset * 12)
    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if player then
        local hudX = baseX
        local hudY = baseY + (i * 14)
        local data = Core.GetPlayerData(player)
        if Core.IsHalJordan(player) then
          local pct = math.max(0.0, math.min(1.0, (data.willpower or 0) / Core.WILLPOWER_MAX))
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
          if data.ringDepleted then
            label = string.format("REBOOT %.0f%%/%.0f%%", data.willpower or 0, Core.WILLPOWER_REBOOT_THRESHOLD)
          elseif data.overcharge then
            label = string.format("%.0f%% +15%%DMG", data.willpower or 0)
          end
          Core.DrawHudText(label, hudX + 33, hudY - 2, r, g, b, 0.95)
          if data.oathTextTimer and data.oathTextTimer > 0 then
            data.oathTextTimer = data.oathTextTimer - 1
            if data.oathText then
              local headPos = Isaac.WorldToScreen(player.Position + Vector(0, -48))
              local textAlpha = math.min(0.95, data.oathTextTimer / 20.0)
              Core.DrawHudText(data.oathText, math.floor(headPos.X - 38), math.floor(headPos.Y), r, g, b, textAlpha)
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
        end
        if i == 0 then
          local inspectTitle, inspectLines = nil, nil
          if not EID then
            local nearestDist = 95
            for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false)) do
              if ent.Variant == PickupVariant.PICKUP_COLLECTIBLE and ent.SubType > 0 then
                local dist = (ent.Position - player.Position):Length()
                if dist < nearestDist then
                  local t, l = Core.GetModItemInspectionInfo(false, ent.SubType)
                  if t then
                    nearestDist = dist
                    inspectTitle = t
                    inspectLines = l
                  end
                end
              elseif ent.Variant == PickupVariant.PICKUP_TRINKET and ent.SubType > 0 then
                local dist = (ent.Position - player.Position):Length()
                if dist < nearestDist then
                  local t, l = Core.GetModItemInspectionInfo(true, ent.SubType)
                  if t then
                    nearestDist = dist
                    inspectTitle = t
                    inspectLines = l
                  end
                end
              end
            end
          end
          local holdingMap = Input.IsActionPressed(ButtonAction.ACTION_MAP, player.ControllerIndex)
            and (Game():GetFrameCount() > 60)
          if not inspectTitle and holdingMap then
            local actId = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY)
            inspectTitle, inspectLines = Core.GetModItemInspectionInfo(false, actId)
            if not inspectTitle and Core.ITEM_SOLID_LIGHT_SHIELD and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD) then
              inspectTitle, inspectLines = Core.GetModItemInspectionInfo(false, Core.ITEM_SOLID_LIGHT_SHIELD)
            end
            if not inspectTitle and Core.TRINKET_YELLOW_IMPURITY and player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY) then
              inspectTitle, inspectLines = Core.GetModItemInspectionInfo(true, Core.TRINKET_YELLOW_IMPURITY)
            end
          end
          if inspectTitle and inspectLines then
            local boxX = math.max(12, baseX - 28)
            local boxY = 215
            Core.DrawHudText(inspectTitle, boxX, boxY, 0.25, 1.0, 0.45, 0.95)
            for idx, line in ipairs(inspectLines) do
              Core.DrawHudText(line, boxX, boxY + idx * 9, 0.92, 0.96, 0.93, 0.90)
            end
          end
        end
      end
    end
  end)
end
