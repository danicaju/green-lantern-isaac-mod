from PIL import Image

hal_extra = Image.open("resources/gfx/characters/hal_jordan_extra.png")
thal_extra = Image.open("resources/gfx/characters/tainted_hal_extra.png")

print("hal_extra size:", hal_extra.size)
print("thal_extra size:", thal_extra.size)

# Check non-empty cells in hal_extra and thal_extra
def inspect_extra(img, name):
    print(f"\n--- {name} non-empty 32x32 cells ---")
    w, h = img.size
    for y in range(0, h, 32):
        row_c = []
        for x in range(0, w, 32):
            b = img.crop((x, y, x + 32, y + 32)).getbbox()
            if b:
                row_c.append(f"X={x}:{b}")
        if row_c:
            print(f"Y={y}: " + " | ".join(row_c[:6]))

inspect_extra(hal_extra, "hal_jordan_extra.png")
inspect_extra(thal_extra, "tainted_hal_extra.png")
