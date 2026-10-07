-- modules/fx_shield_items.lua -- RSI: render de escudo solido + efectos de items/trinkets. Sin callbacks, todo via Core.
return function(Core)
    -- Duracion canonica del flash Deflect (frames). El valor manda en shield.lua;
    -- aqui solo se usa para mapear timer -> frame 0-3. Timers heredados mayores se clampan.
    local DEFLECT_DURATION = 12

    -- Transicion de animacion orbital sin parpadeo: todo cambio va via Play
    -- (Deflect tiene Loop=false; volver con SetFrame dejaba el ultimo frame congelado).
    local function EnsureOrbitalAnim(orbitalSpr, data, name)
        if data.shieldOrbitalAnim ~= name then
            if orbitalSpr.Play then
                orbitalSpr:Play(name, true)
            end
            data.shieldOrbitalAnim = name
        end
    end
    function Core.RenderGLSolidShieldBehind(player, renderOffset)
        if not (player and Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0 and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD)) then return end
        local data = Core.GetPlayerData(player)
        local getAura = Core.GetGLSolidShieldAuraSprite or Core.GetGLSolidShieldSprite
        local auraSpr = getAura and getAura()
        if not auraSpr then return end

        local frame = Game():GetFrameCount()

        -- 1. Hexagonal Construct Barrier Aura centered on player's torso
        local auraFrame = math.floor(frame / 4) % 2
        auraSpr:SetFrame("Aura", auraFrame)
        local isDeflecting = (data.shieldDeflectTimer and data.shieldDeflectTimer > 0)
        -- Pulsing alpha: alternating 0.36 / 0.52 every 4 frames.
        local auraAlpha = isDeflecting and 0.88 or ((math.floor(frame / 4) % 2 == 0) and 0.52 or 0.36)
        auraSpr.Color = Color(1.0, 1.0, 1.0, auraAlpha, 0, 0, 0)
        auraSpr.Scale = Vector(1.0, 1.0)
        local auraPos = player.Position + Vector(0, -14)
        -- Note: Isaac.WorldToScreen already transforms world to screen coordinates in all room sizes.
        -- Adding renderOffset from MC_POST_PLAYER_RENDER in large rooms was causing a camera-offset detachment bug.
        auraSpr:Render(Isaac.WorldToScreen(auraPos), Vector.Zero, Vector.Zero)
    end

    function Core.RenderGLSolidShieldFront(player, renderOffset)
        if not (player and Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0 and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD)) then return end
        local data = Core.GetPlayerData(player)
        local getOrbital = Core.GetGLSolidShieldOrbitalSprite or Core.GetGLSolidShieldSprite
        local orbitalSpr = getOrbital and getOrbital()
        if not orbitalSpr then return end

        local frame = Game():GetFrameCount()
        local shieldPos = Core.GetShieldOrbitPos(player, data) or (player.Position + Vector(36, 0))
        local sScreen = Isaac.WorldToScreen(shieldPos) + Vector(0, -14)
        local isDeflecting = (data.shieldDeflectTimer and data.shieldDeflectTimer > 0)
        if isDeflecting then
            EnsureOrbitalAnim(orbitalSpr, data, "Deflect")
            local clampedTimer = math.min(DEFLECT_DURATION, data.shieldDeflectTimer or 0)
            local defFrame = math.min(3, math.max(0, math.floor((DEFLECT_DURATION - clampedTimer) / 3)))
            orbitalSpr:SetFrame("Deflect", defFrame)
        else
            EnsureOrbitalAnim(orbitalSpr, data, "Orbit")
            orbitalSpr:SetFrame("Orbit", math.floor(frame / 2) % 4)
        end
        orbitalSpr.Color = Color(1.0, 1.0, 1.0, 0.95, 0, 0, 0)
        orbitalSpr.Scale = Vector(1.0, 1.0)
        orbitalSpr:Render(sScreen, Vector.Zero, Vector.Zero)
    end

    function Core.RenderGLActiveItemAndTrinketEffects(player, renderOffset)
        local data = Core.GetPlayerData(player)
        local frame = Game():GetFrameCount()

        -- Power Battery manifestation construct projection
        if data.batteryConstructTimer and data.batteryConstructTimer > 0 then
            local battSpr = Core.GetGLBatteryConstructSprite()
            if battSpr then
                battSpr:SetFrame("Pulse", math.floor(frame / 2) % 4)
                local alpha = math.min(1.0, data.batteryConstructTimer / 10.0)
                battSpr.Color = Color(1.0, 1.0, 1.0, alpha, 0.10, 0.55, 0.15)
                local bob = ((math.floor(frame * 0.18) % 2 == 0) and 1 or -1) * 3
                local battPos = player.Position + Vector(0, -44 + bob)
                battSpr:Render(Isaac.WorldToScreen(battPos), Vector.Zero, Vector.Zero)
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
                fearSpr:Render(Isaac.WorldToScreen(skullPos), Vector.Zero, Vector.Zero)
            end
        elseif Core.TRINKET_YELLOW_IMPURITY and player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY) then
            -- Ambient yellow fear ember crackling around player while held
            if (frame % 28) < 10 then
                local fearSpr = Core.GetGLYellowFearSprite()
                if fearSpr then
                    fearSpr:SetFrame("YellowSpark", math.floor(frame / 2) % 2)
                    fearSpr.Color = Color(1.0, 1.0, 1.0, 0.85, 0.30, 0.22, 0.0)
                    local sx = ((frame % 32) - 16) * (15 / 16)
                    local sy = ((frame % 16) - 8)
                    local sparkPos = player.Position + Vector(sx, -16 + sy)
                    fearSpr:Render(Isaac.WorldToScreen(sparkPos), Vector.Zero, Vector.Zero)
                end
            end
        end

    end

    -- Power Battery construct orbital with Green Lantern emblem
    function Core.RenderGLBatteryOrbital(player, renderOffset, isBehind)
        if not player then return end
        if not Core.ITEM_POWER_BATTERY or Core.ITEM_POWER_BATTERY < 0 then
            Core.LoadItemIDs()
        end
        if not Core.ITEM_POWER_BATTERY or Core.ITEM_POWER_BATTERY < 0 then return end

        local hasBattery = false
        if player.HasCollectible and player:HasCollectible(Core.ITEM_POWER_BATTERY) then
            hasBattery = true
        elseif player.GetActiveItem and (player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) == Core.ITEM_POWER_BATTERY
               or (ActiveSlot.SLOT_POCKET and player:GetActiveItem(ActiveSlot.SLOT_POCKET) == Core.ITEM_POWER_BATTERY)) then
            hasBattery = true
        end
        if not hasBattery then return end

        local getSprite = Core.GetGLBatteryOrbitalSparkSprite or Core.GetGLSparkSprite
        local sparkSpr = getSprite and getSprite()
        if not sparkSpr then return end

        local data = Core.GetPlayerData(player)
        local frame = Game():GetFrameCount()

        -- Smooth continuous angle: advances smoothly at 60Hz via batteryOrbitAngle, or continuous frame angle
        local angle = (data and data.batteryOrbitAngle) or (frame * 0.05)

        -- Elliptical orbit matching Isaac's 2.5D perspective
        local radX = 32.0
        local radY = 18.0
        local ox = math.cos(angle) * radX
        local oy = math.sin(angle) * radY

        -- Depth check: top half (oy < 0) is behind player, bottom half (oy >= 0) is in front of player
        local isBehindOrbit = (oy < 0)
        if isBehind == true and not isBehindOrbit then return end
        if isBehind == false and isBehindOrbit then return end

        -- Set sprite animation and render
        sparkSpr:SetFrame("Idle", math.floor(frame / 3) % 4)
        sparkSpr.Color = Color(1.0, 1.0, 1.0, 0.95, 0.08, 0.35, 0.12)
        sparkSpr.Scale = Vector(0.70, 0.70)

        -- Center around player's waist/torso (Y: -14)
        local orbitalPos = player.Position + Vector(ox, -14 + oy)
        local screenPos = Isaac.WorldToScreen(orbitalPos)
        sparkSpr:Render(screenPos, Vector.Zero, Vector.Zero)
    end
end
