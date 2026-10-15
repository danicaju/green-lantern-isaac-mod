import os
from PIL import Image

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png").convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's inspect the palette and pixels of Hal's current WalkRight frames vs Isaac's:
# In Hal's current WalkRight frames:
# Notice that Hal's legs DO animate, but the upper body has the static fist sticking out!
# Let's verify: does Hal's lower body (legs/boots) animate across the 10 frames?
# Let's check!

for f in range(10):
    x = f * 32 if f < 8 else (f - 8) * 32
    y = 64 if f < 8 else 96
    cell = hal_img.crop((x, y, x + 32, y + 32))
    # check row 21..25 (legs)
    leg_pixels = []
    for ly in range(20, 26):
        for lx in range(0, 32):
            if cell.getpixel((lx, ly))[3] > 0:
                leg_pixels.append((lx, ly))
    print(f"Hal Frame {f}: {len(leg_pixels)} leg pixels, min_x={min(p[0] for p in leg_pixels)}, max_x={max(p[0] for p in leg_pixels)}")
