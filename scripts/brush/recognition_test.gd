extends Node
## Recognition test: generates noisy strokes of each glyph and of non-glyphs at several sizes,
## drawing speeds and input rates, runs them through the same pipeline as live input
## (BrushStroke.prepare, then BrushGlyphs.recognise with the press time and the tie posts on
## screen) and prints a confusion table. Every stroke has two tie posts somewhere on screen;
## for Tie strokes they sit at the stroke's ends.
## Run: tools/brush/test_recognition.sh (headless). Deterministic (fixed seed).

const GLYPH_COUNT := 300
const OTHER_COUNT := 40
const H := 720.0
const RATES := [30.0, 60.0, 144.0]
const SPEEDS := {"slow": 0.5, "medium": 1.5, "fast": 3.0}
const COLUMNS := ["bloom", "slash", "gust", "kindle", "tie", "rejected"]
const OTHERS := ["scribble", "zigzag", "open_arc", "vertical", "diagonal", "spiral", "figure8", "double_loop", "square", "triangle", "check", "wave",
	"long_press", "slash_start", "tiny_loop", "tie_one_end", "tie_curved", "tie_overshoot", "gust_long_tails"]

var rng := RandomNumberGenerator.new()
## The posts placed beside every stroke draw from their own generator, so the strokes themselves
## are the same sequence as before the posts existed and the old rows stay comparable.
var post_rng := RandomNumberGenerator.new()
var _duration := 0.0
var _posts: Array = []
var _pointer := ""
## The measurements the dab thresholds are set from, per class: {name: {"size": [], "length": [], "time": []}}.
var _dab_measure := {}
const DAB_CLASSES := ["kindle", "long_press", "slash_start", "tiny_loop"]


func _ready() -> void:
	rng.seed = 20261114
	post_rng.seed = 20261115
	var start := Time.get_ticks_msec()
	var rows: Array = []
	var by_speed := {}
	for g: StringName in BrushGlyphs.GLYPHS:
		rows.append(_run(String(g), GLYPH_COUNT, by_speed))
	for o in OTHERS:
		rows.append(_run(o, OTHER_COUNT, by_speed))
	var ms := Time.get_ticks_msec() - start
	print("BRUSH_TEST confusion table (rows: what was drawn; columns: what the recogniser said)")
	print("")
	print("| drawn | n | " + " | ".join(COLUMNS) + " | correct |")
	print("| - | - | - | - | - | - | - | - | - |")
	var total := 0
	var correct := 0
	for row: Dictionary in rows:
		var ok: int = row["ok"]
		total += row["n"]
		correct += ok
		var cells: PackedStringArray = []
		for col in COLUMNS:
			cells.append(str(row["counts"][col]))
		print("| %s | %d | %s | %.1f%% |" % [row["name"], row["n"], " | ".join(cells), 100.0 * ok / row["n"]])
	print("")
	print("BRUSH_TEST overall %d / %d correct (%.1f%%), %d strokes in %d ms (%.2f ms per stroke)" % [correct, total, 100.0 * correct / total, total, ms, float(ms) / total])
	print("")
	print("Accuracy of the drawn glyphs (bloom, slash, gust, tie) by drawing speed and input rate:")
	print("")
	var drawn := ["bloom", "slash", "gust", "tie"]
	print("| speed | rate | " + " | ".join(drawn) + " |")
	print("| - | - | - | - | - | - |")
	var keys := by_speed.keys()
	keys.sort()
	for k: String in keys:
		var cells: PackedStringArray = []
		for g in drawn:
			var c: Array = by_speed[k].get(g, [0, 0])
			cells.append("%d / %d" % c)
		print("| %s | %s Hz | %s |" % [k.get_slice("@", 0), k.get_slice("@", 1), " | ".join(cells)])
	print("")
	print("Dab measurements (%%H for size and length, seconds for time): min / median / max. A dab must be within\nsize %.1f %%H, length %.1f %%H (re-cleaned at %.1f %%H) and %.1f s." % [BrushGlyphs.DAB_MAX_SIZE * 100.0, BrushGlyphs.DAB_MAX_LENGTH * 100.0, BrushGlyphs.DAB_SPACING * 100.0, BrushGlyphs.DAB_MAX_TIME])
	print("")
	print("| class | n | bounding box | path length | press time |")
	print("| - | - | - | - | - |")
	var classes := _dab_measure.keys()
	classes.sort()
	for k: String in classes:
		var m: Dictionary = _dab_measure[k]
		print("| %s | %d | %s | %s | %s |" % [k, (m["size"] as Array).size(), _spread(m["size"], 100.0, "%.2f"), _spread(m["length"], 100.0, "%.2f"), _spread(m["time"], 1.0, "%.2f")])
	print("")
	print("Most common reasons for wrong answers:")
	for row: Dictionary in rows:
		var reasons: Dictionary = row["reasons"]
		if reasons.is_empty():
			continue
		var items := reasons.keys()
		items.sort_custom(func(a, b): return reasons[a] > reasons[b])
		var parts: PackedStringArray = []
		for r in items.slice(0, 4):
			parts.append("%s x%d" % [r, reasons[r]])
		print("- %s: %s" % [row["name"], ", ".join(parts)])
	print("BRUSH_TEST_DONE")
	get_tree().quit(0)


func _run(name: String, count: int, by_speed: Dictionary) -> Dictionary:
	var expect := name if name in COLUMNS else "gust" if name == "gust_long_tails" else "rejected"
	var ok := 0
	var counts := {}
	for col in COLUMNS:
		counts[col] = 0
	var reasons := {}
	for i in count:
		var speed_name: String = SPEEDS.keys()[i % SPEEDS.size()]
		var rate: float = RATES[(i / SPEEDS.size()) % RATES.size()]
		_posts = _random_posts()
		var raw: PackedVector2Array
		if name == "kindle" or name == "long_press":
			raw = _tap(name == "long_press")
			speed_name = "tap"
		else:
			raw = _sample(_shape(name), SPEEDS[speed_name] * H, rate)
		var prepared := BrushStroke.prepare(raw, H)
		if name in DAB_CLASSES:
			var key := name + (" (" + _pointer + ")" if name in ["kindle", "long_press"] else "")
			var m: Dictionary = _dab_measure.get_or_add(key, {"size": [], "length": [], "time": []})
			var rect := Rect2(prepared[0], Vector2.ZERO)
			for q in prepared:
				rect = rect.expand(q)
			m["size"].append(maxf(rect.size.x, rect.size.y) / H)
			m["length"].append(BrushStroke.path_length(BrushStroke.clean(prepared, BrushGlyphs.DAB_SPACING * H)) / H)
			m["time"].append(_duration)
		var res := BrushGlyphs.recognise(prepared, H, _duration, _posts)
		var got: String = String(res["glyph"]) if res["glyph"] != &"" else "rejected"
		counts[got] += 1
		if name.begins_with("tie_"):
			# Not a Tie, so it must be judged exactly as if there were no posts.
			var plain := BrushGlyphs.recognise(prepared, H, _duration, [])
			expect = String(plain["glyph"]) if plain["glyph"] != &"" else "rejected"
		if got == expect:
			ok += 1
		if name in COLUMNS and name != "kindle":
			var key := "%s@%03d" % [speed_name, int(rate)]
			var cell: Array = by_speed.get_or_add(key, {}).get_or_add(name, [0, 0])
			cell[1] += 1
			if got == expect:
				cell[0] += 1
		if got != expect:
			var why: String = (String(res["reason"]) + " " + String(res["detail"])) if got == "rejected" else "accepted as " + got
			if OS.get_environment("BRUSH_TEST_VERBOSE") != "":
				print("MISS %s %s@%d (%d events, %.2f s) -> %s %s %s gates: %s" % [name, speed_name, rate, raw.size(), _duration, got, res["detail"], JSON.stringify(res["scores"]), JSON.stringify(res["gates"])])
			why = why.split("(")[0].strip_edges()
			reasons[why] = reasons.get(why, 0) + 1
	return {"name": name, "n": count, "ok": ok, "counts": counts, "reasons": reasons}


func _spread(values: Array, scale: float, fmt: String) -> String:
	var v := values.duplicate()
	v.sort()
	return "%s / %s / %s" % [fmt % (v[0] * scale), fmt % (v[v.size() / 2] * scale), fmt % (v[v.size() - 1] * scale)]


## Two tie posts at random places on screen, projected radius 8 to 30 px.
func _random_posts() -> Array:
	var out: Array = []
	for k in 2:
		out.append({"pos": Vector2(post_rng.randf_range(60, 1220), post_rng.randf_range(60, 660)), "radius": post_rng.randf_range(8.0, 30.0)})
	return out


## A press with almost no travel. Mouse (40 %): one to four events within 3 px, 0.05 to 0.25 s.
## Pen (60 %): the tip slips up to 1.2 %H while it lands, sampled at 120 to 240 Hz with 0.7 px
## of jitter, 0.05 to 0.5 s. A long press is the same held 1 to 2 s.
func _tap(long: bool) -> PackedVector2Array:
	var centre := Vector2(rng.randf_range(200, 1080), rng.randf_range(150, 570))
	var out := PackedVector2Array([centre])
	_pointer = "mouse" if rng.randf() < 0.4 else "pen"
	if _pointer == "mouse":
		_duration = rng.randf_range(0.05, 0.25)
		for k in rng.randi_range(0, 3):
			out.append(centre + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)))
	else:
		_duration = rng.randf_range(0.05, 0.5)
		var slip := Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(0.0, 0.012 * H)
		var n := maxi(2, int(_duration * rng.randf_range(120.0, 240.0)))
		for k in n:
			var t := minf(1.0, float(k) / float(n) * 4.0)
			out.append(centre + slip * t + Vector2(rng.randfn(0.0, 0.7), rng.randfn(0.0, 0.7)))
	if long:
		_duration = rng.randf_range(1.0, 2.0)
	return out


## A straight stroke from near post a to near post b (within the post's radius plus 28 px).
func _post_line(bow: float, land_b: bool) -> PackedVector2Array:
	var length := rng.randf_range(0.1, 0.6) * H
	var a := Vector2(rng.randf_range(150, 1130), rng.randf_range(120, 600))
	var dir := Vector2.from_angle(rng.randf_range(0, TAU))
	var b := a + dir * length
	b = b.clamp(Vector2(20, 20), Vector2(1260, 700))
	_posts = [{"pos": a, "radius": rng.randf_range(8.0, 30.0)}, {"pos": b, "radius": rng.randf_range(8.0, 30.0)}]
	var start := a + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(0.0, _posts[0]["radius"] + 28.0)
	var end := b + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(0.0, _posts[1]["radius"] + 28.0)
	if not land_b:
		# The far post is moved well off the line's end.
		_posts[1]["pos"] = end + Vector2.from_angle(rng.randf_range(0, TAU)) * (_posts[1]["radius"] + 40.0 + rng.randf_range(40.0, 200.0))
	var pts := PackedVector2Array()
	var normal := (end - start).normalized().orthogonal()
	var span := start.distance_to(end)
	for k in 120:
		var t := float(k) / 119.0
		pts.append(start.lerp(end, t) + normal * bow * span * 0.5 * (1.0 - pow(2.0 * t - 1.0, 2.0)))
	return pts


## A noisy shape in viewport pixels, dense, in drawing order.
func _shape(name: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var size := rng.randf_range(0.09, 0.3) * H
	var rot := rng.randf_range(0.0, TAU)
	match name:
		"bloom":
			pts = BrushGlyphs.ideal(&"bloom", 200, {"turns": rng.randf_range(0.9, 1.12), "start": rng.randf_range(0.0, TAU), "ccw": rng.randf() < 0.5})
			pts = _stretch(pts, rng.randf_range(0.75, 1.25))
		"slash":
			size = rng.randf_range(0.1, 0.35) * H
			pts = BrushGlyphs.ideal(&"slash", 200, {"bow": rng.randf_range(-0.1, 0.1), "reverse": rng.randf() < 0.5})
			rot = deg_to_rad(rng.randf_range(-20.0, 20.0))
		"gust", "gust_long_tails":
			var tail := 1.3 if name == "gust" else rng.randf_range(1.5, 2.0)
			pts = BrushGlyphs.ideal(&"gust", 240, {"loop": rng.randf_range(1.6, 3.0), "tail": tail, "mirror": rng.randf() < 0.5, "reverse": rng.randf() < 0.5})
			pts = _trim(pts, rng.randf_range(0.0, 0.15), rng.randf_range(0.0, 0.15))
		"tie":
			return _jitter_line(_post_line(rng.randf_range(-0.06, 0.06), true))
		"tie_curved":
			# Bowed by 18 to 25 % of the span: an arc, not a line.
			return _jitter_line(_post_line(rng.randf_range(0.36, 0.5) * (1 if rng.randf() < 0.5 else -1), true))
		"tie_one_end", "tie_overshoot":
			# A steep line (so it cannot be a Slash) that starts on a post and ends off any post.
			var line := _post_line(0.0, false)
			var d := line[line.size() - 1] - line[0]
			var steep := Vector2.from_angle(deg_to_rad(rng.randf_range(40.0, 90.0)) * (1 if rng.randf() < 0.5 else -1)) * maxf(d.length(), 0.3 * H)
			if rng.randf() < 0.5:
				steep.x = -steep.x
			var far := line[0] + steep
			var r_b: float = _posts[1]["radius"]
			if name == "tie_overshoot":
				# Passes over the second post and carries on well beyond its reach.
				_posts[1]["pos"] = far - steep.normalized() * (r_b + 40.0 + rng.randf_range(30.0, 120.0))
			else:
				_posts[1]["pos"] = far + Vector2.from_angle(rng.randf_range(0, TAU)) * (r_b + 40.0 + rng.randf_range(40.0, 200.0))
			var out := PackedVector2Array()
			for k in 120:
				out.append(line[0] + steep * float(k) / 119.0)
			return _jitter_line(out)
		"slash_start":
			size = rng.randf_range(0.02, 0.05) * H
			pts = BrushGlyphs.ideal(&"slash", 60)
			rot = deg_to_rad(rng.randf_range(-20.0, 20.0))
		"tiny_loop":
			size = rng.randf_range(0.006, 0.02) * H
			pts = BrushGlyphs.ideal(&"bloom", 60, {"start": rng.randf_range(0.0, TAU)})
		"scribble":
			var p := Vector2.ZERO
			var heading := rng.randf_range(0, TAU)
			for i in rng.randi_range(8, 14):
				heading += rng.randf_range(-2.6, 2.6)
				p += Vector2.from_angle(heading) * rng.randf_range(0.4, 1.0)
				pts.append(p)
			pts = _normalise(BrushStroke.smooth(pts, 0.02))
		"zigzag":
			var k := rng.randi_range(4, 7)
			for i in k:
				pts.append(Vector2(float(i) / (k - 1) * 2.0 - 1.0, 0.6 * (1 if i % 2 == 0 else -1)))
			pts = _polyline(pts)
			rot = deg_to_rad(rng.randf_range(-25.0, 25.0))
		"open_arc":
			pts = BrushGlyphs.ideal(&"bloom", 200, {"turns": rng.randf_range(0.45, 0.72), "start": rng.randf_range(0.0, TAU), "ccw": rng.randf() < 0.5})
		"vertical":
			pts = BrushGlyphs.ideal(&"slash", 200, {"bow": rng.randf_range(-0.08, 0.08), "reverse": rng.randf() < 0.5})
			rot = deg_to_rad(90.0 + rng.randf_range(-30.0, 30.0))
		"diagonal":
			pts = BrushGlyphs.ideal(&"slash", 200, {"bow": rng.randf_range(-0.08, 0.08), "reverse": rng.randf() < 0.5})
			rot = deg_to_rad(rng.randf_range(40.0, 58.0) * (1 if rng.randf() < 0.5 else -1))
		"spiral":
			var turns := rng.randf_range(1.6, 2.4)
			for i in 300:
				var t := float(i) / 299.0
				pts.append(Vector2.from_angle(t * turns * TAU) * (1.0 - 0.55 * t))
		"figure8":
			var off := rng.randf_range(0.0, TAU)
			var squash := rng.randf_range(0.95, 1.05)
			for i in 300:
				var t := off + float(i) / 299.0 * TAU
				pts.append(Vector2(sin(t), sin(t) * cos(t) * squash))
		"double_loop":
			var d := rng.randf_range(1.8, 2.8)
			for i in 300:
				var t := lerpf(-PI, 3.0 * PI, float(i) / 299.0)
				pts.append(Vector2(t - d * sin(t), -d * cos(t)))
			pts = _normalise(pts)
		"square", "triangle":
			var k := 4 if name == "square" else 3
			var a0 := rng.randf_range(0, TAU)
			for i in k + 1:
				pts.append(Vector2.from_angle(a0 + TAU * i / k))
			pts = _polyline(pts)
		"check":
			pts = _polyline(PackedVector2Array([Vector2(-1, -0.2), Vector2(-0.3, 0.6), Vector2(1, -0.8)]))
			rot = deg_to_rad(rng.randf_range(-30.0, 30.0))
		"wave":
			var periods := rng.randf_range(1.0, 1.8)
			for i in 200:
				var t := float(i) / 199.0
				pts.append(Vector2(t * 2.0 - 1.0, 0.35 * sin(t * periods * TAU)))
			rot = deg_to_rad(rng.randf_range(-20.0, 20.0))
	return _wobble(pts, size, rot)


## Hand wobble for strokes already placed in screen space.
func _jitter_line(pts: PackedVector2Array) -> PackedVector2Array:
	var amp := rng.randf_range(0.5, 3.0)
	var f1 := rng.randf_range(1.0, 3.0)
	var ph := rng.randf_range(0, TAU)
	var n := pts.size()
	var normal := (pts[n - 1] - pts[0]).normalized().orthogonal()
	for i in n:
		pts[i] += normal * amp * sin(TAU * f1 * float(i) / float(n - 1) + ph)
	return pts


func _stretch(pts: PackedVector2Array, aspect: float) -> PackedVector2Array:
	for i in pts.size():
		pts[i].y *= aspect
	return pts


func _trim(pts: PackedVector2Array, head: float, tail: float) -> PackedVector2Array:
	var n := pts.size()
	return pts.slice(int(head * n), n - int(tail * n))


func _normalise(pts: PackedVector2Array) -> PackedVector2Array:
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	var s := 2.0 / maxf(rect.size.x, rect.size.y)
	var c := rect.get_center()
	for i in pts.size():
		pts[i] = (pts[i] - c) * s
	return pts


func _polyline(corners: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in corners.size() - 1:
		for k in 30:
			out.append(corners[i].lerp(corners[i + 1], k / 30.0))
	out.append(corners[corners.size() - 1])
	return out


## Scales to size px, rotates, adds a hand wobble (low-frequency sideways drift) and places it
## near the screen centre.
func _wobble(pts: PackedVector2Array, size: float, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var amp := rng.randf_range(0.01, 0.05) * size
	var f1 := rng.randf_range(1.0, 3.0)
	var f2 := rng.randf_range(4.0, 8.0)
	var ph := rng.randf_range(0, TAU)
	var centre := Vector2(640, 360) + Vector2(rng.randf_range(-200, 200), rng.randf_range(-80, 80))
	var n := pts.size()
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		var tangent := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var normal := tangent.normalized().orthogonal() if tangent.length() > 0 else Vector2.ZERO
		var off := amp * (sin(TAU * f1 * t + ph) + 0.4 * sin(TAU * f2 * t + ph * 2.0))
		out.append(centre + (pts[i] * size).rotated(rot) + normal * off)
	return out


## Samples the shape the way input events arrive: at rate Hz along a speed profile that eases
## in and out, with 0.7 px of sensor jitter.
func _sample(pts: PackedVector2Array, mean_speed: float, rate: float) -> PackedVector2Array:
	var arclen := BrushStroke.arc_lengths(pts)
	var total := arclen[arclen.size() - 1]
	var duration := maxf(total / (mean_speed * rng.randf_range(0.8, 1.25)), 0.12)
	_duration = duration
	var steps := maxi(2, int(duration * rate))
	var out := PackedVector2Array()
	var k := 0
	for s in steps + 1:
		var u := float(s) / float(steps)
		var target := (u * u * (3.0 - 2.0 * u) * 0.6 + u * 0.4) * total
		while k < arclen.size() - 2 and arclen[k + 1] < target:
			k += 1
		var seg := maxf(arclen[k + 1] - arclen[k], 1e-6)
		var p := pts[k].lerp(pts[k + 1], clampf((target - arclen[k]) / seg, 0.0, 1.0))
		out.append(p + Vector2(rng.randfn(0.0, 0.7), rng.randfn(0.0, 0.7)))
	return out
