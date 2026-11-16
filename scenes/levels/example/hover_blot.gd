extends EnemyBase
## The example level's flying enemy: a blot that hovers about a metre up, drifts after Orimi,
## winds up and dives at her, then rises again. It shows EnemyBase's movement hooks
## (_apply_gravity, keeps_to_ground, spawn_height) for flyers such as Level 4's Sootflit. Up in
## the air a tail swipe cannot hurt it: a Gust downs it for a few seconds, and then one swipe
## unravels it (a Slash works any time). Owner: gameplay.

enum { HOVER, WINDUP, DIVE, RISE, DOWNED }

const HOVER_HEIGHT := 4.0
const DIVE_HEIGHT := 0.35
const SPEED := 3.2
const DIVE_RANGE := 2.2
const DIVE_SPEED := 6.5
const WINDUP_TIME := 7.0 / 12.0
const DIVE_TIME := 0.45
const RISE_TIME := 0.8
const DOWNED_TIME := 3.0

var state := HOVER
var _timer := 0.0
var _t := 0.0


func _init() -> void:
	kind = &"hover_blot"
	max_hp = 1.0
	hp = 1.0
	aggro_range = 10.0


func _model_name() -> String:
	return "splotchet"


func _build_placeholder() -> Node3D:
	return ModelKit.splotchet()


func _collision_size() -> Vector2:
	return Vector2(0.33, 0.66)


## Downed by a Gust it is a ground enemy until it rises again.
func keeps_to_ground() -> bool:
	return state == DOWNED


func spawn_height() -> float:
	return HOVER_HEIGHT


## Hold a height over the ground below: a slow bob while hovering, low during a dive. Downed,
## it falls like any enemy.
func _apply_gravity(delta: float) -> void:
	if state == DOWNED:
		super._apply_gravity(delta)
		return
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * (HOVER_HEIGHT + 3.0), Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var floor_y: float = (hit.position as Vector3).y if not hit.is_empty() else home.y
	var height := DIVE_HEIGHT if state == DIVE else HOVER_HEIGHT + sin(_t * 2.5) * 0.12
	velocity.y = clampf((floor_y + height - global_position.y) * 5.0, -6.0, 6.0)


func _on_glyph(glyph: StringName, info: Dictionary) -> bool:
	match glyph:
		&"slash":
			return take_hit(2.0, Game.player.global_position if is_instance_valid(Game.player) else global_position, &"slash", 6.0)
		&"gust":
			var dir: Vector3 = info.get("world_dir", Vector3.ZERO)
			knock_back(dir if dir.length() > 0.1 else -flat_to(Game.player.global_position), 5.0, 0.6)
			_release_attack_token()
			state = DOWNED
			_timer = DOWNED_TIME
			animator.play(&"hurt", true)
			Game.qa_log("flyer_downed", {"enemy": String(name)})
			return true
	return false


## Up in the air only a Slash reaches it; downed, anything does.
func _can_be_hurt(source: StringName) -> bool:
	return state == DOWNED or source == &"slash"


func _think(delta: float) -> void:
	_t += delta
	_timer -= delta
	var p := player_target()
	match state:
		HOVER:
			var goal := p.global_position if aggro and p != null else home
			var to := flat_to(goal)
			var want := to.normalized() * SPEED if to.length() > (1.6 if aggro else 0.5) else Vector3.ZERO
			velocity.x = move_toward(velocity.x, want.x, 12.0 * delta)
			velocity.z = move_toward(velocity.z, want.z, 12.0 * delta)
			face(to, delta, 6.0)
			if aggro and p != null and to.length() < DIVE_RANGE and _take_attack_token():
				state = WINDUP
				_timer = WINDUP_TIME
				animator.play(&"attack", true)
		WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
			if p != null:
				face(flat_to(p.global_position), delta, 14.0)
			if _timer <= 0.0:
				state = DIVE
				_timer = DIVE_TIME
				_hit_player_this_strike = false
				var dir := -Basis(Vector3.UP, _facing).z
				velocity.x = dir.x * DIVE_SPEED
				velocity.z = dir.z * DIVE_SPEED
		DIVE:
			_strike()
			if _timer <= 0.0:
				state = RISE
				_timer = RISE_TIME
				_release_attack_token()
				animator.play(&"idle")
		DOWNED:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			if _timer <= 0.0:
				state = RISE
				_timer = RISE_TIME
		RISE:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
			if _timer <= 0.0:
				state = HOVER
