import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")

# Colors for Hal
C_BLACK = (28, 20, 16, 255)
HAL_SUIT_GREEN = (0, 170, 56, 255)
HAL_SUIT_GREEN_DARK = (0, 110, 36, 255)
HAL_SUIT_BLACK = (26, 26, 32, 255)
HAL_SUIT_BLACK_LIGHT = (48, 48, 56, 255)
HAL_GLOVE_WHITE = (245, 248, 250, 255)
HAL_GLOVE_SHADOW = (180, 190, 200, 255)
HAL_BOOT_GREEN = (0, 140, 48, 255)
HAL_BOOT_DARK = (0, 80, 26, 255)
HAL_RING_GREEN = (60, 255, 120, 255)

# Colors for THal
THAL_SUIT_DARK = (22, 22, 26, 255)
THAL_SUIT_MID = (38, 38, 46, 255)
THAL_SUIT_LIGHT = (58, 56, 68, 255)
THAL_BOOT_WHITE = (230, 230, 240, 255)
THAL_BOOT_SHADOW = (160, 160, 175, 255)
THAL_CAPE_OUTER = (30, 30, 36, 255)
THAL_CAPE_INNER = (50, 48, 58, 255)
THAL_RING_YELLOW = (255, 215, 25, 255)

walk_coords = [
    (0, 64), (32, 64), (64, 64), (96, 64), (128, 64),
    (160, 64), (192, 64), (224, 64), (0, 96), (32, 96)
]

def build_hal_walk_frame(f_idx):
    x0, y0 = walk_coords[f_idx]
    base = isaac_img.crop((x0, y0, x0 + 32, y0 + 32)).copy()
    b_px = base.load()
    
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    o_px = out.load()
    
    for y in range(32):
        for x in range(32):
            if b_px[x, y][3] > 0:
                is_outline = b_px[x, y] == (0, 0, 0, 255) or (b_px[x, y][0] < 30 and b_px[x, y][1] < 30 and b_px[x, y][2] < 30)
                if is_outline:
                    o_px[x, y] = C_BLACK
                else:
                    # Legs (y >= 21)
                    if y >= 21:
                        # Boots: bottom 3-4 pixels of the feet
                        if y >= 23:
                            o_px[x, y] = HAL_GLOVE_WHITE if b_px[x, y][0] > 200 else HAL_GLOVE_SHADOW
                        else:
                            # Upper boot / green pants
                            o_px[x, y] = HAL_BOOT_GREEN if b_px[x, y][0] > 200 else HAL_BOOT_DARK
                    # Torso & Arm (y < 21)
                    else:
                        # Front of chest (right side, x >= 17) -> Green Lantern green
                        if x >= 17:
                            o_px[x, y] = HAL_SUIT_GREEN if b_px[x, y][0] > 200 else HAL_SUIT_GREEN_DARK
                        # Back / sides (x < 15) -> Black suit
                        elif x < 15:
                            o_px[x, y] = HAL_SUIT_BLACK_LIGHT if b_px[x, y][0] > 200 else HAL_SUIT_BLACK
                        # Transition stripe / arm area (x in [15, 16])
                        else:
                            # Arm swinging at side: white glove on hand
                            if y >= 17 and y <= 20:
                                o_px[x, y] = HAL_GLOVE_WHITE if b_px[x, y][0] > 200 else HAL_GLOVE_SHADOW
                            else:
                                o_px[x, y] = HAL_SUIT_GREEN if b_px[x, y][0] > 210 else HAL_SUIT_BLACK
                                
    # Add green power ring on the glove finger
    # Locate the hand in rows 18..20
    for y in range(18, 21):
        for x in range(15, 19):
            if o_px[x, y] == HAL_GLOVE_WHITE:
                o_px[x, y] = HAL_RING_GREEN
                break
        if o_px[x, y] == HAL_RING_GREEN:
            break

    return out

def build_thal_walk_frame(f_idx):
    x0, y0 = walk_coords[f_idx]
    base = isaac_img.crop((x0, y0, x0 + 32, y0 + 32)).copy()
    b_px = base.load()
    
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    o_px = out.load()
    
    for y in range(32):
        for x in range(32):
            if b_px[x, y][3] > 0:
                is_outline = b_px[x, y] == (0, 0, 0, 255) or (b_px[x, y][0] < 30 and b_px[x, y][1] < 30 and b_px[x, y][2] < 30)
                if is_outline:
                    o_px[x, y] = C_BLACK
                else:
                    if y >= 22:
                        o_px[x, y] = THAL_BOOT_WHITE if b_px[x, y][0] > 200 else THAL_BOOT_SHADOW
                    else:
                        if x >= 17:
                            o_px[x, y] = THAL_SUIT_MID if b_px[x, y][0] > 200 else THAL_SUIT_DARK
                        else:
                            o_px[x, y] = THAL_SUIT_DARK
                            
    # Add Parallax cape billowing behind his back on the left side (x=5..9, y=13..23)
    # The cape follows the walking cycle motion:
    cape_offset = 0 if f_idx in [0, 4, 8] else (1 if f_idx in [1, 2, 5, 6] else -1)
    for y in range(13, 24):
        # width of cape expanding towards bottom
        w = 3 + (y - 13) // 3
        # find the back edge of the body at this y
        body_left = 32
        for x in range(32):
            if o_px[x, y][3] > 0:
                body_left = x
                break
        if body_left < 32:
            start_x = max(2, body_left - w + cape_offset)
            for cx in range(start_x, body_left):
                if cx == start_x or y == 23:
                    o_px[cx, y] = C_BLACK
                else:
                    o_px[cx, y] = THAL_CAPE_OUTER if cx % 2 == 0 else THAL_CAPE_INNER

    # Add yellow fear ring on the hand
    for y in range(18, 21):
        for x in range(15, 19):
            if o_px[x, y] in [THAL_SUIT_MID, THAL_SUIT_LIGHT, THAL_BOOT_WHITE]:
                o_px[x, y] = THAL_RING_YELLOW
                break
        if o_px[x, y] == THAL_RING_YELLOW:
            break

    return out

# Generate preview of all 10 walk frames for Isaac, Hal, and THal
walk_preview = Image.new("RGBA", (32 * 10, 32 * 3), (235, 235, 235, 255))
for f in range(10):
    x0, y0 = walk_coords[f]
    i_f = isaac_img.crop((x0, y0, x0 + 32, y0 + 32))
    h_f = build_hal_walk_frame(f)
    t_f = build_thal_walk_frame(f)
    
    walk_preview.paste(i_f, (f * 32, 0), i_f)
    walk_preview.paste(h_f, (f * 32, 32), h_f)
    walk_preview.paste(t_f, (f * 32, 64), t_f)

walk_zoom = walk_preview.resize((walk_preview.width * 4, walk_preview.height * 4), Image.NEAREST)
walk_zoom.save("tools/walk_frames_preview_zoom4x.png")
print("Saved tools/walk_frames_preview_zoom4x.png")
