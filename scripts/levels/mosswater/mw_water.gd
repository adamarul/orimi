extends Node3D
## Wrapper script for Mosswater Wood's water (assets/levels/mosswater/mw_water.glb): every
## surface takes vfx's shared water material (materials/env/water.tres, mapped in world XZ, so
## the ponds turn black inside the CurseField pond zones). Falls and runnels show only while the
## stream runs: set_flowing(). Owner: l4.

const WATER_MATERIAL := "res://materials/env/water.tres"

@export var flowing: bool = false:
	set(v):
		flowing = v
		if is_inside_tree():
			_apply_flow()


func _ready() -> void:
	var mat: Material = load(WATER_MATERIAL) if ResourceLoader.exists(WATER_MATERIAL) else null
	for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mat:
			m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.add_to_group(&"ink_skip")
	_apply_flow()


func set_flowing(on: bool) -> void:
	flowing = on


func _apply_flow() -> void:
	for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name)
		if n.begins_with("Fall_") or n.begins_with("Runnel_"):
			m.visible = flowing
