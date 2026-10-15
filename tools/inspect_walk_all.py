from PIL import Image

isaac = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png")
hal = Image.open("resources/gfx/characters/hal_jordan.png")
thal = Image.open("resources/gfx/characters/tainted_hal.png")

# Let's inspect Isaac's WalkRight frames:
# Frame 0: (0, 64)
# Frame 1: (32, 64)
# ...
# Frame 9: (32, 96)

# Let's print out what the body looks like across all 10 frames
# Specifically: where does the body start and end horizontally and vertically?
walk_coords = [
    (0, 64), (32, 64), (64, 64), (96, 64), (128, 64),
    (160, 64), (192, 64), (224, 64), (0, 96), (32, 96)
]

print("=== ISAAC WALKRIGHT 10 FRAMES ===")
for i, (x, y) in enumerate(walk_coords):
    cell = isaac.crop((x, y, x + 32, y + 32))
    print(f"Frame {i}: bbox={cell.getbbox()}")

print("\n=== HAL WALKRIGHT 10 FRAMES ===")
for i, (x, y) in enumerate(walk_coords):
    cell = hal.crop((x, y, x + 32, y + 32))
    print(f"Frame {i}: bbox={cell.getbbox()}")
