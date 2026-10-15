import os
from PIL import Image
from generate_fixed_side_sprites import build_hal_side_head_f0, build_thal_side_head_f0

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

new_hal_head = build_hal_side_head_f0()
new_thal_head = build_thal_side_head_f0()

# Test 4 iconic costumes:
costumes = [
    ("No Item", None, 0),
    ("Polyphemus", "costume_106_polyphemus.png", 64),
    ("Inner Eye", "costume_002_theinner_eye.png", 64),
    ("Growth Hormones", "costume_028_growthhormones.png", 64),
]

# Grid: 5 columns:
# Col 0: Vanilla Isaac
# Col 1: Old Hal (broken front face)
# Col 2: Fixed Hal (authentic side profile)
# Col 3: Old THal (broken front face)
# Col 4: Fixed THal (authentic side profile)
# Row 0..3: Right facing
# Row 4..7: Left facing (flipped)

canvas = Image.new("RGBA", (32 * 5, 32 * len(costumes) * 2), (235, 235, 235, 255))

for idx, (name, cfile, cx) in enumerate(costumes):
    c_r = None
    if cfile:
        cpath = os.path.join(costume_dir, cfile)
        if os.path.exists(cpath):
            c_r = Image.open(cpath).convert("RGBA").crop((cx, 0, cx + 32, 32))
    if not c_r:
        c_r = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    c_l = c_r.transpose(Image.FLIP_LEFT_RIGHT)
    
    # RIGHT
    i_r = Image.alpha_composite(isaac_img.crop((64, 0, 96, 32)), c_r)
    old_h_r = Image.alpha_composite(hal_img.crop((64, 0, 96, 32)), c_r)
    new_h_r = Image.alpha_composite(new_hal_head.copy(), c_r)
    old_t_r = Image.alpha_composite(thal_img.crop((64, 0, 96, 32)), c_r)
    new_t_r = Image.alpha_composite(new_thal_head.copy(), c_r)
    
    yr = idx * 32
    canvas.paste(i_r, (0 * 32, yr), i_r)
    canvas.paste(old_h_r, (1 * 32, yr), old_h_r)
    canvas.paste(new_h_r, (2 * 32, yr), new_h_r)
    canvas.paste(old_t_r, (3 * 32, yr), old_t_r)
    canvas.paste(new_t_r, (4 * 32, yr), new_t_r)
    
    # LEFT (flipped base + flipped costume)
    i_base_l = isaac_img.crop((64, 0, 96, 32)).transpose(Image.FLIP_LEFT_RIGHT)
    old_h_base_l = hal_img.crop((64, 0, 96, 32)).transpose(Image.FLIP_LEFT_RIGHT)
    new_h_base_l = new_hal_head.copy().transpose(Image.FLIP_LEFT_RIGHT)
    old_t_base_l = thal_img.crop((64, 0, 96, 32)).transpose(Image.FLIP_LEFT_RIGHT)
    new_t_base_l = new_thal_head.copy().transpose(Image.FLIP_LEFT_RIGHT)
    
    i_l = Image.alpha_composite(i_base_l, c_l)
    old_h_l = Image.alpha_composite(old_h_base_l, c_l)
    new_h_l = Image.alpha_composite(new_h_base_l, c_l)
    old_t_l = Image.alpha_composite(old_t_base_l, c_l)
    new_t_l = Image.alpha_composite(new_t_base_l, c_l)
    
    yl = (len(costumes) + idx) * 32
    canvas.paste(i_l, (0 * 32, yl), i_l)
    canvas.paste(old_h_l, (1 * 32, yl), old_h_l)
    canvas.paste(new_h_l, (2 * 32, yl), new_h_l)
    canvas.paste(old_t_l, (3 * 32, yl), old_t_l)
    canvas.paste(new_t_l, (4 * 32, yl), new_t_l)

canvas_zoom = canvas.resize((canvas.width * 4, canvas.height * 4), Image.NEAREST)
canvas_zoom.save("tools/side_heads_costumes_comparison_4x.png")
print("Saved tools/side_heads_costumes_comparison_4x.png")
