"""
tools/build_character_redesign.py
Master sprite generator and verification suite for Hal Jordan and Tainted Hal redesigns.
Directly implements the user-provided sketch while strictly adhering to:
1. Authentic Binding of Isaac Repentance head positioning, pivots, and layers (Rule 3/Coordinate constraints).
2. Character Sprite Protection (Rule 4: Keeps active sheets safe, outputs proposed sheets and artifact showcases).
3. 100% item costume merge compatibility across Front, Side, and Back orientations.
"""

import os
import sys
from PIL import Image, ImageDraw

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_DIR not in sys.path:
    sys.path.insert(0, PROJECT_DIR)

VANILLA_PATH = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\character_001_isaac.png"
CURRENT_HAL_PATH = os.path.join(PROJECT_DIR, r"resources\gfx\characters\hal_jordan.png")
CURRENT_TAINTED_PATH = os.path.join(PROJECT_DIR, r"resources\gfx\characters\tainted_hal.png")
ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\c85d05f1-0104-407a-a3c0-1180d226af49"

EXTRACTED_RES = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx"
PATH_2020 = os.path.join(EXTRACTED_RES, r"characters\costumes\costume_245_2020.png")
PATH_HALO = os.path.join(EXTRACTED_RES, r"characters\costumes\costume_119_halo.png")
PATH_SADONION = os.path.join(EXTRACTED_RES, r"characters\costumes\costume_058_sadonion.png")
PATH_MONSTRO = os.path.join(EXTRACTED_RES, r"characters\costumes\costume_monstros lung.png")

# ==================== AUTHENTIC COLOR PALETTES ====================
OUTLINE = (12, 14, 12, 255)
HAIR_OUTLINE = (28, 20, 16, 255)

# Skin (authentic Isaac)
SKIN_LIGHT = (235, 190, 165, 255)
SKIN_BASE = (204, 152, 128, 255)
SKIN_SHADOW = (172, 118, 96, 255)

# Hal Jordan Hair (Warm pilot chestnut brown #67442b from user sketch)
HAIR_DARK = (44, 26, 17, 255)
HAIR_BASE = (103, 68, 43, 255)
HAIR_MID = (128, 86, 56, 255)
HAIR_LIGHT = (165, 115, 75, 255)

# Parallax Silver Temples
SILVER_DARK = (100, 115, 125, 255)
SILVER_BASE = (175, 188, 196, 255)
SILVER_LIGHT = (235, 242, 246, 255)
THAL_HAIR_BASE = (72, 54, 46, 255)

# Hal Jordan Domino Mask (Iconic emerald hero mask)
MASK_OUTLINE = (6, 52, 18, 255)
MASK_DEEP = (12, 85, 32, 255)
MASK_BASE = (24, 168, 62, 255)
MASK_LIGHT = (58, 232, 102, 255)
MASK_GLOW = (135, 255, 165, 255)

# Eyes (Glowing White Comic Hero Lenses)
WHITE = (255, 255, 255, 255)
EYE_GLOW = (220, 255, 232, 255)
EYE_RIM = (105, 240, 174, 255)

# Parallax Eyes (Piercing Cosmic Yellow Glow)
PARALLAX_YELLOW_DEEP = (200, 160, 20, 255)
PARALLAX_YELLOW_BASE = (255, 225, 45, 255)
PARALLAX_YELLOW_GLOW = (255, 255, 175, 255)

# Hal Jordan Suit (Directly from User Sketch)
# Dark Forest Green: shoulders, outer torso, sleeves, waist, pants
SUIT_DARK_OUTLINE = (10, 36, 18, 255)
SUIT_DARK_BASE = (22, 78, 38, 255)
SUIT_DARK_LIGHT = (34, 106, 54, 255)

# Light Vibrant Emerald Green: chest plate, gauntlets/gloves, boots
SUIT_LIGHT_BASE = (92, 204, 112, 255)
SUIT_LIGHT_BRIGHT = (138, 235, 154, 255)
SUIT_LIGHT_DARK = (52, 158, 76, 255)

# Chest Emblem (Lantern Logo)
EMBLEM_LINE = (14, 60, 26, 255)
EMBLEM_CORE = (180, 250, 190, 255)

# Power Ring
RING_GEM = (0, 255, 128, 255)
RING_AURA = (140, 255, 190, 255)
THAL_RING_YELLOW = (255, 230, 40, 255)

# Parallax Suit & Billowing Cape
PARALLAX_CAPE_BASE = (24, 140, 68, 255)
PARALLAX_CAPE_DARK = (10, 75, 34, 255)
PARALLAX_CAPE_LIGHT = (48, 190, 96, 255)
PARALLAX_ARMOR_BASE = (24, 30, 28, 255)
PARALLAX_ARMOR_LIGHT = (44, 56, 52, 255)
PARALLAX_CREST_GOLD = (255, 215, 30, 255)

# ==================== HEAD GENERATION ====================

def clean_base_head(base_head):
    """Removes tears and crying mouth to expose a clean facial canvas."""
    img = base_head.copy().convert("RGBA")
    pix = img.load()
    for y in range(12, 24):
        for x in range(5, 27):
            p = pix[x, y]
            if p[3] > 30 and (p[2] > p[0] + 5 or (p[0] > 200 and p[1] > 200 and p[2] > 220)):
                pix[x, y] = SKIN_BASE if y >= 20 else SKIN_LIGHT
    for y in range(16, 20):
        for x in range(12, 20):
            if pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_LIGHT if y <= 18 else SKIN_BASE
    return img

def render_hal_head_front(base_head, is_shooting=False):
    img = clean_base_head(base_head)
    pix = img.load()

    hair_pixels = set()
    for y in range(2, 8):
        for x in range(2, 30):
            if pix[x, y][3] > 30:
                hair_pixels.add((x, y))

    # Spikes extending above skull Y=2 matching user sketch:
    left_spike = [(7, 1), (8, 1), (7, 2), (8, 2), (9, 2)]
    center_spike = [(16, 0), (17, 0), (15, 1), (16, 1), (17, 1), (18, 1),
                    (14, 2), (15, 2), (16, 2), (17, 2), (18, 2), (19, 2)]
    right_spike = [(24, 1), (25, 1), (23, 2), (24, 2), (25, 2), (26, 2)]
    side_spikes = [(3, 6), (2, 7), (3, 7), (2, 8), (3, 8), (4, 8),
                   (28, 6), (28, 7), (29, 7), (27, 8), (28, 8), (29, 8)]

    for pt in left_spike + center_spike + right_spike + side_spikes:
        hair_pixels.add(pt)

    # Forehead bangs with prominent central triangular dip
    bangs = [
        (4, 8), (5, 8), (6, 8), (7, 8), (8, 8), (9, 8), (10, 8), (11, 8), (12, 8), (13, 8),
        (14, 8), (15, 8), (16, 8), (17, 8), (18, 8), (19, 8), (20, 8), (21, 8), (22, 8), (23, 8),
        (24, 8), (25, 8), (26, 8), (27, 8),
        (4, 9), (5, 9), (6, 9), (8, 9), (9, 9), (12, 9), (13, 9), (14, 9), (19, 9), (20, 9), (25, 9), (26, 9), (27, 9),
        (4, 10), (5, 10), (12, 10), (13, 10), (26, 10), (27, 10),
        (4, 11), (5, 11), (26, 11), (27, 11),
        (4, 12), (27, 12),
    ]
    for pt in bangs:
        hair_pixels.add(pt)

    hair_outline_pts = set()
    for (x, y) in hair_pixels:
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in hair_pixels:
                hair_outline_pts.add((x, y))
                break

    for (x, y) in hair_pixels:
        if (x, y) in hair_outline_pts:
            pix[x, y] = HAIR_OUTLINE
        else:
            if y <= 2 and x in (8, 16, 17, 24):
                pix[x, y] = HAIR_LIGHT
            elif y in (3, 4, 5) and (8 <= x <= 12 or 16 <= x <= 22):
                pix[x, y] = HAIR_MID
            elif y >= 8:
                pix[x, y] = HAIR_BASE
            else:
                pix[x, y] = HAIR_BASE

    for y in range(8, 13):
        for x in range(5, 27):
            if (x, y) not in hair_pixels and pix[x, y][3] > 30 and pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_LIGHT if y <= 11 else SKIN_BASE

    # Green Lantern Domino Mask
    mask_pixels = set()
    for y in range(12, 19):
        for x in range(4, 28):
            p = pix[x, y]
            if p[3] > 30 and (x, y) not in hair_pixels:
                in_mask = False
                if 5 <= x <= 12 and 13 <= y <= 18: in_mask = True
                elif 19 <= x <= 26 and 13 <= y <= 18: in_mask = True
                elif (6 <= x <= 11 or 20 <= x <= 25) and y == 12: in_mask = True
                elif 13 <= x <= 18 and 14 <= y <= 15: in_mask = True
                elif (x in (4, 27) and y in (13, 14, 15)): in_mask = True
                if in_mask: mask_pixels.add((x, y))

    mask_outline_pts = set()
    for (x, y) in mask_pixels:
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in mask_pixels:
                mask_outline_pts.add((x, y))
                break

    for (x, y) in mask_pixels:
        if (x, y) in mask_outline_pts:
            pix[x, y] = MASK_OUTLINE
        else:
            if y == 13 and (7 <= x <= 10 or 21 <= x <= 24):
                pix[x, y] = MASK_LIGHT
            elif y in (13, 14):
                pix[x, y] = MASK_LIGHT if (y == 13 and 14 <= x <= 17) else MASK_BASE
            elif y >= 17:
                pix[x, y] = MASK_DEEP
            else:
                pix[x, y] = MASK_BASE

    # Glowing White Comic Eyes
    for y in range(14, 18):
        for x in range(7, 11):
            if (x, y) in mask_pixels: pix[x, y] = WHITE
    pix[7, 14] = EYE_RIM; pix[10, 14] = EYE_RIM
    pix[7, 17] = MASK_DEEP; pix[10, 17] = MASK_DEEP
    pix[8, 15] = EYE_GLOW; pix[9, 15] = EYE_GLOW

    for y in range(14, 18):
        for x in range(21, 25):
            if (x, y) in mask_pixels: pix[x, y] = WHITE
    pix[21, 14] = EYE_RIM; pix[24, 14] = EYE_RIM
    pix[21, 17] = MASK_DEEP; pix[24, 17] = MASK_DEEP
    pix[22, 15] = EYE_GLOW; pix[23, 15] = EYE_GLOW

    # Mouth & Chin
    if not is_shooting:
        pix[14, 20] = OUTLINE; pix[15, 20] = OUTLINE; pix[16, 20] = OUTLINE; pix[17, 20] = OUTLINE
        pix[13, 21] = OUTLINE
        pix[14, 21] = WHITE; pix[15, 21] = WHITE; pix[16, 21] = WHITE
        pix[17, 21] = (45, 18, 18, 255)
        pix[18, 21] = OUTLINE
        pix[14, 22] = OUTLINE; pix[15, 22] = OUTLINE; pix[16, 22] = OUTLINE; pix[17, 22] = OUTLINE
    else:
        for mx in range(13, 19):
            pix[mx, 19] = OUTLINE; pix[mx, 22] = OUTLINE
        pix[13, 20] = OUTLINE; pix[13, 21] = OUTLINE
        pix[18, 20] = OUTLINE; pix[18, 21] = OUTLINE
        for mx in range(14, 18):
            pix[mx, 20] = WHITE; pix[mx, 21] = (50, 16, 16, 255)

    return img

def render_hal_head_side(base_head, is_shooting=False):
    img = clean_base_head(base_head)
    pix = img.load()

    hair_pixels = set()
    for y in range(2, 19):
        for x in range(2, 27):
            p = pix[x, y]
            if p[3] > 30:
                is_hair = False
                if y <= 7: is_hair = True
                elif y in (8, 9) and x <= 24: is_hair = True
                elif y == 10 and (x <= 18 or (21 <= x <= 24)): is_hair = True
                elif y in (11, 12) and (x <= 15 or (22 <= x <= 23 and y == 11)): is_hair = True
                elif y in (13, 14) and x <= 13: is_hair = True
                elif y in (15, 16) and x <= 11: is_hair = True
                elif y in (17, 18) and x <= 9: is_hair = True
                if is_hair: hair_pixels.add((x, y))

    for pt in [(13, 0), (14, 0), (12, 1), (13, 1), (14, 1), (15, 1),
               (11, 2), (12, 2), (13, 2), (14, 2), (15, 2), (16, 2),
               (6, 1), (7, 1), (5, 2), (6, 2), (7, 2), (8, 2),
               (22, 8), (23, 8), (24, 8), (22, 9), (23, 9), (24, 9), (23, 10)]:
        hair_pixels.add(pt)

    hair_outline_pts = set()
    for (x, y) in hair_pixels:
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in hair_pixels:
                hair_outline_pts.add((x, y))
                break

    for (x, y) in hair_pixels:
        if (x, y) in hair_outline_pts:
            pix[x, y] = HAIR_OUTLINE
        else:
            if y <= 2 and x in (12, 13, 14):
                pix[x, y] = HAIR_LIGHT
            elif y in (3, 4, 5) and (8 <= x <= 18):
                pix[x, y] = HAIR_MID
            elif y >= 8:
                pix[x, y] = HAIR_BASE
            else:
                pix[x, y] = HAIR_BASE

    mask_pixels = set()
    for y in range(12, 19):
        for x in range(13, 24):
            p = pix[x, y]
            if p[3] > 30 and (x, y) not in hair_pixels:
                in_mask = False
                if y in (12, 18) and 14 <= x <= 21: in_mask = True
                elif 13 <= y <= 17 and 13 <= x <= 22: in_mask = True
                if in_mask: mask_pixels.add((x, y))

    mask_outline_pts = set()
    for (x, y) in mask_pixels:
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in mask_pixels:
                mask_outline_pts.add((x, y))
                break

    for (x, y) in mask_pixels:
        if (x, y) in mask_outline_pts:
            pix[x, y] = MASK_OUTLINE
        else:
            pix[x, y] = MASK_LIGHT if y == 13 else MASK_BASE

    for y in range(14, 18):
        for x in range(15, 20):
            if (x, y) in mask_pixels: pix[x, y] = WHITE
    pix[15, 14] = EYE_RIM; pix[19, 14] = EYE_RIM
    pix[15, 17] = MASK_DEEP; pix[19, 17] = MASK_DEEP
    pix[16, 15] = EYE_GLOW; pix[17, 15] = EYE_GLOW

    if not is_shooting:
        pix[25, 17] = OUTLINE; pix[26, 17] = OUTLINE
    else:
        pix[24, 17] = OUTLINE; pix[25, 17] = WHITE
        pix[26, 17] = (50, 16, 16, 255); pix[27, 17] = OUTLINE
        pix[25, 18] = OUTLINE; pix[26, 18] = OUTLINE

    return img

def render_hal_head_back(base_head, is_shooting=False):
    img = clean_base_head(base_head)
    pix = img.load()

    hair_pixels = set()
    for y in range(2, 22):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30:
                is_hair = False
                if y <= 18: is_hair = True
                elif y in (19, 20) and (x <= 10 or x >= 21): is_hair = True
                elif y == 21 and (x <= 7 or x >= 24): is_hair = True
                if is_hair: hair_pixels.add((x, y))

    for pt in [(7, 1), (8, 1), (7, 2), (8, 2), (9, 2),
               (15, 0), (16, 0), (14, 1), (15, 1), (16, 1), (17, 1),
               (13, 2), (14, 2), (15, 2), (16, 2), (17, 2), (18, 2),
               (24, 1), (25, 1), (23, 2), (24, 2), (25, 2), (26, 2)]:
        hair_pixels.add(pt)

    hair_outline_pts = set()
    for (x, y) in hair_pixels:
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in hair_pixels:
                hair_outline_pts.add((x, y))
                break

    for (x, y) in hair_pixels:
        if (x, y) in hair_outline_pts:
            pix[x, y] = HAIR_OUTLINE
        else:
            if y <= 2 and x in (8, 15, 16, 24):
                pix[x, y] = HAIR_LIGHT
            elif y in (4, 5, 6, 7, 8) and x in (9, 10, 15, 16, 21, 22):
                pix[x, y] = HAIR_LIGHT if y in (5, 6) else HAIR_MID
            elif y in (3, 4, 5, 6, 7, 8, 9):
                pix[x, y] = HAIR_MID
            else:
                pix[x, y] = HAIR_BASE

    for y in range(19, 26):
        for x in range(8, 24):
            if (x, y) not in hair_pixels and pix[x, y][3] > 30 and pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_SHADOW if y <= 21 else SKIN_BASE

    return img

# ==================== TAINTED HAL (PARALLAX) HEADS ====================

def render_tainted_head_front(base_head, is_shooting=False):
    img = render_hal_head_front(base_head, is_shooting)
    pix = img.load()

    # Silver temples on both sides
    for y in range(6, 13):
        for x in range(4, 9):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                if y in (7, 8): pix[x, y] = SILVER_LIGHT
                elif y in (9, 10): pix[x, y] = SILVER_BASE
                else: pix[x, y] = SILVER_DARK
        for x in range(23, 28):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                if y in (7, 8): pix[x, y] = SILVER_LIGHT
                elif y in (9, 10): pix[x, y] = SILVER_BASE
                else: pix[x, y] = SILVER_DARK

    for y in range(2, 8):
        for x in range(9, 23):
            if pix[x, y] in (HAIR_BASE, HAIR_MID): pix[x, y] = THAL_HAIR_BASE

    for y in range(12, 19):
        for x in range(4, 28):
            if pix[x, y] == MASK_BASE: pix[x, y] = SUIT_DARK_BASE
            elif pix[x, y] == MASK_LIGHT: pix[x, y] = SUIT_DARK_LIGHT
            elif pix[x, y] == MASK_DEEP: pix[x, y] = SUIT_DARK_OUTLINE

    # Piercing Cosmic Yellow Eyes
    for y in range(14, 18):
        for x in range(7, 11):
            if pix[x, y] in (WHITE, EYE_GLOW, EYE_RIM):
                pix[x, y] = PARALLAX_YELLOW_BASE
    pix[8, 15] = PARALLAX_YELLOW_GLOW; pix[9, 15] = PARALLAX_YELLOW_GLOW
    pix[7, 14] = PARALLAX_YELLOW_DEEP; pix[10, 14] = PARALLAX_YELLOW_DEEP

    for y in range(14, 18):
        for x in range(21, 25):
            if pix[x, y] in (WHITE, EYE_GLOW, EYE_RIM):
                pix[x, y] = PARALLAX_YELLOW_BASE
    pix[22, 15] = PARALLAX_YELLOW_GLOW; pix[23, 15] = PARALLAX_YELLOW_GLOW
    pix[21, 14] = PARALLAX_YELLOW_DEEP; pix[24, 14] = PARALLAX_YELLOW_DEEP

    return img

def render_tainted_head_side(base_head, is_shooting=False):
    img = render_hal_head_side(base_head, is_shooting)
    pix = img.load()

    for y in range(7, 14):
        for x in range(7, 14):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                if y in (8, 9): pix[x, y] = SILVER_LIGHT
                elif y in (10, 11): pix[x, y] = SILVER_BASE
                else: pix[x, y] = SILVER_DARK

    for y in range(14, 18):
        for x in range(15, 20):
            if pix[x, y] in (WHITE, EYE_GLOW, EYE_RIM):
                pix[x, y] = PARALLAX_YELLOW_BASE
    pix[16, 15] = PARALLAX_YELLOW_GLOW; pix[17, 15] = PARALLAX_YELLOW_GLOW
    return img

def render_tainted_head_back(base_head, is_shooting=False):
    img = render_hal_head_back(base_head, is_shooting)
    pix = img.load()

    for y in range(7, 14):
        for x in range(4, 8):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                pix[x, y] = SILVER_LIGHT if y in (8, 9) else SILVER_BASE
        for x in range(24, 28):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                pix[x, y] = SILVER_LIGHT if y in (8, 9) else SILVER_BASE
    return img

# ==================== BODY GENERATION ====================

def render_hal_body_front(base_body):
    """
    Hal Jordan Suit directly following User Sketch:
    - Shoulders (x<=10, x>=21, y<=16): Dark forest green sleeves
    - Outer torso flanks (x in (11, 12, 19, 20), y in (14..17)): Dark forest green
    - Gauntlets / Gloves (y >= 17 on outer arms): Vibrant light green
    - Central chest plate (x=13..18, y=13..18): Vibrant light emerald green with Emblem
    - Pants (y=20..21): Dark forest green
    - Boots (y=22..24): Vibrant light emerald green
    - Right fist: Glowing emerald Power Ring
    """
    img = base_body.copy().convert("RGBA")
    pix = img.load()

    for y in range(12, 25):
        for x in range(5, 27):
            p = pix[x, y]
            if p[3] > 30 and p != OUTLINE:
                if x <= 10 or x >= 21:
                    if y <= 16:
                        pix[x, y] = SUIT_DARK_BASE
                    else:
                        pix[x, y] = SUIT_LIGHT_BRIGHT if (y == 17 and x in (8, 23)) else SUIT_LIGHT_BASE

                elif 11 <= x <= 20 and 12 <= y <= 19:
                    if (x in (11, 12) or x in (19, 20)) and y in (14, 15, 16, 17):
                        pix[x, y] = SUIT_DARK_BASE
                    elif y == 19:
                        pix[x, y] = SUIT_DARK_LIGHT if 13 <= x <= 18 else SUIT_DARK_BASE
                    else:
                        if y == 15 and 14 <= x <= 17:
                            pix[x, y] = EMBLEM_LINE
                        elif y == 17 and 14 <= x <= 17:
                            pix[x, y] = EMBLEM_LINE
                        elif y == 16 and (x in (14, 17)):
                            pix[x, y] = EMBLEM_LINE
                        elif y == 16 and x in (15, 16):
                            pix[x, y] = EMBLEM_CORE
                        else:
                            pix[x, y] = SUIT_LIGHT_BRIGHT if y == 13 else SUIT_LIGHT_BASE

                elif 20 <= y <= 24:
                    if y in (20, 21):
                        pix[x, y] = SUIT_DARK_BASE
                    else:
                        pix[x, y] = SUIT_LIGHT_BRIGHT if y == 22 else SUIT_LIGHT_BASE

    if pix[24, 18][3] > 30: pix[24, 18] = RING_GEM
    if pix[23, 18][3] > 30 and pix[23, 18] != OUTLINE: pix[23, 18] = RING_AURA

    return img

def render_tainted_body_front(base_body, base_tainted_body):
    img = base_body.copy().convert("RGBA")
    pix = img.load()
    t_pix = base_tainted_body.load()

    # Cape preserved from base_tainted_body
    for y in range(32):
        for x in range(32):
            tp = t_pix[x, y]
            if tp[3] > 30 and (x <= 8 or x >= 23) and y >= 13:
                pix[x, y] = tp

    for y in range(12, 25):
        for x in range(7, 25):
            p = pix[x, y]
            if p[3] > 30 and p != OUTLINE:
                if 12 <= y <= 19:
                    if y in (12, 13, 14) and (7 <= x <= 11 or 20 <= x <= 24):
                        pix[x, y] = PARALLAX_ARMOR_LIGHT if y == 12 else PARALLAX_ARMOR_BASE
                    elif 12 <= x <= 19:
                        if y in (15, 16) and 14 <= x <= 17:
                            pix[x, y] = PARALLAX_CREST_GOLD
                        elif y % 2 == 0:
                            pix[x, y] = PARALLAX_ARMOR_BASE
                        else:
                            pix[x, y] = PARALLAX_CAPE_DARK
                    elif (x in (7, 8, 23, 24)) and y in (17, 18):
                        pix[x, y] = PARALLAX_ARMOR_LIGHT
                    else:
                        pix[x, y] = PARALLAX_ARMOR_BASE
                elif 20 <= y <= 24:
                    if y in (20, 21):
                        pix[x, y] = PARALLAX_ARMOR_BASE
                    else:
                        pix[x, y] = PARALLAX_CAPE_BASE

    if pix[7, 17][3] > 30: pix[7, 17] = THAL_RING_YELLOW
    if pix[8, 17][3] > 30 and pix[8, 17] != OUTLINE: pix[8, 17] = (255, 255, 180, 255)
    if pix[24, 18][3] > 30: pix[24, 18] = RING_GEM
    if pix[23, 18][3] > 30 and pix[23, 18] != OUTLINE: pix[23, 18] = RING_AURA

    return img

def assemble_full(head, body):
    canvas = Image.new("RGBA", (32, 38), (0, 0, 0, 0))
    canvas.paste(body, (0, 10), body)
    canvas.paste(head, (0, 0), head)
    return canvas

# ==================== MASTER GENERATOR & VERIFICATION ====================

def generate_all():
    print("=" * 60)
    print("GENERATING PROPOSED REDESIGNS AND VERIFICATION SUITE")
    print("=" * 60)

    vanilla_sheet = Image.open(VANILLA_PATH).convert("RGBA")
    current_hal = Image.open(CURRENT_HAL_PATH).convert("RGBA")
    current_tainted = Image.open(CURRENT_TAINTED_PATH).convert("RGBA")

    # Base cells
    v_hd = vanilla_sheet.crop((0, 0, 32, 32))
    v_hr = vanilla_sheet.crop((64, 0, 96, 32))
    v_hu = vanilla_sheet.crop((128, 0, 160, 32))
    v_bd = vanilla_sheet.crop((0, 32, 32, 64))

    c_hd = current_hal.crop((0, 0, 32, 32))
    c_hr = current_hal.crop((64, 0, 96, 32))
    c_hu = current_hal.crop((128, 0, 160, 32))
    c_bd = current_hal.crop((0, 32, 32, 64))

    ct_hd = current_tainted.crop((0, 0, 32, 32))
    ct_hr = current_tainted.crop((64, 0, 96, 32))
    ct_hu = current_tainted.crop((128, 0, 160, 32))
    ct_bd = current_tainted.crop((0, 32, 32, 64))

    # Proposed Redesigns
    new_hal_hd = render_hal_head_front(v_hd, is_shooting=False)
    new_hal_hr = render_hal_head_side(v_hr, is_shooting=False)
    new_hal_hu = render_hal_head_back(v_hu, is_shooting=False)
    new_hal_bd = render_hal_body_front(c_bd)

    new_thal_hd = render_tainted_head_front(v_hd, is_shooting=False)
    new_thal_hr = render_tainted_head_side(v_hr, is_shooting=False)
    new_thal_hu = render_tainted_head_back(v_hu, is_shooting=False)
    new_thal_bd = render_tainted_body_front(v_bd, ct_bd)

    # 1. Generate Full 512x512 Proposed Sprite Sheets
    # Based on current full animation sheet, replacing the canonical head & body cells
    prop_hal = current_hal.copy()
    prop_hal.paste(new_hal_hd, (0, 0), new_hal_hd)
    prop_hal.paste(render_hal_head_front(v_hd, is_shooting=True), (32, 0))
    prop_hal.paste(new_hal_hr, (64, 0), new_hal_hr)
    prop_hal.paste(render_hal_head_side(v_hr, is_shooting=True), (96, 0))
    prop_hal.paste(new_hal_hu, (128, 0), new_hal_hu)
    prop_hal.paste(render_hal_head_back(v_hu, is_shooting=True), (160, 0))
    prop_hal.paste(new_hal_bd, (0, 32), new_hal_bd)

    prop_thal = current_tainted.copy()
    prop_thal.paste(new_thal_hd, (0, 0), new_thal_hd)
    prop_thal.paste(render_tainted_head_front(v_hd, is_shooting=True), (32, 0))
    prop_thal.paste(new_thal_hr, (64, 0), new_thal_hr)
    prop_thal.paste(render_tainted_head_side(v_hr, is_shooting=True), (96, 0))
    prop_thal.paste(new_thal_hu, (128, 0), new_thal_hu)
    prop_thal.paste(render_tainted_head_back(v_hu, is_shooting=True), (160, 0))
    prop_thal.paste(new_thal_bd, (0, 32), new_thal_bd)

    # Save proposed sheets (strictly protecting active sheets per Rule 4!)
    prop_hal_path = os.path.join(PROJECT_DIR, r"resources\gfx\characters\proposed_hal_jordan.png")
    prop_thal_path = os.path.join(PROJECT_DIR, r"resources\gfx\characters\proposed_tainted_hal.png")
    prop_hal.save(prop_hal_path)
    prop_thal.save(prop_thal_path)
    print(f"  [SAVED] {prop_hal_path}")
    print(f"  [SAVED] {prop_thal_path}")

    # 2. Generate Side-by-Side Comparison Showcase (character_redesign_preview.png)
    v_full = assemble_full(v_hd, v_bd)
    c_full = assemble_full(c_hd, c_bd)
    ct_full = assemble_full(ct_hd, ct_bd)
    new_hal_full = assemble_full(new_hal_hd, new_hal_bd)
    new_thal_full = assemble_full(new_thal_hd, new_thal_bd)

    SCALE = 4
    COL_W = 150
    CANVAS_W = COL_W * 5
    CANVAS_H = 680
    showcase = Image.new("RGBA", (CANVAS_W, CANVAS_H), (18, 20, 24, 255))
    draw = ImageDraw.Draw(showcase)

    columns = [
        ("1. Vanilla Isaac", v_full, v_hd, v_hr, v_hu, (180, 180, 180)),
        ("2. Current Mod Hal", c_full, c_hd, c_hr, c_hu, (230, 90, 90)),
        ("3. Current Mod Tainted", ct_full, ct_hd, ct_hr, ct_hu, (230, 90, 90)),
        ("4. Proposed Hal Jordan", new_hal_full, new_hal_hd, new_hal_hr, new_hal_hu, (0, 230, 118)),
        ("5. Proposed Tainted Hal", new_thal_full, new_thal_hd, new_thal_hr, new_thal_hu, (255, 235, 59)),
    ]

    for idx, (title, full_c, head_d, head_r, head_u, color) in enumerate(columns):
        cx = idx * COL_W + 10
        draw.text((cx, 8), title, fill=color)

        draw.text((cx, 28), "Full Character (4x)", fill=(120, 120, 130))
        full_4x = full_c.resize((32 * SCALE, 38 * SCALE), Image.NEAREST)
        showcase.paste(full_4x, (cx, 44), full_4x)

        draw.text((cx, 208), "Front Head (4x)", fill=(120, 120, 130))
        hd_4x = head_d.resize((32 * SCALE, 32 * SCALE), Image.NEAREST)
        showcase.paste(hd_4x, (cx, 224), hd_4x)

        draw.text((cx, 360), "Profile Head (4x)", fill=(120, 120, 130))
        hr_4x = head_r.resize((32 * SCALE, 32 * SCALE), Image.NEAREST)
        showcase.paste(hr_4x, (cx, 376), hr_4x)

        draw.text((cx, 512), "Back Head (4x)", fill=(120, 120, 130))
        hu_4x = head_u.resize((32 * SCALE, 32 * SCALE), Image.NEAREST)
        showcase.paste(hu_4x, (cx, 528), hu_4x)

    showcase_path = os.path.join(PROJECT_DIR, "character_redesign_preview.png")
    showcase.save(showcase_path)
    os.makedirs(ARTIFACT_DIR, exist_ok=True)
    art_showcase = os.path.join(ARTIFACT_DIR, "character_redesign_preview.png")
    showcase.save(art_showcase)
    print(f"  [SAVED] {showcase_path}")
    print(f"  [SAVED] {art_showcase}")

    # 3. High-Res Zoom 8x Pixel Comparison (character_redesign_zoom8x.png)
    zoom_w = 32 * 8 * 5 + 40
    zoom_h = 38 * 8 + 40
    zoom_sheet = Image.new("RGBA", (zoom_w, zoom_h), (18, 20, 24, 255))
    zoom_draw = ImageDraw.Draw(zoom_sheet)
    for idx, (title, full_c, _, _, _, color) in enumerate(columns):
        zx = 10 + idx * (32 * 8 + 8)
        zoom_draw.text((zx, 6), title, fill=color)
        full_8x = full_c.resize((32 * 8, 38 * 8), Image.NEAREST)
        zoom_sheet.paste(full_8x, (zx, 24), full_8x)

    zoom_path = os.path.join(ARTIFACT_DIR, "character_redesign_zoom8x.png")
    zoom_sheet.save(zoom_path)
    print(f"  [SAVED] {zoom_path}")

    # 4. Item Costume Merge Verification
    from tools.verify_costume_merging import run_verification
    run_verification()

    print("-" * 60)
    print("ALL REDESIGN ASSETS AND VERIFICATIONS READY FOR USER REVIEW")
    print("-" * 60)

if __name__ == "__main__":
    generate_all()
