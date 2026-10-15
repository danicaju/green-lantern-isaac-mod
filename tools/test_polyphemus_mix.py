from PIL import Image
import os

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's pick 3 iconic items that change appearance:
# 1. Polyphemus (costume_106_polyphemus.png) -> giant single eye
# 2. Mutant Spider (costume_064_spiderbite.png or costume_045_mutantspider.png)
# 3. Growth Hormones or Puberty or Brimstone

mutant_files = [f for f in os.listdir(costume_dir) if "mutant" in f or "spider" in f]
print("Spider costumes:", mutant_files[:5])

# Let's inspect costume_106_polyphemus.png and costume_019_brimstone.png and costume_puberty.png
poly = Image.open(os.path.join(costume_dir, "costume_106_polyphemus.png")).convert("RGBA")

# In 001.000_player.anm2:
# HeadDown: base head is cell (0, 0, 32, 32) at XPos=0, YPos=-5, XPiv=16, YPiv=28
# HeadRight: base head is cell (64, 0, 96, 32) at XPos=0, YPos=-5, XPiv=16, YPiv=28
# HeadLeft: base head is cell (64, 0, 96, 32) at XPos=0, YPos=-5, XPiv=16, YPiv=28, XScale=-100
# Body WalkDown: cell (0, 32, 32, 64) at XPos=0, YPos=2, XPiv=16, YPiv=25
# Body WalkRight: cell (0, 64, 32, 96) at XPos=0, YPos=2, XPiv=16, YPiv=25
# Body WalkLeft: cell (0, 64, 32, 96) at XPos=0, YPos=2, XPiv=16, YPiv=25, XScale=-100

# In 169_Polyphemus.anm2:
# HeadDown: cell (0, 0, 32, 64) at XPos=0, YPos=-5, XPiv=16, YPiv=44
# HeadRight: cell (64, 0, 96, 64) at XPos=0, YPos=-5, XPiv=16, YPiv=44
# HeadLeft: cell (192, 0, 224, 64) at XPos=0, YPos=-5, XPiv=16, YPiv=44

# Let's composite Isaac, Hal, and THal with Polyphemus!
def composite_player(char_img, head_x, head_y, body_x, body_y, flip_head=False, flip_body=False, costume_img=None, cost_x=0, cost_y=0, cost_w=32, cost_h=32, cost_pivy=28):
    canvas = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    # Origin at (32, 36)
    ox, oy = 32, 36
    
    # Draw body: XPos=0, YPos=2, XPiv=16, YPiv=25
    b_cell = char_img.crop((body_x, body_y, body_x + 32, body_y + 32))
    if flip_body:
        b_cell = b_cell.transpose(Image.FLIP_LEFT_RIGHT)
    bx = ox - 16
    by = oy + 2 - 25
    canvas.paste(b_cell, (bx, by), b_cell)
    
    # Draw head: XPos=0, YPos=-5, XPiv=16, YPiv=28
    h_cell = char_img.crop((head_x, head_y, head_x + 32, head_y + 32))
    if flip_head:
        h_cell = h_cell.transpose(Image.FLIP_LEFT_RIGHT)
    hx = ox - 16
    hy = oy - 5 - 28
    canvas.paste(h_cell, (hx, hy), h_cell)
    
    # Draw costume if provided
    if costume_img:
        c_cell = costume_img.crop((cost_x, cost_y, cost_x + cost_w, cost_y + cost_h))
        cx = ox - cost_w // 2
        cy = oy - 5 - cost_pivy
        canvas.paste(c_cell, (cx, cy), c_cell)
        
    return canvas

# Composite Down, Right, Left for Isaac, Hal, THal:
# Without item:
# Down:
i_down = composite_player(isaac_img, 0, 0, 0, 32)
h_down = composite_player(hal_img, 0, 0, 0, 32)
t_down = composite_player(thal_img, 0, 0, 0, 32)

# Right:
i_right = composite_player(isaac_img, 64, 0, 0, 64)
h_right = composite_player(hal_img, 64, 0, 0, 64)
t_right = composite_player(thal_img, 64, 0, 0, 64)

# Left:
i_left = composite_player(isaac_img, 64, 0, 0, 64, flip_head=True, flip_body=True)
h_left = composite_player(hal_img, 64, 0, 0, 64, flip_head=True, flip_body=True)
t_left = composite_player(thal_img, 64, 0, 0, 64, flip_head=True, flip_body=True)

# With Polyphemus:
# Down:
i_down_p = composite_player(isaac_img, 0, 0, 0, 32, costume_img=poly, cost_x=0, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)
h_down_p = composite_player(hal_img, 0, 0, 0, 32, costume_img=poly, cost_x=0, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)
t_down_p = composite_player(thal_img, 0, 0, 0, 32, costume_img=poly, cost_x=0, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)

# Right:
i_right_p = composite_player(isaac_img, 64, 0, 0, 64, costume_img=poly, cost_x=64, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)
h_right_p = composite_player(hal_img, 64, 0, 0, 64, costume_img=poly, cost_x=64, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)
t_right_p = composite_player(thal_img, 64, 0, 0, 64, costume_img=poly, cost_x=64, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)

# Left:
i_left_p = composite_player(isaac_img, 64, 0, 0, 64, flip_head=True, flip_body=True, costume_img=poly, cost_x=192, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)
h_left_p = composite_player(hal_img, 64, 0, 0, 64, flip_head=True, flip_body=True, costume_img=poly, cost_x=192, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)
t_left_p = composite_player(thal_img, 64, 0, 0, 64, flip_head=True, flip_body=True, costume_img=poly, cost_x=192, cost_y=0, cost_w=32, cost_h=64, cost_pivy=44)

# Build a grid image: 6 columns x 3 rows
grid = Image.new("RGBA", (64 * 6, 64 * 3), (240, 240, 240, 255))
# Row 0: Isaac [Down, Right, Left, Down+Poly, Right+Poly, Left+Poly]
for col, img in enumerate([i_down, i_right, i_left, i_down_p, i_right_p, i_left_p]):
    grid.paste(img, (col * 64, 0), img)
# Row 1: Hal
for col, img in enumerate([h_down, h_right, h_left, h_down_p, h_right_p, h_left_p]):
    grid.paste(img, (col * 64, 64), img)
# Row 2: Tainted Hal
for col, img in enumerate([t_down, t_right, t_left, t_down_p, t_right_p, t_left_p]):
    grid.paste(img, (col * 64, 128), img)

grid.save("tools/costume_mix_test.png")
print("Saved tools/costume_mix_test.png")
