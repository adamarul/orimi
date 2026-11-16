class_name Splotchet
extends EnemyBase
## A small hopping blot. Hops toward the player in bursts, winds up and lunges.
## Dies to two tail swipes or one slash; a gust bowls it over. Owner: gameplay.

enum { IDLE, CHASE, WINDUP, LUNGE, RECOVER }

const HOP_SPEED := 4.4
const HOP_UP := 4.6
const LUNGE_RANGE := 2.8
const LUNGE_SPEED := 8.5
## Seven 12 fps frames: the windup part of the attack animation (frames 0 to 6).
const WINDUP_TIME := 7.0 / 12.0
const LUNGE_TIME := 0.38
const RECOVER_TIME := 0.7

var state := IDLE
var _timer := 0.0
var _hop_cd := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	kind = &"splotchet"
	max_hp = 2.0
	hp = 2.0
	aggro_range = 11.0


func _model_name() -> String:
	return "splotchet"


func _build_placeholder() -> Node3D:
	return ModelKit.splotchet()


func _collision_size() -> Vector2:
	return Vector2(0.33, 0.66)


func _strike_radius() -> float:
	return 0.65


func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * 0.35


func glyph_radius() -> float:
	return 0.6


func _ready() -> void:
	super._ready()
	_rng.randomize()
	_hop_cd = _rng.randf_range(0.2, 1.2)


func _on_glyph(glyph: StringName, info: Dictionary) -> bool:
	if dying:
		return false
	match glyph:
		&"slash":
			return take_hit(2.0, _glyph_from(info), &"slash", 6.0)
		&"gust":
			var dir: Vector3 = info.get("world_dir", Vector3.ZERO)
			if dir.length() < 0.1:
				dir = flat_to(global_position * 2.0 - _glyph_from(info))
			knock_back(dir, 9.0, 1.0)
			state = RECOVER
			_timer = 1.0
			return true
	return false


func _glyph_from(info: Dictionary) -> Vector3:
	if is_instance_valid(Game.player):
		return Game.player.global_position
	return info.get("world_center", global_position)


func _think(delta: float) -> void:
	_timer -= delta
	_hop_cd -= delta
	var p := player_target()
	var on_floor := is_on_floor()
	if on_floor and state != LUNGE:
		var h := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 14.0 * delta)
		velocity.x = h.x
		velocity.z = h.z
	match state:
		IDLE, CHASE:
			state = CHASE if aggro and p != null else IDLE
			var goal := p.global_position if state == CHASE else home
			var to := flat_to(goal)
			if state == CHASE and to.length() < LUNGE_RANGE and on_floor and _take_attack_token():
				state = WINDUP
				_timer = WINDUP_TIME
				animator.play(&"attack", true)
				return
			if on_floor and _hop_cd <= 0.0 and (state == CHASE or to.length() > 1.5 or _rng.randf() < 0.3):
				var dir := to.normalized() if to.length() > 0.3 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
				if state == CHASE and to.length() < LUNGE_RANGE + 1.0:
					dir = dir.rotated(Vector3.UP, _rng.randf_range(-0.9, 0.9))
				var spd := HOP_SPEED if state == CHASE else HOP_SPEED * 0.45
				velocity = dir * spd + Vector3.UP * (HOP_UP if state == CHASE else HOP_UP * 0.6)
				_hop_cd = _rng.randf_range(0.55, 0.95) if state == CHASE else _rng.randf_range(1.2, 2.6)
				animator.play(&"hop", true)
				Audio.play_sfx(&"splotchet_hop", global_position, -6.0)
				face(dir, 1.0, 100.0)
			elif on_floor and animator.is_done():
				animator.play(&"idle")
			if state == CHASE:
				face(to, delta, 6.0)
		WINDUP:
			if p != null:
				face(flat_to(p.global_position), delta, 14.0)
			if _timer <= 0.0:
				state = LUNGE
				_timer = LUNGE_TIME
				_hit_player_this_strike = false
				var dir := -Basis(Vector3.UP, _facing).z
				velocity = dir * LUNGE_SPEED + Vector3.UP * 3.2
		LUNGE:
			_strike()
			if _timer <= 0.0 or (on_floor and _timer < LUNGE_TIME - 0.15):
				state = RECOVER
				_timer = RECOVER_TIME
				_release_attack_token()
				animator.play(&"idle")
		RECOVER:
			if _timer <= 0.0:
				state = CHASE
				_hop_cd = 0.2
