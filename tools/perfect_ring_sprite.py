"""
tools/perfect_ring_sprite.py
Constructs the perfected 32x32 Green Lantern Ring sprite with:
1. Authentic Green Lantern emblem (distinct top bar, round circle with glowing white core, bottom bar).
2. Proper 3/4 isometric perspective matching media_1790729121738.jpg.
3. Clean 1-bit alpha with transparent inner hole.
4. Cel-shaded Isaac aesthetic matching the rest of the mod items.
5. Zero outline leaks (orthogonal and diagonal).
"""

import os
from PIL import Image

ARTIFACT_DIR = r"C:\Users\danic\.gemini\antigravity\brain\1da92c3a-b6b6-41f0-ae66-135ed6eb06a2"
MOD_DIR = r"C:\Users\danic\Desktop\green_lantern_mod"
TARGET_FILE = os.path.join(MOD_DIR, r"resources\gfx\items\collectibles\collectible_power_ring.png")

# 10-Color Cel-Shaded Isaac Emerald Palette
PAL = {
    ' ': (0, 0, 0, 0),          # Transparent Background
    '.': (0, 0, 0, 0),          # Transparent Inner Hole
    '#': (0, 0, 0, 255),        # Black Outline (#000000)
    '0': (10, 30, 16, 255),     # Deepest Shadow / Emblem Inset Line (#0a1e10)
    '1': (16, 52, 26, 255),     # Dark Jade Metal (#10341a)
    '2': (26, 86, 42, 255),     # Mid Jade Metal (#1a562a)
    '3': (38, 134, 62, 255),    # Vibrant Emerald Metal (#26863e)
    '4': (68, 196, 92, 255),    # Bright Emerald Highlight (#44c45c)
    '5': (116, 240, 136, 255),  # Luminous Jade Face (#74f088)
    '6': (196, 255, 120, 255),  # Neon Lime Rune / Core Glow (#c4ff78)
    '7': (244, 255, 218, 255),  # Specular White-Lime Core Highlight (#f4ffda)
}

grid_perfect = [
    #01234567890123456789012345678901
    "                                ", # 0
    "            ########            ", # 1  Top bezel outline
    "          ##24444442##    #     ", # 2  Bezel upper rim + spark at (26,2)
    "   #     #245555555544#  #6#    ", # 3  Spark at (3,3) + bezel rim
    "  #6#   #14#00000000#54## #     ", # 4  EMBLEM TOP BAR (8px wide: x=11..18)
    "   #   #14555555555555541#      ", # 5  Bright jade gap
    "      #12455##0000##555421#     ", # 6  EMBLEM CIRCLE TOP
    "     #12455#00677600#555421#    ", # 7  EMBLEM CORE (77: white-lime shine)
    "    #12455#0067777600#555421#   ", # 8  EMBLEM CORE
    "   #12621#55##0000##555412221#  ", # 9  EMBLEM CIRCLE BOTTOM
    "   #12621455555555555554122221# ", # 10 Bright jade gap
    "   #1266214#00000000#541#122221#", # 11 EMBLEM BOTTOM BAR (8px wide)
    "   #126211##24444442##11#122221#", # 12 Bezel bottom rim
    "   #12621#11234444321111#12222# ", # 13 Inside roof of band (gleam)
    "   #12661#11246776421111#12222# ", # 14 Specular reflection
    "   #12621#1111####111111#1222#  ", # 15 Top of inner hole
    "   #12621#111#....#11111#1222#  ", # 16 Inner hole (4 px)
    "   #12661#11#......#1111#122# # ", # 17 Inner hole (6 px) + spark
    "   #12221#1#........#111#122##6#", # 18 Inner hole (8 px)
    "    #1221#1#........#111#122# # ", # 19 Inner hole (8 px)
    "    #1222#11#......#1111#122#   ", # 20 Inner hole (6 px)
    "     #1222#11#....#11111#122#   ", # 21 Inner hole (4 px)
    "     ##1222#11####11111#1222#   ", # 22 Bottom hole outline
    "       ##122234444432222222##   ", # 23 Bottom band highlight rim
    "         ###122222222222###     ", # 24 Bottom band loop
    "   #        ############        ", # 25 Spark at (3,26)
    "  #6#                           ", # 26
    "   #                            ", # 27
    "                                ", # 28
    "                                ", # 29
    "                                ", # 30
    "                                ", # 31
]

def build_image():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    pix = img.load()
    for y in range(32):
        row = grid_perfect[y]
        for x in range(32):
            ch = row[x] if x < len(row) else ' '
            pix[x, y] = PAL.get(ch, (0, 0, 0, 0))
    return img

def verify_sprite(img):
    w, h = img.size
    assert (w, h) == (32, 32), f"Dimensions must be 32x32, got {w}x{h}"
    semi = 0
    leaks = 0
    diag_leaks = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if 0 < a < 255:
                semi += 1
            if a == 255 and (r, g, b) != (0, 0, 0):
                # Orthogonal check
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        if img.getpixel((nx, ny))[3] == 0:
                            leaks += 1
                # Diagonal check
                for dx in [-1, 1]:
                    for dy in [-1, 1]:
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            if img.getpixel((nx, ny))[3] == 0:
                                o1 = img.getpixel((x + dx, y))
                                o2 = img.getpixel((x, y + dy))
                                if o1[:3] != (0, 0, 0) and o2[:3] != (0, 0, 0):
                                    diag_leaks += 1

    assert semi == 0, f"Found {semi} semi-transparent pixels!"
    assert leaks == 0, f"Found {leaks} orthogonal outline leaks!"
    assert diag_leaks == 0, f"Found {diag_leaks} diagonal outline leaks!"
    print(f"VERIFICATION PASSED: 32x32, 0 semi-transparent, 0 outline leaks, 0 diagonal leaks.")

if __name__ == "__main__":
    img = build_image()
    verify_sprite(img)

    # Save to artifact dir
    img.save(os.path.join(ARTIFACT_DIR, "ring_perfect_1x.png"))
    img.resize((128, 128), Image.Resampling.NEAREST).save(os.path.join(ARTIFACT_DIR, "ring_perfect_4x.png"))
    img.resize((256, 256), Image.Resampling.NEAREST).save(os.path.join(ARTIFACT_DIR, "ring_perfect_8x.png"))

    # Deploy to mod directory
    img.save(TARGET_FILE)
    print(f"Deployed perfected sprite to {TARGET_FILE}")
