import os
from PIL import Image

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

def process_sheet(path, hair_dark, hair_mid):
    img = Image.open(path).convert("RGBA")
    f0_orig = img.crop((64, 0, 96, 32))
    f1_orig = img.crop((96, 0, 128, 32))
    
    # Calibrate f0 crown (Y=3 -> Y=2)
    f0_cal = calibrate_crown(f0_orig, hair_dark, hair_mid)
    
    # Calibrate f1 crown and add gentle 1-px floating hover drift
    f1_cal_base = calibrate_crown(f1_orig, hair_dark, hair_mid)
    f1_cal = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    f1_cal.paste(f1_cal_base.crop((0, 0, 32, 31)), (0, 1))
    
    # Paste back into sheet
    img.paste(f0_cal, (64, 0))
    img.paste(f1_cal, (96, 0))
    
    img.save(path)
    print(f"Updated {path}")

# Apply to Hal Jordan sheets
process_sheet("resources/gfx/characters/hal_jordan.png", (24, 16, 12, 255), (46, 28, 20, 255))
process_sheet("resources/gfx/characters/hal_jordan_extra.png", (24, 16, 12, 255), (46, 28, 20, 255))

# Apply to Tainted Hal sheets
process_sheet("resources/gfx/characters/tainted_hal.png", (20, 20, 24, 255), (38, 36, 44, 255))
process_sheet("resources/gfx/characters/tainted_hal_extra.png", (20, 20, 24, 255), (38, 36, 44, 255))

print("All sheets successfully updated with calibrated floating hover!")
