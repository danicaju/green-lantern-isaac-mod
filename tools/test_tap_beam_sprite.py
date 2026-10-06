#!/usr/bin/env python3
"""tools/test_tap_beam_sprite.py — SPEC-W3: tap-beam mini-rayo sin flecha.

Verifica sobre `resources/gfx/effects/gl_ring_beam.png` + `.anm2`:
  ATLAS (guardias): tamano 64x256, crops tap 64x32 con pivot
    (5,16) dentro de bounds, mitad inferior (ContinuousBeam, y128-255)
    byte-identica a HEAD (beam continuo intacto).
  MINI-RAYO (criterios W3, sin arrowhead):
    nucleo blanco grueso + halo verde 2 capas + estela comica,
    base clara (min canal >= 120 en opacos fuertes) para que Color() tina,
    punta roma continua: sin ensanchamiento flecha en x54-63,
    haz mas opaco y punta truncada como el continuo.

Solo stdlib (struct/zlib/re/xml). Sin PIL, sin engine.
Salida estilo repo: passes/failures por stderr, exit 1 si falla.
"""
import io
import os
import re
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PNG_PATH = str(REPO_ROOT / "resources/gfx/effects/gl_ring_beam.png")
ANM2_PATH = str(REPO_ROOT / "resources/gfx/effects/gl_ring_beam.anm2")

# --- Umbrales SPEC-W3 (tap-beam mini-rayo sin flecha) ---
CORE_HALF_MIN = 7          # grosor blanco vertical en x=32 por frame
INNER_MIN = 200            # halo interno verde claro opaco por frame
OUTER_MIN = 160            # halo externo suave (alpha<=190) verdoso por frame
MIN_CHANNEL = 120          # base clara: min(r,g,b) en px con a>128
OPAQUE_MIN = 1000          # haz rotundo: px con a>8 por frame
TIP_MAX = 20               # sin flecha: px opacos en x54-63 por frame (<=)
TIP_WIDTH_MAX = 4          # sin flecha: alto vertical opaco en x=56 (<=)
PIVOT_MIN = 30             # base del anillo: px opacos en x0-6 por frame
FRAME_DIFF_MIN = 60        # frames animados: diff par-a-par minima
CENTER_RUN_MIN = 40        # nucleo blanco horizontal en fila central

TAP_ANIMS = (
    ["Idle"]
    + ["RegularTear%d" % i for i in range(1, 14)]
    + ["BloodTear%d" % i for i in range(1, 14)]
    + ["Rotate%d" % i for i in range(1, 14)]
)


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "firma PNG invalida"
    pos, w, h, idat = 8, None, None, b""
    while pos < len(data):
        (ln,) = struct.unpack(">I", data[pos:pos + 4])
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, depth, ctype, _, _, _ = struct.unpack(">IIBBBBB", chunk)
            assert depth == 8 and ctype == 6, "se espera RGBA8"
        elif typ == b"IDAT":
            idat += chunk
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * 4
    rows = []
    for y in range(h):
        off = y * (stride + 1) + 1
        rows.append(raw[off:off + stride])
    return w, h, rows


def px(rows, x, y):
    r = rows[y]
    o = x * 4
    return (r[o], r[o + 1], r[o + 2], r[o + 3])


def is_white(p):
    r, g, b, a = p
    return a > 8 and r > 200 and g > 200 and b > 200


def is_inner(p):
    r, g, b, a = p
    return a > 190 and not is_white(p) and r >= 140 and g >= 180 and b >= 140


def is_outer(p):
    r, g, b, a = p
    return 8 < a <= 190 and g > 120 and g >= r and g >= b


passes, failures = 0, 0


def check(cond, msg):
    global passes, failures
    if cond:
        passes += 1
    else:
        failures += 1
        sys.stderr.write("FAIL: %s\n" % msg)


# ---------- ATLAS ----------
W, H, ROWS = read_png(PNG_PATH)
check((W, H) == (64, 256), "atlas debe ser 64x256, es %dx%d" % (W, H))

with io.open(ANM2_PATH, encoding="utf-8") as f:
    anm2 = f.read()
anims = {}
for m in re.finditer(r'<Animation Name="([^"]+)".*?>(.*?)</Animation>',
                     anm2, re.S):
    frames = re.findall(
        r'<Frame [^>]*XPivot="(\d+)" YPivot="(\d+)" '
        r'XCrop="(\d+)" YCrop="(\d+)" Width="(\d+)" Height="(\d+)"', m.group(2))
    anims[m.group(1)] = frames

for name in TAP_ANIMS:
    fs = anims.get(name)
    check(fs is not None and len(fs) == 4,
          "%s debe existir con 4 frames" % name)
    if fs:
        for (xp, yp, xc, yc, w, h) in fs:
            ok = (w, h) == ("64", "32") and (xp, yp) == ("5", "16")
            ok = ok and int(xc) + 64 <= W and int(yc) + 32 <= H
            if not ok:
                check(False, "%s crop invalido/pivot != (5,16)" % name)
                break
        else:
            check(True, "%s crops 64x32 pivot (5,16) validos" % name)

# Beam continuo intacto: mitad inferior identica a HEAD.
cur_bottom = b"".join(bytes(ROWS[y]) for y in range(128, 256))
git = subprocess.run(["git", "show",
                      "HEAD:resources/gfx/effects/gl_ring_beam.png"],
                     capture_output=True, cwd=str(REPO_ROOT))
if git.returncode == 0:
    fd, tmp = tempfile.mkstemp(suffix="_head_beam.png")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(git.stdout)
        _, _, head_rows = read_png(tmp)
    finally:
        os.remove(tmp)
    head_bottom = b"".join(bytes(head_rows[y]) for y in range(128, 256))
    check(cur_bottom == head_bottom,
          "filas y128-255 (ContinuousBeam) deben ser identicas a HEAD")
else:
    check(False, "no se pudo leer HEAD del png para comparar continuo")

# ---------- MINI-RAYO sin flecha (frames tap y0 = f*32) ----------
for f in range(4):
    y0 = f * 32
    core = sum(1 for y in range(y0, y0 + 32) if is_white(px(ROWS, 32, y)))
    check(core >= CORE_HALF_MIN,
          "frame%d nucleo blanco en x=32: %d < %d" % (f, core, CORE_HALF_MIN))
    inner = sum(1 for y in range(y0, y0 + 32) for x in range(64)
                if is_inner(px(ROWS, x, y)))
    check(inner >= INNER_MIN,
          "frame%d halo interno: %d < %d" % (f, inner, INNER_MIN))
    outer = sum(1 for y in range(y0, y0 + 32) for x in range(64)
                if is_outer(px(ROWS, x, y)))
    check(outer >= OUTER_MIN,
          "frame%d halo externo suave: %d < %d" % (f, outer, OUTER_MIN))
    op = sum(1 for y in range(y0, y0 + 32) for x in range(64)
             if px(ROWS, x, y)[3] > 8)
    check(op >= OPAQUE_MIN,
          "frame%d opacos: %d < %d" % (f, op, OPAQUE_MIN))
    tip = sum(1 for y in range(y0, y0 + 32) for x in range(54, 64)
              if px(ROWS, x, y)[3] > 8)
    check(tip <= TIP_MAX,
          "frame%d con flecha x54-63: %d > %d" % (f, tip, TIP_MAX))
    tip_w = sum(1 for y in range(y0, y0 + 32)
                if px(ROWS, 56, y)[3] > 8)
    check(tip_w <= TIP_WIDTH_MAX,
          "frame%d punta no truncada x=56 h=%d > %d" % (f, tip_w,
                                                        TIP_WIDTH_MAX))
    piv = sum(1 for y in range(y0, y0 + 32) for x in range(7)
              if px(ROWS, x, y)[3] > 8)
    check(piv >= PIVOT_MIN,
          "frame%d base anillo x0-6: %d < %d" % (f, piv, PIVOT_MIN))
    best, cur = 0, 0
    for x in range(64):
        if is_white(px(ROWS, x, y0 + 16)):
            cur += 1
            best = max(best, cur)
        else:
            cur = 0
    check(best >= CENTER_RUN_MIN,
          "frame%d run blanco central: %d < %d" % (f, best, CENTER_RUN_MIN))

worst = 255
for y in range(128):
    for x in range(64):
        r, g, b, a = px(ROWS, x, y)
        if a > 128:
            worst = min(worst, r, g, b)
check(worst >= MIN_CHANNEL,
      "base poco tintable: min canal en opacos=%d < %d" % (worst, MIN_CHANNEL))

for a in range(4):
    for b in range(a + 1, 4):
        d = sum(1 for y in range(32) for x in range(64)
                if px(ROWS, x, a * 32 + y) != px(ROWS, x, b * 32 + y))
        check(d >= FRAME_DIFF_MIN,
              "frames %d-%d casi identicos: diff=%d" % (a, b, d))

sys.stderr.write("[test_tap_beam_sprite] passes=%d failures=%d\n"
                 % (passes, failures))
sys.exit(1 if failures else 0)
