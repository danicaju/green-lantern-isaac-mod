# CHANGELOG — green_lantern_mod

Historial de cambios del mod. Formato: lo más nuevo arriba.

## Unreleased

### Rebalance: Fear de Tainted por probabilidad
- `TAINTED_FEAR_CHANCE = 0.25` (`core.lua`): los beams, el rayo continuo y los
  lasers de Tainted ya NO aplican Fear siempre; tiran 25% por impacto/tick/láser.
- Quitado `TEAR_FEAR` permanente de los flags base (`stats.lua`, `beam_discrete.lua`).
- Coast City mantiene su Fear 100% (ítem activo de 4 cargas): pasa a ser LA
  herramienta de miedo, no un extra redundante.
- Efectos en cadena: menos Fear ambiente = menos drops esmeralda al 14%,
  y el bonus Depredador (+25% vs Fear) se vuelve situacional.
- Ajustable en MCM (`Tainted Fear chance`, 0–1; 0 = sin Fear).

## 2026-10-02 — Upgrades de gameplay

- **E. Cap de anillos + bonus**: `MAX_STOLEN_RINGS = 10` (el README lo prometía,
  el código no lo cumplía), `+0.3 DMG` por anillo, re-eval de daño al forjar.
- **B. Reembolso por impacto**: cada beam de Hal que golpea devuelve `+0.15%`
  Willpower (`WILLPOWER_HIT_REFUND`).
- **D. Hambre de Parallax**: `emeraldSparks` decae `2%/s` tras 5s sin kill
  (`SPARK_DECAY_PER_SEC`, `SPARK_DECAY_GRACE_FRAMES`).
- **F. Depredador del miedo**: `+25%` de rayo continuo vs enemigos con Fear
  (conmutable: `FEAR_VULN_ENABLED`).
- **C. Overcharge por tramos**: `≥50% → ×1.15`, `≥90% → ×1.25`
  (`OVERCHARGE_T1/T2_*`), con etiqueta HUD correspondiente.
- **A. Menú MCM**: 8 ajustes de balance en Mod Config Menu (opcional, con guard).
- **G. Oathkeeper persistente**: pisar Womb I como Hal/Tainted desbloquea bonus
  inicial permanente (Hal +1 Soul Heart, Tainted +20% sparks). Guardado en
  SaveModData. (Se descartó `achievements.xml`: en `content/` no tiene efecto
  y en `resources/` reemplazaría los logros vanilla.)
- **H. Construct: Gatling** (ítem activo id 6, 4 cargas): 10s de beams rápidos
  sin coste (`GATLING_DURATION = 300`). Icono placeholder (copia del Fist)
  pendiente de arte final. EID + inspector + indicador HUD incluidos.
- **Pools**: nuevo `content/itempools.xml` (Treasure/Shop). De paso, Giant Fist,
  Shield, Ring y Gatling ya aparecen en runs (antes solo por consola).

## 2026-10-02 — Fixes del review

1. Co-op: vórtice Coast City por jugador (`Core.GetCoastCity`) — ya no se pisan.
2. Escudo: `grantedSolidShieldHearts` se resetea al perderlo (D4/reroll).
3. Debug: `gl_sparks` clampeado a `[0, SPARK_MAX]`.
4. `RefreshCharacterCostume` es no-op documentado (`costumes2.xml` vacío) —
   se conserva como punto de extensión.
5. `oathTextTimer` decrementa cada 2 render frames (duración real ~30Hz).
- Limpieza: eliminada rama `EntityLaser` continuo muerta (-60 líneas, el rayo
  es 100% Lua + sprite). Cooldown 15f al consumir pedestales con DROP.
- Throttle: inspector de pedestales cada 15 render frames.

## 2026-10-01 — Refactor hipermodular (RSI)

- `main.lua` monolito (3239 líneas) → loader de 45 líneas + 26 módulos en
  `modules/` (todos <300 líneas), estado compartido vía tabla `Core`,
  carga con `include("modules.*")`. 1 commit por módulo.
- Sin cambios de comportamiento salvo el split intencional de
  `MC_POST_PLAYER_UPDATE` en base (`player_update`) + disparo (`firing_mode`).
- `agents.md`: Norma 1 — Responsabilidad, Separación, Independencia.
- `opencode.json`: MCPs `github` (PAT) + `context7` (no commiteado).
