class_name EnemySpawn
extends Marker3D
## Where an enemy appears. On its own in a level it spawns when the level is built and roams
## near here. Under a CursedZone it belongs to that zone (wave 0 at build, wave 1+ in the
## zone's final wave); under a SealedFight it rises when the fight starts. Owner: gameplay.

## &"splotchet" or &"reedwraith". Ignored when enemy_scene is set.
@export var kind: StringName = &"splotchet"
## A level's own enemy: a scene whose root script extends EnemyBase (see docs/LEVEL_KIT.md).
@export var enemy_scene: PackedScene
## 0: present from the start. 1, 2, ...: the zone's final-wave pulse (inside a CursedZone)
## or the fight's wave (inside a SealedFight).
@export var wave: int = 0
## Start already hunting Orimi.
@export var aggro: bool = false
## The enemy ignores Orimi while she is more than this far (across the ground) from the marker:
## a creature that keeps to its chamber or its pen. 0: no limit.
@export var territory_radius: float = 0.0

const KINDS := {&"splotchet": "Splotchet", &"reedwraith": "Reedwraith"}

var spawned: EnemyBase
var _auto := true


func _ready() -> void:
	# Stand-alone spawns create their enemy once the level is built; zones and fights call spawn().
	if _owned_by_group():
		return
	_spawn_when_built.call_deferred()


func _owned_by_group() -> bool:
	var p := get_parent()
	while p != null and not (p is Level):
		if p is CursedZone or p is SealedFight:
			return true
		p = p.get_parent()
	return false


func _spawn_when_built() -> void:
	await get_tree().physics_frame
	if spawned == null:
		spawn(get_parent())


## Create the enemy under parent at this marker (dropped onto the ground) and return it.
func spawn(parent: Node, hunting: bool = false) -> EnemyBase:
	var e := make(kind, enemy_scene)
	e.name = "%s_%s" % [String(e.kind).capitalize().replace(" ", ""), String(name)]
	parent.add_child(e)
	var at := global_position
	if Game.level != null:
		at = Game.level.ground_at(at + Vector3.UP * 1.0)
	e.global_position = at + Vector3.UP * e.spawn_height()
	e.rotation.y = global_rotation.y
	e.home = at
	if territory_radius > 0.0:
		e.territory_center = global_position
		e.territory_radius = territory_radius
	e.aggro = aggro or hunting
	spawned = e
	return e


static func make(enemy_kind: StringName, scene: PackedScene = null) -> EnemyBase:
	if scene != null:
		var custom := scene.instantiate() as EnemyBase
		if custom != null:
			return custom
		push_error("EnemySpawn: enemy_scene root must extend EnemyBase")
	match enemy_kind:
		&"reedwraith":
			return Reedwraith.new()
		_:
			return Splotchet.new()
