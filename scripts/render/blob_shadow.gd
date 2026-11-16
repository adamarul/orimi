extends MeshInstance3D
## Blob shadow under a character (scenes/render/blob_shadow.tscn). Owner: render.
## Parent it under the character body. Each physics frame it casts a ray straight down from its
## parent and lies on whatever world geometry it finds, shrinking and fading with height, so it
## stays on the ground through jumps. Without a hit it stays at its parent's feet.

## Footprint of the ellipse in metres (x across, y along the body).
@export var size: Vector2 = Vector2(0.7, 1.0)
## 0..1 darkness at the centre. Tuned on web (0.75 reads as 70 to 80 % there and on desktop).
@export_range(0.0, 1.0) var strength: float = 0.75:
	set(value):
		strength = value
		if material_override:
			(material_override as ShaderMaterial).set_shader_parameter(&"strength", value)
## Physics mask of the ground the shadow lies on.
@export_flags_3d_physics var ground_mask: int = 1
## Height above the ground at which the shadow has faded out completely.
@export var fade_height: float = 4.0

var _last_ground_y := INF


func _ready() -> void:
	top_level = true
	material_override = material_override.duplicate()
	strength = strength
	add_to_group(&"ink_skip")
	_follow()


func _physics_process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var parent := get_parent() as Node3D
	if parent == null or not is_inside_tree():
		return
	var origin := parent.global_position
	var ground := origin
	var normal := Vector3.UP
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	if space:
		var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.5, origin + Vector3.DOWN * (fade_height + 1.0), ground_mask)
		var exclude: Array[RID] = []
		if parent is CollisionObject3D:
			exclude.append((parent as CollisionObject3D).get_rid())
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit:
			ground = hit.position
			normal = hit.normal
	var height := maxf(origin.y - ground.y, 0.0)
	var k := clampf(1.0 - height / maxf(fade_height, 0.01), 0.0, 1.0)
	var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis.from_euler(Vector3(0.0, parent.global_rotation.y, 0.0))
	global_transform = Transform3D(basis * Basis.from_scale(Vector3(size.x, 1.0, size.y) * lerpf(0.6, 1.0, k)), ground + normal * 0.03)
	(material_override as ShaderMaterial).set_shader_parameter(&"fade", k)
