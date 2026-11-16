extends Level
## The Hollow Kiln (Level 5), scenes/levels/hollow_kiln/hollow_kiln.tscn, written by
## tools/levels/hollow_kiln/make_level.py. The kit does most of it (docs/LEVEL_KIT.md); this script
## sets the drained look of the set's props and water, plays the models of the kit's Kindle and
## glyph targets (bellows blow, moss blooms and its MossLedge ramp turns solid), darkens the hall, the flue and
## the vat chamber with render's light pools (level.json "dark_places") so lit lamps and mouths open
## pools, plays the level's music (the Dregs' own track from dregs_started until it unravels), keeps the camera behind Orimi in the vat chamber (VatCam) until the Dregs unravels and frames both pillar rings (TieCam) while it climbs, lifts the counterweight door when it is tied, runs the finale (the tree, the clear river)
## and the ending (Pell, the valley), and has one QA hook:
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


func _exit_tree() -> void:
	super._exit_tree()
	Audio.set_level_music(&"")


## The Dregs' track while it is awake (the director keeps it through deaths and zones), else the
## kiln's cursed and restored pair.
func _set_music() -> void:
	if get_flag(&"dregs_started") and not get_flag(&"dregs_unravelled"):
		Audio.set_level_music(&"hollow_kiln_dregs")
	else:
		Audio.set_level_music(&"hollow_kiln_cursed", &"hollow_kiln_restored")


## VatCam (behind Orimi) until the Dregs unravels: after that the plain camera, so the finale's Bloom
## on the vat is seen from the floor. TieCam (both pillar rings and the vat) only while it climbs.
func _set_cams() -> void:
	(get_node(^"VatCam") as CameraZone).size = Vector3.ZERO if get_flag(&"dregs_unravelled") else _cam_sizes["VatCam"]
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
	camera.release()
	camera.snap_behind(player)
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
