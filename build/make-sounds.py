#!/usr/bin/env python3
"""Genera los sonidos de Command OS en os/branding/sounds/ (WAV estéreo 48 kHz, 16 bit).

Síntesis propia, sin dependencias: tonos de campana FM con envolvente de ataque
seco y caída larga, eco estéreo ping-pong y una reverb corta de combs para dar
espacio ("envolvente") sin ensuciar. Carácter de BRAND.md § 9: arranca con
decisión, se asienta sin rebotes. Uso: python build/make-sounds.py
"""
import math, os, random, struct, wave

SR = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "os", "branding", "sounds")
NOTE = {n: 440 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ["C4", "Db4", "D4", "Eb4", "E4", "F4", "Gb4", "G4", "Ab4", "A4", "Bb4", "B4"])}
NOTE.update({k[:-1] + "5": v * 2 for k, v in list(NOTE.items())})
NOTE.update({k[:-1] + "3": v / 2 for k, v in list(NOTE.items()) if k.endswith("4")})
NOTE.update({k[:-1] + "2": v / 4 for k, v in list(NOTE.items()) if k.endswith("4")})


def bell(freq, dur, amp=0.5, attack=0.004, decay=None, fm=1.4, ratio=2.0, pan=0.0):
    """Tono tipo campana: portadora + modulador FM cuyo índice cae con el tiempo."""
    decay = decay or dur / 3.5
    n = int(SR * dur)
    left, right = [0.0] * n, [0.0] * n
    gl, gr = math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)
    for i in range(n):
        t = i / SR
        env = min(1.0, t / attack) * math.exp(-t / decay)
        if i > n - SR * 0.02:
            env *= max(0.0, (n - i) / (SR * 0.02))
        idx = fm * math.exp(-t / (decay * 0.6))
        s = math.sin(2 * math.pi * freq * t + idx * math.sin(2 * math.pi * freq * ratio * t))
        s = (s + 0.25 * math.sin(2 * math.pi * freq * 2 * t)) * env * amp
        left[i], right[i] = s * gl, s * gr
    return left, right


def swell(freq, dur, amp=0.3, pan=0.0):
    """Pad suave: tres osciladores levemente desafinados con entrada y salida lentas."""
    n = int(SR * dur)
    left, right = [0.0] * n, [0.0] * n
    gl, gr = math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)
    for i in range(n):
        t = i / SR
        x = t / dur
        env = math.sin(math.pi * min(1.0, x)) ** 2 * (1 - 0.3 * x)
        s = sum(math.sin(2 * math.pi * freq * d * t) for d in (0.997, 1.0, 1.003)) / 3
        s += 0.3 * math.sin(2 * math.pi * freq * 0.5 * t)
        left[i], right[i] = s * env * amp * gl, s * env * amp * gr
    return left, right


def mix(parts, total):
    n = int(SR * total)
    L, R = [0.0] * n, [0.0] * n
    for start, (l, r) in parts:
        o = int(SR * start)
        for i in range(min(len(l), n - o)):
            L[o + i] += l[i]
            R[o + i] += r[i]
    return L, R


def space(L, R, echo=0.0, fb=0.35, reverb=0.18, tail=0.8):
    """Eco ping-pong opcional + reverb de combs en paralelo; añade cola de `tail` s."""
    n = len(L) + int(SR * tail)
    L, R = L + [0.0] * (n - len(L)), R + [0.0] * (n - len(R))
    if echo:
        d = int(SR * echo)
        for i in range(d, n):
            L[i] += R[i - d] * fb
            R[i] += L[i - d] * fb
    wl, wr = [0.0] * n, [0.0] * n
    for dl, g in ((0.0297, 0.77), (0.0371, 0.75), (0.0411, 0.73), (0.0437, 0.71)):
        for src, dst, off in ((L, wl, 0.0), (R, wr, 0.0011)):
            d = int(SR * (dl + off))
            buf = [0.0] * n
            for i in range(n):
                buf[i] = src[i] + (buf[i - d] * g if i >= d else 0.0)
            for i in range(n):
                dst[i] += buf[i] * 0.25
    return [l + w * reverb for l, w in zip(L, wl)], [r + w * reverb for r, w in zip(R, wr)]


def save(name, L, R, peak=0.8, fade=0.05):
    m = max(max(map(abs, L)), max(map(abs, R)), 1e-9)
    k = peak / m
    n = len(L)
    f = int(SR * fade)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        frames = bytearray()
        for i in range(n):
            g = k * (min(1.0, (n - i) / f) if i > n - f else 1.0)
            frames += struct.pack("<hh", int(max(-1, min(1, L[i] * g)) * 32767),
                                  int(max(-1, min(1, R[i] * g)) * 32767))
        w.writeframes(bytes(frames))
    print(f"{name}.wav  {n / SR:.2f}s")


def seq(notes, **kw):
    """notes: [(inicio, nota, duración, amp, pan)]."""
    total = max(s + d for s, _, d, _, _ in notes)
    return mix([(s, bell(NOTE[n], d, a, pan=p, **kw)) for s, n, d, a, p in notes], total)


def main():
    os.makedirs(OUT, exist_ok=True)
    random.seed(7)
    # Arranque: pad grave que se abre + arpegio ascendente de campanas, mucho espacio.
    parts = [(0.0, swell(NOTE["A2"], 3.4, 0.35, -0.2)), (0.2, swell(NOTE["E3"], 3.2, 0.25, 0.2)),
             (0.5, swell(NOTE["A3"], 2.8, 0.18, 0.0))]
    for i, (n, p) in enumerate([("A3", -0.5), ("E4", 0.4), ("A4", -0.3), ("B4", 0.3), ("E5", 0.0)]):
        parts.append((1.0 + i * 0.28, bell(NOTE[n], 2.2, 0.38, pan=p)))
    L, R = mix(parts, 4.0)
    save("boot", *space(L, R, echo=0.32, fb=0.38, reverb=0.35, tail=1.2))
    # Sesión lista: dos notas ascendentes.
    save("login", *space(*seq([(0, "E4", 1.2, 0.5, -0.3), (0.16, "B4", 1.4, 0.5, 0.3)]), echo=0.2, reverb=0.25))
    # Notificación: ping corto y limpio.
    save("notify", *space(*seq([(0, "E5", 0.9, 0.5, 0.0), (0.09, "B5", 0.9, 0.35, 0.2)]), echo=0.14, fb=0.25, reverb=0.2, tail=0.4))
    # Urgente: dos golpes graves.
    save("critical", *space(*seq([(0, "A3", 0.8, 0.6, 0.0), (0.22, "Eb3", 1.0, 0.6, 0.0)], fm=2.4), reverb=0.15, tail=0.4))
    # Bloqueo / desbloqueo: bajada y subida.
    save("lock", *space(*seq([(0, "B4", 0.7, 0.45, 0.3), (0.12, "E4", 1.0, 0.45, -0.3)]), echo=0.16, reverb=0.2, tail=0.4))
    save("unlock", *space(*seq([(0, "E4", 0.7, 0.45, -0.3), (0.12, "B4", 1.0, 0.5, 0.3)]), echo=0.16, reverb=0.2, tail=0.4))
    # Clic de interfaz (volumen, cambio de escritorio): seco y cortísimo.
    save("tick", *space(*seq([(0, "E5", 0.12, 0.5, 0.0)], decay=0.025, fm=0.6), reverb=0.08, tail=0.15), peak=0.55, fade=0.01)


if __name__ == "__main__":
    main()
