import os
from PIL import Image, ImageDraw, ImageFont

costume_dir = r"C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\extracted_resources\resources\gfx\characters\costumes"
hal_img = Image.open("resources/gfx/characters/hal_jordan.png").convert("RGBA")
thal_img = Image.open("resources/gfx/characters/tainted_hal.png").convert("RGBA")

# Original bodies (floating superhero posture)
h_body_f0 = hal_img.crop((0, 64, 32, 96))
h_body_f1 = hal_img.crop((32, 64, 64, 96))
t_body_f0 = thal_img.crop((0, 64, 32, 96))
t_body_f1 = thal_img.crop((32, 64, 64, 96))

# Calibrate top hairline by 1 px (Y=3 -> Y=2)
def calibrate_crown(cell, hair_dark, hair_mid):
    out = cell.copy()
    px = out.load()
    for x in range(32):
        if px[x, 3][3] > 0:
            if px[x, 3][0] < 40 and px[x, 3][1] < 40 and px[x, 3][2] < 40:
                if 8 <= x <= 23:
                    px[x, 2] = px[x, 3]
                    px[x, 3] = hair_dark if x in [8, 9, 22, 23] else hair_mid
    return out

h_head_f0 = calibrate_crown(hal_img.crop((64, 0, 96, 32)), (24, 16, 12, 255), (46, 28, 20, 255))
h_head_f1_base = calibrate_crown(hal_img.crop((96, 0, 128, 32)), (24, 16, 12, 255), (46, 28, 20, 255))
h_head_f1 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
h_head_f1.paste(h_head_f1_base.crop((0, 0, 32, 31)), (0, 1)) # gentle 1-px hover

t_head_f0 = calibrate_crown(thal_img.crop((64, 0, 96, 32)), (20, 20, 24, 255), (38, 36, 44, 255))
t_head_f1_base = calibrate_crown(thal_img.crop((96, 0, 128, 32)), (20, 20, 24, 255), (38, 36, 44, 255))
t_head_f1 = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
t_head_f1.paste(t_head_f1_base.crop((0, 0, 32, 31)), (0, 1)) # gentle 1-px hover

# Costumes
fez_img = Image.open(os.path.join(costume_dir, "character_004_judasfez.png")).convert("RGBA")
spel_img = Image.open(os.path.join(costume_dir, "costume_063_spelunkerhat.png")).convert("RGBA")
belt_img = Image.open(os.path.join(costume_dir, "costume_015_belt.png")).convert("RGBA")

# Assembler
def assemble_char(head, body, flip=False, hat_cell_64=None, hat_ypiv=44, belt_cell=None):
    canvas = Image.new("RGBA", (48, 56), (0, 0, 0, 0))
    ox, oy = 24, 38
    
    # Body
    b = body.copy()
    if flip:
        b = b.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(b, (ox - 16, oy + 2 - 25), b)
    
    if belt_cell:
        bc = belt_cell.copy()
        if flip:
            bc = bc.transpose(Image.FLIP_LEFT_RIGHT)
        canvas.paste(bc, (ox - 16, oy + 2 - 25), bc)
        
    # Head
    h = head.copy()
    if flip:
        h = h.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(h, (ox - 16, oy - 5 - 28), h)
    
    if hat_cell_64:
        hc = hat_cell_64.copy()
        if flip:
            hc = hc.transpose(Image.FLIP_LEFT_RIGHT)
        canvas.paste(hc, (ox - 16, oy - 5 - hat_ypiv), hc)
        
    return canvas

fez_r = fez_img.crop((192, 0, 224, 64))
fez_l = fez_img.crop((64, 0, 96, 64))

spel_r0 = spel_img.crop((64, 0, 96, 64))
spel_r1 = spel_img.crop((96, 0, 128, 64))
spel_l0 = spel_img.crop((192, 0, 224, 64))
spel_l1 = spel_img.crop((224, 0, 256, 64))

belt_c = belt_img.crop((0, 0, 32, 32))

# Grid
col_w, row_h = 60, 56
label_left = 140
header_top = 44

total_w = label_left + col_w * 4
total_h = header_top + row_h * 5

grid = Image.new("RGBA", (total_w, total_h), (242, 242, 246, 255))
draw = ImageDraw.Draw(grid)

try:
    font = ImageFont.truetype("arial.ttf", 10)
    font_bold = ImageFont.truetype("arialbd.ttf", 11)
except:
    font = ImageFont.load_default()
    font_bold = font

headers = [
    "Hal (Float Hover 0)",
    "Hal (Float Hover 1)",
    "Tainted Hal (Hover 0)",
    "Tainted Hal (Hover 1)",
]

for ci, text in enumerate(headers):
    cx = label_left + ci * col_w + col_w // 2
    bbox = draw.textbbox((0, 0), text, font=font_bold)
    tw = bbox[2] - bbox[0]
    draw.text((cx - tw // 2, 14), text, fill=(20, 20, 30), font=font_bold)

rows_spec = [
    ("No Item [Right ->]", None, False, None, 44, None),
    ("Judas Fez [Right ->]", fez_r, False, None, 44, None),
    ("Judas Fez [Left <-]", fez_l, True, None, 44, None),
    ("Spelunker Hat [Right ->]", spel_r0, False, spel_r1, 44, None),
    ("The Belt [Right ->]", None, False, None, 44, belt_c),
]

for ri, (label, hat0, flip, hat1, ypiv, belt) in enumerate(rows_spec):
    by = header_top + ri * row_h
    draw.line([(0, by), (total_w, by)], fill=(215, 215, 222), width=1)
    draw.text((10, by + 18), label, fill=(30, 30, 40), font=font_bold)
    
    h1_hat = hat1 if hat1 else hat0
    
    c0 = assemble_char(h_head_f0, h_body_f0, flip, hat0, ypiv, belt)
    c1 = assemble_char(h_head_f1, h_body_f1, flip, h1_hat, ypiv, belt)
    c2 = assemble_char(t_head_f0, t_body_f0, flip, hat0, ypiv, belt)
    c3 = assemble_char(t_head_f1, t_body_f1, flip, h1_hat, ypiv, belt)
    
    for ci, spr in enumerate([c0, c1, c2, c3]):
        grid.paste(spr, (label_left + ci * col_w + (col_w - 48) // 2, by))

artifact_path = r"C:\Users\danic\.gemini\antigravity\brain\25a8c9be-14f1-4e9c-8c5f-e17d8ccace13\floating_green_lantern_costumes_preview.png"
grid_zoom = grid.resize((grid.width * 2, grid.height * 2), Image.NEAREST)
grid_zoom.save(artifact_path)
print(f"Saved floating preview artifact to {artifact_path}")
