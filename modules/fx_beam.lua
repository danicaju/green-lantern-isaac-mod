-- modules/fx_beam.lua -- RSI: render de sparks + aura + beam continuo + flare. Sin callbacks, todo via Core.
return function(Core)
    function Core.RenderGLSparkDrops(onlyCollected)
        if #Core.activeEmeraldSparks == 0 then return end
        local sparkSpr = Core.GetGLSparkSprite()
        if not sparkSpr then return end

        local frame = Game():GetFrameCount()
        local currentRoomIdx = Game():GetLevel():GetCurrentRoomIndex()
        for _, sp in ipairs(Core.activeEmeraldSparks) do
            if sp and sp.roomIdx == currentRoomIdx then
                if sp.collected and (onlyCollected == true or onlyCollected == nil) then
                    -- Render coin/bomb-style squash-and-upward-stretch pickup animation IN FRONT OF the player!
                    local collectAge = math.max(0, frame - (sp.collectFrame or frame))
                    if collectAge < Core.SPARK_COLLECT_FRAMES then
                        local screenPos = Isaac.WorldToScreen(sp.pos)
                        sparkSpr:SetFrame("Collect", collectAge)
                        sparkSpr.Scale = Vector(1.0, 1.0)
                        sparkSpr.Color = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0)
                        sparkSpr:Render(screenPos, Vector.Zero, Vector.Zero)
                    end
                elseif (not sp.collected) and (onlyCollected == false or onlyCollected == nil) then
                    local ageFrames = math.max(0, frame - (sp.spawnFrame or frame))
                    if ageFrames < Core.SPARK_LIFETIME_FRAMES then
                        local screenPos = Isaac.WorldToScreen(sp.pos)
                        local animFrame = math.floor(ageFrames / 4) % 4
                        sparkSpr:SetFrame("Idle", animFrame)
                        local rem = Core.SPARK_LIFETIME_FRAMES - ageFrames
                        if rem <= 15 then
                            local shrink = math.max(0.15, rem / 15.0)
                            sparkSpr.Scale = Vector(shrink, shrink)
                        else
                            sparkSpr.Scale = Vector(1.0, 1.0)
                        end
                        if ageFrames >= (Core.SPARK_LIFETIME_FRAMES - Core.SPARK_BLINK_FRAMES) then
                            local alpha = (math.floor(ageFrames / 3) % 2 == 0) and 0.95 or 0.22
                            sparkSpr.Color = Color(1.0, 1.0, 1.0, alpha, 0, 0, 0)
                        else
                            sparkSpr.Color = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0)
                        end
                        sparkSpr:Render(screenPos, Vector.Zero, Vector.Zero)
                    end
                end
            end
        end
    end

    function Core.RenderGLPlayerAura(player)
        if not (Core.IsHalJordan(player) or Core.IsTaintedHal(player)) then return end
        local data = Core.GetPlayerData(player)
        if Core.IsHalJordan(player) and data.ringDepleted then return end

        local auraSpr, _ = Core.GetGLAuraSprites()
        if not auraSpr then return end

        local frame = Game():GetFrameCount()
        local animName = Core.IsTaintedHal(player) and "ParallaxAura" or "HalAura"
        local animFrame = math.floor(frame / 3) % 8
        auraSpr:SetFrame(animName, animFrame)

        local isMaxPower = (Core.IsHalJordan(player) and ((data.willpower or 0) >= 99.5 or data.overcharge or data.surgeBuff))
            or (Core.IsTaintedHal(player) and ((data.emeraldSparks or 0) >= 99.5 or data.coastCityActive))

        local auraScale = isMaxPower and 1.05 or 0.92
        local auraAlpha = isMaxPower and 0.92 or 0.72
        auraSpr.Scale = Vector(auraScale, auraScale)
        if data.overcharge then
            auraSpr.Color = Color(0.55, 1.0, 0.55, auraAlpha, 0.12, 0.45, 0.08)
        else
            auraSpr.Color = Color(1.0, 1.0, 1.0, auraAlpha, 0, 0, 0)
        end

        local bodyScreenPos = Isaac.WorldToScreen(player.Position)
        auraSpr:Render(bodyScreenPos, Vector.Zero, Vector.Zero)
    end

    -- Screen-space offset (px) to skip at the start of the continuous beam when aiming UP.
    -- The ring hand is centered behind the head (Vector(0,-32)) in that pose; the initial
    -- segment would otherwise be painted directly over the head/neck. Purely a render-time
    -- trim — raycast / damage start are untouched.
    local GL_BEAM_UP_HEAD_SKIP = 28.0

    -- Returns the initial screen-space distance (px) to skip when drawing the continuous beam.
    -- Only applies while aiming UP and when the beam is long enough that something would still
    -- remain visible after the skip. 0 in every other case.
    function Core.ComputeBeamRenderStartSkip(isAimingUp, totalScreenLen)
        if not isAimingUp then return 0.0 end
        if totalScreenLen <= GL_BEAM_UP_HEAD_SKIP then return 0.0 end
        return GL_BEAM_UP_HEAD_SKIP
    end

    function Core.RenderGLContinuousBeam(player, data, flareSpr, frame)
        if not (data and data.isFiringContinuousBeam) then
            return
        end
        local beamSpr = Core.GetGLContBeamSprite()
        if not beamSpr then return end

        local shootInput = player:GetShootingInput()
        local dir = data.lastShootDir
        if not (dir and dir:Length() > 0.001) then
            if shootInput and shootInput:Length() > 0.1 then
                dir = shootInput:Normalized()
            else
                dir = Vector(1, 0)
            end
        else
            dir = dir:Normalized()
        end

        local handOffset  = data.lastRingHandOffset or Core.GetRingHandOffset(player, dir)
        local startWorld  = player.Position + handOffset
        local endWorld    = Core.ComputeContinuousBeamEndWorld(startWorld, dir)
        local startScreen = Isaac.WorldToScreen(startWorld)
        local endScreen   = Isaac.WorldToScreen(endWorld)

        local screenDelta = endScreen - startScreen
        local totalScreenLen = screenDelta:Length()
        if totalScreenLen < 4.0 then return end

        local screenDir = screenDelta / totalScreenLen
        local screenAngle = screenDir:GetAngleDegrees()
        local thickness = Core.IsTaintedHal(player) and 1.18 or (data.overcharge and 1.22 or (data.surgeBuff and 1.10 or 1.0))
        local segWidth = 48.0
        local segStep  = 48.0
        local aimingUp = Core.IsAimingUp(player, dir)
        local dist     = Core.ComputeBeamRenderStartSkip(aimingUp, totalScreenLen)
        local animFrame = math.floor(frame / 2) % 4

        while dist < totalScreenLen do
            local rem = totalScreenLen - dist
            local xScale = 1.0
            if rem < segWidth then
                xScale = math.max(0.05, rem / segWidth)
            end
            beamSpr:SetFrame("ContinuousBeam", animFrame)
            beamSpr.Rotation = screenAngle
            beamSpr.Scale = Vector(xScale, thickness)
            beamSpr.Color = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0)
            beamSpr:Render(startScreen + screenDir * dist, Vector.Zero, Vector.Zero)
            if rem <= segWidth then
                break
            end
            dist = dist + segStep
        end

        -- Render bright emerald construct impact flare at the beam endpoint.
        -- Guard: skip on very short beams to avoid a bright flare stacked on the player.
        -- Alpha scales with length: 0 at <=24px, 1 at >=120px, linear in between.
        local GL_BEAM_FLARE_MIN_DIST = 24.0
        local GL_BEAM_FLARE_FULL_DIST = 120.0
        if flareSpr and totalScreenLen >= GL_BEAM_FLARE_MIN_DIST then
            local flareAlpha = (totalScreenLen - GL_BEAM_FLARE_MIN_DIST) / (GL_BEAM_FLARE_FULL_DIST - GL_BEAM_FLARE_MIN_DIST)
            if flareAlpha < 0.0 then
                flareAlpha = 0.0
            elseif flareAlpha > 1.0 then
                flareAlpha = 1.0
            end
            flareSpr:SetFrame("RingFlare", math.floor(frame / 2) % 4)
            flareSpr.Scale = Vector(0.95 * thickness, 0.95 * thickness)
            flareSpr.Color = Color(1.0, 1.0, 1.0, 0.95 * flareAlpha, 0.15, 0.50, 0.18)
            flareSpr:Render(endScreen, Vector.Zero, Vector.Zero)
        end
    end

    function Core.IsPlayerAimingUpForRender(player, data)
        local activeFlare = data and (data.isFiringContinuousBeam or (data.ringFlareTimer and data.ringFlareTimer > 0))
        local shootDir = (activeFlare and data.lastShootDir) or player:GetShootingInput()
        return Core.IsAimingUp(player, shootDir)
    end

    function Core.RenderGLBeamAndFlareForPlayer(player, data, frame)
        local _, flareSpr = Core.GetGLAuraSprites()
        Core.RenderGLContinuousBeam(player, data, flareSpr, frame)

        if flareSpr then
            local shootInput = player:GetShootingInput()
            local hasActiveFlare = data.isFiringContinuousBeam or (data.ringFlareTimer and data.ringFlareTimer > 0)
            local isFiring = (shootInput and shootInput:Length() > 0.1) or hasActiveFlare
            local aimingUp = Core.IsPlayerAimingUpForRender(player, data)

            -- When facing UP without firing, the ring hand is in front of the torso (hidden behind the head/body from camera view)
            if aimingUp and not isFiring then
                return
            end

            local handOffset = (hasActiveFlare and data.lastRingHandOffset) or Core.GetRingHandOffset(player, shootInput)
            if aimingUp then
                handOffset = Vector(0, -38)
            end
            local handScreenPos = Isaac.WorldToScreen(player.Position + handOffset)

            local flareFrame = math.floor(frame / (isFiring and 2 or 4)) % 4
            flareSpr:SetFrame("RingFlare", flareFrame)

            if data.isFiringContinuousBeam then
                local fScale = aimingUp and 0.78 or 1.05
                flareSpr.Scale = Vector(fScale, fScale)
                flareSpr.Color = Color(1.0, 1.0, 1.0, 0.98, 0.15, 0.50, 0.18)
            elseif isFiring then
                local fScale = aimingUp and 0.68 or 0.85
                flareSpr.Scale = Vector(fScale, fScale)
                flareSpr.Color = Color(1.0, 1.0, 1.0, 0.95, 0.10, 0.35, 0.12)
            else
                local pulse = 0.45 + 0.20 * math.sin(frame * 0.20)
                flareSpr.Scale = Vector(0.45, 0.45)
                flareSpr.Color = Color(1.0, 1.0, 1.0, pulse, 0, 0, 0)
            end
            flareSpr:Render(handScreenPos, Vector.Zero, Vector.Zero)
        end
    end
end
