class_name VfxRibbon
extends MeshInstance3D
## A dry-brush ribbon strip (fx_ribbon.gdshader), rebuilt on the 12 fps grid. Owner: vfx.
## Used one-shot by the Vfx director for the slash glyph and the tail-swipe arc: play() lays a
## path, then step() reveals it head first, erodes it and hides it. VfxTrail extends this for
## ribbons that follow a node.

var playing := false
var age := 0.0
var duration := 0.3
var _path := PackedVector3Array()
var _widths := PackedFloat32Array()
var _imesh: ImmediateMesh


func _init() -> void:
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	visible = false


## Starts a one-shot ribbon along path (world points) with the given half widths per point,
## lasting duration seconds.
func play(path: PackedVector3Array, half_widths: PackedFloat32Array, p_duration: float) -> void:
	_path = path
	_widths = half_widths
	duration = p_duration
	age = 0.0
	playing = true
	_show_at(0.0)


func step(dt: float) -> void:
	if not playing:
		return
	age += dt
	if age >= duration:
		playing = false
		visible = false
		_imesh.clear_surfaces()
		return
	_show_at(age)


func _show_at(a: float) -> void:
	var t := clampf((a + 1.0 / 12.0) / duration, 0.0, 1.0)
	var head := clampf(t * 2.4, 0.0, 1.0)
	var tail := clampf((t - 0.55) * 2.0, 0.0, 1.0)
	var erode := clampf((t - 0.6) * 1.8, 0.0, 1.0)
	var us := PackedFloat32Array()
	us.resize(_path.size())
	for i in _path.size():
		us[i] = float(i) / maxf(_path.size() - 1, 1)
	build(_path, _widths, us, us, erode, head, tail)


## Writes the strip. us = texture u per point (0 head .. 1 tail), arcs = reveal parameter.
func build(points: PackedVector3Array, half_widths: PackedFloat32Array, us: PackedFloat32Array,
		arcs: PackedFloat32Array, erode: float, head: float, tail: float) -> void:
	_imesh.clear_surfaces()
	var n := points.size()
	if n < 2:
		visible = false
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, n - 1)]
		var tangent := (b - a)
		tangent = tangent.normalized() if tangent.length() > 0.00001 else Vector3.RIGHT
		for side in 2:
			_imesh.surface_set_normal(tangent)
			_imesh.surface_set_color(Color(half_widths[i], erode, head, tail))
			_imesh.surface_set_uv(Vector2(us[i], float(side)))
			_imesh.surface_set_uv2(Vector2(arcs[i], 0.0))
			_imesh.surface_add_vertex(points[i])
	_imesh.surface_end()
	visible = true
