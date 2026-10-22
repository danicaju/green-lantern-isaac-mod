-- modules/hud_render.lua -- RSI: callbacks de render + coordinacion de HUD.
-- Responsabilidad unica: registrar callbacks de render y orquestar los
-- helpers especializados (input, barras, construct tears).

return function(Core)
  local GL = Core.GL
  -- Escala del texto propio de la HUD (etiqueta %, GATLING, REBOOT, oathText).
  -- Politica de tamano de este modulo; fx_sprites.DrawHudText la consume con default 1.0.
  Core.HUD_TEXT_SCALE = 0.8

  if ModCallbacks.MC_PRE_PLAYER_RENDER then
    GL:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player, renderOffset)
      local room = Game and Game().GetRoom and Game():GetRoom()
      if RenderMode and room and room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
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
    local room = Game and Game().GetRoom and Game():GetRoom()
    if RenderMode and room and room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
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

    if Core.PollInputForRender then
      Core.PollInputForRender()
    end

    if Core.HUD_GL_DISPLAY == false then return end
    if Game():GetHUD() and not Game():GetHUD():IsVisible() then return end

    if Core.RenderHudBars then
      Core.RenderHudBars(currentGameFrame, gameAdvancedThisRender)
    end
    if Core.RenderConstructTears then
      Core.RenderConstructTears(currentGameFrame)
    end
  end)
end
