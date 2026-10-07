-- modules/item_fist.lua -- RSI: solo Giant Fist (USE_ITEM + trail/rocas). Sin Willpower, sin beam, sin Coast City.
-- Responsabilidad unica: constructo puno gigante, trail esmeralda y destruccion de rocas. Estado via Core.*, sin globales sueltos.
return function(Core)
  local GL = Core.GL

  -- Giant Fist
  GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if not Core.ITEM_GIANT_FIST or Core.ITEM_GIANT_FIST < 0 then Core.LoadItemIDs() end
    if itemID ~= Core.ITEM_GIANT_FIST then return end

    -- When Hal's ring is offline at 0% Willpower, he cannot project Ring constructs!
    if Core.IsHalJordan(player) and Core.GetPlayerData(player).ringDepleted then
      local data = Core.GetPlayerData(player)
      data.oathText      = "RING OFFLINE!"
      data.oathTextTimer = 60
      pcall(function()
        local sfx = (SoundEffect and (SoundEffect.SOUND_BATTERYDISCHARGE or SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ)) or 0
        if sfx > 0 then
          SFXManager():Play(sfx, 0.80, 0, false, 1.0)
        end
      end)
      return { Discharge = false, Remove = false, ShowAnim = false }
    end

    local direction = player:GetShootingInput()
    if direction:Length() < 0.01 then
      local headDir = player:GetHeadDirection()
      local headVecs = {
        [Direction.LEFT]  = Vector(-1,  0),
        [Direction.RIGHT] = Vector( 1,  0),
        [Direction.UP]    = Vector( 0, -1),
        [Direction.DOWN]  = Vector( 0,  1),
      }
      direction = headVecs[headDir] or Vector(1, 0)
    else
      direction = direction:Normalized()
    end

    local spawnOffset  = Core.GetRingBeamTearSpawnOffset(player, direction)
    local fistVelocity = direction * 20.0
    local tearVar      = (TearVariant and TearVariant.TOOTH) or 0
    local ent = Isaac.Spawn(
      EntityType.ENTITY_TEAR,
      tearVar,
      0,
      player.Position + spawnOffset + direction * 10,
      fistVelocity,
      player
    )
    local fist = ent and ent:ToTear()

    if fist then
      fist.DepthOffset     = Core.IsAimingUp(player, direction) and -20 or 25
      fist.CollisionDamage = player.Damage * 10
      fist.Scale           = 3.5
      fist.TearFlags       = fist.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING | TearFlags.TEAR_MEGA
      Core.ApplyGiantFistSprite(fist)
      fist:GetData().isGiantFist = true
    end

    pcall(function()
      local vol = (Core.SFX_VOLUME_MULT or 1.0)
      SFXManager():Play(SoundEffect.SOUND_PUNCH, 1.0 * vol, 0, false, 0.85)
      if Core.SCREEN_SHAKE_ENABLED ~= false then Game():ShakeScreen(6) end
      local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, player.Position + spawnOffset, Vector.Zero, player)
      if fx then
        fx:GetSprite().Color = Color(0.1, 1.0, 0.35, 0.9, 0.1, 0.6, 0.15)
        fx.Scale = 0.9
      end
    end)

    return true
  end)

  -- Giant Fist update, emerald trail, & rock destruction with sound and debris
  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for _, tear in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, false)) do
      local td = tear:GetData()
      if td and td.isGiantFist then
        -- Trailing emerald construct smoke dust
        if Game():GetFrameCount() % 2 == 0 then
          pcall(function()
            local trail = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SMOKE_CLOUD, 0, tear.Position - tear.Velocity:Normalized() * 8, Vector.Zero, nil)
            if trail then
              trail:GetSprite().Color = Color(0.1, 1.0, 0.35, 0.65, 0.05, 0.5, 0.1)
              trail.Scale = 0.6
            end
          end)
        end

        local room = Game():GetRoom()
        local gridIdx = room:GetGridIndex(tear.Position)
        if gridIdx >= 0 then
          local gridEntity = room:GetGridEntity(gridIdx)
          if gridEntity then
            local gtype = gridEntity:GetType()
            if gtype == GridEntityType.GRID_ROCK
            or gtype == GridEntityType.GRID_ROCKB
            or gtype == GridEntityType.GRID_ROCKT
            or gtype == GridEntityType.GRID_ROCK_BOMB
            or gtype == GridEntityType.GRID_ROCK_ALT
            or gtype == GridEntityType.GRID_POOP then
              gridEntity:Destroy(false)
              pcall(function()
                local vol = (Core.SFX_VOLUME_MULT or 1.0)
                SFXManager():Play(SoundEffect.SOUND_ROCK_CRUMBLE, 1.0 * vol, 0, false, 1.0)
                if Core.SCREEN_SHAKE_ENABLED ~= false then Game():ShakeScreen(4) end
                local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, gridEntity.Position, Vector.Zero, nil)
                if poof then
                  poof:GetSprite().Color = Color(0.15, 1.0, 0.35, 0.85, 0.1, 0.6, 0.1)
                  poof.Scale = 0.8
                end
              end)
            end
          end
        end
      end
    end
  end)
end
