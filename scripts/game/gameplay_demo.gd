extends Node3D
## Gameplay demo (scenes/dev/gameplay_demo.tscn): Orimi, the camera, both enemy types, a thorn
## gate, a soot bank and a sapling in a small cursed zone on flat ground, with the HUD. For
## tuning movement, camera and combat on their own. Click to capture the mouse, Escape releases.
## selftest=1 casts each glyph through Brush.inject_stroke and prints QA lines. Owner: gameplay.

var player: OrimiPlayer
var camera: GameCamera
var hud: GameHud


func _ready() -> void:
	Game.read_options()
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
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	mi.mesh = plane
	mi.material_override = ModelKit.mat(Palette.SAGE)
	ground.add_child(mi)
	add_child(ground)
	ModelKit.add_ink_look(ground)

	var zone := CursedZone.new()
	zone.zone_id = &"zone_a"
	zone.radius = 9.0
	zone.display_name = "Demo Hollow"
	zone.position = Vector3(10, 0, -12)
	add_child(zone)
	var sapling := BloomTarget.new()
	sapling.name = "Sapling"
	sapling.zone = zone
	zone.target = sapling
	sapling.position = zone.position
	add_child(sapling)
	for spec: Array in [[Splotchet, Vector3(6, 0, -9)], [Splotchet, Vector3(13, 0, -8)], [Reedwraith, Vector3(10, 0, -17)]]:
		var e: EnemyBase = (spec[0] as GDScript).new()
		e.position = spec[1]
		add_child(e)
		zone.add_enemy(e)
	var gate := GlyphObstacle.new()
	gate.name = "ThornGate"
	gate.glyph = &"slash"
	gate.position = Vector3(-8, 0, -8)
	add_child(gate)
	var soot := GlyphObstacle.new()
	soot.name = "SootBank"
	soot.glyph = &"gust"
	soot.position = Vector3(-8, 0, -20)
	add_child(soot)

	player = OrimiPlayer.new()
	player.name = "Orimi"
	add_child(player)
	player.teleport(Vector3(0, 0.05, 6), 0.0)
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
	Game.qa_log("demo_ready", Game.debug_snapshot())
	if String(Boot.opt("selftest", "0")) == "1":
		_selftest(gate, soot, zone)


func _exit_tree() -> void:
	Game.set_state(Game.STATE_TITLE)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Brush.is_open():
		Game.capture_mouse()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _cast(glyph: StringName, target: Node3D) -> Dictionary:
	camera.face_toward(target.call("glyph_anchor"), -14.0)
	await get_tree().create_timer(1.0).timeout
	var cam := get_viewport().get_camera_3d()
	var c := cam.unproject_position(target.call("glyph_anchor"))
	var pts := PackedVector2Array()
	for p in GlyphIcon.stroke(glyph):
		pts.append(c + (p - Vector2(0.5, 0.5)) * 260.0)
	Brush.refill()
	var info := Brush.inject_stroke(pts)
	var hit: bool = target in info.get("targets", [])
	Game.qa_log("demo_cast", {"glyph": String(glyph), "recognised": String(info.get("glyph", "")), "hit": hit})
	return info


func _selftest(gate: GlyphObstacle, soot: GlyphObstacle, zone: CursedZone) -> void:
	await get_tree().create_timer(1.5).timeout
	player.teleport(Vector3(-8, 0.05, -2), 0.0)
	camera.snap_behind(player)
	await _cast(&"slash", gate)
	player.teleport(Vector3(-8, 0.05, -14), 0.0)
	camera.snap_behind(player)
	await _cast(&"gust", soot)
	for e in zone.enemies:
		if is_instance_valid(e):
			e.die()
	await get_tree().create_timer(0.5).timeout
	player.teleport(Vector3(10, 0.05, -6), 0.0)
	camera.snap_behind(player)
	await _cast(&"bloom", zone.target)
	await get_tree().create_timer(3.0).timeout
	var ok := (not is_instance_valid(gate) or gate.cleared)
	ok = ok and (not is_instance_valid(soot) or soot.cleared) and zone.is_restored
	Game.qa_log("demo_selftest", {"passed": ok})
