#!/usr/bin/env python3
"""Normalize the 7 mod item icons (collectibles + trinket) to Isaac style.

Transforms applied per icon (all deterministic, pixel-safe):
  1. Outline recolor: boundary black pixels (0,0,0) touching transparency are
     repainted to the vanilla dark-brown outline #1C1615 = (28,22,21).
  2. Recenter: content bbox is shifted so its center lands on (15.5, 15.5).
  3. Footprint: icons whose content exceeds MAX_FOOTPRINT are nearest-neighbour
     shrunk (preserving aspect) to fit, then recentered. Alpha stays 0/255.

Usage:
  python tools/normalize_item_icons.py            # apply in place
  python tools/normalize_item_icons.py --preview  # write before/after sheet only
"""
import os
import sys
from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIRS = [
    os.path.join(REPO_ROOT, "resources", "gfx", "items", "collectibles"),
    os.path.join(REPO_ROOT, "resources", "gfx", "items", "trinkets"),
]
ICONS = [
    "collectible_power_battery.png",
    "collectible_coast_city.png",
    "collectible_giant_fist.png",
    "collectible_gatling.png",
    "collectible_solid_light_shield.png",
    "collectible_power_ring.png",
    "trinket_yellow_impurity.png",
]

OUTLINE = (28, 22, 21, 255)   # vanilla #1C1615
CANVAS = 32
CENTER = 15.5
MAX_FOOTPRINT = 26            # max content dimension after normalization (mild, pixel-safe)


def icon_path(name):
    for d in ICON_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(name)


def bbox(img):
    return img.getchannel("A").getbbox()


def recolor_outline(img):
    """Repaint black boundary pixels (adjacent to transparency) to OUTLINE."""
    px = img.load()
    w, h = img.size
    out = img.copy()
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or (r, g, b) != (0, 0, 0):
                continue
            boundary = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        boundary = True
                        break
                    if px[nx, ny][3] == 0:
                        boundary = True
                        break
                if boundary:
                    break
            if boundary:
                opx[x, y] = OUTLINE
    return out


def shrink_to_fit(img):
    """Nearest-neighbour shrink so the content fits MAX_FOOTPRINT, keeping aspect."""
    bb = bbox(img)
    if bb is None:
        return img
    x0, y0, x1, y1 = bb
    cw, ch = x1 - x0, y1 - y0
    longest = max(cw, ch)
    if longest <= MAX_FOOTPRINT:
        return img
    factor = MAX_FOOTPRINT / float(longest)
    nw, nh = max(1, int(round(cw * factor))), max(1, int(round(ch * factor)))
    content = img.crop(bb).resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(content, (0, 0), content)
    return canvas


def recenter(img):
    """Shift content so its bbox center lands on CENTER, CENTER."""
    bb = bbox(img)
    if bb is None:
        return img
    x0, y0, x1, y1 = bb
    cx = (x0 + x1 - 1) / 2.0
    cy = (y0 + y1 - 1) / 2.0
    dx = int(round(CENTER - cx))
    dy = int(round(CENTER - cy))
    if dx == 0 and dy == 0:
        return img
    content = img.crop(bb)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    nx = int(round(cx + dx - (x1 - x0 - 1) / 2.0))
    ny = int(round(cy + dy - (y1 - y0 - 1) / 2.0))
    canvas.paste(content, (nx, ny), content)
    return canvas


def normalize(img):
    img = recolor_outline(img)
    img = shrink_to_fit(img)
    img = recenter(img)
    return img


def report(img, label):
    bb = bbox(img)
    x0, y0, x1, y1 = bb
    print("  %-34s bbox=(%d,%d)-(%d,%d) %dx%d center=(%.1f,%.1f)"
          % (label, x0, y0, x1 - 1, y1 - 1, x1 - x0, y1 - y0,
             (x0 + x1 - 1) / 2.0, (y0 + y1 - 1) / 2.0))


def preview_sheet(pairs, out_path, scale=6):
    cols = len(pairs)
    cell = CANVAS * scale
    sheet = Image.new("RGBA", (cols * (cell + 8) + 8, 2 * (cell + 20) + 8),
                      (40, 40, 40, 255))
    for i, (before, after, name) in enumerate(pairs):
        x = 8 + i * (cell + 8)
        for row, img in ((0, before), (1, after)):
            big = img.resize((cell, cell), Image.NEAREST)
            sheet.paste(big, (x, 8 + row * (cell + 20)), big)
    sheet.save(out_path)
    print("preview -> %s" % out_path)


def main():
    preview = "--preview" in sys.argv
    pairs = []
    print("== icons before ==")
    for name in ICONS:
        p = icon_path(name)
        img = Image.open(p).convert("RGBA")
        report(img, name)
        after = normalize(img)
        pairs.append((img, after, name))
    print("== icons after ==")
    for _, after, name in pairs:
        report(after, name)

    tmp = os.path.join(os.environ.get("TEMP", "."), "icon_normalize_preview.png")
    preview_sheet(pairs, tmp)

    if not preview:
        for (_, after, name) in pairs:
            p = icon_path(name)
            after.save(p)
        print("written %d icons in place" % len(pairs))
    else:
        print("preview only (no files written)")


if __name__ == "__main__":
    main()
