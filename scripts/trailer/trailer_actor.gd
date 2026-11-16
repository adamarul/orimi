class_name TrailerActor
extends AutoplayDirector
## Plays one trailer shot's steps through the real game. It reuses the autoplay runner (the same
## route steps, walking, fights and talk), with two changes for the camera: time is the game's own
## clock (Movie Maker renders at a fixed 60 fps whatever the machine load, so wall-clock time would
## drift from what is recorded), and every glyph is drawn live through the real input path: the
## brush action is pressed, the left mouse button goes down and the pointer travels the stroke over
## several frames, so the brush paints, recognises and casts exactly as it does for a player.
## Owner: trailer.

## Stroke drawing speed, in viewport heights per second.
var draw_speed := 0.85
## Seconds the paper is held open before the tip touches down, and after it lifts.
var open_hold := 0.28
var lift_hold := 0.22
## Scales the autoplay's settle time before each cast (it waits for the camera to turn).
var settle_scale := 0.7
## When false, casting leaves the camera alone (a placed trailer camera is framing the shot).
var steer_camera := true
## Gameplay camera pitch in degrees, held every frame when set (NAN: leave it to the steps).
## Looking a little further down than the autoplay does keeps the sky out of a running shot.
var pitch_override := NAN
## Game seconds each talk line stays up before the trailer advances it.
var line_time := 2.6

var clock := 0.0
var cast_log: Array = []
var _casting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Before the gameplay camera, so a held pitch is what it reads this frame.
	process_priority = -100


func _process(delta: float) -> void:
	clock += delta
	if not is_nan(pitch_override) and not _casting and is_instance_valid(_level) and not _level.camera.cinematic:
		_level.camera.pitch = deg_to_rad(pitch_override)


func setup(level: Level) -> void:
	_level = level
	_player = level.player
	_player.ai_enabled = true
	_t0 = _now()
	_load_chain()


func run(steps: Array) -> void:
	for s: Variant in steps:
		await _step(s as Dictionary)


func _now() -> float:
	return clock


func _stage(stage_name: String, _extra: Dictionary = {}) -> void:
	print("TRAILER_STAGE %s t=%.2f" % [stage_name, clock])


func _shot(_stage_name: String) -> void:
	pass


func _fail(what: String) -> void:
	failures.append(what)
	print("TRAILER_FAIL %s" % what)


## Talk the way the autoplay does, but advance each line on the game clock (the panel's own
## autoplay timer reads the wall clock, which runs at a different rate under Movie Maker).
func _talk(person: Node) -> void:
	if person == null:
		return
	var n := person as Node3D
	await _go(_before(n.global_position, _player.global_position, 1.6))
	var talk: Node = Game.main.get(&"talk")
	person.call("talk")
	await _wait_until(func() -> bool: return bool(talk.get(&"is_open")), 3.0)
	var until := clock + 60.0
	while bool(talk.get(&"is_open")) and clock < until:
		var next := clock + line_time
		while clock < next and bool(talk.get(&"is_open")):
			talk.set(&"_shown_at", Time.get_ticks_msec() / 1000.0)
			await get_tree().process_frame
		if bool(talk.get(&"is_open")):
			talk.set(&"_shown_at", Time.get_ticks_msec() / 1000.0 - 1.0)
			talk.call(&"advance")
	await _wait(0.4)


func _cast(glyph: StringName, target: Node3D, settle: float = 0.9, tie_posts: Array = []) -> bool:
	_casting = true
	var hit := await _cast_live(glyph, target, settle, tie_posts)
	_casting = false
	return hit


## The autoplay's cast with the stroke drawn live. The held pitch is let go while it aims, so a
## target high on a post is framed the way the autoplay frames it.
func _cast_live(glyph: StringName, target: Node3D, settle: float, tie_posts: Array) -> bool:
	if not is_instance_valid(target):
		return false
	var anchor: Vector3 = target.call("glyph_anchor") if target.has_method("glyph_anchor") else target.global_position + Vector3.UP * 0.8
	var radius: float = target.call("glyph_radius") if target.has_method("glyph_radius") else 1.0
	_player.ai_move = Vector3.ZERO
	if steer_camera:
		_level.camera.face_toward(anchor, -14.0)
	await _wait(maxf(settle * settle_scale, 0.1))
	if not is_instance_valid(target):
		return false
	var cam := get_viewport().get_camera_3d()
	var vp := get_viewport().get_visible_rect()
	var center := Vector2.ZERO
	var r_px := 0.0
	for attempt in 4:
		if not is_instance_valid(target):
			return false
		anchor = target.call("glyph_anchor") if target.has_method("glyph_anchor") else target.global_position
		var behind := cam.is_position_behind(anchor)
		center = cam.unproject_position(anchor)
		r_px = maxf(center.distance_to(cam.unproject_position(anchor + cam.global_basis.x * radius)), 24.0)
		if not behind and vp.grow(-60.0).has_point(center) and r_px < 240.0:
			break
		var away := _player.global_position - target.global_position
		away.y = 0.0
		_player.ai_move = away.normalized() if away.length() > 0.1 else Vector3.BACK
		await _wait(0.5)
		_player.ai_move = Vector3.ZERO
		if steer_camera:
			_level.camera.face_toward(anchor, -14.0)
		await _wait(0.7)
	var pts := _stroke_points(glyph, center, r_px)
	if glyph == &"kindle":
		pts = PackedVector2Array([center])
	if glyph == &"tie" and tie_posts.size() == 2 and is_instance_valid(tie_posts[1]):
		var b: Vector3 = (tie_posts[1] as Node3D).call("glyph_anchor")
		pts = PackedVector2Array([center, cam.unproject_position(b)])
	var info := await draw_stroke(pts)
	var targets: Array = info.get("targets", [])
	var record := {"glyph": String(glyph), "target": String(target.name), "recognised": String(info.get("glyph", "")),
		"hit": info.get("glyph", &"") == glyph and target in targets, "t": snappedf(clock, 0.01),
		"score": snappedf(float(info.get("score", 0.0)), 0.01)}
	if info.is_empty():
		record["reason"] = String(Brush.last_result.get("reason", ""))
	cast_log.append(record)
	casts.append(record)
	print("TRAILER_CAST %s" % JSON.stringify(record))
	return record["hit"]


## Draw one stroke given in viewport pixels through the input system, frame by frame, and return
## the glyph info the brush cast ({} if it recognised nothing).
func draw_stroke(pts: PackedVector2Array) -> Dictionary:
	var result := {}
	var on_cast := func(_g: StringName, info: Dictionary) -> void: result["info"] = info
	Events.glyph_cast.connect(on_cast)
	Brush.refill()
	_send_brush(true)
	var until := clock + 1.5
	while not Brush.is_open() and clock < until:
		await get_tree().process_frame
	await _wait(open_hold)
	var to_window := get_tree().root.get_final_transform()
	var pos := pts[0]
	_send_button(to_window * pos, true)
	await get_tree().process_frame
	if pts.size() > 1:
		var speed := draw_speed * get_viewport().get_visible_rect().size.y
		var i := 1
		while i < pts.size():
			var budget := speed * get_process_delta_time()
			while budget > 0.0 and i < pts.size():
				var d := pos.distance_to(pts[i])
				var nxt: Vector2
				if d <= budget:
					nxt = pts[i]
					budget -= d
					i += 1
				else:
					nxt = pos.move_toward(pts[i], budget)
					budget = 0.0
				_send_motion(to_window * nxt, to_window * pos)
				pos = nxt
			await get_tree().process_frame
	else:
		await get_tree().process_frame
	_send_button(to_window * pos, false)
	await _wait(lift_hold)
	_send_brush(false)
	until = clock + 3.0
	while Brush.is_open() and clock < until:
		await get_tree().process_frame
	Events.glyph_cast.disconnect(on_cast)
	return result.get("info", {})


func _send_brush(down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = &"brush"
	ev.pressed = down
	ev.strength = 1.0 if down else 0.0
	Input.parse_input_event(ev)


func _send_button(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(ev)


func _send_motion(at: Vector2, from: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.relative = at - from
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)
