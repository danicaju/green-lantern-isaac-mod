-- modules/progress.lua -- RSI: progresion persistente Oathkeeper. Sin combate, sin HUD.
-- Al pisar Womb I (tras vencer a Mom) como Hal/Tainted, desbloquea bonus inicial
-- permanente: Hal +1 Soul Heart, Tainted +20% sparks. Todo con pcall.
return function(Core)
  local GL = Core.GL

  Core.Progress = { oathkeeperHal = false, oathkeeperTainted = false }

  local function Save()
    pcall(function()
      GL:SaveModData(json.encode(Core.Progress))
    end)
  end

  local function Load()
    pcall(function()
      if GL:HasModData() then
        local t = json.decode(GL:LoadModData())
        if type(t) == "table" then
          Core.Progress.oathkeeperHal = (t.oathkeeperHal == true)
          Core.Progress.oathkeeperTainted = (t.oathkeeperTainted == true)
        end
      end
    end)
  end

  GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_)
    Load()
  end)

  GL:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function(_)
    local ok, stage = pcall(function() return Game():GetLevel():GetStage() end)
    if not ok or not stage then return end
    if LevelStage and stage == LevelStage.STAGE3_1 then
      local unlocked = false
      for i = 0, Game():GetNumPlayers() - 1 do
        local p = Isaac.GetPlayer(i)
        if Core.IsHalJordan(p) and not Core.Progress.oathkeeperHal then
          Core.Progress.oathkeeperHal = true
          unlocked = true
        elseif Core.IsTaintedHal(p) and not Core.Progress.oathkeeperTainted then
          Core.Progress.oathkeeperTainted = true
          unlocked = true
        end
      end
      if unlocked then Save() end
    end
  end)

  GL:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player)
    if Core.IsHalJordan(player) and Core.Progress.oathkeeperHal then
      local data = Core.GetPlayerData(player)
      if data.oathGrantedThisRun then return end
      pcall(function() player:AddSoulHearts(2) end)
      data.oathGrantedThisRun = true
    elseif Core.IsTaintedHal(player) and Core.Progress.oathkeeperTainted then
      local data = Core.GetPlayerData(player)
      if data.oathGrantedThisRun then return end
      data.emeraldSparks = math.max(20.0, data.emeraldSparks or 0.0)
      data.oathGrantedThisRun = true
    end
  end)
end
