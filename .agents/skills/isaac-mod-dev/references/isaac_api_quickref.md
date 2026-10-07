# The Binding of Isaac: Repentance Lua API Quick Reference

This offline reference lists all primary classes, enumerations, and methods used in Repentance+ mod development.

---

## 1. ModCallbacks Enum Reference

| Enum | Value | Common Parameters |
| :--- | :--- | :--- |
| `MC_POST_UPDATE` | 1 | `(_)` |
| `MC_POST_RENDER` | 2 | `(_)` |
| `MC_USE_ITEM` | 3 | `(_, itemID, rng, player, useFlags, activeSlot, varData)` |
| `MC_EVALUATE_CACHE` | 8 | `(_, player, cacheFlag)` |
| `MC_POST_PLAYER_INIT` | 9 | `(_, player)` |
| `MC_POST_FIRE_TEAR` | 12 | `(_, tear)` |
| `MC_PRE_TEAR_COLLISION` | 14 | `(_, tear, collider, low)` |
| `MC_ENTITY_TAKE_DMG` | 20 | `(_, entity, amount, flags, source, countdown)` |
| `MC_POST_ENTITY_REMOVE`| 21 | `(_, entity)` |
| `MC_PRE_PLAYER_RENDER` | 31 | `(_, player, renderOffset)` |
| `MC_POST_PLAYER_RENDER`| 32 | `(_, player, renderOffset)` |
| `MC_POST_TEAR_RENDER`  | 40 | `(_, tear, renderOffset)` |
| `MC_POST_PICKUP_INIT`  | 41 | `(_, pickup)` |
| `MC_PRE_PICKUP_COLLISION`| 42 | `(_, pickup, collider, low)` |

---

## 2. Common Enums

### `CacheFlag`
- `CacheFlag.CACHE_DAMAGE` = 1
- `CacheFlag.CACHE_FIREDELAY` = 2
- `CacheFlag.CACHE_SHOTSPEED` = 4
- `CacheFlag.CACHE_RANGE` = 8
- `CacheFlag.CACHE_SPEED` = 16
- `CacheFlag.CACHE_TEARFLAG` = 32
- `CacheFlag.CACHE_TEARCOLOR` = 64
- `CacheFlag.CACHE_FLYING` = 128
- `CacheFlag.CACHE_WEAPON` = 256
- `CacheFlag.CACHE_FAMILIARS` = 512
- `CacheFlag.CACHE_ALL` = 1023

### `TearFlags` (Bitmask)
- `TearFlags.TEAR_SPECTRAL` (passes through rocks/obstacles)
- `TearFlags.TEAR_PIERCING` (pierces through enemies)
- `TearFlags.TEAR_HOMING`
- `TearFlags.TEAR_SLOW`
- `TearFlags.TEAR_POISON`
- `TearFlags.TEAR_FREEZE`
- `TearFlags.TEAR_FEAR`
- `TearFlags.TEAR_SPLIT`
- `TearFlags.TEAR_BOUNCE`
- `TearFlags.TEAR_EXPLOSIVE`

### `Direction`
- `Direction.LEFT` = 0
- `Direction.UP` = 1
- `Direction.RIGHT` = 2
- `Direction.DOWN` = 3
- `Direction.NO_DIRECTION` = 4

### `ActiveSlot`
- `ActiveSlot.SLOT_PRIMARY` = 0
- `ActiveSlot.SLOT_SECONDARY` = 1
- `ActiveSlot.SLOT_POCKET` = 2
- `ActiveSlot.SLOT_POCKET2` = 3

---

## 3. Core Objects & Global Singletons

### `Isaac` Global Table
- `Isaac.GetPlayer(index)`: Returns `EntityPlayer` (index 0 is main player).
- `Isaac.GetRoomEntities()`: Returns array of all entities in the current room.
- `Isaac.FindByType(type, variant, subtype, cache, ignoreFriendly)`: Finds entities matching type.
- `Isaac.Spawn(type, variant, subtype, position, velocity, spawner)`: Spawns an entity.
- `Isaac.WorldToScreen(worldPos)`: Converts world position to screen space.
- `Isaac.WorldToRenderPosition(worldPos)`: Converts world position to room render space.
- `Isaac.GetItemIdByName(string)`: Dynamic lookup for item ID.

### `Game()` Global Methods
- `Game():GetRoom()`: Returns current `Room` object.
- `Game():GetLevel()`: Returns current `Level` object.
- `Game():GetFrameCount()`: Returns logic frame counter (advances at 30Hz).
- `Game():IsPaused()`: True if pause menu / cutscene is active.
- `Game():GetNumPlayers()`: Number of active players (single player or co-op).

### `Room` Object Methods
- `room:GetRenderScrollOffset()`: Camera scroll vector in large rooms.
- `room:GetTopLeftClamp()` / `room:GetBottomRightClamp()`: Playable bounds.
- `room:IsClear()`: True if all room enemies are defeated.
- `room:GetType()`: Returns `RoomType` (e.g. `RoomType.ROOM_BOSS`, `RoomType.ROOM_TREASURE`).
- `room:GetRenderMode()`: Used to detect `RenderMode.RENDER_WATER_REFLECT`.
