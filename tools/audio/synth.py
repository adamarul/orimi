"""Small offline synthesis toolkit for the game's sound effects and music (numpy + scipy).

Everything here renders to float arrays at RATE; nothing runs at game time (the web build
cannot synthesise audio), so reverb and filtering are baked into the files.
"""
import numpy as np
from scipy import signal

RATE = 44100


def t_axis(seconds):
    return np.arange(int(round(seconds * RATE))) / RATE


def env_adsr(n, a, d, s, r, hold=None):
    """Attack/decay/sustain/release envelope over n samples (times in seconds)."""
    a_n, d_n, r_n = int(a * RATE), int(d * RATE), int(r * RATE)
    hold_n = n - a_n - d_n - r_n if hold is None else int(hold * RATE)
    hold_n = max(0, hold_n)
    e = np.concatenate([np.linspace(0, 1, max(a_n, 1), endpoint=False), np.linspace(1, s, max(d_n, 1), endpoint=False),
                        np.full(hold_n, s), np.linspace(s, 0, max(r_n, 1))])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def env_exp(n, decay, attack=0.002):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / max(attack, 1e-5)) * np.exp(-t / decay)


def noise(n, rng, color="white"):
    x = rng.standard_normal(n)
    if color == "pink":
        b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
        x = signal.lfilter(b, a, x) * 3.0
    elif color == "brown":
        x = np.cumsum(x)
        x = signal.lfilter([1, -1], [1, -0.995], x) * 0.05
    return x


def bandpass(x, lo, hi, order=2):
    lo = max(20.0, lo)
    hi = min(RATE / 2 * 0.95, hi)
    sos = signal.butter(order, [lo, hi], btype="band", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, f, order=2):
    sos = signal.butter(order, min(f, RATE / 2 * 0.95), btype="low", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, f, order=2):
    sos = signal.butter(order, max(f, 20), btype="high", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def sweep_bandpass(x, f0, f1, q=3.0, steps=48):
    """Band-pass whose centre glides from f0 to f1 (log), applied block by block with crossfades."""
    n = len(x)
    out = np.zeros(n)
    edges = np.linspace(0, n, steps + 1).astype(int)
    win_pad = 256
    for i in range(steps):
        a, b = edges[i], edges[i + 1]
        fc = f0 * (f1 / f0) ** ((i + 0.5) / steps)
        lo, hi = fc / (1 + 1 / q), fc * (1 + 1 / q)
        s = max(0, a - win_pad)
        e = min(n, b + win_pad)
        y = bandpass(x[s:e], lo, hi)
        w = np.ones(e - s)
        ramp = min(win_pad, a - s)
        if ramp > 0:
            w[:ramp] = np.linspace(0, 1, ramp)
        ramp2 = min(win_pad, e - b)
        if ramp2 > 0:
            w[-ramp2:] = np.linspace(1, 0, ramp2)
        out[s:e] += y * w
    return out


def sine(freq, n, phase=0.0):
    """freq may be a scalar or an array (glide)."""
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * np.arange(n) / RATE + phase)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE + phase)


def pluck(freq, seconds, rng, brightness=0.5, decay=0.996, pick=0.12):
    """Karplus-Strong plucked string, computed one period at a time."""
    n = int(seconds * RATE)
    period = max(2, int(round(RATE / freq)))
    buf = rng.uniform(-1, 1, period)
    # pick position comb softens the attack like a finger near the bridge
    shift = max(1, int(period * pick))
    buf = buf - np.roll(buf, shift) * 0.5
    buf = lowpass(np.tile(buf, 3), 1500 + 9000 * brightness)[-period:]
    out = np.empty(n + period)
    out[:period] = buf
    pos = period
    while pos < n + period:
        prev = out[pos - period:pos]
        nxt = np.empty(period)
        nxt[0] = decay * 0.5 * (prev[0] + out[pos - period - 1] if pos - period - 1 >= 0 else prev[0])
        nxt[1:] = decay * 0.5 * (prev[1:] + prev[:-1])
        take = min(period, n + period - pos)
        out[pos:pos + take] = nxt[:take]
        pos += take
    y = out[:n]
    y -= y.mean()
    return y / (np.abs(y).max() + 1e-9)


def flute(freq, seconds, rng, breath=0.18, vibrato=0.006, attack=0.09, release=0.25):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    vib_on = np.clip((t - 0.25) / 0.4, 0, 1)
    f = freq * (1 + vibrato * vib_on * np.sin(2 * np.pi * 5.2 * t + rng.random() * 6))
    tone = sine(f, n) + 0.22 * sine(f * 2, n, 0.3) + 0.08 * sine(f * 3, n, 1.1) + 0.03 * sine(f * 4, n, 2.0)
    br = bandpass(noise(n, rng), freq * 0.8, freq * 3.5) * breath * (0.6 + 0.4 * np.exp(-t / 0.15))
    y = (tone + br * 4.0) * env_adsr(n, attack, 0.1, 0.85, min(release, seconds * 0.4))
    return y / (np.abs(y).max() + 1e-9)


def bell(freq, seconds, partials=((1.0, 1.0, 1.0), (2.76, 0.45, 0.55), (5.4, 0.25, 0.35), (8.93, 0.12, 0.2), (0.5, 0.3, 1.4))):
    """Soft bell from inharmonic partials: (ratio, amplitude, decay factor)."""
    n = int(seconds * RATE)
    y = np.zeros(n)
    for ratio, amp, dec in partials:
        y += amp * sine(freq * ratio, n, ratio) * env_exp(n, seconds * 0.35 * dec, 0.003)
    return y / (np.abs(y).max() + 1e-9)


def wood(freq, seconds, rng):
    n = int(seconds * RATE)
    y = sine(freq, n) * env_exp(n, 0.035) + 0.5 * sine(freq * 2.3, n) * env_exp(n, 0.018)
    y += bandpass(noise(n, rng), 1500, 6000) * env_exp(n, 0.006) * 0.6
    return y / (np.abs(y).max() + 1e-9)


def drum(freq, seconds, rng, thump=0.4):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    f = freq * (1 + 1.5 * np.exp(-t / 0.03))
    y = sine(f, n) * env_exp(n, seconds * 0.3, 0.002)
    y += lowpass(noise(n, rng), 900) * env_exp(n, 0.04) * thump
    return y / (np.abs(y).max() + 1e-9)


def pad(freqs, seconds, rng, attack=1.2, release=1.5, bright=0.35):
    """Soft bowed-string pad: detuned harmonic stacks, low-passed."""
    n = int(seconds * RATE)
    y = np.zeros(n)
    for f in freqs:
        for det in (-0.004, 0.0, 0.0045):
            ff = f * (1 + det)
            ph = rng.random() * 6.28
            for h in range(1, 7):
                y += (1.0 / h ** 1.3) * sine(ff * h, n, ph * h)
    y = lowpass(y, 600 + 3000 * bright)
    y *= env_adsr(n, attack, 0.3, 0.9, release)
    return y / (np.abs(y).max() + 1e-9)


def reverb_ir(seconds, rng, damp=0.5, stereo=True):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    chans = []
    for c in range(2 if stereo else 1):
        x = rng.standard_normal(n) * np.exp(-t * 6.9 / seconds)
        x = lowpass(x, 9000 * (1 - damp) + 1200)
        x[: int(0.012 * RATE)] *= np.linspace(0, 1, int(0.012 * RATE))
        chans.append(x / np.sqrt(np.sum(x ** 2)))
    return np.stack(chans, axis=1)


def apply_reverb(x, ir, wet=0.25):
    """x: (n,) or (n, 2). Returns (n + len(ir) - 1, channels) with the dry signal plus the tail."""
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    out = np.zeros((len(x) + len(ir) - 1, 2))
    for c in range(2):
        out[:, c] = signal.fftconvolve(x[:, c], ir[:, c % ir.shape[1]]) * wet
        out[: len(x), c] += x[:, c] * (1 - wet * 0.5)
    return out


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def normalize(x, peak_db=-1.0):
    peak = np.abs(x).max() + 1e-12
    return x * (10 ** (peak_db / 20.0) / peak)


def levels(x):
    """Peak and RMS in dBFS (RMS over the whole file, all channels)."""
    peak = 20 * np.log10(np.abs(x).max() + 1e-12)
    rms = 20 * np.log10(np.sqrt(np.mean(np.square(x))) + 1e-12)
    return peak, rms


def fade(x, fin=0.002, fout=0.01):
    n = len(x)
    a, b = int(fin * RATE), int(fout * RATE)
    env = np.ones(n)
    if a:
        env[:a] = np.linspace(0, 1, a)
    if b:
        env[-b:] = np.minimum(env[-b:], np.linspace(1, 0, b))
    return x * (env[:, None] if x.ndim == 2 else env)


def write_ogg(path, x, quality=None):
    """Write OGG Vorbis in small blocks: one large write overflows the encoder's stack on Windows.
    quality: None for the library default, else libsndfile's compression level (0 best .. 1 smallest)."""
    import soundfile as sf
    x = np.asarray(x, dtype=np.float32)
    channels = 1 if x.ndim == 1 else x.shape[1]
    kw = {} if quality is None else {"compression_level": quality}
    with sf.SoundFile(str(path), "w", RATE, channels, format="OGG", subtype="VORBIS", **kw) as f:
        for i in range(0, len(x), 4096):
            f.write(x[i:i + 4096])
