class_name FolkPerson
extends Node3D
## A paper person made by tools/blender/make_folk.py (see the Folk section of docs/ASSETS.md).
## Faded: drained grey paper holding the still "faded" pose. Woken: painted colours and "idle".
## The switch swaps the atlas on this person's own InkLook materials, so it touches no one else
## and does not depend on cursed zones (InkLook.cursable is off for folk). Owner: assets.

signal woke

## Start faded (grey and still) or woken. Setting it at run time switches at once, no flash.
@export var faded := false:
	set(value):
		faded = value
		if is_node_ready():
			_apply()
@export var woken_texture: Texture2D
@export var faded_texture: Texture2D


func _ready() -> void:
	_apply()


## Colour returns in one step with a warm flash, and the person starts the idle loop.
func wake(flash_duration: float = 0.45) -> void:
	if not faded:
		return
	faded = false
	var look := _look()
	if look:
		look.flash(Color(1.0, 0.93, 0.75), flash_duration)
	woke.emit()


## The person's AnimationPlayer (idle, talk, walk, faded).
func anim_player() -> AnimationPlayer:
	return get_node_or_null(^"%AnimationPlayer") as AnimationPlayer


func _look() -> InkLook:
	for child in get_children():
		if child is InkLook:
			return child
	return null


func _apply() -> void:
	var look := _look()
	if look:
		look.set_dissolve(0.0)
	var tex := faded_texture if faded else woken_texture
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m:
				m.set_shader_parameter(&"albedo_tex", tex)
	var ap := anim_player()
	if ap:
		ap.play(&"faded" if faded else &"idle")
