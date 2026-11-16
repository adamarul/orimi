class_name Person
extends Node3D
## Someone Orimi can talk to. Walk up and press E or Enter (the prompt says so); the talk panel
## shows the level's lines for this person (level.json "lines"). A faded person stands grey and
## still, like an unpainted cut-out, until wake_flag is set or wake() is called; then colour
## comes back and they move. Lines are picked by state: "<talk_id>_faded" while faded (if the
## level has it; otherwise a faded person cannot be talked to), "<talk_id>" the first time when
## awake, "<talk_id>_again" on later talks (falls back to "<talk_id>"). A line with no "who"
## is spoken by display_name; "who": "" is a narrator line with no name. Owner: gameplay.

## A conversation finished. talk_id is the lines key that was shown.
signal talked(talk_id: String)
## Colour came back.
signal woken

const FADE_COLOR := Color("cfcac0")
const FADE_AMOUNT := 0.85
const WAKE_TIME := 1.4

## The name on the talk panel (lines without "who" use it).
@export var display_name: String = ""
## Key of this person's lines in level.json. Empty: the node name in snake_case.
@export var talk_id: String = ""
## scenes/models/<model_name>.tscn when it exists (for example "folk/pell"); otherwise a
## paper placeholder.
@export var model_name: String = ""
## A model scene of the level's own, usually a folk wrapper from tools/assets/gen_folk.sh
## (scenes/levels/<id>/folk/<name>.tscn). Takes priority over model_name.
@export var model_scene: PackedScene
## Placeholder robe colour and hat ("", "paper", "brim").
@export var robe_color: Color = Palette.SAGE
@export var hat: String = ""
## Starts grey and still.
@export var faded: bool = false
## Wakes when this level flag is set.
@export var wake_flag: StringName = &""
## Set after the first finished conversation while awake. Empty: "talked_<talk_id>".
@export var talked_flag: StringName = &""
## Set after the first finished conversation while faded. Empty: "talked_<talk_id>_faded".
@export var talked_faded_flag: StringName = &""
@export var talk_radius: float = 2.4
## Shown (and talkable) only once this flag is set.
@export var show_flag: StringName = &""
## Hidden once this flag is set (walked away, went home).
@export var hide_flag: StringName = &""
## Talk id switched by flags: flag -> lines key. The last listed flag that is set wins; with
## none set, talk_id is used. The _faded and _again variants apply to the chosen key too.
@export var talk_by_flag: Dictionary = {}
## A bark (a line in the panel that does not stop play) when Orimi first comes within
## bark_radius: a lines key. It repeats only after she has gone and come back.
@export var bark_near: String = ""
@export var bark_radius: float = 7.0
## Barks when flags are set: flag -> lines key.
@export var bark_on_flag: Dictionary = {}
## Turn toward Orimi while talking.
@export var face_player: bool = true
## The camera frames the two of them while talking.
@export var frame_camera: bool = true

var model: Node3D
var anim: AnimationPlayer
var look: InkLook
var talking := false
var talks := 0
var _in_range := false
var _bark_close := false
## Lines keys (before _again) already talked through while awake.
var _talked: Dictionary = {}
var _hint_id: StringName


func _ready() -> void:
	add_to_group(&"person")
	if talk_id == "":
		talk_id = String(name).to_snake_case()
	if talked_flag == &"":
		talked_flag = StringName("talked_" + talk_id)
	if talked_faded_flag == &"":
		talked_faded_flag = StringName("talked_%s_faded" % talk_id)
	_hint_id = StringName("talk_" + talk_id)
	if model_scene != null:
		model = model_scene.instantiate() as Node3D
	else:
		model = ModelKit.load_model(model_name, ModelKit.person.bind(robe_color, hat)) if model_name != "" \
			else ModelKit.person(robe_color, hat)
	model.name = "Model"
	add_child(model)
	anim = ModelKit.anim_player(model)
	look = ModelKit.ink_look(model)
	if faded:
		_apply_faded.call_deferred()
	else:
		_play(&"idle")
	_settle.call_deferred()


func _settle() -> void:
	await get_tree().physics_frame
	if Game.level != null:
		Game.level.flag_changed.connect(_on_flag)
		if wake_flag != &"" and Game.level.get_flag(wake_flag) and faded:
			wake(true)
		_update_shown()
		await Game.level.ready_to_settle()
		global_position = Game.level.ground_at(global_position + Vector3.UP * 1.5, self)


## A folk model from the assets generator (scenes/models/folk/folk_person.gd) drains and wakes
## itself; a placeholder is greyed through its InkLook.
func _is_folk() -> bool:
	return model.has_method(&"wake") and &"faded" in model


func _apply_faded() -> void:
	if _is_folk():
		model.set(&"faded", true)
		_play(&"faded")
		return
	if anim != null:
		anim.stop()
	if look != null:
		# A flash that never fades: a flat grey cut-out until wake().
		look.flash(FADE_COLOR, 1.0e7)


func _play(anim_name: StringName) -> void:
	if anim != null and anim.has_animation(anim_name):
		anim.play(anim_name)


func _on_flag(flag: StringName, value: bool) -> void:
	if value and flag == wake_flag and faded:
		wake()
	if flag == show_flag or flag == hide_flag:
		_update_shown()
	# Flags a warp sets are history, not news: no barks for them.
	if value and bark_on_flag.has(String(flag)) and is_shown() and not (Game.level != null and Game.level.applying_warp):
		bark(String(bark_on_flag[String(flag)]))


## Present in the level: show_flag set (or none) and hide_flag not set.
func is_shown() -> bool:
	if Game.level == null:
		return true
	return (show_flag == &"" or Game.level.get_flag(show_flag)) and (hide_flag == &"" or not Game.level.get_flag(hide_flag))


func _update_shown() -> void:
	visible = is_shown()


## Say a lines key as a bark: in the panel, without stopping play.
func bark(key: String) -> void:
	if Game.level == null or not Game.level.has_lines(key) or not is_instance_valid(Game.main):
		return
	var lines: Array = []
	for l: Dictionary in Game.level.lines(key):
		var line := l.duplicate()
		if not line.has("who"):
			line["who"] = display_name
		lines.append(line)
	Game.qa_log("bark", {"person": talk_id, "lines": key})
	Game.main.talk.bark(lines)


## Bring the colour back. instant: no fade (a level loaded past this point).
func wake(instant: bool = false) -> void:
	if not faded:
		return
	faded = false
	if _is_folk():
		if instant:
			model.set(&"faded", false)
		else:
			model.call(&"wake")
	elif look != null:
		look.flash(FADE_COLOR, 0.01 if instant else WAKE_TIME)
	_play(&"idle")
	if not instant:
		Vfx.petal_burst(global_position + Vector3.UP * 1.0, 1.5)
	Game.qa_log("person_woken", {"person": talk_id})
	woken.emit()


## The lines key that talk() would show now, or "" when there is nothing to say.
func current_talk() -> String:
	var lvl := Game.level
	if lvl == null or not is_shown():
		return ""
	var base := _base_key()
	if faded:
		return base + "_faded" if lvl.has_lines(base + "_faded") else ""
	if _talked.has(base) and lvl.has_lines(base + "_again"):
		return base + "_again"
	return base if lvl.has_lines(base) else ""


## talk_id, or the key talk_by_flag switches to.
func _base_key() -> String:
	var base := talk_id
	if Game.level != null:
		for f: Variant in talk_by_flag:
			if Game.level.get_flag(StringName(f)):
				base = String(talk_by_flag[f])
	return base


func can_talk() -> bool:
	return current_talk() != "" and not talking


## Talk now (the E key, or a level script / autoplay). Returns when the panel closes.
func talk() -> void:
	var key := current_talk()
	if key == "" or talking or not is_instance_valid(Game.main):
		return
	talking = true
	var was_faded := faded
	var base := _base_key()
	if is_instance_valid(Game.main):
		Game.main.hide_prompt(_hint_id)
	var p := Game.player as OrimiPlayer
	if face_player and is_instance_valid(p) and not faded:
		var d := p.global_position - global_position
		create_tween().tween_property(self, "rotation:y", atan2(d.x, d.z), 0.25)
	if is_instance_valid(p):
		var to := global_position - p.global_position
		p.rotation.y = atan2(-to.x, -to.z)
		if frame_camera and p.camera is GameCamera:
			(p.camera as GameCamera).face_toward(global_position + Vector3.UP * 1.0, -10.0)
	if not faded:
		_play(&"talk")
	var lines: Array = []
	for l: Dictionary in Game.level.lines(key):
		var line := l.duplicate()
		if not line.has("who"):
			line["who"] = display_name
		lines.append(line)
	Game.qa_log("talk", {"person": talk_id, "lines": key})
	await Game.main.talk.run(lines)
	talking = false
	if not faded:
		_play(&"idle")
	talks += 1
	if not was_faded:
		_talked[base] = true
	if Game.level != null:
		Game.level.set_flag(talked_faded_flag if was_faded else talked_flag)
	talked.emit(key)


func _physics_process(_delta: float) -> void:
	var p := Game.player
	if not is_instance_valid(p) or not Game.is_playing():
		return
	var d := p.global_position.distance_to(global_position)
	if bark_near != "" and is_shown():
		if not _bark_close and d < bark_radius:
			_bark_close = true
			bark(bark_near)
		elif _bark_close and d > bark_radius + 3.0:
			_bark_close = false
	var near := d < talk_radius and can_talk() and _is_nearest(p.global_position)
	if near != _in_range:
		_in_range = near
		if near:
			Game.main.prompt_near(_hint_id, "[b]E[/b] or [b]Enter[/b] to talk with %s." % (display_name if display_name != "" else "them"), &"")
		elif is_instance_valid(Game.main):
			Game.main.hide_prompt(_hint_id)


func _is_nearest(at: Vector3) -> bool:
	var mine := at.distance_squared_to(global_position)
	for n: Node in get_tree().get_nodes_in_group(&"person"):
		if n != self and (n as Node3D).global_position.distance_squared_to(at) < mine and (n as Person).can_talk():
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _in_range or not Game.is_playing() or talking:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		talk()
