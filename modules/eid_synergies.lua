-- modules/eid_synergies.lua -- RSI: EID bilingual synergy descriptions for Green Lantern construct items.
-- Responsabilidad unica: Registrar tooltips bilingues (en/es) para sinergias de constructos de luz solida en EID.

return function(Core)
    local SynergyDescriptions = {
        [3]   = { en = "Infuses construct bolts with powerful emerald magnetic homing resonance", es = "Imbuye los proyectiles de constructo con una potente resonancia magnetica teledirigida" },
        [49]  = { en = "Projects a giant emerald hand construct laser beam (+30% damage)", es = "Proyecta un rayo laser desde un canon de mano gigante de constructo (+30% dano)" },
        [52]  = { en = "Fires emerald construct energy bombs that detonate with hard-light shockwaves", es = "Lanza bombas de energia de constructo esmeralda que detonan con ondas expansivas" },
        [68]  = { en = "Converts attacks into a high-powered continuous emerald laser beam (+30% DMG)", es = "Convierte los ataques en un rayo laser esmeralda concentrado (+30% dano)" },
        [114] = { en = "Yields a Hard-Light Emerald Energy Dagger with emerald glow aura (+25% DMG)", es = "Blande una Daga de Energia Esmeralda de luz solida con aura radiante (+25% dano)" },
        [118] = { en = "Replaces continuous beam with a massive emerald laser (+25% DMG, spectral & piercing)", es = "Reemplaza el rayo continuo por un haz masivo de luz solida (+25% dano, espectral y perforante)" },
        [149] = { en = "Fires a secondary continuous emerald construct laser alongside regular attacks", es = "Dispara un laser continuo secundario de constructo esmeralda junto a tus ataques" },
        [168] = { en = "Calls down an orbital emerald construct strike from the sky on target location", es = "Invoca un ataque orbital de constructo esmeralda desde el cielo en el punto marcado" },
        [182] = { en = "Massive damage multiplier (+130% DMG) and emerald homing guidance", es = "Multiplicador masivo de dano (+130% dano) y guiado magnetico esmeralda" },
        [210] = { en = "Standing still manifests a hard-light emerald crystal statue with energy aura", es = "Quedarse quieto invoca una estatua de cristal esmeralda de luz solida con aura protectora" },
        [220] = { en = "Bomb explosions unleash 10 radial emerald construct burst beams dealing 80% DMG", es = "Las bombas detonan 10 rayos radiales de constructo esmeralda que infligen 80% de dano" },
        [222] = { en = "Construct bolts float in place as glowing nodes, launching when releasing fire", es = "Los disparos flotan como nodos de energia suspendidos y se lanzan al soltar el boton" },
        [244] = { en = "Spontaneously fires piercing emerald construct lasers while attacking", es = "Dispara rayos laser esmeralda perforantes de forma espontanea mientras atacas" },
        [257] = { en = "Inflicts emerald plasma burns with a chance to trigger a 2x DMG plasma explosion", es = "Aplica quemadura de plasma esmeralda, con probabilidad de explosion esmeralda (x2 dano)" },
        [293] = { en = "Fires a 4-way cross of colossal emerald construct beams (+30% damage)", es = "Dispara una cruz de 4 colosales rayos de constructo esmeralda (+30% dano)" },
        [331] = { en = "Surrounds construct bolts with an expansive radiant emerald aura (+20% DMG)", es = "Rodea los disparos de constructo con una expansiva aura esmeralda radiante (+20% dano)" },
        [366] = { en = "Construct bombs split into 3-5 mini cluster construct bombs on explosion", es = "Las bombas de luz solida se dividen en 3-5 minibombas de constructo al detonar" },
        [369] = { en = "Emerald construct bolts wrap around room screen edges, looping through borders", es = "Los proyectiles de constructo atraviesan los bordes de la sala y reaparecen por el lado opuesto" },
        [374] = { en = "Attacks have a chance to call down radiant emerald orbital laser pillars dealing 4x DMG", es = "Probabilidad de invocar pilares laser orbitales de luz solida que infligen x4 de dano" },
        [395] = { en = "Fires expanding blazing emerald laser rings that pierce through enemies", es = "Dispara anillos laser esmeralda expansivos que perforan enemigos" },
        [397] = { en = "Focuses all construct attacks into an emerald guidance beam with perfect accuracy", es = "Concentra todos los ataques de constructo en un rayo guia esmeralda con precision total" },
        [400] = { en = "On-hit chance to attach a swelling emerald plasma bubble that detonates for 2.2x DMG", es = "Probabilidad de adherir una burbuja de plasma esmeralda que detona por x2.2 de dano" },
        [408] = { en = "On-hit chance to summon a Giant Construct Fist crashing from above for 4x DMG", es = "Probabilidad de invocar un Puno Gigante de Constructo que cae aplastando por x4 de dano" },
        [441] = { en = "Transforms into a Colossal Emerald Mega Laser Cannon construct (+35% damage)", es = "Invoca un Canon Mega Laser de Constructo Esmeralda colosal (+35% dano)" },
        [462] = { en = "Piercing bolts erupt into empowered demonic construct bolts (+35% size, 2x DMG)", es = "Los disparos perforantes se transforman en proyectiles demoniacos (+35% tamano, x2 dano)" },
        [494] = { en = "Construct attacks emit emerald hard-light spark arcs between enemies (+20% DMG)", es = "Los ataques de constructo emiten arcos de chispas de luz solida esmeralda (+20% dano)" },
        [499] = { en = "Defeating enemies erupts them into 10 radial emerald needle construct shards", es = "Eliminar enemigos provoca una supernova de 10 agujas de constructo perforantes en 360 grados" },
        [502] = { en = "Arcs of emerald construct electricity link attacks and enemies (+20% damage)", es = "Rayos de electricidad esmeralda conectan los ataques y enemigos (+20% de dano)" },
        [507] = { en = "Attaches sticky emerald construct tracking tags that deal continuous poison damage", es = "Adhiere marcas de rastreo de constructo esmeralda que danan por veneno continuo" },
        [509] = { en = "Ring hits shatter into 3 piercing emerald bone construct splinters dealing 50% DMG", es = "Los impactos se fragmentan en 3 esquirlas oseas de constructo perforantes (50% dano)" },
        [527] = { en = "Bouncing construct bolts trigger emerald shockwaves along the floor on every bounce", es = "Los disparos rebotan en el suelo emitiendo ondas de choque de luz solida en cada bote" },
        [533] = { en = "Ring attacks become piercing emerald wave construct beams dealing +25% DMG", es = "Los disparos se convierten en ondas de energia esmeralda perforantes (+25% dano)" },
        [540] = { en = "Projects an Emerald Aegis Dome forcefield upon entering any boss room", es = "Proyecta una Cupula Egida esmeralda protectora al entrar a cualquier sala de jefe" },
        [577] = { en = "On-hit chance to manifest a Giant Boxing Glove Construct (2.5x DMG, knockback & confusion)", es = "Probabilidad de invocar un Puno de Boxeo de Constructo (x2.5 dano, retroceso y confusion)" },
        [578] = { en = "On-hit chance to open an emerald singularity rift that pulls in enemies and tears", es = "Probabilidad de abrir una singularidad esmeralda que absorbe enemigos y proyectiles" },
        [582] = { en = "Freezes enemies into emerald cryo-constructs that shatter into hard-light ice shards", es = "Congela enemigos en constructos de hielo esmeralda que se fragmentan en esquirlas al morir" },
        [583] = { en = "Replaces attacks with an Emerald Hard-Light Energy Greatsword and spin slash", es = "Reemplaza el ataque por un Mandoble de Luz Solida esmeralda con ataque giratorio" },
        [593] = { en = "Attacks break rocks and obstacles, triggering emerald ground shockwaves on impact", es = "Los disparos rompen rocas y obstaculos, creando ondas de choque esmeralda en el suelo" },
        [597] = { en = "Charging releases a rapid-fire torrent of piercing emerald construct bolts", es = "Cargar el ataque libera una rafaga torrencial de disparos esmeralda perforantes" },
        [601] = { en = "Grants full controllable steering to all emerald construct bolts with +10% DMG", es = "Permite teledirigir con precision todos los disparos de constructo con +10% de dano" },
        [606] = { en = "Grants a planetary construct ring that captures enemy tears into orbiting shields", es = "Crea un anillo de constructo orbital que absorbe disparos enemigos y los usa como escudo" },
        [618] = { en = "Attaches emerald spore clusters that burst into piercing hard-light spores on defeat", es = "Adhiere esporas de constructo esmeralda que estallan en esquirlas al morir el enemigo" },
        [643] = { en = "Grants construct angel wings and charges a divine emerald willpower beam (+25% DMG)", es = "Otorga alas de angel de luz solida y carga un rayo de voluntad divino (+25% dano)" },
        [678] = { en = "Fires levitating ring-construct fetuses that channel continuous emerald laser beams", es = "Dispara bebes de constructo que levitan y canalizan rayos laser esmeralda continuos" },
    }

    Core.EIDSynergyDescriptions = SynergyDescriptions

    function Core.GetSynergyDescription(collectibleId, isSpanish)
        local entry = SynergyDescriptions[collectibleId]
        if not entry then return nil end
        return isSpanish and entry.es or entry.en
    end

    local function IsSpanishLanguage()
        if EID then
            if EID.getLanguage and type(EID.getLanguage) == "function" then
                local l = tostring(EID:getLanguage() or ""):lower()
                if l:sub(1, 2) == "es" or l == "spa" then return true end
            end
            if EID.Config and EID.Config["Language"] then
                local l = tostring(EID.Config["Language"]):lower()
                if l:sub(1, 2) == "es" or l == "spa" then return true end
            end
            if EID.UserLocal then
                local l = tostring(EID.UserLocal):lower()
                if l:sub(1, 2) == "es" or l == "spa" then return true end
            end
        end
        if Options and Options.Language then
            local l = tostring(Options.Language):lower()
            if l:sub(1, 2) == "es" or l == "spa" then return true end
        end
        return false
    end

    local function IsGreenLanternPlayerPresent()
        if not (Game and Isaac and Isaac.GetPlayer) then return false end
        local num = Game():GetNumPlayers()
        for i = 0, num - 1 do
            local p = Isaac.GetPlayer(i)
            if p and (Core.IsHalJordan(p) or Core.IsTaintedHal(p) or (Core.ITEM_POWER_RING and p.HasCollectible and p:HasCollectible(Core.ITEM_POWER_RING))) then
                return true
            end
        end
        return false
    end

    local registered = false
    function Core.EnsureEIDSynergiesRegistered()
        if registered or not EID then return end
        Core.LoadItemIDs()

        -- 1. In-game item pedestal description modifier
        if EID.addDescriptionModifier then
            local function cond(descObj)
                if not descObj or descObj.ObjType ~= 5 or descObj.ObjVariant ~= 100 then return false end
                if not SynergyDescriptions[descObj.ObjSubType] then return false end
                return IsGreenLanternPlayerPresent()
            end
            local function cb(descObj)
                local entry = SynergyDescriptions[descObj.ObjSubType]
                if entry then
                    local isEs = IsSpanishLanguage()
                    local text = isEs and entry.es or entry.en
                    local ringIcon = (Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0) and ("{{Collectible" .. Core.ITEM_POWER_RING .. "}} ") or "{{ColorGreen}}"
                    local tag = isEs and "{{ColorGreen}}Sinergia Linterna Verde: " or "{{ColorGreen}}Green Lantern Synergy: "
                    local appendStr = "#" .. ringIcon .. tag .. "{{CR}}" .. text
                    if EID.appendToDescription then
                        EID:appendToDescription(descObj, appendStr)
                    else
                        descObj.Description = (descObj.Description or "") .. appendStr
                    end
                end
                return descObj
            end
            EID:addDescriptionModifier("GL_Item_Synergies", cond, cb)
        end

        -- 2. Register native EID synergies with Green Lantern Ring
        if EID.addSynergy and Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 then
            pcall(function()
                for id, entry in pairs(SynergyDescriptions) do
                    EID:addSynergy(id, Core.ITEM_POWER_RING, entry.en, "Green Lantern Ring", "en_us")
                    EID:addSynergy(id, Core.ITEM_POWER_RING, entry.en, "Green Lantern Ring", "en_us_detailed")
                    EID:addSynergy(id, Core.ITEM_POWER_RING, entry.es, "Anillo de Linterna Verde", "es")
                end
            end)
        end

        -- 3. Register character synergies for Hal Jordan & Tainted Hal
        if EID.addCharacterSynergy then
            pcall(function()
                if Core.PLAYER_HAL and Core.PLAYER_HAL >= 0 then
                    for id, entry in pairs(SynergyDescriptions) do
                        EID:addCharacterSynergy(Core.PLAYER_HAL, id, entry.en, "Hal Jordan", "en_us")
                        EID:addCharacterSynergy(Core.PLAYER_HAL, id, entry.es, "Hal Jordan", "es")
                    end
                end
                if Core.PLAYER_TAINTED_HAL and Core.PLAYER_TAINTED_HAL >= 0 then
                    for id, entry in pairs(SynergyDescriptions) do
                        EID:addCharacterSynergy(Core.PLAYER_TAINTED_HAL, id, entry.en, "Parallax", "en_us")
                        EID:addCharacterSynergy(Core.PLAYER_TAINTED_HAL, id, entry.es, "Parallax", "es")
                    end
                end
            end)
        end

        registered = true
    end
end
