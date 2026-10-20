#!/usr/bin/env python3
"""Genera los sonidos de Command OS en os/branding/sounds/ (WAV estéreo 48 kHz, 16 bit).

Carácter (marca v2, docs/DISENO.md § «Sonido»): un instrumento de medida preciso y sobrio. Tonos casi
puros (seno con un segundo armónico breve en el ataque), ataque de 2 ms y caída limpia, sin ruido, sin
saturación y sin nada al azar. Movimiento de BRAND.md § 9: arranca con decisión y se asienta sin
rebotes. Una sola tónica (La) con quintas, cuartas y octavas; los tiempos, los de la marca (90 y
160 ms). Sala casi seca. Síntesis propia con numpy.

Eventos (os/bin/command-os-sound): boot (inicio de sesión), notify y critical (swaync, por urgencia),
lock y unlock (hypridle), tick (teclas de volumen).
Uso: python build/make-sounds.py
"""
import os
import wave

import numpy as np

SR = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "os", "branding", "sounds")
# La respuesta de la sala usa ruido: con semilla fija, cada ejecución da los mismos archivos.
rng = np.random.default_rng(0)

LA3, LA4, MI5, LA5, RE6, MI6, MI7 = 220.0, 440.0, 659.26, 880.0, 1174.66, 1318.51, 2637.02


def t_of(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, decay, attack=0.002):
    """Ataque de medio coseno (sin clic) y caída exponencial; `decay` en segundos (constante de tiempo)."""
    t = np.arange(n) / SR
    a = np.where(t < attack, 0.5 - 0.5 * np.cos(np.pi * t / attack), 1.0)
    return a * np.exp(-t / decay)


def tono(freq, dur, decay, amp=0.5, brillo=0.06):
    """Seno casi puro: el segundo armónico solo en el ataque y se apaga el doble de rápido."""
    t = t_of(dur)
    s = np.sin(2 * np.pi * freq * t) + brillo * np.sin(4 * np.pi * freq * t) * np.exp(-t / (decay / 2))
    return s * env(len(t), decay) * amp


def place(parts, total):
    """parts: [(inicio en s, señal mono, pan -1..1)] -> (L, R)."""
    n = int(SR * total)
    L, R = np.zeros(n), np.zeros(n)
    for start, sig, pan in parts:
        o = int(SR * start)
        m = min(len(sig), n - o)
        gl, gr = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        L[o:o + m] += sig[:m] * gl
        R[o:o + m] += sig[:m] * gr
    return L, R


def sala(L, R, size=0.06, mix=0.08):
    """Sala casi seca: respuesta al impulso muy corta, distinta por canal, para que no suene plano."""
    n = int(SR * size)
    t = np.arange(n) / SR
    out = []
    for ch in (L, R):
        ir = rng.standard_normal(n) * np.exp(-t / (size / 6))
        ir /= np.sqrt(np.sum(ir ** 2))
        wet = np.concatenate([np.convolve(ch, ir), [0.0]])  # len(ch) + n
        dry = np.concatenate([ch, np.zeros(n)])
        out.append(dry + wet * mix)
    return out


def save(name, L, R, peak=0.6, fade=0.02):
    m = max(np.abs(L).max(), np.abs(R).max(), 1e-9)
    k = peak / m
    n = len(L)
    f = int(SR * fade)
    g = np.ones(n)
    g[-f:] = np.linspace(1, 0, f)
    data = np.stack([np.clip(L * k * g, -1, 1), np.clip(R * k * g, -1, 1)], axis=1)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32767).astype("<i2").tobytes())
    print(f"{name}.wav  {n / SR:.2f}s")


def main():
    os.makedirs(OUT, exist_ok=True)
    old = os.path.join(OUT, "login.wav")  # ya no se usa
    if os.path.exists(old):
        os.remove(old)

    # Arranque: tónica, quinta y octava, escalonadas 160 ms; la última se queda con la tónica grave debajo.
    save("boot", *sala(*place([(0.00, tono(LA4, 0.5, 0.16, 0.45), -0.1),
                               (0.16, tono(MI5, 0.5, 0.18, 0.45), 0.0),
                               (0.32, tono(LA5, 1.1, 0.45, 0.5), 0.1),
                               (0.32, tono(LA3, 1.1, 0.4, 0.18, 0.0), 0.0)], 1.45)), peak=0.75)

    # Notificación: dos notas cortas que suben una cuarta.
    save("notify", *sala(*place([(0.00, tono(LA5, 0.2, 0.06, 0.45), 0.0),
                                 (0.09, tono(RE6, 0.3, 0.1, 0.45), 0.0)], 0.4)))

    # Urgente: el mismo tono tres veces, más brillante. La urgencia la da la repetición, no la distorsión.
    save("critical", *sala(*place([(i * 0.16, tono(RE6, 0.15, 0.05, 0.5, 0.25), 0.0)
                                   for i in range(3)], 0.55)), peak=0.65)

    # Bloqueo: baja una quinta. Desbloqueo: la misma figura hacia arriba.
    save("lock", *sala(*place([(0.00, tono(MI6, 0.15, 0.045, 0.45), 0.0),
                               (0.09, tono(LA5, 0.3, 0.09, 0.45), 0.0)], 0.4)), peak=0.55)
    save("unlock", *sala(*place([(0.00, tono(LA5, 0.15, 0.045, 0.45), 0.0),
                                 (0.09, tono(MI6, 0.3, 0.09, 0.45), 0.0)], 0.4)), peak=0.55)

    # Tecla de volumen: un toque de 90 ms, como el paso de un mando de precisión.
    save("tick", *place([(0, tono(MI7, 0.09, 0.012, 0.5, 0.0), 0.0)], 0.09), peak=0.45, fade=0.01)


if __name__ == "__main__":
    main()
