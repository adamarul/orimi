extends Node3D
## Sedge Plain look-dev: the whole plain under the real materials, with vfx's sky, water, mist and
## card foliage, seen from fixed views or along a camera tour, drained or restored. Owner: l3.
##
## Boot options (command line after -- on desktop, URL query in the browser):
##   view=<name>     one of VIEWS below (default landing); view=tour flies through all of them
##   state=drained   valley_gloom 1 and the three hollows cursed (default)
##   state=restored  gloom 0, hollows clean
##   state=restore   starts drained, then restores the Mere, Brine Hollow and Wick Hollow in turn
##   foliage=<n>     sedge cards per ground tile (default 700, 16 tiles); 0 turns the sedge off
##   fox=0           hide the stand-in fox at gameplay views
##   tour_time=<s>   seconds per view on the tour (default 7)
## Prints "ORIMI_FPS fps=<n>" once a second and "SEDGE_LOOKDEV <json>" once built.

const L := preload("res://scripts/levels/sedge_plain/sedge_layout.gd")
const Scenery := preload("res://scripts/levels/sedge_plain/sedge_scenery.gd")
const SAPLING := "res://scenes/levels/sedge_plain/props/guardian_sapling.tscn"
const TERRAIN := "res://scenes/levels/sedge_plain/terrain.tscn"
const DRESSING := "res://scenes/levels/sedge_plain/dressing.tscn"
const SKY := "res://scenes/env/sky.tscn"
const SOOT := "res://scenes/env/soot_bank_visual.tscn"
const FOX := "res://scenes/models/fox.tscn"
const TAMSIN := "res://scenes/levels/sedge_plain/folk/tamsin.tscn"

## Views: eye, target, field of view, and an optional fox position (gameplay framing).
const VIEWS := {
	"landing": {"eye": Vector3(3.0, 2.65, 57.7), "at": Vector3(3.2, 1.2, 40.0), "fox": Vector3(3.0, 0.35, 53.0)},
	"camp": {"eye": Vector3(-2.5, 2.6, 49.0), "at": Vector3(-10.0, 0.9, 46.0), "fox": Vector3(-5.5, 0.1, 47.0)},
	"stones": {"eye": Vector3(7.5, 2.9, 31.0), "at": Vector3(11.0, 1.3, 16.0), "fox": Vector3(8.6, 0.5, 26.4)},
	"bridge": {"eye": Vector3(16.6, 3.1, 14.0), "at": Vector3(16.0, 0.0, 0.0), "fox": Vector3(16.2, 0.6, 9.3)},
	"seam": {"eye": Vector3(-4.0, 3.6, 7.5), "at": Vector3(22.0, -3.0, 1.0)},
	"rim": {"eye": Vector3(8.6, 3.2, -3.4), "at": Vector3(3.0, 1.0, -26.0), "fox": Vector3(7.6, 0.8, -7.8)},
	"east": {"eye": Vector3(26.8, 3.4, -13.0), "at": Vector3(42.0, -0.5, -22.0), "fox": Vector3(30.8, 1.1, -15.6)},
	"west": {"eye": Vector3(-23.0, 3.2, 9.6), "at": Vector3(-36.0, -0.5, 22.0), "fox": Vector3(-26.4, 0.7, 13.0)},
	"mere": {"eye": Vector3(-16.6, 3.4, -11.4), "at": Vector3(-6.0, 1.5, -28.0), "fox": Vector3(-14.3, 1.0, -15.0)},
	"knoll": {"eye": Vector3(1.0, 9.0, -36.5), "at": Vector3(4.0, 2.0, -6.0), "fox": Vector3(1.6, 5.7, -32.5)},
	"exit": {"eye": Vector3(-42.0, 4.0, -32.0), "at": Vector3(-62.0, 3.0, -50.0), "fox": Vector3(-46.0, 1.4, -36.5)},
	"high": {"eye": Vector3(36.0, 24.0, 40.0), "at": Vector3(0.0, 0.0, -12.0)},
}

var camera: Camera3D
var fox: Node3D
var _fps_timer := 0.0
var _tour := false
var _tour_time := 7.0
var _tour_t := 0.0
var _foliage_cards := 0
var _soot: Array[Node3D] = []


func _ready() -> void:
	RenderingServer.global_shader_parameter_set(&"player_world_pos", Vector3(0.0, -500.0, 0.0))
	_build_environment()
	add_child((load(TERRAIN) as PackedScene).instantiate())
	add_child((load(DRESSING) as PackedScene).instantiate())
	camera = Camera3D.new()
	camera.fov = 57.0
	camera.far = 1200.0
	add_child(camera)
	camera.make_current()
	if ResourceLoader.exists(FOX) and String(Boot.opt("fox", "1")) != "0":
		fox = (load(FOX) as PackedScene).instantiate() as Node3D
		add_child(fox)
	if ResourceLoader.exists(TAMSIN):
		var tamsin := (load(TAMSIN) as PackedScene).instantiate() as Node3D
		add_child(tamsin)
		tamsin.position = L.MARKERS["M_Tamsin_Camp"]
		var to_path: Vector3 = Vector3(-2.5, 0.0, 44.5) - tamsin.position
		tamsin.rotation.y = atan2(-to_path.x, -to_path.z)
	_build_curse()
	Scenery.build_mist(self)
	var sapling := (load(SAPLING) as PackedScene).instantiate() as Node3D
	add_child(sapling)
	sapling.position = L.MARKERS["M_Sapling"]
	sapling.rotation.y = deg_to_rad(20.0)
	_build_soot()
	var per_tile := int(Boot.opt("foliage", "700"))
	if per_tile > 0:
		Scenery.build_foliage(self, per_tile)
		Scenery.build_wood(self)
	var view := String(Boot.opt("view", "landing"))
	_tour_time = float(Boot.opt("tour_time", "7"))
	_tour = view == "tour"
	_show_view(VIEWS.keys()[0] if _tour else view)
	var state := String(Boot.opt("state", "drained"))
	_apply_state(state)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	print("SEDGE_LOOKDEV %s" % JSON.stringify({"view": view, "state": state, "foliage_per_tile": per_tile,
		"foliage_cards": Scenery.count_cards(self), "props": L.PROPS.size(), "markers": L.MARKERS.size()}))


func _process(delta: float) -> void:
	_fps_timer += delta
	if _fps_timer >= 1.0:
		_fps_timer = 0.0
		print("ORIMI_FPS fps=%d" % roundi(Engine.get_frames_per_second()))
	if _tour:
		_tour_t += delta
		var names := VIEWS.keys()
		var k := int(_tour_t / _tour_time) % names.size()
		var f := fmod(_tour_t, _tour_time) / _tour_time
		var a: Dictionary = VIEWS[names[k]]
		var b: Dictionary = VIEWS[names[(k + 1) % names.size()]]
		var s := smoothstep(0.55, 1.0, f)
		var eye: Vector3 = (a["eye"] as Vector3).lerp(b["eye"], s)
		var at: Vector3 = (a["at"] as Vector3).lerp(b["at"], s)
		camera.look_at_from_position(eye, at)
		if fox:
			fox.visible = a.has("fox") and s < 0.05
			if a.has("fox"):
				_place_fox(a["fox"], at)


func _show_view(view_name: String) -> void:
	var v: Dictionary = VIEWS.get(view_name, VIEWS["landing"])
	camera.look_at_from_position(v["eye"], v["at"])
	if fox:
		fox.visible = v.has("fox")
		if v.has("fox"):
			_place_fox(v["fox"], v["at"])


func _place_fox(at: Vector3, look: Vector3) -> void:
	fox.position = at
	var d := look - at
	fox.rotation.y = atan2(-d.x, -d.z)


func _build_environment() -> void:
	if ResourceLoader.exists(SKY):
		var sky := (load(SKY) as PackedScene).instantiate()
		sky.set(&"dome_radius", 420.0)
		add_child(sky)
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
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.85
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-52, -35, 0)
	add_child(sun)


func _build_curse() -> void:
	for slot in 4:
		CurseField.clear_zone(slot)
	for key: StringName in L.HOLLOWS:
		var h: Dictionary = L.HOLLOWS[key]
		CurseField.set_zone(int(h["slot"]), (h["center"] as Vector3) + Vector3.UP * 0.5, float(h["zone_radius"]), 1.0)


func _apply_state(state: String) -> void:
	match state:
		"restored":
			for key: StringName in L.HOLLOWS:
				CurseField.set_zone(int(L.HOLLOWS[key]["slot"]), (L.HOLLOWS[key]["center"] as Vector3) + Vector3.UP * 0.5, float(L.HOLLOWS[key]["zone_radius"]), 0.0)
			CurseField.set_valley_gloom(0.0, 0.0)
			_set_soot(false)
		"restore":
			CurseField.set_valley_gloom(1.0, 0.0)
			_restore_sequence()
		_:
			CurseField.set_valley_gloom(1.0, 0.0)


func _restore_sequence() -> void:
	await get_tree().create_timer(3.0).timeout
	_set_soot(false)
	for key: StringName in [&"mere", &"east", &"west"]:
		var h: Dictionary = L.HOLLOWS[key]
		CurseField.restore_zone(int(h["slot"]), 2.6)
		if Vfx.has_method("bloom_ring"):
			Vfx.bloom_ring((h["center"] as Vector3) + Vector3.UP * 3.0, float(h["zone_radius"]))
		await get_tree().create_timer(2.2).timeout
	CurseField.set_valley_gloom(0.0, 3.0)


func _build_soot() -> void:
	if not ResourceLoader.exists(SOOT):
		return
	for pair: Array in [["M_Soot_East_1", "M_Causeway_East"], ["M_Soot_East_2", "M_Island_East"], ["M_Soot_West_1", "M_Causeway_West"],
			["M_Soot_West_2", "M_Island_West"], ["M_Soot_Mere", "M_Causeway_Mere"]]:
		var at: Vector3 = L.MARKERS[pair[0]]
		var toward: Vector3 = L.MARKERS[pair[1]]
		var bank := (load(SOOT) as PackedScene).instantiate() as Node3D
		bank.set(&"width", 4.2)
		bank.set(&"height", 2.4)
		bank.position = at
		var d := toward - at
		bank.rotation.y = atan2(-d.x, -d.z)
		add_child(bank)
		_soot.append(bank)


func _set_soot(on: bool) -> void:
	for s in _soot:
		s.visible = on
