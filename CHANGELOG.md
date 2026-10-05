# CHANGELOG — green_lantern_mod

Historial de cambios del mod. Formato: lo más nuevo arriba.

## Unreleased

### F8b — Persistencia save/continue
- Slot compartido `{oath, run}` read-modify-write; `save_run.lua` persiste willpower/sparks/rings/tier por Index. Suite 310/310.

### F8a — Oathkeeper anti-farmeo
- Flag por-run + sparks `max(20, actual)`. Harness 8/8 x3.

### F4 — Reset por cambio de personaje
- `lastPlayerType`: al cambiar, reset de estado + rekit mismo frame; familiares huérfanos inertes. Harness 28/28.

### F5 — Escudo suprime fear mismo-frame
- `shieldBlockedFrame` al bloquear; el trinket lo respeta. Harness 9/9.

### F2 — Timers de fear sin trinket
- Decremento y limpieza corren sin trinket; inversión/poof solo con él. Harness 19/19.

### F7 — Bypass de escudo por jugador
- `glShieldBypassBy = player.Index` (fallback legacy); P2 re-rollea lo de P1.
- Harness 18/18; suite 203/203.

### F6 — Coast expira solo en su dueño
- Apaga `coastCityActive` solo de `cc.owner` (fallback legacy si nil). Harness 7/7 x3.

### F3 — Vuelo de items sobrevive al depletar
- `hadItemFlight` muestrea la base con anillo activo; al depletar restaura la base.
- Harness 8/8 x3. Tainted intacto.

### F1 — Cap de anillos sin consumir pickup
- A cap: buzz + cooldown, sin familiar fantasma ni `Remove()`. Harness 11/11.

### T8 — Harness de coherencia de nombres
- `tools/test_item_names_consistency.lua` 18/18: sin `Construct:`, names↔lookups, pools↔items.

### T7 — Sin prefijo "Construct:" en nombres de items
- "Giant Fist" y "Gatling" en items.xml, pools, ids, EID, README y comentarios.
- IDs, gfx, weights y comportamiento intactos. 141/141 harnesses.

### T6 — Giant Fist con sprite dedicado + enforcement
- Nuevo `gl_giant_fist.anm2` (Idle 32x32) + PNG; `Core.ApplyGiantFistSprite`.
- `EnforceGiantFistSprite` en UPDATE/RENDER contra resets C++ (ramas separadas de beam).
- Harnesses 38/38. Dano/flags/escala intactos.

### T5 — Juramentos poéticos al activar ítems (Battery/C-Coast) + render Tainted
- `modules/item_battery.lua`: tras el refill (rama Hal), `oathText = "IN BRIGHTEST DAY..."` y `oathTextTimer = 90`. Convive con `statusMsg` mecánico (que `RestoreHalRingPower` sigue recibiendo).
- `modules/item_coastcity.lua`: tras activar, `oathText = "I AM PARALLAX!"` y `oathTextTimer = 90` (Tainted).
- `modules/hud_render.lua`: render del juramento extendido a la rama `IsTaintedHal`. Mismo patrón que Hal (decremento `currentGameFrame % 2`, color de la barra verde Tainted). Cada jugador decrementa una vez por frame; no se duplica entre ramas.
- Solo 3 ficheros tocados (+21 LOC). Test `tools/test_t5_oath_text.lua` 29/29 verde.

### T4 — Escudo: posición live + roll único Luck (fix teleport/OP)
- `Core.GetShieldOrbitPos` usada en colisiones y render (fuera `shieldWorldPos` stale).
- Orbital: un roll por proyectil con `SHIELD_REFLECT_*`; miss → `glShieldBypass`, sin segundo roll (ni en dano ni en re-entrada orbital).
- Harnesses 27+11+11+21 en verde con kill-checks.

### T3 — Posición live del escudo + fix userdata
- Nueva `Core.GetShieldOrbitPos(player, data)` (`ring_aim.lua`): `pos + orbit*0.6 + facing*24`.
- `shield.lua` la consume; compat `shieldWorldPos` hasta T4.
- Fix B1: guard por campos X/Y (Vector Isaac es `userdata`, el `type()=="table"` lo descartaba siempre); stub del harness emula userdata + kill-check.
- Harnesses 9+11+21 en verde.

### T2 — Recorte haz up 28→14px
- `GL_BEAM_UP_HEAD_SKIP` 28.0→14.0 (el hueco de S7 era excesivo); harness
  migrado, 21/21. Solo render, dano/raycast intactos.

### T1 — Paridad click/hold + consts reflect escudo
- `DISCRETE_BEAM_DMG_MULT` 0.45→0.60; MFD {6,10,14,20}: click 3.00/2.57/2.00/1.80
  vs hold 2.625 (paridad en MFD10, nichos por arma).
- `SHIELD_REFLECT_BASE/PER_LUCK/MAX` (0.25/0.05/0.75) + slider MCM.
- Harness `tools/test_t1_balance_constants.lua` 11/11.

### S9 — HUD propia +7px (sin solape con slot activo)
- `modules/hud_render.lua`: `baseY` 33→40. El slot activo del engine no es
  movible por API pública (clase HUD sin setters de posición).

### S8 — Inspector propio eliminado
- `modules/hud_render.lua` (-58/+1): fuera la caja verde de Tab/Map.
- EID sigue registrándose; `GetModItemInspectionInfo` queda como API.

### S7 — Recorte visual del haz continuo al apuntar arriba
- `modules/fx_beam.lua`: nueva constante local `GL_BEAM_UP_HEAD_SKIP = 28.0` (px)
  y `Core.ComputeBeamRenderStartSkip(isAimingUp, totalScreenLen)`. En
  `RenderGLContinuousBeam`, cuando se apunta arriba y hay haz suficiente,
  `dist` inicial salta esos 28 px para no pintar el segmento sobre la cabeza
  (la mano se coloca en `Vector(0,-32)` por `GetRingHandOffset`). Si el haz
  es ≤28 px no se recorta (no quedaría nada visible).
- Solo dibujo: `ring_aim.lua` (offset up), `firing_mode.lua` (`dmgStart`) y
  `beam_math.lua` (raycast/`ComputeContinuousBeamEndWorld`) intactos.
- Sin efecto en daño, hitbox ni longitud lógica del rayo (el recorte es solo
  de dibujado).
- `tools/test_fx_beam_render_skip.lua`: 21 asserts (skip unitarios + integración
  de render con stubs de Vector/Isaac/Sprite). `lua5.1 tools/test_fx_beam_render_skip.lua` → `passes=21 failures=0`.

### S5 — Vuelo del anillo respeta alas de items
- `data.ringGrantedFly` (`core.lua` init, `stats.lua` CACHE_FLYING): al agotarse
  el anillo solo se revoca el vuelo si lo había concedido el anillo; las alas
  de items se conservan. Tainted intacto.

### S3 — Rebalance click-vs-hold agresivo
- `HOLD_FRAMES 15→10`, `CONT_BEAM 0.25→0.35`, `DISCRETE 0.70→0.45`;
  intervalo `max(6,min(10,MFD*0.70))`; ratio hold/click ≥1.15 en MFD 6–20.
- Slider MCM `HOLD_FRAMES` 4–30 + aviso de inversión de dominio.

### S1 — Escudo orbital siempre delante
- Orbital en `POST_PLAYER_RENDER`, aura hexagonal detrás; sin `math.sin` en
  el fichero; partículas no-escudo a pulsación binaria/rectangular.

### Rebalance click-vs-hold
- `DISCRETE_BEAM_DMG_MULT = 0.70`: los beams por click pegan el 70% del daño
  de ficha (Puño Gigante excluido, conserva su 10x).
- `HAL_CONTINUOUS_BEAM_DMG_MULT`: `0.20 → 0.25` (1.5x → ~1.9x DPS sostenido).
- Ambos ajustables en MCM. Objetivo: click = burst con coste, hold = DPS
  sostenido + multitudes.

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
