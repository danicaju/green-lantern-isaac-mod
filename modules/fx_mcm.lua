-- modules/fx_mcm.lua -- RSI: menu Mod Config Menu (opcional). Sin gameplay propio.
-- Expone el balance (Core.*) como sliders/toggles. Todo guardado: sin MCM no hace nada.
return function(Core)
  local function AddNumber(key, label, min, max, step, info)
    pcall(function()
      ModConfigMenu.AddSetting("GreenLantern", "Balance", {
        Type = ModConfigMenuOptionType.NUMBER,
        CurrentSetting = function() return Core[key] end,
        Display = function() return label .. ": " .. tostring(Core[key]) end,
        OnChange = function(v) Core[key] = v end,
        Info = info or {},
        Minimum = min,
        Maximum = max,
        ModifyBy = step,
      })
    end)
  end

  local function AddBool(key, label, info)
    pcall(function()
      ModConfigMenu.AddSetting("GreenLantern", "Balance", {
        Type = ModConfigMenuOptionType.BOOLEAN,
        CurrentSetting = function() return Core[key] end,
        Display = function() return label .. ": " .. (Core[key] and "ON" or "OFF") end,
        OnChange = function(v) Core[key] = v end,
        Info = info or {},
      })
    end)
  end

  pcall(function()
    if not ModConfigMenu then return end
    AddNumber("WILLPOWER_PER_TEAR", "Willpower por tiro", 0, 2, 0.1,
      {"Coste de Willpower por beam discreto."})
    AddNumber("WILLPOWER_HIT_REFUND", "Reembolso por impacto", 0, 1, 0.05,
      {"Willpower devuelto por beam que golpea."})
    AddNumber("HAL_CONTINUOUS_WILL_DRAIN", "Drenaje rayo continuo", 0, 0.3, 0.01,
      {"Willpower drenado por tick (30Hz) al canalizar."})
    AddNumber("TAINTED_DMG_MULTIPLIER", "Tainted DMG mult", 1, 2, 0.05,
      {"Multiplicador de dano base de Tainted Hal."})
    AddNumber("SPARK_PER_KILL", "Sparks por emblema", 1, 25, 1,
      {"Medidor ganado por emblema recogido."})
    AddNumber("SPARK_DECAY_PER_SEC", "Decaimiento sparks/s", 0, 10, 0.5,
      {"Hambre de Parallax fuera de combate. 0 = sin decaimiento."})
    AddBool("FEAR_VULN_ENABLED", "Depredador del miedo",
      {"+25% de rayo continuo contra enemigos con Fear."})
  end)
end
