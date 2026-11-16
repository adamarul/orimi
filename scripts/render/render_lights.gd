extends Node3D
## Light pools demo (scenes/dev/render_lights.tscn): a small dusk square with three lamps, houses,
## tall trunks, rocks, foliage, water, a villager and a Splotchet, all under InkLook or the env
## shaders. Three lamps are lit one after another; then the whole place comes back. Owner: render.
##
## Boot options: keep=0|1 (1, the default: the fox keeps its colour as the player does, and the
## splotchet 0.7 as an enemy does), mode=drained|dark|none (which use of LightPools, default drained), lit=<0..3> (start
## with that many lamps lit and hold, for captures), step=<seconds> between lamps (default 2),
## curse=1 (a cursed zone with tall trunks inside and on its rim), view=main|close|curse|keep (keep frames the fox and the Splotchet).

const LAMPS := [Vector3(-9.0, 2.6, -3.0), Vector3(0.0, 2.6, -11.0), Vector3(9.0, 2.6, -3.0)]
const LAMP_RADIUS := 7.0
const VIEWS := {
	"main": [Vector3(0.0, 10.0, 15.0), Vector3(0.0, 0.5, -5.0)],
	"close": [Vector3(-3.0, 3.2, 6.0), Vector3(-7.0, 1.5, -3.0)],
	"curse": [Vector3(14.0, 4.5, 13.0), Vector3(18.0, 2.5, -2.0)],
	"keep": [Vector3(3.0, 2.6, 7.0), Vector3(0.6, 0.7, -3.5)],
}

var pools: LightPools
var _camera: Camera3D
var _step := 2.0
var _t := 0.0
var _next := 0
var _hold := false


func _ready() -> void:
	_build()
	pools = LightPools.new()
	add_child(pools)
	CurseField.set_valley_gloom(0.0)
	match String(Boot.opt("mode", "drained")):
		"drained":
			pools.set_drained(1.0)
		"dark":
			pools.set_darkness(1.0)
	_step = float(Boot.opt("step", "2"))
	var lit := String(Boot.opt("lit", ""))
	if lit != "":
		_hold = true
		for i in clampi(int(lit), 0, LAMPS.size()):
			pools.set_light(StringName("lamp_%d" % i), LAMPS[i], LAMP_RADIUS)
	if Boot.opt("curse", "0") == "1":
		CurseField.set_zone(0, Vector3(18.0, 0.0, -4.0), 8.0, 1.0)
	var v: Array = VIEWS.get(String(Boot.opt("view", "main")), VIEWS.main)
	_camera.look_at_from_position(v[0], v[1])


func _process(delta: float) -> void:
	if _hold:
		return
	_t += delta
	if _next < LAMPS.size() and _t >= _step * (_next + 1):
		pools.light_up(StringName("lamp_%d" % _next), LAMPS[_next], LAMP_RADIUS)
		_next += 1
	elif _next == LAMPS.size() and _t >= _step * (_next + 1.5):
		pools.set_drained(0.0, 2.0)
		pools.set_darkness(0.0, 2.0)
		_next += 1


func _build() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Palette.SKY
	add_child(env)
	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.make_current()

	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(200.0, 1.0, 200.0)
	shape.position.y = -0.5
	ground.add_child(shape)
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	plane.subdivide_width = 40
	plane.subdivide_depth = 40
	ground.add_child(_mesh(plane, Palette.SAGE, Vector3.ZERO))
	_look(ground, 0.0)
	add_child(ground)

	var props := Node3D.new()
	add_child(props)
	var wall := BoxMesh.new()
	wall.size = Vector3(5.0, 3.0, 4.0)
	var roof := PrismMesh.new()
	roof.size = Vector3(6.0, 1.8, 4.6)
	for h: Vector3 in [Vector3(-13.0, 0.0, -9.0), Vector3(-4.5, 0.0, -17.0), Vector3(6.0, 0.0, -17.0), Vector3(14.0, 0.0, -9.0)]:
		props.add_child(_mesh(wall, Palette.PARCHMENT_WARM, h + Vector3(0.0, 1.5, 0.0)))
		props.add_child(_mesh(roof, Palette.SEPIA, h + Vector3(0.0, 3.9, 0.0)))
	var post := CylinderMesh.new()
	post.top_radius = 0.12
	post.bottom_radius = 0.16
	post.height = 2.4
	var lamp := SphereMesh.new()
	lamp.radius = 0.35
	lamp.height = 0.7
	for p: Vector3 in LAMPS:
		props.add_child(_mesh(post, Palette.SEPIA, Vector3(p.x, 1.2, p.z)))
		props.add_child(_mesh(lamp, Palette.GOLD, p))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.3
	trunk.bottom_radius = 0.5
	trunk.height = 11.0
	for t: Vector3 in [Vector3(-17.0, 5.5, -2.0), Vector3(3.5, 5.5, -6.0), Vector3(13.0, 5.5, 1.0), Vector3(17.0, 5.5, -3.0), Vector3(23.5, 5.5, -1.0), Vector3(19.0, 5.5, 3.0)]:
		props.add_child(_mesh(trunk, Palette.STONE_DARK, t))
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	rock.radius = 1.2
	rock.height = 1.6
	for r: Vector3 in [Vector3(-6.0, 0.5, 1.0), Vector3(5.0, 0.5, -1.5), Vector3(16.0, 0.5, -6.0)]:
		props.add_child(_mesh(rock, Palette.STONE, r))
	_look(props, 1.0)

	var water := MeshInstance3D.new()
	var wplane := PlaneMesh.new()
	wplane.size = Vector2(8.0, 60.0)
	water.mesh = wplane
	water.material_override = load("res://materials/env/water.tres")
	water.position = Vector3(-24.0, 0.05, -10.0)
	add_child(water)

	var foliage: Node3D = load("res://scenes/env/foliage_scatter.tscn").instantiate()
	foliage.set(&"area_size", Vector2(44.0, 30.0))
	foliage.set(&"count", 260)
	foliage.set(&"avoid_valley_paths", false)
	foliage.position = Vector3(0.0, 0.0, -6.0)
	add_child(foliage)

	var folk: Node3D = load("res://scenes/models/folk/folk_lampmaker.tscn").instantiate()
	folk.position = Vector3(-7.5, 0.0, -1.5)
	add_child(folk)
	var splotchet: Node3D = load("res://scenes/models/splotchet.tscn").instantiate()
	splotchet.position = Vector3(1.5, 0.0, -9.0)
	var fox: Node3D = load("res://scenes/models/fox.tscn").instantiate()
	fox.position = Vector3(0.0, 0.0, 2.0)
	if str(Boot.opt("keep", "1")) == "1":
		(splotchet.get_node("InkLook") as InkLook).light_keep = 0.7
		(fox.get_node("InkLook") as InkLook).light_keep = 1.0
	add_child(splotchet)
	add_child(fox)


func _look(parent: Node3D, width: float) -> void:
	var look := InkLook.new()
	look.outline_width = width
	parent.add_child(look)


func _mesh(m: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	return mi
