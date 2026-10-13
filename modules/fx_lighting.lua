-- modules/fx_lighting.lua — RSI: iluminacion dinamica de constructos esmeralda en salas oscuras.
-- Responsabilidad unica: efectos de luz (EffectVariant.LIGHT / HALO) cuando el anillo o rayo esta activo.
return function(Core)
  local GL = Core.GL
  local LIGHT_VAR = (EffectVariant and EffectVariant.LIGHT) or 121

  local function hasDarknessCurse(curses, curseDark)
    if not curses or curses == 0 then return false end
    return (curses % (curseDark * 2)) >= curseDark
  end

  GL:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    if Core.DYNAMIC_LIGHTING_ENABLED == false then return end
    if not Core.IsRingActive(player) then return end

    local data = Core.GetPlayerData(player)
    local isFiring = data.isFiringContinuousBeam == true
    local hasFlare = (data.ringFlareTimer or 0) > 0
    local isDarkRoom = false

    local room = Game and Game().GetRoom and Game():GetRoom()
    if room and room.GetLightingAmount and room:GetLightingAmount() < 0.85 then
      isDarkRoom = true
    end
    local level = Game and Game().GetLevel and Game():GetLevel()
    if level and level.GetCurses then
      local curseDark = (LevelCurse and LevelCurse.CURSE_OF_DARKNESS) or 1
      if hasDarknessCurse(level:GetCurses(), curseDark) then
        isDarkRoom = true
      end
    end

    if isFiring or hasFlare or isDarkRoom then
      local lightEnt = data.glLightEntity
      if not (lightEnt and lightEnt:Exists() and not lightEnt:IsDead()) then
        pcall(function()
          lightEnt = Isaac.Spawn(EntityType.ENTITY_EFFECT, LIGHT_VAR, 0, player.Position, Vector.Zero, player)
          if lightEnt then
            lightEnt:GetData().isGLLight = true
            lightEnt.DepthOffset = -10
            data.glLightEntity = lightEnt
          end
        end)
      end

      if lightEnt and lightEnt:Exists() then
        lightEnt.Position = player.Position
        local scale = isFiring and 1.85 or (hasFlare and 1.45 or 1.15)
        local alpha = isFiring and 0.65 or (hasFlare and 0.45 or 0.30)
        pcall(function()
          lightEnt.SpriteScale = Vector(scale, scale)
          lightEnt:GetSprite().Color = Color(0.15, 1.0, 0.40, alpha, 0.10, 0.75, 0.20)
        end)
      end
    else
      if data.glLightEntity and data.glLightEntity:Exists() then
        pcall(function() data.glLightEntity:Remove() end)
        data.glLightEntity = nil
      end
    end
  end)

  -- Clean up light entities on room exit
  GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    if Isaac and Isaac.FindByType then
      for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, LIGHT_VAR, -1, false)) do
        local ed = ent:GetData()
        if ed and ed.isGLLight then
          pcall(function() ent:Remove() end)
        end
      end
    end
  end)
end
