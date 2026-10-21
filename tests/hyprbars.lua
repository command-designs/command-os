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

-- Las órdenes de los botones y del doble clic: command_os.boton con un botón que sabe hacer.
local SABE = { cerrar = true, maximizar = true, minimizar = true }
local function orden(texto, donde)
    local boton = type(texto) == "string" and texto:match([[^hyprctl eval "command_os%.boton%('(%w+)'%)"$]])
    if not (boton and SABE[boton]) then mal("%s: orden desconocida %q", donde, tostring(texto)) end
end
if valores["plugin.hyprbars.on_double_click"] then orden(valores["plugin.hyprbars.on_double_click"], "on_double_click") end

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
    for boton in pairs(SABE) do
        local hecho, e = pcall(command_os.boton, boton)
        if not hecho then mal("command_os.boton('%s'): %s", boton, tostring(e)) end
    end
    if fallos == antes then ok("command_os.boton: cerrar, maximizar y minimizar") end
end

os.exit(fallos == 0 and 0 or 1)
