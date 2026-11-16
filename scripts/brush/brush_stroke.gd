class_name BrushStroke
extends RefCounted
## Stroke geometry shared by the brush view, the glyph card, the ink pot, inject_stroke and
## the recognition tests: input cleaning, centripetal Catmull-Rom smoothing and resampling,
## width shaping (speed, pressure, taper) and the triangle arrays an ink stroke is drawn with.
## Lengths are in viewport pixels; "H" below is the viewport height (720 at the base size).

## Raw input closer than this (fraction of H) to the previous kept point is dropped (jitter).
const MIN_RAW_SPACING := 0.003
## Spacing of the smoothed samples (fraction of H).
const SAMPLE_SPACING := 0.004
## Width at slow speed and at fast speed (fraction of H).
const WIDTH_SLOW := 0.026
const WIDTH_FAST := 0.0075
## Speeds (H per second) that map to WIDTH_SLOW and WIDTH_FAST.
const SPEED_SLOW := 0.6
const SPEED_FAST := 2.6
## Speeds (H per second) over which the edge turns from wet to dry.
const DRY_FROM := 1.1
const DRY_TO := 3.0
## Pen pressure scales width between these factors (pressure 0 and 1).
const PRESSURE_MIN := 0.3
const PRESSURE_MAX := 1.3
## Start taper length and the end taper length range, slow to fast (fraction of H).
const TAPER_START := 0.03
const TAPER_END_SLOW := 0.04
const TAPER_END_FAST := 0.1
## Taper at the live tip while the brush is still down (fraction of H).
const TAPER_LIVE := 0.012


## Width (px) and dryness (0..1) for a speed in px/s and a pen pressure (negative: no pen).
static func width_for(speed_px: float, pressure: float, height: float) -> Vector2:
	var v := speed_px / maxf(height, 1.0)
	var w := lerpf(WIDTH_SLOW, WIDTH_FAST, smoothstep(SPEED_SLOW, SPEED_FAST, v)) * height
	var dry := smoothstep(DRY_FROM, DRY_TO, v)
	if pressure >= 0.0:
		var p := clampf(pressure, 0.0, 1.0)
		w *= lerpf(PRESSURE_MIN, PRESSURE_MAX, p)
		dry = clampf(dry + (1.0 - p) * 0.35, 0.0, 1.0)
	return Vector2(w, dry)


## Drops points closer than min_spacing to the last kept point. Always keeps the last point.
static func clean(raw: PackedVector2Array, min_spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in raw:
		if out.is_empty() or out[out.size() - 1].distance_to(p) >= min_spacing:
			out.append(p)
	if raw.size() > 1 and out[out.size() - 1] != raw[raw.size() - 1]:
		if out.size() > 1:
			out[out.size() - 1] = raw[raw.size() - 1]
		else:
			out.append(raw[raw.size() - 1])
	return out


## Samples the centripetal Catmull-Rom spline through pts at roughly spacing px.
## Returns the samples; out_pos, when given, receives each sample's position between input
## points as a float (k + fraction), for interpolating per-point attributes.
static func smooth(pts: PackedVector2Array, spacing: float, out_pos: PackedFloat32Array = PackedFloat32Array()) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	if n == 0:
		return out
	for k in range(n - 1):
		segment(pts, k, spacing, out, out_pos)
	out.append(pts[n - 1])
	out_pos.append(float(n - 1))
	return out


## Linear interpolation of per-point values at the positions smooth() reported.
static func interpolate(values: PackedFloat32Array, positions: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(positions.size())
	var last := values.size() - 1
	for i in positions.size():
		var k := mini(int(positions[i]), last)
		out[i] = lerpf(values[k], values[mini(k + 1, last)], positions[i] - float(k))
	return out


## Appends the samples of spline segment k: from pts[k] up to, not including, pts[k + 1].
## The segment only depends on pts[k - 1 .. k + 2], so it is final once pts[k + 2] exists.
static func segment(pts: PackedVector2Array, k: int, spacing: float, out: PackedVector2Array, out_pos: PackedFloat32Array) -> void:
	var n := pts.size()
	var p1 := pts[k]
	var p2 := pts[k + 1]
	var p0 := pts[k - 1] if k > 0 else p1 * 2.0 - p2
	var p3 := pts[k + 2] if k + 2 < n else p2 * 2.0 - p1
	var seg := p1.distance_to(p2)
	var steps := maxi(1, ceili(seg / maxf(spacing, 0.5)))
	var t0 := 0.0
	var t1 := t0 + maxf(sqrt(p0.distance_to(p1)), 1e-3)
	var t2 := t1 + maxf(sqrt(seg), 1e-3)
	var t3 := t2 + maxf(sqrt(p2.distance_to(p3)), 1e-3)
	for s in steps:
		var f := float(s) / float(steps)
		var t := lerpf(t1, t2, f)
		var a1 := p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
		var a2 := p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
		var a3 := p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
		var b1 := a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
		var b2 := a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
		out.append(b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1)))
		out_pos.append(float(k) + f)


## The input pipeline every stroke goes through before recognition: clean, then smooth.
static func prepare(raw: PackedVector2Array, height: float) -> PackedVector2Array:
	return smooth(clean(raw, MIN_RAW_SPACING * height), SAMPLE_SPACING * height)


static func path_length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


## n points spaced evenly along the path.
static func resample(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty():
		return out
	out.append(pts[0])
	var interval := path_length(pts) / float(n - 1)
	if interval > 0.0:
		var acc := 0.0
		var prev := pts[0]
		var i := 1
		while i < pts.size() and out.size() < n:
			var cur := pts[i]
			var d := prev.distance_to(cur)
			if acc + d >= interval and d > 0.0:
				var q := prev + (cur - prev) * ((interval - acc) / d)
				out.append(q)
				prev = q
				acc = 0.0
			else:
				acc += d
				prev = cur
				i += 1
	while out.size() < n:
		out.append(pts[pts.size() - 1])
	return out


## Taper factor at arc length s on a stroke of length total. A length of 0 disables that end.
static func taper(s: float, total: float, start_len: float, end_len: float) -> float:
	var f := 1.0
	if start_len > 0.0:
		f *= pow(clampf(s / start_len, 0.0, 1.0), 0.55)
	if end_len > 0.0:
		f *= pow(clampf((total - s) / end_len, 0.0, 1.0), 0.7)
	return f


## Appends two vertices per sample for samples [from, to), and the two triangles joining each
## sample to the previous one when the previous sample is already in the arrays. widths are
## final widths in px, dry 0..1. UV.x is arc length in px, UV.y runs -1..1 across the stroke.
## Colour carries (dry, width / 64 px, 0, 1) to the ink stroke shader.
static func append_geometry(pts: PackedVector2Array, widths: PackedFloat32Array, dry: PackedFloat32Array, arclen: PackedFloat32Array,
		from: int, to: int, verts: PackedVector2Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var n := pts.size()
	for i in range(from, to):
		var tangent := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tangent.length_squared() < 1e-8:
			tangent = Vector2.RIGHT
		var normal := tangent.normalized().orthogonal()
		var half := widths[i] * 0.5
		var base := verts.size()
		verts.append(pts[i] + normal * half)
		verts.append(pts[i] - normal * half)
		uvs.append(Vector2(arclen[i], -1.0))
		uvs.append(Vector2(arclen[i], 1.0))
		var c := Color(dry[i], minf(widths[i] / 64.0, 1.0), 0.0, 1.0)
		colors.append(c)
		colors.append(c)
		if base >= 2:
			indices.append_array([base - 2, base - 1, base, base - 1, base + 1, base])


static func arc_lengths(pts: PackedVector2Array) -> PackedFloat32Array:
	var arclen := PackedFloat32Array()
	arclen.resize(pts.size())
	var total := 0.0
	for i in pts.size():
		if i > 0:
			total += pts[i - 1].distance_to(pts[i])
		arclen[i] = total
	return arclen


## Builds a whole finished stroke at once. Returns verts, uvs, colors and indices for
## draw_geometry().
static func build(pts: PackedVector2Array, base_widths: PackedFloat32Array, dry: PackedFloat32Array, start_len: float, end_len: float) -> Dictionary:
	var n := pts.size()
	var arclen := arc_lengths(pts)
	var total := arclen[n - 1] if n > 0 else 0.0
	var widths := PackedFloat32Array()
	widths.resize(n)
	for i in n:
		widths[i] = base_widths[i] * taper(arclen[i], total, start_len, end_len)
	var g := {"verts": PackedVector2Array(), "uvs": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}
	append_geometry(pts, widths, dry, arclen, 0, n, g["verts"], g["uvs"], g["colors"], g["indices"])
	return g


## A finished stroke from plain points drawn at one speed (px/s): smoothed, width and dryness
## from that speed, tapered at both ends. height is the reference height for the constants.
static func build_simple(raw: PackedVector2Array, height: float, speed_px: float, width_scale: float = 1.0) -> Dictionary:
	var pts := prepare(raw, height)
	var wd := width_for(speed_px, -1.0, height)
	var widths := PackedFloat32Array()
	var dry := PackedFloat32Array()
	widths.resize(pts.size())
	dry.resize(pts.size())
	widths.fill(wd.x * width_scale)
	dry.fill(wd.y)
	return build(pts, widths, dry, TAPER_START * height, lerpf(TAPER_END_SLOW, TAPER_END_FAST, wd.y) * height)


## A dab: the brush pressed down at a slant leaves a short teardrop of wet ink, width across.
static func dab(centre: Vector2, width: float) -> Dictionary:
	var dir := Vector2(0.89, 0.45)
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(centre + dir * width * lerpf(-0.45, 0.45, float(k) / 8.0))
	var widths := PackedFloat32Array()
	var dry := PackedFloat32Array()
	widths.resize(9)
	dry.resize(9)
	widths.fill(width)
	dry.fill(0.0)
	return build(pts, widths, dry, width * 0.3, width * 0.55)


## Draws stroke geometry into a CanvasItem; call from its _draw(). The item's material (the
## ink stroke shader) does the ink look.
static func draw_geometry(item: CanvasItem, g: Dictionary) -> void:
	var indices: PackedInt32Array = g["indices"]
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), indices, g["verts"], g["colors"], g["uvs"])
