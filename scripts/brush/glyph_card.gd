extends Control
## A small torn-paper card showing one glyph as an ink stroke with its name, for tutorial
## prompts and the pause menu. Set glyph to bloom, slash, gust, kindle or tie. A small ink dot
## marks where the stroke starts. Kindle shows a dab above a small wick; Tie shows its line between
## two post rings, the same rings the brush draws round tie posts.

const PAPER := Color("e3d3b0")
const PAPER_EDGE := Color("d8bf8f")
const INK := Color("1b1a1c")

@export_enum("bloom", "slash", "gust", "kindle", "tie") var glyph: String = "bloom":
	set(value):
		glyph = value
		if is_node_ready():
			_layout()
## Show the glyph name under the stroke.
@export var show_name: bool = true:
	set(value):
		show_name = value
		if is_node_ready():
			_layout()

var _paper := PackedVector2Array()
var _start := Vector2.ZERO
var _lines: BrushInkCanvas
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(150, 150)
	_lines = BrushInkCanvas.new()
	add_child(_lines)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override(&"font_color", INK)
	add_child(_label)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := size
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(glyph)
	# Torn paper: a rectangle whose edge is pushed in and out a little.
	_paper.clear()
	var corners := [Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]
	for c in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var steps := maxi(4, int(a.distance_to(b) / 7.0))
		var inward := (b - a).normalized().orthogonal()
		for i in steps:
			var p := a.lerp(b, float(i) / steps)
			_paper.append(p - inward * rng.randf_range(0.0, 4.0) + (Vector2(s.x, s.y) * 0.5 - p).normalized() * 3.0)
	var name_h := 26.0 if show_name else 0.0
	var area := Rect2(Vector2(s.x * 0.18, s.y * 0.14), Vector2(s.x * 0.64, s.y * 0.72 - name_h))
	var r := minf(area.size.x, area.size.y) * 0.5
	var pts := BrushGlyphs.ideal(StringName(glyph), 64)
	if glyph == "tie":
		r *= 0.8
	for i in pts.size():
		pts[i] = area.get_center() + pts[i] * r
	_start = pts[0]
	var ref := maxf(s.y, 100.0) * 2.4
	var list: Array[Dictionary] = []
	match glyph:
		"kindle":
			# A fat, slow dab, and the wick it lands on.
			list.append(BrushStroke.dab(area.get_center() - Vector2(0.0, r * 0.3), r * 0.8))
			var wick := area.get_center() + Vector2(0.0, r * 0.25)
			list.append(BrushStroke.build_simple(PackedVector2Array([wick, wick + Vector2(0.0, r * 0.75)]), ref, ref, 0.6))
			_start = Vector2.INF
		"tie":
			for end in [pts[0], pts[pts.size() - 1]]:
				var ring := PackedVector2Array()
				for k in 24:
					ring.append(end + Vector2.from_angle(-PI * 0.5 - TAU * 0.92 * k / 23.0) * r * 0.22)
				list.append(BrushStroke.build_simple(ring, ref, ref, 0.45))
			list.append(BrushStroke.build_simple(pts, ref, ref * 0.5, 0.8))
		_:
			list.append(BrushStroke.build_simple(pts, ref, ref * 0.5, 0.8))
	_lines.strokes = list
	_lines.set_param(&"dry_bias", 0.3)
	_label.visible = show_name
	_label.text = BrushGlyphs.NAMES.get(StringName(glyph), glyph)
	_label.position = Vector2(0, s.y - name_h - 12.0)
	_label.size = Vector2(s.x, name_h)
	queue_redraw()


func _draw() -> void:
	if _paper.size() < 3:
		return
	draw_colored_polygon(_paper, PAPER)
	var edge := _paper.duplicate()
	edge.append(_paper[0])
	draw_polyline(edge, Color(PAPER_EDGE, 0.9), 2.0, true)
	if _start.is_finite():
		draw_circle(_start, 4.5, INK, true, -1.0, true)
