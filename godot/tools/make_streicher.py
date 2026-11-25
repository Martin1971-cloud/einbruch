"""Erzeugt die Hintergrundmusik mit Streichern (Cello und Violine), eigene Synthese, keine Samples.

- town.ogg     Stadt: Cello-Klang mit Bogen, weich, leichtes Vibrato
- planning.ogg Planung: derselbe Bogenklang, ruhiger Puls
- heist.ogg    Ausführung: Pizzicato-Streicher, angespannter Achtelpuls

Die Melodien kommen aus tools/make_music.py. Nur der Klang wird ersetzt.
Aufruf:  python3 tools/make_streicher.py   (braucht numpy und ffmpeg)
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_music as mm  # noqa: E402

SR = mm.SR
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


def bowed(freq: float, dur: float, vol: float = 0.4) -> np.ndarray:
    """Bogenton: sägezahnartige Obertöne, langsames Einschwingen und leichtes Vibrato."""
    n = int(SR * dur)
    if freq <= 0 or n <= 0:
        return np.zeros(max(n, 0))
    t = np.arange(n) / SR
    # Vibrato erst nach kurzer Zeit (5,2 Hz, sehr flach), wie beim Streicher
    depth = np.clip((t - 0.25) / 0.4, 0, 1) * 0.0035
    rate = 2 * np.pi * 5.2
    t_eff = t - depth * np.cos(rate * t) / rate
    s = np.zeros(n)
    for k in range(1, 13):
        s += np.sin(2 * np.pi * freq * k * t_eff) / (k ** 1.15)
    attack = np.clip(t / 0.14, 0, 1)
    release = np.clip((dur - t) / 0.12, 0, 1)
    return vol * s * attack * release / 3.0


def pizz(freq: float, dur: float, vol: float = 0.4) -> np.ndarray:
    """Pizzicato-Streicher: heller Anschlag, schnell abklingend, mehr Obertöne als der Bogenton."""
    n = int(SR * dur)
    if freq <= 0 or n <= 0:
        return np.zeros(max(n, 0))
    t = np.arange(n) / SR
    s = np.zeros(n)
    for k in range(1, 10):
        s += np.sin(2 * np.pi * freq * k * t) / k * np.exp(-t * (4.0 + 0.6 * k))
    attack = np.clip(t / 0.004, 0, 1)
    release = np.clip((dur - t) / 0.05, 0, 1)
    return vol * s * attack * release / 2.2


def to_ogg(name: str, data: np.ndarray, gain_db: float = 0.0) -> None:
    peak = float(np.max(np.abs(data))) or 1.0
    pcm = np.int16(np.clip(data / peak * 0.85, -1, 1) * 32767)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(SR)
            f.writeframes(pcm.tobytes())
        out = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-af", "volume=%.1fdB" % gain_db, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    print(f"{name}.ogg: {len(data) / SR:.1f} s")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    mm.pluck = bowed
    town = mm.town_loop()
    planning = mm.planning_loop()
    mm.pluck = pizz
    heist = mm.heist_loop()
    # Lautheit angeglichen an die bisherigen Stücke (Bogenklang ist dichter)
    to_ogg("town", town, gain_db=-4.5)
    to_ogg("planning", planning, gain_db=-3.5)
    to_ogg("heist", heist, gain_db=1.0)


if __name__ == "__main__":
    main()
