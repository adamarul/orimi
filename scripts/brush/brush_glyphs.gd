class_name BrushGlyphs
extends RefCounted
## Glyph shapes and the stroke recogniser.
##
## Recognition is a $1 unistroke template matcher (Wobbrock, Wilson and Li, 2007, implemented
## here from the paper's description) plus geometric gates, because the template distance on its
## own cannot tell a vertical line from a horizontal one (the $1 rotation step removes the
## angle) or an open arc from a circle. A stroke is a glyph only when that glyph's gate passes
## AND its best template score reaches MIN_SCORE; anything else is rejected, never guessed.
## Two glyphs are decided before the templates: Kindle (a dab: almost no travel, a short press)
## and Tie (a straight line whose two ends land on two different tie posts).
## Input is the smoothed stroke (BrushStroke.prepare) in viewport pixels.

const GLYPHS: Array[StringName] = [&"bloom", &"slash", &"gust", &"kindle", &"tie"]
## The glyphs matched by shape templates.
const SHAPE_GLYPHS: Array[StringName] = [&"bloom", &"slash", &"gust"]
const NAMES := {&"bloom": "Bloom", &"slash": "Slash", &"gust": "Gust", &"kindle": "Kindle", &"tie": "Tie"}

# $1 parameters (paper defaults, except uniform scaling, see _normalise).
const N := 64
const SQUARE := 250.0
const ANGLE_RANGE := deg_to_rad(45.0)
const ANGLE_STEP := deg_to_rad(2.0)
const PHI := 0.6180339887

# Gates. Lengths are fractions of the viewport height H unless they say "of L" (path length).
const MIN_LENGTH := 0.06           # shorter is &"too_short"
const FEATURE_POINTS := 96         # resampled points the geometric features use
const MIN_SCORE := {&"bloom": 0.80, &"slash": 0.80, &"gust": 0.72}
const BLOOM_MIN_SIZE := 0.07       # bounding box, larger side
const BLOOM_MAX_GAP := 0.17        # end-to-start gap, of L
const BLOOM_MAX_TAILS := 0.2       # overshoot past the closing crossing, both ends together, of L
const BLOOM_TURN := Vector2(285.0, 470.0)  # total turning, degrees
const BLOOM_MAX_CV := 0.24         # radius spread (std / mean) about the centroid
const BLOOM_MAX_CORNER := 75.0     # most turning inside 1/12 of the path, degrees
const SLASH_MIN_LENGTH := 0.12
const SLASH_MIN_STRAIGHT := 0.86   # chord / L
const SLASH_MAX_ANGLE := 30.0      # degrees from horizontal, either direction
const GUST_MIN_SIZE := 0.08
const GUST_MIN_TAIL := 0.05        # each tail outside the crossing, of L
const GUST_MIN_TAILS := 0.2        # both tails together, of L
const GUST_MIN_LOOP := 0.22        # the part between the crossings, of L
const GUST_LOOP_TURN := 200.0      # turning inside the loop part, degrees
const GUST_MIN_TURN := 150.0       # total turning, degrees (rejects figure eights)
# Before the Gust template score (not the gate), each tail is cut to at most this many times the
# loop's length, so a loop with long or curling tails is scored on the loop and its near tails.
const GUST_MAX_TAIL := 1.0
# Kindle (a dab). The length is measured on the stroke re-cleaned at DAB_SPACING, so a pen held
# still and jittering for half a second does not add up length, while a small loop still does.
const DAB_SPACING := 0.01
const DAB_MAX_LENGTH := 0.03       # path length at DAB_SPACING
const DAB_MAX_SIZE := 0.025        # bounding box, larger side
const DAB_MAX_TIME := 0.8          # seconds the tip was down; longer is a hesitation, not a dab
# Tie. Ends must land within the post's projected radius plus this many pixels.
const TIE_MARGIN := 40.0
const TIE_MIN_LENGTH := 0.06
const TIE_MAX_BOW := 0.1           # furthest point from the chord, of the chord
const TIE_MIN_SCORE := 0.75        # $1 line score at any angle
const KNOT := 0.05                 # crossings closing a loop shorter than this (of L) are ignored
const MERGE := 0.04                # crossings closer than this along both branches are one (of L)

static var _templates: Array = []


## A canonical glyph shape, centred on the origin, about 2 units across, in screen axes
## (y down), in drawing order. Used for templates, glyph cards and test strokes.
## params: "aspect", "turns", "bow", "loop" (cycloid d/r), "tail" (cycloid half-range in pi),
## "mirror", "reverse", "start" (radians, circle start angle), "ccw".
static func ideal(glyph: StringName, n: int = 96, params: Dictionary = {}) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match glyph:
		&"bloom":
			var turns: float = params.get("turns", 1.0)
			var aspect: float = params.get("aspect", 1.0)
			var start: float = params.get("start", -PI * 0.5)
			var dir := -1.0 if params.get("ccw", true) else 1.0
			for i in n:
				var a := start + dir * TAU * turns * float(i) / float(n - 1)
				pts.append(Vector2(cos(a), sin(a) * aspect))
		&"slash":
			var bow: float = params.get("bow", 0.0)
			for i in n:
				var t := float(i) / float(n - 1) * 2.0 - 1.0
				pts.append(Vector2(t, -bow * (1.0 - t * t)))
		&"kindle":
			# A dab: the brush pressed down at a slant leaves a short teardrop.
			for i in n:
				pts.append(Vector2(-0.12, -0.06).lerp(Vector2(0.12, 0.06), float(i) / float(n - 1)))
		&"tie":
			for i in n:
				pts.append(Vector2(-1.0, 0.45).lerp(Vector2(1.0, -0.45), float(i) / float(n - 1)))
		&"gust":
			var d: float = params.get("loop", 2.2)
			var tail: float = params.get("tail", 1.0) * PI
			var raw := PackedVector2Array()
			for i in n:
				var t := lerpf(-tail, tail, float(i) / float(n - 1))
				raw.append(Vector2(t - d * sin(t), -d * cos(t)))
			var rect := _bounds(raw)
			var c := rect.get_center()
			var s := 2.0 / maxf(rect.size.x, rect.size.y)
			for p in raw:
				pts.append((p - c) * s)
	if params.get("mirror", false):
		for i in pts.size():
			pts[i].x = -pts[i].x
	if params.get("reverse", false):
		pts.reverse()
	return pts


## Recognises a smoothed stroke. Returns:
##   glyph: StringName (&"" when rejected), score: float 0..1, reason: &"" / &"too_short" /
##   &"unrecognised", detail: String (which gate failed), scores: {glyph: $1 score},
##   gates: {glyph: "" or failure}, features: Dictionary, tie: [start post, end post] indices
##   into posts when the glyph is Tie.
## height is the viewport height the stroke was drawn in (sizes are relative to it).
## duration is how long the tip was down in seconds (0 when unknown, as for injected strokes).
## posts are the tie posts on screen: [{"pos": Vector2, "radius": float px}, ...].
static func recognise(points: PackedVector2Array, height: float = 720.0, duration: float = 0.0, posts: Array = []) -> Dictionary:
	var result := {"glyph": &"", "score": 0.0, "reason": &"", "detail": "", "scores": {}, "gates": {}, "features": {}}
	var length := BrushStroke.path_length(points)
	if points.is_empty():
		result["reason"] = &"too_short"
		return result
	if is_dab(points, height):
		var extent := _bounds(points).size
		if duration > DAB_MAX_TIME:
			result["reason"] = &"unrecognised"
			result["detail"] = "closest kindle: held %.1f s" % duration
			return result
		result["glyph"] = &"kindle"
		result["score"] = 1.0 - 0.5 * maxf(extent.x, extent.y) / (DAB_MAX_SIZE * height)
		result["features"] = {"length": length / height, "size": maxf(extent.x, extent.y) / height, "duration": duration}
		return result
	if points.size() < 2 or length < MIN_LENGTH * height:
		result["reason"] = &"too_short"
		result["detail"] = "length %.0f px" % length
		return result
	var f := features(points, height)
	result["features"] = f
	var gates := {&"bloom": _gate_bloom(f), &"slash": _gate_slash(f), &"gust": _gate_gust(f)}
	result["gates"] = gates
	var norm := _normalise(BrushStroke.resample(points, N))
	var gust_points := _trim_tails(points, f)
	var gust_norm := norm if gust_points == points else _normalise(BrushStroke.resample(gust_points, N))
	if not posts.is_empty():
		var tie := _match_tie(points, f, height, posts)
		gates[&"tie"] = tie["gate"]
		if tie["gate"] == "":
			var line_score := _best_score(norm, &"slash")
			result["scores"][&"tie"] = snappedf(line_score, 0.001)
			if line_score >= TIE_MIN_SCORE:
				result["glyph"] = &"tie"
				result["score"] = line_score
				result["tie"] = tie["posts"]
				return result
	var best := &""
	var best_score := 0.0
	var best_any := &""
	var best_any_score := -1.0
	for g: StringName in SHAPE_GLYPHS:
		var score := _best_score(gust_norm if g == &"gust" else norm, g)
		result["scores"][g] = snappedf(score, 0.001)
		if score > best_any_score:
			best_any_score = score
			best_any = g
		if gates[g] == "" and score >= MIN_SCORE[g] and score > best_score:
			best_score = score
			best = g
	if best != &"":
		result["glyph"] = best
		result["score"] = best_score
		return result
	result["reason"] = &"unrecognised"
	result["score"] = best_any_score
	var failed: String = gates[best_any]
	if failed == "":
		failed = "score %.2f < %.2f" % [best_any_score, MIN_SCORE[best_any]]
	result["detail"] = "closest %s: %s" % [best_any, failed]
	return result


## Geometric features of a stroke (see docs/BRUSH.md).
static func features(points: PackedVector2Array, height: float) -> Dictionary:
	var p := BrushStroke.resample(points, FEATURE_POINTS)
	var n := p.size()
	var length := BrushStroke.path_length(points)
	var arclen := BrushStroke.arc_lengths(p)
	var rect := _bounds(p)
	var chord := p[0].distance_to(p[n - 1])
	var dv := p[n - 1] - p[0]
	var angle := absf(rad_to_deg(atan2(dv.y, dv.x)))
	if angle > 90.0:
		angle = 180.0 - angle
	# Turning: signed heading changes between successive segments.
	var turns := PackedFloat32Array()
	for i in range(1, n - 1):
		var a := (p[i] - p[i - 1]).angle()
		var b := (p[i + 1] - p[i]).angle()
		turns.append(rad_to_deg(wrapf(b - a, -PI, PI)))
	var total_turn := 0.0
	for t in turns:
		total_turn += t
	var window := maxi(2, n / 12)
	var corner := 0.0
	for i in range(0, turns.size() - window + 1):
		var acc := 0.0
		for k in window:
			acc += turns[i + k]
		corner = maxf(corner, absf(acc))
	# Self-crossings between non-adjacent segments, as positions along the path (of L).
	var total_len := arclen[n - 1]
	var crossings: Array = []
	for i in range(0, n - 1):
		for j in range(i + 2, n - 1):
			var hit: Variant = Geometry2D.segment_intersects_segment(p[i], p[i + 1], p[j], p[j + 1])
			if hit == null:
				continue
			var sa := (arclen[i] + p[i].distance_to(hit)) / total_len
			var sb := (arclen[j] + p[j].distance_to(hit)) / total_len
			if sb - sa < KNOT:
				continue
			var merged := false
			for c: Dictionary in crossings:
				if absf(c["a"] - sa) < MERGE and absf(c["b"] - sb) < MERGE:
					merged = true
					break
			if not merged:
				crossings.append({"a": sa, "b": sb, "i": i, "j": j})
	# Roundness: spread of the distance to the centroid.
	var centroid := _centroid(p)
	var mean_r := 0.0
	for q in p:
		mean_r += q.distance_to(centroid)
	mean_r /= float(n)
	var var_r := 0.0
	for q in p:
		var_r += pow(q.distance_to(centroid) - mean_r, 2.0)
	var cv := sqrt(var_r / float(n)) / maxf(mean_r, 1e-3)
	var loop_turn := 0.0
	if crossings.size() == 1:
		for i in range(crossings[0]["i"], mini(crossings[0]["j"], turns.size())):
			loop_turn += turns[i]
	return {
		"length": length / height,
		"size": maxf(rect.size.x, rect.size.y) / height,
		"gap": chord / maxf(length, 1e-3),
		"straight": chord / maxf(length, 1e-3),
		"angle": angle,
		"turn": total_turn,
		"corner": corner,
		"cv": cv,
		"crossings": crossings,
		"loop_turn": loop_turn,
	}


## True when the stroke is small and short enough to be a dab (Kindle), whatever its timing.
static func is_dab(points: PackedVector2Array, height: float) -> bool:
	if points.size() < 2:
		return not points.is_empty()
	var extent := _bounds(points).size
	if maxf(extent.x, extent.y) > DAB_MAX_SIZE * height:
		return false
	return BrushStroke.path_length(BrushStroke.clean(points, DAB_SPACING * height)) <= DAB_MAX_LENGTH * height


## The tie post (index into posts) whose projected disc, grown by TIE_MARGIN, holds the point
## and is nearest to it; -1 if none. except is skipped.
static func post_at(point: Vector2, posts: Array, except: int = -1) -> int:
	var best := -1
	var best_d := INF
	for i in posts.size():
		if i == except:
			continue
		var d := point.distance_to(posts[i]["pos"])
		if d <= float(posts[i]["radius"]) + TIE_MARGIN and d < best_d:
			best_d = d
			best = i
	return best


static func _match_tie(points: PackedVector2Array, f: Dictionary, height: float, posts: Array) -> Dictionary:
	var out := {"gate": "", "posts": []}
	if f["length"] < TIE_MIN_LENGTH:
		out["gate"] = "too short"
	elif not (f["crossings"] as Array).is_empty():
		out["gate"] = "crosses itself"
	else:
		var bow := _bow(BrushStroke.resample(points, FEATURE_POINTS))
		if bow > TIE_MAX_BOW:
			out["gate"] = "bowed (%.2f)" % bow
			return out
		var a := post_at(points[0], posts)
		var b := post_at(points[points.size() - 1], posts, a)
		if a < 0 or b < 0:
			out["gate"] = "ends not on two posts"
		else:
			out["posts"] = [a, b]
	return out


## The furthest any point lies from the chord, as a fraction of the chord. Unlike chord / L it
## does not grow with sensor jitter, which a slow stroke at a high input rate adds a lot of.
static func _bow(p: PackedVector2Array) -> float:
	var a := p[0]
	var b := p[p.size() - 1]
	var chord := a.distance_to(b)
	var far := 0.0
	for q in p:
		far = maxf(far, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return far / maxf(chord, 1e-3)


## With exactly one self-crossing, the stroke with each tail outside the loop cut to at most
## GUST_MAX_TAIL times the loop's length; otherwise the stroke unchanged.
static func _trim_tails(points: PackedVector2Array, f: Dictionary) -> PackedVector2Array:
	var crossings: Array = f["crossings"]
	if crossings.size() != 1:
		return points
	var a: float = crossings[0]["a"]
	var b: float = crossings[0]["b"]
	var keep := (b - a) * GUST_MAX_TAIL
	var from := maxf(0.0, a - keep)
	var to := minf(1.0, b + keep)
	if from <= 0.0 and to >= 1.0:
		return points
	var total := BrushStroke.path_length(points)
	var out := PackedVector2Array()
	var run := 0.0
	for i in points.size():
		var step := 0.0 if i == 0 else points[i - 1].distance_to(points[i])
		var s0 := run / total
		run += step
		var s1 := run / total
		if i > 0 and s0 < from and s1 >= from:
			out.append(points[i - 1].lerp(points[i], (from - s0) / maxf(s1 - s0, 1e-6)))
		if s1 >= from and s1 <= to:
			out.append(points[i])
		if i > 0 and s0 < to and s1 > to:
			out.append(points[i - 1].lerp(points[i], (to - s0) / maxf(s1 - s0, 1e-6)))
			break
	return out


static func _gate_bloom(f: Dictionary) -> String:
	if f["size"] < BLOOM_MIN_SIZE:
		return "too small"
	var crossings: Array = f["crossings"]
	for c: Dictionary in crossings:
		if c["a"] + (1.0 - c["b"]) > BLOOM_MAX_TAILS:
			return "crosses itself mid-stroke"
	if crossings.is_empty() and f["gap"] > BLOOM_MAX_GAP:
		return "not closed (gap %.2f)" % f["gap"]
	var turn := absf(f["turn"])
	if turn < BLOOM_TURN.x or turn > BLOOM_TURN.y:
		return "turns %.0f deg" % turn
	if f["cv"] > BLOOM_MAX_CV:
		return "not round (cv %.2f)" % f["cv"]
	if f["corner"] > BLOOM_MAX_CORNER:
		return "has a corner (%.0f deg)" % f["corner"]
	return ""


static func _gate_slash(f: Dictionary) -> String:
	if f["length"] < SLASH_MIN_LENGTH:
		return "too short"
	if not (f["crossings"] as Array).is_empty():
		return "crosses itself"
	if f["straight"] < SLASH_MIN_STRAIGHT:
		return "not straight (%.2f)" % f["straight"]
	if f["angle"] > SLASH_MAX_ANGLE:
		return "too steep (%.0f deg)" % f["angle"]
	return ""


static func _gate_gust(f: Dictionary) -> String:
	if f["size"] < GUST_MIN_SIZE:
		return "too small"
	var crossings: Array = f["crossings"]
	if crossings.size() != 1:
		return "%d crossings" % crossings.size()
	var c: Dictionary = crossings[0]
	var head: float = c["a"]
	var tail: float = 1.0 - c["b"]
	if head < GUST_MIN_TAIL or tail < GUST_MIN_TAIL or head + tail < GUST_MIN_TAILS:
		return "no tails outside the loop"
	if c["b"] - c["a"] < GUST_MIN_LOOP:
		return "loop too small"
	if absf(f["loop_turn"]) < GUST_LOOP_TURN:
		return "loop turns %.0f deg" % absf(f["loop_turn"])
	if absf(f["turn"]) < GUST_MIN_TURN:
		return "turns back on itself"
	return ""


static func _best_score(norm: PackedVector2Array, glyph: StringName) -> float:
	if _templates.is_empty():
		_build_templates()
	var best := INF
	for t: Dictionary in _templates:
		if t["glyph"] == glyph:
			best = minf(best, _distance_at_best_angle(norm, t["points"]))
	return maxf(0.0, 1.0 - best / (0.5 * sqrt(2.0 * SQUARE * SQUARE)))


static func _build_templates() -> void:
	var specs := [
		[&"bloom", {}], [&"bloom", {"ccw": false}],
		[&"bloom", {"aspect": 0.8}], [&"bloom", {"aspect": 0.8, "ccw": false}],
		[&"bloom", {"turns": 1.06}], [&"bloom", {"turns": 1.06, "ccw": false}],
		[&"slash", {}], [&"slash", {"bow": 0.08}], [&"slash", {"bow": -0.08}],
	]
	for loop in [1.8, 2.6]:
		for mirror in [false, true]:
			for reverse in [false, true]:
				specs.append([&"gust", {"loop": loop, "mirror": mirror, "reverse": reverse}])
	for spec in specs:
		_templates.append({"glyph": spec[0], "points": _normalise(BrushStroke.resample(ideal(spec[0], 128, spec[1]), N))})


## $1 steps 2 and 3: rotate so the indicative angle (centroid to first point) is zero, scale,
## and move the centroid to the origin. Scaling is uniform (larger side to SQUARE) rather than
## the paper's non-uniform square, so a line stays a line instead of being stretched into noise.
static func _normalise(pts: PackedVector2Array) -> PackedVector2Array:
	var c := _centroid(pts)
	var theta := (c - pts[0]).angle()
	var out := PackedVector2Array()
	for p in pts:
		out.append((p - c).rotated(-theta))
	var rect := _bounds(out)
	var s := SQUARE / maxf(maxf(rect.size.x, rect.size.y), 1e-3)
	var c2 := _centroid(out)
	for i in out.size():
		out[i] = (out[i] - c2) * s
	return out


## $1 step 4: golden section search for the rotation in [-45, 45] degrees that minimises the
## mean point-to-point distance to the template.
static func _distance_at_best_angle(pts: PackedVector2Array, tmpl: PackedVector2Array) -> float:
	var a := -ANGLE_RANGE
	var b := ANGLE_RANGE
	var x1 := PHI * a + (1.0 - PHI) * b
	var f1 := _distance_at_angle(pts, tmpl, x1)
	var x2 := (1.0 - PHI) * a + PHI * b
	var f2 := _distance_at_angle(pts, tmpl, x2)
	while absf(b - a) > ANGLE_STEP:
		if f1 < f2:
			b = x2
			x2 = x1
			f2 = f1
			x1 = PHI * a + (1.0 - PHI) * b
			f1 = _distance_at_angle(pts, tmpl, x1)
		else:
			a = x1
			x1 = x2
			f1 = f2
			x2 = (1.0 - PHI) * a + PHI * b
			f2 = _distance_at_angle(pts, tmpl, x2)
	return minf(f1, f2)


static func _distance_at_angle(pts: PackedVector2Array, tmpl: PackedVector2Array, angle: float) -> float:
	var cs := cos(angle)
	var sn := sin(angle)
	var d := 0.0
	for i in pts.size():
		var p := pts[i]
		d += Vector2(p.x * cs - p.y * sn, p.x * sn + p.y * cs).distance_to(tmpl[i])
	return d / float(pts.size())


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / float(maxi(pts.size(), 1))


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	return rect
