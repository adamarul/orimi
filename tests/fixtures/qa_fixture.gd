extends Node3D
## QA self-test fixture: a tiny stand-in game used only to prove the browser checks can pass and can
## catch planted defects before the real game exists. Not part of the slice. Owner: qa.
##   scene=res://tests/qa/qa_host.tscn target=res://tests/fixtures/qa_fixture.tscn [defect=...] [autoplay=1]
## Title card (Enter, Space or a click starts), a capsule "player" in group player moved by the
## move_* actions relative to an orbit camera (mouse while captured, arrow keys), jump, attack
## (emits Events.player_attacked), a stand-in brush on the brush action (pauses the tree, sepia
## overlay, records the pointer stroke, classifies circle / line / loop, spends ink through
## Brush.add_ink, emits the brush Events), a thorn gate at M_GateA that a slash cuts, and an
## autoplay timeline that emits the full slice's events.
## defect=error | input | brush | no_gust | shader | level_fail | paper_stuck plants one defect for the harness to catch.

const SPAWN := Vector3(0, 0, 50)
const GATE := Vector3(-4, 0, 36)

var defect := String(Boot.opt("defect", ""))
var player: CharacterBody3D
var pivot: Node3D
var camera: Camera3D
var yaw := 0.0
var pitch := -18.0
var title: CanvasLayer
var brush_layer: CanvasLayer
var sepia: ColorRect
var playing := false
var brush_open := false
var drawing := false
var stroke: PackedVector2Array = []
var mouse_before := Input.MOUSE_MODE_VISIBLE
var was_captured := false


func _ready() -> void:
	if defect == "error":
		push_error("QA fixture: planted error")
	_build_world()
	_build_ui()
	Game.state = Game.STATE_TITLE
	Events.game_state_changed.emit(Game.STATE_TITLE)
	if Boot.opt("autoplay", "") == "1":
		_autoplay()


func qa_fixture_snapshot() -> Dictionary:
	return {"state": String(Game.state), "player_pos": [player.global_position.x, player.global_position.y, player.global_position.z]}


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Palette.SKY
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var ground := StaticBody3D.new()
	var gshape := CollisionShape3D.new()
	gshape.shape = WorldBoundaryShape3D.new()
	ground.add_child(gshape)
	var gmesh := MeshInstance3D.new()
	gmesh.mesh = PlaneMesh.new()
	(gmesh.mesh as PlaneMesh).size = Vector2(200, 200)
	gmesh.material_override = _mat(Palette.SAGE)
	ground.add_child(gmesh)
	add_child(ground)
	for i in 24:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.position = Vector3(-30 + (i % 6) * 12, 0.5, 60 - (i / 6) * 25)
		box.material_override = _mat([Palette.STONE, Palette.VERMILION, Palette.GOLD, Palette.RIVER][i % 4])
		add_child(box)
	var gate := StaticBody3D.new()
	gate.name = "ThornGateFixture"
	gate.position = GATE
	gate.add_to_group(&"brush_target")
	gate.set_script(preload("res://tests/fixtures/qa_fixture_gate.gd"))
	var gm := MeshInstance3D.new()
	gm.mesh = BoxMesh.new()
	(gm.mesh as BoxMesh).size = Vector3(4, 2, 0.5)
	gm.position.y = 1
	gm.material_override = _mat(Palette.INK)
	gate.add_child(gm)
	add_child(gate)
	if defect == "shader":
		var bad := ShaderMaterial.new()
		bad.shader = Shader.new()
		bad.shader.code = "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(1.0) + undefined_symbol; }\n"
		gm.material_override = bad
	player = CharacterBody3D.new()
	player.name = "FixturePlayer"
	player.add_to_group(&"player")
	var pshape := CollisionShape3D.new()
	pshape.shape = CapsuleShape3D.new()
	pshape.position.y = 1
	player.add_child(pshape)
	var pm := MeshInstance3D.new()
	pm.mesh = CapsuleMesh.new()
	pm.position.y = 1
	pm.material_override = _mat(Palette.IVORY)
	player.add_child(pm)
	player.position = SPAWN
	add_child(player)
	Game.player = player
	pivot = Node3D.new()
	add_child(pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0, 6)
	camera.fov = 58
	pivot.add_child(camera)
	camera.make_current()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _build_ui() -> void:
	title = CanvasLayer.new()
	title.layer = Layers.CANVAS_MENU
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	var label := Label.new()
	label.text = "QA FIXTURE - press Enter or click to start"
	label.position = Vector2(400, 300)
	title.add_child(label)
	add_child(title)
	brush_layer = CanvasLayer.new()
	brush_layer.layer = Layers.CANVAS_BRUSH
	brush_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	sepia = ColorRect.new()
	sepia.color = Color(0.56, 0.42, 0.27, 0.86)
	sepia.set_anchors_preset(Control.PRESET_FULL_RECT)
	sepia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sepia.visible = false
	brush_layer.add_child(sepia)
	add_child(brush_layer)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _start() -> void:
	playing = true
	title.visible = false
	Game.state = Game.STATE_PLAYING
	Events.game_state_changed.emit(Game.STATE_PLAYING)
	Game.qa_log("state", {"state": "playing"})


func _input(event: InputEvent) -> void:
	if not playing:
		if event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_SPACE):
			_start()
			get_viewport().set_input_as_handled()
		return
	if brush_open:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			drawing = event.pressed
			if drawing:
				stroke.append(event.position)
		elif event is InputEventMouseMotion and drawing:
			stroke.append(event.position)
		if event.is_action_released(&"brush"):
			_close_brush()
		return
	if event.is_action_pressed(&"pause"):
		if get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event.is_action_pressed(&"brush") and defect != "brush" and not get_tree().paused:
		_open_brush()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and defect != "input":
		yaw -= event.relative.x * 0.25
		pitch = clampf(pitch - event.relative.y * 0.15, -60, 20)
	if event.is_action_pressed(&"attack") and defect != "input":
		Events.player_attacked.emit(&"swipe", player.global_transform)


func _process(_delta: float) -> void:
	if defect == "paper_stuck":
		Settings.paper_intensity = 1
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if was_captured and not captured and playing and not brush_open and not get_tree().paused:
		get_tree().paused = true
		Game.state = Game.STATE_PAUSED
		Events.game_state_changed.emit(Game.STATE_PAUSED)
	if captured and get_tree().paused and not brush_open:
		get_tree().paused = false
		Game.state = Game.STATE_PLAYING
		Events.game_state_changed.emit(Game.STATE_PLAYING)
	was_captured = captured


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	yaw += (Input.get_axis(&"cam_right", &"cam_left")) * 90.0 * delta
	pivot.global_position = player.global_position + Vector3.UP * 1.6
	pivot.rotation_degrees = Vector3(pitch, yaw, 0)
	if not playing or defect == "input":
		return
	var dir2 := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var dir := basis * Vector3(dir2.x, 0, dir2.y)
	player.velocity.x = dir.x * 6.0
	player.velocity.z = dir.z * 6.0
	if player.is_on_floor():
		player.velocity.y = 6.0 if Input.is_action_just_pressed(&"jump") else 0.0
	else:
		player.velocity.y -= 18.0 * delta
	player.move_and_slide()


func _open_brush() -> void:
	brush_open = true
	stroke.clear()
	get_tree().paused = true
	mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sepia.visible = true
	Events.brush_opened.emit()


func _close_brush() -> void:
	brush_open = false
	drawing = false
	var info := _classify(stroke)
	if info.is_empty():
		Events.glyph_failed.emit({"reason": &"unrecognised", "screen_points": stroke})
	else:
		var cost := 10.0
		Brush.add_ink(-cost)
		info["ink_cost"] = cost
		info["targets"] = []
		for n in get_tree().get_nodes_in_group(&"brush_target"):
			if n.has_method(&"on_glyph") and _hits(n, info) and n.on_glyph(info.glyph, info):
				info.targets.append(n)
		Events.glyph_cast.emit(info.glyph, info)
		Game.qa_log("glyph_cast", {"glyph": String(info.glyph)})
	sepia.visible = false
	Input.mouse_mode = mouse_before
	get_tree().paused = false
	Events.brush_closed.emit()


func _hits(n: Node3D, info: Dictionary) -> bool:
	if camera.is_position_behind(n.global_position):
		return false
	var sp := camera.unproject_position(n.global_position + Vector3.UP)
	var pts: PackedVector2Array = info.screen_points
	for i in range(1, pts.size()):
		if Geometry2D.get_closest_point_to_segment(sp, pts[i - 1], pts[i]).distance_to(sp) < 80.0:
			return true
	return false


func _classify(pts: PackedVector2Array) -> Dictionary:
	if pts.size() < 8:
		return {}
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	var size := maxf(r.size.x, r.size.y)
	if size < 40.0:
		return {}
	var turning := 0.0
	for i in range(2, pts.size()):
		var a := pts[i - 1] - pts[i - 2]
		var b := pts[i] - pts[i - 1]
		if a.length() > 0.5 and b.length() > 0.5:
			turning += a.angle_to(b)
	var closed := pts[0].distance_to(pts[pts.size() - 1]) < size * 0.3
	var glyph := &""
	if r.size.y < r.size.x * 0.25 and absf(turning) < PI * 0.5:
		glyph = &"slash"
	elif closed and absf(turning) > PI * 1.5:
		glyph = &"bloom"
	elif not closed and absf(turning) > PI * 1.5:
		glyph = &"gust"
	if glyph == &"" or (defect == "no_gust" and glyph == &"gust"):
		return {}
	var c := r.get_center()
	return {"glyph": glyph, "score": 0.9, "screen_points": pts, "screen_center": c, "screen_radius": size * 0.5}


func _autoplay() -> void:
	var steps := [
		["state", Game.STATE_PLAYING], ["glyph", &"slash"], ["thorns"], ["enemy", &"splotchet"], ["glyph", &"bloom"],
		["zone", &"zone_a"], ["glyph", &"gust"], ["soot"], ["enemy", &"reedwraith"], ["glyph", &"slash"], ["glyph", &"bloom"],
		["zone", &"zone_b"], ["enemy", &"splotchet"], ["enemy", &"reedwraith"], ["glyph", &"bloom"], ["finale"], ["restored"],
		["state", Game.STATE_ENDED]]
	await get_tree().create_timer(1.0).timeout
	title.visible = false
	for step: Array in steps:
		await get_tree().create_timer(0.4).timeout
		match step[0]:
			"state":
				Game.state = step[1]
				Events.game_state_changed.emit(step[1])
			"glyph":
				if defect == "no_gust" and step[1] == &"gust":
					continue
				Events.glyph_cast.emit(step[1], {"glyph": step[1], "score": 1.0, "targets": []})
			"thorns":
				Events.thorns_cut.emit(self, GATE)
			"soot":
				Events.soot_cleared.emit(self, Vector3(6, 1.5, 4))
			"enemy":
				Events.enemy_died.emit(player, step[1], player.global_position)
			"zone":
				Events.zone_restore_started.emit(step[1], Vector3.ZERO, 16.0)
				Events.zone_restored.emit(step[1])
			"finale":
				Events.finale_started.emit(Vector3(0, 6, -42))
			"restored":
				Events.valley_restored.emit()
		Game.qa_log(String(step[0]), {"step": str(step)})
	var levels: Array = [String(Boot.opt("level", ""))]
	if levels[0] == "":
		levels.clear()
		var reg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/levels/levels.json"))
		for entry: Dictionary in (reg as Dictionary).get("levels", []):
			if ResourceLoader.exists(String(entry.get("scene", ""))):
				levels.append(String(entry["id"]))
	var ok := defect != "level_fail"
	for level: String in levels:
		if ok:
			Game.qa_log("level_complete", {"level": level})
			Game.qa_log("bead", {"level": level})
		else:
			Game.qa_log("autoplay_fail", {"what": "planted level_fail", "level": level})
	Game.qa_log("autoplay_end", {"passed": ok, "failures": [] if ok else ["planted level_fail"], "levels": levels})
