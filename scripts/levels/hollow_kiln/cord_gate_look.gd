extends Node3D
## The kiln gate's look under the kit's GlyphObstacle (CordGate in hollow_kiln.tscn): bound in ink
## cord until a Slash clears the obstacle, then the cord is cut and the leaves swing open. The
## obstacle frees itself after it clears, so the gate moves to the level first and stays.
## Owner: l5 (hollow_kiln).


func _ready() -> void:
	_play(&"bound")


func blow_away(_direction: Vector3) -> void:
	var home: Node = Game.level if Game.level != null else get_tree().current_scene
	reparent(home)
	var ap := _player()
	if ap == null or not ap.has_animation(&"cut"):
		return
	ap.play(&"cut")
	await ap.animation_finished
	_play(&"open")


func _play(anim: StringName) -> void:
	var ap := _player()
	if ap != null and ap.has_animation(anim):
		ap.play(anim)


func _player() -> AnimationPlayer:
	return find_child("AnimationPlayer", true, false) as AnimationPlayer
