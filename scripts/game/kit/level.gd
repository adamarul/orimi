class_name Level
extends Node3D
## The base of every level. A level is a scene under scenes/levels/<id>/ whose root has this
## script (or a script that extends it). It finds its markers, loads its data file, spawns
## Orimi at the spawn marker, keeps the level's named flags and objectives, and tells Game
## when the level is complete. Everything else in the level is ordinary nodes from the kit
## (docs/LEVEL_KIT.md). Owner: gameplay.

## A flag was set or cleared (Level.set_flag). Kit nodes and level scripts listen to this.
signal flag_changed(flag: StringName, value: bool)
## An objective from the data file was met; index is its position in the list.
signal objective_completed(index: int, text: String)
## The level is complete (all objectives met, or complete() called). Rewards follow.
signal level_completed
## Built: the ground has its collision, markers are read and Orimi is spawned. Kit nodes that set
## themselves down on the ground wait for this (await Game.level.ready_to_settle()).
signal level_built

const SKY_SCENE := "res://scenes/env/sky.tscn"
const DATA_NAME := "level.json"

## The id in the level registry (scenes/levels/levels.json), for example &"tallowford".
@export var level_id: StringName = &""
## Shown on the intro card, the title's level list and the completion banner.
@export var display_name: String = ""
@export var chapter: String = ""
@export_multiline var intro_text: String = ""
## Marker Orimi starts at (any Node3D in the level with this name).
@export var spawn_marker: String = "M_Spawn"
## Lines, safe ground, objectives and the autoplay route. Empty: level.json beside the scene.
@export_file("*.json") var data_file: String = ""
## Add the shared sky (scenes/env/sky.tscn) and a sun when the level has no WorldEnvironment.
@export var shared_environment: bool = true
## Valley-wide grey at the start: 1 drained, 0 full colour.
@export_range(0.0, 1.0) var start_gloom: float = 1.0
## Give every MeshInstance3D under nodes in group "level_ground" trimesh collision when it has none.
@export var auto_collision: bool = true
## The title screen camera orbits this marker when this level is the one behind the title.
@export var title_marker: String = ""
## ground_at looks down from 40 m up. Ground it finds more than this far above the asked point is
## taken to be overhead (a roof, a ledge over a ledge), and it looks again from the point itself,
## so markers, spawns, checkpoints and put-back points land on the floor under them. Indoors set
## it to about 1 (callers ask from up to 2 m above the floor). The default 40 leaves outdoor
## levels as they were.
@export var ground_overhead: float = 40.0

## Everything in the data file, parsed (see docs/LEVEL_KIT.md "The data file").
var data: Dictionary = {}
## Marker name -> world position, for every Node3D named M_* in the level.
var markers: Dictionary = {}
var flags: Dictionary = {}
var player: OrimiPlayer
var camera: GameCamera
var built := false
var completed := false
var _objectives_done: Dictionary = {}
## level.json "hints" entries that wait for Orimi near a point; id -> she is inside now.
var _near_hints: Array[Dictionary] = []
var _hint_inside: Dictionary = {}
var applying_warp := false


func _ready() -> void:
	add_to_group(&"level")
	Game.attach_level(self)


func _exit_tree() -> void:
	Game.detach_level(self)


# --- building -----------------------------------------------------------------------------

## Called by the main scene. Builds in steps a frame or two apart so the loading card keeps
## moving; progress is called with (fraction, label).
func build_async(progress: Callable) -> void:
	CurseSlots.reset()
	CurseField.set_valley_gloom(start_gloom, 0.0)
	_load_data()
	progress.call(0.1, "Laying down the paper")
	if shared_environment:
		_add_environment()
	await _frames(2)
	progress.call(0.25, "Washing in the ground")
	await _build(progress)
	if auto_collision:
		_add_ground_collision()
	_read_markers()
	await _frames(2)
	progress.call(0.75, "Folding Orimi")
	_spawn_player()
	await _frames(2)
	progress.call(0.88, "Warming the brush")
	if Vfx.has_method("warm_up"):
		Vfx.call("warm_up")
	await _frames(3)
	progress.call(1.0, "Ready")
	built = true
	level_built.emit()
	CurseSlots.refresh()
	_start_cues()
	Game.qa_log("level_built", {"level": String(level_id), "enemies": get_tree().get_nodes_in_group(Layers.GROUP_ENEMY).size(), "markers": markers.size()})


## Await before setting something down with ground_at from a kit node's _ready: returns once the
## level is built (at once if it already is).
func ready_to_settle() -> void:
	if not built:
		await level_built


## Override to build a level in code (Level 1 does). Called after the environment exists and
## before markers are read and Orimi is spawned. May await.
func _build(_progress: Callable) -> void:
	pass


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _load_data() -> void:
	var path := data_file
	if path == "" and scene_file_path != "":
		path = scene_file_path.get_base_dir().path_join(DATA_NAME)
	data = {}
	if path == "" or not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("Level %s: %s is not a JSON object" % [level_id, path])


func _add_environment() -> void:
	if not find_children("*", "WorldEnvironment", true, false).is_empty():
		return
	var has_env := false
	if ResourceLoader.exists(SKY_SCENE):
		var sky := (load(SKY_SCENE) as PackedScene).instantiate()
		sky.name = "SharedSky"
		add_child(sky)
		has_env = sky is WorldEnvironment or not sky.find_children("*", "WorldEnvironment", true, false).is_empty()
	if not has_env:
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
		we.environment = env
		add_child(we)
	if find_children("*", "DirectionalLight3D", true, false).is_empty():
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		sun.light_color = Color("fff4e0")
		sun.light_energy = 0.85
		sun.rotation_degrees = Vector3(-52, -35, 0)
		add_child(sun)


func _add_ground_collision() -> void:
	for holder: Node in get_tree().get_nodes_in_group(&"level_ground"):
		if not is_ancestor_of(holder) and holder != self:
			continue
		if not holder.find_children("*", "CollisionObject3D", true, false).is_empty():
			continue
		for mi: Node in holder.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).create_trimesh_collision()
			for body: Node in mi.find_children("*", "StaticBody3D", false, false):
				(body as StaticBody3D).collision_layer = Layers.WORLD


func _read_markers() -> void:
	for n: Node in find_children("M_*", "Node3D", true, false):
		if not markers.has(String(n.name)):
			markers[String(n.name)] = (n as Node3D).global_position


func _spawn_player() -> void:
	player = OrimiPlayer.new()
	player.name = "Orimi"
	add_child(player)
	var at := spawn_point()
	var face := marker(String(data.get("spawn_facing", ""))) if data.has("spawn_facing") else at + _marker_forward(spawn_marker)
	var d := face - at
	player.teleport(at + Vector3.UP * 0.05, atan2(-d.x, -d.z) if Vector2(d.x, d.z).length() > 0.01 else 0.0)
	camera = GameCamera.new()
	camera.name = "GameCamera"
	add_child(camera)
	camera.target = player.visual
	player.camera = camera
	camera.snap_behind(player)
	Game.player = player
	Game.checkpoint = player.global_position
	player.set_beads(Game.bead_colors())


func _marker_forward(marker_name: String) -> Vector3:
	var n := find_child(marker_name, true, false) as Node3D
	return -n.global_basis.z if n != null else Vector3.FORWARD


# --- queries ------------------------------------------------------------------------------

func has_marker(marker_name: String) -> bool:
	return markers.has(marker_name)


## The position of a marker; Vector3.ZERO (with a warning) when the level has none by that name.
func marker(marker_name: String) -> Vector3:
	if not markers.has(marker_name):
		var n := find_child(marker_name, true, false) as Node3D
		if n == null:
			push_warning("Level %s: no marker %s" % [level_id, marker_name])
			return Vector3.ZERO
		markers[marker_name] = n.global_position
	return markers[marker_name]


func spawn_point() -> Vector3:
	return ground_at(marker(spawn_marker))


## The ground point under p on the world layer, ignoring brush targets (gates, posts, saplings)
## and any collision under ignore (a model being set down on the ground).
func ground_at(p: Vector3, ignore: Node = null) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 40.0, p.z), Vector3(p.x, p.y - 60.0, p.z), Layers.WORLD)
	var exclude: Array[RID] = []
	for n: Node in get_tree().get_nodes_in_group(Layers.GROUP_BRUSH_TARGET):
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())
	if ignore != null:
		for n: Node in ignore.find_children("*", "CollisionObject3D", true, false):
			exclude.append((n as CollisionObject3D).get_rid())
		if ignore is CollisionObject3D:
			exclude.append((ignore as CollisionObject3D).get_rid())
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and (hit.position as Vector3).y > p.y + ground_overhead:
		q.from = Vector3(p.x, p.y + 0.05, p.z)
		var under := space.intersect_ray(q)
		if not under.is_empty():
			hit = under
	return hit.position if not hit.is_empty() else p


## The cursed zone id the point is in, or &"".
func zone_of(p: Vector3) -> StringName:
	for z: Node in get_tree().get_nodes_in_group(Layers.GROUP_CURSED_ZONE):
		var zone := z as CursedZone
		if zone != null and Vector2(p.x - zone.global_position.x, p.z - zone.global_position.z).length() < zone.radius:
			return zone.zone_id
	return &""


## A kit node in this level by name (anywhere below the root), or by a path from the root such
## as "Bridge/PostA" when the name alone is not unique. Null when there is none.
func node(node_name: String) -> Node:
	if node_name.contains("/"):
		return get_node_or_null(NodePath(node_name))
	return find_child(node_name, true, false)


# --- flags and objectives -----------------------------------------------------------------

func set_flag(flag: StringName, value: bool = true) -> void:
	if flag == &"" or bool(flags.get(flag, false)) == value:
		return
	flags[flag] = value
	Game.qa_log("flag", {"level": String(level_id), "flag": String(flag), "value": value})
	flag_changed.emit(flag, value)
	_check_objectives()


func get_flag(flag: StringName) -> bool:
	return flag == &"" or bool(flags.get(flag, false))


## True when every flag in the list is set (an empty list is true).
func all_flags(list: Array) -> bool:
	for f: Variant in list:
		if not get_flag(StringName(f)):
			return false
	return true


func objectives() -> Array:
	return data.get("objectives", [])


## The text of the first objective not met yet, or "".
func current_objective() -> String:
	var list := objectives()
	for i in list.size():
		if not _objectives_done.has(i):
			return String((list[i] as Dictionary).get("text", ""))
	return ""


func _check_objectives() -> void:
	var list := objectives()
	if list.is_empty():
		return
	for i in list.size():
		var o: Dictionary = list[i]
		if _objectives_done.has(i):
			continue
		var need: Array = o.get("flags", [])
		if o.has("flag"):
			need = need + [o["flag"]]
		if all_flags(need):
			_objectives_done[i] = true
			Game.qa_log("objective", {"level": String(level_id), "index": i, "text": String(o.get("text", ""))})
			objective_completed.emit(i, String(o.get("text", "")))
	if _objectives_done.size() == list.size() and bool(data.get("complete_on_objectives", true)):
		complete()


## Finish the level: rewards, Pell's raft, the next level. Safe to call more than once.
func complete() -> void:
	if completed:
		return
	completed = true
	Game.qa_log("level_complete", {"level": String(level_id)})
	level_completed.emit()
	if is_instance_valid(Game.main) and Game.main.has_method("finish_level"):
		Game.main.finish_level(self)


# --- lines --------------------------------------------------------------------------------

func has_lines(talk_id: String) -> bool:
	return not ((data.get("lines", {}) as Dictionary).get(talk_id, []) as Array).is_empty()


## A conversation from the data file: an Array of {"who", "text"} dictionaries.
func lines(talk_id: String) -> Array:
	var all: Dictionary = data.get("lines", {})
	var out: Array = []
	for entry: Variant in all.get(talk_id, []):
		if entry is Dictionary:
			out.append(entry)
		else:
			var s := String(entry)
			var colon := s.find(": ")
			out.append({"who": s.substr(0, colon), "text": s.substr(colon + 2)} if colon > 0 else {"text": s})
	if out.is_empty():
		push_warning("Level %s: no lines '%s'" % [level_id, talk_id])
	return out


# --- hints and narration from the data file ---------------------------------------------

## level.json "hints": prompts near a point or when a flag is set; "barks": a lines key said in
## the panel, without a Person, when a flag is set (see docs/LEVEL_KIT.md).
func _start_cues() -> void:
	var list: Array = data.get("hints", [])
	for i in list.size():
		var h: Dictionary = (list[i] as Dictionary).duplicate()
		if not h.has("id"):
			h["id"] = "level_hint_%d" % i
		if h.has("near"):
			h["at"] = _cue_point(h["near"])
			_near_hints.append(h)
	if not _near_hints.is_empty():
		# A timer, not _process: level scripts override _process.
		var tick := Timer.new()
		tick.name = "HintTick"
		tick.wait_time = 0.2
		tick.autostart = true
		tick.timeout.connect(_tick_hints)
		add_child(tick)
	if list.size() > _near_hints.size() or not (data.get("barks", {}) as Dictionary).is_empty():
		flag_changed.connect(_on_cue_flag)


func _cue_point(p: Variant) -> Vector3:
	if p is Array and (p as Array).size() == 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	return marker(String(p))


func _tick_hints() -> void:
	if not is_instance_valid(player) or not is_instance_valid(Game.main):
		return
	for h in _near_hints:
		var id := StringName(h["id"])
		var d := player.global_position.distance_to(h["at"])
		var radius := float(h.get("radius", 4.0))
		var wanted := get_flag(StringName(h.get("flag", ""))) and not (h.has("until") and get_flag(StringName(h["until"])))
		if wanted and d < radius and Game.is_playing():
			if not _hint_inside.get(id, false):
				_hint_inside[id] = true
				_show_hint(h)
		elif _hint_inside.get(id, false) and (not wanted or d > radius + 1.5):
			_hint_inside[id] = false
			Game.main.hide_prompt(id)


func _show_hint(h: Dictionary) -> void:
	Game.qa_log("level_hint", {"level": String(level_id), "id": String(h["id"])})
	Game.main.prompt_near(StringName(h["id"]), String(h.get("text", "")), StringName(h.get("glyph", "")))


func _on_cue_flag(flag: StringName, value: bool) -> void:
	if not value or applying_warp or not is_instance_valid(Game.main):
		return
	for h: Dictionary in data.get("hints", []):
		if not h.has("near") and String(h.get("flag", "")) == String(flag):
			_show_hint(h if h.has("id") else h.merged({"id": "level_hint_" + String(flag)}))
	var key := String((data.get("barks", {}) as Dictionary).get(String(flag), ""))
	if key != "" and has_lines(key):
		_narrate(key)


## Say a lines key in the panel as narration (lines without "who" show no name). Waits for a
## conversation to close first.
func _narrate(key: String) -> void:
	var talk: Node = Game.main.get(&"talk")
	if talk == null:
		return
	var until := Time.get_ticks_msec() + 30000
	while bool(talk.get(&"is_open")) and Time.get_ticks_msec() < until:
		await get_tree().create_timer(0.25, false).timeout
	Game.qa_log("bark", {"person": "", "lines": key})
	talk.call(&"bark", lines(key))


# --- hooks for the main scene -------------------------------------------------------------

## Override for a level-specific finale. The default restores the zone and completes the level.
func run_finale(zone: CursedZone) -> void:
	zone.restore()
	await get_tree().create_timer(CursedZone.RESTORE_TIME + 0.5, false).timeout
	complete()


## Behind the title of a finished book: show the level as the player left it, restored, with no
## events. The default leaves it as built; a level overrides it when it has a restored look.
func show_restored() -> void:
	pass


## Start at a marker with the level's state set as if the player had got there (warp=<marker>).
## The data file's "warps" section names flags to set first; override _on_warp for more.
func apply_warp(marker_name: String) -> bool:
	if not has_marker(marker_name) and find_child(marker_name, true, false) == null:
		push_warning("Level %s: unknown warp marker '%s'" % [level_id, marker_name])
		return false
	var spec: Dictionary = (data.get("warps", {}) as Dictionary).get(marker_name, {})
	applying_warp = true
	for f: Variant in spec.get("flags", []):
		set_flag(StringName(f))
	applying_warp = false
	var at := marker(marker_name)
	var face := at + _marker_forward(marker_name)
	if spec.has("face"):
		face = marker(String(spec["face"]))
	_on_warp(marker_name)
	at = ground_at(at) + Vector3.UP * 0.05
	var d := face - at
	player.teleport(at, atan2(-d.x, -d.z) if Vector2(d.x, d.z).length() > 0.01 else player.rotation.y)
	camera.snap_behind(player)
	Game.checkpoint = at
	Game.qa_log("warp", {"marker": marker_name, "at": Game._v(at)})
	return true


func _on_warp(_marker_name: String) -> void:
	pass


## Where the title camera sits and looks while this level is behind the title.
func title_camera(t: float) -> Transform3D:
	var c := marker(title_marker) if title_marker != "" else spawn_point()
	var a := t * 0.035
	var pos := c + Vector3(sin(a) * 7.0 + 4.0, 9.5, 12.0 + cos(a) * 3.0)
	return Transform3D.IDENTITY.translated(pos).looking_at(c + Vector3(0, 1.5, -12), Vector3.UP)
