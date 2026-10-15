-- modules/shield.lua -- RSI: solo Solid Light Shield orbital + reflect. Sin Willpower, sin beam, sin sparks.
-- Responsabilidad unica: orbital construct shield, projectile reflection y aegis barrier. Estado via Core.*, sin globales sueltos.
return function(Core)
  local GL = Core.GL

  -- SPEC-A: paso orbital a ritmo de render (60Hz). POST_UPDATE corre a ritmo
  -- logico (30Hz); avanzar 0.065 ahi mostraba cada posicion 2 frames seguidos
  -- (patron d,0,d,0 = trompicones). 0.0325 * 60 = 0.065 * 30 = 1.95 rad/s:
  -- misma velocidad angular/segundo, sin duplicar.
  local SHIELD_ORBIT_STEP_RENDER = 0.065 / 2
  local TWO_PI = math.pi * 2
  -- Flash Deflect: 12 frames en los 2 puntos de armado de shield.lua
  -- (literal 12, verificado por test_shield_orbit_flicker) + DEFLECT_DURATION
  -- en fx_shield_items.lua. Mantener los tres sincronizados.

  -- Helpers locales: evitan triplicar guards/lookups sin tocar comportamiento.
  local function EnsureShieldId()
    if not Core.ITEM_SOLID_LIGHT_SHIELD or Core.ITEM_SOLID_LIGHT_SHIELD < 0 then Core.LoadItemIDs() end
  end

  local function HasShield(player)
    return player
      and Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0
      and player:HasCollectible(Core.ITEM_SOLID_LIGHT_SHIELD)
  end

  local function ReflectChance(player)
    local chance = math.min(Core.SHIELD_REFLECT_BASE + player.Luck * Core.SHIELD_REFLECT_PER_LUCK, Core.SHIELD_REFLECT_MAX)
    return chance
  end

  local function HasBFFS(player)
    return player and player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_BFFS) or 247)
  end

  -- Active orbital construct shield: rotation, enemy projectile deflection, and contact construct damage
  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    EnsureShieldId()

    for i = 0, Game():GetNumPlayers() - 1 do
      local player = Isaac.GetPlayer(i)
      if HasShield(player) then
        local data = Core.GetPlayerData(player)
        -- SPEC-A: el angulo avanza en MC_POST_RENDER (60Hz); aqui solo se lee
        -- via Core.GetShieldOrbitPos (fuente unica con el render).
        local shieldPos = Core.GetShieldOrbitPos(player, data)
        if shieldPos then

        if data.shieldDeflectTimer and data.shieldDeflectTimer > 0 then
          data.shieldDeflectTimer = data.shieldDeflectTimer - 1
        end

        -- 1. Projectile blocking & reflection by the orbital shield
        -- Luck-scaled chance to deflect; on miss, mark the projectile so
        -- MC_ENTITY_TAKE_DMG knows it has already been "passed through"
        -- and skips its own redundant reflect roll.
        local reflectChance = ReflectChance(player)
        local hasBFFS = HasBFFS(player)
        local blockRadius = hasBFFS and 30 or 22
        for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PROJECTILE, -1, -1, false)) do
          local proj = ent:ToProjectile()
          if proj and proj:IsVulnerableEnemy() == false and not proj:IsDead() then
            local dist = (proj.Position - shieldPos):Length()
            if dist <= 22 or (hasBFFS and dist <= 30) then
              -- Skip proyectiles ya marcados: roll único por proyectil, evita que
              -- lentos dentro del radio se re-evaluen frame tras frame e
              -- inflen el bloqueo real por encima del 25-75% declarado.
              local ok, pData = pcall(function() return proj:GetData() end)
              local bypassBy = ok and pData and pData.glShieldBypassBy
              local bypassedForMe
              if bypassBy ~= nil then
                bypassedForMe = (bypassBy == player.Index)
              else
                bypassedForMe = ok and pData and pData.glShieldBypass == true
              end
              if not bypassedForMe then
                if math.random() >= reflectChance then
                  -- Roll failed: let the projectile pass through the orbital,
                  -- but remember it so the damage callback does not double-roll.
                  -- Bypass por-jugador (F7): glShieldBypassBy = player.Index.
                  -- Se mantiene glShieldBypass legacy como fallback single-player.
                  local byIndex = player.Index
                  pcall(function()
                    local d = proj:GetData()
                    if d then
                      d.glShieldBypass = true
                      d.glShieldBypassBy = byIndex
                    end
                  end)
                else
                  proj:Die()
                  data.shieldDeflectTimer = 12

                  pcall(function()
                    local vol = (Core.SFX_VOLUME_MULT or 1.0)
                    local sfxClink = (SoundEffect and (SoundEffect.SOUND_METAL_CLINK or SoundEffect.SOUND_SHIELD_DEFLECT)) or 0
                    if sfxClink > 0 then
                      SFXManager():Play(sfxClink, 0.85 * vol, 0, false, 1.25)
                    end
                    SFXManager():Play(SoundEffect.SOUND_TEARS_FIRE, 0.70 * vol, 0, false, 1.35)
                  end)

                  -- Target nearest enemy if possible, else reverse projectile velocity or reflect outward
                  local targetDir = (proj.Velocity and proj.Velocity:Length() > 0.1) and -proj.Velocity:Normalized() or nil
                  local nearestDist = 320
                  for _, enemy in ipairs(Isaac.GetRoomEntities()) do
                    if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
                      local diff = (enemy.Position - shieldPos)
                      local d = diff:Length()
                      if d < nearestDist and d > 0.01 then
                        nearestDist = d
                        targetDir = diff:Normalized()
                      end
                    end
                  end

                  if (not targetDir) or targetDir:Length() < 0.1 or targetDir.X ~= targetDir.X then
                    local fromPlayer = (shieldPos - player.Position)
                    targetDir = fromPlayer:Length() > 0.1 and fromPlayer:Normalized() or Vector(1, 0)
                  end

                  local reflectSpeed = math.max(11.0, proj.Velocity:Length() * 1.25)
                  local tearVar = (TearVariant and TearVariant.DEFAULT) or 0
                  local refTear = Isaac.Spawn(EntityType.ENTITY_TEAR, tearVar, 0, shieldPos, targetDir * reflectSpeed, player)
                  local t = refTear and refTear:ToTear()
                  if t then
                    local dmgMult = hasBFFS and 3.0 or 1.5
                    local minDmg = hasBFFS and 12.0 or 6.0
                    t.CollisionDamage = math.max((player.Damage * 1.5) * (hasBFFS and 2.0 or 1.0), minDmg)
                    t.TearFlags = t.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
                    t.Visible = false
                    pcall(function()
                      if t:GetSprite() then t:GetSprite().Color = Color(0, 0, 0, 0) end
                    end)
                    if Core.ApplyRingBeamSprite then
                      Core.ApplyRingBeamSprite(t, hasBFFS and 1.15 or 0.85)
                    end
                  end

                  pcall(function()
                    local splash = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, shieldPos, Vector.Zero, player)
                    if splash then
                      splash:GetSprite().Color = Color(0.1, 1.0, 0.4, 0.9, 0.15, 0.7, 0.15)
                      splash.Scale = hasBFFS and 1.1 or 0.8
                    end
                  end)
                end
              end
            end
          end
        end

        -- 2. Contact construct damage on enemies colliding with orbital shield
        local contactDmg = hasBFFS and (player.Damage * 1.5 + 5.0) or (player.Damage * 0.75 + 2.5)
        local pushForce = hasBFFS and 6.5 or 4.5
        for _, ent in ipairs(Isaac.GetRoomEntities()) do
          if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
            local dist = (ent.Position - shieldPos):Length()
            local enemyRadius = ent.Size or 16
            if dist <= (hasBFFS and (enemyRadius + 22) or (enemyRadius + 16)) then
              if Game():GetFrameCount() % 6 == 0 then
                ent:TakeDamage(contactDmg, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
                local push = (ent.Position - shieldPos)
                if push:Length() > 0.1 then
                  ent.Velocity = ent.Velocity + push:Normalized() * pushForce
                end
                pcall(function()
                  SFXManager():Play(SoundEffect.SOUND_ROCK_CRUMBLE, 0.45, 0, false, 1.5)
                end)
              end
            end
          end
        end
        end -- shieldPos válida; sin ella se salta solo este jugador (co-op)
      end
    end
  end)

  -- Direct player damage reflection (Luck-scaled chance to deflect enemy projectiles hitting the player)
  GL:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, flags, source)
    if entity.Type ~= EntityType.ENTITY_PLAYER then return end
    local player = entity:ToPlayer()
    EnsureShieldId()
    if not HasShield(player) then return end

    if source and source.Entity and (source.Entity.Type == EntityType.ENTITY_PROJECTILE or source.Entity.Type == EntityType.ENTITY_TEAR) then
      local srcEnt = source.Entity
      -- If the orbital already let this projectile through, skip the
      -- second roll entirely so it does not double-deflect or self-cancel.
      -- Bypass por-jugador (F7): solo exime si glShieldBypassBy coincide con
      -- el indice del jugador golpeado. Fallback legacy: flag global sin dueno.
      local okSrc, srcData = pcall(function() return srcEnt:GetData() end)
      if not okSrc then srcData = nil end
      local bypassBy = srcData and srcData.glShieldBypassBy
      if bypassBy ~= nil then
        if bypassBy == player.Index then
          return
        end
      elseif srcData and srcData.glShieldBypass == true then
        return
      end

      local chance = ReflectChance(player)

      if math.random() < chance then
        local data = Core.GetPlayerData(player)
        data.shieldDeflectTimer = 12
        data.shieldBlockedFrame = Game():GetFrameCount()

        pcall(function()
          local vol = (Core.SFX_VOLUME_MULT or 1.0)
          local sfxClink = (SoundEffect and (SoundEffect.SOUND_METAL_CLINK or SoundEffect.SOUND_SHIELD_DEFLECT)) or 0
          if sfxClink > 0 then
            SFXManager():Play(sfxClink, 0.90 * vol, 0, false, 1.20)
          end
          SFXManager():Play(SoundEffect.SOUND_TEARS_FIRE, 0.80 * vol, 0, false, 1.35)
          local hasBFFS = HasBFFS(player)
          local dmgMult = hasBFFS and 3.0 or 1.5
          local diff = srcEnt.Position - player.Position
          local dir = diff:Length() > 0.1 and diff:Normalized() or ((srcEnt.Velocity and srcEnt.Velocity:Length() > 0.1) and -srcEnt.Velocity:Normalized() or Vector(1, 0))
          local speed = math.max((srcEnt.Velocity and srcEnt.Velocity:Length() or 8.0) * 1.2, 9.0)
          local reflectVel = dir * speed
          local tearVar    = (TearVariant and TearVariant.DEFAULT) or 0
          local ent        = Isaac.Spawn(EntityType.ENTITY_TEAR, tearVar, 0, srcEnt.Position, reflectVel, player)
          local reflected  = ent and ent:ToTear()
          if reflected then
            reflected.CollisionDamage = math.max((player.Damage * 1.5) * (hasBFFS and 2.0 or 1.0), minDmg)
            reflected.TearFlags       = reflected.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING
            reflected.Visible         = false
            pcall(function()
              if reflected:GetSprite() then reflected:GetSprite().Color = Color(0, 0, 0, 0) end
            end)
            if Core.ApplyRingBeamSprite then
              Core.ApplyRingBeamSprite(reflected, hasBFFS and 1.15 or 0.85)
            end
          end
          local splash = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, player.Position, Vector.Zero, player)
          if splash then
            splash:GetSprite().Color = Color(0.1, 1.0, 0.4, 0.9, 0.15, 0.7, 0.15)
            splash.Scale = hasBFFS and 1.2 or 0.9
          end
        end)

        return false -- Block damage
      end
    end
  end)

  -- SPEC-A: avance suave del orbital a 60Hz (unica sede del avance).
  -- Misma fuente de posicion para render y colision (Core.GetShieldOrbitPos);
  -- sin caches divergentes. Se pausa con el juego (MC_POST_RENDER sigue
  -- disparando en pausa). Registrado en ultimo lugar para no alterar el
  -- orden de los callbacks existentes.
  if ModCallbacks.MC_POST_RENDER then
    GL:AddCallback(ModCallbacks.MC_POST_RENDER, function(_)
      local paused = false
      pcall(function() paused = Game():IsPaused() end)
      if paused then return end
      EnsureShieldId()

      for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if HasShield(player) then
          local data = Core.GetPlayerData(player)
          if data then
            -- Wrap 2pi: evita deriva de precision en sesiones largas; cos/sin
            -- son continuos en el wrap, la posicion no salta.
            data.shieldOrbitAngle = ((data.shieldOrbitAngle or 0) + SHIELD_ORBIT_STEP_RENDER) % TWO_PI
          end
        end
      end
    end)
  end
end
