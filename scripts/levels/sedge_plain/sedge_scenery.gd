extends RefCounted
## Sedge Plain scenery built in code, shared by the level (sedge_plain.gd) and the look-dev scene:
## the card sedge (one scatter per ground tile), the edge of the wood, and the mist. Owner: l3.

const L := preload("res://scripts/levels/sedge_plain/sedge_layout.gd")
const MIST := "res://scenes/env/mist.tscn"
const FOLIAGE := "res://scenes/env/foliage_scatter.tscn"
const TILE := Vector2(36.0, 36.0)
const FLOOR_MIN := Vector2(-72.0, -64.0)
const TILES := Vector2i(4, 4)
const BROOK := [Vector2(-61, -48.5), Vector2(-66, -51.5), Vector2(-76, -56.5), Vector2(-92, -63)]


static func build_mist(parent: Node3D) -> void:
	if not ResourceLoader.exists(MIST):
		return
	var spots := [
		[Vector3(2.0, -2.4, -30.0), Vector2(30.0, 30.0), 10],
		[Vector3(44.0, -1.8, -22.0), Vector2(16.0, 16.0), 5],
		[Vector3(-36.0, -2.8, 22.0), Vector2(16.0, 16.0), 5],
		[Vector3(-30.0, -4.0, 0.5), Vector2(40.0, 6.0), 6],
		[Vector3(24.0, -4.0, 1.0), Vector2(40.0, 6.0), 6],
		[Vector3(0.0, -0.4, 64.0), Vector2(90.0, 10.0), 8],
	]
	for s: Array in spots:
		var m := (load(MIST) as PackedScene).instantiate() as Node3D
		m.set(&"area_size", s[1])
		m.set(&"band_count", s[2])
		m.set(&"seed", int((s[0] as Vector3).x * 7.0 + 100.0))
		m.position = s[0]
		parent.add_child(m)


## Sedge: one card scatter per ground tile (so each can be culled), kept off paths, causeways,
## islands, the Knoll's plateau, the river, and the feet of the props.
static func build_foliage(parent: Node3D, per_tile: int) -> void:
	if not ResourceLoader.exists(FOLIAGE):
		return
	var clear := clearings()
	for tz in TILES.y:
		for tx in TILES.x:
			var lo := FLOOR_MIN + Vector2(tx, tz) * TILE
			var center := lo + TILE * 0.5
			var local := PackedVector3Array()
			for c: Vector3 in clear:
				if c.x > lo.x - c.z and c.x < lo.x + TILE.x + c.z and c.y > lo.y - c.z and c.y < lo.y + TILE.y + c.z:
					local.append(c)
			var f := (load(FOLIAGE) as PackedScene).instantiate() as Node3D
			f.set(&"area_size", TILE)
			f.set(&"count", per_tile)
			f.set(&"seed", 40 + tz * 4 + tx)
			f.set(&"kind_weights", Vector4(0.34, 0.6, 0.06, 0.0))
			f.set(&"reed_height", Vector2(0.9, 1.5))
			f.set(&"grass_height", Vector2(0.55, 1.05))
			f.set(&"bush_height", Vector2(0.8, 1.2))
			f.set(&"max_slope", 32.0)
			f.set(&"avoid_valley_paths", false)
			f.set(&"keep_clear", local)
			f.position = Vector3(center.x, 0.0, center.y)
			parent.add_child(f)
			var mat = f.get(&"material")
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter(&"sway_amount", 0.34)


## The edge of the wood in the north-west: tall fan cards round the trunk models.
static func build_wood(parent: Node3D) -> void:
	var f := (load(FOLIAGE) as PackedScene).instantiate() as Node3D
	f.set(&"area_size", Vector2(44.0, 34.0))
	f.set(&"count", 90)
	f.set(&"seed", 77)
	f.set(&"kind_weights", Vector4(0.0, 0.0, 0.35, 0.65))
	f.set(&"tree_height", Vector2(4.5, 7.5))
	f.set(&"bush_height", Vector2(1.4, 2.4))
	f.set(&"max_slope", 50.0)
	f.set(&"avoid_valley_paths", false)
	var clear := PackedVector3Array()
	sample_line(clear, L.PATHS[&"exit"], 2.6, 1.5)
	sample_line(clear, BROOK, 5.5, 2.0)
	f.set(&"keep_clear", clear)
	f.position = Vector3(-62.0, 0.0, -56.0)
	parent.add_child(f)


static func clearings() -> PackedVector3Array:
	var out := PackedVector3Array()
	for key: StringName in L.PATHS:
		sample_line(out, L.PATHS[key], 2.0, 1.4)
	for line: Dictionary in L.SAFE_LINES:
		sample_line(out, line["points"], float(line["half_width"]) + 0.8, 1.2)
	for d: Vector3 in L.SAFE_DISCS:
		out.append(Vector3(d.x, d.y, d.z + 0.6))
	var river := [Vector2(-96, 66), Vector2(-66, 70), Vector2(-40, 66.5), Vector2(-14, 64.5), Vector2(6, 64.5), Vector2(28, 67), Vector2(52, 64.5), Vector2(76, 68.5)]
	sample_line(out, river, 7.2, 4.0)
	sample_line(out, BROOK, 5.5, 2.0)
	for p: Array in L.PROPS:
		var at: Vector3 = p[1]
		var r := 1.0
		match String(p[0]):
			"tamsin_camp": r = 3.4
			"landing_stage": r = 3.0
			"shrine": r = 2.0
			"wood_tree": r = 1.6
			"reeds": continue
		out.append(Vector3(at.x, at.z, r))
	return out


static func sample_line(out: PackedVector3Array, pts: Array, radius: float, step: float) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			out.append(Vector3(p.x, p.y, radius))


static func count_cards(parent: Node) -> int:
	var total := 0
	for n: Node in parent.get_children():
		var placed = n.get(&"placed")
		if placed is int:
			total += placed
	return total
