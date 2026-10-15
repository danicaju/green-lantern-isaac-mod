from PIL import Image

belt_img = Image.open("tools/belt_walkright_zoom4x.png")

# Let's inspect the ascii of:
# Belt alone:
costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
belt = Image.open(f"{costume_dir}/costume_015_belt.png").convert("RGBA")
bcell = belt.crop((0, 0, 32, 32))
px = bcell.load()

print("=== BELT ALONE ===")
for y in range(32):
    line = ""
    for x in range(32):
        if px[x, y][3] > 10:
            line += "B"
        else:
            line += " "
    if line.strip():
        print(f"{y:02d}: {line}")
