"""
tools/build_character_redesign.py
Generates the proposed Isaac-style redesigns for Hal Jordan and Tainted Hal (Parallax)
directly building upon the official vanilla Isaac sprite sheet (character_001_isaac.png).

Generates:
- proposed_hal_jordan.png (512x512 full sprite sheet)
- proposed_tainted_hal.png (512x512 full sprite sheet)
- character_redesign_preview.png (high-res comparison showcase at 4x scale)
"""

import os
from PIL import Image, ImageDraw

VANILLA_PATH = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\character_001_isaac.png"
CURRENT_HAL_PATH = r"resources\gfx\characters\hal_jordan.png"
CURRENT_TAINTED_PATH = r"resources\gfx\characters\tainted_hal.png"

# Color Palettes
# Outlines
OUTLINE_DARK = (28, 22, 21, 255)
OUTLINE_MID = (43, 29, 25, 255)

# Skin (authentic Isaac)
SKIN_BASE = (232, 186, 158, 255)
SKIN_SHADOW = (201, 148, 120, 255)
SKIN_HIGHLIGHT = (244, 212, 192, 255)

# Tainted skin (slightly paler / weathered)
TAINTED_SKIN_BASE = (222, 180, 160, 255)
TAINTED_SKIN_SHADOW = (188, 140, 120, 255)

# Hair (Hal Jordan brown)
HAIR_DARK = (44, 26, 17, 255)
HAIR_BASE = (93, 58, 36, 255)
HAIR_MID = (118, 77, 49, 255)
HAIR_LIGHT = (145, 98, 64, 255)

# Parallax hair (brown with silver/gray temples)
SILVER_TEMPLE = (207, 216, 220, 255)
SILVER_SHADOW = (144, 164, 174, 255)
SILVER_LIGHT = (236, 239, 241, 255)

# Green Lantern Emerald Palette
EMERALD_OUTLINE = (0, 77, 32, 255)
EMERALD_DARK = (0, 122, 51, 255)
EMERALD_BASE = (0, 200, 83, 255)
EMERALD_LIGHT = (0, 230, 118, 255)
EMERALD_GLOW = (105, 240, 174, 255)
WHITE_GLOW = (240, 255, 245, 255)

# Parallax Dark/Cosmic Palette
PARALLAX_ARMOR_DARK = (0, 56, 24, 255)
PARALLAX_ARMOR_BASE = (0, 150, 60, 255)
PARALLAX_ARMOR_LIGHT = (0, 210, 80, 255)
PARALLAX_EYE_YELLOW = (238, 255, 65, 255)
PARALLAX_EYE_GLOW = (200, 255, 80, 255)

# Suit Black / White
SUIT_BLACK = (24, 24, 24, 255)
SUIT_BLACK_MID = (45, 45, 48, 255)
SUIT_WHITE = (245, 245, 245, 255)
SUIT_WHITE_SHADOW = (205, 205, 210, 255)

def create_hal_head_front(base_head):
    """Takes vanilla Isaac front head (32x32) and applies Hal Jordan pilot hair, domino mask, and glowing eyes."""
    img = base_head.copy().convert("RGBA")
    pix = img.load()
    
    # 1. Hair: Smooth curved pilot hair following Isaac's round cranium (Y=2..11)
    # Forehead hairline curves down gently at the sides and parts nicely
    for y in range(2, 12):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30: # If part of head
                # Outer perimeter is dark hair outline
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline:
                    if y <= 10:
                        pix[x, y] = HAIR_DARK
                else:
                    # Hair volume
                    # Hairline logic: hair covers top down to y=10 on sides, y=8-9 in center with side-swept bangs
                    is_hair = False
                    if y <= 7:
                        is_hair = True
                    elif y == 8 and (x < 12 or x > 16):
                        is_hair = True
                    elif y == 9 and (x < 9 or x > 21 or (13 <= x <= 15)): # stylish bang strand
                        is_hair = True
                    elif y == 10 and (x < 7 or x > 23):
                        is_hair = True
                    elif y == 11 and (x < 6 or x > 24):
                        is_hair = True
                        
                    if is_hair:
                        # Hair texturing / highlights
                        if y <= 4:
                            pix[x, y] = HAIR_MID
                        elif y in (5, 6) and (8 <= x <= 14 or 18 <= x <= 22):
                            pix[x, y] = HAIR_LIGHT # soft glossy highlight
                        elif y >= 8:
                            pix[x, y] = HAIR_BASE
                        else:
                            pix[x, y] = HAIR_BASE
    
    # Hair bangs bottom edge outline
    for x in range(3, 29):
        for y in range(6, 12):
            if pix[x, y] in (HAIR_BASE, HAIR_MID, HAIR_LIGHT):
                if y + 1 < 32 and pix[x, y+1] not in (HAIR_BASE, HAIR_MID, HAIR_LIGHT, HAIR_DARK):
                    pix[x, y] = HAIR_DARK

    # 2. Emerald Domino Mask (Y=12..18)
    # Curves around the eyes: left cheek (x=4..13), nose bridge (x=13..18), right cheek (x=18..27)
    mask_pixels = set()
    for y in range(12, 19):
        for x in range(4, 28):
            p = pix[x, y]
            if p[3] > 30 and p != HAIR_DARK:
                in_mask = False
                # Left eye area
                if 5 <= x <= 12 and 13 <= y <= 18:
                    in_mask = True
                # Right eye area
                elif 19 <= x <= 26 and 13 <= y <= 18:
                    in_mask = True
                # Nose bridge connection
                elif 13 <= x <= 18 and 14 <= y <= 16:
                    in_mask = True
                # Wings on cheeks
                elif (x in (4, 27) and y in (14, 15, 16)) or (x in (5, 26) and y in (13, 14, 15, 16, 17)):
                    in_mask = True
                    
                if in_mask:
                    mask_pixels.add((x, y))

    # Apply mask base and outline
    for (x, y) in mask_pixels:
        # Check if border of mask
        is_border = False
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in mask_pixels:
                is_border = True
                break
        if is_border:
            pix[x, y] = EMERALD_OUTLINE
        else:
            if y == 14 and (7 <= x <= 10 or 21 <= x <= 24):
                pix[x, y] = EMERALD_GLOW
            elif y in (14, 15):
                pix[x, y] = EMERALD_LIGHT
            else:
                pix[x, y] = EMERALD_BASE

    # 3. Glowing White Eye Lenses inside Mask (matching Isaac's eye sockets)
    # Left eye: x=[7..10], y=[14..17]
    for y in range(14, 18):
        for x in range(7, 11):
            if (x, y) in mask_pixels:
                pix[x, y] = WHITE_GLOW
    # Eye highlights / inner shape
    pix[7, 14] = EMERALD_GLOW
    pix[10, 14] = EMERALD_GLOW
    pix[7, 17] = EMERALD_DARK
    pix[10, 17] = EMERALD_DARK

    # Right eye: x=[21..24], y=[14..17]
    for y in range(14, 18):
        for x in range(21, 25):
            if (x, y) in mask_pixels:
                pix[x, y] = WHITE_GLOW
    pix[21, 14] = EMERALD_GLOW
    pix[24, 14] = EMERALD_GLOW
    pix[21, 17] = EMERALD_DARK
    pix[24, 17] = EMERALD_DARK

    # 4. Clean up mouth & chin
    # Small determined smirk at y=21, x=14..17
    pix[14, 21] = OUTLINE_DARK
    pix[15, 21] = OUTLINE_DARK
    pix[16, 21] = OUTLINE_DARK
    pix[17, 20] = OUTLINE_DARK # slight confident upturn!

    return img


def create_hal_head_right(base_head):
    """Profile head (looking right) with pilot swept hair and profile domino mask."""
    img = base_head.copy().convert("RGBA")
    pix = img.load()
    
    # Hair
    for y in range(2, 13):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline:
                    if y <= 10 or (x <= 6 and y <= 14):
                        pix[x, y] = HAIR_DARK
                else:
                    is_hair = False
                    if y <= 7:
                        is_hair = True
                    elif y == 8 and (x < 16 or x > 24):
                        is_hair = True
                    elif y in (9, 10) and (x < 14 or (21 <= x <= 23)):
                        is_hair = True
                    elif y in (11, 12) and (x < 8): # back nape hair
                        is_hair = True
                        
                    if is_hair:
                        if y <= 4:
                            pix[x, y] = HAIR_MID
                        elif y in (5, 6) and (10 <= x <= 18):
                            pix[x, y] = HAIR_LIGHT
                        elif y >= 8:
                            pix[x, y] = HAIR_BASE
                        else:
                            pix[x, y] = HAIR_BASE

    # Profile mask over right eye (x=16..26, y=13..18)
    mask_pixels = set()
    for y in range(13, 19):
        for x in range(15, 28):
            p = pix[x, y]
            if p[3] > 30 and p != HAIR_DARK:
                if 16 <= x <= 26:
                    mask_pixels.add((x, y))

    for (x, y) in mask_pixels:
        is_border = False
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            nx, ny = x + dx, y + dy
            if (nx, ny) not in mask_pixels:
                is_border = True
                break
        if is_border:
            pix[x, y] = EMERALD_OUTLINE
        else:
            pix[x, y] = EMERALD_BASE

    # Profile Eye Lens (x=19..23, y=14..17)
    for y in range(14, 18):
        for x in range(19, 24):
            if (x, y) in mask_pixels:
                pix[x, y] = WHITE_GLOW
    pix[19, 14] = EMERALD_GLOW
    pix[23, 14] = EMERALD_GLOW
    pix[19, 17] = EMERALD_DARK
    pix[23, 17] = EMERALD_DARK

    return img


def create_hal_head_up(base_head):
    """Back of head (looking up) - full rich pilot brown hair."""
    img = base_head.copy().convert("RGBA")
    pix = img.load()
    
    for y in range(2, 22):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline:
                    if y <= 18:
                        pix[x, y] = HAIR_DARK
                else:
                    if y <= 18:
                        if y <= 6:
                            pix[x, y] = HAIR_MID
                        elif y in (7, 8) and (10 <= x <= 22):
                            pix[x, y] = HAIR_LIGHT
                        elif y >= 14:
                            pix[x, y] = HAIR_BASE
                        else:
                            pix[x, y] = HAIR_BASE
    return img


def create_hal_body_front(base_body):
    """Applies Green Lantern comic suit to Isaac's chubby front body (32x32)."""
    img = base_body.copy().convert("RGBA")
    pix = img.load()
    
    # Torso is lines 12..19, legs lines 20..24
    for y in range(12, 25):
        for x in range(5, 27):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline:
                    continue # Keep authentic Isaac body outline
                
                # Torso
                if 12 <= y <= 19:
                    # Shoulders & outer waist: Black suit
                    if (x <= 10 or x >= 21) and y <= 18:
                        if y in (16, 17) and (x in (7, 8, 23, 24)):
                            pix[x, y] = SUIT_WHITE # White gloves!
                        else:
                            pix[x, y] = SUIT_BLACK
                    # Central emerald green chest
                    elif 11 <= x <= 20:
                        # Circular emblem at center (x=14..17, y=14..17)
                        dist_sq = (x - 15.5)**2 + (y - 15.5)**2
                        if dist_sq <= 3.2:
                            # White circle with Green Lantern symbol inside
                            if 15 <= x <= 16 and y in (15, 16):
                                pix[x, y] = EMERALD_DARK # Lantern icon center
                            else:
                                pix[x, y] = SUIT_WHITE # Emblem white disk
                        else:
                            if y == 13:
                                pix[x, y] = EMERALD_LIGHT
                            else:
                                pix[x, y] = EMERALD_BASE
                    else:
                        pix[x, y] = EMERALD_BASE

                # Legs & Boots (lines 20..24)
                elif 20 <= y <= 24:
                    if y in (20, 21):
                        pix[x, y] = SUIT_BLACK # Black pants
                    else:
                        pix[x, y] = EMERALD_BASE # Emerald boots!

    # Right fist power ring glow (x=24, y=18)
    if pix[24, 18][3] > 30:
        pix[24, 18] = EMERALD_GLOW

    return img


def create_tainted_head_front(base_head):
    """Parallax Hal Jordan: Isaac round head, brown hair with SILVER TEMPLES, and cosmic yellow/green eyes."""
    img = base_head.copy().convert("RGBA")
    pix = img.load()

    # 1. Hair with iconic silver temples
    for y in range(2, 12):
        for x in range(2, 30):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline:
                    if y <= 10:
                        pix[x, y] = HAIR_DARK
                else:
                    is_hair = False
                    if y <= 7:
                        is_hair = True
                    elif y == 8 and (x < 12 or x > 16):
                        is_hair = True
                    elif y == 9 and (x < 9 or x > 21 or (13 <= x <= 15)):
                        is_hair = True
                    elif y == 10 and (x < 7 or x > 23):
                        is_hair = True
                    elif y == 11 and (x < 6 or x > 24):
                        is_hair = True

                    if is_hair:
                        # SILVER TEMPLES at the sides! (x in 4..7 or x in 23..27)
                        if (4 <= x <= 8 or 22 <= x <= 26) and 6 <= y <= 11:
                            if y in (7, 8):
                                pix[x, y] = SILVER_LIGHT
                            else:
                                pix[x, y] = SILVER_TEMPLE
                        elif y <= 4:
                            pix[x, y] = HAIR_MID
                        else:
                            pix[x, y] = HAIR_BASE

    # 2. Parallax Sharp Domino Mask (Y=12..18)
    mask_pixels = set()
    for y in range(12, 19):
        for x in range(4, 28):
            p = pix[x, y]
            if p[3] > 30 and p != HAIR_DARK:
                in_mask = False
                if 5 <= x <= 12 and 13 <= y <= 18: in_mask = True
                elif 19 <= x <= 26 and 13 <= y <= 18: in_mask = True
                elif 13 <= x <= 18 and 14 <= y <= 16: in_mask = True
                elif (x in (4, 27) and y in (14, 15, 16)) or (x in (5, 26) and y in (13, 14, 15, 16, 17)): in_mask = True
                if in_mask: mask_pixels.add((x, y))

    for (x, y) in mask_pixels:
        is_border = False
        for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
            if (x+dx, y+dy) not in mask_pixels:
                is_border = True; break
        if is_border:
            pix[x, y] = EMERALD_OUTLINE
        else:
            pix[x, y] = PARALLAX_ARMOR_BASE

    # 3. Glowing Parallax Cosmic Yellow-Green Eyes!
    for y in range(14, 18):
        for x in range(7, 11):
            if (x, y) in mask_pixels:
                pix[x, y] = PARALLAX_EYE_YELLOW
    for y in range(14, 18):
        for x in range(21, 25):
            if (x, y) in mask_pixels:
                pix[x, y] = PARALLAX_EYE_YELLOW

    # Toxic energy highlights
    pix[8, 15] = (255, 255, 200, 255)
    pix[22, 15] = (255, 255, 200, 255)

    # Stern mouth
    pix[14, 21] = OUTLINE_DARK
    pix[15, 21] = OUTLINE_DARK
    pix[16, 21] = OUTLINE_DARK
    pix[17, 21] = OUTLINE_DARK

    return img


def create_tainted_body_front(base_body):
    """Parallax armored body with high collar, shoulder armor, cape edges, and cosmic rings."""
    img = base_body.copy().convert("RGBA")
    pix = img.load()

    for y in range(12, 25):
        for x in range(4, 28):
            p = pix[x, y]
            if p[3] > 30:
                is_outline = (p[0] < 50 and p[1] < 50 and p[2] < 50)
                if is_outline:
                    continue

                # Torso
                if 12 <= y <= 19:
                    # Cape edge visible behind shoulders
                    if (x in (5, 6, 25, 26)) and y >= 14:
                        pix[x, y] = PARALLAX_ARMOR_DARK
                    # Armored shoulders / pauldrons (y=12..14, x=7..11 and 20..24)
                    elif y in (12, 13, 14) and (7 <= x <= 11 or 20 <= x <= 24):
                        if y == 12:
                            pix[x, y] = PARALLAX_ARMOR_LIGHT
                        else:
                            pix[x, y] = PARALLAX_ARMOR_BASE
                    # Central armored chest
                    elif 12 <= x <= 19:
                        if y in (15, 16) and 14 <= x <= 17:
                            pix[x, y] = PARALLAX_EYE_YELLOW # Glowing Parallax crest!
                        elif y % 2 == 0:
                            pix[x, y] = SUIT_BLACK # Segmented armor ribs
                        else:
                            pix[x, y] = PARALLAX_ARMOR_BASE
                    # Hands with rings
                    elif (x in (7, 8, 23, 24)) and y in (17, 18):
                        pix[x, y] = EMERALD_DARK
                    else:
                        pix[x, y] = SUIT_BLACK

                # Armored legs (lines 20..24)
                elif 20 <= y <= 24:
                    if y in (20, 21):
                        pix[x, y] = SUIT_BLACK
                    else:
                        pix[x, y] = PARALLAX_ARMOR_BASE

    # Multiple glowing rings on both fists!
    pix[7, 17] = PARALLAX_EYE_YELLOW
    pix[8, 18] = EMERALD_GLOW
    pix[23, 17] = PARALLAX_EYE_YELLOW
    pix[24, 18] = EMERALD_GLOW

    return img


def build_showcase():
    print("Loading base sheets...")
    vanilla = Image.open(VANILLA_PATH).convert("RGBA")
    current_hal = Image.open(CURRENT_HAL_PATH).convert("RGBA")
    current_tainted = Image.open(CURRENT_TAINTED_PATH).convert("RGBA")

    # Crop heads and bodies
    v_head_down = vanilla.crop((0, 0, 32, 32))
    v_head_right = vanilla.crop((64, 0, 96, 32))
    v_head_up = vanilla.crop((128, 0, 160, 32))
    v_body_down = vanilla.crop((0, 32, 32, 64))

    c_head_down = current_hal.crop((0, 0, 32, 32))
    c_head_right = current_hal.crop((64, 0, 96, 32))
    c_head_up = current_hal.crop((128, 0, 160, 32))
    c_body_down = current_hal.crop((0, 32, 32, 64))

    ct_head_down = current_tainted.crop((0, 0, 32, 32))
    ct_head_right = current_tainted.crop((64, 0, 96, 32))
    ct_head_up = current_tainted.crop((128, 0, 160, 32))
    ct_body_down = current_tainted.crop((0, 32, 32, 64))

    # Generate new redesigns
    new_hal_head_down = create_hal_head_front(v_head_down)
    new_hal_head_right = create_hal_head_right(v_head_right)
    new_hal_head_up = create_hal_head_up(v_head_up)
    new_hal_body_down = create_hal_body_front(v_body_down)

    new_tainted_head_down = create_tainted_head_front(v_head_down)
    new_tainted_body_down = create_tainted_body_front(v_body_down)

    # Function to assemble full character (head + body with proper offset)
    def assemble_char(head, body):
        full = Image.new("RGBA", (32, 36), (0, 0, 0, 0))
        # Body at bottom: body y=12 aligns with full y=14
        full.paste(body, (0, 4), body)
        # Head at top: head overlaps body
        full.paste(head, (0, 0), head)
        return full

    v_assembled = assemble_char(v_head_down, v_body_down)
    c_assembled = assemble_char(c_head_down, c_body_down)
    ct_assembled = assemble_char(ct_head_down, ct_body_down)
    new_hal_assembled = assemble_char(new_hal_head_down, new_hal_body_down)
    new_tainted_assembled = assemble_char(new_tainted_head_down, new_tainted_body_down)

    # Build Comparison Canvas (Width = 4 columns x 140px = 560px, Height = 480px)
    SCALE = 4
    canvas_w = 140 * 4
    canvas_h = 420
    preview = Image.new("RGBA", (canvas_w, canvas_h), (20, 20, 24, 255))
    draw = ImageDraw.Draw(preview)

    cols = [
        ("Vanilla Isaac (Baseline)", v_assembled, v_head_down, v_head_right, v_head_up, (180, 180, 180)),
        ("Current Mod (Blocky)", c_assembled, c_head_down, c_head_right, c_head_up, (220, 100, 100)),
        ("Proposed Hal Jordan", new_hal_assembled, new_hal_head_down, new_hal_head_right, new_hal_head_up, (0, 230, 118)),
        ("Proposed Parallax", new_tainted_assembled, new_tainted_head_down, new_hal_head_right, new_hal_head_up, (255, 235, 59)),
    ]

    for col_idx, (title, full_char, head_d, head_r, head_u, color) in enumerate(cols):
        col_x = col_idx * 140 + 10
        # Draw column title
        draw.text((col_x, 10), title, fill=color)

        # 1. Assembled Full Character (Scaled 4x)
        full_scaled = full_char.resize((32 * SCALE, 36 * SCALE), Image.NEAREST)
        preview.paste(full_scaled, (col_x, 35), full_scaled)

        # Label: Front Head
        draw.text((col_x, 195), "Head Front", fill=(160, 160, 160))
        hd_scaled = head_d.resize((28 * SCALE, 28 * SCALE), Image.NEAREST)
        preview.paste(hd_scaled, (col_x, 210), hd_scaled)

        # Label: Profile
        draw.text((col_x, 330), "Profile", fill=(160, 160, 160))
        hr_scaled = head_r.resize((28 * SCALE, 28 * SCALE), Image.NEAREST)
        preview.paste(hr_scaled, (col_x, 345), hr_scaled)

    # Save preview image
    preview_path = "character_redesign_preview.png"
    preview.save(preview_path)
    print(f"Saved {preview_path} successfully!")

    # Also build full 512x512 proposed sheets
    proposed_hal_sheet = vanilla.copy()
    # Replace front head
    proposed_hal_sheet.paste(new_hal_head_down, (0, 0), new_hal_head_down)
    proposed_hal_sheet.paste(new_hal_head_right, (64, 0), new_hal_head_right)
    proposed_hal_sheet.paste(new_hal_head_up, (128, 0), new_hal_head_up)
    proposed_hal_sheet.paste(new_hal_body_down, (0, 32), new_hal_body_down)
    proposed_hal_sheet.save("proposed_hal_jordan.png")
    print("Saved proposed_hal_jordan.png")

    proposed_tainted_sheet = vanilla.copy()
    proposed_tainted_sheet.paste(new_tainted_head_down, (0, 0), new_tainted_head_down)
    proposed_tainted_sheet.paste(new_tainted_body_down, (0, 32), new_tainted_body_down)
    proposed_tainted_sheet.save("proposed_tainted_hal.png")
    print("Saved proposed_tainted_hal.png")

if __name__ == "__main__":
    build_showcase()
