-- modules/synergies_virtues.lua -- RSI: Book of Virtues custom wisps (Power Battery, Giant Fist, Coast City, Gatling).
-- Responsabilidad unica: Book of Virtues wisps behaviour & Hard-Light construct tears. Sin Willpower, sin HUD.
return function(Core)
  local GL = Core.GL
  local WISP_VARIANT = (FamiliarVariant and FamiliarVariant.WISP) or 239

  local function IsGLWisp(familiar)
    if not familiar or familiar.Type ~= EntityType.ENTITY_FAMILIAR then return false end
    if familiar.Variant ~= WISP_VARIANT then return false end
    local sub = familiar.SubType
    if not sub or sub <= 0 then return false end
    return sub == Core.ITEM_POWER_BATTERY
        or sub == Core.ITEM_GIANT_FIST
        or sub == Core.ITEM_COAST_CITY
        or sub == Core.ITEM_GATLING
  end

  -- 1. FAMILIAR INIT: Set unique emerald tints, scales, and HP
  GL:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, function(_, familiar)
    if not IsGLWisp(familiar) then return end
    local fd = familiar:GetData()
    fd.isGLWisp = true
    fd.glWispType = familiar.SubType

    local sub = familiar.SubType
    pcall(function()
      if sub == Core.ITEM_POWER_BATTERY then
        familiar:GetSprite().Color = Color(0.25, 1.0, 0.45, 0.95, 0.15, 0.8, 0.2)
        familiar.MaxHitPoints = 6.0
        familiar.HitPoints = 6.0
      elseif sub == Core.ITEM_GIANT_FIST then
        familiar:GetSprite().Color = Color(0.12, 1.0, 0.35, 1.0, 0.2, 0.85, 0.25)
        familiar.Scale = 1.30
        familiar.MaxHitPoints = 8.0
        familiar.HitPoints = 8.0
      elseif sub == Core.ITEM_COAST_CITY then
        familiar:GetSprite().Color = Color(0.08, 0.85, 0.28, 0.95, 0.05, 0.55, 0.12)
        familiar.MaxHitPoints = 5.0
        familiar.HitPoints = 5.0
      elseif sub == Core.ITEM_GATLING then
        familiar:GetSprite().Color = Color(0.35, 1.0, 0.55, 1.0, 0.25, 0.9, 0.35)
        familiar.MaxHitPoints = 4.0
        familiar.HitPoints = 4.0
      end
    end)
  end, WISP_VARIANT)

  -- 2. FAMILIAR UPDATE: Unique behaviors and firing mechanics
  GL:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, function(_, familiar)
    local fd = familiar:GetData()
    if not (fd and fd.isGLWisp) then
      if IsGLWisp(familiar) then
        fd.isGLWisp = true
        fd.glWispType = familiar.SubType
      else
        return
      end
    end

    local sub = fd.glWispType or familiar.SubType
    local player = familiar.Player or (familiar.SpawnerEntity and familiar.SpawnerEntity:ToPlayer())
    local frame = Game():GetFrameCount()

    -- A. Power Battery Wisp: Emerald pulse deflects nearby projectiles every 90 frames
    if sub == Core.ITEM_POWER_BATTERY then
      if frame % 90 == 0 then
        pcall(function()
          local shock = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HALO, 0, familiar.Position, Vector.Zero, familiar)
          if shock then
            shock:GetSprite().Color = Color(0.2, 1.0, 0.4, 0.85, 0.1, 0.7, 0.15)
            shock.Scale = 1.1
          end
          for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PROJECTILE, -1, -1, false)) do
            local proj = ent:ToProjectile()
            if proj and not proj:IsDead() and (proj.Position - familiar.Position):Length() <= 65 then
              proj:Die()
            end
          end
        end)
      end

    -- B. Giant Fist Wisp: Extra contact damage against active enemies
    elseif sub == Core.ITEM_GIANT_FIST then
      if frame % 8 == 0 then
        for _, ent in ipairs(Isaac.GetRoomEntities()) do
          if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
            local diff = ent.Position - familiar.Position
            local d = diff:Length()
            if d <= (familiar.Size + (ent.Size or 16) + 6) then
              local dmg = player and (player.Damage * 2.5) or 10.0
              pcall(function()
                ent:TakeDamage(dmg, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(familiar), 0)
              end)
              if d > 0.01 then
                local push = diff:Normalized() * 5.0
                ent.Velocity = ent.Velocity + push
              end
            end
          end
        end
      end

    -- C. Coast City Wisp: Pulses Fear every 60 frames to nearest enemy within 130px
    elseif sub == Core.ITEM_COAST_CITY then
      if frame % 60 == 0 then
        pcall(function()
          for _, ent in ipairs(Isaac.GetRoomEntities()) do
            if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
              if (ent.Position - familiar.Position):Length() <= 130 then
                ent:AddFear(EntityRef(familiar), 45)
                ent:AddEntityFlags(EntityFlag.FLAG_FEAR)
              end
            end
          end
        end)
      end

    -- D. Gatling Wisp: Rapid Hard-Light construct shooting (every 18 frames)
    elseif sub == Core.ITEM_GATLING then
      if frame % 18 == 0 and player then
        local nearestEnemy = nil
        local nearestDist = 260
        for _, ent in ipairs(Isaac.GetRoomEntities()) do
          if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
            local d = (ent.Position - familiar.Position):Length()
            if d < nearestDist then
              nearestDist = d
              nearestEnemy = ent
            end
          end
        end
        if nearestEnemy then
          local diff = nearestEnemy.Position - familiar.Position
          local dir = diff:Length() > 0.01 and diff:Normalized() or Vector(1, 0)
          local tearVar = (TearVariant and TearVariant.DEFAULT) or 0
          local okSpawn, spawned = pcall(function()
            return Isaac.Spawn(EntityType.ENTITY_TEAR, tearVar, 0, familiar.Position, dir * 14.0, familiar)
          end)
          local ent = okSpawn and spawned or nil
          local tear = ent and ent:ToTear()
          if tear then
            tear.CollisionDamage = math.max(3.5, player.Damage * 0.75)
            if tear.AddTearFlags then
              tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
              tear:AddTearFlags(TearFlags.TEAR_PIERCING)
            elseif tear.TearFlags then
              pcall(function()
                tear.TearFlags = tear.TearFlags + (TearFlags and TearFlags.TEAR_SPECTRAL or 0) + (TearFlags and TearFlags.TEAR_PIERCING or 0)
              end)
            end
            tear.Visible = false
            pcall(function()
              if tear:GetSprite() then tear:GetSprite().Color = Color(0, 0, 0, 0) end
            end)
            if Core.ApplyRingBeamSprite then
              Core.ApplyRingBeamSprite(tear, 0.75)
            end
          end
        end
      end
    end
  end, WISP_VARIANT)

  -- 3. WISP TEAR STYLING: Stylize tears fired by GL wisps into emerald construct bolts
  GL:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
    local spawner = tear.SpawnerEntity
    if not spawner or spawner.Type ~= EntityType.ENTITY_FAMILIAR then return end
    local fd = spawner:GetData()
    if not (fd and fd.isGLWisp) then return end

    tear.Visible = false
    pcall(function()
      if tear:GetSprite() then tear:GetSprite().Color = Color(0, 0, 0, 0) end
    end)
    if Core.ApplyRingBeamSprite then
      Core.ApplyRingBeamSprite(tear, 0.80)
    end
    if fd.glWispType == Core.ITEM_COAST_CITY then
      if tear.AddTearFlags then
        tear:AddTearFlags(TearFlags.TEAR_FEAR)
        tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
      elseif tear.TearFlags then
        pcall(function()
          tear.TearFlags = tear.TearFlags + (TearFlags and TearFlags.TEAR_FEAR or 0) + (TearFlags and TearFlags.TEAR_SPECTRAL or 0)
        end)
      end
    end
  end)

  -- 4. WISP KILL: Battery drop chance on Power Battery wisp death
  GL:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, entity)
    if entity.Type ~= EntityType.ENTITY_FAMILIAR or entity.Variant ~= WISP_VARIANT then return end
    local fd = entity:GetData()
    if fd and fd.glWispType == Core.ITEM_POWER_BATTERY then
      if math.random() < 0.25 then
        pcall(function()
          local lilBatt = (PickupVariant and PickupVariant.PICKUP_LIL_BATTERY) or 90
          Isaac.Spawn(EntityType.ENTITY_PICKUP, lilBatt, 0, entity.Position, Vector.Zero, nil)
        end)
      end
    end
  end)
end
