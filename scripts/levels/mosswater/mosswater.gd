extends Level
## Mosswater Wood, "The Three Still Ponds" (docs/levels/mosswater/DESIGN.md). The scene
## (written by tools/levels/mosswater/make_level_scene.py) holds the markers and the kit nodes;
## this script builds the wood itself from scripts/levels/mosswater/mosswater_layout.json, keeps
## the darkness and the lantern-fruit in step with the kit's flags, and runs the finale: the
## willow blooms and the water, the colour and the light run down through the three ponds.
## Owner: l4.

## Models the kit provides as nodes in the scene, so the builder leaves them out.
const KIT_PROPS := ["thorn_gate", "brazier", "lily"]
const POND_ORDER := ["high", "mid", "low"]
const AUDIO_DIR := "res://audio/levels/mosswater/"
const INK_NODES := {"high": "InkHigh", "mid": "InkMid", "low": "InkLow"}
## The finale: the willow's light, the gap between ponds clearing, and how long the fixed camera
## holds after the water has run.
const WILLOW_GLOW_RADIUS := 16.0
const POND_STEP := 1.6
const FINALE_CAM_HOLD := 5.0
const BEAD_DELAY := 3.0

var layout: Dictionary
var props: Dictionary = {}
var water: Node3D
var dark: LightPools
var _lanterns: Array[KindleTarget] = []


func _build(progress: Callable) -> void:
	Audio.register_music(&"mosswater_cursed", AUDIO_DIR + "mosswater_cursed.ogg")
	Audio.register_music(&"mosswater_restored", AUDIO_DIR + "mosswater_restored.ogg")
	Audio.set_level_music(&"mosswater_cursed", &"mosswater_restored")
	layout = MwLayout.data()
	var ground := Node3D.new()
	ground.name = "Ground"
	ground.add_to_group(&"level_ground")
	add_child(ground)
	MwBuilder.build_terrain(ground)
	water = MwBuilder.build_water(self)
	await _frames(1)
	progress.call(0.4, "Growing the old trees")
	MwBuilder.build_trees(self, layout).add_to_group(&"camera_fade")
	var kept := layout.duplicate()
	kept["props"] = (layout.get("props", []) as Array).filter(func(p: Dictionary) -> bool: return not String(p.model) in KIT_PROPS)
	props = MwBuilder.build_props(self, kept)
	await _frames(1)
	progress.call(0.55, "Hanging the lantern-fruit")
	MwBuilder.build_foliage(self, layout)
	MwBuilder.build_mist(self, layout)
	_add_raft()
	dark = MwBuilder.make_darkness(self)
	_light(&"brazier", marker_or(&"M_Brazier") + Vector3.UP * 0.8, MwBuilder.BRAZIER_RADIUS, 0.9)
	for n: Node in find_children("*", "KindleTarget", true, false):
		var lf := n as KindleTarget
		if lf.kind != "lantern_fruit":
			continue
		_lanterns.append(lf)
		lf.kindled.connect(_on_kindled.bind(lf))
		_show_lantern(lf, lf.lit, false)
	for n: Node in find_children("Lily_*", "GlyphTarget", true, false):
		MwBuilder.anim((n as GlyphTarget).model, "bud")
	var log_node := _prop("log")
	if log_node != null:
		log_node.add_child(_log_walk())
	var willow := node("Willow") as BloomTarget
	if willow != null and willow.model != null:
		willow.model.visible = false
	# The ponds' ink is drawn without the Spill's black-mass walls (as in lookdev).
	CurseField.walls_enabled = false
	_finale_cam(false)
	flag_changed.connect(_on_flag)


func _exit_tree() -> void:
	Audio.set_level_music(&"")
	CurseField.walls_enabled = true
	super._exit_tree()


func _process(_delta: float) -> void:
	if dark != null and is_instance_valid(player):
		MwBuilder.light_follow(dark, player.visual)


func marker_or(name_: StringName) -> Vector3:
	return MwLayout.marker(String(name_))


## A pool in the darkness (render's LightPools); grow: it lights up over a second.
func _light(id: StringName, at: Vector3, radius: float, power: float = 1.0, grow: bool = false) -> void:
	if dark == null:
		return
	if grow:
		dark.light_up(id, at, radius, LightPools.WARM, power)
	else:
		dark.set_light(id, at, radius, LightPools.WARM, power)


func _show_lantern(lf: KindleTarget, lit: bool, animate: bool) -> void:
	MwBuilder.anim(lf.model, ("catch" if animate else "lit") if lit else "unlit")
	var at := lf.global_position + Vector3.DOWN * 0.5
	if lit:
		_light(StringName(lf.name), at, MwBuilder.LANTERN_RADIUS, MwBuilder.LANTERN_POWER, animate)
	elif dark != null:
		dark.remove_light(StringName(lf.name))


func _on_kindled(lf: KindleTarget) -> void:
	_show_lantern(lf, true, true)


func _prop(prefix: String) -> Node3D:
	for id: String in props:
		if id.begins_with(prefix):
			return props[id]
	return null


func _on_flag(flag: StringName, on: bool) -> void:
	if not on:
		return
	match flag:
		&"wheel_freed":
			var wheel := _prop("wheel")
			if wheel != null:
				MwBuilder.anim(wheel, "unclog")
				get_tree().create_timer(1.0, false).timeout.connect(func() -> void: MwBuilder.anim(wheel, "spin"))
			_pond_light("low")
		&"lit_lf10":
			for id: String in props:
				if id.begins_with("M") and id.length() == 2:
					MwBuilder.anim(props[id], "unfurl")
		&"lily_1_open", &"lily_2_open", &"lily_3_open":
			var lily := node(String(flag).trim_suffix("_open").capitalize().replace(" ", "_")) as GlyphTarget
			if lily != null:
				MwBuilder.anim(lily.model, "open")
		&"tied_log":
			_pond_light("mid")
		&"tied_gap":
			# Over the gully the canopy opens above Willow Pool: the dark thins.
			if dark != null:
				dark.set_darkness(0.7, 4.0)
		&"fight_dam":
			var dam := _prop("dam")
			if dam != null:
				MwBuilder.anim(dam, "open")
			_pond_light("high")


## A flat 1.8 m walk along the old log's rounded top (its top is 0.75 m over the root, 0.56 m
## at the tip, 7.6 m along local -Z, and the walk starts 0.5 m back on the island), so walking it
## forgives a step to either side.
func _log_walk() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "LogWalk"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.2, 8.1)
	shape.shape = box
	shape.position = Vector3(0.0, 0.56, -3.55)
	shape.rotation.x = atan2(0.56 - 0.75, 7.6)
	body.add_child(shape)
	return body


func _pond_light(key: String) -> void:
	var pd: Dictionary = (layout.get("ponds", {}) as Dictionary).get(key, {})
	if pd.is_empty():
		return
	_light(StringName("pond_" + key), MwLayout.v3(pd.center) + Vector3.UP * 1.5, maxf(float(pd.radius_s), float(pd.radius_t)) + 4.0, 0.6, true)


## Bloom on the willow: the spring opens and the wood lifts at once (the dark eases off over a
## couple of seconds, warm light falls through the willow, the gloom goes), then the water runs
## pond by pond down the slope, each pond's ink clearing and its light coming up as it moves. A
## fixed camera over Willow Pool watches it. Pell's raft waits on Willow Pool (the LevelExit).
func run_finale(zone: CursedZone) -> void:
	_finale_cam(true)
	var willow := _prop("willow")
	if willow != null:
		MwBuilder.anim(willow, "bloom")
	zone.restore()
	MwBuilder.set_water_flowing(water, true)
	CurseField.set_valley_gloom(0.0, 3.0)
	if dark != null:
		dark.set_darkness(0.3, 2.5)
		dark.light_up(&"willow", marker_or(&"M_Willow") + Vector3.UP * 4.0, WILLOW_GLOW_RADIUS, LightPools.WARM, 1.2, 2.0)
	await get_tree().create_timer(2.0, false).timeout
	for key: String in POND_ORDER:
		var ink := node(INK_NODES[key]) as MwPondInk
		if ink != null:
			ink.clear()
		_pond_light(key)
		await get_tree().create_timer(POND_STEP, false).timeout
	if dark != null:
		dark.set_darkness(0.0, 3.0)
	for lf in _lanterns:
		if not lf.lit:
			lf.kindle()
	set_flag(&"water_runs")
	# Fenn's fenn_end bark first, then the bead narration (level.json barks).
	await get_tree().create_timer(BEAD_DELAY, false).timeout
	set_flag(&"ponds_remember")
	await get_tree().create_timer(FINALE_CAM_HOLD - BEAD_DELAY, false).timeout
	_finale_cam(false)


## The finale's fixed CameraZone counts only while it is in the camera_zone group.
func _finale_cam(on: bool) -> void:
	var cam := node("FinaleCam")
	if cam == null:
		return
	if on:
		cam.add_to_group(&"camera_zone")
	else:
		cam.remove_from_group(&"camera_zone")


func _on_warp(marker_name: String) -> void:
	for lf in _lanterns:
		if get_flag(lf.lit_flag) and not lf.lit:
			lf.kindle(true)
	Game.qa_log("mosswater_warp", {"marker": marker_name})


func _add_raft() -> void:
	var path := "res://scenes/models/raft.tscn"
	if not ResourceLoader.exists(path):
		return
	var raft := (load(path) as PackedScene).instantiate() as Node3D
	var at := marker_or(&"M_Raft")
	var toward := marker_or(&"M_Spawn")
	MwBuilder.place(self, raft, at, rad_to_deg(atan2(-(toward.x - at.x), -(toward.z - at.z))) + 90.0, 1.0, "LandingRaft")
