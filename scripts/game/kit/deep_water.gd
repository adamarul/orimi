class_name DeepWater
extends Node3D
## Water too deep to wade: a box around this node, its top at the node's height. When Orimi gets
## into it she splashes and is put back on the bank she left (the last ground she stood on
## outside the water), with no damage. Place it over a river, a pool or a moat; the level's own
## ground may run under it or stop at the bank. Owner: gameplay.

## A box: x and z across the water, y how far below the surface it reaches.
@export var size: Vector3 = Vector3(6, 3, 6)
## Draw a water surface over the box (the shared water material). Off when the level models its
## own water.
@export var show_surface: bool = true
## Orimi counts as in the water once her feet are this far below the surface...
@export var sink: float = 0.0
## ...and she is put back at least this far (across the ground) from where she went in...
@export var bank_margin: float = 0.8
## ...on ground at least this far above the surface (a sloping shore inside the box counts as
## bank only from here up; ground outside the box always does).
@export var bank_height: float = 0.25
## After a return she stands still this long, so a held direction cannot walk her straight back in.
@export var return_hold: float = 0.4
## Set the first time she is put back (for a hint or a route check). Empty: none.
@export var flag: StringName = &""

const WATER_MATERIAL := "res://materials/env/water.tres"

## Times Orimi was put back.
var returns := 0
## Recent ground she stood on that counts as bank, oldest first, about 0.3 m apart.
var _banks: Array[Vector3] = []
var _returned_at := -100.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"deep_water")
	if show_surface:
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(size.x, size.z)
		mi.mesh = plane
		mi.position.y = 0.02
		mi.material_override = load(WATER_MATERIAL) as Material
		mi.set_meta(&"ink_skip", true)
		add_child(mi)
	# The splash ring is built and drawn (almost invisibly small) from the start, so the web build
	# compiles its material at load rather than at the first splash.
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1, 1, 1, 0)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.set_meta(&"ink_skip", true)
	_ring.scale = Vector3.ONE * 0.001
	add_child(_ring)


func contains(pos: Vector3, margin: float = 0.0) -> bool:
	var l := global_transform.affine_inverse() * pos
	return absf(l.x) < size.x * 0.5 + margin and absf(l.z) < size.z * 0.5 + margin \
		and l.y < -sink + 0.05 and l.y > -size.y


func _physics_process(_delta: float) -> void:
	var p := Game.player as OrimiPlayer
	if not is_instance_valid(p) or p.dead or not Game.is_playing():
		return
	var pos := p.global_position
	if not contains(pos):
		if p.is_on_floor() and _is_bank(pos) and (_banks.is_empty() or _flat(_banks.back() - pos) > 0.3):
			_banks.append(pos)
			if _banks.size() > 24:
				_banks.pop_front()
		return
	var now := Time.get_ticks_msec() / 1000.0
	var to := _bank_for(pos)
	# Back in again the moment she could move: the bank point itself is no good, so step out of
	# the box altogether.
	if now - _returned_at < return_hold + 0.15 or contains(to):
		to = _nearest_bank(pos)
		_banks.clear()
	_returned_at = now
	_splash(pos)
	p.teleport(to + Vector3.UP * 0.05, p.rotation.y)
	p.hold_still(return_hold)
	returns += 1
	Events.player_thrown_back.emit(Vector3(pos.x, global_position.y, pos.z), &"water")
	Game.qa_log("deep_water_return", {"water": String(name), "from": Game._v(pos), "to": Game._v(to)})
	if flag != &"" and Game.level != null:
		Game.level.set_flag(flag)


func _splash(at: Vector3) -> void:
	_ring.global_position = Vector3(at.x, global_position.y + 0.05, at.z)
	_ring.scale = Vector3(0.4, 0.3, 0.4)
	_ring_mat.albedo_color = Color(1, 1, 1, 0.85)
	var t := create_tween().set_parallel()
	t.tween_property(_ring, "scale", Vector3(2.2, 0.3, 2.2), 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(_ring_mat, "albedo_color:a", 0.0, 0.5)
	t.chain().tween_property(_ring, "scale", Vector3.ONE * 0.001, 0.0)


## Ground outside the box footprint, or inside it but bank_height above the surface.
func _is_bank(pos: Vector3) -> bool:
	var l := global_transform.affine_inverse() * pos
	return absf(l.x) > size.x * 0.5 or absf(l.z) > size.z * 0.5 or l.y > bank_height


## The newest bank point at least bank_margin from where she went in (else the oldest kept).
func _bank_for(entered: Vector3) -> Vector3:
	for i in range(_banks.size() - 1, -1, -1):
		if _flat(_banks[i] - entered) >= bank_margin:
			return _banks[i]
	return _banks[0] if not _banks.is_empty() else _nearest_bank(entered)


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## A point just outside the nearest edge, for when she never stood on a bank (spawned in it).
func _nearest_bank(pos: Vector3) -> Vector3:
	var l := global_transform.affine_inverse() * pos
	var hx := size.x * 0.5 + bank_margin
	var hz := size.z * 0.5 + bank_margin
	if hx - absf(l.x) < hz - absf(l.z):
		l.x = signf(l.x if l.x != 0.0 else 1.0) * hx
	else:
		l.z = signf(l.z if l.z != 0.0 else 1.0) * hz
	l.y = 0.0
	var p := global_transform * l
	return Game.level.ground_at(p + Vector3.UP * 2.0) if Game.level != null else p
