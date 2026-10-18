import os
from PIL import Image

ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\d0abad69-7124-472e-9088-fe0a1a3473a9"
old_h = Image.open(os.path.join(ARTIFACT_DIR, "curr_hal_menu_portrait.png")).convert("RGBA")

# Colors
OUTLINE = (28, 22, 21, 255)
SKIN_BASE = (232, 186, 158, 255)
SKIN_SHADOW = (201, 148, 120, 255)
SKIN_HIGHLIGHT = (244, 212, 192, 255)

HAIR_DARK = (44, 26, 17, 255)
HAIR_BASE = (93, 58, 36, 255)
HAIR_MID = (118, 77, 49, 255)
HAIR_LIGHT = (145, 98, 64, 255)
HAIR_HIGHLIGHT = (167, 116, 77, 255)

SILVER_DARK = (120, 144, 156, 255)
SILVER_BASE = (176, 190, 197, 255)
SILVER_LIGHT = (236, 239, 241, 255)

EMERALD_OUTLINE = (0, 77, 32, 255)
EMERALD_DARK = (0, 122, 51, 255)
EMERALD_BASE = (0, 200, 83, 255)
EMERALD_LIGHT = (0, 230, 118, 255)
EMERALD_GLOW = (105, 240, 174, 255)

PARALLAX_YELLOW = (238, 255, 65, 255)
PARALLAX_YELLOW_GLOW = (255, 255, 170, 255)
PARALLAX_ARMOR_DARK = (0, 60, 25, 255)
PARALLAX_ARMOR_BASE = (0, 145, 58, 255)
PARALLAX_ARMOR_LIGHT = (0, 215, 85, 255)

WHITE = (255, 255, 255, 255)
WHITE_GLOW = (235, 255, 242, 255)
BLACK_SUIT = (24, 24, 24, 255)
BLACK_SUIT_LIGHT = (48, 48, 52, 255)

def clean_and_refine_hal_menu():
    im = old_h.copy()
    pix = im.load()
    w, h = im.size

    # Clean up every pixel in the 48x52 grid based on geometry and features
    for y in range(h):
        for x in range(w):
            p = pix[x, y]
            if p[3] < 50 or y >= 42: # zero out bottom stray line
                pix[x, y] = (0, 0, 0, 0)
                continue

            r, g, b, a = p
            # Black outline / dark contour
            if r < 40 and g < 40 and b < 40:
                pix[x, y] = OUTLINE
            # Green mask and suit
            elif g > r + 30 and g > b + 30:
                if y <= 25: # mask
                    is_edge = False
                    for ox, oy in [(-1,0), (1,0), (0,-1), (0,1)]:
                        if pix[x+ox, y+oy][:3] in [SKIN_BASE[:3], SKIN_SHADOW[:3], (0, 0, 0)]:
                            is_edge = True; break
                    if is_edge:
                        pix[x, y] = EMERALD_OUTLINE
                    elif y in (19, 20) and (13 <= x <= 18 or 30 <= x <= 35):
                        pix[x, y] = EMERALD_LIGHT
                    else:
                        pix[x, y] = EMERALD_BASE
                else: # suit / boots
                    if y in (32, 33) and 21 <= x <= 27:
                        # Chest emblem center
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
                    # Comic white slit eye
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
                # Classify edge pixels
                if y <= 16:
                    pix[x, y] = HAIR_BASE if r > 50 else HAIR_DARK
                elif y <= 25:
                    pix[x, y] = EMERALD_BASE if g > 80 else EMERALD_OUTLINE
                else:
                    pix[x, y] = OUTLINE

    # Clean eye accents
    # Left eye: X: 15..18, Y: 21..23
    for y in range(21, 24):
        for x in range(15, 19):
            pix[x, y] = WHITE
    pix[15, 21] = EMERALD_GLOW; pix[18, 21] = EMERALD_GLOW

    # Right eye: X: 29..32, Y: 21..23
    for y in range(21, 24):
        for x in range(29, 33):
            pix[x, y] = WHITE
    pix[29, 21] = EMERALD_GLOW; pix[32, 21] = EMERALD_GLOW

    # Ensure zero dirty alpha
    for y in range(h):
        for x in range(w):
            if pix[x, y][3] == 0:
                pix[x, y] = (0, 0, 0, 0)

    return im

def clean_and_refine_tainted_menu():
    im = clean_and_refine_hal_menu()
    pix = im.load()
    w, h = im.size

    # 1. PARALLAX SILVER/WHITE TEMPLE STREAKS
    # Left temple: X: 10..15, Y: 12..20
    for y in range(12, 21):
        for x in range(10, 16):
            p = pix[x, y]
            if p in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK, HAIR_HIGHLIGHT):
                if y in (14, 15, 16) and 11 <= x <= 14:
                    pix[x, y] = SILVER_LIGHT
                elif y in (13, 17, 18) and 10 <= x <= 15:
                    pix[x, y] = SILVER_BASE
                else:
                    pix[x, y] = SILVER_DARK

    # Right temple: X: 33..38, Y: 12..20
    for y in range(12, 21):
        for x in range(33, 39):
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
                pix[x, y] = PARALLAX_YELLOW # corrupt yellow insignia

    # Ensure zero dirty alpha
    for y in range(h):
        for x in range(w):
            if pix[x, y][3] == 0:
                pix[x, y] = (0, 0, 0, 0)

    return im

if __name__ == "__main__":
    h = clean_and_refine_hal_menu()
    t = clean_and_refine_tainted_menu()

    h.save(os.path.join(ARTIFACT_DIR, "refined_hal_menu.png"))
    t.save(os.path.join(ARTIFACT_DIR, "refined_t_menu.png"))

    comp = Image.new("RGBA", (106, 52), (24, 24, 28, 255))
    comp.paste(h, (0, 0), h)
    comp.paste(t, (58, 0), t)
    comp_4x = comp.resize((comp.width * 4, comp.height * 4), Image.NEAREST)
    comp_4x.save(os.path.join(ARTIFACT_DIR, "test_refined_menu_4x.png"))
    print("Saved test_refined_menu_4x.png successfully.")
