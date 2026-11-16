class_name RaftTrip
extends Node3D
## Pell's raft, played by the kit at both ends of a level. depart(): the raft pulls in at the
## level's exit with Pell aboard (or is already moored there), Pell says the level's raft line,
## Orimi hops on and it pushes off with a wake. arrive(): the raft glides in to the level's
## arrival marker with both aboard, Orimi hops off and Pell says his arrival line; raft and Pell
## stay moored. Each way is about five seconds plus the lines; skip() ends it at once. The level
## only supplies data in level.json "raft" (docs/LEVEL_KIT.md). Owner: gameplay.

## A moment worth a shot: raft_unfaded (the paper clears after Orimi is set on the bank), raft_framed,
## raft_in, raft_off (departure), raft_arrives, landed (arrival).
signal moment(stage: String)

const GLIDE := 5.0
const PULL_IN_TIME := 1.6
const PUSH_OFF_TIME := 2.4
const ARRIVE_TIME := 2.4
const HOP_TIME := 0.45
## Where Orimi and Pell stand on the deck (the raft's origin is at the waterline, bow along -Z).
const ORIMI_SPOT := Vector3(0, 0.17, -0.35)
const PELL_SPOT := Vector3(0, 0.17, 0.85)

var level: Level
var raft: Node3D
var pell: Node3D
var playing := false
var skipping := false
var _tween: Tween
var _water := 0.0


## True when the level's data places a departure: a "depart" point, or a LevelExit with "water" set
## or with the raft as its own model.
static func can_depart(l: Level) -> bool:
	var d: Dictionary = l.data.get("raft", {})
	if d.has("depart"):
		return true
	var exit := l.get_tree().get_first_node_in_group(&"level_exit")
	return exit != null and (d.has("water") or exit.get(&"model_name") == "raft")


static func can_arrive(l: Level) -> bool:
	return (l.data.get("raft", {}) as Dictionary).has("arrive")


func _init(l: Level) -> void:
	level = l
	name = "RaftTrip"


## End the moment now: every move jumps to its end and lines are left out.
func skip() -> void:
	if not playing or skipping:
		return
	skipping = true
	Game.qa_log("raft_skipped", {})


func depart() -> void:
	var d: Dictionary = level.data.get("raft", {})
	var exit := level.get_tree().get_first_node_in_group(&"level_exit") as Node3D
	var moor := _place(d, "depart", exit)
	playing = true
	var p := level.player
	var fwd := -moor.basis.z
	var own: bool = exit != null and not d.has("depart") and exit.get(&"model_name") == "raft" and exit.get(&"model") != null
	raft = exit.get(&"model") as Node3D if own else _new_raft()
	_colliders(raft, false)
	pell = _find_pell()
	var board := _point(d, "board", moor.origin + _flat(p.global_position - moor.origin).normalized() * 2.6)
	var moved := _flat(p.global_position - board).length() > 6.0
	if moved:
		await Game.main.fade(1.0, 0.35)
		p.teleport(board + Vector3.UP * 0.05, atan2(-(moor.origin - board).x, -(moor.origin - board).z))
	# Behind the paper the camera cuts straight to the bank; in plain view it glides there.
	_frame(moor, p.global_position, 0.0 if moved else 0.6)
	if moved:
		await get_tree().process_frame
		await Game.main.fade(0.0, 0.35)
		_emit("raft_unfaded")
	if not skipping:
		get_tree().create_timer(0.8).timeout.connect(_emit.bind("raft_framed"))
	if own:
		raft.global_transform = moor
		_carry(pell, PELL_SPOT)
	else:
		raft.global_transform = Transform3D(moor.basis, moor.origin - fwd * GLIDE)
		Vfx.attach_wake(raft, _water)
		await _play(_glide(Transform3D(moor.basis, moor.origin - fwd * GLIDE), moor, PULL_IN_TIME, Tween.EASE_OUT, [pell]))
		Vfx.detach_wake(raft)
	_emit("raft_in")
	if d.has("talk") and not skipping:
		await Game.main.talk.run(level.lines(String(d["talk"])), true)
	await _hop(p, p.global_position, raft.global_transform * ORIMI_SPOT, -raft.global_basis.z)
	Audio.play_sfx(&"raft", raft.global_position)
	Vfx.attach_wake(raft, _water)
	var away := Transform3D(moor.basis, moor.origin + fwd * GLIDE * 1.4)
	var t := _glide(moor, away, PUSH_OFF_TIME, Tween.EASE_IN, [pell, p])
	if not skipping:
		get_tree().create_timer(PUSH_OFF_TIME * 0.45).timeout.connect(_emit.bind("raft_off"))
	await _play(t)
	if skipping:
		_emit("raft_off")
	playing = false


func arrive() -> void:
	var d: Dictionary = level.data.get("raft", {})
	var moor := _place(d, "arrive", null)
	playing = true
	var p := level.player
	var fwd := -moor.basis.z
	raft = _new_raft()
	_colliders(raft, false)
	pell = _find_pell()
	var from := Transform3D(moor.basis, moor.origin - fwd * GLIDE)
	raft.global_transform = from
	_carry(pell, PELL_SPOT)
	_carry(p, ORIMI_SPOT)
	var land := _point(d, "land", moor.origin + fwd * 2.4)
	_frame(moor, land)
	Audio.play_sfx(&"raft", moor.origin)
	Vfx.attach_wake(raft, _water)
	var t := _glide(from, moor, ARRIVE_TIME, Tween.EASE_OUT, [pell, p])
	if not skipping:
		get_tree().create_timer(ARRIVE_TIME * 0.5).timeout.connect(_emit.bind("raft_arrives"))
	await _play(t)
	if skipping:
		_emit("raft_arrives")
	Vfx.detach_wake(raft)
	await _hop(p, p.global_position, land, fwd)
	_colliders(raft, true)
	_emit("landed")
	if d.has("arrive_talk") and not skipping:
		await Game.main.talk.run(level.lines(String(d["arrive_talk"])), true)
	playing = false


# --- moves --------------------------------------------------------------------------------

## Run a tween to its end, or straight to its end once skipping.
func _play(t: Tween) -> void:
	_tween = t
	while t.is_valid() and t.is_running() and not skipping:
		await get_tree().physics_frame
	if t.is_valid() and t.is_running():
		t.custom_step(60.0)


## Move the raft from a to b, carrying the riders.
func _glide(a: Transform3D, b: Transform3D, time: float, ease_type: Tween.EaseType, riders: Array) -> Tween:
	var t := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	t.tween_method(func(k: float) -> void:
		raft.global_transform = a.interpolate_with(b, k)
		for r: Variant in riders:
			_carry(r as Node3D, ORIMI_SPOT if r == level.player else PELL_SPOT)
		, 0.0, 1.0, time)
	return t


## Put a rider on the deck spot (facing the bow).
func _carry(n: Node3D, spot: Vector3) -> void:
	if n == null:
		return
	var at := raft.global_transform * spot
	var yaw := raft.global_rotation.y
	if n is OrimiPlayer:
		(n as OrimiPlayer).teleport(at, yaw)
	else:
		n.global_position = at
		n.global_rotation = Vector3(0, yaw + PI, 0)


## Orimi hops from a to b in a short arc.
func _hop(p: OrimiPlayer, a: Vector3, b: Vector3, face: Vector3) -> void:
	var yaw := atan2(-face.x, -face.z)
	p.animator.play(&"jump", true)
	Audio.play_sfx(&"jump", a)
	var t := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_method(func(k: float) -> void:
		p.teleport(a.lerp(b, k) + Vector3.UP * 4.0 * 0.6 * k * (1.0 - k), yaw)
		, 0.0, 1.0, HOP_TIME)
	await _play(t)
	p.teleport(b + Vector3.UP * 0.02, yaw)
	Audio.play_sfx(&"land", b)


# --- setting up ---------------------------------------------------------------------------

## The mooring: a marker name (its position and turn), a point [x, y, z] with "<key>_yaw"
## degrees, or the fallback node. The height is the water's ("water", else the point's).
func _place(d: Dictionary, key: String, fallback: Node3D) -> Transform3D:
	var v: Variant = d.get(key)
	var at := fallback.global_position if fallback != null else level.player.global_position
	var yaw := fallback.global_rotation.y if fallback != null else 0.0
	if v is Array and (v as Array).size() >= 3:
		at = Vector3(float(v[0]), float(v[1]), float(v[2]))
	elif v is String:
		var n := level.node(String(v)) as Node3D
		if n != null:
			at = n.global_position
			yaw = n.global_rotation.y
		else:
			at = level.marker(String(v))
	if d.has(key + "_yaw"):
		yaw = deg_to_rad(float(d[key + "_yaw"]))
	_water = float(d.get("water", at.y))
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, _water, at.z))


## A ground point from a marker name or [x, y, z], else the fallback.
func _point(d: Dictionary, key: String, fallback: Vector3) -> Vector3:
	var v: Variant = d.get(key)
	var at := fallback
	if v is Array and (v as Array).size() >= 3:
		at = Vector3(float(v[0]), float(v[1]), float(v[2]))
	elif v is String:
		at = level.marker(String(v))
	return level.ground_at(at + Vector3.UP * 1.5)


func _new_raft() -> Node3D:
	var r := ModelKit.load_model("raft", func() -> Node3D: return Node3D.new())
	r.name = "PellsRaft"
	level.add_child(r)
	return r


## The level's own Pell when he is about, else a new one who stays with the raft.
func _find_pell() -> Node3D:
	var own := level.node("Pell") as Node3D
	if own != null and own.is_visible_in_tree():
		return own
	var p := Person.new()
	p.name = "RaftPell"
	p.display_name = "Pell"
	p.model_name = "folk/pell"
	p.hat = "paper"
	p.robe_color = Palette.RIVER_DEEP
	p.talk_id = "pell"
	level.add_child(p)
	return p


func _colliders(n: Node, on: bool) -> void:
	for b: Node in n.find_children("*", "CollisionObject3D", true, false):
		var c := b as CollisionObject3D
		if not c.has_meta(&"raft_layer"):
			c.set_meta(&"raft_layer", c.collision_layer)
		c.collision_layer = int(c.get_meta(&"raft_layer")) if on else 0


## Frame the raft (with Pell) at the mooring and Orimi on the bank. The camera stands behind the
## bank to one side, lifted clear of the ground under it, with a clear line to the raft, Pell and
## Orimi; if no such spot is clear it tries the river side and pulls back along the river, then
## settles for the first spot that at least sees the raft, and last of all looks down from high
## above. Every level's bank is different, so nothing here trusts the data's heights.
func _frame(moor_xf: Transform3D, bank: Vector3, blend: float = 0.6) -> void:
	var cam := level.camera
	var moor := moor_xf.origin
	var out := _flat(bank - moor)
	out = out.normalized() if out.length() > 0.1 else Vector3.BACK
	var side := out.cross(Vector3.UP)
	var river := _flat(-moor_xf.basis.z)
	river = river.normalized() if river.length() > 0.1 else side
	var look := _flat(moor + bank) * 0.5 + Vector3.UP * (moor.y + 0.7)
	var spots: Array[Vector3] = [
		bank + out * 4.5 + side * 2.0 + Vector3.UP * 2.6,
		bank + out * 4.5 - side * 2.0 + Vector3.UP * 2.6,
		moor - out * 6.0 + side * 2.5 + Vector3.UP * 2.4,
		moor - out * 6.0 - side * 2.5 + Vector3.UP * 2.4,
		moor - river * 7.0 + out * 2.5 + Vector3.UP * 2.4,
		moor + river * 7.0 + out * 2.5 + Vector3.UP * 2.4,
		bank + out * 8.0 + Vector3.UP * 4.5,
		moor - river * 10.0 + Vector3.UP * 3.5,
	]
	var raft_at := moor + Vector3.UP * 0.9
	var pick := _lift(look + Vector3.UP * 6.0 + out * 5.0)
	var why := "high"
	var raft_only := -1
	var refused: Array[String] = []
	for i in spots.size():
		var at := _lift(spots[i])
		var miss := _sees(at, [raft_at, look, bank + Vector3.UP * 0.5])
		if miss == "":
			pick = at
			why = str(i)
			break
		refused.append("%d:%s" % [i, miss])
		if raft_only < 0 and _sees(at, [raft_at]) == "":
			raft_only = i
	if why == "high" and raft_only >= 0:
		pick = _lift(spots[raft_only])
		why = "%d raft only" % raft_only
	Game.qa_log("raft_camera", {"spot": why, "at": Game._v(pick), "refused": refused})
	cam.cinematic_to(pick, look, blend)
	if blend <= 0.0:
		cam.global_transform = Transform3D(Basis.IDENTITY, pick).looking_at(look, Vector3.UP)


## A camera spot raised to stand at least 1.6 m over the ground and 1.5 m over the water under it.
func _lift(at: Vector3) -> Vector3:
	var ground := level.ground_at(at)
	at.y = maxf(at.y, maxf(ground.y + 1.6, _water + 1.5))
	return at


## "" when the camera at "from" is in open air and sees every point (the raft's own colliders are
## off while it travels); otherwise what is in the way.
func _sees(from: Vector3, points: Array) -> String:
	var space := level.get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.4
	probe.shape = ball
	probe.transform = Transform3D(Basis.IDENTITY, from)
	probe.collision_mask = Layers.WORLD
	var inside := space.intersect_shape(probe, 1)
	if not inside.is_empty():
		return "in %s" % (inside[0]["collider"] as Node).name
	for p: Vector3 in points:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, p, Layers.WORLD))
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(p) > 0.6:
			return "%s blocks" % (hit["collider"] as Node).name
	return ""


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _emit(stage: String) -> void:
	Game.qa_log("raft_moment", {"stage": stage, "level": String(level.level_id)})
	moment.emit(stage)
