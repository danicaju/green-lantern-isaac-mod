import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's inspect the side head frames (64, 0) and (96, 0)
# We want to see:
# 1. Base head (64, 0)
# 2. Base head with Polyphemus (106)
# 3. Base head with Inner Eye (002)
# 4. Base head with Growth Hormones (028)
# 5. Base head with Brimstone (019)

items = [
    ("No Item", None, 0),
    ("Polyphemus", "costume_106_polyphemus.png", 64),
    ("Inner Eye", "costume_002_theinner_eye.png", 64),
    ("Growth Hormones", "costume_028_growthhormones.png", 64),
    ("Brimstone", "costume_019_brimstone.png", 0), # brimstone head is 64x64
]

# Create a composite canvas: 5 items x 3 characters (Isaac, Hal, THal) x 2 directions (Right, Left)
# Cell size 32x32, 6 columns per item: [Isaac R, Hal R, THal R, Isaac L, Hal L, THal L]
cell_w, cell_h = 32, 32
canvas = Image.new("RGBA", (cell_w * 6, cell_h * len(items)), (230, 230, 230, 255))

for row, (name, cfile, cx) in enumerate(items):
    cimg = None
    if cfile:
        cpath = os.path.join(costume_dir, cfile)
        if os.path.exists(cpath):
            cimg = Image.open(cpath).convert("RGBA")
            
    # Isaac
    i_r = isaac_img.crop((64, 0, 96, 32))
    h_r = hal_img.crop((64, 0, 96, 32))
    t_r = thal_img.crop((64, 0, 96, 32))
    
    if cimg:
        # crop costume for Right:
        # In 001.000_player.anm2, HeadRight is at XPos=0, YPos=-5, XPiv=16, YPiv=28
        # If costume is 32x64, top 32 is row 0:
        cc_r = cimg.crop((cx, 0, cx + 32, 32))
        i_r = Image.alpha_composite(i_r, cc_r)
        h_r = Image.alpha_composite(h_r, cc_r)
        t_r = Image.alpha_composite(t_r, cc_r)
        
    i_l = i_r.transpose(Image.FLIP_LEFT_RIGHT)
    h_l = h_r.transpose(Image.FLIP_LEFT_RIGHT)
    t_l = t_r.transpose(Image.FLIP_LEFT_RIGHT)
    
    y = row * cell_h
    canvas.paste(i_r, (0 * cell_w, y), i_r)
    canvas.paste(h_r, (1 * cell_w, y), h_r)
    canvas.paste(t_r, (2 * cell_w, y), t_r)
    canvas.paste(i_l, (3 * cell_w, y), i_l)
    canvas.paste(h_l, (4 * cell_w, y), h_l)
    canvas.paste(t_l, (5 * cell_w, y), t_l)

canvas_zoom = canvas.resize((canvas.width * 4, canvas.height * 4), Image.NEAREST)
canvas_zoom.save("tools/costumes_comparison_side_zoom4x.png")
print("Saved tools/costumes_comparison_side_zoom4x.png")
