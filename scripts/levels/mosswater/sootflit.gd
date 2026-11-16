class_name Sootflit
extends EnemyBase
## Mosswater Wood's flying enemy: a drop of ink that grew soot wings. It circles out of reach about
## 4 m up, and every few seconds folds its wings and dives at Orimi, then climbs back. In the air
## nothing but a Gust touches it: the gust knocks it out of the sky, it lies stunned on the ground
## for DOWNED_TIME seconds, open to swipes and a Slash, then lifts off again. A dive can be
## swiped as it comes in. Model scenes/levels/mosswater/models/mw_sootflit.tscn. Owner: l4.

enum { CIRCLE, WINDUP, DIVE, CLIMB, FALL, DOWNED, LIFT }

const MODEL_SCENE := "res://scenes/levels/mosswater/models/mw_sootflit.tscn"
const ALTITUDE := 4.0
const ORBIT_RADIUS := 4.0
const ORBIT_SPEED := 3.2
const MAX_SPEED := 6.0
const CLIMB_SPEED := 4.0
const DIVE_SPEED := 9.5
const WINDUP_TIME := 0.5
const DIVE_TIME := 1.3
const DOWNED_TIME := 3.0
## How far the orbit may drift from home toward Orimi.
const DRIFT := 6.0
## It dives only while Orimi is this close to home (flat metres), so a pack keeps to its own place.
const DIVE_REACH := 10.0

var state := CIRCLE
var _timer := 0.0
var _dive_cd := 0.0
var _angle := 0.0
var _turn := 1.0
var _dive_target := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	kind = &"sootflit"
	max_hp = 2.0
	hp = 2.0
	aggro_range = 14.0
	leash_range = 28.0


func _build_placeholder() -> Node3D:
	if ResourceLoader.exists(MODEL_SCENE):
		return (load(MODEL_SCENE) as PackedScene).instantiate() as Node3D
	return ModelKit.splotchet()


func _collision_size() -> Vector2:
	return Vector2(0.3, 0.6)


func _strike_radius() -> float:
	return 0.75


func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * 0.3


func glyph_radius() -> float:
	return 0.9


func _ready() -> void:
	super._ready()
	_rng.randomize()
	_angle = _rng.randf() * TAU
	_turn = 1.0 if _rng.randf() < 0.5 else -1.0
	_dive_cd = _rng.randf_range(1.5, 3.5)
	_set_flying(true)
	animator.play(&"fly")


## True while it is in the air and out of reach of swipes and slashes.
func is_airborne() -> bool:
	return state in [CIRCLE, CLIMB, LIFT]


func is_downed() -> bool:
	return state == DOWNED


func keeps_to_ground() -> bool:
	return false


func spawn_height() -> float:
	return ALTITUDE


## In flight _think steers the whole velocity; only a gust-downed Sootflit falls.
func _apply_gravity(delta: float) -> void:
	if state in [FALL, DOWNED]:
		super._apply_gravity(delta)


func _set_flying(on: bool) -> void:
	floor_snap_length = 0.0 if on else 0.3


func _go(new_state: int, anim: StringName = &"", restart := true) -> void:
	state = new_state
	if anim != &"":
		animator.play(anim, restart)
	Game.qa_log("sootflit_state", {"name": String(name), "state": ["circle", "windup", "dive", "climb", "fall", "downed", "lift"][new_state], "at": Game._v(global_position)})


func _orbit_centre() -> Vector3:
	var c := home
	var p := player_target()
	if aggro and p != null:
		var off := flat_to(p.global_position) + (global_position - home) * Vector3(1, 0, 1)
		c = home + off.limit_length(DRIFT)
		c.y = maxf(home.y, p.global_position.y)
	return c + Vector3.UP * ALTITUDE


func _fly_toward(point: Vector3, delta: float, speed: float = MAX_SPEED) -> void:
	var want := ((point - global_position) * 3.0).limit_length(speed)
	velocity = velocity.lerp(want, 1.0 - exp(-6.0 * delta))
	face(Vector3(velocity.x, 0, velocity.z), delta, 8.0)


func _on_glyph(glyph: StringName, info: Dictionary) -> bool:
	match glyph:
		&"gust":
			if state in [FALL, DOWNED]:
				return false
			var dir: Vector3 = info.get("world_dir", Vector3.ZERO)
			if dir.length() < 0.1:
				dir = flat_to(global_position * 2.0 - _glyph_from(info))
			dir.y = 0.0
			velocity = dir.normalized() * 3.0 + Vector3.DOWN * 2.0
			_release_attack_token()
			_set_flying(false)
			if look != null:
				look.flash(Color.WHITE, 0.12)
			_go(FALL, &"fall")
			return true
		&"slash":
			if is_airborne():
				return false
			return take_hit(2.0, _glyph_from(info), &"slash", 3.0)
	return false


func _glyph_from(info: Dictionary) -> Vector3:
	if is_instance_valid(Game.player):
		return Game.player.global_position
	return info.get("world_center", global_position)


func _can_be_hurt(_source: StringName) -> bool:
	return not is_airborne()


func _on_blocked(_source: StringName) -> void:
	if look != null:
		look.flash(Palette.IVORY, 0.08)


func _think(delta: float) -> void:
	_timer -= delta
	_dive_cd -= delta
	var p := player_target()
	match state:
		CIRCLE:
			_angle += _turn * ORBIT_SPEED / ORBIT_RADIUS * delta
			var bob := sin(_angle * 2.3) * 0.35
			_fly_toward(_orbit_centre() + Vector3(cos(_angle) * ORBIT_RADIUS, bob, sin(_angle) * ORBIT_RADIUS), delta)
			if aggro and p != null and _dive_cd <= 0.0 and Vector2(p.global_position.x - home.x, p.global_position.z - home.z).length() < DIVE_REACH and _take_attack_token():
				_timer = WINDUP_TIME
				_go(WINDUP, &"dive")
		WINDUP:
			velocity = velocity.lerp(Vector3.UP * 0.6, 1.0 - exp(-8.0 * delta))
			if p == null:
				_release_attack_token()
				_go(CLIMB, &"fly")
				return
			face(flat_to(p.global_position), delta, 14.0)
			if _timer <= 0.0:
				_dive_target = p.global_position + Vector3.UP * 0.5
				_hit_player_this_strike = false
				_timer = DIVE_TIME
				_go(DIVE)
		DIVE:
			var to := _dive_target - global_position
			if to.length() > 0.05:
				velocity = to.normalized() * DIVE_SPEED
			face(Vector3(to.x, 0, to.z), delta, 14.0)
			_strike()
			if to.length() < 0.6 or _timer <= 0.0 or is_on_floor() or is_on_wall():
				_release_attack_token()
				_dive_cd = _rng.randf_range(2.5, 4.5)
				_go(CLIMB, &"fly")
		CLIMB, LIFT:
			var c := _orbit_centre() + Vector3(cos(_angle) * ORBIT_RADIUS, 0.0, sin(_angle) * ORBIT_RADIUS)
			_fly_toward(c, delta, CLIMB_SPEED + 2.0)
			if global_position.y < c.y - 0.5:
				velocity.y = maxf(velocity.y, CLIMB_SPEED)
			if global_position.y >= c.y - 0.6:
				_go(CIRCLE, &"fly", false)
		FALL:
			velocity.x = move_toward(velocity.x, 0.0, 4.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 4.0 * delta)
			if is_on_floor():
				_timer = DOWNED_TIME
				_go(DOWNED, &"downed")
		DOWNED:
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			if _timer <= 0.0:
				_set_flying(true)
				velocity = Vector3.UP * CLIMB_SPEED
				_dive_cd = _rng.randf_range(1.5, 3.0)
				_go(LIFT, &"fly")
