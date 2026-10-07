"""
tools/test_ring_sprite_quality.py
Unit test for Green Lantern Ring collectible sprite quality and Isaac compliance:
- Exact 32x32 dimensions
- Strict 1-bit alpha (0 semi-transparent pixels)
- Zero orthogonal and diagonal outline leaks
- Inner hole transparency (pedestal floor visibility)
- Cel-shaded palette size within Isaac guidelines
- Presence of Green Lantern emblem core highlight
"""

import os
import sys
from PIL import Image

MOD_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITE_PATH = os.path.join(MOD_DIR, "resources", "gfx", "items", "collectibles", "collectible_power_ring.png")

def test_ring_sprite():
    assert os.path.exists(SPRITE_PATH), f"Sprite not found at {SPRITE_PATH}"
    img = Image.open(SPRITE_PATH).convert("RGBA")
    w, h = img.size

    # 1. Dimensions
    assert (w, h) == (32, 32), f"Expected 32x32, got {w}x{h}"

    # 2. Strict 1-bit alpha
    semi = 0
    opaque = 0
    colors = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if 0 < a < 255:
                semi += 1
            if a == 255:
                opaque += 1
                colors.add((r, g, b))

    assert semi == 0, f"Found {semi} semi-transparent pixels! Isaac sprites require 1-bit alpha."
    assert 400 <= opaque <= 650, f"Opaque pixel count {opaque} outside expected range [400, 650]"
    assert 5 <= len(colors) <= 15, f"Palette count {len(colors)} outside cel-shaded range [5, 15]"

    # 3. Outline integrity (orthogonal)
    leaks = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a == 255 and (r, g, b) != (0, 0, 0):
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        if img.getpixel((nx, ny))[3] == 0:
                            leaks += 1
    assert leaks == 0, f"Found {leaks} orthogonal outline leaks!"

    # 4. Diagonal outline integrity
    diag_leaks = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a == 255 and (r, g, b) != (0, 0, 0):
                for dx in [-1, 1]:
                    for dy in [-1, 1]:
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            if img.getpixel((nx, ny))[3] == 0:
                                o1 = img.getpixel((x + dx, y))
                                o2 = img.getpixel((x, y + dy))
                                if o1[:3] != (0, 0, 0) and o2[:3] != (0, 0, 0):
                                    diag_leaks += 1
    assert diag_leaks == 0, f"Found {diag_leaks} diagonal corner leaks!"

    # 5. Inner hole transparency check (finger loop must be transparent)
    hole_sample_coords = [(15, 18), (16, 18), (15, 19), (16, 19)]
    for hx, hy in hole_sample_coords:
        assert img.getpixel((hx, hy))[3] == 0, f"Pixel at ({hx}, {hy}) inside finger hole must be transparent (Alpha=0)"

    # 6. Emblem presence check (luminous highlight must be present in top signet seal)
    has_luminous = False
    for y in range(4, 11):
        for x in range(12, 19):
            r, g, b, a = img.getpixel((x, y))
            if a == 255 and g > 240 and (r > 200 or b > 180):
                has_luminous = True
                break
        if has_luminous:
            break
    assert has_luminous, "Signet face must contain luminous Green Lantern core highlight pixels"

    print("[PASS] test_ring_sprite_quality passed all checks!")

if __name__ == "__main__":
    test_ring_sprite()
