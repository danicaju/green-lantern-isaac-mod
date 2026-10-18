-- modules/tainted_rings.lua -- RSI: solo Stolen Rings de Tainted Hal (Angel Room).
-- Responsabilidad unica: marcar coleccionables Angel, consumir con DROP, orbitar y disparar.
-- Sin Willpower, sin beam, sin sparks, sin Coast City. Estado via Core.*, sin globales sueltos.
return function(Core)
  local GL = Core.GL

  GL:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function(_)
    local room = Game and Game().GetRoom and Game():GetRoom()
    if room and room:GetType() == RoomType.ROOM_ANGEL then
      local hasTaintedHal = false
      for i = 0, Game():GetNumPlayers() - 1 do
        if Core.IsTaintedHal(Isaac.GetPlayer(i)) then
          hasTaintedHal = true
          break
        end
      end
      if hasTaintedHal then
        for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false)) do
          ent:GetData().canBeConsumedByHal = true
        end
      end
    end

    -- Ensure missing Stolen Ring familiars are respawned on room transition / Save & Continue
    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if player and Core.IsTaintedHal(player) then
        local data = Core.GetPlayerData(player)
        local targetCount = data.stolenRings or 0
        if targetCount > 0 then
          local currentRings = {}
          for _, familiar in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false)) do
            local fd = familiar:GetData()
            if fd and fd.isStolenRing and familiar.SpawnerEntity and familiar.SpawnerEntity.Index == player.Index then
              table.insert(currentRings, familiar)
            end
          end
          if #currentRings < targetCount then
            for rIdx = #currentRings + 1, targetCount do
              local flyVar = (FamiliarVariant and FamiliarVariant.BLUE_FLY) or 43
              local newRing = Isaac.Spawn(EntityType.ENTITY_FAMILIAR, flyVar, 0, player.Position, Vector.Zero, player)
              if newRing then
                local rd = newRing:GetData()
                rd.isStolenRing = true
                rd.ringIndex    = rIdx
                pcall(function()
                  if EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE then
                    newRing.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
                  end
                  newRing:AddEntityFlags(EntityFlag.FLAG_NO_TARGET)
                  newRing:GetSprite().Color = Color(0.1, 1.0, 0.4, 0.95, 0.1, 0.8, 0.2)
                end)
              end
            end
          end
        end
      end
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
              local maxRings = (Core.GetMaxStolenRings and Core.GetMaxStolenRings(player)) or Core.MAX_STOLEN_RINGS or 10
              if (data.stolenRings or 0) >= maxRings then
                pcall(function()
                  SFXManager():Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.8, 0, false, 1.0)
                end)
                data.ringConsumeCooldown = 15
                return
              end
              data.stolenRings = (data.stolenRings or 0) + 1
              player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
              player:EvaluateItems()
              data.ringConsumeCooldown = 15

              local flyVar = (FamiliarVariant and FamiliarVariant.BLUE_FLY) or 43
              local ring = Isaac.Spawn(
                EntityType.ENTITY_FAMILIAR,
                flyVar,
                0,
                player.Position,
                Vector.Zero,
                player
              )

              if ring then
                local rd = ring:GetData()
                rd.isStolenRing = true
                rd.ringIndex    = data.stolenRings
                pcall(function()
                  if EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE then
                    ring.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
                  end
                  ring:AddEntityFlags(EntityFlag.FLAG_NO_TARGET)
                  ring:GetSprite().Color = Color(0.1, 1.0, 0.4, 0.95, 0.1, 0.8, 0.2)
                end)
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
        -- F4: solo el Tainted real mueve y dispara sus anillos; huerfanos quedan inertes.
        if player and Core.IsTaintedHal(player) then
          pcall(function()
            if EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE then
              familiar.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
            end
          end)
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
              local diff     = targetEnemy.Position - familiar.Position
              local dir      = diff:Length() > 0.01 and diff:Normalized() or Vector(1, 0)
              local laserVel = dir * 18
              local tearVar  = (TearVariant and TearVariant.DEFAULT) or 0
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
                laser.Visible         = false
                pcall(function()
                  if laser:GetSprite() then laser:GetSprite().Color = Color(0, 0, 0, 0) end
                end)
                if Core.ApplyRingBeamSprite then
                  Core.ApplyRingBeamSprite(laser, 0.85)
                end
              end
            end
          end
        end
      end
    end
  end)
end
