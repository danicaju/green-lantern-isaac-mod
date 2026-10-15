from PIL import Image

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png").convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# WalkRight has 10 frames:
# Frame 0: (0, 64)
# Frame 1: (32, 64)
# Frame 2: (64, 64)
# Frame 3: (96, 64)
# Frame 4: (128, 64)
# Frame 5: (160, 64)
# Frame 6: (192, 64)
# Frame 7: (224, 64)
# Frame 8: (0, 96)
# Frame 9: (32, 96)

walk_coords = [
    (0, 64), (32, 64), (64, 64), (96, 64), (128, 64),
    (160, 64), (192, 64), (224, 64), (0, 96), (32, 96)
]

print("=== COMPARING WALKRIGHT FRAMES ===")
for i, (x, y) in enumerate(walk_coords):
    ibox = isaac_img.crop((x, y, x + 32, y + 32)).getbbox()
    hbox = hal_img.crop((x, y, x + 32, y + 32)).getbbox()
    tbox = thal_img.crop((x, y, x + 32, y + 32)).getbbox()
    print(f"Frame {i} at ({x},{y}): Isaac={ibox} | Hal={hbox} | THal={tbox}")
