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
      ts:Load("gfx/effects/gl_ring_beam.anm2", true)
      ts:Play("Idle", true)
      local angle = (tear.Velocity and tear.Velocity:Length() > 0.01) and tear.Velocity:GetAngleDegrees() or 0.0
      ts.Rotation = angle
      local s = scaleMult or 1.0
      ts.Scale = Vector(s, s)
      ts.Color = Color(1, 1, 1, 1, 0, 0, 0)
      local td = tear:GetData()
      td.isGLRingBeam = true
      td.glBeamScale = s
      if tear.Velocity and tear.Velocity:Length() > 0.1 then
        td.glBeamVel = Vector(tear.Velocity.X, tear.Velocity.Y)
      end
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
end
