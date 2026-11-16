class_name EnemyBase
extends CharacterBody3D
## Shared enemy body: health, hits, knockback, the death dissolve, stepped animation,
## interpolated visuals and an attack hitbox on the enemy_hit layer. Owner: gameplay.

const GRAVITY := 22.0
## At most this many enemies wind up or strike at the same time, so swarms stay fair.
const MAX_ATTACKERS := 2
const DISSOLVE_TIME := 0.75
## The finishing stroke: an enemy at zero health unravels this long before it falls apart; a
## Slash through it meanwhile is a clean cut (extra ink and a burst of petals).
const UNRAVEL_TIME := 1.5
const CLEAN_CUT_INK := 25.0

## At zero health: the unravel starts (duration seconds until it falls apart unless cut).
signal unravel_started(duration: float)

static var attackers: int = 0

var kind: StringName = &""
var max_hp := 2.0
var hp := 2.0
## The CursedZone this enemy belongs to (may be null).
var zone: Node = null
var aggro := false
var aggro_range := 12.0
var leash_range := 26.0
var dying := false
## At zero health and unravelling: no longer a threat, still open to a finishing Slash.
var unraveling := false
var stun := 0.0
var home := Vector3.ZERO
## Held within confine_radius (across the ground) of confine_center, and not let down off the
## ground there (a SealedFight's ring sets this). INF: free.
var confine_center := Vector3.ZERO
var confine_radius := INF
## It ignores Orimi while she is more than territory_radius (across the ground) from
## territory_center (EnemySpawn.territory_radius sets this). INF: no limit.
var territory_center := Vector3.ZERO
var territory_radius := INF

var model: Node3D
var visual: Node3D
var animator: SteppedAnimator
var look: InkLook
var hitbox: Area3D

var _facing := 0.0
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO
var _holds_attack_token := false
var _hit_player_this_strike := false


func _model_name() -> String:
	return ""


func _build_placeholder() -> Node3D:
	return Node3D.new()


func _collision_size() -> Vector2:
	return Vector2(0.35, 0.7)


func _ready() -> void:
	add_to_group(Layers.GROUP_ENEMY)
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3
	var size := _collision_size()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = size.x
	capsule.height = maxf(size.y, size.x * 2.0)
	shape.shape = capsule
	shape.position = Vector3(0, capsule.height * 0.5, 0)
	add_child(shape)

	visual = Node3D.new()
	visual.name = "Visual"
	visual.top_level = true
	add_child(visual)
	model = ModelKit.load_model(_model_name(), _build_placeholder)
	visual.add_child(model)
	look = ModelKit.ink_look(model)
	animator = SteppedAnimator.new()
	add_child(animator)
	animator.setup(model)
	animator.play(&"idle")

	GroundShadow.attach(self, Vector2(size.x * 2.4, size.x * 2.4), visual)

	hitbox = Area3D.new()
	hitbox.name = "AttackHitbox"
	hitbox.collision_layer = Layers.ENEMY_HIT
	hitbox.collision_mask = Layers.PLAYER
	var hs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _strike_radius()
	hs.shape = sphere
	hs.position = Vector3(0, 0.45, -0.35)
	hitbox.add_child(hs)
	add_child(hitbox)

	home = global_position
	_facing = rotation.y
	_prev_pos = global_position
	_cur_pos = global_position
	visual.global_position = global_position


func _strike_radius() -> float:
	return 0.7


## World point the brush tests strokes against.
func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * 0.6


func glyph_radius() -> float:
	return 0.8


## Brush protocol. Handles the finishing stroke, then hands everything else to _on_glyph.
func on_glyph(glyph: StringName, info: Dictionary) -> bool:
	if dying:
		return false
	if unraveling:
		if glyph != &"slash":
			return false
		_clean_cut()
		return true
	return _on_glyph(glyph, info)


## Override in an enemy for its reactions to glyphs. Return true when the glyph did something.
func _on_glyph(_glyph: StringName, _info: Dictionary) -> bool:
	return false


## Defeated: dying, or unravelling at zero health. Zones and fights count only the others.
func is_defeated() -> bool:
	return dying or unraveling


## Put the enemy at a point without visual interpolation (spawning, scripted moves).
func place(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	home = at
	_prev_pos = at
	_cur_pos = at
	if visual != null:
		visual.global_position = at


func player_target() -> CharacterBody3D:
	var p := Game.player
	if not is_instance_valid(p) or not Game.is_playing() or p.get(&"dead"):
		return null
	return p


func flat_to(point: Vector3) -> Vector3:
	var v := point - global_position
	v.y = 0.0
	return v


func face(dir: Vector3, delta: float, rate: float = 10.0) -> void:
	if dir.length() < 0.01:
		return
	_facing = lerp_angle(_facing, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))
	rotation.y = _facing


## Hit by a melee swipe or a slash. Returns true if it did damage.
func take_hit(damage: float, from: Vector3, source: StringName = &"swipe", knock: float = 4.0) -> bool:
	if dying or unraveling:
		return false
	if not _can_be_hurt(source):
		_on_blocked(source)
		return false
	hp -= damage
	aggro = true
	Events.enemy_hit.emit(self, damage, global_position + Vector3.UP * 0.5)
	if look != null:
		look.flash(Color.WHITE, 0.1)
	var away := flat_to(global_position * 2.0 - from)
	away = away.normalized() if away.length() > 0.01 else -global_basis.z
	velocity = away * _ledge_safe_speed(away, knock) + Vector3.UP * 3.0
	stun = 0.4
	_release_attack_token()
	animator.play(&"hurt", true)
	if hp <= 0.0:
		_unravel()
	return true


func _unravel() -> void:
	if unraveling or dying:
		return
	unraveling = true
	aggro = false
	unravel_started.emit(UNRAVEL_TIME)
	_release_attack_token()
	Game.qa_log("enemy_unravel", {"kind": String(kind), "at": Game._v(global_position)})
	var has_anim := animator != null and animator.has(&"unravel")
	if has_anim:
		animator.play(&"unravel", true)
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		var step := floorf(k * UNRAVEL_TIME * 12.0) / (UNRAVEL_TIME * 12.0)
		if look != null:
			look.set_dissolve(step * 0.35)
		if not has_anim and visual != null and is_instance_valid(model):
			model.rotation.z = sin(step * 40.0) * 0.12
		, 0.0, 1.0, UNRAVEL_TIME)
	await get_tree().create_timer(UNRAVEL_TIME, false).timeout
	if not dying:
		die()


func _clean_cut() -> void:
	Game.qa_log("finishing_stroke", {"kind": String(kind), "at": Game._v(global_position)})
	Brush.add_ink(CLEAN_CUT_INK)
	Vfx.petal_burst(global_position + Vector3.UP * 0.5, 2.5)
	if look != null:
		look.flash(Palette.PETAL, 0.2)
	Game.enemy_finished.emit(self)
	die()


func _can_be_hurt(_source: StringName) -> bool:
	return true


func _on_blocked(_source: StringName) -> void:
	pass


func knock_back(dir: Vector3, strength: float, stun_time: float) -> void:
	dir.y = 0.0
	dir = dir.normalized()
	if keeps_to_ground():
		velocity = dir * _ledge_safe_speed(dir, strength) + Vector3.UP * strength * 0.45
	else:
		velocity = dir * strength
	stun = maxf(stun, stun_time)
	_release_attack_token()
	animator.play(&"hurt", true)


# --- movement hooks: a flying enemy (Level 4's Sootflit) overrides these three -----------------

## Vertical motion each physics frame (stunned or not). Default: fall when off the floor. A flyer
## holds its height here instead.
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


## True for a ground enemy: it stops at ledges and steep drops, and knockback pops it up but never
## throws it off the ledge its zone stands on. A flyer returns false (knockback is flat).
func keeps_to_ground() -> bool:
	return true


## Height above the ground EnemySpawn puts it at.
func spawn_height() -> float:
	return 0.1


## True when moving along h heads down a slope steeper than about 40 degrees or off a ledge:
## enemies keep to the ground their zone stands on.
func _drop_ahead(h: Vector3) -> bool:
	if h.length() < 0.05:
		return false
	var here := _ground_y(global_position)
	if is_nan(here):
		return false
	var ahead := _ground_y(global_position + h.normalized() * 0.7)
	return is_nan(ahead) or here - ahead > 0.6


func _ground_y(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 3.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else NAN


## Knockback speed cut so the slide (decelerating at 10 m/s²) stops short of any drop over
## 1.2 m: a hit never throws an enemy off the ledge its zone stands on.
func _ledge_safe_speed(dir: Vector3, speed: float) -> float:
	if not is_inside_tree() or speed <= 0.0:
		return speed
	var space := get_world_3d().direct_space_state
	var travel := speed * speed / 20.0
	var safe := travel
	var d := 0.4
	while d <= travel + 0.6:
		var p := global_position + dir * d
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 1.2, Layers.WORLD)
		if space.intersect_ray(q).is_empty():
			safe = maxf(d - 0.9, 0.0)
			break
		d += 0.4
	return speed if safe >= travel else sqrt(20.0 * safe)


func die() -> void:
	if dying:
		return
	dying = true
	_release_attack_token()
	remove_from_group(Layers.GROUP_ENEMY)
	collision_layer = 0
	hitbox.set_deferred(&"monitoring", false)
	Events.enemy_died.emit(self, kind, global_position)
	var placeholder: bool = model.get_meta(&"placeholder", false)
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		var step := floorf(k * DISSOLVE_TIME * 12.0) / (DISSOLVE_TIME * 12.0)
		if look != null:
			look.set_dissolve(step)
		if placeholder:
			model.scale = Vector3(1.0 + step * 0.6, maxf(1.0 - step, 0.05), 1.0 + step * 0.6)
		, 0.0, 1.0, DISSOLVE_TIME)
	t.tween_callback(queue_free)


func _take_attack_token() -> bool:
	if _holds_attack_token:
		return true
	if attackers >= MAX_ATTACKERS:
		return false
	attackers += 1
	_holds_attack_token = true
	return true


func _release_attack_token() -> void:
	if _holds_attack_token:
		attackers = maxi(attackers - 1, 0)
		_holds_attack_token = false


func _exit_tree() -> void:
	_release_attack_token()


## Deal damage to the player if the strike hitbox touches them (once per strike).
func _strike() -> void:
	if _hit_player_this_strike:
		return
	for body in hitbox.get_overlapping_bodies():
		if body == Game.player and body.has_method("take_damage"):
			_hit_player_this_strike = true
			body.take_damage(1, global_position)
			return


func _physics_process(delta: float) -> void:
	_prev_pos = _cur_pos
	if dying:
		_cur_pos = global_position
		return
	stun = maxf(stun - delta, 0.0)
	if unraveling:
		stun = maxf(stun, 0.1)
	_apply_gravity(delta)
	if stun > 0.0:
		var h := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = h.x
		velocity.z = h.z
	else:
		_update_aggro()
		_think(delta)
	_separate(delta)
	if keeps_to_ground() and _drop_ahead(Vector3(velocity.x, 0, velocity.z)):
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	if confine_radius < INF:
		_hold_in()
	_cur_pos = global_position
	if global_position.y < -25.0:
		die()


## Keep to the confine circle: back to its edge, and back up onto its ground if it got down a
## slope or a drop (a flyer keeps its own height).
func _hold_in() -> void:
	var off := global_position - confine_center
	off.y = 0.0
	var out := off.normalized() if off.length() > 0.01 else Vector3.ZERO
	if off.length() > confine_radius:
		global_position = Vector3(confine_center.x, global_position.y, confine_center.z) + out * confine_radius
		var along := Vector3(velocity.x, 0.0, velocity.z).dot(out)
		if along > 0.0:
			velocity -= out * along
	if keeps_to_ground() and global_position.y < confine_center.y - 1.5:
		var back := Vector3(confine_center.x, confine_center.y, confine_center.z) + out * minf(off.length(), confine_radius) * 0.6
		var g := _ground_y(back + Vector3.UP * 1.0)
		global_position = Vector3(back.x, (g if not is_nan(g) else confine_center.y) + 0.1, back.z)
		velocity = Vector3.ZERO
		Game.qa_log("enemy_held", {"enemy": String(name), "to": Game._v(global_position)})


func _update_aggro() -> void:
	var p := player_target()
	if p == null:
		aggro = false
		return
	var d := global_position.distance_to(p.global_position)
	if territory_radius < INF and Vector2(p.global_position.x - territory_center.x, p.global_position.z - territory_center.z).length() > territory_radius:
		aggro = false
		return
	if zone != null:
		var from_zone := Vector2(global_position.x - zone.global_position.x, global_position.z - zone.global_position.z).length()
		if from_zone > zone.radius + 3.0 and p.global_position.distance_to(zone.global_position) > zone.radius:
			# Ink-spawn stay near the ink that made them; out past the edge they go home.
			aggro = false
			return
	if not aggro and (d < aggro_range or (zone != null and zone.get(&"player_inside") and d < aggro_range * 1.6)):
		aggro = true
	elif aggro and d > leash_range:
		aggro = false


func _think(_delta: float) -> void:
	pass


func _separate(delta: float) -> void:
	for other: Node in get_tree().get_nodes_in_group(Layers.GROUP_ENEMY):
		if other == self:
			continue
		var o := other as Node3D
		var d := flat_to(o.global_position)
		var dist := d.length()
		if dist < 1.1 and dist > 0.001:
			var push := -d.normalized() * (1.1 - dist) * 6.0 * delta
			global_position += push


func _process(_delta: float) -> void:
	var f := Engine.get_physics_interpolation_fraction()
	visual.global_position = _prev_pos.lerp(_cur_pos, f)
	visual.global_rotation = Vector3(0, _facing, 0)
