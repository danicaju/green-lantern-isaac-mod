"""
tools/build_perfect_ui_sprites.py
Builds handmade, authentic Isaac pixel art for:
1. Character Menu Portraits (Hal Jordan & Tainted Hal) in 48x52 crop of 160x160 sheets.
2. Stage Nightmare Transitions (Hal Jordan & Tainted Hal) in 144x144 canvas.
3. Boss UI Portraits (Hal Jordan & Tainted Hal) in 112x80 canvas (framed for versusscreen.anm2).
"""

import os
from PIL import Image

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(TOOLS_DIR)
ASSETS_DIR = os.path.join(TOOLS_DIR, "assets")

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
SHADOW_GREY = (55, 55, 60, 255)
TEAR_LIGHT = (163, 207, 240, 255)
TEAR_BASE = (104, 152, 180, 255)
TEAR_DARK = (56, 116, 140, 255)
TEAR_DEEP = (26, 48, 56, 255)

PTEAR_LIGHT = (255, 245, 157, 255)
PTEAR_BASE = (255, 238, 88, 255)
PTEAR_DARK = (245, 127, 23, 255)
PTEAR_DEEP = (100, 80, 20, 255)

def sanitize_zero_dirty_alpha(im: Image.Image) -> Image.Image:
    rgba = im.convert("RGBA")
    pix = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            if pix[x, y][3] == 0:
                pix[x, y] = (0, 0, 0, 0)
    return rgba

def build_hal_menu_portrait() -> Image.Image:
    """Builds the 48x52 character menu portrait crop for Hal Jordan."""
    crop_path = os.path.join(ASSETS_DIR, "base_hal_menu_crop.png")
    im = Image.open(crop_path).convert("RGBA")
    pix = im.load()
    w, h = im.size

    for y in range(h):
        for x in range(w):
            p = pix[x, y]
            if p[3] < 50 or y >= 42:
                pix[x, y] = (0, 0, 0, 0)
                continue

            r, g, b, a = p
            # Black outline
            if r < 40 and g < 40 and b < 40:
                pix[x, y] = OUTLINE
            # Green mask and suit
            elif g > r + 30 and g > b + 30:
                if y <= 25: # mask
                    is_edge = False
                    for ox, oy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        if 0 <= x+ox < w and 0 <= y+oy < h:
                            if pix[x+ox, y+oy][:3] in [SKIN_BASE[:3], SKIN_SHADOW[:3], (0, 0, 0)]:
                                is_edge = True
                                break
                    if is_edge:
                        pix[x, y] = EMERALD_OUTLINE
                    elif y in (19, 20) and (13 <= x <= 18 or 30 <= x <= 35):
                        pix[x, y] = EMERALD_LIGHT
                    else:
                        pix[x, y] = EMERALD_BASE
                else: # suit / boots
                    if y in (32, 33) and 21 <= x <= 27:
                        if 23 <= x <= 25 and y == 33:
                            pix[x, y] = EMERALD_DARK
                        else:
                            pix[x, y] = WHITE
                    elif y >= 39:
                        pix[x, y] = EMERALD_DARK
                    else:
                        pix[x, y] = EMERALD_BASE
            # White eyes & white gloves
            elif r > 180 and g > 180 and b > 180:
                if y <= 25: # Eyes
                    pix[x, y] = WHITE if (r+g+b)//3 >= 240 else WHITE_GLOW
                else: # Gloves
                    pix[x, y] = WHITE
            # Hair
            elif r > 60 and g > 35 and b < 55:
                if r >= 140: pix[x, y] = HAIR_LIGHT if y >= 11 else HAIR_HIGHLIGHT
                elif r >= 105: pix[x, y] = HAIR_MID
                elif r >= 75: pix[x, y] = HAIR_BASE
                else: pix[x, y] = HAIR_DARK
            # Skin
            elif r > 150 and g > 100 and b > 80:
                if y >= 28 or x <= 13 or x >= 35:
                    pix[x, y] = SKIN_SHADOW
                elif y <= 17:
                    pix[x, y] = SKIN_HIGHLIGHT
                else:
                    pix[x, y] = SKIN_BASE
            # Suit sides
            elif r < 60 and g < 60 and b < 60:
                pix[x, y] = BLACK_SUIT
            else:
                if y <= 16:
                    pix[x, y] = HAIR_BASE if r > 50 else HAIR_DARK
                elif y <= 25:
                    pix[x, y] = EMERALD_BASE if g > 80 else EMERALD_OUTLINE
                else:
                    pix[x, y] = OUTLINE

    # Eye accents (comic white slit eyes with emerald edge glow)
    for y in range(21, 24):
        for x in range(15, 19):
            pix[x, y] = WHITE
    pix[15, 21] = EMERALD_GLOW; pix[18, 21] = EMERALD_GLOW

    for y in range(21, 24):
        for x in range(29, 33):
            pix[x, y] = WHITE
    pix[29, 21] = EMERALD_GLOW; pix[32, 21] = EMERALD_GLOW

    # Balance bottom boot soles at Y=41:
    # Right foot: X=25 OUTLINE, X=26..28 EMERALD_DARK, X=29 OUTLINE
    # Left foot:  X=19 OUTLINE, X=20..22 EMERALD_DARK, X=23 OUTLINE
    for x in (19, 23):
        pix[x, 41] = OUTLINE
    for x in (20, 21, 22):
        pix[x, 41] = EMERALD_DARK

    return sanitize_zero_dirty_alpha(im)

def build_tainted_menu_portrait() -> Image.Image:
    """Builds the 48x52 character menu portrait crop for Tainted Hal (Parallax)."""
    im = build_hal_menu_portrait()
    pix = im.load()
    w, h = im.size

    # 1. PARALLAX SILVER/WHITE TEMPLE STREAKS
    for y in range(12, 21):
        for x in range(10, 16): # Left temple
            p = pix[x, y]
            if p in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK, HAIR_HIGHLIGHT):
                if y in (14, 15, 16) and 11 <= x <= 14:
                    pix[x, y] = SILVER_LIGHT
                elif y in (13, 17, 18) and 10 <= x <= 15:
                    pix[x, y] = SILVER_BASE
                else:
                    pix[x, y] = SILVER_DARK
        for x in range(33, 39): # Right temple
            p = pix[x, y]
            if p in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK, HAIR_HIGHLIGHT):
                if y in (14, 15, 16) and 34 <= x <= 37:
                    pix[x, y] = SILVER_LIGHT
                elif y in (13, 17, 18) and 33 <= x <= 38:
                    pix[x, y] = SILVER_BASE
                else:
                    pix[x, y] = SILVER_DARK

    # 2. GLOWING COSMIC YELLOW PARALLAX EYES
    for y in range(21, 24):
        for x in range(15, 19):
            pix[x, y] = PARALLAX_YELLOW_GLOW if (x, y) in [(16, 22), (17, 22)] else PARALLAX_YELLOW
        for x in range(29, 33):
            pix[x, y] = PARALLAX_YELLOW_GLOW if (x, y) in [(30, 22), (31, 22)] else PARALLAX_YELLOW

    # 3. CORRUPT DOMINO MASK
    for y in range(18, 26):
        for x in range(10, 39):
            if pix[x, y] == EMERALD_BASE:
                pix[x, y] = PARALLAX_ARMOR_BASE
            elif pix[x, y] == EMERALD_LIGHT:
                pix[x, y] = PARALLAX_ARMOR_LIGHT

    # 4. CORRUPTED ARMOR & DARK CAPE
    for y in range(32, 42):
        for x in range(11, 38):
            p = pix[x, y]
            if p in (EMERALD_BASE, EMERALD_LIGHT):
                pix[x, y] = PARALLAX_ARMOR_BASE
            elif p == EMERALD_DARK:
                pix[x, y] = PARALLAX_ARMOR_DARK
            elif p == WHITE and y in (32, 33):
                pix[x, y] = PARALLAX_YELLOW

    # Balance sole color at Y=41
    for x in range(19, 30):
        if pix[x, 41] == EMERALD_DARK:
            pix[x, 41] = PARALLAX_ARMOR_DARK

    return sanitize_zero_dirty_alpha(im)

def build_perfect_hal_stage() -> Image.Image:
    """Builds authentic pixel-art Hal Jordan curled nightmare stage transition (144x144)."""
    stage_path = os.path.join(ASSETS_DIR, "curr_hal_stage.png")
    im = Image.open(stage_path).convert("RGBA")
    pix = im.load()
    w, h = im.size

    for y in range(h):
        for x in range(w):
            p = pix[x, y]
            if p[3] < 100:
                pix[x, y] = (0, 0, 0, 0)
                continue
            r, g, b, a = p
            # Black outline
            if r < 35 and g < 35 and b < 35:
                pix[x, y] = OUTLINE
            # Blue tears & puddle
            elif b > r + 15 and b > 70:
                bright = (r + g + b) // 3
                if bright >= 180: pix[x, y] = TEAR_LIGHT
                elif bright >= 130: pix[x, y] = TEAR_BASE
                elif bright >= 80: pix[x, y] = TEAR_DARK
                else: pix[x, y] = TEAR_DEEP
            # Green boots, suit, mask
            elif g > r + 25 and g > b + 25:
                if y >= 115 or (x <= 35 and y >= 105):
                    pix[x, y] = EMERALD_DARK if g < 150 else EMERALD_BASE
                elif y <= 85 and 70 <= x <= 95:
                    pix[x, y] = EMERALD_LIGHT if g >= 180 else EMERALD_BASE
                else:
                    pix[x, y] = EMERALD_BASE
            # White eye, glove, emblem
            elif r > 180 and g > 180 and b > 180:
                pix[x, y] = WHITE if (r+g+b)//3 >= 240 else WHITE_GLOW
            # Brown hair
            elif r > 70 and g > 35 and b < 60:
                if r >= 150: pix[x, y] = HAIR_LIGHT
                elif r >= 110: pix[x, y] = HAIR_MID
                elif r >= 80: pix[x, y] = HAIR_BASE
                else: pix[x, y] = HAIR_DARK
            # Skin
            elif r > 150 and g > 100:
                pix[x, y] = SKIN_BASE if r >= 200 else SKIN_SHADOW
            # Dark suit
            elif r < 60 and g < 60 and b < 60:
                pix[x, y] = BLACK_SUIT_LIGHT if (r+g+b)//3 >= 40 else BLACK_SUIT
            # Shadow
            elif abs(r-g) < 15 and abs(g-b) < 15 and 40 <= r <= 100:
                pix[x, y] = SHADOW_GREY
            else:
                if y >= 120 and x >= 40:
                    pix[x, y] = TEAR_DARK if b > r else SHADOW_GREY
                elif y <= 85:
                    pix[x, y] = HAIR_BASE if r > g else EMERALD_BASE
                else:
                    pix[x, y] = OUTLINE

    # GL power ring on fist at X: 58..62, Y: 92..96
    for y in range(92, 97):
        for x in range(58, 63):
            if pix[x, y][3] > 0 and pix[x, y] != OUTLINE:
                pix[x, y] = EMERALD_GLOW if (x, y) in [(60, 94), (61, 94)] else EMERALD_LIGHT

    return sanitize_zero_dirty_alpha(im)

def build_perfect_tainted_stage() -> Image.Image:
    """Builds authentic pixel-art Tainted Hal (Parallax) curled nightmare stage transition (144x144)."""
    im = build_perfect_hal_stage()
    pix = im.load()
    w, h = im.size

    # 1. Parallax silver streaks at temples (X: 88..108, Y: 72..86)
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

    # 2. Glowing fear yellow tears (X: 68..85, Y: 82..125)
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

    # 3. Glowing fear yellow eyes (X: 70..84, Y: 80..94)
    for y in range(80, 94):
        for x in range(70, 84):
            p = pix[x, y]
            if p in (WHITE, WHITE_GLOW):
                pix[x, y] = PARALLAX_YELLOW_GLOW if (x + y) % 2 == 0 else PARALLAX_YELLOW

    # 4. Dark cape & corrupt armor (X: 35..66, Y: 74..95)
    for y in range(74, 95):
        for x in range(35, 66):
            p = pix[x, y]
            if p in (EMERALD_BASE, EMERALD_LIGHT):
                pix[x, y] = PARALLAX_ARMOR_BASE
            elif p == EMERALD_DARK:
                pix[x, y] = PARALLAX_ARMOR_DARK

    # 5. Fear-tinged corrupted yellow/green puddle (X: 40..95, Y: 118..142)
    for y in range(118, 142):
        for x in range(40, 95):
            p = pix[x, y]
            if p == TEAR_LIGHT:
                pix[x, y] = (205, 215, 120, 255)
            elif p == TEAR_BASE:
                pix[x, y] = (160, 175, 80, 255)
            elif p == TEAR_DARK:
                pix[x, y] = (105, 120, 50, 255)

    # 6. Yellow fear energy on fist (X: 58..62, Y: 92..96)
    for y in range(92, 97):
        for x in range(58, 63):
            if pix[x, y] in (EMERALD_GLOW, EMERALD_LIGHT):
                pix[x, y] = PARALLAX_YELLOW_GLOW if (x, y) in [(60, 94), (61, 94)] else PARALLAX_YELLOW

    return sanitize_zero_dirty_alpha(im)

def build_perfect_hal_boss() -> Image.Image:
    """Builds authentic pixel-art Hal Jordan Boss VS screen portrait (112x80)."""
    raw_path = os.path.join(ASSETS_DIR, "base_boss_hal.png")
    raw = Image.open(raw_path).convert("RGBA")

    # Pad to canonical 112x80
    im = Image.new("RGBA", (112, 80), (0, 0, 0, 0))
    im.paste(raw, (0, 1), raw)
    pix = im.load()
    w, h = im.size

    for y in range(h):
        for x in range(w):
            p = pix[x, y]
            if p[3] < 100:
                pix[x, y] = (0, 0, 0, 0)
                continue
            r, g, b, a = p
            # Black outline
            if r < 40 and g < 40 and b < 40:
                pix[x, y] = OUTLINE
            # Green boots, suit, mask
            elif g > r + 25 and g > b + 25:
                if y >= 65: # boots
                    pix[x, y] = EMERALD_DARK if g < 150 else EMERALD_BASE
                elif y <= 45: # mask
                    pix[x, y] = EMERALD_LIGHT if g >= 180 else (EMERALD_DARK if g < 120 else EMERALD_BASE)
                else: # suit
                    pix[x, y] = EMERALD_BASE if g >= 140 else EMERALD_DARK
            # White eyes, gloves, chest emblem
            elif r > 180 and g > 180 and b > 180:
                if y <= 45: # eyes
                    pix[x, y] = WHITE if (r+g+b)//3 >= 240 else WHITE_GLOW
                else:
                    pix[x, y] = WHITE if (r+g+b)//3 >= 220 else GREY_GLOVE
            # Hair
            elif r > 60 and g > 35 and b < 60:
                if r >= 140: pix[x, y] = HAIR_LIGHT if y >= 25 else HAIR_HIGHLIGHT
                elif r >= 105: pix[x, y] = HAIR_MID
                elif r >= 75: pix[x, y] = HAIR_BASE
                else: pix[x, y] = HAIR_DARK
            # Skin
            elif r > 140 and g > 90 and b > 70:
                if y >= 50 or x <= 40 or x >= 70:
                    pix[x, y] = SKIN_SHADOW
                elif y <= 35:
                    pix[x, y] = SKIN_HIGHLIGHT
                else:
                    pix[x, y] = SKIN_BASE
            # Dark suit sides
            elif r < 60 and g < 60 and b < 60:
                pix[x, y] = BLACK_SUIT_LIGHT if (r+g+b)//3 >= 40 else BLACK_SUIT
            else:
                if y <= 35:
                    pix[x, y] = HAIR_BASE if r > 60 else OUTLINE
                elif y <= 48:
                    pix[x, y] = EMERALD_BASE if g > r else SKIN_SHADOW
                else:
                    pix[x, y] = OUTLINE

    # Clean ring glow on fist at X: 78..84, Y: 40..46
    for y in range(40, 46):
        for x in range(78, 85):
            if pix[x, y][3] > 0 and pix[x, y] != OUTLINE:
                if (x, y) in [(80, 42), (81, 42), (81, 43)]:
                    pix[x, y] = EMERALD_GLOW
                elif (x + y) % 2 == 0:
                    pix[x, y] = EMERALD_LIGHT

    return sanitize_zero_dirty_alpha(im)

def build_perfect_tainted_boss() -> Image.Image:
    """Builds authentic pixel-art Tainted Hal (Parallax) Boss VS screen portrait (112x80)."""
    im = build_perfect_hal_boss()
    pix = im.load()
    w, h = im.size

    # 1. Silver/white temple streaks
    # Left temple: X: 34..46, Y: 20..35
    for y in range(20, 36):
        for x in range(34, 47):
            p = pix[x, y]
            if p in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                if y in (23, 24, 25) and 36 <= x <= 44:
                    pix[x, y] = SILVER_LIGHT
                elif y in (22, 26, 27) and 35 <= x <= 45:
                    pix[x, y] = SILVER_BASE
                else:
                    pix[x, y] = SILVER_DARK

    # Right temple: X: 63..74, Y: 20..35
    for y in range(20, 36):
        for x in range(63, 75):
            p = pix[x, y]
            if p in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                if y in (23, 24, 25) and 64 <= x <= 72:
                    pix[x, y] = SILVER_LIGHT
                elif y in (22, 26, 27) and 63 <= x <= 73:
                    pix[x, y] = SILVER_BASE
                else:
                    pix[x, y] = SILVER_DARK

    # 2. Glowing cosmic yellow Parallax eyes
    for y in range(37, 43):
        for x in range(46, 56):
            if pix[x, y] in (WHITE, WHITE_GLOW):
                pix[x, y] = PARALLAX_YELLOW_GLOW if (x + y) % 2 == 0 else PARALLAX_YELLOW
        for x in range(64, 71):
            if pix[x, y] in (WHITE, WHITE_GLOW):
                pix[x, y] = PARALLAX_YELLOW_GLOW if (x + y) % 2 == 0 else PARALLAX_YELLOW

    # 3. Corrupt armor & mask
    for y in range(h):
        for x in range(w):
            p = pix[x, y]
            if p == EMERALD_BASE:
                pix[x, y] = PARALLAX_ARMOR_BASE
            elif p == EMERALD_DARK:
                pix[x, y] = PARALLAX_ARMOR_DARK
            elif p == EMERALD_LIGHT:
                pix[x, y] = PARALLAX_ARMOR_LIGHT
            elif p == EMERALD_GLOW:
                pix[x, y] = PARALLAX_YELLOW_GLOW

    # 4. Corrupt yellow chest emblem
    for y in range(56, 63):
        for x in range(54, 64):
            if pix[x, y] == WHITE:
                pix[x, y] = PARALLAX_YELLOW

    # 5. Yellow fist fear energy glow
    for y in range(40, 46):
        for x in range(78, 85):
            if pix[x, y] == PARALLAX_ARMOR_LIGHT:
                pix[x, y] = PARALLAX_YELLOW

    return sanitize_zero_dirty_alpha(im)

# Backwards compatibility aliases
clean_and_refine_hal_menu = build_hal_menu_portrait
clean_and_refine_tainted_menu = build_tainted_menu_portrait
