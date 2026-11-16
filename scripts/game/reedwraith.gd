class_name Reedwraith
extends EnemyBase
## A tall drifting bundle of ink reeds in a soot veil. Keeps its distance and lashes out.
## Nothing hurts it while veiled; a gust strips the veil and stuns it, then swipes or a slash
## cut it down. Owner: gameplay.

enum { DRIFT, WINDUP, LASH, RECOVER }

const DRIFT_SPEED := 2.6
const NEAR := 4.8
const FAR := 8.5
const LASH_MIN := 3.0
const LASH_MAX := 6.0
## Eleven 12 fps frames: the windup part of the attack animation (frames 0 to 10).
const WINDUP_TIME := 11.0 / 12.0
const LASH_TIME := 0.32
const LASH_SPEED := 10.5
const RECOVER_TIME := 1.0
const UNVEIL_STUN := 2.8

var veiled := true
var state := DRIFT
var _timer := 0.0
var _cooldown := 2.0
var _strafe := 1.0
var _moan := 4.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	kind = &"reedwraith"
	max_hp = 2.0
	hp = 2.0
	aggro_range = 14.0
	leash_range = 30.0


func _model_name() -> String:
	return "reedwraith"


func _build_placeholder() -> Node3D:
	return ModelKit.reedwraith()


func _collision_size() -> Vector2:
	return Vector2(0.4, 2.0)


func _strike_radius() -> float:
	return 1.0


func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * 1.2


func glyph_radius() -> float:
	return 1.1


func _ready() -> void:
	super._ready()
	_rng.randomize()
	_strafe = 1.0 if _rng.randf() < 0.5 else -1.0
	_cooldown = _rng.randf_range(1.5, 3.0)


func _can_be_hurt(_source: StringName) -> bool:
	return not veiled


func _on_blocked(_source: StringName) -> void:
	if look != null:
		look.flash(Palette.STONE, 0.1)
	if is_instance_valid(Game.main) and Game.main.has_method("hint"):
		Game.main.hint(&"veil")


func _on_glyph(glyph: StringName, info: Dictionary) -> bool:
	if dying:
		return false
	match glyph:
		&"gust":
			if veiled:
				unveil()
			else:
				var dir: Vector3 = info.get("world_dir", Vector3.ZERO)
				knock_back(dir if dir.length() > 0.1 else -global_basis.z, 5.0, 1.2)
			return true
		&"slash":
			if veiled:
				_on_blocked(&"slash")
				return false
			var from := Game.player.global_position if is_instance_valid(Game.player) else global_position + global_basis.z
			return take_hit(2.0, from, &"slash", 5.0)
	return false


func unveil() -> void:
	if not veiled:
		return
	veiled = false
	_release_attack_token()
	state = RECOVER
	_timer = UNVEIL_STUN
	stun = UNVEIL_STUN
	velocity = Vector3.ZERO
	animator.play(&"veil_off", true)
	Events.enemy_unveiled.emit(self)
	await get_tree().create_timer(0.6, false).timeout
	if is_instance_valid(model):
		var veil := model.find_child("Veil", true, false) as Node3D
		if veil != null:
			veil.visible = false


func _think(delta: float) -> void:
	_timer -= delta
	_cooldown -= delta
	_moan -= delta
	var p := player_target()
	var h := Vector3(velocity.x, 0, velocity.z)
	if p == null or not aggro:
		var to_home := flat_to(home)
		var want := to_home.normalized() * DRIFT_SPEED * 0.5 if to_home.length() > 1.0 else Vector3.ZERO
		h = h.move_toward(want, 6.0 * delta)
		velocity.x = h.x
		velocity.z = h.z
		if animator.current != &"veil_off" or animator.is_done():
			animator.play(&"idle")
		return
	if _moan <= 0.0:
		_moan = _rng.randf_range(5.0, 9.0)
		Audio.play_sfx(&"reedwraith_moan", global_position, -4.0)
	var to := flat_to(p.global_position)
	var d := to.length()
	match state:
		DRIFT:
			# Its circling band, fitted to a ring that holds it.
			var near := minf(NEAR, confine_radius * 0.6)
			var far := minf(FAR, confine_radius * 1.2)
			var radial := 0.0
			if d < near:
				radial = -1.0
			elif d > far:
				radial = 1.0
			var want := to.normalized() * radial + to.normalized().cross(Vector3.UP) * _strafe * 0.6
			h = h.move_toward(want.limit_length(1.0) * DRIFT_SPEED, 5.0 * delta)
			velocity.x = h.x
			velocity.z = h.z
			face(to, delta, 5.0)
			if _rng.randf() < delta * 0.25:
				_strafe = -_strafe
			if animator.current != &"veil_off" or animator.is_done():
				animator.play(&"drift")
			if _cooldown <= 0.0 and d > LASH_MIN and d < LASH_MAX and _take_attack_token():
				state = WINDUP
				_timer = WINDUP_TIME
				animator.play(&"attack", true)
				if look != null:
					look.flash(Palette.CURSE_RED, WINDUP_TIME)
		WINDUP:
			h = h.move_toward(Vector3.ZERO, 8.0 * delta)
			velocity.x = h.x
			velocity.z = h.z
			face(to, delta, 12.0)
			if _timer <= 0.0:
				state = LASH
				_timer = LASH_TIME
				_hit_player_this_strike = false
				var dir := -Basis(Vector3.UP, _facing).z
				velocity = dir * LASH_SPEED
		LASH:
			_strike()
			if _timer <= 0.0:
				state = RECOVER
				_timer = RECOVER_TIME
				_cooldown = _rng.randf_range(2.6, 4.2)
				_release_attack_token()
		RECOVER:
			h = h.move_toward(-to.normalized() * DRIFT_SPEED * 0.6, 6.0 * delta)
			velocity.x = h.x
			velocity.z = h.z
			if _timer <= 0.0:
				state = DRIFT
