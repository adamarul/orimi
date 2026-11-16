extends Node3D
## scenes/dev/vfx_demo.tscn: the vfx workstream's showcase. Owner: vfx.
## A small ground with the sky, a strip of river, scattered foliage half inside a cursed zone,
## mist, a soot bank and a stand-in player walking a loop (flowers in its wake), then every
## one-shot effect firing in turn, on a loop, with a label naming it. Effects that the Vfx
## director fires by itself are triggered through Events, so the demo proves those hookups.
##
## Boot options:
##   peak_pause=1   pause the tree at each effect's peak for a moment (also proves the pause
##                  freeze) and print "VFX_PEAK n=<i> id=<id>"
##   vfx_shots=DIR  desktop: save a PNG at each peak into DIR (implies peak_pause)
##   once=1         stop after one pass: print VFX_DEMO_DONE (and quit on desktop)
##   only=<id>      loop just that step
##   foliage=N      number of foliage cards (default 300)
##   step_time=S    seconds per step without peak pauses (default 2.6)

const STAGE := Vector3(8.0, 0.0, 6.0)
const ZONE := Vector3(-14.0, 0.0, 2.0)
const ZONE_R := 9.0
const LOOP_CENTER := Vector3(-4.0, 0.0, 4.0)
const LOOP_R := 7.5
const KIT2 := Vector3(-3.0, 0.0, 9.0)

var steps: Array[Dictionary] = []
var camera: Camera3D
var label: Label
var player: CharacterBody3D
var soot_bank: Node3D
var swinger: Node3D
var swing_trail: Node
var dummy: Node3D

var _index := -1
var _fired_at := 0.0
var _fired := false
var _peaked := false
var _step_clock := 0.0
var _walk := 0.0
var _peak_pause := false
var _shots_dir := ""
var _once := false
var _only := ""
var _step_time := 2.6
var _fps_clock := 0.0
var _busy := false
var _swing := -1.0
var _kit := false
var _kit_t := 0.0
var _raft_go := false
var lamps: Array[Node3D] = []
var posts: Node3D
var stone: Node3D
var enemy: Node3D
var knot: Node3D
var raft: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shots_dir = String(Boot.opt("vfx_shots", ""))
	_peak_pause = Boot.opt("peak_pause", "0") == "1" or _shots_dir != ""
	_once = Boot.opt("once", "0") == "1"
	_only = String(Boot.opt("only", ""))
	_step_time = float(Boot.opt("step_time", "2.6"))
	_kit = Boot.opt("set", "") == "kit"
	_build_world()
	if _kit:
		_build_kit_props()
		_build_kit_steps()
	else:
		_build_steps()
	Vfx.warm_up()
	_next_step()


# --- world ----------------------------------------------------------------------------------

func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.IVORY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Palette.IVORY
	env.fog_density = 0.011
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.85
	sun.rotation_degrees = Vector3(-52, -35, 0)
	add_child(sun)

	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.SAGE.lerp(Palette.PARCHMENT, 0.35)
	mesh.material_override = mat
	ground.add_child(mesh)
	if ResourceLoader.exists("res://scripts/render/ink_look.gd"):
		var look: Node = load("res://scripts/render/ink_look.gd").new()
		ground.add_child(look)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	add_child(body)

	add_child(load("res://scenes/env/sky.tscn").instantiate())
	var river := load("res://scenes/env/river_water.tscn").instantiate() as Node3D
	river.set("size", Vector2(120, 7))
	river.set("flow_direction", Vector2(1, 0.15))
	river.position = Vector3(0, 0.03, -15)
	add_child(river)
	var foliage := load("res://scenes/env/foliage_scatter.tscn").instantiate() as Node3D
	foliage.set("area_size", Vector2(60, 22))
	foliage.set("count", int(Boot.opt("foliage", "300")))
	foliage.set("avoid_valley_paths", false)
	foliage.set("kind_weights", Vector4(0.25, 0.45, 0.25, 0.05))
	foliage.set("keep_clear", PackedVector3Array([Vector3(STAGE.x, STAGE.z, 4.5), Vector3(16, 0, 4.0), Vector3(KIT2.x, KIT2.z, 5.0)]))
	foliage.position = Vector3(0, 0, 1)
	add_child(foliage)
	for p: Vector3 in [Vector3(-2, 0, -9), Vector3(4, 0, 14), Vector3(12, 0, -6)]:
		var mist := load("res://scenes/env/mist.tscn").instantiate() as Node3D
		mist.position = p
		add_child(mist)
	soot_bank = load("res://scenes/env/soot_bank_visual.tscn").instantiate() as Node3D
	soot_bank.position = Vector3(16, 0, 0)
	add_child(soot_bank)

	player = CharacterBody3D.new()
	player.name = "StandInPlayer"
	player.add_to_group(&"player")
	player.collision_layer = Layers.PLAYER
	player.collision_mask = Layers.WORLD
	var pshape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.0
	pshape.shape = cap
	pshape.position = Vector3(0, 0.5, 0)
	player.add_child(pshape)
	var pmesh := MeshInstance3D.new()
	var pm := CapsuleMesh.new()
	pm.radius = 0.3
	pm.height = 1.0
	pmesh.mesh = pm
	pmesh.position = Vector3(0, 0.5, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Palette.IVORY
	pmesh.material_override = pmat
	player.add_child(pmesh)
	add_child(player)
	player.global_position = LOOP_CENTER + Vector3(LOOP_R, 0.1, 0)

	swinger = Node3D.new()
	swinger.name = "TailTip"
	add_child(swinger)
	swinger.global_position = STAGE + Vector3(0, 0.6, 0)
	dummy = Node3D.new()
	dummy.name = "DemoTarget"
	add_child(dummy)

	camera = Camera3D.new()
	camera.fov = 58.0
	camera.far = 400.0
	add_child(camera)
	camera.make_current()

	var hud := CanvasLayer.new()
	hud.layer = Layers.CANVAS_HUD
	add_child(hud)
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override(&"font_size", 26)
	label.add_theme_color_override(&"font_color", Palette.INK)
	label.add_theme_color_override(&"font_outline_color", Palette.IVORY)
	label.add_theme_constant_override(&"outline_size", 8)
	hud.add_child(label)


# --- the sequence ---------------------------------------------------------------------------

func _build_steps() -> void:
	var s := STAGE
	var near := [s + Vector3(0, 2.0, 4.2), s + Vector3(0, 0.6, 0)]
	_add("sky_cursed", "Sky, cursed (valley_gloom 1)", [Vector3(0, 2, 22), Vector3(0, 16, -40)], 1.0,
		func() -> void: CurseField.set_valley_gloom(1.0, 0.0))
	_add("sky_restored", "Sky, restored (valley_gloom 0)", [Vector3(0, 2, 22), Vector3(0, 16, -40)], 1.0,
		func() -> void: CurseField.set_valley_gloom(0.0, 0.0))
	_add("foliage_curse", "Foliage in and out of a cursed zone", [ZONE + Vector3(10, 5, 15), ZONE + Vector3(4, 0, 0)], 0.6,
		func() -> void: CurseField.set_valley_gloom(0.0, 0.0))
	_add("river_mist", "River water and mist", [Vector3(2, 3.5, 2), Vector3(4, 0, -15)], 0.8, Callable())
	_add("wake_flowers", "Flowers in the player's wake", [], 3.0, Callable())
	_add("ink_splash", "Enemy ink death (Events.enemy_died)", near, 0.25,
		func() -> void: Events.enemy_died.emit(dummy, &"splotchet", s + Vector3(0, 0.3, 0)))
	_add("hit_spark", "Hit spark (Events.enemy_hit)", near, 0.083,
		func() -> void: Events.enemy_hit.emit(dummy, 1.0, s + Vector3(0, 0.9, 0)))
	_add("slash_ribbon", "Slash ribbon (Events.glyph_cast slash)", near, 0.083,
		func() -> void: Events.glyph_cast.emit(&"slash", {"glyph": &"slash", "world_from": s + Vector3(-2.2, -0.3, 0.3),
			"world_to": s + Vector3(2.3, 0.1, -0.3), "world_center": s, "targets": []}))
	_add("tail_swipe", "Tail swipe arc (Events.player_attacked)", near, 0.083,
		func() -> void: Events.player_attacked.emit(&"attack_1", Transform3D(Basis(), s)))
	_add("attach_trail", "attach_trail on a swinging node", near, 0.25,
		func() -> void: _swing = 0.0)
	_add("gust", "Gust swirl (Events.glyph_cast gust)", [s + Vector3(0, 2.4, 6.0), s + Vector3(0, 1.0, 0)], 0.333,
		func() -> void: Events.glyph_cast.emit(&"gust", {"glyph": &"gust", "world_center": s + Vector3(-1.5, 0, 0),
			"world_dir": Vector3(1, 0, -0.2), "targets": []}))
	_add("bloom_glyph", "Bloom flowers at the cast point", [s + Vector3(0, 3.5, 6.0), s], 0.5,
		func() -> void: Events.glyph_cast.emit(&"bloom", {"glyph": &"bloom", "world_center": s, "world_radius": 1.8, "targets": []}))
	_add("petal_burst", "Petal burst", near, 0.42,
		func() -> void: Vfx.petal_burst(s + Vector3(0, 0.5, 0), 3.0))
	_add("bloom_ring", "Bloom ring riding the colour front (zone_restore_started)", [ZONE + Vector3(0, 8, 15), ZONE], 0.75,
		func() -> void:
			CurseField.restore_zone(0, 2.6)
			Events.zone_restore_started.emit(&"zone_a", ZONE, ZONE_R))
	_add("soot_clear", "Soot cleared (Events.soot_cleared + blow_away)", [Vector3(16, 2.6, 10), Vector3(16, 1.4, 0)], 0.75,
		func() -> void:
			soot_bank.call("blow_away", Vector3(1, 0, -0.4))
			Events.soot_cleared.emit(soot_bank, soot_bank.global_position + Vector3.UP * 1.5))
	_add("thorns_cut", "Thorns cut (Events.thorns_cut)", near, 0.25,
		func() -> void: Events.thorns_cut.emit(dummy, s + Vector3(0, 1.0, 0)))
	_add("veil_stripped", "Veil stripped (Events.enemy_unveiled)", near, 0.42,
		func() -> void:
			dummy.global_position = s
			Events.enemy_unveiled.emit(dummy))
	_add("valley_petals", "Valley-wide petal fall (Events.valley_restored)", [Vector3(2, 3, 20), Vector3(2, 2.5, 0)], 3.0,
		func() -> void: Events.valley_restored.emit())


# --- level-kit effects (set=kit) ---------------------------------------------------------

func _build_kit_props() -> void:
	var holder := Node3D.new()
	holder.name = "KitProps"
	add_child(holder)
	var kinds := ["lamp", "brazier", "lantern_fruit"]
	for i in 3:
		var lamp := (load("res://scenes/game/kit/%s.tscn" % kinds[i]) as PackedScene).instantiate() as Node3D
		holder.add_child(lamp)
		lamp.global_position = STAGE + Vector3(-2.6 + 2.6 * i, 0.0, -1.4 - 0.4 * float(i == 1))
		lamps.append(lamp)
	posts = (load("res://scenes/game/kit/tie_posts.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(posts)
	posts.global_position = STAGE + Vector3(0.0, 0.0, 2.6)
	stone = (load("res://scenes/game/kit/verse_stone.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(stone)
	stone.global_position = KIT2 + Vector3(-2.2, 0.0, -1.2)
	enemy = (load("res://scenes/models/splotchet.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(enemy)
	enemy.global_position = KIT2 + Vector3(1.4, 0.0, -0.4)
	knot = Node3D.new()
	knot.name = "Knot"
	holder.add_child(knot)
	var knot_mat := StandardMaterial3D.new()
	knot_mat.albedo_color = Palette.CURSE_INK
	for i in 3:
		var loop := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.16
		torus.outer_radius = 0.26
		loop.mesh = torus
		loop.material_override = knot_mat
		loop.rotation = [Vector3.ZERO, Vector3(PI * 0.5, 0, 0), Vector3(0, 0, PI * 0.5)][i]
		knot.add_child(loop)
	raft = (load("res://scenes/models/raft.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(raft)
	raft.global_position = Vector3(-6.0, 0.05, -14.5)
	raft.rotation.y = -PI * 0.5
	player.global_position = KIT2 + Vector3(2.4, 0.1, 2.2)


func _build_kit_steps() -> void:
	var a := [STAGE + Vector3(0, 2.8, 8.6), STAGE + Vector3(0, 0.9, 0.8)]
	var b := [KIT2 + Vector3(0.5, 2.6, 6.5), KIT2 + Vector3(0, 0.8, -0.5)]
	for i in 3:
		var lamp := lamps[i]
		var cam := [lamp.global_position + Vector3(0, 1.6, 2.8), lamp.global_position + Vector3(0, 0.9, 0)]
		_add("kindle_%s" % lamp.get(&"kind"), "Kindle catches a %s (KindleTarget.kindled)" % String(lamp.get(&"kind")).replace("_", " "), cam, 0.17,
			func() -> void:
				lamp.call(&"put_out")
				lamp.call(&"kindle"))
	_add("tie_rope", "Tie rope drawn and pulled taut (TiePost.tied_up)", a, 0.42,
		func() -> void:
			var pa := posts.get_node(^"PostA")
			var pb := posts.get_node(^"PostB")
			pa.set(&"tied", false)
			pb.set(&"tied", false)
			pa.call(&"on_glyph", &"tie", {"targets": [pa, pb]}))
	_add("unravel", "Enemy unravelling (EnemyBase.unraveling, polled)", b, 0.9,
		func() -> void: Vfx.play(&"unravel", enemy.global_position, {"node": enemy}))
	_add("clean_cut", "Finishing stroke: clean cut (Game.enemy_finished)", b, 0.25,
		func() -> void: Game.enemy_finished.emit(enemy))
	_add("knot_drift", "Knot of black cord drifting (SealedFight.knot)", b, 1.0,
		func() -> void:
			knot.visible = true
			Vfx.play(&"knot_drift", knot.global_position, {"node": knot, "duration": 2.5}))
	_add("knot_burst", "Knot bursts (SealedFight.fight_started)", b, 0.17,
		func() -> void:
			Vfx.play(&"knot_burst", knot.global_position)
			knot.visible = false)
	var high := [KIT2 + Vector3(0, 7.0, 10.5), KIT2 + Vector3(0, 0.5, 0)]
	_add("fight_ring_rise", "Sealed fight: ring of ink rises (fight_started)", high, 0.42,
		func() -> void: Vfx.play(&"fight_ring_rise", KIT2, {"radius": 4.5}))
	_add("fight_ring_fall", "Sealed fight: ring sinks (fight_won)", high, 0.33,
		func() -> void: Vfx.play(&"fight_ring_fall", KIT2, {"radius": 4.5}))
	_add("verse_wake", "Verse-stone wakes under Bloom (VerseStone.reading, polled)", b, 0.6,
		func() -> void: Vfx.play(&"verse_wake", stone.call(&"glyph_anchor")))
	var pc := [player.global_position + Vector3(0, 1.8, 3.4), player.global_position + Vector3(0, 0.6, 0)]
	_add("bead_award", "Bead awarded (needs a hook)", pc, 0.58,
		func() -> void: Vfx.play(&"bead_award", player.global_position + Vector3.UP * 1.5, {"color": Palette.GOLD}))
	_add("pickup", "Pickup (needs a hook)", pc, 0.17,
		func() -> void: Vfx.play(&"pickup", player.global_position + Vector3(-0.8, 0.5, 0.0), {"color": Palette.PETAL_DEEP}))
	var cz := ZONE + Vector3(5.0, 0.0, 1.0)
	_add("cursed_throwback", "Cursed ground throws Orimi back (CursedGround.hurts, polled)", [cz + Vector3(0, 2.4, 5.0), cz + Vector3(0, 0.6, 0)], 0.17,
		func() -> void: Vfx.play(&"cursed_throwback", cz))
	var wp := Vector3(4.0, 0.06, -13.5)
	_add("water_throwback", "Deep water throws Orimi back (needs a hook)", [wp + Vector3(0, 2.6, 5.5), wp + Vector3(0, 0.3, 0)], 0.33,
		func() -> void: Vfx.play(&"water_throwback", wp))
	_add("raft_wake", "Raft's wake (Vfx.attach_wake; needs a hook)", [Vector3(1.0, 4.5, -6.5), Vector3(1.0, 0.0, -14.5)], 1.6,
		func() -> void:
			raft.global_position = Vector3(-5.0, 0.05, -14.5)
			Vfx.attach_wake(raft, 0.06)
			_raft_go = true)


func _step_kit_props(delta: float) -> void:
	_kit_t += delta
	knot.position = KIT2 + Vector3(-1.2 + sin(_kit_t * 0.9) * 1.4, 1.1 + sin(_kit_t * 1.7) * 0.15, -0.6 + cos(_kit_t * 0.7) * 1.2)
	knot.rotation = Vector3(_kit_t * 0.9, _kit_t * 1.3, _kit_t * 0.5)
	if _raft_go:
		raft.global_position += Vector3(2.6 * delta, 0.0, 0.0)
		if raft.global_position.x > 12.0:
			_raft_go = false
			Vfx.detach_wake(raft)


func _add(id: String, title: String, cam: Array, peak: float, fire: Callable) -> void:
	steps.append({"id": id, "title": title, "cam": cam, "peak": peak, "fire": fire})


func _next_step() -> void:
	if _only != "" and _once and _index >= 0:
		print("VFX_DEMO_DONE")
		if not Boot.is_web():
			get_tree().quit(0)
		_busy = true
		return
	if _only != "":
		var found := -1
		for i in steps.size():
			if steps[i]["id"] == _only:
				found = i
		_index = found if found >= 0 else 0
	else:
		_index += 1
		if _index >= steps.size():
			if _once:
				print("VFX_DEMO_DONE")
				if not Boot.is_web():
					get_tree().quit(0)
				_index = steps.size() - 1
				_busy = true
				return
			_index = 0
	if _index == 0 or _only != "":
		_reset_world()
	var step: Dictionary = steps[_index]
	label.text = "%d/%d  %s" % [_index + 1, steps.size(), step["title"]]
	var cam: Array = step["cam"]
	if not cam.is_empty():
		camera.look_at_from_position(cam[0], cam[1])
	_step_clock = 0.0
	_fired = false
	_peaked = false
	if step["id"] == "wake_flowers":
		_walk = 0.0


func _reset_world() -> void:
	Vfx.clear_all()
	CurseField.set_zone(0, ZONE, ZONE_R, 1.0)
	CurseField.set_valley_gloom(1.0, 0.0)
	if soot_bank.has_method("reset"):
		soot_bank.call("reset")


func _process(delta: float) -> void:
	_fps_clock += delta
	if _fps_clock >= 1.0:
		_fps_clock = 0.0
		print("ORIMI_FPS fps=%d process_ms=%.2f [t=%.2fs]" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Time.get_ticks_msec() / 1000.0])
	if _busy or _index < 0:
		return
	if get_tree().paused:
		return
	if _kit:
		_step_kit_props(delta)
	else:
		_walk_player(delta)
	_swing_tail(delta)
	var step: Dictionary = steps[_index]
	_step_clock += delta
	if not _fired and _step_clock >= 0.35:
		_fired = true
		_fired_at = Vfx.time
		var fire: Callable = step["fire"]
		if fire.is_valid():
			fire.call()
	if step["id"] == "wake_flowers":
		var p := player.global_position
		var ahead := Vector3(-sin(_walk), 0.0, cos(_walk))
		var out := Vector3(cos(_walk), 0.0, sin(_walk))
		camera.look_at_from_position(p + ahead * 3.5 + out * 2.0 + Vector3(0, 2.6, 0), p - ahead * 2.5 + Vector3.UP * 0.2)
	if _fired and not _peaked and Vfx.time - _fired_at >= float(step["peak"]) - 0.001:
		_peaked = true
		print("VFX_PEAK n=%d id=%s t=%.2f" % [_index + 1, step["id"], Vfx.time - _fired_at])
		if _peak_pause:
			_hold_peak(step["id"])
			return
	if _peaked and _step_clock >= maxf(_step_time, float(step["peak"]) + 0.8):
		_next_step()


func _hold_peak(id: String) -> void:
	_busy = true
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if _shots_dir != "" and not Boot.is_web():
		DirAccess.make_dir_recursive_absolute(_shots_dir)
		var img := get_viewport().get_texture().get_image()
		var path := _shots_dir.path_join("%02d_%s.png" % [_index + 1, id])
		img.save_png(path)
		print("VFX_SHOT %s" % path.get_file())
	print("VFX_PEAK_HELD n=%d id=%s" % [_index + 1, id])
	var t0 := Vfx.time
	var wind0: Vector4 = Vfx.current_wind()
	await get_tree().create_timer(1.2, true, false, true).timeout
	print("VFX_PAUSE_CHECK n=%d frozen=%s" % [_index + 1, str(Vfx.time == t0 and Vfx.current_wind() == wind0)])
	get_tree().paused = false
	_busy = false
	_step_clock = maxf(_step_clock, _step_time - 0.6)


func _walk_player(delta: float) -> void:
	_walk += delta * 0.55
	var target := LOOP_CENTER + Vector3(cos(_walk) * LOOP_R, 0, sin(_walk) * LOOP_R)
	var to := target - player.global_position
	to.y = 0.0
	player.velocity = Vector3(to.x, player.velocity.y - 9.8 * delta, to.z) / maxf(delta, 0.001) * 0.2
	player.velocity.y = -2.0
	player.move_and_slide()
	RenderingServer.global_shader_parameter_set(&"player_world_pos", player.global_position)


func _swing_tail(delta: float) -> void:
	if _swing < 0.0:
		return
	if swing_trail == null or not is_instance_valid(swing_trail):
		swing_trail = Vfx.attach_trail(swinger, 0.3)
	swing_trail.set("emitting", true)
	_swing += delta
	var k := clampf(_swing / 0.32, 0.0, 1.0)
	var a := lerpf(-2.0, 2.0, k)
	swinger.global_position = STAGE + Vector3(sin(a) * 1.3, 0.5 + 0.4 * k, cos(a) * 0.9)
	if k >= 1.0:
		swing_trail.set("emitting", false)
		_swing = -1.0
