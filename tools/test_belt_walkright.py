import os
from PIL import Image

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Let's inspect:
# 1. Belt: costume_015_belt.png
# In 028_The Belt.anm2:
# WalkRight: XCrop=0, YCrop=0, W=32, H=32, XPos=-16, YPos=-23, XPiv=0, YPiv=0
# Note that XPos=-16, XPiv=0 is equivalent to XPos=0, XPiv=16!
# So it directly overlays the 32x32 body frame!
belt = Image.open(os.path.join(costume_dir, "costume_015_belt.png")).convert("RGBA")

# Let's crop WalkRight frame 0 (0, 64) from Isaac, Hal, THal
i_b = isaac_img.crop((0, 64, 32, 96))
h_b = hal_img.crop((0, 64, 32, 96))
t_b = thal_img.crop((0, 64, 32, 96))

# Belt WalkRight frame 0 is at (0, 0) in costume_015_belt.png
belt_cell = belt.crop((0, 0, 32, 32))

i_b_comp = Image.alpha_composite(i_b, belt_cell)
h_b_comp = Image.alpha_composite(h_b, belt_cell)
t_b_comp = Image.alpha_composite(t_b, belt_cell)

# Save visual comparison:
body_comp = Image.new("RGBA", (32 * 6, 32), (230, 230, 230, 255))
body_comp.paste(i_b, (0, 0), i_b)
body_comp.paste(h_b, (32, 0), h_b)
body_comp.paste(t_b, (64, 0), t_b)
body_comp.paste(i_b_comp, (96, 0), i_b_comp)
body_comp.paste(h_b_comp, (128, 0), h_b_comp)
body_comp.paste(t_b_comp, (160, 0), t_b_comp)

body_comp_zoom = body_comp.resize((body_comp.width * 4, body_comp.height * 4), Image.NEAREST)
body_comp_zoom.save("tools/belt_walkright_zoom4x.png")
print("Saved tools/belt_walkright_zoom4x.png")
