extends Node
## Trailer director. Boots the real game (scenes/game/main.tscn) under this node, sets up one shot
## from scripts/trailer/shots.json, plays it through TrailerActor, and prints frame marks for the
## edit: TRAILER_IN frame=<n> when the shot starts and TRAILER_OUT frame=<n> when it ends, then quits.
## Card shots draw a text card on the game's paper instead. Run it under Movie Maker with
## tools/trailer/capture.sh <shot id>. Boot: scene=res://scenes/trailer/director.tscn shot=<id>.
## playthrough=<level id> instead films the book from the title screen to the end of that level
## (the card after it), played by PlaythroughActor (tools/trailer/playthrough.sh).
## Owner: trailer.

const SHOTS := "res://scripts/trailer/shots.json"
const MAIN := "res://scenes/game/main.tscn"
const LOAD_TIMEOUT := 240.0

var spec: Dictionary = {}
var main: Node
var level: Level
var actor: TrailerActor
var rig: Camera3D
var _clock := 0.0
var _rig_t := 0.0
var _rig_keys: Array = []
var _rig_smooth := 4.0
var _rig_xf := Transform3D.IDENTITY
var _rig_started := false
var _hud := "auto"
var _rolling := false
var _playthrough := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var through := String(Boot.opt("playthrough", ""))
	if through != "":
		_run_playthrough(StringName(through))
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHOTS))
	var id := String(Boot.opt("shot", ""))
	for s: Dictionary in data.get("shots", []):
		if String(s.get("id", "")) == id:
			spec = s
	if spec.is_empty():
		push_error("Trailer: no shot '%s' in %s" % [id, SHOTS])
		get_tree().quit(1)
		return
	_watchdog(LOAD_TIMEOUT + float(spec.get("max", 40.0)) + 60.0)
	if String(spec.get("type", "")) == "card":
		_run_card()
	else:
		_run_shot()


func _process(delta: float) -> void:
	_clock += delta
	if _rolling and main != null and _playthrough:
		_pace_talk(main.get(&"talk") as Node)
	elif _rolling and main != null:
		var hud: GameHud = main.get(&"hud")
		match _hud:
			"on":
				hud.visible = Game.state == Game.STATE_PLAYING or Brush.is_open()
			"off":
				hud.visible = false
			_:
				hud.visible = Game.state != Game.STATE_CUTSCENE
		if not bool(spec.get("hints", false)) and hud.prompt_panel.visible:
			hud.hide_prompt()
		if not bool(spec.get("banners", true)):
			hud.banner.visible = false
		# The talk panel's "click, E or Enter" footer is an instruction, not part of the line.
		var talk := main.get(&"talk") as Node
		var more: Variant = talk.get(&"_more")
		if more is Control:
			(more as Control).visible = false
		_pace_talk(talk)
	if rig != null and _rig_started:
		if not Brush.is_open():
			_rig_t += delta
		var want := _rig_at(_rig_t)
		_rig_xf = want if _rig_smooth <= 0.0 else _rig_xf.interpolate_with(want, 1.0 - exp(-_rig_smooth * delta))
		rig.global_transform = _rig_xf


## Under autoplay the talk panel advances a line after a wall-clock second, which is a different
## length of film under Movie Maker. Hold each line for line_time seconds of game time instead.
var _line_key := ""
var _line_since := 0.0


func _pace_talk(talk: Node) -> void:
	if not bool(talk.get(&"is_open")):
		_line_key = ""
		return
	var index := int(talk.get(&"_index"))
	var lines: Array = talk.get(&"_lines")
	var key := "%d:%s" % [index, str(lines.hash())]
	if key != _line_key:
		_line_key = key
		_line_since = _clock
	var hold := float(spec.get("line_time", 2.6))
	if spec.has("per_char") and index < lines.size():
		hold = maxf(hold, float(spec["per_char"]) * String((lines[index] as Dictionary).get("text", "")).length())
	var now_real := Time.get_ticks_msec() / 1000.0
	if _clock - _line_since < hold:
		talk.set(&"_shown_at", now_real)
	else:
		talk.set(&"_shown_at", now_real - 5.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _wait_until(cond: Callable, timeout: float) -> bool:
	var until := _clock + timeout
	while _clock < until:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _mark(which: String) -> void:
	await RenderingServer.frame_post_draw
	print("TRAILER_%s frame=%d t=%.3f shot=%s" % [which, Engine.get_frames_drawn(), _clock, String(spec["id"])])


func _quit(code: int) -> void:
	await get_tree().process_frame
	get_tree().quit(code)


# --- game shots ---------------------------------------------------------------------------

func _run_shot() -> void:
	Boot.options.erase("level")
	Boot.options.erase("warp")
	Boot.options["autoplay"] = "1"
	Boot.options["god"] = "1"
	Boot.options["fresh"] = "1"
	if not bool(spec.get("music_in_clip", false)):
		Settings.music_volume = 0.0
	main = (load(MAIN) as PackedScene).instantiate()
	# The game starts its own autoplay run when autoplay=1; the trailer drives Orimi itself.
	main.set(&"_autoplay_started", true)
	add_child(main)
	if not await _wait_until(func() -> bool: return bool(main.get(&"title_ready")), LOAD_TIMEOUT):
		_abort("title never became ready")
		return
	var want := StringName(String(spec.get("level", "hazewater")))
	if Game.level == null or Game.level.level_id != want:
		main.call(&"choose_level", want)
	else:
		main.call(&"start_game")
	if not await _wait_until(func() -> bool: return bool(main.get(&"intro_open")), LOAD_TIMEOUT):
		_abort("level %s never opened" % want)
		return
	if bool(spec.get("arrive", false)):
		# Pell's raft brings Orimi in, as it does after travelling from the level before.
		main.set(&"_arrive_next", true)
	main.call(&"dismiss_intro")
	level = Game.level
	await _wait(0.2)
	if spec.has("warp"):
		level.apply_warp(String(spec["warp"]))
	for f: Variant in spec.get("flags", []):
		level.set_flag(StringName(f))
	actor = TrailerActor.new()
	actor.name = "TrailerActor"
	add_child(actor)
	actor.setup(level)
	for k: String in ["draw_speed", "open_hold", "lift_hold", "settle_scale", "pitch_override", "line_time"]:
		if spec.has(k):
			actor.set(k, float(spec[k]))
	for s: Dictionary in spec.get("prep", []):
		await _prep(s)
	await actor.run(spec.get("setup", []))
	_hud = String(spec.get("hud", "auto"))
	_rolling = true
	if spec.has("camera"):
		_start_rig(spec["camera"])
	await _wait(float(spec.get("preroll", 1.0)))
	await _mark("IN")
	var started := _clock
	var steps: Array = spec.get("steps", [])
	var max_len := float(spec.get("max", 40.0))
	var done := [false]
	var runner := func() -> void:
		await actor.run(steps)
		done[0] = true
	runner.call()
	await _wait_until(func() -> bool: return done[0], max_len)
	var tail := float(spec.get("tail", 1.0))
	var min_len := float(spec.get("min", 0.0))
	await _wait(maxf(tail, min_len - (_clock - started)))
	await _mark("OUT")
	var ok: bool = actor.failures.is_empty()
	print("TRAILER_RESULT %s" % JSON.stringify({"shot": spec["id"], "ok": ok, "failures": actor.failures, "casts": actor.cast_log}))
	_quit(0 if ok else 3)


# --- playthrough --------------------------------------------------------------------------

## The real game from its title screen: the autoplay's route played with live strokes, the HUD,
## hints and talk panels as a player sees them, and the game's music and sound. Marks IN when the
## title is ready and OUT when the level is over: tail=<s> (default 3) into the end card when it is
## the book's last level, or as the screen fades to paper for the travel on to the next one
## (tail 0.2 there, as the next level opens at once).
func _run_playthrough(id: StringName) -> void:
	spec = {"id": "playthrough_%s" % id, "line_time": 2.4, "per_char": 0.045}
	_watchdog(LOAD_TIMEOUT + 1800.0)
	Boot.options.erase("level")
	Boot.options.erase("warp")
	Boot.options["autoplay"] = "1"
	Boot.options["fresh"] = "1"
	main = (load(MAIN) as PackedScene).instantiate()
	main.set(&"_autoplay_started", true)
	add_child(main)
	_playthrough = true
	_rolling = true
	if not await _wait_until(func() -> bool: return bool(main.get(&"title_ready")), LOAD_TIMEOUT):
		_abort("title never became ready")
		return
	await _mark("IN")
	var player := PlaythroughActor.new()
	player.name = "PlaythroughActor"
	add_child(player)
	player.play_book()
	var travel := main.get(&"_travel") as Control
	var over := func() -> bool: return bool(main.get(&"end_open")) or (Game.is_level_completed(id) and travel.visible)
	if not await _wait_until(over, 1800.0):
		_abort("level %s never ended" % id)
		return
	print("TRAILER_STAGE level_over t=%.2f" % player.clock)
	await _wait(float(Boot.opt("tail", "3" if bool(main.get(&"end_open")) else "0.2")))
	await _mark("OUT")
	var ok: bool = player.failures.is_empty()
	print("TRAILER_RESULT %s" % JSON.stringify({"shot": spec["id"], "ok": ok, "failures": player.failures, "casts": player.cast_log}))
	_quit(0 if ok else 3)


func _watchdog(seconds: float) -> void:
	await _wait(seconds)
	_abort("watchdog: shot ran past %.0f s" % seconds)


func _abort(why: String) -> void:
	print("TRAILER_FAIL %s" % why)
	print("TRAILER_RESULT %s" % JSON.stringify({"shot": spec.get("id", ""), "ok": false, "failures": [why]}))
	_quit(3)


## Preparation that is not a route step: things done before the camera rolls.
func _prep(s: Dictionary) -> void:
	if s.has("clear_zone"):
		var z := level.node(String(s["clear_zone"])) as CursedZone
		if z != null:
			for e: Variant in z.enemies:
				if is_instance_valid(e):
					(e as Node).queue_free()
			z.enemies.clear()
			z.set(&"_waves", [])
			z.is_cleared = true
	elif s.has("teleport"):
		var p: Array = s["teleport"]
		var at := level.ground_at(Vector3(float(p[0]), float(p[1]), float(p[2])))
		var yaw := deg_to_rad(float(s.get("yaw", 0.0)))
		if s.has("face"):
			var f := _point(s["face"])
			yaw = atan2(-(f.x - at.x), -(f.z - at.z))
		level.player.teleport(at + Vector3.UP * 0.05, yaw)
		level.camera.snap_behind(level.player)
	elif s.has("face"):
		level.camera.face_toward(_point(s["face"]), float(s.get("pitch", GameCamera.PITCH_DEFAULT)))
		level.camera.snap()
	elif s.has("wait"):
		await _wait(float(s["wait"]))


# --- placed camera ------------------------------------------------------------------------

## camera: {"keys": [{"t": 0, "pos": P, "look": P, "fov": 50}, ...], "smooth": 4}. A point P is
## [x, y, z], {"ground": [x, z], "up": h}, {"marker": name, "off": [x, y, z]},
## {"node": name, "off": [...]} or {"player": [x, y, z]} (offset from Orimi, in world axes).
func _start_rig(cam: Dictionary) -> void:
	_rig_keys = cam.get("keys", [])
	if _rig_keys.is_empty():
		return
	_rig_smooth = float(cam.get("smooth", 4.0))
	rig = Camera3D.new()
	rig.name = "TrailerCamera"
	rig.near = 0.08
	rig.far = 400.0
	rig.fov = float((_rig_keys[0] as Dictionary).get("fov", 50.0))
	level.add_child(rig)
	_rig_t = 0.0
	_rig_xf = _rig_at(0.0)
	rig.global_transform = _rig_xf
	rig.make_current()
	_rig_started = true
	if actor != null:
		actor.steer_camera = bool(cam.get("steer", false))


func _rig_at(t: float) -> Transform3D:
	var a: Dictionary = _rig_keys[0]
	var b: Dictionary = a
	for i in _rig_keys.size():
		var k: Dictionary = _rig_keys[i]
		if float(k.get("t", 0.0)) <= t:
			a = k
			b = _rig_keys[mini(i + 1, _rig_keys.size() - 1)]
	var ta := float(a.get("t", 0.0))
	var tb := float(b.get("t", 0.0))
	var u := 0.0 if tb <= ta else clampf((t - ta) / (tb - ta), 0.0, 1.0)
	u = smoothstep(0.0, 1.0, u)
	var pos := _point(a["pos"]).lerp(_point(b["pos"]), u)
	var look := _point(a["look"]).lerp(_point(b["look"]), u)
	rig.fov = lerpf(float(a.get("fov", 50.0)), float(b.get("fov", a.get("fov", 50.0))), u)
	if pos.distance_to(look) < 0.01:
		look = pos + Vector3.FORWARD
	return Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP)


func _point(p: Variant) -> Vector3:
	if p is Array:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	var d: Dictionary = p
	var off := Vector3.ZERO
	if d.has("off"):
		off = Vector3(float(d["off"][0]), float(d["off"][1]), float(d["off"][2]))
	if d.has("ground"):
		var g: Array = d["ground"]
		return level.ground_at(Vector3(float(g[0]), 50.0, float(g[1]))) + Vector3.UP * float(d.get("up", 0.0))
	if d.has("marker"):
		return level.marker(String(d["marker"])) + off
	if d.has("node"):
		var n := level.node(String(d["node"])) as Node3D
		return (n.global_position if n != null else Vector3.ZERO) + off
	if d.has("player"):
		var q: Array = d["player"]
		return level.player.global_position + Vector3(float(q[0]), float(q[1]), float(q[2]))
	return Vector3.ZERO


# --- cards --------------------------------------------------------------------------------

## A text card on the game's paper: the ivory wash and torn paper panel of the title screen, in
## the interface's own theme. "lines": [{"text": "...", "size": 64, "color": "ink"|"vermilion"|"sepia"}].
func _run_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = Layers.CANVAS_MENU
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	layer.add_child(root)
	var wash := ColorRect.new()
	wash.color = Palette.IVORY
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wash)
	var panel := PaperPanel.new()
	panel.seed_value = int(spec.get("seed", 12))
	panel.ragged = 10.0
	panel.stains = 7
	var half := Vector2(float(spec.get("width", 760)), float(spec.get("height", 300))) * 0.5
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -half.x
	panel.offset_right = half.x
	panel.offset_top = -half.y
	panel.offset_bottom = half.y
	panel.drop_shadow = bool(spec.get("panel", true))
	panel.visible = bool(spec.get("panel", true))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", int(spec.get("separation", 10)))
	root.add_child(v)
	var labels: Array[Control] = []
	for line: Dictionary in spec.get("lines", []):
		var color := UiKit.INK
		match String(line.get("color", "ink")):
			"vermilion":
				color = Palette.VERMILION_DEEP
			"sepia":
				color = Palette.SEPIA
		var l := UiKit.label(String(line.get("text", "")), int(line.get("size", 40)), color, HORIZONTAL_ALIGNMENT_CENTER)
		l.modulate.a = 0.0
		v.add_child(l)
		labels.append(l)
		if line.has("gap"):
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, float(line["gap"]))
			v.add_child(gap)
	await get_tree().process_frame
	await _mark("IN")
	var lead := float(spec.get("lead", 0.3))
	var stagger := float(spec.get("stagger", 0.5))
	var fade := float(spec.get("fade", 0.6))
	for i in labels.size():
		var t := create_tween()
		t.tween_interval(lead + stagger * i)
		t.tween_property(labels[i], "modulate:a", 1.0, fade).set_trans(Tween.TRANS_SINE)
	await _wait(float(spec.get("length", 3.0)))
	await _mark("OUT")
	print("TRAILER_RESULT %s" % JSON.stringify({"shot": spec["id"], "ok": true}))
	_quit(0)
