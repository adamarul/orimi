extends Node3D
## Mosswater Wood look-dev: the whole wood under the real materials (InkLook toon and outline,
## the Post chain, vfx's sky, water, mist and foliage), the pond curse zones from CurseField, the
## valley gloom, and the level's own darkness field. Owner: l4.
##
## Boot options (command line after --, or the URL query on web):
##   view=<name>          arrival, walk, wheel, stair, lily, gully, dam, willow, overview (default arrival)
##   state=drained|restored   drained: still black ponds, gloom, the dark; restored: the end state
##   lanterns=start|all|none  which lantern-fruit are lit (default: start when drained, all when restored)
##   dark=0..1            override the darkness amount; dark=0 turns the field off
##   tour=1               glide through every view (8 s each), drained then restored
##   walls=1              show CurseField's black-mass walls around the ponds (default off)
##   fox=0                hide the stand-in Orimi
## Keys: 1..9 views, R toggles drained/restored, L lights every lantern, D toggles the darkness.

const VIEW_ORDER: Array[String] = ["arrival", "walk", "wheel", "stair", "lily", "gully", "dam", "willow", "overview"]
const TOUR_SECONDS := 8.0

var data: Dictionary
var dark: LightPools
var water: Node3D
var props: Dictionary = {}
var lanterns: Dictionary = {}
var camera: Camera3D
var fox: Node3D
var flyers: Array[Node3D] = []
var _flyer_row: Array[Node3D] = []
var views: Dictionary = {}
var view_name := "arrival"
var drained := true
var _tour := false
var _tour_t := 0.0
var _fps_t := 0.0
var _fly_t := 0.0


func _ready() -> void:
	data = MwLayout.data()
	_build_environment()
	MwBuilder.build_terrain(self)
	water = MwBuilder.build_water(self)
	MwBuilder.build_trees(self, data)
	props = MwBuilder.build_props(self, data)
	lanterns = MwBuilder.build_lanterns(self, data)
	MwBuilder.build_foliage(self, data)
	MwBuilder.build_mist(self, data)
	_build_flyers()
	_build_cast()
	dark = MwBuilder.make_darkness(self)
	camera = Camera3D.new()
	camera.fov = 57.0
	camera.near = 0.1
	camera.far = 900.0
	add_child(camera)
	camera.current = true
	if String(Boot.opt("fox", "1")) != "0" and ResourceLoader.exists("res://scenes/models/fox.tscn"):
		fox = (load("res://scenes/models/fox.tscn") as PackedScene).instantiate() as Node3D
		add_child(fox)
	CurseField.walls_enabled = String(Boot.opt("walls", "0")) == "1"
	_define_views()
	var state := String(Boot.opt("state", "drained"))
	set_state(state != "restored")
	_tour = String(Boot.opt("tour", "0")) == "1"
	set_view(String(Boot.opt("view", "arrival")))
	print("ORIMI_LOOKDEV ready trees=%d props=%d lanterns=%d view=%s state=%s" % [
		get_node("Trees").get_child_count(), props.size(), lanterns.size(), view_name, "drained" if drained else "restored"])


func _exit_tree() -> void:
	for z: Dictionary in data.get("curse_zones", []):
		CurseField.clear_zone(int(z.slot))
	CurseField.walls_enabled = true


func _build_environment() -> void:
	if ResourceLoader.exists("res://scenes/env/sky.tscn"):
		var sky := (load("res://scenes/env/sky.tscn") as PackedScene).instantiate()
		sky.set(&"cloud_count", 9)
		add_child(sky)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.IVORY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.85
	sun.rotation_degrees = Vector3(-52, -35, 0)
	add_child(sun)


func _build_flyers() -> void:
	var c := MwLayout.marker("M_Flyers_Mid")
	for i in 2:
		var f := MwBuilder.instance("sootflit")
		MwBuilder.place(self, f, c, 0.0, 1.0, "Sootflit_%d" % i)
		MwBuilder.anim(f, "fly")
		flyers.append(f)


## Pell on the raft at the landing and Fenn at each of his three places (the level shows one at a time).
func _build_cast() -> void:
	var raft_at := MwLayout.marker("M_Raft")
	var toward := MwLayout.marker("M_Spawn")
	var yaw := rad_to_deg(atan2(-(toward.x - raft_at.x), -(toward.z - raft_at.z)))
	var cast := [["res://scenes/models/raft.tscn", raft_at, yaw + 90.0], ["res://scenes/models/folk/pell.tscn", raft_at + Vector3.UP * 0.3, yaw]]
	for i in 3:
		var at := MwLayout.marker("M_Fenn_%d" % (i + 1))
		cast.append(["res://scenes/levels/mosswater/folk/fenn.tscn", at, 0.0])
	for c: Array in cast:
		if not ResourceLoader.exists(c[0]):
			continue
		var n := (load(c[0]) as PackedScene).instantiate() as Node3D
		MwBuilder.place(self, n, c[1], c[2])
		MwBuilder.anim(n, "bob" if String(c[0]).ends_with("raft.tscn") else "idle")


## The Sootflit's animations side by side, for view=sootflit.
func _build_flyer_row(at: Vector3) -> void:
	var names := ["idle", "fly", "dive", "downed"]
	for i in names.size():
		var f := MwBuilder.instance("sootflit")
		MwBuilder.place(self, f, at + Vector3((i - 1.5) * 1.1, -0.9 if names[i] == "downed" else 0.0, 0.0), 180.0, 1.0, "SootflitRow_%s" % names[i])
		MwBuilder.anim(f, names[i])
		_flyer_row.append(f)


## drained = true: still black ponds, valley gloom, full dark, only the guide fruit lit.
func set_state(is_drained: bool) -> void:
	drained = is_drained
	MwBuilder.set_curse(data, drained)
	MwBuilder.set_water_flowing(water, not drained)
	var which := String(Boot.opt("lanterns", "start" if drained else "all"))
	for lf: Dictionary in data.get("lanterns", []):
		var lit := which == "all" or (which == "start" and bool(lf.lit))
		MwBuilder.set_lantern(dark, lanterns, String(lf.id), lit)
	dark.set_light(&"brazier", MwLayout.marker("M_Brazier") + Vector3.UP * 0.8, MwBuilder.BRAZIER_RADIUS, LightPools.WARM, 0.9)
	for key: String in data.get("ponds", {}):
		var id := StringName("pond_" + key)
		if drained:
			dark.remove_light(id)
		else:
			var pd: Dictionary = data.ponds[key]
			dark.set_light(id, MwLayout.v3(pd.center) + Vector3.UP * 1.5, maxf(float(pd.radius_s), float(pd.radius_t)) + 6.0, LightPools.WARM, 0.8)
	var amount := 1.0 if drained else 0.35
	dark.set_darkness(float(Boot.opt("dark", str(amount))))
	for id: String in props:
		var n: Node3D = props[id]
		if id.begins_with("wheel"):
			MwBuilder.anim(n, "clogged" if drained else "spin")
		elif id.begins_with("Lily_"):
			MwBuilder.anim(n, "bud" if drained else "open")
		elif id.begins_with("M") and id.length() == 2:
			MwBuilder.anim(n, "tucked" if drained else "unfurl")
		elif id.begins_with("willow"):
			MwBuilder.anim(n, "withered" if drained else "bloom")
		elif id.begins_with("log"):
			_set_log(n, drained)
	print("ORIMI_LOOKDEV state=%s" % ("drained" if drained else "restored"))


func _set_log(n: Node3D, jammed: bool) -> void:
	var root := MwLayout.marker("M_Log")
	var end := MwLayout.marker("M_LogEnd_Jammed" if jammed else "M_LogEnd_Bridge")
	n.rotation_degrees.y = rad_to_deg(atan2(-(end.x - root.x), -(end.z - root.z)))


func _define_views() -> void:
	var m := MwLayout.markers()
	var up := Vector3.UP
	# eye, target, fox position (on the ground in front of the eye)
	views = {
		"arrival": [m.M_Spawn + Vector3(4.2, 2.6, 3.2), m.M_Wheel + up * 2.0, m.M_Spawn],
		"walk": [m.M_DarkHollow + Vector3(5.5, 2.5, -2.0), m.M_FennHut + up * 1.5, m.M_DarkHollow + Vector3(2.4, 0, -0.8)],
		"wheel": [m.M_WheelView + Vector3(0.8, 2.4, 3.6), m.M_Wheel + up * 1.6, m.M_WheelView],
		"stair": [m.M_StairTree + Vector3(3.0, 2.6, 9.0), m.M_StairTree + up * 6.0, m.M_StairTree + Vector3(1.0, 0, 5.0)],
		"lily": [m.M_StairTop + Vector3(0.6, 2.2, -1.2), m.M_Island + up * 1.5, m.M_StairTop + Vector3(0.2, 0, -3.0)],
		"gully": [m.M_Fenn_2 + Vector3(2.0, 2.8, 2.0), m.M_MossLantern + up * 1.0, m.M_Thorns + Vector3(2.4, 0, -4.0)],
		"dam": [m.M_TiePost_D + Vector3(1.2, 2.6, 2.8), m.M_DamFight + up * 1.0 + (m.M_PondHigh - m.M_DamFight) * 0.4, m.M_TiePost_D + Vector3(0.4, 0, -1.0)],
		"willow": [m.M_Verse_2 + Vector3(2.0, 2.6, 2.0), m.M_Willow + up * 4.0, m.M_Verse_2 + Vector3(-1.0, 0, -1.4)],
		"overview": [m.M_Spawn + Vector3(10.0, 34.0, 14.0), m.M_PondMid + up * 2.0, m.M_Spawn],
		"sootflit": [m.M_Brazier + Vector3(0.0, 1.6, 3.6), m.M_Brazier + Vector3(0.0, 1.3, 0.0), m.M_Brazier + Vector3(-2.2, 0, 2.0)],
	}


func set_view(v: String) -> void:
	if not views.has(v):
		v = "arrival"
	view_name = v
	if v == "sootflit" and _flyer_row.is_empty():
		_build_flyer_row(MwLayout.marker("M_Brazier") + Vector3(0.0, 1.3, 0.0))
	var spec: Array = views[v]
	camera.global_position = spec[0]
	camera.look_at(spec[1], Vector3.UP)
	if fox:
		var at: Vector3 = spec[2]
		fox.global_position = _ground(at)
		var dir: Vector3 = spec[1] - spec[0]
		fox.rotation.y = atan2(-dir.x, -dir.z)
	print("ORIMI_LOOKDEV view=%s eye=%s" % [v, spec[0]])


func _ground(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 30.0, Layers.WORLD))
	return hit.position if not hit.is_empty() else p


func _process(delta: float) -> void:
	if fox != null:
		MwBuilder.light_follow(dark, fox)
	_fly_t += delta
	var c := MwLayout.marker("M_Flyers_Mid")
	for i in flyers.size():
		var a := _fly_t * 0.7 + PI * i
		var p := c + Vector3(cos(a) * 4.0, sin(_fly_t * 1.3 + i) * 0.5, sin(a) * 4.0)
		flyers[i].global_position = p
		flyers[i].rotation.y = -a
	if _tour:
		_tour_t += delta
		var idx := int(_tour_t / TOUR_SECONDS)
		var total := VIEW_ORDER.size()
		if idx >= total * 2:
			_tour = false
		else:
			var want := VIEW_ORDER[idx % total]
			if want != view_name:
				if idx == total and drained:
					set_state(false)
				set_view(want)
	_fps_t += delta
	if _fps_t >= 1.0:
		_fps_t = 0.0
		print("ORIMI_FPS fps=%d [t=%.1fs]" % [Engine.get_frames_per_second(), Time.get_ticks_msec() / 1000.0])
		if fox and fox.global_position.y < -50.0:
			fox.global_position = _ground(views[view_name][2])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			set_view(VIEW_ORDER[k - KEY_1])
		elif k == KEY_R:
			set_state(not drained)
		elif k == KEY_L:
			for id: String in lanterns:
				MwBuilder.set_lantern(dark, lanterns, id, true, true)
		elif k == KEY_D:
			dark.set_darkness(0.0 if dark.darkness > 0.0 else 1.0)
