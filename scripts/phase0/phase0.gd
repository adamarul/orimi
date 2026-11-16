extends Node3D
## Phase 0 renderer probe scene. Every probe is small, visible in a screenshot, and reports one line:
##   ORIMI_PROBE <name> <PASS|FAIL|YES|NO|INFO|SKIP> <detail>
## Screen-space probe tiles along the top-left edge are written by the post shaders and read back
## from the viewport image here. Click-gated probes (audio, pointer lock) run on the first mouse
## press; on desktop they run automatically unless autoclick=0.

const TOON := preload("res://shaders/phase0/toon.gdshader")
const OUTLINE := preload("res://shaders/phase0/ink_outline.gdshader")
const DEPTH_EDGES := preload("res://shaders/phase0/post_depth_edges.gdshader")
const PROBE_A := preload("res://shaders/phase0/post_probe_a.gdshader")
const PROBE_B := preload("res://shaders/phase0/post_probe_b.gdshader")
const CANVAS_PROBE := preload("res://shaders/phase0/canvas_probe.gdshader")
const BLOB := preload("res://shaders/phase0/blob_shadow.gdshader")
const VCOL_RAW := preload("res://shaders/phase0/vertex_colour_raw.gdshader")
const VCOL_SCENE := preload("res://assets/phase0/vcol_probe.glb")
const CHIME := preload("res://audio/phase0/probe_chime.wav")
const FrameCounter := preload("res://scripts/phase0/frame_counter.gd")

const BG_SRGB := Color(0.55, 0.42, 0.30)
const BG_UV := Vector2(0.92, 0.04)
const CAMERA_POS := Vector3(0.0, 7.0, 11.0)
const TILE_X0 := 0.02
const TILE_STEP := 0.06
const TILE_W := 0.05
const TILE_Y0 := 0.02
const TILE_Y1 := 0.08

const TORUS_POS := Vector3(-6.0, 1.0, 2.5)
const VCOL_POS := Vector3(-3.0, 1.0, 2.5)
const DECAL_POS := Vector3(3.0, 0.0, 2.5)
const BLOB_POS := Vector3(6.0, 0.0, 2.5)
const GROUND_REF_POS := Vector3(1.5, 0.0, 2.5)
const GPU_PARTICLES_POS := Vector3(-2.5, 0.2, -3.0)
const CPU_PARTICLES_POS := Vector3(2.5, 0.2, -3.0)
const VCOL_RAW_POS := Vector3(0.0, 1.0, 5.0)
const GREY_POS := Vector3(1.6, 1.0, 5.0)

var results: Dictionary = {}
var _camera: Camera3D
var _labels: Array[Label] = []
var _audio: AudioStreamPlayer
var _pausable: Node3D
var _always: Node3D
var _vcol_meshes: Array[MeshInstance3D] = []
var _click_probes_started := false
var _motion := {"events": 0, "pressure_min": INF, "pressure_max": -INF, "tilt_events": 0, "pen_inverted": 0}


func _ready() -> void:
	_build_world()
	_build_post_passes()
	_build_canvas_probes()
	_build_ui()
	_run_timeline()


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_SRGB
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.75)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = false
	add_child(sun)

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.look_at_from_position(CAMERA_POS, Vector3.ZERO)
	_camera.current = true

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	ground.material_override = _toon(Color(0.86, 0.83, 0.74))
	add_child(ground)

	var torus := MeshInstance3D.new()
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 0.35
	torus_mesh.outer_radius = 0.9
	torus.mesh = torus_mesh
	var torus_mat := _toon(Color(0.62, 0.68, 0.58))
	torus_mat.next_pass = _outline(3.0, false)
	torus.material_override = torus_mat
	torus.position = TORUS_POS
	torus.rotation_degrees = Vector3(60.0, 0.0, 0.0)
	add_child(torus)

	var vcol := VCOL_SCENE.instantiate() as Node3D
	vcol.position = VCOL_POS
	add_child(vcol)
	for node in vcol.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mat := _toon(Color(1, 1, 1))
		mat.set_shader_parameter("use_vertex_color", true)
		mat.set_shader_parameter("flat_from_derivatives", true)
		mat.next_pass = _outline(5.0, true)
		mi.material_override = mat
		_vcol_meshes.append(mi)

	var vcol_raw := VCOL_SCENE.instantiate() as Node3D
	vcol_raw.position = VCOL_RAW_POS
	vcol_raw.scale = Vector3.ONE * 0.6
	add_child(vcol_raw)
	for node in vcol_raw.find_children("*", "MeshInstance3D", true, false):
		var raw_mat := ShaderMaterial.new()
		raw_mat.shader = VCOL_RAW
		(node as MeshInstance3D).material_override = raw_mat

	var grey := MeshInstance3D.new()
	var grey_mesh := SphereMesh.new()
	grey_mesh.radius = 0.35
	grey_mesh.height = 0.7
	grey.mesh = grey_mesh
	var grey_mat := ShaderMaterial.new()
	grey_mat.shader = VCOL_RAW
	grey_mat.set_shader_parameter("constant_grey", true)
	grey.material_override = grey_mat
	grey.position = GREY_POS
	add_child(grey)

	var decal := Decal.new()
	decal.size = Vector3(2.0, 2.0, 2.0)
	decal.position = DECAL_POS
	decal.texture_albedo = _radial_texture(Color(0.12, 0.10, 0.10, 0.85))
	add_child(decal)

	var blob := MeshInstance3D.new()
	var blob_mesh := PlaneMesh.new()
	blob_mesh.size = Vector2(2.0, 2.0)
	blob.mesh = blob_mesh
	var blob_mat := ShaderMaterial.new()
	blob_mat.shader = BLOB
	blob.material_override = blob_mat
	blob.position = BLOB_POS + Vector3(0.0, 0.02, 0.0)
	add_child(blob)

	add_child(_make_gpu_particles())
	add_child(_make_cpu_particles())

	_pausable = _spinner(Vector3(-0.8, 0.6, -4.5), Color(0.62, 0.66, 0.70), Node.PROCESS_MODE_PAUSABLE)
	_always = _spinner(Vector3(0.8, 0.6, -4.5), Color(0.80, 0.30, 0.18), Node.PROCESS_MODE_ALWAYS)

	_audio = AudioStreamPlayer.new()
	_audio.stream = CHIME
	_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_audio)


func _build_post_passes() -> void:
	var edges := _fullscreen_quad(DEPTH_EDGES, 1)
	var probe_a := _fullscreen_quad(PROBE_A, 2)
	var mat_a := probe_a.material_override as ShaderMaterial
	mat_a.set_shader_parameter("bg_srgb", Vector3(BG_SRGB.r, BG_SRGB.g, BG_SRGB.b))
	mat_a.set_shader_parameter("bg_uv", BG_UV)
	var hit := _ground_hit_at_center()
	mat_a.set_shader_parameter("expected_depth", (hit - _camera.global_position).dot(-_camera.global_basis.z))
	mat_a.set_shader_parameter("expected_view_normal", (_camera.global_basis.inverse() * Vector3.UP).normalized())
	var probe_b := _fullscreen_quad(PROBE_B, 3)
	for quad in [edges, probe_a, probe_b]:
		_camera.add_child(quad)


func _build_canvas_probes() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	layer.add_child(_canvas_rect(0, 0))
	layer.add_child(_canvas_rect(1, 8))
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(copy)
	layer.add_child(_canvas_rect(1, 9))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.07, 0.78)
	style.set_content_margin_all(6.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	panel.add_child(columns)
	for i in 2:
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_constant_override("line_spacing", 0)
		label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		columns.add_child(label)
		_labels.append(label)
	_refresh_label()


func _run_timeline() -> void:
	if DisplayServer.get_name() == "headless":
		_report("pixel_probes", "SKIP", "headless display, nothing is rendered")
		return
	await RenderingServer.frame_post_draw
	_report("renderer", "INFO", "%s / %s / %s" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(),
	])
	_fps_loop()
	await _wait(1.0)
	await _probe_pause()
	await _wait(0.8)
	await RenderingServer.frame_post_draw
	_probe_pixels()
	_probe_vertex_colour_arrays()
	print("ORIMI_PROBES_DONE %s" % JSON.stringify(results))
	if not Boot.is_web() and String(Boot.opt("autoclick", "1")) != "0":
		await _probe_desktop_motion()
		await _run_click_probes()


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_motion["events"] += 1
		_motion["pressure_min"] = minf(_motion["pressure_min"], motion.pressure)
		_motion["pressure_max"] = maxf(_motion["pressure_max"], motion.pressure)
		if motion.tilt != Vector2.ZERO:
			_motion["tilt_events"] += 1
		if motion.pen_inverted:
			_motion["pen_inverted"] += 1
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	if button.pressed and not _click_probes_started:
		_run_click_probes()
	elif not button.pressed:
		_report_pressure()


func _probe_pause() -> void:
	get_tree().paused = true
	await get_tree().process_frame
	var p0 := _pausable.get("frames") as int
	var a0 := _always.get("frames") as int
	await _wait(0.4)
	var dp := (_pausable.get("frames") as int) - p0
	var da := (_always.get("frames") as int) - a0
	get_tree().paused = false
	var ok := dp == 0 and da > 5
	_report("tree_paused_one_node_processing", "PASS" if ok else "FAIL",
		"while paused: pausable node +%d frames, PROCESS_MODE_ALWAYS node +%d frames" % [dp, da])


func _probe_pixels() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_report("pixel_readback", "FAIL", "viewport image unavailable")
		return
	_report("pixel_readback", "PASS", "%dx%d" % [image.get_width(), image.get_height()])

	var tile := func(i: int) -> String:
		return _classify(_pixel_uv(image, Vector2(TILE_X0 + i * TILE_STEP + TILE_W * 0.5, (TILE_Y0 + TILE_Y1) * 0.5)))

	var t0: String = tile.call(0)
	_report("fullscreen_quad_3d", "PASS" if t0 == "magenta" else "FAIL", "tile0=%s" % t0)
	var t1: String = tile.call(1)
	_report("screen_texture_3d", "PASS" if t1 in ["green", "blue"] else "FAIL",
		"tile1=%s (%s)" % [t1, {"green": "holds linear values", "blue": "holds sRGB-encoded values"}.get(t1, "background not matched")])
	var t2: String = tile.call(2)
	_report("depth_texture_3d", "PASS" if t2 == "green" else "FAIL", "tile2=%s (linearised centre depth vs analytic)" % t2)
	var t3: String = tile.call(3)
	_report("normal_roughness_texture", {"green": "PASS", "yellow": "SKIP"}.get(t3, "FAIL"),
		"tile3=%s%s" % [t3, " (gated off under Compatibility)" if t3 == "yellow" else ""])
	var t4: String = tile.call(4)
	_report("depth_reconstructed_normal", "PASS" if t4 == "green" else "FAIL", "tile4=%s" % t4)
	var t5: String = tile.call(5)
	_report("chain_3d_second_pass_sees_first", "YES" if t5 == "green" else "NO", "tile5=%s" % t5)
	var t6: String = tile.call(6)
	_report("canvas_pass_reads_3d_post_output", "YES" if t6 == "green" else "NO", "tile6=%s" % t6)
	var t7: String = tile.call(7)
	_report("canvas_pass_draws", "PASS" if t7 == "cyan" else "FAIL", "tile7=%s" % t7)
	var t8: String = tile.call(8)
	_report("canvas_chain_without_backbuffercopy", "YES" if t8 == "green" else "NO", "tile8=%s" % t8)
	var t9: String = tile.call(9)
	_report("canvas_chain_after_backbuffercopy", "YES" if t9 == "green" else "NO", "tile9=%s" % t9)
	var t10: String = tile.call(10)
	_report("screen_texture_canvas", "PASS" if t10 in ["green", "blue"] else "FAIL",
		"tile10=%s (%s)" % [t10, {"green": "holds linear values", "blue": "holds sRGB-encoded values"}.get(t10, "background not matched")])

	var ground := _pixel_world(image, GROUND_REF_POS)
	var decal := _pixel_world(image, DECAL_POS)
	var blob := _pixel_world(image, BLOB_POS)
	_report("decal_node", "PASS" if decal.get_luminance() < ground.get_luminance() * 0.8 else "FAIL",
		"luminance at decal %.2f vs ground %.2f" % [decal.get_luminance(), ground.get_luminance()])
	_report("blob_shadow_quad", "PASS" if blob.get_luminance() < ground.get_luminance() * 0.8 else "FAIL",
		"luminance at blob %.2f vs ground %.2f" % [blob.get_luminance(), ground.get_luminance()])

	var gpu := _count_pixels(image, GPU_PARTICLES_POS, func(c: Color) -> bool: return c.r > 0.8 and c.g > 0.35 and c.g < 0.75 and c.b < 0.25)
	var cpu := _count_pixels(image, CPU_PARTICLES_POS, func(c: Color) -> bool: return c.b > 0.75 and c.g > 0.55 and c.r < 0.35)
	_report("gpu_particles_3d", "PASS" if gpu > 30 else "FAIL", "%d orange pixels near emitter" % gpu)
	_report("cpu_particles_3d", "PASS" if cpu > 30 else "FAIL", "%d blue pixels near emitter" % cpu)

	var is_ink := func(c: Color) -> bool: return c.b > c.r + 0.03 and c.get_luminance() < 0.16
	var torus_ink := _count_pixels(image, TORUS_POS + Vector3(0.0, -1.0, 0.0), is_ink)
	_report("inverted_hull_outline", "PASS" if torus_ink > 50 else "FAIL", "%d outline-ink pixels around torus" % torus_ink)
	var vcol_px := _pixel_world(image, VCOL_POS)
	var saturation := maxf(vcol_px.r, maxf(vcol_px.g, vcol_px.b)) - minf(vcol_px.r, minf(vcol_px.g, vcol_px.b))
	_report("gltf_vertex_colour_in_shader", "PASS" if saturation > 0.15 else "FAIL",
		"lit #%s, unlit raw COLOR #%s, unlit constant 0.5 #%s" % [vcol_px.to_html(false), _pixel_world(image, VCOL_RAW_POS + Vector3(0.0, 0.25, 0.0)).to_html(false), _pixel_world(image, GREY_POS).to_html(false)])
	var vcol_ink := _count_pixels(image, VCOL_POS + Vector3(0.0, -1.0, 0.0), is_ink)
	_report("gltf_outline_vertex_alpha_width", "PASS" if vcol_ink > 30 else "FAIL", "%d outline-ink pixels around glTF mesh" % vcol_ink)


func _probe_vertex_colour_arrays() -> void:
	if _vcol_meshes.is_empty():
		_report("gltf_vertex_colour_arrays", "FAIL", "no MeshInstance3D in the imported glTF")
		return
	var mesh := _vcol_meshes[0].mesh
	var arrays := mesh.surface_get_arrays(0)
	var colors: Variant = arrays[Mesh.ARRAY_COLOR] if arrays.size() > Mesh.ARRAY_COLOR else null
	if colors == null or (colors as PackedColorArray).is_empty():
		_report("gltf_vertex_colour_arrays", "FAIL", "surface has no colour array")
		return
	var lo := Color(1, 1, 1, 1)
	var hi := Color(0, 0, 0, 0)
	for c in colors as PackedColorArray:
		lo = Color(minf(lo.r, c.r), minf(lo.g, c.g), minf(lo.b, c.b), minf(lo.a, c.a))
		hi = Color(maxf(hi.r, c.r), maxf(hi.g, c.g), maxf(hi.b, c.b), maxf(hi.a, c.a))
	_report("gltf_vertex_colour_arrays", "PASS",
		"%d colours, rgb min #%s max #%s, alpha %.2f..%.2f" % [(colors as PackedColorArray).size(), lo.to_html(false), hi.to_html(false), lo.a, hi.a])


func _probe_desktop_motion() -> void:
	var size := get_viewport().get_visible_rect().size
	for i in 8:
		Input.warp_mouse(size * 0.5 + Vector2(i * 12.0, i * 6.0))
		await get_tree().process_frame
		await get_tree().process_frame
	_report_pressure()


func _run_click_probes() -> void:
	_click_probes_started = true
	_audio.play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(0.5)
	var pos := _audio.get_playback_position()
	var playing := _audio.playing
	var playback_type := "desktop"
	if Boot.is_web():
		playback_type = "web default_playback_type=%s" % ProjectSettings.get_setting("audio/general/default_playback_type.web", "?")
	_report("audio_after_first_click", "PASS" if playing else "FAIL",
		"playing=%s playback_position=%.2fs (%s)" % [playing, pos, playback_type])
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var detail := "Input.mouse_mode captured=%s" % captured
	if Boot.is_web():
		detail += ", document.pointerLockElement set=%s" % JavaScriptBridge.eval("document.pointerLockElement !== null", true)
	_report("mouse_capture_pointer_lock", "PASS" if captured else "FAIL", detail)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("ORIMI_CLICK_PROBES_DONE %s" % JSON.stringify(results))


func _report_pressure() -> void:
	if _motion["events"] == 0:
		_report("pointer_pressure", "INFO", "no mouse motion events seen")
		return
	_report("pointer_pressure", "INFO", "%d motion events, pressure %.2f..%.2f, tilt in %d, pen_inverted in %d" % [
		_motion["events"], _motion["pressure_min"], _motion["pressure_max"], _motion["tilt_events"], _motion["pen_inverted"]])


func _fps_loop() -> void:
	var reported_motion := 0
	while is_inside_tree():
		await _wait(1.0)
		if _motion["events"] != reported_motion:
			reported_motion = _motion["events"]
			_report_pressure()
		print("ORIMI_FPS fps=%d process_ms=%.2f [t=%.2fs]" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Time.get_ticks_msec() / 1000.0])


func _report(probe: String, status: String, detail: String) -> void:
	results[probe] = {"status": status, "detail": detail}
	print("ORIMI_PROBE %s %s %s [t=%.2fs]" % [probe, status, detail, Time.get_ticks_msec() / 1000.0])
	_refresh_label()


func _refresh_label() -> void:
	if _labels.is_empty():
		return
	var lines: PackedStringArray = [
		"Orimi: The Unfaded Vale - phase 0 renderer probes",
		"tiles 0-10: A mark, A screen, A depth, A nrm buf, A depth nrm, B chain, C reads 3D, C mark, C no copy, C after copy, C screen",
	]
	for probe in results:
		lines.append("%s  %s  %s" % [probe, results[probe]["status"], results[probe]["detail"]])
	var half := ceili(lines.size() / 2.0)
	_labels[0].text = "\n".join(lines.slice(0, half))
	_labels[1].text = "\n".join(lines.slice(half))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _toon(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("albedo", color)
	return mat


func _outline(width_px: float, weight_from_alpha: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE
	mat.set_shader_parameter("width_px", width_px)
	mat.set_shader_parameter("weight_from_vertex_alpha", weight_from_alpha)
	return mat


func _fullscreen_quad(shader: Shader, priority: int) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	quad.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = priority
	quad.material_override = mat
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = Vector3(0.0, 0.0, -1.0)
	return quad


func _canvas_rect(mode: int, target_tile: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = CANVAS_PROBE
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("target_tile", target_tile)
	mat.set_shader_parameter("bg_srgb", Vector3(BG_SRGB.r, BG_SRGB.g, BG_SRGB.b))
	mat.set_shader_parameter("bg_uv", BG_UV)
	rect.material = mat
	return rect


func _radial_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _spinner(pos: Vector3, color: Color, mode: ProcessMode) -> Node3D:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.8, 0.8)
	box.mesh = mesh
	box.material_override = _toon(color)
	box.set_script(FrameCounter)
	box.process_mode = mode
	box.position = pos
	add_child(box)
	return box


func _particle_quad(color: Color) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	return quad


func _make_gpu_particles() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.5, 0.1, 0.5)
	process.direction = Vector3.UP
	process.spread = 15.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 1.6
	process.gravity = Vector3.ZERO
	particles.process_material = process
	particles.draw_pass_1 = _particle_quad(Color(1.0, 0.55, 0.0))
	particles.amount = 60
	particles.lifetime = 2.0
	particles.preprocess = 2.0
	particles.position = GPU_PARTICLES_POS
	return particles


func _make_cpu_particles() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.5, 0.1, 0.5)
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 1.6
	particles.gravity = Vector3.ZERO
	particles.mesh = _particle_quad(Color(0.1, 0.8, 1.0))
	particles.amount = 60
	particles.lifetime = 2.0
	particles.preprocess = 2.0
	particles.position = CPU_PARTICLES_POS
	return particles


func _ground_hit_at_center() -> Vector3:
	var dir := -_camera.global_basis.z
	return _camera.global_position + dir * (-_camera.global_position.y / dir.y)


func _pixel_uv(image: Image, uv: Vector2) -> Color:
	var x := clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1)
	var y := clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
	return image.get_pixel(x, y)


func _pixel_world(image: Image, world: Vector3) -> Color:
	var p := _camera.unproject_position(world)
	var size := get_viewport().get_visible_rect().size
	return _pixel_uv(image, p / size)


func _count_pixels(image: Image, world_base: Vector3, match_fn: Callable) -> int:
	var size := get_viewport().get_visible_rect().size
	var scale_px := Vector2(image.get_width(), image.get_height()) / size
	var a := _camera.unproject_position(world_base) * scale_px
	var b := _camera.unproject_position(world_base + Vector3(0.0, 3.5, 0.0)) * scale_px
	var x0 := clampi(int(minf(a.x, b.x) - 70.0), 0, image.get_width() - 1)
	var x1 := clampi(int(maxf(a.x, b.x) + 70.0), 0, image.get_width() - 1)
	var y0 := clampi(int(minf(a.y, b.y) - 20.0), 0, image.get_height() - 1)
	var y1 := clampi(int(maxf(a.y, b.y) + 20.0), 0, image.get_height() - 1)
	var count := 0
	for y in range(y0, y1 + 1, 2):
		for x in range(x0, x1 + 1, 2):
			if match_fn.call(image.get_pixel(x, y)):
				count += 1
	return count


func _classify(c: Color) -> String:
	var named := {
		"green": Color(0, 1, 0), "red": Color(1, 0, 0), "blue": Color(0, 0, 1), "yellow": Color(1, 1, 0),
		"magenta": Color(1, 0, 1), "cyan": Color(0, 1, 1),
	}
	for key in named:
		var n: Color = named[key]
		if absf(c.r - n.r) < 0.2 and absf(c.g - n.g) < 0.2 and absf(c.b - n.b) < 0.2:
			return key
	return "other(#%s)" % c.to_html(false)
