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
        local tint = white
        local scaleMul = 1.0
        if not player then
            return tint, scaleMul
        end

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
                    tint = info.tint
                end
            end
        end

        return tint, scaleMul
    end
end
