-- modules/item_gatling.lua -- RSI: solo Gatling construct.
-- Activo 4 cargas: 10s de constructo ametralladora.
-- Para Hal Jordan / anillo activo: beams discretos rapidos sin coste de Willpower.
-- Para otros personajes: ametralladora constructo de lagrimas espectrales/perforantes a maxima cadencia.
return function(Core)
  local GL = Core.GL

  GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if not Core.ITEM_GATLING or Core.ITEM_GATLING < 0 then Core.LoadItemIDs() end
    if itemID ~= Core.ITEM_GATLING then return end

    local data = Core.GetPlayerData(player)
    local hasCarBattery = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_CAR_BATTERY) or 356)
    local baseDuration = Core.GATLING_DURATION or 300
    data.gatlingTimer = hasCarBattery and math.floor(baseDuration * 1.5) or baseDuration
    data.ringFlareTimer = 20

    -- Floating text indicator
    data.oathText = hasCarBattery and "GATLING EXTENDED BARRAGE!" or "GATLING OVERCHARGE!"
    data.oathTextTimer = 45

    pcall(function()
      local vol = (Core.SFX_VOLUME_MULT or 1.0)
      SFXManager():Play(SoundEffect.SOUND_POWERUP_SPEWER, 1.0 * vol, 0, false, 1.3)
      SFXManager():Play(SoundEffect.SOUND_GUNSHOT, 0.85 * vol, 0, false, 1.25)
    end)
    player:AnimateHappy()

    -- Re-evaluate fire delay and tear flags immediately
    if CacheFlag then
      player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
      player:AddCacheFlags(CacheFlag.CACHE_TEARFLAG)
      player:AddCacheFlags(CacheFlag.CACHE_SHOTSPEED)
      player:EvaluateItems()
    end

    return true
  end)

  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if player then
        local data = Core.GetPlayerData(player)
        if data.gatlingTimer and data.gatlingTimer > 0 then
          data.gatlingTimer = data.gatlingTimer - 1
          if data.gatlingTimer == 0 then
            -- Reset stats cleanly when timer expires
            if CacheFlag then
              player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
              player:AddCacheFlags(CacheFlag.CACHE_TEARFLAG)
              player:AddCacheFlags(CacheFlag.CACHE_SHOTSPEED)
              player:EvaluateItems()
            end
          end
        end
      end
    end
  end)

  -- When firing tears during Gatling mode, non-ring tears are styled as emerald construct bullets
  GL:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
    local spawner = tear.SpawnerEntity
    if not spawner then return end
    local player = spawner:ToPlayer()
    if not player then return end

    local data = Core.GetPlayerData(player)
    if data and data.gatlingTimer and data.gatlingTimer > 0 then
      if not Core.IsRingActive(player) then
        tear:GetSprite().Color = Color(0.12, 1.0, 0.35, 1.0, 0.08, 0.65, 0.12)
        if tear.AddTearFlags then
          tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
          tear:AddTearFlags(TearFlags.TEAR_PIERCING)
        elseif tear.TearFlags then
          pcall(function()
            tear.TearFlags = tear.TearFlags + (TearFlags and TearFlags.TEAR_SPECTRAL or 0) + (TearFlags and TearFlags.TEAR_PIERCING or 0)
          end)
        end
        pcall(function()
          local vol = (Core.SFX_VOLUME_MULT or 1.0)
          local pitch = 1.1 + (math.random() * 0.3)
          SFXManager():Play(SoundEffect.SOUND_TEARS_FIRE, 0.75 * vol, 0, false, pitch)
        end)
      end
    end
  end)
end
