class_name SealedFight
extends Node3D
## A sealed fight. A drifting knot of black cord marks a pack; when Orimi touches it a ring of
## ink wash and standing torn-paper screens rises round the circle, the EnemySpawn children
## rise in waves, and Orimi cannot leave the ring until every enemy in it has fallen apart.
## Then the ring sinks, the reward is paid and done_flag is set. If Orimi falls in the ring,
## the fight resets and the knot comes back. Owner: gameplay.

## The ring has risen and the first wave is up.
signal fight_started
## Every enemy is gone; rewards have been paid and done_flag is set.
signal fight_won

const TOUCH_RADIUS := 1.3
const RING_HEIGHT := 1.6
const RISE_TIME := 0.7
const SCREENS := 10
const KEEP_IN := 0.5
const SCREEN_PAPER := Color("968b74")

## Unique in the level; used for the default flag and QA lines.
@export var fight_id: StringName = &"fight"
## The ring's radius in metres (the circle is about 10 m across by default).
@export var radius: float = 5.0
## Flags that must be set before the knot appears.
@export var requires_flags: PackedStringArray = PackedStringArray()
## Set when the fight is won. Empty: "fight_<fight_id>".
@export var done_flag: StringName = &""
## No knot: the fight starts when this flag is set (a scripted ambush).
@export var start_flag: StringName = &""
## Ink added to the pot when the fight is won.
@export var reward_ink: float = 30.0
@export var heal_on_win: bool = true
@export var checkpoint_on_win: bool = true
## How far the knot wanders from the centre.
@export var knot_drift: float = 1.5

var enemies: Array[Node] = []
var started := false
var done := false
var player_inside := false
var wave_index := -1
var knot: Node3D
var ring: Node3D
var _waves: Array = []
var _held: Array[EnemyBase] = []
var _t := 0.0


func _ready() -> void:
	add_to_group(&"sealed_fight")
	if done_flag == &"":
		done_flag = StringName("fight_" + String(fight_id))
	var by_wave := {}
	for c: Node in find_children("*", "", true, false):
		if c is EnemySpawn:
			var w: int = maxi((c as EnemySpawn).wave, 0)
			if not by_wave.has(w):
				by_wave[w] = []
			by_wave[w].append(c)
		elif c is EnemyBase:
			# Placed enemies wait, hidden and still, until the ring rises.
			var e := c as EnemyBase
			e.process_mode = Node.PROCESS_MODE_DISABLED
			e.visible = false
			_held.append(e)
	var keys := by_wave.keys()
	keys.sort()
	for k: int in keys:
		_waves.append(by_wave[k])
	if start_flag == &"":
		_make_knot()
	_make_ring()
	_settle.call_deferred()


func _settle() -> void:
	# A warp (or a level script) that sets done_flag finds the fight already won.
	if Game.level != null:
		Game.level.flag_changed.connect(func(f: StringName, value: bool) -> void:
			if value and f == done_flag and not done and not started:
				_finish_silently())
		if Game.level.get_flag(done_flag):
			_finish_silently()
	await get_tree().physics_frame
	if Game.level != null:
		await Game.level.ready_to_settle()
		ring.global_position = Game.level.ground_at(global_position + Vector3.UP * 2.0) - Vector3.UP * 0.15


## Where the knot is now (the centre when the fight has no knot).
func knot_position() -> Vector3:
	return knot.global_position if knot != null else global_position


func _physics_process(delta: float) -> void:
	if done:
		return
	_t += delta
	var p := Game.player
	if not started:
		var ready := Game.level == null or Game.level.all_flags(Array(requires_flags))
		if knot != null:
			knot.visible = ready
			knot.position = Vector3(sin(_t * 0.37) * knot_drift, 1.1 + sin(_t * 1.7) * 0.15, cos(_t * 0.29) * knot_drift)
			knot.rotation = Vector3(_t * 0.9, _t * 1.3, _t * 0.5)
		if not ready or not is_instance_valid(p) or not Game.is_playing():
			return
		if start_flag != &"" and Game.level != null and Game.level.get_flag(start_flag):
			start()
		elif knot != null:
			var off := p.global_position - knot.global_position
			if Vector2(off.x, off.z).length() < TOUCH_RADIUS and absf(off.y) < 2.5:
				start()
		return
	if not is_instance_valid(p):
		return
	if p.get(&"dead"):
		_reset()
		return
	_keep_in(p)
	if _remaining() == 0:
		if wave_index + 1 < _waves.size():
			_spawn_wave(wave_index + 1)
		else:
			_win()


## Enemies not yet fallen apart. Unravelling ones still count, so the ring stays up for the
## finishing stroke.
func _remaining() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not (e as EnemyBase).dying:
			n += 1
	return n


func _keep_in(p: OrimiPlayer) -> void:
	var off := p.global_position - global_position
	off.y = 0.0
	var limit := radius - KEEP_IN
	player_inside = off.length() < radius
	if off.length() <= limit:
		return
	var out := off.normalized()
	p.global_position = Vector3(global_position.x, p.global_position.y, global_position.z) + out * limit
	var v := p.velocity
	var along := Vector3(v.x, 0.0, v.z).dot(out)
	if along > 0.0:
		p.velocity -= out * along


## Raise the ring and the first wave.
func start() -> void:
	if started or done:
		return
	started = true
	player_inside = true
	Game.qa_log("fight_started", {"fight": String(fight_id), "waves": _waves.size()})
	if knot != null:
		var kt := create_tween()
		kt.tween_property(knot, "scale", Vector3.ONE * 0.05, 0.3)
		kt.tween_callback(func() -> void: knot.visible = false)
	ring.visible = true
	ring.scale = Vector3(1.0, 0.02, 1.0)
	create_tween().tween_property(ring, "scale", Vector3.ONE, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Vfx.ink_splash(global_position + Vector3.UP * 0.3, 2.0)
	for e in _held:
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_INHERIT
			e.visible = true
			e.aggro = true
			_add_enemy(e)
	_held.clear()
	if not _waves.is_empty():
		_spawn_wave(0)
	Game.hint(&"sealed")
	fight_started.emit()


func _spawn_wave(index: int) -> void:
	wave_index = index
	Game.qa_log("wave", {"fight": String(fight_id), "wave": index + 1, "of": _waves.size()})
	for s: EnemySpawn in _waves[index]:
		var e := s.spawn(get_parent(), true)
		_add_enemy(e)
		Vfx.ink_splash(e.global_position, 1.2)


func _add_enemy(e: EnemyBase) -> void:
	if e == null or e in enemies:
		return
	e.zone = self
	# Held inside the ring and on its ground, so none can sit out of reach.
	e.confine_center = global_position
	e.confine_radius = radius - KEEP_IN
	enemies.append(e)


func _win() -> void:
	done = true
	Game.qa_log("fight_won", {"fight": String(fight_id)})
	var t := create_tween()
	t.tween_property(ring, "scale", Vector3(1.0, 0.02, 1.0), RISE_TIME * 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: ring.visible = false)
	Vfx.petal_burst(global_position + Vector3.UP * 0.6, radius)
	if reward_ink > 0.0:
		Brush.add_ink(reward_ink)
	var p := Game.player
	if is_instance_valid(p):
		if heal_on_win and p.has_method("heal_full"):
			p.heal_full()
		if checkpoint_on_win and Game.level != null:
			Game.checkpoint = Game.level.ground_at(p.global_position)
	if Game.level != null:
		Game.level.set_flag(done_flag)
	fight_won.emit()


## Won some other way (a warp): no knot, no ring, no enemies, no rewards.
func _finish_silently() -> void:
	done = true
	for e in _held:
		if is_instance_valid(e):
			e.queue_free()
	_held.clear()
	if knot != null:
		knot.visible = false
	ring.visible = false
	Game.qa_log("fight_already_won", {"fight": String(fight_id)})


## Orimi fell inside the ring: clear it and put the knot back.
func _reset() -> void:
	Game.qa_log("fight_reset", {"fight": String(fight_id)})
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	started = false
	wave_index = -1
	player_inside = false
	ring.visible = false
	if knot != null:
		knot.scale = Vector3.ONE
		knot.visible = true
	elif start_flag != &"" and Game.level != null:
		Game.level.set_flag(start_flag, false)


# --- looks --------------------------------------------------------------------------------

func _make_knot() -> void:
	knot = Node3D.new()
	knot.name = "Knot"
	add_child(knot)
	ModelKit.part(knot, "LoopA", ModelKit.torus(0.22, 0.32), Palette.CURSE_INK)
	ModelKit.part(knot, "LoopB", ModelKit.torus(0.2, 0.3), Palette.CURSE_INK, Vector3.ZERO, Vector3(90, 0, 0))
	ModelKit.part(knot, "LoopC", ModelKit.torus(0.18, 0.27), Palette.INK_SOFT, Vector3.ZERO, Vector3(0, 0, 90))
	for i in 3:
		var a := TAU * i / 3.0
		ModelKit.part(knot, "Tail%d" % i, ModelKit.cylinder(0.03, 0.05, 0.7, 5), Palette.CURSE_INK,
			Vector3(cos(a) * 0.35, -0.35, sin(a) * 0.35), Vector3(30.0 * cos(a), 0, 30.0 * sin(a)))
	ModelKit.add_ink_look(knot, &"", false, 0.8)


func _make_ring() -> void:
	ring = Node3D.new()
	ring.name = "Ring"
	ring.visible = false
	add_child(ring)
	var wash := CylinderMesh.new()
	wash.top_radius = radius
	wash.bottom_radius = radius
	wash.height = RING_HEIGHT
	wash.cap_top = false
	wash.cap_bottom = false
	wash.radial_segments = 32
	# Faint: the VFX ring (fight_ring_rise) carries the moment; this only marks the edge.
	ModelKit.part(ring, "Wash", wash, Palette.CURSE_INK, Vector3.UP * RING_HEIGHT * 0.5, Vector3.ZERO, Vector3.ONE, 0.2)
	var screens := Node3D.new()
	screens.name = "Screens"
	ring.add_child(screens)
	for i in SCREENS:
		var a := TAU * (i + 0.5) / SCREENS
		var h := 1.7 + 0.35 * float((i * 7) % 3)
		# Each screen fades on its own when it hides Orimi from the camera (group camera_fade,
		# with a body on the camera's fade layer so the camera's ray can find it).
		var holder := ModelKit.node(screens, "Screen%d" % i, Vector3(cos(a), 0.0, sin(a)) * (radius + 0.2))
		holder.rotation_degrees = Vector3(0, -rad_to_deg(a) + 90.0, (i % 3 - 1) * 4.0)
		holder.add_to_group(GameCamera.FADE_GROUP)
		var s := ModelKit.part(holder, "Paper", ModelKit.box(Vector3(1.0, h, 0.04)), SCREEN_PAPER, Vector3.UP * h * 0.5)
		ModelKit.part(s, "Stroke", ModelKit.box(Vector3(0.12, h * 0.7, 0.05)), Palette.INK, Vector3(-0.2 + 0.1 * (i % 4), -0.05, 0.0))
		var body := StaticBody3D.new()
		body.collision_layer = GameCamera.FADE_LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, h, 0.1)
		cs.shape = box
		cs.position = Vector3.UP * h * 0.5
		body.add_child(cs)
		holder.add_child(body)
		ModelKit.add_ink_look(holder, &"", false, 0.8)
