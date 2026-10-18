import os
from PIL import Image

PROJECT_DIR = r"C:\Users\danic\Desktop\green_lantern_mod"
ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\d0abad69-7124-472e-9088-fe0a1a3473a9"

from test_generate_menu_portraits import create_hal_menu_portrait, create_tainted_menu_portrait

def build_menu_sheet(base_path, portrait_img):
    sheet = Image.open(base_path).convert("RGBA")
    
    # 1. Clear portrait crop area (56, 2, 104, 54)
    # Ensure zero dirty alpha in the area
    pix = sheet.load()
    for y in range(2, 54):
        for x in range(56, 104):
            pix[x, y] = (0, 0, 0, 0)
            
    # Also clean any stray pixels between Y=44 and Y=54 across the entire sheet
    for y in range(45, 54):
        for x in range(160):
            pix[x, y] = (0, 0, 0, 0)

    # 2. Paste new handmade portrait
    sheet.paste(portrait_img, (56, 2), portrait_img)

    # 3. Sanitize zero alpha channel everywhere
    for y in range(160):
        for x in range(160):
            if pix[x, y][3] == 0:
                pix[x, y] = (0, 0, 0, 0)

    return sheet

if __name__ == "__main__":
    h_port = create_hal_menu_portrait()
    t_port = create_tainted_menu_portrait()

    hal_sheet = build_menu_sheet(os.path.join(PROJECT_DIR, "content/gfx/hal_charactermenu.png"), h_port)
    t_sheet = build_menu_sheet(os.path.join(PROJECT_DIR, "content/gfx/tainted_charactermenu.png"), t_port)

    # Save test sheets to artifact dir
    hal_sheet.save(os.path.join(ARTIFACT_DIR, "test_hal_charactermenu.png"))
    t_sheet.save(os.path.join(ARTIFACT_DIR, "test_tainted_charactermenu.png"))

    print("Audit test sheets:")
    for name, sh in [("Hal Menu", hal_sheet), ("Tainted Menu", t_sheet)]:
        dirty = sum(1 for p in sh.getdata() if p[3] == 0 and p[:3] != (0, 0, 0))
        print(f"  {name}: size={sh.size}, bbox={sh.getbbox()}, dirty_alpha={dirty}")
