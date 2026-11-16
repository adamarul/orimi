"""Image statistics for the visual checks. Prints one JSON object with "pass" and "summary".

    python -I tools/qa/imgstats.py sepia <before.png> <during.png> <after.png>
    python -I tools/qa/imgstats.py paper <light.png> <normal.png> <heavy.png>
    python -I tools/qa/imgstats.py selftest <out dir>      writes synthetic images and checks both
                                                           comparisons pass on good input and fail
                                                           on planted defects

sepia: "during" must differ clearly from "before" (mean absolute difference > 0.04), be a warm
monochrome (pixels with colour have a circular-mean hue between 15 and 60 degrees and a hue spread
under 30 degrees, and at least 70 % of pixels have r >= g >= b), and "after" must be closer to
"before" than "during" was (the view came back).

paper: the three captures must differ pairwise (mean absolute difference > 0.002), and move in the
direction docs/STYLE_GUIDE.md gives for Light < Normal < Heavy:
  tooth     high-frequency luminance energy (|L - 5x5 box blur|): Heavy > Normal and Heavy > Light
  vignette  centre luminance / corner luminance: Light < Normal < Heavy
  colour    mean saturation: Heavy < Normal
"""
import json
import os
import sys

import numpy as np
from PIL import Image


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0


def luminance(a):
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def box_blur(l, k=5):
    pad = k // 2
    p = np.pad(l, pad, mode="edge")
    c = np.cumsum(np.cumsum(p, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s / (k * k)


def saturation(a):
    mx, mn = a.max(-1), a.min(-1)
    return np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)


def hue_deg(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (np.degrees(np.arctan2(np.sqrt(3.0) * (g - b), 2 * r - g - b)) + 360.0) % 360.0


def sepia(before, during, after):
    b, d, a = load(before), load(during), load(after)
    diff_bd = float(np.abs(b - d).mean())
    diff_ba = float(np.abs(b - a).mean())
    sat = saturation(d)
    mask = (sat > 0.08) & (d.max(-1) > 0.1)
    if mask.sum() > 100:
        h = np.radians(hue_deg(d)[mask])
        c, s = np.cos(h).mean(), np.sin(h).mean()
        mean_hue = float((np.degrees(np.arctan2(s, c)) + 360) % 360)
        spread = float(np.degrees(np.sqrt(max(-2 * np.log(max(np.hypot(c, s), 1e-6)), 0))))
    else:
        mean_hue, spread = -1.0, 999.0
    warm = float(((d[..., 0] >= d[..., 1] - 0.01) & (d[..., 1] >= d[..., 2] - 0.01)).mean())
    checks = {
        "during differs from before": diff_bd > 0.04,
        "during is warm (hue 15-60)": 15 <= mean_hue <= 60,
        "during is monochrome (hue spread < 30)": spread < 30,
        "during r>=g>=b on 70% of pixels": warm >= 0.7,
        "after returns toward before": diff_ba < diff_bd,
    }
    return {"pass": all(checks.values()), "checks": checks,
            "values": {"diff_before_during": round(diff_bd, 4), "diff_before_after": round(diff_ba, 4), "mean_hue": round(mean_hue, 1),
                       "hue_spread": round(spread, 1), "warm_fraction": round(warm, 3),
                       "sat_before": round(float(saturation(b).mean()), 4), "sat_during": round(float(sat.mean()), 4)},
            "summary": "; ".join(("ok " if v else "NOT ") + k for k, v in checks.items())}


def paper_metrics(a):
    l = luminance(a)
    h, w = l.shape
    tooth = float(np.abs(l - box_blur(l)).mean())
    cy, cx = slice(int(h * 0.3), int(h * 0.7)), slice(int(w * 0.3), int(w * 0.7))
    ch, cw = int(h * 0.15), int(w * 0.15)
    corners = np.concatenate([l[:ch, :cw].ravel(), l[:ch, -cw:].ravel(), l[-ch:, :cw].ravel(), l[-ch:, -cw:].ravel()])
    vignette = float(l[cy, cx].mean() / max(corners.mean(), 1e-4))
    return {"tooth": round(tooth, 5), "vignette": round(vignette, 4), "saturation": round(float(saturation(a).mean()), 4)}


def paper(light, normal, heavy):
    imgs = [load(p) for p in (light, normal, heavy)]
    m = [paper_metrics(a) for a in imgs]
    d = [float(np.abs(imgs[i] - imgs[j]).mean()) for i, j in ((0, 1), (1, 2), (0, 2))]
    L, N, H = m
    checks = {
        "all three differ": min(d) > 0.002,
        "tooth Heavy > Normal": H["tooth"] > N["tooth"],
        "tooth Heavy > Light": H["tooth"] > L["tooth"],
        "vignette Light < Normal": L["vignette"] < N["vignette"],
        "vignette Normal < Heavy": N["vignette"] < H["vignette"],
        "saturation Heavy < Normal": H["saturation"] < N["saturation"],
    }
    return {"pass": all(checks.values()), "checks": checks, "metrics": {"light": L, "normal": N, "heavy": H},
            "pair_diffs": {"light-normal": round(d[0], 4), "normal-heavy": round(d[1], 4), "light-heavy": round(d[2], 4)},
            "summary": "; ".join(("ok " if v else "NOT ") + k for k, v in checks.items())}


def synth(strength, seed=3):
    rng = np.random.default_rng(seed)
    h, w = 360, 640
    y, x = np.mgrid[0:h, 0:w] / np.array([h, w])[:, None, None]
    base = np.stack([0.55 + 0.2 * x, 0.65 - 0.1 * y, 0.45 + 0.1 * np.sin(6 * x)], -1)
    base[100:220, 200:420] = [0.84, 0.25, 0.17]
    noise = rng.normal(0, 1, (h, w))
    tooth = box_blur(noise, 3) * 0.05 * strength
    r = np.hypot(x - 0.5, y - 0.5)
    vig = 1 - 0.5 * strength * np.clip(r - 0.25, 0, 1)
    grey = base.mean(-1, keepdims=True)
    img = base + (grey - base) * 0.4 * strength
    img = (img + tooth[..., None]) * vig[..., None]
    return np.clip(img, 0, 1)


def save(a, path):
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(path)


def selftest(out):
    os.makedirs(out, exist_ok=True)
    p = lambda n: os.path.join(out, n)
    save(synth(0.2), p("l.png")); save(synth(0.6), p("n.png")); save(synth(1.0), p("h.png"))
    good = paper(p("l.png"), p("n.png"), p("h.png"))
    same = paper(p("n.png"), p("n.png"), p("n.png"))
    reversed_ = paper(p("h.png"), p("n.png"), p("l.png"))
    scene = synth(0.0, seed=5)
    sep = luminance(scene)[..., None] * np.array([1.0, 0.78, 0.55]) * 0.9 + np.array([0.1, 0.07, 0.03])
    save(scene, p("before.png")); save(sep, p("during.png")); save(scene * 0.99, p("after.png"))
    s_good = sepia(p("before.png"), p("during.png"), p("after.png"))
    s_none = sepia(p("before.png"), p("before.png"), p("after.png"))
    grey = np.repeat(luminance(scene)[..., None] * 0.6, 3, -1)
    save(grey, p("grey.png"))
    s_grey = sepia(p("before.png"), p("grey.png"), p("after.png"))
    s_stuck = sepia(p("before.png"), p("during.png"), p("during.png"))
    cases = {"paper good passes": good["pass"], "paper identical fails": not same["pass"], "paper reversed fails": not reversed_["pass"],
             "sepia good passes": s_good["pass"], "sepia no change fails": not s_none["pass"], "sepia grey (not warm) fails": not s_grey["pass"],
             "sepia never resumes fails": not s_stuck["pass"]}
    return {"pass": all(cases.values()), "cases": cases, "summary": "; ".join(("ok " if v else "NOT ") + k for k, v in cases.items()),
            "detail": {"paper_good": good["summary"], "paper_reversed": reversed_["summary"], "sepia_good": s_good["summary"], "sepia_grey": s_grey["summary"]}}


def main():
    mode, args = sys.argv[1], sys.argv[2:]
    try:
        res = {"sepia": sepia, "paper": paper, "selftest": selftest}[mode](*args)
    except Exception as e:  # noqa: BLE001
        res = {"pass": False, "error": "%s: %s" % (type(e).__name__, e), "summary": "image statistics failed"}
    print(json.dumps(res))
    sys.exit(0 if res.get("pass") else 1)


if __name__ == "__main__":
    main()
