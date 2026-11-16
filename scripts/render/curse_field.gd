extends Node
## Autoload "CurseField". Owner: render. Tracks the cursed spheres and pushes the shader
## globals (curse_zone_0..3, curse_amount, valley_gloom) that ink_toon.gdshader and
## ink_common.gdshaderinc read. Gameplay drives it; render draws it.
##
## A zone's amount is drawn as a hard ragged front, not a fade: amount 1 is fully cursed,
## and as the amount falls the clean disc around the centre grows (front_radius()) until it
## has passed the rim at amount 0. Raising the amount again re-curses from the rim inward.

const MAX_ZONES := 4
## Added by render: places whose curse was lifted in the current level, remembered after their
## area gives up its slot (curse_restored_0..3), so ground marks stay lighter there.
const MAX_RESTORED := 4
const WALL_SHADER := preload("res://shaders/render/curse_wall.gdshader")
const NOISE_TEX := preload("res://assets/textures/render/ink_noise.png")

## Added by render: show the black-mass wall around each zone (seen from outside only).
var walls_enabled: bool = true:
	set(value):
		walls_enabled = value
		_update_walls()

## Valley-wide dullness, 1.0 while the great tree is cursed, 0.0 once restored.
var valley_gloom: float = 1.0

var _centers: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _radii: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _amounts: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _tweens: Array[Tween] = [null, null, null, null]
var _gloom_tween: Tween
var _walls: Array[MeshInstance3D] = []
var _walls_dirty := false
var _restored: Array[Vector4] = []
var _restored_level := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for slot in MAX_ZONES:
		var wall := MeshInstance3D.new()
		wall.name = "CurseWall%d" % slot
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.visible = false
		var mat := ShaderMaterial.new()
		mat.shader = WALL_SHADER
		mat.set_shader_parameter(&"slot", slot)
		mat.set_shader_parameter(&"noise_tex", NOISE_TEX)
		wall.material_override = mat
		add_child(wall)
		_walls.append(wall)
	_push()


## Declare or update a cursed sphere. slot is 0..MAX_ZONES-1, amount 0 (clean) to 1 (fully cursed).
func set_zone(slot: int, center: Vector3, radius: float, amount: float = 1.0) -> void:
	if slot < 0 or slot >= MAX_ZONES:
		return
	_kill(slot)
	_centers[slot] = center
	_radii[slot] = radius
	_amounts[slot] = clampf(amount, 0.0, 1.0)
	_push()
	_update_walls()


## Animate a zone back to full colour over duration seconds: a ragged front races outward
## from the centre (fast at first, easing as it reaches the rim).
func restore_zone(slot: int, duration: float = 2.5) -> void:
	_animate(slot, 0.0, duration, Tween.EASE_OUT)


## Added by render: animate a zone back to cursed (the front closes from the rim inward).
func curse_zone(slot: int, duration: float = 2.5) -> void:
	_animate(slot, 1.0, duration, Tween.EASE_IN)


func clear_zone(slot: int) -> void:
	if slot < 0 or slot >= MAX_ZONES:
		return
	_kill(slot)
	_amounts[slot] = 0.0
	_radii[slot] = 0.0
	_push()
	_update_walls()


## How cursed a world position is right now, 0..1. Behind a restoration front it is 0.
func amount_at(world_pos: Vector3) -> float:
	var result := 0.0
	for slot in MAX_ZONES:
		var r := _radii[slot]
		if r <= 0.0 or _amounts[slot] <= 0.0:
			continue
		var c := _centers[slot]
		var d := Vector2(world_pos.x - c.x, world_pos.z - c.z).length()
		var vert := 1.0 - smoothstep(r * 0.5, r * 0.5 + maxf(r * 0.3, 4.0), absf(world_pos.y - c.y))
		var front := front_radius(slot)
		var v := (1.0 - smoothstep(r * 0.9, r, d)) * smoothstep(front - 0.5, front + 0.5, d) * vert
		result = maxf(result, v)
	return result


## Added by render: radius in metres of the clean disc around the zone's centre, the position
## of the restoration front (0 while fully cursed). Matches INK_CURSE_FRONT in the shaders.
func front_radius(slot: int) -> float:
	if slot < 0 or slot >= MAX_ZONES:
		return 0.0
	return (1.0 - _amounts[slot]) * (_radii[slot] * 1.25 + 2.0)


## Added by render: the zone's current amount, 0 clean to 1 cursed.
func zone_amount(slot: int) -> float:
	if slot < 0 or slot >= MAX_ZONES:
		return 0.0
	return _amounts[slot]


## Animate the valley-wide gloom. duration 0 sets it at once.
func set_valley_gloom(amount: float, duration: float = 0.0) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if _gloom_tween:
		_gloom_tween.kill()
	if duration <= 0.0:
		valley_gloom = amount
		_push()
		return
	_gloom_tween = create_tween()
	_gloom_tween.tween_method(_set_gloom, valley_gloom, amount, duration)


func _animate(slot: int, target: float, duration: float, ease_type: Tween.EaseType) -> void:
	if slot < 0 or slot >= MAX_ZONES:
		return
	_kill(slot)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(ease_type)
	tween.tween_method(_set_amount.bind(slot), _amounts[slot], target, maxf(duration, 0.01))
	_tweens[slot] = tween


func _kill(slot: int) -> void:
	if _tweens[slot]:
		_tweens[slot].kill()
		_tweens[slot] = null


func _set_amount(value: float, slot: int) -> void:
	_amounts[slot] = value
	if value <= 0.0 and _radii[slot] > 0.0:
		_remember_restored(_centers[slot], _radii[slot])
	_push()
	_walls[slot].visible = walls_enabled and _radii[slot] > 0.0 and value > 0.0


func _update_walls() -> void:
	for slot in _walls.size():
		var r := _radii[slot]
		_walls[slot].visible = walls_enabled and r > 0.0 and _amounts[slot] > 0.0
	_walls_dirty = true


func _remember_restored(center: Vector3, radius: float) -> void:
	_check_level()
	for i in _restored.size():
		if Vector3(_restored[i].x, _restored[i].y, _restored[i].z).distance_to(center) < 0.5:
			_restored.remove_at(i)
			break
	_restored.append(Vector4(center.x, center.y, center.z, radius))
	if _restored.size() > MAX_RESTORED:
		_restored.pop_front()


## The remembered places belong to one level; a new level starts with none.
func _check_level() -> bool:
	var id := Game.level.get_instance_id() if is_instance_valid(Game.level) else 0
	if id == _restored_level:
		return false
	_restored_level = id
	_restored.clear()
	return true


func _physics_process(_delta: float) -> void:
	if _check_level():
		_push()
	if not _walls_dirty:
		return
	_walls_dirty = false
	for slot in _walls.size():
		if _radii[slot] > 0.0:
			_build_wall(slot)


## The wall is a ring of quads whose foot follows the ground (rays down onto the world layer),
## so it never floats above a slope or hangs below a terrace edge. UV.y is 0 at the foot and 1
## at the top; the shader cuts the ragged top out of that.
func _build_wall(slot: int) -> void:
	var wall := _walls[slot]
	var r := _radii[slot]
	var center := _centers[slot]
	var height := clampf(r * 0.1, 0.9, 2.0)
	var segments := clampi(int(r * 8.0), 64, 192)
	var space: PhysicsDirectSpaceState3D = null
	if wall.is_inside_tree() and wall.get_world_3d():
		space = wall.get_world_3d().direct_space_state
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments + 1:
		var ang := TAU * float(i) / segments
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var foot := center + dir * r
		if space:
			foot.y = _ground_y(space, foot)
		st.set_normal(dir)
		st.set_uv(Vector2(float(i) / segments, -0.6 / height))
		st.add_vertex(foot + Vector3.DOWN * 0.6 - center)
		st.set_normal(dir)
		st.set_uv(Vector2(float(i) / segments, 1.0))
		st.add_vertex(foot + Vector3.UP * height - center)
	for i in segments:
		var b := i * 2
		st.add_index(b)
		st.add_index(b + 1)
		st.add_index(b + 2)
		st.add_index(b + 2)
		st.add_index(b + 1)
		st.add_index(b + 3)
	wall.mesh = st.commit()
	wall.custom_aabb = AABB(Vector3(-r - 1.0, -40.0, -r - 1.0), Vector3(2.0 * r + 2.0, 80.0, 2.0 * r + 2.0))
	wall.position = center
	(wall.material_override as ShaderMaterial).set_shader_parameter(&"height", height)


## The lowest world surface under a point: rocks, gates and roofs share the world layer with the
## terrain, so the ray steps through every hit and keeps the lowest (the foot stays on the ground
## instead of jumping onto a prop as a flat-topped block).
func _ground_y(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 30.0, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var y := at.y
	var found := false
	for i in 6:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		y = hit.position.y if not found else minf(y, hit.position.y)
		found = true
		query.exclude = query.exclude + [hit.rid]
	return y


func _set_gloom(value: float) -> void:
	valley_gloom = value
	_push()


func _push() -> void:
	for slot in MAX_ZONES:
		var c := _centers[slot]
		RenderingServer.global_shader_parameter_set(
			StringName("curse_zone_%d" % slot), Vector4(c.x, c.y, c.z, _radii[slot]))
	RenderingServer.global_shader_parameter_set(
		&"curse_amount", Vector4(_amounts[0], _amounts[1], _amounts[2], _amounts[3]))
	RenderingServer.global_shader_parameter_set(&"valley_gloom", valley_gloom)
	for i in MAX_RESTORED:
		RenderingServer.global_shader_parameter_set(StringName("curse_restored_%d" % i),
				_restored[i] if i < _restored.size() else Vector4.ZERO)
