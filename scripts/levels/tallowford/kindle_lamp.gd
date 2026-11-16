extends Node3D
## Bridges a Tallowford lamp model to the kit's KindleTarget (this scene is its model_scene): the
## lamp shows its unlit pose until the target emits kindled, then plays its lit animation. Wick
## (where the dab lands) and Flame (shown by the kit when lit) are built up front, so nothing is
## created at the moment of kindling. Owner: l2.

@export var unlit_animation: StringName = &"unlit"
@export var lit_animation: StringName = &"lit"

var _anim: AnimationPlayer


func _ready() -> void:
	var model := get_node(^"Model")
	_anim = model.get_node_or_null(^"%AnimationPlayer") as AnimationPlayer
	play(unlit_animation)
	var target := get_parent()
	if target != null and target.has_signal(&"kindled"):
		target.connect(&"kindled", func() -> void: play(lit_animation))


func play(animation: StringName) -> void:
	if _anim != null and _anim.has_animation(animation):
		_anim.play(animation)
