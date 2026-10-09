-- modules/tainted_sparks.lua -- RSI: solo ciclo vida de Emerald Sparks (drops en suelo).
-- Responsabilidad unica: POST_NPC_DEATH, PRE_SPAWN_CLEAN_AWARD, POST_UPDATE pickup/lifetime.
-- Sin beam, sin Willpower pasivo, sin Coast City. Estado via Core.*, sin globales sueltos.
return function(Core)
  local GL = Core.GL

  -- Only spawn Green Lantern Emblem drops on actual enemy deaths (never on room transitions),
  -- with a significantly reduced drop rate (14% on Feared enemies, 8% on normal enemies).
  -- Also: if Hal Jordan's ring is depleted, defeating enemies with normal tears fuels his resolve (+5% Willpower per kill) to reboot the ring faster!
  GL:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, function(_, npc)
    if not npc or not npc:IsEnemy() or not npc:IsActiveEnemy(true) or (npc.MaxHitPoints and npc.MaxHitPoints <= 1) then return end

    local hasTaintedHal = false
    for i = 0, Game():GetNumPlayers() - 1 do
      local p = Isaac.GetPlayer(i)
      if Core.IsTaintedHal(p) then
        hasTaintedHal = true
        Core.GetPlayerData(p).lastSparkKillFrame = Game():GetFrameCount()
      elseif Core.IsHalJordan(p) then
        local d = Core.GetPlayerData(p)
        if d.ringDepleted then
          d.willpower = math.min(Core.WILLPOWER_MAX, (d.willpower or 0) + Core.WILLPOWER_KILL_REBOOT_BONUS)
          if d.willpower >= Core.WILLPOWER_REBOOT_THRESHOLD then
            Core.RestoreHalRingPower(p, d.willpower, "RING REBOOTED!")
          end
        end
      end
    end
    if not hasTaintedHal then return end

    local dropChance = npc:HasEntityFlags(EntityFlag.FLAG_FEAR) and Core.SPARK_DROP_CHANCE_FEARED or Core.SPARK_DROP_CHANCE_NORMAL
    if math.random() < dropChance then
      Core.SpawnLanternEmblemDrop(npc.Position)
    end
  end)

  -- Clearing a room while Hal's ring is depleted surges his willpower (+15%) to immediately help reboot the Power Ring!
  if ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD then
    GL:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, function(_)
      for i = 0, Game():GetNumPlayers() - 1 do
        local p = Isaac.GetPlayer(i)
        if Core.IsHalJordan(p) then
          local d = Core.GetPlayerData(p)
          if d.ringDepleted then
            d.willpower = math.min(Core.WILLPOWER_MAX, (d.willpower or 0) + Core.WILLPOWER_ROOM_REBOOT_BONUS)
            if d.willpower >= Core.WILLPOWER_REBOOT_THRESHOLD then
              Core.RestoreHalRingPower(p, d.willpower, "RING REBOOTED!")
            end
          end
        end
      end
    end)
  end

  GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
    if #Core.activeEmeraldSparks == 0 then return end

    local currentFrame = Game():GetFrameCount()
    local currentRoomIdx = Game():GetLevel():GetCurrentRoomIndex()

    for idx = #Core.activeEmeraldSparks, 1, -1 do
      local sp = Core.activeEmeraldSparks[idx]
      if not sp or sp.roomIdx ~= currentRoomIdx then
        table.remove(Core.activeEmeraldSparks, idx)
      elseif sp.collected then
        -- Play out the 12-frame coin/bomb style pickup animation, then remove!
        local collectAge = currentFrame - (sp.collectFrame or currentFrame)
        if collectAge < 0 or collectAge >= Core.SPARK_COLLECT_FRAMES then
          table.remove(Core.activeEmeraldSparks, idx)
        end
      else
        -- 1. Check walk-over pickup FIRST so any visible emblem on the floor immediately triggers pickup & grants meter!
        local pickedUpBy = nil
        for i = 0, Game():GetNumPlayers() - 1 do
          local player = Isaac.GetPlayer(i)
          if Core.IsTaintedHal(player) then
            local dist = (player.Position - sp.pos):Length()
            if dist <= Core.SPARK_PICKUP_RANGE then
              pickedUpBy = player
              break
            end
          end
        end

        if pickedUpBy then
          sp.collected = true
          sp.collectFrame = currentFrame

          local data = Core.GetPlayerData(pickedUpBy)
          data.emeraldSparks = math.min(Core.SPARK_MAX, (data.emeraldSparks or 0.0) + Core.SPARK_PER_KILL)

          -- If Emblem meter reaches 100% and Tainted Hal's active item needs charge, grant +1 charge bar!
          if data.emeraldSparks >= Core.SPARK_MAX then
            pcall(function()
              if Core.ITEM_COAST_CITY and pickedUpBy:GetActiveItem(ActiveSlot.SLOT_PRIMARY) == Core.ITEM_COAST_CITY then
                local curCharge = pickedUpBy:GetActiveCharge(ActiveSlot.SLOT_PRIMARY)
                if curCharge < 4 then
                  pickedUpBy:SetActiveCharge(curCharge + 1, ActiveSlot.SLOT_PRIMARY)
                  data.emeraldSparks = 0.0
                end
              end
            end)
          end

          -- Play crisp coin-style pickup chime while the emblem's Collect squash-and-stretch animation plays in front of the player
          pcall(function()
            local sfx = (SoundEffect and (SoundEffect.SOUND_PENNYPICKUP or SoundEffect.SOUND_PLOP or SoundEffect.SOUND_BEEP)) or 24
            SFXManager():Play(sfx, 0.75, 0, false, 1.18)
          end)
        else
          -- 2. If not walked over yet, check floor lifetime & vanish on the floor after SPARK_LIFETIME_FRAMES (6s)
          local ageFrames = currentFrame - (sp.spawnFrame or currentFrame)
          if ageFrames < 0 or ageFrames >= Core.SPARK_LIFETIME_FRAMES then
            table.remove(Core.activeEmeraldSparks, idx)
          end
        end
      end
    end
  end)

  -- Hambre de Parallax: sin kills el medidor decae (desactivado por balance, SPARK_DECAY_PER_SEC = 0)
  if Core.SPARK_DECAY_PER_SEC and Core.SPARK_DECAY_PER_SEC > 0 then
    GL:AddCallback(ModCallbacks.MC_POST_UPDATE, function(_)
      local frame = Game():GetFrameCount()
      for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if Core.IsTaintedHal(player) then
          local data = Core.GetPlayerData(player)
          if (data.emeraldSparks or 0) > 0
            and frame - (data.lastSparkKillFrame or -9999) > Core.SPARK_DECAY_GRACE_FRAMES then
            data.emeraldSparks = math.max(0, data.emeraldSparks - Core.SPARK_DECAY_PER_SEC / 30)
          end
        end
      end
    end)
  end
end
