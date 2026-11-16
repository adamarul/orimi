extends Node3D
## Climb probe (scenes/levels/mosswater/climb_probe.tscn): builds Mosswater's ground and props,
## then casts rays down onto every step of the two climbs (the stair tree's fungus shelves and the
## gully's ledges and moss shelves) and along the walked paths, and prints what Orimi would stand
## on: the hit height against the data's height, the collider, the rise and gap from the step
## before, and whether a jump (about 1.4 m) reaches it. Prints MW_PROBE lines, then quits.
## Owner: l4.

const JUMP_RISE := 1.4
const JUMP_REACH := 2.6


func _ready() -> void:
	var data := MwLayout.data()
	MwBuilder.build_terrain(self)
	var props := MwBuilder.build_props(self, data)
	for id: String in props:
		if id.begins_with("M") and id.length() == 2:
			MwBuilder.anim(props[id], "unfurl")
	await get_tree().create_timer(1.5).timeout
	await get_tree().physics_frame
	var ok := true
	ok = _climb("stair", Vector3(0.0, 1.1, 14.6), (data.get("stair_shelves", []) as Array).map(func(s: Dictionary) -> Array: return [s.pos, s.top]), MwLayout.marker("M_StairTop")) and ok
	ok = _climb("gully", MwLayout.marker("M_Thorns"), (data.get("gully", []) as Array).map(func(s: Dictionary) -> Array: return [s.pos, s.top]), MwLayout.v3([data.paths.gully_top[0][0], 13.0, data.paths.gully_top[0][1]])) and ok
	for path_name: String in (data.get("paths", {}) as Dictionary):
		_path(path_name, data.paths[path_name])
	ok = await _log_walk(props) and ok
	_grid(String(Boot.opt("grid", "")))
	print("MW_PROBE_%s" % ("OK" if ok else "PROBLEMS"))
	get_tree().quit(0 if ok else 1)


func _hit(p: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 6.0, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q)


func _climb(label: String, start: Vector3, steps: Array, finish: Vector3) -> bool:
	var ok := true
	var prev := start
	var h0 := _hit(start)
	if not h0.is_empty():
		prev = h0.position
	var points: Array = []
	for s: Array in steps:
		points.append(MwLayout.v3(s[0]) + Vector3(0, float(s[1]) - MwLayout.v3(s[0]).y, 0))
	if not points.is_empty():
		var last: Vector3 = points[-1]
		var toward := Vector3(finish.x - last.x, 0, finish.z - last.z).normalized()
		points.append(last + toward * 1.6 + Vector3.UP * (finish.y - last.y))
	points.append(finish)
	for i in points.size():
		var want: Vector3 = points[i]
		var h := _hit(want)
		if h.is_empty():
			print("MW_PROBE %s step %d at %s: NOTHING TO STAND ON" % [label, i, want])
			ok = false
			continue
		var at: Vector3 = h.position
		var rise := at.y - prev.y
		var gap := Vector2(at.x - prev.x, at.z - prev.z).length()
		var collider := String((h.collider as Node).get_path()).get_slice("/", 3) if h.collider else "?"
		var reachable := rise <= JUMP_RISE and gap <= JUMP_REACH + maxf(0.0, -rise)
		print("MW_PROBE %s step %d: stands at y %.2f (data %.2f, off %+.2f) on %s; rise %+.2f gap %.2f %s" % [label, i, at.y, want.y, at.y - want.y, collider, rise, gap, "ok" if reachable else "OUT OF REACH"])
		ok = ok and reachable and absf(at.y - want.y) < 0.35
		prev = at
	return ok


## The old log swung free (the pose of Ties/Log/LogFree in the level scene): what Orimi stands on
## along its length.
func _log_walk(props: Dictionary) -> bool:
	var log_node: Node3D = props.get("log_1")
	var state := (load("res://scenes/levels/mosswater/mosswater.tscn") as PackedScene).get_state()
	for i in state.get_node_count():
		if state.get_node_name(i) != &"LogFree":
			continue
		for k in state.get_node_property_count(i):
			if state.get_node_property_name(i, k) == &"transform":
				log_node.global_transform = state.get_node_property_value(i, k)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ok := true
	var dir := -log_node.global_basis.z
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var want := MwLayout.marker("M_LogEnd_Bridge") - MwLayout.marker("M_Log")
	print("MW_PROBE log axis %s (toward M_LogEnd_Bridge %s), tip rises %.2f m" % [dir, Vector3(want.x, 0.0, want.z).normalized(), -log_node.global_basis.z.y * 7.6])
	for d: float in [-1.0, 0.5, 2.5, 4.5, 6.5, 8.0]:
		var p := log_node.global_position + dir * d
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 20.0, Layers.WORLD))
		var y: float = (hit.position as Vector3).y if not hit.is_empty() else -INF
		var on := String((hit.collider as Node).name) if not hit.is_empty() else "nothing"
		print("MW_PROBE log %.1f m: stands at y %.2f on %s" % [d, y, on])
		if d > 0.0 and d < 7.6 and y < 6.6:
			ok = false
	return ok


## grid=x0,z0,x1,z1: print the ground height every 0.5 m over that rectangle (one row per z).
func _grid(spec: String) -> void:
	var v := spec.split_floats(",")
	if v.size() != 4:
		return
	var z := v[1]
	while z <= v[3]:
		var row := PackedStringArray()
		var x := v[0]
		while x <= v[2]:
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -10.0, z), Layers.WORLD))
			row.append("%5.1f" % (hit.position as Vector3).y if not hit.is_empty() else "  -  ")
			x += 0.5
		print("MW_PROBE grid z %6.1f: %s" % [z, " ".join(row)])
		z += 0.5


func _path(label: String, pts: Array) -> void:
	var worst := 0.0
	var worst_at := Vector3.ZERO
	var prev := NAN
	for i in range(1, pts.size()):
		var a := MwLayout.v3([pts[i - 1][0], 0, pts[i - 1][1]]) if (pts[i - 1] as Array).size() == 2 else MwLayout.v3(pts[i - 1])
		var b := MwLayout.v3([pts[i][0], 0, pts[i][1]]) if (pts[i] as Array).size() == 2 else MwLayout.v3(pts[i])
		for k in 10:
			var p := a.lerp(b, k / 10.0)
			var h := _hit(Vector3(p.x, 30.0, p.z) + Vector3.DOWN * 20.0)
			if h.is_empty():
				continue
			var y: float = h.position.y
			if label == String(Boot.opt("dump", "")):
				print("MW_PROBE dump %s (%.2f, %.2f) y %.2f on %s" % [label, p.x, p.z, y, (h.collider as Node).name])
			if not is_nan(prev) and absf(y - prev) > worst:
				worst = absf(y - prev)
				worst_at = h.position
			prev = y
	print("MW_PROBE path %s: largest step between samples %.2f m at %s" % [label, worst, worst_at])
