import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's check:
# 1. Polyphemus (costume_106_polyphemus.png)
# 2. Brimstone (costume_019_brimstone.png)
# 3. Growth Hormones (costume_028_growthhormones.png)
# 4. Belt (costume_015_belt.png)

costumes_to_test = [
    "costume_106_polyphemus.png",
    "costume_019_brimstone.png",
    "costume_028_growthhormones.png",
    "costume_015_belt.png",
]

for cname in costumes_to_test:
    cpath = os.path.join(costume_dir, cname)
    if not os.path.exists(cpath):
        print("Missing:", cname)
        continue
    cimg = Image.open(cpath).convert("RGBA")
    print(f"\nTesting costume: {cname}, size: {cimg.size}")
    
    # Check HeadRight / HeadSide in costume:
    # In player anm2, HeadRight uses XCrop=64, YCrop=0, W=32, H=32.
    # What does the costume have at (64, 0)?
    cell_64 = cimg.crop((64, 0, 96, 32))
    print(f"  Head cell (64, 0): bbox = {cell_64.getbbox()}")
    
    # In some costumes (64x64 format or 32x32 format):
    # Wait! Does the costume use 32x32 or 64x64 or 32-grid?
    # Let's inspect where non-empty pixels are in the costume
    non_empty = []
    for y in range(0, min(cimg.height, 128), 32):
        for x in range(0, min(cimg.width, 256), 32):
            b = cimg.crop((x, y, x + 32, y + 32)).getbbox()
            if b:
                non_empty.append(f"({x},{y}):{b}")
    print(f"  Non-empty 32x32 cells in {cname}: {non_empty[:8]}")
