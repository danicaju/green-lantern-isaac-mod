"""
tools/build_user_hal_sprites.py
Implements user-provided transparent Hal Jordan sprite sheet into The Binding of Isaac: Repentance format.
- Input: 1024x1024 RGBA transparent PNG.
- Preserves authentic white gloves, chest emblem, glowing eyes, and teeth.
- Cleans up stray white, grey, and off-color noise pixels on hair, skin, mask perimeter, neck, and outlines.
- Eliminates transparent edge fringes and ringing artifacts.
- Exact 512x512 RGBA matching 001.000_player.anm2 grid.
- Crisp 1-bit binary alpha (0 semi-transparent pixels) matching authentic Repentance engine standards.
- Integrates teleport light beam & hole base in Col 4 & 6 (Y=320..448).
- Saves to resources/gfx/characters/hal_jordan.png and hal_jordan_extra.png.
"""

import os
import sys
import numpy as np
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_IMAGE_PATH = r"C:/Users/danic/.gemini/antigravity/brain/25a8c9be-14f1-4e9c-8c5f-e17d8ccace13/.user_uploaded/media_1792140081953_e9e21585.png"
VANILLA_ISAAC_PATH = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png"

HAL_JORDAN_PATH = os.path.join(PROJECT_ROOT, "resources", "gfx", "characters", "hal_jordan.png")
HAL_EXTRA_PATH = os.path.join(PROJECT_ROOT, "resources", "gfx", "characters", "hal_jordan_extra.png")

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
    print("Downscaling 1024x1024 to 512x512 RGBA with alpha-weighted pooling...")
    blocks = arr_src.reshape(512, 2, 512, 2, 4).transpose(0, 2, 1, 3, 4).reshape(512, 512, 4, 4)
    rgb = blocks[:, :, :, :3]
    alpha = blocks[:, :, :, 3]

    # Filter out faint antialiased transparent fringes (alpha < 64)
    valid = alpha >= 64
    w = alpha * valid
    w_sum = w.sum(axis=2)
    # Majority vote: 2 or more solid subpixels -> solid 1-bit pixel
    has_fg = (alpha >= 128).sum(axis=2) >= 2

    out_rgb = np.zeros((512, 512, 3), dtype=np.uint8)
    mask_fg = w_sum > 0
    out_rgb[mask_fg] = np.clip((rgb * w[:, :, :, None]).sum(axis=2)[mask_fg] / w_sum[mask_fg, None], 0, 255).astype(np.uint8)

    arr_512 = np.zeros((512, 512, 4), dtype=np.uint8)
    arr_512[:, :, :3] = out_rgb
    arr_512[has_fg, 3] = 255
    arr_512[~has_fg, :3] = 0

    # 2. Integrate vanilla teleport light beam and trapdoor base
    print("Integrating vanilla teleport light beam and trapdoor base...")
    arr_512[384:448, 128:160] = arr_v[384:448, 128:160] # Col 4: Hole death base
    arr_512[320:448, 192:224] = arr_v[320:448, 192:224] # Col 6: Teleport beam

    # 3. Step 2: Remove outside fringe noise (pixels bordering transparency outside solid dark outlines)
    print("Eliminating outside edge fringe noise...")
    fg = arr_512[:, :, 3] == 255
    is_edge = np.zeros((512, 512), dtype=bool)
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        shifted = np.pad(fg, 1, mode='constant', constant_values=False)[1+dy:513+dy, 1+dx:513+dx]
        is_edge |= (fg & (~shifted))

    is_protected = np.zeros((512, 512), dtype=bool)
    is_protected[320:448, 192:224] = True
    is_protected[384:448, 128:160] = True
    for r in [0, 1, 2, 3, 7, 9]:
        for c in range(16):
            if r in [1, 2, 7, 9] or (r == 0 and c in [6, 7]):
                is_protected[r*32+15:r*32+25, c*32+5:c*32+13] = True
                is_protected[r*32+15:r*32+25, c*32+19:c*32+27] = True
                is_protected[r*32+21:r*32+26, c*32+13:c*32+19] = True
            if r == 3 and c in [8, 9]:
                is_protected[r*32+8:r*32+16, c*32+4:c*32+11] = True
                is_protected[r*32+8:r*32+16, c*32+22:c*32+29] = True

    for y in range(512):
        for x in range(512):
            if is_edge[y, x] and not is_protected[y, x]:
                p = arr_512[y, x, :3]
                diff = max(p) - min(p)
                lum = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
                if lum > 65 and (diff < 15 or min(p) > 180):
                    has_dark_inward = False
                    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < 512 and 0 <= nx < 512 and fg[ny, nx]:
                            if max(arr_512[ny, nx, :3]) < 40:
                                has_dark_inward = True
                                break
                    if has_dark_inward:
                        arr_512[y, x] = [0, 0, 0, 0]

    # 4. Step 3: Clean up head hair, skin, and mask perimeters (preserving glowing eyes & teeth)
    print("Sanitizing head frames (hair brown, uniform skin, glowing eyes, teeth)...")
    for c in [0, 1, 2, 3, 4, 5, 8]:
        for y in range(32):
            for x in range(32):
                gy, gx = y, c * 32 + x
                if arr_512[gy, gx, 3] == 0:
                    continue
                p = arr_512[gy, gx, :3]
                r, g, b = int(p[0]), int(p[1]), int(p[2])
                diff = max(r, g, b) - min(r, g, b)
                lum = 0.299 * r + 0.587 * g + 0.114 * b

                # Hair region (y <= 12)
                if y <= 12:
                    if min(r, g, b) > 180:
                        arr_512[gy, gx, :3] = [95, 65, 42]
                    elif diff < 14 and lum > 50:
                        if y <= 2 or x <= 4 or x >= 27:
                            arr_512[gy, gx, :3] = [20, 15, 10] # solid dark outline
                        else:
                            arr_512[gy, gx, :3] = [95, 65, 42] # warm brown hair
                # Face / skin / mask region (y >= 13)
                else:
                    is_eye = (14 <= y <= 19) and ((6 <= x <= 12) or (19 <= x <= 25) or (13 <= x <= 17)) and (g > 180 and g >= r)
                    is_teeth = (c == 8 and y == 20 and 14 <= x <= 16)
                    if not (is_eye or is_teeth):
                        # Stray white on skin or mask perimeter
                        if min(r, g, b) > 190:
                            arr_512[gy, gx, :3] = [230, 195, 178]
                        # Stray grey dot on skin or mask perimeter
                        elif diff < 12 and 60 < lum < 190:
                            arr_512[gy, gx, :3] = [225, 190, 175]

    # 5. Step 4: Clean up body frames (remove neck/mint dots, preserve gloves & chest emblem)
    print("Sanitizing body frames (clearing neck white dots, preserving white gloves & emblem)...")
    for r in [0, 1, 2, 3]:
        for c in range(16):
            if r in [1, 2] or (r == 0 and c in [6, 7]) or (r == 3 and c in [0, 1]):
                for y in range(32):
                    for x in range(32):
                        gy, gx = r * 32 + y, c * 32 + x
                        if arr_512[gy, gx, 3] == 0:
                            continue
                        p = arr_512[gy, gx, :3]
                        r_c, g_c, b_c = int(p[0]), int(p[1]), int(p[2])
                        diff = max(r_c, g_c, b_c) - min(r_c, g_c, b_c)
                        lum = 0.299 * r_c + 0.587 * g_c + 0.114 * b_c

                        is_glove = (15 <= y <= 24) and ((5 <= x <= 12) or (19 <= x <= 26))
                        is_chest = (21 <= y <= 25) and (13 <= x <= 18)

                        # Upper chest / neck neon white/mint pixels: restore to green suit
                        if (12 <= y <= 17) and (12 <= x <= 20) and min(r_c, g_c, b_c) > 170:
                            arr_512[gy, gx, :3] = [40, 145, 65]
                        # Boots stray white/grey
                        elif y >= 24 and not is_glove and (min(r_c, g_c, b_c) > 180 or (diff < 10 and 60 < lum < 185)):
                            arr_512[gy, gx, :3] = [25, 70, 35]
                        # Stray white outside gloves & chest:
                        elif min(r_c, g_c, b_c) > 180 and not (is_glove or is_chest):
                            arr_512[gy, gx, :3] = [20, 20, 20]
                        # Stray grey outside gloves & chest & outline:
                        elif diff < 10 and 60 < lum < 185 and not (is_glove or is_chest):
                            arr_512[gy, gx, :3] = [20, 20, 20]

    # 6. Step 5: Solid dark outline crispness on outer perimeters
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
                diff = max(p) - min(p)
                lum = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
                if 35 <= lum <= 70 and diff < 15:
                    arr_512[y, x, :3] = [20, 15, 10]

    # 7. Final sanitization: 1-bit binary alpha & zero dirty RGB
    print("Enforcing strict 1-bit binary alpha and clean zero RGB on transparent pixels...")
    arr_512[arr_512[:, :, 3] < 255, 3] = 0
    arr_512[arr_512[:, :, 3] == 0, :3] = 0

    final_sheet = Image.fromarray(arr_512, mode="RGBA")

    # 8. Save output files
    print(f"Saving {HAL_JORDAN_PATH}...")
    final_sheet.save(HAL_JORDAN_PATH, "PNG")

    print(f"Saving {HAL_EXTRA_PATH}...")
    final_sheet.save(HAL_EXTRA_PATH, "PNG")

    solid_cnt = (arr_512[:, :, 3] == 255).sum()
    semi_cnt = ((arr_512[:, :, 3] > 0) & (arr_512[:, :, 3] < 255)).sum()
    dirty_cnt = ((arr_512[:, :, 3] == 0) & ((arr_512[:, :, 0] > 0) | (arr_512[:, :, 1] > 0) | (arr_512[:, :, 2] > 0))).sum()
    print(f"Sprite generation complete! Solid pixels: {solid_cnt}, Semi: {semi_cnt}, Dirty: {dirty_cnt}")
    return final_sheet

if __name__ == "__main__":
    process_sheet()
