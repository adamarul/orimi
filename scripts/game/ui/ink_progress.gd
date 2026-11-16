class_name InkProgress
extends Control
## Loading indicator: a tapered brush stroke that grows with progress, with a drop of ink
## that keeps bobbing so the screen never looks frozen between loading steps. Owner: gameplay.

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var y := size.y * 0.5
	draw_line(Vector2(0, y), Vector2(size.x, y), Color(Palette.INK, 0.15), 2.0)
	var end := size.x * value
	var n := 24
	for i in n:
		var a := float(i) / n
		var b := float(i + 1) / n
		var w := 2.0 + 7.0 * sin(PI * clampf(a * 1.05, 0.0, 1.0))
		draw_line(Vector2(end * a, y + sin(a * 9.0) * 1.2), Vector2(end * b, y + sin(b * 9.0) * 1.2), Palette.INK, w, true)
	if value < 1.0:
		var bob := floorf(_t * 12.0) / 12.0
		draw_circle(Vector2(end + 10.0, y - 4.0 + 4.0 * sin(bob * 6.0)), 4.0, Palette.INK)
