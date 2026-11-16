"""A worked example of a level theme that belongs to the same score as the vale music, for the
level workstreams to copy into tools/levels/<id>/music_<id>.py and change.

    python tools/audio/level_theme_example.py <out_dir>

writes example_cursed.ogg and example_restored.ogg (both loop). A level renders its own pair into
audio/levels/<id>/ and registers them at run time (docs/ASSETS.md, Audio, "Level music").

What keeps a level's theme recognisably related to the vale music:
- the same instruments and production: Score, pads, arp and the baked reverb from music.py;
- the theme's opening figure (THEME bars 1 to 2: A B D B A F# E) as the first phrase, moved to the
  level's key, then an answer of the level's own;
- the same cursed/restored relation: drain() (one semitone down on the bright degrees), slower,
  notes dropping out, muted strings and a low heartbeat drum when cursed;
- one signature colour per level (here a bell lead and an off-beat wood click), so it is a sibling,
  not a copy.
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = next(p for p in Path(__file__).resolve().parents if (p / "project.godot").exists())
sys.path.insert(0, str(ROOT / "tools" / "audio"))
from music import CHORDS_BRIGHT, CHORDS_DARK, THEME, Score, arp, drain, pads, write_piece  # noqa: E402

KEY = -3  # semitones from the vale's D: B major
OPENING = [n for n in THEME if n[0] < 8]  # the shared figure, bars 1 to 2
# The level's own answer, bars 3 to 8, in D before transposition (D major pentatonic like THEME).
ANSWER = [
    (8, 1, 69), (9, 1, 71), (10, 2, 74), (12, 1.5, 76), (13.5, 0.5, 74), (14, 2, 71),
    (16, 1, 69), (17, 1, 66), (18, 1, 64), (19, 1, 66), (20, 2, 69), (22, 2, 64),
    (24, 1.5, 66), (25.5, 0.5, 64), (26, 1, 62), (27, 1, 64), (28, 4, 62),
]
MELODY = OPENING + ANSWER  # 8 bars; played twice for a 16-bar loop


def melody(cursed):
    for rep in (0, 32):
        for i, (beat, length, m) in enumerate(MELODY):
            if cursed and i % 4 == 3:
                continue
            yield rep + beat, length, (drain(m) if cursed else m) + KEY


def chords(cursed):
    return [(root + KEY, [t + KEY for t in tones]) for root, tones in (CHORDS_DARK if cursed else CHORDS_BRIGHT)]


def restored():
    s = Score(76, 64, 21)
    for beat, length, m in melody(False):
        s.add(beat, length, "bell", m + 12, 0.2, 0.25, ring=1.6 + length)
        s.add(beat, length, "flute", m, 0.22, -0.1, breath=0.14)
    arp(s, chords(False), [0, 2, 3, 4, 1, 3, 4, 5], gain=0.18, bright=0.6)
    pads(s, chords(False), 0.12, 0.45)
    for bar in range(16):
        s.add(bar * 4, 1, "drum", 38 + KEY, 0.32, 0.0)
        for k in (1, 3):
            s.add(bar * 4 + k + 0.5, 0.5, "wood", 81 + KEY, 0.06, 0.5)
    return s.render(loop=True)


def cursed():
    s = Score(60, 64, 23)
    for beat, length, m in melody(True):
        s.add(beat, length * 1.1, "bell", m + 12, 0.12, 0.25, ring=2.5)
        s.add(beat, length * 1.1, "flute", m, 0.3, -0.1, breath=0.3, vib=0.012)
    arp(s, chords(True), [0, None, 2, None, 1, None, 3, None], octave_shift=-12, gain=0.18, bright=0.25, decay=0.991)
    pads(s, chords(True), 0.15, 0.2)
    for bar in range(0, 16, 2):
        s.add(bar * 4, 1, "drum", 33 + KEY, 0.42, 0.0)
        s.add(bar * 4 + 0.75, 1, "drum", 33 + KEY, 0.26, 0.0)
    return s.render(loop=True, reverb=(3.4, 0.3))


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in (("example_cursed", cursed), ("example_restored", restored)):
        write_piece(fn(), out / ("%s.ogg" % name), True)


if __name__ == "__main__":
    main(sys.argv[1])
