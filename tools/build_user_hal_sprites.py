"""
tools/build_user_hal_sprites.py
Implements user-provided Hal Jordan sprite sheet into The Binding of Isaac: Repentance format.
- Input: 1024x1024 JPEG with white background.
- Preserves white gloves, chest emblem, eyes, and teeth via vanilla Isaac anatomical hull protection.
- Eliminates JPEG compression ringing, white halos, and mint edge fringes.
- Foreground-only area downscaling to 512x512 RGBA matching 001.000_player.anm2 grid.
- Crisp 1-bit binary alpha (0 semi-transparent pixels) matching authentic Repentance engine standards.
- Integrates teleport light beam & hole base in Col 4 & 6 (Y=320..448).
- Saves to resources/gfx/characters/hal_jordan.png and hal_jordan_extra.png.
"""

import os
import sys
import numpy as np
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_IMAGE_PATH = r"C:/Users/danic/.gemini/antigravity/brain/25a8c9be-14f1-4e9c-8c5f-e17d8ccace13/.user_uploaded/media_1792136633456_3f3fd8cf.jpg"
VANILLA_ISAAC_PATH = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png"

HAL_JORDAN_PATH = os.path.join(PROJECT_ROOT, "resources", "gfx", "characters", "hal_jordan.png")
HAL_EXTRA_PATH = os.path.join(PROJECT_ROOT, "resources", "gfx", "characters", "hal_jordan_extra.png")

def process_sheet():
    if not os.path.exists(SRC_IMAGE_PATH):
        raise FileNotFoundError(f"Source image not found: {SRC_IMAGE_PATH}")
    if not os.path.exists(VANILLA_ISAAC_PATH):
        raise FileNotFoundError(f"Vanilla Isaac reference not found: {VANILLA_ISAAC_PATH}")

    print(f"Loading {SRC_IMAGE_PATH}...")
    uploaded = Image.open(SRC_IMAGE_PATH).convert("RGB")
    arr_src = np.array(uploaded, dtype=float)
    H, W, _ = arr_src.shape
    assert H == 1024 and W == 1024, f"Expected 1024x1024, got {W}x{H}"

    print(f"Loading {VANILLA_ISAAC_PATH}...")
    vanilla = Image.open(VANILLA_ISAAC_PATH).convert("RGBA")
    arr_v = np.array(vanilla)
    v_mask_512 = arr_v[:, :, 3] > 0
    v_mask_1024 = np.repeat(np.repeat(v_mask_512, 2, axis=0), 2, axis=1)

    print("Segmenting foreground with anatomical protection for white gloves and emblem...")
    lum = 0.299 * arr_src[:, :, 0] + 0.587 * arr_src[:, :, 1] + 0.114 * arr_src[:, :, 2]
    chroma = arr_src.max(axis=2) - arr_src.min(axis=2)
    min_rgb = arr_src.min(axis=2)

    # 1. Definite foreground elements:
    # Any pixel with distinct color (green suit, brown hair, skin tones, ring sparks) or dark outline
    has_color = chroma > 18
    has_dark = (lum < 170) | (min_rgb < 120)
    distinct_fg = has_color | has_dark

    # 2. Interior white elements (white gloves, chest emblem, eyes, teeth) protected by vanilla silhouette
    # Inside the canonical character silhouette, pixels with min_rgb < 250 are preserved
    inside_vanilla_fg = v_mask_1024 & (min_rgb < 250)

    fg_mask = distinct_fg | inside_vanilla_fg

    # 3. Downscale to 512x512 via 2x2 area pooling with foreground-only RGB averaging
    # This prevents white background pixels from contaminating outline colors
    print("Downscaling to 512x512 RGBA with foreground-only averaging...")
    blocks = arr_src.reshape(512, 2, 512, 2, 3).transpose(0, 2, 1, 3, 4).reshape(512, 512, 4, 3)
    blocks_fg = fg_mask.reshape(512, 2, 512, 2).transpose(0, 2, 1, 3).reshape(512, 512, 4)
    k_fg = blocks_fg.sum(axis=2)

    rgb_sum = (blocks * blocks_fg[:, :, :, None]).sum(axis=2)
    rgb_mean = np.zeros((512, 512, 3), dtype=np.uint8)
    has_any_fg = k_fg > 0
    rgb_mean[has_any_fg] = np.clip(rgb_sum[has_any_fg] / k_fg[has_any_fg, None], 0, 255).astype(np.uint8)

    arr_512 = np.zeros((512, 512, 4), dtype=np.uint8)
    arr_512[:, :, :3] = rgb_mean
    # Majority vote: 2 or more subpixels in 2x2 block -> solid 1-bit pixel (0 semi-transparent blur)
    arr_512[k_fg >= 2, 3] = 255

    # 4. Integrate vanilla teleport light beam and death hole base
    print("Integrating vanilla teleport light beam and trapdoor base...")
    # Col 4 (X=128..160, Y=384..448): Hole death bottom
    arr_512[384:448, 128:160] = arr_v[384:448, 128:160]
    # Col 6 (X=192..224, Y=320..448): Teleport beam
    arr_512[320:448, 192:224] = arr_v[320:448, 192:224]

    # 5. Clean up any transparent pixels (ensure A=0 has RGB=0)
    arr_512[arr_512[:, :, 3] == 0, :3] = 0

    final_sheet = Image.fromarray(arr_512, mode="RGBA")

    # 6. Save output files
    print(f"Saving {HAL_JORDAN_PATH}...")
    final_sheet.save(HAL_JORDAN_PATH, "PNG")

    print(f"Saving {HAL_EXTRA_PATH}...")
    final_sheet.save(HAL_EXTRA_PATH, "PNG")

    print(f"Sprite generation complete! Solid pixels: {(arr_512[:, :, 3] == 255).sum()}, Semi: {((arr_512[:, :, 3] > 0) & (arr_512[:, :, 3] < 255)).sum()}")
    return final_sheet

if __name__ == "__main__":
    process_sheet()
