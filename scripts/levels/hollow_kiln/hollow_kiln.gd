extends Level
## The Hollow Kiln (Level 5), scenes/levels/hollow_kiln/hollow_kiln.tscn, written by
## tools/levels/hollow_kiln/make_level.py. The kit does most of it (docs/LEVEL_KIT.md); this script
## sets the drained look of the set's props and water, plays the models of the kit's Kindle and
## glyph targets (bellows blow, moss blooms and its MossLedge ramp turns solid), darkens the hall, the flue and
## the vat chamber with render's light pools (level.json "dark_places") so lit lamps and mouths open
## pools, warms each restored place (level.json "restored_places": the grey lifts a step, warm pools, embers in the
## yard's stoke mouths), plays the level's music (the Dregs' own track from dregs_started until it unravels), keeps the camera behind Orimi and tilted up to the Dregs in the vat chamber (VatCam) while the Dregs is awake and frames both pillar rings (TieCam) while it climbs, lifts the counterweight door when it is tied, runs the finale (the tree, the clear river)
## and the ending (Pell, the valley), sets the title's backdrop (the kiln over the yard, restored once the
## level is done), and has one QA hook:
##   hk_start=<name>  start at level.json "qa_starts"[name] (flue, arena, dregs_lash, dregs_climb,
##                    dregs_bound) with everything before it done, and play only that start's
##                    autoplay route. The dregs_* starts wake the Dregs in that part.
## Owner: l5 (hollow_kiln).

const INK_WATER := "res://assets/levels/hollow_kiln/materials/ink_water.tres"
const CLEAR_WATER := "res://materials/env/water.tres"
const AUDIO_DIR := "res://audio/levels/hollow_kiln/"

var pools := LightPools.new()
var _dark := 0.0
var _cam_sizes := {}
var _title_restored := false


func _build(_progress: Callable) -> void:
	for id: String in ["cursed", "restored", "dregs"]:
		Audio.register_music(StringName("hollow_kiln_" + id), AUDIO_DIR + "hollow_kiln_%s.ogg" % id)
	var start := String(Boot.opt("hk_start", ""))
	if start != "":
		_start_at(start)
	_set_music()
	for cam: String in ["VatCam", "TieCam"]:
		_cam_sizes[cam] = (get_node(cam) as CameraZone).size
	_set_cams()
	_set_water(INK_WATER)
	for n: Node in get_node(^"Set").find_children("*", "", true, false):
		if String(n.name).begins_with("Counterweight"):
			_play(n, &"closed")
		elif n.name == "VatTree":
			(n as Node3D).visible = false
	add_child(pools)
	for k: Node in get_tree().get_nodes_in_group(&"kindle_target"):
		if is_ancestor_of(k):
			_play(k, &"unlit")
			k.connect(&"kindled", _on_kindled.bind(k))
	for t: Node in get_tree().get_nodes_in_group(&"glyph_target"):
		if is_ancestor_of(t):
			_play(t, &"withered" if String(t.name).begins_with("MossFoothold") else &"idle")
			t.connect(&"glyph_received", _on_glyph_target.bind(t))
	_set_verse_4(false)
	flag_changed.connect(_on_flag)
	if get_flag(&"counterweight_tied"):
		_on_flag(&"counterweight_tied", true)
	for place: Dictionary in data.get("restored_places", []):
		if get_flag(StringName("restored_" + String(place["zone"]))):
			_warm_place(place, 0.0)
	Events.zone_restore_started.connect(_on_zone_restore_started)
	if Game.state == Game.STATE_TITLE and Game.is_level_completed(level_id):
		level_built.connect(_set_title_restored.bind(true), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
		Events.game_state_changed.connect(_on_game_state)


func _exit_tree() -> void:
	super._exit_tree()
	Audio.set_level_music(&"")


## Behind the title: from over the gate across the yard to the hall and the dome, the kiln right of
## the title card, swaying slowly.
func title_camera(t: float) -> Transform3D:
	var a := t * 0.035
	var pos := marker("M_TitleView") + Vector3(sin(a) * 3.0, cos(a) * 0.8, 0.0)
	return Transform3D.IDENTITY.translated(pos).looking_at(marker("M_TitleLook"), Vector3.UP)


## The title after the level is done shows it restored (the tree through the dome, colour, the clear
## river), once the build has handed out the curse slots; the level is the same instance Continue
## plays, so leaving the title puts the drained state back.
func _set_title_restored(on: bool) -> void:
	_title_restored = on
	CurseField.set_valley_gloom(0.0 if on else start_gloom, 0.0)
	for z: Node in get_tree().get_nodes_in_group(Layers.GROUP_CURSED_ZONE):
		var slot := int(z.get(&"curse_slot"))
		if slot < 0:
			continue
		if on:
			CurseField.set_zone(slot, (z as Node3D).global_position, float(z.get(&"radius")), 0.0)
		else:
			z.call(&"curse_assigned", slot)
	_set_water(CLEAR_WATER if on else INK_WATER)
	var tree := find_child("VatTree", true, false) as Node3D
	if tree != null:
		tree.visible = on
		var ap := tree.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if on and ap != null and ap.has_animation(&"grow"):
			ap.play(&"grow")
			ap.seek(ap.current_animation_length, true)
	var pool := get_node(^"Set").find_child("InkPool", true, false) as Node3D
	if pool != null:
		pool.visible = not on


func _on_game_state(state: StringName) -> void:
	if _title_restored and state != Game.STATE_TITLE:
		_set_title_restored(false)


func _on_zone_restore_started(zone_id: StringName, _center: Vector3, _radius: float) -> void:
	for place: Dictionary in data.get("restored_places", []):
		if StringName(place["zone"]) == zone_id:
			_warm_place(place, 2.5)


## A restored place warms up over duration seconds (0: at once): the valley's grey lifts to the
## place's gloom (never back up), its warm pools open, and its embers catch as the front reaches them.
func _warm_place(place: Dictionary, duration: float) -> void:
	if CurseField.valley_gloom > float(place["gloom"]):
		CurseField.set_valley_gloom(float(place["gloom"]), duration)
	var lights: Array = place.get("lights", [])
	for i in lights.size():
		var l: Array = lights[i]
		var id := StringName("%s_%d" % [place["zone"], i])
		var c: Array = l[4]
		var at := Vector3(l[0], l[1], l[2])
		if duration > 0.0:
			pools.light_up(id, at, float(l[3]), Color(c[0], c[1], c[2]), float(l[5]), duration)
		else:
			pools.set_light(id, at, float(l[3]), Color(c[0], c[1], c[2]), float(l[5]))
	if duration <= 0.0 or place.get("embers", []).is_empty():
		return
	await get_tree().create_timer(duration * 0.6, false).timeout
	for e: Array in place["embers"]:
		Vfx.play(&"kindle_catch", Vector3(e[0], e[1], e[2]), {"kind": "brazier"})


## The Dregs' track while it is awake (the director keeps it through deaths and zones), else the
## kiln's cursed and restored pair.
func _set_music() -> void:
	if get_flag(&"dregs_started") and not get_flag(&"dregs_unravelled"):
		Audio.set_level_music(&"hollow_kiln_dregs")
	else:
		Audio.set_level_music(&"hollow_kiln_cursed", &"hollow_kiln_restored")


## VatCam (behind Orimi, tilted up to the Dregs' head) only while the Dregs is awake: before it the
## plain camera, so the third verse-stone at Orimi's feet can be seen, and after it unravels, so the
## finale's Bloom on the vat is seen from the floor. TieCam (both pillar rings and the vat) only while
## it climbs. ArenaDoorCam at the door is always on.
func _set_cams() -> void:
	var fighting := get_flag(&"dregs_started") and not get_flag(&"dregs_unravelled")
	(get_node(^"VatCam") as CameraZone).size = _cam_sizes["VatCam"] if fighting else Vector3.ZERO
	var climbing := get_flag(&"dregs_arms_cut") and not get_flag(&"dregs_bound")
	(get_node(^"TieCam") as CameraZone).size = _cam_sizes["TieCam"] if climbing else Vector3.ZERO


func _start_at(start: String) -> void:
	var s: Dictionary = (data.get("qa_starts", {}) as Dictionary).get(start, {})
	if s.is_empty():
		push_warning("hollow_kiln: no qa start '%s'" % start)
		return
	spawn_marker = String(s["marker"])
	data["spawn_facing"] = String(s["face"])
	for f: Variant in s.get("flags", []):
		set_flag(StringName(f))
	for fight: Node in get_tree().get_nodes_in_group(&"sealed_fight"):
		if is_ancestor_of(fight) and get_flag(fight.get(&"done_flag")):
			fight.set(&"done", true)
	var ap: Dictionary = data.get("autoplay", {})
	ap["route"] = s.get("route", [])
	data["autoplay"] = ap


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var rise := get_node_or_null(^"FlueRise") as RisingHazard
	var pool := get_node(^"Set").find_child("InkPool", true, false) as Node3D
	if rise != null and pool != null:
		pool.global_position.y = rise.surface_y()
		pool.visible = not get_flag(&"vat_bloomed")
	var at := player.global_position
	var want := 0.0
	for d: Dictionary in data.get("dark_places", []):
		var lo: Array = d["box"][0]
		var hi: Array = d["box"][1]
		if at.x < lo[0] or at.x > hi[0] or at.y < lo[1] or at.y > hi[1] or at.z < lo[2] or at.z > hi[2]:
			continue
		var entered := StringName(d.get("enter_flag", ""))
		if entered != &"" and not get_flag(entered):
			set_flag(entered)
		if not get_flag(StringName(d.get("until", ""))):
			want = maxf(want, float(d["darkness"]))
	if want != _dark:
		_dark = want
		pools.set_darkness(want, 1.2)
	if want > 0.0:
		pools.set_light(&"orimi", at + Vector3.UP * 1.2, 3.5, LightPools.WARM, 0.45)
	elif pools.has_light(&"orimi"):
		pools.remove_light(&"orimi")


## The kiln is roofed and stacked (ledges over ledges in the flue, the dome over the vat), and
## Level.ground_at looks down from 40 m up, which lands markers, checkpoints and autoplay waypoints
## on whatever is overhead. When it finds ground more than 2.5 m above the point, look again from
## just above the point, and keep the high answer only when nothing is under it (a point that fell
## through the floor).
func ground_at(p: Vector3, ignore: Node = null) -> Vector3:
	var top := super.ground_at(p, ignore)
	if top.y <= p.y + 2.5:
		return top
	var from := Vector3(p.x, p.y - 37.5, p.z)
	var near := super.ground_at(from, ignore)
	return top if near == from else near


func _on_kindled(k: Node3D) -> void:
	_play(k, &"lit")
	pools.light_up(k.name, k.global_position + Vector3.UP * 0.5, float(k.get(&"light_range")), k.get(&"light_color"))


func _on_glyph_target(_glyph: StringName, _info: Dictionary, t: Node3D) -> void:
	if not String(t.name).begins_with("MossFoothold"):
		_play(t, &"blow")
		return
	_play(t, &"bloom")
	(get_node("MossLedge_" + String(t.name).get_slice("_", 1)) as StaticBody3D).collision_layer = Layers.WORLD


func _on_flag(flag: StringName, on: bool) -> void:
	if not on:
		return
	match flag:
		&"counterweight_tied":
			var cw := get_node(^"Set").find_child("Counterweight", true, false)
			if cw != null:
				_play(cw, &"open")
		&"dregs_started":
			_set_cams()
			_set_music()
		&"dregs_arms_cut", &"dregs_bound":
			_set_cams()
		&"dregs_unravelled":
			_set_cams()
			_set_music()
		&"verse_4_read":
			_ending()


## Bloom on the cracked vat (Zone_vat, finale): the tree grows up through the dome, the river runs
## clear from its roots, every zone clears and the valley's grey lifts.
func run_finale(zone: CursedZone) -> void:
	Game.set_state(Game.STATE_CUTSCENE)
	if is_instance_valid(Game.main):
		Game.main.hud.hide_prompt()
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	var vat := marker("M_Vat")
	Events.finale_started.emit(vat)
	var tree := find_child("VatTree", true, false) as Node3D
	if tree != null:
		tree.visible = true
		_play(tree, &"grow")
	await camera.cinematic_to(vat + Vector3(9.0, 4.0, 11.0), vat + Vector3.UP * 6.0, 2.4).finished
	for z: Node in get_tree().get_nodes_in_group(Layers.GROUP_CURSED_ZONE):
		(z as CursedZone).restore()
	_set_water(CLEAR_WATER)
	CurseField.set_valley_gloom(0.0, 6.0)
	await camera.cinematic_to(vat + Vector3(-7.0, 1.5, 9.0), vat + Vector3(0.0, 30.0, 0.0), 3.0).finished
	await get_tree().create_timer(1.0, false).timeout
	set_flag(&"vat_bloomed")
	Events.valley_restored.emit()
	_set_verse_4(true)
	var to_tree := vat - player.global_position
	player.rotation.y = atan2(-to_tree.x, -to_tree.z)
	camera.release()
	camera.snap_behind(player)
	camera.pitch = deg_to_rad(12.0)
	camera.snap()
	player.control_enabled = true
	Game.set_state(Game.STATE_PLAYING)


## After the last verse-stone: Pell in the chamber door (PellEnd, shown once the vat blooms), then
## the valley from above the dome.
func _ending() -> void:
	Game.set_state(Game.STATE_CUTSCENE)
	player.control_enabled = false
	var pell := find_child("PellEnd", true, false) as Node3D
	if pell != null:
		var d := player.global_position - pell.global_position
		pell.rotation.y = atan2(-d.x, -d.z)
	await get_tree().create_timer(1.5, false).timeout
	var view := marker("M_EndView")
	await camera.cinematic_to(view, view + Vector3(0.0, -45.0, 80.0), 5.0).finished
	await get_tree().create_timer(2.0, false).timeout
	complete()


## The fourth verse-stone is lifted out of the floor by the tree's roots.
func _set_verse_4(shown: bool) -> void:
	var stone := find_child("VerseStone_4", true, false) as CollisionObject3D
	if stone == null:
		return
	stone.visible = shown
	stone.collision_layer = (Layers.WORLD | Layers.BRUSH_TARGET) if shown else 0
	if shown:
		stone.add_to_group(Layers.GROUP_BRUSH_TARGET)
	else:
		stone.remove_from_group(Layers.GROUP_BRUSH_TARGET)


func _set_water(path: String) -> void:
	var water := find_child("Water", true, false)
	if water == null or not ResourceLoader.exists(path):
		return
	var mat: Material = load(path)
	for mi: Node in water.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat


func _play(node: Node, anim: StringName) -> void:
	var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation(anim):
		ap.play(anim)
