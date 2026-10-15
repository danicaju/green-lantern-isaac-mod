import os
from PIL import Image

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png").convert("RGBA")

# Colors
C_TRANSPARENT = (0, 0, 0, 0)
C_BLACK = (28, 20, 16, 255)

HAL_HAIR_DARK = (24, 16, 12, 255)
HAL_HAIR_MID = (46, 28, 20, 255)
HAL_HAIR_LIGHT = (74, 46, 32, 255)

HAL_SKIN_LIGHT = (255, 218, 185, 255)
HAL_SKIN_SHADOW = (186, 128, 96, 255)

HAL_MASK_OUTLINE = (0, 42, 16, 255)
HAL_MASK_DARK = (0, 110, 36, 255)
HAL_MASK_MID = (0, 170, 56, 255)
HAL_MASK_LIGHT = (0, 215, 75, 255)

HAL_EYE_WHITE = (255, 255, 255, 255)
HAL_EYE_GLOW = (210, 255, 225, 255)

THAL_HAIR_DARK = (20, 20, 24, 255)
THAL_HAIR_MID = (38, 36, 44, 255)
THAL_HAIR_LIGHT = (58, 56, 68, 255)
THAL_HAIR_STREAK = (240, 242, 250, 255)

THAL_SKIN_LIGHT = (218, 202, 196, 255)
THAL_SKIN_SHADOW = (136, 116, 108, 255)

THAL_MASK_DARK = (24, 24, 30, 255)
THAL_EYE_WHITE = (255, 255, 255, 255)

def build_hal_side_head_f0():
    base = isaac_img.crop((64, 0, 96, 32)).copy()
    b_px = base.load()
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    o_px = out.load()
    
    for y in range(32):
        for x in range(32):
            if b_px[x, y][3] > 0:
                o_px[x, y] = HAL_SKIN_LIGHT
                if b_px[x, y] == (0, 0, 0, 255) or (b_px[x, y][0] < 30 and b_px[x, y][1] < 30 and b_px[x, y][2] < 30):
                    o_px[x, y] = C_BLACK
                elif b_px[x, y][0] < 210:
                    o_px[x, y] = HAL_SKIN_SHADOW

    # Hal's Hair: clean solid superhero hair clumps (no checkerboard dither)
    # Top of head
    for y in range(2, 6):
        for x in range(5, 23):
            if o_px[x, y] not in [C_TRANSPARENT, C_BLACK]:
                o_px[x, y] = HAL_HAIR_DARK if y == 2 or x < 12 else HAL_HAIR_MID
    # Forehead bangs / locks
    for y in range(6, 9):
        for x in range(5, 20):
            if o_px[x, y] not in [C_TRANSPARENT, C_BLACK]:
                o_px[x, y] = HAL_HAIR_DARK if x < 10 else HAL_HAIR_MID
    for y in range(9, 11):
        for x in range(5, 16):
            if o_px[x, y] not in [C_TRANSPARENT, C_BLACK]:
                o_px[x, y] = HAL_HAIR_DARK if x < 9 else HAL_HAIR_MID
    # Front tuft pointing down towards mask
    for (fx, fy) in [(18, 9), (19, 9), (19, 8), (20, 7), (20, 8)]:
        if o_px[fx, fy] not in [C_TRANSPARENT, C_BLACK]:
            o_px[fx, fy] = HAL_HAIR_MID
    # Back hair down the skull
    for y in range(6, 17):
        for x in range(2, 10):
            if o_px[x, y] not in [C_TRANSPARENT, C_BLACK]:
                o_px[x, y] = HAL_HAIR_DARK if x < 7 else HAL_HAIR_MID

    # Hair top highlights
    for (hx, hy) in [(10, 3), (11, 3), (14, 3), (15, 3), (12, 4), (13, 4)]:
        if o_px[hx, hy] in [HAL_HAIR_DARK, HAL_HAIR_MID]:
            o_px[hx, hy] = HAL_HAIR_LIGHT

    # Domino mask: smooth curve from temple to cheek
    mask_pixels = [
        (12, 11), (13, 11), (14, 11), (15, 11), (16, 11), (17, 11), (18, 11), (19, 11), (20, 11),
        (11, 12), (12, 12), (13, 12), (14, 12), (15, 12), (16, 12), (17, 12), (18, 12), (19, 12), (20, 12), (21, 12),
        (10, 13), (11, 13), (12, 13), (13, 13), (20, 13), (21, 13), (22, 13), (23, 13),
        (10, 14), (11, 14), (12, 14), (13, 14), (20, 14), (21, 14), (22, 14),
        (11, 15), (12, 15), (13, 15), (20, 15), (21, 15),
        (13, 16), (14, 16), (15, 16), (16, 16), (17, 16), (18, 16), (19, 16), (20, 16),
        (14, 17), (15, 17), (16, 17), (17, 17), (18, 17), (19, 17),
    ]
    for (mx, my) in mask_pixels:
        if o_px[mx, my] != C_BLACK:
            o_px[mx, my] = HAL_MASK_MID

    for (mx, my) in [(13, 11), (14, 11), (15, 11), (16, 11), (17, 11), (21, 12), (22, 13)]:
        if o_px[mx, my] == HAL_MASK_MID:
            o_px[mx, my] = HAL_MASK_LIGHT
    for (mx, my) in [(10, 13), (10, 14), (11, 15), (14, 17), (15, 17), (16, 17), (17, 17), (18, 17)]:
        if o_px[mx, my] == HAL_MASK_MID:
            o_px[mx, my] = HAL_MASK_DARK

    # Glowing eye slit
    eye_pixels = [
        (15, 13), (16, 13), (17, 13), (18, 13),
        (14, 14), (15, 14), (16, 14), (17, 14), (18, 14), (19, 14),
        (15, 15), (16, 15), (17, 15), (18, 15),
    ]
    for (ex, ey) in eye_pixels:
        o_px[ex, ey] = HAL_EYE_WHITE
    for (gx, gy) in [(14, 14), (19, 14), (15, 13), (18, 13), (15, 15), (18, 15)]:
        o_px[gx, gy] = HAL_EYE_GLOW

    # Smirk
    o_px[22, 18] = C_BLACK
    o_px[23, 18] = C_BLACK
    o_px[24, 18] = C_BLACK
    o_px[25, 17] = C_BLACK
    
    return out

def build_hal_side_head_f1():
    f0 = build_hal_side_head_f0()
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.paste(f0.crop((0, 0, 32, 30)), (0, 2))
    px = out.load()
    # Squint on step bob
    px[16, 15] = HAL_EYE_WHITE
    px[17, 15] = HAL_EYE_WHITE
    px[18, 15] = HAL_EYE_WHITE
    return out

def build_thal_side_head_f0():
    base = isaac_img.crop((64, 0, 96, 32)).copy()
    b_px = base.load()
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    o_px = out.load()
    
    for y in range(32):
        for x in range(32):
            if b_px[x, y][3] > 0:
                o_px[x, y] = THAL_SKIN_LIGHT
                if b_px[x, y] == (0, 0, 0, 255) or (b_px[x, y][0] < 30 and b_px[x, y][1] < 30 and b_px[x, y][2] < 30):
                    o_px[x, y] = C_BLACK
                elif b_px[x, y][0] < 210:
                    o_px[x, y] = THAL_SKIN_SHADOW

    for y in range(2, 6):
        for x in range(5, 23):
            if o_px[x, y] not in [C_TRANSPARENT, C_BLACK]:
                o_px[x, y] = THAL_HAIR_DARK if y == 2 or x < 12 else THAL_HAIR_MID
    for y in range(6, 9):
        for x in range(5, 20):
            if o_px[x, y] not in [C_TRANSPARENT, C_BLACK]:
                o_px[x, y] = THAL_HAIR_DARK if x < 10 else THAL_HAIR_MID
    for y in range(9, 11):
        for x in range(5, 16):
            if o_px[x, y] not in [C_TRANSPARENT, C_BLACK]:
                o_px[x, y] = THAL_HAIR_DARK if x < 9 else THAL_HAIR_MID
    for (fx, fy) in [(18, 9), (19, 9), (19, 8), (20, 7), (20, 8)]:
        if o_px[fx, fy] not in [C_TRANSPARENT, C_BLACK]:
            o_px[fx, fy] = THAL_HAIR_MID
    for y in range(6, 17):
        for x in range(2, 10):
            if o_px[x, y] not in [C_TRANSPARENT, C_BLACK]:
                o_px[x, y] = THAL_HAIR_DARK if x < 7 else THAL_HAIR_MID

    # Parallax White Temple Streak
    for (sx, sy) in [(6, 7), (7, 7), (8, 7), (7, 8), (8, 8), (9, 8), (8, 9), (9, 9), (10, 9)]:
        if o_px[sx, sy] not in [C_BLACK, C_TRANSPARENT]:
            o_px[sx, sy] = THAL_HAIR_STREAK

    # Sharp black mask
    mask_pixels = [
        (12, 11), (13, 11), (14, 11), (15, 11), (16, 11), (17, 11), (18, 11), (19, 11), (20, 11),
        (11, 12), (12, 12), (13, 12), (14, 12), (15, 12), (16, 12), (17, 12), (18, 12), (19, 12), (20, 12), (21, 12),
        (10, 13), (11, 13), (12, 13), (13, 13), (20, 13), (21, 13), (22, 13), (23, 13),
        (10, 14), (11, 14), (12, 14), (13, 14), (20, 14), (21, 14), (22, 14),
        (11, 15), (12, 15), (13, 15), (20, 15), (21, 15),
        (13, 16), (14, 16), (15, 16), (16, 16), (17, 16), (18, 16), (19, 16), (20, 16),
        (14, 17), (15, 17), (16, 17), (17, 17), (18, 17), (19, 17),
    ]
    for (mx, my) in mask_pixels:
        if o_px[mx, my] != C_BLACK:
            o_px[mx, my] = THAL_MASK_DARK

    eye_pixels = [
        (15, 13), (16, 13), (17, 13), (18, 13),
        (14, 14), (15, 14), (16, 14), (17, 14), (18, 14), (19, 14),
        (15, 15), (16, 15), (17, 15), (18, 15),
    ]
    for (ex, ey) in eye_pixels:
        o_px[ex, ey] = THAL_EYE_WHITE

    # Fierce grimace
    o_px[22, 18] = C_BLACK
    o_px[23, 19] = C_BLACK
    o_px[24, 19] = C_BLACK
    o_px[25, 19] = C_BLACK
    o_px[24, 20] = C_BLACK
    
    return out

def build_thal_side_head_f1():
    f0 = build_thal_side_head_f0()
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.paste(f0.crop((0, 0, 32, 30)), (0, 2))
    return out

if __name__ == "__main__":
    hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
    thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")
    h0 = build_hal_side_head_f0()
    h1 = build_hal_side_head_f1()
    t0 = build_thal_side_head_f0()
    t1 = build_thal_side_head_f1()
    
    p = Image.new("RGBA", (32 * 4, 32 * 2), (230, 230, 230, 255))
    p.paste(isaac_img.crop((64, 0, 96, 32)), (0, 0))
    p.paste(isaac_img.crop((96, 0, 128, 32)), (32, 0))
    p.paste(h0, (64, 0), h0)
    p.paste(h1, (96, 0), h1)
    
    p.paste(hal_img.crop((64, 0, 96, 32)), (0, 32))
    p.paste(thal_img.crop((64, 0, 96, 32)), (32, 32))
    p.paste(t0, (64, 32), t0)
    p.paste(t1, (96, 32), t1)
    
    pz = p.resize((p.width * 4, p.height * 4), Image.NEAREST)
    pz.save("tools/new_side_heads_preview_zoom4x.png")
    print("Updated new_side_heads_preview_zoom4x.png")
