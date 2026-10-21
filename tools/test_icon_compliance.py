#!/usr/bin/env python3
"""Compliance guard for the mod's item icons (SPEC icons).

Checks (all deterministic, read-only):
  1. Every icon is 32x32 (vanilla collectible/trinket size, verified against
     extracted vanilla resources: collectibles_001 and trinket_001 are 32x32).
  2. Alpha is strictly 0 or 255 (no semi-transparency in pixel art).
  3. Zero dirty alpha: any pixel with alpha == 0 must have RGB (0,0,0).
  4. Content footprint (bbox) fits MAX_FOOTPRINT on its longest side.
  5. Content bbox center is within TOLERANCE px of the canvas centre (15.5, 15.5).
  6. The vanilla outline colour #1C1615 = (28,22,21) is present in the outline.
  7. Spec resolutions: trinket file is 32x32 (NOT 16x16) and the player stage
     big portraits are 144x144 (NOT 100x100) -- both verified against real mods
     shipped with the game (playerportrait_* under ui/boss = 112x78 and
     ui/stage = 144x144).

Exit 0 when every check passes.
"""
import os
import sys
from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLLECTIBLES = os.path.join(REPO_ROOT, "resources", "gfx", "items", "collectibles")
TRINKETS = os.path.join(REPO_ROOT, "resources", "gfx", "items", "trinkets")
STAGE = os.path.join(REPO_ROOT, "resources", "gfx", "ui", "stage")

ICONS = [
    (COLLECTIBLES, "collectible_power_battery.png"),
    (COLLECTIBLES, "collectible_coast_city.png"),
    (COLLECTIBLES, "collectible_giant_fist.png"),
    (COLLECTIBLES, "collectible_gatling.png"),
    (COLLECTIBLES, "collectible_solid_light_shield.png"),
    (COLLECTIBLES, "collectible_power_ring.png"),
    (TRINKETS, "trinket_yellow_impurity.png"),
]

CANVAS = 32
CENTER = 15.5
TOLERANCE = 1.0
MAX_FOOTPRINT = 26
OUTLINE = (28, 22, 21)

passes = 0
failures = 0


def check(cond, msg):
    global passes, failures
    if cond:
        passes += 1
    else:
        failures += 1
        sys.stderr.write("FAIL: %s\n" % msg)


def analyse(img):
    px = img.load()
    w, h = img.size
    minx, miny, maxx, maxy = w, h, -1, -1
    semi = 0
    dirty = 0
    outline_hits = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a not in (0, 255):
                semi += 1
            if a == 0:
                if (r, g, b) != (0, 0, 0):
                    dirty += 1
                continue
            if (r, g, b) == OUTLINE:
                outline_hits += 1
            if x < minx:
                minx = x
            if y < miny:
                miny = y
            if x > maxx:
                maxx = x
            if y > maxy:
                maxy = y
    return minx, miny, maxx, maxy, semi, dirty, outline_hits


def main():
    for folder, name in ICONS:
        path = os.path.join(folder, name)
        check(os.path.exists(path), "%s exists" % name)
        if not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGBA")
        check(img.size == (CANVAS, CANVAS),
              "%s is %dx%d, expected %dx%d" % (name, img.size[0], img.size[1], CANVAS, CANVAS))
        minx, miny, maxx, maxy, semi, dirty, outline_hits = analyse(img)
        check(minx <= maxx, "%s has non-empty content" % name)
        check(semi == 0, "%s has %d semi-transparent pixels (pixel art must be 0/255)" % (name, semi))
        check(dirty == 0, "%s has %d dirty-alpha pixels (alpha=0 with non-black RGB)" % (name, dirty))
        if minx <= maxx:
            cw, ch = maxx - minx + 1, maxy - miny + 1
            cx = (minx + maxx) / 2.0
            cy = (miny + maxy) / 2.0
            check(max(cw, ch) <= MAX_FOOTPRINT,
                  "%s footprint %dx%d exceeds %d" % (name, cw, ch, MAX_FOOTPRINT))
            check(abs(cx - CENTER) <= TOLERANCE and abs(cy - CENTER) <= TOLERANCE,
                  "%s center (%.1f,%.1f) off canvas centre (%.1f,%.1f)" % (name, cx, cy, CENTER, CENTER))
        check(outline_hits > 0,
              "%s has no vanilla outline colour #1C1615" % name)

    # Spec resolutions resolved against real shipped mods.
    trinket = Image.open(os.path.join(TRINKETS, "trinket_yellow_impurity.png"))
    check(trinket.size == (32, 32),
          "trinket must be 32x32 (vanilla trinket_001 is 32x32), got %s" % (trinket.size,))
    for stage_name in ("stage_hal_jordan.png", "stage_tainted_hal.png"):
        p = os.path.join(STAGE, stage_name)
        check(os.path.exists(p), "%s exists" % stage_name)
        if os.path.exists(p):
            im = Image.open(p)
            check(im.size == (144, 144),
                  "%s must be 144x144 (vanilla ui/stage playerportrait is 144x144), got %s"
                  % (stage_name, im.size))

    sys.stderr.write("\n[test_icon_compliance] passes=%d failures=%d\n" % (passes, failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
