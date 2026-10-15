import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"

def print_ascii_char(filename):
    print(f"\n--- {filename} at (64, 0) ---")
    path = os.path.join(costume_dir, filename)
    img = Image.open(path).convert("RGBA")
    cell = img.crop((64, 0, 96, 32))
    px = cell.load()
    for y in range(0, 32):
        line = ""
        for x in range(0, 32):
            r, g, b, a = px[x, y]
            if a < 10:
                line += " "
            elif r < 40 and g < 40 and b < 40:
                line += "#"
            elif r > 200 and g > 200 and b > 200:
                line += "."
            else:
                line += "+"
        if line.strip():
            print(f"{y:02d}: {line}")

print_ascii_char("character_003_cain.png")
print_ascii_char("character_004_judas.png")
