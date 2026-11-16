class_name TallowfordDressing
extends RefCounted
## Tallowford's dressing, shared by the level and the look-dev: vfx's water on the river, foliage
## kept off the paths, banks and yards, mist on the river and hill feet, and the dusk tints on
## sky, foliage, mist and water. Placement comes from layout.json. Owner: l2.

const FOLIAGE_SCENE := "res://scenes/env/foliage_scatter.tscn"
const MIST_SCENE := "res://scenes/env/mist.tscn"
const WATER_MATERIAL := "res://materials/env/water.tres"
const MIST_SPOTS := [Vector3(34, -0.3, -18), Vector3(34, -0.3, 14), Vector3(-10, 0.2, 28), Vector3(-30, 1.5, -24)]
## Outside the lamps' pools (render's LightPools): an amber-grey dusk with little colour left, so a
## lit pool reads at a glance from across the square.
const DRAINED_TINT := Color("b8ad98")
const DRAINED_SATURATION := 0.1

var foliage: Array[Node] = []
var mists: Array[Node] = []
var water: ShaderMaterial
var sky_material: ShaderMaterial


## Water on every mesh under river, foliage and mist under root.
func build(root: Node3D, river: Node3D, layout: Dictionary) -> void:
	if ResourceLoader.exists(WATER_MATERIAL):
		water = (load(WATER_MATERIAL) as ShaderMaterial).duplicate() as ShaderMaterial
		water.set_shader_parameter(&"flow_direction", Vector2(layout.flow[0], layout.flow[1]))
		for m: MeshInstance3D in river.find_children("*", "MeshInstance3D", true, false):
			m.material_override = water
			m.add_to_group(&"ink_skip")
		Vfx.register_material(water)
	_build_foliage(root, layout)
	if ResourceLoader.exists(MIST_SCENE):
		for spot: Vector3 in MIST_SPOTS:
			var mist := (load(MIST_SCENE) as PackedScene).instantiate() as Node3D
			mist.set(&"opacity", 0.5)
			mist.position = spot
			root.add_child(mist)
			mists.append(mist)


## Tallowford's mood on render's LightPools.
func light(pools: LightPools) -> void:
	pools.drained_tint = DRAINED_TINT
	pools.drained_saturation = DRAINED_SATURATION


## Dusk colours, drained or restored. The sky material is the shared sky's (found under root).
func tint(root: Node, restored: bool) -> void:
	if sky_material == null:
		for n: Node in root.find_children("*", "", true, false):
			var m: Variant = n.get(&"material")
			if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).get_shader_parameter(&"zenith_color") != null:
				sky_material = m
				break
	if sky_material:
		sky_material.set_shader_parameter(&"zenith_color", Color("a2a59f") if restored else Color("9c9a94"))
		sky_material.set_shader_parameter(&"horizon_color", Color("e8c48c") if restored else Color("dcc39a"))
		sky_material.set_shader_parameter(&"drained_color", Color("cfc3ab"))
	for f: Node in foliage:
		var m: ShaderMaterial = f.get(&"material")
		if m:
			m.set_shader_parameter(&"light_color", Color("9eb07c") if restored else Color("8f9a78"))
			m.set_shader_parameter(&"dark_color", Color("566f4c") if restored else Color("4f5e48"))
	for mnode: Node in mists:
		var mm: ShaderMaterial = mnode.get(&"material")
		if mm:
			mm.set_shader_parameter(&"mist_color", Color("e9dcc0") if restored else Color("d9cdb6"))
	if water:
		water.set_shader_parameter(&"wash_color", Color("7fa0a6") if restored else Color("6f878c"))
		water.set_shader_parameter(&"deep_color", Color("6b8d95") if restored else Color("5d7479"))


func _build_foliage(root: Node3D, layout: Dictionary) -> void:
	if not ResourceLoader.exists(FOLIAGE_SCENE):
		return
	var clear := PackedVector3Array()
	for c: Array in layout.clear:
		clear.append(Vector3(c[0], c[1], c[2]))
	for pname: String in layout.paths:
		var path: Dictionary = layout.paths[pname]
		var pts: Array = path.points
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var n := maxi(1, int(a.distance_to(b) / 1.5))
			for k in n + 1:
				var q := a.lerp(b, float(k) / n)
				clear.append(Vector3(q.x, q.y, float(path.half_width) + 0.9))
	var river: Array = layout.river
	for i in river.size() - 1:
		var a := Vector2(river[i][0], river[i][1])
		var b := Vector2(river[i + 1][0], river[i + 1][1])
		var n := maxi(1, int(a.distance_to(b) / 3.0))
		for k in n + 1:
			var q := a.lerp(b, float(k) / n)
			clear.append(Vector3(q.x, q.y, 5.2))
	# village floor: grass and bushes; hill feet: tree fans; banks: reeds
	for spec: Array in [
			[Vector3(-3, 0, 0), Vector2(62, 62), 650, Vector4(0.05, 0.7, 0.25, 0.0), 21],
			[Vector3(-36, 0, 0), Vector2(10, 70), 70, Vector4(0.0, 0.2, 0.3, 0.5), 22],
			[Vector3(0, 0, -32), Vector2(70, 8), 70, Vector4(0.0, 0.2, 0.3, 0.5), 23],
			[Vector3(27, 0, 0), Vector2(5, 66), 110, Vector4(0.7, 0.3, 0.0, 0.0), 24]]:
		var f := (load(FOLIAGE_SCENE) as PackedScene).instantiate() as Node3D
		f.set(&"area_size", spec[1])
		f.set(&"count", spec[2])
		f.set(&"kind_weights", spec[3])
		f.set(&"seed", spec[4])
		f.set(&"avoid_valley_paths", false)
		f.set(&"keep_clear", clear)
		f.position = spec[0]
		root.add_child(f)
		foliage.append(f)
