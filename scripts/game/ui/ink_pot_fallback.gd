class_name InkPotFallback
extends Control
## Stand-in ink-pot meter until brush's scenes/brush/ink_pot.tscn exists. Owner: gameplay.

var ink := 100.0
var ink_max := 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink = Brush.ink
	ink_max = Brush.ink_max
	Events.ink_changed.connect(func(current: float, maximum: float) -> void:
		ink = current
		ink_max = maximum
		queue_redraw())


func _draw() -> void:
	var w := size.x
	var h := size.y
	var body := Rect2(w * 0.14, h * 0.28, w * 0.72, h * 0.66)
	var level := clampf(ink / maxf(ink_max, 0.01), 0.0, 1.0)
	var fill := Rect2(body.position.x + 3, body.end.y - 3 - (body.size.y - 6) * level, body.size.x - 6, (body.size.y - 6) * level)
	draw_rect(body, Color(Palette.PARCHMENT, 0.6))
	draw_rect(fill, Palette.INK)
	draw_rect(body, Palette.INK_SOFT, false, 2.5)
	draw_rect(Rect2(w * 0.3, h * 0.16, w * 0.4, h * 0.12), Palette.INK_SOFT, false, 2.0)
	draw_line(Vector2(w * 0.62, h * 0.02), Vector2(w * 0.46, h * 0.3), Palette.SEPIA, 3.0, true)
	draw_circle(Vector2(w * 0.46, h * 0.3), 3.0, Palette.INK)
