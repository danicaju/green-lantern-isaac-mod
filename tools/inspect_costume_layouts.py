import glob
import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"

# Let's inspect some popular costumes:
# 1. brimstone
# 2. mutant spider
# 3. the inner eye
# 4. puberty
# 5. steven

sample_costumes = [
    "costume_puberty.png",
    "costume_002_theinner_eye.png",
    "costume_008_myreflection.png",
    "costume_019_boom.png",
    "costume_034_thebookofbelial.png",
    "costume_067_growthhormones.png",
]

for sc in sample_costumes:
    path = os.path.join(costume_dir, sc)
    if os.path.exists(path):
        img = Image.open(path).convert("RGBA")
        print(f"\nCostume: {sc}, size: {img.size}")
        # Check cell (128, 0, 192, 64) or whatever HeadRight is
        # Wait, let's see where the non-empty cells are in row 0
        w, h = img.size
        cells = []
        for x in range(0, min(w, 512), 32):
            cell = img.crop((x, 0, x + 32, min(h, 32)))
            bbox = cell.getbbox()
            if bbox:
                cells.append(f"X={x}:{bbox}")
        print("  Row 0 (32x32): " + " | ".join(cells[:8]))
