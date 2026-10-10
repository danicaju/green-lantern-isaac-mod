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

def build_hal_f0(base_isaac_f0, hal_head):
    out = Image.new('RGBA', (64, 64), (0,0,0,0))
    pix = out.load()
    
    # Place Hal head (centered at 16, 22)
    for hy in range(32):
        for hx in range(32):
            c = hal_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 22] = c
                
    # Mouth looking up in wonder (O-shaped open mouth)
    o_mouth = [
        (40, 31, OUTLINE), (40, 32, OUTLINE),
        (41, 30, OUTLINE), (41, 31, WHITE), (41, 32, WHITE), (41, 33, OUTLINE),
        (42, 30, OUTLINE), (42, 31, (40,15,15,255)), (42, 32, (40,15,15,255)), (42, 33, OUTLINE),
        (43, 31, OUTLINE), (43, 32, OUTLINE)
    ]
    for y, x, color in o_mouth:
        pix[x, y] = color
        
    # Torso & squatting legs from base_isaac_f0
    for y in range(46, 57):
        for x in range(16, 48):
            c = base_isaac_f0.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif y in [52, 53, 54, 55, 56]:
                    if y >= 54:
                        pix[x, y] = SUIT_GREEN
                    else:
                        pix[x, y] = WHITE
                else:
                    if x in range(28, 36) and y in [47, 48, 49]:
                        if x in [31, 32] and y == 48:
                            pix[x, y] = SUIT_GREEN
                        else:
                            pix[x, y] = WHITE
                    elif x in range(26, 38):
                        pix[x, y] = SUIT_GREEN
                    else:
                        pix[x, y] = SUIT_BLACK

    # Low anticipation hands at sides
    for y in range(48, 52):
        for x in range(18, 22):
            c = base_isaac_f0.getpixel((x, y))
            if c[3] > 0:
                pix[x, y] = OUTLINE if c[0] < 50 else (WHITE if c[0] > 180 else GLOVE_SHADOW)
        for x in range(42, 46):
            c = base_isaac_f0.getpixel((x, y))
            if c[3] > 0:
                pix[x, y] = OUTLINE if c[0] < 50 else (WHITE if c[0] > 180 else GLOVE_SHADOW)

    return out

def build_hal_f1(base_isaac_f1, hal_head):
    out = Image.new('RGBA', (64, 64), (0,0,0,0))
    pix = out.load()
    
    # 1. Base head from Hal (at 16, 21)
    for hy in range(32):
        for hx in range(32):
            c = hal_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c
                
    # 2. Add celebratory open smile with white teeth
    smile_pixels = [
        (39, 29, OUTLINE), (39, 30, OUTLINE), (39, 31, OUTLINE), (39, 32, OUTLINE), (39, 33, OUTLINE), (39, 34, OUTLINE),
        (40, 29, OUTLINE), (40, 30, WHITE),   (40, 31, WHITE),   (40, 32, WHITE),   (40, 33, WHITE),   (40, 34, OUTLINE),
        (41, 29, OUTLINE), (41, 30, (40,15,15,255)), (41, 31, (40,15,15,255)), (41, 32, (40,15,15,255)), (41, 33, (40,15,15,255)), (41, 34, OUTLINE),
        (42, 30, OUTLINE), (42, 31, OUTLINE), (42, 32, OUTLINE), (42, 33, OUTLINE)
    ]
    for y, x, color in smile_pixels:
        pix[x, y] = color
        
    # 3. Body: Torso (Y=46..51) & Legs (Y=52..56)
    for y in range(46, 57):
        for x in range(20, 44):
            c = base_isaac_f1.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif y in [52, 53, 54, 55, 56]:
                    if y >= 54:
                        pix[x, y] = SUIT_GREEN
                    else:
                        pix[x, y] = WHITE
                else:
                    if x in [30, 31, 32, 33] and y in [47, 48, 49]:
                        if (x in [31, 32] and y == 48):
                            pix[x, y] = SUIT_GREEN
                        else:
                            pix[x, y] = WHITE
                    elif x in range(27, 37):
                        pix[x, y] = SUIT_GREEN
                    else:
                        pix[x, y] = SUIT_BLACK

    # 4. Arms directly from Isaac geometry
    for y in range(34, 47):
        # Left Arm
        for x in range(17, 25):
            c = base_isaac_f1.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif y >= 44:
                    pix[x, y] = SUIT_BLACK if x >= 22 else SUIT_GREEN_DARK
                elif y >= 42:
                    pix[x, y] = SUIT_GREEN if x in [20, 21] else SUIT_GREEN_DARK
                else:
                    if c[0] > 210: pix[x, y] = WHITE
                    elif c[0] > 180: pix[x, y] = GLOVE_SHADOW
                    else: pix[x, y] = GLOVE_DARK
        # Right Arm
        for x in range(39, 47):
            c = base_isaac_f1.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif x == 43 and y == 37:
                    pix[x, y] = RING_GEM
                elif x in [42, 44] and y == 37:
                    pix[x, y] = RING_BAND
                elif y >= 44:
                    pix[x, y] = SUIT_BLACK if x <= 41 else SUIT_GREEN_DARK
                elif y >= 42:
                    pix[x, y] = SUIT_GREEN if x in [42, 43] else SUIT_GREEN_DARK
                else:
                    if c[0] > 210: pix[x, y] = WHITE
                    elif c[0] > 180: pix[x, y] = GLOVE_SHADOW
                    else: pix[x, y] = GLOVE_DARK

    return out

def build_hal_f2(base_f2):
    f2 = base_f2.copy()
    pix = f2.load()

    # Brow arches of Green Domino Mask
    pix[25, 37] = MASK_BRIGHT
    pix[26, 36] = MASK_BRIGHT
    pix[27, 36] = MASK_BRIGHT
    pix[28, 36] = MASK_BRIGHT
    pix[29, 37] = MASK_BRIGHT
    pix[30, 37] = MASK_MID

    # Bridge between eyes
    pix[31, 37] = MASK_MID
    pix[32, 38] = MASK_MID
    pix[33, 38] = MASK_MID
    pix[34, 38] = MASK_MID
    pix[35, 38] = MASK_MID
    pix[36, 37] = MASK_MID

    # Right brow
    pix[37, 37] = MASK_BRIGHT
    pix[38, 37] = MASK_BRIGHT
    pix[39, 36] = MASK_BRIGHT
    pix[40, 36] = MASK_BRIGHT
    pix[41, 36] = MASK_BRIGHT
    pix[42, 37] = MASK_BRIGHT
    pix[43, 37] = MASK_BRIGHT

    # Temple wings
    pix[22, 37] = MASK_MID
    pix[23, 37] = MASK_MID
    pix[24, 37] = MASK_MID

    pix[44, 37] = MASK_MID
    pix[45, 37] = MASK_MID

    for x in range(25, 31):
        pix[x, 37] = MASK_MID
    for x in range(37, 44):
        pix[x, 37] = MASK_MID

    # Y=38: surrounding the eye creases
    pix[22, 38] = MASK_MID
    pix[23, 38] = MASK_MID
    pix[24, 38] = MASK_MID
    for x in range(25, 30):
        pix[x, 38] = MASK_MID
    pix[30, 38] = MASK_MID
    pix[31, 38] = MASK_DARK

    pix[36, 38] = MASK_DARK
    pix[37, 38] = MASK_MID
    for x in range(38, 43):
        pix[x, 38] = MASK_MID
    pix[43, 38] = MASK_MID
    pix[44, 38] = MASK_MID

    # Y=39: Wing edges and eye slit frame (slits stay black outline)
    pix[21, 39] = MASK_MID
    pix[22, 39] = MASK_MID
    pix[23, 39] = MASK_DARK
    pix[24, 39] = MASK_DARK
    pix[30, 39] = MASK_DARK
    pix[31, 39] = MASK_DARK

    pix[36, 39] = MASK_DARK
    pix[37, 39] = MASK_DARK
    pix[43, 39] = MASK_DARK
    pix[44, 39] = MASK_MID
    pix[45, 39] = MASK_MID

    # Y=40: Under eye cheek wrap (leaves teardrop at 40..42 intact)
    for x in range(23, 30):
        pix[x, 40] = MASK_DARK
    pix[30, 40] = MASK_DARK

    pix[37, 40] = MASK_DARK
    pix[38, 40] = MASK_DARK
    pix[39, 40] = MASK_DARK
    pix[43, 40] = MASK_DARK

    # Hal Right Fist with Power Ring at (40, 44)
    pix[38, 44] = GLOVE_SHADOW
    pix[39, 44] = WHITE
    pix[40, 44] = RING_GEM
    pix[41, 44] = WHITE
    pix[42, 44] = GLOVE_SHADOW

    return f2

def build_hal_f3(base_f3):
    f3 = base_f3.copy()
    pix = f3.load()

    # 1. Clean forehead at Y=38: restore forehead skin (no isolated green eyebrows)
    for x in range(21, 43):
        c = f3.getpixel((x, 38))
        if c[1] > 140 and c[0] < 80:
            pix[x, 38] = SKIN_BASE if (x in [21, 42]) else SKIN_LIGHT

    # 2. Draw full Green Domino Mask framing the eyes (Y=41..47)
    for x in range(21, 29):
        pix[x, 41] = MASK_BRIGHT
        pix[x, 42] = MASK_MID
    for x in range(35, 43):
        pix[x, 41] = MASK_BRIGHT
        pix[x, 42] = MASK_MID
    for x in range(28, 36):
        pix[x, 42] = MASK_MID
        pix[x, 43] = MASK_DARK

    for y in range(43, 47):
        pix[20, y] = MASK_MID
        pix[21, y] = MASK_MID
        pix[42, y] = MASK_MID
        pix[43, y] = MASK_MID

    for x in range(22, 28):
        pix[x, 47] = MASK_DARK
    for x in range(36, 42):
        pix[x, 47] = MASK_DARK

    # Tears running down cheeks from the mask
    pix[21, 46] = (156, 200, 204, 255)
    pix[21, 47] = (156, 200, 204, 255)
    pix[42, 46] = (156, 200, 204, 255)
    pix[42, 47] = (156, 200, 204, 255)

    return f3

def build_thal_f0(base_isaac_f0, thal_head):
    out = Image.new('RGBA', (64, 64), (0,0,0,0))
    pix = out.load()
    
    for hy in range(32):
        for hx in range(32):
            c = thal_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 22] = c
                
    o_mouth = [
        (40, 31, OUTLINE), (40, 32, OUTLINE),
        (41, 30, OUTLINE), (41, 31, WHITE), (41, 32, WHITE), (41, 33, OUTLINE),
        (42, 30, OUTLINE), (42, 31, (40,15,15,255)), (42, 32, (40,15,15,255)), (42, 33, OUTLINE),
        (43, 31, OUTLINE), (43, 32, OUTLINE)
    ]
    for y, x, color in o_mouth:
        pix[x, y] = color
        
    for y in range(46, 57):
        for x in range(16, 48):
            c = base_isaac_f0.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif y in [52, 53, 54, 55, 56]:
                    pix[x, y] = THAL_SUIT_GREEN if y >= 54 else THAL_GLOVE_MID
                else:
                    if x in range(28, 36) and y in [47, 48, 49]:
                        pix[x, y] = THAL_MASK_BRIGHT if (x in [31, 32] and y == 48) else WHITE
                    elif x in range(26, 38):
                        pix[x, y] = THAL_SUIT_GREEN
                    else:
                        pix[x, y] = THAL_SUIT_DARK

    for y in range(48, 52):
        for x in range(18, 22):
            c = base_isaac_f0.getpixel((x, y))
            if c[3] > 0:
                pix[x, y] = OUTLINE if c[0] < 50 else (THAL_GLOVE_LIGHT if c[0] > 180 else THAL_GLOVE_MID)
        for x in range(42, 46):
            c = base_isaac_f0.getpixel((x, y))
            if c[3] > 0:
                pix[x, y] = OUTLINE if c[0] < 50 else (THAL_GLOVE_LIGHT if c[0] > 180 else THAL_GLOVE_MID)

    return out

def build_thal_f1(base_isaac_f1, thal_head):
    out = Image.new('RGBA', (64, 64), (0,0,0,0))
    pix = out.load()
    
    for hy in range(32):
        for hx in range(32):
            c = thal_head.getpixel((hx, hy))
            if c[3] > 0:
                pix[hx + 16, hy + 21] = c
                
    smile_pixels = [
        (39, 29, OUTLINE), (39, 30, OUTLINE), (39, 31, OUTLINE), (39, 32, OUTLINE), (39, 33, OUTLINE), (39, 34, OUTLINE),
        (40, 29, OUTLINE), (40, 30, WHITE),   (40, 31, WHITE),   (40, 32, WHITE),   (40, 33, WHITE),   (40, 34, OUTLINE),
        (41, 29, OUTLINE), (41, 30, (40,15,15,255)), (41, 31, (40,15,15,255)), (41, 32, (40,15,15,255)), (41, 33, (40,15,15,255)), (41, 34, OUTLINE),
        (42, 30, OUTLINE), (42, 31, OUTLINE), (42, 32, OUTLINE), (42, 33, OUTLINE)
    ]
    for y, x, color in smile_pixels:
        pix[x, y] = color
        
    for y in range(46, 57):
        for x in range(20, 44):
            c = base_isaac_f1.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif y in [52, 53, 54, 55, 56]:
                    pix[x, y] = THAL_SUIT_GREEN if y >= 54 else THAL_GLOVE_MID
                else:
                    if x in [30, 31, 32, 33] and y in [47, 48, 49]:
                        pix[x, y] = THAL_MASK_BRIGHT if (x in [31, 32] and y == 48) else WHITE
                    elif x in range(27, 37):
                        pix[x, y] = THAL_SUIT_GREEN
                    else:
                        pix[x, y] = THAL_SUIT_DARK

    for y in range(34, 47):
        # Left Arm (Yellow Fear Ring on middle finger)
        for x in range(17, 25):
            c = base_isaac_f1.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif x == 20 and y == 37:
                    pix[x, y] = THAL_RING_GEM
                elif x in [19, 21] and y == 37:
                    pix[x, y] = THAL_RING_YELLOW
                elif y >= 44:
                    pix[x, y] = THAL_SUIT_DARK if x >= 22 else THAL_MASK_DARK
                elif y >= 42:
                    pix[x, y] = THAL_SUIT_GREEN if x in [20, 21] else THAL_MASK_DARK
                else:
                    if c[0] > 210: pix[x, y] = THAL_GLOVE_LIGHT
                    elif c[0] > 180: pix[x, y] = THAL_GLOVE_MID
                    else: pix[x, y] = THAL_GLOVE_DARK
        # Right Arm (Emerald Ring)
        for x in range(39, 47):
            c = base_isaac_f1.getpixel((x, y))
            if c[3] > 0:
                if c[0] < 50:
                    pix[x, y] = OUTLINE
                elif x == 43 and y == 37:
                    pix[x, y] = RING_GEM
                elif x in [42, 44] and y == 37:
                    pix[x, y] = RING_BAND
                elif y >= 44:
                    pix[x, y] = THAL_SUIT_DARK if x <= 41 else THAL_MASK_DARK
                elif y >= 42:
                    pix[x, y] = THAL_SUIT_GREEN if x in [42, 43] else THAL_MASK_DARK
                else:
                    if c[0] > 210: pix[x, y] = THAL_GLOVE_LIGHT
                    elif c[0] > 180: pix[x, y] = THAL_GLOVE_MID
                    else: pix[x, y] = THAL_GLOVE_DARK

    return out

def build_thal_f2(base_f2):
    f2 = base_f2.copy()
    pix = f2.load()

    pix[25, 37] = THAL_MASK_BRIGHT
    pix[26, 36] = THAL_MASK_BRIGHT
    pix[27, 36] = THAL_MASK_BRIGHT
    pix[28, 36] = THAL_MASK_BRIGHT
    pix[29, 37] = THAL_MASK_BRIGHT
    pix[30, 37] = THAL_MASK_MID

    pix[31, 37] = THAL_MASK_MID
    pix[32, 38] = THAL_MASK_MID
    pix[33, 38] = THAL_MASK_MID
    pix[34, 38] = THAL_MASK_MID
    pix[35, 38] = THAL_MASK_MID
    pix[36, 37] = THAL_MASK_MID

    pix[37, 37] = THAL_MASK_BRIGHT
    pix[38, 37] = THAL_MASK_BRIGHT
    pix[39, 36] = THAL_MASK_BRIGHT
    pix[40, 36] = THAL_MASK_BRIGHT
    pix[41, 36] = THAL_MASK_BRIGHT
    pix[42, 37] = THAL_MASK_BRIGHT
    pix[43, 37] = THAL_MASK_BRIGHT

    pix[22, 37] = THAL_MASK_MID
    pix[23, 37] = THAL_MASK_MID
    pix[24, 37] = THAL_MASK_MID

    pix[44, 37] = THAL_MASK_MID
    pix[45, 37] = THAL_MASK_MID

    for x in range(25, 31):
        pix[x, 37] = THAL_MASK_MID
    for x in range(37, 44):
        pix[x, 37] = THAL_MASK_MID

    pix[22, 38] = THAL_MASK_MID
    pix[23, 38] = THAL_MASK_MID
    pix[24, 38] = THAL_MASK_MID
    for x in range(25, 30):
        pix[x, 38] = THAL_MASK_MID
    pix[30, 38] = THAL_MASK_MID
    pix[31, 38] = THAL_MASK_DARK

    pix[36, 38] = THAL_MASK_DARK
    pix[37, 38] = THAL_MASK_MID
    for x in range(38, 43):
        pix[x, 38] = THAL_MASK_MID
    pix[43, 38] = THAL_MASK_MID
    pix[44, 38] = THAL_MASK_MID

    pix[21, 39] = THAL_MASK_MID
    pix[22, 39] = THAL_MASK_MID
    pix[23, 39] = THAL_MASK_DARK
    pix[24, 39] = THAL_MASK_DARK
    pix[30, 39] = THAL_MASK_DARK
    pix[31, 39] = THAL_MASK_DARK

    pix[36, 39] = THAL_MASK_DARK
    pix[37, 39] = THAL_MASK_DARK
    pix[43, 39] = THAL_MASK_DARK
    pix[44, 39] = THAL_MASK_MID
    pix[45, 39] = THAL_MASK_MID

    for x in range(23, 30):
        pix[x, 40] = THAL_MASK_DARK
    pix[30, 40] = THAL_MASK_DARK

    pix[37, 40] = THAL_MASK_DARK
    pix[38, 40] = THAL_MASK_DARK
    pix[39, 40] = THAL_MASK_DARK
    pix[43, 40] = THAL_MASK_DARK

    pix[38, 44] = THAL_GLOVE_MID
    pix[39, 44] = THAL_GLOVE_LIGHT
    pix[40, 44] = RING_GEM
    pix[41, 44] = THAL_GLOVE_LIGHT
    pix[42, 44] = THAL_GLOVE_MID

    return f2

def build_thal_f3(base_f3):
    f3 = base_f3.copy()
    pix = f3.load()

    for x in range(21, 43):
        c = f3.getpixel((x, 38))
        if c[1] > 60 and c[0] < 60:
            pix[x, 38] = SKIN_BASE if (x in [21, 42]) else SKIN_LIGHT

    for x in range(21, 29):
        pix[x, 41] = THAL_MASK_BRIGHT
        pix[x, 42] = THAL_MASK_MID
    for x in range(35, 43):
        pix[x, 41] = THAL_MASK_BRIGHT
        pix[x, 42] = THAL_MASK_MID
    for x in range(28, 36):
        pix[x, 42] = THAL_MASK_MID
        pix[x, 43] = THAL_MASK_DARK

    for y in range(43, 47):
        pix[20, y] = THAL_MASK_MID
        pix[21, y] = THAL_MASK_MID
        pix[42, y] = THAL_MASK_MID
        pix[43, y] = THAL_MASK_MID

    for x in range(22, 28):
        pix[x, 47] = THAL_MASK_DARK
    for x in range(36, 42):
        pix[x, 47] = THAL_MASK_DARK

    pix[21, 46] = (255, 230, 80, 255)
    pix[21, 47] = (255, 230, 80, 255)
    pix[42, 46] = (255, 230, 80, 255)
    pix[42, 47] = (255, 230, 80, 255)

    return f3

def generate_all_and_apply(apply_to_sheets=False):
    isaac = Image.open('C:/Program Files (x86)/Steam/steamapps/common/The Binding of Isaac Rebirth/extracted_resources/resources/gfx/characters/costumes/Character_001_Isaac.png').convert('RGBA')
    hal = Image.open('resources/gfx/characters/hal_jordan.png').convert('RGBA')
    thal = Image.open('resources/gfx/characters/tainted_hal.png').convert('RGBA')

    isaac_f0 = isaac.crop((0, 192, 64, 256))
    isaac_f1 = isaac.crop((64, 192, 128, 256))
    isaac_f2 = isaac.crop((128, 192, 192, 256))
    isaac_f3 = isaac.crop((192, 192, 256, 256))

    hal_head = hal.crop((0, 0, 32, 32))
    thal_head = thal.crop((0, 0, 32, 32))

    hal_f0 = build_hal_f0(isaac_f0, hal_head)
    hal_f1 = build_hal_f1(isaac_f1, hal_head)
    hal_f2 = build_hal_f2(hal.crop((128, 192, 192, 256)))
    hal_f3 = build_hal_f3(hal.crop((192, 192, 256, 256)))

    thal_f0 = build_thal_f0(isaac_f0, thal_head)
    thal_f1 = build_thal_f1(isaac_f1, thal_head)
    thal_f2 = build_thal_f2(thal.crop((128, 192, 192, 256)))
    thal_f3 = build_thal_f3(thal.crop((192, 192, 256, 256)))

    # Assemble strips (256x64)
    hal_strip = Image.new('RGBA', (256, 64), (0,0,0,0))
    hal_strip.paste(hal_f0, (0, 0))
    hal_strip.paste(hal_f1, (64, 0))
    hal_strip.paste(hal_f2, (128, 0))
    hal_strip.paste(hal_f3, (192, 0))

    thal_strip = Image.new('RGBA', (256, 64), (0,0,0,0))
    thal_strip.paste(thal_f0, (0, 0))
    thal_strip.paste(thal_f1, (64, 0))
    thal_strip.paste(thal_f2, (128, 0))
    thal_strip.paste(thal_f3, (192, 0))

    brain_dir = r'C:/Users/danic/.gemini/antigravity/brain/25a8c9be-14f1-4e9c-8c5f-e17d8ccace13'
    hal_strip.save(os.path.join(brain_dir, 'hal_row192_complete_strip.png'))
    thal_strip.save(os.path.join(brain_dir, 'thal_row192_complete_strip.png'))

    # Comparison sheet: 4 columns (Anticipation, Celebratory Hold, Hit, Sad) x 3 rows (Isaac, Hal, Tainted Hal)
    cmp = Image.new('RGBA', (256, 192), (24, 26, 30, 255))
    cmp.paste(isaac_f0, (0, 0), isaac_f0)
    cmp.paste(isaac_f1, (64, 0), isaac_f1)
    cmp.paste(isaac_f2, (128, 0), isaac_f2)
    cmp.paste(isaac_f3, (192, 0), isaac_f3)

    cmp.paste(hal_f0, (0, 64), hal_f0)
    cmp.paste(hal_f1, (64, 64), hal_f1)
    cmp.paste(hal_f2, (128, 64), hal_f2)
    cmp.paste(hal_f3, (192, 64), hal_f3)

    cmp.paste(thal_f0, (0, 128), thal_f0)
    cmp.paste(thal_f1, (64, 128), thal_f1)
    cmp.paste(thal_f2, (128, 128), thal_f2)
    cmp.paste(thal_f3, (192, 128), thal_f3)

    cmp_zoom = cmp.resize((cmp.width * 4, cmp.height * 4), Image.NEAREST)
    cmp_zoom.save(os.path.join(brain_dir, 'complete_row192_comparison_zoom4x.png'))
    print('Generated complete_row192_comparison_zoom4x.png')

    if apply_to_sheets:
        # Hal Jordan
        for path in ['resources/gfx/characters/hal_jordan.png', 'resources/gfx/characters/hal_jordan_extra.png']:
            img = Image.open(path).convert('RGBA')
            # Paste hal_strip at (0, 192)
            img.paste(hal_strip, (0, 192), hal_strip)
            img.save(path)
            print(f'Updated {path}')

        # Tainted Hal
        for path in ['resources/gfx/characters/tainted_hal.png', 'resources/gfx/characters/tainted_hal_extra.png']:
            img = Image.open(path).convert('RGBA')
            img.paste(thal_strip, (0, 192), thal_strip)
            img.save(path)
            print(f'Updated {path}')

if __name__ == '__main__':
    generate_all_and_apply(apply_to_sheets=True)
