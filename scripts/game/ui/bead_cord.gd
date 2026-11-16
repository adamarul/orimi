class_name BeadCord
extends Control
## Orimi's cord drawn flat for the interface: one slot per level of the book, in book order; a
## level finished on this save shows its bead in its colour, the rest an empty ink ring. Used by
## the HUD, the pause screen and the title. Owner: gameplay.

## Bead radius in pixels.
@export var bead_radius := 8.0
## Show only the beads earned (no empty rings, no cord when there are none).
@export var earned_only := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.bead_awarded.connect(func(_id: StringName, _c: Color) -> void: refresh())
	visibility_changed.connect(refresh)
	refresh()


## Re-read the beads from the save and redraw.
func refresh() -> void:
	var n := _slots().size()
	custom_minimum_size = Vector2(maxf(n, 1) * bead_radius * 3.0 + bead_radius, bead_radius * 2.0 + 6.0)
	queue_redraw()


## One entry per book level: its bead colour, or null when not earned yet.
func _slots() -> Array:
	var out := []
	for entry: Dictionary in LevelRegistry.levels():
		if not entry.has("bead_color"):
			continue
		var earned := Game.is_level_completed(StringName(entry["id"]))
		if earned:
			out.append(Color(String(entry["bead_color"])))
		elif not earned_only:
			out.append(null)
	return out


func _draw() -> void:
	var slots := _slots()
	if slots.is_empty():
		return
	var r := bead_radius
	var y := size.y * 0.5
	var step := r * 3.0
	var x0 := r * 1.5
	var x1 := x0 + step * (slots.size() - 1)
	draw_line(Vector2(x0 - r * 1.2, y - 1.0), Vector2(x1 + r * 1.2, y + 1.0), Palette.SEPIA, maxf(1.5, r * 0.22), true)
	for i in slots.size():
		var c := Vector2(x0 + step * i, y + (1.0 if i % 2 else -1.0) * r * 0.08)
		if slots[i] == null:
			draw_circle(c, r * 0.62, Palette.IVORY)
			draw_arc(c, r * 0.62, 0.0, TAU, 20, UiKit.INK_FAINT, maxf(1.2, r * 0.16), true)
			continue
		draw_circle(c, r, slots[i])
		draw_arc(c, r, 0.0, TAU, 24, Palette.INK, maxf(1.5, r * 0.2), true)
		draw_circle(c + Vector2(-r * 0.32, -r * 0.34), r * 0.24, Color(1, 1, 1, 0.55))
