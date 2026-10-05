-- modules/item_gatling.lua -- RSI: solo Gatling. Sin Willpower pasivo, sin beam.
-- Activo 4 cargas: 10s de beams discretos rapidos sin coste de Willpower.
return function(Core)
  local GL = Core.GL

  GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if not Core.ITEM_GATLING or Core.ITEM_GATLING < 0 then Core.LoadItemIDs() end
    if itemID ~= Core.ITEM_GATLING then return end

    -- Sin anillo activo no hay constructos que disparar
    if not Core.IsRingActive(player) then
      local data = Core.GetPlayerData(player)
      data.oathText = "RING OFFLINE!"
      data.oathTextTimer = 60
      pcall(function()
        SFXManager():Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.8, 0, false, 1.0)
      end)
      return { Discharge = false, Remove = false, ShowAnim = false }
    end

    local data = Core.GetPlayerData(player)
    data.gatlingTimer = Core.GATLING_DURATION
    data.ringFlareTimer = 20
    pcall(function()
      SFXManager():Play(SoundEffect.SOUND_POWERUP_SPEWER, 1.0, 0, false, 1.3)
    end)
    player:AnimateHappy()
    return true
  end)

  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if player then
        local data = Core.GetPlayerData(player)
        if data.gatlingTimer and data.gatlingTimer > 0 then
          data.gatlingTimer = data.gatlingTimer - 1
        end
      end
    end
  end)
end
