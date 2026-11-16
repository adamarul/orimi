class_name LightPools
extends Node
## Lit places in the world, for every shader that writes its colour through ink_out(). Owner: render.
## Docs: docs/SHADERS.md, "Light pools".
##
## A level adds one LightPools node and gives it lights (id, position, radius, colour, strength).
## The MAX_DRAWN lights whose pools come nearest the camera are sent to the shaders each frame.
## Two level-wide amounts say what the pools push back:
##   drained  - outside the pools the place is grey, like an unpainted drawing (Tallowford)
##   darkness - outside the pools the place is multiplied down to shade_color (Mosswater Wood)
## Inside a pool the colour comes back, warmed toward the light's colour near its centre.
## Everything is off until a level sets it, and leaving the tree switches it all off again.

const MAX_DRAWN := 8
const WARM := Color(1.0, 0.84, 0.6)

## 0 colour everywhere, 1 grey outside the pools.
@export_range(0.0, 1.0) var drained: float = 0.0:
	set(v):
		drained = clampf(v, 0.0, 1.0)
		_dirty = true
## 0 no darkness, 1 the full shade outside the pools.
@export_range(0.0, 1.0) var darkness: float = 0.0:
	set(v):
		darkness = clampf(v, 0.0, 1.0)
		_dirty = true
## How strongly a light's colour warms the middle of its pool.
@export_range(0.0, 1.0) var warmth: float = 0.6:
	set(v):
		warmth = clampf(v, 0.0, 1.0)
		_dirty = true
## Multiplier at full darkness (display values).
@export var shade_color: Color = Color(0.3, 0.31, 0.39):
	set(v):
		shade_color = v
		_dirty = true
## Tint of the drained colour, multiplied (an amber-grey dusk by default; white for a neutral grey).
@export var drained_tint: Color = Color(1.0, 0.93, 0.8):
	set(v):
		drained_tint = v
		_dirty = true
## How much of its colour a drained surface keeps (0 = plain grey).
@export_range(0.0, 1.0) var drained_saturation: float = 0.35:
	set(v):
		drained_saturation = clampf(v, 0.0, 1.0)
		_dirty = true
## Beyond this view distance in metres drained and darkness thin out, so the sky keeps its colour.
@export var far_distance: float = 200.0:
	set(v):
		far_distance = v
		_dirty = true

var _lights := {}       # id -> [position: Vector3, radius: float, color: Color, strength: float]
var _tweens := {}
var _amount_tweens := {}
var _dirty := true
var _eye := Vector3.INF


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"light_field", Vector4.ZERO)
	for i in MAX_DRAWN:
		RenderingServer.global_shader_parameter_set(StringName("light_pool_%d" % i), Vector4.ZERO)
		RenderingServer.global_shader_parameter_set(StringName("light_tint_%d" % i), Vector4.ZERO)


## Add or move a light. radius in metres; strength 0..1 (0 is off, the pool is gone).
func set_light(id: StringName, at: Vector3, radius: float, color: Color = WARM, strength: float = 1.0) -> void:
	_kill(_tweens, id)
	_lights[id] = [at, radius, color, clampf(strength, 0.0, 1.0)]
	_dirty = true


## Light a pool over duration seconds: it grows from a third of its radius and fades in, fast then
## easing, the way a lamp catches.
func light_up(id: StringName, at: Vector3, radius: float, color: Color = WARM, strength: float = 1.0, duration: float = 1.0) -> void:
	_kill(_tweens, id)
	_lights[id] = [at, radius * 0.35, color, 0.0]
	_dirty = true
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float) -> void:
		_lights[id] = [at, radius * lerpf(0.35, 1.0, k), color, strength * k]
		_dirty = true, 0.0, 1.0, maxf(duration, 0.01))
	_tweens[id] = tw


func remove_light(id: StringName) -> void:
	_kill(_tweens, id)
	if _lights.erase(id):
		_dirty = true


func clear_lights() -> void:
	for id: StringName in _lights.keys():
		remove_light(id)


func has_light(id: StringName) -> bool:
	return _lights.has(id)


## Animate drained to value over duration seconds (0 = at once).
func set_drained(value: float, duration: float = 0.0) -> void:
	_animate(&"drained", value, duration)


## Animate darkness to value over duration seconds (0 = at once).
func set_darkness(value: float, duration: float = 0.0) -> void:
	_animate(&"darkness", value, duration)


func _animate(property: StringName, value: float, duration: float) -> void:
	_kill(_amount_tweens, property)
	if duration <= 0.0:
		set(property, value)
		return
	var tw := create_tween()
	tw.tween_property(self, NodePath(property), clampf(value, 0.0, 1.0), duration)
	_amount_tweens[property] = tw


func _kill(tweens: Dictionary, key: StringName) -> void:
	if tweens.has(key):
		(tweens[key] as Tween).kill()
		tweens.erase(key)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3.ZERO
	if not _dirty and eye.distance_squared_to(_eye) < 0.25:
		return
	_dirty = false
	_eye = eye
	var ids: Array = _lights.keys()
	if ids.size() > MAX_DRAWN:
		var gap := func(id: StringName) -> float: return eye.distance_to(_lights[id][0]) - float(_lights[id][1])
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return gap.call(a) < gap.call(b))
		ids.resize(MAX_DRAWN)
	var any := false
	for i in MAX_DRAWN:
		var pool := Vector4.ZERO
		var tint := Vector4.ZERO
		if i < ids.size():
			var l: Array = _lights[ids[i]]
			var at: Vector3 = l[0]
			var c: Color = l[2]
			pool = Vector4(at.x, at.y, at.z, l[1])
			tint = Vector4(c.r, c.g, c.b, l[3])
			any = any or (float(l[1]) > 0.0 and float(l[3]) > 0.0)
		RenderingServer.global_shader_parameter_set(StringName("light_pool_%d" % i), pool)
		RenderingServer.global_shader_parameter_set(StringName("light_tint_%d" % i), tint)
	RenderingServer.global_shader_parameter_set(&"light_field", Vector4(drained, darkness, warmth, 1.0 if any else 0.0))
	RenderingServer.global_shader_parameter_set(&"light_shade", Vector4(shade_color.r, shade_color.g, shade_color.b, far_distance))
	RenderingServer.global_shader_parameter_set(&"light_tint", Vector4(drained_tint.r, drained_tint.g, drained_tint.b, drained_saturation))
