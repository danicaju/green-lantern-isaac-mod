"""
tools/generate_showcase.py
Generates high-resolution comparison images, in-game pedestal mockups,
and HUD item bar comparisons for the new Green Lantern Ring sprite.
"""

import os
from PIL import Image, ImageDraw, ImageFont

ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\1da92c3a-b6b6-41f0-ae66-135ed6eb06a2"
MOD_DIR = r"C:\Users\danic\Desktop\green_lantern_mod"
SKETCH_PATH = os.path.join(ARTIFACT_DIR, r".user_uploaded\media_1790729121738.jpg")
OLD_SPRITE_PATH = os.path.join(ARTIFACT_DIR, "ring_old_sprite.png")
NEW_SPRITE_PATH = os.path.join(ARTIFACT_DIR, "ring_perfect_1x.png")

VANILLA_PEDESTAL = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\items\levelitem_001_itemaltar.png"
VANILLA_FLOOR = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\backdrop\01_basement_nfloor.png"

def make_showcase():
    old_spr = Image.open(OLD_SPRITE_PATH).convert("RGBA")
    new_spr = Image.open(NEW_SPRITE_PATH).convert("RGBA")
    sketch  = Image.open(SKETCH_PATH).convert("RGB")

    # 1. SIDE-BY-SIDE COMPARISON IMAGE (1000 x 500)
    # Shows Sketch, Old Sprite (8x), and New Sprite (8x) on dark pedestal background
    w, h = 960, 440
    comp = Image.new("RGBA", (w, h), (24, 20, 18, 255)) # Dark Isaac background
    draw = ImageDraw.Draw(comp)

    # Left: Sketch crop (280x280)
    sketch_crop = sketch.crop((100, 70, 930, 900)).resize((280, 280), Image.Resampling.LANCZOS)
    comp.paste(sketch_crop, (40, 80))

    # Center: Old sprite at 8x (256x256)
    old_8x = old_spr.resize((256, 256), Image.Resampling.NEAREST)
    comp.paste(old_8x, (350, 90), old_8x)

    # Right: New sprite at 8x (256x256)
    new_8x = new_spr.resize((256, 256), Image.Resampling.NEAREST)
    comp.paste(new_8x, (650, 90), new_8x)

    # Titles
    draw.text((80, 40), "USER SKETCH (REFERENCE)", fill=(200, 240, 200), font_size=18)
    draw.text((370, 40), "OLD SPRITE (CURRENT)", fill=(240, 120, 120), font_size=18)
    draw.text((680, 40), "NEW SPRITE (REDESIGNED)", fill=(120, 255, 150), font_size=18)

    # Subtitles
    draw.text((370, 360), "Muddy colors / blurry square hole", fill=(180, 140, 140), font_size=14)
    draw.text((670, 360), "Crisp GL Emblem / Runic Band / 1-bit alpha", fill=(140, 210, 160), font_size=14)

    comp.save(os.path.join(ARTIFACT_DIR, "ring_showcase_comparison.png"))
    print("Saved ring_showcase_comparison.png")

    # 2. IN-GAME PEDESTAL & ROOM MOCKUP
    # Render on real Isaac basement floor and pedestal!
    if os.path.exists(VANILLA_PEDESTAL) and os.path.exists(VANILLA_FLOOR):
        floor_sheet = Image.open(VANILLA_FLOOR).convert("RGBA")
        altar_sheet = Image.open(VANILLA_PEDESTAL).convert("RGBA")

        # Crop 1 floor tile (130x130)
        floor_tile = floor_sheet.crop((0, 0, 150, 150))
        # Pedestal sprite: standard brown stone pedestal is at (96, 64, 128, 96) in levelitem_001_itemaltar.png
        # Let's crop the brown stone pedestal (32x32)
        pedestal = altar_sheet.crop((96, 64, 128, 96))

        # Build 2 mockup scenes (150x150 each): Old vs New
        mock_old = floor_tile.copy()
        mock_new = floor_tile.copy()

        # Paste pedestal at (59, 70)
        mock_old.paste(pedestal, (59, 70), pedestal)
        mock_new.paste(pedestal, (59, 70), pedestal)

        # Paste item floating above pedestal at (59, 46)
        mock_old.paste(old_spr, (59, 46), old_spr)
        mock_new.paste(new_spr, (59, 46), new_spr)

        # Combine side-by-side at 3x scale (900x450)
        mock_combined = Image.new("RGBA", (900, 460), (20, 18, 16, 255))
        d_mock = ImageDraw.Draw(mock_combined)

        old_3x = mock_old.resize((400, 400), Image.Resampling.NEAREST)
        new_3x = mock_new.resize((400, 400), Image.Resampling.NEAREST)

        mock_combined.paste(old_3x, (30, 40))
        mock_combined.paste(new_3x, (470, 40))

        d_mock.text((100, 15), "IN-GAME PEDESTAL: OLD SPRITE", fill=(240, 120, 120), font_size=16)
        d_mock.text((540, 15), "IN-GAME PEDESTAL: NEW SPRITE", fill=(120, 255, 150), font_size=16)

        mock_combined.save(os.path.join(ARTIFACT_DIR, "ring_pedestal_mockup.png"))
        print("Saved ring_pedestal_mockup.png")

    # 3. FULL MOD COLLECTIBLES HARMONY ROW
    # Place all 6 collectibles in a row to verify stylistic coherence
    row_img = Image.new("RGBA", (6 * 32 + 7 * 8, 32 + 16), (28, 22, 20, 255))
    items = [
        "collectible_power_battery.png",
        "collectible_giant_fist.png",
        "collectible_solid_light_shield.png",
        "collectible_coast_city.png",
        "collectible_gatling.png",
    ]
    cur_x = 8
    for it in items:
        p = os.path.join(MOD_DIR, r"resources\gfx\items\collectibles", it)
        im = Image.open(p).convert("RGBA")
        row_img.paste(im, (cur_x, 8), im)
        cur_x += 40

    # Paste new ring as 6th item
    row_img.paste(new_spr, (cur_x, 8), new_spr)

    row_4x = row_img.resize((row_img.width * 4, row_img.height * 4), Image.Resampling.NEAREST)
    row_4x.save(os.path.join(ARTIFACT_DIR, "all_mod_items_harmony_4x.png"))
    print("Saved all_mod_items_harmony_4x.png")

if __name__ == "__main__":
    make_showcase()
