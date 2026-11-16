class_name GlyphIcon
extends Control
## An inked drawing of a glyph stroke (bloom circle, slash line, gust loop, kindle dab, tie
## line between two posts), used in the
## glyph guide and in tutorial prompts. Owner: gameplay.

@export var glyph: StringName = &"bloom":
	set(value):
		glyph = value
		queue_redraw()
@export var ink: Color = Palette.INK


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The stroke as points in 0..1 space, start to end.
static func stroke(which: StringName) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match which:
		&"bloom":
			for i in 49:
				var a := -PI * 0.5 + TAU * 1.04 * i / 48.0
				pts.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * Vector2(0.4, 0.38))
		&"slash":
			for i in 25:
				var t := i / 24.0
				pts.append(Vector2(0.08 + 0.84 * t, 0.53 - 0.06 * t + 0.02 * sin(t * PI)))
		&"gust":
			# A prolate cycloid: in from the left, one loop at the top, out to the right.
			for i in 61:
				var t := lerpf(-PI, PI, i / 60.0)
				var x := t - 2.2 * sin(t)
				var y := 2.2 * cos(t)
				pts.append(Vector2(0.5 + x / TAU * 0.84, 0.5 - y / 2.2 * 0.32))
		&"kindle":
			# A dab: the brush pressed down and barely moved.
			pts.append(Vector2(0.5, 0.5))
			pts.append(Vector2(0.505, 0.502))
			pts.append(Vector2(0.508, 0.506))
		&"tie":
			# One straight line from one post to another (the icon puts a post at each end).
			for i in 21:
				pts.append(Vector2(0.14, 0.64).lerp(Vector2(0.86, 0.36), i / 20.0))
	return pts


func _draw() -> void:
	var pts := stroke(glyph)
	var s := minf(size.x, size.y)
	var off := (size - Vector2(s, s)) * 0.5
	var n := pts.size()
	if glyph == &"kindle":
		# A round blot with a small flame above it.
		var c := off + Vector2(0.5, 0.56) * s
		draw_circle(c, s * 0.09, ink)
		for k in 5:
			var a := TAU * k / 5.0 + 0.4
			draw_circle(c + Vector2(cos(a), sin(a)) * s * (0.12 + 0.02 * (k % 2)), s * 0.015, ink)
		var flame := PackedVector2Array([c + Vector2(0, -s * 0.36), c + Vector2(s * 0.07, -s * 0.18), c + Vector2(0, -s * 0.13), c + Vector2(-s * 0.07, -s * 0.18)])
		draw_colored_polygon(flame, Palette.VERMILION)
		return
	if glyph == &"tie":
		for p: Vector2 in [pts[0], pts[n - 1]]:
			var at := off + p * s
			draw_line(at, at + Vector2(0, s * 0.2), ink, s * 0.035, true)
			draw_arc(at, s * 0.045, 0.0, TAU, 16, Palette.VERMILION, s * 0.02, true)
	for i in n - 1:
		var t := float(i) / (n - 1)
		var w := s * (0.012 + 0.05 * sin(PI * clampf(t * 1.1, 0.0, 1.0)))
		var a := off + pts[i] * s
		var b := off + pts[i + 1] * s
		draw_line(a, b, ink, w, true)
		draw_circle(b, w * 0.5, ink)
	var tip := off + pts[n - 1] * s
	var prev := off + pts[n - 2] * s
	var dir := (tip - prev).normalized()
	draw_line(tip, tip + dir.rotated(2.5) * s * 0.09, ink, s * 0.02, true)
	draw_line(tip, tip + dir.rotated(-2.5) * s * 0.09, ink, s * 0.02, true)
