---
name: isaac-mod-dev
description: Specialized skill for developing, debugging, testing, and creating pixel art for The Binding of Isaac: Repentance and Repentance+ mods. Covers Lua API callbacks, entity manipulation, coordinate math, sprite sheets, XML configs, and automated synchronization.
---

# The Binding of Isaac: Repentance+ Mod Development Guide

This skill provides comprehensive instructions, API cheat sheets, rendering mathematics, and authoring guidelines for developing mods for **The Binding of Isaac: Repentance / Repentance+**.

---

## 1. Mod Architecture & File Layout

A standard Repentance+ mod follows this directory structure:

```
mod_root/
├── metadata.xml                # Mod title, version, description, visibility
├── main.lua                    # Entry point (registers mod, loads modules)
├── GEMINI.md                   # Automated workspace development rules
├── modules/                    # Modular Lua subsystems (RSI pattern)
│   ├── core.lua                # Shared state, constants, helper functions
│   ├── firing_mode.lua         # Attack behaviors, click vs hold logic
│   ├── fx_beam.lua             # Raycasts, laser visuals, flares
│   ├── fx_shield_items.lua     # Orbitals, barrier rendering
│   ├── hud_render.lua          # HUD overlays, custom meters, render callbacks
│   ├── stats.lua               # MC_EVALUATE_CACHE stat adjustments
│   └── item_*.lua              # Individual active/passive item implementations
├── content/                    # Game XML declarations
│   ├── players.xml             # Characters (normal & tainted), base HP, costumes
│   ├── items.xml               # Collectibles (actives & passives), charge counts
│   ├── trinkets.xml            # Trinkets
│   └── itempools.xml           # Item pool distributions & weights
├── resources/                  # Assets loaded by the engine
│   └── gfx/
│       ├── characters/         # Character sprite sheets (128x256, 512x512) & costumes (.anm2)
│       ├── items/collectibles/ # 32x32 item pedestal/HUD sprites
│       ├── items/trinkets/     # 16x16 trinket sprites
│       ├── ui/boss/            # Boss VS screen portraits (258x190) & names (192x64)
│       └── ui/stage/           # Stage transition icons (100x100)
└── tools/                      # Test suites (test_*.lua) & Python asset generators
```

---

## 2. Isaac Lua API Reference & Callbacks

### Key Callbacks Cheat Sheet

| Callback Enum | Arguments | Return Value | Purpose |
| :--- | :--- | :--- | :--- |
| `MC_POST_UPDATE` | `(mod)` | void | Runs once per logic frame (30 Hz). Game logic, timers, AI. |
| `MC_POST_RENDER` | `(mod)` | void | Runs once per render frame (60 Hz). Screen-space UI, smooth animations. |
| `MC_PRE_PLAYER_RENDER` | `(mod, player, renderOffset)` | bool/nil | Before player is drawn. Background orbitals, under-player auras. |
| `MC_POST_PLAYER_RENDER` | `(mod, player, renderOffset)` | void | After player is drawn. Foreground orbitals, active item effects, text. |
| `MC_EVALUATE_CACHE` | `(mod, player, cacheFlag)` | void | Evaluate stats when `player:AddCacheFlags()` is called. |
| `MC_USE_ITEM` | `(mod, itemID, rng, player, useFlags, activeSlot, varData)` | bool/table | Triggers on active item use (Spacebar). |
| `MC_POST_FIRE_TEAR` | `(mod, tear)` | void | Runs whenever the player fires a projectile/tear. |
| `MC_ENTITY_TAKE_DMG` | `(mod, entity, amount, flags, source, countdown)` | bool/nil | Return `false` to block/cancel damage. |
| `MC_POST_ENTITY_REMOVE`| `(mod, entity)` | void | Triggered when an enemy/tear/pickup is destroyed or killed. |

### Essential `EntityPlayer` Methods
- `player:HasCollectible(CollectibleType)`: Checks if player holds a passive or active collectible.
- `player:HasTrinket(TrinketType)`: Checks if player holds a trinket.
- `player:AddCacheFlags(CacheFlag)`: Flags stats to be recalculated. Must call `player:EvaluateItems()` right after.
- `player:EvaluateItems()`: Triggers `MC_EVALUATE_CACHE`.
- `player:GetHeadDirection()`: Returns `Direction.LEFT`, `Direction.RIGHT`, `Direction.UP`, `Direction.DOWN`.
- `player:CanFly`: Boolean property for flight status.
- `player:AnimateHappy()` / `player:AnimateSad()`: Plays standard item pickup / hurt animations.

---

## 3. Coordinate Spaces & Rendering Mathematics

### World vs Screen Coordinates
The game operates across distinct coordinate planes:
1. **World Space**: Coordinates where entities and grid tiles exist (`entity.Position`).
2. **Screen Space**: Pixel coordinates of the user's game window.
3. **Render Space**: Internal room rendering plane.

### Critical Rule for `MC_POST_PLAYER_RENDER`
```lua
-- CORRECT:
local screenPos = Isaac.WorldToScreen(worldPos)
sprite:Render(screenPos, Vector.Zero, Vector.Zero)

-- INCORRECT (DO NOT USE):
local screenPos = Isaac.WorldToScreen(worldPos) + renderOffset
```
> [!CAUTION]
> In Repentance, `Isaac.WorldToScreen(pos)` **already accounts for camera position and window resolution**.
> Adding `renderOffset` from `MC_POST_PLAYER_RENDER` causes a **double camera offset bug** in rooms larger than 1×1 (2×1, 1×2, 2×2, L-rooms). The sprite will detach from the player and float away!

---

## 4. Asset Authoring Specifications

### Boss VS Loading Screen Banners
- **Path**: `resources/gfx/ui/boss/name_<character>.png`
- **Canvas Size**: Canonical **192×64** pixels.
- **Color**: Hand-lettered parchment `#C7B299` (`RGBA(199, 178, 153, 255)`) with anti-aliasing.
- **Text Height**: **20–24 pixels** (matches vanilla scale for *Isaac*, *Judas*, *Samson*).
- **Horizontal Center**: Centered around **X = 88–92** on the 192px canvas.
  - *Why*: In `versusscreen.anm2`, `PlayerName` is placed at `X = -142`. Biasing slightly towards X=88 ensures full breathing room before "VS" and guarantees no collision with the left screen edge.

### Collectible & Trinket Icons
- **Collectibles**: **32×32** pixels, centered, 1-pixel dark outline `#1C1615`.
- **Trinkets**: **16×16** pixels.
- **Stage Icons**: **100×100** pixels (`stage_<character>.png`).
- **Boss Portraits**: **258×190** pixels (`portrait_<character>.png`).

---

## 5. Automated Verification Checklist

Before finishing any task on this mod:
1. **Run Unit Tests**:
   ```powershell
   Get-ChildItem tools/test_*.lua | ForEach-Object { $out = & "lua.exe" $_.FullName 2>&1; if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $($_.Name)"; Write-Host $out } else { Write-Host "PASSED: $($_.Name)" } }
   ```
2. **Sync to Steam**:
   Mirror modified files from `resources/`, `modules/`, `content/`, and `main.lua` to:
   `C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\mods\green_lantern_mod`
3. **Commit & Push**:
   Keep git history clean with conventional commits on `origin main`.
