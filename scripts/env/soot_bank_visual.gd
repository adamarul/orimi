extends Node3D
## scenes/env/soot_bank_visual.tscn: the hanging soot wall across a path. Owner: vfx.
## Dozens of soot clumps (fx_sprite.gdshader, soot look) hang in a slab width x height x depth,
## rooted on the ground at this node and facing along Z. They breathe in 12 fps steps; clear()
## (also callable as blow_away()) blows them apart along a direction and they soak away.
## Visual only: collision and the soot_cleared event belong to gameplay.

signal cleared

const SPRITE_SHADER := preload("res://shaders/vfx/fx_sprite.gdshader")
const STEP := 1.0 / 12.0

@export var width := 6.6
@export var height := 3.2
@export var depth := 1.0
## Clumps per square metre of the wall's face.
@export var density := 2.6
@export var seed := 11
## Clump size range in metres.
@export var clump_size := Vector2(0.9, 1.7)

var is_blowing := false
var is_cleared := false

var _mmi: MultiMeshInstance3D
var _rest := PackedVector3Array()
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _size := PackedFloat32Array()
var _rot := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _frame := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _delay := PackedFloat32Array()
var _buf := PackedFloat32Array()
var _time := 0.0
var _blow_time := 0.0
var _acc := 0.0

static var _material: ShaderMaterial


func _ready() -> void:
	_mmi = $Clumps as MultiMeshInstance3D
	_mmi.add_to_group(&"ink_skip")
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SPRITE_SHADER
		_material.set_shader_parameter(&"atlas", load("res://assets/textures/vfx/soot.png"))
		_material.set_shader_parameter(&"atlas_grid", Vector2(4, 2))
		_material.set_shader_parameter(&"look", 4)
		_material.set_shader_parameter(&"align", 0)
		_material.set_shader_parameter(&"color_a", Palette.CURSE_INK)
		_material.set_shader_parameter(&"color_b", Color("5f5a55"))
		_material.set_shader_parameter(&"cutoff", 0.5)
	_mmi.material_override = _material
	reset()


## Rebuilds the wall in place (after a clear, or when the settings change).
func reset() -> void:
	is_blowing = false
	is_cleared = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := maxi(4, int(width * height * density))
	_rest.resize(n)
	_pos.resize(n)
	_vel.resize(n)
	_size.resize(n)
	_rot.resize(n)
	_spin.resize(n)
	_frame.resize(n)
	_phase.resize(n)
	_delay.resize(n)
	_buf.resize(n * 20)
	for i in n:
		var x := rng.randf_range(-0.5, 0.5) * width
		var edge := 1.0 - pow(absf(x) / (width * 0.5), 3.0)
		var bottom := 0.25 + rng.randf() * 0.5 + (1.0 - edge) * height * 0.35
		var top := height * (0.82 + 0.18 * edge)
		var y := lerpf(bottom, top, pow(rng.randf(), 0.7))
		_rest[i] = Vector3(x, y, rng.randf_range(-0.5, 0.5) * depth)
		_pos[i] = _rest[i]
		_vel[i] = Vector3.ZERO
		_size[i] = rng.randf_range(clump_size.x, clump_size.y) * (0.75 + 0.25 * edge)
		_rot[i] = rng.randf() * TAU
		_spin[i] = 0.0
		_frame[i] = float(rng.randi_range(0, 7))
		_phase[i] = rng.randf() * TAU
		_delay[i] = 0.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = n
	_mmi.multimesh = mm
	_mmi.custom_aabb = AABB(Vector3(-width - 30.0, -2.0, -30.0), Vector3(width * 2.0 + 60.0, height + 20.0, 60.0))
	_mmi.visible = true
	_write(0.0)


## Blows the wall apart along direction (world space; flattened). Zero means away from the
## camera. Emits cleared when the last clump has soaked away.
func clear(direction: Vector3 = Vector3.ZERO) -> void:
	if is_blowing or is_cleared:
		return
	var dir := direction
	dir.y = 0.0
	if dir.length() < 0.01:
		var cam := get_viewport().get_camera_3d()
		dir = -cam.global_basis.z if cam != null else -global_basis.z
		dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var local_dir := global_basis.inverse() * dir
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 99
	var side := dir.cross(Vector3.UP)
	for i in _pos.size():
		var lead := (global_basis * _rest[i]).dot(-side) / maxf(width, 0.1) + 0.5
		_delay[i] = clampf(lead, 0.0, 1.0) * 0.25 + rng.randf() * 0.12
		var v := local_dir * rng.randf_range(7.0, 13.0) + Vector3.UP * rng.randf_range(0.6, 3.0)
		v += Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)) * 1.5
		_vel[i] = v
		_spin[i] = rng.randf_range(-3.0, 3.0)
	is_blowing = true
	_blow_time = 0.0


## Same as clear(): the name gameplay's GlyphObstacle calls.
func blow_away(direction: Vector3 = Vector3.ZERO) -> void:
	clear(direction)


func _process(delta: float) -> void:
	if is_cleared:
		return
	_acc += delta
	while _acc >= STEP:
		_acc -= STEP
		_time += STEP
		_step()


func _step() -> void:
	if is_blowing:
		_blow_time += STEP
		for i in _pos.size():
			if _blow_time < _delay[i]:
				continue
			_vel[i] *= 0.86
			_pos[i] += _vel[i] * STEP
			_rot[i] += _spin[i] * STEP
		_write(_blow_time)
		if _blow_time > 1.6:
			is_blowing = false
			is_cleared = true
			_mmi.visible = false
			cleared.emit()
		return
	for i in _pos.size():
		var ph := _phase[i]
		_pos[i] = _rest[i] + Vector3(sin(_time * 0.8 + ph) * 0.06, sin(_time * 1.2 + ph * 1.7) * 0.08, 0.0)
	_write(0.0)


func _write(blow: float) -> void:
	var b := global_basis
	for i in _pos.size():
		var o := i * 20
		var erode := 0.0
		if is_blowing:
			erode = clampf((blow - _delay[i] - 0.05) / 1.0, 0.0, 1.0)
		var s := _size[i] * (1.0 + erode * 0.4)
		var p := b * _pos[i] + global_position
		var rot := _rot[i] + (sin(_time * 0.6 + _phase[i]) * 0.08 if not is_blowing else 0.0)
		_buf[o + 0] = s
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = p.x
		_buf[o + 4] = 0.0
		_buf[o + 5] = s
		_buf[o + 6] = 0.0
		_buf[o + 7] = p.y
		_buf[o + 8] = 0.0
		_buf[o + 9] = 0.0
		_buf[o + 10] = 1.0
		_buf[o + 11] = p.z
		_buf[o + 12] = 1.0
		_buf[o + 13] = 1.0
		_buf[o + 14] = 1.0
		_buf[o + 15] = 1.0
		_buf[o + 16] = _frame[i]
		_buf[o + 17] = erode
		_buf[o + 18] = rot
		_buf[o + 19] = 1.0
	_mmi.multimesh.buffer = _buf
