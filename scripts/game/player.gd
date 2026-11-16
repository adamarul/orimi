class_name OrimiPlayer
extends CharacterBody3D
## Orimi, the paper fox. Camera-relative movement, coyote-time jump, a two-hit tail-swipe
## combo, 5 health with brief invulnerability, death and respawn. Owner: gameplay.

const RUN_SPEED := 6.4
const ACCEL := 40.0
const AIR_ACCEL := 16.0
const DECEL := 48.0
const AIR_DECEL := 6.0
const TURN_RATE := 16.0
const GRAVITY := 23.0
const FALL_GRAVITY := 34.0
const MAX_FALL := 22.0
const JUMP_VELOCITY := 8.2
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
const MAX_HP := 5
const INVULN_TIME := 1.1
const HURT_STUN := 0.3
const RESPAWN_DELAY := 1.6
const ASSIST_RANGE := 3.6
const ASSIST_ANGLE := 1.2

## Per attack: frames on the 12 fps grid, active frames [first, last], damage, knockback,
## forward lunge (m/s), combo window start frame.
var ATTACKS := {
	&"attack_1": {"frames": 6, "active": [2, 3], "damage": 1.0, "knock": 4.5, "lunge": 3.5, "combo_from": 2},
	&"attack_2": {"frames": 7, "active": [2, 4], "damage": 1.0, "knock": 9.0, "lunge": 4.5, "combo_from": 99},
}
const COMBO_GRACE := 0.16
const ATTACK_COOLDOWN := 0.18

var hp: int = MAX_HP
var max_hp: int = MAX_HP
var dead := false
## False while cards, cutscenes or the finale own the player.
var control_enabled := true
## The GameCamera this player moves relative to.
var camera: Node3D

## Autoplay drives the player through these instead of the input map.
var ai_enabled := false
var ai_move := Vector3.ZERO
var ai_jump := false
## Seconds the AI keeps the jump button held after ai_jump (a full-height jump needs about 0.35).
var ai_jump_hold := 0.0
var ai_attack := false

var model: Node3D
var visual: Node3D
var animator: SteppedAnimator
var hitbox: Area3D

var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_held := false
var _air_time := 0.0
var _land_timer := 0.0
var _hurt_timer := 0.0
var _hold_timer := 0.0
var _invuln := 0.0
var _attack: StringName = &""
var _attack_time := 0.0
var _attack_queued := false
var _attack_cooldown := 0.0
var _hit_this_swing: Array[Node] = []
var _footstep := 0.0
var _attack_input := false
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO
var _facing := 0.0


func _ready() -> void:
	add_to_group(Layers.GROUP_PLAYER)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.35
	safe_margin = 0.02
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 0.9
	shape.shape = capsule
	shape.position = Vector3(0, 0.45, 0)
	add_child(shape)

	visual = Node3D.new()
	visual.name = "Visual"
	visual.top_level = true
	add_child(visual)
	model = ModelKit.load_model("fox", ModelKit.fox)
	visual.add_child(model)
	animator = SteppedAnimator.new()
	animator.name = "SteppedAnimator"
	add_child(animator)
	animator.setup(model)
	animator.play(&"idle")

	GroundShadow.attach(self, Vector2(0.62, 1.15), visual)
	var look := ModelKit.ink_look(model)
	if look != null and not model.get_meta(&"placeholder", false):
		# Orimi keeps its own colour inside cursed ground, and takes the softer character line.
		look.cursable = false
		if &"line_style" in look:
			look.set(&"line_style", &"character")
		look.apply()
	_read_attack_timing()

	hitbox = Area3D.new()
	hitbox.name = "TailHitbox"
	hitbox.collision_layer = Layers.PLAYER_HIT
	hitbox.collision_mask = Layers.ENEMY
	hitbox.monitorable = true
	var hs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.45
	hs.shape = sphere
	hs.position = Vector3(0, 0.5, -0.25)
	hitbox.add_child(hs)
	add_child(hitbox)

	Events.brush_opened.connect(_on_brush_opened)
	_facing = rotation.y
	teleport(global_position)


## Put the player somewhere without interpolation or leftover motion.
func teleport(at: Vector3, yaw: float = NAN) -> void:
	global_position = at
	velocity = Vector3.ZERO
	if not is_nan(yaw):
		_facing = yaw
		rotation.y = yaw
	_prev_pos = at
	_cur_pos = at
	if visual != null:
		visual.global_position = at
		visual.global_rotation = Vector3(0, _facing, 0)


## Take each attack's length and hit frames from the model's animation: the frames where the
## Smear node is keyed visible are the frames the tail is sweeping, so they are the hit frames.
func _read_attack_timing() -> void:
	var ap := animator.player
	if ap == null:
		return
	for attack: StringName in ATTACKS:
		if not ap.has_animation(attack):
			continue
		var anim := ap.get_animation(attack)
		var spec: Dictionary = ATTACKS[attack]
		spec["frames"] = maxi(3, roundi(anim.length * 12.0))
		for t in anim.get_track_count():
			if not String(anim.track_get_path(t)).ends_with("Smear:visible"):
				continue
			var first := -1
			var last := -1
			for k in anim.track_get_key_count(t):
				var f := roundi(anim.track_get_key_time(t, k) * 12.0)
				if anim.track_get_key_value(t, k):
					first = f if first < 0 else mini(first, f)
					last = maxi(last, f)
				elif first >= 0 and f > last:
					last = maxi(last, f - 1)
			if first >= 0:
				spec["active"] = [first, maxi(first, last)]
				spec["combo_from"] = first if attack == &"attack_1" else 99
	Game.qa_log("attack_timing", {"attack_1": ATTACKS[&"attack_1"], "attack_2": ATTACKS[&"attack_2"]})


func is_attacking() -> bool:
	return _attack != &""


func is_invulnerable() -> bool:
	return _invuln > 0.0 or dead or Game.god_mode


func _physics_process(delta: float) -> void:
	_prev_pos = _cur_pos
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL)
		move_and_slide()
		_cur_pos = global_position
		return

	_invuln = maxf(_invuln - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	_hold_timer = maxf(_hold_timer - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_land_timer = maxf(_land_timer - delta, 0.0)
	var can_act := control_enabled and Game.is_playing() and _hurt_timer <= 0.0 and _hold_timer <= 0.0
	var attack_input := _attack_input
	_attack_input = false

	# --- input
	var move := Vector3.ZERO
	var jump_pressed := false
	var attack_pressed := false
	if can_act:
		if ai_enabled:
			move = Vector3(ai_move.x, 0, ai_move.z).limit_length(1.0)
			jump_pressed = ai_jump
			_jump_held = ai_jump or ai_jump_hold > 0.0
			ai_jump_hold = maxf(ai_jump_hold - delta, 0.0)
			attack_pressed = ai_attack
			ai_jump = false
			ai_attack = false
		else:
			var v := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
			move = _camera_relative(v)
			jump_pressed = Input.is_action_just_pressed(&"jump")
			_jump_held = Input.is_action_pressed(&"jump")
			attack_pressed = attack_input
	else:
		_jump_held = false

	# --- jump with coyote time and buffering
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = JUMP_BUFFER if jump_pressed else maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0 and not is_attacking():
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		Audio.play_sfx(&"jump", global_position)
		animator.play(&"jump", true)
	if not _jump_held and velocity.y > 0.0 and not is_on_floor():
		velocity.y *= pow(JUMP_CUT, delta * 20.0)

	# --- attacks
	if attack_pressed:
		if is_attacking():
			_attack_queued = _attack == &"attack_1"
		elif _attack_cooldown <= 0.0:
			_start_attack(&"attack_1", move)
	if is_attacking():
		_update_attack(delta, move)

	# --- horizontal movement
	var speed_scale := 0.35 if is_attacking() else 1.0
	var target := move * RUN_SPEED * speed_scale
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var on_floor := is_on_floor()
	var rate: float
	if target.length() > 0.01:
		rate = ACCEL if on_floor else AIR_ACCEL
	else:
		rate = DECEL if on_floor else AIR_DECEL
	if _hurt_timer <= 0.0:
		horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# --- gravity
	var g := FALL_GRAVITY if velocity.y < 0.0 else GRAVITY
	velocity.y = maxf(velocity.y - g * delta, -MAX_FALL)

	var was_on_floor := on_floor
	move_and_slide()
	_cur_pos = global_position

	if is_on_floor():
		if not was_on_floor and _air_time > 0.22:
			_land_timer = 0.25
			Audio.play_sfx(&"land", global_position)
		_air_time = 0.0
	else:
		_air_time += delta

	# --- facing
	if not is_attacking() and move.length() > 0.1:
		var want := atan2(-move.x, -move.z)
		_facing = lerp_angle(_facing, want, 1.0 - exp(-TURN_RATE * delta))
	rotation.y = _facing

	# --- footsteps
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 1.5:
		_footstep -= delta * hspeed / RUN_SPEED
		if _footstep <= 0.0:
			_footstep = 0.3
			Audio.play_sfx(&"footstep", global_position, -8.0)

	if global_position.y < -25.0:
		_respawn()

	_update_animation()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"attack") or event.is_echo():
		return
	# A click that only captures the mouse is consumed by the main scene before it gets here;
	# a click without capture (desktop window lost focus) should not swing either.
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_attack_input = true


func _process(_delta: float) -> void:
	if visual == null:
		return
	var f := Engine.get_physics_interpolation_fraction()
	visual.global_position = _prev_pos.lerp(_cur_pos, f)
	visual.global_rotation = Vector3(0, _facing, 0)
	if _invuln > 0.0 and not dead:
		# Stepped flicker on the 12 fps grid while invulnerable.
		model.visible = int(_invuln * 12.0) % 2 == 0
	else:
		model.visible = true


func _camera_relative(v: Vector2) -> Vector3:
	var basis := Basis.IDENTITY
	if is_instance_valid(camera):
		basis = Basis(Vector3.UP, camera.global_rotation.y)
	var forward := -basis.z
	var right := basis.x
	var dir := right * v.x - forward * v.y
	dir.y = 0.0
	return dir.limit_length(1.0)


func _start_attack(attack: StringName, move: Vector3) -> void:
	_attack = attack
	_attack_time = 0.0
	_attack_queued = false
	_hit_this_swing.clear()
	# Aim assist: turn toward the nearest enemy roughly in front.
	var aim := move if move.length() > 0.2 else -global_basis.z
	var best: Node3D = null
	var best_d := ASSIST_RANGE
	for e: Node in get_tree().get_nodes_in_group(Layers.GROUP_ENEMY):
		var n := e as Node3D
		if n == null:
			continue
		var to := n.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and d > 0.01 and absf(aim.signed_angle_to(to, Vector3.UP)) < ASSIST_ANGLE:
			best = n
			best_d = d
	if best != null:
		var to := best.global_position - global_position
		_facing = atan2(-to.x, -to.z)
		rotation.y = _facing
	elif move.length() > 0.2:
		_facing = atan2(-move.x, -move.z)
		rotation.y = _facing
	var spec: Dictionary = ATTACKS[attack]
	var fwd := -Basis(Vector3.UP, _facing).z
	velocity.x = fwd.x * spec["lunge"]
	velocity.z = fwd.z * spec["lunge"]
	animator.play(attack, true)
	Events.player_attacked.emit(attack, global_transform)


func _update_attack(delta: float, move: Vector3) -> void:
	_attack_time += delta
	var spec: Dictionary = ATTACKS[_attack]
	var f := int(_attack_time * 12.0)
	var active: Array = spec["active"]
	# Once the tail has swept past, a queued second swipe starts at once, and running cancels
	# the follow-through, so the combo and movement never wait on the animation's tail end.
	if f > int(active[1]):
		if _attack_queued and _attack == &"attack_1":
			_start_attack(&"attack_2", move)
			return
		if f > int(active[1]) + 1 and move.length() > 0.5:
			_attack = &""
			_attack_cooldown = 0.05
			return
	if f >= active[0] and f <= active[1]:
		for body in hitbox.get_overlapping_bodies():
			if body in _hit_this_swing or not body.is_in_group(Layers.GROUP_ENEMY):
				continue
			if not body.has_method("take_hit"):
				continue
			_hit_this_swing.append(body)
			body.take_hit(float(spec["damage"]), global_position, &"swipe", float(spec["knock"]))
	var length: float = spec["frames"] / 12.0
	if _attack_queued and f >= int(spec["combo_from"]) and _attack_time >= length - 0.05:
		_start_attack(&"attack_2", Vector3.ZERO)
		return
	if _attack_time >= length + (COMBO_GRACE if _attack == &"attack_1" else 0.0):
		_attack = &""
		_attack_cooldown = ATTACK_COOLDOWN
	elif _attack_time >= length and _attack == &"attack_1" and _attack_queued:
		_start_attack(&"attack_2", Vector3.ZERO)


func _update_animation() -> void:
	if dead:
		return
	if _hurt_timer > 0.0:
		animator.play(&"hurt")
	elif is_attacking():
		if _attack_time * 12.0 >= ATTACKS[_attack]["frames"]:
			animator.play(&"idle")
	elif not is_on_floor() and _air_time > 0.06:
		if velocity.y > 0.5:
			animator.play(&"jump")
		else:
			animator.play(&"fall")
	elif _land_timer > 0.0:
		animator.play(&"land")
	else:
		var hspeed := Vector2(velocity.x, velocity.z).length()
		if hspeed > 0.8:
			animator.play(&"run")
			animator.speed = clampf(hspeed / RUN_SPEED, 0.6, 1.2)
			return
		animator.play(&"idle")
	animator.speed = 1.0


## Hurt the player. from is where the blow came from (for knockback).
func take_damage(amount: int, from: Vector3) -> void:
	if is_invulnerable() or not Game.is_playing():
		return
	var floor_hp := 1 if Game.autoplay and not get_meta(&"allow_death", false) else 0
	hp = maxi(hp - amount, floor_hp)
	_invuln = INVULN_TIME
	_hurt_timer = HURT_STUN
	_attack = &""
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else global_basis.z
	velocity = away * (7.0 if _knock_lands_safe(away) else 1.5) + Vector3.UP * 4.0
	animator.play(&"hurt", true)
	var look := ModelKit.ink_look(model)
	if look != null:
		look.flash(Palette.VERMILION, 0.15)
	Events.player_damaged.emit(hp, max_hp)
	if hp <= 0:
		_die()


## A hit never throws Orimi off a ledge: false when the knockback path (about 3 m) drops more
## than 1.2 m below where she stands.
func _knock_lands_safe(away: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for d: float in [0.0, 1.0, 2.0, 3.0]:
		var p := global_position + away * d
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 1.2, Layers.WORLD))
		if hit.is_empty():
			return false
	return true


## Show one bead per remembered colour on Orimi's cord, either side of the knot.
func set_beads(colors: Array[Color]) -> void:
	if model == null:
		return
	var anchor: Node3D = model.find_child("Bead", true, false) as Node3D
	var base := Vector3.ZERO
	if anchor == null:
		anchor = visual
		base = Vector3(0, 0.62, -0.3)
	for old: Node in anchor.get_children():
		if String(old.name).begins_with("CordBead"):
			old.queue_free()
	for i in colors.size():
		var bead := MeshInstance3D.new()
		bead.name = "CordBead%d" % i
		var s := SphereMesh.new()
		s.radius = 0.04
		s.height = 0.08
		s.radial_segments = 8
		s.rings = 4
		bead.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = colors[i]
		m.roughness = 0.45
		m.emission_enabled = true
		m.emission = colors[i] * 0.35
		bead.material_override = m
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side := -1.0 if i % 2 == 0 else 1.0
		bead.position = base + Vector3(side * 0.075 * (i / 2 + 1), -0.02 * (i / 2), 0)
		anchor.add_child(bead)


## Ignore movement and attack input for a moment (put back on a bank: a held direction must not
## walk her straight back in).
func hold_still(seconds: float) -> void:
	_hold_timer = maxf(_hold_timer, seconds)


func heal_full() -> void:
	if hp == max_hp:
		return
	hp = max_hp
	Events.player_healed.emit(hp, max_hp)


func _die() -> void:
	dead = true
	_attack = &""
	Events.player_died.emit()
	var look := ModelKit.ink_look(model)
	var t := create_tween()
	if look != null:
		t.tween_method(look.set_dissolve, 0.0, 1.0, 0.9)
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	if is_instance_valid(Game.main) and Game.main.has_method("fade"):
		await Game.main.fade(1.0, 0.35)
	_respawn()
	if look != null:
		look.set_dissolve(0.0)
	if is_instance_valid(Game.main) and Game.main.has_method("fade"):
		Game.main.fade(0.0, 0.5)


func _respawn() -> void:
	var at := Game.checkpoint
	if is_instance_valid(Game.valley) and Game.valley.has_method("ground_at"):
		at = Game.valley.ground_at(at)
	teleport(at + Vector3.UP * 0.1)
	dead = false
	_invuln = INVULN_TIME
	_hurt_timer = 0.0
	hp = max_hp
	Events.player_healed.emit(hp, max_hp)
	Events.player_respawned.emit(at)
	if is_instance_valid(camera) and camera.has_method("snap_behind"):
		camera.snap_behind(self)


func _on_brush_opened() -> void:
	if not dead and is_instance_valid(animator):
		animator.play(&"brush_pose", true)
