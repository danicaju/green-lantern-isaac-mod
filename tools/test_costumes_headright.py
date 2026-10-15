import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's test 6 costumes:
# 1. costume_002_theinner_eye.png
# 2. costume_028_growthhormones.png
# 3. costume_034_thebookofbelial.png
# 4. costume_064_spiderbite.png
# 5. costume_019_brimstone.png
# 6. costume_puberty.png

test_items = [
    ("Inner Eye", "costume_002_theinner_eye.png"),
    ("Growth Hormones", "costume_028_growthhormones.png"),
    ("Brimstone", "costume_019_brimstone.png"),
    ("Puberty", "costume_puberty.png"),
]

# Let's check how they look in HeadRight (Cell 64, 0)
# Canvas width: 32 * 4 (Isaac, Hal, THal, Costume alone), height: 32 * len(test_items)
out = Image.new("RGBA", (32 * 4, 32 * len(test_items)), (230, 230, 230, 255))

for row_idx, (name, fname) in enumerate(test_items):
    fpath = os.path.join(costume_dir, fname)
    if not os.path.exists(fpath):
        continue
    cimg = Image.open(fpath).convert("RGBA")
    
    # In player anm2, HeadRight is at (64, 0)
    # Most costumes have HeadRight at (64, 0) or (128, 0) depending on whether they are 32-wide or 64-wide
    # Let's inspect where the costume has HeadRight:
    # Check 169_Polyphemus had (64, 0), 070_Growth had (64, 0), Puberty had (64, 0) or (128, 0)
    # Let's find non-empty cell in row 0:
    cost_cell = None
    for cand_x in [64, 128, 0]:
        cand = cimg.crop((cand_x, 0, cand_x + 32, 32))
        if cand.getbbox():
            cost_cell = cand
            break
    if not cost_cell:
        cost_cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        
    i_head = isaac_img.crop((64, 0, 96, 32))
    h_head = hal_img.crop((64, 0, 96, 32))
    t_head = thal_img.crop((64, 0, 96, 32))
    
    # Composite:
    i_comp = Image.alpha_composite(i_head, cost_cell)
    h_comp = Image.alpha_composite(h_head, cost_cell)
    t_comp = Image.alpha_composite(t_head, cost_cell)
    
    y = row_idx * 32
    out.paste(i_comp, (0, y), i_comp)
    out.paste(h_comp, (32, y), h_comp)
    out.paste(t_comp, (64, y), t_comp)
    out.paste(cost_cell, (96, y), cost_cell)

out_zoom = out.resize((out.width * 4, out.height * 4), Image.NEAREST)
out_zoom.save("tools/costumes_headright_zoom4x.png")
print("Saved tools/costumes_headright_zoom4x.png")
