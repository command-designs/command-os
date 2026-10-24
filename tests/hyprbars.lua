-- Command OS — comprueba la configuración de hyprbars de os/dotfiles/hypr/hyprland.lua (tests/hyprbars.sh).
-- `Hyprland --verify-config` no carga plugins, así que se salta el bloque `if hl.plugin.hyprbars`: aquí se
-- ejecuta la configuración con un `hl` de mentira que sí tiene el plugin y se mira lo que le pide.
--
-- Uso: lua tests/hyprbars.lua <hyprland.lua> <carpeta de los SVG de los botones> <clave registrada>...
-- Las claves son las que registra el plugin compilado (plugin:hyprbars:… y los efectos hyprbars:…).

local CONFIG, SVG = arg[1], arg[2]
local registradas = {}
for i = 3, #arg do registradas[(arg[i]:gsub(":", "."))] = true end

local fallos = 0
local function ok(...) print("  ok   " .. string.format(...)) end
local function mal(...)
    print("  MAL  " .. string.format(...))
    fallos = fallos + 1
end

-- Cualquier cosa de hl que no se mira aquí: se puede llamar y leer sin fin.
local function nada()
    return setmetatable({}, { __index = function() return nada() end, __call = function() return nada() end })
end

local valores, efectos, botones = {}, {}, {}
local function aplanar(t, prefijo)
    for k, v in pairs(t) do
        local nombre = prefijo .. "." .. k
        if type(v) == "table" then aplanar(v, nombre) else valores[nombre] = v end
    end
end

hl = nada()
rawset(hl, "config", function(t)
    if type(t) == "table" and type(t.plugin) == "table" and type(t.plugin.hyprbars) == "table" then
        aplanar(t.plugin.hyprbars, "plugin.hyprbars")
    end
end)
rawset(hl, "window_rule", function(t)
    for k, v in pairs(t) do
        if type(k) == "string" and k:find(":", 1, true) then efectos[k] = v end
    end
    return nada()
end)
-- Un puntero y una pantalla de 1920×1080 con la barra arriba, y las órdenes que se lanzan.
local lanzadas = {}
local PANTALLA = { x = 0, y = 0, width = 1920, height = 1080, scale = 1, reserved = { top = 36, bottom = 0, left = 0, right = 0 } }
rawset(hl, "get_cursor_pos", function() return { x = 100, y = 100 } end)
rawset(hl, "get_monitor_at_cursor", function() return PANTALLA end)

-- Una ventana activa con barra de título (33 px encima del contenido con el filo) y filo de 1 px, y los
-- despachadores que la mueven, la redimensionan, la etiquetan o le quitan el maximizado de Hyprland: el
-- resto no hace nada. Al llevarla al borde (direction), Hyprland deja el contenido a esa distancia del área libre.
local ventana
local function ventana_nueva()
    ventana = {
        address = "0x1", class = "kitty", title = "kitty", floating = true, fullscreen = 0, focus_history_id = 0,
        at = { x = 500, y = 300 }, size = { x = 800, y = 600 }, monitor = PANTALLA, workspace = { id = 1, name = "1" },
        tags = {},
    }
end
ventana_nueva()
rawset(hl, "get_active_window", function() return ventana end)
rawset(hl, "get_window", function(selector) return selector == "address:" .. ventana.address and ventana or nil end)
rawset(hl, "timer", function(f) f() return nada() end)
local function despachador(tipo)
    return function(t) return { despachar = tipo, args = t or {} } end
end
local dsp_ventana = setmetatable({
    move = despachador("move"), resize = despachador("resize"), tag = despachador("tag"),
    fullscreen = despachador("fullscreen"),
}, { __index = function() return nada() end })
rawset(hl, "dsp", setmetatable({ window = dsp_ventana }, { __index = function() return nada() end }))
rawset(hl, "dispatch", function(d)
    if type(d) ~= "table" or not rawget(d, "despachar") then return end
    local a = d.args
    if d.despachar == "move" and a.direction == "left" then
        ventana.at.x = PANTALLA.x + PANTALLA.reserved.left + 1
    elseif d.despachar == "move" and a.direction == "up" then
        ventana.at.y = PANTALLA.y + PANTALLA.reserved.top + 33
    elseif d.despachar == "move" and a.x and a.y then
        ventana.at = { x = a.x, y = a.y }
    elseif d.despachar == "resize" and a.x and a.y then
        ventana.size = { x = a.x, y = a.y }
    elseif d.despachar == "tag" then
        ventana.tags[a.tag:sub(2)] = a.tag:sub(1, 1) == "+" or nil
    elseif d.despachar == "fullscreen" and a.action == "unset" then
        ventana.fullscreen = 0
    end
end)
-- Los atajos de teclado con función (los de despachador no hacen falta aquí), los de cada submapa aparte.
local atajos, submapas, submapa = {}, {}, nil
rawset(hl, "bind", function(tecla, f)
    if type(f) == "function" then
        if submapa then submapas[submapa][tecla] = f else atajos[tecla] = f end
    end
    return nada()
end)
rawset(hl, "define_submap", function(nombre, f)
    submapas[nombre], submapa = {}, nombre
    f()
    submapa = nil
end)
rawset(hl, "exec_cmd", function(orden) lanzadas[#lanzadas + 1] = orden end)
-- Los manejadores de eventos (hl.on), para lanzarlos abajo.
local eventos = {}
rawset(hl, "on", function(nombre, f) eventos[nombre] = f end)
rawset(hl, "plugin", {
    load = function() end,
    hyprbars = { add_button = function(t) botones[#botones + 1] = t end },
})

-- Con rofi (aunque no esté instalado aquí) y la lista de Alt+Tab en una carpeta temporal.
local io_open, getenv = io.open, os.getenv
local TEMPORAL = getenv("TMPDIR") or "/tmp"
io.open = function(ruta, modo)
    if ruta == "/usr/bin/rofi" then return { close = function() end } end
    return io_open(ruta, modo)
end
os.getenv = function(nombre)
    if nombre == "XDG_RUNTIME_DIR" then return TEMPORAL end
    return getenv(nombre)
end

local cargada, err = pcall(dofile, CONFIG)
if not cargada then
    mal("%s no se ejecuta con hyprbars: %s", CONFIG, tostring(err))
    os.exit(1)
end

-- Opciones del plugin y efectos de las reglas: los que existen en el plugin compilado.
local n = 0
for nombre in pairs(valores) do
    n = n + 1
    if not registradas[nombre] then mal("hyprbars no tiene la opción %s", nombre) end
end
for nombre in pairs(efectos) do
    if not registradas[(nombre:gsub(":", "."))] then mal("hyprbars no tiene el efecto de regla %s", nombre) end
end
if n == 0 then mal("la configuración no da ninguna opción a hyprbars") else ok("hyprbars: %d opciones", n) end

-- Las órdenes de los botones, del doble clic y del clic derecho: command_os.boton con un botón que sabe
-- hacer, o command_os.menu con un menú que existe.
local SABE = { cerrar = true, maximizar = true, minimizar = true }
local MENUS = { ventana = true }
local function orden(texto, donde)
    local que, cual = (type(texto) == "string" and texto or ""):match([[^hyprctl eval "command_os%.(%w+)%('(%w+)'%)"$]])
    if not ((que == "boton" and SABE[cual]) or (que == "menu" and MENUS[cual])) then
        mal("%s: orden desconocida %q", donde, tostring(texto))
    end
end
for _, clave in ipairs({ "on_double_click", "on_right_click" }) do
    if valores["plugin.hyprbars." .. clave] then orden(valores["plugin.hyprbars." .. clave], clave)
    else mal("hyprbars: falta %s", clave) end
end

-- Los botones SVG del parche: solo sus campos, y que estén los tres dibujos de cada estado.
local CAMPOS = { svg = "string", svg_toggled = "string", width = "number", action = "string" }
local function dibujos(base, donde)
    local archivo = base:match("([^/]+)$")
    for _, sufijo in ipairs({ "-active.svg", "-inactive.svg", "_hover-active.svg" }) do
        local f = io.open(SVG .. "/" .. archivo .. sufijo, "r")
        if f then f:close() else mal("%s: falta %s%s", donde, archivo, sufijo) end
    end
end
for i, b in ipairs(botones) do
    local donde = "botón " .. i .. " (" .. tostring(b.svg) .. ")"
    for k, v in pairs(b) do
        if not CAMPOS[k] then mal("%s: campo desconocido %s", donde, tostring(k))
        elseif type(v) ~= CAMPOS[k] then mal("%s: %s debe ser %s", donde, k, CAMPOS[k]) end
    end
    if type(b.svg) ~= "string" or type(b.width) ~= "number" or b.width <= 0 or type(b.action) ~= "string" then
        mal("%s: le falta svg, width o action", donde)
    else
        dibujos(b.svg, donde)
        if b.svg_toggled then dibujos(b.svg_toggled, donde) end
        orden(b.action, donde)
    end
end
if #botones == 3 then ok("hyprbars: 3 botones con sus dibujos") else mal("hyprbars: %d botones (cerrar, maximizar y minimizar)", #botones) end

-- Lo que hacen los botones se ejecuta sin errores de Lua (los despachadores los valida tests/hyprbars.sh).
if type(command_os) ~= "table" or type(command_os.boton) ~= "function" then
    mal("no existe command_os.boton")
else
    local antes = fallos
    -- También los del menú de ventana (lib/menu-hyprland.py).
    for _, boton in ipairs({ "cerrar", "maximizar", "minimizar", "pantalla_completa", "fijar" }) do
        local hecho, e = pcall(command_os.boton, boton)
        if not hecho then mal("command_os.boton('%s'): %s", boton, tostring(e)) end
    end
    if fallos == antes then ok("command_os.boton: cerrar, maximizar, minimizar, pantalla completa y fijar") end
end

-- Lo demás que llaman desde fuera: los menús, «mover a escritorio» y el final de Alt+Tab. El menú se abre
-- en el puntero, contado desde lo que deja libre la barra.
for _, llamada in ipairs({ { "menu", "ventana" }, { "menu", "escritorio" }, { "enviar", 1 }, { "alttab_fin", -1 } }) do
    local f = type(command_os) == "table" and command_os[llamada[1]]
    local hecho, e = type(f) == "function" and pcall(f, llamada[2])
    if hecho then ok("command_os.%s(%s)", llamada[1], tostring(llamada[2]))
    else mal("command_os.%s(%s): %s", llamada[1], tostring(llamada[2]), tostring(e or "no existe")) end
end
local MENU = "/usr/lib/command-os/menu-hyprland.py ventana 100 64 1920 1044"
if lanzadas[1] == MENU then ok("menú de ventana: %s", MENU) else mal("menú de ventana: %s", tostring(lanzadas[1])) end

-- Al cerrar una ventana, Hyprland 0.56.2 la pasa ya destruida y sin `address`: el manejador no puede fallar
-- (el error de Lua sale arriba en la pantalla con cada ventana que se cierra).
if type(eventos["window.destroy"]) ~= "function" then
    mal("no hay manejador de window.destroy")
else
    local antes = fallos
    for _, w in ipairs({ { address = "0x1" }, {}, false }) do
        local hecho, e = pcall(eventos["window.destroy"], w or nil)
        if not hecho then mal("window.destroy con %s: %s", w and (w.address or "ventana sin address") or "nil", tostring(e)) end
    end
    if fallos == antes then ok("window.destroy: con address, sin address y sin ventana") end
end

-- Maximizar y media pantalla son geometría (no el maximizado de Hyprland, que quitaría el de otra ventana al
-- cambiar con Alt+Tab): área libre 1920×1044 desde y = 36; el contenido, dentro del filo y bajo la barra.
local function geometria(donde, x, y, an, al, maximizada)
    local v = ventana
    if v.at.x == x and v.at.y == y and v.size.x == an and v.size.y == al and (v.tags.maximizada == true) == maximizada then
        ok("%s: %d,%d %d×%d%s", donde, x, y, an, al, maximizada and " (maximizada)" or "")
    else
        mal("%s: %d,%d %d×%d %s; tenía que ser %d,%d %d×%d %s", donde, v.at.x, v.at.y, v.size.x, v.size.y,
            tostring(v.tags.maximizada == true), x, y, an, al, tostring(maximizada))
    end
end
local function pulsar(tecla)
    if atajos[tecla] then atajos[tecla]() else mal("no hay atajo %s", tecla) end
end

ventana_nueva()
pulsar("SUPER + left")
geometria("Super+Izquierda", 1, 69, 958, 1010, false)
pulsar("SUPER + right")
geometria("Super+Derecha", 961, 69, 958, 1010, false)
pulsar("SUPER + up")
geometria("Super+Arriba", 1, 69, 1918, 1010, true)
pulsar("SUPER + up")
geometria("Super+Arriba otra vez (donde estaba antes de encajarla)", 500, 300, 800, 600, false)
pulsar("SUPER + left")
pulsar("SUPER + down")
geometria("Super+Izquierda y Super+Abajo", 500, 300, 800, 600, false)
if type(command_os) == "table" and type(command_os.boton) == "function" then
    command_os.boton("maximizar")
    geometria("botón de maximizar", 1, 69, 1918, 1010, true)
    command_os.boton("maximizar")
    geometria("botón de maximizar otra vez", 500, 300, 800, 600, false)
end

-- Lo que pide una app (su botón de maximizar) llega como el maximizado de Hyprland: se cambia por el nuestro
-- y, si ya lo estaba, la devuelve.
if type(eventos["window.fullscreen"]) ~= "function" then
    mal("no hay manejador de window.fullscreen")
else
    ventana_nueva()
    ventana.fullscreen = 1
    eventos["window.fullscreen"](ventana)
    geometria("maximizar pedido por la app", 1, 69, 1918, 1010, true)
    if ventana.fullscreen ~= 0 then mal("maximizar pedido por la app: sigue con el maximizado de Hyprland") end
    ventana.fullscreen = 1
    eventos["window.fullscreen"](ventana)
    geometria("maximizar pedido por la app otra vez", 500, 300, 800, 600, false)
end

-- Alt+Tab con tres ventanas: la primera pulsación pasa a la anterior; con Alt pulsado sale la lista (rofi),
-- Tab mueve la marca y, al soltar Alt, Hyprland activa la marcada y cierra rofi.
do
    local ventanas = {}
    for i = 1, 3 do
        ventanas[i] = { address = "0x" .. i, class = "app" .. i, title = "app " .. i, focus_history_id = i - 1,
            workspace = { id = 1, name = "1" } }
    end
    local temporizadores, alt, activa = {}, true, nil
    local function correr_temporizadores()
        local ahora = temporizadores
        temporizadores = {}
        for _, f in ipairs(ahora) do f() end
    end
    rawset(hl, "timer", function(f) temporizadores[#temporizadores + 1] = f return nada() end)
    rawset(hl, "is_key_down", function(tecla) return alt and tecla == "Alt_L" end)
    rawset(hl, "get_windows", function() return ventanas end)
    rawset(hl, "get_active_workspace", function() return { id = 1, name = "1" } end)
    rawset(hl, "get_window", function(selector)
        for _, v in ipairs(ventanas) do
            if selector == "address:" .. v.address then return v end
        end
    end)
    rawset(hl.dsp, "focus", function(t) return { despachar = "focus", args = t } end)
    rawset(hl, "dispatch", function(d)
        if type(d) == "table" and rawget(d, "despachar") == "focus" then activa = d.args.window.address end
    end)
    lanzadas = {}

    pulsar("ALT + Tab")
    if activa == "0x2" then ok("Alt+Tab: pasa al momento a la anterior") else mal("Alt+Tab: activa %s", tostring(activa)) end
    correr_temporizadores() -- 150 ms con Alt pulsado: sale la lista
    local rofi = lanzadas[#lanzadas] or ""
    if rofi:find("rofi -dmenu", 1, true) and rofi:find("-selected-row 1", 1, true) then
        ok("Alt+Tab: lista de rofi con la anterior marcada")
    else
        mal("Alt+Tab: no sale la lista (%s)", rofi)
    end
    -- Con la lista abierta, Alt+Tab llega a rofi y al submapa (non_consuming), que lleva la cuenta.
    local tab = submapas.alttab and submapas.alttab["ALT + Tab"]
    if not tab then
        mal("Alt+Tab: el submapa alttab no tiene ALT + Tab")
    else
        tab()
        alt = false
        correr_temporizadores() -- soltar Alt
        local cierra = lanzadas[#lanzadas] or ""
        if activa == "0x3" then ok("Alt+Tab: al soltar Alt activa la marcada") else mal("Alt+Tab: al soltar Alt activa %s", tostring(activa)) end
        if cierra:find("pkill", 1, true) and cierra:find("command-os-alttab", 1, true) then
            ok("Alt+Tab: al soltar Alt se cierra rofi")
        else
            mal("Alt+Tab: rofi no se cierra (%s)", cierra)
        end
    end
end

os.exit(fallos == 0 and 0 or 1)
