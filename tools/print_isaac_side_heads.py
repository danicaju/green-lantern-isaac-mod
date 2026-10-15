from PIL import Image

isaac = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png")
c0 = isaac.crop((64, 0, 96, 32))
c1 = isaac.crop((96, 0, 128, 32))

print("=== ISAAC CELL (64, 0) ===")
for y in range(32):
    row_str = ""
    for x in range(32):
        r, g, b, a = c0.getpixel((x, y))
        if a == 0:
            row_str += " "
        elif (r, g, b) == (0, 0, 0) or (r < 30 and g < 30 and b < 30):
            row_str += "#" # black outline
        elif (r, g, b) == (255, 255, 255):
            row_str += "." # white eye highlight
        elif r > 200 and g > 150:
            row_str += "s" # skin
        else:
            row_str += "+" # shadow / blush
    if row_str.strip():
        print(f"{y:02d}: {row_str}")

print("\n=== ISAAC CELL (96, 0) ===")
for y in range(32):
    row_str = ""
    for x in range(32):
        r, g, b, a = c1.getpixel((x, y))
        if a == 0:
            row_str += " "
        elif (r, g, b) == (0, 0, 0) or (r < 30 and g < 30 and b < 30):
            row_str += "#" # black outline
        elif (r, g, b) == (255, 255, 255):
            row_str += "." # white eye highlight
        elif r > 200 and g > 150:
            row_str += "s" # skin
        else:
            row_str += "+" # shadow / blush
    if row_str.strip():
        print(f"{y:02d}: {row_str}")
