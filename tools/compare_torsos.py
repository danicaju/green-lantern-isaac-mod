from PIL import Image

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png").convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")

# Compare Frame 0:
# Isaac: (0, 64)
# Hal: (0, 64)

for frame in [0, 2, 4, 7]:
    x = frame * 32
    y = 64
    i_cell = isaac_img.crop((x, y, x + 32, y + 32))
    h_cell = hal_img.crop((x, y, x + 32, y + 32))
    print(f"\n--- Frame {frame} ---")
    print("Isaac Torso rows 12..20:")
    for cy in range(12, 21):
        line = ""
        for cx in range(6, 26):
            if i_cell.getpixel((cx, cy))[3] > 0:
                line += "#"
            else:
                line += " "
        print(f"  {cy}: {line}")
    print("Hal Torso rows 12..20:")
    for cy in range(12, 21):
        line = ""
        for cx in range(6, 26):
            if h_cell.getpixel((cx, cy))[3] > 0:
                line += "#"
            else:
                line += " "
        print(f"  {cy}: {line}")
