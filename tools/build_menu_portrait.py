#!/usr/bin/env python3
"""Reconstruye el retrato del character menu desde el sheet recrispificado.

Paso B aprobado por el usuario: tomar la celda de personaje completo del sheet
recrispificado (Down-idle) y escalarla por NEAREST a escala 1.5x para encajar en
la caja del retrato del menu, preservando el resto de la hoja (los textos).

Uso:
  python tools/build_menu_portrait.py --preview   # solo comparativa
  python tools/build_menu_portrait.py --apply     # sobrescribe las hojas del menu
"""
import argparse
import os
import sys
from PIL import Image

MENU_DIR = "content/gfx"
SHEET_DIR = "resources/gfx/characters"
PAIRS = [
    ("hal_charactermenu.png", "hal_jordan.png"),
    ("tainted_charactermenu.png", "tainted_hal.png"),
]
CELL = 32
SCALE = 1.5            # 32 * 1.5 = 48 px de ancho -> encaja en la caja del retrato
# Layout medido del sheet: fila 0 = cabezas, fila 1 = cuerpos (Down idle).
HEAD_ROW, HEAD_COL = 0, 0
BODY_ROW, BODY_COL = 1, 0
HEAD_BODY_OVERLAP = 4  # px de solape cuello (cabeza sobre cuerpo)
ALPHA_CUTOFF = 128
PREVIEW_ZOOM = 6
PREVIEW_PATH = os.path.join(os.environ.get("TEMP", "/tmp"), "opencode", "menu_portrait_preview.png")


def harden_alpha(im):
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < ALPHA_CUTOFF:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, 255)
    return im


def find_down_idle_cell(sheet):
    """Celda 32x32 con mas pixeles opacos en la fila 0 (Down idle/walk)."""
    best, best_n = None, -1
    for cx in range(9):
        cell = sheet.crop((cx * CELL, 0, cx * CELL + CELL, CELL))
        n = sum(1 for p in cell.getdata() if p[3] >= ALPHA_CUTOFF)
        if n > best_n:
            best_n, best = n, cx
    return best, best_n


def character_region(menu):
    """BBox del sprite del personaje (todo lo opaco por encima del texto)."""
    px = menu.load()
    w, h = menu.size
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(0, 56):
        for x in range(w):
            if px[x, y][3] >= ALPHA_CUTOFF:
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
    if maxx < 0:
        return None
    return (minx, miny, maxx + 1, maxy + 1)


def cell_content(sheet, row, col):
    cell = sheet.crop((col * CELL, row * CELL, col * CELL + CELL, row * CELL + CELL))
    bbox = cell.getbbox()
    return cell.crop(bbox) if bbox else cell


def compose_character(sheet):
    """Compone cabeza (fila 0) + cuerpo (fila 1) para el retrato Down-idle."""
    head = cell_content(sheet, HEAD_ROW, HEAD_COL)
    body = cell_content(sheet, BODY_ROW, BODY_COL)
    w = max(head.width, body.width) + 8
    h = head.height + body.height - HEAD_BODY_OVERLAP + 8
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Cuerpo abajo; cabeza encima con solape.
    bx = (w - body.width) // 2
    by = h - body.height - 4
    canvas.paste(body, (bx, by), body)
    hx = (w - head.width) // 2
    hy = by - head.height + HEAD_BODY_OVERLAP
    canvas.paste(head, (hx, hy), head)
    bbox = canvas.getbbox()
    return canvas.crop(bbox) if bbox else canvas


def build(menu_path, sheet_path):
    menu = Image.open(menu_path).convert("RGBA")
    sheet = Image.open(sheet_path).convert("RGBA")

    composed = compose_character(sheet)

    region = character_region(menu)
    rw, rh = region[2] - region[0], region[3] - region[1]

    # Encaja el personaje DENTRO de la caja del retrato (sin desbordar ni tocar
    # el texto), con NEAREST para conservar bordes duros. SCALE actua de tope.
    s = min(SCALE, rw / composed.width, rh / composed.height)
    tw = max(1, int(round(composed.width * s)))
    th = max(1, int(round(composed.height * s)))
    scaled = harden_alpha(composed.resize((tw, th), Image.NEAREST))

    out = menu.copy()
    # Limpia la caja del personaje y pega el sprite nuevo centrado.
    clear = Image.new("RGBA", (rw, rh), (0, 0, 0, 0))
    out.paste(clear, (region[0], region[1]))
    ox = region[0] + (rw - tw) // 2
    oy = region[1] + (rh - th) // 2
    out.paste(scaled, (ox, oy), scaled)
    # NOTE: no global harden_alpha here — la hoja del menu conserva el AA
    # tipografico dibujado a mano ("HAL JORDAN"/"POWER BATTERY"). El sprite
    # insertado ya llega con alpha duro desde harden_alpha(scaled).
    return menu, out, f"{HEAD_ROW},{HEAD_COL}+{BODY_ROW},{BODY_COL}", tw * th


def build_preview(rows):
    pad = 8
    zoom = PREVIEW_ZOOM
    cellw = 160 * zoom
    W = pad + (cellw + pad) * 2
    H = pad + (160 * zoom + pad) * len(rows)
    canvas = Image.new("RGBA", (W, H), (40, 40, 40, 255))
    for i, (before, after) in enumerate(rows):
        y = pad + i * (160 * zoom + pad)
        canvas.paste(before.resize((cellw, cellw), Image.NEAREST), (pad, y), before.resize((cellw, cellw), Image.NEAREST))
        canvas.paste(after.resize((cellw, cellw), Image.NEAREST), (pad + cellw + pad, y), after.resize((cellw, cellw), Image.NEAREST))
    os.makedirs(os.path.dirname(PREVIEW_PATH), exist_ok=True)
    canvas.save(PREVIEW_PATH)
    return PREVIEW_PATH


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    if not (args.preview or args.apply):
        print("usa --preview o --apply")
        sys.exit(2)

    rows = []
    for menu_name, sheet_name in PAIRS:
        menu_path = os.path.join(MENU_DIR, menu_name)
        sheet_path = os.path.join(SHEET_DIR, sheet_name)
        before, after, cx, n = build(menu_path, sheet_path)
        print(f"{menu_name}: celda Down-idle col={cx} ({n} opacos) -> region reconstruida")
        if args.apply:
            after.save(menu_path)
        rows.append((before, after))

    if args.preview:
        print("preview:", build_preview(rows))


if __name__ == "__main__":
    main()
