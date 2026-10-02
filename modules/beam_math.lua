-- modules/beam_math.lua -- RSI: matematicas del rayo continuo (disponibilidad, raycast, dano por tick). Sin callbacks, sin estado global, todo via Core.
-- Responsabilidad unica: CanUse/Stop, conteo de lagrimas por tap, ComputeContinuousBeamEndWorld y TickContinuousBeamDamage.

return function(Core)
  -- NOTA: sin alias locales de constantes: MCM puede cambiarlas en runtime.

  function Core.CanUseContinuousBeam(player)
    if not (Core.IsHalJordan(player) or Core.IsTaintedHal(player)) then return false end
    if not Core.IsRingActive(player) then return false end
    -- Allow charge/override weapons (Brimstone, Mom's Knife, Tech X, Technology, Monstro's Lung, etc.) to use their own mechanics
    if CollectibleType then
      local overrideItems = {
        CollectibleType.COLLECTIBLE_BRIMSTONE,
        CollectibleType.COLLECTIBLE_MOMS_KNIFE,
        CollectibleType.COLLECTIBLE_TECH_X,
        CollectibleType.COLLECTIBLE_TECHNOLOGY,
        CollectibleType.COLLECTIBLE_MONSTROS_LUNG,
        CollectibleType.COLLECTIBLE_CHOCOLATE_MILK,
        CollectibleType.COLLECTIBLE_CURSED_EYE,
        CollectibleType.COLLECTIBLE_EPIC_FETUS,
        CollectibleType.COLLECTIBLE_DR_FETUS,
        CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE,
        CollectibleType.COLLECTIBLE_SPIRIT_SWORD,
      }
      for _, itemId in ipairs(overrideItems) do
        if itemId and player:HasCollectible(itemId) then
          return false
        end
      end
    end
    return true
  end

  function Core.StopContinuousBeam(data)
    if not data then return end
    if data.continuousLaser and data.continuousLaser:Exists() then
      data.continuousLaser:Remove()
    end
    data.continuousLaser = nil
    data.isFiringContinuousBeam = false
    data.spawningContinuousBeam = false
  end

  function Core.GetTapTearCount(player)
    local count = 1
    if not (player and CollectibleType) then return count end
    pcall(function()
      if CollectibleType.COLLECTIBLE_QUAD_SHOT and player:HasCollectible(CollectibleType.COLLECTIBLE_QUAD_SHOT) then
        count = 4
      elseif CollectibleType.COLLECTIBLE_INNER_EYE and player:HasCollectible(CollectibleType.COLLECTIBLE_INNER_EYE) then
        count = 3
      end
      if CollectibleType.COLLECTIBLE_20_20 and player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) then
        local n20 = (player.GetCollectibleNum and player:GetCollectibleNum(CollectibleType.COLLECTIBLE_20_20)) or 1
        if count == 1 then
          count = 1 + math.max(1, n20)
        else
          count = count + math.max(1, n20)
        end
      end
      if PlayerForm and PlayerForm.PLAYERFORM_BABY and player.HasPlayerForm and player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then
        count = math.max(count, 3)
      end
    end)
    return math.min(count, 8)
  end

  -- Raycast from startWorld along dir across the current Room until hitting a wall (passing spectrally over rocks/pits)
  function Core.ComputeContinuousBeamEndWorld(startWorld, dir)
    if not startWorld then return Vector.Zero end
    local d = (dir and dir:Length() > 0.001) and dir:Normalized() or Vector(1, 0)
    local room = Game():GetRoom()
    if not room then
      return startWorld + d * 400.0
    end

    local function IsWallAt(p)
      if room.IsPositionInRoom and not room:IsPositionInRoom(p, 0) then
        return true
      end
      if room.GetGridCollisionAtPos and GridCollisionClass then
        local col = room:GetGridCollisionAtPos(p)
        if col == GridCollisionClass.COLLISION_WALL then
          return true
        end
      end
      return false
    end

    local maxDist = 1600.0
    local step = 8.0
    local hasEnteredRoom = not IsWallAt(startWorld)
    local lastValid = 0.0
    local hitDist = maxDist

    local dist = step
    while dist <= maxDist do
      local p = startWorld + d * dist
      if IsWallAt(p) then
        if hasEnteredRoom then
          hitDist = dist
          break
        elseif dist >= 80.0 then
          -- Started inside a wall margin while flying and aiming outward away from the room
          hitDist = 12.0
          break
        end
      else
        hasEnteredRoom = true
        lastValid = dist
      end
      dist = dist + step
    end

    if not hasEnteredRoom then
      return startWorld + d * 12.0
    end

    local lo = lastValid
    local hi = hitDist
    for _ = 1, 5 do
      local mid = (lo + hi) * 0.5
      if IsWallAt(startWorld + d * mid) then
        hi = mid
      else
        lo = mid
      end
    end

    local finalDist = math.max(12.0, (lo + hi) * 0.5)
    return startWorld + d * finalDist
  end

  -- Perform continuous emerald laser beam hit/damage logic directly in Lua on tick frames (every 4 frames)
  function Core.TickContinuousBeamDamage(player, data, startWorld, endWorld)
    local seg = endWorld - startWorld
    local segLen = seg:Length()
    if segLen < 1.0 then return end
    local segDir = seg / segLen

    local beamScale = Core.IsTaintedHal(player) and 1.25 or (data.overcharge and 1.35 or (data.surgeBuff and 1.15 or 1.0))
    local baseRadius = 18.0 * beamScale
    local tickDmg = (player.Damage or 3.5) * Core.HAL_CONTINUOUS_BEAM_DMG_MULT
    local applyFear = Core.IsTaintedHal(player)
      or (TearFlags and TearFlags.TEAR_FEAR and Core.HasTearFlag(player.TearFlags, TearFlags.TEAR_FEAR))
    local frame = Game():GetFrameCount()

    for _, ent in ipairs(Isaac.GetRoomEntities()) do
      if ent and ent:Exists() and not ent:IsDead() then
        local isEnemy = ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy()
        local isFire = (EntityType and ent.Type == EntityType.ENTITY_FIREPLACE)
          and (not ent.HitPoints or ent.HitPoints > 1.0)
        if isEnemy or isFire then
          local toEnt = ent.Position - startWorld
          local proj = toEnt.X * segDir.X + toEnt.Y * segDir.Y
          local clampedProj = math.max(0.0, math.min(segLen, proj))
          local closestPt = startWorld + segDir * clampedProj
          local perpDist = (ent.Position - closestPt):Length()
          local entRadius = math.max(8.0, ent.Size or 12.0)

          if perpDist <= (baseRadius + entRadius) then
            if isEnemy then
              local ed = ent.GetData and ent:GetData()
              if not (ed and ed.lastGLContBeamTickFrame == frame) then
                if ed then ed.lastGLContBeamTickFrame = frame end
                local fearMult = ent:HasEntityFlags(EntityFlag.FLAG_FEAR) and 1.25 or 1.0
                local tookDmg = ent:TakeDamage(tickDmg * fearMult, DamageFlag.DAMAGE_LASER, EntityRef(player), 0)
                if tookDmg ~= false then
                  if applyFear then
                    pcall(function()
                      ent:AddFear(EntityRef(player), 90)
                      ent:AddEntityFlags(EntityFlag.FLAG_FEAR)
                    end)
                  end
                  local splashPos = closestPt * 0.4 + ent.Position * 0.6
                  local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, splashPos, Vector.Zero, player)
                  Core.SetEntityScaleAndColor(fx, 0.45, Color(0.1, 1.0, 0.35, 0.85, 0.15, 0.85, 0.25))
                end
              end
            elseif isFire then
              pcall(function()
                ent:TakeDamage(tickDmg, DamageFlag.DAMAGE_LASER, EntityRef(player), 0)
              end)
            end
          end
        end
      end
    end

    -- Damage destroyable grid entities (GRID_POOP, GRID_TNT) along the beam ray (including lateral beam width)
    local room = Game():GetRoom()
    if room and GridEntityType then
      local visitedGrid = {}
      local perp = Vector(-segDir.Y, segDir.X)
      local edgeOffset = baseRadius * 0.75
      local offsets = { Vector.Zero, perp * edgeOffset, perp * (-edgeOffset) }
      local d = 0.0
      while d <= segLen do
        local basePos = startWorld + segDir * d
        for _, off in ipairs(offsets) do
          local samplePos = basePos + off
          local gridIdx = room:GetGridIndex(samplePos)
          if gridIdx and gridIdx >= 0 and not visitedGrid[gridIdx] then
            visitedGrid[gridIdx] = true
            local gridEnt = room:GetGridEntity(gridIdx)
            if gridEnt then
              local gtype = gridEnt:GetType()
              if gtype == GridEntityType.GRID_POOP or gtype == GridEntityType.GRID_TNT then
                pcall(function()
                  gridEnt:Hurt(1)
                end)
              end
            end
          end
        end
        if d >= segLen then break end
        d = math.min(segLen, d + 20.0)
      end
    end
  end
end
