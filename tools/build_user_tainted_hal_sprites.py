"""
tools/build_user_tainted_hal_sprites.py
Implements user-provided Tainted Hal sprite sheet into The Binding of Isaac: Repentance format.
- Input: 1024x1024 RGBA transparent PNG (media_1792283016381_425cfad6.png).
- Subpixel filtering: averages only solid subpixels (alpha >= 200) to prevent transparent white/grey edge ringing.
- Preserves authentic white gloves, chest emblem, glowing eyes, teeth, and PARALLAX WHITE/SILVER HAIR STREAKS.
- Eliminates stray white, grey, and off-color noise pixels on hair, skin, mask perimeter, neck, boots, and crotch.
- Injects authentic single-eye superhero side head frames with Parallax white hair streaks (tools/thal_side_idle_perfect_32.png and thal_side_shoot_perfect_32.png).
- Solidifies crisp dark perimeter outlines matching Isaac Repentance art style.
- Exact 512x512 RGBA matching 001.000_player.anm2 grid.
- Crisp 1-bit binary alpha (0 semi-transparent pixels) matching authentic Repentance engine standards.
- Integrates vanilla teleport light beam & trapdoor hole base in Col 4 & 6 (Y=320..448).
- Saves to resources/gfx/characters/tainted_hal.png and tainted_hal_extra.png.
"""

import os
import sys
import numpy as np
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_IMAGE_PATH = r"C:/Users/danic/.gemini/antigravity/brain/25a8c9be-14f1-4e9c-8c5f-e17d8ccace13/.user_uploaded/media_1792283016381_425cfad6.png"
VANILLA_ISAAC_PATH = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png"

TAINTED_HAL_PATH = os.path.join(PROJECT_ROOT, "resources", "gfx", "characters", "tainted_hal.png")
TAINTED_EXTRA_PATH = os.path.join(PROJECT_ROOT, "resources", "gfx", "characters", "tainted_hal_extra.png")

def process_sheet():
    if not os.path.exists(SRC_IMAGE_PATH):
        raise FileNotFoundError(f"Source image not found: {SRC_IMAGE_PATH}")
    if not os.path.exists(VANILLA_ISAAC_PATH):
        raise FileNotFoundError(f"Vanilla Isaac reference not found: {VANILLA_ISAAC_PATH}")

    print(f"Loading transparent source PNG: {SRC_IMAGE_PATH}...")
    uploaded = Image.open(SRC_IMAGE_PATH).convert("RGBA")
    arr_src = np.array(uploaded, dtype=float)
    H, W, C = arr_src.shape
    assert H == 1024 and W == 1024, f"Expected 1024x1024, got {W}x{H}"

    print(f"Loading vanilla Isaac reference: {VANILLA_ISAAC_PATH}...")
    vanilla = Image.open(VANILLA_ISAAC_PATH).convert("RGBA")
    arr_v = np.array(vanilla)

    # 1. 2x2 area pooling downscale to 512x512 with subpixel filtering
    print("Downscaling 1024x1024 to 512x512 RGBA with solid subpixel filtering...")
    blocks = arr_src.reshape(512, 2, 512, 2, 4).transpose(0, 2, 1, 3, 4).reshape(512, 512, 4, 4)
    rgb = blocks[:, :, :, :3]
    alpha = blocks[:, :, :, 3]

    solid_sub = alpha >= 180
    has_fg = solid_sub.sum(axis=2) >= 2

    w = (alpha >= 200).astype(float)
    w_sum = w.sum(axis=2)
    fallback = (w_sum == 0) & has_fg
    w[fallback] = (alpha[fallback] >= 180).astype(float)
    w_sum = w.sum(axis=2)

    out_rgb = np.zeros((512, 512, 3), dtype=np.uint8)
    valid = w_sum > 0
    out_rgb[valid] = np.clip((rgb * w[:, :, :, None]).sum(axis=2)[valid] / w_sum[valid, None], 0, 255).astype(np.uint8)

    arr_512 = np.zeros((512, 512, 4), dtype=np.uint8)
    arr_512[:, :, :3] = out_rgb
    arr_512[has_fg, 3] = 255
    arr_512[~has_fg, :3] = 0

    # 2. Integrate vanilla teleport light beam and trapdoor base
    print("Integrating vanilla teleport light beam and trapdoor base...")
    arr_512[384:448, 128:160] = arr_v[384:448, 128:160] # Col 4: Hole death base
    arr_512[320:448, 192:224] = arr_v[320:448, 192:224] # Col 6: Teleport beam

    # 3. Outer edge fringe cleanup (removes antialiased white/grey halo pixels bordering dark outlines)
    print("Eliminating outside edge fringe noise...")
    fg = arr_512[:, :, 3] == 255
    is_edge = np.zeros((512, 512), dtype=bool)
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        shifted = np.pad(fg, 1, mode='constant', constant_values=False)[1+dy:513+dy, 1+dx:513+dx]
        is_edge |= (fg & (~shifted))

    is_protected = np.zeros((512, 512), dtype=bool)
    is_protected[320:448, 192:224] = True
    is_protected[384:448, 128:160] = True
    for r in [0, 1, 2, 3]:
        for c in range(16):
            if r in [1, 2] or (r == 0 and c in [6, 7, 14, 15]):
                is_protected[r*32+14:r*32+21, c*32+6:c*32+12] = True
                is_protected[r*32+14:r*32+21, c*32+20:c*32+26] = True
                if c >= 8:
                    is_protected[r*32+8:r*32+16, c*32+4:c*32+12] = True
                    is_protected[r*32+8:r*32+16, c*32+21:c*32+28] = True
            # Protect temple hair streaks on front heads
            if r == 0 and c in [0, 1, 4, 5, 8]:
                is_protected[r*32+9:r*32+16, c*32+3:c*32+7] = True
                is_protected[r*32+9:r*32+16, c*32+25:c*32+29] = True

    for y in range(512):
        for x in range(512):
            if is_edge[y, x] and not is_protected[y, x]:
                p = arr_512[y, x, :3]
                diff = int(max(p)) - int(min(p))
                lum = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
                if lum > 65 and (diff < 15 or min(p) > 180):
                    has_dark_inward = False
                    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < 512 and 0 <= nx < 512 and fg[ny, nx]:
                            if max(arr_512[ny, nx, :3]) < 45:
                                has_dark_inward = True
                                break
                    if has_dark_inward:
                        arr_512[y, x] = [0, 0, 0, 0]

    # 4. Step 3: Clean up head frames (preserving glowing eyes, teeth, and temple white hair streaks)
    print("Sanitizing head frames (hair brown, uniform skin, glowing eyes, teeth, and white temple streaks)...")
    head_cells = [(0, c) for c in [0, 1, 4, 5, 8]]
    for r, c in head_cells:
        for y in range(32):
            for x in range(32):
                gy, gx = r * 32 + y, c * 32 + x
                if arr_512[gy, gx, 3] == 0:
                    continue
                p = arr_512[gy, gx, :3]
                rc, gc, bc = int(p[0]), int(p[1]), int(p[2])
                diff = max(rc, gc, bc) - min(rc, gc, bc)
                lum = 0.299 * rc + 0.587 * gc + 0.114 * bc
                is_skin = (rc > gc + 14) and (gc > bc + 8) and (rc > 160)
                is_eye = (15 <= y <= 19) and ((7 <= x <= 12) or (19 <= x <= 24)) and (gc >= 170 and gc >= rc)
                is_teeth = (c in [1, 8] and y in [20, 21, 22] and 13 <= x <= 18)
                # Temple hair streak protection (Parallax silver/white streaks)
                is_temple_streak = (9 <= y <= 16) and ((3 <= x <= 6) or (25 <= x <= 28)) and (lum > 160 and diff < 30)

                if not (is_eye or is_teeth or is_temple_streak):
                    # Check for stray white, light grey, or off-color outline pixels from paper sketch
                    if (lum > 130 and diff < 35) or (min(rc, gc, bc) > 175) or (diff < 15 and 50 < lum < 185 and not is_skin):
                        if y <= 13:
                            if y <= 2 or x <= 4 or x >= 27:
                                arr_512[gy, gx, :3] = [20, 15, 10]
                            else:
                                arr_512[gy, gx, :3] = [95, 65, 42]
                        else:
                            if x <= 4 or x >= 27 or y >= 24:
                                arr_512[gy, gx, :3] = [20, 15, 10]
                            elif x <= 6 or x >= 25 or y >= 22:
                                arr_512[gy, gx, :3] = [205, 160, 145]
                            else:
                                arr_512[gy, gx, :3] = [225, 190, 175]

    # 4B. Build authentic single-eye superhero side head frames (Col 2 Idle & Col 3 Shooting)
    print("Applying authentic single-eye superhero side head with Parallax hair streaks for Col 2 (Idle) and Col 3 (Shooting)...")
    idle_file = os.path.join(PROJECT_ROOT, "tools", "thal_side_idle_perfect_32.png")
    shoot_file = os.path.join(PROJECT_ROOT, "tools", "thal_side_shoot_perfect_32.png")
    
    if os.path.exists(idle_file):
        arr_512[0:32, 64:96] = np.array(Image.open(idle_file).convert("RGBA"))
    if os.path.exists(shoot_file):
        arr_512[0:32, 96:128] = np.array(Image.open(shoot_file).convert("RGBA"))

    # 5. Step 4: Clean up body frames (eliminate white boots/neck/crotch dots, preserve white gloves & emblem)
    print("Sanitizing body frames (clearing boot/neck white dots, preserving white gloves & emblem)...")
    body_cells = [(r, c) for r in [1, 2] for c in range(16)] + [(0, 6), (0, 7), (0, 14), (0, 15), (3, 0), (3, 1), (3, 8), (3, 9)]
    for r, c in body_cells:
        for y in range(32):
            for x in range(32):
                gy, gx = r * 32 + y, c * 32 + x
                if arr_512[gy, gx, 3] == 0:
                    continue
                p = arr_512[gy, gx, :3]
                rc, gc, bc = int(p[0]), int(p[1]), int(p[2])
                diff = max(rc, gc, bc) - min(rc, gc, bc)
                lum = 0.299 * rc + 0.587 * gc + 0.114 * bc

                # Context-aware glove protection
                if r == 1 and c < 8:
                    is_glove = (16 <= y <= 20) and ((7 <= x <= 12) or (20 <= x <= 25))
                elif r == 2 and c < 8:
                    is_glove = (14 <= y <= 19) and (18 <= x <= 25)
                elif (r in [1, 2] and c >= 8) or (r == 0 and c in [14, 15]) or (r == 3 and c in [8, 9]):
                    is_glove = (8 <= y <= 15) and ((4 <= x <= 12) or (20 <= x <= 28))
                elif r == 0 and c in [6, 7]:
                    is_glove = (16 <= y <= 20) and ((7 <= x <= 12) or (20 <= x <= 25))
                elif r == 3 and c in [0, 1]:
                    is_glove = (16 <= y <= 20) and ((7 <= x <= 12) or (20 <= x <= 25))
                else:
                    is_glove = False

                # Context-aware chest emblem protection
                if r in [1, 2] and c >= 8:
                    is_chest = (16 <= y <= 20) and (13 <= x <= 18)
                else:
                    is_chest = (13 <= y <= 17) and (13 <= x <= 18)

                # A. Boots & crotch region (y >= 21) - boots must be green, crotch dark
                if y >= 21:
                    if min(rc, gc, bc) > 170 or (diff < 20 and lum > 150):
                        if 14 <= x <= 17 and r in [1, 3] and c < 8:
                            arr_512[gy, gx, :3] = [20, 20, 20] # dark suit
                        else:
                            arr_512[gy, gx, :3] = [35, 105, 52] # green boot
                    elif diff < 15 and 50 < lum < 150:
                        if 14 <= x <= 17 and r in [1, 3] and c < 8:
                            arr_512[gy, gx, :3] = [20, 20, 20]
                        else:
                            arr_512[gy, gx, :3] = [35, 105, 52]

                # B. Upper chest / neck (11 <= y <= 14)
                elif 11 <= y <= 14 and 11 <= x <= 21:
                    if min(rc, gc, bc) > 165 or (diff < 15 and lum > 140):
                        if y <= 12:
                            arr_512[gy, gx, :3] = [20, 15, 10] # dark collar outline
                        else:
                            arr_512[gy, gx, :3] = [40, 145, 65] # green suit

                # C. Torso (y < 21) outside gloves and chest emblem
                elif not (is_glove or is_chest):
                    if min(rc, gc, bc) > 175:
                        if 11 <= x <= 20:
                            arr_512[gy, gx, :3] = [40, 145, 65] # green suit
                        else:
                            arr_512[gy, gx, :3] = [20, 20, 20] # black suit
                    elif diff < 15 and 50 < lum < 175:
                        if 11 <= x <= 20 and y <= 19:
                            arr_512[gy, gx, :3] = [40, 145, 65] # green suit

    # 6. Step 5: Clean up large 64x64 animation frames (Rows 4, 6, 8)
    print("Sanitizing 64x64 animation frames (clearing white boot noise in pickup/death/jump)...")
    for r_base in [4, 6, 8]:
        for c_base in [0, 2, 4, 6]:
            for y in range(48, 64):
                for x in range(64):
                    gy, gx = r_base * 32 + y, c_base * 32 + x
                    if arr_512[gy, gx, 3] == 0:
                        continue
                    p = arr_512[gy, gx, :3]
                    rc, gc, bc = int(p[0]), int(p[1]), int(p[2])
                    diff = max(rc, gc, bc) - min(rc, gc, bc)
                    lum = 0.299 * rc + 0.587 * gc + 0.114 * bc
                    if min(rc, gc, bc) > 170 or (diff < 20 and lum > 150):
                        arr_512[gy, gx, :3] = [35, 105, 52]

    # 7. Step 6: Solid dark outline crispness on outer perimeters
    print("Solidifying dark perimeter outlines...")
    fg = arr_512[:, :, 3] == 255
    is_edge = np.zeros((512, 512), dtype=bool)
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        shifted = np.pad(fg, 1, mode='constant', constant_values=False)[1+dy:513+dy, 1+dx:513+dx]
        is_edge |= (fg & (~shifted))

    for y in range(512):
        for x in range(512):
            if is_edge[y, x] and not is_protected[y, x]:
                p = arr_512[y, x, :3]
                diff = int(max(p)) - int(min(p))
                lum = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
                if 30 <= lum <= 70 and diff < 15:
                    arr_512[y, x, :3] = [20, 15, 10]

    # 8. Step 7: Final sanitization: 1-bit binary alpha & zero dirty RGB
    print("Enforcing strict 1-bit binary alpha and clean zero RGB on transparent pixels...")
    arr_512[arr_512[:, :, 3] < 255, 3] = 0
    arr_512[arr_512[:, :, 3] == 0, :3] = 0

    final_sheet = Image.fromarray(arr_512, mode="RGBA")

    # 9. Save output files
    print(f"Saving {TAINTED_HAL_PATH}...")
    final_sheet.save(TAINTED_HAL_PATH, "PNG")

    print(f"Saving {TAINTED_EXTRA_PATH}...")
    final_sheet.save(TAINTED_EXTRA_PATH, "PNG")

    solid_cnt = (arr_512[:, :, 3] == 255).sum()
    semi_cnt = ((arr_512[:, :, 3] > 0) & (arr_512[:, :, 3] < 255)).sum()
    dirty_cnt = ((arr_512[:, :, 3] == 0) & ((arr_512[:, :, 0] > 0) | (arr_512[:, :, 1] > 0) | (arr_512[:, :, 2] > 0))).sum()
    print(f"Tainted Hal sprite generation complete! Solid pixels: {solid_cnt}, Semi: {semi_cnt}, Dirty: {dirty_cnt}")
    return final_sheet

if __name__ == "__main__":
    process_sheet()
