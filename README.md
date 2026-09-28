# Green Lantern Mod — The Binding of Isaac: Repentance+

Mod de **Green Lantern (Hal Jordan)** y su versión Tainted (**The Butcher of Oa / Parallax**) para *The Binding of Isaac: Repentance+*.

---

## Personajes

### 1. Hal Jordan (Green Lantern)
- **Salud inicial:** 2 Corazones Rojos, 1 Corazón de Alma.
- **Habilidad innata:** Vuelo y disparos de energía esmeralda desde su anillo.
- **Mecánica exclusiva — Willpower & Power Battery (Pocket Active):**
  - Dispone de una barra de **Willpower** bajo los corazones que se consume al disparar y se recarga en combate o usando la **Power Battery** (ítem activo de bolsillo).
  - **Sobrecarga (>100%):** Otorga daño adicional y lágrimas espectrales/perforantes temporalmente.
  - **Batería agotada (0%):** Reduce la cadencia de disparo hasta recargar el anillo.

### 2. Tainted Hal (The Butcher of Oa / Parallax)
- **Salud inicial:** 1 Corazón Rojo, 2 Corazones Negros.
- **Mecánica exclusiva — Stolen Rings (Pocket Active):**
  - Forja anillos a partir de enemigos derrotados y acumula hasta 10 anillos de poder que incrementan la velocidad de ataque y el daño, con riesgo de sobrecarga al recibir daño.

---

## Ítems y Trinkets

| Nombre | Tipo | Descripción |
| :--- | :--- | :--- |
| **Power Battery** | Activo (Pocket) | Recarga la barra de Willpower de Hal Jordan. |
| **Construct: Giant Fist** | Activo | Invoca un puño gigante de luz sólida que golpea y empuja enemigos. |
| **Solid Light Shield** | Pasivo | Orbital de luz sólida que bloquea proyectiles y daña al contacto. |
| **The Tragedy of Coast City** | Pasivo | Al perder corazones en una sala activa el estado *Parallax* (+Daño masivo y lágrimas de miedo). |
| **Yellow Impurity** | Trinket | Los enemigos con *Fear* sueltan chispas de energía al morir; penaliza contra enemigos amarillos/campeones. |

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
│       ├── hal_charactermenu.png     # Sprite de Hal Jordan en la rueda de selección (160x160)
│       ├── tainted_charactermenu.png # Sprite de Tainted Hal en la rueda de selección (160x160)
│       ├── charactermenu.png         # Hoja de texto/stats del menú normal (512x512)
│       ├── charactermenualt.png      # Hoja de texto/stats del menú Tainted (512x512)
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
            │   ├── portrait_hal_jordan.png   # Retrato grande de Hal Jordan (192x192)
            │   ├── portrait_tainted_hal.png  # Retrato grande de Tainted Hal (192x192)
            │   ├── name_hal_jordan.png       # Letrero con el nombre de Hal Jordan (256x64)
            │   └── name_tainted_hal.png      # Letrero con el nombre de Tainted Hal (256x64)
            └── stage/                # Transición de pesadilla entre pisos (112x112)
                ├── stage_hal_jordan.png
                └── stage_tainted_hal.png
```

---

## Instalación

Copia la carpeta `green_lantern_mod` dentro del directorio `mods` de tu instalación de Steam:
```text
C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth\mods\green_lantern_mod
```
