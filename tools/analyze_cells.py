from PIL import Image
import os

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png").convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's inspect the side head:
# In Isaac, cell (64, 0, 96, 32) is HeadRight frame 0.
# In Isaac, cell (96, 0, 128, 32) is HeadRight frame 1.
# Let's inspect where Isaac's eyes, chin, top of head, back of head are!
# And compare to Hal Jordan and Tainted Hal!

def analyze_cell(img, name, x0, y0, w=32, h=32):
    cell = img.crop((x0, y0, x0 + w, y0 + h))
    pixels = cell.load()
    # Find bounding box
    min_x, max_x, min_y, max_y = 32, 0, 32, 0
    for y in range(h):
        for x in range(w):
            if pixels[x, y][3] > 10:
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
    print(f"{name} ({x0},{y0}): bbox=({min_x}, {min_y}, {max_x}, {max_y}), width={max_x - min_x + 1}, height={max_y - min_y + 1}")

print("=== HEAD DOWN (0,0) ===")
analyze_cell(isaac_img, "Isaac HeadDown", 0, 0)
analyze_cell(hal_img, "Hal HeadDown", 0, 0)
analyze_cell(thal_img, "THal HeadDown", 0, 0)

print("\n=== HEAD SIDE (64,0) ===")
analyze_cell(isaac_img, "Isaac HeadSide", 64, 0)
analyze_cell(hal_img, "Hal HeadSide", 64, 0)
analyze_cell(thal_img, "THal HeadSide", 64, 0)

print("\n=== HEAD SIDE FRAME 2 (96,0) ===")
analyze_cell(isaac_img, "Isaac HeadSide2", 96, 0)
analyze_cell(hal_img, "Hal HeadSide2", 96, 0)
analyze_cell(thal_img, "THal HeadSide2", 96, 0)

print("\n=== HEAD UP (128,0) ===")
analyze_cell(isaac_img, "Isaac HeadUp", 128, 0)
analyze_cell(hal_img, "Hal HeadUp", 128, 0)
analyze_cell(thal_img, "THal HeadUp", 128, 0)

print("\n=== WALK SIDE FRAME 0 (0,64) ===")
analyze_cell(isaac_img, "Isaac WalkSide0", 0, 64)
analyze_cell(hal_img, "Hal WalkSide0", 0, 64)
analyze_cell(thal_img, "THal WalkSide0", 0, 64)

print("\n=== WALK SIDE FRAME 1 (32,64) ===")
analyze_cell(isaac_img, "Isaac WalkSide1", 32, 64)
analyze_cell(hal_img, "Hal WalkSide1", 32, 64)
analyze_cell(thal_img, "THal WalkSide1", 32, 64)
