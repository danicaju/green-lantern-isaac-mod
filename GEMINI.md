# Project Rules: Green Lantern Mod (The Binding of Isaac: Repentance+)

## 1. Project Overview & Directories
- **Repository Root**: `C:\Users\danic\Desktop\green_lantern_mod`
- **Steam Mod Directory (Mirror Target)**: `C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\mods\green_lantern_mod`
- **Vanilla Unpacked Resources**: `C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources`

---

## 2. Mandatory Workflow Rules

### Rule 1: Automated Unit Testing
Whenever any Lua file in `main.lua` or `modules/*.lua` is modified:
- Run all 27 unit tests using `lua.exe`:
  ```powershell
  Get-ChildItem tools/test_*.lua | ForEach-Object { $out = & "lua.exe" $_.FullName 2>&1; if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $($_.Name)"; Write-Host $out } else { Write-Host "PASSED: $($_.Name)" } }
  ```
- All 27 tests MUST pass before completing any turn.

### Rule 2: Steam Mod Directory Mirroring
Whenever any file is created or modified in `resources/`, `content/`, `modules/`, or `main.lua`:
- Immediately sync the changes to the Steam mod directory using robocopy:
  ```powershell
  robocopy "<source_folder>" "C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\mods\green_lantern_mod\<relative_folder>" <files> /NFL /NDL /NJH /NJS
  ```

### Rule 3: Git Version Control
- All completed features, fixes, and asset updates must be staged, committed with conventional commit messages, and pushed to `origin main`.

### Rule 4: Character Sprite Protection
- **NEVER overwrite active character sprite sheets** (`resources/gfx/characters/hal_jordan.png`, `tainted_hal.png`, `hal_head_base.png`, overlays, etc.) without explicit user approval.
- Always generate preview comparisons first for user review.

---

## 3. Repentance Engine Technical Constraints

### Coordinate Spaces & Rendering
- **`Isaac.WorldToScreen(worldPos)`**:
  - In `MC_POST_PLAYER_RENDER`, `Isaac.WorldToScreen` ALREADY transforms world coordinates to screen space for the current room view.
  - **NEVER add `renderOffset` or camera scroll offset on top of `Isaac.WorldToScreen`**. Doing so causes double-offsetting in scrolling rooms (2×1, 1×2, 2×2, L-rooms), detaching effects and orbitals from the player.
- **`Sprite:Render(screenPos, Vector.Zero, Vector.Zero)`**:
  - Requires screen-space coordinates. Always pass `Isaac.WorldToScreen(worldPos)`.

### Boss VS Screen Banners
- **Canvas Size**: Canonical **192×64** pixels (`.png`).
- **Color Palette**: `#C7B299` (`RGBA(199, 178, 153, 255)`) with anti-aliasing.
- **Lettering Scale**: Text height must be **20–24 pixels** (content width ~100–125 px).
- **Centering**: Center the text around **X = 88–92** on the 192px canvas. This prevents the left side of the name from colliding with the screen edge and keeps a clean margin before "VS".

### Active & Passive Items Universal Compatibility
- All collectible items in `content/items.xml` must have useful, functional effects for **ALL characters** (Isaac, Cain, Judas, Samson, etc.), not just Hal Jordan.
- Character-specific synergies (e.g. Willpower / emerald beams) can enhance the item, but base functionality must always trigger for regular characters.
