class_name BloomTarget
extends StaticBody3D
## A withered sapling (one per cursed zone) or the great tree. Bloom on it restores its zone
## once the zone allows it. Owner: gameplay.

## &"sapling" or &"great_tree".
@export var model_name: String = "sapling"
var zone: CursedZone
var model: Node3D
var animator: SteppedAnimator
var bloomed := false


func _ready() -> void:
	add_to_group(Layers.GROUP_BRUSH_TARGET)
	collision_layer = Layers.WORLD | Layers.BRUSH_TARGET
	collision_mask = 0
	var big := model_name == "great_tree"
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.5 if big else 0.25
	cyl.height = 9.0 if big else 1.4
	shape.shape = cyl
	shape.position = Vector3(0, cyl.height * 0.5, 0)
	add_child(shape)
	model = ModelKit.load_model(model_name, ModelKit.great_tree if big else ModelKit.sapling)
	add_child(model)
	animator = SteppedAnimator.new()
	add_child(animator)
	animator.setup(model)
	if animator.has(&"withered"):
		animator.play(&"withered")
	else:
		# The model's bloom animation starts from the withered pose; hold its first frame.
		animator.play(&"bloom", true)
		animator.speed = 0.0


func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * (3.5 if model_name == "great_tree" else 0.8)


func glyph_radius() -> float:
	return 2.5 if model_name == "great_tree" else 0.9


func on_glyph(glyph: StringName, _info: Dictionary) -> bool:
	if glyph != &"bloom" or bloomed or zone == null:
		return false
	return zone.request_restore()


func play_bloom() -> void:
	bloomed = true
	animator.speed = 1.0
	animator.play(&"bloom", true)
	var look := ModelKit.ink_look(model)
	if look != null:
		look.flash(Palette.PETAL, 0.4)


## Jump straight to the bloomed pose (warp).
func set_bloomed() -> void:
	bloomed = true
	animator.speed = 1.0
	animator.play(&"bloom", true)
	animator.finish_now()
