#!/usr/bin/env python3
"""tools/gen_tap_beam_sprite.py — SPEC-W3: regenera el tap-beam mini-rayo.

Reescribe SOLO las filas y0-127 (4 frames tap de 64x32) de
`resources/gfx/effects/gl_ring_beam.png` con nucleo blanco + halo verde
2 capas + estela comica (dientes + lineas de velocidad), punta roma
continua SIN arrowhead (mini-rayo, truncado como el continuo).
Las filas y128-255 (ContinuousBeam) se copian byte a byte: beam
continuo intacto, .anm2 y pivot (5,16) sin cambios.

Base toda clara (gen garantiza min canal 168 en opacos con a>128;
el test exige >=120 con margen) para que Color() tina.
Solo stdlib. Uso: python tools/gen_tap_beam_sprite.py (cwd cualquiera
dentro del repo).
"""
import struct
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PNG_PATH = str(REPO_ROOT / "resources/gfx/effects/gl_ring_beam.png")
W, H = 64, 256

WHITE = (255, 255, 255, 255)
INNER = (168, 255, 168, 255)   # halo interno opaco verde claro
OUTER = (150, 245, 150, 110)   # halo externo suave
AA = (200, 255, 200, 150)      # feather (claro para no romper tinte)
SPEED = (150, 245, 150, 100)   # lineas de velocidad


def core_half(x, f):
    """Semigrosor del nucleo blanco en x (ondula 4/5, fase por frame)."""
    return 4 + (1 if ((x + f) % 8) < 2 else 0)


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, w, h, idat = 8, None, None, b""
    while pos < len(data):
        (ln,) = struct.unpack(">I", data[pos:pos + 4])
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, _, _, _, _, _ = struct.unpack(">IIBBBBB", chunk)
        elif typ == b"IDAT":
            idat += chunk
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * 4
    return w, h, [bytearray(raw[y * (stride + 1) + 1:][:stride])
                  for y in range(h)]


def write_png(path, w, h, rows):
    stride = w * 4
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(typ, dat):
        c = typ + dat
        return struct.pack(">I", len(dat)) + c + struct.pack(
            ">I", zlib.crc32(c) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def make_frame(f):
    """Un frame tap de 64x32 (lista de bytearray RGBA). Mira a +X."""
    grid = [bytearray(64 * 4) for _ in range(32)]

    def setp(x, y, c):
        if 0 <= x < 64 and 0 <= y < 32:
            o = x * 4
            grid[y][o:o + 4] = bytes(c)

    # +1 en frames impares: fase de animacion (sin esto 4 frames identicos).
    end_x = 51 + (f % 2)

    # --- Cuerpo: nucleo blanco ondulante + halo interno + estela dentada ---
    for x in range(4, end_x + 1):
        hc = core_half(x, f)
        jagged = ((x + f * 2) // 3) % 2 == 0
        ext = hc + (6 if jagged else 4)
        for dy in range(-ext - 1, ext + 2):
            y = 16 + dy
            ad = abs(dy)
            if ad <= hc:
                setp(x, y, WHITE)
            elif ad <= hc + 3:
                setp(x, y, INNER)
            elif ad <= ext:
                setp(x, y, OUTER)
            elif ad == ext + 1:
                setp(x, y, AA)

    # --- Punta roma continua (SPEC-W3: sin arrowhead) ---
    # Corte truncado como el continuo (termina en end_x); 1px de halo
    # suave en end_x+1 para no dejar corte blanco duro. x54-63 queda
    # vacio: mini-rayo, sin ensanchamiento flecha.
    hc_end = core_half(end_x, f)
    for dy in range(-hc_end - 2, hc_end + 3):
        y = 16 + dy
        ad = abs(dy)
        if ad <= hc_end - 1:
            setp(end_x + 1, y, INNER)
        elif ad <= hc_end + 1:
            setp(end_x + 1, y, OUTER)
        elif ad == hc_end + 2:
            setp(end_x + 1, y, AA)

    # --- Base del anillo (pivot 5,16): disco esmeralda con corazon blanco ---
    for y in range(32):
        for x in range(12):
            d = ((x - 4) ** 2 + (y - 16) ** 2) ** 0.5
            if d <= 2.5:
                setp(x, y, WHITE)
            elif d <= 4.5 + (f % 2) * 0.5:
                setp(x, y, INNER)
            elif d <= 6.5:
                setp(x, y, OUTER)

    # --- Lineas de velocidad (estela comica, fase por frame) ---
    for x in range(12, 37):
        if ((x + f * 2) // 2) % 2 == 0:
            setp(x, 5, SPEED)
            setp(x, 26, SPEED)
    for x in range(16, 31):
        if ((x + f * 3) // 2) % 2 == 1:
            setp(x, 7, SPEED)
            setp(x, 24, SPEED)
    return grid


def main():
    w, h, rows = read_png(PNG_PATH)
    assert (w, h) == (W, H), "atlas inesperado %dx%d" % (w, h)
    for f in range(4):
        frame = make_frame(f)
        for y in range(32):
            rows[f * 32 + y] = frame[y]
    write_png(PNG_PATH, w, h, rows)
    print("tap-beam mini-rayo escrito: 4 frames 64x32 sin flecha, continuo intacto")


if __name__ == "__main__":
    main()
