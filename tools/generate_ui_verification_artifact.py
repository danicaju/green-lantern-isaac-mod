"""
tools/generate_ui_verification_artifact.py
Generates 4x zoom composite verification previews for Character Menu portraits,
Stage Nightmare transitions, and Boss VS UI into the artifacts directory.
"""

import os
from PIL import Image, ImageDraw, ImageFont

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\d0abad69-7124-472e-9088-fe0a1a3473a9"

def add_label(img: Image.Image, text: str, pos=(4, 4), color=(255, 255, 255, 255), bg=(0, 0, 0, 180)):
    draw = ImageDraw.Draw(img)
    # Simple bitmap box label
    bbox = draw.textbbox(pos, text)
    pad = 2
    draw.rectangle((bbox[0]-pad, bbox[1]-pad, bbox[2]+pad, bbox[3]+pad), fill=bg)
    draw.text(pos, text, fill=color)

def generate_menu_comparison():
    print("[1/4] Generating Character Menu 4x Verification Preview...")
    v_isaac = Image.open(os.path.join(ARTIFACT_DIR, "vanilla_menu_isaac.png"))
    old_hal = Image.open(os.path.join(ARTIFACT_DIR, "curr_hal_menu_portrait.png"))
    old_thal = Image.open(os.path.join(ARTIFACT_DIR, "curr_t_menu_portrait.png"))

    new_hal_menu = Image.open(os.path.join(PROJECT_DIR, "content/gfx/hal_charactermenu.png")).crop((56, 2, 104, 54))
    new_thal_menu = Image.open(os.path.join(PROJECT_DIR, "content/gfx/tainted_charactermenu.png")).crop((56, 2, 104, 54))

    # Grid: 5 columns (Vanilla Isaac, Old Hal, New Hal, Old Tainted, New Tainted)
    w, h = 48, 52
    spacing = 8
    canvas = Image.new("RGBA", (w * 5 + spacing * 6, h + 24), (24, 24, 28, 255))

    items = [
        ("Vanilla Isaac", v_isaac),
        ("Old Hal Menu", old_hal),
        ("NEW Hal Jordan", new_hal_menu),
        ("Old Tainted Hal", old_thal),
        ("NEW Tainted Hal", new_thal_menu),
    ]

    for idx, (label, im) in enumerate(items):
        x = spacing + idx * (w + spacing)
        y = 20
        # Draw slot box
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((x-1, y-1, x+w, y+h), outline=(60, 60, 68, 255))
        canvas.paste(im, (x, y), im)
        add_label(canvas, label, (x, 4), color=(220, 220, 220, 255), bg=(35, 35, 42, 255))

    canvas_4x = canvas.resize((canvas.width * 4, canvas.height * 4), Image.NEAREST)
    out_path = os.path.join(ARTIFACT_DIR, "menu_portraits_comparison_4x.png")
    canvas_4x.save(out_path)
    print(f"  -> Saved {out_path}")

def generate_stage_comparison():
    print("[2/4] Generating Stage Transition 4x Verification Preview...")
    v_stage = Image.open(os.path.join(ARTIFACT_DIR, "stageapi_isaac.png"))
    old_h_stage = Image.open(os.path.join(ARTIFACT_DIR, "curr_hal_stage.png"))
    old_t_stage = Image.open(os.path.join(ARTIFACT_DIR, "curr_t_stage.png"))

    new_h_stage = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/stage/stage_hal_jordan.png"))
    new_t_stage = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/stage/stage_tainted_hal.png"))

    # Crop to content box around (15, 70, 115, 142) -> 100x72
    crop_box = (15, 70, 115, 142)
    cw, ch = 100, 72
    spacing = 8
    canvas = Image.new("RGBA", (cw * 5 + spacing * 6, ch + 24), (20, 20, 24, 255))

    items = [
        ("Vanilla Nightmare", v_stage.crop(crop_box)),
        ("Old Hal Stage", old_h_stage.crop(crop_box)),
        ("NEW Hal Stage", new_h_stage.crop(crop_box)),
        ("Old Tainted Stage", old_t_stage.crop(crop_box)),
        ("NEW Tainted Stage", new_t_stage.crop(crop_box)),
    ]

    for idx, (label, im) in enumerate(items):
        x = spacing + idx * (cw + spacing)
        y = 20
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((x-1, y-1, x+cw, y+ch), outline=(50, 50, 60, 255))
        canvas.paste(im, (x, y), im)
        add_label(canvas, label, (x, 4), color=(220, 220, 220, 255), bg=(30, 30, 38, 255))

    canvas_4x = canvas.resize((canvas.width * 4, canvas.height * 4), Image.NEAREST)
    out_path = os.path.join(ARTIFACT_DIR, "stage_nightmare_comparison_4x.png")
    canvas_4x.save(out_path)
    print(f"  -> Saved {out_path}")

def generate_boss_ui_comparison():
    print("[3/4] Generating Boss UI 4x Verification Preview...")
    h_name = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/name_hal_jordan.png"))
    t_name = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/name_tainted_hal.png"))
    h_port = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/portrait_hal_jordan.png"))
    t_port = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/portrait_tainted_hal.png"))

    # Boss screen mock layout: 2 cards (Hal Jordan VS Boss, Tainted Hal VS Boss)
    card_w = 240
    card_h = 160
    spacing = 10
    canvas = Image.new("RGBA", (card_w * 2 + spacing * 3, card_h + 20), (18, 18, 20, 255))

    # Hal Card
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((spacing, 10, spacing + card_w, 10 + card_h), fill=(26, 26, 30, 255), outline=(55, 55, 65, 255))
    # Paste Name (192x64) scaled/centered at top
    canvas.paste(h_name, (spacing + (card_w - 192)//2, 16), h_name)
    # Paste Portrait cropped around (15, 70, 115, 142) -> 100x72
    h_crop = h_port.crop((15, 70, 115, 142))
    canvas.paste(h_crop, (spacing + (card_w - 100)//2, 80), h_crop)
    add_label(canvas, "HAL JORDAN - BOSS VS UI", (spacing + 8, 14), color=(199, 178, 153, 255), bg=(35, 35, 42, 255))

    # Tainted Hal Card
    x_offset = spacing * 2 + card_w
    draw.rectangle((x_offset, 10, x_offset + card_w, 10 + card_h), fill=(26, 26, 30, 255), outline=(55, 55, 65, 255))
    canvas.paste(t_name, (x_offset + (card_w - 192)//2, 16), t_name)
    t_crop = t_port.crop((15, 70, 115, 142))
    canvas.paste(t_crop, (x_offset + (card_w - 100)//2, 80), t_crop)
    add_label(canvas, "TAINTED HAL - BOSS VS UI", (x_offset + 8, 14), color=(199, 178, 153, 255), bg=(35, 35, 42, 255))

    canvas_4x = canvas.resize((canvas.width * 4, canvas.height * 4), Image.NEAREST)
    out_path = os.path.join(ARTIFACT_DIR, "boss_vs_screen_showcase_4x.png")
    canvas_4x.save(out_path)
    print(f"  -> Saved {out_path}")

def generate_master_showcase():
    print("[4/4] Generating Master UI Evolution Showcase...")
    # Composite showing Menu + Stage + Boss UI in one comprehensive image
    w = 560
    h = 360
    master = Image.new("RGBA", (w, h), (16, 16, 18, 255))
    draw = ImageDraw.Draw(master)

    # Title Banner
    draw.rectangle((0, 0, w, 28), fill=(28, 32, 30, 255))
    add_label(master, "GREEN LANTERN MOD - UI REDESIGN SHOWCASE (HAL JORDAN & TAINTED HAL)", (8, 6), color=(105, 240, 174, 255), bg=(28, 32, 30, 0))

    # Section 1: Character Menu Portraits (Y: 36..130)
    add_label(master, "1. CHARACTER MENU PORTRAITS (48x52 crop in 160x160 sheets)", (8, 34), color=(220, 220, 220, 255), bg=(20, 20, 24, 255))
    old_h = Image.open(os.path.join(ARTIFACT_DIR, "curr_hal_menu_portrait.png"))
    new_h = Image.open(os.path.join(PROJECT_DIR, "content/gfx/hal_charactermenu.png")).crop((56, 2, 104, 54))
    old_t = Image.open(os.path.join(ARTIFACT_DIR, "curr_t_menu_portrait.png"))
    new_t = Image.open(os.path.join(PROJECT_DIR, "content/gfx/tainted_charactermenu.png")).crop((56, 2, 104, 54))

    menu_items = [
        ("Old Hal", old_h),
        ("NEW Hal (Crisp Pixel Art)", new_h),
        ("Old Tainted", old_t),
        ("NEW Tainted (Parallax Temples)", new_t),
    ]
    for idx, (lbl, im) in enumerate(menu_items):
        mx = 16 + idx * 136
        my = 56
        draw.rectangle((mx-1, my-1, mx+48, my+52), outline=(50, 50, 60, 255))
        master.paste(im, (mx, my), im)
        add_label(master, lbl, (mx + 54, my + 18), color=(200, 200, 200, 255), bg=(20, 20, 24, 255))

    # Section 2: Stage Nightmare Transitions (Y: 135..250)
    add_label(master, "2. STAGE NIGHTMARE TRANSITIONS (144x144 canvas, framed at (15, 70, 115, 142))", (8, 126), color=(220, 220, 220, 255), bg=(20, 20, 24, 255))
    new_hs = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/stage/stage_hal_jordan.png")).crop((15, 70, 115, 142))
    new_ts = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/stage/stage_tainted_hal.png")).crop((15, 70, 115, 142))

    master.paste(new_hs, (16, 148), new_hs)
    add_label(master, "Hal Jordan (Nightmare)\n- Brown pilot hair\n- Glowing domino mask\n- Clenched fist GL ring glow\n- Clean tear pool", (124, 152), color=(180, 230, 200, 255), bg=(20, 20, 24, 255))

    master.paste(new_ts, (290, 148), new_ts)
    add_label(master, "Tainted Hal (Parallax)\n- Silver temple hair streaks\n- Dark draped torn cape\n- Yellow fear tear stream\n- Sickly fear-tinged pool", (398, 152), color=(240, 230, 160, 255), bg=(20, 20, 24, 255))

    # Section 3: Boss Names Banner (Y: 255..350)
    add_label(master, "3. BOSS UI BANNERS (Canonical 192x64, Centered at X=104 in #C7B299)", (8, 246), color=(220, 220, 220, 255), bg=(20, 20, 24, 255))
    h_name = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/name_hal_jordan.png"))
    t_name = Image.open(os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/name_tainted_hal.png"))

    draw.rectangle((16, 268, 16 + 250, 268 + 76), fill=(24, 24, 28, 255), outline=(50, 50, 60, 255))
    master.paste(h_name, (16 + (250 - 192)//2, 274), h_name)

    draw.rectangle((290, 268, 290 + 250, 268 + 76), fill=(24, 24, 28, 255), outline=(50, 50, 60, 255))
    master.paste(t_name, (290 + (250 - 192)//2, 274), t_name)

    master_4x = master.resize((master.width * 2, master.height * 2), Image.NEAREST)
    out_path = os.path.join(ARTIFACT_DIR, "comprehensive_ui_evolution_showcase.png")
    master_4x.save(out_path)
    print(f"  -> Saved {out_path}")

if __name__ == "__main__":
    generate_menu_comparison()
    generate_stage_comparison()
    generate_boss_ui_comparison()
    generate_master_showcase()
