"""The level themes for Book One's levels 2 to 5 and the Dregs, one score with the vale music.

    python tools/audio/level_music.py <project root or audio/levels dir> [<report.json>]

writes audio/levels/<id>/<id>_cursed.ogg and <id>_restored.ogg for tallowford, sedge_plain,
mosswater and hollow_kiln, and audio/levels/hollow_kiln/hollow_kiln_dregs.ogg (the boss fight). All
loop. Levels register and play them themselves (docs/ASSETS.md, Audio, "Level music").

Each is built the way tools/audio/level_theme_example.py explains: the vale theme's opening figure
(THEME bars 1 to 2) in the level's key, an answer of the level's own, the vale's instruments and
baked reverb, and the cursed track derived from the restored one by drain(), a slower tempo,
dropped notes, muted strings and a heartbeat drum. Each level adds one colour of its own:
Tallowford slow quarter-note lute and a lamp bell, Sedge Plain walking drums, open fifths and wind,
Mosswater low close plucks and drips, the Hollow Kiln the theme bent into 5/4 with a tritone in it,
and the Dregs a driving dark arp under the opening drained and broken.
"""
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from music import CHORDS_BRIGHT, CHORDS_DARK, THEME, Score, arp, drain, pads, write_piece  # noqa: E402

OPENING = [n for n in THEME if n[0] < 8]


def tune(answer, cursed, key, drop=True, octave=0):
    """The opening plus a level's answer, played twice for 16 bars; drained and thinned when cursed."""
    for rep in (0, 32):
        for i, (beat, length, m) in enumerate(OPENING + answer):
            if cursed and drop and i % 4 == 3:
                continue
            yield rep + beat, length, (drain(m) if cursed else m) + key + octave


def keyed(chords, key):
    return [(root + key, [t + key for t in tones]) for root, tones in chords]


def heartbeat(s, note, bars, gain=0.42):
    for bar in range(0, bars, 2):
        s.add(bar * 4, 1, "drum", note, gain, 0.0)
        s.add(bar * 4 + 0.75, 1, "drum", note, gain * 0.62, 0.0)


# ------------------------------------------------------------------ Tallowford: dusk, lamps, warm
TALLOW_KEY = -5  # A major, warm and low
TALLOW_ANSWER = [
    (8, 2, 66), (10, 1, 69), (11, 1, 71), (12, 3, 69), (15, 1, 66),
    (16, 1.5, 64), (17.5, 0.5, 66), (18, 1, 69), (19, 1, 74), (20, 3, 71), (23, 1, 69),
    (24, 1, 66), (25, 1, 64), (26, 2, 62), (28, 1, 64), (29, 1, 66), (30, 2, 62),
]


def tallowford(cursed):
    k = TALLOW_KEY
    chords = keyed(CHORDS_DARK if cursed else CHORDS_BRIGHT, k)
    s = Score(60 if cursed else 66, 64, 41 if cursed else 40)
    for beat, length, m in tune(TALLOW_ANSWER, cursed, k):
        s.add(beat, length * (1.15 if cursed else 1.0), "flute", m, 0.3 if cursed else 0.26, -0.15, breath=0.3 if cursed else 0.16, vib=0.012 if cursed else 0.006)
    arp(s, chords, [0, 2, 3, 4] if not cursed else [0, None, 2, None], octave_shift=-12, gain=0.24, bright=0.25 if cursed else 0.4,
        decay=0.991 if cursed else 0.996, pan=-0.3, every=1.0)
    pads(s, chords, 0.13, 0.2 if cursed else 0.3)
    for bar in range(1, 16, 2):
        lamp = (81 if bar % 4 == 1 else 78) + k
        s.add(bar * 4 + 3, 1, "bell", drain(lamp - k) + k if cursed else lamp, 0.07 if cursed else 0.11, 0.45, ring=3.0)
    if cursed:
        heartbeat(s, 33 + k, 16)
    else:
        for bar in range(16):
            s.add(bar * 4, 1, "drum", 38 + k, 0.22, 0.0)
    return s.render(loop=True, reverb=(3.2, 0.28) if cursed else (2.8, 0.25))


# ------------------------------------------------------- Sedge Plain: open, windy, walking pace
SEDGE_KEY = 2  # E major
SEDGE_ANSWER = [
    (8, 1, 69), (9, 1, 74), (10, 1, 76), (11, 1, 74), (12, 2, 69), (14, 1, 71), (15, 1, 69),
    (16, 1, 66), (17, 1, 69), (18, 2, 64), (20, 1, 62), (21, 1, 64), (22, 2, 69),
    (24, 1, 74), (25, 0.5, 76), (25.5, 0.5, 74), (26, 1, 71), (27, 1, 69), (28, 3, 62), (31, 1, 64),
]


def open_fifths(chords):
    return [(root, [root + 12, root + 19, root + 24]) for root, _ in chords]


def sedge_plain(cursed):
    k = SEDGE_KEY
    chords = keyed(open_fifths(CHORDS_DARK if cursed else CHORDS_BRIGHT), k)
    s = Score(72 if cursed else 88, 64, 51 if cursed else 50)
    for beat, length, m in tune(SEDGE_ANSWER, cursed, k):
        s.add(beat, length, "flute", m, 0.3, 0.15, breath=0.32 if cursed else 0.22, vib=0.014 if cursed else 0.009)
        if not cursed:
            s.add(beat, length, "pluck", m - 12, 0.12, -0.35, bright=0.55, ring=0.8)
    pads(s, chords, 0.12, 0.25 if cursed else 0.4)
    for bar in range(16):
        g = s.rng
        s.add(bar * 4 + 0.5, 3.0, "wind", 74 + k + int(g.integers(-3, 4)), 0.1 if cursed else 0.07, float(g.uniform(-0.7, 0.7)),
              to=86 + k + int(g.integers(-5, 3)), q=2.0)
    if cursed:
        heartbeat(s, 35 + k, 16, 0.36)
        arp(s, chords, [0, None, None, 1, None, None, 2, None], octave_shift=-12, gain=0.16, bright=0.25, decay=0.99)
    else:
        for bar in range(16):
            for b in (0, 2):
                s.add(bar * 4 + b, 1, "drum", 40 + k, 0.34 if b == 0 else 0.24, 0.0)
            for b in (1, 3):
                s.add(bar * 4 + b, 0.5, "wood", 76 + k, 0.05, 0.4)
            for i in range(8):
                s.add(bar * 4 + i * 0.5, 0.5, "shaker", None, 0.035 if i % 2 else 0.05, -0.4)
    return s.render(loop=True, reverb=(3.0, 0.24))


# ---------------------------------------------------------- Mosswater Wood: dark, close, water
MOSS_KEY = -7  # G major, low
MOSS_ANSWER = [
    (8, 2, 62), (10, 1, 64), (11, 1, 66), (12, 2, 64), (14, 2, 59),
    (16, 1.5, 57), (17.5, 0.5, 59), (18, 2, 62), (20, 1, 64), (21, 1, 62), (22, 2, 57),
    (24, 1, 59), (25, 1, 62), (26, 1, 64), (27, 1, 66), (28, 4, 62),
]


def mosswater(cursed):
    k = MOSS_KEY
    chords = keyed(CHORDS_DARK if cursed else CHORDS_BRIGHT, k)
    s = Score(60 if cursed else 66, 64, 61 if cursed else 60)
    for beat, length, m in tune(MOSS_ANSWER, cursed, k):
        s.add(beat, length * 1.05, "flute", m, 0.28, 0.1, breath=0.34 if cursed else 0.24, vib=0.01)
        s.add(beat, length, "pluck", m - 12, 0.16 if cursed else 0.2, -0.25, bright=0.2, decay=0.99, ring=0.7)
    arp(s, chords, [0, None, 1, 2] * 2 if not cursed else [0, None, None, None, 1, None, None, None], octave_shift=-12,
        gain=0.18, bright=0.15, decay=0.989, pan=0.3)
    pads(s, chords, 0.2 if cursed else 0.14, 0.15 if cursed else 0.22)
    drips = [74, 78, 81, 86, 88, 90] if not cursed else [74, 77, 81, 86, 89]
    for i in range(14 if cursed else 26):
        g = s.rng
        s.add(float(g.uniform(0, 63)), 0.25, "bell", int(g.choice(drips)) + k + 12, 0.05 if cursed else 0.07, float(g.uniform(-0.8, 0.8)), ring=0.35)
    if cursed:
        heartbeat(s, 31 + k + 12, 16, 0.4)
    else:
        for bar in range(16):
            s.add(bar * 4, 1, "drum", 38 + k, 0.2, 0.0)
            s.add(bar * 4 + 2.5, 1, "drum", 38 + k, 0.12, 0.0)
    return s.render(loop=True, reverb=(2.2, 0.2) if not cursed else (2.6, 0.24))


# ------------------------------------------- The Hollow Kiln: hollow, low, the theme bent out of shape
KILN_KEY = -14  # C, an octave and a tone below the vale
BENT_PLACES = (0.0, 1.5, 2.5, 4.0)  # where beats 0..3 of a 4/4 bar land in a 5/4 bar


def bent_theme():
    """THEME bars 1 to 8 stretched into 5/4 (the third and fourth beats pushed late) and drained,
    with the fifth (A) flattened to a tritone in every other bar."""
    out = []
    for beat, length, m in THEME:
        if beat >= 32:
            continue
        bar, pos = divmod(beat, 4)
        lo = int(pos)
        place = BENT_PLACES[lo] + (pos - lo) * ((BENT_PLACES[lo + 1] if lo < 3 else 5.0) - BENT_PLACES[lo])
        n = drain(m)
        if bar % 2 == 1 and n % 12 == 9:
            n -= 1
        out.append((bar * 5 + place, length * 1.25, n))
    return out


def kiln_chords_bent():
    return [(root - 1 if i % 4 == 3 else root, tones) for i, (root, tones) in enumerate(CHORDS_DARK[:8])]


def hollow_kiln(cursed):
    k = KILN_KEY
    if cursed:
        s = Score(84, 80, 71)
        chords = keyed(kiln_chords_bent(), k)
        for rep in (0, 40):
            for i, (beat, length, m) in enumerate(bent_theme()):
                if rep and i % 3 == 2:
                    continue
                s.add(rep + beat, length, "flute", m + k + 12, 0.3, -0.1, breath=0.4, vib=0.016)
                s.add(rep + beat, length, "pluck", m + k, 0.2, 0.2, bright=0.2, decay=0.99, ring=1.4)
        for bar in range(16):
            root, tones = chords[bar % 8]
            s.add(bar * 5, 5.2, "pad", [root] + tones, 0.14, 0.0, attack=1.2, bright=0.15)
            s.add(bar * 5, 1, "drum", root - 12 if root - 12 > 24 else root, 0.42, 0.0)
            s.add(bar * 5 + 3, 1, "drum", root, 0.2, 0.0)
            s.add(bar * 5 + 2.5, 0.5, "wood", 57 + k + 12, 0.07, -0.5)
            s.add(bar * 5 + 4.5, 0.5, "wood", 56 + k + 12, 0.05, 0.5)
        return s.render(loop=True, reverb=(4.2, 0.36))
    s = Score(70, 64, 70)
    chords = keyed(CHORDS_BRIGHT, k + 12)
    for beat, length, m in THEME:
        s.add(beat, length, "flute", m + k + 12, 0.24, -0.1, breath=0.18)
        s.add(beat, length, "bell", m + k + 24, 0.1, 0.3, ring=1.4 + length)
    arp(s, chords, [0, 2, 3, 4, 1, 3, 4, 5], octave_shift=-12, gain=0.17, bright=0.35)
    pads(s, chords, 0.15, 0.3)
    for bar in range(16):
        s.add(bar * 4, 1, "drum", 36 + k + 12, 0.28, 0.0)
    return s.render(loop=True, reverb=(3.8, 0.3))


# ----------------------------------------------------- The Dregs: the boss fight in the vat chamber
DREGS_KEY = -14
DREGS_BARS = 20
DREGS_LEAD = [
    # bars 1-2: the opening, drained
    *[(b, l, m) for b, l, m in OPENING],
    # bars 5-6: the opening again a fourth up, broken off
    *[(16 + b, l, m + 5) for b, l, m in OPENING if b < 5],
    (21, 3, 69),
    # bars 9-12: a falling line, the thing that only keeps
    (32, 2, 74), (34, 2, 71), (36, 1.5, 69), (37.5, 0.5, 66), (38, 2, 64),
    (40, 2, 69), (42, 2, 66), (44, 1, 64), (45, 1, 62), (46, 2, 64),
    # bars 13-14: the opening once more, low and whole
    *[(48 + b, l, m - 12) for b, l, m in OPENING],
    # bars 17-20: climbing back to the start
    (64, 1, 62), (65, 1, 64), (66, 1, 66), (67, 1, 69), (68, 2, 71), (70, 2, 69),
    (72, 1, 71), (73, 1, 74), (74, 2, 76), (76, 4, 69),
]


def dregs():
    k = DREGS_KEY
    s = Score(104, DREGS_BARS * 4, 80)
    chords = keyed(CHORDS_DARK + CHORDS_DARK[:4], k + 12)
    for beat, length, m in DREGS_LEAD:
        s.add(beat, length, "flute", drain(m) + k + 12, 0.28, -0.1, breath=0.34, vib=0.014)
    arp(s, chords, [0, 0, 2, 0, 3, 0, 2, 1], octave_shift=-12, gain=0.2, bright=0.3, decay=0.99, pan=0.25)
    pads(s, chords, 0.12, 0.25)
    for bar in range(DREGS_BARS):
        root = chords[bar % len(chords)][0]
        for b, g in ((0, 0.5), (1.5, 0.3), (2, 0.42), (3.5, 0.24)):
            s.add(bar * 4 + b, 1, "drum", root, g, 0.0)
        for i in range(8):
            s.add(bar * 4 + i * 0.5, 0.5, "wood", 69 + k + 12 if i % 2 == 0 else 74 + k + 12, 0.05 if i % 2 else 0.07, 0.45 if i % 2 else -0.45)
        if bar % 4 == 3:
            s.add(bar * 4 + 2, 2, "wind", 50 + k + 24, 0.12, 0.0, to=74 + k + 24, q=3.0)
    return s.render(loop=True, reverb=(3.6, 0.3))


PIECES = {
    "tallowford_cursed": ("tallowford", lambda: tallowford(True)),
    "tallowford_restored": ("tallowford", lambda: tallowford(False)),
    "sedge_plain_cursed": ("sedge_plain", lambda: sedge_plain(True)),
    "sedge_plain_restored": ("sedge_plain", lambda: sedge_plain(False)),
    "mosswater_cursed": ("mosswater", lambda: mosswater(True)),
    "mosswater_restored": ("mosswater", lambda: mosswater(False)),
    "hollow_kiln_cursed": ("hollow_kiln", lambda: hollow_kiln(True)),
    "hollow_kiln_restored": ("hollow_kiln", lambda: hollow_kiln(False)),
    "hollow_kiln_dregs": ("hollow_kiln", dregs),
}


def main(levels_dir, report_path=None, only=None):
    out = Path(levels_dir)
    report = {}
    for name, (level, fn) in PIECES.items():
        if only and name not in only:
            continue
        (out / level).mkdir(parents=True, exist_ok=True)
        entry, _ = write_piece(fn(), out / level / ("%s.ogg" % name), True)
        entry["file"] = "audio/levels/%s/%s.ogg" % (level, name)
        report[name] = entry
    if report_path:
        with open(report_path, "w", newline="\n") as f:
            f.write(json.dumps(report, indent=1))
    return report


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None, sys.argv[3].split(",") if len(sys.argv) > 3 else None)
