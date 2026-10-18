"""
tools/build_perfect_ui_sprites.py
Builds handmade, authentic Isaac pixel art for:
1. Character Menu Portraits (Hal Jordan & Tainted Hal) in 48x52 crop of 160x160 sheets.
2. Stage Nightmare Transitions (Hal Jordan & Tainted Hal) in 144x144 canvas.
3. Synchronizes Boss UI portraits.
"""

import os
from PIL import Image

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\d0abad69-7124-472e-9088-fe0a1a3473a9"

from refine_menu_portraits import clean_and_refine_hal_menu, clean_and_refine_tainted_menu

# Palettes
OUTLINE = (28, 22, 21, 255)
SKIN_BASE = (232, 186, 158, 255)
SKIN_SHADOW = (201, 148, 120, 255)
SKIN_HIGHLIGHT = (244, 212, 192, 255)

# Hal Pilot Hair
HAIR_DARK = (44, 26, 17, 255)
HAIR_BASE = (93, 58, 36, 255)
HAIR_MID = (118, 77, 49, 255)
HAIR_LIGHT = (145, 98, 64, 255)
HAIR_HIGHLIGHT = (167, 116, 77, 255)

# Parallax Silver Hair
SILVER_DARK = (120, 144, 156, 255)
SILVER_BASE = (176, 190, 197, 255)
SILVER_LIGHT = (236, 239, 241, 255)

# Emerald
EMERALD_OUTLINE = (0, 77, 32, 255)
EMERALD_DARK = (0, 122, 51, 255)
EMERALD_BASE = (0, 200, 83, 255)
EMERALD_LIGHT = (0, 230, 118, 255)
EMERALD_GLOW = (105, 240, 174, 255)

# Parallax
PARALLAX_YELLOW = (238, 255, 65, 255)
PARALLAX_YELLOW_GLOW = (255, 255, 170, 255)
PARALLAX_ARMOR_DARK = (0, 60, 25, 255)
PARALLAX_ARMOR_BASE = (0, 145, 58, 255)
PARALLAX_ARMOR_LIGHT = (0, 215, 85, 255)

# Suit
WHITE = (255, 255, 255, 255)
WHITE_GLOW = (235, 255, 242, 255)
GREY_GLOVE = (196, 196, 196, 255)
BLACK_SUIT = (24, 24, 24, 255)
BLACK_SUIT_LIGHT = (48, 48, 52, 255)

# Tears & Shadows
SHADOW_FLOOR = (0, 0, 0, 127)
TEAR_LIGHT = (154, 204, 205, 255)
TEAR_BASE = (104, 152, 156, 255)
TEAR_DARK = (52, 76, 78, 255)
TEAR_DEEP = (41, 56, 58, 255)

PTEAR_LIGHT = (255, 245, 157, 255)
PTEAR_BASE = (255, 238, 88, 255)
PTEAR_DARK = (245, 127, 23, 255)
PTEAR_DEEP = (100, 80, 20, 255)

def build_hal_menu_portrait():
    return clean_and_refine_hal_menu()

def build_tainted_menu_portrait():
    return clean_and_refine_tainted_menu()

def build_perfect_hal_stage():
    """Builds authentic, clean pixel-art Hal Jordan curled nightmare transition."""
    master_path = os.path.join(ARTIFACT_DIR, "curr_hal_stage.png")
    im = Image.open(master_path).convert("RGBA")
    pix = im.load()

    w, h = im.size
    for y in range(h):
        for x in range(w):
            p = pix[x, y]
            if p[3] == 0:
                pix[x, y] = (0, 0, 0, 0)
                continue

            r, g, b, a = p
            # Pure black outline
            if r < 35 and g < 35 and b < 35:
                pix[x, y] = (0, 0, 0, a) if a < 255 else OUTLINE
            # Green boots / suit / mask
            elif g > r + 30 and g > b + 30:
                if y >= 115 or (x <= 35 and y >= 105):
                    pix[x, y] = EMERALD_DARK if g < 150 else EMERALD_BASE
                elif y <= 85 and 70 <= x <= 95: # mask
                    pix[x, y] = EMERALD_LIGHT if g >= 180 else EMERALD_BASE
                else:
                    pix[x, y] = EMERALD_BASE
            # Brown Hair
            elif r > 70 and g > 35 and b < 60:
                if r >= 150: pix[x, y] = HAIR_LIGHT
                elif r >= 110: pix[x, y] = HAIR_MID
                elif r >= 80: pix[x, y] = HAIR_BASE
                else: pix[x, y] = HAIR_DARK
            # White eyes & white gloves & chest emblem
            elif r > 180 and g > 180 and b > 180:
                pix[x, y] = WHITE if (r + g + b) // 3 >= 240 else WHITE_GLOW
            # Tears
            elif b > r + 20 and b > 80:
                bright = (r + g + b) // 3
                if bright >= 180: pix[x, y] = TEAR_LIGHT
                elif bright >= 130: pix[x, y] = TEAR_BASE
                elif bright >= 80: pix[x, y] = TEAR_DARK
                else: pix[x, y] = TEAR_DEEP
            # Skin
            elif r > 150 and g > 100:
                pix[x, y] = SKIN_BASE if r >= 200 else SKIN_SHADOW
            # Dark suit
            elif r < 60 and g < 60 and b < 60:
                pix[x, y] = BLACK_SUIT_LIGHT if (r + g + b) // 3 >= 40 else BLACK_SUIT
            # Soft shadow
            elif a < 200:
                pix[x, y] = (0, 0, 0, 127)

    # GL ring glow on fist at X: 58..62, Y: 92..96
    for y in range(92, 97):
        for x in range(58, 63):
            if pix[x, y][3] > 0 and pix[x, y][:3] != (0, 0, 0):
                pix[x, y] = EMERALD_GLOW if (x, y) in [(60, 94), (61, 94)] else EMERALD_LIGHT

    # Ensure zero dirty alpha
    for y in range(h):
        for x in range(w):
            if pix[x, y][3] == 0:
                pix[x, y] = (0, 0, 0, 0)

    return im

def build_perfect_tainted_stage():
    """Builds authentic, clean pixel-art Tainted Hal (Parallax) curled nightmare."""
    im = build_perfect_hal_stage()
    pix = im.load()

    w, h = im.size
    # 1. PARALLAX SILVER/WHITE TEMPLE STREAKS (X: 88..108, Y: 72..86)
    for y in range(72, 87):
        for x in range(88, 109):
            p = pix[x, y]
            if p in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                if y in (74, 75, 76) and 90 <= x <= 104:
                    pix[x, y] = SILVER_LIGHT
                elif y in (73, 77, 78) and 89 <= x <= 106:
                    pix[x, y] = SILVER_BASE
                else:
                    pix[x, y] = SILVER_DARK

    # 2. YELLOW FEAR TEARS (X: 68..85, Y: 82..125)
    for y in range(82, 126):
        for x in range(68, 86):
            p = pix[x, y]
            if p in (TEAR_LIGHT, TEAR_BASE, TEAR_DARK, WHITE, WHITE_GLOW) and y >= 88:
                if (x + y) % 2 == 0 and y <= 98:
                    pix[x, y] = PTEAR_LIGHT
                elif y <= 110:
                    pix[x, y] = PTEAR_BASE
                else:
                    pix[x, y] = PTEAR_DARK

    # 3. CORRUPTED YELLOW / EMERALD GLOWING EYES
    for y in range(80, 94):
        for x in range(70, 84):
            p = pix[x, y]
            if p in (WHITE, WHITE_GLOW):
                pix[x, y] = PARALLAX_YELLOW_GLOW if (x + y) % 2 == 0 else PARALLAX_YELLOW

    # 4. DARK CAPE & CORRUPTED ARMOR
    for y in range(74, 95):
        for x in range(35, 66):
            p = pix[x, y]
            if p in (EMERALD_BASE, EMERALD_LIGHT):
                pix[x, y] = PARALLAX_ARMOR_BASE
            elif p == EMERALD_DARK:
                pix[x, y] = PARALLAX_ARMOR_DARK

    # 5. FEAR-TINGED CORRUPTED PUDDLE
    for y in range(118, 142):
        for x in range(40, 95):
            p = pix[x, y]
            if p == TEAR_LIGHT:
                pix[x, y] = (175, 205, 120, 255)
            elif p == TEAR_BASE:
                pix[x, y] = (130, 160, 90, 255)
            elif p == TEAR_DARK:
                pix[x, y] = (75, 105, 60, 255)

    # Ensure zero dirty alpha
    for y in range(h):
        for x in range(w):
            if pix[x, y][3] == 0:
                pix[x, y] = (0, 0, 0, 0)

    return im
