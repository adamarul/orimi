"""Cut the captured shots into the trailer, add the music bed, mix, encode and check.

Reads tools/trailer/cut.json (the edit: shot segments in order, times in seconds from each shot's
TRAILER_IN mark, and the music bed) and the clips and logs in .userdata/trailer/clips/ written by
tools/trailer/capture_all.sh. Writes:
    build/trailer/orimi_trailer_x_1080p.mp4             picture, game sound effects and music
    build/trailer/orimi_trailer_x_1080p_music_only.mp4  same picture, music only
    build/trailer/orimi_trailer_x_720p.mp4              fallback copy of the first at 1280x720
    build/trailer/report.txt                            ffprobe facts, loudness, silence, cut checks
    docs/trailer/contact_sheet.jpg                      one frame per second of the 1080p cut
    python -I tools/trailer/edit.py <ffmpeg dir> <checkout root>
"""
import json
import os
import re
import subprocess
import sys

FPS = 60
TARGET_LUFS = -14.0
# AAC encoding adds about 0.5 dB of inter-sample overshoot, so the PCM mix is limited lower
# than the -1 dBTP the delivered file must stay under.
TARGET_TP = -2.0


def run(cmd, capture=False):
    r = subprocess.run(cmd, stdout=subprocess.PIPE if capture else None, stderr=subprocess.PIPE, text=True,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-4000:])
        raise SystemExit("command failed: %s" % " ".join(cmd[:6]))
    return (r.stdout or "") + (r.stderr or "")


def mark_frames(log_path):
    text = open(log_path, encoding="utf-8", errors="replace").read()
    marks = dict((m.group(1), int(m.group(2))) for m in re.finditer(r"^TRAILER_(IN|OUT) frame=(\d+)", text, re.M))
    if "IN" not in marks or "OUT" not in marks:
        raise SystemExit("no TRAILER_IN/OUT marks in %s" % log_path)
    return marks["IN"], marks["OUT"]


def check_file(ffmpeg, ffprobe, dst, root):
    """ffprobe facts, loudness, true peak and silences of one delivered file, as report lines."""
    lines = []
    probe = json.loads(run([ffprobe, "-v", "error", "-show_entries",
                            "stream=codec_name,profile,pix_fmt,width,height,r_frame_rate,avg_frame_rate,sample_rate,channels,bit_rate:format=duration,size,bit_rate",
                            "-of", "json", dst], capture=True))
    loud = run([ffmpeg, "-hide_banner", "-nostats", "-i", dst, "-af", "ebur128=peak=true", "-f", "null", "-"])
    summary = loud[loud.rfind("Summary:"):]
    i_val = re.search(r"I:\s+(-?[\d.]+) LUFS", summary)
    tp_val = re.search(r"Peak:\s+(-?[\d.]+) dBFS", summary)
    lra_val = re.search(r"LRA:\s+(-?[\d.]+) LU", summary)
    sil = run([ffmpeg, "-hide_banner", "-nostats", "-i", dst, "-af", "silencedetect=noise=-50dB:d=1", "-f", "null", "-"])
    silences = re.findall(r"silence_start: (-?[\d.]+)", sil)
    st = run([ffmpeg, "-hide_banner", "-nostats", "-i", dst, "-af", "astats=measure_overall=Peak_level+Number_of_samples:measure_perchannel=none", "-f", "null", "-"])
    peak = re.findall(r"Peak level dB: (-?[\d.inf]+)", st)
    clipped = run([ffmpeg, "-hide_banner", "-nostats", "-i", dst, "-af",
                   "astats=measure_overall=none:measure_perchannel=none,volumedetect", "-f", "null", "-"])
    maxv = re.search(r"max_volume: (-?[\d.]+) dB", clipped)
    lines.append("== %s" % os.path.relpath(dst, root).replace("\\", "/"))
    fmt = probe["format"]
    lines.append("file size %.1f MB, duration %.3f s, overall %.2f Mbps" % (
        int(fmt["size"]) / 1e6, float(fmt["duration"]), int(fmt["bit_rate"]) / 1e6))
    for s in probe["streams"]:
        if s.get("width"):
            lines.append("video %s %s %s %dx%d %s fps, %.2f Mbps" % (s["codec_name"], s.get("profile"), s["pix_fmt"],
                         s["width"], s["height"], s["avg_frame_rate"], int(s.get("bit_rate", 0)) / 1e6))
        else:
            lines.append("audio %s %s Hz %d ch, %d kbps" % (s["codec_name"], s["sample_rate"], s["channels"],
                                                            int(s.get("bit_rate", 0)) / 1000))
    lines.append("integrated %s LUFS, true peak %s dBTP, LRA %s LU, sample peak %s dBFS (volumedetect max %s dB)" % (
        i_val.group(1) if i_val else "?", tp_val.group(1) if tp_val else "?", lra_val.group(1) if lra_val else "?",
        peak[-1] if peak else "?", maxv.group(1) if maxv else "?"))
    lines.append("silences of 1 s or more below -50 dBFS: %d %s" % (len(silences), silences))
    return lines


def main():
    ff_dir, root = sys.argv[1], sys.argv[2]
    ffmpeg = os.path.join(ff_dir, "ffmpeg.exe")
    ffprobe = os.path.join(ff_dir, "ffprobe.exe")
    cut = json.load(open(os.path.join(root, "tools", "trailer", "cut.json"), encoding="utf-8"))
    clips = os.path.join(root, ".userdata", "trailer", "clips")
    work = os.path.join(root, ".userdata", "trailer", "edit")
    out_dir = os.path.join(root, "build", "trailer")
    os.makedirs(work, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    paper = cut.get("paper_color", "0xEFE6D2")

    # 1. Each segment to an intermediate with the same format (near-lossless H.264 + PCM).
    parts = []
    timeline = []
    t = 0.0
    for i, seg in enumerate(cut["segments"]):
        shot = seg["shot"]
        f_in, f_out = mark_frames(os.path.join(clips, shot + ".log"))
        a = f_in + int(round(float(seg["in"]) * FPS))
        b = f_in + int(round(float(seg["out"]) * FPS))
        if b > f_out + 1:
            raise SystemExit("segment %d (%s) runs past the shot's TRAILER_OUT" % (i, shot))
        n = b - a
        dur = n / FPS
        vf = ["trim=start_frame=%d:end_frame=%d" % (a, b), "setpts=PTS-STARTPTS"]
        if seg.get("crop"):
            # [x, y, w, h] of the 1920x1080 frame, scaled back up: frames a shot lower when the
            # game's own camera leaves too much sky in it.
            x, y, w, h = seg["crop"]
            vf.append("crop=%d:%d:%d:%d,scale=1920:1080:flags=lanczos" % (w, h, x, y))
        if seg.get("fade_in"):
            vf.append("fade=t=in:st=0:d=%.3f:color=%s" % (float(seg["fade_in"]), paper))
        if seg.get("fade_out"):
            d = float(seg["fade_out"])
            vf.append("fade=t=out:st=%.3f:d=%.3f:color=%s" % (dur - d, d, paper))
        # Movie Maker writes full-range MJPEG; convert to the TV range every player expects.
        vf.append("scale=in_range=full:out_range=tv,format=yuv420p")
        gain = float(seg.get("sfx_db", 0.0))
        af = ["atrim=start=%.6f:end=%.6f" % (a / FPS, b / FPS), "asetpts=PTS-STARTPTS",
              "volume=%.2fdB" % gain, "afade=t=in:d=0.015", "afade=t=out:st=%.4f:d=0.03" % (dur - 0.03)]
        if seg.get("mute"):
            af.append("volume=0")
        part = os.path.join(work, "part_%02d.mkv" % i)
        run([ffmpeg, "-v", "error", "-y", "-i", os.path.join(clips, shot + ".avi"),
             "-vf", ",".join(vf), "-af", ",".join(af), "-r", str(FPS),
             "-c:v", "libx264", "-preset", "veryfast", "-crf", "10", "-color_range", "tv", "-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2",
             part])
        parts.append(part)
        timeline.append({"shot": shot, "start": round(t, 3), "length": round(dur, 3), "note": seg.get("note", "")})
        t += dur
    total = t

    # 2. Join the picture and the game sound.
    lst = os.path.join(work, "parts.txt")
    with open(lst, "w", encoding="utf-8") as f:
        for p in parts:
            f.write("file '%s'\n" % p.replace("\\", "/"))
    joined = os.path.join(work, "joined.mkv")
    run([ffmpeg, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined])

    # 3. Music bed: one track from its start offset, faded out at the end.
    m = cut["music"]
    fade = float(m.get("fade_out", 2.5))
    music_f = ["atrim=start=%.3f:end=%.3f" % (float(m.get("start", 0.0)), float(m.get("start", 0.0)) + total),
               "asetpts=PTS-STARTPTS", "aresample=48000", "aformat=channel_layouts=stereo",
               "afade=t=in:d=%.3f" % float(m.get("fade_in", 0.05)),
               "afade=t=out:st=%.3f:d=%.3f" % (total - fade, fade), "volume=%.2fdB" % float(m.get("gain_db", 0.0))]
    music_wav = os.path.join(work, "music.wav")
    run([ffmpeg, "-v", "error", "-y", "-i", os.path.join(root, m["file"]), "-af", ",".join(music_f), "-c:a", "pcm_s16le", music_wav])
    sfx_wav = os.path.join(work, "sfx.wav")
    run([ffmpeg, "-v", "error", "-y", "-i", joined, "-vn", "-af", "volume=%.2fdB" % float(cut.get("sfx_gain_db", 0.0)),
         "-c:a", "pcm_s16le", sfx_wav])
    mix_raw = os.path.join(work, "mix_raw.wav")
    run([ffmpeg, "-v", "error", "-y", "-i", music_wav, "-i", sfx_wav,
         "-filter_complex", "[0:a][1:a]amix=inputs=2:normalize=0:duration=first[a]", "-map", "[a]", "-c:a", "pcm_s16le", mix_raw])

    def normalise(src, dst):
        first = run([ffmpeg, "-hide_banner", "-i", src, "-af",
                     "loudnorm=I=%.1f:TP=%.1f:LRA=11:print_format=json" % (TARGET_LUFS, TARGET_TP), "-f", "null", "-"])
        js = json.loads(first[first.rfind("{"):first.rfind("}") + 1])
        run([ffmpeg, "-v", "error", "-y", "-i", src, "-af",
             ("loudnorm=I=%.1f:TP=%.1f:LRA=11:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:"
              "offset=%s:linear=true,aresample=48000") % (TARGET_LUFS, TARGET_TP, js["input_i"], js["input_tp"],
                                                          js["input_lra"], js["input_thresh"], js["target_offset"]),
             "-ar", "48000", "-c:a", "pcm_s16le", dst])

    mix = os.path.join(work, "mix.wav")
    music_only = os.path.join(work, "music_only.wav")
    normalise(mix_raw, mix)
    normalise(music_wav, music_only)

    # 4. Encode the deliverables.
    final = os.path.join(out_dir, "orimi_trailer_x_1080p.mp4")
    final_music = os.path.join(out_dir, "orimi_trailer_x_1080p_music_only.mp4")
    final_720 = os.path.join(out_dir, "orimi_trailer_x_720p.mp4")
    common_v = ["-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p", "-color_range", "tv", "-preset", "slow", "-r", str(FPS),
                "-g", "120", "-bf", "2", "-tune", "film"]
    common_a = ["-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart"]
    for audio, dst, size, rate in [(mix, final, None, "12M"), (music_only, final_music, None, "12M"),
                                   (mix, final_720, "1280:720", "5M")]:
        vf = ["scale=%s:flags=lanczos" % size] if size else []
        vf.append("format=yuv420p")
        bufsize = "%dM" % (int(rate[:-1]) * 2)
        maxrate = "%dM" % (int(rate[:-1]) * 13 // 10)
        run([ffmpeg, "-v", "error", "-y", "-i", joined, "-i", audio, "-map", "0:v", "-map", "1:a", "-vf", ",".join(vf)]
            + common_v + ["-b:v", rate, "-maxrate", maxrate, "-bufsize", bufsize] + common_a + ["-shortest", dst])

    # 5. Checks.
    lines = []
    for dst in [final, final_music, final_720]:
        lines += check_file(ffmpeg, ffprobe, dst, root)
    lines.append("== cut (%d segments, %.2f s)" % (len(timeline), total))
    short = [x for x in timeline if x["length"] < 0.6]
    lines.append("segments under 0.6 s: %d" % len(short))
    for x in timeline:
        lines.append("%7.2f  %5.2f  %-14s %s" % (x["start"], x["length"], x["shot"], x["note"]))
    report = os.path.join(out_dir, "report.txt")
    open(report, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    json.dump(timeline, open(os.path.join(out_dir, "timeline.json"), "w", encoding="utf-8"), indent=1)

    # 6. Contact sheet: one frame per second, small enough to keep under docs/.
    cols = 8
    rows = (int(total) + cols) // cols
    sheet = os.path.join(root, "docs", "trailer", "contact_sheet.jpg")
    os.makedirs(os.path.dirname(sheet), exist_ok=True)
    run([ffmpeg, "-v", "error", "-y", "-i", final, "-vf",
         "fps=1,scale=320:180,tile=%dx%d:padding=4:color=white" % (cols, rows), "-frames:v", "1", "-q:v", "5", sheet])
    print("\n".join(lines))
    print("contact sheet: docs/trailer/contact_sheet.jpg")


if __name__ == "__main__":
    main()
