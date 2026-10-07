-- modules/save_run.lua -- RSI: solo persistencia save/continue de run. Sin combate, sin HUD, sin balance.
-- Guarda por player.Index {willpower, emeraldSparks, stolenRings, overchargeTier}
-- en MC_PRE_GAME_EXIT y MC_POST_NEW_LEVEL; restaura en MC_POST_GAME_STARTED
-- solo si isContinued. Todo acceso a save/json con pcall; corrupto/vacio -> defaults.
return function(Core)
  local GL = Core.GL

  local function Num(v, dflt)
    if type(v) ~= "number" then return dflt end
    if v ~= v then return dflt end -- NaN
    return v
  end

  local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
  end

  local function Collect(player)
    local data = Core.GetPlayerData(player)
    return {
      willpower = data.willpower,
      emeraldSparks = data.emeraldSparks,
      stolenRings = data.stolenRings,
      overchargeTier = data.overchargeTier,
      ringDepleted = (data.ringDepleted == true),
      birthrightInitialized = (data.birthrightInitialized == true),
    }
  end

  local function Apply(player, entry)
    local data = Core.GetPlayerData(player)
    if type(entry) ~= "table" then entry = {} end
    local wMax = (Core.GetMaxWillpower and Core.GetMaxWillpower(player)) or Core.WILLPOWER_MAX or 100.0
    local sMax = Core.SPARK_MAX or 100.0
    local rMax = (Core.GetMaxStolenRings and Core.GetMaxStolenRings(player)) or Core.MAX_STOLEN_RINGS or 10
    data.willpower = Clamp(Num(entry.willpower, wMax), 0, wMax)
    data.emeraldSparks = Clamp(Num(entry.emeraldSparks, 0.0), 0, sMax)
    data.stolenRings = math.floor(Clamp(Num(entry.stolenRings, 0), 0, rMax))
    data.overchargeTier = math.floor(Clamp(Num(entry.overchargeTier, 0), 0, 2))
    data.overcharge = (data.overchargeTier or 0) > 0
    data.ringDepleted = (entry.ringDepleted == true)
    data.birthrightInitialized = (entry.birthrightInitialized == true)
  end

  -- Slot COMPARTIDO SaveModData (un solo string por mod en Isaac) con secciones
  -- namespaced {oath = {...}, run = {...}}. save_run.lua posee `run`;
  -- progress.lua posee `oath`. Read-modify-write: cargar todo, actualizar SOLO
  -- la seccion propia, guardar todo. Nunca lanza; seccion ausente/corrupta ->
  -- defaults por jugador, sin tumbar la seccion ajena.
  -- Normaliza legados planos: {["0"]={...}} (snapshot de run) -> seccion run,
  -- {oathkeeperHal,...} -> seccion oath (preservada intacta).
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
      local snapshot = {}
      local n = Game():GetNumPlayers()
      for i = 0, n - 1 do
        local p = Isaac.GetPlayer(i)
        if p then snapshot[tostring(p.Index or i)] = Collect(p) end
      end
      slot.run = snapshot
      GL:SaveModData(json.encode(slot))
    end)
  end

  local function Load()
    pcall(function()
      if not GL:HasModData() then return end
      local slot = LoadSlot()
      local tbl = slot.run
      if type(tbl) ~= "table" then tbl = {} end -- seccion ausente/corrupta: defaults por jugador
      local n = Game():GetNumPlayers()
      for i = 0, n - 1 do
        local p = Isaac.GetPlayer(i)
        if p then Apply(p, tbl[tostring(p.Index or i)]) end
      end
    end)
  end

  GL:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function() Save() end)
  GL:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function() Save() end)
  GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
    if isContinued then Load() end
  end)
end
