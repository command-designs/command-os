"""Chaflanes y escuadras de la marca v2 (BRAND.md § 6, docs/DISENO.md § «Forma») para las hojas GTK.

El CSS de GTK no tiene clip-path: el chaflán se dibuja con border-image, un SVG de nueve partes con
las esquinas superior izquierda e inferior derecha cortadas a 45° y el filo de 1 px siguiendo el
corte (como .panel y .btn--cut de components.css). GTK no pinta el centro de un border-image (no
admite «fill»): cada hoja lo rellena con un degradado liso de su tamaño menos las esquinas. GTK 3
no carga imágenes data:, así que van en archivos: /usr/share/command-os/chaflanes/ y, para las apps
Flatpak, copias en ~/.config/gtk-3.0/chaflanes y gtk-4.0/chaflanes (command-os-user-setup).

Uso: python build/make-chaflanes.py [--comprobar]  ->  os/branding/chaflanes/*.svg
Con --comprobar no escribe nada y sale con 1 si algún SVG no está al día (tests/marca.sh).
"""
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "os" / "branding" / "chaflanes"

# Paleta v2 (tokens.css de command-web).
GRAPHITE, SLATE = "#151515", "#1f1f1f"
# BRAND 2.1 § 7: relleno del botón principal al pasar por encima.
HOVER_ROJO = "#b81a02"
STEEL, IRON, SMOKE = "#2a2a2a", "#3a3a3a", "#85827c"
SIGNAL_RED, RED_HOT, RED_DEEP = "#a51500", "#f5482c", "#6e0e00"

# Tamaños de corte (tokens.css: --cut-xs/sm/md/lg) y largo de las escuadras (--corner-size).
# En las hojas, border-image-slice y border-image-width son el corte + 1.
XS, SM, MD, LG = 6, 10, 14, 20
ESCUADRA = 10

# pieza: (corte, relleno, filo)
CHAFLANES = {
    "panel": (MD, GRAPHITE, STEEL),             # .panel: paneles, notificaciones, menú de energía
    "panel-hover": (MD, GRAPHITE, RED_HOT),     # .panel--interactive:hover (.dev:hover): notificación al pasar
    "panel-activo": (MD, GRAPHITE, RED_HOT),    # .panel--active: notificación crítica
    "menu": (MD, SLATE, STEEL),                 # menús y popovers de las apps
    "paleta": (LG, GRAPHITE, IRON),             # lanzador (paleta de comandos)
    "pista": (XS, SLATE, STEEL),                # tooltips
    "boton": (SM, GRAPHITE, IRON),              # .btn--cut
    "boton-hover": (SM, GRAPHITE, RED_HOT),     # .btn:hover: filo Red Hot (y texto blanco, en la hoja)
    "boton-pulsado": (SM, SLATE, RED_HOT),
    "boton-foco": (SM, GRAPHITE, RED_HOT),
    "boton-inactivo": (SM, GRAPHITE, STEEL),
    "principal": (SM, SIGNAL_RED, SIGNAL_RED),  # .btn--cut.btn--primary (texto blanco)
    "principal-hover": (SM, HOVER_ROJO, RED_HOT),  # .btn.primary:hover: #B81A02 con filo Red Hot
    "principal-foco": (SM, SIGNAL_RED, RED_HOT),   # con el foco del teclado: solo el filo
    "principal-pulsado": (SM, RED_DEEP, RED_DEEP),
}

R2 = 2 ** 0.5


def num(x):
    return f"{x:.3f}".rstrip("0").rstrip(".")


def svg(s, cuerpo):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{s}" height="{s}" '
            f'viewBox="0 0 {s} {s}">{cuerpo}</svg>\n')


def chaflan(c, relleno, filo):
    """SVG de 2c + 3 px de lado: esquinas de c + 1 px y un píxel central que se estira. Polígono
    exterior en el color del filo y, 1 px por dentro, el relleno; el corte interior va √2 − 1 más
    adentro para que el filo diagonal también mida 1 px."""
    s = 2 * c + 3
    d = c + R2 - 1  # el corte interior: rectas x + y = c + √2 y x + y = 2s − c − √2
    fuera = [(c, 0), (s, 0), (s, s - c), (s - c, s), (0, s), (0, c)]
    dentro = [(d, 1), (s - 1, 1), (s - 1, s - d), (s - d, s - 1), (1, s - 1), (1, d)]

    def poligono(puntos, color):
        return f'<polygon points="{" ".join(f"{num(x)},{num(y)}" for x, y in puntos)}" fill="{color}"/>'

    return svg(s, poligono(fuera, filo) + poligono(dentro, relleno))


def escuadras(largo, color):
    """Las cuatro escuadras de .corners: 1 px de grueso, «largo» px por brazo y el centro vacío.
    Cada esquina mide largo + 2 px (en las hojas, border-image-slice y border-image-width): GTK
    suaviza al estirar los lados y, si el brazo llegara al borde de la esquina, su rojo se correría
    por ellos."""
    k = largo + 2
    s = 2 * k + 1
    e = s - 1
    trazos = [(0, 0, largo, 1), (0, 0, 1, largo), (s - largo, 0, largo, 1), (e, 0, 1, largo),
              (0, e, largo, 1), (0, s - largo, 1, largo), (s - largo, e, largo, 1), (e, s - largo, 1, largo)]
    return svg(s, "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>'
                          for x, y, w, h in trazos))


def piezas():
    todas = {nombre: chaflan(*datos) for nombre, datos in CHAFLANES.items()}
    todas["escuadras"] = escuadras(ESCUADRA, RED_HOT)
    return todas


def main():
    comprobar = "--comprobar" in sys.argv[1:]
    todas = piezas()
    mal = 0
    for nombre, texto in todas.items():
        archivo = OUT / f"{nombre}.svg"
        if archivo.exists() and archivo.read_text(encoding="utf-8") == texto:
            continue
        if comprobar:
            print(f"  MAL  {archivo.relative_to(OUT.parent.parent.parent)}: sin rehacer "
                  "(python build/make-chaflanes.py)")
            mal += 1
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            archivo.write_text(texto, encoding="utf-8", newline="\n")
            print(f"  {archivo.name}")
    sobran = sorted(p.name for p in OUT.glob("*.svg") if p.stem not in todas) if OUT.exists() else []
    for nombre in sobran:
        print(f"  MAL  os/branding/chaflanes/{nombre}: no lo genera este script; bórralo")
        mal += 1
    sys.exit(1 if mal else 0)


if __name__ == "__main__":
    main()
