extends Node3D
## The Hollow Kiln look-dev scene (scenes/levels/hollow_kiln/lookdev.tscn): the whole place from
## scenes/levels/hollow_kiln/kiln_set.tscn under the real materials, with vfx's sky, mist and
## foliage, shown drained (the Spill: CurseField zones and valley_gloom) or restored.
## Owner: l5 (hollow_kiln).
##
## Boot options (command line after -- or the web URL query):
##   state=drained|restored   default drained
##   view=<name>              one of VIEWS (default arrival); play_* views frame Orimi the way the
##                            gameplay camera does (4.9 m back, pivot 0.95 m, pitch -16, FOV 57)
##   tour=1                   cycle through every view, tour_step seconds each (default 4)
##   fox=0                    hide the stand-in Orimi on the play_* views
##   dregs=veiled|idle|lash|climb|bound|dry|unravel|none   the Dregs' pose in the vat (default veiled)
## Prints "LOOKDEV view=<name> state=<state>" each time the camera moves.

const SET_SCENE := "res://scenes/levels/hollow_kiln/kiln_set.tscn"
const SKY_SCENE := "res://scenes/env/sky.tscn"
const MIST_SCENE := "res://scenes/env/mist.tscn"
const FOLIAGE_SCENE := "res://scenes/env/foliage_scatter.tscn"
const FOX_SCENE := "res://scenes/models/fox.tscn"
const BLOB_SCENE := "res://scenes/render/blob_shadow.tscn"
const WATER_MAT := "res://materials/env/water.tres"
const INK_WATER_MAT := "res://assets/levels/hollow_kiln/materials/ink_water.tres"
## Stand-ins until the kit's person node lands: wrapper scene, feet, yaw (kiln_layout.PEOPLE), faded while drained.
const PEOPLE := [
	["res://scenes/models/folk/pell.tscn", Vector3(3.0, 0, 56.2), 100.0, false],
	["res://scenes/levels/hollow_kiln/folk/wenna.tscn", Vector3(-10.8, 2, 27.2), -60.0, true],
]

## CurseField slot, centre, radius: the same four zones as tools/levels/hollow_kiln/kiln_layout.py.
const ZONES := [
	[0, Vector3(0, 2, 17), 19.0], [1, Vector3(0, 5, -13), 19.5],
	[2, Vector3(-8, 11, -38), 13.5], [3, Vector3(2, 22, -64), 17.0],
]
## Fixed views: [camera position, look-at point]. play_* views: [Orimi's feet, Orimi's facing yaw in degrees].
const VIEWS := {
	"arrival": [Vector3(1.5, 2.6, 56.0), Vector3(0.5, 9.0, 20.0)],
	"gate": [Vector3(-2.0, 3.6, 41.0), Vector3(0.0, 5.0, 30.0)],
	"pell": [Vector3(-0.6, 1.5, 57.6), Vector3(3.0, 0.9, 56.2)],
	"keeper": [Vector3(-6.4, 3.4, 23.8), Vector3(-10.8, 2.9, 27.2)],
	"yard": [Vector3(-4.0, 5.2, 33.5), Vector3(0.0, 9.0, -10.0)],
	"yard_high": [Vector3(15.0, 15.0, 36.0), Vector3(-2.0, 2.0, 12.0)],
	"hall_entry": [Vector3(-15.5, 7.3, -3.2), Vector3(8.0, 6.0, -8.0)],
	"hall_back": [Vector3(15.6, 7.5, -21.6), Vector3(-6.0, 6.6, -18.0)],
	"hall_high": [Vector3(-16.0, 11.0, -22.6), Vector3(4.0, 5.0, -8.0)],
	"flue_low": [Vector3(-12.0, 6.8, -30.8), Vector3(-6.0, 13.0, -42.0)],
	"flue_high": [Vector3(-15.4, 16.6, -31.0), Vector3(-2.0, 10.0, -42.0)],
	"vat": [Vector3(-0.4, 20.2, -51.6), Vector3(2.0, 22.0, -64.0)],
	"vat_high": [Vector3(10.0, 25.0, -56.0), Vector3(0.0, 19.0, -68.0)],
	"vat_up": [Vector3(-6.0, 19.0, -58.0), Vector3(2.0, 40.0, -64.0)],
	"ending": [Vector3(2.0, 58.0, -40.0), Vector3(2.0, 10.0, 40.0)],
	"ending_tree": [Vector3(34.0, 56.0, -26.0), Vector3(2.0, 50.0, -64.0)],
	"title": [Vector3(20.0, 18.0, 48.0), Vector3(-12.0, 18.0, -30.0)],
	"play_landing": [Vector3(0.0, 0.0, 46.0), 0.0],
	"play_yard": [Vector3(0.0, 2.0, 22.0), 0.0],
	"play_hall": [Vector3(-6.0, 5.3, -5.0), -90.0],
	"play_hall_back": [Vector3(6.0, 5.3, -20.8), 90.0],
	"play_flue": [Vector3(-0.5, 5.9, -33.0), 0.0],
	"play_flue_mid": [Vector3(-0.5, 6.8, -36.0), 0.0],
	"play_flue_top": [Vector3(-0.5, 17.2, -36.0), 0.0],
	"play_vat": [Vector3(-0.6, 18.0, -52.5), -15.0],
	"play_vat_side": [Vector3(11.0, 18.0, -55.5), 45.0],
}
const TOUR := ["arrival", "pell", "gate", "keeper", "yard", "play_yard", "yard_high", "hall_entry", "play_hall", "hall_back", "play_hall_back",
	"hall_high", "flue_low", "play_flue", "play_flue_mid", "flue_high", "play_flue_top", "vat", "play_vat", "vat_high", "vat_up",
	"play_vat_side", "ending", "ending_tree", "title"]

var restored := false
var camera: Camera3D
var fox: Node3D
var kiln: Node3D
var people: Array[Node3D] = []
var tour_step := 4.0
var _tour_index := 0
var _tour_time := 0.0
var _touring := false


func _ready() -> void:
	restored = String(Boot.opt("state", "drained")) == "restored"
	_build_environment()
	kiln = (load(SET_SCENE) as PackedScene).instantiate() as Node3D
	add_child(kiln)
	_build_extras()
	camera = Camera3D.new()
	camera.name = "LookCamera"
	camera.fov = 57.0
	camera.near = 0.1
	camera.far = 900.0
	add_child(camera)
	camera.make_current()
	if String(Boot.opt("fox", "1")) != "0" and ResourceLoader.exists(FOX_SCENE):
		fox = (load(FOX_SCENE) as PackedScene).instantiate() as Node3D
		add_child(fox)
		if ResourceLoader.exists(BLOB_SCENE):
			fox.add_child((load(BLOB_SCENE) as PackedScene).instantiate())
		_play(fox, "idle")
	_apply_state()
	tour_step = float(Boot.opt("tour_step", 4.0))
	_touring = String(Boot.opt("tour", "0")) == "1"
	set_view(TOUR[0] if _touring else String(Boot.opt("view", "arrival")))


func _process(delta: float) -> void:
	if not _touring:
		return
	_tour_time += delta
	if _tour_time >= tour_step:
		_tour_time = 0.0
		_tour_index = (_tour_index + 1) % TOUR.size()
		set_view(TOUR[_tour_index])


func set_view(view_name: String) -> void:
	if not VIEWS.has(view_name):
		push_warning("lookdev: unknown view '%s'" % view_name)
		view_name = "arrival"
	var v: Array = VIEWS[view_name]
	if view_name.begins_with("play_"):
		var feet: Vector3 = v[0]
		var yaw := deg_to_rad(float(v[1]))
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var pitch := deg_to_rad(16.0)
		var pivot := feet + Vector3.UP * 0.95
		camera.global_position = pivot - forward * 4.9 * cos(pitch) + Vector3.UP * 4.9 * sin(pitch)
		camera.look_at(pivot + forward * 0.01 - Vector3.UP * 0.0, Vector3.UP)
		camera.rotation.x = -pitch
		if fox:
			fox.visible = true
			fox.global_position = feet
			fox.rotation.y = yaw
	else:
		camera.global_position = v[0]
		camera.look_at(v[1], Vector3.UP)
		if fox:
			fox.visible = false
	print("LOOKDEV view=%s state=%s" % [view_name, "restored" if restored else "drained"])


func _build_environment() -> void:
	if ResourceLoader.exists(SKY_SCENE):
		add_child((load(SKY_SCENE) as PackedScene).instantiate())
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
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.85
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-52, -35, 0)
	add_child(sun)


func _build_extras() -> void:
	if ResourceLoader.exists(MIST_SCENE):
		for spot: Vector3 in [Vector3(-6, 0, 50), Vector3(12, -0.4, 60), Vector3(4, -6, 90), Vector3(-10, -12, 130)]:
			var m := (load(MIST_SCENE) as PackedScene).instantiate() as Node3D
			m.position = spot
			add_child(m)
	if ResourceLoader.exists(FOLIAGE_SCENE):
		# outdoor patches only: the landing, the gorge sides, the hillside round the works
		var keep := PackedVector3Array([Vector3(0, 17, 21), Vector3(0, -13, 21), Vector3(-8, -38, 14), Vector3(2, -64, 20),
			Vector3(0, -2, 6), Vector3(0, 38, 4.5), Vector3(-2, 46, 3.5), Vector3(10, -46, 10)])
		for patch: Array in [[Vector3(0, 0, 50), Vector2(44, 26), 420], [Vector3(-30, 0, 4), Vector2(24, 80), 380],
				[Vector3(30, 0, 4), Vector2(24, 80), 380], [Vector3(0, 0, -62), Vector2(76, 60), 520]]:
			var f := (load(FOLIAGE_SCENE) as PackedScene).instantiate() as Node3D
			f.set("area_size", patch[1])
			f.set("count", patch[2])
			f.set("avoid_valley_paths", false)
			f.set("keep_clear", keep)
			f.set("kind_weights", Vector4(0.1, 0.5, 0.3, 0.1))
			f.position = patch[0]
			add_child(f)
	for p: Array in PEOPLE:
		if not ResourceLoader.exists(p[0]):
			continue
		var person := (load(p[0]) as PackedScene).instantiate() as Node3D
		person.position = p[1]
		person.rotation.y = deg_to_rad(p[2])
		person.set_meta(&"fades", p[3])
		add_child(person)
		people.append(person)


func _apply_state() -> void:
	for z: Array in ZONES:
		if restored:
			CurseField.clear_zone(z[0])
		else:
			CurseField.set_zone(z[0], z[1], z[2], 1.0)
	CurseField.set_valley_gloom(0.0 if restored else 1.0, 0.0)
	for person in people:
		var faded: bool = person.get_meta(&"fades") and not restored
		person.set(&"faded", faded)
		_play(person, "faded" if faded else "idle")
	var water := kiln.find_child("Water", true, false)
	if water and ResourceLoader.exists(INK_WATER_MAT):
		var mat: Material = load(WATER_MAT if restored else INK_WATER_MAT)
		for mi: Node in water.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
	var pool := kiln.find_child("InkPool", true, false) as Node3D
	if pool:
		pool.position.y = 3.2 if restored else 4.6
	for n: Node in kiln.find_children("*", "", true, false):
		var nm := String(n.name)
		if nm.begins_with("Brazier") or nm.begins_with("WallLamp") or nm.begins_with("KilnFire"):
			_play(n, "lit" if restored else "unlit")
		elif nm.begins_with("MossFoothold"):
			_play(n, "bloom" if restored else "withered", 99.0)
		elif nm.begins_with("Bellows"):
			_play(n, "idle")
		elif nm.begins_with("Counterweight"):
			_play(n, "open" if restored else "closed", 99.0)
		elif nm.begins_with("CordGate"):
			_play(n, "open" if restored else "bound", 99.0)
		elif nm == "Dregs":
			(n as Node3D).visible = not restored and String(Boot.opt("dregs", "veiled")) != "none"
			_play(n, String(Boot.opt("dregs", "veiled")))
		elif nm == "VatTree":
			(n as Node3D).visible = restored
			_play(n, "grow", 99.0)


func _play(node: Node, anim: String, seek_to: float = -1.0) -> void:
	var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(anim):
		return
	ap.play(anim)
	if seek_to >= 0.0:
		ap.seek(minf(seek_to, ap.current_animation_length), true)
