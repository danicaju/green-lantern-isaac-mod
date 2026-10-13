"""
tools/verify_costume_merging.py
Deep verification of item costume merging across Front, Side, and Back orientations.
Generates an uncompressed high-resolution grid showing authentic vanilla Isaac costumes:
1. Base (No Items)
2. 20/20 Glasses (Eyeglasses alignment)
3. The Halo (Crown / Skull top alignment)
4. Sad Onion Tears (Eye socket / Cheek alignment)
5. Monstro's Lung (Mouth / Jaw alignment)
Composited over Vanilla Isaac, Proposed Hal Jordan, and Proposed Tainted Hal.
"""

import os
import sys

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_DIR not in sys.path:
    sys.path.insert(0, PROJECT_DIR)

from PIL import Image, ImageDraw
from tools.generate_all_redesigns import (
    render_hal_head_front, render_hal_head_side, render_hal_head_back,
    render_tainted_head_front, render_tainted_head_side, render_tainted_head_back
)

EXTRACTED_RES = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx"
VANILLA_PATH = os.path.join(EXTRACTED_RES, r"characters\costumes\character_001_isaac.png")
ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\c85d05f1-0104-407a-a3c0-1180d226af49"

PATH_2020 = os.path.join(EXTRACTED_RES, r"characters\costumes\costume_245_2020.png")
PATH_HALO = os.path.join(EXTRACTED_RES, r"characters\costumes\costume_119_halo.png")
PATH_SADONION = os.path.join(EXTRACTED_RES, r"characters\costumes\costume_058_sadonion.png")
PATH_MONSTRO = os.path.join(EXTRACTED_RES, r"characters\costumes\costume_monstros lung.png")

def get_costume_overlay(costume_type, orientation):
    if costume_type == '2020':
        img = Image.open(PATH_2020).convert('RGBA')
        if orientation == 'down':
            return img.crop((0, 0, 32, 32)), 0, 0
        elif orientation == 'right':
            return img.crop((64, 0, 96, 32)), 0, 0
        else:
            return None, 0, 0

    elif costume_type == 'halo':
        img = Image.open(PATH_HALO).convert('RGBA')
        if orientation == 'down':
            return img.crop((0, 0, 32, 64)), 0, -16
        elif orientation == 'right':
            return img.crop((64, 0, 96, 64)), 0, -16
        elif orientation == 'up':
            return img.crop((128, 0, 160, 64)), 0, -16

    elif costume_type == 'sadonion':
        img = Image.open(PATH_SADONION).convert('RGBA')
        if orientation == 'down':
            return img.crop((0, 0, 64, 64)), -16, -16
        elif orientation == 'right':
            return img.crop((0, 64, 64, 64)), -20, -16
        else:
            return None, 0, 0

    elif costume_type == 'monstro':
        img = Image.open(PATH_MONSTRO).convert('RGBA')
        if orientation == 'down':
            return img.crop((0, 16, 64, 48)), -16, -3
        elif orientation == 'right':
            return img.crop((0, 80, 64, 112)), -16, -3
        else:
            return None, 0, 0

    return None, 0, 0

def composite_head_with_costume(head_32, costume_type, orientation):
    PAD = 10
    canvas = Image.new('RGBA', (32 + PAD * 2, 32 + PAD * 2), (0, 0, 0, 0))
    canvas.paste(head_32, (PAD, PAD), head_32)

    costume_img, ox, oy = get_costume_overlay(costume_type, orientation)
    if costume_img is not None:
        paste_x = PAD + ox
        paste_y = PAD + oy
        canvas.paste(costume_img, (paste_x, paste_y), costume_img)

    return canvas

def run_verification():
    print("Running Item Costume Merge Verification with spacious layout...")
    vanilla_sheet = Image.open(VANILLA_PATH).convert('RGBA')

    v_hd = vanilla_sheet.crop((0, 0, 32, 32))
    v_hr = vanilla_sheet.crop((64, 0, 96, 32))
    v_hu = vanilla_sheet.crop((128, 0, 160, 32))

    hal_hd = render_hal_head_front(v_hd, is_shooting=False)
    hal_hr = render_hal_head_side(v_hr, is_shooting=False)
    hal_hu = render_hal_head_back(v_hu, is_shooting=False)

    thal_hd = render_tainted_head_front(v_hd, is_shooting=False)
    thal_hr = render_tainted_head_side(v_hr, is_shooting=False)
    thal_hu = render_tainted_head_back(v_hu, is_shooting=False)

    characters = [
        ("Vanilla Isaac", v_hd, v_hr, v_hu),
        ("Hal Jordan", hal_hd, hal_hr, hal_hu),
        ("Tainted Hal", thal_hd, thal_hr, thal_hu),
    ]

    costumes_to_test = [
        ("1. Base (No Items)", None),
        ("2. 20/20 Glasses", "2020"),
        ("3. The Halo", "halo"),
        ("4. Sad Onion Tears", "sadonion"),
        ("5. Monstro's Lung", "monstro"),
    ]

    orientations = [("Front", "down"), ("Side", "right"), ("Back", "up")]

    # Canvas dimensions:
    # Sub-cell size = 52x52 at 3x scale = 156x156.
    # Group of 3 orientations = 156 * 3 + 16 = 484 px.
    # 3 Characters = 484 * 3 + 20 = 1472 px.
    # Label column = 180 px.
    # Total width = 180 + 1472 = 1652 px.
    # Height = 50 + 5 rows * (156 + 16) = 910 px.

    SCALE = 3
    CELL_NATIVE = 52
    CELL_SCALED = CELL_NATIVE * SCALE # 156 px
    GAP = 8
    LABEL_W = 180
    CHAR_GROUP_W = (CELL_SCALED + GAP) * 3 + 24
    CANVAS_W = LABEL_W + CHAR_GROUP_W * 3
    CANVAS_H = 60 + len(costumes_to_test) * (CELL_SCALED + 20)

    sheet = Image.new('RGBA', (CANVAS_W, CANVAS_H), (18, 20, 24, 255))
    draw = ImageDraw.Draw(sheet)

    # Column Titles
    for c_idx, (c_name, _, _, _) in enumerate(characters):
        group_x = LABEL_W + c_idx * CHAR_GROUP_W
        color = (0, 230, 118) if "Hal Jordan" == c_name else ((255, 235, 59) if "Tainted" in c_name else (200, 200, 200))
        draw.text((group_x + 10, 15), f"{c_name.upper()}", fill=color)
        draw.text((group_x + 10, 32), "Front          Side           Back", fill=(130, 130, 140))

    # Rows
    for r_idx, (costume_label, costume_type) in enumerate(costumes_to_test):
        ry = 60 + r_idx * (CELL_SCALED + 20)
        draw.text((15, ry + 60), costume_label, fill=(240, 240, 240))

        for c_idx, (_, hd, hr, hu) in enumerate(characters):
            heads = {"down": hd, "right": hr, "up": hu}
            group_x = LABEL_W + c_idx * CHAR_GROUP_W

            for o_idx, (_, o_key) in enumerate(orientations):
                head = heads[o_key]
                comp = composite_head_with_costume(head, costume_type, o_key)
                comp_scaled = comp.resize((CELL_SCALED, CELL_SCALED), Image.NEAREST)
                cell_x = group_x + o_idx * (CELL_SCALED + GAP)
                sheet.paste(comp_scaled, (cell_x, ry), comp_scaled)

    out_path = "item_costumes_merge_showcase.png"
    sheet.save(out_path)
    os.makedirs(ARTIFACT_DIR, exist_ok=True)
    art_path = os.path.join(ARTIFACT_DIR, "item_costumes_merge_showcase.png")
    sheet.save(art_path)
    print(f"Costume merge showcase saved to {out_path} and {art_path}")

if __name__ == '__main__':
    run_verification()
