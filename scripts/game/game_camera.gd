class_name GameCamera
extends Node3D
## Third-person orbit camera with gentle positional and rotational lag, mouse and arrow-key
## control, pitch limits, collision that never leaves it inside geometry, CameraZone volumes
## (follow overrides, fixed views, framing several points), fading of props in the group
## "camera_fade" that come between it and Orimi, and a cinematic mode. Owner: gameplay.

const DISTANCE := 4.9
## Closest the camera comes when something is behind it (tight rooms, shafts).
const MIN_DISTANCE := 0.45
## Kept between the camera and any surface behind it.
const WALL_GAP := 0.12
## Props in this group do not push the camera in; they fade while they hide Orimi.
const FADE_GROUP := &"camera_fade"
const FADE_DISSOLVE := 0.6
## A physics layer nothing else uses: a fading prop with no solid body gives itself one here so
## the camera's ray can find it (Orimi and enemies pass through).
const FADE_LAYER := 1 << 19
const PIVOT_HEIGHT := 0.95
const FOV := 57.0
const PITCH_DEFAULT := -16.0
const PITCH_MIN := -62.0
const PITCH_MAX := 14.0
const MOUSE_YAW := 0.0026
const MOUSE_PITCH := 0.0021
const KEY_YAW := 2.3
const KEY_PITCH := 1.3
## Lag rates (higher follows faster).
const FOLLOW_XZ := 9.0
const FOLLOW_Y := 5.0
const ROTATE := 13.0
const ZOOM_OUT := 3.5
const PROBE_RADIUS := 0.22
## Seconds without camera input before it drifts back behind a moving player.
const RECENTER_DELAY := 2.0
const RECENTER_RATE := 0.9

var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(PITCH_DEFAULT)
var cinematic := false
var camera: Camera3D

var _yaw_s := 0.0
var _pitch_s := deg_to_rad(PITCH_DEFAULT)
var _pivot_s := Vector3.ZERO
var _dist_s := DISTANCE
var _idle_input := 0.0
var _probe := SphereShape3D.new()
var _small_probe := SphereShape3D.new()
var _zone: CameraZone
var _blend_zone: CameraZone
var _w := 0.0
var _zone_xf := Transform3D.IDENTITY
var _fov_s := FOV
var _pivot_height := PIVOT_HEIGHT
var _faded: Dictionary = {}


func _ready() -> void:
	top_level = true
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = FOV
	camera.near = 0.08
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	_probe.radius = PROBE_RADIUS
	_small_probe.radius = 0.05


func _unhandled_input(event: InputEvent) -> void:
	if cinematic or not Game.is_playing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = (event as InputEventMouseMotion).relative * Settings.mouse_sensitivity
		yaw -= rel.x * MOUSE_YAW
		pitch -= rel.y * MOUSE_PITCH * (-1.0 if Settings.invert_y else 1.0)
		pitch = clampf(pitch, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
		_idle_input = 0.0


## Jump the camera behind a node's facing with no lag.
func snap_behind(node: Node3D) -> void:
	target = node if target == null else target
	yaw = node.global_rotation.y
	pitch = deg_to_rad(PITCH_DEFAULT)
	snap()


func snap() -> void:
	_yaw_s = yaw
	_pitch_s = pitch
	if is_instance_valid(target):
		_pivot_s = _target_point()
	_dist_s = DISTANCE
	_place(DISTANCE)


## Turn the camera so it looks from behind the target toward a world point.
func face_toward(point: Vector3, pitch_deg: float = PITCH_DEFAULT) -> void:
	if not is_instance_valid(target):
		return
	var to := point - target.global_position
	yaw = atan2(-to.x, -to.z)
	pitch = deg_to_rad(pitch_deg)


func _target_point() -> Vector3:
	return target.global_position + Vector3.UP * _pivot_height


func _process(delta: float) -> void:
	if cinematic or not is_instance_valid(target):
		return
	if Game.is_playing():
		var kx := Input.get_axis(&"cam_left", &"cam_right")
		var ky := Input.get_axis(&"cam_down", &"cam_up")
		if absf(kx) > 0.0 or absf(ky) > 0.0:
			_idle_input = 0.0
		yaw -= kx * KEY_YAW * delta
		pitch += ky * KEY_PITCH * delta * (-1.0 if Settings.invert_y else 1.0)
		pitch = clampf(pitch, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
		_idle_input += delta
		_recenter(delta)

	# Camera zones: follow overrides apply directly, fixed and frame views blend in.
	var zone := _active_zone()
	_zone = zone
	if zone != null and zone.mode != "follow":
		_blend_zone = zone
	var want_dist := DISTANCE
	var want_fov := FOV
	var want_pivot := PIVOT_HEIGHT
	if zone != null and zone.mode == "follow":
		if zone.distance > 0.0:
			want_dist = zone.distance
		if zone.lock_pitch:
			pitch = deg_to_rad(zone.pitch_deg)
		if zone.lock_yaw:
			yaw = deg_to_rad(zone.yaw_deg)
		want_pivot += zone.pivot_raise
		if zone.fov > 0.0:
			want_fov = zone.fov
	var kz := 1.0 - exp(-4.0 * delta)
	_pivot_height = lerpf(_pivot_height, want_pivot, kz)
	_fov_s = lerpf(_fov_s, want_fov, kz)
	camera.fov = _fov_s

	var want := _target_point()
	var kxz := 1.0 - exp(-FOLLOW_XZ * delta)
	var ky2 := 1.0 - exp(-FOLLOW_Y * delta)
	_pivot_s = Vector3(lerpf(_pivot_s.x, want.x, kxz), lerpf(_pivot_s.y, want.y, ky2), lerpf(_pivot_s.z, want.z, kxz))
	# Never let vertical lag drop the pivot into the ground or leave the fox off-screen.
	_pivot_s.y = clampf(_pivot_s.y, want.y - 1.2, want.y + 1.2)
	var kr := 1.0 - exp(-ROTATE * delta)
	_yaw_s = lerp_angle(_yaw_s, yaw, kr)
	_pitch_s = lerpf(_pitch_s, pitch, kr)

	var dist := _collide(want_dist)
	_dist_s = dist if dist < _dist_s else move_toward(_dist_s, dist, ZOOM_OUT * delta)
	_place(_dist_s)

	var w_target := 1.0 if zone != null and zone.mode != "follow" else 0.0
	var bt := maxf((_blend_zone.blend_time if _blend_zone != null else 0.6), 0.01)
	_w = move_toward(_w, w_target, delta / bt)
	if _w > 0.0 and _blend_zone != null:
		var zx := _zone_transform(_blend_zone)
		_zone_xf = zx if _zone_xf == Transform3D.IDENTITY else _zone_xf.interpolate_with(zx, 1.0 - exp(-5.0 * delta))
		global_transform = global_transform.interpolate_with(_zone_xf, smoothstep(0.0, 1.0, _w))
	elif _w <= 0.0:
		_blend_zone = null
		_zone_xf = Transform3D.IDENTITY
	_update_fades()


func _recenter(delta: float) -> void:
	if _idle_input < RECENTER_DELAY or not (target is Node3D):
		return
	var body := Game.player
	if body == null or Vector2(body.velocity.x, body.velocity.z).length() < 2.0:
		return
	var heading := atan2(-body.velocity.x, -body.velocity.z)
	# Only drift when the player runs roughly away from the camera, never swing it round.
	if absf(angle_difference(yaw, heading)) > 1.4:
		return
	yaw = lerp_angle(yaw, heading, 1.0 - exp(-RECENTER_RATE * delta))


func _offset(dist: float) -> Vector3:
	return Basis(Vector3.UP, _yaw_s) * Basis(Vector3.RIGHT, _pitch_s) * Vector3(0, 0, dist)


## Pull the camera in when terrain or a solid prop is between it and the fox. Gates, saplings
## and the tree are left out (the camera may pass through a thorn tangle), and a probe that
## starts inside something is ignored rather than collapsing the camera onto the fox.
func _collide(dist: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis.IDENTITY, _pivot_s)
	q.motion = _offset(dist)
	q.collision_mask = Layers.WORLD
	q.exclude = _excluded()
	var frac := space.cast_motion(q)
	if not frac.is_empty() and frac[0] <= 0.0 and frac[1] <= 0.0:
		# The lagging pivot is touching something (a low ceiling, a shaft wall): cast a thin
		# probe from Orimi herself instead of giving up and leaving the camera in the wall.
		q.shape = _small_probe
		q.transform = Transform3D(Basis.IDENTITY, _target_point())
		frac = space.cast_motion(q)
		if not frac.is_empty() and frac[0] <= 0.0 and frac[1] <= 0.0:
			return MIN_DISTANCE
	if frac.is_empty() or frac[0] >= 1.0:
		return dist
	return clampf(dist * frac[0] - WALL_GAP, MIN_DISTANCE, dist)


## Bodies the camera passes through: brush targets (a thorn tangle, a sapling) and props
## that fade instead.
func _excluded() -> Array[RID]:
	var exclude: Array[RID] = []
	for group: StringName in [Layers.GROUP_BRUSH_TARGET, FADE_GROUP]:
		for n: Node in get_tree().get_nodes_in_group(group):
			if n is CollisionObject3D:
				exclude.append((n as CollisionObject3D).get_rid())
			for c: Node in n.find_children("*", "CollisionObject3D", true, false):
				exclude.append((c as CollisionObject3D).get_rid())
	return exclude


func _active_zone() -> CameraZone:
	if not is_instance_valid(target):
		return null
	var best: CameraZone = null
	for n: Node in get_tree().get_nodes_in_group(&"camera_zone"):
		var z := n as CameraZone
		if z != null and z.is_inside_tree() and z.contains(target.global_position) and (best == null or z.priority > best.priority):
			best = z
	return best


## Where a fixed or frame zone wants the camera, pulled in front of anything in the way.
func _zone_transform(z: CameraZone) -> Transform3D:
	var v := z.view_node()
	var focus := _target_point()
	if z.mode == "fixed":
		var xf := v.global_transform if v != null else global_transform
		if z.look_at_player and xf.origin.distance_to(focus) > 0.1:
			xf = xf.looking_at(focus, Vector3.UP)
		return xf
	var pts := z.frame_points()
	pts.append(focus)
	var center := Vector3.ZERO
	for p in pts:
		center += p
	center /= pts.size()
	var r := 0.0
	for p in pts:
		r = maxf(r, p.distance_to(center))
	r += z.margin
	var dir := -v.global_basis.z if v != null else -global_basis.z
	var half := deg_to_rad(_fov_s) * 0.5
	var aspect := get_viewport().get_visible_rect().size
	var half_min := minf(half, atan(tan(half) * aspect.x / maxf(aspect.y, 1.0)))
	var back := r / sin(half_min)
	if z.max_distance > 0.0:
		back = minf(back, z.max_distance)
	if z.stay_inside:
		back = minf(back, maxf(z.exit_distance(center, -dir) - WALL_GAP, MIN_DISTANCE))
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.motion = -dir * back
	q.collision_mask = Layers.WORLD
	q.exclude = _excluded()
	var frac := space.cast_motion(q)
	if not frac.is_empty() and frac[0] < 1.0 and not (frac[0] <= 0.0 and frac[1] <= 0.0):
		back = maxf(back * frac[0] - WALL_GAP, MIN_DISTANCE)
	var pos := center - dir * back
	return Transform3D(Basis.IDENTITY, pos).looking_at(center, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)


## Fade props in the group "camera_fade" while they stand between the camera and Orimi.
func _update_fades() -> void:
	var hiding := {}
	if is_instance_valid(target) and not get_tree().get_nodes_in_group(FADE_GROUP).is_empty():
		var space := get_world_3d().direct_space_state
		var exclude: Array[RID] = []
		for i in 4:
			var q := PhysicsRayQueryParameters3D.create(global_position, _target_point(), 0xFFFFFFFF)
			q.exclude = exclude
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			exclude.append(hit["rid"])
			var n := hit["collider"] as Node
			while n != null and not n.is_in_group(FADE_GROUP):
				n = n.get_parent()
			if n != null:
				hiding[n] = true
	for n: Node in hiding:
		if not _faded.has(n):
			_faded[n] = true
			Game.qa_log("camera_fade", {"prop": String(n.name)})
			_set_faded(n, true)
	for n: Node in _faded.keys():
		if not hiding.has(n):
			_faded.erase(n)
			if is_instance_valid(n):
				_set_faded(n, false)


func _set_faded(n: Node, on: bool) -> void:
	var looks := n.find_children("*", "InkLook", true, false)
	if looks.is_empty() and n is Node3D:
		looks.append(ModelKit.add_ink_look(n as Node3D))
	for l: Node in looks:
		(l as InkLook).set_dissolve(FADE_DISSOLVE if on else 0.0)


func _place(dist: float) -> void:
	global_position = _pivot_s + _offset(dist)
	var look_at_point := _pivot_s + Vector3.UP * 0.1
	if global_position.distance_to(look_at_point) > 0.01:
		look_at(look_at_point, Vector3.UP)


## Move to a world transform over duration seconds (cinematic mode stays on until release()).
func cinematic_to(pos: Vector3, look: Vector3, duration: float) -> Tween:
	cinematic = true
	var from := global_transform
	var to := Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP)
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(k: float) -> void:
		global_transform = from.interpolate_with(to, k), 0.0, 1.0, maxf(duration, 0.01))
	return t


func release() -> void:
	cinematic = false
	snap()
