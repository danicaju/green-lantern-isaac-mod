from PIL import Image

isaac = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png")
hal = Image.open("resources/gfx/characters/hal_jordan.png")
thal = Image.open("resources/gfx/characters/tainted_hal.png")

print(f"Isaac dimensions: {isaac.size}")
print(f"Hal dimensions: {hal.size}")
print(f"THal dimensions: {thal.size}")

# Let's inspect each row of 32x32 in Isaac (512x512)
# Row 0 (Y=0): Heads (Down, Down2, Side, Side2, Up, Up2, ...)
# Row 1 (Y=32): WalkDown (10 frames)
# Row 2 (Y=64): WalkRight / WalkSide (10 frames)
# Row 3 (Y=96): WalkRight frame 8, 9, etc.
# Row 4 (Y=128): WalkUp (10 frames)?
# Let's check 001.000_player.anm2 animations to map every row!

# Let's print out what each animation in 001.000_player.anm2 uses!
import xml.etree.ElementTree as ET
tree = ET.parse(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\001.000_player.anm2")
root = tree.getroot()

mapping = {}
for anim in root.findall(".//Animations/Animation"):
    aname = anim.attrib.get("Name")
    for la in anim.findall("LayerAnimations/LayerAnimation"):
        lid = la.attrib.get("LayerId")
        frames = la.findall("Frame")
        if frames:
            f0 = frames[0]
            ycrop = f0.attrib.get("YCrop")
            w = f0.attrib.get("Width")
            h = f0.attrib.get("Height")
            key = f"YCrop={ycrop}, W={w}, H={h}"
            if key not in mapping:
                mapping[key] = []
            mapping[key].append(f"{aname} (L{lid})")

print("\n=== ANM2 ROW MAPPING ===")
for k, v in sorted(mapping.items()):
    print(f"{k}: {', '.join(v[:6])}")
