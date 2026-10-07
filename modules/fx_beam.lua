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
    local GL_BEAM_UP_HEAD_SKIP = 14.0

    -- Returns the initial screen-space distance (px) to skip when drawing the continuous beam.
    -- Only applies while aiming UP and when the beam is long enough that something would still
    -- remain visible after the skip. 0 in every other case.
    function Core.ComputeBeamRenderStartSkip(isAimingUp, totalScreenLen)
        if not isAimingUp then return 0.0 end
        if totalScreenLen <= GL_BEAM_UP_HEAD_SKIP then return 0.0 end
        return GL_BEAM_UP_HEAD_SKIP
    end

    -- SPEC-D: crecimiento fluido del rayo continuo (solo render, estilo Brimstone).
    -- Coseno del umbral de giro (~30 grados): por debajo se reinicia la rampa
    -- desde la longitud visible actual, sin colapsar a 0. Solo render: el raycast,
    -- el dano por tick y el flare de la mano no cambian (beam_math/firing_mode intactos).
    local GL_BEAM_GROWTH_TURN_DOT = 0.8660254
    local GL_BEAM_GROWTH_MIN_LEN = 0.001

    local function growthFrames()
        local n = Core.CONTINUOUS_BEAM_GROWTH_FRAMES or 10
        if n < 1 then n = 1 end
        return n
    end

    local function normDirOrNil(v)
        if v and v.Length and v:Length() > GL_BEAM_GROWTH_MIN_LEN then
            return v:Normalized()
        end
        return nil
    end

    -- Longitud visible del haz para un frame de crecimiento dado. Pura y monotona:
    -- arranca en baseLen y llega a totalLen en N frames (suavizado smoothstep).
    function Core.ComputeBeamGrowthVisibleLength(totalLen, growthFrame, baseLen)
        local total = totalLen or 0.0
        if total <= 0.0 then return 0.0 end
        local n = growthFrames()
        local t = (growthFrame or 0) / n
        if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end
        local ease = t * t * (3.0 - 2.0 * t)
        local base = baseLen or 0.0
        if base < 0.0 then base = 0.0 elseif base > total then base = total end
        return base + (total - base) * ease
    end

    function Core.ResetBeamGrowth(data)
        if not data then return end
        data.beamGrowthFrame = 0
        data.beamGrowthDir = nil
        data.beamGrowthBaseLen = 0.0
    end

    -- Avanza la rampa de crecimiento un frame de render y devuelve la longitud
    -- visible. Todo el estado vive en data (por jugador, co-op seguro).
    function Core.UpdateBeamGrowth(data, dir, totalLen)
        local total = math.max(0.0, totalLen or 0.0)
        if not data then return 0.0 end
        if data.beamGrowthFrame == nil then data.beamGrowthFrame = 0 end
        if data.beamGrowthBaseLen == nil then data.beamGrowthBaseLen = 0.0 end
        local ndir = normDirOrNil(dir)
        local oldDir = data.beamGrowthDir
        local hasOld = oldDir and oldDir.Length and oldDir:Length() > GL_BEAM_GROWTH_MIN_LEN
        if ndir and hasOld then
            local dot = ndir.X * oldDir.X + ndir.Y * oldDir.Y
            if dot < GL_BEAM_GROWTH_TURN_DOT then
                local cur = Core.ComputeBeamGrowthVisibleLength(total, data.beamGrowthFrame, data.beamGrowthBaseLen)
                if cur < 0.0 then cur = 0.0 elseif cur > total then cur = total end
                data.beamGrowthBaseLen = cur
                data.beamGrowthFrame = 0
                data.beamGrowthDir = ndir
                return cur
            end
        elseif not ndir then
            return Core.ComputeBeamGrowthVisibleLength(total, data.beamGrowthFrame, data.beamGrowthBaseLen)
        end
        if oldDir == nil and ndir then
            data.beamGrowthDir = ndir
            return Core.ComputeBeamGrowthVisibleLength(total, data.beamGrowthFrame, data.beamGrowthBaseLen)
        end
        local n = growthFrames()
        data.beamGrowthFrame = math.min(n, (data.beamGrowthFrame or 0) + 1)
        if ndir then data.beamGrowthDir = ndir end
        return Core.ComputeBeamGrowthVisibleLength(total, data.beamGrowthFrame, data.beamGrowthBaseLen)
    end

    -- SPEC-X1 (solo render): haz corto contra muro fino para no tapar la cara.
    -- Por debajo de SHORT_THIN_LEN el grosor se clampa a <=1.0; el haz largo
    -- conserva su grosor (tainted/overcharge/surge intactos).
    local function clampShortBeamThickness(baseThickness, totalLen)
        local thinLen = Core.CONTINUOUS_BEAM_SHORT_THIN_LEN or 44.0
        if totalLen < thinLen and baseThickness > 1.0 then
            return 1.0
        end
        return baseThickness
    end

    function Core.RenderGLContinuousBeam(player, data, flareSpr, frame)
        if not (data and data.isFiringContinuousBeam) then
            -- SPEC-D: al soltar el disparo el proximo haz vuelve a crecer desde 0.
            if data then Core.ResetBeamGrowth(data) end
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
        -- Bajo 4px (degenerado) no dibuja; a partir de 4px dibuja incluso pegado al muro.
        local minRenderLen = Core.CONTINUOUS_BEAM_MIN_RENDER_LEN or 4.0
        if totalScreenLen < minRenderLen then return end

        -- SPEC-D: solo render — el dano usa el endWorld completo (beam_math intacto);
        -- aqui el haz crece 0->full en N frames y el flare sigue la punta visible.
        local visibleLen = Core.UpdateBeamGrowth(data, dir, totalScreenLen)
        if visibleLen < 2.0 then return end

        local screenDir = screenDelta / totalScreenLen
        local screenAngle = (screenDir.GetAngleDegrees and screenDir:GetAngleDegrees()) or (math.atan2(screenDir.Y, screenDir.X) * 180 / math.pi)
        local baseThickness = Core.IsTaintedHal(player) and 1.18 or (data.overcharge and 1.22 or (data.surgeBuff and 1.10 or 1.0))
        if Core.HasBirthright and Core.HasBirthright(player) and Core.IsHalJordan(player) then
            baseThickness = baseThickness * 1.30
        end
        local thickness = clampShortBeamThickness(baseThickness, totalScreenLen)
        local segWidth = 48.0
        local segStep  = 48.0
        local aimingUp = Core.IsAimingUp(player, dir)
        local dist     = Core.ComputeBeamRenderStartSkip(aimingUp, totalScreenLen)
        local animFrame = math.floor(frame / 2) % 4

        while dist < visibleLen do
            local rem = visibleLen - dist
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

        -- Render bright emerald construct impact flare at the VISIBLE beam tip on the wall.
        local GL_BEAM_FLARE_MIN_DIST = 8.0
        local GL_BEAM_FLARE_FULL_DIST = 120.0
        if flareSpr and visibleLen >= GL_BEAM_FLARE_MIN_DIST then
            local flareAlpha = (visibleLen - GL_BEAM_FLARE_MIN_DIST) / (GL_BEAM_FLARE_FULL_DIST - GL_BEAM_FLARE_MIN_DIST)
            if flareAlpha < 0.0 then
                flareAlpha = 0.0
            elseif flareAlpha > 1.0 then
                flareAlpha = 1.0
            end
            local flarePos = startScreen + screenDir * visibleLen
            flareSpr:SetFrame("RingFlare", math.floor(frame / 2) % 4)
            flareSpr.Scale = Vector(0.95 * thickness, 0.95 * thickness)
            flareSpr.Color = Color(1.0, 1.0, 1.0, 0.95 * flareAlpha, 0.15, 0.50, 0.18)
            flareSpr:Render(flarePos, Vector.Zero, Vector.Zero)
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
