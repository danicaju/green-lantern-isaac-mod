-- modules/stats.lua -- RSI: evaluacion de stats (MC_EVALUATE_CACHE). Sin HUD, sin combate, sin beams.
-- Responsabilidad unica: SECTION 5 STAT EVALUATION (Hal / Tainted / Ring / Yellow Impurity / Overcharge).
-- Separacion: solo lee Core (constantes + predicados + estado); no toca gfx ni XML.
-- Independencia: un solo callback; si Core.* falta, no rompe otros modulos.

return function(Core)
  local GL = Core.GL

  GL:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
    local data = Core.GetPlayerData(player)
    local roomIdx = Game():GetLevel():GetCurrentRoomIndex()

    -- HAL JORDAN STATS
    if Core.IsHalJordan(player) then
      if cacheFlag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed + Core.HAL_SPEED_BONUS
      end

      if cacheFlag == CacheFlag.CACHE_DAMAGE then
        if not data.ringDepleted then
          -- While the Power Ring is active, scale damage from 1.00x -> 1.15x (+0.10 peak bonus = 1.25x at 100% Willpower)
          local will = data.willpower or Core.WILLPOWER_MAX
          local willRatio = math.max(0.0, math.min(1.0, will / Core.WILLPOWER_MAX))
          local willMult = 1.00 + (0.15 * willRatio)
          if will >= 99.5 then
            willMult = willMult + 0.10 -- 1.25x DMG at 100% Willpower!
          end
          player.Damage = player.Damage * willMult
        end
        -- When ringDepleted is true, Hal loses the ability to use the Ring (no ring bonus, but NO harsh 50% damage nerf!)
      end

      if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        if not data.ringDepleted then
          player.ShotSpeed = player.ShotSpeed + Core.HAL_SHOT_SPEED_BONUS
        end
      end

      if cacheFlag == CacheFlag.CACHE_FLYING then
        if not data.ringDepleted then
          -- Track grants so depletion only revokes flight the Ring itself gave,
          -- preserving flight from items (e.g. Spirit Wings / Holy Mantle flight items).
          if not player.CanFly then
            data.ringGrantedFly = true
          end
          player.CanFly = true
        elseif data.ringGrantedFly then
          -- Ring depleted: revoke only the flight it previously granted.
          player.CanFly = false
          data.ringGrantedFly = false
        end
      end

      if cacheFlag == CacheFlag.CACHE_TEARFLAG then
        if not data.ringDepleted then
          -- All Green Lantern Ring energy beams pass through enemies and obstacles!
          player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
        end
      end
    end

    -- TAINTED HAL STATS (no passive or active damage scaling from Emblem meter / Coast City)
    if Core.IsTaintedHal(player) then
      if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage * Core.TAINTED_DMG_MULTIPLIER
        local rings = Core.GetPlayerData(player).stolenRings or 0
        if rings > 0 then
          player.Damage = player.Damage + math.min(rings, Core.MAX_STOLEN_RINGS) * Core.STOLEN_RING_DMG
        end
      end

      if cacheFlag == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = math.max(player.MaxFireDelay + math.abs(Core.TAINTED_TEARS_PENALTY) * 3, 6)
      end

      if cacheFlag == CacheFlag.CACHE_FLYING then
        player.CanFly = true
      end

      if cacheFlag == CacheFlag.CACHE_TEARFLAG then
        -- Tainted ya NO lleva Fear permanente: se aplica por probabilidad al impactar
        player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
      end
    end

    -- POWER BATTERY OVERCHARGE (applies to Hal Jordan when activating Power Battery at >=50% Willpower)
    if cacheFlag == CacheFlag.CACHE_DAMAGE then
      if Core.IsHalJordan(player) and not data.ringDepleted and data.overcharge and data.overchargeRoomIdx == roomIdx then
        local mult = (data.overchargeTier or 1) >= 2 and Core.OVERCHARGE_T2_MULT or Core.OVERCHARGE_T1_MULT
        player.Damage = player.Damage * mult
      end
    elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
      if not (Core.IsHalJordan(player) and data.ringDepleted) and (data.overcharge or data.surgeBuff) and data.overchargeRoomIdx == roomIdx then
        player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
      end
    end

    -- GREEN LANTERN RING (when picked up by non-Hal characters, grants +1.0 DMG, +0.20 ShotSpeed, Piercing & Spectral)
    if not Core.IsHalJordan(player) and not Core.IsTaintedHal(player) and Core.HasGreenLanternRing(player) then
      if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + 1.0
      elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        player.ShotSpeed = player.ShotSpeed + 0.20
      elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
        player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
      end
    end

    -- TRINKET: YELLOW IMPURITY DAMAGE BUFF
    if cacheFlag == CacheFlag.CACHE_DAMAGE then
      if Core.TRINKET_YELLOW_IMPURITY and player:HasTrinket(Core.TRINKET_YELLOW_IMPURITY) then
        player.Damage = player.Damage * 1.5
      end
    end
  end)
end
