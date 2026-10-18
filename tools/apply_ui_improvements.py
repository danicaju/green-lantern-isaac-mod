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
    build_perfect_hal_boss,
    build_perfect_tainted_boss,
    sanitize_zero_dirty_alpha,
)
from build_menu_sheets import build_menu_sheet

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(TOOLS_DIR)

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

    # 3. Boss UI Sprites (Dedicated 112x80 VS confrontation portraits)
    print("\n[3/3] Generating Boss UI Portraits (112x80) & Sanitizing Names...")
    h_boss = build_perfect_hal_boss()
    t_boss = build_perfect_tainted_boss()

    hal_boss_path = os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/portrait_hal_jordan.png")
    t_boss_path = os.path.join(PROJECT_DIR, "resources/gfx/ui/boss/portrait_tainted_hal.png")

    h_boss.save(hal_boss_path)
    t_boss.save(t_boss_path)
    print("  -> Saved resources/gfx/ui/boss/portrait_hal_jordan.png (112x80)")
    print("  -> Saved resources/gfx/ui/boss/portrait_tainted_hal.png (112x80)")

    # Sanitize names
    for name_rel in ["resources/gfx/ui/boss/name_hal_jordan.png", "resources/gfx/ui/boss/name_tainted_hal.png"]:
        full_p = os.path.join(PROJECT_DIR, name_rel)
        name_img = Image.open(full_p)
        clean_name = sanitize_zero_dirty_alpha(name_img)
        clean_name.save(full_p)
        print(f"  -> Sanitized {name_rel}")

    print("\n" + "=" * 60)
    print("VERIFYING SANITIZATION ACROSS ALL TARGET ASSETS")
    print("=" * 60)
    target_specs = [
        ("content/gfx/hal_charactermenu.png", (160, 160)),
        ("content/gfx/tainted_charactermenu.png", (160, 160)),
        ("resources/gfx/ui/stage/stage_hal_jordan.png", (144, 144)),
        ("resources/gfx/ui/stage/stage_tainted_hal.png", (144, 144)),
        ("resources/gfx/ui/boss/portrait_hal_jordan.png", (112, 80)),
        ("resources/gfx/ui/boss/portrait_tainted_hal.png", (112, 80)),
        ("resources/gfx/ui/boss/name_hal_jordan.png", (192, 64)),
        ("resources/gfx/ui/boss/name_tainted_hal.png", (192, 64)),
    ]

    all_clean = True
    for rel, exp_size in target_specs:
        full_p = os.path.join(PROJECT_DIR, rel)
        im = Image.open(full_p)
        w, h = im.size
        pix = im.load()

        if (w, h) != exp_size:
            print(f"[FAIL] {rel}: expected size {exp_size}, got {(w, h)}")
            all_clean = False

        dirty_count = 0
        for y in range(h):
            for x in range(w):
                p = pix[x, y]
                if p[3] == 0 and p[:3] != (0, 0, 0):
                    dirty_count += 1

        if dirty_count > 0:
            print(f"[FAIL] {rel}: has {dirty_count} dirty alpha pixels!")
            all_clean = False
        else:
            bbox = im.getbbox()
            print(f"[PASS] {rel} | size={im.size} | bbox={bbox} | dirty_alpha=0")

    if all_clean:
        print("\nALL 8 TARGET ASSETS VERIFIED PERFECT!")
    else:
        print("\nSOME ASSETS FAILED VERIFICATION!")

if __name__ == "__main__":
    apply_all()
