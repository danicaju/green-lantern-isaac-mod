import os
from PIL import Image
from generate_fixed_side_sprites import build_hal_side_head_f0, build_thal_side_head_f0
from build_side_walk_frames import build_hal_walk_frame, build_thal_walk_frame

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "character_001_isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

new_h_head = build_hal_side_head_f0()
new_t_head = build_thal_side_head_f0()
new_h_body = build_hal_walk_frame(0)
new_t_body = build_thal_walk_frame(0)

# Costumes to showcase:
# 1. No item
# 2. Polyphemus (costume_106_polyphemus.png)
# 3. Inner Eye (costume_002_theinner_eye.png)
# 4. Growth Hormones (costume_028_growthhormones.png)
# 5. The Belt (costume_015_belt.png)

costume_specs = [
    ("Default (No Item)", None, None, 0, 0),
    ("Polyphemus", "costume_106_polyphemus.png", None, 64, 0),
    ("Inner Eye", "costume_002_theinner_eye.png", None, 64, 0),
    ("Growth Hormones", "costume_028_growthhormones.png", None, 64, 0),
    ("The Belt", None, "costume_015_belt.png", 0, 0),
]

def assemble_char(head, body, flip=False, head_costume=None, body_costume=None):
    canvas = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    # Origin at (24, 28)
    ox, oy = 24, 28
    
    # Body: XPos=0, YPos=2, XPiv=16, YPiv=25
    b = body.copy()
    if flip:
        b = b.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(b, (ox - 16, oy + 2 - 25), b)
    
    # Body costume if any
    if body_costume:
        bc = body_costume.copy()
        if flip:
            bc = bc.transpose(Image.FLIP_LEFT_RIGHT)
        canvas.paste(bc, (ox - 16, oy + 2 - 25), bc)
        
    # Head: XPos=0, YPos=-5, XPiv=16, YPiv=28
    h = head.copy()
    if flip:
        h = h.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(h, (ox - 16, oy - 5 - 28), h)
    
    # Head costume if any
    if head_costume:
        hc = head_costume.copy()
        if flip:
            hc = hc.transpose(Image.FLIP_LEFT_RIGHT)
        canvas.paste(hc, (ox - 16, oy - 5 - 28), hc)
        
    return canvas

# Grid layout:
# Columns:
# 0: Vanilla Isaac (Reference)
# 1: Hal Jordan OLD (Broken)
# 2: Hal Jordan NEW (Fixed)
# 3: Tainted Hal OLD (Broken)
# 4: Tainted Hal NEW (Fixed)
#
# Rows:
# Each item has 2 sub-rows:
# Sub-row 1: Walking Right (-->)
# Sub-row 2: Walking Left (<--)

col_w, row_h = 48, 48
grid = Image.new("RGBA", (col_w * 5, row_h * len(costume_specs) * 2), (245, 245, 245, 255))

old_h_head = hal_img.crop((64, 0, 96, 32))
old_t_head = thal_img.crop((64, 0, 96, 32))
old_h_body = hal_img.crop((0, 64, 32, 96))
old_t_body = thal_img.crop((0, 64, 32, 96))

isaac_head = isaac_img.crop((64, 0, 96, 32))
isaac_body = isaac_img.crop((0, 64, 32, 96))

for idx, (label, h_file, b_file, h_crop_x, b_crop_x) in enumerate(costume_specs):
    hc = None
    if h_file:
        p = os.path.join(costume_dir, h_file)
        if os.path.exists(p):
            hc = Image.open(p).convert("RGBA").crop((h_crop_x, 0, h_crop_x + 32, 32))
            
    bc = None
    if b_file:
        p = os.path.join(costume_dir, b_file)
        if os.path.exists(p):
            bc = Image.open(p).convert("RGBA").crop((b_crop_x, 0, b_crop_x + 32, 32))
            
    # Right-facing (flip = False)
    y_r = (idx * 2) * row_h
    grid.paste(assemble_char(isaac_head, isaac_body, False, hc, bc), (0 * col_w, y_r))
    grid.paste(assemble_char(old_h_head, old_h_body, False, hc, bc), (1 * col_w, y_r))
    grid.paste(assemble_char(new_h_head, new_h_body, False, hc, bc), (2 * col_w, y_r))
    grid.paste(assemble_char(old_t_head, old_t_body, False, hc, bc), (3 * col_w, y_r))
    grid.paste(assemble_char(new_t_head, new_t_body, False, hc, bc), (4 * col_w, y_r))
    
    # Left-facing (flip = True)
    y_l = (idx * 2 + 1) * row_h
    grid.paste(assemble_char(isaac_head, isaac_body, True, hc, bc), (0 * col_w, y_l))
    grid.paste(assemble_char(old_h_head, old_h_body, True, hc, bc), (1 * col_w, y_l))
    grid.paste(assemble_char(new_h_head, new_h_body, True, hc, bc), (2 * col_w, y_l))
    grid.paste(assemble_char(old_t_head, old_t_body, True, hc, bc), (3 * col_w, y_l))
    grid.paste(assemble_char(new_t_head, new_t_body, True, hc, bc), (4 * col_w, y_l))

# Save artifact
artifact_path = r"C:\Users\danic\.gemini\antigravity\brain\25a8c9be-14f1-4e9c-8c5f-e17d8ccace13\side_movement_costumes_comparison.png"
grid_zoom = grid.resize((grid.width * 3, grid.height * 3), Image.NEAREST)
grid_zoom.save(artifact_path)
print(f"Saved artifact comparison to {artifact_path}")
