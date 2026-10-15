import os
from PIL import Image, ImageDraw, ImageFont
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

costume_specs = [
    ("Default (No Item)", None, None, 0, 0),
    ("Polyphemus (Eye)", "costume_106_polyphemus.png", None, 64, 0),
    ("Inner Eye (3rd Eye)", "costume_002_theinner_eye.png", None, 64, 0),
    ("Growth Hormones", "costume_028_growthhormones.png", None, 64, 0),
    ("The Belt (Body)", None, "costume_015_belt.png", 0, 0),
]

def assemble_char(head, body, flip=False, head_costume=None, body_costume=None):
    canvas = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    ox, oy = 24, 28
    
    b = body.copy()
    if flip:
        b = b.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(b, (ox - 16, oy + 2 - 25), b)
    
    if body_costume:
        bc = body_costume.copy()
        if flip:
            bc = bc.transpose(Image.FLIP_LEFT_RIGHT)
        canvas.paste(bc, (ox - 16, oy + 2 - 25), bc)
        
    h = head.copy()
    if flip:
        h = h.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(h, (ox - 16, oy - 5 - 28), h)
    
    if head_costume:
        hc = head_costume.copy()
        if flip:
            hc = hc.transpose(Image.FLIP_LEFT_RIGHT)
        canvas.paste(hc, (ox - 16, oy - 5 - 28), hc)
        
    return canvas

col_w, row_h = 70, 48
header_top = 44
label_left = 135

total_w = label_left + col_w * 5
total_h = header_top + row_h * len(costume_specs) * 2

grid = Image.new("RGBA", (total_w, total_h), (242, 242, 246, 255))
draw = ImageDraw.Draw(grid)

try:
    font = ImageFont.truetype("arial.ttf", 10)
    font_bold = ImageFont.truetype("arialbd.ttf", 10)
except:
    font = ImageFont.load_default()
    font_bold = font

headers = [
    ("Vanilla Isaac", "(Reference)", (40, 40, 50)),
    ("Hal Jordan", "[CURRENT / Broken]", (190, 30, 30)),
    ("Hal Jordan", "[FIXED Profile]", (20, 140, 50)),
    ("Tainted Hal", "[CURRENT / Broken]", (190, 30, 30)),
    ("Tainted Hal", "[FIXED Profile]", (20, 140, 50)),
]

for col_idx, (title, sub, color) in enumerate(headers):
    cx = label_left + col_idx * col_w + col_w // 2
    bbox1 = draw.textbbox((0, 0), title, font=font_bold)
    tw1 = bbox1[2] - bbox1[0]
    draw.text((cx - tw1 // 2, 8), title, fill=(20, 20, 30), font=font_bold)
    
    bbox2 = draw.textbbox((0, 0), sub, font=font_bold)
    tw2 = bbox2[2] - bbox2[0]
    draw.text((cx - tw2 // 2, 22), sub, fill=color, font=font_bold)

old_h_head = hal_img.crop((64, 0, 96, 32))
old_t_head = thal_img.crop((64, 0, 96, 32))
old_h_body = hal_img.crop((0, 64, 32, 96))
old_t_body = thal_img.crop((0, 64, 32, 96))

isaac_head = isaac_img.crop((64, 0, 96, 32))
isaac_body = isaac_img.crop((0, 64, 32, 96))

char_offset_x = (col_w - 48) // 2

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
            
    base_y = header_top + (idx * 2) * row_h
    draw.text((10, base_y + 10), f"{label}\n[Right ->]", fill=(30, 30, 40), font=font)
    draw.text((10, base_y + row_h + 10), f"{label}\n[Left <-]", fill=(80, 80, 90), font=font)
    
    draw.line([(0, base_y), (total_w, base_y)], fill=(215, 215, 222), width=1)
    
    # Right-facing
    y_r = base_y
    for ci, char_sprite in enumerate([
        assemble_char(isaac_head, isaac_body, False, hc, bc),
        assemble_char(old_h_head, old_h_body, False, hc, bc),
        assemble_char(new_h_head, new_h_body, False, hc, bc),
        assemble_char(old_t_head, old_t_body, False, hc, bc),
        assemble_char(new_t_head, new_t_body, False, hc, bc),
    ]):
        grid.paste(char_sprite, (label_left + ci * col_w + char_offset_x, y_r))
        
    # Left-facing
    y_l = base_y + row_h
    for ci, char_sprite in enumerate([
        assemble_char(isaac_head, isaac_body, True, hc, bc),
        assemble_char(old_h_head, old_h_body, True, hc, bc),
        assemble_char(new_h_head, new_h_body, True, hc, bc),
        assemble_char(old_t_head, old_t_body, True, hc, bc),
        assemble_char(new_t_head, new_t_body, True, hc, bc),
    ]):
        grid.paste(char_sprite, (label_left + ci * col_w + char_offset_x, y_l))

artifact_path = r"C:\Users\danic\.gemini\antigravity\brain\25a8c9be-14f1-4e9c-8c5f-e17d8ccace13\side_movement_costumes_comparison.png"
grid_zoom = grid.resize((grid.width * 2, grid.height * 2), Image.NEAREST)
grid_zoom.save(artifact_path)
print(f"Saved annotated comparison artifact to {artifact_path}")
