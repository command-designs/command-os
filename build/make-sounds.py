#!/usr/bin/env python3
"""Genera los sonidos de Command OS en os/branding/sounds/ (WAV estéreo 48 kHz, 16 bit).

Carácter: un aparato real del mundo de Cyberpunk, no un móvil ni un videojuego. Pitidos digitales
cortos, clics de transitorio (relés, botones), barridos de encendido y apagado, un golpe grave al
arrancar, y una sala pequeña y seca en lugar de ecos largos. Movimiento de BRAND.md § 9: arranca con
decisión y se asienta sin rebotes. Síntesis propia con numpy.

Eventos (os/bin/command-os-sound): boot (inicio de sesión), notify y critical (swaync, por urgencia), lock y unlock
(hypridle), tick (teclas de volumen).
Uso: python build/make-sounds.py
"""
import os
import wave

import numpy as np

SR = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "os", "branding", "sounds")
rng = np.random.default_rng(2077)


def t_of(dur):
    return np.arange(int(SR * dur)) / SR


def env_ad(n, attack, decay):
    """Envolvente de ataque lineal y caída exponencial; `decay` en segundos (constante de tiempo)."""
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay)


def blip(freq, dur, amp=0.5, attack=0.002, decay=None, soft_square=0.0):
    """Pitido digital: seno con un poco de armónico impar (cuadrada suave) si se pide."""
    t = t_of(dur)
    s = np.sin(2 * np.pi * freq * t)
    if soft_square:
        s = np.tanh(s * (1 + 6 * soft_square)) / np.tanh(1 + 6 * soft_square)
    return s * env_ad(len(t), attack, decay or dur / 4) * amp


def sweep(f0, f1, dur, amp=0.4, attack=0.004, decay=None):
    """Barrido exponencial de f0 a f1 (encendido hacia arriba, apagado hacia abajo)."""
    t = t_of(dur)
    k = np.log(f1 / f0) / dur
    phase = 2 * np.pi * f0 * (np.exp(k * t) - 1) / k
    return np.sin(phase) * env_ad(len(t), attack, decay or dur / 2.5) * amp


def lowpass(x, cutoff):
    """Filtro de un polo; `cutoff` puede ser un array (barrido de filtro)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, float), x.shape)
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def click(amp=0.6, dur=0.012, bright=6000):
    """Transitorio de relé o botón: ráfaga de ruido muy corta, paso alto."""
    n = int(SR * dur)
    noise = rng.standard_normal(n)
    hp = noise - lowpass(noise, bright)
    return hp * env_ad(n, 0.0003, dur / 5) * amp


def thump(amp=0.9, dur=0.45):
    """Golpe grave de encendido: seno que cae de 70 a 38 Hz con caída rápida."""
    t = t_of(dur)
    f = 38 + 32 * np.exp(-t / 0.05)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * env_ad(len(t), 0.002, 0.12) * amp


def whoosh(dur, amp=0.25, f0=300, f1=6000):
    """Ruido con el filtro abriéndose: los ventiladores y la fuente arrancando."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    cutoff = f0 * (f1 / f0) ** (t / dur)
    x = lowpass(rng.standard_normal(n), cutoff)
    env = np.sin(np.pi * np.minimum(1, t / dur)) ** 1.5
    return x * env * amp


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


def room(L, R, size=0.12, mix=0.18):
    """Sala pequeña y seca: respuesta al impulso de ruido con caída corta, distinta por canal."""
    n = int(SR * size)
    t = np.arange(n) / SR
    out = []
    for ch in (L, R):
        ir = rng.standard_normal(n) * np.exp(-t / (size / 5))
        ir = lowpass(ir, 5000)
        ir /= np.sqrt(np.sum(ir ** 2))
        wet = np.concatenate([np.convolve(ch, ir), [0.0]])  # len(ch) + n
        dry = np.concatenate([ch, np.zeros(n)])
        out.append(dry + wet * mix)
    return out


def save(name, L, R, peak=0.8, fade=0.02):
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

    # Arranque: golpe de encendido, ventiladores, ráfaga de datos (POST) y confirmación de dos tonos.
    data = []
    for i in range(14):
        f = rng.choice([1760, 2093, 2349, 2637, 3136])
        data.append((0.55 + i * 0.045 + rng.uniform(0, 0.012),
                     blip(f, 0.03, 0.16, decay=0.008, soft_square=0.6), rng.uniform(-0.6, 0.6)))
    parts = [(0.0, click(0.7, 0.02, 3000), 0.0), (0.01, thump(1.0, 0.6), 0.0),
             (0.05, whoosh(1.6, 0.22), -0.2), (0.12, whoosh(1.4, 0.16, 500, 8000), 0.25)]
    parts += data
    parts += [(1.35, blip(880, 0.28, 0.42, decay=0.09, soft_square=0.25), -0.15),
              (1.47, blip(1318.5, 0.6, 0.45, decay=0.2, soft_square=0.25), 0.15)]
    save("boot", *room(*place(parts, 2.3), size=0.2, mix=0.22))

    # Notificación: clic + dos tonos digitales cortos.
    save("notify", *room(*place([(0, click(0.35, 0.008), 0.0),
                                 (0.005, blip(1975.5, 0.09, 0.45, decay=0.03, soft_square=0.3), 0.0),
                                 (0.085, blip(2637, 0.18, 0.4, decay=0.05, soft_square=0.3), 0.1)], 0.35)))

    # Urgente: tres pulsos de alarma en dos tonos, saturados.
    pulses = []
    for i in range(3):
        f = 740 if i % 2 == 0 else 587
        p = np.tanh(blip(f, 0.14, 1.0, attack=0.003, decay=0.09, soft_square=0.8) * 2.2) * 0.5
        pulses.append((i * 0.17, p, 0.0))
    save("critical", *room(*place(pulses, 0.7), size=0.15, mix=0.2), peak=0.55)

    # Bloqueo: barrido hacia abajo y cerrojo. Desbloqueo: cerrojo y barrido hacia arriba.
    save("lock", *room(*place([(0, sweep(1400, 380, 0.22, 0.45), 0.0),
                               (0.2, click(0.8, 0.015, 2500), 0.0),
                               (0.205, thump(0.35, 0.15), 0.0)], 0.45)))
    save("unlock", *room(*place([(0, click(0.7, 0.012, 3000), 0.0),
                                 (0.02, sweep(420, 1600, 0.2, 0.42), 0.0),
                                 (0.17, blip(1975.5, 0.16, 0.25, decay=0.05, soft_square=0.3), 0.0)], 0.45)))

    # Clic de botón (teclas de volumen): seco y cortísimo.
    save("tick", *place([(0, click(0.6, 0.006, 7000), 0.0),
                         (0.0, blip(3520, 0.02, 0.15, decay=0.004), 0.0)], 0.05), peak=0.55, fade=0.005)


if __name__ == "__main__":
    main()
