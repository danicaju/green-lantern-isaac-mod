from PIL import Image

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png")

print(f"Isaac size: {isaac_img.size}")
print(f"Hal size: {hal_img.size}")
print(f"Tainted Hal size: {thal_img.size}")

# Let's inspect rows and columns:
# Row 0: Y=0..32 (Heads)
# In Isaac:
# X=0..32: Head Down 1
# X=32..64: Head Down 2
# X=64..96: Head Side 1
# X=96..128: Head Side 2
# X=128..160: Head Up 1
# X=160..192: Head Up 2
# X=192..224: ???
# X=224..256: ???
# Let's inspect non-empty bounding boxes of each 32x32 cell in row 0, 1, 2, 3!

def inspect_sheet(name, img):
    print(f"\n=== {name} ===")
    w, h = img.size
    for y in range(0, min(h, 256), 32):
        row_cells = []
        for x in range(0, min(w, 512), 32):
            cell = img.crop((x, y, x + 32, y + 32))
            bbox = cell.getbbox()
            if bbox:
                row_cells.append(f"X={x}:{bbox}")
            else:
                row_cells.append(f"X={x}:empty")
        print(f"Y={y}: " + " | ".join(row_cells[:8]))

inspect_sheet("Vanilla Isaac", isaac_img)
inspect_sheet("Hal Jordan", hal_img)
inspect_sheet("Tainted Hal", thal_img)
