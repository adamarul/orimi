class_name RisingHazard
extends Node3D
## Ink (or water, or soot) that rises over a box: a flooding flue, a filling vat. It starts at
## the node's height and rises to top_height above it at rise_speed once it starts (start_flag,
## or Orimi stepping into its box). It never traps her: when it closes over her she is lifted
## out onto the most recent ground she stood on above the surface (a foothold she climbed past),
## or, if there is none, just outside the box, taking damage on the way. Death and respawn put
## it back to the start. Owner: gameplay.

## The surface reached a new height (metres above the node).
signal risen(height: float)
## Orimi was lifted out.
signal lifted(to: Vector3)

## x and z across the box; the surface rises from 0 to top_height above the node.
@export var size: Vector2 = Vector2(6, 6)
@export var top_height: float = 2.0
## Metres per second.
@export var rise_speed: float = 0.3
## Starts rising when this flag is set (empty: see start_on_enter).
@export var start_flag: StringName = &""
## Starts rising when Orimi steps into the box.
@export var start_on_enter: bool = true
## Stops rising (and stays) when this flag is set.
@export var stop_flag: StringName = &""
## Orimi counts as caught once the surface is this far above her feet...
@export var sink: float = 0.25
## ...and a foothold must stand this far above the surface to be a place to lift her to.
@export var clearance: float = 0.4
@export var damage: int = 1
## Set the first time she is lifted out. Empty: none.
@export var flag: StringName = &""
@export var color: Color = Palette.CURSE_INK
@export var show_surface: bool = true

## The surface height above the node.
var height := 0.0
var rising := false
## Times Orimi was lifted out.
var lifts := 0
var _footholds: Array[Vector3] = []
var _sample := 0.0
var _surface: MeshInstance3D


func _ready() -> void:
	add_to_group(&"rising_hazard")
	if show_surface:
		var plane := PlaneMesh.new()
		plane.size = size
		_surface = ModelKit.part(self, "Surface", plane, color)
		_surface.set_meta(&"ink_skip", true)
	Events.player_respawned.connect(func(_at: Vector3) -> void: reset())
	_setup.call_deferred()


func _setup() -> void:
	while Game.level == null or not Game.level.built:
		await get_tree().process_frame
	Game.level.flag_changed.connect(_on_flag)
	if start_flag != &"" and Game.level.get_flag(start_flag):
		start()


func _on_flag(f: StringName, value: bool) -> void:
	if value and f == start_flag:
		start()
	elif value and f == stop_flag:
		rising = false


func start() -> void:
	if rising or (stop_flag != &"" and Game.level != null and Game.level.get_flag(stop_flag)):
		return
	rising = true
	Game.qa_log("rising_started", {"hazard": String(name)})


## Back to the start, still (it starts again on start_flag already set, or on entering).
func reset() -> void:
	height = 0.0
	rising = false
	_footholds.clear()
	_place_surface()
	if start_flag != &"" and Game.level != null and Game.level.get_flag(start_flag):
		start()


func surface_y() -> float:
	return global_position.y + height


func inside(pos: Vector3) -> bool:
	var l := global_transform.affine_inverse() * pos
	return absf(l.x) < size.x * 0.5 and absf(l.z) < size.y * 0.5


## Inside the box and under the surface (as the autoplay checks it).
func contains(pos: Vector3) -> bool:
	return inside(pos) and pos.y < surface_y() - sink


func _place_surface() -> void:
	if _surface != null:
		_surface.position.y = height + 0.01
		_surface.visible = height > 0.01


func _physics_process(delta: float) -> void:
	var p := Game.player as OrimiPlayer
	if not is_instance_valid(p) or p.dead or not Game.is_playing():
		return
	var pos := p.global_position
	if not rising and start_on_enter and start_flag == &"" and inside(pos):
		start()
	if rising and height < top_height:
		height = minf(height + rise_speed * delta, top_height)
		_place_surface()
		risen.emit(height)
	_sample -= delta
	if p.is_on_floor() and pos.y > surface_y() + clearance and _sample <= 0.0:
		_sample = 0.2
		if _footholds.is_empty() or _footholds.back().distance_to(pos) > 0.5:
			_footholds.append(pos)
			if _footholds.size() > 40:
				_footholds.pop_front()
	if height > 0.01 and contains(pos):
		_lift(p, pos)


func _lift(p: OrimiPlayer, pos: Vector3) -> void:
	var to := Vector3.INF
	for i in range(_footholds.size() - 1, -1, -1):
		if _footholds[i].y > surface_y() + clearance:
			to = _footholds[i]
			break
	if to == Vector3.INF:
		to = _outside(pos)
	Events.player_thrown_back.emit(Vector3(pos.x, surface_y(), pos.z), &"rising")
	p.teleport(to + Vector3.UP * 0.05, p.rotation.y)
	if damage > 0:
		p.take_damage(damage, pos)
		# No knockback: it would throw her off the foothold she was lifted onto.
		p.velocity = Vector3.ZERO
	lifts += 1
	Game.qa_log("rising_lifted", {"hazard": String(name), "from": Game._v(pos), "to": Game._v(to), "surface": snappedf(surface_y(), 0.01)})
	if flag != &"" and Game.level != null:
		Game.level.set_flag(flag)
	lifted.emit(to)


## Ground just past the nearest edge of the box.
func _outside(pos: Vector3) -> Vector3:
	var l := global_transform.affine_inverse() * pos
	var hx := size.x * 0.5 + 0.8
	var hz := size.y * 0.5 + 0.8
	if hx - absf(l.x) < hz - absf(l.z):
		l.x = signf(l.x if l.x != 0.0 else 1.0) * hx
	else:
		l.z = signf(l.z if l.z != 0.0 else 1.0) * hz
	l.y = 0.0
	var out := global_transform * l
	return Game.level.ground_at(out) if Game.level != null else out
