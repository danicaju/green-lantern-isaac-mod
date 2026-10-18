-- modules/ring_aim.lua — RSI: punteria y sprite del rayo del anillo. Sin callbacks, sin combate.
-- Responsabilidad unica: direccion de apuntado, offsets de mano/spawn y sprite del beam.

return function(Core)
  -- Returns true when the firing direction (or player head direction) is pointing UPWARD
  function Core.IsAimingUp(player, fireVel)
    local dx, dy = 0, 1
    if fireVel and fireVel:Length() > 0.1 then
      local n = fireVel:Normalized()
      dx, dy = n.X, n.Y
    elseif player then
      local headDir = player:GetHeadDirection()
      if headDir == Direction.RIGHT then dx, dy = 1, 0
      elseif headDir == Direction.LEFT then dx, dy = -1, 0
      elseif headDir == Direction.UP then dx, dy = 0, -1
      else dx, dy = 0, 1 end
    end
    return (dy < 0) and (math.abs(dy) > math.abs(dx))
  end

  -- Compute the visual/screen-space offset of the character's outstretched Power Ring hand (for lasers & flares)
  function Core.GetRingHandOffset(player, fireVel)
    local headDir = player and player.GetHeadDirection and player:GetHeadDirection()
    local dx, dy = 0, 1
    if fireVel and fireVel:Length() > 0.1 then
      local n = fireVel:Normalized()
      dx, dy = n.X, n.Y
    else
      if headDir == Direction.RIGHT then dx, dy = 1, 0
      elseif headDir == Direction.LEFT then dx, dy = -1, 0
      elseif headDir == Direction.UP then dx, dy = 0, -1
      else dx, dy = 0, 1 end
    end

    -- Diagonal upward aiming: hand outstretched up and outward (away from head/face)
    if dy < -0.2 and math.abs(dx) > 0.2 then
      if dx > 0 then
        return Vector(16, -24) -- Outstretched right ring hand aiming up-right
      else
        return Vector(-16, -24) -- Outstretched left ring hand aiming up-left
      end
    end

    if math.abs(dx) >= math.abs(dy) then
      if dx >= 0 then
        return Vector(18, -14) -- Outstretched right ring hand clearly in front of player
      else
        return Vector(-18, -14) -- Outstretched left ring hand clearly in front of player
      end
    else
      if dy >= 0 then
        return Vector(6, -6) -- Outstretched ring hand aiming down in front of body
      else
        return Vector(0, -32) -- Centered behind the head when aiming up so the beam never overlaps or bleeds past the head/neck
      end
    end
  end

  -- Compute the ground-plane spawn offset for EntityTear beams.
  -- Note: EntityTear already renders at (Position.Y + Height * 0.65) where Height = -23.75 (~-15.4px screen Y).
  function Core.GetRingBeamTearSpawnOffset(player, fireVel)
    local headDir = player:GetHeadDirection()
    local dx, dy = 0, 1
    if fireVel and fireVel:Length() > 0.1 then
      local n = fireVel:Normalized()
      dx, dy = n.X, n.Y
    else
      if headDir == Direction.RIGHT then dx, dy = 1, 0
      elseif headDir == Direction.LEFT then dx, dy = -1, 0
      elseif headDir == Direction.UP then dx, dy = 0, -1
      else dx, dy = 0, 1 end
    end

    local dir = Vector(dx, dy)
    if dir:Length() > 0.01 then
      dir = dir:Normalized()
    else
      dir = Vector(0, 1)
    end

    if dy < -0.2 and math.abs(dx) > 0.2 then
      local sideX = (dx > 0) and 16 or -16
      return Vector(sideX, -16) + dir * 4
    end

    if math.abs(dx) >= math.abs(dy) then
      local sideX = (dx >= 0) and 18 or -18
      return Vector(sideX, 3) + dir * 4
    else
      if dy >= 0 then
        return Vector(6, 12) + dir * 4
      else
        return Vector(0, -24) + dir * 6
      end
    end
  end

  -- Transform a tear into an intense comic-book Green Lantern energy beam originating from the Ring
  function Core.ApplyRingBeamSprite(tear, scaleMult)
    if not tear then return end
    pcall(function()
      tear.DepthOffset = Core.IsAimingUp(nil, tear.Velocity) and -20 or 25
      tear.FallingAcceleration = -0.04
      tear.FallingSpeed = 0.0
      local ts = tear:GetSprite()
      if ts then
        ts:Load("gfx/effects/gl_ring_beam.anm2", true)
        ts:Play("Idle", true)
        local angle = (tear.Velocity and tear.Velocity:Length() > 0.01) and tear.Velocity:GetAngleDegrees() or 0.0
        ts.Rotation = angle
        local s = scaleMult or 1.0
        ts.Scale = Vector(s, s)
        ts.Color = Color(0, 0, 0, 0)
      end
      local td = tear:GetData()
      td.isGLRingBeam = true
      td.glBeamScale = scaleMult or 1.0
      if td.hasEnteredRoom == nil then
        td.hasEnteredRoom = not (Core.IsWallAtPos and Core.IsWallAtPos(tear.Position))
      end
      if tear.Velocity and tear.Velocity:Length() > 0.1 then
        td.glBeamVel = Vector(tear.Velocity.X, tear.Velocity.Y)
      end
      tear.Visible = false
    end)
  end

  -- Compute the orbital shield world position from the player's current aim
  -- and the shield orbit angle. Centralizes the orbital formula so collisions
  -- (modules/shield.lua) and future consumers share a single source of truth.
  --   facing = data.lastShootDir if set, else head-dir via GetHeadDirection()
  --   orbit  = Vector(cos(data.shieldOrbitAngle)*36, sin(data.shieldOrbitAngle)*24)
  --   result = player.Position + orbit*0.6 + facing*24
  function Core.GetShieldOrbitPos(player, data)
    if not (player and data) then return nil end
    local radX, radY = 36, 24
    local a = data.shieldOrbitAngle or 0
    local orbit = Vector(math.cos(a) * radX, math.sin(a) * radY)

    local facing = data.lastShootDir
    if not (facing and facing.X and facing.Y) then
      local headDir = player:GetHeadDirection()
      if headDir == Direction.RIGHT then facing = Vector(1, 0)
      elseif headDir == Direction.LEFT then facing = Vector(-1, 0)
      elseif headDir == Direction.UP then facing = Vector(0, -1)
      else facing = Vector(0, 1) end
    end

    return player.Position + orbit * 0.6 + facing * 24
  end

  -- Check if player has active homing tear modifiers or items
  function Core.HasHomingSynergy(player)
    if not player then return false end
    if player.HasHomingTypeTears and player:HasHomingTypeTears() then return true end
    if player.HasCollectible then
      local spoon = (CollectibleType and CollectibleType.COLLECTIBLE_SPOON_BENDER) or 3
      local heart = (CollectibleType and CollectibleType.COLLECTIBLE_SACRED_HEART) or 182
      local godhead = (CollectibleType and CollectibleType.COLLECTIBLE_GODHEAD) or 331
      if player:HasCollectible(spoon) or player:HasCollectible(heart) or player:HasCollectible(godhead) then
        return true
      end
    end
    local telepathy = (CollectibleType and CollectibleType.COLLECTIBLE_TELEPATHY_FOR_FOOLS) or 44
    if player.GetEffects and player:GetEffects() and player:GetEffects().HasCollectibleEffect and player:GetEffects():HasCollectibleEffect(telepathy) then
      return true
    end
    return false
  end

  -- Dynamically curves the continuous laser beam towards nearby active enemies within a forward cone
  function Core.GetHomingBeamDirection(player, startWorld, shootDir)
    if not shootDir then return Vector(1, 0) end
    local shootLen = math.sqrt(shootDir.X * shootDir.X + shootDir.Y * shootDir.Y)
    if shootLen < 0.01 then return Vector(1, 0) end
    local normSx, normSy = shootDir.X / shootLen, shootDir.Y / shootLen
    if not Core.HasHomingSynergy(player) then return Vector(normSx, normSy) end

    local bestDirX, bestDirY = nil, nil
    local bestScore = 0.65 -- ~49 degree frontal cone
    local maxDist = 450.0
    local sx, sy = (startWorld and startWorld.X) or 0, (startWorld and startWorld.Y) or 0

    if Isaac and Isaac.GetRoomEntities then
      for _, ent in ipairs(Isaac.GetRoomEntities()) do
        if ent and ent.Position and ent:Exists() and not ent:IsDead() and ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
          local dx = ent.Position.X - sx
          local dy = ent.Position.Y - sy
          local dist = math.sqrt(dx * dx + dy * dy)
          if dist > 8.0 and dist <= maxDist then
            local toX, toY = dx / dist, dy / dist
            local dot = normSx * toX + normSy * toY
            if dot > bestScore then
              bestScore = dot
              bestDirX, bestDirY = toX, toY
            end
          end
        end
      end
    end

    if bestDirX and bestDirY then
      local blend = 0.40
      local curvedX = normSx * (1.0 - blend) + bestDirX * blend
      local curvedY = normSy * (1.0 - blend) + bestDirY * blend
      local curLen = math.sqrt(curvedX * curvedX + curvedY * curvedY)
      if curLen > 0.01 then
        return Vector(curvedX / curLen, curvedY / curLen)
      end
    end

    return Vector(normSx, normSy)
  end
end
