class_name HazewaterLevel
extends Level
## Level 1, Hazewater Vale. Built in code on the level base: the terrain model and its M_*
## markers (or the grey-box height field and the Marker3D fallbacks in this scene), then kit
## parts placed from the marker table in docs/CONTRACTS.md. Its lines, objectives and autoplay
## route are in scenes/levels/hazewater/level.json. Owner: gameplay.

const TERRAIN_SCENE := "res://scenes/models/valley_terrain.tscn"
const MIST_SCENE := "res://scenes/env/mist.tscn"
const FOLIAGE_SCENE := "res://scenes/env/foliage_scatter.tscn"
const RIVER_SCENE := "res://scenes/models/river_surface.tscn"
const WADE_DEPTH := 0.22
## Vfx's shared water material; it maps in world XZ, so the assets river mesh needs no UVs.
const WATER_MATERIAL := "res://materials/env/water.tres"
const ROUTE: Array[String] = ["M_Spawn", "M_GateA", "M_ZoneA", "M_Crossing", "M_GateB", "M_ZoneB", "M_Tree"]
const FALLBACK := {
	"M_Spawn": Vector3(0, 0, 50), "M_GateA": Vector3(-4, 0, 36), "M_ZoneA": Vector3(-12, 0, 20),
	"M_Crossing": Vector3(0, 0, 8), "M_GateB": Vector3(6, 1.5, 4), "M_ZoneB": Vector3(14, 3, -10),
	"M_Tree": Vector3(0, 6, -42),
}
const ZONES := {
	&"zone_a": {"marker": "M_ZoneA", "radius": 16.0, "name": "Reed Shallows"},
	&"zone_b": {"marker": "M_ZoneB", "radius": 16.0, "name": "Soot Terrace"},
	&"tree": {"marker": "M_Tree", "radius": 20.0, "name": "Camphor Rise"},
}
## Enemy placements per zone: [kind, offset from the zone centre].
const ZONE_ENEMIES := {
	&"zone_a": [[&"splotchet", Vector3(-5, 0, -4)], [&"splotchet", Vector3(4, 0, 3)],
		[&"splotchet", Vector3(-3, 0, 6)], [&"splotchet", Vector3(3, 0, -6)]],
	&"zone_b": [[&"reedwraith", Vector3(5, 0, -5)], [&"reedwraith", Vector3(-5, 0, -3)],
		[&"splotchet", Vector3(3, 0, 4)], [&"splotchet", Vector3(-4, 0, 5)], [&"splotchet", Vector3(0, 0, -7)]],
}
## Camphor Rise's final wave: offsets toward the side Orimi arrives from (the terrace ramp).
const FINAL_WAVES := [
	[[&"splotchet", Vector3(-4, 0, 6)], [&"splotchet", Vector3(4, 0, 6)], [&"splotchet", Vector3(0, 0, 4)],
		[&"reedwraith", Vector3(-6, 0, 2)]],
	[[&"splotchet", Vector3(-5, 0, 7)], [&"splotchet", Vector3(5, 0, 7)], [&"reedwraith", Vector3(6, 0, 1)]],
]

var gate_a: GlyphObstacle
var gate_b: GlyphObstacle
var zones: Dictionary = {}
var tree: BloomTarget
var greybox := true


func _build(progress: Callable) -> void:
	_build_terrain()
	_read_valley_markers()
	await _frames(2)
	progress.call(0.42, "Inking the shrine and the stones")
	_build_props()
	await _frames(2)
	progress.call(0.58, "Spilling the ink")
	_build_zones()
	_build_gates()
	await _frames(2)


func marker(marker_name: String) -> Vector3:
	if markers.has(marker_name):
		return markers[marker_name]
	if FALLBACK.has(marker_name):
		return FALLBACK[marker_name]
	return super.marker(marker_name)


# --- building -----------------------------------------------------------------------------

func _build_terrain() -> void:
	var holder := Node3D.new()
	holder.name = "Terrain"
	add_child(holder)
	if ResourceLoader.exists(TERRAIN_SCENE):
		greybox = false
		var terrain := (load(TERRAIN_SCENE) as PackedScene).instantiate() as Node3D
		holder.add_child(terrain)
		if terrain.find_children("*", "CollisionObject3D", true, false).is_empty():
			for mi: Node in terrain.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).create_trimesh_collision()
	else:
		GreyboxTerrain.build(holder)


func _read_valley_markers() -> void:
	var fallback := get_node_or_null(^"Markers")
	var terrain := get_node_or_null(^"Terrain")
	for m: String in FALLBACK:
		var found: Node3D = null
		if not greybox and terrain != null:
			found = terrain.find_child(m, true, false) as Node3D
		if found == null and fallback != null:
			found = fallback.get_node_or_null(m) as Node3D
		markers[m] = found.global_position if found != null else FALLBACK[m]
	if greybox:
		# The grey-box ground is generated from the same numbers; drop markers onto it.
		for m: String in markers:
			markers[m] = ground_at(markers[m])


func _place(n: Node3D, at: Vector3, yaw_deg: float = 0.0, parent: Node = self) -> Node3D:
	n.position = at
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	return n


func _yaw_between(a: Vector3, b: Vector3) -> float:
	var d := b - a
	return rad_to_deg(atan2(-d.x, -d.z))


func _build_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var terrain := get_node_or_null(^"Terrain")
	var spawn := marker("M_Spawn")
	var shrine_marker: Node3D = terrain.find_child("M_Shrine", true, false) as Node3D if not greybox else null
	var shrine_at := shrine_marker.global_position if shrine_marker != null else ground_at(spawn + Vector3(0, 0, 5.5))
	_place(ModelKit.load_model("shrine", ModelKit.shrine), shrine_at, 0.0, props)
	# The first of the Ink-maker's verse-stones, beside the shrine where Orimi wakes.
	var stone := VerseStone.new()
	stone.name = "VerseStone"
	stone.talk_id = "shrine_stone"
	var stone_at := ground_at(spawn + Vector3(3.0, 0, 2.0))
	_place(stone, stone_at, _yaw_between(stone_at, spawn) + 180.0)
	# Stepping stones across the Lull at the crossing (terrain markers when present).
	var c := marker("M_Crossing")
	var stones: Array[Vector3] = []
	if not greybox:
		for i in range(1, 9):
			var m := terrain.find_child("M_Stone_%d" % i, true, false) as Node3D
			if m != null:
				stones.append(m.global_position)
	if stones.is_empty():
		for off: Vector3 in [Vector3(-2.2, 0, 2.9), Vector3(-1.0, 0, 1.4), Vector3(0.3, 0, 0.0), Vector3(1.6, 0, -1.4), Vector3(2.9, 0, -2.6)]:
			stones.append(c + off + Vector3(0, -0.12, 0))
	for i in stones.size():
		var s := ModelKit.load_model("stepping_stone", ModelKit.stepping_stone)
		_place(s, stones[i], i * 37.0, props)
		if s.find_children("*", "CollisionObject3D", true, false).is_empty():
			var body := StaticBody3D.new()
			body.collision_layer = Layers.WORLD
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.7
			cyl.height = 0.6
			cs.shape = cyl
			cs.position = Vector3(0, -0.3, 0)
			body.add_child(cs)
			s.add_child(body)
	if not greybox and ResourceLoader.exists(RIVER_SCENE):
		var river := (load(RIVER_SCENE) as PackedScene).instantiate() as Node3D
		_place(river, Vector3.ZERO, 0.0, props)
		# The bed runs 2 m under the surface; a wading floor just below it keeps Orimi in view.
		for m: MeshInstance3D in river.find_children("*", "MeshInstance3D", true, false):
			if ResourceLoader.exists(WATER_MATERIAL):
				m.material_override = load(WATER_MATERIAL)
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				m.add_to_group(&"ink_skip")
			var body := StaticBody3D.new()
			body.name = "WadingFloor"
			body.collision_layer = Layers.WORLD
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			cs.shape = m.mesh.create_trimesh_shape()
			body.add_child(cs)
			m.add_child(body)
			body.position = Vector3(0, -WADE_DEPTH, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var route: Array[Vector2] = []
	for m: String in ROUTE:
		var p := marker(m)
		route.append(Vector2(p.x, p.z))
	var rocks := 0
	var tries := 0
	while rocks < 36 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(-24, 24), 0, rng.randf_range(-58, 58))
		if GreyboxTerrain.poly_dist(Vector2(p.x, p.z), route) < 5.0 or GreyboxTerrain.poly_dist(Vector2(p.x, p.z), GreyboxTerrain.PATH) < 4.0:
			continue
		if greybox and GreyboxTerrain.river_dist(p.x, p.z) < 3.5:
			continue
		var g := ground_at(p)
		if not greybox and g.y < -0.3:
			continue
		rocks += 1
		_place(ModelKit.load_model("rocks", ModelKit.rock.bind(rng.randf_range(0.4, 1.3), rocks)), g, rng.randf_range(0, 360), props)
	for i in 26:
		var t := rng.randf()
		var seg := rng.randi_range(0, GreyboxTerrain.RIVER.size() - 2)
		var a: Vector2 = GreyboxTerrain.RIVER[seg].lerp(GreyboxTerrain.RIVER[seg + 1], t)
		var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(3.2, 5.0)
		var p := Vector3(a.x + off.x, 0, a.y + off.y)
		if GreyboxTerrain.poly_dist(Vector2(p.x, p.z), route) < 2.5:
			continue
		_place(ModelKit.load_model("reeds", ModelKit.reeds.bind(i)), ground_at(p), rng.randf_range(0, 360), props)
	for spot: Vector3 in [Vector3(-14, 0, 30), Vector3(10, 0, 20), Vector3(-8, 0, -20), Vector3(0, 0, -60)]:
		if ResourceLoader.exists(MIST_SCENE):
			_place((load(MIST_SCENE) as PackedScene).instantiate() as Node3D, ground_at(spot), 0.0, props)
	if ResourceLoader.exists(FOLIAGE_SCENE):
		_place((load(FOLIAGE_SCENE) as PackedScene).instantiate() as Node3D, Vector3.ZERO, 0.0, props)


func _build_zones() -> void:
	for id: StringName in ZONES:
		var info: Dictionary = ZONES[id]
		var z := CursedZone.new()
		z.name = "Zone_" + String(id)
		z.zone_id = id
		z.radius = info["radius"]
		z.display_name = info["name"]
		z.position = marker(info["marker"])
		if id == &"tree":
			z.target_kind = "great_tree"
			z.finale = true
			z.requires_flags = PackedStringArray(["restored_zone_a", "restored_zone_b"])
		for spec: Array in ZONE_ENEMIES.get(id, []):
			_add_spawn(z, spec, spec[1], 0)
		if id == &"tree":
			# Offsets point toward the terrace ramp, the side Orimi climbs in from.
			var facing := marker("M_ZoneB") - z.position
			var basis := Basis(Vector3.UP, atan2(facing.x, facing.z))
			for w in FINAL_WAVES.size():
				for spec: Array in FINAL_WAVES[w]:
					_add_spawn(z, spec, basis * (spec[1] as Vector3), w + 1)
		add_child(z)
		zones[id] = z
		if id == &"tree":
			tree = z.target


func _add_spawn(z: CursedZone, spec: Array, offset: Vector3, wave: int) -> void:
	var s := EnemySpawn.new()
	s.kind = spec[0]
	s.wave = wave
	s.name = "%s_%d" % [String(spec[0]).capitalize(), z.get_child_count()]
	s.position = offset
	s.rotation.y = randf_range(0, TAU)
	z.add_child(s)


func _build_gates() -> void:
	var ga := marker("M_GateA")
	gate_a = GlyphObstacle.new()
	gate_a.name = "ThornGate"
	gate_a.glyph = &"slash"
	gate_a.hint_id = &"gate_a"
	gate_a.cleared_flag = &"gate_a_cut"
	_place(gate_a, ga, 0.0)
	var gb := marker("M_GateB")
	gate_b = GlyphObstacle.new()
	gate_b.name = "SootBank"
	gate_b.glyph = &"gust"
	gate_b.width = 6.4
	gate_b.height = 3.4
	gate_b.hint_id = &"gate_b"
	gate_b.cleared_flag = &"gate_b_cleared"
	_place(gate_b, gb, _yaw_between(gb, marker("M_ZoneB")))


func title_camera(t: float) -> Transform3D:
	var spawn := marker("M_Spawn")
	var a := t * 0.035
	var pos := spawn + Vector3(sin(a) * 7.0 + 4.0, 9.5, 12.0 + cos(a) * 3.0)
	return Transform3D.IDENTITY.translated(pos).looking_at(marker("M_ZoneA") + Vector3(2.0, 2.0, 4.0), Vector3.UP)


## Bloom landed on the great tree with both saplings restored: the restoration sequence.
func run_finale(zone: CursedZone) -> void:
	Game.set_state(Game.STATE_CUTSCENE)
	if is_instance_valid(Game.main):
		Game.main.hud.hide_prompt()
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	var tree_pos := zone.global_position
	Events.finale_started.emit(tree_pos)
	zone.restore()
	CurseField.set_valley_gloom(0.0, 6.0)
	var side := player.global_position - tree_pos
	side.y = 0.0
	side = side.normalized() if side.length() > 0.1 else Vector3.BACK
	await camera.cinematic_to(tree_pos + side * 15.0 + Vector3.UP * 3.0, tree_pos + Vector3.UP * 7.0, 2.6).finished
	await get_tree().create_timer(1.0).timeout
	await camera.cinematic_to(tree_pos + Vector3(0, 24, -6), marker("M_ZoneA") + Vector3(0, 0, 6), 5.0).finished
	Events.valley_restored.emit()
	set_flag(&"valley_restored")
	if is_instance_valid(Game.main):
		Game.main.hud.show_banner(display_name, "its colour returns")
	await get_tree().create_timer(3.5).timeout
	# Pell's raft comes for her at the river (level.json "raft"; the kit plays it).
	complete()


## Start at a marker with everything before it done (QA hook warp=<marker>).
func apply_warp(marker_name: String) -> bool:
	var index := ROUTE.find(marker_name)
	if index < 0:
		return super.apply_warp(marker_name)
	if index >= ROUTE.find("M_ZoneA") and is_instance_valid(gate_a):
		gate_a.remove_silently()
	if index >= ROUTE.find("M_Crossing"):
		zones[&"zone_a"].restore_silently()
		Game.checkpoint = zones[&"zone_a"].checkpoint_point()
	if index >= ROUTE.find("M_ZoneB") and is_instance_valid(gate_b):
		gate_b.remove_silently()
	if index >= ROUTE.find("M_Tree"):
		zones[&"zone_b"].restore_silently()
		Game.checkpoint = zones[&"zone_b"].checkpoint_point()
	var at := marker(marker_name)
	var face := marker(ROUTE[mini(index + 1, ROUTE.size() - 1)])
	if marker_name.begins_with("M_Gate"):
		# Stand on the near side of the gate, facing through it toward the next marker.
		var back := at - marker(ROUTE[index + 1])
		back.y = 0.0
		at = at + back.normalized() * 4.0
		face = marker(marker_name)
	elif marker_name == "M_Tree":
		var back := marker("M_ZoneB") - at
		back.y = 0.0
		at = at + back.normalized() * 15.0
		face = marker("M_Tree")
	elif marker_name.begins_with("M_Zone"):
		# Arrive at the zone's edge from the previous marker, looking in at its sapling.
		var back := marker(ROUTE[index - 1]) - at
		back.y = 0.0
		at = at + back.normalized() * 6.0
		face = marker(marker_name)
	at = ground_at(at) + Vector3.UP * 0.05
	var d := face - at
	player.teleport(at, atan2(-d.x, -d.z))
	camera.snap_behind(player)
	Game.qa_log("warp", {"marker": marker_name, "at": Game._v(at)})
	return true
