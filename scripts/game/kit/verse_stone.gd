class_name VerseStone
extends StaticBody3D
## A verse-stone the Ink-maker left by the river. Bloom it and it speaks its lines (usually four
## short ones) from the level's data file, then sets read_flag. It can teach a glyph: with
## teaches set, a prompt explains the glyph once the lines end. It can be read again. Owner: gameplay.

## The lines were read to the end.
signal read
## The Bloom landed and the stone starts speaking.
signal woken

## Key of the lines in level.json. Empty: the node name in snake_case.
@export var talk_id: String = ""
## Name on the panel for lines without "who".
@export var display_name: String = "Verse-stone"
## Set after the first reading. Empty: "read_<talk_id>".
@export var read_flag: StringName = &""
## A glyph this stone teaches (kindle, tie, ...): a prompt follows the lines.
@export var teaches: StringName = &""
## The teaching prompt (BBCode; %s becomes the glyph's name).
@export_multiline var teach_text: String = ""
## Your own stone model (default: scenes/models/verse_stone.tscn or a placeholder).
@export var model_scene: PackedScene

var model: Node3D
var reads := 0
var reading := false


func _ready() -> void:
	add_to_group(Layers.GROUP_BRUSH_TARGET)
	add_to_group(&"verse_stone")
	collision_layer = Layers.WORLD | Layers.BRUSH_TARGET
	collision_mask = 0
	if talk_id == "":
		talk_id = String(name).to_snake_case()
	if read_flag == &"":
		read_flag = StringName("read_" + talk_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.7, 0.4)
	shape.shape = box
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	model = model_scene.instantiate() as Node3D if model_scene != null else ModelKit.load_model("verse_stone", ModelKit.verse_stone)
	add_child(model)


func glyph_anchor() -> Vector3:
	return global_position + Vector3.UP * 0.9


func glyph_radius() -> float:
	return 0.8


func on_glyph(glyph: StringName, _info: Dictionary) -> bool:
	if glyph != &"bloom" or reading or Game.level == null or not Game.level.has_lines(talk_id) or not GlyphReach.clear(self):
		return false
	reading = true
	woken.emit()
	# The brush is still finishing its stroke; open the panel once it has.
	_read.call_deferred()
	return true


func _read() -> void:
	var look := ModelKit.ink_look(model)
	if look != null:
		look.flash(Palette.PETAL, 0.5)
	Vfx.petal_burst(glyph_anchor(), 1.2)
	await get_tree().create_timer(0.5).timeout
	var lines: Array = []
	for l: Dictionary in Game.level.lines(talk_id):
		var line := l.duplicate()
		if not line.has("who"):
			line["who"] = display_name
		lines.append(line)
	Game.qa_log("verse_stone", {"stone": talk_id})
	if is_instance_valid(Game.main):
		await Game.main.talk.run(lines)
	reading = false
	reads += 1
	Game.level.set_flag(read_flag)
	read.emit()
	if teaches != &"" and is_instance_valid(Game.main):
		var text := teach_text if teach_text != "" else "The stone remembers a stroke: %s."
		Game.main.prompt_near(StringName("teach_" + String(teaches)), text, teaches)
