import glob
import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"

body_costumes = [
    "costume_028_thebelt.png",
    "costume_029_momsunderwear.png",
    "costume_030_momsheels.png",
    "costume_080_thepact.png",
    "costume_046_luckyfoot.png",
]

for bc in body_costumes:
    path = os.path.join(costume_dir, bc)
    if os.path.exists(path):
        img = Image.open(path).convert("RGBA")
        print(f"\nBody costume: {bc}, size: {img.size}")
        # check row 2 (Y=64..96)
        w, h = img.size
        cells = []
        for x in range(0, min(w, 320), 32):
            cell = img.crop((x, 64, x + 32, min(h, 96)))
            bbox = cell.getbbox()
            if bbox:
                cells.append(f"X={x}:{bbox}")
        print("  Row 2 (Y=64..96): " + " | ".join(cells[:6]))
