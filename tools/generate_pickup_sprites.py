import os
from PIL import Image

OUTLINE = (12, 14, 12, 255)
SKIN_LIGHT = (235, 190, 165, 255)
SKIN_BASE = (204, 152, 128, 255)
SKIN_SHADOW = (172, 118, 96, 255)

# Hal colors
HAIR_LIGHT = (148, 92, 52, 255)
HAIR_MID = (108, 62, 32, 255)
HAIR_DARK = (74, 40, 18, 255)

MASK_BRIGHT = (58, 232, 102, 255)
MASK_MID = (24, 168, 62, 255)
MASK_DARK = (12, 108, 38, 255)
MASK_DEEP = (6, 52, 18, 255)

SUIT_GREEN = (24, 168, 62, 255)
SUIT_GREEN_BRIGHT = (58, 232, 102, 255)
SUIT_GREEN_DARK = (12, 108, 38, 255)
SUIT_BLACK = (40, 44, 48, 255)

WHITE = (255, 255, 255, 255)
GLOVE_SHADOW = (210, 220, 215, 255)
GLOVE_DARK = (170, 180, 175, 255)

RING_GEM = (0, 255, 120, 255)
RING_BAND = (12, 108, 38, 255)

# Tainted Hal (Parallax) colors
THAL_HAIR_GREY = (180, 185, 190, 255)
THAL_HAIR_MID = (90, 70, 60, 255)
THAL_HAIR_DARK = (50, 40, 35, 255)

THAL_MASK_BRIGHT = (32, 178, 86, 255)
THAL_MASK_MID = (16, 110, 52, 255)
THAL_MASK_DARK = (8, 64, 28, 255)
THAL_MASK_DEEP = (4, 32, 11, 255)

THAL_SUIT_GREEN = (16, 110, 52, 255)
THAL_SUIT_DARK = (20, 26, 24, 255)

THAL_GLOVE_LIGHT = (180, 188, 192, 255)
THAL_GLOVE_MID = (130, 138, 142, 255)
THAL_GLOVE_DARK = (80, 88, 92, 255)

THAL_RING_YELLOW = (255, 220, 40, 255)
THAL_RING_GEM = (255, 240, 80, 255)

def build_smiling_head_32(base_head, is_tainted=False):
    """Creates a 32x32 celebratory head with joyous open smile and white teeth."""
    out = base_head.copy()
    pix = out.load()

    mask_dark = THAL_MASK_DARK if is_tainted else MASK_DARK

    # Clean lower mask droop on cheeks (hy=18..22) so mask finishes cleanly at hy=18 under the eyes
    for x in range(6, 26):
        if 6 <= x <= 12 or 19 <= x <= 25:
            pix[x, 18] = mask_dark
        else:
            pix[x, 18] = SKIN_LIGHT

    for y in range(19, 23):
        for x in range(6, 26):
            if 9 <= x <= 22:
                pix[x, y] = SKIN_LIGHT if y <= 20 else SKIN_BASE
            elif pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_BASE

    # Celebratory open smile with gleaming white teeth (hy=19..22, hx=13..18)
    mouth_dark = (40, 15, 15, 255)
    for x in range(13, 19):
        pix[x, 19] = OUTLINE
    pix[13, 20] = OUTLINE
    for x in range(14, 18):
        pix[x, 20] = WHITE
    pix[18, 20] = OUTLINE

    pix[13, 21] = OUTLINE
    for x in range(14, 18):
        pix[x, 21] = mouth_dark
    pix[18, 21] = OUTLINE

    for x in range(14, 18):
        pix[x, 22] = OUTLINE

    return out

def build_smiling_head_64(smiling_head_32):
    """Places the 32x32 celebratory head at (16, 16) in a 64x64 cell for (256, 128, 320, 192)."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    out.paste(smiling_head_32, (16, 16), smiling_head_32)
    return out

def build_hal_pickupwalk_body(base_cell, is_side=False):
    """
    Converts a 32x32 vanilla Isaac PickupWalk body cell (X=256..512, Y=0..128)
    into Hal Jordan's Green Lantern suit with raised arms (\\o/), white superhero
    gauntlets, glowing Power Ring, chest lantern emblem, and walking boots.
    Carefully leaves the upper center face window transparent with a tapered
    jawline/shoulder transition so Layer 12 composites cleanly over Layer 4.
    """
    out = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    pix = out.load()

    for y in range(32):
        for x in range(32):
            c = base_cell.getpixel((x, y))
            if c[3] == 0:
                continue

            # Tapered upper-center face/chin window so Layer 4 head shows cleanly
            if y <= 12 and 10 <= x <= 21:
                continue
            if y == 13 and 11 <= x <= 20:
                continue
            if y == 14 and 12 <= x <= 19:
                continue

            # Raised Arms & Shoulders (y <= 15)
            if y <= 15:
                if y == 8:
                    if 4 <= x <= 8 or 23 <= x <= 27:
                        pix[x, y] = OUTLINE
                    continue
                if y in (9, 10, 11):
                    if x in (3, 4, 9, 22, 27, 28):
                        pix[x, y] = OUTLINE
                    elif 5 <= x <= 8 or 23 <= x <= 26:
                        if y == 9:
                            if not is_side and x == 7:
                                pix[x, y] = RING_GEM
                            elif not is_side and x in (6, 8):
                                pix[x, y] = RING_BAND
                            elif is_side and x == 24:
                                pix[x, y] = RING_GEM
                            elif is_side and x in (23, 25):
                                pix[x, y] = RING_BAND
                            else:
                                pix[x, y] = WHITE
                        else:
                            pix[x, y] = WHITE if c[0] > 200 else GLOVE_SHADOW
                    continue
                if y == 12:
                    if x in (4, 5, 9, 22, 26, 27):
                        pix[x, y] = OUTLINE
                    elif 6 <= x <= 8 or 23 <= x <= 25:
                        pix[x, y] = GLOVE_SHADOW
                    continue
                if y == 13:
                    if x in (5, 6, 10, 21, 25, 26):
                        pix[x, y] = OUTLINE
                    elif 7 <= x <= 9 or 22 <= x <= 24:
                        pix[x, y] = SUIT_GREEN
                    continue
                if y == 14:
                    if x in (6, 7, 11, 20, 24, 25):
                        pix[x, y] = OUTLINE
                    elif 8 <= x <= 10 or 21 <= x <= 23:
                        pix[x, y] = SUIT_GREEN
                    continue
                if y == 15:
                    if x in (7, 8, 23, 24) or (12 <= x <= 19):
                        pix[x, y] = OUTLINE
                    elif 9 <= x <= 11:
                        pix[x, y] = SUIT_BLACK if is_side else SUIT_GREEN
                    elif 20 <= x <= 22:
                        pix[x, y] = SUIT_GREEN
                    continue

            if c[0] < 50 and c[1] < 50 and c[2] < 50:
                pix[x, y] = OUTLINE
                continue

            # Torso (16 <= y <= 19)
            if 16 <= y <= 19:
                if not is_side:
                    if x in (14, 15, 16, 17) and y in (16, 17, 18):
                        if x in (15, 16) and y == 17:
                            pix[x, y] = SUIT_GREEN
                        else:
                            pix[x, y] = WHITE
                    elif 11 <= x <= 20:
                        pix[x, y] = SUIT_GREEN
                    else:
                        pix[x, y] = SUIT_BLACK
                else:
                    if y in (16, 17, 18) and x in (15, 16, 17):
                        pix[x, y] = SUIT_GREEN if (y == 17 and x == 16) else WHITE
                    elif x <= 12:
                        pix[x, y] = SUIT_BLACK
                    elif x >= 18:
                        pix[x, y] = SUIT_GREEN_BRIGHT
                    else:
                        pix[x, y] = SUIT_GREEN
                continue

            # Animated walking legs & boots (y >= 20)
            if y == 20:
                pix[x, y] = SUIT_BLACK
            elif y in (21, 22):
                pix[x, y] = WHITE if c[0] > 200 else GLOVE_SHADOW
            else:
                pix[x, y] = SUIT_GREEN if c[0] > 200 else SUIT_GREEN_DARK

    return out

def build_thal_pickupwalk_body(base_cell, is_side=False):
    """
    Converts a 32x32 vanilla Isaac PickupWalk body cell (X=256..512, Y=0..128)
    into Tainted Hal's (Parallax) suit with raised arms (\\o/), metallic gauntlets,
    Emerald & Yellow Fear rings, chest emblem, cape edge, and walking boots.
    """
    out = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    pix = out.load()

    for y in range(32):
        for x in range(32):
            c = base_cell.getpixel((x, y))
            if c[3] == 0:
                continue

            if y <= 12 and 10 <= x <= 21:
                continue
            if y == 13 and 11 <= x <= 20:
                continue
            if y == 14 and 12 <= x <= 19:
                continue

            # Raised Arms & Shoulders (y <= 15)
            if y <= 15:
                if y == 8:
                    if 4 <= x <= 8 or 23 <= x <= 27:
                        pix[x, y] = OUTLINE
                    continue
                if y in (9, 10, 11):
                    if x in (3, 4, 9, 22, 27, 28):
                        pix[x, y] = OUTLINE
                    elif 5 <= x <= 8 or 23 <= x <= 26:
                        if y == 9:
                            if not is_side:
                                if x == 7:
                                    pix[x, y] = RING_GEM
                                elif x in (6, 8):
                                    pix[x, y] = RING_BAND
                                elif x == 24:
                                    pix[x, y] = THAL_RING_GEM
                                elif x in (23, 25):
                                    pix[x, y] = THAL_RING_YELLOW
                                else:
                                    pix[x, y] = THAL_GLOVE_LIGHT
                            else:
                                if x == 7:
                                    pix[x, y] = THAL_RING_GEM
                                elif x in (6, 8):
                                    pix[x, y] = THAL_RING_YELLOW
                                elif x == 24:
                                    pix[x, y] = RING_GEM
                                elif x in (23, 25):
                                    pix[x, y] = RING_BAND
                                else:
                                    pix[x, y] = THAL_GLOVE_LIGHT
                        else:
                            pix[x, y] = THAL_GLOVE_LIGHT if c[0] > 200 else THAL_GLOVE_MID
                    continue
                if y == 12:
                    if x in (4, 5, 9, 22, 26, 27):
                        pix[x, y] = OUTLINE
                    elif 6 <= x <= 8 or 23 <= x <= 25:
                        pix[x, y] = THAL_GLOVE_MID
                    continue
                if y == 13:
                    if x in (5, 6, 10, 21, 25, 26):
                        pix[x, y] = OUTLINE
                    elif 7 <= x <= 9 or 22 <= x <= 24:
                        pix[x, y] = THAL_SUIT_GREEN
                    continue
                if y == 14:
                    if x in (6, 7, 11, 20, 24, 25):
                        pix[x, y] = OUTLINE
                    elif 8 <= x <= 10 or 21 <= x <= 23:
                        pix[x, y] = THAL_SUIT_GREEN
                    continue
                if y == 15:
                    if x in (7, 8, 23, 24) or (12 <= x <= 19):
                        pix[x, y] = OUTLINE
                    elif 9 <= x <= 11:
                        pix[x, y] = THAL_SUIT_DARK if is_side else THAL_SUIT_GREEN
                    elif 20 <= x <= 22:
                        pix[x, y] = THAL_SUIT_GREEN
                    continue

            if c[0] < 50 and c[1] < 50 and c[2] < 50:
                pix[x, y] = OUTLINE
                continue

            # Torso (16 <= y <= 19)
            if 16 <= y <= 19:
                if not is_side:
                    if x in (14, 15, 16, 17) and y in (16, 17, 18):
                        if x in (15, 16) and y == 17:
                            pix[x, y] = THAL_MASK_BRIGHT
                        else:
                            pix[x, y] = WHITE
                    elif 11 <= x <= 20:
                        pix[x, y] = THAL_SUIT_GREEN
                    else:
                        pix[x, y] = THAL_SUIT_DARK
                else:
                    if y in (16, 17, 18) and x in (15, 16, 17):
                        pix[x, y] = THAL_MASK_BRIGHT if (y == 17 and x == 16) else WHITE
                    elif x <= 11:
                        pix[x, y] = THAL_MASK_DEEP
                    elif x == 12:
                        pix[x, y] = THAL_SUIT_DARK
                    elif x >= 18:
                        pix[x, y] = THAL_MASK_BRIGHT
                    else:
                        pix[x, y] = THAL_SUIT_GREEN
                continue

            # Animated walking legs & boots (y >= 20)
            if y == 20:
                pix[x, y] = THAL_SUIT_DARK
            elif y in (21, 22):
                pix[x, y] = THAL_GLOVE_LIGHT if c[0] > 200 else THAL_GLOVE_MID
            else:
                pix[x, y] = THAL_SUIT_GREEN if c[0] > 200 else THAL_MASK_DARK

    return out

def build_row192_f0(base_isaac_f0, head_32, is_tainted=False):
    """(0, 192): Stationary Pickup anticipation / universal full-body transition pose."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    # 1. Place head at (16, 21) so top outline is at Y=24 and chin outline is at Y=46
    for hy in range(32):
        for hx in range(32):
            c = head_32.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c

    # 2. Clean lower mask cheek droop (Y=39..43) so mask finishes cleanly at Y=39 under the eyes
    mask_dark = THAL_MASK_DARK if is_tainted else MASK_DARK
    for x in range(22, 42):
        if 22 <= x <= 28 or 35 <= x <= 41:
            pix[x, 39] = mask_dark
        else:
            pix[x, 39] = SKIN_LIGHT

    for y in range(40, 45):
        for x in range(22, 42):
            if 25 <= x <= 38:
                pix[x, y] = SKIN_LIGHT if y <= 41 else SKIN_BASE
            elif pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_BASE

    # 3. Wonder O-mouth below the mask bridge (Y=40..43, X=30..33)
    o_mouth = [
        (40, 31, OUTLINE), (40, 32, OUTLINE),
        (41, 30, OUTLINE), (41, 31, WHITE), (41, 32, WHITE), (41, 33, OUTLINE),
        (42, 30, OUTLINE), (42, 31, (40, 15, 15, 255)), (42, 32, (40, 15, 15, 255)), (42, 33, OUTLINE),
        (43, 31, OUTLINE), (43, 32, OUTLINE),
    ]
    for y, x, color in o_mouth:
        pix[x, y] = color

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    # 4. Torso & squatting legs from base_isaac_f0 (Y=47..56)
    for y in range(47, 57):
        for x in range(18, 46):
            c = base_isaac_f0.getpixel((x, y))
            if c[3] == 0:
                continue
            # Ignore base_isaac_f0's lower chin outline at Y=47..48 inside the chest so chin contour at Y=46 stays 1px crisp
            is_old_chin_outline = (
                (y == 47 and 26 <= x <= 37)
                or (y == 48 and 27 <= x <= 36)
            )
            if c[0] < 50 and not is_old_chin_outline:
                pix[x, y] = OUTLINE
            elif y in (52, 53):
                pix[x, y] = boot_cuff
            elif y >= 54:
                pix[x, y] = suit_green
            elif y in (50, 51) and x in (25, 26, 37, 38):
                pix[x, y] = glove_light if c[0] > 180 else glove_mid
            else:
                if x in (30, 31, 32, 33) and y in (48, 49, 50):
                    pix[x, y] = emblem_center if (x in (31, 32) and y == 49) else WHITE
                elif 27 <= x <= 36:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = suit_dark

    # Power ring on right hand (and yellow ring on left hand for Tainted Hal)
    pix[38, 50] = RING_GEM
    if is_tainted:
        pix[25, 50] = THAL_RING_GEM

    return out

def build_hal_f0(base_isaac_f0, hal_head):
    return build_row192_f0(base_isaac_f0, hal_head, is_tainted=False)

def build_thal_f0(base_isaac_f0, thal_head):
    return build_row192_f0(base_isaac_f0, thal_head, is_tainted=True)

def build_row192_f1(base_isaac_f1, head_32, is_tainted=False):
    """(64, 192): Stationary Pickup celebratory raised-arms pose."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    smiling_head = build_smiling_head_32(head_32, is_tainted=is_tainted)
    for hy in range(32):
        for hx in range(32):
            c = smiling_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    # Body: Torso (Y=47..51) & Legs (Y=52..56)
    for y in range(47, 57):
        for x in range(20, 44):
            c = base_isaac_f1.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif y in (52, 53):
                    pix[x, y] = boot_cuff
                elif y >= 54:
                    pix[x, y] = suit_green
                else:
                    if x in (30, 31, 32, 33) and y in (47, 48, 49):
                        pix[x, y] = emblem_center if (x in (31, 32) and y == 48) else WHITE
                    elif 27 <= x <= 36:
                        pix[x, y] = suit_green
                    else:
                        pix[x, y] = suit_dark

    # Raised arms & tapered shoulders at Y=39..46 (matching PickupWalk by=8..15 at offset +16, +31)
    for by in range(8, 16):
        y = by + 31
        for bx in range(3, 29):
            x = bx + 16
            c = base_isaac_f1.getpixel((x, y))
            if by <= 12 and 10 <= bx <= 21:
                continue
            if by == 13 and 11 <= bx <= 20:
                continue
            if by == 14 and 12 <= bx <= 19:
                continue
            if by == 8:
                if 4 <= bx <= 8 or 23 <= bx <= 27:
                    pix[x, y] = OUTLINE
            elif by in (9, 10, 11):
                if bx in (3, 4, 9, 22, 27, 28):
                    pix[x, y] = OUTLINE
                elif 5 <= bx <= 8 or 23 <= bx <= 26:
                    if by == 9:
                        if is_tainted and bx == 7:
                            pix[x, y] = THAL_RING_GEM
                        elif is_tainted and bx in (6, 8):
                            pix[x, y] = THAL_RING_YELLOW
                        elif bx == 24:
                            pix[x, y] = RING_GEM
                        elif bx in (23, 25):
                            pix[x, y] = RING_BAND
                        else:
                            pix[x, y] = glove_light
                    else:
                        pix[x, y] = glove_light if (c[3] > 0 and c[0] > 200) else glove_mid
            elif by == 12:
                if bx in (4, 5, 9, 22, 26, 27):
                    pix[x, y] = OUTLINE
                elif 6 <= bx <= 8 or 23 <= bx <= 25:
                    pix[x, y] = glove_mid
            elif by == 13:
                if bx in (5, 6, 10, 21, 25, 26):
                    pix[x, y] = OUTLINE
                elif 7 <= bx <= 9 or 22 <= bx <= 24:
                    pix[x, y] = suit_green
            elif by == 14:
                if bx in (6, 7, 11, 20, 24, 25):
                    pix[x, y] = OUTLINE
                elif 8 <= bx <= 10 or 21 <= bx <= 23:
                    pix[x, y] = suit_green
            elif by == 15:
                if bx in (7, 8, 23, 24) or (12 <= bx <= 19):
                    pix[x, y] = OUTLINE
                elif 9 <= bx <= 11 or 20 <= bx <= 22:
                    pix[x, y] = suit_green

    return out

def build_hal_f1(base_isaac_f1, hal_head):
    return build_row192_f1(base_isaac_f1, hal_head, is_tainted=False)

def build_thal_f1(base_isaac_f1, thal_head):
    return build_row192_f1(base_isaac_f1, thal_head, is_tainted=True)

def build_row192_f2(base_isaac_f2, is_tainted=False):
    """(128, 192): Hit / Damage recoiling wince pose built cleanly from vanilla isaac_f2."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    mask_bright = THAL_MASK_BRIGHT if is_tainted else MASK_BRIGHT
    mask_mid = THAL_MASK_MID if is_tainted else MASK_MID
    mask_dark = THAL_MASK_DARK if is_tainted else MASK_DARK

    hair_light = THAL_HAIR_MID if is_tainted else HAIR_LIGHT
    hair_mid = THAL_HAIR_MID if is_tainted else HAIR_MID
    hair_dark = THAL_HAIR_DARK if is_tainted else HAIR_DARK

    for y in range(23, 55):
        for x in range(20, 48):
            c = base_isaac_f2.getpixel((x, y))
            if c[3] == 0:
                continue
            if c[0] < 50 and c[1] < 50 and c[2] < 50:
                pix[x, y] = OUTLINE
                continue

            # 1. Head & Face (y <= 41, plus jaw at y=42)
            if y <= 40 or (y == 41 and 31 <= x <= 36):
                # Wincing teeth at y=41, x=32..35
                if y == 41 and 32 <= x <= 35 and c[0] > 235 and c[1] > 235 and c[2] > 235:
                    pix[x, y] = WHITE
                    continue

                # Pilot brown hair on top/temples of recoiling head (y=23..35)
                is_hair = (
                    y <= 32
                    or (y == 33 and (x <= 30 or x >= 36))
                    or (y == 34 and (x <= 26 or x >= 41 or (32 <= x <= 34)))
                    or (y == 35 and (x <= 24 or x >= 43))
                )
                if is_hair:
                    if is_tainted and 29 <= y <= 35 and (x <= 26 or x >= 41):
                        pix[x, y] = WHITE if y in (31, 32) else THAL_HAIR_GREY
                    elif 26 <= y <= 29 and 27 <= x <= 39:
                        pix[x, y] = hair_light
                    elif y <= 25 or x <= 23 or x >= 44:
                        pix[x, y] = hair_dark
                    else:
                        pix[x, y] = hair_mid
                    continue

                # Domino Mask framing the wincing >_< eye creases (y=36..40, strictly inside head outline)
                is_mask = (
                    (y == 36 and ((25 <= x <= 30) or (37 <= x <= 42)))
                    or (y == 37 and ((23 <= x <= 31) or (36 <= x <= 44)))
                    or (y in (38, 39) and (22 <= x <= 44))
                    or (y == 40 and ((24 <= x <= 30) or (37 <= x <= 43)))
                )
                if is_mask:
                    if y == 36 or (y == 37 and x in (25, 26, 27, 40, 41, 42)):
                        pix[x, y] = mask_bright
                    elif y == 40 or x in (31, 32, 35, 36):
                        pix[x, y] = mask_dark
                    else:
                        pix[x, y] = mask_mid
                    continue

                pix[x, y] = SKIN_LIGHT if c[0] > 195 else SKIN_BASE
                continue

            # 2. Left raised recoiling hand (y=41..45, x=22..28) & chin center (y=43, x=29..34)
            if y <= 46:
                if 29 <= x <= 35 and y <= 44:
                    pix[x, y] = SKIN_BASE
                elif y >= 45 and x <= 28:
                    pix[x, y] = suit_green
                elif y == 46 and x >= 37:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = glove_light if c[0] > 195 else glove_mid
                continue

            # 3. Recoiling torso & boots (y=47..54)
            if y in (47, 48, 49, 50):
                if x in (28, 29, 30, 31) and y in (48, 49):
                    pix[x, y] = emblem_center if (x in (29, 30) and y == 49) else WHITE
                elif 25 <= x <= 33:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = suit_dark
            elif y == 51:
                pix[x, y] = boot_cuff
            else:
                pix[x, y] = suit_green

    # Power Ring on right recoiling fist (and yellow ring on left fist for Tainted Hal)
    pix[40, 44] = RING_GEM
    pix[39, 44] = glove_light
    pix[41, 44] = glove_light
    if is_tainted:
        pix[25, 42] = THAL_RING_GEM

    return out

def build_hal_f2(base_isaac_f2):
    return build_row192_f2(base_isaac_f2, is_tainted=False)

def build_thal_f2(base_isaac_f2):
    return build_row192_f2(base_isaac_f2, is_tainted=True)

def build_row192_f3(base_isaac_f3, is_tainted=False):
    """(192, 192): Sad bowed-head pose with both gloved hands covering face, built cleanly from vanilla isaac_f3."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    mask_bright = THAL_MASK_BRIGHT if is_tainted else MASK_BRIGHT
    mask_mid = THAL_MASK_MID if is_tainted else MASK_MID
    mask_dark = THAL_MASK_DARK if is_tainted else MASK_DARK

    hair_light = THAL_HAIR_MID if is_tainted else HAIR_LIGHT
    hair_mid = THAL_HAIR_MID if is_tainted else HAIR_MID
    hair_dark = THAL_HAIR_DARK if is_tainted else HAIR_DARK
    tear_color = (255, 230, 80, 255) if is_tainted else (156, 200, 204, 255)

    for y in range(29, 59):
        for x in range(18, 46):
            c = base_isaac_f3.getpixel((x, y))
            if c[3] == 0:
                continue
            if c[0] < 50 and c[1] < 50 and c[2] < 50:
                pix[x, y] = OUTLINE
                continue

            # 1. Bowed Crown Hair (y=29..39, plus temple sweeps at y=40)
            is_hair = (
                y <= 38
                or (y == 39 and (x <= 29 or x >= 34))
                or (y == 40 and (x <= 23 or x >= 40))
            )
            if is_hair:
                if is_tainted and 35 <= y <= 40 and (x <= 24 or x >= 39):
                    pix[x, y] = WHITE if y in (36, 37) else THAL_HAIR_GREY
                elif 32 <= y <= 35 and 25 <= x <= 38:
                    pix[x, y] = hair_light
                elif y <= 31 or x <= 21 or x >= 42 or y == 39:
                    pix[x, y] = hair_dark
                else:
                    pix[x, y] = hair_mid
                continue

            # 2. Forehead skin (y=39..41)
            if y <= 40:
                pix[x, y] = SKIN_LIGHT if c[0] > 195 else SKIN_BASE
                continue

            # 3. Domino Mask peeking around/behind the gloved hands (y=41..45)
            if y == 41:
                if 21 <= x <= 28 or 35 <= x <= 42:
                    pix[x, y] = mask_bright
                else:
                    pix[x, y] = SKIN_LIGHT
                continue
            if y == 42:
                pix[x, y] = mask_mid if (20 <= x <= 43) else SKIN_BASE
                continue
            if y == 43:
                if 29 <= x <= 34:
                    pix[x, y] = mask_dark
                else:
                    pix[x, y] = mask_mid
                continue

            # 4. Gloved hands covering eyes (x=24..29 and x=34..39, y=44..47), mask edges (x=20..23, 40..43), and nose bridge (x=30..33)
            if 44 <= y <= 47:
                if x <= 22 or x >= 41:
                    if y in (46, 47) and x in (21, 42):
                        pix[x, y] = tear_color
                    else:
                        pix[x, y] = mask_dark if y >= 46 else mask_mid
                elif 30 <= x <= 33:
                    pix[x, y] = SKIN_LIGHT if y <= 45 else SKIN_BASE
                else:
                    pix[x, y] = glove_light if c[0] > 195 else glove_mid
                continue

            # 5. Forearms/sleeves & chest emblem (y=48..51)
            if 48 <= y <= 51:
                if 30 <= x <= 33 and y in (48, 49, 50):
                    pix[x, y] = emblem_center if (x in (31, 32) and y == 49) else WHITE
                elif y <= 50 and (21 <= x <= 29 or 34 <= x <= 42):
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = suit_dark
                continue

            # 6. Boots & boot cuffs (y=53..57)
            if y in (53, 54):
                pix[x, y] = boot_cuff
            elif y >= 55:
                pix[x, y] = suit_green
            else:
                pix[x, y] = suit_dark

    # Power ring on right gloved hand (and yellow ring on left hand for Tainted Hal)
    pix[38, 45] = RING_GEM
    if is_tainted:
        pix[25, 45] = THAL_RING_GEM

    return out

def build_hal_f3(base_isaac_f3):
    return build_row192_f3(base_isaac_f3, is_tainted=False)

def build_thal_f3(base_isaac_f3):
    return build_row192_f3(base_isaac_f3, is_tainted=True)

def build_row128_f0(base_isaac, head_32, is_tainted=False):
    """(0, 128): Death horror/scream pose with both gloved hands on cheeks."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    for hy in range(32):
        for hx in range(32):
            c = head_32.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c

    mask_dark = THAL_MASK_DARK if is_tainted else MASK_DARK
    for x in range(22, 42):
        if 22 <= x <= 28 or 35 <= x <= 41:
            pix[x, 39] = mask_dark
        else:
            pix[x, 39] = SKIN_LIGHT

    for y in range(40, 46):
        for x in range(24, 40):
            pix[x, y] = SKIN_LIGHT if y <= 42 else SKIN_BASE

    # Tall screaming mouth (x=29..34, y=39..45)
    mouth_dark = (40, 15, 15, 255)
    tongue = (180, 75, 75, 255)
    for x in range(29, 35):
        pix[x, 39] = OUTLINE
        pix[x, 45] = OUTLINE
    for y in range(40, 45):
        pix[29, y] = OUTLINE
        pix[34, y] = OUTLINE
        for x in range(30, 34):
            if y == 40:
                pix[x, y] = WHITE
            elif y == 44 and x in (31, 32):
                pix[x, y] = tongue
            else:
                pix[x, y] = mouth_dark

    for x in range(27, 37):
        pix[x, 46] = SKIN_BASE
    for x in range(26, 38):
        pix[x, 47] = OUTLINE

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    # Torso & boots (y=48..56)
    for y in range(48, 57):
        for x in range(22, 42):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            # Avoid duplicating chin outline at y=48 (already drawn at y=47)
            is_old_chin_outline = (y == 48 and 26 <= x <= 37)
            if c[0] < 50 and not is_old_chin_outline:
                pix[x, y] = OUTLINE
            elif y in (52, 53):
                pix[x, y] = boot_cuff
            elif y >= 54:
                pix[x, y] = suit_green
            else:
                if x in (30, 31, 32, 33) and y in (48, 49, 50):
                    pix[x, y] = emblem_center if (x in (31, 32) and y == 49) else WHITE
                elif 27 <= x <= 36:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = suit_dark

    # Hands on cheeks & forearms (y=40..48)
    for y in range(40, 49):
        for x in list(range(18, 27)) + list(range(37, 46)):
            if y == 40 and x in (25, 26, 37, 38):
                continue
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            if c[0] < 50:
                pix[x, y] = OUTLINE
            elif y <= 45:
                pix[x, y] = glove_light if c[0] > 195 else glove_mid
            else:
                pix[x, y] = suit_green

    pix[42, 42] = RING_GEM
    pix[41, 42] = RING_BAND
    if is_tainted:
        pix[21, 42] = THAL_RING_GEM
        pix[22, 42] = THAL_RING_YELLOW

    return out

def build_row128_f1(base_isaac, head_32, is_tainted=False):
    """(64, 128): Happy thumbs-up transition pose."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    smiling_head = build_smiling_head_32(head_32, is_tainted=is_tainted)
    for hy in range(32):
        for hx in range(32):
            c = smiling_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    # Torso, left arm, and boots (y=47..56, x=21..39)
    for y in range(47, 57):
        for x in range(21, 40):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            is_old_chin_outline = (
                (y == 47 and 26 <= x <= 36)
                or (y == 48 and 25 <= x <= 34)
            )
            if c[0] < 50 and not is_old_chin_outline:
                pix[x, y] = OUTLINE
            elif x <= 26 and y in (48, 49, 50, 51):
                if y in (48, 49):
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = glove_light if c[0] > 195 else glove_mid
            elif y in (52, 53):
                pix[x, y] = boot_cuff
            elif y >= 54:
                pix[x, y] = suit_green
            else:
                if x in (30, 31, 32, 33) and y in (48, 49, 50):
                    pix[x, y] = emblem_center if (x in (31, 32) and y == 49) else WHITE
                elif 28 <= x <= 35:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = suit_dark

    # Right thumbs-up hand & forearm (y=36..51)
    for y in range(36, 52):
        if y in (36, 37):
            x_start = 42
        elif y == 38:
            x_start = 41
        elif y in (39, 40):
            x_start = 40
        elif y in (41, 42):
            x_start = 39
        elif y == 43:
            x_start = 38
        else:
            x_start = 37
        for x in range(x_start, 48):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            if c[0] < 50 or (y in (39, 40) and x == 40):
                pix[x, y] = OUTLINE
            elif y >= 49 and x <= 40:
                pix[x, y] = suit_green
            else:
                pix[x, y] = glove_light if c[0] > 195 else glove_mid

    pix[44, 45] = RING_GEM
    pix[43, 45] = RING_BAND
    if is_tainted:
        pix[24, 50] = THAL_RING_GEM

    return out

def build_row128_f2(base_isaac, head_32, is_tainted=False):
    """(128, 128): Happy main 12-frame big cheering grin + foreground thumbs-up pose."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    smiling_head = build_smiling_head_32(head_32, is_tainted=is_tainted)
    # Head shifted 1px left (at 15, 21) matching vanilla Isaac's (128, 128)
    for hy in range(32):
        for hx in range(32):
            c = smiling_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 15, hy + 21] = c

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    # Torso, left arm, and boots (y=47..56, x=21..39)
    for y in range(47, 57):
        for x in range(21, 40):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            is_old_chin_outline = (
                (y == 47 and 26 <= x <= 35)
                or (y == 48 and 25 <= x <= 35)
            )
            if c[0] < 50 and not is_old_chin_outline:
                pix[x, y] = OUTLINE
            elif x <= 26 and y in (48, 49, 50, 51):
                if y in (48, 49):
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = glove_light if c[0] > 195 else glove_mid
            elif y in (52, 53):
                pix[x, y] = boot_cuff
            elif y >= 54:
                pix[x, y] = suit_green
            else:
                if x in (29, 30, 31, 32) and y in (48, 49, 50):
                    pix[x, y] = emblem_center if (x in (30, 31) and y == 49) else WHITE
                elif 27 <= x <= 35:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = suit_dark

    # Large foreground thumbs-up hand (y=29..50)
    for y in range(29, 51):
        if y in (29, 30):
            x_start = 42
        elif y <= 37:
            x_start = 41
        elif y == 38:
            x_start = 40
        elif y in (39, 40):
            x_start = 39
        elif y in (41, 42):
            x_start = 37
        else:
            x_start = 36
        for x in range(x_start, 51):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            if c[0] < 50 or (y == 37 and x == 41):
                pix[x, y] = OUTLINE
            elif y >= 47 and x <= 40:
                pix[x, y] = suit_green
            else:
                pix[x, y] = glove_light if c[0] > 195 else glove_mid

    # Power ring on the foreground thumbs-up knuckle
    pix[46, 41] = RING_GEM
    pix[45, 41] = RING_BAND
    pix[47, 41] = RING_BAND
    if is_tainted:
        pix[24, 50] = THAL_RING_GEM

    return out

def build_row128_f3(base_isaac, is_tainted=False):
    """(192, 128): Appear / Death sideways lying pose (head on right, body/legs on left)."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_green_dark = THAL_MASK_DARK if is_tainted else SUIT_GREEN_DARK
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW

    mask_bright = THAL_MASK_BRIGHT if is_tainted else MASK_BRIGHT
    mask_mid = THAL_MASK_MID if is_tainted else MASK_MID
    mask_dark = THAL_MASK_DARK if is_tainted else MASK_DARK

    hair_light = THAL_HAIR_MID if is_tainted else HAIR_LIGHT
    hair_mid = THAL_HAIR_MID if is_tainted else HAIR_MID
    hair_dark = THAL_HAIR_DARK if is_tainted else HAIR_DARK

    for y in range(34, 61):
        for x in range(13, 49):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            if c[0] < 50 and c[1] < 50 and c[2] < 50:
                pix[x, y] = OUTLINE
                continue

            # 1. Legs & boots on left (x=13..19)
            if x <= 19:
                if x <= 16:
                    pix[x, y] = suit_green if c[0] > 195 else suit_green_dark
                elif x in (17, 18):
                    pix[x, y] = glove_light if c[0] > 195 else glove_mid
                else:
                    pix[x, y] = suit_dark
                continue

            # 2. Torso (y<=52, x=20..23) & resting arm/hand on ground (y=53..56, x=20..26)
            if (y <= 52 and x <= 23) or (53 <= y <= 56 and x <= 26):
                if y <= 52:
                    if x in (21, 22, 23) and y in (46, 47, 48):
                        pix[x, y] = emblem_center if (x == 22 and y == 47) else WHITE
                    elif x == 20 or y in (42, 43, 50, 51):
                        pix[x, y] = suit_dark
                    else:
                        pix[x, y] = suit_green
                else:
                    if x <= 21:
                        pix[x, y] = suit_green
                    else:
                        pix[x, y] = glove_light if c[0] > 180 else glove_mid
                continue

            # 3. Sideways Head (x=24..48, rotated 90 deg CW so crown hair is at right x=40..47)
            # Mouth teeth at x=32, y=46..50
            if x == 32 and 46 <= y <= 50:
                pix[x, y] = WHITE
                continue

            # Hair on crown (right side of rotated head: x >= 41, plus temple sweeps at top/bottom)
            is_hair = (
                x >= 41
                or (x == 40 and (y <= 43 or y >= 51 or y in (46, 47, 48)))
                or (x == 39 and (y <= 40 or y >= 54))
                or (x in (37, 38) and (y <= 38 or y >= 56))
            )
            if is_hair:
                if is_tainted and ((36 <= y <= 40) or (54 <= y <= 58)) and x <= 42:
                    pix[x, y] = WHITE if y in (38, 56) else THAL_HAIR_GREY
                elif x >= 43 and 42 <= y <= 51:
                    pix[x, y] = hair_light
                elif x >= 45 or y <= 37 or y >= 57:
                    pix[x, y] = hair_dark
                else:
                    pix[x, y] = hair_mid
                continue

            # Sculpted vertical Domino Mask framing both closed eyes (x=32..38, y=37..57)
            is_mask = (
                (33 <= x <= 37 and (37 <= y <= 44 or 51 <= y <= 57))
                or (34 <= x <= 36 and 45 <= y <= 50)
                or (x == 32 and (38 <= y <= 43 or 52 <= y <= 56))
                or (x == 38 and (39 <= y <= 42 or 53 <= y <= 55))
            )
            if is_mask:
                if x >= 36:
                    pix[x, y] = mask_bright
                elif x <= 33 or (45 <= y <= 50 and x == 34):
                    pix[x, y] = mask_dark
                else:
                    pix[x, y] = mask_mid
                continue

            # Forehead (x=38..40) and lower face / cheeks / chin skin (x=24..33)
            pix[x, y] = SKIN_LIGHT if c[0] > 195 else SKIN_BASE

    # Power ring on resting hand at (23, 55)
    pix[23, 55] = RING_GEM
    return out

def build_row256_f0(base_isaac, head_32, is_tainted=False):
    """(0, 256): Trapdoor startled pose with hands clasped in front of chest, standing."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    for hy in range(32):
        for hx in range(32):
            c = head_32.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c

    mask_dark = THAL_MASK_DARK if is_tainted else MASK_DARK
    for x in range(22, 42):
        if 22 <= x <= 28 or 35 <= x <= 41:
            pix[x, 39] = mask_dark
        else:
            pix[x, 39] = SKIN_LIGHT

    # Unconditionally clear neutral mouth & lower cheek mask droop (y=40..44)
    for y in range(40, 45):
        for x in range(22, 42):
            if 25 <= x <= 38:
                pix[x, y] = SKIN_LIGHT if y <= 41 else SKIN_BASE
            elif pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_BASE

    # Startled open mouth below mask bridge (x=29..34, y=40..42)
    for x in range(29, 35):
        pix[x, 40] = OUTLINE
        pix[x, 42] = OUTLINE
    pix[29, 41] = OUTLINE
    pix[34, 41] = OUTLINE
    for x in range(30, 34):
        pix[x, 41] = WHITE

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    for y in range(46, 57):
        for x in range(22, 42):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            if c[0] < 50:
                pix[x, y] = OUTLINE
            elif y in (47, 48, 49, 50):
                if x <= 26 or x >= 37:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = glove_light if c[0] > 195 else glove_mid
            elif y == 51:
                pix[x, y] = suit_dark
            elif y in (52, 53):
                pix[x, y] = boot_cuff
            elif y >= 54:
                pix[x, y] = suit_green

    pix[35, 48] = RING_GEM
    if is_tainted:
        pix[28, 48] = THAL_RING_GEM
    return out

def build_row256_f1(base_isaac, head_32, is_tainted=False):
    """(64, 256): Jump / JumpOut / Trapdoor mid-air curled ball pose."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    for hy in range(32):
        for hx in range(32):
            c = head_32.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c

    mask_dark = THAL_MASK_DARK if is_tainted else MASK_DARK
    for x in range(22, 42):
        if 22 <= x <= 28 or 35 <= x <= 41:
            pix[x, 39] = mask_dark
        else:
            pix[x, 39] = SKIN_LIGHT

    # Unconditionally clear neutral mouth & lower cheek mask droop (y=40..43)
    for y in range(40, 44):
        for x in range(22, 42):
            if 25 <= x <= 38:
                pix[x, y] = SKIN_LIGHT if y <= 41 else SKIN_BASE
            elif pix[x, y] != OUTLINE:
                pix[x, y] = SKIN_BASE

    # Startled/focused mouth below mask bridge (x=29..34, y=40..42)
    for x in range(29, 35):
        pix[x, 40] = OUTLINE
        pix[x, 42] = OUTLINE
    pix[29, 41] = OUTLINE
    pix[34, 41] = OUTLINE
    for x in range(30, 34):
        pix[x, 41] = WHITE

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    # Clear lower head chin pixels below y=44 where tucked body replaces them
    for y in range(44, 54):
        for x in range(18, 46):
            pix[x, y] = (0, 0, 0, 0)

    for y in range(43, 54):
        for x in range(20, 44):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            if y == 43:
                if 26 <= x <= 37 and c[0] < 50:
                    pix[x, y] = OUTLINE
                continue
            if y == 44 and (x <= 25 or x >= 38):
                if x in (24, 25, 38, 39):
                    pix[x, y] = OUTLINE
                continue
            if c[0] < 50:
                pix[x, y] = OUTLINE
            elif y in (45, 46, 47, 48):
                if x <= 26 or x >= 37:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = glove_light if c[0] > 195 else glove_mid
            elif y == 50:
                pix[x, y] = boot_cuff
            elif y == 51:
                pix[x, y] = suit_green
            elif y == 44:
                pix[x, y] = SKIN_BASE

    pix[35, 46] = RING_GEM
    if is_tainted:
        pix[28, 46] = THAL_RING_GEM
    return out

def build_row256_f2(base_isaac, head_32, is_tainted=False):
    """(128, 256): Jump rising/leaping pose with open smile and extended legs."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    smiling_head = build_smiling_head_32(head_32, is_tainted=is_tainted)
    for hy in range(32):
        for hx in range(32):
            c = smiling_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    suit_dark = THAL_SUIT_DARK if is_tainted else SUIT_BLACK
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    # Side arms strictly outside head cheek outlines (y=42..46)
    for y in range(42, 47):
        if y in (42, 43):
            x_cols = list(range(19, 23)) + list(range(41, 45))
        elif y == 44:
            x_cols = list(range(19, 24)) + list(range(40, 45))
        elif y == 45:
            x_cols = list(range(19, 25)) + list(range(39, 45))
        else:
            x_cols = list(range(19, 26)) + list(range(38, 45))
        for x in x_cols:
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            if c[0] < 50:
                pix[x, y] = OUTLINE
            elif y == 43:
                pix[x, y] = glove_light
            elif y == 44:
                pix[x, y] = glove_light if c[0] > 195 else glove_mid
            else:
                pix[x, y] = suit_green

    pix[42, 43] = RING_GEM
    if is_tainted:
        pix[21, 43] = THAL_RING_GEM

    # Leaping torso & extended legs (y=47..55, x=23..40)
    for y in range(47, 56):
        for x in range(23, 41):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            is_old_chin_outline = (y == 47 and 28 <= x <= 35)
            if c[0] < 50 and not is_old_chin_outline:
                pix[x, y] = OUTLINE
            elif y in (47, 48, 49, 50):
                if x in (30, 31, 32, 33) and y in (48, 49):
                    pix[x, y] = emblem_center if (x in (31, 32) and y == 49) else WHITE
                elif 26 <= x <= 37:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = suit_dark
            elif y in (51, 52):
                pix[x, y] = boot_cuff
            elif y >= 53:
                pix[x, y] = suit_green

    return out

def build_row256_f3(base_isaac, head_32, is_tainted=False):
    """(192, 256): Jump landing squash pose with spread hands and wide stance."""
    out = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    pix = out.load()

    smiling_head = build_smiling_head_32(head_32, is_tainted=is_tainted)
    for hy in range(32):
        for hx in range(32):
            c = smiling_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 23] = c

    suit_green = THAL_SUIT_GREEN if is_tainted else SUIT_GREEN
    emblem_center = THAL_MASK_BRIGHT if is_tainted else SUIT_GREEN
    glove_light = THAL_GLOVE_LIGHT if is_tainted else WHITE
    glove_mid = THAL_GLOVE_MID if is_tainted else GLOVE_SHADOW
    boot_cuff = THAL_GLOVE_MID if is_tainted else WHITE

    # Spread arms at sides strictly outside cheek outlines (y=42..48)
    for y in range(42, 49):
        if y == 42:
            x_cols = [18, 19, 44, 45]
        elif y in (43, 44):
            x_cols = list(range(17, 21)) + list(range(43, 47))
        elif y == 45:
            x_cols = list(range(17, 22)) + list(range(42, 47))
        elif y == 46:
            x_cols = list(range(18, 23)) + list(range(41, 46))
        elif y == 47:
            x_cols = list(range(19, 25)) + list(range(39, 45))
        else:
            x_cols = list(range(20, 26)) + list(range(38, 44))
        for x in x_cols:
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                if y == 48 and x in (23, 40):
                    pix[x, y] = OUTLINE
                continue
            if c[0] < 50 or (y == 46 and x in (22, 41)):
                pix[x, y] = OUTLINE
            elif x <= 20 or x >= 43:
                pix[x, y] = glove_light if c[0] > 195 else glove_mid
            else:
                pix[x, y] = suit_green

    pix[44, 44] = RING_GEM
    if is_tainted:
        pix[19, 44] = THAL_RING_GEM

    # Squashed torso & wide boots (y=49..54, x=22..41)
    for y in range(49, 55):
        for x in range(22, 42):
            c = base_isaac.getpixel((x, y))
            if c[3] == 0:
                continue
            is_old_chin_outline = (
                (y == 49 and 26 <= x <= 37)
                or (y == 50 and 29 <= x <= 34)
            )
            if c[0] < 50 and not is_old_chin_outline:
                pix[x, y] = OUTLINE
            elif y == 49:
                if x in (30, 31, 32, 33):
                    pix[x, y] = emblem_center if x in (31, 32) else WHITE
                else:
                    pix[x, y] = suit_green
            elif y in (50, 51):
                if y == 50 and 29 <= x <= 34:
                    pix[x, y] = suit_green
                else:
                    pix[x, y] = boot_cuff
            elif y >= 52:
                pix[x, y] = suit_green

    return out

def build_glitch_heads(head_32):
    """
    Generates all 7 32x32 Glitch animation head cells at:
    (16, 336), (48, 336), (80, 336), (16, 368), (48, 368), (80, 368), (16, 400)
    using the exact quadrant/slice glitch transformations of 001.000_player.anm2.
    """
    tl = head_32.crop((0, 0, 16, 16))
    tr = head_32.crop((16, 0, 32, 16))
    bl = head_32.crop((0, 16, 16, 32))
    br = head_32.crop((16, 16, 32, 32))
    top_half = head_32.crop((0, 0, 32, 16))
    bot_half = head_32.crop((0, 16, 32, 32))

    g0 = head_32.copy()

    g1 = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    g1.paste(tl, (0, 0))
    g1.paste(bl, (0, 16))
    g1.paste(br, (16, 16))

    g2 = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    g2.paste(tl, (0, 0))
    g2.paste(br, (16, 0))
    g2.paste(br, (0, 16))
    g2.paste(br, (16, 16))

    g3 = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    g3.paste(br, (0, 0))
    g3.paste(tr, (16, 0))
    g3.paste(bot_half.transpose(Image.FLIP_TOP_BOTTOM), (0, 16))

    g4 = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    g4.paste(br, (0, 0))
    g4.paste(tl, (16, 0))
    g4.paste(bl.transpose(Image.FLIP_TOP_BOTTOM), (0, 16))
    g4.paste(bl, (16, 16))

    g5 = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    g5_top = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    g5_top.paste(tl, (0, 0))
    g5_top.paste(br.transpose(Image.FLIP_TOP_BOTTOM), (16, 0))
    g5.paste(g5_top, (0, 0))
    g5.paste(g5_top.transpose(Image.FLIP_TOP_BOTTOM), (0, 16))

    g6 = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    g6.paste(bot_half, (0, 0))
    g6.paste(top_half, (0, 16))

    return {
        (16, 336): g0,
        (48, 336): g1,
        (80, 336): g2,
        (16, 368): g3,
        (48, 368): g4,
        (80, 368): g5,
        (16, 400): g6,
    }

def composite_pickupwalk_frame(head64, body32, flip_body=True):
    """
    Simulates 001.000_player.anm2 composite for PickupWalk*:
    - Layer 4 (head): 64x64 at XPos=0, YPos=-5, XPiv=32, YPiv=44
    - Layer 12 (extra): 32x32 at XPos=0, YPos=2, XPiv=16, YPiv=25 (rendered ON TOP of Layer 4)
    """
    canvas = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    canvas.paste(head64, (0, 6), head64)
    b = body32.transpose(Image.FLIP_LEFT_RIGHT) if flip_body else body32
    canvas.paste(b, (16, 32), b)
    return canvas

def generate_all_and_apply(apply_to_sheets=False):
    isaac = Image.open('C:/Program Files (x86)/Steam/steamapps/common/The Binding of Isaac Rebirth/extracted_resources/resources/gfx/characters/costumes/Character_001_Isaac.png').convert('RGBA')
    hal = Image.open('resources/gfx/characters/hal_jordan.png').convert('RGBA')
    thal = Image.open('resources/gfx/characters/tainted_hal.png').convert('RGBA')

    hal_head = hal.crop((0, 0, 32, 32))
    thal_head = thal.crop((0, 0, 32, 32))

    # --- ROW 128 (Death Scream, Happy Thumbs-Up 1, Happy Thumbs-Up 2, Sideways Appear/Death) ---
    isaac_r128 = [isaac.crop((x, 128, x + 64, 192)) for x in (0, 64, 128, 192)]
    hal_r128 = [
        build_row128_f0(isaac_r128[0], hal_head, is_tainted=False),
        build_row128_f1(isaac_r128[1], hal_head, is_tainted=False),
        build_row128_f2(isaac_r128[2], hal_head, is_tainted=False),
        build_row128_f3(isaac_r128[3], is_tainted=False),
    ]
    thal_r128 = [
        build_row128_f0(isaac_r128[0], thal_head, is_tainted=True),
        build_row128_f1(isaac_r128[1], thal_head, is_tainted=True),
        build_row128_f2(isaac_r128[2], thal_head, is_tainted=True),
        build_row128_f3(isaac_r128[3], is_tainted=True),
    ]

    hal_strip_128 = Image.new('RGBA', (256, 64), (0, 0, 0, 0))
    thal_strip_128 = Image.new('RGBA', (256, 64), (0, 0, 0, 0))
    for i in range(4):
        hal_strip_128.paste(hal_r128[i], (i * 64, 0))
        thal_strip_128.paste(thal_r128[i], (i * 64, 0))

    # --- ROW 192 (Stationary Pickup Anticipation, Pickup Hold, Hit, Sad) ---
    isaac_f0 = isaac.crop((0, 192, 64, 256))
    isaac_f1 = isaac.crop((64, 192, 128, 256))
    isaac_f2 = isaac.crop((128, 192, 192, 256))
    isaac_f3 = isaac.crop((192, 192, 256, 256))

    hal_f0 = build_hal_f0(isaac_f0, hal_head)
    hal_f1 = build_hal_f1(isaac_f1, hal_head)
    hal_f2 = build_hal_f2(isaac_f2)
    hal_f3 = build_hal_f3(isaac_f3)

    thal_f0 = build_thal_f0(isaac_f0, thal_head)
    thal_f1 = build_thal_f1(isaac_f1, thal_head)
    thal_f2 = build_thal_f2(isaac_f2)
    thal_f3 = build_thal_f3(isaac_f3)

    hal_strip = Image.new('RGBA', (256, 64), (0, 0, 0, 0))
    hal_strip.paste(hal_f0, (0, 0))
    hal_strip.paste(hal_f1, (64, 0))
    hal_strip.paste(hal_f2, (128, 0))
    hal_strip.paste(hal_f3, (192, 0))

    thal_strip = Image.new('RGBA', (256, 64), (0, 0, 0, 0))
    thal_strip.paste(thal_f0, (0, 0))
    thal_strip.paste(thal_f1, (64, 0))
    thal_strip.paste(thal_f2, (128, 0))
    thal_strip.paste(thal_f3, (192, 0))

    # --- ROW 256 (Trapdoor Clasped, Jump Curled Ball, Jump Leap, Jump Squash) ---
    isaac_r256 = [isaac.crop((x, 256, x + 64, 320)) for x in (0, 64, 128, 192)]
    hal_r256 = [
        build_row256_f0(isaac_r256[0], hal_head, is_tainted=False),
        build_row256_f1(isaac_r256[1], hal_head, is_tainted=False),
        build_row256_f2(isaac_r256[2], hal_head, is_tainted=False),
        build_row256_f3(isaac_r256[3], hal_head, is_tainted=False),
    ]
    thal_r256 = [
        build_row256_f0(isaac_r256[0], thal_head, is_tainted=True),
        build_row256_f1(isaac_r256[1], thal_head, is_tainted=True),
        build_row256_f2(isaac_r256[2], thal_head, is_tainted=True),
        build_row256_f3(isaac_r256[3], thal_head, is_tainted=True),
    ]

    hal_strip_256 = Image.new('RGBA', (256, 64), (0, 0, 0, 0))
    thal_strip_256 = Image.new('RGBA', (256, 64), (0, 0, 0, 0))
    for i in range(4):
        hal_strip_256.paste(hal_r256[i], (i * 64, 0))
        thal_strip_256.paste(thal_r256[i], (i * 64, 0))

    # --- Celebratory smiling heads at (256, 0, 288, 32) and (256, 128, 320, 192) ---
    hal_smile_32 = build_smiling_head_32(hal_head, is_tainted=False)
    hal_smile_64 = build_smiling_head_64(hal_smile_32)

    thal_smile_32 = build_smiling_head_32(thal_head, is_tainted=True)
    thal_smile_64 = build_smiling_head_64(thal_smile_32)

    # --- All 20 PickupWalk 32x32 body cells in X=256..512, Y=0..128 ---
    down_up_coords = [
        (448, 0), (480, 0),
        (256, 32), (288, 32), (320, 32), (352, 32), (384, 32), (416, 32), (448, 32), (480, 32)
    ]
    side_coords = [
        (256, 64), (288, 64), (320, 64), (352, 64), (384, 64), (416, 64), (448, 64), (480, 64),
        (256, 96), (288, 96)
    ]

    hal_pickupwalk_bodies = {}
    thal_pickupwalk_bodies = {}

    for (cx, cy) in down_up_coords:
        base_cell = isaac.crop((cx, cy, cx + 32, cy + 32))
        hal_pickupwalk_bodies[(cx, cy)] = build_hal_pickupwalk_body(base_cell, is_side=False)
        thal_pickupwalk_bodies[(cx, cy)] = build_thal_pickupwalk_body(base_cell, is_side=False)

    for (cx, cy) in side_coords:
        base_cell = isaac.crop((cx, cy, cx + 32, cy + 32))
        hal_pickupwalk_bodies[(cx, cy)] = build_hal_pickupwalk_body(base_cell, is_side=True)
        thal_pickupwalk_bodies[(cx, cy)] = build_thal_pickupwalk_body(base_cell, is_side=True)

    # --- 7 Glitch animation head cells in X=0..112, Y=320..448 ---
    hal_glitch_heads = build_glitch_heads(hal_head)
    thal_glitch_heads = build_glitch_heads(thal_head)

    brain_dir = r'C:/Users/danic/.gemini/antigravity/brain/25a8c9be-14f1-4e9c-8c5f-e17d8ccace13'
    os.makedirs(brain_dir, exist_ok=True)
    hal_strip.save(os.path.join(brain_dir, 'hal_row192_complete_strip.png'))
    thal_strip.save(os.path.join(brain_dir, 'thal_row192_complete_strip.png'))

    # Complete verification preview showing Row 128, Row 192, Row 256, and PickupWalk
    # Layout: 12 columns (4 cols Row 128 | 4 cols Row 192 | 4 cols Row 256) x 3 rows (Isaac, Hal, Tainted Hal)
    # Plus a 4th & 5th row showing PickupWalk composites for Hal and Tainted Hal!
    all_preview = Image.new('RGBA', (64 * 12, 64 * 5), (24, 26, 30, 255))

    # Row 0: Vanilla Isaac (Row 128, Row 192, Row 256)
    isaac_r192 = [isaac_f0, isaac_f1, isaac_f2, isaac_f3]
    for i in range(4):
        all_preview.paste(isaac_r128[i], (i * 64, 0), isaac_r128[i])
        all_preview.paste(isaac_r192[i], ((i + 4) * 64, 0), isaac_r192[i])
        all_preview.paste(isaac_r256[i], ((i + 8) * 64, 0), isaac_r256[i])

    # Row 1: Hal Jordan (Row 128, Row 192, Row 256)
    hal_r192 = [hal_f0, hal_f1, hal_f2, hal_f3]
    for i in range(4):
        all_preview.paste(hal_r128[i], (i * 64, 64), hal_r128[i])
        all_preview.paste(hal_r192[i], ((i + 4) * 64, 64), hal_r192[i])
        all_preview.paste(hal_r256[i], ((i + 8) * 64, 64), hal_r256[i])

    # Row 2: Tainted Hal (Row 128, Row 192, Row 256)
    thal_r192 = [thal_f0, thal_f1, thal_f2, thal_f3]
    for i in range(4):
        all_preview.paste(thal_r128[i], (i * 64, 128), thal_r128[i])
        all_preview.paste(thal_r192[i], ((i + 4) * 64, 128), thal_r192[i])
        all_preview.paste(thal_r256[i], ((i + 8) * 64, 128), thal_r256[i])

    # Rows 3 & 4: PickupWalk composites (Hal & Tainted Hal)
    hal_pw_cols = [
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(256, 32)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(288, 32)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(320, 32)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(352, 32)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(384, 32)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(448, 0)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(256, 64)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(288, 64)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(320, 64)], flip_body=True),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(384, 64)], flip_body=False),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(448, 64)], flip_body=False),
        composite_pickupwalk_frame(hal_smile_64, hal_pickupwalk_bodies[(256, 96)], flip_body=False),
    ]
    thal_pw_cols = [
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(256, 32)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(288, 32)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(320, 32)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(352, 32)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(384, 32)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(448, 0)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(256, 64)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(288, 64)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(320, 64)], flip_body=True),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(384, 64)], flip_body=False),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(448, 64)], flip_body=False),
        composite_pickupwalk_frame(thal_smile_64, thal_pickupwalk_bodies[(256, 96)], flip_body=False),
    ]
    for col_idx, frame_img in enumerate(hal_pw_cols):
        all_preview.paste(frame_img, (col_idx * 64, 192), frame_img)
    for col_idx, frame_img in enumerate(thal_pw_cols):
        all_preview.paste(frame_img, (col_idx * 64, 256), frame_img)

    all_zoom = all_preview.resize((all_preview.width * 4, all_preview.height * 4), Image.NEAREST)
    all_zoom_path = os.path.join(brain_dir, 'all_rows_complete_preview_zoom4x.png')
    all_zoom.save(all_zoom_path)
    print(f'Generated {all_zoom_path}')

    if apply_to_sheets:
        blank_glitch_region = Image.new('RGBA', (112, 128), (0, 0, 0, 0))
        # Hal Jordan
        for path in ['resources/gfx/characters/hal_jordan.png', 'resources/gfx/characters/hal_jordan_extra.png']:
            img = Image.open(path).convert('RGBA')
            img.paste(hal_strip_128, (0, 128))
            img.paste(hal_strip, (0, 192))
            img.paste(hal_strip_256, (0, 256))
            img.paste(hal_smile_32, (256, 0))
            img.paste(hal_smile_64, (256, 128))
            for (cx, cy), body_cell in hal_pickupwalk_bodies.items():
                img.paste(body_cell, (cx, cy))
            img.paste(blank_glitch_region, (0, 320))
            for (gx, gy), g_cell in hal_glitch_heads.items():
                img.paste(g_cell, (gx, gy))
            img.save(path)
            print(f'Updated {path}')

        # Tainted Hal
        for path in ['resources/gfx/characters/tainted_hal.png', 'resources/gfx/characters/tainted_hal_extra.png']:
            img = Image.open(path).convert('RGBA')
            img.paste(thal_strip_128, (0, 128))
            img.paste(thal_strip, (0, 192))
            img.paste(thal_strip_256, (0, 256))
            img.paste(thal_smile_32, (256, 0))
            img.paste(thal_smile_64, (256, 128))
            for (cx, cy), body_cell in thal_pickupwalk_bodies.items():
                img.paste(body_cell, (cx, cy))
            img.paste(blank_glitch_region, (0, 320))
            for (gx, gy), g_cell in thal_glitch_heads.items():
                img.paste(g_cell, (gx, gy))
            img.save(path)
            print(f'Updated {path}')

if __name__ == '__main__':
    generate_all_and_apply(apply_to_sheets=True)
