-- modules/hud_bars.lua -- RSI: barras Willpower/Sparks + texto de juramento.
-- Responsabilidad unica: dibujar la HUD de recursos y los textos oathText.

return function(Core)
    function Core.RenderHudBars(currentGameFrame, gameAdvancedThisRender)
        local hudOffset = (Options and Options.HUDOffset) or 0
        local function GetCoopHUDOrigin(pIdx)
            local offX = math.floor(hudOffset * 20)
            local offY = math.floor(hudOffset * 12)
            if pIdx == 0 then
                return 48 + offX, 40 + offY
            elseif pIdx == 1 then
                local sW = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
                return sW - (80 + offX), 40 + offY
            elseif pIdx == 2 then
                local sH = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
                return 48 + offX, sH - (38 + offY)
            elseif pIdx == 3 then
                local sW = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
                local sH = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270
                return sW - (80 + offX), sH - (38 + offY)
            else
                return 48 + offX, 40 + offY + (pIdx * 14)
            end
        end

        for i = 0, Game():GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(i)
            if player then
                local hudX, hudY = GetCoopHUDOrigin(i)
                local data = Core.GetPlayerData(player)
                if Core.IsHalJordan(player) then
                    local maxWill = (Core.GetMaxWillpower and Core.GetMaxWillpower(player)) or Core.WILLPOWER_MAX
                    local pct = math.max(0.0, math.min(1.0, (data.willpower or 0) / maxWill))
                    local BAR_W = 30
                    Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * 0.14, 0.9, 0.08, 0.08, 0.08, 0.85)
                    local r, g, b = 0.1, 0.95, 0.3
                    if data.ringDepleted then
                        r, g, b = 1.0, 0.45, 0.15
                    elseif data.overcharge then
                        r, g, b = 1.0, 0.88, 0.15
                    elseif data.surgeBuff then
                        r, g, b = 0.35, 1.0, 0.65
                    elseif pct >= 0.995 then
                        r, g, b = 0.35, 1.0, 0.55
                    end
                    if pct > 0 then
                        Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * pct * 0.14, 0.9, r, g, b, 0.95)
                    end
                    local label = string.format("%.0f%%", data.willpower or 0)
                    if (data.gatlingTimer or 0) > 0 then
                        label = string.format("%.0f%% GATLING", data.willpower or 0)
                    elseif data.ringDepleted then
                        label = string.format("REBOOT %.0f%%/%.0f%%", data.willpower or 0, Core.WILLPOWER_REBOOT_THRESHOLD)
                    elseif data.overcharge then
                        local bonus = (data.overchargeTier or 1) >= 2 and "+25%DMG" or "+15%DMG"
                        label = string.format("%.0f%% %s", data.willpower or 0, bonus)
                    end
                    Core.DrawHudText(label, hudX + 28, hudY - 2, r, g, b, 0.95)
                    if data.oathTextTimer and data.oathTextTimer > 0 then
                        if gameAdvancedThisRender and currentGameFrame % 2 == 0 then data.oathTextTimer = data.oathTextTimer - 1 end
                        if data.oathText and data.oathText ~= "" then
                            local textWidth = (Core.GetTextWidth and Core.GetTextWidth(data.oathText)) or (#data.oathText * 5.5)
                            local timerRatio = math.max(0, math.min(1, (data.oathTextTimer or 0) / 95.0))
                            local floatUp = (1.0 - timerRatio) * 12.0
                            local hp = Isaac.WorldToScreen(player.Position + Vector(0, -48 - floatUp))
                            local drawX = math.floor(hp.X - (textWidth * 0.5))
                            local drawY = math.floor(hp.Y)
                            Core.DrawHudText(data.oathText, drawX, drawY, r, g, b, math.min(0.95, data.oathTextTimer / 20.0))
                        end
                    end
                end
                if Core.IsTaintedHal(player) then
                    local sparks = data.emeraldSparks or 0.0
                    local stolen = data.stolenRings or 0
                    local sMax = Core.SPARK_MAX or 100.0
                    local pct = math.max(0.0, math.min(1.0, sparks / sMax))
                    local BAR_W = 30
                    Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * 0.14, 0.9, 0.08, 0.08, 0.08, 0.85)
                    local r, g, b = 0.0, 0.85, 0.4
                    if pct >= 1.0 then r, g, b = 0.25, 1.0, 0.55 end
                    if pct > 0 then
                        Isaac.RenderScaledText("_", hudX, hudY - 4, BAR_W * pct * 0.14, 0.9, r, g, b, 0.95)
                    end
                    local label = pct >= 1.0 and "100%" or string.format("%.0f%%", sparks)
                    if stolen > 0 then
                        label = string.format("%s [%d]", label, stolen)
                    end
                    Core.DrawHudText(label, hudX + 28, hudY - 2, r, g, b, 0.95)
                    if data.oathTextTimer and data.oathTextTimer > 0 then
                        if gameAdvancedThisRender and currentGameFrame % 2 == 0 then data.oathTextTimer = data.oathTextTimer - 1 end
                        if data.oathText and data.oathText ~= "" then
                            local textWidth = (Core.GetTextWidth and Core.GetTextWidth(data.oathText)) or (#data.oathText * 5.5)
                            local timerRatio = math.max(0, math.min(1, (data.oathTextTimer or 0) / 95.0))
                            local floatUp = (1.0 - timerRatio) * 12.0
                            local hp = Isaac.WorldToScreen(player.Position + Vector(0, -48 - floatUp))
                            local drawX = math.floor(hp.X - (textWidth * 0.5))
                            local drawY = math.floor(hp.Y)
                            Core.DrawHudText(data.oathText, drawX, drawY, r, g, b, math.min(0.95, data.oathTextTimer / 20.0))
                        end
                    end
                end
            end
        end
    end
end
