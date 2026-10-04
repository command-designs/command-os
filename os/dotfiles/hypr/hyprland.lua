-- Command OS — Hyprland (configuración en Lua; el formato .conf desaparece en Hyprland 0.57).
-- Lenguaje visual en docs/DISENO.md (HUD estilo Cyberpunk 2077 con ADN Command).
-- Void #0D0B0E · Steel #2E2630 · Bone #EDEBE6 · Red #D13449 · Cyan #5BBFC4
-- Ventana activa: marco rojo con un filo cian y un halo rojo suave; el resto, apagado.
-- API: /usr/share/hypr/stubs/hl.meta.lua y https://wiki.hypr.land

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local terminal = "kitty"
local launcher = "wofi --show drun"
local files    = "thunar"
local browser  = "firefox"
local mainMod  = "SUPER"

-- --- Arranque de la sesión ---
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("command-os-sound boot")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)

-- Apps GTK y Qt con el tema de Command OS (gtk-3.0/gtk-4.0 en ~/.config y dconf de install.sh).
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
        },
    },

    general = {
        gaps_in     = 3,
        gaps_out    = 8,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(d13449ff)", "rgba(d13449ff)", "rgba(5bbfc4ff)" }, angle = 45 },
            inactive_border = "rgba(2e2630ff)",
        },
        layout = "dwindle",
    },

    -- Esquinas vivas, sin blur (caro en la GPU del Pi). El halo es una sombra roja sin
    -- desplazamiento solo en la ventana activa.
    decoration = {
        rounding     = 0,
        dim_inactive = true,
        dim_strength = 0.15,
        blur = {
            enabled = false,
        },
        shadow = {
            enabled        = true,
            range          = 14,
            render_power   = 3,
            offset         = { 0, 0 },
            color          = "rgba(d1344938)",
            color_inactive = "rgba(00000000)",
        },
    },

    animations = {
        enabled = true,
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = "rgb(0d0b0e)",
    },
})

-- Movimiento de Command (BRAND.md § 9): arranca con decisión, se asienta sin rebotes.
-- Toque HUD: entradas más secas y el degradado del marco gira al cambiar el foco.
-- Curvas: `out` (expo, entrada), `emphasized` (salida rápida), `soft` (fundidos).
-- `speed` va en décimas de segundo (4 = 0,4 s).
hl.curve("out",        { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("emphasized", { type = "bezier", points = { { 0.2, 0 },  { 0, 1 } } })
hl.curve("soft",       { type = "bezier", points = { { 0.4, 0 },  { 0.2, 1 } } })
hl.curve("linear",     { type = "bezier", points = { { 0, 0 },    { 1, 1 } } })

local function anim(leaf, speed, curve, style)
    hl.animation({ leaf = leaf, enabled = true, speed = speed, bezier = curve, style = style })
end

anim("windowsIn",        3, "out",        "popin 85%")
anim("windowsOut",       2, "emphasized", "popin 85%")
anim("windowsMove",      4, "out")
anim("fadeIn",           3, "soft")
anim("fadeOut",          2, "soft")
anim("fadeSwitch",       4, "soft")
anim("fadeDim",          5, "soft")
anim("fadeShadow",       4, "soft")
anim("border",           4, "soft")
anim("borderangle",      8, "out")
anim("layersIn",         4, "out",        "slide top")
anim("layersOut",        3, "emphasized", "slide top")
anim("fadeLayersIn",     4, "soft")
anim("fadeLayersOut",    3, "soft")
anim("workspacesIn",     5, "out",        "slide")
anim("workspacesOut",    4, "emphasized", "slide")
anim("specialWorkspace", 5, "out",        "slidevert")

-- --- Ventanas flotantes ---
-- Mezclador de volumen (clic en `vol` de la barra): panel pequeño bajo el módulo, arriba a la
-- derecha, como un desplegable. La barra mide 30 px y el margen exterior 8 px.
hl.window_rule({
    name  = "mezclador-desplegable",
    match = { class = "^(org.pulseaudio.pavucontrol)$" },
    float = true,
    pin   = true,
    size  = { 460, 340 },
    move  = { "(monitor_w-468)", "38" },
})

-- Diálogos del sistema (contraseña de polkit): centrados y flotantes.
hl.window_rule({
    name   = "polkit-centrado",
    match  = { class = "^(hyprpolkitagent)$" },
    float  = true,
    center = true,
})

-- --- Aplicaciones ---
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Space",  hl.dsp.exec_cmd(launcher))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd(launcher))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(files))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + V",      hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- --- Ventanas ---
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + " .. dir,           hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. dir,   hl.dsp.window.swap({ direction = dir }))
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- --- Espacios de trabajo ---
-- Los cuatro de la barra existen siempre, aunque estén vacíos.
for i = 1, 4 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end
for i = 1, 5 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + Tab",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }))

-- --- Sistema ---
-- Menú de energía (bloquear · reiniciar · apagar), también en el botón de la barra.
hl.bind(mainMod .. " + Escape",    hl.dsp.exec_cmd("command-os-power"))
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"))
-- Salida de emergencia: cierra Hyprland y el inicio automático de tty1 abre una sesión nueva.
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("makoctl dismiss --all"))
hl.bind("Print",                   hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd("grim - | wl-copy"))

-- --- Teclas multimedia (con OSD) ---
local held = { locked = true, repeating = true }
local once = { locked = true }
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise && command-os-sound tick"), held)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower && command-os-sound tick"), held)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), once)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), held)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), held)
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), once)
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"), once)
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"), once)

-- Ajustes locales que genera install.sh en ~/.config/hypr/local.lua (p. ej. el perfil ligero de
-- la VM). Debe ir al final. Si no existe se ignora; si tiene un error, se informa.
local ok, err = pcall(require, "local")
if not ok and not tostring(err):find("module 'local' not found", 1, true) then
    error(err)
end
