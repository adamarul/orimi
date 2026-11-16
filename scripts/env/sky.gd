extends Node3D
## scenes/env/sky.tscn: a flat pale wash sky with brush-drawn swirled clouds that drift.
## Owner: vfx. The dome follows the active camera inside its shader (shaders/env/sky.gdshader),
## so it can sit anywhere in the scene. It drains toward bare paper with the valley_gloom global
## and while the camera stands in a cursed zone. It brings no WorldEnvironment of its own.

## Number of clouds around the horizon (0..16).
@export_range(0, 16) var cloud_count := 14
## Angular drift speed of the clouds (radians per second, before per-cloud variation).
@export var drift_speed := 0.006
## Changes where the clouds sit.
@export var cloud_seed := 3.0
## How far valley_gloom drains the sky (0 never, 1 fully to paper).
@export_range(0.0, 1.0) var gloom_strength := 0.85
## Dome radius in metres; keep it inside the camera's far plane.
@export var dome_radius := 350.0

var material: ShaderMaterial


func _ready() -> void:
	var dome := $Dome as MeshInstance3D
	dome.add_to_group(&"ink_skip")
	material = (dome.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter(&"cloud_count", cloud_count)
	material.set_shader_parameter(&"drift_speed", drift_speed)
	material.set_shader_parameter(&"cloud_seed", cloud_seed)
	material.set_shader_parameter(&"gloom_strength", gloom_strength)
	material.set_shader_parameter(&"dome_radius", dome_radius)
	dome.material_override = material
	if not has_meta(&"vfx_warm_up"):
		Vfx.register_material(material)
