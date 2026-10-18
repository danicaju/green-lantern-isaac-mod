"""
tools/apply_ui_improvements.py
Master script to apply improved Character Menu portraits, Stage Nightmare transitions,
and Boss UI sprites for both Hal Jordan and Tainted Hal.
"""

import os
from PIL import Image
from build_perfect_ui_sprites import (
    build_hal_menu_portrait,
    build_tainted_menu_portrait,
    build_perfect_hal_stage,
    build_perfect_tainted_stage,
)
from build_menu_sheets import build_menu_sheet

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def sanitize_alpha(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pix = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            if pix[x, y][3] == 0:
                pix[x, y] = (0, 0, 0, 0)
    return rgba

def apply_all():
    print("=" * 60)
    print("APPLYING PERFECT HANDMADE UI ASSET IMPROVEMENTS")
    print("=" * 60)

    # 1. Character Menu Portraits
    print("\n[1/3] Generating Character Menu Portraits (160x160)...")
    h_port = build_hal_menu_portrait()
    t_port = build_tainted_menu_portrait()

    hal_menu_path = os.path.join(PROJECT_DIR, "content/gfx/hal_charactermenu.png")
    t_menu_path = os.path.join(PROJECT_DIR, "content/gfx/tainted_charactermenu.png")

    hal_menu_sheet = build_menu_sheet(hal_menu_path, h_port)
    t_menu_sheet = build_menu_sheet(t_menu_path, t_port)

    hal_menu_sheet.save(hal_menu_path)
    t_menu_sheet.save(t_menu_path)
    print("  -> Saved content/gfx/hal_charactermenu.png")
    print("  -> Saved content/gfx/tainted_charactermenu.png")

    # 2. Stage Transition Sprites
    print("\n[2/3] Generating Stage Transition Nightmare Sprites (144x144)...")
    h_stage = build_perfect_hal_stage()
    t_stage = build_perfect_tainted_stage()

    hal_stage_path = os.path.join(PROJECT_DIR, "resources/gfx/ui/stage/stage_hal_jordan.png")
    t_stage_path = os.path.join(PROJECT_DIR, "resources/gfx/ui/stage/stage_tainted_hal.png")

    h_stage.save(hal_stage_path)
    t_stage.save(t_stage_path)
    print("  -> Saved resources/gfx/ui/stage/stage_hal_jordan.png")
    print("  -> Saved resources/gfx/ui/stage/stage_tainted_hal.png")

    # 3. Boss UI Sprites
    print("\n[3/3] Generating Boss UI Portraits & Sanitizing Names...")
    hal_boss_path = os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/portrait_hal_jordan.png")
    t_boss_path = os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/portrait_tainted_hal.png")

    h_stage.save(hal_boss_path)
    t_stage.save(t_boss_path)
    print("  -> Saved resources/gfx/ui/boss/portrait_hal_jordan.png")
    print("  -> Saved resources/gfx/ui/boss/portrait_tainted_hal.png")

    # Sanitize names
    for name_rel in ["resources/gfx/ui/boss/name_hal_jordan.png", "resources/gfx/ui/boss/name_tainted_hal.png"]:
        full_p = os.path.join(PROJECT_DIR, name_rel)
        name_img = Image.open(full_p)
        clean_name = sanitize_alpha(name_img)
        clean_name.save(full_p)
        print(f"  -> Sanitized {name_rel}")

    print("\n" + "=" * 60)
    print("VERIFYING SANITIZATION ACROSS ALL TARGET ASSETS")
    print("=" * 60)
    all_target_assets = [
        "content/gfx/hal_charactermenu.png",
        "content/gfx/tainted_charactermenu.png",
        "resources/gfx/ui/stage/stage_hal_jordan.png",
        "resources/gfx/ui/stage/stage_tainted_hal.png",
        "resources/gfx/ui/boss/portrait_hal_jordan.png",
        "resources/gfx/ui/boss/portrait_tainted_hal.png",
        "resources/gfx/ui/boss/name_hal_jordan.png",
        "resources/gfx/ui/boss/name_tainted_hal.png",
    ]

    all_clean = True
    for rel in all_target_assets:
        full_p = os.path.join(PROJECT_DIR, rel)
        im = Image.open(full_p)
        w, h = im.size
        pix = im.load()
        dirty = 0
        for y in range(h):
            for x in range(w):
                p = pix[x, y]
                if p[3] == 0 and p[:3] != (0, 0, 0):
                    dirty += 1
        colors = im.getcolors(maxcolors=2000)
        col_count = len(colors) if colors else ">2000"
        print(f"  {rel:<48} Size={str(im.size):<10} BBox={str(im.getbbox()):<22} Colors={str(col_count):<6} DirtyAlpha={dirty}")
        if dirty > 0:
            all_clean = False

    if all_clean:
        print("\nAll 8 UI assets successfully verified with ZERO dirty alpha!")
    else:
        print("\nWarning: Some assets have dirty alpha!")

if __name__ == "__main__":
    apply_all()
