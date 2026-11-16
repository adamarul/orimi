extends Node3D
## Tallowford look-dev: the whole village under the real materials, with vfx's sky, water, mist and
## foliage, fixed views and a camera path, drained and restored. Owner: l2.
##
## Boot options (command line after --, or the web URL query):
##   state=drained|partial|fight|restored   which moment to show (default drained)
##   cycle=1        step through drained, partial, fight, restored, lighting lamps as it goes
##   view=1..8      fixed view (default 1, the arrival); path=1 flies through every view
##   fps=1          print TF_FPS lines every 2 s
##   tint=default   render's LightPools defaults outside the pools instead of ours (a before shot);
##   tint=<hex> and sat=<0..1> try another drained_tint and drained_saturation
## Everything is placed from scripts/levels/tallowford/layout.json (written by
## tools/levels/tallowford/layout.py), so this scene and the plan cannot disagree.

const LAYOUT := "res://scripts/levels/tallowford/layout.json"
const OWN := "res://scenes/levels/tallowford/models/%s.tscn"
const SHARED := "res://scenes/models/%s.tscn"
const SHARED_MODELS := ["shrine", "thorn_gate", "reeds", "rocks", "stepping_stone"]
const SKY_SCENE := "res://scenes/env/sky.tscn"
const SOOT_SCENE := "res://scenes/env/soot_bank_visual.tscn"

## Quest lamps in beat order, then the cottages. Pool radius in metres when lit.
const QUEST := ["Trim", "Marrow", "Brindle", "Children", "Ferry"]
const COTTAGES := ["Cottage1", "Cottage2", "Cottage3", "Cottage4"]
## marker: [scene, the lamp whose lighting wakes them ("" = Pell, never faded; "end" = at restored)]
const CAST := {
	"M_Person_Trim": ["res://scenes/levels/tallowford/folk/old_trim.tscn", "Trim"],
	"M_Person_Marrow": ["res://scenes/levels/tallowford/folk/marrow.tscn", "Marrow"],
	"M_Person_Brindle": ["res://scenes/levels/tallowford/folk/brindle.tscn", "Brindle"],
	"M_Person_Flax": ["res://scenes/levels/tallowford/folk/flax.tscn", "Children"],
	"M_Person_Pibbet": ["res://scenes/levels/tallowford/folk/pibbet.tscn", "Children"],
	"M_Person_Wherry": ["res://scenes/levels/tallowford/folk/wherry.tscn", "Ferry"],
	"M_Person_Neighbour_1": ["res://scenes/levels/tallowford/folk/baker.tscn", "end"],
	"M_Person_Neighbour_2": ["res://scenes/levels/tallowford/folk/netmender.tscn", "end"],
	"M_Person_Neighbour_3": ["res://scenes/levels/tallowford/folk/fisher.tscn", "end"],
	"M_Person_Pell": ["res://scenes/models/folk/pell.tscn", ""],
}
const HOUSE_POOL := 6.5
const COTTAGE_POOL := 4.5

## name: [camera position, look-at point]
const VIEWS := [
	["arrival", Vector3(26.7, 2.45, 30.4), Vector3(18.0, 1.6, 14.0)],
	["square", Vector3(9.0, 3.0, 7.0), Vector3(-2.0, 2.0, -9.0)],
	["dye yard", Vector3(-11.0, 2.7, 7.5), Vector3(-23.0, 1.0, -2.0)],
	["well", Vector3(-0.5, 2.6, 19.5), Vector3(-9.0, 0.9, 12.5)],
	["jetty square", Vector3(11.0, 3.6, 3.0), Vector3(22.0, 0.6, -9.0)],
	["ford-lamp", Vector3(19.5, 2.4, -12.5), Vector3(29.8, 5.6, -24.0)],
	["overview", Vector3(-34.0, 30.0, 42.0), Vector3(4.0, 0.0, -4.0)],
	["from the jetty", Vector3(34.0, 2.2, -2.5), Vector3(4.0, 2.2, 1.0)],
]

var layout: Dictionary
var pools := LightPools.new()
var camera: Camera3D
var dressing := TallowfordDressing.new()
var lamps := {}          # key -> {node, anim, center}
var folk := {}           # marker -> FolkPerson
var ford: Node3D
var persimmon: Node3D
var thorns: Node3D
var soot: Node3D
var state := ""
var _fps_t := 0.0
var _frames := 0
var _path_t := -1.0


func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	pools.name = "LightPools"
	add_child(pools)
	var tint := str(Boot.opt("tint", ""))
	if tint != "default":
		dressing.light(pools)
	if tint not in ["", "default"]:
		pools.drained_tint = Color(tint)
	if str(Boot.opt("sat", "")) != "":
		pools.drained_saturation = float(str(Boot.opt("sat", "")))
	_build_environment()
	_build_world()
	_build_camera()
	await get_tree().physics_frame
	await get_tree().physics_frame
	RenderingServer.global_shader_parameter_set(&"player_world_pos", Vector3(0, -500, 0))
	var view := clampi(int(Boot.opt("view", "1")) - 1, 0, VIEWS.size() - 1)
	_set_view(view)
	set_state(str(Boot.opt("state", "drained")), false)
	print("TALLOWFORD_LOOKDEV ready props=%d lamps=%d folk=%d view=%s state=%s" % [
		get_node("Props").get_child_count(), lamps.size(), folk.size(), VIEWS[view][0], state])
	if str(Boot.opt("path", "0")) == "1":
		_path_t = 0.0
	if str(Boot.opt("cycle", "0")) == "1":
		_cycle()


func _process(delta: float) -> void:
	_frames += 1
	_fps_t += delta
	if _fps_t >= 2.0:
		if str(Boot.opt("fps", "0")) == "1":
			print("TF_FPS %.1f" % (_frames / _fps_t))
		_frames = 0
		_fps_t = 0.0
	if _path_t >= 0.0:
		_path_t += delta
		var seg := 6.0
		var i := int(_path_t / seg) % VIEWS.size()
		var j := (i + 1) % VIEWS.size()
		var t := smoothstep(0.0, 1.0, fmod(_path_t, seg) / seg)
		var pos: Vector3 = (VIEWS[i][1] as Vector3).lerp(VIEWS[j][1], t)
		var look: Vector3 = (VIEWS[i][2] as Vector3).lerp(VIEWS[j][2], t)
		camera.look_at_from_position(pos, look)


# ------------------------------------------------------------------ states
func set_state(s: String, animate: bool = true) -> void:
	state = s
	var lit: Array = []
	match s:
		"partial":
			lit = QUEST.slice(0, 3)
		"fight":
			lit = QUEST.duplicate()
		"restored":
			lit = QUEST + COTTAGES
		_:
			state = "drained"
	var restored := state == "restored"
	var dur := 1.6 if animate else 0.0
	CurseField.set_valley_gloom(0.0)
	pools.set_drained(0.0 if restored else 1.0, 3.0 if animate else 0.0)
	for key: String in QUEST + COTTAGES:
		var on: bool = key in lit
		var info: Dictionary = lamps[key]
		var anim: AnimationPlayer = info.anim
		if anim:
			anim.play(&"lit" if on else &"unlit")
		var r := HOUSE_POOL if key in QUEST else COTTAGE_POOL
		if not on:
			pools.remove_light(StringName(key))
		elif animate:
			pools.light_up(StringName(key), info.center, r, LightPools.WARM, 1.0, dur)
		else:
			pools.set_light(StringName(key), info.center, r)
	# the ford-lamp: hooded until the end
	var fanim := ford.get_node_or_null(^"%AnimationPlayer") as AnimationPlayer
	if fanim:
		fanim.play(&"lit" if restored else &"hooded")
	var fc: Vector3 = _marker("M_Kindle_Ford")
	if restored:
		pools.set_light(&"Ford", fc, 7.0)
	else:
		pools.remove_light(&"Ford")
	# the persimmon blooms at beat 4, the vats are freed at beat 2, the well cleared at beat 3
	var panim := persimmon.get_node_or_null(^"%AnimationPlayer") as AnimationPlayer
	if panim:
		var bloomed := state in ["fight", "restored"]
		panim.play(&"bloom" if bloomed else &"withered")
		if bloomed and not animate:
			panim.seek(panim.current_animation_length, true)
	for m: String in folk:
		var person: FolkPerson = folk[m]
		var waker: String = CAST[m][1]
		var awake: bool = waker == "" or (restored if waker == "end" else waker in lit)
		if awake and person.faded and animate:
			person.wake()
		else:
			person.faded = not awake
	thorns.visible = state == "drained"
	if soot:
		soot.visible = state == "drained"
	dressing.tint(self, restored)
	print("TALLOWFORD_STATE %s lit=%s" % [state, ",".join(lit)])


func _cycle() -> void:
	for s: String in ["drained", "partial", "fight", "restored"]:
		set_state(s, true)
		await get_tree().create_timer(6.0).timeout


# ------------------------------------------------------------------ building
func _marker(n: String) -> Vector3:
	var a: Array = layout.markers[n]
	return Vector3(a[0], a[1], a[2])


func _build_environment() -> void:
	if ResourceLoader.exists(SKY_SCENE):
		var sky := (load(SKY_SCENE) as PackedScene).instantiate()
		sky.set(&"cloud_count", 9)
		add_child(sky)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d8ccb4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.IVORY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)


func _instance(model: String) -> Node3D:
	var path := (SHARED if model in SHARED_MODELS else OWN) % model
	if not ResourceLoader.exists(path):
		push_warning("missing model " + path)
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


func _build_world() -> void:
	var terrain := _instance("tallowford_terrain")
	terrain.name = "Terrain"
	add_child(terrain)
	var river := _instance("tallowford_river")
	river.name = "River"
	add_child(river)
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var cottage_i := 0
	var house_of := {}
	for p: Dictionary in layout.props:
		var n := _instance(p.model)
		if n == null:
			continue
		n.position = Vector3(p.pos[0], p.pos[1], p.pos[2])
		n.rotation_degrees.y = p.yaw
		n.scale = Vector3.ONE * float(p.scale)
		props.add_child(n)
		match p.model:
			"lamp_post":
				var key := _lamp_key(n.position)
				lamps[key] = {"node": n, "anim": n.get_node_or_null(^"%AnimationPlayer"), "center": _marker("M_Kindle_" + key)}
			"ford_lamp":
				ford = n
			"persimmon":
				persimmon = n
			"thorn_gate":
				thorns = n
	var people := Node3D.new()
	people.name = "Folk"
	add_child(people)
	for m: String in CAST:
		var spot: Dictionary = layout.people[m]
		var person := (load(CAST[m][0]) as PackedScene).instantiate() as FolkPerson
		person.position = Vector3(spot.pos[0], spot.pos[1], spot.pos[2])
		person.rotation_degrees.y = spot.yaw
		people.add_child(person)
		folk[m] = person
	if ResourceLoader.exists(SOOT_SCENE):
		soot = (load(SOOT_SCENE) as PackedScene).instantiate() as Node3D
		soot.set(&"width", 1.5)
		soot.set(&"height", 1.3)
		soot.set(&"depth", 1.5)
		soot.set(&"clump_size", Vector2(0.45, 0.8))
		soot.position = _marker("M_Well") + Vector3(0, 0.55, 0)
		add_child(soot)
	dressing.build(self, river, layout)

func _lamp_key(at: Vector3) -> String:
	var best := ""
	var bd := INF
	for k: String in QUEST + COTTAGES:
		var m: Array = layout.markers["M_Lamp_" + k]
		var d := Vector2(m[0] - at.x, m[2] - at.z).length()
		if d < bd:
			bd = d
			best = k
	return best


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 57.0
	camera.near = 0.1
	camera.far = 600.0
	add_child(camera)
	camera.make_current()


func _set_view(i: int) -> void:
	camera.look_at_from_position(VIEWS[i][1], VIEWS[i][2])
