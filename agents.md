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

## Norma 2 — Modelos baratos y enrutado (Opencode Go)

Objetivo: no quemar saldo. Precios en USD por millón de tokens (input/output).
Nivel gratuito ($0): `minimax-m3.1-flash-free`, `beam-free`, `longcat-2.5-preview-free`.
Nivel barato (<0.2 in): `muse-spark-1.3-contributor` (0.1/0.2), `mimo-v2.5` (0.14/0.28),
`deepseek-v4.1-flash` (0.15/0.6). Nivel medio: `mimo-v2.6-pro` (0.435/0.87),
`qwen3.7-plus` (0.4/1.6), `deepseek-v4-pro` (0.66/1.98).
Prohibidos sin aprobación explícita del usuario (`kimi-k3`, `grok-4.7`,
`qwen3.8-max`, `gemini-4-argon`: todos >$2/M input).

| Rol | Subagentes | Modelo (`opencode-go/...`) | Variant |
| :--- | :--- | :--- | :--- |
| Enrutador (clasifica S/M/L/H) | `orquestador-*`, paso 0 | `minimax-m3.1-flash-free`, fallback `deepseek-v4.1-flash` | `low` |
| Explore (lectura masiva, sin editar) | `explore`, `researcher` | `beam-free`, fallback `minimax-m3.1-flash-free` | `low`/`minimal` |
| Tester (harness + veredicto literal) | `tester-*` | `minimax-m3.1-flash-free`, fallback `deepseek-v4.1-flash` | `low` |
| Docs (README/CHANGELOG/commits) | `documenter` | `longcat-2.5-preview-free` | (sin variants) |
| S (1 archivo, ≤250 líneas) | `implementador-*`, `improver-*` | `mimo-v2.5` | (sin variants) |
| M (2-5 archivos, feature) | `implementador-*`, `improver-*`, `refactor` | `mimo-v2.6-pro` en vez de `kimi-k2.7-code` (~3x más barato en mezcla típica) | (sin variants) |
| L/arquitectura (plan, multi-fichero) | `architect`, `planner-*` | `qwen3.7-plus` | default (`high` si se atasca) |
| Review / Security | `reviewer-*`, `security-*` | `qwen3.7-plus` | default |
| H (tras 2 fallos, turno único) | `scalpel` | `deepseek-v4-pro` | `max` |
| Principal / orquestador (esta sesión y siguientes) | — | `deepseek-v4.1-flash` | default |

Reglas de enrutado:
- Clasifica S/M/L/H/Docs/Explore ANTES de delegar; el override explícito del
  usuario siempre gana.
- Pasa el modelo al subagente con el parámetro `model: "opencode-go/<id>"`
  (nunca `provider/model#variant` inventado; variant solo si existe arriba).
- Tareas mecánicas (grep masivo, contar asserts, copiar formato) van a nivel
  gratuito; si un gratuito falla 2 veces en lo mismo, se sube un nivel y se
  sigue (no reintentos ciegos).
- Los modelos gratuitos pueden tener límites de ritmo: ante `rate limit`,
  usar el fallback de su fila sin preguntar.
- Código de gameplay (Lua del mod) nunca va a un modelo gratuito en primera
  instancia: mínimo `mimo-v2.5` (S) o `mimo-v2.6-pro` (M).
- Orden obligatorio (el principal lo hace cumplir): 1) clasificar S/M/L/H/Docs/
  Explore, 2) delegar SOLO al subagente y modelo de su fila, 3) verificar la
  salida antes de avanzar. Si un paso se salta o usa otro modelo, parar,
  re-enrutar y dejar constancia en el handoff.
