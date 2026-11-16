extends Node3D
## Sedge Plain's river surface (assets/levels/sedge_plain/terrain/river.glb) under vfx's water
## material, flowing east. Owner: l3.

const WATER_MATERIAL := "res://materials/env/water.tres"

## Downstream direction in world XZ.
@export var flow_direction := Vector2(1.0, 0.05)
@export var flow_speed := 0.7


func _ready() -> void:
	if not ResourceLoader.exists(WATER_MATERIAL):
		return
	var material := (load(WATER_MATERIAL) as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter(&"flow_direction", flow_direction)
	material.set_shader_parameter(&"flow_speed", flow_speed)
	for m: Node in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.add_to_group(&"ink_skip")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = material
	Vfx.register_material(material)
