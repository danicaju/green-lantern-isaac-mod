from PIL import Image

def inspect_pixels(img, name, x0, y0):
    print(f"\n--- {name} ({x0},{y0}) ---")
    cell = img.crop((x0, y0, x0 + 32, y0 + 32))
    px = cell.load()
    for y in range(0, 32):
        line = ""
        for x in range(0, 32):
            r, g, b, a = px[x, y]
            if a < 10:
                line += " "
            elif r < 50 and g < 50 and b < 50:
                line += "#"
            elif r > 200 and g > 200 and b > 200:
                line += "."
            elif g > 150 and r < 100:
                line += "G"
            else:
                line += "+"
        if line.strip():
            print(f"{y:02d}: {line}")

hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
inspect_pixels(hal_img, "Hal HeadDown", 0, 0)
inspect_pixels(hal_img, "Hal HeadSide", 64, 0)
