from PIL import Image

isaac_img = Image.open(r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes\Character_001_Isaac.png")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png")

# Save crops of Isaac vs Hal vs Tainted Hal
# Row 0: HeadDown (0..32, 32..64), HeadSide (64..96, 96..128), HeadUp (128..160, 160..192)
# Row 2 (Y=64): WalkSide / WalkRight (X=0..32, 32..64, etc.)

preview = Image.new("RGBA", (32 * 8, 32 * 6), (0, 0, 0, 0))

# Row 0: Isaac Heads
preview.paste(isaac_img.crop((0, 0, 32 * 8, 32)), (0, 0))
# Row 1: Hal Heads
preview.paste(hal_img.crop((0, 0, 32 * 8, 32)), (0, 32))
# Row 2: Tainted Hal Heads
preview.paste(thal_img.crop((0, 0, 32 * 8, 32)), (0, 64))

# Row 3: Isaac WalkSide (Y=64)
preview.paste(isaac_img.crop((0, 64, 32 * 8, 96)), (0, 96))
# Row 4: Hal WalkSide (Y=64)
preview.paste(hal_img.crop((0, 64, 32 * 8, 96)), (0, 128))
# Row 5: Tainted Hal WalkSide (Y=64)
preview.paste(thal_img.crop((0, 64, 32 * 8, 96)), (0, 160))

preview_zoom = preview.resize((preview.width * 3, preview.height * 3), Image.NEAREST)
preview_zoom.save("tools/preview_heads_bodies.png")
print("Saved tools/preview_heads_bodies.png")
