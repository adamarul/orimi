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
## The wood lifts with the lantern-fruit: each one lit takes a share of DARK_EASE off the darkness
## and warms its shade toward SHADE_WARM, and the last one takes DARK_ALL_LIT more.
const DARK_EASE := 0.45
const DARK_ALL_LIT := 0.2
const SHADE_WARM := Color(0.5, 0.41, 0.31)
## A lit fruit keeps all its colour in the dark and glows: a warm halo round its core.
const GLOW_SIZE := 2.2
const GLOW_COLOR := Color(1.0, 0.72, 0.34, 1.0)

var layout: Dictionary
var props: Dictionary = {}
var water: Node3D
var dark: LightPools
var _lanterns: Array[KindleTarget] = []
var _finale := false
var _shade_cold := Color()
var _glow_mat: StandardMaterial3D
## Autoplay only: bush cards (centre and radius), for the camera check in _check_camera().
var _bushes := PackedVector4Array()
var _bushes_read := false
var _cam_wait := 0.0
var _cam_logged := {}


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
	_shade_cold = dark.shade_color
	_light(&"brazier", marker_or(&"M_Brazier") + Vector3.UP * 0.8, MwBuilder.BRAZIER_RADIUS, 0.9)
	for n: Node in find_children("*", "KindleTarget", true, false):
		var lf := n as KindleTarget
		if lf.kind != "lantern_fruit":
			continue
		_lanterns.append(lf)
		lf.kindled.connect(_on_kindled.bind(lf))
		_show_lantern(lf, lf.lit, false)
	_ease_dark(0.0)
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
	# Soot banks are brush targets, so the camera's sweep does not stop at them and could sit inside
	# the soot; the camera passes through and they fade instead (LEVEL_KIT.md, camera_fade).
	for id: String in ["WheelSoot", "SootBank"]:
		var soot := node(id)
		if soot != null:
			soot.add_to_group(GameCamera.FADE_GROUP)
	_finale_cam(false)
	flag_changed.connect(_on_flag)


func _exit_tree() -> void:
	Audio.set_level_music(&"")
	CurseField.walls_enabled = true
	super._exit_tree()


func _process(delta: float) -> void:
	if dark != null and is_instance_valid(player):
		MwBuilder.light_follow(dark, player.visual)
	if Game.autoplay:
		_check_camera(delta)


## QA lines while autoplay runs: the camera pulled in close to Orimi (something with collision
## behind her), or a bush card between it and her (cards have no collision, so the camera cannot
## keep out of them).
func _check_camera(delta: float) -> void:
	_cam_wait -= delta
	var cam := get_viewport().get_camera_3d()
	if _cam_wait > 0.0 or cam == null or not is_instance_valid(player):
		return
	_cam_wait = 0.25
	if not _bushes_read:
		_bushes_read = true
		for f: Node in find_children("Foliage*", "Node3D", false, false):
			var mmi: MultiMeshInstance3D = f.get(&"multimesh_instance")
			if mmi == null or mmi.multimesh == null:
				continue
			var buf := mmi.multimesh.buffer
			for i in mmi.multimesh.instance_count:
				var o := i * 16
				if int(buf[o + 12]) % 4 != 2:
					continue
				var c := mmi.global_transform * Vector3(buf[o + 3], buf[o + 7] + buf[o + 5] * 0.5, buf[o + 11])
				_bushes.append(Vector4(c.x, c.y, c.z, minf(buf[o], buf[o + 5]) * 0.4))
		Game.qa_log("mw_camera_bushes", {"cards": _bushes.size()})
	var eye := cam.global_position
	var pivot := player.global_position + Vector3.UP * GameCamera.PIVOT_HEIGHT
	var d := eye.distance_to(pivot)
	var where := {"at": _round3(player.global_position), "camera": _round3(eye), "distance": snappedf(d, 0.01)}
	if d < 2.0:
		_cam_qa("close", where)
	var cards := 0
	for b in _bushes:
		var c := Vector3(b.x, b.y, b.z)
		if c.distance_to(eye) < d + b.w and Geometry3D.get_closest_point_to_segment(c, eye, pivot).distance_to(c) < b.w:
			cards += 1
	if cards > 0:
		where["cards"] = cards
		_cam_qa("screened", where)


func _cam_qa(kind: String, data: Dictionary) -> void:
	var t := Time.get_ticks_msec()
	if t - int(_cam_logged.get(kind, -10000)) < 1000:
		return
	_cam_logged[kind] = t
	Game.qa_log("mw_camera_" + kind, data)


func _round3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


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
	var look := ModelKit.ink_look(lf.model)
	if look != null:
		look.light_keep = 1.0 if lit else 0.6
		look.apply()
	var glow := _lantern_glow(lf)
	glow.visible = lit
	if lit and animate:
		glow.scale = Vector3.ONE * 0.05
		create_tween().tween_property(glow, "scale", Vector3.ONE * GLOW_SIZE, 0.8).set_trans(Tween.TRANS_SINE)
	else:
		glow.scale = Vector3.ONE * GLOW_SIZE
	var at := lf.global_position + Vector3.DOWN * 0.5
	if lit:
		_light(StringName(lf.name), at, MwBuilder.LANTERN_RADIUS, MwBuilder.LANTERN_POWER, animate)
	elif dark != null:
		dark.remove_light(StringName(lf.name))


func _on_kindled(lf: KindleTarget) -> void:
	_show_lantern(lf, true, true)
	_ease_dark(1.5)


## The warm halo on a lantern-fruit's core: an unshaded card facing the camera, beside the model
## rather than under it so its InkLook leaves it alone.
func _lantern_glow(lf: KindleTarget) -> MeshInstance3D:
	var glow := lf.get_node_or_null(^"Glow") as MeshInstance3D
	if glow != null:
		return glow
	if _glow_mat == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.add_point(0.35, Color(1, 1, 1, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.albedo_color = GLOW_COLOR
		_glow_mat.albedo_texture = tex
		_glow_mat.disable_fog = true
		_glow_mat.no_depth_test = true
		_glow_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		_glow_mat.distance_fade_min_distance = 34.0
		_glow_mat.distance_fade_max_distance = 22.0
	glow = MeshInstance3D.new()
	glow.name = "Glow"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	glow.mesh = quad
	glow.material_override = _glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = lf.model.position if lf.model != null else Vector3.ZERO
	lf.add_child(glow)
	return glow


## The darkness for the lantern-fruit lit so far (thinner over the gully once the gap is tied).
func _ease_dark(duration: float) -> void:
	if dark == null or _finale or _lanterns.is_empty():
		return
	var lit := _lanterns.filter(func(lf: KindleTarget) -> bool: return lf.lit).size()
	var k := float(lit) / _lanterns.size()
	var target := (0.7 if get_flag(&"tied_gap") else 1.0) - DARK_EASE * k - (DARK_ALL_LIT if lit == _lanterns.size() else 0.0)
	dark.set_darkness(target, duration)
	var shade := _shade_cold.lerp(SHADE_WARM, k)
	dark.warmth = lerpf(0.6, 0.9, k)
	if duration <= 0.0:
		dark.shade_color = shade
	else:
		create_tween().tween_property(dark, "shade_color", shade, duration)


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
			_ease_dark(4.0)
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
	_finale = true
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
