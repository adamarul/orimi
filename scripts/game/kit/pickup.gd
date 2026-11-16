class_name Pickup
extends Node3D
## Something Orimi picks up by touching it: a leaf of a map, a key, a keepsake. It sets its flag,
## plays its sound, shows a card (title and a line under it) and goes. The level does the rest on
## the flag (count leaves with all_flags, open a gate). Owner: gameplay.

## A pickup was taken.
signal picked

## Set when taken. Empty: "picked_<node name in snake_case>", for example picked_leaf_1.
@export var flag: StringName = &""
## Card shown when taken (title empty: no card).
@export var title: String = ""
@export var text: String = ""
## Only there (seen and takeable) once this flag is set, like Person.show_flag.
@export var show_flag: StringName = &""
## Your model. Without one it is a leaf of paper with a vermilion mark.
@export var model_scene: PackedScene
## How close Orimi must come, metres.
@export var radius: float = 0.9
## Colour of the pickup effect (Vfx "pickup").
@export var color: Color = Palette.GOLD
@export var sfx: StringName = &"pickup"
## Bob and turn while waiting.
@export var bob: bool = true

var taken := false
var model: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"pickup")
	if flag == &"":
		flag = StringName("picked_" + String(name).to_snake_case())
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
		add_child(model)
	else:
		model = ModelKit.node(self, "Leaf", Vector3(0, 0.6, 0))
		ModelKit.part(model, "Sheet", ModelKit.box(Vector3(0.46, 0.02, 0.34)), Palette.PARCHMENT, Vector3.ZERO, Vector3(-60, 0, 8))
		ModelKit.part(model, "Mark", ModelKit.box(Vector3(0.12, 0.024, 0.12)), Palette.VERMILION, Vector3(0.06, 0.004, 0.0), Vector3(-60, 0, 8))
		ModelKit.add_ink_look(model, &"vermilion", false, 0.8)
	_setup.call_deferred()


func _setup() -> void:
	while Game.level == null or not Game.level.built:
		await get_tree().process_frame
	Game.level.flag_changed.connect(func(_f: StringName, _v: bool) -> void: _update_shown())
	_update_shown()


func is_shown() -> bool:
	return not taken and (show_flag == &"" or Game.level == null or Game.level.get_flag(show_flag))


func _update_shown() -> void:
	if Game.level != null and Game.level.get_flag(flag):
		taken = true
	visible = is_shown()


func _physics_process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if bob and model != null:
		model.position.y = 0.6 + sin(_t * 2.2) * 0.08
		model.rotation.y = _t * 0.9
	var p := Game.player as OrimiPlayer
	if not is_instance_valid(p) or p.dead or not Game.is_playing():
		return
	var d := p.global_position - global_position
	if Vector2(d.x, d.z).length() > radius or absf(d.y) > 1.6:
		return
	take()


## Take it now (also for a level that hands it over in a cutscene).
func take() -> void:
	if taken:
		return
	taken = true
	visible = false
	Audio.play_sfx(sfx, global_position)
	Vfx.play(&"pickup", model.global_position if model != null else global_position, {"color": color})
	if title != "" and Game.main != null and Game.main.hud != null:
		Game.main.hud.show_banner(title, text, 3.5)
	Game.qa_log("pickup", {"pickup": String(name), "flag": String(flag)})
	if Game.level != null:
		Game.level.set_flag(flag)
	picked.emit()
