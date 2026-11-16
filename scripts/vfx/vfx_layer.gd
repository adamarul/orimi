class_name VfxLayer
extends MultiMeshInstance3D
## One batched pool of effect sprites: every particle of every effect that shares a look is an
## instance of this one MultiMesh, so a layer is one draw call however many effects are playing.
## Owner: vfx. The Vfx director owns the layers and calls step() on the 12 fps grid, so nothing
## here moves between steps and everything freezes while the tree is paused.
##
## Particles live in dense parallel arrays; a dead particle is swapped with the last one.
## Instance data written for fx_sprite.gdshader / fx_glow.gdshader: transform (origin, size,
## direction), CUSTOM = (frame [+64 mirrors], erode, rotation, stroke head), COLOR = (tint, tail).

enum Align { BILLBOARD, GROUND, UPRIGHT, DIRECTIONAL }

const FLOATS := 20

var align: int = Align.BILLBOARD
var capacity := 0
var count := 0
## Spawn options used when a spawn() call does not give them.
var defaults := {}

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _dir := PackedVector3Array()
var _size := PackedVector2Array()
var _f := PackedFloat32Array()  # per particle: see the F_ offsets
var _tint := PackedColorArray()
var _buf := PackedFloat32Array()

const F_AGE := 0
const F_LIFE := 1
const F_GRAV := 2
const F_DRAG := 3
const F_ROT := 4
const F_SPIN := 5
const F_FRAME := 6
const F_GROW := 7
const F_ERODE := 8
const F_SHRINK := 9
const F_GROUND := 10
const F_FLUTTER := 11
const F_DRAW := 12
const F_TAIL := 13
const F_DELAY := 14
const F_PHASE := 15
const F_N := 16


func setup(p_capacity: int, p_align: int, material: Material, p_defaults: Dictionary = {}) -> void:
	capacity = p_capacity
	align = p_align
	defaults = p_defaults
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	_buf.resize(capacity * FLOATS)
	_pos.resize(capacity)
	_vel.resize(capacity)
	_dir.resize(capacity)
	_size.resize(capacity)
	_tint.resize(capacity)
	_f.resize(capacity * F_N)
	visible = false


func _opt(o: Dictionary, key: StringName, fallback: Variant) -> Variant:
	if o.has(key):
		return o[key]
	return defaults.get(key, fallback)


## Adds one particle. size is (width, height) in metres. Options (all optional): tint (Color),
## gravity, drag, rot, spin, grow (seconds to reach full size), erode (fraction of life when
## erosion starts), shrink (0..1, how much it shrinks while eroding), ground (y it lands on),
## flutter (metres of side-to-side tumble), draw (seconds for a stroke to draw on), tail
## (seconds before the stroke's tail starts to follow), delay (seconds hidden), dir (Vector3,
## for DIRECTIONAL), mirror (bool). Returns false when the layer is full.
func spawn(p: Vector3, v: Vector3, size: Vector2, life: float, frame: int, o: Dictionary = {}) -> bool:
	if count >= capacity:
		return false
	var i := count
	count += 1
	_pos[i] = p
	_vel[i] = v
	var d: Vector3 = _opt(o, &"dir", v)
	_dir[i] = d.normalized() if d.length() > 0.0001 else Vector3.RIGHT
	_size[i] = size
	_tint[i] = _opt(o, &"tint", Color.WHITE)
	var b := i * F_N
	_f[b + F_AGE] = 0.0
	_f[b + F_LIFE] = maxf(life, 0.01)
	_f[b + F_GRAV] = _opt(o, &"gravity", 0.0)
	_f[b + F_DRAG] = _opt(o, &"drag", 0.0)
	_f[b + F_ROT] = _opt(o, &"rot", 0.0)
	_f[b + F_SPIN] = _opt(o, &"spin", 0.0)
	_f[b + F_FRAME] = float(frame) + (64.0 if bool(_opt(o, &"mirror", false)) else 0.0)
	_f[b + F_GROW] = _opt(o, &"grow", 0.0)
	_f[b + F_ERODE] = _opt(o, &"erode", 0.6)
	_f[b + F_SHRINK] = _opt(o, &"shrink", 0.0)
	_f[b + F_GROUND] = _opt(o, &"ground", -1.0e9)
	_f[b + F_FLUTTER] = _opt(o, &"flutter", 0.0)
	_f[b + F_DRAW] = _opt(o, &"draw", 0.0)
	_f[b + F_TAIL] = _opt(o, &"tail", 1.0e9)
	_f[b + F_DELAY] = _opt(o, &"delay", 0.0)
	_f[b + F_PHASE] = randf() * TAU
	return true


## Rewrites the instance buffer now (step() does this on its own).
func refresh() -> void:
	_write()


func clear() -> void:
	count = 0
	multimesh.visible_instance_count = 0
	visible = false


## Advances every particle by dt (one 12 fps step) and rewrites the instance buffer.
func step(dt: float) -> void:
	if count == 0:
		if visible:
			clear()
		return
	var i := 0
	while i < count:
		var b := i * F_N
		var age := _f[b + F_AGE] + dt
		if age >= _f[b + F_LIFE]:
			_remove(i)
			continue
		_f[b + F_AGE] = age
		if age > _f[b + F_DELAY]:
			var v := _vel[i]
			v.y -= _f[b + F_GRAV] * dt
			v *= maxf(0.0, 1.0 - _f[b + F_DRAG] * dt)
			var p := _pos[i] + v * dt
			var ground := _f[b + F_GROUND]
			if p.y < ground:
				p.y = ground
				v = Vector3.ZERO
				_f[b + F_GRAV] = 0.0
				_f[b + F_SPIN] = 0.0
				_f[b + F_FLUTTER] = 0.0
			_vel[i] = v
			_pos[i] = p
			_f[b + F_ROT] += _f[b + F_SPIN] * dt
		i += 1
	_write()


func _remove(i: int) -> void:
	var last := count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_dir[i] = _dir[last]
		_size[i] = _size[last]
		_tint[i] = _tint[last]
		var b := i * F_N
		var bl := last * F_N
		for k in F_N:
			_f[b + k] = _f[bl + k]
	count = last


func _write() -> void:
	for i in count:
		var b := i * F_N
		var o := i * FLOATS
		var age := _f[b + F_AGE] - _f[b + F_DELAY]
		var life := _f[b + F_LIFE] - _f[b + F_DELAY]
		var t := clampf(age / maxf(life, 0.001), 0.0, 1.0)
		var s := _size[i]
		var k := 1.0
		var grow := _f[b + F_GROW]
		if age < 0.0:
			k = 0.0
		elif grow > 0.0:
			k = clampf((age + 1.0 / 12.0) / grow, 0.0, 1.0)
		var erode_from := _f[b + F_ERODE]
		var erode := 0.0
		if t > erode_from:
			erode = (t - erode_from) / maxf(1.0 - erode_from, 0.001)
			k *= 1.0 - erode * _f[b + F_SHRINK]
		var sx := s.x * k
		var sy := s.y * k
		var p := _pos[i]
		var flutter := _f[b + F_FLUTTER]
		var rot := _f[b + F_ROT]
		if flutter > 0.0:
			var ph := _f[b + F_PHASE] + age * 5.0
			p += Vector3(cos(ph * 0.7), 0.0, sin(ph * 0.9)) * flutter
			sx *= maxf(0.2, absf(cos(ph * 1.3)))
		var bx := Vector3(sx, 0.0, 0.0)
		var by := Vector3(0.0, sy, 0.0)
		var bz := Vector3(0.0, 0.0, 1.0)
		if align == Align.GROUND:
			bx = Vector3(cos(rot), 0.0, sin(rot)) * sx
			by = Vector3(-sin(rot), 0.0, cos(rot)) * sy
			bz = Vector3.UP
		elif align == Align.DIRECTIONAL:
			var d := _vel[i]
			bx = (d.normalized() if d.length() > 0.05 else _dir[i]) * sx
		_buf[o + 0] = bx.x
		_buf[o + 1] = by.x
		_buf[o + 2] = bz.x
		_buf[o + 3] = p.x
		_buf[o + 4] = bx.y
		_buf[o + 5] = by.y
		_buf[o + 6] = bz.y
		_buf[o + 7] = p.y
		_buf[o + 8] = bx.z
		_buf[o + 9] = by.z
		_buf[o + 10] = bz.z
		_buf[o + 11] = p.z
		var c := _tint[i]
		var draw := _f[b + F_DRAW]
		var head := 1.0
		var tail := 0.0
		if draw > 0.0:
			head = clampf((age + 1.0 / 12.0) / draw, 0.0, 1.0)
			tail = clampf((age - _f[b + F_TAIL]) / draw, 0.0, 1.0)
		_buf[o + 12] = c.r
		_buf[o + 13] = c.g
		_buf[o + 14] = c.b
		_buf[o + 15] = tail if draw > 0.0 else c.a * (1.0 - erode)
		_buf[o + 16] = _f[b + F_FRAME]
		_buf[o + 17] = erode
		_buf[o + 18] = rot
		_buf[o + 19] = head
	multimesh.buffer = _buf
	multimesh.visible_instance_count = count
	visible = count > 0
