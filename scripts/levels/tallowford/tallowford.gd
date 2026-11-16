extends Level
## Tallowford: the lamp-makers' village. The scene is generated (tools/levels/tallowford/level_scene.py)
## and the data is level.json; this script adds what the kit does not do by itself, driven by the
## level-local "tallowford" section of level.json: the dressing and dusk tints, colour coming back
## in pools round lit lamps (render's LightPools, drained), prompts when Orimi comes near a place,
## our models' animations (persimmon, ford-lamp hood, cottage lamps) and the finale. Owner: l2.

const LAYOUT := "res://scripts/levels/tallowford/layout.json"
const COTTAGE_LAMP_DELAY := 0.4
const COTTAGE_POOL := 4.5
const AUDIO_DIR := "res://audio/levels/tallowford/"

var plan: Dictionary
var layout: Dictionary
var pools := LightPools.new()
var dressing := TallowfordDressing.new()
var _warping := false
var _near_shown := {}
var _near_t := 0.0
var _walk := false
var _snag_t := 0.0
var _snag_from := Vector3.ZERO
var _snags := {}


func _build(_progress: Callable) -> void:
	plan = data.get("tallowford", {})
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	dressing.build(self, get_node(^"River") as Node3D, layout)
	dressing.tint(self, false)
	_play(node("PersimmonTree"), &"withered")
	pools.name = "LightPools"
	add_child(pools)
	dressing.light(pools)
	Audio.register_music(&"tallowford_cursed", AUDIO_DIR + "tallowford_cursed.ogg")
	Audio.register_music(&"tallowford_restored", AUDIO_DIR + "tallowford_restored.ogg")
	Audio.set_level_music(&"tallowford_cursed", &"tallowford_restored")
	CurseField.set_valley_gloom(0.0)
	pools.set_drained(1.0)
	var finale_cam := node("FinaleCam")
	if finale_cam != null:
		finale_cam.remove_from_group(&"camera_zone")
	for lamp: Node in find_children("Lamp_*", "StaticBody3D", true, false):
		if lamp is KindleTarget:
			var target := lamp as KindleTarget
			target.kindled.connect(func() -> void: _lamp_lit(target))
	flag_changed.connect(_on_flag)
	if String(Boot.opt("tf_route", "")) == "walk":
		_start_walk()


func _exit_tree() -> void:
	super._exit_tree()
	Audio.set_level_music(&"")


## QA (boot option tf_route=walk): swap the autoplay route for the collision walk in level.json
## (tallowford.walk), from the lit village, and log tf_snag wherever Orimi is steered but stays put.
func _start_walk() -> void:
	var walk: Dictionary = plan.get("walk", {})
	data["autoplay"] = {"chain": [], "route": walk.get("route", [])}
	_walk = true
	while not built:
		await get_tree().process_frame
	apply_warp(String(walk.get("warp", "M_PellWait")))


func _physics_process(delta: float) -> void:
	if not _walk or player == null or not Game.is_playing():
		return
	_snag_t += delta
	if _snag_t < 0.75:
		return
	var at := player.global_position
	if player.ai_move.length() > 0.3 and Vector2(at.x - _snag_from.x, at.z - _snag_from.z).length() < 0.3:
		var cell := Vector2i(roundi(at.x / 2.0), roundi(at.z / 2.0))
		if not _snags.has(cell):
			_snags[cell] = true
			Game.qa_log("tf_snag", {"at": Game._v(at), "toward": Game._v(player.ai_move)})
	_snag_t = 0.0
	_snag_from = at


func _lamp_lit(lamp: KindleTarget) -> void:
	var key := String(lamp.name).trim_prefix("Lamp_")
	var at := marker("M_Kindle_" + key)
	var r := float((plan.get("pools", {}) as Dictionary).get(key, 6.5))
	if _warping:
		pools.set_light(lamp.name, at, r)
	else:
		pools.light_up(lamp.name, at, r, LightPools.WARM, 1.0, 1.6)


func _process(delta: float) -> void:
	_near_t += delta
	if _near_t < 0.25 or player == null or Game.main == null:
		return
	_near_t = 0.0
	for spec: Dictionary in plan.get("near", []):
		var id := String(spec.lines)
		var m := marker(spec.at)
		var close := Vector2(player.global_position.x - m.x, player.global_position.z - m.z).length() < float(spec.radius)
		var open := close and not get_flag(StringName(spec.unless))
		if open and not _near_shown.get(id, false):
			_near_shown[id] = true
			var text := " ".join(lines(id).map(func(l: Dictionary) -> String: return String(l.get("text", ""))))
			Game.main.prompt_near(StringName("tf_" + id), text, &"")
		elif not open and _near_shown.get(id, false):
			_near_shown[id] = false
			Game.main.hide_prompt(StringName("tf_" + id))


func apply_warp(marker_name: String) -> bool:
	_warping = true
	var ok := super.apply_warp(marker_name)
	_warping = false
	return ok


func _on_warp(_marker_name: String) -> void:
	for lamp: Node in find_children("Lamp_*", "StaticBody3D", true, false):
		if lamp is KindleTarget and get_flag((lamp as KindleTarget).lit_flag):
			(lamp as KindleTarget).kindle(true)
	for o: Node in find_children("*", "StaticBody3D", true, false):
		if o is GlyphObstacle and (o as GlyphObstacle).cleared_flag != &"" and get_flag((o as GlyphObstacle).cleared_flag):
			(o as GlyphObstacle).remove_silently()


func _on_flag(flag: StringName, on: bool) -> void:
	if not on:
		return
	match flag:
		&"persimmon_bloomed":
			_play(node("PersimmonTree"), &"bloom", _warping)
		&"hood_cleared":
			var lamp := node("Lamp_Ford")
			if lamp != null and lamp.get(&"model") != null:
				(lamp.get(&"model") as Node).call(&"play", &"unhood")
		&"lit_ford":
			_finale()
	var said: String = (plan.get("on_flag", {}) as Dictionary).get(String(flag), "")
	if said != "":
		if not _warping and Game.main != null:
			await Game.main.talk.run(lines(said))
		set_flag(StringName("said_" + said))


func _finale() -> void:
	var instant := _warping
	pools.set_drained(0.0, 0.0 if instant else 3.0)
	Audio.set_level_music(&"tallowford_cursed", &"tallowford_restored", true)
	dressing.tint(self, true)
	var finale_cam := node("FinaleCam")
	if finale_cam != null:
		finale_cam.add_to_group(&"camera_zone")
	var pell := node("Pell") as Node3D
	if pell != null and has_marker("M_PellWait"):
		pell.global_position = ground_at(marker("M_PellWait"))
	var lamp := marker("M_FordLamp")
	for person: Node in get_node(^"People").get_children():
		var spot := get_node_or_null(NodePath("Kit/Gather/M_Gather_" + String(person.name))) as Node3D
		if spot == null:
			continue
		var p := person as Node3D
		p.global_position = ground_at(spot.global_position, p)
		var d := lamp - p.global_position
		p.rotation.y = atan2(d.x, d.z)
	for k in range(1, 5):
		if not instant:
			await get_tree().create_timer(COTTAGE_LAMP_DELAY, false).timeout
		var at := marker("M_Kindle_Cottage%d" % k)
		_play(_nearest_prop("LampPost", marker("M_Lamp_Cottage%d" % k)), &"lit")
		pools.set_light(StringName("Cottage%d" % k), at, COTTAGE_POOL)


func _nearest_prop(prefix: String, at: Vector3) -> Node3D:
	var best: Node3D = null
	for n: Node in get_node(^"Props").get_children():
		if String(n.name).begins_with(prefix) and (best == null or (n as Node3D).global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = n
	return best


func _play(model: Node, animation: StringName, to_end: bool = false) -> void:
	if model == null:
		return
	var anim := model.get_node_or_null(^"%AnimationPlayer") as AnimationPlayer
	if anim == null or not anim.has_animation(animation):
		return
	anim.play(animation)
	if to_end:
		anim.seek(anim.current_animation_length, true)
