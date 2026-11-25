"""Erzeugt die Hintergrundmusik des Spiels selbst (keine Samples aus dem Original).

Drei kurze Loops mit einem gezupften Cembalo-artigen Klang:
- town.wav     Stadtphase, C-Dur, gemächlicher Dreiertakt
- planning.wav Planung, a-Moll, ruhiger Viertelpuls
- heist.wav    Ausführung, d-Moll, gespannter Achtelpuls

Aufruf:  python3 tools/make_music.py
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


def note_freq(name: str) -> float:
    """Name wie 'C4', 'F#3', 'A4' -> Hz. Ein Ton 'R' ist eine Pause."""
    if name == "R":
        return 0.0
    base = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    letter = name[0]
    idx = 1
    semis = base[letter]
    if len(name) > 1 and name[1] in "#b":
        semis += 1 if name[1] == "#" else -1
        idx = 2
    octave = int(name[idx:])
    midi = (octave + 1) * 12 + semis
    return 440.0 * 2 ** ((midi - 69) / 12)


def pluck(freq: float, dur: float, vol: float = 0.4) -> np.ndarray:
    """Gezupfter Ton: Obertöne mit schnell abklingender Hüllkurve."""
    n = int(SR * dur)
    if freq <= 0 or n <= 0:
        return np.zeros(max(n, 0))
    t = np.arange(n) / SR
    wave_ = np.zeros(n)
    for k, amp in [(1, 1.0), (2, 0.35), (3, 0.15), (4, 0.07)]:
        wave_ += amp * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (3.0 + 2.0 * k))
    attack = np.minimum(1.0, t / 0.004)
    release = np.clip((dur - t) / 0.05, 0, 1)
    return vol * wave_ * attack * release / 1.5


def render(events: list, bpm: float, bars_beats: float) -> np.ndarray:
    """events: Liste von (Tonname, Schläge, Lautstärke). Gibt den Mix zurück."""
    beat = 60.0 / bpm
    total = bars_beats * beat
    out = np.zeros(int(SR * total) + SR)
    pos = 0.0
    for name, beats, vol in events:
        dur = beats * beat
        snd = pluck(note_freq(name), dur * 1.4, vol)
        i = int(pos * SR)
        out[i:i + len(snd)] += snd[: len(out) - i]
        pos += dur
    return out[: int(SR * total)]


def town_loop() -> np.ndarray:
    # C-Dur, Dreiertakt. Melodie aus eigenen Figuren, Begleitung als Bass.
    mel = [
        ("E5", 1.0, 0.45), ("G5", 0.5, 0.4), ("C6", 1.5, 0.45), ("B5", 0.5, 0.4), ("A5", 1.0, 0.4), ("G5", 0.5, 0.4),
        ("F5", 1.0, 0.45), ("E5", 0.5, 0.4), ("D5", 1.5, 0.4), ("C5", 0.5, 0.4), ("D5", 1.0, 0.4), ("E5", 0.5, 0.4),
        ("G5", 1.0, 0.45), ("A5", 0.5, 0.4), ("G5", 1.5, 0.45), ("F5", 0.5, 0.4), ("E5", 1.0, 0.4), ("D5", 0.5, 0.4),
        ("C5", 3.0, 0.4), ("R", 1.0, 0.0),
    ]
    bass = [
        ("C3", 3.0, 0.35), ("G2", 3.0, 0.35), ("A2", 3.0, 0.35), ("F2", 3.0, 0.35),
        ("C3", 3.0, 0.35), ("G2", 3.0, 0.35), ("C3", 3.0, 0.35), ("G2", 3.0, 0.35),
    ]
    melody = render(mel * 2, bpm=92, bars_beats=2 * sum(e[1] for e in mel))
    accomp = render(bass * 2, bpm=92, bars_beats=2 * sum(e[1] for e in bass))
    n = max(len(melody), len(accomp))
    mix = np.zeros(n)
    mix[: len(melody)] += melody
    mix[: len(accomp)] += accomp[: len(accomp)]
    return mix[: min(n, len(melody))]


def planning_loop() -> np.ndarray:
    # a-Moll, Viertelpuls, ruhiger Bass-Ostinato mit Melodielinie
    bass = []
    for _ in range(2):
        bass += [("A2", 1, 0.4), ("A2", 1, 0.3), ("E2", 1, 0.35), ("F2", 1, 0.35)]
        bass += [("G2", 1, 0.35), ("G2", 1, 0.3), ("E2", 1, 0.35), ("E2", 1, 0.3)]
    tune = [
        ("A4", 2, 0.35), ("C5", 1, 0.3), ("B4", 1, 0.3), ("A4", 2, 0.3), ("G4", 2, 0.3),
        ("E4", 2, 0.3), ("F4", 1, 0.3), ("E4", 1, 0.3), ("D4", 2, 0.3), ("R", 2, 0.0),
    ]
    b = render(bass, bpm=100, bars_beats=sum(e[1] for e in bass))
    t = render(tune, bpm=100, bars_beats=sum(e[1] for e in tune))
    n = max(len(b), len(t))
    mix = np.zeros(n)
    mix[: len(b)] += b
    mix[: len(t)] += t
    return mix


def heist_loop() -> np.ndarray:
    # d-Moll, Achtelpuls, gespannter Ostinato mit Akzenten
    pattern = []
    for _ in range(4):
        pattern += [("D3", 0.5, 0.4), ("D3", 0.5, 0.2), ("F3", 0.5, 0.3), ("D3", 0.5, 0.2)]
        pattern += [("A#2", 0.5, 0.35), ("A#2", 0.5, 0.2), ("C3", 0.5, 0.3), ("A#2", 0.5, 0.2)]
    high = [("D5", 2, 0.25), ("C5", 1, 0.2), ("A#4", 1, 0.2), ("A4", 4, 0.22), ("R", 2, 0.0), ("F4", 2, 0.2)] * 2
    p = render(pattern, bpm=120, bars_beats=sum(e[1] for e in pattern))
    h = render(high, bpm=120, bars_beats=sum(e[1] for e in high))
    n = max(len(p), len(h))
    mix = np.zeros(n)
    mix[: len(p)] += p
    mix[: len(h)] += h
    return mix


def to_wav(path: str, data: np.ndarray) -> None:
    peak = float(np.max(np.abs(data))) or 1.0
    pcm = np.int16(np.clip(data / peak * 0.85, -1, 1) * 32767)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    tracks = {"town": town_loop(), "planning": planning_loop(), "heist": heist_loop()}
    for name, data in tracks.items():
        path = os.path.join(OUT, name + ".wav")
        to_wav(path, data)
        print(f"{name}.wav: {len(data) / SR:.1f} s")


if __name__ == "__main__":
    main()
