extends Node3D
## scenes/env/river_water.tscn: a flat strip of river (shaders/env/water.gdshader). Owner: vfx.
## The strip is a plane of size metres centred on this node, flowing along flow_direction
## (world XZ). For water on any other mesh, use materials/env/water.tres (it maps in world XZ,
## so it needs no UVs); the Vfx director animates that shared material.

## Width (X) and length (Z) of the strip in metres.
@export var size := Vector2(8.0, 40.0)
## Flow direction in world XZ (it is normalised).
@export var flow_direction := Vector2(0.0, 1.0)
## Drift speed of ripples and cells, metres per second.
@export var flow_speed := 0.6

var material: ShaderMaterial


func _ready() -> void:
	var surface := $Surface as MeshInstance3D
	surface.add_to_group(&"ink_skip")
	var plane := PlaneMesh.new()
	plane.size = size
	surface.mesh = plane
	material = (surface.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter(&"flow_direction", flow_direction)
	material.set_shader_parameter(&"flow_speed", flow_speed)
	surface.material_override = material
	if not has_meta(&"vfx_warm_up"):
		Vfx.register_material(material)
