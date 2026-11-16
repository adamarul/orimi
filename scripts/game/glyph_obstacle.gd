class_name GlyphObstacle
extends StaticBody3D
## A blocking object a glyph removes: a thorn gate (slash) or a soot bank (gust). Solid on
## the world layer and a brush target until cleared; sets cleared_flag when it goes. Place
## scenes/game/kit/thorn_gate.tscn or soot_bank.tscn. Owner: gameplay.

signal cleared_by_glyph

## &"slash" (thorn gate) or &"gust" (soot bank).
@export var glyph: StringName = &"slash"
## The blocking box, metres (depth is 1 m).
@export var width: float = 6.6
@export var height: float = 3.2
## A model to show instead of the default thorns or soot (its root may have blow_away(dir)).
@export var model_scene: PackedScene
## Set on the level when cleared.
@export var cleared_flag: StringName = &""
## Tutorial prompt shown while Orimi is within hint_distance: a main-scene prompt id, or
## hint_text (BBCode, %s becomes the glyph name in the accent colour).
@export var hint_id: StringName = &""
@export_multiline var hint_text: String = ""
@export var hint_distance: float = 10.0
## The glyph is refused (refuse_hint) until all are set.
@export var requires_flags: PackedStringArray = PackedStringArray()
@export var refuse_hint: StringName = &"not_ready"
## Other nodes cleared with this one (a bellows-blown soot bank clearing the soot on a route):
## GlyphObstacles clear as if hit, anything with clear() has it called, anything else is freed.
@export var clears: Array[NodePath] = []

var cleared := false
var model: Node3D
var _hint_cooldown := 0.0


func _ready() -> void:
	add_to_group(Layers.GROUP_BRUSH_TARGET)
	collision_layer = Layers.WORLD | Layers.BRUSH_TARGET
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 1.0)
	shape.shape = box
	shape.position = Vector3(0, height * 0.5, 0)
	add_child(shape)
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
	elif glyph == &"slash":
		model = ModelKit.load_model("thorn_gate", ModelKit.thorn_gate)
	else:
		const VFX_SCENE := "res://scenes/env/soot_bank_visual.tscn"
		if ResourceLoader.exists(VFX_SCENE):
			model = (load(VFX_SCENE) as PackedScene).instantiate() as Node3D
			model.set_meta(&"placeholder", false)
		else:
			model = ModelKit.soot_bank()
			model.set_meta(&"placeholder", true)
	add_child(model)
	_link_flag.call_deferred()


## A warp (or a level script) that sets cleared_flag finds the way already clear.
func _link_flag() -> void:
	if Game.level == null or cleared_flag == &"":
		return
	Game.level.flag_changed.connect(func(f: StringName, value: bool) -> void:
		if value and f == cleared_flag and not cleared:
			remove_silently())
	if Game.level.get_flag(cleared_flag):
		remove_silently()


func _process(delta: float) -> void:
	if cleared or (hint_id == &"" and hint_text == "") or not Game.is_playing() or not is_instance_valid(Game.player):
		return
	_hint_cooldown -= delta
	if _hint_cooldown > 0.0 or Game.player.global_position.distance_to(global_position) > hint_distance:
		return
	_hint_cooldown = 8.0
	if is_instance_valid(Game.main) and Game.main.has_method("prompt_near"):
		Game.main.prompt_near(hint_id if hint_id != &"" else StringName("obstacle_" + String(name)), hint_text, glyph)


func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * height * 0.45


func glyph_radius() -> float:
	return width * 0.42


func on_glyph(cast: StringName, info: Dictionary) -> bool:
	if cleared or cast != glyph or not GlyphReach.clear(self):
		return false
	if Game.level != null and not Game.level.all_flags(Array(requires_flags)):
		Game.qa_log("glyph_refused", {"target": String(name), "glyph": String(cast), "needs": Array(requires_flags)})
		if refuse_hint != &"":
			Game.hint(refuse_hint)
		return false
	clear(info.get("world_dir", Vector3.ZERO))
	return true


func clear(direction: Vector3 = Vector3.ZERO) -> void:
	if cleared:
		return
	cleared = true
	remove_from_group(Layers.GROUP_BRUSH_TARGET)
	collision_layer = 0
	var at := glyph_anchor()
	cleared_by_glyph.emit()
	GlyphTarget.clear_nodes(self, clears, direction)
	if Game.level != null:
		Game.level.set_flag(cleared_flag)
	if is_instance_valid(Game.main) and Game.main.has_method("hide_prompt"):
		Game.main.hide_prompt(hint_id if hint_id != &"" else StringName("obstacle_" + String(name)))
	if glyph == &"slash":
		Events.thorns_cut.emit(self, at)
	else:
		Events.soot_cleared.emit(self, at)
	if model.has_method("blow_away"):
		model.call("blow_away", direction)
		await get_tree().create_timer(3.0, false).timeout
		queue_free()
		return
	# Stepped collapse on the 12 fps grid: thorns fall apart, soot thins away.
	var look := ModelKit.ink_look(model)
	for i in 10:
		var k := (i + 1) / 10.0
		if look != null:
			look.set_dissolve(k)
		if glyph == &"slash":
			model.scale = Vector3(1.0 + k * 0.15, maxf(1.0 - k, 0.02), 1.0)
		else:
			model.scale = Vector3(1.0 + k * 0.5, 1.0 + k * 0.3, maxf(1.0 - k, 0.02))
			if direction.length() > 0.1:
				model.global_position += direction.normalized() * 0.35
		await get_tree().create_timer(1.0 / 12.0, false).timeout
	queue_free()


## Remove at once without events (warp).
func remove_silently() -> void:
	cleared = true
	if Game.level != null:
		Game.level.set_flag(cleared_flag)
	queue_free()
