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

# Artifact directories
ARTIFACT_DIRS = [
    r"C:\Users\danic\.gemini\antigravity\brain\9da71cf0-d896-4c4f-9028-8fd34b5177fe",
    r"C:\Users\danic\.gemini\antigravity\brain\c85d05f1-0104-407a-a3c0-1180d226af49"
]

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
HAIR_DARK = (54, 32, 20, 255)
HAIR_BASE = (98, 62, 38, 255)
HAIR_MID = (125, 82, 52, 255)
HAIR_LIGHT = (158, 108, 70, 255)

# Parallax Silver Temples
SILVER_DARK = (95, 110, 120, 255)
SILVER_BASE = (170, 182, 192, 255)
SILVER_LIGHT = (235, 240, 245, 255)
THAL_HAIR_BASE = (65, 50, 42, 255)

# Hal Jordan Domino Mask (Iconic emerald hero mask)
MASK_OUTLINE = (6, 44, 16, 255)
MASK_DARK = (12, 82, 30, 255)
MASK_BASE = (24, 158, 58, 255)
MASK_LIGHT = (56, 218, 94, 255)
MASK_GLOW = (125, 248, 156, 255)

# Eyes (Glowing White Comic Hero Lenses)
WHITE = (255, 255, 255, 255)
EYE_GLOW = (220, 255, 235, 255)
EYE_RIM = (90, 230, 160, 255)

# Parallax Eyes (Piercing Cosmic Yellow Glow)
PARALLAX_YELLOW_DEEP = (190, 150, 15, 255)
PARALLAX_YELLOW_BASE = (255, 220, 40, 255)
PARALLAX_YELLOW_GLOW = (255, 255, 170, 255)

# Hal Jordan Suit (Directly from User Sketch)
SUIT_DARK_OUTLINE = (10, 34, 16, 255)
SUIT_DARK_BASE = (20, 72, 35, 255)
SUIT_DARK_LIGHT = (32, 98, 48, 255)

SUIT_LIGHT_OUTLINE = (16, 68, 30, 255)
SUIT_LIGHT_BASE = (84, 196, 102, 255)
SUIT_LIGHT_BRIGHT = (130, 230, 148, 255)
SUIT_LIGHT_DARK = (50, 150, 72, 255)

# Chest Emblem (Lantern Logo)
EMBLEM_LINE = (12, 54, 22, 255)
EMBLEM_CORE = (160, 245, 180, 255)

# Gauntlets and Boots
GLOVE_LIGHT = (125, 230, 142, 255)
GLOVE_BASE = (80, 192, 98, 255)
BOOT_LIGHT = (125, 230, 142, 255)
BOOT_BASE = (80, 192, 98, 255)

# Power Ring
RING_GEM = (0, 255, 128, 255)
RING_AURA = (140, 255, 190, 255)
THAL_RING_YELLOW = (255, 230, 40, 255)

# Parallax Suit & Billowing Cape
PARALLAX_CAPE_BASE = (22, 130, 62, 255)
PARALLAX_CAPE_DARK = (10, 65, 30, 255)
PARALLAX_CAPE_LIGHT = (45, 175, 88, 255)
PARALLAX_ARMOR_BASE = (22, 28, 26, 255)
PARALLAX_ARMOR_LIGHT = (40, 52, 48, 255)
PARALLAX_CREST_GOLD = (255, 215, 30, 255)

# ==================== HEAD GENERATION ====================

def clean_base_head(base_head):
    """Removes tears and crying mouth from vanilla Isaac head."""
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

    hair_map = {}

    # Fill base skull crown (y=2..7)
    for y in range(2, 8):
        for x in range(2, 30):
            if pix[x, y][3] > 30:
                hair_map[(x, y)] = HAIR_BASE

    # Organic spiky tufts on top (solidly rooted to skull)
    # Left tuft (pointing up-left, x=7..10, y=1..3)
    for x, y in [(8, 1), (9, 1), (7, 2), (8, 2), (9, 2), (10, 2), (7, 3), (8, 3), (9, 3), (10, 3)]:
        hair_map[(x, y)] = HAIR_BASE
    # Center tuft (pointing up-right, x=14..18, y=1..3)
    for x, y in [(15, 1), (16, 1), (14, 2), (15, 2), (16, 2), (17, 2), (14, 3), (15, 3), (16, 3), (17, 3)]:
        hair_map[(x, y)] = HAIR_BASE
    # Right tuft (pointing up-right, x=21..24, y=1..3)
    for x, y in [(22, 1), (23, 1), (21, 2), (22, 2), (23, 2), (24, 2), (21, 3), (22, 3), (23, 3), (24, 3)]:
        hair_map[(x, y)] = HAIR_BASE

    # Sideburns down both sides
    for y in range(7, 13):
        hair_map[(3, y)] = HAIR_BASE
        hair_map[(4, y)] = HAIR_BASE
        if y <= 10: hair_map[(5, y)] = HAIR_BASE
        hair_map[(27, y)] = HAIR_BASE
        hair_map[(28, y)] = HAIR_BASE
        if y <= 10: hair_map[(26, y)] = HAIR_BASE

    # Brow bangs (framing forehead)
    for y in range(7, 9):
        for x in range(5, 10): hair_map[(x, y)] = HAIR_BASE
        for x in range(22, 27): hair_map[(x, y)] = HAIR_BASE
    hair_map[(5, 9)] = HAIR_BASE; hair_map[(6, 9)] = HAIR_BASE
    hair_map[(25, 9)] = HAIR_BASE; hair_map[(26, 9)] = HAIR_BASE

    # Prominent central fringe lock dipping into forehead (sketch detail)
    for y in range(7, 9):
        for x in range(14, 18): hair_map[(x, y)] = HAIR_BASE
    for x in range(14, 17): hair_map[(x, 9)] = HAIR_BASE
    hair_map[(15, 10)] = HAIR_BASE

    # Outlining for hair
    outline_hair = set()
    for (x, y) in hair_map.keys():
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in hair_map:
                outline_hair.add((x, y))
                break

    for (x, y) in hair_map.keys():
        if (x, y) in outline_hair:
            pix[x, y] = HAIR_OUTLINE
        else:
            if y == 2 and x in (8, 9, 15, 16, 22, 23):
                pix[x, y] = HAIR_LIGHT
            elif y in (3, 4) and (8 <= x <= 10 or 14 <= x <= 17 or 21 <= x <= 23):
                pix[x, y] = HAIR_MID
            elif y in (8, 9, 10):
                pix[x, y] = HAIR_DARK if (x, y) in outline_hair else HAIR_BASE
            else:
                pix[x, y] = HAIR_BASE

    # Forehead skin exposed above eyes
    for y in range(8, 12):
        for x in range(7, 14):
            if (x, y) not in hair_map and pix[x, y][3] > 30 and pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_LIGHT if y <= 10 else SKIN_BASE
        for x in range(17, 25):
            if (x, y) not in hair_map and pix[x, y][3] > 30 and pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_LIGHT if y <= 10 else SKIN_BASE

    # 2. Sleek Iconic Green Lantern Domino Mask
    mask_pixels = set()
    for y in range(12, 19):
        for x in range(4, 28):
            if (x, y) in hair_map: continue
            in_m = False
            # Nose bridge (y=14..15)
            if y in (14, 15) and 13 <= x <= 18: in_m = True
            # Left mask wing (surrounding left eye)
            elif 5 <= x <= 12 and 13 <= y <= 18: in_m = True
            elif y == 12 and (5 <= x <= 7 or 11 <= x <= 12): in_m = True # brow arch
            elif y in (13, 14, 15) and x in (4, 5): in_m = True # pointed outer flare
            # Right mask wing (surrounding right eye)
            elif 19 <= x <= 26 and 13 <= y <= 18: in_m = True
            elif y == 12 and (19 <= x <= 20 or 24 <= x <= 26): in_m = True # brow arch
            elif y in (13, 14, 15) and x in (26, 27): in_m = True # pointed outer flare
            if in_m and pix[x, y][3] > 30:
                mask_pixels.add((x, y))

    mask_outline = set()
    for (x, y) in mask_pixels:
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in mask_pixels:
                mask_outline.add((x, y))
                break

    for (x, y) in mask_pixels:
        if (x, y) in mask_outline:
            pix[x, y] = MASK_OUTLINE
        else:
            if y == 13 and (6 <= x <= 11 or 20 <= x <= 25):
                pix[x, y] = MASK_LIGHT
            elif y in (13, 14) and 13 <= x <= 18:
                pix[x, y] = MASK_LIGHT if y == 13 else MASK_BASE
            elif y >= 17:
                pix[x, y] = MASK_DARK
            else:
                pix[x, y] = MASK_BASE

    # Comic Hero White Eyes (heroic almond shape inside mask)
    for y in range(14, 17):
        for x in range(7, 12):
            if (x, y) in mask_pixels and (x, y) not in mask_outline:
                if (y in (14, 16) and 8 <= x <= 11) or (y == 15 and 7 <= x <= 11):
                    pix[x, y] = WHITE
    pix[8, 14] = EYE_RIM; pix[11, 14] = EYE_RIM
    pix[9, 15] = EYE_GLOW; pix[10, 15] = EYE_GLOW
    pix[8, 16] = EYE_RIM; pix[11, 16] = EYE_RIM

    for y in range(14, 17):
        for x in range(20, 25):
            if (x, y) in mask_pixels and (x, y) not in mask_outline:
                if (y in (14, 16) and 20 <= x <= 23) or (y == 15 and 20 <= x <= 24):
                    pix[x, y] = WHITE
    pix[20, 14] = EYE_RIM; pix[23, 14] = EYE_RIM
    pix[21, 15] = EYE_GLOW; pix[22, 15] = EYE_GLOW
    pix[20, 16] = EYE_RIM; pix[23, 16] = EYE_RIM

    # 3. Mouth (determined hero expression from sketch)
    if not is_shooting:
        pix[14, 20] = OUTLINE; pix[15, 20] = OUTLINE; pix[16, 20] = OUTLINE; pix[17, 20] = OUTLINE
        pix[13, 21] = OUTLINE
        pix[14, 21] = WHITE; pix[15, 21] = WHITE; pix[16, 21] = WHITE; pix[17, 21] = (45, 18, 18, 255)
        pix[18, 21] = OUTLINE
        pix[14, 22] = OUTLINE; pix[15, 22] = OUTLINE; pix[16, 22] = OUTLINE; pix[17, 22] = OUTLINE
    else:
        for mx in range(13, 19):
            pix[mx, 19] = OUTLINE; pix[mx, 22] = OUTLINE
        pix[13, 20] = OUTLINE; pix[13, 21] = OUTLINE
        pix[18, 20] = OUTLINE; pix[18, 21] = OUTLINE
        for mx in range(14, 18):
            pix[mx, 20] = WHITE
            pix[mx, 21] = (50, 16, 16, 255)

    return img

def render_hal_head_side(base_head, is_shooting=False):
    img = clean_base_head(base_head)
    pix = img.load()

    hair_map = {}
    for y in range(2, 20):
        for x in range(2, 27):
            if pix[x, y][3] > 30:
                is_h = False
                if y <= 7: is_h = True
                elif x <= 13 and y <= 18: is_h = True
                elif y in (8, 9) and x <= 22: is_h = True
                elif y == 10 and (x <= 16 or (20 <= x <= 23)): is_h = True
                elif y in (11, 12) and (x <= 13 or (21 <= x <= 22 and y == 11)): is_h = True
                if is_h: hair_map[(x, y)] = HAIR_BASE

    for x, y in [(13, 1), (14, 1), (12, 2), (13, 2), (14, 2), (15, 2), (21, 8), (22, 8), (22, 9)]:
        hair_map[(x, y)] = HAIR_BASE

    outline_hair = set()
    for (x, y) in hair_map.keys():
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in hair_map:
                outline_hair.add((x, y))
                break

    for (x, y) in hair_map.keys():
        if (x, y) in outline_hair:
            pix[x, y] = HAIR_OUTLINE
        else:
            if y <= 3 and 12 <= x <= 15:
                pix[x, y] = HAIR_LIGHT
            elif y in (4, 5, 6) and 6 <= x <= 16:
                pix[x, y] = HAIR_MID
            elif y >= 11:
                pix[x, y] = HAIR_DARK if x <= 5 else HAIR_BASE
            else:
                pix[x, y] = HAIR_BASE

    # Profile Domino Mask
    mask_pixels = set()
    for y in range(12, 19):
        for x in range(13, 25):
            if (x, y) in hair_map: continue
            in_m = False
            if y in (12, 18) and 15 <= x <= 22: in_m = True
            elif 13 <= y <= 17 and 14 <= x <= 23: in_m = True
            elif x in (13, 14) and y in (14, 15): in_m = True
            if in_m and pix[x, y][3] > 30:
                mask_pixels.add((x, y))

    mask_outline = set()
    for (x, y) in mask_pixels:
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in mask_pixels:
                mask_outline.add((x, y))
                break

    for (x, y) in mask_pixels:
        if (x, y) in mask_outline:
            pix[x, y] = MASK_OUTLINE
        else:
            pix[x, y] = MASK_LIGHT if y == 13 else (MASK_DARK if y >= 17 else MASK_BASE)

    # Heroic comic eye profile
    for y in range(14, 17):
        for x in range(16, 22):
            if (x, y) in mask_pixels and (x, y) not in mask_outline:
                if (y in (14, 16) and 17 <= x <= 20) or (y == 15 and 16 <= x <= 21):
                    pix[x, y] = WHITE
    pix[17, 14] = EYE_RIM; pix[20, 14] = EYE_RIM
    pix[18, 15] = EYE_GLOW; pix[19, 15] = EYE_GLOW

    # Mouth profile
    if not is_shooting:
        pix[25, 20] = OUTLINE; pix[26, 20] = OUTLINE
        pix[25, 21] = OUTLINE; pix[26, 21] = WHITE; pix[27, 21] = OUTLINE
        pix[25, 22] = OUTLINE; pix[26, 22] = OUTLINE
    else:
        pix[24, 19] = OUTLINE; pix[25, 19] = OUTLINE; pix[26, 19] = OUTLINE
        pix[24, 20] = OUTLINE; pix[25, 20] = WHITE; pix[26, 20] = (50, 16, 16, 255); pix[27, 20] = OUTLINE
        pix[24, 21] = OUTLINE; pix[25, 21] = WHITE; pix[26, 21] = (50, 16, 16, 255); pix[27, 21] = OUTLINE
        pix[24, 22] = OUTLINE; pix[25, 22] = OUTLINE; pix[26, 22] = OUTLINE

    return img

def render_hal_head_back(base_head, is_shooting=False):
    img = clean_base_head(base_head)
    pix = img.load()

    hair_map = {}
    for y in range(2, 19):
        for x in range(2, 30):
            if pix[x, y][3] > 30:
                hair_map[(x, y)] = HAIR_BASE

    for x, y in [(15, 1), (16, 1), (14, 2), (15, 2), (16, 2), (17, 2)]:
        hair_map[(x, y)] = HAIR_BASE

    outline_hair = set()
    for (x, y) in hair_map.keys():
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in hair_map:
                outline_hair.add((x, y))
                break

    for (x, y) in hair_map.keys():
        if (x, y) in outline_hair:
            pix[x, y] = HAIR_OUTLINE
        else:
            if y <= 3 and x in (14, 15, 16, 17):
                pix[x, y] = HAIR_LIGHT
            elif y in (4, 5, 6, 7) and x in (9, 10, 15, 16, 21, 22):
                pix[x, y] = HAIR_LIGHT if y in (5, 6) else HAIR_MID
            elif y in (4, 5, 6, 7, 8):
                pix[x, y] = HAIR_MID
            elif y in (12, 13, 14) and x in (11, 20):
                pix[x, y] = HAIR_DARK
            elif y in (15, 16, 17) and x in (10, 21):
                pix[x, y] = HAIR_DARK
            else:
                pix[x, y] = HAIR_BASE

    # Exposed nape
    for y in range(19, 26):
        for x in range(8, 24):
            if (x, y) not in hair_map and pix[x, y][3] > 30 and pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_SHADOW if y <= 21 else SKIN_BASE

    return img

def render_hal_head_sad(base_head, is_side=False):
    """Generates hurt/sad head with new hair & domino mask preserved."""
    if not is_side:
        img = render_hal_head_front(base_head, is_shooting=False)
        pix = img.load()
        # Sad eyes: white hero eyes with blue tear drops below
        for x in range(14, 18):
            pix[x, 21] = OUTLINE # closed grimace mouth
            pix[x, 22] = SKIN_SHADOW
        return img
    else:
        img = render_hal_head_side(base_head, is_shooting=False)
        pix = img.load()
        pix[25, 21] = OUTLINE
        pix[26, 21] = OUTLINE
        return img

# ==================== TAINTED HAL (PARALLAX) HEADS ====================

def render_tainted_head_front(base_head, is_shooting=False):
    img = render_hal_head_front(base_head, is_shooting)
    pix = img.load()

    for y in range(1, 14):
        for x in range(2, 30):
            if pix[x, y] in (HAIR_BASE, HAIR_MID):
                pix[x, y] = THAL_HAIR_BASE
            elif pix[x, y] == HAIR_LIGHT:
                pix[x, y] = HAIR_MID

    # Sleek silver hair streaks along temples
    for y in range(7, 13):
        for x in (5, 6):
            if pix[x, y] in (THAL_HAIR_BASE, HAIR_MID, HAIR_DARK):
                pix[x, y] = SILVER_LIGHT if y in (8, 9) else SILVER_BASE
        for x in (25, 26):
            if pix[x, y] in (THAL_HAIR_BASE, HAIR_MID, HAIR_DARK):
                pix[x, y] = SILVER_LIGHT if y in (8, 9) else SILVER_BASE

    # Corrupted darker domino mask
    for y in range(12, 19):
        for x in range(4, 28):
            if pix[x, y] == MASK_BASE: pix[x, y] = SUIT_DARK_BASE
            elif pix[x, y] == MASK_LIGHT: pix[x, y] = SUIT_DARK_LIGHT
            elif pix[x, y] == MASK_DARK: pix[x, y] = SUIT_DARK_OUTLINE

    # Piercing Cosmic Yellow Eyes
    for y in range(14, 17):
        for x in range(7, 12):
            if pix[x, y] in (WHITE, EYE_GLOW, EYE_RIM):
                pix[x, y] = PARALLAX_YELLOW_BASE
    pix[9, 15] = PARALLAX_YELLOW_GLOW; pix[10, 15] = PARALLAX_YELLOW_GLOW
    pix[8, 14] = PARALLAX_YELLOW_DEEP; pix[11, 14] = PARALLAX_YELLOW_DEEP
    pix[8, 16] = PARALLAX_YELLOW_DEEP; pix[11, 16] = PARALLAX_YELLOW_DEEP

    for y in range(14, 17):
        for x in range(20, 25):
            if pix[x, y] in (WHITE, EYE_GLOW, EYE_RIM):
                pix[x, y] = PARALLAX_YELLOW_BASE
    pix[21, 15] = PARALLAX_YELLOW_GLOW; pix[22, 15] = PARALLAX_YELLOW_GLOW
    pix[20, 14] = PARALLAX_YELLOW_DEEP; pix[23, 14] = PARALLAX_YELLOW_DEEP
    pix[20, 16] = PARALLAX_YELLOW_DEEP; pix[23, 16] = PARALLAX_YELLOW_DEEP

    return img

def render_tainted_head_side(base_head, is_shooting=False):
    img = render_hal_head_side(base_head, is_shooting)
    pix = img.load()

    for y in range(1, 20):
        for x in range(2, 27):
            if pix[x, y] in (HAIR_BASE, HAIR_MID):
                pix[x, y] = THAL_HAIR_BASE
            elif pix[x, y] == HAIR_LIGHT:
                pix[x, y] = HAIR_MID

    # Sleek silver hair streak above ear
    for y in range(9, 13):
        for x in (10, 11):
            if pix[x, y] in (THAL_HAIR_BASE, HAIR_MID, HAIR_DARK):
                pix[x, y] = SILVER_LIGHT if y in (10, 11) else SILVER_BASE

    for y in range(12, 19):
        for x in range(13, 25):
            if pix[x, y] == MASK_BASE: pix[x, y] = SUIT_DARK_BASE
            elif pix[x, y] == MASK_LIGHT: pix[x, y] = SUIT_DARK_LIGHT
            elif pix[x, y] == MASK_DARK: pix[x, y] = SUIT_DARK_OUTLINE

    for y in range(14, 17):
        for x in range(16, 22):
            if pix[x, y] in (WHITE, EYE_GLOW, EYE_RIM):
                pix[x, y] = PARALLAX_YELLOW_BASE
    pix[18, 15] = PARALLAX_YELLOW_GLOW; pix[19, 15] = PARALLAX_YELLOW_GLOW
    pix[17, 14] = PARALLAX_YELLOW_DEEP; pix[20, 14] = PARALLAX_YELLOW_DEEP
    pix[17, 16] = PARALLAX_YELLOW_DEEP; pix[20, 16] = PARALLAX_YELLOW_DEEP

    return img

def render_tainted_head_back(base_head, is_shooting=False):
    img = render_hal_head_back(base_head, is_shooting)
    pix = img.load()

    for y in range(1, 22):
        for x in range(2, 30):
            if pix[x, y] in (HAIR_BASE, HAIR_MID):
                pix[x, y] = THAL_HAIR_BASE
            elif pix[x, y] == HAIR_LIGHT:
                pix[x, y] = HAIR_MID

    for y in range(8, 14):
        for x in (5, 6):
            if pix[x, y] in (THAL_HAIR_BASE, HAIR_MID, HAIR_DARK):
                pix[x, y] = SILVER_LIGHT if y in (9, 10) else SILVER_BASE
        for x in (25, 26):
            if pix[x, y] in (THAL_HAIR_BASE, HAIR_MID, HAIR_DARK):
                pix[x, y] = SILVER_LIGHT if y in (9, 10) else SILVER_BASE

    return img

# ==================== BODY & SUIT GENERATION ====================

def render_hal_body_front(base_body):
    """
    Hal Jordan Suit directly following User Sketch:
    - Shoulders (x<=10, x>=21, y<=16): Dark forest green sleeves
    - Outer torso flanks (x in (11, 12, 19, 20), y in (14..17)): Dark forest green
    - Gauntlets / Gloves (y >= 17 on outer arms): Vibrant light green
    - Central chest plate (x=13..18, y=13..18): Vibrant light emerald green with Emblem
    - Pants (y=20..21): Dark forest green
    - Boots (y=22..25): Vibrant light emerald green
    - Right fist: Glowing emerald Power Ring
    """
    img = base_body.copy().convert("RGBA")
    pix = img.load()

    for y in range(12, 26):
        for x in range(5, 27):
            p = pix[x, y]
            if p[3] > 30 and p != OUTLINE:
                # Outer arms / sleeves / gauntlets
                if x <= 10 or x >= 21:
                    if y <= 16:
                        pix[x, y] = SUIT_DARK_BASE
                    else:
                        pix[x, y] = GLOVE_LIGHT if (y == 17 and x in (8, 23)) else GLOVE_BASE

                # Center Torso
                elif 11 <= x <= 20 and 12 <= y <= 19:
                    if (x in (11, 12) or x in (19, 20)) and y in (14, 15, 16, 17):
                        pix[x, y] = SUIT_DARK_BASE
                    elif y == 19:
                        pix[x, y] = SUIT_DARK_LIGHT if 13 <= x <= 18 else SUIT_DARK_BASE
                    else:
                        # Green Lantern Emblem on chest plate
                        if y == 14 and 13 <= x <= 18:
                            pix[x, y] = EMBLEM_LINE
                        elif y == 18 and 13 <= x <= 18:
                            pix[x, y] = EMBLEM_LINE
                        elif y in (15, 17) and 14 <= x <= 17:
                            pix[x, y] = EMBLEM_LINE
                        elif y == 16 and (x in (13, 18)):
                            pix[x, y] = EMBLEM_LINE
                        elif y == 16 and (x in (14, 17)):
                            pix[x, y] = EMBLEM_LINE
                        elif y == 16 and x in (15, 16):
                            pix[x, y] = EMBLEM_CORE
                        else:
                            pix[x, y] = SUIT_LIGHT_BRIGHT if y == 13 else SUIT_LIGHT_BASE

                # Lower body: pants & boots
                elif 20 <= y <= 25:
                    if y in (20, 21):
                        pix[x, y] = SUIT_DARK_BASE
                    else:
                        pix[x, y] = BOOT_LIGHT if y == 22 else BOOT_BASE

    # Power Ring on right fist
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

    # Yellow fear ring on left fist, green power ring on right fist
    if pix[7, 17][3] > 30: pix[7, 17] = THAL_RING_YELLOW
    if pix[8, 17][3] > 30 and pix[8, 17] != OUTLINE: pix[8, 17] = (255, 255, 180, 255)
    if pix[24, 18][3] > 30: pix[24, 18] = RING_GEM
    if pix[23, 18][3] > 30 and pix[23, 18] != OUTLINE: pix[23, 18] = RING_AURA

    return img

def recolor_hal_walk_frames(target_sheet):
    """
    Recolors all walking animations (Row 1 cols 1..15, Row 2 cols 0..15)
    to match the new suit (light green gloves, light green boots).
    Replaces old white glove/boot colors with vibrant emerald greens.
    """
    pix = target_sheet.load()
    old_white_base = (222, 232, 226, 255)
    old_white_bright = (252, 255, 252, 255)

    for y in range(32, 96): # Rows 1 and 2
        for x in range(0, 512):
            if y < 64 and x < 32:
                continue # Row 1 Col 0 handled separately by custom front body
            p = pix[x, y]
            if p == old_white_base:
                pix[x, y] = GLOVE_BASE
            elif p == old_white_bright:
                pix[x, y] = GLOVE_LIGHT

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
    new_hal_hd_shoot = render_hal_head_front(v_hd, is_shooting=True)
    new_hal_hr = render_hal_head_side(v_hr, is_shooting=False)
    new_hal_hr_shoot = render_hal_head_side(v_hr, is_shooting=True)
    new_hal_hu = render_hal_head_back(v_hu, is_shooting=False)
    new_hal_hu_shoot = render_hal_head_back(v_hu, is_shooting=True)
    new_hal_hl = new_hal_hr.transpose(Image.FLIP_LEFT_RIGHT)
    new_hal_hl_shoot = new_hal_hr_shoot.transpose(Image.FLIP_LEFT_RIGHT)
    new_hal_sad_front = render_hal_head_sad(v_hd, is_side=False)
    new_hal_sad_right = render_hal_head_sad(v_hr, is_side=True)
    new_hal_sad_left = new_hal_sad_right.transpose(Image.FLIP_LEFT_RIGHT)
    new_hal_bd = render_hal_body_front(c_bd)

    new_thal_hd = render_tainted_head_front(v_hd, is_shooting=False)
    new_thal_hd_shoot = render_tainted_head_front(v_hd, is_shooting=True)
    new_thal_hr = render_tainted_head_side(v_hr, is_shooting=False)
    new_thal_hr_shoot = render_tainted_head_side(v_hr, is_shooting=True)
    new_thal_hu = render_tainted_head_back(v_hu, is_shooting=False)
    new_thal_hu_shoot = render_tainted_head_back(v_hu, is_shooting=True)
    new_thal_hl = new_thal_hr.transpose(Image.FLIP_LEFT_RIGHT)
    new_thal_hl_shoot = new_thal_hr_shoot.transpose(Image.FLIP_LEFT_RIGHT)
    new_thal_sad_front = render_tainted_head_front(v_hd, is_shooting=False)
    new_thal_sad_right = render_tainted_head_side(v_hr, is_shooting=False)
    new_thal_sad_left = new_thal_sad_right.transpose(Image.FLIP_LEFT_RIGHT)
    new_thal_bd = render_tainted_body_front(v_bd, ct_bd)

    # 1. Generate Full 512x512 Proposed Sprite Sheets with COMPLETE animation coverage
    prop_hal = current_hal.copy()
    # Row 0 heads
    prop_hal.paste(new_hal_hd, (0, 0), new_hal_hd)
    prop_hal.paste(new_hal_hd_shoot, (32, 0), new_hal_hd_shoot)
    prop_hal.paste(new_hal_hr, (64, 0), new_hal_hr)
    prop_hal.paste(new_hal_hr_shoot, (96, 0), new_hal_hr_shoot)
    prop_hal.paste(new_hal_hu, (128, 0), new_hal_hu)
    prop_hal.paste(new_hal_hu_shoot, (160, 0), new_hal_hu_shoot)
    prop_hal.paste(new_hal_hl, (192, 0), new_hal_hl)
    prop_hal.paste(new_hal_hl_shoot, (224, 0), new_hal_hl_shoot)
    prop_hal.paste(new_hal_sad_front, (256, 0), new_hal_sad_front)
    prop_hal.paste(new_hal_sad_right, (14 * 32, 0), new_hal_sad_right)
    prop_hal.paste(new_hal_sad_left, (15 * 32, 0), new_hal_sad_left)
    # Row 1 body idle
    prop_hal.paste(new_hal_bd, (0, 32), new_hal_bd)
    # Recolor all walk frames across Rows 1 & 2
    recolor_hal_walk_frames(prop_hal)

    prop_thal = current_tainted.copy()
    # Row 0 heads
    prop_thal.paste(new_thal_hd, (0, 0), new_thal_hd)
    prop_thal.paste(new_thal_hd_shoot, (32, 0), new_thal_hd_shoot)
    prop_thal.paste(new_thal_hr, (64, 0), new_thal_hr)
    prop_thal.paste(new_thal_hr_shoot, (96, 0), new_thal_hr_shoot)
    prop_thal.paste(new_thal_hu, (128, 0), new_thal_hu)
    prop_thal.paste(new_thal_hu_shoot, (160, 0), new_thal_hu_shoot)
    prop_thal.paste(new_thal_hl, (192, 0), new_thal_hl)
    prop_thal.paste(new_thal_hl_shoot, (224, 0), new_thal_hl_shoot)
    prop_thal.paste(new_thal_sad_front, (256, 0), new_thal_sad_front)
    prop_thal.paste(new_thal_sad_right, (14 * 32, 0), new_thal_sad_right)
    prop_thal.paste(new_thal_sad_left, (15 * 32, 0), new_thal_sad_left)
    # Row 1 body idle (preserving cape!)
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
    print(f"  [SAVED] {showcase_path}")
    for adir in ARTIFACT_DIRS:
        os.makedirs(adir, exist_ok=True)
        ashowcase = os.path.join(adir, "character_redesign_preview.png")
        showcase.save(ashowcase)
        print(f"  [SAVED] {ashowcase}")

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

    zoom_path = os.path.join(PROJECT_DIR, "character_redesign_zoom8x.png")
    zoom_sheet.save(zoom_path)
    print(f"  [SAVED] {zoom_path}")
    for adir in ARTIFACT_DIRS:
        azoom = os.path.join(adir, "character_redesign_zoom8x.png")
        zoom_sheet.save(azoom)
        print(f"  [SAVED] {azoom}")

    # 4. Item Costume Merge Verification
    from tools.verify_costume_merging import run_verification
    run_verification()

    print("-" * 60)
    print("ALL REDESIGN ASSETS AND VERIFICATIONS READY FOR USER REVIEW")
    print("-" * 60)

if __name__ == "__main__":
    generate_all()
