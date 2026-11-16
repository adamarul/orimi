class_name AutoplayDirector
extends Node
## autoplay=1: plays the book from the title through every level in order (or, with
## level=<id>, just that level) and back to the title. Each level supplies its route as data
## (the "autoplay" section of its level.json, see docs/LEVEL_KIT.md); this runner executes
## it through the real systems: Orimi steered by the player's AI inputs, real tail swipes,
## glyphs drawn as strokes through Brush.inject_stroke. Prints a QA line at every stage and a
## summary at the end. Options: shots=<dir> (desktop: a screenshot per stage),
## autoplay_quit=1 (quit when done, exit code 1 on failure), fight_shots=1 (a stage
## <fight>_ring as each sealed fight starts, where the route names no start_stage). Owner: gameplay.

const STAGE_TIMEOUT := 150.0

var failures: Array[String] = []
var stages: Array[String] = []
var casts: Array = []
var simulated: Array = []
var levels_played: Array[String] = []
var _t0 := 0.0
var _shot_dir := ""
var _shot_index := 0
var _level: Level
var _player: OrimiPlayer
var _chain: Array[Vector3] = []
var _slash_kill_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = _now()
	_shot_dir = String(Boot.opt("shots", ""))
	_run()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _stage(stage_name: String, extra: Dictionary = {}) -> void:
	stages.append(stage_name)
	var data := Game.debug_snapshot()
	data["stage"] = stage_name
	data["elapsed"] = snappedf(_now() - _t0, 0.1)
	data.merge(extra, true)
	Game.qa_log("stage", data)
	await _shot(stage_name)


func _shot(stage_name: String) -> void:
	if _shot_dir == "" or Boot.is_web() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_index += 1
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	img.save_png(_shot_dir.path_join("%02d_%s.png" % [_shot_index, stage_name]))


func _fail(what: String) -> void:
	failures.append(what)
	Game.qa_log("autoplay_fail", {"what": what, "level": String(_level.level_id) if _level != null else "", "snapshot": Game.debug_snapshot()})


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _wait_until(cond: Callable, timeout: float) -> bool:
	var until := _now() + timeout
	while _now() < until:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


# --- the run ------------------------------------------------------------------------------

func _run() -> void:
	await _wait(0.5)
	var main: Node = Game.main
	var only_one := Game.start_level != &""
	# warp=<marker> (with level=): start the first level there and resume its route after the
	# warp's route_from stage.
	var warp := String(Boot.opt("warp", "")) if only_one else ""
	main.moment.connect(func(stage: String) -> void: _stage(stage))
	if Game.state == Game.STATE_TITLE:
		await _stage("title")
		await _wait(1.5)
		main.start_game()
		await _wait(0.6)
	while true:
		_level = Game.level
		if _level == null:
			_fail("no level loaded")
			break
		var id := String(_level.level_id)
		levels_played.append(id)
		if main.intro_open:
			await _stage("intro" if levels_played.size() == 1 else id + "_intro")
			await _wait(1.0)
			main.dismiss_intro()
		else:
			main._begin_play(warp if levels_played.size() == 1 else "")
		if not await _wait_until(func() -> bool: return not main.arriving, 30.0):
			_fail("the raft never brought Orimi in to %s" % id)
		_player = _level.player
		_player.ai_enabled = true
		_load_chain()
		await _wait(0.8)
		await _stage("spawn" if id == "hazewater" else id + "_spawn")
		if only_one and String(Boot.opt("beads_check", "0")) == "1":
			# beads_check=1 (with level=, usually completed=): the beads in the HUD, on Orimi's cord
			# close up, and on the pause screen.
			await _show_beads()
			_finish()
			return
		if only_one and String(Boot.opt("end_card", "0")) == "1":
			# end_card=1 (with level=): straight to this level's end card, to check its text.
			main._show_end(_level)
			break
		var route: Array = _level.data.get("autoplay", {}).get("route", [])
		if warp != "" and levels_played.size() == 1:
			route = _route_after_warp(route, warp)
		await _play_route(route)
		if not await _wait_until(func() -> bool: return _level.completed or not is_instance_valid(_level), 30.0):
			_fail("level %s never completed" % id)
			break
		var next := LevelRegistry.next_after(StringName(id))
		if only_one or next == &"" or LevelRegistry.is_dev(StringName(id)):
			break
		if not await _wait_until(func() -> bool: return is_instance_valid(Game.level) and Game.level != _level and main.intro_open, 90.0):
			_fail("travel to %s never arrived" % next)
			break
	if await _wait_until(func() -> bool: return main.end_open, 60.0):
		await _wait(1.6)
		await _stage("end_card")
		main.dismiss_end()
		if not await _wait_until(func() -> bool: return Game.state == Game.STATE_TITLE and main.title_ready, 60.0):
			_fail("did not return to the title")
		await _wait(1.0)
		await _stage("title_again")
	elif not only_one:
		_fail("end card never shown")
	_finish()


func _show_beads() -> void:
	await _stage("hud_beads")
	# Each shot is taken a moment after its QA line (in the browser, by the page): hold the view.
	await _wait(1.2)
	var on_cord := _player.find_children("CordBead*", "MeshInstance3D", true, false)
	var at := _player.global_position + Vector3.UP * 0.62
	if not on_cord.is_empty():
		at = Vector3.ZERO
		for b: Node in on_cord:
			at += (b as Node3D).global_position
		at /= on_cord.size()
	var front := -_player.global_basis.z
	_level.camera.cinematic_to(at + front * 0.95 + _player.global_basis.x * 0.35 + Vector3.UP * 0.2, at, 0.01)
	await _wait(0.8)
	await _stage("cord_beads")
	await _wait(1.2)
	_level.camera.release()
	Game.pause_game()
	await _wait(0.8)
	await _stage("pause_beads")
	await _wait(1.2)
	Game.resume_game()
	Game.qa_log("beads_shown", {"beads": Game.bead_colors().size(), "on_cord": on_cord.size()})


## The route steps after the warp's route_from stage (level.json warps.<marker>.route_from).
func _route_after_warp(route: Array, warp: String) -> Array:
	var from := String((_level.data.get("warps", {}) as Dictionary).get(warp, {}).get("route_from", ""))
	for i in route.size():
		if from != "" and String((route[i] as Dictionary).get("stage", "")) == from:
			return route.slice(i + 1)
	_fail("warp %s has no route_from stage in the route" % warp)
	return []


func _finish() -> void:
	var glyphs_used := {}
	for c: Dictionary in casts:
		if c.get("hit", false):
			glyphs_used[c["glyph"]] = true
	if levels_played.has("hazewater"):
		for g: String in ["bloom", "slash", "gust"]:
			if not glyphs_used.has(g):
				_fail("glyph never landed: " + g)
	var summary := {
		"passed": failures.is_empty(),
		"failures": failures,
		"levels": levels_played,
		"stages": stages,
		"casts": casts,
		"simulated_casts": simulated,
		"duration": snappedf(_now() - _t0, 0.1),
		"snapshot": Game.debug_snapshot(),
	}
	Game.qa_log("autoplay_end", summary)
	print("QA_AUTOPLAY_%s" % ("PASSED" if failures.is_empty() else "FAILED"))
	if String(Boot.opt("autoplay_quit", "0")) == "1":
		get_tree().quit(0 if failures.is_empty() else 1)


func _load_chain() -> void:
	_chain.clear()
	for p: Variant in _level.data.get("autoplay", {}).get("chain", []):
		_chain.append(_level.ground_at(_point(p)))


## A route position: a marker or node name, or [x, y, z].
func _point(p: Variant) -> Vector3:
	if p is Array:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	var s := String(p)
	if _level.has_marker(s):
		return _level.marker(s)
	var n := _level.node(s) as Node3D
	if n != null:
		return n.global_position
	if _level.find_child(s, true, false) == null:
		_fail("route names unknown point '%s'" % s)
	return _level.marker(s)


func _target(name_: Variant) -> Node:
	var n := _level.node(String(name_))
	if n == null:
		_fail("route names unknown node '%s'" % name_)
	return n


# --- steps --------------------------------------------------------------------------------

func _play_route(route: Array) -> void:
	for step: Dictionary in route:
		if not failures.is_empty() and bool(_level.data.get("autoplay", {}).get("stop_on_failure", false)):
			return
		await _step(step)


func _step(s: Dictionary) -> void:
	if s.has("stage"):
		await _stage(String(s["stage"]))
	elif s.has("go"):
		var at := _point(s["go"])
		if s.has("before"):
			var from := _point(s["from"]) if s.has("from") else _player.global_position
			at = _before(at, from, float(s["before"]))
		await _go(at, bool(s.get("required", true)))
	elif s.has("cast"):
		await _cast_step(s)
	elif s.has("tie"):
		var posts: Array = s["tie"]
		var a := _target(posts[0]) as Node3D
		var b := _target(posts[1]) as Node3D
		if a != null and b != null:
			if s.has("before"):
				await _go(_before(a.global_position.lerp(b.global_position, 0.5), _player.global_position, float(s["before"])))
			if not await _cast_until(&"tie", a, func() -> bool: return bool(a.get(&"tied")) or (s.has("flag") and _level.get_flag(StringName(s["flag"]))), 3, [a, b]):
				_fail("tie between %s and %s never held" % [posts[0], posts[1]])
	elif s.has("talk"):
		await _talk(_target(s["talk"]))
	elif s.has("fight"):
		await _fight(_target(s["fight"]), bool(s.get("finish", false)), String(s.get("start_stage",
			"%s_ring" % s["fight"] if String(Boot.opt("fight_shots", "0")) == "1" else "")))
	elif s.has("bloom_zone"):
		await _bloom_zone(_target(s["bloom_zone"]) as CursedZone)
	elif s.has("wait_flag"):
		var f := StringName(s["wait_flag"])
		if not await _wait_until(func() -> bool: return _level.get_flag(f), float(s.get("timeout", 20.0))):
			_fail("flag %s never set" % f)
	elif s.has("expect_flag"):
		if not _level.get_flag(StringName(s["expect_flag"])):
			_fail("flag %s not set" % s["expect_flag"])
	elif s.has("wait"):
		await _wait(float(s["wait"]))
	elif s.has("probe_cursed"):
		var g := _target(s["probe_cursed"]) as CursedGround
		await _probe_cursed(g, _point(s["toward"]) if s.has("toward") else (g.global_position if g != null else Vector3.ZERO))
	elif s.has("probe_water"):
		var w := _target(s["probe_water"]) as DeepWater
		await _probe_water(w, _point(s["toward"]) if s.has("toward") else (w.global_position if w != null else Vector3.ZERO), float(s.get("hold", 0.0)))
	elif s.has("probe_rising"):
		var h := _target(s["probe_rising"]) as RisingHazard
		await _probe_rising(h, _point(s["toward"]) if s.has("toward") else (h.global_position if h != null else Vector3.ZERO))
	elif s.has("death_test"):
		await _death_test()
	elif s.has("look"):
		_level.camera.face_toward(_point(s["look"]), float(s.get("pitch", GameCamera.PITCH_DEFAULT)))
	elif s.has("look_away"):
		# Turn so the camera ends up behind the named thing (to see a fading prop at work).
		var from := _point(s["look_away"])
		var p := _player.global_position
		_level.camera.face_toward(p + Vector3(p.x - from.x, 0.0, p.z - from.z), float(s.get("pitch", GameCamera.PITCH_DEFAULT)))
	elif s.has("jump"):
		# A jump held for "hold" seconds (0.35 is a full jump), steering in the air toward "toward"
		# and stopping over it.
		var hold := float(s.get("hold", 0.35))
		var land := _point(s["toward"]) if s.has("toward") else _player.global_position
		if s.has("toward"):
			_level.camera.face_toward(land)
		_player.ai_jump = true
		_player.ai_jump_hold = hold
		var until := _now() + float(s.get("air_time", hold + 0.6))
		while _now() < until:
			await get_tree().physics_frame
			var dir := land - _player.global_position
			dir.y = 0.0
			_player.ai_move = dir.normalized() if s.has("toward") and dir.length() > 0.3 else Vector3.ZERO
		_player.ai_move = Vector3.ZERO
		await _wait(0.3)
	elif s.has("expect_prompt"):
		# A prompt from level data (or a kit node) shows within "timeout" seconds.
		var id := StringName(s["expect_prompt"])
		if not await _wait_until(func() -> bool: return Game.main.hud.prompt_id == id, float(s.get("timeout", 3.0))):
			_fail("prompt %s never shown" % id)
	elif s.has("expect_bark"):
		# A bark (a Person's or the level's narration) is on the panel within "timeout" seconds.
		if not await _wait_until(func() -> bool: return Game.main.talk.barking, float(s.get("timeout", 3.0))):
			_fail("no bark on the panel (%s)" % s["expect_bark"])
	elif s.has("expect_calm"):
		# An enemy that should be ignoring Orimi (outside its territory) is not hunting her.
		var en := _target(s["expect_calm"]) as EnemyBase
		if en == null or en.aggro:
			_fail("%s is %s" % [s["expect_calm"], "missing" if en == null else "hunting Orimi"])
	elif s.has("cast_blocked"):
		# One stroke over a target nobody can see (behind a wall): fail if it answers.
		var t := _target(s["target"]) as Node3D
		await _cast(StringName(s["cast_blocked"]), t)
		if s.has("flag") and _level.get_flag(StringName(s["flag"])):
			_fail("%s answered a glyph through a wall" % s["target"])
	elif s.has("expect_height"):
		# A node stands at height "y" (within 0.3 m): placed on the floor, not on a roof.
		var n := _target(s["expect_height"]) as Node3D
		if n == null or absf(n.global_position.y - float(s.get("y", 0.0))) > 0.3:
			_fail("%s at height %s, expected %.2f" % [s["expect_height"], str(n.global_position.y) if n != null else "?", float(s.get("y", 0.0))])
	elif s.has("expect_above"):
		if _player.global_position.y < float(s["expect_above"]):
			_fail("Orimi at height %.2f, expected above %.2f" % [_player.global_position.y, float(s["expect_above"])])
	else:
		_fail("unknown route step %s" % JSON.stringify(s))


func _cast_step(s: Dictionary) -> void:
	var glyph := StringName(s["cast"])
	var target := _target(s["target"]) as Node3D
	if target == null:
		return
	if s.has("before"):
		var from := _point(s["from"]) if s.has("from") else _player.global_position
		await _go(_before(target.global_position, from, float(s["before"])))
	var flag := StringName(s.get("flag", ""))
	var landed := [false]
	var done := func() -> bool:
		if flag != &"":
			return _level.get_flag(flag)
		if s.has("until") and String(s["until"]) == "cutscene":
			return Game.state == Game.STATE_CUTSCENE
		return landed[0] or not is_instance_valid(target) or bool(target.get(&"cleared")) or bool(target.get(&"lit"))
	if not await _cast_until(glyph, target, done, int(s.get("attempts", 4)), [], landed):
		_fail("%s on %s did not take" % [glyph, s["target"]])
	await _wait(float(s.get("after", 0.6)))


# --- movement -----------------------------------------------------------------------------

func _before(target: Vector3, from: Vector3, dist: float) -> Vector3:
	var d := from - target
	d.y = 0.0
	return target + (d.normalized() if d.length() > 0.01 else Vector3.BACK) * dist


## Nearest route node, counting height four times over: below a ledge, the node on the ledge
## above is not the way back.
func _nearest_chain(p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in _chain.size():
		var off := _chain[i] - p
		var d := Vector2(off.x, off.z).length() + absf(off.y) * 4.0
		if d < best_d:
			best_d = d
			best = i
	return best


## Walk to a point along the level's route chain (straight there when it has none).
func _go(point: Vector3, required: bool = true) -> bool:
	point = _level.ground_at(point)
	if _chain.size() >= 2:
		var i := _nearest_chain(_player.global_position)
		var j := _nearest_chain(point)
		var step := 1 if j >= i else -1
		# Intermediate nodes are best effort: if one cannot be reached (a fight pushed Orimi below a
		# ledge), the walker moves on to the next one rather than giving up.
		if i != j and _chain[i].distance_to(_player.global_position) > 2.5:
			await _walk_to(_chain[i], 1.5, 10.0, false)
		var k := i + step
		while (step > 0 and k < j) or (step < 0 and k > j):
			await _walk_to(_chain[k], 1.5, 14.0, false)
			k += step
		if j != i and j - step >= 0 and j - step < _chain.size():
			var prev := _chain[j - step]
			if point.distance_to(prev) > _chain[j].distance_to(prev):
				await _walk_to(_chain[j], 1.5, 14.0, false)
	return await _walk_to(point, 1.2, 45.0, required)


## Steer to a point on the ground. Returns false on timeout.
func _walk_to(point: Vector3, tolerance: float = 1.2, timeout: float = 45.0, required: bool = true) -> bool:
	var until := _now() + timeout
	var check_at := _now() + 1.5
	var check_pos := _player.global_position
	var sidestep := 0.0
	var side := 1.0
	while _now() < until:
		await get_tree().physics_frame
		if not is_instance_valid(_level) or _level.completed:
			# Walking into a level exit ends the level on the way.
			_player.ai_move = Vector3.ZERO
			return true
		if not Game.is_playing():
			_player.ai_move = Vector3.ZERO
			continue
		var to := point - _player.global_position
		to.y = 0.0
		if to.length() < tolerance:
			_player.ai_move = Vector3.ZERO
			return true
		var dir := to.normalized()
		if sidestep > 0.0:
			sidestep -= get_physics_process_delta_time()
			dir = (dir + dir.cross(Vector3.UP) * side * 1.5).normalized()
		_player.ai_move = dir * clampf(to.length() / 2.0, 0.35, 1.0)
		_level.camera.face_toward(_player.global_position + dir * 10.0, -16.0)
		if _now() > check_at:
			if _player.global_position.distance_to(check_pos) < 0.6:
				_player.ai_jump = true
				sidestep = 0.6
				side = -side
			check_at = _now() + 1.5
			check_pos = _player.global_position
	_player.ai_move = Vector3.ZERO
	if not required:
		Game.qa_log("autoplay_skip_waypoint", {"at": Game._v(point), "player": Game._v(_player.global_position)})
		return false
	_fail("could not reach %s" % [Game._v(point)])
	_player.teleport(_level.ground_at(point) + Vector3.UP * 0.1, _player.rotation.y)
	return false


# --- talking ------------------------------------------------------------------------------

func _talk(person: Node) -> void:
	if person == null:
		return
	var n := person as Node3D
	await _go(_before(n.global_position, _player.global_position, 1.6))
	var main: Node = Game.main
	if not person.has_method("talk"):
		_fail("%s cannot talk" % person.name)
		return
	person.call("talk")
	await _wait_until(func() -> bool: return main.talk.is_open, 3.0)
	if not await _wait_until(func() -> bool: return not main.talk.is_open, 60.0):
		_fail("talk with %s never ended" % person.name)
	await _wait(0.4)


# --- fighting -----------------------------------------------------------------------------

func _alive(group: Node) -> Array[EnemyBase]:
	var out: Array[EnemyBase] = []
	for e: Variant in group.get(&"enemies"):
		if is_instance_valid(e) and not (e as EnemyBase).is_defeated():
			out.append(e)
	return out


func _group_done(group: Node) -> bool:
	if group is CursedZone:
		return (group as CursedZone).is_cleared
	return bool(group.get(&"done"))


## start_stage: a stage (shot) 0.4 s after a sealed fight starts, with its ring rising.
func _fight(group: Node, finish: bool, start_stage: String = "") -> void:
	if group == null:
		return
	if group.has_method("knot_position") and not bool(group.get(&"started")):
		await _go(group.call("knot_position"))
		# The fight registers the touch on its own physics frame, and the knot drifts: give it time
		# after each arrival, and step onto the knot where it is now until it starts.
		for attempt in 5:
			if await _wait_until(func() -> bool: return bool(group.get(&"started")), 2.0):
				break
			await _walk_to(group.call("knot_position"), 0.6, 8.0, false)
		await _wait_until(func() -> bool: return bool(group.get(&"started")), 1.0)
		if not bool(group.get(&"started")):
			_fail("%s never started" % group.name)
		elif start_stage != "":
			_player.ai_move = Vector3.ZERO
			await _wait(0.4)
			await _stage(start_stage)
	var until := _now() + STAGE_TIMEOUT
	var swing_at := 0.0
	var finished_one := not finish
	while _now() < until:
		await get_tree().physics_frame
		if _group_done(group):
			_player.ai_move = Vector3.ZERO
			if not finished_one:
				_fail("no finishing stroke landed in %s" % group.name)
			return
		if not Game.is_playing():
			continue
		if not finished_one:
			for e: Variant in group.get(&"enemies"):
				if is_instance_valid(e) and (e as EnemyBase).unraveling and not (e as EnemyBase).dying:
					_player.ai_move = Vector3.ZERO
					if await _cast(&"slash", e, 0.15):
						finished_one = true
					break
		var alive := _alive(group)
		if alive.is_empty():
			_player.ai_move = Vector3.ZERO
			continue
		var target: EnemyBase = alive[0]
		var best := INF
		for e in alive:
			var d := e.global_position.distance_to(_player.global_position)
			if e is Reedwraith and (e as Reedwraith).veiled:
				d += 3.0
			if d < best:
				best = d
				target = e
		var to := target.global_position - _player.global_position
		var flat_dist := Vector2(to.x, to.z).length()
		# A veil or a flyer up in the air comes first, whatever the height: a Gust from where she
		# stands (walking toward one only on the same level, never off an edge after a flyer).
		if (target is Reedwraith and (target as Reedwraith).veiled) or _airborne(target):
			_level.camera.face_toward(target.global_position, -14.0)
			if flat_dist > 8.0:
				var same_level := absf(to.y) < 1.5 and not _airborne(target)
				_player.ai_move = Vector3(to.x, 0.0, to.z).normalized() if same_level else Vector3.ZERO
				continue
			_player.ai_move = Vector3.ZERO
			await _cast(&"gust", target)
			continue
		if absf(to.y) > 1.5:
			# On another level. Within brush reach (or held in by a ring), Slash it from here;
			# otherwise take the route round.
			if to.length() < 12.0 or _player_held(group):
				_player.ai_move = Vector3.ZERO
				Game.qa_log("autoplay_fight_reach", {"enemy": String(target.name), "dy": snappedf(to.y, 0.01)})
				await _cast(&"slash", target)
			else:
				await _go(target.global_position, false)
			continue
		to.y = 0.0
		var dist := to.length()
		if target is Reedwraith and not _slash_kill_done and dist < 10.0:
			_player.ai_move = Vector3.ZERO
			if await _cast(&"slash", target):
				_slash_kill_done = true
			continue
		_level.camera.face_toward(target.global_position, -18.0)
		if dist > 1.7:
			_player.ai_move = to.normalized()
		else:
			_player.ai_move = to.normalized() * 0.2
			if _now() > swing_at:
				_player.ai_attack = true
				swing_at = _now() + 0.24
	_fail("%s not cleared in time (%d left)" % [group.name, _alive(group).size()])
	for e in _alive(group):
		e.die()


## Orimi is kept inside this group's ring (a started SealedFight): walking round is no use.
func _player_held(group: Node) -> bool:
	return group is SealedFight and (group as SealedFight).started and not (group as SealedFight).done


## A flyer up in the air (keeps_to_ground() false and over half a metre up): a Gust downs it first.
func _airborne(e: EnemyBase) -> bool:
	if e.keeps_to_ground():
		return false
	# Its own ground probe reaches 3 m down; a flyer may be higher, so look further.
	var q := PhysicsRayQueryParameters3D.create(e.global_position + Vector3.UP * 0.2, e.global_position + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := e.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or e.global_position.y - (hit.position as Vector3).y > 0.5


func _bloom_zone(zone: CursedZone) -> void:
	if zone == null:
		return
	await _go(_before(zone.target.global_position, _level.spawn_point(), 4.5))
	if not await _cast_until(&"bloom", zone.target, func() -> bool: return zone.is_restored):
		_fail("zone %s did not restore" % zone.zone_id)
		zone.restore()
	if not await _wait_until(func() -> bool: return Game.restored_zones.has(zone.zone_id), 15.0):
		_fail("zone_restored never arrived for %s" % zone.zone_id)


## Step off the safe ground into the curse on purpose: it must hurt and throw Orimi back out.
func _probe_cursed(ground: CursedGround, toward: Vector3) -> void:
	if ground == null:
		return
	var before := ground.hurts
	var into := toward - _player.global_position
	into.y = 0.0
	var until := _now() + 2.5
	while _now() < until and ground.hurts == before:
		await get_tree().physics_frame
		if Game.is_playing():
			_player.ai_move = into.normalized()
	_player.ai_move = Vector3.ZERO
	# Pushed back, or put back on safe ground after CursedGround.STUCK_TIME in a deep hollow.
	await _wait(0.3)
	await _wait_until(func() -> bool: return ground.is_safe(_player.global_position), CursedGround.STUCK_TIME + 1.5)
	var hurt := ground.hurts > before
	var safe := ground.is_safe(_player.global_position)
	var kept: Vector3 = ground.get(&"_last_safe")
	Game.qa_log("cursed_probe", {"ground": String(ground.name), "hurt": hurt, "back_on_safe_ground": safe,
		"kept": Game._v(kept) if kept != Vector3.INF else [], "kept_inside_margin": kept != Vector3.INF and ground.is_safe(kept, CursedGround.SAFE_MARGIN)})
	if not hurt:
		_fail("cursed ground %s did not hurt" % ground.name)
	if not safe:
		_fail("cursed ground %s did not push Orimi back" % ground.name)
	await _wait(0.8)
	_player.heal_full()


## Walk into deep water; fail unless she is put back on the bank she left, unhurt.
## hold: keep pushing into the water this long after the first return; fail if she loops (put
## back more than once each 0.6 s).
func _probe_water(water: DeepWater, toward: Vector3, hold: float = 0.0) -> void:
	if water == null:
		_fail("no deep water to probe")
		return
	var before := water.returns
	var hp := _player.hp
	var start := _player.global_position
	var into := toward - start
	into.y = 0.0
	var until := _now() + 4.0
	var last := start
	while _now() < until and water.returns == before:
		last = _player.global_position
		await get_tree().physics_frame
		if Game.is_playing():
			_player.ai_move = into.normalized()
	var held_until := _now() + hold
	var seen := water.returns
	while _now() < held_until:
		var here := _player.global_position
		await get_tree().physics_frame
		if water.returns != seen:
			seen = water.returns
			last = here
		if Game.is_playing():
			_player.ai_move = into.normalized()
	_player.ai_move = Vector3.ZERO
	await _wait(1.0)
	var back := water.returns > before
	if hold > 0.0 and water.returns - before > 1 + ceili(hold / 0.6):
		_fail("deep water %s looped: %d returns in %.1f s held" % [water.name, water.returns - before, hold])
	var on_bank := not water.contains(_player.global_position, 0.3)
	# From where she last went in (the start, if she never did).
	var dist := Vector2(_player.global_position.x - last.x, _player.global_position.z - last.z).length()
	Game.qa_log("water_probe", {"water": String(water.name), "returned": back, "on_bank": on_bank,
		"from_start": snappedf(dist, 0.01), "hp_lost": hp - _player.hp, "returns": water.returns - before})
	if not back:
		_fail("deep water %s did not put Orimi back" % water.name)
	elif not on_bank or dist > 3.0:
		_fail("deep water %s put Orimi %.1f m from where she went in" % [water.name, dist])
	if _player.hp < hp:
		_fail("deep water %s hurt Orimi" % water.name)


## Walk into a risen hazard; fail unless she is lifted out above its surface (or out of its box).
func _probe_rising(hazard: RisingHazard, toward: Vector3) -> void:
	if hazard == null:
		_fail("no rising hazard to probe")
		return
	var before := hazard.lifts
	var hp := _player.hp
	var into := toward - _player.global_position
	into.y = 0.0
	var until := _now() + 4.0
	while _now() < until and hazard.lifts == before:
		await get_tree().physics_frame
		if Game.is_playing():
			_player.ai_move = into.normalized()
	_player.ai_move = Vector3.ZERO
	await _wait(1.0)
	var pos := _player.global_position
	var out := not hazard.inside(pos) or pos.y > hazard.surface_y()
	Game.qa_log("rising_probe", {"hazard": String(hazard.name), "lifted": hazard.lifts > before, "out": out,
		"at": Game._v(pos), "surface": snappedf(hazard.surface_y(), 0.01), "hp_lost": hp - _player.hp})
	if hazard.lifts == before:
		_fail("rising hazard %s did not lift Orimi out" % hazard.name)
	elif not out:
		_fail("rising hazard %s left Orimi under its surface" % hazard.name)
	_player.heal_full()


func _death_test() -> void:
	var expected := Game.checkpoint
	_player.set_meta(&"allow_death", true)
	_player.take_damage(OrimiPlayer.MAX_HP, _player.global_position + Vector3.FORWARD)
	_player.set_meta(&"allow_death", false)
	if not _player.dead:
		_fail("player did not die on lethal damage")
		return
	await _stage("death")
	var respawned := await _wait_until(func() -> bool: return not _player.dead, 6.0)
	var dist := _player.global_position.distance_to(expected)
	if not respawned or dist > 2.0 or _player.hp != _player.max_hp:
		_fail("respawn wrong (respawned %s, %.1f m from checkpoint, hp %d)" % [respawned, dist, _player.hp])
	await _wait(1.0)
	await _stage("respawned", {"distance_from_checkpoint": snappedf(dist, 0.01)})


# --- glyphs -------------------------------------------------------------------------------

func _cast_until(glyph: StringName, target: Node3D, done: Callable, attempts: int = 4, tie_posts: Array = [], landed: Array = []) -> bool:
	for i in attempts:
		if done.call():
			return true
		var hit := await _cast(glyph, target, 0.9, tie_posts)
		if landed.size() > 0 and hit:
			landed[0] = true
		# A glyph that landed may start something long (a verse-stone's lines): give it time.
		if await _wait_until(done, 12.0 if hit else 3.5):
			return true
	return done.call()


## Draw the glyph's stroke over target in screen space and send it through the brush. A glyph
## the brush does not know yet (kindle, tie) is handed to the target directly, the way the
## brush will, and logged as simulated.
func _cast(glyph: StringName, target: Node3D, settle: float = 0.9, tie_posts: Array = []) -> bool:
	if not is_instance_valid(target):
		return false
	var anchor: Vector3 = target.call("glyph_anchor") if target.has_method("glyph_anchor") else target.global_position + Vector3.UP * 0.8
	var radius: float = target.call("glyph_radius") if target.has_method("glyph_radius") else 1.0
	_player.ai_move = Vector3.ZERO
	_level.camera.face_toward(anchor, -14.0)
	if not glyph in Brush.known_glyphs():
		return await _simulate(glyph, target, tie_posts)
	await _wait(settle)
	# A player draws once the target is in view: give a camera swinging round a corner time to see it.
	var seen_by := _now() + 2.0
	while is_instance_valid(target) and not GlyphReach.clear(target, false) and _now() < seen_by:
		await _wait(0.2)
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
		# Too close or off screen: step back from the target and look again.
		var away := _player.global_position - target.global_position
		away.y = 0.0
		_player.ai_move = away.normalized() if away.length() > 0.1 else Vector3.BACK
		await _wait(0.5)
		_player.ai_move = Vector3.ZERO
		_level.camera.face_toward(anchor, -14.0)
		await _wait(0.7)
	var pts := _stroke_points(glyph, center, r_px)
	if glyph == &"kindle":
		pts = PackedVector2Array([center])
	if glyph == &"tie" and tie_posts.size() == 2 and is_instance_valid(tie_posts[1]):
		# A Tie is a straight line from one post's ring to the other's.
		var b: Vector3 = (tie_posts[1] as Node3D).call("glyph_anchor")
		var end := cam.unproject_position(b)
		pts = PackedVector2Array()
		for k in 24:
			pts.append(center.lerp(end, k / 23.0))
	var record := {"glyph": String(glyph), "target": String(target.name), "screen": [snappedf(center.x, 1), snappedf(center.y, 1)], "r_px": snappedf(r_px, 1)}
	# inject_stroke spends ink exactly like a drawn stroke; refill so the run never stalls on it.
	Brush.refill()
	var info := Brush.inject_stroke(pts)
	if info.is_empty() and Brush.get(&"last_result") is Dictionary:
		record["reason"] = String((Brush.get(&"last_result") as Dictionary).get("reason", ""))
	var targets: Array = info.get("targets", [])
	record["recognised"] = String(info.get("glyph", ""))
	record["hit"] = info.get("glyph", &"") == glyph and target in targets
	record["targets"] = targets.size()
	casts.append(record)
	Game.qa_log("autoplay_cast", record)
	if not record["hit"]:
		await _stage("missed_%s" % target.name)
	return record["hit"]


func _simulate(glyph: StringName, target: Node3D, tie_posts: Array) -> bool:
	await _wait(0.4)
	if not is_instance_valid(target):
		return false
	var info := {"injected": true, "simulated": true, "world_center": target.global_position, "targets": tie_posts if not tie_posts.is_empty() else [target]}
	var hit := false
	var told: Array = tie_posts if not tie_posts.is_empty() else [target]
	for t: Variant in told:
		if is_instance_valid(t) and (t as Node).has_method("on_glyph") and bool((t as Node).call("on_glyph", glyph, info)):
			hit = true
	if hit:
		Events.glyph_cast.emit(glyph, info)
	var record := {"glyph": String(glyph), "target": String(target.name), "simulated": true, "hit": hit}
	simulated.append(record)
	casts.append(record)
	Game.qa_log("autoplay_cast", record)
	return hit


## The stroke for a glyph in viewport pixels, sized around a target's projected radius.
func _stroke_points(glyph: StringName, center: Vector2, r_px: float) -> PackedVector2Array:
	var unit := GlyphIcon.stroke(glyph)
	var span: float
	match glyph:
		&"bloom":
			span = clampf(r_px * 3.2, 150.0, 420.0)
		&"slash":
			span = clampf(r_px * 3.0, 220.0, 520.0)
		_:
			span = clampf(r_px * 3.0, 220.0, 420.0)
	var vp := get_viewport().get_visible_rect().size
	var out := PackedVector2Array()
	for p in unit:
		var q := center + (p - Vector2(0.5, 0.5)) * span
		out.append(Vector2(clampf(q.x, 4.0, vp.x - 4.0), clampf(q.y, 4.0, vp.y - 4.0)))
	return out
