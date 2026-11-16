extends Control
## The ink-pot meter: a squat ink pot drawn in brush strokes whose ink level shows Brush.ink.
## Self-contained: instance scenes/brush/ink_pot.tscn anywhere (gameplay's HUD does); it reads
## Brush on ready and follows Events.ink_changed.

## Seconds for the shown level to catch up with the real one.
const EASE_TIME := 0.25
const PAPER := Color("efe6d2")
const PAPER_SHADE := Color("d8c9a8")
const INK := Color("2e2b2d")

var _level := 1.0
var _target := 1.0
var _flash := 0.0
var _time := 0.0
var _body := PackedVector2Array()
var _lines: BrushInkCanvas


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(84, 96)
	_lines = BrushInkCanvas.new()
	add_child(_lines)
	resized.connect(_layout)
	Events.ink_changed.connect(_on_ink_changed)
	var brush := get_node_or_null(^"/root/Brush")
	if brush:
		_target = clampf(brush.ink / maxf(brush.ink_max, 0.001), 0.0, 1.0)
	_level = _target
	_layout()


func _on_ink_changed(current: float, maximum: float) -> void:
	var t := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if t > _target + 0.02:
		_flash = 1.0
	_target = t


func _process(delta: float) -> void:
	_time += delta
	_level = move_toward(_level, _target, delta / EASE_TIME * maxf(absf(_target - _level), 0.05))
	_flash = maxf(0.0, _flash - delta * 2.0)
	queue_redraw()


## Pot outline: half-width as a function of height (0 top of the lip, 1 base).
func _half_width(t: float) -> float:
	if t < 0.12:
		return 0.36
	if t < 0.24:
		return lerpf(0.36, 0.3, (t - 0.12) / 0.12)
	var u := (t - 0.24) / 0.76
	return 0.3 + 0.2 * sin(u * PI * 0.92) + 0.06 * u


func _layout() -> void:
	var s := size
	var cx := s.x * 0.5
	var top := s.y * 0.1
	var h := s.y * 0.84
	var w := minf(s.x, h * 1.05)
	var right := PackedVector2Array()
	var left := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		right.append(Vector2(cx + _half_width(t) * w, top + t * h))
		left.append(Vector2(cx - _half_width(t) * w, top + t * h))
	_body = right.duplicate()
	var rev := left.duplicate()
	rev.reverse()
	_body.append_array(rev)
	# Brush strokes: a heavy left side, a lighter right side, the lip and the base.
	var strokes: Array[Dictionary] = []
	var hh := s.y / 96.0
	strokes.append(_stroke(left.slice(2), 7.0 * hh, 0.15))
	strokes.append(_stroke(right.slice(2), 3.5 * hh, 0.5))
	var lip := PackedVector2Array()
	for i in 21:
		var a := PI + TAU * float(i) / 20.0 * 0.97
		lip.append(Vector2(cx + cos(a) * 0.36 * w, top + 0.05 * h + sin(a) * 0.05 * h))
	strokes.append(_stroke(lip, 3.5 * hh, 0.3))
	var base := PackedVector2Array([Vector2(cx - 0.5 * w, top + h * 0.995), Vector2(cx, top + h * 1.01), Vector2(cx + 0.46 * w, top + h * 0.99)])
	strokes.append(_stroke(base, 5.0 * hh, 0.4))
	_lines.strokes = strokes


func _stroke(pts: PackedVector2Array, width: float, dry: float) -> Dictionary:
	var smooth := BrushStroke.smooth(pts, 2.0)
	var widths := PackedFloat32Array()
	var dryness := PackedFloat32Array()
	widths.resize(smooth.size())
	dryness.resize(smooth.size())
	widths.fill(width)
	dryness.fill(dry)
	var len := BrushStroke.path_length(smooth)
	return BrushStroke.build(smooth, widths, dryness, len * 0.12, len * 0.3)


func _draw() -> void:
	if _body.size() < 3:
		return
	draw_colored_polygon(_body, PAPER)
	var rect := Rect2(_body[0], Vector2.ZERO)
	for p in _body:
		rect = rect.expand(p)
	# A soft wash on the side away from the brush light.
	var x0 := rect.position.x + rect.size.x * 0.66
	var wash := PackedVector2Array([Vector2(x0, rect.position.y - 4.0), Vector2(rect.end.x + 4.0, rect.position.y - 4.0), Vector2(rect.end.x + 4.0, rect.end.y + 4.0), Vector2(x0 - rect.size.x * 0.1, rect.end.y + 4.0)])
	for poly in Geometry2D.intersect_polygons(_body, wash):
		draw_colored_polygon(poly, Color(PAPER_SHADE, 0.6))
	# Ink: the pot body clipped below a gently moving surface.
	var top := rect.position.y + rect.size.y * 0.3
	var bottom := rect.end.y
	var level_y := lerpf(bottom, top, _level)
	if _level <= 0.003:
		return
	var surface := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var x := lerpf(rect.position.x - 4.0, rect.end.x + 4.0, float(i) / steps)
		var wave := sin(_time * 2.2 + x * 0.15) * 1.2 + sin(_time * 3.7 - x * 0.31) * 0.6
		surface.append(Vector2(x, level_y + wave * (0.4 + _flash)))
	surface.append(Vector2(rect.end.x + 4.0, bottom + 4.0))
	surface.append(Vector2(rect.position.x - 4.0, bottom + 4.0))
	for poly in Geometry2D.intersect_polygons(_body, surface):
		draw_colored_polygon(poly, INK)
	var gx := rect.position.x + rect.size.x * 0.3
	draw_line(Vector2(gx, level_y + 3.0), Vector2(gx + rect.size.x * 0.16, level_y + 2.0), Color(PAPER, 0.5 + 0.4 * _flash), 2.0, true)
