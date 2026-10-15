import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"

vanilla_chars = [
    "character_001_isaac.png",
    "character_002_magdalene.png",
    "character_003_cain.png",
    "character_004_judas.png",
    "character_005_eve.png",
    "character_007_samson.png",
    "character_008_azazel.png",
    "character_012_lazarus.png",
    "character_014_keeper.png",
    "character_015_apollyon.png",
    "character_001x_bethany.png",
    "character_002x_jacob.png",
]

print("=== CHECKING VANILLA CHARACTERS AT CELL (64, 0) ===")
for vc in vanilla_chars:
    path = os.path.join(costume_dir, vc)
    if not os.path.exists(path):
        continue
    img = Image.open(path).convert("RGBA")
    cell = img.crop((64, 0, 96, 32))
    bbox = cell.getbbox()
    print(f"{vc}: bbox={bbox}")
