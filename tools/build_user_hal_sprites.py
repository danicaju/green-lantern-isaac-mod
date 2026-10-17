"""
tools/build_user_hal_sprites.py
Implements user-provided transparent Hal Jordan sprite sheet into The Binding of Isaac: Repentance format.
- Input: 1024x1024 RGBA transparent PNG (media_1792140081953_e9e21585.png).
- Subpixel filtering: averages only solid subpixels (alpha >= 200) to prevent transparent white/grey edge ringing.
- Preserves authentic white gloves, circular chest emblem, glowing mint/white eyes, and open-mouth teeth.
- Eliminates stray white, grey, and off-color noise pixels on hair, skin, mask perimeter, neck, boots, and crotch.
- Eliminates inadvertent black noise dots by appropriately restoring green suit, black suit, and green boot colors.
- Solidifies crisp dark perimeter outlines matching Isaac Repentance art style.
- Exact 512x512 RGBA matching 001.000_player.anm2 grid.
- Crisp 1-bit binary alpha (0 semi-transparent pixels) matching authentic Repentance engine standards.
- Integrates vanilla teleport light beam & trapdoor hole base in Col 4 & 6 (Y=320..448).
- Saves to resources/gfx/characters/hal_jordan.png and hal_jordan_extra.png.
"""

import os
import sys
import numpy as np
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_IMAGE_PATH = r"C:/Users/danic/.gemini/antigravity/brain/25a8c9be-14f1-4e9c-8c5f-e17d8ccace13/.user_uploaded/media_1792140081953_e9e21585.png"
VANILLA_ISAAC_PATH = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png"

# Palette constants for authentic Hal Jordan superhero side head
SIDE_DARK = np.array([20, 15, 10, 255], dtype=np.uint8)
SIDE_HAIR_SHADOW = np.array([45, 28, 16, 255], dtype=np.uint8)
SIDE_HAIR_BASE = np.array([95, 65, 42, 255], dtype=np.uint8)
SIDE_HAIR_LIGHT = np.array([125, 88, 58, 255], dtype=np.uint8)

SIDE_SKIN_BASE = np.array([225, 190, 175, 255], dtype=np.uint8)
SIDE_SKIN_SHADOW = np.array([205, 160, 145, 255], dtype=np.uint8)

SIDE_MASK_DARK = np.array([20, 65, 30, 255], dtype=np.uint8)
SIDE_MASK_MID = np.array([45, 145, 65, 255], dtype=np.uint8)
SIDE_MASK_LIGHT = np.array([75, 185, 95, 255], dtype=np.uint8)

SIDE_EYE_MINT = np.array([130, 220, 160, 255], dtype=np.uint8)
SIDE_EYE_CORE = np.array([238, 255, 245, 255], dtype=np.uint8)

SIDE_MOUTH_DARK = np.array([55, 22, 14, 255], dtype=np.uint8)

def build_side_head_idle(base):
    idle_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "user_side_idle_perfect_32.png")
    if os.path.exists(idle_file):
        return np.array(Image.open(idle_file))
    c = base.copy()
    
    # y=0..1: Completely transparent (remove white sketch background dome)
    c[0:2, :] = 0
    
    # y=2..9: Clean skull crown & hair contour (no white halo)
    c[2, :12] = 0; c[2, 12:21] = SIDE_DARK; c[2, 21:] = 0
    c[3, :9] = 0; c[3, 9:12] = SIDE_DARK; c[3, 20:22] = SIDE_DARK; c[3, 22:] = 0
    c[4, :8] = 0; c[4, 8:10] = SIDE_DARK; c[4, 22:24] = SIDE_DARK; c[4, 24:] = 0
    c[5, :6] = 0; c[5, 6:8] = SIDE_DARK; c[5, 24:26] = SIDE_DARK; c[5, 26:] = 0
    c[6, :5] = 0; c[6, 5:7] = SIDE_DARK; c[6, 25:27] = SIDE_DARK; c[6, 27:] = 0
    c[7, :4] = 0; c[7, 4:6] = SIDE_DARK; c[7, 26:28] = SIDE_DARK; c[7, 28:] = 0
    c[8, :3] = 0; c[8, 3:5] = SIDE_DARK; c[8, 27:29] = SIDE_DARK; c[8, 29:] = 0
    c[9, :2] = 0; c[9, 2:4] = SIDE_DARK; c[9, 28:30] = SIDE_DARK; c[9, 30:] = 0

    # y=10: Crown/bangs hair & forehead
    c[10, 2:4] = SIDE_DARK
    c[10, 4:7] = SIDE_HAIR_SHADOW
    c[10, 7:12] = SIDE_HAIR_BASE
    c[10, 12:15] = SIDE_HAIR_LIGHT
    c[10, 15:18] = SIDE_HAIR_BASE
    c[10, 18:22] = SIDE_HAIR_SHADOW
    c[10, 22:26] = SIDE_SKIN_BASE
    c[10, 26:30] = SIDE_DARK

    # y=11: Hair flow, bangs & forehead skin
    c[11, 2:4] = SIDE_DARK
    c[11, 4:6] = SIDE_HAIR_SHADOW
    c[11, 6:11] = SIDE_HAIR_BASE
    c[11, 11:13] = SIDE_HAIR_LIGHT
    c[11, 13:16] = SIDE_HAIR_BASE
    c[11, 16:18] = SIDE_HAIR_SHADOW
    c[11, 18:25] = SIDE_SKIN_BASE
    c[11, 25:28] = SIDE_SKIN_SHADOW
    c[11, 28:30] = SIDE_DARK

    # y=12: Back hair, temple hair, brow skin & top of mask
    c[12, 2:4] = SIDE_DARK
    c[12, 4:6] = SIDE_HAIR_SHADOW
    c[12, 6:11] = SIDE_HAIR_BASE
    c[12, 11:14] = SIDE_HAIR_SHADOW
    c[12, 14:16] = SIDE_MASK_DARK
    c[12, 16:21] = SIDE_MASK_LIGHT
    c[12, 21:24] = SIDE_MASK_MID
    c[12, 24:26] = SIDE_MASK_DARK
    c[12, 26:30] = SIDE_DARK

    # y=13: Back hair, temple/sideburn, mask upper wing & upper eye frame
    c[13, 2:4] = SIDE_DARK
    c[13, 4:6] = SIDE_HAIR_SHADOW
    c[13, 6:10] = SIDE_HAIR_BASE
    c[13, 10:12] = SIDE_HAIR_SHADOW
    c[13, 12] = SIDE_DARK
    c[13, 13:16] = SIDE_MASK_MID
    c[13, 16:21] = SIDE_MASK_LIGHT
    c[13, 21:25] = SIDE_MASK_MID
    c[13, 25] = SIDE_MASK_DARK
    c[13, 26:30] = SIDE_DARK

    # y=14: Back hair, sideburn, mask wing, glowing white eye upper
    c[14, 2:4] = SIDE_DARK
    c[14, 4:6] = SIDE_HAIR_SHADOW
    c[14, 6:9] = SIDE_HAIR_BASE
    c[14, 9:11] = SIDE_HAIR_SHADOW
    c[14, 11] = SIDE_DARK
    c[14, 12:15] = SIDE_MASK_MID
    c[14, 15] = SIDE_MASK_DARK
    c[14, 16:20] = SIDE_EYE_CORE
    c[14, 20] = SIDE_MASK_DARK
    c[14, 21:25] = SIDE_MASK_MID
    c[14, 25:27] = SIDE_MASK_DARK
    c[14, 27:30] = SIDE_DARK

    # y=15: Back hair, sideburn, mask, glowing white eye center
    c[15, 2:4] = SIDE_DARK
    c[15, 4:6] = SIDE_HAIR_SHADOW
    c[15, 6:9] = SIDE_HAIR_BASE
    c[15, 9:11] = SIDE_HAIR_SHADOW
    c[15, 11:13] = SIDE_SKIN_BASE
    c[15, 13:15] = SIDE_MASK_MID
    c[15, 15] = SIDE_MASK_DARK
    c[15, 16:20] = SIDE_EYE_CORE
    c[15, 20] = SIDE_MASK_DARK
    c[15, 21:25] = SIDE_MASK_MID
    c[15, 25:27] = SIDE_MASK_DARK
    c[15, 27:30] = SIDE_DARK

    # y=16: Back hair, sideburn tip, cheek skin, lower eye & mask bottom
    c[16, 2:4] = SIDE_DARK
    c[16, 4:6] = SIDE_HAIR_SHADOW
    c[16, 6:8] = SIDE_HAIR_BASE
    c[16, 8:10] = SIDE_HAIR_SHADOW
    c[16, 10:13] = SIDE_SKIN_BASE
    c[16, 13:15] = SIDE_MASK_MID
    c[16, 15:21] = SIDE_MASK_MID
    c[16, 21:24] = SIDE_MASK_MID
    c[16, 24:26] = SIDE_MASK_DARK
    c[16, 26:30] = SIDE_DARK

    # y=17: Back hair bottom, cheek skin, bottom mask arch
    c[17, 2:4] = SIDE_DARK
    c[17, 4:6] = SIDE_HAIR_SHADOW
    c[17, 6:8] = SIDE_HAIR_SHADOW
    c[17, 8:14] = SIDE_SKIN_BASE
    c[17, 14:16] = SIDE_MASK_DARK
    c[17, 16:22] = SIDE_MASK_DARK
    c[17, 22:24] = SIDE_MASK_DARK
    c[17, 24:27] = SIDE_SKIN_BASE
    c[17, 27:30] = SIDE_DARK

    # y=18: Lower skull hair end, cheek and jaw skin
    c[18, 2:4] = SIDE_DARK
    c[18, 4:6] = SIDE_HAIR_SHADOW
    c[18, 6:16] = SIDE_SKIN_BASE
    c[18, 16:22] = SIDE_SKIN_SHADOW
    c[18, 22:27] = SIDE_SKIN_BASE
    c[18, 27:30] = SIDE_DARK

    # y=19..20: Lower cheek / jawline
    c[19, 3:5] = SIDE_DARK
    c[19, 5:27] = SIDE_SKIN_BASE
    c[19, 27:29] = SIDE_DARK

    c[20, 3:5] = SIDE_DARK
    c[20, 5:26] = SIDE_SKIN_BASE
    c[20, 26:29] = SIDE_DARK

    # y=21..22: Jawline & mouth
    c[21, 4:6] = SIDE_DARK
    c[21, 6:25] = SIDE_SKIN_BASE
    c[21, 25:28] = SIDE_DARK

    c[22, 5:7] = SIDE_DARK
    c[22, 7:17] = SIDE_SKIN_BASE
    c[22, 17:22] = SIDE_MOUTH_DARK
    c[22, 22:25] = SIDE_SKIN_BASE
    c[22, 25:28] = SIDE_DARK
    return c

def build_side_head_shooting(base):
    shoot_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "user_side_shoot_perfect_32.png")
    if os.path.exists(shoot_file):
        return np.array(Image.open(shoot_file))
    c = base.copy()
    
    # y=0..1: Completely transparent
    c[0:2, :] = 0

    # y=2..11: Clean skull crown & hair contour
    c[2, :12] = 0; c[2, 12:21] = SIDE_DARK; c[2, 21:] = 0
    c[3, :9] = 0; c[3, 9:12] = SIDE_DARK; c[3, 20:22] = SIDE_DARK; c[3, 22:] = 0
    c[4, :8] = 0; c[4, 8:10] = SIDE_DARK; c[4, 22:24] = SIDE_DARK; c[4, 24:] = 0
    c[5, :6] = 0; c[5, 6:8] = SIDE_DARK; c[5, 24:26] = SIDE_DARK; c[5, 26:] = 0
    c[6, :5] = 0; c[6, 5:7] = SIDE_DARK; c[6, 25:27] = SIDE_DARK; c[6, 27:] = 0
    c[7, :4] = 0; c[7, 4:6] = SIDE_DARK; c[7, 26:28] = SIDE_DARK; c[7, 28:] = 0
    c[8, :3] = 0; c[8, 3:5] = SIDE_DARK; c[8, 27:29] = SIDE_DARK; c[8, 29:] = 0
    c[9, :3] = 0; c[9, 3:5] = SIDE_DARK; c[9, 27:29] = SIDE_DARK; c[9, 29:] = 0
    c[10, :3] = 0; c[10, 3] = SIDE_DARK; c[10, 29] = SIDE_DARK; c[10, 30:] = 0
    c[11, :2] = 0; c[11, 2] = SIDE_DARK; c[11, 29] = SIDE_DARK; c[11, 30:] = 0

    # Shifted 2 pixels down for shooting pose
    # y=12: Crown/bangs hair & forehead
    c[12, 2:4] = SIDE_DARK
    c[12, 4:7] = SIDE_HAIR_SHADOW
    c[12, 7:12] = SIDE_HAIR_BASE
    c[12, 12:15] = SIDE_HAIR_LIGHT
    c[12, 15:18] = SIDE_HAIR_BASE
    c[12, 18:22] = SIDE_HAIR_SHADOW
    c[12, 22:26] = SIDE_SKIN_BASE
    c[12, 26:30] = SIDE_DARK

    # y=13: Hair flow & forehead skin
    c[13, 2:4] = SIDE_DARK
    c[13, 4:6] = SIDE_HAIR_SHADOW
    c[13, 6:11] = SIDE_HAIR_BASE
    c[13, 11:13] = SIDE_HAIR_LIGHT
    c[13, 13:16] = SIDE_HAIR_BASE
    c[13, 16:18] = SIDE_HAIR_SHADOW
    c[13, 18:25] = SIDE_SKIN_BASE
    c[13, 25:28] = SIDE_SKIN_SHADOW
    c[13, 28:30] = SIDE_DARK

    # y=14: Back hair, temple hair, brow skin & top of mask
    c[14, 2:4] = SIDE_DARK
    c[14, 4:6] = SIDE_HAIR_SHADOW
    c[14, 6:11] = SIDE_HAIR_BASE
    c[14, 11:14] = SIDE_HAIR_SHADOW
    c[14, 14:16] = SIDE_MASK_DARK
    c[14, 16:21] = SIDE_MASK_LIGHT
    c[14, 21:24] = SIDE_MASK_MID
    c[14, 24:26] = SIDE_MASK_DARK
    c[14, 26:30] = SIDE_DARK

    # y=15: Back hair, temple/sideburn, mask upper wing & upper eye frame
    c[15, 2:4] = SIDE_DARK
    c[15, 4:6] = SIDE_HAIR_SHADOW
    c[15, 6:10] = SIDE_HAIR_BASE
    c[15, 10:12] = SIDE_HAIR_SHADOW
    c[15, 12] = SIDE_DARK
    c[15, 13:16] = SIDE_MASK_MID
    c[15, 16:21] = SIDE_MASK_LIGHT
    c[15, 21:25] = SIDE_MASK_MID
    c[15, 25] = SIDE_MASK_DARK
    c[15, 26:30] = SIDE_DARK

    # y=16: Back hair, sideburn, mask wing, glowing white eye upper
    c[16, 2:4] = SIDE_DARK
    c[16, 4:6] = SIDE_HAIR_SHADOW
    c[16, 6:9] = SIDE_HAIR_BASE
    c[16, 9:11] = SIDE_HAIR_SHADOW
    c[16, 11] = SIDE_DARK
    c[16, 12:15] = SIDE_MASK_MID
    c[16, 15] = SIDE_MASK_DARK
    c[16, 16:20] = SIDE_EYE_CORE
    c[16, 20] = SIDE_MASK_DARK
    c[16, 21:25] = SIDE_MASK_MID
    c[16, 25:27] = SIDE_MASK_DARK
    c[16, 27:30] = SIDE_DARK

    # y=17: Back hair, sideburn, mask, glowing white eye center
    c[17, 2:4] = SIDE_DARK
    c[17, 4:6] = SIDE_HAIR_SHADOW
    c[17, 6:9] = SIDE_HAIR_BASE
    c[17, 9:11] = SIDE_HAIR_SHADOW
    c[17, 11:13] = SIDE_SKIN_BASE
    c[17, 13:15] = SIDE_MASK_MID
    c[17, 15] = SIDE_MASK_DARK
    c[17, 16:20] = SIDE_EYE_CORE
    c[17, 20] = SIDE_MASK_DARK
    c[17, 21:25] = SIDE_MASK_MID
    c[17, 25:27] = SIDE_MASK_DARK
    c[17, 27:30] = SIDE_DARK

    # y=18: Back hair, sideburn tip, cheek skin, lower eye & mask bottom
    c[18, 2:4] = SIDE_DARK
    c[18, 4:6] = SIDE_HAIR_SHADOW
    c[18, 6:8] = SIDE_HAIR_BASE
    c[18, 8:10] = SIDE_HAIR_SHADOW
    c[18, 10:13] = SIDE_SKIN_BASE
    c[18, 13:15] = SIDE_MASK_MID
    c[18, 15:21] = SIDE_MASK_MID
    c[18, 21:24] = SIDE_MASK_MID
    c[18, 24:26] = SIDE_MASK_DARK
    c[18, 26:30] = SIDE_DARK

    # y=19: Mask bottom arch
    c[19, 2:4] = SIDE_DARK
    c[19, 4:6] = SIDE_HAIR_SHADOW
    c[19, 6:8] = SIDE_HAIR_SHADOW
    c[19, 8:14] = SIDE_SKIN_BASE
    c[19, 14:16] = SIDE_MASK_DARK
    c[19, 16:22] = SIDE_MASK_DARK
    c[19, 22:24] = SIDE_MASK_DARK
    c[19, 24:27] = SIDE_SKIN_BASE
    c[19, 27:30] = SIDE_DARK

    # y=20: Cheek / jawline
    c[20, 2:4] = SIDE_DARK
    c[20, 4:6] = SIDE_HAIR_SHADOW
    c[20, 6:16] = SIDE_SKIN_BASE
    c[20, 16:22] = SIDE_SKIN_SHADOW
    c[20, 22:27] = SIDE_SKIN_BASE
    c[20, 27:30] = SIDE_DARK

    # y=21..22: Lower cheek / jawline
    c[21, 3:5] = SIDE_DARK
    c[21, 5:26] = SIDE_SKIN_BASE
    c[21, 26:29] = SIDE_DARK

    c[22, 3:5] = SIDE_DARK
    c[22, 5:26] = SIDE_SKIN_BASE
    c[22, 26:29] = SIDE_DARK

    # y=23: Shooting mouth
    c[23, 4:6] = SIDE_DARK
    c[23, 6:17] = SIDE_SKIN_BASE
    c[23, 17:23] = SIDE_MOUTH_DARK
    c[23, 23:25] = SIDE_SKIN_BASE
    c[23, 25:28] = SIDE_DARK
    return c

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
    # Subpixels with alpha < 200 hold transparent white-ringing from original white background.
    # We strictly average subpixels with alpha >= 200 so background noise never enters foreground colors.
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

    # 4. Step 3: Clean up head frames (preserving glowing eyes & teeth, restoring warm hair and skin)
    print("Sanitizing head frames (hair brown, uniform skin, glowing eyes, teeth)...")
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

                # Hair region (y <= 12 and not skin tone)
                if y <= 12 and not is_skin:
                    if min(rc, gc, bc) > 175:
                        arr_512[gy, gx, :3] = [95, 65, 42]
                    elif diff < 15 and lum > 50:
                        if y <= 2 or x <= 4 or x >= 27:
                            arr_512[gy, gx, :3] = [20, 15, 10]
                        else:
                            arr_512[gy, gx, :3] = [95, 65, 42]
                # Face / skin / mask region (y >= 13)
                else:
                    is_eye = (14 <= y <= 19) and ((6 <= x <= 12) or (19 <= x <= 25) or (13 <= x <= 17)) and (gc >= 180 and gc >= rc)
                    is_teeth = (c == 8 and y in [20, 21] and 14 <= x <= 17)
                    if not (is_eye or is_teeth):
                        if min(rc, gc, bc) > 185:
                            arr_512[gy, gx, :3] = [225, 190, 175]
                        elif diff < 12 and 50 < lum < 185 and not is_skin:
                            arr_512[gy, gx, :3] = [225, 190, 175]

    # 4B. Build authentic single-eye superhero side head frames (Col 2 Idle & Col 3 Shooting)
    print("Applying authentic single-eye superhero side head for Col 2 (Idle) and Col 3 (Shooting)...")
    arr_512[0:32, 64:96] = build_side_head_idle(arr_512[0:32, 64:96])
    arr_512[0:32, 96:128] = build_side_head_shooting(arr_512[0:32, 96:128])

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
