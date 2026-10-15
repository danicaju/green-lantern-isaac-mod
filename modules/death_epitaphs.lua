-- modules/death_epitaphs.lua -- RSI: comic book death epitaphs & game over messages.
-- Responsabilidad unica: mostrar epitafios y citas de comic al morir como Hal Jordan o Parallax.

return function(Core)
    local GL = Core.GL

    local HAL_EPITAPHS = {
        { quote = "His light was extinguished in Sector 2814.", author = "Oan Book of the Dead" },
        { quote = "The ring has chosen a successor...", author = "Power Ring AI" },
        { quote = "Willpower shattered... In Blackest Night.", author = "Tales of the Corps" },
        { quote = "Even the greatest of the Green Lanterns must fall.", author = "Sinestro" },
        { quote = "Beware my power... A final oath whispers into the void.", author = "Hal Jordan" },
        { quote = "No evil shall escape his sight... Until now.", author = "Guardians of the Universe" },
    }

    local PARALLAX_EPITAPHS = {
        { quote = "Fear swallowed the cosmos... All light died.", author = "The Blackest Night" },
        { quote = "The Emerald Twilight claims another soul.", author = "Coast City Memorial" },
        { quote = "The Parallax entity hungers for eternity.", author = "The Book of Parallax" },
        { quote = "No will remained to hold back the yellow fear.", author = "Sinestro Corps Archive" },
        { quote = "Consumed by the terror he once fought.", author = "Ganthet" },
    }

    Core.HAL_EPITAPHS = HAL_EPITAPHS
    Core.PARALLAX_EPITAPHS = PARALLAX_EPITAPHS

    -- Reset state on new game
    GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
        Core.activeDeathEpitaph = nil
    end)

    -- Trigger & render comic death epitaph
    GL:AddCallback(ModCallbacks.MC_POST_RENDER, function(_)
        if Core.DEATH_EPITAPHS_ENABLED == false then return end
        if not (Game and Isaac and Isaac.GetPlayer) then return end

        local num = Game():GetNumPlayers()
        for i = 0, num - 1 do
            local player = Isaac.GetPlayer(i)
            if player then
                local isHal = Core.IsHalJordan and Core.IsHalJordan(player)
                local isTHal = Core.IsTaintedHal and Core.IsTaintedHal(player)

                if isHal or isTHal then
                    local isDead = false
                    if player.IsDead and player:IsDead() then
                        isDead = true
                    elseif player.GetSprite then
                        local spr = player:GetSprite()
                        if spr and spr.IsPlaying and spr:IsPlaying("Death") then
                            isDead = true
                        end
                    end

                    if isDead and not Core.activeDeathEpitaph then
                        local pool = isTHal and PARALLAX_EPITAPHS or HAL_EPITAPHS
                        local idx = math.random(1, #pool)
                        local chosen = pool[idx]

                        Core.activeDeathEpitaph = {
                            quote = chosen.quote,
                            author = chosen.author,
                            isTainted = isTHal,
                            timer = 0,
                        }

                        pcall(function()
                            if isTHal then
                                local sfx = (SoundEffect and (SoundEffect.SOUND_HELL_PORTAL2 or SoundEffect.SOUND_DEATH_CARD)) or 0
                                if sfx > 0 and SFXManager then
                                    SFXManager():Play(sfx, 0.85 * (Core.SFX_VOLUME_MULT or 1.0), 0, false, 0.85)
                                end
                            else
                                local sfx = (SoundEffect and (SoundEffect.SOUND_BATTERYDISCHARGE or SoundEffect.SOUND_THUMBS_DOWN)) or 0
                                if sfx > 0 and SFXManager then
                                    SFXManager():Play(sfx, 0.90 * (Core.SFX_VOLUME_MULT or 1.0), 0, false, 0.70)
                                end
                            end
                        end)
                    end
                end
            end
        end

        -- Render active comic death epitaph
        local epitaph = Core.activeDeathEpitaph
        if epitaph and Isaac.RenderScaledText then
            epitaph.timer = (epitaph.timer or 0) + 1
            local alpha = math.min(1.0, epitaph.timer / 40.0)

            local screenW = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or 480
            local screenH = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or 270

            local r, g, b
            local title
            if epitaph.isTainted then
                r, g, b = 1.0, 0.86, 0.18 -- Yellow Fear
                title = "-- PARALLAX REIGN --"
            else
                r, g, b = 0.22, 1.0, 0.42 -- Emerald Willpower
                title = "-- GREEN LANTERN MEMORIAM --"
            end

            local scale = 0.5
            local quoteText = '"' .. epitaph.quote .. '"'
            local authorText = "- " .. epitaph.author

            local titleX = screenW / 2 - (#title * 3)
            local quoteX = screenW / 2 - (#quoteText * 2.8)
            local authorX = screenW / 2 - (#authorText * 2.5)
            local baseY = screenH - 46

            pcall(function()
                Isaac.RenderScaledText(title, titleX, baseY, scale, scale, r * 0.8, g * 0.8, b * 0.8, alpha * 0.75)
                Isaac.RenderScaledText(quoteText, quoteX, baseY + 12, scale, scale, r, g, b, alpha)
                Isaac.RenderScaledText(authorText, authorX, baseY + 24, scale, scale, 0.8, 0.8, 0.8, alpha * 0.85)
            end)
        end
    end)
end
