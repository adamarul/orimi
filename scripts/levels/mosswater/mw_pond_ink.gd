class_name MwPondInk
extends Node3D
## A drained pond's black ink: a cursed area drawn through CurseField while the pond is still,
## sharing the four render slots with the spring's CursedZone through CurseSlots. Purely a look:
## the pond's DeepWater keeps Orimi out. The finale clears it pond by pond. Owner: l4.

const CLEAR_TIME := 2.5

@export var radius: float = 10.0

## Assigned by CurseSlots (-1 while another area holds the slot).
var curse_slot := -1
var is_clear := false
var _clear_end := 0.0


func _ready() -> void:
	CurseSlots.register(self)


func _exit_tree() -> void:
	CurseSlots.unregister(self)


func clear(instant: bool = false) -> void:
	if is_clear:
		return
	is_clear = true
	var t := 0.1 if instant else CLEAR_TIME
	_clear_end = Time.get_ticks_msec() / 1000.0 + t
	if curse_slot >= 0:
		CurseField.restore_zone(curse_slot, t)
	CurseSlots.refresh()


func curse_wants_slot() -> bool:
	return not is_clear or Time.get_ticks_msec() / 1000.0 < _clear_end


func curse_assigned(slot: int) -> void:
	var animating := is_clear and Time.get_ticks_msec() / 1000.0 < _clear_end
	CurseField.set_zone(slot, global_position, radius, 0.0 if is_clear and not animating else 1.0)
	if animating:
		CurseField.restore_zone(slot, maxf(_clear_end - Time.get_ticks_msec() / 1000.0, 0.1))
