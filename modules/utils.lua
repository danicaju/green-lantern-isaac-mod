-- modules/utils.lua -- RSI: utilidades puras sin estado (bitmask + sprite). Sin callbacks, sin globals, todo via Core.
return function(Core)
    local bitAndFn = (loadstring or load) and (loadstring or load)("local a, b = ...; return a & b")
    local function fallbackBitAnd(a, b)
        local p, r = 1, 0
        while a > 0 and b > 0 do
            if a % 2 >= 1 and b % 2 >= 1 then r = r + p end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            p = p * 2
        end
        return r
    end

    -- Safe TearFlags bitmask test supporting both Repentance BitSet128 userdata and numeric bitmasks.
    -- (In Lua, comparing BitSet128 userdata to number 0 with `~= 0` is ALWAYS true!)
    function Core.HasTearFlag(flags, flag)
        if not flags or not flag then return false end
        local ok, res
        if bitAndFn then
            ok, res = pcall(bitAndFn, flags, flag)
        elseif type(flags) == "number" and type(flag) == "number" then
            ok, res = true, fallbackBitAnd(flags, flag)
        end
        if not ok or res == nil then return false end
        if type(res) == "number" then
            return res ~= 0
        end
        if TearFlags and TearFlags.TEAR_NONE ~= nil then
            local okEq, isNone = pcall(function() return res == TearFlags.TEAR_NONE end)
            if okEq then
                return not isNone
            end
        end
        if BitSet128 then
            local okBs, isZero = pcall(function() return res == BitSet128(0, 0) end)
            if okBs then
                return not isZero
            end
        end
        return false
    end

    -- Safe helper to scale and tint any Entity userdata (since Entity uses SpriteScale, not .Scale)
    function Core.SetEntityScaleAndColor(ent, scale, color)
        if not ent then return end
        pcall(function()
            if scale then
                ent.SpriteScale = Vector(scale, scale)
            end
            local spr = ent:GetSprite()
            if spr then
                if scale then
                    spr.Scale = Vector(scale, scale)
                end
                if color then
                    spr.Color = color
                end
            end
        end)
    end

    function Core.HasTractorBeam(player)
        if not (player and player.HasCollectible) then return false end
        local tbId = (CollectibleType and CollectibleType.COLLECTIBLE_TRACTOR_BEAM) or 397
        return player:HasCollectible(tbId)
    end

    function Core.GetTractorBeamDirection(player, rawDir)
        if not player then return rawDir end
        local headDir = player.GetHeadDirection and player:GetHeadDirection()
        if Direction then
            if headDir == Direction.LEFT then return Vector(-1, 0)
            elseif headDir == Direction.RIGHT then return Vector(1, 0)
            elseif headDir == Direction.UP then return Vector(0, -1)
            elseif headDir == Direction.DOWN then return Vector(0, 1)
            end
        end
        if headDir == 0 then return Vector(-1, 0)
        elseif headDir == 1 then return Vector(0, -1)
        elseif headDir == 2 then return Vector(1, 0)
        elseif headDir == 3 then return Vector(0, 1)
        end
        if rawDir and rawDir.Length and rawDir:Length() > 0.01 then
            if math.abs(rawDir.X) >= math.abs(rawDir.Y) then
                return Vector(rawDir.X > 0 and 1 or -1, 0)
            else
                return Vector(0, rawDir.Y > 0 and 1 or -1)
            end
        end
        return Vector(0, -1)
    end

    -- Plays a sound scaled by the user's SFX_VOLUME_MULT configuration
    function Core.PlayRingSound(soundId, baseVol, pitch)
        if not soundId or soundId <= 0 then return end
        if not SFXManager then return end
        local mult = Core.SFX_VOLUME_MULT or 1.0
        local vol = (baseVol or 1.0) * mult
        if vol <= 0.001 then return end
        pcall(function()
            SFXManager():Play(soundId, vol, 0, false, pitch or 1.0)
        end)
    end

    -- Comic Sound Design: Ring Overcharge Chime
    function Core.PlayOverchargeChime(player)
        if Core.OVERCHARGE_CHIME_ENABLED == false then return end
        local sfx = (SoundEffect and (SoundEffect.SOUND_SUPERHOLY or SoundEffect.SOUND_HOLY or SoundEffect.SOUND_POWERUP_SPEWER)) or 0
        if sfx > 0 and Core.PlayRingSound then
            Core.PlayRingSound(sfx, 0.95, 1.25)
        end
    end

    -- Comic Sound Design: Low Willpower Warning Sputter (<15% Willpower)
    function Core.PlayLowWillpowerWarning(player)
        if Core.LOW_WILLPOWER_WARNING_ENABLED == false then return end
        local sfx = (SoundEffect and (SoundEffect.SOUND_BATTERYDISCHARGE or SoundEffect.SOUND_THUMBS_DOWN)) or 0
        if sfx > 0 and Core.PlayRingSound then
            Core.PlayRingSound(sfx, 0.35, 1.40)
        end
    end

    -- Comic Sound Design: Ring Rebooted / Recharged Power Restoration Chime
    function Core.PlayRingRebootChime(player)
        local sfx = (SoundEffect and (SoundEffect.SOUND_BATTERYCHARGE or SoundEffect.SOUND_SUPERHOLY)) or 0
        if sfx > 0 and Core.PlayRingSound then
            Core.PlayRingSound(sfx, 0.90, 1.15)
        end
    end

    -- Comic Sound Design: Solid-Light Construct Punch
    function Core.PlayConstructPunchSound(player, isHeavy)
        if Core.CONSTRUCT_SFX_ENABLED == false then return end
        local sfx = (SoundEffect and SoundEffect.SOUND_PUNCH) or 0
        if sfx > 0 and Core.PlayRingSound then
            Core.PlayRingSound(sfx, isHeavy and 1.0 or 0.85, isHeavy and 0.88 or 1.05)
        end
    end

    -- Comic Sound Design: Solid-Light Crystallization / Shatter
    function Core.PlayCrystallizationSound(player)
        if Core.CONSTRUCT_SFX_ENABLED == false then return end
        local sfx = (SoundEffect and (SoundEffect.SOUND_GLASS_BREAK or SoundEffect.SOUND_TEARIMPACTS)) or 0
        if sfx > 0 and Core.PlayRingSound then
            Core.PlayRingSound(sfx, 0.80, 1.15)
        end
    end
end
