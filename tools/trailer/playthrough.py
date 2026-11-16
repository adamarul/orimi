"""Encode the unbroken playthrough filmed by tools/trailer/playthrough.sh.

The only edit is trimming the head and tail: the take runs from its TRAILER_IN mark (the title
screen is ready) to its TRAILER_OUT mark (a few seconds after the card that ends the level), with
no cuts, speed changes, cards or added music. The game's own sound is kept as it plays, only turned
down if its true peak would otherwise reach -1 dBTP after AAC encoding. Writes:
    build/trailer/orimi_<name>_1080p.mp4     H.264 High, about 8 Mbps, AAC 48 kHz stereo
    build/trailer/orimi_<name>_720p.mp4      the same at 1280x720, about 4 Mbps
    build/trailer/<name>_report.txt          ffprobe facts, loudness, the route's stages and casts
    docs/trailer/<name>_sheet.jpg            one frame every five seconds, eight to a row
    python -I tools/trailer/playthrough.py <ffmpeg dir> <checkout root> <name>
"""
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from edit import FPS, TARGET_TP, check_file, mark_frames, run  # noqa: E402


def main():
    ff_dir, root, name = sys.argv[1], sys.argv[2], sys.argv[3]
    ffmpeg = os.path.join(ff_dir, "ffmpeg.exe")
    ffprobe = os.path.join(ff_dir, "ffprobe.exe")
    clips = os.path.join(root, ".userdata", "trailer", "clips")
    src = os.path.join(clips, name + ".avi")
    log = os.path.join(clips, name + ".log")
    out_dir = os.path.join(root, "build", "trailer")
    os.makedirs(out_dir, exist_ok=True)
    f_in, f_out = mark_frames(log)
    end = f_out + 1
    duration = (end - f_in) / FPS
    trim_v = "trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS" % (f_in, end)
    trim_a = "atrim=start=%.6f:end=%.6f,asetpts=PTS-STARTPTS,aresample=48000" % (f_in / FPS, end / FPS)

    loud = run([ffmpeg, "-hide_banner", "-nostats", "-i", src, "-vn", "-af", trim_a + ",ebur128=peak=true", "-f", "null", "-"])
    summary = loud[loud.rfind("Summary:"):]
    tp = re.search(r"Peak:\s+(-?[\d.]+|-inf) dBFS", summary)
    source_tp = float(tp.group(1)) if tp and tp.group(1) != "-inf" else -99.0
    gain = min(0.0, TARGET_TP - source_tp)

    outputs = []
    for size, rate, label in [(None, 8, "1080p"), ("1280:720", 4, "720p")]:
        dst = os.path.join(out_dir, "orimi_%s_%s.mp4" % (name, label))
        vf = [trim_v]
        if size:
            vf.append("scale=%s:flags=lanczos" % size)
        # Movie Maker writes full-range MJPEG; convert to the TV range every player expects.
        vf.append("scale=in_range=full:out_range=tv,format=yuv420p")
        run([ffmpeg, "-v", "error", "-y", "-i", src, "-vf", ",".join(vf), "-af", trim_a + ",volume=%.2fdB" % gain,
             "-r", str(FPS), "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p", "-color_range", "tv",
             "-preset", "medium", "-g", "120", "-bf", "2", "-b:v", "%dM" % rate, "-maxrate", "%dM" % (rate * 13 // 10),
             "-bufsize", "%dM" % (rate * 2), "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
             "-movflags", "+faststart", dst])
        outputs.append(dst)

    lines = []
    for dst in outputs:
        lines += check_file(ffmpeg, ffprobe, dst, root)
    lines.append("== take: frames %d to %d of %s.avi, %.3f s; game sound turned %.2f dB (source true peak %.1f dBTP)"
                 % (f_in, f_out, name, duration, gain, source_tp))
    lines.append("== stages and casts (seconds into the video)")
    text = open(log, encoding="utf-8", errors="replace").read()
    for m in re.finditer(r"^TRAILER_(STAGE|CAST|FAIL) (.*)$", text, re.M):
        kind, rest = m.group(1), m.group(2).strip()
        t = re.search(r"\bt=(-?[\d.]+)|\"t\":(-?[\d.]+)", rest)
        at = float(t.group(1) or t.group(2)) if t else -1.0
        lines.append("%8.2f  %-5s %s" % (at, kind.lower(), rest))
    report = os.path.join(out_dir, name + "_report.txt")
    open(report, "w", encoding="utf-8").write("\n".join(lines) + "\n")

    cols = 8
    shots = int(duration // 5) + 1
    rows = (shots + cols - 1) // cols
    sheet = os.path.join(root, "docs", "trailer", name + "_sheet.jpg")
    os.makedirs(os.path.dirname(sheet), exist_ok=True)
    run([ffmpeg, "-v", "error", "-y", "-i", outputs[0], "-vf",
         "fps=1/5:round=down,scale=320:180,tile=%dx%d:padding=4:color=white" % (cols, rows), "-frames:v", "1", "-q:v", "5", sheet])
    print("\n".join(lines))
    print("contact sheet: %s" % os.path.relpath(sheet, root).replace("\\", "/"))


if __name__ == "__main__":
    main()
