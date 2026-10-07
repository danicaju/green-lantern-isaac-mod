-- modules/core.lua — RSI: constantes, GL y estado compartido. Sin callbacks, sin combate.
-- Responsabilidad unica: ser la unica fuente de verdad para balance (SECTION 1)
-- y estado por jugador / compartido (SECTION 2). Todo modulo recibe Core y lo usa.

local Core = {}

Core.GL = RegisterMod("GreenLanternMod", 1)

-- IDs resueltos en runtime por modules/ids.lua (se declaran aqui, se rellenan alli).
Core.ITEM_POWER_BATTERY       = nil
Core.ITEM_GIANT_FIST          = nil
Core.ITEM_GATLING             = nil
Core.ITEM_COAST_CITY          = nil
Core.ITEM_SOLID_LIGHT_SHIELD  = nil
Core.ITEM_POWER_RING          = nil
Core.TRINKET_YELLOW_IMPURITY  = nil

Core.COSTUME_HAL              = -1
Core.COSTUME_TAINTED_HAL      = -1

Core.PLAYER_HAL               = nil
Core.PLAYER_TAINTED_HAL       = nil

-- Balance Hal Jordan (solo via MC_EVALUATE_CACHE en modules/stats.lua).
Core.HAL_SPEED_BONUS          = 0.15
Core.HAL_SHOT_SPEED_BONUS     = 0.30
Core.HAL_WILL_BASE_MULT       = 1.10
Core.HAL_FIREDELAY_BONUS      = 2

-- Willpower y rayo continuo.
Core.WILLPOWER_MAX                 = 100.0
Core.WILLPOWER_PER_TEAR            = 0.5
Core.WILLPOWER_HIT_REFUND          = 0.15
Core.FEAR_VULN_ENABLED             = true
Core.OVERCHARGE_T1_THRESHOLD       = 50.0
Core.OVERCHARGE_T2_THRESHOLD       = 90.0
Core.OVERCHARGE_T1_MULT            = 1.15
Core.OVERCHARGE_T2_MULT            = 1.25
Core.WILLPOWER_REBOOT_THRESHOLD    = 20.0
Core.WILLPOWER_PASSIVE_REBOOT_RATE = 0.085
Core.WILLPOWER_KILL_REBOOT_BONUS   = 5.0
Core.WILLPOWER_ROOM_REBOOT_BONUS   = 15.0
Core.HAL_CONTINUOUS_HOLD_FRAMES    = 10
Core.HAL_SPAM_EXTRA_HOLD_FRAMES    = 5
Core.HAL_CONTINUOUS_BEAM_DMG_MULT  = 0.35
Core.DISCRETE_BEAM_DMG_MULT        = 0.60
Core.HAL_CONTINUOUS_TICK_FRAMES    = 4
Core.HAL_CONTINUOUS_WILL_DRAIN     = 0.06
-- SPEC-D: crecimiento fluido del rayo continuo (solo render, estilo Brimstone).
-- El haz visible crece 0->full en N frames al iniciar/cambiar de direccion.
-- Raycast/dano/tick-rate intactos (viven en beam_math.lua con el endWorld completo).
Core.CONTINUOUS_BEAM_GROWTH_FRAMES = 10
-- Minimo en pantalla para disparar/dibujar el haz (~4px umbral degenerado).
-- Permite disparar pegado al muro sin bloquearse. Por debajo de SHORT_THIN_LEN
-- el grosor se clampa a <=1.0 para no tapar la cara.
Core.CONTINUOUS_BEAM_MIN_RENDER_LEN = 4.0
-- Bajo esta longitud el haz corto se dibuja fino (clamp <=1.0).
Core.CONTINUOUS_BEAM_SHORT_THIN_LEN = 44.0

-- Escudo orbital: probabilidad de reflejar disparos del enemigo. Alineado con
-- el calculo de modules/shield.lua (base 0.25, +0.05/Luck, cap 0.75). Las dos
-- ramas (orbital y MC_ENTITY_TAKE_DMG) las consumen desde shield.lua;
-- bypass glShieldBypass evita re-rolls frame-a-frame para proyectiles lentos.
Core.SHIELD_REFLECT_BASE       = 0.25
Core.SHIELD_REFLECT_PER_LUCK   = 0.05
Core.SHIELD_REFLECT_MAX        = 0.75

-- Tainted Hal.
Core.TAINTED_DMG_MULTIPLIER   = 1.35
Core.TAINTED_TEARS_PENALTY    = -2.0
Core.TAINTED_FEAR_CHANCE      = 0.25
Core.MAX_STOLEN_RINGS         = 10
Core.STOLEN_RING_DMG          = 0.3

-- Emblemas esmeralda.
Core.SPARK_MAX                = 100.0
Core.SPARK_PER_KILL           = 10.0
Core.SPARK_DECAY_PER_SEC      = 2.0
Core.SPARK_DECAY_GRACE_FRAMES = 150
Core.SPARK_LIFETIME_FRAMES    = 180
Core.SPARK_BLINK_FRAMES       = 60
Core.SPARK_COLLECT_FRAMES     = 12
Core.SPARK_PICKUP_RANGE       = 22.0
Core.SPARK_DROP_CHANCE_FEARED = 0.14
Core.SPARK_DROP_CHANCE_NORMAL = 0.08

Core.COAST_CITY_DURATION  = 150
Core.GATLING_DURATION     = 300

-- Opciones de accesibilidad y audio
Core.SCREEN_SHAKE_ENABLED = true
Core.HUD_GL_DISPLAY       = true
Core.SFX_VOLUME_MULT      = 1.0
Core.BIRTHRIGHT_ENABLED   = true

-- Estado compartido: un vortice Coast City por jugador (co-op seguro).
Core.activeCoastCityByPlayer = {}

function Core.GetCoastCity(player)
    local key = (player and player.Index) or 0
    local cc = Core.activeCoastCityByPlayer[key]
    if not cc then
        cc = {
            active     = false,
            spawnFrame = 0,
            roomIdx    = -1,
            owner      = nil,
            sparkBonus = 1.0,
        }
        Core.activeCoastCityByPlayer[key] = cc
    end
    return cc
end

function Core.ClearAllCoastCities()
    Core.activeCoastCityByPlayer = {}
end

-- Drops de emblemas en el suelo (renderizados via anm2, nunca como coins).
Core.activeEmeraldSparks = {}

function Core.SpawnLanternEmblemDrop(pos)
    local roomIdx = Game():GetLevel():GetCurrentRoomIndex()
    table.insert(Core.activeEmeraldSparks, {
        pos          = Vector(pos.X, pos.Y),
        spawnFrame   = Game():GetFrameCount(),
        roomIdx      = roomIdx,
        collected    = false,
        collectFrame = 0,
    })
end

function Core.ClearAllLanternEmblemDrops()
    Core.activeEmeraldSparks = {}
end

function Core.GetPlayerData(player)
    local d = player:GetData()
    if not d.GreenLantern then
        d.GreenLantern = {
            willpower                    = Core.WILLPOWER_MAX,
            ringDepleted                 = false,
            hadItemFlight                = false,
            overcharge                   = false,
            surgeBuff                    = false,
            overchargeRoomIdx            = -1,
            oathTextTimer                = 0,
            oathText                     = "",
            shootHoldFrames              = 0,
            lastShootUpdateFrame         = -1,
            lastSmallBeamFrame           = -999,
            lastDiscreteClickReleaseFrame = -999,
            firedSmallBeamThisPress      = false,
            lastShootDir                 = nil,
            renderLastShootDir           = nil,
            wasHoldingShootOnRender      = false,
            sawShootReleaseBetweenFrames = false,
            sawShootPressBetweenFrames   = false,
            bufferedClickDir             = nil,
            bufferedClickExpireFrame     = 0,
            humanTapShootDir             = nil,
            humanTapExpireFrame          = 0,
            isFiringContinuousBeam       = false,
            spawningContinuousBeam       = false,
            continuousLaser              = nil,
            continuousBeamGraceTimer     = 0,
            -- SPEC-D: crecimiento fluido del rayo (solo render, por jugador, nunca global).
            -- beamGrowthDir es el lastBeamDir del crecimiento; beamGrowthBaseLen la
            -- longitud visible desde la que se reinicia tras un giro >~30 grados.
            beamGrowthFrame              = 0,
            beamGrowthDir                = nil,
            beamGrowthBaseLen            = 0.0,
            allowingTapTear              = false,
            emeraldSparks       = 0.0,
            stolenRings         = 0,
            coastCityActive     = false,
            coastCityFrame      = 0,
            coastCityBoost      = 1.0,
            fearControlTimer    = 0,
            ringFlareTimer      = 0,
            lastRingHandOffset  = Vector(18, -14),
            batteryConstructTimer = 0,
            batteryOrbitAngle    = 0.0,
            shieldDeflectTimer    = 0,
            fearSkullTimer        = 0,
            lastCollectibleCount = -1,
            multiShotFrame       = -1,
            multiShotIndex       = 0,
            lastPlayerType       = nil,
        }
    end
    return d.GreenLantern
end

return Core
