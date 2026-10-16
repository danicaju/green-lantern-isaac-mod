"""
tools/build_user_hal_sprites.py
Implements user-provided Hal Jordan sprite sheet into The Binding of Isaac: Repentance format.
- Input: 1024x1024 JPEG with white background.
- Clean transparency extraction: BFS flood fill preserving interior eyes, gloves, chest emblem, teeth.
- Decontaminates outline edges to completely eliminate white halos and fringing.
- Downscales to 512x512 RGBA aligned with 001.000_player.anm2 grid.
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

    print(f"Loading {SRC_IMAGE_PATH}...")
    uploaded = Image.open(SRC_IMAGE_PATH).convert("RGB")
    arr = np.array(uploaded)
    H, W, _ = arr.shape
    assert H == 1024 and W == 1024, f"Expected 1024x1024, got {W}x{H}"

    print("Computing chroma and background masks...")
    chroma = arr.max(axis=2).astype(int) - arr.min(axis=2).astype(int)
    min_rgb = arr.min(axis=2)

    bg_thresh = 225
    edge_thresh = 135
    max_chroma = 25

    is_bg_seed = (min_rgb >= bg_thresh) & (chroma <= max_chroma)

    # 1. BFS flood fill from outer boundaries to find exterior background
    visited_bg = np.zeros((H, W), dtype=bool)
    q = []
    for y in range(H):
        if is_bg_seed[y, 0]: visited_bg[y, 0] = True; q.append((y, 0))
        if is_bg_seed[y, W-1]: visited_bg[y, W-1] = True; q.append((y, W-1))
    for x in range(W):
        if is_bg_seed[0, x]: visited_bg[0, x] = True; q.append((0, x))
        if is_bg_seed[H-1, x]: visited_bg[H-1, x] = True; q.append((H-1, x))

    head = 0
    while head < len(q):
        y, x = q[head]
        head += 1
        for dy, dx in [(-1,0),(1,0),(0,-1),(0,1)]:
            ny, nx = y+dy, x+dx
            if 0 <= ny < H and 0 <= nx < W and not visited_bg[ny, nx] and is_bg_seed[ny, nx]:
                visited_bg[ny, nx] = True
                q.append((ny, nx))

    print(f"Exterior background seed count: {visited_bg.sum()}")

    # 2. Expand into exterior edge transition zone (neutral near-white ringing pixels)
    q_edge = [ (y, x) for y, x in zip(*np.where(visited_bg)) ]
    edge_visited = visited_bg.copy()
    head = 0
    while head < len(q_edge):
        y, x = q_edge[head]
        head += 1
        for dy, dx in [(-1,0),(1,0),(0,-1),(0,1)]:
            ny, nx = y+dy, x+dx
            if 0 <= ny < H and 0 <= nx < W and not edge_visited[ny, nx]:
                if min_rgb[ny, nx] >= edge_thresh and chroma[ny, nx] <= max_chroma:
                    edge_visited[ny, nx] = True
                    q_edge.append((ny, nx))

    print(f"Expanded exterior background count: {edge_visited.sum()}")

    # 3. Create clean 1024x1024 RGBA image
    rgba_1024 = np.zeros((H, W, 4), dtype=np.uint8)
    fg_mask = ~edge_visited
    rgba_1024[fg_mask, :3] = arr[fg_mask]
    rgba_1024[fg_mask, 3] = 255

    # 4. Color decontaminate boundary pixels to strip any residual white halo:
    # Any foreground pixel adjacent to edge_visited that has min_rgb > 90 and chroma <= 20
    # is a JPEG transition pixel between dark outline and white background.
    # Darken it towards the outline color so it doesn't bleed white during downsampling.
    # Check foreground boundary with simple numpy shifts
    fg_border = np.zeros((H, W), dtype=bool)
    for dy, dx in [(-1,0),(1,0),(0,-1),(0,1)]:
        shifted = np.roll(np.roll(edge_visited, dy, axis=0), dx, axis=1)
        fg_border |= (fg_mask & shifted)

    decontaminate_mask = fg_border & (min_rgb >= 90) & (chroma <= 25)
    print(f"Decontaminating {decontaminate_mask.sum()} boundary edge pixels...")
    # Scale down RGB of these transition pixels to eliminate white fringe
    for c in range(3):
        rgba_1024[decontaminate_mask, c] = np.clip(
            rgba_1024[decontaminate_mask, c].astype(float) * 0.4, 0, 255
        ).astype(np.uint8)

    # 5. Downsample to 512x512 using high quality Lanczos filter (premultiplied in PIL)
    print("Downscaling to 512x512 RGBA...")
    im_1024 = Image.fromarray(rgba_1024, mode="RGBA")
    im_512 = im_1024.resize((512, 512), Image.Resampling.LANCZOS)
    arr_512 = np.array(im_512)

    # Clean up faint anti-aliased whisper pixels (alpha < 25) to keep edges ultra clean
    arr_512[arr_512[:, :, 3] < 25, 3] = 0

    # 6. Integrate vanilla teleport light beam and death hole base into Col 4 and Col 6 (Y=320..448)
    if os.path.exists(VANILLA_ISAAC_PATH):
        print("Integrating vanilla teleport beam and hole base...")
        vanilla = Image.open(VANILLA_ISAAC_PATH).convert("RGBA")
        vanilla_arr = np.array(vanilla)
        
        # Col 4 (X=128..160, Y=320..448): Hole death bottom
        # Col 6 (X=192..224, Y=320..448): Teleport beam
        for col_idx in [4, 6]:
            x0 = col_idx * 32
            x1 = (col_idx + 1) * 32
            # Only copy where arr_512 is empty (alpha == 0)
            target_slice = arr_512[320:448, x0:x1]
            vanilla_slice = vanilla_arr[320:448, x0:x1]
            empty_mask = (target_slice[:, :, 3] == 0)
            target_slice[empty_mask] = vanilla_slice[empty_mask]

    final_sheet = Image.fromarray(arr_512, mode="RGBA")

    # 7. Save output files
    print(f"Saving {HAL_JORDAN_PATH}...")
    final_sheet.save(HAL_JORDAN_PATH, "PNG")

    print(f"Saving {HAL_EXTRA_PATH}...")
    final_sheet.save(HAL_EXTRA_PATH, "PNG")

    print("Sprite generation complete!")
    return final_sheet

if __name__ == "__main__":
    process_sheet()
