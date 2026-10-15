import os
from PIL import Image
from generate_fixed_side_sprites import (
    build_hal_side_head_f0, build_hal_side_head_f1,
    build_thal_side_head_f0, build_thal_side_head_f1
)
from build_side_walk_frames import (
    build_hal_walk_frame, build_thal_walk_frame, walk_coords
)

def apply_fixes_to_sheets(dry_run=True):
    targets = [
        ("resources/gfx/characters/hal_jordan.png", "hal"),
        ("resources/gfx/characters/hal_jordan_extra.png", "hal"),
        ("resources/gfx/characters/tainted_hal.png", "thal"),
        ("resources/gfx/characters/tainted_hal_extra.png", "thal"),
    ]
    
    for path, char_type in targets:
        if not os.path.exists(path):
            print(f"Skipping non-existent {path}")
            continue
            
        sheet = Image.open(path).convert("RGBA")
        
        # 1. Inject Side Heads at (64, 0) and (96, 0)
        if char_type == "hal":
            h0 = build_hal_side_head_f0()
            h1 = build_hal_side_head_f1()
        else:
            h0 = build_thal_side_head_f0()
            h1 = build_thal_side_head_f1()
            
        sheet.paste(h0, (64, 0), h0)
        sheet.paste(h1, (96, 0), h1)
        
        # 2. Inject Side Walk bodies at walk_coords
        for f in range(10):
            x0, y0 = walk_coords[f]
            if char_type == "hal":
                b = build_hal_walk_frame(f)
            else:
                b = build_thal_walk_frame(f)
            # Clear 32x32 cell first then paste
            empty_cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
            sheet.paste(empty_cell, (x0, y0))
            sheet.paste(b, (x0, y0), b)
            
        if dry_run:
            preview_path = path.replace(".png", "_preview_patched.png")
            sheet.save(preview_path)
            print(f"[DRY-RUN] Saved patched preview to {preview_path}")
        else:
            sheet.save(path)
            print(f"[APPLIED] Overwritten active sheet {path}")

if __name__ == "__main__":
    apply_fixes_to_sheets(dry_run=True)
