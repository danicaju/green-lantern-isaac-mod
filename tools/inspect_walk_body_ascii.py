from PIL import Image

def inspect_pixels_rgb(img, name, x0, y0):
    print(f"\n--- {name} ({x0},{y0}) ---")
    cell = img.crop((x0, y0, x0 + 32, y0 + 32))
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
            elif g > 150 and r < 100:
                line += "G"
            elif r > 180 and g > 150 and b > 120:
                line += "s" # skin
            else:
                line += "+"
        if line.strip():
            print(f"{y:02d}: {line}")

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png").convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

print("=== ISAAC BODY WALK SIDE 0 (0, 64) ===")
inspect_pixels_rgb(isaac_img, "Isaac WalkSide0", 0, 64)
print("=== HAL BODY WALK SIDE 0 (0, 64) ===")
inspect_pixels_rgb(hal_img, "Hal WalkSide0", 0, 64)
print("=== THAL BODY WALK SIDE 0 (0, 64) ===")
inspect_pixels_rgb(thal_img, "THal WalkSide0", 0, 64)
