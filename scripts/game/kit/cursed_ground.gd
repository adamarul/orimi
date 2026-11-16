class_name CursedGround
extends Node3D
## Ground the Spill has soaked. Inside radius it hurts Orimi and throws her back the way she
## came, except on safe ground: causeways, islands and planks the level lists as data in
## level.json ("safe_ground", keyed by this node's name; see docs/LEVEL_KIT.md). A safe shape
## can wait for a flag (a causeway buried in soot until a Gust uncovers it). When clear_flag is
## set the ground is clean. Any number of cursed grounds may exist: CurseSlots draws the four
## nearest. Owner: gameplay.

signal cleared
## Orimi was hurt here (and is being pushed back); at is where she stood.
signal hurt(at: Vector3)

## Seconds of standing on bad ground (pushed or not) before Orimi is put back where she last
## stood safely.
const STUCK_TIME := 1.6
## Orimi must stand this long on safe ground, and this far inside it, before the spot is kept as
## the place to put her back: never the very edge she stepped off, nor a spot she only brushed.
const SAFE_HOLD := 0.35
const SAFE_MARGIN := 0.5
const PUSH_SPEED := 6.0
const SAFE_COLOR := Color("efe6d2")

@export var radius: float = 10.0
## The ground becomes clean when this flag is set (for example restored_<zone_id>).
@export var clear_flag: StringName = &""
@export var damage: int = 1
## Orimi this far above the ground's centre (on a bridge, a ledge) is out of reach.
@export var max_height: float = 2.5
## Draw the Spill over the radius through CurseField.
@export var draw_curse: bool = true
## Mark safe shapes with a pale wash on the ground (off if the level models its own causeways).
@export var show_safe: bool = true

var curse_slot := -1
var is_clear := false
## Times Orimi was hurt here.
var hurts := 0
var _shapes: Array = []
var _last_safe := Vector3.INF
var _bad_time := 0.0
var _safe_time := 0.0
var _clear_end := 0.0
var _set_up := false


func _ready() -> void:
	add_to_group(&"cursed_ground")
	if draw_curse:
		CurseSlots.register(self)
	_setup.call_deferred()


func _exit_tree() -> void:
	if draw_curse:
		CurseSlots.unregister(self)


func _setup() -> void:
	while Game.level == null or not Game.level.built:
		await get_tree().process_frame
	var lvl := Game.level
	var list: Array = (lvl.data.get("safe_ground", {}) as Dictionary).get(String(name), [])
	for entry: Variant in list:
		if entry is Dictionary:
			_shapes.append(_parse(entry))
	lvl.flag_changed.connect(_on_flag)
	if clear_flag != &"" and lvl.get_flag(clear_flag):
		clear(true)
	_update_visuals()
	_set_up = true


func _xz(p: Variant) -> Vector2:
	if p is Array:
		var a: Array = p
		return Vector2(float(a[0]), float(a[2])) if a.size() >= 3 else Vector2(float(a[0]), float(a[1]))
	var v := Game.level.marker(String(p))
	return Vector2(v.x, v.z)


func _parse(e: Dictionary) -> Dictionary:
	var s := {"flag": StringName(e.get("flag", "")), "visual": null}
	if e.has("path"):
		var pts := PackedVector2Array()
		for p: Variant in e["path"]:
			pts.append(_xz(p))
		s["kind"] = "path"
		s["points"] = pts
		s["half"] = float(e.get("width", 2.0)) * 0.5
	elif e.has("circle"):
		s["kind"] = "circle"
		s["center"] = _xz(e["circle"])
		s["radius"] = float(e.get("radius", 2.0))
	elif e.has("polygon"):
		var poly := PackedVector2Array()
		for p: Variant in e["polygon"]:
			poly.append(_xz(p))
		s["kind"] = "polygon"
		s["points"] = poly
	else:
		push_warning("CursedGround %s: safe shape needs path, circle or polygon: %s" % [name, e])
		s["kind"] = "none"
	return s


func _on_flag(flag: StringName, value: bool) -> void:
	if value and flag == clear_flag:
		clear()
	_update_visuals()


## True when a world point is clean: outside the radius, or on a safe shape that is open.
## margin: only when it is that far inside the clean ground (metres).
func is_safe(p: Vector3, margin: float = 0.0) -> bool:
	if is_clear:
		return true
	var q := Vector2(p.x - global_position.x, p.z - global_position.z)
	if q.length() >= radius + margin or p.y - global_position.y > max_height + margin:
		return true
	var at := Vector2(p.x, p.z)
	for s: Dictionary in _shapes:
		if not _open(s):
			continue
		match String(s["kind"]):
			"path":
				var pts: PackedVector2Array = s["points"]
				for i in range(1, pts.size()):
					if at.distance_to(Geometry2D.get_closest_point_to_segment(at, pts[i - 1], pts[i])) <= float(s["half"]) - margin:
						return true
			"circle":
				if at.distance_to(s["center"]) <= float(s["radius"]) - margin:
					return true
			"polygon":
				var poly: PackedVector2Array = s["points"]
				if Geometry2D.is_point_in_polygon(at, poly) and _edge_distance(at, poly) >= margin:
					return true
	return false


func _edge_distance(at: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		best = minf(best, at.distance_to(Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()])))
	return best


## Standing on a body in the group "safe_ground" (a Tie rope bridge, a level's own planks) is
## always safe, wherever it lies.
func _on_safe_body(p: OrimiPlayer) -> bool:
	if not p.is_on_floor():
		return false
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i).get_collider() as Node
		while c != null and not c is Level:
			if c.is_in_group(&"safe_ground"):
				return true
			c = c.get_parent()
	return false


func _open(s: Dictionary) -> bool:
	return s["flag"] == &"" or (Game.level != null and Game.level.get_flag(s["flag"]))


func _physics_process(delta: float) -> void:
	if is_clear or not _set_up:
		return
	var p := Game.player as OrimiPlayer
	if not is_instance_valid(p) or p.dead or not Game.is_playing():
		return
	var pos := p.global_position
	if Vector2(pos.x - global_position.x, pos.z - global_position.z).length() > radius + 2.0:
		_bad_time = 0.0
		return
	var on_body := _on_safe_body(p)
	if is_safe(pos) or on_body:
		_safe_time = _safe_time + delta if p.is_on_floor() else 0.0
		if _safe_time >= SAFE_HOLD and (on_body or is_safe(pos, SAFE_MARGIN)):
			_last_safe = pos
		_bad_time = 0.0
		return
	_safe_time = 0.0
	_bad_time += delta
	var back := (_last_safe - pos) if _last_safe != Vector3.INF else (pos - global_position)
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else Vector3.BACK
	if not p.is_invulnerable():
		hurts += 1
		Game.qa_log("cursed_ground_hurt", {"ground": String(name), "at": Game._v(pos)})
		Game.hint(&"cursed_ground")
		p.take_damage(damage, pos - back)
		hurt.emit(pos)
		Events.player_thrown_back.emit(pos, &"curse")
	var v := Vector3(p.velocity.x, 0.0, p.velocity.z)
	if v.dot(back) < PUSH_SPEED:
		p.velocity += back * (PUSH_SPEED - v.dot(back))
	if _bad_time > STUCK_TIME and _last_safe != Vector3.INF:
		p.teleport(_last_safe + Vector3.UP * 0.05, p.rotation.y)
		_bad_time = 0.0
		Game.qa_log("cursed_ground_returned", {"ground": String(name), "to": Game._v(_last_safe)})


## Make the ground clean (its flag was set, or a level script calls it).
func clear(instant: bool = false) -> void:
	if is_clear:
		return
	is_clear = true
	var t := 0.1 if instant else CursedZone.RESTORE_TIME
	_clear_end = Time.get_ticks_msec() / 1000.0 + t
	if curse_slot >= 0:
		CurseField.restore_zone(curse_slot, t)
	Game.qa_log("cursed_ground_cleared", {"ground": String(name)})
	cleared.emit()
	if draw_curse:
		CurseSlots.refresh()


# --- CurseSlots ---------------------------------------------------------------------------

func curse_wants_slot() -> bool:
	return not is_clear or Time.get_ticks_msec() / 1000.0 < _clear_end


func curse_assigned(slot: int) -> void:
	CurseField.set_zone(slot, global_position, radius, 0.0 if is_clear else 1.0)


# --- looks --------------------------------------------------------------------------------

func _update_visuals() -> void:
	if not show_safe or Game.level == null:
		return
	for s: Dictionary in _shapes:
		var open := _open(s) and not is_clear
		if s["visual"] == null and open:
			s["visual"] = _make_visual(s)
		if s["visual"] != null:
			(s["visual"] as Node3D).visible = open


func _make_visual(s: Dictionary) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var tris: Array = []
	match String(s["kind"]):
		"path":
			var pts: PackedVector2Array = s["points"]
			var h: float = s["half"]
			for i in range(1, pts.size()):
				var a := pts[i - 1]
				var b := pts[i]
				var n := (b - a).orthogonal().normalized() * h
				tris.append([a + n, a - n, b - n])
				tris.append([a + n, b - n, b + n])
			for p in pts:
				tris.append_array(_disc(p, h))
		"circle":
			tris.append_array(_disc(s["center"], s["radius"]))
		"polygon":
			var poly: PackedVector2Array = s["points"]
			var idx := Geometry2D.triangulate_polygon(poly)
			for i in range(0, idx.size(), 3):
				tris.append([poly[idx[i]], poly[idx[i + 1]], poly[idx[i + 2]]])
	for tri: Array in tris:
		for v: Vector2 in tri:
			var g := Game.level.ground_at(Vector3(v.x, global_position.y + 1.0, v.y))
			st.add_vertex(Vector3(v.x, g.y + 0.04, v.y))
	var mi := MeshInstance3D.new()
	mi.name = "Safe"
	mi.mesh = st.commit()
	mi.material_override = ModelKit.mat(SAFE_COLOR, 0.55, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(&"ink_skip")
	Game.level.add_child(mi)
	return mi


func _disc(c: Vector2, r: float) -> Array:
	var out: Array = []
	var n := 14
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		out.append([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r])
	return out
