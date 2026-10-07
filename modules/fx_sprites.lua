-- modules/fx_sprites.lua -- RSI: HUD font + EID/inspection + caches de sprites GL. Sin callbacks, sin globals, todo via Core.
return function(Core)
    local hudFont = nil
    function Core.GetHudFont()
        if not hudFont and Font then
            local f = Font()
            local ok = pcall(function() f:Load("font/luaminioutlined.fnt") end)
            if ok and f:IsLoaded() then
                hudFont = f
            end
        end
        return hudFont
    end

    function Core.DrawHudText(text, x, y, r, g, b, a)
        local f = Core.GetHudFont()
        if f and KColor then
            f:DrawStringScaled(text, x, y, 1.0, 1.0, KColor(r, g, b, a), 0, false)
        else
            Isaac.RenderScaledText(text, x, y, 0.5, 0.5, r, g, b, a)
        end
    end

    local eidRegistered = false
    function Core.EnsureEIDRegistered()
        if eidRegistered or not EID then return end
        Core.LoadItemIDs()
        if not Core.ITEM_POWER_BATTERY or Core.ITEM_POWER_BATTERY < 0 then return end
        pcall(function()
            -- Official community mod indicator badge
            if EID.setModIndicatorName then
                EID:setModIndicatorName("Green Lantern")
            end
            if EID.setModIndicatorIcon then
                pcall(function() EID:setModIndicatorIcon("Battery") end)
            end

            -- English (en_us, en_us_detailed)
            for _, lang in ipairs({"en_us", "en_us_detailed"}) do
                EID:addCollectible(Core.ITEM_POWER_BATTERY,
                    "Active (4 charges)#Refills Willpower to 100% and emits a close-range emerald pulse#At >=50% Willpower: Overcharge (+15% DMG, Piercing & Spectral for the room)#Below 50%: Restores Willpower & reboots Ring from offline state#{{Collectible356}} Car Battery: Triggers instant Overcharge Tier 2 (+25% DMG) with 2.6x pulse radius",
                    "Power Battery", lang)
                EID:addCollectible(Core.ITEM_GIANT_FIST,
                    "Active (4 charges)#Fires a massive spectral piercing emerald construct fist#Deals 10x Player Damage and smashes rocks, poop & obstacles in its path#{{Collectible356}} Car Battery: Fires dual parallel giant fists to punch a wide path",
                    "Giant Fist", lang)
                EID:addCollectible(Core.ITEM_COAST_CITY,
                    "Active (4 charges)#Inflicts Fear (3s) and spawns a 5s Emerald Vortex pulling enemies to the center#Collecting Green Lantern Emblems recharges 25% and extends vortex duration#{{Collectible356}} Car Battery: +2s vortex duration and 1.5x gravitational suction pull",
                    "The Tragedy of Coast City", lang)
                if Core.ITEM_GATLING and Core.ITEM_GATLING > 0 then
                    EID:addCollectible(Core.ITEM_GATLING,
                        "Active (4 charges)#Activates a 10s emerald construct machine gun#Hal Jordan: Rapid-fire discrete emerald beams with 0 Willpower cost#Other Characters: Maximum fire rate (delay 2) firing piercing & spectral emerald construct bullets#{{Collectible356}} Car Battery: Extends machine gun duration from 10s to 15s",
                        "Gatling", lang)
                end
                EID:addCollectible(Core.ITEM_SOLID_LIGHT_SHIELD,
                    "Passive#+2 Soul Hearts#Grants an orbital light shield that blocks enemy projectiles#25% to 75% chance (scales with Luck) to reflect blocked shots as spectral emerald energy beams",
                    "Solid Light Shield", lang)
                if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 then
                    EID:addCollectible(Core.ITEM_POWER_RING,
                        "Passive#Grants flight & transforms tears into Hard-Light emerald energy#Tap/Click: High-damage piercing & spectral emerald bolts#Hold Fire: Channels a continuous emerald laser beam",
                        "Green Lantern Ring", lang)
                end
                if Core.TRINKET_YELLOW_IMPURITY and Core.TRINKET_YELLOW_IMPURITY > 0 then
                    EID:addTrinket(Core.TRINKET_YELLOW_IMPURITY,
                        "Trinket#1.5x Damage multiplier (+50% DMG)#Taking contact or explosion damage inflicts 2s Fear (inverted movement controls)",
                        "Yellow Impurity", lang)
                end
            end

            -- Spanish (es)
            EID:addCollectible(Core.ITEM_POWER_BATTERY,
                "Activo (4 cargas)#Recarga la Voluntad al 100% y emite un pulso esmeralda a corto alcance#Con >=50% Voluntad: Sobrecarga (+15% Daño, Disparos Perforantes y Espectrales en la sala)#Bajo 50%: Reinicia el anillo si estaba agotado#{{Collectible356}} Pila de coche: Activa Sobrecarga Nivel 2 (+25% Daño) al instante con onda expansiva 2.6x",
                "Batería de Poder", "es")
            EID:addCollectible(Core.ITEM_GIANT_FIST,
                "Activo (4 cargas)#Lanza un puño gigante de constructo perforante y espectral#Inflige x10 del Daño del jugador y destruye rocas, cacas y obstáculos#{{Collectible356}} Pila de coche: Lanza dos puños paralelos que barren un camino ancho",
                "Puño Gigante", "es")
            EID:addCollectible(Core.ITEM_COAST_CITY,
                "Activo (4 cargas)#Aplica Miedo (3s) a todos los enemigos de la sala#Invoca un Vórtice Esmeralda de 5s que absorbe enemigos al centro#Recoger emblemas de linterna alarga el vórtice y recarga un 25% del objeto#{{Collectible356}} Pila de coche: +2s de duración del vórtice y fuerza de succión x1.5",
                "La Tragedia de Coast City", "es")
            if Core.ITEM_GATLING and Core.ITEM_GATLING > 0 then
                EID:addCollectible(Core.ITEM_GATLING,
                    "Activo (4 cargas)#Invoca una ametralladora de constructo durante 10 segundos#Hal Jordan: Disparos de energía rápidos sin coste de Voluntad#Otros Personajes: Cadencia máxima (delay 2) con balas esmeralda perforantes y espectrales#{{Collectible356}} Pila de coche: Extiende la duración de la ametralladora de 10s a 15s",
                    "Ametralladora Gatling", "es")
            end
            EID:addCollectible(Core.ITEM_SOLID_LIGHT_SHIELD,
                "Pasivo#+2 Corazones de Alma#Otorga un escudo orbital de constructo que bloquea proyectiles enemigos#25% a 75% de probabilidad (escala con Suerte) de reflejar disparos como rayos esmeralda espectrales",
                "Escudo de Luz Sólida", "es")
            if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 then
                EID:addCollectible(Core.ITEM_POWER_RING,
                    "Pasivo#Otorga vuelo y transforma los disparos en energía esmeralda de luz sólida#Click/Toque: Disparos perforantes y espectrales de alto daño#Mantener presionado: Canaliza un rayo láser continuo",
                    "Anillo de Linterna Verde", "es")
            end
            if Core.TRINKET_YELLOW_IMPURITY and Core.TRINKET_YELLOW_IMPURITY > 0 then
                EID:addTrinket(Core.TRINKET_YELLOW_IMPURITY,
                    "Trinket#Multiplicador de daño x1.5 (+50% Daño)#Recibir daño por contacto o explosión causa Miedo temporal (invierte los controles durante 2s)",
                    "Impureza Amarilla", "es")
            end

            -- Native EID synergy registration hook if supported
            if EID.addSynergy then
                pcall(function()
                    EID:addSynergy(Core.ITEM_POWER_BATTERY, 356, "Instant Overcharge Tier 2 (+25% DMG) with 2.6x pulse", "Car Battery")
                    EID:addSynergy(Core.ITEM_GIANT_FIST, 356, "Fires dual parallel giant fists", "Car Battery")
                    EID:addSynergy(Core.ITEM_COAST_CITY, 356, "+2s vortex duration and 1.5x suction pull", "Car Battery")
                    if Core.ITEM_GATLING and Core.ITEM_GATLING > 0 then
                        EID:addSynergy(Core.ITEM_GATLING, 356, "Extends machine gun duration from 10s to 15s", "Car Battery")
                    end
                end)
            end

            -- Birthright Registrations
            if EID.addBirthright then
                if Core.PLAYER_HAL and Core.PLAYER_HAL >= 0 then
                    for _, lang in ipairs({"en_us", "en_us_detailed"}) do
                        EID:addBirthright(Core.PLAYER_HAL,
                            "Willpower capacity increased to 150%#Continuous beam width +30% & damage +42%#Permanent Overcharge (+15%/+25% DMG) while above 100% Willpower",
                            "Hal Jordan", lang)
                    end
                    EID:addBirthright(Core.PLAYER_HAL,
                        "Capacidad de Voluntad aumentada al 150%#Anchura del rayo +30% y daño +42%#Sobrecarga permanente (+15%/+25% Daño) al superar el 100% de Voluntad",
                        "Hal Jordan", "es")
                end
                if Core.PLAYER_TAINTED_HAL and Core.PLAYER_TAINTED_HAL >= 0 then
                    for _, lang in ipairs({"en_us", "en_us_detailed"}) do
                        EID:addBirthright(Core.PLAYER_TAINTED_HAL,
                            "Max Stolen Rings cap increased to 15#Emits an emerald fear wave on hostile room entry#Damage multiplier against Feared enemies increased to +50%",
                            "Parallax", lang)
                    end
                    EID:addBirthright(Core.PLAYER_TAINTED_HAL,
                        "Límite de Anillos Robados aumentado a 15#Emite una onda esmeralda de miedo al entrar a salas hostiles#Multiplicador de daño contra enemigos asustados aumentado al +50%",
                        "Parallax", "es")
                end
            end

            eidRegistered = true
        end)
    end

    function Core.GetModItemInspectionInfo(isTrinket, id)
        if not Core.ITEM_POWER_BATTERY or Core.ITEM_POWER_BATTERY < 0 then Core.LoadItemIDs() end
        if not isTrinket then
            if id == Core.ITEM_POWER_BATTERY then
                return "Power Battery [4R Active]", {
                    "Refills 100% Willpower + close emerald pulse",
                    ">=50% Will: +15% Overcharge DMG for room",
                    "[Car Battery]: Instant Tier 2 Overcharge (+25% DMG)"
                }
            elseif id == Core.ITEM_GIANT_FIST then
                return "Giant Fist [4R Active]", {
                    "Fires a giant piercing 10x DMG emerald fist",
                    "Smashes rocks, poop, and obstacles in its path",
                    "[Car Battery]: Fires dual parallel giant fists"
                }
            elseif id == Core.ITEM_GATLING then
                return "Gatling [4R Active]", {
                    "10s emerald construct machine gun barrage",
                    "Hal: 0 Willpower cost | Others: Max fire rate",
                    "[Car Battery]: Extends barrage from 10s to 15s"
                }
            elseif id == Core.ITEM_COAST_CITY then
                return "The Tragedy of Coast City [4R Active]", {
                    "Fears enemies & pulls them into a 5s vortex",
                    "Lantern Emblems recharge & extend the vortex",
                    "[Car Battery]: +2s vortex duration & 1.5x suction"
                }
            elseif id == Core.ITEM_SOLID_LIGHT_SHIELD then
                return "Solid Light Shield [Passive]", {
                    "+2 Soul Hearts & orbital light shield",
                    "25%-75% chance (Luck) to reflect enemy shots"
                }
            elseif id == Core.ITEM_POWER_RING then
                return "Green Lantern Ring [Starting Passive]", {
                    "Click: high-DMG small beams | Hold: continuous beam",
                    "Piercing & spectral emerald energy from your ring"
                }
            end
        else
            if id == Core.TRINKET_YELLOW_IMPURITY then
                return "Yellow Impurity [Trinket]", {
                    "1.5x Damage Multiplier (+50% Damage Up)",
                    "Contact/explosion hits cause 2s Fear reversal"
                }
            end
        end
        return nil, nil
    end

    local glAuraSprite             = nil
    local glFlareSprite            = nil
    local glSparkSprite            = nil
    local glBatteryOrbitalSparkSprite = nil -- dedicated to Power Battery construct orbital
    local glContBeamSprite         = nil
    local glSolidShieldOrbitalSprite = nil  -- dedicated to "Orbit"/"Deflect" animations
    local glSolidShieldAuraSprite    = nil  -- dedicated to "Aura" animation
    local glBatteryConstructSprite = nil
    local glYellowFearSprite       = nil

    function Core.GetGLAuraSprites()
        if not glAuraSprite and Sprite then
            local s1 = Sprite()
            local ok1 = pcall(function()
                s1:Load("gfx/effects/gl_aura.anm2", true)
                s1:Play("HalAura", true)
            end)
            if ok1 then
                glAuraSprite = s1
            end
        end
        if not glFlareSprite and Sprite then
            local s2 = Sprite()
            local ok2 = pcall(function()
                s2:Load("gfx/effects/gl_aura.anm2", true)
                s2:Play("RingFlare", true)
            end)
            if ok2 then
                glFlareSprite = s2
            end
        end
        return glAuraSprite, glFlareSprite
    end

    function Core.GetGLContBeamSprite()
        if not glContBeamSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_ring_beam.anm2", true)
                s:Play("ContinuousBeam", true)
            end)
            if ok then
                glContBeamSprite = s
            end
        end
        return glContBeamSprite
    end

    function Core.GetGLSparkSprite()
        if not glSparkSprite and Sprite then
            local s3 = Sprite()
            local ok3 = pcall(function()
                s3:Load("gfx/effects/gl_lantern_spark.anm2", true)
                s3:Play("Idle", true)
            end)
            if ok3 then
                glSparkSprite = s3
            end
        end
        return glSparkSprite
    end

    function Core.GetGLBatteryOrbitalSparkSprite()
        if not glBatteryOrbitalSparkSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_lantern_spark.anm2", true)
                s:Play("Idle", true)
            end)
            if ok then
                glBatteryOrbitalSparkSprite = s
            end
        end
        return glBatteryOrbitalSparkSprite
    end

    -- Two separate sprite instances for the shield so the aura and the orbital
    -- never fight over animation state within the same render frame.
    function Core.GetGLSolidShieldOrbitalSprite()
        if not glSolidShieldOrbitalSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_solid_shield.anm2", true)
                s:Play("Orbit", true)
            end)
            if ok then
                glSolidShieldOrbitalSprite = s
            end
        end
        return glSolidShieldOrbitalSprite
    end

    function Core.GetGLSolidShieldAuraSprite()
        if not glSolidShieldAuraSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_solid_shield.anm2", true)
                s:Play("Aura", true)
            end)
            if ok then
                glSolidShieldAuraSprite = s
            end
        end
        return glSolidShieldAuraSprite
    end

    -- Legacy alias: some old code paths may call GetGLSolidShieldSprite().
    -- Route them to the orbital sprite to avoid nil errors.
    function Core.GetGLSolidShieldSprite()
        return Core.GetGLSolidShieldOrbitalSprite()
    end

    function Core.GetGLBatteryConstructSprite()
        if not glBatteryConstructSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_power_battery_construct.anm2", true)
                s:Play("Pulse", true)
            end)
            if ok then
                glBatteryConstructSprite = s
            end
        end
        return glBatteryConstructSprite
    end

    function Core.GetGLYellowFearSprite()
        if not glYellowFearSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_yellow_fear.anm2", true)
                s:Play("FearSkull", true)
            end)
            if ok then
                glYellowFearSprite = s
            end
        end
        return glYellowFearSprite
    end

    -- T6: swap the tear's sprite for the custom Giant Fist anm2 so the construct
    -- looks like a giant emerald fist instead of a tinted tooth. Caller is
    -- modules/item_fist.lua (right after spawn). Hardcodes the only allowed path.
    function Core.ApplyGiantFistSprite(tear)
        if not tear then return end
        pcall(function()
            local ts = tear:GetSprite()
            ts:Load("gfx/effects/gl_giant_fist.anm2", true)
            ts:Play("Idle", true)
            local vel = tear.Velocity
            local speed = (vel and vel:Length()) or 0.0
            ts.Rotation = (speed > 0.01) and vel:GetAngleDegrees() or 0.0
            local td = tear:GetData()
            td.isGLFist = true
        end)
    end
end
