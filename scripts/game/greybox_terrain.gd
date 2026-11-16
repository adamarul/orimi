class_name GreyboxTerrain
extends RefCounted
## Grey-box valley ground built from the marker table in docs/CONTRACTS.md, used until the
## assets workstream's scenes/models/valley_terrain.tscn exists. A height field with the
## raised Soot Terrace and its ramp, Camphor Rise, the Lull's channel, valley walls,
## and two ridges that make the thorn gate and the terrace the only ways forward. Owner: gameplay.

const X0 := -40
const X1 := 40
const Z0 := -80
const Z1 := 76

const ZONE_B := Vector2(14, -10)
const TREE := Vector2(0, -42)
const GATE_B := Vector2(6, 4)
const RIVER: Array[Vector2] = [Vector2(36, -8), Vector2(24, 5), Vector2(12, 9.5), Vector2(1, 8.5),
	Vector2(2, 20), Vector2(6, 36), Vector2(10, 52), Vector2(13, 72)]
const PATH: Array[Vector2] = [Vector2(0, 52), Vector2(-2, 42), Vector2(-4, 36), Vector2(-9, 27), Vector2(-12, 20),
	Vector2(-6, 13), Vector2(0, 8), Vector2(4.8, 6.1), Vector2(6, 4), Vector2(10, -3), Vector2(14, -10),
	Vector2(9, -22), Vector2(4, -30), Vector2(0, -38)]
## Ridges: [from, to, half width, height].
const RIDGES: Array = [
	[Vector2(-34, 36), Vector2(-7.4, 36), 1.3, 4.2],
	[Vector2(-0.6, 36), Vector2(34, 36), 1.3, 4.2],
	[Vector2(-34, -5), Vector2(1.5, -5), 1.4, 4.6],
]


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func poly_dist(p: Vector2, pts: Array[Vector2]) -> float:
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, seg_dist(p, pts[i], pts[i + 1]))
	return best


static func river_dist(x: float, z: float) -> float:
	return poly_dist(Vector2(x, z), RIVER)


static func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var base := 0.16 * sin(x * 0.21 + z * 0.13) + 0.12 * sin(z * 0.17 - x * 0.09)
	var rd := river_dist(x, z)
	base -= 0.75 * (1.0 - smoothstep(1.4, 3.2, rd))
	var h := base
	# Soot Terrace: a 3 m plateau with a cliff edge.
	var db := p.distance_to(ZONE_B)
	h = maxf(h, 3.0 * (1.0 - smoothstep(13.0, 13.8, db)))
	# Ramp up to the terrace through the soot bank, along the line from the gate to the centre.
	var axis := (ZONE_B - GATE_B).normalized()
	var lateral := absf((p - GATE_B).cross(axis))
	var ramp := 3.0 * clampf((19.0 - db) / 5.6, 0.0, 1.0) * (1.0 - smoothstep(2.7, 3.0, lateral))
	h = maxf(h, ramp)
	# Camphor Rise, and a saddle that joins it to the terrace with no dip between.
	var dt := p.distance_to(TREE)
	h = maxf(h, 6.0 * (1.0 - smoothstep(12.0, 24.0, dt)))
	var s0 := Vector2(12, -16)
	var s1 := Vector2(3, -31)
	var st := clampf((p - s0).dot(s1 - s0) / (s1 - s0).length_squared(), 0.0, 1.0)
	var sd := p.distance_to(s0.lerp(s1, st))
	h = maxf(h, lerpf(3.0, 6.0, smoothstep(0.0, 1.0, st)) * (1.0 - smoothstep(4.0, 6.5, sd)))
	# Ridges.
	for r: Array in RIDGES:
		var d := seg_dist(p, r[0], r[1])
		var top: float = r[3] + 0.6 * sin(x * 0.7 + z * 0.4)
		h = maxf(h, top * (1.0 - smoothstep(r[2], r[2] + 1.1, d)))
	# Valley walls.
	h = maxf(h, 14.0 * smoothstep(25.0, 34.0, absf(x)) + 0.8 * sin(z * 0.23))
	h = maxf(h, 10.0 * smoothstep(60.0, 72.0, z))
	h = maxf(h, 12.0 * smoothstep(62.0, 74.0, -z))
	return h


static func ground_color(x: float, z: float, h: float, slope: float) -> Color:
	var p := Vector2(x, z)
	var n := 0.5 + 0.5 * sin(x * 0.31 + sin(z * 0.23) * 2.0) * cos(z * 0.27 - x * 0.11)
	var c := Palette.SAGE.lerp(Palette.SAGE_DEEP, n * 0.45)
	c = c.lerp(Palette.PARCHMENT_WARM, 0.12)
	var pd := poly_dist(p, PATH)
	c = c.lerp(Palette.PARCHMENT, (1.0 - smoothstep(1.0, 1.9, pd)) * 0.8)
	var rd := river_dist(x, z)
	c = c.lerp(Palette.STONE, (1.0 - smoothstep(2.6, 3.6, rd)) * 0.6)
	c = c.lerp(Palette.STONE, smoothstep(0.55, 1.1, slope))
	if h > 7.0:
		c = c.lerp(Palette.STONE_DARK, smoothstep(7.0, 12.0, h) * 0.5)
	return c


## Builds the ground mesh, its height-field collision, and the river surface under parent.
static func build(parent: Node3D) -> void:
	var w := X1 - X0 + 1
	var d := Z1 - Z0 + 1
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for iz in d:
		for ix in w:
			heights[iz * w + ix] = height(X0 + ix, Z0 + iz)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in d:
		for ix in w:
			var x := float(X0 + ix)
			var z := float(Z0 + iz)
			var h := heights[iz * w + ix]
			var hx := heights[iz * w + mini(ix + 1, w - 1)] - heights[iz * w + maxi(ix - 1, 0)]
			var hz := heights[mini(iz + 1, d - 1) * w + ix] - heights[maxi(iz - 1, 0) * w + ix]
			var slope := Vector2(hx, hz).length() * 0.5
			st.set_color(ground_color(x, z, h, slope))
			st.set_uv(Vector2(x, z) * 0.25)
			st.add_vertex(Vector3(x, h, z))
	for iz in d - 1:
		for ix in w - 1:
			var i := iz * w + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + w)
			st.add_index(i + 1)
			st.add_index(i + w + 1)
			st.add_index(i + w)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.metallic_specular = 0.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = w
	hm.map_depth = d
	hm.map_data = heights
	shape.shape = hm
	shape.position = Vector3((X0 + X1) * 0.5, 0, (Z0 + Z1) * 0.5)
	body.add_child(shape)
	body.add_child(mi)
	parent.add_child(body)
	ModelKit.add_ink_look(body, &"", true, 1.0)
	parent.add_child(_river())


static func _river() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	for i in RIVER.size() - 1:
		for k in 8:
			pts.append(RIVER[i].lerp(RIVER[i + 1], k / 8.0))
	pts.append(RIVER[RIVER.size() - 1])
	var y := -0.28
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := (b - a).normalized().orthogonal() * 2.9
		var na := n
		var nb := n
		var a0 := Vector3(a.x + na.x, y, a.y + na.y)
		var a1 := Vector3(a.x - na.x, y, a.y - na.y)
		var b0 := Vector3(b.x + nb.x, y, b.y + nb.y)
		var b1 := Vector3(b.x - nb.x, y, b.y - nb.y)
		for v: Vector3 in [a0, b0, a1, a1, b0, b1]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 0.2)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "RiverSurface"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water := ""
	for candidate in ["res://materials/env/water.tres", "res://materials/env/river_water.tres", "res://materials/env/water_material.tres"]:
		if ResourceLoader.exists(candidate):
			water = candidate
			break
	if water != "":
		mi.material_override = load(water)
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = Palette.RIVER
		m.roughness = 1.0
		m.metallic_specular = 0.0
		mi.material_override = m
	return mi
