class_name LevelExit
extends Node3D
## Where a level ends: Orimi walks within radius once every required flag is set and the
## level completes (bead, Pell's raft, the next level). Before that it shows the "not ready"
## hint. model_name "raft" puts Pell's raft here (scenes/models/raft.tscn). Owner: gameplay.

signal used

@export var radius: float = 2.5
@export var requires_flags: PackedStringArray = PackedStringArray()
## A model from scenes/models/ (for example "raft"); empty for none.
@export var model_name: String = ""
## Set when used, before the level completes.
@export var flag: StringName = &"exit_reached"

var model: Node3D
var _hint_at := -100.0


func _ready() -> void:
	add_to_group(&"level_exit")
	if model_name != "":
		model = ModelKit.load_model(model_name, func() -> Node3D: return Node3D.new())
		add_child(model)


func _physics_process(_delta: float) -> void:
	var p := Game.player as OrimiPlayer
	if Game.level == null or Game.level.completed or not is_instance_valid(p) or p.dead or not Game.is_playing():
		return
	var off := p.global_position - global_position
	if (Vector2(off.x, off.z).length() > radius or absf(off.y) > 3.0) and not _touching_model(p):
		return
	if not Game.level.all_flags(Array(requires_flags)):
		var now := Time.get_ticks_msec() / 1000.0
		if now - _hint_at > 6.0:
			_hint_at = now
			Game.qa_log("exit_refused", {"needs": Array(requires_flags)})
			Game.hint(&"not_ready")
		return
	Game.qa_log("level_exit", {"exit": String(name)})
	Game.level.set_flag(flag)
	used.emit()
	Game.level.complete()


## Bumping into or standing on the exit's model (the raft) counts as reaching it.
func _touching_model(p: OrimiPlayer) -> bool:
	if model == null:
		return false
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i).get_collider() as Node
		if c != null and (c == model or model.is_ancestor_of(c)):
			return true
	return false
