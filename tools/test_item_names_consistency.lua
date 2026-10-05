-- tools/test_item_names_consistency.lua
-- T8 — guard de consistencia entre content/items.xml, content/itempools.xml
-- y modules/ids.lua. Compatible con Lua 5.1.
--
-- Spec:
--   (a) Ningun fichero de la lista contiene la cadena literal "Construct:"
--       (prefijo eliminado en T7):
--         - content/items.xml
--         - content/itempools.xml
--         - modules/ids.lua
--         - modules/fx_sprites.lua
--         - README.md
--   (b) Cada name="X" de content/items.xml tiene una llamada de resolucion
--       de ID en modules/ids.lua. Para <active>/<passive> se exige
--       `GetItemIdByName("X")`; para <trinket> se exige
--       `GetTrinketIdByName("X")`. Esto preserva el contrato T8: cualquier
--       nombre nuevo en items.xml debe tener su lookup correspondiente
--       (sea item o trinket).
--   (c) Cada <Item Name="X"> de content/itempools.xml debe existir como
--       name="X" en content/items.xml.
--
-- Estilo: mismo `io.open` + `string.match` que el resto de harnesses de tools/.
-- Rutas relativas a la raiz del mod; se ejecuta desde ahi:
--     "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\test_item_names_consistency.lua

-- ===================== HELPERS =====================
local passes, failures = 0, 0
local function check(cond, msg)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
    end
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a") or ""
    f:close()
    return content
end

-- ===================== (a) SIN PREFIJO "Construct:" =====================
local filesToScanForConstructColon = {
    "content/items.xml",
    "content/itempools.xml",
    "modules/ids.lua",
    "modules/fx_sprites.lua",
    "README.md",
}
for _, relPath in ipairs(filesToScanForConstructColon) do
    local content = readFile(relPath)
    if content == nil then
        -- No abortamos: puede ser un fichero opcional durante desarrollo.
        -- El test solo verifica la regla sobre los ficheros que SI existen.
        check(false, string.format("(a) no se puede abrir %s", relPath))
    else
        -- Coincidencia literal de la cadena "Construct:" (prefijo a banear).
        -- Usamos string.find(plain, plain, 1, true) para busqueda literal.
        local pos = content:find("Construct:", 1, true)
        check(pos == nil,
              string.format("(a) %s aun contiene la cadena 'Construct:'", relPath))
    end
end

-- ===================== (b) name="X" en items.xml -> lookup en ids.lua =====================
-- 1.a) Parsear content/items.xml y clasificar nombres por tipo de elemento.
--      Patrones a buscar (en este orden):
--        <active ... name="Y" ...
--        <passive ... name="Y" ...
--        <trinket ... name="Y" ...
--      Y capturamos el `name="Y"` del mismo elemento. Estrategia robusta:
--        buscamos la apertura de la etiqueta (<active/<passive/<trinket),
--        y dentro de esa etiqueta el primer `name="Y"`.
local itemsXml = readFile("content/items.xml")
local idsLua   = readFile("modules/ids.lua")

local itemNames   = {}  -- collectibles (active/passive): exigen GetItemIdByName
local trinketNames = {} -- trinkets: exigen GetTrinketIdByName

if not itemsXml then
    failures = failures + 1
    io.stderr:write("FAIL: (b) no se puede abrir content/items.xml\n")
elseif not idsLua then
    failures = failures + 1
    io.stderr:write("FAIL: (b) no se puede abrir modules/ids.lua\n")
else
    -- Recorremos el XML linealmente y agrupamos por etiqueta de apertura.
    -- Guardamos el tag real (active/passive/trinket) junto al nombre para que
    -- los mensajes de error (b) no pierdan contexto y (c) pueda cruzar contra
    -- itempools.xml sin perder la pista del tipo de elemento.
    local pos = 1
    local collected = {}  -- lista de { tag=..., name=... } en orden de aparicion
    while true do
        -- Encuentra el siguiente <active, <passive o <trinket.
        local iA = itemsXml:find("<active",  pos, true)
        local iP = itemsXml:find("<passive", pos, true)
        local iT = itemsXml:find("<trinket", pos, true)
        local candidates = {}
        if iA then candidates[#candidates + 1] = { tag = "active",   at = iA } end
        if iP then candidates[#candidates + 1] = { tag = "passive",  at = iP } end
        if iT then candidates[#candidates + 1] = { tag = "trinket",  at = iT } end
        if #candidates == 0 then break end
        -- Elige la primera por posicion.
        table.sort(candidates, function(a, b) return a.at < b.at end)
        local hit = candidates[1]
        -- Encuentra el cierre `>` del tag de apertura (no self-closing).
        local gtPos = itemsXml:find(">", hit.at, true)
        if not gtPos then break end
        local tagText = itemsXml:sub(hit.at, gtPos)
        -- Captura name="X" del primer name= dentro de la apertura.
        local _, _, captured = tagText:find('name%s*=%s*"([^"]+)"')
        if captured then
            collected[#collected + 1] = { tag = hit.tag, name = captured }
        end
        pos = gtPos + 1
    end

    for _, e in ipairs(collected) do
        if e.tag == "trinket" then
            trinketNames[#trinketNames + 1] = e.name
        else
            itemNames[#itemNames + 1] = { name = e.name, tag = e.tag }
        end
    end

    -- 2.b) Verifica lookup en ids.lua para collectibles.
    for _, e in ipairs(itemNames) do
        -- Buscamos literal GetItemIdByName("X") en ids.lua (string.find plano).
        local needle = 'GetItemIdByName("' .. e.name .. '")'
        local found = idsLua:find(needle, 1, true)
        check(found ~= nil,
              string.format("(b) items.xml tiene name=\"%s\" (<%s>) pero ids.lua no contiene %s",
                              e.name, e.tag, needle))
    end

    -- 3.b) Verifica lookup en ids.lua para trinkets.
    for _, nm in ipairs(trinketNames) do
        local needle = 'GetTrinketIdByName("' .. nm .. '")'
        local found = idsLua:find(needle, 1, true)
        check(found ~= nil,
              string.format("(b) items.xml tiene name=\"%s\" (<trinket>) pero ids.lua no contiene %s",
                              nm, needle))
    end
end

-- ===================== (c) itempools.xml -> items.xml =====================
local poolsXml = readFile("content/itempools.xml")
if not poolsXml then
    failures = failures + 1
    io.stderr:write("FAIL: (c) no se puede abrir content/itempools.xml\n")
elseif not itemsXml then
    -- Ya reportado arriba; nada que anadir aqui.
else
    -- 1.c) Construimos el set de `name="X"` validos en items.xml.
    local nameSet = {}
    for _, e in ipairs(itemNames)   do nameSet[e.name] = true end
    for _, nm in ipairs(trinketNames) do nameSet[nm]    = true end

    -- 2.c) Capturamos cada <Item Name="X"> en itempools.xml.
    --      CUIDADO: el atributo `Name=` aparece tambien en `<Pool Name="...">`,
    --      asi que buscamos `Name="X"` solo cuando esta dentro de un `<Item`
    --      (entre su apertura y su `>`). Eso replica literalmente la forma:
    --      <Item ... Name="X" ...>.
    local poolNames = {}
    local ppos = 1
    while true do
        -- Localiza el siguiente `<Item` (apertura de Item) y, dentro de ese
        -- tag hasta su `>`, el primer Name="X".
        local itemOpenStart = poolsXml:find("<Item ", ppos, true)
        if not itemOpenStart then break end
        local itemOpenEnd = poolsXml:find(">", itemOpenStart, true)
        if not itemOpenEnd then break end
        local tagText = poolsXml:sub(itemOpenStart, itemOpenEnd)
        local _, _, captured = tagText:find('Name%s*=%s*"([^"]+)"')
        if captured then
            poolNames[#poolNames + 1] = captured
        end
        ppos = itemOpenEnd + 1
    end

    -- 3.c) Cada poolName debe existir como name="X" en items.xml.
    for _, nm in ipairs(poolNames) do
        check(nameSet[nm] == true,
              string.format("(c) itempools.xml referencia Item Name=\"%s\" pero items.xml no tiene name=\"%s\"",
                              nm, nm))
    end
end

-- ===================== RESUMEN =====================
io.stderr:write(string.format("\n[test_item_names_consistency] passes=%d failures=%d\n",
                              passes, failures))
if failures > 0 then os.exit(1) else os.exit(0) end