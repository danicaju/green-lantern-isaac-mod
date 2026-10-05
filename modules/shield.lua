-- modules/shield.lua -- RSI: solo Solid Light Shield orbital + reflect. Sin Willpower, sin beam, sin sparks.
-- Responsabilidad unica: orbital construct shield, projectile reflection y aegis barrier. Estado via Core.*, sin globales sueltos.
return function(Core)
  local GL = Core.GL

  -- Active orbital construct shield: rotation, enemy projectile deflection, and contact construct damage
  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    if not Core.ITEM_SOLID_LIGHT_SHIELD or Core.ITEM_SOLID_LIGHT_SHIELD < 0 then Core.LoadItemIDs() end

    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if player and Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0 and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD) then
        local data = Core.GetPlayerData(player)
        -- Smooth isometric elliptical orbit around the player
        data.shieldOrbitAngle = (data.shieldOrbitAngle or 0) + 0.065
        -- Single source of truth for the shield world position (see Core.GetShieldOrbitPos).
        local shieldPos = Core.GetShieldOrbitPos(player, data)
        if not shieldPos then return end
        -- Compat: fx_shield_items.lua aún lee data.shieldWorldPos hasta que T4 lo migre.
        data.shieldWorldPos = shieldPos

        if data.shieldDeflectTimer and data.shieldDeflectTimer > 0 then
          data.shieldDeflectTimer = data.shieldDeflectTimer - 1
        end

        -- 1. Projectile blocking & reflection by the orbital shield
        for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PROJECTILE, -1, -1, false)) do
          local proj = ent:ToProjectile()
          if proj and proj:IsVulnerableEnemy() == false and not proj:IsDead() then
            local dist = (proj.Position - shieldPos):Length()
            if dist <= 22 then
              proj:Die()
              data.shieldDeflectTimer = 12

              pcall(function()
                SFXManager():Play(SoundEffect.SOUND_TEARS_FIRE, 0.9, 0, false, 1.35)
              end)

              -- Target nearest enemy if possible, else reverse projectile velocity or reflect outward
              local targetDir = -proj.Velocity:Normalized()
              local nearestDist = 320
              for _, enemy in ipairs(Isaac.GetRoomEntities()) do
                if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
                  local d = (enemy.Position - shieldPos):Length()
                  if d < nearestDist then
                    nearestDist = d
                    targetDir = (enemy.Position - shieldPos):Normalized()
                  end
                end
              end

              if targetDir:Length() < 0.1 then
                local fromPlayer = (shieldPos - player.Position)
                targetDir = fromPlayer:Length() > 0.1 and fromPlayer:Normalized() or Vector(1, 0)
              end

              local reflectSpeed = math.max(11.0, proj.Velocity:Length() * 1.25)
              local tearVar = (TearVariant and TearVariant.BLUE) or 0
              local refTear = Isaac.Spawn(EntityType.ENTITY_TEAR, tearVar, 0, shieldPos, targetDir * reflectSpeed, player)
              local t = refTear and refTear:ToTear()
              if t then
                t.CollisionDamage = math.max(player.Damage * 1.5, 6.0)
                t.TearFlags = t.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
                t:GetSprite().Color = Color(0.12, 1.0, 0.35, 1.0, 0.05, 0.60, 0.12)
                t.Scale = 1.25
              end

              pcall(function()
                local splash = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, shieldPos, Vector.Zero, player)
                if splash then
                  splash:GetSprite().Color = Color(0.1, 1.0, 0.4, 0.9, 0.15, 0.7, 0.15)
                  splash.Scale = 0.8
                end
              end)
            end
          end
        end

        -- 2. Contact construct damage on enemies colliding with orbital shield
        for _, ent in ipairs(Isaac.GetRoomEntities()) do
          if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
            local dist = (ent.Position - shieldPos):Length()
            local enemyRadius = ent.Size or 16
            if dist <= (enemyRadius + 16) then
              if Game():GetFrameCount() % 6 == 0 then
                ent:TakeDamage(player.Damage * 0.75 + 2.5, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
                local push = (ent.Position - shieldPos)
                if push:Length() > 0.1 then
                  ent.Velocity = ent.Velocity + push:Normalized() * 4.5
                end
                pcall(function()
                  SFXManager():Play(SoundEffect.SOUND_ROCK_CRUMBLE, 0.45, 0, false, 1.5)
                end)
              end
            end
          end
        end
      end
    end
  end)

  -- Direct player damage reflection (Luck-scaled chance to deflect enemy projectiles hitting the player)
  GL:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, flags, source)
    if entity.Type ~= EntityType.ENTITY_PLAYER then return end
    local player = entity:ToPlayer()
    if not player then return end
    if not Core.ITEM_SOLID_LIGHT_SHIELD or Core.ITEM_SOLID_LIGHT_SHIELD < 0 then Core.LoadItemIDs() end
    if not (Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0 and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD)) then return end

    if source and source.Entity and (source.Entity.Type == EntityType.ENTITY_PROJECTILE or source.Entity.Type == EntityType.ENTITY_TEAR) then
      local srcEnt = source.Entity
      local luck   = player.Luck
      local chance = math.min(0.25 + luck * 0.05, 0.75)

      if math.random() < chance then
        local data = Core.GetPlayerData(player)
        data.shieldDeflectTimer = 14

        pcall(function()
          SFXManager():Play(SoundEffect.SOUND_TEARS_FIRE, 1.0, 0, false, 1.35)
          local reflectVel = (player.Position - srcEnt.Position):Normalized() * (-srcEnt.Velocity:Length() * 1.2)
          local tearVar    = (TearVariant and TearVariant.BLUE) or 0
          local ent        = Isaac.Spawn(EntityType.ENTITY_TEAR, tearVar, 0, srcEnt.Position, reflectVel, player)
          local reflected  = ent and ent:ToTear()
          if reflected then
            reflected.CollisionDamage = player.Damage * 1.5
            reflected.TearFlags       = reflected.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
            reflected:GetSprite().Color = Color(0.12, 1.0, 0.35, 1.0, 0.05, 0.60, 0.12)
            reflected.Scale = 1.25
          end
          local splash = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, player.Position, Vector.Zero, player)
          if splash then
            splash:GetSprite().Color = Color(0.1, 1.0, 0.4, 0.9, 0.15, 0.7, 0.15)
            splash.Scale = 0.9
          end
        end)

        return false -- Block damage
      end
    end
  end)
end
