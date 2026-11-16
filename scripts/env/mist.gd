extends Node3D
## scenes/env/mist.tscn: low drifting mist bands in paper colour (shaders/env/mist.gdshader).
## Owner: vfx. Bands are long cards that turn about Y to face the camera, rooted near the ground
## around this node, drifting sideways in 12 fps steps. One MultiMesh, translucent.

## Width (X) and depth (Z) of the area the bands are spread over, in metres.
@export var area_size := Vector2(18.0, 12.0)
@export var band_count := 6
@export var seed := 7
## Band length and height ranges in metres.
@export var band_length := Vector2(7.0, 13.0)
@export var band_height := Vector2(1.2, 2.4)
## Height of the band roots above this node (min, max), in metres.
@export var lift := Vector2(-0.3, 0.9)
@export_range(0.0, 1.0) var opacity := 0.7
@export var drift_speed := 0.02

var material: ShaderMaterial


func _ready() -> void:
	var bands := $Bands as MultiMeshInstance3D
	bands.add_to_group(&"ink_skip")
	material = (bands.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter(&"opacity", opacity)
	material.set_shader_parameter(&"drift_speed", drift_speed)
	bands.material_override = material
	if not has_meta(&"vfx_warm_up"):
		Vfx.register_material(material)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = band_count
	for i in band_count:
		var l := rng.randf_range(band_length.x, band_length.y)
		var h := rng.randf_range(band_height.x, band_height.y)
		var p := Vector3(rng.randf_range(-0.5, 0.5) * area_size.x, rng.randf_range(lift.x, lift.y), rng.randf_range(-0.5, 0.5) * area_size.y)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(l, h, 1.0)), p))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.5, 1.5) * (1.0 if rng.randf() < 0.7 else -1.0),
			rng.randf_range(0.6, 1.0), 1.0 if rng.randf() < 0.3 else 0.0))
	bands.multimesh = mm
	var r := maxf(area_size.x, area_size.y) * 0.5 + band_length.y
	bands.custom_aabb = AABB(Vector3(-r, -1.0, -r), Vector3(2.0 * r, band_height.y + 3.0, 2.0 * r))
