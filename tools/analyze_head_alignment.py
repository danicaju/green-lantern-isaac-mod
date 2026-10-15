from PIL import Image

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png").convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's inspect the top pixel Y and horizontal center X of Isaac vs Hal vs THal for:
# 1. HeadDown (0, 0)
# 2. HeadSide f0 (64, 0)
# 3. HeadSide f1 (96, 0)

def analyze_top_and_center(name, img, x0, y0):
    cell = img.crop((x0, y0, x0 + 32, y0 + 32))
    px = cell.load()
    min_x, max_x = 32, 0
    min_y, max_y = 32, 0
    top_pixels = []
    for y in range(32):
        for x in range(32):
            if px[x, y][3] > 0:
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
    
    # top 3 rows of pixels
    for y in range(min_y, min_y + 3):
        for x in range(32):
            if px[x, y][3] > 0:
                top_pixels.append((x, y))
                
    center_x = (min_x + max_x) / 2.0
    top_center_x = sum(p[0] for p in top_pixels) / max(1, len(top_pixels))
    print(f"{name} ({x0},{y0}): bbox=({min_x}, {min_y}, {max_x}, {max_y}), Top_Y={min_y}, Center_X={center_x:.2f}, Top_Center_X={top_center_x:.2f}")

print("=== HEAD DOWN (0, 0) ===")
analyze_top_and_center("Isaac HeadDown", isaac_img, 0, 0)
analyze_top_and_center("Hal HeadDown", hal_img, 0, 0)
analyze_top_and_center("THal HeadDown", thal_img, 0, 0)

print("\n=== HEAD SIDE FRAME 0 (64, 0) ===")
analyze_top_and_center("Isaac HeadSide f0", isaac_img, 64, 0)
analyze_top_and_center("Hal HeadSide f0", hal_img, 64, 0)
analyze_top_and_center("THal HeadSide f0", thal_img, 64, 0)

print("\n=== HEAD SIDE FRAME 1 (96, 0) ===")
analyze_top_and_center("Isaac HeadSide f1", isaac_img, 96, 0)
analyze_top_and_center("Hal HeadSide f1", hal_img, 96, 0)
analyze_top_and_center("THal HeadSide f1", thal_img, 96, 0)
