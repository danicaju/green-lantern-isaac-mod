-- modules/challenges.lua — RSI: gestion de desafios personalizados (In Brightest Day / Blackest Night).
-- Responsabilidad unica: inicializar personajes e items al entrar a un desafio del mod.
return function(Core)
  local GL = Core.GL

  GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
    if isContinued then return end

    local challengeId = (Isaac.GetChallenge and Isaac.GetChallenge()) or 0
    if challengeId == 0 then return end

    local chalBrightest = (Isaac.GetChallengeIdByName and Isaac.GetChallengeIdByName("In Brightest Day")) or -1
    local chalBlackest  = (Isaac.GetChallengeIdByName and Isaac.GetChallengeIdByName("Blackest Night")) or -1

    if challengeId == chalBrightest then
      for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player then
          if Core.PLAYER_HAL and Core.PLAYER_HAL > 0 and player:GetPlayerType() ~= Core.PLAYER_HAL then
            pcall(function() player:ChangePlayerType(Core.PLAYER_HAL) end)
          end
          player.CanShoot = false
          if Core.ITEM_SOLID_LIGHT_SHIELD and not player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD) then
            player:AddCollectible(Core.ITEM_SOLID_LIGHT_SHIELD, 0, false)
          end
          if Core.ITEM_GIANT_FIST and not player:HasCollectible(Core.ITEM_GIANT_FIST) then
            player:AddCollectible(Core.ITEM_GIANT_FIST, 4, false)
          end
          if Core.ITEM_POWER_BATTERY and not player:HasCollectible(Core.ITEM_POWER_BATTERY) then
            player:AddCollectible(Core.ITEM_POWER_BATTERY, 4, false)
          end
        end
      end
    elseif challengeId == chalBlackest then
      for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player then
          if Core.PLAYER_TAINTED_HAL and Core.PLAYER_TAINTED_HAL > 0 and player:GetPlayerType() ~= Core.PLAYER_TAINTED_HAL then
            pcall(function() player:ChangePlayerType(Core.PLAYER_TAINTED_HAL) end)
          end
          if Core.ITEM_COAST_CITY and not player:HasCollectible(Core.ITEM_COAST_CITY) then
            player:AddCollectible(Core.ITEM_COAST_CITY, 4, false)
          end
          if Core.TRINKET_YELLOW_IMPURITY and not player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY) then
            player:AddTrinket(Core.TRINKET_YELLOW_IMPURITY)
          end
        end
      end
    end
  end)

  -- Re-apply Curse of Darkness in Blackest Night on each new floor
  GL:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function(_)
    local challengeId = (Isaac.GetChallenge and Isaac.GetChallenge()) or 0
    local chalBlackest = (Isaac.GetChallengeIdByName and Isaac.GetChallengeIdByName("Blackest Night")) or -1
    if challengeId > 0 and challengeId == chalBlackest then
      local level = Game():GetLevel()
      if level and level.AddCurse then
        local curseDarkness = (LevelCurse and LevelCurse.CURSE_OF_DARKNESS) or 1
        level:AddCurse(curseDarkness, false)
      end
    end
  end)
end
