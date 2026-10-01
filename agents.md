# agents.md — green_lantern_mod

Contexto: Mod Isaac Repentance+ (Hal Jordan + Tainted Hal). Root: `main.lua` (2935 líneas), `content/*.xml`, `resources/gfx/`, `metadata.xml`.

## Norma 1 — Metodología Hipermodular con RSI (Responsabilidad, Separación, Independencia)

Todo cambio en el mod sigue RSI:

1. **Responsabilidad única:** un módulo/fichero = un sistema. Ej: `willpower.lua`, `beam.lua`, `tainted_sparks.lua`, `items_active.lua`. Nada de mezclar Willpower + Coast City + HUD en el mismo bloque. Referencia actual: `main.lua` SECTIONS 1-7 deben tratarse como módulos lógicos aunque aún estén en un solo fichero.
2. **Separación:** Lua ≠ XML ≠ gfx ≠ docs.
   - Lógica solo en `main.lua` / `modules/*.lua` (vía `include()`).
   - Definiciones solo en `content/players.xml`, `items.xml`, `trinkets.xml`, `costumes2.xml`.
   - Sprites solo en `resources/gfx/` + `content/gfx/`. No hardcodear rutas fuera de `RegisterStageAPIGraphics()` / `ApplyRingBeamSprite()`.
   - Balance/stats solo vía constantes SECTION 1 (`WILLPOWER_*`, `HAL_*`, `SPARK_*`, `TAINTED_*`) + `MC_EVALUATE_CACHE`.
3. **Independencia:** ningún módulo rompe a otro si falla o falta.
   - IDs siempre vía `LoadItemIDs()` + guards `if not ITEM_X then return end`.
   - Estado solo vía `GetPlayerData(player).GreenLantern`, nunca globales sueltos.
   - Todo acceso API inseguro con `pcall` (patrón `SetEntityScaleAndColor`, `HasTearFlag`).
   - Prohibido acoplar sistemas: Willpower no toca `emeraldSparks`; beam no toca `CoastCity`; `EnforceTaintedHalNoRedHearts` no toca daño.

Reglas de implementación:
- Fichero nuevo < 300 líneas. Si supera, dividir.
- No editar 2 sistemas en el mismo commit. Un commit = un módulo.
- Antes de tocar `main.lua`, leer SECTION implicada + `GetPlayerData` + constantes.
- Verificar con `git diff --stat` que solo toca el módulo objetivo.
