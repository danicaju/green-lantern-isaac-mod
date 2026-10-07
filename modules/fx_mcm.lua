-- modules/fx_mcm.lua -- RSI: menu Mod Config Menu (opcional). Sin gameplay propio.
-- Expone el balance y accesibilidad (Core.*) como sliders/toggles categorizados.
return function(Core)
  local function AddNumber(subCategory, key, label, min, max, step, info)
    pcall(function()
      ModConfigMenu.AddSetting("GreenLantern", subCategory or "Balance", {
        Type = ModConfigMenuOptionType.NUMBER,
        CurrentSetting = function() return Core[key] end,
        Display = function() return label .. ": " .. string.format("%.2f", Core[key] or 0) end,
        OnChange = function(v) Core[key] = v end,
        Info = info or {},
        Minimum = min,
        Maximum = max,
        ModifyBy = step,
      })
    end)
  end

  local function AddInt(subCategory, key, label, min, max, step, info)
    pcall(function()
      ModConfigMenu.AddSetting("GreenLantern", subCategory or "Balance", {
        Type = ModConfigMenuOptionType.NUMBER,
        CurrentSetting = function() return math.floor((Core[key] or 0) + 0.5) end,
        Display = function() return label .. ": " .. tostring(math.floor((Core[key] or 0) + 0.5)) end,
        OnChange = function(v)
          Core[key] = math.floor(tonumber(v) or min)
          if Core[key] < min then Core[key] = min end
          if Core[key] > max then Core[key] = max end
        end,
        Info = info or {},
        Minimum = min,
        Maximum = max,
        ModifyBy = step,
      })
    end)
  end

  local function AddBool(subCategory, key, label, info)
    pcall(function()
      ModConfigMenu.AddSetting("GreenLantern", subCategory or "Balance", {
        Type = ModConfigMenuOptionType.BOOLEAN,
        CurrentSetting = function() return Core[key] ~= false end,
        Display = function() return label .. ": " .. (Core[key] ~= false and "ON" or "OFF") end,
        OnChange = function(v) Core[key] = v end,
        Info = info or {},
      })
    end)
  end

  pcall(function()
    if not ModConfigMenu then return end

    -- === 1. ACCESSIBILITY & DISPLAY ===
    AddBool("Accessibility", "SCREEN_SHAKE_ENABLED", "Temblor de pantalla",
      {"Activar o desactivar el temblor de pantalla al golpear con el puno o explosiones.",
       "Recomendado en OFF para personas sensibles al movimiento."})
    AddBool("Accessibility", "HUD_GL_DISPLAY", "Mostrar HUD Linterna",
      {"Muestra u oculta las barras de porcentaje y medidores de Voluntad/Sparks en pantalla."})
    AddNumber("Accessibility", "SFX_VOLUME_MULT", "Volumen efectos constructos", 0.0, 1.5, 0.1,
      {"Multiplicador de volumen para sonidos de constructos esmeralda y choques."})
    AddBool("Accessibility", "BOSS_OATH_CUES_ENABLED", "Juramentos en sala de jefe",
      {"Muestra el juramento dramatico y destello de anillo al entrar a una sala de jefe.",
       "Hal: 'NO EVIL SHALL ESCAPE MY SIGHT!' | Parallax: 'FEAR THE LIGHT OF PARALLAX!'"})

    -- === 2. CONTROLS & FEEL ===
    AddInt("Controls", "HAL_CONTINUOUS_HOLD_FRAMES", "Frames para rayo continuo", 4, 30, 1,
      {"Frames manteniendo disparo antes de pasar de proyectil discreto a rayo continuo.",
       "Default 10 frames (~1/3 de segundo)."})

    -- === 3. BALANCE & BIRTHRIGHT ===
    AddBool("Balance", "BIRTHRIGHT_ENABLED", "Habilidades de Birthright",
      {"Activa o desactiva las mecanicas de Birthright exclusivas para Hal Jordan y Parallax.",
       "Hal: 150% Voluntad y rayo mas grueso | Parallax: Onda de miedo y 15 anillos."})
    AddNumber("Balance", "WILLPOWER_PER_TEAR", "Voluntad por tiro", 0, 2, 0.1,
      {"Coste de Voluntad por beam discreto."})
    AddNumber("Balance", "WILLPOWER_HIT_REFUND", "Reembolso por impacto", 0, 1, 0.05,
      {"Voluntad devuelta por beam que impacta a un enemigo."})
    AddNumber("Balance", "HAL_CONTINUOUS_WILL_DRAIN", "Drenaje rayo continuo", 0, 0.3, 0.01,
      {"Voluntad drenada por tick (30Hz) al canalizar el laser."})
    AddNumber("Balance", "HAL_CONTINUOUS_BEAM_DMG_MULT", "Dano rayo continuo", 0.05, 0.6, 0.05,
      {"Fraccion de dano por tick de laser continuo."})
    AddNumber("Balance", "DISCRETE_BEAM_DMG_MULT", "Dano beam discreto", 0.3, 1.5, 0.05,
      {"Fraccion de dano por click/toque de disparo."})
    AddNumber("Balance", "SHIELD_REFLECT_BASE", "Escudo: reflect base", 0, 1, 0.05,
      {"Probabilidad base de reflejar proyectiles enemigos con el escudo.",
       "La Suerte del personaje suma +0.05 adicional por punto."})
    AddNumber("Balance", "TAINTED_DMG_MULTIPLIER", "Tainted multiplicador dano", 1, 2, 0.05,
      {"Multiplicador de dano base de Tainted Hal / Parallax."})
    AddNumber("Balance", "TAINTED_FEAR_CHANCE", "Tainted probabilidad miedo", 0, 1, 0.05,
      {"Probabilidad de aplicar Fear con disparos de Tainted."})
    AddNumber("Balance", "SPARK_PER_KILL", "Sparks por emblema", 1, 25, 1,
      {"Medidor ganado por recoger un emblema esmeralda del suelo."})
    AddNumber("Balance", "SPARK_DECAY_PER_SEC", "Decaimiento sparks/s", 0, 10, 0.5,
      {"Perdida del medidor de Parallax fuera de combate."})
    AddBool("Balance", "FEAR_VULN_ENABLED", "Depredador del miedo",
      {"+25% de dano continuo contra enemigos bajo efecto de Fear."})
  end)
end
