class_name MwBuilder
extends RefCounted
## Builds Mosswater Wood from MwLayout: terrain, water, trunks, props, lantern-fruit, foliage,
## mist, the pond curse zones and the darkness lights. Used by the look-dev scene now and meant
## for the playable level in phase B. Every model is a wrapper scene under
## scenes/levels/mosswater/models/ (a Node3D with an InkLook child; animated ones expose
## %AnimationPlayer); Level 1 pieces come from scenes/models/. Owner: l4.

const MODEL_DIR := "res://scenes/levels/mosswater/models/"
const FOLIAGE_SCENE := "res://scenes/env/foliage_scatter.tscn"
const MIST_SCENE := "res://scenes/env/mist.tscn"
## Lantern-fruit pool radius and strength once lit.
const LANTERN_RADIUS := 7.5
const LANTERN_POWER := 1.0
## The faint pool that travels with Orimi.
const FOLLOW_RADIUS := 3.4
const FOLLOW_POWER := 0.5
## Fenn's brazier, always burning: it is how he kept the dark off.
const BRAZIER_RADIUS := 5.0


static func scene_for(model: String, shared: String = "") -> PackedScene:
	var path := shared if shared != "" else MODEL_DIR + "mw_%s.tscn" % model
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null


## A model instance, or a small grey placeholder if its wrapper does not exist yet.
static func instance(model: String, shared: String = "") -> Node3D:
	var ps := scene_for(model, shared)
	if ps:
		return ps.instantiate() as Node3D
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	mi.mesh = box
	mi.position.y = 0.5
	n.add_child(mi)
	return n


static func place(parent: Node, n: Node3D, at: Vector3, yaw_deg: float = 0.0, scale: float = 1.0, node_name: String = "") -> Node3D:
	if node_name != "":
		n.name = node_name
	n.position = at
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n


static func anim(n: Node, anim_name: String) -> void:
	var ap := n.get_node_or_null(^"%AnimationPlayer") as AnimationPlayer
	if ap == null:
		var found := n.find_children("*", "AnimationPlayer", true, false)
		ap = found[0] as AnimationPlayer if not found.is_empty() else null
	if ap and ap.has_animation(anim_name):
		ap.play(anim_name)


static func build_terrain(root: Node3D) -> Node3D:
	var t := place(root, instance("terrain"), Vector3.ZERO, 0.0, 1.0, "Terrain")
	if t.find_children("*", "CollisionObject3D", true, false).is_empty():
		for mi: Node in t.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).create_trimesh_collision()
	return t


static func build_water(root: Node3D) -> Node3D:
	return place(root, instance("water"), Vector3.ZERO, 0.0, 1.0, "Water")


## Show the flowing water (falls and runnels) or only the still ponds.
static func set_water_flowing(water: Node3D, flowing: bool) -> void:
	if water.has_method(&"set_flowing"):
		water.call(&"set_flowing", flowing)


static func build_trees(root: Node3D, data: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Trees"
	root.add_child(holder)
	var cache := {}
	var i := 0
	for t: Dictionary in data.get("trees", []):
		var model := String(t.model)
		if not cache.has(model):
			cache[model] = scene_for(model)
		var ps: PackedScene = cache[model]
		var n: Node3D = ps.instantiate() if ps else instance(model)
		place(holder, n, MwLayout.v3(t.pos), float(t.yaw), float(t.scale), "%s_%03d" % [model, i])
		i += 1
	return holder


static func build_props(root: Node3D, data: Dictionary) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "Props"
	root.add_child(holder)
	var out := {}
	var counts := {}
	for p: Dictionary in data.get("props", []):
		var model := String(p.model)
		var id := String(p.get("id", ""))
		if id == "":
			counts[model] = int(counts.get(model, 0)) + 1
			id = "%s_%d" % [model, counts[model]]
		var n := place(holder, instance(model, String(p.get("shared", ""))), MwLayout.v3(p.pos), float(p.yaw), float(p.scale), id)
		out[id] = n
	return out


static func build_lanterns(root: Node3D, data: Dictionary) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "Lanterns"
	root.add_child(holder)
	var out := {}
	for lf: Dictionary in data.get("lanterns", []):
		var n := place(holder, instance("lantern_fruit"), MwLayout.v3(lf.pos), 0.0, 1.0, String(lf.id))
		out[String(lf.id)] = n
	return out


## The wood's darkness: render's shared light pools (docs/SHADERS.md, "Light pools"), fully dark
## until lanterns are lit.
static func make_darkness(root: Node3D) -> LightPools:
	var pools := LightPools.new()
	pools.name = "LightPools"
	root.add_child(pools)
	pools.set_darkness(1.0)
	return pools


## Move the faint pool that travels with Orimi (call every frame).
static func light_follow(pools: LightPools, n: Node3D) -> void:
	pools.set_light(&"follow", n.global_position + Vector3.UP * 0.6, FOLLOW_RADIUS, LightPools.WARM, FOLLOW_POWER)


## Light (or unlight) one lantern-fruit: its animation and its pool in the darkness.
static func set_lantern(dark: LightPools, lanterns: Dictionary, id: String, lit: bool, animate: bool = false) -> void:
	var n: Node3D = lanterns.get(id)
	if n == null:
		return
	anim(n, "lit" if lit else "unlit")
	var at := n.global_position + Vector3.DOWN * 0.5
	if dark == null:
		return
	if not lit:
		dark.remove_light(StringName(id))
	elif animate:
		dark.light_up(StringName(id), at, LANTERN_RADIUS, LightPools.WARM, LANTERN_POWER)
	else:
		dark.set_light(StringName(id), at, LANTERN_RADIUS, LightPools.WARM, LANTERN_POWER)


static func build_foliage(root: Node3D, data: Dictionary) -> Node3D:
	if not ResourceLoader.exists(FOLIAGE_SCENE):
		return null
	var f := (load(FOLIAGE_SCENE) as PackedScene).instantiate() as Node3D
	f.name = "Foliage"
	f.set(&"area_size", Vector2(96.0, 96.0))
	f.set(&"count", 1700)
	f.set(&"seed", 404)
	f.set(&"kind_weights", Vector4(0.1, 0.5, 0.4, 0.0))
	f.set(&"bush_height", Vector2(0.8, 1.4))
	f.set(&"avoid_valley_paths", false)
	var clear := PackedVector3Array()
	for k: String in data.get("paths", {}):
		var pts: Array = data.paths[k]
		for j in pts.size() - 1:
			var a := Vector2(pts[j][0], pts[j][1])
			var b := Vector2(pts[j + 1][0], pts[j + 1][1])
			var steps := maxi(1, int(a.distance_to(b) / 1.2))
			for s in steps + 1:
				var p := a.lerp(b, float(s) / steps)
				clear.append(Vector3(p.x, p.y, 1.7))
	for key: String in data.get("ponds", {}):
		var pd: Dictionary = data.ponds[key]
		var c := MwLayout.v3(pd.center)
		clear.append(Vector3(c.x, c.z, minf(float(pd.radius_s), float(pd.radius_t)) * 0.95))
	for fight: Dictionary in data.get("fights", []):
		if String(fight.kind) == "sealed":
			var c := MwLayout.v3(fight.center)
			clear.append(Vector3(c.x, c.z, float(fight.radius)))
	f.set(&"keep_clear", clear)
	place(root, f, Vector3.ZERO)
	return f


static func build_mist(root: Node3D, data: Dictionary) -> void:
	if not ResourceLoader.exists(MIST_SCENE):
		return
	var ps := load(MIST_SCENE) as PackedScene
	var spots: Array[Vector3] = []
	for key: String in data.get("ponds", {}):
		spots.append(MwLayout.v3(data.ponds[key].center))
	spots.append(MwLayout.marker("M_DarkHollow"))
	spots.append(MwLayout.marker("M_Spawn") + Vector3(-4, 0, -4))
	for i in spots.size():
		var m := ps.instantiate() as Node3D
		m.set(&"opacity", 0.45)
		m.set(&"seed", 31 + i)
		m.set(&"band_count", 5)
		place(root, m, spots[i], 0.0, 1.0, "Mist_%d" % i)


## The ponds and the spring as CurseField zones: still black ink while drained.
static func set_curse(data: Dictionary, drained: bool) -> void:
	for z: Dictionary in data.get("curse_zones", []):
		CurseField.set_zone(int(z.slot), MwLayout.v3(z.center), float(z.radius), 1.0 if drained else 0.0)
	CurseField.set_valley_gloom(1.0 if drained else 0.0, 0.0)
