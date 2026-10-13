-- modules/compat_encyclopedia.lua -- RSI: Encyclopedia mod integration (opcional). Sin gameplay propio.
-- Registra personajes, items y trinkets en la enciclopedia de la comunidad si el mod esta presente.
return function(Core)
  local GL = Core.GL
  local registered = false

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

      -- 2. ITEMS
      local pools = Encyclopedia.ItemPools or {}
      if Core.ITEM_POWER_BATTERY and Core.ITEM_POWER_BATTERY > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_POWER_BATTERY,
          ModName = "Green Lantern Mod",
          Name = "Power Battery",
          Description = "Refills Willpower to 100% and releases a defensive emerald pulse. Overcharges the ring for +15% damage (or +25% with Car Battery).",
          Pools = { pools.POOL_SHOP }
        })
      end
      if Core.ITEM_GIANT_FIST and Core.ITEM_GIANT_FIST > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_GIANT_FIST,
          ModName = "Green Lantern Mod",
          Name = "Giant Fist",
          Description = "Projects a colossal hard-light emerald fist dealing 10x player damage, destroying obstacles and piercing enemies.",
          Pools = { pools.POOL_TREASURE }
        })
      end
      if Core.ITEM_COAST_CITY and Core.ITEM_COAST_CITY > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_COAST_CITY,
          ModName = "Green Lantern Mod",
          Name = "The Tragedy of Coast City",
          Description = "Inflicts Fear across the room and opens a 5s emerald vortex pulling enemies to its center.",
          Pools = { pools.POOL_DEVIL, pools.POOL_CURSE }
        })
      end
      if Core.ITEM_GATLING and Core.ITEM_GATLING > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_GATLING,
          ModName = "Green Lantern Mod",
          Name = "Gatling",
          Description = "Constructs a hard-light machine gun for 10s. Hal gains 0 Willpower cost; other characters gain maximum fire rate.",
          Pools = { pools.POOL_TREASURE, pools.POOL_SHOP }
        })
      end
      if Core.ITEM_SOLID_LIGHT_SHIELD and Core.ITEM_SOLID_LIGHT_SHIELD > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_SOLID_LIGHT_SHIELD,
          ModName = "Green Lantern Mod",
          Name = "Solid Light Shield",
          Description = "Grants 2 Soul Hearts and an orbital shield that blocks enemy projectiles with a 25-75% chance to reflect them as hard-light beams.",
          Pools = { pools.POOL_TREASURE, pools.POOL_ANGEL }
        })
      end
      if Core.ITEM_POWER_RING and Core.ITEM_POWER_RING > 0 and Encyclopedia.AddItem then
        Encyclopedia.AddItem({
          ID = Core.ITEM_POWER_RING,
          ModName = "Green Lantern Mod",
          Name = "Green Lantern Ring",
          Description = "Willpower made manifest. Grants flight and channels piercing, spectral emerald hard-light beams from the hand.",
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

      registered = true
    end)
  end

  GL:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_)
    Core.RegisterEncyclopedia()
  end)
end
