-- modules/progress.lua -- RSI: progresion persistente Oathkeeper. Sin combate, sin HUD.
-- Al pisar Womb I (tras vencer a Mom) como Hal/Tainted, desbloquea bonus inicial
-- permanente: Hal +1 Soul Heart, Tainted +20% sparks. Todo con pcall.
return function(Core)
  local GL = Core.GL

  Core.Progress = { oathkeeperHal = false, oathkeeperTainted = false }

  -- Slot COMPARTIDO SaveModData (un solo string por mod en Isaac) con secciones
  -- namespaced {oath = {...}, run = {...}}. progress.lua posee `oath`;
  -- save_run.lua posee `run`. Read-modify-write: cargar todo, actualizar SOLO
  -- la seccion propia, guardar todo. Nunca lanza; corrupto/vacio -> {} y cada
  -- seccion cae a defaults al leerla, sin tumbar la otra.
  -- Normaliza legados planos: {oathkeeperHal,...} -> seccion oath,
  -- {["0"]={...}} (snapshot de run) -> seccion run.
  local function LoadSlot()
    local slot = nil
    pcall(function()
      if GL:HasModData() then
        local raw = GL:LoadModData()
        if type(raw) == "string" and raw ~= "" then
          local ok, decoded = pcall(json.decode, raw)
          if ok and type(decoded) == "table" then slot = decoded end
        end
      end
    end)
    if type(slot) ~= "table" then slot = {} end
    if type(slot.oath) ~= "table" and type(slot.run) ~= "table" then
      if slot.oathkeeperHal ~= nil or slot.oathkeeperTainted ~= nil then
        slot = { oath = { oathkeeperHal = slot.oathkeeperHal, oathkeeperTainted = slot.oathkeeperTainted } }
      elseif next(slot) ~= nil then
        slot = { run = slot }
      end
    end
    return slot
  end

  local function Save()
    pcall(function()
      local slot = LoadSlot()
      slot.oath = {
        oathkeeperHal = (Core.Progress.oathkeeperHal == true),
        oathkeeperTainted = (Core.Progress.oathkeeperTainted == true),
      }
      GL:SaveModData(json.encode(slot))
    end)
  end

  local function Load()
    pcall(function()
      local slot = LoadSlot()
      local oath = slot.oath
      if type(oath) ~= "table" then oath = {} end
      Core.Progress.oathkeeperHal = (oath.oathkeeperHal == true)
      Core.Progress.oathkeeperTainted = (oath.oathkeeperTainted == true)
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
