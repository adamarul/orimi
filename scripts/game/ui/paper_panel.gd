class_name PaperPanel
extends Control
## A torn paper scrap with a ragged, dry-brush ink edge and faint wash stains, drawn
## procedurally so it holds at any size. Owner: gameplay.

@export var paper_color: Color = Palette.IVORY
@export var seed_value: int = 1
## How far the torn edge bites into the rectangle, in pixels.
@export var ragged: float = 7.0
@export var ink_edge: bool = true
@export var drop_shadow: bool = true
@export var stains: int = 5


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_STOP if mouse_filter == Control.MOUSE_FILTER_STOP else mouse_filter


func _outline() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array()
	var corners := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	var inward := [Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var len := a.distance_to(b)
		var n: int = maxi(3, int(len / 9.0))
		var tear := 0.0
		for i in range(1, n):
			var t := float(i) / n
			tear = lerpf(tear, rng.randf_range(0.0, 1.0), 0.45)
			var bite := ragged * (0.25 + tear) + (ragged * 1.6 if rng.randf() < 0.04 else 0.0)
			# Keep bites shallow near the corners so neighbouring sides never cross.
			bite *= clampf(minf(t, 1.0 - t) * len / (ragged * 4.0), 0.0, 1.0)
			pts.append(a.lerp(b, t) + inward[side] * bite)
		var next_in: Vector2 = inward[(side + 1) % 4]
		pts.append(b + (inward[side] + next_in) * ragged * 0.3)
	return pts


func _draw() -> void:
	if size.x < 8 or size.y < 8:
		return
	var pts := _outline()
	if drop_shadow:
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(5, 7))
		draw_colored_polygon(sh, Color(0.08, 0.06, 0.05, 0.22))
	draw_colored_polygon(pts, paper_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	for i in stains:
		var c := Vector2(rng.randf_range(0.1, 0.9) * size.x, rng.randf_range(0.15, 0.85) * size.y)
		var r := rng.randf_range(0.12, 0.3) * minf(size.x, size.y)
		draw_circle(c, r, Color(Palette.PARCHMENT_WARM, 0.07))
		draw_circle(c + Vector2(r * 0.2, -r * 0.1), r * 0.6, Color(Palette.PARCHMENT_WARM, 0.05))
	if not ink_edge:
		return
	var count := pts.size()
	var phase := rng.randf() * 10.0
	for i in count:
		var a := pts[i]
		var b := pts[(i + 1) % count]
		var k := float(i) / count
		var weight := 0.5 + 0.5 * sin(k * TAU * 3.0 + phase) * sin(k * TAU * 7.0 + phase * 0.5)
		if weight < 0.12:
			continue
		draw_line(a, b, Color(Palette.INK_SOFT, 0.55 + 0.35 * weight), 1.0 + 2.6 * weight, true)
