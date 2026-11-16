class_name KindleTarget
extends StaticBody3D
## Something Kindle lights: a lamp on a post, a brazier, a lantern-fruit. A Kindle dab on its
## wick lights it: the flame shows, a warm light comes up and lit_flag is set. It can refuse
## until required flags are set (a hooded lamp until the soot is blown off). Owner: gameplay.

## It was lit.
signal kindled

## "lamp", "brazier" or "lantern_fruit" (the placeholder model and its wick height).
@export_enum("lamp", "brazier", "lantern_fruit") var kind: String = "lamp"
## Set when lit. Empty: "lit_<node name in snake_case>".
@export var lit_flag: StringName = &""
## Kindle is refused (hint "not_ready") until all are set.
@export var requires_flags: PackedStringArray = PackedStringArray()
## Your own look. Put a node named "Flame" in it (shown when lit) and, optionally, a node
## named "Wick" where the dab must land.
@export var model_scene: PackedScene
@export var start_lit: bool = false
@export var light_color: Color = Color("ffcf7a")
@export var light_range: float = 7.0
@export var light_energy: float = 1.6
## How much of its own colour the model keeps in a dark or drained place (InkLook.light_keep):
## 0 follows the place, 1 is untouched. -1 = automatic: 0.6 for a lantern-fruit (it glows on
## its branch even unlit), the ink look's own default for lamps and braziers.
@export_range(-1.0, 1.0) var light_keep: float = -1.0

var lit := false
var model: Node3D
var light: OmniLight3D
var _wick := Vector3(0, 1.0, 0)


func _ready() -> void:
	add_to_group(Layers.GROUP_BRUSH_TARGET)
	add_to_group(&"kindle_target")
	collision_layer = Layers.WORLD | Layers.BRUSH_TARGET
	collision_mask = 0
	if lit_flag == &"":
		lit_flag = StringName("lit_" + String(name).to_snake_case())
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
	else:
		model = ModelKit.load_model(kind, ModelKit.kindle.bind(kind))
	add_child(model)
	var keep := light_keep if light_keep >= 0.0 else (0.6 if kind == "lantern_fruit" else -1.0)
	var look := ModelKit.ink_look(model)
	if look != null and keep >= 0.0:
		look.light_keep = keep
		look.apply()
		Game.qa_log("kindle_look", {"target": String(name), "kind": kind, "light_keep": keep})
	var wick_node := model.find_child("Wick", true, false) as Node3D
	if wick_node != null:
		_wick = wick_node.position
	elif model.has_meta(&"wick"):
		_wick = model.get_meta(&"wick")
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3 if kind != "brazier" else 0.5
	cyl.height = maxf(_wick.y, 0.4) + 0.3
	shape.shape = cyl
	shape.position = Vector3(0, cyl.height * 0.5 if kind != "lantern_fruit" else 0.0, 0)
	add_child(shape)
	light = OmniLight3D.new()
	light.light_color = light_color
	light.omni_range = light_range
	# Visible from the start at energy 0: a light that first appears at kindle time can stall
	# the web build while its shaders compile.
	light.light_energy = 0.0
	light.position = _wick + Vector3.UP * 0.2
	add_child(light)
	_set_flame(false)
	if start_lit:
		kindle(true)


func glyph_anchor() -> Vector3:
	return to_global(_wick)


func glyph_radius() -> float:
	return 0.45


func on_glyph(glyph: StringName, _info: Dictionary) -> bool:
	if glyph != &"kindle" or lit or not GlyphReach.clear(self):
		return false
	if Game.level != null and not Game.level.all_flags(Array(requires_flags)):
		Game.qa_log("kindle_refused", {"target": String(name), "needs": Array(requires_flags)})
		Game.hint(&"not_ready")
		return false
	kindle()
	return true


## Light it. instant: no animation (a level loaded past this point, or start_lit).
func kindle(instant: bool = false) -> void:
	if lit:
		return
	lit = true
	_set_flame(true)
	if instant:
		light.light_energy = light_energy
	else:
		create_tween().tween_property(light, "light_energy", light_energy, 0.5)
		var look := ModelKit.ink_look(model)
		if look != null:
			look.flash(Palette.GOLD_PALE, 0.35)
	Game.qa_log("kindled", {"target": String(name)})
	if Game.level != null:
		Game.level.set_flag(lit_flag)
	kindled.emit()


## Put it out again (wind, a scripted moment).
func put_out() -> void:
	if not lit:
		return
	lit = false
	_set_flame(false)
	create_tween().tween_property(light, "light_energy", 0.0, 0.4)
	if Game.level != null:
		Game.level.set_flag(lit_flag, false)


func _set_flame(on: bool) -> void:
	# Shrunk rather than hidden, so it is drawn (and its material compiled) from the start.
	var flame := model.find_child("Flame", true, false) as Node3D
	if flame == null:
		return
	if not flame.has_meta(&"lit_scale"):
		flame.set_meta(&"lit_scale", flame.scale)
	flame.visible = true
	flame.scale = flame.get_meta(&"lit_scale") if on else Vector3.ONE * 0.001
