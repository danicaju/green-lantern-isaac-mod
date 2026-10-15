import os
from PIL import Image, ImageDraw, ImageFont

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
isaac_img = Image.open(os.path.join(costume_dir, "Character_001_Isaac.png")).convert("RGBA")
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Isaac heads and bodies
i_head_f0 = isaac_img.crop((64, 0, 96, 32))
i_head_f1 = isaac_img.crop((96, 0, 128, 32))
i_body_f0 = isaac_img.crop((0, 64, 32, 96))
i_body_f1 = isaac_img.crop((32, 64, 64, 96))

# Hal original
h_head_orig_f0 = hal_img.crop((64, 0, 96, 32))
h_head_orig_f1 = hal_img.crop((96, 0, 128, 32))
h_body_f0 = hal_img.crop((0, 64, 32, 96))
h_body_f1 = hal_img.crop((32, 64, 64, 96))

# Tainted Hal original
t_head_orig_f0 = thal_img.crop((64, 0, 96, 32))
t_head_orig_f1 = thal_img.crop((96, 0, 128, 32))
t_body_f0 = thal_img.crop((0, 64, 32, 96))
t_body_f1 = thal_img.crop((32, 64, 64, 96))

# Calibrate crown (Y=3 -> Y=2)
def calibrate_crown(cell, hair_dark, hair_mid):
    out = cell.copy()
    px = out.load()
    for x in range(32):
        if px[x, 3][3] > 0:
            if px[x, 3][0] < 45 and px[x, 3][1] < 45 and px[x, 3][2] < 45:
                if 8 <= x <= 23:
                    px[x, 2] = px[x, 3]
                    px[x, 3] = hair_dark if x in [8, 9, 22, 23] else hair_mid
    return out

h_head_cal_f0 = calibrate_crown(h_head_orig_f0, (24, 16, 12, 255), (46, 28, 20, 255))
h_head_cal_f1_base = calibrate_crown(h_head_orig_f1, (24, 16, 12, 255), (46, 28, 20, 255))
h_head_cal_f1 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
h_head_cal_f1.paste(h_head_cal_f1_base.crop((0, 0, 32, 31)), (0, 1))

t_head_cal_f0 = calibrate_crown(t_head_orig_f0, (20, 20, 24, 255), (38, 36, 44, 255))
t_head_cal_f1_base = calibrate_crown(t_head_orig_f1, (20, 20, 24, 255), (38, 36, 44, 255))
t_head_cal_f1 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
t_head_cal_f1.paste(t_head_cal_f1_base.crop((0, 0, 32, 31)), (0, 1))

# Costumes
fez_img = Image.open(os.path.join(costume_dir, "character_004_judasfez.png")).convert("RGBA")
spel_img = Image.open(os.path.join(costume_dir, "costume_063_spelunkerhat.png")).convert("RGBA")
brim_img = Image.open(os.path.join(costume_dir, "costume_019_brimstone.png")).convert("RGBA")
onion_img = Image.open(os.path.join(costume_dir, "costume_058_sadonion.png")).convert("RGBA")
poly_img = Image.open(os.path.join(costume_dir, "costume_106_polyphemus.png")).convert("RGBA")
belt_img = Image.open(os.path.join(costume_dir, "costume_015_belt.png")).convert("RGBA")

# Assemble helper
def render_character(head, body, flip=False, costume_layer=None, belt=None):
    # Canvas with plenty of margins
    canvas = Image.new("RGBA", (52, 60), (0, 0, 0, 0))
    ox, oy = 26, 40

    # 1. Body (XPiv=16, YPiv=25, YPos=2)
    b = body.copy()
    if flip:
        b = b.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(b, (ox - 16, oy + 2 - 25), b)

    # 2. Belt (if present)
    if belt:
        bc = belt.copy()
        if flip:
            bc = bc.transpose(Image.FLIP_LEFT_RIGHT)
        canvas.paste(bc, (ox - 16, oy + 2 - 25), bc)

    # 3. Head (XPiv=16, YPiv=28, YPos=-5)
    h = head.copy()
    if flip:
        h = h.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(h, (ox - 16, oy - 5 - 28), h)

    # 4. Head Costume (spec: img, xpos, ypos, xpiv, ypiv, flip_custom)
    if costume_layer:
        c_img, cxpos, cypos, cxpiv, cypiv, cflip = costume_layer
        c = c_img.copy()
        if cflip:
            c = c.transpose(Image.FLIP_LEFT_RIGHT)
        canvas.paste(c, (ox + cxpos - cxpiv, oy + cypos - cypiv), c)

    return canvas

# Costume specs: (img, xpos, ypos, xpiv, ypiv, flip)
fez_r0 = (fez_img.crop((192, 0, 224, 64)), 0, -5, 16, 44, False)
fez_r1 = (fez_img.crop((224, 0, 256, 64)), 0, -5, 16, 44, False)
fez_l0 = (fez_img.crop((64, 0, 96, 64)), 0, -5, 16, 44, False)

spel_r0 = (spel_img.crop((64, 0, 96, 64)), 0, -5, 16, 44, False)
spel_r1 = (spel_img.crop((96, 0, 128, 64)), 0, -5, 16, 44, False)

brim_r = (brim_img.crop((0, 64, 64, 128)), 0, -8, 32, 44, False)
brim_l = (brim_img.crop((0, 64, 64, 128)), 0, -8, 32, 44, True)

onion_r0 = (onion_img.crop((0, 64, 64, 128)), -4, -5, 32, 44, False)
onion_r1 = (onion_img.crop((64, 64, 128, 128)), -4, -5, 32, 44, False)

poly_r0 = (poly_img.crop((64, 0, 96, 64)), 0, -5, 16, 44, False)
poly_r1 = (poly_img.crop((96, 0, 128, 64)), 0, -5, 16, 44, False)

belt_c = belt_img.crop((0, 0, 32, 32))

rows = [
    ("No Item [Right ->]", None, None, False, None),
    ("Judas Fez [Right Frame 0]", fez_r0, fez_r0, False, None),
    ("Judas Fez [Right Frame 1]", fez_r1, fez_r1, False, None),
    ("Judas Fez [Left Frame 0]", fez_l0, fez_l0, True, None),
    ("Spelunker Hat [Right Frame 0]", spel_r0, spel_r0, False, None),
    ("Spelunker Hat [Right Frame 1]", spel_r1, spel_r1, False, None),
    ("Brimstone Horns [Right]", brim_r, brim_r, False, None),
    ("Polyphemus Eye [Right Frame 0]", poly_r0, poly_r0, False, None),
    ("Polyphemus Eye [Right Frame 1]", poly_r1, poly_r1, False, None),
    ("The Sad Onion [Right Frame 0]", onion_r0, onion_r0, False, None),
    ("The Belt [Right ->]", None, None, False, belt_c),
]

cols = [
    ("Vanilla Isaac", i_head_f0, i_body_f0, False),
    ("Hal (Original)", h_head_orig_f0, h_body_f0, False),
    ("Hal (Calibrated Hover)", h_head_cal_f0, h_body_f0, False),
    ("Tainted Hal (Orig)", t_head_orig_f0, t_body_f0, False),
    ("Tainted Hal (Hover)", t_head_cal_f0, t_body_f0, False),
]

# Grid dimensions
col_w = 72
row_h = 62
label_w = 190
header_h = 36

total_w = label_w + col_w * len(cols)
total_h = header_h + row_h * len(rows)

grid = Image.new("RGBA", (total_w, total_h), (245, 246, 248, 255))
draw = ImageDraw.Draw(grid)

try:
    font_bold = ImageFont.truetype("arialbd.ttf", 11)
    font_reg = ImageFont.truetype("arial.ttf", 10)
except:
    font_bold = ImageFont.load_default()
    font_reg = font_bold

# Draw column headers
for ci, (col_name, _, _, _) in enumerate(cols):
    cx = label_w + ci * col_w + col_w // 2
    bbox = draw.textbbox((0, 0), col_name, font=font_bold)
    tw = bbox[2] - bbox[0]
    draw.text((cx - tw // 2, 10), col_name, fill=(25, 25, 35), font=font_bold)

# Draw rows
for ri, (row_label, cost_f0, cost_f1, flip, belt) in enumerate(rows):
    by = header_h + ri * row_h
    # Alternating row background
    if ri % 2 == 1:
        draw.rectangle([(0, by), (total_w, by + row_h - 1)], fill=(238, 240, 244, 255))
    draw.line([(0, by), (total_w, by)], fill=(218, 220, 226), width=1)
    draw.text((12, by + 22), row_label, fill=(30, 30, 45), font=font_bold)

    is_f1 = "Frame 1" in row_label
    cost = cost_f1 if is_f1 else cost_f0

    for ci, (col_name, _, _, _) in enumerate(cols):
        if ci == 0:
            h = i_head_f1 if is_f1 else i_head_f0
            b = i_body_f1 if is_f1 else i_body_f0
        elif ci == 1:
            h = h_head_orig_f1 if is_f1 else h_head_orig_f0
            b = h_body_f1 if is_f1 else h_body_f0
        elif ci == 2:
            h = h_head_cal_f1 if is_f1 else h_head_cal_f0
            b = h_body_f1 if is_f1 else h_body_f0
        elif ci == 3:
            h = t_head_orig_f1 if is_f1 else t_head_orig_f0
            b = t_body_f1 if is_f1 else t_body_f0
        elif ci == 4:
            h = t_head_cal_f1 if is_f1 else t_head_cal_f0
            b = t_body_f1 if is_f1 else t_body_f0

        char_spr = render_character(h, b, flip=flip, costume_layer=cost, belt=belt)
        gx = label_w + ci * col_w + (col_w - 52) // 2
        gy = by + (row_h - 60) // 2
        grid.paste(char_spr, (gx, gy), char_spr)

artifact_path = r"C:\Users\danic\.gemini\antigravity\brain\25a8c9be-14f1-4e9c-8c5f-e17d8ccace13\costumes_mixing_comprehensive_matrix.png"
grid_zoom = grid.resize((grid.width * 2, grid.height * 2), Image.NEAREST)
grid_zoom.save(artifact_path)
print(f"Matrix saved to {artifact_path}")
