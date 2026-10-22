-- Command OS — sesión de Hyprland de prueba (ROADMAP.md, punto 7; docs/notas/escritorio.md § «Sesión
-- Hyprland de prueba»). Se ve y se usa como labwc (os/dotfiles/labwc/rc.xml): solo cambian las
-- animaciones. Es la configuración de serie (/etc/xdg/hypr/hyprland.lua); command-os-session la pasa con
-- --config y, al final, carga lo que el usuario añada en ~/.config/hypr/hyprland.lua. Validar cada
-- cambio con `Hyprland --verify-config --config os/dotfiles/hypr/hyprland.lua` (tests/escritorio.sh).
-- API de la 0.56.2: /usr/share/hypr/stubs/hl.meta.lua (la wiki va por delante de la versión de Arch).
-- Super+F1 (command-os-keys) enseña los atajos: los de aquí son los mismos que los de labwc.

local CONFIG = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")

-- Lo que llaman desde fuera con `hyprctl eval`: command-os-desktops, los botones de la barra de título, los
-- menús (lib/menu-hyprland.py) y la lista de Alt+Tab.
command_os = {}

local function existe(ruta)
    local f = io.open(ruta, "r")
    if f then f:close() end
    return f ~= nil
end

-- Barras de título: hyprbars con el parche de Command OS (os/hyprbars, paquete command-os-hyprbars). Hyprland
-- lo carga al acabar de leer esto y vuelve a leerlo: la segunda vez ya existe hl.plugin.hyprbars (BARRAS).
-- Sin el paquete, las apps sin cabecera propia van sin barra, pero todo lo demás funciona.
local HYPRBARS = "/usr/lib/command-os/hyprbars.so"
if existe(HYPRBARS) then hl.plugin.load(HYPRBARS) end

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

----------------------------
---- BARRAS DE TÍTULO ----
----------------------------

-- Como las de labwc (themerc y rc.xml): 32 px, Graphite con la ventana activa y Void sin ella, el título a la
-- izquierda en mono (negrita activa, Bone; normal inactiva, Smoke) y los botones de 36×32 de
-- build/make-labwc-buttons.py, los mismos SVG que labwc y las cabeceras GTK. Solo las llevan las apps que
-- piden decoración al compositor (el parche lo mira), como en labwc: las de cabecera propia no.
-- Doble clic en el título: maximizar.
if hl.plugin.hyprbars then
    local BOTONES = "/usr/share/command-os/botones/"
    local function accion(nombre)
        return string.format([[hyprctl eval "command_os.boton('%s')"]], nombre)
    end

    hl.config({
        plugin = {
            hyprbars = {
                bar_height = 32,
                bar_color = "rgba(151515ff)",
                inactive_bar_color = "rgba(0e0e0eff)",
                col = { text = "rgba(edebe6ff)", inactive_text = "rgba(85827cff)" },
                bar_text_font = "JetBrainsMono Nerd Font",
                bar_text_size = 10,
                bar_text_weight = "bold",
                bar_text_weight_inactive = "normal",
                bar_text_align = "left",
                -- window.titlebar.padding.width y window.button.spacing de themerc.
                bar_padding = 4,
                bar_button_padding = 0,
                -- El filo rodea también la barra, como en labwc.
                bar_precedence_over_border = true,
                on_double_click = accion("maximizar"),
                -- Clic derecho en la barra: el menú de ventana (el plugin le da antes el foco).
                on_right_click = [[hyprctl eval "command_os.menu('ventana')"]],
            },
        },
    })

    -- De derecha a izquierda (<layout> de rc.xml al revés): cerrar, maximizar y minimizar.
    hl.plugin.hyprbars.add_button({ svg = BOTONES .. "close", width = 36, action = accion("cerrar") })
    hl.plugin.hyprbars.add_button({
        svg = BOTONES .. "max", svg_toggled = BOTONES .. "max_toggled", width = 36, action = accion("maximizar"),
    })
    hl.plugin.hyprbars.add_button({ svg = BOTONES .. "iconify", width = 36, action = accion("minimizar") })

    -- Sin barra, como en labwc: el centro de control (SetDecorations none) y los desplegables del mezclador
    -- y de blueman (solo el filo).
    hl.window_rule({
        name = "sin-barra",
        match = { class = "^(dev\\.commandlab\\.Centro.*|org\\.pulseaudio\\.pavucontrol|blueman-manager)$" },
        ["hyprbars:no_bar"] = true,
    })
end

------------------------------------
---- VENTANAS: MINIMIZAR, ENCAJAR ----
------------------------------------

-- Hyprland no minimiza: las minimizadas van a un escritorio especial que no se enseña. Cuando una de ellas
-- se activa (la barra de tareas, Alt+Tab), vuelve al escritorio de la pantalla. La 0.56 no avisa a Lua de
-- que una app pide minimizarse (el evento window.minimize llega después): el botón de minimizar de las
-- cabeceras GTK y el clic en la ventana activa de la barra de tareas no hacen nada todavía; el de la barra
-- de título de hyprbars, sí (command_os.boton).
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
-- Al soltarla en el borde, `previo` es dónde estaba antes de arrastrarla.
local antes = {}
local function encajar(lado, previo)
    local w = hl.get_active_window()
    local m = w and (w.monitor or hl.get_active_monitor())
    if not m then return end
    if not antes[w.address] then
        local x, y = par(w.at)
        local an, al = par(w.size)
        antes[w.address] = previo or { x = x, y = y, an = an, al = al }
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

-- Los botones de la barra de título (hyprbars) y el menú de ventana: cerrar, maximizar o devolver,
-- minimizar, pantalla completa y fijar (siempre encima y en todos los escritorios: Hyprland lo junta). El
-- plugin da el foco a la ventana del botón antes de lanzar la orden.
function command_os.boton(nombre)
    local w = hl.get_active_window()
    if not w then return end
    if nombre == "cerrar" then
        hl.dispatch(hl.dsp.window.close({ window = w }))
    elseif nombre == "maximizar" then
        hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "maximized", action = "toggle" }))
    elseif nombre == "minimizar" then
        minimizar(w)
    elseif nombre == "pantalla_completa" then
        hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "fullscreen", action = "toggle" }))
    elseif nombre == "fijar" then
        hl.dispatch(hl.dsp.window.pin({ window = w }))
    end
end

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

-- Encajar al soltar en el borde (labwc: <snapping>): la ventana que se arrastra (por la barra de título o con
-- Super) y se suelta con el puntero en el borde izquierdo o derecho de la pantalla ocupa esa mitad; en el de
-- arriba, se maximiza. Al pulsar se apunta dónde está cada ventana; al soltar, si la activa se ha movido sin
-- cambiar de tamaño (no es redimensionar por el filo) y el puntero toca el borde, encaja. Sin el aviso de
-- labwc antes de soltar. Va un momento después: el arrastre acaba tras los atajos y la dejaría donde se soltó.
local BORDE = 2
local pulsado, encaje = nil, nil

local function al_pulsar()
    clic_fuera_del_centro()
    pulsado = {}
    for _, w in ipairs(hl.get_windows()) do
        local x, y = par(w.at)
        local an, al = par(w.size)
        pulsado[w.address] = { x = x, y = y, an = an, al = al }
    end
end

local function al_soltar()
    local w, c, m = hl.get_active_window(), hl.get_cursor_pos(), hl.get_monitor_at_cursor()
    local previo = w and pulsado and pulsado[w.address]
    pulsado = nil
    if not (previo and c and m and w.floating and w.fullscreen == 0) then return end
    local x, y = par(w.at)
    local an, al = par(w.size)
    if (x == previo.x and y == previo.y) or an ~= previo.an or al ~= previo.al then return end
    local escala = (m.scale and m.scale > 0) and m.scale or 1
    local lado
    if c.x <= m.x + BORDE then
        lado = "izquierda"
    elseif c.x >= m.x + m.width / escala - 1 - BORDE then
        lado = "derecha"
    elseif c.y <= m.y + BORDE then
        lado = "arriba"
    end
    if not lado then return end
    encaje = hl.timer(function()
        encaje = nil
        if lado == "arriba" then
            hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "maximized", action = "set" }))
        else
            encajar(lado, previo)
        end
    end, { timeout = 20, type = "oneshot" })
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

-- «mover a escritorio» del menú de ventana: la lleva sin ir con ella (labwc: SendToDesktop follow="no").
function command_os.enviar(i)
    i = math.floor(tonumber(i) or 0)
    if i >= 1 and i <= escritorios.n then hl.dispatch(hl.dsp.window.move({ workspace = i, follow = false })) end
end

---------------
---- MENÚS ----
---------------

-- Los de labwc (menu.xml), que Hyprland no tiene: lib/menu-hyprland.py los enseña traducidos con wofi junto
-- al puntero. El del escritorio sale con el clic derecho donde no hay ventana ni panel (barra, lanzador,
-- notificaciones); el de ventana, con el clic derecho en su barra de título (hyprbars, on_right_click).
local MENU = "/usr/lib/command-os/menu-hyprland.py"
-- Lo que ocupa la barra de título encima de la ventana y el margen para agarrar el filo.
local ENCIMA, FILO = hl.plugin.hyprbars and 32 or 0, 1 + 10

function command_os.menu(cual)
    if cual ~= "escritorio" and cual ~= "ventana" then return end
    local c, m = hl.get_cursor_pos(), hl.get_monitor_at_cursor()
    if not (c and m) then return end
    -- wofi no reserva sitio: se coloca dentro de lo que deja libre la barra.
    local x, y, an, al = area(m)
    hl.exec_cmd(string.format("%s %s %d %d %d %d", MENU, cual,
        math.floor(c.x - x), math.floor(c.y - y), math.floor(an), math.floor(al)))
end

local function dentro(c, x, y, an, al)
    return c.x >= x and c.x < x + an and c.y >= y and c.y < y + al
end

local function hay_algo_debajo(c)
    for _, l in ipairs(hl.get_layers()) do
        -- Capas 0 y 1: el fondo de pantalla; 2 y 3: la barra, los paneles y las notificaciones.
        if l.mapped and l.layer >= 2 and dentro(c, l.x, l.y, l.w, l.h) then return true end
    end
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and w.workspace.visible and not w.hidden then
            local x, y = par(w.at)
            local an, al = par(w.size)
            if dentro(c, x - FILO, y - FILO - ENCIMA, an + 2 * FILO, al + 2 * FILO + ENCIMA) then return true end
        end
    end
    return false
end

local function clic_derecho()
    local c = hl.get_cursor_pos()
    if c and not hay_algo_debajo(c) then command_os.menu("escritorio") end
end

-----------------
---- ALT+TAB ----
-----------------

-- Como el de labwc: pasa al momento a la ventana anterior y, si Alt sigue pulsado, enseña la lista (icono y
-- título) con rofi, de la más reciente a la más antigua: Tab avanza, Mayús+Tab retrocede, soltar Alt elige y
-- Escape vuelve a la de antes. Salen las del escritorio, las fijadas y las minimizadas; el centro y los
-- desplegables, no (labwc: skipWindowSwitcher). Sin rofi (aparte, como Hyprland) solo cambia de ventana.
-- Con la lista abierta, el submapa «alttab» deja que Alt+Tab llegue a rofi en vez de a este atajo.
local ROFI = existe("/usr/bin/rofi")
local ESPERA = 150 -- ms con Alt pulsado antes de enseñar la lista: un toque rápido solo cambia de ventana
local TECLAS_ROFI = "-kb-accept-entry '!Alt-Alt_L,!Alt-Alt_R,Return,KP_Enter' -kb-row-down 'Alt+Tab,Down'"
    .. " -kb-row-up 'Alt+ISO_Left_Tab,Alt+Shift+ISO_Left_Tab,Up' -kb-cancel 'Escape'"
local alttab_en_curso = nil -- { lista = direcciones, i = la elegida, temporizador }

local function fuera_de_la_lista(clase)
    return clase:match("^dev%.commandlab%.Centro") or clase == "org.pulseaudio.pavucontrol"
        or clase == "blueman-manager"
end

local function recientes()
    local ws = hl.get_active_workspace()
    local lista = {}
    for _, w in ipairs(hl.get_windows()) do
        local donde = w.workspace
        if donde and not fuera_de_la_lista(w.class or "")
            and (w.pinned or donde.name == MINIMIZADAS or (ws and donde.id == ws.id)) then
            table.insert(lista, w)
        end
    end
    local function orden(w) return w.focus_history_id >= 0 and w.focus_history_id or math.huge end
    table.sort(lista, function(a, b) return orden(a) < orden(b) end)
    return lista
end

-- La trae al frente; si estaba minimizada, antes al escritorio de la pantalla.
local function activar(direccion)
    local w = direccion and hl.get_window("address:" .. direccion)
    if not w then return end
    if w.workspace and w.workspace.name == MINIMIZADAS then
        local ws = hl.get_active_workspace()
        if ws then hl.dispatch(hl.dsp.window.move({ window = w, workspace = ws.id, follow = false })) end
    end
    hl.dispatch(hl.dsp.focus({ window = w }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end

local function abrir_lista(estado)
    local run = os.getenv("XDG_RUNTIME_DIR")
    local ruta = run and (run .. "/command-os-alttab")
    local f = ruta and io.open(ruta, "w")
    if not f then return false end
    -- rofi -dmenu: «título\0icon\x1fclase» por línea.
    for _, direccion in ipairs(estado.lista) do
        local w = hl.get_window("address:" .. direccion)
        local titulo = w and (w.title ~= "" and w.title or w.class) or "?"
        f:write((titulo:gsub("[\r\n]", " ")), "\0icon\31", (w and w.class or ""):lower(), "\n")
    end
    f:close()
    hl.dispatch(hl.dsp.submap("alttab"))
    hl.exec_cmd(string.format(
        [[i=$(rofi -dmenu -no-custom -format i -show-icons -p '' -selected-row %d -input '%s' ]]
        .. [[-theme "$(command-os-config rofi/alttab.rasi)" %s); hyprctl eval "command_os.alttab_fin(${i:--1})"]],
        estado.i - 1, ruta, TECLAS_ROFI))
    return true
end

-- Mientras Alt siga pulsado, Alt+Tab sigue por la misma lista; al soltarlo antes de ESPERA, se acaba ahí.
local function esperar_alt(estado)
    estado.temporizador = hl.timer(function()
        if alttab_en_curso ~= estado then return end
        if not (hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R")) then
            alttab_en_curso = nil
        elseif not (ROFI and abrir_lista(estado)) then
            esperar_alt(estado)
        end
    end, { timeout = ESPERA, type = "oneshot" })
end

local function alttab(paso)
    local estado = alttab_en_curso
    if estado then
        estado.i = (estado.i - 1 + paso) % #estado.lista + 1
        activar(estado.lista[estado.i])
        return
    end
    local lista = recientes()
    if #lista == 0 then return end
    estado = { lista = {}, i = #lista == 1 and 1 or (paso > 0 and 2 or #lista) }
    for k, w in ipairs(lista) do estado.lista[k] = w.address end
    activar(estado.lista[estado.i])
    if #lista > 1 then
        alttab_en_curso = estado
        esperar_alt(estado)
    end
end

-- Lo llama la orden de abrir_lista al cerrarse rofi: el número de la elegida (desde 0) o -1 (Escape).
function command_os.alttab_fin(i)
    hl.dispatch(hl.dsp.submap("reset"))
    local estado = alttab_en_curso
    alttab_en_curso = nil
    if not estado then return end
    i = math.floor(tonumber(i) or -1)
    activar(estado.lista[i >= 0 and i + 1 or 1])
end

hl.define_submap("alttab", function()
    -- Escape llega también a rofi, que se cierra y llama a alttab_fin; esto, por si rofi no llegara a salir.
    hl.bind("Escape", function() command_os.alttab_fin(-1) end, { non_consuming = true })
end)

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
hl.bind("ALT + Tab", function() alttab(1) end)
hl.bind("ALT + SHIFT + Tab", function() alttab(-1) end)

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

-- Ratón: Super+arrastrar mueve y Super+clic derecho redimensiona (los de serie de labwc). Los clics en
-- cualquier sitio siguen llegando a las ventanas (non_consuming): el izquierdo solo mira si cierra el centro
-- o encaja la ventana al soltarla (también con Super pulsado: ignore_mods), y el derecho, si es en el fondo.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("mouse:272", al_pulsar, { non_consuming = true, ignore_mods = true })
hl.bind("mouse:272", al_soltar, { non_consuming = true, ignore_mods = true, release = true })
hl.bind("mouse:273", clic_derecho, { non_consuming = true })

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
