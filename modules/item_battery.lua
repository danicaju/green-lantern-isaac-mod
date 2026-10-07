-- modules/item_battery.lua -- RSI: solo Power Battery + Lil Battery suelo. Sistema Willpower/Battery.
-- Responsabilidad unica: refill Willpower, overcharge/surge, pulso cercano. Estado via Core.*, sin globales.
return function(Core)
  local GL = Core.GL

  -- Active: Power Battery (refill 100% + overcharge condicional + pulso)
  GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if not Core.ITEM_POWER_BATTERY or Core.ITEM_POWER_BATTERY < 0 then Core.LoadItemIDs() end
    if itemID ~= Core.ITEM_POWER_BATTERY then return end

    local data = Core.GetPlayerData(player)
    local prevWill = data.willpower or Core.WILLPOWER_MAX
    local wasDepleted = data.ringDepleted

    data.overchargeRoomIdx = Game():GetLevel():GetCurrentRoomIndex()
    data.batteryConstructTimer = 45
    data.ringFlareTimer = 20

    local hasCarBattery = player.HasCollectible and player:HasCollectible((CollectibleType and CollectibleType.COLLECTIBLE_CAR_BATTERY) or 356)

    pcall(function()
      SFXManager():Play(SoundEffect.SOUND_BATTERYCHARGE, 1.0, 0, false, 1.0)
      SFXManager():Play(SoundEffect.SOUND_POWERUP_SPEWER, 0.85, 0, false, 1.2)
      local shock = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HALO, 0, player.Position, Vector.Zero, player)
      if shock then
        shock:GetSprite().Color = Color(0.15, 1.0, 0.35, 0.9, 0.1, 0.7, 0.15)
        shock.Scale = hasCarBattery and 2.6 or 1.8
      end
    end)

    local statusMsg = "WILLPOWER RESTORED!"
    if Core.IsHalJordan(player) then
      local vol = (Core.SFX_VOLUME_MULT or 1.0)
      if hasCarBattery or ((not wasDepleted) and prevWill >= Core.OVERCHARGE_T2_THRESHOLD) then
        data.overcharge = true
        data.overchargeTier = 2
        data.surgeBuff = false
        statusMsg = hasCarBattery and "CAR BATTERY DUAL OVERCHARGE! (+25% DMG)" or "OVERCHARGE MAX! (+25% DMG)"
        pcall(function()
          local sfx = (SoundEffect and SoundEffect.SOUND_HOLY) or 0
          if sfx > 0 then SFXManager():Play(sfx, 0.95 * vol, 0, false, 1.30) end
        end)
      elseif (not wasDepleted) and prevWill >= Core.OVERCHARGE_T1_THRESHOLD then
        data.overcharge = true
        data.overchargeTier = 1
        data.surgeBuff = false
        statusMsg = "OVERCHARGE! (+15% DMG)"
        pcall(function()
          local sfx = (SoundEffect and SoundEffect.SOUND_HOLY) or 0
          if sfx > 0 then SFXManager():Play(sfx, 0.85 * vol, 0, false, 1.20) end
        end)
      else
        data.overcharge = false
        data.overchargeTier = 0
        data.surgeBuff = true
      end
      local maxWillTarget = (Core.GetMaxWillpower and Core.GetMaxWillpower(player)) or Core.WILLPOWER_MAX
      if Core.RestoreHalRingPower then
        Core.RestoreHalRingPower(player, maxWillTarget, statusMsg)
      else
        data.willpower = maxWillTarget
      end
      -- T5: juramento poetico "IN BRIGHTEST DAY..." tras el refill (Hal).
      -- Convive con el statusMsg mecanico (que RestoreHalRingPower usa solo
      -- en reboot real via ring_state.lua); aqui siempre se sobreescribe el
      -- texto poetico del HUD.
      data.oathText      = "IN BRIGHTEST DAY..."
      data.oathTextTimer = 90
    else
      data.overcharge = true
      data.overchargeTier = 1
      data.surgeBuff = false
      player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
      player:EvaluateItems()
    end

    for _, ent in ipairs(Isaac.GetRoomEntities()) do
      local dist = (ent.Position - player.Position):Length()
      if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() and dist <= 110 then
        ent:TakeDamage(player.Damage * 1.0 + 3.0, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
        local push = (ent.Position - player.Position)
        if push:Length() > 0.1 then
          ent.Velocity = ent.Velocity + push:Normalized() * 9.5
        end
      elseif ent.Type == EntityType.ENTITY_PROJECTILE and dist <= 125 then
        ent:Die()
        pcall(function()
          local sp = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, ent.Position, Vector.Zero, player)
          if sp then
            sp:GetSprite().Color = Color(0.1, 1.0, 0.35, 0.8, 0.1, 0.6, 0.1)
            sp.Scale = 0.6
          end
        end)
      end
    end

    player:AnimateHappy()
    return true
  end)

  -- Pickup suelo: Lil Battery recarga Willpower segun subtype (1=50, 2=25 micro, 3/4=100 mega/golden)
  GL:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, function(_, pickup, collider, low)
    if pickup.Variant ~= PickupVariant.PICKUP_LIL_BATTERY then return end
    local player = collider:ToPlayer()
    if not player or not Core.IsHalJordan(player) then return end
    local data = Core.GetPlayerData(player)
    local refillAmount = 50.0
    if pickup.SubType == 3 or pickup.SubType == 4 then
      refillAmount = 100.0
    elseif pickup.SubType == 2 then
      refillAmount = 25.0
    end
    local maxW = (Core.GetMaxWillpower and Core.GetMaxWillpower(player)) or Core.WILLPOWER_MAX
    if Core.RestoreHalRingPower then
      Core.RestoreHalRingPower(player, newWill, "BATTERY RECHARGED!")
    else
      data.willpower = newWill
    end
    pcall(function()
      local vol = (Core.SFX_VOLUME_MULT or 1.0)
      local sfx = (SoundEffect and SoundEffect.SOUND_BATTERYCHARGE) or 0
      if sfx > 0 then SFXManager():Play(sfx, 0.85 * vol, 0, false, 1.1) end
    end)
  end)
end
