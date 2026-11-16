extends Node
## Autoload "Game": game state and flow. Owner: gameplay.
## The main scene (scenes/game/main.tscn, scripts/game/main.gd) runs the screens and loads
## levels; this autoload holds the state, the current level and player, saved progress (levels
## completed, beads), pause, and the QA hooks.

## An enemy was finished with a clean cut (the finishing stroke).
signal enemy_finished(enemy: Node3D)
## A level finished building and is about to be played (or shown behind the title).
signal level_loaded(level: Level)

const STATE_TITLE := &"title"
const STATE_PLAYING := &"playing"
const STATE_CUTSCENE := &"cutscene"
const STATE_PAUSED := &"paused"
const STATE_ENDED := &"ended"
## Talking to someone: Orimi stands still and the brush is put away.
const STATE_TALK := &"talk"

const MAIN_SCENE := "res://scenes/game/main.tscn"
const SAVE_PATH := "user://progress.json"
## The browser's copy of the save, in localStorage (read first, written first).
const WEB_SAVE_KEY := "orimi_progress"
## Maximum ink grows by this much for each bead on Orimi's cord.
const INK_PER_BEAD := 20.0
const BASE_INK := 100.0

var state: StringName = STATE_TITLE
## The player body (a CharacterBody3D in group "player"), or null outside play.
var player: CharacterBody3D = null

## The main scene while it is loaded (scripts/game/main.gd).
var main: Node = null
## The level being played or shown behind the title (a Level), or null.
var level: Level = null
## The same node as level, kept for older callers.
var valley: Node3D = null
## Saved between sessions (user://progress.json, IndexedDB and localStorage in the browser):
## {"completed": [level ids], "current": level id to continue from, "taught": [control prompt ids
## already shown], "stats": {level id: {"time", "kills", "deaths"} of its latest completion}}.
var progress: Dictionary = {"completed": [], "current": "", "taught": [], "stats": {}}
## level=<id>: start straight in that level (and autoplay only that level).
var start_level: StringName = &""
## Zone ids restored so far this run, in order.
var restored_zones: Array[StringName] = []
## Where the player respawns: the shrine, then the sapling of the last restored zone.
var checkpoint: Vector3 = Vector3.ZERO
## god=1: the player takes no damage.
var god_mode: bool = false
## autoplay=1: a scripted run of the whole slice (scripts/game/autoplay.gd).
var autoplay: bool = false
var deaths: int = 0
var kills: int = 0
var run_started_msec: int = 0

var _options_read := false
## Time of the last real key press, click or touch (the browser grants pointer lock only then).
var _gesture_msec := -100000
var _state_before_pause: StringName = STATE_PLAYING


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# window_input arrives before the event reaches any node, so a handler that captures the
	# mouse in response to a click already sees the gesture recorded.
	get_tree().root.window_input.connect(_on_window_input)
	if OS.has_feature("web"):
		# A lock request the browser still refuses (focus lost, a lock released a moment ago)
		# rejects a promise; keep that out of the console as an error.
		JavaScriptBridge.eval("window.addEventListener('unhandledrejection', function (e) { var r = e.reason; if (r && r.name === 'NotAllowedError' && String(r.message).indexOf('Pointer Lock') >= 0) { e.preventDefault(); console.warn('pointer lock refused: ' + r.message); } });", true)
	Events.zone_restored.connect(_on_zone_restored)
	Events.enemy_died.connect(_on_enemy_died)
	Events.glyph_cast.connect(_on_glyph_cast)
	Events.glyph_failed.connect(_on_glyph_failed)
	Events.finale_started.connect(func(center: Vector3) -> void: qa_log("finale_started", {"center": _v(center)}))
	Events.valley_restored.connect(func() -> void: qa_log("valley_restored", debug_snapshot()))
	Events.player_died.connect(_on_player_died)
	Events.player_respawned.connect(func(at: Vector3) -> void: qa_log("player_respawned", {"at": _v(at)}))
	Events.zone_restore_started.connect(func(zone_id: StringName, center: Vector3, radius: float) -> void:
		qa_log("zone_restore_started", {"zone": String(zone_id), "center": _v(center), "radius": radius}))
	Events.thorns_cut.connect(func(_t: Node3D, at: Vector3) -> void: qa_log("thorns_cut", {"at": _v(at)}))
	Events.soot_cleared.connect(func(_t: Node3D, at: Vector3) -> void: qa_log("soot_cleared", {"at": _v(at)}))
	Events.enemy_unveiled.connect(func(e: Node3D) -> void: qa_log("enemy_unveiled", {"at": _v(e.global_position)}))


## Boot options are parsed by the boot scene, which runs after the autoloads, so they are
## read here when the main scene starts.
func read_options() -> void:
	if _options_read:
		return
	_options_read = true
	god_mode = String(Boot.opt("god", "0")) == "1"
	autoplay = String(Boot.opt("autoplay", "0")) == "1"
	start_level = StringName(String(Boot.opt("level", "")))
	if String(Boot.opt("fresh", "0")) == "1" or autoplay:
		reset_progress(false)
	else:
		load_progress()
	# completed=<id>,<id>: a save that has finished those levels, for checking the title and the beads.
	var done := String(Boot.opt("completed", ""))
	if done != "":
		progress["completed"] = Array(done.split(",", false))
		progress["current"] = String(LevelRegistry.next_after(StringName(progress["completed"].back())))
		if progress["current"] == "":
			progress["current"] = progress["completed"].back()
		save_progress()
		apply_beads()


func _process(_delta: float) -> void:
	if is_instance_valid(player):
		RenderingServer.global_shader_parameter_set(&"player_world_pos", player.global_position)
	elif player != null:
		player = null


func set_state(new_state: StringName) -> void:
	if new_state == state:
		return
	state = new_state
	Brush.enabled = state == STATE_PLAYING
	qa_log("state", {"state": String(state)})
	Events.game_state_changed.emit(state)


func is_playing() -> bool:
	return state == STATE_PLAYING


func start_new_game() -> void:
	if is_instance_valid(main) and main.has_method("start_game"):
		main.start_game()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_SCENE)


func return_to_title() -> void:
	get_tree().paused = false
	if is_instance_valid(main) and main.has_method("go_to_title"):
		main.go_to_title()
	else:
		get_tree().change_scene_to_file(MAIN_SCENE)


## Called by the main scene when a level starts (stats count per level).
func reset_run() -> void:
	restored_zones.clear()
	deaths = 0
	kills = 0
	checkpoint = Vector3.ZERO
	run_started_msec = Time.get_ticks_msec()


# --- levels -------------------------------------------------------------------------------

func attach_level(l: Level) -> void:
	level = l
	valley = l


func detach_level(l: Level) -> void:
	if level == l:
		level = null
		valley = null
	if player != null and is_instance_valid(player) and l.is_ancestor_of(player):
		player = null


## Set a named flag on the current level (kit nodes and level scripts use these as hooks).
func set_flag(flag: StringName, value: bool = true) -> void:
	if level != null:
		level.set_flag(flag, value)


func get_flag(flag: StringName) -> bool:
	return level != null and level.get_flag(flag)


## Show one of the main scene's tutorial hints (see main.gd PROMPTS), rate-limited.
func hint(id: StringName) -> void:
	if is_instance_valid(main) and main.has_method("hint"):
		main.hint(id)


# --- progress -----------------------------------------------------------------------------

func load_progress() -> void:
	var text := ""
	var from := "localStorage"
	if OS.has_feature("web"):
		var stored: Variant = JavaScriptBridge.eval("localStorage.getItem(%s)" % JSON.stringify(WEB_SAVE_KEY), true)
		if stored is String:
			text = stored
	if text == "" and FileAccess.file_exists(SAVE_PATH):
		text = FileAccess.get_file_as_string(SAVE_PATH)
		from = "file"
	if text == "":
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		progress["completed"] = (parsed as Dictionary).get("completed", [])
		progress["current"] = String((parsed as Dictionary).get("current", ""))
		progress["taught"] = (parsed as Dictionary).get("taught", [])
		progress["stats"] = (parsed as Dictionary).get("stats", {})
	var info := progress.duplicate()
	info["from"] = from
	qa_log("progress_loaded", info)


func save_progress() -> void:
	var text := JSON.stringify(progress)
	# In the browser user:// reaches IndexedDB seconds after the file closes (F-016); localStorage
	# is written before this returns, so a tab closed straight after a bead keeps it.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem(%s, %s)" % [JSON.stringify(WEB_SAVE_KEY), JSON.stringify(text)], true)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Game: could not save progress (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(text)
	f.close()
	qa_log("progress_saved", progress)


func reset_progress(save: bool = true) -> void:
	progress = {"completed": [], "current": "", "taught": [], "stats": {}}
	if save:
		save_progress()
	apply_beads()


func is_level_completed(id: StringName) -> bool:
	return String(id) in progress["completed"]


## Record a finished level and the level to continue from; saves at once.
func mark_level_complete(id: StringName, next_id: StringName) -> void:
	if not String(id) in progress["completed"]:
		(progress["completed"] as Array).append(String(id))
	progress["current"] = String(next_id)
	(progress["stats"] as Dictionary)[String(id)] = {"time": int((Time.get_ticks_msec() - run_started_msec) / 1000), "kills": kills, "deaths": deaths}
	save_progress()
	apply_beads()


## True when every level of the book is finished on this save.
func book_complete() -> bool:
	for entry: Dictionary in LevelRegistry.levels():
		if not is_level_completed(StringName(entry["id"])):
			return false
	return true


## True once the control prompt id has been shown on this save.
func taught(id: StringName) -> bool:
	return String(id) in progress["taught"]


## Record that the control prompt id has been shown, so no later level shows it again.
func teach(id: StringName) -> void:
	if taught(id):
		return
	(progress["taught"] as Array).append(String(id))
	save_progress()


## Time, kills and deaths summed over the book's levels, or {} until every one has been finished.
func book_totals() -> Dictionary:
	var out := {"time": 0, "kills": 0, "deaths": 0, "levels": 0}
	for entry: Dictionary in LevelRegistry.levels():
		var s: Variant = (progress["stats"] as Dictionary).get(String(entry["id"]))
		if not s is Dictionary:
			return {}
		for k: String in ["time", "kills", "deaths"]:
			out[k] += int((s as Dictionary).get(k, 0))
		out["levels"] += 1
	return out


## One colour per completed level that has a bead, in registry order.
func bead_colors() -> Array[Color]:
	var out: Array[Color] = []
	for entry: Dictionary in LevelRegistry.levels():
		if is_level_completed(StringName(entry["id"])) and entry.has("bead_color"):
			out.append(Color(String(entry["bead_color"])))
	return out


## Maximum ink follows the beads on the cord.
func apply_beads() -> void:
	var beads := bead_colors()
	Brush.ink_max = BASE_INK + INK_PER_BEAD * beads.size()
	Brush.ink = minf(Brush.ink, Brush.ink_max)
	Events.ink_changed.emit(Brush.ink, Brush.ink_max)
	if is_instance_valid(player) and player.has_method("set_beads"):
		player.set_beads(beads)


func pause_game() -> void:
	if state != STATE_PLAYING or Brush.is_open():
		return
	_state_before_pause = state
	get_tree().paused = true
	set_state(STATE_PAUSED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(main) and main.has_method("show_pause"):
		main.show_pause(true)


func resume_game() -> void:
	if state != STATE_PAUSED:
		return
	if is_instance_valid(main) and main.has_method("show_pause"):
		main.show_pause(false)
	get_tree().paused = false
	set_state(_state_before_pause)
	capture_mouse()


## Capture the mouse for camera control. On the web this only succeeds inside a user gesture,
## so it is called from click and key handlers.
func capture_mouse() -> void:
	if autoplay or DisplayServer.get_name() == "headless":
		return
	if OS.has_feature("web") and Time.get_ticks_msec() - _gesture_msec > 1000:
		# No user gesture just now: the browser would refuse the lock. The next click captures.
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_window_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.is_pressed() and not event.is_echo():
		_gesture_msec = Time.get_ticks_msec()


func is_zone_restored(zone_id: StringName) -> bool:
	return zone_id in restored_zones


## A plain-data picture of the game for QA: at least state, player position, hp,
## ink, restored zone ids, living enemy count.
func debug_snapshot() -> Dictionary:
	var zones: Array = []
	for z in restored_zones:
		zones.append(String(z))
	var snap := {
		"state": String(state),
		"player_pos": [],
		"hp": 0,
		"max_hp": 0,
		"ink": snappedf(Brush.ink, 0.1),
		"ink_max": Brush.ink_max,
		"restored_zones": zones,
		"level": String(level.level_id) if level != null else "",
		"beads": bead_colors().size(),
		"enemies_alive": get_tree().get_nodes_in_group(&"enemy").size(),
		"checkpoint": _v(checkpoint),
		"deaths": deaths,
		"kills": kills,
		"god": god_mode,
		"autoplay": autoplay,
		"fps": Engine.get_frames_per_second(),
		"t": snappedf(Time.get_ticks_msec() / 1000.0, 0.01),
	}
	if level != null and is_instance_valid(level.camera) and is_instance_valid(player):
		var zone: Variant = level.camera.get(&"_zone")
		snap["camera"] = {"zone": String((zone as Node).name) if zone is Node else "", "to_player": snappedf(level.camera.camera.global_position.distance_to(player.global_position), 0.01)}
	if is_instance_valid(player):
		snap["player_pos"] = _v(player.global_position)
		snap["hp"] = player.get(&"hp")
		snap["max_hp"] = player.get(&"max_hp")
		if level != null:
			snap["zone"] = String(level.zone_of(player.global_position))
	return snap


## Print one machine-readable line the QA harness can pick out of the console.
func qa_log(tag: String, data: Dictionary = {}) -> void:
	print("QA:", JSON.stringify({"tag": tag, "data": data}))


func _on_player_died() -> void:
	deaths += 1
	qa_log("player_died", {"deaths": deaths, "at": _v(player.global_position) if is_instance_valid(player) else []})


func _on_zone_restored(zone_id: StringName) -> void:
	if not zone_id in restored_zones:
		restored_zones.append(zone_id)
	qa_log("zone_restored", {"zone": String(zone_id), "restored": debug_snapshot()["restored_zones"]})


func _on_enemy_died(_enemy: Node3D, kind: StringName, at: Vector3) -> void:
	kills += 1
	# The dying enemy has already left the group, so this count excludes it.
	qa_log("enemy_died", {"kind": String(kind), "at": _v(at), "alive": get_tree().get_nodes_in_group(&"enemy").size()})


func _on_glyph_cast(glyph: StringName, info: Dictionary) -> void:
	var names: Array = []
	for t: Variant in info.get("targets", []):
		if is_instance_valid(t):
			names.append(String((t as Node).name))
	qa_log("glyph_cast", {"glyph": String(glyph), "score": snappedf(float(info.get("score", 0.0)), 0.01), "targets": names, "ink": snappedf(Brush.ink, 0.1)})


func _on_glyph_failed(info: Dictionary) -> void:
	qa_log("glyph_failed", {"reason": String(info.get("reason", ""))})


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]
