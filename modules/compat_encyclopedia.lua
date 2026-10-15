-- modules/compat_encyclopedia.lua -- RSI: Encyclopedia mod integration (opcional). Sin gameplay propio.
-- Registra personajes, items, trinkets, sinergias y desafios DC en la enciclopedia de la comunidad.
return function(Core)
  local GL = Core.GL
  local registered = false

  -- Metadata descriptiva y reglas para los 4 desafios tematicos DC
  local CHALLENGE_INFOS = {
    [1] = {
      ID = 1,
      Name = "In Brightest Day",
      Character = "Hal Jordan",
      Goal = "Mom's Heart / It Lives (Stage 8)",
      Description = "Blindfolded Hal Jordan cannot shoot regular tears or beams. Relies on Solid Light Shield, Giant Fist, and Power Battery to overcome Isaac's horrors.",
      Difficulty = "Normal"
    },
    [2] = {
      ID = 2,
      Name = "Emerald Twilight",
      Character = "Hal Jordan -> Parallax",
      Goal = "Satan in Sheol (Stage 10)",
      Description = "Hal Jordan starts with The Tragedy of Coast City. Upon stepping into Sheol, the grief consumes him, transforming him into Parallax.",
      Difficulty = "Hard"
    },
    [3] = {
      ID = 3,
      Name = "Blackest Night",
      Character = "Parallax",
      Goal = "The Lamb in Dark Room (Stage 11)",
      Description = "Permanent Darkness & Curse of the Unknown. Parallax battles endless shadows; slain foes reanimate as Nekron's undead legions.",
      Difficulty = "Very Hard"
    },
    [4] = {
      ID = 4,
      Name = "Sinestro Corps War",
      Character = "Hal Jordan",
      Goal = "Mega Satan (Stage 12)",
      Description = "Hard mode cosmic war. Hal starts with Dad's Key, Power Ring, and full constructs against yellow Sinestro fear phantoms to slay Mega Satan.",
      Difficulty = "Nightmare"
    }
  }

  function Core.GetModChallengeInfo(chalId)
    if type(chalId) == "number" then
      if CHALLENGE_INFOS[chalId] then return CHALLENGE_INFOS[chalId] end
      if Isaac and Isaac.GetChallengeIdByName then
        for _, data in pairs(CHALLENGE_INFOS) do
          if Isaac.GetChallengeIdByName(data.Name) == chalId then
            return data
          end
        end
      end
    elseif type(chalId) == "string" then
      for _, data in pairs(CHALLENGE_INFOS) do
        if data.Name:lower() == chalId:lower() then
          return data
        end
      end
    end
    return nil
  end

  function Core.RegisterEncyclopedia()
    if registered or not Encyclopedia then return end

    pcall(function()
      -- 1. CHARACTERS
      if Core.PLAYER_HAL and Core.PLAYER_HAL >= 0 and Encyclopedia.AddCharacter then
        Encyclopedia.AddCharacter({
          Class = "Green Lantern",
          ModName = "Green Lantern Mod",
          Name = "Hal Jordan",
          Description = "Hal Jordan, Green Lantern of Sector 2814. Channels the Power Ring with Willpower. Tap to fire piercing emerald bolts, or hold to channel a continuous hard-light laser.",
          Quote = "In brightest day, in blackest night...",
          Sprite = "gfx/characters/hal_jordan.png",
          Unlock = "Unlocked by default"
        })
      end
      if Core.PLAYER_TAINTED_HAL and Core.PLAYER_TAINTED_HAL >= 0 and Encyclopedia.AddCharacter then
        Encyclopedia.AddCharacter({
          Class = "Green Lantern",
          ModName = "Green Lantern Mod",
          Name = "Parallax",
          Description = "Tainted Hal Jordan consumed by the fear entity Parallax. Cannot have red hearts. Defeating enemies spawns Green Lantern Emblems to fuel rage and steal power rings from angel statues.",
          Quote = "Fear the light of Parallax!",
          Sprite = "gfx/characters/tainted_hal.png",
          Unlock = "Unlocked by default"
        })
      end

      -- 2. ITEMS WITH SYNERGIES & WIKI DESCRIPTIONS
      local pools = Encyclopedia.ItemPools or {}
      if Core.ITEM_POWER_BATTERY and Core.ITEM_POWER_BATTERY > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_POWER_BATTERY,
          ModName = "Green Lantern Mod",
          Name = "Power Battery",
          Description = "Refills Willpower to 100% and releases a defensive emerald pulse. Overcharges the ring for +15% damage (or +25% with Car Battery).",
          WikiDescription = "Acts as a hard-light energy reservoir. Non-Hal characters trigger a massive emerald shockwave pushing and damaging all room enemies.",
          Synergies = {
            { Name = "Car Battery", Description = "Doubles the shockwave pulse and increases damage overcharge from +15% to +25%." },
            { Name = "9 Volt / The Battery", Description = "Greatly speeds up construct recharges and preserves overcharge battery energy." },
          },
          Pools = { pools.POOL_SHOP }
        })
      end
      if Core.ITEM_GIANT_FIST and Core.ITEM_GIANT_FIST > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_GIANT_FIST,
          ModName = "Green Lantern Mod",
          Name = "Giant Fist",
          Description = "Projects a colossal hard-light emerald fist dealing 10x player damage, destroying obstacles and piercing enemies.",
          WikiDescription = "Hal Jordan's signature boxing construct. Shatters tinted rocks, secret room walls, and crushes bosses in its path.",
          Synergies = {
            { Name = "Car Battery", Description = "Fires twin paired colossal emerald boxing fists side-by-side." },
            { Name = "Polyphemus", Description = "The emerald fist triples in physical size and deals catastrophic colossal impact damage." },
          },
          Pools = { pools.POOL_TREASURE }
        })
      end
      if Core.ITEM_COAST_CITY and Core.ITEM_COAST_CITY > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_COAST_CITY,
          ModName = "Green Lantern Mod",
          Name = "The Tragedy of Coast City",
          Description = "Inflicts Fear across the room and opens a 5s emerald vortex pulling enemies to its center.",
          WikiDescription = "Memorializing the destruction of Coast City. Sucks enemies and non-boss projectiles into a singularity of grief.",
          Synergies = {
            { Name = "Black Powder", Description = "Spinning around the vortex inscribes instant pentagrams of dark death." },
            { Name = "Dark Matter", Description = "Vortex pulses trigger dark fear explosions on trapped targets." },
          },
          Pools = { pools.POOL_DEVIL, pools.POOL_CURSE }
        })
      end
      if Core.ITEM_GATLING and Core.ITEM_GATLING > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_GATLING,
          ModName = "Green Lantern Mod",
          Name = "Gatling",
          Description = "Constructs a hard-light machine gun for 10s. Hal gains 0 Willpower cost; other characters gain maximum fire rate.",
          WikiDescription = "High-velocity emerald construct. Fires a relentless stream of hard-light bullets with heavy knockback.",
          Synergies = {
            { Name = "Soy Milk", Description = "Creates an uncontrollable wall of green hard-light plasma." },
            { Name = "Continuum", Description = "Hard-light bullets wrap endlessly around room boundaries." },
          },
          Pools = { pools.POOL_TREASURE, pools.POOL_SHOP }
        })
      end
      if Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_SOLID_LIGHT_SHIELD,
          ModName = "Green Lantern Mod",
          Name = "Solid Light Shield",
          Description = "Grants 2 Soul Hearts and an orbital shield that blocks enemy projectiles with a 25-75% chance to reflect them as hard-light beams.",
          WikiDescription = "Oan defensive construct. Reflect probability scales with player Luck stat (+5% per point of Luck).",
          Synergies = {
            { Name = "BFFS!", Description = "Enlarges the orbital shield radius and boosts reflection damage to 200%." },
            { Name = "The Wafer", Description = "Reflected lasers deal bonus holy damage to evil bosses." },
          },
          Pools = { pools.POOL_TREASURE, pools.POOL_ANGEL }
        })
      end
      if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_POWER_RING,
          ModName = "Green Lantern Mod",
          Name = "Green Lantern Ring",
          Description = "Willpower made manifest. Grants flight and channels piercing, spectral emerald hard-light beams from the hand.",
          WikiDescription = "The weapon of the Green Lantern Corps. Replaces normal tears with hard-light constructs and piercing beams.",
          Synergies = {
            { Name = "Brimstone", Description = "Fires a colossal piercing emerald brimstone beam dealing continuous damage." },
            { Name = "Technology", Description = "Beams manifest as ultra-dense hard-light laser lines crackling with sparks." },
            { Name = "Spoon Bender", Description = "Construct lasers curve and seek nearby targets automatically." },
            { Name = "Soy Milk", Description = "High-speed rapid-fire pulse beams with minimal willpower consumption." },
            { Name = "Polyphemus", Description = "A single gigantic emerald blast dealing overwhelming impact damage." },
          },
          Pools = { pools.POOL_PLANETARIUM, pools.POOL_ANGEL }
        })
      end

      -- 3. TRINKET
      if Core.TRINKET_YELLOW_IMPURITY and Core.TRINKET_YELLOW_IMPURITY > 0 and Encyclopedia.AddTrinket then
        Encyclopedia.AddTrinket({
          ID = Core.TRINKET_YELLOW_IMPURITY,
          ModName = "Green Lantern Mod",
          Name = "Yellow Impurity",
          Description = "+50% damage multiplier, but taking contact or explosion hits inflicts temporary Fear with inverted controls."
        })
      end

      -- 4. DC THEMED CHALLENGES
      if Encyclopedia.AddChallenge then
        for i = 1, 4 do
          local info = Core.GetModChallengeInfo(i)
          if info then
            Encyclopedia.AddChallenge({
              ModName = "Green Lantern Mod",
              Name = info.Name,
              Description = info.Description .. " [Goal: " .. info.Goal .. "]",
            })
          end
        end
      end

      -- 5. COMMUNITY MOD INTEGRATIONS: Specialist Dance & Pog for Good Items
      if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 then
        if SpecialistDance and SpecialistDance.RegisterItem then
          SpecialistDance:RegisterItem(Core.ITEM_POWER_RING, true)
        end
        if PogLite and PogLite.AddPogCostume then
          PogLite:AddPogCostume("GreenLanternRing", Core.ITEM_POWER_RING)
        end
      end

      registered = true
    end)
  end

  GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_)
    Core.RegisterEncyclopedia()
  end)
end
