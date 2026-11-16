extends Node3D
## Render demo (scenes/dev/render_demo.tscn): primitives and the phase 0 glTF under InkLook,
## a procedural branch with painted vertex-colour weights (taper, dry brush), a sacred gate,
## a gold interactive lantern, a character-preset stand-in with a blob shadow, a dissolving
## and flashing object, a cursed zone that restores and re-curses on a timer, and distant
## hills for the paper fade. Owner: render.
##
## Boot options: view=main|line|rim|front|char (camera), curse=cycle|cursed|clean|<0..1>
## (zone state; a number holds the zone at that amount), gloom=<0..1>, post=0 (disable the
## chain), perf=1 (print ORIMI_RENDER_PERF lines with CPU and GPU frame times), orbit=1.

const ZONE_CENTER := Vector3(-7.0, 0.0, -5.0)
const ZONE_RADIUS := 9.0
const VIEWS := {
	"main": [Vector3(1.5, 7.0, 17.0), Vector3(-1.0, 1.0, -2.0)],
	"line": [Vector3(7.5, 3.2, 3.2), Vector3(4.5, 2.0, -2.0)],
	"rim": [Vector3(4.0, 3.0, 5.0), Vector3(-2.5, 0.6, -3.5)],
	"front": [Vector3(-7.0, 17.0, 9.0), Vector3(-7.0, 0.0, -5.0)],
	"char": [Vector3(5.0, 2.2, 8.0), Vector3(3.0, 0.7, 4.0)],
}

var _camera: Camera3D
var _dissolver: InkLook
var _flasher: InkLook
var _cycle_cursed := true
var _perf := false
var _perf_t := 0.0
var _perf_frames := 0
var _orbit := false
var _t := 0.0


func _ready() -> void:
	_build_world()
	var view := String(Boot.opt("view", "main"))
	var v: Array = VIEWS.get(view, VIEWS.main)
	_camera.look_at_from_position(v[0], v[1])
	_orbit = Boot.opt("orbit", "0") == "1"
	Post.set_enabled(Boot.opt("post", "1") != "0")
	CurseField.set_valley_gloom(float(Boot.opt("gloom", "1")))
	var curse := String(Boot.opt("curse", "cycle"))
	match curse:
		"cycle":
			CurseField.set_zone(0, ZONE_CENTER, ZONE_RADIUS, 1.0)
			_cycle()
		"clean":
			CurseField.set_zone(0, ZONE_CENTER, ZONE_RADIUS, 0.0)
		"cursed":
			CurseField.set_zone(0, ZONE_CENTER, ZONE_RADIUS, 1.0)
		_:
			CurseField.set_zone(0, ZONE_CENTER, ZONE_RADIUS, float(curse))
	if Boot.opt("glow", "") == "debug":
		var paper := Post.get_node("Paper").material as ShaderMaterial
		paper.set_shader_parameter(&"glow_strength", 1.0)
		paper.set_shader_parameter(&"glow_threshold", 0.3)
	if Boot.opt("creases", "") == "only":
		(Post.get_node("Ink3D").material_override as ShaderMaterial).set_shader_parameter(&"debug_creases_only", true)
	_perf = Boot.opt("perf", "0") == "1"
	if _perf:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(delta: float) -> void:
	_t += delta
	_dissolver.set_dissolve(clampf(fmod(_t, 4.0) / 3.0, 0.0, 1.0))
	if fmod(_t, 1.5) < delta:
		_flasher.flash(Color(Palette.VERMILION), 0.25)
	if _orbit:
		var a := _t * 0.15
		_camera.look_at_from_position(Vector3(sin(a) * 18.0, 7.0, cos(a) * 18.0), Vector3(-1.0, 1.0, -2.0))
	_perf_frames += 1
	_perf_t += delta
	if _perf_t >= 1.0:
		var fps := _perf_frames / _perf_t
		print("ORIMI_FPS fps=%d" % roundi(fps))
		if _perf:
			var vp := get_viewport().get_viewport_rid()
			print("ORIMI_RENDER_PERF fps=%.1f frame_ms=%.2f cpu_render_ms=%.3f gpu_render_ms=%.3f size=%s post=%s" % [
				fps, 1000.0 / fps,
				RenderingServer.viewport_get_measured_render_time_cpu(vp),
				RenderingServer.viewport_get_measured_render_time_gpu(vp),
				get_viewport().get_visible_rect().size, Post.enabled])
		_perf_frames = 0
		_perf_t = 0.0


func _cycle() -> void:
	while is_inside_tree():
		await get_tree().create_timer(3.5).timeout
		if _cycle_cursed:
			CurseField.restore_zone(0, 2.5)
		else:
			CurseField.curse_zone(0, 2.0)
		_cycle_cursed = not _cycle_cursed


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Palette.SKY
	add_child(env)

	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.make_current()

	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(400.0, 1.0, 400.0)
	shape.position.y = -0.5
	ground.add_child(shape)
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	plane.subdivide_width = 40
	plane.subdivide_depth = 40
	ground.add_child(_mesh(plane, Palette.SAGE, Vector3.ZERO))
	_add_look(ground, 0.0)
	add_child(ground)

	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 1.6, 1.6)
	props.add_child(_mesh(box, Palette.STONE, Vector3(-1.5, 0.8, -1.0), Vector3(0.0, 0.5, 0.0)))
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	rock.radius = 1.3
	rock.height = 1.8
	props.add_child(_mesh(rock, Palette.STONE_DARK.lightened(0.15), Vector3(2.5, 0.6, -4.5)))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.5
	cyl.height = 3.2
	props.add_child(_mesh(cyl, Palette.PARCHMENT_WARM, Vector3(6.5, 1.6, -5.0)))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 1.0
	props.add_child(_mesh(torus, Palette.SAGE_DEEP, Vector3(-3.5, 1.2, 3.0), Vector3(1.2, 0.3, 0.0)))
	var prism := PrismMesh.new()
	prism.size = Vector3(2.0, 2.0, 1.4)
	props.add_child(_mesh(prism, Palette.MOSS.lightened(0.2), Vector3(-10.0, 1.0, -8.0)))
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	props.add_child(_mesh(sphere, Palette.SAGE, Vector3(-5.0, 0.8, -3.0)))
	var branch_root := Node3D.new()
	branch_root.add_child(_branch(Vector3(3.2, 2.2, -2.2)))
	var branch_look := _add_look(branch_root, 1.0)
	branch_look.wind = true
	add_child(branch_root)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.25
	post_mesh.bottom_radius = 0.3
	post_mesh.height = 2.5
	props.add_child(_mesh(post_mesh, Palette.STONE, Vector3(-9.5, 1.25, -2.0)))
	_add_look(props, 1.0)

	var glb: PackedScene = load("res://assets/phase0/vcol_probe.glb")
	var probe := Node3D.new()
	probe.position = Vector3(0.5, 0.7, 2.5)
	probe.add_child(glb.instantiate())
	_add_look(probe, 1.0)
	add_child(probe)

	# sacred gate inside the cursed zone: keeps its colour, vermilion accent
	var gate := Node3D.new()
	gate.position = Vector3(-8.5, 0.0, -6.5)
	var red := StandardMaterial3D.new()
	red.albedo_color = Palette.VERMILION
	red.resource_name = "gate_sacred"
	for x in [-1.1, 1.1]:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.14
		pole.bottom_radius = 0.17
		pole.height = 2.8
		gate.add_child(_mesh_mat(pole, red, Vector3(x, 1.4, 0.0)))
	var beam := BoxMesh.new()
	beam.size = Vector3(3.2, 0.25, 0.35)
	gate.add_child(_mesh_mat(beam, red, Vector3(0.0, 2.75, 0.0)))
	_add_look(gate, 0.8, &"vermilion")
	add_child(gate)

	# gold interactive lantern, outside the zone
	var lantern := Node3D.new()
	lantern.position = Vector3(1.0, 0.0, -6.0)
	var lbox := BoxMesh.new()
	lbox.size = Vector3(0.6, 0.9, 0.6)
	lantern.add_child(_mesh(lbox, Palette.GOLD_PALE, Vector3(0.0, 1.2, 0.0)))
	var lpost := CylinderMesh.new()
	lpost.top_radius = 0.08
	lpost.bottom_radius = 0.1
	lpost.height = 0.8
	lantern.add_child(_mesh(lpost, Palette.STONE_DARK, Vector3(0.0, 0.4, 0.0)))
	_add_look(lantern, 1.0, &"gold")
	add_child(lantern)

	# character-preset stand-in with a blob shadow
	var body := Node3D.new()
	body.position = Vector3(3.0, 0.0, 4.0)
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.1
	var torso := _mesh(cap, Palette.IVORY, Vector3(0.0, 0.62, 0.0), Vector3(PI / 2.0, 0.0, 0.0))
	body.add_child(torso)
	var head := SphereMesh.new()
	head.radius = 0.24
	head.height = 0.48
	body.add_child(_mesh(head, Palette.IVORY, Vector3(0.0, 0.95, -0.55)))
	var ear := PrismMesh.new()
	ear.size = Vector3(0.16, 0.26, 0.08)
	for x in [-0.12, 0.12]:
		body.add_child(_mesh(ear, Palette.STONE.lightened(0.3), Vector3(x, 1.22, -0.55)))
	var look := _add_look(body, 1.0)
	look.line_style = &"character"
	look.apply()
	body.add_child(preload("res://scenes/render/blob_shadow.tscn").instantiate())
	add_child(body)

	# dissolving and flashing objects
	var dnode := Node3D.new()
	dnode.position = Vector3(6.0, 0.0, 1.0)
	var dsph := SphereMesh.new()
	dsph.radius = 0.7
	dsph.height = 1.4
	dnode.add_child(_mesh(dsph, Palette.INK_SOFT.lightened(0.15), Vector3(0.0, 0.7, 0.0)))
	_dissolver = _add_look(dnode, 1.0)
	add_child(dnode)
	var fnode := Node3D.new()
	fnode.position = Vector3(-2.0, 0.0, 6.0)
	var fbox := BoxMesh.new()
	fbox.size = Vector3(0.8, 0.8, 0.8)
	fnode.add_child(_mesh(fbox, Palette.SAGE_DEEP, Vector3(0.0, 0.4, 0.0), Vector3(0.0, 0.8, 0.0)))
	_flasher = _add_look(fnode, 1.0)
	add_child(fnode)

	# distant hills for the paper fade
	var hills := Node3D.new()
	add_child(hills)
	for i in 9:
		var hill := SphereMesh.new()
		hill.radial_segments = 10
		hill.rings = 6
		hill.radius = 14.0 + float(i % 3) * 5.0
		hill.height = hill.radius * 1.1
		var z := -45.0 - float(i) * 14.0
		var x := (-60.0 + float(i) * 15.0) * (1.0 if i % 2 == 0 else -0.6)
		hills.add_child(_mesh(hill, Palette.SAGE_DEEP if i % 2 == 0 else Palette.STONE, Vector3(x, 0.0, z)))
	_add_look(hills, 1.0)


func _add_look(parent: Node3D, width: float, accent: StringName = &"") -> InkLook:
	var look := InkLook.new()
	look.outline_width = width
	look.accent = accent
	parent.add_child(look)
	return look


func _mesh(m: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return _mesh_mat(m, mat, pos, rot)


func _mesh_mat(m: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _smooth_normals(m)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	return mi


## Godot's primitives have split normals at hard edges, which cracks the hull outline. Models
## are exported with smooth normals (docs/CONTRACTS.md); this does the same for the demo's
## primitives by averaging normals at shared positions. The toon shader facets from derivatives.
func _smooth_normals(m: Mesh) -> Mesh:
	var arrays := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var sums := {}
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 0.0001)
		sums[key] = sums.get(key, Vector3.ZERO) + normals[i]
	for i in verts.size():
		normals[i] = (sums[verts[i].snapped(Vector3.ONE * 0.0001)] as Vector3).normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## A tapered, gently curved branch with painted weights: R tapers to 0 at both ends,
## G (sway) and B (dry brush) grow toward the tip.
func _branch(pos: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var sides := 8
	var length := 5.0
	for i in segs + 1:
		var t := float(i) / segs
		var center := Vector3(-length * 0.5 + t * length, sin(t * 2.4) * 0.6, sin(t * 3.1) * 0.3)
		var radius := lerpf(0.22, 0.03, t)
		var w := pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.6)
		for j in sides:
			var a := TAU * j / sides
			var n := Vector3(0.0, cos(a), sin(a))
			st.set_color(Color(w, t, t * 0.9 + 0.1, 1.0))
			st.set_normal(n)
			st.set_uv(Vector2(float(j) / sides, t))
			st.add_vertex(center + n * radius)
	for i in segs:
		for j in sides:
			var a := i * sides + j
			var b := i * sides + (j + 1) % sides
			var c := a + sides
			var d := b + sides
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.SEPIA.lightened(0.25)
	mi.material_override = mat
	mi.position = pos
	return mi
