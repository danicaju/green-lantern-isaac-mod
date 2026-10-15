-- modules/challenges.lua -- RSI: gestion de desafios tematicos DC Comics.
-- Responsabilidad unica: inicializar personajes, equipamiento y mecanicas exclusivas de desafios:
-- 1. In Brightest Day (Maestria de Constructos a Ciegas)
-- 2. Emerald Twilight (La Caida de Hal Jordan hacia Sheol)
-- 3. Blackest Night (La Noche mas Oscura y los Muertos Vivientes)
-- 4. Sinestro Corps War (Guerra de la Luz y el Miedo)

return function(Core)
    local GL = Core.GL

    local function GetChallengeIds()
        local getId = Isaac.GetChallengeIdByName
        if not getId then return -1, -1, -1, -1 end
        return getId("In Brightest Day") or -1,
               getId("Emerald Twilight") or -1,
               getId("Blackest Night") or -1,
               getId("Sinestro Corps War") or -1
    end

    -- 1. INICIALIZACION DE DESAFIO (MC_POST_GAME_STARTED)
    GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
        if isContinued then return end

        local challengeId = (Isaac.GetChallenge and Isaac.GetChallenge()) or 0
        if challengeId <= 0 then return end

        if Core.LoadItemIDs then Core.LoadItemIDs() end
        local chalBrightest, chalTwilight, chalBlackest, chalSinestro = GetChallengeIds()

        for i = 0, Game():GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(i)
            if player then
                local data = (Core.GetPlayerData and Core.GetPlayerData(player)) or (player.GetData and player:GetData()) or {}

                if challengeId == chalBrightest then
                    -- Desafio 1: In Brightest Day (Blindfold Construct Master)
                    if Core.PLAYER_HAL and Core.PLAYER_HAL >= 0 and player:GetPlayerType() ~= Core.PLAYER_HAL then
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
                    if player.GetSoulHearts and player.AddSoulHearts and player:GetSoulHearts() < 4 then
                        player:AddSoulHearts(4 - player:GetSoulHearts())
                    end
                    data.oathTextTimer = 110
                    data.oathText = "IN BRIGHTEST DAY, IN BLACKEST NIGHT..."

                elseif challengeId == chalTwilight then
                    -- Desafio 2: Emerald Twilight (La caida de Hal Jordan)
                    if Core.PLAYER_HAL and Core.PLAYER_HAL >= 0 and player:GetPlayerType() ~= Core.PLAYER_HAL then
                        pcall(function() player:ChangePlayerType(Core.PLAYER_HAL) end)
                    end
                    if Core.ITEM_COAST_CITY and not player:HasCollectible(Core.ITEM_COAST_CITY) then
                        player:AddCollectible(Core.ITEM_COAST_CITY, 4, false)
                    end
                    local carBatteryId = (CollectibleType and CollectibleType.COLLECTIBLE_CAR_BATTERY) or 356
                    if not player:HasCollectible(carBatteryId) then
                        player:AddCollectible(carBatteryId, 0, false)
                    end
                    local nineVoltId = (CollectibleType and CollectibleType.COLLECTIBLE_9_VOLT) or 116
                    if not player:HasCollectible(nineVoltId) then
                        player:AddCollectible(nineVoltId, 0, false)
                    end
                    data.willpower = Core.WILLPOWER_MAX
                    data.stolenRings = 1
                    data.oathTextTimer = 110
                    data.oathText = "EMERALD TWILIGHT: RECLAIM THE LIGHT!"

                elseif challengeId == chalBlackest then
                    -- Desafio 3: Blackest Night (Tainted Hal / Muerte viviente)
                    if Core.PLAYER_TAINTED_HAL and Core.PLAYER_TAINTED_HAL >= 0 and player:GetPlayerType() ~= Core.PLAYER_TAINTED_HAL then
                        pcall(function() player:ChangePlayerType(Core.PLAYER_TAINTED_HAL) end)
                    end
                    if Core.ITEM_COAST_CITY and not player:HasCollectible(Core.ITEM_COAST_CITY) then
                        player:AddCollectible(Core.ITEM_COAST_CITY, 4, false)
                    end
                    if Core.TRINKET_YELLOW_IMPURITY and not player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY) then
                        player:AddTrinket(Core.TRINKET_YELLOW_IMPURITY)
                    end
                    local deadCatId = (CollectibleType and CollectibleType.COLLECTIBLE_DEAD_CAT) or 81
                    if not player:HasCollectible(deadCatId) then
                        player:AddCollectible(deadCatId, 0, false)
                    end
                    data.emeraldSparks = 50.0
                    data.oathTextTimer = 120
                    data.oathText = "THE BLACKEST NIGHT FALLS FROM THE SKIES..."

                elseif challengeId == chalSinestro then
                    -- Desafio 4: Sinestro Corps War (Guerra de Voluntad contra Miedo)
                    if Core.PLAYER_HAL and Core.PLAYER_HAL >= 0 and player:GetPlayerType() ~= Core.PLAYER_HAL then
                        pcall(function() player:ChangePlayerType(Core.PLAYER_HAL) end)
                    end
                    if Core.TRINKET_YELLOW_IMPURITY and not player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY) then
                        player:AddTrinket(Core.TRINKET_YELLOW_IMPURITY)
                    end
                    local birthrightId = (CollectibleType and CollectibleType.COLLECTIBLE_BIRTHRIGHT) or 619
                    if not player:HasCollectible(birthrightId) then
                        player:AddCollectible(birthrightId, 0, false)
                    end
                    if Core.ITEM_POWER_BATTERY and not player:HasCollectible(Core.ITEM_POWER_BATTERY) then
                        player:AddCollectible(Core.ITEM_POWER_BATTERY, 4, false)
                    end
                    data.oathTextTimer = 110
                    data.oathText = "NO EVIL SHALL ESCAPE MY SIGHT!"
                end
            end
        end
    end)

    -- 2. EFECTOS POR PISO (MC_POST_NEW_LEVEL)
    GL:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function(_)
        local challengeId = (Isaac.GetChallenge and Isaac.GetChallenge()) or 0
        if challengeId <= 0 then return end

        local chalBrightest, chalTwilight, chalBlackest, chalSinestro = GetChallengeIds()
        local level = Game():GetLevel()
        local stage = level and level:GetStage() or 1

        if challengeId == chalBlackest then
            -- Blackest Night: Niebla y oscuridad perpetuas
            if level and level.AddCurse then
                local curseDark = (LevelCurse and LevelCurse.CURSE_OF_DARKNESS) or 1
                local curseUnknown = (LevelCurse and LevelCurse.CURSE_OF_THE_UNKNOWN) or 8
                level:AddCurse(curseDark + curseUnknown, false)
            end

        elseif challengeId == chalTwilight then
            -- Emerald Twilight: Corrupcion progresiva hacia Parallax
            for i = 0, Game():GetNumPlayers() - 1 do
                local player = Isaac.GetPlayer(i)
                if player then
                    local data = (Core.GetPlayerData and Core.GetPlayerData(player)) or (player.GetData and player:GetData()) or {}
                    data.stolenRings = math.min(Core.MAX_STOLEN_RINGS or 10, (data.stolenRings or 0) + 2)
                    data.ringFlareTimer = 20

                    if stage >= 9 and Core.PLAYER_TAINTED_HAL and player:GetPlayerType() ~= Core.PLAYER_TAINTED_HAL then
                        pcall(function()
                            player:ChangePlayerType(Core.PLAYER_TAINTED_HAL)
                            data.oathTextTimer = 120
                            data.oathText = "OA IS FALLEN! I AM PARALLAX!"
                            if Core.PlayRingOverchargeChime then Core.PlayRingOverchargeChime(player) end
                        end)
                    end
                end
            end

        elseif challengeId == chalSinestro then
            -- Sinestro Corps War: Manto de oscuridad de la guerra de luz
            if level and level.AddCurse then
                local curseDark = (LevelCurse and LevelCurse.CURSE_OF_DARKNESS) or 1
                level:AddCurse(curseDark, false)
            end
        end
    end)

    -- 3. RECARGA DE CONSTRUCTOS AL LIMPIAR SALAS EN IN BRIGHTEST DAY
    GL:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, function(_)
        local challengeId = (Isaac.GetChallenge and Isaac.GetChallenge()) or 0
        if challengeId <= 0 then return end

        local chalBrightest = (Isaac.GetChallengeIdByName and Isaac.GetChallengeIdByName("In Brightest Day")) or -1
        if challengeId == chalBrightest then
            for i = 0, Game():GetNumPlayers() - 1 do
                local player = Isaac.GetPlayer(i)
                if player then
                    local data = (Core.GetPlayerData and Core.GetPlayerData(player)) or (player.GetData and player:GetData()) or {}
                    data.willpower = math.min(Core.WILLPOWER_MAX or 100, (data.willpower or 0) + 25.0)
                    data.ringFlareTimer = 12
                    -- Recarga +2 cargas de objetos activos de constructos
                    for slot = 0, 2 do
                        local item = (player.GetActiveItem and player:GetActiveItem(slot)) or 0
                        if item > 0 and player.NeedsCharge and player:NeedsCharge(slot) and player.SetActiveCharge then
                            local curCh = (player.GetActiveCharge and player:GetActiveCharge(slot)) or 0
                            player:SetActiveCharge(curCh + 2, slot)
                        end
                    end
                end
            end
        end
    end)

    -- 4. APARICION DE APARICIONES ESPECTRALES EN BLACKEST NIGHT
    GL:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, entity)
        local challengeId = (Isaac.GetChallenge and Isaac.GetChallenge()) or 0
        if challengeId <= 0 then return end

        local chalBlackest = (Isaac.GetChallengeIdByName and Isaac.GetChallengeIdByName("Blackest Night")) or -1
        if challengeId == chalBlackest and entity and entity.IsActiveEnemy and entity:IsActiveEnemy(false) and not (entity.IsBoss and entity:IsBoss()) then
            if math.random() < 0.28 then
                pcall(function()
                    local fxVar = (EffectVariant and EffectVariant.GHOST) or (EffectVariant and EffectVariant.SMOKE_CLOUD) or 10
                    local ghost = Isaac.Spawn(EntityType.ENTITY_EFFECT, fxVar, 0, entity.Position, Vector.Zero, nil)
                    if ghost and Core.SetEntityScaleAndColor then
                        Core.SetEntityScaleAndColor(ghost, 0.85, Color(0.1, 0.8, 0.3, 0.75, 0.1, 0.5, 0.15))
                    end
                end)
            end
        end
    end)
end
