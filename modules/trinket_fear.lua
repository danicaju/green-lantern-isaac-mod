-- modules/trinket_fear.lua -- RSI: solo Yellow Impurity (fear) + spark burst on kill.
-- Responsabilidad unica: MC_ENTITY_TAKE_DMG fear, MC_POST_UPDATE control confusion, MC_POST_ENTITY_KILL burst. Estado via Core.*, sin globales sueltos.
return function(Core)
  local GL = Core.GL

  -- SECTION 9: YELLOW IMPURITY TRINKET (Fear on damage & control confusion)
  GL:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, flags, source)
    if entity.Type ~= EntityType.ENTITY_PLAYER then return end
    local player = entity:ToPlayer()
    if not player then return end
    if not (Core.TRINKET_YELLOW_IMPURITY and player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY)) then return end

    local isContact   = (flags & DamageFlag.DAMAGE_CRUSH) ~= 0 or (flags & DamageFlag.DAMAGE_NOKILL) == 0
    local isExplosion = (flags & DamageFlag.DAMAGE_EXPLOSION) ~= 0

    if isContact or isExplosion then
      local data = Core.GetPlayerData(player)
      data.fearControlTimer = 60
      data.fearSkullTimer   = 60
      player:AddEntityFlags(EntityFlag.FLAG_FEAR)

      pcall(function()
        player:SetColor(Color(1.0, 0.9, 0.1, 1.0, 0.4, 0.35, 0.0), 20, 1, true, false)
        SFXManager():Play(SoundEffect.SOUND_DEATH_BURST_SMALL, 1.0, 0, false, 1.1)
      end)
    end
  end)

  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if player then
        local hasTrinket = Core.TRINKET_YELLOW_IMPURITY and player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY)
        local data = Core.GetPlayerData(player)
        if data.fearSkullTimer and data.fearSkullTimer > 0 then
          data.fearSkullTimer = data.fearSkullTimer - 1
        end
        if data.fearControlTimer and data.fearControlTimer > 0 then
          data.fearControlTimer = data.fearControlTimer - 1
          if hasTrinket then
            local moveInput = player:GetMovementInput()
            if moveInput:Length() > 0.05 then
              local fearSpeed = math.max(2.8, (player.MoveSpeed or 1.0) * 3.2)
              player.Velocity = -moveInput:Normalized() * fearSpeed
            end

            -- Trailing fear poof behind player while running scared
            if Game():GetFrameCount() % 4 == 0 then
              pcall(function()
                local dust = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF04, 0, player.Position, Vector.Zero, nil)
                if dust then
                  dust:GetSprite().Color = Color(1.0, 0.85, 0.1, 0.7, 0.3, 0.25, 0.0)
                  dust.Scale = 0.5
                end
              end)
            end
          end

          if data.fearControlTimer <= 0 then
            player:ClearEntityFlags(EntityFlag.FLAG_FEAR)
          end
        end
      end
    end
  end)

  -- Defeating enemies with Green Lantern Ring releases a burst of emerald construct sparks
  GL:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, entity)
    if not (entity and entity:IsActiveEnemy(false)) then return end
    pcall(function()
      for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player and Core.HasGreenLanternRing(player) then
          local dist = (player.Position - entity.Position):Length()
          if dist <= 400 then
            local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, entity.Position, Vector.Zero, player)
            if fx then
              fx:GetSprite().Color = Color(0.1, 1.0, 0.4, 0.85, 0.1, 0.7, 0.15)
              fx.Scale = 0.75
            end
            break
          end
        end
      end
    end)
  end)
end
