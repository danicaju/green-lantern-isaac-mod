-- =============================================================================
--  GREEN LANTERN MOD — main.lua (loader hipermodular RSI)
--  "In Brightest Day, In Blackest Night..."
--  Responsabilidad unica: cargar Core una vez y delegar cada sistema a modules/*.
--  Sin lógica de juego aquí. Balance en modules/core.lua, IDs en modules/ids.lua.
-- =============================================================================

local Core = include("modules.core")

include("modules.ids")(Core)
include("modules.utils")(Core)
include("modules.ring_aim")(Core)
include("modules.beam_math")(Core)
include("modules.ring_state")(Core)

include("modules.init_players")(Core)
include("modules.player_update")(Core)
include("modules.firing_mode")(Core)

include("modules.stats")(Core)

include("modules.beam_discrete")(Core)
include("modules.beam_synergies")(Core)

include("modules.item_battery")(Core)
include("modules.item_fist")(Core)
include("modules.item_gatling")(Core)
include("modules.item_coastcity")(Core)

include("modules.shield")(Core)
include("modules.trinket_fear")(Core)

include("modules.tainted_hearts")(Core)
include("modules.tainted_sparks")(Core)
include("modules.tainted_rings")(Core)

include("modules.room_reset")(Core)
include("modules.progress")(Core)
include("modules.save_run")(Core)

include("modules.fx_sprites")(Core)
include("modules.fx_beam")(Core)
include("modules.fx_shield_items")(Core)
include("modules.hud_render")(Core)
include("modules.fx_mcm")(Core)

include("modules.debug")(Core)

Isaac.ConsoleOutput("[GreenLanternMod] Loaded successfully. In brightest day, in blackest night!\n")
