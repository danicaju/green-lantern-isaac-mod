from PIL import Image

grid = Image.open("tools/costume_mix_test.png")

# Let's crop:
# Col 1: Hal Right (no item)
# Col 4: Hal Right + Poly
# Col 2: Hal Left (no item)
# Col 5: Hal Left + Poly
# Row 0: Isaac, Row 1: Hal, Row 2: THal

# Let's inspect the pixels of Hal Right + Poly and THal Right + Poly:
# In Hal Right + Poly (Row 1, Col 4 -> X=256..320, Y=64..128)
hal_right_poly = grid.crop((256, 64, 320, 128))
thal_right_poly = grid.crop((256, 128, 320, 192))
isaac_right_poly = grid.crop((256, 0, 320, 64))

# Let's inspect how many eyes are visible in Hal Right + Poly!
# In Hal's head, the eyes are green domino mask (#00d050 or similar) and white slit (#ffffff)
# Polyphemus eye is a large black pupil with white highlight and red veins, positioned around center/right.
# Where is Hal's left eye?
# Hal's head at (64, 0) had:
# Eye 1: columns 8..13
# Eye 2: columns 21..25
# In the composite (head placed at ox-16 = 32-16 = 16):
# Eye 1 is at X = 16 + 8..13 = 24..29!
# Polyphemus eye at (64, 0) has bbox (2, 18, 30, 32). In 64x64 at cx = ox - 16 = 16:
# Where does Polyphemus cover?
# Let's inspect the pixels of hal_right_poly!

for y in range(10, 40):
    line = ""
    for x in range(16, 48):
        r, g, b, a = hal_right_poly.getpixel((x, y))
        if a < 10:
            line += " "
        elif g > 150 and r < 100:
            line += "G" # Hal's green mask!
        elif r > 200 and g > 200 and b > 200:
            line += "." # white
        elif r < 50 and g < 50 and b < 50:
            line += "#" # black outline/pupil
        else:
            line += "+"
    if "G" in line or "." in line:
        print(f"Y={y:02d}: {line}")
