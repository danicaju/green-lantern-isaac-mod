"""
tools/restore_character_menu_letters.py
Restores pristine anti-aliased character menu typography from commit da9cf74
into content/gfx/hal_charactermenu.png and content/gfx/tainted_charactermenu.png
while strictly preserving the refined character portraits at (56, 2, 104, 54).
Ensures 100% clean zero dirty RGB (alpha == 0 -> RGB = (0, 0, 0)).
"""

import os
import subprocess
import io
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_COMMIT = "da9cf74"

FILES = [
    "content/gfx/hal_charactermenu.png",
    "content/gfx/tainted_charactermenu.png"
]

def restore_menu_letters():
    print("=" * 60)
    print("RESTORING CHARACTER MENU LETTERS FROM GIT COMMIT:", SOURCE_COMMIT)
    print("=" * 60)

    for rel_path in FILES:
        full_path = os.path.join(PROJECT_ROOT, rel_path)
        print(f"\nProcessing {rel_path}...")

        # 1. Fetch pristine image from git history
        git_cmd = ["git", "show", f"{SOURCE_COMMIT}:{rel_path}"]
        res = subprocess.run(git_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        img_pristine = Image.open(io.BytesIO(res.stdout)).convert("RGBA")

        # 2. Open current HEAD image (which contains the refined character portraits)
        img_current = Image.open(full_path).convert("RGBA")

        assert img_pristine.size == (160, 160), f"Unexpected size for pristine: {img_pristine.size}"
        assert img_current.size == (160, 160), f"Unexpected size for current: {img_current.size}"

        pix_pristine = img_pristine.load()
        pix_current = img_current.load()

        # 3. Create restored canvas
        img_restored = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
        pix_restored = img_restored.load()

        # Copy Rows 0..53 from current HEAD (preserving character portrait at 56, 2, 104, 54)
        for y in range(0, 54):
            for x in range(160):
                p = pix_current[x, y]
                pix_restored[x, y] = (0, 0, 0, 0) if p[3] == 0 else p

        # Copy Rows 54..159 from pristine da9cf74 (restoring original hand-drawn anti-aliased typography)
        for y in range(54, 160):
            for x in range(160):
                p = pix_pristine[x, y]
                pix_restored[x, y] = (0, 0, 0, 0) if p[3] == 0 else p

        # 4. Strict zero dirty RGB verification and sanitization
        for y in range(160):
            for x in range(160):
                p = pix_restored[x, y]
                if p[3] == 0:
                    pix_restored[x, y] = (0, 0, 0, 0)

        # 5. Sanity checks
        # Verify portrait area unchanged
        for y in range(2, 54):
            for x in range(56, 104):
                assert pix_restored[x, y] == pix_current[x, y], f"Portrait mismatch at ({x}, {y})"

        # Verify letter areas match pristine
        for y in range(54, 80):
            for x in range(10, 150):
                assert pix_restored[x, y] == pix_pristine[x, y], f"CustomName mismatch at ({x}, {y})"
        for y in range(82, 108):
            for x in range(10, 150):
                assert pix_restored[x, y] == pix_pristine[x, y], f"CustomItemName mismatch at ({x}, {y})"

        # Verify 0 dirty alpha
        dirty_count = sum(
            1 for y in range(160) for x in range(160)
            if pix_restored[x, y][3] == 0 and pix_restored[x, y][:3] != (0, 0, 0)
        )
        assert dirty_count == 0, f"Found {dirty_count} dirty alpha pixels!"

        # Save to file
        img_restored.save(full_path)
        print(f"  [SAVED] {rel_path} restored and verified successfully.")

if __name__ == "__main__":
    restore_menu_letters()
