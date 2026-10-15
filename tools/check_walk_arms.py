from PIL import Image

isaac = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png")
hal = Image.open("resources/gfx/characters/hal_jordan.png")
thal = Image.open("resources/gfx/characters/tainted_hal.png")

# Let's inspect Hal's body at Y=64, X=0..320
# And THal's body at Y=64, X=0..320
# In Isaac, the walking body has legs walking and arms swinging naturally.
# What does Hal's walking body have?
# Let's see: Hal has an arm jutting out with a fist and ring!
# Does Hal have an extended fist on ALL 10 frames of WalkRight?

def check_extended_arm(img, name):
    print(f"\n--- Checking {name} WalkRight frames (Y=64) ---")
    for f in range(10):
        if f < 8:
            x = f * 32
            y = 64
        else:
            x = (f - 8) * 32
            y = 96
        cell = img.crop((x, y, x + 32, y + 32))
        px = cell.load()
        # check columns 20..31 in rows 12..20 (where the fist would be)
        fist_pixels = []
        for cy in range(12, 21):
            for cx in range(20, 32):
                if px[cx, cy][3] > 10:
                    fist_pixels.append((cx, cy, px[cx, cy]))
        print(f"  Frame {f} at ({x},{y}): {len(fist_pixels)} pixels in right-arm area (X=20..31)")

check_extended_arm(isaac, "Vanilla Isaac")
check_extended_arm(hal, "Hal Jordan")
check_extended_arm(thal, "Tainted Hal")
