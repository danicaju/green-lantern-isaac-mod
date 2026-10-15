from PIL import Image

hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")
isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png").convert("RGBA")

# Let's save a clear visual comparison of Isaac, Hal, and THal for:
# Cell (0, 0): Head Down
# Cell (64, 0): Head Side
# Cell (128, 0): Head Up
# Cell (0, 64): Walk Side 0

comp = Image.new("RGBA", (32 * 4, 32 * 3), (255, 255, 255, 255))

for col, (x, y) in enumerate([(0, 0), (64, 0), (128, 0), (0, 64)]):
    comp.paste(isaac_img.crop((x, y, x + 32, y + 32)), (col * 32, 0), isaac_img.crop((x, y, x + 32, y + 32)))
    comp.paste(hal_img.crop((x, y, x + 32, y + 32)), (col * 32, 32), hal_img.crop((x, y, x + 32, y + 32)))
    comp.paste(thal_img.crop((x, y, x + 32, y + 32)), (col * 32, 64), thal_img.crop((x, y, x + 32, y + 32)))

comp_zoom = comp.resize((comp.width * 4, comp.height * 4), Image.NEAREST)
comp_zoom.save("tools/side_comparison_zoom4x.png")
print("Saved tools/side_comparison_zoom4x.png")
