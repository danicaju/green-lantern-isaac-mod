-- modules/utils.lua -- RSI: utilidades puras sin estado (bitmask + sprite). Sin callbacks, sin globals, todo via Core.
return function(Core)
    -- Safe TearFlags bitmask test supporting both Repentance BitSet128 userdata and numeric bitmasks.
    -- (In Lua, comparing BitSet128 userdata to number 0 with `~= 0` is ALWAYS true!)
    function Core.HasTearFlag(flags, flag)
        if not flags or not flag then return false end
        local ok, res = pcall(function() return flags & flag end)
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
end
