-- modules/tainted_rings.lua -- RSI: solo Stolen Rings de Tainted Hal (Angel Room).
-- Responsabilidad unica: marcar coleccionables Angel, consumir con DROP, orbitar y disparar.
-- Sin Willpower, sin beam, sin sparks, sin Coast City. Estado via Core.*, sin globales sueltos.
return function(Core)
  local GL = Core.GL

  GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    local room = Game():GetRoom()
    if room:GetType() ~= RoomType.ROOM_ANGEL then return end

    local hasTaintedHal = false
    for i = 0, Game():GetNumPlayers() - 1 do
      if Core.IsTaintedHal(Isaac.GetPlayer(i)) then
        hasTaintedHal = true
        break
      end
    end
    if not hasTaintedHal then return end

    for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false)) do
      ent:GetData().canBeConsumedByHal = true
    end
  end)

  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if Core.IsTaintedHal(player) then
        local data = Core.GetPlayerData(player)
        if data.ringConsumeCooldown and data.ringConsumeCooldown > 0 then
          data.ringConsumeCooldown = data.ringConsumeCooldown - 1
        end
        local isUsing = Input.IsActionPressed(ButtonAction.ACTION_DROP, player.ControllerIndex)
        if isUsing and not (data.ringConsumeCooldown and data.ringConsumeCooldown > 0) then
          for _, ent in ipairs(Isaac.FindInRadius(player.Position, 50, EntityPartition.PICKUP)) do
            local ed = ent:GetData()
            if ed and ed.canBeConsumedByHal then
              if (data.stolenRings or 0) >= Core.MAX_STOLEN_RINGS then
                pcall(function()
                  SFXManager():Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.8, 0, false, 1.0)
                end)
              else
                data.stolenRings = data.stolenRings + 1
                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                player:EvaluateItems()
              end
              data.ringConsumeCooldown = 15

              local flyVar = (FamiliarVariant and FamiliarVariant.BLUE_FLY) or 43
              local ring = Isaac.Spawn(
                EntityType.ENTITY_FAMILIAR,
                flyVar,
                0,
                player.Position,
                Vector.Zero,
                player
              ):ToFamiliar()

              if ring then
                local rd = ring:GetData()
                rd.isStolenRing = true
                rd.ringIndex    = data.stolenRings
                ring:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
              end

              ent:Remove()
              player:AnimateHappy()
              break
            end
          end
        end
      end
    end
  end)

  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    local currentFrame = Game():GetFrameCount()

    for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false)) do
      local fd = familiar:GetData()
      if fd and fd.isStolenRing then
        local owner = familiar.SpawnerEntity
        local player = owner and owner:ToPlayer()
        if player then
          local ringIdx   = fd.ringIndex or 1
          local orbitRad  = 40 + (ringIdx - 1) * 20
          local speed     = 0.12
          local angle     = currentFrame * speed + (ringIdx * math.pi / 2)
          local targetPos = player.Position + Vector(math.cos(angle) * orbitRad, math.sin(angle) * orbitRad)

          familiar.Position = targetPos
          familiar.Velocity = Vector.Zero
          Core.SetEntityScaleAndColor(familiar, 1.3, nil)

          if currentFrame % 25 == (ringIdx * 5) % 25 then
            local targetEnemy = nil
            local nearestDist = 400

            -- Prioritize Feared enemies, fallback to any vulnerable enemy
            for _, enemy in ipairs(Isaac.GetRoomEntities()) do
              if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
                local dist = (enemy.Position - familiar.Position):Length()
                local effectiveDist = enemy:HasEntityFlags(EntityFlag.FLAG_FEAR) and (dist * 0.5) or dist
                if effectiveDist < nearestDist then
                  nearestDist = effectiveDist
                  targetEnemy = enemy
                end
              end
            end

            if targetEnemy then
              local dir      = (targetEnemy.Position - familiar.Position):Normalized()
              local laserVel = dir * 18
              local tearVar  = (TearVariant and TearVariant.BLUE) or 0
              local ent      = Isaac.Spawn(
                EntityType.ENTITY_TEAR,
                tearVar,
                0,
                familiar.Position,
                laserVel,
                player
              )
              local laser    = ent and ent:ToTear()

              if laser then
                laser.CollisionDamage = player.Damage * 1.5
                laser.TearFlags       = laser.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
                laser:GetSprite().Color = Color(0, 1, 0.3, 1, 0, 0.6, 0)
              end
            end
          end
        end
      end
    end
  end)
end
