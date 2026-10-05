-- modules/fx_sprites.lua -- RSI: HUD font + EID/inspection + caches de sprites GL. Sin callbacks, sin globals, todo via Core.
return function(Core)
    local hudFont = nil
    function Core.GetHudFont()
        if not hudFont and Font then
            local f = Font()
            local ok = pcall(function() f:Load("font/luaminioutlined.fnt") end)
            if ok and f:IsLoaded() then
                hudFont = f
            end
        end
        return hudFont
    end

    function Core.DrawHudText(text, x, y, r, g, b, a)
        local f = Core.GetHudFont()
        if f and KColor then
            f:DrawStringScaled(text, x, y, 1.0, 1.0, KColor(r, g, b, a), 0, false)
        else
            Isaac.RenderScaledText(text, x, y, 0.5, 0.5, r, g, b, a)
        end
    end

    local eidRegistered = false
    function Core.EnsureEIDRegistered()
        if eidRegistered or not EID then return end
        Core.LoadItemIDs()
        if not Core.ITEM_POWER_BATTERY or Core.ITEM_POWER_BATTERY < 0 then return end
        pcall(function()
            for _, lang in ipairs({"en_us", "en_us_detailed", "es"}) do
                EID:addCollectible(Core.ITEM_POWER_BATTERY,
                    "Refills Willpower to 100% and unleashes a close-range emerald pulse#At >=50% Willpower: Overcharge (+15% DMG + Piercing + Spectral for the room)#Below 50%: Restores Willpower & Ring capabilities",
                    "Power Battery", lang)
                EID:addCollectible(Core.ITEM_GIANT_FIST,
                    "Fires a massive spectral piercing emerald fist#Deals 10x Player Damage and smashes rocks & obstacles",
                    "Giant Fist", lang)
                EID:addCollectible(Core.ITEM_COAST_CITY,
                    "Inflicts Fear (3s) and spawns a 5s Emerald Vortex that pulls nearby enemies toward the center#Collecting Green Lantern Emblems recharges the item and extends vortex duration",
                    "The Tragedy of Coast City", lang)
                if Core.ITEM_GATLING and Core.ITEM_GATLING > 0 then
                    EID:addCollectible(Core.ITEM_GATLING,
                        "10s of rapid-fire emerald beams with no Willpower cost",
                        "Gatling", lang)
                end
                EID:addCollectible(Core.ITEM_SOLID_LIGHT_SHIELD,
                    "+2 Soul Hearts#Grants an orbital shield that blocks shots#25%-75% chance (scales with Luck) to reflect enemy projectiles as spectral beams",
                    "Solid Light Shield", lang)
                if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 then
                    EID:addCollectible(Core.ITEM_POWER_RING,
                        "Signature Green Lantern Power Ring worn on your hand#Tap/click to fire high-damage piercing & spectral emerald bolts#Hold fire to channel a continuous lower-damage emerald laser beam",
                        "Green Lantern Ring", lang)
                end
                if Core.TRINKET_YELLOW_IMPURITY and Core.TRINKET_YELLOW_IMPURITY > 0 then
                    EID:addTrinket(Core.TRINKET_YELLOW_IMPURITY,
                        "1.5x Damage multiplier (+50% DMG)#Taking contact or explosion damage briefly inflicts Fear (reversed movement for 2s)",
                        "Yellow Impurity", lang)
                end
            end
            eidRegistered = true
        end)
    end

    function Core.GetModItemInspectionInfo(isTrinket, id)
        if not Core.ITEM_POWER_BATTERY or Core.ITEM_POWER_BATTERY < 0 then Core.LoadItemIDs() end
        if not isTrinket then
            if id == Core.ITEM_POWER_BATTERY then
                return "Power Battery [4R Active]", {
                    "Refills 100% Willpower + close emerald pulse",
                    ">=50% Will: +15% Overcharge DMG for room"
                }
            elseif id == Core.ITEM_GIANT_FIST then
                return "Giant Fist [4R Active]", {
                    "Fires a giant piercing 10x DMG emerald fist",
                    "Smashes rocks, poop, and obstacles in its path"
                }
            elseif id == Core.ITEM_GATLING then
                return "Gatling [4R Active]", {
                    "10s rapid-fire emerald beams, no Willpower cost",
                    "Click fast while it lasts"
                }
            elseif id == Core.ITEM_COAST_CITY then
                return "The Tragedy of Coast City [4R Active]", {
                    "Fears enemies & pulls them into a 5s vortex",
                    "Lantern Emblems recharge & extend the vortex"
                }
            elseif id == Core.ITEM_SOLID_LIGHT_SHIELD then
                return "Solid Light Shield [Passive]", {
                    "+2 Soul Hearts & orbital light shield",
                    "25%-75% chance (Luck) to reflect enemy shots"
                }
            elseif id == Core.ITEM_POWER_RING then
                return "Green Lantern Ring [Starting Passive]", {
                    "Click: high-DMG small beams | Hold: continuous beam",
                    "Piercing & spectral emerald energy from your ring"
                }
            end
        else
            if id == Core.TRINKET_YELLOW_IMPURITY then
                return "Yellow Impurity [Trinket]", {
                    "1.5x Damage Multiplier (+50% Damage Up)",
                    "Contact/explosion hits cause 2s Fear reversal"
                }
            end
        end
        return nil, nil
    end

    local glAuraSprite             = nil
    local glFlareSprite            = nil
    local glSparkSprite            = nil
    local glContBeamSprite         = nil
    local glSolidShieldOrbitalSprite = nil  -- dedicated to "Orbit"/"Deflect" animations
    local glSolidShieldAuraSprite    = nil  -- dedicated to "Aura" animation
    local glBatteryConstructSprite = nil
    local glYellowFearSprite       = nil

    function Core.GetGLAuraSprites()
        if not glAuraSprite and Sprite then
            local s1 = Sprite()
            local ok1 = pcall(function()
                s1:Load("gfx/effects/gl_aura.anm2", true)
                s1:Play("HalAura", true)
            end)
            if ok1 then
                glAuraSprite = s1
            end
        end
        if not glFlareSprite and Sprite then
            local s2 = Sprite()
            local ok2 = pcall(function()
                s2:Load("gfx/effects/gl_aura.anm2", true)
                s2:Play("RingFlare", true)
            end)
            if ok2 then
                glFlareSprite = s2
            end
        end
        return glAuraSprite, glFlareSprite
    end

    function Core.GetGLContBeamSprite()
        if not glContBeamSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_ring_beam.anm2", true)
                s:Play("ContinuousBeam", true)
            end)
            if ok then
                glContBeamSprite = s
            end
        end
        return glContBeamSprite
    end

    function Core.GetGLSparkSprite()
        if not glSparkSprite and Sprite then
            local s3 = Sprite()
            local ok3 = pcall(function()
                s3:Load("gfx/effects/gl_lantern_spark.anm2", true)
                s3:Play("Idle", true)
            end)
            if ok3 then
                glSparkSprite = s3
            end
        end
        return glSparkSprite
    end

    -- Two separate sprite instances for the shield so the aura and the orbital
    -- never fight over animation state within the same render frame.
    function Core.GetGLSolidShieldOrbitalSprite()
        if not glSolidShieldOrbitalSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_solid_shield.anm2", true)
                s:Play("Orbit", true)
            end)
            if ok then
                glSolidShieldOrbitalSprite = s
            end
        end
        return glSolidShieldOrbitalSprite
    end

    function Core.GetGLSolidShieldAuraSprite()
        if not glSolidShieldAuraSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_solid_shield.anm2", true)
                s:Play("Aura", true)
            end)
            if ok then
                glSolidShieldAuraSprite = s
            end
        end
        return glSolidShieldAuraSprite
    end

    -- Legacy alias: some old code paths may call GetGLSolidShieldSprite().
    -- Route them to the orbital sprite to avoid nil errors.
    function Core.GetGLSolidShieldSprite()
        return Core.GetGLSolidShieldOrbitalSprite()
    end

    function Core.GetGLBatteryConstructSprite()
        if not glBatteryConstructSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_power_battery_construct.anm2", true)
                s:Play("Pulse", true)
            end)
            if ok then
                glBatteryConstructSprite = s
            end
        end
        return glBatteryConstructSprite
    end

    function Core.GetGLYellowFearSprite()
        if not glYellowFearSprite and Sprite then
            local s = Sprite()
            local ok = pcall(function()
                s:Load("gfx/effects/gl_yellow_fear.anm2", true)
                s:Play("FearSkull", true)
            end)
            if ok then
                glYellowFearSprite = s
            end
        end
        return glYellowFearSprite
    end

    -- T6: swap the tear's sprite for the custom Giant Fist anm2 so the construct
    -- looks like a giant emerald fist instead of a tinted tooth. Caller is
    -- modules/item_fist.lua (right after spawn). Hardcodes the only allowed path.
    function Core.ApplyGiantFistSprite(tear)
        if not tear then return end
        pcall(function()
            local ts = tear:GetSprite()
            ts:Load("gfx/effects/gl_giant_fist.anm2", true)
            ts:Play("Idle", true)
            local vel = tear.Velocity
            local speed = (vel and vel:Length()) or 0.0
            ts.Rotation = (speed > 0.01) and vel:GetAngleDegrees() or 0.0
            local td = tear:GetData()
            td.isGLFist = true
        end)
    end
end
