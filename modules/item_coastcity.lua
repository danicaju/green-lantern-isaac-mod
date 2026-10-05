-- modules/item_coastcity.lua -- RSI: solo The Tragedy of Coast City + vortex. Sin Willpower, sin beam, sin sparks.
-- Responsabilidad unica: active Coast City (vortex 5s, Fear + pull + pulso). Estado via Core.GetCoastCity(player), sin locales sueltos.
return function(Core)
  local GL = Core.GL

  -- The Tragedy of Coast City
  GL:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, itemID, rng, player, useFlags, activeSlot, varData)
    if not Core.ITEM_COAST_CITY or Core.ITEM_COAST_CITY < 0 then Core.LoadItemIDs() end
    if itemID ~= Core.ITEM_COAST_CITY then return end

    local data = Core.GetPlayerData(player)

    -- Stored Green Lantern Emblems slightly extend vortex duration & pull (NEVER increases player Damage!)
    local sparkRatio = math.max(0.0, math.min(1.0, (data.emeraldSparks or 0.0) / Core.SPARK_MAX))
    local sparkBonus = 1.0 + sparkRatio * 0.20
    local durationBonus = math.floor(sparkRatio * 45) -- up to +1.5s vortex duration at full meter
    data.coastCityBoost  = 1.0
    data.emeraldSparks   = 0.0
    data.coastCityActive = true
    data.coastCityFrame  = Game():GetFrameCount()
    data.ringFlareTimer  = 14

    local roomIdx = Game():GetLevel():GetCurrentRoomIndex()

    -- Store 5-second vortex state in this player's slot (co-op safe)
    local cc = Core.GetCoastCity(player)
    cc.active        = true
    cc.spawnFrame    = Game():GetFrameCount()
    cc.roomIdx       = roomIdx
    cc.owner         = player
    cc.sparkBonus    = sparkBonus
    cc.totalDuration = Core.COAST_CITY_DURATION + durationBonus

    -- T5: juramento poetico "I AM PARALLAX!" al activar Coast City (Tainted).
    if Core.IsTaintedHal(player) then
      data.oathText      = "I AM PARALLAX!"
      data.oathTextTimer = 90
    end

    pcall(function()
      SFXManager():Play(SoundEffect.SOUND_SUPERHOLY, 0.85, 0, false, 0.88)
      SFXManager():Play(SoundEffect.SOUND_HELL_PORTAL2, 0.70, 0, false, 1.30)
      Game():ShakeScreen(4)
    end)

    -- Inflict Fear (3s) and a light 0.50x DMG pulse to vulnerable enemies in the room
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
      if ent:IsActiveEnemy(false) and ent:IsVulnerableEnemy() then
        ent:AddFear(EntityRef(player), 90)
        ent:AddEntityFlags(EntityFlag.FLAG_FEAR)
        ent:TakeDamage(player.Damage * 0.50, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(player), 0)
      end
    end

    player:AnimateHappy()
    return true
  end)

  -- Coast City logic: gently pull vulnerable enemies toward center & deal light pulsing damage for 5 seconds
  local function RenderCoastCityVortex(cc, currentFrame, roomIdx)
    local age          = currentFrame - (cc.spawnFrame or currentFrame)
    local maxDuration  = cc.totalDuration or Core.COAST_CITY_DURATION

    if roomIdx ~= cc.roomIdx or age > maxDuration then
      cc.active = false
      -- Solo el dueno apaga su flag; el fallback cubre vortices legacy sin owner.
      if cc.owner then
        Core.GetPlayerData(cc.owner).coastCityActive = false
      else
        for i = 0, Game():GetNumPlayers() - 1 do
          local p = Isaac.GetPlayer(i)
          if Core.IsTaintedHal(p) then
            Core.GetPlayerData(p).coastCityActive = false
          end
        end
      end
      return
    end

    local room        = Game():GetRoom()
    local center      = room:GetCenterPos()
    local ownerPlayer = cc.owner or Isaac.GetPlayer(0)
    local sparkBonus  = cc.sparkBonus or 1.0

    -- Swirling emerald vortex construct particles
    pcall(function()
      if age % 2 == 0 then
        local rotAngle = (currentFrame * 0.14) + (math.random() * 6.28)
        local distR    = math.random(25, 200)
        local swirlPos = center + Vector(math.cos(rotAngle) * distR, math.sin(rotAngle) * distR)
        local swirlVel = Vector(-math.sin(rotAngle), math.cos(rotAngle)) * 4.0 - (swirlPos - center):Normalized() * 3.0
        local fx = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_SPLASH, 0, swirlPos, swirlVel, ownerPlayer)
        if fx then
          fx:GetSprite().Color = Color(0.1, 1.0, 0.4, 0.75, 0.1, 0.6, 0.15)
          fx.Scale = 0.45
        end
      end
    end)

    for _, enemy in ipairs(Isaac.GetRoomEntities()) do
      if enemy:IsActiveEnemy(false) and enemy:IsVulnerableEnemy() then
        local isFeared = enemy:HasEntityFlags(EntityFlag.FLAG_FEAR)
        local toCenter = (center - enemy.Position)
        local dist     = toCenter:Length()

        -- Pull vulnerable enemies within 250px gently toward the center
        if dist > 18 and dist <= 250 then
          local pullMult = isFeared and 1.15 or 1.0
          local pullStr  = math.min(3.8, 140.0 / math.max(dist, 22)) * pullMult * sparkBonus
          enemy.Velocity = enemy.Velocity * 0.85 + toCenter:Normalized() * pullStr
        end

        -- Deal light vortex damage every 25 frames
        if age > 0 and age % 25 == 0 and ownerPlayer and dist <= 220 then
          enemy:AddFear(EntityRef(ownerPlayer), 45)
          enemy:AddEntityFlags(EntityFlag.FLAG_FEAR)
          local distMult = (dist <= 100) and 0.35 or 0.20
          local dmg = ownerPlayer.Damage * distMult * sparkBonus
          enemy:TakeDamage(dmg, DamageFlag.DAMAGE_NO_MODIFIERS, EntityRef(ownerPlayer), 0)
        end
      end
    end
  end

  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    local currentFrame = Game():GetFrameCount()
    local roomIdx      = Game():GetLevel():GetCurrentRoomIndex()
    for _, cc in pairs(Core.activeCoastCityByPlayer) do
      if cc.active then
        RenderCoastCityVortex(cc, currentFrame, roomIdx)
      end
    end
  end)
end
