extends Node3D
## Sootflit test (scenes/levels/mosswater/sootflit_test.tscn): Orimi and three Sootflits over flat
## ground, with the HUD, to see the flyer move and fight it by hand (click to capture the mouse,
## Escape releases). selftest=1 runs the fight itself through the real brush and prints QA lines:
## waits for a dive, Gusts one down, checks it lies stunned, Slashes it, and checks a second one
## lifts off again after its stun. shots=<dir> (desktop) saves a picture at each step. Owner: l4.

const SOOTFLIT := preload("res://scenes/levels/mosswater/enemies/sootflit.tscn")

var player: OrimiPlayer
var camera: GameCamera
var hud: GameHud
var flyers: Array[Sootflit] = []
var _shots := ""
var _shot_n := 0


func _ready() -> void:
	Game.read_options()
	_shots = String(Boot.opt("shots", ""))
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.IVORY
	env.ambient_light_energy = 0.75
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.85
	add_child(sun)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	mi.mesh = plane
	mi.material_override = ModelKit.mat(Palette.SAGE)
	ground.add_child(mi)
	add_child(ground)
	ModelKit.add_ink_look(ground)

	for at: Vector3 in [Vector3(-3, 0, -6), Vector3(3, 0, -7), Vector3(0, 0, -11)]:
		var f := SOOTFLIT.instantiate() as Sootflit
		add_child(f)
		f.place(at + Vector3.UP * 0.1)
		f.name = "Sootflit_%d" % flyers.size()
		flyers.append(f)

	player = OrimiPlayer.new()
	player.name = "Orimi"
	add_child(player)
	player.teleport(Vector3(0, 0.05, 2), 0.0)
	camera = GameCamera.new()
	add_child(camera)
	camera.target = player.visual
	player.camera = camera
	camera.snap_behind(player)
	Game.player = player
	hud = GameHud.new()
	add_child(hud)
	hud.reset()
	Game.reset_run()
	Game.set_state(Game.STATE_PLAYING)
	Game.qa_log("sootflit_test_ready", Game.debug_snapshot())
	if String(Boot.opt("selftest", "0")) == "1":
		_selftest()


func _exit_tree() -> void:
	Game.set_state(Game.STATE_TITLE)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Brush.is_open():
		Game.capture_mouse()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _shot(label: String) -> void:
	if _shots == "" or Boot.is_web() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_shot_n += 1
	DirAccess.make_dir_recursive_absolute(_shots)
	get_viewport().get_texture().get_image().save_png(_shots.path_join("%02d_%s.png" % [_shot_n, label]))


## Draw a glyph centred on target's anchor through the real brush.
func _cast(glyph: StringName, target: Node3D) -> bool:
	camera.face_toward(target.call("glyph_anchor"), -10.0)
	await _sleep(0.5)
	if not is_instance_valid(target):
		return false
	var cam := get_viewport().get_camera_3d()
	var c := cam.unproject_position(target.call("glyph_anchor"))
	var pts := PackedVector2Array()
	for p in GlyphIcon.stroke(glyph):
		pts.append(c + (p - Vector2(0.5, 0.5)) * 220.0)
	Brush.refill()
	var info := Brush.inject_stroke(pts)
	var hit: bool = target in info.get("targets", [])
	Game.qa_log("sootflit_test_cast", {"glyph": String(glyph), "recognised": String(info.get("glyph", "")), "target": String(target.name), "hit": hit})
	return hit


## Waits in game time (physics frames), so a loaded machine does not cut a wait short; gives up
## after four times as long in real time (a paused tree).
func _wait_until(cond: Callable, timeout: float) -> bool:
	var game_t := 0.0
	var real_until := Time.get_ticks_msec() + int(timeout * 4000.0)
	while game_t < timeout and Time.get_ticks_msec() < real_until:
		if cond.call():
			return true
		await get_tree().physics_frame
		game_t += get_physics_process_delta_time()
	if get_tree().paused:
		Game.qa_log("sootflit_test_paused", {"brush_open": Brush.is_open(), "state": Game.state})
	return cond.call()


func _sleep(seconds: float) -> void:
	await _wait_until(func() -> bool: return false, seconds)


func _selftest() -> void:
	var results := {}
	await _sleep(1.0)
	await _shot("circling")
	results["dived"] = await _wait_until(func() -> bool: return flyers.any(func(f: Sootflit) -> bool: return is_instance_valid(f) and f.state == Sootflit.DIVE), 15.0)
	await _shot("dive")
	await _sleep(1.5)
	var a := flyers[0]
	var b: Sootflit
	results["air_slash_ignored"] = not await _cast(&"slash", a) and a.hp == a.max_hp
	await _wait_until(func() -> bool: return a.is_airborne(), 5.0)
	results["gust_a_hit"] = await _cast(&"gust", a)
	results["a_downed"] = await _wait_until(func() -> bool: return a.is_downed(), 4.0)
	await _shot("downed")
	await _sleep(0.6)
	results["a_still_downed"] = a.is_downed()
	results["slash_a_hit"] = await _cast(&"slash", a)
	results["a_defeated"] = await _wait_until(func() -> bool: return not is_instance_valid(a) or a.is_defeated(), 3.0)
	await _shot("slashed")
	var alive := flyers.filter(func(f: Sootflit) -> bool: return is_instance_valid(f) and not f.is_defeated())
	results["left_alive"] = alive.size()
	if alive.is_empty():
		results["b_downed"] = false
		Game.qa_log("sootflit_selftest", results)
		print("QA_SOOTFLIT_FAILED")
		return
	b = alive[0]
	await _wait_until(func() -> bool: return is_instance_valid(b) and b.is_airborne(), 8.0)
	results["gust_b_hit"] = await _cast(&"gust", b)
	results["b_downed"] = await _wait_until(func() -> bool: return b.is_downed(), 4.0)
	var f0 := Engine.get_physics_frames()
	results["b_lifted"] = await _wait_until(func() -> bool: return b.state == Sootflit.LIFT or b.state == Sootflit.CIRCLE, Sootflit.DOWNED_TIME + 2.0)
	results["b_stun_s"] = snappedf((Engine.get_physics_frames() - f0) * get_physics_process_delta_time(), 0.1)
	await _shot("lifted")
	var passed := true
	for k: String in results:
		if results[k] is bool and not results[k]:
			passed = false
	results["passed"] = passed
	Game.qa_log("sootflit_selftest", results)
	print("QA_SOOTFLIT_%s" % ("PASSED" if passed else "FAILED"))
