"""Erzeugt die Hintergrundmusik mit Streichern (Cello und Violine), eigene Synthese, keine Samples.

- town.ogg     Stadt: Cello-Klang mit Bogen, weich, leichtes Vibrato
- planning.ogg Planung: derselbe Bogenklang, ruhiger Puls
- heist.ogg    Ausführung: Streicher mit Bogen-Tremolo, angespannter Achtelpuls

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


def bowed(freq: float, dur: float, vol: float = 0.4, trem: float = 0.0) -> np.ndarray:
    """Bogenton: weicher Klang (Obertöne fallen stark ab), langsames Einschwingen,
    leichtes Vibrato, etwas Bogenrauschen und ein sanfter Tiefpass. trem > 0: Bogen-Tremolo (schnelles Wippen)."""
    n = int(SR * dur)
    if freq <= 0 or n <= 0:
        return np.zeros(max(n, 0))
    t = np.arange(n) / SR
    depth = np.clip((t - 0.3) / 0.5, 0, 1) * 0.004
    rate = 2 * np.pi * 5.0
    t_eff = t - depth * np.cos(rate * t) / rate
    s = np.zeros(n)
    for k in range(1, 11):
        s += np.sin(2 * np.pi * freq * k * t_eff) / (k ** 1.6)
    # Bogenrauschen: sehr leise, gefiltert
    rng = np.random.default_rng(int(freq * 100) % 2**32)
    noise = rng.standard_normal(n) * 0.02
    s = s + np.convolve(noise, np.ones(8) / 8, mode="same")
    # sanfter Tiefpass (einpolig), macht den Klang runder
    y = np.empty(n)
    acc = 0.0
    a = 0.22
    for i in range(n):
        acc += a * (s[i] - acc)
        y[i] = acc
    # Einschwingen: bei kurzen Tönen entsprechend kürzer
    attack_t = min(0.16, dur * 0.3)
    attack = np.clip(t / max(attack_t, 1e-3), 0, 1)
    release = np.clip((dur - t) / 0.1, 0, 1)
    env = attack * release
    if trem > 0:
        env = env * (0.8 + 0.2 * np.sin(2 * np.pi * trem * t))
    return vol * y * env / 2.5


def pizz(freq: float, dur: float, vol: float = 0.4) -> np.ndarray:
    """Pizzicato (nicht mehr verwendet; bleibt als Werkzeug erhalten)."""
    return bowed(freq, dur, vol)


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
    # Ausführung: gleiche Melodie, aber als Bogenton mit Tremolo (kein Zupfen)
    mm.pluck = lambda f, d, v=0.4: bowed(f, d, v, trem=9.0)
    heist = mm.heist_loop()
    # Lautheit angeglichen an die bisherigen Stücke (Bogenklang ist dichter)
    to_ogg("town", town, gain_db=-5.3)
    to_ogg("planning", planning, gain_db=-5.1)
    to_ogg("heist", heist, gain_db=-4.4)


if __name__ == "__main__":
    main()
