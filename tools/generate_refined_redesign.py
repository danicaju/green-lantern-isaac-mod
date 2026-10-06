"""
tools/generate_refined_redesign.py
Creates refined pixel art for Hal Jordan and Parallax directly modifying
the authentic Isaac sprite sheet (character_001_isaac.png).
Outputs high-res side-by-side comparison showcase for user review.
"""

import os
from PIL import Image, ImageDraw

VANILLA_PATH = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\character_001_isaac.png"
ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\1da92c3a-b6b6-41f0-ae66-135ed6eb06a2"

# Palettes
OUTLINE = (28, 22, 21, 255)
SKIN_BASE = (232, 186, 158, 255)
SKIN_SHADOW = (201, 148, 120, 255)
SKIN_HIGHLIGHT = (244, 212, 192, 255)

# Hair (Hal Jordan pilot brown)
HAIR_DARK = (44, 26, 17, 255)
HAIR_BASE = (93, 58, 36, 255)
HAIR_MID = (118, 77, 49, 255)
HAIR_LIGHT = (145, 98, 64, 255)

# Silver temples for Parallax
SILVER_DARK = (120, 144, 156, 255)
SILVER_BASE = (176, 190, 197, 255)
SILVER_LIGHT = (236, 239, 241, 255)

# Emerald
EMERALD_OUTLINE = (0, 77, 32, 255)
EMERALD_DARK = (0, 122, 51, 255)
EMERALD_BASE = (0, 200, 83, 255)
EMERALD_LIGHT = (0, 230, 118, 255)
EMERALD_GLOW = (105, 240, 174, 255)

# Whites & Blacks
WHITE = (255, 255, 255, 255)
WHITE_GLOW = (235, 255, 242, 255)
BLACK_SUIT = (24, 24, 24, 255)
BLACK_SUIT_LIGHT = (48, 48, 52, 255)

# Parallax colors
PARALLAX_YELLOW = (238, 255, 65, 255)
PARALLAX_YELLOW_GLOW = (255, 255, 170, 255)
PARALLAX_ARMOR_DARK = (0, 60, 25, 255)
PARALLAX_ARMOR_BASE = (0, 145, 58, 255)
PARALLAX_ARMOR_LIGHT = (0, 215, 85, 255)

def clean_isaac_head(crop_img):
    """Removes tears and crying mouth from vanilla Isaac head."""
    img = crop_img.copy().convert("RGBA")
    pix = img.load()
    for x in range(32):
        for y in range(32):
            p = pix[x, y]
            if p[3] > 30 and p[2] > p[0] + 10:
                pix[x, y] = SKIN_BASE if y < 22 else SKIN_SHADOW
    # Clean mouth
    for y in range(16, 19):
        for x in range(12, 19):
            if pix[x, y] != OUTLINE or (y in (16, 17) and 13 <= x <= 17):
                pix[x, y] = SKIN_BASE
    return img

def render_hal_head_front(clean_head, eye_style="comic_white"):
    img = clean_head.copy()
    pix = img.load()

    # 1. Pilot Hair (Y=2..11)
    for y in range(2, 12):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline and y <= 9:
                    pix[x, y] = HAIR_DARK
                elif not is_outline:
                    is_hair = False
                    if y <= 7: is_hair = True
                    elif y == 8 and (x < 12 or x > 16): is_hair = True
                    elif y == 9 and (x < 9 or x > 21 or (13 <= x <= 15)): is_hair = True
                    elif y == 10 and (x < 6 or x > 24): is_hair = True
                    elif y == 11 and (x < 5 or x > 25): is_hair = True

                    if is_hair:
                        if y <= 4: pix[x, y] = HAIR_MID
                        elif y in (5, 6) and (9 <= x <= 14 or 18 <= x <= 22): pix[x, y] = HAIR_LIGHT
                        elif y >= 8: pix[x, y] = HAIR_BASE
                        else: pix[x, y] = HAIR_BASE

    for x in range(3, 29):
        for y in range(6, 12):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                if y + 1 < 32 and pix[x, y+1] not in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                    pix[x, y] = HAIR_DARK

    # 2. Domino Mask
    mask_pixels = set()
    for y in range(12, 19):
        for x in range(4, 28):
            p = pix[x, y]
            if p[3] > 30 and p != HAIR_DARK:
                in_mask = False
                if 5 <= x <= 12 and 12 <= y <= 18: in_mask = True
                elif 18 <= x <= 25 and 12 <= y <= 18: in_mask = True
                elif 13 <= x <= 17 and 13 <= y <= 16: in_mask = True
                elif (x in (4, 26) and 13 <= y <= 16) or (x in (3, 27) and y == 14): in_mask = True
                if in_mask: mask_pixels.add((x, y))

    for (x, y) in mask_pixels:
        is_border = False
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            if (x+dx, y+dy) not in mask_pixels:
                is_border = True; break
        if is_border:
            pix[x, y] = EMERALD_OUTLINE
        else:
            if y == 13 and (7 <= x <= 10 or 20 <= x <= 23):
                pix[x, y] = EMERALD_LIGHT
            else:
                pix[x, y] = EMERALD_BASE

    # 3. Eyes
    if eye_style == "comic_white":
        for y in range(14, 18):
            for x in range(7, 11): pix[x, y] = WHITE
        pix[7, 14] = EMERALD_GLOW; pix[10, 14] = EMERALD_GLOW
        pix[7, 17] = EMERALD_DARK; pix[10, 17] = EMERALD_DARK
        pix[8, 15] = WHITE_GLOW; pix[9, 15] = WHITE_GLOW

        for y in range(14, 18):
            for x in range(20, 24): pix[x, y] = WHITE
        pix[20, 14] = EMERALD_GLOW; pix[23, 14] = EMERALD_GLOW
        pix[20, 17] = EMERALD_DARK; pix[23, 17] = EMERALD_DARK
        pix[21, 15] = WHITE_GLOW; pix[22, 15] = WHITE_GLOW
    else: # isaac_black
        for y in range(14, 18):
            for x in range(7, 11): pix[x, y] = OUTLINE
        pix[8, 14] = WHITE; pix[8, 15] = WHITE
        for y in range(14, 18):
            for x in range(20, 24): pix[x, y] = OUTLINE
        pix[21, 14] = WHITE; pix[21, 15] = WHITE

    # Mouth
    pix[14, 20] = OUTLINE; pix[15, 20] = OUTLINE
    pix[16, 20] = OUTLINE; pix[17, 19] = OUTLINE
    return img

def render_hal_head_right(clean_head, eye_style="comic_white"):
    img = clean_head.copy()
    pix = img.load()

    # 1. Hair covering top and back of skull down to nape
    for y in range(2, 19):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                is_hair = False

                if y <= 7:
                    is_hair = True
                elif y in (8, 9, 10):
                    if x <= 18 or x >= 21:
                        is_hair = True
                elif y in (11, 12):
                    if x <= 14 or (x in (21, 22) and y == 11):
                        is_hair = True
                elif y in (13, 14):
                    if x <= 13:
                        is_hair = True
                elif y in (15, 16):
                    if x <= 11:
                        is_hair = True
                elif y in (17, 18):
                    if x <= 9:
                        is_hair = True

                if is_hair:
                    if is_outline:
                        pix[x, y] = HAIR_DARK
                    else:
                        if y <= 4:
                            pix[x, y] = HAIR_MID
                        elif y in (5, 6) and (8 <= x <= 16):
                            pix[x, y] = HAIR_LIGHT
                        elif y >= 8:
                            pix[x, y] = HAIR_BASE
                        else:
                            pix[x, y] = HAIR_BASE

    # Dark hair perimeter borders
    for x in range(3, 29):
        for y in range(7, 19):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                if y + 1 < 32 and pix[x, y+1] not in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                    pix[x, y] = HAIR_DARK
                elif x + 1 < 32 and pix[x+1, y] not in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                    pix[x, y] = HAIR_DARK

    # 2. Domino Mask in profile: sits over eye socket (x=13..22, y=12..18)
    mask_pixels = set()
    for y in range(12, 19):
        for x in range(13, 23):
            p = pix[x, y]
            if p[3] > 30 and p != HAIR_DARK:
                if y in (12, 18) and 14 <= x <= 21:
                    mask_pixels.add((x, y))
                elif 13 <= y <= 17 and 13 <= x <= 22:
                    mask_pixels.add((x, y))

    for (x, y) in mask_pixels:
        is_border = False
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            if (x+dx, y+dy) not in mask_pixels:
                is_border = True
                break
        if is_border:
            pix[x, y] = EMERALD_OUTLINE
        else:
            pix[x, y] = EMERALD_LIGHT if y == 13 else EMERALD_BASE

    # 3. Eye inside mask (x=15..19, y=14..17)
    if eye_style == "comic_white":
        for y in range(14, 18):
            for x in range(15, 20):
                if (x, y) in mask_pixels:
                    pix[x, y] = WHITE
        pix[15, 14] = EMERALD_GLOW
        pix[19, 14] = EMERALD_GLOW
        pix[15, 17] = EMERALD_DARK
        pix[19, 17] = EMERALD_DARK
        pix[16, 15] = WHITE_GLOW
        pix[17, 15] = WHITE_GLOW
    else: # isaac_black
        for y in range(14, 18):
            for x in range(15, 20):
                if (x, y) in mask_pixels:
                    pix[x, y] = OUTLINE
        pix[16, 14] = WHITE
        pix[16, 15] = WHITE

    # Mouth/nose in profile
    pix[25, 17] = OUTLINE
    pix[26, 17] = OUTLINE
    return img

def render_hal_head_up(clean_head):
    img = clean_head.copy()
    pix = img.load()
    for y in range(2, 22):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline and y <= 18:
                    pix[x, y] = HAIR_DARK
                elif not is_outline and y <= 18:
                    if y <= 6:
                        pix[x, y] = HAIR_MID
                    elif y in (7, 8) and (10 <= x <= 22):
                        pix[x, y] = HAIR_LIGHT
                    elif y >= 14:
                        pix[x, y] = HAIR_BASE
                    else:
                        pix[x, y] = HAIR_BASE
    # Neckline contour
    for x in range(6, 26):
        if pix[x, 18] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
            pix[x, 18] = HAIR_DARK
    return img

def render_parallax_head_front(clean_head):
    img = clean_head.copy()
    pix = img.load()
    for y in range(2, 12):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline and y <= 9: pix[x, y] = HAIR_DARK
                elif not is_outline:
                    is_hair = False
                    if y <= 7: is_hair = True
                    elif y == 8 and (x < 12 or x > 16): is_hair = True
                    elif y == 9 and (x < 9 or x > 21 or (13 <= x <= 15)): is_hair = True
                    elif y == 10 and (x < 6 or x > 24): is_hair = True
                    elif y == 11 and (x < 5 or x > 25): is_hair = True
                    if is_hair:
                        # Silver temple streaks
                        if (4 <= x <= 7 or 23 <= x <= 26) and 6 <= y <= 11:
                            if y in (7, 8): pix[x, y] = SILVER_LIGHT
                            elif y == 9: pix[x, y] = SILVER_BASE
                            else: pix[x, y] = SILVER_DARK
                        elif y <= 4: pix[x, y] = HAIR_MID
                        else: pix[x, y] = HAIR_BASE

    for x in range(3, 29):
        for y in range(6, 12):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, SILVER_BASE, SILVER_LIGHT, SILVER_DARK):
                if y + 1 < 32 and pix[x, y+1] not in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK, SILVER_BASE, SILVER_LIGHT, SILVER_DARK):
                    pix[x, y] = HAIR_DARK

    mask_pixels = set()
    for y in range(12, 19):
        for x in range(4, 28):
            p = pix[x, y]
            if p[3] > 30 and p not in (HAIR_DARK, SILVER_DARK):
                in_mask = False
                if 5 <= x <= 12 and 12 <= y <= 18: in_mask = True
                elif 18 <= x <= 25 and 12 <= y <= 18: in_mask = True
                elif 13 <= x <= 17 and 13 <= y <= 16: in_mask = True
                elif (x in (4, 26) and 13 <= y <= 16) or (x in (3, 27) and y == 14): in_mask = True
                if in_mask: mask_pixels.add((x, y))

    for (x, y) in mask_pixels:
        is_border = False
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            if (x+dx, y+dy) not in mask_pixels:
                is_border = True; break
        if is_border: pix[x, y] = EMERALD_OUTLINE
        else: pix[x, y] = PARALLAX_ARMOR_BASE

    for y in range(14, 18):
        for x in range(7, 11): pix[x, y] = PARALLAX_YELLOW
    pix[8, 15] = PARALLAX_YELLOW_GLOW; pix[9, 15] = PARALLAX_YELLOW_GLOW
    pix[7, 14] = EMERALD_GLOW; pix[10, 14] = EMERALD_GLOW

    for y in range(14, 18):
        for x in range(20, 24): pix[x, y] = PARALLAX_YELLOW
    pix[21, 15] = PARALLAX_YELLOW_GLOW; pix[22, 15] = PARALLAX_YELLOW_GLOW
    pix[20, 14] = EMERALD_GLOW; pix[23, 14] = EMERALD_GLOW

    pix[14, 20] = OUTLINE; pix[15, 20] = OUTLINE
    pix[16, 20] = OUTLINE; pix[17, 20] = OUTLINE
    return img

def render_parallax_head_right(clean_head):
    img = render_hal_head_right(clean_head, eye_style="comic_white")
    pix = img.load()
    # Add silver temple to profile (x=7..12, y=8..13)
    for y in range(8, 14):
        for x in range(7, 12):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                pix[x, y] = SILVER_LIGHT if y in (9, 10) else SILVER_BASE
    # Cosmic yellow eye in profile (x=15..19, y=14..17)
    for y in range(14, 18):
        for x in range(15, 20):
            if pix[x, y] in (WHITE, WHITE_GLOW, EMERALD_GLOW):
                pix[x, y] = PARALLAX_YELLOW
    pix[16, 15] = PARALLAX_YELLOW_GLOW
    pix[17, 15] = PARALLAX_YELLOW_GLOW
    return img

def render_parallax_head_up(clean_head):
    img = render_hal_head_up(clean_head)
    pix = img.load()
    # Silver temples visible on left and right sides
    for y in range(7, 14):
        for x in range(4, 8):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                pix[x, y] = SILVER_LIGHT if y in (8, 9) else SILVER_BASE
        for x in range(24, 28):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                pix[x, y] = SILVER_LIGHT if y in (8, 9) else SILVER_BASE
    return img

def render_hal_body_front(base_body):
    img = base_body.copy().convert("RGBA")
    pix = img.load()
    for y in range(12, 25):
        for x in range(5, 27):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline: continue
                if 12 <= y <= 19:
                    if (x <= 10 or x >= 21) and y <= 18:
                        if y in (16, 17) and (x in (7, 8, 23, 24)):
                            pix[x, y] = WHITE
                        else:
                            pix[x, y] = BLACK_SUIT
                    elif 11 <= x <= 20:
                        dist_sq = (x - 15.5)**2 + (y - 15.5)**2
                        if dist_sq <= 3.2:
                            if 15 <= x <= 16 and y in (15, 16):
                                pix[x, y] = EMERALD_DARK
                            else:
                                pix[x, y] = WHITE
                        else:
                            pix[x, y] = EMERALD_LIGHT if y == 13 else EMERALD_BASE
                    else:
                        pix[x, y] = EMERALD_BASE
                elif 20 <= y <= 24:
                    if y in (20, 21): pix[x, y] = BLACK_SUIT
                    else: pix[x, y] = EMERALD_BASE
    if pix[24, 18][3] > 30: pix[24, 18] = EMERALD_GLOW
    return img

def render_parallax_body_front(base_body):
    img = base_body.copy().convert("RGBA")
    pix = img.load()
    for y in range(12, 25):
        for x in range(4, 28):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline: continue
                if 12 <= y <= 19:
                    if (x in (5, 6, 25, 26)) and y >= 14:
                        pix[x, y] = PARALLAX_ARMOR_DARK
                    elif y in (12, 13, 14) and (7 <= x <= 11 or 20 <= x <= 24):
                        pix[x, y] = PARALLAX_ARMOR_LIGHT if y == 12 else PARALLAX_ARMOR_BASE
                    elif 12 <= x <= 19:
                        if y in (15, 16) and 14 <= x <= 17:
                            pix[x, y] = PARALLAX_YELLOW
                        elif y % 2 == 0:
                            pix[x, y] = BLACK_SUIT
                        else:
                            pix[x, y] = PARALLAX_ARMOR_BASE
                    elif (x in (7, 8, 23, 24)) and y in (17, 18):
                        pix[x, y] = EMERALD_DARK
                    else:
                        pix[x, y] = BLACK_SUIT
                elif 20 <= y <= 24:
                    if y in (20, 21): pix[x, y] = BLACK_SUIT
                    else: pix[x, y] = PARALLAX_ARMOR_BASE
    pix[7, 17] = PARALLAX_YELLOW; pix[8, 18] = EMERALD_GLOW
    pix[23, 17] = PARALLAX_YELLOW; pix[24, 18] = EMERALD_GLOW
    return img

def assemble_full(head, body):
    """
    In Isaac engine, head sits over body with the chin slightly overlapping collar.
    Standard sprite frame canvas: 32x38.
    Head at (0, 0), Body at (0, 13).
    Body torso & boots stick out visibly below the chin!
    """
    canvas = Image.new("RGBA", (32, 38), (0, 0, 0, 0))
    # Paste body first
    canvas.paste(body, (0, 13), body)
    # Paste head over body
    canvas.paste(head, (0, 0), head)
    return canvas

def main():
    vanilla_sheet = Image.open(VANILLA_PATH).convert("RGBA")
    current_hal = Image.open(r"resources\gfx\characters\hal_jordan.png").convert("RGBA")
    current_tainted = Image.open(r"resources\gfx\characters\tainted_hal.png").convert("RGBA")

    v_head_down = vanilla_sheet.crop((0, 0, 32, 32))
    v_head_right = vanilla_sheet.crop((64, 0, 96, 32))
    v_head_up = vanilla_sheet.crop((128, 0, 160, 32))
    v_body_down = vanilla_sheet.crop((0, 32, 32, 64))

    c_head_down = current_hal.crop((0, 0, 32, 32))
    c_head_right = current_hal.crop((64, 0, 96, 32))
    c_head_up = current_hal.crop((128, 0, 160, 32))
    c_body_down = current_hal.crop((0, 32, 32, 64))

    ct_head_down = current_tainted.crop((0, 0, 32, 32))
    ct_head_right = current_tainted.crop((64, 0, 96, 32))
    ct_head_up = current_tainted.crop((128, 0, 160, 32))
    ct_body_down = current_tainted.crop((0, 32, 32, 64))

    v_head_clean = clean_isaac_head(v_head_down)
    v_head_right_clean = clean_isaac_head(v_head_right)
    v_head_up_clean = clean_isaac_head(v_head_up)

    # Proposed Hal (White Comic Eyes)
    hal_white_head_d = render_hal_head_front(v_head_clean, "comic_white")
    hal_white_head_r = render_hal_head_right(v_head_right_clean, "comic_white")
    hal_white_head_u = render_hal_head_up(v_head_up_clean)
    hal_body = render_hal_body_front(v_body_down)

    # Proposed Hal (Classic Isaac Black Eyes)
    hal_black_head_d = render_hal_head_front(v_head_clean, "isaac_black")
    hal_black_head_r = render_hal_head_right(v_head_right_clean, "isaac_black")
    hal_black_head_u = hal_white_head_u

    # Proposed Parallax (Tainted)
    parallax_head_d = render_parallax_head_front(v_head_clean)
    parallax_head_r = render_parallax_head_right(v_head_right_clean)
    parallax_head_u = render_parallax_head_up(v_head_up_clean)
    parallax_body = render_parallax_body_front(v_body_down)

    # Assemble Full Characters
    v_full = assemble_full(v_head_down, v_body_down)
    c_hal_full = assemble_full(c_head_down, c_body_down)
    ct_hal_full = assemble_full(ct_head_down, ct_body_down)
    new_hal_white_full = assemble_full(hal_white_head_d, hal_body)
    new_hal_black_full = assemble_full(hal_black_head_d, hal_body)
    new_parallax_full = assemble_full(parallax_head_d, parallax_body)

    # Build High Resolution Showcase (6 Columns x 150px = 900px wide, 680px tall)
    SCALE = 4
    COL_W = 150
    CANVAS_W = COL_W * 6
    CANVAS_H = 680
    showcase = Image.new("RGBA", (CANVAS_W, CANVAS_H), (18, 18, 22, 255))
    draw = ImageDraw.Draw(showcase)

    columns = [
        ("1. Vanilla Isaac", v_full, v_head_down, v_head_right, v_head_up, (180, 180, 180)),
        ("2. Current Mod Hal", c_hal_full, c_head_down, c_head_right, c_head_up, (230, 90, 90)),
        ("3. Current Mod Tainted", ct_hal_full, ct_head_down, ct_head_right, ct_head_up, (230, 90, 90)),
        ("4. Proposed Hal (White Eyes)", new_hal_white_full, hal_white_head_d, hal_white_head_r, hal_white_head_u, (0, 230, 118)),
        ("5. Proposed Hal (Black Eyes)", new_hal_black_full, hal_black_head_d, hal_black_head_r, hal_black_head_u, (0, 200, 160)),
        ("6. Proposed Parallax", new_parallax_full, parallax_head_d, parallax_head_r, parallax_head_u, (255, 235, 59)),
    ]

    for idx, (title, full_c, head_d, head_r, head_u, color) in enumerate(columns):
        cx = idx * COL_W + 10
        draw.text((cx, 8), title, fill=color)

        # 1. Full Assembled Character (32x38 at 4x = 128x152)
        draw.text((cx, 28), "Full Character (4x)", fill=(120, 120, 130))
        full_4x = full_c.resize((32 * SCALE, 38 * SCALE), Image.NEAREST)
        showcase.paste(full_4x, (cx, 44), full_4x)

        # 2. Front Head (32x32 at 4x = 128x128)
        draw.text((cx, 208), "Front Head (4x)", fill=(120, 120, 130))
        hd_4x = head_d.resize((32 * SCALE, 32 * SCALE), Image.NEAREST)
        showcase.paste(hd_4x, (cx, 224), hd_4x)

        # 3. Profile Head (32x32 at 4x = 128x128)
        draw.text((cx, 360), "Profile Head (4x)", fill=(120, 120, 130))
        hr_4x = head_r.resize((32 * SCALE, 32 * SCALE), Image.NEAREST)
        showcase.paste(hr_4x, (cx, 376), hr_4x)

        # 4. Back Head (32x32 at 4x = 128x128)
        draw.text((cx, 512), "Back Head (4x)", fill=(120, 120, 130))
        hu_4x = head_u.resize((32 * SCALE, 32 * SCALE), Image.NEAREST)
        showcase.paste(hu_4x, (cx, 528), hu_4x)

    showcase_path = "character_showcase_comparison.png"
    showcase.save(showcase_path)
    # Also save to artifact directory so it's readily accessible
    artifact_showcase = os.path.join(ARTIFACT_DIR, "character_showcase_comparison.png")
    showcase.save(artifact_showcase)
    print(f"Saved {showcase_path} and {artifact_showcase}")

if __name__ == "__main__":
    main()
