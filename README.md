# Green Lantern Mod — The Binding of Isaac: Repentance+

Mod de **Green Lantern (Hal Jordan)** y su versión Tainted (**The Butcher of Oa / Parallax**) para *The Binding of Isaac: Repentance+*.

---

## Personajes

### 1. Hal Jordan (Green Lantern)
- **Salud inicial:** 2 Corazones Rojos, 1 Corazón de Alma.
- **Habilidad innata:** Vuelo y disparos de energía esmeralda desde su anillo.
- **Mecánica exclusiva — Willpower & Power Battery (Pocket Active):**
  - Dispone de una barra de **Willpower** bajo los corazones que se consume al disparar y se recarga en combate o usando la **Power Battery** (ítem activo de bolsillo).
  - **Impactos devuelven +0.15%** Willpower por beam que golpea.
  - **Sobrecarga por tramos:** ≥50% → +15% DMG, ≥90% → +25% DMG temporalmente.
  - **Batería agotada (0%):** Reduce la cadencia de disparo hasta recargar el anillo.
- **Progresión Oathkeeper:** pisar Womb I como Hal/Tainted desbloquea bonus inicial permanente.
- **Menú MCM:** todo el balance (costes, drenajes, multiplicadores) es ajustable en Mod Config Menu.

### 2. Tainted Hal (The Butcher of Oa / Parallax)
- **Salud inicial:** 1 Corazón Rojo, 2 Corazones Negros.
- **Mecánica exclusiva — Stolen Rings (Pocket Active):**
  - Forja anillos a partir de enemigos derrotados y acumula hasta 10 anillos de poder (+0.3 DMG c/u) que incrementan la velocidad de ataque y el daño, con riesgo de sobrecarga al recibir daño.
  - Los beams aplican Fear con 25% de probabilidad (ajustable en MCM, 0 = off); Coast City lo garantiza.
  - **Hambre de Parallax:** sin kills, el medidor decae 2%/s tras 5s.
  - **Depredador del miedo:** +25% de rayo continuo contra enemigos con Fear.

---

## Ítems y Trinkets

| Nombre | Tipo | Descripción |
| :--- | :--- | :--- |
| **Power Battery** | Activo (Inicial) | Recarga la barra de Willpower de Hal Jordan o activa *Overcharge* (tramos +15%/+25%). |
| **Construct: Giant Fist** | Activo | Invoca un puño gigante de luz sólida que golpea y empuja enemigos. |
| **Construct: Gatling** | Activo | 10s de beams discretos rápidos sin coste de Willpower. |
| **Solid Light Shield** | Pasivo | Orbital de luz sólida que bloquea proyectiles y daña al contacto. |
| **The Tragedy of Coast City** | Activo (Tainted) | Invoca el constructo de Coast City al llenar las chispas esmeralda. |
| **Yellow Impurity** | Trinket | Incrementa el daño x1.5, pero los impactos recibidos pueden causar *Fear*. |

---

## Estructura del Proyecto y Archivos Gráficos

```text
green_lantern_mod/
├── main.lua                          # Lógica principal del mod
├── metadata.xml                      # Metadatos del mod para Isaac
├── content/
│   ├── players.xml                   # Definición de Hal Jordan y Tainted Hal
│   ├── items.xml                     # Definición de los 4 ítems
│   ├── trinkets.xml                  # Definición del trinket Yellow Impurity
│   └── gfx/                          # Gráficos y animaciones del menú de selección de personaje
│       ├── hal_charactermenu.png     # Sprite y textos de Hal Jordan en el menú (160x160)
│       ├── tainted_charactermenu.png # Sprite y textos de Tainted Hal en el menú (160x160)
│       ├── charactermenu.png         # Hoja base del menú normal (512x555)
│       ├── charactermenualt.png      # Hoja base del menú Tainted (512x556)
│       ├── characterportraits.anm2   # Animación del retrato en el menú normal
│       ├── characterportraitsalt.anm2# Animación del retrato en el menú Tainted
│       ├── charactermenu.anm2        # Animación del nombre/stats en el menú normal
│       └── charactermenualt.anm2     # Animación del nombre/stats en el menú Tainted
└── resources/
    └── gfx/
        ├── characters/               # Sprites in-game durante la partida
        │   ├── hal_jordan.png        # Sprite sheet principal de Hal Jordan (512x512)
        │   ├── hal_jordan_extra.png  # Animaciones extra de constructos de Hal Jordan (1024x1024)
        │   ├── tainted_hal.png       # Sprite sheet principal de Tainted Hal (512x512)
        │   └── tainted_hal_extra.png # Animaciones extra de Tainted Hal (1024x1024)
        ├── items/
        │   ├── collectibles/         # Iconos de ítems en pedestales e inventario (32x32)
        │   │   ├── collectible_power_battery.png
        │   │   ├── collectible_giant_fist.png
        │   │   ├── collectible_solid_light_shield.png
        │   │   └── collectible_coast_city.png
        │   └── trinkets/             # Icono del trinket (32x32)
        │       └── trinket_yellow_impurity.png
        └── ui/
            ├── boss/                 # Pantalla VS contra jefes y racha de victoria
            │   ├── portrait_hal_jordan.png   # Retrato de Hal Jordan en pantalla VS (144x144)
            │   ├── portrait_tainted_hal.png  # Retrato de Tainted Hal en pantalla VS (144x144)
            │   ├── name_hal_jordan.png       # Letrero con el nombre de Hal Jordan (192x64)
            │   └── name_tainted_hal.png      # Letrero con el nombre de Tainted Hal (192x64)
            └── stage/                # Transición de pesadilla entre pisos (144x144)
                ├── stage_hal_jordan.png
                └── stage_tainted_hal.png
```

---

## Instalación

Copia la carpeta `green_lantern_mod` dentro del directorio `mods` de tu instalación de Steam:
```text
C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\mods\green_lantern_mod
```
