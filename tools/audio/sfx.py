"""Every sound effect id in docs/CONTRACTS.md, synthesised to sound like materials: paper, brush
on paper, water, wind, wood and soft bells. Mono OGG Vorbis, 44.1 kHz.

    python tools/audio/sfx.py <out_dir> [<report.json>]
"""
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from synth import (RATE, bandpass, bell, drum, env_adsr, env_exp, fade, flute, highpass, levels, lowpass,  # noqa: E402
                   midi_hz, noise, normalize, pluck, sine, sweep_bandpass, wood, write_ogg)


def n_of(s):
    return int(s * RATE)


def mix(*parts):
    n = max(len(p) for p, _ in parts)
    out = np.zeros(n)
    for p, at in parts:
        a = int(at * RATE)
        p = p[: max(0, n - a)]
        out[a:a + len(p)] += p
    return out


def place(n_total, *parts):
    out = np.zeros(n_total)
    for p, at in parts:
        a = int(at * RATE)
        p = p[: max(0, n_total - a)]
        out[a:a + len(p)] += p
    return out


def paper_crinkle(seconds, rng, density=60, bright=5000):
    """Paper: clusters of tiny bright crackles."""
    n = n_of(seconds)
    out = np.zeros(n)
    count = int(density * seconds)
    for _ in range(count):
        at = int(rng.random() * (n - 400))
        ln = int(rng.uniform(40, 300))
        burst = highpass(noise(ln, rng), bright * rng.uniform(0.6, 1.4)) * np.exp(-np.arange(ln) / (ln * 0.3))
        out[at:at + ln] += burst * rng.uniform(0.2, 1.0)
    return out


def brush_scrape(seconds, rng, f0=1800, f1=4200):
    """Bristles dragged on paper: band noise with a fine grain flutter."""
    n = n_of(seconds)
    x = sweep_bandpass(noise(n, rng), f0, f1, q=1.6, steps=24)
    grain = 0.6 + 0.4 * np.abs(lowpass(noise(n, rng), 60))
    grain /= grain.max()
    return x * grain


def whoosh(seconds, rng, f0, f1, q=2.0, shape=(0.35, 0.65)):
    n = n_of(seconds)
    x = sweep_bandpass(noise(n, rng, "pink"), f0, f1, q=q, steps=40)
    t = np.linspace(0, 1, n)
    env = np.where(t < shape[0], (t / shape[0]) ** 1.5, ((1 - t) / (1 - shape[0])) ** shape[1] * 2.0)
    return x * np.clip(env, 0, 1)


def drip(freq, rng):
    n = n_of(0.12)
    t = np.arange(n) / RATE
    f = freq * (1 + 1.8 * np.exp(-t / 0.012))
    return sine(f, n) * env_exp(n, 0.03, 0.001)


def chime(notes, rng, spacing=0.12, length=1.6, gain=1.0):
    parts = [(bell(midi_hz(m), length) * gain, i * spacing) for i, m in enumerate(notes)]
    return mix(*parts)


# ----------------------------------------------------------------------------- the sounds
def footstep(rng):
    n = n_of(0.16)
    thud = lowpass(noise(n, rng), 420) * env_exp(n, 0.025, 0.003) * 3.0
    rustle = bandpass(noise(n, rng), 2500, 8000) * env_exp(n, 0.03, 0.004) * 0.5
    return thud + rustle + paper_crinkle(0.16, rng, 40, 6000) * 0.3


def jump(rng):
    return whoosh(0.32, rng, 500, 2600, q=1.5, shape=(0.3, 1.2)) + paper_crinkle(0.32, rng, 30) * 0.35


def land(rng):
    n = n_of(0.3)
    thud = lowpass(noise(n, rng), 300) * env_exp(n, 0.05, 0.002) * 3.0
    return thud + paper_crinkle(0.3, rng, 70, 4500) * 0.6 * env_exp(n, 0.1)


def swipe(rng):
    return whoosh(0.3, rng, 3200, 900, q=1.8, shape=(0.25, 1.5)) + brush_scrape(0.3, rng) * 0.35 * env_exp(n_of(0.3), 0.12)


def hit_full(rng):
    n = n_of(0.45)
    base = drum(90, 0.45, rng, 0.8) * 1.2 + bandpass(noise(n, rng), 300, 2400) * env_exp(n, 0.04, 0.001) * 1.5
    return base + place(n, (drip(900, rng) * 0.25, 0.12), (drip(1300, rng) * 0.18, 0.21))


def hurt(rng):
    n = n_of(0.5)
    t = np.arange(n) / RATE
    tone = sine(320 * np.exp(-t * 1.6), n) * env_exp(n, 0.16, 0.005) * 0.6
    tone += sine(480 * np.exp(-t * 1.6), n) * env_exp(n, 0.1, 0.005) * 0.3
    return tone + paper_crinkle(0.5, rng, 120, 3500) * env_exp(n, 0.18) * 0.9


def splotchet_hop(rng):
    n = n_of(0.18)
    t = np.arange(n) / RATE
    blip = sine(260 * (1 + 2.0 * t / 0.18), n) * env_exp(n, 0.05, 0.003)
    return blip + lowpass(noise(n, rng), 600) * env_exp(n, 0.02) * 0.6


def splotchet_die(rng):
    n = n_of(0.8)
    splash = bandpass(noise(n, rng), 200, 3000) * env_exp(n, 0.09, 0.002) * 1.4
    bubbles = place(n, *[(drip(rng.uniform(500, 1400), rng) * rng.uniform(0.2, 0.5), rng.uniform(0.05, 0.6)) for _ in range(9)])
    return splash + bubbles + place(n, (drum(70, 0.5, rng, 0.5) * 0.7, 0.0))


def reedwraith_moan(rng):
    n = n_of(1.8)
    t = np.arange(n) / RATE
    air = noise(n, rng, "pink")
    formant = sweep_bandpass(air, 300, 520, q=6.0, steps=30) * 2.5 + sweep_bandpass(air, 900, 700, q=8.0, steps=30) * 1.6
    hollow = sine(110 * (1 + 0.03 * np.sin(2 * np.pi * 3.1 * t)), n) * 0.18 + sine(165, n) * 0.08
    return (formant + hollow) * env_adsr(n, 0.4, 0.3, 0.8, 0.8)


def reed_cracks(seconds, rng, count):
    n = n_of(seconds)
    out = np.zeros(n)
    for _ in range(count):
        at = rng.uniform(0, seconds * 0.7)
        out += place(n, (wood(rng.uniform(500, 1400), 0.12, rng) * rng.uniform(0.4, 1.0), at))
    return out


def reedwraith_die(rng):
    n = n_of(1.4)
    exhale = whoosh(1.4, rng, 900, 250, q=2.0, shape=(0.15, 1.8)) * 0.8
    return exhale + reed_cracks(1.4, rng, 6) * 0.7


def veil_off(rng):
    n = n_of(1.0)
    t = np.arange(n) / RATE
    flutter = 0.55 + 0.45 * np.sin(2 * np.pi * (14 - 8 * t) * t)
    return whoosh(1.0, rng, 2400, 300, q=1.4, shape=(0.2, 1.4)) * flutter + paper_crinkle(1.0, rng, 50, 2500) * 0.3 * env_exp(n, 0.4)


def brush_open(rng):
    n = n_of(1.1)
    unroll = whoosh(0.6, rng, 400, 2200, q=1.2, shape=(0.6, 0.8)) * 0.6
    return place(n, (unroll, 0.0), (bell(midi_hz(81), 1.0) * 0.45, 0.18), (bell(midi_hz(86), 0.9) * 0.25, 0.3))


def brush_close(rng):
    n = n_of(0.9)
    roll = whoosh(0.45, rng, 2000, 500, q=1.2, shape=(0.3, 1.2)) * 0.6
    return place(n, (roll, 0.0), (bell(midi_hz(74), 0.8) * 0.4, 0.12))


def brush_stroke(rng):
    n = n_of(0.55)
    return brush_scrape(0.55, rng, 2200, 3400) * env_adsr(n, 0.04, 0.1, 0.8, 0.2)


def glyph_ok(rng):
    return chime([79, 86, 91], rng, spacing=0.11, length=1.5)


def glyph_fail(rng):
    n = n_of(0.6)
    knock = wood(220, 0.2, rng)
    sag = pluck(midi_hz(55), 0.55, rng, 0.3, 0.990) * 0.6
    t = np.arange(len(sag)) / RATE
    sag *= np.exp(-t / 0.2)
    return place(n, (knock, 0.0), (sag, 0.06))


def bloom(rng):
    notes = [62, 66, 69, 74, 78, 81]
    n = n_of(1.8)
    arp = place(n, *[(pluck(midi_hz(m), 1.2, rng, 0.6, 0.997) * 0.5, i * 0.07) for i, m in enumerate(notes)])
    shimmer = place(n, *[(bell(midi_hz(m + 12), 0.9) * 0.18, 0.35 + i * 0.09) for i, m in enumerate(notes[2:])])
    return arp + shimmer


def slash(rng):
    n = n_of(0.42)
    cut = whoosh(0.2, rng, 6500, 1800, q=2.5, shape=(0.15, 1.6))
    bristle = brush_scrape(0.42, rng, 3000, 2000) * env_exp(n, 0.1) * 0.5
    return place(n, (cut * 1.2, 0.0), (bristle, 0.03))


def gust(rng):
    n = n_of(1.3)
    t = np.arange(n) / RATE
    swirl = whoosh(1.3, rng, 300, 1600, q=1.8, shape=(0.45, 1.0))
    swirl2 = whoosh(1.3, rng, 1400, 500, q=3.0, shape=(0.6, 1.0)) * 0.5
    return (swirl + swirl2) * (0.75 + 0.25 * np.sin(2 * np.pi * 3.5 * t))


def thorns_cut(rng):
    n = n_of(0.8)
    return reed_cracks(0.8, rng, 7) + paper_crinkle(0.8, rng, 50, 3000) * 0.3 * env_exp(n, 0.3)


def soot_clear(rng):
    n = n_of(1.6)
    big = whoosh(1.6, rng, 200, 1200, q=1.0, shape=(0.3, 1.2))
    crackle = paper_crinkle(1.6, rng, 60, 2000) * 0.25 * env_adsr(n, 0.3, 0.2, 0.6, 0.8)
    return big + crackle


def zone_restore(rng):
    from synth import pad
    n = n_of(3.4)
    swell = pad([midi_hz(m) for m in (50, 57, 62, 66, 69)], 3.4, rng, attack=1.2, release=1.6, bright=0.5) * 0.7
    bells = place(n, *[(bell(midi_hz(m), 1.4) * 0.22, 0.6 + i * 0.16) for i, m in enumerate([74, 78, 81, 86, 90])])
    rise = whoosh(1.4, rng, 800, 6000, q=2.0, shape=(0.8, 0.5)) * 0.25
    return place(n, (swell, 0.0), (bells, 0.0), (rise, 0.0))


def petals(rng):
    n = n_of(1.4)
    taps = place(n, *[(bell(midi_hz(rng.choice([86, 88, 90, 93, 95, 98])), 0.4) * rng.uniform(0.08, 0.2), rng.uniform(0, 1.0)) for _ in range(12)])
    rustle = bandpass(noise(n, rng), 3000, 9000) * env_adsr(n, 0.2, 0.2, 0.5, 0.8) * 0.12
    return taps + rustle


def tree_restore(rng):
    from synth import pad
    n = n_of(5.5)
    boom = drum(55, 2.0, rng, 0.6)
    swell = pad([midi_hz(m) for m in (38, 50, 57, 62, 66, 69, 74)], 5.5, rng, attack=1.6, release=2.2, bright=0.55) * 0.8
    bells = place(n, *[(bell(midi_hz(m), 2.2) * 0.25, 1.0 + i * 0.22) for i, m in enumerate([62, 69, 74, 78, 81, 86])])
    return place(n, (boom, 0.0), (swell, 0.15), (bells, 0.0))


def ink_pickup(rng):
    n = n_of(0.5)
    return place(n, (drip(700, rng) * 0.8, 0.0), (bell(midi_hz(93), 0.45) * 0.3, 0.04))


def ui_move(rng):
    return wood(1150, 0.09, rng)


def ui_accept(rng):
    n = n_of(0.6)
    return place(n, (wood(900, 0.1, rng), 0.0), (bell(midi_hz(86), 0.55) * 0.45, 0.03))


# --------------------------------------------------------------- level-kit sounds (levels 2-5)
def kindle(rng):
    """A wick catching: a scratch, a soft whump of flame, a crackle and a warm low bell."""
    n = n_of(1.5)
    strike = brush_scrape(0.12, rng, 2500, 5200) * env_exp(n_of(0.12), 0.05) * 0.7
    whump = lowpass(noise(n_of(0.9), rng, "pink"), 700) * env_adsr(n_of(0.9), 0.06, 0.15, 0.4, 0.6) * 2.2
    crackle = paper_crinkle(1.3, rng, 26, 1800) * 0.35 * env_exp(n_of(1.3), 0.5)
    return place(n, (strike, 0.0), (whump, 0.07), (crackle, 0.12), (bell(midi_hz(62), 1.3) * 0.32, 0.1), (bell(midi_hz(69), 1.1) * 0.16, 0.1))


def tie(rng):
    """A rope drawn out and pulled taut: rising creak of fibres, then a low twang and a knock."""
    n = n_of(1.3)
    draw_n = n_of(0.5)
    t = np.arange(draw_n) / RATE
    creak = sweep_bandpass(noise(draw_n, rng, "pink"), 500, 1600, q=4.0, steps=24)
    creak *= (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 23 * t))) * np.clip(t / 0.4, 0, 1) * 1.2
    twang_n = n_of(0.8)
    tt = np.arange(twang_n) / RATE
    twang = pluck(midi_hz(45), 0.8, rng, 0.7, 0.995)
    hum = sine(midi_hz(45) * (1 + 0.04 * np.exp(-tt / 0.05)), twang_n) * env_exp(twang_n, 0.25) * 0.4
    knock = wood(330, 0.15, rng) * 0.5
    return place(n, (creak, 0.0), (twang * 0.9 + hum, 0.48), (knock, 0.48))


def verse_wake(rng):
    """A verse-stone waking: a low stone hum rising into the vale's first notes on bells."""
    from synth import pad
    n = n_of(2.8)
    hum = pad([midi_hz(m) for m in (38, 45)], 2.8, rng, attack=0.5, release=1.6, bright=0.2) * 0.6
    grit = lowpass(noise(n_of(0.8), rng), 300) * env_adsr(n_of(0.8), 0.2, 0.2, 0.5, 0.4) * 0.8
    bells = place(n, *[(bell(midi_hz(m), 1.8) * g, 0.45 + i * 0.22) for i, (m, g) in enumerate([(69, 0.35), (71, 0.3), (74, 0.38), (81, 0.2)])])
    air = flute(midi_hz(74), 1.6, rng, breath=0.5, attack=0.5, release=0.8) * 0.12
    return place(n, (hum, 0.0), (grit, 0.0), (bells, 0.0), (air, 0.7))


def talk_open(rng):
    """The talk panel opening: a sheet of paper turned, a soft wood tap."""
    n = n_of(0.45)
    turn = whoosh(0.3, rng, 1800, 4200, q=1.4, shape=(0.4, 1.2)) * 0.5 + paper_crinkle(0.3, rng, 60, 4500) * 0.4
    return place(n, (turn, 0.0), (wood(700, 0.12, rng) * 0.45, 0.2), (bell(midi_hz(81), 0.25) * 0.12, 0.21))


def talk_next(rng):
    """Next line: a quiet, soft wooden blip."""
    n = n_of(0.12)
    return place(n, (wood(980, 0.1, rng) * 0.8, 0.0), (sine(midi_hz(86), n) * env_exp(n, 0.03) * 0.15, 0.0))


def pickup(rng):
    """Taking a keepsake: two plucked notes up and a bell."""
    n = n_of(0.9)
    return place(n, (pluck(midi_hz(74), 0.6, rng, 0.6, 0.996) * 0.6, 0.0), (pluck(midi_hz(81), 0.7, rng, 0.6, 0.996) * 0.6, 0.08),
                 (bell(midi_hz(86), 0.75) * 0.35, 0.12), (paper_crinkle(0.2, rng, 50, 5000) * 0.25, 0.0))


def bead(rng):
    """A level's colour remembered: the vale theme's first notes rung bright over a warm swell."""
    from synth import pad
    n = n_of(2.6)
    notes = [69, 71, 74, 78, 81]
    run = place(n, *[(pluck(midi_hz(m), 1.4, rng, 0.75, 0.997) * 0.45, i * 0.085) for i, m in enumerate(notes)])
    ring = place(n, *[(bell(midi_hz(m), 2.0) * g, 0.42 + i * 0.03) for i, (m, g) in enumerate([(86, 0.4), (93, 0.25), (98, 0.12)])])
    swell = pad([midi_hz(m) for m in (50, 62, 66, 69)], 2.4, rng, attack=0.35, release=1.4, bright=0.5) * 0.35
    sparkle = place(n, *[(bell(midi_hz(rng.choice([93, 95, 98, 100, 102])), 0.35) * rng.uniform(0.05, 0.12), 0.5 + rng.uniform(0, 0.9)) for _ in range(10)])
    return run + ring + place(n, (swell, 0.3)) + sparkle


def splash(rng):
    """Thrown back out of deep water: a plunge, a gush up and bubbles settling."""
    n = n_of(1.1)
    plunge = lowpass(noise(n_of(0.5), rng, "pink"), 900) * env_exp(n_of(0.5), 0.12, 0.004) * 2.0
    gush = whoosh(0.6, rng, 600, 3200, q=1.2, shape=(0.3, 1.0)) * 0.8
    spray = bandpass(noise(n_of(0.5), rng), 2500, 9000) * env_exp(n_of(0.5), 0.15, 0.01) * 0.4
    bubbles = place(n, *[(drip(rng.uniform(450, 1300), rng) * rng.uniform(0.15, 0.4), rng.uniform(0.15, 0.95)) for _ in range(12)])
    return place(n, (plunge, 0.0), (gush, 0.05), (spray, 0.08), (bubbles, 0.0))


def curse_throwback(rng):
    """Shoved back off cursed ground: a dull thud, a sour sag and ink hissing off."""
    n = n_of(1.0)
    thud = drum(60, 0.6, rng, 0.8) * 0.9
    sour = place(n_of(0.8), (pluck(midi_hz(50), 0.8, rng, 0.3, 0.993) * 0.45, 0.0), (pluck(midi_hz(51), 0.8, rng, 0.3, 0.993) * 0.4, 0.01))
    t = np.arange(len(sour)) / RATE
    sour *= np.exp(-t / 0.3)
    hiss = whoosh(0.8, rng, 2400, 600, q=1.5, shape=(0.1, 1.5)) * 0.5
    return place(n, (thud, 0.0), (sour, 0.03), (hiss, 0.05))


def fight_seal(rng):
    """The ring rising round a sealed fight: a low drum, an upward sweep and a held sour fifth."""
    from synth import pad
    n = n_of(2.2)
    boom = drum(50, 1.2, rng, 0.7) * 0.9
    rise = whoosh(1.1, rng, 250, 2600, q=2.2, shape=(0.85, 0.6)) * 0.7
    sour = pad([midi_hz(m) for m in (38, 44, 50)], 2.0, rng, attack=0.4, release=1.0, bright=0.4) * 0.5
    cords = reed_cracks(0.8, rng, 4) * 0.35
    return place(n, (boom, 0.0), (rise, 0.0), (sour, 0.15), (cords, 0.9))


def fight_won(rng):
    """The ring falling: a falling sweep and the vale's chord rung out, resolved."""
    from synth import pad
    n = n_of(2.6)
    fall = whoosh(0.9, rng, 2600, 400, q=2.0, shape=(0.2, 1.4)) * 0.5
    chord = pad([midi_hz(m) for m in (50, 57, 62, 66)], 2.4, rng, attack=0.3, release=1.4, bright=0.5) * 0.55
    bells = place(n, *[(bell(midi_hz(m), 1.6) * 0.3, 0.25 + i * 0.13) for i, m in enumerate([74, 78, 81, 86])])
    return place(n, (fall, 0.0), (chord, 0.2), (bells, 0.0))


def unravel(rng):
    """An enemy coming apart over about 1.5 s: threads snapping and falling away, sliding down."""
    n = n_of(1.55)
    snaps = place(n, *[(pluck(midi_hz(76 - i * 2.2 + rng.uniform(-0.5, 0.5)), 0.35, rng, 0.8, 0.99) * (0.5 - i * 0.025), 0.03 + i * 0.105 + rng.uniform(0, 0.03))
                       for i in range(12)])
    slide = sweep_bandpass(noise(n, rng, "pink"), 2600, 300, q=3.0, steps=40) * env_adsr(n, 0.15, 0.3, 0.7, 0.6) * 0.6
    grains = paper_crinkle(1.5, rng, 45, 2600) * 0.3 * np.linspace(0.3, 1.0, n_of(1.5)) ** 2 * env_exp(n_of(1.5), 1.0)
    return snaps + slide + place(n, (grains, 0.0))


def clean_cut(rng):
    """The finishing stroke landing: one clean, bright cut and a ring."""
    n = n_of(0.9)
    cut = whoosh(0.16, rng, 8000, 2500, q=3.0, shape=(0.1, 1.8)) * 1.3
    tear = paper_crinkle(0.18, rng, 140, 4000) * 0.6
    thump = drum(110, 0.25, rng, 0.3) * 0.5
    return place(n, (cut, 0.0), (tear, 0.02), (thump, 0.04), (bell(midi_hz(90), 0.8) * 0.4, 0.05), (bell(midi_hz(97), 0.6) * 0.15, 0.05))


def raft(rng):
    """A pole raft pushing off: the pole knocks the bottom, the deck creaks, water slaps and runs."""
    n = n_of(1.9)
    creak_n = n_of(0.45)
    t = np.arange(creak_n) / RATE
    creak = bandpass(noise(creak_n, rng), 300, 900) * (0.4 + 0.6 * (np.sin(2 * np.pi * 17 * t) > 0.6)) * env_adsr(creak_n, 0.1, 0.1, 0.6, 0.2) * 0.8
    slap = lowpass(noise(n_of(0.35), rng, "pink"), 1200) * env_exp(n_of(0.35), 0.08, 0.005) * 1.4
    run = whoosh(1.4, rng, 500, 1400, q=1.4, shape=(0.3, 1.0)) * 0.45
    drips = place(n, *[(drip(rng.uniform(600, 1200), rng) * rng.uniform(0.1, 0.25), rng.uniform(0.6, 1.7)) for _ in range(6)])
    return place(n, (wood(180, 0.25, rng) * 0.7, 0.0), (drum(80, 0.3, rng, 0.6) * 0.4, 0.0), (creak, 0.15), (slap, 0.3), (run, 0.35), (drips, 0.0))


def lamp_hum(rng):
    """A lit lamp, looped: a soft flame flutter and a faint warm tone. Exactly periodic (2 s)."""
    n = n_of(2.0)
    t = np.arange(n) / RATE
    tone = sine(110.0, n) * 0.25 + sine(220.0, n, 0.7) * 0.08 + sine(330.0, n, 1.3) * 0.03
    flutter = 0.75 + 0.15 * np.sin(2 * np.pi * 3.0 * t) + 0.1 * np.sin(2 * np.pi * 7.5 * t + 1.0)
    roar = lowpass(noise(n * 2, rng, "pink"), 500)
    w = np.linspace(0, 1, n)
    roar = roar[:n] * w + roar[n:] * (1 - w)
    roar = np.roll(roar, n // 2)
    roar /= np.abs(roar).max() + 1e-9
    ticks = np.zeros(n)
    for _ in range(5):
        at = int(rng.uniform(0, n - 600))
        ticks[at:at + 300] += highpass(noise(300, rng), 3000) * np.exp(-np.arange(300) / 60.0) * rng.uniform(0.1, 0.25)
    return tone + roar * flutter * 0.9 + ticks


SOUNDS = {
    "footstep": (footstep, -9.0), "jump": (jump, -6.0), "land": (land, -6.0), "swipe": (swipe, -4.0),
    "hit": (hit_full, -3.0), "hurt": (hurt, -3.0), "splotchet_hop": (splotchet_hop, -8.0),
    "splotchet_die": (splotchet_die, -3.0), "reedwraith_moan": (reedwraith_moan, -6.0),
    "reedwraith_die": (reedwraith_die, -3.0), "veil_off": (veil_off, -3.0), "brush_open": (brush_open, -5.0),
    "brush_close": (brush_close, -6.0), "brush_stroke": (brush_stroke, -9.0), "glyph_ok": (glyph_ok, -4.0),
    "glyph_fail": (glyph_fail, -5.0), "bloom": (bloom, -3.0), "slash": (slash, -3.0), "gust": (gust, -3.0),
    "thorns_cut": (thorns_cut, -3.0), "soot_clear": (soot_clear, -3.0), "zone_restore": (zone_restore, -2.0),
    "petals": (petals, -6.0), "tree_restore": (tree_restore, -1.5), "ink_pickup": (ink_pickup, -6.0),
    "ui_move": (ui_move, -10.0), "ui_accept": (ui_accept, -6.0),
    "kindle": (kindle, -4.0), "tie": (tie, -4.0), "verse_wake": (verse_wake, -3.0), "talk_open": (talk_open, -8.0),
    "talk_next": (talk_next, -14.0), "pickup": (pickup, -5.0), "bead": (bead, -2.0), "splash": (splash, -4.0),
    "curse_throwback": (curse_throwback, -4.0), "fight_seal": (fight_seal, -3.0), "fight_won": (fight_won, -3.0),
    "unravel": (unravel, -4.0), "clean_cut": (clean_cut, -2.5), "raft": (raft, -5.0), "lamp_hum": (lamp_hum, -12.0),
}
## Sounds the game loops: rendered exactly periodic, no fades.
LOOPS = ("lamp_hum",)


def main(out_dir, report_path=None):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    report = {}
    for i, (name, (fn, peak_db)) in enumerate(SOUNDS.items()):
        rng = np.random.default_rng(1000 + i)
        x = np.asarray(fn(rng), dtype=float)
        x = x - np.mean(x)
        if name not in LOOPS:
            x = fade(x, 0.001, 0.02)
        x = normalize(x, peak_db)
        path = out / ("%s.ogg" % name)
        write_ogg(path, x)
        back, _ = sf.read(str(path))
        peak, rms = levels(back)
        report[name] = {"file": "audio/sfx/%s.ogg" % name, "seconds": round(len(back) / RATE, 3), "peak_db": round(peak, 1),
                        "rms_db": round(rms, 1), "bytes": path.stat().st_size, "clipped": bool(np.abs(back).max() >= 0.999)}
        print("SFX %-16s %5.2fs peak %6.1f dBFS rms %6.1f dBFS %6d bytes" % (name, len(back) / RATE, peak, rms, path.stat().st_size))
    if report_path:
        Path(report_path).write_text(json.dumps(report, indent=1))
    return report


if __name__ == "__main__":
    main(*sys.argv[1:3])
