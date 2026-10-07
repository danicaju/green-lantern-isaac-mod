-- modules/birthright.lua -- RSI: mecanicas de Birthright (Hal Jordan & Parallax).
-- Hal Jordan ("In Brightest Day"): Cap 150% Willpower, haz continuo +35% ancho & +42% dano,
-- Sobrecarga permanente al superar 100% de Willpower.
-- Parallax ("In Blackest Night"): Cap 15 anillos robados, onda de miedo al entrar a sala hostil,
-- dano x1.50 contra enemigos con Fear.
return function(Core)
    local GL = Core.GL

    Core.BIRTHRIGHT_ENABLED             = true
    Core.WILLPOWER_MAX_BIRTHRIGHT       = 150.0
    Core.MAX_STOLEN_RINGS_BIRTHRIGHT    = 15

    -- Helper de predicado: comprueba si el jugador posee Birthright
    function Core.HasBirthright(player)
        if Core.BIRTHRIGHT_ENABLED == false then return false end
        if not player or not player.HasCollectible then return false end
        local brId = (CollectibleType and CollectibleType.COLLECTIBLE_BIRTHRIGHT) or 619
        return player:HasCollectible(brId)
    end

    -- Resolucion de maximos dinamicos segun Birthright
    function Core.GetMaxWillpower(player)
        if Core.HasBirthright(player) and Core.IsHalJordan(player) then
            return Core.WILLPOWER_MAX_BIRTHRIGHT or 150.0
        end
        return Core.WILLPOWER_MAX or 100.0
    end

    function Core.GetMaxStolenRings(player)
        if Core.HasBirthright(player) and Core.IsTaintedHal(player) then
            return Core.MAX_STOLEN_RINGS_BIRTHRIGHT or 15
        end
        return Core.MAX_STOLEN_RINGS or 10
    end

    -- 1. DETECCION DE RECOGIDA DE BIRTHRIGHT: juramento, efectos y animacion
    GL:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
        if not (Core.IsHalJordan(player) or Core.IsTaintedHal(player)) then return end
        local data = Core.GetPlayerData(player)
        local hasBR = Core.HasBirthright(player)

        if hasBR and not data.birthrightInitialized then
            data.birthrightInitialized = true

            if Core.IsHalJordan(player) then
                data.oathText      = "IN BRIGHTEST DAY!"
                data.oathTextTimer = 95
                -- Relleno inmediato del nuevo cupo de Voluntad (150%)
                data.willpower     = Core.WILLPOWER_MAX_BIRTHRIGHT
                data.ringDepleted  = false
                data.overcharge    = true
                data.overchargeTier = 2

                pcall(function()
                    player:AnimateHappy()
                    local sfx = (SoundEffect and SoundEffect.SOUND_HOLY) or 0
                    if sfx > 0 then SFXManager():Play(sfx, 0.90, 0, false, 1.15) end
                    local halo = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HALO, 0, player.Position, Vector.Zero, player)
                    if halo then
                        halo:GetSprite().Color = Color(0.15, 1.0, 0.35, 0.95, 0.1, 0.8, 0.2)
                        halo.Scale = 2.0
                    end
                end)

                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
                player:EvaluateItems()
            elseif Core.IsTaintedHal(player) then
                data.oathText      = "IN BLACKEST NIGHT!"
                data.oathTextTimer = 95

                pcall(function()
                    player:AnimateHappy()
                    local sfx = (SoundEffect and (SoundEffect.SOUND_DEATH_CARD or SoundEffect.SOUND_FEAR)) or 0
                    if sfx > 0 then SFXManager():Play(sfx, 0.90, 0, false, 0.95) end
                    local shock = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HALO, 0, player.Position, Vector.Zero, player)
                    if shock then
                        shock:GetSprite().Color = Color(0.10, 0.9, 0.25, 0.95, 0.05, 0.6, 0.1)
                        shock.Scale = 2.4
                    end
                end)

                -- Onda inmediata de miedo a la sala
                Core.EmitParallaxFearWave(player)
                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                player:EvaluateItems()
            end
        elseif not hasBR and data.birthrightInitialized then
            -- Si se retira Birthright (D4, Genesis, etc.)
            data.birthrightInitialized = false
            if Core.IsHalJordan(player) and (data.willpower or 0) > Core.WILLPOWER_MAX then
                data.willpower = Core.WILLPOWER_MAX
            end
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
            player:EvaluateItems()
        end

        -- Mantenimiento pasivo de Hal con Birthright:
        -- Si esta por encima de 100% de Willpower, mantiene Sobrecarga Tier 1 o Tier 2 permanentemente
        if Core.IsHalJordan(player) and hasBR and not data.ringDepleted then
            local will = data.willpower or 0
            if will >= 135.0 then
                if not (data.overcharge and data.overchargeTier == 2) then
                    data.overcharge = true
                    data.overchargeTier = 2
                    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                    player:EvaluateItems()
                end
            elseif will >= 100.0 then
                if not (data.overcharge and data.overchargeTier == 1) then
                    data.overcharge = true
                    data.overchargeTier = 1
                    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                    player:EvaluateItems()
                end
            end
        end
    end)

    -- 2. ONDA DE MIEDO DE PARALLAX AL ENTRAR A UNA SALA HOSTIL
    function Core.EmitParallaxFearWave(player)
        if not player then return end
        local room = Game():GetRoom()
        local enemyCount = 0
        for _, ent in ipairs(Isaac.GetRoomEntities()) do
            if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
                enemyCount = enemyCount + 1
                pcall(function()
                    ent:AddFear(EntityRef(player), 120)
                    ent:AddEntityFlags(EntityFlag.FLAG_FEAR)
                end)
            end
        end

        if enemyCount > 0 then
            pcall(function()
                local sfx = (SoundEffect and (SoundEffect.SOUND_FEAR or SoundEffect.SOUND_HELL_PORTAL1)) or 0
                if sfx > 0 then SFXManager():Play(sfx, 0.70, 0, false, 1.1) end
                local wave = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RIPPLE_POOF, 0, player.Position, Vector.Zero, player)
                if wave then
                    wave:GetSprite().Color = Color(0.12, 1.0, 0.35, 0.85, 0.1, 0.7, 0.15)
                    wave.Scale = 1.5
                end
            end)
        end
    end

    GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
        for i = 0, Game():GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(i)
            if Core.IsTaintedHal(player) and Core.HasBirthright(player) then
                Core.EmitParallaxFearWave(player)
            end
        end
    end)
end
