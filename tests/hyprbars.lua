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
rawset(hl, "get_cursor_pos", function() return { x = 100, y = 100 } end)
rawset(hl, "get_monitor_at_cursor", function()
    return { x = 0, y = 0, width = 1920, height = 1080, scale = 1, reserved = { top = 36, bottom = 0, left = 0, right = 0 } }
end)
rawset(hl, "exec_cmd", function(orden) lanzadas[#lanzadas + 1] = orden end)
rawset(hl, "plugin", {
    load = function() end,
    hyprbars = { add_button = function(t) botones[#botones + 1] = t end },
})

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

os.exit(fallos == 0 and 0 or 1)
