-- Command OS — sesión de Hyprland de prueba (ROADMAP.md, punto 7; docs/notas/escritorio.md § «Sesión
-- Hyprland de prueba»). Se ve y se usa como labwc (os/dotfiles/labwc/rc.xml): solo cambian las
-- animaciones. Es la configuración de serie (/etc/xdg/hypr/hyprland.lua); command-os-session la pasa con
-- --config y, al final, carga lo que el usuario añada en ~/.config/hypr/hyprland.lua. Validar cada
-- cambio con `Hyprland --verify-config --config os/dotfiles/hypr/hyprland.lua` (tests/escritorio.sh).
-- API de la 0.56.2: /usr/share/hypr/stubs/hl.meta.lua (la wiki va por delante de la versión de Arch).
-- Super+F1 (command-os-keys) enseña los atajos: los de aquí son los mismos que los de labwc.

local CONFIG = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")

-- Lee un archivo de «clave=valor» (los ajustes de Command OS) en una tabla.
local function ajustes(ruta)
    local valores = {}
    local f = io.open(ruta, "r")
    if f then
        for linea in f:lines() do
            local clave, valor = linea:match("^%s*([%w_]+)%s*=%s*(%S+)%s*$")
            if clave then valores[clave] = valor end
        end
        f:close()
    end
    return valores
end

-- La barra (Ajustes → Barra, lib/fijadas.py): su lado y lo que reserva en ese borde. Waybar reserva su
-- grosor y, flotante, también sus dos márgenes. command-os-fijadas recarga esto al cambiarla.
local barra = ajustes(CONFIG .. "/command-os/barra")
local LADO = barra.lado or "arriba"
local GROSOR = 36 + (barra.flotante == "si" and 2 * 8 or 0)
local reserva = { arriba = 0, abajo = 0, izquierda = 0, derecha = 0 }
reserva[LADO] = reserva[LADO] and GROSOR or 0

------------------
---- PANTALLA ----
------------------

-- La escala la pone command-os-pantallas (autostart) en cada pantalla, como en labwc.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Las variables de la sesión de labwc (os/dotfiles/labwc/environment); el teclado lo exporta
-- lib/entorno-grafico desde /etc/command-os/kb_layout.
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- Con el driver de NVIDIA (variante pc-nvidia), lo que pide Hyprland para el vídeo por hardware y GLX.
local nvidia = io.open("/proc/driver/nvidia/version", "r")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
end

-- Lo mismo que arranca labwc (barra, fondo, notificaciones, reposo…): un solo archivo para las dos.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh /etc/xdg/labwc/autostart")
end)

-------------------
---- ASPECTO ----
-------------------

-- Como el tema de labwc (themerc): filo de 1 px Red Hot en la activa y Steel en las demás, sin
-- redondeo, sombra corta y oscura, sin huecos, sin desenfoque (ligereza) y sin halos (BRAND 2.1 § 7.2).
hl.config({
    general = {
        border_size = 1,
        gaps_in = 0,
        gaps_out = 0,
        col = {
            active_border = "rgba(f5482cff)",
            inactive_border = "rgba(2a2a2aff)",
        },
        -- Redimensionar por los bordes, como en labwc, con un margen para agarrarlos.
        resize_on_border = true,
        extend_border_grab_area = 10,
        hover_icon_on_border = true,
        -- Pegar las ventanas a los bordes y entre ellas al arrastrarlas (labwc: <snapping><range>).
        snap = { enabled = true, window_gap = 10, monitor_gap = 10 },
    },
    decoration = {
        rounding = 0,
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = "rgba(00000099)",
            color_inactive = "rgba(00000070)",
        },
        blur = { enabled = false },
        glow = { enabled = false },
    },
    input = {
        kb_layout = os.getenv("XKB_DEFAULT_LAYOUT") or "us",
        numlock_by_default = true,
        repeat_rate = 30,
        repeat_delay = 400,
        -- El foco va con el clic, no con el ratón (labwc: followMouse no); la rueda, a la de debajo.
        follow_mouse = 2,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
        },
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = "rgba(0e0e0eff)",
        -- La barra de tareas (y cualquier app) puede traer una ventana al frente.
        focus_on_activate = true,
        -- Sin start-hyprland (otro proceso residente): si Hyprland falla al empezar, command-os-session
        -- abre labwc.
        disable_watchdog_warning = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

--------------------
---- ANIMACIONES ----
--------------------

-- Lo único que cambia frente a labwc. Las curvas y las duraciones de la marca (docs/DISENO.md
-- § «Movimiento»): 160 ms para los cambios de estado y lo que sale, 280 ms para lo que entra. Hyprland
-- mide en décimas de segundo. Solo al abrir, cerrar, mover o cambiar de escritorio: nada en bucle.
local RAPIDA, BASE = 1.6, 2.8
hl.curve("ease-out", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("ease-in-out", { type = "bezier", points = { { 0.65, 0 }, { 0.35, 1 } } })
hl.curve("ease-snap", { type = "bezier", points = { { 0.2, 0.9 }, { 0.1, 1.25 } } })

hl.animation({ leaf = "global", enabled = true, speed = BASE, bezier = "ease-out" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = BASE, bezier = "ease-out", style = "popin 96%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = RAPIDA, bezier = "ease-in-out", style = "popin 96%" })
-- Maximizar, encajar o centrar: llega con el pequeño exceso de --ease-snap.
hl.animation({ leaf = "windowsMove", enabled = true, speed = BASE, bezier = "ease-snap" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = BASE, bezier = "ease-out" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = RAPIDA, bezier = "ease-in-out" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = RAPIDA, bezier = "ease-out" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = RAPIDA, bezier = "ease-out" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = RAPIDA, bezier = "ease-out" })
hl.animation({ leaf = "fadePopups", enabled = true, speed = RAPIDA, bezier = "ease-out" })
hl.animation({ leaf = "fadeDpms", enabled = true, speed = RAPIDA, bezier = "ease-out" })
hl.animation({ leaf = "border", enabled = true, speed = RAPIDA, bezier = "ease-out" })
hl.animation({ leaf = "workspaces", enabled = true, speed = BASE, bezier = "ease-out", style = "slidefade 8%" })
-- La barra, el lanzador y las notificaciones ya entran con su propia animación (su CSS): sin otra encima.
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "fadeLayers", enabled = false })
-- Las minimizadas (un escritorio especial) no se ven nunca al restaurarlas.
hl.animation({ leaf = "specialWorkspace", enabled = false })
-- Los giros de los degradados redibujan sin parar si van en bucle: fuera.
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "shadowangle", enabled = false })
hl.animation({ leaf = "glowangle", enabled = false })
hl.animation({ leaf = "zoomFactor", enabled = false })
hl.animation({ leaf = "monitorAdded", enabled = false })

----------------
---- REGLAS ----
----------------

-- Todas las ventanas flotan, como en labwc; Hyprland las abre centradas.
hl.window_rule({ name = "flotantes", match = { class = ".*" }, float = true })

-- Una posición en la pantalla, en el texto de las reglas de Hyprland (sin espacios dentro de cada valor).
local function sitio(x, y) return { (x:gsub(" ", "")), (y:gsub(" ", "")) } end
local derecha = string.format("monitor_w - window_w - %d", reserva.derecha)
local abajo = string.format("monitor_h - window_h - %d", reserva.abajo)

-- Centro de control (lib/centro.py): sin filo ni sombra (el panel con chaflán lo pinta GTK sobre una
-- ventana transparente) y sin animación de Hyprland (entra con la suya). Cuelga junto al grupo de estado,
-- al final de la barra: su id cambia con el lado (arriba, abajo o a la derecha, y a la izquierda). Fijado
-- (encima de todo, como AlwaysOnTop) y fuera de la barra de tareas (su ignore-list).
local centro = { border_size = 0, no_shadow = true, no_anim = true, pin = true }
local function panel(id, x, y)
    hl.window_rule({
        name = id,
        match = { class = "^" .. id:gsub("%.", "\\.") .. "$" },
        border_size = centro.border_size, no_shadow = centro.no_shadow, no_anim = centro.no_anim,
        pin = centro.pin, move = sitio(x, y),
    })
end
panel("dev.commandlab.Centro", derecha, tostring(reserva.arriba))
panel("dev.commandlab.CentroAbajo", derecha, abajo)
panel("dev.commandlab.CentroIzquierda", tostring(reserva.izquierda), abajo)

-- Mezclador (vol en la barra) y dispositivos Bluetooth (bt): desplegables fijos arriba a la derecha,
-- solo con el filo, como en labwc (docs/decisiones.md: siguen ahí con la barra en otro lado).
for clase, tam in pairs({ ["org.pulseaudio.pavucontrol"] = { 460, 340 }, ["blueman-manager"] = { 520, 400 } }) do
    hl.window_rule({
        name = clase,
        match = { class = "^" .. clase:gsub("%.", "\\.") .. "$" },
        size = tam,
        move = sitio(derecha, tostring(reserva.arriba)),
        pin = true,
    })
end

-- Monitor del sistema (Ctrl+Mayús+Esc).
hl.window_rule({ name = "btop", match = { class = "^btop$" }, size = { 960, 600 }, center = true })

-- Vídeo flotante de Firefox: encima de todo.
hl.window_rule({ name = "pip", match = { title = "^(Picture-in-Picture|Imagen en imagen)$" }, pin = true })

------------------------------------
---- VENTANAS: MINIMIZAR, ENCAJAR ----
------------------------------------

-- Hyprland no minimiza: las minimizadas van a un escritorio especial que no se enseña. Cuando una de ellas
-- se activa (la barra de tareas, Alt+Tab), vuelve al escritorio de la pantalla. La 0.56 no avisa a Lua de
-- que una app pide minimizarse (el evento window.minimize llega después): el botón de minimizar de las
-- cabeceras GTK y el clic en la ventana activa de la barra de tareas no hacen nada todavía.
local MINIMIZADAS = "special:minimizadas"

local function minimizar(w)
    hl.dispatch(hl.dsp.window.move({ window = w, workspace = MINIMIZADAS, follow = false }))
end

hl.on("window.active", function(w)
    if w and w.workspace and w.workspace.name == MINIMIZADAS then
        local ws = hl.get_active_workspace()
        if ws then
            hl.dispatch(hl.dsp.window.move({ window = w, workspace = ws.id, follow = true }))
            hl.dispatch(hl.dsp.focus({ window = w }))
        end
    end
end)

-- Una tabla de Hyprland con dos valores (posición o tamaño): {x =, y =} o {1, 2}.
local function par(t)
    if type(t) ~= "table" then return 0, 0 end
    return t.x or t[1] or 0, t.y or t[2] or 0
end

-- El área de la pantalla que no ocupa la barra, en coordenadas de Hyprland: el tamaño viene en píxeles
-- (se divide por la escala) y lo reservado, lo que pide Waybar de verdad.
local function area(m)
    local escala = (m.scale and m.scale > 0) and m.scale or 1
    local r = m.reserved or {}
    local arriba, derecha = r.top or reserva.arriba, r.right or reserva.derecha
    local abajo, izquierda = r.bottom or reserva.abajo, r.left or reserva.izquierda
    return m.x + izquierda, m.y + arriba,
        m.width / escala - izquierda - derecha, m.height / escala - arriba - abajo
end

-- Media pantalla (Super+Izquierda/Derecha, como SnapToEdge de labwc); Super+Abajo la devuelve a su sitio.
local antes = {}
local function encajar(lado)
    local w = hl.get_active_window()
    local m = w and (w.monitor or hl.get_active_monitor())
    if not m then return end
    if not antes[w.address] then
        local x, y = par(w.at)
        local an, al = par(w.size)
        antes[w.address] = { x = x, y = y, an = an, al = al }
    end
    local x, y, an, al = area(m)
    if lado == "derecha" then x = x + an / 2 end
    if w.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "maximized", action = "unset" }))
    end
    hl.dispatch(hl.dsp.window.resize({ window = w, x = math.floor(an / 2), y = math.floor(al) }))
    hl.dispatch(hl.dsp.window.move({ window = w, x = math.floor(x), y = math.floor(y) }))
end

-- Super+Abajo: maximizada o encajada vuelve a su tamaño; si no, se minimiza (como en labwc).
local function abajo_o_minimizar()
    local w = hl.get_active_window()
    if not w then return end
    local previo = antes[w.address]
    if w.fullscreen == 1 then
        hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "maximized", action = "unset" }))
    elseif previo then
        antes[w.address] = nil
        hl.dispatch(hl.dsp.window.resize({ window = w, x = previo.an, y = previo.al }))
        hl.dispatch(hl.dsp.window.move({ window = w, x = previo.x, y = previo.y }))
    else
        minimizar(w)
    end
end

hl.on("window.destroy", function(w)
    if w then antes[w.address] = nil end
end)

-- Super+D: minimiza las ventanas del escritorio y, la segunda vez, las devuelve.
local escondidas = nil
local function ver_escritorio()
    if escondidas then
        local ws = hl.get_active_workspace()
        for _, direccion in ipairs(escondidas) do
            local w = hl.get_window("address:" .. direccion)
            if w and ws and w.workspace and w.workspace.name == MINIMIZADAS then
                hl.dispatch(hl.dsp.window.move({ window = w, workspace = ws.id, follow = false }))
            end
        end
        escondidas = nil
        return
    end
    local ws = hl.get_active_workspace()
    if not ws then return end
    escondidas = {}
    for _, w in ipairs(hl.get_workspace_windows(ws.id)) do
        if not w.pinned then
            table.insert(escondidas, w.address)
            minimizar(w)
        end
    end
end

-- El centro de control se cierra al perder el foco; en labwc, un clic en el fondo se lo quita (Unfocus).
-- Hyprland no quita el foco al pulsar el fondo: un clic fuera del panel y fuera de la barra lo cierra.
local function en_barra(c, m)
    local x, y, an, al = area(m)
    return c.x < x or c.y < y or c.x >= x + an or c.y >= y + al
end

local function clic_fuera_del_centro()
    local w = hl.get_active_window()
    if not (w and w.class and w.class:match("^dev%.commandlab%.Centro")) then return end
    local c = hl.get_cursor_pos()
    local m = hl.get_monitor_at_cursor()
    if not (c and m) then return end
    local x, y = par(w.at)
    local an, al = par(w.size)
    local dentro = c.x >= x and c.x < x + an and c.y >= y and c.y < y + al
    if not dentro and not en_barra(c, m) then
        hl.dispatch(hl.dsp.window.close({ window = w }))
    end
end

---------------------
---- ESCRITORIOS ----
---------------------

-- Como en labwc (command-os-desktops): de serie uno y, con dos o más, sus números en la barra. Cuántos hay
-- lo guarda command-os-desktops en ~/.config/command-os/escritorios; aquí se crean fijos («01», «02»…) para
-- que la barra (ext/workspaces) los enseñe aunque estén vacíos.
local MAX = 4
local escritorios = { n = 1, reglas = {} }
do
    local f = io.open(CONFIG .. "/command-os/escritorios", "r")
    local n = f and tonumber(f:read("l") or "")
    if f then f:close() end
    if n then escritorios.n = math.max(1, math.min(MAX, math.floor(n))) end
end

local function regla_escritorio(i)
    return hl.workspace_rule({ workspace = tostring(i), persistent = true, default_name = string.format("%02d", i) })
end
for i = 1, escritorios.n do escritorios.reglas[i] = regla_escritorio(i) end

-- Lo llama command-os-desktops (hyprctl eval) con el número nuevo: crea los que faltan y va al último, o
-- quita los que sobran y pasa sus ventanas al 01.
command_os = {}
function command_os.escritorios(n)
    n = math.max(1, math.min(MAX, math.floor(tonumber(n) or 1)))
    local crece = n > escritorios.n
    for i = escritorios.n + 1, n do escritorios.reglas[i] = regla_escritorio(i) end
    for i = escritorios.n, n + 1, -1 do
        for _, w in ipairs(hl.get_workspace_windows(i)) do
            hl.dispatch(hl.dsp.window.move({ window = w, workspace = 1, follow = false }))
        end
        if escritorios.reglas[i] then escritorios.reglas[i]:set_enabled(false) end
        escritorios.reglas[i] = nil
    end
    local activo = hl.get_active_workspace()
    escritorios.n = n
    if crece then
        hl.dispatch(hl.dsp.focus({ workspace = n }))
    elseif activo and not activo.special and activo.id > n then
        hl.dispatch(hl.dsp.focus({ workspace = 1 }))
    end
end

local function ir_a(i)
    if i <= escritorios.n then hl.dispatch(hl.dsp.focus({ workspace = i })) end
end

local function llevar_a(i)
    if i <= escritorios.n then hl.dispatch(hl.dsp.window.move({ workspace = i, follow = true })) end
end

-- El siguiente o el anterior, dando la vuelta (labwc: GoToDesktop right|left wrap).
local function vecino(paso)
    local ws = hl.get_active_workspace()
    local id = (ws and not ws.special and ws.id) or 1
    ir_a((id - 1 + paso) % escritorios.n + 1)
end

----------------
---- ATAJOS ----
----------------

-- Los de os/dotfiles/labwc/rc.xml, uno a uno, y los de serie de labwc que Command OS usa (Alt+Tab, Alt+F4,
-- Super+A, Super+Izquierda/Derecha, Super+arrastrar).

-- Aplicaciones. Super solo abre el lanzador (y lo cierra si ya está abierto).
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("command-os-launcher"), { release = true })
hl.bind("SUPER + space", hl.dsp.exec_cmd("command-os-launcher"))
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("command-os-clipboard"))
hl.bind("SUPER + F1", hl.dsp.exec_cmd("command-os-keys"))
hl.bind("SUPER + F2", hl.dsp.exec_cmd("command-os-about"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class btop -e btop"))

-- Ventanas.
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + up", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + A", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + down", abajo_o_minimizar)
hl.bind("SUPER + left", function() encajar("izquierda") end)
hl.bind("SUPER + right", function() encajar("derecha") end)
hl.bind("SUPER + D", ver_escritorio)
-- Siempre encima: Hyprland solo lo tiene fijando la ventana (que además sale en todos los escritorios).
hl.bind("SUPER + T", hl.dsp.window.pin())
-- Alt+Tab sin lista, de momento: pasa a la siguiente ventana y la trae al frente.
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)
hl.bind("ALT + SHIFT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Escritorios: Super+Ctrl+D crea uno y Super+Ctrl+F4 quita el último (como en Windows); Super+1…4 cambia,
-- Super+Mayús+1…4 lleva la ventana.
hl.bind("CTRL + SUPER + D", hl.dsp.exec_cmd("command-os-desktops nuevo"))
hl.bind("CTRL + SUPER + F4", hl.dsp.exec_cmd("command-os-desktops quitar"))
for i = 1, MAX do
    hl.bind("SUPER + " .. i, function() ir_a(i) end)
    hl.bind("SUPER + SHIFT + " .. i, function() llevar_a(i) end)
end
hl.bind("SUPER + Tab", function() vecino(1) end)
hl.bind("SUPER + SHIFT + Tab", function() vecino(-1) end)
hl.bind("CTRL + SUPER + right", function() vecino(1) end)
hl.bind("CTRL + SUPER + left", function() vecino(-1) end)

-- Sistema.
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("command-os-power"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("swaync-client --close-all"))
-- Salida de emergencia: cierra Hyprland y greetd vuelve a la pantalla de inicio de sesión.
hl.bind("SUPER + SHIFT + M", hl.dsp.exit())
hl.bind("Print", hl.dsp.exec_cmd("command-os-captura zona"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("command-os-captura zona"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("command-os-captura pantalla"))

-- Teclas multimedia, con OSD. Funcionan también con la sesión bloqueada.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise && command-os-sound tick"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower && command-os-sound tick"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Ratón: Super+arrastrar mueve y Super+clic derecho redimensiona (los de serie de labwc). El clic izquierdo
-- en cualquier sitio sigue llegando a las ventanas (non_consuming): solo mira si cierra el centro.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("mouse:272", clic_fuera_del_centro, { non_consuming = true })

-------------------------
---- LO DEL USUARIO ----
-------------------------

-- Lo que el usuario añada o cambie va en ~/.config/hypr/hyprland.lua, que se carga encima de esto. Si
-- tiene un error, se avisa y se sigue con lo de serie.
do
    local propio = CONFIG .. "/hypr/hyprland.lua"
    local f = io.open(propio, "r")
    if f then
        f:close()
        local ok, err = pcall(dofile, propio)
        if not ok then
            hl.notification.create({ text = "~/.config/hypr/hyprland.lua: " .. tostring(err), timeout = 15000 })
        end
    end
end
