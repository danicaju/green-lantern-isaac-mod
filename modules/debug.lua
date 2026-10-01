-- modules/debug.lua -- RSI: solo comandos consola debug (gl_willpower, gl_sparks).
-- No logica de gameplay; delega estado a Core.*. Loader conserva ConsoleOutput final.
return function(Core)
  local GL = Core.GL
  GL:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, cmd, params)
    if cmd == "gl_willpower" then
      local p = Isaac.GetPlayer(0)
      if Core.IsHalJordan(p) then
        local pct = tonumber(params) or 100
        if pct <= 0 then
          Core.TriggerHalRingDepleted(p)
        else
          Core.RestoreHalRingPower(p, pct, "WILLPOWER RESTORED!")
        end
        Isaac.ConsoleOutput(string.format("[GL] Willpower set to %.0f%%\n", pct))
      end
      return true
    end

    if cmd == "gl_sparks" then
      local p = Isaac.GetPlayer(0)
      if Core.IsTaintedHal(p) then
        local pct = tonumber(params) or 100
        Core.GetPlayerData(p).emeraldSparks = pct
        p:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
        p:EvaluateItems()
        Isaac.ConsoleOutput(string.format("[GL] Emerald Sparks set to %.0f%%\n", pct))
      end
      return true
    end
  end)
end
