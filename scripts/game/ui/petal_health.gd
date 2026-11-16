class_name PetalHealth
extends Control
## Health as a five-petal flower: one petal per hit point. A lost petal is left as a bare ink
## outline, and flutters off in stepped frames when it is lost. Owner: gameplay.

var hp: int = 5
var max_hp: int = 5
var _falling: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(110, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.player_damaged.connect(_on_damaged)
	Events.player_healed.connect(_on_healed)


func set_health(value: int, maximum: int) -> void:
	hp = value
	max_hp = maximum
	queue_redraw()


func _on_damaged(value: int, maximum: int) -> void:
	for i in range(value, mini(hp, maximum)):
		_falling.append({"index": i, "t": 0.0})
	set_health(value, maximum)


func _on_healed(value: int, maximum: int) -> void:
	set_health(value, maximum)


func _process(delta: float) -> void:
	if _falling.is_empty():
		return
	for f: Dictionary in _falling:
		f["t"] += delta
	_falling = _falling.filter(func(f: Dictionary) -> bool: return f["t"] < 0.9)
	queue_redraw()


func _petal(center: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var along := length * (1.0 - cos(PI * t)) * 0.5
		var half := width * sin(PI * t) * (0.75 + 0.25 * t)
		pts.append(Vector2(along, 0))
		pts[pts.size() - 1] = Vector2(along, half)
	for i in range(12, -1, -1):
		var t := i / 12.0
		var along := length * (1.0 - cos(PI * t)) * 0.5
		var half := width * sin(PI * t) * (0.75 + 0.25 * t)
		pts.append(Vector2(along, -half))
	var out := PackedVector2Array()
	for p in pts:
		out.append(center + p.rotated(angle))
	return out


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	for i in max_hp:
		var a := -PI * 0.5 + TAU * i / max_hp
		var poly := _petal(c, a, r, r * 0.34)
		if i < hp:
			draw_colored_polygon(poly, Palette.PETAL if i % 2 == 0 else Palette.PETAL_DEEP)
			var hi := _petal(c + Vector2.from_angle(a) * r * 0.18, a, r * 0.6, r * 0.1)
			draw_colored_polygon(hi, Color(1, 1, 1, 0.45))
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, Color(Palette.INK_SOFT, 0.85 if i < hp else 0.45), 2.0 if i < hp else 1.5, true)
	for f: Dictionary in _falling:
		var i: int = f["index"]
		var step := floorf(float(f["t"]) * 12.0) / 12.0
		var a := -PI * 0.5 + TAU * i / max_hp + step * 2.5
		var drift := Vector2.from_angle(-PI * 0.5 + TAU * i / max_hp) * r * (0.4 + step * 1.6) + Vector2(0, step * 40.0)
		var poly := _petal(c + drift, a, r * (1.0 - step * 0.5), r * 0.3)
		draw_colored_polygon(poly, Color(Palette.PETAL_DEEP, 1.0 - step))
	draw_circle(c, r * 0.16, Palette.GOLD)
	draw_arc(c, r * 0.16, 0, TAU, 16, Palette.INK_SOFT, 1.5, true)
