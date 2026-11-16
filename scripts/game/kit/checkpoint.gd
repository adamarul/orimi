class_name Checkpoint
extends Node3D
## A place Orimi comes back to after a fall. Walking within radius makes it the checkpoint,
## heals her (heal), and sets its flag; it also works as a plain "Orimi got here" trigger for
## objectives. Owner: gameplay.

signal reached

@export var radius: float = 2.0
## Set when reached. Empty: "reached_<node name in snake_case>".
@export var flag: StringName = &""
## Only counts once all are set.
@export var requires_flags: PackedStringArray = PackedStringArray()
@export var heal: bool = true
## Show the paper charm on a stake (off for an invisible trigger).
@export var show_model: bool = true

var done := false
var model: Node3D


func _ready() -> void:
	add_to_group(&"checkpoint")
	if flag == &"":
		flag = StringName("reached_" + String(name).to_snake_case())
	if show_model:
		model = ModelKit.load_model("checkpoint", ModelKit.tie_post)
		add_child(model)
	_settle.call_deferred()


func _settle() -> void:
	await get_tree().physics_frame
	if Game.level != null:
		await Game.level.ready_to_settle()
		global_position = Game.level.ground_at(global_position + Vector3.UP * 1.5, self)


func _physics_process(_delta: float) -> void:
	if done:
		return
	var p := Game.player as OrimiPlayer
	if not is_instance_valid(p) or p.dead or not Game.is_playing():
		return
	var off := p.global_position - global_position
	if Vector2(off.x, off.z).length() > radius or absf(off.y) > 3.0:
		return
	if Game.level != null and not Game.level.all_flags(Array(requires_flags)):
		return
	done = true
	Game.checkpoint = Game.level.ground_at(p.global_position) if Game.level != null else p.global_position
	if heal:
		p.heal_full()
	if model != null:
		var look := ModelKit.ink_look(model)
		if look != null:
			look.flash(Palette.GOLD_PALE, 0.5)
	Game.qa_log("checkpoint", {"checkpoint": String(name), "at": Game._v(Game.checkpoint)})
	if Game.level != null:
		Game.level.set_flag(flag)
	reached.emit()
