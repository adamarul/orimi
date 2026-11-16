extends Node3D
## scenes/env/foliage_scatter.tscn: camera-facing card foliage scattered over an area from a
## seed, drawn as one MultiMesh (shaders/env/foliage.gdshader). Owner: vfx.
## Cards: reeds, grass tufts, bush fans and tree foliage fans (brush-stroke cards, not modelled
## leaves). They sway with the "wind" global in 12 fps steps, bend away from player_world_pos,
## dull with valley_gloom and turn to black ink inside cursed zones.
## The default area covers the playable valley around this node, so gameplay can drop one at the
## origin. With snap_to_ground it raycasts the world layer to sit each card on the terrain
## (after two physics frames, so the terrain's collision exists); without it cards sit at y = 0.
## With avoid_valley_paths it keeps the path and the river clear, reading the polylines from the
## gameplay class GreyboxTerrain when that class exists.

## Width (X) and length (Z) of the scattered area, centred on this node, in metres.
@export var area_size := Vector2(60.0, 124.0)
## Number of cards.
@export var count := 900
@export var seed := 1
## Relative weights of reeds, grass tufts, bush fans and tree fans.
@export var kind_weights := Vector4(0.2, 0.55, 0.25, 0.0)
## Card height ranges in metres (min, max) per kind.
@export var reed_height := Vector2(1.0, 1.7)
@export var grass_height := Vector2(0.45, 0.8)
@export var bush_height := Vector2(1.0, 1.6)
@export var tree_height := Vector2(2.6, 3.6)
## Sit every card on the world-layer ground under it.
@export var snap_to_ground := true
## Skip ground steeper than this, in degrees.
@export var max_slope := 38.0
## Keep cards off the valley path and the river (see above).
@export var avoid_valley_paths := true
@export var path_clearance := 2.2
@export var river_clearance := 3.0
## Circles kept free of cards, in world space: x, z and radius (for clearings, saplings...).
@export var keep_clear := PackedVector3Array()
## Reeds are preferred within this distance of the river.
@export var reed_river_band := 7.0

var multimesh_instance: MultiMeshInstance3D
var material: ShaderMaterial
var placed := 0

const KIND_REEDS := 0
const KIND_GRASS := 1
const KIND_BUSH := 2
const KIND_TREE := 3
const SWAY := [1.0, 0.8, 0.35, 0.25]


func _ready() -> void:
	multimesh_instance = $Cards as MultiMeshInstance3D
	multimesh_instance.add_to_group(&"ink_skip")
	material = (multimesh_instance.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	multimesh_instance.material_override = material
	if not has_meta(&"vfx_warm_up"):
		Vfx.register_material(material)
	if snap_to_ground and not has_meta(&"vfx_warm_up"):
		multimesh_instance.visible = false
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not is_inside_tree():
			return
	rebuild()


## Re-scatters every card from the current settings.
func rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lines := _valley_lines() if avoid_valley_paths else [[], []]
	var path: Array = lines[0]
	var river: Array = lines[1]
	var space := get_world_3d().direct_space_state
	var snap := snap_to_ground and not has_meta(&"vfx_warm_up")
	var origin := global_position
	var min_up := cos(deg_to_rad(max_slope))
	var data := PackedFloat32Array()
	data.resize(count * 16)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	placed = 0
	var tries := 0
	var total_w := kind_weights.x + kind_weights.y + kind_weights.z + kind_weights.w
	while placed < count and tries < count * 4:
		tries += 1
		var p := origin + Vector3(rng.randf_range(-0.5, 0.5) * area_size.x, 0.0, rng.randf_range(-0.5, 0.5) * area_size.y)
		var flat := Vector2(p.x, p.z)
		if not path.is_empty() and _poly_dist(flat, path) < path_clearance:
			continue
		var blocked := false
		for c in keep_clear:
			if flat.distance_to(Vector2(c.x, c.y)) < c.z:
				blocked = true
				break
		if blocked:
			continue
		var river_d := _poly_dist(flat, river) if not river.is_empty() else INF
		if river_d < river_clearance:
			continue
		if snap:
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0, Layers.WORLD)
			var hit := space.intersect_ray(q)
			if hit.is_empty() or (hit["normal"] as Vector3).y < min_up:
				continue
			p = hit["position"]
		var pick := rng.randf() * maxf(total_w, 0.0001)
		if river_d < reed_river_band and rng.randf() < 0.6:
			pick = 0.0
		var kind := KIND_TREE
		if pick < kind_weights.x:
			kind = KIND_REEDS
		elif pick < kind_weights.x + kind_weights.y:
			kind = KIND_GRASS
		elif pick < kind_weights.x + kind_weights.y + kind_weights.z:
			kind = KIND_BUSH
		var hr: Vector2 = [reed_height, grass_height, bush_height, tree_height][kind]
		var h := rng.randf_range(hr.x, hr.y)
		var w := h * (1.25 if kind >= KIND_BUSH else 1.0)
		var local := p - origin
		var o := placed * 16
		data[o + 0] = w
		data[o + 1] = 0.0
		data[o + 2] = 0.0
		data[o + 3] = local.x
		data[o + 4] = 0.0
		data[o + 5] = h
		data[o + 6] = 0.0
		data[o + 7] = local.y - 0.04
		data[o + 8] = 0.0
		data[o + 9] = 0.0
		data[o + 10] = 1.0
		data[o + 11] = local.z
		data[o + 12] = float(kind + 4 * rng.randi_range(0, 1))
		data[o + 13] = rng.randf()
		data[o + 14] = SWAY[kind] * rng.randf_range(0.8, 1.2)
		data[o + 15] = rng.randf_range(-1.0, 1.0)
		lo = lo.min(local - Vector3(w, 0, w))
		hi = hi.max(local + Vector3(w, h, w))
		placed += 1
	data.resize(placed * 16)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = placed
	if placed > 0:
		mm.buffer = data
		multimesh_instance.custom_aabb = AABB(lo - Vector3.ONE * 2.0, hi - lo + Vector3.ONE * 4.0)
	multimesh_instance.multimesh = mm
	multimesh_instance.visible = placed > 0


func _valley_lines() -> Array:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c.get("class") == &"GreyboxTerrain":
			var script := load(String(c.get("path"))) as Script
			if script == null:
				break
			var consts := script.get_script_constant_map()
			return [consts.get("PATH", []), consts.get("RIVER", [])]
	return [[], []]


func _poly_dist(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best
