"""Recrispify the character body sheets (hal_jordan.png / tainted_hal.png).

Diagnosis: those two sheets carry ~21k-22k unique colours for ~27k opaque
pixels -> they were resampled with interpolation and lost the hard pixel-art
grid. The *_head_base / *_body_overlay assets are already crisp (10-23
colours), so only the body sheets need work.

Pipeline (all on the canonical 512x512 canvas, 2x logical grid = 256x256):
  1. Grid snap: every 2x2 source block collapses to its dominant colour
     (mode; ties broken by closeness to the block mean). Removes sub-pixel
     interpolation noise while preserving the 2x structure the engine expects.
  2. Palette quantisation: median-cut to a small Isaac-like palette.
  3. Hard alpha: alpha >= 128 -> 255 else 0 (Zero-Dirty-Alpha rule).
  4. Nearest 2x upscale back to 512x512.

Usage:
  python tools/recrisp_character_sheets.py --preview   # comparison sheet only
  python tools/recrisp_character_sheets.py --apply     # overwrite the sheets
"""

import argparse
import os
import sys
from collections import Counter

from PIL import Image

SHEETS = ["hal_jordan.png", "hal_jordan_extra.png", "tainted_hal.png", "tainted_hal_extra.png"]
SHEET_DIR = os.path.join("resources", "gfx", "characters")
LOGICAL = 256          # 512 / 2
BLOCK = 2
PALETTE_SIZE = 32
ALPHA_CUTOFF = 128
PREVIEW_PATH = os.path.join(
    os.environ.get("TEMP", "."), "opencode", "recrisp_preview.png"
)
# Preview window: 6 columns x 3 rows of 32x32 cells starting at the origin.
PREVIEW_BOX = (0, 0, 192, 96)
PREVIEW_ZOOM = 4


def dominant_block(px, bx, by):
    """Most frequent colour of a BLOCK x BLOCK region, ties -> nearest mean."""
    counts = Counter()
    sr = sg = sb = sa = 0
    for dy in range(BLOCK):
        for dx in range(BLOCK):
            c = px[bx + dx, by + dy]
            counts[c] += 1
            sr += c[0]
            sg += c[1]
            sb += c[2]
            sa += c[3]
    n = BLOCK * BLOCK
    mean = (sr / n, sg / n, sb / n, sa / n)
    best, best_n, best_d = None, -1, None
    for c, k in counts.items():
        if k > best_n:
            best, best_n, best_d = c, k, None
        elif k == best_n:
            d = sum((c[i] - mean[i]) ** 2 for i in range(4))
            if best_d is None or d < best_d:
                best, best_d = c, d
    return best


def grid_snap(im):
    """Collapse each BLOCK x BLOCK region to its dominant colour."""
    px = im.load()
    out = Image.new("RGBA", (LOGICAL, LOGICAL))
    op = out.load()
    for y in range(LOGICAL):
        for x in range(LOGICAL):
            op[x, y] = dominant_block(px, x * BLOCK, y * BLOCK)
    return out


def harden_alpha(im):
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a < ALPHA_CUTOFF:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, 255)
    return im


def quantize(im, colors):
    """Median-cut quantisation that keeps the alpha channel intact."""
    alpha = im.getchannel("A")
    rgb = im.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def recrisp(im):
    # Cuantizacion de paleta sobre el sheet completo (512x512): elimina el ruido
    # de color que dejo el remuestreo y endurece los bordes, SIN mover ningun
    # pixel (no hay grid-snap, por eso no aparecen escalones de 2px).
    out = harden_alpha(im)
    out = quantize(out, PALETTE_SIZE)
    out = harden_alpha(out)
    return out


def build_preview(pairs):
    box = PREVIEW_BOX
    cw = (box[2] - box[0]) * PREVIEW_ZOOM
    ch = (box[3] - box[1]) * PREVIEW_ZOOM
    gap = 12
    canvas = Image.new("RGBA", (cw, ch * 2 + gap * 3), (30, 30, 34, 255))
    for i, (label, im) in enumerate(pairs):
        crop = im.crop(box).resize((cw, ch), Image.NEAREST)
        canvas.alpha_composite(crop, (0, gap + i * (ch + gap)))
    os.makedirs(os.path.dirname(PREVIEW_PATH), exist_ok=True)
    canvas.save(PREVIEW_PATH)
    return PREVIEW_PATH


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    if not (args.preview or args.apply):
        ap.error("choose --preview or --apply")

    for name in SHEETS:
        path = os.path.join(SHEET_DIR, name)
        im = Image.open(path).convert("RGBA")
        before = len(Counter(im.getdata()))
        out = recrisp(im)
        after = len(Counter(out.getdata()))
        print(f"{name}: colours {before} -> {after}")
        if args.apply:
            out.save(path)
        if args.preview and name == SHEETS[0]:
            build_preview([("original", im), ("recrisp", out)])

    if args.preview:
        print("preview:", PREVIEW_PATH)


if __name__ == "__main__":
    sys.exit(main())
