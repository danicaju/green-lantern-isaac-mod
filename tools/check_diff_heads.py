from PIL import Image

hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
head_down = hal_img.crop((0, 0, 32, 32))
head_side = hal_img.crop((64, 0, 96, 32))

diff_pixels = 0
for y in range(32):
    for x in range(32):
        if head_down.getpixel((x, y)) != head_side.getpixel((x, y)):
            diff_pixels += 1

print(f"Diff between HeadDown (0,0) and HeadSide (64,0) in Hal Jordan: {diff_pixels} pixels")

head_side2 = hal_img.crop((96, 0, 128, 32))
diff_pixels2 = 0
for y in range(32):
    for x in range(32):
        if head_side.getpixel((x, y)) != head_side2.getpixel((x, y)):
            diff_pixels2 += 1
print(f"Diff between HeadSide 1 (64,0) and HeadSide 2 (96,0) in Hal Jordan: {diff_pixels2} pixels")

thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")
thead_down = thal_img.crop((0, 0, 32, 32))
thead_side = thal_img.crop((64, 0, 96, 32))
diff_t = 0
for y in range(32):
    for x in range(32):
        if thead_down.getpixel((x, y)) != thead_side.getpixel((x, y)):
            diff_t += 1
print(f"Diff between HeadDown and HeadSide in Tainted Hal: {diff_t} pixels")
