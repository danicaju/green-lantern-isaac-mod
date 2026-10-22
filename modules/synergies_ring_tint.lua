-- modules/synergies_ring_tint.lua -- RSI: identidad visual del beam esmeralda segun items del jugador.
-- Responsabilidad unica: mapear CollectibleType -> (tinte, escala) y combinarlos con precedencia documentada.
return function(Core)
    local function MakeColor(r, g, b, a, ro, go, bo)
        if Color then
            return Color(r, g, b, a, ro, go, bo)
        else
            return { R = r, G = g, B = b, A = a, RO = ro or 0, GO = go or 0, BO = bo or 0 }
        end
    end

    -- Declarative table guarded by runtime CollectibleType availability.
    -- Later entries in ORDER override earlier tintes (last-wins); scales always multiply.
    local ITEM_VISUALS = {}
    local ORDER = {}
    local function Add(id, tint, scale)
        if id then
            ITEM_VISUALS[id] = { tint = tint, scale = scale }
            table.insert(ORDER, id)
        end
    end

    if CollectibleType then
        Add(CollectibleType.COLLECTIBLE_SOY_MILK, MakeColor(0.75, 1.0, 0.8, 0.9, 0, 0, 0), 0.8)
        Add(CollectibleType.COLLECTIBLE_LOST_CONTACT, MakeColor(0.55, 1.0, 0.75, 1.0, 0, 0, 0), 1.15)
        Add(CollectibleType.COLLECTIBLE_MIDAS_TOUCH, MakeColor(1.0, 0.95, 0.35, 1.0, 0.55, 0.45, 0.05), 1.0)
        Add(CollectibleType.COLLECTIBLE_SACRED_HEART, MakeColor(1, 1, 1, 1, 0, 0, 0), 1.2)
        Add(CollectibleType.COLLECTIBLE_DEATHS_TOUCH, MakeColor(0.35, 0.95, 0.5, 1.0, 0, 0, 0), 1.15)
        Add(CollectibleType.COLLECTIBLE_8_INCH_NAILS, MakeColor(0.85, 1.0, 0.9, 1.0, 0, 0, 0), 1.4)
        Add(CollectibleType.COLLECTIBLE_TECHNOLOGY, MakeColor(0.75, 1.0, 0.9, 1.0, 0, 0.05, 0.1), 1.0)
        Add(CollectibleType.COLLECTIBLE_TECH_X, MakeColor(0.75, 1.0, 0.9, 1.0, 0, 0.05, 0.1), 1.0)
    end

    function Core.GetRingBeamVisual(player)
        local white = MakeColor(1, 1, 1, 1, 0, 0, 0)
        local scaleMul = 1.0
        if not player then
            return white, scaleMul
        end

        -- D1: blend multiplicativo suave. En vez de last-wins, acumulamos los
        -- tintes de los items poseidos y los combinamos: media geometrica de los
        -- canales RGB (para que Sacred Heart aclare sin borrar oro/verde) y
        -- media aritmetica de alpha y offset colors. Un solo item conserva su
        -- tinte exacto; sin items se devuelve blanco. La API (tint, scaleMul)
        -- no cambia.
        local ownedColors = {}
        for _, id in ipairs(ORDER) do
            local info = ITEM_VISUALS[id]
            if info then
                local has = false
                pcall(function()
                    if player.HasCollectible and player:HasCollectible(id) then
                        has = true
                    end
                end)
                if has then
                    scaleMul = scaleMul * info.scale
                    table.insert(ownedColors, info.tint)
                end
            end
        end

        local n = #ownedColors
        if n == 0 then
            return white, scaleMul
        elseif n == 1 then
            return ownedColors[1], scaleMul
        end

        local function clamp01(x)
            if x < 0 then return 0 end
            if x > 1 then return 1 end
            return x
        end

        local r, g, b = 1.0, 1.0, 1.0
        local a, ro, go, bo = 0.0, 0.0, 0.0, 0.0
        for _, c in ipairs(ownedColors) do
            r = r * (c.R or 1.0)
            g = g * (c.G or 1.0)
            b = b * (c.B or 1.0)
            a = a + (c.A or 1.0)
            ro = ro + (c.RO or 0.0)
            go = go + (c.GO or 0.0)
            bo = bo + (c.BO or 0.0)
        end
        local invN = 1.0 / n
        r = clamp01(r ^ invN)
        g = clamp01(g ^ invN)
        b = clamp01(b ^ invN)
        a = clamp01(a / n)
        ro = ro / n
        go = go / n
        bo = bo / n

        return MakeColor(r, g, b, a, ro, go, bo), scaleMul
    end
end
