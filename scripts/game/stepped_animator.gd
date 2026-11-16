class_name SteppedAnimator
extends Node
## Drives an AnimationPlayer in 1/12 s steps, so nothing ever interpolates between keys,
## and shows the model's Smear node on an attack's smear frames. Owner: gameplay.
##
## The AnimationPlayer is put in manual mode and only ever seeked to whole frames. If an
## animation keys Smear's visibility itself, that track decides; otherwise Smear is shown on
## the frames listed in smear_frames.

signal finished(anim_name: StringName)

const STEP := 1.0 / 12.0
const LOOPING: Array[StringName] = [&"idle", &"run", &"fall", &"brush_pose", &"drift", &"withered"]

## Fallback smear frames per animation, used when the animation has no Smear track.
var smear_frames: Dictionary = {&"attack_1": [2, 3], &"attack_2": [2, 3, 4]}
## Playback rate multiplier (frames still land on the 12 fps grid).
var speed: float = 1.0
var player: AnimationPlayer
var current: StringName = &""
var frame: int = 0

var _model: Node3D
var _smear: Node3D
var _smear_has_track := false
var _length := 0.0
var _loop := false
var _accum := 0.0
var _done := false


func setup(model: Node3D) -> void:
	_model = model
	player = ModelKit.anim_player(model)
	_smear = model.find_child("Smear", true, false) as Node3D
	if _smear != null:
		_smear.visible = false
	if player != null:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL


func has(anim_name: StringName) -> bool:
	return player != null and player.has_animation(anim_name)


func is_done() -> bool:
	return _done


## Start an animation from frame 0. Playing the current animation again does nothing
## unless restart is true. Unknown names are ignored, so a model may lack some animations.
func play(anim_name: StringName, restart: bool = false) -> void:
	if not has(anim_name):
		return
	if anim_name == current and not restart and not _done:
		return
	current = anim_name
	var anim := player.get_animation(anim_name)
	_length = anim.length
	_loop = anim_name in LOOPING or anim.loop_mode != Animation.LOOP_NONE
	_smear_has_track = false
	for t in anim.get_track_count():
		var path := String(anim.track_get_path(t))
		if path.ends_with("Smear:visible"):
			_smear_has_track = true
	_accum = 0.0
	_done = false
	frame = 0
	player.play(anim_name)
	_apply()


## Jump to the last frame of the current animation (used when warping past a sequence).
func finish_now() -> void:
	if player == null or current == &"":
		return
	frame = frame_count() - 1
	_done = not _loop
	_apply()


func frame_count() -> int:
	return maxi(1, roundi(_length / STEP))


func _process(delta: float) -> void:
	if player == null or current == &"" or _done:
		return
	_accum += delta * speed
	if _accum < STEP:
		return
	var steps := int(_accum / STEP)
	_accum -= steps * STEP
	var count := frame_count()
	frame += steps
	if frame >= count:
		if _loop:
			frame = frame % count
		else:
			frame = count - 1
			_done = true
	_apply()
	if _done:
		finished.emit(current)


func _apply() -> void:
	player.seek(minf(frame * STEP, _length), true)
	if _smear != null and not _smear_has_track:
		_smear.visible = frame in smear_frames.get(current, [])
