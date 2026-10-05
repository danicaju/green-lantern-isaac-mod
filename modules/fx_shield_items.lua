-- modules/fx_shield_items.lua -- RSI: render de escudo solido + efectos de items/trinkets. Sin callbacks, todo via Core.
return function(Core)
    function Core.RenderGLSolidShieldBehind(player, renderOffset)
        if not (player and Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0 and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD)) then return end
        local data = Core.GetPlayerData(player)
        local shieldSpr = Core.GetGLSolidShieldSprite()
        if not shieldSpr then return end

        local frame = Game():GetFrameCount()
        local rOffset = renderOffset or Vector.Zero

        -- 1. Hexagonal Construct Barrier Aura centered on player's torso
        local auraFrame = math.floor(frame / 4) % 2
        shieldSpr:SetFrame("Aura", auraFrame)
        local isDeflecting = (data.shieldDeflectTimer and data.shieldDeflectTimer > 0)
        -- Pulsing alpha: alternating 0.36 / 0.52 every 4 frames. Was a sinusoidal pulse (eliminated per SPEC).
        local auraAlpha = isDeflecting and 0.88 or ((math.floor(frame / 4) % 2 == 0) and 0.52 or 0.36)
        shieldSpr.Color = Color(1.0, 1.0, 1.0, auraAlpha, 0, 0, 0)
        shieldSpr.Scale = Vector(1.0, 1.0)
        local auraPos = player.Position + Vector(0, -14)
        shieldSpr:Render(Isaac.WorldToScreen(auraPos) + rOffset, Vector.Zero, Vector.Zero)
    end

    function Core.RenderGLSolidShieldFront(player, renderOffset)
        if not (player and Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0 and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD)) then return end
        local data = Core.GetPlayerData(player)
        local shieldSpr = Core.GetGLSolidShieldSprite()
        if not shieldSpr then return end

        -- Orbital shield always rendered in MC_POST_PLAYER_RENDER (delante del jugador).
        -- Reparto isometrico (sign-of-angle split) eliminado: el orbital vive siempre en Front.
        local frame = Game():GetFrameCount()
        local rOffset = renderOffset or Vector.Zero
        local shieldPos = Core.GetShieldOrbitPos(player, data) or (player.Position + Vector(36, 0))
        local sScreen = Isaac.WorldToScreen(shieldPos) + rOffset + Vector(0, -14)
        local isDeflecting = (data.shieldDeflectTimer and data.shieldDeflectTimer > 0)
        if isDeflecting then
            local defFrame = math.min(3, math.max(0, math.floor((12 - (data.shieldDeflectTimer or 0)) / 3)))
            shieldSpr:SetFrame("Deflect", defFrame)
        else
            shieldSpr:SetFrame("Orbit", math.floor(frame / 2) % 4)
        end
        shieldSpr.Color = Color(1.0, 1.0, 1.0, 0.95, 0, 0, 0)
        shieldSpr.Scale = Vector(1.0, 1.0)
        shieldSpr:Render(sScreen, Vector.Zero, Vector.Zero)
    end

    function Core.RenderGLActiveItemAndTrinketEffects(player, renderOffset)
        local data = Core.GetPlayerData(player)
        local frame = Game():GetFrameCount()
        local rOffset = renderOffset or Vector.Zero

        -- Power Battery manifestation construct projection
        if data.batteryConstructTimer and data.batteryConstructTimer > 0 then
            local battSpr = Core.GetGLBatteryConstructSprite()
            if battSpr then
                battSpr:SetFrame("Pulse", math.floor(frame / 2) % 4)
                local alpha = math.min(1.0, data.batteryConstructTimer / 10.0)
                battSpr.Color = Color(1.0, 1.0, 1.0, alpha, 0.10, 0.55, 0.15)
                -- Bob +/-3 alternando cada 18 frames aprox. Era un bob sinusoidal (eliminado per SPEC).
                local bob = ((math.floor(frame * 0.18) % 2 == 0) and 1 or -1) * 3
                local battPos = player.Position + Vector(0, -44 + bob)
                battSpr:Render(Isaac.WorldToScreen(battPos) + rOffset, Vector.Zero, Vector.Zero)
            end
        end

        -- Yellow Impurity Fear Skull
        if data.fearSkullTimer and data.fearSkullTimer > 0 then
            local fearSpr = Core.GetGLYellowFearSprite()
            if fearSpr then
                fearSpr:SetFrame("FearSkull", math.floor(frame / 2) % 2)
                local alpha = math.min(1.0, data.fearSkullTimer / 10.0)
                fearSpr.Color = Color(1.0, 1.0, 1.0, alpha, 0.35, 0.28, 0.0)
                local skullPos = player.Position + Vector(0, -36)
                fearSpr:Render(Isaac.WorldToScreen(skullPos) + rOffset, Vector.Zero, Vector.Zero)
            end
        elseif Core.TRINKET_YELLOW_IMPURITY and player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY) then
            -- Ambient yellow fear ember crackling around player while held
            if (frame % 28) < 10 then
                local fearSpr = Core.GetGLYellowFearSprite()
                if fearSpr then
                    fearSpr:SetFrame("YellowSpark", math.floor(frame / 2) % 2)
                    fearSpr.Color = Color(1.0, 1.0, 1.0, 0.85, 0.30, 0.22, 0.0)
                    -- Orbita rectangular alrededor del jugador. Antes: Vector(sin(0.25t)*15, -16 + cos(0.25t)*8)
                    local sx = ((frame % 32) - 16) * (15 / 16)
                    local sy = ((frame % 16) - 8)
                    local sparkPos = player.Position + Vector(sx, -16 + sy)
                    fearSpr:Render(Isaac.WorldToScreen(sparkPos) + rOffset, Vector.Zero, Vector.Zero)
                end
            end
        end

        -- Power Battery passive held spark
        if Core.ITEM_POWER_BATTERY and player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) == Core.ITEM_POWER_BATTERY and (frame % 36) < 8 then
            local sparkSpr = Core.GetGLSparkSprite()
            if sparkSpr then
                sparkSpr:SetFrame("Idle", math.floor(frame / 2) % 4)
                sparkSpr.Color = Color(1.0, 1.0, 1.0, 0.70, 0.10, 0.50, 0.15)
                sparkSpr.Scale = Vector(0.65, 0.65)
                -- Orbita rectangular alrededor del jugador. Antes: Vector(cos(0.2t)*14, -18 + sin(0.2t)*6)
                local bx = ((frame % 28) - 14) * (14 / 14)
                local by = ((frame % 14) - 7) * (6 / 7)
                local bPos = player.Position + Vector(bx, -18 + by)
                sparkSpr:Render(Isaac.WorldToScreen(bPos) + rOffset, Vector.Zero, Vector.Zero)
            end
        end
    end
end
