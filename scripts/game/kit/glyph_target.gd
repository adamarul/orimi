class_name GlyphTarget
extends StaticBody3D
## Anything that answers a glyph: a lily bud that Bloom opens into a platform, a bellows that
## Gust works, a seal that Slash breaks, a wick that Kindle lights. It accepts the glyphs in
## its list, optionally only once its required flags are set, then sets its flag, clears the
## nodes in clears (a bellows blowing soot off a route) and emits glyph_received; the level
## does the rest on that signal or flag. It does not move or vanish by itself. Owner: gameplay.

## A glyph in the list landed (and the target accepted it).
signal glyph_received(glyph: StringName, info: Dictionary)

## Glyphs it answers: any of bloom, slash, gust, kindle, tie.
@export var glyphs: PackedStringArray = PackedStringArray(["bloom"])
## Refused (refuse_hint) until all are set.
@export var requires_flags: PackedStringArray = PackedStringArray()
## Set when a glyph lands. Empty: "<glyph>_<node name in snake_case>", for example bloom_lily_1.
@export var flag: StringName = &""
## Answer only the first glyph; later ones are ignored.
@export var once: bool = true
## Nodes cleared when it answers: a GlyphObstacle (or anything with clear()) clears as if its
## own glyph had landed; any other node is freed.
@export var clears: Array[NodePath] = []
## Your model. Without one the target is invisible (the level shows something of its own).
@export var model_scene: PackedScene
## Size of the target box (and the height of its glyph anchor).
@export var size: Vector3 = Vector3(1.2, 1.2, 1.2)
## Solid: Orimi collides with it (WORLD layer as well as BRUSH_TARGET).
@export var solid: bool = false
## Prompt near it, like GlyphObstacle (a main-scene prompt id, or text with %s for the glyph).
@export var hint_id: StringName = &""
@export_multiline var hint_text: String = ""
@export var hint_distance: float = 8.0
## Main-scene prompt shown when the glyph is refused for a missing flag.
@export var refuse_hint: StringName = &"not_ready"

var answered := false
var model: Node3D
var _hint_cooldown := 0.0


func _ready() -> void:
	add_to_group(Layers.GROUP_BRUSH_TARGET)
	add_to_group(&"glyph_target")
	collision_layer = (Layers.WORLD if solid else 0) | Layers.BRUSH_TARGET
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	add_child(shape)
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
		add_child(model)
	_link_flag.call_deferred()


## A once target whose flag a warp (or a level script) sets is already answered, quietly.
func _link_flag() -> void:
	if Game.level == null or not once:
		return
	var f := _flag_name()
	Game.level.flag_changed.connect(func(changed: StringName, value: bool) -> void:
		if value and changed == f:
			answered = true)
	if Game.level.get_flag(f):
		answered = true


func _flag_name() -> StringName:
	return flag if flag != &"" else StringName("%s_%s" % [glyphs[0] if not glyphs.is_empty() else "", String(name).to_snake_case()])


func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * size.y * 0.5


func glyph_radius() -> float:
	return maxf(size.x, size.z) * 0.5


func on_glyph(glyph: StringName, info: Dictionary) -> bool:
	if not String(glyph) in glyphs or (once and answered) or not GlyphReach.clear(self):
		return false
	if Game.level != null and not Game.level.all_flags(Array(requires_flags)):
		Game.qa_log("glyph_refused", {"target": String(name), "glyph": String(glyph), "needs": Array(requires_flags)})
		if refuse_hint != &"":
			Game.hint(refuse_hint)
		return false
	answered = true
	Game.qa_log("glyph_target", {"target": String(name), "glyph": String(glyph)})
	if is_instance_valid(Game.main):
		Game.main.hide_prompt(_hint_key())
	if model != null:
		var look := ModelKit.ink_look(model)
		if look != null:
			look.flash(Palette.GOLD_PALE, 0.3)
	clear_nodes(self, clears, info.get("world_dir", Vector3.ZERO))
	if Game.level != null:
		Game.level.set_flag(flag if flag != &"" else StringName("%s_%s" % [glyph, String(name).to_snake_case()]))
	glyph_received.emit(glyph, info)
	return true


## Clear each node in paths (relative to from): clear(direction) when it has one, else free it.
static func clear_nodes(from: Node, paths: Array[NodePath], direction: Vector3 = Vector3.ZERO) -> void:
	for path in paths:
		var n := from.get_node_or_null(path)
		if n == null:
			push_warning("%s: nothing to clear at %s" % [from.name, path])
		elif n.has_method(&"clear"):
			n.call(&"clear", direction)
		else:
			n.queue_free()


func _hint_key() -> StringName:
	return hint_id if hint_id != &"" else StringName("target_" + String(name))


func _process(delta: float) -> void:
	if answered or (hint_id == &"" and hint_text == "") or not Game.is_playing() or not is_instance_valid(Game.player):
		return
	_hint_cooldown -= delta
	if _hint_cooldown > 0.0 or Game.player.global_position.distance_to(global_position) > hint_distance:
		return
	_hint_cooldown = 8.0
	if is_instance_valid(Game.main):
		Game.main.prompt_near(_hint_key(), hint_text, StringName(glyphs[0]) if not glyphs.is_empty() else &"")
