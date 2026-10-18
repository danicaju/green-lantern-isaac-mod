"""
tools/build_menu_sheets.py
Embeds 48x52 character menu portraits into 160x160 character menu sheets
at (56, 2, 104, 54), zeroing dirty alpha and preserving name text.
"""

import os
from PIL import Image

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(TOOLS_DIR)

def build_menu_sheet(base_sheet_path: str, portrait_img: Image.Image) -> Image.Image:
    sheet = Image.open(base_sheet_path).convert("RGBA")
    pix = sheet.load()

    # 1. Clear portrait crop area (56, 2, 104, 54)
    for y in range(2, 54):
        for x in range(56, 104):
            pix[x, y] = (0, 0, 0, 0)

    # Clean stray artifact line between Y=44 and Y=53
    for y in range(44, 54):
        for x in range(160):
            if y < 54:
                pix[x, y] = (0, 0, 0, 0)

    # 2. Paste new handmade portrait
    sheet.paste(portrait_img, (56, 2), portrait_img)

    # 3. Sanitize zero dirty alpha
    w, h = sheet.size
    for y in range(h):
        for x in range(w):
            if pix[x, y][3] == 0:
                pix[x, y] = (0, 0, 0, 0)

    return sheet
