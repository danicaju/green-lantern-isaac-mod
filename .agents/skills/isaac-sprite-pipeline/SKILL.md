---
name: isaac-sprite-pipeline
description: Asset creation, pixel art sanitization, and sprite verification pipeline for The Binding of Isaac Repentance characters, items, and UI. Use when editing sprites, fixing transparency issues, checking 20/20 costume alignments, or authoring boss banners.
---

# Isaac Sprite Pipeline Skill

This skill governs the generation, sanitization, and verification of 2D pixel art assets for The Binding of Isaac: Repentance.

---

## 1. Core Pixel Art Rules & Alpha Sanitization

### The Zero-Dirty-Alpha Rule
When sprites are imported from external art tools or converted from white/checkered backgrounds:
- **Transparent pixels (`Alpha == 0`) MUST have RGB `(0, 0, 0)`**.
- Pixels with `Alpha == 0` but RGB `(255, 255, 255)` or `(128, 128, 128)` will cause grey/white speckles when rendered by the Repentance graphics pipeline.
- Semi-transparent pixels (`0 < Alpha < 255`) create blurry anti-aliasing halos in pixel art. Every pixel should be either fully opaque (`Alpha == 255`) or completely transparent (`Alpha == 0`).

### Automated Clean-Up Script Pattern (Python PIL):
```python
from PIL import Image

def clean_alpha_channel(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    data = rgba.getdata()
    cleaned = []
    for r, g, b, a in data:
        if a < 128:
            cleaned.append((0, 0, 0, 0))  # Snap to pure black transparent
        else:
            cleaned.append((r, g, b, 255)) # Snap to solid opaque
    rgba.putdata(cleaned)
    return rgba
```

---

## 2. Character Spritesheet Grid Specifications (`001.000_player.anm2`)

- **Canvas Size**: Canonical **512×512** pixels (`RGBA`).
- **Standard Head Cell**: **32×32** pixels.
  - Down Idle / Shoot: Rows `Y = 0..32`
  - Right Idle / Shoot: Rows `Y = 32..64` (Flipped horizontally by engine for Left)
  - Up Idle / Shoot: Rows `Y = 64..96`
- **Side Profile Single-Eye Constraint**:
  - When the character faces sideways (right/left), render ONLY the profile eye and mask contour.
  - Centering both eyes on the side head causes facial items (such as 20/20 glasses, Polyphemus, and Monstro's Lung) to bisect the skull or misalign.
- **Celebratory Pickup Animations**:
  - Row `Y = 192`: Pickup hold frames (`XCrop = 0` and `XCrop = 64`).
  - Cells in `X = 256..512, Y = 0..128`: 20 walking pickup body frames with raised celebratory arms (`\o/`).

---

## 3. Boss VS Screen Banner Specifications

- **Path**: `resources/gfx/ui/boss/name_<character>.png`
- **Canvas Size**: Canonical **192×64** pixels.
- **Color Palette**: `#C7B299` (`RGBA(199, 178, 153, 255)`) with anti-aliasing.
- **Text Height**: **19–20 pixels** (content width ~104–112 px matching Isaac, Judas, and Cain).
- **Alignment**: Center text horizontally around **X = 104** (left margin **X = 48–52**, right margin **X = 156–160**). In `versusscreen.anm2`, this prevents clipping on the left edge while leaving clean space before the "VS" emblem.

---

## 4. Verification Previews

Always generate 4× zoom composite previews (e.g., character head + body + test costumes) into the artifact directory before requesting user feedback on sprite changes.
