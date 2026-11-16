extends Node3D
## Counts processed frames and spins the node, so pause behaviour is both visible and measurable.

var frames := 0


func _process(delta: float) -> void:
	frames += 1
	rotate_y(delta * 1.5)
